#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Standard CUE Sheet Generator & Splitter Wrapper
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PY_SCRIPT="$SCRIPT_DIR/generate_cue_sheet.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$PARENT_DIR/scripts/generate_cue_sheet.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/generate_cue_sheet.py"

if [ -f "$PY_SCRIPT" ]; then
    exec python3 "$PY_SCRIPT" "$@"
else
    echo "Error: generate_cue_sheet.py not found."
    exit 1
fi
