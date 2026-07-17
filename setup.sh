#!/usr/bin/env bash
# Wrapper para Git Bash: el setup real es setup.ps1 (Windows).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && { pwd -W 2>/dev/null || pwd; })"
exec powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/setup.ps1"
