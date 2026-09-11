#!/usr/bin/env bash
# Runs INSIDE the sandbox VM against a cloned directory. Advisory only: it
# prints warnings for patterns worth a manual look but never blocks `open` by
# itself (clamscan, run separately, is what gates that).
set -uo pipefail

target="${1:?usage: heuristic-scan.sh <dir>}"

check() {
  local desc="$1" pattern="$2" matches
  matches="$(grep -rlnE "$pattern" "$target" --exclude-dir=.git 2>/dev/null || true)"
  if [[ -n "$matches" ]]; then
    echo "WARN: $desc"
    echo "$matches" | sed 's/^/  - /'
  fi
}

check "curl/wget piped directly into a shell"             '(curl|wget)[^|]*\|\s*(sudo\s+)?(sh|bash|zsh)'
check "base64 payload decoded and executed"                'base64\s+-d.*\|\s*(sh|bash)'
check "eval of a dynamically decoded string"                'eval\((atob|Buffer\.from)\('
check "npm/yarn install lifecycle script (common, but worth a glance)" '"(pre|post)?install"\s*:'
check "long base64-looking blob embedded in source"         '[A-Za-z0-9+/]{300,}={0,2}'

echo "Heuristic scan complete."
exit 0
