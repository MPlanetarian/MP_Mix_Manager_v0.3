#!/usr/bin/env bash
# ==============================================================================
# MP_YouTube_Channel_Downloader.sh
# ------------------------------------------------------------------------------
# Minimal & High-Efficiency YouTube 1080p Channel Downloader (Linux & macOS)
# - Streams and downloads the last 6 months directly (stops at 6-month cutoff)
# - No redundant scans or full-channel history parsing
# - Proxy: 192.168.1.138:3128
# - Target Dir: YOUTUBE_[CHANNELNAME]_DOWNLOAD_[INSERTDATE]
# ==============================================================================
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

PROXY="${YOUTUBE_PROXY:-http://192.168.1.138:3128}"

# JS engine detection (Node or Deno)
JS_ARG=()
if command -v node >/dev/null 2>&1; then
    JS_ARG=(--js-runtimes "node:$(command -v node)")
elif [[ -x "/home/mplanetarian/.local/bin/node" ]]; then
    JS_ARG=(--js-runtimes "node:/home/mplanetarian/.local/bin/node")
elif command -v deno >/dev/null 2>&1; then
    JS_ARG=(--js-runtimes "deno:$(command -v deno)")
fi

echo -e "\033[1;36m=== YouTube 1080p Channel Downloader (Last 6 Months) ===\033[0m"

# 1. Quick Proxy Ping (2-second timeout)
if ! curl -s -x "$PROXY" -I https://www.google.com --connect-timeout 2 >/dev/null; then
    echo -e "\033[1;31m❌ Error: Proxy server $PROXY is unreachable.\033[0m"
    read -rp "Press Enter to exit..."
    exit 1
fi
echo -e "\033[32m✔ Proxy online: $PROXY\033[0m"

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

# 3. Channel Input
INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then
    echo -ne "\033[1;33mEnter YouTube Channel URL or Name: \033[0m"
    read -r INPUT
fi

INPUT=$(echo "$INPUT" | xargs)
if [[ -z "$INPUT" ]]; then
    echo "No channel entered. Exiting."
    exit 0
fi

# Prefer dedicated YouTube directory if running from repo or home
DATA_DIR="/run/media/mplanetarian/DATA/YOUTUBE_VIDEOS"
if [[ -d "$DATA_DIR" ]] && [[ "$PWD" == *"/MP_Mix_Manager"* || "$PWD" == "$HOME" ]]; then
    cd "$DATA_DIR"
fi

# Format URL and directory name
if [[ "$INPUT" =~ ^https?:// ]]; then
    CHANNEL_URL="$INPUT"
    RAW_NAME=$(echo "$INPUT" | sed -E 's|.*/@?([^/?#]+).*|\1|')
else
    CLEAN_HANDLE="${INPUT#@}"
    RAW_NAME="$CLEAN_HANDLE"
    CHANNEL_URL="https://www.youtube.com/@${CLEAN_HANDLE}/videos"
fi

if [[ "$CHANNEL_URL" =~ /@[^/]+$ ]]; then
    CHANNEL_URL="${CHANNEL_URL}/videos"
fi

CHANNEL_NAME=$(echo "$RAW_NAME" | tr -cd '[:alnum:]_-')
CHANNEL_NAME=${CHANNEL_NAME:-Channel}
DATE_STR=$(date +%Y-%m-%d)
TARGET_DIR="YOUTUBE_${CHANNEL_NAME}_DOWNLOAD_${DATE_STR}"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 6 Months Cutoff Calculation (compatible with BSD/macOS and GNU date)
if date -v-6m +%Y%m%d >/dev/null 2>&1; then
    CUTOFF_DATE=$(date -v-6m +%Y%m%d)
    CUTOFF_DISPLAY=$(date -v-6m '+%B %d, %Y')
elif date -d '6 months ago' +%Y%m%d >/dev/null 2>&1; then
    CUTOFF_DATE=$(date -d '6 months ago' +%Y%m%d)
    CUTOFF_DISPLAY=$(date -d '6 months ago' '+%B %d, %Y')
elif command -v gdate >/dev/null 2>&1; then
    CUTOFF_DATE=$(gdate -d '6 months ago' +%Y%m%d)
    CUTOFF_DISPLAY=$(gdate -d '6 months ago' '+%B %d, %Y')
else
    CUTOFF_DATE=$(date +%Y%m%d)
    CUTOFF_DISPLAY="6 months ago"
fi

echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
echo -e "\033[1;32m📅 Cutoff:\033[0m Only videos on/after ${CUTOFF_DISPLAY} ($CUTOFF_DATE)"
echo -e "\033[1;32m🚀 Starting direct stream download in 1080p...\033[0m\n"

# 4. Direct Streamed Download
START_TIME=$(date +%s)

yt-dlp \
    --proxy "$PROXY" \
    "${JS_ARG[@]}" \
    --lazy-playlist \
    --break-match-filters "upload_date >= ${CUTOFF_DATE}" \
    -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best" \
    --merge-output-format mp4 \
    -o "%(upload_date)s - %(title)s [%(id)s].%(ext)s" \
    --progress \
    --console-title \
    --exec 'after_video:bash -c '\''SIZE=$(ls -lh "$1" 2>/dev/null | awk "{print \$5}"); echo -e "\n\033[1;32m✔ Finished: $(basename "$1") | Size: ${SIZE:-Unknown}\033[0m\n"'\'' _ {}' \
    "$CHANNEL_URL" || true

TOTAL_TIME=$(( $(date +%s) - START_TIME ))
MINS=$(( TOTAL_TIME / 60 ))
SECS=$(( TOTAL_TIME % 60 ))

echo -e "\n\033[1;32m═══════════════════════════════════════════════════════\033[0m"
echo -e "\033[1;32m🎉 Batch finished in ${MINS}m ${SECS}s\033[0m"
echo -e "\033[1;34m📁 Saved in:\033[0m $(pwd)"
echo -e "\033[1;32m═══════════════════════════════════════════════════════\033[0m"

read -rp "Press Enter to exit..."
