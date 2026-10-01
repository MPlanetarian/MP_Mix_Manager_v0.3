#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Audio Mastering & EBU R128 Loudness Suite Wrapper
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PY_SCRIPT="$SCRIPT_DIR/master_audio_loudness.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$PARENT_DIR/scripts/master_audio_loudness.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/master_audio_loudness.py"

if [ -f "$PY_SCRIPT" ]; then
    exec python3 "$PY_SCRIPT" "$@"
else
    echo "Error: master_audio_loudness.py not found."
    exit 1
fi
