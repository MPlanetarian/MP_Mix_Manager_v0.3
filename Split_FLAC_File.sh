#!/usr/bin/env bash
# ==============================================================================
# Script: Split_FLAC_File.sh
# Purpose: Split a .FLAC audio file into N equal parts.
#          Allows selecting from FLAC_CONVERTED_OUTPUTS or entering a custom path.
#          Always outputs split parts to the same directory as the input file.
# ==============================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Determine script directory
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
unset _RESOLVED_SRC _RESOLVED_DIR

# Load configuration if present
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
elif [ -f "$PWD/config.env" ]; then
    # shellcheck source=/dev/null
    source "$PWD/config.env"
fi

OUTPUT_DIR="${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}"

# Ensure required utilities exist
for tool in ffmpeg ffprobe; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo -e "${RED}Error: Required tool '$tool' is not installed or not in PATH.${NC}"
        exit 1
    fi
done

format_seconds() {
    local total_sec
    total_sec=$(printf "%.0f" "$1" 2>/dev/null || echo "0")
    local h=$((total_sec / 3600))
    local m=$(( (total_sec % 3600) / 60 ))
    local s=$((total_sec % 60))
    if [ $h -gt 0 ]; then
        printf "%02d:%02d:%02d" $h $m $s
    else
        printf "%02d:%02d" $m $s
    fi
}

open_file_manager() {
    local target_dir="$1"
    [ -z "$target_dir" ] || [ ! -d "$target_dir" ] && return 0
    echo -e "${CYAN}Opening file manager in: ${BOLD}${target_dir}${NC}"
    if [[ "$OSTYPE" == "darwin"* ]] || [[ "$(uname -s)" == "Darwin"* ]]; then
        open "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
        if command -v cygpath >/dev/null 2>&1; then
            local win_p
            win_p="$(cygpath -w "$target_dir" 2>/dev/null || echo "$target_dir")"
            cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
        else
            explorer.exe "$target_dir" >/dev/null 2>&1 &
        fi
        disown 2>/dev/null || true
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v dolphin >/dev/null 2>&1; then
        dolphin "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v nautilus >/dev/null 2>&1; then
        nautilus "$target_dir" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi
}

clean_path_input() {
    local p="$1"
    p=$(echo "$p" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    if [[ "$p" == ~* ]]; then
        p="${p/#~/$HOME}"
    fi
    echo "$p"
}

echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
echo -e "${BOLD}${MAGENTA}            SPLIT AUDIO FILE INTO EQUAL PARTS & DJ SETS               ${NC}"
echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

input_flac="${1:-}"
num_parts="${2:-}"

# 1. Select the audio file
if [ -z "$input_flac" ]; then
    # Search candidate directories for audio files (FLAC, MP3, OGG, WAV)
    candidate_dirs=(
        "$OUTPUT_DIR"
        "${MIX_ARCHIVE_DIR:-$PWD}/FLAC_CONVERTED_OUTPUTS"
        "${MIX_ARCHIVE_DIR:-$PWD}/MP3_CONVERTED_OUTPUTS"
        "${MIX_ARCHIVE_DIR:-$PWD}/OGG_CONVERTED_OUTPUTS"
        "${MIX_ARCHIVE_DIR:-$PWD}/CONVERTED_WAV_FILES"
        "$PWD/FLAC_CONVERTED_OUTPUTS"
        "$PWD/MP3_CONVERTED_OUTPUTS"
        "$PWD/OGG_CONVERTED_OUTPUTS"
        "$SCRIPT_DIR/FLAC_CONVERTED_OUTPUTS"
        "${MIX_ARCHIVE_DIR:-$PWD}"
        "$PWD"
    )
    if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
        IFS=':;,' read -ra EXTRA_DIRS <<< "$EXTRA_MIX_ARCHIVE_DIRS"
        for ed in "${EXTRA_DIRS[@]}"; do
            ed="$(echo "$ed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [ -z "$ed" ] && continue
            for sub in "FLAC_CONVERTED_OUTPUTS" "MP3_CONVERTED_OUTPUTS" "OGG_CONVERTED_OUTPUTS" "CONVERTED_WAV_FILES"; do
                [ -d "$ed/$sub" ] && candidate_dirs+=("$ed/$sub")
            done
            [ -d "$ed" ] && candidate_dirs+=("$ed")
        done
    fi

    found_flacs=()
    shopt -s nullglob nocaseglob
    for cdir in "${candidate_dirs[@]}"; do
        if [ -d "$cdir" ]; then
            for f in "$cdir"/*.flac "$cdir"/*.mp3 "$cdir"/*.ogg "$cdir"/*.wav; do
                [ -f "$f" ] && found_flacs+=("$f")
            done
        fi
    done
    shopt -u nullglob nocaseglob

    # Deduplicate candidate files while preserving order
    unique_flacs=()
    if [ ${#found_flacs[@]} -gt 0 ]; then
        IFS=$'\n' read -r -d '' -a unique_flacs < <(python3 -c "
import sys, os
seen = set()
res = []
for p in sys.argv[1:]:
    rp = os.path.realpath(p)
    if rp not in seen and os.path.isfile(rp):
        seen.add(rp)
        res.append(rp)
res.sort(key=lambda x: os.path.getmtime(x), reverse=True)
for r in res:
    print(r)
" "${found_flacs[@]}" && printf '\0') || true
    fi

    if [ ${#unique_flacs[@]} -gt 0 ]; then
        echo -e "${BOLD}${CYAN}Found ${#unique_flacs[@]} audio file(s) in archive output directories:${NC}\n"
        max_show=25
        count=0
        for f in "${unique_flacs[@]}"; do
            ((count++))
            [ $count -gt $max_show ] && break
            f_size=$(ls -lh "$f" 2>/dev/null | awk '{print $5}')
            f_ext="${f##*.}"
            echo -e "  ${BOLD}${CYAN}$(printf "%2d" $count))${NC} $(basename "$f") ${DIM}(${f_size} • ${f_ext^^})${NC}"
        done
        if [ ${#unique_flacs[@]} -gt $max_show ]; then
            echo -e "  ${DIM}...and $(( ${#unique_flacs[@]} - max_show )) more files${NC}"
        fi
        echo ""
        echo -e "  ${BOLD}${YELLOW} M)${NC} Manually enter / paste custom full path to an audio file"
        echo -e "  ${BOLD}${RED} 0)${NC} Cancel / Exit\n"

        while true; do
            read -r -p "Select an audio file [1-${#unique_flacs[@]}, M for manual, 0 to exit]: " choice
            case "$choice" in
                0|[qQ])
                    echo -e "\n${YELLOW}Operation cancelled.${NC}"
                    exit 0
                    ;;
                [mM])
                    echo ""
                    read -r -e -p "Enter full path to the audio file: " manual_path
                    input_flac=$(clean_path_input "$manual_path")
                    break
                    ;;
                *)
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#unique_flacs[@]}" ]; then
                        input_flac="${unique_flacs[$((choice - 1))]}"
                        break
                    else
                        echo -e "${RED}Invalid choice! Please enter a number between 1 and ${#unique_flacs[@]}, 'M', or '0'.${NC}"
                    fi
                    ;;
            esac
        done
    else
        echo -e "${YELLOW}No audio files automatically discovered in output directories.${NC}"
        read -r -e -p "Enter full path to the audio file: " manual_path
        input_flac=$(clean_path_input "$manual_path")
    fi
fi

# Clean & validate the selected input path
input_flac=$(clean_path_input "$input_flac")

if [ -z "$input_flac" ] || [ ! -f "$input_flac" ]; then
    echo -e "${RED}Error: File not found at: '$input_flac'${NC}"
    exit 1
fi

input_flac=$(realpath "$input_flac" 2>/dev/null || readlink -f "$input_flac" 2>/dev/null || echo "$input_flac")

# Probe file duration and specs
echo -e "\n${BOLD}${BLUE}Probing audio stream specifications...${NC}"
duration_raw=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_flac" 2>/dev/null || true)
if [ -z "$duration_raw" ] || [ "$duration_raw" = "N/A" ]; then
    if command -v soxi >/dev/null 2>&1; then
        duration_raw=$(soxi -D "$input_flac" 2>/dev/null || true)
    fi
fi

if [ -z "$duration_raw" ] || [ "$duration_raw" = "N/A" ]; then
    echo -e "${RED}Error: Unable to probe duration for '$input_flac'. Please ensure it is a valid audio file.${NC}"
    exit 1
fi

total_sec=$(python3 -c "import sys; print(f'{float(sys.argv[1]):.4f}')" "$duration_raw" 2>/dev/null || echo "$duration_raw")
total_formatted=$(format_seconds "$total_sec")
file_size=$(ls -lh "$input_flac" 2>/dev/null | awk '{print $5}')
target_dir=$(dirname "$input_flac")
base_name=$(basename "$input_flac")
stem="${base_name%.*}"
ext="${base_name##*.}"
ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

# Choose encoder parameters based on format
codec_args=()
case "$ext_lower" in
    flac)
        codec_args=(-c:a flac)
        ;;
    mp3)
        codec_args=(-c:a libmp3lame -b:a 320k)
        ;;
    ogg)
        codec_args=(-c:a libvorbis -q:a 8)
        ;;
    wav)
        codec_args=(-c:a pcm_s24le)
        ;;
    m4a|aac)
        codec_args=(-c:a aac -b:a 320k)
        ;;
    *)
        codec_args=(-c:a copy)
        ;;
esac

echo -e "  • ${BOLD}Input File:${NC}   ${BOLD}${GREEN}${base_name}${NC}"
echo -e "  • ${BOLD}Directory:${NC}    ${CYAN}${target_dir}${NC}"
echo -e "  • ${BOLD}Format:${NC}       ${MAGENTA}${ext_lower^^}${NC}"
echo -e "  • ${BOLD}Total Length:${NC} ${WHITE}${total_formatted}${NC} (${total_sec} seconds)"
echo -e "  • ${BOLD}File Size:${NC}    ${YELLOW}${file_size}${NC}\n"

# 2. Ask user for number of parts
while true; do
    if [ -z "$num_parts" ]; then
        read -r -p "How many parts do you want to split this audio file into? (e.g. 2, 3, 4): " num_parts
    fi
    num_parts=$(echo "$num_parts" | tr -d '[:space:]')
    if [[ "$num_parts" =~ ^[0-9]+$ ]] && [ "$num_parts" -ge 2 ] && [ "$num_parts" -le 99 ]; then
        break
    else
        echo -e "${RED}Error: Number of parts must be a whole integer between 2 and 99.${NC}"
        num_parts=""
    fi
done

# Calculate duration per part
part_dur=$(python3 -c "import sys; print(f'{float(sys.argv[1]) / int(sys.argv[2]):.4f}')" "$total_sec" "$num_parts")
part_dur_fmt=$(format_seconds "$part_dur")

echo -e "\n${BOLD}${BLUE}=== SPLIT CONFIGURATION ===${NC}"
echo -e "  • ${BOLD}Total Parts:${NC}       ${BOLD}${GREEN}${num_parts}${NC}"
echo -e "  • ${BOLD}Duration Per Part:${NC} ~${BOLD}${CYAN}${part_dur_fmt}${NC} (${part_dur}s)"
echo -e "  • ${BOLD}Output Directory:${NC}  ${BOLD}${YELLOW}${target_dir}${NC} ${DIM}(Always same directory as input)${NC}"
echo -e "  • ${BOLD}Naming Scheme:${NC}     ${stem}_Part01.${ext}, ${stem}_Part02.${ext}..."
echo -e "${BLUE}----------------------------------------------------------------------${NC}\n"

read -r -p "Proceed with splitting? [Y/n]: " confirm
confirm=$(echo "${confirm:-y}" | tr '[:upper:]' '[:lower:]')
if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
    echo -e "${YELLOW}Operation cancelled by user.${NC}"
    exit 0
fi

echo -e "\n${BOLD}${MAGENTA}Starting Audio Split Processing (${ext_lower^^})...${NC}\n"

generated_files=()
pad_width=2
[ "$num_parts" -ge 100 ] && pad_width=3

for ((part=1; part<=num_parts; part++)); do
    part_str=$(printf "%0*d" "$pad_width" "$part")
    out_file="${target_dir}/${stem}_Part${part_str}.${ext}"
    start_sec=$(python3 -c "import sys; print(f'{(int(sys.argv[1]) - 1) * float(sys.argv[2]):.4f}')" "$part" "$part_dur")
    start_fmt=$(format_seconds "$start_sec")

    if [ "$part" -lt "$num_parts" ]; then
        end_sec=$(python3 -c "import sys; print(f'{int(sys.argv[1]) * float(sys.argv[2]):.4f}')" "$part" "$part_dur")
        end_fmt=$(format_seconds "$end_sec")
        echo -e "${BOLD}${CYAN}[Part ${part}/${num_parts}]${NC} Processing: ${WHITE}${stem}_Part${part_str}.${ext}${NC} (${start_fmt} ➔ ${end_fmt})..."
        ffmpeg -y -hide_banner -loglevel warning -stats \
            -ss "$start_sec" -t "$part_dur" \
            -i "$input_flac" \
            "${codec_args[@]}" \
            -map_metadata 0 \
            -metadata title="${stem} (Part ${part}/${num_parts})" \
            -metadata track="${part}/${num_parts}" \
            "$out_file"
    else
        echo -e "${BOLD}${CYAN}[Part ${part}/${num_parts}]${NC} Processing Final Part: ${WHITE}${stem}_Part${part_str}.${ext}${NC} (${start_fmt} ➔ End: ${total_formatted})..."
        # Last part captures all remaining audio without -t truncation
        ffmpeg -y -hide_banner -loglevel warning -stats \
            -ss "$start_sec" \
            -i "$input_flac" \
            "${codec_args[@]}" \
            -map_metadata 0 \
            -metadata title="${stem} (Part ${part}/${num_parts})" \
            -metadata track="${part}/${num_parts}" \
            "$out_file"
    fi

    if [ -f "$out_file" ]; then
        generated_files+=("$out_file")
    else
        echo -e "${RED}Warning: Failed to generate '$out_file'!${NC}"
    fi
done

echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}               ✓ AUDIO SPLIT COMPLETED SUCCESSFULLY!                  ${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}\n"

echo -e "Generated ${#generated_files[@]} of ${num_parts} parts in ${CYAN}${target_dir}${NC}:\n"
for f in "${generated_files[@]}"; do
    sz=$(ls -lh "$f" 2>/dev/null | awk '{print $5}')
    dur_f=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null || echo "0")
    dur_fmt=$(format_seconds "$dur_f")
    echo -e "  ${GREEN}✓${NC} ${BOLD}$(basename "$f")${NC}  ${DIM}[${dur_fmt} • ${sz}]${NC}"
done

echo ""
# Ask user if they would like to generate spectrogram images for all split parts separately
echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
gen_spek_choice=""
read -r -p "Would you like to generate spek spectrogram images of all the split parts separately? [Y/n]: " gen_spek_choice </dev/tty || gen_spek_choice=""
gen_spek_choice=$(echo "${gen_spek_choice:-y}" | tr '[:upper:]' '[:lower:]')

if [[ "$gen_spek_choice" == "y" || "$gen_spek_choice" == "yes" ]]; then
    echo -e "\n${BOLD}${MAGENTA}Generating Spek Spectrogram Images for ${#generated_files[@]} Split Part(s)...${NC}\n"
    spek_count=0
    spek_out_dir="${SPEK_DIR:-$SCRIPT_DIR/SPEK_OUTPUTS}"
    [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/SPEK_OUTPUTS" ] && spek_out_dir="$MIX_ARCHIVE_DIR/SPEK_OUTPUTS"
    mkdir -p "$spek_out_dir" 2>/dev/null || true

    for pf in "${generated_files[@]}"; do
        [ -f "$pf" ] || continue
        p_base=$(basename "$pf")
        p_stem="${p_base%.*}"
        p_dir=$(dirname "$pf")
        spek_img="${p_dir}/${p_stem}_Spek.png"
        spek_archive_img="${spek_out_dir}/${p_stem}.png"

        echo -e "  ${BOLD}${CYAN}Spectrogram [Part $((spek_count+1))/${#generated_files[@]}]:${NC} ${WHITE}${p_base}${NC}..."
        if ffmpeg -hide_banner -loglevel error -y -i "$pf" \
            -lavfi "showspectrumpic=s=1920x1080:mode=combined:color=intensity:scale=log:legend=1:saturation=1.2" \
            -frames:v 1 "$spek_img" 2>/dev/null; then
            ((spek_count++))
            # Also copy to SPEK_OUTPUTS archive directory if target is elsewhere
            if [ -d "$spek_out_dir" ] && [ "$(realpath "$spek_out_dir" 2>/dev/null)" != "$(realpath "$p_dir" 2>/dev/null)" ]; then
                cp -f "$spek_img" "$spek_archive_img" 2>/dev/null || true
            fi
            echo -e "    ${GREEN}✓ Generated:${NC} ${spek_img}"
        else
            echo -e "    ${RED}✗ Failed to generate spectrogram for ${p_base}${NC}"
        fi
    done
    echo -e "\n${BOLD}${GREEN}✓ Successfully generated ${spek_count} of ${#generated_files[@]} spectrogram image(s)!${NC}\n"
else
    echo -e "${DIM}Skipped spectrogram generation.${NC}\n"
fi

open_file_manager "$target_dir"
echo -e "${GREEN}All split parts safely written to the input file's directory: ${target_dir}${NC}\n"
