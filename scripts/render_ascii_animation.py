#!/usr/bin/env python3
"""
render_ascii_animation.py
=========================
Renders the animated and static rainbow ASCII header banner for
MP Mix Archive Manager using the MPlanetarian Dreamworlds color palette
(based on the KDE Plasma Sweet / Nice theme from the bash prompt screenshot).

Colors:
- Sweet Neon Hot Pink (#f72585)
- Sweet Neon Red / Coral (#ed254e)
- Sweet Electric Orange (#ff7200)
- Sweet Neon Violet (#bd93f9)
- Soft Sweet Lavender (#9b59b6)
- Sweet Electric Cyan (#00c1e4)
- Sweet Aqua (#00f5ff)
"""

import os
import sys
import time

# Enable Virtual Terminal Processing on Windows 10 & 11 so ANSI escape codes render properly
if sys.platform == "win32" or os.name == "nt":
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        for h_id in (-11, -12):
            h = kernel32.GetStdHandle(h_id)
            if h and h != -1:
                mode = ctypes.c_ulong()
                if kernel32.GetConsoleMode(h, ctypes.byref(mode)):
                    kernel32.SetConsoleMode(h, mode.value | 0x0004 | 0x0008)
        conout = kernel32.CreateFileW("CONOUT$", 0x40000000 | 0x80000000, 2, None, 3, 0, None)
        if conout and conout != -1:
            mode = ctypes.c_ulong()
            if kernel32.GetConsoleMode(conout, ctypes.byref(mode)):
                kernel32.SetConsoleMode(conout, mode.value | 0x0004 | 0x0008)
            kernel32.CloseHandle(conout)
    except Exception:
        pass
    try:
        os.system('')
    except Exception:
        pass

PALETTE = [
    (247, 37, 133),  # Sweet Neon Hot Pink (#f72585)
    (237, 37, 78),   # Sweet Neon Red / Coral (#ed254e)
    (255, 114, 0),   # Sweet Electric Orange (#ff7200)
    (189, 147, 249), # Sweet Neon Violet (#bd93f9)
    (155, 89, 182),  # Soft Sweet Lavender (#9b59b6)
    (0, 193, 228),   # Sweet Electric Cyan (#00c1e4)
    (0, 245, 255),   # Aqua (#00f5ff)
]

ULTRA_PALETTE = [
    (166, 77, 255),  # Hot Purple Box Outline (#a64dff)
    (153, 51, 255),  # Hot Purple (#9933ff)
    (102, 102, 255), # Electric Lavender Blue (#6666ff)
    (0, 255, 0),     # Traffic Light Green (#00ff00)
    (204, 255, 102), # Traffic Light Lime (#ccff66)
    (255, 153, 51),  # Traffic Light Amber (#ff9933)
    (255, 0, 0),     # Traffic Light Danger Red (#ff0000)
    (153, 153, 255), # Soft Lilac (#9999ff)
]

BANNER_LINES = [
    "   __  ___ ___     __  ___ _  _  __    ___   ___  ____ __  __ _  _   __  ____",
    "  /  |/  // _ \\   /  |/  /(_)| |/_/   /   | / _ \\/ __// / / /(_)| | / / / __/",
    " / /|_/ // ___/  / /|_/ // / _>  <    / /| |/ , _/ /__/ /_/ // / | |/ / / _/  ",
    "/_/  /_//_/     /_/  /_//_/ /_/|_|   /_/ |_/_/|_|\\___/\\____//_/  |___/ /___/  ",
    "                   __  ___   ___   _  __   ___   _____ ____   ___ ",
    "                  /  |/  /  /   | / |/ /  /   | / ___// __/  / _ \\",
    "                 / /|_/ /  / /| |/    /  / /| |/ (_ // _/   / , _/",
    "                /_/  /_/  /_/ |_/_/|_/  /_/ |_|\\___//___/  /_/|_| "
]

SUBTITLES = [
    "               ✦  D R E A M W O R L D S   P R O D U C T I O N S  ✦",
    "  ✦ MPlanetarian Dreamworlds Edition ✦ High-Resolution Audio Production Suite ✦"
]

ULTRA_SUBTITLES = [
    "         ✦  D R E A M W O R L D S   U L T R A   P R O D U C T I O N S  ✦",
    "✦ Dreamworlds Ultra Edition ✦ Hot Purple & Traffic Light Audio Production Suite ✦"
]

def render_frame(offset=0, is_ultra=False):
    output = []
    palette = ULTRA_PALETTE if is_ultra else PALETTE
    subtitles = ULTRA_SUBTITLES if is_ultra else SUBTITLES
    num_colors = len(palette)
    for line in BANNER_LINES:
        row = []
        for i, char in enumerate(line):
            if char == " ":
                row.append(" ")
            else:
                col_idx = (i // 3 + offset) % num_colors
                r, g, b = palette[col_idx]
                row.append(f"\033[38;2;{r};{g};{b}m{char}\033[0m")
        output.append("".join(row))
    
    # Subtitles with rainbow gradient
    for s_idx, subtitle in enumerate(subtitles):
        sub_row = []
        for i, char in enumerate(subtitle):
            if char == " ":
                sub_row.append(" ")
            else:
                col_idx = (i // 4 + offset * 2 + s_idx * 3) % num_colors
                r, g, b = palette[col_idx]
                sub_row.append(f"\033[1;38;2;{r};{g};{b}m{char}\033[0m")
        output.append("".join(sub_row))
    
    return "\n".join(output)

def play_animation(frames=14, delay=0.04, is_ultra=False):
    # Hide cursor
    sys.stdout.write("\033[?25l")
    sys.stdout.flush()
    try:
        subtitles = ULTRA_SUBTITLES if is_ultra else SUBTITLES
        num_lines = len(BANNER_LINES) + len(subtitles)
        for f in range(frames):
            frame_str = render_frame(f, is_ultra=is_ultra)
            if f == 0:
                sys.stdout.write(frame_str + "\n")
            else:
                sys.stdout.write(f"\033[{num_lines}A\r")
                sys.stdout.write(frame_str + "\n")
            sys.stdout.flush()
            time.sleep(delay)
    finally:
        # Restore cursor
        sys.stdout.write("\033[?25h")
        sys.stdout.flush()

def render_compact(offset=0, is_ultra=False):
    palette = ULTRA_PALETTE if is_ultra else PALETTE
    num_colors = len(palette)
    if is_ultra:
        title = "  ✦ Dreamworlds Ultra Productions ✦ Hot Purple & Traffic Light Audio Suite ✦"
    else:
        title = "  ✦ Dreamworlds Productions ✦ MPlanetarian Audio Production Suite ✦"
    sub_row = []
    for i, char in enumerate(title):
        if char == " ":
            sub_row.append(" ")
        else:
            col_idx = (i // 3 + offset) % num_colors
            r, g, b = palette[col_idx]
            sub_row.append(f"\033[1;38;2;{r};{g};{b}m{char}\033[0m")
    return "".join(sub_row)

if __name__ == "__main__":
    is_ultra = "--ultra" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--ultra"]
    if len(args) > 0 and args[0] == "--animate":
        play_animation(is_ultra=is_ultra)
    elif len(args) > 0 and args[0] == "--compact":
        sys.stdout.write(render_compact(0, is_ultra=is_ultra) + "\n")
        sys.stdout.flush()
    else:
        sys.stdout.write(render_frame(0, is_ultra=is_ultra) + "\n")
        sys.stdout.flush()
