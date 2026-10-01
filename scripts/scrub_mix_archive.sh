#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Automated Mix Archive Bit-Rot Scrubber & Health Daemon
# Scans all configured mix archives for silent bit degradation, frame damage,
# and checksum mismatches. Dispatches desktop alerts upon corruption detection.
# Supports Systemd User Timer for periodic background maintenance.
# ==============================================================================

set -uo pipefail

# ANSI Styling
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    BASE_DIR="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
else
    BASE_DIR="$SCRIPT_DIR"
fi

# Source configuration
for cfg in "$BASE_DIR/config.env" "$SCRIPT_DIR/config.env" "$PWD/config.env" "${MIX_ARCHIVE_DIR:-}/config.env"; do
    if [ -f "$cfg" ]; then
        # shellcheck source=/dev/null
        source "$cfg"
        break
    fi
done

LOG_DIR="${BASE_DIR}/VERIFY_LOGS"
mkdir -p "$LOG_DIR" 2>/dev/null || true

SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="mix-archive-scrub.service"
TIMER_NAME="mix-archive-scrub.timer"

# Multi-Archive Directory Discovery
get_all_flac_scan_dirs() {
    local dirs=()
    if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" ]; then
        dirs+=("$(cd "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" && pwd)")
    elif [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
        dirs+=("$(cd "$MIX_ARCHIVE_DIR" && pwd)")
    elif [ -d "${OUTPUT_DIR:-$BASE_DIR/FLAC_CONVERTED_OUTPUTS}" ]; then
        dirs+=("$(cd "${OUTPUT_DIR:-$BASE_DIR/FLAC_CONVERTED_OUTPUTS}" && pwd)")
    fi

    local raw_extras="${EXTRA_MIX_ARCHIVE_DIRS:-${MIX_ARCHIVE_DIRS:-}}"
    if [ -n "$raw_extras" ]; then
        local IFS_BACK="$IFS"
        IFS=':,;'
        for ed in $raw_extras; do
            IFS="$IFS_BACK"
            local clean_ed="${ed#"${ed%%[![:space:]]*}"}"
            clean_ed="${clean_ed%"${clean_ed##*[![:space:]]}"}"
            clean_ed="${clean_ed%\"}"
            clean_ed="${clean_ed#\"}"
            clean_ed="${clean_ed%\'}"
            clean_ed="${clean_ed#\'}"
            if [ -n "$clean_ed" ]; then
                if [ -d "$clean_ed/FLAC_CONVERTED_OUTPUTS" ]; then
                    local cand
                    cand="$(cd "$clean_ed/FLAC_CONVERTED_OUTPUTS" && pwd)"
                    [[ ! " ${dirs[*]} " =~ " ${cand} " ]] && dirs+=("$cand")
                elif [ -d "$clean_ed" ]; then
                    local cand
                    cand="$(cd "$clean_ed" && pwd)"
                    [[ ! " ${dirs[*]} " =~ " ${cand} " ]] && dirs+=("$cand")
                fi
            fi
            IFS=':,;'
        done
        IFS="$IFS_BACK"
    fi

    if [ ${#dirs[@]} -eq 0 ]; then
        dirs+=("$BASE_DIR")
    fi

    for d in "${dirs[@]}"; do
        echo "$d"
    done
}

install_systemd_timer() {
    mkdir -p "$SYSTEMD_USER_DIR"
    
    local exec_bin="$SCRIPT_DIR/scrub_mix_archive.sh"
    [ ! -f "$exec_bin" ] && exec_bin="$BASE_DIR/scripts/scrub_mix_archive.sh"
    
    cat << EOF > "$SYSTEMD_USER_DIR/$SERVICE_NAME"
[Unit]
Description=Stream of Frequency Mix Archive Bit-Rot Scrub
After=local-fs.target

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
IOSchedulingPriority=7
ExecStart=/usr/bin/env bash "$exec_bin" --silent
EOF

    cat << EOF > "$SYSTEMD_USER_DIR/$TIMER_NAME"
[Unit]
Description=Weekly Stream of Frequency Mix Archive Bit-Rot Scrub Timer

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true
RandomizedDelaySec=1800

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now "$TIMER_NAME" 2>/dev/null || true
    echo -e "${BOLD}${GREEN}✓ Successfully installed and activated systemd user timer:${NC} ${CYAN}$TIMER_NAME${NC}"
    echo -e "  Schedule: ${YELLOW}Every Sunday at 03:00 AM (Idle background I/O)${NC}"
}

uninstall_systemd_timer() {
    systemctl --user stop "$TIMER_NAME" 2>/dev/null || true
    systemctl --user disable "$TIMER_NAME" 2>/dev/null || true
    rm -f "$SYSTEMD_USER_DIR/$SERVICE_NAME" "$SYSTEMD_USER_DIR/$TIMER_NAME"
    systemctl --user daemon-reload 2>/dev/null || true
    echo -e "${BOLD}${YELLOW}✓ Uninstalled systemd user timer:${NC} ${TIMER_NAME}"
}

show_timer_status() {
    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}          MIX ARCHIVE BIT-ROT SCRUB SYSTEMD TIMER STATUS              ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    if systemctl --user is-active --quiet "$TIMER_NAME" 2>/dev/null; then
        echo -e "  Timer Status:  ${BOLD}${GREEN}ACTIVE / SCHEDULED${NC}"
        systemctl --user status "$TIMER_NAME" 2>/dev/null | grep -E "Loaded:|Active:|Trigger:" || true
    else
        echo -e "  Timer Status:  ${BOLD}${YELLOW}INACTIVE / NOT INSTALLED${NC}"
        echo -e "  Run with ${CYAN}--install-timer${NC} or use Option 8 in the Mix Manager to activate."
    fi
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
}

run_scrub() {
    local silent_mode="${1:-false}"
    
    # Deprioritize background process to ensure zero desktop/gaming impact
    renice -n 19 $$ >/dev/null 2>&1 || true
    ionice -c 3 -p $$ >/dev/null 2>&1 || true

    local today
    today="$(date '+%Y-%m-%d')"
    local log_file="${LOG_DIR}/scrub_${today}_$(date '+%H%M%S').log"

    if [ "$silent_mode" != "true" ]; then
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             MIX ARCHIVE BIT-ROT & AUDIO HEALTH SCRUB                 ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "  Mode:        ${BOLD}${CYAN}Non-Destructive Full FLAC Stream Verification${NC}"
        echo -e "  Priority:    ${DIM}Background Idle (Nice 19, ionice 3)${NC}"
        echo -e "  Log File:    ${DIM}${log_file}${NC}"
        echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}\n"
    fi

    {
        echo "======================================================================"
        echo "MIX ARCHIVE BIT-ROT AUDIT LOG"
        echo "Date:       $(date)"
        echo "Hostname:   $(hostname 2>/dev/null || echo 'localhost')"
        echo "======================================================================"
    } > "$log_file"

    local scan_dirs=()
    while IFS= read -r sd; do
        [ -n "$sd" ] && [ -d "$sd" ] && scan_dirs+=("$sd")
    done < <(get_all_flac_scan_dirs)

    local flac_files=()
    for sd in "${scan_dirs[@]}"; do
        shopt -s nullglob nocaseglob
        for f in "$sd"/*.flac; do
            [ -f "$f" ] && flac_files+=("$f")
        done
        shopt -u nullglob nocaseglob
    done

    if [ ${#flac_files[@]} -eq 0 ]; then
        echo "No FLAC audio files discovered in archive directories." >> "$log_file"
        [ "$silent_mode" != "true" ] && echo -e "${YELLOW}No FLAC files found in archives.${NC}"
        return 0
    fi

    if [ "$silent_mode" != "true" ]; then
        echo -e "Discovered ${BOLD}${WHITE}${#flac_files[@]}${NC} FLAC mixes across ${#scan_dirs[@]} storage archive(s)."
        echo -e "Auditing stream CRC frames and audio integrity...\n"
    fi

    local checked=0
    local corrupted=0
    local corrupt_list=()

    for flac in "${flac_files[@]}"; do
        ((checked++))
        local fname
        fname="$(basename "$flac")"
        
        # Check using flac -t or ffmpeg
        local is_ok=1
        local err_msg=""

        if command -v flac >/dev/null 2>&1; then
            if ! flac -t --totally-silent "$flac" 2>/dev/null; then
                is_ok=0
                err_msg="FLAC MD5/frame decode failure"
            fi
        else
            err_out="$(ffmpeg -v error -i "$flac" -f null - 2>&1 || true)"
            if [ -n "$err_out" ]; then
                is_ok=0
                err_msg="$err_out"
            fi
        fi

        if [ "$is_ok" -eq 1 ]; then
            if [ "$silent_mode" != "true" ]; then
                printf "  [%3d/%3d] %-52s ${GREEN}✓ HEALTHY${NC}\n" "$checked" "${#flac_files[@]}" "${fname:0:50}"
            fi
        else
            ((corrupted++))
            corrupt_list+=("$flac")
            echo "[CORRUPTION] $flac - $err_msg" >> "$log_file"
            if [ "$silent_mode" != "true" ]; then
                printf "  [%3d/%3d] %-52s ${RED}❌ BIT-ROT DETECTED${NC}\n" "$checked" "${#flac_files[@]}" "${fname:0:50}"
            fi
        fi
    done

    {
        echo "----------------------------------------------------------------------"
        echo "Total Checked:   $checked"
        echo "Corrupted Files: $corrupted"
        echo "Completed At:    $(date)"
        echo "======================================================================"
    } >> "$log_file"

    # Notification Handling
    if [ "$corrupted" -gt 0 ]; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send --urgency=critical -i dialog-warning \
                "⚠️ Mix Archive Bit-Rot Alert!" \
                "Detected $corrupted corrupted FLAC mix(es)!\nCheck log: $log_file" 2>/dev/null || true
        fi
        if [ "$silent_mode" != "true" ]; then
            echo -e "\n${BOLD}${RED}⚠️  SCRUB FINISHED WITH CORRUPTION DETECTED IN $corrupted FILE(S)!${NC}"
            echo -e "Review log at: ${CYAN}$log_file${NC}"
        fi
        return 1
    else
        if [ "$silent_mode" != "true" ]; then
            echo -e "\n${BOLD}${GREEN}✓ Mix Archive Scrub Completed! All $checked FLAC mixes verified 100% healthy.${NC}"
        fi
        return 0
    fi
}

# Main CLI dispatch
case "${1:-}" in
    --install-timer|--enable-timer)
        install_systemd_timer
        ;;
    --uninstall-timer|--disable-timer)
        uninstall_systemd_timer
        ;;
    --timer-status)
        show_timer_status
        ;;
    --silent)
        run_scrub true
        ;;
    --logs)
        echo -e "\n${BOLD}${CYAN}Recent Bit-Rot Scrub Logs in ${LOG_DIR}:${NC}"
        ls -lt "$LOG_DIR" | head -n 15
        ;;
    *)
        run_scrub false
        ;;
esac
