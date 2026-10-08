#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Pioneer Rekordbox XML Exporter Wrapper
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/export_rekordbox_playlist.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/export_rekordbox_playlist.py"

exec python3 "$PY_SCRIPT" "$@"
