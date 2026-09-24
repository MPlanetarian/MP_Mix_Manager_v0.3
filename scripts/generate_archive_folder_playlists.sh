#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Mix Archive Folder Playlists Generator Launcher
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/generate_archive_folder_playlists.py"

if [ ! -f "$PY_SCRIPT" ]; then
    PY_SCRIPT="$SCRIPT_DIR/scripts/generate_archive_folder_playlists.py"
fi

exec python3 "$PY_SCRIPT" "$@"
