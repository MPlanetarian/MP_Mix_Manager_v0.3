#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Google Drive Backup Runner
# Wrapper around scripts/backup_mix_archive.sh for Google Drive
# ==============================================================================

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
BACKUP_SUITE="$SCRIPT_DIR/scripts/backup_mix_archive.sh"
[ ! -f "$BACKUP_SUITE" ] && BACKUP_SUITE="$SCRIPT_DIR/backup_mix_archive.sh"

if [ -f "$BACKUP_SUITE" ]; then
    exec "$BACKUP_SUITE" --provider=gdrive --all "$@"
else
    echo "Error: backup_mix_archive.sh not found."
    exit 1
fi
