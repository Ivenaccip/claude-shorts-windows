#!/usr/bin/env bash
# Wrapper para Git Bash: el desinstalador real es uninstall.ps1 (Windows).
# NO usar rm -rf sobre la skill: es un junction y rm puede seguirlo
# y borrar el contenido del repo.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && { pwd -W 2>/dev/null || pwd; })"
exec powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/uninstall.ps1"
