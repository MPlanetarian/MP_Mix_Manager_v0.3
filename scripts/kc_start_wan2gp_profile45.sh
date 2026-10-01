#!/usr/bin/env bash
# ==============================================================================
# KDE Connect Remote Command: Start WAN2GP AI Video Server (Profile 4.5)
# Mix Archive Manager -> Menu 56 -> Option 2:
# (2) Start in Profile 4.5 (Low VRAM / 14B Models Offload) [New Tab/Window]
# ==============================================================================
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export PATH="$HOME/.local/bin:$PATH"

# Resolve codebase directory
CODEBASE_DIR="/var/home/mplanetarian/MP_Mix_Manager_v0.3"
if [ ! -f "$CODEBASE_DIR/wan2gp.sh" ]; then
    for _c in \
        "$HOME/MP_Mix_Manager_v0.3" \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.1" \
        "$HOME/MP_Mix_Manager_v0.1" \
        "$HOME/Documents/BASH_SCRIPTS"; do
        if [ -f "$_c/wan2gp.sh" ]; then
            CODEBASE_DIR="$_c"
            break
        fi
    done
fi
WAN2GP_SCRIPT="$CODEBASE_DIR/wan2gp.sh"

# Check if WAN2GP is already running
wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
if [ -n "$wgp_pids" ]; then
    notify-send -a "KDE Connect" -i "dialog-warning" "WAN2GP Server" "WAN2GP is already running (PID: ${wgp_pids% }). Stop it first if you wish to restart." 2>/dev/null || true
    exit 0
fi

notify-send -a "KDE Connect" -i "utilities-terminal" "WAN2GP Server" "Launching WAN2GP in Profile 4.5 (Low VRAM / 14B Models Offload)..." 2>/dev/null || true

TITLE="WAN2GP (Profile 4.5)"
CMD="bash \"$WAN2GP_SCRIPT\" 4.5; echo ''; echo 'WAN2GP finished. Press [Enter] to exit...'; read -r"

qdbus_bin=""
if command -v qdbus-qt6 >/dev/null 2>&1; then
    qdbus_bin="qdbus-qt6"
elif command -v qdbus >/dev/null 2>&1; then
    qdbus_bin="qdbus"
fi

launched=false
if [ -n "$qdbus_bin" ]; then
    k_svc="${KONSOLE_DBUS_SERVICE:-}"
    k_win="${KONSOLE_DBUS_WINDOW:-}"
    if [ -z "$k_svc" ]; then
        k_svc=$("$qdbus_bin" 2>/dev/null | grep -m1 -E "org\.kde\.konsole-[0-9]+" || true)
    fi
    if [ -n "$k_svc" ]; then
        if [ -z "$k_win" ] || ! "$qdbus_bin" "$k_svc" "$k_win" org.kde.konsole.Window.sessionCount >/dev/null 2>&1; then
            for candidate_win in "/Windows/1" "/Windows/2" "/Windows/3"; do
                if "$qdbus_bin" "$k_svc" "$candidate_win" org.kde.konsole.Window.sessionCount >/dev/null 2>&1; then
                    k_win="$candidate_win"
                    break
                fi
            done
        fi
        if [ -n "$k_win" ]; then
            session_id=$("$qdbus_bin" "$k_svc" "$k_win" org.kde.konsole.Window.newSession "" "$CODEBASE_DIR" 2>/dev/null || true)
            if [ -n "$session_id" ] && [ "$session_id" -gt 0 ] 2>/dev/null; then
                "$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.setTitle 1 "$TITLE" 2>/dev/null || true
                "$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.runCommand "$CMD" 2>/dev/null || true
                launched=true
            fi
        fi
    fi
fi

if [ "$launched" = false ]; then
    if command -v konsole >/dev/null 2>&1; then
        konsole --new-tab -p tabtitle="$TITLE" --workdir "$CODEBASE_DIR" -e bash -c "$CMD" &
    elif command -v xdg-terminal-exec >/dev/null 2>&1; then
        nohup xdg-terminal-exec bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v gnome-terminal >/dev/null 2>&1; then
        nohup gnome-terminal --title="$TITLE" -- bash -c "$CMD" >/dev/null 2>&1 &
    elif command -v xterm >/dev/null 2>&1; then
        nohup xterm -T "$TITLE" -e bash -c "$CMD" >/dev/null 2>&1 &
    fi
fi
