#!/usr/bin/env bash
# ==============================================================================
# scripts/manage_open_webui.sh
# Purpose: Start, stop, restart, open browser, and monitor Open WebUI
#          Web Chat AI Harness listening on port 42004
#          (http://127.0.0.1:42004/auth?redirect=%2F)
# ==============================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

OPEN_WEBUI_HOST="${OPEN_WEBUI_HOST:-0.0.0.0}"
OPEN_WEBUI_PORT="${OPEN_WEBUI_PORT:-42004}"
OPEN_WEBUI_PATH="${OPEN_WEBUI_PATH:-/auth?redirect=%2F}"
OPEN_WEBUI_LOCAL_URL="http://127.0.0.1:${OPEN_WEBUI_PORT}${OPEN_WEBUI_PATH}"
OPEN_WEBUI_SERVICE="open-webui.service"
OPEN_WEBUI_BIN="${OPEN_WEBUI_BIN:-/home/mplanetarian/pinokio/api/open-webui/app/env/bin/open-webui}"
OPEN_WEBUI_DIR="${OPEN_WEBUI_DIR:-/home/mplanetarian/pinokio/api/open-webui/app}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_API_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:${OLLAMA_PORT}}"
LOG_FILE="/tmp/open-webui.log"

is_webui_running() {
    if systemctl --user is-active --quiet "$OPEN_WEBUI_SERVICE" 2>/dev/null; then
        return 0
    elif curl -s -I --connect-timeout 1 "http://127.0.0.1:${OPEN_WEBUI_PORT}/" 2>/dev/null | grep -qi "HTTP/"; then
        return 0
    elif pgrep -f "open-webui serve" >/dev/null 2>&1; then
        return 0
    elif ss -tuln 2>/dev/null | grep -q ":${OPEN_WEBUI_PORT} "; then
        return 0
    fi
    return 1
}

get_webui_pids() {
    local pids
    pids=$(pgrep -f "open-webui serve" 2>/dev/null | tr '\n' ' ')
    if [ -z "$pids" ] && systemctl --user is-active --quiet "$OPEN_WEBUI_SERVICE" 2>/dev/null; then
        pids=$(systemctl --user show "$OPEN_WEBUI_SERVICE" -p MainPID 2>/dev/null | cut -d'=' -f2)
        [ "$pids" = "0" ] && pids=""
    fi
    echo "$pids"
}

is_ollama_running() {
    if curl -s --connect-timeout 1 "${OLLAMA_API_URL}/" 2>/dev/null | grep -qi "Ollama is running"; then
        return 0
    elif pgrep -f "ollama serve" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

open_webui_browser() {
    local target_url="$OPEN_WEBUI_LOCAL_URL"
    echo -e "\n${BOLD}${CYAN}Opening Open WebUI in browser:${NC} ${BOLD}${YELLOW}${target_url}${NC}\n"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v google-chrome >/dev/null 2>&1; then
        google-chrome "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    elif command -v firefox >/dev/null 2>&1; then
        firefox "$target_url" >/dev/null 2>&1 &
        disown 2>/dev/null || true
    else
        echo -e "${YELLOW}Please open the URL in your browser: ${target_url}${NC}"
    fi
}

start_webui_bg() {
    echo -e "\n${BOLD}${BLUE}=== STARTING OPEN WEBUI (BACKGROUND SERVICE) ===${NC}"
    if is_webui_running; then
        local pids
        pids=$(get_webui_pids)
        echo -e "${GREEN}✓ Open WebUI server is already running (PID: ${pids% }, URL: ${OPEN_WEBUI_LOCAL_URL}).${NC}"
        return 0
    fi

    # Ensure backend Ollama is running if possible
    if ! is_ollama_running; then
        echo -e "  ${YELLOW}Notice: Ollama backend is not detected. Starting Ollama in background...${NC}"
        if [ -f "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" ]; then
            "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" start >/dev/null 2>&1 || true
        fi
    fi

    if systemctl --user list-unit-files "$OPEN_WEBUI_SERVICE" >/dev/null 2>&1; then
        echo -e "Starting Open WebUI via systemd user service (${OPEN_WEBUI_SERVICE})..."
        systemctl --user start "$OPEN_WEBUI_SERVICE" 2>/dev/null || true
    elif [ -x "$OPEN_WEBUI_BIN" ]; then
        echo -e "Starting Open WebUI standalone daemon..."
        mkdir -p "$OPEN_WEBUI_DIR/data" 2>/dev/null || true
        nohup env DATA_DIR="$OPEN_WEBUI_DIR/data" OLLAMA_BASE_URL="$OLLAMA_API_URL" "$OPEN_WEBUI_BIN" serve --host "$OPEN_WEBUI_HOST" --port "$OPEN_WEBUI_PORT" >"$LOG_FILE" 2>&1 &
    else
        echo -e "${RED}Error: Neither systemd service '$OPEN_WEBUI_SERVICE' nor executable '$OPEN_WEBUI_BIN' found!${NC}"
        return 1
    fi

    echo -e "Waiting for Open WebUI endpoint to become responsive..."
    local ready=false
    for _ in {1..25}; do
        if curl -s -I --connect-timeout 1 "http://127.0.0.1:${OPEN_WEBUI_PORT}/" 2>/dev/null | grep -qi "HTTP/"; then
            ready=true
            break
        fi
        sleep 0.5
    done

    local LAN_IP
    LAN_IP=$(ip -4 addr show wlp2s0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || hostname -I 2>/dev/null | awk '{print $1}')

    if [ "$ready" = "true" ]; then
        local pids
        pids=$(get_webui_pids)
        echo -e "${BOLD}${GREEN}✓ Open WebUI server successfully started!${NC}"
        echo -e "  • Status:       ${GREEN}RUNNING${NC}"
        echo -e "  • Local Web UI: ${BOLD}${CYAN}${OPEN_WEBUI_LOCAL_URL}${NC}"
        [ -n "$LAN_IP" ] && echo -e "  • LAN Endpoint: ${BOLD}${CYAN}http://${LAN_IP}:${OPEN_WEBUI_PORT}${OPEN_WEBUI_PATH}${NC}"
        echo -e "  • PID(s):       ${YELLOW}${pids% }${NC}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "Open WebUI" -i "dialog-ok" "Open WebUI" "✓ Open WebUI is live on http://${LAN_IP:-127.0.0.1}:${OPEN_WEBUI_PORT}" 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}Warning: Open WebUI did not respond on http://127.0.0.1:${OPEN_WEBUI_PORT} within 12s.${NC}"
        echo -e "${YELLOW}Check service logs with option 6 or: journalctl --user -u ${OPEN_WEBUI_SERVICE} -n 20${NC}"
        return 1
    fi
}

start_webui_window() {
    echo -e "\n${BOLD}${BLUE}=== STARTING OPEN WEBUI (TERMINAL WINDOW) ===${NC}"
    if is_webui_running; then
        local pids
        pids=$(get_webui_pids)
        echo -e "${GREEN}✓ Open WebUI server is already running (PID: ${pids% }, URL: ${OPEN_WEBUI_LOCAL_URL}).${NC}"
        echo -e "Opening live journal log monitor in terminal window..."
        local TITLE="Open WebUI Live Server Monitor"
        local CMD="journalctl --user -u ${OPEN_WEBUI_SERVICE} -f -n 50; echo ''; echo 'Log stream closed. Press Enter...'; read -r"
        if command -v konsole >/dev/null 2>&1; then
            konsole --new-tab -p tabtitle="$TITLE" -e bash -c "$CMD" &
        elif command -v xdg-terminal-exec >/dev/null 2>&1; then
            nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
        else
            journalctl --user -u "${OPEN_WEBUI_SERVICE}" -f -n 50
        fi
        return 0
    fi

    local TITLE="Open WebUI Server (:42004)"
    local CMD
    if [ -x "$OPEN_WEBUI_BIN" ]; then
        CMD="cd '${OPEN_WEBUI_DIR}' && env DATA_DIR='${OPEN_WEBUI_DIR}/data' OLLAMA_BASE_URL='${OLLAMA_API_URL}' '${OPEN_WEBUI_BIN}' serve --host '${OPEN_WEBUI_HOST}' --port '${OPEN_WEBUI_PORT}'; echo ''; echo 'Server exited. Press [Enter] to close...'; read -r"
    else
        CMD="systemctl --user start ${OPEN_WEBUI_SERVICE} && journalctl --user -u ${OPEN_WEBUI_SERVICE} -f; echo ''; read -r"
    fi

    echo -e "Opening terminal window for Open WebUI [listening on ${OPEN_WEBUI_PORT}]..."
    if command -v konsole >/dev/null 2>&1; then
        konsole --new-tab -p tabtitle="$TITLE" -e bash -c "$CMD" &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$TITLE" -- bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$TITLE" -e bash -c "$CMD" >/dev/null 2>&1 &
    else
        start_webui_bg
        return $?
    fi

    echo -e "Waiting for Open WebUI to initialize..."
    sleep 2
    return 0
}

stop_webui() {
    echo -e "\n${BOLD}${YELLOW}Stopping Open WebUI Server...${NC}"
    if ! is_webui_running; then
        echo -e "${YELLOW}Open WebUI server is not currently running.${NC}"
        return 0
    fi

    if systemctl --user list-unit-files "$OPEN_WEBUI_SERVICE" >/dev/null 2>&1; then
        systemctl --user stop "$OPEN_WEBUI_SERVICE" 2>/dev/null || true
    fi

    local pids
    pids=$(get_webui_pids)
    if [ -n "$pids" ]; then
        # shellcheck disable=SC2086
        kill $pids 2>/dev/null || true
        sleep 1
        pids=$(get_webui_pids)
        if [ -n "$pids" ]; then
            # shellcheck disable=SC2086
            kill -9 $pids 2>/dev/null || true
        fi
    fi

    if ! is_webui_running; then
        echo -e "${GREEN}✓ Open WebUI server successfully stopped.${NC}"
    else
        echo -e "${RED}Warning: Open WebUI process could not be terminated.${NC}"
    fi
}

restart_webui() {
    echo -e "\n${BOLD}${BLUE}=== RESTARTING OPEN WEBUI SERVER ===${NC}"
    stop_webui
    sleep 1
    start_webui_bg
}

show_status() {
    local LAN_IP
    LAN_IP=$(ip -4 addr show wlp2s0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || hostname -I 2>/dev/null | awk '{print $1}')

    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}             OPEN WEBUI — WEB CHAT AI HARNESS SUITE                  ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"

    if is_webui_running; then
        local pids
        pids=$(get_webui_pids)
        echo -e "  Server Status:    ${BOLD}${GREEN}● RUNNING${NC} (PID: ${pids% })"
        echo -e "  Local Web UI URL: ${BOLD}${CYAN}${OPEN_WEBUI_LOCAL_URL}${NC}"
        [ -n "$LAN_IP" ] && echo -e "  LAN Endpoint:     ${BOLD}${CYAN}http://${LAN_IP}:${OPEN_WEBUI_PORT}${OPEN_WEBUI_PATH}${NC}"
        echo -e "  HTTP Health:      ${GREEN}HTTP 200 OK (Open WebUI)${NC}"
        echo -e "  Service Unit:     ${GREEN}${OPEN_WEBUI_SERVICE}${NC} (systemd user service)"
    else
        echo -e "  Server Status:    ${BOLD}${RED}○ STOPPED${NC}"
        echo -e "  Local Web UI URL: ${BOLD}${CYAN}${OPEN_WEBUI_LOCAL_URL}${NC} (Offline)"
        [ -n "$LAN_IP" ] && echo -e "  LAN Endpoint:     ${BOLD}${CYAN}http://${LAN_IP}:${OPEN_WEBUI_PORT}${OPEN_WEBUI_PATH}${NC} (Offline)"
        echo -e "  Service Unit:     ${YELLOW}${OPEN_WEBUI_SERVICE}${NC}"
    fi

    # Ollama backend status
    if is_ollama_running; then
        echo -e "  Ollama Backend:   ${BOLD}${GREEN}● CONNECTED${NC} (${OLLAMA_API_URL})"
    else
        echo -e "  Ollama Backend:   ${BOLD}${RED}○ OFFLINE${NC} (${OLLAMA_API_URL})"
    fi

    # GPU info
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_info
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -n 1)
        [ -n "$gpu_info" ] && echo -e "  Hardware Accel:   ${GREEN}${gpu_info}${NC} (CUDA Enabled)"
    fi

    echo ""
    echo -e "${BOLD}Installed Local Models Available for Web Chat:${NC}"
    if is_ollama_running; then
        local model_list
        model_list=$(curl -s "${OLLAMA_API_URL}/api/tags" 2>/dev/null)
        if [ -n "$model_list" ] && command -v jq >/dev/null 2>&1; then
            echo "$model_list" | jq -r '.models[]? | "  • \(.name) (\((.size / 1073741824 * 10 | floor) / 10) GB, \(.details.parameter_size // "N/A"))"' 2>/dev/null
        else
            echo -e "  ${GREEN}Ollama models online at ${OLLAMA_API_URL}${NC}"
        fi
    else
        echo -e "  ${YELLOW}(Start Ollama server to feed local models into Open WebUI)${NC}"
    fi
    echo ""
}

view_logs() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                     OPEN WEBUI SERVER LOGS                           ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    if systemctl --user list-unit-files "$OPEN_WEBUI_SERVICE" >/dev/null 2>&1; then
        echo -e "Showing last 50 log entries from systemd journal (${OPEN_WEBUI_SERVICE}):\n"
        journalctl --user -u "$OPEN_WEBUI_SERVICE" -n 50 --no-pager 2>/dev/null || true
    elif [ -f "$LOG_FILE" ]; then
        echo -e "Last 50 lines of ${LOG_FILE}:\n"
        tail -n 50 "$LOG_FILE"
    else
        echo -e "No log file found."
    fi
    echo ""
    read -r -p "Press Enter to return..."
}

interactive_menu() {
    while true; do
        clear
        show_status
        echo -e "${BOLD}${MAGENTA}----------------------------------------------------------------------${NC}"
        echo -e "${BOLD}Select an Open WebUI operation:${NC}\n"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Open Web Chat in Browser (${BOLD}${GREEN}${OPEN_WEBUI_LOCAL_URL}${NC})"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Start Open WebUI Server (${BOLD}${GREEN}Background Service${NC}) [systemd / daemon]"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Start Open WebUI Server in ${BOLD}${YELLOW}New Terminal Window${NC} (Live Logs)"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Stop Running Open WebUI Server"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Restart Open WebUI Server"
        echo -e "  ${BOLD}${CYAN} 6)${NC} View Service Status & Logs (${OPEN_WEBUI_SERVICE})"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Return to Previous Menu\n"
        read -r -p "Enter choice [1-7, or q to return]: " w_choice

        case "$w_choice" in
            1)
                if ! is_webui_running; then
                    echo -e "\n${YELLOW}Open WebUI is not running. Starting server first...${NC}"
                    start_webui_bg
                    sleep 1
                fi
                open_webui_browser
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            2)
                start_webui_bg
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            3)
                start_webui_window
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            4)
                stop_webui
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            5)
                restart_webui
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            6)
                view_logs
                ;;
            7|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

case "${1:-}" in
    open|launch|browser|chat)
        if ! is_webui_running; then
            start_webui_bg
            sleep 1
        fi
        open_webui_browser
        ;;
    start|serve|bg)
        start_webui_bg
        ;;
    start-window|window|terminal)
        start_webui_window
        ;;
    stop)
        stop_webui
        ;;
    restart)
        restart_webui
        ;;
    status)
        show_status
        ;;
    logs)
        view_logs
        ;;
    "")
        interactive_menu
        ;;
    *)
        echo "Usage: $(basename "$0") {open|start|start-window|stop|restart|status|logs}"
        exit 1
        ;;
esac
