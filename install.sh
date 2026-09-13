#!/usr/bin/env bash
set -euo pipefail

echo "Checking for Multipass..."
if command -v multipass >/dev/null 2>&1; then
  echo "Multipass is already installed ($(multipass version | head -n1))."
  exit 0
fi

os="$(uname -s)"
is_wsl() {
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]
}

case "$os" in
  Darwin)
    echo "Multipass isn't installed. Install it with Homebrew:"
    echo
    echo "  brew install --cask multipass"
    ;;
  Linux)
    if is_wsl; then
      echo "Multipass isn't installed. You're in WSL — Multipass needs Hyper-V, which only works"
      echo "installed natively on Windows, not inside this Linux distro (skip apt/snap here):"
      echo
      echo "  https://multipass.run/install"
      echo
      echo "Once it's installed on the Windows side, this WSL shell picks up multipass.exe on PATH"
      echo "automatically — no extra setup needed here."
    else
      echo "Multipass isn't installed. On most distros:"
      echo
      echo "  sudo snap install multipass"
      echo
      echo "No snap available? See https://multipass.run/install for other options."
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "Multipass isn't installed. Install Multipass for Windows (uses Hyper-V):"
    echo
    echo "  https://multipass.run/install"
    echo
    echo "Then run ./interview-sandbox from this same Git Bash terminal — it calls the Windows"
    echo "multipass.exe directly, no WSL required."
    ;;
  *)
    echo "Multipass isn't installed. See https://multipass.run/install for Windows/other platforms."
    ;;
esac

echo
echo "This installs a lightweight VM hypervisor on your machine — worth reviewing before running."
echo "Once it's installed, run: ./interview-sandbox up"
