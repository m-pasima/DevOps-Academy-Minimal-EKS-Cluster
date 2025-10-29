#!/usr/bin/env bash
set -euo pipefail

# Resolve directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS_SCRIPT="$SCRIPT_DIR/cleanup.ps1"

if command -v pwsh >/dev/null 2>&1; then
  exec pwsh -NoProfile -File "$PS_SCRIPT" "$@"
else
  exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" "$@"
fi

