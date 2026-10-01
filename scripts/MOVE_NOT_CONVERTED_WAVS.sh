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

ROOT_DIR="${PWD}"

# Discover all FLAC directories across archives
flac_scan_dirs=()
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" ]; then
    flac_scan_dirs+=("$(cd "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" && pwd)")
elif [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR" ]; then
    flac_scan_dirs+=("$(cd "$MIX_ARCHIVE_DIR" && pwd)")
elif [ -d "${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}" ]; then
    flac_scan_dirs+=("$(cd "${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}" && pwd)")
fi

if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
    IFS=':;,' read -ra EXTRA_DIRS <<< "$EXTRA_MIX_ARCHIVE_DIRS"
    for ed in "${EXTRA_DIRS[@]}"; do
        ed="$(echo "$ed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "$ed" ] && continue
        if [ -d "$ed/FLAC_CONVERTED_OUTPUTS" ]; then
            cand="$(cd "$ed/FLAC_CONVERTED_OUTPUTS" && pwd)"
            [[ ! " ${flac_scan_dirs[*]} " =~ " ${cand} " ]] && flac_scan_dirs+=("$cand")
        elif [ -d "$ed" ]; then
            cand="$(cd "$ed" && pwd)"
            [[ ! " ${flac_scan_dirs[*]} " =~ " ${cand} " ]] && flac_scan_dirs+=("$cand")
        fi
    done
fi

# Discover all WAV archive directories
wav_scan_dirs=()
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES" ]; then
    wav_scan_dirs+=("$(cd "$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES" && pwd)")
elif [ -d "${ARCHIVE_DIR:-CONVERTED_WAV_FILES}" ]; then
    wav_scan_dirs+=("$(cd "${ARCHIVE_DIR:-CONVERTED_WAV_FILES}" && pwd)")
fi

if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
    IFS=':;,' read -ra EXTRA_DIRS <<< "$EXTRA_MIX_ARCHIVE_DIRS"
    for ed in "${EXTRA_DIRS[@]}"; do
        ed="$(echo "$ed" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "$ed" ] && continue
        if [ -d "$ed/CONVERTED_WAV_FILES" ]; then
            cand="$(cd "$ed/CONVERTED_WAV_FILES" && pwd)"
            [[ ! " ${wav_scan_dirs[*]} " =~ " ${cand} " ]] && wav_scan_dirs+=("$cand")
        fi
    done
fi

echo "=================================================="
echo "Checking and retrieving unconverted WAV files..."
echo "=================================================="
echo "WAV Archive Locations:"
for wd in "${wav_scan_dirs[@]}"; do
    echo "  • $wd"
done
echo "FLAC Destination Locations (Checked for existing mixes):"
for fd in "${flac_scan_dirs[@]}"; do
    echo "  • $fd"
done
echo "=================================================="

if [ ${#wav_scan_dirs[@]} -eq 0 ]; then
    echo "ERROR: No WAV archive directories found!"
    exit 1
fi

shopt -s nullglob nocaseglob

wav_files=()
for wd in "${wav_scan_dirs[@]}"; do
    if [ -d "$wd" ]; then
        for f in "$wd"/*.wav; do
            [ -f "$f" ] && wav_files+=("$f")
        done
    fi
done

if [ ${#wav_files[@]} -eq 0 ]; then
    echo "No WAV files found in any configured WAV archive."
    exit 0
fi

retrieved_count=0

get_session_base_name() {
    local fname="$1"
    local name="${fname%.[Ww][Aa][Vv]}"
    name="${name%.[Ff][Ll][Aa][Cc]}"
    name="${name%.[Mm][Pp]3}"

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
        local parent_d
        parent_d=$(dirname "$fname" 2>/dev/null || echo ".")
        if [ -f "$parent_d/${cand_prefix}.wav" ] || [ -f "$parent_d/${cand_prefix}.WAV" ] || [ -f "${cand_prefix}.wav" ] || [ -f "${cand_prefix}.WAV" ]; then
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

flac_exists_in_any_archive() {
    local base="$1"
    local clean_base
    clean_base=$(echo "$base" | sed 's/__/_/g')
    for fd in "${flac_scan_dirs[@]}"; do
        if [ -f "$fd/${base}.flac" ] || [ -f "$fd/${clean_base}.flac" ] || [ -f "$fd/MPlanetarian - Stream of Frequency - ${clean_base}.flac" ] || [ -f "$fd/MPlanetarian_-_Stream_of_Frequency_-_${clean_base}.flac" ]; then
            return 0
        fi
    done
    return 1
}

for wav in "${wav_files[@]}"; do
    filename=$(basename "$wav")
    
    # Extract session base name cleanly
    base_name=$(get_session_base_name "$wav")
    base_name=$(basename "$base_name")
    
    if ! flac_exists_in_any_archive "$base_name"; then
        echo " [UNCONVERTED] Moving $filename to staging directory..."
        mv "$wav" "$ROOT_DIR/"
        ((retrieved_count++))
    else
        echo " [CONVERTED]   $filename (FLAC exists in archive)"
    fi
done

echo "=================================================="
if [ "$retrieved_count" -eq 0 ]; then
    echo "Status: All files are converted across all archives. No files moved."
else
    echo "Status: Successfully moved $retrieved_count unconverted WAV file(s) to staging directory."
fi
echo "=================================================="
