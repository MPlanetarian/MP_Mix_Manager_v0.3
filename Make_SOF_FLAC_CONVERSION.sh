#!/usr/bin/env bash

# ==============================================================================
# Make_SOF_FLAC_CONVERSION.sh
# Universal Multi-Platform FLAC Audio Conversion & Session Grouper
# Compatible with macOS (Bash 3.2 / 4 / 5), Linux, and Windows
# ==============================================================================

set -eo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

# Auto-upgrade to modern Homebrew Bash on macOS if running under ancient Bash 3.2
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] && [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    if [ -x "/opt/homebrew/bin/bash" ]; then
        exec /opt/homebrew/bin/bash "$0" "$@"
    elif [ -x "/usr/local/bin/bash" ]; then
        exec /usr/local/bin/bash "$0" "$@"
    fi
fi

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

# ================================
# USER CONFIGURATION & SETUP
# ================================
OUTPUT_DIR="${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}"
ARCHIVE_DIR="${ARCHIVE_DIR:-CONVERTED_WAV_FILES}"
SPEK_DIR="${SPEK_DIR:-SPEK_OUTPUTS}"
LOG_FILE="FLAC_CONVERSION_SOF.log"
COVER_ART="Cover.png"

# Resolve relative to MIX_ARCHIVE_DIR if configured
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
    if [[ "$OUTPUT_DIR" != /* ]] && [ -d "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" ]; then
        OUTPUT_DIR="$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS"
    fi
    if [[ "$ARCHIVE_DIR" != /* ]] && [ -d "$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES" ]; then
        ARCHIVE_DIR="$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES"
    fi
fi

# Discover all FLAC check directories for existing mix detection
flac_check_dirs=()
[ -d "$OUTPUT_DIR" ] && flac_check_dirs+=("$(cd "$OUTPUT_DIR" && pwd)")
if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
    IFS=':;,' read -ra EXTRA_DIRS <<< "$EXTRA_MIX_ARCHIVE_DIRS"
    for ed in "${EXTRA_DIRS[@]}"; do
        ed="$(echo "$ed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "$ed" ] && continue
        if [ -d "$ed/FLAC_CONVERTED_OUTPUTS" ]; then
            cand="$(cd "$ed/FLAC_CONVERTED_OUTPUTS" && pwd)"
            [[ ! " ${flac_check_dirs[*]} " =~ " ${cand} " ]] && flac_check_dirs+=("$cand")
        elif [ -d "$ed" ]; then
            cand="$(cd "$ed" && pwd)"
            [[ ! " ${flac_check_dirs[*]} " =~ " ${cand} " ]] && flac_check_dirs+=("$cand")
        fi
    done
fi

# Cross-platform helper functions (Bash 3.2+ compatible)
get_abs_path() {
    local target="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath "$target" 2>/dev/null || readlink -f "$target" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import os, sys; print(os.path.abspath(sys.argv[1]))" "$target" 2>/dev/null
    else
        echo "$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")"
    fi
}

get_str_hash() {
    local s="$1"
    if command -v md5sum >/dev/null 2>&1; then
        echo -n "$s" | md5sum | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q -s "$s"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import hashlib, sys; print(hashlib.md5(sys.argv[1].encode('utf-8')).hexdigest())" "$s"
    else
        echo -n "$s" | cksum | awk '{print $1}'
    fi
}

safe_mktemp() {
    local ext="${1:-}"
    if [ -n "$ext" ]; then
        mktemp "${TMPDIR:-/tmp}/sof_${ext}_XXXXXX.${ext}" 2>/dev/null || \
        mktemp -t "sof_${ext}_XXXXXX.${ext}" 2>/dev/null || \
        mktemp "/tmp/sof_${ext}_XXXXXX.${ext}"
    else
        mktemp "${TMPDIR:-/tmp}/sof_XXXXXX" 2>/dev/null || \
        mktemp -t "sof_XXXXXX" 2>/dev/null || \
        mktemp "/tmp/sof_XXXXXX"
    fi
}

# Copy history_*.nml files that exist on the Traktor machine but not locally.
# Files already present are left untouched. A failed share check does not stop conversion.
sync_missing_traktor_history() {
    local dest="$1"
    local cred="" remote_raw="" remote_names="" local_names="" missing="" missing_count=0
    local remote_dir smb_target list_cmd get_cmd smb_err copied=0 smb_rc=0

    if [ -z "${TRAKTOR_SMB_HOST:-}" ] || [ -z "${TRAKTOR_SMB_SHARE:-}" ] || [ -z "${TRAKTOR_SMB_USER:-}" ] || [ -z "${TRAKTOR_SMB_PASSWORD:-}" ]; then
        echo " -> Traktor history sync skipped (SMB host, share, user, or password is not set)."
        return 0
    fi
    if ! command -v smbclient >/dev/null 2>&1; then
        echo " -> WARNING: smbclient is not installed. Continuing with the local Traktor history only."
        return 0
    fi
    if [ -z "$dest" ]; then
        echo " -> WARNING: No local Traktor history directory is configured. Skipping history sync."
        return 0
    fi
    if [ ! -d "$dest" ]; then
        mkdir -p "$dest" 2>/dev/null || {
            echo " -> WARNING: Could not create Traktor history directory: $dest"
            return 0
        }
    fi

    remote_dir="${TRAKTOR_SMB_HISTORY_DIR:-Documents/Native Instruments/Traktor 3.11.1/History}"
    smb_target="//${TRAKTOR_SMB_HOST}/${TRAKTOR_SMB_SHARE}"
    umask 077
    cred=$(mktemp "${TMPDIR:-/tmp}/sof_smb_XXXXXX" 2>/dev/null || mktemp /tmp/sof_smb_XXXXXX)
    remote_raw=$(mktemp "${TMPDIR:-/tmp}/sof_smb_dir_XXXXXX" 2>/dev/null || mktemp /tmp/sof_smb_dir_XXXXXX)
    remote_names=$(mktemp "${TMPDIR:-/tmp}/sof_smb_remote_XXXXXX" 2>/dev/null || mktemp /tmp/sof_smb_remote_XXXXXX)
    local_names=$(mktemp "${TMPDIR:-/tmp}/sof_smb_local_XXXXXX" 2>/dev/null || mktemp /tmp/sof_smb_local_XXXXXX)
    missing=$(mktemp "${TMPDIR:-/tmp}/sof_smb_missing_XXXXXX" 2>/dev/null || mktemp /tmp/sof_smb_missing_XXXXXX)
    smb_err=$(mktemp "${TMPDIR:-/tmp}/sof_smb_err_XXXXXX" 2>/dev/null || mktemp /tmp/sof_smb_err_XXXXXX)

    cleanup_smb() {
        rm -f "$cred" "$remote_raw" "$remote_names" "$local_names" "$missing" "$smb_err" 2>/dev/null || true
    }

    printf 'username=%s\npassword=%s\n' "$TRAKTOR_SMB_USER" "$TRAKTOR_SMB_PASSWORD" > "$cred"
    echo " -> Checking Traktor history on ${smb_target} ..."

    list_cmd="cd \"${remote_dir}\"; dir"
    smb_rc=0
    if command -v timeout >/dev/null 2>&1; then
        timeout 40 smbclient "$smb_target" -A "$cred" -t 20 -c "$list_cmd" > "$remote_raw" 2>"$smb_err" || smb_rc=$?
    else
        smbclient "$smb_target" -A "$cred" -t 20 -c "$list_cmd" > "$remote_raw" 2>"$smb_err" || smb_rc=$?
    fi
    if [ "$smb_rc" -ne 0 ]; then
        echo " -> WARNING: Could not read the Traktor history share. Continuing with local files."
        if [ -s "$smb_err" ]; then
            sed -n '1,3p' "$smb_err" | sed 's/^/    /'
        fi
        cleanup_smb
        return 0
    fi

    awk '{
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^history_.*\.nml$/) {
                print $i
                break
            }
        }
    }' "$remote_raw" | sort -u > "$remote_names"

    find "$dest" -maxdepth 1 -type f -name 'history_*.nml' -exec basename {} \; 2>/dev/null | sort -u > "$local_names"
    comm -23 "$remote_names" "$local_names" > "$missing"
    missing_count=$(grep -c . "$missing" || true)

    if [ "$missing_count" -eq 0 ]; then
        echo " -> Traktor history files are already available locally. Nothing to copy."
        cleanup_smb
        return 0
    fi

    echo " -> Copying ${missing_count} Traktor history file(s) that are not on this machine..."
    get_cmd="cd \"${remote_dir}\"; prompt OFF;"
    while IFS= read -r hist_name || [ -n "$hist_name" ]; do
        [ -n "$hist_name" ] || continue
        if [ -f "$dest/$hist_name" ]; then
            continue
        fi
        get_cmd="${get_cmd} get \"${hist_name}\";"
    done < "$missing"

    if ( cd "$dest" && smbclient "$smb_target" -A "$cred" -t 30 -c "$get_cmd" >"$remote_raw" 2>"$smb_err" ); then
        while IFS= read -r hist_name || [ -n "$hist_name" ]; do
            [ -n "$hist_name" ] || continue
            if [ -f "$dest/$hist_name" ]; then
                copied=$((copied + 1))
            else
                echo " -> WARNING: Failed to copy ${hist_name}"
            fi
        done < "$missing"
        echo " -> Copied ${copied} Traktor history file(s)."
    else
        echo " -> WARNING: Copy from the Traktor history share failed. Continuing with local files."
        if [ -s "$smb_err" ]; then
            sed -n '1,3p' "$smb_err" | sed 's/^/    /'
        fi
    fi
    cleanup_smb
    return 0
}

# Direct Local Traktor History Directory (Auto-detected across Linux, macOS, and Windows)
LOCAL_HISTORY_DIR="${TRAKTOR_HISTORY_DIR:-}"
if [ -z "$LOCAL_HISTORY_DIR" ] || [ ! -d "$LOCAL_HISTORY_DIR" ]; then
    for cand in \
        "${MIX_ARCHIVE_DIR:-$PWD}/Traktor 3.11.1/History" \
        "./Traktor 3.11.1/History" \
        "/run/media/$USER/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/Volumes/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/Volumes/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/Volumes/DATAMAC3/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/d/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "D:/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "/mnt/d/MIX_ARCHIVE/Traktor 3.11.1/History" \
        "$HOME/Documents/Native Instruments/Traktor 3.11.1/History" \
        "$HOME/Native Instruments/Traktor 3.11.1/History"
    do
        if [ -d "$cand" ]; then
            LOCAL_HISTORY_DIR="$cand"
            break
        fi
    done
fi

# Ask which format to write before any files are moved or the log is cleared.
# Enter keeps the usual FLAC conversion. SOF_OUTPUT_FORMAT skips the question.
choose_conversion_output() {
    OUTPUT_FORMAT="${SOF_OUTPUT_FORMAT:-}"
    case "$OUTPUT_FORMAT" in
        flac|mp3|wav|mp4|ogg) return 0 ;;
    esac
    OUTPUT_FORMAT=""
    if [ ! -r /dev/tty ]; then
        OUTPUT_FORMAT="flac"
        return 0
    fi
    while true; do
        {
            echo "=================================================="
            echo "The audio files in this folder are ready to convert."
            echo "Choose the output before conversion starts."
            echo "  1) FLAC lossless          (default, press Enter)"
            echo "  2) MP3 320 kbps"
            echo "  3) WAV 24-bit"
            echo "  4) MP4 YouTube video      (1080p, still cover art)"
            echo "  5) OGG Vorbis             (320 kbps / quality 8)"
            echo "  0) Cancel"
            echo "=================================================="
        } >/dev/tty
        local format_choice=""
        read -r -p "Output [1/Enter = FLAC]: " format_choice </dev/tty || format_choice=""
        case "$format_choice" in
            ""|1) OUTPUT_FORMAT="flac"; return 0 ;;
            2) OUTPUT_FORMAT="mp3"; return 0 ;;
            3) OUTPUT_FORMAT="wav"; return 0 ;;
            4) OUTPUT_FORMAT="mp4"; return 0 ;;
            5) OUTPUT_FORMAT="ogg"; return 0 ;;
            0|[qQ]) echo "Conversion cancelled." >/dev/tty; exit 0 ;;
            *) echo "Choose 1, 2, 3, 4, 5, or 0." >/dev/tty ;;
        esac
    done
}

choose_conversion_output

# Metadata & ID Tag Defaults
CUSTOM_ARTIST="${SOF_ARTIST:-}"
CUSTOM_TITLE="${SOF_TITLE:-}"
CUSTOM_ALBUM="${SOF_ALBUM:-}"
CUSTOM_YEAR="${SOF_YEAR:-}"
CUSTOM_GENRE="${SOF_GENRE:-}"
CUSTOM_COMMENT="${SOF_COMMENT:-}"
CUSTOM_COVER_IMAGE="${SOF_COVER_IMAGE:-}"

configure_conversion_metadata_and_cover() {
    if [ ! -r /dev/tty ]; then
        return 0
    fi

    local tag_choice=""
    {
        echo ""
        echo "=================================================="
        echo "    AUDIO ID TAGS & COVER ARTWORK SETTINGS        "
        echo "=================================================="
        echo "Would you like to set custom tags or custom cover art?"
        echo "  [y/N] (Default: Enter = keep standard tags & default cover)"
        echo "=================================================="
    } >/dev/tty

    read -r -p "Customize audio tags & cover? [y/N]: " tag_choice </dev/tty || tag_choice=""
    case "$tag_choice" in
        [yY]|[yY][eE][sS])
            ;;
        *)
            echo " -> Using standard default tags and cover art." >/dev/tty
            return 0
            ;;
    esac

    {
        echo ""
        echo "--- Audio Metadata / ID Tags (Press Enter to keep default) ---"
    } >/dev/tty

    # 1. Artist
    local input_artist=""
    read -r -p "Artist Name [MPlanetarian]: " input_artist </dev/tty || input_artist=""
    CUSTOM_ARTIST="${input_artist:-MPlanetarian}"

    # 2. Mix / Track Title
    local input_title=""
    read -r -p "Mix / Track Title [Auto-detect from filename]: " input_title </dev/tty || input_title=""
    CUSTOM_TITLE="$input_title"

    # 3. Album Name
    local input_album=""
    read -r -p "Album / Series Name [Stream of Frequency]: " input_album </dev/tty || input_album=""
    CUSTOM_ALBUM="${input_album:-Stream of Frequency}"

    # 4. Release Year
    local def_year
    def_year="$(date +%Y)"
    local input_year=""
    read -r -p "Release Year [$def_year]: " input_year </dev/tty || input_year=""
    CUSTOM_YEAR="${input_year:-$def_year}"

    # 5. Genre
    local input_genre=""
    read -r -p "Genre [Electronic / Trance]: " input_genre </dev/tty || input_genre=""
    CUSTOM_GENRE="${input_genre:-Electronic / Trance}"

    # 6. Comment
    local input_comment=""
    read -r -p "Comment / Description [Stream of Frequency Mix Archive]: " input_comment </dev/tty || input_comment=""
    CUSTOM_COMMENT="${input_comment:-Stream of Frequency Mix Archive}"

    # 7. Cover Artwork Selection
    {
        echo ""
        echo "--- Cover Artwork Image Selection ---"
    } >/dev/tty

    local discovered_covers=()
    local search_paths=(
        "./Cover.png"
        "./assets/Cover.png"
        "./COVERS"
        "$SCRIPT_DIR/COVERS"
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

    {
        echo "  1) Default Cover Image (${COVER_ART:-Cover.png})"
        local c_idx=2
        for cov in "${discovered_covers[@]}"; do
            [ "$c_idx" -gt 9 ] && break
            echo "  ${c_idx}) Existing: $cov"
            ((c_idx++))
        done
        echo "  c) Enter full path to a custom image file (PNG / JPG)"
    } >/dev/tty

    local cov_choice=""
    read -r -p "Select cover option [1/Enter = default]: " cov_choice </dev/tty || cov_choice=""
    case "$cov_choice" in
        ""|1)
            echo " -> Selected default cover image." >/dev/tty
            ;;
        [cC]|[cC][uU][sS][tT][oO][mM])
            local custom_path=""
            read -r -p "Enter full path to cover image (or drag & drop): " custom_path </dev/tty || custom_path=""
            custom_path="${custom_path#\"}"
            custom_path="${custom_path%\"}"
            custom_path="${custom_path#\'}"
            custom_path="${custom_path%\'}"
            custom_path="$(eval echo "$custom_path")"
            if [ -n "$custom_path" ] && [ -f "$custom_path" ]; then
                CUSTOM_COVER_IMAGE="$custom_path"
                echo " -> Custom cover art verified: $CUSTOM_COVER_IMAGE" >/dev/tty
            else
                echo " -> Warning: File '$custom_path' not found. Using default cover." >/dev/tty
            fi
            ;;
        [2-9])
            local target_idx=$((cov_choice - 2))
            if [ "$target_idx" -lt "${#discovered_covers[@]}" ]; then
                CUSTOM_COVER_IMAGE="${discovered_covers[$target_idx]}"
                echo " -> Selected existing cover: $CUSTOM_COVER_IMAGE" >/dev/tty
            else
                echo " -> Invalid selection. Using default cover." >/dev/tty
            fi
            ;;
        *)
            echo " -> Invalid selection. Using default cover." >/dev/tty
            ;;
    esac

    {
        echo ""
        echo "=================================================="
        echo "Configured Tag Summary:"
        echo "  Artist:  ${CUSTOM_ARTIST:-MPlanetarian}"
        echo "  Title:   ${CUSTOM_TITLE:-[Auto-detect from filename]}"
        echo "  Album:   ${CUSTOM_ALBUM:-Stream of Frequency}"
        echo "  Year:    ${CUSTOM_YEAR:-$def_year}"
        echo "  Genre:   ${CUSTOM_GENRE:-Electronic / Trance}"
        echo "  Cover:   ${CUSTOM_COVER_IMAGE:-Default ($COVER_ART)}"
        echo "=================================================="
        echo ""
    } >/dev/tty
}

configure_conversion_metadata_and_cover

case "$OUTPUT_FORMAT" in
    mp3)
        OUTPUT_EXT="mp3"
        OUTPUT_LABEL="MP3"
        OUTPUT_DIR="${MP3_OUTPUT_DIR:-MP3_CONVERTED_OUTPUTS}"
        ;;
    wav)
        OUTPUT_EXT="wav"
        OUTPUT_LABEL="WAV"
        OUTPUT_DIR="${WAV_OUTPUT_DIR:-WAV_CONVERTED_OUTPUTS}"
        ;;
    mp4)
        OUTPUT_EXT="mp4"
        OUTPUT_LABEL="MP4"
        OUTPUT_DIR="${MP4_OUTPUT_DIR:-MP4_CONVERTED_OUTPUTS}"
        ;;
    ogg)
        OUTPUT_EXT="ogg"
        OUTPUT_LABEL="OGG"
        OUTPUT_DIR="${OGG_OUTPUT_DIR:-OGG_CONVERTED_OUTPUTS}"
        ;;
    *)
        OUTPUT_FORMAT="flac"
        OUTPUT_EXT="flac"
        OUTPUT_LABEL="FLAC"
        ;;
esac

if [ "$OUTPUT_FORMAT" != "flac" ] && [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ] && [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$MIX_ARCHIVE_DIR/${OUTPUT_DIR#./}"
fi

# Start timer and log start time
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
START_SECONDS=$(date +%s)

mkdir -p "$OUTPUT_DIR"
mkdir -p "$ARCHIVE_DIR"
mkdir -p "$SPEK_DIR"
: > "$LOG_FILE"

# Tee all output to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo "${OUTPUT_LABEL} conversion started at: $START_TIME"
echo "=================================================="

# Check History Directory Availability, then fetch any history files that are not here yet
if [ -d "$LOCAL_HISTORY_DIR" ]; then
    echo " -> Traktor History directory located successfully at: $LOCAL_HISTORY_DIR"
elif [ -n "${TRAKTOR_HISTORY_DIR:-}" ]; then
    LOCAL_HISTORY_DIR="$TRAKTOR_HISTORY_DIR"
    echo " -> WARNING: Traktor History directory was missing. It will be created if the share can be reached."
else
    echo " -> WARNING: Traktor History directory not found at specified path!"
fi
sync_missing_traktor_history "$LOCAL_HISTORY_DIR"
if [ -d "$LOCAL_HISTORY_DIR" ]; then
    echo " -> Traktor History directory ready at: $LOCAL_HISTORY_DIR"
fi

# Cover Art Verification and Fallback
if [ -n "${CUSTOM_COVER_IMAGE:-}" ] && [ -f "$CUSTOM_COVER_IMAGE" ]; then
    COVER_ART="$CUSTOM_COVER_IMAGE"
elif [ ! -f "$COVER_ART" ]; then
    if [ -f "$SCRIPT_DIR/assets/Cover.png" ]; then
        COVER_ART="$SCRIPT_DIR/assets/Cover.png"
    elif [ -f "$SCRIPT_DIR/Cover.png" ]; then
        COVER_ART="$SCRIPT_DIR/Cover.png"
    elif [ -f "$PARENT_DIR/Cover.png" ]; then
        COVER_ART="$PARENT_DIR/Cover.png"
    else
        echo "ERROR: Required artwork file '$COVER_ART' not found in the current directory!"
        echo "Please place 'Cover.png' in this directory or specify a custom cover."
        exit 1
    fi
fi
echo "Cover art ready ($COVER_ART)."

# Enable globstar and nullglob for robust file matching
shopt -s nullglob nocaseglob

# Check for explicit file arguments (supports single or multiple files, cleans hidden line breaks)
declare -a TARGET_FILES=()
if [ $# -gt 0 ]; then
    for arg in "$@"; do
        clean_arg=$(echo "$arg" | tr -d '\r' | tr -d '\n')
        if [ -f "$clean_arg" ]; then
            abs_target=$(get_abs_path "$clean_arg")
            TARGET_FILES+=("$abs_target")
            echo "Target file added: $(basename "$clean_arg")"
        else
            echo "ERROR: Specified file '$clean_arg' not found!"
            exit 1
        fi
    done
    echo "Multi-file/Explicit target mode enabled. Total targets: ${#TARGET_FILES[@]}"
fi

# Helper function to extract the session base name across all split chunks
get_session_base_name() {
    local fname="$1"
    local name="${fname%.[Ww][Aa][Vv]}"
    name="${name%.[Ff][Ll][Aa][Cc]}"
    name="${name%.[Mm][Pp]3}"
    name="${name%.[Oo][Gg][Gg]}"

    # 1. Traktor split chunks: session timestamp + split duration offset (e.g. _4h53m32_03h02m02 or _14h00m00_0h52m07)
    # Strip only the trailing split duration offset, preserving the session timestamp
    if [[ "$name" =~ ^(.*_[0-9]{1,2}h[0-9]{2}m[0-9]{2}s?)_[0-9]{1,2}h[0-9]{2}m[0-9]{2}s?$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # 2. Check single timestamp: if preceded by a date (e.g. _2026-09-29_4h53m32), it is the session start time
    if [[ "$name" =~ ^(.*)_[0-9]{1,2}h[0-9]{2}m[0-9]{2}s?$ ]]; then
        local cand_prefix="${BASH_REMATCH[1]}"
        # If candidate prefix ends with a date (e.g. _2026-09-29), then the trailing time is the session start time
        if [[ "$cand_prefix" =~ _[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo "$name"
            return 0
        fi
        # If it is an explicit 00h00m00 offset, strip it
        if [[ "$name" =~ ^(.*)_0{1,2}h00m00s?$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return 0
        fi
        # Check if the unsuffixed parent/root file exists in current directory or target path
        local parent_d
        parent_d=$(dirname "$fname" 2>/dev/null || echo ".")
        if [ -f "$parent_d/${cand_prefix}.wav" ] || [ -f "$parent_d/${cand_prefix}.WAV" ] || [ -f "$parent_d/${cand_prefix}.ogg" ] || [ -f "$parent_d/${cand_prefix}.OGG" ] || [ -f "${cand_prefix}.wav" ] || [ -f "${cand_prefix}.WAV" ] || [ -f "${cand_prefix}.ogg" ] || [ -f "${cand_prefix}.OGG" ]; then
            echo "$cand_prefix"
            return 0
        fi
    fi

    # 3. Standard part suffixes at the end of the filename: _part01, _part1, _pt1, _cd1, etc.
    local orig_nocase
    orig_nocase=$(shopt -p nocasematch 2>/dev/null || true)
    shopt -s nocasematch
    if [[ "$name" =~ ^(.*)[_\ -]+(part|pt|cd|disc|disk|subpart)[_\ -]*[0-9]+$ ]]; then
        local stripped="${BASH_REMATCH[1]}"
        eval "$orig_nocase" 2>/dev/null || true
        echo "$stripped"
        return 0
    fi
    eval "$orig_nocase" 2>/dev/null || true

    echo "$name"
}

# 1. Discover and group audio files cleanly (Bash 3.2+ & macOS compatible without associative arrays)
GROUP_TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/sof_groups_XXXXXX" 2>/dev/null || mktemp -d /tmp/sof_groups_XXXXXX)
trap 'rm -rf "$GROUP_TMP_DIR" "${OPTIMIZED_COVER:-}" 2>/dev/null || true' EXIT

declare -a group_keys=()

if [ ${#TARGET_FILES[@]} -gt 0 ]; then
    search_list=("${TARGET_FILES[@]}")
else
    search_list=(./*.[wW][aA][vV] ./*.[oO][gG][gG])
fi

for file in "${search_list[@]}"; do
    [ -e "$file" ] || continue
    abs_file=$(get_abs_path "$file")
    [ -f "$abs_file" ] || continue

    file_hash=$(get_str_hash "$abs_file")
    if [ -f "$GROUP_TMP_DIR/seen_${file_hash}" ]; then
        continue
    fi
    touch "$GROUP_TMP_DIR/seen_${file_hash}"

    filename=$(basename "$file")
    base_name=$(get_session_base_name "$file")
    base_name=$(basename "$base_name")

    base_hash=$(get_str_hash "$base_name")
    if [ ! -f "$GROUP_TMP_DIR/group_${base_hash}.base" ]; then
        echo "$base_name" > "$GROUP_TMP_DIR/group_${base_hash}.base"
        group_keys+=("$base_hash")
    fi
    echo "$abs_file" >> "$GROUP_TMP_DIR/group_${base_hash}.wavs"
done

total_groups=${#group_keys[@]}

if [ "$total_groups" -eq 0 ]; then
    echo "Error: No matching .wav files found to process."
    exit 1
fi

echo "Found $total_groups unique audio session group(s) to process."

# 2. Calculate Total Source Size & Check Available Disk Space
total_size_bytes=0
for g_hash in "${group_keys[@]}"; do
    wav_file_list="$GROUP_TMP_DIR/group_${g_hash}.wavs"
    if [ -f "$wav_file_list" ]; then
        while IFS= read -r wav || [ -n "$wav" ]; do
            [ -z "$wav" ] && continue
            size=$(wc -c < "$wav" 2>/dev/null || stat -c %s "$wav" 2>/dev/null || stat -f %z "$wav" 2>/dev/null || echo 0)
            total_size_bytes=$((total_size_bytes + size))
        done < "$wav_file_list"
    fi
done

if command -v python3 >/dev/null 2>&1; then
    available_space_bytes=$(python3 -c "import shutil, sys; print(shutil.disk_usage(sys.argv[1]).free)" "$OUTPUT_DIR" 2>/dev/null || echo 0)
else
    available_space_bytes=$(df -k "$OUTPUT_DIR" 2>/dev/null | awk 'NR==2 {print $4 * 1024}')
fi
[ -z "$available_space_bytes" ] && available_space_bytes=0

if [ "$available_space_bytes" -gt 0 ] && [ "$available_space_bytes" -lt "$total_size_bytes" ]; then
    echo "--------------------------------------------------"
    echo "ERROR: Insufficient disk space!"
    echo " -> Total WAV source size:  $((total_size_bytes / 1024 / 1024)) MB"
    echo " -> Available disk space:   $((available_space_bytes / 1024 / 1024)) MB"
    exit 1
else
    echo "Disk space check passed: $((available_space_bytes / 1024 / 1024)) MB available."
fi

# 3. Estimate processing time
estimated_seconds=$((total_size_bytes / 50000000))
if [ "$estimated_seconds" -lt 10 ]; then estimated_seconds=10; fi

if date -u -d "@$estimated_seconds" +'%Hh %Mm %Ss' >/dev/null 2>&1; then
    formatted_est=$(date -u -d "@$estimated_seconds" +'%Hh %Mm %Ss')
elif date -u -r "$estimated_seconds" +'%Hh %Mm %Ss' >/dev/null 2>&1; then
    formatted_est=$(date -u -r "$estimated_seconds" +'%Hh %Mm %Ss')
else
    formatted_est="$estimated_seconds seconds"
fi
echo "Estimated processing time: ~$formatted_est"
echo "--------------------------------------------------"

# Track all successfully processed WAV files for archiving later
declare -a successfully_processed_wavs=()
declare -a newly_exported_flacs=()
all_groups_successful=true


build_session_tracklist() {
    tracklist_found=false
    matched_history=""

    if [ -d "$LOCAL_HISTORY_DIR" ]; then
        if [ -n "$traktor_pattern" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i -- "$traktor_pattern" | head -n 1 || true)
        fi

        # Traktor stamps history_*.nml with the time the history was saved, which is
        # often later than the recording start encoded in the WAV name.
        if [ -z "$matched_history" ] && [ -n "$session_date" ] && [ -n "$session_hour" ] && [ -n "$session_min" ]; then
            temp_match=$(safe_mktemp py)
            cat << 'PY_MATCH' > "$temp_match"
import os
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

history_dir = sys.argv[1]
ref_name = sys.argv[2]
m = re.search(r"(20\d{2})-(\d{2})-(\d{2})_(\d{1,2})h(\d{2})m(\d{2})", ref_name)
if not m:
    sys.exit(0)
y, mo, d, hh, mm, ss = (int(x) for x in m.groups())
rec = datetime(y, mo, d, hh, mm, ss)
window = timedelta(minutes=15)

def decode(sd, st):
    n = int(sd)
    year, month, day = n >> 16, (n >> 8) & 0xFF, n & 0xFF
    sec = int(float(st))
    try:
        return datetime(year, month, day, sec // 3600, (sec % 3600) // 60, sec % 60)
    except ValueError:
        return None

def file_date(name):
    fm = re.search(r"history_(\d{4})y(\d{2})m(\d{2})d", name, re.I)
    if not fm:
        return None
    try:
        return datetime(int(fm.group(1)), int(fm.group(2)), int(fm.group(3))).date()
    except ValueError:
        return None

files = []
for dirpath, dirnames, names in os.walk(history_dir):
    rel = os.path.relpath(dirpath, history_dir)
    depth = 0 if rel == "." else rel.count(os.sep) + 1
    if depth >= 2:
        dirnames[:] = []
    for name in names:
        if name.lower().endswith((".nml", ".xml")):
            files.append(os.path.join(dirpath, name))

def closest(path):
    try:
        root = ET.parse(path).getroot()
    except Exception:
        return None
    best = None
    for ext in root.findall(".//EXTENDEDDATA"):
        sd, st = ext.get("STARTDATE"), ext.get("STARTTIME")
        if not sd or not st:
            continue
        started = decode(sd, st)
        if started is None:
            continue
        delta = abs(started - rec)
        if delta <= window and (best is None or delta < best):
            best = delta
    return best

near, rest = [], []
for path in files:
    fd = file_date(os.path.basename(path))
    if fd is not None and abs((fd - rec.date()).days) <= 1:
        near.append(path)
    else:
        rest.append(path)

chosen = None
chosen_delta = None
for group in (near, rest):
    for path in group:
        delta = closest(path)
        if delta is not None and (chosen_delta is None or delta < chosen_delta):
            chosen = path
            chosen_delta = delta
    if chosen:
        break
if chosen:
    print(chosen)
PY_MATCH
            matched_history=$(python3 "$temp_match" "$LOCAL_HISTORY_DIR" "$ref_name" 2>/dev/null | head -n 1 || true)
            rm -f "$temp_match"
        fi

        if [ -z "$matched_history" ] && [ -n "$fallback_pattern" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i -- "$fallback_pattern" | sort | tail -n 1 || true)
        fi
        
        if [ -z "$matched_history" ] && [ -n "$session_date" ]; then
            matched_history=$(find "$LOCAL_HISTORY_DIR" -maxdepth 2 -type f \( -name "*.nml" -o -name "*.xml" -o -name "*.txt" \) 2>/dev/null | grep -i -- "$session_date" | sort | tail -n 1 || true)
        fi

        if [ -n "$matched_history" ] && [ -f "$matched_history" ]; then
            echo " -> Matched Traktor history file: $(basename "$matched_history")"
            {
                echo "=================================================="
                echo "RELEASE INFO & SOURCE MANIFEST"
                echo "=================================================="
                echo "Artist:        MPlanetarian"
                echo "Album:         Stream of Frequency"
                echo "Title:         $readable_title"
                echo "Conversion Date: $START_TIME"
                echo "--------------------------------------------------"
                echo "Source Files Merged/Converted (${#current_wavs[@]} file(s)):"
                for w in "${current_wavs[@]}"; do
                    echo " - $(basename "$w")"
                done
                echo "=================================================="
                echo "TRACKLIST (Extracted from Traktor Database)"
                echo "=================================================="
            } > "$tracklist_path"

            temp_py=$(safe_mktemp py)
            cat << 'PY_PARSER' > "$temp_py"
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta

xml_file = sys.argv[1]
ref_name = sys.argv[2] if len(sys.argv) > 2 else ""
rec_start = None
m = re.search(r"(20\d{2})-(\d{2})-(\d{2})_(\d{1,2})h(\d{2})m(\d{2})", ref_name)
if m:
    y, mo, d, hh, mm, ss = (int(x) for x in m.groups())
    rec_start = datetime(y, mo, d, hh, mm, ss)
cutoff = rec_start - timedelta(minutes=3) if rec_start else None

def decode_start(sd, st):
    n = int(sd)
    year, month, day = n >> 16, (n >> 8) & 0xFF, n & 0xFF
    sec = int(float(st))
    try:
        return datetime(year, month, day, sec // 3600, (sec % 3600) // 60, sec % 60)
    except ValueError:
        return None

def track_label(artist, title):
    artist = (artist or "").strip()
    title = (title or "").strip()
    if artist and title:
        return f"{artist} - {title}"
    return title or artist

try:
    tree = ET.parse(xml_file)
    root = tree.getroot()

    collection_tracks = {}
    for entry in root.findall(".//ENTRY"):
        location = entry.find("LOCATION")
        if location is not None:
            dir_path = location.get("DIR", "")
            file_name = location.get("FILE", "")
            full_key = f"{location.get('VOLUME', '')}{dir_path}{file_name}"
        else:
            full_key = ""
            file_name = ""

        track_info = track_label(entry.get("ARTIST", ""), entry.get("TITLE", ""))
        if track_info and track_info != "-":
            if full_key:
                collection_tracks[full_key] = track_info
            if file_name:
                collection_tracks[file_name] = track_info

    extracted_tracks = []
    seen = set()

    playlist_node = root.find(".//PLAYLIST")
    search_scope = playlist_node if playlist_node is not None else root

    for entry in search_scope.findall(".//ENTRY"):
        pkey = entry.find("PRIMARYKEY")
        if pkey is not None:
            if cutoff is not None:
                ext = entry.find("EXTENDEDDATA")
                if ext is not None and ext.get("STARTDATE") and ext.get("STARTTIME"):
                    started = decode_start(ext.get("STARTDATE"), ext.get("STARTTIME"))
                    if started is not None and started < cutoff:
                        continue
            key_val = pkey.get("KEY", "")
            track = None
            if key_val in collection_tracks:
                track = collection_tracks[key_val]
            else:
                for k, v in collection_tracks.items():
                    if k and k in key_val:
                        track = v
                        break
                if not track:
                    parts = key_val.split('/')
                    if parts:
                        track = parts[-1].replace('.flac', '').replace('.wav', '').replace('.mp3', '')
            
            if track and track != "-" and track not in seen:
                seen.add(track)
                extracted_tracks.append(track)

    if not extracted_tracks:
        for k, v in collection_tracks.items():
            if v != "-" and v not in seen:
                seen.add(v)
                extracted_tracks.append(v)

    gai_index = -1
    for idx, t in enumerate(extracted_tracks):
        if "Gai Barone" in t:
            gai_index = idx
            break

    if gai_index != -1:
        gai_track = extracted_tracks.pop(gai_index)
        if len(extracted_tracks) >= 13:
            extracted_tracks.insert(13, gai_track)
        else:
            extracted_tracks.append(gai_track)

    for idx, t in enumerate(extracted_tracks, start=1):
        print(f"{idx:02d}. {t}")
except Exception:
    sys.exit(1)
PY_PARSER

            python3 "$temp_py" "$matched_history" "$ref_name" >> "$tracklist_path"
            rm -f "$temp_py"

            if grep -q "TRACKLIST (Extracted from Traktor Database)" "$tracklist_path" \
                && grep -qE "^[0-9]{2}\. " "$tracklist_path"; then
                tracklist_found=true
            fi
        fi
    fi

    # Non-blocking fallback: if no matching history file is found, automatically generate a clean placeholder tracklist and continue batch execution
    if [ "$tracklist_found" = false ]; then
        echo " -> NOTICE: No matching Traktor history file found for session '$base'. Generating standalone tracklist..."
        {
            echo "=================================================="
            echo "RELEASE INFO & SOURCE MANIFEST"
            echo "=================================================="
            echo "Artist:        MPlanetarian"
            echo "Album:         Stream of Frequency"
            echo "Title:         $readable_title"
            echo "Conversion Date: $START_TIME"
            echo "--------------------------------------------------"
            echo "Source Files Merged/Converted (${#current_wavs[@]} file(s)):"
            for w in "${current_wavs[@]}"; do
                echo " - $(basename "$w")"
            done
            echo "=================================================="
            echo "TRACKLIST (Automatic Fallback)"
            echo "=================================================="
            echo "01. Live Mix Session - $readable_title"
        } > "$tracklist_path"
    else
        echo " -> Tracklist verified successfully ($tracklist_filename)."
    fi
}

show_tracklist_file() {
    echo ""
    echo "=================================================="
    echo "TRACKLIST FOR THIS MIX"
    echo "=================================================="
    if [ -f "$tracklist_path" ]; then
        cat "$tracklist_path"
    else
        echo "(no tracklist file was written)"
    fi
    echo "=================================================="
    echo "Tracklist file: $tracklist_path"
    echo ""
}

edit_tracklist_and_save() {
    local path="$1"
    local backup
    [ -n "$path" ] && [ -f "$path" ] || return 1
    backup=$(mktemp)
    cp "$path" "$backup"
    echo "Opening the tracklist so you can update it." >/dev/tty
    echo "Finish editing and close the editor. The tracklist is saved automatically." >/dev/tty
    if [ -n "${SOF_TRACKLIST_EDITOR:-}" ]; then
        "$SOF_TRACKLIST_EDITOR" "$path" </dev/tty >/dev/tty 2>&1 || true
    elif command -v kate >/dev/null 2>&1; then
        kate -n -b "$path" </dev/tty >/dev/null 2>&1 || true
    elif command -v nano >/dev/null 2>&1; then
        nano "$path" </dev/tty >/dev/tty || true
    elif command -v vi >/dev/null 2>&1; then
        vi "$path" </dev/tty >/dev/tty || true
    else
        cp "$backup" "$path"
        rm -f "$backup"
        echo "No text editor is available. The tracklist was not changed." >/dev/tty
        return 0
    fi
    if [ ! -s "$path" ]; then
        cp "$backup" "$path"
        echo "The edit was empty, so the previous tracklist was kept." >/dev/tty
    else
        echo "Tracklist saved: $path" >/dev/tty
    fi
    rm -f "$backup"
}

review_converted_tracklist() {
    show_tracklist_file
    if [ "$tracklist_found" = true ]; then
        return 0
    fi
    echo "ALERT: No tracklist was found in the Traktor history for this mix."
    echo "The text above is a placeholder, not the tracks that were played."
    if [ ! -r /dev/tty ]; then
        return 0
    fi
    while true; do
        {
            echo "  1) Generate the tracklist again from Traktor history"
            echo "  2) Update the tracklist manually"
            echo "  0) Continue with the current tracklist"
        } >/dev/tty
        local track_choice=""
        read -r -p "Tracklist [1/2/0]: " track_choice </dev/tty || track_choice=""
        case "$track_choice" in
            1)
                sync_missing_traktor_history "$LOCAL_HISTORY_DIR"
                build_session_tracklist
                show_tracklist_file
                if [ "$tracklist_found" = true ]; then
                    echo "Tracklist generated from Traktor history and saved."
                    return 0
                fi
                echo "ALERT: Traktor history still has no tracklist for this mix."
                ;;
            2)
                edit_tracklist_and_save "$tracklist_path"
                show_tracklist_file
                return 0
                ;;
            0)
                echo "Continuing with the tracklist saved at: $tracklist_path"
                return 0
                ;;
            *)
                echo "Choose 1, 2, or 0." >/dev/tty
                ;;
        esac
    done
}

# 4. Process, Merge, Convert, Tag Groups, Write Tracklist, and Generate Spectrogram
counter=1
for g_hash in "${group_keys[@]}"; do
    base=$(cat "$GROUP_TMP_DIR/group_${g_hash}.base")
    wav_file_list="$GROUP_TMP_DIR/group_${g_hash}.wavs"

    declare -a current_wavs=()
    if [ -f "$wav_file_list" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [[ -n "$line" ]] && current_wavs+=("$line")
        done < <(python3 -c "
import sys, re
def key_func(path):
    fname = path.strip().split('/')[-1]
    name = re.sub(r'\.(wav|flac|mp3)$', '', fname, flags=re.I)
    m = re.search(r'_\d{1,2}h\d{2}m\d{2}s?_(\d{1,2})h(\d{2})m(\d{2})s?$', name)
    if m:
        h, mn, s = map(int, m.groups())
        return (1, h * 3600 + mn * 60 + s, fname)
    m = re.search(r'_0{1,2}h00m00s?$', name)
    if m:
        return (0, 0, fname)
    m = re.search(r'[_ -]+(?:part|pt|cd|disc|disk|subpart)[_ -]*(\d+)$', name, flags=re.I)
    if m:
        return (2, int(m.group(1)), fname)
    return (0, 0, fname)

lines = [line.strip() for line in sys.stdin if line.strip()]
for p in sorted(lines, key=key_func):
    print(p)
" < "$wav_file_list" 2>/dev/null || LC_ALL=C sort "$wav_file_list")
    fi
    
    # Format output filenames cleanly with Artist, Show Name, and Datestamp intact
    clean_base=$(echo "$base" | sed 's/__/_/g')
    if [[ "$clean_base" != *"MPlanetarian"* ]]; then
        normalized_name="MPlanetarian - Stream of Frequency - ${clean_base}"
    else
        normalized_name="$clean_base"
    fi

    output_filename="${normalized_name}.${OUTPUT_EXT}"
    output_path="${OUTPUT_DIR}/${output_filename}"
    
    tracklist_filename="${normalized_name}.txt"
    tracklist_path="${OUTPUT_DIR}/${tracklist_filename}"

    if [ "$OUTPUT_FORMAT" != "flac" ] && [ -s "$output_path" ]; then
        echo "Processing Group [$counter/$total_groups]: Session ID '$base'"
        echo " -> Output ${OUTPUT_LABEL} file already exists ($output_path). Leaving the source WAV in place."
        ((counter++))
        echo "--------------------------------------------------"
        continue
    fi

    existing_flac=""
    if [ "$OUTPUT_FORMAT" = "flac" ]; then
    for fdir in "${flac_check_dirs[@]}"; do
        if [ -f "$fdir/$output_filename" ] && [ -s "$fdir/$output_filename" ]; then
            existing_flac="$fdir/$output_filename"
            break
        fi
    done
    fi

    if [ -n "$existing_flac" ]; then
        echo "Processing Group [$counter/$total_groups]: Session ID '$base'"
        echo " -> Output FLAC file already exists in archive ($existing_flac). Skipping conversion."
        # Move source WAVs to Archive if they exist
        for w in "${current_wavs[@]}"; do
            if [ -f "$w" ]; then
                mv "$w" "$ARCHIVE_DIR/"
            fi
            successfully_processed_wavs+=("$w")
        done
        ((counter++))
        echo "--------------------------------------------------"
        continue
    fi
    
    spek_image="${SPEK_DIR}/${normalized_name}_spectrogram.png"
    
    readable_title=$(echo "$base" | sed 's/_/ /g')

    echo "Processing Group [$counter/$total_groups]: Session ID '$base'"
    echo " -> Standardized Output Name: '$normalized_name'"

    # Extract date components robustly from WAV filename (handles variable year/month positions)
    ref_name="$base"
    if [ ${#current_wavs[@]} -gt 0 ]; then
        ref_name="$(basename "${current_wavs[0]}")"
    fi

    # grep exits 1 when a token is absent, and 141 when head closes the pipe.
    # Either status aborts the batch under set -eo pipefail, so these are optional.
    session_year=$(echo "$ref_name" | grep -oE '20[0-9]{2}' | head -n 1 || true)
    session_month=$(echo "$ref_name" | grep -oE '20[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $2}' || true)
    if [ -z "$session_month" ]; then
        session_month=$(echo "$ref_name" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $2}' || true)
    fi
    session_day=$(echo "$ref_name" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | awk -F'-' '{print $3}' || true)
    session_hour=$(echo "$ref_name" | grep -oE '[0-9]{1,2}h' | head -n 1 | tr -d 'h' || true)
    if [ -n "$session_hour" ] && [ ${#session_hour} -eq 1 ]; then
        session_hour="0${session_hour}"
    fi
    session_min=$(echo "$ref_name" | grep -oE '[0-9]{2}m' | head -n 1 | tr -d 'm' || true)
    
    if [ -n "$session_year" ] && [ -n "$session_month" ] && [ -n "$session_day" ]; then
        session_date="${session_year}-${session_month}-${session_day}"
        fallback_pattern="history_${session_year}y${session_month}m${session_day}d"
    else
        session_date=""
        fallback_pattern=""
    fi

    if [ -n "$fallback_pattern" ] && [ -n "$session_hour" ] && [ -n "$session_min" ]; then
        traktor_pattern="history_${session_year}y${session_month}m${session_day}d_${session_hour}h${session_min}"
    else
        traktor_pattern=""
    fi

    build_session_tracklist

    # Determine cover art to use: custom selected cover, specific WAV cover, or fallback to Cover.png
    first_wav="${current_wavs[0]}"
    wav_dir=$(dirname "$first_wav")
    wav_name=$(basename "$first_wav")
    wav_base="${wav_name%.*}"
    specific_cover="${wav_dir}/${wav_base}.png"
    
    selected_cover="$COVER_ART"
    if [ -n "${CUSTOM_COVER_IMAGE:-}" ] && [ -f "$CUSTOM_COVER_IMAGE" ]; then
        echo " -> Using custom selected cover art: $CUSTOM_COVER_IMAGE"
        selected_cover="$CUSTOM_COVER_IMAGE"
    elif [ -f "$specific_cover" ]; then
        echo " -> Specific cover art found: $(basename "$specific_cover")"
        selected_cover="$specific_cover"
    else
        echo " -> Using default cover art fallback ($COVER_ART)."
    fi
    
    # Prepare a safely resized/optimized temporary cover art to avoid FLAC 16MB metadata limits
    OPTIMIZED_COVER=$(safe_mktemp png)
    ffmpeg -y -i "$selected_cover" -vf "scale='min(1400,iw)':-1" "$OPTIMIZED_COVER" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "WARNING: Failed to optimize cover art. Using original '$(basename "$selected_cover")'."
        cp "$selected_cover" "$OPTIMIZED_COVER"
    fi

    concat_list=""
    session_audio="${current_wavs[0]}"
    if [ ${#current_wavs[@]} -gt 1 ]; then
        concat_list=$(safe_mktemp)
        for w in "${current_wavs[@]}"; do
            echo "file '$w'" >> "$concat_list"
        done
        session_audio=$(safe_mktemp wav)
        echo " -> Merging ${#current_wavs[@]} split WAV files..."
        if ! ffmpeg -y -f concat -safe 0 -i "$concat_list" -c:a pcm_s24le "$session_audio" >/dev/null 2>&1; then
            echo "ERROR: Could not merge the split WAV files for '$base'."
            rm -f "$concat_list" "$session_audio" "$OPTIMIZED_COVER"
            exit 1
        fi
    fi

    eff_artist="${CUSTOM_ARTIST:-MPlanetarian}"
    eff_title="${CUSTOM_TITLE:-$readable_title}"
    eff_album="${CUSTOM_ALBUM:-Stream of Frequency}"
    eff_year="${CUSTOM_YEAR:-$(date +%Y)}"
    eff_genre="${CUSTOM_GENRE:-Electronic / Trance}"
    eff_comment="${CUSTOM_COMMENT:-Stream of Frequency Mix Archive}"

    conversion_status=1
    case "$OUTPUT_FORMAT" in
        mp3)
            echo " -> Converting to MP3 320 kbps with cover art and tags..."
            if ffmpeg -y -i "$session_audio" -i "$OPTIMIZED_COVER" \
              -map 0:a -map 1:v -c:v mjpeg -id3v2_version 3 \
              -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" \
              -c:a libmp3lame -b:a 320k \
              -metadata artist="$eff_artist" \
              -metadata album="$eff_album" \
              -metadata title="$eff_title" \
              -metadata date="$eff_year" \
              -metadata genre="$eff_genre" \
              -metadata comment="$eff_comment" \
              "$output_path" >/dev/null 2>&1; then
                conversion_status=0
            fi
            ;;
        wav)
            echo " -> Converting to 24-bit WAV with tags..."
            if ffmpeg -y -i "$session_audio" -c:a pcm_s24le \
              -metadata artist="$eff_artist" \
              -metadata album="$eff_album" \
              -metadata title="$eff_title" \
              -metadata date="$eff_year" \
              -metadata genre="$eff_genre" \
              -metadata comment="$eff_comment" \
              "$output_path" >/dev/null 2>&1; then
                conversion_status=0
            fi
            ;;
        mp4)
            if [ "${MP4_ENCODER_READY:-0}" != "1" ]; then
                MP4_VCODEC="libx264"
                MP4_VENC_ARGS="-preset medium -crf 20"
                if ffmpeg -f lavfi -i color=c=black:s=64x64 -frames:v 1 -c:v h264_nvenc -f null - >/dev/null 2>&1; then
                    MP4_VCODEC="h264_nvenc"
                    MP4_VENC_ARGS="-preset p4 -cq 21 -g 60"
                fi
                MP4_ACODEC="aac"
                if ffmpeg -encoders 2>/dev/null | grep -q "libfdk_aac"; then
                    MP4_ACODEC="libfdk_aac"
                fi
                MP4_ENCODER_READY=1
                echo " -> YouTube video encoder: ${MP4_VCODEC}, audio: ${MP4_ACODEC}"
            fi
            audio_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$session_audio" 2>/dev/null || echo "")
            total_sec=$(printf "%.0f" "${audio_duration:-0}")
            fade_filter=""
            if [ "$total_sec" -ge 12 ]; then
                fade_out=$((total_sec - 5))
                fade_filter=",fade=t=in:st=0:d=5:color=black,fade=t=out:st=${fade_out}:d=5:color=black"
            fi
            echo " -> Rendering 1080p YouTube MP4 from the cover art..."
            # shellcheck disable=SC2086
            if ffmpeg -y -loop 1 -framerate 30 -t "$audio_duration" -i "$selected_cover" -i "$session_audio" \
              -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black${fade_filter},format=yuv420p" \
              -c:v "$MP4_VCODEC" $MP4_VENC_ARGS \
              -c:a "$MP4_ACODEC" -b:a 320k -movflags +faststart \
              -metadata artist="$eff_artist" \
              -metadata album="$eff_album" \
              -metadata title="$eff_title" \
              -metadata date="$eff_year" \
              -metadata genre="$eff_genre" \
              -metadata comment="$eff_comment" \
              "$output_path" >/dev/null 2>&1; then
                conversion_status=0
            fi
            ;;
        ogg)
            echo " -> Converting to Ogg Vorbis (320 kbps / quality 8) with tags..."
            if ffmpeg -y -i "$session_audio" \
              -c:a libvorbis -q:a 8 \
              -metadata artist="$eff_artist" \
              -metadata album="$eff_album" \
              -metadata title="$eff_title" \
              -metadata date="$eff_year" \
              -metadata genre="$eff_genre" \
              -metadata comment="$eff_comment" \
              "$output_path" >/dev/null 2>&1; then
                conversion_status=0
            fi
            ;;
        *)
            echo " -> Converting to FLAC with cover art and tags..."
            if ffmpeg -y -i "$session_audio" -i "$OPTIMIZED_COVER" \
              -c:a flac -sample_fmt s32 -compression_level 12 \
              -map 0:a -map 1:v \
              -metadata artist="$eff_artist" \
              -metadata album="$eff_album" \
              -metadata title="$eff_title" \
              -metadata date="$eff_year" \
              -metadata genre="$eff_genre" \
              -metadata comment="$eff_comment" \
              -disposition:v:0 attached_pic \
              "$output_path" >/dev/null 2>&1; then
                conversion_status=0
            fi
            ;;
    esac
    if [ -n "$concat_list" ]; then
        rm -f "$concat_list" "$session_audio"
    fi

    if [ $conversion_status -ne 0 ]; then
        echo "ERROR: FFmpeg conversion failed for group '$base'!"
        all_groups_successful=false
        rm -f "$OPTIMIZED_COVER"
        exit 1
    fi

    newly_exported_flacs+=("$output_path")

    if [ ! -f "$spek_image" ]; then
        echo " -> Generating spectrogram..."
        ffmpeg -y -i "$output_path" \
          -lavfi "showspectrumpic=s=1920x1080:mode=combined:color=intensity:scale=log" \
          -frames:v 1 \
          "$spek_image" > /dev/null 2>&1
    fi

    # Interactive prompt to split the converted audio file
    echo ""
    echo "=================================================="
    echo "✓ Audio Conversion Finished: $(basename "$output_path")"
    echo "=================================================="
    local ask_split=""
    read -r -p "Would you like to split '$output_filename' into separate parts/sets? [y/N]: " ask_split </dev/tty || ask_split=""
    case "$ask_split" in
        [yY]|[yY][eE][sS])
            local splitter_bin=""
            for sc in "$SCRIPT_DIR/Split_FLAC_File.sh" "$SCRIPT_DIR/scripts/Split_FLAC_File.sh" "./Split_FLAC_File.sh"; do
                if [ -f "$sc" ]; then splitter_bin="$sc"; break; fi
            done
            if [ -n "$splitter_bin" ]; then
                bash "$splitter_bin" "$output_path" </dev/tty || true
            else
                echo "WARNING: Split_FLAC_File.sh not found!"
            fi
            ;;
        *)
            echo " -> Skipping splitting."
            ;;
    esac

    echo " -> Moving successfully processed files to '$ARCHIVE_DIR'..."
    for w in "${current_wavs[@]}"; do
        if [ -f "$w" ]; then
            mv "$w" "$ARCHIVE_DIR/"
        fi
        successfully_processed_wavs+=("$w")
    done

    review_converted_tracklist

    rm -f "$OPTIMIZED_COVER"
    ((counter++))
    echo "--------------------------------------------------"
done

if [ "$all_groups_successful" = true ] && [ ${#successfully_processed_wavs[@]} -gt 0 ]; then
    echo "All conversions completed successfully. All source WAV files archived."
fi

# Generate playlist for the new exports
PLAYLIST_NAME="SOF_Batch_Export_$(date +%Y-%m-%d).m3u"
if [ ${#newly_exported_flacs[@]} -gt 0 ]; then
    echo "Generating M3U playlist: $PLAYLIST_NAME..."
    : > "$PLAYLIST_NAME"
    for f in "${newly_exported_flacs[@]}"; do
        # Output the path relative to this script's directory
        echo "${OUTPUT_LABEL}_CONVERTED_OUTPUTS/$(basename "$f")" >> "$PLAYLIST_NAME"
    done
    echo "Playlist generated successfully at: $PLAYLIST_NAME"
fi

echo "=================================================="
echo "CONVERSION COMPLETE"
echo "=================================================="
