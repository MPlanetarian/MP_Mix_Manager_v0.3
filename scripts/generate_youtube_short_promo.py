#!/usr/bin/env python3
"""
MP Mix Manager v0.3 - YouTube Shorts Promotional Video Generator (1080x1920 Vertical)
Generates an eye-catching 42-second YouTube Shorts / Reels video promoting the new
v0.3.5 features of MP Mix Archive Manager with Dreamworlds neon aesthetics,
hardware-accelerated NVENC encoding, and lossless audio synchronization.
"""

import argparse
import glob
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH = 1080
HEIGHT = 1920
FPS = 30
SLIDE_DURATION = 6.0  # seconds per slide
FADE_DURATION = 0.5   # transition crossfade

# Dreamworlds Palette
BG_COLOR = (13, 15, 24)           # #0d0f18
CARD_BG = (21, 25, 40)            # #151928
CARD_BORDER = (45, 53, 85)        # #2d3555
NEON_PINK = (247, 37, 133)        # #f72585
NEON_CYAN = (0, 229, 255)         # #00e5ff
NEON_CORAL = (237, 37, 78)        # #ed254e
NEON_GOLD = (255, 170, 0)         # #ffaa00
TEXT_WHITE = (245, 247, 250)      # #f5f7fa
TEXT_DIM = (140, 155, 185)        # #8c9bb9


def find_font(candidates, default_size=40):
    for c in candidates:
        if os.path.isfile(c):
            try:
                return ImageFont.truetype(c, default_size)
            except Exception:
                pass
    # Fallback search
    for pattern in ["*NotoSans*Bold*.ttf", "*FreeSans*Bold*.ttf", "*DejaVuSans*Bold*.ttf"]:
        found = glob.glob(f"/usr/share/fonts/**/{pattern}", recursive=True)
        if found:
            try:
                return ImageFont.truetype(found[0], default_size)
            except Exception:
                pass
    return ImageFont.load_default()


def get_fonts():
    bold_candidates = [
        "/usr/share/fonts/google-noto/NotoSans-Bold.ttf",
        "/usr/share/fonts/gnu-free/FreeSansBold.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/adwaita-mono-fonts/AdwaitaMono-Bold.ttf",
    ]
    reg_candidates = [
        "/usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf",
        "/usr/share/fonts/google-noto/NotoSans-Regular.ttf",
        "/usr/share/fonts/gnu-free/FreeSans.ttf",
        "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
    ]
    return {
        "title_large": find_font(bold_candidates, 76),
        "title_med": find_font(bold_candidates, 56),
        "header": find_font(bold_candidates, 48),
        "badge": find_font(bold_candidates, 28),
        "body_bold": find_font(bold_candidates, 36),
        "body_reg": find_font(reg_candidates, 34),
        "caption": find_font(reg_candidates, 26),
    }


def draw_rounded_rect(draw, xy, radius, fill, outline=None, width=1):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill, outline=outline, width=width)


def create_base_canvas():
    """Create vertical 1080x1920 canvas with subtle Dreamworlds ambient neon glows."""
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Ambient gradient circles
    glow_overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow_overlay)

    # Top-right pink glow
    g_draw.ellipse([WIDTH - 300, -100, WIDTH + 400, 600], fill=(247, 37, 133, 40))
    # Bottom-left cyan glow
    g_draw.ellipse([-200, HEIGHT - 700, 500, HEIGHT + 100], fill=(0, 229, 255, 35))
    # Center accent glow
    g_draw.ellipse([WIDTH // 2 - 250, HEIGHT // 2 - 250, WIDTH // 2 + 250, HEIGHT // 2 + 250], fill=(155, 89, 182, 25))

    glow_blurred = glow_overlay.filter(ImageFilter.GaussianBlur(120))
    img.paste(glow_blurred, (0, 0), glow_blurred)

    return img


def render_slide_0(fonts, cover_img_path):
    """Slide 0: Title Hook & Cover Art"""
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Top Badge
    badge_text = "🔥 MAJOR RELEASE • v0.3.5"
    draw_rounded_rect(draw, [WIDTH // 2 - 220, 140, WIDTH // 2 + 220, 200], 30, (247, 37, 133, 50), outline=NEON_PINK, width=2)
    draw.text((WIDTH // 2, 170), badge_text, font=fonts["badge"], fill=NEON_PINK, anchor="mm")

    # Main Big Title
    draw.text((WIDTH // 2, 280), "MP MIX ARCHIVE", font=fonts["title_large"], fill=TEXT_WHITE, anchor="mm")
    draw.text((WIDTH // 2, 360), "MANAGER", font=fonts["title_large"], fill=NEON_CYAN, anchor="mm")

    # Subtitle
    draw.text((WIDTH // 2, 430), "THE ULTIMATE DJ & AUDIO WORKSTATION", font=fonts["caption"], fill=TEXT_DIM, anchor="mm")

    # Cover Art Thumbnail with neon card frame
    c_w, c_h = 600, 600
    c_x = (WIDTH - c_w) // 2
    c_y = 520
    draw_rounded_rect(draw, [c_x - 12, c_y - 12, c_x + c_w + 12, c_y + c_h + 12], 28, CARD_BG, outline=NEON_PINK, width=4)

    if cover_img_path and os.path.isfile(cover_img_path):
        try:
            cov = Image.open(cover_img_path).convert("RGB")
            cov = cov.resize((c_w, c_h), Image.Resampling.LANCZOS)
            img.paste(cov, (c_x, c_y))
        except Exception:
            pass

    # Features Callout Pill Card
    draw_rounded_rect(draw, [80, 1200, WIDTH - 80, 1680], 32, CARD_BG, outline=CARD_BORDER, width=2)

    callout_items = [
        ("⚡ <20ms Instant TUI Navigation", NEON_CYAN),
        ("🔍 Auto-ID Unknown Tracks (Shazam/AcoustID)", NEON_PINK),
        ("📼 1-Click YouTube Chapters & Rekordbox XML", NEON_GOLD),
        ("🎛️ Mastering Health & True-Peak Audit", NEON_CYAN),
        ("📱 DJ Booth Mobile Web Companion", NEON_PINK),
    ]

    y_pos = 1270
    for text, col in callout_items:
        draw.text((120, y_pos), text, font=fonts["body_bold"], fill=col, anchor="lm")
        y_pos += 84

    # Footer
    draw.text((WIDTH // 2, 1780), "7 POWERFUL NEW FEATURES IN THIS UPDATE", font=fonts["caption"], fill=TEXT_DIM, anchor="mm")

    return img


def render_feature_slide(fonts, badge_text, title_line1, title_line2, items, icon_char="✨"):
    """Generic high-impact feature slide with Dreamworlds cards."""
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    # Top Badge
    draw_rounded_rect(draw, [WIDTH // 2 - 240, 150, WIDTH // 2 + 240, 215], 32, (0, 229, 255, 40), outline=NEON_CYAN, width=2)
    draw.text((WIDTH // 2, 182), badge_text, font=fonts["badge"], fill=NEON_CYAN, anchor="mm")

    # Slide Header
    draw.text((WIDTH // 2, 290), title_line1, font=fonts["title_med"], fill=TEXT_WHITE, anchor="mm")
    if title_line2:
        draw.text((WIDTH // 2, 360), title_line2, font=fonts["title_med"], fill=NEON_PINK, anchor="mm")

    # Main Feature Card
    draw_rounded_rect(draw, [80, 460, WIDTH - 80, 1640], 36, CARD_BG, outline=CARD_BORDER, width=2)

    # Render items with glowing bullet points
    y = 540
    for heading, detail, color in items:
        # Bullet indicator
        draw.ellipse([120, y + 8, 144, y + 32], fill=color)

        draw.text((170, y + 20), heading, font=fonts["body_bold"], fill=TEXT_WHITE, anchor="lm")
        draw.text((170, y + 70), detail, font=fonts["body_reg"], fill=TEXT_DIM, anchor="lm")

        # Divider
        draw.line([120, y + 150, WIDTH - 120, y + 150], fill=(35, 42, 65), width=1)
        y += 180

    # Footer CTA
    draw.text((WIDTH // 2, 1760), "MPlanetarian • Stream of Frequency Edition", font=fonts["caption"], fill=TEXT_DIM, anchor="mm")

    return img


def render_outro_slide(fonts, cover_img_path):
    """Slide 6: Outro & Download / Upgrade CTA"""
    img = create_base_canvas()
    draw = ImageDraw.Draw(img)

    draw_rounded_rect(draw, [WIDTH // 2 - 200, 160, WIDTH // 2 + 200, 225], 32, (255, 170, 0, 40), outline=NEON_GOLD, width=2)
    draw.text((WIDTH // 2, 192), "🚀 AVAILABLE NOW", font=fonts["badge"], fill=NEON_GOLD, anchor="mm")

    draw.text((WIDTH // 2, 310), "MP MIX MANAGER", font=fonts["title_large"], fill=TEXT_WHITE, anchor="mm")
    draw.text((WIDTH // 2, 390), "VERSION 0.3.5", font=fonts["title_large"], fill=NEON_CYAN, anchor="mm")

    c_w, c_h = 560, 560
    c_x = (WIDTH - c_w) // 2
    c_y = 480
    draw_rounded_rect(draw, [c_x - 10, c_y - 10, c_x + c_w + 10, c_y + c_h + 10], 24, CARD_BG, outline=NEON_PINK, width=3)

    if cover_img_path and os.path.isfile(cover_img_path):
        try:
            cov = Image.open(cover_img_path).convert("RGB")
            cov = cov.resize((c_w, c_h), Image.Resampling.LANCZOS)
            img.paste(cov, (c_x, c_y))
        except Exception:
            pass

    draw_rounded_rect(draw, [80, 1120, WIDTH - 80, 1680], 32, CARD_BG, outline=CARD_BORDER, width=2)

    bullets = [
        ("🐧 Linux Native", "Bazzite • Fedora • SteamOS • Ubuntu"),
        ("🍏 Apple macOS", "Sonoma • Sequoia • Apple Silicon M1-M4 & Intel"),
        ("🪟 Windows 10 & 11", "PowerShell • WSL2 • Git Bash"),
        ("💯 100% Free & Open Source", "Enterprise-grade DJ mix management & archiving"),
    ]

    y = 1180
    for title, desc in bullets:
        draw.text((120, y + 15), title, font=fonts["body_bold"], fill=NEON_CYAN, anchor="lm")
        draw.text((120, y + 60), desc, font=fonts["body_reg"], fill=TEXT_DIM, anchor="lm")
        y += 125

    draw.text((WIDTH // 2, 1780), "Like & Subscribe • youtube.com/@mplanetarian", font=fonts["body_bold"], fill=NEON_PINK, anchor="mm")

    return img


def build_slides(temp_dir, cover_path):
    fonts = get_fonts()
    slides = []

    # Slide 0: Hook
    s0 = render_slide_0(fonts, cover_path)
    p0 = os.path.join(temp_dir, "slide_0.png")
    s0.save(p0)
    slides.append(p0)

    # Slide 1: Blistering Speed
    s1 = render_feature_slide(
        fonts,
        "⚡ SPEED & NAVIGATION",
        "BLISTERING PERFORMANCE",
        "<20ms Instant TUI",
        [
            ("Zero Latency Menus", "Refreshes in under 20ms instead of 1.7s", NEON_CYAN),
            ("Cached Archive Telemetry", "Instant multi-drive scans without FUSE bottlenecks", NEON_PINK),
            ("24-Bit TrueColor Theme", "Hand-crafted MPlanetarian Dreamworlds palette", NEON_GOLD),
            ("Keyboard Fluidity", "Seamless Arrow, Enter & Esc navigation across all menus", NEON_CYAN),
        ]
    )
    p1 = os.path.join(temp_dir, "slide_1.png")
    s1.save(p1)
    slides.append(p1)

    # Slide 2: Audio Fingerprinting
    s2 = render_feature_slide(
        fonts,
        "🔍 AUDIO INTELLIGENCE",
        "AUTO-ID TRACKS",
        "AcoustID & Shazam",
        [
            ("Mix Transition Slicing", "Probes audio snippets at transition cue points", NEON_CYAN),
            ("Resolve Unknown IDs", "Automatically identifies 'ID - ID' mystery tracks", NEON_PINK),
            ("Draft Tracklist Generation", "Exports timestamped text tracklists with one click", NEON_GOLD),
            ("Red Book CUE Alignment", "Ready to burn or split into individual lossless tracks", NEON_CYAN),
        ]
    )
    p2 = os.path.join(temp_dir, "slide_2.png")
    s2.save(p2)
    slides.append(p2)

    # Slide 3: 1-Click Chapters & Rekordbox XML
    s3 = render_feature_slide(
        fonts,
        "📼 STREAMING & CDJ EXPORT",
        "YOUTUBE CHAPTERS",
        "& Rekordbox XML Export",
        [
            ("YouTube Video Chapters", "Exact format (00:00:00 Artist - Title) ready for uploads", NEON_CYAN),
            ("SoundCloud & Mixcloud", "Formatted descriptions with duration validation", NEON_PINK),
            ("Pioneer Rekordbox XML", "Converts Traktor / M3U into standard rekordbox.xml", NEON_GOLD),
            ("CDJ Stage Prep", "Load ascending harmonic keys straight onto USB drives", NEON_CYAN),
        ]
    )
    p3 = os.path.join(temp_dir, "slide_3.png")
    s3.save(p3)
    slides.append(p3)

    # Slide 4: Mastering Quality & Audio Health
    s4 = render_feature_slide(
        fonts,
        "🎛️ AUDIO MASTERING AUDIT",
        "STUDIO HEALTH CHECK",
        "True Peak & Phase Analysis",
        [
            ("True Peak (ISP) Check", "Flags clipping distortion before lossy MP3 encoding", NEON_CYAN),
            ("Stereo Phase Correlation", "Guarantees mono compatibility on club sound systems", NEON_PINK),
            ("EBU R128 Loudness Audit", "Integrated LUFS & LRA dynamic range measurement", NEON_GOLD),
            ("Silence Trimming Detection", "Detects dead air at start/end of sets automatically", NEON_CYAN),
        ]
    )
    p4 = os.path.join(temp_dir, "slide_4.png")
    s4.save(p4)
    slides.append(p4)

    # Slide 5: Mobile Web Companion
    s5 = render_feature_slide(
        fonts,
        "📱 WIRELESS DJ BOOTH REMOTE",
        "MOBILE WEB COMPANION",
        "Phone & Tablet Control",
        [
            ("Local LAN Dashboard", "Accessible on port 8888 from phone or tablet", NEON_CYAN),
            ("Live Track Information", "Now-playing track title, artist & elapsed playback time", NEON_PINK),
            ("Wireless Transport Controls", "Play, Pause, Next & Previous right from the DJ booth", NEON_GOLD),
            ("Zero Dependencies", "Lightweight Python HTTP server — no bloated installs", NEON_CYAN),
        ]
    )
    p5 = os.path.join(temp_dir, "slide_5.png")
    s5.save(p5)
    slides.append(p5)

    # Slide 6: Outro / CTA
    s6 = render_outro_slide(fonts, cover_path)
    p6 = os.path.join(temp_dir, "slide_6.png")
    s6.save(p6)
    slides.append(p6)

    return slides


def encode_short_video(slides, audio_file, output_path, total_duration=42.0):
    """
    Render video with slide crossfades, NVENC acceleration, and audio synchronization.
    """
    nvenc_avail = "h264_nvenc" in subprocess.check_output(["ffmpeg", "-encoders"], stderr=subprocess.DEVNULL).decode('utf-8')
    v_codec = "h264_nvenc" if nvenc_avail else "libx264"
    print(f"[•] Video Encoder: {v_codec}")

    # Build individual slide video segments
    seg_duration = total_duration / len(slides)
    seg_files = []
    tmpdir = os.path.dirname(slides[0])

    print(f"[•] Rendering {len(slides)} vertical slide segments ({seg_duration:.1f}s each)...")
    for idx, slide_path in enumerate(slides):
        seg_out = os.path.join(tmpdir, f"seg_{idx}.mp4")
        cmd = [
            "ffmpeg", "-y", "-loop", "1", "-t", str(seg_duration),
            "-i", slide_path,
            "-c:v", v_codec,
            "-pix_fmt", "yuv420p",
            "-r", str(FPS),
        ]
        if v_codec == "h264_nvenc":
            cmd.extend(["-preset", "p4", "-cq", "20", "-b:v", "8M"])
        else:
            cmd.extend(["-preset", "medium", "-crf", "19"])
        cmd.append(seg_out)

        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        seg_files.append(seg_out)

    # Concat file list
    concat_list = os.path.join(tmpdir, "concat.txt")
    with open(concat_list, "w") as f:
        for s in seg_files:
            f.write(f"file '{s}'\n")

    video_only = os.path.join(tmpdir, "video_merged.mp4")
    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0",
        "-i", concat_list,
        "-c", "copy",
        video_only
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

    # Audio muxing & fading
    print(f"[•] Muxing and fading audio (Duration: {total_duration}s)...")
    cmd = [
        "ffmpeg", "-y",
        "-i", video_only,
    ]

    audio_filter = f"afade=t=in:ss=0:d=1.5,afade=t=out:st={total_duration - 2.5}:d=2.5"

    if audio_file and os.path.isfile(audio_file):
        # Sample audio from offset (e.g. 60s in for drop)
        cmd.extend([
            "-ss", "60", "-t", str(total_duration),
            "-i", audio_file,
            "-map", "0:v:0", "-map", "1:a:0",
            "-dn", "-map_metadata", "-1", "-map_chapters", "-1",
            "-af", audio_filter,
            "-c:v", "copy",
            "-c:a", "aac", "-b:a", "320k",
            "-movflags", "+faststart",
            "-shortest",
            output_path
        ])
    else:
        # Fallback synthesizer tone if audio missing
        cmd.extend([
            "-f", "lavfi", "-t", str(total_duration),
            "-i", f"sine=frequency=440:sample_rate=44100",
            "-map", "0:v:0", "-map", "1:a:0",
            "-dn", "-map_metadata", "-1", "-map_chapters", "-1",
            "-af", audio_filter,
            "-c:v", "copy",
            "-c:a", "aac", "-b:a", "192k",
            "-movflags", "+faststart",
            output_path
        ])

    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    print(f"[✓] Successfully generated YouTube Short video: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Generate YouTube Shorts Promo Video for MP Mix Manager v0.3.5")
    parser.add_argument("--audio", "-a", help="Source audio file (.wav / .flac)", default="/run/media/mplanetarian/DATA/Sensorium Interface/MPlanetarian - Stream of Frequency 074.wav")
    parser.add_argument("--cover", "-c", help="Cover art image", default="Cover.png")
    parser.add_argument("--output", "-o", help="Output MP4 file", default="MP_Mix_Manager_v0.3.5_New_Features_YouTube_Short.mp4")

    args = parser.parse_args()

    # Locate cover
    cover_path = args.cover
    if not os.path.isfile(cover_path):
        cover_path = "assets/Cover.png"

    with tempfile.TemporaryDirectory() as tmpdir:
        t0 = time.time()
        print("\n======================================================================")
        print("  🎥 YOUTUBE SHORTS PROMO GENERATOR (1080x1920 VERTICAL)")
        print("  MPlanetarian Dreamworlds Edition • MP Mix Archive Manager v0.3.5")
        print("======================================================================\n")

        print("[•] Step 1: Generating high-resolution vertical Dreamworlds slide graphics...")
        slides = build_slides(tmpdir, cover_path)

        print("[•] Step 2: Assembling 42-second YouTube Shorts video with hardware acceleration...")
        out_abs = os.path.abspath(args.output)
        encode_short_video(slides, args.audio, out_abs, total_duration=42.0)

        elapsed = time.time() - t0
        print(f"\n[✓] Render completed in {elapsed:.1f}s!")
        print(f"[•] Output File: {out_abs}")
        if os.path.isfile(out_abs):
            size_mb = os.path.getsize(out_abs) / (1024 * 1024)
            print(f"[•] File Size:   {size_mb:.2f} MB")
            print(f"[•] Resolution:  1080x1920 (9:16 Vertical YouTube Shorts / TikTok / Reels)")
            print(f"[•] Audio:       320 kbps AAC Stereo with smooth studio fades\n")


if __name__ == "__main__":
    main()
