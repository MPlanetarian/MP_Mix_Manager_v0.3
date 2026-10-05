#!/usr/bin/env bash

# Auto-upgrade to modern Bash on macOS if running under ancient system Bash 3.2
if [ "$(uname -s)" = "Darwin" ] && [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    if [ -x "/opt/homebrew/bin/bash" ]; then
        exec /opt/homebrew/bin/bash "$0" "$@"
    elif [ -x "/usr/local/bin/bash" ]; then
        exec /usr/local/bin/bash "$0" "$@"
    fi
fi

# Colors for terminal styling & Theme Engine
set_theme_colors() {
    local theme_name="${1:-dreamworlds}"
    NC='\033[0m'
    BOLD='\033[1m'
    DIM='\033[2m'
    
    case "$theme_name" in
        dreamworlds|mplanetarian_dreamworlds|mplanetarian|default)
            # MPlanetarian Dreamworlds [Default]
            # Based on the Sweet / Nice KDE Plasma Palette (No Green - Neon Aesthetic)
            RED='\033[38;2;237;37;78m'       # Sweet Neon Red / Coral (#ed254e)
            GREEN='\033[38;2;0;229;255m'     # Sweet Bright Aqua Cyan (#00e5ff) - Sweet theme accent
            YELLOW='\033[38;2;255;170;0m'    # Sweet Electric Amber / Gold (#ffaa00)
            BLUE='\033[38;2;155;89;182m'     # Soft Sweet Lavender (#9b59b6)
            MAGENTA='\033[38;2;247;37;133m'  # Sweet Neon Hot Pink (#f72585)
            CYAN='\033[38;2;0;193;228m'      # Sweet Electric Cyan (#00c1e4)
            CURRENT_THEME="dreamworlds"
            ;;
        dracula)
            RED='\033[38;5;212m'     # Dracula Coral Pink / Red
            GREEN='\033[38;5;84m'    # Dracula Neon Green
            YELLOW='\033[38;5;228m'  # Dracula Pale Gold
            BLUE='\033[38;5;62m'     # Dracula Lavender Blue
            MAGENTA='\033[38;5;141m' # Dracula Purple
            CYAN='\033[38;5;117m'    # Dracula Sky Cyan
            CURRENT_THEME="dracula"
            ;;
        nord)
            RED='\033[38;5;167m'     # Nord Aurora Red
            GREEN='\033[38;5;108m'   # Nord Aurora Green / Sage
            YELLOW='\033[38;5;221m'  # Nord Aurora Yellow
            BLUE='\033[38;5;110m'    # Nord Frost Slate Blue
            MAGENTA='\033[38;5;139m' # Nord Aurora Purple
            CYAN='\033[38;5;117m'    # Nord Frost Polar Cyan
            CURRENT_THEME="nord"
            ;;
        matrix)
            RED='\033[38;5;124m'     # Dark Terminal Crimson
            GREEN='\033[38;5;46m'    # Pure Phosphor Green
            YELLOW='\033[38;5;190m'  # Electric Yellow-Green
            BLUE='\033[38;5;29m'     # Deep Matrix Green
            MAGENTA='\033[38;5;35m'  # Forest Emerald
            CYAN='\033[38;5;120m'    # Light Phosphor Mint
            CURRENT_THEME="matrix"
            ;;
        solarized)
            RED='\033[38;5;166m'     # Solarized Red
            GREEN='\033[38;5;64m'    # Solarized Green
            YELLOW='\033[38;5;136m'  # Solarized Yellow
            BLUE='\033[38;5;33m'     # Solarized Blue
            MAGENTA='\033[38;5;125m' # Solarized Magenta
            CYAN='\033[38;5;37m'     # Solarized Cyan
            CURRENT_THEME="solarized"
            ;;
        tokyo)
            RED='\033[38;5;203m'     # Tokyo Red/Coral
            GREEN='\033[38;5;114m'   # Tokyo Sage Green
            YELLOW='\033[38;5;222m'  # Tokyo Warm Sand
            BLUE='\033[38;5;111m'    # Tokyo Soft Blue
            MAGENTA='\033[38;5;176m' # Tokyo Neon Purple
            CYAN='\033[38;5;73m'     # Tokyo Cyan
            CURRENT_THEME="tokyo"
            ;;
        monokai)
            RED='\033[38;5;197m'     # Monokai Pink/Red
            GREEN='\033[38;5;148m'   # Monokai Lime Green
            YELLOW='\033[38;5;220m'  # Monokai Gold Yellow
            BLUE='\033[38;5;141m'    # Monokai Purple Blue
            MAGENTA='\033[38;5;208m' # Monokai Bright Orange
            CYAN='\033[38;5;81m'     # Monokai Bright Blue/Cyan
            CURRENT_THEME="monokai"
            ;;
        gruvbox)
            RED='\033[38;5;167m'     # Gruvbox Rust Red
            GREEN='\033[38;5;142m'   # Gruvbox Olive Green
            YELLOW='\033[38;5;214m'  # Gruvbox Warm Yellow
            BLUE='\033[38;5;109m'    # Gruvbox Slate Blue
            MAGENTA='\033[38;5;175m' # Gruvbox Dusty Rose
            CYAN='\033[38;5;108m'    # Gruvbox Aqua
            CURRENT_THEME="gruvbox"
            ;;
        emerald)
            RED='\033[38;5;204m'     # Soft Coral
            GREEN='\033[38;5;48m'    # Pure Spring Emerald
            YELLOW='\033[38;5;221m'  # Gold Amber
            BLUE='\033[38;5;31m'     # Deep Ocean
            MAGENTA='\033[38;5;78m'  # Light Seafoam
            CYAN='\033[38;5;86m'     # Mint Cyan
            CURRENT_THEME="emerald"
            ;;
        classic)
            RED='\033[0;31m'
            GREEN='\033[0;32m'
            YELLOW='\033[0;33m'
            BLUE='\033[0;34m'
            MAGENTA='\033[0;35m'
            CYAN='\033[0;36m'
            CURRENT_THEME="classic"
            ;;
        cyberpunk|*)
            RED='\033[38;5;196m'     # Cyberpunk Neon Red
            GREEN='\033[38;5;48m'    # Cyberpunk Acid Green
            YELLOW='\033[38;5;226m'  # Cyberpunk High Voltage Yellow
            BLUE='\033[38;5;45m'     # Cyberpunk Deep Cyan/Blue
            MAGENTA='\033[38;5;198m' # Cyberpunk Hot Pink
            CYAN='\033[38;5;51m'     # Cyberpunk Electric Cyan
            CURRENT_THEME="cyberpunk"
            ;;
    esac
}

# UI Sound Effects player
play_sound_effect() {
    local sound_type="${1:-storage}"
    local sound_file=""
    
    if [ "$sound_type" = "dreamworlds" ] || [ "$sound_type" = "theme" ]; then
        for cand in \
            "/usr/share/sounds/Oxygen-Sys-Special.ogg" \
            "/usr/share/sounds/oxygen/stereo/dialog-special.ogg" \
            "/usr/share/sounds/ocean/stereo/theme-demo.oga" \
            "/usr/share/sounds/ocean/stereo/desktop-login.oga" \
            "/usr/share/sounds/freedesktop/stereo/service-login.oga"; do
            if [ -f "$cand" ]; then sound_file="$cand"; break; fi
        done
    elif [ "$sound_type" = "storage" ]; then
        for cand in \
            "/usr/share/sounds/ocean/stereo/device-added.oga" \
            "/usr/share/sounds/freedesktop/stereo/device-added.oga" \
            "/usr/share/sounds/Oxygen-Sys-App-Positive.ogg" \
            "/usr/share/sounds/ocean/stereo/completion-success.oga"; do
            if [ -f "$cand" ]; then sound_file="$cand"; break; fi
        done
    fi
    
    if [ -n "$sound_file" ]; then
        if command -v pw-play >/dev/null 2>&1; then
            pw-play "$sound_file" >/dev/null 2>&1 &
        elif command -v paplay >/dev/null 2>&1; then
            paplay "$sound_file" >/dev/null 2>&1 &
        elif command -v canberra-gtk-play >/dev/null 2>&1; then
            canberra-gtk-play -f "$sound_file" >/dev/null 2>&1 &
        elif command -v aplay >/dev/null 2>&1; then
            aplay -q "$sound_file" >/dev/null 2>&1 &
        fi
    fi
}

show_dreamworlds_ascii_banner() {
    local animate="${1:-false}"
    if [ "$CURRENT_THEME" = "dreamworlds" ]; then
        local anim_script="$SCRIPT_DIR/scripts/render_ascii_animation.py"
        [ ! -f "$anim_script" ] && anim_script="$SCRIPT_DIR/render_ascii_animation.py"
        if [ -f "$anim_script" ]; then
            if [ "$animate" = "true" ]; then
                python3 "$anim_script" --animate 2>/dev/null || python3 "$anim_script" 2>/dev/null
            else
                python3 "$anim_script" 2>/dev/null
            fi
        fi
    fi
}

# Key reader for interactive navigation
read_nav_key() {
    local k=""
    local rest=""
    IFS= read -rsn1 k || return 1
    if [[ "$k" == $'\x1b' || "$k" == $'\e' ]]; then
        IFS= read -rsn4 -t 0.05 rest || true
        case "$rest" in
            "[A"|"OA") echo "UP" ;;
            "[B"|"OB") echo "DOWN" ;;
            "[C"|"OC") echo "RIGHT" ;;
            "[D"|"OD") echo "LEFT" ;;
            "[5~")     echo "PAGE_UP" ;;
            "[6~")     echo "PAGE_DOWN" ;;
            "[H"|"[1~") echo "HOME" ;;
            "[F"|"[4~") echo "END" ;;
            *)         echo "ESC" ;;
        esac
    elif [[ -z "$k" || "$k" == $'\n' || "$k" == $'\r' ]]; then
        echo "ENTER"
    elif [[ "$k" == $'\x7f' || "$k" == $'\x08' ]]; then
        echo "BACKSPACE"
    else
        echo "CHAR:$k"
    fi
}

# Interactive Submenu Runner
run_interactive_submenu() {
    local menu_title="$1"
    local menu_header="$2"
    local -n _opts_ref="$3"
    local cur_idx="${4:-0}"
    local total_opts="${#_opts_ref[@]}"
    
    if [ "$total_opts" -eq 0 ]; then
        REPLY="0"
        return 0
    fi
    
    # Ensure starting cur_idx is on a selectable item
    local start_attempts=0
    while [ "$start_attempts" -lt "$total_opts" ]; do
        IFS='|' read -r k_chk _ _ <<< "${_opts_ref[$cur_idx]}"
        if [ "$k_chk" != "SECTION" ] && [ "$k_chk" != "SEP" ]; then
            break
        fi
        cur_idx=$(( (cur_idx + 1) % total_opts ))
        ((start_attempts++))
    done
    
    # Non-interactive fallback
    if [ ! -t 0 ]; then
        clear
        if [ -n "$menu_title" ]; then
            echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
            echo -e "${BOLD}${MAGENTA}       ${menu_title}${NC}"
            echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        fi
        [ -n "$menu_header" ] && echo -e "$menu_header"
        for opt_entry in "${_opts_ref[@]}"; do
            IFS='|' read -r o_key o_label o_extra <<< "$opt_entry"
            if [ "$o_key" = "SECTION" ]; then
                echo -e "\n  ${BOLD}${BLUE}─── [ ${o_label} ] ─────────${NC}"
                continue
            elif [ "$o_key" = "SEP" ]; then
                echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────────${NC}"
                continue
            fi
            echo -e "  ${BOLD}${CYAN}${o_key})${NC} ${o_label} ${DIM}${o_extra}${NC}"
        done
        echo ""
        read -r -p "Enter choice: " REPLY
        return 0
    fi
    
    # Clear screen once on entry and hide cursor
    clear
    printf '\033[?25l'
    
    local typed_buffer=""
    local view_top=0

    while true; do
        local term_lines term_cols
        term_lines=$(tput lines 2>/dev/null || echo 40)
        term_cols=$(tput cols 2>/dev/null || echo 100)
        [ -z "$term_lines" ] || [ "$term_lines" -lt 15 ] && term_lines=40
        [ -z "$term_cols" ] || [ "$term_cols" -lt 40 ] && term_cols=100

        # Calculate fixed overhead lines
        local overhead=4 # prompt, bottom divider, selection status, blank
        if [ -n "$menu_title" ]; then
            overhead=$((overhead + 4)) # box title is 3 lines + margin
        fi
        if [ -n "$menu_header" ]; then
            local header_count
            header_count=$(printf "%b\n" "$menu_header" | wc -l)
            overhead=$((overhead + header_count))
        fi

        # Compute maximum visible options
        local max_visible=$(( term_lines - overhead ))
        if [ "$max_visible" -lt 8 ]; then
            max_visible=8
        fi

        if [ "$max_visible" -ge "$total_opts" ]; then
            max_visible=$total_opts
            view_top=0
        else
            # Adjust view_top so cur_idx is always inside [view_top, view_top + max_visible - 1]
            if [ "$cur_idx" -lt "$view_top" ]; then
                view_top="$cur_idx"
            elif [ "$cur_idx" -ge $(( view_top + max_visible )) ]; then
                view_top=$(( cur_idx - max_visible + 1 ))
            fi
            # Bound checks
            if [ "$view_top" -gt $(( total_opts - max_visible )) ]; then
                view_top=$(( total_opts - max_visible ))
            fi
            if [ "$view_top" -lt 0 ]; then
                view_top=0
            fi
        fi

        local view_end=$(( view_top + max_visible - 1 ))
        [ "$view_end" -ge "$total_opts" ] && view_end=$(( total_opts - 1 ))

        # Move cursor to home position without resetting scrollback (prevents scrollbar flick)
        printf '\033[H'

        if [ -n "$menu_title" ]; then
            echo -e "${BOLD}${MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮\033[K${NC}"
            printf "${BOLD}${MAGENTA}│ %-72s │\033[K${NC}\n" "  ${menu_title}"
            echo -e "${BOLD}${MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯\033[K${NC}"
            if [ -n "$menu_header" ]; then
                while IFS= read -r h_line; do
                    echo -e "${h_line}\033[K"
                done <<< "$menu_header"
            fi
            echo -e "  ${DIM}${BLUE}Use [↑/↓] Arrow Keys to navigate, [Enter] to select, [Esc] to return immediately\033[K${NC}"
        else
            if [ -n "$menu_header" ]; then
                while IFS= read -r h_line; do
                    echo -e "${h_line}\033[K"
                done <<< "$menu_header"
            fi
            echo -e "  ${DIM}${BLUE}Use [↑/↓] Arrow Keys to navigate, [Enter] to select, [Esc] or 'q' to exit\033[K${NC}"
        fi

        # Scroll indicator top
        if [ "$view_top" -gt 0 ]; then
            echo -e "  ${BOLD}${YELLOW}▲  (${view_top} more option$([ "$view_top" -gt 1 ] && echo "s") above - press ↑ to scroll)\033[K${NC}"
        else
            echo -e "\033[K"
        fi

        # Render visible items
        for (( idx=view_top; idx<=view_end; idx++ )); do
            IFS='|' read -r o_key o_label o_extra <<< "${_opts_ref[$idx]}"
            if [ "$o_key" = "SECTION" ]; then
                echo -e "  ${BOLD}${BLUE}─── [ ${o_label} ] ─────────\033[K${NC}"
                continue
            elif [ "$o_key" = "SEP" ]; then
                echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────────\033[K${NC}"
                continue
            fi
            local prefix="    "
            local key_display="${BOLD}${CYAN}[$(printf "%2s" "$o_key")]${NC}"
            local label_display="${o_label}"
            local extra_display=""
            [ -n "$o_extra" ] && extra_display="${DIM}${o_extra}${NC}"
            
            if [ "$idx" -eq "$cur_idx" ]; then
                prefix="${BOLD}${MAGENTA} ▶ ❯${NC}"
                echo -e "${prefix} ${BOLD}${YELLOW}[$(printf "%2s" "$o_key")]${NC} ${BOLD}${GREEN}${label_display}${NC} ${extra_display}\033[K"
            else
                echo -e "${prefix} ${key_display} ${label_display} ${extra_display}\033[K"
            fi
        done

        # Scroll indicator bottom
        local remaining_below=$(( total_opts - 1 - view_end ))
        if [ "$remaining_below" -gt 0 ]; then
            echo -e "  ${BOLD}${YELLOW}▼  (${remaining_below} more option$([ "$remaining_below" -gt 1 ] && echo "s") below - press ↓ to scroll)\033[K${NC}"
        else
            echo -e "\033[K"
        fi

        echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────────\033[K${NC}"
        IFS='|' read -r cur_key cur_lbl cur_ext <<< "${_opts_ref[$cur_idx]}"
        if [ -n "$typed_buffer" ]; then
            echo -e "  ${BOLD}${CYAN}Selection:${NC} ${BOLD}${YELLOW}${typed_buffer}${NC} ▏ ${DIM}(Press Enter to confirm, Esc to return/exit)\033[K${NC}"
        else
            echo -e "  ${BOLD}${CYAN}Selection:${NC} ${DIM}[Option ${cur_key}: ${cur_lbl}]${NC} ▏ ${DIM}[↑/↓ to Navigate, Enter to Select, Esc to Return/Exit]\033[K${NC}"
        fi
        
        # Clear any lines below our output in case window size changed
        printf '\033[J'
        
        local key_action
        key_action=$(read_nav_key)
        
        case "$key_action" in
            UP)
                local hops=0
                while [ "$hops" -lt "$total_opts" ]; do
                    cur_idx=$(( (cur_idx - 1 + total_opts) % total_opts ))
                    IFS='|' read -r k_chk _ _ <<< "${_opts_ref[$cur_idx]}"
                    [ "$k_chk" != "SECTION" ] && [ "$k_chk" != "SEP" ] && break
                    ((hops++))
                done
                typed_buffer=""
                ;;
            PAGE_UP)
                local hops=0
                local target_step=$(( max_visible > 5 ? max_visible - 2 : 5 ))
                while [ "$hops" -lt "$target_step" ]; do
                    cur_idx=$(( (cur_idx - 1 + total_opts) % total_opts ))
                    IFS='|' read -r k_chk _ _ <<< "${_opts_ref[$cur_idx]}"
                    if [ "$k_chk" != "SECTION" ] && [ "$k_chk" != "SEP" ]; then
                        ((hops++))
                    fi
                done
                typed_buffer=""
                ;;
            DOWN)
                local hops=0
                while [ "$hops" -lt "$total_opts" ]; do
                    cur_idx=$(( (cur_idx + 1) % total_opts ))
                    IFS='|' read -r k_chk _ _ <<< "${_opts_ref[$cur_idx]}"
                    [ "$k_chk" != "SECTION" ] && [ "$k_chk" != "SEP" ] && break
                    ((hops++))
                done
                typed_buffer=""
                ;;
            PAGE_DOWN)
                local hops=0
                local target_step=$(( max_visible > 5 ? max_visible - 2 : 5 ))
                while [ "$hops" -lt "$target_step" ]; do
                    cur_idx=$(( (cur_idx + 1) % total_opts ))
                    IFS='|' read -r k_chk _ _ <<< "${_opts_ref[$cur_idx]}"
                    if [ "$k_chk" != "SECTION" ] && [ "$k_chk" != "SEP" ]; then
                        ((hops++))
                    fi
                done
                typed_buffer=""
                ;;
            HOME)
                cur_idx=0
                while [ "$cur_idx" -lt "$total_opts" ]; do
                    IFS='|' read -r k_chk _ _ <<< "${_opts_ref[$cur_idx]}"
                    [ "$k_chk" != "SECTION" ] && [ "$k_chk" != "SEP" ] && break
                    ((cur_idx++))
                done
                typed_buffer=""
                ;;
            END)
                cur_idx=$(( total_opts - 1 ))
                while [ "$cur_idx" -ge 0 ]; do
                    IFS='|' read -r k_chk _ _ <<< "${_opts_ref[$cur_idx]}"
                    [ "$k_chk" != "SECTION" ] && [ "$k_chk" != "SEP" ] && break
                    ((cur_idx--))
                done
                typed_buffer=""
                ;;
            ENTER)
                printf '\033[?25h'
                clear
                if [ -n "$typed_buffer" ]; then
                    REPLY="$typed_buffer"
                else
                    IFS='|' read -r sel_key _ _ <<< "${_opts_ref[$cur_idx]}"
                    REPLY="$sel_key"
                fi
                return 0
                ;;
            ESC)
                printf '\033[?25h'
                clear
                REPLY="ESC"
                return 0
                ;;
            BACKSPACE)
                typed_buffer="${typed_buffer%?}"
                ;;
            CHAR:*)
                local ch="${key_action#CHAR:}"
                typed_buffer+="$ch"
                local m_idx=0
                for opt_entry in "${_opts_ref[@]}"; do
                    IFS='|' read -r o_key _ _ <<< "$opt_entry"
                    if [ "$o_key" = "$typed_buffer" ]; then
                        cur_idx=$m_idx
                        break
                    fi
                    ((m_idx++))
                done
                if [ "$typed_buffer" = "q" ] || [ "$typed_buffer" = "Q" ] || [ "$typed_buffer" = "b" ] || [ "$typed_buffer" = "B" ]; then
                    printf '\033[?25h'
                    clear
                    REPLY="$typed_buffer"
                    return 0
                fi
                ;;
        esac
    done
}

load_theme() {
    local theme_file="$HOME/.config/mix-manager/theme"
    if [ -f "$theme_file" ]; then
        local saved_theme
        saved_theme="$(tr -d ' \t\n\r' < "$theme_file" 2>/dev/null)"
        if [ -n "$saved_theme" ]; then
            set_theme_colors "$saved_theme"
            return
        fi
    fi
    set_theme_colors "dreamworlds"
}

save_theme() {
    local new_theme="$1"
    mkdir -p "$HOME/.config/mix-manager" 2>/dev/null
    echo "$new_theme" > "$HOME/.config/mix-manager/theme" 2>/dev/null
    set_theme_colors "$new_theme"
    if [ "$new_theme" = "dreamworlds" ] || [ "$new_theme" = "mplanetarian_dreamworlds" ] || [ "$new_theme" = "default" ]; then
        play_sound_effect "dreamworlds"
    fi
}

load_theme

# Ctrl+C at the main menu exits. Monitors that catch INT restore this afterwards.
exit_mix_manager() {
    printf '\033[?25h' 2>/dev/null || true
    echo ""
    echo -e "${BOLD}${GREEN}You are exiting the Mix Archive Manager.${NC}"
    echo ""
    exit 0
}
trap 'exit_mix_manager' INT

MANAGER_START_EPOCH="$(date +%s)"
printf '\033]0;%s\007' "Mix Archive Manager" 2>/dev/null || true
# Resolve symlinks so SCRIPT_DIR correctly points to codebase directory
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
if [ ! -d "$SCRIPT_DIR/scripts" ]; then
    for _c in \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.3" \
        "$HOME/MP_Mix_Manager_v0.3" \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.3" \
        "$HOME/MP_Mix_Manager_v0.3" \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.1" \
        "$HOME/MP_Mix_Manager_v0.1"; do
        if [ -d "$_c/scripts" ]; then
            SCRIPT_DIR="$_c"
            break
        fi
    done
fi
unset _RESOLVED_SRC _RESOLVED_DIR _c
export PATH="$SCRIPT_DIR/bin:$SCRIPT_DIR:$HOME/.local/bin:$HOME/bin:/usr/local/bin:/usr/local/sbin:/opt/homebrew/bin:$PATH"

# OS Platform Detection (Linux, macOS, Windows 10/11, FreeBSD)
OS_TYPE="linux"
case "$(uname -s)" in
    Darwin*)
        OS_TYPE="macos"
        ;;
    CYGWIN*|MINGW*|MSYS*)
        OS_TYPE="windows"
        ;;
    FreeBSD*)
        OS_TYPE="freebsd"
        ;;
    Linux*)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            OS_TYPE="wsl"
        else
            OS_TYPE="linux"
        fi
        ;;
    *)
        OS_TYPE="linux"
        ;;
esac

# Auto-upgrade to modern Homebrew Bash on macOS if running under ancient Bash 3.2
if [ "$OS_TYPE" = "macos" ] && [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    if [ -x "/opt/homebrew/bin/bash" ]; then
        exec /opt/homebrew/bin/bash "$0" "$@"
    elif [ -x "/usr/local/bin/bash" ]; then
        exec /usr/local/bin/bash "$0" "$@"
    fi
fi

# Cross-Platform Open Path (File/Directory opener for Linux, macOS, and Windows)
open_path() {
    local target="$1"
    [ -z "$target" ] && return 0
    if [ "$OS_TYPE" = "macos" ]; then
        open "$target" >/dev/null 2>&1 &
    elif [ "$OS_TYPE" = "windows" ]; then
        if command -v cygpath >/dev/null 2>&1; then
            local win_p
            win_p="$(cygpath -w "$target" 2>/dev/null || echo "$target")"
            cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
        else
            explorer.exe "$target" >/dev/null 2>&1 &
        fi
    elif [ "$OS_TYPE" = "wsl" ]; then
        if command -v wslview >/dev/null 2>&1; then
            wslview "$target" >/dev/null 2>&1 &
        elif command -v explorer.exe >/dev/null 2>&1; then
            explorer.exe "$(wslpath -w "$target" 2>/dev/null || echo "$target")" >/dev/null 2>&1 &
        fi
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$target" >/dev/null 2>&1 &
    fi
}

# Ensure KWin rules for Borderless & Keep-Above Windows exist on Bazzite / KDE Plasma
ensure_bazzite_borderless_kwin_rule() {
    [ ! -d "$HOME/.config" ] && return 0
    local rc_path="$HOME/.config/kwinrulesrc"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import configparser, os, uuid, subprocess

rc_path = os.path.expanduser('~/.config/kwinrulesrc')
if not os.path.exists(rc_path):
    os.makedirs(os.path.dirname(rc_path), exist_ok=True)
    with open(rc_path, 'w') as f:
        f.write('[General]\ncount=0\nrules=\n')

cp = configparser.ConfigParser()
cp.read(rc_path)

# Rule 1: Mix Tracklist Viewer (Borderless & Keep Above on top of manager)
rule_tl_desc = 'Mix Tracklist Viewer (Borderless)'
tl_found = False
for sec in cp.sections():
    if cp.has_option(sec, 'description') and cp.get(sec, 'description') == rule_tl_desc:
        tl_found = True
        cp.set(sec, 'above', 'true')
        cp.set(sec, 'aboverule', '2')
        break

if not tl_found:
    new_uuid = str(uuid.uuid4())
    cp.add_section(new_uuid)
    cp.set(new_uuid, 'description', rule_tl_desc)
    cp.set(new_uuid, 'wmclass', 'konsole')
    cp.set(new_uuid, 'wmclassmatch', '1')
    cp.set(new_uuid, 'title', 'Mix Tracklist Viewer')
    cp.set(new_uuid, 'titlematch', '1')
    cp.set(new_uuid, 'types', '1')
    cp.set(new_uuid, 'noborder', 'true')
    cp.set(new_uuid, 'noborderrule', '2')
    cp.set(new_uuid, 'above', 'true')
    cp.set(new_uuid, 'aboverule', '2')

    if not cp.has_section('General'):
        cp.add_section('General')
    count = int(cp.get('General', 'count', fallback='0')) + 1
    cp.set('General', 'count', str(count))
    existing_rules = cp.get('General', 'rules', fallback='')
    rules_list = [r.strip() for r in existing_rules.split(',') if r.strip()]
    rules_list.append(new_uuid)
    cp.set('General', 'rules', ','.join(rules_list))

# Rule 2: Mix Cover Art Viewer (Keep Above on top of manager)
rule_cov_desc = 'Mix Cover Art Viewer (Keep Above)'
cov_found = False
for sec in cp.sections():
    if cp.has_option(sec, 'description') and cp.get(sec, 'description') == rule_cov_desc:
        cov_found = True
        break

if not cov_found:
    new_uuid2 = str(uuid.uuid4())
    cp.add_section(new_uuid2)
    cp.set(new_uuid2, 'description', rule_cov_desc)
    cp.set(new_uuid2, 'wmclass', 'gwenview')
    cp.set(new_uuid2, 'wmclassmatch', '2')
    cp.set(new_uuid2, 'title', 'Cover')
    cp.set(new_uuid2, 'titlematch', '2')
    cp.set(new_uuid2, 'types', '1')
    cp.set(new_uuid2, 'above', 'true')
    cp.set(new_uuid2, 'aboverule', '2')

    if not cp.has_section('General'):
        cp.add_section('General')
    count = int(cp.get('General', 'count', fallback='0')) + 1
    cp.set('General', 'count', str(count))
    existing_rules = cp.get('General', 'rules', fallback='')
    rules_list = [r.strip() for r in existing_rules.split(',') if r.strip()]
    rules_list.append(new_uuid2)
    cp.set('General', 'rules', ','.join(rules_list))

with open(rc_path, 'w') as f:
    cp.write(f)

if os.path.exists('/usr/bin/qdbus'):
    subprocess.run(['/usr/bin/qdbus', 'org.kde.KWin', '/KWin', 'reconfigure'], capture_output=True)
" 2>/dev/null || true
    fi
}

get_connected_displays_count() {
    if command -v kscreen-doctor >/dev/null 2>&1; then
        local cnt
        cnt=$(kscreen-doctor -o 2>/dev/null | grep -c "Output: ")
        [ -n "$cnt" ] && [ "$cnt" -gt 0 ] && echo "$cnt" && return 0
    fi
    if command -v xrandr >/dev/null 2>&1; then
        local cnt
        cnt=$(xrandr --listmonitors 2>/dev/null | awk '/Monitors:/{print $2}')
        [ -n "$cnt" ] && [ "$cnt" -gt 0 ] && echo "$cnt" && return 0
    fi
    echo 1
}

ensure_manager_fullscreen() {
    printf '\033]0;%s\007' "Mix Archive Manager" 2>/dev/null || true
    # 1. Terminal escape sequences for maximize / fullscreen (supported by VTE and modern terms)
    printf '\033[10;2t' 2>/dev/null || true

    # 2. X11 / Wayland wmctrl command to ensure fullscreen
    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -r "Mix Archive Manager" -b add,fullscreen 2>/dev/null || true
        wmctrl -r :ACTIVE: -b add,fullscreen 2>/dev/null || true
    fi
}

align_mix_windows_on_screen() {
    ensure_manager_fullscreen
    local align_sh="$SCRIPT_DIR/scripts/align_mix_windows.py"
    [ ! -f "$align_sh" ] && align_sh="$HOME/MP_Mix_Manager_v0.3/scripts/align_mix_windows.py"
    [ ! -f "$align_sh" ] && align_sh="/var/home/mplanetarian/MP_Mix_Manager_v0.3/scripts/align_mix_windows.py"
    [ ! -f "$align_sh" ] && align_sh="$HOME/MP_Mix_Manager_v0.3/scripts/align_mix_windows.py"
    [ ! -f "$align_sh" ] && align_sh="/var/home/mplanetarian/MP_Mix_Manager_v0.3/scripts/align_mix_windows.py"
    [ ! -f "$align_sh" ] && align_sh="$HOME/Documents/BASH_SCRIPTS/scripts/align_mix_windows.py"
    [ ! -f "$align_sh" ] && align_sh="$PWD/scripts/align_mix_windows.py"
    if [ -f "$align_sh" ] && command -v python3 >/dev/null 2>&1; then
        local mgr_pid="$$"
        local parent_pid="$PPID"
        (python3 "$align_sh" --mgr-pid "$mgr_pid" --parent-pid "$parent_pid" "$@" >/dev/null 2>&1 || true) &
        disown 2>/dev/null || true
    fi
}

# Cross-Platform Open Cover Art in Dedicated Viewer (Centered on top of manager)
open_cover_art_window() {
    local target="$1"
    [ -z "$target" ] || [ ! -f "$target" ] && return 1

    local cover_title="Mix Cover Art Viewer"

    # 1. Linux & FreeBSD
    if [ "$OS_TYPE" = "linux" ] || [ "$OS_TYPE" = "freebsd" ]; then
        ensure_bazzite_borderless_kwin_rule
        if command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "org.kde.gwenview"; then
            nohup flatpak run org.kde.gwenview "$target" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            align_mix_windows_on_screen --expect-cover
            return 0
        elif command -v gwenview >/dev/null 2>&1; then
            nohup gwenview "$target" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            align_mix_windows_on_screen --expect-cover
            return 0
        elif command -v loupe >/dev/null 2>&1; then
            nohup loupe "$target" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            align_mix_windows_on_screen --expect-cover
            return 0
        elif command -v eog >/dev/null 2>&1; then
            nohup eog "$target" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            align_mix_windows_on_screen --expect-cover
            return 0
        elif command -v feh >/dev/null 2>&1; then
            nohup feh --title "$cover_title" --geometry 700x700 "$target" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            align_mix_windows_on_screen --expect-cover
            return 0
        elif command -v xdg-open >/dev/null 2>&1; then
            nohup xdg-open "$target" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            align_mix_windows_on_screen --expect-cover
            return 0
        fi
    fi

    # 2. macOS
    if [ "$OS_TYPE" = "macos" ]; then
        open -a Preview "$target" >/dev/null 2>&1 &
        align_mix_windows_on_screen --expect-cover
        return 0
    fi

    # 3. Windows / WSL
    if [ "$OS_TYPE" = "windows" ]; then
        cmd.exe /c start "" "$target" >/dev/null 2>&1 &
        return 0
    elif [ "$OS_TYPE" = "wsl" ]; then
        if command -v wslview >/dev/null 2>&1; then
            wslview "$target" >/dev/null 2>&1 &
        elif command -v explorer.exe >/dev/null 2>&1; then
            explorer.exe "$(wslpath -w "$target" 2>/dev/null || echo "$target")" >/dev/null 2>&1 &
        fi
        return 0
    fi

    open_path "$target"
}

# Cross-Platform Open Tracklist in the Default Console (Borderless on Bazzite Linux)
open_tracklist_window() {
    local target="$1"
    [ -z "$target" ] || [ ! -f "$target" ] && return 1

    local viewer_sh="$SCRIPT_DIR/scripts/view_tracklist_console.sh"
    [ ! -f "$viewer_sh" ] && viewer_sh="$PWD/scripts/view_tracklist_console.sh"
    [ ! -f "$viewer_sh" ] && viewer_sh="$SCRIPT_DIR/view_tracklist_console.sh"
    [ ! -f "$viewer_sh" ] && viewer_sh="$PWD/view_tracklist_console.sh"

    local tl_title="Mix Tracklist Viewer"
    local viewer="${TRACKLIST_VIEWER:-console}"

    # If custom external viewer explicitly configured and not console/auto
    if [ "$viewer" != "console" ] && [ "$viewer" != "auto" ] && [ -n "$viewer" ]; then
        if command -v "$viewer" >/dev/null 2>&1; then
            "$viewer" "$target" >/dev/null 2>&1 &
            return 0
        fi
    fi

    # 1. Linux & FreeBSD (Default Console with Borderless Mode on Bazzite / KDE)
    if [ "$OS_TYPE" = "linux" ] || [ "$OS_TYPE" = "freebsd" ]; then
        ensure_bazzite_borderless_kwin_rule

        # Default Console on Bazzite & KDE: Konsole (Frameless & Borderless)
        if command -v konsole >/dev/null 2>&1; then
            konsole --hide-menubar --hide-tabbar --separate \
                --qwindowtitle "$tl_title" \
                -p tabtitle="$tl_title" \
                -p TerminalMargin=0 \
                --geometry 95x35 \
                -e bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            (sleep 0.15; command -v xprop >/dev/null 2>&1 && xprop -name "$tl_title" -f _MOTIF_WM_HINTS 32c -set _MOTIF_WM_HINTS "0x2, 0x0, 0x0, 0x0, 0x0" 2>/dev/null || true) &
            return 0
        elif command -v gnome-terminal >/dev/null 2>&1; then
            gnome-terminal --title="$tl_title" --hide-menubar -- bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            return 0
        elif command -v xfce4-terminal >/dev/null 2>&1; then
            xfce4-terminal --title="$tl_title" --hide-menubar --hide-borders -e "bash '$viewer_sh' '$target'" >/dev/null 2>&1 &
            return 0
        elif command -v alacritty >/dev/null 2>&1; then
            alacritty --title "$tl_title" -e bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            return 0
        elif command -v foot >/dev/null 2>&1; then
            foot -T "$tl_title" bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            return 0
        elif command -v xterm >/dev/null 2>&1; then
            xterm -title "$tl_title" -bd 0 -geometry 95x35 -e bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            return 0
        fi
    fi

    # 2. macOS (Default Console: Terminal.app)
    if [ "$OS_TYPE" = "macos" ]; then
        local escaped_viewer escaped_target
        escaped_viewer=$(printf '%s' "$viewer_sh" | sed 's/"/\\"/g')
        escaped_target=$(printf '%s' "$target" | sed 's/"/\\"/g')
        osascript -e "tell application \"Terminal\" to do script \"bash \\\"$escaped_viewer\\\" \\\"$escaped_target\\\"\"" >/dev/null 2>&1 &
        return 0
    fi

    # 3. Windows / WSL (Default Console: Windows Terminal wt.exe or cmd.exe)
    if [ "$OS_TYPE" = "windows" ]; then
        if command -v wt.exe >/dev/null 2>&1; then
            wt.exe -w new --title "$tl_title" bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            return 0
        elif command -v cmd.exe >/dev/null 2>&1; then
            cmd.exe /c start "$tl_title" bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            return 0
        fi
    elif [ "$OS_TYPE" = "wsl" ]; then
        if command -v wt.exe >/dev/null 2>&1; then
            wt.exe -w 0 nt --title "$tl_title" wsl.exe -e bash "$viewer_sh" "$target" >/dev/null 2>&1 &
            return 0
        fi
    fi

    # Fallback to open_path
    open_path "$target"
}

# Cross-Platform Mix Tracklist Finder
find_mix_tracklist() {
    local mix_file="$1"
    [ -z "$mix_file" ] && return 1

    local mix_basename
    mix_basename=$(basename "$mix_file")
    local mix_stem="${mix_basename%.*}"
    local mix_dir
    mix_dir="$(dirname "$mix_file")"

    local ep_num=""
    if [[ "$mix_stem" =~ [_\ -]([0-9]{2,3})([_\ -]|$) ]]; then
        ep_num="${BASH_REMATCH[1]}"
    fi

    local date_str=""
    if [[ "$mix_stem" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        date_str="${BASH_REMATCH[1]}"
    fi

    local candidate_dirs=(
        "$mix_dir"
        "$OUTPUT_DIR"
        "${MIX_ARCHIVE_DIR:-$PWD}/FLAC_CONVERTED_OUTPUTS"
        "${MIX_ARCHIVE_DIR:-$PWD}"
        "$PWD/FLAC_CONVERTED_OUTPUTS"
        "$PWD"
        "${MIX_ARCHIVE_DIR:-$PWD}/TEMP"
    )
    if command -v get_all_flac_output_dirs >/dev/null 2>&1; then
        while IFS= read -r f_dir; do
            [ -n "$f_dir" ] && candidate_dirs+=("$f_dir")
        done < <(get_all_flac_output_dirs)
    fi
    if command -v get_all_mix_archive_dirs >/dev/null 2>&1; then
        while IFS= read -r a_dir; do
            [ -n "$a_dir" ] && candidate_dirs+=("$a_dir")
        done < <(get_all_mix_archive_dirs)
    fi

    # 1. Exact stem match: <dir>/<mix_stem>.txt or <mix_file_without_ext>.txt
    if [ -f "${mix_file%.*}.txt" ]; then
        echo "${mix_file%.*}.txt"
        return 0
    fi
    for d in "${candidate_dirs[@]}"; do
        if [ -f "$d/${mix_stem}.txt" ]; then
            echo "$d/${mix_stem}.txt"
            return 0
        fi
    done

    # 2. Episode number match
    if [ -n "$ep_num" ]; then
        shopt -s nullglob nocaseglob
        for d in "${candidate_dirs[@]}"; do
            for match in "$d"/*"${ep_num}"*.txt; do
                if [ -f "$match" ]; then
                    shopt -u nullglob nocaseglob
                    echo "$match"
                    return 0
                fi
            done
        done
        shopt -u nullglob nocaseglob
    fi

    # 3. Date match
    if [ -n "$date_str" ]; then
        shopt -s nullglob nocaseglob
        for d in "${candidate_dirs[@]}"; do
            for match in "$d"/*"${date_str}"*.txt; do
                if [ -f "$match" ]; then
                    shopt -u nullglob nocaseglob
                    echo "$match"
                    return 0
                fi
            done
        done
        shopt -u nullglob nocaseglob
    fi

    # 4. Keyword fuzzy match from stem
    local clean_kw
    clean_kw=$(echo "$mix_stem" | sed -E 's/MPlanetarian|Stream|of|Frequency|Part|WMI|Mix//gi' | tr '_-' ' ' | awk '{print $1}')
    if [ -n "$clean_kw" ] && [ "${#clean_kw}" -ge 4 ]; then
        shopt -s nullglob nocaseglob
        for d in "${candidate_dirs[@]}"; do
            for match in "$d"/*"${clean_kw}"*.txt; do
                if [ -f "$match" ]; then
                    shopt -u nullglob nocaseglob
                    echo "$match"
                    return 0
                fi
            done
        done
        shopt -u nullglob nocaseglob
    fi

    # 5. Archive-wide deep search (up to 3 levels) for episode or stem
    if [ -d "${MIX_ARCHIVE_DIR:-$PWD}" ]; then
        if [ -n "$ep_num" ]; then
            local deep_match
            deep_match=$(find "${MIX_ARCHIVE_DIR:-$PWD}" -maxdepth 3 -type f -name "*${ep_num}*.txt" ! -path "*/SPEK_OUTPUTS/*" 2>/dev/null | head -1)
            if [ -n "$deep_match" ] && [ -f "$deep_match" ]; then
                echo "$deep_match"
                return 0
            fi
        fi
        if [ -n "$date_str" ]; then
            local deep_match_date
            deep_match_date=$(find "${MIX_ARCHIVE_DIR:-$PWD}" -maxdepth 3 -type f -name "*${date_str}*.txt" ! -path "*/SPEK_OUTPUTS/*" 2>/dev/null | head -1)
            if [ -n "$deep_match_date" ] && [ -f "$deep_match_date" ]; then
                echo "$deep_match_date"
                return 0
            fi
        fi
    fi

    # 6. Generate fallback summary manifest if none found
    local tmp_tl="/tmp/Tracklist_${mix_stem}.txt"
    {
        echo "=================================================="
        echo "STREAM OF FREQUENCY - MIX TRACKLIST"
        echo "=================================================="
        echo "Mix File:       $mix_basename"
        [ -n "$ep_num" ] && echo "Episode:        Episode $ep_num"
        [ -n "$date_str" ] && echo "Recorded Date:  $date_str"
        echo "Directory:      $mix_dir"
        echo "Detected on:    $(date '+%Y-%m-%d %H:%M:%S')"
        echo "--------------------------------------------------"
        echo "A standalone .txt tracklist file was not yet found"
        echo "directly on disk for this mix file."
        echo ""
        echo "To auto-generate complete tracklists from your Traktor"
        echo "history or audio metadata, launch Option 16 in the"
        echo "Mix Archive Manager."
        echo "=================================================="
    } > "$tmp_tl" 2>/dev/null
    if [ -f "$tmp_tl" ]; then
        echo "$tmp_tl"
        return 0
    fi

    return 1
}

# Cross-Platform Mix Cover Art Finder
find_mix_cover() {
    local mix_file="$1"
    [ -z "$mix_file" ] && return 1

    local mix_basename
    mix_basename=$(basename "$mix_file")
    local mix_stem="${mix_basename%.*}"
    local mix_dir
    mix_dir="$(dirname "$mix_file")"

    local ep_num=""
    if [[ "$mix_stem" =~ [_\ -]([0-9]{2,3})([_\ -]|$) ]]; then
        ep_num="${BASH_REMATCH[1]}"
    fi

    local date_str=""
    if [[ "$mix_stem" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        date_str="${BASH_REMATCH[1]}"
    fi

    local candidate_dirs=(
        "$mix_dir"
        "$mix_dir/COVERS"
        "${MIX_ARCHIVE_DIR:-$PWD}/COVERS"
        "$PWD/COVERS"
        "${MIX_ARCHIVE_DIR:-$PWD}"
        "$PWD"
        "$SCRIPT_DIR/COVERS"
        "$SCRIPT_DIR"
    )
    if command -v get_all_mix_archive_dirs >/dev/null 2>&1; then
        while IFS= read -r a_dir; do
            [ -n "$a_dir" ] && candidate_dirs+=("$a_dir" "$a_dir/COVERS")
        done < <(get_all_mix_archive_dirs)
    fi

    # 1. Exact match with same stem
    for d in "${candidate_dirs[@]}"; do
        for ext in png jpg jpeg webp; do
            if [ -f "$d/${mix_stem}.${ext}" ]; then
                echo "$d/${mix_stem}.${ext}"
                return 0
            fi
        done
    done

    # 2. Episode number in COVERS
    if [ -n "$ep_num" ]; then
        shopt -s nullglob nocaseglob
        for d in "${candidate_dirs[@]}"; do
            for match in "$d"/*"${ep_num}"*.png "$d"/*"${ep_num}"*.jpg; do
                if [ -f "$match" ]; then
                    shopt -u nullglob nocaseglob
                    echo "$match"
                    return 0
                fi
            done
        done
        shopt -u nullglob nocaseglob
    fi

    # 3. Date in COVERS
    if [ -n "$date_str" ]; then
        shopt -s nullglob nocaseglob
        for d in "${candidate_dirs[@]}"; do
            for match in "$d"/*"${date_str}"*.png "$d"/*"${date_str}"*.jpg; do
                if [ -f "$match" ]; then
                    shopt -u nullglob nocaseglob
                    echo "$match"
                    return 0
                fi
            done
        done
        shopt -u nullglob nocaseglob
    fi

    # 4. Archive-wide deep search for episode cover art
    if [ -d "${MIX_ARCHIVE_DIR:-$PWD}" ]; then
        if [ -n "$ep_num" ]; then
            local deep_cov
            deep_cov=$(find "${MIX_ARCHIVE_DIR:-$PWD}" -maxdepth 3 -type f \( -name "*${ep_num}*.png" -o -name "*${ep_num}*.jpg" \) ! -path "*/SPEK_OUTPUTS/*" 2>/dev/null | head -1)
            if [ -n "$deep_cov" ] && [ -f "$deep_cov" ]; then
                echo "$deep_cov"
                return 0
            fi
        fi
    fi

    # 5. Master Cover.png or Cover_4K.png
    for d in "${candidate_dirs[@]}"; do
        if [ -f "$d/Cover_4K.png" ]; then echo "$d/Cover_4K.png"; return 0; fi
        if [ -f "$d/Cover.png" ]; then echo "$d/Cover.png"; return 0; fi
        if [ -f "$d/Cover.jpg" ]; then echo "$d/Cover.jpg"; return 0; fi
        if [ -f "$d/001.png" ]; then echo "$d/001.png"; return 0; fi
    done

    if [ -f "$SCRIPT_DIR/assets/Cover.png" ]; then
        echo "$SCRIPT_DIR/assets/Cover.png"
        return 0
    fi

    return 1
}

# Spectrogram that belongs to this mix. A different mix's Spek file is not a match.
find_mix_spek() {
    local mix_file="$1"
    [ -n "$mix_file" ] || return 1

    local mix_stem
    mix_stem="$(basename "${mix_file%.*}")"
    [ -n "$mix_stem" ] || return 1

    local -a dirs=()
    add_spek_dir() {
        local cand="$1"
        local resolved seen
        [ -n "$cand" ] && [ -d "$cand" ] || return 0
        resolved="$(cd "$cand" 2>/dev/null && pwd -P)" || return 0
        for seen in "${dirs[@]}"; do
            [ "$seen" = "$resolved" ] && return 0
        done
        dirs+=("$resolved")
    }

    add_spek_dir "$(dirname "$mix_file")"
    add_spek_dir "${SPEK_DIR:-}"
    if [ -n "${MIX_ARCHIVE_DIR:-}" ]; then
        add_spek_dir "${MIX_ARCHIVE_DIR%/}/SPEK_OUTPUTS"
        if [ -n "${SPEK_DIR:-}" ] && [[ "$SPEK_DIR" != /* ]]; then
            add_spek_dir "${MIX_ARCHIVE_DIR%/}/${SPEK_DIR}"
        fi
    fi
    add_spek_dir "${PWD}/SPEK_OUTPUTS"
    if command -v get_all_mix_archive_dirs >/dev/null 2>&1; then
        local archive_dir
        while IFS= read -r archive_dir; do
            [ -z "$archive_dir" ] && continue
            add_spek_dir "${archive_dir%/}/SPEK_OUTPUTS"
            add_spek_dir "$(dirname "$archive_dir")/SPEK_OUTPUTS"
        done < <(get_all_mix_archive_dirs)
    fi

    local spek_dir spek_name
    for spek_dir in "${dirs[@]}"; do
        for spek_name in \
            "${mix_stem}_spectrogram.png" \
            "${mix_stem}.spek.png" \
            "${mix_stem}.spek" \
            "${mix_stem}_spectrogram.jpg"
        do
            if [ -s "$spek_dir/$spek_name" ]; then
                echo "$spek_dir/$spek_name"
                return 0
            fi
        done
    done
    return 1
}

# First load opens the Spek for the newest finished mix. With no converted mix, it does nothing.
open_startup_mix_spek() {
    local saved_mode="${AUTO_PLAY_MIX_SELECTION:-latest}"
    local selected_mix=""
    AUTO_PLAY_MIX_SELECTION="latest"
    selected_mix="$(select_startup_mix)" || true
    AUTO_PLAY_MIX_SELECTION="$saved_mode"

    if [ -z "$selected_mix" ] || [ ! -s "$selected_mix" ]; then
        return 0
    fi

    if ! is_internet_connected && is_remote_or_cloud_path "$selected_mix"; then
        return 0
    fi

    local spek=""
    spek="$(find_mix_spek "$selected_mix" 2>/dev/null || true)"
    if [ -z "$spek" ] || [ ! -s "$spek" ]; then
        return 0
    fi

    STARTUP_SPEK_NOTICE="Spectrogram: $(basename "$spek")"
    open_cover_art_window "$spek" || open_path "$spek"
}

# Cross-Platform Clipboard Copy (Linux wl-copy/xclip, macOS pbcopy, Windows clip.exe)
copy_to_clipboard() {
    local text="$1"
    if [ "$OS_TYPE" = "macos" ] && command -v pbcopy >/dev/null 2>&1; then
        printf "%s" "$text" | pbcopy
        return 0
    elif [ "$OS_TYPE" = "windows" ] && command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe
        return 0
    elif [ "$OS_TYPE" = "wsl" ] && command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe
        return 0
    elif command -v wl-copy >/dev/null 2>&1; then
        printf "%s" "$text" | wl-copy
        return 0
    elif command -v xclip >/dev/null 2>&1; then
        printf "%s" "$text" | xclip -selection clipboard
        return 0
    elif command -v pbcopy >/dev/null 2>&1; then
        printf "%s" "$text" | pbcopy
        return 0
    elif command -v clip.exe >/dev/null 2>&1; then
        printf "%s" "$text" | clip.exe
        return 0
    fi
    return 1
}

# Cross-Platform Launch Command in New Terminal Tab or Window
launch_in_terminal() {
    local title="$1"
    local cmd="$2"
    local mode="${3:-tab}" # "tab" or "window"

    if [ "$OS_TYPE" = "macos" ]; then
        if [ "${TERM_PROGRAM:-}" = "iTerm.app" ]; then
            osascript - "$cmd" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
    set cmdText to item 1 of argv
    tell application "iTerm"
        activate
        if (count of windows) = 0 then
            create window with default profile
        end if
        tell current window
            create tab with default profile
            tell current session of current tab
                write text cmdText
            end tell
        end tell
    end tell
end run
APPLESCRIPT
            return 0
        fi

        if [ "$mode" = "window" ]; then
            osascript - "$cmd" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
    tell application "Terminal"
        activate
        do script (item 1 of argv)
    end tell
end run
APPLESCRIPT
            return 0
        fi

        # New tab in the Terminal window that is already in front. The new-tab
        # button is used because this Mac's Shell > New Tab action opens a
        # separate window. A fresh login tab is the only place the command is sent.
        local launch_result=""
        launch_result="$(osascript - "$cmd" <<'APPLESCRIPT'
on run argv
    set cmdText to item 1 of argv
    tell application "System Events"
        tell process "Terminal"
            set frontmost to true
            key code 53
        end tell
    end tell
    delay 0.1
    set beforeCount to 0
    tell application "System Events"
        tell process "Terminal"
            repeat with w in windows
                try
                    set beforeCount to beforeCount + (count of radio buttons of tab group 1 of w)
                end try
            end repeat
        end tell
    end tell
    tell application "Terminal"
        set oldIds to {}
        repeat with w in windows
            try
                set end of oldIds to (id of w as integer) as string
            end try
        end repeat
    end tell
    ignoring application responses
        tell application "System Events"
            tell process "Terminal"
                set frontmost to true
                click button 1 of tab group 1 of window 1
            end tell
        end tell
    end ignoring
    delay 0.7
    set afterCount to 0
    tell application "System Events"
        tell process "Terminal"
            repeat with w in windows
                try
                    set afterCount to afterCount + (count of radio buttons of tab group 1 of w)
                end try
            end repeat
        end tell
    end tell
    tell application "Terminal"
        set targetWin to missing value
        repeat with w in windows
            try
                set wid to (id of w as integer) as string
                set known to false
                repeat with oldId in oldIds
                    if (oldId as string) is equal to wid then set known to true
                end repeat
                if not known then
                    set hist to history of selected tab of w
                    set nm to name of w
                    if (count of hist) < 900 and hist contains "Last login" and nm does not contain "grok" and nm does not contain "ffmpeg" and nm does not contain "Mix Archive" then
                        set targetWin to w
                        exit repeat
                    end if
                end if
            end try
        end repeat
        if targetWin is not missing value then
            do script cmdText in selected tab of targetWin
            if afterCount > beforeCount then
                return "tab"
            end if
            return "window"
        end if
        do script cmdText
        return "fallback"
    end tell
end run
APPLESCRIPT
)" || launch_result="fail"
        case "$launch_result" in
            tab*|window*|fallback*) return 0 ;;
        esac
        osascript - "$cmd" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
    tell application "Terminal" to do script (item 1 of argv)
end run
APPLESCRIPT
        return 0
    elif [ "$OS_TYPE" = "windows" ]; then
        if command -v wt.exe >/dev/null 2>&1; then
            if [ "$mode" = "tab" ]; then
                wt.exe new-tab --title "$title" bash -c "$cmd" >/dev/null 2>&1 &
            else
                wt.exe -w new --title "$title" bash -c "$cmd" >/dev/null 2>&1 &
            fi
            return 0
        elif command -v start >/dev/null 2>&1; then
            start "$title" bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v cmd.exe >/dev/null 2>&1; then
            cmd.exe /c start "$title" bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    elif [ "$OS_TYPE" = "wsl" ]; then
        if command -v wt.exe >/dev/null 2>&1; then
            wt.exe -w 0 nt --title "$title" wsl.exe -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    fi

    # Linux native terminal emulators
    if [ "$mode" = "window" ]; then
        if command -v konsole >/dev/null 2>&1; then
            nohup konsole --separate --workdir "$PWD" -p tabtitle="$title" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xdg-terminal-exec >/dev/null 2>&1; then
            nohup xdg-terminal-exec bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v gnome-terminal >/dev/null 2>&1; then
            nohup gnome-terminal --title="$title" -- bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xterm >/dev/null 2>&1; then
            nohup xterm -T "$title" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    else
        # default to tab or preferred terminal
        # 1. Native Konsole DBus tab injection (instant and zero-failure on KDE Plasma)
        local qdbus_bin=""
        if command -v qdbus-qt6 >/dev/null 2>&1; then
            qdbus_bin="qdbus-qt6"
        elif command -v qdbus >/dev/null 2>&1; then
            qdbus_bin="qdbus"
        fi

        if [ -n "$qdbus_bin" ]; then
            local k_svc="${KONSOLE_DBUS_SERVICE:-}"
            local k_win="${KONSOLE_DBUS_WINDOW:-}"

            # If not in env, search DBus for any active Konsole process
            if [ -z "$k_svc" ]; then
                k_svc=$("$qdbus_bin" 2>/dev/null | grep -m1 -E "org\.kde\.konsole-[0-9]+" || true)
            fi
            k_svc=$(echo "$k_svc" | xargs)

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
                    local session_id
                    session_id=$("$qdbus_bin" "$k_svc" "$k_win" org.kde.konsole.Window.newSession "" "$PWD" 2>/dev/null || true)
                    session_id=$(echo "$session_id" | xargs)
                    if [ -n "$session_id" ] && [ "$session_id" -gt 0 ] 2>/dev/null; then
                        "$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.setTitle 1 "$title" 2>/dev/null || true

                        # Wait briefly for bash to finish MOTD / .bashrc initialization so input is not flushed
                        for ((_w=0; _w<25; _w++)); do
                            local disp
                            disp=$("$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.getAllDisplayedText 2>/dev/null || true)
                            if [[ "$disp" =~ (\$) || "$disp" =~ (\#) || "$disp" =~ (@) ]]; then
                                break
                            fi
                            sleep 0.08
                        done

                        if "$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.runCommand "$cmd" >/dev/null 2>&1; then
                            # Verify command was accepted; if shell is still idle at prompt after 0.25s, retry once
                            sleep 0.25
                            local check_disp
                            check_disp=$("$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.getAllDisplayedText 2>/dev/null || true)
                            if [[ "$check_disp" =~ \$\ $ ]] || [[ "$check_disp" =~ @.*:\~.*\$ ]]; then
                                "$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.runCommand "$cmd" >/dev/null 2>&1 || true
                            fi
                            return 0
                        else
                            # DBus runCommand was rejected (e.g. security-sensitive DBus API disabled in Konsole settings)
                            # Close the newly created empty session so it doesn't leave an orphaned shell tab
                            local child_pid
                            child_pid=$("$qdbus_bin" "$k_svc" "/Sessions/$session_id" org.kde.konsole.Session.processId 2>/dev/null || true)
                            [ -n "$child_pid" ] && [ "$child_pid" -gt 0 ] 2>/dev/null && kill -9 "$child_pid" 2>/dev/null || true
                        fi
                    fi
                fi
            fi
        fi

        if command -v konsole >/dev/null 2>&1; then
            nohup konsole --separate --workdir "$PWD" -p tabtitle="$title" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xdg-terminal-exec >/dev/null 2>&1; then
            nohup xdg-terminal-exec bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v gnome-terminal >/dev/null 2>&1; then
            nohup gnome-terminal --tab --title="$title" --working-directory="$PWD" -- bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        elif command -v xfce4-terminal >/dev/null 2>&1; then
            local xfce_cmd
            xfce_cmd="$(printf '%q' "$cmd")"
            nohup xfce4-terminal --tab --title="$title" --working-directory="$PWD" -e "bash -lc ${xfce_cmd}" >/dev/null 2>&1 &
            return 0
        elif command -v xterm >/dev/null 2>&1; then
            nohup xterm -T "$title" -e bash -c "$cmd" >/dev/null 2>&1 &
            return 0
        fi
    fi

    return 1
}

# Load optional user configuration
if [ -f "$SCRIPT_DIR/config.env" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/config.env"
elif [ -f "$HOME/.config/mix-manager/config.env" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.config/mix-manager/config.env"
fi

OUTPUT_DIR="${OUTPUT_DIR:-FLAC_CONVERTED_OUTPUTS}"
ARCHIVE_DIR="${ARCHIVE_DIR:-CONVERTED_WAV_FILES}"
MP3_OUTPUT_DIR="${MP3_OUTPUT_DIR:-MP3_CONVERTED_OUTPUTS}"
WAV_OUTPUT_DIR="${WAV_OUTPUT_DIR:-WAV_CONVERTED_OUTPUTS}"
MP4_OUTPUT_DIR="${MP4_OUTPUT_DIR:-MP4_CONVERTED_OUTPUTS}"
EXTRA_MIX_ARCHIVE_DIRS="${EXTRA_MIX_ARCHIVE_DIRS:-${MIX_ARCHIVE_DIRS:-}}"
export OUTPUT_DIR ARCHIVE_DIR MP3_OUTPUT_DIR WAV_OUTPUT_DIR MP4_OUTPUT_DIR EXTRA_MIX_ARCHIVE_DIRS

is_mix_archive_configured() {
    if [ "${MIX_ARCHIVE_CONFIGURED:-false}" = "true" ] && [ -n "${MIX_ARCHIVE_DIR:-}" ]; then
        return 0
    fi
    return 1
}

# Global in-memory caches for network and archive discovery
_LAST_INTERNET_CHECK=0
_CACHED_INTERNET_STATUS=""

is_internet_connected() {
    local now
    now=$(date +%s 2>/dev/null || echo 0)
    if [ $((now - _LAST_INTERNET_CHECK)) -lt 30 ] && [ -n "$_CACHED_INTERNET_STATUS" ]; then
        [ "$_CACHED_INTERNET_STATUS" = "online" ]
        return $?
    fi

    _LAST_INTERNET_CHECK="$now"
    # Quick check for default route (if no default route, definitely offline)
    if command -v ip >/dev/null 2>&1; then
        if ! ip route 2>/dev/null | grep -q "^default"; then
            _CACHED_INTERNET_STATUS="offline"
            return 1
        fi
    fi

    # Fast TCP probe to public DNS (no DNS lookup required)
    if timeout 0.35 bash -c 'cat < /dev/null > /dev/tcp/1.1.1.1/53' 2>/dev/null || \
       timeout 0.35 bash -c 'cat < /dev/null > /dev/tcp/8.8.8.8/53' 2>/dev/null; then
        _CACHED_INTERNET_STATUS="online"
        return 0
    fi

    _CACHED_INTERNET_STATUS="offline"
    return 1
}

is_remote_or_cloud_path() {
    local p="$1"
    [ -z "$p" ] && return 1
    case "$p" in
        *GoogleDrive*|*google-drive*|*rclone*|*Dropbox*|*dropbox*|*iCloud*|*icloud*|*OneDrive*|*onedrive*|*Nextcloud*|*nextcloud*)
            return 0
            ;;
    esac
    if [ -f /proc/mounts ]; then
        while read -r _ mpoint fstype _; do
            case "$fstype" in
                fuse.rclone|nfs|nfs4|cifs|smbfs|fuse.sshfs|davfs)
                    if [[ "$p" == "$mpoint"* ]]; then
                        return 0
                    fi
                    ;;
            esac
        done < /proc/mounts 2>/dev/null
    fi
    return 1
}

# Global in-memory caches for archive discovery
_CACHED_ALL_MIX_ARCHIVE_DIRS=()
_CACHED_ALL_FLAC_OUTPUT_DIRS=()
_CACHED_ALL_WAV_ARCHIVE_DIRS=()

clear_archive_dir_cache() {
    _CACHED_ALL_MIX_ARCHIVE_DIRS=()
    _CACHED_ALL_FLAC_OUTPUT_DIRS=()
    _CACHED_ALL_WAV_ARCHIVE_DIRS=()
}

# Helper: Get all configured mix archive directories
get_all_mix_archive_dirs() {
    if [ "${1:-}" != "--refresh" ] && [ ${#_CACHED_ALL_MIX_ARCHIVE_DIRS[@]} -gt 0 ]; then
        printf '%s\n' "${_CACHED_ALL_MIX_ARCHIVE_DIRS[@]}"
        return 0
    fi

    local dirs=()
    local seen=()

    # Primary archive directory
    local primary="${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}"
    if [ -n "$primary" ]; then
        local clean_p="${primary%/}"
        if is_internet_connected || ! is_remote_or_cloud_path "$clean_p"; then
            dirs+=("$clean_p")
            seen+=("$clean_p")
        fi
    fi

    # Extra archive directories (colon, comma, or newline separated)
    local raw_extras="${EXTRA_MIX_ARCHIVE_DIRS:-${MIX_ARCHIVE_DIRS:-}}"
    if [ -n "$raw_extras" ]; then
        local IFS_BACK="$IFS"
        IFS=':,;'
        for raw_entry in $raw_extras; do
            IFS="$IFS_BACK"
            local d
            d="${raw_entry#"${raw_entry%%[![:space:]]*}"}"
            d="${d%"${d##*[![:space:]]}"}"
            d="${d%\"}"
            d="${d#\"}"
            d="${d%\'}"
            d="${d#\'}"
            if [[ "$d" =~ ^~(/.*)?$ ]]; then
                d="${HOME}${d:1}"
            fi
            if [ -n "$d" ]; then
                local clean_d="${d%/}"
                if ! is_internet_connected && is_remote_or_cloud_path "$clean_d"; then
                    continue
                fi
                if [[ ! " ${seen[*]} " =~ " ${clean_d} " ]]; then
                    seen+=("$clean_d")
                    dirs+=("$clean_d")
                fi
            fi
            IFS=':,;'
        done
        IFS="$IFS_BACK"
    fi

    _CACHED_ALL_MIX_ARCHIVE_DIRS=("${dirs[@]}")
    printf '%s\n' "${dirs[@]}"
}

# Helper: Get all FLAC output directories across all configured archives
get_all_flac_output_dirs() {
    if [ "${1:-}" != "--refresh" ] && [ ${#_CACHED_ALL_FLAC_OUTPUT_DIRS[@]} -gt 0 ]; then
        printf '%s\n' "${_CACHED_ALL_FLAC_OUTPUT_DIRS[@]}"
        return 0
    fi

    local flac_dirs=()
    local seen=()

    # Active primary OUTPUT_DIR first
    if [ -n "${OUTPUT_DIR:-}" ] && [ -d "$OUTPUT_DIR" ]; then
        local clean_out="${OUTPUT_DIR%/}"
        flac_dirs+=("$clean_out")
        seen+=("$clean_out")
    fi

    while IFS= read -r adir; do
        [ -z "$adir" ] && continue
        local clean_a="${adir%/}"

        # 1. If adir is itself named FLAC_CONVERTED_OUTPUTS or ends with it
        if [[ "$clean_a" =~ FLAC_CONVERTED_OUTPUTS$ ]]; then
            if [ -d "$clean_a" ] && [[ ! " ${seen[*]} " =~ " ${clean_a} " ]]; then
                seen+=("$clean_a")
                flac_dirs+=("$clean_a")
            fi
        # 2. If adir has FLAC_CONVERTED_OUTPUTS subdirectory
        elif [ -d "$clean_a/FLAC_CONVERTED_OUTPUTS" ]; then
            local sub="$clean_a/FLAC_CONVERTED_OUTPUTS"
            if [[ ! " ${seen[*]} " =~ " ${sub} " ]]; then
                seen+=("$sub")
                flac_dirs+=("$sub")
            fi
        # 3. If adir directly contains .flac files (only if FLAC_CONVERTED_OUTPUTS subdirectory did not exist)
        elif [ -d "$clean_a" ]; then
            if [[ ! " ${seen[*]} " =~ " ${clean_a} " ]]; then
                local has_flac=0
                shopt -s nullglob nocaseglob
                local test_flacs=("$clean_a"/*.flac)
                shopt -u nullglob nocaseglob
                [ ${#test_flacs[@]} -gt 0 ] && has_flac=1
                if [ "$has_flac" -eq 1 ]; then
                    seen+=("$clean_a")
                    flac_dirs+=("$clean_a")
                fi
            fi
        fi
    done < <(get_all_mix_archive_dirs)

    _CACHED_ALL_FLAC_OUTPUT_DIRS=("${flac_dirs[@]}")
    printf '%s\n' "${flac_dirs[@]}"
}

# Helper: Get all converted WAV directories across all configured archives
get_all_wav_archive_dirs() {
    if [ "${1:-}" != "--refresh" ] && [ ${#_CACHED_ALL_WAV_ARCHIVE_DIRS[@]} -gt 0 ]; then
        printf '%s\n' "${_CACHED_ALL_WAV_ARCHIVE_DIRS[@]}"
        return 0
    fi

    local wav_dirs=()
    local seen=()

    if [ -n "${ARCHIVE_DIR:-}" ] && [ -d "$ARCHIVE_DIR" ]; then
        local clean_a="${ARCHIVE_DIR%/}"
        wav_dirs+=("$clean_a")
        seen+=("$clean_a")
    fi

    while IFS= read -r adir; do
        [ -z "$adir" ] && continue
        local clean_a="${adir%/}"
        if [[ "$clean_a" =~ CONVERTED_WAV_FILES$ ]]; then
            if [ -d "$clean_a" ] && [[ ! " ${seen[*]} " =~ " ${clean_a} " ]]; then
                seen+=("$clean_a")
                wav_dirs+=("$clean_a")
            fi
        elif [ -d "$clean_a/CONVERTED_WAV_FILES" ]; then
            local sub="$clean_a/CONVERTED_WAV_FILES"
            if [[ ! " ${seen[*]} " =~ " ${sub} " ]]; then
                seen+=("$sub")
                wav_dirs+=("$sub")
            fi
        fi
    done < <(get_all_mix_archive_dirs)

    _CACHED_ALL_WAV_ARCHIVE_DIRS=("${wav_dirs[@]}")
    printf '%s\n' "${wav_dirs[@]}"
}

# Determine target working archive directory
if is_mix_archive_configured && ! { ! is_internet_connected && is_remote_or_cloud_path "$MIX_ARCHIVE_DIR"; } && [ -d "$MIX_ARCHIVE_DIR" ]; then
    cd "$MIX_ARCHIVE_DIR" || exit 1
else
    # Fallback to Application Root Folder 'MIX_ARCHIVE'
    MIX_ARCHIVE_DIR="${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}"
    mkdir -p "$SCRIPT_DIR/MIX_ARCHIVE"/{FLAC_CONVERTED_OUTPUTS,CONVERTED_WAV_FILES,MP3_CONVERTED_OUTPUTS,WAV_CONVERTED_OUTPUTS,MP4_CONVERTED_OUTPUTS} 2>/dev/null || true
    if [ -d "$MIX_ARCHIVE_DIR" ]; then
        cd "$MIX_ARCHIVE_DIR" 2>/dev/null || cd "$SCRIPT_DIR/MIX_ARCHIVE" 2>/dev/null || cd "$SCRIPT_DIR" || exit 1
    else
        cd "$SCRIPT_DIR/MIX_ARCHIVE" 2>/dev/null || cd "$SCRIPT_DIR" || exit 1
    fi
fi

# Resolve relative storage paths to active archive folder
if [ -n "${MIX_ARCHIVE_DIR:-}" ] && ! { ! is_internet_connected && is_remote_or_cloud_path "$MIX_ARCHIVE_DIR"; } && [ -d "$MIX_ARCHIVE_DIR" ]; then
    if ! is_remote_or_cloud_path "$MIX_ARCHIVE_DIR"; then
        mkdir -p "$MIX_ARCHIVE_DIR"/{FLAC_CONVERTED_OUTPUTS,CONVERTED_WAV_FILES,MP3_CONVERTED_OUTPUTS,WAV_CONVERTED_OUTPUTS,MP4_CONVERTED_OUTPUTS} 2>/dev/null || true
    fi
    if [ ! -d "$OUTPUT_DIR" ] && [ -d "$MIX_ARCHIVE_DIR/$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$MIX_ARCHIVE_DIR/$OUTPUT_DIR"
    elif [ ! -d "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS"
    fi
    if [ ! -d "$ARCHIVE_DIR" ] && [ -d "$MIX_ARCHIVE_DIR/$ARCHIVE_DIR" ]; then
        ARCHIVE_DIR="$MIX_ARCHIVE_DIR/$ARCHIVE_DIR"
    elif [ ! -d "$ARCHIVE_DIR" ]; then
        ARCHIVE_DIR="$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES"
    fi
    if [ ! -d "$MP3_OUTPUT_DIR" ] && [ -d "$MIX_ARCHIVE_DIR/$MP3_OUTPUT_DIR" ]; then
        MP3_OUTPUT_DIR="$MIX_ARCHIVE_DIR/$MP3_OUTPUT_DIR"
    elif [ ! -d "$MP3_OUTPUT_DIR" ]; then
        MP3_OUTPUT_DIR="$MIX_ARCHIVE_DIR/MP3_CONVERTED_OUTPUTS"
    fi
    if [ ! -d "$WAV_OUTPUT_DIR" ] && [ -d "$MIX_ARCHIVE_DIR/$WAV_OUTPUT_DIR" ]; then
        WAV_OUTPUT_DIR="$MIX_ARCHIVE_DIR/$WAV_OUTPUT_DIR"
    elif [ ! -d "$WAV_OUTPUT_DIR" ]; then
        WAV_OUTPUT_DIR="$MIX_ARCHIVE_DIR/WAV_CONVERTED_OUTPUTS"
    fi
    if [ ! -d "$MP4_OUTPUT_DIR" ] && [ -d "$MIX_ARCHIVE_DIR/$MP4_OUTPUT_DIR" ]; then
        MP4_OUTPUT_DIR="$MIX_ARCHIVE_DIR/$MP4_OUTPUT_DIR"
    elif [ ! -d "$MP4_OUTPUT_DIR" ]; then
        MP4_OUTPUT_DIR="$MIX_ARCHIVE_DIR/MP4_CONVERTED_OUTPUTS"
    fi
    export OUTPUT_DIR ARCHIVE_DIR MP3_OUTPUT_DIR WAV_OUTPUT_DIR MP4_OUTPUT_DIR
fi

# Ensure PLAYLISTS_GENERATED exists in application root and all configured mix archive folders
ensure_playlists_generated_dirs() {
    mkdir -p "$SCRIPT_DIR/PLAYLISTS_GENERATED" 2>/dev/null || true
    local all_arch_dirs=()
    while IFS= read -r adir; do
        [ -n "$adir" ] && all_arch_dirs+=("$adir")
    done < <(get_all_mix_archive_dirs 2>/dev/null)
    for pdir in "${all_arch_dirs[@]}"; do
        # Never perform mkdir or file modifications on remote/cloud mounts
        if is_remote_or_cloud_path "$pdir"; then
            continue
        fi
        if [ -d "$pdir" ]; then
            [ -d "$pdir/PLAYLISTS_GENERATED" ] || mkdir -p "$pdir/PLAYLISTS_GENERATED" 2>/dev/null || true
            if [[ "$pdir" =~ (FLAC_CONVERTED_OUTPUTS|CONVERTED_WAV_FILES|MP3_CONVERTED_OUTPUTS)/?$ ]]; then
                local pparent
                pparent="$(dirname "$pdir")"
                if [ -d "$pparent" ] && [ ! -d "$pparent/PLAYLISTS_GENERATED" ]; then
                    mkdir -p "$pparent/PLAYLISTS_GENERATED" 2>/dev/null || true
                fi
            fi
        fi
    done
}
ensure_playlists_generated_dirs

# Default Audio Player and Startup Autoplay Preferences
DEFAULT_AUDIO_PLAYER="${DEFAULT_AUDIO_PLAYER:-audacious}"
AUTO_PLAY_ON_STARTUP="${AUTO_PLAY_ON_STARTUP:-true}"
AUTO_SHOW_COVER_ON_STARTUP="${AUTO_SHOW_COVER_ON_STARTUP:-false}"
AUTO_SHOW_TRACKLIST_ON_STARTUP="${AUTO_SHOW_TRACKLIST_ON_STARTUP:-true}"
TRACKLIST_VIEWER="${TRACKLIST_VIEWER:-console}"
AUTO_PLAY_MIX_SELECTION="${AUTO_PLAY_MIX_SELECTION:-latest}"
DEFAULT_VIDEO_PLAYER="${DEFAULT_VIDEO_PLAYER:-vlc}"
AUTO_PLAY_YOUTUBE_ON_STARTUP="${AUTO_PLAY_YOUTUBE_ON_STARTUP:-false}"
STARTUP_YOUTUBE_URL="${STARTUP_YOUTUBE_URL:-}"
WEATHER_ENABLED="${WEATHER_ENABLED:-true}"
WEATHER_LOCATION="${WEATHER_LOCATION:-Swansea, UK}"
STARTUP_AUTOPLAY_EXECUTED=0
STARTUP_AUTOPLAY_NOTICE=""
STARTUP_SPEK_NOTICE=""

save_config_setting() {
    local key="$1"
    local val="$2"
    local cfg_file="$SCRIPT_DIR/config.env"
    [ ! -f "$cfg_file" ] && cfg_file="$PWD/config.env"

    python3 -c "
import sys, re
key = sys.argv[1]
val = sys.argv[2]
path = sys.argv[3]
try:
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    pat = rf'^[ \t]*{re.escape(key)}=.*$'
    if re.search(pat, c, re.MULTILINE):
        new_c = re.sub(pat, f'{key}=\"{val}\"', c, flags=re.MULTILINE)
    else:
        new_c = c.rstrip() + f'\n{key}=\"{val}\"\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_c)
except Exception:
    pass
" "$key" "$val" "$cfg_file" 2>/dev/null || true

    if [ -f "$HOME/.config/mix-manager/config.env" ]; then
        python3 -c "
import sys, re
key = sys.argv[1]
val = sys.argv[2]
path = sys.argv[3]
try:
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    pat = rf'^[ \t]*{re.escape(key)}=.*$'
    if re.search(pat, c, re.MULTILINE):
        new_c = re.sub(pat, f'{key}=\"{val}\"', c, flags=re.MULTILINE)
    else:
        new_c = c.rstrip() + f'\n{key}=\"{val}\"\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(new_c)
except Exception:
    pass
" "$key" "$val" "$HOME/.config/mix-manager/config.env" 2>/dev/null || true
    fi
}

run_sub_script() {
    local script_name="$1"
    shift
    local bash_bin="${BASH:-bash}"
    if [ -x "./$script_name" ]; then
        "./$script_name" "$@"
    elif [ -f "./$script_name" ]; then
        "$bash_bin" "./$script_name" "$@"
    elif [ -x "$SCRIPT_DIR/$script_name" ]; then
        "$SCRIPT_DIR/$script_name" "$@"
    elif [ -f "$SCRIPT_DIR/$script_name" ]; then
        "$bash_bin" "$SCRIPT_DIR/$script_name" "$@"
    elif [ -x "$SCRIPT_DIR/scripts/$script_name" ]; then
        "$SCRIPT_DIR/scripts/$script_name" "$@"
    elif [ -f "$SCRIPT_DIR/scripts/$script_name" ]; then
        "$bash_bin" "$SCRIPT_DIR/scripts/$script_name" "$@"
    elif command -v "$script_name" >/dev/null 2>&1; then
        "$script_name" "$@"
    else
        echo -e "${RED}Error: Script '$script_name' not found in $(pwd) or $SCRIPT_DIR!${NC}"
        return 1
    fi
}

is_mix_in_strawberry_playlist() {
    local mix_file="$1"
    [ -z "$mix_file" ] && return 1

    python3 -c "
import sqlite3, os, sys, urllib.parse

filepath = sys.argv[1]
fname = os.path.basename(filepath)
stem = os.path.splitext(fname)[0]
enc_fname = urllib.parse.quote(fname)

db_candidates = [
    os.path.expanduser('~/.local/share/strawberry/strawberry/strawberry.db'),
    os.path.expanduser('~/.var/app/org.strawberrymusicplayer.strawberry/data/strawberry/strawberry/strawberry.db'),
    os.path.expanduser('~/Library/Application Support/Strawberry/strawberry/strawberry.db'),
]

found = False
for db in db_candidates:
    if os.path.isfile(db):
        try:
            conn = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
            cur = conn.cursor()
            query = '''SELECT count(*) FROM playlist_items WHERE url LIKE ? OR url LIKE ? OR url LIKE ? OR title = ? OR title LIKE ?'''
            cur.execute(query, (f'%{fname}%', f'%{enc_fname}%', f'%{filepath}%', stem, f'%{stem}%'))
            cnt = cur.fetchone()[0]
            conn.close()
            if cnt > 0:
                found = True
                break
        except Exception:
            pass

sys.exit(0 if found else 1)
" "$mix_file" 2>/dev/null
}

is_mix_in_audacious_playlist() {
    local mix_file="$1"
    [ -z "$mix_file" ] && return 1
    local bname
    bname="$(basename "$mix_file")"
    local stem="${bname%.*}"
    if command -v audtool >/dev/null 2>&1; then
        if audtool playlist-display 2>/dev/null | grep -i -F "$stem" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

get_audacious_track_info() {
    AUDACIOUS_RUNNING=0
    AUDACIOUS_STATE=""
    AUDACIOUS_TITLE=""
    AUDACIOUS_ARTIST=""
    AUDACIOUS_ALBUM=""
    AUDACIOUS_RAW_PATH=""
    AUDACIOUS_RESOLVED_PATH=""
    AUDACIOUS_FILE_EXISTS=0
    AUDACIOUS_FILE_SIZE=""
    AUDACIOUS_POSITION=0
    AUDACIOUS_DURATION=0
    AUDACIOUS_POS_FMT="00:00"
    AUDACIOUS_DUR_FMT="00:00"
    AUDACIOUS_PROGRESS_PCT=0

    if ! pgrep -i -f audacious >/dev/null 2>&1 && ! qdbus org.mpris.MediaPlayer2.audacious >/dev/null 2>&1; then
        return 1
    fi

    local status_json
    status_json=$(python3 -c '
import subprocess, urllib.parse, sys, os, json, shutil

def get_prop(dest, path, iface, prop):
    try:
        return subprocess.check_output(["qdbus", dest, path, f"{iface}.{prop}"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
    except Exception:
        pass
    try:
        out = subprocess.check_output(["dbus-send", "--print-reply", f"--dest={dest}", path, "org.freedesktop.DBus.Properties.Get", "string:" + iface, "string:" + prop], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            line = line.strip()
            if "variant" in line:
                parts = line.split(None, 2)
                if len(parts) >= 3:
                    return parts[2].strip().strip("\"")
    except Exception:
        pass
    return ""

def get_meta(dest, path):
    try:
        raw = subprocess.check_output(["qdbus", dest, path, "org.mpris.MediaPlayer2.Player.Metadata"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
        meta = {}
        for line in raw.splitlines():
            if ": " in line:
                k, v = line.split(": ", 1)
                meta[k.strip()] = v.strip()
        if meta:
            return meta
    except Exception:
        pass
    return {}

dest = "org.mpris.MediaPlayer2.audacious"
path = "/org/mpris/MediaPlayer2"
iface = "org.mpris.MediaPlayer2.Player"

status = get_prop(dest, path, iface, "PlaybackStatus")
meta = get_meta(dest, path)

if not status or not meta:
    try:
        audtool_cmd = ["audtool"] if shutil.which("audtool") else ["flatpak", "run", "--command=audtool", "org.atheme.audacious"]
        if not status:
            st = subprocess.check_output(audtool_cmd + ["playback-status"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
            if st:
                status = st
        if not meta:
            t = subprocess.check_output(audtool_cmd + ["current-song"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
            fn = subprocess.check_output(audtool_cmd + ["current-song-filename"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
            ln = subprocess.check_output(audtool_cmd + ["current-song-length-seconds"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
            meta = {"xesam:title": t, "xesam:url": "file://" + fn if fn else "", "mpris:length": str(int(ln)*1000000) if ln.isdigit() else "0"}
    except Exception:
        pass

if not status:
    sys.exit(1)

track_url = meta.get("xesam:url", "")
if track_url.startswith("file://"):
    track_url = track_url[7:]
elif track_url.startswith("file:/"):
    track_url = track_url[6:]
track_url = urllib.parse.unquote(track_url)

title = meta.get("xesam:title", "")
artist = meta.get("xesam:artist", "")
album = meta.get("xesam:album", "")

if not title and track_url:
    title = os.path.splitext(os.path.basename(track_url))[0]

dur_us = meta.get("mpris:length", "0")
try:
    dur_s = int(dur_us) // 1000000
except Exception:
    try:
        dur_s = int(float(dur_us))
    except Exception:
        dur_s = 0

pos_val = get_prop(dest, path, iface, "Position")
try:
    pos_s = int(pos_val) // 1000000
except Exception:
    try:
        pos_s = int(float(pos_val))
    except Exception:
        pos_s = 0

if dur_s == 0 or pos_s == 0:
    try:
        audtool_cmd = ["audtool"] if shutil.which("audtool") else ["flatpak", "run", "--command=audtool", "org.atheme.audacious"]
        if dur_s == 0:
            ln = subprocess.check_output(audtool_cmd + ["current-song-length-seconds"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
            if ln.isdigit():
                dur_s = int(ln)
        if pos_s == 0:
            oln = subprocess.check_output(audtool_cmd + ["current-song-output-length-seconds"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
            if oln.isdigit():
                pos_s = int(oln)
    except Exception:
        pass

data = {
    "ok": True,
    "state": status.lower(),
    "title": title,
    "artist": artist,
    "album": album,
    "path": track_url,
    "position": pos_s,
    "duration": dur_s
}
print(json.dumps(data))
' 2>/dev/null)

    if [ -z "$status_json" ] || ! echo "$status_json" | jq -e . >/dev/null 2>&1; then
        return 1
    fi

    local ok
    ok=$(echo "$status_json" | jq -r '.ok // false')
    if [ "$ok" != "true" ]; then
        return 1
    fi

    AUDACIOUS_RUNNING=1
    AUDACIOUS_STATE=$(echo "$status_json" | jq -r '.state // "unknown"')
    AUDACIOUS_TITLE=$(echo "$status_json" | jq -r '.title // ""')
    AUDACIOUS_ARTIST=$(echo "$status_json" | jq -r '.artist // ""')
    AUDACIOUS_ALBUM=$(echo "$status_json" | jq -r '.album // ""')
    AUDACIOUS_RAW_PATH=$(echo "$status_json" | jq -r '.path // ""')
    AUDACIOUS_POSITION=$(echo "$status_json" | jq -r '.position // 0' | awk '{printf "%d", $1}')
    AUDACIOUS_DURATION=$(echo "$status_json" | jq -r '.duration // 0' | awk '{printf "%d", $1}')

    format_seconds_aud() {
        local t=$1
        local h=$((t / 3600))
        local m=$(( (t % 3600) / 60 ))
        local s=$((t % 60))
        if [ $h -gt 0 ]; then
            printf "%02d:%02d:%02d" $h $m $s
        else
            printf "%02d:%02d" $m $s
        fi
    }
    AUDACIOUS_POS_FMT=$(format_seconds_aud "$AUDACIOUS_POSITION")
    AUDACIOUS_DUR_FMT=$(format_seconds_aud "$AUDACIOUS_DURATION")

    if [ "$AUDACIOUS_DURATION" -gt 0 ]; then
        AUDACIOUS_PROGRESS_PCT=$((AUDACIOUS_POSITION * 100 / AUDACIOUS_DURATION))
    else
        AUDACIOUS_PROGRESS_PCT=0
    fi

    AUDACIOUS_RESOLVED_PATH="$AUDACIOUS_RAW_PATH"
    if [ -e "$AUDACIOUS_RESOLVED_PATH" ]; then
        AUDACIOUS_FILE_EXISTS=1
    else
        local alt="${AUDACIOUS_RAW_PATH/#\/media\//\/run\/media\/}"
        if [ -e "$alt" ]; then
            AUDACIOUS_RESOLVED_PATH="$alt"
            AUDACIOUS_FILE_EXISTS=1
        else
            local target_pids
            target_pids=$(pgrep -i -f audacious 2>/dev/null)
            for pid in $target_pids; do
                for fd in /proc/"$pid"/fd/*; do
                    if [ -e "$fd" ]; then
                        local link_target
                        link_target=$(readlink "$fd" 2>/dev/null)
                        case "$link_target" in
                            *.flac|*.wav|*.mp3|*.m4a|*.ogg)
                                if [ -f "$link_target" ]; then
                                    AUDACIOUS_RESOLVED_PATH="$link_target"
                                    AUDACIOUS_FILE_EXISTS=1
                                    break 2
                                fi
                                ;;
                        esac
                    fi
                done
            done
        fi
    fi

    if [ "$AUDACIOUS_FILE_EXISTS" -eq 1 ]; then
        AUDACIOUS_FILE_SIZE=$(ls -lh "$AUDACIOUS_RESOLVED_PATH" 2>/dev/null | awk '{print $5}')
    fi

    return 0
}

get_strawberry_track_info() {
    STRAWBERRY_RUNNING=0
    STRAWBERRY_STATE=""
    STRAWBERRY_TITLE=""
    STRAWBERRY_ARTIST=""
    STRAWBERRY_ALBUM=""
    STRAWBERRY_RAW_PATH=""
    STRAWBERRY_RESOLVED_PATH=""
    STRAWBERRY_FILE_EXISTS=0
    STRAWBERRY_FILE_SIZE=""
    STRAWBERRY_POSITION=0
    STRAWBERRY_DURATION=0
    STRAWBERRY_POS_FMT="00:00"
    STRAWBERRY_DUR_FMT="00:00"
    STRAWBERRY_PROGRESS_PCT=0

    if ! pgrep -i -f strawberry >/dev/null 2>&1; then
        return 1
    fi

    local status_json
    status_json=$(python3 -c '
import subprocess, urllib.parse, sys, os, json

def get_prop(dest, path, iface, prop):
    try:
        return subprocess.check_output(["qdbus", dest, path, f"{iface}.{prop}"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
    except Exception:
        pass
    try:
        if prop == "PlaybackStatus":
            return subprocess.check_output(["playerctl", "-p", "strawberry", "status"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
        elif prop == "Position":
            return subprocess.check_output(["playerctl", "-p", "strawberry", "position"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
    except Exception:
        pass
    try:
        out = subprocess.check_output(["dbus-send", "--print-reply", f"--dest={dest}", path, "org.freedesktop.DBus.Properties.Get", "string:" + iface, "string:" + prop], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
        for line in out.splitlines():
            line = line.strip()
            if "variant" in line:
                parts = line.split(None, 2)
                if len(parts) >= 3:
                    return parts[2].strip().strip("\"")
    except Exception:
        pass
    return ""

def get_meta(dest, path):
    try:
        raw = subprocess.check_output(["qdbus", dest, path, "org.mpris.MediaPlayer2.Player.Metadata"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
        meta = {}
        for line in raw.splitlines():
            if ": " in line:
                k, v = line.split(": ", 1)
                meta[k.strip()] = v.strip()
        if meta:
            return meta
    except Exception:
        pass
    try:
        url = subprocess.check_output(["playerctl", "-p", "strawberry", "metadata", "xesam:url"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
        title = subprocess.check_output(["playerctl", "-p", "strawberry", "metadata", "xesam:title"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
        artist = subprocess.check_output(["playerctl", "-p", "strawberry", "metadata", "xesam:artist"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
        album = subprocess.check_output(["playerctl", "-p", "strawberry", "metadata", "xesam:album"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
        length = subprocess.check_output(["playerctl", "-p", "strawberry", "metadata", "mpris:length"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
        return {"xesam:url": url, "xesam:title": title, "xesam:artist": artist, "album": album, "mpris:length": length}
    except Exception:
        pass
    return {}

dest = "org.mpris.MediaPlayer2.strawberry"
path = "/org/mpris/MediaPlayer2"
iface = "org.mpris.MediaPlayer2.Player"

status = get_prop(dest, path, iface, "PlaybackStatus")
if not status:
    sys.exit(1)

meta = get_meta(dest, path)
track_url = meta.get("xesam:url", "")
if track_url.startswith("file://"):
    track_url = track_url[7:]
elif track_url.startswith("file:/"):
    track_url = track_url[6:]
track_url = urllib.parse.unquote(track_url)

title = meta.get("xesam:title", "")
artist = meta.get("xesam:artist", "")
album = meta.get("xesam:album", "")

if not title and track_url:
    title = os.path.splitext(os.path.basename(track_url))[0]

dur_us = meta.get("mpris:length", "0")
try:
    dur_s = int(dur_us) // 1000000
except Exception:
    try:
        dur_s = int(float(dur_us))
    except Exception:
        dur_s = 0

pos_val = get_prop(dest, path, iface, "Position")
try:
    pos_s = int(pos_val) // 1000000
except Exception:
    try:
        pos_s = int(float(pos_val))
    except Exception:
        pos_s = 0

data = {
    "ok": True,
    "state": status.lower(),
    "title": title,
    "artist": artist,
    "album": album,
    "path": track_url,
    "position": pos_s,
    "duration": dur_s
}
print(json.dumps(data))
' 2>/dev/null)

    if [ -z "$status_json" ] || ! echo "$status_json" | jq -e . >/dev/null 2>&1; then
        return 1
    fi

    local ok
    ok=$(echo "$status_json" | jq -r '.ok // false')
    if [ "$ok" != "true" ]; then
        return 1
    fi

    STRAWBERRY_RUNNING=1
    STRAWBERRY_STATE=$(echo "$status_json" | jq -r '.state // "unknown"')
    STRAWBERRY_TITLE=$(echo "$status_json" | jq -r '.title // ""')
    STRAWBERRY_ARTIST=$(echo "$status_json" | jq -r '.artist // ""')
    STRAWBERRY_ALBUM=$(echo "$status_json" | jq -r '.album // ""')
    STRAWBERRY_RAW_PATH=$(echo "$status_json" | jq -r '.path // ""')
    STRAWBERRY_POSITION=$(echo "$status_json" | jq -r '.position // 0' | awk '{printf "%d", $1}')
    STRAWBERRY_DURATION=$(echo "$status_json" | jq -r '.duration // 0' | awk '{printf "%d", $1}')

    format_seconds_straw() {
        local t=$1
        local h=$((t / 3600))
        local m=$(( (t % 3600) / 60 ))
        local s=$((t % 60))
        if [ $h -gt 0 ]; then
            printf "%02d:%02d:%02d" $h $m $s
        else
            printf "%02d:%02d" $m $s
        fi
    }
    STRAWBERRY_POS_FMT=$(format_seconds_straw "$STRAWBERRY_POSITION")
    STRAWBERRY_DUR_FMT=$(format_seconds_straw "$STRAWBERRY_DURATION")

    if [ "$STRAWBERRY_DURATION" -gt 0 ]; then
        STRAWBERRY_PROGRESS_PCT=$((STRAWBERRY_POSITION * 100 / STRAWBERRY_DURATION))
    else
        STRAWBERRY_PROGRESS_PCT=0
    fi

    STRAWBERRY_RESOLVED_PATH="$STRAWBERRY_RAW_PATH"
    if [ -e "$STRAWBERRY_RESOLVED_PATH" ]; then
        STRAWBERRY_FILE_EXISTS=1
    else
        local alt="${STRAWBERRY_RAW_PATH/#\/media\//\/run\/media\/}"
        if [ -e "$alt" ]; then
            STRAWBERRY_RESOLVED_PATH="$alt"
            STRAWBERRY_FILE_EXISTS=1
        else
            local target_pids
            target_pids=$(pgrep -i -f strawberry 2>/dev/null)
            for pid in $target_pids; do
                for fd in /proc/"$pid"/fd/*; do
                    if [ -e "$fd" ]; then
                        local link_target
                        link_target=$(readlink "$fd" 2>/dev/null)
                        case "$link_target" in
                            *.flac|*.wav|*.mp3|*.m4a|*.ogg)
                                if [ -f "$link_target" ]; then
                                    STRAWBERRY_RESOLVED_PATH="$link_target"
                                    STRAWBERRY_FILE_EXISTS=1
                                    break 2
                                fi
                                ;;
                        esac
                    fi
                done
            done
        fi
    fi

    if [ "$STRAWBERRY_FILE_EXISTS" -eq 1 ]; then
        STRAWBERRY_FILE_SIZE=$(ls -lh "$STRAWBERRY_RESOLVED_PATH" 2>/dev/null | awk '{print $5}')
    fi

    return 0
}

get_cliamp_track_info() {
    CLIAMP_RUNNING=0
    CLIAMP_STATE=""
    CLIAMP_TITLE=""
    CLIAMP_ARTIST=""
    CLIAMP_RAW_PATH=""
    CLIAMP_RESOLVED_PATH=""
    CLIAMP_FILE_EXISTS=0
    CLIAMP_FILE_SIZE=""
    CLIAMP_POSITION=0
    CLIAMP_DURATION=0
    CLIAMP_POS_FMT="00:00"
    CLIAMP_DUR_FMT="00:00"
    CLIAMP_PROGRESS_PCT=0

    local cliamp_bin="cliamp"
    if ! command -v cliamp >/dev/null 2>&1; then
        if [ -x "$SCRIPT_DIR/bin/cliamp" ]; then
            cliamp_bin="$SCRIPT_DIR/bin/cliamp"
        elif [ -x "$HOME/.local/bin/cliamp" ]; then
            cliamp_bin="$HOME/.local/bin/cliamp"
        else
            return 1
        fi
    fi

    local pids
    pids=$(pgrep -x cliamp 2>/dev/null)
    if [ -z "$pids" ]; then
        return 1
    fi
    CLIAMP_RUNNING=1

    local status_json
    status_json=$("$cliamp_bin" status --json 2>/dev/null)
    if [ -z "$status_json" ] || ! echo "$status_json" | jq -e . >/dev/null 2>&1; then
        return 1
    fi

    local ok
    ok=$(echo "$status_json" | jq -r '.ok // false')
    if [ "$ok" != "true" ]; then
        return 1
    fi

    CLIAMP_STATE=$(echo "$status_json" | jq -r '.state // "unknown"')
    CLIAMP_TITLE=$(echo "$status_json" | jq -r '.track.title // ""')
    CLIAMP_ARTIST=$(echo "$status_json" | jq -r '.track.artist // ""')
    CLIAMP_RAW_PATH=$(echo "$status_json" | jq -r '.track.path // ""')
    CLIAMP_POSITION=$(echo "$status_json" | jq -r '.position // 0' | awk '{printf "%d", $1}')
    CLIAMP_DURATION=$(echo "$status_json" | jq -r '.duration // 0' | awk '{printf "%d", $1}')

    format_seconds_cliamp() {
        local t=$1
        local h=$((t / 3600))
        local m=$(( (t % 3600) / 60 ))
        local s=$((t % 60))
        if [ $h -gt 0 ]; then
            printf "%02d:%02d:%02d" $h $m $s
        else
            printf "%02d:%02d" $m $s
        fi
    }
    CLIAMP_POS_FMT=$(format_seconds_cliamp "$CLIAMP_POSITION")
    CLIAMP_DUR_FMT=$(format_seconds_cliamp "$CLIAMP_DURATION")

    if [ "$CLIAMP_DURATION" -gt 0 ]; then
        CLIAMP_PROGRESS_PCT=$((CLIAMP_POSITION * 100 / CLIAMP_DURATION))
    else
        CLIAMP_PROGRESS_PCT=0
    fi

    CLIAMP_RESOLVED_PATH="$CLIAMP_RAW_PATH"
    if [ -e "$CLIAMP_RESOLVED_PATH" ]; then
        CLIAMP_FILE_EXISTS=1
    else
        local alt="${CLIAMP_RAW_PATH/#\/media\//\/run\/media\/}"
        if [ -e "$alt" ]; then
            CLIAMP_RESOLVED_PATH="$alt"
            CLIAMP_FILE_EXISTS=1
        else
            for pid in $pids; do
                for fd in /proc/"$pid"/fd/*; do
                    if [ -e "$fd" ]; then
                        local target
                        target=$(readlink "$fd" 2>/dev/null)
                        if [ -n "$target" ] && [ "$(basename "$CLIAMP_RAW_PATH")" = "$(basename "$target")" ] && [ -e "$target" ]; then
                            CLIAMP_RESOLVED_PATH="$target"
                            CLIAMP_FILE_EXISTS=1
                            break 2
                        fi
                    fi
                done
            done
            if [ "$CLIAMP_FILE_EXISTS" -eq 0 ]; then
                local bname
                bname=$(basename "$CLIAMP_RAW_PATH")
                for dir in \
                    "${MIX_ARCHIVE_DIR:-}" \
                    "${MIX_ARCHIVE_DIR:-}/CONVERTED_WAV_FILES" \
                    "${MIX_ARCHIVE_DIR:-}/FLAC_CONVERTED_OUTPUTS" \
                    "$SCRIPT_DIR/MIX_ARCHIVE" \
                    "$SCRIPT_DIR/MIX_ARCHIVE/CONVERTED_WAV_FILES" \
                    "$SCRIPT_DIR/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" \
                    "/Volumes/WD BLACK B/MIX_ARCHIVE" \
                    "/Volumes/WD BLACK B/MIX_ARCHIVE/CONVERTED_WAV_FILES" \
                    "/Volumes/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" \
                    "/Volumes/MIX_ARCHIVE" \
                    "/d/MIX_ARCHIVE" \
                    "/e/MIX_ARCHIVE" \
                    "D:/MIX_ARCHIVE" \
                    "E:/MIX_ARCHIVE" \
                    "/mnt/d/MIX_ARCHIVE" \
                    "$SCRIPT_DIR" \
                    "$SCRIPT_DIR/CONVERTED_WAV_FILES" \
                    "$SCRIPT_DIR/FLAC_CONVERTED_OUTPUTS" \
                    "$PWD"; do
                    if [ -n "$dir" ] && [ -f "$dir/$bname" ]; then
                        CLIAMP_RESOLVED_PATH="$dir/$bname"
                        CLIAMP_FILE_EXISTS=1
                        break
                    fi
                done
            fi
        fi
    fi

    if [ "$CLIAMP_FILE_EXISTS" -eq 1 ]; then
        CLIAMP_FILE_SIZE=$(ls -lh "$CLIAMP_RESOLVED_PATH" 2>/dev/null | awk '{print $5}')
    fi

    return 0
}

# Command-line flags for quick inspection without full interactive menu
if [ "$1" = "--track" ] || [ "$1" = "--current-track" ] || [ "$1" = "--audacious-path" ] || [ "$1" = "--strawberry-path" ] || [ "$1" = "--cliamp-path" ] || [ "$1" = "-p" ]; then
    if get_audacious_track_info 2>/dev/null && [ -n "$AUDACIOUS_RESOLVED_PATH" ]; then
        echo "$AUDACIOUS_RESOLVED_PATH"
        exit 0
    elif get_strawberry_track_info 2>/dev/null && [ -n "$STRAWBERRY_RESOLVED_PATH" ]; then
        echo "$STRAWBERRY_RESOLVED_PATH"
        exit 0
    elif get_cliamp_track_info 2>/dev/null && [ -n "$CLIAMP_RESOLVED_PATH" ]; then
        echo "$CLIAMP_RESOLVED_PATH"
        exit 0
    else
        local detected_p
        detected_p=$(detect_currently_playing_mix 2>/dev/null)
        if [ -n "$detected_p" ] && [ -f "$detected_p" ]; then
            echo "$detected_p"
            exit 0
        fi
        echo "Error: No track currently playing in Audacious, Strawberry, cliamp, or supported players." >&2
        exit 1
    fi
elif [ "$1" = "--audacious-info" ]; then
    if get_audacious_track_info 2>/dev/null; then
        echo "State: $AUDACIOUS_STATE"
        echo "Title: $AUDACIOUS_TITLE"
        echo "Artist: $AUDACIOUS_ARTIST"
        echo "Album: $AUDACIOUS_ALBUM"
        echo "Time: $AUDACIOUS_POS_FMT / $AUDACIOUS_DUR_FMT ($AUDACIOUS_PROGRESS_PCT%)"
        echo "Path: $AUDACIOUS_RESOLVED_PATH"
        [ -n "$AUDACIOUS_FILE_SIZE" ] && echo "Size: $AUDACIOUS_FILE_SIZE"
        exit 0
    else
        echo "Error: Audacious is not running or no track playing." >&2
        exit 1
    fi
elif [ "$1" = "--strawberry-info" ]; then
    if get_strawberry_track_info 2>/dev/null; then
        echo "State: $STRAWBERRY_STATE"
        echo "Title: $STRAWBERRY_TITLE"
        echo "Artist: $STRAWBERRY_ARTIST"
        echo "Album: $STRAWBERRY_ALBUM"
        echo "Time: $STRAWBERRY_POS_FMT / $STRAWBERRY_DUR_FMT ($STRAWBERRY_PROGRESS_PCT%)"
        echo "Path: $STRAWBERRY_RESOLVED_PATH"
        [ -n "$STRAWBERRY_FILE_SIZE" ] && echo "Size: $STRAWBERRY_FILE_SIZE"
        exit 0
    else
        echo "Error: Strawberry is not running or no track playing." >&2
        exit 1
    fi
elif [ "$1" = "--cliamp-info" ]; then
    if get_cliamp_track_info 2>/dev/null; then
        echo "State: $CLIAMP_STATE"
        echo "Title: $CLIAMP_TITLE"
        echo "Artist: $CLIAMP_ARTIST"
        echo "Time: $CLIAMP_POS_FMT / $CLIAMP_DUR_FMT ($CLIAMP_PROGRESS_PCT%)"
        echo "Path: $CLIAMP_RESOLVED_PATH"
        [ -n "$CLIAMP_FILE_SIZE" ] && echo "Size: $CLIAMP_FILE_SIZE"
        exit 0
    else
        echo "Error: cliamp is not running or no track playing." >&2
        exit 1
    fi
elif [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ "$1" = "help" ]; then
    shift
    if [ -x "$SCRIPT_DIR/scripts/show_help.sh" ]; then
        exec bash "$SCRIPT_DIR/scripts/show_help.sh" "$@"
    elif [ -x "$SCRIPT_DIR/show_help.sh" ]; then
        exec bash "$SCRIPT_DIR/show_help.sh" "$@"
    fi
    exit 0
elif [ "$1" = "--version" ] || [ "$1" = "-v" ] || [ "$1" = "version" ]; then
    shift
    if [ -x "$SCRIPT_DIR/scripts/update_manager.sh" ]; then
        exec bash "$SCRIPT_DIR/scripts/update_manager.sh" --version "$@"
    elif [ -x "$SCRIPT_DIR/update_manager.sh" ]; then
        exec bash "$SCRIPT_DIR/update_manager.sh" --version "$@"
    fi
    exit 0
elif [ "$1" = "update" ] || [ "$1" = "--update" ]; then
    shift
    if [ -x "$SCRIPT_DIR/scripts/update_manager.sh" ]; then
        exec bash "$SCRIPT_DIR/scripts/update_manager.sh" "$@"
    elif [ -x "$SCRIPT_DIR/update_manager.sh" ]; then
        exec bash "$SCRIPT_DIR/update_manager.sh" "$@"
    fi
    exit 0
elif [ "$1" = "--top5" ] || [ "$1" = "--top-5" ] || [ "$1" = "top5" ] || [ "$1" = "top-5" ]; then
    shift
    if [ -x "$SCRIPT_DIR/scripts/manage_top_5_tracks.sh" ]; then
        exec bash "$SCRIPT_DIR/scripts/manage_top_5_tracks.sh" "$@"
    elif [ -f "$SCRIPT_DIR/scripts/top_5_tracks_manager.py" ]; then
        exec python3 "$SCRIPT_DIR/scripts/top_5_tracks_manager.py" "$@"
    fi
    exit 0
fi


CLI_INITIAL_ACTION="${1:-}"

show_stats() {
    echo -e "${BOLD}${BLUE}=== CURRENT STATUS & STATISTICS ===${NC}"
    if ! is_internet_connected; then
        echo -e "  ${DIM}${YELLOW}⚡ Offline Mode: Cloud storage excluded from scan${NC}"
    fi
    
    local wav_dirs=()
    while IFS= read -r wdir; do
        [ -n "$wdir" ] && [ -d "$wdir" ] && wav_dirs+=("$wdir")
    done < <(get_all_wav_archive_dirs)

    local all_flac_dirs=()
    while IFS= read -r fdir; do
        [ -n "$fdir" ] && [ -d "$fdir" ] && all_flac_dirs+=("$fdir")
    done < <(get_all_flac_output_dirs)

    local all_parent_dirs=()
    while IFS= read -r pdir; do
        [ -n "$pdir" ] && [ -d "$pdir" ] && all_parent_dirs+=("$pdir")
    done < <(get_all_mix_archive_dirs)

    local root_wav_count=0
    local root_wav_size_mb=0
    local archive_wav_count=0
    local archive_wav_size_gb="0.00"
    local total_flac_count=0
    local missing_tl_count=0
    local mp3_count=0
    local wav_out_count=0
    local mp4_count=0

    # High-Performance Single-Pass Python Scanner (1,000x faster on Cloud/FUSE mounts like GoogleDrive)
    local w_str f_str p_str stats_out
    w_str="$(printf '%s\n' "${wav_dirs[@]}")"
    f_str="$(printf '%s\n' "${all_flac_dirs[@]}")"
    p_str="$(printf '%s\n' "${all_parent_dirs[@]}")"

    stats_out=$(python3 - "$PWD" "$w_str" "$f_str" "$p_str" << 'PY' 2>/dev/null || true
import os, sys

root_dir = sys.argv[1]
wav_dirs = [d for d in sys.argv[2].splitlines() if d and os.path.isdir(d)]
flac_dirs = [d for d in sys.argv[3].splitlines() if d and os.path.isdir(d)]
parent_dirs = [d for d in sys.argv[4].splitlines() if d and os.path.isdir(d)]

# 1. Root WAVs
root_wav_count = 0
root_wav_size = 0
if os.path.isdir(root_dir):
    try:
        with os.scandir(root_dir) as it:
            for entry in it:
                if entry.name.lower().endswith('.wav') and entry.is_file():
                    root_wav_count += 1
                    root_wav_size += entry.stat().st_size
    except Exception:
        pass
root_wav_size_mb = root_wav_size // (1024 * 1024)

# 2. Archive WAVs
archive_wav_count = 0
archive_wav_size = 0
for d in wav_dirs:
    try:
        with os.scandir(d) as it:
            for entry in it:
                if entry.name.lower().endswith('.wav') and entry.is_file():
                    archive_wav_count += 1
                    archive_wav_size += entry.stat().st_size
    except Exception:
        pass
archive_wav_size_gb = f"{archive_wav_size / (1024**3):.2f}"

# 3. FLACs & Missing Tracklists
total_flac_count = 0
missing_tl_count = 0
for d in flac_dirs:
    try:
        names = set(os.listdir(d))
        flacs = [n for n in names if n.lower().endswith('.flac')]
        total_flac_count += len(flacs)
        for f in flacs:
            stem = f.rsplit('.', 1)[0]
            if f"{stem}.txt" not in names:
                missing_tl_count += 1
    except Exception:
        pass

# 4. MP3, WAV, MP4 outputs in parents
mp3_count = 0
wav_out_count = 0
mp4_count = 0
for p in parent_dirs:
    for kind, ext in [('MP3_CONVERTED_OUTPUTS', '.mp3'), ('WAV_CONVERTED_OUTPUTS', '.wav'), ('MP4_CONVERTED_OUTPUTS', '.mp4')]:
        sub_d = os.path.join(p, kind)
        if os.path.isdir(sub_d):
            try:
                count = sum(1 for e in os.scandir(sub_d) if e.name.lower().endswith(ext) and e.is_file())
                if ext == '.mp3': mp3_count += count
                elif ext == '.wav': wav_out_count += count
                elif ext == '.mp4': mp4_count += count
            except Exception:
                pass

print(f"{root_wav_count}|{root_wav_size_mb}|{archive_wav_count}|{archive_wav_size_gb}|{total_flac_count}|{missing_tl_count}|{mp3_count}|{wav_out_count}|{mp4_count}")
PY
)

    if [ -n "$stats_out" ]; then
        IFS='|' read -r root_wav_count root_wav_size_mb archive_wav_count archive_wav_size_gb total_flac_count missing_tl_count mp3_count wav_out_count mp4_count <<< "$stats_out"
    else
        # Fallback to shell-native scan if python failed
        shopt -s nullglob nocaseglob
        local root_wavs=(./*.wav)
        root_wav_count=${#root_wavs[@]}
        local root_wav_size=0
        for w in "${root_wavs[@]}"; do
            [ -f "$w" ] && root_wav_size=$((root_wav_size + $(stat -c %s "$w" 2>/dev/null || wc -c < "$w")))
        done
        root_wav_size_mb=$((root_wav_size / 1024 / 1024))

        for wdir in "${wav_dirs[@]}"; do
            local cur_wavs=("$wdir"/*.wav)
            archive_wav_count=$((archive_wav_count + ${#cur_wavs[@]}))
        done
        for fdir in "${all_flac_dirs[@]}"; do
            local cur_flacs=("$fdir"/*.flac)
            total_flac_count=$((total_flac_count + ${#cur_flacs[@]}))
        done
        shopt -u nullglob nocaseglob
    fi

    local loc_count=${#all_flac_dirs[@]}
    local loc_note=""
    if [ "$loc_count" -gt 1 ]; then
        loc_note=" across ${BOLD}${WHITE}${loc_count}${NC}${CYAN} storage archives${NC}"
    fi

    echo -e "  Root Directory WAVs (Pending Conversion):  ${BOLD}${YELLOW}${root_wav_count}${NC} files (${root_wav_size_mb} MB)"
    echo -e "  Archive Directory WAVs (Converted):       ${BOLD}${GREEN}${archive_wav_count}${NC} files (${archive_wav_size_gb} GB)"
    echo -e "  Total FLAC Files Generated:               ${BOLD}${CYAN}${total_flac_count}${NC} files${loc_note}"
    [ "$mp3_count" -gt 0 ] && echo -e "  Total MP3 Files Generated:                ${BOLD}${CYAN}${mp3_count}${NC} files"
    [ "$wav_out_count" -gt 0 ] && echo -e "  Total WAV Converted Outputs:              ${BOLD}${CYAN}${wav_out_count}${NC} files"
    [ "$mp4_count" -gt 0 ] && echo -e "  Total MP4 Videos Generated:               ${BOLD}${CYAN}${mp4_count}${NC} videos"
    if [ "$missing_tl_count" -gt 0 ]; then
        echo -e "  FLAC Files Missing Tracklists:            ${BOLD}${RED}${missing_tl_count}${NC} files"
    else
        echo -e "  FLAC Files Missing Tracklists:            ${BOLD}${GREEN}0${NC} files (All complete!)"
    fi
    local cloud_stat
    cloud_stat=$(get_cloud_backup_badge 2>/dev/null)
    [ -n "$cloud_stat" ] && echo -e "  ${cloud_stat}"

    # 5. Live Player Status & Audio Specifications
    if get_audacious_track_info 2>/dev/null; then
        local st_badge
        case "$AUDACIOUS_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${AUDACIOUS_STATE^^}${NC}" ;;
        esac
        echo -e "  --------------------------------------------------"
        echo -e "  Audacious Audio Player:                   ${st_badge} [${AUDACIOUS_POS_FMT} / ${AUDACIOUS_DUR_FMT}] (${AUDACIOUS_PROGRESS_PCT}%)"
        echo -e "  Audacious Current Track:                  ${BOLD}${YELLOW}${AUDACIOUS_TITLE}${NC}${AUDACIOUS_ARTIST:+ - $AUDACIOUS_ARTIST}"
        [ -n "$AUDACIOUS_RESOLVED_PATH" ] && echo -e "  Audacious Active File Path:               ${BOLD}${CYAN}${AUDACIOUS_RESOLVED_PATH}${NC}"
        if [ -n "$AUDACIOUS_RESOLVED_PATH" ] && [ -f "$AUDACIOUS_RESOLVED_PATH" ]; then
            local audio_spec
            audio_spec=$(get_playing_audio_spec_summary "$AUDACIOUS_RESOLVED_PATH")
            [ -n "$audio_spec" ] && echo -e "  Audio Specifications:                     ${BOLD}${GREEN}${audio_spec}${NC}"
        fi
    elif get_strawberry_track_info 2>/dev/null; then
        local st_badge
        case "$STRAWBERRY_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${STRAWBERRY_STATE^^}${NC}" ;;
        esac
        echo -e "  --------------------------------------------------"
        echo -e "  Strawberry Music Player:                  ${st_badge} [${STRAWBERRY_POS_FMT} / ${STRAWBERRY_DUR_FMT}] (${STRAWBERRY_PROGRESS_PCT}%)"
        echo -e "  Strawberry Current Track:                 ${BOLD}${YELLOW}${STRAWBERRY_TITLE}${NC}${STRAWBERRY_ARTIST:+ - $STRAWBERRY_ARTIST}"
        [ -n "$STRAWBERRY_RESOLVED_PATH" ] && echo -e "  Strawberry Active File Path:              ${BOLD}${CYAN}${STRAWBERRY_RESOLVED_PATH}${NC}"
        if [ -n "$STRAWBERRY_RESOLVED_PATH" ] && [ -f "$STRAWBERRY_RESOLVED_PATH" ]; then
            local audio_spec
            audio_spec=$(get_playing_audio_spec_summary "$STRAWBERRY_RESOLVED_PATH")
            [ -n "$audio_spec" ] && echo -e "  Audio Specifications:                     ${BOLD}${GREEN}${audio_spec}${NC}"
        fi
    elif get_cliamp_track_info 2>/dev/null; then
        local st_badge
        case "$CLIAMP_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
        esac
        echo -e "  --------------------------------------------------"
        echo -e "  Cliamp Music Player:                      ${st_badge} [${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}] (${CLIAMP_PROGRESS_PCT}%)"
        echo -e "  Cliamp Current Track:                     ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC} - ${CLIAMP_ARTIST}"
        echo -e "  Cliamp Active File Path:                  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
        if [ -n "$CLIAMP_RESOLVED_PATH" ] && [ -f "$CLIAMP_RESOLVED_PATH" ]; then
            local audio_spec
            audio_spec=$(get_playing_audio_spec_summary "$CLIAMP_RESOLVED_PATH")
            [ -n "$audio_spec" ] && echo -e "  Audio Specifications:                     ${BOLD}${GREEN}${audio_spec}${NC}"
        fi
    else
        local other_mix
        other_mix=$(detect_currently_playing_mix 2>/dev/null)
        if [ -n "$other_mix" ] && [ -f "$other_mix" ]; then
            local audio_spec
            audio_spec=$(get_playing_audio_spec_summary "$other_mix")
            echo -e "  --------------------------------------------------"
            echo -e "  Active Playing Mix:                       ${BOLD}${GREEN}$(basename "$other_mix")${NC}"
            [ -n "$audio_spec" ] && echo -e "  Audio Specifications:                     ${BOLD}${GREEN}${audio_spec}${NC}"
        fi
    fi
    echo -e "${BLUE}===================================${NC}"
}

press_enter() {
    echo ""
    read -r -p "Press [Enter] to return to the main menu..."
}

rename_mix() {
    echo -e "\n${BOLD}${BLUE}=== RENAME MIX FILE & ASSOCIATED ASSETS ===${NC}"
    read -r -p "Enter current FLAC filename (or search keyword): " src_flac
    
    # Clean and locate file
    src_flac_name=$(basename "$src_flac" | tr -d '\r' | tr -d '\n')
    local src_path=""
    local found_dir=""

    if [ -f "$src_flac" ]; then
        src_path="$src_flac"
        found_dir="$(dirname "$src_path")"
        src_flac_name="$(basename "$src_path")"
    else
        while IFS= read -r fdir; do
            if [ -n "$fdir" ] && [ -f "$fdir/$src_flac_name" ]; then
                src_path="$fdir/$src_flac_name"
                found_dir="$fdir"
                break
            fi
        done < <(get_all_flac_output_dirs)
    fi

    # Fallback to search if not exact filename match
    if [ -z "$src_path" ]; then
        local candidates=()
        while IFS= read -r fdir; do
            if [ -d "$fdir" ]; then
                shopt -s nullglob nocaseglob
                for mf in "$fdir"/*"$src_flac"*.flac; do
                    [ -f "$mf" ] && candidates+=("$mf")
                done
                shopt -u nullglob nocaseglob
            fi
        done < <(get_all_flac_output_dirs)

        if [ ${#candidates[@]} -eq 1 ]; then
            src_path="${candidates[0]}"
            found_dir="$(dirname "$src_path")"
            src_flac_name="$(basename "$src_path")"
        elif [ ${#candidates[@]} -gt 1 ]; then
            echo -e "\nMultiple matching FLAC files found:"
            for i in "${!candidates[@]}"; do
                echo "  $((i+1))) [$(basename "$(dirname "${candidates[$i]}")")] $(basename "${candidates[$i]}")"
            done
            read -r -p "Select mix to rename [1-${#candidates[@]}]: " pick
            if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#candidates[@]}" ]; then
                src_path="${candidates[$((pick-1))]}"
                found_dir="$(dirname "$src_path")"
                src_flac_name="$(basename "$src_path")"
            else
                echo -e "${RED}Invalid selection.${NC}"
                return
            fi
        fi
    fi
    
    if [ -z "$src_path" ] || [ ! -f "$src_path" ]; then
        echo -e "${RED}Error: File '$src_flac' not found across any configured archive directories!${NC}"
        return
    fi

    echo -e "\n${CYAN}Located Mix in:${NC} ${found_dir}"
    echo -e "Current file: ${WHITE}$src_flac_name${NC}"
    
    read -r -p "Enter destination filename for final FLAC: " dest_flac
    dest_flac_name=$(basename "$dest_flac" | tr -d '\r' | tr -d '\n')
    [[ "$dest_flac_name" != *.flac ]] && dest_flac_name="${dest_flac_name}.flac"
    dest_path="${found_dir}/${dest_flac_name}"
    
    if [ -f "$dest_path" ]; then
        echo -e "${RED}Error: Destination file '$dest_path' already exists!${NC}"
        return
    fi
    
    # Rename FLAC
    mv "$src_path" "$dest_path"
    echo -e "${GREEN}✓ Renamed FLAC: $src_flac_name ➔ $dest_flac_name${NC}"
    
    # Base names without extension
    src_base="${src_flac_name%.*}"
    dest_base="${dest_flac_name%.*}"
    
    # Rename Tracklist if exists
    src_txt="${found_dir}/${src_base}.txt"
    dest_txt="${found_dir}/${dest_base}.txt"
    if [ -f "$src_txt" ]; then
        mv "$src_txt" "$dest_txt"
        echo -e "${GREEN}✓ Renamed Tracklist: $(basename "$src_txt") ➔ $(basename "$dest_txt")${NC}"
    fi
    
    # Rename Spek if exists (check in parent archive SPEK_OUTPUTS as well)
    local spek_dirs=("SPEK_OUTPUTS" "${found_dir}/SPEK_OUTPUTS" "$(dirname "$found_dir")/SPEK_OUTPUTS")
    for s_dir in "${spek_dirs[@]}"; do
        if [ -f "$s_dir/${src_base}_spectrogram.png" ]; then
            mv "$s_dir/${src_base}_spectrogram.png" "$s_dir/${dest_base}_spectrogram.png"
            echo -e "${GREEN}✓ Renamed Spectrogram in $s_dir: ${src_base}_spectrogram.png ➔ ${dest_base}_spectrogram.png${NC}"
        fi
    done
}

view_tasks() {
    echo -e "\n${BOLD}${BLUE}=== RUNNING BACKGROUND TASKS ===${NC}"
    local tasks_found=0
    
    if pgrep -f "Make_SOF_FLAC_CONVERSION.sh" > /dev/null || pgrep -x "ffmpeg" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] FLAC Conversion Batch Job (Make_SOF_FLAC_CONVERSION.sh / ffmpeg)"
        ((tasks_found++))
    fi
    if pgrep -f "Check_Find_Tracklists.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] Tracklist Generator Job (Check_Find_Tracklists.sh)"
        ((tasks_found++))
    fi
    if pgrep -f "Verify_FLAC_Files.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] FLAC Verification Scan (Verify_FLAC_Files.sh)"
        ((tasks_found++))
    fi
    if pgrep -f "backup_to_gdrive.sh" > /dev/null || pgrep -f "backup_mix_archive.sh" > /dev/null || pgrep -x "rclone" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] Cloud Backup / Active Transfer (backup_mix_archive.sh / rclone)"
        ((tasks_found++))
    fi
    if pgrep -f "import_new_mixes.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] SMB Import Process (import_new_mixes.sh)"
        ((tasks_found++))
    fi
    if pgrep -f "SOF_Live_Tracker.sh" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] Live Tracklist Monitor (SOF_Live_Tracker.sh)"
        ((tasks_found++))
    fi
    local chrome_upload_info=""
    if command -v chrome-upload-monitor >/dev/null 2>&1; then
        chrome_upload_info=$(chrome-upload-monitor --check 2>/dev/null || true)
    elif [ -x "$HOME/.local/bin/chrome-upload-monitor" ]; then
        chrome_upload_info=$("$HOME/.local/bin/chrome-upload-monitor" --check 2>/dev/null || true)
    elif [ -x "./chrome_upload_monitor.py" ]; then
        chrome_upload_info=$(python3 ./chrome_upload_monitor.py --check 2>/dev/null || true)
    fi
    if [ -n "$chrome_upload_info" ]; then
        echo -e "  [${YELLOW}RUNNING${NC}] Chrome Podcast Connect / Web Upload: ${CYAN}${chrome_upload_info}${NC}"
        ((tasks_found++))
    fi
    if pgrep -f "python.*wgp\.py" > /dev/null; then
        local wgp_pids
        wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] WAN2GP AI Video Server (PID: ${wgp_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "wan2gp_flux_batch" > /dev/null; then
        local flux_pids
        flux_pids=$(pgrep -f "wan2gp_flux_batch" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] WAN2GP Flux 2 Klein Batch Processor (PID: ${flux_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "wan2gp_ltx.*batch" > /dev/null; then
        local ltx_pids
        ltx_pids=$(pgrep -f "wan2gp_ltx.*batch" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] WAN2GP LTX Video Batch Processor (PID: ${ltx_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "remove_duplicate_images\.py" > /dev/null; then
        local dup_pids
        dup_pids=$(pgrep -f "remove_duplicate_images\.py" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] Duplicate Image Remover (PID: ${dup_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "traktor_monitor" > /dev/null; then
        local tm_pids
        tm_pids=$(pgrep -f "traktor_monitor" | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] Traktor Live Monitor & Audio Recorder (PID: ${tm_pids})"
        ((tasks_found++))
    fi
    if pgrep -x "Traktor" > /dev/null || pgrep -x "Traktor.exe" > /dev/null || pgrep -f "Traktor Pro" > /dev/null; then
        local tp_pids
        tp_pids=$(pgrep -x "Traktor" 2>/dev/null || pgrep -x "Traktor.exe" 2>/dev/null || pgrep -f "Traktor Pro" 2>/dev/null | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] Native Instruments Traktor Pro DJ (PID: ${tp_pids})"
        ((tasks_found++))
    fi
    if systemctl is-active --quiet sshd || pgrep -x sshd > /dev/null; then
        local ssh_pids
        ssh_pids=$(pgrep -x sshd | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] SSH Server (sshd - Port 22, PID: ${ssh_pids})"
        ((tasks_found++))
    fi
    if systemctl is-active --quiet smb || pgrep -x smbd > /dev/null; then
        local smb_pids
        smb_pids=$(pgrep -x smbd | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] Samba File Sharing (smbd, nmbd, wsdd - Ports 139, 445, PID: ${smb_pids})"
        ((tasks_found++))
    fi
    if systemctl is-active --quiet vsftpd || pgrep -x vsftpd > /dev/null; then
        local ftp_pids
        ftp_pids=$(pgrep -x vsftpd | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] FTP Server (vsftpd - Port 21, PID: ${ftp_pids})"
        ((tasks_found++))
    fi
    if pgrep -f "ujust" > /dev/null || pgrep -f "rpm-ostree" > /dev/null; then
        echo -e "  [${YELLOW}RUNNING${NC}] System Maintenance / Update (ujust / rpm-ostree)"
        ((tasks_found++))
    fi
    if pgrep -i -f "audacious" > /dev/null; then
        local aud_pids aud_desc=""
        aud_pids=$(pgrep -i -f audacious | tr '\n' ' ')
        if get_audacious_track_info 2>/dev/null; then
            aud_desc=" [${AUDACIOUS_STATE^^}: ${AUDACIOUS_TITLE} - ${AUDACIOUS_POS_FMT}/${AUDACIOUS_DUR_FMT}]"
        fi
        echo -e "  [${GREEN}RUNNING${NC}] Audacious Audio Player (PID: ${aud_pids})${aud_desc}"
        ((tasks_found++))
    fi
    if pgrep -i -f "strawberry" > /dev/null; then
        local straw_pids straw_desc=""
        straw_pids=$(pgrep -i -f strawberry | tr '\n' ' ')
        if get_strawberry_track_info 2>/dev/null; then
            straw_desc=" [${STRAWBERRY_STATE^^}: ${STRAWBERRY_TITLE} - ${STRAWBERRY_POS_FMT}/${STRAWBERRY_DUR_FMT}]"
        fi
        echo -e "  [${GREEN}RUNNING${NC}] Strawberry Music Player (PID: ${straw_pids})${straw_desc}"
        ((tasks_found++))
    fi
    if pgrep -x "cliamp" > /dev/null; then
        local cliamp_pids cliamp_desc=""
        cliamp_pids=$(pgrep -x cliamp | tr '\n' ' ')
        if get_cliamp_track_info 2>/dev/null; then
            cliamp_desc=" [${CLIAMP_STATE^^}: ${CLIAMP_TITLE} - ${CLIAMP_POS_FMT}/${CLIAMP_DUR_FMT}]"
        fi
        echo -e "  [${GREEN}RUNNING${NC}] cliamp Retro Music Player (PID: ${cliamp_pids})${cliamp_desc}"
        ((tasks_found++))
    fi
    if ss -tuln 2>/dev/null | grep -q ":3080 " || pgrep -f "dsh.*web|apps/cli/src/bin\.ts.*web" >/dev/null 2>&1; then
        local dsh_pids
        dsh_pids=$(lsof -ti:3080 2>/dev/null || pgrep -f "dsh.*web|apps/cli/src/bin\.ts.*web" 2>/dev/null | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] DeepSeek Harness (dsh-mobile - http://192.168.1.11:3080, PID: ${dsh_pids% })"
        ((tasks_found++))
    fi
    if command -v podman >/dev/null 2>&1 && podman ps --filter "name=beszel" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel$"; then
        local bsz_status="Hub :8090"
        if podman ps --filter "name=beszel-agent" --format "{{.Names}}" 2>/dev/null | grep -q "^beszel-agent$"; then
            bsz_status="Hub :8090 + Agent"
        fi
        echo -e "  [${GREEN}RUNNING${NC}] Beszel Server Monitoring (${bsz_status})"
        ((tasks_found++))
    fi
    if curl -s --connect-timeout 1 "http://127.0.0.1:11434/" 2>/dev/null | grep -qi "Ollama is running" || pgrep -f "ollama serve" >/dev/null 2>&1; then
        local olm_pids
        olm_pids=$(pgrep -f "ollama serve" 2>/dev/null | tr '\n' ' ')
        echo -e "  [${GREEN}RUNNING${NC}] Ollama Local AI Server (http://127.0.0.1:11434, PID: ${olm_pids% })"
        ((tasks_found++))
    fi
    
    if [ $tasks_found -eq 0 ]; then
        echo -e "  ${GREEN}No active background tasks found.${NC}"
    fi
    echo -e "${BLUE}================================${NC}"
}

view_cover() {
    echo -e "\n${BOLD}${BLUE}=== VIEW COVER ART BY MIX NUMBER ===${NC}"
    read -r -p "Enter the mix/episode number (e.g. 037, 063): " mix_num
    
    if [ -z "$mix_num" ]; then
        echo -e "${RED}Error: Mix number cannot be empty.${NC}"
        return
    fi
    
    # Search for matching covers in COVERS/ directory
    shopt -s nullglob nocaseglob
    local matches=(COVERS/*"${mix_num}"*.png COVERS/*"${mix_num}"*.jpg COVERS/*"${mix_num}"*.jpeg)
    
    if [ ${#matches[@]} -eq 0 ]; then
        echo -e "${YELLOW}No matching cover art found in COVERS/ for mix number '${mix_num}'.${NC}"
        return
    fi
    
    echo -e "${GREEN}Found match(es):${NC}"
    local i=1
    for m in "${matches[@]}"; do
        echo "  $i) $(basename "$m")"
        ((i++))
    done
    
    local choice=1
    if [ ${#matches[@]} -gt 1 ]; then
        read -r -p "Select which file to view [1-$((i-1))]: " choice
    fi
    
    local target_index=$((choice - 1))
    local selected_cover="${matches[$target_index]}"
    
    if [ -f "$selected_cover" ]; then
        echo -e "${CYAN}Launching external image viewer for $(basename "$selected_cover")...${NC}"
        open_path "$selected_cover"
    else
        echo -e "${RED}Error: Selected file does not exist.${NC}"
    fi
}

generate_youtube_video() {
    clear
    echo -e "
${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}       YOUTUBE VIDEO GENERATION SUITE (4K UHD / 1080p / 720p)         ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}
"
    echo -e "  Encodes video with hardware acceleration (NVENC / VideoToolbox / libx264)"
    echo -e "  and studio-grade 320kbps AAC audio with smooth 5-second audio fading.
"
    echo -e "  ${BOLD}Select Video Generation Option:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} 4K UHD (3840x2160 @ 30fps) - ${GREEN}Ultra High Definition (Still Cover Art + Audio)${NC}"
    echo -e "  ${BOLD}${CYAN}2)${NC} 1080p Full HD (1920x1080 @ 30fps) - ${GREEN}Standard High Definition (Still Cover Art + Audio)${NC}"
    echo -e "  ${BOLD}${CYAN}3)${NC} 720p HD (1280x720 @ 30fps) - ${YELLOW}Fast Export & Compact File Size (Still Cover Art + Audio)${NC}"
    echo -e "  ${BOLD}${CYAN}4)${NC} Looping MP4-to-MP4 Video Creator (${GREEN}Loop MP4 with Segment Fades, Audio & Thumbnails${NC})"
    echo -e "  ${BOLD}${CYAN}5)${NC} Launch Universal Video Generator Wizard (${GREEN}generate_youtube_video.sh${NC})"
    echo -e "  ${BOLD}${CYAN}6)${NC} Download YouTube Videos & Shorts in 1080p (${GREEN}Single URL, 1/3/6 Mo, All Videos/Shorts - MP_YouTube_Channel_Downloader.sh${NC})"
    echo -e "  ${BOLD}${CYAN}7)${NC} Cancel & Return to Main Menu
"
    read -r -p "Enter choice [1-7, default: 2]: " v_choice

    local res="1080p"
    case "$v_choice" in
        1) res="4k" ;;
        2) res="1080p" ;;
        3) res="720p" ;;
        4)
            echo -e "\n${BOLD}${CYAN}--- MP4 to MP4 Looping Video Creator ---${NC}\n"
            read -r -p "Enter Audio file path (.wav / .flac): " mp4_audio
            read -r -p "Enter Input Video file path (.mp4 / .mkv): " mp4_video
            read -r -p "Enter Intro/Outro Thumbnail image (optional, leave blank for auto): " mp4_thumb
            read -r -p "Enter Output directory or target file path (default: $MP4_OUTPUT_DIR): " mp4_out
            [ -z "$mp4_out" ] && mp4_out="$MP4_OUTPUT_DIR"
            run_sub_script "Make_SOF_Episode_From_MP4_Audio_Output_MP4_1080p_Video.sh" "$mp4_audio" "$mp4_video" "$mp4_thumb" "$mp4_out" "1080p"
            press_enter
            return 0
            ;;
        5)
            run_sub_script "generate_youtube_video.sh"
            press_enter
            return 0
            ;;
        6)
            run_sub_script "MP_YouTube_Channel_Downloader.sh"
            press_enter
            return 0
            ;;
        7|[qQ])
            return 0
            ;;
        *)
            res="1080p"
            ;;
    esac

    # Prompt or select latest FLAC/WAV mix (newest first)
    local flac_list=()
    local search_dirs=()
    [ -d "$OUTPUT_DIR" ] && search_dirs+=("$OUTPUT_DIR")
    [ -d "$WAV_OUTPUT_DIR" ] && search_dirs+=("$WAV_OUTPUT_DIR")
    [ -d "$ARCHIVE_DIR" ] && search_dirs+=("$ARCHIVE_DIR")
    [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS" ] && search_dirs+=("$MIX_ARCHIVE_DIR/FLAC_CONVERTED_OUTPUTS")
    [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/WAV_CONVERTED_OUTPUTS" ] && search_dirs+=("$MIX_ARCHIVE_DIR/WAV_CONVERTED_OUTPUTS")
    [ -n "${MIX_ARCHIVE_DIR:-}" ] && [ -d "$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES" ] && search_dirs+=("$MIX_ARCHIVE_DIR/CONVERTED_WAV_FILES")
    [ -d "$SCRIPT_DIR/FLAC_CONVERTED_OUTPUTS" ] && search_dirs+=("$SCRIPT_DIR/FLAC_CONVERTED_OUTPUTS")
    search_dirs+=("$PWD")

    local patterns=()
    for sdir in "${search_dirs[@]}"; do
        patterns+=("$sdir"/*.flac "$sdir"/*.wav)
    done

    local seen_stems="|"
    local f
    while IFS= read -r f; do
        if [ -n "$f" ] && [ -f "$f" ]; then
            local bname stem stem_lower preferred_f
            bname=$(basename "$f")
            stem="${bname%.*}"
            stem_lower=$(echo "$stem" | tr '[:upper:]' '[:lower:]')
            if [[ "$seen_stems" != *"|$stem_lower|"* ]]; then
                seen_stems="${seen_stems}${stem_lower}|"
                preferred_f="$f"
                if [[ "$f" == *.wav ]] || [[ "$f" == *.WAV ]]; then
                    local flac_companion="${f%.*}.flac"
                    [ -f "$flac_companion" ] && preferred_f="$flac_companion"
                fi
                flac_list+=("$preferred_f")
            fi
        fi
    done < <(ls -td "${patterns[@]}" 2>/dev/null)

    local flac_input=""
    if [ ${#flac_list[@]} -gt 0 ]; then
        echo -e "\n${BOLD}${CYAN}Available Mixes in Archive (Showing Latest 10 Mixes):${NC}"
        local limit=10
        [ ${#flac_list[@]} -lt $limit ] && limit=${#flac_list[@]}
        for ((i=0; i<limit; i++)); do
            printf "  %2d) %s\n" "$((i + 1))" "$(basename "${flac_list[$i]}")"
        done
        echo ""
        read -r -p "Select mix number [1-${limit}] or enter custom filename: " chosen_mix
        if [[ "$chosen_mix" =~ ^[0-9]+$ ]] && [ "$chosen_mix" -ge 1 ] && [ "$chosen_mix" -le "$limit" ]; then
            flac_input="${flac_list[$((chosen_mix - 1))]}"
        elif [ -n "$chosen_mix" ]; then
            flac_input="$chosen_mix"
        fi
    fi

    if [ -z "$flac_input" ]; then
        read -r -p "Enter filename/path of the audio file (.flac / .wav): " flac_input
    fi

    flac_input=$(echo "$flac_input" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    [ -z "$flac_input" ] && { echo -e "${RED}Error: Audio file is required.${NC}"; return; }

    # Cover image prompt
    read -r -p "Enter Cover PNG path (leave blank for auto-detect / Cover.png): " cover_input
    cover_input=$(echo "$cover_input" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    case "$res" in
        4k)
            run_sub_script "Make_SOF_Episode_From_PNG_FLAC_Output_MP4_4K_Video.sh" "$flac_input" "$cover_input" "$MP4_OUTPUT_DIR"
            ;;
        720p)
            run_sub_script "Make_SOF_Episode_From_PNG_FLAC_Output_MP4_720p_Video.sh" "$flac_input" "$cover_input" "$MP4_OUTPUT_DIR"
            ;;
        *)
            run_sub_script "Make_SOF_Episode_From_PNG_FLAC_Output_MP4_1080p_Video.sh" "$flac_input" "$cover_input" "$MP4_OUTPUT_DIR"
            ;;
    esac
}

cut_video_clip() {
    echo -e "\n${BOLD}${BLUE}=== CUT VIDEO FILE (.MP4 / .MKV) ===${NC}\n"
    run_sub_script "Cut_Video.sh" "$@"
}

split_flac_audio() {
    echo -e "\n${BOLD}${BLUE}=== SPLIT FLAC AUDIO FILE ===${NC}\n"
    run_sub_script "Split_FLAC_File.sh" "$@"
}

split_video_clip() {
    echo -e "\n${BOLD}${BLUE}=== SPLIT VIDEO FILE (.MP4) ===${NC}\n"
    run_sub_script "Split_Video_File.sh" "$@"
}

manage_video_cut_and_split() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}                   VIDEO CUTTING & SPLITTING SUITE                    ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Cut / Trim Video File by Start & End Time (${GREEN}Cut_Video.sh${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Split Video File (.mp4) into Equal Parts (${GREEN}Split_Video_File.sh${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-3]: " v_choice

        case "$v_choice" in
            1)
                run_sub_script "Cut_Video.sh"
                press_enter
                ;;
            2)
                run_sub_script "Split_Video_File.sh"
                press_enter
                ;;
            3|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

launch_cliamp() {
    echo -e "\n${BOLD}${YELLOW}Launching cliamp Music Player in a new window...${NC}\n"
    local cliamp_bin
    if command -v cliamp >/dev/null 2>&1; then
        cliamp_bin="cliamp"
    elif [ -x "$SCRIPT_DIR/bin/cliamp" ]; then
        cliamp_bin="$SCRIPT_DIR/bin/cliamp"
    elif [ -x "$HOME/.local/bin/cliamp" ]; then
        cliamp_bin="$HOME/.local/bin/cliamp"
    else
        echo -e "${RED}Error: cliamp command not found in PATH or bin!${NC}"
        press_enter
        return 1
    fi

    if launch_in_terminal "cliamp" "$cliamp_bin" "window"; then
        echo -e "${GREEN}✓ cliamp launched in a new window.${NC}"
        sleep 1.2
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window.${NC}"
        press_enter
        return 1
    fi
}

monitor_cliamp_live() {
    echo -e "\n${BOLD}${YELLOW}Starting Real-Time cliamp Monitor (Press 'q' or Ctrl+C to exit)...${NC}\n"
    sleep 0.5
    trap 'break' INT
    while true; do
        if ! get_cliamp_track_info 2>/dev/null; then
            clear
            echo -e "${BOLD}${MAGENTA}=== CLIAMP LIVE TRACKLIST MONITOR ===${NC}\n"
            echo -e "${YELLOW}cliamp is currently idle or no active track is playing.${NC}"
            echo -e "${DIM}Waiting for playback... (Press 'q' to quit)${NC}"
            read -r -t 1 -n 1 key 2>/dev/null || true
            if [[ "$key" == "q" || "$key" == "Q" ]]; then break; fi
            continue
        fi

        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}           CLIAMP LIVE REAL-TIME MONITOR          ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}\n"
        
        local st_badge
        case "$CLIAMP_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
        esac

        local bar_len=32
        local filled_len=$(( CLIAMP_PROGRESS_PCT * bar_len / 100 ))
        local empty_len=$(( bar_len - filled_len ))
        local bar=""
        for ((i=0; i<filled_len; i++)); do bar="${bar}="; done
        if [ $filled_len -lt $bar_len ]; then bar="${bar}>"; empty_len=$((empty_len - 1)); fi
        for ((i=0; i<empty_len; i++)); do bar="${bar}-"; done

        echo -e "  Status:        ${st_badge}"
        echo -e "  Title:         ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC}"
        echo -e "  Artist:        ${BOLD}${WHITE}${CLIAMP_ARTIST}${NC}"
        echo -e "  Position:      ${BOLD}${CYAN}${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}${NC} [${bar}] (${CLIAMP_PROGRESS_PCT}%)"
        echo ""
        echo -e "  ${BOLD}${GREEN}Current File:${NC}  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
        if [ "$CLIAMP_FILE_EXISTS" -eq 1 ]; then
            echo -e "  File Size:     ${GREEN}${CLIAMP_FILE_SIZE}${NC}"
        else
            echo -e "  File Status:   ${RED}File not found at path${NC}"
        fi
        echo ""
        echo -e "${DIM}Shortcuts: [p] Play/Pause  [n] Next  [b] Prev  [c] Copy Path  [o] Open Folder  [q] Exit${NC}"

        read -r -t 1 -n 1 key 2>/dev/null || true
        case "$key" in
            c|C)
                copy_to_clipboard "$CLIAMP_RESOLVED_PATH" || true
                ;;
            o|O)
                open_path "$(dirname "$CLIAMP_RESOLVED_PATH")"
                ;;
            p|P) cliamp toggle 2>/dev/null || true ;;
            n|N) cliamp next 2>/dev/null || true ;;
            b|B) cliamp prev 2>/dev/null || true ;;
            q|Q) break ;;
        esac
    done
    trap 'exit_mix_manager' INT
}

manage_cliamp() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       CLIAMP MUSIC PLAYER & NOW PLAYING INFO     ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""

        if ! get_cliamp_track_info 2>/dev/null; then
            local cliamp_pids
            cliamp_pids=$(pgrep -x cliamp 2>/dev/null)
            if [ -z "$cliamp_pids" ]; then
                echo -e "  Player Status:  ${BOLD}${RED}○ NOT RUNNING${NC}"
            else
                echo -e "  Player Status:  ${BOLD}${YELLOW}● RUNNING (Idle / No Active Track)${NC} (PID: ${cliamp_pids})"
            fi
            echo ""
            echo -e "${BOLD}Options:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Launch cliamp in New Terminal Window"
            echo -e "  ${BOLD}${CYAN}2)${NC} Resume / Start Playback (${GREEN}cliamp play${NC})"
            echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [0-2]: " c_opt
            case "$c_opt" in
                1) launch_cliamp; break ;;
                2) cliamp play 2>/dev/null; sleep 0.5 ;;
                0|q|Q|"") break ;;
                *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
            esac
            continue
        fi

        local pids
        pids=$(pgrep -x cliamp 2>/dev/null | tr '\n' ' ')
        local st_badge
        case "$CLIAMP_STATE" in
            playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
            paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
            stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
            *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
        esac

        local bar_len=30
        local filled_len=$(( CLIAMP_PROGRESS_PCT * bar_len / 100 ))
        local empty_len=$(( bar_len - filled_len ))
        local bar=""
        for ((i=0; i<filled_len; i++)); do bar="${bar}="; done
        if [ $filled_len -lt $bar_len ]; then bar="${bar}>"; empty_len=$((empty_len - 1)); fi
        for ((i=0; i<empty_len; i++)); do bar="${bar}-"; done

        echo -e "  Player Status:  ${st_badge} (PID: ${pids})"
        echo -e "  Current Track:  ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC}"
        echo -e "  Artist:         ${BOLD}${WHITE}${CLIAMP_ARTIST}${NC}"
        echo -e "  Playback Time:  ${BOLD}${CYAN}${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}${NC} [${bar}] (${CLIAMP_PROGRESS_PCT}%)"
        echo ""
        echo -e "  ${BOLD}${GREEN}Current Track File Path:${NC}"
        echo -e "  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
        if [ "$CLIAMP_RAW_PATH" != "$CLIAMP_RESOLVED_PATH" ]; then
            echo -e "  ${DIM}(Raw cliamp Path: ${CLIAMP_RAW_PATH})${NC}"
        fi
        if [ "$CLIAMP_FILE_EXISTS" -eq 1 ]; then
            echo -e "  File Status:    ${GREEN}✓ File exists on disk${NC} (${CLIAMP_FILE_SIZE})"
            local cli_spec
            cli_spec=$(get_playing_audio_spec_summary "$CLIAMP_RESOLVED_PATH")
            [ -n "$cli_spec" ] && echo -e "  Audio Specs:    ${BOLD}${GREEN}${cli_spec}${NC}"
        else
            echo -e "  File Status:    ${RED}✗ File not found at resolved location${NC}"
        fi
        echo ""
        echo -e "${BOLD}Select an operation:${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Copy File Path to Clipboard (${GREEN}System Clipboard${NC})"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Open Containing Folder in File Browser (${GREEN}File Manager${NC})"
        echo -e "  ${BOLD}${CYAN} 3)${NC} View Spek Spectrogram of Current Track"
        echo -e "  ${BOLD}${CYAN} 4)${NC} View Tracklist Text File of Current Track"
        echo -e "  ${BOLD}${CYAN} 5)${NC} View Full Audio File Specifications & Stream Analysis (${GREEN}inspect_audio${NC})"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Play / Pause Toggle (${GREEN}cliamp toggle${NC})"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Skip to Next Track (${GREEN}cliamp next${NC})"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Skip to Previous Track (${GREEN}cliamp prev${NC})"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Launch / Bring Up cliamp Terminal Window"
        echo -e "  ${BOLD}${CYAN}10)${NC} Live Real-Time Monitor (Updates Every Second)"
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-10 or c/o/s/t/i/p/n/b/l/w/Enter]: " c_opt
        case "$c_opt" in
            1|[cC])
                if copy_to_clipboard "$CLIAMP_RESOLVED_PATH"; then
                    echo -e "\n${GREEN}✓ File path copied to clipboard!${NC}"
                else
                    echo -e "\n${YELLOW}Clipboard utility not available.${NC}"
                fi
                sleep 1.2
                ;;
            2|[oO])
                local folder_dir
                folder_dir=$(dirname "$CLIAMP_RESOLVED_PATH")
                if [ -d "$folder_dir" ]; then
                    echo -e "\n${GREEN}Opening $folder_dir in file manager...${NC}"
                    open_path "$folder_dir"
                else
                    echo -e "\n${RED}Directory $folder_dir does not exist!${NC}"
                fi
                sleep 1.2
                ;;
            3|[sS])
                local bname_no_ext
                bname_no_ext=$(basename "$CLIAMP_RESOLVED_PATH")
                bname_no_ext="${bname_no_ext%.*}"
                shopt -s nullglob nocaseglob
                local spek_matches=(SPEK_OUTPUTS/*"${bname_no_ext}"*.png SPEK_OUTPUTS/*"${CLIAMP_TITLE}"*.png)
                shopt -u nullglob nocaseglob
                if [ ${#spek_matches[@]} -gt 0 ] && [ -f "${spek_matches[0]}" ]; then
                    echo -e "\n${GREEN}Opening spectrogram: $(basename "${spek_matches[0]}")...${NC}"
                    open_path "${spek_matches[0]}"
                else
                    echo -e "\n${YELLOW}No matching spectrogram found for '${bname_no_ext}' in SPEK_OUTPUTS/.${NC}"
                fi
                sleep 1.5
                ;;
            4|[tT])
                local bname_no_ext
                bname_no_ext=$(basename "$CLIAMP_RESOLVED_PATH")
                bname_no_ext="${bname_no_ext%.*}"
                shopt -s nullglob nocaseglob
                local tl_matches=("${OUTPUT_DIR}/${bname_no_ext}.txt" "${bname_no_ext}.txt" "${OUTPUT_DIR}/*${CLIAMP_TITLE}*.txt")
                shopt -u nullglob nocaseglob
                local found_tl=""
                for tm in "${tl_matches[@]}"; do
                    if [ -f "$tm" ]; then found_tl="$tm"; break; fi
                done
                if [ -n "$found_tl" ]; then
                    echo -e "\n${BOLD}${CYAN}=== TRACKLIST: $(basename "$found_tl") ===${NC}\n"
                    cat "$found_tl"
                    press_enter
                else
                    echo -e "\n${YELLOW}No tracklist .txt file found for '${bname_no_ext}'.${NC}"
                    sleep 1.5
                fi
                ;;
            5|[iI])
                inspect_playing_audio_file "$CLIAMP_RESOLVED_PATH"
                ;;
            6|[pP])
                cliamp toggle 2>/dev/null || true
                sleep 0.4
                ;;
            7|[nN])
                cliamp next 2>/dev/null || true
                sleep 0.5
                ;;
            8|[bB])
                cliamp prev 2>/dev/null || true
                sleep 0.5
                ;;
            9|[lL])
                launch_cliamp
                break
                ;;
            10|[wW])
                monitor_cliamp_live
                ;;
            0|q|Q|"")
                break
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1
                ;;
        esac
    done
}

launch_strawberry() {
    echo -e "\n${BOLD}${YELLOW}Launching Strawberry Music Player in a new window...${NC}\n"
    if command -v strawberry >/dev/null 2>&1; then
        nohup strawberry >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Strawberry launched in a new window.${NC}"
        sleep 1.2
    else
        echo -e "${RED}Error: strawberry command not found in PATH!${NC}"
        press_enter
        return 1
    fi
}

launch_video_playlists() {
    echo -e "\n${BOLD}${BLUE}=== LAUNCH VIDEO PLAYLISTS (VLC) ===${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Play NFT Videos Playlist in VLC (${GREEN}NFT_VIDEOS.xspf${NC})"
    echo -e "  ${BOLD}${CYAN}2)${NC} Regenerate NFT Playlist from /run/media/mplanetarian/DATA/NFT_VIDEOS"
    echo -e "  ${BOLD}${CYAN}3)${NC} Return to Main Menu"
    echo ""
    read -r -p "Enter choice [1-3]: " v_choice

    case $v_choice in
        1)
            if [ -x "$HOME/.local/bin/update-nft-playlist" ]; then
                "$HOME/.local/bin/update-nft-playlist" --quiet
            fi
            local nft_pl="$HOME/Desktop/DESKTOP/NFT_VIDEOS.xspf"
            [ ! -f "$nft_pl" ] && nft_pl="$HOME/Desktop/NFT_VIDEOS.xspf"
            [ ! -f "$nft_pl" ] && nft_pl="$HOME/Desktop/DESKTOP/NFT_VIDEOS.m3u"
            [ ! -f "$nft_pl" ] && nft_pl="$HOME/Desktop/NFT_VIDEOS.m3u"
            if [ -f "$nft_pl" ]; then
                echo -e "${GREEN}Launching VLC with NFT Videos playlist...${NC}"
                nohup vlc "$nft_pl" >/dev/null 2>&1 &
                sleep 1.2
            else
                echo -e "${RED}Error: NFT Videos playlist not found on Desktop or Desktop/DESKTOP!${NC}"
                press_enter
            fi
            ;;
        2)
            if [ -x "$HOME/.local/bin/update-nft-playlist" ]; then
                "$HOME/.local/bin/update-nft-playlist"
            else
                echo -e "${RED}Error: update-nft-playlist helper not found!${NC}"
            fi
            press_enter
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid selection.${NC}"
            sleep 1
            ;;
    esac
}

close_all_desktop_apps() {
    echo -e "\n${BOLD}${RED}=== CLOSE ALL DESKTOP APPLICATIONS ===${NC}"
    echo -e "${YELLOW}This will close all open desktop application windows while keeping the Manager open.${NC}"
    read -r -p "Are you sure you want to proceed? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Operation canceled.${NC}"
        sleep 1
        return
    fi

    echo -e "\n${CYAN}Identifying active Manager session and closing other windows...${NC}"

    if [ "$OS_TYPE" = "macos" ]; then
        osascript -e 'tell application "System Events"
            set appList to name of every application process whose visible is true and name is not "Terminal" and name is not "iTerm2" and name is not "Finder" and name is not "Ghostty" and name is not "Alacritty" and name is not "kitty"
            repeat with appName in appList
                tell application appName to quit
            end repeat
        end tell' 2>/dev/null
        echo -e "${GREEN}✓ Closed open macOS applications.${NC}"
        press_enter
        return 0
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        powershell.exe -Command "Get-Process | Where-Object { \$_.MainWindowTitle -ne '' -and \$_.ProcessName -notmatch 'bash|cmd|powershell|WindowsTerminal|mintty|conhost|explorer' } | ForEach-Object { \$_.CloseMainWindow() }" 2>/dev/null
        echo -e "${GREEN}✓ Closed open Windows desktop applications.${NC}"
        press_enter
        return 0
    fi

    # 1. Collect PID ancestry of the Manager so we never close it or its parent terminal
    local current_pid=$$
    local mgr_pids=("$current_pid")
    local p=$current_pid
    while [ "$p" -gt 1 ]; do
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        if [ -n "$p" ] && [ "$p" -gt 0 ]; then
            mgr_pids+=("$p")
        else
            break
        fi
    done

    # 2. Convert WINDOWID if present
    local my_win_hex=""
    if [ -n "${WINDOWID:-}" ]; then
        my_win_hex=$(printf "0x%08x" "$WINDOWID" 2>/dev/null || true)
    fi

    local closed_count=0
    if command -v wmctrl >/dev/null 2>&1; then
        while read -r win_id desktop_num win_pid host win_title; do
            # Skip system desktop panels and desktop background (-1)
            if [ "$desktop_num" -lt 0 ] || [[ "$win_title" == *"plasmashell"* ]]; then
                continue
            fi
            
            # Check if this window matches our WINDOWID
            if [ -n "$my_win_hex" ] && [ "$win_id" = "$my_win_hex" ]; then
                continue
            fi

            # Check if window PID belongs to our Manager process hierarchy
            local is_mgr=false
            for mp in "${mgr_pids[@]}"; do
                if [ "$win_pid" = "$mp" ]; then
                    is_mgr=true
                    break
                fi
            done
            if [ "$is_mgr" = true ]; then
                continue
            fi

            # Gracefully close window
            wmctrl -c "$win_id"
            ((closed_count++))
        done < <(wmctrl -lp 2>/dev/null)
    fi

    sleep 1

    # 3. Terminate background GUI / media processes without touching Konsole or Bash
    local apps_to_clean=(
        "vlc"
        "mpv"
        "strawberry"
        "cliamp"
        "btop"
        "nvtop"
        "top"
        "cpu-x"
        "GPUViewer"
        "steam"
        "steamwebhelper"
    )
    for app in "${apps_to_clean[@]}"; do
        pkill -f "$app" 2>/dev/null || true
    done

    echo -e "${GREEN}✓ Closed $closed_count application window(s).${NC}"
    echo -e "${GREEN}✓ Active Mix Archive Manager kept open and protected.${NC}"
    press_enter
}

block_internet() {
    echo -e "\n${BOLD}${RED}=== BLOCK INTERNET ACCESS (LAN ONLY) ===${NC}"
    local script="$HOME/Documents/BASH_SCRIPTS/block-internet"
    [ ! -f "$script" ] && script="$HOME/bin/block-internet"
    if [ -f "$script" ]; then
        echo -e "${YELLOW}Running $script...${NC}\n"
        sudo bash "$script"
    else
        echo -e "${RED}Error: block-internet script not found at $script!${NC}"
    fi
    press_enter
}

unblock_internet() {
    echo -e "\n${BOLD}${GREEN}=== RESTORE / UNBLOCK INTERNET ACCESS ===${NC}"
    local script="$HOME/Documents/BASH_SCRIPTS/unblock-internet"
    [ ! -f "$script" ] && script="$HOME/bin/unblock-internet"
    if [ -f "$script" ]; then
        echo -e "${YELLOW}Running $script...${NC}\n"
        sudo bash "$script"
    else
        echo -e "${RED}Error: unblock-internet script not found at $script!${NC}"
    fi
    press_enter
}

launch_geexlab_demos() {
    echo -e "\n${BOLD}${YELLOW}Launching GeeXLab Demo Launcher (FurMark)...${NC}\n"
    local furmark_dir="/var/home/mplanetarian/Documents/FurMark_linux64"
    if [ -d "$furmark_dir" ] && [ -x "$furmark_dir/demo_launcher.sh" ]; then
        sleep 0.5
        trap ':' INT
        (cd "$furmark_dir" && ./demo_launcher.sh)
        trap 'exit_mix_manager' INT
    else
        echo -e "${RED}Error: demo_launcher.sh not found or not executable in $furmark_dir!${NC}"
        press_enter
    fi
}

list_usb_midi_devices() {
    echo -e "\n${BOLD}${CYAN}=== CONNECTED USB MIDI DEVICES ===${NC}\n"
    if command -v list-midi-devices >/dev/null 2>&1; then
        list-midi-devices
    elif [ -x "$HOME/bin/list-midi-devices" ]; then
        "$HOME/bin/list-midi-devices"
    else
        echo -e "${RED}Error: list-midi-devices command not found in PATH or ~/bin!${NC}"
        press_enter
        return
    fi
    echo ""
    echo -e "${DIM}Options: Press [Enter] to return to menu, or [w] for real-time live monitor...${NC}"
    read -r -p "> " midi_opt
    if [[ "$midi_opt" =~ ^[wW]$ ]]; then
        echo -e "\n${BOLD}${YELLOW}Launching Live MIDI Monitor (Press Ctrl+C to return)...${NC}\n"
        sleep 0.5
        trap ':' INT
        if command -v list-midi-devices >/dev/null 2>&1; then
            list-midi-devices -w
        else
            "$HOME/bin/list-midi-devices" -w
        fi
        trap 'exit_mix_manager' INT
    fi
}

switch_to_wayland() {
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}${YELLOW}macOS uses Quartz / WindowServer compositor.${NC}"
        echo -e "${CYAN}Opening macOS Display Settings...${NC}"
        open "x-apple.systempreferences:com.apple.Displays-Settings.extension" 2>/dev/null || open /System/Library/PreferencePanes/Displays.prefPane 2>/dev/null
        press_enter
        return 0
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}${YELLOW}Windows 10/11 uses Desktop Window Manager (DWM).${NC}"
        echo -e "${CYAN}Opening Windows Display Settings...${NC}"
        cmd.exe /c start ms-settings:display 2>/dev/null
        press_enter
        return 0
    fi

    local script="$SCRIPT_DIR/switch-to-plasma-wayland.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/switch-to-plasma-wayland.sh"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/switch-to-plasma-wayland.sh"
    if [ -x "$script" ]; then
        "$script"
    elif [ -f "$script" ]; then
        bash "$script"
    else
        echo -e "${RED}Error: Switch script not found at $script!${NC}"
        press_enter
    fi
}

switch_to_x11() {
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}${YELLOW}macOS Audio & Sound Configuration.${NC}"
        echo -e "${CYAN}Opening Audio MIDI Setup...${NC}"
        open -a "Audio MIDI Setup" 2>/dev/null || open /System/Applications/Utilities/Audio\ MIDI\ Setup.app 2>/dev/null
        press_enter
        return 0
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}${YELLOW}Windows Audio Control Panel.${NC}"
        echo -e "${CYAN}Opening Windows Sound Settings...${NC}"
        cmd.exe /c start control.exe mmsys.cpl 2>/dev/null
        press_enter
        return 0
    fi

    local script="$SCRIPT_DIR/switch-to-plasma-x11.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/switch-to-plasma-x11.sh"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/switch-to-plasma-x11.sh"
    if [ -x "$script" ]; then
        "$script"
    elif [ -f "$script" ]; then
        bash "$script"
    else
        echo -e "${RED}Error: Switch script not found at $script!${NC}"
        press_enter
    fi
}

launch_wan2gp_terminal() {
    local profile="$1"
    local title="WAN2GP (Profile $profile)"
    local script="$SCRIPT_DIR/scripts/wan2gp.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/wan2gp.sh"
    [ ! -f "$script" ] && script="$HOME/wan2gp.sh"
    [ ! -f "$script" ] && script="/var/home/mplanetarian/MP_Mix_Manager_v0.3/scripts/wan2gp.sh"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/wan2gp.sh"
    local cmd="bash \"$script\" \"$profile\"; echo ''; echo 'WAN2GP finished. Press [Enter] to exit...'; read -r"

    if launch_in_terminal "$title" "$cmd" "tab"; then
        echo -e "${GREEN}✓ WAN2GP launched in a new console tab/window (Profile $profile).${NC}"
        sleep 1.2
        return 0
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
}

launch_wan2gp_flux_batch_terminal() {
    local mode="$1"
    local title="WAN2GP Flux 2 Klein Batch"
    if [[ "$mode" == *"--multi-control"* ]]; then
        title="WAN2GP Flux Multi-Control Batch"
    fi
    local script="$SCRIPT_DIR/scripts/wan2gp_flux_batch.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/wan2gp_flux_batch.py"
    [ ! -f "$script" ] && script="$HOME/wan2gp_flux_batch.py"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/scripts/wan2gp_flux_batch.py"
    [ ! -f "$script" ] && script="/var/home/mplanetarian/MP_Mix_Manager_v0.3/scripts/wan2gp_flux_batch.py"

    if [ ! -f "$script" ]; then
        echo -e "${RED}Error: wan2gp_flux_batch.py not found!${NC}"
        press_enter
        return 1
    fi
    chmod +x "$script" 2>/dev/null || true
    local cmd="bash \"$script\" $mode; echo ''; echo 'Batch process finished. Press [Enter] to exit...'; read -r"

    if launch_in_terminal "$title" "$cmd" "tab"; then
        echo -e "${GREEN}✓ Flux 2 Klein 9B Batch Processor launched in a new console tab/window.${NC}"
        sleep 1.2
        return 0
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
}

launch_wan2gp_ltx_batch_terminal() {
    local mode="$1"
    local model="${2:-2b}"
    local lora="${3:-none}"
    local title="WAN2GP LTX Video ${model^^} Batch"
    if [ -n "$lora" ] && [ "$lora" != "none" ]; then
        title="WAN2GP LTX Video ${model^^} [${lora}]"
    elif [[ "$mode" == *"--no-control"* ]]; then
        title="WAN2GP LTX Video ${model^^} (Pure I2V)"
    elif [[ "$mode" == *"--watch"* ]]; then
        title="WAN2GP LTX Video ${model^^} (Watch Mode)"
    fi
    local script="$SCRIPT_DIR/scripts/wan2gp_ltx_batch.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/wan2gp_ltx_batch.py"
    [ ! -f "$script" ] && script="$HOME/wan2gp_ltx_batch.py"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/scripts/wan2gp_ltx_batch.py"
    [ ! -f "$script" ] && script="/var/home/mplanetarian/MP_Mix_Manager_v0.3/scripts/wan2gp_ltx_batch.py"

    if [ ! -f "$script" ]; then
        echo -e "${RED}Error: wan2gp_ltx_batch.py not found!${NC}"
        press_enter
        return 1
    fi
    chmod +x "$script" 2>/dev/null || true
    local lora_arg=""
    if [ -n "$lora" ] && [ "$lora" != "none" ]; then
        lora_arg="--lora $lora"
    fi
    local cmd="bash \"$script\" --model $model $lora_arg $mode; echo ''; echo 'Batch process finished. Press [Enter] to exit...'; read -r"

    if launch_in_terminal "$title" "$cmd" "tab"; then
        echo -e "${GREEN}✓ LTX Video ${model^^} Batch Processor launched in a new console tab/window.${NC}"
        sleep 1.2
        return 0
    else
        echo -e "${RED}Error: No supported terminal emulator found to launch in a new window/tab.${NC}"
        press_enter
        return 1
    fi
}

clear_wan2gp_logs() {
    local script="$SCRIPT_DIR/clear-wan2gp-logs.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/clear-wan2gp-logs.sh"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/clear-wan2gp-logs.sh"
    if [ -x "$script" ]; then
        "$script"
    elif [ -f "$script" ]; then
        bash "$script"
    else
        echo -e "${RED}Error: Clear WAN2GP logs script not found at $script!${NC}"
        press_enter
    fi
}

run_duplicate_image_remover() {
    echo -e "\n${BOLD}${GREEN}=== BYTE-FOR-BYTE DUPLICATE IMAGE REMOVER ===${NC}\n"
    local script="./remove_duplicate_images.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/remove_duplicate_images.py"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/remove_duplicate_images.py"
    [ ! -f "$script" ] && script="${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}/remove_duplicate_images.py"
    [ ! -f "$script" ] && script="$HOME/Documents/BASH_SCRIPTS/remove_duplicate_images.py"

    if [ -f "$script" ]; then
        python3 "$script"
    else
        echo -e "${RED}Error: remove_duplicate_images.py not found at $script!${NC}"
    fi
    echo ""
    read -r -p "Press [Enter] to return to the WAN2GP menu..."
}


manage_wan2gp() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             WAN2GP SERVER MANAGER                ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""
        
        local wgp_pids
        wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
        if [ -n "$wgp_pids" ]; then
            echo -e "  Server Status:    ${BOLD}${GREEN}● RUNNING${NC} (PID: ${wgp_pids})"
        else
            echo -e "  Server Status:    ${BOLD}${RED}○ STOPPED${NC}"
        fi

        local flux_pids
        flux_pids=$(pgrep -f "wan2gp_flux_batch" | tr '\n' ' ')
        if [ -n "$flux_pids" ]; then
            echo -e "  Flux Batch:       ${BOLD}${GREEN}● RUNNING${NC} (PID: ${flux_pids})"
        else
            echo -e "  Flux Batch:       ${BOLD}${RED}○ STOPPED${NC}"
        fi

        local ltx_pids
        ltx_pids=$(pgrep -f "wan2gp_ltx.*batch" | tr '\n' ' ')
        if [ -n "$ltx_pids" ]; then
            echo -e "  LTX Video Batch:  ${BOLD}${GREEN}● RUNNING${NC} (PID: ${ltx_pids})"
        else
            echo -e "  LTX Video Batch:  ${BOLD}${RED}○ STOPPED${NC}"
        fi

        local ltx_ctrl_dir="/run/media/mplanetarian/DATA/WAN2GP_LTX_BATCH/CTRL_VIDEO"
        if [ -d "$ltx_ctrl_dir" ]; then
            shopt -s nullglob nocaseglob
            local ltx_ctrl_vids=("$ltx_ctrl_dir"/*.mp4 "$ltx_ctrl_dir"/*.mov "$ltx_ctrl_dir"/*.avi "$ltx_ctrl_dir"/*.mkv "$ltx_ctrl_dir"/*.webm)
            shopt -u nullglob nocaseglob
            if [ ${#ltx_ctrl_vids[@]} -gt 0 ]; then
                echo -e "  LTX Control Video:${BOLD}${YELLOW} ${#ltx_ctrl_vids[@]} video(s) detected in CTRL_VIDEO${NC}"
            fi
        fi

        local dup_pids
        dup_pids=$(pgrep -f "remove_duplicate_images\.py" | tr '\n' ' ')
        if [ -n "$dup_pids" ]; then
            echo -e "  Duplicate Cleaner:${BOLD}${GREEN}● RUNNING${NC} (PID: ${dup_pids})"
        fi
        echo ""
        echo -e "${BOLD}Select a WAN2GP operation:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Start in ${BOLD}${GREEN}Profile 2${NC} (High Speed / 2B Models & VRAM-Resident) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}2)${NC} Start in ${BOLD}${YELLOW}Profile 4.5${NC} (Low VRAM / 14B Models Offload) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}3)${NC} Stop Running WAN2GP Server"
        echo -e "  ${BOLD}${CYAN}4)${NC} Restart in ${BOLD}${GREEN}Profile 2${NC} (High Speed / 2B Models) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}5)${NC} Restart in ${BOLD}${YELLOW}Profile 4.5${NC} (Low VRAM / 14B Models) [New Tab/Window]"
        echo -e "  ${BOLD}${CYAN}6)${NC} View Detailed Status & Memory Usage"
        echo -e "  ${BOLD}${CYAN}7)${NC} Clear WAN2GP Logs (${GREEN}clear-wan2gp-logs.sh${NC})"
        echo -e "  ${BOLD}${CYAN}8)${NC} Run Flux2 Klein 9B Batch Image Processor [Single Control Image]"
        echo -e "  ${BOLD}${CYAN}9)${NC} Run Flux2 Klein 9B Batch Image Processor [${BOLD}${YELLOW}Multi-Control Images${NC}] (All in CTRL_IMAGE)"
        echo -e "  ${BOLD}${CYAN}10)${NC} Run Flux2 Klein 9B in ${BOLD}${GREEN}Watch Mode${NC} [Single Control Image]"
        echo -e "  ${BOLD}${CYAN}11)${NC} Run Flux2 Klein 9B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}${YELLOW}Multi-Control Images${NC}]"
        echo -e "  ${BOLD}${CYAN}12)${NC} Run LTX Video 2B Batch Video Processor [${BOLD}${YELLOW}Single Control Video${NC}] (${GREEN}CTRL_VIDEO${NC})"
        echo -e "  ${BOLD}${CYAN}13)${NC} Run LTX Video 2B Batch Video Processor [${BOLD}Pure Image-to-Video${NC}] (No Control Video)"
        echo -e "  ${BOLD}${CYAN}14)${NC} Run LTX Video 2B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}${YELLOW}Single Control Video${NC}]"
        echo -e "  ${BOLD}${CYAN}15)${NC} Run LTX Video 2B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}Pure Image-to-Video${NC}]"
        echo -e "  ${BOLD}${CYAN}16)${NC} Run LTX Video 13B Batch Video Processor [${BOLD}${YELLOW}Single Control Video${NC}] (${GREEN}CTRL_VIDEO${NC})"
        echo -e "  ${BOLD}${CYAN}17)${NC} Run LTX Video 13B Batch Video Processor [${BOLD}Pure Image-to-Video${NC}] (No Control Video)"
        echo -e "  ${BOLD}${CYAN}18)${NC} Run LTX Video 13B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}${YELLOW}Single Control Video${NC}]"
        echo -e "  ${BOLD}${CYAN}19)${NC} Run LTX Video 13B in ${BOLD}${GREEN}Watch Mode${NC} [${BOLD}Pure Image-to-Video${NC}]"
        echo -e "  ${BOLD}${CYAN}20)${NC} Run LTX-2 2.5 22B Batch Processor [${BOLD}${YELLOW}EditAnything v2 LoRA${NC}]"
        echo -e "  ${BOLD}${CYAN}21)${NC} Run LTX-2 2.5 22B Batch Processor [${BOLD}${YELLOW}BFS Head Swap IC-LoRA${NC}]"
        echo -e "  ${BOLD}${CYAN}22)${NC} Run LTX-2 2.5 22B Batch Processor [${BOLD}${YELLOW}Deblur & Decompression LoRAs${NC}]"
        echo -e "  ${BOLD}${CYAN}23)${NC} Run LTX-2 2.5 22B Batch Processor [${BOLD}${GREEN}Clean Base / Video+Audio${NC}]"
        echo -e "  ${BOLD}${CYAN}24)${NC} Scan & Remove Byte-for-Byte Duplicate Images (${GREEN}remove_duplicate_images.py${NC})"
        echo -e "  ${BOLD}${CYAN}25)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [1-25]: " w_choice

        case $w_choice in
            1)
                if [ -n "$wgp_pids" ]; then
                    echo -e "\n${YELLOW}WAN2GP is already running (PID: $wgp_pids). Stop or restart it first.${NC}"
                    sleep 2
                else
                    echo -e "\n${GREEN}Launching WAN2GP in Profile 2...${NC}"
                    launch_wan2gp_terminal "2"
                fi
                ;;
            2)
                if [ -n "$wgp_pids" ]; then
                    echo -e "\n${YELLOW}WAN2GP is already running (PID: $wgp_pids). Stop or restart it first.${NC}"
                    sleep 2
                else
                    echo -e "\n${YELLOW}Launching WAN2GP in Profile 4.5...${NC}"
                    launch_wan2gp_terminal "4.5"
                fi
                ;;
            3)
                echo -e "\n${YELLOW}Stopping WAN2GP...${NC}"
                run_sub_script "wan2gp.sh" stop
                press_enter
                ;;
            4)
                echo -e "\n${YELLOW}Stopping existing WAN2GP instance...${NC}"
                run_sub_script "wan2gp.sh" stop
                sleep 1
                echo -e "${GREEN}Restarting WAN2GP in Profile 2...${NC}"
                launch_wan2gp_terminal "2"
                ;;
            5)
                echo -e "\n${YELLOW}Stopping existing WAN2GP instance...${NC}"
                run_sub_script "wan2gp.sh" stop
                sleep 1
                echo -e "${YELLOW}Restarting WAN2GP in Profile 4.5...${NC}"
                launch_wan2gp_terminal "4.5"
                ;;
            6)
                echo -e "\n${BOLD}${BLUE}=== WAN2GP STATUS ===${NC}\n"
                run_sub_script "wan2gp.sh" status
                press_enter
                ;;
            7)
                clear_wan2gp_logs
                ;;
            8)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B Batch Image Processor (Single Control)...${NC}"
                launch_wan2gp_flux_batch_terminal "--single-control"
                ;;
            9)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B Batch Image Processor (Multi-Control Images)...${NC}"
                launch_wan2gp_flux_batch_terminal "--multi-control"
                ;;
            10)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B in Watch Mode (Single Control)...${NC}"
                launch_wan2gp_flux_batch_terminal "--watch --single-control"
                ;;
            11)
                echo -e "\n${GREEN}Launching Flux 2 Klein 9B in Watch Mode (Multi-Control Images)...${NC}"
                launch_wan2gp_flux_batch_terminal "--watch --multi-control"
                ;;
            12)
                echo -e "\n${GREEN}Launching LTX Video 2B Batch Video Processor (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "2b"
                ;;
            13)
                echo -e "\n${GREEN}Launching LTX Video 2B Batch Video Processor (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--no-control" "2b"
                ;;
            14)
                echo -e "\n${GREEN}Launching LTX Video 2B in Watch Mode (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch" "2b"
                ;;
            15)
                echo -e "\n${GREEN}Launching LTX Video 2B in Watch Mode (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch --no-control" "2b"
                ;;
            16)
                echo -e "\n${GREEN}Launching LTX Video 13B Batch Video Processor (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "13b"
                ;;
            17)
                echo -e "\n${GREEN}Launching LTX Video 13B Batch Video Processor (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--no-control" "13b"
                ;;
            18)
                echo -e "\n${GREEN}Launching LTX Video 13B in Watch Mode (Single Control Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch" "13b"
                ;;
            19)
                echo -e "\n${GREEN}Launching LTX Video 13B in Watch Mode (Pure Image-to-Video)...${NC}"
                launch_wan2gp_ltx_batch_terminal "--watch --no-control" "13b"
                ;;
            20)
                echo -e "\n${GREEN}Launching LTX-2 2.5 22B Batch Processor with EditAnything v2 LoRA...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "25_22b" "editanything_v2"
                ;;
            21)
                echo -e "\n${GREEN}Launching LTX-2 2.5 22B Batch Processor with BFS Head Swap IC-LoRA...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "25_22b" "bfs_head_swap"
                ;;
            22)
                echo -e "\n${GREEN}Launching LTX-2 2.5 22B Batch Processor with Deblur LoRA...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "25_22b" "deblur"
                ;;
            23)
                echo -e "\n${GREEN}Launching LTX-2 2.5 22B Batch Processor (Clean Base / Video+Audio)...${NC}"
                launch_wan2gp_ltx_batch_terminal "" "25_22b" "none"
                ;;
            24)
                run_duplicate_image_remover
                ;;
            25)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

manage_beszel() {
    run_sub_script "beszel.sh" "$@"
}

manage_ollama() {
    run_sub_script "manage_ollama.sh" "$@"
}

manage_dsh_mobile() {
    run_sub_script "dsh_mobile.sh" "$@"
}

launch_dsh_mobile() {
    run_sub_script "dsh_mobile.sh" start
}

_control_net_service() {
    local action="$1" # start, stop, restart
    local target="$2" # all, ssh, smb, ftp

    if command -v systemctl >/dev/null 2>&1; then
        case "$target" in
            all) sudo systemctl "$action" sshd smb nmb wsdd vsftpd 2>/dev/null || true ;;
            ssh) sudo systemctl "$action" sshd ;;
            smb) sudo systemctl "$action" smb nmb wsdd ;;
            ftp) sudo systemctl "$action" vsftpd ;;
        esac
    elif [ "$OS_TYPE" = "freebsd" ] || command -v service >/dev/null 2>&1; then
        case "$target" in
            all)
                sudo service sshd "$action" 2>/dev/null || true
                sudo service samba_server "$action" 2>/dev/null || sudo service smbd "$action" 2>/dev/null || true
                sudo service vsftpd "$action" 2>/dev/null || sudo service ftpd "$action" 2>/dev/null || true
                ;;
            ssh) sudo service sshd "$action" 2>/dev/null || true ;;
            smb) sudo service samba_server "$action" 2>/dev/null || sudo service smbd "$action" 2>/dev/null || true ;;
            ftp) sudo service vsftpd "$action" 2>/dev/null || sudo service ftpd "$action" 2>/dev/null || true ;;
        esac
    elif [ "$OS_TYPE" = "macos" ]; then
        case "$target" in
            all)
                sudo systemsetup -setremotelogin "$([ "$action" = "stop" ] && echo "off" || echo "on")" 2>/dev/null || true
                if [ "$action" = "start" ]; then sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null || true
                elif [ "$action" = "stop" ]; then sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null || true
                fi
                ;;
            ssh)
                if [ "$action" = "start" ]; then sudo systemsetup -setremotelogin on 2>/dev/null || sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null
                elif [ "$action" = "stop" ]; then sudo systemsetup -setremotelogin off 2>/dev/null || sudo launchctl unload -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null
                else sudo launchctl stop com.openssh.sshd 2>/dev/null; sudo launchctl start com.openssh.sshd 2>/dev/null; fi
                ;;
            smb)
                if [ "$action" = "start" ]; then sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null
                elif [ "$action" = "stop" ]; then sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null
                else sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null; sleep 0.5; sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null; fi
                ;;
            ftp)
                echo -e "${YELLOW}macOS does not provide a built-in FTP daemon in modern versions.${NC}"
                ;;
        esac
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        if command -v powershell.exe >/dev/null 2>&1; then
            local ps_action="Start-Service"
            [ "$action" = "stop" ] && ps_action="Stop-Service"
            [ "$action" = "restart" ] && ps_action="Restart-Service"
            case "$target" in
                all) powershell.exe -NoProfile -Command "$ps_action -Name 'sshd','LanmanServer' -ErrorAction SilentlyContinue" 2>/dev/null || true ;;
                ssh) powershell.exe -NoProfile -Command "$ps_action -Name 'sshd' -ErrorAction SilentlyContinue" 2>/dev/null || true ;;
                smb) powershell.exe -NoProfile -Command "$ps_action -Name 'LanmanServer' -ErrorAction SilentlyContinue" 2>/dev/null || true ;;
                ftp) powershell.exe -NoProfile -Command "$ps_action -Name 'ftpsvc' -ErrorAction SilentlyContinue" 2>/dev/null || true ;;
            esac
        else
            echo -e "${YELLOW}Please manage Windows Services using services.msc.${NC}"
        fi
    else
        echo -e "${RED}No supported service manager found (systemctl or service).${NC}"
    fi
}

manage_network_services() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}          NETWORK SERVICES MANAGER                ${NC}"
        echo -e "${BOLD}${MAGENTA}       (SSH, Samba File Sharing, vsftpd FTP)      ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""

        local ssh_status="${BOLD}${RED}○ STOPPED${NC}"
        if (command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet sshd 2>/dev/null) || pgrep -x sshd >/dev/null; then
            local ssh_pids
            ssh_pids=$(pgrep -x sshd | tr '\n' ' ')
            ssh_status="${BOLD}${GREEN}● RUNNING${NC} (Port 22, PID: ${ssh_pids})"
        fi

        local smb_status="${BOLD}${RED}○ STOPPED${NC}"
        if (command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet smb 2>/dev/null) || pgrep -x smbd >/dev/null; then
            local smb_pids
            smb_pids=$(pgrep -x smbd | tr '\n' ' ')
            smb_status="${BOLD}${GREEN}● RUNNING${NC} (Ports 139, 445, PID: ${smb_pids})"
        fi

        local ftp_status="${BOLD}${RED}○ STOPPED${NC}"
        if (command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet vsftpd 2>/dev/null) || pgrep -x vsftpd >/dev/null || pgrep -x ftpd >/dev/null; then
            local ftp_pids
            ftp_pids=$( (pgrep -x vsftpd 2>/dev/null || pgrep -x ftpd 2>/dev/null) | tr '\n' ' ')
            ftp_status="${BOLD}${GREEN}● RUNNING${NC} (Port 21, PID: ${ftp_pids})"
        fi

        echo -e "  SSH Server (sshd):          ${ssh_status}"
        echo -e "  Samba Share (smbd/wsdd):    ${smb_status}"
        echo -e "  FTP Server (vsftpd/ftpd):   ${ftp_status}"
        echo ""
        echo -e "${BOLD}Bulk Actions (All Services):${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} ${GREEN}Start All Services${NC}   (SSH, SMB, FTP)"
        echo -e "  ${BOLD}${CYAN}2)${NC} ${RED}Stop All Services${NC}    (SSH, SMB, FTP)"
        echo -e "  ${BOLD}${CYAN}3)${NC} ${YELLOW}Restart All Services${NC} (SSH, SMB, FTP)"
        echo ""
        echo -e "${BOLD}Individual Service Controls:${NC}"
        echo -e "  ${BOLD}${CYAN}4)${NC} Start SSH               ${BOLD}${CYAN}7)${NC} Start Samba (SMB)        ${BOLD}${CYAN}10)${NC} Start FTP"
        echo -e "  ${BOLD}${CYAN}5)${NC} Stop SSH                ${BOLD}${CYAN}8)${NC} Stop Samba (SMB)         ${BOLD}${CYAN}11)${NC} Stop FTP"
        echo -e "  ${BOLD}${CYAN}6)${NC} Restart SSH             ${BOLD}${CYAN}9)${NC} Restart Samba (SMB)      ${BOLD}${CYAN}12)${NC} Restart FTP"
        echo ""
        echo -e "  ${BOLD}${CYAN}13)${NC} View Detailed Service Status"
        echo -e "  ${BOLD}${CYAN}14)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [1-14]: " s_choice

        case $s_choice in
            1)
                echo -e "\n${BOLD}${GREEN}Starting all network services (SSH, SMB, FTP)...${NC}\n"
                _control_net_service "start" "all"
                sleep 1
                press_enter
                ;;
            2)
                echo -e "\n${BOLD}${RED}Stopping all network services (SSH, SMB, FTP)...${NC}\n"
                _control_net_service "stop" "all"
                sleep 1
                press_enter
                ;;
            3)
                echo -e "\n${BOLD}${YELLOW}Restarting all network services (SSH, SMB, FTP)...${NC}\n"
                _control_net_service "restart" "all"
                sleep 1
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${GREEN}Starting SSH Server (sshd)...${NC}\n"
                _control_net_service "start" "ssh"
                sleep 1
                press_enter
                ;;
            5)
                echo -e "\n${BOLD}${RED}Stopping SSH Server (sshd)...${NC}\n"
                _control_net_service "stop" "ssh"
                sleep 1
                press_enter
                ;;
            6)
                echo -e "\n${BOLD}${YELLOW}Restarting SSH Server (sshd)...${NC}\n"
                _control_net_service "restart" "ssh"
                sleep 1
                press_enter
                ;;
            7)
                echo -e "\n${BOLD}${GREEN}Starting Samba Server (smb, nmb, wsdd)...${NC}\n"
                _control_net_service "start" "smb"
                sleep 1
                press_enter
                ;;
            8)
                echo -e "\n${BOLD}${RED}Stopping Samba Server (smb, nmb, wsdd)...${NC}\n"
                _control_net_service "stop" "smb"
                sleep 1
                press_enter
                ;;
            9)
                echo -e "\n${BOLD}${YELLOW}Restarting Samba Server (smb, nmb, wsdd)...${NC}\n"
                _control_net_service "restart" "smb"
                sleep 1
                press_enter
                ;;
            10)
                echo -e "\n${BOLD}${GREEN}Starting FTP Server (vsftpd)...${NC}\n"
                _control_net_service "start" "ftp"
                sleep 1
                press_enter
                ;;
            11)
                echo -e "\n${BOLD}${RED}Stopping FTP Server (vsftpd)...${NC}\n"
                _control_net_service "stop" "ftp"
                sleep 1
                press_enter
                ;;
            12)
                echo -e "\n${BOLD}${YELLOW}Restarting FTP Server (vsftpd)...${NC}\n"
                _control_net_service "restart" "ftp"
                sleep 1
                press_enter
                ;;
            13)
                echo -e "\n${BOLD}${BLUE}=== DETAILED NETWORK SERVICES STATUS ===${NC}\n"
                if command -v systemctl >/dev/null 2>&1; then
                    systemctl status sshd smb wsdd vsftpd --no-pager -l
                elif [ "$OS_TYPE" = "freebsd" ] || command -v service >/dev/null 2>&1; then
                    echo -e "${CYAN}--- SSH Server ---${NC}"
                    service sshd status 2>/dev/null || true
                    echo -e "\n${CYAN}--- Samba File Sharing ---${NC}"
                    service samba_server status 2>/dev/null || service smbd status 2>/dev/null || true
                    echo -e "\n${CYAN}--- FTP Server ---${NC}"
                    service vsftpd status 2>/dev/null || service ftpd status 2>/dev/null || true
                elif [ "$OS_TYPE" = "macos" ]; then
                    echo -e "${CYAN}--- SSH Server ---${NC}"
                    sudo systemsetup -getremotelogin 2>/dev/null || launchctl list | grep ssh || true
                    echo -e "\n${CYAN}--- Samba File Sharing ---${NC}"
                    launchctl list | grep smbd || true
                elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
                    if command -v powershell.exe >/dev/null 2>&1; then
                        powershell.exe -NoProfile -Command "Get-Service -Name 'sshd','LanmanServer','ftpsvc' -ErrorAction SilentlyContinue | Format-Table -AutoSize" 2>/dev/null || true
                    fi
                fi
                echo ""
                press_enter
                ;;
            14)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

launch_system_process_monitor() {
    local refresh="${1:-10}"
    local mon="$SCRIPT_DIR/scripts/MP_Monitor_Bash.sh"
    [ ! -f "$mon" ] && mon="$SCRIPT_DIR/MP_Monitor_Bash.sh"
    if [ ! -f "$mon" ]; then
        echo -e "\n${RED}Monitor script not found: MP_Monitor_Bash.sh${NC}"
        press_enter
        return 1
    fi

    local mon_q dir_q run_cmd
    mon_q="$(printf '%q' "$mon")"
    dir_q="$(printf '%q' "$SCRIPT_DIR")"
    run_cmd="cd ${dir_q} && exec bash ${mon_q} --refresh ${refresh}"

    echo -e "\n${BOLD}${GREEN}Opening Monitor System Processes and Bash Commands with System Info in a new terminal tab...${NC}\n"
    if launch_in_terminal "Monitor System Processes and Bash Commands with System Info" "$run_cmd" "tab"; then
        echo -e "${GREEN}✓ Monitor is running in a new tab of this Terminal. This menu stays here.${NC}"
        echo -e "${DIM}Refresh interval: ${refresh}s. History log: ${SCRIPT_DIR}/running_history.log${NC}"
        sleep 1.2
    else
        echo -e "${YELLOW}No separate terminal tab was available. Running the monitor here. Ctrl+C returns to the menu.${NC}\n"
        sleep 0.6
        trap ':' INT
        bash "$mon" --refresh "$refresh"
        trap 'exit_mix_manager' INT
        press_enter
    fi
}

manage_process_and_bash_monitor() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA} Monitor System Processes and Bash Commands with System Info ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""
        echo -e "  ${DIM}macOS and Linux. Opens in a new tab of the terminal running Mix Manager.${NC}"
        echo -e "  ${DIM}Snapshots append to running_history.log and are never cleared.${NC}"
        echo ""
        echo -e "  ${BOLD}${CYAN}1)${NC} Launch monitor ${GREEN}(refresh every 10 seconds)${NC}"
        echo -e "  ${BOLD}${CYAN}2)${NC} Launch monitor ${GREEN}(refresh every 5 seconds)${NC}"
        echo -e "  ${BOLD}${CYAN}3)${NC} Launch monitor ${GREEN}(refresh every 2 seconds)${NC}"
        echo -e "  ${BOLD}${CYAN}4)${NC} Return"
        echo ""
        read -r -p "Enter choice [1-4]: " mon_choice
        case "$mon_choice" in
            1) launch_system_process_monitor 10 ;;
            2) launch_system_process_monitor 5 ;;
            3) launch_system_process_monitor 2 ;;
            4|0|[qQ]|back) return 0 ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

manage_system_maintenance() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        if [ "$OS_TYPE" = "macos" ]; then
            echo -e "${BOLD}${MAGENTA}         macOS SYSTEM MAINTENANCE & CLEANUP       ${NC}"
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            echo -e "${BOLD}${MAGENTA}       WINDOWS 10/11 MAINTENANCE & CLEANUP        ${NC}"
        elif [ "$OS_TYPE" = "freebsd" ]; then
            echo -e "${BOLD}${MAGENTA}        FreeBSD SYSTEM MAINTENANCE & CLEANUP      ${NC}"
        else
            echo -e "${BOLD}${MAGENTA}           SYSTEM MAINTENANCE & CLEANUP           ${NC}"
        fi
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""

        if [ "$OS_TYPE" = "macos" ]; then
            local brew_count="N/A"
            local brew_formulae="N/A"
            if command -v brew >/dev/null 2>&1; then
                brew_count=$(brew list --cask 2>/dev/null | wc -l | tr -d ' ')
                brew_formulae=$(brew list --formula 2>/dev/null | wc -l | tr -d ' ')
                echo -e "  Homebrew Packages Installed: ${CYAN}${brew_formulae} formulae, ${brew_count} casks${NC}"
            fi
            echo -e "  macOS Version:               ${GREEN}$(sw_vers -productVersion 2>/dev/null || uname -r)${NC}"
            echo ""
            echo -e "${BOLD}Select a maintenance operation:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Check Drive Space Statistics (${GREEN}Get_All_Drive_Space.sh${NC}) [Mounted & Unmounted]"
            echo -e "  ${BOLD}${CYAN}2)${NC} Open macOS Software Update Window (${GREEN}System Settings / Software Update${NC})"
            echo -e "  ${BOLD}${CYAN}3)${NC} Clean Homebrew Caches & Old Packages (${GREEN}brew cleanup -s && brew autoremove${NC})"
            echo -e "  ${BOLD}${CYAN}4)${NC} Full Homebrew Package Upgrade (${GREEN}brew update && brew upgrade${NC})"
            echo -e "  ${BOLD}${CYAN}5)${NC} Purge Inactive System RAM Memory (${GREEN}sudo purge${NC})"
            echo -e "  ${BOLD}${CYAN}6)${NC} Clear User Caches & Temporary Files (${GREEN}rm -rf ~/Library/Caches/*${NC})"
            echo -e "  ${BOLD}${CYAN}7)${NC} ${BOLD}${YELLOW}Run Complete macOS Maintenance Suite${NC}"
            echo -e "  ${BOLD}${CYAN}8)${NC} Monitor System Processes and Bash Commands with System Info ${GREEN}(MP_Monitor_Bash.sh, new Terminal tab)${NC}"
            echo -e "  ${BOLD}${CYAN}9)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [1-9, or m]: " m_choice
            case "$m_choice" in
                1)
                    local drive_sh="$SCRIPT_DIR/Get_All_Drive_Space.sh"
                    [ ! -f "$drive_sh" ] && drive_sh="$SCRIPT_DIR/scripts/Get_All_Drive_Space.sh"
                    if [ -f "$drive_sh" ]; then
                        echo ""
                        bash "$drive_sh"
                    else
                        echo -e "\n${RED}Drive space script not found: $drive_sh${NC}"
                    fi
                    echo ""
                    press_enter
                    ;;
                2)
                    echo -e "\n${BOLD}${YELLOW}Opening macOS Software Update Window in System Settings...${NC}\n"
                    open "x-apple.systempreferences:com.apple.preferences.softwareupdate" 2>/dev/null || open /System/Library/PreferencePanes/SoftwareUpdate.prefPane 2>/dev/null || true
                    echo -e "${GREEN}✓ macOS Software Update settings opened.${NC}"
                    press_enter
                    ;;
                3)
                    echo -e "\n${BOLD}${YELLOW}Cleaning Homebrew...${NC}\n"
                    brew cleanup -s && brew autoremove
                    press_enter
                    ;;
                4)
                    echo -e "\n${BOLD}${YELLOW}Updating Homebrew & packages...${NC}\n"
                    brew update && brew upgrade
                    press_enter
                    ;;
                5)
                    echo -e "\n${BOLD}${YELLOW}Purging inactive memory...${NC}\n"
                    sudo purge 2>/dev/null || purge 2>/dev/null || echo "Purge completed."
                    press_enter
                    ;;
                6)
                    echo -e "\n${BOLD}${YELLOW}Clearing user caches...${NC}\n"
                    rm -rf ~/Library/Caches/* 2>/dev/null || true
                    echo -e "${GREEN}✓ User caches cleared.${NC}"
                    press_enter
                    ;;
                7)
                    echo -e "\n${BOLD}${GREEN}=== RUNNING COMPLETE macOS CLEANUP SUITE ===${NC}\n"
                    echo -e "${BOLD}${BLUE}[1/4] Opening Software Update window...${NC}"
                    open "x-apple.systempreferences:com.apple.preferences.softwareupdate" 2>/dev/null || open /System/Library/PreferencePanes/SoftwareUpdate.prefPane 2>/dev/null || true
                    echo -e "${BOLD}${BLUE}[2/4] Cleaning Homebrew caches...${NC}"
                    command -v brew >/dev/null 2>&1 && brew cleanup -s && brew autoremove
                    echo -e "${BOLD}${BLUE}[3/4] Clearing user caches...${NC}"
                    rm -rf ~/Library/Caches/* 2>/dev/null || true
                    echo -e "${BOLD}${BLUE}[4/4] Purging inactive RAM...${NC}"
                    sudo purge 2>/dev/null || true
                    echo -e "${GREEN}✓ Cleanup suite finished!${NC}"
                    press_enter
                    ;;
                8|m|monitor|mp-monitor)
                    manage_process_and_bash_monitor
                    ;;
                9|0|[qQ])
                    return 0
                    ;;
                *)
                    echo -e "\n${RED}Invalid choice!${NC}"
                    sleep 1.2
                    ;;
            esac
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            echo -e "  Windows Edition:             ${GREEN}$(cmd.exe /c "ver" 2>/dev/null | tr -d '\r\n' || echo "Windows 10/11")${NC}"
            echo ""
            echo -e "${BOLD}Select a maintenance operation:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Check Drive Space Statistics (${GREEN}Get_All_Drive_Space.sh${NC}) [Mounted & Unmounted]"
            echo -e "  ${BOLD}${CYAN}2)${NC} Open Windows Update Window (${GREEN}ms-settings:windowsupdate${NC})"
            echo -e "  ${BOLD}${CYAN}3)${NC} Upgrade All Installed Packages (${GREEN}winget upgrade --all${NC})"
            echo -e "  ${BOLD}${CYAN}4)${NC} Clear Windows Temporary Files (${GREEN}%TEMP% & System Temp${NC})"
            echo -e "  ${BOLD}${CYAN}5)${NC} Empty Windows Recycle Bin (${GREEN}Clear-RecycleBin${NC})"
            echo -e "  ${BOLD}${CYAN}6)${NC} Optimize / TRIM Primary Drive C: (${GREEN}Optimize-Volume${NC})"
            echo -e "  ${BOLD}${CYAN}7)${NC} ${BOLD}${YELLOW}Run Complete Windows Maintenance Suite${NC}"
            echo -e "  ${BOLD}${CYAN}8)${NC} Monitor System Processes and Bash Commands with System Info ${GREEN}(MP_Monitor_Bash.sh, new Terminal tab)${NC}"
            echo -e "  ${BOLD}${CYAN}9)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [1-9, or m]: " m_choice
            case "$m_choice" in
                1)
                    local drive_sh="$SCRIPT_DIR/Get_All_Drive_Space.sh"
                    [ ! -f "$drive_sh" ] && drive_sh="$SCRIPT_DIR/scripts/Get_All_Drive_Space.sh"
                    if [ -f "$drive_sh" ]; then
                        echo ""
                        bash "$drive_sh"
                    else
                        echo -e "\n${RED}Drive space script not found: $drive_sh${NC}"
                    fi
                    echo ""
                    press_enter
                    ;;
                2)
                    echo -e "\n${BOLD}${YELLOW}Opening Windows Update Window in Settings...${NC}\n"
                    cmd.exe /c "start ms-settings:windowsupdate" 2>/dev/null || powershell.exe -Command "Start-Process 'ms-settings:windowsupdate'" 2>/dev/null || true
                    echo -e "${GREEN}✓ Windows Update window opened.${NC}"
                    press_enter
                    ;;
                3)
                    echo -e "\n${BOLD}${YELLOW}Upgrading packages via winget...${NC}\n"
                    cmd.exe /c "winget upgrade --all" 2>/dev/null || echo -e "${RED}winget not found.${NC}"
                    press_enter
                    ;;
                4)
                    echo -e "\n${BOLD}${YELLOW}Clearing Windows temp directory...${NC}\n"
                    powershell.exe -Command "Remove-Item -Path \$env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    echo -e "${GREEN}✓ Temporary files removed.${NC}"
                    press_enter
                    ;;
                5)
                    echo -e "\n${BOLD}${YELLOW}Emptying Recycle Bin...${NC}\n"
                    powershell.exe -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    echo -e "${GREEN}✓ Recycle bin emptied.${NC}"
                    press_enter
                    ;;
                6)
                    echo -e "\n${BOLD}${YELLOW}Optimizing C: drive...${NC}\n"
                    powershell.exe -Command "Optimize-Volume -DriveLetter C -Verbose" 2>/dev/null || true
                    press_enter
                    ;;
                7)
                    echo -e "\n${BOLD}${GREEN}=== RUNNING COMPLETE WINDOWS CLEANUP SUITE ===${NC}\n"
                    echo -e "${BOLD}${BLUE}[1/5] Opening Windows Update window...${NC}"
                    cmd.exe /c "start ms-settings:windowsupdate" 2>/dev/null || powershell.exe -Command "Start-Process 'ms-settings:windowsupdate'" 2>/dev/null || true
                    echo -e "${BOLD}${BLUE}[2/5] Clearing temporary files...${NC}"
                    powershell.exe -Command "Remove-Item -Path \$env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    echo -e "${BOLD}${BLUE}[3/5] Emptying Recycle Bin...${NC}"
                    powershell.exe -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" 2>/dev/null || true
                    echo -e "${BOLD}${BLUE}[4/5] Upgrading installed applications via winget...${NC}"
                    cmd.exe /c "winget upgrade --all" 2>/dev/null || true
                    echo -e "${BOLD}${BLUE}[5/5] Optimizing C: drive...${NC}"
                    powershell.exe -Command "Optimize-Volume -DriveLetter C -Verbose" 2>/dev/null || true
                    echo -e "${GREEN}✓ Windows maintenance suite finished!${NC}"
                    press_enter
                    ;;
                8|m|monitor|mp-monitor)
                    manage_process_and_bash_monitor
                    ;;
                9|0|[qQ])
                    return 0
                    ;;
                *)
                    echo -e "\n${RED}Invalid choice!${NC}"
                    sleep 1.2
                    ;;
            esac
        elif [ "$OS_TYPE" = "freebsd" ]; then
            local pkg_count="N/A"
            if command -v pkg >/dev/null 2>&1; then
                pkg_count=$(pkg info 2>/dev/null | wc -l | tr -d ' ')
            fi
            echo -e "  FreeBSD Version:             ${GREEN}$(uname -r) ($(uname -m))${NC}"
            echo -e "  Packages Installed (pkg):    ${CYAN}${pkg_count}${NC}"
            echo ""
            echo -e "${BOLD}Select a maintenance operation:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Check Drive Space Statistics (${GREEN}Get_All_Drive_Space.sh${NC}) [Mounted & Unmounted]"
            echo -e "  ${BOLD}${CYAN}2)${NC} Clean Package Caches & Old Deps (${GREEN}pkg clean -a && pkg autoremove${NC})"
            echo -e "  ${BOLD}${CYAN}3)${NC} Full FreeBSD Package Upgrade (${GREEN}pkg upgrade${NC})"
            echo -e "  ${BOLD}${CYAN}4)${NC} Audit Installed Packages for Vulnerabilities (${GREEN}pkg audit -F${NC})"
            echo -e "  ${BOLD}${CYAN}5)${NC} Clear User Caches & /tmp (${GREEN}rm -rf ~/.cache/* /tmp/*${NC})"
            echo -e "  ${BOLD}${CYAN}6)${NC} ${BOLD}${YELLOW}Run Complete FreeBSD Maintenance Suite${NC}"
            echo -e "  ${BOLD}${CYAN}7)${NC} Monitor System Processes and Bash Commands with System Info ${GREEN}(MP_Monitor_Bash.sh, new Terminal tab)${NC}"
            echo -e "  ${BOLD}${CYAN}8)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [1-8, or m]: " m_choice
            case "$m_choice" in
                1)
                    local drive_sh="$SCRIPT_DIR/Get_All_Drive_Space.sh"
                    [ ! -f "$drive_sh" ] && drive_sh="$SCRIPT_DIR/scripts/Get_All_Drive_Space.sh"
                    if [ -f "$drive_sh" ]; then
                        echo ""
                        bash "$drive_sh"
                    else
                        echo -e "\n${RED}Drive space script not found: $drive_sh${NC}"
                    fi
                    echo ""
                    press_enter
                    ;;
                2)
                    echo -e "\n${BOLD}${YELLOW}Cleaning pkg caches...${NC}\n"
                    sudo pkg clean -a -y && sudo pkg autoremove -y || pkg clean -a -y
                    press_enter
                    ;;
                3)
                    echo -e "\n${BOLD}${YELLOW}Upgrading FreeBSD packages...${NC}\n"
                    sudo pkg upgrade || pkg upgrade
                    press_enter
                    ;;
                4)
                    echo -e "\n${BOLD}${YELLOW}Auditing FreeBSD packages...${NC}\n"
                    pkg audit -F
                    press_enter
                    ;;
                5)
                    echo -e "\n${BOLD}${YELLOW}Clearing user cache and /tmp...${NC}\n"
                    rm -rf ~/.cache/* 2>/dev/null || true
                    echo -e "${GREEN}✓ User caches cleared.${NC}"
                    press_enter
                    ;;
                6)
                    echo -e "\n${BOLD}${GREEN}=== RUNNING COMPLETE FreeBSD CLEANUP SUITE ===${NC}\n"
                    sudo pkg clean -a -y 2>/dev/null || true
                    sudo pkg autoremove -y 2>/dev/null || true
                    pkg audit -F 2>/dev/null || true
                    rm -rf ~/.cache/* 2>/dev/null || true
                    echo -e "${GREEN}✓ FreeBSD maintenance suite finished!${NC}"
                    press_enter
                    ;;
                7|m|monitor|mp-monitor)
                    manage_process_and_bash_monitor
                    ;;
                8|0|[qQ])
                    return 0
                    ;;
                *)
                    echo -e "\n${RED}Invalid choice!${NC}"
                    sleep 1.2
                    ;;
            esac
        else
            local journal_usage
            journal_usage=$(journalctl --disk-usage 2>/dev/null | grep -o '[0-9.]*[KMGT]B*' || echo "N/A")
            echo -e "  System Journal Log Usage:   ${CYAN}${journal_usage}${NC}"

            if command -v free >/dev/null 2>&1; then
                local ram_info
                ram_info=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2 " used, " $6 " cached, " $7 " avail"}')
                [ -n "$ram_info" ] && echo -e "  System Memory (RAM):        ${CYAN}${ram_info}${NC}"
            fi

            local distro_desc=""
            if [ -f /etc/os-release ]; then
                distro_desc=$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
            fi
            [ -z "$distro_desc" ] && distro_desc="Linux ($(uname -r))"

            if command -v rpm-ostree >/dev/null 2>&1; then
                local ostree_status
                ostree_status=$(rpm-ostree status 2>/dev/null | grep -E '^\*? State:' | head -n 1 | awk '{print $2}' || echo "idle")
                [ -z "$ostree_status" ] && ostree_status="idle"
                echo -e "  Operating System:           ${GREEN}${distro_desc}${NC} (rpm-ostree: ${ostree_status})"
            else
                echo -e "  Operating System:           ${GREEN}${distro_desc}${NC}"
            fi
            echo ""

            local clean_label="Clean System (Package Caches, Unused Runtimes)"
            local update_label="Full System & Package Update"

            if command -v ujust >/dev/null 2>&1; then
                clean_label="Clean System (${GREEN}ujust clean-system${NC}) [Podman, Flatpak, ostree, Brew]"
                update_label="Full System & Package Update (${GREEN}ujust update${NC}) [OS, Flatpaks, Brew]"
            elif command -v dnf5 >/dev/null 2>&1; then
                clean_label="Clean System (${GREEN}sudo dnf5 clean all && autoremove${NC}) [DNF caches, Flatpaks]"
                update_label="Full System & Package Update (${GREEN}sudo dnf5 upgrade --refresh${NC}) [Fedora packages, Flatpaks]"
            elif command -v dnf >/dev/null 2>&1; then
                clean_label="Clean System (${GREEN}sudo dnf clean all && autoremove${NC}) [DNF caches, Flatpaks]"
                update_label="Full System & Package Update (${GREEN}sudo dnf upgrade --refresh${NC}) [Fedora / RHEL packages, Flatpaks]"
            elif command -v rpm-ostree >/dev/null 2>&1; then
                clean_label="Clean System (${GREEN}rpm-ostree cleanup -m${NC}) [ostree, Flatpaks]"
                update_label="Full System & Package Update (${GREEN}rpm-ostree upgrade${NC}) [Atomic OS, Flatpaks]"
            elif command -v apt-get >/dev/null 2>&1; then
                clean_label="Clean System (${GREEN}sudo apt autoremove && clean${NC}) [APT caches, Flatpaks]"
                update_label="Full System & Package Update (${GREEN}sudo apt update && upgrade${NC}) [Debian/Ubuntu packages, Flatpaks]"
            elif command -v pacman >/dev/null 2>&1; then
                clean_label="Clean System (${GREEN}sudo pacman -Sc${NC}) [Pacman caches, Flatpaks]"
                update_label="Full System & Package Update (${GREEN}sudo pacman -Syu${NC}) [Arch packages, Flatpaks]"
            elif command -v zypper >/dev/null 2>&1; then
                clean_label="Clean System (${GREEN}sudo zypper clean -a${NC}) [Zypper caches, Flatpaks]"
                update_label="Full System & Package Update (${GREEN}sudo zypper refresh && update${NC}) [openSUSE packages]"
            fi

            echo -e "${BOLD}Select a maintenance operation:${NC}"
            echo -e "  ${BOLD}${CYAN}1)${NC} Check Drive Space Statistics (${GREEN}Get_All_Drive_Space.sh${NC}) [Mounted & Unmounted]"
            echo -e "  ${BOLD}${CYAN}2)${NC} ${clean_label}"
            echo -e "  ${BOLD}${CYAN}3)${NC} ${update_label}"
            echo -e "  ${BOLD}${CYAN}4)${NC} Vacuum System Logs (${GREEN}sudo journalctl --vacuum-size=200M${NC})"
            echo -e "  ${BOLD}${CYAN}5)${NC} Optimize & Trim SSD Storage (${GREEN}sudo fstrim -av${NC})"
            echo -e "  ${BOLD}${CYAN}6)${NC} Clear System Memory & Page Cache (${GREEN}sudo sync && drop_caches=3${NC})"
            echo -e "  ${BOLD}${CYAN}7)${NC} ${BOLD}${YELLOW}Run Complete Cleanup Suite${NC} (Clean System + Drop RAM Cache + Vacuum Logs + SSD Trim)"
            echo -e "  ${BOLD}${CYAN}8)${NC} Monitor System Processes and Bash Commands with System Info ${GREEN}(MP_Monitor_Bash.sh, new Terminal tab)${NC}"
            echo -e "  ${BOLD}${CYAN}9)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [1-9, or m]: " m_choice

            case $m_choice in
                1)
                    local drive_sh="$SCRIPT_DIR/Get_All_Drive_Space.sh"
                    [ ! -f "$drive_sh" ] && drive_sh="$SCRIPT_DIR/scripts/Get_All_Drive_Space.sh"
                    if [ -f "$drive_sh" ]; then
                        echo ""
                        bash "$drive_sh"
                    else
                        echo -e "\n${RED}Drive space script not found: $drive_sh${NC}"
                    fi
                    echo ""
                    press_enter
                    ;;
                2)
                    echo -e "\n${BOLD}${YELLOW}=== RUNNING SYSTEM CLEANUP ===${NC}\n"
                    if command -v ujust >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Running ujust clean-system...${NC}"
                        ujust clean-system
                    else
                        if command -v dnf5 >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Cleaning dnf5 caches & unused packages...${NC}"
                            sudo dnf5 clean all && sudo dnf5 autoremove -y || true
                        elif command -v dnf >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Cleaning dnf caches & unused packages...${NC}"
                            sudo dnf clean all && sudo dnf autoremove -y || true
                        elif command -v apt-get >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Cleaning APT caches & unused packages...${NC}"
                            sudo apt-get autoremove -y && sudo apt-get clean || true
                        elif command -v pacman >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Cleaning Pacman caches...${NC}"
                            sudo pacman -Sc --noconfirm || true
                        elif command -v zypper >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Cleaning Zypper caches...${NC}"
                            sudo zypper clean -a || true
                        fi

                        if command -v rpm-ostree >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Cleaning ostree metadata...${NC}"
                            rpm-ostree cleanup -m 2>/dev/null || true
                        fi

                        if command -v flatpak >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Uninstalling unused Flatpak runtimes...${NC}"
                            flatpak uninstall --unused -y 2>/dev/null || true
                        fi

                        if command -v podman >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Pruning unused podman images & containers...${NC}"
                            podman system prune -f 2>/dev/null || true
                        elif command -v docker >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Pruning unused docker images & containers...${NC}"
                            docker system prune -f 2>/dev/null || true
                        fi

                        if command -v brew >/dev/null 2>&1; then
                            echo -e "${BOLD}${CYAN}» Cleaning Homebrew packages...${NC}"
                            brew cleanup -s 2>/dev/null && brew autoremove 2>/dev/null || true
                        fi
                    fi

                    echo -e "${BOLD}${CYAN}» Clearing user thumbnails & cache...${NC}"
                    rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true
                    echo -e "\n${GREEN}[✓] System cleanup completed successfully.${NC}"
                    echo ""
                    press_enter
                    ;;
                3)
                    echo -e "\n${BOLD}${YELLOW}=== DOWNLOADING & APPLYING SYSTEM UPDATES ===${NC}\n"
                    local updated=0

                    # 1. Bazzite / Universal Blue with ujust
                    if command -v ujust >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Running ujust update (Bazzite / Universal Blue)...${NC}"
                        ujust update && updated=1
                    # 2. rpm-ostree systems (Fedora Silverblue / Kinoite / Atomic without ujust)
                    elif command -v rpm-ostree >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Upgrading ostree deployment (rpm-ostree upgrade)...${NC}"
                        rpm-ostree upgrade && updated=1
                    # 3. Fedora / RHEL (dnf5 or dnf)
                    elif command -v dnf5 >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Updating Fedora packages (dnf5 upgrade)...${NC}"
                        sudo dnf5 upgrade --refresh -y && updated=1
                    elif command -v dnf >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Updating Fedora / RHEL packages (dnf upgrade)...${NC}"
                        sudo dnf upgrade --refresh -y && updated=1
                    # 4. Debian / Ubuntu / Mint / Pop!_OS (apt)
                    elif command -v apt-get >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Updating APT packages (apt update && apt upgrade)...${NC}"
                        sudo apt-get update && sudo apt-get upgrade -y && updated=1
                    # 5. Arch Linux / Manjaro (pacman)
                    elif command -v pacman >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Updating Pacman packages (pacman -Syu)...${NC}"
                        sudo pacman -Syu --noconfirm && updated=1
                    # 6. openSUSE (zypper)
                    elif command -v zypper >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Updating Zypper packages...${NC}"
                        sudo zypper refresh && sudo zypper update -y && updated=1
                    # 7. Alpine Linux (apk)
                    elif command -v apk >/dev/null 2>&1; then
                        echo -e "${BOLD}${CYAN}» Updating Alpine packages (apk upgrade)...${NC}"
                        sudo apk update && sudo apk upgrade && updated=1
                    fi

                    # Update Flatpaks if installed (common across Fedora, Silverblue, Ubuntu, Arch, etc.)
                    if command -v flatpak >/dev/null 2>&1; then
                        echo -e "\n${BOLD}${CYAN}» Updating Flatpak applications and runtimes...${NC}"
                        flatpak update -y && updated=1
                    fi

                    # Update Snap if installed (Ubuntu)
                    if command -v snap >/dev/null 2>&1; then
                        echo -e "\n${BOLD}${CYAN}» Refreshing Snap packages...${NC}"
                        sudo snap refresh 2>/dev/null && updated=1
                    fi

                    # Update Homebrew on Linux if installed
                    if command -v brew >/dev/null 2>&1; then
                        echo -e "\n${BOLD}${CYAN}» Updating Homebrew on Linux...${NC}"
                        brew update && brew upgrade && updated=1
                    fi

                    if [ "$updated" -eq 1 ]; then
                        echo -e "\n${GREEN}[✓] System update completed successfully.${NC}"
                    else
                        echo -e "\n${RED}No supported package manager found to update.${NC}"
                    fi
                    echo ""
                    press_enter
                    ;;
                4)
                    echo -e "\n${BOLD}${YELLOW}Vacuuming system logs down to 200MB...${NC}\n"
                    sudo journalctl --vacuum-size=200M 2>/dev/null || true
                    echo ""
                    journalctl --disk-usage 2>/dev/null || true
                    echo ""
                    press_enter
                    ;;
                5)
                    echo -e "\n${BOLD}${YELLOW}Trimming and optimizing SSD storage (fstrim)...${NC}\n"
                    sudo fstrim -av 2>/dev/null || true
                    echo ""
                    press_enter
                    ;;
                6)
                    echo -e "\n${BOLD}${YELLOW}=== CLEAR SYSTEM MEMORY (RAM & PAGE CACHE) ===${NC}\n"
                    if command -v free >/dev/null 2>&1; then
                        echo -e "${BOLD}Memory status before cleanup:${NC}"
                        free -h
                        echo ""
                    fi
                    echo -e "${CYAN}Syncing filesystem buffers to disk...${NC}"
                    sync
                    echo -e "${CYAN}Dropping pagecache, dentries, and inodes (drop_caches=3)...${NC}"
                    if echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ PageCache, dentries, and inodes successfully cleared!${NC}"
                    elif sudo sysctl -w vm.drop_caches=3 >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ PageCache, dentries, and inodes successfully cleared via sysctl!${NC}"
                    else
                        echo -e "${RED}Failed to drop caches (sudo permissions required).${NC}"
                    fi

                    local swap_used_kb=0
                    if [ -f /proc/meminfo ]; then
                        swap_used_kb=$(awk '/SwapTotal:/ {st=$2} /SwapFree:/ {sf=$2} END {print (st - sf)}' /proc/meminfo 2>/dev/null || echo 0)
                    fi
                    if [ "$swap_used_kb" -gt 51200 ]; then
                        local swap_used_human
                        swap_used_human=$(awk '/SwapTotal:/ {st=$2} /SwapFree:/ {sf=$2} END {printf "%.1f MB", (st - sf)/1024}' /proc/meminfo 2>/dev/null || echo "Swap in use")
                        echo ""
                        echo -e "Swap memory currently in use: ${YELLOW}${swap_used_human}${NC}"
                        read -r -p "Would you also like to flush swap memory back into RAM? [y/N]: " swap_choice
                        case "$swap_choice" in
                            [yY]|[yY][eE][sS])
                                echo -e "${CYAN}Flushing swap back to RAM (sudo swapoff -a && sudo swapon -a)...${NC}"
                                if sudo swapoff -a && sudo swapon -a; then
                                    echo -e "${GREEN}✓ Swap memory flushed successfully!${NC}"
                                else
                                    echo -e "${RED}Warning: Could not cycle swap.${NC}"
                                fi
                                ;;
                            *)
                                echo -e "${DIM}Skipping swap flush.${NC}"
                                ;;
                        esac
                    fi

                    echo ""
                    if command -v free >/dev/null 2>&1; then
                        echo -e "${BOLD}Memory status after cleanup:${NC}"
                        free -h
                    fi
                    echo ""
                    press_enter
                    ;;
                7)
                    echo -e "\n${BOLD}${GREEN}=== RUNNING COMPLETE CLEANUP SUITE ===${NC}\n"
                    echo -e "${BOLD}${BLUE}[1/4] Running System Cleanup...${NC}"
                    if command -v ujust >/dev/null 2>&1; then
                        ujust clean-system
                    else
                        if command -v dnf5 >/dev/null 2>&1; then
                            sudo dnf5 clean all && sudo dnf5 autoremove -y || true
                        elif command -v dnf >/dev/null 2>&1; then
                            sudo dnf clean all && sudo dnf autoremove -y || true
                        elif command -v apt-get >/dev/null 2>&1; then
                            sudo apt-get autoremove -y && sudo apt-get clean || true
                        elif command -v pacman >/dev/null 2>&1; then
                            sudo pacman -Sc --noconfirm || true
                        elif command -v zypper >/dev/null 2>&1; then
                            sudo zypper clean -a || true
                        fi
                        if command -v rpm-ostree >/dev/null 2>&1; then
                            rpm-ostree cleanup -m 2>/dev/null || true
                        fi
                        if command -v flatpak >/dev/null 2>&1; then
                            flatpak uninstall --unused -y 2>/dev/null || true
                        fi
                        if command -v podman >/dev/null 2>&1; then
                            podman system prune -f 2>/dev/null || true
                        fi
                        rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null || true
                    fi
                    echo ""
                    echo -e "${BOLD}${BLUE}[2/4] Clearing System Memory (RAM Cache)...${NC}"
                    sync
                    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || sudo sysctl -w vm.drop_caches=3 >/dev/null 2>&1 || true
                    echo -e "${GREEN}✓ System RAM cache cleared.${NC}"
                    echo ""
                    echo -e "${BOLD}${BLUE}[3/4] Vacuuming system logs to 200MB...${NC}"
                    sudo journalctl --vacuum-size=200M 2>/dev/null || true
                    echo ""
                    echo -e "${BOLD}${BLUE}[4/4] Trimming SSD filesystems (fstrim)...${NC}"
                    sudo fstrim -av 2>/dev/null || true
                    echo ""
                    echo -e "${BOLD}${GREEN}[✓] Complete cleanup finished!${NC}"
                    journalctl --disk-usage 2>/dev/null || true
                    if command -v free >/dev/null 2>&1; then
                        echo ""
                        free -h
                    fi
                    echo ""
                    press_enter
                    ;;
                8|m|monitor|mp-monitor)
                    manage_process_and_bash_monitor
                    ;;
                9|0|[qQ])
                    return 0
                    ;;
                *)
                    echo -e "\n${RED}Invalid option!${NC}"
                    sleep 1.5
                    ;;
            esac
        fi
    done
}

launch_ai_session() {
    local target_arg="$1"
    local title="$2"
    local agy_bin
    if command -v agy >/dev/null 2>&1; then
        agy_bin="agy"
    elif [ -x "$HOME/.local/bin/agy.bin" ]; then
        agy_bin="$HOME/.local/bin/agy.bin"
    else
        agy_bin="agy"
    fi

    local run_cmd="\"$agy_bin\""
    if [ -n "$target_arg" ]; then
        if [[ "$target_arg" =~ ^-- ]]; then
            run_cmd="\"$agy_bin\" $target_arg"
        else
            run_cmd="\"$agy_bin\" --model \"$target_arg\""
        fi
    fi

    if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        echo -e "\n${BOLD}${YELLOW}No GUI display detected; launching ${title} in current terminal...${NC}\n"
        sleep 0.8
        trap ':' INT
        eval "$run_cmd"
        trap 'exit_mix_manager' INT
        press_enter
        return 0
    fi

    echo ""
    echo -e "${BOLD}Select launch target for ${title}:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} New Terminal Tab (Default - keeps Manager running in background)"
    echo -e "  ${BOLD}${CYAN}2)${NC} New Standalone Terminal Window"
    echo -e "  ${BOLD}${CYAN}3)${NC} Current Terminal Window (Returns to Manager upon exit)"
    read -r -p "Enter choice [1-3, default: 1]: " t_choice

    case "$t_choice" in
        2)
            echo -e "\n${BOLD}${GREEN}Launching ${title} in a new window...${NC}\n"
            local full_cmd="$run_cmd; echo ''; echo 'Session ended. Press [Enter] to close window...'; read -r"
            if launch_in_terminal "$title" "$full_cmd" "window"; then
                echo -e "${GREEN}✓ ${title} launched in a new window.${NC}"
                sleep 1.2
            else
                echo -e "${YELLOW}No external terminal emulator found; launching in current window...${NC}"
                sleep 0.5
                trap ':' INT
                eval "$run_cmd"
                trap 'exit_mix_manager' INT
                press_enter
                return 0
            fi
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Launching ${title} in current terminal (Type /exit or Ctrl+D twice to return)...${NC}\n"
            sleep 0.8
            trap ':' INT
            eval "$run_cmd"
            trap 'exit_mix_manager' INT
            press_enter
            ;;
        *)
            echo -e "\n${BOLD}${GREEN}Launching ${title} in a new terminal tab...${NC}\n"
            local full_cmd="$run_cmd; echo ''; echo 'Session ended. Press [Enter] to close tab...'; read -r"
            if launch_in_terminal "$title" "$full_cmd" "tab"; then
                echo -e "${GREEN}✓ ${title} launched in a new terminal tab.${NC}"
                sleep 1.2
            else
                echo -e "${YELLOW}No external terminal emulator found; launching in current window...${NC}"
                sleep 0.5
                trap ':' INT
                eval "$run_cmd"
                trap 'exit_mix_manager' INT
                press_enter
                return 0
            fi
            ;;
    esac
}

manage_ai_models() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       AI ASSISTANT & MODEL LAUNCHER (AGY)        ${NC}"
        echo -e "${BOLD}${MAGENTA}==================================================${NC}"
        echo ""
        echo -e "  Account:    ${CYAN}mathewkjohn2026@gmail.com${NC}"
        echo -e "  Workspace:  ${GREEN}${PWD}${NC}"
        echo ""
        echo -e "${BOLD}Claude & GPT Models (Shared Partner Quota):${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Claude Sonnet 4.6 (Thinking)         ${GREEN}[claude-sonnet-4-6]${NC}"
        echo -e "  ${BOLD}${CYAN}2)${NC} Claude Opus 4.6 (Thinking)           ${GREEN}[claude-opus-4-6-thinking]${NC}"
        echo -e "  ${BOLD}${CYAN}3)${NC} GPT-OSS 120B (Medium)                ${GREEN}[gpt-oss-120b-medium]${NC}"
        echo ""
        echo -e "${BOLD}Google Gemini Models (High Volume Quota):${NC}"
        echo -e "  ${BOLD}${CYAN}4)${NC} Gemini 3.8 Flash (High)              ${GREEN}[gemini-3.8-flash-high]${NC}"
        echo -e "  ${BOLD}${CYAN}5)${NC} Gemini 3.1 Pro (High)                ${GREEN}[gemini-3.1-pro-high]${NC}"
        echo ""
        echo -e "${BOLD}Local Ollama & AI Web Interfaces:${NC}"
        echo -e "  ${BOLD}${CYAN}6)${NC} Manage Ollama Server & Local Models  ${GREEN}[ollama serve / chat / status]${NC}"
        echo -e "  ${BOLD}${CYAN}7)${NC} Launch dsh-mobile Web Server         ${GREEN}[http://192.168.1.11:3080]${NC}"
        echo -e "  ${BOLD}${CYAN}8)${NC} Manage DeepSeek Harness Server       ${GREEN}[Start, Stop, Browser, Status]${NC}"
        echo ""
        echo -e "${BOLD}Sessions & Utilities:${NC}"
        echo -e "  ${BOLD}${CYAN}9)${NC} Launch Default Session               ${GREEN}[agy]${NC}"
        echo -e "  ${BOLD}${CYAN}10)${NC} Resume Most Recent Conversation      ${GREEN}[agy --continue]${NC}"
        echo -e "  ${BOLD}${CYAN}11)${NC} View All Available Models & Status   ${GREEN}[agy models]${NC}"
        echo -e "  ${BOLD}${CYAN}12)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [1-12]: " ai_choice

        case $ai_choice in
            1)
                launch_ai_session "claude-sonnet-4-6" "Claude Sonnet"
                ;;
            2)
                launch_ai_session "claude-opus-4-6-thinking" "Claude Opus"
                ;;
            3)
                launch_ai_session "gpt-oss-120b-medium" "GPT-OSS 120B"
                ;;
            4)
                launch_ai_session "gemini-3.8-flash-high" "Gemini 3.8 Flash"
                ;;
            5)
                launch_ai_session "gemini-3.1-pro-high" "Gemini 3.1 Pro"
                ;;
            6)
                manage_ollama
                ;;
            7)
                launch_dsh_mobile
                press_enter
                ;;
            8)
                manage_dsh_mobile
                ;;
            9)
                launch_ai_session "" "Antigravity AI"
                ;;
            10)
                echo -e "\n${BOLD}${YELLOW}Resuming most recent conversation...${NC}\n"
                launch_ai_session "--continue" "Resume Session"
                ;;
            11)
                echo -e "\n${BOLD}${BLUE}=== AVAILABLE MODELS IN AGY ===${NC}\n"
                if command -v agy >/dev/null 2>&1; then
                    agy models
                elif [ -x "$HOME/.local/bin/agy.bin" ]; then
                    "$HOME/.local/bin/agy.bin" models
                fi
                echo ""
                press_enter
                ;;
            12|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

burn_iso_to_usb() {
    echo -e "\n${BOLD}${MAGENTA}==================================================${NC}"
    echo -e "${BOLD}${MAGENTA}          BURN ISO IMAGE TO USB DRIVE (DD)        ${NC}"
    echo -e "${BOLD}${MAGENTA}==================================================${NC}\n"

    # Prompt user for ISO file path
    local iso_path=""
    read -r -e -p "Enter full path to the ISO file: " iso_path

    # Clean input quotes and spaces from drag & drop
    iso_path=$(echo "$iso_path" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    if [ -z "$iso_path" ]; then
        echo -e "${RED}Error: ISO file path cannot be empty!${NC}"
        press_enter
        return 1
    fi

    # Expand tilde if present
    if [[ "$iso_path" == ~* ]]; then
        iso_path="${iso_path/#~/$HOME}"
    fi

    if [ ! -f "$iso_path" ]; then
        echo -e "${RED}Error: File not found at '$iso_path'!${NC}"
        press_enter
        return 1
    fi

    local iso_size
    iso_size=$(ls -lh "$iso_path" 2>/dev/null | awk '{print $5}')
    echo -e "${GREEN}✓ Found ISO:${NC} $iso_path (${CYAN}${iso_size}${NC})"

    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}Available External USB Drives (macOS diskutil):${NC}"
        diskutil list external
        echo ""
        read -r -p "Enter target disk name (e.g. disk2 or /dev/disk2): " target_dev
        target_dev=$(echo "$target_dev" | tr -d ' ' | sed 's|^/dev/||')
        if [ -z "$target_dev" ]; then
            echo -e "${RED}Error: Target disk cannot be empty!${NC}"
            press_enter
            return 1
        fi
        local full_dev="/dev/$target_dev"
        if ! diskutil info "$full_dev" >/dev/null 2>&1; then
            echo -e "${RED}Error: Disk '$full_dev' not found!${NC}"
            press_enter
            return 1
        fi
        if diskutil info "$full_dev" | grep -qi "Internal:[[:space:]]*Yes"; then
            echo -e "${BOLD}${RED}FATAL: $full_dev is reported as an INTERNAL drive! Aborting for safety.${NC}"
            press_enter
            return 1
        fi
        echo -e "\n${BOLD}${RED}!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
        echo -e "${BOLD}${RED}ALL EXISTING DATA ON $full_dev WILL BE PERMANENTLY ERASED!${NC}"
        echo -e "${BOLD}${RED}Source: $iso_path (${iso_size})${NC}"
        echo -e "${BOLD}${RED}Target: $full_dev${NC}"
        echo -e "${BOLD}${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}\n"
        read -r -p "Type 'YES' (in capitals) to confirm writing to $full_dev: " confirm_burn
        if [ "$confirm_burn" != "YES" ]; then
            echo -e "\n${YELLOW}Operation canceled. No changes were made.${NC}"
            press_enter
            return 0
        fi
        echo -e "\n${CYAN}Unmounting $full_dev...${NC}"
        diskutil unmountDisk "$full_dev"
        local r_dev="/dev/r${target_dev}"
        echo -e "\n${BOLD}${GREEN}Executing dd (writing ISO to $r_dev)...${NC}\n"
        sudo dd if="$iso_path" of="$r_dev" bs=4m status=progress
        local dd_status=$?
        if [ $dd_status -eq 0 ]; then
            echo -e "\n${BOLD}${GREEN}✓ Successfully wrote ISO to $r_dev!${NC}"
            echo -e "${CYAN}Disk ejected. USB drive is ready to boot.${NC}"
            diskutil eject "$full_dev" 2>/dev/null || true
        else
            echo -e "\n${BOLD}${RED}✗ Error occurred during dd write (exit code: $dd_status)!${NC}"
        fi
        press_enter
        return $dd_status
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}Available Disks (Windows PowerShell):${NC}"
        powershell.exe -NoProfile -Command "Get-Disk | Select-Object Number, FriendlyName, BusType, @{Name='Size_GB';Expression={[math]::Round(\$_.Size / 1GB, 2)}} | Format-Table -AutoSize" 2>/dev/null
        echo -e "\n${YELLOW}Note: Direct block-level raw writing to physical drives on Windows requires elevated privileges.${NC}"
        echo -e "${CYAN}For Windows 10/11, it is highly recommended to use:${NC}"
        echo -e "  • ${BOLD}Rufus${NC} (https://rufus.ie) - Best for bootable USB creation"
        echo -e "  • ${BOLD}BalenaEtcher${NC} (https://etcher.balena.io) - Easy cross-platform image flasher"
        echo ""
        read -r -p "Press [Enter] to open Rufus download page or 'q' to return: " w_burn_opt
        if [ "$w_burn_opt" != "q" ] && [ "$w_burn_opt" != "Q" ]; then
            open_path "https://rufus.ie"
        fi
        return 0
    fi

    # Display available USB storage devices (Linux)
    echo -e "\n${BOLD}Available USB Removable Devices:${NC}"
    lsblk -d -o NAME,MODEL,SIZE,TRAN,VENDOR,TYPE | grep -E "usb|NAME"
    echo ""

    local target_dev=""
    read -r -p "Enter target device name (e.g. sdf or /dev/sdf): " target_dev
    target_dev=$(echo "$target_dev" | tr -d ' ' | sed 's|^/dev/||')

    if [ -z "$target_dev" ]; then
        echo -e "${RED}Error: Target device cannot be empty!${NC}"
        press_enter
        return 1
    fi

    local full_dev="/dev/$target_dev"
    if [ ! -b "$full_dev" ]; then
        echo -e "${RED}Error: Block device '$full_dev' does not exist!${NC}"
        press_enter
        return 1
    fi

    # Ensure user specified a whole disk, not a partition (e.g. sdf, not sdf1)
    local dev_type
    dev_type=$(lsblk -no TYPE "$full_dev" 2>/dev/null | head -n 1)
    if [ "$dev_type" != "disk" ]; then
        echo -e "${RED}Error: '$full_dev' is a $dev_type, not a whole disk (e.g. specify 'sdf', not 'sdf1')!${NC}"
        press_enter
        return 1
    fi

    # Safety check: Prevent targeting OS drives
    local mounts
    mounts=$(lsblk -no MOUNTPOINTS "$full_dev" 2>/dev/null | tr '\n' ' ')
    if echo "$mounts" | grep -qE '(^|[[:space:]])/(sysroot|boot|var|etc|home|var/home)?([[:space:]]|$)'; then
        echo -e "${BOLD}${RED}FATAL: $full_dev contains active operating system mounts! Aborting.${NC}"
        press_enter
        return 1
    fi

    # Warn if not a USB transport
    local tran
    tran=$(lsblk -no TRAN "$full_dev" 2>/dev/null | head -n 1)
    if [ "$tran" != "usb" ]; then
        echo -e "${BOLD}${YELLOW}WARNING: Device $full_dev transport is '$tran' (not USB)!${NC}"
    fi

    echo -e "\n${BOLD}${BLUE}Target Drive Details:${NC}"
    lsblk -o NAME,MODEL,SIZE,LABEL,FSTYPE,MOUNTPOINTS "$full_dev"
    echo ""

    echo -e "${BOLD}${RED}!!!!!!!!!!!!!!!!!!!!!!!!!! WARNING !!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
    echo -e "${BOLD}${RED}ALL EXISTING DATA ON $full_dev WILL BE PERMANENTLY ERASED!${NC}"
    echo -e "${BOLD}${RED}Source: $iso_path (${iso_size})${NC}"
    echo -e "${BOLD}${RED}Target: $full_dev${NC}"
    echo -e "${BOLD}${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}\n"

    read -r -p "Type 'YES' (in capitals) to confirm writing to $full_dev: " confirm_burn
    if [ "$confirm_burn" != "YES" ]; then
        echo -e "\n${YELLOW}Operation canceled. No changes were made.${NC}"
        press_enter
        return 0
    fi

    # Unmount any mounted partitions on the target drive
    echo -e "\n${CYAN}Unmounting any active partitions on $full_dev...${NC}"
    local part_names
    part_names=$(lsblk -lno NAME "$full_dev" 2>/dev/null | tail -n +2)
    for part in $part_names; do
        if grep -qs "/dev/$part" /proc/mounts; then
            echo -e "  Unmounting /dev/$part..."
            udisksctl unmount -b "/dev/$part" 2>/dev/null || sudo umount "/dev/$part" 2>/dev/null || true
        fi
    done

    echo -e "\n${BOLD}${GREEN}Executing dd (writing ISO to $full_dev)...${NC}\n"
    sudo dd if="$iso_path" of="$full_dev" bs=4M status=progress oflag=sync
    local dd_status=$?

    if [ $dd_status -eq 0 ]; then
        sync
        echo -e "\n${BOLD}${GREEN}✓ Successfully wrote ISO to $full_dev!${NC}"
        echo -e "${CYAN}Disk synced. The USB drive is now ready to boot.${NC}"
    else
        echo -e "\n${BOLD}${RED}✗ Error occurred during dd write (exit code: $dd_status)!${NC}"
    fi

    press_enter
    return $dd_status
}

is_app_installed() {
    local bin_name="$1"
    local flatpak_id="$2"
    local mac_app_name="$3"
    local win_exe_name="$4"

    if [ -n "$bin_name" ] && command -v "$bin_name" >/dev/null 2>&1; then
        return 0
    fi
    if [ "$OS_TYPE" = "macos" ] && [ -n "$mac_app_name" ]; then
        if [ -d "/Applications/${mac_app_name}.app" ] || [ -d "$HOME/Applications/${mac_app_name}.app" ] || osascript -e "id of application \"$mac_app_name\"" >/dev/null 2>&1; then
            return 0
        fi
    fi
    if { [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; } && [ -n "$win_exe_name" ]; then
        if [ -f "/c/Program Files/${win_exe_name}" ] || [ -f "/c/Program Files (x86)/${win_exe_name}" ] || [ -f "$LOCALAPPDATA/${win_exe_name}" ]; then
            return 0
        fi
        if command -v cmd.exe >/dev/null 2>&1; then
            if [ -n "$bin_name" ] && cmd.exe /c "where $bin_name" >/dev/null 2>&1; then
                return 0
            fi
        fi
    fi
    if [ -n "$flatpak_id" ] && command -v flatpak >/dev/null 2>&1; then
        if flatpak info "$flatpak_id" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

launch_gui_app() {
    local app_name="$1"
    local bin_name="$2"
    local flatpak_id="$3"
    local mac_app_name="$4"
    local brew_cask="$5"
    local win_exe_name="$6"
    local winget_id="$7"

    echo -e "\n${BOLD}${YELLOW}Launching ${app_name}...${NC}\n"

    # 1. Native CLI binary in PATH (works across Linux, macOS with Homebrew, Windows with Git Bash)
    if [ -n "$bin_name" ] && command -v "$bin_name" >/dev/null 2>&1; then
        nohup "$bin_name" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ ${app_name} launched successfully.${NC}"
        sleep 1.2
        return 0
    fi

    # 2. macOS Platform Support (.app in /Applications or ~/Applications)
    if [ "$OS_TYPE" = "macos" ]; then
        if [ -n "$mac_app_name" ]; then
            if osascript -e "id of application \"$mac_app_name\"" >/dev/null 2>&1 || [ -d "/Applications/${mac_app_name}.app" ] || [ -d "$HOME/Applications/${mac_app_name}.app" ]; then
                open -a "$mac_app_name" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ ${app_name} launched (macOS App).${NC}"
                sleep 1.2
                return 0
            fi
        fi
        if [ -n "$brew_cask" ] && command -v brew >/dev/null 2>&1; then
            echo -e "${YELLOW}${app_name} is not installed.${NC}"
            read -r -p "Install ${app_name} via Homebrew now? [y/N]: " mac_inst
            if [[ "$mac_inst" =~ ^[Yy]$ ]]; then
                echo -e "${CYAN}Running: brew install --cask ${brew_cask}...${NC}"
                if brew install --cask "$brew_cask"; then
                    open -a "$mac_app_name" >/dev/null 2>&1 &
                    echo -e "${GREEN}✓ ${app_name} installed and launched!${NC}"
                    sleep 1.2
                    return 0
                else
                    echo -e "${RED}Error: Homebrew installation failed.${NC}"
                    press_enter
                    return 1
                fi
            fi
        fi
        echo -e "${RED}Error: ${app_name} is not installed!${NC}"
        press_enter
        return 1
    fi

    # 3. Windows Platform Support (Git Bash / MSYS2 / WSL)
    if [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        if [ -n "$win_exe_name" ]; then
            local win_paths=(
                "/c/Program Files/${win_exe_name}"
                "/c/Program Files (x86)/${win_exe_name}"
                "$LOCALAPPDATA/${win_exe_name}"
            )
            for p in "${win_paths[@]}"; do
                if [ -f "$p" ]; then
                    if command -v cygpath >/dev/null 2>&1; then
                        cmd.exe /c start "" "$(cygpath -w "$p")" >/dev/null 2>&1 &
                    else
                        cmd.exe /c start "" "$p" >/dev/null 2>&1 &
                    fi
                    echo -e "${GREEN}✓ ${app_name} launched (Windows).${NC}"
                    sleep 1.2
                    return 0
                fi
            done
        fi
        if [ -n "$bin_name" ] && command -v cmd.exe >/dev/null 2>&1; then
            if cmd.exe /c "where $bin_name" >/dev/null 2>&1; then
                cmd.exe /c start "" "$bin_name" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ ${app_name} launched (Windows).${NC}"
                sleep 1.2
                return 0
            fi
        fi
        if [ -n "$winget_id" ] && command -v winget.exe >/dev/null 2>&1; then
            echo -e "${YELLOW}${app_name} is not installed.${NC}"
            read -r -p "Install ${app_name} via winget now? [y/N]: " win_inst
            if [[ "$win_inst" =~ ^[Yy]$ ]]; then
                echo -e "${CYAN}Running: winget install ${winget_id}...${NC}"
                winget.exe install --id "$winget_id" -e --accept-source-agreements --accept-package-agreements
                echo -e "${GREEN}✓ Installation finished. Please re-run to launch.${NC}"
                press_enter
                return 0
            fi
        fi
        echo -e "${RED}Error: ${app_name} is not installed!${NC}"
        press_enter
        return 1
    fi

    # 4. Linux Platform Support (Flatpak / Native)
    if [ -n "$flatpak_id" ] && command -v flatpak >/dev/null 2>&1; then
        if flatpak info "$flatpak_id" >/dev/null 2>&1; then
            nohup flatpak run "$flatpak_id" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ ${app_name} launched (Flatpak).${NC}"
            sleep 1.2
            return 0
        fi
        echo -e "${YELLOW}${app_name} is not installed on this system.${NC}"
        read -r -p "Would you like to install ${app_name} via Flatpak now? [y/N]: " do_install
        if [[ "$do_install" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Installing ${flatpak_id} from Flathub...${NC}"
            if flatpak install -y --user flathub "$flatpak_id"; then
                nohup flatpak run "$flatpak_id" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ ${app_name} installed and launched!${NC}"
                sleep 1.2
                return 0
            fi
        fi
    fi

    echo -e "${RED}Error: ${app_name} is not installed!${NC}"
    press_enter
    return 1
}

launch_audacity() {
    launch_gui_app "Audacity" "audacity" "org.audacityteam.Audacity" "Audacity" "audacity" "Audacity/Audacity.exe" "Audacity.Audacity"
}

launch_or_install_picard() {
    launch_gui_app "MusicBrainz Picard" "picard" "org.musicbrainz.Picard" "MusicBrainz Picard" "musicbrainz-picard" "MusicBrainz Picard/picard.exe" "MusicBrainz.Picard"
}

launch_vlc() {
    launch_gui_app "VLC Media Player" "vlc" "org.videolan.VLC" "VLC" "vlc" "VideoLAN/VLC/vlc.exe" "VideoLAN.VLC"
}

launch_haruna() {
    launch_gui_app "Haruna Media Player" "haruna" "org.kde.haruna" "IINA" "iina" "mpv/mpv.exe" ""
}

launch_kodi() {
    launch_gui_app "Kodi" "kodi" "tv.kodi.Kodi" "Kodi" "kodi" "Kodi/kodi.exe" "XBMCFoundation.Kodi"
}

launch_audacious() {
    launch_gui_app "Audacious Audio Player" "audacious" "org.atheme.audacious" "Audacious" "audacious" "Audacious/bin/audacious.exe" "Audacious.Audacious"
}

launch_strawberry() {
    launch_gui_app "Strawberry Music Player" "strawberry" "org.strawberrymusicplayer.strawberry" "Strawberry" "strawberry" "Strawberry Music Player/strawberry.exe" "JonasKvinge.Strawberry"
}

launch_gimp() {
    launch_gui_app "GIMP Image Editor" "gimp" "org.gimp.GIMP" "GIMP" "gimp" "GIMP 2/bin/gimp-2.10.exe" "GIMP.GIMP"
}

launch_electricsheep() {
    if [ -x "$HOME/.local/share/electricsheep/electricsheep.AppImage" ]; then
        nohup "$HOME/.local/share/electricsheep/electricsheep.AppImage" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Electric Sheep launched (AppImage).${NC}"
        sleep 1.2
        return 0
    fi
    launch_gui_app "Electric Sheep" "electricsheep" "" "Electric Sheep" "" "ElectricSheep/electricsheep.exe" ""
}

launch_gpu_screen_recorder() {
    echo -e "\n${BOLD}${YELLOW}Launching GPU Screen Recorder in a new window...${NC}\n"

    if [ "$OS_TYPE" != "linux" ]; then
        echo -e "${RED}GPU Screen Recorder is available on Linux only.${NC}"
        return 1
    fi

    if command -v gpu-screen-recorder-gtk >/dev/null 2>&1; then
        nohup gpu-screen-recorder-gtk >/dev/null 2>&1 &
        disown 2>/dev/null || true
        echo -e "${GREEN}✓ GPU Screen Recorder launched in a new window.${NC}"
        return 0
    fi

    if command -v flatpak >/dev/null 2>&1 && flatpak info com.dec05eba.gpu_screen_recorder >/dev/null 2>&1; then
        nohup flatpak run --command=gpu-screen-recorder-gtk com.dec05eba.gpu_screen_recorder >/dev/null 2>&1 &
        disown 2>/dev/null || true
        echo -e "${GREEN}✓ GPU Screen Recorder launched in a new window.${NC}"
        return 0
    fi

    if command -v gtk-launch >/dev/null 2>&1 && gtk-launch com.dec05eba.gpu_screen_recorder >/dev/null 2>&1; then
        echo -e "${GREEN}✓ GPU Screen Recorder launched in a new window.${NC}"
        return 0
    fi

    echo -e "${RED}Error: GPU Screen Recorder is not installed.${NC}"
    echo -e "${YELLOW}Install it on Linux with: flatpak install flathub com.dec05eba.gpu_screen_recorder${NC}"
    return 1
}

launch_or_install_flatpak_app() {
    local app_id="$1"
    local bin_name="$2"
    local app_name="$3"
    local mac_app_name="${4:-$app_name}"
    local brew_cask="${5:-$bin_name}"
    local win_exe="${6:-$bin_name.exe}"
    local winget_id="${7:-}"
    launch_gui_app "$app_name" "$bin_name" "$app_id" "$mac_app_name" "$brew_cask" "$win_exe" "$winget_id"
}

launch_logic_pro() {
    local file="${1:-}"
    if [ "$OS_TYPE" != "macos" ]; then
        echo -e "\n${BOLD}${RED}⚠️  Apple Logic Pro is exclusively available on macOS.${NC}"
        echo -e "${YELLOW}To work with audio projects on Linux/Windows, REAPER or Audacity is recommended.${NC}"
        press_enter
        return 1
    fi
    echo -e "\n${BOLD}${YELLOW}Launching Apple Logic Pro...${NC}\n"
    if [ -n "$file" ] && [ -f "$file" ]; then
        if open -a "Logic Pro" "$file" 2>/dev/null || open -a "Logic Pro X" "$file" 2>/dev/null; then
            echo -e "${GREEN}✓ Opened '$(basename "$file")' in Apple Logic Pro.${NC}"
            sleep 1.2
            return 0
        fi
    else
        if open -a "Logic Pro" 2>/dev/null || open -a "Logic Pro X" 2>/dev/null; then
            echo -e "${GREEN}✓ Apple Logic Pro launched.${NC}"
            sleep 1.2
            return 0
        fi
    fi
    echo -e "${RED}Error: Apple Logic Pro was not found in /Applications.${NC}"
    press_enter
    return 1
}

launch_garageband() {
    local file="${1:-}"
    if [ "$OS_TYPE" != "macos" ]; then
        echo -e "\n${BOLD}${RED}⚠️  Apple GarageBand is exclusively available on macOS.${NC}"
        press_enter
        return 1
    fi
    echo -e "\n${BOLD}${YELLOW}Launching Apple GarageBand...${NC}\n"
    if [ -n "$file" ] && [ -f "$file" ]; then
        if open -a "GarageBand" "$file" 2>/dev/null; then
            echo -e "${GREEN}✓ Opened '$(basename "$file")' in Apple GarageBand.${NC}"
            sleep 1.2
            return 0
        fi
    else
        if open -a "GarageBand" 2>/dev/null; then
            echo -e "${GREEN}✓ Apple GarageBand launched.${NC}"
            sleep 1.2
            return 0
        fi
    fi
    echo -e "${RED}Error: Apple GarageBand was not found in /Applications.${NC}"
    press_enter
    return 1
}

launch_traktor() {
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}${YELLOW}Launching Native Instruments Traktor Pro on macOS...${NC}\n"
        if [ -d "/Applications/Native Instruments/Traktor Pro 3/Traktor.app" ] && open "/Applications/Native Instruments/Traktor Pro 3/Traktor.app" 2>/dev/null; then
            echo -e "${GREEN}✓ Traktor Pro launched successfully.${NC}"
            sleep 1.2
            return 0
        elif [ -d "/Applications/Native Instruments/Traktor Pro 4/Traktor.app" ] && open "/Applications/Native Instruments/Traktor Pro 4/Traktor.app" 2>/dev/null; then
            echo -e "${GREEN}✓ Traktor Pro launched successfully.${NC}"
            sleep 1.2
            return 0
        elif open -b "com.native-instruments.Traktor" 2>/dev/null; then
            echo -e "${GREEN}✓ Traktor Pro launched successfully.${NC}"
            sleep 1.2
            return 0
        elif open -a "Traktor Pro 4" 2>/dev/null || open -a "Traktor Pro 3" 2>/dev/null || open -a "Traktor" 2>/dev/null; then
            echo -e "${GREEN}✓ Traktor Pro launched successfully.${NC}"
            sleep 1.2
            return 0
        else
            echo -e "${RED}Traktor Pro was not found in /Applications.${NC}"
            press_enter
            return 1
        fi
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}${YELLOW}Launching Native Instruments Traktor Pro on Windows...${NC}\n"
        local traktor_paths=(
            "/c/Program Files/Native Instruments/Traktor Pro 4/Traktor.exe"
            "/c/Program Files/Native Instruments/Traktor Pro 3/Traktor.exe"
            "/c/Program Files/Native Instruments/Traktor 2/Traktor.exe"
            "/c/Program Files (x86)/Native Instruments/Traktor Pro 3/Traktor.exe"
        )
        for p in "${traktor_paths[@]}"; do
            if [ -f "$p" ]; then
                local win_p
                win_p="$(cygpath -w "$p" 2>/dev/null || wslpath -w "$p" 2>/dev/null || echo "$p")"
                cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ Traktor Pro launched successfully.${NC}"
                sleep 1.2
                return 0
            fi
        done
        if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c "where Traktor.exe" >/dev/null 2>&1; then
            cmd.exe /c start "" "Traktor.exe" >/dev/null 2>&1 &
            echo -e "${GREEN}✓ Traktor Pro launched successfully.${NC}"
            sleep 1.2
            return 0
        fi
        echo -e "${RED}Traktor Pro was not found in standard Program Files directories.${NC}"
        press_enter
        return 1
    else
        echo -e "\n${BOLD}${RED}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${RED}            ⚠️  PLATFORM NOT SUPPORTED FOR TRAKTOR PRO ⚠️                      ${NC}"
        echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "  • ${BOLD}Platform:${NC}           $(uname -s)"
        echo -e "  • ${BOLD}Status:${NC}             ${RED}Unsupported by Native Instruments${NC}"
        echo -e "  • ${BOLD}Compatibility:${NC}      Native Instruments Traktor Pro is officially supported"
        echo -e "                          on ${BOLD}${GREEN}macOS${NC} and ${BOLD}${CYAN}Windows${NC} only."
        echo -e "  • ${BOLD}Recommended Alternative:${NC}"
        echo -e "                          For Linux & FreeBSD DJing, ${BOLD}${GREEN}Mixxx${NC} is the industry standard"
        echo -e "                          open-source DJ platform (Flatpak: org.mixxx.Mixxx, pkg: mixxx)."
        echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
        press_enter
        return 1
    fi
}

get_traktor_version_mac() {
    if [ "$OS_TYPE" != "macos" ]; then
        echo ""
        return 1
    fi
    local ver=""
    if [ -x "/usr/libexec/PlistBuddy" ] && [ -f "/Applications/Native Instruments/Traktor Pro 3/Traktor.app/Contents/Info.plist" ]; then
        ver="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/Native Instruments/Traktor Pro 3/Traktor.app/Contents/Info.plist" 2>/dev/null | awk '{print $1}')"
    elif [ -x "/usr/libexec/PlistBuddy" ] && [ -f "/Applications/Traktor Pro 3.app/Contents/Info.plist" ]; then
        ver="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/Traktor Pro 3.app/Contents/Info.plist" 2>/dev/null | awk '{print $1}')"
    elif [ -x "/usr/libexec/PlistBuddy" ] && [ -f "/Applications/Traktor.app/Contents/Info.plist" ]; then
        ver="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/Traktor.app/Contents/Info.plist" 2>/dev/null | awk '{print $1}')"
    fi
    if [ -z "$ver" ] && [ -d "$HOME/Documents/Native Instruments" ]; then
        ver="$(find "$HOME/Documents/Native Instruments" -maxdepth 1 -type d -name "Traktor 3*" 2>/dev/null | sort -V | tail -n 1 | sed 's/.*Traktor //')"
    fi
    echo "${ver:-3}"
}

generate_traktor_playlist_from_history() {
    if [ "$OS_TYPE" != "macos" ]; then
        echo -e "\n${BOLD}${RED}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${RED}            ⚠️  PLATFORM NOT SUPPORTED FOR TRAKTOR PLAYLISTS ⚠️                 ${NC}"
        echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "  • ${BOLD}Platform:${NC}           $(uname -s)"
        echo -e "  • ${BOLD}Notice:${NC}             Traktor Pro does not run on Linux natively."
        echo -e "                          This feature is exclusively supported on ${BOLD}${GREEN}macOS${NC}."
        echo -e "  • ${BOLD}Remote Access:${NC}      To generate Traktor playlists, execute Mix Archive Manager"
        echo -e "                          directly on your macOS workstation."
        echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
        press_enter
        return 1
    fi

    local gen_py="$SCRIPT_DIR/scripts/generate_traktor_playlist_from_history.py"
    local gen_sh="$SCRIPT_DIR/scripts/generate_traktor_playlist_from_history.sh"
    
    if [ -x "$gen_sh" ]; then
        "$gen_sh" "$@"
    elif [ -f "$gen_py" ]; then
        python3 "$gen_py" "$@"
    elif [ -f "./scripts/generate_traktor_playlist_from_history.py" ]; then
        python3 "./scripts/generate_traktor_playlist_from_history.py" "$@"
    else
        echo -e "\n${RED}Error: generate_traktor_playlist_from_history.py was not found in scripts/!${NC}\n"
        press_enter
        return 1
    fi
}

launch_fl_studio() {
    local file="${1:-}"
    echo -e "\n${BOLD}${YELLOW}Launching Image-Line FL Studio (Fruity Loops)...${NC}\n"

    # 1. macOS Platform
    if [ "$OS_TYPE" = "macos" ]; then
        local fl_mac_apps=("FL Studio 2024" "FL Studio 21" "FL Studio 20" "FL Studio")
        for app in "${fl_mac_apps[@]}"; do
            if [ -d "/Applications/${app}.app" ] || [ -d "$HOME/Applications/${app}.app" ]; then
                if [ -n "$file" ] && [ -f "$file" ]; then
                    open -a "$app" "$file" >/dev/null 2>&1 &
                    echo -e "${GREEN}✓ Opened '$(basename "$file")' in ${app}.${NC}"
                else
                    open -a "$app" >/dev/null 2>&1 &
                    echo -e "${GREEN}✓ ${app} launched on macOS.${NC}"
                fi
                sleep 1.2
                return 0
            fi
        done
        if [ -n "$file" ]; then
            open -a "FL Studio" "$file" 2>/dev/null && return 0
        else
            open -a "FL Studio" 2>/dev/null && return 0
        fi
        echo -e "${RED}FL Studio was not found in /Applications.${NC}"
        press_enter
        return 1

    # 2. Windows / WSL Platform
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        local fl_win_paths=(
            "/c/Program Files/Image-Line/FL Studio 2024/FL64.exe"
            "/c/Program Files/Image-Line/FL Studio 21/FL64.exe"
            "/c/Program Files/Image-Line/FL Studio 20/FL64.exe"
            "/c/Program Files (x86)/Image-Line/FL Studio 20/FL.exe"
        )
        local win_file=""
        [ -n "$file" ] && [ -f "$file" ] && win_file="$(cygpath -w "$file" 2>/dev/null || wslpath -w "$file" 2>/dev/null || echo "$file")"

        for p in "${fl_win_paths[@]}"; do
            if [ -f "$p" ]; then
                local win_p
                win_p="$(cygpath -w "$p" 2>/dev/null || wslpath -w "$p" 2>/dev/null || echo "$p")"
                if [ -n "$win_file" ]; then
                    cmd.exe /c start "" "$win_p" "$win_file" >/dev/null 2>&1 &
                else
                    cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
                fi
                echo -e "${GREEN}✓ FL Studio launched on Windows.${NC}"
                sleep 1.2
                return 0
            fi
        done

        if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c "where FL64.exe" >/dev/null 2>&1; then
            if [ -n "$win_file" ]; then
                cmd.exe /c start "" "FL64.exe" "$win_file" >/dev/null 2>&1 &
            else
                cmd.exe /c start "" "FL64.exe" >/dev/null 2>&1 &
            fi
            echo -e "${GREEN}✓ FL Studio launched on Windows.${NC}"
            sleep 1.2
            return 0
        fi

        echo -e "${RED}FL Studio was not found in Program Files or PATH on Windows.${NC}"
        press_enter
        return 1

    # 3. Linux Platform (via Wine, Bottles, or Native Wrapper)
    else
        if command -v flstudio >/dev/null 2>&1; then
            nohup flstudio ${file:+"$file"} >/dev/null 2>&1 &
            echo -e "${GREEN}✓ FL Studio launched (native wrapper).${NC}"
            sleep 1.2
            return 0
        elif command -v fl-studio >/dev/null 2>&1; then
            nohup fl-studio ${file:+"$file"} >/dev/null 2>&1 &
            echo -e "${GREEN}✓ FL Studio launched (native wrapper).${NC}"
            sleep 1.2
            return 0
        fi

        if command -v bottles-cli >/dev/null 2>&1; then
            if bottles-cli list bottles 2>/dev/null | grep -qi "fl.*studio"; then
                local b_name
                b_name=$(bottles-cli list bottles 2>/dev/null | grep -i "fl.*studio" | head -n 1 | awk -F: '{print $1}' | tr -d ' ')
                nohup bottles-cli run -b "$b_name" -p "FL Studio" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ FL Studio launched via Bottles bottle: $b_name.${NC}"
                sleep 1.2
                return 0
            fi
        elif command -v flatpak >/dev/null 2>&1 && flatpak info com.usebottles.bottles >/dev/null 2>&1; then
            if flatpak run --command=bottles-cli com.usebottles.bottles list bottles 2>/dev/null | grep -qi "fl.*studio"; then
                flatpak run --command=bottles-cli com.usebottles.bottles run -b "FL Studio" -p "FL Studio" >/dev/null 2>&1 &
                echo -e "${GREEN}✓ FL Studio launched via Bottles Flatpak.${NC}"
                sleep 1.2
                return 0
            fi
        fi

        local wine_fl_paths=(
            "$HOME/.wine/drive_c/Program Files/Image-Line/FL Studio 2024/FL64.exe"
            "$HOME/.wine/drive_c/Program Files/Image-Line/FL Studio 21/FL64.exe"
            "$HOME/.wine/drive_c/Program Files/Image-Line/FL Studio 20/FL64.exe"
            "$HOME/.local/share/bottles/bottles/FL-Studio/drive_c/Program Files/Image-Line/FL Studio 21/FL64.exe"
            "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/FL-Studio/drive_c/Program Files/Image-Line/FL Studio 21/FL64.exe"
        )
        for wp in "${wine_fl_paths[@]}"; do
            if [ -f "$wp" ] && command -v wine >/dev/null 2>&1; then
                nohup wine "$wp" ${file:+"$file"} >/dev/null 2>&1 &
                echo -e "${GREEN}✓ FL Studio launched via Wine.${NC}"
                sleep 1.2
                return 0
            fi
        done

        echo -e "${YELLOW}FL Studio is not currently installed or detected on this system.${NC}"
        echo -e "FL Studio is supported on Linux through ${BOLD}Bottles${NC} or ${BOLD}Wine${NC}."
        echo -e "Options:"
        echo -e "  1. Install ${CYAN}Bottles${NC} (flatpak install flathub com.usebottles.bottles) and run FL Studio installer."
        echo -e "  2. Or run: ${CYAN}wine \"FL_Studio_Installer.exe\"${NC}"
        press_enter
        return 1
    fi
}

launch_winamp() {
    local file="${1:-}"
    if [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}${YELLOW}Launching Winamp on Windows...${NC}\n"
        local win_file=""
        [ -n "$file" ] && [ -f "$file" ] && win_file="$(cygpath -w "$file" 2>/dev/null || wslpath -w "$file" 2>/dev/null || echo "$file")"

        local winamp_paths=(
            "/c/Program Files (x86)/Winamp/winamp.exe"
            "/c/Program Files/Winamp/winamp.exe"
            "$LOCALAPPDATA/Programs/Winamp/winamp.exe"
        )
        for p in "${winamp_paths[@]}"; do
            if [ -f "$p" ]; then
                local win_p
                win_p="$(cygpath -w "$p" 2>/dev/null || wslpath -w "$p" 2>/dev/null || echo "$p")"
                if [ -n "$win_file" ]; then
                    cmd.exe /c start "" "$win_p" "$win_file" >/dev/null 2>&1 &
                else
                    cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
                fi
                echo -e "${GREEN}✓ Winamp launched on Windows.${NC}"
                sleep 1.2
                return 0
            fi
        done
        if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c "where winamp.exe" >/dev/null 2>&1; then
            if [ -n "$win_file" ]; then
                cmd.exe /c start "" "winamp.exe" "$win_file" >/dev/null 2>&1 &
            else
                cmd.exe /c start "" "winamp.exe" >/dev/null 2>&1 &
            fi
            echo -e "${GREEN}✓ Winamp launched on Windows.${NC}"
            sleep 1.2
            return 0
        fi
        echo -e "${RED}Winamp was not found on Windows.${NC}"
        press_enter
        return 1
    else
        echo -e "\n${BOLD}${RED}⚠️  Winamp is a native Windows application.${NC}"
        echo -e "${YELLOW}On Linux & FreeBSD, retro Winamp skin support is available via cliamp retro terminal player or Audacious (audacious -k).${NC}"
        press_enter
        return 1
    fi
}

launch_foobar2000() {
    local file="${1:-}"
    if [ "$OS_TYPE" = "macos" ]; then
        echo -e "\n${BOLD}${YELLOW}Launching foobar2000 on macOS...${NC}\n"
        if [ -n "$file" ] && [ -f "$file" ]; then
            if open -a "foobar2000" "$file" 2>/dev/null; then
                echo -e "${GREEN}✓ Opened '$(basename "$file")' in foobar2000.${NC}"
                sleep 1.2
                return 0
            fi
        else
            if open -a "foobar2000" 2>/dev/null; then
                echo -e "${GREEN}✓ foobar2000 launched on macOS.${NC}"
                sleep 1.2
                return 0
            fi
        fi
        echo -e "${RED}foobar2000 was not found in /Applications.${NC}"
        echo -e "Install with Homebrew: ${CYAN}brew install --cask foobar2000${NC}"
        press_enter
        return 1
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        echo -e "\n${BOLD}${YELLOW}Launching foobar2000 on Windows...${NC}\n"
        local win_file=""
        [ -n "$file" ] && [ -f "$file" ] && win_file="$(cygpath -w "$file" 2>/dev/null || wslpath -w "$file" 2>/dev/null || echo "$file")"

        local fb_paths=(
            "/c/Program Files/foobar2000/foobar2000.exe"
            "/c/Program Files (x86)/foobar2000/foobar2000.exe"
            "$LOCALAPPDATA/Programs/foobar2000/foobar2000.exe"
        )
        for p in "${fb_paths[@]}"; do
            if [ -f "$p" ]; then
                local win_p
                win_p="$(cygpath -w "$p" 2>/dev/null || wslpath -w "$p" 2>/dev/null || echo "$p")"
                if [ -n "$win_file" ]; then
                    cmd.exe /c start "" "$win_p" "$win_file" >/dev/null 2>&1 &
                else
                    cmd.exe /c start "" "$win_p" >/dev/null 2>&1 &
                fi
                echo -e "${GREEN}✓ foobar2000 launched on Windows.${NC}"
                sleep 1.2
                return 0
            fi
        done
        if command -v cmd.exe >/dev/null 2>&1 && cmd.exe /c "where foobar2000.exe" >/dev/null 2>&1; then
            if [ -n "$win_file" ]; then
                cmd.exe /c start "" "foobar2000.exe" "$win_file" >/dev/null 2>&1 &
            else
                cmd.exe /c start "" "foobar2000.exe" >/dev/null 2>&1 &
            fi
            echo -e "${GREEN}✓ foobar2000 launched on Windows.${NC}"
            sleep 1.2
            return 0
        fi
        echo -e "${RED}foobar2000 was not found on Windows.${NC}"
        echo -e "Install with winget: ${CYAN}winget install foobar2000.foobar2000${NC}"
        press_enter
        return 1
    else
        echo -e "\n${YELLOW}foobar2000 is officially supported on macOS and Windows.${NC}"
        echo -e "On Linux/FreeBSD, Strawberry Music Player, VLC, or cliamp is recommended."
        press_enter
        return 1
    fi
}

launch_apple_music() {
    local file="${1:-}"
    if [ "$OS_TYPE" != "macos" ]; then
        echo -e "\n${BOLD}${RED}⚠️  Apple Music is exclusively available on macOS.${NC}"
        press_enter
        return 1
    fi
    echo -e "\n${BOLD}${YELLOW}Launching Apple Music...${NC}\n"
    if [ -n "$file" ] && [ -f "$file" ]; then
        open -a "Music" "$file" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Opened '$(basename "$file")' in Apple Music.${NC}"
    else
        open -a "Music" >/dev/null 2>&1 &
        echo -e "${GREEN}✓ Apple Music launched.${NC}"
    fi
    sleep 1.2
    return 0
}

launch_apple_podcasts() {
    if [ "$OS_TYPE" != "macos" ]; then
        echo -e "\n${BOLD}${RED}⚠️  Apple Podcasts is exclusively available on macOS.${NC}"
        press_enter
        return 1
    fi
    echo -e "\n${BOLD}${YELLOW}Launching Apple Podcasts...${NC}\n"
    open -a "Podcasts" >/dev/null 2>&1 &
    echo -e "${GREEN}✓ Apple Podcasts launched.${NC}"
    sleep 1.2
    return 0
}

open_mix_in_daw() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}            OPEN MIX AUDIO FILE (WAV/FLAC) IN DAW                     ${NC}"
    echo -e "${BOLD}${MAGENTA}   (REAPER, Apple Logic Pro, GarageBand, FL Studio, Audacity, etc.)   ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    shopt -s nullglob nocaseglob
    local wav_candidates=(
        "${ARCHIVE_DIR}"/*.wav
        "${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}/CONVERTED_WAV_FILES"/*.wav
        "${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}"/*.wav
        "${OUTPUT_DIR}"/*.flac
        "$PWD"/*.flac
    )
    shopt -u nullglob nocaseglob

    local selected_file=""

    echo -e "${BOLD}How would you like to select the mix to open?${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Search mix by keyword or episode number (e.g., 033, 041, Who am I)"
    echo -e "  ${BOLD}${CYAN}2)${NC} Select from mixes currently in archiver (${#wav_candidates[@]} available)"
    echo -e "  ${BOLD}${CYAN}3)${NC} Enter custom audio file path manually"
    echo -e "  ${BOLD}${CYAN}0)${NC} Cancel and return\n"
    read -r -p "Enter choice [0-3]: " s_method

    case "$s_method" in
        1)
            read -r -p "Enter search query: " query
            [ -z "$query" ] && return 0
            local matches=()
            for f in "${wav_candidates[@]}"; do
                if echo "$(basename "$f")" | grep -qi "$query"; then
                    matches+=("$f")
                fi
            done
            if [ ${#matches[@]} -eq 0 ]; then
                echo -e "\n${RED}No mixes found matching '${query}'.${NC}"
                press_enter
                return 1
            fi
            echo -e "\n${BOLD}Matching Mixes:${NC}"
            for i in "${!matches[@]}"; do
                echo -e "  ${CYAN}$((i + 1)))${NC} $(basename "${matches[$i]}")"
            done
            read -r -p "Select mix number [1-${#matches[@]}]: " pick
            if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#matches[@]}" ]; then
                selected_file="${matches[$((pick - 1))]}"
            else
                echo -e "${RED}Invalid selection.${NC}"
                sleep 1
                return 1
            fi
            ;;
        2)
            if [ ${#wav_candidates[@]} -eq 0 ]; then
                echo -e "\n${YELLOW}No audio files found in archive directories.${NC}"
                press_enter
                return 1
            fi
            echo -e "\n${BOLD}Available Mixes in Archiver:${NC}"
            local max_show=30
            for i in "${!wav_candidates[@]}"; do
                [ "$i" -ge "$max_show" ] && break
                echo -e "  ${CYAN}$((i + 1)))${NC} $(basename "${wav_candidates[$i]}")"
            done
            read -r -p "Select mix number [1-${#wav_candidates[@]}]: " pick
            if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#wav_candidates[@]}" ]; then
                selected_file="${wav_candidates[$((pick - 1))]}"
            else
                echo -e "${RED}Invalid selection.${NC}"
                sleep 1
                return 1
            fi
            ;;
        3)
            read -r -p "Enter absolute path to WAV or FLAC file: " selected_file
            if [ ! -f "$selected_file" ]; then
                echo -e "${RED}Error: File does not exist!${NC}"
                press_enter
                return 1
            fi
            ;;
        0|[qQ])
            return 0
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            sleep 1
            return 1
            ;;
    esac

    [ -z "$selected_file" ] && return 0

    echo -e "\n${BOLD}Selected Mix:${NC} ${GREEN}$(basename "$selected_file")${NC}"
    echo -e "Full Path:    ${CYAN}${selected_file}${NC}\n"

    echo -e "${BOLD}Select target DAW / Audio Editor to open this mix in:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Cockos REAPER DAW          ${DIM}(Cross-Platform: Linux, macOS, Windows, FreeBSD)${NC}"
    echo -e "  ${BOLD}${CYAN}2)${NC} Apple Logic Pro             ${DIM}(macOS Exclusive)${NC}"
    echo -e "  ${BOLD}${CYAN}3)${NC} Apple GarageBand            ${DIM}(macOS Exclusive)${NC}"
    echo -e "  ${BOLD}${CYAN}4)${NC} Image-Line FL Studio (Fruity Loops) ${DIM}(macOS, Windows, Linux via Wine)${NC}"
    echo -e "  ${BOLD}${CYAN}5)${NC} Audacity Audio Editor       ${DIM}(Cross-Platform: Linux, macOS, Windows, FreeBSD)${NC}"
    echo -e "  ${BOLD}${CYAN}6)${NC} Ardour Digital Audio Workstation"
    echo -e "  ${BOLD}${CYAN}7)${NC} Bitwig Studio"
    echo -e "  ${BOLD}${CYAN}0)${NC} Cancel\n"
    read -r -p "Enter choice [0-7]: " daw_pick

    case "$daw_pick" in
        1)
            echo -e "\n${BOLD}${YELLOW}Opening mix in Cockos REAPER...${NC}\n"
            if [ "$OS_TYPE" = "macos" ]; then
                open -a "REAPER" "$selected_file" >/dev/null 2>&1 &
            elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
                local win_p
                win_p="$(cygpath -w "$selected_file" 2>/dev/null || wslpath -w "$selected_file" 2>/dev/null || echo "$selected_file")"
                cmd.exe /c start "" "reaper.exe" "$win_p" >/dev/null 2>&1 &
            elif command -v reaper >/dev/null 2>&1; then
                nohup reaper "$selected_file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "fm.reaper.Reaper"; then
                nohup flatpak run fm.reaper.Reaper "$selected_file" >/dev/null 2>&1 &
            else
                echo -e "${RED}REAPER is not installed.${NC}"
                press_enter
                return 1
            fi
            echo -e "${GREEN}✓ Mix dispatched to REAPER.${NC}"
            sleep 1.2
            ;;
        2)
            launch_logic_pro "$selected_file"
            ;;
        3)
            launch_garageband "$selected_file"
            ;;
        4)
            launch_fl_studio "$selected_file"
            ;;
        5)
            echo -e "\n${BOLD}${YELLOW}Opening mix in Audacity...${NC}\n"
            play_audio_file "audacity" "$selected_file"
            echo -e "${GREEN}✓ Mix dispatched to Audacity.${NC}"
            sleep 1.2
            ;;
        6)
            if [ "$OS_TYPE" = "macos" ]; then
                open -a "Ardour" "$selected_file" 2>/dev/null &
            elif command -v ardour >/dev/null 2>&1; then
                nohup ardour "$selected_file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "org.ardour.Ardour"; then
                nohup flatpak run org.ardour.Ardour "$selected_file" >/dev/null 2>&1 &
            fi
            echo -e "${GREEN}✓ Mix dispatched to Ardour.${NC}"
            sleep 1.2
            ;;
        7)
            if [ "$OS_TYPE" = "macos" ]; then
                open -a "Bitwig Studio" "$selected_file" 2>/dev/null &
            elif command -v bitwig-studio >/dev/null 2>&1; then
                nohup bitwig-studio "$selected_file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "com.bitwig.BitwigStudio"; then
                nohup flatpak run com.bitwig.BitwigStudio "$selected_file" >/dev/null 2>&1 &
            fi
            echo -e "${GREEN}✓ Mix dispatched to Bitwig Studio.${NC}"
            sleep 1.2
            ;;
        0|[qQ])
            return 0
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            sleep 1
            ;;
    esac
}

generate_spek_single_file() {
    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}   GENERATE SPECTROGRAM USING SPEK FOR WAV/MP3/FLAC (SINGLE FILE)     ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    echo -e "${CYAN}Please enter the full path to the .FLAC, MP3 or WAV audio mix file:${NC}"
    read -e -r -p "Audio Mix Path: " raw_path

    local audio_path
    audio_path="$(echo "$raw_path" | sed -e "s/^['\"]//" -e "s/['\"]$//" | xargs 2>/dev/null || echo "$raw_path")"
    if [ -z "$audio_path" ]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        press_enter
        return 0
    fi

    if [[ "$audio_path" == "~"* ]]; then
        audio_path="${HOME}${audio_path:1}"
    fi

    if [ "$OS_TYPE" = "wsl" ] && command -v wslpath >/dev/null 2>&1; then
        if [[ "$audio_path" =~ ^[A-Za-z]: ]]; then
            audio_path="$(wslpath -u "$audio_path" 2>/dev/null || echo "$audio_path")"
        fi
    elif [ "$OS_TYPE" = "windows" ] && command -v cygpath >/dev/null 2>&1; then
        audio_path="$(cygpath -u "$audio_path" 2>/dev/null || echo "$audio_path")"
    fi

    if [ ! -f "$audio_path" ]; then
        echo -e "\n${RED}Error: Audio mix file not found at '$audio_path'!${NC}"
        press_enter
        return 1
    fi

    local script="$SCRIPT_DIR/generate_spek.sh"
    [ ! -f "$script" ] && script="./generate_spek.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/generate_spek.sh"

    if [ -f "$script" ]; then
        bash "$script" --single-file "$audio_path"
    else
        local dir_path
        dir_path="$(cd "$(dirname "$audio_path")" 2>/dev/null && pwd || dirname "$audio_path")"
        local base_name
        base_name="$(basename "$audio_path")"
        local stem="${base_name%.*}"
        local out_spek="${dir_path}/${stem}.spek"
        local out_spek_png="${dir_path}/${stem}.spek.png"

        echo -e "\n${BOLD}${CYAN}Generating Spek spectrogram...${NC}"
        echo -e "  • ${BOLD}Input Audio:${NC}   ${GREEN}${base_name}${NC}"
        echo -e "  • ${BOLD}Location:${NC}      ${dir_path}"
        echo -e "  • ${BOLD}Output File:${NC}   ${stem}.spek"

        if ! command -v ffmpeg >/dev/null 2>&1; then
            echo -e "${RED}Error: ffmpeg is required to generate spectrograms.${NC}"
            press_enter
            return 1
        fi

        local start_time
        start_time=$(date +%s)
        ffmpeg -hide_banner -loglevel error -y -i "$audio_path" \
            -lavfi "showspectrumpic=s=1920x1080:mode=combined:color=intensity:scale=log:legend=1:saturation=1.2" \
            -frames:v 1 "$out_spek_png"

        if [ $? -eq 0 ] && [ -f "$out_spek_png" ]; then
            cp -f "$out_spek_png" "$out_spek"
            local sz
            sz=$(du -h "$out_spek_png" | cut -f1)
            local end_time
            end_time=$(date +%s)
            local elapsed=$((end_time - start_time))
            echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
            echo -e "${BOLD}${GREEN}✓ Spek Spectrogram Generated Successfully!${NC}"
            echo -e "  • ${BOLD}Spek File:${NC}      ${GREEN}${out_spek}${NC}"
            echo -e "  • ${BOLD}Image File:${NC}     ${GREEN}${out_spek_png}${NC}"
            echo -e "  • ${BOLD}Saved to:${NC}       ${dir_path}"
            echo -e "  • ${BOLD}Size / Time:${NC}    ${sz} (completed in ${elapsed}s)"
            echo -e "${BOLD}${GREEN}======================================================================${NC}\n"

            read -r -p "Do you want to view the Spek file after it has been fully generated? [Y/n]: " view_ask
            if [[ "$view_ask" =~ ^[Yy]?$ ]] || [ -z "$view_ask" ]; then
                echo -e "${CYAN}Displaying Spek file in image viewer...${NC}"
                open_path "$out_spek_png"
            fi
        else
            echo -e "\n${RED}✗ Failed to generate Spek spectrogram for '$base_name'.${NC}"
        fi
    fi
    press_enter
}

generate_spek_multiple_files() {
    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}       GENERATE SPEKS FOR MULTIPLE WAV/MP3/FLAC FILES                 ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
    echo -e "${CYAN}Please enter a path where one or more audio files exist:${NC}"
    read -e -r -p "Directory Path: " raw_dir

    local dir_path
    dir_path="$(echo "$raw_dir" | sed -e "s/^['\"]//" -e "s/['\"]$//" | xargs 2>/dev/null || echo "$raw_dir")"
    if [ -z "$dir_path" ]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        press_enter
        return 0
    fi

    if [[ "$dir_path" == "~"* ]]; then
        dir_path="${HOME}${dir_path:1}"
    fi

    if [ "$OS_TYPE" = "wsl" ] && command -v wslpath >/dev/null 2>&1; then
        if [[ "$dir_path" =~ ^[A-Za-z]: ]]; then
            dir_path="$(wslpath -u "$dir_path" 2>/dev/null || echo "$dir_path")"
        fi
    elif [ "$OS_TYPE" = "windows" ] && command -v cygpath >/dev/null 2>&1; then
        dir_path="$(cygpath -u "$dir_path" 2>/dev/null || echo "$dir_path")"
    fi

    if [ ! -d "$dir_path" ]; then
        echo -e "\n${RED}Error: Directory not found at '$dir_path'!${NC}"
        press_enter
        return 1
    fi

    local script="$SCRIPT_DIR/generate_spek.sh"
    [ ! -f "$script" ] && script="./generate_spek.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/generate_spek.sh"

    if [ -f "$script" ]; then
        bash "$script" --multiple-dir "$dir_path"
    else
        dir_path="$(cd "$dir_path" 2>/dev/null && pwd || echo "$dir_path")"
        shopt -s nullglob nocaseglob
        local audio_files=("$dir_path"/*.flac "$dir_path"/*.wav "$dir_path"/*.mp3 "$dir_path"/*.m4a "$dir_path"/*.ogg "$dir_path"/*.aiff "$dir_path"/*.aif)
        shopt -u nullglob nocaseglob

        if [ ${#audio_files[@]} -eq 0 ]; then
            echo -e "\n${YELLOW}No WAV, MP3, or FLAC audio files found in '$dir_path'.${NC}"
            press_enter
            return 0
        fi

        echo -e "\n${BOLD}${CYAN}Found ${#audio_files[@]} audio file(s) in '$dir_path'. Starting Spek generation...${NC}\n"
        local count=0
        local success_count=0
        local total=${#audio_files[@]}

        for f in "${audio_files[@]}"; do
            count=$((count + 1))
            local base
            base="$(basename "$f")"
            local stem="${base%.*}"
            local file_dir
            file_dir="$(dirname "$f")"
            local out_spek="${file_dir}/${stem}.spek"
            local out_spek_png="${file_dir}/${stem}.spek.png"

            echo -e "  ${BOLD}[${count}/${total}]${NC} ${CYAN}Analyzing:${NC} ${base}"
            ffmpeg -hide_banner -loglevel error -y -i "$f" \
                -lavfi "showspectrumpic=s=1920x1080:mode=combined:color=intensity:scale=log:legend=1:saturation=1.2" \
                -frames:v 1 "$out_spek_png"

            if [ $? -eq 0 ] && [ -f "$out_spek_png" ]; then
                cp -f "$out_spek_png" "$out_spek"
                local sz
                sz=$(du -h "$out_spek_png" | cut -f1)
                echo -e "      ${GREEN}✓ Generated:${NC} ${stem}.spek (${sz})"
                success_count=$((success_count + 1))
            else
                echo -e "      ${RED}✗ Failed generating Spek for: ${base}${NC}"
            fi
        done

        echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
        echo -e "${BOLD}${GREEN}✓ Batch Spek Generation Complete!${NC}"
        echo -e "  • ${BOLD}Success:${NC}        ${success_count} / ${total} Spek files generated"
        echo -e "  • ${BOLD}Location:${NC}       ${dir_path}"
        echo -e "  • ${BOLD}File Format:${NC}    <filename>.spek & <filename>.spek.png"
        echo -e "${BOLD}${GREEN}======================================================================${NC}\n"
    fi
    press_enter
}

manage_spek_generation() {
    local script="$SCRIPT_DIR/generate_spek.sh"
    [ ! -f "$script" ] && script="./generate_spek.sh"
    [ ! -f "$script" ] && script="$SCRIPT_DIR/scripts/generate_spek.sh"

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       ACOUSTIC SPECTRUM ANALYSER & SPECTROGRAM SUITE (SPEK)          ${NC}"
        echo -e "${BOLD}${MAGENTA}         Cross-Platform: Linux • macOS • Windows • FreeBSD            ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

        echo -e "${BOLD}Select a Spectrogram Generation Option:${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}${GREEN}Generate Spectrogram using Spek for WAV/MP3/FLAC (Single File)${NC}"
        echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}${GREEN}Generate Speks for Multiple WAV/MP3/FLAC Files (Scan Directory Path)${NC}"
        echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Generate Spek for Single Mix from Archive (${GREEN}Search or Select & Auto-Open${NC})"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Batch Generate Speks for all FLACs in ${BOLD}FLAC_CONVERTED_OUTPUTS/${NC}"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Batch Generate Speks for all WAVs in ${BOLD}CONVERTED_WAV_FILES/${NC}"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Batch Generate Speks for all Audio Files in Current Directory ($PWD)"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Launch Native Spek GUI Application (${GREEN}Spek.app / spek.exe / spek${NC})"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Browse Generated Spectrograms in ${BOLD}SPEK_OUTPUTS/${NC}"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Sonic Visualiser, SoX & Spectral Analyzers Menu"
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [0-9]: " sp_choice

        case "$sp_choice" in
            1)
                generate_spek_single_file
                ;;
            2)
                generate_spek_multiple_files
                ;;
            3)
                echo ""
                bash "$script"
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${YELLOW}Batch generating spectrograms for FLAC_CONVERTED_OUTPUTS/...${NC}\n"
                bash "$script" -d "FLAC_CONVERTED_OUTPUTS" -o "SPEK_OUTPUTS"
                press_enter
                ;;
            5)
                echo -e "\n${BOLD}${YELLOW}Batch generating spectrograms for CONVERTED_WAV_FILES/...${NC}\n"
                bash "$script" -d "CONVERTED_WAV_FILES" -o "SPEK_OUTPUTS"
                press_enter
                ;;
            6)
                echo -e "\n${BOLD}${YELLOW}Batch generating spectrograms for Current Directory ($PWD)...${NC}\n"
                bash "$script" -d "$PWD" -o "SPEK_OUTPUTS"
                press_enter
                ;;
            7)
                echo ""
                bash "$script" -g
                press_enter
                ;;
            8)
                echo -e "\n${CYAN}Opening SPEK_OUTPUTS/ directory...${NC}"
                open_path "$PWD/SPEK_OUTPUTS"
                sleep 1
                ;;
            9)
                echo -e "\n${BOLD}${MAGENTA}=== ADVANCED SPECTRAL ANALYZERS & SOX SUITE ===${NC}\n"
                echo -e "  ${BOLD}${CYAN}1)${NC} Launch Sonic Visualiser (Open mix in Spectrogram pane)"
                echo -e "  ${BOLD}${CYAN}2)${NC} Generate SoX High-Resolution Spectrogram (Viridis, Magma, Rainbow, Mono)"
                echo -e "  ${BOLD}${CYAN}3)${NC} Launch Praat / Kwave / Audacity Spectral Analyzer"
                echo -e "  ${BOLD}${CYAN}0)${NC} Back to Spek Menu\n"
                read -r -p "Enter choice [0-3]: " a_choice
                case "$a_choice" in
                    1)
                        read -e -r -p "Enter path to audio mix (or press Enter): " sfile
                        bash "$script" -i "$sfile" --gui 2>/dev/null || bash "$script"
                        press_enter
                        ;;
                    2)
                        read -e -r -p "Enter path to audio mix: " sxfile
                        bash "$script" -i "$sxfile" -c "magma"
                        press_enter
                        ;;
                    3)
                        read -e -r -p "Enter path to audio mix: " prfile
                        bash "$script" -i "$prfile" --gui 2>/dev/null || true
                        press_enter
                        ;;
                esac
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

manage_daws() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}     DIGITAL AUDIO WORKSTATIONS (DAWs) & EDITORS    ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        local current_datetime
        current_datetime=$(date "+%A, %B %d, %Y  •  %T %Z")
        echo -e "       ${BOLD}${CYAN}📅 ${current_datetime}${NC}"
        echo ""

        local reaper_badge="${RED}[NOT INSTALLED]${NC}"
        local audacity_badge="${RED}[NOT INSTALLED]${NC}"
        local ardour_badge="${YELLOW}[AVAILABLE]${NC}"
        local lmms_badge="${YELLOW}[AVAILABLE]${NC}"
        local bitwig_badge="${YELLOW}[AVAILABLE]${NC}"
        local bespoke_badge="${YELLOW}[AVAILABLE]${NC}"
        local logic_badge="${YELLOW}[macOS Only]${NC}"
        local garage_badge="${YELLOW}[macOS Only]${NC}"
        local fl_badge="${YELLOW}[AVAILABLE]${NC}"
        local traktor_badge="${YELLOW}[macOS & Windows Only]${NC}"

        is_app_installed "reaper" "fm.reaper.Reaper" "REAPER" "REAPER (x64)/reaper.exe" && reaper_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "audacity" "org.audacityteam.Audacity" "Audacity" "Audacity/Audacity.exe" && audacity_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "ardour" "org.ardour.Ardour" "Ardour" "Ardour/bin/ardour.exe" && ardour_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "lmms" "io.lmms.LMMS" "LMMS" "LMMS/lmms.exe" && lmms_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "bitwig-studio" "com.bitwig.BitwigStudio" "Bitwig Studio" "Bitwig Studio/bin/BitwigStudio.exe" && bitwig_badge="${GREEN}✓ INSTALLED${NC}"
        is_app_installed "bespokesynth" "com.bespokesynth.BespokeSynth" "BespokeSynth" "BespokeSynth/BespokeSynth.exe" && bespoke_badge="${GREEN}✓ INSTALLED${NC}"

        if [ "$OS_TYPE" = "macos" ]; then
            if [ -d "/Applications/Logic Pro.app" ] || [ -d "/Applications/Logic Pro X.app" ] || osascript -e 'id of application "Logic Pro"' >/dev/null 2>&1; then
                logic_badge="${GREEN}✓ INSTALLED${NC}"
            else
                logic_badge="${RED}[NOT INSTALLED]${NC}"
            fi
            if [ -d "/Applications/GarageBand.app" ] || osascript -e 'id of application "GarageBand"' >/dev/null 2>&1; then
                garage_badge="${GREEN}✓ INSTALLED${NC}"
            else
                garage_badge="${RED}[NOT INSTALLED]${NC}"
            fi
            if [ -d "/Applications/Native Instruments/Traktor Pro 3/Traktor.app" ] || [ -d "/Applications/Native Instruments/Traktor Pro 4/Traktor.app" ] || [ -d "/Applications/Traktor Pro 4.app" ] || [ -d "/Applications/Traktor Pro 3.app" ] || [ -d "/Applications/Traktor.app" ] || osascript -e 'id of application "Traktor"' >/dev/null 2>&1; then
                traktor_badge="${GREEN}✓ INSTALLED${NC}"
            else
                traktor_badge="${RED}[NOT INSTALLED]${NC}"
            fi
            if [ -d "/Applications/FL Studio 2024.app" ] || [ -d "/Applications/FL Studio 21.app" ] || [ -d "/Applications/FL Studio.app" ]; then
                fl_badge="${GREEN}✓ INSTALLED${NC}"
            fi
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            if [ -f "/c/Program Files/Native Instruments/Traktor Pro 4/Traktor.exe" ] || [ -f "/c/Program Files/Native Instruments/Traktor Pro 3/Traktor.exe" ]; then
                traktor_badge="${GREEN}✓ INSTALLED${NC}"
            else
                traktor_badge="${YELLOW}[AVAILABLE]${NC}"
            fi
            if [ -f "/c/Program Files/Image-Line/FL Studio 2024/FL64.exe" ] || [ -f "/c/Program Files/Image-Line/FL Studio 21/FL64.exe" ]; then
                fl_badge="${GREEN}✓ INSTALLED${NC}"
            fi
        fi

        echo -e "${BOLD}Select a DAW or Audio Editor to launch (or install):${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Launch REAPER DAW (${reaper_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Launch Audacity Audio Editor (${audacity_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Launch / Install Ardour DAW (${ardour_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Launch / Install LMMS Studio (${lmms_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Launch / Install Bitwig Studio (${bitwig_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Launch / Install Bespoke Synth (${bespoke_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Launch Apple Logic Pro (${logic_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Launch Apple GarageBand (${garage_badge}${NC})"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Launch Image-Line FL Studio / Fruity Loops (${fl_badge}${NC})"
        echo -e "  ${BOLD}${CYAN}10)${NC} Launch Native Instruments Traktor Pro (${traktor_badge}${NC})"
        echo -e "  ${BOLD}${CYAN}11)${NC} Launch Traktor Live Monitor & Audio Recorder (${GREEN}New Window - CPU, Decks, Recording, Audio I/O${NC})"
        if [ "$OS_TYPE" = "macos" ]; then
            local t_ver
            t_ver="$(get_traktor_version_mac 2>/dev/null || echo "3")"
            if [ -n "$t_ver" ] && [ "$t_ver" != "3" ]; then
                echo -e "  ${BOLD}${CYAN}12)${NC} Generate Playlist from History Files on Traktor 3 (${GREEN}v${t_ver} Key Sorted / Decks Ready${NC})"
            else
                echo -e "  ${BOLD}${CYAN}12)${NC} Generate Playlist from History Files on Traktor 3 (${GREEN}Key Sorted / Decks Ready${NC})"
            fi
            echo -e "  ${BOLD}${BLUE}────────────────────────────────────────────────────${NC}"
            echo -e "  ${BOLD}${CYAN}13)${NC} ${BOLD}${GREEN}Open Mix WAV/FLAC Audio File in DAW...${NC} (Reaper, Logic Pro, FL Studio)"
            echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [0-13]: " d_choice
        else
            echo -e "  ${BOLD}${BLUE}────────────────────────────────────────────────────${NC}"
            echo -e "  ${BOLD}${CYAN}12)${NC} ${BOLD}${GREEN}Open Mix WAV/FLAC Audio File in DAW...${NC} (Reaper, Logic Pro, FL Studio)"
            echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu"
            echo ""
            read -r -p "Enter choice [0-12]: " d_choice
        fi

        case "$d_choice" in
            1)
                launch_gui_app "REAPER" "reaper" "fm.reaper.Reaper" "REAPER" "reaper" "REAPER (x64)/reaper.exe" "Cockos.REAPER"
                ;;
            2)
                launch_audacity
                ;;
            3)
                launch_gui_app "Ardour" "ardour" "org.ardour.Ardour" "Ardour" "ardour" "Ardour/bin/ardour.exe" ""
                ;;
            4)
                launch_gui_app "LMMS" "lmms" "io.lmms.LMMS" "LMMS" "lmms" "LMMS/lmms.exe" "LMMS.LMMS"
                ;;
            5)
                launch_gui_app "Bitwig Studio" "bitwig-studio" "com.bitwig.BitwigStudio" "Bitwig Studio" "bitwig-studio" "Bitwig Studio/bin/BitwigStudio.exe" "Bitwig.BitwigStudio"
                ;;
            6)
                launch_gui_app "Bespoke Synth" "bespokesynth" "com.bespokesynth.BespokeSynth" "BespokeSynth" "bespoke-synth" "BespokeSynth/BespokeSynth.exe" ""
                ;;
            7)
                launch_logic_pro
                ;;
            8)
                launch_garageband
                ;;
            9)
                launch_fl_studio
                ;;
            10)
                launch_traktor
                ;;
            11)
                launch_traktor_monitor_window
                ;;
            12)
                if [ "$OS_TYPE" = "macos" ]; then
                    generate_traktor_playlist_from_history
                else
                    open_mix_in_daw
                fi
                ;;
            13)
                if [ "$OS_TYPE" = "macos" ]; then
                    open_mix_in_daw
                else
                    echo -e "\n${RED}Invalid choice!${NC}"
                    sleep 1.2
                fi
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

play_audio_file() {
    local player="${1:-${DEFAULT_AUDIO_PLAYER:-audacious}}"
    local file="$2"
    [ -z "$file" ] && return 1

    case "$player" in
        audacious)
            if get_audacious_track_info 2>/dev/null && [ "$AUDACIOUS_STATE" = "playing" ]; then
                if [ "$AUDACIOUS_RESOLVED_PATH" = "$file" ] || [ "$AUDACIOUS_RAW_PATH" = "$file" ]; then
                    align_mix_windows_on_screen --expect-audacious
                    return 0
                fi
            fi
            if command -v audacious >/dev/null 2>&1; then
                nohup audacious "$file" >/dev/null 2>&1 &
                disown 2>/dev/null || true
            elif flatpak list 2>/dev/null | grep -q "org.atheme.audacious"; then
                nohup flatpak run org.atheme.audacious "$file" >/dev/null 2>&1 &
                disown 2>/dev/null || true
            elif [ "$OS_TYPE" = "macos" ]; then
                open -a Audacious "$file" >/dev/null 2>&1 &
            fi
            align_mix_windows_on_screen --expect-audacious
            ;;
        cliamp)
            local cliamp_bin="cliamp"
            command -v cliamp >/dev/null 2>&1 || cliamp_bin="$SCRIPT_DIR/bin/cliamp"
            [ ! -x "$cliamp_bin" ] && cliamp_bin="$HOME/.local/bin/cliamp"
            if pgrep -x cliamp >/dev/null 2>&1; then
                "$cliamp_bin" queue "$file" 2>/dev/null || true
                sleep 0.3
                "$cliamp_bin" play 2>/dev/null || true
            else
                local full_cmd="\"$cliamp_bin\" queue \"$file\" 2>/dev/null; \"$cliamp_bin\" --auto-play play 2>/dev/null || \"$cliamp_bin\" --auto-play"
                launch_in_terminal "cliamp - $(basename "$file")" "$full_cmd" "window"
            fi
            ;;
        strawberry)
            if get_strawberry_track_info 2>/dev/null && [ "$STRAWBERRY_STATE" = "playing" ]; then
                if [ "$STRAWBERRY_RESOLVED_PATH" = "$file" ] || [ "$STRAWBERRY_RAW_PATH" = "$file" ]; then
                    align_mix_windows_on_screen --expect-strawberry
                    return 0
                fi
            fi
            if command -v strawberry >/dev/null 2>&1; then
                nohup strawberry "$file" >/dev/null 2>&1 &
                disown 2>/dev/null || true
            elif flatpak list 2>/dev/null | grep -q "org.strawberrymusicplayer.strawberry"; then
                nohup flatpak run org.strawberrymusicplayer.strawberry "$file" >/dev/null 2>&1 &
                disown 2>/dev/null || true
            elif [ "$OS_TYPE" = "macos" ]; then
                open -a Strawberry "$file" >/dev/null 2>&1 &
            fi
            align_mix_windows_on_screen --expect-strawberry
            ;;
        vlc)
            if command -v vlc >/dev/null 2>&1; then
                nohup vlc "$file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "org.videolan.VLC"; then
                nohup flatpak run org.videolan.VLC "$file" >/dev/null 2>&1 &
            elif [ "$OS_TYPE" = "macos" ]; then
                open -a VLC "$file" >/dev/null 2>&1 &
            fi
            ;;
        haruna)
            if command -v haruna >/dev/null 2>&1; then
                nohup haruna "$file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "org.kde.haruna"; then
                nohup flatpak run org.kde.haruna "$file" >/dev/null 2>&1 &
            fi
            ;;
        kodi)
            if command -v kodi >/dev/null 2>&1; then
                nohup kodi "$file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi"; then
                nohup flatpak run tv.kodi.Kodi "$file" >/dev/null 2>&1 &
            fi
            ;;
        audacity)
            if command -v audacity >/dev/null 2>&1; then
                nohup audacity "$file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "org.audacityteam.Audacity"; then
                nohup flatpak run org.audacityteam.Audacity "$file" >/dev/null 2>&1 &
            fi
            ;;
        mpv)
            if command -v mpv >/dev/null 2>&1; then
                nohup mpv "$file" >/dev/null 2>&1 &
            fi
            ;;
        winamp)
            launch_winamp "$file"
            ;;
        foobar2000)
            launch_foobar2000 "$file"
            ;;
        music|apple_music)
            launch_apple_music "$file"
            ;;
        garageband)
            launch_garageband "$file"
            ;;
        logic|logic_pro)
            launch_logic_pro "$file"
            ;;
        reaper)
            if [ "$OS_TYPE" = "macos" ]; then
                open -a "REAPER" "$file" >/dev/null 2>&1 &
            elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
                local win_p
                win_p="$(cygpath -w "$file" 2>/dev/null || wslpath -w "$file" 2>/dev/null || echo "$file")"
                cmd.exe /c start "" "reaper.exe" "$win_p" >/dev/null 2>&1 &
            elif command -v reaper >/dev/null 2>&1; then
                nohup reaper "$file" >/dev/null 2>&1 &
            elif flatpak list 2>/dev/null | grep -q "fm.reaper.Reaper"; then
                nohup flatpak run fm.reaper.Reaper "$file" >/dev/null 2>&1 &
            fi
            ;;
        flstudio|fl_studio)
            launch_fl_studio "$file"
            ;;
        *)
            if command -v "$player" >/dev/null 2>&1; then
                nohup "$player" "$file" >/dev/null 2>&1 &
            elif [ "$player" != "audacious" ] && (command -v audacious >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "org.atheme.audacious"); then
                play_audio_file "audacious" "$file"
            elif [ "$player" != "strawberry" ] && command -v strawberry >/dev/null 2>&1; then
                play_audio_file "strawberry" "$file"
            else
                play_audio_file "cliamp" "$file"
            fi
            ;;
    esac

    if [ "${AUTO_SHOW_PLAYING_ASSETS:-true}" = "true" ] && [ "${SKIP_PLAYING_ASSETS:-0}" -ne 1 ]; then
        auto_show_playing_mix_assets "$file" "$player"
    fi
}

collect_converted_mix_dirs() {
    local -a dirs=()
    local seen="|"
    local cand resolved rel adir kind

    add_converted_dir() {
        cand="$1"
        [ -n "$cand" ] || return 0
        if ! is_internet_connected && is_remote_or_cloud_path "$cand"; then
            return 0
        fi
        [ -d "$cand" ] || return 0
        resolved="$(cd "$cand" 2>/dev/null && pwd -P)" || return 0
        case "$seen" in
            *"|$resolved|"*) return 0 ;;
        esac
        seen="${seen}${resolved}|"
        dirs+=("$resolved")
    }

    for rel in "${OUTPUT_DIR:-}" "${MP3_OUTPUT_DIR:-}" "${WAV_OUTPUT_DIR:-}"; do
        [ -z "$rel" ] && continue
        add_converted_dir "$rel"
        if [ -n "${MIX_ARCHIVE_DIR:-}" ]; then
            add_converted_dir "${MIX_ARCHIVE_DIR%/}/$rel"
        fi
    done

    if command -v get_all_mix_archive_dirs >/dev/null 2>&1; then
        while IFS= read -r adir; do
            [ -z "$adir" ] && continue
            case "$adir" in
                *FLAC_CONVERTED_OUTPUTS|*FLAC_CONVERTED_OUTPUTS/|\
                *MP3_CONVERTED_OUTPUTS|*MP3_CONVERTED_OUTPUTS/|\
                *WAV_CONVERTED_OUTPUTS|*WAV_CONVERTED_OUTPUTS/)
                    add_converted_dir "$adir"
                    ;;
            esac
            for kind in FLAC_CONVERTED_OUTPUTS MP3_CONVERTED_OUTPUTS WAV_CONVERTED_OUTPUTS; do
                add_converted_dir "${adir%/}/$kind"
            done
        done < <(get_all_mix_archive_dirs)
    fi

    [ ${#dirs[@]} -gt 0 ] && printf '%s\n' "${dirs[@]}"
}

select_startup_mix() {
    local mode="${AUTO_PLAY_MIX_SELECTION:-latest}"
    local list d
    list="$(mktemp "${TMPDIR:-/tmp}/sof_startup_XXXXXX")"
    while IFS= read -r d; do
        if ! is_internet_connected && is_remote_or_cloud_path "$d"; then
            continue
        fi
        [ -d "$d" ] || continue
        find "$d" -maxdepth 1 -type f \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.wav' \) -print >> "$list"
    done < <(collect_converted_mix_dirs)
    if [ ! -s "$list" ]; then
        rm -f "$list"
        return 1
    fi
    python3 - "$mode" "$list" << 'PY'
import os, random, re, sys
mode = sys.argv[1]

def paths_open_for_write(candidates):
    wanted = set()
    for path in candidates:
        wanted.add(path)
        try:
            wanted.add(os.path.realpath(path))
        except OSError:
            pass
    writing = set()
    if not os.path.isdir("/proc"):
        return writing
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        fd_dir = "/proc/" + pid + "/fd"
        try:
            fds = os.listdir(fd_dir)
        except OSError:
            continue
        for fd in fds:
            fd_path = fd_dir + "/" + fd
            try:
                target = os.path.realpath(os.readlink(fd_path))
            except OSError:
                continue
            if target not in wanted:
                continue
            try:
                info = open("/proc/" + pid + "/fdinfo/" + fd, encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            flags = ""
            for line in info.splitlines():
                if line.startswith("flags:"):
                    parts = line.split()
                    flags = parts[1] if len(parts) > 1 else ""
                    break
            try:
                # O_RDONLY is 0, O_WRONLY is 1, O_RDWR is 2.
                if int(flags, 8) & 3:
                    writing.add(target)
            except ValueError:
                continue
    return writing

raw_files = []
seen = set()
with open(sys.argv[2], encoding="utf-8", errors="ignore") as fh:
    for line in fh:
        path = line.strip()
        if not path or path in seen or not os.path.isfile(path):
            continue
        seen.add(path)
        raw_files.append(path)
writing = paths_open_for_write(raw_files)
files = []
for path in raw_files:
    try:
        if os.path.getsize(path) <= 0:
            continue
        if os.path.realpath(path) in writing:
            continue
    except OSError:
        continue
    files.append(path)
if not files:
    sys.exit(1)

def stem(path):
    return os.path.splitext(os.path.basename(path))[0].lower()

rank = {".flac": 0, ".wav": 1, ".mp3": 2}

def prefer_sibling(chosen):
    chosen_stem = stem(chosen)
    siblings = [path for path in files if stem(path) == chosen_stem]
    siblings.sort(key=lambda path: (rank.get(os.path.splitext(path)[1].lower(), 9), -os.path.getmtime(path)))
    return siblings[0]

if mode == "random":
    pick = prefer_sibling(random.choice(files))
elif mode == "latest":
    pick = prefer_sibling(max(files, key=lambda path: os.path.getmtime(path)))
else:
    try:
        pattern = re.compile(mode, re.IGNORECASE)
        matched = [path for path in files if pattern.search(os.path.basename(path))]
    except re.error:
        needle = mode.lower()
        matched = [path for path in files if needle in os.path.basename(path).lower()]
    pool = matched or files
    pool.sort(key=lambda path: os.path.getmtime(path), reverse=True)
    pick = prefer_sibling(pool[0])
print(pick)
PY
    local py_rc=$?
    rm -f "$list"
    return "$py_rc"
}

same_mix_file() {
    local left="$1" right="$2"
    [ -n "$left" ] && [ -n "$right" ] || return 1
    [ "$left" = "$right" ] && return 0
    local left_real right_real
    left_real="$(readlink -f "$left" 2>/dev/null || echo "$left")"
    right_real="$(readlink -f "$right" 2>/dev/null || echo "$right")"
    [ "$left_real" = "$right_real" ] && return 0
    [ "$(basename "$left_real")" = "$(basename "$right_real")" ]
}

audacious_dbus_ready() {
    qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Length >/dev/null 2>&1
}

play_audacious_file_now() {
    local file="$1"
    # An empty or missing file must not be handed to Audacious. Launching the
    # player with no file restores the saved playlist and starts that song.
    [ -s "$file" ] || return 1

    if ! audacious_dbus_ready; then
        if command -v audacious >/dev/null 2>&1; then
            nohup audacious >/dev/null 2>&1 &
            disown 2>/dev/null || true
        elif flatpak list 2>/dev/null | grep -q "org.atheme.audacious"; then
            nohup flatpak run org.atheme.audacious >/dev/null 2>&1 &
            disown 2>/dev/null || true
        elif [ "${OS_TYPE:-}" = "macos" ]; then
            open -a Audacious "$file" >/dev/null 2>&1 &
            return 0
        else
            return 1
        fi
        local wait_i
        for wait_i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40; do
            audacious_dbus_ready && break
            sleep 0.5
        done
    fi
    audacious_dbus_ready || return 1

    python3 - "$file" << 'PY'
import os, sys, time, urllib.parse
target = os.path.realpath(sys.argv[1])
target_base = os.path.basename(target)
uri = "file://" + urllib.parse.quote(target)

def normalize(raw):
    text = urllib.parse.unquote(str(raw or ""))
    if text.startswith("file://"):
        text = text[7:]
    elif text.startswith("file:"):
        text = text[5:]
    if text and os.path.exists(text):
        text = os.path.realpath(text)
    return text

def matches(raw):
    path = normalize(raw)
    return path == target or os.path.basename(path) == target_base

try:
    import dbus
except Exception:
    sys.exit(1)

bus = dbus.SessionBus()
obj = bus.get_object("org.atheme.audacious", "/org/atheme/audacious")
player = dbus.Interface(obj, "org.atheme.audacious")

def length():
    return int(player.Length())

def position():
    return int(player.Position())

def song_at(index):
    return player.SongFilename(dbus.UInt32(index))

def current_matches():
    try:
        return matches(song_at(position()))
    except Exception:
        return False

# DBus comes up before the saved playlist is loaded. Jumping in that window
# is thrown away when Audacious restores the previous song.
last = None
stable = 0
deadline = time.time() + 4
while time.time() < deadline:
    try:
        current = length()
    except Exception:
        time.sleep(0.2)
        continue
    if current == last:
        stable += 1
        if stable >= 3:
            break
    else:
        stable = 0
        last = current
    time.sleep(0.2)

def find_index():
    total = length()
    for index in range(total):
        try:
            if matches(song_at(index)):
                return index
        except Exception:
            continue
    return None

def ensure_index():
    found = find_index()
    if found is not None:
        return found
    try:
        player.Add(uri)
    except Exception:
        return None
    wait_until = time.time() + 2.5
    while time.time() < wait_until:
        found = find_index()
        if found is not None:
            return found
        time.sleep(0.15)
    return None

try:
    shuffle_on = bool(player.Shuffle())
except Exception:
    shuffle_on = False

for _attempt in range(3):
    found = ensure_index()
    if found is None:
        time.sleep(0.3)
        continue
    try:
        if shuffle_on and bool(player.Shuffle()):
            player.ToggleShuffle()
        player.Stop()
        player.Jump(dbus.UInt32(found))
        player.Play()
        if shuffle_on and not bool(player.Shuffle()):
            player.ToggleShuffle()
    except Exception:
        time.sleep(0.3)
        continue
    held = True
    for _sample in range(4):
        time.sleep(0.2)
        if not current_matches():
            held = False
            break
    if held:
        sys.exit(0)

sys.exit(1)
PY
}

execute_startup_autoplay() {
    if [ "${AUTO_PLAY_ON_STARTUP:-true}" != "true" ]; then
        return 0
    fi

    local selected_mix=""
    selected_mix="$(select_startup_mix)" || true
    if [ -z "$selected_mix" ] || [ ! -s "$selected_mix" ]; then
        return 0
    fi

    if ! is_internet_connected && is_remote_or_cloud_path "$selected_mix"; then
        STARTUP_AUTOPLAY_NOTICE="Latest mix is on cloud storage (offline, playback skipped)"
        return 0
    fi
    STARTUP_AUTOPLAY_NOTICE="Latest converted mix: $(basename "$selected_mix")"

    local player="${DEFAULT_AUDIO_PLAYER:-audacious}"
    local SKIP_PLAYING_ASSETS=1
    local current_path=""
    local current_state=""

    if [ "$player" = "audacious" ] && get_audacious_track_info 2>/dev/null; then
        current_path="$AUDACIOUS_RESOLVED_PATH"
        current_state="$AUDACIOUS_STATE"
    elif [ "$player" = "strawberry" ] && get_strawberry_track_info 2>/dev/null; then
        current_path="$STRAWBERRY_RESOLVED_PATH"
        current_state="$STRAWBERRY_STATE"
    else
        local detected_mix=""
        detected_mix="$(detect_currently_playing_mix 2>/dev/null || true)"
        if [ -n "$detected_mix" ] && [ -f "$detected_mix" ]; then
            current_path="$detected_mix"
            current_state="playing"
        fi
    fi

    if same_mix_file "$current_path" "$selected_mix" && [ "$current_state" = "playing" ]; then
        :
    elif same_mix_file "$current_path" "$selected_mix"; then
        if [ "$player" = "audacious" ]; then
            qdbus org.atheme.audacious /org/atheme/audacious org.atheme.audacious.Play >/dev/null 2>&1 \
                || audtool playback-play >/dev/null 2>&1 \
                || true
        else
            play_audio_file "$player" "$selected_mix"
        fi
    elif [ "$player" = "audacious" ]; then
        # play_audio_file only enqueues when Audacious is already running, which
        # leaves the restored playlist song playing. Retry the direct jump.
        if ! play_audacious_file_now "$selected_mix"; then
            if ! play_audacious_file_now "$selected_mix"; then
                STARTUP_AUTOPLAY_NOTICE="Could not start $(basename "$selected_mix"). Audacious kept its previous mix."
            fi
        fi
    else
        play_audio_file "$player" "$selected_mix"
    fi

    local found_cover=""
    if [ "${AUTO_SHOW_COVER_ON_STARTUP:-false}" = "true" ]; then
        found_cover=$(find_mix_cover "$selected_mix" 2>/dev/null)
        if [ -n "$found_cover" ] && [ -f "$found_cover" ]; then
            open_cover_art_window "$found_cover"
        fi
    fi

    local num_displays
    num_displays=$(get_connected_displays_count)
    if [ "$num_displays" -le 1 ]; then
        local found_tl=""
        if [ "${AUTO_SHOW_TRACKLIST_ON_STARTUP:-true}" = "true" ]; then
            found_tl=$(find_mix_tracklist "$selected_mix" 2>/dev/null)
            if [ -n "$found_tl" ] && [ -f "$found_tl" ]; then
                open_tracklist_window "$found_tl"
            fi
        fi
    fi

    local align_args=()
    [ "$player" = "audacious" ] && align_args+=(--expect-audacious)
    [ "$player" = "strawberry" ] && align_args+=(--expect-strawberry)
    [ -n "$found_cover" ] && align_args+=(--expect-cover)
    align_mix_windows_on_screen "${align_args[@]}"

    if [ "${AUTO_PLAY_YOUTUBE_ON_STARTUP:-false}" = "true" ] && [ -n "${STARTUP_YOUTUBE_URL:-}" ]; then
        (sleep 0.6; open_video_url "$STARTUP_YOUTUBE_URL" >/dev/null 2>&1 || true) &
    fi

    return 0
}

configure_audio_player_and_startup() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}      DEFAULT AUDIO PLAYER & STARTUP AUTOPLAY CONFIGURATION           ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

        local audacious_st="Not Installed"
        (command -v audacious >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "org.atheme.audacious") && audacious_st="${GREEN}Installed${NC}"
        local cliamp_st="Not Installed"
        (command -v cliamp >/dev/null 2>&1 || [ -x "$SCRIPT_DIR/bin/cliamp" ] || [ -x "$HOME/.local/bin/cliamp" ]) && cliamp_st="${GREEN}Installed${NC}"
        local straw_st="Not Installed"
        (command -v strawberry >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "org.strawberrymusicplayer.strawberry") && straw_st="${GREEN}Installed${NC}"
        local vlc_st="Not Installed"
        (command -v vlc >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "org.videolan.VLC") && vlc_st="${GREEN}Installed${NC}"
        local haruna_st="Not Installed"
        (command -v haruna >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "org.kde.haruna") && haruna_st="${GREEN}Installed${NC}"
        local kodi_st="Not Installed"
        (command -v kodi >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "tv.kodi.Kodi") && kodi_st="${GREEN}Installed${NC}"
        local audacity_st="Not Installed"
        (command -v audacity >/dev/null 2>&1 || flatpak list 2>/dev/null | grep -q "org.audacityteam.Audacity") && audacity_st="${GREEN}Installed${NC}"
        local mpv_st="Not Installed"
        command -v mpv >/dev/null 2>&1 && mpv_st="${GREEN}Installed${NC}"
        local foobar_st="Not Installed"
        (command -v foobar2000 >/dev/null 2>&1 || [ -d "/Applications/foobar2000.app" ] || [ -f "/c/Program Files/foobar2000/foobar2000.exe" ]) && foobar_st="${GREEN}Installed${NC}"
        local winamp_st="Not Installed"
        ([ -f "/c/Program Files (x86)/Winamp/winamp.exe" ] || [ -f "/c/Program Files/Winamp/winamp.exe" ] || command -v winamp >/dev/null 2>&1) && winamp_st="${GREEN}Installed${NC}"
        local music_st="Not Installed"
        ([ "$OS_TYPE" = "macos" ] && osascript -e 'id of application "Music"' >/dev/null 2>&1) && music_st="${GREEN}Installed${NC}"

        echo -e "  ${BOLD}Current Settings:${NC}"
        echo -e "  • Default Audio Player:          ${BOLD}${GREEN}${DEFAULT_AUDIO_PLAYER:-audacious}${NC}"
        
        local ap_badge="${RED}DISABLED${NC}"
        [ "${AUTO_PLAY_ON_STARTUP:-true}" = "true" ] && ap_badge="${GREEN}ENABLED${NC}"
        echo -e "  • Auto-Play Mix on Startup:      ${ap_badge}"

        local cov_badge="${RED}DISABLED${NC}"
        [ "${AUTO_SHOW_COVER_ON_STARTUP:-false}" = "true" ] && cov_badge="${GREEN}ENABLED${NC}"
        echo -e "  • Auto-Show Cover Art on Boot:   ${cov_badge}"

        local tl_badge="${RED}DISABLED${NC}"
        [ "${AUTO_SHOW_TRACKLIST_ON_STARTUP:-true}" = "true" ] && tl_badge="${GREEN}ENABLED${NC}"
        echo -e "  • Auto-Show Tracklist on Boot:   ${tl_badge}"
        echo -e "  • Tracklist Window Viewer:       ${BOLD}${CYAN}${TRACKLIST_VIEWER:-console}${NC} (Dedicated Window)"

        echo -e "  • Startup Mix Selection Mode:    ${BOLD}${CYAN}${AUTO_PLAY_MIX_SELECTION:-latest}${NC} (Newest converted mix, or Random)"
        echo -e "  • Default Video Player:          ${BOLD}${GREEN}${DEFAULT_VIDEO_PLAYER:-vlc}${NC}"

        local yt_badge="${RED}DISABLED${NC}"
        [ "${AUTO_PLAY_YOUTUBE_ON_STARTUP:-false}" = "true" ] && yt_badge="${GREEN}ENABLED${NC}"
        echo -e "  • Startup YouTube Autoplay:      ${yt_badge} ${DIM}(Plays only when mix audio is playing)${NC}"
        if [ -n "${STARTUP_YOUTUBE_URL:-}" ]; then
            echo -e "  • Startup YouTube URL:           ${CYAN}${STARTUP_YOUTUBE_URL}${NC}"
        fi

        local w_badge="${RED}DISABLED${NC}"
        [ "${WEATHER_ENABLED:-true}" = "true" ] && w_badge="${GREEN}ENABLED${NC}"
        echo -e "  • Live Weather Banner:           ${w_badge} ${DIM}(${WEATHER_LOCATION:-Swansea, UK})${NC}"
        echo -e "  • Config File Location:          ${DIM}${SCRIPT_DIR}/config.env${NC}\n"

        echo -e "${BOLD}Select Player or Setting to Change:${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Set Default Player to: ${BOLD}Audacious${NC} (Audio Player) [${audacious_st}]"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Set Default Player to: ${BOLD}cliamp${NC} (Retro Terminal Player) [${cliamp_st}]"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Set Default Player to: ${BOLD}Strawberry${NC} (Music Player) [${straw_st}]"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Set Default Player to: ${BOLD}VLC Media Player${NC} [${vlc_st}]"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Set Default Player to: ${BOLD}Haruna Media Player${NC} [${haruna_st}]"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Set Default Player to: ${BOLD}Kodi Entertainment Center${NC} [${kodi_st}]"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Set Default Player to: ${BOLD}foobar2000${NC} (macOS & Windows) [${foobar_st}]"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Set Default Player to: ${BOLD}Winamp${NC} (Windows) [${winamp_st}]"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Set Default Player to: ${BOLD}Apple Music${NC} (macOS) [${music_st}]"
        echo -e "  ${BOLD}${CYAN}10)${NC} Set Default Player to: ${BOLD}Audacity Audio Editor${NC} [${audacity_st}]"
        echo -e "  ${BOLD}${CYAN}11)${NC} Set Default Player to: ${BOLD}mpv Video/Audio Player${NC} [${mpv_st}]"
        echo -e "  ${BOLD}${CYAN}12)${NC} Set Custom Audio Player Command / Binary"
        echo -e "  ${BOLD}${BLUE}──────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${BOLD}${CYAN}13)${NC} Toggle Auto-Play Mix on Startup (${ap_badge})"
        echo -e "  ${BOLD}${CYAN}14)${NC} Toggle Auto-Show Cover Art on Startup (${cov_badge})"
        echo -e "  ${BOLD}${CYAN}15)${NC} Toggle Auto-Show Tracklist on Startup (${tl_badge})"
        echo -e "  ${BOLD}${CYAN}16)${NC} Toggle Startup Mix Selection (Latest vs Random)"
        echo -e "  ${BOLD}${CYAN}17)${NC} Test-Play Latest Mix Right Now in Default Player (${DEFAULT_AUDIO_PLAYER})"
        echo -e "  ${BOLD}${CYAN}18)${NC} Configure Tracklist Window Viewer (${BOLD}${TRACKLIST_VIEWER:-console}${NC})"
        echo -e "  ${BOLD}${CYAN}19)${NC} Configure Default Video Player (${BOLD}${DEFAULT_VIDEO_PLAYER:-vlc}${NC})"
        echo -e "  ${BOLD}${CYAN}20)${NC} Configure Startup YouTube URL & Autoplay (${yt_badge})"
        echo -e "  ${BOLD}${CYAN}21)${NC} Configure Live Weather Banner & Location (${BOLD}${WEATHER_LOCATION:-Swansea, UK}${NC})"
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [0-21]: " set_choice

        case "$set_choice" in
            1)
                DEFAULT_AUDIO_PLAYER="audacious"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "audacious"
                echo -e "\n${GREEN}✓ Default audio player set to 'audacious' and saved to config.env!${NC}"
                sleep 1
                ;;
            2)
                DEFAULT_AUDIO_PLAYER="cliamp"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "cliamp"
                echo -e "\n${GREEN}✓ Default audio player set to 'cliamp' and saved to config.env!${NC}"
                sleep 1
                ;;
            3)
                DEFAULT_AUDIO_PLAYER="strawberry"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "strawberry"
                echo -e "\n${GREEN}✓ Default audio player set to 'strawberry' and saved to config.env!${NC}"
                sleep 1
                ;;
            4)
                DEFAULT_AUDIO_PLAYER="vlc"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "vlc"
                echo -e "\n${GREEN}✓ Default audio player set to 'vlc' and saved to config.env!${NC}"
                sleep 1
                ;;
            5)
                DEFAULT_AUDIO_PLAYER="haruna"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "haruna"
                echo -e "\n${GREEN}✓ Default audio player set to 'haruna' and saved to config.env!${NC}"
                sleep 1
                ;;
            6)
                DEFAULT_AUDIO_PLAYER="kodi"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "kodi"
                echo -e "\n${GREEN}✓ Default audio player set to 'kodi' and saved to config.env!${NC}"
                sleep 1
                ;;
            7)
                DEFAULT_AUDIO_PLAYER="foobar2000"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "foobar2000"
                echo -e "\n${GREEN}✓ Default audio player set to 'foobar2000' and saved to config.env!${NC}"
                sleep 1
                ;;
            8)
                DEFAULT_AUDIO_PLAYER="winamp"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "winamp"
                echo -e "\n${GREEN}✓ Default audio player set to 'winamp' and saved to config.env!${NC}"
                sleep 1
                ;;
            9)
                DEFAULT_AUDIO_PLAYER="music"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "music"
                echo -e "\n${GREEN}✓ Default audio player set to 'music' (Apple Music) and saved to config.env!${NC}"
                sleep 1
                ;;
            10)
                DEFAULT_AUDIO_PLAYER="audacity"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "audacity"
                echo -e "\n${GREEN}✓ Default audio player set to 'audacity' and saved to config.env!${NC}"
                sleep 1
                ;;
            11)
                DEFAULT_AUDIO_PLAYER="mpv"
                save_config_setting "DEFAULT_AUDIO_PLAYER" "mpv"
                echo -e "\n${GREEN}✓ Default audio player set to 'mpv' and saved to config.env!${NC}"
                sleep 1
                ;;
            12)
                read -r -p "Enter custom audio player executable command: " cust_p
                if [ -n "$cust_p" ]; then
                    DEFAULT_AUDIO_PLAYER="$cust_p"
                    save_config_setting "DEFAULT_AUDIO_PLAYER" "$cust_p"
                    echo -e "\n${GREEN}✓ Default audio player set to '${cust_p}' and saved to config.env!${NC}"
                    sleep 1.2
                fi
                ;;
            13)
                if [ "${AUTO_PLAY_ON_STARTUP:-true}" = "true" ]; then
                    AUTO_PLAY_ON_STARTUP="false"
                else
                    AUTO_PLAY_ON_STARTUP="true"
                fi
                save_config_setting "AUTO_PLAY_ON_STARTUP" "$AUTO_PLAY_ON_STARTUP"
                echo -e "\n${GREEN}✓ Startup autoplay toggled to: ${AUTO_PLAY_ON_STARTUP}!${NC}"
                sleep 1
                ;;
            14)
                if [ "${AUTO_SHOW_COVER_ON_STARTUP:-false}" = "true" ]; then
                    AUTO_SHOW_COVER_ON_STARTUP="false"
                else
                    AUTO_SHOW_COVER_ON_STARTUP="true"
                fi
                save_config_setting "AUTO_SHOW_COVER_ON_STARTUP" "$AUTO_SHOW_COVER_ON_STARTUP"
                echo -e "\n${GREEN}✓ Auto-show cover art toggled to: ${AUTO_SHOW_COVER_ON_STARTUP}!${NC}"
                sleep 1
                ;;
            15)
                if [ "${AUTO_SHOW_TRACKLIST_ON_STARTUP:-true}" = "true" ]; then
                    AUTO_SHOW_TRACKLIST_ON_STARTUP="false"
                else
                    AUTO_SHOW_TRACKLIST_ON_STARTUP="true"
                fi
                save_config_setting "AUTO_SHOW_TRACKLIST_ON_STARTUP" "$AUTO_SHOW_TRACKLIST_ON_STARTUP"
                echo -e "\n${GREEN}✓ Auto-show tracklist toggled to: ${AUTO_SHOW_TRACKLIST_ON_STARTUP}!${NC}"
                sleep 1
                ;;
            16)
                if [ "${AUTO_PLAY_MIX_SELECTION:-latest}" = "latest" ]; then
                    AUTO_PLAY_MIX_SELECTION="random"
                else
                    AUTO_PLAY_MIX_SELECTION="latest"
                fi
                save_config_setting "AUTO_PLAY_MIX_SELECTION" "$AUTO_PLAY_MIX_SELECTION"
                echo -e "\n${GREEN}✓ Startup mix selection toggled to: ${AUTO_PLAY_MIX_SELECTION}!${NC}"
                sleep 1
                ;;
            17)
                echo -e "\n${BOLD}${YELLOW}Testing startup playback right now with player: ${DEFAULT_AUDIO_PLAYER}...${NC}\n"
                execute_startup_autoplay
                press_enter
                ;;
            18)
                clear
                echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
                echo -e "${BOLD}${MAGENTA}             CONFIGURE DEDICATED TRACKLIST WINDOW VIEWER              ${NC}"
                echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
                echo -e "  Current Viewer: ${BOLD}${GREEN}${TRACKLIST_VIEWER:-console}${NC}\n"
                echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}console${NC} (Default OS Console • Entirely Borderless Window on Bazzite Linux)"
                echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}auto${NC} (External GUI Editor: KWrite/Kate on KDE, TextEdit on macOS, Notepad on Windows)"
                echo -e "  ${BOLD}${CYAN} 3)${NC} ${BOLD}kwrite${NC} (KDE Lightweight Dedicated Editor Window)"
                echo -e "  ${BOLD}${CYAN} 4)${NC} ${BOLD}kate${NC} (KDE Advanced Text Editor - New Window)"
                echo -e "  ${BOLD}${CYAN} 5)${NC} ${BOLD}gedit${NC} (GNOME Text Editor - New Window)"
                echo -e "  ${BOLD}${CYAN} 6)${NC} ${BOLD}mousepad${NC} (XFCE Lightweight Text Editor)"
                echo -e "  ${BOLD}${CYAN} 7)${NC} ${BOLD}konsole${NC} (Standard Konsole Window with less viewer)"
                echo -e "  ${BOLD}${CYAN} 8)${NC} ${BOLD}xdg-open${NC} (Desktop Environment Default MIME Handler)"
                echo -e "  ${BOLD}${CYAN} 9)${NC} Custom Text Viewer / Editor Executable Command"
                echo -e "  ${BOLD}${CYAN} 0)${NC} Cancel\n"
                read -r -p "Enter choice [0-9]: " tv_choice
                case "$tv_choice" in
                    1) TRACKLIST_VIEWER="console" ;;
                    2) TRACKLIST_VIEWER="auto" ;;
                    3) TRACKLIST_VIEWER="kwrite" ;;
                    4) TRACKLIST_VIEWER="kate" ;;
                    5) TRACKLIST_VIEWER="gedit" ;;
                    6) TRACKLIST_VIEWER="mousepad" ;;
                    7) TRACKLIST_VIEWER="konsole" ;;
                    8) TRACKLIST_VIEWER="xdg-open" ;;
                    9)
                        read -r -p "Enter custom text viewer command: " cust_tv
                        [ -n "$cust_tv" ] && TRACKLIST_VIEWER="$cust_tv"
                        ;;
                    *) ;;
                esac
                save_config_setting "TRACKLIST_VIEWER" "$TRACKLIST_VIEWER"
                echo -e "\n${GREEN}✓ Tracklist window viewer set to '${TRACKLIST_VIEWER}' and saved to config.env!${NC}"
                sleep 1.2
                ;;
            18)
                clear
                echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
                echo -e "${BOLD}${MAGENTA}                CONFIGURE DEFAULT VIDEO PLAYER                        ${NC}"
                echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
                echo -e "  Current Video Player: ${BOLD}${GREEN}${DEFAULT_VIDEO_PLAYER:-vlc}${NC}\n"
                echo -e "  ${BOLD}${CYAN} 1)${NC} ${BOLD}vlc${NC} (VLC Media Player • Recommended)"
                echo -e "  ${BOLD}${CYAN} 2)${NC} ${BOLD}mpv${NC} (High-performance minimalist player)"
                echo -e "  ${BOLD}${CYAN} 3)${NC} ${BOLD}haruna${NC} (KDE Qt/QML Video Player)"
                echo -e "  ${BOLD}${CYAN} 4)${NC} ${BOLD}kodi${NC} (Kodi Media Center)"
                echo -e "  ${BOLD}${CYAN} 5)${NC} Custom video player command / executable"
                echo -e "  ${BOLD}${CYAN} 0)${NC} Cancel\n"
                read -r -p "Enter choice [0-5]: " vp_choice
                case "$vp_choice" in
                    1) DEFAULT_VIDEO_PLAYER="vlc" ;;
                    2) DEFAULT_VIDEO_PLAYER="mpv" ;;
                    3) DEFAULT_VIDEO_PLAYER="haruna" ;;
                    4) DEFAULT_VIDEO_PLAYER="kodi" ;;
                    5)
                        read -r -p "Enter custom video player command: " cust_vp
                        [ -n "$cust_vp" ] && DEFAULT_VIDEO_PLAYER="$cust_vp"
                        ;;
                    *) ;;
                esac
                save_config_setting "DEFAULT_VIDEO_PLAYER" "$DEFAULT_VIDEO_PLAYER"
                echo -e "\n${GREEN}✓ Default video player set to '${DEFAULT_VIDEO_PLAYER}' and saved to config.env!${NC}"
                sleep 1.2
                ;;
            19)
                clear
                echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
                echo -e "${BOLD}${MAGENTA}        CONFIGURE STARTUP CUSTOM YOUTUBE VIDEO AUTOPLAY               ${NC}"
                echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
                local cur_yt="${RED}DISABLED${NC}"
                [ "${AUTO_PLAY_YOUTUBE_ON_STARTUP:-false}" = "true" ] && cur_yt="${GREEN}ENABLED${NC}"
                echo -e "  • Startup YouTube Autoplay: ${cur_yt}"
                echo -e "  • Note: Autoplays ONLY if a mix is playing already in a music player!\n"
                echo -e "  Current YouTube URL: ${CYAN}${STARTUP_YOUTUBE_URL:-None}${NC}\n"
                echo -e "  ${BOLD}${CYAN} 1)${NC} Toggle Autoplay on/off"
                echo -e "  ${BOLD}${CYAN} 2)${NC} Set / Change Custom YouTube Video URL"
                echo -e "  ${BOLD}${CYAN} 3)${NC} Clear YouTube URL & Disable Autoplay"
                echo -e "  ${BOLD}${CYAN} 0)${NC} Cancel\n"
                read -r -p "Enter choice [0-3]: " yt_choice
                case "$yt_choice" in
                    1)
                        if [ "${AUTO_PLAY_YOUTUBE_ON_STARTUP:-false}" = "true" ]; then
                            AUTO_PLAY_YOUTUBE_ON_STARTUP="false"
                        else
                            AUTO_PLAY_YOUTUBE_ON_STARTUP="true"
                        fi
                        save_config_setting "AUTO_PLAY_YOUTUBE_ON_STARTUP" "$AUTO_PLAY_YOUTUBE_ON_STARTUP"
                        echo -e "\n${GREEN}✓ Startup YouTube autoplay set to: ${AUTO_PLAY_YOUTUBE_ON_STARTUP}!${NC}"
                        sleep 1
                        ;;
                    2)
                        echo ""
                        read -r -p "Enter YouTube video URL (e.g. https://www.youtube.com/watch?v=...): " new_yt
                        if [ -n "$new_yt" ]; then
                            STARTUP_YOUTUBE_URL="$new_yt"
                            AUTO_PLAY_YOUTUBE_ON_STARTUP="true"
                            save_config_setting "STARTUP_YOUTUBE_URL" "$STARTUP_YOUTUBE_URL"
                            save_config_setting "AUTO_PLAY_YOUTUBE_ON_STARTUP" "true"
                            echo -e "\n${GREEN}✓ Startup YouTube URL updated and enabled!${NC}"
                            sleep 1.2
                        fi
                        ;;
                    3)
                        STARTUP_YOUTUBE_URL=""
                        AUTO_PLAY_YOUTUBE_ON_STARTUP="false"
                        save_config_setting "STARTUP_YOUTUBE_URL" ""
                        save_config_setting "AUTO_PLAY_YOUTUBE_ON_STARTUP" "false"
                        echo -e "\n${YELLOW}✓ Startup YouTube URL cleared and disabled.${NC}"
                        sleep 1.2
                        ;;
                    *) ;;
                esac
                ;;
            20)
                manage_weather_menu
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

manage_audio_players() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             AUDIO PLAYERS & PLAYBACK SUITE         ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        local current_datetime
        current_datetime=$(date "+%A, %B %d, %Y  •  %T %Z")
        echo -e "       ${BOLD}${CYAN}📅 ${current_datetime}${NC}"
        echo ""

        if get_audacious_track_info 2>/dev/null; then
            local st_badge
            case "$AUDACIOUS_STATE" in
                playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
                paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
                stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
                *)       st_badge="${BOLD}${CYAN}${AUDACIOUS_STATE^^}${NC}" ;;
            esac
            echo -e "  Audacious Player:  ${st_badge} [${AUDACIOUS_POS_FMT} / ${AUDACIOUS_DUR_FMT}] (${AUDACIOUS_PROGRESS_PCT}%)"
            echo -e "  Current Track:     ${BOLD}${YELLOW}${AUDACIOUS_TITLE}${NC}${AUDACIOUS_ARTIST:+ - $AUDACIOUS_ARTIST}"
            [ -n "$AUDACIOUS_RESOLVED_PATH" ] && echo -e "  Active File Path:  ${BOLD}${CYAN}${AUDACIOUS_RESOLVED_PATH}${NC}"
            echo -e "  --------------------------------------------------"
        elif get_cliamp_track_info 2>/dev/null; then
            local st_badge
            case "$CLIAMP_STATE" in
                playing) st_badge="${BOLD}${GREEN}▶ PLAYING${NC}" ;;
                paused)  st_badge="${BOLD}${YELLOW}⏸ PAUSED${NC}" ;;
                stopped) st_badge="${BOLD}${RED}⏹ STOPPED${NC}" ;;
                *)       st_badge="${BOLD}${CYAN}${CLIAMP_STATE}${NC}" ;;
            esac
            echo -e "  cliamp Player:     ${st_badge} [${CLIAMP_POS_FMT} / ${CLIAMP_DUR_FMT}] (${CLIAMP_PROGRESS_PCT}%)"
            echo -e "  Current Track:     ${BOLD}${YELLOW}${CLIAMP_TITLE}${NC} - ${CLIAMP_ARTIST}"
            echo -e "  Active File Path:  ${BOLD}${CYAN}${CLIAMP_RESOLVED_PATH}${NC}"
            echo -e "  --------------------------------------------------"
        fi

        local fb_badge="${YELLOW}[macOS & Windows]${NC}"
        local wa_badge="${YELLOW}[Windows Only]${NC}"
        local am_badge="${YELLOW}[macOS Only]${NC}"
        local ap_badge="${YELLOW}[macOS Only]${NC}"
        if [ "$OS_TYPE" = "macos" ]; then
            [ -d "/Applications/foobar2000.app" ] && fb_badge="${GREEN}✓ INSTALLED${NC}"
            am_badge="${GREEN}✓ macOS APP${NC}"
            ap_badge="${GREEN}✓ macOS APP${NC}"
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            ([ -f "/c/Program Files/foobar2000/foobar2000.exe" ] || command -v foobar2000.exe >/dev/null 2>&1) && fb_badge="${GREEN}✓ INSTALLED${NC}"
            ([ -f "/c/Program Files (x86)/Winamp/winamp.exe" ] || [ -f "/c/Program Files/Winamp/winamp.exe" ] || command -v winamp.exe >/dev/null 2>&1) && wa_badge="${GREEN}✓ INSTALLED${NC}"
        fi

        echo -e "${BOLD}Select an Audio Player to launch / manage:${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Launch Audacious Audio Player (New Window) (${GREEN}audacious / org.atheme.audacious${NC})"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Cliamp Music Player & Current Track Info (${GREEN}Now Playing Path, Controls & Launch${NC})"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Launch VLC Media Player (${GREEN}vlc / org.videolan.VLC${NC})"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Launch Haruna Media Player (${GREEN}org.kde.haruna${NC})"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Launch Kodi Entertainment Center (${GREEN}tv.kodi.Kodi${NC})"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Launch Strawberry Music Player (Legacy) (${GREEN}strawberry${NC})"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Launch foobar2000 Player (${fb_badge})"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Launch Winamp Player (${wa_badge})"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Launch Apple Music Player (${am_badge})"
        echo -e "  ${BOLD}${CYAN}10)${NC} Launch Apple Podcasts App (${ap_badge})"
        echo -e "  ${BOLD}${CYAN}11)${NC} Launch Audacity Audio Editor (${GREEN}audacity${NC})"
        echo -e "  ${BOLD}${CYAN}12)${NC} Show Connected USB MIDI Devices (${GREEN}list-midi-devices${NC})"
        echo -e "  ${BOLD}${CYAN}13)${NC} Configure Default Audio Player & Startup Autoplay (${GREEN}Current: ${DEFAULT_AUDIO_PLAYER:-audacious}${NC})"
        echo -e "  ${BOLD}${CYAN}14)${NC} View Playing Mix Audio Specifications & Stream Metadata (${GREEN}Bit Depth, Sample Rate, Codec, Title${NC})"
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-14]: " p_choice

        case "$p_choice" in
            1)
                launch_audacious
                ;;
            2)
                manage_cliamp
                ;;
            3)
                launch_vlc
                ;;
            4)
                launch_haruna
                ;;
            5)
                launch_kodi
                ;;
            6)
                launch_strawberry
                ;;
            7)
                launch_foobar2000
                ;;
            8)
                launch_winamp
                ;;
            9)
                launch_apple_music
                ;;
            10)
                launch_apple_podcasts
                ;;
            11)
                launch_audacity
                ;;
            12)
                list_usb_midi_devices
                ;;
            13)
                configure_audio_player_and_startup
                ;;
            14)
                inspect_playing_audio_file
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.5
                ;;
        esac
    done
}

manage_visual_media_launchers() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}         VISUAL, VIDEO & ART LAUNCHERS SUITE        ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo ""
        echo -e "${BOLD}Select a visual or media application to launch:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Launch Video Playlists (${GREEN}NFT Videos in VLC${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Launch Specific Video in Default Video Player (${GREEN}${DEFAULT_VIDEO_PLAYER:-vlc}${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Launch GIMP Image Editor (${GREEN}gimp / org.gimp.GIMP${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Launch Electric Sheep Generative Screensaver (${GREEN}electricsheep / infinidream${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} Launch GeeXLab Demo Launcher (${GREEN}FurMark_linux64/demo_launcher.sh${NC})"
        echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-5]: " vml_choice
        case "$vml_choice" in
            1)
                launch_video_playlists
                ;;
            2)
                manage_video_dispatcher
                ;;
            3)
                launch_gimp
                ;;
            4)
                launch_electricsheep
                ;;
            5)
                launch_geexlab_demos
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_live_monitors() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}         LIVE SESSION & STREAM MONITORS SUITE       ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo ""
        echo -e "${BOLD}Select a live monitor to launch:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Launch Live Tracklist Monitor (${GREEN}SOF_Live_Tracker.sh${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Launch Traktor Live Monitor & Audio Recorder (${GREEN}New Window - CPU, Tracks, Audio I/O${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Launch Live File Transfer Monitor (${GREEN}transfer-monitor${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Launch Chrome Upload Monitor (${GREEN}Podcast Connect / Web Uploads${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} View Running Background Tasks (${GREEN}Track and inspect background jobs${NC})"
        echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-5]: " lm_choice
        case "$lm_choice" in
            1)
                echo -e "\n${BOLD}${YELLOW}Launching Live Tracklist Monitor (Press Ctrl+C to return)...${NC}\n"
                sleep 0.8
                trap ':' INT
                run_sub_script "SOF_Live_Tracker.sh"
                trap 'exit_mix_manager' INT
                press_enter
                ;;
            2)
                launch_traktor_monitor_window
                ;;
            3)
                echo -e "\n${BOLD}${YELLOW}Launching Live File Transfer Monitor (Press Ctrl+C to return)...${NC}\n"
                sleep 0.8
                trap ':' INT
                if command -v transfer-monitor >/dev/null 2>&1; then
                    transfer-monitor
                elif [ -x "$HOME/.local/bin/transfer-monitor" ]; then
                    "$HOME/.local/bin/transfer-monitor"
                else
                    echo -e "${RED}Error: transfer-monitor command not found in PATH or ~/.local/bin!${NC}"
                fi
                trap 'exit_mix_manager' INT
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${YELLOW}Launching Chrome Upload Monitor (Press Ctrl+C to return)...${NC}\n"
                sleep 0.8
                trap ':' INT
                if command -v chrome-upload-monitor >/dev/null 2>&1; then
                    chrome-upload-monitor
                elif [ -x "$HOME/.local/bin/chrome-upload-monitor" ]; then
                    "$HOME/.local/bin/chrome-upload-monitor"
                elif [ -x "./chrome_upload_monitor.py" ]; then
                    python3 ./chrome_upload_monitor.py
                elif [ -x "$SCRIPT_DIR/chrome_upload_monitor.py" ]; then
                    python3 "$SCRIPT_DIR/chrome_upload_monitor.py"
                elif [ -x "./Monitor_Chrome_Uploads.sh" ]; then
                    ./Monitor_Chrome_Uploads.sh
                elif [ -x "$SCRIPT_DIR/Monitor_Chrome_Uploads.sh" ]; then
                    "$SCRIPT_DIR/Monitor_Chrome_Uploads.sh"
                else
                    echo -e "${RED}Error: chrome-upload-monitor command not found in PATH or ~/.local/bin!${NC}"
                fi
                trap 'exit_mix_manager' INT
                press_enter
                ;;
            5)
                view_tasks
                press_enter
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_system_process_monitors() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo -e "${BOLD}${MAGENTA}        SYSTEM & HARDWARE PROCESS MONITORS          ${NC}"
        echo -e "${BOLD}${MAGENTA}====================================================${NC}"
        echo ""
        echo -e "${BOLD}Select a process / resource monitor to launch:${NC}"
        echo -e "  ${BOLD}${CYAN}1)${NC} Launch Resource Monitor (${GREEN}btop${NC}) [CPU, RAM, Disks, Network]"
        echo -e "  ${BOLD}${CYAN}2)${NC} Launch GPU Process Monitor (${GREEN}nvtop${NC}) [NVIDIA / AMD / Intel GPU VRAM & Cores]"
        echo -e "  ${BOLD}${CYAN}3)${NC} Launch System Process Monitor (${GREEN}top${NC}) [Standard UNIX Process Table]"
        echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-3]: " spm_choice
        case "$spm_choice" in
            1)
                echo -e "\n${BOLD}${YELLOW}Launching btop Resource Monitor (Press 'q' to exit)...${NC}\n"
                sleep 0.5
                trap ':' INT
                if command -v btop >/dev/null 2>&1; then
                    btop
                else
                    echo -e "${RED}Error: btop command not found in PATH!${NC}"
                    press_enter
                fi
                trap 'exit_mix_manager' INT
                ;;
            2)
                echo -e "\n${BOLD}${YELLOW}Launching nvtop GPU Monitor (Press 'q' to exit)...${NC}\n"
                sleep 0.5
                trap ':' INT
                if command -v nvtop >/dev/null 2>&1; then
                    nvtop
                else
                    echo -e "${RED}Error: nvtop command not found in PATH!${NC}"
                    press_enter
                fi
                trap 'exit_mix_manager' INT
                ;;
            3)
                echo -e "\n${BOLD}${YELLOW}Launching top Process Monitor (Press 'q' to exit)...${NC}\n"
                sleep 0.5
                trap ':' INT
                if command -v top >/dev/null 2>&1; then
                    top
                else
                    echo -e "${RED}Error: top command not found in PATH!${NC}"
                    press_enter
                fi
                trap 'exit_mix_manager' INT
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1
                ;;
        esac
    done
}

run_bash_cli() {
    echo -e "\n${BOLD}${MAGENTA}====================================================${NC}"
    echo -e "${BOLD}${MAGENTA}             Interactive Bash CLI Runner            ${NC}"
    echo -e "${BOLD}${MAGENTA}====================================================${NC}"
    echo -e "${CYAN}Choose an option:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Open an interactive Bash shell session ${DIM}(type 'exit' to return to Manager)${NC}"
    echo -e "  ${BOLD}${CYAN}2)${NC} Execute a single Bash command and return"
    echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
    echo ""
    read -r -p "Enter choice [0-2]: " cli_choice
    case "$cli_choice" in
        1)
            echo -e "\n${BOLD}${GREEN}Spawning interactive Bash subshell. Type 'exit' to return.${NC}\n"
            export PS1="\[\033[01;32m\][MixManager-CLI] \[\033[01;34m\]\w\[\033[00m\]\$ "
            bash --norc -i 2>/dev/null || bash -i
            echo -e "\n${GREEN}Returned from Bash subshell.${NC}"
            sleep 1
            ;;
        2)
            echo ""
            read -r -p "Enter Bash command to execute: " user_cmd
            if [ -n "$user_cmd" ]; then
                echo -e "\n${BOLD}${YELLOW}Executing:${NC} $user_cmd\n"
                eval "$user_cmd"
                echo ""
                press_enter
            fi
            ;;
        0|[qQ])
            return 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice!${NC}"
            sleep 1.2
            ;;
    esac
}

manage_themes() {
    while true; do
        local opts=(
            "1|MPlanetarian Dreamworlds [Default]|[Sweet Hot Pink, Electric Cyan, Lavender & Violet] $([ "$CURRENT_THEME" = "dreamworlds" ] && echo -e "${GREEN}★ ACTIVE (DEFAULT)${NC}")"
            "2|Cyberpunk|[Neon Hot Pink, Electric Cyan & High-Volt Yellow] $([ "$CURRENT_THEME" = "cyberpunk" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "3|Dracula|[Vampiric Purple, Neon Green & Coral Pink] $([ "$CURRENT_THEME" = "dracula" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "4|Nord|[Arctic Slate, Frost Polar Ice & Sage Aurora] $([ "$CURRENT_THEME" = "nord" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "5|The Matrix|[Pure Phosphor Green, Terminal Crimson & Mint] $([ "$CURRENT_THEME" = "matrix" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "6|Solarized|[Warm Amber, Solar Yellow, Cyan & Terracotta] $([ "$CURRENT_THEME" = "solarized" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "7|Tokyo Night|[Deep Violet, Lavender, Soft Blue & Coral] $([ "$CURRENT_THEME" = "tokyo" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "8|Monokai|[Electric Pink, Tangerine, Lime & Vivid Blue] $([ "$CURRENT_THEME" = "monokai" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "9|Gruvbox|[Retro Warm Earth, Dusty Rose, Rust & Gold] $([ "$CURRENT_THEME" = "gruvbox" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "10|Emerald Isle|[Deep Ocean, Spring Emerald & Mint Cyan] $([ "$CURRENT_THEME" = "emerald" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "11|Classic ANSI|[Standard 16-Color Terminal Fallback] $([ "$CURRENT_THEME" = "classic" ] && echo -e "${GREEN}★ ACTIVE${NC}")"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "Themes & Color Palette Switcher" "  Current Active Theme: ${BOLD}${YELLOW}${CURRENT_THEME}${NC}\n" opts 0
        local tchoice="$REPLY"
        case "$tchoice" in
            1|dreamworlds|default)
                save_theme "dreamworlds"
                echo -e "\n${BOLD}${GREEN}✓ Theme switched to MPlanetarian Dreamworlds [Default]!${NC}"
                show_dreamworlds_ascii_banner true
                sleep 0.8
                ;;
            2|cyberpunk)
                save_theme "cyberpunk"
                echo -e "\n${GREEN}✓ Theme switched to Cyberpunk!${NC}"
                sleep 0.8
                ;;
            3|dracula)
                save_theme "dracula"
                echo -e "\n${GREEN}✓ Theme switched to Dracula!${NC}"
                sleep 0.8
                ;;
            4|nord)
                save_theme "nord"
                echo -e "\n${GREEN}✓ Theme switched to Nord!${NC}"
                sleep 0.8
                ;;
            5|matrix)
                save_theme "matrix"
                echo -e "\n${GREEN}✓ Theme switched to The Matrix!${NC}"
                sleep 0.8
                ;;
            6|solarized)
                save_theme "solarized"
                echo -e "\n${GREEN}✓ Theme switched to Solarized!${NC}"
                sleep 0.8
                ;;
            7|tokyo)
                save_theme "tokyo"
                echo -e "\n${GREEN}✓ Theme switched to Tokyo Night!${NC}"
                sleep 0.8
                ;;
            8|monokai)
                save_theme "monokai"
                echo -e "\n${GREEN}✓ Theme switched to Monokai!${NC}"
                sleep 0.8
                ;;
            9|gruvbox)
                save_theme "gruvbox"
                echo -e "\n${GREEN}✓ Theme switched to Gruvbox!${NC}"
                sleep 0.8
                ;;
            10|emerald)
                save_theme "emerald"
                echo -e "\n${GREEN}✓ Theme switched to Emerald Isle!${NC}"
                sleep 0.8
                ;;
            11|classic)
                save_theme "classic"
                echo -e "\n${GREEN}✓ Theme switched to Classic ANSI!${NC}"
                sleep 0.8
                ;;
            0|[bB]|[qQ]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

# ==============================================================================
# ADVANCED SYSTEM, AUDIO, TRACKLIST & ARCHIVE UTILITIES (OPTIONS 1-14, 32)
# ==============================================================================

get_system_perf_stats() {
    local cpu_info="" ram_info="" disk_info=""
    
    # 1. CPU / Load Info
    if [ -f /proc/loadavg ]; then
        read -r l1 l5 l15 _ < /proc/loadavg
        cpu_info="${l1} (1m), ${l5} (5m)"
    elif [ "$OS_TYPE" = "macos" ] || [ "$OS_TYPE" = "freebsd" ]; then
        local load
        load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2, $3}')
        [ -n "$load" ] && cpu_info="${load}" || cpu_info="Active"
    else
        cpu_info="Active"
    fi

    # 2. RAM Info
    if [ -f /proc/meminfo ]; then
        local mem_total mem_avail mem_used mem_total_g mem_used_g mem_pct
        mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
        mem_avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
        if [ -n "$mem_total" ] && [ -n "$mem_avail" ] && [ "$mem_total" -gt 0 ]; then
            mem_used=$((mem_total - mem_avail))
            mem_total_g=$(awk "BEGIN {printf \"%.1f\", $mem_total/1048576}")
            mem_used_g=$(awk "BEGIN {printf \"%.1f\", $mem_used/1048576}")
            mem_pct=$(( (mem_used * 100) / mem_total ))
            ram_info="${mem_used_g}G/${mem_total_g}G (${mem_pct}%)"
        fi
    elif [ "$OS_TYPE" = "freebsd" ]; then
        local mem_bytes page_size free_pages mem_total_g mem_used_g mem_pct
        mem_bytes=$(sysctl -n hw.physmem 2>/dev/null)
        page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
        free_pages=$(sysctl -n vm.stats.vm.v_free_count 2>/dev/null || echo 0)
        if [ -n "$mem_bytes" ] && [ "$mem_bytes" -gt 0 ]; then
            local free_bytes=$(( free_pages * page_size ))
            local used_bytes=$(( mem_bytes - free_bytes ))
            mem_total_g=$(awk "BEGIN {printf \"%.1f\", $mem_bytes/1073741824}")
            mem_used_g=$(awk "BEGIN {printf \"%.1f\", $used_bytes/1073741824}")
            mem_pct=$(( (used_bytes * 100) / mem_bytes ))
            ram_info="${mem_used_g}G/${mem_total_g}G (${mem_pct}%)"
        fi
    fi
    [ -z "$ram_info" ] && ram_info="Available"

    # 3. Disk Info (Mix Drive Only)
    local mix_target="${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}"
    local d_avail="" d_pct=""
    read -r _ _ _ d_avail d_pct _ < <(df -h "$mix_target" 2>/dev/null | tail -n 1)
    if [ -n "$d_avail" ]; then
        disk_info="${d_avail} free (${d_pct} used)"
    else
        disk_info="Mounted"
    fi

    echo -e "  ${BOLD}${CYAN}⚡ CPU Load:${NC} ${cpu_info}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🧠 RAM:${NC} ${ram_info}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}💾 Mix Drive Free:${NC} ${disk_info}"
}

get_active_audio_interface_display() {
    local script_py="$SCRIPT_DIR/scripts/get_audio_interface.py"
    [ ! -f "$script_py" ] && script_py="$PWD/scripts/get_audio_interface.py"
    if [ -f "$script_py" ]; then
        local raw
        raw=$(python3 "$script_py" 2>/dev/null)
        if [ -n "$raw" ]; then
            local iface latency sys_mode
            IFS='|' read -r iface latency sys_mode <<< "$raw"
            if [ -n "$iface" ]; then
                echo -e "  ${BOLD}${CYAN}🎧 Audio Interface:${NC} ${WHITE}${iface}${NC}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}⚡ Latency:${NC} ${GREEN}${latency:-Active}${NC}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🎛️ Engine:${NC} ${sys_mode:-Audio}"
                return 0
            fi
        fi
    fi
    return 1
}

get_alarm_clock_status_display() {
    local script_py="$SCRIPT_DIR/scripts/get_alarm_clock_status.py"
    [ ! -f "$script_py" ] && script_py="$PWD/scripts/get_alarm_clock_status.py"
    if [ -f "$script_py" ] && command -v python3 >/dev/null 2>&1; then
        python3 "$script_py" 2>/dev/null
    elif [ -x "$SCRIPT_DIR/scripts/get_alarm_clock_status.sh" ]; then
        "$SCRIPT_DIR/scripts/get_alarm_clock_status.sh" 2>/dev/null
    fi
}

get_playing_audio_spec_summary() {
    local target_file="$1"
    local script_py="$SCRIPT_DIR/scripts/inspect_playing_audio.py"
    [ ! -f "$script_py" ] && script_py="$PWD/scripts/inspect_playing_audio.py"
    if [ -f "$script_py" ]; then
        if [ -n "$target_file" ] && [ -f "$target_file" ]; then
            python3 "$script_py" "$target_file" --summary 2>/dev/null
        else
            python3 "$script_py" --summary 2>/dev/null
        fi
    fi
}

inspect_playing_audio_file() {
    local target="$1"
    local script_sh="$SCRIPT_DIR/scripts/inspect_playing_audio.sh"
    [ ! -f "$script_sh" ] && script_sh="$PWD/scripts/inspect_playing_audio.sh"
    if [ -x "$script_sh" ]; then
        if [ -n "$target" ]; then
            "$script_sh" "$target"
        else
            "$script_sh"
        fi
    else
        local script_py="$SCRIPT_DIR/scripts/inspect_playing_audio.py"
        [ ! -f "$script_py" ] && script_py="$PWD/scripts/inspect_playing_audio.py"
        if [ -f "$script_py" ]; then
            if [ -n "$target" ]; then
                python3 "$script_py" "$target"
            else
                python3 "$script_py"
            fi
        else
            echo -e "\n${RED}Error: inspect_playing_audio script not found in scripts/!${NC}"
            sleep 1.5
        fi
    fi
}

launch_traktor_monitor_window() {
    local mon_sh=""
    if [ -x "$SCRIPT_DIR/scripts/traktor_monitor.sh" ]; then
        mon_sh="$SCRIPT_DIR/scripts/traktor_monitor.sh"
    elif [ -x "$SCRIPT_DIR/traktor_monitor.sh" ]; then
        mon_sh="$SCRIPT_DIR/traktor_monitor.sh"
    elif [ -x "$HOME/.local/bin/traktor-monitor" ]; then
        mon_sh="$HOME/.local/bin/traktor-monitor"
    elif command -v traktor-monitor >/dev/null 2>&1; then
        mon_sh="$(command -v traktor-monitor)"
    elif [ -f "$SCRIPT_DIR/scripts/traktor_monitor.py" ]; then
        mon_sh="$SCRIPT_DIR/scripts/traktor_monitor.py"
    elif [ -f "$PWD/scripts/traktor_monitor.py" ]; then
        mon_sh="$PWD/scripts/traktor_monitor.py"
    fi

    if [ -z "$mon_sh" ]; then
        echo -e "\n${RED}Error: traktor_monitor.sh / traktor-monitor was not found in scripts/ or PATH!${NC}"
        press_enter
        return 1
    fi

    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}       🎛️  TRAKTOR PRO LIVE MONITOR & AUDIO RECORDER CONTROL  🎛️               ${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "  • ${BOLD}Process Metrics:${NC}   Traktor CPU %, RSS RAM, Thread Count & Execution State"
    echo -e "  • ${BOLD}Deck Tracking:${NC}     Active open audio files & deck playback detection"
    echo -e "  • ${BOLD}Audio Recorder:${NC}    Live WAV write detection, file-growth tracking & standby"
    echo -e "  • ${BOLD}Hardware & I/O:${NC}    Traktor audio device, sample rate, latency & buffer size"
    echo -e "  • ${BOLD}Hotkeys in Live:${NC}   [s] Start Rec  │  [x] Stop Rec  │  [t] Toggle Rec  │  [q] Quit"
    echo -e "  • ${BOLD}Cross-Platform:${NC}    macOS (AppleScript UI), Windows 10 & 11, Linux (Bazzite/Fedora)"
    echo -e "${BOLD}${CYAN}───────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "Select launch target:"
    echo -e "  ${BOLD}${CYAN}1)${NC} Launch Live Monitor in ${BOLD}${GREEN}New Terminal Window${NC} (Recommended)"
    echo -e "  ${BOLD}${CYAN}2)${NC} Run Live Monitor in Current Terminal Window"
    echo -e "  ${BOLD}${CYAN}3)${NC} Single Diagnostic Status Snapshot (--once)"
    echo -e "  ${BOLD}${CYAN}4)${NC} Trigger Traktor Audio Recording: ${GREEN}START RECORDING${NC}"
    echo -e "  ${BOLD}${CYAN}5)${NC} Trigger Traktor Audio Recording: ${RED}STOP RECORDING${NC}"
    echo -e "  ${BOLD}${CYAN}6)${NC} Trigger Traktor Audio Recording: ${YELLOW}TOGGLE RECORDING${NC}"
    echo -e "  ${BOLD}${CYAN}0)${NC} Return to Main Menu"
    echo ""
    read -r -p "Enter choice [1-6, default: 1]: " tm_choice
    tm_choice="${tm_choice:-1}"

    case "$tm_choice" in
        1)
            if ! pgrep -i -f "Traktor.app/Contents/MacOS/Traktor$" >/dev/null 2>&1 && ! pgrep -i -f "Traktor\.exe" >/dev/null 2>&1 && ! pgrep -i -f "Traktor" >/dev/null 2>&1; then
                echo -e "\n${BOLD}${YELLOW}Traktor Pro is not running. Opening Traktor Pro...${NC}"
                launch_traktor >/dev/null 2>&1 || true
                sleep 1.5
            fi
            echo -e "\n${BOLD}${GREEN}Launching Traktor Live Monitor in a new terminal window...${NC}\n"
            local full_cmd="\"$mon_sh\"; echo ''; echo 'Traktor monitor closed. Press [Enter] to exit...'; read -r"
            if launch_in_terminal "Traktor Live Monitor" "$full_cmd" "window"; then
                echo -e "${GREEN}✓ Traktor Live Monitor launched in standalone window.${NC}"
                sleep 1.2
            else
                echo -e "${YELLOW}External terminal emulator not available; running in current window...${NC}\n"
                sleep 0.8
                trap ':' INT
                "$mon_sh"
                trap 'exit_mix_manager' INT
                press_enter
            fi
            ;;
        2)
            if ! pgrep -i -f "Traktor.app/Contents/MacOS/Traktor$" >/dev/null 2>&1 && ! pgrep -i -f "Traktor\.exe" >/dev/null 2>&1 && ! pgrep -i -f "Traktor" >/dev/null 2>&1; then
                echo -e "\n${BOLD}${YELLOW}Traktor Pro is not running. Opening Traktor Pro...${NC}"
                launch_traktor >/dev/null 2>&1 || true
                sleep 1.5
            fi
            echo -e "\n${BOLD}${YELLOW}Launching Traktor Live Monitor in current window (Press 'q' to quit)...${NC}\n"
            sleep 0.8
            trap ':' INT
            "$mon_sh"
            trap 'exit_mix_manager' INT
            press_enter
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Querying Traktor Diagnostic Snapshot...${NC}\n"
            "$mon_sh" --once
            echo ""
            press_enter
            ;;
        4)
            echo -e "\n${BOLD}${YELLOW}Sending START RECORDING trigger to Traktor...${NC}\n"
            "$mon_sh" --start-recording
            echo ""
            press_enter
            ;;
        5)
            echo -e "\n${BOLD}${YELLOW}Sending STOP RECORDING trigger to Traktor...${NC}\n"
            "$mon_sh" --stop-recording
            echo ""
            press_enter
            ;;
        6)
            echo -e "\n${BOLD}${YELLOW}Sending TOGGLE RECORDING trigger to Traktor...${NC}\n"
            "$mon_sh" --toggle-recording
            echo ""
            press_enter
            ;;
        0|[qQ])
            return 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice!${NC}"
            sleep 1.2
            ;;
    esac
}

show_mix_drive_space() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}       MIX STORAGE DRIVES - DISK SPACE & INVENTORY USAGE REPORT       ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    local all_arch_dirs=()
    while IFS= read -r adir; do
        [ -n "$adir" ] && all_arch_dirs+=("$adir")
    done < <(get_all_mix_archive_dirs)

    if [ ${#all_arch_dirs[@]} -eq 0 ]; then
        all_arch_dirs=("${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}")
    fi

    # Precompute audio sizes with Python (fast single pass across all directories)
    local folder_audio_bytes=()
    local folder_audio_gbs=()
    local total_audio_bytes=0

    while IFS=$'\t' read -r d_path d_bytes d_gb; do
        folder_audio_bytes+=("$d_bytes")
        folder_audio_gbs+=("$d_gb")
        total_audio_bytes=$(python3 -c "print($total_audio_bytes + $d_bytes)" 2>/dev/null || awk "BEGIN {printf \"%.0f\", $total_audio_bytes + $d_bytes}")
    done < <(python3 -c "
import os, sys
dirs = sys.argv[1:]
audio_exts = {'.flac', '.wav'}
for d in dirs:
    total = 0
    if os.path.exists(d):
        for root, subdirs, files in os.walk(d):
            depth = 0 if root == d else os.path.relpath(root, d).count(os.sep) + 1
            if depth > 1 and 'mp3_converted_outputs' not in root.lower():
                continue
            for f in files:
                ext = os.path.splitext(f)[1].lower()
                if ext in audio_exts:
                    try: total += os.path.getsize(os.path.join(root, f))
                    except OSError: pass
                elif ext == '.mp3':
                    if depth == 0 or 'mp3_converted_outputs' in root.lower():
                        try: total += os.path.getsize(os.path.join(root, f))
                        except OSError: pass
    gb = total / (1024 ** 3)
    print(f'{d}\t{total}\t{gb:.2f}')
" "${all_arch_dirs[@]}")

    local loc_num=1
    local total_flacs_all=0
    local total_wavs_all=0
    local total_mp3s_all=0
    local total_free_kb=0
    local seen_mounts=""

    local folder_fs=()
    local folder_mounts=()
    local folder_totals=()
    local folder_used=()
    local folder_free=()
    local folder_pcts=()
    local folder_flacs=()
    local folder_wavs=()
    local folder_mp3s=()

    for idx in "${!all_arch_dirs[@]}"; do
        local mix_target="${all_arch_dirs[$idx]}"
        echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────────${NC}"
        local label="Primary Archive"
        [ "$loc_num" -gt 1 ] && label="Additional Storage Location #${loc_num}"
        echo -e "  [${BOLD}${YELLOW}${label}${NC}] ➔ ${BOLD}${WHITE}${mix_target}${NC}"
        echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────────${NC}"

        if [ ! -d "$mix_target" ]; then
            echo -e "  ${YELLOW}⚠️  Directory is currently unmounted or not accessible.${NC}\n"
            folder_fs+=("N/A")
            folder_mounts+=("Unmounted")
            folder_totals+=("N/A")
            folder_used+=("N/A")
            folder_free+=("N/A")
            folder_pcts+=("N/A")
            folder_flacs+=(0)
            folder_wavs+=(0)
            folder_mp3s+=(0)
            ((loc_num++))
            continue
        fi

        local fs total_kb used_kb avail_kb cap_pct mount_pt
        read -r fs total_kb used_kb avail_kb cap_pct mount_pt <<< $(df -k -P "$mix_target" 2>/dev/null | tail -n 1 | awk '{fs=$1; t=$2; u=$3; a=$4; c=$5; $1=$2=$3=$4=$5=""; sub(/^[ \t]+/, ""); print fs, t, u, a, c, $0}')
        if [ -n "$mount_pt" ]; then
            if [[ "$seen_mounts" != *"|${mount_pt}|"* ]]; then
                seen_mounts+="|${mount_pt}|"
                total_free_kb=$((total_free_kb + avail_kb))
            fi
        fi

        local df_output
        df_output=$(df -h -T "$mix_target" 2>/dev/null || df -h "$mix_target" 2>/dev/null)
        local line
        line=$(echo "$df_output" | tail -n 1)
        local fs_dev type total used avail pct mount
        if [ "$(echo "$df_output" | head -n 1 | awk '{print NF}')" -ge 7 ]; then
            read -r fs_dev type total used avail pct mount <<< "$line"
        else
            read -r fs_dev total used avail pct mount <<< "$line"
            type="filesystem"
        fi

        echo -e "  • ${BOLD}Device Filesystem:${NC}   ${CYAN}${fs_dev}${NC} (${type})"
        echo -e "  • ${BOLD}Mount Point:${NC}         ${GREEN}${mount}${NC}"
        echo -e "  • ${BOLD}Total Capacity:${NC}      ${total}"
        echo -e "  • ${BOLD}Space Used:${NC}          ${YELLOW}${used}${NC} (${pct})"
        echo -e "  • ${BOLD}Space Remaining:${NC}     ${BOLD}${GREEN}${avail}${NC} free"

        local pct_num
        pct_num=$(echo "$pct" | tr -dc '0-9')
        if [ -n "$pct_num" ]; then
            local bar_len=35
            local filled=$(( (pct_num * bar_len) / 100 ))
            local empty=$(( bar_len - filled ))
            local bar=""
            for ((i=0; i<filled; i++)); do bar+="█"; done
            for ((i=0; i<empty; i++)); do bar+="░"; done
            local bar_color="${GREEN}"
            [ "$pct_num" -ge 75 ] && bar_color="${YELLOW}"
            [ "$pct_num" -ge 90 ] && bar_color="${RED}"
            echo -e "  • ${BOLD}Usage Graph:${NC}         [${bar_color}${bar}${NC}] ${BOLD}${pct}${NC}"
        fi

        # File counts
        local flac_count wav_count mp3_count
        flac_count=$(find "$mix_target" -maxdepth 2 -type f \( -name "*.flac" -o -name "*.FLAC" \) 2>/dev/null | wc -l)
        wav_count=$(find "$mix_target" -maxdepth 2 -type f \( -name "*.wav" -o -name "*.WAV" \) 2>/dev/null | wc -l)
        if [ -d "$mix_target/MP3_CONVERTED_OUTPUTS" ]; then
            mp3_count=$(find "$mix_target/MP3_CONVERTED_OUTPUTS" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) 2>/dev/null | wc -l)
        elif [[ "$mix_target" =~ MP3_CONVERTED_OUTPUTS/?$ ]]; then
            mp3_count=$(find "$mix_target" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) 2>/dev/null | wc -l)
        else
            mp3_count=$(find "$mix_target" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) 2>/dev/null | wc -l)
        fi
        total_flacs_all=$((total_flacs_all + flac_count))
        total_wavs_all=$((total_wavs_all + wav_count))
        total_mp3s_all=$((total_mp3s_all + mp3_count))

        folder_fs+=("$fs_dev")
        folder_mounts+=("$mount")
        folder_totals+=("$total")
        folder_used+=("$used")
        folder_free+=("$avail")
        folder_pcts+=("$pct")
        folder_flacs+=("$flac_count")
        folder_wavs+=("$wav_count")
        folder_mp3s+=("$mp3_count")

        local f_gb="${folder_audio_gbs[$idx]:-0.00}"
        echo -e "  • ${BOLD}Audio Consumed:${NC}      ${CYAN}${f_gb} GB${NC}"
        echo -e "  • ${BOLD}Audio Files Hosted:${NC}  ${GREEN}${flac_count}${NC} FLACs | ${CYAN}${wav_count}${NC} WAVs | ${YELLOW}${mp3_count}${NC} MP3s\n"
        ((loc_num++))
    done

    local total_master_mixes=$((total_flacs_all + total_wavs_all + total_mp3s_all))
    local total_folders_configured=${#all_arch_dirs[@]}
    local total_consumed_gb
    total_consumed_gb=$(python3 -c "print(f'{$total_audio_bytes / (1024**3):.2f}')" 2>/dev/null || awk "BEGIN {printf \"%.2f\", $total_audio_bytes / 1073741824}")
    local total_free_gb
    total_free_gb=$(python3 -c "print(f'{$total_free_kb / (1024*1024):.2f}')" 2>/dev/null || awk "BEGIN {printf \"%.2f\", $total_free_kb / 1048576}")

    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "  Total FLAC Master Mixes Across All Drives: ${BOLD}${GREEN}${total_flacs_all}${NC}"
    echo -e "  Total WAV Master Mixes Across All Drives:  ${BOLD}${CYAN}${total_wavs_all}${NC}"
    echo -e "  Total MP3 Master Mixes Across All Drives:  ${BOLD}${YELLOW}${total_mp3s_all}${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "  Total Mix Archive Master Mixes:              ${BOLD}${WHITE}${total_master_mixes}${NC}"
    echo -e "  Total Mix Archive Storage Folders Configured: ${BOLD}${GREEN}${total_folders_configured}${NC}"
    echo -e "  Total Space Consumed:                        ${BOLD}${CYAN}${total_consumed_gb} GB${NC}"
    echo -e "  Total Space Free:                            ${BOLD}${GREEN}${total_free_gb} GB${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${BOLD}${WHITE}Configured Mix Archive Storage Folders Breakdown${NC}"
    echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────────────────────────${NC}"
    for ((idx=0; idx<${#all_arch_dirs[@]}; idx++)); do
        local f_num=$((idx + 1))
        local f_path="${all_arch_dirs[$idx]}"
        local f_fs="${folder_fs[$idx]}"
        local f_mount="${folder_mounts[$idx]}"
        local f_total="${folder_totals[$idx]}"
        local f_used="${folder_used[$idx]}"
        local f_free="${folder_free[$idx]}"
        local f_pct="${folder_pcts[$idx]}"
        local f_flac="${folder_flacs[$idx]}"
        local f_wav="${folder_wavs[$idx]}"
        local f_mp3="${folder_mp3s[$idx]}"
        local f_audio_gb="${folder_audio_gbs[$idx]:-0.00}"
        local f_mix_total=$((f_flac + f_wav + f_mp3))

        echo -e "  📁 ${BOLD}${YELLOW}[Folder #${f_num}]${NC} ${BOLD}${WHITE}${f_path}${NC}"
        echo -e "     • ${BOLD}Drive Mount:${NC}    ${GREEN}${f_mount}${NC} (${CYAN}${f_fs}${NC})"
        echo -e "     • ${BOLD}Space Free:${NC}     ${BOLD}${GREEN}${f_free}${NC} free"
        echo -e "     • ${BOLD}Space Used:${NC}     ${YELLOW}${f_used}${NC} (${f_pct} of ${f_total} capacity)"
        echo -e "     • ${BOLD}Audio Consumed:${NC} ${CYAN}${f_audio_gb} GB${NC}"
        echo -e "     • ${BOLD}Mixes Tally:${NC}    ${GREEN}${f_flac}${NC} FLACs | ${CYAN}${f_wav}${NC} WAVs | ${YELLOW}${f_mp3}${NC} MP3s (Total: ${BOLD}${WHITE}${f_mix_total}${NC} mixes)"
        echo ""
    done
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    press_enter
}

# Helper: Add extra mix archive storage directory and persist
add_extra_mix_archive_dir() {
    local new_dir="$1"
    [ -z "$new_dir" ] && return 1

    local current_extras="${EXTRA_MIX_ARCHIVE_DIRS:-${MIX_ARCHIVE_DIRS:-}}"
    local new_extras=""
    if [ -z "$current_extras" ]; then
        new_extras="$new_dir"
    else
        local IFS_BACK="$IFS"
        IFS=':,;'
        for e in $current_extras; do
            IFS="$IFS_BACK"
            local clean_e="${e#"${e%%[![:space:]]*}"}"
            clean_e="${clean_e%"${clean_e##*[![:space:]]}"}"
            clean_e="${clean_e%\"}"
            clean_e="${clean_e#\"}"
            clean_e="${clean_e%\'}"
            clean_e="${clean_e#\'}"
            if [ "$clean_e" = "$new_dir" ]; then
                return 0
            fi
            IFS=':,;'
        done
        IFS="$IFS_BACK"
        new_extras="${current_extras}:${new_dir}"
    fi

    EXTRA_MIX_ARCHIVE_DIRS="$new_extras"
    export EXTRA_MIX_ARCHIVE_DIRS
    clear_archive_dir_cache
    save_config_setting "EXTRA_MIX_ARCHIVE_DIRS" "$new_extras"
    save_config_setting "MIX_ARCHIVE_CONFIGURED" "true"
}

# Helper: Remove extra mix archive storage directory and persist
remove_extra_mix_archive_dir() {
    local target_dir="$1"
    local raw_extras="${EXTRA_MIX_ARCHIVE_DIRS:-${MIX_ARCHIVE_DIRS:-}}"
    local kept=()
    local IFS_BACK="$IFS"
    IFS=':,;'
    for e in $raw_extras; do
        IFS="$IFS_BACK"
        local clean_e="${e#"${e%%[![:space:]]*}"}"
        clean_e="${clean_e%"${clean_e##*[![:space:]]}"}"
        clean_e="${clean_e%\"}"
        clean_e="${clean_e#\"}"
        clean_e="${clean_e%\'}"
        clean_e="${clean_e#\'}"
        if [ -n "$clean_e" ] && [ "$clean_e" != "$target_dir" ]; then
            kept+=("$clean_e")
        fi
        IFS=':,;'
    done
    IFS="$IFS_BACK"

    local joined=""
    for k in "${kept[@]}"; do
        if [ -z "$joined" ]; then
            joined="$k"
        else
            joined="${joined}:${k}"
        fi
    done

    EXTRA_MIX_ARCHIVE_DIRS="$joined"
    export EXTRA_MIX_ARCHIVE_DIRS
    clear_archive_dir_cache
    save_config_setting "EXTRA_MIX_ARCHIVE_DIRS" "$joined"
}

configure_mix_archive_folder() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}     CONFIGURE MIX ARCHIVE STORAGE FOLDERS (PRIMARY & MULTIPLE)       ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        
        local current_path="${MIX_ARCHIVE_DIR:-}"
        local status_str
        if is_mix_archive_configured && [ -d "$current_path" ]; then
            status_str="${GREEN}Configured & Accessible${NC}"
        elif is_mix_archive_configured; then
            status_str="${YELLOW}Configured but Unmounted / Not Found${NC}"
        else
            status_str="${RED}Not Configured (Defaulting to: ${SCRIPT_DIR}/MIX_ARCHIVE)${NC}"
        fi
        
        local prim_flacs=0
        if [ -d "$current_path/FLAC_CONVERTED_OUTPUTS" ]; then
            prim_flacs=$(find "$current_path/FLAC_CONVERTED_OUTPUTS" -maxdepth 1 -type f -name "*.flac" 2>/dev/null | wc -l)
        elif [ -d "$current_path" ]; then
            prim_flacs=$(find "$current_path" -maxdepth 1 -type f -name "*.flac" 2>/dev/null | wc -l)
        fi

        echo -e "  • Primary Archive Path     : ${BOLD}${CYAN}${current_path:-$SCRIPT_DIR/MIX_ARCHIVE}${NC} ${DIM}(${prim_flacs} FLACs)${NC}"
        echo -e "  • Primary Status           : ${status_str}"

        # Parse and display extra archive paths
        local extra_list=()
        local raw_extras="${EXTRA_MIX_ARCHIVE_DIRS:-${MIX_ARCHIVE_DIRS:-}}"
        if [ -n "$raw_extras" ]; then
            local IFS_BACK="$IFS"
            IFS=':,;'
            for e_item in $raw_extras; do
                IFS="$IFS_BACK"
                local clean_e
                clean_e="${e_item#"${e_item%%[![:space:]]*}"}"
                clean_e="${clean_e%"${clean_e##*[![:space:]]}"}"
                clean_e="${clean_e%\"}"
                clean_e="${clean_e#\"}"
                clean_e="${clean_e%\'}"
                clean_e="${clean_e#\'}"
                [ -n "$clean_e" ] && extra_list+=("$clean_e")
                IFS=':,;'
            done
            IFS="$IFS_BACK"
        fi

        if [ ${#extra_list[@]} -gt 0 ]; then
            echo -e "  • Additional Storage Paths :"
            local e_idx=1
            for ed in "${extra_list[@]}"; do
                local ed_stat="${RED}Not Found${NC}"
                local ed_flacs=0
                if [ -d "$ed" ]; then
                    ed_flacs=$(find "$ed" -maxdepth 2 -type f -name "*.flac" 2>/dev/null | wc -l)
                    ed_stat="${GREEN}Accessible (${ed_flacs} FLACs)${NC}"
                fi
                echo -e "      ${BOLD}${CYAN}[${e_idx}]${NC} ${WHITE}${ed}${NC} ➔ ${ed_stat}"
                ((e_idx++))
            done
        else
            echo -e "  • Additional Storage Paths : ${DIM}None configured (Single Archive Mode)${NC}"
        fi
        echo ""

        local cfg_opts=(
            "1|Enter New Primary Mix Archive Folder Path|(Custom Directory Path)"
            "2|Auto-Detect & Select Primary from Connected Drives / Volumes|"
            "3|Reset Primary to Application Root Folder|(${SCRIPT_DIR}/MIX_ARCHIVE)"
            "4|Add New Additional Mix Archive Storage Location Folder|"
            "5|Remove an Additional Mix Archive Storage Location|"
            "6|Auto-Detect & Add Other Mix Folders from Connected Drives|"
            "7|View Detailed Space & Mix Inventory Across All Storage Folders|"
            "8|Clear All Additional Mix Archive Storage Locations|"
            "0|Return to Main Menu|(or Esc / q)"
        )
        local status_hdr="  • Primary Archive Path     : ${BOLD}${CYAN}${current_path:-$SCRIPT_DIR/MIX_ARCHIVE}${NC} ${DIM}(${prim_flacs} FLACs)${NC}\n  • Primary Status           : ${status_str}\n"
        if [ ${#extra_list[@]} -gt 0 ]; then
            status_hdr+="  • Additional Storage Paths :\n"
            local e_idx=1
            for ed in "${extra_list[@]}"; do
                local ed_stat="${RED}Not Found${NC}"
                local ed_flacs=0
                if [ -d "$ed" ]; then
                    ed_flacs=$(find "$ed" -maxdepth 2 -type f -name "*.flac" 2>/dev/null | wc -l)
                    ed_stat="${GREEN}Accessible (${ed_flacs} FLACs)${NC}"
                fi
                status_hdr+="      ${BOLD}${CYAN}[${e_idx}]${NC} ${WHITE}${ed}${NC} ➔ ${ed_stat}\n"
                ((e_idx++))
            done
        else
            status_hdr+="  • Additional Storage Paths : ${DIM}None configured (Single Archive Mode)${NC}\n"
        fi
        
        run_interactive_submenu "CONFIGURE MIX ARCHIVE STORAGE FOLDERS (PRIMARY & MULTIPLE)" "$status_hdr" cfg_opts 0
        local opt="$REPLY"
        case "$opt" in
            1)
                echo ""
                echo -e "${BOLD}Enter full path to your Primary Mix Archive storage directory:${NC}"
                echo -e "${DIM}(e.g. /run/media/$USER/WD BLACK B/MIX_ARCHIVE or /Volumes/EXTERNAL/MIX_ARCHIVE)${NC}"
                read -e -r -p "Path: " new_dir
                new_dir="${new_dir#"${new_dir%%[![:space:]]*}"}"
                new_dir="${new_dir%"${new_dir##*[![:space:]]}"}"
                new_dir="${new_dir%\"}"
                new_dir="${new_dir#\"}"
                new_dir="${new_dir%\'}"
                new_dir="${new_dir#\'}"
                
                # Expand tilde ~
                if [[ "$new_dir" =~ ^~(/.*)?$ ]]; then
                    new_dir="${HOME}${new_dir:1}"
                fi
                
                [ -z "$new_dir" ] && continue
                
                if [ ! -d "$new_dir" ]; then
                    echo -e "\n${YELLOW}Directory does not exist:${NC} ${new_dir}"
                    read -r -p "Would you like to create this directory now? [y/N]: " create_ans
                    if [[ "$create_ans" =~ ^[yY] ]]; then
                        mkdir -p "$new_dir" 2>/dev/null || {
                            echo -e "${RED}Error: Failed to create directory. Check permissions.${NC}"
                            sleep 2
                            continue
                        }
                    else
                        continue
                    fi
                fi
                
                # Setup subdirectories
                mkdir -p "$new_dir"/{FLAC_CONVERTED_OUTPUTS,CONVERTED_WAV_FILES,MP3_CONVERTED_OUTPUTS,WAV_CONVERTED_OUTPUTS,MP4_CONVERTED_OUTPUTS} 2>/dev/null || true
                
                MIX_ARCHIVE_DIR="$new_dir"
                MIX_ARCHIVE_CONFIGURED="true"
                OUTPUT_DIR="$new_dir/FLAC_CONVERTED_OUTPUTS"
                ARCHIVE_DIR="$new_dir/CONVERTED_WAV_FILES"
                MP3_OUTPUT_DIR="$new_dir/MP3_CONVERTED_OUTPUTS"
                WAV_OUTPUT_DIR="$new_dir/WAV_CONVERTED_OUTPUTS"
                MP4_OUTPUT_DIR="$new_dir/MP4_CONVERTED_OUTPUTS"
                export MIX_ARCHIVE_DIR MIX_ARCHIVE_CONFIGURED OUTPUT_DIR ARCHIVE_DIR MP3_OUTPUT_DIR WAV_OUTPUT_DIR MP4_OUTPUT_DIR
                
                save_config_setting "MIX_ARCHIVE_DIR" "$new_dir"
                save_config_setting "MIX_ARCHIVE_CONFIGURED" "true"
                
                cd "$new_dir" 2>/dev/null || true
                play_sound_effect "storage"
                echo -e "\n${GREEN}✓ Primary Mix Archive Folder successfully configured and saved!${NC}"
                echo -e "  Primary Location: ${BOLD}${WHITE}${new_dir}${NC}"
                sleep 2
                ;;
            2)
                local found_dirs=()
                echo -e "\n${CYAN}Scanning mounted drives and volumes for candidate mix folders...${NC}"
                shopt -s nullglob
                for d in "/run/media/$USER"/* "/run/media/mplanetarian"/* "/Volumes"/* "/media/$USER"/* "/mnt"/*; do
                    if [ -d "$d" ]; then
                        [ -d "$d/MIX_ARCHIVE" ] && found_dirs+=("$d/MIX_ARCHIVE")
                        [ -d "$d/MIX_ARCHIVE2" ] && found_dirs+=("$d/MIX_ARCHIVE2")
                        [ -d "$d/Mixes" ] && found_dirs+=("$d/Mixes")
                        [ -d "$d/MIXES" ] && found_dirs+=("$d/MIXES")
                        found_dirs+=("$d")
                    fi
                done
                shopt -u nullglob
                
                local unique_dirs=()
                local seen_dirs=()
                for f_dir in "${found_dirs[@]}"; do
                    local real_d
                    real_d="$(cd "$f_dir" 2>/dev/null && pwd -P || echo "$f_dir")"
                    if [[ ! " ${seen_dirs[*]} " =~ " ${real_d} " ]]; then
                        seen_dirs+=("$real_d")
                        unique_dirs+=("$f_dir")
                    fi
                done
                
                if [ ${#unique_dirs[@]} -eq 0 ]; then
                    echo -e "\n${YELLOW}No external mounted drives detected.${NC}"
                    sleep 1.5
                    continue
                fi
                
                echo -e "\n${BOLD}Available Storage Locations:${NC}"
                local idx=1
                for u_dir in "${unique_dirs[@]}"; do
                    local note=""
                    [ -d "$u_dir/FLAC_CONVERTED_OUTPUTS" ] && note=" ${GREEN}(Contains FLAC_CONVERTED_OUTPUTS)${NC}"
                    echo -e "  ${BOLD}${CYAN}${idx})${NC} ${u_dir}${note}"
                    ((idx++))
                done
                echo -e "  ${BOLD}0)${NC} Back"
                
                read -r -p "Select a location [1-${#unique_dirs[@]}, 0]: " sel_idx
                if [[ "$sel_idx" =~ ^[0-9]+$ ]] && [ "$sel_idx" -ge 1 ] && [ "$sel_idx" -le "${#unique_dirs[@]}" ]; then
                    local chosen_dir="${unique_dirs[$((sel_idx - 1))]}"
                    mkdir -p "$chosen_dir"/{FLAC_CONVERTED_OUTPUTS,CONVERTED_WAV_FILES,MP3_CONVERTED_OUTPUTS,WAV_CONVERTED_OUTPUTS,MP4_CONVERTED_OUTPUTS} 2>/dev/null || true
                    MIX_ARCHIVE_DIR="$chosen_dir"
                    MIX_ARCHIVE_CONFIGURED="true"
                    OUTPUT_DIR="$chosen_dir/FLAC_CONVERTED_OUTPUTS"
                    ARCHIVE_DIR="$chosen_dir/CONVERTED_WAV_FILES"
                    MP3_OUTPUT_DIR="$chosen_dir/MP3_CONVERTED_OUTPUTS"
                    WAV_OUTPUT_DIR="$chosen_dir/WAV_CONVERTED_OUTPUTS"
                    MP4_OUTPUT_DIR="$chosen_dir/MP4_CONVERTED_OUTPUTS"
                    export MIX_ARCHIVE_DIR MIX_ARCHIVE_CONFIGURED OUTPUT_DIR ARCHIVE_DIR MP3_OUTPUT_DIR WAV_OUTPUT_DIR MP4_OUTPUT_DIR
                    save_config_setting "MIX_ARCHIVE_DIR" "$chosen_dir"
                    save_config_setting "MIX_ARCHIVE_CONFIGURED" "true"
                    cd "$chosen_dir" 2>/dev/null || true
                    play_sound_effect "storage"
                    echo -e "\n${GREEN}✓ Primary Mix Archive Folder successfully set to:${NC} ${BOLD}${WHITE}${chosen_dir}${NC}"
                    sleep 2
                fi
                ;;
            3)
                local root_archive="$SCRIPT_DIR/MIX_ARCHIVE"
                mkdir -p "$root_archive"/{FLAC_CONVERTED_OUTPUTS,CONVERTED_WAV_FILES,MP3_CONVERTED_OUTPUTS,WAV_CONVERTED_OUTPUTS,MP4_CONVERTED_OUTPUTS} 2>/dev/null || true
                MIX_ARCHIVE_DIR="$root_archive"
                MIX_ARCHIVE_CONFIGURED="true"
                OUTPUT_DIR="$root_archive/FLAC_CONVERTED_OUTPUTS"
                ARCHIVE_DIR="$root_archive/CONVERTED_WAV_FILES"
                MP3_OUTPUT_DIR="$root_archive/MP3_CONVERTED_OUTPUTS"
                WAV_OUTPUT_DIR="$root_archive/WAV_CONVERTED_OUTPUTS"
                MP4_OUTPUT_DIR="$root_archive/MP4_CONVERTED_OUTPUTS"
                export MIX_ARCHIVE_DIR MIX_ARCHIVE_CONFIGURED OUTPUT_DIR ARCHIVE_DIR MP3_OUTPUT_DIR WAV_OUTPUT_DIR MP4_OUTPUT_DIR
                save_config_setting "MIX_ARCHIVE_DIR" "$root_archive"
                save_config_setting "MIX_ARCHIVE_CONFIGURED" "true"
                cd "$root_archive" 2>/dev/null || true
                play_sound_effect "storage"
                echo -e "\n${GREEN}✓ Primary Mix Archive Folder reset to Application Root Folder:${NC} ${BOLD}${WHITE}${root_archive}${NC}"
                sleep 2
                ;;
            4)
                echo ""
                echo -e "${BOLD}Enter full path to the Additional Mix Archive folder:${NC}"
                echo -e "${DIM}(e.g. /run/media/$USER/DATA/MIX_ARCHIVE2/FLAC_CONVERTED_OUTPUTS/)${NC}"
                read -e -r -p "Additional Archive Path: " add_dir
                add_dir="${add_dir#"${add_dir%%[![:space:]]*}"}"
                add_dir="${add_dir%"${add_dir##*[![:space:]]}"}"
                add_dir="${add_dir%\"}"
                add_dir="${add_dir#\"}"
                add_dir="${add_dir%\'}"
                add_dir="${add_dir#\'}"
                
                if [[ "$add_dir" =~ ^~(/.*)?$ ]]; then
                    add_dir="${HOME}${add_dir:1}"
                fi
                
                [ -z "$add_dir" ] && continue
                
                if [ ! -d "$add_dir" ]; then
                    echo -e "\n${YELLOW}Directory does not currently exist:${NC} ${add_dir}"
                    read -r -p "Create this directory now? [y/N]: " create_ans
                    if [[ "$create_ans" =~ ^[yY] ]]; then
                        mkdir -p "$add_dir" 2>/dev/null || {
                            echo -e "${RED}Error: Failed to create directory.${NC}"
                            sleep 2
                            continue
                        }
                    else
                        continue
                    fi
                fi
                
                add_extra_mix_archive_dir "$add_dir"
                play_sound_effect "storage"
                echo -e "\n${GREEN}✓ Additional Mix Archive Location successfully added and saved!${NC}"
                echo -e "  Location: ${BOLD}${WHITE}${add_dir}${NC}"
                sleep 2
                ;;
            5)
                if [ ${#extra_list[@]} -eq 0 ]; then
                    echo -e "\n${YELLOW}No additional mix archive locations currently configured.${NC}"
                    sleep 1.5
                    continue
                fi
                echo -e "\n${BOLD}Select an Additional Mix Archive Location to Remove:${NC}"
                local r_idx=1
                for ed in "${extra_list[@]}"; do
                    echo -e "  ${BOLD}${CYAN}${r_idx})${NC} ${ed}"
                    ((r_idx++))
                done
                echo -e "  ${BOLD}0)${NC} Cancel"
                read -r -p "Enter number to remove [1-${#extra_list[@]}, 0]: " rem_idx
                if [[ "$rem_idx" =~ ^[0-9]+$ ]] && [ "$rem_idx" -ge 1 ] && [ "$rem_idx" -le "${#extra_list[@]}" ]; then
                    local rem_target="${extra_list[$((rem_idx - 1))]}"
                    remove_extra_mix_archive_dir "$rem_target"
                    echo -e "\n${GREEN}✓ Removed:${NC} ${rem_target}"
                    sleep 1.5
                fi
                ;;
            6)
                local found_dirs=()
                echo -e "\n${CYAN}Scanning mounted drives for potential mix archive folders...${NC}"
                shopt -s nullglob
                for d in "/run/media/$USER"/* "/run/media/mplanetarian"/* "/Volumes"/* "/media/$USER"/* "/mnt"/*; do
                    if [ -d "$d" ]; then
                        [ -d "$d/FLAC_CONVERTED_OUTPUTS" ] && found_dirs+=("$d/FLAC_CONVERTED_OUTPUTS")
                        [ -d "$d/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS" ] && found_dirs+=("$d/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS")
                        [ -d "$d/MIX_ARCHIVE2/FLAC_CONVERTED_OUTPUTS" ] && found_dirs+=("$d/MIX_ARCHIVE2/FLAC_CONVERTED_OUTPUTS")
                        [ -d "$d/MIX_ARCHIVE" ] && found_dirs+=("$d/MIX_ARCHIVE")
                        [ -d "$d/MIX_ARCHIVE2" ] && found_dirs+=("$d/MIX_ARCHIVE2")
                        [ -d "$d/Mixes" ] && found_dirs+=("$d/Mixes")
                        [ -d "$d/MIXES" ] && found_dirs+=("$d/MIXES")
                    fi
                done
                shopt -u nullglob

                local unique_candidates=()
                local seen_cand=()
                local prim_real
                prim_real="$(cd "${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}" 2>/dev/null && pwd -P || echo "")"
                for cand in "${found_dirs[@]}"; do
                    local r_cand
                    r_cand="$(cd "$cand" 2>/dev/null && pwd -P || echo "$cand")"
                    # Skip primary
                    [ "$r_cand" = "$prim_real" ] && continue
                    # Skip already in extra_list
                    local already=0
                    for ex in "${extra_list[@]}"; do
                        local r_ex
                        r_ex="$(cd "$ex" 2>/dev/null && pwd -P || echo "$ex")"
                        [ "$r_cand" = "$r_ex" ] && already=1 && break
                    done
                    [ "$already" -eq 1 ] && continue
                    if [[ ! " ${seen_cand[*]} " =~ " ${r_cand} " ]]; then
                        seen_cand+=("$r_cand")
                        unique_candidates+=("$cand")
                    fi
                done

                if [ ${#unique_candidates[@]} -eq 0 ]; then
                    echo -e "\n${YELLOW}No new unconfigured mix archive folders detected on mounted drives.${NC}"
                    sleep 2
                    continue
                fi

                echo -e "\n${BOLD}Select a detected folder to add as an Additional Archive:${NC}"
                local c_idx=1
                for cand in "${unique_candidates[@]}"; do
                    local fc
                    fc=$(find "$cand" -maxdepth 2 -type f -name "*.flac" 2>/dev/null | wc -l)
                    echo -e "  ${BOLD}${CYAN}${c_idx})${NC} ${cand} ${GREEN}(${fc} FLAC files)${NC}"
                    ((c_idx++))
                done
                echo -e "  ${BOLD}0)${NC} Back"

                read -r -p "Select folder [1-${#unique_candidates[@]}, 0]: " sel_cand
                if [[ "$sel_cand" =~ ^[0-9]+$ ]] && [ "$sel_cand" -ge 1 ] && [ "$sel_cand" -le "${#unique_candidates[@]}" ]; then
                    local chosen_extra="${unique_candidates[$((sel_cand - 1))]}"
                    add_extra_mix_archive_dir "$chosen_extra"
                    play_sound_effect "storage"
                    echo -e "\n${GREEN}✓ Added additional mix archive location:${NC} ${chosen_extra}"
                    sleep 2
                fi
                ;;
            7)
                show_mix_drive_space
                ;;
            8)
                echo -e "\n${YELLOW}Are you sure you want to clear all additional mix archive locations? [y/N]:${NC} "
                read -r clr_ans
                if [[ "$clr_ans" =~ ^[yY] ]]; then
                    EXTRA_MIX_ARCHIVE_DIRS=""
                    export EXTRA_MIX_ARCHIVE_DIRS
                    save_config_setting "EXTRA_MIX_ARCHIVE_DIRS" ""
                    echo -e "\n${GREEN}✓ All additional storage locations cleared.${NC}"
                    sleep 1.5
                fi
                ;;
            0|[qQ]|ESC)
                return 0
                ;;
        esac
    done
}

manage_audio_conversion() {
    local script=""
    for s in "$SCRIPT_DIR/convert_audio_format.sh" "$SCRIPT_DIR/scripts/convert_audio_format.sh" "./convert_audio_format.sh"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: convert_audio_format.sh script not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        local conv_opts=(
            "1|Convert Single Audio File|(Interactive Selection & Auto-Split Prompt)"
            "2|Convert Current Staging WAV / OGG Files|(in ${PWD})"
            "3|Convert All WAV / OGG in CONVERTED_WAV_FILES/|(Archive batch)"
            "4|Convert FLAC Outputs to MP3 & OGG Vorbis|(320kbps CBR / Vorbis q8)"
            "5|WAV-to-WAV Bit Depth Conversion|(16/24/32-bit Float)"
            "6|Split Audio File into Parts & Generate Spek Spectrograms|(FLAC, MP3, OGG, WAV)"
            "7|EBU R128 Loudness Scanner & True-Peak Analyzer|(master_audio_loudness.py)"
            "8|Master & Normalize Loudness|(-14 LUFS Streaming / -16 LUFS Podcast / -23 LUFS)"
            "9|Standard Red Book CUE Sheet Generator & Audio Splitter|(generate_cue_sheet.py)"
            "10|Launch Full Interactive Converter CLI|(convert_audio_format.sh)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        local conv_hdr="  Supported Formats: ${BOLD}FLAC, MP3, Ogg Vorbis, Opus, Apple AAC, WAV${NC}\n  WAV Bit Depths:    ${BOLD}32-bit Float, 32-bit Int, 24-bit PCM, 16-bit 44.1kHz PCM${NC}\n"
        run_interactive_submenu "AUDIO FORMAT & BIT DEPTH CONVERTER" "$conv_hdr" conv_opts 0
        local conv_choice="$REPLY"

        case "$conv_choice" in
            1)
                bash "$script" -i
                press_enter
                ;;
            2)
                bash "$script" -c
                press_enter
                ;;
            3)
                bash "$script" -w
                press_enter
                ;;
            4)
                bash "$script" -f -o mp3 -b 320k
                press_enter
                ;;
            5)
                bash "$script" -w -o wav -d 24
                press_enter
                ;;
            6)
                split_flac_audio
                press_enter
                ;;
            7)
                if [ -f "$SCRIPT_DIR/scripts/master_audio_loudness.py" ]; then
                    python3 "$SCRIPT_DIR/scripts/master_audio_loudness.py"
                else
                    echo -e "\n${RED}Error: master_audio_loudness.py not found!${NC}"
                fi
                press_enter
                ;;
            8)
                if [ -f "$SCRIPT_DIR/scripts/master_audio_loudness.py" ]; then
                    python3 "$SCRIPT_DIR/scripts/master_audio_loudness.py"
                else
                    echo -e "\n${RED}Error: master_audio_loudness.py not found!${NC}"
                fi
                press_enter
                ;;
            9)
                if [ -f "$SCRIPT_DIR/scripts/generate_cue_sheet.py" ]; then
                    python3 "$SCRIPT_DIR/scripts/generate_cue_sheet.py"
                else
                    echo -e "\n${RED}Error: generate_cue_sheet.py not found!${NC}"
                fi
                press_enter
                ;;
            10)
                bash "$script"
                press_enter
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

detect_active_music_player() {
    DETECTED_PLAYER_NAME=""
    DETECTED_TRACK_PATH=""
    DETECTED_TRACK_TITLE=""
    DETECTED_PLAYER_LABEL=""

    # 1. Check Audacious (priority if running or playing)
    if get_audacious_track_info 2>/dev/null && [ "$AUDACIOUS_STATE" = "playing" ]; then
        DETECTED_PLAYER_NAME="Audacious"
        DETECTED_TRACK_PATH="$AUDACIOUS_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$AUDACIOUS_TITLE"
    # 2. Check Strawberry (if running or playing)
    elif get_strawberry_track_info 2>/dev/null && [ "$STRAWBERRY_STATE" = "playing" ]; then
        DETECTED_PLAYER_NAME="Strawberry"
        DETECTED_TRACK_PATH="$STRAWBERRY_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$STRAWBERRY_TITLE"
    elif get_cliamp_track_info 2>/dev/null && [ "$CLIAMP_STATE" = "playing" ]; then
        DETECTED_PLAYER_NAME="cliamp"
        DETECTED_TRACK_PATH="$CLIAMP_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$CLIAMP_TITLE"
    elif get_audacious_track_info 2>/dev/null && [ -n "$AUDACIOUS_TITLE" ]; then
        DETECTED_PLAYER_NAME="Audacious"
        DETECTED_TRACK_PATH="$AUDACIOUS_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$AUDACIOUS_TITLE"
    elif get_strawberry_track_info 2>/dev/null && [ -n "$STRAWBERRY_TITLE" ]; then
        DETECTED_PLAYER_NAME="Strawberry"
        DETECTED_TRACK_PATH="$STRAWBERRY_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$STRAWBERRY_TITLE"
    elif get_cliamp_track_info 2>/dev/null && [ -n "$CLIAMP_TITLE" ]; then
        DETECTED_PLAYER_NAME="cliamp"
        DETECTED_TRACK_PATH="$CLIAMP_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$CLIAMP_TITLE"
    elif pgrep -i -f audacious >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="Audacious"
        get_audacious_track_info 2>/dev/null || true
        DETECTED_TRACK_PATH="$AUDACIOUS_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$AUDACIOUS_TITLE"
    elif pgrep -i -f strawberry >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="Strawberry"
        get_strawberry_track_info 2>/dev/null || true
        DETECTED_TRACK_PATH="$STRAWBERRY_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$STRAWBERRY_TITLE"
    elif pgrep -x cliamp >/dev/null 2>&1 || pgrep -i -f cliamp >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="cliamp"
        get_cliamp_track_info 2>/dev/null || true
        DETECTED_TRACK_PATH="$CLIAMP_RESOLVED_PATH"
        DETECTED_TRACK_TITLE="$CLIAMP_TITLE"
    elif pgrep -i -f vlc >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="VLC"
    elif pgrep -i -f audacity >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="Audacity"
    elif pgrep -i -f haruna >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="Haruna"
    elif pgrep -x mpv >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="mpv"
    elif pgrep -i -f kodi >/dev/null 2>&1; then
        DETECTED_PLAYER_NAME="Kodi"
    elif command -v playerctl >/dev/null 2>&1 && [ -n "$(playerctl -l 2>/dev/null)" ]; then
        local raw_p
        raw_p=$(playerctl -l 2>/dev/null | head -1 | sed 's/\..*//')
        case "${raw_p,,}" in
            audacious*) DETECTED_PLAYER_NAME="Audacious" ;;
            strawberry*) DETECTED_PLAYER_NAME="Strawberry" ;;
            vlc*) DETECTED_PLAYER_NAME="VLC" ;;
            haruna*) DETECTED_PLAYER_NAME="Haruna" ;;
            mpv*) DETECTED_PLAYER_NAME="mpv" ;;
            audacity*) DETECTED_PLAYER_NAME="Audacity" ;;
            kodi*) DETECTED_PLAYER_NAME="Kodi" ;;
            *) DETECTED_PLAYER_NAME="${raw_p:-Music Player}" ;;
        esac
    fi

    # Fallback to detect_currently_playing_mix if track path not yet resolved
    if [ -n "$DETECTED_PLAYER_NAME" ] && [ -z "$DETECTED_TRACK_PATH" ]; then
        if command -v playerctl >/dev/null 2>&1; then
            local u
            u=$(playerctl metadata xesam:url 2>/dev/null || true)
            if [[ "$u" == file://* ]]; then
                local p="${u#file://}"
                DETECTED_TRACK_PATH=$(printf '%b' "${p//%/\\x}")
            fi
            if [ -z "$DETECTED_TRACK_TITLE" ]; then
                DETECTED_TRACK_TITLE=$(playerctl metadata xesam:title 2>/dev/null || true)
            fi
        fi
        if [ -z "$DETECTED_TRACK_PATH" ]; then
            local dp
            dp=$(detect_currently_playing_mix 2>/dev/null || true)
            if [ -n "$dp" ] && [ -f "$dp" ]; then
                DETECTED_TRACK_PATH="$dp"
            fi
        fi
    fi

    if [ -n "$DETECTED_PLAYER_NAME" ]; then
        DETECTED_PLAYER_LABEL="${GREEN}${DETECTED_PLAYER_NAME}${NC}"
        return 0
    else
        DETECTED_PLAYER_LABEL="${RED}No Player Detected${NC}"
        return 1
    fi
}

manage_tracklists() {
    local doc_script=""
    for s in "$SCRIPT_DIR/generate_tracklist_docs.py" "$SCRIPT_DIR/scripts/generate_tracklist_docs.py" "./generate_tracklist_docs.py"; do
        if [ -f "$s" ]; then doc_script="$s"; break; fi
    done

    while true; do
        detect_active_music_player
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}                   TRACKLIST & METADATA MANAGEMENT                    ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Browse & View Tracklists (Select from Archive List)"
        echo -e "  ${BOLD}${CYAN}2)${NC} Search Tracklist by Title, Episode or Keyword"
        echo -e "  ${BOLD}${CYAN}3)${NC} View Tracklist of Currently Playing Track (Current Music Player: ${DETECTED_PLAYER_LABEL})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Export Tracklist to Styled HTML Document"
        echo -e "  ${BOLD}${CYAN}5)${NC} Export Tracklist to Printable PDF Document"
        echo -e "  ${BOLD}${CYAN}6)${NC} Batch Export All Archive Tracklists to HTML & PDF"
        echo -e "  ${BOLD}${CYAN}7)${NC} Scan & Generate Missing Tracklists (${GREEN}Check_Find_Tracklists.sh${NC})"
        echo -e "  ${BOLD}${CYAN}8)${NC} Generate Master Tracklist HTML Index (${GREEN}Generate_Master_Tracklist.sh${NC})"
        echo -e "  ${BOLD}${CYAN}9)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-9]: " tl_choice

        case "$tl_choice" in
            1)
                shopt -s nullglob nocaseglob
                local txt_files=("$PWD"/*.txt "$OUTPUT_DIR"/*.txt)
                shopt -u nullglob nocaseglob
                if [ ${#txt_files[@]} -eq 0 ]; then
                    echo -e "\n${YELLOW}No tracklist .txt files found in archive.${NC}"
                    press_enter
                    continue
                fi
                echo -e "\n${BOLD}${CYAN}Available Tracklists (${#txt_files[@]} found):${NC}"
                local idx=1
                local display_files=()
                for tf in "${txt_files[@]}"; do
                    local bname
                    bname=$(basename "$tf")
                    if [[ "$bname" != "requirements.txt" && "$bname" != "checksums"* ]]; then
                        printf "  %2d) %s\n" "$idx" "$bname"
                        display_files+=("$tf")
                        ((idx++))
                        if [ "$idx" -gt 35 ]; then
                            echo -e "  ${DIM}...and $(( ${#txt_files[@]} - 35 )) more (use search for specific mix)${NC}"
                            break
                        fi
                    fi
                done
                echo ""
                read -r -p "Enter number to view [1-${#display_files[@]}, or q to cancel]: " sel_idx
                if [[ "$sel_idx" =~ ^[0-9]+$ ]] && [ "$sel_idx" -ge 1 ] && [ "$sel_idx" -le "${#display_files[@]}" ]; then
                    local sel_file="${display_files[$((sel_idx - 1))]}"
                    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
                    echo -e "${BOLD}${CYAN}FILE: $(basename "$sel_file")${NC}"
                    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
                    if command -v bat >/dev/null 2>&1; then
                        bat --paging=always "$sel_file"
                    elif command -v less >/dev/null 2>&1; then
                        less -R "$sel_file"
                    else
                        cat "$sel_file"
                        press_enter
                    fi
                fi
                ;;
            2)
                read -r -p "Enter search keyword (e.g. 033, Escape, Episode): " query
                if [ -n "$query" ]; then
                    shopt -s nullglob nocaseglob
                    local matches=("$PWD"/*"$query"*.txt "$OUTPUT_DIR"/*"$query"*.txt)
                    shopt -u nullglob nocaseglob
                    if [ ${#matches[@]} -eq 0 ]; then
                        echo -e "\n${YELLOW}No tracklists matching '${query}' found.${NC}"
                        press_enter
                    else
                        echo -e "\n${BOLD}${GREEN}Matches Found:${NC}"
                        local m_idx=1
                        for m in "${matches[@]}"; do
                            printf "  %2d) %s\n" "$m_idx" "$(basename "$m")"
                            ((m_idx++))
                        done
                        read -r -p "Select file to view [1-${#matches[@]}]: " chosen
                        if [[ "$chosen" =~ ^[0-9]+$ ]] && [ "$chosen" -ge 1 ] && [ "$chosen" -le "${#matches[@]}" ]; then
                            local sel_file="${matches[$((chosen - 1))]}"
                            echo -e "\n${BOLD}${CYAN}=== TRACKLIST: $(basename "$sel_file") ===${NC}\n"
                            cat "$sel_file"
                            press_enter
                        fi
                    fi
                fi
                ;;
            3)
                detect_active_music_player
                if [ -z "$DETECTED_PLAYER_NAME" ]; then
                    echo -e "\n${RED}No music player is currently running.${NC}"
                    press_enter
                    continue
                fi

                # If no track path is found yet, try detect_currently_playing_mix
                if [ -z "$DETECTED_TRACK_PATH" ] || [ ! -f "$DETECTED_TRACK_PATH" ]; then
                    local fallback_path
                    fallback_path=$(detect_currently_playing_mix 2>/dev/null || true)
                    if [ -n "$fallback_path" ] && [ -f "$fallback_path" ]; then
                        DETECTED_TRACK_PATH="$fallback_path"
                    fi
                fi

                if [ -z "$DETECTED_TRACK_PATH" ] && [ -z "$DETECTED_TRACK_TITLE" ]; then
                    echo -e "\n${YELLOW}${DETECTED_PLAYER_NAME} is currently running, but has no track loaded or playing.${NC}"
                    press_enter
                    continue
                fi

                local found_tl=""
                if [ -n "$DETECTED_TRACK_PATH" ] && [ -f "$DETECTED_TRACK_PATH" ]; then
                    found_tl=$(find_mix_tracklist "$DETECTED_TRACK_PATH" 2>/dev/null || true)
                fi

                if [ -z "$found_tl" ] && [ -n "$DETECTED_TRACK_TITLE" ]; then
                    found_tl=$(find_mix_tracklist "$DETECTED_TRACK_TITLE" 2>/dev/null || true)
                fi

                # Additional comprehensive scan across all mix archive directories
                if [ -z "$found_tl" ]; then
                    local search_term="${DETECTED_TRACK_TITLE:-$(basename "$DETECTED_TRACK_PATH")}"
                    search_term="${search_term%.*}"
                    local ep=""
                    if [[ "$search_term" =~ [_\ -]([0-9]{2,3})([_\ -]|$) ]]; then
                        ep="${BASH_REMATCH[1]}"
                    elif [[ "$search_term" =~ ([0-9]{2,3}) ]]; then
                        ep="${BASH_REMATCH[1]}"
                    fi
                    local search_dirs=("$OUTPUT_DIR" "$PWD" "${MIX_ARCHIVE_DIR:-}")
                    if command -v get_all_flac_output_dirs >/dev/null 2>&1; then
                        while IFS= read -r f_dir; do
                            [ -n "$f_dir" ] && search_dirs+=("$f_dir")
                        done < <(get_all_flac_output_dirs)
                    fi
                    shopt -s nullglob nocaseglob
                    for sd in "${search_dirs[@]}"; do
                        [ -z "$sd" ] || [ ! -d "$sd" ] && continue
                        if [ -n "$ep" ]; then
                            for tm in "$sd"/*"$ep"*.txt; do
                                if [ -f "$tm" ] && [[ "$(basename "$tm")" != "requirements.txt" && "$(basename "$tm")" != "checksums"* ]]; then
                                    found_tl="$tm"
                                    break 2
                                fi
                            done
                        fi
                        for tm in "$sd"/*"${search_term}"*.txt; do
                            if [ -f "$tm" ] && [[ "$(basename "$tm")" != "requirements.txt" && "$(basename "$tm")" != "checksums"* ]]; then
                                found_tl="$tm"
                                break 2
                            fi
                        done
                    done
                    shopt -u nullglob nocaseglob
                fi

                if [ -n "$found_tl" ] && [ -f "$found_tl" ]; then
                    echo -e "\n${BOLD}${MAGENTA}======================================================================${NC}"
                    echo -e "  ${BOLD}${CYAN}CURRENT TRACKLIST:${NC} ${GREEN}$(basename "$found_tl")${NC}"
                    echo -e "  ${BOLD}${CYAN}MUSIC PLAYER:${NC}      ${YELLOW}${DETECTED_PLAYER_NAME}${NC}"
                    [ -n "$DETECTED_TRACK_TITLE" ] && echo -e "  ${BOLD}${CYAN}CURRENT TRACK:${NC}     ${WHITE}${DETECTED_TRACK_TITLE}${NC}"
                    [ -n "$DETECTED_TRACK_PATH" ] && echo -e "  ${BOLD}${CYAN}AUDIO FILE:${NC}        ${DIM}$(basename "$DETECTED_TRACK_PATH")${NC}"
                    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
                    cat "$found_tl"
                else
                    echo -e "\n${YELLOW}No tracklist found for current track '${DETECTED_TRACK_TITLE:-$(basename "$DETECTED_TRACK_PATH")}' playing in ${DETECTED_PLAYER_NAME}.${NC}"
                fi
                press_enter
                ;;
            4)
                if [ -n "$doc_script" ]; then
                    python3 "$doc_script" -f html
                else
                    echo -e "\n${RED}Error: generate_tracklist_docs.py not found!${NC}"
                fi
                press_enter
                ;;
            5)
                if [ -n "$doc_script" ]; then
                    python3 "$doc_script" -f pdf
                else
                    echo -e "\n${RED}Error: generate_tracklist_docs.py not found!${NC}"
                fi
                press_enter
                ;;
            6)
                if [ -n "$doc_script" ]; then
                    local all_flac_dirs=()
                    while IFS= read -r f_dir; do
                        [ -n "$f_dir" ] && [ -d "$f_dir" ] && all_flac_dirs+=("$f_dir")
                    done < <(get_all_flac_output_dirs)
                    echo -e "\n${BOLD}${YELLOW}Batch exporting all tracklists across ${#all_flac_dirs[@]} archive(s) to HTML and PDF...${NC}\n"
                    python3 "$doc_script" -d "${all_flac_dirs[@]}" -f both
                else
                    echo -e "\n${RED}Error: generate_tracklist_docs.py not found!${NC}"
                fi
                press_enter
                ;;
            7)
                run_sub_script "Check_Find_Tracklists.sh"
                press_enter
                ;;
            8)
                if [ -f "$SCRIPT_DIR/Generate_Master_Tracklist.sh" ]; then
                    bash "$SCRIPT_DIR/Generate_Master_Tracklist.sh"
                else
                    run_sub_script "Generate_Master_Tracklist.sh"
                fi
                press_enter
                ;;
            9|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

manage_promo_outreach() {
    local py_script=""
    for s in "$SCRIPT_DIR/send_promo_email.py" "$SCRIPT_DIR/scripts/send_promo_email.py" "./send_promo_email.py"; do
        if [ -f "$s" ]; then py_script="$s"; break; fi
    done

    if [ -z "$py_script" ]; then
        echo -e "\n${RED}Error: send_promo_email.py not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             PROMOTIONAL & PUBLISHER OUTREACH SYSTEM                  ${NC}"
        echo -e "${BOLD}${MAGENTA}         (Promoters, Podcast Publishers, Radio & Labels)              ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

        local contact_count="0"
        local contacts_file="$SCRIPT_DIR/assets/promo_contacts.json"
        if [ ! -f "$contacts_file" ] && [ -f "./assets/promo_contacts.json" ]; then
            contacts_file="./assets/promo_contacts.json"
        fi
        if [ -f "$contacts_file" ]; then
            contact_count=$(grep -c '"email":' "$contacts_file" 2>/dev/null || echo "0")
        fi

        echo -e "  Sender Name:          ${GREEN}${PROMO_SENDER_NAME:-MPlanetarian}${NC}"
        echo -e "  Sender Email:         ${CYAN}${PROMO_SENDER_EMAIL:-Not Set (Direct desktop mailto/preview)}${NC}"
        echo -e "  SMTP Outgoing Server: ${YELLOW}${SMTP_HOST:-None Configured (Mail client / Browser preview)}${NC}"
        echo -e "  Outreach Contacts:    ${GREEN}${contact_count} contacts in address book${NC}"
        echo ""
        echo -e "${BOLD}Send Enquiries & Promotional Pitches:${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} ${GREEN}Interactive Outreach Wizard${NC} (Step-by-step custom email builder)"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Pitch Episode to Podcast Publishers & Syndicators (${CYAN}Apple Podcasts, DI.FM, Proton...${NC})"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Send Booking / Guest Mix Enquiry to Promoters & Venues (${CYAN}Clubs, Festivals...${NC})"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Send New Episode Press & Promo Release Blast"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Send Track Support Courtesy Notice to Labels & Producers"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Submit Radio Guest Mix & Syndication Proposal"
        echo ""
        echo -e "${BOLD}Tools, Contacts & Preferences:${NC}"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Preview HTML & Plaintext Email in Browser & Terminal"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Browse & Search Outreach Contacts Book"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Add New Contact (Promoter, Publisher, Label, Radio, Press)"
        echo -e "  ${BOLD}${CYAN}10)${NC} View Sent Email History & Delivery Logs"
        echo -e "  ${BOLD}${CYAN}11)${NC} Configure Sender Profile & SMTP Server Settings"
        echo ""
        echo -e "  ${BOLD}${CYAN}12)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-12]: " p_choice

        case "$p_choice" in
            1)
                python3 "$py_script" --interactive
                press_enter
                ;;
            2)
                echo -e "\n${BOLD}${CYAN}=== PITCH TO PODCAST PUBLISHERS & SYNDICATORS ===${NC}\n"
                read -r -p "Enter episode number or keyword (or ENTER for latest): " ep_q
                read -r -p "Enter recipient email (or ENTER to select from saved publishers): " to_email
                local extra_args=()
                if [ -n "$to_email" ]; then
                    extra_args+=(--to "$to_email")
                else
                    extra_args+=(--category publisher)
                fi
                [ -n "$ep_q" ] && extra_args+=(--episode "$ep_q")
                python3 "$py_script" --template podcast_publisher "${extra_args[@]}" --interactive
                press_enter
                ;;
            3)
                echo -e "\n${BOLD}${CYAN}=== PROMOTER & VENUE BOOKING ENQUIRY ===${NC}\n"
                read -r -p "Enter episode number or keyword (or ENTER for latest): " ep_q
                read -r -p "Enter recipient email (or ENTER to select from saved promoters): " to_email
                local extra_args=()
                if [ -n "$to_email" ]; then
                    extra_args+=(--to "$to_email")
                else
                    extra_args+=(--category promoter)
                fi
                [ -n "$ep_q" ] && extra_args+=(--episode "$ep_q")
                python3 "$py_script" --template promoter_booking "${extra_args[@]}" --interactive
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${CYAN}=== NEW EPISODE PROMO RELEASE BLAST ===${NC}\n"
                read -r -p "Enter episode number or keyword (or ENTER for latest): " ep_q
                read -r -p "Enter recipient email (or ENTER to select from press/media contacts): " to_email
                local extra_args=()
                if [ -n "$to_email" ]; then
                    extra_args+=(--to "$to_email")
                else
                    extra_args+=(--category press)
                fi
                [ -n "$ep_q" ] && extra_args+=(--episode "$ep_q")
                python3 "$py_script" --template episode_promo "${extra_args[@]}" --interactive
                press_enter
                ;;
            5)
                echo -e "\n${BOLD}${CYAN}=== TRACK SUPPORT COURTESY NOTICE TO LABELS ===${NC}\n"
                read -r -p "Enter episode number or keyword (or ENTER for latest): " ep_q
                read -r -p "Enter label / artist email (or ENTER to select from saved labels): " to_email
                local extra_args=()
                if [ -n "$to_email" ]; then
                    extra_args+=(--to "$to_email")
                else
                    extra_args+=(--category label)
                fi
                [ -n "$ep_q" ] && extra_args+=(--episode "$ep_q")
                python3 "$py_script" --template track_support "${extra_args[@]}" --interactive
                press_enter
                ;;
            6)
                echo -e "\n${BOLD}${CYAN}=== RADIO GUEST MIX & SYNDICATION PROPOSAL ===${NC}\n"
                read -r -p "Enter episode number or keyword (or ENTER for latest): " ep_q
                read -r -p "Enter station / show email (or ENTER to select from saved radio stations): " to_email
                local extra_args=()
                if [ -n "$to_email" ]; then
                    extra_args+=(--to "$to_email")
                else
                    extra_args+=(--category radio)
                fi
                [ -n "$ep_q" ] && extra_args+=(--episode "$ep_q")
                python3 "$py_script" --template radio_guestmix "${extra_args[@]}" --interactive
                press_enter
                ;;
            7)
                echo -e "\n${BOLD}${CYAN}=== PREVIEW EMAIL IN WEB BROWSER ===${NC}\n"
                python3 "$py_script" --list-templates
                read -r -p "Enter template name [podcast_publisher]: " t_name
                t_name="${t_name:-podcast_publisher}"
                read -r -p "Enter episode number or keyword (or ENTER for latest): " ep_q
                local prev_args=(--template "$t_name" --preview)
                [ -n "$ep_q" ] && prev_args+=(--episode "$ep_q")
                python3 "$py_script" "${prev_args[@]}"
                press_enter
                ;;
            8)
                python3 "$py_script" --list-contacts
                press_enter
                ;;
            9)
                python3 "$py_script" --add-contact
                press_enter
                ;;
            10)
                local log_file="$SCRIPT_DIR/assets/promo_logs/sent_promo_emails.log"
                if [ ! -f "$log_file" ] && [ -f "./assets/promo_logs/sent_promo_emails.log" ]; then
                    log_file="./assets/promo_logs/sent_promo_emails.log"
                fi
                echo -e "\n${BOLD}${CYAN}=== OUTREACH & DELIVERY LOGS ===${NC}\n"
                if [ -f "$log_file" ] && [ -s "$log_file" ]; then
                    tail -n 35 "$log_file"
                else
                    echo -e "${DIM}No sent emails or drafts logged yet.${NC}"
                fi
                echo ""
                press_enter
                ;;
            11)
                echo -e "\n${BOLD}${CYAN}=== CONFIGURE SENDER PROFILE & SMTP SERVER ===${NC}\n"
                read -r -p "Sender Full Name [${PROMO_SENDER_NAME:-MPlanetarian}]: " new_name
                read -r -p "Sender Email Address [${PROMO_SENDER_EMAIL}]: " new_email
                read -r -p "SMTP Host (e.g. smtp.gmail.com) [${SMTP_HOST}]: " new_host
                read -r -p "SMTP Port [${SMTP_PORT:-587}]: " new_port
                read -r -p "SMTP Username / Login Email [${SMTP_USER}]: " new_user
                read -r -s -p "SMTP Password / App Password (leave blank to keep existing): " new_pass
                echo ""

                local cfg_file="$SCRIPT_DIR/config.env"
                if [ ! -f "$cfg_file" ] && [ -f "./config.env" ]; then cfg_file="./config.env"; fi

                if [ -n "$new_name" ]; then
                    PROMO_SENDER_NAME="$new_name"
                    sed -i "s|^PROMO_SENDER_NAME=.*|PROMO_SENDER_NAME=\"$new_name\"|" "$cfg_file" 2>/dev/null || true
                fi
                if [ -n "$new_email" ]; then
                    PROMO_SENDER_EMAIL="$new_email"
                    sed -i "s|^PROMO_SENDER_EMAIL=.*|PROMO_SENDER_EMAIL=\"$new_email\"|" "$cfg_file" 2>/dev/null || true
                fi
                if [ -n "$new_host" ]; then
                    SMTP_HOST="$new_host"
                    sed -i "s|^SMTP_HOST=.*|SMTP_HOST=\"$new_host\"|" "$cfg_file" 2>/dev/null || true
                fi
                if [ -n "$new_port" ]; then
                    SMTP_PORT="$new_port"
                    sed -i "s|^SMTP_PORT=.*|SMTP_PORT=\"$new_port\"|" "$cfg_file" 2>/dev/null || true
                fi
                if [ -n "$new_user" ]; then
                    SMTP_USER="$new_user"
                    sed -i "s|^SMTP_USER=.*|SMTP_USER=\"$new_user\"|" "$cfg_file" 2>/dev/null || true
                fi
                if [ -n "$new_pass" ]; then
                    SMTP_PASSWORD="$new_pass"
                    sed -i "s|^SMTP_PASSWORD=.*|SMTP_PASSWORD=\"$new_pass\"|" "$cfg_file" 2>/dev/null || true
                fi
                echo -e "\n${GREEN}✔ Outreach settings updated in ${cfg_file}!${NC}"
                press_enter
                ;;
            12|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

search_and_play_mix() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}            SEARCH FOR MIX & AUTO-PLAY WITH LIVE TRACKLIST            ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    read -r -p "Enter mix search query (Episode #, Title, Date, Artist): " query
    if [ -z "$query" ]; then
        echo -e "\n${YELLOW}Search cancelled.${NC}"
        sleep 1
        return 0
    fi

    echo -e "\n${CYAN}Searching archive for '${query}'...${NC}"

    local search_dirs=("$OUTPUT_DIR" "$PWD" "${OUTPUT_DIR%/*}/CONVERTED_WAV_FILES" "${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}" "${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}/FLAC_CONVERTED_OUTPUTS")
    while IFS= read -r f_dir; do
        [ -n "$f_dir" ] && [ -d "$f_dir" ] && search_dirs+=("$f_dir")
    done < <(get_all_flac_output_dirs)
    while IFS= read -r w_dir; do
        [ -n "$w_dir" ] && [ -d "$w_dir" ] && search_dirs+=("$w_dir")
    done < <(get_all_wav_archive_dirs)
    while IFS= read -r a_dir; do
        [ -n "$a_dir" ] && [ -d "$a_dir" ] && search_dirs+=("$a_dir")
    done < <(get_all_mix_archive_dirs)

    local matches=()
    local seen_names=()

    for d in "${search_dirs[@]}"; do
        if [ -d "$d" ]; then
            while IFS= read -r -d '' file; do
                local bname
                bname=$(basename "$file")
                if [[ ! " ${seen_names[*]} " =~ " ${bname} " ]]; then
                    matches+=("$file")
                    seen_names+=("$bname")
                fi
            done < <(find "$d" -maxdepth 2 -type f \( -name "*$query*.flac" -o -name "*$query*.wav" -o -name "*$query*.mp3" \) -print0 2>/dev/null)
        fi
    done

    if [ ${#matches[@]} -eq 0 ]; then
        echo -e "\n${YELLOW}No audio mixes matching '${query}' were found in the archive.${NC}"
        press_enter
        return 0
    fi

    local selected_mix=""
    if [ ${#matches[@]} -eq 1 ]; then
        selected_mix="${matches[0]}"
        echo -e "\n${GREEN}Found 1 matching mix:${NC} $(basename "$selected_mix")"
    else
        echo -e "\n${BOLD}${CYAN}Multiple matches found (${#matches[@]} files):${NC}"
        for i in "${!matches[@]}"; do
            printf "  %2d) %s\n" "$((i + 1))" "$(basename "${matches[$i]}")"
        done
        echo ""
        read -r -p "Select mix to play [1-${#matches[@]}, or q to cancel]: " sel_idx
        if [[ "$sel_idx" =~ ^[0-9]+$ ]] && [ "$sel_idx" -ge 1 ] && [ "$sel_idx" -le "${#matches[@]}" ]; then
            selected_mix="${matches[$((sel_idx - 1))]}"
        else
            echo -e "\n${YELLOW}Selection cancelled.${NC}"
            sleep 1
            return 0
        fi
    fi

    echo -e "\n${BOLD}${YELLOW}Preparing playback for:${NC} $(basename "$selected_mix")"

    local cliamp_bin="cliamp"
    if ! command -v cliamp >/dev/null 2>&1; then
        if [ -x "$SCRIPT_DIR/bin/cliamp" ]; then
            cliamp_bin="$SCRIPT_DIR/bin/cliamp"
        elif [ -x "$HOME/.local/bin/cliamp" ]; then
            cliamp_bin="$HOME/.local/bin/cliamp"
        fi
    fi

    local is_cliamp_running=0
    if pgrep -x cliamp >/dev/null 2>&1; then
        is_cliamp_running=1
    fi

    if [ "$is_cliamp_running" -eq 1 ]; then
        echo -e "${CYAN}cliamp is already active; queuing and playing track...${NC}"
        "$cliamp_bin" queue "$selected_mix" 2>/dev/null || true
        sleep 0.4
        "$cliamp_bin" play 2>/dev/null || true
    else
        echo -e "${CYAN}Launching cliamp in a new console window...${NC}"
        local full_cmd=""$cliamp_bin" queue "$selected_mix" 2>/dev/null; "$cliamp_bin" --auto-play play 2>/dev/null || "$cliamp_bin" --auto-play"
        launch_in_terminal "cliamp - $(basename "$selected_mix")" "$full_cmd" "window"
    fi

    # Check if audio player actually started playing
    echo -e "${CYAN}Verifying playback status...${NC}"
    local started_playing=0
    for ((attempt=1; attempt<=10; attempt++)); do
        sleep 0.6
        if get_cliamp_track_info 2>/dev/null; then
            if [ "$CLIAMP_STATE" = "playing" ] || [ "$CLIAMP_RUNNING" -eq 1 ]; then
                started_playing=1
                break
            fi
        fi
    done

    if [ "$started_playing" -eq 1 ]; then
        echo -e "${BOLD}${GREEN}✓ Playback started successfully!${NC}"
        echo -e "${CYAN}Returning to manager and loading currently playing tracklist...${NC}\n"
        sleep 1.0

        # Display tracklist for the currently playing track
        local bname_no_ext
        bname_no_ext=$(basename "$selected_mix")
        bname_no_ext="${bname_no_ext%.*}"

        local found_tl=""
        found_tl=$(find_mix_tracklist "$selected_mix" 2>/dev/null || true)
        if [ -z "$found_tl" ] || [ ! -f "$found_tl" ]; then
            shopt -s nullglob nocaseglob
            local tl_candidates=(
                "${OUTPUT_DIR}/${bname_no_ext}.txt"
                "${selected_mix%.*}.txt"
                "$(dirname "$selected_mix")/${bname_no_ext}.txt"
                "$PWD/${bname_no_ext}.txt"
                "${OUTPUT_DIR}/"*${query}*".txt"
                "$PWD/"*${query}*".txt"
            )
            shopt -u nullglob nocaseglob

            for tc in "${tl_candidates[@]}"; do
                if [ -f "$tc" ]; then found_tl="$tc"; break; fi
            done
        fi

        if [ -n "$found_tl" ]; then
            echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
            echo -e "${BOLD}${CYAN}           CURRENTLY PLAYING TRACKLIST: $(basename "$found_tl")      ${NC}"
            echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
            cat "$found_tl"
            echo ""
            echo -e "${BOLD}${BLUE}──────────────────────────────────────────────────────────────────────${NC}"
            echo -e "${DIM}Playback active in cliamp. Press [Enter] to return to Main Menu...${NC}"
            read -r
        else
            echo -e "\n${YELLOW}Track is playing, but no matching tracklist .txt file found for '${bname_no_ext}'.${NC}"
            press_enter
        fi
    else
        echo -e "\n${YELLOW}⚠️  Audio player did not start playback. Skipping tracklist view.${NC}"
        sleep 1.8
    fi
}

manage_cover_converter() {
    local script=""
    for s in "$SCRIPT_DIR/convert_cover_art.py" "$SCRIPT_DIR/scripts/convert_cover_art.py" "./convert_cover_art.py"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: convert_cover_art.py not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}                   COVER ART CONVERTER & OPTIMIZER                    ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  Supported Formats:  ${BOLD}JPEG, WebP, PNG, TIFF${NC}"
        echo -e "  Byte Target Modes:  ${BOLD}1MB Podcast, 500KB, 2MB, or Custom Target Size${NC}"
        echo -e "  Resolution Presets: ${BOLD}3000x3000, 1400x1400, 1080x1080, 500x500${NC}\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Optimize Cover to 1MB Podcast Standard (${GREEN}Strict <= 1MB Target${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Convert Cover to WebP Format (${GREEN}High efficiency web delivery${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Resize Cover Art (${GREEN}Square 3000x3000, 1400x1400, 1080x1080${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Custom Byte Target Compression (${GREEN}Specify any byte/KB/MB size${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} Batch Convert All Covers in COVERS/ Directory"
        echo -e "  ${BOLD}${CYAN}6)${NC} Launch Interactive Cover Converter CLI"
        echo -e "  ${BOLD}${CYAN}7)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-7]: " cover_choice

        case "$cover_choice" in
            1)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                if [ -f "$img_path" ]; then
                    python3 "$script" -i "$img_path" --bytes 1MB -f jpg
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            2)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                if [ -f "$img_path" ]; then
                    python3 "$script" -i "$img_path" -f webp -q 90
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            3)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                if [ -f "$img_path" ]; then
                    echo -e "Select resolution: 1) 3000x3000  2) 1400x1400  3) 1080x1080  4) 500x500"
                    read -r -p "Enter preset [1-4]: " res_sel
                    local res="1400x1400"
                    case "$res_sel" in
                        1) res="3000x3000" ;;
                        2) res="1400x1400" ;;
                        3) res="1080x1080" ;;
                        4) res="500x500" ;;
                    esac
                    python3 "$script" -i "$img_path" -r "$res"
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            4)
                read -r -p "Enter path to cover image [default: ./Cover.png]: " img_path
                [ -z "$img_path" ] && img_path="./Cover.png"
                read -r -p "Enter target max size (e.g. 500KB, 1MB, 2.5MB): " target_sz
                [ -z "$target_sz" ] && target_sz="1MB"
                if [ -f "$img_path" ]; then
                    python3 "$script" -i "$img_path" --bytes "$target_sz"
                else
                    echo -e "\n${RED}File not found: $img_path${NC}"
                fi
                press_enter
                ;;
            5)
                local cov_dir="$PWD/COVERS"
                [ ! -d "$cov_dir" ] && cov_dir="${MIX_ARCHIVE_DIR:-$SCRIPT_DIR/MIX_ARCHIVE}/COVERS"
                if [ -d "$cov_dir" ]; then
                    echo -e "\n${BOLD}${YELLOW}Batch converting covers in: $cov_dir${NC}\n"
                    python3 "$script" -d "$cov_dir" --bytes 1MB -f jpg
                else
                    echo -e "\n${YELLOW}COVERS directory not found.${NC}"
                fi
                press_enter
                ;;
            6)
                python3 "$script" -h
                echo ""
                read -r -p "Enter custom arguments for convert_cover_art.py: " custom_args
                if [ -n "$custom_args" ]; then
                    python3 "$script" $custom_args
                fi
                press_enter
                ;;
            7|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

find_duplicate_audio_mixes() {
    local script=""
    for s in "$SCRIPT_DIR/find_duplicate_mixes.py" "$SCRIPT_DIR/scripts/find_duplicate_mixes.py" "./find_duplicate_mixes.py"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: find_duplicate_mixes.py not found!${NC}"
        press_enter
        return 1
    fi

    local scan_dirs=()
    while IFS= read -r f_dir; do
        [ -n "$f_dir" ] && [ -d "$f_dir" ] && scan_dirs+=("$f_dir")
    done < <(get_all_flac_output_dirs)
    while IFS= read -r w_dir; do
        [ -n "$w_dir" ] && [ -d "$w_dir" ] && scan_dirs+=("$w_dir")
    done < <(get_all_wav_archive_dirs)
    [ -d "$PWD" ] && scan_dirs+=("$PWD")

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             DUPLICATE AUDIO FILE DETECTOR & CLEANER                  ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  Detects exact binary duplicates and multiple renders across:"
        for sd in "${scan_dirs[@]}"; do
            echo -e "  • ${CYAN}${sd}${NC}"
        done
        echo ""
        echo -e "  ${BOLD}${CYAN}1)${NC} Scan & Generate Duplicate Mixes Report (${GREEN}Safe: Read Only${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Move Duplicates to Quarantine Directory (${YELLOW}DUPLICATES_QUARANTINE/${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Permanently Remove Duplicates (${RED}Prompt with safety confirmation${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} Custom Directory Scan"
        echo -e "  ${BOLD}${CYAN}5)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-5]: " dup_choice

        case "$dup_choice" in
            1)
                echo -e "\n${BOLD}${YELLOW}Scanning archives for duplicate mixes...${NC}\n"
                python3 "$script" -d "${scan_dirs[@]}" --action report
                press_enter
                ;;
            2)
                echo -e "\n${BOLD}${YELLOW}Scanning and moving duplicates to quarantine...${NC}\n"
                python3 "$script" -d "${scan_dirs[@]}" --action quarantine
                press_enter
                ;;
            3)
                echo -e "\n${BOLD}${RED}⚠️  WARNING: DELETION REQUESTED ⚠️${NC}\n"
                read -r -p "Are you sure you want to permanently delete duplicate files? [y/N]: " del_confirm
                case "$del_confirm" in
                    [yY]|[yY][eE][sS])
                        python3 "$script" -d "${scan_dirs[@]}" --action delete
                        ;;
                    *)
                        echo -e "\n${GREEN}Deletion cancelled.${NC}"
                        ;;
                esac
                press_enter
                ;;
            4)
                read -r -p "Enter directory path to scan for duplicates: " custom_dir
                if [ -d "$custom_dir" ]; then
                    python3 "$script" -d "$custom_dir" --action report
                else
                    echo -e "\n${RED}Directory not found: $custom_dir${NC}"
                fi
                press_enter
                ;;
            5|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

export_mixes_to_path() {
    clear
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                 EXPORT & COPY MIXES TO DESTINATION                   ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"

    read -r -p "Enter destination path (e.g. /media/USB_DRIVE/Mixes, ~/Music/Export): " dest_dir
    if [ -z "$dest_dir" ]; then
        echo -e "\n${YELLOW}Export cancelled.${NC}"
        sleep 1
        return 0
    fi

    dest_dir="${dest_dir/#\~/$HOME}"

    if [ ! -d "$dest_dir" ]; then
        echo -e "${YELLOW}Destination directory does not exist.${NC}"
        read -r -p "Create directory '${dest_dir}'? [Y/n]: " create_dir
        case "$create_dir" in
            [nN]*)
                echo -e "\n${YELLOW}Export cancelled.${NC}"
                sleep 1
                return 0
                ;;
            *)
                mkdir -p "$dest_dir" || { echo -e "${RED}Failed to create directory!${NC}"; press_enter; return 1; }
                echo -e "${GREEN}✓ Created directory: ${dest_dir}${NC}\n"
                ;;
        esac
    fi

    local all_flac_dirs=()
    while IFS= read -r f_dir; do
        [ -n "$f_dir" ] && [ -d "$f_dir" ] && all_flac_dirs+=("$f_dir")
    done < <(get_all_flac_output_dirs)

    echo -e "${BOLD}Select items to export:${NC}"
    echo -e "  ${BOLD}${CYAN}1)${NC} Complete Mix Package (FLAC + Cover Art + Tracklists TXT/HTML/PDF + Spek)"
    echo -e "  ${BOLD}${CYAN}2)${NC} Audio Files Only (FLAC / WAV / MP3)"
    echo -e "  ${BOLD}${CYAN}3)${NC} Tracklists & Documentation Only (.txt, .html, .pdf)"
    echo -e "  ${BOLD}${CYAN}4)${NC} Cover Art & Spectrograms Only"
    echo -e "  ${BOLD}${CYAN}5)${NC} Specific Mix by Search Keyword"
    echo -e "  ${BOLD}${CYAN}6)${NC} Cancel Export\n"
    read -r -p "Enter choice [1-6]: " exp_choice

    case "$exp_choice" in
        1)
            echo -e "\n${BOLD}${YELLOW}Exporting complete packages to: ${dest_dir}...${NC}\n"
            for fdir in "${all_flac_dirs[@]}"; do
                echo -e "Exporting from: ${CYAN}${fdir}${NC}"
                rsync -avh --progress "$fdir"/*.flac "$dest_dir/" 2>/dev/null || true
                rsync -avh "$fdir"/*.txt "$fdir"/*.html "$fdir"/*.pdf "$dest_dir/" 2>/dev/null || true
            done
            if [ -d "$PWD/COVERS" ]; then
                rsync -avh "$PWD/COVERS/" "$dest_dir/COVERS/" 2>/dev/null || true
            fi
            if [ -d "$PWD/SPEK_OUTPUTS" ]; then
                rsync -avh "$PWD/SPEK_OUTPUTS/" "$dest_dir/SPEK_OUTPUTS/" 2>/dev/null || true
            fi
            echo -e "\n${BOLD}${GREEN}✓ Complete mix package export finished.${NC}"
            ;;
        2)
            echo -e "\n${BOLD}${YELLOW}Exporting audio files to: ${dest_dir}...${NC}\n"
            for fdir in "${all_flac_dirs[@]}"; do
                echo -e "Exporting from: ${CYAN}${fdir}${NC}"
                rsync -avh --progress "$fdir"/*.flac "$dest_dir/" 2>/dev/null || true
            done
            rsync -avh --progress "$PWD"/*.flac "$PWD"/*.wav "$PWD"/*.mp3 "$dest_dir/" 2>/dev/null || true
            echo -e "\n${BOLD}${GREEN}✓ Audio file export finished.${NC}"
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Exporting tracklists and documentation to: ${dest_dir}...${NC}\n"
            for fdir in "${all_flac_dirs[@]}"; do
                echo -e "Exporting from: ${CYAN}${fdir}${NC}"
                rsync -avh "$fdir"/*.txt "$fdir"/*.html "$fdir"/*.pdf "$dest_dir/" 2>/dev/null || true
            done
            rsync -avh "$PWD"/*.txt "$PWD"/*.html "$PWD"/*.pdf "$dest_dir/" 2>/dev/null || true
            echo -e "\n${BOLD}${GREEN}✓ Tracklist documentation export finished.${NC}"
            ;;
        4)
            echo -e "\n${BOLD}${YELLOW}Exporting cover art and spectrograms to: ${dest_dir}...${NC}\n"
            [ -d "$PWD/COVERS" ] && rsync -avh "$PWD/COVERS/" "$dest_dir/COVERS/" 2>/dev/null || true
            [ -d "$PWD/SPEK_OUTPUTS" ] && rsync -avh "$PWD/SPEK_OUTPUTS/" "$dest_dir/SPEK_OUTPUTS/" 2>/dev/null || true
            [ -f "$PWD/Cover.png" ] && cp -v "$PWD/Cover.png" "$dest_dir/" 2>/dev/null || true
            echo -e "\n${BOLD}${GREEN}✓ Visual assets export finished.${NC}"
            ;;
        5)
            read -r -p "Enter mix search term (Episode #, Title): " mix_kw
            if [ -n "$mix_kw" ]; then
                echo -e "\n${BOLD}${YELLOW}Exporting matching assets for '${mix_kw}' to: ${dest_dir}...${NC}\n"
                for fdir in "${all_flac_dirs[@]}" "$PWD"; do
                    find "$fdir" -maxdepth 2 -type f -iname "*${mix_kw}*" -exec cp -v {} "$dest_dir/" \; 2>/dev/null
                done
                echo -e "\n${BOLD}${GREEN}✓ Matching mix assets exported.${NC}"
            fi
            ;;
        *)
            echo -e "\n${YELLOW}Export cancelled.${NC}"
            sleep 1
            return 0
            ;;
    esac
    press_enter
}

manage_audio_checksums() {
    local script=""
    for s in "$SCRIPT_DIR/manage_checksums.sh" "$SCRIPT_DIR/scripts/manage_checksums.sh" "./manage_checksums.sh"; do
        if [ -f "$s" ]; then script="$s"; break; fi
    done
    if [ -z "$script" ]; then
        echo -e "\n${RED}Error: manage_checksums.sh not found!${NC}"
        press_enter
        return 1
    fi

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}             AUDIO FILE CHECKSUM CREATION & VERIFICATION              ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        echo -e "  Cryptographic SHA-256 integrity protection for master mix files.\n"
        echo -e "  ${BOLD}${CYAN}1)${NC} Generate SHA-256 Checksums for FLAC Master Mixes (${GREEN}FLAC_CONVERTED_OUTPUTS${NC})"
        echo -e "  ${BOLD}${CYAN}2)${NC} Generate SHA-256 Checksums for Current Staging Directory (${GREEN}${PWD}${NC})"
        echo -e "  ${BOLD}${CYAN}3)${NC} Verify Archive Checksums & Detect Corruption (${GREEN}Verify against checksums.sha256${NC})"
        echo -e "  ${BOLD}${CYAN}4)${NC} View Checksum Manifest File (${CYAN}checksums.sha256${NC})"
        echo -e "  ${BOLD}${CYAN}5)${NC} View Historical Verification Logs (${CYAN}VERIFY_LOGS/${NC})"
        echo -e "  ${BOLD}${CYAN}6)${NC} Return to Main Menu\n"
        read -r -p "Enter choice [1-6]: " cs_choice

        case "$cs_choice" in
            1)
                bash "$script" -g -d "$OUTPUT_DIR"
                press_enter
                ;;
            2)
                bash "$script" -g -d "$PWD"
                press_enter
                ;;
            3)
                bash "$script" -v
                press_enter
                ;;
            4)
                if [ -f "$PWD/checksums.sha256" ]; then
                    echo -e "\n${BOLD}${CYAN}=== CHECKSUMS MANIFEST ($PWD/checksums.sha256) ===${NC}\n"
                    head -n 40 "$PWD/checksums.sha256"
                elif [ -f "$OUTPUT_DIR/checksums.sha256" ]; then
                    echo -e "\n${BOLD}${CYAN}=== CHECKSUMS MANIFEST ($OUTPUT_DIR/checksums.sha256) ===${NC}\n"
                    head -n 40 "$OUTPUT_DIR/checksums.sha256"
                else
                    echo -e "\n${YELLOW}No checksums.sha256 manifest found. Generate one first with Option 1 or 2.${NC}"
                fi
                press_enter
                ;;
            5)
                local log_dir="$PWD/VERIFY_LOGS"
                if [ -d "$log_dir" ] && [ "$(ls -A "$log_dir" 2>/dev/null)" ]; then
                    echo -e "\n${BOLD}${CYAN}Verification Logs in $log_dir:${NC}"
                    ls -lh "$log_dir"
                else
                    echo -e "\n${YELLOW}No verification logs found in VERIFY_LOGS/.${NC}"
                fi
                press_enter
                ;;
            6|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1.2
                ;;
        esac
    done
}

manage_mix_search_and_import() {
    clear 2>/dev/null || true
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}       Search & Import Mixes from Local Storage & Network SMB         ${NC}"
    echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
    echo -e "  ${BOLD}${CYAN} 1)${NC} Universal Search & Import Wizard ${GREEN}(Local Disks, USB, External Drives & SMB)${NC}"
    echo -e "  ${BOLD}${CYAN} 2)${NC} Dedicated Traktor & SOF SMB Share Ingest ${GREEN}(import_new_mixes.sh)${NC}"
    echo ""
    echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu"
    echo ""
    read -r -p "Select ingest mode [1-2, 0 to return]: " imode
    case "$imode" in
        1)
            run_sub_script "search_and_import_mixes.sh"
            press_enter
            ;;
        2)
            echo -e "\n${BOLD}${YELLOW}Starting SMB Import Process...${NC}\n"
            run_sub_script "import_new_mixes.sh"
            press_enter
            ;;
        0|*)
            return
            ;;
    esac
}

manage_installation_and_config() {
    run_sub_script "manage_installation_config.sh"
}

reboot_system() {
    echo -e "\n${BOLD}${RED}⚠️  SYSTEM REBOOT REQUESTED ⚠️${NC}\n"
    echo -e "${YELLOW}Are you sure you want to reboot the system?${NC}"
    read -r -p "Type 'yes' or 'y' to confirm reboot [y/N]: " confirm_reboot
    case "$confirm_reboot" in
        [yY]|[yY][eE][sS])
            echo -e "\n${BOLD}${RED}Rebooting system now... Goodbye!${NC}\n"
            sleep 1.5
            if [ "$OS_TYPE" = "macos" ]; then
                osascript -e 'tell app "System Events" to restart' 2>/dev/null || sudo shutdown -r now || shutdown -r now
            elif [ "$OS_TYPE" = "windows" ]; then
                shutdown.exe /r /t 0 2>/dev/null || shutdown /r /t 0
            elif [ "$OS_TYPE" = "wsl" ]; then
                cmd.exe /c shutdown /r /t 0 2>/dev/null || wsl.exe --shutdown
            elif [ "$OS_TYPE" = "freebsd" ]; then
                shutdown -r now || sudo shutdown -r now || reboot
            else
                if command -v systemctl >/dev/null 2>&1; then
                    sudo systemctl reboot || sudo reboot || sudo shutdown -r now || systemctl reboot || reboot
                else
                    sudo reboot || sudo shutdown -r now || reboot
                fi
            fi
            ;;
        *)
            echo -e "\n${GREEN}Reboot cancelled.${NC}"
            sleep 1.2
            ;;
    esac
}

get_audio_volume_and_mute() {
    local status="Unknown"
    if command -v wpctl >/dev/null 2>&1; then
        local wp_out
        wp_out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        if [ -n "$wp_out" ]; then
            local vol
            vol=$(echo "$wp_out" | awk '{printf "%d", $2 * 100}')
            if echo "$wp_out" | grep -qi "MUTED"; then
                echo "Muted (${vol}%)"
            else
                echo "${vol}%"
            fi
            return 0
        fi
    fi
    if command -v pactl >/dev/null 2>&1; then
        local pac_sink
        pac_sink=$(pactl get-default-sink 2>/dev/null)
        if [ -n "$pac_sink" ]; then
            local pac_mute
            pac_mute=$(pactl get-sink-mute "$pac_sink" 2>/dev/null | awk '{print $2}')
            local pac_vol
            pac_vol=$(pactl get-sink-volume "$pac_sink" 2>/dev/null | grep -o '[0-9]\+%' | head -1)
            if [ "$pac_mute" = "yes" ]; then
                echo "Muted (${pac_vol})"
            else
                echo "${pac_vol}"
            fi
            return 0
        fi
    fi
    if [ "$OS_TYPE" = "macos" ]; then
        local mac_vol mac_mute
        mac_vol=$(osascript -e "output volume of (get volume settings)" 2>/dev/null)
        mac_mute=$(osascript -e "output muted of (get volume settings)" 2>/dev/null)
        if [ "$mac_mute" = "true" ]; then
            echo "Muted (${mac_vol}%)"
        else
            echo "${mac_vol}%"
        fi
        return 0
    fi
    echo "Active"
}

toggle_audio_mute() {
    echo -e "\n${BOLD}${MAGENTA}=== MASTER AUDIO MUTE / UNMUTE CONTROL ===${NC}\n"
    local toggled=0
    if command -v wpctl >/dev/null 2>&1; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null && toggled=1
    elif command -v pactl >/dev/null 2>&1; then
        pactl set-sink-mute @DEFAULT_SINK@ toggle 2>/dev/null && toggled=1
    elif command -v amixer >/dev/null 2>&1; then
        amixer set Master toggle 2>/dev/null && toggled=1
    elif [ "$OS_TYPE" = "macos" ]; then
        osascript -e "set volume output muted not (output muted of (get volume settings))" 2>/dev/null && toggled=1
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        if command -v powershell.exe >/dev/null 2>&1; then
            powershell.exe -NoProfile -Command "$w = New-Object -ComObject WScript.Shell; $w.SendKeys([char]173)" 2>/dev/null && toggled=1
        fi
    elif [ "$OS_TYPE" = "freebsd" ] && command -v mixer >/dev/null 2>&1; then
        mixer vol.mute=toggle 2>/dev/null || mixer -s vol toggle 2>/dev/null && toggled=1
    fi

    if [ "$toggled" -eq 1 ]; then
        local current_st
        current_st=$(get_audio_volume_and_mute)
        echo -e "${GREEN}✓ Master audio mute state toggled successfully.${NC}"
        echo -e "  Current Audio Status: ${BOLD}${CYAN}${current_st}${NC}"
    else
        echo -e "${YELLOW}Warning: Could not detect standard audio mixer (wpctl/pactl/amixer/osascript).${NC}"
    fi
    sleep 1.2
}

manage_mix_scheduler() {
    local alarm_bin="$SCRIPT_DIR/mplanetarians-alarm-clock/alarm.sh"
    [ ! -x "$alarm_bin" ] && alarm_bin="$SCRIPT_DIR/alarm.sh"
    [ ! -x "$alarm_bin" ] && alarm_bin="./alarm.sh"

    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}       MORNING ALARM CLOCK & DJ MIX PLAYBACK SCHEDULER SUITE          ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        local alarm_summary
        alarm_summary=$(get_alarm_clock_status_display)
        if [ -n "$alarm_summary" ]; then
            echo -e "${alarm_summary}"
            echo -e "${BOLD}${MAGENTA}----------------------------------------------------------------------${NC}"
        fi
        echo ""
        echo -e "${BOLD}Select an operation:${NC}"
        echo -e "  ${BOLD}${BLUE}─── [ MPLANETARIANS ALARM CLOCK (WAKE UP EDITION) ] ───────────${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Morning Screen & Daily Brief (${GREEN}Animated Clock, Weather, Steam Games${NC})"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Alarm Clock Interactive Menu (${GREEN}Full TUI Alarm Interface${NC})"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Set New Morning Alarm (${GREEN}Time, Daily/Once, Volume, Mix Path${NC})"
        echo -e "  ${BOLD}${CYAN} 4)${NC} List All Saved Alarms & Timers (${GREEN}systemd user timers & status${NC})"
        echo -e "  ${BOLD}${CYAN} 5)${NC} Silence / Stop Ringing Alarm (${GREEN}Move mouse or manual stop${NC})"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Snooze Ringing Alarm (${GREEN}Ramp volume, custom snooze minutes${NC})"
        echo -e "  ${BOLD}${CYAN} 7)${NC} Cancel / Delete Saved Alarms (${GREEN}Cancel single alarm or all${NC})"
        echo -e "  ${BOLD}${CYAN} 8)${NC} Toggle Alarm Clock (${GREEN}Enable / Disable all alarms${NC})"
        echo -e "  ${BOLD}${CYAN} 9)${NC} Change Alarm Theme (${GREEN}Midnight Ink, Warm Brass, Forest Hour, Porcelain${NC})"
        echo -e "  ${BOLD}${CYAN}10)${NC} Configure Wake-Up Action (${GREEN}Browser on right screen / Console / URL${NC})"
        echo -e "  ${BOLD}${CYAN}11)${NC} Manage Morning Notes & Reminders (${GREEN}View / Add / Remove wake notes${NC})"
        echo -e "  ${BOLD}${CYAN}12)${NC} Test Morning Alarm Now (${RED}Loud Playback Test, Mouse Tracking & Steam Prompt${NC})"
        echo ""
        echo -e "  ${BOLD}${BLUE}─── [ DJ MIX AUTOMATED PLAYBACK SCHEDULER ] ───────────────────${NC}"
        echo -e "  ${BOLD}${CYAN}13)${NC} Schedule Single Mix / Playlist for Specific Date & Time (${GREEN}schedule_mix_playback.py${NC})"
        echo ""
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Main Menu"
        echo ""
        read -r -p "Enter choice [0-13]: " ac_choice
        case "$ac_choice" in
            1)
                clear
                if [ -x "$alarm_bin" ]; then
                    "$alarm_bin" brief
                else
                    echo -e "${RED}Error: alarm.sh not found!${NC}"
                fi
                press_enter
                ;;
            2)
                if [ -x "$alarm_bin" ]; then
                    "$alarm_bin" menu
                else
                    echo -e "${RED}Error: alarm.sh not found!${NC}"
                    press_enter
                fi
                ;;
            3)
                clear
                echo -e "${BOLD}${MAGENTA}=== SET NEW MORNING ALARM ===${NC}\n"
                read -r -p "Enter alarm time (e.g. 07:30, 6:45am, 1930): " a_time
                if [ -n "$a_time" ]; then
                    read -r -p "Repeat daily? [y/N]: " a_daily
                    read -r -p "Volume percentage [1-100, default 100]: " a_vol
                    read -r -p "Specific mix path (leave empty for random archive mix): " a_mus
                    local set_args=("$a_time")
                    [[ "$a_daily" =~ ^[Yy] ]] && set_args+=("--daily")
                    [ -n "$a_vol" ] && set_args+=("--volume" "$a_vol")
                    [ -n "$a_mus" ] && set_args+=("--music" "$a_mus")
                    if [ -x "$alarm_bin" ]; then
                        "$alarm_bin" set "${set_args[@]}"
                    fi
                fi
                press_enter
                ;;
            4)
                clear
                echo -e "${BOLD}${MAGENTA}=== SAVED ALARMS & TIMERS ===${NC}\n"
                if [ -x "$alarm_bin" ]; then
                    "$alarm_bin" list
                fi
                press_enter
                ;;
            5)
                echo -e "\n${YELLOW}Silencing alarm...${NC}"
                if [ -x "$alarm_bin" ]; then
                    "$alarm_bin" stop
                fi
                press_enter
                ;;
            6)
                read -r -p "Enter snooze minutes (default 5): " sn_min
                if [ -x "$alarm_bin" ]; then
                    "$alarm_bin" snooze "${sn_min:-5}"
                fi
                press_enter
                ;;
            7)
                clear
                echo -e "${BOLD}${MAGENTA}=== CANCEL SAVED ALARMS ===${NC}\n"
                if [ -x "$alarm_bin" ]; then
                    "$alarm_bin" list
                    echo ""
                    read -r -p "Enter Alarm ID to cancel (or 'all' to cancel all): " c_id
                    if [ -n "$c_id" ]; then
                        "$alarm_bin" cancel "$c_id"
                    fi
                fi
                press_enter
                ;;
            8)
                if [ -x "$alarm_bin" ]; then
                    local cur_en
                    cur_en=$("$alarm_bin" list 2>/dev/null | grep -i "enabled" || true)
                    if [ -n "$cur_en" ]; then
                        "$alarm_bin" disable
                    else
                        "$alarm_bin" enable
                    fi
                fi
                sleep 1.2
                ;;
            9)
                clear
                echo -e "${BOLD}${MAGENTA}=== CHANGE ALARM CLOCK THEME ===${NC}\n"
                echo -e "  ${BOLD}${CYAN}1)${NC} Midnight Ink (${DIM}navy and silver${NC})"
                echo -e "  ${BOLD}${CYAN}2)${NC} Warm Brass (${DIM}amber lamp-light${NC})"
                echo -e "  ${BOLD}${CYAN}3)${NC} Forest Hour (${DIM}deep green and gold${NC})"
                echo -e "  ${BOLD}${CYAN}4)${NC} Porcelain (${DIM}warm grey and rose${NC})"
                read -r -p "Enter choice [1-4]: " th_ch
                case "$th_ch" in
                    1) "$alarm_bin" theme midnight-ink ;;
                    2) "$alarm_bin" theme warm-brass ;;
                    3) "$alarm_bin" theme forest-hour ;;
                    4) "$alarm_bin" theme porcelain ;;
                esac
                sleep 1
                ;;
            10)
                clear
                echo -e "${BOLD}${MAGENTA}=== CONFIGURE WAKE-UP ACTION ===${NC}\n"
                echo -e "Current action:"
                "$alarm_bin" task
                echo ""
                echo -e "  ${BOLD}${CYAN}1)${NC} Browser on Display to the Right (Default)"
                echo -e "  ${BOLD}${CYAN}2)${NC} Browser with Custom URL"
                echo -e "  ${BOLD}${CYAN}3)${NC} Dedicated Console Window"
                echo -e "  ${BOLD}${CYAN}4)${NC} Clear / None"
                read -r -p "Enter choice [1-4]: " wk_ch
                case "$wk_ch" in
                    1) "$alarm_bin" task browser ;;
                    2)
                        read -r -p "Enter URL (e.g. https://news.ycombinator.com): " wk_url
                        "$alarm_bin" task browser "$wk_url"
                        ;;
                    3) "$alarm_bin" task console ;;
                    4) "$alarm_bin" task clear ;;
                esac
                sleep 1
                ;;
            11)
                clear
                echo -e "${BOLD}${MAGENTA}=== MORNING WAKE-UP NOTES ===${NC}\n"
                "$alarm_bin" note list
                echo ""
                echo -e "  ${BOLD}${CYAN}1)${NC} Add Note"
                echo -e "  ${BOLD}${CYAN}2)${NC} Remove Note by ID"
                echo -e "  ${BOLD}${CYAN}0)${NC} Done"
                read -r -p "Enter choice [0-2]: " nt_ch
                case "$nt_ch" in
                    1)
                        read -r -p "Enter note text: " nt_txt
                        [ -n "$nt_txt" ] && "$alarm_bin" note add "$nt_txt"
                        ;;
                    2)
                        read -r -p "Enter note ID to remove: " nt_id
                        [ -n "$nt_id" ] && "$alarm_bin" note rm "$nt_id"
                        ;;
                esac
                sleep 1
                ;;
            12)
                clear
                echo -e "${BOLD}${RED}=== TESTING MORNING ALARM (LOUD PLAYBACK & STEAM PROMPT) ===${NC}\n"
                echo -e "${YELLOW}Starting alarm test. Press Ctrl+C or move mouse to stop.${NC}\n"
                if [ -x "$alarm_bin" ]; then
                    "$alarm_bin" test
                fi
                press_enter
                ;;
            13)
                echo -e "\n${BOLD}${BLUE}=== DJ MIX SCHEDULER (PLAYS LOUDLY VIA DEFAULT AUDIO PLAYER) ===${NC}\n"
                local py_script="$SCRIPT_DIR/scripts/schedule_mix_playback.py"
                [ ! -f "$py_script" ] && py_script="$SCRIPT_DIR/schedule_mix_playback.py"
                [ ! -f "$py_script" ] && py_script="./scripts/schedule_mix_playback.py"
                if [ -x "$SCRIPT_DIR/scripts/schedule_mix_playback.sh" ]; then
                    "$SCRIPT_DIR/scripts/schedule_mix_playback.sh" --player "${DEFAULT_AUDIO_PLAYER:-strawberry}"
                elif command -v python3 >/dev/null 2>&1 && [ -f "$py_script" ]; then
                    python3 "$py_script" --player "${DEFAULT_AUDIO_PLAYER:-strawberry}"
                else
                    echo -e "${RED}Error: schedule_mix_playback script not found!${NC}"
                fi
                press_enter
                ;;
            0|[qQ]|[eE][xX][iI][tT])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

get_manager_uptime() {
    local now
    now=$(date +%s)
    local elapsed=$(( now - MANAGER_START_EPOCH ))
    local m_hours=$(( elapsed / 3600 ))
    local m_mins=$(( (elapsed % 3600) / 60 ))
    local m_secs=$(( elapsed % 60 ))
    local manager_up
    if [ $m_hours -gt 0 ]; then
        manager_up="${m_hours}h ${m_mins}m ${m_secs}s"
    elif [ $m_mins -gt 0 ]; then
        manager_up="${m_mins}m ${m_secs}s"
    else
        manager_up="${m_secs}s"
    fi

    local sys_up=""
    if [ -f /proc/uptime ]; then
        local sec
        sec=$(cut -d. -f1 /proc/uptime 2>/dev/null)
        local s_days=$(( sec / 86400 ))
        local s_hours=$(( (sec % 86400) / 3600 ))
        local s_mins=$(( (sec % 3600) / 60 ))
        if [ $s_days -gt 0 ]; then
            sys_up="${s_days}d ${s_hours}h ${s_mins}m"
        else
            sys_up="${s_hours}h ${s_mins}m"
        fi
    elif command -v uptime >/dev/null 2>&1; then
        sys_up=$(uptime | sed 's/.*up \([^,]*\), .*/\1/' | xargs)
    fi

    local audio_st
    audio_st=$(get_audio_volume_and_mute)

    echo -e "  ${BOLD}${CYAN}⏱ Manager Uptime:${NC} ${manager_up}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🖥 System Uptime:${NC} ${sys_up:-N/A}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🔊 Audio:${NC} ${audio_st}"
}

detect_currently_playing_mix() {
    # 1. Check Audacious (MPRIS / qdbus / dbus-send / audtool)
    if get_audacious_track_info 2>/dev/null; then
        if [ -n "$AUDACIOUS_RESOLVED_PATH" ] && [ -f "$AUDACIOUS_RESOLVED_PATH" ]; then
            echo "$AUDACIOUS_RESOLVED_PATH"
            return 0
        fi
    fi

    # 2. Check Strawberry (MPRIS / qdbus / dbus-send)
    if get_strawberry_track_info 2>/dev/null; then
        if [ -n "$STRAWBERRY_RESOLVED_PATH" ] && [ -f "$STRAWBERRY_RESOLVED_PATH" ]; then
            echo "$STRAWBERRY_RESOLVED_PATH"
            return 0
        fi
    fi

    # 3. Check cliamp
    if get_cliamp_track_info 2>/dev/null; then
        if [ -n "$CLIAMP_RESOLVED_PATH" ] && [ -f "$CLIAMP_RESOLVED_PATH" ]; then
            echo "$CLIAMP_RESOLVED_PATH"
            return 0
        fi
    fi

    # 4. Check playerctl
    if command -v playerctl >/dev/null 2>&1; then
        local p_status p_url
        p_status=$(playerctl status 2>/dev/null | head -1)
        if [ "$p_status" = "Playing" ] || [ "$p_status" = "Paused" ]; then
            p_url=$(playerctl metadata xesam:url 2>/dev/null | head -1)
            if [[ "$p_url" == file://* ]]; then
                local p_path="${p_url#file://}"
                p_path=$(printf '%b' "${p_path//%/\\x}")
                if [ -f "$p_path" ]; then
                    echo "$p_path"
                    return 0
                fi
            fi
        fi
    fi

    # 5. Check audacious/strawberry/vlc/mpv open file descriptors
    local target_pids
    target_pids=$(pgrep -i -f 'audacious|strawberry|vlc|mpv|kodi|cliamp' 2>/dev/null)
    for pid in $target_pids; do
        for fd in /proc/"$pid"/fd/*; do
            if [ -e "$fd" ]; then
                local link_target
                link_target=$(readlink "$fd" 2>/dev/null)
                case "$link_target" in
                    *.flac|*.wav|*.mp3|*.m4a|*.ogg)
                        if [ -f "$link_target" ]; then
                            echo "$link_target"
                            return 0
                        fi
                        ;;
                esac
            fi
        done
    done

    return 1
}

auto_show_playing_mix_assets() {
    local mix_file="$1"
    local player_name="${2:-${DEFAULT_AUDIO_PLAYER:-audacious}}"
    [ -z "$mix_file" ] || [ ! -f "$mix_file" ] && return 0

    local mix_basename
    mix_basename=$(basename "$mix_file")

    # 1. Open cover art in dedicated image viewer window
    local found_cover=""
    found_cover=$(find_mix_cover "$mix_file" 2>/dev/null)
    if [ -n "$found_cover" ] && [ -f "$found_cover" ]; then
        open_cover_art_window "$found_cover"
    fi

    # 2. Open tracklist in dedicated console window
    local found_tl=""
    found_tl=$(find_mix_tracklist "$mix_file" 2>/dev/null)
    if [ -n "$found_tl" ] && [ -f "$found_tl" ]; then
        open_tracklist_window "$found_tl"
    fi

    # Center and vertically align cover and tracklist on top of the manager window
    if [ -n "$found_cover" ] || [ -n "$found_tl" ]; then
        align_mix_windows_on_screen
    fi

    # 3. Custom YouTube video URL on startup (only if mix audio is playing!)
    if [ "${AUTO_PLAY_YOUTUBE_ON_STARTUP:-false}" = "true" ] && [ -n "${STARTUP_YOUTUBE_URL:-}" ]; then
        (sleep 0.6; open_video_url "$STARTUP_YOUTUBE_URL" >/dev/null 2>&1 || true) &
    fi

    clear
    echo -e "${BOLD}${MAGENTA}===================================================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                 🎶 NOW PLAYING MIX & ASSET DISPLAY 🎶                             ${NC}"
    echo -e "${BOLD}${MAGENTA}===================================================================================${NC}"
    echo -e "  • ${BOLD}Now Playing:${NC}       ${BOLD}${GREEN}${mix_basename}${NC}"
    echo -e "  • ${BOLD}Audio Player:${NC}      ${BOLD}${CYAN}${player_name}${NC}"
    local audio_spec
    audio_spec=$(get_playing_audio_spec_summary "$mix_file")
    if [ -n "$audio_spec" ]; then
        echo -e "  • ${BOLD}Audio Specs:${NC}       ${BOLD}${GREEN}${audio_spec}${NC}"
    fi
    local audio_out
    audio_out=$(get_active_audio_interface_display)
    if [ -n "$audio_out" ]; then
        echo -e "  • ${BOLD}Audio Output:${NC}     ${audio_out#  }"
    fi
    if [ -n "$found_cover" ]; then
        echo -e "  • ${BOLD}Cover Art Opened:${NC}  ${YELLOW}$(basename "$found_cover")${NC} (Image Viewer Window)"
    fi
    if [ -n "$found_tl" ]; then
        echo -e "  • ${BOLD}Tracklist Opened:${NC}  ${CYAN}$(basename "$found_tl")${NC} (Dedicated Text Editor Window)"
    fi
    echo -e "${BOLD}${MAGENTA}-----------------------------------------------------------------------------------${NC}"

    if [ -n "$found_tl" ]; then
        echo -e "\n${BOLD}${CYAN}=== TRACKLIST PREVIEW: $(basename "$found_tl") ===${NC}\n"
        head -n 25 "$found_tl"
        local total_lines
        total_lines=$(wc -l < "$found_tl" 2>/dev/null || echo "0")
        if [ "$total_lines" -gt 25 ]; then
            echo -e "  ${DIM}...and $((total_lines - 25)) more tracks (Also opened in full text editor window)${NC}"
        fi
    else
        echo -e "\n${YELLOW}No matching tracklist text file found for: ${mix_basename}${NC}"
    fi

    echo -e "\n${BOLD}${BLUE}───────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${DIM}Playback assets loaded in separate windows. Press [Enter] to continue to Main Menu...${NC}"
    if [ -t 0 ]; then
        if [ -e /dev/tty ]; then
            read -r -t 3 < /dev/tty 2>/dev/null || true
        else
            read -r -t 3 || true
        fi
    fi
}

check_and_show_currently_playing_mix() {
    # On startup, proceed directly to the main menu window.
    # Active playback info is displayed in the live status box by show_stats.
    return 0
}

open_video_url() {
    local url="$1"
    [ -z "$url" ] && return 1

    local player="${DEFAULT_VIDEO_PLAYER:-vlc}"
    if [ "$player" = "vlc" ]; then
        if command -v vlc >/dev/null 2>&1; then
            vlc "$url" >/dev/null 2>&1 &
            return 0
        elif command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "org.videolan.VLC"; then
            flatpak run org.videolan.VLC "$url" >/dev/null 2>&1 &
            return 0
        fi
    elif [ "$player" = "mpv" ]; then
        if command -v mpv >/dev/null 2>&1; then
            mpv "$url" >/dev/null 2>&1 &
            return 0
        fi
    fi

    # Fallback to default web browser
    if command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "com.google.Chrome"; then
        flatpak run com.google.Chrome "$url" >/dev/null 2>&1 &
    elif command -v google-chrome >/dev/null 2>&1; then
        google-chrome "$url" >/dev/null 2>&1 &
    elif command -v firefox >/dev/null 2>&1; then
        firefox "$url" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 &
    elif [ "$OS_TYPE" = "macos" ]; then
        open "$url" >/dev/null 2>&1 &
    elif [ "$OS_TYPE" = "windows" ]; then
        cmd.exe /c start "" "$url" >/dev/null 2>&1 &
    fi
}

get_current_weather() {
    [ "${WEATHER_ENABLED:-true}" != "true" ] && return 0
    [ -z "${WEATHER_LOCATION:-}" ] && return 0

    local weather_sh="$SCRIPT_DIR/scripts/get_weather.sh"
    [ ! -f "$weather_sh" ] && weather_sh="$PWD/scripts/get_weather.sh"
    if [ -x "$weather_sh" ]; then
        local w_data
        w_data=$("$weather_sh" get 2>/dev/null)
        if [ -n "$w_data" ]; then
            echo -e "  ${BOLD}${CYAN}🌤️  Weather:${NC} ${WHITE}${w_data}${NC}  ${DIM}(${WEATHER_LOCATION})${NC}"
        elif ! is_internet_connected; then
            echo -e "  ${BOLD}${CYAN}🌤️  Weather:${NC} ${YELLOW}Offline (No Internet Connection)${NC}  ${DIM}(${WEATHER_LOCATION})${NC}"
        fi
    fi
}

get_planets_above_horizon() {
    [ "${PLANETS_ENABLED:-true}" != "true" ] && return 0

    local planets_py="$SCRIPT_DIR/scripts/get_planets.py"
    [ ! -f "$planets_py" ] && planets_py="$PWD/scripts/get_planets.py"
    if [ -f "$planets_py" ] && command -v python3 >/dev/null 2>&1; then
        local loc="${WEATHER_LOCATION:-Swansea, UK}"
        python3 "$planets_py" --location "$loc" 2>/dev/null
    fi
}

manage_weather_menu() {
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}        METEOROLOGICAL & PLANETARY EPHEMERIS SETTINGS                 ${NC}"
        echo -e "${BOLD}${MAGENTA}======================================================================${NC}\n"
        local w_badge="${RED}DISABLED${NC}"
        [ "${WEATHER_ENABLED:-true}" = "true" ] && w_badge="${GREEN}ENABLED${NC}"
        local p_badge="${RED}DISABLED${NC}"
        [ "${PLANETS_ENABLED:-true}" = "true" ] && p_badge="${GREEN}ENABLED${NC}"

        echo -e "  • ${BOLD}Weather Banner Display:${NC}   ${w_badge}"
        echo -e "  • ${BOLD}Planets Banner Display:${NC}   ${p_badge}"
        echo -e "  • ${BOLD}Configured Location:${NC}      ${BOLD}${CYAN}${WEATHER_LOCATION:-Not Set}${NC}"

        local weather_sh="$SCRIPT_DIR/scripts/get_weather.sh"
        [ ! -f "$weather_sh" ] && weather_sh="$PWD/scripts/get_weather.sh"
        if [ -x "$weather_sh" ]; then
            local current_w
            current_w=$("$weather_sh" get 2>/dev/null)
            if [ -n "$current_w" ]; then
                echo -e "  • ${BOLD}Current Conditions:${NC}       ${WHITE}${current_w}${NC}"
            fi
        fi

        local planets_py="$SCRIPT_DIR/scripts/get_planets.py"
        [ ! -f "$planets_py" ] && planets_py="$PWD/scripts/get_planets.py"
        if [ -f "$planets_py" ] && command -v python3 >/dev/null 2>&1; then
            local current_p
            current_p=$(python3 "$planets_py" --location "${WEATHER_LOCATION:-Swansea, UK}" 2>/dev/null)
            if [ -n "$current_p" ]; then
                echo -e "  • ${BOLD}Planets Above Horizon:${NC}    ${current_p#*Planets: }"
            fi
        fi

        echo -e "  • ${BOLD}Config File:${NC}              ${DIM}${SCRIPT_DIR}/config.env${NC}\n"

        echo -e "${BOLD}Select an option:${NC}"
        echo -e "  ${BOLD}${CYAN} 1)${NC} Toggle Weather Display (${w_badge})"
        echo -e "  ${BOLD}${CYAN} 2)${NC} Toggle Planets Above Horizon Display (${p_badge})"
        echo -e "  ${BOLD}${CYAN} 3)${NC} Change / Update Observer Location (${BOLD}${WEATHER_LOCATION:-Swansea, UK}${NC})"
        echo -e "  ${BOLD}${CYAN} 4)${NC} Force Refresh Weather Now (Fetch live meteorological data)"
        echo -e "  ${BOLD}${CYAN} 5)${NC} View Full Planetary Ephemeris (All 7 Planets Altitude & Compass Heading)"
        echo -e "  ${BOLD}${CYAN} 6)${NC} Remove / Clear Location (Disables weather display)"
        echo -e "  ${BOLD}${CYAN} 0)${NC} Return to Previous Menu\n"
        read -r -p "Enter choice [0-6]: " w_choice

        case "$w_choice" in
            1)
                if [ "${WEATHER_ENABLED:-true}" = "true" ]; then
                    WEATHER_ENABLED="false"
                else
                    WEATHER_ENABLED="true"
                fi
                save_config_setting "WEATHER_ENABLED" "$WEATHER_ENABLED"
                echo -e "\n${GREEN}✓ Weather display set to '${WEATHER_ENABLED}' and saved to config.env!${NC}"
                sleep 1
                ;;
            2)
                if [ "${PLANETS_ENABLED:-true}" = "true" ]; then
                    PLANETS_ENABLED="false"
                else
                    PLANETS_ENABLED="true"
                fi
                save_config_setting "PLANETS_ENABLED" "$PLANETS_ENABLED"
                echo -e "\n${GREEN}✓ Planets display set to '${PLANETS_ENABLED}' and saved to config.env!${NC}"
                sleep 1
                ;;
            3)
                echo ""
                echo -e "Current Location: ${CYAN}${WEATHER_LOCATION:-Swansea, UK}${NC}"
                read -r -p "Enter new location (e.g. 'Swansea, UK', 'London, UK', 'Cardiff, UK'): " new_loc
                if [ -n "$new_loc" ]; then
                    WEATHER_LOCATION="$new_loc"
                    WEATHER_ENABLED="true"
                    save_config_setting "WEATHER_LOCATION" "$WEATHER_LOCATION"
                    save_config_setting "WEATHER_ENABLED" "true"
                    [ -x "$weather_sh" ] && "$weather_sh" clear >/dev/null 2>&1 || true
                    echo -e "\n${GREEN}✓ Observer location updated to '${WEATHER_LOCATION}'!${NC}"
                    sleep 1
                fi
                ;;
            4)
                echo ""
                if [ -x "$weather_sh" ]; then
                    "$weather_sh" refresh
                fi
                sleep 1.2
                ;;
            5)
                echo ""
                if [ -f "$planets_py" ] && command -v python3 >/dev/null 2>&1; then
                    python3 "$planets_py" --all --location "${WEATHER_LOCATION:-Swansea, UK}"
                fi
                echo ""
                read -r -p "Press Enter to return to settings..."
                ;;
            6)
                WEATHER_LOCATION=""
                WEATHER_ENABLED="false"
                save_config_setting "WEATHER_LOCATION" ""
                save_config_setting "WEATHER_ENABLED" "false"
                [ -x "$weather_sh" ] && "$weather_sh" clear >/dev/null 2>&1 || true
                echo -e "\n${YELLOW}✓ Observer location cleared and weather display disabled.${NC}"
                sleep 1.2
                ;;
            0|[qQ])
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_video_dispatcher() {
    local video_sh="$SCRIPT_DIR/scripts/launch_specific_video.sh"
    [ ! -f "$video_sh" ] && video_sh="$PWD/scripts/launch_specific_video.sh"
    if [ -x "$video_sh" ]; then
        "$video_sh"
    elif [ -f "$video_sh" ]; then
        bash "$video_sh"
    else
        launch_vlc
    fi
}

shop_for_new_music_menu() {
    local shop_sh="$SCRIPT_DIR/scripts/shop_music.sh"
    [ ! -f "$shop_sh" ] && shop_sh="$PWD/scripts/shop_music.sh"
    if [ -x "$shop_sh" ]; then
        "$shop_sh"
    elif [ -f "$shop_sh" ]; then
        bash "$shop_sh"
    else
        if command -v flatpak >/dev/null 2>&1 && flatpak list 2>/dev/null | grep -q "com.google.Chrome"; then
            flatpak run com.google.Chrome "https://www.beatport.com" "https://music.apple.com" "https://bandcamp.com" >/dev/null 2>&1 &
        else
            xdg-open "https://www.beatport.com" >/dev/null 2>&1 &
            sleep 0.2
            xdg-open "https://music.apple.com" >/dev/null 2>&1 &
            sleep 0.2
            xdg-open "https://bandcamp.com" >/dev/null 2>&1 &
        fi
    fi
}

manage_publishing_schedule() {
    echo -e "\n${BOLD}${BLUE}=== MIX PUBLISHING SCHEDULE & MULTI-PLATFORM SYNDICATION ===${NC}\n"
    if [ -x "$SCRIPT_DIR/publish_calendar_scheduler.sh" ]; then
        "$SCRIPT_DIR/publish_calendar_scheduler.sh"
    elif [ -x "./publish_calendar_scheduler.sh" ]; then
        ./publish_calendar_scheduler.sh
    elif command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/publish_calendar_scheduler.py" ]; then
        python3 "$SCRIPT_DIR/publish_calendar_scheduler.py"
    else
        echo -e "${RED}Error: publish_calendar_scheduler.sh not found!${NC}"
        press_enter
    fi
}

manage_playlists_menu() {
    echo -e "\n${BOLD}${BLUE}=== CUSTOM MIX PLAYLISTS SUITE (.M3U / .M3U8 / .XSPF) ===${NC}\n"
    if [ -x "$SCRIPT_DIR/manage_playlists.sh" ]; then
        "$SCRIPT_DIR/manage_playlists.sh"
    elif [ -x "./manage_playlists.sh" ]; then
        ./manage_playlists.sh
    elif command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/manage_playlists.py" ]; then
        python3 "$SCRIPT_DIR/manage_playlists.py"
    else
        echo -e "${RED}Error: manage_playlists.sh not found!${NC}"
        press_enter
    fi
}

inspect_audio_studio_menu() {
    echo -e "\n${BOLD}${BLUE}=== STUDIO HARDWARE & SOFTWARE INSPECTOR ===${NC}\n"
    if [ -x "$SCRIPT_DIR/inspect_audio_studio.sh" ]; then
        "$SCRIPT_DIR/inspect_audio_studio.sh"
    elif [ -x "./inspect_audio_studio.sh" ]; then
        ./inspect_audio_studio.sh
    elif command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/inspect_audio_studio.py" ]; then
        python3 "$SCRIPT_DIR/inspect_audio_studio.py"
    else
        echo -e "${RED}Error: inspect_audio_studio.sh not found!${NC}"
        press_enter
    fi
}

generate_ppm_cover_menu() {
    echo -e "\n${BOLD}${BLUE}=== PROCEDURAL GRADIENT .PPM COVER ART GENERATOR ===${NC}\n"
    if [ -x "$SCRIPT_DIR/generate_ppm_cover.sh" ]; then
        "$SCRIPT_DIR/generate_ppm_cover.sh"
    elif [ -x "./generate_ppm_cover.sh" ]; then
        ./generate_ppm_cover.sh
    elif command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/generate_ppm_cover.py" ]; then
        python3 "$SCRIPT_DIR/generate_ppm_cover.py"
    else
        echo -e "${RED}Error: generate_ppm_cover.sh not found!${NC}"
        press_enter
    fi
}

manage_sync_video_companion_menu() {
    echo -e "\n${BOLD}${BLUE}=== SYNCHRONIZED MIX-VIDEO COMPANION DAEMON ===${NC}\n"
    if [ -x "$SCRIPT_DIR/sync_video_companion.sh" ]; then
        "$SCRIPT_DIR/sync_video_companion.sh"
    elif [ -x "./sync_video_companion.sh" ]; then
        ./sync_video_companion.sh
    elif command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/sync_video_companion.py" ]; then
        python3 "$SCRIPT_DIR/sync_video_companion.py"
    else
        echo -e "${RED}Error: sync_video_companion.sh not found!${NC}"
        press_enter
    fi
}

manage_system_motd_menu() {
    echo -e "\n${BOLD}${BLUE}=== DYNAMIC SYSTEM MOTD BANNER MANAGER ===${NC}\n"
    if [ -x "$SCRIPT_DIR/update_system_motd.sh" ]; then
        "$SCRIPT_DIR/update_system_motd.sh"
    elif [ -x "./update_system_motd.sh" ]; then
        ./update_system_motd.sh
    elif command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/manage_motd.py" ]; then
        python3 "$SCRIPT_DIR/manage_motd.py"
    else
        echo -e "${RED}Error: update_system_motd.sh not found!${NC}"
        press_enter
    fi
}

get_os_badge() {
    if [ "$OS_TYPE" = "macos" ]; then
        local mac_ver
        mac_ver=$(sw_vers -productVersion 2>/dev/null || uname -r)
        echo -e "${BOLD}${CYAN}🍏 macOS:${NC} ${mac_ver} ($(uname -m))"
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        local win_ver=""
        if command -v cmd.exe >/dev/null 2>&1; then
            win_ver=$(cmd.exe /c ver 2>/dev/null | tr -d '\r\n' | sed 's/.*\[Version \([^]]*\)\].*/\1/')
        fi
        [ -z "$win_ver" ] && win_ver="$(uname -r)"
        if [ "$OS_TYPE" = "wsl" ]; then
            echo -e "${BOLD}${CYAN}🪟 Windows (WSL2):${NC} ${win_ver}"
        else
            echo -e "${BOLD}${CYAN}🪟 Windows:${NC} ${win_ver}"
        fi
    elif [ "$OS_TYPE" = "freebsd" ]; then
        local fbsd_ver
        fbsd_ver=$(uname -r)
        echo -e "${BOLD}${RED}😈 FreeBSD:${NC} ${fbsd_ver} ($(uname -m))"
    else
        local distro_name=""
        local distro_ver=""
        if [ -f /etc/os-release ]; then
            distro_name=$(grep -E '^NAME=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"')
            distro_ver=$(grep -E '^VERSION=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"')
        fi
        if [ -n "$distro_name" ]; then
            if echo "$distro_name" | grep -qi "linux"; then
                echo -e "${BOLD}${CYAN}🐧 OS:${NC} ${distro_name} ${distro_ver} (${BOLD}$(uname -r)${NC})"
            else
                echo -e "${BOLD}${CYAN}🐧 OS:${NC} ${distro_name} Linux ${distro_ver} (${BOLD}$(uname -r)${NC})"
            fi
        else
            echo -e "${BOLD}${CYAN}🐧 Kernel:${NC} $(uname -r)"
        fi
    fi
}

_LAST_OS_UPDATE_CHECK=0
_CACHED_OS_UPDATE_STATUS=""

get_os_update_status() {
    local now
    now=$(date +%s 2>/dev/null || echo 0)
    if [ $((now - _LAST_OS_UPDATE_CHECK)) -lt 60 ] && [ -n "$_CACHED_OS_UPDATE_STATUS" ]; then
        echo -e "$_CACHED_OS_UPDATE_STATUS"
        return 0
    fi

    local status=""
    if [ "$OS_TYPE" = "macos" ]; then
        local count=0
        if [ -f /Library/Preferences/com.apple.SoftwareUpdate.plist ]; then
            count=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist RecommendedUpdates 2>/dev/null | grep -c "Identifier =" 2>/dev/null || true)
            count="${count:-0}"
            if [ "$count" -eq 0 ]; then
                local last_avail
                last_avail=$(defaults read /Library/Preferences/com.apple.SoftwareUpdate.plist LastUpdatesAvailable 2>/dev/null || echo 0)
                [[ "$last_avail" =~ ^[0-9]+$ ]] && count="$last_avail"
            fi
        fi
        if [ "$count" -gt 0 ]; then
            status="${YELLOW}${count} pending${NC}"
        else
            status="${GREEN}Up to date${NC}"
        fi
    elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
        local win_reboot=""
        if command -v reg.exe >/dev/null 2>&1; then
            if reg.exe query "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired" >/dev/null 2>&1; then
                win_reboot="1"
            fi
        fi
        if [ -n "$win_reboot" ]; then
            status="${YELLOW}Restart pending${NC}"
        else
            status="${GREEN}Up to date${NC}"
        fi
    elif [ "$OS_TYPE" = "freebsd" ]; then
        status="${GREEN}Up to date${NC}"
    else
        # Linux (Bazzite / Silverblue / Fedora / Ubuntu / Debian / Arch)
        local ostree_staged=""
        if command -v rpm-ostree >/dev/null 2>&1; then
            if rpm-ostree status 2>/dev/null | grep -E -qi "(staged|upgrade available|staged: yes)"; then
                ostree_staged="1"
            fi
        fi
        if [ -n "$ostree_staged" ]; then
            status="${YELLOW}1 staged (reboot)${NC}"
        elif [ -f /var/run/reboot-required ]; then
            status="${YELLOW}Reboot required${NC}"
        elif [ -f /var/lib/update-notifier/updates-available ]; then
            local u_count
            u_count=$(grep -E "^[0-9]+ updates can be applied" /var/lib/update-notifier/updates-available 2>/dev/null | awk '{print $1}')
            if [ -n "$u_count" ] && [ "$u_count" -gt 0 ]; then
                status="${YELLOW}${u_count} pending${NC}"
            else
                status="${GREEN}Up to date${NC}"
            fi
        else
            if is_internet_connected; then
                status="${GREEN}Up to date${NC}"
            else
                status="${GREEN}Up to date${NC} ${DIM}(Offline)${NC}"
            fi
        fi
    fi

    _LAST_OS_UPDATE_CHECK="$now"
    _CACHED_OS_UPDATE_STATUS="$status"
    echo -e "$status"
}

_LAST_CLOUD_CHECK=0
_CACHED_CLOUD_STATUS=""

get_cloud_backup_badge() {
    local now
    now=$(date +%s 2>/dev/null || echo 0)
    if [ $((now - _LAST_CLOUD_CHECK)) -lt 30 ] && [ -n "$_CACHED_CLOUD_STATUS" ]; then
        echo -e "$_CACHED_CLOUD_STATUS"
        return 0
    fi

    if ! is_internet_connected; then
        _CACHED_CLOUD_STATUS="${BOLD}${CYAN}☁️  Cloud Backup:${NC} ${BOLD}${YELLOW}Offline (No Internet Connection)${NC}  ${BOLD}${BLUE}│${NC}  ${DIM}Cloud sync paused (Option 9 when online)${NC}"
        _LAST_CLOUD_CHECK="$now"
        echo -e "$_CACHED_CLOUD_STATUS"
        return 0
    fi

    local state_file="$HOME/.config/mix-manager/cloud_backup_state.json"
    local backup_time=0
    local backup_date=""
    local backup_provider=""

    if [ -f "$state_file" ]; then
        backup_time=$(grep -o '"timestamp": [0-9]*' "$state_file" 2>/dev/null | head -1 | awk '{print $2}')
        backup_date=$(grep -o '"date": "[^"]*"' "$state_file" 2>/dev/null | head -1 | cut -d'"' -f4)
        backup_provider=$(grep -o '"provider": "[^"]*"' "$state_file" 2>/dev/null | head -1 | cut -d'"' -f4)
    fi

    if [ -z "$backup_date" ]; then
        local latest_log
        latest_log=$(ls -t "$SCRIPT_DIR/BACKUP_LOGS"/backup_*.log 2>/dev/null | head -1)
        if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
            backup_time=$(stat -c %Y "$latest_log" 2>/dev/null || stat -f %m "$latest_log" 2>/dev/null || echo 0)
            backup_date=$(date -d "@$backup_time" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$backup_time" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Recently")
            if [[ "$latest_log" =~ backup_([a-z0-9]+)_ ]]; then
                backup_provider="${BASH_REMATCH[1]^^}"
            fi
        fi
    fi

    if [ -z "$backup_provider" ]; then
        backup_provider="Google Drive"
    fi

    if [ -z "$backup_date" ] || [ "${backup_time:-0}" -eq 0 ]; then
        _CACHED_CLOUD_STATUS="${BOLD}${CYAN}☁️  Cloud Backup:${NC} ${BOLD}${YELLOW}No backup recorded${NC} ${DIM}(Option 9 to sync)${NC}"
        _LAST_CLOUD_CHECK="$now"
        echo -e "$_CACHED_CLOUD_STATUS"
        return 0
    fi

    local pending_count=0
    local all_fdirs=()
    while IFS= read -r fd; do
        [ -n "$fd" ] && [ -d "$fd" ] || continue
        # Exclude remote cloud mounts (like Google Drive) from being counted as pending backup targets
        case "$fd" in
            *GoogleDrive*|*google-drive*|*rclone*) continue ;;
        esac
        all_fdirs+=("$fd")
    done < <(get_all_flac_output_dirs 2>/dev/null)

    if [ ${#all_fdirs[@]} -gt 0 ]; then
        local f_str
        f_str="$(printf "%s\n" "${all_fdirs[@]}")"
        pending_count=$(python3 - "$backup_time" "$f_str" << 'PY' 2>/dev/null || echo 0
import os, sys
try:
    btime = float(sys.argv[1])
    dirs = [d for d in sys.argv[2].splitlines() if d and os.path.isdir(d)]
    pending = 0
    for d in dirs:
        with os.scandir(d) as it:
            for entry in it:
                if entry.name.lower().endswith('.flac') and entry.is_file():
                    if entry.stat().st_mtime > btime:
                        pending += 1
    print(pending)
except Exception:
    print(0)
PY
)
    fi

    if [ "$pending_count" -eq 0 ]; then
        _CACHED_CLOUD_STATUS="${BOLD}${CYAN}☁️  Cloud Backup (${backup_provider}):${NC} ${BOLD}${GREEN}Up-to-date${NC} ${DIM}(Last: ${backup_date})${NC}  ${BOLD}${BLUE}│${NC}  ${BOLD}${GREEN}0 pending${NC}"
    else
        _CACHED_CLOUD_STATUS="${BOLD}${CYAN}☁️  Cloud Backup (${backup_provider}):${NC} ${BOLD}${YELLOW}${pending_count} mix(es) pending sync${NC}  ${BOLD}${BLUE}│${NC}  ${DIM}Last: ${backup_date}${NC}"
    fi

    _LAST_CLOUD_CHECK="$now"
    echo -e "$_CACHED_CLOUD_STATUS"
}

# Direct CLI invocation support for manager update & version commands
if [ "$1" = "update" ] || [ "$1" = "--update" ]; then
    shift
    run_sub_script "update_manager.sh" "$@"
    exit $?
elif [ "$1" = "version" ] || [ "$1" = "--version" ] || [ "$1" = "-v" ]; then
    shift
    run_sub_script "update_manager.sh" --version "$@"
    exit $?
# Direct CLI invocation support for WAN2GP server management (e.g. Menu 56 options)
elif [ "$1" = "--wan2gp-start-4.5" ] || [ "$1" = "--wan2gp-p45" ] || { [ "$1" = "56" ] && [ "$2" = "2" ]; }; then
    wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
    if [ -n "$wgp_pids" ]; then
        echo -e "\n${YELLOW}WAN2GP is already running (PID: ${wgp_pids% }). Stop or restart it first.${NC}"
        exit 0
    fi
    echo -e "\n${YELLOW}Launching WAN2GP in Profile 4.5...${NC}"
    launch_wan2gp_terminal "4.5"
    exit 0
elif [ "$1" = "--wan2gp-start" ] || [ "$1" = "--wan2gp" ]; then
    profile="${2:-4.5}"
    wgp_pids=$(pgrep -f "python.*wgp\.py" | tr '\n' ' ')
    if [ -n "$wgp_pids" ]; then
        echo -e "\n${YELLOW}WAN2GP is already running (PID: ${wgp_pids% }). Stop or restart it first.${NC}"
        exit 0
    fi
    echo -e "\n${YELLOW}Launching WAN2GP in Profile $profile...${NC}"
    launch_wan2gp_terminal "$profile"
    exit 0
elif [ "$1" = "--wan2gp-stop" ] || { [ "$1" = "56" ] && [ "$2" = "3" ]; }; then
    echo -e "\n${YELLOW}Stopping WAN2GP...${NC}"
    run_sub_script "wan2gp.sh" stop
    exit 0
elif [ "$1" = "--split-flac" ] || [ "$1" = "--flac-split" ]; then
    shift
    split_flac_audio "$@"
    exit 0
elif [ "$1" = "--split-video" ] || [ "$1" = "--split-mp4" ] || [ "$1" = "--video-split" ]; then
    shift
    split_video_clip "$@"
    exit 0
elif [ "$1" = "--cut-video" ]; then
    shift
    cut_video_clip "$@"
    exit 0
elif [ "$1" = "--beszel" ] || [ "$1" = "--beszel-menu" ]; then
    shift
    manage_beszel "$@"
    exit 0
elif [ "$1" = "--beszel-start" ] || [ "$1" = "--beszel-start-both" ] || { [ "$1" = "57" ] && [ "$2" = "1" ]; }; then
    run_sub_script "beszel.sh" start
    exit 0
elif [ "$1" = "--beszel-hub" ] || [ "$1" = "--beszel-start-hub" ] || { [ "$1" = "57" ] && [ "$2" = "2" ]; }; then
    run_sub_script "beszel.sh" start-hub
    exit 0
elif [ "$1" = "--beszel-agent" ] || [ "$1" = "--beszel-start-agent" ] || { [ "$1" = "57" ] && [ "$2" = "3" ]; }; then
    run_sub_script "beszel.sh" start-agent
    exit 0
elif [ "$1" = "--beszel-dashboard" ] || [ "$1" = "--beszel-web" ] || { [ "$1" = "57" ] && [ "$2" = "4" ]; }; then
    run_sub_script "beszel.sh" dashboard
    exit 0
elif [ "$1" = "--beszel-stop" ] || { [ "$1" = "57" ] && [ "$2" = "5" ]; }; then
    run_sub_script "beszel.sh" stop
    exit 0
elif [ "$1" = "--beszel-status" ] || { [ "$1" = "57" ] && [ "$2" = "status" ]; }; then
    run_sub_script "beszel.sh" status
    exit 0
elif [ "$1" = "57" ] && [ -z "$2" ]; then
    manage_beszel
    exit 0
elif [ "$1" = "--ollama" ] || [ "$1" = "--ollama-menu" ]; then
    shift
    manage_ollama "$@"
    exit 0
elif [ "$1" = "--ollama-serve" ] || [ "$1" = "--ollama-start" ] || [ "$1" = "--ollama-bg" ] || { [ "$1" = "58" ] && [ "$2" = "1" ]; }; then
    run_sub_script "manage_ollama.sh" start
    exit 0
elif [ "$1" = "--ollama-window" ] || [ "$1" = "--ollama-term" ] || { [ "$1" = "58" ] && [ "$2" = "2" ]; }; then
    run_sub_script "manage_ollama.sh" start-window
    exit 0
elif [ "$1" = "--ollama-stop" ] || { [ "$1" = "58" ] && [ "$2" = "3" ]; }; then
    run_sub_script "manage_ollama.sh" stop
    exit 0
elif [ "$1" = "--ollama-restart" ] || { [ "$1" = "58" ] && [ "$2" = "4" ]; }; then
    run_sub_script "manage_ollama.sh" restart
    exit 0
elif [ "$1" = "--ollama-chat" ] || { [ "$1" = "58" ] && [ "$2" = "5" ]; }; then
    shift 2 2>/dev/null || shift 1
    run_sub_script "manage_ollama.sh" chat "$@"
    exit 0
elif [ "$1" = "--ollama-logs" ] || { [ "$1" = "58" ] && [ "$2" = "6" ]; }; then
    run_sub_script "manage_ollama.sh" logs
    exit 0
elif [ "$1" = "--ollama-status" ] || { [ "$1" = "58" ] && [ "$2" = "status" ]; }; then
    run_sub_script "manage_ollama.sh" status
    exit 0
elif [ "$1" = "58" ] && [ -z "$2" ]; then
    manage_ollama
    exit 0
elif [ "$1" = "--dsh-mobile" ] || [ "$1" = "--dsh" ] || [ "$1" = "--dsh-start" ] || { [ "$1" = "59" ] && [ "$2" = "1" ]; }; then
    run_sub_script "dsh_mobile.sh" start
    exit 0
elif [ "$1" = "--dsh-bg" ] || { [ "$1" = "59" ] && [ "$2" = "2" ]; }; then
    run_sub_script "dsh_mobile.sh" start-bg
    exit 0
elif [ "$1" = "--dsh-web" ] || [ "$1" = "--dsh-browser" ] || { [ "$1" = "59" ] && [ "$2" = "3" ]; }; then
    run_sub_script "dsh_mobile.sh" web
    exit 0
elif [ "$1" = "--dsh-stop" ] || { [ "$1" = "59" ] && [ "$2" = "4" ]; }; then
    run_sub_script "dsh_mobile.sh" stop
    exit 0
elif [ "$1" = "--dsh-restart" ] || { [ "$1" = "59" ] && [ "$2" = "5" ]; }; then
    run_sub_script "dsh_mobile.sh" restart
    exit 0
elif [ "$1" = "--dsh-logs" ] || { [ "$1" = "59" ] && [ "$2" = "6" ]; }; then
    run_sub_script "dsh_mobile.sh" logs
    exit 0
elif [ "$1" = "--dsh-status" ] || { [ "$1" = "59" ] && [ "$2" = "status" ]; }; then
    run_sub_script "dsh_mobile.sh" status
    exit 0
elif [ "$1" = "--dsh-menu" ] || { [ "$1" = "59" ] && [ -z "$2" ]; }; then
    manage_dsh_mobile
    exit 0
elif [ "$1" = "--backup" ] || [ "$1" = "--cloud-backup" ] || { [ "$1" = "9" ] && [ -z "${2:-}" ]; }; then
    shift || true
    run_sub_script "backup_mix_archive.sh" "$@"
    exit 0
elif [ "$1" = "--alarm" ] || [ "$1" = "--alarm-clock" ] || [ "$1" = "alarm" ] || [ "$1" = "alarm-clock" ] || { [ "$1" = "18" ] && [ -n "${2:-}" ]; }; then
    shift || true
    if [ -x "$SCRIPT_DIR/mplanetarians-alarm-clock/alarm.sh" ]; then
        exec "$SCRIPT_DIR/mplanetarians-alarm-clock/alarm.sh" "$@"
    elif [ -x "$SCRIPT_DIR/alarm.sh" ]; then
        exec "$SCRIPT_DIR/alarm.sh" "$@"
    else
        exec ./alarm.sh "$@"
    fi
elif [ "$1" = "--congen" ] || [ "$1" = "congen" ] || [ "$1" = "kdeconnect" ] || [ "$1" = "--kdeconnect" ]; then
    shift || true
    if [ -x "$SCRIPT_DIR/Congen/Congen" ]; then
        exec "$SCRIPT_DIR/Congen/Congen" "$@"
    elif [ -x "$SCRIPT_DIR/congen" ]; then
        exec "$SCRIPT_DIR/congen" "$@"
    else
        exec ./congen "$@"
    fi
fi

manage_cloud_backup_suite() {
    run_sub_script "backup_mix_archive.sh"
}

manage_integrity_and_verification() {
    while true; do
        local opts=(
            "1|Manage Audio Integrity Checksums|(SHA-256 Manifest & Verification)"
            "2|Verify FLAC Files for Integrity & Corruption|(Verify_FLAC_Files.sh)"
            "3|Lossless Legitimacy & Spectral Cutoff Inspector|(Detect Fake FLACs / MP3 Transcodes)"
            "4|Run Non-Destructive Bit-Rot Scrub on All Mix Archives|(scrub_mix_archive.sh)"
            "5|Automated Background Bit-Rot Scrub Timer|(Systemd User Timer)"
            "6|View Bit-Rot Scrub History & Logs|(VERIFY_LOGS)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "AUDIO INTEGRITY, BIT-ROT SCRUB & FLAC VERIFICATION" "" opts 0
        local aiv_choice="$REPLY"
        case "$aiv_choice" in
            1)
                manage_audio_checksums
                ;;
            2)
                echo -e "\n${BOLD}${YELLOW}Starting FLAC File Integrity Scan...${NC}\n"
                run_sub_script "Verify_FLAC_Files.sh"
                press_enter
                ;;
            3)
                if [ -f "$SCRIPT_DIR/scripts/verify_lossless_spectral.py" ]; then
                    python3 "$SCRIPT_DIR/scripts/verify_lossless_spectral.py"
                else
                    echo -e "\n${RED}Error: verify_lossless_spectral.py not found!${NC}"
                fi
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${YELLOW}Starting Non-Destructive Bit-Rot Scrub across all archives...${NC}\n"
                run_sub_script "scrub_mix_archive.sh"
                press_enter
                ;;
            5)
                echo -e "\n${BOLD}${MAGENTA}--- Automated Background Bit-Rot Scrub Timer (Systemd) ---${NC}"
                run_sub_script "scrub_mix_archive.sh" --timer-status
                local t_opts=(
                    "1|Install & Enable Weekly Scrub Timer|(Sundays 03:00 AM)"
                    "2|Disable & Uninstall Scrub Timer|"
                    "0|Back|(or Esc)"
                )
                run_interactive_submenu "Automated Bit-Rot Scrub Timer" "" t_opts 0
                local t_choice="$REPLY"
                case "$t_choice" in
                    1) run_sub_script "scrub_mix_archive.sh" --install-timer ;;
                    2) run_sub_script "scrub_mix_archive.sh" --uninstall-timer ;;
                esac
                press_enter
                ;;
            6)
                run_sub_script "scrub_mix_archive.sh" --logs
                press_enter
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_storage_and_archive_config() {
    while true; do
        local archive_disp=""
        if is_mix_archive_configured; then
            archive_disp="${GREEN}${MIX_ARCHIVE_DIR}${NC}"
        else
            archive_disp="${RED}Not Configured${NC} ${DIM}(Root: ${SCRIPT_DIR}/MIX_ARCHIVE)${NC}"
        fi
        local extra_disp=""
        if [ -n "${EXTRA_MIX_ARCHIVE_DIRS:-}" ]; then
            extra_disp="\n  Extra Archives  : ${CYAN}${EXTRA_MIX_ARCHIVE_DIRS}${NC}"
        fi
        local stg_hdr="  Primary Archive : ${archive_disp}${extra_disp}\n"
        local opts=(
            "1|Show Mix Storage Drive Space Remaining|(All Configured Mix Drives)"
            "2|Show All Attached Drives Space Remaining|(Get_All_Drive_Space.sh)"
            "3|Refresh Archive Status & File Counts|(Rescan WAVs, FLACs & Tracklists)"
            "4|Configure Mix Archive Storage Locations|(Option 13: Primary & Multiple Folders)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "STORAGE MANAGEMENT & ARCHIVE CONFIGURATION" "$stg_hdr" opts 0
        local stg_choice="$REPLY"
        case "$stg_choice" in
            1)
                show_mix_drive_space
                ;;
            2)
                echo -e "\n${BOLD}${YELLOW}Scanning Drive Space Across Attached Storage...${NC}\n"
                run_sub_script "Get_All_Drive_Space.sh"
                press_enter
                ;;
            3)
                _LAST_OS_UPDATE_CHECK=0
                return 0
                ;;
            4|13)
                configure_mix_archive_folder
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_tracklist_suite() {
    while true; do
        local opts=(
            "1|Tracklist Management Suite|(Browse, Search, View, Export HTML & PDF)"
            "2|Search for Mix & Auto-Play with Live Tracklist View|(cliamp Window)"
            "3|Scan & Generate Missing Tracklists|(Check_Find_Tracklists.sh)"
            "4|Generate Master Tracklist HTML Index|(Generate_Master_Tracklist.sh)"
            "5|Launch MusicBrainz Picard Meta Tag Editor|(Auto-install if missing)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "TRACKLIST MANAGEMENT, SCANNING & METADATA SUITE" "" opts 0
        local tl_choice="$REPLY"
        case "$tl_choice" in
            1)
                manage_tracklists
                ;;
            2)
                search_and_play_mix
                ;;
            3)
                echo -e "\n${BOLD}${YELLOW}Scanning & Generating Missing Tracklists...${NC}\n"
                run_sub_script "Check_Find_Tracklists.sh"
                press_enter
                ;;
            4)
                echo -e "\n${BOLD}${YELLOW}Starting Master Tracklist HTML Generation...${NC}\n"
                if [ -f "$SCRIPT_DIR/Generate_Master_Tracklist.sh" ]; then
                    bash "$SCRIPT_DIR/Generate_Master_Tracklist.sh"
                else
                    run_sub_script "Generate_Master_Tracklist.sh"
                fi
                press_enter
                ;;
            5)
                launch_or_install_picard
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

generate_archive_folder_playlists_menu() {
    ensure_playlists_generated_dirs
    local py_script="$SCRIPT_DIR/scripts/generate_archive_folder_playlists.py"
    if [ ! -f "$py_script" ]; then
        py_script="$SCRIPT_DIR/generate_archive_folder_playlists.py"
    fi
    if [ -f "$py_script" ]; then
        python3 "$py_script"
    else
        echo -e "${RED}Error: generate_archive_folder_playlists.py not found!${NC}"
        press_enter
    fi
}

manage_playlists_and_history() {
    while true; do
        local t_ver
        t_ver="$(get_traktor_version_mac 2>/dev/null | tr -d '\r\n')"
        t_ver="${t_ver:-3}"
        local tr_lbl="Generate Playlist from History Files on Traktor 3"
        [ -n "$t_ver" ] && [ "$t_ver" != "3" ] && tr_lbl="Generate Playlist from History Files on Traktor ${t_ver}"
        local opts=(
            "1|Custom Mix Playlists Suite|(.m3u / .m3u8 / .xspf - Create, Edit & Launch)"
            "2|Generate Mix Archive Folder Playlists|(.m3u / .m3u8 / .xspf ➔ PLAYLISTS_GENERATED)"
            "3|${tr_lbl}|(Key Sorted / Decks Ready)"
            "4|Listen to Your Top 5 Tracks Right Now|$(get_top_5_status_badge)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "CUSTOM PLAYLISTS & TRAKTOR HISTORY SUITE" "" opts 0
        local ph_choice="$REPLY"
        case "$ph_choice" in
            1)
                manage_playlists_menu
                ;;
            2)
                generate_archive_folder_playlists_menu
                ;;
            3)
                generate_traktor_playlist_from_history
                ;;
            4|top5|top-5|top|special)
                manage_top_5_tracks
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

get_top_5_status_badge() {
    local py_script="$SCRIPT_DIR/scripts/top_5_tracks_manager.py"
    [ ! -f "$py_script" ] && py_script="$SCRIPT_DIR/top_5_tracks_manager.py"
    if [ -f "$py_script" ]; then
        python3 "$py_script" --badge 2>/dev/null || echo -e "${YELLOW}[Unlock Mystery / Ready]${NC}"
    else
        echo -e "${YELLOW}[Unlock Mystery / Ready]${NC}"
    fi
}

manage_top_5_tracks() {
    local py_script="$SCRIPT_DIR/scripts/top_5_tracks_manager.py"
    [ ! -f "$py_script" ] && py_script="$SCRIPT_DIR/top_5_tracks_manager.py"
    if [ -f "$py_script" ]; then
        python3 "$py_script"
    elif [ -x "$SCRIPT_DIR/scripts/manage_top_5_tracks.sh" ]; then
        bash "$SCRIPT_DIR/scripts/manage_top_5_tracks.sh"
    elif [ -x "$SCRIPT_DIR/manage_top_5_tracks.sh" ]; then
        bash "$SCRIPT_DIR/manage_top_5_tracks.sh"
    else
        echo -e "\n${RED}Error: top_5_tracks_manager.py was not found in scripts/!${NC}\n"
        press_enter
    fi
}


manage_daws_suite() {
    while true; do
        local opts=(
            "1|Digital Audio Workstations (DAWs) Menu|(Reaper, Logic Pro, FL Studio, Traktor, Ardour, Bitwig...)"
            "2|Open Mix WAV/FLAC Audio File in DAW|(Direct Mix Search/Select & Dispatch)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "DIGITAL AUDIO WORKSTATIONS (DAWS) SUITE" "" opts 0
        local daw_choice="$REPLY"
        case "$daw_choice" in
            1)
                manage_daws
                ;;
            2)
                open_mix_in_daw
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_studio_hardware_and_volume() {
    while true; do
        local opts=(
            "1|Studio Hardware & Software Inspector|(PipeWire, ALSA, DAWs, MIDI Controllers & Surfaces)"
            "2|Toggle Audio Mute / Unmute & Master Volume Control|(Instant PipeWire/ALSA Mute)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "STUDIO HARDWARE, INTERFACES & VOLUME CONTROL" "" opts 0
        local shv_choice="$REPLY"
        case "$shv_choice" in
            1)
                inspect_audio_studio_menu
                ;;
            2)
                toggle_audio_mute
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ─── [ RUN ANY DESKTOP SHORTCUTS - LINUX (MANUAL MODE) ] ─────────────────────
manage_desktop_shortcuts() {
    while true; do
        local opts=(
            "1|Run Any Desktop Shortcut Manually|(Games, Audio, Files, Tools, AI Servers)"
            "2|Generate Keyboard Shortcut for a Desktop Shortcut|(e.g. Ctrl+Alt+Enter)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "RUN ANY DESKTOP SHORTCUTS — LINUX (KDE Plasma)" "  Launch and automate Desktop Shortcuts on KDE Plasma (Linux).\n" opts 0
        local dsk_top_choice="$REPLY"
        case "$dsk_top_choice" in
            1)
                _run_desktop_shortcut_manual
                ;;
            2)
                _bind_desktop_shortcut_keyboard
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ─── Internal helper: parse and launch a desktop shortcut ────────────────────
_run_desktop_shortcut_manual() {
    # ── Collect .desktop file paths from Desktop & local applications ──────
    local -a desktop_paths=()
    local -a search_dirs=(
        "$HOME/Desktop/DESKTOP"
        "$HOME/Desktop"
        "$HOME/.local/share/applications"
    )

    for _dir in "${search_dirs[@]}"; do
        if [ -d "$_dir" ]; then
            while IFS= read -r -d '' _f; do
                desktop_paths+=("$_f")
            done < <(find "$_dir" -maxdepth 1 -name "*.desktop" -print0 2>/dev/null | sort -z)
        fi
    done

    if [ ${#desktop_paths[@]} -eq 0 ]; then
        echo -e "\n${RED}No .desktop shortcuts found in standard locations.${NC}"
        echo -e "${DIM}Searched: ${search_dirs[*]}${NC}"
        press_enter
        return 0
    fi

    # ── Parse each file and build display arrays ───────────────────────────
    local -a shortcut_names=()
    local -a shortcut_files=()
    local -a shortcut_comments=()
    local -a shortcut_categories=()

    for _f in "${desktop_paths[@]}"; do
        local _name="" _comment="" _cats="" _type=""
        _name="$(grep -m1 '^Name=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        _comment="$(grep -m1 '^Comment=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        _cats="$(grep -m1 '^Categories=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        _type="$(grep -m1 '^Type=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        # Skip non-Application entries (e.g. Directory, Link)
        [ -z "$_type" ] || [ "$_type" = "Application" ] || continue
        [ -z "$_name" ] && _name="$(basename "$_f" .desktop)"
        shortcut_names+=("$_name")
        shortcut_files+=("$_f")
        shortcut_comments+=("$_comment")
        shortcut_categories+=("$_cats")
    done

    if [ ${#shortcut_names[@]} -eq 0 ]; then
        echo -e "\n${RED}No valid Application .desktop shortcuts found.${NC}"
        press_enter
        return 0
    fi

    # ── Category emoji helper ──────────────────────────────────────────────
    _cat_emoji() {
        local cats="$1"
        case "$cats" in
            *Game*)                      echo "🎮" ;;
            *AudioVideo*|*Audio*|*Music*) echo "🎵" ;;
            *AI*)                        echo "🤖" ;;
            *Development*)               echo "🛠️ " ;;
            *Network*)                   echo "🌐" ;;
            *System*|*Settings*)         echo "⚙️ " ;;
            *Graphics*|*Screensaver*)    echo "🎨" ;;
            *Utility*)                   echo "🔧" ;;
            *)                           echo "📌" ;;
        esac
    }

    # ── Display the shortcut list ──────────────────────────────────────────
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}   🖥️  RUN ANY DESKTOP SHORTCUT MANUALLY — KDE Plasma (kioclient)     ${NC}"
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo -e "  ${DIM}All available Desktop Shortcuts are listed below.${NC}"
        echo -e "  ${DIM}Select a number to launch the shortcut. Press 0 to go back.${NC}"
        echo ""

        local _i=1
        local idx
        for (( idx=0; idx<${#shortcut_names[@]}; idx++ )); do
            local _name="${shortcut_names[$idx]}"
            local _comment="${shortcut_comments[$idx]}"
            local _cats="${shortcut_categories[$idx]}"
            local _emoji
            _emoji="$(_cat_emoji "$_cats")"

            # Right-pad index for alignment
            local _idx_str
            printf -v _idx_str "%3d" "$_i"

            if [ -n "$_comment" ]; then
                echo -e "  ${BOLD}${CYAN}${_idx_str})${NC} ${_emoji} ${BOLD}${_name}${NC}"
                echo -e "       ${DIM}${_comment}${NC}"
            else
                echo -e "  ${BOLD}${CYAN}${_idx_str})${NC} ${_emoji} ${BOLD}${_name}${NC}"
            fi
            _i=$(( _i + 1 ))
        done

        echo ""
        echo -e "  ${BOLD}${CYAN}  0)${NC} Return to Desktop Shortcuts Menu"
        echo ""
        read -r -p "Enter shortcut number to launch [0-$(( ${#shortcut_names[@]} ))]: " sc_choice

        if [[ "$sc_choice" == "0" ]] || [[ "$sc_choice" =~ ^[qQ]$ ]]; then
            return 0
        fi

        # Validate numeric selection
        if ! [[ "$sc_choice" =~ ^[0-9]+$ ]] || \
           [ "$sc_choice" -lt 1 ] || [ "$sc_choice" -gt "${#shortcut_names[@]}" ]; then
            echo -e "\n${RED}Invalid selection — please enter a number between 1 and ${#shortcut_names[@]}.${NC}"
            sleep 1.5
            continue
        fi

        local _sel_idx=$(( sc_choice - 1 ))
        local _sel_name="${shortcut_names[$_sel_idx]}"
        local _sel_file="${shortcut_files[$_sel_idx]}"

        echo ""
        echo -e "${BOLD}${YELLOW}▶  Launching: ${GREEN}${_sel_name}${NC}"
        echo -e "   ${DIM}File: ${_sel_file}${NC}"
        echo -e "   ${DIM}Command: kioclient exec \"${_sel_file}\"${NC}"
        echo ""

        # Check kioclient is available
        local _kioclient
        if command -v kioclient >/dev/null 2>&1; then
            _kioclient="kioclient"
        elif command -v kioclient5 >/dev/null 2>&1; then
            _kioclient="kioclient5"
        elif command -v kioclient6 >/dev/null 2>&1; then
            _kioclient="kioclient6"
        else
            echo -e "${RED}Error: kioclient is not installed. Cannot launch desktop shortcut.${NC}"
            echo -e "${DIM}Install it via: sudo dnf install kio-extras  OR  sudo apt install kio${NC}"
            press_enter
            continue
        fi

        # Launch the shortcut in background (detached)
        "$_kioclient" exec "$_sel_file" >/dev/null 2>&1 &
        disown

        echo -e "${GREEN}✔  Shortcut launched successfully!${NC}"
        echo -e "${DIM}The application is opening. When you are done, return here to launch another.${NC}"
        echo ""
        press_enter
        # Loop back to the list so the user can launch another shortcut
    done
}
# ─────────────────────────────────────────────────────────────────────────────

# ─── Bind a Desktop Shortcut to a Global Keyboard Shortcut (KDE Plasma) ───────
_bind_desktop_shortcut_keyboard() {
    # ── Step 1: collect & parse desktop files (reuse same logic as _run_desktop_shortcut_manual)
    local -a desktop_paths=()
    local -a search_dirs=(
        "$HOME/Desktop/DESKTOP"
        "$HOME/Desktop"
        "$HOME/.local/share/applications"
    )
    for _dir in "${search_dirs[@]}"; do
        [ -d "$_dir" ] || continue
        while IFS= read -r -d '' _f; do
            desktop_paths+=("$_f")
        done < <(find "$_dir" -maxdepth 1 -name "*.desktop" -print0 2>/dev/null | sort -z)
    done

    local -a shortcut_names=()
    local -a shortcut_files=()
    local -a shortcut_comments=()
    local -a shortcut_categories=()
    local -a shortcut_existing_keys=()   # any existing X-KDE-Shortcuts value

    for _f in "${desktop_paths[@]}"; do
        local _name="" _comment="" _cats="" _type="" _existing_key=""
        _name="$(grep -m1 '^Name=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        _comment="$(grep -m1 '^Comment=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        _cats="$(grep -m1 '^Categories=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        _type="$(grep -m1 '^Type=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        _existing_key="$(grep -m1 '^X-KDE-Shortcuts=' "$_f" 2>/dev/null | cut -d'=' -f2-)"
        [ -z "$_type" ] || [ "$_type" = "Application" ] || continue
        [ -z "$_name" ] && _name="$(basename "$_f" .desktop)"
        shortcut_names+=("$_name")
        shortcut_files+=("$_f")
        shortcut_comments+=("$_comment")
        shortcut_categories+=("$_cats")
        shortcut_existing_keys+=("$_existing_key")
    done

    if [ ${#shortcut_names[@]} -eq 0 ]; then
        echo -e "\n${RED}No valid Application .desktop shortcuts found.${NC}"
        press_enter; return 0
    fi

    _cat_emoji_bind() {
        local cats="$1"
        case "$cats" in
            *Game*)                       echo "🎮" ;;
            *AudioVideo*|*Audio*|*Music*) echo "🎵" ;;
            *AI*)                         echo "🤖" ;;
            *Development*)                echo "🛠️ " ;;
            *Network*)                    echo "🌐" ;;
            *System*|*Settings*)          echo "⚙️ " ;;
            *Graphics*|*Screensaver*)     echo "🎨" ;;
            *Utility*)                    echo "🔧" ;;
            *)                            echo "📌" ;;
        esac
    }

    # ── Step 2: display shortcut list ─────────────────────────────────────────
    while true; do
        clear
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}   ⌨️  GENERATE KEYBOARD SHORTCUT FOR DESKTOP SHORTCUT (KDE Plasma)    ${NC}"
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo -e "  ${DIM}Select a Desktop Shortcut and assign a global keyboard shortcut.${NC}"
        echo -e "  ${DIM}The shortcut will be registered in KDE Plasma and fire instantly.${NC}"
        echo ""

        local _i=1
        local idx
        for (( idx=0; idx<${#shortcut_names[@]}; idx++ )); do
            local _emoji
            _emoji="$(_cat_emoji_bind "${shortcut_categories[$idx]}")"
            local _idx_str
            printf -v _idx_str "%3d" "$_i"
            local _existing="${shortcut_existing_keys[$idx]}"
            local _key_badge=""
            [ -n "$_existing" ] && _key_badge=" ${CYAN}[${_existing}]${NC}"
            if [ -n "${shortcut_comments[$idx]}" ]; then
                echo -e "  ${BOLD}${CYAN}${_idx_str})${NC} ${_emoji} ${BOLD}${shortcut_names[$idx]}${NC}${_key_badge}"
                echo -e "       ${DIM}${shortcut_comments[$idx]}${NC}"
            else
                echo -e "  ${BOLD}${CYAN}${_idx_str})${NC} ${_emoji} ${BOLD}${shortcut_names[$idx]}${NC}${_key_badge}"
            fi
            _i=$(( _i + 1 ))
        done

        echo ""
        echo -e "  ${BOLD}${CYAN}  0)${NC} Return to Desktop Shortcuts Menu"
        echo ""
        read -r -p "Enter shortcut number to bind [0-$(( ${#shortcut_names[@]} ))]: " sc_choice

        [[ "$sc_choice" == "0" ]] || [[ "$sc_choice" =~ ^[qQ]$ ]] && return 0

        if ! [[ "$sc_choice" =~ ^[0-9]+$ ]] || \
           [ "$sc_choice" -lt 1 ] || [ "$sc_choice" -gt "${#shortcut_names[@]}" ]; then
            echo -e "\n${RED}Invalid selection.${NC}"; sleep 1.5; continue
        fi

        local _sel_idx=$(( sc_choice - 1 ))
        local _sel_name="${shortcut_names[$_sel_idx]}"
        local _sel_file="${shortcut_files[$_sel_idx]}"
        local _sel_comment="${shortcut_comments[$_sel_idx]}"
        local _existing_shortcut="${shortcut_existing_keys[$_sel_idx]}"

        # ── Step 3: Keyboard shortcut input ───────────────────────────────────
        clear
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo -e "${BOLD}${MAGENTA}   ⌨️  ASSIGN KEYBOARD SHORTCUT — ${_sel_name}${NC}"
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo ""
        echo -e "  ${BOLD}Selected shortcut:${NC} ${GREEN}${_sel_name}${NC}"
        [ -n "$_sel_comment" ] && echo -e "  ${DIM}${_sel_comment}${NC}"
        echo -e "  ${DIM}File: ${_sel_file}${NC}"
        echo ""
        if [ -n "$_existing_shortcut" ]; then
            echo -e "  ${YELLOW}⚠️  Currently bound to: ${BOLD}${_existing_shortcut}${NC}"
            echo -e "  ${DIM}  Entering a new shortcut will replace the existing binding.${NC}"
            echo ""
        fi
        echo -e "  ${BOLD}${CYAN}Enter a keyboard shortcut combination:${NC}"
        echo -e "  ${DIM}  Use + to combine modifiers. Examples:${NC}"
        echo -e "  ${DIM}    Ctrl+Alt+G       Meta+Shift+A     Ctrl+Alt+Return${NC}"
        echo -e "  ${DIM}    Ctrl+Alt+1       Meta+F5          Ctrl+Shift+S${NC}"
        echo ""
        echo -e "  ${DIM}  Common modifiers: Ctrl  Alt  Meta (Win key)  Shift${NC}"
        echo -e "  ${DIM}  Keys: A-Z, F1-F12, Return, Space, Tab, Insert, Delete, etc.${NC}"
        echo ""
        echo -e "  ${BOLD}${CYAN}  Known taken shortcuts on your system:${NC}"
        # Show a few taken shortcuts from kglobalshortcutsrc for reference
        if [ -f "$HOME/.config/kglobalshortcutsrc" ]; then
            grep -hE "^[A-Za-z].*=Ctrl\+Alt\+|=Meta\+[A-Z]" \
                "$HOME/.config/kglobalshortcutsrc" 2>/dev/null \
                | grep -v "^_k_" | head -8 \
                | while IFS='=' read -r kname kval; do
                    local _first_binding
                    _first_binding="$(echo "$kval" | cut -d',' -f1)"
                    printf "  ${DIM}    %-35s → %s${NC}\n" \
                        "$(echo "$kname" | sed 's/_/ /g')" "$_first_binding"
                done
        fi
        echo ""

        local new_shortcut
        read -r -p "  Keyboard shortcut (or 0 to cancel): " new_shortcut
        [[ "$new_shortcut" == "0" ]] || [[ -z "$new_shortcut" ]] && continue

        # ── Normalise: strip surrounding spaces, ensure Title case modifiers ──
        # Accept input like "ctrl+alt+g" → "Ctrl+Alt+G"
        local norm_shortcut
        norm_shortcut="$(echo "$new_shortcut" | sed \
            -e 's/\bctrl\b/Ctrl/gi' \
            -e 's/\balt\b/Alt/gi' \
            -e 's/\bmeta\b/Meta/gi' \
            -e 's/\bshift\b/Shift/gi' \
            -e 's/\breturn\b/Return/gi' \
            -e 's/\bspace\b/Space/gi' \
            -e 's/\btab\b/Tab/gi' \
            -e 's/\binsert\b/Insert/gi' \
            -e 's/\bdelete\b/Delete/gi' \
            -e 's/\bescape\b/Escape/gi' \
            -e 's/\bhome\b/Home/gi' \
            -e 's/\bend\b/End/gi' \
            -e 's/ //g')"

        echo ""
        echo -e "  ${BOLD}Confirming shortcut:${NC} ${CYAN}${BOLD}${norm_shortcut}${NC}"
        echo -e "  ${BOLD}For application:${NC}   ${GREEN}${_sel_name}${NC}"
        echo ""
        read -r -p "  Apply this keyboard shortcut? [Y/n]: " confirm_bind
        [[ "$confirm_bind" =~ ^[Nn]$ ]] && continue

        # ── Step 4: Write the binding ──────────────────────────────────────────
        # KDE Plasma keyboard shortcut binding strategy:
        # 1. Copy .desktop to ~/.local/share/applications/ (if not already there)
        # 2. Add/update X-KDE-GlobalAccel-CommandShortcut=true
        # 3. Add/update X-KDE-Shortcuts=<shortcut>
        # 4. Write entry to ~/.config/kglobalshortcutsrc under [services][<basename>]
        # 5. Notify kglobalaccel via D-Bus to reload

        local local_apps_dir="$HOME/.local/share/applications"
        local desktop_basename
        desktop_basename="$(basename "$_sel_file")"
        local target_desktop="${local_apps_dir}/${desktop_basename}"

        echo ""
        echo -e "  ${DIM}Writing keyboard shortcut binding...${NC}"

        # Ensure the .desktop lives in ~/.local/share/applications/
        if [ "$_sel_file" != "$target_desktop" ]; then
            cp -f "$_sel_file" "$target_desktop" 2>/dev/null || {
                echo -e "  ${RED}Error: Could not copy .desktop to ${local_apps_dir}/ — check permissions.${NC}"
                press_enter; continue
            }
        fi

        # Remove any old X-KDE-* lines from the target desktop file
        local tmp_desktop
        tmp_desktop="$(mktemp /tmp/congen_dsk_bind_XXXXXX.desktop)"
        grep -v '^X-KDE-GlobalAccel-CommandShortcut=' \
             "$target_desktop" > "$tmp_desktop" 2>/dev/null || true
        grep -v '^X-KDE-Shortcuts=' "$tmp_desktop" > "${tmp_desktop}.2" 2>/dev/null || true
        mv "${tmp_desktop}.2" "$tmp_desktop"

        # Append KDE shortcut keys under [Desktop Entry]
        echo "X-KDE-GlobalAccel-CommandShortcut=true" >> "$tmp_desktop"
        echo "X-KDE-Shortcuts=${norm_shortcut}" >> "$tmp_desktop"
        mv -f "$tmp_desktop" "$target_desktop"

        # ── Write/update kglobalshortcutsrc ───────────────────────────────────
        local kglobal_cfg="$HOME/.config/kglobalshortcutsrc"
        local section_key="[services][${desktop_basename}]"
        # Action key name = same as desktop file basename without extension
        local action_name="${desktop_basename%.desktop}"

        # Remove old entry for this app from kglobalshortcutsrc if it exists
        if [ -f "$kglobal_cfg" ]; then
            local tmp_kg
            tmp_kg="$(mktemp /tmp/congen_kglobal_XXXXXX.rc)"
            python3 - "$kglobal_cfg" "$section_key" "$action_name" "$norm_shortcut" "$_sel_name" \
                > "$tmp_kg" << 'PYEOF'
import sys, re

cfg_file   = sys.argv[1]
section    = sys.argv[2]   # e.g. [services][foo.desktop]
action     = sys.argv[3]   # e.g. foo
shortcut   = sys.argv[4]   # e.g. Ctrl+Alt+G
app_name   = sys.argv[5]   # e.g. My App

with open(cfg_file, 'r', encoding='utf-8', errors='replace') as f:
    content = f.read()

# Remove existing section block for this service
pattern = re.compile(
    r'^\[services\]\[' + re.escape(action) + r'\.desktop\][^\[]*',
    re.MULTILINE
)
content = pattern.sub('', content)
content = re.sub(r'\n{3,}', '\n\n', content)   # collapse blank lines

# Build the new section entry
# Format: actionname=shortcut,shortcut,Friendly Description
new_block = (
    f'\n{section}\n'
    f'_k_friendly_name={app_name}\n'
    f'{action}={shortcut},{shortcut},Launch {app_name}\n'
)

content = content.rstrip('\n') + '\n' + new_block + '\n'
print(content, end='')
PYEOF

            if [ -s "$tmp_kg" ]; then
                mv -f "$tmp_kg" "$kglobal_cfg"
            else
                rm -f "$tmp_kg"
            fi
        else
            # Create fresh kglobalshortcutsrc with this entry
            {
                echo "${section_key}"
                echo "_k_friendly_name=${_sel_name}"
                echo "${action_name}=${norm_shortcut},${norm_shortcut},Launch ${_sel_name}"
                echo ""
            } >> "$kglobal_cfg"
        fi

        # ── Step 5: Notify KDE to reload shortcuts ─────────────────────────────
        # kglobalaccel D-Bus reload (Plasma 6)
        if command -v qdbus >/dev/null 2>&1; then
            qdbus org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reloadConfig \
                >/dev/null 2>&1 || true
        fi
        # kbuildsycoca to rebuild service database (Plasma 5/6)
        if command -v kbuildsycoca6 >/dev/null 2>&1; then
            kbuildsycoca6 --noincremental >/dev/null 2>&1 &
            disown
        elif command -v kbuildsycoca5 >/dev/null 2>&1; then
            kbuildsycoca5 --noincremental >/dev/null 2>&1 &
            disown
        fi

        # ── Step 6: Confirmation screen ────────────────────────────────────────
        clear
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo -e "${BOLD}${GREEN}   ✔  Keyboard Shortcut Successfully Bound!${NC}"
        echo -e "${BOLD}${MAGENTA}========================================================================${NC}"
        echo ""
        echo -e "  ${BOLD}Application:${NC}       ${GREEN}${BOLD}${_sel_name}${NC}"
        echo -e "  ${BOLD}Keyboard Shortcut:${NC} ${CYAN}${BOLD}${norm_shortcut}${NC}"
        echo -e "  ${BOLD}Desktop File:${NC}      ${DIM}${target_desktop}${NC}"
        echo ""
        echo -e "  ${DIM}What was updated:${NC}"
        echo -e "  ${GREEN}✔${NC}  ${DIM}X-KDE-GlobalAccel-CommandShortcut=true added to .desktop file${NC}"
        echo -e "  ${GREEN}✔${NC}  ${DIM}X-KDE-Shortcuts=${norm_shortcut} written to .desktop file${NC}"
        echo -e "  ${GREEN}✔${NC}  ${DIM}~/.config/kglobalshortcutsrc updated${NC}"
        echo -e "  ${GREEN}✔${NC}  ${DIM}KDE kglobalaccel daemon notified to reload${NC}"
        echo ""
        echo -e "  ${BOLD}${YELLOW}Note:${NC} ${DIM}You may need to log out and back in, or right-click the${NC}"
        echo -e "  ${DIM}Desktop Shortcut → Properties → Keyboard Shortcut to confirm.${NC}"
        echo -e "  ${DIM}Alternatively run: qdbus org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reloadConfig${NC}"
        echo ""
        press_enter

        # Update cached value in our arrays for the next display
        shortcut_existing_keys[$_sel_idx]="$norm_shortcut"
    done
}
# ─────────────────────────────────────────────────────────────────────────────

manage_visual_media_suite() {
    while true; do
        local opts=(
            "1|Visual, Video & Art Launchers Suite|(NFT Videos, Video Player, GIMP, Electric Sheep, GeeXLab)"
            "2|Cut or Split Video File (.mp4 / .mkv)|(Cut_Video.sh / Split_Video_File.sh)"
            "3|Convert Cover Art & Resize / Byte Target|(1MB Podcast, WebP/JPG/PNG, Sizes)"
            "4|View Cover Art by Mix Number|(External Viewer)"
            "5|Procedural Gradient .PPM Cover Art Generator|(Netpbm P6 Binary, Palettes)"
            "6|Synchronized Mix-Video Companion Player Daemon|(Auto-play Video on Mix Start, Close on Stop)"
            "7|Download YouTube Videos & Shorts in 1080p|(Single URL, 1/3/6 Mo, All Videos/Shorts)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "VISUAL MEDIA, COVER ART & COMPANION VIDEO SUITE" "" opts 0
        local vm_choice="$REPLY"
        case "$vm_choice" in
            1)
                manage_visual_media_launchers
                ;;
            2)
                manage_video_cut_and_split
                ;;
            3)
                manage_cover_converter
                ;;
            4)
                view_cover
                press_enter
                ;;
            5)
                generate_ppm_cover_menu
                ;;
            6)
                manage_sync_video_companion_menu
                ;;
            7)
                run_sub_script "MP_YouTube_Channel_Downloader.sh"
                press_enter
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_promo_and_syndication() {
    while true; do
        local opts=(
            "1|Promotional & Publisher Outreach Emails|(Promoters, Publishers, Radio, Labels)"
            "2|Mix Publishing Schedule & Multi-Platform Syndication|(Apple Podcasts, Spotify, YouTube, SoundCloud, RSS, iCal)"
            "3|Go Shopping for New Music|(Beatport, Apple Music & Bandcamp Tabs)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "PROMOTIONAL OUTREACH, SYNDICATION & SHOPPING" "" opts 0
        local ps_choice="$REPLY"
        case "$ps_choice" in
            1)
                manage_promo_outreach
                ;;
            2)
                manage_publishing_schedule
                ;;
            3)
                shop_for_new_music_menu
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_congen() {
    local congen_bin="$SCRIPT_DIR/Congen/Congen"
    [ ! -x "$congen_bin" ] && congen_bin="$SCRIPT_DIR/congen"
    [ ! -x "$congen_bin" ] && congen_bin="./congen"
    if [ -x "$congen_bin" ]; then
        "$congen_bin" "$@"
    else
        echo -e "\n${RED}Error: Congen executable not found!${NC}"
        press_enter
    fi
}

manage_network_and_internet() {
    while true; do
        local opts=(
            "1|Manage Network Services|(SSH, Samba, FTP - Start, Stop, Restart All)"
            "2|Congen - KDE Connect Commands Generator & Remote Control|(Mobile Phone Commands)"
            "3|Block Internet Access|(LAN Only - block-internet)"
            "4|Restore / Unblock Internet Access|(unblock-internet)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "NETWORK SERVICES, CONGEN & INTERNET ACCESS CONTROL" "" opts 0
        local net_choice="$REPLY"
        case "$net_choice" in
            1)
                manage_network_services
                ;;
            2)
                manage_congen
                ;;
            3)
                block_internet
                ;;
            4)
                unblock_internet
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_desktop_and_display() {
    while true; do
        local d1="Switch Desktop to Plasma Wayland"
        local d1_info="(HDR Gaming on Hisense & Steam BPM)"
        local d2="Switch Desktop to Plasma X11"
        local d2_info="(Standard Workstation)"
        if [ "$OS_TYPE" = "macos" ]; then
            d1="Open macOS Display Settings"; d1_info="(Displays, Arrangement & HDR)"
            d2="Open macOS Audio MIDI Setup"; d2_info="(Sample Rates & Output Devices)"
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            d1="Open Windows Display Settings"; d1_info="(ms-settings:display - HDR & Scale)"
            d2="Open Windows Sound Settings"; d2_info="(control.exe mmsys.cpl)"
        fi
        local opts=(
            "1|${d1}|${d1_info}"
            "2|${d2}|${d2_info}"
            "3|Close All Desktop Applications|(Keep Manager Open)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "DESKTOP DISPLAY SETTINGS & APP CONTROL" "" opts 0
        local dsk_choice="$REPLY"
        case "$dsk_choice" in
            1)
                if [ "$OS_TYPE" = "macos" ]; then
                    open /System/Library/PreferencePanes/Displays.prefPane 2>/dev/null || open "x-apple.systempreferences:com.apple.Displays-Settings.extension" 2>/dev/null || true
                elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
                    cmd.exe /c start ms-settings:display 2>/dev/null || true
                else
                    switch_to_wayland
                fi
                ;;
            2)
                if [ "$OS_TYPE" = "macos" ]; then
                    open -a "Audio MIDI Setup" 2>/dev/null || true
                elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
                    cmd.exe /c start control.exe mmsys.cpl 2>/dev/null || true
                else
                    switch_to_x11
                fi
                ;;
            3)
                close_all_desktop_apps
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_ai_and_servers() {
    while true; do
        local opts=(
            "1|Launch AI Assistant / Models|(Claude Opus, Claude Sonnet, GPT-OSS, Gemini, Ollama, DeepSeek)"
            "2|Manage Ollama Server|(ollama serve in distrobox, Chat, Models, Logs :11434)"
            "3|Manage DeepSeek Harness Server|(dsh-mobile - Start, Stop, Mobile Web UI :3080)"
            "4|Manage WAN2GP Server|(Start, Stop, Restart in Profile 2 or 4.5)"
            "5|Manage Beszel Server & Monitoring Agent|(Start Hub & Agent, Status, Dashboard :8090)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "AI ASSISTANT & LOCAL LLM SERVERS SUITE" "" opts 0
        local ai_choice="$REPLY"
        case "$ai_choice" in
            1)
                manage_ai_models
                ;;
            2)
                manage_ollama
                ;;
            3)
                manage_dsh_mobile
                ;;
            4)
                manage_wan2gp
                ;;
            5)
                manage_beszel
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_motd_and_tools() {
    while true; do
        local opts=(
            "1|Dynamic System MOTD Banner Manager|(Last 3 Mixes, Date/Time, Size, Format & Specs)"
            "2|Burn ISO Image to USB Drive|(dd / diskutil with safety checks)"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "MOTD BANNER MANAGER & SYSTEM UTILITIES" "" opts 0
        local mt_choice="$REPLY"
        case "$mt_choice" in
            1)
                manage_system_motd_menu
                ;;
            2)
                burn_iso_to_usb
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

manage_settings_and_system() {
    while true; do
        local reboot_desc="systemctl reboot with confirmation"
        if [ "$OS_TYPE" = "macos" ]; then
            reboot_desc="macOS restart with confirmation"
        elif [ "$OS_TYPE" = "windows" ] || [ "$OS_TYPE" = "wsl" ]; then
            reboot_desc="Windows restart with confirmation"
        elif [ "$OS_TYPE" = "freebsd" ]; then
            reboot_desc="FreeBSD restart with confirmation"
        fi
        local opts=(
            "1|Manager Themes & Color Palette Switcher|(11 Themes: Dreamworlds, Cyberpunk, Dracula...)"
            "2|Manage Installation & Configuration|(Migrate Path, Backup, Export & Import Config)"
            "3|Run Bash CLI Commands|(Interactive Shell & Direct Runner)"
            "4|Reboot System|(${reboot_desc})"
            "0|Return to Main Menu|(or Esc / q)"
        )
        run_interactive_submenu "MANAGER SETTINGS, THEMES & SYSTEM SHELL" "" opts 0
        local set_choice="$REPLY"
        case "$set_choice" in
            1)
                manage_themes
                ;;
            2)
                manage_installation_and_config
                ;;
            3)
                run_bash_cli
                ;;
            4)
                reboot_system
                ;;
            0|[qQ]|[eE][xX][iI][tT]|ESC)
                return 0
                ;;
            *)
                echo -e "\n${RED}Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}


# ==============================================================================
# MAIN APPLICATION LOOP
# ==============================================================================

while true; do
    if [ "$STARTUP_AUTOPLAY_EXECUTED" -eq 0 ]; then
        STARTUP_AUTOPLAY_EXECUTED=1
        ensure_manager_fullscreen
        align_mix_windows_on_screen
        if [ "${AUTO_PLAY_ON_STARTUP:-true}" = "true" ]; then
            execute_startup_autoplay
        else
            check_and_show_currently_playing_mix
        fi
        # Ensure DJ mix scheduler daemon is active if pending scheduled mixes exist
        if [ -f "$HOME/.config/mix-manager/scheduled_mixes.json" ] && grep -q '"status": "pending"' "$HOME/.config/mix-manager/scheduled_mixes.json" 2>/dev/null; then
            if [ -f "$SCRIPT_DIR/scripts/schedule_mix_playback.py" ]; then
                python3 "$SCRIPT_DIR/scripts/schedule_mix_playback.py" --ensure-daemon >/dev/null 2>&1 &
            elif [ -f "$SCRIPT_DIR/scripts/schedule_mix_playback.sh" ]; then
                "$SCRIPT_DIR/scripts/schedule_mix_playback.sh" --ensure-daemon >/dev/null 2>&1 &
            fi
        fi
        if [ "$CURRENT_THEME" = "dreamworlds" ]; then
            show_dreamworlds_ascii_banner true
            sleep 0.2
        fi
    fi

    term_lines=$(tput lines 2>/dev/null || echo 40)
    [ -z "$term_lines" ] || [ "$term_lines" -lt 15 ] && term_lines=40

    main_header=""
    if [ "$CURRENT_THEME" = "dreamworlds" ]; then
        local_anim_script="$SCRIPT_DIR/scripts/render_ascii_animation.py"
        [ ! -f "$local_anim_script" ] && local_anim_script="$SCRIPT_DIR/render_ascii_animation.py"
        if [ "$term_lines" -ge 55 ]; then
            if [ -f "$local_anim_script" ]; then
                main_header+="$(python3 "$local_anim_script" 2>/dev/null)\n"
            fi
        else
            if [ -f "$local_anim_script" ]; then
                main_header+="$(python3 "$local_anim_script" --compact 2>/dev/null)\n"
            fi
        fi
    else
        main_header+="${BOLD}${MAGENTA}===================================================================================${NC}\n"
        main_header+="${BOLD}${MAGENTA}                     Mix Archive Manager (MP_Mix_Manager_v0.3)                     ${NC}\n"
        main_header+="${BOLD}${MAGENTA}===================================================================================${NC}\n"
    fi
    os_badge=$(get_os_badge)
    os_updates=$(get_os_update_status)
    shell_info="Bash ${BASH_VERSION%%(*}"
    current_datetime=$(date "+%A, %B %d, %Y • %T %Z")
    if is_internet_connected; then
        net_status="${GREEN}Online${NC}"
    else
        net_status="${YELLOW}Offline (LAN Only)${NC}"
    fi
    main_header+="  ${os_badge}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🔄 OS Updates:${NC} ${os_updates}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🌐 Network:${NC} ${net_status}  ${BOLD}${BLUE}│${NC}  ${BOLD}${CYAN}🐚 Shell:${NC} ${shell_info}\n"
    cloud_status=$(get_cloud_backup_badge 2>/dev/null)
    [ -n "$cloud_status" ] && main_header+="  ${cloud_status}\n"
    sys_perf=$(get_system_perf_stats)
    audio_interface_disp=$(get_active_audio_interface_display)
    [ -n "$sys_perf" ] && main_header+="${sys_perf}\n"
    [ -n "$audio_interface_disp" ] && main_header+="${audio_interface_disp}\n"

    if [ "$term_lines" -ge 55 ]; then
        if [ -n "${STARTUP_AUTOPLAY_NOTICE:-}" ]; then
            main_header+="  ${BOLD}${GREEN}${STARTUP_AUTOPLAY_NOTICE}${NC}\n"
        fi
        if [ -n "${STARTUP_SPEK_NOTICE:-}" ]; then
            main_header+="  ${BOLD}${GREEN}${STARTUP_SPEK_NOTICE}${NC}\n"
        fi
        if [ "${WEATHER_ENABLED:-true}" = "true" ] && [ -n "${WEATHER_LOCATION:-}" ]; then
            current_weather=$(get_current_weather)
            [ -n "$current_weather" ] && main_header+="${current_weather}\n"
        fi
        if [ "${PLANETS_ENABLED:-true}" = "true" ]; then
            current_planets=$(get_planets_above_horizon)
            [ -n "$current_planets" ] && main_header+="${current_planets}\n"
        fi
        alarm_clock_status=$(get_alarm_clock_status_display)
        [ -n "$alarm_clock_status" ] && main_header+="${alarm_clock_status}\n"
        main_header+="${BOLD}${MAGENTA}-----------------------------------------------------------------------------------${NC}\n"
        if ! is_mix_archive_configured; then
            main_header+="\n  ${BOLD}${RED}⚠️  Please be advised you have not configured your Mix Archive Folder, Please use Option 13 or 10 to Configure this now.${NC}\n"
            main_header+="  ${DIM}${YELLOW}(Currently using application root folder: ${SCRIPT_DIR}/MIX_ARCHIVE)${NC}\n"
        fi
        main_header+="\n"
        main_header+="$(show_stats)\n\n"
        main_header+="  $(get_manager_uptime)\n"
    else
        main_header+="${BOLD}${MAGENTA}-----------------------------------------------------------------------------------${NC}\n"
        main_header+="  $(get_manager_uptime)\n"
    fi

    main_opts=(
        "SECTION|SECTION 1: MIX ARCHIVE WORKFLOW & INGESTION|"
        "0|Run Any Desktop Shortcuts — Linux|(Games, Audio, Files, Tools, AI Servers — KDE Plasma)"
        "1|Run Mix Conversion|(FLAC, MP3, WAV, or YouTube MP4)"
        "2|Audio Conversion, EBU R128 Mastering & CUE Sheets|(WAV, MP3, AAC, LUFS, CUE, Splitter)"
        "3|Retrieve Unconverted WAVs from Archive|(MOVE_NOT_CONVERTED_WAVS.sh)"
        "4|Search & Import Mixes from Local Drives & SMB|(search_and_import_mixes.sh / import_new_mixes.sh)"
        "5|Rename a Mix and Associated Assets|(FLAC, Tracklist, Spek)"
        "6|Find & Remove Duplicate Audio Files / Mixes|(Exact Content & Episode Match)"
        "7|Export / Copy Mixes to Specified Path|(Audio, Covers, Tracklists, Spek)"
        "8|Audio Integrity, Bit-Rot Scrub & FLAC Verification|(SHA-256, Bit-Rot Daemon, Fake FLAC)"
        "9|Cloud & Remote Backup Suite|(Google Drive, iCloud, Dropbox, Custom Folder)"
        "10|Storage Management & Multiple Mix Archives Setup|(Drive Space, Rescan, Configure Archives)"
        "SECTION|SECTION 2: STUDIO AUDIO, PLAYBACK, METADATA & VIDEO|"
        "11|Tracklist Management, Scanning & Metadata Suite|(Browse, Search, Picard, HTML Index)"
        "12|Audio Players & Retro Playback Suite|(cliamp, Strawberry, VLC, Audacity, Haruna, Winamp...)"
        "13|Configure Mix Archive Storage Locations|(Option 13: Primary & Multiple Archives)"
        "14|Custom Mix Playlists & Traktor History Suite|(.m3u, .m3u8, .xspf, Traktor 3 Playlists)"
        "15|Digital Audio Workstations (DAWs) & Mix Dispatch|(Reaper, Logic, FL Studio, Ardour, Traktor)"
        "16|Studio Hardware, Audio Interfaces & Master Volume Control|(PipeWire, ALSA, MIDI, Mute)"
        "17|Spectrogram Generation & Audio Frequency Analysis|(Single & Multiple Spek, SoX, Praat)"
        "18|Morning Alarm Clock & DJ Mix Playback Suite|(Steam Games, Wake-Up Mixes, Scheduler)"
        "19|YouTube Video Suite|(Generate 4K/1080p Videos, Download Videos & Shorts)"
        "20|Visual Media, Cover Art & Companion Video Suite|(Cut/Split Video, Converters, PPM, Launchers)"
        "21|Record Video of DJ Mix using GPU Screen Recorder (Linux)|(New Desktop Window)"
        "22|Listen to Your Top 5 Tracks Right Now (Pre-Selected - Special Option)|$(get_top_5_status_badge)"
        "SECTION|SECTION 3: SYSTEM, NETWORK, AI & SETTINGS|"
        "23|Live Session, Stream & Transfer Monitors Suite|(Tracklist, Traktor, Transfers, Uploads, Tasks)"
        "24|System & Hardware Process Monitors Suite|(btop, nvtop, top)"
        "25|View Advanced Archive Statistics|(SOF_Archive_Stats.sh)"
        "26|Promotional Outreach, Syndication & Music Shopping|(Emails, RSS/Podcasts, Beatport/Bandcamp)"
        "27|Network Services, Congen & Internet Control|(SSH, Samba, FTP, Congen KDE Connect, Block Internet)"
        "28|Desktop Display Settings, Audio Routing & App Control|(Wayland/X11/macOS/Windows, Close Apps)"
        "29|Universal System Maintenance & Cleanup|(Drive space, OS Updates, Package Clean, Logs)"
        "30|Monitor System Processes and Bash Commands with System Info|(MP_Monitor_Bash.sh, new Terminal tab)"
        "31|AI Assistant & Local LLM Servers Suite|(Claude, GPT, Ollama, DeepSeek, WAN2GP, Beszel)"
        "32|Dynamic MOTD Banner Manager & Drive Burner|(Last 3 Mixes, Netpbm, ISO USB Burner)"
        "33|Manager Settings, Themes, Shell CLI & Reboot|(Themes, Migration, Bash CLI, Reboot)"
        "SEP|SEP|"
        "34|Exit Manager|(or q / exit)"
    )

    if [ -n "$CLI_INITIAL_ACTION" ]; then
        choice="$CLI_INITIAL_ACTION"
        CLI_INITIAL_ACTION=""
    else
        run_interactive_submenu "" "$main_header" main_opts 1
        choice="$REPLY"
    fi
    
    case $choice in
        1)
            echo -e "\n${BOLD}${YELLOW}Starting conversion. You can still choose FLAC, MP3, WAV, or a YouTube MP4.${NC}\n"
            run_sub_script "Make_SOF_FLAC_CONVERSION.sh"
            echo ""
            echo -e "${BOLD}${GREEN}Conversion finished. This report stays on screen.${NC}"
            while true; do
                flac_done_choice=""
                read -r -p "Type [m] to open the main menu, or [q] to quit: " flac_done_choice </dev/tty || true
                case "$flac_done_choice" in
                    [mM]) break ;;
                    [qQ]) exit_mix_manager ;;
                esac
            done
            ;;
        2)
            manage_audio_conversion
            ;;
        3)
            echo -e "\n${BOLD}${YELLOW}Retrieving unconverted WAV files...${NC}\n"
            run_sub_script "MOVE_NOT_CONVERTED_WAVS.sh"
            press_enter
            ;;
        4)
            manage_mix_search_and_import
            ;;
        5)
            rename_mix
            press_enter
            ;;
        6)
            find_duplicate_audio_mixes
            ;;
        7)
            export_mixes_to_path
            ;;
        8)
            manage_integrity_and_verification
            ;;
        9|backup|cloud-backup)
            manage_cloud_backup_suite
            ;;
        10)
            play_sound_effect "storage"
            manage_storage_and_archive_config
            ;;
        11)
            manage_tracklist_suite
            ;;
        12|manage-audio-players|players)
            manage_audio_players
            ;;
        13|config-archive|archive-dir|archive-folder)
            play_sound_effect "storage"
            configure_mix_archive_folder
            ;;
        specs|metadata|inspect)
            inspect_playing_audio_file
            ;;
        14)
            manage_playlists_and_history
            ;;
        15)
            manage_daws_suite
            ;;
        16)
            manage_studio_hardware_and_volume
            ;;
        17)
            manage_spek_generation
            ;;
        18)
            manage_mix_scheduler
            ;;
        19)
            generate_youtube_video
            ;;
        20|manage-visual-media|visual-launchers|video-launchers)
            manage_visual_media_suite
            ;;
        21|gpu-screen-recorder|record-mix)
            launch_gpu_screen_recorder
            press_enter
            ;;
        22|top5|top-5|top_5|top|mystery|special)
            manage_top_5_tracks
            ;;
        23|manage-live-monitors|live-monitors)
            manage_live_monitors
            ;;
        24|manage-process-monitors|process-monitors)
            manage_system_process_monitors
            ;;
        25)
            echo -e "\n${BOLD}${YELLOW}Loading Advanced Archive Statistics...${NC}\n"
            sleep 0.5
            run_sub_script "SOF_Archive_Stats.sh"
            press_enter
            ;;
        26)
            manage_promo_and_syndication
            ;;
        27)
            manage_network_and_internet
            ;;
        28)
            manage_desktop_and_display
            ;;
        29)
            manage_system_maintenance
            ;;
        30|m|monitor|mp-monitor|bash-monitor)
            manage_process_and_bash_monitor
            ;;
        31)
            manage_ai_and_servers
            ;;
        32)
            manage_motd_and_tools
            ;;
        33)
            manage_settings_and_system
            ;;
        34|77|[qQ]|[eE][xX][iI][tT]|ESC)
            exit_mix_manager
            ;;
        # ----------------------------------------------------------------------
        # Legacy Shortcut Aliases (for direct muscle-memory compatibility)
        # ----------------------------------------------------------------------
        audacious|audacious-launch)
            launch_audacious
            ;;
        audacity|audacity-launch)
            launch_audacity
            ;;
        strawberry|strawberry-launch)
            launch_strawberry
            ;;
        vlc|vlc-launch)
            launch_vlc
            ;;
        haruna|haruna-launch)
            launch_haruna
            ;;
        kodi|kodi-launch)
            launch_kodi
            ;;
        gimp|gimp-launch)
            launch_gimp
            ;;
        electricsheep|screensaver)
            launch_electricsheep
            ;;
        geexlab|geexlab-launch)
            launch_geexlab_demos
            ;;
        btop|btop-launch)
            echo -e "\n${BOLD}${YELLOW}Launching btop Resource Monitor (Press 'q' to exit)...${NC}\n"
            sleep 0.5
            trap ':' INT
            if command -v btop >/dev/null 2>&1; then btop; else echo -e "${RED}Error: btop command not found!${NC}"; press_enter; fi
            trap 'exit_mix_manager' INT
            ;;
        nvtop|nvtop-launch)
            echo -e "\n${BOLD}${YELLOW}Launching nvtop GPU Monitor (Press 'q' to exit)...${NC}\n"
            sleep 0.5
            trap ':' INT
            if command -v nvtop >/dev/null 2>&1; then nvtop; else echo -e "${RED}Error: nvtop command not found!${NC}"; press_enter; fi
            trap 'exit_mix_manager' INT
            ;;
        top|top-launch)
            echo -e "\n${BOLD}${YELLOW}Launching top Process Monitor (Press 'q' to exit)...${NC}\n"
            sleep 0.5
            trap ':' INT
            if command -v top >/dev/null 2>&1; then top; else echo -e "${RED}Error: top command not found!${NC}"; press_enter; fi
            trap 'exit_mix_manager' INT
            ;;
        split-flac|split_flac)
            split_flac_audio
            press_enter
            ;;
        split-video|split_video|split-mp4|split_mp4)
            split_video_clip
            press_enter
            ;;
        cut-video|cut_video)
            cut_video_clip
            press_enter
            ;;
        beszel|beszel-start|beszel_start|beszel-hub|beszel-agent)
            manage_beszel
            press_enter
            ;;
        ollama|ollama-serve|ollama_serve|ollama-start|ollama_start)
            manage_ollama
            press_enter
            ;;
        dsh|dsh-mobile|dsh_mobile|dsh-start|dsh_start|dsh-web|dsh_web|deepseek|deepseek-harness)
            manage_dsh_mobile
            press_enter
            ;;
        alarm|alarm-clock|alarm_clock|alarm.sh)
            manage_mix_scheduler
            ;;
        congen|kdeconnect|congen-launch)
            manage_congen
            ;;
        0|[Ss]|shortcuts|desktop-shortcuts|ds|kioclient|run-shortcuts|desktop_shortcuts)
            manage_desktop_shortcuts
            ;;
        *)
            echo -e "\n${RED}Invalid option! Please enter a number between 0 and 34, or q to exit.${NC}"
            sleep 2
            ;;
    esac
done
