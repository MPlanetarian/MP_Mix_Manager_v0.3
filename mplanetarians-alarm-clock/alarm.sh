#!/usr/bin/env bash
# MPlanetarians Alarm Clock (Wake Up Edition)
# Version 0.1 — command-line morning alarm by MPlanetarian.

set -uo pipefail

APP_NAME="MPlanetarians Alarm Clock (Wake Up Edition)"
APP_VERSION="0.1"
APP_AUTHOR="MPlanetarian"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mplanetarians-alarm-clock"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mplanetarians-alarm-clock"
SETTINGS_FILE="$CONFIG_DIR/settings.env"
ALARM_FILE="$CONFIG_DIR/alarms.tsv"
NOTES_FILE="$CONFIG_DIR/notes.tsv"
LOG_FILE="$STATE_DIR/alarm.log"
WAKE_FILE="$STATE_DIR/wakeups.tsv"
RING_FILE="$STATE_DIR/ringing"
VOLUME_FILE="$STATE_DIR/previous-volume"
REASON_FILE="$STATE_DIR/stop-reason"
STATUS_FILE="$STATE_DIR/watch.status"
SUMMARY_FILE="$STATE_DIR/last-summary.txt"
BRIEF_CACHE="$STATE_DIR/daily-brief.txt"
IDLE_SECONDS="${MPAC_IDLE_SECONDS:-600}"
CLIAMP_BIN="${CLIAMP_BIN:-}"

mkdir -p "$CONFIG_DIR" "$STATE_DIR"
touch "$ALARM_FILE" "$NOTES_FILE" "$LOG_FILE" "$WAKE_FILE"
[[ -f "$SETTINGS_FILE" ]] || printf 'THEME=midnight-ink\nENABLED=yes\nVOLUME=100\nWAKE_KIND=none\nWAKE_ARG=\n' >"$SETTINGS_FILE"

if [[ -z "$CLIAMP_BIN" ]]; then
    if [[ -x "$HOME/.local/bin/cliamp" ]]; then
        CLIAMP_BIN="$HOME/.local/bin/cliamp"
    else
        CLIAMP_BIN="$(command -v cliamp 2>/dev/null || true)"
    fi
fi

log_line() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

cfg_get() {
    local key="$1" default="${2:-}" line
    line="$(grep -E "^${key}=" "$SETTINGS_FILE" 2>/dev/null | tail -n 1 || true)"
    if [[ -z "$line" ]]; then
        printf '%s\n' "$default"
    else
        printf '%s\n' "${line#*=}"
    fi
}

cfg_set() {
    local key="$1" value="$2" tmp
    tmp="$(mktemp "$CONFIG_DIR/settings.XXXXXX")"
    grep -Ev "^${key}=" "$SETTINGS_FILE" >"$tmp" || true
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
    mv "$tmp" "$SETTINGS_FILE"
    log_line "CONFIG ${key}=${value}"
}

die() {
    printf 'Error: %s\n' "$*" >&2
    log_line "ERROR $*"
    exit 1
}

# --- themes -----------------------------------------------------------------

apply_theme() {
    local theme
    theme="$(cfg_get THEME midnight-ink)"
    case "$theme" in
        warm-brass)
            C1=$'\033[38;5;178m'; C2=$'\033[38;5;223m'; C3=$'\033[38;5;94m' ;;
        forest-hour)
            C1=$'\033[38;5;108m'; C2=$'\033[38;5;187m'; C3=$'\033[38;5;65m' ;;
        porcelain)
            C1=$'\033[38;5;224m'; C2=$'\033[38;5;252m'; C3=$'\033[38;5;138m' ;;
        *)
            theme="midnight-ink"
            C1=$'\033[38;5;75m'; C2=$'\033[38;5;159m'; C3=$'\033[38;5;67m' ;;
    esac
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
    THEME_NAME="$theme"
}

theme_title() {
    case "$1" in
        midnight-ink) printf 'Midnight Ink — navy and silver, the hour before dawn' ;;
        warm-brass) printf 'Warm Brass — amber lamp-light on a dark morning' ;;
        forest-hour) printf 'Forest Hour — deep green and soft gold' ;;
        porcelain) printf 'Porcelain — warm grey and rose, quiet and clear' ;;
        *) printf '%s' "$1" ;;
    esac
}

cmd_theme() {
    local choice="${1:-}"
    if [[ -z "$choice" ]]; then
        printf 'Themes:\n'
        printf '  1) %s\n' "$(theme_title midnight-ink)"
        printf '  2) %s\n' "$(theme_title warm-brass)"
        printf '  3) %s\n' "$(theme_title forest-hour)"
        printf '  4) %s\n' "$(theme_title porcelain)"
        printf 'Current: %s\n' "$(cfg_get THEME midnight-ink)"
        return 0
    fi
    case "$choice" in
        1|midnight-ink) choice="midnight-ink" ;;
        2|warm-brass) choice="warm-brass" ;;
        3|forest-hour) choice="forest-hour" ;;
        4|porcelain) choice="porcelain" ;;
        *) die "Unknown theme: $choice" ;;
    esac
    cfg_set THEME "$choice"
    apply_theme
    printf 'Theme set to %s.\n' "$(theme_title "$choice")"
}

# --- logo -------------------------------------------------------------------

draw_logo() {
    local frame="${1:-0}" hand
    case "$frame" in
        1) hand='   /|\   ' ;;
        2) hand=' ---+--- ' ;;
        3) hand='   \|/   ' ;;
        *) hand='    |    ' ;;
    esac
    printf '%s%s%s\n' "$C1" "$BOLD" "        MPlanetarians Alarm Clock"
    printf '%s%s%s\n' "$C2" "" "        Wake Up Edition  ·  Version ${APP_VERSION}"
    printf '%s%s\n' "$C3" "                 ┌─────────┐"
    printf '%s%s\n' "$C3" "                 │    │    │"
    printf '%s%s\n' "$C1" "                 │${hand}│"
    printf '%s%s\n' "$C3" "                 │    │    │"
    printf '%s%s%s\n' "$C3" "                 └─────────┘"
    printf '%sby %s%s\n' "$DIM" "$APP_AUTHOR" "$RESET"
}

animate_logo() {
    local i
    if [[ ! -t 1 || "${MPAC_NO_ANIM:-}" == "1" ]]; then
        draw_logo 0
        return 0
    fi
    tput civis 2>/dev/null || true
    for i in 0 1 2 3 0 1 2; do
        printf '\033[H'
        draw_logo "$i"
        sleep 0.12
    done
    tput cnorm 2>/dev/null || true
}

# --- small helpers ----------------------------------------------------------

enabled() {
    [[ "$(cfg_get ENABLED yes)" != "no" ]]
}

fmt_duration() {
    local seconds="$1" h m s
    h=$((seconds / 3600))
    m=$(((seconds % 3600) / 60))
    s=$((seconds % 60))
    if (( h > 0 )); then
        printf '%dh %dm %02ds' "$h" "$m" "$s"
    else
        printf '%dm %02ds' "$m" "$s"
    fi
}

parse_time() {
    local raw="${1,,}" ampm="" hour minute
    raw="${raw//[[:space:]]/}"
    if [[ "$raw" == *am ]]; then
        ampm="am"; raw="${raw%am}"
    elif [[ "$raw" == *pm ]]; then
        ampm="pm"; raw="${raw%pm}"
    fi
    if [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        hour=$((10#${BASH_REMATCH[1]})); minute=$((10#${BASH_REMATCH[2]}))
    elif [[ "$raw" =~ ^([0-9]{1,2})([0-9]{2})$ ]]; then
        hour=$((10#${BASH_REMATCH[1]})); minute=$((10#${BASH_REMATCH[2]}))
    else
        return 1
    fi
    if [[ -n "$ampm" ]]; then
        (( hour > 12 || hour < 1 )) && return 1
        if [[ "$ampm" == "am" && "$hour" -eq 12 ]]; then hour=0
        elif [[ "$ampm" == "pm" && "$hour" -lt 12 ]]; then hour=$((hour + 12)); fi
    fi
    (( hour > 23 || minute > 59 )) && return 1
    printf '%02d:%02d\n' "$hour" "$minute"
}

validate_volume() {
    local volume="$1"
    [[ "$volume" =~ ^[0-9]+$ ]] || return 1
    (( volume >= 1 && volume <= 150 )) || return 1
    printf '%s\n' "$volume"
}

last_bash_command() {
    local hist="${HISTFILE:-$HOME/.bash_history}" line cmd=""
    if [[ -f "$hist" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            case "$line" in
                *mplanetarians-alarm*|*/alarm.sh*) continue ;;
            esac
            cmd="$line"
        done <"$hist"
    fi
    if [[ -z "$cmd" ]]; then
        cmd="$(ps -u "$USER" -o etimes=,args= 2>/dev/null | awk '$2=="bash" || $2=="-bash" {next} {print $1"\t"$0}' | sort -n | awk -F'\t' 'END{print $2}' || true)"
    fi
    printf '%s\n' "${cmd:-none recorded}"
}

show_footer() {
    printf '\n%s%s\n' "$DIM" "────────────────────────────────────────────────────────────"
    printf 'Last Bash command: %s\n' "$(last_bash_command)"
    printf 'Kernel: %s%s\n' "$(uname -a)" "$RESET"
}

# --- archives and players ---------------------------------------------------

is_cloud_path() {
    local path="$1" src target fstype
    case "$path" in
        *GoogleDrive*|*google-drive*|*rclone*) return 0 ;;
    esac
    [[ -r /proc/mounts ]] || return 1
    while read -r src target fstype _; do
        [[ "$fstype" == *rclone* ]] || continue
        target="${target//\\040/ }"
        [[ "$path" == "$target" || "$path" == "$target"/* ]] && return 0
    done < /proc/mounts
    return 1
}

mix_config_file() {
    local candidate
    local script_parent
    script_parent="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || true)"
    for candidate in \
        "$script_parent/config.env" \
        "$HOME/MP_Mix_Manager_v0.3/config.env" \
        "/var/home/mplanetarian/MP_Mix_Manager_v0.3/config.env" \
        "/home/mplanetarian/MP_Mix_Manager_v0.3/config.env"
    do
        [[ -f "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
    return 1
}

archive_dirs() {
    local cfg line key value extra part dir flac
    local -a dirs=()
    cfg="$(mix_config_file || true)"
    if [[ -n "$cfg" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ "$line" == *=* ]] || continue
            key="${line%%=*}"
            value="${line#*=}"
            value="${value%\"}"; value="${value#\"}"
            value="${value%\'}"; value="${value#\'}"
            if [[ "$key" == "MIX_ARCHIVE_DIR" && -n "$value" ]]; then
                dirs+=("$value")
            elif [[ "$key" == "EXTRA_MIX_ARCHIVE_DIRS" || "$key" == "MIX_ARCHIVE_DIRS" ]]; then
                extra="$value"
            fi
        done <"$cfg"
    fi
    if [[ -n "${extra:-}" ]]; then
        IFS=':;,' read -r -a parts <<<"${extra//,/:}"
        for part in "${parts[@]+"${parts[@]}"}"; do
            [[ -n "$part" ]] && dirs+=("$part")
        done
    fi
    dirs+=(
        "/run/media/${USER}/WD BLACK B/MIX_ARCHIVE"
        "/run/media/${USER}/DATA/MIX_ARCHIVE2"
    )
    local seen="|"
    for dir in "${dirs[@]+"${dirs[@]}"}"; do
        [[ -n "$dir" ]] || continue
        is_cloud_path "$dir" && continue
        if [[ -d "$dir/FLAC_CONVERTED_OUTPUTS" ]]; then
            flac="$dir/FLAC_CONVERTED_OUTPUTS"
        elif [[ -d "$dir" ]]; then
            flac="$dir"
        else
            continue
        fi
        is_cloud_path "$flac" && continue
        [[ "$seen" == *"|$flac|"* ]] && continue
        seen="${seen}${flac}|"
        printf '%s\n' "$flac"
    done
}

random_mix() {
    local avoid="${1:-}" dir file pick
    local -a pool=()
    while IFS= read -r dir; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r file; do
            [[ -n "$file" && "$file" != "$avoid" ]] && pool+=("$file")
        done < <(find "$dir" -maxdepth 1 -type f \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.m4a' \) 2>/dev/null)
    done < <(archive_dirs)
    ((${#pool[@]})) || return 1
    pick="${pool[RANDOM % ${#pool[@]}]}"
    printf '%s\n' "$pick"
}

choose_player() {
    local first second roll
    roll=$((RANDOM % 2))
    if (( roll == 0 )); then
        first="strawberry"; second="cliamp"
    else
        first="cliamp"; second="strawberry"
    fi
    if [[ "$first" == "cliamp" && -n "$CLIAMP_BIN" ]]; then
        printf 'cliamp\n'; return 0
    fi
    if [[ "$first" == "strawberry" ]] && command -v strawberry >/dev/null 2>&1; then
        printf 'strawberry\n'; return 0
    fi
    if [[ "$second" == "cliamp" && -n "$CLIAMP_BIN" ]]; then
        printf 'cliamp\n'; return 0
    fi
    if [[ "$second" == "strawberry" ]] && command -v strawberry >/dev/null 2>&1; then
        printf 'strawberry\n'; return 0
    fi
    return 1
}

ensure_cliamp() {
    [[ -n "$CLIAMP_BIN" ]] || return 1
    if "$CLIAMP_BIN" status --json >/dev/null 2>&1; then
        return 0
    fi
    "$CLIAMP_BIN" --daemon >/dev/null 2>&1 &
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        "$CLIAMP_BIN" status --json >/dev/null 2>&1 && return 0
        sleep 0.25
    done
    return 1
}

cliamp_is_ready() {
    "$CLIAMP_BIN" status --json 2>/dev/null | python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
except Exception:
    sys.exit(1)
track=(data.get("track") or {})
total=int(data.get("total") or 0)
path=str(track.get("path") or "")
sys.exit(0 if path or total>0 else 1)
'
}

ensure_strawberry() {
    command -v strawberry >/dev/null 2>&1 || return 1
    if qdbus org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlaybackStatus >/dev/null 2>&1; then
        return 0
    fi
    strawberry >/dev/null 2>&1 &
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
        qdbus org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlaybackStatus >/dev/null 2>&1 && return 0
        sleep 0.3
    done
    return 1
}

strawberry_is_ready() {
    qdbus org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2.Player Metadata 2>/dev/null | grep -q 'xesam:url' && return 0
    local active
    active="$(qdbus org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Playlists.ActivePlaylist 2>/dev/null || true)"
    [[ -n "$active" && "$active" != *"/0"* && "$active" != "()" ]]
}

strawberry_shuffle_play() {
    dbus-send --session --dest=org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 \
        org.freedesktop.DBus.Properties.Set string:org.mpris.MediaPlayer2.Player string:Shuffle variant:boolean:true >/dev/null 2>&1 || true
    dbus-send --session --dest=org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 \
        org.freedesktop.DBus.Properties.Set string:org.mpris.MediaPlayer2.Player string:Volume variant:double:1.0 >/dev/null 2>&1 || true
    dbus-send --session --dest=org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 \
        org.mpris.MediaPlayer2.Player.Play >/dev/null 2>&1 || true
}

strawberry_open() {
    local file="$1" uri
    uri="file://$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri()[7:])' "$file")"
    dbus-send --session --dest=org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 \
        org.mpris.MediaPlayer2.Player.OpenUri "string:${uri}" >/dev/null 2>&1
    strawberry_shuffle_play
}

stop_players() {
    [[ -n "$CLIAMP_BIN" ]] && "$CLIAMP_BIN" stop >/dev/null 2>&1 || true
    dbus-send --session --dest=org.mpris.MediaPlayer2.strawberry /org/mpris/MediaPlayer2 \
        org.mpris.MediaPlayer2.Player.Stop >/dev/null 2>&1 || true
}

RAMP_SECONDS=180

ramp_percent() {
    local elapsed="$1" target="$2" snooze="${3:-no}" start
    if [[ "$snooze" == "yes" ]]; then
        printf '%s\n' "$target"
        return 0
    fi
    start=$((target / 5))
    (( start < 8 )) && start=8
    (( start > target )) && start=$target
    if (( elapsed >= RAMP_SECONDS )); then
        printf '%s\n' "$target"
    else
        printf '%s\n' "$(( start + (target - start) * elapsed / RAMP_SECONDS ))"
    fi
}

remember_volume() {
    local saved
    [[ -f "$VOLUME_FILE" ]] && return 0
    [[ "${MPAC_DRY_RUN:-}" == "1" ]] && return 0
    saved="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2; exit}')"
    [[ -n "${saved:-}" ]] && printf '%s\n' "$saved" >"$VOLUME_FILE"
}

set_sink_volume() {
    local volume="$1" last
    if [[ "${MPAC_DRY_RUN:-}" == "1" ]]; then
        log_line "DRY volume ${volume}%"
        printf '%s\n' "$volume" >"$STATE_DIR/current-volume"
        return 0
    fi
    command -v wpctl >/dev/null 2>&1 || return 1
    last="$(cat "$STATE_DIR/current-volume" 2>/dev/null || echo "")"
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 >/dev/null 2>&1 || true
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${volume}%" >/dev/null 2>&1 || true
    printf '%s\n' "$volume" >"$STATE_DIR/current-volume"
    if [[ -z "$last" || ( "$last" != "$volume" && $((volume % 10)) -eq 0 ) ]]; then
        log_line "VOLUME ${volume}%"
    fi
}

begin_volume() {
    local target="$1" snooze="${2:-no}"
    printf '%s\n' "$target" >"$STATE_DIR/target-volume"
    printf '%s\n' "$snooze" >"$STATE_DIR/snooze-ring"
    remember_volume
    set_sink_volume "$(ramp_percent 0 "$target" "$snooze")"
}

raise_volume() {
    begin_volume "${1:-100}" "yes"
}

restore_volume() {
    local saved
    [[ -f "$VOLUME_FILE" ]] || return 0
    saved="$(head -n 1 "$VOLUME_FILE")"
    rm -f "$VOLUME_FILE"
    [[ "${MPAC_DRY_RUN:-}" == "1" ]] && return 0
    [[ -n "$saved" ]] && wpctl set-volume @DEFAULT_AUDIO_SINK@ "$saved" >/dev/null 2>&1 || true
    log_line "VOLUME restored to ${saved}"
}

play_on_player() {
    local player="$1" forced="${2:-}"
    printf '%s\n' "$player" >"$STATE_DIR/current-player"
    if [[ "${MPAC_DRY_RUN:-}" == "1" ]]; then
        printf '%s\n' "${forced:-playlist}" >"$STATE_DIR/current-mix"
        log_line "DRY play player=${player} music=${forced:-playlist}"
        return 0
    fi
    if [[ "$player" == "cliamp" ]]; then
        ensure_cliamp || return 1
        "$CLIAMP_BIN" shuffle on >/dev/null 2>&1 || true
        "$CLIAMP_BIN" repeat all >/dev/null 2>&1 || true
        if [[ -n "$forced" ]]; then
            "$CLIAMP_BIN" queue "$forced" >/dev/null 2>&1 || return 1
            printf '%s\n' "$forced" >"$STATE_DIR/current-mix"
        elif cliamp_is_ready; then
            printf 'playlist\n' >"$STATE_DIR/current-mix"
        else
            forced="$(random_mix || true)"
            [[ -n "$forced" ]] || return 1
            "$CLIAMP_BIN" queue "$forced" >/dev/null 2>&1 || return 1
            printf '%s\n' "$forced" >"$STATE_DIR/current-mix"
        fi
        "$CLIAMP_BIN" play >/dev/null 2>&1 || return 1
        return 0
    fi
    ensure_strawberry || return 1
    if [[ -n "$forced" ]]; then
        strawberry_open "$forced" || return 1
        printf '%s\n' "$forced" >"$STATE_DIR/current-mix"
    elif strawberry_is_ready; then
        strawberry_shuffle_play
        printf 'playlist\n' >"$STATE_DIR/current-mix"
    else
        forced="$(random_mix || true)"
        [[ -n "$forced" ]] || return 1
        strawberry_open "$forced" || return 1
        printf '%s\n' "$forced" >"$STATE_DIR/current-mix"
    fi
}

start_music() {
    local forced="${1:-}" player
    player="$(choose_player)" || die "Neither Strawberry nor cliamp is installed"
    log_line "PLAYER chosen ${player}"
    if ! play_on_player "$player" "$forced"; then
        local other="strawberry"
        [[ "$player" == "strawberry" ]] && other="cliamp"
        log_line "PLAYER ${player} failed, trying ${other}"
        play_on_player "$other" "$forced" || die "Could not start playback"
    fi
    log_line "PLAY $(cat "$STATE_DIR/current-player" 2>/dev/null) $(cat "$STATE_DIR/current-mix" 2>/dev/null)"
}

switch_mix() {
    local current next player
    current="$(cat "$STATE_DIR/current-mix" 2>/dev/null || true)"
    next="$(random_mix "$current" || true)"
    [[ -n "$next" ]] || { log_line "MIX switch failed, no local archive file"; return 1; }
    player="$(choose_player)" || return 1
    stop_players
    play_on_player "$player" "$next" || return 1
    log_line "MIX switch player=${player} file=${next}"
    printf 'A different mix is playing: %s\n' "$(basename "$next")"
}

# --- scheduling -------------------------------------------------------------

load_alarms() {
    ALARM_ROWS=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        ALARM_ROWS+=("$line")
    done <"$ALARM_FILE"
}

save_alarms() {
    local tmp row
    tmp="$(mktemp "$CONFIG_DIR/alarms.tsv.XXXXXX")"
    printf '# id\ttime\tdaily\tvolume\tmusic\n' >"$tmp"
    for row in "${ALARM_ROWS[@]+"${ALARM_ROWS[@]}"}"; do
        printf '%s\n' "$row" >>"$tmp"
    done
    mv "$tmp" "$ALARM_FILE"
}

split_alarm() {
    IFS=$'\t' read -r A_ID A_TIME A_DAILY A_VOLUME A_MUSIC <<<"$1"
}

unit_name() { printf 'mpac-%s\n' "$1"; }

next_occurrence() {
    local hhmm="$1" now target
    now="$(date '+%s')"
    target="$(date -d "today ${hhmm}:00" '+%s')"
    if (( target <= now )); then
        date -d "tomorrow ${hhmm}:00" '+%F %T'
    else
        date -d "today ${hhmm}:00" '+%F %T'
    fi
}

unschedule() {
    local id="$1" unit
    unit="$(unit_name "$id")"
    systemctl --user stop "${unit}.timer" "${unit}.service" >/dev/null 2>&1 || true
    systemctl --user reset-failed "${unit}.timer" "${unit}.service" >/dev/null 2>&1 || true
}

schedule_with_systemd() {
    local id="$1" hhmm="$2" daily="$3" unit calendar err
    unit="$(unit_name "$id")"
    unschedule "$id"
    if [[ "$daily" == "yes" ]]; then
        calendar="*-*-* ${hhmm}:00"
    else
        calendar="$(next_occurrence "$hhmm")"
    fi
    err="$(systemd-run --user \
        --unit="$unit" \
        --on-calendar="$calendar" \
        --timer-property=AccuracySec=1s \
        --timer-property=Persistent=true \
        --property=TimeoutStopSec=8 \
        --setenv=DISPLAY="${DISPLAY:-:0}" \
        --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
        --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        --description="${APP_NAME} ${hhmm}" \
        "$SCRIPT_PATH" ring "$id" 2>&1)" || { printf '%s\n' "$err" >&2; return 1; }
}

create_alarm() {
    local hhmm="$1" music="${2:-}" volume="${3:-100}" daily="${4:-no}" id row when
    enabled || printf 'The alarm clock is disabled. This alarm is saved and will wait until you enable it.\n'
    volume="$(validate_volume "$volume")" || die "Volume must be a number from 1 to 150"
    id="$(printf 'a%07d%03d' "$(( $(date '+%s') % 10000000 ))" "$((RANDOM % 1000))")"
    row="${id}"$'\t'"${hhmm}"$'\t'"${daily}"$'\t'"${volume}"$'\t'"${music}"
    load_alarms
    ALARM_ROWS+=("$row")
    save_alarms
    if enabled; then
        schedule_with_systemd "$id" "$hhmm" "$daily" || die "Could not schedule the alarm"
    fi
    if [[ "$daily" == "yes" ]]; then
        when="${hhmm} every day"
    else
        when="$(next_occurrence "$hhmm")"
    fi
    printf 'Alarm %s set for %s.\n' "$id" "$when"
    printf 'Volume: %s%%. Music: %s\n' "$volume" "${music:-player playlist, or a local archive mix}"
    log_line "SCHEDULE id=${id} time=${hhmm} daily=${daily} volume=${volume} music=${music:-auto}"
}

cmd_set() {
    local hhmm="" music="" volume="100" daily="no" parsed
    while (($#)); do
        case "$1" in
            --music) shift; music="${1:-}" ;;
            --volume) shift; volume="${1:-}" ;;
            --daily) daily="yes" ;;
            --once) daily="no" ;;
            *) [[ -z "$hhmm" ]] && hhmm="$1" || die "Unexpected argument: $1" ;;
        esac
        shift
    done
    [[ -n "$hhmm" ]] || die "Give a time, for example 07:30 or 6:45am"
    parsed="$(parse_time "$hhmm")" || die "Could not understand the time: $hhmm"
    create_alarm "$parsed" "$music" "$volume" "$daily"
}

cmd_list() {
    local row next count=0
    load_alarms
    if enabled; then
        printf 'Alarm clock: enabled\n'
    else
        printf 'Alarm clock: disabled\n'
    fi
    printf '%-14s %-8s %-8s %-8s %s\n' "ID" "TIME" "REPEAT" "VOLUME" "MUSIC"
    for row in "${ALARM_ROWS[@]+"${ALARM_ROWS[@]}"}"; do
        split_alarm "$row"
        count=$((count + 1))
        printf '%-14s %-8s %-8s %-8s %s\n' "$A_ID" "$A_TIME" \
            "$([[ "$A_DAILY" == yes ]] && printf daily || printf once)" \
            "${A_VOLUME}%" "${A_MUSIC:-auto}"
        next="$(systemctl --user show "$(unit_name "$A_ID").timer" -p NextElapseUSecRealtime --value 2>/dev/null || true)"
        [[ -n "$next" && "$next" != "n/a" && "$next" != "0" ]] && printf '  next: %s\n' "$next"
    done
    if (( count == 0 )); then
        printf 'No alarms saved.\n'
    fi
    return 0
}

cmd_cancel() {
    local needle="${1:-}" row kept=() removed=0
    [[ -n "$needle" ]] || die "Give an alarm ID, a time, or all"
    load_alarms
    if [[ "$needle" == "all" ]]; then
        for row in "${ALARM_ROWS[@]+"${ALARM_ROWS[@]}"}"; do
            split_alarm "$row"; unschedule "$A_ID"
        done
        unschedule snooze
        ALARM_ROWS=()
        save_alarms
        log_line "CANCEL all"
        printf 'All alarms cancelled.\n'
        return 0
    fi
    for row in "${ALARM_ROWS[@]+"${ALARM_ROWS[@]}"}"; do
        split_alarm "$row"
        if [[ "$A_ID" == "$needle" || "$A_TIME" == "$needle" ]]; then
            unschedule "$A_ID"
            removed=$((removed + 1))
            log_line "CANCEL ${A_ID}"
        else
            kept+=("$row")
        fi
    done
    (( removed > 0 )) || die "No alarm matches ${needle}"
    ALARM_ROWS=("${kept[@]+"${kept[@]}"}")
    save_alarms
    printf 'Cancelled %s alarm(s).\n' "$removed"
}

cmd_disable() {
    local row
    cfg_set ENABLED no
    load_alarms
    for row in "${ALARM_ROWS[@]+"${ALARM_ROWS[@]}"}"; do
        split_alarm "$row"; unschedule "$A_ID"
    done
    unschedule snooze
    printf 'The alarm clock is disabled. Saved alarms will not ring until you enable it.\n'
    log_line "DISABLE"
}

cmd_enable() {
    local row
    cfg_set ENABLED yes
    load_alarms
    for row in "${ALARM_ROWS[@]+"${ALARM_ROWS[@]}"}"; do
        split_alarm "$row"
        schedule_with_systemd "$A_ID" "$A_TIME" "$A_DAILY" || printf 'Could not reschedule %s.\n' "$A_ID"
    done
    printf 'The alarm clock is enabled.\n'
    log_line "ENABLE"
}

# --- wake, snooze, summary --------------------------------------------------

quiet_cleanup() {
    stop_players
    restore_volume
    rm -f "$RING_FILE" "$STATUS_FILE" "$REASON_FILE"
}

finish_wake() {
    local reason="${1:-stop}" start now seconds player mix switches
    mkdir "$STATE_DIR/wake.lock" 2>/dev/null || return 0
    start="$(cat "$STATE_DIR/watch-start" 2>/dev/null || date '+%s')"
    now="$(date '+%s')"
    seconds=$((now - start))
    (( seconds < 0 )) && seconds=0
    player="$(cat "$STATE_DIR/current-player" 2>/dev/null || echo unknown)"
    mix="$(cat "$STATE_DIR/current-mix" 2>/dev/null || echo unknown)"
    switches="$(cat "$STATE_DIR/mix-switches" 2>/dev/null || echo 0)"
    stop_players
    restore_volume
    rm -f "$RING_FILE" "$STATUS_FILE" "$REASON_FILE"
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$seconds" "$player" "$mix" "$switches" >>"$WAKE_FILE"
    log_line "WAKE reason=${reason} seconds=${seconds} player=${player} switches=${switches} mix=${mix}"
    write_summary "$seconds" >"$SUMMARY_FILE"
    cat "$SUMMARY_FILE"
    if [[ "$reason" != "snooze" ]]; then
        open_browser_on_right_display
        run_wake_task
    fi
    rm -rf "$STATE_DIR/wake.lock"
}

write_summary() {
    local seconds="$1" line count=0 total=0 prev avg diff word
    printf 'You deactivated the alarm after %s.\n' "$(fmt_duration "$seconds")"
    printf 'Earlier wake-ups:\n'
    while IFS=$'\t' read -r when secs _rest; do
        [[ -z "${when:-}" ]] && continue
        printf '  %s   %s\n' "$when" "$(fmt_duration "$secs")"
        total=$((total + secs))
        count=$((count + 1))
    done < <(head -n -1 "$WAKE_FILE" 2>/dev/null || true)
    if (( count == 0 )); then
        printf 'This is the first wake-up on record.\n'
        return 0
    fi
    avg=$((total / count))
    diff=$((seconds - avg))
    if (( diff > 0 )); then
        word="longer"
    elif (( diff < 0 )); then
        word="shorter"
        diff=$((-diff))
    else
        printf 'This matches your average of %s.\n' "$(fmt_duration "$avg")"
        return 0
    fi
    printf 'Your earlier average is %s. This morning was %s %s.\n' \
        "$(fmt_duration "$avg")" "$(fmt_duration "$diff")" "$word"
}

screen_to_the_right() {
    python3 - <<'PY'
import re, subprocess, sys
raw = subprocess.check_output(["kscreen-doctor", "-o"], text=True, errors="ignore")
raw = re.sub(r"\x1b\[[0-9;]*m", "", raw)
screens = []
cur = None
for line in raw.splitlines():
    if line.startswith("Output:"):
        parts = line.split()
        if len(parts) >= 3:
            cur = {"name": parts[2], "x": 0, "y": 0, "w": 0, "h": 0}
            screens.append(cur)
    elif line.startswith("Geometry:") and cur is not None:
        match = re.search(r"(-?\d+),(-?\d+)\s+(\d+)x(\d+)", line)
        if match:
            cur["x"], cur["y"], cur["w"], cur["h"] = (int(n) for n in match.groups())
if not screens:
    sys.exit(1)
try:
    active = subprocess.check_output(
        ["qdbus", "org.kde.KWin", "/KWin", "org.kde.KWin.activeOutputName"],
        text=True, errors="ignore",
    ).strip()
except Exception:
    active = ""
current = next((s for s in screens if s["name"] == active), None)
if current is None:
    current = min(screens, key=lambda s: (s["x"], s["y"]))
right = [
    s for s in screens
    if s["name"] != current["name"] and s["x"] >= current["x"] + max(current["w"] - 40, 1)
]
same_row = [
    s for s in right
    if not (s["y"] + s["h"] <= current["y"] or current["y"] + current["h"] <= s["y"])
]
pool = same_row or right
if not pool:
    print(current["name"])
    sys.exit(0)
pool.sort(key=lambda s: s["x"])
print(pool[0]["name"])
PY
}

install_browser_placer() {
    local screen="$1" js
    [[ -n "$screen" ]] || return 1
    command -v qdbus >/dev/null 2>&1 || return 1
    js="$STATE_DIR/place-browser.js"
    cat >"$js" <<EOF
var targetName = "${screen}";
var placed = false;
var deadline = Date.now() + 20000;
function targetScreen() {
    var screens = workspace.screenOrder || [];
    for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === targetName) {
            return screens[i];
        }
    }
    return null;
}
function isBrowser(window) {
    var name = ((window.resourceName || "") + " " + (window.resourceClass || "") + " " + (window.caption || "")).toLowerCase();
    return name.indexOf("chrome") !== -1 || name.indexOf("chromium") !== -1 || name.indexOf("firefox") !== -1 || name.indexOf("brave") !== -1;
}
function place(window) {
    if (placed || Date.now() > deadline || !window.normalWindow || !isBrowser(window)) {
        return;
    }
    var screen = targetScreen();
    if (!screen) {
        return;
    }
    placed = true;
    try {
        window.output = screen;
    } catch (err) {}
    try {
        var geo = screen.geometry;
        window.frameGeometry = {
            x: geo.x + 48,
            y: geo.y + 48,
            width: Math.max(960, geo.width - 96),
            height: Math.max(640, geo.height - 96)
        };
    } catch (err2) {}
}
workspace.windowAdded.connect(place);
EOF
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "mpac-place-browser" >/dev/null 2>&1 || true
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$js" "mpac-place-browser" >/dev/null 2>&1 || return 1
    qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1 || return 1
    ( sleep 25; qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "mpac-place-browser" >/dev/null 2>&1 || true ) &
    disown || true
}

default_browser_launch() {
    local url="${1:-}" desktop exec_line bin
    desktop="$(xdg-settings get default-web-browser 2>/dev/null || true)"
    [[ -n "$desktop" ]] || desktop="$(xdg-mime query default x-scheme-handler/http 2>/dev/null || true)"
    [[ -n "$desktop" ]] || desktop="chrome.desktop"
    if [[ -x "$HOME/.local/bin/launch-chrome" && "$desktop" == *chrome* ]]; then
        if [[ -n "$url" ]]; then
            "$HOME/.local/bin/launch-chrome" "$url" >/dev/null 2>&1 &
        else
            "$HOME/.local/bin/launch-chrome" >/dev/null 2>&1 &
        fi
        disown || true
        return 0
    fi
    if [[ -n "$url" ]]; then
        gtk-launch "$desktop" "$url" >/dev/null 2>&1 && return 0
        xdg-open "$url" >/dev/null 2>&1 &
        disown || true
        return 0
    fi
    gtk-launch "$desktop" >/dev/null 2>&1 &
    disown || true
}

open_browser_on_right_display() {
    local screen url
    url="$(cfg_get WAKE_ARG "")"
    [[ "$(cfg_get WAKE_KIND none)" == "browser" ]] || url=""
    if [[ "${MPAC_DRY_RUN:-}" == "1" ]]; then
        screen="$(screen_to_the_right 2>/dev/null || true)"
        log_line "DRY browser screen=${screen:-unknown} url=${url:-startup}"
        printf 'Dry run: would open the default browser on %s.\n' "${screen:-the display to the right}"
        return 0
    fi
    screen="$(screen_to_the_right 2>/dev/null || true)"
    log_line "BROWSER screen=${screen:-unknown} url=${url:-startup}"
    [[ -n "$screen" ]] && install_browser_placer "$screen" || true
    default_browser_launch "$url"
    printf 'Opening the default browser on %s.\n' "${screen:-the display to the right}"
}

run_wake_task() {
    local kind arg
    kind="$(cfg_get WAKE_KIND none)"
    arg="$(cfg_get WAKE_ARG "")"
    # The browser is opened on the display to the right. A console is the only extra action.
    [[ "$kind" == "console" ]] || return 0
    log_line "WAKE_TASK run console"
    if [[ "${MPAC_DRY_RUN:-}" == "1" ]]; then
        printf 'Dry run: would open a console window.\n'
        return 0
    fi
    case "$kind" in
        console)
            if command -v konsole >/dev/null 2>&1; then
                konsole --separate >/dev/null 2>&1 &
            elif command -v gnome-terminal >/dev/null 2>&1; then
                gnome-terminal >/dev/null 2>&1 &
            elif command -v xterm >/dev/null 2>&1; then
                xterm >/dev/null 2>&1 &
            fi
            ;;
    esac
    disown || true
}

cmd_wake_task() {
    local choice="${1:-}" url
    if [[ -z "$choice" ]]; then
        printf 'One wake-up action is allowed. It runs when you stop the alarm.\n'
        printf 'Current: %s %s\n' "$(cfg_get WAKE_KIND none)" "$(cfg_get WAKE_ARG "")"
        printf '  1) Open a web browser\n'
        printf '  2) Open a console window\n'
        printf '  3) Remove the wake-up action\n'
        return 0
    fi
    case "$choice" in
        1|browser)
            url="${2:-}"
            cfg_set WAKE_KIND browser
            cfg_set WAKE_ARG "$url"
            printf 'Wake-up action: open a web browser%s\n' "${url:+ at $url}"
            ;;
        2|console)
            cfg_set WAKE_KIND console
            cfg_set WAKE_ARG ""
            printf 'Wake-up action: open one console window.\n'
            ;;
        3|none|clear)
            cfg_set WAKE_KIND none
            cfg_set WAKE_ARG ""
            printf 'Wake-up action removed.\n'
            ;;
        *) die "Choose browser, console, or clear" ;;
    esac
}

cmd_snooze() {
    local minutes="${1:-5}"
    [[ "$minutes" =~ ^[0-9]+$ ]] || die "Snooze minutes must be a number"
    (( minutes >= 1 && minutes <= 180 )) || die "Snooze must be from 1 to 180 minutes"
    [[ -f "$RING_FILE" ]] || die "Nothing is ringing."
    printf 'snooze\n' >"$REASON_FILE"
    printf 'yes\n' >"$STATE_DIR/snooze-next"
    systemctl --user stop "$(unit_name "$(head -n 1 "$RING_FILE")").service" >/dev/null 2>&1 || true
    quiet_cleanup
    unschedule snooze
    systemd-run --user \
        --unit="$(unit_name snooze)" \
        --on-active="${minutes}min" \
        --timer-property=AccuracySec=1s \
        --property=TimeoutStopSec=8 \
        --setenv=DISPLAY="${DISPLAY:-:0}" \
        --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
        --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        --description="${APP_NAME} snooze" \
        "$SCRIPT_PATH" ring "$(cat "$STATE_DIR/last-id" 2>/dev/null || echo snooze)" >/dev/null 2>&1 \
        || die "Could not schedule the snooze"
    printf 'Snoozing for %s minute(s). It will ring again at %s.\n' \
        "$minutes" "$(date -d "+${minutes} minutes" '+%H:%M')"
    log_line "SNOOZE ${minutes}"
}

on_ring_signal() {
    local reason
    reason="$(cat "$REASON_FILE" 2>/dev/null || echo stop)"
    if [[ "$reason" == "snooze" ]]; then
        quiet_cleanup
        exit 0
    fi
    finish_wake "$reason"
    exit 0
}

watch_loop() {
    local start now origin x y ox oy dx dy idle mark switches=0 target snooze vol
    start="$(date '+%s')"
    printf '%s\n' "$start" >"$STATE_DIR/watch-start"
    printf '0\n' >"$STATE_DIR/mix-switches"
    mark="$start"
    origin="$(xdotool getmouselocation --shell 2>/dev/null || true)"
    ox="$(printf '%s\n' "$origin" | awk -F= '/^X=/{print $2}')"
    oy="$(printf '%s\n' "$origin" | awk -F= '/^Y=/{print $2}')"
    ox="${ox:-0}"; oy="${oy:-0}"
    trap on_ring_signal TERM INT HUP
    while [[ -f "$RING_FILE" ]]; do
        now="$(date '+%s')"
        origin="$(xdotool getmouselocation --shell 2>/dev/null || true)"
        x="$(printf '%s\n' "$origin" | awk -F= '/^X=/{print $2}')"
        y="$(printf '%s\n' "$origin" | awk -F= '/^Y=/{print $2}')"
        x="${x:-$ox}"; y="${y:-$oy}"
        dx=$((x - ox)); dy=$((y - oy))
        if (( dx * dx + dy * dy >= 64 )); then
            printf 'mouse\n' >"$REASON_FILE"
            finish_wake mouse
            return 0
        fi
        idle=$((now - mark))
        if (( now - mark >= IDLE_SECONDS )); then
            switch_mix || true
            switches=$((switches + 1))
            printf '%s\n' "$switches" >"$STATE_DIR/mix-switches"
            mark="$now"
            log_line "IDLE ${IDLE_SECONDS}s switch=${switches}"
        fi
        target="$(cat "$STATE_DIR/target-volume" 2>/dev/null || echo 100)"
        snooze="$(cat "$STATE_DIR/snooze-ring" 2>/dev/null || echo no)"
        vol="$(ramp_percent "$((now - start))" "$target" "$snooze")"
        set_sink_volume "$vol"
        printf 'elapsed=%s\nidle=%s\nswitches=%s\nplayer=%s\nmix=%s\nvolume=%s\ntarget=%s\nsnooze=%s\n' \
            "$((now - start))" "$idle" "$switches" \
            "$(cat "$STATE_DIR/current-player" 2>/dev/null || echo unknown)" \
            "$(cat "$STATE_DIR/current-mix" 2>/dev/null || echo unknown)" \
            "$vol" "$target" "$snooze" >"$STATUS_FILE"
        sleep 2
    done
}

cmd_display() {
    apply_theme
    while [[ -f "$RING_FILE" ]]; do
        printf '\033[H\033[J'
        draw_logo "$(( $(date +%S) % 4 ))"
        printf '\n%sAlarm watch%s\n' "$BOLD" "$RESET"
        if [[ -f "$STATUS_FILE" ]]; then
            # shellcheck disable=SC1090
            source "$STATUS_FILE"
            printf 'Awake timer: %s\n' "$(fmt_duration "${elapsed:-0}")"
            printf 'Mouse still for: %s\n' "$(fmt_duration "${idle:-0}")"
            printf 'Player: %s\n' "${player:-unknown}"
            printf 'Mix: %s\n' "${mix:-unknown}"
            printf 'Different mixes played because the mouse stayed still: %s\n' "${switches:-0}"
            if [[ "${snooze:-no}" == "yes" ]]; then
                printf 'Volume: %s%% (snooze, already at full)\n' "${volume:-100}"
            else
                printf 'Volume: %s%%, rising to %s%% over 3 minutes\n' "${volume:-0}" "${target:-100}"
            fi
        fi
        printf '\nMove the mouse to stop the alarm.\n'
        printf 'The default browser then opens on the display to the right.\n'
        printf 'If the mouse stays still for %s, a different mix plays.\n' "$(fmt_duration "$IDLE_SECONDS")"
        sleep 1
    done
    printf '\n'
    [[ -f "$SUMMARY_FILE" ]] && cat "$SUMMARY_FILE"
    printf '\nPress Enter to close this window.\n'
    read -r -t 90 _ || true
}

cmd_ring() {
    local id="${1:-}" row music=""
    [[ -n "$id" ]] || die "ring needs an alarm id"
    if ! enabled; then
        log_line "RING skipped, alarm clock disabled"
        exit 0
    fi
    row="$(awk -F'\t' -v id="$id" '$1==id {print; exit}' "$ALARM_FILE" || true)"
    if [[ -z "$row" && "$id" != "snooze" ]]; then
        log_line "RING ignored unknown ${id}"
        exit 0
    fi
    if [[ -n "$row" ]]; then
        split_alarm "$row"
        music="$A_MUSIC"
        printf '%s\n' "$A_ID" >"$STATE_DIR/last-id"
        if [[ "$A_DAILY" != "yes" ]]; then
            systemctl --user stop "$(unit_name "$A_ID").timer" >/dev/null 2>&1 || true
        fi
        if [[ -f "$STATE_DIR/snooze-next" ]]; then
            rm -f "$STATE_DIR/snooze-next"
            begin_volume "$A_VOLUME" yes
        else
            begin_volume "$A_VOLUME" no
        fi
    else
        if [[ -f "$STATE_DIR/snooze-next" ]]; then
            rm -f "$STATE_DIR/snooze-next"
            begin_volume "$(cfg_get VOLUME 100)" yes
        else
            begin_volume "$(cfg_get VOLUME 100)" no
        fi
    fi
    printf '%s\n' "${A_ID:-$id}" >"$RING_FILE"
    rm -f "$REASON_FILE" "$SUMMARY_FILE"
    rm -rf "$STATE_DIR/wake.lock"
    start_music "$music"
    if command -v konsole >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" || -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wayland-0" ]]; then
        konsole --separate --hide-menubar -p tabtitle='Alarm Clock' -e "$SCRIPT_PATH" display >/dev/null 2>&1 &
        disown || true
    fi
    log_line "RING start id=${id}"
    watch_loop
}

cmd_stop() {
    local reason
    [[ -f "$REASON_FILE" ]] || printf 'stop\n' >"$REASON_FILE"
    reason="$(cat "$REASON_FILE")"
    load_alarms
    local row
    for row in "${ALARM_ROWS[@]+"${ALARM_ROWS[@]}"}"; do
        split_alarm "$row"
        systemctl --user stop "$(unit_name "$A_ID").service" >/dev/null 2>&1 || true
    done
    systemctl --user stop "$(unit_name snooze).service" >/dev/null 2>&1 || true
    if [[ -f "$RING_FILE" ]]; then
        if [[ "$reason" == "snooze" ]]; then
            quiet_cleanup
        else
            finish_wake "$reason"
        fi
    else
        quiet_cleanup
        printf 'Alarm silenced.\n'
    fi
    log_line "STOP reason=${reason}"
}

# --- notes ------------------------------------------------------------------

cmd_note() {
    local action="${1:-list}" text tmp i=0 line kept=()
    case "$action" in
        add)
            shift
            text="$*"
            [[ -n "$text" ]] || die "Write the note after 'note add'"
            printf '%s\t%s\n' "$(date '+%F %T')" "$text" >>"$NOTES_FILE"
            log_line "NOTE add ${text}"
            printf 'Note saved.\n'
            ;;
        list)
            if [[ ! -s "$NOTES_FILE" ]]; then
                printf 'No notes yet.\n'
                return 0
            fi
            while IFS=$'\t' read -r when text; do
                i=$((i + 1))
                printf '%s) [%s] %s\n' "$i" "$when" "$text"
            done <"$NOTES_FILE"
            ;;
        delete)
            shift
            [[ "${1:-}" =~ ^[0-9]+$ ]] || die "Give the note number to delete"
            while IFS= read -r line; do
                i=$((i + 1))
                [[ "$i" == "$1" ]] && continue
                kept+=("$line")
            done <"$NOTES_FILE"
            tmp="$(mktemp)"
            printf '%s\n' "${kept[@]+"${kept[@]}"}" >"$tmp"
            mv "$tmp" "$NOTES_FILE"
            log_line "NOTE delete $1"
            printf 'Note removed.\n'
            ;;
        *) die "Use note add, note list, or note delete N" ;;
    esac
}

show_notes() {
    local i=0 when text
    printf '%sNotes%s\n' "$BOLD" "$RESET"
    if [[ ! -s "$NOTES_FILE" ]]; then
        printf '  No reminders yet. Use the menu to add one.\n'
        return 0
    fi
    while IFS=$'\t' read -r when text; do
        i=$((i + 1))
        (( i > 5 )) && break
        printf '  %s) %s\n' "$i" "$text"
    done <"$NOTES_FILE"
}

# --- morning brief ----------------------------------------------------------

daily_words() {
    local today cache phrase word define manline
    today="$(date '+%F')"
    cache="$STATE_DIR/brief-${today}.txt"
    if [[ -f "$cache" ]]; then
        cat "$cache"
        return 0
    fi
    phrase="$(curl -fsS --max-time 6 'https://zenquotes.io/api/random' 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)[0]
    print(d.get("q","").replace("\n"," ")+" — "+d.get("a",""))
except Exception:
    print("")' || true)"
    [[ -n "$phrase" ]] || phrase="Begin again, quietly and on purpose. — Morning note"
    word="$(curl -fsS --max-time 6 'https://random-word-api.herokuapp.com/word?number=1' 2>/dev/null | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin)[0])
except Exception:
    print("")' || true)"
    [[ -n "$word" ]] || word="clarity"
    define="$(curl -fsS --max-time 6 "https://api.dictionaryapi.dev/api/v2/entries/en/${word}" 2>/dev/null | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)[0]
    print(d["meanings"][0]["definitions"][0]["definition"])
except Exception:
    print("A word worth keeping nearby today.")' || true)"
    manline="$(timeout 12 man -k . 2>/dev/null | awk -F' - ' 'NF>=2 && length($1)<48 {print}' | shuf -n 1 || true)"
    [[ -n "$manline" ]] || manline="printf (1) - format and print data"
    {
        printf 'PHRASE\t%s\n' "$phrase"
        printf 'WORD\t%s\n' "$word"
        printf 'DEFINE\t%s\n' "$define"
        printf 'MAN\t%s\n' "$manline"
    } | tee "$cache"
}

show_daily_words() {
    local kind rest
    while IFS=$'\t' read -r kind rest; do
        case "$kind" in
            PHRASE) printf '%sPhrase of the day%s\n  %s\n' "$BOLD" "$RESET" "$rest" ;;
            WORD) printf '%sWord of the day%s\n  %s\n' "$BOLD" "$RESET" "$rest" ;;
            DEFINE) printf '  %s\n' "$rest" ;;
            MAN)
                printf '%sManual page%s\n  %s\n' "$BOLD" "$RESET" "${rest%% - *}"
                printf '  %s\n' "${rest#* - }"
                ;;
        esac
    done < <(daily_words)
}

show_system() {
    printf '%sNow%s  %s\n' "$BOLD" "$RESET" "$(date '+%A %d %B %Y, %H:%M:%S %Z')"
    printf '%sUptime%s  %s\n' "$BOLD" "$RESET" "$(uptime -p 2>/dev/null || uptime)"
    printf '%sCPU%s  %s  (%s cores, load %s)\n' "$BOLD" "$RESET" \
        "$(awk -F: '/model name/{gsub(/^ /,"",$2); print $2; exit}' /proc/cpuinfo)" \
        "$(nproc)" "$(cut -d' ' -f1-3 /proc/loadavg)"
    awk '/MemTotal|MemAvailable/{printf "%s %s\n", $1, $2}' /proc/meminfo | paste -sd' ' - | awk '{printf "\033[1mMemory\033[0m  total %.1f GiB, available %.1f GiB\n", $2/1024/1024, $4/1024/1024}'
    printf '%sDisk%s\n' "$BOLD" "$RESET"
    df -hP -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | awk 'NR==1 || $6=="/" || $6 ~ /run\/media/ {print "  "$0}' | head -n 6
    if command -v nvidia-smi >/dev/null 2>&1; then
        printf '%sGPU%s  %s\n' "$BOLD" "$RESET" "$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null | head -n 1)"
    else
        printf '%sGPU%s  %s\n' "$BOLD" "$RESET" "$(lspci 2>/dev/null | awk -F: '/VGA|3D/{print $NF; exit}')"
    fi
    printf '%sUSB%s\n' "$BOLD" "$RESET"
    lsusb 2>/dev/null | head -n 8 | sed 's/^/  /'
    printf '%sMonitors%s\n' "$BOLD" "$RESET"
    if command -v kscreen-doctor >/dev/null 2>&1; then
        kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '
            /^Output:/ {if (n) printf "  %s %s  %s  %s\n", n, name, mode, geo; n=$2; name=$3; mode=""; geo=""}
            /Modes:/ {if (match($0, /[0-9]+x[0-9]+@[0-9.]+[!*]*/)) mode=substr($0, RSTART, RLENGTH)}
            /^Geometry:/ {geo=$2}
            END {if (n) printf "  %s %s  %s  %s\n", n, name, mode, geo}
        '
    else
        xrandr --query 2>/dev/null | awk '/ connected/{print "  "$0}' | head -n 4
    fi
}

show_recent_apps() {
    printf '%sLast desktop applications%s\n' "$BOLD" "$RESET"
    python3 - <<'PY' || printf '  No recent desktop applications are recorded yet.\n'
import os, xml.etree.ElementTree as ET
path=os.path.expanduser("~/.local/share/recently-used.xbel")
ns="{http://www.freedesktop.org/standards/desktop-bookmarks}"
found=[]
if os.path.isfile(path):
    root=ET.parse(path).getroot()
    for app in root.findall(f".//{ns}application"):
        found.append((app.attrib.get("modified",""), app.attrib.get("name","")))
found.sort(reverse=True)
seen=set(); shown=0
for _when, name in found:
    if not name or name in seen:
        continue
    seen.add(name)
    shown += 1
    print(f"  {shown}) {name}")
    if shown==3:
        break
if shown==0:
    raise SystemExit(1)
PY
}

show_overnight_errors() {
    local lines
    printf '%sOvernight errors%s\n' "$BOLD" "$RESET"
    lines="$(journalctl -p err --since 'yesterday 21:00' --no-pager -o cat 2>/dev/null | awk '
        BEGIN{IGNORECASE=1}
        /bpf-restrict-fs|zram-generator|systemd-oomd|ECC is disabled|audit/ {next}
        /out of memory|oom-kill|i\/o error|segfault|kernel panic|oops|BUG:|corrupt|nvrm|xid|ext4-fs error|btrfs error|critical temperature|nvme.*reset/ {print}
    ' | awk '!seen[$0]++' | head -n 6)"
    if [[ -z "$lines" ]]; then
        printf '  No important overnight errors.\n'
    else
        printf '%s\n' "$lines" | sed 's/^/  /'
    fi
}

show_breakfast() {
    local -a meals=(
        "Oats with berries, yoghurt, and a glass of water"
        "Eggs with wholegrain toast and fruit"
        "Plain yoghurt, banana, and a handful of nuts"
        "Porridge with cinnamon and sliced apple"
        "Smoked fish or beans on toast, plus tea"
        "A smoothie of milk, banana, and oats"
    )
    printf '%sBreakfast%s\n' "$BOLD" "$RESET"
    printf '  %s\n' "${meals[RANDOM % ${#meals[@]}]}"
    printf '  %s\n' "${meals[RANDOM % ${#meals[@]}]}"
}

show_exercise() {
    printf '%sA short start%s\n' "$BOLD" "$RESET"
    printf '  1. March in place for one minute.\n'
    printf '  2. Ten slow squats, heels down.\n'
    printf '  3. Twenty seconds of easy arm circles.\n'
    printf '  4. Reach overhead and breathe for thirty seconds.\n'
    printf '  5. Drink a glass of water.\n'
}

show_weather() {
    local json
    printf '%sWeather today%s\n' "$BOLD" "$RESET"
    json="$(curl -fsS --max-time 8 'https://wttr.in/?format=j1' 2>/dev/null || true)"
    if [[ -z "$json" ]]; then
        printf '  Weather could not be fetched.\n'
        return 0
    fi
    printf '%s\n' "$json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
area = d["nearest_area"][0]["areaName"][0]["value"]
cur = d["current_condition"][0]
desc = cur["weatherDesc"][0]["value"]
print("  {}: {} C, {}".format(area, cur["temp_C"], desc))
day = d["weather"][0]
print("  Day: {}-{} C".format(day["mintempC"], day["maxtempC"]))
rain = False
for hour in day.get("hourly", []):
    raw = str(hour.get("time", "0")).zfill(4)
    label = raw[:2] + ":" + raw[2:]
    hdesc = hour["weatherDesc"][0]["value"]
    chance = int(hour.get("chanceofrain") or 0)
    print("  {}  {} C  {}  rain {}%".format(label, hour.get("tempC", "?"), hdesc, chance))
    low = hdesc.lower()
    if chance >= 40 or any(word in low for word in ("rain", "drizzle", "thunder", "shower")):
        rain = True
if rain:
    print("  ALERT: rain is expected today. Take a coat.")
else:
    print("  No rain alert for today.")
'
}

steam_games() {
    python3 - <<'PY'
import glob, os, re, random
roots=[]
vdf=os.path.expanduser("~/.local/share/Steam/steamapps/libraryfolders.vdf")
if os.path.isfile(vdf):
    text=open(vdf, errors="ignore").read()
    roots=re.findall(r'"path"\s+"([^"]+)"', text)
if not roots:
    roots=[os.path.expanduser("~/.local/share/Steam")]
skip=("runtime","proton","steamworks","redistribut","soundtrack","steamvr","benchmark","dedicated server")
games=[]
for root in roots:
    apps=os.path.join(root.replace("\\\\","/"), "steamapps")
    for path in glob.glob(os.path.join(apps, "appmanifest_*.acf")):
        text=open(path, errors="ignore").read()
        name=re.search(r'"name"\s+"([^"]+)"', text)
        app=re.search(r'"appid"\s+"([^"]+)"', text)
        if not name or not app:
            continue
        title=name.group(1)
        if any(word in title.lower() for word in skip):
            continue
        games.append((app.group(1), title))
random.shuffle(games)
for app, title in games[:3]:
    print(f"{app}\t{title}")
PY
}

show_steam() {
    local line count=0
    printf '%sFrom your Steam library%s\n' "$BOLD" "$RESET"
    if ! command -v steam >/dev/null 2>&1 && [[ ! -d "$HOME/.local/share/Steam" ]]; then
        printf '  Steam is not installed.\n'
        return 0
    fi
    STEAM_SUGGESTIONS=()
    while IFS=$'\t' read -r app title; do
        [[ -n "$title" ]] || continue
        count=$((count + 1))
        STEAM_SUGGESTIONS+=("${app}"$'\t'"${title}")
        printf '  %s) %s\n' "$count" "$title"
    done < <(steam_games)
    if (( count == 0 )); then
        printf '  No games were found in the Steam library.\n'
        return 0
    fi
    printf '  Would you like to play a game for breakfast?\n'
}

offer_steam_game() {
    local answer pick app title
    ((${#STEAM_SUGGESTIONS[@]})) || return 0
    [[ -t 0 ]] || return 0
    read -r -p "Play one of these for breakfast? [y/N]: " answer || true
    [[ "$answer" =~ ^[Yy]$ ]] || { log_line "STEAM declined"; return 0; }
    read -r -p "Which number? [1-${#STEAM_SUGGESTIONS[@]}]: " pick || true
    [[ "$pick" =~ ^[0-9]+$ ]] || return 0
    (( pick >= 1 && pick <= ${#STEAM_SUGGESTIONS[@]} )) || return 0
    IFS=$'\t' read -r app title <<<"${STEAM_SUGGESTIONS[$((pick - 1))]}"
    log_line "STEAM launch ${app} ${title}"
    printf 'Starting %s.\n' "$title"
    if [[ "${MPAC_DRY_RUN:-}" != "1" ]] && command -v steam >/dev/null 2>&1; then
        steam "steam://rungameid/${app}" >/dev/null 2>&1 &
        disown || true
    fi
}

show_screen() {
    apply_theme
    printf '\033[H\033[J' 2>/dev/null || true
    animate_logo
    printf '\n'
    if ! enabled; then
        printf '%sThe alarm clock is disabled. Saved alarms will not ring.%s\n\n' "$BOLD" "$RESET"
    fi
    show_daily_words
    printf '\n'
    show_system
    printf '\n'
    show_recent_apps
    printf '\n'
    show_overnight_errors
    printf '\n'
    show_notes
    printf '\n'
    printf '%s%sStart the day%s\n' "$C2" "$BOLD" "$RESET"
    show_breakfast
    show_exercise
    show_weather
    printf '\n'
    show_steam
    show_footer
    log_line "LOAD theme=$(cfg_get THEME midnight-ink) enabled=$(cfg_get ENABLED yes)"
}

# --- menu and usage ---------------------------------------------------------

usage() {
    cat <<EOF
$APP_NAME
Version $APP_VERSION by $APP_AUTHOR

  alarm.sh                     Open the morning screen and menu
  alarm.sh set TIME [options]  Schedule an alarm
  alarm.sh list                Show saved alarms
  alarm.sh cancel ID|all       Remove an alarm
  alarm.sh stop                Silence a ringing alarm
  alarm.sh snooze [MINUTES]    Ring again later (default 5)
  alarm.sh disable             Turn the whole alarm clock off
  alarm.sh enable              Turn the alarm clock back on
  alarm.sh theme [NAME]        Choose Midnight Ink, Warm Brass, Forest Hour, or Porcelain
  alarm.sh task browser [URL]  One wake-up action: open a browser
  alarm.sh task console        One wake-up action: open a console
  alarm.sh task clear          Remove the wake-up action
  alarm.sh note add TEXT       Save a reminder
  alarm.sh test                Play the alarm now, loudly

At alarm time the clock picks Strawberry or cliamp at random and unmutes the
speakers. The music starts quietly and reaches full volume after 3 minutes.
Snooze plays at full volume immediately. It plays a shuffled mix from the
playlist already loaded in that player. If nothing is loaded, it adds one
random mix from the local archive disks. Google Drive is not used.

Move the mouse to stop the alarm. The default web browser then opens on the
display to the right. If the mouse stays still for 10 minutes, a different
local mix starts. Stopping the alarm records how long you took and compares
it with earlier mornings.

Clone: https://github.com/MPlanetarian/MPlanetarians_Alarm_Clock_v0.1.git
EOF
}

menu_loop() {
    local choice time_raw parsed music volume daily_answer
    show_screen
    printf '\n'
    offer_steam_game
    while true; do
        printf '\n%s%s\n' "$BOLD" "$APP_NAME"
        printf '1) Set an alarm\n'
        printf '2) List alarms\n'
        printf '3) Cancel an alarm\n'
        printf '4) Stop the music\n'
        printf '5) Snooze\n'
        printf '6) Test loud playback\n'
        printf '7) Theme\n'
        printf '8) Wake-up task\n'
        printf '9) Notes\n'
        printf '10) %s\n' "$(enabled && printf 'Disable the alarm clock' || printf 'Enable the alarm clock')"
        printf '11) Show the morning screen again\n'
        printf '12) Exit\n'
        read -r -p "Choose [1-12]: " choice || return 0
        case "$choice" in
            1)
                read -r -p "Time (07:30 or 6:45am): " time_raw || continue
                parsed="$(parse_time "$time_raw")" || { printf 'That time was not understood.\n'; continue; }
                read -r -p "Volume percent [100]: " volume || continue
                volume="${volume:-100}"
                read -r -p "Repeat every day? [y/N]: " daily_answer || continue
                if [[ "$daily_answer" =~ ^[Yy]$ ]]; then
                    ( create_alarm "$parsed" "" "$volume" yes )
                else
                    ( create_alarm "$parsed" "" "$volume" no )
                fi
                ;;
            2) cmd_list || true ;;
            3)
                read -r -p "Alarm ID, time, or all: " choice || continue
                ( cmd_cancel "$choice" ) || true
                ;;
            4) ( cmd_stop ) || true ;;
            5)
                read -r -p "Snooze minutes [5]: " choice || continue
                ( cmd_snooze "${choice:-5}" ) || true
                ;;
            6) ( cmd_test ) || true ;;
            7)
                cmd_theme
                read -r -p "Theme number or name: " choice || continue
                ( cmd_theme "$choice" ) || true
                apply_theme
                ;;
            8)
                cmd_wake_task
                read -r -p "1 browser, 2 console, 3 clear: " choice || continue
                if [[ "$choice" == "1" ]]; then
                    read -r -p "Address (empty for a blank window): " music || continue
                    ( cmd_wake_task browser "$music" ) || true
                else
                    ( cmd_wake_task "$choice" ) || true
                fi
                ;;
            9)
                read -r -p "add TEXT, list, or delete N: " choice || continue
                # shellcheck disable=SC2086
                ( cmd_note $choice ) || true
                ;;
            10)
                if enabled; then ( cmd_disable ); else ( cmd_enable ); fi
                ;;
            11) show_screen; offer_steam_game ;;
            12|q|Q) printf 'Good morning.\n'; return 0 ;;
            *) printf 'Choose a number from 1 to 12.\n' ;;
        esac
    done
}

cmd_test() {
    printf 'Testing %s. This turns the volume up and starts the chosen player.\n' "$APP_NAME"
    raise_volume "$(cfg_get VOLUME 100)"
    start_music ""
    printf 'Press Enter to stop the test.\n'
    read -r _
    printf 'stop\n' >"$REASON_FILE"
    cmd_stop
}

self_test() {
    local i straw=0 amp=0 player fails=0
    MPAC_NO_ANIM=1
    apply_theme
    parse_time "6:45am" >/dev/null || { echo FAIL parse; fails=$((fails+1)); }
    [[ "$(parse_time "7:30pm")" == "19:30" ]] || { echo FAIL pm; fails=$((fails+1)); }
    for i in 1 2 3 4; do
        theme_title "$(cfg_get THEME midnight-ink)" >/dev/null
    done
    cfg_set THEME warm-brass
    cfg_set THEME forest-hour
    cfg_set THEME porcelain
    cfg_set THEME midnight-ink
    for i in $(seq 1 40); do
        player="$(choose_player || true)"
        [[ "$player" == "strawberry" ]] && straw=$((straw+1))
        [[ "$player" == "cliamp" ]] && amp=$((amp+1))
    done
    echo "player rolls strawberry=${straw} cliamp=${amp}"
    (( straw > 5 && amp > 5 )) || { echo FAIL player balance; fails=$((fails+1)); }
    is_cloud_path "/var/home/mplanetarian/GoogleDrive/MIX_ARCHIVE" || { echo FAIL cloud; fails=$((fails+1)); }
    is_cloud_path "/run/media/${USER}/WD BLACK B/MIX_ARCHIVE" && { echo FAIL local marked cloud; fails=$((fails+1)); }
    cmd_note add "self-test reminder" >/dev/null
    cmd_note list | grep -q "self-test reminder" || { echo FAIL note; fails=$((fails+1)); }
    cmd_wake_task browser "https://example.com" >/dev/null
    cmd_wake_task console >/dev/null
    [[ "$(cfg_get WAKE_KIND none)" == "console" ]] || { echo FAIL single task; fails=$((fails+1)); }
    cmd_wake_task clear >/dev/null
    printf '2026-09-24 07:10:00\t480\tstrawberry\tplaylist\t0\n' >"$WAKE_FILE"
    printf '2026-09-25 07:12:00\t600\tcliamp\tmix.flac\t1\n' >>"$WAKE_FILE"
    write_summary 600 | grep -q "average" || { echo FAIL summary; fails=$((fails+1)); }
    show_footer | grep -q "Kernel:" || { echo FAIL footer; fails=$((fails+1)); }
    draw_logo 1 | grep -q "0.1" || { echo FAIL logo; fails=$((fails+1)); }
    [[ "$(ramp_percent 0 100 no)" == "20" ]] || { echo "FAIL ramp-start $(ramp_percent 0 100 no)"; fails=$((fails+1)); }
    [[ "$(ramp_percent 90 100 no)" == "60" ]] || { echo "FAIL ramp-mid $(ramp_percent 90 100 no)"; fails=$((fails+1)); }
    [[ "$(ramp_percent 180 100 no)" == "100" ]] || { echo FAIL ramp-full; fails=$((fails+1)); }
    [[ "$(ramp_percent 5 100 yes)" == "100" ]] || { echo FAIL ramp-snooze; fails=$((fails+1)); }
    screen_to_the_right >/dev/null || { echo FAIL screen; fails=$((fails+1)); }
    show_breakfast >/dev/null
    show_exercise | grep -q "squats" || { echo FAIL exercise; fails=$((fails+1)); }
    steam_games | awk 'END{exit !(NR>=1)}' || echo "steam list empty or filtered"
    cmd_set 07:15 --volume 40 --once >/dev/null
    list_out="$(cmd_list)"
    printf '%s\n' "$list_out" | grep -q "07:15" || { echo FAIL set; printf '%s\n' "$list_out"; fails=$((fails+1)); }
    cmd_disable >/dev/null
    enabled && { echo FAIL disable; fails=$((fails+1)); }
    cmd_enable >/dev/null
    enabled || { echo FAIL enable; fails=$((fails+1)); }
    cmd_cancel all >/dev/null
    systemctl --user list-timers 'mpac-*' --no-pager | grep -q mpac && { echo FAIL timer leftover; fails=$((fails+1)); }
    if (( fails == 0 )); then
        echo SELF_TEST_OK
        return 0
    fi
    echo "SELF_TEST_FAILS=$fails"
    return 1
}

main() {
    local cmd="${1:-menu}"
    apply_theme
    if (($#)); then shift; fi
    case "$cmd" in
        menu) menu_loop ;;
        help|-h|--help) usage ;;
        version|--version) printf '%s %s\n' "$APP_NAME" "$APP_VERSION" ;;
        set) cmd_set "$@" ;;
        list|ls) cmd_list ;;
        cancel|rm|delete) cmd_cancel "$@" ;;
        stop|silence) cmd_stop ;;
        snooze) cmd_snooze "$@" ;;
        disable) cmd_disable ;;
        enable) cmd_enable ;;
        theme) cmd_theme "$@" ;;
        task|wake-task) cmd_wake_task "$@" ;;
        note) cmd_note "$@" ;;
        test) cmd_test "$@" ;;
        ring) cmd_ring "$@" ;;
        display) cmd_display ;;
        brief)
            MPAC_NO_ANIM=1
            show_screen
            ;;
        self-test) self_test ;;
        *) usage >&2; exit 1 ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
