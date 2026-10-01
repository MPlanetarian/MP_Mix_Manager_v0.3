#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Lossless Legitimacy & Spectral Cutoff Inspector
- Analyzes FLAC and WAV files for transcode upscales ("Fake FLACs" converted from MP3 128k/192k/320k)
- Samples multiple audio segments across the mix, computes FFT power spectral density (PSD)
- Detects steep brickwall low-pass filter shelves (e.g. 16kHz, 18.5kHz, 20.5kHz cutoffs)
- Generates ASCII frequency spectrum distribution and authenticity confidence rating
"""

import os
import sys
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

try:
    import numpy as np
except ImportError:
    print(f"{RED}Error: numpy is required for spectral analysis. Please run: pip install numpy{NC}")
    sys.exit(1)

def check_ffmpeg():
    if not shutil.which("ffmpeg"):
        print(f"{RED}Error: ffmpeg is not installed or not in PATH.{NC}")
        sys.exit(1)

def get_audio_info(file_path):
    """Retrieve duration and sample rate via ffprobe/ffmpeg."""
    cmd = [
        "ffprobe", "-v", "error", "-select_streams", "a:0",
        "-show_entries", "stream=sample_rate,duration",
        "-of", "default=noprint_wrappers=1:nokey=1", str(file_path)
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = [line.strip() for line in res.stdout.strip().split("\n") if line.strip()]
        if len(lines) >= 2:
            sr = int(lines[0])
            dur = float(lines[1])
            return sr, dur
    except Exception:
        pass
        
    # Fallback to ffmpeg output parsing
    try:
        res2 = subprocess.run(["ffmpeg", "-i", str(file_path)], capture_output=True, text=True)
        m_sr = re.search(r"(\d{4,6})\s*Hz", res2.stderr)
        m_dur = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.?\d*)", res2.stderr)
        sr = int(m_sr.group(1)) if m_sr else 44100
        dur = 3600.0
        if m_dur:
            dur = float(m_dur.group(1)) * 3600 + float(m_dur.group(2)) * 60 + float(m_dur.group(3))
        return sr, dur
    except Exception:
        return 44100, 3600.0

def extract_pcm_slice(file_path, start_sec, duration_sec=6.0, sample_rate=44100):
    """Extract raw 16-bit mono PCM samples at a given timestamp."""
    cmd = [
        "ffmpeg", "-v", "error", "-ss", str(start_sec), "-t", str(duration_sec),
        "-i", str(file_path),
        "-f", "s16le", "-ac", "1", "-ar", str(sample_rate), "-"
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, check=True)
        samples = np.frombuffer(proc.stdout, dtype=np.int16).astype(np.float32)
        return samples
    except Exception:
        return None

def compute_spectrum(samples, sample_rate=44100):
    """Compute average FFT power spectrum in decibels across windowed segments."""
    if len(samples) < 2048:
        return None, None
    n_fft = 2048
    hop = 1024
    window = np.hanning(n_fft)
    
    psd_list = []
    for i in range(0, len(samples) - n_fft, hop):
        frame = samples[i:i + n_fft] * window
        fft_vals = np.fft.rfft(frame)
        power = np.abs(fft_vals) ** 2
        psd_list.append(power)
        
    if not psd_list:
        return None, None
        
    mean_power = np.mean(psd_list, axis=0)
    # Avoid log of zero
    mean_power = np.maximum(mean_power, 1e-12)
    power_db = 10 * np.log10(mean_power)
    # Normalize peak to 0 dB
    power_db -= np.max(power_db)
    
    freqs = np.fft.rfftfreq(n_fft, d=1.0 / sample_rate)
    return freqs, power_db

def evaluate_lossless_authenticity(file_path):
    """Analyze multiple audio segments to determine if audio is genuine lossless."""
    sample_rate, duration = get_audio_info(file_path)
    
    # Analyze multiple points across mix, scaling slice duration to file length
    slice_dur = min(5.0, max(1.0, duration * 0.15))
    if duration <= 6.0:
        check_points = [0.0]
        slice_dur = max(0.5, duration * 0.9)
    else:
        check_points = [
            duration * 0.15,
            duration * 0.35,
            duration * 0.55,
            duration * 0.75
        ]
    
    all_spectra = []
    freq_axis = None
    
    for pt in check_points:
        safe_start = min(pt, max(0.0, duration - slice_dur))
        samples = extract_pcm_slice(file_path, start_sec=safe_start, duration_sec=slice_dur, sample_rate=sample_rate)
        if samples is not None and len(samples) >= 2048:
            freqs, p_db = compute_spectrum(samples, sample_rate=sample_rate)
            if p_db is not None:
                all_spectra.append(p_db)
                freq_axis = freqs
                
    if not all_spectra or freq_axis is None:
        return None, "Unable to extract audio samples for analysis."
        
    avg_db = np.mean(all_spectra, axis=0)
    
    # Helper to calculate average dB power in a frequency band
    def get_band_power(f_min, f_max):
        mask = (freq_axis >= f_min) & (freq_axis <= f_max)
        if not np.any(mask):
            return -100.0
        return float(np.mean(avg_db[mask]))
        
    # Measure critical frequency bands
    db_core = get_band_power(1000, 10000)      # Baseline audible core
    db_15k  = get_band_power(14500, 15500)     # Near MP3 128k boundary
    db_17k  = get_band_power(16500, 17500)     # MP3 128k drop zone
    db_19k  = get_band_power(18500, 19500)     # MP3 192k drop zone
    db_20k  = get_band_power(19800, 20400)     # Pre-320k boundary
    db_21k  = get_band_power(20800, 21800)     # MP3 320k drop zone / CDDA top edge
    
    # Measure roll-off drops relative to core
    drop_16k = db_core - db_17k
    drop_19k = db_core - db_19k
    drop_21k = db_core - db_21k
    
    # Detect sharp cliff between 20k and 21k (typical MP3 320k)
    shelf_320k = db_20k - db_21k
    shelf_192k = db_17k - db_19k
    shelf_128k = db_15k - db_17k
    
    # Classification verdict
    verdict = ""
    rating = ""
    color = NC
    details = ""
    
    if shelf_128k > 20.0 or (db_core - db_17k > 40.0 and db_17k < -50.0):
        rating = "FAKE LOSSLESS (MP3 128kbps Transcode)"
        verdict = "Severe brickwall low-pass cutoff at ~16.0 kHz detected."
        color = RED
    elif shelf_192k > 18.0 or (db_core - db_19k > 35.0 and db_19k < -50.0):
        rating = "TRANSCODE DETECTED (MP3 192kbps Transcode)"
        verdict = "Clear brickwall low-pass cutoff at ~18.5 kHz detected."
        color = RED
    elif shelf_320k > 15.0 or (db_core - db_21k > 22.0 and db_core > -40.0):
        rating = "SUSPECT TRANSLOSS (MP3 320kbps / AAC 256k Cutoff)"
        verdict = "High-frequency energy plummets sharply at ~20.5 kHz (typical lossy encoder shelf)."
        color = YELLOW
    elif db_21k >= -48.0 or (db_core - db_21k < 20.0):
        rating = "GENUINE LOSSLESS (Full CD/Studio Bandwidth)"
        verdict = f"Natural unbroken high-frequency harmonics extending to {sample_rate/2000:.1f} kHz."
        color = GREEN
    else:
        rating = "LIKELY LOSSLESS / ACOUSTIC ROLLOFF"
        verdict = "Gentle natural roll-off without sharp encoder brickwall shelves."
        color = GREEN

    results = {
        "rating": rating,
        "verdict": verdict,
        "color": color,
        "sample_rate": sample_rate,
        "duration": duration,
        "db_core": db_core,
        "db_15k": db_15k,
        "db_17k": db_17k,
        "db_19k": db_19k,
        "db_20k": db_20k,
        "db_21k": db_21k,
        "shelf_320k": shelf_320k,
        "freq_axis": freq_axis,
        "avg_db": avg_db
    }
    return results, None

def print_spectral_report(file_path, res):
    name = Path(file_path).name
    c = res["color"]
    
    print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}          LOSSLESS LEGITIMACY & SPECTRAL CUTOFF INSPECTOR             {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"  {BOLD}File:{NC}          {CYAN}{name}{NC}")
    print(f"  {BOLD}Sample Rate:{NC}   {WHITE}{res['sample_rate']} Hz{NC} (Nyquist Limit: {res['sample_rate']/2000:.1f} kHz)")
    print(f"  {BOLD}Authenticity:{NC}  {BOLD}{c}{res['rating']}{NC}")
    print(f"  {BOLD}Analysis:{NC}      {DIM}{res['verdict']}{NC}\n")
    
    print(f"  {BOLD}High-Frequency Power Distribution (dB):{NC}")
    print(f"  {'Band':<16} {'Avg Power':<12} {'Visual Distribution':<28}")
    print("  " + "-" * 56)
    
    bands = [
        ("Core (1-10 kHz)", res["db_core"]),
        ("15 kHz (128k lim)", res["db_15k"]),
        ("17 kHz (128k cut)", res["db_17k"]),
        ("19 kHz (192k cut)", res["db_19k"]),
        ("20 kHz (320k lim)", res["db_20k"]),
        ("21+ kHz (CDDA Nyq)", res["db_21k"]),
    ]
    
    for label, pwr in bands:
        # Normalize -70 dB to 0 dB to bar length 20
        clamped = max(-70.0, min(0.0, pwr))
        ratio = (clamped + 70.0) / 70.0
        bar_len = int(round(ratio * 20))
        bar_col = GREEN if pwr > -45.0 else (YELLOW if pwr > -60.0 else RED)
        bar_str = f"{bar_col}{'█' * bar_len}{DIM}{'░' * (20 - bar_len)}{NC}"
        print(f"  {label:<16} {pwr:>6.1f} dB    {bar_str}")
        
    print(f"{BOLD}{MAGENTA}======================================================================{NC}\n")

def interactive_menu():
    check_ffmpeg()
    while True:
        print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}            LOSSLESS LEGITIMACY & FAKE FLAC INSPECTOR                 {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"  {BOLD}1){NC} Inspect Single Audio File (Full Spectral Cutoff Analysis)")
        print(f"  {BOLD}2){NC} Batch Inspect All FLAC Mixes in Archive / Output Folder")
        print(f"  {BOLD}0){NC} Return to Previous Menu\n")
        
        choice = input("Enter choice [0-2]: ").strip()
        if choice in ["0", "q", "exit"]:
            break
        elif choice == "1":
            target = input("\nEnter path to audio file (or drag & drop): ").strip().strip("'\"")
            if target and os.path.isfile(target):
                print(f"\n{CYAN}Extracting audio slices and computing FFT power spectrum...{NC}")
                res, err = evaluate_lossless_authenticity(target)
                if res:
                    print_spectral_report(target, res)
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
            flacs = sorted(list(p_dir.glob("*.flac")) + list(p_dir.glob("*.wav")))
            if not flacs:
                print(f"{YELLOW}No FLAC/WAV files found in {scan_dir}{NC}")
                input(f"\n{DIM}Press Enter to continue...{NC}")
                continue
            print(f"\n{CYAN}Found {len(flacs)} audio files. Auditing spectral authenticity...{NC}\n")
            print(f"{BOLD}{'FILENAME':<44} {'VERDICT':<36} {'21kHz dB':<10}{NC}")
            print("-" * 92)
            
            for f in flacs:
                res, _ = evaluate_lossless_authenticity(f)
                if res:
                    fname = f.name[:42]
                    v_str = f"{res['color']}{res['rating'][:34]}{NC}"
                    db_str = f"{res['db_21k']:.1f} dB"
                    print(f"{fname:<44} {v_str:<44} {db_str:<10}")
            input(f"\n{DIM}Press Enter to continue...{NC}")

def main():
    parser = argparse.ArgumentParser(description="MP_Mix_Manager_v0.3 - Lossless Legitimacy & Spectral Inspector")
    parser.add_argument("file", nargs="?", help="Audio file to inspect")
    parser.add_argument("--batch", "-b", help="Inspect all audio files in directory")
    args = parser.parse_args()

    check_ffmpeg()
    
    if not args.file and not args.batch:
        interactive_menu()
        return

    if args.batch:
        p_dir = Path(args.batch)
        flacs = sorted(list(p_dir.glob("*.flac")) + list(p_dir.glob("*.wav")))
        for f in flacs:
            res, _ = evaluate_lossless_authenticity(f)
            if res:
                print_spectral_report(f, res)
    elif args.file:
        res, err = evaluate_lossless_authenticity(args.file)
        if res:
            print_spectral_report(args.file, res)
        else:
            print(f"{RED}Error: {err}{NC}")
            sys.exit(1)

if __name__ == "__main__":
    main()
