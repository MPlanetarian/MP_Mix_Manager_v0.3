#!/usr/bin/env python3
"""
MP Mix Manager v0.3 - Streaming & Platform Chapters Exporter
Parses tracklists (.txt), CUE sheets (.cue), and Traktor session histories (.nml)
and generates standardized YouTube Chapters, SoundCloud/Mixcloud timestamps,
and Markdown/HTML tracklists with duration verification.
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def parse_timestamp_seconds(ts_str):
    """Convert HH:MM:SS or MM:SS or MM:SS:FF to total seconds."""
    ts_str = ts_str.strip()
    parts = ts_str.split(":")
    try:
        if len(parts) == 3:
            # HH:MM:SS or MM:SS:FF (cue sheet frames)
            if len(parts[2]) == 2 and int(parts[0]) > 23:
                # MM:SS:FF
                m, s, f = int(parts[0]), int(parts[1]), int(parts[2])
                return m * 60 + s + (f / 75.0)
            h, m, s = int(parts[0]), int(parts[1]), float(parts[2])
            return h * 3600 + m * 60 + s
        elif len(parts) == 2:
            m, s = int(parts[0]), float(parts[1])
            return m * 60 + s
    except Exception:
        pass
    return None


def format_seconds(sec, include_hours=True):
    """Format seconds into HH:MM:SS or MM:SS."""
    sec = max(0, int(sec))
    h = sec // 3600
    m = (sec % 3600) // 60
    s = sec % 60
    if include_hours or h > 0:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


def parse_txt_tracklist(filepath):
    """Parse tracklist text file with various formatting styles."""
    entries = []
    time_regex = re.compile(r'\[?(\d{1,2}:\d{2}(?::\d{2})?)\]?')
    numbered_regex = re.compile(r'^\s*(?:[0-9]{1,3}[.)\-]\s*|\s*)(.*?)$')

    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = [line.strip() for line in f if line.strip()]

    current_time = 0
    for idx, line in enumerate(lines):
        # Match lines like "[00:00:00] Artist - Title" or "01. [05:20] Artist - Title"
        m_time = time_regex.search(line)
        if m_time:
            t_str = m_time.group(1)
            t_sec = parse_timestamp_seconds(t_str)
            # Remove timestamp part from title
            cleaned = time_regex.sub('', line)
            cleaned = re.sub(r'^\s*[0-9]{1,3}[.)\-]\s*', '', cleaned).strip(' -:|')
            if cleaned:
                entries.append({
                    'index': len(entries) + 1,
                    'seconds': t_sec if t_sec is not None else current_time,
                    'title': cleaned
                })
        else:
            # Numbered lines without explicit timestamp e.g. "01. Artist - Title"
            m_num = numbered_regex.match(line)
            if m_num and '-' in m_num.group(1):
                raw_title = m_num.group(1).strip()
                entries.append({
                    'index': len(entries) + 1,
                    'seconds': None,
                    'title': raw_title
                })

    return entries


def parse_cue_sheet(filepath):
    """Parse a standard .cue sheet."""
    entries = []
    current_track = None

    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if line.startswith("TRACK"):
                if current_track:
                    entries.append(current_track)
                current_track = {
                    'index': len(entries) + 1,
                    'artist': '',
                    'title': '',
                    'seconds': 0
                }
            elif line.startswith("PERFORMER") and current_track:
                current_track['artist'] = line.split("PERFORMER", 1)[1].strip().strip('"')
            elif line.startswith("TITLE") and current_track:
                current_track['title'] = line.split("TITLE", 1)[1].strip().strip('"')
            elif line.startswith("INDEX 01") and current_track:
                t_str = line.split("INDEX 01", 1)[1].strip()
                sec = parse_timestamp_seconds(t_str)
                if sec is not None:
                    current_track['seconds'] = sec

    if current_track:
        entries.append(current_track)

    for e in entries:
        full_title = f"{e.get('artist', '')} - {e.get('title', '')}".strip(" -")
        e['title'] = full_title or f"Track {e['index']:02d}"

    return entries


def get_audio_duration(audio_file):
    """Probe audio duration using ffprobe."""
    if not audio_file or not os.path.isfile(audio_file):
        return None
    try:
        cmd = [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            audio_file
        ]
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode('utf-8').strip()
        return float(out)
    except Exception:
        return None


def copy_to_clipboard(text):
    """Copy text to clipboard across Linux, macOS, and Windows."""
    for cmd in [["wl-copy"], ["xclip", "-selection", "clipboard"], ["pbcopy"]]:
        if shutil_which(cmd[0]):
            try:
                proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
                proc.communicate(input=text.encode('utf-8'))
                return True
            except Exception:
                pass
    return False


def shutil_which(cmd):
    import shutil
    return shutil.which(cmd) is not None


def main():
    parser = argparse.ArgumentParser(description="Export Mix Chapters for YouTube, SoundCloud, Mixcloud, and Markdown")
    parser.add_argument("input_file", help="Path to .txt tracklist or .cue sheet")
    parser.add_argument("--audio", "-a", help="Path to corresponding audio file for duration checks", default=None)
    parser.add_argument("--format", "-f", choices=["youtube", "soundcloud", "markdown", "html", "all"], default="youtube", help="Output format")
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)", default=None)
    parser.add_argument("--clipboard", "-c", action="store_true", help="Copy output to system clipboard")

    args = parser.parse_args()

    input_path = Path(args.input_file)
    if not os.path.exists(args.input_file):
        print(f"Error: Input file '{args.input_file}' not found.", file=sys.stderr)
        sys.exit(1)

    if input_path.suffix.lower() == ".cue":
        entries = parse_cue_sheet(input_path)
    else:
        entries = parse_txt_tracklist(input_path)

    if not entries:
        print("Error: No tracks or timestamps could be parsed from the file.", file=sys.stderr)
        sys.exit(1)

    audio_dur = get_audio_duration(args.audio)

    # YouTube Chapters (Requires starting at 00:00:00)
    yt_lines = []
    # Ensure first chapter starts at 00:00:00
    if entries and entries[0]['seconds'] is not None and entries[0]['seconds'] > 10:
        yt_lines.append("00:00:00 Intro")

    for e in entries:
        sec = e['seconds'] if e['seconds'] is not None else 0
        if audio_dur and sec > audio_dur:
            print(f"Warning: Track '{e['title']}' timestamp ({format_seconds(sec)}) exceeds audio duration ({format_seconds(audio_dur)}).", file=sys.stderr)
        yt_lines.append(f"{format_seconds(sec)} {e['title']}")

    yt_output = "\n".join(yt_lines)

    # SoundCloud / Mixcloud format
    sc_lines = []
    for e in entries:
        sec = e['seconds'] if e['seconds'] is not None else 0
        sc_lines.append(f"[{format_seconds(sec, include_hours=False)}] {e['title']}")
    sc_output = "\n".join(sc_lines)

    # Markdown format
    md_lines = [f"## Tracklist — {input_path.stem}\n"]
    if audio_dur:
        md_lines.append(f"**Total Duration:** {format_seconds(audio_dur)}\n")
    md_lines.append("| # | Timestamp | Artist - Title |")
    md_lines.append("|---|-----------|----------------|")
    for e in entries:
        sec = e['seconds'] if e['seconds'] is not None else 0
        md_lines.append(f"| {e['index']:02d} | `{format_seconds(sec)}` | {e['title']} |")
    md_output = "\n".join(md_lines)

    # HTML format
    html_lines = [f"<div class='mix-chapters'><h3>{input_path.stem}</h3><ol>"]
    for e in entries:
        sec = e['seconds'] if e['seconds'] is not None else 0
        html_lines.append(f"  <li><span class='time'>{format_seconds(sec)}</span> - <span class='track'>{e['title']}</span></li>")
    html_lines.append("</ol></div>")
    html_output = "\n".join(html_lines)

    final_output = ""
    if args.format == "youtube":
        final_output = yt_output
    elif args.format == "soundcloud":
        final_output = sc_output
    elif args.format == "markdown":
        final_output = md_output
    elif args.format == "html":
        final_output = html_output
    elif args.format == "all":
        final_output = (
            "=== YOUTUBE CHAPTERS ===\n" + yt_output + "\n\n" +
            "=== SOUNDCLOUD / MIXCLOUD TIMESTAMPS ===\n" + sc_output + "\n\n" +
            "=== MARKDOWN TABLE ===\n" + md_output
        )

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(final_output + "\n")
        print(f"Chapters successfully exported to: {args.output}")
    else:
        print(final_output)

    if args.clipboard:
        if copy_to_clipboard(final_output):
            print("\n[✓] Copied chapters to system clipboard!", file=sys.stderr)


if __name__ == "__main__":
    main()
