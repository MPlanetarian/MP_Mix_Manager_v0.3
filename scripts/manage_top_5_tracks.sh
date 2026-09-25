#!/usr/bin/env bash
# ==============================================================================
# scripts/manage_top_5_tracks.sh
# Mix Archive Manager: Listen to Your Top 5 Tracks Right Now (Special Option)
# Traktor Database Search, Remote Import (SMB, NFS, Mac), Playlists & Joined Mix
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source config if available
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
fi

PY_ENGINE="$SCRIPT_DIR/scripts/top_5_tracks_manager.py"
if [ ! -f "$PY_ENGINE" ]; then
    echo -e "\033[0;31mError: $PY_ENGINE not found!\033[0m"
    exit 1
fi

python3 "$PY_ENGINE" "$@"
