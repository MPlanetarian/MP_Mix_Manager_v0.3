#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Universal Audio Format & Bit Depth Converter
# Converts WAV (and other audio) to MP3, Ogg Vorbis, Apple AAC/ALAC, Opus,
# FLAC, and WAV to WAV with custom bit depths (32-bit, 24-bit, 16-bit).
# ==============================================================================
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Parse command line flags if invoked non-interactively or from menu
CLI_SCOPE=""
CLI_FORMAT=""
CLI_BITRATE=""
CLI_BITDEPTH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) CLI_SCOPE="1"; shift ;;
        -c) CLI_SCOPE="2"; shift ;;
        -w) CLI_SCOPE="3"; shift ;;
        -f) CLI_SCOPE="4"; shift ;;
        -o) CLI_FORMAT="$2"; shift 2 ;;
        -b) CLI_BITRATE="$2"; shift 2 ;;
        -d) CLI_BITDEPTH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Discover all configured mix archive root directories
all_mix_archive_roots=()
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
    cand="$(cd "$MIX_ARCHIVE_DIR" && pwd)"
    [[ ! " ${all_mix_archive_roots[*]} " =~ " ${cand} " ]] && all_mix_archive_roots+=("$cand")
fi

if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
    IFS=':;,' read -ra EXTRA_DIRS <<< "$EXTRA_MIX_ARCHIVE_DIRS"
    for ed in "${EXTRA_DIRS[@]}"; do
        ed="$(echo "$ed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "$ed" ] && continue
        if [ -d "$ed" ]; then
            cand="$(cd "$ed" && pwd)"
            [[ ! " ${all_mix_archive_roots[*]} " =~ " ${cand} " ]] && all_mix_archive_roots+=("$cand")
        fi
    done
fi
[ -d "$PWD" ] && cand="$(pwd)" && [[ ! " ${all_mix_archive_roots[*]} " =~ " ${cand} " ]] && all_mix_archive_roots+=("$cand")

# Discover all FLAC directories across all archives
all_flac_dirs=()
if [ -d "${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}" ]; then
    all_flac_dirs+=("$(cd "${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}" && pwd)")
fi
for arch_d in "${all_mix_archive_roots[@]}"; do
    if [ -d "$arch_d/FLAC_CONVERTED_OUTPUTS" ]; then
        cand="$(cd "$arch_d/FLAC_CONVERTED_OUTPUTS" && pwd)"
        [[ ! " ${all_flac_dirs[*]} " =~ " ${cand} " ]] && all_flac_dirs+=("$cand")
    elif [ -d "$arch_d" ]; then
        cand="$(cd "$arch_d" && pwd)"
        [[ ! " ${all_flac_dirs[*]} " =~ " ${cand} " ]] && all_flac_dirs+=("$cand")
    fi
done
[ ${#all_flac_dirs[@]} -eq 0 ] && [ -d "$PWD" ] && all_flac_dirs+=("$PWD")

# Discover all WAV archive and unconverted directories across all archives
all_wav_dirs=()
all_unconverted_wav_dirs=()
for arch_d in "${all_mix_archive_roots[@]}"; do
    # Archive converted WAV directories
    if [ -d "$arch_d/CONVERTED_WAV_FILES" ]; then
        cand="$(cd "$arch_d/CONVERTED_WAV_FILES" && pwd)"
        [[ ! " ${all_wav_dirs[*]} " =~ " ${cand} " ]] && all_wav_dirs+=("$cand")
    fi
    if [ -d "$arch_d/WAV_CONVERTED_OUTPUTS" ]; then
        cand="$(cd "$arch_d/WAV_CONVERTED_OUTPUTS" && pwd)"
        [[ ! " ${all_wav_dirs[*]} " =~ " ${cand} " ]] && all_wav_dirs+=("$cand")
    fi
    # Archive root directory (where incoming/pending WAVs reside)
    if [ -d "$arch_d" ]; then
        cand="$(cd "$arch_d" && pwd)"
        [[ ! " ${all_unconverted_wav_dirs[*]} " =~ " ${cand} " ]] && all_unconverted_wav_dirs+=("$cand")
        [[ ! " ${all_wav_dirs[*]} " =~ " ${cand} " ]] && all_wav_dirs+=("$cand")
    fi
    if [ -d "$arch_d/UNCONVERTED_WAVS" ]; then
        cand="$(cd "$arch_d/UNCONVERTED_WAVS" && pwd)"
        [[ ! " ${all_unconverted_wav_dirs[*]} " =~ " ${cand} " ]] && all_unconverted_wav_dirs+=("$cand")
    fi
done

# Find matching cover art
find_cover_art() {
    local base_name="$1"
    local search_dirs=("./COVERS" "$PARENT_DIR/COVERS" "${MIX_ARCHIVE_DIR:-}/COVERS" "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/COVERS" "/Volumes/WD BLACK B/MIX_ARCHIVE/COVERS" "D:/MIX_ARCHIVE/COVERS")
    if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
        IFS=':;,' read -ra EXTRA_DIRS <<< "$EXTRA_MIX_ARCHIVE_DIRS"
        for ed in "${EXTRA_DIRS[@]}"; do
            ed="$(echo "$ed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            [ -n "$ed" ] && [ -d "$ed/COVERS" ] && search_dirs+=("$ed/COVERS")
        done
    fi
    
    # Try show number match (e.g. 033)
    local show_num=""
    local re_show='(Frequency|Mix|SOF)[_ -]+([0-9]{3})'
    local re_num='([0-9]{3})'
    if [[ "$base_name" =~ $re_show ]]; then
        show_num="${BASH_REMATCH[2]}"
    elif [[ "$base_name" =~ $re_num ]]; then
        show_num="${BASH_REMATCH[1]}"
    fi

    if [ -n "$show_num" ]; then
        for cd in "${search_dirs[@]}"; do
            if [ -d "$cd" ]; then
                shopt -s nullglob nocaseglob
                local matches=("$cd"/*"$show_num"*.jpg "$cd"/*"$show_num"*.jpeg "$cd"/*"$show_num"*.png)
                shopt -u nullglob nocaseglob
                if [ ${#matches[@]} -gt 0 ] && [ -f "${matches[0]}" ]; then
                    echo "${matches[0]}"
                    return 0
                fi
            fi
        done
    fi

    # Fallback to Cover.png
    if [ -f "./Cover.png" ]; then
        echo "./Cover.png"
        return 0
    elif [ -f "$PARENT_DIR/Cover.png" ]; then
        echo "$PARENT_DIR/Cover.png"
        return 0
    fi

    return 1
}

CUSTOM_ARTIST="${SOF_ARTIST:-}"
CUSTOM_TITLE="${SOF_TITLE:-}"
CUSTOM_ALBUM="${SOF_ALBUM:-}"
CUSTOM_YEAR="${SOF_YEAR:-}"
CUSTOM_GENRE="${SOF_GENRE:-}"
CUSTOM_COMMENT="${SOF_COMMENT:-}"
CUSTOM_COVER_IMAGE="${SOF_COVER_IMAGE:-}"

configure_conversion_metadata_and_cover() {
    if [ ! -t 0 ]; then
        return 0
    fi

    local tag_choice=""
    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}           AUDIO ID TAGS & COVER ARTWORK SETTINGS                     ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "Would you like to set custom tags or custom cover art?"
    echo -e "  [y/N] (Default: Enter = keep standard tags & default cover)"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"

    read -r -p "Customize audio tags & cover? [y/N]: " tag_choice || tag_choice=""
    case "$tag_choice" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            echo -e " -> Using standard default tags and cover art.\n"
            return 0
            ;;
    esac

    echo -e "\n--- Audio Metadata / ID Tags (Press Enter to keep default) ---"

    # 1. Artist
    local input_artist=""
    read -r -p "Artist Name [MPlanetarian]: " input_artist || input_artist=""
    CUSTOM_ARTIST="${input_artist:-MPlanetarian}"

    # 2. Mix / Track Title
    local input_title=""
    read -r -p "Mix / Track Title [Auto-detect from filename]: " input_title || input_title=""
    CUSTOM_TITLE="$input_title"

    # 3. Album
    local input_album=""
    read -r -p "Album / Series Name [Stream of Frequency]: " input_album || input_album=""
    CUSTOM_ALBUM="${input_album:-Stream of Frequency}"

    # 4. Year
    local def_year
    def_year="$(date +%Y)"
    local input_year=""
    read -r -p "Release Year [$def_year]: " input_year || input_year=""
    CUSTOM_YEAR="${input_year:-$def_year}"

    # 5. Genre
    local input_genre=""
    read -r -p "Genre [Electronic / Trance]: " input_genre || input_genre=""
    CUSTOM_GENRE="${input_genre:-Electronic / Trance}"

    # 6. Comment
    local input_comment=""
    read -r -p "Comment / Description [Stream of Frequency Mix Archive]: " input_comment || input_comment=""
    CUSTOM_COMMENT="${input_comment:-Stream of Frequency Mix Archive}"

    # 7. Cover Artwork Selection
    echo -e "\n--- Cover Artwork Image Selection ---"

    local discovered_covers=()
    local search_paths=(
        "./Cover.png"
        "./assets/Cover.png"
        "./COVERS"
        "$SCRIPT_DIR/COVERS"
        "$PARENT_DIR/COVERS"
        "${MIX_ARCHIVE_DIR:-}/COVERS"
        "${MIX_ARCHIVE_DIR:-}/SOF_PODCAST_COVER_ART"
    )

    for sp in "${search_paths[@]}"; do
        if [ -f "$sp" ]; then
            local already=0
            for dc in "${discovered_covers[@]}"; do [ "$dc" = "$sp" ] && already=1 && break; done
            [ "$already" -eq 0 ] && discovered_covers+=("$sp")
        elif [ -d "$sp" ]; then
            shopt -s nullglob nocaseglob
            for img in "$sp"/*.png "$sp"/*.jpg "$sp"/*.jpeg; do
                if [ -f "$img" ]; then
                    local already=0
                    for dc in "${discovered_covers[@]}"; do [ "$dc" = "$img" ] && already=1 && break; done
                    [ "$already" -eq 0 ] && discovered_covers+=("$img")
                fi
            done
            shopt -u nullglob nocaseglob
        fi
    done

    echo "  1) Default Cover Image"
    local c_idx=2
    for cov in "${discovered_covers[@]}"; do
        [ "$c_idx" -gt 9 ] && break
        echo "  ${c_idx}) Existing: $cov"
        ((c_idx++))
    done
    echo "  c) Enter full path to a custom image file (PNG / JPG)"

    local cov_choice=""
    read -r -p "Select cover option [1/Enter = default]: " cov_choice || cov_choice=""
    case "$cov_choice" in
        ""|1)
            echo " -> Selected default cover image."
            ;;
        [cC]|[cC][uU][sS][tT][oO][mM])
            local custom_path=""
            read -r -p "Enter full path to cover image (or drag & drop): " custom_path || custom_path=""
            custom_path="${custom_path#\"}"
            custom_path="${custom_path%\"}"
            custom_path="${custom_path#\'}"
            custom_path="${custom_path%\'}"
            custom_path="$(eval echo "$custom_path")"
            if [ -n "$custom_path" ] && [ -f "$custom_path" ]; then
                CUSTOM_COVER_IMAGE="$custom_path"
                echo " -> Custom cover art verified: $CUSTOM_COVER_IMAGE"
            else
                echo " -> Warning: File '$custom_path' not found. Using default cover."
            fi
            ;;
        [2-9])
            local target_idx=$((cov_choice - 2))
            if [ "$target_idx" -lt "${#discovered_covers[@]}" ]; then
                CUSTOM_COVER_IMAGE="${discovered_covers[$target_idx]}"
                echo " -> Selected existing cover: $CUSTOM_COVER_IMAGE"
            else
                echo " -> Invalid selection. Using default cover."
            fi
            ;;
        *)
            echo " -> Invalid selection. Using default cover."
            ;;
    esac

    echo -e "\n=================================================="
    echo "Configured Tag Summary:"
    echo "  Artist:  ${CUSTOM_ARTIST:-MPlanetarian}"
    echo "  Title:   ${CUSTOM_TITLE:-[Auto-detect from filename]}"
    echo "  Album:   ${CUSTOM_ALBUM:-Stream of Frequency}"
    echo "  Year:    ${CUSTOM_YEAR:-$def_year}"
    echo "  Genre:   ${CUSTOM_GENRE:-Electronic / Trance}"
    echo "  Cover:   ${CUSTOM_COVER_IMAGE:-Default}"
    echo -e "==================================================\n"
}

convert_file() {
    local in_file="$1"
    local out_format="$2"
    local out_dir="$3"
    local custom_opts="$4"
    local out_ext="$5"

    local base_name
    base_name=$(basename "$in_file")
    base_name="${base_name%.*}"

    mkdir -p "$out_dir"
    local out_file="$out_dir/${base_name}.${out_ext}"

    echo -e "  Converting: ${BOLD}${CYAN}$(basename "$in_file")${NC}"
    echo -e "  Format:     ${YELLOW}${out_format}${NC} -> ${GREEN}$(basename "$out_file")${NC}"

    local cover_art=""
    if [ -n "${CUSTOM_COVER_IMAGE:-}" ] && [ -f "$CUSTOM_COVER_IMAGE" ]; then
        cover_art="$CUSTOM_COVER_IMAGE"
    else
        cover_art=$(find_cover_art "$base_name" 2>/dev/null || true)
    fi

    local ffmpeg_args=(-y -i "$in_file")
    
    # Cover art embedding for formats that support ID3/MP4/FLAC covers
    if [ -n "$cover_art" ] && [ -f "$cover_art" ]; then
        if [ "$out_ext" = "mp3" ]; then
            ffmpeg_args+=(-i "$cover_art" -map 0:a -map 1:v -c:v mjpeg -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)")
        elif [ "$out_ext" = "m4a" ]; then
            ffmpeg_args+=(-i "$cover_art" -map 0:a -map 1:v -c:v mjpeg -disposition:v:0 attached_pic)
        elif [ "$out_ext" = "flac" ]; then
            ffmpeg_args+=(-i "$cover_art" -map 0:a -map 1:v -c:v copy -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)")
        else
            ffmpeg_args+=(-map 0:a)
        fi
    else
        ffmpeg_args+=(-map 0:a)
    fi

    local eff_artist="${CUSTOM_ARTIST:-MPlanetarian}"
    local eff_title="${CUSTOM_TITLE:-$base_name}"
    local eff_album="${CUSTOM_ALBUM:-Stream of Frequency}"
    local eff_year="${CUSTOM_YEAR:-$(date +%Y)}"
    local eff_genre="${CUSTOM_GENRE:-Electronic / Trance}"
    local eff_comment="${CUSTOM_COMMENT:-Stream of Frequency Mix Archive}"

    ffmpeg_args+=(-metadata artist="$eff_artist" -metadata album="$eff_album" -metadata title="$eff_title" -metadata date="$eff_year" -metadata genre="$eff_genre" -metadata comment="$eff_comment")

    # Append codec and encoding parameters
    # shellcheck disable=SC2206
    ffmpeg_args+=($custom_opts "$out_file")

    if ffmpeg "${ffmpeg_args[@]}" >/dev/null 2>&1; then
        local sz
        sz=$(ls -lh "$out_file" 2>/dev/null | awk '{print $5}')
        echo -e "  ${GREEN}✓ Done:${NC} $out_file (${CYAN}${sz}${NC})\n"
        prompt_split_audio "$out_file"
        return 0
    else
        # Fallback without artwork embedding if muxing failed
        if ffmpeg -y -i "$in_file" $custom_opts "$out_file" >/dev/null 2>&1; then
            local sz
            sz=$(ls -lh "$out_file" 2>/dev/null | awk '{print $5}')
            echo -e "  ${GREEN}✓ Done (audio only):${NC} $out_file (${CYAN}${sz}${NC})\n"
            prompt_split_audio "$out_file"
            return 0
        else
            echo -e "  ${RED}✗ Error converting $in_file!${NC}\n"
            return 1
        fi
    fi
}

prompt_split_audio() {
    local converted_file="$1"
    [ -f "$converted_file" ] || return 0
    if [ ! -t 0 ] && [ ! -r /dev/tty ]; then
        return 0
    fi
    echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
    local ask_split=""
    read -r -p "Would you like to split '$(basename "$converted_file")' into separate parts/sets? [y/N]: " ask_split </dev/tty || ask_split=""
    case "$ask_split" in
        [yY]|[yY][eE][sS])
            local splitter_bin=""
            for sc in "$SCRIPT_DIR/Split_FLAC_File.sh" "$PARENT_DIR/Split_FLAC_File.sh" "$SCRIPT_DIR/scripts/Split_FLAC_File.sh" "./Split_FLAC_File.sh"; do
                if [ -f "$sc" ]; then splitter_bin="$sc"; break; fi
            done
            if [ -n "$splitter_bin" ]; then
                bash "$splitter_bin" "$converted_file" </dev/tty || true
            else
                echo -e "${RED}Warning: Split_FLAC_File.sh not found!${NC}"
            fi
            ;;
        *)
            echo -e "${DIM}Skipped splitting for $(basename "$converted_file").${NC}"
            ;;
    esac
}

FMT_NAME=""
OPTS=""
EXT=""
SUB_DIR=""

if [ -n "$CLI_FORMAT" ]; then
    case "${CLI_FORMAT,,}" in
        mp3)
            case "${CLI_BITRATE:-320k}" in
                256|256k) FMT_NAME="MP3 256k CBR"; OPTS="-c:a libmp3lame -b:a 256k"; EXT="mp3"; SUB_DIR="MP3_256K" ;;
                192|192k) FMT_NAME="MP3 192k CBR"; OPTS="-c:a libmp3lame -b:a 192k"; EXT="mp3"; SUB_DIR="MP3_192K" ;;
                v0|V0)    FMT_NAME="MP3 V0 VBR";   OPTS="-c:a libmp3lame -q:a 0";    EXT="mp3"; SUB_DIR="MP3_V0" ;;
                *)        FMT_NAME="MP3 320k CBR"; OPTS="-c:a libmp3lame -b:a 320k"; EXT="mp3"; SUB_DIR="MP3_320K" ;;
            esac
            ;;
        wav)
            case "${CLI_BITDEPTH:-24}" in
                32)      FMT_NAME="WAV 32-bit Float";   OPTS="-c:a pcm_f32le"; EXT="wav"; SUB_DIR="WAV_32BIT_FLOAT" ;;
                16)      FMT_NAME="WAV 16-bit 44.1kHz"; OPTS="-c:a pcm_s16le -ar 44100"; EXT="wav"; SUB_DIR="WAV_16BIT_44K" ;;
                *)       FMT_NAME="WAV 24-bit PCM";     OPTS="-c:a pcm_s24le"; EXT="wav"; SUB_DIR="WAV_24BIT" ;;
            esac
            ;;
        flac)
            case "${CLI_BITDEPTH:-24}" in
                16)      FMT_NAME="FLAC 16-bit"; OPTS="-sample_fmt s16 -c:a flac -compression_level 8"; EXT="flac"; SUB_DIR="FLAC_16BIT" ;;
                *)       FMT_NAME="FLAC 24-bit"; OPTS="-sample_fmt s32 -c:a flac -compression_level 8"; EXT="flac"; SUB_DIR="FLAC_24BIT" ;;
            esac
            ;;
        ogg)
            FMT_NAME="Ogg Vorbis Q8"; OPTS="-c:a libvorbis -q:a 8"; EXT="ogg"; SUB_DIR="OGG_Q8"
            ;;
        opus)
            FMT_NAME="Opus 160k"; OPTS="-c:a libopus -b:a 160k"; EXT="opus"; SUB_DIR="OPUS_160K"
            ;;
        aac|m4a)
            FMT_NAME="Apple AAC 320k"; OPTS="-c:a aac -b:a 320k"; EXT="m4a"; SUB_DIR="AAC_320K"
            ;;
        alac)
            FMT_NAME="Apple ALAC Lossless"; OPTS="-c:a alac"; EXT="m4a"; SUB_DIR="ALAC_LOSSLESS"
            ;;
    esac
fi

if [ -z "$FMT_NAME" ]; then
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}       UNIVERSAL AUDIO FORMAT & BIT DEPTH CONVERTER                   ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    echo -e "${BOLD}Select Target Output Format:${NC}"
    echo -e "  ${BOLD}${BLUE}── [ MP3 FORMATS ] ───────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}${CYAN} 1)${NC} MP3 320 kbps CBR (Highest Constant Bitrate MP3)"
    echo -e "  ${BOLD}${CYAN} 2)${NC} MP3 V0 VBR (~245 kbps Optimal Variable Bitrate)"
    echo -e "  ${BOLD}${CYAN} 3)${NC} MP3 256 kbps CBR"
    echo -e "  ${BOLD}${CYAN} 4)${NC} MP3 192 kbps CBR"
    echo -e "  ${BOLD}${BLUE}── [ OGG VORBIS & OPUS FORMATS ] ─────────────────────────────${NC}"
    echo -e "  ${BOLD}${CYAN} 5)${NC} Ogg Vorbis Quality 10 (~500 kbps Ultra Quality .ogg)"
    echo -e "  ${BOLD}${CYAN} 6)${NC} Ogg Vorbis Quality 8 (~256 kbps Standard .ogg)"
    echo -e "  ${BOLD}${CYAN} 7)${NC} Opus 160 kbps (High-Efficiency Broadcast / Streaming)"
    echo -e "  ${BOLD}${CYAN} 8)${NC} Opus 128 kbps"
    echo -e "  ${BOLD}${BLUE}── [ APPLE FORMATS (AAC & ALAC) ] ────────────────────────────${NC}"
    echo -e "  ${BOLD}${CYAN} 9)${NC} Apple AAC 320 kbps (.m4a)"
    echo -e "  ${BOLD}${CYAN}10)${NC} Apple AAC 256 kbps (iTunes / Apple Podcasts Standard .m4a)"
    echo -e "  ${BOLD}${CYAN}11)${NC} Apple ALAC Lossless (.m4a Apple Lossless Audio Codec)"
    echo -e "  ${BOLD}${BLUE}── [ WAV TO WAV (BIT DEPTH CONVERSION) ] ─────────────────────${NC}"
    echo -e "  ${BOLD}${CYAN}12)${NC} WAV 32-bit Float PCM (Master Studio Floating Point)"
    echo -e "  ${BOLD}${CYAN}13)${NC} WAV 24-bit Signed PCM (24-bit Studio Lossless WAV)"
    echo -e "  ${BOLD}${CYAN}14)${NC} WAV 16-bit Signed PCM (CD Standard 44.1 kHz, 16-bit)"
    echo -e "  ${BOLD}${CYAN}15)${NC} WAV 16-bit Signed PCM (Native Sample Rate, 16-bit)"
    echo -e "  ${BOLD}${BLUE}── [ FLAC LOSSLESS ] ─────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}${CYAN}16)${NC} FLAC 24-bit Lossless"
    echo -e "  ${BOLD}${CYAN}17)${NC} FLAC 16-bit CD Standard Lossless"
    echo -e "  ${BOLD}${CYAN} 0)${NC} Cancel and Return"
    echo ""

    read -r -p "Enter choice [1-17]: " fmt_choice

    case "$fmt_choice" in
        1)  FMT_NAME="MP3 320k CBR";        OPTS="-c:a libmp3lame -b:a 320k";                     EXT="mp3"; SUB_DIR="MP3_320K" ;;
        2)  FMT_NAME="MP3 V0 VBR";          OPTS="-c:a libmp3lame -q:a 0";                        EXT="mp3"; SUB_DIR="MP3_V0" ;;
        3)  FMT_NAME="MP3 256k CBR";        OPTS="-c:a libmp3lame -b:a 256k";                     EXT="mp3"; SUB_DIR="MP3_256K" ;;
        4)  FMT_NAME="MP3 192k CBR";        OPTS="-c:a libmp3lame -b:a 192k";                     EXT="mp3"; SUB_DIR="MP3_192K" ;;
        5)  FMT_NAME="Ogg Vorbis Q10";      OPTS="-c:a libvorbis -q:a 10";                        EXT="ogg"; SUB_DIR="OGG_Q10" ;;
        6)  FMT_NAME="Ogg Vorbis Q8";       OPTS="-c:a libvorbis -q:a 8";                         EXT="ogg"; SUB_DIR="OGG_Q8" ;;
        7)  FMT_NAME="Opus 160k";           OPTS="-c:a libopus -b:a 160k";                        EXT="opus"; SUB_DIR="OPUS_160K" ;;
        8)  FMT_NAME="Opus 128k";           OPTS="-c:a libopus -b:a 128k";                        EXT="opus"; SUB_DIR="OPUS_128K" ;;
        9)  FMT_NAME="Apple AAC 320k";      OPTS="-c:a aac -b:a 320k";                            EXT="m4a"; SUB_DIR="AAC_320K" ;;
        10) FMT_NAME="Apple AAC 256k";      OPTS="-c:a aac -b:a 256k";                            EXT="m4a"; SUB_DIR="AAC_256K" ;;
        11) FMT_NAME="Apple ALAC Lossless"; OPTS="-c:a alac";                                     EXT="m4a"; SUB_DIR="ALAC_LOSSLESS" ;;
        12) FMT_NAME="WAV 32-bit Float";    OPTS="-c:a pcm_f32le";                                EXT="wav"; SUB_DIR="WAV_32BIT_FLOAT" ;;
        13) FMT_NAME="WAV 24-bit PCM";      OPTS="-c:a pcm_s24le";                                EXT="wav"; SUB_DIR="WAV_24BIT" ;;
        14) FMT_NAME="WAV 16-bit 44.1kHz";  OPTS="-c:a pcm_s16le -ar 44100";                      EXT="wav"; SUB_DIR="WAV_16BIT_44K" ;;
        15) FMT_NAME="WAV 16-bit PCM";      OPTS="-c:a pcm_s16le";                                EXT="wav"; SUB_DIR="WAV_16BIT" ;;
        16) FMT_NAME="FLAC 24-bit";         OPTS="-sample_fmt s32 -c:a flac -compression_level 8"; EXT="flac"; SUB_DIR="FLAC_24BIT" ;;
        17) FMT_NAME="FLAC 16-bit";         OPTS="-sample_fmt s16 -c:a flac -compression_level 8"; EXT="flac"; SUB_DIR="FLAC_16BIT" ;;
        0|q|Q) echo "Conversion cancelled."; exit 0 ;;
        *) echo -e "${RED}Invalid choice!${NC}"; exit 1 ;;
    esac
fi

scope_choice="${CLI_SCOPE:-}"
if [ -z "$scope_choice" ]; then
    echo -e "\n${BOLD}Select Input Scope:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Single Audio File (Search & Pick or Enter Path)"
    echo -e "  ${BOLD}${CYAN}2)${NC} All WAV Files in Staging / Current Directory"
    echo -e "  ${BOLD}${CYAN}3)${NC} All Converted WAV Archive Files (CONVERTED_WAV_FILES)"
    echo -e "  ${BOLD}${CYAN}4)${NC} All FLAC Outputs (FLAC_CONVERTED_OUTPUTS)"
    echo ""
    read -r -p "Enter choice [1-4]: " scope_choice
fi

if [ "$EXT" = "mp3" ]; then
    DEFAULT_OUT_DIR="${MP3_OUTPUT_DIR:-MP3_CONVERTED_OUTPUTS}"
elif [ "$EXT" = "wav" ]; then
    DEFAULT_OUT_DIR="${WAV_OUTPUT_DIR:-WAV_CONVERTED_OUTPUTS}"
elif [ "$EXT" = "flac" ]; then
    DEFAULT_OUT_DIR="${FLAC_OUTPUT_DIR:-${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}}"
else
    DEFAULT_OUT_DIR="CONVERTED_AUDIO_OUTPUTS/$SUB_DIR"
fi

configure_conversion_metadata_and_cover

case "$scope_choice" in
    1)
        read -r -e -p "Enter path to audio file (or search keyword, Enter to browse): " user_input
        user_input=$(echo "$user_input" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        
        target_file=""
        if [ -n "$user_input" ] && [ -f "$user_input" ]; then
            target_file="$user_input"
        else
            shopt -s nullglob nocaseglob
            raw_candidates=()
            if [ -n "$user_input" ]; then
                raw_candidates+=(*"$user_input"*.[wW][aA][vV] *"$user_input"*.[fF][lL][aA][cC] *"$user_input"*.[oO][gG][gG] *"$user_input"*.[mM][pP]3)
                for fd in "${all_flac_dirs[@]}"; do
                    [ -d "$fd" ] && raw_candidates+=("$fd"/*"$user_input"*.[fF][lL][aA][cC] "$fd"/*"$user_input"*.[wW][aA][vV] "$fd"/*"$user_input"*.[oO][gG][gG] "$fd"/*"$user_input"*.[mM][pP]3)
                done
                for wd in "${all_wav_dirs[@]}"; do
                    [ -d "$wd" ] && raw_candidates+=("$wd"/*"$user_input"*.[wW][aA][vV] "$wd"/*"$user_input"*.[oO][gG][gG])
                done
                for arch_d in "${all_mix_archive_roots[@]}"; do
                    [ -d "$arch_d" ] && raw_candidates+=("$arch_d"/*"$user_input"*.[wW][aA][vV] "$arch_d"/*"$user_input"*.[oO][gG][gG] "$arch_d"/*"$user_input"*.[fF][lL][aA][cC])
                done
            else
                for arch_d in "${all_mix_archive_roots[@]}"; do
                    [ -d "$arch_d" ] || continue
                    for cand_file in "$arch_d"/*.[wW][aA][vV] "$arch_d"/*.[oO][gG][gG]; do
                        [ -f "$cand_file" ] && raw_candidates+=("$cand_file")
                    done
                    if [ -d "$arch_d/UNCONVERTED_WAVS" ]; then
                        for cand_file in "$arch_d/UNCONVERTED_WAVS"/*.[wW][aA][vV]; do
                            [ -f "$cand_file" ] && raw_candidates+=("$cand_file")
                        done
                    fi
                done
                for cand_file in ./*.[wW][aA][vV] ./*.[oO][gG][gG]; do
                    [ -f "$cand_file" ] && raw_candidates+=("$cand_file")
                done
            fi
            shopt -u nullglob nocaseglob

            candidates=()
            declare -A seen_candidates=()
            for cand in "${raw_candidates[@]}"; do
                [ -f "$cand" ] || continue
                real_c="$(cd "$(dirname "$cand")" 2>/dev/null && pwd -P)/$(basename "$cand")"
                if [ -z "${seen_candidates[$real_c]:-}" ]; then
                    seen_candidates[$real_c]=1
                    candidates+=("$cand")
                fi
            done

            if [ ${#candidates[@]} -eq 0 ]; then
                echo -e "${RED}No audio files found matching '$user_input' across configured archives!${NC}"
                exit 1
            elif [ ${#candidates[@]} -eq 1 ]; then
                target_file="${candidates[0]}"
                echo -e "\n${GREEN}Found:${NC} $target_file"
            else
                echo -e "\nMatching files found across archives:"
                for i in "${!candidates[@]}"; do
                    echo "  $((i+1))) [$(basename "$(dirname "${candidates[$i]}")")] $(basename "${candidates[$i]}")"
                done
                read -r -p "Select file [1-${#candidates[@]}]: " pick
                if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#candidates[@]}" ]; then
                    target_file="${candidates[$((pick-1))]}"
                else
                    echo -e "${RED}Invalid selection!${NC}"
                    exit 1
                fi
            fi
        fi

        # Route default output directory to the file's owning mix archive
        target_dir="$(dirname "$target_file")"
        target_real="$(cd "$target_dir" 2>/dev/null && pwd -P || echo "$target_dir")"
        target_archive_dir=""
        for arch_d in "${all_mix_archive_roots[@]}"; do
            arch_real="$(cd "$arch_d" 2>/dev/null && pwd -P || echo "$arch_d")"
            if [ "$target_real" = "$arch_real" ] || [[ "$target_real" == "$arch_real"/* ]]; then
                target_archive_dir="$arch_d"
                break
            fi
        done

        if [ -n "$target_archive_dir" ] && [ -d "$target_archive_dir" ]; then
            if [ "$EXT" = "mp3" ]; then
                DEFAULT_OUT_DIR="$target_archive_dir/MP3_CONVERTED_OUTPUTS"
            elif [ "$EXT" = "wav" ]; then
                DEFAULT_OUT_DIR="$target_archive_dir/WAV_CONVERTED_OUTPUTS"
            elif [ "$EXT" = "flac" ]; then
                DEFAULT_OUT_DIR="$target_archive_dir/FLAC_CONVERTED_OUTPUTS"
            else
                DEFAULT_OUT_DIR="$target_archive_dir/CONVERTED_AUDIO_OUTPUTS/$SUB_DIR"
            fi
        fi

        echo ""
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== STARTING CONVERSION ===${NC}\n"
        convert_file "$target_file" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"
        ;;
    2)
        shopt -s nullglob nocaseglob
        wav_files=(*.[wW][aA][vV] *.[oO][gG][gG])
        shopt -u nullglob nocaseglob
        if [ ${#wav_files[@]} -eq 0 ]; then
            echo -e "${RED}No WAV or OGG files found in current directory!${NC}"
            exit 1
        fi
        echo -e "\nFound ${#wav_files[@]} audio file(s)."
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== BATCH CONVERSION STARTED (${#wav_files[@]} files) ===${NC}\n"
        success=0
        for wf in "${wav_files[@]}"; do
            if convert_file "$wf" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"; then
                ((success++))
            fi
        done
        echo -e "${BOLD}${GREEN}✓ Batch conversion completed: $success / ${#wav_files[@]} succeeded!${NC}\n"
        ;;
    3)
        shopt -s nullglob nocaseglob
        wav_files=()
        for wd in "${all_wav_dirs[@]}"; do
            [ -d "$wd" ] && wav_files+=("$wd"/*.[wW][aA][vV] "$wd"/*.[oO][gG][gG])
        done
        shopt -u nullglob nocaseglob
        if [ ${#wav_files[@]} -eq 0 ]; then
            echo -e "${RED}No WAV or OGG files found across configured WAV/OGG archives!${NC}"
            exit 1
        fi
        echo -e "\nFound ${#wav_files[@]} audio file(s) across ${#all_wav_dirs[@]} archive location(s)."
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== BATCH CONVERSION STARTED (${#wav_files[@]} files) ===${NC}\n"
        success=0
        for wf in "${wav_files[@]}"; do
            if convert_file "$wf" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"; then
                ((success++))
            fi
        done
        echo -e "${BOLD}${GREEN}✓ Batch conversion completed: $success / ${#wav_files[@]} succeeded!${NC}\n"
        ;;
    4)
        shopt -s nullglob nocaseglob
        flac_files=()
        for fd in "${all_flac_dirs[@]}"; do
            [ -d "$fd" ] && flac_files+=("$fd"/*.[fF][lL][aA][cC])
        done
        shopt -u nullglob nocaseglob
        if [ ${#flac_files[@]} -eq 0 ]; then
            echo -e "${RED}No FLAC files found across configured FLAC archives!${NC}"
            exit 1
        fi
        echo -e "\nFound ${#flac_files[@]} FLAC file(s) across ${#all_flac_dirs[@]} archive location(s)."
        read -r -e -p "Enter output directory [default: $DEFAULT_OUT_DIR]: " custom_out
        final_out="${custom_out:-$DEFAULT_OUT_DIR}"

        echo -e "\n${BOLD}${GREEN}=== BATCH CONVERSION STARTED (${#flac_files[@]} files) ===${NC}\n"
        success=0
        for ff in "${flac_files[@]}"; do
            if convert_file "$ff" "$FMT_NAME" "$final_out" "$OPTS" "$EXT"; then
                ((success++))
            fi
        done
        echo -e "${BOLD}${GREEN}✓ Batch conversion completed: $success / ${#flac_files[@]} succeeded!${NC}\n"
        ;;
    *)
        echo -e "${RED}Invalid scope!${NC}"
        exit 1
        ;;
esac
