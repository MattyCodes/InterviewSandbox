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
