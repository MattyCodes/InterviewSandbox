#!/usr/bin/env bash
# Shared config and helpers sourced by the main interview-sandbox script.

VM_NAME="interview-sandbox"
VM_IMAGE="22.04"
VM_CPUS="2"
VM_MEMORY="4G"
VM_DISK="20G"
CODE_SERVER_PORT="8080"

WORKDIR="$HOME/.interview-sandbox"
KEY_FILE="$WORKDIR/keys/id_ed25519"
KNOWN_HOSTS_FILE="$WORKDIR/known_hosts"
TUNNEL_CONTROL_SOCKET="$WORKDIR/tunnel.sock"
PASSWORD_FILE="$WORKDIR/code-server-password"

# Some Windows + VirtualBox combinations only ever attach a NAT adapter to
# the VM (see ensure_windows_nat_forward in lib/ssh.sh), leaving it with no
# host-routable IP. When that happens, we forward this local port through to
# the guest's SSH port instead and connect via localhost.
SSH_FALLBACK_PORT="2222"

SSH_CONFIG_DIR="$HOME/.ssh/config.d"
SSH_CONFIG_FILE="$SSH_CONFIG_DIR/interview-sandbox.conf"
SSH_MAIN_CONFIG="$HOME/.ssh/config"

log()  { printf '\033[1;32m✔\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$1"; }
err()  { printf '\033[1;31m✘ %s\033[0m\n' "$1" >&2; }
die()  { err "$1"; exit 1; }

require_multipass() {
  command -v multipass >/dev/null 2>&1 || die "Multipass is not installed. Run ./install.sh for instructions."
}

vm_exists() {
  multipass info "$VM_NAME" >/dev/null 2>&1
}

vm_state() {
  multipass info "$VM_NAME" 2>/dev/null | awk -F': *' '/^State/{print $2; exit}'
}

vm_ip() {
  # multipass reports "--" as a placeholder before the VM has a DHCP lease.
  # Filter it here so every caller gets either a real IP or nothing.
  multipass info "$VM_NAME" 2>/dev/null \
    | awk -F': *' '/^IPv4/{print $2; exit}' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true
}

require_running_vm() {
  vm_exists || die "No sandbox VM found. Run 'interview-sandbox up' first."
  [[ "$(vm_state)" == "Running" ]] || die "Sandbox VM isn't running. Run 'interview-sandbox up' first."
}

is_windows_host() {
  command -v cmd.exe >/dev/null 2>&1
}

# Converts a native Windows path (e.g. "C:\Program Files\Foo") to the POSIX
# form bash needs to use it directly (e.g. "/c/Program Files/Foo").
to_posix_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s' "$1" | sed -e 's#^\([A-Za-z]\):#/\L\1#' -e 's#\\#/#g'
  fi
}
