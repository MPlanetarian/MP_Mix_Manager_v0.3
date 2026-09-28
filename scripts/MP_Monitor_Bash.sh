#!/bin/bash
# MP_Monitor_Bash.sh
# Live system monitor for macOS and Linux.
# Shows the last 10 shell commands, top processes, and CPU, memory, disk,
# Wi-Fi, GPU, and temperature readings. Each refresh appends one snapshot
# to the history log and never truncates it.
#
# Usage:
#   MP_Monitor_Bash.sh [--refresh|-r 2|5|10] [--once]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# When this file lives in scripts/, keep the log beside the project root.
case "$SCRIPT_DIR" in
    */scripts) HISTORY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)" ;;
    *) HISTORY_DIR="$SCRIPT_DIR" ;;
esac
HISTORY_FILE="${HISTORY_DIR}/running_history.log"
touch "$HISTORY_FILE"

OS_NAME="$(uname -s)"
case "$OS_NAME" in
    Darwin*) OS_KIND="macos" ;;
    Linux*)  OS_KIND="linux" ;;
    *)       OS_KIND="other" ;;
esac

REFRESH=10
ONCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --refresh|-r)
            shift
            case "${1:-}" in
                2|5|10) REFRESH="$1" ;;
                *) echo "Invalid refresh interval. Use 2, 5, or 10 seconds." >&2; exit 1 ;;
            esac
            ;;
        --once)
            ONCE=1
            ;;
        -h|--help)
            echo "Usage: $0 [--refresh|-r 2|5|10] [--once]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--refresh|-r 2|5|10] [--once]" >&2
            exit 1
            ;;
    esac
    shift
done

printf '\033]0;%s\007' "Monitor System Processes and Bash Commands with System Info"

human_bytes() {
    awk -v n="${1:-0}" 'BEGIN {
        split("B K M G T", u, " ")
        i = 1
        n += 0
        while (n >= 1024 && i < 5) { n /= 1024; i++ }
        if (i == 1) printf "%d%s", n, u[i]
        else printf "%.1f%s", n, u[i]
    }'
}

show_last_10_commands() {
    local hist_file="" hist_label="shell"
    if [ -n "${HISTFILE:-}" ] && [ -f "$HISTFILE" ]; then
        hist_file="$HISTFILE"
    elif [ -f "$HOME/.bash_history" ]; then
        hist_file="$HOME/.bash_history"
        hist_label="bash"
    elif [ -f "$HOME/.zsh_history" ]; then
        hist_file="$HOME/.zsh_history"
        hist_label="zsh"
    fi

    echo "=== Last 10 Shell Commands (${hist_label}) ==="
    if [ -z "$hist_file" ]; then
        echo "(no shell history file found)"
        return 0
    fi

    awk '
        {
            line = $0
            sub(/\r$/, "", line)
            if (line ~ /^: [0-9]+:[0-9]+;/) sub(/^: [0-9]+:[0-9]+;/, "", line)
            if (cont != "") {
                line = cont line
                cont = ""
            }
            if (line ~ /\\$/) {
                sub(/\\$/, "", line)
                cont = line
                next
            }
            if (line != "") cmds[++n] = line
        }
        END {
            start = n - 9
            if (start < 1) start = 1
            for (i = start; i <= n; i++) print cmds[i]
            if (n == 0) print "(history file is empty)"
        }
    ' "$hist_file"
}

show_top_processes() {
    echo "=== Top System Processes ==="
    if [ "$OS_KIND" = "macos" ]; then
        ps -axo pid=,pcpu=,command= -r 2>/dev/null | head -n 10 | awk '
            {
                pid = $1
                cpu = $2
                cmd = substr($0, index($0, $3))
                if (length(cmd) > 72) cmd = substr(cmd, 1, 69) "..."
                printf "  %6s  %5s%%  %s\n", pid, cpu, cmd
            }
        '
    else
        ps -eo pid,pcpu,cmd --sort=-pcpu --no-headers 2>/dev/null | head -n 10 | awk '
            {
                pid = $1
                cpu = $2
                cmd = substr($0, index($0, $3))
                if (length(cmd) > 72) cmd = substr(cmd, 1, 69) "..."
                printf "  %6s  %5s%%  %s\n", pid, cpu, cmd
            }
        '
    fi
}

get_cpu_usage() {
    if [ "$OS_KIND" = "linux" ] && command -v mpstat >/dev/null 2>&1; then
        mpstat 1 1 | tail -1 | awk '{ printf "%.1f", 100 - $NF }'
        return 0
    fi
    if [ "$OS_KIND" = "linux" ]; then
        top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)|%Cpu/ {
            for (i = 1; i <= NF; i++) if ($i ~ /id/) { gsub(/[^0-9.]/, "", $i); printf "%.1f", 100 - $i; exit }
        }'
        return 0
    fi

    local ncpu
    ncpu="$(sysctl -n hw.ncpu 2>/dev/null || echo 1)"
    ps -A -o pcpu= 2>/dev/null | awk -v n="$ncpu" '
        { s += $1 }
        END {
            if (n < 1) n = 1
            u = s / n
            if (u < 0) u = 0
            if (u > 100) u = 100
            printf "%.1f", u
        }
    '
}

get_memory_usage() {
    if [ "$OS_KIND" != "macos" ] && command -v free >/dev/null 2>&1; then
        free -h | awk '/^Mem:/ { print $3 " / " $2 }'
        return 0
    fi
    if [ "$OS_KIND" = "macos" ]; then
        local total phys used_h
        total="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
        phys="$(top -l 1 -n 0 -s 0 2>/dev/null | awk '/PhysMem:/ { print; exit }')"
        used_h="$(printf '%s\n' "$phys" | awk '{ for (i = 1; i <= NF; i++) if ($i == "used") { print $(i - 1); exit } }')"
        if [ -n "$used_h" ]; then
            echo "${used_h} / $(human_bytes "$total")"
            return 0
        fi
        echo "n/a / $(human_bytes "$total")"
        return 0
    fi
    echo "n/a"
}

get_disk_usage() {
    df -h / 2>/dev/null | awk 'NR > 1 { print $5 " used (" $3 " / " $2 ")"; exit }'
}

get_wifi_status() {
    if [ "$OS_KIND" = "macos" ]; then
        local wifi_dev ssid radio
        wifi_dev="$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi|AirPort|WiFi/ { getline; if ($1 == "Device:") { print $2; exit } }')"
        if [ -n "$wifi_dev" ]; then
            ssid="$(ipconfig getsummary "$wifi_dev" 2>/dev/null | awk -F': ' '/^[[:space:]]*SSID :/ { gsub(/^ +| +$/, "", $2); print $2; exit }')"
        fi
        radio="$(osascript -l JavaScript <<'JS'
ObjC.import("CoreWLAN");
var client = $.CWWiFiClient.sharedWiFiClient;
var iface = client ? client.interface : null;
if (!iface || iface.isNil()) {
    "none";
} else {
    var rssi = Number(iface.rssiValue);
    var noise = Number(iface.noiseMeasurement);
    var rate = Number(iface.transmitRate);
    rssi + " " + noise + " " + rate;
}
JS
)"
        if [ "$radio" = "none" ] || [ -z "$radio" ]; then
            if [ -n "$ssid" ]; then
                echo "ESSID: ${ssid}"
            else
                echo "No wireless interface found"
            fi
            return 0
        fi
        local rssi noise rate quality
        rssi="$(printf '%s\n' "$radio" | awk '{ print $1 }')"
        noise="$(printf '%s\n' "$radio" | awk '{ print $2 }')"
        rate="$(printf '%s\n' "$radio" | awk '{ print $3 }')"
        if [ -z "$ssid" ] && [ "${rssi:-0}" -ge 0 ] 2>/dev/null; then
            echo "Not associated with a Wi-Fi network"
            return 0
        fi
        quality="$(awk -v r="${rssi:-0}" 'BEGIN { q = int((r + 100) * 70 / 60); if (q < 0) q = 0; if (q > 70) q = 70; print q }')"
        if [ -n "$ssid" ]; then
            echo "ESSID: ${ssid} | Signal: ${rssi}dBm | Noise: ${noise}dBm | Quality: ${quality}/70 | Rate: ${rate} Mbps"
        else
            echo "Signal: ${rssi}dBm | Noise: ${noise}dBm | Quality: ${quality}/70 | Rate: ${rate} Mbps"
        fi
        return 0
    fi

    if command -v nmcli >/dev/null 2>&1; then
        local nm
        nm="$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1 == "yes" && $2 != "" { print "ESSID: " $2 " | Signal: " $3 "%"; exit }')"
        if [ -n "$nm" ]; then
            echo "$nm"
            return 0
        fi
    fi

    if command -v iw >/dev/null 2>&1 && iw dev 2>/dev/null | grep -q "Interface"; then
        local iface quality signal essid
        iface="$(iw dev 2>/dev/null | awk '/Interface/ { print $2; exit }')"
        if [ -n "$iface" ] && command -v iwconfig >/dev/null 2>&1; then
            quality="$(iwconfig "$iface" 2>/dev/null | awk -F'=' '/Link Quality/ { split($2, a, "/"); print a[1]; exit }')"
            signal="$(iwconfig "$iface" 2>/dev/null | awk -F'=' '/Signal level/ { print $2; exit }' | awk '{ print $1 }')"
            essid="$(iwconfig "$iface" 2>/dev/null | awk -F'ESSID:' '/ESSID/ { gsub(/"/, "", $2); print $2; exit }')"
            echo "ESSID: ${essid:-n/a} | Signal: ${signal:-n/a}dBm | Quality: ${quality:-n/a}/70"
            return 0
        fi
        local iw_out
        iw_out="$(iw dev "$iface" link 2>/dev/null)"
        if [ -n "$iw_out" ]; then
            echo "$iw_out" | awk '
                /SSID:/ { ssid = $2 }
                /signal:/ { sig = $2 }
                END {
                    if (ssid == "") print "Not associated with a Wi-Fi network"
                    else print "ESSID: " ssid " | Signal: " sig "dBm"
                }
            '
            return 0
        fi
    fi

    echo "No wireless interface found"
}

get_gpu_info() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_temp gpu_util gpu_mem
        gpu_temp="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)"
        gpu_util="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)"
        gpu_mem="$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | awk 'NR == 1 { print $1 " / " $2 " MiB" }')"
        echo "GPU Temp: ${gpu_temp:-n/a}°C | Util: ${gpu_util:-n/a}% | Mem: ${gpu_mem:-n/a}"
        return 0
    fi

    if [ "$OS_KIND" = "macos" ]; then
        local stats util used alloc
        stats="$(ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null | tr ',' '\n')"
        util="$(printf '%s\n' "$stats" | awk -F= '/Device Utilization %/ { gsub(/[^0-9.]/, "", $2); print $2; exit }')"
        used="$(printf '%s\n' "$stats" | awk -F= '/"In use system memory"/ { gsub(/[^0-9]/, "", $2); print $2; exit }')"
        alloc="$(printf '%s\n' "$stats" | awk -F= '/"Alloc system memory"/ { gsub(/[^0-9]/, "", $2); print $2; exit }')"
        if [ -n "$util" ] || [ -n "$used" ]; then
            echo "Apple GPU | Util: ${util:-0}% | Mem: $(human_bytes "${used:-0}") / $(human_bytes "${alloc:-0}")"
            return 0
        fi
        echo "GPU statistics unavailable"
        return 0
    fi

    echo "GPU statistics unavailable"
}

# Print a temperature only when the tool returns a real reading.
# osx-cpu-temp reports 0.0°C on Apple Silicon when the SMC key is missing.
valid_temp() {
    local raw="$1"
    local num
    num="$(printf '%s' "$raw" | awk '{
        for (i = 1; i <= NF; i++) if ($i ~ /[0-9]/) { gsub(/[^0-9.]/, "", $i); print $i; exit }
    }')"
    case "$num" in
        ""|0|0.0|0.00) return 1 ;;
    esac
    printf '%s' "$num"
    return 0
}

get_temperature_info() {
    local parts="" piece num

    if [ "$OS_KIND" = "linux" ] && command -v sensors >/dev/null 2>&1; then
        piece="$(sensors 2>/dev/null | awk -F'[+°]' '/[Tt]emp/ { if ($2 != "") { printf "%s°C ", $2 } }' | head -n 1)"
        [ -n "$piece" ] && parts="sensors: ${piece}"
    fi

    if command -v nvidia-smi >/dev/null 2>&1; then
        num="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)"
        if num="$(valid_temp "$num")"; then
            parts="${parts:+$parts | }GPU: ${num}°C"
        fi
    fi

    if [ "$OS_KIND" = "macos" ] && command -v osx-cpu-temp >/dev/null 2>&1; then
        if num="$(valid_temp "$(osx-cpu-temp -c 2>/dev/null)")"; then
            parts="${parts:+$parts | }CPU: ${num}°C"
        fi
        if num="$(valid_temp "$(osx-cpu-temp -g 2>/dev/null)")"; then
            parts="${parts:+$parts | }GPU: ${num}°C"
        fi
    fi

    if [ -z "$parts" ] && [ "$OS_KIND" = "macos" ] && command -v sudo >/dev/null 2>&1; then
        piece="$(sudo -n powermetrics -s thermal -n 1 -i 200 2>/dev/null | awk '
            /temperature/ {
                if (match($0, /[0-9]+(\.[0-9]+)?/)) {
                    print substr($0, RSTART, RLENGTH)
                    exit
                }
            }
        ')"
        if num="$(valid_temp "$piece")"; then
            parts="CPU: ${num}°C"
        fi
    fi

    if [ -z "$parts" ]; then
        echo "unavailable"
    else
        echo "$parts"
    fi
}

get_fastfetch_info() {
    if command -v fastfetch >/dev/null 2>&1; then
        fastfetch -l none
        return 0
    fi
    if command -v neofetch >/dev/null 2>&1; then
        neofetch --off
        return 0
    fi

    echo "(fastfetch not installed — built-in summary)"
    if [ "$OS_KIND" = "macos" ]; then
        echo "OS:       macOS $(sw_vers -productVersion 2>/dev/null) ($(sw_vers -buildVersion 2>/dev/null))"
        echo "Host:     $(sysctl -n hw.model 2>/dev/null)"
        echo "CPU:      $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
        echo "Cores:    $(sysctl -n hw.ncpu 2>/dev/null)"
        echo "Memory:   $(human_bytes "$(sysctl -n hw.memsize 2>/dev/null)")"
        echo "Kernel:   $(uname -sr)"
    else
        local pretty=""
        if [ -f /etc/os-release ]; then
            pretty="$(awk -F= '/^PRETTY_NAME=/ { gsub(/"/, "", $2); print $2; exit }' /etc/os-release)"
        fi
        echo "OS:       ${pretty:-$(uname -s)}"
        echo "Host:     $(uname -n)"
        echo "Kernel:   $(uname -sr)"
        if [ -r /proc/cpuinfo ]; then
            awk -F: '/model name/ { gsub(/^ /, "", $2); print "CPU:      " $2; exit }' /proc/cpuinfo
        fi
        echo "Cores:    $(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo n/a)"
    fi
}

log_snapshot() {
    local stamp cpu mem disk wifi gpu temps top1
    stamp="$(date '+%Y-%m-%d %H:%M:%S')"
    cpu="$1"; mem="$2"; disk="$3"; wifi="$4"; gpu="$5"; temps="$6"
    if [ "$OS_KIND" = "macos" ]; then
        top1="$(ps -axo pid=,pcpu=,comm= -r 2>/dev/null | awk 'NR <= 3 { printf "%s:%s%%(%s) ", $1, $2, $3 }')"
    else
        top1="$(ps -eo pid,pcpu,comm --sort=-pcpu --no-headers 2>/dev/null | awk 'NR <= 3 { printf "%s:%s%%(%s) ", $1, $2, $3 }')"
    fi
    printf '%s | CPU %s%% | MEM %s | DISK %s | WIFI %s | GPU %s | TEMP %s | TOP %s\n' \
        "$stamp" "$cpu" "$mem" "$disk" "$wifi" "$gpu" "$temps" "$top1" >> "$HISTORY_FILE"
}

trap 'printf "\nMonitor stopped. History kept at %s\n" "$HISTORY_FILE"; exit 0' INT TERM

while true; do
    if [ -t 1 ]; then
        clear
    fi

    show_last_10_commands
    echo
    show_top_processes
    echo
    echo "=== Live System Usage ==="

    cpu_now="$(get_cpu_usage)"
    mem_now="$(get_memory_usage)"
    disk_now="$(get_disk_usage)"
    wifi_now="$(get_wifi_status)"
    gpu_now="$(get_gpu_info)"
    temp_now="$(get_temperature_info)"

    echo "CPU Usage:    ${cpu_now:-n/a}%"
    echo "Memory:       ${mem_now:-n/a}"
    echo "Disk:         ${disk_now:-n/a}"
    echo "Wi-Fi:        ${wifi_now:-n/a}"
    echo "GPU:          ${gpu_now:-n/a}"
    echo "Temperatures: ${temp_now:-n/a}"
    echo
    echo "System Info:"
    get_fastfetch_info
    echo
    echo "History log: ${HISTORY_FILE} (appended, never cleared)"
    echo "Press Ctrl+C to exit. Refreshing every ${REFRESH} second(s)..."

    log_snapshot "${cpu_now:-n/a}" "${mem_now:-n/a}" "${disk_now:-n/a}" \
        "${wifi_now:-n/a}" "${gpu_now:-n/a}" "${temp_now:-n/a}"

    if [ "$ONCE" -eq 1 ]; then
        break
    fi
    sleep "$REFRESH"
done
