#!/usr/bin/env bash

# ================================
# CONFIGURATION & PATHS
# ================================
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

OUTPUT_DIR="${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}"
ARCHIVE_DIR="${ARCHIVE_DIR:-CONVERTED_WAV_FILES}"

# ANSI Color Codes & Formatting Styles
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[1;36m"
C_MAGENTA="\033[1;35m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_BLUE="\033[1;34m"
C_WHITE="\033[1;37m"

# Discover archive locations (Name -> path)
declare -a ARCHIVE_NAMES=()
declare -a ARCHIVE_FLAC_PATHS=()
declare -a ARCHIVE_WAV_PATHS=()

# Primary Archive
primary_flac=""
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" ]; then
    primary_flac="$(cd "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" && pwd)"
elif [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
    primary_flac="$(cd "$MIX_ARCHIVE_DIR" && pwd)"
elif [ -d "$OUTPUT_DIR" ]; then
    primary_flac="$(cd "$OUTPUT_DIR" && pwd)"
fi

primary_wav=""
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES" ]; then
    primary_wav="$(cd "$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES" && pwd)"
elif [ -d "$ARCHIVE_DIR" ]; then
    primary_wav="$(cd "$ARCHIVE_DIR" && pwd)"
fi

if [ -n "$primary_flac" ] || [ -n "$primary_wav" ]; then
    ARCHIVE_NAMES+=("Primary Archive (${MIX_ARCHIVE_DIR:-$PWD})")
    ARCHIVE_FLAC_PATHS+=("${primary_flac:-}")
    ARCHIVE_WAV_PATHS+=("${primary_wav:-}")
fi

# Extra Archives
if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
    IFS=':;,' read -ra EXTRA_DIRS <<< "$EXTRA_MIX_ARCHIVE_DIRS"
    extra_idx=1
    for ed in "${EXTRA_DIRS[@]}"; do
        ed="$(echo "$ed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "$ed" ] && continue
        
        eflac=""
        ewav=""
        if [ -d "$ed/FLAC_CONVERTED_OUTPUTS" ]; then
            eflac="$(cd "$ed/FLAC_CONVERTED_OUTPUTS" && pwd)"
        elif [ -d "$ed" ]; then
            eflac="$(cd "$ed" && pwd)"
        fi
        
        if [ -d "$ed/CONVERTED_WAV_FILES" ]; then
            ewav="$(cd "$ed/CONVERTED_WAV_FILES" && pwd)"
        fi

        if [ -n "$eflac" ] || [ -n "$ewav" ]; then
            ARCHIVE_NAMES+=("Additional Storage #${extra_idx} (${ed})")
            ARCHIVE_FLAC_PATHS+=("${eflac:-}")
            ARCHIVE_WAV_PATHS+=("${ewav:-}")
            ((extra_idx++))
        fi
    done
fi

# Fallback if none found
if [ ${#ARCHIVE_NAMES[@]} -eq 0 ]; then
    ARCHIVE_NAMES+=("Local Directory ($PWD)")
    ARCHIVE_FLAC_PATHS+=("$PWD")
    ARCHIVE_WAV_PATHS+=("")
fi

# Aggregate stats across all archives
total_flac_count=0
total_wav_count=0
total_valid_tracklists=0
total_flac_bytes=0
total_wav_bytes=0
total_cumulative_seconds=0

declare -a REPORT_LINES=()

for i in "${!ARCHIVE_NAMES[@]}"; do
    arch_name="${ARCHIVE_NAMES[$i]}"
    flac_path="${ARCHIVE_FLAC_PATHS[$i]}"
    wav_path="${ARCHIVE_WAV_PATHS[$i]}"

    loc_flac_count=0
    loc_wav_count=0
    loc_valid_tracklists=0
    loc_flac_bytes=0
    loc_wav_bytes=0
    loc_seconds=0

    if [ -n "$flac_path" ] && [ -d "$flac_path" ]; then
        loc_flac_count=$(find "$flac_path" -maxdepth 1 -type f -name "*.flac" 2>/dev/null | wc -l)
        loc_flac_bytes=$(du -sb "$flac_path" 2>/dev/null | awk '{print $1}')
        [ -z "$loc_flac_bytes" ] && loc_flac_bytes=0

        while IFS= read -r txt_file; do
            track_entries=$(grep -E '^[0-9]{1,2}\.' "$txt_file" 2>/dev/null | wc -l)
            if [ "$track_entries" -gt 3 ]; then
                ((loc_valid_tracklists++))
            fi
        done < <(find "$flac_path" -maxdepth 1 -type f -name "*.txt" 2>/dev/null)

        if command -v ffprobe &>/dev/null; then
            durations=$(find "$flac_path" -maxdepth 1 -type f -name "*.flac" -print0 2>/dev/null | xargs -0 -P "$(nproc)" -I {} ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "{}" 2>/dev/null || true)
            if [ -n "$durations" ]; then
                loc_seconds=$(echo "$durations" | awk '{s+=$1} END {print s+0}')
            fi
        fi
    fi

    if [ -n "$wav_path" ] && [ -d "$wav_path" ]; then
        loc_wav_count=$(find "$wav_path" -maxdepth 1 -type f -name "*.wav" 2>/dev/null | wc -l)
        loc_wav_bytes=$(du -sb "$wav_path" 2>/dev/null | awk '{print $1}')
        [ -z "$loc_wav_bytes" ] && loc_wav_bytes=0
    fi

    total_flac_count=$((total_flac_count + loc_flac_count))
    total_wav_count=$((total_wav_count + loc_wav_count))
    total_valid_tracklists=$((total_valid_tracklists + loc_valid_tracklists))
    total_flac_bytes=$((total_flac_bytes + loc_flac_bytes))
    total_wav_bytes=$((total_wav_bytes + loc_wav_bytes))
    total_cumulative_seconds=$(awk "BEGIN {print $total_cumulative_seconds + $loc_seconds}")

    loc_flac_gb=$(awk "BEGIN {print $loc_flac_bytes / 1024 / 1024 / 1024}")
    loc_sec_int=${loc_seconds%.*}
    loc_h=$((loc_sec_int / 3600))
    loc_m=$(((loc_sec_int % 3600) / 60))

    REPORT_LINES+=(" • ${C_CYAN}${arch_name}${C_RESET}")
    REPORT_LINES+=("   - Location:       ${flac_path:-N/A}")
    REPORT_LINES+=("   - FLAC Mixes:     ${C_BOLD}${loc_flac_count}${C_RESET} mixes ($(printf "%.2f" "$loc_flac_gb") GB)")
    [ "$loc_wav_count" -gt 0 ] && REPORT_LINES+=("   - Archived WAVs:  ${loc_wav_count} files")
    REPORT_LINES+=("   - Tracklists:     ${loc_valid_tracklists} verified")
    if [ "$loc_h" -gt 0 ] || [ "$loc_m" -gt 0 ]; then
        REPORT_LINES+=("   - Duration:       ${loc_h}h ${loc_m}m")
    fi
done

total_size_bytes=$((total_flac_bytes + total_wav_bytes))
total_flac_gb=$(awk "BEGIN {print $total_flac_bytes / 1024 / 1024 / 1024}")
total_wav_gb=$(awk "BEGIN {print $total_wav_bytes / 1024 / 1024 / 1024}")
total_size_gb=$(awk "BEGIN {print $total_size_bytes / 1024 / 1024 / 1024}")

tot_sec_int=${total_cumulative_seconds%.*}
hours=$((tot_sec_int / 3600))
mins=$(((tot_sec_int % 3600) / 60))
secs=$((tot_sec_int % 60))

# Print formatted dashboard
clear
echo -e "${C_CYAN}======================================================================${C_RESET}"
echo -e "${C_MAGENTA}${C_BOLD}     STREAM OF FREQUENCY - MULTI-ARCHIVE STATISTICS DASHBOARD        ${C_RESET}"
echo -e "${C_CYAN}======================================================================${C_RESET}"
echo ""

echo -e "${C_GREEN}[+] CONFIGURED ARCHIVE STORAGE LOCATIONS (${#ARCHIVE_NAMES[@]})${C_RESET}"
echo -e " --------------------------------------------------------------------"
for line in "${REPORT_LINES[@]}"; do
    echo -e "$line"
done
echo ""

echo -e "${C_GREEN}[+] COMBINED INVENTORY COUNTS (ACROSS ALL ARCHIVES)${C_RESET}"
echo -e " --------------------------------------------------------------------"
echo -e " • Total Converted FLAC Mixes Available: ${C_BOLD}${C_GREEN}$total_flac_count${C_RESET}"
echo -e " • Total Processed WAV Files Archived:   ${C_BOLD}$total_wav_count${C_RESET}"
echo -e " • Total Verified Tracklists (>3 Tracks): ${C_BOLD}$total_valid_tracklists${C_RESET}"
echo ""

echo -e "${C_GREEN}[+] COMBINED STORAGE FOOTPRINT${C_RESET}"
echo -e " --------------------------------------------------------------------"
echo -e " • Combined FLAC Directories Size:       ${C_BOLD}$(printf "%.3f" "$total_flac_gb") GB${C_RESET} (${total_flac_bytes} bytes)"
if [ "$total_wav_bytes" -gt 0 ]; then
    echo -e " • Combined WAV Archive Directories Size: ${C_BOLD}$(printf "%.3f" "$total_wav_gb") GB${C_RESET} (${total_wav_bytes} bytes)"
fi
echo -e " • Total Multi-Archive Footprint:        ${C_BOLD}${C_YELLOW}$(printf "%.3f" "$total_size_gb") GB${C_RESET} (${total_size_bytes} bytes)"
echo ""

echo -e "${C_GREEN}[+] TOTAL TIME ARCHIVE METRICS${C_RESET}"
echo -e " --------------------------------------------------------------------"
echo -e " • Total Cumulative Mixing Duration:     ${C_BOLD}${hours}h ${mins}m ${secs}s${C_RESET}"
echo ""
echo -e "${C_CYAN}======================================================================${C_RESET}"
