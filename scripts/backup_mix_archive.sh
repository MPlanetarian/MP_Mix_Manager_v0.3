#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Multi-Cloud & Storage Mix Archive Backup Suite
# Supports Google Drive, iCloud, Dropbox, and Custom Specified Destination Folders
# Features:
#   - Backup All Mix Archive Folders (Multi-Archive Discovery)
#   - Custom Selection (1 or More Mixes by Number, List, Range, or Search Keyword)
#   - Optional Companion Assets Sync (Tracklists TXT/HTML/PDF, Covers, Spek)
#   - Dual Engine: Native rsync/cp for Local/Cloud Folders, rclone for Cloud Remotes
#   - Real-time Progress, Bandwidth Limiting & Timestamped Session Logging
#   - Cross-Platform: Linux (Bazzite/Fedora/Ubuntu), macOS (Bash 3.2+), Windows
# ==============================================================================

set -euo pipefail

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

# Resolve codebase directory
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    BASE_DIR="$(cd -P "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
else
    BASE_DIR="$SCRIPT_DIR"
fi
unset _RESOLVED_SRC _RESOLVED_DIR

# Source config.env
for cfg in "$BASE_DIR/config.env" "$SCRIPT_DIR/config.env" "$PWD/config.env" "${MIX_ARCHIVE_DIR:-}/config.env"; do
    if [ -f "$cfg" ]; then
        # shellcheck source=/dev/null
        source "$cfg"
        break
    fi
done

# Defaults & Configured Settings
LOG_DIR="${BASE_DIR}/BACKUP_LOGS"
mkdir -p "$LOG_DIR" 2>/dev/null || true

GDRIVE_REMOTE="${GDRIVE_REMOTE:-gdrive:MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS}"
BW_LIMIT="${BW_LIMIT:-0}"
INCLUDE_COMPANIONS="${INCLUDE_COMPANIONS:-true}"

# Platform-aware defaults for iCloud and Dropbox
detect_default_cloud_paths() {
    local os_type
    os_type="$(uname -s)"
    
    # Default iCloud path
    if [ -z "${ICLOUD_PATH:-}" ]; then
        if [ "$os_type" = "Darwin" ]; then
            ICLOUD_PATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs/MIX_ARCHIVE"
        elif [ -d "$HOME/iCloud/MIX_ARCHIVE" ] || [ -d "$HOME/iCloud" ]; then
            ICLOUD_PATH="$HOME/iCloud/MIX_ARCHIVE"
        elif [ -n "${USERPROFILE:-}" ] && [ -d "$USERPROFILE/iCloudDrive" ]; then
            ICLOUD_PATH="$USERPROFILE/iCloudDrive/MIX_ARCHIVE"
        else
            ICLOUD_PATH="$HOME/iCloud_Drive/MIX_ARCHIVE"
        fi
    fi

    # Default Dropbox path
    if [ -z "${DROPBOX_PATH:-}" ]; then
        if [ "$os_type" = "Darwin" ] && [ -d "$HOME/Library/CloudStorage/Dropbox" ]; then
            DROPBOX_PATH="$HOME/Library/CloudStorage/Dropbox/MIX_ARCHIVE"
        elif [ -d "$HOME/Dropbox" ]; then
            DROPBOX_PATH="$HOME/Dropbox/MIX_ARCHIVE"
        elif [ -n "${USERPROFILE:-}" ] && [ -d "$USERPROFILE/Dropbox" ]; then
            DROPBOX_PATH="$USERPROFILE/Dropbox/MIX_ARCHIVE"
        elif command -v rclone >/dev/null 2>&1 && rclone listremotes 2>/dev/null | grep -qi "^dropbox:"; then
            DROPBOX_PATH="dropbox:MIX_ARCHIVE"
        else
            DROPBOX_PATH="$HOME/Dropbox/MIX_ARCHIVE"
        fi
    fi
}
detect_default_cloud_paths

# Multi-Archive Directory Discovery Helpers
get_all_mix_archive_dirs() {
    local dirs=()
    if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
        dirs+=("$MIX_ARCHIVE_DIR")
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
            if [ -n "$clean_ed" ] && [ -d "$clean_ed" ]; then
                dirs+=("$clean_ed")
            fi
            IFS=':,;'
        done
        IFS="$IFS_BACK"
    fi
    if [ ${#dirs[@]} -eq 0 ]; then
        [ -d "$BASE_DIR/MIX_ARCHIVE" ] && dirs+=("$BASE_DIR/MIX_ARCHIVE")
        [ -d "$PWD" ] && dirs+=("$PWD")
    fi

    local seen=()
    for d in "${dirs[@]}"; do
        local real_d
        real_d="$(cd "$d" 2>/dev/null && pwd -P || echo "$d")"
        local found=0
        for s in "${seen[@]}"; do
            [ "$s" = "$real_d" ] && found=1 && break
        done
        if [ "$found" -eq 0 ]; then
            seen+=("$real_d")
            echo "$d"
        fi
    done
}

get_all_flac_output_dirs() {
    local f_dirs=()
    while IFS= read -r adir; do
        [ -z "$adir" ] && continue
        if [ -d "$adir/FLAC_CONVERTED_OUTPUTS" ]; then
            f_dirs+=("$adir/FLAC_CONVERTED_OUTPUTS")
        elif [[ "$adir" =~ FLAC_CONVERTED_OUTPUTS/?$ ]]; then
            f_dirs+=("$adir")
        elif [ -d "$adir" ]; then
            f_dirs+=("$adir")
        fi
    done < <(get_all_mix_archive_dirs)

    if [ ${#f_dirs[@]} -eq 0 ]; then
        [ -d "$BASE_DIR/FLAC_CONVERTED_OUTPUTS" ] && f_dirs+=("$BASE_DIR/FLAC_CONVERTED_OUTPUTS")
        [ -d "$PWD/FLAC_CONVERTED_OUTPUTS" ] && f_dirs+=("$PWD/FLAC_CONVERTED_OUTPUTS")
        [ -d "$PWD" ] && f_dirs+=("$PWD")
    fi

    local seen=()
    for fd in "${f_dirs[@]}"; do
        local real_f
        real_f="$(cd "$fd" 2>/dev/null && pwd -P || echo "$fd")"
        local found=0
        for s in "${seen[@]}"; do
            [ "$s" = "$real_f" ] && found=1 && break
        done
        if [ "$found" -eq 0 ]; then
            seen+=("$real_f")
            echo "$fd"
        fi
    done
}

# Collect all unique mixes across all FLAC output directories
collect_all_mixes() {
    local raw_files=()
    while IFS= read -r f_dir; do
        [ -z "$f_dir" ] || [ ! -d "$f_dir" ] && continue
        while IFS= read -r mf; do
            [ -n "$mf" ] && [ -f "$mf" ] && raw_files+=("$mf")
        done < <(find "$f_dir" -maxdepth 1 -type f \( -name "*.flac" -o -name "*.FLAC" \) 2>/dev/null | sort)
    done < <(get_all_flac_output_dirs)

    # Deduplicate by basename
    local seen_names=()
    for mf in "${raw_files[@]}"; do
        local bn
        bn="$(basename "$mf")"
        local already=0
        for sn in "${seen_names[@]}"; do
            [ "$sn" = "$bn" ] && already=1 && break
        done
        if [ "$already" -eq 0 ]; then
            seen_names+=("$bn")
            echo "$mf"
        fi
    done
}

# Resolve companion assets for a mix file (.txt, .html, .pdf, cover .png, spek .png)
find_mix_companions() {
    local mix_file="$1"
    local base_stem
    base_stem="$(basename "${mix_file%.*}")"
    local parent_dir
    parent_dir="$(dirname "$mix_file")"
    local grand_dir
    grand_dir="$(cd "$parent_dir/.." 2>/dev/null && pwd || echo "$parent_dir")"

    local companions=()

    # Tracklists
    for ext in txt html pdf; do
        if [ -f "${parent_dir}/${base_stem}.${ext}" ]; then
            companions+=("${parent_dir}/${base_stem}.${ext}")
        elif [ -f "${grand_dir}/${base_stem}.${ext}" ]; then
            companions+=("${grand_dir}/${base_stem}.${ext}")
        fi
    done

    # Cover Art
    for c_cand in "${parent_dir}/${base_stem}.png" "${parent_dir}/${base_stem}.jpg" \
                  "${grand_dir}/COVERS/${base_stem}.png" "${grand_dir}/COVERS/${base_stem}.jpg" \
                  "${BASE_DIR}/COVERS/${base_stem}.png" "${BASE_DIR}/COVERS/${base_stem}.jpg" \
                  "${BASE_DIR}/Cover.png" "${BASE_DIR}/assets/Cover.png"; do
        if [ -f "$c_cand" ]; then
            companions+=("$c_cand")
            break
        fi
    done

    # Spek Spectrogram
    for s_cand in "${parent_dir}/${base_stem}_spek.png" \
                  "${grand_dir}/SPEK_OUTPUTS/${base_stem}.png" \
                  "${BASE_DIR}/SPEK_OUTPUTS/${base_stem}.png"; do
        if [ -f "$s_cand" ]; then
            companions+=("$s_cand")
            break
        fi
    done

    for c in "${companions[@]}"; do
        echo "$c"
    done
}

# Determine if destination is an rclone remote or filesystem path
is_rclone_remote() {
    local target="$1"
    # An rclone remote has a colon, but NOT a Windows drive letter like C:/ or D:/
    if [[ "$target" =~ ^[a-zA-Z0-9_-]+: && ! "$target" =~ ^[a-zA-Z]:[/\] ]]; then
        return 0
    fi
    return 1
}

# Execute copy operation for a single file or directory
# Usage: execute_transfer <src_path> <dest_target> <log_file> [is_dir]
execute_transfer() {
    local src_item="$1"
    local dest_target="$2"
    local log_file="$3"
    local is_directory="${4:-0}"

    if is_rclone_remote "$dest_target"; then
        if ! command -v rclone >/dev/null 2>&1; then
            echo -e "${RED}Error: 'rclone' is required to transfer to remote: ${dest_target}${NC}" | tee -a "$log_file"
            return 1
        fi
        local bw_flag=()
        [ "$BW_LIMIT" != "0" ] && bw_flag=("--bwlimit" "$BW_LIMIT")

        if [ "$is_directory" -eq 1 ]; then
            rclone copy "$src_item" "$dest_target" "${bw_flag[@]}" --progress --log-file="$log_file" --log-level=INFO
        else
            local dest_file="${dest_target}/$(basename "$src_item")"
            rclone copyto "$src_item" "$dest_file" "${bw_flag[@]}" --progress --log-file="$log_file" --log-level=INFO
        fi
    else
        # Local or mounted filesystem destination
        dest_target="${dest_target/#\~/$HOME}"
        mkdir -p "$dest_target" 2>/dev/null || true

        if command -v rsync >/dev/null 2>&1; then
            local bw_rsync=()
            [ "$BW_LIMIT" != "0" ] && bw_rsync=("--bwlimit=${BW_LIMIT%M}")
            if [ "$is_directory" -eq 1 ]; then
                rsync -avh --progress "${bw_rsync[@]}" "$src_item/" "$dest_target/" 2>&1 | tee -a "$log_file"
            else
                rsync -avh --progress "${bw_rsync[@]}" "$src_item" "$dest_target/" 2>&1 | tee -a "$log_file"
            fi
        else
            if [ "$is_directory" -eq 1 ]; then
                cp -Rvp "$src_item"/* "$dest_target/" 2>&1 | tee -a "$log_file"
            else
                cp -vp "$src_item" "$dest_target/" 2>&1 | tee -a "$log_file"
            fi
        fi
    fi
}

# Run the complete backup job
run_backup_job() {
    local provider_name="$1"
    local dest_target="$2"
    local scope_mode="$3" # "all" or "custom"
    shift 3
    local selected_mixes=("$@")

    local today
    today="$(date '+%Y-%m-%d')"
    local p_clean
    p_clean="$(echo "$provider_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_')"
    local log_file="${LOG_DIR}/backup_${p_clean}_${today}_$(date '+%H%M%S').log"

    local start_date start_time start_seconds
    start_date="$(date '+%A, %Y-%m-%d')"
    start_time="$(date '+%H:%M:%S')"
    start_seconds="$(date +%s)"

    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}          MIX ARCHIVE BACKUP SUITE - TRANSFER IN PROGRESS             ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "  Provider:      ${BOLD}${CYAN}${provider_name}${NC}"
    echo -e "  Destination:   ${BOLD}${WHITE}${dest_target}${NC}"
    echo -e "  Scope:         ${BOLD}${YELLOW}$( [ "$scope_mode" = "all" ] && echo "ALL Mix Archive Folders" || echo "Custom Selection (${#selected_mixes[@]} Mixes)" )${NC}"
    echo -e "  Companions:    ${BOLD}${GREEN}$( [ "$INCLUDE_COMPANIONS" = "true" ] && echo "Included (Tracklists, Covers, Spek)" || echo "Audio Only" )${NC}"
    echo -e "  Bandwidth:     ${DIM}$( [ "$BW_LIMIT" = "0" ] && echo "Unlimited" || echo "$BW_LIMIT" )${NC}"
    echo -e "  Session Log:   ${DIM}${log_file}${NC}"
    echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}\n"

    {
        echo "======================================================================"
        echo "MIX ARCHIVE BACKUP SESSION LOG"
        echo "Date:        $start_date"
        echo "Start Time:  $start_time"
        echo "Provider:    $provider_name"
        echo "Destination: $dest_target"
        echo "Scope:       $scope_mode"
        echo "Companions:  $INCLUDE_COMPANIONS"
        echo "======================================================================"
        echo ""
    } > "$log_file"

    local transfer_success=1
    local total_files_transferred=0

    if [ "$scope_mode" = "all" ]; then
        local all_fdirs=()
        while IFS= read -r fd; do
            [ -n "$fd" ] && [ -d "$fd" ] && all_fdirs+=("$fd")
        done < <(get_all_flac_output_dirs)

        echo -e "${CYAN}Syncing all FLAC output directories across storage drives...${NC}"
        for fd in "${all_fdirs[@]}"; do
            echo -e "\n${BOLD}➔ Syncing archive directory:${NC} ${GREEN}${fd}${NC}"
            echo "--- Source: $fd ---" >> "$log_file"
            if ! execute_transfer "$fd" "$dest_target" "$log_file" 1; then
                transfer_success=0
            fi
        done

        if [ "$INCLUDE_COMPANIONS" = "true" ]; then
            echo -e "\n${CYAN}Syncing companion visual and documentary assets...${NC}"
            while IFS= read -r adir; do
                [ -z "$adir" ] || [ ! -d "$adir" ] && continue
                if [ -d "$adir/COVERS" ]; then
                    echo -e "  • Syncing covers from: ${DIM}${adir}/COVERS${NC}"
                    execute_transfer "$adir/COVERS" "${dest_target}/COVERS" "$log_file" 1 || true
                fi
                if [ -d "$adir/SPEK_OUTPUTS" ]; then
                    echo -e "  • Syncing spek from:   ${DIM}${adir}/SPEK_OUTPUTS${NC}"
                    execute_transfer "$adir/SPEK_OUTPUTS" "${dest_target}/SPEK_OUTPUTS" "$log_file" 1 || true
                fi
            done < <(get_all_mix_archive_dirs)
        fi
    else
        # Custom Selection of Mixes
        local current_idx=1
        local total_items="${#selected_mixes[@]}"

        for mix_file in "${selected_mixes[@]}"; do
            [ ! -f "$mix_file" ] && continue
            local bname
            bname="$(basename "$mix_file")"
            local fsize
            fsize="$(du -h "$mix_file" 2>/dev/null | awk '{print $1}')"

            echo -e "${BOLD}${CYAN}[${current_idx}/${total_items}]${NC} Backing up: ${WHITE}${bname}${NC} ${DIM}(${fsize})${NC}"
            echo "[${current_idx}/${total_items}] $mix_file" >> "$log_file"

            if ! execute_transfer "$mix_file" "$dest_target" "$log_file" 0; then
                transfer_success=0
                echo -e "      ${RED}⚠️  Transfer failed for ${bname}${NC}"
            else
                total_files_transferred=$((total_files_transferred + 1))
            fi

            # Companions
            if [ "$INCLUDE_COMPANIONS" = "true" ]; then
                local companions=()
                while IFS= read -r comp; do
                    [ -n "$comp" ] && [ -f "$comp" ] && companions+=("$comp")
                done < <(find_mix_companions "$mix_file")

                for comp in "${companions[@]}"; do
                    local cbname
                    cbname="$(basename "$comp")"
                    echo -e "      ↳ Companion: ${DIM}${cbname}${NC}"
                    if execute_transfer "$comp" "$dest_target" "$log_file" 0; then
                        total_files_transferred=$((total_files_transferred + 1))
                    fi
                done
            fi
            current_idx=$((current_idx + 1))
        done
    fi

    local end_time end_seconds total_runtime hours mins secs formatted_runtime
    end_time="$(date '+%H:%M:%S')"
    end_seconds="$(date +%s)"
    total_runtime=$((end_seconds - start_seconds))
    hours=$((total_runtime / 3600))
    mins=$(((total_runtime % 3600) / 60))
    secs=$((total_runtime % 60))
    formatted_runtime="${hours}h ${mins}m ${secs}s"

    local summary_status="SUCCESS"
    [ "$transfer_success" -eq 0 ] && summary_status="FAILED / COMPLETED WITH WARNINGS"

    local summary_block
    summary_block=$(cat << EOF

======================================================================
BACKUP SESSION SUMMARY REPORT
======================================================================
Status:            $summary_status
Cloud Provider:    $provider_name
Destination:       $dest_target
Scope:             $scope_mode
Date:              $start_date
Start Time:        $start_time
End Time:          $end_time
Total Runtime:     $formatted_runtime
Files Transferred: $total_files_transferred items
Session Log:       $log_file
======================================================================
EOF
)
    echo "$summary_block" >> "$log_file"

    echo ""
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    if [ "$transfer_success" -eq 1 ]; then
        echo -e "${BOLD}${GREEN}✓ Mix Archive Backup Completed Successfully!${NC}"
    else
        echo -e "${BOLD}${YELLOW}⚠️  Backup Finished with Warnings or Errors. Check session log.${NC}"
    fi
    echo -e "$summary_block"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
}

# Interactive Selection of Mixes (1 or More)
interactive_select_mixes() {
    local all_mixes=()
    while IFS= read -r mf; do
        [ -n "$mf" ] && all_mixes+=("$mf")
    done < <(collect_all_mixes)

    if [ ${#all_mixes[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}No FLAC mixes found in configured Mix Archive directories.${NC}"
        sleep 2
        return 1
    fi

    local filter=""
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}          SELECT MIXES FOR BACKUP (1 OR MORE, LIST, RANGE)            ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "  Total Available Mixes: ${BOLD}${GREEN}${#all_mixes[@]}${NC} mixes across all storage drives"
        [ -n "$filter" ] && echo -e "  Active Filter:         ${BOLD}${YELLOW}${filter}${NC} ${DIM}(type 'clear' to reset)${NC}"
        echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"

        local displayed_mixes=()
        local displayed_indices=()
        local idx=1
        for mf in "${all_mixes[@]}"; do
            local bname
            bname="$(basename "$mf")"
            if [ -n "$filter" ]; then
                if ! echo "$bname" | grep -qi "$filter"; then
                    ((idx++))
                    continue
                fi
            fi
            displayed_mixes+=("$mf")
            displayed_indices+=("$idx")
            ((idx++))
        done

        local count=${#displayed_mixes[@]}
        local max_show=30
        local page_count=$(( (count + max_show - 1) / max_show ))
        [ "$page_count" -eq 0 ] && page_count=1

        # Display first page or all if small
        local show_limit=$count
        [ "$show_limit" -gt "$max_show" ] && show_limit=$max_show

        for ((i=0; i<show_limit; i++)); do
            local cur_file="${displayed_mixes[$i]}"
            local cur_idx="${displayed_indices[$i]}"
            local bname
            bname="$(basename "$cur_file")"
            local fsize
            fsize="$(du -h "$cur_file" 2>/dev/null | awk '{print $1}')"
            local parent_drive
            parent_drive="$(basename "$(dirname "$cur_file")")"
            printf "  ${BOLD}${CYAN}%3d)${NC} %-52s ${DIM}%6s${NC} [${GREEN}%s${NC}]\n" "$cur_idx" "${bname:0:52}" "$fsize" "$parent_drive"
        done

        if [ "$count" -gt "$max_show" ]; then
            echo -e "\n  ${DIM}... Showing first ${max_show} of ${count} matching mixes. Use search or enter numbers directly.${NC}"
        fi

        echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}Selection Options:${NC}"
        echo -e "    • ${BOLD}${GREEN}all${NC} or ${BOLD}${GREEN}a${NC}     : Select ALL ${count} mixes"
        echo -e "    • Single number : e.g. ${BOLD}${WHITE}15${NC}"
        echo -e "    • Multiple list : e.g. ${BOLD}${WHITE}1, 4, 7, 12${NC} or ${BOLD}${WHITE}1 4 7 12${NC}"
        echo -e "    • Number Range  : e.g. ${BOLD}${WHITE}1-10${NC} or ${BOLD}${WHITE}20-25${NC}"
        echo -e "    • Search filter : e.g. ${BOLD}${WHITE}/137${NC} or ${BOLD}${WHITE}/Trance${NC} or ${BOLD}${WHITE}f 050${NC}"
        echo -e "    • ${BOLD}0${NC} or ${BOLD}q${NC}       : Cancel and return\n"

        read -r -p "Enter selection: " user_sel
        user_sel="${user_sel#"${user_sel%%[![:space:]]*}"}"
        user_sel="${user_sel%"${user_sel##*[![:space:]]}"}"

        [ -z "$user_sel" ] || [ "$user_sel" = "0" ] || [ "$user_sel" = "q" ] && return 1

        if [ "$user_sel" = "clear" ]; then
            filter=""
            continue
        fi

        if [[ "$user_sel" =~ ^(/|f[[:space:]]+|s[[:space:]]+) ]]; then
            filter="$(echo "$user_sel" | sed -E 's|^/||; s|^[fs][[:space:]]+||')"
            continue
        fi

        local chosen_files=()

        if [ "$user_sel" = "all" ] || [ "$user_sel" = "a" ]; then
            chosen_files=("${displayed_mixes[@]}")
        else
            # Parse commas, spaces, and ranges
            local raw_tokens
            raw_tokens="$(echo "$user_sel" | tr ',' ' ')"
            for token in $raw_tokens; do
                if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    local r_start="${BASH_REMATCH[1]}"
                    local r_end="${BASH_REMATCH[2]}"
                    if [ "$r_start" -gt "$r_end" ]; then
                        local tmp="$r_start"
                        r_start="$r_end"
                        r_end="$tmp"
                    fi
                    for ((k=r_start; k<=r_end; k++)); do
                        if [ "$k" -ge 1 ] && [ "$k" -le "${#all_mixes[@]}" ]; then
                            chosen_files+=("${all_mixes[$((k - 1))]}")
                        fi
                    done
                elif [[ "$token" =~ ^[0-9]+$ ]]; then
                    local k="$token"
                    if [ "$k" -ge 1 ] && [ "$k" -le "${#all_mixes[@]}" ]; then
                        chosen_files+=("${all_mixes[$((k - 1))]}")
                    fi
                fi
            done
        fi

        if [ ${#chosen_files[@]} -eq 0 ]; then
            echo -e "\n${RED}No valid mixes selected from input '${user_sel}'. Try again.${NC}"
            sleep 1.8
            continue
        fi

        # Deduplicate chosen files
        local final_chosen=()
        for cf in "${chosen_files[@]}"; do
            local already=0
            for fc in "${final_chosen[@]}"; do
                [ "$fc" = "$cf" ] && already=1 && break
            done
            [ "$already" -eq 0 ] && final_chosen+=("$cf")
        done

        SELECTED_MIXES_GLOBAL=("${final_chosen[@]}")
        return 0
    done
}

# Main Interactive Menu
interactive_menu() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}      MIX ARCHIVE BACKUP SUITE (GOOGLE DRIVE • ICLOUD • DROPBOX)      ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "  Current Configured Destinations:"
        echo -e "    • ${BOLD}Google Drive${NC} : ${CYAN}${GDRIVE_REMOTE}${NC}"
        echo -e "    • ${BOLD}iCloud Drive${NC} : ${GREEN}${ICLOUD_PATH}${NC}"
        echo -e "    • ${BOLD}Dropbox${NC}      : ${YELLOW}${DROPBOX_PATH}${NC}"
        if [ -n "${CLOUD_BACKUP_DEST:-}" ]; then
            echo -e "    • ${BOLD}Custom Path${NC}  : ${WHITE}${CLOUD_BACKUP_DEST}${NC}"
        fi
        echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}Select Cloud Provider or Destination:${NC}"
        echo -e "    ${BOLD}${CYAN}1)${NC} Google Drive  ${DIM}(rclone: ${GDRIVE_REMOTE})${NC}"
        echo -e "    ${BOLD}${CYAN}2)${NC} iCloud Drive  ${DIM}(Folder / Sync: ${ICLOUD_PATH})${NC}"
        echo -e "    ${BOLD}${CYAN}3)${NC} Dropbox       ${DIM}(Folder / rclone: ${DROPBOX_PATH})${NC}"
        echo -e "    ${BOLD}${CYAN}4)${NC} Custom Specified Destination Folder ${GREEN}(Local, External SSD, SMB, Remote)${NC}"
        echo -e ""
        echo -e "    ${BOLD}${CYAN}5)${NC} Edit & Configure Cloud Destination Paths in config.env"
        echo -e "    ${BOLD}${CYAN}6)${NC} View Recent Cloud Backup Logs (${LOG_DIR})"
        echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
        echo -e "    ${BOLD}0)${NC} Return / Exit ${DIM}(or q)${NC}\n"

        read -r -p "Enter choice [1-6, 0]: " prov_choice
        case "$prov_choice" in
            1)
                selected_provider="Google Drive"
                selected_dest="$GDRIVE_REMOTE"
                ;;
            2)
                selected_provider="iCloud Drive"
                selected_dest="$ICLOUD_PATH"
                ;;
            3)
                selected_provider="Dropbox"
                selected_dest="$DROPBOX_PATH"
                ;;
            4)
                echo ""
                echo -e "${BOLD}Enter full path to Specified Destination Folder:${NC}"
                echo -e "${DIM}(e.g. /run/media/$USER/EXTERNAL_BACKUP/Mixes, ~/CloudStorage/Dropbox, gdrive:Mixes)${NC}"
                read -e -r -p "Destination: " user_dest
                user_dest="${user_dest#"${user_dest%%[![:space:]]*}"}"
                user_dest="${user_dest%"${user_dest##*[![:space:]]}"}"
                user_dest="${user_dest%\"}"
                user_dest="${user_dest#\"}"
                user_dest="${user_dest%\'}"
                user_dest="${user_dest#\'}"
                [ -z "$user_dest" ] && continue
                selected_provider="Custom Specified Folder"
                selected_dest="$user_dest"
                ;;
            5)
                echo ""
                echo -e "${BOLD}Configure Cloud Backup Paths:${NC}"
                read -e -r -p "Google Drive Remote [${GDRIVE_REMOTE}]: " new_gd
                [ -n "$new_gd" ] && GDRIVE_REMOTE="$new_gd"
                read -e -r -p "iCloud Destination Path [${ICLOUD_PATH}]: " new_ic
                [ -n "$new_ic" ] && ICLOUD_PATH="$new_ic"
                read -e -r -p "Dropbox Destination Path [${DROPBOX_PATH}]: " new_db
                [ -n "$new_db" ] && DROPBOX_PATH="$new_db"

                # Persist to config.env if possible
                if [ -f "$BASE_DIR/config.env" ]; then
                    grep -q "^GDRIVE_REMOTE=" "$BASE_DIR/config.env" && sed -i -E "s|^GDRIVE_REMOTE=.*|GDRIVE_REMOTE=\"${GDRIVE_REMOTE}\"|" "$BASE_DIR/config.env" || echo "GDRIVE_REMOTE=\"${GDRIVE_REMOTE}\"" >> "$BASE_DIR/config.env"
                    grep -q "^ICLOUD_PATH=" "$BASE_DIR/config.env" && sed -i -E "s|^ICLOUD_PATH=.*|ICLOUD_PATH=\"${ICLOUD_PATH}\"|" "$BASE_DIR/config.env" || echo "ICLOUD_PATH=\"${ICLOUD_PATH}\"" >> "$BASE_DIR/config.env"
                    grep -q "^DROPBOX_PATH=" "$BASE_DIR/config.env" && sed -i -E "s|^DROPBOX_PATH=.*|DROPBOX_PATH=\"${DROPBOX_PATH}\"|" "$BASE_DIR/config.env" || echo "DROPBOX_PATH=\"${DROPBOX_PATH}\"" >> "$BASE_DIR/config.env"
                    echo -e "\n${GREEN}✓ Configuration saved to config.env!${NC}"
                fi
                sleep 2
                continue
                ;;
            6)
                echo -e "\n${BOLD}${CYAN}Recent Backup Logs in ${LOG_DIR}:${NC}"
                ls -lt "$LOG_DIR" | head -n 15
                echo ""
                read -r -p "Press [Enter] to continue..." _
                continue
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                continue
                ;;
        esac

        # Step 2: Choose Backup Scope
        echo ""
        echo -e "${BOLD}Select Backup Scope for ${CYAN}${selected_provider}${NC}:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Backup ALL Mix Archive Folders ${GREEN}(Full Sync across all drives)${NC}"
        echo -e "  ${BOLD}${CYAN}2)${NC} Custom Selection of Mixes ${YELLOW}(Choose 1 or more specific mixes)${NC}"
        echo -e "  ${BOLD}${CYAN}0)${NC} Back to Provider Menu\n"

        read -r -p "Enter choice [1-2, 0]: " scope_choice
        case "$scope_choice" in
            1)
                echo ""
                read -r -p "Include companion files (tracklists TXT/HTML/PDF & covers)? [Y/n]: " comp_ans
                case "$comp_ans" in
                    [nN]*) INCLUDE_COMPANIONS="false" ;;
                    *)     INCLUDE_COMPANIONS="true" ;;
                esac
                run_backup_job "$selected_provider" "$selected_dest" "all"
                read -r -p "Press [Enter] to return..." _
                ;;
            2)
                SELECTED_MIXES_GLOBAL=()
                if interactive_select_mixes; then
                    echo ""
                    echo -e "${GREEN}Selected ${#SELECTED_MIXES_GLOBAL[@]} mix(es) for backup.${NC}"
                    read -r -p "Include companion files (tracklists TXT/HTML/PDF & covers)? [Y/n]: " comp_ans
                    case "$comp_ans" in
                        [nN]*) INCLUDE_COMPANIONS="false" ;;
                        *)     INCLUDE_COMPANIONS="true" ;;
                    esac
                    run_backup_job "$selected_provider" "$selected_dest" "custom" "${SELECTED_MIXES_GLOBAL[@]}"
                    read -r -p "Press [Enter] to return..." _
                fi
                ;;
            0|[qQ])
                continue
                ;;
        esac
    done
}

# CLI Argument Mode
if [ "$#" -gt 0 ]; then
    cli_provider="Custom"
    cli_dest=""
    cli_scope="all"
    cli_mix_kw=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --provider=*)
                p_val="${1#*=}"
                p_lower="$(echo "$p_val" | tr '[:upper:]' '[:lower:]')"
                case "$p_lower" in
                    gdrive|google*) cli_provider="Google Drive"; cli_dest="$GDRIVE_REMOTE" ;;
                    icloud*)        cli_provider="iCloud Drive"; cli_dest="$ICLOUD_PATH" ;;
                    dropbox*)       cli_provider="Dropbox";      cli_dest="$DROPBOX_PATH" ;;
                    *)              cli_provider="Custom";       cli_dest="$p_val" ;;
                esac
                ;;
            --dest=*)
                cli_dest="${1#*=}"
                ;;
            --all)
                cli_scope="all"
                ;;
            --mix=*)
                cli_scope="custom"
                cli_mix_kw="${1#*=}"
                ;;
            --no-companions)
                INCLUDE_COMPANIONS="false"
                ;;
            --bwlimit=*)
                BW_LIMIT="${1#*=}"
                ;;
            -h|--help)
                echo "Usage: $(basename "$0") [options]"
                echo "Options:"
                echo "  --provider=gdrive|icloud|dropbox|custom  Select cloud provider"
                echo "  --dest=<path_or_remote>                 Specify exact destination folder"
                echo "  --all                                   Backup all mixes across all archives"
                echo "  --mix=<search_term>                     Backup specific mix matching term"
                echo "  --no-companions                         Exclude tracklists and covers"
                echo "  --bwlimit=<limit>                       Bandwidth limit (e.g. 10M, 0=unlimited)"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done

    [ -z "$cli_dest" ] && cli_dest="$GDRIVE_REMOTE"

    if [ "$cli_scope" = "all" ]; then
        run_backup_job "$cli_provider" "$cli_dest" "all"
    else
        # Find matching mix
        matched=()
        while IFS= read -r mf; do
            if [ -z "$cli_mix_kw" ] || echo "$(basename "$mf")" | grep -qi "$cli_mix_kw"; then
                matched+=("$mf")
            fi
        done < <(collect_all_mixes)
        if [ ${#matched[@]} -eq 0 ]; then
            echo "Error: No mixes found matching '${cli_mix_kw}'."
            exit 1
        fi
        run_backup_job "$cli_provider" "$cli_dest" "custom" "${matched[@]}"
    fi
    exit 0
fi

# Run interactive menu if no arguments provided
interactive_menu
