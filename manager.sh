#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Local Launcher
# ==============================================================================

# ANSI Color Codes
CYAN='\033[38;5;51m'
PURPLE='\033[38;5;135m'
GREEN='\033[38;5;48m'
RESET='\033[0m'

# Clear terminal screen
clear

# Display CONGEN-style Header Banner (3-row compact isometric font)
printf "${CYAN}%s${RESET}\n" "─────────────────────────────────────────────────────────────────────────────────"
printf "${PURPLE}"
cat << "EOF"
 ▌
 ▌  █▄▀█ █▀█   █▄▀█ █ ▀▄▀   █▀█ █▀▄ █▀▀ █ █ █ █ █▀▀   █▄▀█ █▀█ █▀▄ █▀█ █▀▀ █▀▄
 ▌  █ ▀█ █▀▀   █ ▀█ █ █ █   █▀█ █▀▄ █▄▄ █▀█ █ █ ██▄   █ ▀█ █▀█ █ █ █▀█ █ █ █▀▄
 ▌  ▀  ▀ ▀     ▀  ▀ ▀ ▀ ▀   ▀ ▀ ▀ ▀ ▀▀▀ ▀ ▀ ▀ ▀ ▀▀▀   ▀  ▀ ▀ ▀ ▀ ▀ ▀ ▀ ▀▀▀ ▀ ▀
 ▌
EOF
printf "${CYAN}%s${RESET}\n" "─────────────────────────────────────────────────────────────────────────────────"
printf "${GREEN} MP Mix Archive Manager  v0.3${RESET}\n\n"

# Resolve script path and locate backend
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"

if [ ! -f "$SCRIPT_DIR/Mix_Archive_Manager.sh" ]; then
    for _c in \
        "$HOME/MP_Mix_Manager_v0.1"; do
        if [ -f "$_c/Mix_Archive_Manager.sh" ]; then
            SCRIPT_DIR="$_c"
            break
        fi
    done
fi

unset _RESOLVED_SRC _RESOLVED_DIR _c

# Execute core management script
exec bash "$SCRIPT_DIR/Mix_Archive_Manager.sh" "$@"
