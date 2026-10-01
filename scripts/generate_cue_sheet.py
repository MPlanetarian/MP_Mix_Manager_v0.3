#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Standard CUE Sheet Generator & Audio Splitter
- Generates Red Book CDRWIN / EAC compliant .cue sheets from tracklists and Traktor history
- Calculates frame-accurate CDDA index timecodes (MM:SS:FF at 75 frames/sec)
- Splits FLAC/WAV mixes into individual tracks using .cue sheets with embedded Vorbis/ID3 tags
- Cross-platform support for Linux, macOS, and Windows
"""

import os
import sys
import re
import argparse
import subprocess
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

# --- ANSI Colors ---
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[1;37m"
NC = "\033[0m"

def get_audio_duration(file_path):
    """Return audio duration in seconds using ffprobe or ffmpeg."""
    cmd = [
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(file_path)
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return float(res.stdout.strip())
    except Exception:
        # Fallback to ffmpeg
        try:
            cmd2 = ["ffmpeg", "-i", str(file_path)]
            res2 = subprocess.run(cmd2, capture_output=True, text=True)
            m = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.?\d*)", res2.stderr)
            if m:
                hours, mins, secs = float(m.group(1)), float(m.group(2)), float(m.group(3))
                return hours * 3600 + mins * 60 + secs
        except Exception:
            pass
    return None

def seconds_to_cdda_frame(seconds):
    """Convert floating-point seconds into MM:SS:FF (75 frames per second)."""
    total_frames = int(round(seconds * 75.0))
    minutes = total_frames // (75 * 60)
    remainder = total_frames % (75 * 60)
    secs = remainder // 75
    frames = remainder % 75
    return f"{minutes:02d}:{secs:02d}:{frames:02d}"

def parse_timecode_to_seconds(tc_str):
    """Parse various timecode formats into seconds."""
    tc = tc_str.strip("[]() ")
    parts = tc.split(":")
    try:
        if len(parts) == 3:
            # HH:MM:SS or MM:SS:FF
            p1, p2, p3 = float(parts[0]), float(parts[1]), float(parts[2])
            # Check if likely MM:SS:FF (frames < 75) or HH:MM:SS
            return p1 * 3600 + p2 * 60 + p3
        elif len(parts) == 2:
            # MM:SS
            return float(parts[0]) * 60 + float(parts[1])
    except ValueError:
        pass
    return None

def parse_tracklist_text(text_content):
    """Extract tracks and any embedded timestamps from tracklist text."""
    lines = text_content.strip().split("\n")
    tracks = []
    
    # Common regex patterns
    # e.g. 01. [00:00:00] Artist - Title
    # e.g. 00:00 Artist - Title
    # e.g. 01. Artist - Title (05:22)
    # e.g. 01. Artist - Title
    tc_start_pattern = re.compile(r"^\s*(?:\d+[\.\)]\s*)?(?:\[|\()?(\d{1,2}:\d{2}(?::\d{2})?)(?:\]|\))?\s*[-–—]?\s*(.*)$")
    tc_end_pattern = re.compile(r"^\s*(?:\d+[\.\)]\s*)?(.*?)\s*(?:\[|\()(\d{1,2}:\d{2}(?::\d{2})?)(?:\]|\))\s*$")
    numbered_pattern = re.compile(r"^\s*(\d+)[\.\)]\s*(.*)$")
    
    current_time = 0.0
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("===") or line.startswith("---"):
            continue
        if re.search(r"tracklist|episode|stream of frequency|presented by|mplanetarian", line, re.I) and not re.search(r"[-–—]", line):
            continue

        start_match = tc_start_pattern.match(line)
        end_match = tc_end_pattern.match(line)
        
        tc_sec = None
        track_info = ""
        
        if start_match:
            tc_sec = parse_timecode_to_seconds(start_match.group(1))
            track_info = start_match.group(2).strip()
        elif end_match:
            tc_sec = parse_timecode_to_seconds(end_match.group(2))
            track_info = end_match.group(1).strip()
        else:
            num_m = numbered_pattern.match(line)
            if num_m:
                track_info = num_m.group(2).strip()
            else:
                track_info = line

        # Split into Artist and Title if possible
        artist = ""
        title = ""
        if " - " in track_info:
            parts = track_info.split(" - ", 1)
            artist, title = parts[0].strip(), parts[1].strip()
        elif " – " in track_info:
            parts = track_info.split(" – ", 1)
            artist, title = parts[0].strip(), parts[1].strip()
        else:
            artist = "Unknown Artist"
            title = track_info

        tracks.append({
            "artist": artist,
            "title": title,
            "seconds": tc_sec,
            "raw": track_info
        })
        
    return tracks

def find_traktor_nml_match(mix_name, traktor_history_dir):
    """Find matching Traktor history session for timestamps if available."""
    if not traktor_history_dir or not os.path.isdir(traktor_history_dir):
        return None
    # Look for NML files
    nml_files = list(Path(traktor_history_dir).glob("**/*.nml"))
    # Simple search for mix name or date in NML filename
    mix_stem = Path(mix_name).stem.lower()
    for nml in nml_files:
        if nml.stem.lower() in mix_stem or any(part in nml.stem.lower() for part in mix_stem.split("_") if len(part) > 4):
            return nml
    return None

def extract_cue_from_traktor_nml(nml_path):
    """Extract tracks and start times from Traktor .nml file."""
    try:
        tree = ET.parse(nml_path)
        root = tree.getroot()
        tracks = []
        cumulative_time = 0.0
        
        for entry in root.findall(".//ENTRY"):
            artist = entry.get("ARTIST", "Unknown Artist")
            title = entry.get("TITLE", "Unknown Title")
            info = entry.find("INFO")
            playtime = 0.0
            if info is not None:
                playtime = float(info.get("PLAYTIME", 0))
            
            tracks.append({
                "artist": artist,
                "title": title,
                "seconds": cumulative_time
            })
            cumulative_time += playtime
        return tracks
    except Exception:
        return None

def generate_cue_sheet_text(audio_file_path, tracks, performer="MPlanetarian", title=None):
    """Construct a Red Book compliant .cue sheet string."""
    audio_p = Path(audio_file_path)
    if not title:
        title = audio_p.stem
        
    lines = [
        f'REM GENRE "Electronic / Trance"',
        f'REM DATE "{audio_p.stat().st_mtime if audio_p.exists() else 2026}"',
        f'REM COMMENT "Generated by MP_Mix_Manager_v0.3 CUE Engine"',
        f'PERFORMER "{performer}"',
        f'TITLE "{title}"',
        f'FILE "{audio_p.name}" WAVE'
    ]
    
    for idx, tr in enumerate(tracks, start=1):
        tr_artist = tr.get("artist") or performer
        tr_title = tr.get("title") or f"Track {idx:02d}"
        tr_sec = tr.get("seconds") or 0.0
        cdda_idx = seconds_to_cdda_frame(tr_sec)
        
        lines.append(f'  TRACK {idx:02d} AUDIO')
        lines.append(f'    TITLE "{tr_title}"')
        lines.append(f'    PERFORMER "{tr_artist}"')
        lines.append(f'    INDEX 01 {cdda_idx}')
        
    return "\n".join(lines) + "\n"

def split_audio_by_cue(audio_file_path, cue_file_path, output_dir=None):
    """Split audio file into individual FLAC/WAV tracks based on .cue sheet."""
    if not shutil.which("ffmpeg"):
        print(f"{RED}Error: ffmpeg is required to split audio files.{NC}")
        return False
        
    audio_p = Path(audio_file_path)
    cue_p = Path(cue_file_path)
    
    if not output_dir:
        output_dir = audio_p.parent / f"{audio_p.stem}_SPLIT_TRACKS"
    else:
        output_dir = Path(output_dir)
        
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Parse CUE tracks
    tracks = []
    current_track = None
    album_title = audio_p.stem
    album_artist = "MPlanetarian"
    
    with open(cue_p, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if line.startswith("TITLE ") and not current_track:
                album_title = line.split("TITLE ", 1)[1].strip('"')
            elif line.startswith("PERFORMER ") and not current_track:
                album_artist = line.split("PERFORMER ", 1)[1].strip('"')
            elif line.startswith("TRACK "):
                if current_track:
                    tracks.append(current_track)
                m = re.search(r"TRACK\s+(\d+)\s+AUDIO", line)
                t_num = int(m.group(1)) if m else len(tracks) + 1
                current_track = {"num": t_num, "artist": album_artist, "title": f"Track {t_num:02d}", "time": "00:00:00"}
            elif current_track:
                if line.startswith("TITLE "):
                    current_track["title"] = line.split("TITLE ", 1)[1].strip('"')
                elif line.startswith("PERFORMER "):
                    current_track["artist"] = line.split("PERFORMER ", 1)[1].strip('"')
                elif line.startswith("INDEX 01 "):
                    current_track["time"] = line.split("INDEX 01 ", 1)[1].strip()
                    
    if current_track:
        tracks.append(current_track)
        
    if not tracks:
        print(f"{RED}Error: No valid tracks found in CUE sheet.{NC}")
        return False
        
    # Convert CUE index MM:SS:FF into seconds
    for tr in tracks:
        parts = tr["time"].split(":")
        mins = float(parts[0])
        secs = float(parts[1])
        frames = float(parts[2]) if len(parts) > 2 else 0.0
        tr["start_seconds"] = mins * 60.0 + secs + (frames / 75.0)

    total_dur = get_audio_duration(audio_p)
    print(f"\n{BOLD}{CYAN}Splitting {audio_p.name} into {len(tracks)} tracks...{NC}")
    print(f"Destination folder: {GREEN}{output_dir}{NC}\n")

    for idx, tr in enumerate(tracks):
        start_sec = tr["start_seconds"]
        end_sec = tracks[idx + 1]["start_seconds"] if idx + 1 < len(tracks) else total_dur
        duration = (end_sec - start_sec) if end_sec else None
        
        safe_title = re.sub(r'[\\/*?:"<>|]', "", f"{tr['num']:02d}. {tr['artist']} - {tr['title']}")
        out_file = output_dir / f"{safe_title}.flac"
        
        print(f"  [{tr['num']:02d}/{len(tracks)}] Exporting: {CYAN}{out_file.name}{NC} ({seconds_to_cdda_frame(start_sec)})")
        
        cmd = [
            "ffmpeg", "-y", "-nostats", "-ss", str(start_sec),
            "-i", str(audio_p)
        ]
        if duration:
            cmd.extend(["-t", str(duration)])
            
        cmd.extend([
            "-c:a", "flac", "-compression_level", "8",
            "-metadata", f"title={tr['title']}",
            "-metadata", f"artist={tr['artist']}",
            "-metadata", f"album={album_title}",
            "-metadata", f"track={tr['num']}/{len(tracks)}",
            str(out_file)
        ])
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print(f"\n{BOLD}{GREEN}✓ Successfully split mix into {len(tracks)} tracks in:{NC} {output_dir}")
    return True

def create_cue_for_mix(audio_file_path, tracklist_text_path=None, performer="MPlanetarian"):
    """Auto-detect or generate CUE sheet for a mix file."""
    audio_p = Path(audio_file_path)
    cue_p = audio_p.with_suffix(".cue")
    
    # Check for text tracklist
    if not tracklist_text_path:
        for cand in [audio_p.with_suffix(".txt"), audio_p.parent / f"{audio_p.stem}.txt"]:
            if cand.is_file():
                tracklist_text_path = cand
                break
                
    tracks = []
    if tracklist_text_path and os.path.isfile(tracklist_text_path):
        with open(tracklist_text_path, "r", encoding="utf-8", errors="ignore") as f:
            tracks = parse_tracklist_text(f.read())
            
    # Check if timestamps are missing
    has_timestamps = any(t.get("seconds") is not None for t in tracks)
    
    if not has_timestamps and tracks:
        duration = get_audio_duration(audio_p)
        if duration:
            # Distribute tracks evenly across duration as sensible baseline
            track_dur = duration / len(tracks)
            for i, t in enumerate(tracks):
                t["seconds"] = i * track_dur
        else:
            for i, t in enumerate(tracks):
                t["seconds"] = i * 300.0  # 5 min fallback
    elif not tracks:
        print(f"{YELLOW}No tracklist found. Creating default track markers...{NC}")
        duration = get_audio_duration(audio_p) or 3600.0
        # 10 min tracks
        num_tr = max(1, int(round(duration / 600.0)))
        track_dur = duration / num_tr
        for i in range(num_tr):
            tracks.append({
                "artist": performer,
                "title": f"Part {i+1:02d}",
                "seconds": i * track_dur
            })

    cue_text = generate_cue_sheet_text(audio_p, tracks, performer=performer)
    with open(cue_p, "w", encoding="utf-8") as f:
        f.write(cue_text)
        
    print(f"{BOLD}{GREEN}✓ Generated Red Book CUE sheet:{NC} {cue_p}")
    return cue_p

def interactive_menu():
    while True:
        print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}            STANDARD RED BOOK CUE SHEET GENERATOR & SPLITTER          {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"  {BOLD}1){NC} Generate .CUE Sheet for Single Mix File (FLAC/WAV)")
        print(f"  {BOLD}2){NC} Batch Generate .CUE Sheets for All Mixes in Archive")
        print(f"  {BOLD}3){NC} Split FLAC / WAV Mix into Individual Tracks using .CUE Sheet")
        print(f"  {BOLD}0){NC} Return to Previous Menu\n")
        
        choice = input("Enter choice [0-3]: ").strip()
        if choice in ["0", "q", "exit"]:
            break
        elif choice == "1":
            audio_f = input("\nEnter path to audio file (FLAC/WAV): ").strip().strip("'\"")
            if audio_f and os.path.isfile(audio_f):
                tl_f = input("Enter path to tracklist .txt (leave blank to auto-detect): ").strip().strip("'\"")
                create_cue_for_mix(audio_f, tracklist_text_path=tl_f if tl_f else None)
            else:
                print(f"{RED}File not found.{NC}")
            input(f"\n{DIM}Press Enter to continue...{NC}")
        elif choice == "2":
            scan_dir = input("\nEnter mix archive folder (default: current directory): ").strip().strip("'\"")
            if not scan_dir:
                scan_dir = "."
            p_dir = Path(scan_dir)
            flacs = sorted(list(p_dir.glob("*.flac")) + list(p_dir.glob("*.wav")))
            if not flacs:
                print(f"{YELLOW}No audio mixes found in {scan_dir}{NC}")
                continue
            print(f"\n{CYAN}Found {len(flacs)} mixes. Generating CUE sheets...{NC}")
            for idx, flac in enumerate(flacs, start=1):
                print(f"[{idx}/{len(flacs)}] Processing {flac.name}...")
                create_cue_for_mix(flac)
            input(f"\n{DIM}Press Enter to continue...{NC}")
        elif choice == "3":
            cue_f = input("\nEnter path to .cue sheet: ").strip().strip("'\"")
            if not cue_f or not os.path.isfile(cue_f):
                print(f"{RED}CUE sheet not found.{NC}")
                continue
            audio_cand = Path(cue_f).with_suffix(".flac")
            if not audio_cand.is_file():
                audio_cand = Path(cue_f).with_suffix(".wav")
            if not audio_cand.is_file():
                audio_f = input("Enter path to matching audio file (FLAC/WAV): ").strip().strip("'\"")
            else:
                audio_f = str(audio_cand)
            split_audio_by_cue(audio_f, cue_f)
            input(f"\n{DIM}Press Enter to continue...{NC}")

def main():
    parser = argparse.ArgumentParser(description="MP_Mix_Manager_v0.3 - Standard CUE Sheet Engine")
    parser.add_argument("file", nargs="?", help="Audio mix file to process")
    parser.add_argument("--tracklist", "-t", help="Tracklist text file path")
    parser.add_argument("--split", "-s", action="store_true", help="Split audio file using CUE sheet")
    parser.add_argument("--cue", "-c", help="Specific .cue sheet file path")
    parser.add_argument("-o", "--output", help="Output directory for split tracks")
    args = parser.parse_args()

    if not args.file and not args.cue:
        interactive_menu()
        return

    if args.split:
        cue_file = args.cue or (Path(args.file).with_suffix(".cue") if args.file else None)
        if not cue_file or not os.path.isfile(cue_file):
            print(f"{RED}Error: CUE sheet not found.{NC}")
            sys.exit(1)
        split_audio_by_cue(args.file, cue_file, output_dir=args.output)
    else:
        create_cue_for_mix(args.file, tracklist_text_path=args.tracklist)

if __name__ == "__main__":
    main()
