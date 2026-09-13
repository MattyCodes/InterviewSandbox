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
  local host="$1" port="${2:-22}"
  mkdir -p "$SSH_CONFIG_DIR"
  cat > "$SSH_CONFIG_FILE" <<EOF
Host $VM_NAME
    HostName $host
    Port $port
    User ubuntu
    IdentityFile $KEY_FILE
    UserKnownHostsFile $KNOWN_HOSTS_FILE
    ForwardAgent no
    StrictHostKeyChecking accept-new
    LogLevel ERROR
EOF
}

# Locates PsExec (Sysinternals) under any of its common binary names.
find_psexec() {
  local name
  for name in PsExec64.exe psexec64.exe PsExec.exe psexec.exe; do
    command -v "$name" 2>/dev/null && return 0
  done
  return 1
}

# Reads VirtualBox's install directory from the registry (the same place
# Multipass itself looks it up), falling back to the default install path.
# Prints a native Windows path, e.g. "C:\Program Files\Oracle\VirtualBox".
windows_virtualbox_dir() {
  local dir
  dir="$(reg query 'HKLM\SOFTWARE\Oracle\VirtualBox' /v InstallDir 2>/dev/null | sed -n 's/.*REG_SZ *//p')" || true
  dir="${dir%\\}"
  [[ -n "$dir" ]] || dir='C:\Program Files\Oracle\VirtualBox'
  printf '%s' "$dir"
}

# On Windows, Multipass's VirtualBox VMs sometimes only get a NAT adapter
# with no host-routable IP — Multipass runs the VirtualBox backend as the
# LocalSystem service account, and under that account VirtualBox doesn't
# reliably attach the second (host-only) adapter it normally uses for
# host<->guest reachability. The VM itself is perfectly healthy in that
# case, just unreachable by IP.
#
# Multipass still needs its own way to reach the guest for things like
# `multipass exec`, though, so it already forwards a host port to the
# guest's SSH port over the NAT adapter on a rule named "ssh" — it just
# doesn't surface that port anywhere `multipass info`/`vm_ip` looks. Rather
# than fight it with a second, conflicting rule of our own (VirtualBox
# rejects a duplicate rule *name* even on a different port, which is what
# an earlier version of this function ran into), just read the port back
# out and connect through that.
#
# Reading it has to run as the same LocalSystem account Multipass uses
# (regular VBoxManage.exe, run as yourself, can't even see the VM — it's
# registered under a different Windows account's VirtualBox profile), which
# needs PsExec (Sysinternals) since bash has no native way to do that.
discover_windows_nat_ssh_port() {
  is_windows_host || return 1
  multipass exec "$VM_NAME" -- true >/dev/null 2>&1 || return 1

  local psexec
  psexec="$(find_psexec)" || {
    err "This VM has no host-routable IP — on Windows + VirtualBox that usually means"
    err "Multipass only attached a NAT adapter (a known Multipass/VirtualBox limitation"
    err "on Windows). Reading the SSH port Multipass already forwards for its own use"
    err "needs PsExec (Sysinternals), run as the account Multipass runs under:"
    err "  1. Download PsTools: https://learn.microsoft.com/en-us/sysinternals/downloads/pstools"
    err "  2. Put PsExec64.exe somewhere on your PATH"
    err "  3. Re-run this command"
    return 1
  }

  local vboxmanage_native vboxmanage_posix
  vboxmanage_native="$(windows_virtualbox_dir)\\VBoxManage.exe"
  vboxmanage_posix="$(to_posix_path "$vboxmanage_native")"
  if [[ ! -e "$vboxmanage_posix" ]]; then
    err "Could not find VBoxManage.exe (looked at: $vboxmanage_native)."
    return 1
  fi

  local info port
  info="$("$psexec" -s -nobanner -accepteula "$vboxmanage_native" showvminfo "$VM_NAME" --machinereadable 2>/dev/null)" || true
  # Lines look like: Forwarding(0)="ssh,tcp,,61106,,22" — match on the rule
  # that targets guest port 22, regardless of what it's named or which
  # index it's at.
  port="$(printf '%s\n' "$info" | sed -n 's/^Forwarding([0-9]*)="[^,]*,tcp,[^,]*,\([0-9]*\),[^,]*,22"$/\1/p' | head -n1)"

  if [[ -z "$port" ]]; then
    err "Could not find an existing SSH port forward on this VM's NAT adapter."
    return 1
  fi
  printf '%s' "$port"
}

# Figures out how to reach the VM over SSH, setting VM_SSH_HOST/VM_SSH_PORT.
# Prefers a direct routable IP; falls back to the Windows NAT-forward
# discovery above when there isn't one but the VM is otherwise reachable.
resolve_vm_endpoint() {
  local ip
  ip="$(vm_ip)" || true
  if [[ -n "$ip" ]]; then
    VM_SSH_HOST="$ip"
    VM_SSH_PORT="22"
    return 0
  fi

  local nat_port
  if nat_port="$(discover_windows_nat_ssh_port)"; then
    VM_SSH_HOST="127.0.0.1"
    VM_SSH_PORT="$nat_port"
    return 0
  fi

  return 1
}

remove_ssh_config() {
  rm -f "$SSH_CONFIG_FILE" "$KNOWN_HOSTS_FILE"
}

remote_exec() {
  ssh "$VM_NAME" "$@"
}

start_tunnel() {
  if ssh -O check -S "$TUNNEL_CONTROL_SOCKET" "$VM_NAME" >/dev/null 2>&1; then
    return 0
  fi
  ssh -f -N -M -S "$TUNNEL_CONTROL_SOCKET" -o ExitOnForwardFailure=yes \
    -L "${CODE_SERVER_PORT}:localhost:${CODE_SERVER_PORT}" "$VM_NAME"
}

stop_tunnel() {
  ssh -O exit -S "$TUNNEL_CONTROL_SOCKET" "$VM_NAME" >/dev/null 2>&1 || true
  rm -f "$TUNNEL_CONTROL_SOCKET"
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
    kill -0 "$launch_pid" 2>/dev/null || return 0
    sleep 1
  done
  [[ -n "$ip" ]] || return 0

  ensure_ssh_include
  write_ssh_config "$ip"

  while :; do
    local elapsed=$(( $(date +%s) - start_ts ))
    if (( elapsed > PROVISION_MAX_WAIT )); then
      warn "Provisioning is taking longer than $((PROVISION_MAX_WAIT / 60)) minutes — something may be stuck."
      warn "Check manually with: multipass exec $VM_NAME -- cloud-init status --long"
      return 0
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
    if [[ "$cinit_status" == "done" || "$cinit_status" == "error" ]]; then
      return 0
    fi

    # Stop polling once the launch command itself has exited, whether it
    # succeeded, failed, or hit its own timeout — nothing left to watch.
    kill -0 "$launch_pid" 2>/dev/null || return 0

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
