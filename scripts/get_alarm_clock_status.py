#!/usr/bin/env python3
"""
scripts/get_alarm_clock_status.py
Inspects MPlanetarians Alarm Clock configuration, timers, state, and Steam integration,
providing formatted status banners for the Mix Archive Manager main dashboard.
"""

import os
import sys
import glob
import re
import datetime
import subprocess

def get_status_info():
    config_dir = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config") + "/mplanetarians-alarm-clock")
    state_dir = os.path.expanduser(os.environ.get("XDG_STATE_HOME", "~/.local/state") + "/mplanetarians-alarm-clock")

    settings_file = os.path.join(config_dir, "settings.env")
    alarms_file = os.path.join(config_dir, "alarms.tsv")
    notes_file = os.path.join(config_dir, "notes.tsv")
    ring_file = os.path.join(state_dir, "ringing")
    status_file = os.path.join(state_dir, "watch.status")
    wake_file = os.path.join(state_dir, "wakeups.tsv")

    # ANSI color definitions
    BOLD = "\033[1m"
    CYAN = "\033[36m"
    BLUE = "\033[34m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    WHITE = "\033[37m"
    RED = "\033[31m"
    MAGENTA = "\033[35m"
    DIM = "\033[2m"
    NC = "\033[0m"

    # Check if currently ringing
    if os.path.isfile(ring_file):
        mix = "Archive Mix"
        player = "Player"
        vol = "100"
        switches = "0"
        if os.path.isfile(status_file):
            try:
                for line in open(status_file, errors="ignore"):
                    if line.startswith("mix="): mix = line.strip().split("=", 1)[1]
                    elif line.startswith("player="): player = line.strip().split("=", 1)[1]
                    elif line.startswith("volume="): vol = line.strip().split("=", 1)[1]
                    elif line.startswith("switches="): switches = line.strip().split("=", 1)[1]
            except Exception:
                pass
        mix_name = os.path.basename(mix)
        line1 = f"  {BOLD}{RED}🚨 MORNING ALARM CLOCK RINGING!{NC}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}🎵 Playing:{NC} {WHITE}{mix_name}{NC} ({CYAN}{player}{NC})"
        line2 = f"  {BOLD}{CYAN}🎚️ Volume:{NC} {YELLOW}{vol}%{NC}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}🖱️ Wake Action:{NC} {GREEN}Move mouse to stop & start day{NC}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}Mix Switches:{NC} {WHITE}{switches}{NC}"
        return f"{line1}\n{line2}"

    # Load Settings
    settings = {"ENABLED": "yes", "THEME": "midnight-ink", "WAKE_KIND": "none", "WAKE_ARG": "", "VOLUME": "100"}
    if os.path.isfile(settings_file):
        try:
            for line in open(settings_file, errors="ignore"):
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    settings[k.strip()] = v.strip()
        except Exception:
            pass

    enabled = settings.get("ENABLED", "yes").lower() == "yes"
    enabled_disp = f"{GREEN}Armed & Ready{NC}" if enabled else f"{RED}Disabled / Paused{NC}"

    themes = {
        "midnight-ink": "Midnight Ink",
        "warm-brass": "Warm Brass",
        "forest-hour": "Forest Hour",
        "porcelain": "Porcelain"
    }
    raw_theme = settings.get("THEME", "midnight-ink")
    theme_name = themes.get(raw_theme, raw_theme.replace("-", " ").title())

    wake_kind = settings.get("WAKE_KIND", "none")
    wake_arg = settings.get("WAKE_ARG", "")
    if wake_kind == "console":
        wake_disp = "Console Window"
    elif wake_kind == "browser" and wake_arg:
        wake_disp = f"Browser ({wake_arg})"
    else:
        wake_disp = "Browser (Right Display)"

    # Alarms
    alarms = []
    if os.path.isfile(alarms_file):
        try:
            for line in open(alarms_file, errors="ignore"):
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) >= 2:
                    a_id = parts[0]
                    a_time = parts[1]
                    a_daily = parts[2] if len(parts) > 2 else "no"
                    a_vol = parts[3] if len(parts) > 3 else "100"
                    a_mus = parts[4] if len(parts) > 4 else "auto"
                    alarms.append((a_id, a_time, a_daily, a_vol, a_mus))
        except Exception:
            pass

    if alarms:
        a_id, a_time, a_daily, a_vol, a_mus = alarms[0]
        rep_str = "Daily" if a_daily == "yes" else "Once"
        if "MIX_ARCHIVE" in a_mus or "FLAC" in a_mus:
            mus_str = "Archive FLAC Mix"
        elif a_mus and a_mus != "auto":
            mus_str = os.path.basename(a_mus)
        else:
            mus_str = "Random Mix"

        # Check time remaining from systemd timer
        left_str = ""
        try:
            res = subprocess.run(
                ["systemctl", "--user", "show", f"mpac-{a_id}.timer", "-p", "NextElapseUSecRealtime", "--value"],
                capture_output=True, text=True, timeout=1
            )
            raw_next = res.stdout.strip()
            if raw_next and raw_next != "n/a" and raw_next != "0":
                # Calculate time difference
                # Format: Fri 2026-09-25 11:00:00 BST
                parts = raw_next.split()
                if len(parts) >= 3:
                    date_time_str = f"{parts[1]} {parts[2]}"
                    try:
                        tgt = datetime.datetime.strptime(date_time_str, "%Y-%m-%d %H:%M:%S")
                        now = datetime.datetime.now()
                        delta = tgt - now
                        if delta.total_seconds() > 0:
                            hrs = int(delta.total_seconds() // 3600)
                            mins = int((delta.total_seconds() % 3600) // 60)
                            if hrs > 0:
                                left_str = f"in {hrs}h {mins}m"
                            else:
                                left_str = f"in {mins}m"
                    except Exception:
                        pass
        except Exception:
            pass

        timer_badge = f" {GREEN}({left_str}){NC}" if left_str else ""
        alarm_info_disp = f"{WHITE}{a_time}{NC} {DIM}({rep_str}, {a_vol}% ramp){NC}{timer_badge}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}🎵 Sound:{NC} ${mus_str}"
        # Fix the $ prefix on mus_str
        alarm_info_disp = f"{WHITE}{a_time}{NC} {DIM}({rep_str}, {a_vol}% ramp){NC}{timer_badge}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}🎵 Sound:{NC} {YELLOW}{mus_str}{NC}"
        if len(alarms) > 1:
            alarm_info_disp += f" {DIM}(+{len(alarms)-1} more){NC}"
    else:
        alarm_info_disp = f"{DIM}None scheduled (Option 18 to set){NC}"

    # Steam Game Integration Check
    steam_count = 0
    vdf = os.path.expanduser("~/.local/share/Steam/steamapps/libraryfolders.vdf")
    roots = []
    if os.path.isfile(vdf):
        try:
            text = open(vdf, errors="ignore").read()
            roots = re.findall(r'"path"\s+"([^"]+)"', text)
        except Exception:
            pass
    if not roots:
        roots = [os.path.expanduser("~/.local/share/Steam")]
    skip = ("runtime", "proton", "steamworks", "redistribut", "soundtrack", "steamvr", "benchmark", "dedicated server")
    for root in roots:
        apps = os.path.join(root.replace("\\\\", "/"), "steamapps")
        for path in glob.glob(os.path.join(apps, "appmanifest_*.acf")):
            try:
                text = open(path, errors="ignore").read()
                m = re.search(r'"name"\s+"([^"]+)"', text)
                if m and not any(w in m.group(1).lower() for w in skip):
                    steam_count += 1
            except Exception:
                pass

    if steam_count > 0:
        steam_status = f"{GREEN}Ready ({steam_count} Games Installed • 3 for Breakfast){NC}"
    elif os.path.isdir(os.path.expanduser("~/.local/share/Steam")):
        steam_status = f"{YELLOW}Steam Standby (0 games){NC}"
    else:
        steam_status = f"{DIM}Steam Not Found{NC}"

    line1 = f"  {BOLD}{CYAN}⏰ Morning Alarm Clock:{NC} {enabled_disp}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}🔔 Next Alarm:{NC} {alarm_info_disp}"
    line2 = f"  {BOLD}{CYAN}🎮 Steam Wake-Up:{NC} {steam_status}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}🖥️ Action:{NC} {WHITE}{wake_disp}{NC}  {BOLD}{BLUE}│{NC}  {BOLD}{CYAN}🎨 Theme:{NC} {WHITE}{theme_name}{NC}"
    return f"{line1}\n{line2}"

if __name__ == "__main__":
    print(get_status_info())
