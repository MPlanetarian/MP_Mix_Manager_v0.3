#!/usr/bin/env bash
# ==============================================================================
# get_mp_audio_player_file.sh - Shell Launcher for Querying MP Audio Player
# Part of MP_Mix_Manager_v0.3
# ==============================================================================

set -o pipefail 2>/dev/null || true

_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR

PY_SCRIPT="$SCRIPT_DIR/get_mp_audio_player_file.py"
if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/get_mp_audio_player_file.py"
fi

if [ -f "$PY_SCRIPT" ] && command -v python3 >/dev/null 2>&1; then
    exec python3 "$PY_SCRIPT" "$@"
else
    echo "Error: Python 3 or get_mp_audio_player_file.py missing." >&2
    exit 1
fi
