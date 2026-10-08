#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Unified Notification Dispatcher
# Supports Desktop notifications, Discord Webhooks, Telegram Bots, and Pushover
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$SCRIPT_DIR/config.env" ] && source "$SCRIPT_DIR/config.env" 2>/dev/null || true

TITLE="${1:-MP Mix Manager}"
MESSAGE="${2:-Task completed successfully}"
PRIORITY="${3:-normal}" # normal, urgent, low

# 1. Desktop Notification
if command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$PRIORITY" "$TITLE" "$MESSAGE" 2>/dev/null || true
elif [ "$(uname -s)" = "Darwin" ]; then
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null || true
fi

# 2. Discord Webhook
if [ -n "${DISCORD_WEBHOOK_URL:-}" ]; then
    curl -s -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"**${TITLE}**\\n${MESSAGE}\"}" \
         "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 &
fi

# 3. Telegram Bot
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s -X POST \
         "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
         -d "chat_id=${TELEGRAM_CHAT_ID}" \
         -d "text=**${TITLE}**%0A${MESSAGE}" \
         -d "parse_mode=Markdown" >/dev/null 2>&1 &
fi

# 4. Pushover
if [ -n "${PUSHOVER_USER_KEY:-}" ] && [ -n "${PUSHOVER_API_TOKEN:-}" ]; then
    curl -s \
         --form-string "token=${PUSHOVER_API_TOKEN}" \
         --form-string "user=${PUSHOVER_USER_KEY}" \
         --form-string "title=${TITLE}" \
         --form-string "message=${MESSAGE}" \
         https://api.pushover.net/1/messages.json >/dev/null 2>&1 &
fi

echo "[✓] Notification dispatched: $TITLE - $MESSAGE"
