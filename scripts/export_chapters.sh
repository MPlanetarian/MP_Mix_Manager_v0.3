#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Streaming & Platform Chapters Exporter Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/export_chapters.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/export_chapters.py"

exec python3 "$PY_SCRIPT" "$@"
