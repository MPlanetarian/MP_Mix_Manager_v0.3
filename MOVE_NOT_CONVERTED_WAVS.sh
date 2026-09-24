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

flac_exists_in_any_archive() {
    local base="$1"
    for fd in "${flac_scan_dirs[@]}"; do
        if [ -f "$fd/${base}.flac" ]; then
            return 0
        fi
    done
    return 1
}

for wav in "${wav_files[@]}"; do
    filename=$(basename "$wav")
    
    # Strip split segment suffixes and extensions to find the core base name
    base_name=$(echo "$filename" | sed -E 's/_[0-9]{2}h[0-9]{2}m[0-9]{2}(\.[Ww][Aa][Vv])?$//' | sed -E 's/\.[Ww][Aa][Vv]$//')
    
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
