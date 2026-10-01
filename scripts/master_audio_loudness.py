#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Audio Mastering & EBU R128 Loudness Suite
- Scans audio files (FLAC, WAV, MP3) for Integrated Loudness (LUFS), True Peak (dBTP), and Loudness Range (LRA)
- Evaluates compliance against Streaming, Podcast, Broadcast (EBU R128), and DJ/Club mastering standards
- Provides 2-pass transparent linear mastering normalization using ffmpeg loudnorm
- Preserves all metadata/tags and audio fidelity
"""

import os
import sys
import json
import subprocess
import shutil
import argparse
import re
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

# Target Profiles (Integrated LUFS, Max True Peak dBTP, Target LRA)
TARGET_PROFILES = {
    "1": {
        "name": "Streaming Master (Spotify, YouTube Music, Apple Music, Tidal)",
        "i": -14.0,
        "tp": -1.0,
        "lra": 11.0,
        "desc": "Industry-standard target for web streaming platforms (-14 LUFS / -1.0 dBTP)"
    },
    "2": {
        "name": "Podcast & Spoken Word (Apple Podcasts, AES TD1004)",
        "i": -16.0,
        "tp": -1.0,
        "lra": 9.0,
        "desc": "Standard target for podcasts and vocal-heavy mixes (-16 LUFS / -1.0 dBTP)"
    },
    "3": {
        "name": "Broadcast Master (EBU R128 / ITU-R BS.1770 European Standard)",
        "i": -23.0,
        "tp": -1.0,
        "lra": 18.0,
        "desc": "Strict broadcast delivery standard for television and radio (-23 LUFS / -1.0 dBTP)"
    },
    "4": {
        "name": "Club & DJ Master (SoundCloud, Mixcloud, High-Energy)",
        "i": -10.5,
        "tp": -0.3,
        "lra": 8.0,
        "desc": "Loud and punchy dynamic master for DJ sets & SoundCloud (-10.5 LUFS / -0.3 dBTP)"
    }
}

def check_ffmpeg():
    if not shutil.which("ffmpeg"):
        print(f"{RED}Error: ffmpeg is not installed or not in PATH.{NC}")
        sys.exit(1)

def run_loudness_scan(file_path):
    """Run pass 1 loudnorm scan and parse exact JSON metrics."""
    cmd = [
        "ffmpeg", "-nostats", "-i", str(file_path),
        "-af", "loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json",
        "-f", "null", "-"
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        output = proc.stderr
        
        # Extract JSON block from ffmpeg output
        json_match = re.search(r"\{[\s\S]*\}", output)
        if not json_match:
            return None, "Failed to parse loudnorm JSON from ffmpeg output."
        
        data = json.loads(json_match.group(0))
        metrics = {
            "input_i": float(data.get("input_i", 0)),
            "input_tp": float(data.get("input_tp", 0)),
            "input_lra": float(data.get("input_lra", 0)),
            "input_thresh": float(data.get("input_thresh", 0)),
            "target_offset": float(data.get("target_offset", 0)),
            "raw": data
        }
        return metrics, None
    except Exception as e:
        return None, str(e)

def render_meter_bar(val, min_val=-30.0, max_val=-5.0, width=24):
    """Render an ASCII meter bar for loudness."""
    clamped = max(min_val, min(max_val, val))
    ratio = (clamped - min_val) / (max_val - min_val)
    filled = int(round(ratio * width))
    empty = width - filled
    
    # Color based on value
    if val > -12.0:
        bar_color = RED
    elif val >= -16.0:
        bar_color = GREEN
    elif val >= -20.0:
        bar_color = YELLOW
    else:
        bar_color = CYAN
        
    return f"{bar_color}[{'█' * filled}{'░' * empty}]{NC}"

def print_analysis_card(file_path, metrics):
    name = Path(file_path).name
    i_val = metrics["input_i"]
    tp_val = metrics["input_tp"]
    lra_val = metrics["input_lra"]
    thresh_val = metrics["input_thresh"]
    
    print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}             EBU R128 AUDIO LOUDNESS & TRUE-PEAK REPORT               {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"  {BOLD}File:{NC}          {CYAN}{name}{NC}")
    print(f"  {BOLD}Path:{NC}          {DIM}{file_path}{NC}\n")
    
    # Integrated Loudness
    i_status = ""
    if abs(i_val - (-14.0)) <= 1.0:
        i_status = f"{GREEN}✓ Streaming Optimal (-14 ± 1 LUFS){NC}"
    elif i_val > -13.0:
        i_status = f"{YELLOW}▲ Hotter than streaming standard{NC}"
    else:
        i_status = f"{CYAN}▼ Quieter than streaming standard{NC}"
        
    meter = render_meter_bar(i_val)
    print(f"  {BOLD}Integrated Loudness (I):{NC}  {BOLD}{WHITE}{i_val:+.2f} LUFS{NC}  {meter}  {i_status}")
    
    # True Peak
    tp_status = ""
    if tp_val > 0.0:
        tp_status = f"{RED}⚠️ CLIPPING! True Peak exceeds 0.0 dBTP{NC}"
    elif tp_val > -1.0:
        tp_status = f"{YELLOW}⚠️ Danger: Peak > -1.0 dBTP (May distort during lossy encode){NC}"
    else:
        tp_status = f"{GREEN}✓ Safe Headroom (<= -1.0 dBTP){NC}"
        
    print(f"  {BOLD}Maximum True Peak (TP):{NC}   {BOLD}{WHITE}{tp_val:+.2f} dBTP{NC}  {tp_status}")
    
    # Loudness Range & Threshold
    print(f"  {BOLD}Loudness Range (LRA):{NC}     {BOLD}{WHITE}{lra_val:.2f} LU{NC}    {DIM}(Dynamic expression width){NC}")
    print(f"  {BOLD}Loudness Threshold:{NC}       {DIM}{thresh_val:.2f} LUFS{NC}\n")
    
    # Compliance Matrix
    print(f"  {BOLD}Target Compliance Evaluation:{NC}")
    streaming_diff = -14.0 - i_val
    podcast_diff = -16.0 - i_val
    broadcast_diff = -23.0 - i_val
    
    print(f"    • {BOLD}Streaming (-14 LUFS):{NC}   Gain needed: {streaming_diff:+.2f} dB  {GREEN if abs(streaming_diff)<=1.0 else YELLOW}(Spotify / YouTube / Apple){NC}")
    print(f"    • {BOLD}Podcast   (-16 LUFS):{NC}   Gain needed: {podcast_diff:+.2f} dB  {GREEN if abs(podcast_diff)<=1.0 else CYAN}(Podcasts / Spoken Word){NC}")
    print(f"    • {BOLD}Broadcast (-23 LUFS):{NC}   Gain needed: {broadcast_diff:+.2f} dB  {GREEN if abs(broadcast_diff)<=1.0 else CYAN}(EBU R128 Television / Radio){NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")

def master_normalize(file_path, target_i=-14.0, target_tp=-1.0, target_lra=11.0, output_path=None):
    """Perform two-pass transparent linear normalization."""
    input_p = Path(file_path)
    if not output_path:
        stem = input_p.stem
        ext = input_p.suffix
        output_p = input_p.parent / f"{stem}_NORMALIZED_{int(abs(target_i))}LUFS{ext}"
    else:
        output_p = Path(output_path)
        
    print(f"\n{BOLD}{CYAN}➔ Step 1/2: Analyzing input audio dynamics (Pass 1)...{NC}")
    metrics, err = run_loudness_scan(input_p)
    if not metrics:
        print(f"{RED}Error in Pass 1: {err}{NC}")
        return False
        
    print_analysis_card(input_p, metrics)
    
    print(f"\n{BOLD}{CYAN}➔ Step 2/2: Applying transparent 2-pass linear normalization (Pass 2)...{NC}")
    print(f"  Target: {BOLD}{target_i} LUFS{NC} | True-Peak: {BOLD}{target_tp} dBTP{NC} | LRA: {BOLD}{target_lra} LU{NC}")
    print(f"  Output: {GREEN}{output_p}{NC}\n")
    
    loudnorm_filter = (
        f"loudnorm=I={target_i}:TP={target_tp}:LRA={target_lra}:"
        f"measured_I={metrics['input_i']}:measured_TP={metrics['input_tp']}:"
        f"measured_LRA={metrics['input_lra']}:measured_thresh={metrics['input_thresh']}:"
        f"offset={metrics['target_offset']}:linear=true:print_format=summary"
    )
    
    # Codec selection based on extension
    ext_lower = output_p.suffix.lower()
    codec_args = []
    if ext_lower == ".flac":
        codec_args = ["-c:a", "flac", "-compression_level", "8"]
    elif ext_lower == ".wav":
        codec_args = ["-c:a", "pcm_s24le"]
    elif ext_lower == ".mp3":
        codec_args = ["-c:a", "libmp3lame", "-b:a", "320k"]
    else:
        codec_args = ["-c:a", "flac"]
        
    cmd = [
        "ffmpeg", "-y", "-nostats", "-i", str(input_p),
        "-af", loudnorm_filter,
        *codec_args,
        "-map_metadata", "0",
        str(output_p)
    ]
    
    try:
        proc = subprocess.run(cmd, check=True)
        print(f"\n{BOLD}{GREEN}✓ Successfully generated normalized master:{NC} {output_p}")
        
        # Verify output
        print(f"\n{BOLD}{CYAN}➔ Verifying master output compliance...{NC}")
        out_metrics, _ = run_loudness_scan(output_p)
        if out_metrics:
            print_analysis_card(output_p, out_metrics)
        return True
    except subprocess.CalledProcessError as e:
        print(f"{RED}Normalization failed: {e}{NC}")
        return False

def interactive_menu():
    check_ffmpeg()
    while True:
        print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}         STUDIO MASTERING & EBU R128 LOUDNESS NORMALIZER              {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"  {BOLD}1){NC} Scan Single Audio File (Integrated LUFS, LRA & True-Peak Report)")
        print(f"  {BOLD}2){NC} Scan All FLAC Mixes in Archive / Output Folder")
        print(f"  {BOLD}3){NC} Master & Normalize Single Audio File (2-Pass Linear loudnorm)")
        print(f"  {BOLD}4){NC} Batch Normalize All Mixes in Archive to Streaming (-14 LUFS)")
        print(f"  {BOLD}0){NC} Return to Previous Menu\n")
        
        choice = input("Enter choice [0-4]: ").strip()
        if choice in ["0", "q", "exit"]:
            break
        elif choice == "1":
            target = input("\nEnter path to audio file (or drag & drop): ").strip().strip("'\"")
            if target and os.path.isfile(target):
                metrics, err = run_loudness_scan(target)
                if metrics:
                    print_analysis_card(target, metrics)
                else:
                    print(f"{RED}Error: {err}{NC}")
            else:
                print(f"{RED}File not found.{NC}")
            input(f"\n{DIM}Press Enter to continue...{NC}")
        elif choice == "2":
            scan_dir = input("\nEnter directory path (default: current directory): ").strip().strip("'\"")
            if not scan_dir:
                scan_dir = "."
            p_dir = Path(scan_dir)
            if not p_dir.is_dir():
                print(f"{RED}Directory not found.{NC}")
                continue
            flacs = sorted(list(p_dir.glob("*.flac")) + list(p_dir.glob("*.wav")))
            if not flacs:
                print(f"{YELLOW}No FLAC/WAV audio files found in {scan_dir}{NC}")
                input(f"\n{DIM}Press Enter to continue...{NC}")
                continue
            print(f"\n{CYAN}Found {len(flacs)} audio files. Scanning loudness...{NC}")
            print(f"{BOLD}{'FILENAME':<42} {'INTEGRATED':<14} {'TRUE PEAK':<12} {'LRA':<8} {'STATUS':<15}{NC}")
            print("-" * 95)
            for f in flacs:
                m, _ = run_loudness_scan(f)
                if m:
                    i_str = f"{m['input_i']:+.2f} LUFS"
                    tp_str = f"{m['input_tp']:+.2f} dBTP"
                    lra_str = f"{m['input_lra']:.2f} LU"
                    if abs(m['input_i'] - (-14.0)) <= 1.0 and m['input_tp'] <= -1.0:
                        status = f"{GREEN}Compliant{NC}"
                    elif m['input_tp'] > 0.0:
                        status = f"{RED}CLIPPING{NC}"
                    elif m['input_i'] > -13.0:
                        status = f"{YELLOW}Hot{NC}"
                    else:
                        status = f"{CYAN}Quiet{NC}"
                    fname = f.name[:40]
                    print(f"{fname:<42} {i_str:<14} {tp_str:<12} {lra_str:<8} {status:<15}")
            input(f"\n{DIM}Press Enter to continue...{NC}")
        elif choice == "3":
            target = input("\nEnter path to audio file: ").strip().strip("'\"")
            if not target or not os.path.isfile(target):
                print(f"{RED}File not found.{NC}")
                continue
            print(f"\n{BOLD}Select Target Mastering Preset:{NC}")
            for k, v in TARGET_PROFILES.items():
                print(f"  {BOLD}{k}){NC} {v['name']} ({v['i']} LUFS / {v['tp']} dBTP)")
            print(f"  {BOLD}5){NC} Custom Target LUFS & True Peak")
            
            p_choice = input("Enter target preset [1-5]: ").strip()
            if p_choice in TARGET_PROFILES:
                prof = TARGET_PROFILES[p_choice]
                master_normalize(target, target_i=prof["i"], target_tp=prof["tp"], target_lra=prof["lra"])
            elif p_choice == "5":
                try:
                    c_i = float(input("Enter target LUFS (e.g. -14.0): ").strip())
                    c_tp = float(input("Enter target True Peak dBTP (e.g. -1.0): ").strip())
                    c_lra = float(input("Enter target LRA (e.g. 11.0): ").strip())
                    master_normalize(target, target_i=c_i, target_tp=c_tp, target_lra=c_lra)
                except ValueError:
                    print(f"{RED}Invalid numeric values.{NC}")
            input(f"\n{DIM}Press Enter to continue...{NC}")
        elif choice == "4":
            scan_dir = input("\nEnter directory containing mixes to normalize: ").strip().strip("'\"")
            if not scan_dir:
                scan_dir = "."
            p_dir = Path(scan_dir)
            flacs = sorted(list(p_dir.glob("*.flac")))
            if not flacs:
                print(f"{YELLOW}No FLAC files found in {scan_dir}{NC}")
                continue
            out_folder = p_dir / "NORMALIZED_STREAMING_14LUFS"
            out_folder.mkdir(exist_ok=True)
            print(f"\n{BOLD}{CYAN}Batch Normalizing {len(flacs)} mixes to -14 LUFS / -1.0 dBTP...{NC}")
            print(f"Outputs will be saved in: {GREEN}{out_folder}{NC}\n")
            confirm = input("Proceed? [y/N]: ").strip().lower()
            if confirm == "y":
                for idx, flac in enumerate(flacs, start=1):
                    print(f"\n{BOLD}[{idx}/{len(flacs)}] Processing {flac.name}...{NC}")
                    out_f = out_folder / flac.name
                    master_normalize(flac, target_i=-14.0, target_tp=-1.0, target_lra=11.0, output_path=out_f)
            input(f"\n{DIM}Press Enter to continue...{NC}")

def main():
    parser = argparse.ArgumentParser(description="MP_Mix_Manager_v0.3 - Audio Mastering & EBU R128 Loudness Suite")
    parser.add_argument("file", nargs="?", help="Audio file to scan or normalize")
    parser.add_argument("--scan", action="store_true", help="Scan and display loudness report only")
    parser.add_argument("--normalize", action="store_true", help="Apply 2-pass linear normalization")
    parser.add_argument("--target-i", type=float, default=-14.0, help="Target Integrated Loudness in LUFS (default: -14.0)")
    parser.add_argument("--target-tp", type=float, default=-1.0, help="Target Maximum True Peak in dBTP (default: -1.0)")
    parser.add_argument("--target-lra", type=float, default=11.0, help="Target Loudness Range in LU (default: 11.0)")
    parser.add_argument("-o", "--output", help="Output normalized file path")
    args = parser.parse_args()

    check_ffmpeg()
    
    if not args.file:
        interactive_menu()
        return

    file_p = Path(args.file)
    if not file_p.is_file():
        print(f"{RED}Error: File not found: {args.file}{NC}")
        sys.exit(1)

    if args.normalize:
        master_normalize(file_p, target_i=args.target_i, target_tp=args.target_tp, target_lra=args.target_lra, output_path=args.output)
    else:
        metrics, err = run_loudness_scan(file_p)
        if metrics:
            print_analysis_card(file_p, metrics)
        else:
            print(f"{RED}Error: {err}{NC}")
            sys.exit(1)

if __name__ == "__main__":
    main()
