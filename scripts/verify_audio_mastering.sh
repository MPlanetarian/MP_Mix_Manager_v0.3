#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Audio Mastering Quality & Health Verification Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/verify_audio_mastering.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/verify_audio_mastering.py"

exec python3 "$PY_SCRIPT" "$@"
