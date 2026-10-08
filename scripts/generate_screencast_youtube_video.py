#!/usr/bin/env python3
"""
Generate a 1080p YouTube video for "MPlanetarian - MP Harmony AI Agent Fixes MP Mix Manager".
Features:
- Hardware-accelerated NVENC encoding at 1080p Full HD (30fps)
- 5s Intro with Sensorium_Interface.jpeg fading in from black, then dissolving into screencast
- Screencast playback with seamless 5s image transitions every 5 minutes (cycling through 4 images)
- Screencast finishes, dissolves into Cover_v3.jpeg, which fades out to black for 5s
- High fidelity 320kbps AAC audio looped to match video length with 5s fades at start/end
"""

import os
import sys
import time
import shutil
import subprocess
from PIL import Image

SRC_DIR = "/run/media/mplanetarian/DATA/Sensorium Interface"
VIDEO_FILE = os.path.join(SRC_DIR, "Screencast_20261008_081210.mp4")
AUDIO_FILE = os.path.join(SRC_DIR, "MPlanetarian - Stream of Frequency 074.wav")
OUTPUT_FILE = os.path.join(SRC_DIR, "MPlanetarian_MP_Harmony_AI_Agent_Fixes_MP_Mix_Manager.mp4")
TEMP_DIR = "/run/media/mplanetarian/DATA/tmp_render_agent_video"

WIDTH = 1920
HEIGHT = 1080
FPS = 30
INTERVAL_SEC = 300.0  # 5 minutes
TRANS_DUR = 5.0       # 5 seconds display window
FADE_DUR = 1.0        # 1 second crossfade

INTRO_IMAGE_NAME = "Sensorium_Interface.jpeg"
OUTRO_IMAGE_NAME = "Cover_v3.jpeg"

CYCLE_IMAGES = [
    "Cover_v3.jpeg",
    "Cover_v4.png",
    "Sensorium_Interface.jpeg",
    "Sensorium_Interface.png"
]

def run_cmd(cmd, desc="Running command"):
    t0 = time.time()
    print(f"[{time.strftime('%X')}] {desc}...", flush=True)
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if res.returncode != 0:
        print(f"\nERROR: {desc} failed with exit code {res.returncode}", flush=True)
        print(res.stdout[-1500:], flush=True)
        sys.exit(1)
    el = time.time() - t0
    print(f"[{time.strftime('%X')}] Finished {desc} in {el:.1f}s", flush=True)
    return res.stdout

def get_duration(filepath):
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        filepath
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return float(res.stdout.strip())

def main():
    print("=" * 70, flush=True)
    print("   YOUTUBE 1080p VIDEO GENERATOR - MP HARMONY AI AGENT FIXES", flush=True)
    print("=" * 70, flush=True)

    if not os.path.exists(VIDEO_FILE):
        print(f"Error: Video file not found: {VIDEO_FILE}", flush=True)
        sys.exit(1)
    if not os.path.exists(AUDIO_FILE):
        print(f"Error: Audio file not found: {AUDIO_FILE}", flush=True)
        sys.exit(1)

    os.makedirs(TEMP_DIR, exist_ok=True)
    scaled_art_dir = os.path.join(TEMP_DIR, "scaled_art")
    segments_dir = os.path.join(TEMP_DIR, "segments")
    os.makedirs(scaled_art_dir, exist_ok=True)
    os.makedirs(segments_dir, exist_ok=True)

    # 1. Pre-render 1080p scaled artwork
    print("\n[Step 1/5] Pre-scaling artwork to 1920x1080 with aspect ratio preserved...", flush=True)
    scaled_images = {}
    all_needed = list(set([INTRO_IMAGE_NAME, OUTRO_IMAGE_NAME] + CYCLE_IMAGES))
    for name in all_needed:
        src_path = os.path.join(SRC_DIR, name)
        base, _ = os.path.splitext(name)
        ext_tag = "_jpg" if name.lower().endswith(".jpeg") or name.lower().endswith(".jpg") else "_png"
        out_name = f"{base}{ext_tag}.png"
        out_path = os.path.join(scaled_art_dir, out_name)
        if not os.path.exists(out_path):
            img = Image.open(src_path).convert("RGB")
            img.thumbnail((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
            canvas = Image.new("RGB", (WIDTH, HEIGHT), (0, 0, 0))
            px = (WIDTH - img.width) // 2
            py = (HEIGHT - img.height) // 2
            canvas.paste(img, (px, py))
            canvas.save(out_path, "PNG")
        scaled_images[name] = out_path
        print(f"  Scaled: {name} -> {out_name}", flush=True)

    # 2. Probe media
    video_dur = get_duration(VIDEO_FILE)
    audio_dur = get_duration(AUDIO_FILE)
    print(f"\nSource Video Duration: {video_dur:.2f}s ({video_dur/60:.2f} mins)", flush=True)
    print(f"Source Audio Duration: {audio_dur:.2f}s ({audio_dur/60:.2f} mins)", flush=True)

    # 3. Plan Segments
    events = []
    curr = INTERVAL_SEC
    while curr + TRANS_DUR < video_dur:
        events.append(curr)
        curr += INTERVAL_SEC

    print(f"\nPlanned {len(events)} artwork transition intervals (every 5 mins).", flush=True)

    concat_list_file = os.path.join(TEMP_DIR, "concat_list.txt")
    concat_entries = []

    # Common encoder arguments
    enc_args = [
        "-c:v", "h264_nvenc",
        "-preset", "p3",
        "-cq", "20",
        "-g", "60",
        "-pix_fmt", "yuv420p"
    ]

    print("\n[Step 2/5] Rendering segments with NVIDIA NVENC...", flush=True)

    # Intro segment: 5 seconds of Sensorium_Interface fading in from black, then 1s dissolving into screencast (total 6s)
    intro_seg = os.path.join(segments_dir, "seg_00_intro.mp4")
    if not os.path.exists(intro_seg):
        cmd = [
            "ffmpeg", "-y",
            "-loop", "1", "-i", scaled_images[INTRO_IMAGE_NAME], "-t", "6",
            "-ss", "0", "-i", VIDEO_FILE, "-t", f"{FADE_DUR:.6f}",
            "-filter_complex",
            f"[0:v]fps={FPS},setsar=1,fade=t=in:st=0:d=5:color=black,format=yuv420p[v0];"
            f"[1:v]fps={FPS},scale=1728:1080,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p[v1];"
            f"[v0][v1]xfade=transition=fade:duration={FADE_DUR}:offset=5.0[vout];"
            f"[vout]format=yuv420p[final]",
            "-map", "[final]",
            "-t", "6",
            *enc_args,
            intro_seg
        ]
        run_cmd(cmd, "Rendering Intro card (5s display with fade-in + 1s crossfade)")
    concat_entries.append(intro_seg)

    # Screencast time covered by Intro's xfade: [0.0 .. 1.0]
    last_sc_time = FADE_DUR

    for idx, ev_time in enumerate(events):
        img_name = CYCLE_IMAGES[idx % len(CYCLE_IMAGES)]
        # Plain screencast segment up to (ev_time - FADE_DUR)
        sc_seg_start = last_sc_time
        sc_seg_end = ev_time - FADE_DUR
        sc_seg_dur = sc_seg_end - sc_seg_start

        seg_file = os.path.join(segments_dir, f"seg_body_{idx:02d}.mp4")
        if sc_seg_dur > 0:
            if not os.path.exists(seg_file):
                cmd = [
                    "ffmpeg", "-y",
                    "-ss", f"{sc_seg_start:.6f}", "-i", VIDEO_FILE, "-t", f"{sc_seg_dur:.6f}",
                    "-vf", f"fps={FPS},scale=1728:1080,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p",
                    *enc_args,
                    seg_file
                ]
                run_cmd(cmd, f"Rendering Screencast Segment {idx+1}/{len(events)+1} ({sc_seg_dur:.1f}s)")
            concat_entries.append(seg_file)

        # Transition segment:
        # Screencast [ev_time - 1.0 .. ev_time] (1.0s)
        # Image (5.0s)
        # Screencast [ev_time .. ev_time + 1.0] (1.0s)
        # xfade 1: offset 0.0, dur 1.0 -> dissolves screencast to image
        # xfade 2: offset 4.0, dur 1.0 -> dissolves image to screencast
        # Output duration = 1 + 5 + 1 - 2 = 5.0 seconds
        tr_file = os.path.join(segments_dir, f"seg_trans_{idx:02d}.mp4")
        if not os.path.exists(tr_file):
            cmd = [
                "ffmpeg", "-y",
                "-ss", f"{sc_seg_end:.6f}", "-i", VIDEO_FILE, "-t", f"{FADE_DUR:.6f}",
                "-loop", "1", "-i", scaled_images[img_name],
                "-ss", f"{ev_time:.6f}", "-i", VIDEO_FILE, "-t", f"{FADE_DUR:.6f}",
                "-filter_complex",
                f"[0:v]fps={FPS},scale=1728:1080,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p[v0];"
                f"[1:v]fps={FPS},setsar=1,format=yuv420p[v1];"
                f"[2:v]fps={FPS},scale=1728:1080,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p[v2];"
                f"[v0][v1]xfade=transition=fade:duration={FADE_DUR}:offset=0.0[vx1];"
                f"[vx1][v2]xfade=transition=fade:duration={FADE_DUR}:offset={TRANS_DUR-FADE_DUR:.1f}[vx2];"
                f"[vx2]format=yuv420p[final]",
                "-map", "[final]",
                "-t", f"{TRANS_DUR:.6f}",
                *enc_args,
                tr_file
            ]
            run_cmd(cmd, f"Rendering Art Transition {idx+1}/{len(events)} ({img_name})")
        concat_entries.append(tr_file)

        last_sc_time = ev_time + FADE_DUR

    # Final screencast segment to end of video
    rem_sc_dur = video_dur - FADE_DUR - last_sc_time
    final_body_file = os.path.join(segments_dir, "seg_body_final.mp4")
    if rem_sc_dur > 0:
        if not os.path.exists(final_body_file):
            cmd = [
                "ffmpeg", "-y",
                "-ss", f"{last_sc_time:.6f}", "-i", VIDEO_FILE, "-t", f"{rem_sc_dur:.6f}",
                "-vf", f"fps={FPS},scale=1728:1080,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p",
                *enc_args,
                final_body_file
            ]
            run_cmd(cmd, f"Rendering Final Screencast Segment ({rem_sc_dur:.1f}s)")
        concat_entries.append(final_body_file)

    # Outro segment: Screencast final second dissolving into Cover_v3.jpeg (6s total: 1s crossfade + 5s fade out to black)
    outro_seg = os.path.join(segments_dir, "seg_outro.mp4")
    if not os.path.exists(outro_seg):
        cmd = [
            "ffmpeg", "-y",
            "-ss", f"{video_dur - FADE_DUR:.6f}", "-i", VIDEO_FILE, "-t", f"{FADE_DUR:.6f}",
            "-loop", "1", "-i", scaled_images[OUTRO_IMAGE_NAME], "-t", "6",
            "-filter_complex",
            f"[0:v]fps={FPS},scale=1728:1080,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,setsar=1,format=yuv420p[v0];"
            f"[1:v]fps={FPS},setsar=1,fade=t=out:st=1:d=5:color=black,format=yuv420p[v1];"
            f"[v0][v1]xfade=transition=fade:duration={FADE_DUR}:offset=0.0[vout];"
            f"[vout]format=yuv420p[final]",
            "-map", "[final]",
            "-t", "6",
            *enc_args,
            outro_seg
        ]
        run_cmd(cmd, "Rendering Outro card (1s crossfade + 5s fade-out to black)")
    concat_entries.append(outro_seg)

    # Write concat list
    with open(concat_list_file, "w") as f:
        for seg in concat_entries:
            f.write(f"file '{seg}'\n")

    # 4. Concatenate Video Segments
    print("\n[Step 3/5] Concatenating video segments with stream copy...", flush=True)
    concat_video_file = os.path.join(TEMP_DIR, "video_stitched.mp4")
    cmd = [
        "ffmpeg", "-y",
        "-f", "concat", "-safe", "0", "-i", concat_list_file,
        "-c", "copy",
        concat_video_file
    ]
    run_cmd(cmd, "Stitching video segments")

    total_video_dur = get_duration(concat_video_file)
    print(f"Stitched Video Duration: {total_video_dur:.2f}s ({total_video_dur/60:.2f} mins)", flush=True)

    # 5. Mux with Audio Loop & Audio Fades
    print("\n[Step 4/5] Muxing looped WAV audio (320kbps AAC) with 5s fades at start & end...", flush=True)
    audio_fade_out_start = max(0.0, total_video_dur - 5.0)

    cmd = [
        "ffmpeg", "-y",
        "-i", concat_video_file,
        "-stream_loop", "-1", "-i", AUDIO_FILE,
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-c:v", "copy",
        "-af", f"afade=t=in:st=0:d=5,afade=t=out:st={audio_fade_out_start:.6f}:d=5",
        "-c:a", "aac",
        "-b:a", "320k",
        "-t", f"{total_video_dur:.6f}",
        "-movflags", "+faststart",
        OUTPUT_FILE
    ]
    run_cmd(cmd, "Muxing final video with audio")

    # 6. Verify Final File
    print("\n[Step 5/5] Verifying final generated YouTube video...", flush=True)
    final_dur = get_duration(OUTPUT_FILE)
    size_bytes = os.path.getsize(OUTPUT_FILE)
    size_mb = size_bytes / (1024 * 1024)

    print("\n" + "=" * 70, flush=True)
    print("SUCCESS: Final YouTube Video Created Successfully!", flush=True)
    print(f"File Path: {OUTPUT_FILE}", flush=True)
    print(f"Total Duration: {final_dur:.2f}s ({final_dur/60:.2f} mins)", flush=True)
    print(f"File Size: {size_mb:.2f} MB ({size_mb/1024:.2f} GB)", flush=True)
    print("=" * 70, flush=True)

    # Clean up temporary work dir
    print("\nCleaning up temporary files...", flush=True)
    shutil.rmtree(TEMP_DIR, ignore_errors=True)
    print("Cleanup complete.", flush=True)

if __name__ == "__main__":
    main()
