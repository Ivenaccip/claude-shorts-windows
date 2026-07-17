# claude-shorts-windows

Standalone interactive shortform video creator, adapted to run natively on Windows (Git Bash + PowerShell). Extracts viral-ready short clips from longform videos using an interactive Claude Code workflow with Remotion-rendered premium captions.

## Architecture

- **Claude Code** is the orchestrator — reads transcripts, scores segments, presents to user interactively
- **faster-whisper** handles GPU-accelerated transcription with word-level timestamps
- **Remotion** renders 1080x1920 vertical video with animated captions (single-pass)
- **FFmpeg** extracts audio, cuts segments (stream copy), and does platform-specific export encoding

## Key Commands

```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1      # One-shot idempotent install (deps, venv, npm ci, config, skill junction)
powershell -ExecutionPolicy Bypass -File uninstall.ps1  # Removes only the skill junction + config
```

The skill at `~/.claude/skills/shorts` is a **junction to this repo** — `git pull` updates it; never copy files there.

## Central Config

`setup.ps1` writes `%APPDATA%\claude-shorts\env.json` with `{root, venv, python, remotion, tmp, whisper_model}`. All paths use forward slashes. Every script and SKILL.md reads paths from there — no venv guessing, no root-dir probing.

## Windows Path Rules (apply to ALL scripts)

- Call Python via the absolute path from `env.json` (`.../Scripts/python.exe`) — never `python3`, never `source .../activate` (Windows venvs use `Scripts/`, not `bin/`).
- Never interpolate file paths into `python -c "..."` — `C:\Users\...` breaks as a unicode escape. Pass paths via `argv`.
- In bash, when reconstructing absolute paths use `pwd -W 2>/dev/null || pwd` (MSYS `pwd` returns `/c/...` which Python resolves to the bogus `C:\c\...`).
- Print/store paths with forward slashes (`Path(...).as_posix()`).

## Remotion

The Remotion project lives in `remotion/` (shared engine, also used by the video-edit skill). `setup.ps1` runs `npm ci` (reproducible, lockfile-driven; skipped when the lockfile is unchanged).

```bash
cd remotion && npx remotion preview  # Preview compositions in browser
node remotion/render.mjs             # Headless render (used by pipeline)
```

## Temp Files

Pipeline stores intermediate files in `$SHORTS_TMP`, defaulting to the `tmp` value in `env.json` (`%TEMP%/claude-shorts` on Windows — NOT `/tmp`, which is MSYS-private and invisible to native Windows processes). Override with `export SHORTS_TMP="path"`.

## Dependencies

`setup.ps1` auto-installs missing system deps via winget (ffmpeg, jq, Python 3.10, Node LTS) and pins Python packages in `requirements.txt`.

- FFmpeg (system) — audio extraction, segment cutting, export encoding
- Python 3.10+ with faster-whisper, mediapipe, numpy, opencv-python (pinned)
- Node.js 18+ with remotion, @remotion/captions, zod (via `npm ci`)
- NVIDIA GPU recommended (NVENC encoding, CUDA transcription; `whisper_model` defaults to `large-v3` with GPU, `small` without)
