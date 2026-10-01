#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Lossless Legitimacy & Spectral Cutoff Inspector Wrapper
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PY_SCRIPT="$SCRIPT_DIR/verify_lossless_spectral.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$PARENT_DIR/scripts/verify_lossless_spectral.py"
[ ! -f "$PY_SCRIPT" ] && PY_SCRIPT="$SCRIPT_DIR/scripts/verify_lossless_spectral.py"

if [ -f "$PY_SCRIPT" ]; then
    exec python3 "$PY_SCRIPT" "$@"
else
    echo "Error: verify_lossless_spectral.py not found."
    exit 1
fi
