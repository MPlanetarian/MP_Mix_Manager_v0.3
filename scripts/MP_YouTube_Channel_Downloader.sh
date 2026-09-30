#!/usr/bin/env bash
# ==============================================================================
# MP_YouTube_Channel_Downloader.sh
# ------------------------------------------------------------------------------
# Minimal & High-Efficiency YouTube 1080p Channel Downloader
# - Streams and downloads the last 6 months directly (stops at 6-month cutoff)
# - No redundant scans or full-channel history parsing
# - Proxy: 192.168.1.138:3128
# - Target Dir: YOUTUBE_[CHANNELNAME]_DOWNLOAD_[INSERTDATE]
# ==============================================================================
set -euo pipefail

PROXY="${YOUTUBE_PROXY:-http://192.168.1.138:3128}"
NODE_PATH=$(command -v node 2>/dev/null || echo "/home/mplanetarian/.local/bin/node")
JS_ARG=()
[[ -x "$NODE_PATH" ]] && JS_ARG=(--js-runtimes "node:${NODE_PATH}")

echo -e "\033[1;36m=== YouTube 1080p Channel Downloader (Last 6 Months) ===\033[0m"

# 1. Quick Proxy Ping (2-second timeout)
if ! curl -s -x "$PROXY" -I https://www.google.com --connect-timeout 2 >/dev/null; then
    echo -e "\033[1;31m❌ Error: Proxy server $PROXY is unreachable.\033[0m"
    read -rp "Press Enter to exit..."
    exit 1
fi
echo -e "\033[32m✔ Proxy online: $PROXY\033[0m"

# 2. Live Wi-Fi Stats (instant one-shot query)
IFACE=$(ip -o link show 2>/dev/null | awk -F': ' '$2 ~ /^wl/ {print $2; exit}' || true)
IFACE=${IFACE:-wlp2s0}
LINK_INFO=$(iw dev "$IFACE" link 2>/dev/null || true)
SSID=$(echo "$LINK_INFO" | awk -F': ' '/SSID:/ {print $2}')
BSSID=$(echo "$LINK_INFO" | awk '/Connected to/ {print $3}')
FREQ=$(echo "$LINK_INFO" | awk -F': ' '/freq:/ {print $2}')
SIGNAL=$(echo "$LINK_INFO" | awk -F': ' '/signal:/ {print $2}')
RXRATE=$(echo "$LINK_INFO" | awk -F': ' '/rx bitrate:/ {print $2}')
TXRATE=$(echo "$LINK_INFO" | awk -F': ' '/tx bitrate:/ {print $2}')
IP_ADDR=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet / {print $2}')

echo -e "\033[1;34m📶 Wi-Fi:\033[0m ${SSID:-N/A} (${BSSID:-N/A}) | Signal: ${SIGNAL:-N/A} | Freq: ${FREQ:-N/A} MHz"
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

CUTOFF_DATE=$(date -d '6 months ago' +%Y%m%d)
echo -e "\033[1;32m📁 Directory:\033[0m $(pwd)"
echo -e "\033[1;32m📅 Cutoff:\033[0m Only videos on/after $(date -d '6 months ago' '+%B %d, %Y') ($CUTOFF_DATE)"
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
    --exec 'after_video:bash -c '\''SIZE=$(stat -c %s "$1" 2>/dev/null | numfmt --to=iec-i --suffix=B || echo "Unknown"); echo -e "\n\033[1;32m✔ Finished: $(basename "$1") | Size: ${SIZE}\033[0m\n"'\'' _ {}' \
    "$CHANNEL_URL" || true

TOTAL_TIME=$(( $(date +%s) - START_TIME ))
MINS=$(( TOTAL_TIME / 60 ))
SECS=$(( TOTAL_TIME % 60 ))

echo -e "\n\033[1;32m═══════════════════════════════════════════════════════\033[0m"
echo -e "\033[1;32m🎉 Batch finished in ${MINS}m ${SECS}s\033[0m"
echo -e "\033[1;34m📁 Saved in:\033[0m $(pwd)"
echo -e "\033[1;32m═══════════════════════════════════════════════════════\033[0m"

read -rp "Press Enter to exit..."
