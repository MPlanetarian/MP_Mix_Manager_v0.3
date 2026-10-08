#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Studio & DJ Booth Mobile Web Companion Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/mix_web_companion.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/mix_web_companion.py"

exec python3 "$PY_SCRIPT" "$@"
