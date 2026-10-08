#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Lossless Metadata & ReplayGain Tagging Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/tag_audio_metadata.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/tag_audio_metadata.py"

exec python3 "$PY_SCRIPT" "$@"
