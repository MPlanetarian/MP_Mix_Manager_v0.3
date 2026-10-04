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

import sys
import time

PALETTE = [
    (247, 37, 133),  # Sweet Neon Hot Pink (#f72585)
    (237, 37, 78),   # Sweet Neon Red / Coral (#ed254e)
    (255, 114, 0),   # Sweet Electric Orange (#ff7200)
    (189, 147, 249), # Sweet Neon Violet (#bd93f9)
    (155, 89, 182),  # Soft Sweet Lavender (#9b59b6)
    (0, 193, 228),   # Sweet Electric Cyan (#00c1e4)
    (0, 245, 255),   # Aqua (#00f5ff)
]

BANNER_LINES = [
    "    __  ______     __  ____         ___              __    _           ",
    "   /  |/  / __ \\   /  |/  (_)_  __  /   |  __________/ /_  (_)   _____ ",
    "  / /|_/ / /_/ /  / /|_/ / / |/_/ / /| | / ___/ ___/ __ \\/ / | / / _ \\",
    " / /  / / ____/  / /  / / />  <  / ___ |/ /  / /__/ / / / /| |/ /  __/",
    "/_/  /_/_/      /_/  /_/_/_/|_| /_/  |_/_/   \\___/_/ /_/_/ |___/\\___/ ",
    "                __  ___                                               ",
    "               /  |/  /___ _____  ____ _____ ____  _____              ",
    "              / /|_/ / __ `/ __ \\/ __ `/ __ `/ _ \\/ ___/              ",
    "             / /  / / /_/ / / / / /_/ / /_/ /  __/ /                  ",
    "            /_/  /_/\\__,_/_/ /_/\\__,_/\\__, /\\___/_/                   ",
    "                                     /____/                           ",
]

SUBTITLE = "  ✦ MPlanetarian Dreamworlds Edition ✦ High-Resolution Audio Production Suite ✦"

def render_frame(offset=0):
    output = []
    num_colors = len(PALETTE)
    for line in BANNER_LINES:
        row = []
        for i, char in enumerate(line):
            if char == " ":
                row.append(" ")
            else:
                col_idx = (i // 3 + offset) % num_colors
                r, g, b = PALETTE[col_idx]
                row.append(f"\033[38;2;{r};{g};{b}m{char}\033[0m")
        output.append("".join(row))
    
    # Subtitle with rainbow gradient
    sub_row = []
    for i, char in enumerate(SUBTITLE):
        if char == " ":
            sub_row.append(" ")
        else:
            col_idx = (i // 4 + offset * 2) % num_colors
            r, g, b = PALETTE[col_idx]
            sub_row.append(f"\033[1;38;2;{r};{g};{b}m{char}\033[0m")
    output.append("".join(sub_row))
    
    return "\n".join(output)

def play_animation(frames=14, delay=0.04):
    # Hide cursor
    sys.stdout.write("\033[?25l")
    sys.stdout.flush()
    try:
        for f in range(frames):
            frame_str = render_frame(f)
            if f == 0:
                sys.stdout.write(frame_str + "\n")
            else:
                num_lines = len(BANNER_LINES) + 1
                sys.stdout.write(f"\033[{num_lines}A\r")
                sys.stdout.write(frame_str + "\n")
            sys.stdout.flush()
            time.sleep(delay)
    finally:
        # Restore cursor
        sys.stdout.write("\033[?25h")
        sys.stdout.flush()

def render_compact(offset=0):
    num_colors = len(PALETTE)
    title = "  ✦ MPlanetarian Dreamworlds Edition ✦ High-Resolution Audio Production Suite ✦"
    sub_row = []
    for i, char in enumerate(title):
        if char == " ":
            sub_row.append(" ")
        else:
            col_idx = (i // 3 + offset) % num_colors
            r, g, b = PALETTE[col_idx]
            sub_row.append(f"\033[1;38;2;{r};{g};{b}m{char}\033[0m")
    return "".join(sub_row)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--animate":
        play_animation()
    elif len(sys.argv) > 1 and sys.argv[1] == "--compact":
        sys.stdout.write(render_compact(0) + "\n")
        sys.stdout.flush()
    else:
        sys.stdout.write(render_frame(0) + "\n")
        sys.stdout.flush()
