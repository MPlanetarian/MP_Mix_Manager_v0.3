#!/usr/bin/env python3
"""
==============================================================================
wan2gp_tts_batch.py - WAN2GP Text-to-Speech (TTS) Batch Converter & Audio Player
==============================================================================
Converts text (.txt) files to uncompressed .wav speech audio files with full support
for British (English) and international female and male voices.

Workflows:
  - Input directory: /run/media/mplanetarian/GAMES1/DATA_DRIVE_MOVED/WAN2GP_TTSBATCH/
  - Outputs saved first to the same directory as .wav
  - After conversion, both the .wav and matching .txt are moved to TTS_CONVERTED/
    named with date and unique ID (e.g. YYYY-MM-DD_ID001_<filename>.[wav|txt])
  - Interactive playback menu to listen to converted speech files
  - Supports both Neural voices (Edge-TTS) and High-Speed Offline (eSpeak-NG)
==============================================================================
"""

import os
import sys
import re
import json
import time
import wave
import shutil
import datetime
import argparse
import subprocess
from pathlib import Path
from typing import List, Dict, Optional, Tuple

# Terminal color styling
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
CYAN = "\033[0;36m"
RED = "\033[0;31m"
BOLD = "\033[1m"
MAGENTA = "\033[1;35m"
BLUE = "\033[1;34m"
DIM = "\033[2m"
RESET = "\033[0m"

# Default directories
PRIMARY_DATA_DIR = Path("/run/media/mplanetarian/GAMES1/DATA_DRIVE_MOVED")
FALLBACK_DATA_DIR = Path("/run/media/mplanetarian/DATA")
BASE_DATA_DIR = PRIMARY_DATA_DIR if PRIMARY_DATA_DIR.exists() else FALLBACK_DATA_DIR

DEFAULT_TTS_DIR = Path(os.environ.get("WAN2GP_TTSBATCH_DIR", BASE_DATA_DIR / "WAN2GP_TTSBATCH"))
CONFIG_FILE = Path.home() / ".config" / "wan2gp_tts_config.json"

# Voice catalog
VOICES: List[Dict[str, str]] = [
    # British (English) Voices
    {
        "id": "en-GB-SoniaNeural",
        "name": "Sonia",
        "gender": "Female",
        "accent": "British (English)",
        "engine": "edge",
        "desc": "Natural, clear, warm British English (Neural)"
    },
    {
        "id": "en-GB-LibbyNeural",
        "name": "Libby",
        "gender": "Female",
        "accent": "British (English)",
        "engine": "edge",
        "desc": "Friendly, positive, polite British English (Neural)"
    },
    {
        "id": "en-GB-MaisieNeural",
        "name": "Maisie",
        "gender": "Female",
        "accent": "British (English)",
        "engine": "edge",
        "desc": "Cheerful, lively, conversational British English (Neural)"
    },
    {
        "id": "en-GB-RyanNeural",
        "name": "Ryan",
        "gender": "Male",
        "accent": "British (English)",
        "engine": "edge",
        "desc": "Professional, natural, articulate British English (Neural)"
    },
    {
        "id": "en-GB-ThomasNeural",
        "name": "Thomas",
        "gender": "Male",
        "accent": "British (English)",
        "engine": "edge",
        "desc": "Authoritative, calm, deep British English (Neural)"
    },
    {
        "id": "espeak:en-gb+f3",
        "name": "Emily (eSpeak)",
        "gender": "Female",
        "accent": "British (English)",
        "engine": "espeak",
        "desc": "Instant offline British female voice (High-Speed)"
    },
    {
        "id": "espeak:en-gb",
        "name": "George (eSpeak)",
        "gender": "Male",
        "accent": "British (English)",
        "engine": "espeak",
        "desc": "Instant offline British male voice (High-Speed)"
    },
    {
        "id": "espeak:en-gb-x-rp",
        "name": "Oliver RP (eSpeak)",
        "gender": "Male",
        "accent": "British (Received Pronunciation)",
        "engine": "espeak",
        "desc": "Received Pronunciation British male voice (Offline)"
    },
    # American (English) Voices
    {
        "id": "en-US-JennyNeural",
        "name": "Jenny",
        "gender": "Female",
        "accent": "American (US)",
        "engine": "edge",
        "desc": "Clear, professional, versatile US English (Neural)"
    },
    {
        "id": "en-US-AriaNeural",
        "name": "Aria",
        "gender": "Female",
        "accent": "American (US)",
        "engine": "edge",
        "desc": "Confident, expressive, broadcast quality (Neural)"
    },
    {
        "id": "en-US-AvaNeural",
        "name": "Ava",
        "gender": "Female",
        "accent": "American (US)",
        "engine": "edge",
        "desc": "Pleasant, caring, conversational (Neural)"
    },
    {
        "id": "en-US-GuyNeural",
        "name": "Guy",
        "gender": "Male",
        "accent": "American (US)",
        "engine": "edge",
        "desc": "Warm, casual, conversational US English (Neural)"
    },
    {
        "id": "en-US-ChristopherNeural",
        "name": "Christopher",
        "gender": "Male",
        "accent": "American (US)",
        "engine": "edge",
        "desc": "Reliable, authoritative, documentary narration (Neural)"
    },
    {
        "id": "en-US-AndrewNeural",
        "name": "Andrew",
        "gender": "Male",
        "accent": "American (US)",
        "engine": "edge",
        "desc": "Warm, confident, natural (Neural)"
    },
    {
        "id": "espeak:en-us+f3",
        "name": "Sarah (eSpeak)",
        "gender": "Female",
        "accent": "American (US)",
        "engine": "espeak",
        "desc": "Instant offline US female voice (High-Speed)"
    },
    {
        "id": "espeak:en-us",
        "name": "Michael (eSpeak)",
        "gender": "Male",
        "accent": "American (US)",
        "engine": "espeak",
        "desc": "Instant offline US male voice (High-Speed)"
    },
    # Other Accents
    {
        "id": "en-AU-NatashaNeural",
        "name": "Natasha",
        "gender": "Female",
        "accent": "Australian (en-AU)",
        "engine": "edge",
        "desc": "Friendly Australian female voice (Neural)"
    },
    {
        "id": "en-AU-WilliamNeural",
        "name": "William",
        "gender": "Male",
        "accent": "Australian (en-AU)",
        "engine": "edge",
        "desc": "Warm Australian male voice (Neural)"
    },
    {
        "id": "en-IE-OrlaNeural",
        "name": "Orla",
        "gender": "Female",
        "accent": "Irish (en-IE)",
        "engine": "edge",
        "desc": "Melodic Irish female voice (Neural)"
    },
    {
        "id": "en-IE-ColmNeural",
        "name": "Colm",
        "gender": "Male",
        "accent": "Irish (en-IE)",
        "engine": "edge",
        "desc": "Natural Irish male voice (Neural)"
    }
]

DEFAULT_VOICE_ID = "en-GB-SoniaNeural"


def load_config() -> Dict[str, str]:
    """Load persistent user configuration."""
    cfg = {
        "voice_id": DEFAULT_VOICE_ID,
        "speed_rate": "+0%",
        "tts_dir": str(DEFAULT_TTS_DIR),
        "engine": "auto"
    }
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                saved = json.load(f)
                if isinstance(saved, dict):
                    cfg.update(saved)
        except Exception:
            pass
    return cfg


def save_config(cfg: Dict[str, str]) -> None:
    """Save user configuration to disk."""
    try:
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception:
        pass

def pause_if_tty(prompt: str = "\nPress [Enter] to continue...") -> None:
    """Prompt user to press Enter only if connected to an interactive terminal."""
    if sys.stdin.isatty():
        try:
            input(f"{DIM}{prompt}{RESET}")
        except (EOFError, KeyboardInterrupt):
            pass


def get_voice_info(voice_id: str) -> Dict[str, str]:
    """Retrieve voice info dictionary by ID."""
    for v in VOICES:
        if v["id"].lower() == voice_id.lower():
            return v
    # Fallback default
    return VOICES[0]


def sanitize_text_for_speech(raw_text: str) -> str:
    """
    Cleans raw text (such as terminal logs) so that it sounds natural when spoken,
    stripping ANSI escape sequences, excessive punctuation, and box art.
    """
    # 1. Strip ANSI escape codes
    text = re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", " ", raw_text)
    # 2. Strip XML/HTML tags
    text = re.sub(r"<[^>]+>", " ", text)
    # 3. Remove block art, decorative box drawing, and repetitive symbols
    text = re.sub(r"[─═━│┃┄┅┌┐└┘├┤┬┴┼▄▀█▓▒░●○•◆◇▶▼▲◀★☆]+", " ", text)
    # 4. Collapse repeated dashes, underscores, dots, and equals
    text = re.sub(r"[-_=~*]{3,}", " ", text)
    # 5. Remove non-printable control characters (except newlines/tabs)
    text = "".join(c for c in text if c.isprintable() or c in "\n\t")
    # 6. Normalize multiple empty lines and excessive spaces
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n\s*\n\s*\n+", "\n\n", text)
    return text.strip()


def get_audio_duration_seconds(path: Path) -> float:
    """Calculate the duration of a .wav file in seconds using standard library wave."""
    try:
        with wave.open(str(path), "rb") as w:
            frames = w.getnframes()
            rate = w.getframerate()
            if rate > 0:
                return frames / float(rate)
    except Exception:
        # Fallback to ffprobe if wave cannot read header
        try:
            cmd = [
                "ffprobe", "-v", "error", "-show_entries",
                "format=duration", "-of", "default=noprint_wrappers=1:nokey=1",
                str(path)
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return float(res.stdout.strip())
        except Exception:
            pass
    return 0.0


def format_duration(seconds: float) -> str:
    """Format seconds into HH:MM:SS or MM:SS string."""
    m, s = divmod(int(seconds), 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


def format_size(bytes_num: int) -> str:
    """Format bytes into human-readable size."""
    for unit in ["B", "KB", "MB", "GB"]:
        if bytes_num < 1024.0:
            return f"{bytes_num:.1f} {unit}"
        bytes_num /= 1024.0
    return f"{bytes_num:.1f} TB"


def get_next_id(converted_dir: Path, date_str: str) -> str:
    """
    Finds the next sequential ID (e.g. ID001, ID002) for the given date
    or across existing converted files in converted_dir.
    """
    max_id = 0
    if converted_dir.exists():
        pattern = re.compile(rf"{date_str}_ID(\d{{3,}})")
        for item in converted_dir.iterdir():
            match = pattern.search(item.name)
            if match:
                try:
                    num = int(match.group(1))
                    if num > max_id:
                        max_id = num
                except ValueError:
                    pass
        # Also check without date prefix for general ID sequence
        pattern_general = re.compile(r"ID(\d{3,})")
        for item in converted_dir.iterdir():
            match = pattern_general.search(item.name)
            if match:
                try:
                    num = int(match.group(1))
                    if num > max_id:
                        max_id = num
                except ValueError:
                    pass
    next_num = max_id + 1
    return f"ID{next_num:03d}"


def synthesize_speech_espeak(text: str, voice_code: str, output_wav: Path, speed_wpm: int = 130) -> bool:
    """Synthesize speech using local eSpeak-NG engine at normal conversational speed."""
    clean_voice = voice_code.replace("espeak:", "")
    temp_txt = output_wav.with_suffix(".tmp.txt")
    try:
        temp_txt.write_text(text, encoding="utf-8")
        cmd = [
            "espeak-ng",
            "-v", clean_voice,
            "-s", str(speed_wpm),
            "-p", "50",
            "-f", str(temp_txt),
            "-w", str(output_wav)
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0 and output_wav.exists() and output_wav.stat().st_size > 44:
            return True
        else:
            print(f"{RED}[-] eSpeak-NG failed: {res.stderr.strip()}{RESET}")
            return False
    except Exception as e:
        print(f"{RED}[-] Error during eSpeak-NG synthesis: {e}{RESET}")
        return False
    finally:
        if temp_txt.exists():
            temp_txt.unlink()


def split_text_into_chunks(text: str, max_chars: int = 4000) -> List[str]:
    """Split long text into coherent paragraphs/chunks for stable Edge-TTS processing."""
    paragraphs = text.split("\n\n")
    chunks = []
    current_chunk = []
    current_len = 0

    for p in paragraphs:
        p_clean = p.strip()
        if not p_clean:
            continue
        if current_len + len(p_clean) > max_chars and current_chunk:
            chunks.append("\n\n".join(current_chunk))
            current_chunk = [p_clean]
            current_len = len(p_clean)
        else:
            current_chunk.append(p_clean)
            current_len += len(p_clean) + 2

    if current_chunk:
        chunks.append("\n\n".join(current_chunk))
    return chunks if chunks else [text]


def concatenate_wav_files(wav_paths: List[Path], final_wav: Path) -> bool:
    """Concatenate multiple PCM WAV files into a single WAV file."""
    if not wav_paths:
        return False
    if len(wav_paths) == 1:
        shutil.copy2(wav_paths[0], final_wav)
        return True

    try:
        with wave.open(str(wav_paths[0]), "rb") as first:
            params = first.getparams()
            frames = [first.readframes(first.getnframes())]

        for p in wav_paths[1:]:
            with wave.open(str(p), "rb") as w:
                frames.append(w.readframes(w.getnframes()))

        with wave.open(str(final_wav), "wb") as out:
            out.setparams(params)
            for f in frames:
                out.writeframes(f)
        return True
    except Exception as e:
        # Fallback to ffmpeg concat if wave header differs
        concat_list = final_wav.with_suffix(".concat.txt")
        try:
            with open(concat_list, "w") as f:
                for wp in wav_paths:
                    f.write(f"file '{wp.resolve()}'\n")
            cmd = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat_list), "-c", "copy", str(final_wav)]
            res = subprocess.run(cmd, capture_output=True, text=True)
            return res.returncode == 0
        except Exception:
            return False
        finally:
            if concat_list.exists():
                concat_list.unlink()


def synthesize_speech_edge(text: str, voice_id: str, output_wav: Path, rate: str = "+0%") -> bool:
    """Synthesize speech using Microsoft Edge Neural TTS with ffmpeg WAV conversion."""
    edge_bin = Path.home() / ".local" / "bin" / "edge-tts"
    if not edge_bin.exists():
        edge_bin = Path("edge-tts")

    chunks = split_text_into_chunks(text, max_chars=4000)
    temp_wavs = []
    temp_dir = output_wav.parent / ".tts_tmp"
    temp_dir.mkdir(parents=True, exist_ok=True)

    try:
        for idx, chunk in enumerate(chunks, 1):
            if len(chunks) > 1:
                print(f"  {CYAN}Generating audio chunk {idx}/{len(chunks)} ({len(chunk)} characters)...{RESET}")
            chunk_txt = temp_dir / f"chunk_{idx}.txt"
            chunk_mp3 = temp_dir / f"chunk_{idx}.mp3"
            chunk_wav = temp_dir / f"chunk_{idx}.wav"
            chunk_txt.write_text(chunk, encoding="utf-8")

            cmd_tts = [
                str(edge_bin),
                "-f", str(chunk_txt),
                "-v", voice_id,
                "--rate", rate,
                "--write-media", str(chunk_mp3)
            ]
            res_tts = subprocess.run(cmd_tts, capture_output=True, text=True, timeout=120)
            if res_tts.returncode != 0 or not chunk_mp3.exists() or chunk_mp3.stat().st_size == 0:
                print(f"{YELLOW}[!] Edge-TTS chunk {idx} failed: {res_tts.stderr.strip()}{RESET}")
                return False

            # Convert MP3 to standard uncompressed PCM WAV
            cmd_conv = [
                "ffmpeg", "-y", "-v", "error",
                "-i", str(chunk_mp3),
                "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le",
                str(chunk_wav)
            ]
            res_conv = subprocess.run(cmd_conv, capture_output=True, text=True)
            if res_conv.returncode != 0 or not chunk_wav.exists():
                return False

            temp_wavs.append(chunk_wav)

        # Merge chunks into final wav
        success = concatenate_wav_files(temp_wavs, output_wav)
        return success and output_wav.exists() and output_wav.stat().st_size > 44
    except Exception as e:
        print(f"{RED}[-] Error during Edge-TTS generation: {e}{RESET}")
        return False
    finally:
        # Cleanup temporary files
        shutil.rmtree(temp_dir, ignore_errors=True)


def convert_text_to_speech(text_file: Path, voice_id: str, tts_dir: Path) -> Optional[Tuple[Path, Path]]:
    """
    Core conversion pipeline:
      1. Reads and sanitizes .txt from tts_dir
      2. Saves .wav output initially into tts_dir
      3. Generates Date & ID (YYYY-MM-DD_ID###_<filename>)
      4. Moves both .wav and .txt into tts_dir/TTS_CONVERTED/
    Returns (converted_wav_path, moved_txt_path) or None on failure.
    """
    if not text_file.exists():
        print(f"{RED}[-] Error: File not found: {text_file}{RESET}")
        return None

    converted_dir = tts_dir / "TTS_CONVERTED"
    converted_dir.mkdir(parents=True, exist_ok=True)

    v_info = get_voice_info(voice_id)
    raw_content = text_file.read_text(encoding="utf-8", errors="ignore")
    cleaned_content = sanitize_text_for_speech(raw_content)

    if not cleaned_content:
        print(f"{RED}[-] Error: File {text_file.name} is empty or contains no speakable text.{RESET}")
        return None

    char_count = len(cleaned_content)
    word_count = len(cleaned_content.split())
    original_stem = text_file.stem
    initial_wav = tts_dir / f"{original_stem}.wav"

    print(f"\n{BOLD}{CYAN}══════════════════════════════════════════════════════════════{RESET}")
    print(f"{BOLD}Converting File:{RESET}   {GREEN}{text_file.name}{RESET}")
    print(f"{BOLD}Voice Selected:{RESET}    {YELLOW}{v_info['name']} ({v_info['gender']}, {v_info['accent']}){RESET}")
    print(f"{BOLD}Engine Mode:{RESET}       {MAGENTA}{v_info['engine'].upper()}{RESET} ({v_info['id']})")
    print(f"{BOLD}Text Volume:{RESET}       {CYAN}{char_count:,} characters / {word_count:,} words{RESET}")
    print(f"{BOLD}Step 1 Target:{RESET}     {DIM}{initial_wav}{RESET}")
    print(f"{BOLD}{CYAN}══════════════════════════════════════════════════════════════{RESET}")

    t_start = time.time()
    success = False

    # Check engine
    if v_info["engine"] == "espeak":
        print(f"[*] Synthesizing via eSpeak-NG local engine...")
        success = synthesize_speech_espeak(cleaned_content, v_info["id"], initial_wav)
    else:
        # Edge-TTS
        # Notice: for massive files (>30,000 chars), if network is slow, allow seamless fallback
        print(f"[*] Synthesizing via Microsoft Edge Neural TTS...")
        success = synthesize_speech_edge(cleaned_content, v_info["id"], initial_wav)
        if not success:
            print(f"{YELLOW}[!] Neural generation encountered an issue. Falling back to eSpeak-NG British Female voice...{RESET}")
            fallback_voice = "en-gb+f3" if v_info["gender"] == "Female" else "en-gb"
            success = synthesize_speech_espeak(cleaned_content, fallback_voice, initial_wav)

    if not success or not initial_wav.exists():
        print(f"{RED}[-] Synthesis failed for {text_file.name}!{RESET}")
        return None

    dur_sec = get_audio_duration_seconds(initial_wav)
    wav_size = initial_wav.stat().st_size
    elapsed = time.time() - t_start

    print(f"{GREEN}[✓] Audio generated successfully in {elapsed:.1f}s!{RESET}")
    print(f"    Duration: {BOLD}{format_duration(dur_sec)}{RESET} | Size: {BOLD}{format_size(wav_size)}{RESET}")
    print(f"    Saved initially at: {GREEN}{initial_wav}{RESET}")

    # Step 2: Determine Date and next unique ID
    today_str = datetime.date.today().strftime("%Y-%m-%d")
    unique_id = get_next_id(converted_dir, today_str)

    target_stem = f"{today_str}_{unique_id}_{original_stem}"
    final_wav = converted_dir / f"{target_stem}.wav"
    final_txt = converted_dir / f"{target_stem}.txt"

    print(f"\n[*] Moving converted pair to {BOLD}TTS_CONVERTED{RESET} with Date and ID: {CYAN}{unique_id}{RESET}...")

    # Move wav and original txt
    shutil.move(str(initial_wav), str(final_wav))
    shutil.move(str(text_file), str(final_txt))

    print(f"{GREEN}[✓] Successfully archived in TTS_CONVERTED:{RESET}")
    print(f"    Audio: {CYAN}{final_wav.name}{RESET}")
    print(f"    Text:  {CYAN}{final_txt.name}{RESET}")

    # Append to conversion history log
    log_file = converted_dir / "tts_conversion_history.log"
    try:
        timestamp_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(log_file, "a", encoding="utf-8") as lf:
            lf.write(
                f"[{timestamp_str}] ID={unique_id} VOICE={v_info['name']} ({v_info['id']}) "
                f"WORDS={word_count} DUR={format_duration(dur_sec)} AUDIO={final_wav.name} TXT={final_txt.name}\n"
            )
    except Exception:
        pass

    return final_wav, final_txt


def list_pending_text_files(tts_dir: Path) -> List[Path]:
    """Return all .txt files directly inside tts_dir (excluding subdirectories)."""
    if not tts_dir.exists():
        return []
    txt_files = [p for p in tts_dir.iterdir() if p.is_file() and p.suffix.lower() == ".txt"]
    txt_files.sort(key=lambda p: p.name.lower())
    return txt_files


def list_converted_audio_files(tts_dir: Path) -> List[Path]:
    """Return all .wav files in TTS_CONVERTED (sorted newest first)."""
    converted_dir = tts_dir / "TTS_CONVERTED"
    if not converted_dir.exists():
        return []
    wav_files = [p for p in converted_dir.iterdir() if p.is_file() and p.suffix.lower() == ".wav"]
    wav_files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return wav_files


def play_audio_file(wav_path: Path) -> None:
    """Plays an audio file using available system player with interactive stop control."""
    if not wav_path.exists():
        print(f"{RED}[-] File does not exist: {wav_path}{RESET}")
        return

    dur = get_audio_duration_seconds(wav_path)
    print(f"\n{BOLD}{GREEN}▶ Playing:{RESET} {CYAN}{wav_path.name}{RESET} ({format_duration(dur)})")
    print(f"{DIM}Press [Enter] or [s] at any time to stop playback...{RESET}\n")

    player_cmd = None
    if shutil.which("pw-play"):
        player_cmd = ["pw-play", str(wav_path)]
    elif shutil.which("aplay"):
        player_cmd = ["aplay", "-q", str(wav_path)]
    elif shutil.which("ffplay"):
        player_cmd = ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", str(wav_path)]
    elif shutil.which("mpv"):
        player_cmd = ["mpv", "--no-video", str(wav_path)]
    elif shutil.which("vlc"):
        player_cmd = ["cvlc", "--play-and-exit", str(wav_path)]

    if not player_cmd:
        print(f"{RED}[-] Error: No supported audio player (pw-play, aplay, ffplay, mpv) found!{RESET}")
        return

    proc = subprocess.Popen(player_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        # Wait for user input or process finish
        while proc.poll() is None:
            # Check non-blocking stdin
            import select
            r, _, _ = select.select([sys.stdin], [], [], 0.3)
            if r:
                line = sys.stdin.readline().strip().lower()
                print(f"{YELLOW}[■] Stopping playback...{RESET}")
                proc.terminate()
                try:
                    proc.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    proc.kill()
                break
    except KeyboardInterrupt:
        print(f"\n{YELLOW}[■] Playback stopped by user.{RESET}")
        proc.terminate()
    print(f"{DIM}Playback finished.{RESET}")


def preview_voice(voice_id: str) -> None:
    """Generates and plays a short audio preview for the chosen voice."""
    v_info = get_voice_info(voice_id)
    preview_text = f"Hello! This is {v_info['name']}. Your WAN2GP text to speech conversion system is ready."
    preview_wav = Path("/tmp") / f"tts_preview_{v_info['name'].lower().replace(' ', '_')}.wav"

    print(f"\n[*] Generating voice preview for {BOLD}{v_info['name']}{RESET} ({v_info['gender']}, {v_info['accent']})...")
    success = False
    if v_info["engine"] == "espeak":
        success = synthesize_speech_espeak(preview_text, v_info["id"], preview_wav)
    else:
        success = synthesize_speech_edge(preview_text, v_info["id"], preview_wav)

    if success and preview_wav.exists():
        play_audio_file(preview_wav)
        preview_wav.unlink(missing_ok=True)
    else:
        print(f"{RED}[-] Failed to generate voice preview.{RESET}")


def select_voice_menu(current_voice_id: str) -> str:
    """Displays the voice selection menu with female and male British and international voices."""
    while True:
        os.system("clear" if os.name == "posix" else "cls")
        curr_info = get_voice_info(current_voice_id)
        print(f"{BOLD}{MAGENTA}=================================================={RESET}")
        print(f"{BOLD}{MAGENTA}           SELECT TEXT-TO-SPEECH VOICE            {RESET}")
        print(f"{BOLD}{MAGENTA}=================================================={RESET}")
        print(f"  Active Voice: {BOLD}{GREEN}{curr_info['name']}{RESET} ({curr_info['gender']}, {curr_info['accent']} - {curr_info['engine'].upper()})\n")

        print(f"{BOLD}{CYAN}--- BRITISH (ENGLISH) VOICES ---{RESET}")
        for i in range(1, 9):
            v = VOICES[i - 1]
            marker = f"{GREEN}●{RESET}" if v["id"] == current_voice_id else " "
            print(f" {marker} {BOLD}{CYAN}{i:2d}){RESET} [{v['gender']:6s}] {BOLD}{v['name']:18s}{RESET} | {DIM}{v['desc']}{RESET}")

        print(f"\n{BOLD}{CYAN}--- AMERICAN (ENGLISH) VOICES ---{RESET}")
        for i in range(9, 17):
            v = VOICES[i - 1]
            marker = f"{GREEN}●{RESET}" if v["id"] == current_voice_id else " "
            print(f" {marker} {BOLD}{CYAN}{i:2d}){RESET} [{v['gender']:6s}] {BOLD}{v['name']:18s}{RESET} | {DIM}{v['desc']}{RESET}")

        print(f"\n{BOLD}{CYAN}--- OTHER ACCENTS (ENGLISH) ---{RESET}")
        for i in range(17, len(VOICES) + 1):
            v = VOICES[i - 1]
            marker = f"{GREEN}●{RESET}" if v["id"] == current_voice_id else " "
            print(f" {marker} {BOLD}{CYAN}{i:2d}){RESET} [{v['gender']:6s}] {BOLD}{v['name']:18s}{RESET} | {DIM}{v['desc']}{RESET}")

        print("")
        print(f"  {BOLD}P){RESET} Preview Current Voice Sample")
        print(f"  {BOLD}B){RESET} Back / Confirm Selection")
        print("")

        choice = input(f"{BOLD}Enter choice [1-{len(VOICES)} / P / B]: {RESET}").strip()
        if choice.lower() == "b" or choice == "":
            return current_voice_id
        elif choice.lower() == "p":
            preview_voice(current_voice_id)
            pause_if_tty()
        else:
            try:
                idx = int(choice)
                if 1 <= idx <= len(VOICES):
                    selected = VOICES[idx - 1]
                    current_voice_id = selected["id"]
                    print(f"\n{GREEN}✓ Voice set to: {selected['name']} ({selected['gender']}, {selected['accent']}){RESET}")
                    # Auto preview on selection
                    preview_voice(current_voice_id)
                    time.sleep(0.5)
                else:
                    print(f"{RED}Invalid number choice!{RESET}")
                    time.sleep(1)
            except ValueError:
                print(f"{RED}Invalid input!{RESET}")
                time.sleep(1)


def playback_menu(tts_dir: Path) -> None:
    """Interactive audio player menu for listening to converted speech files."""
    while True:
        os.system("clear" if os.name == "posix" else "cls")
        converted_dir = tts_dir / "TTS_CONVERTED"
        audio_files = list_converted_audio_files(tts_dir)

        print(f"{BOLD}{MAGENTA}=================================================={RESET}")
        print(f"{BOLD}{MAGENTA}       CONVERTED SPEECH AUDIO PLAYBACK MENU       {RESET}")
        print(f"{BOLD}{MAGENTA}=================================================={RESET}")
        print(f"  Location: {CYAN}{converted_dir}{RESET}")
        print(f"  Converted Audio Files: {BOLD}{len(audio_files)}{RESET}\n")

        if not audio_files:
            print(f"  {YELLOW}No converted .wav audio files found in TTS_CONVERTED.{RESET}")
            print(f"  Convert a .txt file first to populate this list.\n")
            pause_if_tty("Press [Enter] to return to the TTS menu...")
            return

        print(f"  {BOLD}{'#':<3} {'Filename':<48} {'Duration':<10} {'Size':<10}{RESET}")
        print(f"  {DIM}{'─'*3} {'─'*48} {'─'*10} {'─'*10}{RESET}")

        display_limit = min(20, len(audio_files))
        for idx in range(display_limit):
            f = audio_files[idx]
            dur = format_duration(get_audio_duration_seconds(f))
            size = format_size(f.stat().st_size)
            name_disp = f.name if len(f.name) <= 46 else f.name[:43] + "..."
            print(f"  {BOLD}{CYAN}{idx + 1:2d}){RESET} {name_disp:<48} {dur:<10} {size:<10}")

        if len(audio_files) > display_limit:
            print(f"  {DIM}... and {len(audio_files) - display_limit} older file(s){RESET}")

        print("")
        print(f"  {BOLD}A){RESET} Play All Files Sequentially")
        print(f"  {BOLD}D){RESET} Open Folder in File Manager (Dolphin)")
        print(f"  {BOLD}B){RESET} Back to TTS Menu")
        print("")

        choice = input(f"{BOLD}Select track to play [1-{display_limit} / A / D / B]: {RESET}").strip()
        if choice.lower() == "b" or choice == "":
            return
        elif choice.lower() == "a":
            for f in audio_files:
                play_audio_file(f)
        elif choice.lower() == "d":
            if shutil.which("dolphin"):
                subprocess.Popen(["dolphin", str(converted_dir)])
            elif shutil.which("xdg-open"):
                subprocess.Popen(["xdg-open", str(converted_dir)])
        else:
            try:
                num = int(choice)
                if 1 <= num <= len(audio_files):
                    play_audio_file(audio_files[num - 1])
                    pause_if_tty()
                else:
                    print(f"{RED}Invalid selection!{RESET}")
                    time.sleep(1)
            except ValueError:
                print(f"{RED}Invalid input!{RESET}")
                time.sleep(1)


def convert_single_interactive(tts_dir: Path, voice_id: str) -> None:
    """Interactive prompt to select and convert a single text file."""
    pending = list_pending_text_files(tts_dir)
    if not pending:
        print(f"\n{YELLOW}[!] No pending .txt files found in {tts_dir}!{RESET}")
        print(f"Please place your text files into the directory first.")
        pause_if_tty()
        return

    print(f"\n{BOLD}{CYAN}--- AVAILABLE TEXT FILES FOR CONVERSION ---{RESET}")
    for idx, p in enumerate(pending, 1):
        size = format_size(p.stat().st_size)
        print(f"  {BOLD}{CYAN}{idx:2d}){RESET} {p.name} ({DIM}{size}{RESET})")
    print("")

    choice = input(f"{BOLD}Select file number to convert [1-{len(pending)}] (or [B] Back): {RESET}").strip()
    if choice.lower() == "b" or choice == "":
        return
    try:
        idx = int(choice)
        if 1 <= idx <= len(pending):
            selected_file = pending[idx - 1]
            convert_text_to_speech(selected_file, voice_id, tts_dir)
            pause_if_tty()
        else:
            print(f"{RED}Invalid selection!{RESET}")
            time.sleep(1)
    except ValueError:
        print(f"{RED}Invalid input!{RESET}")
        time.sleep(1)


def convert_all_batch(tts_dir: Path, voice_id: str) -> None:
    """Batch converts all pending .txt files in the TTS directory."""
    pending = list_pending_text_files(tts_dir)
    if not pending:
        print(f"\n{YELLOW}[!] No pending .txt files found in {tts_dir}!{RESET}")
        pause_if_tty()
        return

    print(f"\n{BOLD}{MAGENTA}Starting Batch Conversion of {len(pending)} file(s)...{RESET}")
    success_count = 0
    t_start = time.time()

    for idx, p in enumerate(pending, 1):
        print(f"\n{BOLD}[Batch {idx}/{len(pending)}]{RESET} Processing: {CYAN}{p.name}{RESET}")
        result = convert_text_to_speech(p, voice_id, tts_dir)
        if result:
            success_count += 1

    total_time = time.time() - t_start
    print(f"\n{BOLD}{GREEN}══════════════════════════════════════════════════════════════{RESET}")
    print(f"{BOLD}BATCH CONVERSION COMPLETE:{RESET} {GREEN}{success_count}/{len(pending)}{RESET} files converted successfully in {total_time:.1f}s.")
    print(f"{BOLD}Archived location:{RESET} {CYAN}{tts_dir / 'TTS_CONVERTED'}{RESET}")
    print(f"{BOLD}{GREEN}══════════════════════════════════════════════════════════════{RESET}")
    pause_if_tty()


def interactive_main(tts_dir: Path) -> None:
    """Main interactive terminal UI for the TTS converter and audio player."""
    cfg = load_config()
    active_voice = cfg.get("voice_id", DEFAULT_VOICE_ID)

    while True:
        os.system("clear" if os.name == "posix" else "cls")
        pending = list_pending_text_files(tts_dir)
        converted = list_converted_audio_files(tts_dir)
        v_info = get_voice_info(active_voice)

        print(f"{BOLD}{MAGENTA}=================================================={RESET}")
        print(f"{BOLD}{MAGENTA}        WAN2GP TEXT-TO-SPEECH (TTS) MANAGER       {RESET}")
        print(f"{BOLD}{MAGENTA}=================================================={RESET}")
        print(f"  Batch Directory:  {GREEN}{tts_dir}{RESET}")
        print(f"  Archive Folder:   {CYAN}{tts_dir / 'TTS_CONVERTED'}{RESET}")
        print(f"  Pending .txt:     {BOLD}{YELLOW if pending else GREEN}{len(pending)} file(s){RESET}")
        print(f"  Converted .wav:   {BOLD}{GREEN}{len(converted)} file(s){RESET}")
        print(f"  Active Voice:     {BOLD}{CYAN}{v_info['name']}{RESET} [{v_info['gender']}, {v_info['accent']}] ({v_info['engine'].upper()})")
        print("")
        print(f"  {BOLD}${CYAN}1)${RESET} Convert a Single Text File ({BOLD}{len(pending)}{RESET} pending)")
        print(f"  {BOLD}${CYAN}2)${RESET} Batch Convert All Text Files in Directory ({BOLD}{len(pending)}{RESET} files)")
        print(f"  {BOLD}${CYAN}3)${RESET} Select Voice (British / US / Male / Female / Accents)")
        print(f"  {BOLD}${CYAN}4)${RESET} Preview / Test Current Voice")
        print(f"  {BOLD}${CYAN}5)${RESET} Audio Player & Playback Menu (Play Converted Audio)")
        print(f"  {BOLD}${CYAN}6)${RESET} Open TTS Directory in File Manager (Dolphin)")
        print(f"  {BOLD}${CYAN}7)${RESET} Return to WAN2GP / Main Menu")
        print("")

        choice = input(f"{BOLD}Enter choice [1-7]: {RESET}").strip()
        if choice == "1":
            convert_single_interactive(tts_dir, active_voice)
        elif choice == "2":
            convert_all_batch(tts_dir, active_voice)
        elif choice == "3":
            active_voice = select_voice_menu(active_voice)
            cfg["voice_id"] = active_voice
            save_config(cfg)
        elif choice == "4":
            preview_voice(active_voice)
            pause_if_tty()
        elif choice == "5":
            playback_menu(tts_dir)
        elif choice == "6":
            if shutil.which("dolphin"):
                subprocess.Popen(["dolphin", str(tts_dir)])
            elif shutil.which("xdg-open"):
                subprocess.Popen(["xdg-open", str(tts_dir)])
        elif choice in ["7", "q", "exit"]:
            print(f"\n{GREEN}Returning to WAN2GP Server Manager...{RESET}\n")
            break
        else:
            print(f"{RED}Invalid option!{RESET}")
            time.sleep(1)


def main():
    parser = argparse.ArgumentParser(description="WAN2GP Text-to-Speech (TTS) Batch Converter & Audio Player")
    parser.add_argument("--file", "-f", type=str, help="Convert a single text file (filename or full path)")
    parser.add_argument("--all", "-a", action="store_true", help="Batch convert all .txt files in the TTS batch directory")
    parser.add_argument("--voice", "-v", type=str, default=None, help="Voice ID or name (e.g. en-GB-SoniaNeural, espeak:en-gb+f3)")
    parser.add_argument("--dir", "-d", type=str, default=None, help="Custom TTS batch directory")
    parser.add_argument("--play", "-p", action="store_true", help="Launch interactive audio player playback menu")
    parser.add_argument("--list-voices", "-l", action="store_true", help="List all available voices and exit")
    args = parser.parse_args()

    # Determine TTS directory
    tts_dir = Path(args.dir) if args.dir else DEFAULT_TTS_DIR
    tts_dir.mkdir(parents=True, exist_ok=True)
    (tts_dir / "TTS_CONVERTED").mkdir(parents=True, exist_ok=True)

    # List voices option
    if args.list_voices:
        print(f"\n{BOLD}{CYAN}Available Text-to-Speech Voices:{RESET}\n")
        for idx, v in enumerate(VOICES, 1):
            print(f"  {idx:2d}) {BOLD}{v['name']:18s}{RESET} [{v['gender']:6s}] {v['accent']:30s} ({v['id']})")
        return

    cfg = load_config()
    voice_id = args.voice if args.voice else cfg.get("voice_id", DEFAULT_VOICE_ID)

    # CLI play mode
    if args.play:
        playback_menu(tts_dir)
        return

    # CLI single file mode
    if args.file:
        target = Path(args.file)
        if not target.is_absolute():
            target = tts_dir / target
        convert_text_to_speech(target, voice_id, tts_dir)
        return

    # CLI batch all mode
    if args.all:
        convert_all_batch(tts_dir, voice_id)
        return

    # Default interactive UI
    interactive_main(tts_dir)


if __name__ == "__main__":
    main()
