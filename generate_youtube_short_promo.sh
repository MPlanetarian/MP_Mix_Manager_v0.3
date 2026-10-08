#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - YouTube Shorts Promotional Video Generator Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/generate_youtube_short_promo.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/generate_youtube_short_promo.py"

exec python3 "$PY_SCRIPT" "$@"
