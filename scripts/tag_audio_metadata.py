#!/usr/bin/env python3
"""
MP Mix Manager v0.3 - Lossless Audio Metadata & ReplayGain Tagging Suite
Embeds cover art, Vorbis comments, CUE sheets, and non-destructive EBU R128
ReplayGain tags directly into FLAC and MP3 containers without re-encoding audio.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run_cmd(cmd):
    """Run shell command safely."""
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        return proc.returncode, proc.stdout, proc.stderr
    except Exception as exc:
        return 1, "", str(exc)


def calculate_ebur128_gain(audio_file):
    """
    Analyze audio with ffmpeg ebur128 filter to compute ReplayGain tags.
    Target reference level: -18.0 LUFS (standard ReplayGain 2.0).
    """
    if not shutil.which("ffmpeg"):
        return None, None

    cmd = [
        "ffmpeg", "-nostats", "-i", audio_file,
        "-filter_complex", "ebur128=peak=true",
        "-f", "null", "-"
    ]
    code, out, err = run_cmd(cmd)
    combined = out + "\n" + err

    # Look for Integrated loudness and True peak in summary
    # Integrated loudness:\n    I:         -14.2 LUFS
    # True peak:\n    Peak:       -0.5 dBFS
    i_match = re.search(r'Integrated loudness:\s+I:\s+([-\d.]+)\s+LUFS', combined)
    peak_match = re.search(r'True peak:\s+Peak:\s+([-\d.]+)\s+dBFS', combined)

    if not i_match:
        # Fallback regex
        i_match = re.search(r'I:\s+([-\d.]+)\s+LUFS', combined)

    if i_match:
        integrated_lufs = float(i_match.group(1))
        # ReplayGain 2.0 uses -18.0 LUFS reference level
        # Track gain = -18.0 - integrated_lufs
        gain_db = -18.0 - integrated_lufs
        peak_val = 1.0
        if peak_match:
            try:
                peak_db = float(peak_match.group(1))
                peak_val = 10.0 ** (peak_db / 20.0)
            except Exception:
                peak_val = 1.0
        return f"{gain_db:+.2f} dB", f"{peak_val:.6f}"
    return None, None


def tag_flac(audio_file, cover_file=None, cue_file=None, tags=None, calculate_gain=True):
    """Tag FLAC file using metaflac or mutagen."""
    metaflac_bin = shutil.which("metaflac")
    if not metaflac_bin:
        print(f"Error: 'metaflac' utility not found. Please install flac package.", file=sys.stderr)
        return False

    audio_path = Path(audio_file).resolve()
    print(f"\n[•] Tagging FLAC: {audio_path.name}...")

    # 1. Embed Vorbis comments
    if tags:
        for k, v in tags.items():
            if v:
                run_cmd([metaflac_bin, f"--remove-tag={k.upper()}", str(audio_path)])
                run_cmd([metaflac_bin, f"--set-tag={k.upper()}={v}", str(audio_path)])
                print(f"  ✓ Set tag: {k.upper()} = {v}")

    # 2. Embed CUE Sheet if provided
    if cue_file and os.path.isfile(cue_file):
        run_cmd([metaflac_bin, "--remove", "--block-type=CUESHEET", str(audio_path)])
        rc, _, err = run_cmd([metaflac_bin, f"--import-cuesheet-from={cue_file}", str(audio_path)])
        if rc == 0:
            print(f"  ✓ Embedded CUE Sheet: {Path(cue_file).name}")
        else:
            print(f"  ⚠️ CUE embedding warning: {err.strip()[:80]}")

    # 3. Embed Cover Art
    if cover_file and os.path.isfile(cover_file):
        run_cmd([metaflac_bin, "--remove", "--block-type=PICTURE", str(audio_path)])
        # 3 = Front cover
        rc, _, err = run_cmd([metaflac_bin, f"--import-picture-from=3||||{cover_file}", str(audio_path)])
        if rc == 0:
            print(f"  ✓ Embedded Front Cover Art: {Path(cover_file).name}")
        else:
            print(f"  ⚠️ Picture embedding warning: {err.strip()[:80]}")

    # 4. Non-destructive ReplayGain calculation
    if calculate_gain:
        print("  ⏳ Analyzing EBU R128 loudness for ReplayGain metadata...")
        gain, peak = calculate_ebur128_gain(str(audio_path))
        if gain:
            run_cmd([metaflac_bin, f"--remove-tag=REPLAYGAIN_TRACK_GAIN", str(audio_path)])
            run_cmd([metaflac_bin, f"--remove-tag=REPLAYGAIN_TRACK_PEAK", str(audio_path)])
            run_cmd([metaflac_bin, f"--set-tag=REPLAYGAIN_TRACK_GAIN={gain}", str(audio_path)])
            run_cmd([metaflac_bin, f"--set-tag=REPLAYGAIN_TRACK_PEAK={peak}", str(audio_path)])
            print(f"  ✓ Injected ReplayGain: Gain = {gain}, Peak = {peak}")
        else:
            print("  ⚠️ Could not compute EBU R128 loudness.")

    print(f"[✓] FLAC tagging complete: {audio_path.name}")
    return True


def tag_mp3(audio_file, cover_file=None, tags=None, calculate_gain=True):
    """Tag MP3 file using ffmpeg."""
    if not shutil.which("ffmpeg"):
        print("Error: ffmpeg not found.", file=sys.stderr)
        return False

    audio_path = Path(audio_file).resolve()
    print(f"\n[•] Tagging MP3: {audio_path.name}...")

    gain, peak = None, None
    if calculate_gain:
        print("  ⏳ Analyzing EBU R128 loudness for MP3...")
        gain, peak = calculate_ebur128_gain(str(audio_path))

    temp_out = audio_path.with_name(f"{audio_path.stem}_tagged.mp3")

    cmd = ["ffmpeg", "-y", "-i", str(audio_path)]
    if cover_file and os.path.isfile(cover_file):
        cmd.extend(["-i", str(cover_file), "-map", "0:a", "-map", "1:0", "-c:v", "mjpeg", "-metadata:s:v", "title=Album cover", "-metadata:s:v", "comment=Cover (front)"])
    else:
        cmd.extend(["-map", "0:a"])

    cmd.extend(["-c:a", "copy", "-id3v2_version", "3"])

    if tags:
        for k, v in tags.items():
            if v:
                cmd.extend(["-metadata", f"{k.lower()}={v}"])

    if gain:
        cmd.extend(["-metadata", f"REPLAYGAIN_TRACK_GAIN={gain}"])
        cmd.extend(["-metadata", f"REPLAYGAIN_TRACK_PEAK={peak}"])

    cmd.append(str(temp_out))

    rc, _, err = run_cmd(cmd)
    if rc == 0 and temp_out.is_file() and temp_out.stat().st_size > 1024:
        temp_out.replace(audio_path)
        print(f"[✓] MP3 metadata and cover injected successfully: {audio_path.name}")
        return True
    else:
        if temp_out.is_file():
            temp_out.unlink()
        print(f"  ⚠️ Error tagging MP3: {err[:100]}", file=sys.stderr)
        return False


def find_companion_assets(audio_path):
    """Find matching cover art, CUE sheet, and tracklist in same or sibling folders."""
    stem = audio_path.stem
    folder = audio_path.parent
    base_dir = folder.parent

    cover_candidates = [
        folder / f"{stem}.png",
        folder / f"{stem}.jpg",
        folder / "Cover.png",
        folder / "cover.png",
        base_dir / "COVERS" / f"{stem}.png",
        base_dir / "COVERS" / "Cover.png",
        base_dir / "Cover.png",
    ]
    found_cover = None
    for c in cover_candidates:
        if c.is_file():
            found_cover = str(c)
            break

    cue_candidates = [
        folder / f"{stem}.cue",
        base_dir / f"{stem}.cue",
    ]
    found_cue = None
    for c in cue_candidates:
        if c.is_file():
            found_cue = str(c)
            break

    return found_cover, found_cue


def main():
    parser = argparse.ArgumentParser(description="Embed Cover Art, CUE, Vorbis/ID3 Tags & ReplayGain into Mixes")
    parser.add_argument("target", help="Audio file or directory containing FLAC/MP3 files")
    parser.add_argument("--cover", "-c", help="Path to cover art image (.png or .jpg)", default=None)
    parser.add_argument("--cue", help="Path to .cue sheet", default=None)
    parser.add_argument("--title", help="Mix title / track title", default=None)
    parser.add_argument("--artist", help="Artist name", default=None)
    parser.add_argument("--album", help="Album / Series title", default=None)
    parser.add_argument("--genre", help="Music genre", default=None)
    parser.add_argument("--date", help="Release year / date", default=None)
    parser.add_argument("--no-replaygain", action="store_true", help="Skip ReplayGain calculation")

    args = parser.parse_args()
    target_path = Path(args.target).resolve()

    if not target_path.exists():
        print(f"Error: Target '{args.target}' does not exist.", file=sys.stderr)
        sys.exit(1)

    files_to_tag = []
    if target_path.is_file():
        files_to_tag.append(target_path)
    else:
        for f in target_path.rglob("*"):
            if f.suffix.lower() in [".flac", ".mp3"] and f.is_file():
                files_to_tag.append(f)

    if not files_to_tag:
        print(f"No FLAC or MP3 audio files found at {target_path}.")
        sys.exit(0)

    print(f"Found {len(files_to_tag)} audio file(s) to process.")

    calc_gain = not args.no_replaygain

    for af in files_to_tag:
        cover_file = args.cover
        cue_file = args.cue
        auto_cover, auto_cue = find_companion_assets(af)
        if not cover_file:
            cover_file = auto_cover
        if not cue_file:
            cue_file = auto_cue

        # Extract artist / title if not given
        tags = {
            "TITLE": args.title or af.stem,
            "ARTIST": args.artist or "MPlanetarian",
            "ALBUM": args.album or "Stream of Frequency",
            "GENRE": args.genre or "Trance / Progressive / Electronic",
            "DATE": args.date or str(os.path.getmtime(af)),
        }
        # If filename is "Artist - Title", parse it
        if " - " in af.stem and not args.title:
            parts = af.stem.split(" - ", 1)
            tags["ARTIST"] = parts[0].strip()
            tags["TITLE"] = parts[1].strip()

        ext = af.suffix.lower()
        if ext == ".flac":
            tag_flac(af, cover_file=cover_file, cue_file=cue_file, tags=tags, calculate_gain=calc_gain)
        elif ext == ".mp3":
            tag_mp3(af, cover_file=cover_file, tags=tags, calculate_gain=calc_gain)


if __name__ == "__main__":
    main()
