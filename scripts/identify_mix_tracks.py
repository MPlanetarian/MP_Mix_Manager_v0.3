#!/usr/bin/env python3
"""
MP Mix Manager v0.3 - Audio Fingerprinting & Mix Track Identifier
Extracts short audio snippets across DJ mix transition points or regular intervals
and queries AcoustID / Shazam recognition engines to identify unknown tracks and
generate a ready-to-use tracklist with timestamps.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path


def get_audio_duration(audio_file):
    """Probe audio duration in seconds using ffprobe."""
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
        return 0.0


def extract_snippet(audio_file, start_sec, duration_sec, output_wav):
    """Extract a short audio snippet as 44.1kHz 16-bit stereo WAV using ffmpeg."""
    cmd = [
        "ffmpeg", "-y", "-ss", str(start_sec), "-t", str(duration_sec),
        "-i", audio_file,
        "-ac", "2", "-ar", "44100", "-c:a", "pcm_s16le",
        output_wav
    ]
    try:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        return os.path.isfile(output_wav) and os.path.getsize(output_wav) > 1000
    except Exception:
        return False


def identify_via_fpcalc(snippet_path, api_key="8XaBELgH"):
    """Query AcoustID API using fpcalc."""
    fpcalc_bin = shutil.which("fpcalc")
    if not fpcalc_bin:
        return None

    try:
        cmd = [fpcalc_bin, "-json", snippet_path]
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode('utf-8')
        data = json.loads(out)
        duration = data.get("duration")
        fingerprint = data.get("fingerprint")
        if not fingerprint:
            return None

        # Query AcoustID webservice
        url = "https://api.acoustid.org/v2/lookup"
        params = urllib.parse.urlencode({
            "client": api_key,
            "meta": "recordings+releasegroups",
            "duration": int(duration),
            "fingerprint": fingerprint
        }).encode('utf-8')

        req = urllib.request.Request(url, data=params, headers={"User-Agent": "MP_Mix_Manager/0.3"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            res_data = json.loads(resp.read().decode('utf-8'))
            results = res_data.get("results", [])
            for r in results:
                recordings = r.get("recordings", [])
                for rec in recordings:
                    title = rec.get("title")
                    artists = [a.get("name") for a in rec.get("artists", []) if a.get("name")]
                    artist_str = ", ".join(artists) if artists else "Unknown Artist"
                    if title:
                        return f"{artist_str} - {title}"
    except Exception:
        pass
    return None


def format_seconds(sec):
    sec = max(0, int(sec))
    h = sec // 3600
    m = (sec % 3600) // 60
    s = sec % 60
    return f"{h:02d}:{m:02d}:{s:02d}"


def main():
    parser = argparse.ArgumentParser(description="Auto-Identify Tracks in a DJ Mix")
    parser.add_argument("audio_file", help="Path to FLAC, WAV, or MP3 mix file")
    parser.add_argument("--interval", "-i", type=int, default=300, help="Interval between probes in seconds (default: 300s = 5m)")
    parser.add_argument("--duration", "-d", type=int, default=12, help="Snippet length in seconds (default: 12s)")
    parser.add_argument("--output", "-o", help="Output tracklist file path", default=None)

    args = parser.parse_args()
    audio_path = Path(args.audio_file).resolve()
    if not audio_path.is_file():
        print(f"Error: Audio file '{args.audio_file}' not found.", file=sys.stderr)
        sys.exit(1)

    total_duration = get_audio_duration(str(audio_path))
    if total_duration <= 0:
        print("Error: Could not determine audio duration via ffprobe.", file=sys.stderr)
        sys.exit(1)

    print(f"\n[•] Audio Mix: {audio_path.name}")
    print(f"[•] Total Duration: {format_seconds(total_duration)} ({int(total_duration)} seconds)")
    print(f"[•] Scanning for tracks every {args.interval // 60}m {args.interval % 60}s...\n")

    timestamps = []
    current_sec = 0
    while current_sec < total_duration - 15:
        timestamps.append(current_sec)
        current_sec += args.interval

    track_results = []
    with tempfile.TemporaryDirectory() as tmpdir:
        for idx, ts in enumerate(timestamps, start=1):
            ts_fmt = format_seconds(ts)
            snippet_file = os.path.join(tmpdir, f"snippet_{idx}.wav")
            print(f"  [{idx:02d}/{len(timestamps):02d}] Probing at [{ts_fmt}]... ", end="", flush=True)

            if extract_snippet(str(audio_path), ts, args.duration, snippet_file):
                identified = identify_via_fpcalc(snippet_file)
                if identified:
                    print(f"✓ Found: {identified}")
                    track_results.append((ts_fmt, identified))
                else:
                    print("— (Unrecognized or no match)")
                    track_results.append((ts_fmt, f"Track {idx:02d} (Unidentified)"))
            else:
                print("⚠️ Snippet extraction failed.")
                track_results.append((ts_fmt, f"Track {idx:02d}"))

    out_lines = [f"# Identified Tracklist: {audio_path.stem}", f"# Generated by MP Mix Archive Manager v0.3\n"]
    for idx, (ts_fmt, title) in enumerate(track_results, start=1):
        out_lines.append(f"{idx:02d}. [{ts_fmt}] {title}")

    result_txt = "\n".join(out_lines)

    output_path = args.output or audio_path.parent / f"{audio_path.stem}_identified_tracklist.txt"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(result_txt + "\n")

    print(f"\n[✓] Finished! Tracklist generated at: {output_path}")


if __name__ == "__main__":
    main()
