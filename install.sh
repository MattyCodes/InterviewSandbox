#!/usr/bin/env bash
set -euo pipefail

echo "Checking for Multipass..."
if command -v multipass >/dev/null 2>&1; then
  echo "Multipass is already installed ($(multipass version | head -n1))."
  exit 0
fi

os="$(uname -s)"
case "$os" in
  Darwin)
    echo "Multipass isn't installed. Install it with Homebrew:"
    echo
    echo "  brew install --cask multipass"
    ;;
  Linux)
    echo "Multipass isn't installed. On most distros:"
    echo
    echo "  sudo snap install multipass"
    echo
    echo "No snap available? See https://multipass.run/install for other options."
    ;;
  *)
    echo "Multipass isn't installed. See https://multipass.run/install for Windows/other platforms."
    ;;
esac

echo
echo "This installs a lightweight VM hypervisor on your machine — worth reviewing before running."
echo "Once it's installed, run: ./interview-sandbox up"
