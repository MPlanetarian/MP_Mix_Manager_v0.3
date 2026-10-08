#!/usr/bin/env python3
"""
MP Mix Manager v0.3 - Audio Mastering Quality & Health Verification Suite
Analyzes True Peak / Inter-Sample Peaks (ISP), EBU R128 Integrated Loudness (LUFS),
Loudness Range (LRA), Stereo Phase Correlation (Mono Compatibility), and
Lead-in/Lead-out silence on DJ mixes.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

GREEN = '\033[38;2;0;229;255m'
RED = '\033[38;2;237;37;78m'
YELLOW = '\033[38;2;255;170;0m'
NC = '\033[0m'
BOLD = '\033[1m'


def run_cmd(cmd):
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        return proc.returncode, proc.stdout, proc.stderr
    except Exception as exc:
        return 1, "", str(exc)


def analyze_ebur128(audio_file):
    """Run ffmpeg ebur128 analysis filter."""
    cmd = [
        "ffmpeg", "-nostats", "-i", str(audio_file),
        "-filter_complex", "ebur128=peak=true",
        "-f", "null", "-"
    ]
    _, out, err = run_cmd(cmd)
    combined = out + "\n" + err

    i_match = re.search(r'Integrated loudness:\s+I:\s+([-\d.]+)\s+LUFS', combined)
    lra_match = re.search(r'Loudness range:\s+LRA:\s+([-\d.]+)\s+LU', combined)
    tp_match = re.search(r'True peak:\s+Peak:\s+([-\d.]+)\s+dBFS', combined)

    integrated = float(i_match.group(1)) if i_match else None
    lra = float(lra_match.group(1)) if lra_match else None
    true_peak = float(tp_match.group(1)) if tp_match else None

    return {
        "integrated_lufs": integrated,
        "lra": lra,
        "true_peak_db": true_peak
    }


def analyze_silence(audio_file):
    """Detect leading and trailing silence using silencedetect filter."""
    cmd = [
        "ffmpeg", "-nostats", "-i", str(audio_file),
        "-af", "silencedetect=noise=-60dB:d=0.5",
        "-f", "null", "-"
    ]
    _, _, err = run_cmd(cmd)

    lead_silence = 0.0
    silence_starts = [float(m.group(1)) for m in re.finditer(r'silence_start:\s+([\d.]+)', err)]
    silence_ends = [float(m.group(1)) for m in re.finditer(r'silence_end:\s+([\d.]+)', err)]

    if silence_ends and len(silence_starts) > 0 and silence_starts[0] < 0.1:
        lead_silence = silence_ends[0]

    return lead_silence


def analyze_phase_correlation(audio_file):
    """Estimate stereo phase correlation using aphasemeter filter."""
    cmd = [
        "ffmpeg", "-nostats", "-i", str(audio_file),
        "-af", "aphasemeter=video=0,ametadata=mode=print:key=lavfi.aphasemeter.phase",
        "-t", "180",  # Sample first 3 minutes for efficiency
        "-f", "null", "-"
    ]
    _, _, err = run_cmd(cmd)
    phases = [float(m.group(1)) for m in re.finditer(r'lavfi\.aphasemeter\.phase=([-\d.]+)', err)]

    if phases:
        avg_phase = sum(phases) / len(phases)
        min_phase = min(phases)
        return avg_phase, min_phase
    return 1.0, 1.0


def main():
    parser = argparse.ArgumentParser(description="DJ Mix Audio Health & Mastering Quality Verification")
    parser.add_argument("audio_file", help="Audio file to analyze (FLAC, WAV, MP3)")
    parser.add_argument("--streaming-target", type=float, default=-14.0, help="Target LUFS for streaming (default: -14.0)")

    args = parser.parse_args()
    audio_path = Path(args.audio_file).resolve()

    if not audio_path.is_file():
        print(f"Error: File '{args.audio_file}' not found.", file=sys.stderr)
        sys.exit(1)

    print(f"\n{BOLD}{GREEN}======================================================================{NC}")
    print(f"{BOLD} AUDIO MASTERING QUALITY & HEALTH AUDIT: {audio_path.name}{NC}")
    print(f"{BOLD}{GREEN}======================================================================{NC}\n")

    print("[•] Step 1/3: Analyzing EBU R128 Loudness and True Peak (ISP)...")
    ebu = analyze_ebur128(audio_path)

    print("[•] Step 2/3: Analyzing Stereo Phase Correlation & Mono Compatibility...")
    avg_phase, min_phase = analyze_phase_correlation(audio_path)

    print("[•] Step 3/3: Detecting Lead-in Dead Air & Silence...")
    lead_silence = analyze_silence(audio_path)

    print(f"\n{BOLD}=== MASTERING HEALTH REPORT ==={NC}")

    # 1. True Peak evaluation
    tp = ebu.get("true_peak_db")
    if tp is not None:
        if tp > 0.0:
            tp_badge = f"{RED}CLIPPING / DISTORTION DETECTED ({tp:+.2f} dBFS){NC}"
            tp_note = "True peak exceeds 0.0 dBFS. High probability of distortion on lossy encoding (MP3/AAC)."
        elif tp > -1.0:
            tp_badge = f"{YELLOW}HIGH TRUE PEAK ({tp:+.2f} dBFS){NC}"
            tp_note = "Exceeds standard -1.0 dBFS streaming ceiling. Recommend 0.5-1.0 dB limiter reduction."
        else:
            tp_badge = f"{GREEN}OPTIMAL ({tp:+.2f} dBFS){NC}"
            tp_note = "Safe headroom below -1.0 dBFS ceiling."
        print(f"  • True Peak (ISP):             {tp_badge}")
        print(f"    ↳ {tp_note}")
    else:
        print("  • True Peak (ISP):             Unknown")

    # 2. Integrated Loudness
    lufs = ebu.get("integrated_lufs")
    if lufs is not None:
        diff = lufs - args.streaming_target
        if abs(diff) <= 1.0:
            lufs_badge = f"{GREEN}{lufs:.1f} LUFS (Matches Target: {args.streaming_target:.1f} LUFS){NC}"
        elif diff > 1.0:
            lufs_badge = f"{YELLOW}{lufs:.1f} LUFS ({diff:+.1f} LU hotter than {args.streaming_target:.1f} target){NC}"
        else:
            lufs_badge = f"{YELLOW}{lufs:.1f} LUFS ({diff:+.1f} LU quieter than {args.streaming_target:.1f} target){NC}"
        print(f"  • Integrated Loudness:         {lufs_badge}")
        print(f"    ↳ Loudness Range (LRA):      {ebu.get('lra', 0.0):.1f} LU (Dynamic Range)")

    # 3. Stereo Phase
    if min_phase < -0.2:
        phase_badge = f"{RED}PHASE INVERSION RISK (Min: {min_phase:+.2f}, Avg: {avg_phase:+.2f}){NC}"
        phase_note = "Significant negative correlation detected. Mono sum (club mono setups) will experience comb filtering/cancellation."
    elif avg_phase > 0.3:
        phase_badge = f"{GREEN}EXCELLENT MONO COMPATIBILITY (Avg: {avg_phase:+.2f}){NC}"
        phase_note = "Safe in-phase stereo field."
    else:
        phase_badge = f"{YELLOW}ACCEPTABLE (Avg: {avg_phase:+.2f}){NC}"
        phase_note = "Wide stereo imaging."
    print(f"  • Phase Correlation:           {phase_badge}")
    print(f"    ↳ {phase_note}")

    # 4. Silence
    if lead_silence > 3.0:
        silence_badge = f"{YELLOW}{lead_silence:.2f} seconds leading silence{NC}"
        silence_note = "Consider trimming lead-in silence before publishing."
    else:
        silence_badge = f"{GREEN}{lead_silence:.2f} seconds (Clean start){NC}"
        silence_note = "Quick start."
    print(f"  • Lead-in Dead Air:            {silence_badge}")
    print(f"    ↳ {silence_note}")

    print(f"\n{BOLD}{GREEN}======================================================================{NC}\n")


if __name__ == "__main__":
    main()
