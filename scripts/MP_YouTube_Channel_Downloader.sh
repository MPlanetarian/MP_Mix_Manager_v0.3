#!/usr/bin/env bash
# ==============================================================================
# MP_YouTube_Channel_Downloader.sh
# ------------------------------------------------------------------------------
# High-Efficiency YouTube 1080p Downloader (Linux & macOS)
# - Single YouTube Video or Short (from URL / Video ID)
# - Channel Standard Videos: Last 1 Month, 3 Months, 6 Months, or Entire Channel
# - Channel YouTube Shorts: Last 1 Month, 3 Months, 6 Months, or Entire Channel
# - Prompts user whether to use a proxy (with IP & Port) or direct connection
# - Auto-categorized target dirs: YOUTUBE_SINGLE_VIDEOS, YOUTUBE_SINGLE_SHORTS,
#   YOUTUBE_[CHANNEL]_DOWNLOAD_[DATE], YOUTUBE_[CHANNEL]_SHORTS_DOWNLOAD_[DATE]
# ==============================================================================
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

# JS engine detection (Node or Deno)
JS_ARG=()
if command -v node >/dev/null 2>&1; then
    JS_ARG=(--js-runtimes "node:$(command -v node)")
elif [[ -x "$HOME/.local/bin/node" ]]; then
    JS_ARG=(--js-runtimes "node:$HOME/.local/bin/node")
elif command -v deno >/dev/null 2>&1; then
    JS_ARG=(--js-runtimes "deno:$(command -v deno)")
fi

echo -e "\033[1;36m========================================================================\033[0m"
echo -e "\033[1;36m         YouTube 1080p Downloader (Videos & Shorts Suite)               \033[0m"
echo -e "\033[1;36m========================================================================\033[0m\n"

# 1. Ask user about Proxy usage
PROXY_ARG=()
read -rp "Do you want to use a Proxy server for downloading? [y/N]: " USE_PROXY
USE_PROXY=$(echo "${USE_PROXY:-n}" | tr '[:upper:]' '[:lower:]' | xargs)

if [[ "$USE_PROXY" == "y" || "$USE_PROXY" == "yes" ]]; then
    read -rp "Enter Proxy IP [default: 192.168.1.138]: " PROXY_IP
    PROXY_IP=$(echo "${PROXY_IP:-192.168.1.138}" | xargs)
    # Strip protocol prefix if entered
    PROXY_IP=$(echo "$PROXY_IP" | sed -E 's|^https?://||')

    read -rp "Enter Proxy Port [default: 3128]: " PROXY_PORT
    PROXY_PORT=$(echo "${PROXY_PORT:-3128}" | xargs)

    PROXY_URL="http://${PROXY_IP}:${PROXY_PORT}"
    echo -e "Testing proxy connectivity to ${PROXY_URL}..."

    if ! curl -s -x "$PROXY_URL" -I https://www.google.com --connect-timeout 2 >/dev/null; then
        echo -e "\033[1;31m❌ Warning: Proxy server $PROXY_URL is unreachable.\033[0m"
        read -rp "Proceed without proxy (direct connection)? [Y/n]: " FALLBACK_CHOICE
        FALLBACK_CHOICE=$(echo "${FALLBACK_CHOICE:-y}" | tr '[:upper:]' '[:lower:]' | xargs)
        if [[ "$FALLBACK_CHOICE" != "y" && "$FALLBACK_CHOICE" != "yes" ]]; then
            echo "Exiting."
            exit 1
        fi
        echo -e "\033[33m⚡ Proceeding with direct connection (no proxy).\033[0m\n"
    else
        echo -e "\033[32m✔ Proxy online: $PROXY_URL\033[0m\n"
        PROXY_ARG=(--proxy "$PROXY_URL")
    fi
else
    echo -e "\033[32m✔ Direct connection selected (no proxy).\033[0m\n"
fi

# 2. Live Wi-Fi / Network Stats
SSID="N/A"
BSSID="N/A"
SIGNAL="N/A"
FREQ="N/A"
RXRATE="N/A"
TXRATE="N/A"
IP_ADDR="N/A"

if [[ "$(uname)" == "Darwin" ]]; then
    WIFI_DEV=$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: Wi-Fi/{getline; print $2}')
    WIFI_DEV=${WIFI_DEV:-en1}
    AIRPORT="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
    if [[ -x "$AIRPORT" ]]; then
        AIR_INFO=$("$AIRPORT" -I 2>/dev/null || true)
        SSID=$(echo "$AIR_INFO" | awk -F': ' '/ SSID/ {print $2}' | xargs || true)
        BSSID=$(echo "$AIR_INFO" | awk -F': ' '/ BSSID/ {print $2}' | xargs || true)
        SIGNAL=$(echo "$AIR_INFO" | awk -F': ' '/agrCtlRSSI/ {print $2 " dBm"}' | xargs || true)
        FREQ=$(echo "$AIR_INFO" | awk -F': ' '/channel/ {print $2}' | xargs || true)
        TXRATE=$(echo "$AIR_INFO" | awk -F': ' '/lastTxRate/ {print $2 " Mbps"}' | xargs || true)
        RXRATE=$(echo "$AIR_INFO" | awk -F': ' '/maxRate/ {print $2 " Mbps"}' | xargs || true)
    else
        SSID=$(networksetup -getairportnetwork "$WIFI_DEV" 2>/dev/null | awk -F': ' '{print $2}' | xargs || true)
    fi
    IP_ADDR=$(ipconfig getifaddr "$WIFI_DEV" 2>/dev/null || ipconfig getifaddr en0 2>/dev/null || true)
else
    IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^wl/ {print $2; exit}' || true)
    IFACE=${IFACE:-wlp2s0}
    if command -v iw >/dev/null 2>&1; then
        LINK_INFO=$(iw dev "$IFACE" link 2>/dev/null || true)
        SSID=$(echo "$LINK_INFO" | awk -F': ' '/SSID:/ {print $2}' || true)
        BSSID=$(echo "$LINK_INFO" | awk '/Connected to/ {print $3}' || true)
        FREQ=$(echo "$LINK_INFO" | awk -F': ' '/freq:/ {print $2}' || true)
        SIGNAL=$(echo "$LINK_INFO" | awk -F': ' '/signal:/ {print $2}' || true)
        RXRATE=$(echo "$LINK_INFO" | awk -F': ' '/rx bitrate:/ {print $2}' || true)
        TXRATE=$(echo "$LINK_INFO" | awk -F': ' '/tx bitrate:/ {print $2}' || true)
    fi
    IP_ADDR=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet / {print $2}' || true)
fi

echo -e "\033[1;34m📶 Network:\033[0m SSID: ${SSID:-N/A} (${BSSID:-N/A}) | Signal: ${SIGNAL:-N/A} | Freq: ${FREQ:-N/A} MHz"
echo -e "   \033[2mSpeed: RX ${RXRATE:-N/A} / TX ${TXRATE:-N/A} | IP: ${IP_ADDR:-N/A}\033[0m\n"

# 3. Download Mode & Target Selection
INPUT="${1:-}"
MODE="${2:-}"

# Auto-detect if input argument looks like a single video or short URL
if [[ -n "$INPUT" && -z "$MODE" ]]; then
    if [[ "$INPUT" =~ (watch\?v=|youtu\.be/|/shorts/) ]]; then
        MODE="1"
    elif [[ "$INPUT" =~ /shorts/?$ ]]; then
        MODE="8" # Default to 6m shorts if a channel /shorts link is passed
    fi
fi

if [[ -z "$MODE" ]]; then
    echo -e "\033[1;33mSelect Download Mode:\033[0m"
    echo -e "  \033[1;36m1)\033[0m Single YouTube Video or Short (from URL / Video ID)"
    echo -e "  \033[1;34m─── [ STANDARD VIDEOS (/videos) ] ─────────────────────────\033[0m"
    echo -e "  \033[1;36m2)\033[0m Channel Videos - Last 1 Month"
    echo -e "  \033[1;36m3)\033[0m Channel Videos - Last 3 Months"
    echo -e "  \033[1;36m4)\033[0m Channel Videos - Last 6 Months \033[2m(Default)\033[0m"
    echo -e "  \033[1;36m5)\033[0m Channel Videos - Entire Channel (All Videos)"
    echo -e "  \033[1;35m─── [ YOUTUBE SHORTS (/shorts) ] ──────────────────────────\033[0m"
    echo -e "  \033[1;36m6)\033[0m Channel Shorts - Last 1 Month"
    echo -e "  \033[1;36m7)\033[0m Channel Shorts - Last 3 Months"
    echo -e "  \033[1;36m8)\033[0m Channel Shorts - Last 6 Months"
    echo -e "  \033[1;36m9)\033[0m Channel Shorts - Entire Channel (All Shorts)"
    echo ""
    read -rp "Enter choice [1-9, default: 4]: " MODE_CHOICE
    MODE_CHOICE=$(echo "${MODE_CHOICE:-4}" | xargs)
    case "$MODE_CHOICE" in
        1|single|video|short|shorts)   MODE="single" ;;
        2|1m|month|v1m)                MODE="1m" ;;
        3|3m|v3m)                      MODE="3m" ;;
        4|6m|v6m)                      MODE="6m" ;;
        5|all|entire|vall)             MODE="all" ;;
        6|s1m|short-1m|shorts-1m)      MODE="shorts-1m" ;;
        7|s3m|short-3m|shorts-3m)      MODE="shorts-3m" ;;
        8|s6m|short-6m|shorts-6m)      MODE="shorts-6m" ;;
        9|sall|short-all|shorts-all)   MODE="shorts-all" ;;
        *)                             MODE="6m" ;;
    esac
else
    case "$MODE" in
        1|single|video|short|shorts)   MODE="single" ;;
        2|1m|month|v1m)                MODE="1m" ;;
        3|3m|v3m)                      MODE="3m" ;;
        4|6m|v6m)                      MODE="6m" ;;
        5|all|entire|vall)             MODE="all" ;;
        6|s1m|short-1m|shorts-1m)      MODE="shorts-1m" ;;
        7|s3m|short-3m|shorts-3m)      MODE="shorts-3m" ;;
        8|s6m|short-6m|shorts-6m)      MODE="shorts-6m" ;;
        9|sall|short-all|shorts-all)   MODE="shorts-all" ;;
        *)                             MODE="6m" ;;
    esac
fi

# Determine if mode is targeting Shorts
IS_SHORTS=0
case "$MODE" in
    shorts-*) IS_SHORTS=1 ;;
esac

# Acquire and format target URL/Input
if [[ "$MODE" == "single" ]]; then
    if [[ -z "$INPUT" ]]; then
        echo -ne "\033[1;33mEnter YouTube Video or Short URL: \033[0m"
        read -r INPUT
    fi
    INPUT=$(echo "$INPUT" | sed -e 's/^["'\'' ]*//' -e 's/["'\'' ]*$//')
    if [[ -z "$INPUT" ]]; then
        echo "No URL entered. Exiting."
        exit 0
    fi
    # Support 11-char video ID input directly
    if [[ "$INPUT" =~ ^[a-zA-Z0-9_-]{11}$ ]]; then
        DOWNLOAD_URL="https://www.youtube.com/watch?v=${INPUT}"
    elif [[ "$INPUT" =~ ^https?:// ]]; then
        DOWNLOAD_URL="$INPUT"
    else
        DOWNLOAD_URL="https://www.youtube.com/watch?v=${INPUT}"
    fi

    if [[ "$DOWNLOAD_URL" =~ /shorts/ ]]; then
        IS_SHORTS=1
    fi
else
    if [[ "$IS_SHORTS" -eq 1 ]]; then
        echo -ne "\033[1;35mEnter YouTube Channel URL, @Handle, or Name for Shorts: \033[0m"
    else
        echo -ne "\033[1;33mEnter YouTube Channel URL, @Handle, or Name: \033[0m"
    fi
    if [[ -z "$INPUT" ]]; then
        read -r INPUT
    fi
    INPUT=$(echo "$INPUT" | sed -e 's/^["'\'' ]*//' -e 's/["'\'' ]*$//')
    if [[ -z "$INPUT" ]]; then
        echo "No channel entered. Exiting."
        exit 0
    fi

    # Extract clean channel name and build standard URL (videos vs shorts tab)
    if [[ "$IS_SHORTS" -eq 1 ]]; then
        if [[ "$INPUT" =~ /@([^/?#]+) ]]; then
            RAW_NAME="${BASH_REMATCH[1]}"
            CHANNEL_URL="https://www.youtube.com/@${RAW_NAME}/shorts"
        elif [[ "$INPUT" =~ /channel/([^/?#]+) ]]; then
            RAW_NAME="${BASH_REMATCH[1]}"
            CHANNEL_URL="${INPUT%/}/shorts"
        elif [[ "$INPUT" =~ /c/([^/?#]+) ]]; then
            RAW_NAME="${BASH_REMATCH[1]}"
            CHANNEL_URL="${INPUT%/}/shorts"
        elif [[ "$INPUT" =~ ^https?:// ]]; then
            RAW_NAME=$(echo "$INPUT" | sed -E "s%^https?://[^/]+/([^/?#]+).*%\1%")
            CHANNEL_URL="${INPUT%/}/shorts"
        else
            CLEAN_HANDLE="${INPUT#@}"
            RAW_NAME="$CLEAN_HANDLE"
            CHANNEL_URL="https://www.youtube.com/@${CLEAN_HANDLE}/shorts"
        fi
        CHANNEL_URL=$(echo "$CHANNEL_URL" | sed -E "s%/(videos|featured|streams)/?$%/%")
        [[ ! "$CHANNEL_URL" =~ /shorts$ ]] && CHANNEL_URL="${CHANNEL_URL%/}/shorts"
    else
        if [[ "$INPUT" =~ /@([^/?#]+) ]]; then
            RAW_NAME="${BASH_REMATCH[1]}"
            CHANNEL_URL="https://www.youtube.com/@${RAW_NAME}/videos"
        elif [[ "$INPUT" =~ /channel/([^/?#]+) ]]; then
            RAW_NAME="${BASH_REMATCH[1]}"
            CHANNEL_URL="${INPUT%/}/videos"
        elif [[ "$INPUT" =~ /c/([^/?#]+) ]]; then
            RAW_NAME="${BASH_REMATCH[1]}"
            CHANNEL_URL="${INPUT%/}/videos"
        elif [[ "$INPUT" =~ ^https?:// ]]; then
            RAW_NAME=$(echo "$INPUT" | sed -E "s%^https?://[^/]+/([^/?#]+).*%\1%")
            CHANNEL_URL="$INPUT"
        else
            CLEAN_HANDLE="${INPUT#@}"
            RAW_NAME="$CLEAN_HANDLE"
            CHANNEL_URL="https://www.youtube.com/@${CLEAN_HANDLE}/videos"
        fi
        CHANNEL_URL=$(echo "$CHANNEL_URL" | sed -E "s%/(shorts|featured|streams)/?$%/%")
        [[ "$CHANNEL_URL" =~ /@[^/]+$ ]] && CHANNEL_URL="${CHANNEL_URL}/videos"
    fi

    CHANNEL_NAME=$(echo "$RAW_NAME" | tr -cd '[:alnum:]_-')
    CHANNEL_NAME=${CHANNEL_NAME:-Channel}
    DOWNLOAD_URL="$CHANNEL_URL"
fi

# 4. Storage Directory Setup
DATA_DIR="/run/media/mplanetarian/DATA/YOUTUBE_VIDEOS"
if [[ -d "$DATA_DIR" ]] && [[ "$PWD" == *"/MP_Mix_Manager"* || "$PWD" == "$HOME" ]]; then
    cd "$DATA_DIR"
fi

DATE_STR=$(date +%Y-%m-%d)
if [[ "$MODE" == "single" ]]; then
    if [[ "$IS_SHORTS" -eq 1 ]]; then
        TARGET_DIR="YOUTUBE_SINGLE_SHORTS"
    else
        TARGET_DIR="YOUTUBE_SINGLE_VIDEOS"
    fi
else
    if [[ "$IS_SHORTS" -eq 1 ]]; then
        TARGET_DIR="YOUTUBE_${CHANNEL_NAME}_SHORTS_DOWNLOAD_${DATE_STR}"
    else
        TARGET_DIR="YOUTUBE_${CHANNEL_NAME}_DOWNLOAD_${DATE_STR}"
    fi
fi

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 5. Date Cutoff Calculation & yt-dlp Configuration
calculate_cutoff() {
    local months="$1"
    if date -v-"${months}"m +%Y%m%d >/dev/null 2>&1; then
        CUTOFF_DATE=$(date -v-"${months}"m +%Y%m%d)
        CUTOFF_DISPLAY=$(date -v-"${months}"m '+%B %d, %Y')
    elif date -d "${months} months ago" +%Y%m%d >/dev/null 2>&1; then
        CUTOFF_DATE=$(date -d "${months} months ago" +%Y%m%d)
        CUTOFF_DISPLAY=$(date -d "${months} months ago" '+%B %d, %Y')
    elif command -v gdate >/dev/null 2>&1; then
        CUTOFF_DATE=$(gdate -d "${months} months ago" +%Y%m%d)
        CUTOFF_DISPLAY=$(gdate -d "${months} months ago" '+%B %d, %Y')
    else
        CUTOFF_DATE=$(date +%Y%m%d)
        CUTOFF_DISPLAY="${months} month(s) ago"
    fi
}

EXTRA_YTDLP_ARGS=()
if [[ "$IS_SHORTS" -eq 1 ]]; then
    # Full 1080p vertical resolution for shorts (1080x1920) without downscaling
    FORMAT_SPEC="bestvideo[height<=1920][width<=1080]+bestaudio/best[height<=1920]/best"
else
    # Standard landscape 1080p resolution (1920x1080)
    FORMAT_SPEC="bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
fi

if [[ "$MODE" == "single" ]]; then
    FORMAT_SPEC="bestvideo[height<=1920][width<=1920]+bestaudio/best[height<=1920]/best"
    EXTRA_YTDLP_ARGS+=(--no-playlist)
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    if [[ "$IS_SHORTS" -eq 1 ]]; then
        echo -e "\033[1;35m🎯 Scope:\033[0m Single YouTube Short"
    else
        echo -e "\033[1;32m🎯 Scope:\033[0m Single YouTube Video"
    fi
    echo -e "\033[1;32m🔗 Target URL:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m🚀 Starting direct download in 1080p...\033[0m\n"
elif [[ "$MODE" == "1m" ]]; then
    calculate_cutoff 1
    EXTRA_YTDLP_ARGS+=(--lazy-playlist --break-match-filters "upload_date >= ${CUTOFF_DATE}")
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;32m📺 Channel Videos:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Cutoff:\033[0m Only videos on/after ${CUTOFF_DISPLAY} ($CUTOFF_DATE - Last 1 Month)"
    echo -e "\033[1;32m🚀 Starting direct stream download in 1080p...\033[0m\n"
elif [[ "$MODE" == "3m" ]]; then
    calculate_cutoff 3
    EXTRA_YTDLP_ARGS+=(--lazy-playlist --break-match-filters "upload_date >= ${CUTOFF_DATE}")
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;32m📺 Channel Videos:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Cutoff:\033[0m Only videos on/after ${CUTOFF_DISPLAY} ($CUTOFF_DATE - Last 3 Months)"
    echo -e "\033[1;32m🚀 Starting direct stream download in 1080p...\033[0m\n"
elif [[ "$MODE" == "6m" ]]; then
    calculate_cutoff 6
    EXTRA_YTDLP_ARGS+=(--lazy-playlist --break-match-filters "upload_date >= ${CUTOFF_DATE}")
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;32m📺 Channel Videos:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Cutoff:\033[0m Only videos on/after ${CUTOFF_DISPLAY} ($CUTOFF_DATE - Last 6 Months)"
    echo -e "\033[1;32m🚀 Starting direct stream download in 1080p...\033[0m\n"
elif [[ "$MODE" == "all" ]]; then
    EXTRA_YTDLP_ARGS+=(--lazy-playlist)
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;32m📺 Channel Videos:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Scope:\033[0m Entire Channel (All Videos - Complete Archive)"
    echo -e "\033[1;32m🚀 Starting direct stream download in 1080p...\033[0m\n"
elif [[ "$MODE" == "shorts-1m" ]]; then
    calculate_cutoff 1
    EXTRA_YTDLP_ARGS+=(--lazy-playlist --break-match-filters "upload_date >= ${CUTOFF_DATE}")
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;35m⚡ Channel Shorts:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Cutoff:\033[0m Only shorts on/after ${CUTOFF_DISPLAY} ($CUTOFF_DATE - Last 1 Month)"
    echo -e "\033[1;35m🚀 Starting direct stream download in 1080p (Vertical HD)...\033[0m\n"
elif [[ "$MODE" == "shorts-3m" ]]; then
    calculate_cutoff 3
    EXTRA_YTDLP_ARGS+=(--lazy-playlist --break-match-filters "upload_date >= ${CUTOFF_DATE}")
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;35m⚡ Channel Shorts:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Cutoff:\033[0m Only shorts on/after ${CUTOFF_DISPLAY} ($CUTOFF_DATE - Last 3 Months)"
    echo -e "\033[1;35m🚀 Starting direct stream download in 1080p (Vertical HD)...\033[0m\n"
elif [[ "$MODE" == "shorts-6m" ]]; then
    calculate_cutoff 6
    EXTRA_YTDLP_ARGS+=(--lazy-playlist --break-match-filters "upload_date >= ${CUTOFF_DATE}")
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;35m⚡ Channel Shorts:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Cutoff:\033[0m Only shorts on/after ${CUTOFF_DISPLAY} ($CUTOFF_DATE - Last 6 Months)"
    echo -e "\033[1;35m🚀 Starting direct stream download in 1080p (Vertical HD)...\033[0m\n"
elif [[ "$MODE" == "shorts-all" ]]; then
    EXTRA_YTDLP_ARGS+=(--lazy-playlist)
    echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
    echo -e "\033[1;35m⚡ Channel Shorts:\033[0m $DOWNLOAD_URL"
    echo -e "\033[1;32m📅 Scope:\033[0m Entire Channel (All Shorts - Complete Archive)"
    echo -e "\033[1;35m🚀 Starting direct stream download in 1080p (Vertical HD)...\033[0m\n"
fi

# 6. Streamed Download
START_TIME=$(date +%s)

yt-dlp \
    ${PROXY_ARG[@]+"${PROXY_ARG[@]}"} \
    "${JS_ARG[@]}" \
    "${EXTRA_YTDLP_ARGS[@]}" \
    -f "$FORMAT_SPEC" \
    --merge-output-format mp4 \
    -o "%(upload_date)s - %(title)s [%(id)s].%(ext)s" \
    --progress \
    --console-title \
    --exec 'after_video:bash -c '\''SIZE=$(ls -lh "$1" 2>/dev/null | awk "{print \$5}"); echo -e "\n\033[1;32m✔ Finished: $(basename "$1") | Size: ${SIZE:-Unknown}\033[0m\n"'\'' _ {}' \
    "$DOWNLOAD_URL" || true

TOTAL_TIME=$(( $(date +%s) - START_TIME ))
MINS=$(( TOTAL_TIME / 60 ))
SECS=$(( TOTAL_TIME % 60 ))

echo -e "\n\033[1;32m═══════════════════════════════════════════════════════\033[0m"
echo -e "\033[1;32m🎉 Download finished in ${MINS}m ${SECS}s\033[0m"
echo -e "\033[1;34m📁 Saved in:\033[0m $(pwd)"
echo -e "\033[1;32m═══════════════════════════════════════════════════════\033[0m\n"

if [ -t 0 ]; then
    read -rp "Press Enter to continue..." || true
fi
