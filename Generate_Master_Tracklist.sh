#!/usr/bin/env bash

# Setup colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source config.env if present
for cfg in "$SCRIPT_DIR/config.env" "$PARENT_DIR/config.env" "$PWD/config.env" "${MIX_ARCHIVE_DIR:-}/config.env"; do
    if [ -f "$cfg" ]; then
        # shellcheck source=/dev/null
        source "$cfg"
        break
    fi
done

clear
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "${BOLD}${BLUE}      GENERATE MASTER MULTI-ARCHIVE HTML INDEX    ${NC}"
echo -e "${BOLD}${BLUE}==================================================${NC}"
echo -e "${YELLOW}Parsing tracklist files across all archives and building HTML...${NC}\n"

py_script=""
for cand in "$SCRIPT_DIR/generate_master_tracklist.py" "$SCRIPT_DIR/scripts/generate_master_tracklist.py" "$PARENT_DIR/generate_master_tracklist.py" "$PARENT_DIR/scripts/generate_master_tracklist.py" "$PWD/generate_master_tracklist.py"; do
    if [ -f "$cand" ]; then
        py_script="$cand"
        break
    fi
done

if [ -n "$py_script" ]; then
    python3 -u "$py_script"
    STATUS=$?
else
    echo -e "${BOLD}${RED}Error: generate_master_tracklist.py not found!${NC}"
    STATUS=1
fi

echo -e "${BLUE}--------------------------------------------------${NC}"
if [ $STATUS -eq 0 ]; then
    echo -e "${BOLD}${GREEN}Master Tracklist HTML generated successfully!${NC}"
    echo -e "You can open ${CYAN}master_tracklists.html${NC} in any browser."
else
    echo -e "${BOLD}${RED}Failed to generate Master Tracklist HTML.${NC}"
fi
echo -e "${BLUE}==================================================${NC}"
