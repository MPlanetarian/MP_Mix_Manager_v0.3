#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Test Suite & Verification Harness
# Tests shell script syntax, python syntax, configuration integrity, and tools
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[38;2;0;229;255m'
RED='\033[38;2;237;37;78m'
YELLOW='\033[38;2;255;170;0m'
NC='\033[0m'
BOLD='\033[1m'

PASSED=0
FAILED=0
SKIPPED=0

report_pass() {
    echo -e "  [${GREEN}PASS${NC}] $1"
    ((PASSED++))
}

report_fail() {
    echo -e "  [${RED}FAIL${NC}] $1: $2"
    ((FAILED++))
}

report_skip() {
    echo -e "  [${YELLOW}SKIP${NC}] $1: $2"
    ((SKIPPED++))
}

echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}   MP MIX ARCHIVE MANAGER v0.3 — AUTOMATED TEST SUITE                 ${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}\n"

# ------------------------------------------------------------------------------
# TEST 1: Shell Scripts Syntax Verification (bash -n)
# ------------------------------------------------------------------------------
echo -e "${BOLD}1. Verifying Shell Script Syntax (bash -n)...${NC}"
sh_files=()
while IFS= read -r f; do
    [ -n "$f" ] && sh_files+=("$f")
done < <(find . -maxdepth 2 -name "*.sh" -not -path '*/.*' | sort)

for sh_file in "${sh_files[@]}"; do
    err_out=$(bash -n "$sh_file" 2>&1)
    if [ $? -eq 0 ]; then
        report_pass "$sh_file syntax valid"
    else
        report_fail "$sh_file" "$err_out"
    fi
done

# ------------------------------------------------------------------------------
# TEST 2: Python Scripts Syntax Verification (py_compile)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}2. Verifying Python Script Syntax (py_compile)...${NC}"
py_files=()
while IFS= read -r f; do
    [ -n "$f" ] && py_files+=("$f")
done < <(find . -maxdepth 2 -name "*.py" -not -path '*/.*' -not -path '*/__pycache__*' | sort)

for py_file in "${py_files[@]}"; do
    err_out=$(python3 -m py_compile "$py_file" 2>&1)
    if [ $? -eq 0 ]; then
        report_pass "$py_file compiles cleanly"
    else
        report_fail "$py_file" "$err_out"
    fi
done

# ------------------------------------------------------------------------------
# TEST 3: Configuration Loading and Defaults
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}3. Verifying Configuration Integrity...${NC}"
if [ -f "config.env" ]; then
    report_pass "config.env exists"
    # Verify key config entries can be parsed
    if grep -q "OUTPUT_DIR=" config.env; then
        report_pass "OUTPUT_DIR defined in config.env"
    else
        report_fail "config.env" "OUTPUT_DIR missing"
    fi
else
    report_fail "config.env" "config.env file missing"
fi

# ------------------------------------------------------------------------------
# TEST 4: Synchronization between root and scripts/
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}4. Checking Synchronization Between Root and scripts/...${NC}"
synced=true
for f in *.sh *.py; do
    if [ -f "scripts/$f" ]; then
        if ! cmp -s "$f" "scripts/$f"; then
            report_fail "Sync Check" "$f differs from scripts/$f"
            synced=false
        fi
    fi
done
if [ "$synced" = true ]; then
    report_pass "All duplicate scripts between root and scripts/ are synchronized"
fi

# ------------------------------------------------------------------------------
# TEST 5: Main Entrypoints Executability
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}5. Verifying Executable Permissions...${NC}"
entrypoints=("Mix_Archive_Manager.sh" "manager.sh")
for ep in "${entrypoints[@]}"; do
    if [ -x "$ep" ]; then
        report_pass "$ep is executable"
    else
        report_fail "$ep" "File is not executable (+x missing)"
    fi
done

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
echo -e "  Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}, ${YELLOW}${SKIPPED} skipped${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}\n"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
