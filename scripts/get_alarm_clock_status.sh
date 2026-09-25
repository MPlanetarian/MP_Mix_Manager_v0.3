#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/get_alarm_clock_status.py" ]; then
    python3 "$SCRIPT_DIR/get_alarm_clock_status.py" "$@"
fi
