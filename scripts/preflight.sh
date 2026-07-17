#!/usr/bin/env bash
# Pre-flight safety check before shortform pipeline
# Usage: bash scripts/preflight.sh <input_file> [output_dir]
# Output: JSON with pass/fail status and any warnings
set -euo pipefail

INPUT="${1:-}"
OUTPUT_DIR="${2:-./shorts}"

if [ -z "$INPUT" ]; then
    echo '{"pass":false,"error":"Usage: preflight.sh <input_file> [output_dir]"}'
    exit 1
fi

WARNINGS=()
ERRORS=()

# Check input exists
if [ ! -f "$INPUT" ]; then
    ERRORS+=("Input file not found: $INPUT")
fi

# Check input is a video file (via ffprobe)
if [ -f "$INPUT" ]; then
    if ! ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$INPUT" 2>/dev/null | grep -q "video"; then
        ERRORS+=("Input is not a valid video file: $INPUT")
    fi
fi

# Check output directory
if [ -d "$OUTPUT_DIR" ]; then
    EXISTING=$(find "$OUTPUT_DIR" -name "short_*.mp4" 2>/dev/null | wc -l)
    if [ "$EXISTING" -gt 0 ]; then
        WARNINGS+=("Output directory has $EXISTING existing short_*.mp4 files")
    fi
fi

# Central config written by setup.ps1 (single source of truth for paths)
CONFIG="${APPDATA:-$HOME/.config}/claude-shorts/env.json"
PYTHON=""
SHORTS_TMP_DIR=""
if [ -f "$CONFIG" ] && command -v jq &>/dev/null; then
    PYTHON="$(jq -r .python "$CONFIG")"
    SHORTS_TMP_DIR="$(jq -r .tmp "$CONFIG")"
fi

# Check disk space (estimate 3x input size for temp + output)
if [ -f "$INPUT" ]; then
    INPUT_SIZE_KB=$(du -k "$INPUT" | cut -f1)
    NEEDED_KB=$((INPUT_SIZE_KB * 3))
    TMP_CHECK="${SHORTS_TMP:-${SHORTS_TMP_DIR:-${TEMP:-/tmp}}}"
    AVAIL_KB=$(df -k "$TMP_CHECK" 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$AVAIL_KB" ] && [ "$AVAIL_KB" -lt "$NEEDED_KB" ]; then
        WARNINGS+=("Low disk space on $TMP_CHECK: ${AVAIL_KB}KB available, estimated ${NEEDED_KB}KB needed")
    fi
fi

# Check FFmpeg
if ! command -v ffmpeg &>/dev/null; then
    ERRORS+=("ffmpeg not found — run setup.ps1, or: winget install --id Gyan.FFmpeg")
fi

# Check ffprobe
if ! command -v ffprobe &>/dev/null; then
    ERRORS+=("ffprobe not found — run setup.ps1, or: winget install --id Gyan.FFmpeg")
fi

# Check Node.js
if ! command -v node &>/dev/null; then
    ERRORS+=("Node.js not found — run setup.ps1, or: winget install --id OpenJS.NodeJS.LTS")
fi

# Check Python from central config (venv layout differs: Scripts/ on Windows, bin/ on Unix)
if [ -z "$PYTHON" ]; then
    ERRORS+=("Config not found at $CONFIG — run setup.ps1 from the repo root")
elif [ ! -f "$PYTHON" ]; then
    ERRORS+=("Python not found at $PYTHON — re-run setup.ps1")
elif ! "$PYTHON" -c "import faster_whisper" 2>/dev/null; then
    ERRORS+=("faster-whisper not installed — re-run setup.ps1")
fi

# Check Remotion node_modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && { pwd -W 2>/dev/null || pwd; })"
if [ ! -d "$SCRIPT_DIR/remotion/node_modules" ]; then
    ERRORS+=("Remotion dependencies not installed — re-run setup.ps1")
fi

# Get video info
DURATION=""
RESOLUTION=""
if [ -f "$INPUT" ] && command -v ffprobe &>/dev/null; then
    DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$INPUT" 2>/dev/null || echo "")
    RESOLUTION=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$INPUT" 2>/dev/null || echo "")
fi

# Build JSON output
PASS="true"
if [ ${#ERRORS[@]} -gt 0 ]; then
    PASS="false"
fi

ERROR_JSON="[]"
if [ ${#ERRORS[@]} -gt 0 ]; then
    ERROR_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)
fi

WARN_JSON="[]"
if [ ${#WARNINGS[@]} -gt 0 ]; then
    WARN_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
fi

cat <<EOF
{
  "pass": $PASS,
  "input": "$INPUT",
  "output_dir": "$OUTPUT_DIR",
  "duration": ${DURATION:-null},
  "resolution": "${RESOLUTION:-unknown}",
  "python": "${PYTHON:-none}",
  "errors": $ERROR_JSON,
  "warnings": $WARN_JSON
}
EOF

[ "$PASS" = "true" ] && exit 0 || exit 1
