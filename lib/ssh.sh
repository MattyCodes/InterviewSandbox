#!/usr/bin/env bash
# SSH config, tunnel, and browser-launch helpers. All state here is scoped to
# this tool and safe to delete wholesale on `destroy`.

ensure_ssh_include() {
  mkdir -p "$SSH_CONFIG_DIR"
  touch "$SSH_MAIN_CONFIG"
  chmod 600 "$SSH_MAIN_CONFIG"
  if ! grep -qF "Include $SSH_CONFIG_DIR/*.conf" "$SSH_MAIN_CONFIG" 2>/dev/null; then
    local tmp
    tmp="$(mktemp)"
    { echo "Include $SSH_CONFIG_DIR/*.conf"; cat "$SSH_MAIN_CONFIG"; } > "$tmp"
    mv "$tmp" "$SSH_MAIN_CONFIG"
  fi
}

write_ssh_config() {
  local ip="$1"
  mkdir -p "$SSH_CONFIG_DIR"
  cat > "$SSH_CONFIG_FILE" <<EOF
Host $VM_NAME
    HostName $ip
    User ubuntu
    IdentityFile $KEY_FILE
    UserKnownHostsFile $KNOWN_HOSTS_FILE
    ForwardAgent no
    StrictHostKeyChecking accept-new
    LogLevel ERROR
EOF
}

remove_ssh_config() {
  rm -f "$SSH_CONFIG_FILE" "$KNOWN_HOSTS_FILE"
}

remote_exec() {
  ssh "$VM_NAME" "$@"
}

start_tunnel() {
  if [[ -f "$TUNNEL_PID_FILE" ]] && kill -0 "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null; then
    return 0
  fi
  ssh -f -N -o ExitOnForwardFailure=yes \
    -L "${CODE_SERVER_PORT}:localhost:${CODE_SERVER_PORT}" "$VM_NAME"
  pgrep -f "L ${CODE_SERVER_PORT}:localhost:${CODE_SERVER_PORT}" | tail -n1 > "$TUNNEL_PID_FILE"
}

stop_tunnel() {
  if [[ -f "$TUNNEL_PID_FILE" ]]; then
    kill "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null || true
    rm -f "$TUNNEL_PID_FILE"
  fi
}

open_browser() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 &
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  elif command -v cmd.exe >/dev/null 2>&1; then
    cmd.exe /c start "" "$url" >/dev/null 2>&1 &
  else
    warn "Couldn't auto-open a browser. Visit: $url"
  fi
}

PROGRESS_LOG_REMOTE="/var/log/interview-sandbox-provision.log"
PROVISION_MAX_WAIT=1200

# Polls the VM for new lines in its provisioning progress log and prints each
# one with elapsed time as it appears. Takes the PID of a BACKGROUNDED
# `multipass launch` call and polls while that process is still running.
#
# multipass launch --cloud-init blocks internally until the entire user-data
# script (all of our runcmd steps) finishes — it does not return early once
# the VM is merely reachable. So this must run concurrently with launch, not
# after it, or all progress lines arrive in one batch once launch is already
# done, which defeats the purpose of streaming them.
#
# This polls over plain SSH, not `multipass exec` — empirically, `multipass
# exec` hangs indefinitely (not just slowly) against an instance that a
# `multipass launch` is still in flight for, apparently due to some
# per-instance locking in multipassd. Lightweight daemon queries like
# `multipass info` stay responsive throughout, which is how the VM's IP is
# fetched here; the actual polling then goes straight to the guest's sshd
# using our own already-injected key, bypassing multipassd's exec path
# entirely.
stream_provisioning_progress() {
  local launch_pid="$1"
  local start_ts printed_count=0 cinit_status="running" ip=""
  start_ts="$(date +%s)"

  local i
  for i in $(seq 1 30); do
    ip="$(vm_ip)" || true
    [[ -n "$ip" ]] && break
    kill -0 "$launch_pid" 2>/dev/null || return
    sleep 1
  done
  [[ -n "$ip" ]] || return

  ensure_ssh_include
  write_ssh_config "$ip"

  while :; do
    local elapsed=$(( $(date +%s) - start_ts ))
    if (( elapsed > PROVISION_MAX_WAIT )); then
      warn "Provisioning is taking longer than $((PROVISION_MAX_WAIT / 60)) minutes — something may be stuck."
      warn "Check manually with: multipass exec $VM_NAME -- cloud-init status --long"
      return
    fi

    local remote_lines
    remote_lines="$(ssh -o ConnectTimeout=5 "$VM_NAME" "cat $PROGRESS_LOG_REMOTE" 2>/dev/null)" || true
    if [[ -n "$remote_lines" ]]; then
      local total
      total="$(printf '%s\n' "$remote_lines" | wc -l | tr -d ' ')"
      if (( total > printed_count )); then
        printf '%s\n' "$remote_lines" | tail -n "$((total - printed_count))" | while IFS= read -r step; do
          printf '  [%3ds] %s\n' "$elapsed" "$step"
        done
        printed_count="$total"
      fi
    fi

    cinit_status="$(ssh -o ConnectTimeout=5 "$VM_NAME" "cloud-init status" 2>/dev/null | awk -F': ' '{print $2}')" || true
    [[ "$cinit_status" == "done" || "$cinit_status" == "error" ]] && return

    # Stop polling once the launch command itself has exited, whether it
    # succeeded, failed, or hit its own timeout — nothing left to watch.
    kill -0 "$launch_pid" 2>/dev/null || return

    sleep 3
  done
}

wait_for_code_server() {
  local i
  for i in $(seq 1 30); do
    if remote_exec "curl -sf http://localhost:${CODE_SERVER_PORT} >/dev/null" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  warn "code-server didn't respond within 30s — it may still be starting."
}
