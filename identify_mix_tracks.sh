#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Audio Fingerprinting & Mix Track Identifier Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/identify_mix_tracks.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/identify_mix_tracks.py"

exec python3 "$PY_SCRIPT" "$@"
