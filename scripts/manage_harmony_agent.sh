#!/usr/bin/env bash
# ==============================================================================
# scripts/manage_harmony_agent.sh
# Purpose: Start, stop, restart, chat with, and monitor MP Harmony AI Agent
#          (OpenAI Harmony Autonomous Engineering Agent & Voice Bridge :11435)
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
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

HARMONY_DIR="${HARMONY_DIR:-/var/home/mplanetarian/OpenAI/MP_Harmony_Agent}"
if [ ! -d "$HARMONY_DIR" ] && [ -d "$HOME/OpenAI/MP_Harmony_Agent" ]; then
    HARMONY_DIR="$HOME/OpenAI/MP_Harmony_Agent"
elif [ ! -d "$HARMONY_DIR" ] && [ -d "$HOME/OpenAI/Harmony_Agent" ]; then
    HARMONY_DIR="$HOME/OpenAI/Harmony_Agent"
fi

HARMONY_SCRIPT="$HARMONY_DIR/MP_Harmony_Agent.py"
[ ! -f "$HARMONY_SCRIPT" ] && [ -f "$HARMONY_DIR/HA.py" ] && HARMONY_SCRIPT="$HARMONY_DIR/HA.py"

HARMONY_PORT="${HARMONY_PORT:-11435}"
HARMONY_API_URL="http://127.0.0.1:${HARMONY_PORT}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
OLLAMA_API_URL="${OLLAMA_BASE_URL:-http://127.0.0.1:${OLLAMA_PORT}}"
AUDIO_DIR="$HARMONY_DIR/audio_responses"
LOG_FILE="/tmp/mp-harmony-agent.log"
PYTHON_BIN="${PYTHON_BIN:-python3}"

is_harmony_running() {
    if command -v lsof >/dev/null 2>&1 && lsof -i ":${HARMONY_PORT}" >/dev/null 2>&1; then
        return 0
    elif ss -tuln 2>/dev/null | grep -q ":${HARMONY_PORT} "; then
        return 0
    elif pgrep -f "MP_Harmony_Agent\.py" >/dev/null 2>&1; then
        return 0
    elif pgrep -f "HA\.py.*--server" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

get_harmony_pids() {
    local pids=""
    if command -v lsof >/dev/null 2>&1; then
        pids=$(lsof -t -i ":${HARMONY_PORT}" 2>/dev/null | tr '\n' ' ')
    fi
    if [ -z "$pids" ]; then
        pids=$(pgrep -f "MP_Harmony_Agent\.py" 2>/dev/null | tr '\n' ' ')
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

get_active_model() {
    # Check running python process directly (excluding bash/konsole wrapper)
    local cmdline
    cmdline=$(pgrep -a -f "python.*MP_Harmony_Agent\.py" 2>/dev/null | grep -oE '(gpt-oss[a-zA-Z0-9:._-]*|qwen[a-zA-Z0-9:._-]*)' | head -1)
    if [ -n "$cmdline" ]; then
        cmdline="${cmdline//[\'\";]/}"
        if [ -n "$cmdline" ]; then
            echo "$cmdline"
            return 0
        fi
    fi

    # Fallback to querying Ollama tags
    if is_ollama_running; then
        local found_model
        found_model=$(curl -s "${OLLAMA_API_URL}/api/tags" 2>/dev/null | grep -o '"name":"[^"]*"' | grep -i "gpt-oss" | head -1 | cut -d'"' -f4)
        if [ -n "$found_model" ]; then
            found_model="${found_model//[\'\";]/}"
            echo "$found_model"
            return 0
        fi
    fi
    echo "gpt-oss-pinned:latest"
}

start_harmony_bg() {
    echo -e "\n${BOLD}${BLUE}=== STARTING MP HARMONY AI AGENT (BACKGROUND SERVER) ===${NC}"
    if is_harmony_running; then
        local pids
        pids=$(get_harmony_pids)
        echo -e "${GREEN}✓ MP Harmony Agent server is already running (PID: ${pids% }, Port: ${HARMONY_PORT}).${NC}"
        return 0
    fi

    if [ ! -f "$HARMONY_SCRIPT" ]; then
        echo -e "${RED}Error: MP_Harmony_Agent.py not found in ${HARMONY_DIR}!${NC}"
        return 1
    fi

    # Ensure backend Ollama is running
    if ! is_ollama_running; then
        echo -e "  ${YELLOW}Notice: Ollama backend is not detected. Starting Ollama in background...${NC}"
        if [ -f "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" ]; then
            "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" start >/dev/null 2>&1 || true
            sleep 1
        fi
    fi

    local target_model
    target_model=$(get_active_model)
    target_model="${target_model//[\'\";]/}"
    [ -z "$target_model" ] && target_model="gpt-oss-pinned:latest"

    echo -e "Launching MP Harmony Voice Bridge server [Model: ${CYAN}${target_model}${NC}, Port: ${CYAN}${HARMONY_PORT}${NC}]..."
    setsid "$PYTHON_BIN" -u "$HARMONY_SCRIPT" --server "$target_model" </dev/null >"$LOG_FILE" 2>&1 &
    local launch_pid=$!
    disown "$launch_pid" 2>/dev/null || true

    echo -e "Waiting for MP Harmony API endpoint to initialize..."
    local ready=false
    for _ in {1..30}; do
        if ss -tuln 2>/dev/null | grep -q ":${HARMONY_PORT} "; then
            ready=true
            break
        fi
        sleep 0.5
    done

    if [ "$ready" = "true" ]; then
        local pids
        pids=$(get_harmony_pids)
        echo -e "${BOLD}${GREEN}✓ MP Harmony AI Agent server successfully started!${NC}"
        echo -e "  • Status:         ${GREEN}RUNNING${NC}"
        echo -e "  • Voice Bridge:   ${BOLD}${CYAN}${HARMONY_API_URL}/v1/chat/completions${NC}"
        echo -e "  • Abort Endpoint: ${BOLD}${CYAN}${HARMONY_API_URL}/v1/abort${NC}"
        echo -e "  • Model Tag:      ${YELLOW}${target_model}${NC}"
        echo -e "  • PID(s):         ${YELLOW}${pids% }${NC}"
        echo -e "  • Log File:       ${LOG_FILE}"
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "MP Harmony Agent" -i "dialog-ok" "MP Harmony Agent" "✓ MP Harmony Agent Voice Bridge is live on port ${HARMONY_PORT}" 2>/dev/null || true
        fi
        return 0
    else
        echo -e "${RED}Warning: MP Harmony Agent did not bind to port ${HARMONY_PORT} within 10s.${NC}"
        echo -e "${YELLOW}Check logs with: tail -n 25 ${LOG_FILE}${NC}"
        return 1
    fi
}

start_harmony_window() {
    echo -e "\n${BOLD}${BLUE}=== STARTING MP HARMONY AI AGENT (TERMINAL WINDOW) ===${NC}"
    if is_harmony_running; then
        local pids
        pids=$(get_harmony_pids)
        echo -e "${BOLD}${YELLOW}Notice: MP Harmony Agent server is ALREADY RUNNING!${NC}"
        echo -e "  • PID(s):        ${CYAN}${pids% }${NC}"
        echo -e "  • Voice Bridge:  ${CYAN}${HARMONY_API_URL}/v1/chat/completions${NC}"
        echo -e "  • Status:        ${GREEN}● ACTIVE${NC}\n"
        local restart_choice=""
        read -r -p "Do you want to stop the existing instance and restart in a new window? [y/N]: " restart_choice </dev/tty || true
        case "$restart_choice" in
            [yY]|[yY][eE][sS])
                stop_harmony
                sleep 1
                ;;
            *)
                echo -e "${GREEN}Keeping existing MP Harmony Agent server running.${NC}"
                return 0
                ;;
        esac
    fi

    if [ ! -f "$HARMONY_SCRIPT" ]; then
        echo -e "${RED}Error: MP_Harmony_Agent.py not found in ${HARMONY_DIR}!${NC}"
        return 1
    fi

    # Ensure backend Ollama is running
    if ! is_ollama_running; then
        echo -e "  ${YELLOW}Notice: Ollama backend is not detected. Starting Ollama in background...${NC}"
        if [ -f "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" ]; then
            "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" start >/dev/null 2>&1 || true
            sleep 1
        fi
    fi

    local target_model
    target_model=$(get_active_model)
    target_model="${target_model//[\'\";]/}"
    [ -z "$target_model" ] && target_model="gpt-oss-pinned:latest"
    local TITLE="MP Harmony AI Agent Server (Port ${HARMONY_PORT})"
    local CMD="cd '${HARMONY_DIR}' && python3 '${HARMONY_SCRIPT}' --server '${target_model}'; echo ''; echo 'Agent exited. Press [Enter] to close...'; read -r"

    echo -e "Opening terminal window for MP Harmony Agent Voice Bridge [Port ${HARMONY_PORT}]..."
    if command -v konsole >/dev/null 2>&1; then
        konsole --new-tab -p tabtitle="$TITLE" -e bash -c "$CMD" &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$TITLE" -- bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$TITLE" -e bash -c "$CMD" >/dev/null 2>&1 &
    else
        start_harmony_bg
        return $?
    fi

    echo -e "Waiting for MP Harmony Agent to initialize..."
    sleep 2
    return 0
}

launch_chat_cli() {
    if [ ! -f "$HARMONY_SCRIPT" ]; then
        echo -e "${RED}Error: MP_Harmony_Agent.py not found in ${HARMONY_DIR}!${NC}"
        return 1
    fi

    # Ensure backend Ollama is running
    if ! is_ollama_running; then
        echo -e "  ${YELLOW}Notice: Ollama backend is not detected. Starting Ollama in background...${NC}"
        if [ -f "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" ]; then
            "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" start >/dev/null 2>&1 || true
            sleep 1
        fi
    fi

    local target_model
    target_model=$(get_active_model)
    target_model="${target_model//[\'\";]/}"
    [ -z "$target_model" ] && target_model="gpt-oss-pinned:latest"

    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}         LAUNCHING MP HARMONY AI AGENT INTERACTIVE CHAT               ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "  • Model:     ${CYAN}${target_model}${NC}"
    echo -e "  • Script:    ${DIM}${HARMONY_SCRIPT}${NC}"
    echo -e "  • Type:      ${YELLOW}exit, /quit, or Ctrl+D to return to Manager${NC}\n"
    sleep 1

    (
        cd "$HARMONY_DIR" || exit 1
        "$PYTHON_BIN" "$HARMONY_SCRIPT" "$target_model"
    )
}

launch_voice_chat_cli() {
    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}    LAUNCHING VOICE CHAT CLI WITH MP HARMONY AGENT (TERMINAL)        ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"

    # Ensure backend Ollama is running
    if ! is_ollama_running; then
        echo -e "  ${YELLOW}Notice: Ollama backend is not detected. Starting Ollama in background...${NC}"
        if [ -f "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" ]; then
            "$(dirname "${BASH_SOURCE[0]}")/manage_ollama.sh" start >/dev/null 2>&1 || true
            sleep 1
        fi
    fi

    # Ensure MP Harmony server is running on 11435
    if ! is_harmony_running; then
        echo -e "  ${YELLOW}Notice: MP Harmony Voice Bridge is not currently running.${NC}"
        echo -e "  Starting MP Harmony Agent server in background on port ${HARMONY_PORT}..."
        start_harmony_bg
        sleep 2
    fi

    local target_model
    target_model=$(get_active_model)
    target_model="${target_model//[\'\";]/}"
    [ -z "$target_model" ] && target_model="gpt-oss-pinned:latest"

    local voice_bin
    voice_bin=$(command -v local-voice-talk 2>/dev/null || echo "$HOME/bin/local-voice-talk")

    if [ ! -x "$voice_bin" ] && ! command -v local-voice-talk >/dev/null 2>&1; then
        echo -e "${RED}Error: 'local-voice-talk' command not found!${NC}"
        echo -e "${YELLOW}Expected at: $HOME/bin/local-voice-talk${NC}"
        return 1
    fi

    echo -e "  • Bridge URL: ${BOLD}${CYAN}http://127.0.0.1:${HARMONY_PORT}${NC}"
    echo -e "  • Model:      ${BOLD}${YELLOW}${target_model}${NC}"
    echo -e "  • Engine:     ${BOLD}${GREEN}Whisper STT + MP Harmony Voice Bridge${NC}"
    echo -e "  • Command:    ${DIM}OLLAMA_URL=\"http://127.0.0.1:11435\" local-voice-talk --model ${target_model}${NC}\n"
    sleep 1

    OLLAMA_URL="http://127.0.0.1:11435" "$voice_bin" --model "$target_model"
}

stop_harmony() {
    echo -e "\n${BOLD}${YELLOW}Stopping MP Harmony AI Agent...${NC}"
    if ! is_harmony_running; then
        echo -e "${YELLOW}MP Harmony Agent is not currently running.${NC}"
        return 0
    fi

    local pids
    pids=$(get_harmony_pids)
    if [ -n "$pids" ]; then
        echo -e "Terminating MP Harmony process(es): ${pids% }..."
        # shellcheck disable=SC2086
        kill $pids 2>/dev/null || true
        sleep 1
        pids=$(get_harmony_pids)
        if [ -n "$pids" ]; then
            # shellcheck disable=SC2086
            kill -9 $pids 2>/dev/null || true
        fi
    fi

    if command -v fuser >/dev/null 2>&1; then
        fuser -k -9 "${HARMONY_PORT}/tcp" >/dev/null 2>&1 || true
    fi

    sleep 0.5
    if ! is_harmony_running; then
        echo -e "${GREEN}✓ MP Harmony AI Agent successfully stopped.${NC}"
    else
        echo -e "${RED}Warning: Could not terminate all MP Harmony Agent processes.${NC}"
    fi
}

restart_harmony() {
    echo -e "\n${BOLD}${BLUE}=== RESTARTING MP HARMONY AI AGENT ===${NC}"
    stop_harmony
    sleep 1
    start_harmony_bg
}

show_status() {
    local target_model
    target_model=$(get_active_model)

    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}           MP HARMONY AI AGENT — AUTONOMOUS ENGINEERING ENGINE        ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"

    if is_harmony_running; then
        local pids
        pids=$(get_harmony_pids)
        echo -e "  Server Status:    ${BOLD}${GREEN}● RUNNING${NC} (PID: ${pids% })"
        echo -e "  Voice Bridge:     ${BOLD}${CYAN}${HARMONY_API_URL}/v1/chat/completions${NC}"
        echo -e "  Abort Endpoint:   ${BOLD}${CYAN}${HARMONY_API_URL}/v1/abort${NC}"
        echo -e "  Active Model:     ${BOLD}${YELLOW}${target_model}${NC}"
        echo -e "  HTTP Endpoint:    ${GREEN}Port ${HARMONY_PORT} (Listening)${NC}"
    else
        echo -e "  Server Status:    ${BOLD}${RED}○ STOPPED${NC}"
        echo -e "  Voice Bridge:     ${BOLD}${CYAN}${HARMONY_API_URL}/v1/chat/completions${NC} (Offline)"
        echo -e "  Target Model:     ${YELLOW}${target_model}${NC}"
    fi

    # Ollama backend status
    if is_ollama_running; then
        echo -e "  Ollama Backend:   ${BOLD}${GREEN}● CONNECTED${NC} (${OLLAMA_API_URL})"
    else
        echo -e "  Ollama Backend:   ${BOLD}${RED}○ OFFLINE${NC} (${OLLAMA_API_URL})"
    fi

    # Script location
    if [ -f "$HARMONY_SCRIPT" ]; then
        echo -e "  Agent Script:     ${GREEN}${HARMONY_SCRIPT}${NC}"
    else
        echo -e "  Agent Script:     ${RED}NOT FOUND${NC} (${HARMONY_DIR})"
    fi

    # Audio responses archive
    if [ -d "$AUDIO_DIR" ]; then
        local wav_count
        wav_count=$(find "$AUDIO_DIR" -name "*.wav" 2>/dev/null | wc -l)
        echo -e "  Audio Archive:    ${CYAN}${AUDIO_DIR}${NC} (${wav_count} responses recorded)"
    fi

    # GPU info
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_info
        gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -n 1)
        [ -n "$gpu_info" ] && echo -e "  Hardware Accel:   ${GREEN}${gpu_info}${NC} (CUDA Enabled)"
    fi
    echo ""
}

view_audio_responses() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}              MP HARMONY AGENT AUDIO SPEECH ARCHIVE                   ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    if [ ! -d "$AUDIO_DIR" ]; then
        echo -e "Audio responses directory does not exist: ${AUDIO_DIR}"
        echo ""
        read -r -p "Press Enter to return..."
        return 0
    fi

    local wavs=()
    mapfile -t wavs < <(find "$AUDIO_DIR" -name "*.wav" -type f 2>/dev/null | sort -r | head -n 15)

    if [ ${#wavs[@]} -eq 0 ]; then
        echo -e "No recorded audio responses found yet in ${AUDIO_DIR}."
        echo ""
        read -r -p "Press Enter to return..."
        return 0
    fi

    echo -e "Recent Audio Speech Responses (Latest 15):\n"
    local idx=1
    for w in "${wavs[@]}"; do
        local bname txt_file txt_snippet
        bname=$(basename "$w")
        txt_file="${w%.*}.txt"
        txt_snippet=""
        if [ -f "$txt_file" ]; then
            txt_snippet=$(head -n 1 "$txt_file" | cut -c 1-60)
            [ -n "$txt_snippet" ] && txt_snippet=" - \"${txt_snippet}...\""
        fi
        printf "  %2d) %s%s\n" "$idx" "$bname" "$txt_snippet"
        ((idx++))
    done
    echo ""
    echo -e "Enter number [1-${#wavs[@]}] to play with audio player, or press Enter to return:"
    read -r -p "Choice: " a_choice
    if [[ "$a_choice" =~ ^[0-9]+$ ]] && [ "$a_choice" -ge 1 ] && [ "$a_choice" -le ${#wavs[@]} ]; then
        local chosen_wav="${wavs[$((a_choice - 1))]}"
        echo -e "\n${BOLD}${CYAN}Playing: ${chosen_wav}${NC}"
        if command -v paplay >/dev/null 2>&1; then
            paplay "$chosen_wav"
        elif command -v pw-play >/dev/null 2>&1; then
            pw-play "$chosen_wav"
        elif command -v aplay >/dev/null 2>&1; then
            aplay -q "$chosen_wav"
        elif command -v mpv >/dev/null 2>&1; then
            mpv --no-video "$chosen_wav"
        else
            xdg-open "$chosen_wav" >/dev/null 2>&1 || true
        fi
        echo ""
        read -r -p "Press Enter to return..."
    fi
}

view_logs() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                   MP HARMONY AGENT SERVER LOGS                       ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    if [ -f "$LOG_FILE" ]; then
        echo -e "Last 50 lines of ${LOG_FILE}:\n"
        tail -n 50 "$LOG_FILE"
    else
        echo -e "No log file found at ${LOG_FILE} (server may have been launched in a separate window or terminal)."
    fi
    echo ""
    read -r -p "Press Enter to return..."
}

interactive_menu() {
    while true; do
        clear
        show_status
        echo -e "${BOLD}${MAGENTA}----------------------------------------------------------------------${NC}"
        echo -e "${BOLD}Select an MP Harmony Agent operation:${NC}\n"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Launch Interactive Chat CLI with MP Harmony Agent (${BOLD}${GREEN}Terminal Console${NC})"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Launch Voice Chat CLI with MP Harmony Agent (${BOLD}${GREEN}Terminal Console${NC})"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Start MP Harmony Voice Bridge / Server (${BOLD}${GREEN}Background Daemon${NC}) [:11435]"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Start MP Harmony Voice Bridge in ${BOLD}${YELLOW}New Terminal Window${NC} (Live Logs)"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Stop Running MP Harmony Agent / Server"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Restart MP Harmony Agent / Server"
        echo -e "  ${BOLD}${CYAN} 7)${NC} View Archived Audio Responses & Transcripts (${AUDIO_DIR})"
        echo -e "  ${BOLD}${CYAN} 8)${NC} View Server Log File (${LOG_FILE})"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Return to Previous Menu\n"
        read -r -p "Enter choice [1-9, or q to return]: " h_choice

        case "$h_choice" in
            1)
                launch_chat_cli
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            2)
                launch_voice_chat_cli
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            3)
                start_harmony_bg
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            4)
                start_harmony_window
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            5)
                stop_harmony
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            6)
                restart_harmony
                echo ""
                read -r -p "Press Enter to continue..."
                ;;
            7)
                view_audio_responses
                ;;
            8)
                view_logs
                ;;
            9|[qQ])
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
    voice|voice-chat|talk|voice-talk)
        shift
        launch_voice_chat_cli "$@"
        ;;
    chat|cli|run|interactive)
        shift
        launch_chat_cli "$@"
        ;;
    start|serve|bg)
        start_harmony_bg
        ;;
    start-window|window|terminal)
        start_harmony_window
        ;;
    stop)
        stop_harmony
        ;;
    restart)
        restart_harmony
        ;;
    status)
        show_status
        ;;
    audio|recordings|responses)
        view_audio_responses
        ;;
    logs)
        view_logs
        ;;
    "")
        interactive_menu
        ;;
    *)
        echo "Usage: $(basename "$0") {chat|voice|start|start-window|stop|restart|status|audio|logs}"
        exit 1
        ;;
esac
