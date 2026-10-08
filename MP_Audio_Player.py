#!/usr/bin/env python3
"""
MP_Audio_Player.py - High-Resolution Audio Player & Custom Animated Equalizer
Part of MP_Mix_Manager_v0.3 (Dreamworlds Productions)

Features:
  - Universal audio playback supporting FLAC, WAV, MP3, AAC, OGG, and AIFF.
  - Multi-band Custom Animated Equalizer (Real-time FFT, Dual Stereo L/R, VU Meters, Oscilloscope).
  - Seamless archive scanning across all configured MP Mix Archive Manager locations.
  - Interactive terminal TUI with live spectrum visualization, playlist browser, and filter search.
  - Headless background daemon mode with Unix socket IPC & JSON state synchronization.
  - Full remote control from CLI or anywhere in Mix_Archive_Manager.sh (Space: Play/Pause, Next/Prev, Vol, Seek).
"""

import os
import sys
import time
import math
import random
import json
import socket
import select
import signal
import shutil
import argparse
import threading
import subprocess
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple

try:
    import numpy as np
except ImportError:
    print("Error: numpy is required for MP_Audio_Player.py", file=sys.stderr)
    sys.exit(1)

try:
    import soundfile as sf
except ImportError:
    sf = None

try:
    import sounddevice as sd
except ImportError:
    sd = None

# Terminal Raw Input helpers
try:
    import termios
    import tty
except ImportError:
    termios = None
    tty = None

# --- ANSI Color Codes & Styles ---
BOLD = "\033[1m"
DIM = "\033[2m"
ITALIC = "\033[3m"
UNDERLINE = "\033[4m"
REVERSE = "\033[7m"
NC = "\033[0m"

# Standard Palette
BLACK = "\033[0;30m"
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[0;37m"
BRIGHT_WHITE = "\033[1;37m"

# 24-bit Truecolor Palettes
COLOR_NEON_PINK = "\033[38;2;247;37;133m"
COLOR_ELECTRIC_CYAN = "\033[38;2;0;229;255m"
COLOR_AMBER_ORANGE = "\033[38;2;255;140;0m"
COLOR_DEEP_PURPLE = "\033[38;2;114;9;183m"
COLOR_NEON_GREEN = "\033[38;2;57;255;20m"
COLOR_SLATE_GREY = "\033[38;2;88;98;118m"

CONFIG_DIR = Path.home() / ".config" / "mix-manager"
CONFIG_DIR.mkdir(parents=True, exist_ok=True)
SOCKET_PATH = CONFIG_DIR / "mp_audio_player.sock"
STATE_FILE = CONFIG_DIR / "mp_player_state.json"
PID_FILE = CONFIG_DIR / "mp_player.pid"

AUDIO_EXTENSIONS = ('.flac', '.wav', '.mp3', '.ogg', '.m4a', '.aac', '.aiff', '.wma')
UNICODE_BLOCKS = [' ', ' ', '▂', '▃', '▄', '▅', '▆', '▇', '█']


def get_base_dir() -> Path:
    script_p = Path(__file__).resolve()
    if script_p.parent.name == "scripts":
        return script_p.parent.parent
    return script_p.parent


def parse_env_file(filepath: Path) -> Dict[str, str]:
    env = {}
    if not filepath.is_file():
        return env
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip('"').strip("'")
                env[k] = v
    except Exception:
        pass
    return env


def format_seconds(seconds: float) -> str:
    if seconds < 0 or math.isnan(seconds):
        return "00:00"
    s = int(seconds)
    hours = s // 3600
    minutes = (s % 3600) // 60
    secs = s % 60
    if hours > 0:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


# ==============================================================================
# ARCHIVE MIX SCANNER
# ==============================================================================

class MixArchiveScanner:
    """Discovers and catalogs all available mixes across configured archive folders."""

    def __init__(self, base_dir: Union[Path, str]):
        self.base_dir = Path(base_dir)
        self.mixes: List[Dict[str, Any]] = []
        self._load_and_scan()

    def _get_archive_dirs(self) -> List[Path]:
        dirs = []
        seen = set()

        def add_dir(p_str: Optional[str]):
            if not p_str:
                return
            p = Path(os.path.expanduser(p_str)).resolve()
            if p.is_dir() and str(p) not in seen:
                seen.add(str(p))
                dirs.append(p)

        # 1. Local environment configs
        env_files = [
            self.base_dir / "config.env",
            CONFIG_DIR / "config.env"
        ]
        for ef in env_files:
            cfg = parse_env_file(ef)
            add_dir(cfg.get("MIX_ARCHIVE_DIR"))
            extra = cfg.get("EXTRA_MIX_ARCHIVE_DIRS") or cfg.get("MIX_ARCHIVE_DIRS")
            if extra:
                for sep in [":", ",", ";", "\n"]:
                    if sep in extra:
                        parts = extra.split(sep)
                        for part in parts:
                            add_dir(part.strip())
                        break
                else:
                    add_dir(extra.strip())

        # 2. Well-known project directories
        add_dir(str(self.base_dir / "MIX_ARCHIVE"))
        add_dir(str(self.base_dir / "FLAC_CONVERTED_OUTPUTS"))
        add_dir(str(self.base_dir / "MP3_CONVERTED_OUTPUTS"))
        add_dir(str(self.base_dir / "WAV_CONVERTED_OUTPUTS"))
        add_dir("/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE")
        add_dir("/run/media/mplanetarian/DATA/MIX_ARCHIVE2/FLAC_CONVERTED_OUTPUTS")
        add_dir(os.path.expanduser("~/GoogleDrive/MIX_ARCHIVE"))

        return dirs

    def _load_and_scan(self):
        archive_dirs = self._get_archive_dirs()
        seen_paths = set()
        collected = []

        for ad in archive_dirs:
            if not ad.is_dir():
                continue
            try:
                for root, _, files in os.walk(ad):
                    if "/." in root or "__pycache__" in root:
                        continue
                    for f in files:
                        ext = os.path.splitext(f)[1].lower()
                        if ext in AUDIO_EXTENSIONS:
                            full_path = os.path.join(root, f)
                            if full_path in seen_paths:
                                continue
                            seen_paths.add(full_path)
                            try:
                                stat = os.stat(full_path)
                                size_mb = stat.st_size / (1024 * 1024)
                                mtime = stat.st_mtime
                                collected.append({
                                    "name": f,
                                    "path": full_path,
                                    "size_mb": size_mb,
                                    "mtime": mtime,
                                    "ext": ext.replace(".", "").upper()
                                })
                            except OSError:
                                pass
            except Exception:
                pass

        # Sort newest first by default
        collected.sort(key=lambda x: x["mtime"], reverse=True)
        self.mixes = collected

    def get_mixes(self, query: str = "") -> List[Dict[str, Any]]:
        if not query:
            return self.mixes
        q = query.lower()
        return [m for m in self.mixes if q in m["name"].lower() or q in m["path"].lower()]

    def get_latest_mix(self) -> Optional[Dict[str, Any]]:
        return self.mixes[0] if self.mixes else None


# ==============================================================================
# AUDIO PLAYBACK ENGINE & REAL-TIME SPECTRUM ANALYZER
# ==============================================================================

class AudioEngine:
    """High-performance audio streaming engine with FFT spectrum extraction."""

    def __init__(self, playlist: List[Dict[str, Any]]):
        self.playlist = playlist
        self.current_index = 0
        self.current_track: Optional[Dict[str, Any]] = playlist[0] if playlist else None

        self.state = "stopped"  # "playing", "paused", "stopped"
        self.volume = 0.85      # 0.0 to 1.0
        self.muted = False
        self.shuffle = False
        self.repeat_mode = "all" # "off", "one", "all"

        self.position_sec = 0.0
        self.duration_sec = 0.0
        self.sample_rate = 44100
        self.channels = 2

        self.sf_file: Optional[sf.SoundFile] = None
        self.stream: Optional[sd.OutputStream] = None

        # Equalizer Analysis State (16 Logarithmic Frequency Bands)
        self.num_bands = 16
        self.band_edges = np.logspace(np.log10(30), np.log10(18000), self.num_bands + 1)
        self.levels = np.zeros(self.num_bands, dtype=np.float32)
        self.levels_left = np.zeros(self.num_bands, dtype=np.float32)
        self.levels_right = np.zeros(self.num_bands, dtype=np.float32)
        self.smoothed_levels = np.zeros(self.num_bands, dtype=np.float32)
        self.peaks = np.zeros(self.num_bands, dtype=np.float32)
        self.peak_decay_timers = np.zeros(self.num_bands, dtype=np.float32)

        self.recent_mono_buffer = np.zeros(512, dtype=np.float32)
        self.rms_level = 0.0
        self.peak_db = -60.0

        # Background track end notification flag
        self.track_ended = False
        self.pending_seek_sec: Optional[float] = None

        # Initialize continuous audio stream
        self._init_stream()

    def _init_stream(self):
        try:
            self.stream = sd.OutputStream(
                samplerate=44100,
                channels=2,
                blocksize=1024,
                callback=self._audio_callback
            )
            self.stream.start()
        except Exception:
            pass

    def load_track(self, index: int, start_playing: bool = True) -> bool:
        if not self.playlist or index < 0 or index >= len(self.playlist):
            return False

        self.current_index = index
        self.current_track = self.playlist[index]
        file_path = self.current_track["path"]

        try:
            new_sf = sf.SoundFile(file_path)
            self.sample_rate = new_sf.samplerate
            self.channels = new_sf.channels
            self.duration_sec = float(new_sf.frames) / float(self.sample_rate)
            self.position_sec = 0.0

            # Recompute band frequency indices for current sample rate
            freqs = np.fft.rfftfreq(1024, 1.0 / self.sample_rate)
            self.band_indices = []
            for i in range(self.num_bands):
                low, high = self.band_edges[i], self.band_edges[i + 1]
                idx = np.where((freqs >= low) & (freqs < high))[0]
                if len(idx) == 0:
                    idx = np.array([min(len(freqs) - 1, max(0, int(low / (self.sample_rate / 2) * len(freqs))))])
                self.band_indices.append(idx)

            # Atomically swap active soundfile
            old_sf = self.sf_file
            self.sf_file = new_sf
            if old_sf:
                try:
                    old_sf.close()
                except Exception:
                    pass

            if self.stream is None:
                self._init_stream()

            if start_playing:
                self.state = "playing"
            else:
                self.state = "paused"
            return True
        except Exception:
            self.state = "stopped"
            return False

    def _audio_callback(self, outdata, frames, time_info, status):
        sf_ref = self.sf_file
        if sf_ref is None or self.state != "playing":
            outdata.fill(0)
            return

        if self.pending_seek_sec is not None:
            seek_val = self.pending_seek_sec
            self.pending_seek_sec = None
            try:
                target_frame = int(seek_val * self.sample_rate)
                sf_ref.seek(target_frame)
                self.position_sec = seek_val
            except Exception:
                pass

        try:
            data = sf_ref.read(frames, dtype='float32')
        except Exception:
            data = np.zeros((0, self.channels), dtype=np.float32)

        read_frames = len(data)
        if read_frames == 0:
            outdata.fill(0)
            self.track_ended = True
            return

        self.position_sec += float(read_frames) / float(self.sample_rate)
        effective_vol = 0.0 if self.muted else self.volume

        if data.ndim == 1:
            stereo_data = np.column_stack((data, data))
            mono_data = data
        elif data.shape[1] >= 2:
            stereo_data = data[:, :2]
            mono_data = np.mean(stereo_data, axis=1)
        else:
            stereo_data = np.column_stack((data[:, 0], data[:, 0]))
            mono_data = data[:, 0]

        if effective_vol != 1.0:
            stereo_data *= effective_vol

        outdata[:read_frames] = stereo_data
        if read_frames < frames:
            outdata[read_frames:].fill(0)
            self.track_ended = True

        self._compute_fft_spectrum(stereo_data, mono_data)

    def _compute_fft_spectrum(self, stereo_data: np.ndarray, mono_data: np.ndarray):
        try:
            fft_size = 1024
            if len(mono_data) < fft_size:
                padded = np.zeros(fft_size, dtype=np.float32)
                padded[:len(mono_data)] = mono_data
                mono_chunk = padded
                left_chunk = np.zeros(fft_size, dtype=np.float32)
                right_chunk = np.zeros(fft_size, dtype=np.float32)
                left_chunk[:len(stereo_data)] = stereo_data[:, 0]
                right_chunk[:len(stereo_data)] = stereo_data[:, 1]
            else:
                mono_chunk = mono_data[:fft_size]
                left_chunk = stereo_data[:fft_size, 0]
                right_chunk = stereo_data[:fft_size, 1]

            window = np.hanning(fft_size)
            mono_fft = np.abs(np.fft.rfft(mono_chunk * window)) / (fft_size / 2)
            left_fft = np.abs(np.fft.rfft(left_chunk * window)) / (fft_size / 2)
            right_fft = np.abs(np.fft.rfft(right_chunk * window)) / (fft_size / 2)

            raw_levels = np.zeros(self.num_bands, dtype=np.float32)
            raw_l = np.zeros(self.num_bands, dtype=np.float32)
            raw_r = np.zeros(self.num_bands, dtype=np.float32)

            for b_idx in range(self.num_bands):
                idx = self.band_indices[b_idx]
                boost = 1.0 + (1.2 / (1.0 + b_idx * 0.4))
                val_m = np.mean(mono_fft[idx]) * boost * 4.5
                val_l = np.mean(left_fft[idx]) * boost * 4.5
                val_r = np.mean(right_fft[idx]) * boost * 4.5

                raw_levels[b_idx] = min(1.0, max(0.0, float(val_m)))
                raw_l[b_idx] = min(1.0, max(0.0, float(val_l)))
                raw_r[b_idx] = min(1.0, max(0.0, float(val_r)))

            for b in range(self.num_bands):
                if raw_levels[b] > self.smoothed_levels[b]:
                    self.smoothed_levels[b] = raw_levels[b]
                else:
                    self.smoothed_levels[b] = self.smoothed_levels[b] * 0.82 + raw_levels[b] * 0.18

                if self.smoothed_levels[b] >= self.peaks[b]:
                    self.peaks[b] = self.smoothed_levels[b]
                    self.peak_decay_timers[b] = 0.0
                else:
                    self.peak_decay_timers[b] += 0.03
                    if self.peak_decay_timers[b] > 0.2:
                        self.peaks[b] = max(0.0, self.peaks[b] - 0.05)

            self.levels = raw_levels
            self.levels_left = raw_l
            self.levels_right = raw_r
            self.recent_mono_buffer = mono_chunk[:512]

            rms = np.sqrt(np.mean(mono_chunk ** 2))
            self.rms_level = float(rms)
            self.peak_db = 20.0 * np.log10(max(1e-5, np.max(np.abs(mono_chunk))))
        except Exception:
            pass

    def check_track_end(self):
        if self.track_ended:
            self.track_ended = False
            if self.repeat_mode == "one":
                self.seek(0)
            elif self.repeat_mode == "all" or self.current_index < len(self.playlist) - 1:
                self.next_track()
            else:
                self.stop_playback()

    def play(self):
        if self.sf_file is None:
            self.load_track(self.current_index, start_playing=True)
        else:
            self.state = "playing"

    def pause(self):
        self.state = "paused"

    def toggle_play_pause(self):
        if self.state == "playing":
            self.pause()
        else:
            self.play()

    def stop_playback(self):
        self.state = "stopped"
        self.position_sec = 0.0
        self.smoothed_levels.fill(0)
        self.peaks.fill(0)

    def next_track(self):
        if not self.playlist:
            return
        if self.shuffle:
            new_idx = random.randint(0, len(self.playlist) - 1)
        else:
            new_idx = (self.current_index + 1) % len(self.playlist)
        self.load_track(new_idx, start_playing=True)

    def prev_track(self):
        if not self.playlist:
            return
        if self.position_sec > 5.0:
            self.seek(0)
            return
        if self.shuffle:
            new_idx = random.randint(0, len(self.playlist) - 1)
        else:
            new_idx = (self.current_index - 1 + len(self.playlist)) % len(self.playlist)
        self.load_track(new_idx, start_playing=True)

    def seek(self, target_sec: float):
        if self.duration_sec > 0:
            clamped_sec = max(0.0, min(self.duration_sec - 1.0, target_sec))
            self.pending_seek_sec = clamped_sec
            self.position_sec = clamped_sec

    def seek_relative(self, delta_sec: float):
        self.seek(self.position_sec + delta_sec)

    def set_volume(self, vol_pct: int):
        self.volume = max(0.0, min(1.0, float(vol_pct) / 100.0))
        self.muted = False

    def change_volume(self, delta_pct: int):
        cur_pct = int(self.volume * 100)
        self.set_volume(cur_pct + delta_pct)

    def toggle_mute(self):
        self.muted = not self.muted

    def toggle_shuffle(self):
        self.shuffle = not self.shuffle

    def cycle_repeat(self):
        modes = ["all", "one", "off"]
        idx = (modes.index(self.repeat_mode) + 1) % len(modes)
        self.repeat_mode = modes[idx]

    def get_mini_visualizer(self) -> str:
        if self.state != "playing":
            return "·······"
        step = max(1, self.num_bands // 8)
        chars = []
        for i in range(0, self.num_bands, step)[:8]:
            val = self.smoothed_levels[i]
            idx = int(val * 8)
            chars.append(UNICODE_BLOCKS[max(0, min(8, idx))])
        return "".join(chars)

    def get_status_dict(self) -> Dict[str, Any]:
        track_name = self.current_track["name"] if self.current_track else "No Track Loaded"
        track_path = self.current_track["path"] if self.current_track else ""
        pos_fmt = format_seconds(self.position_sec)
        dur_fmt = format_seconds(self.duration_sec)
        pct = round((self.position_sec / self.duration_sec * 100.0), 1) if self.duration_sec > 0 else 0.0

        return {
            "running": True,
            "state": str(self.state),
            "index": int(self.current_index),
            "total_tracks": int(len(self.playlist)),
            "title": str(track_name),
            "path": str(track_path),
            "position_sec": round(float(self.position_sec), 2),
            "duration_sec": round(float(self.duration_sec), 2),
            "position_fmt": str(pos_fmt),
            "duration_fmt": str(dur_fmt),
            "progress_pct": float(pct),
            "volume": int(self.volume * 100),
            "muted": bool(self.muted),
            "shuffle": bool(self.shuffle),
            "repeat": str(self.repeat_mode),
            "sample_rate": int(self.sample_rate),
            "channels": int(self.channels),
            "mini_eq": str(self.get_mini_visualizer()),
            "levels": [round(float(x), 3) for x in self.smoothed_levels],
            "peaks": [round(float(x), 3) for x in self.peaks],
            "levels_left": [round(float(x), 3) for x in self.levels_left],
            "levels_right": [round(float(x), 3) for x in self.levels_right],
            "peak_db": round(float(self.peak_db), 1),
            "pid": int(os.getpid())
        }


# ==============================================================================
# IPC SERVER & STATE DAEMON
# ==============================================================================

class PlayerIPCServer:
    """Unix domain socket server that enables control from anywhere in Mix Manager."""

    def __init__(self, engine: AudioEngine):
        self.engine = engine
        self.running = True
        self.sock: Optional[socket.socket] = None

    def start(self):
        if SOCKET_PATH.exists():
            try:
                SOCKET_PATH.unlink()
            except OSError:
                pass

        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(str(SOCKET_PATH))
        self.sock.listen(10)
        self.sock.setblocking(False)

        PID_FILE.write_text(str(os.getpid()))

        threading.Thread(target=self._server_loop, daemon=True).start()
        threading.Thread(target=self._state_sync_loop, daemon=True).start()

    def _server_loop(self):
        while self.running:
            try:
                r, _, _ = select.select([self.sock], [], [], 0.2)
                if r:
                    conn, _ = self.sock.accept()
                    threading.Thread(target=self._handle_client, args=(conn,), daemon=True).start()
            except Exception:
                pass

    def _handle_client(self, conn: socket.socket):
        try:
            conn.settimeout(2.0)
            data = conn.recv(4096).decode('utf-8')
            if not data:
                conn.close()
                return

            req = json.loads(data)
            cmd = req.get("cmd")
            res = {"status": "ok"}

            if cmd == "status":
                res["data"] = self.engine.get_status_dict()
            elif cmd == "play":
                file_arg = req.get("file")
                if file_arg:
                    for idx, t in enumerate(self.engine.playlist):
                        if t["path"] == file_arg or t["name"] == os.path.basename(file_arg):
                            self.engine.load_track(idx, start_playing=True)
                            break
                    else:
                        new_track = {
                            "name": os.path.basename(file_arg),
                            "path": file_arg,
                            "size_mb": 0,
                            "mtime": time.time(),
                            "ext": os.path.splitext(file_arg)[1].replace(".", "").upper()
                        }
                        self.engine.playlist.insert(0, new_track)
                        self.engine.load_track(0, start_playing=True)
                else:
                    self.engine.play()
            elif cmd == "pause":
                self.engine.pause()
            elif cmd in ("toggle", "play_pause"):
                self.engine.toggle_play_pause()
                res["state"] = self.engine.state
            elif cmd in ("stop", "quit"):
                self.engine.stop_playback()
                self.running = False
                try:
                    with open(STATE_FILE, "w", encoding="utf-8") as f:
                        json.dump({"running": False, "state": "stopped"}, f)
                except OSError:
                    pass
                try:
                    SOCKET_PATH.unlink()
                except OSError:
                    pass
                try:
                    PID_FILE.unlink()
                except OSError:
                    pass
                conn.sendall(json.dumps(res).encode('utf-8'))
                conn.close()
                os._exit(0)
            elif cmd == "next":
                self.engine.next_track()
            elif cmd == "prev":
                self.engine.prev_track()
            elif cmd == "seek":
                delta = float(req.get("seconds", 10.0))
                self.engine.seek_relative(delta)
            elif cmd == "seek_to":
                pos = float(req.get("position", 0.0))
                self.engine.seek(pos)
            elif cmd == "set_volume":
                self.engine.set_volume(int(req.get("volume", 85)))
            elif cmd == "vol_up":
                self.engine.change_volume(int(req.get("step", 5)))
            elif cmd == "vol_down":
                self.engine.change_volume(-int(req.get("step", 5)))
            elif cmd == "mute":
                self.engine.toggle_mute()
            elif cmd == "shuffle":
                self.engine.toggle_shuffle()
            elif cmd == "repeat":
                self.engine.cycle_repeat()
            elif cmd == "select_index":
                idx = int(req.get("index", 0))
                self.engine.load_track(idx, start_playing=True)
            elif cmd == "get_playlist":
                res["playlist"] = [
                    {"index": i, "name": t["name"], "path": t["path"], "ext": t["ext"]}
                    for i, t in enumerate(self.engine.playlist[:100])
                ]

            conn.sendall(json.dumps(res, default=float).encode('utf-8'))
        except Exception as e:
            try:
                conn.sendall(json.dumps({"status": "error", "message": str(e)}).encode('utf-8'))
            except Exception:
                pass
        finally:
            try:
                conn.close()
            except Exception:
                pass

    def _state_sync_loop(self):
        while self.running:
            try:
                st = self.engine.get_status_dict()
                tmp_file = STATE_FILE.with_suffix(".tmp")
                with open(tmp_file, "w", encoding="utf-8") as f:
                    json.dump(st, f, default=float)
                tmp_file.replace(STATE_FILE)
            except Exception:
                pass
            time.sleep(0.04)


# ==============================================================================
# IPC CLIENT (Used by CLI commands and Mix_Archive_Manager.sh)
# ==============================================================================

def send_ipc_command(cmd: str, **kwargs) -> Optional[Dict[str, Any]]:
    if not SOCKET_PATH.exists():
        return None
    for attempt in range(3):
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.settimeout(0.6)
            sock.connect(str(SOCKET_PATH))
            payload = {"cmd": cmd}
            payload.update(kwargs)
            sock.sendall(json.dumps(payload).encode('utf-8'))
            raw = sock.recv(65536).decode('utf-8')
            sock.close()
            if raw:
                return json.loads(raw)
        except Exception:
            time.sleep(0.05)
    return None


def is_player_daemon_running() -> bool:
    if PID_FILE.exists():
        try:
            pid = int(PID_FILE.read_text().strip())
            os.kill(pid, 0)
            return True
        except (OSError, ValueError):
            try:
                PID_FILE.unlink()
            except OSError:
                pass
            try:
                if SOCKET_PATH.exists():
                    SOCKET_PATH.unlink()
            except OSError:
                pass
            return False
    if SOCKET_PATH.exists():
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.2)
            s.connect(str(SOCKET_PATH))
            s.close()
            return True
        except Exception:
            try:
                SOCKET_PATH.unlink()
            except OSError:
                pass
    return False



# ==============================================================================
# ANIMATED EQUALIZER & VISUALIZERS (TUI RENDERER)
# ==============================================================================

class EqualizerVisualizer:
    """Renders high-resolution animated equalizers and studio meters."""

    STYLES = [
        "stereo_eq",      # 12-Band Dual Left & Right Graphic EQ
        "master_spectrum",# 24-Band Master Hi-Fi Frequency Spectrum
        "analog_vu",      # Studio Analog VU Meters with clip indicators
        "oscilloscope"    # Real-time audio waveform oscilloscope
    ]

    THEMES = [
        "dreamworlds",    # Neon Magenta, Aqua Cyan, Amber (Dreamworlds Ultra)
        "retro_studio",   # Classic Green -> Yellow -> Red Studio VU
        "cyber_neon",     # Violet, Blue, Pink
        "phosphor",       # Monochrome Phosphor Green
        "ice_cold"        # Arctic Blue, Mint, White
    ]

    def __init__(self):
        self.style_idx = 0
        self.theme_idx = 0

    @property
    def style(self) -> str:
        return self.STYLES[self.style_idx]

    @property
    def theme(self) -> str:
        return self.THEMES[self.theme_idx]

    def cycle_style(self):
        self.style_idx = (self.style_idx + 1) % len(self.STYLES)

    def cycle_theme(self):
        self.theme_idx = (self.theme_idx + 1) % len(self.THEMES)

    def _get_bar_color(self, fraction: float) -> str:
        if self.theme == "dreamworlds":
            if fraction < 0.4:
                return "\033[38;2;0;229;255m"     # Electric Aqua
            elif fraction < 0.75:
                return "\033[38;2;247;37;133m"   # Neon Pink
            else:
                return "\033[38;2;255;140;0m"     # Amber Orange
        elif self.theme == "retro_studio":
            if fraction < 0.6:
                return "\033[38;2;46;204;113m"    # Emerald Green
            elif fraction < 0.85:
                return "\033[38;2;241;196;15m"   # Warm Gold
            else:
                return "\033[38;2;231;76;60m"     # Studio Red
        elif self.theme == "cyber_neon":
            if fraction < 0.5:
                return "\033[38;2;114;9;183m"    # Deep Violet
            else:
                return "\033[38;2;76;201;240m"   # Neon Blue
        elif self.theme == "phosphor":
            return "\033[38;2;57;255;20m"        # Phosphor Matrix Green
        else:
            if fraction < 0.5:
                return "\033[38;2;30;144;255m"   # Dodger Blue
            else:
                return "\033[38;2;224;255;255m"  # Light Cyan

    def render_stereo_eq(self, levels_l: np.ndarray, levels_r: np.ndarray, peaks: np.ndarray, width: int = 80, height: int = 7) -> List[str]:
        lines = []
        if width >= 96:
            # Full High-Resolution 12-Band Stereo Equalizer (91 columns)
            bands_l = levels_l[:12] if len(levels_l) >= 12 else np.pad(levels_l, (0, max(0, 12 - len(levels_l))))
            bands_r = levels_r[:12] if len(levels_r) >= 12 else np.pad(levels_r, (0, max(0, 12 - len(levels_r))))
            band_widths = [3, 3, 4, 4, 4, 3, 3, 3, 3, 4, 4, 4]

            lines.append(f"  {BOLD}{MAGENTA}╭── LEFT CHANNEL (12-BAND) ─────────────────┬── RIGHT CHANNEL (12-BAND) ────────────────╮{NC}")

            for r in range(height - 1, -1, -1):
                row_frac = float(r) / float(height)
                color = self._get_bar_color(row_frac)

                def _build_side(bands, pk_offset=0):
                    parts = []
                    for c in range(12):
                        val = bands[c]
                        pk_idx = (c + pk_offset) % len(peaks) if len(peaks) > 0 else 0
                        peak_val = peaks[pk_idx] if len(peaks) > 0 else 0.0
                        peak_row = int(peak_val * height)
                        val_frac = val * height - r

                        if val_frac >= 1.0:
                            char = "█"
                        elif val_frac > 0.0:
                            sub_idx = int(val_frac * 8)
                            char = UNICODE_BLOCKS[max(1, min(8, sub_idx))]
                        elif peak_row == r:
                            char = "▔"
                        else:
                            char = " "

                        w = band_widths[c]
                        if w == 3:
                            parts.append(f" {char} ")
                        else:
                            parts.append(f" {char*2} ")
                    return " " + "".join(parts)

                side_l = _build_side(bands_l, 0)
                side_r = _build_side(bands_r, 12)
                lines.append(f"  │{color}{side_l}{NC}│{color}{side_r}{NC}│")

            lbls = f"  {DIM}{CYAN}│ 30 60 125 250 500 1k 2k 4k 8k 12k 16k 18k │ 30 60 125 250 500 1k 2k 4k 8k 12k 16k 18k │{NC}"
            lines.append(lbls)
            lines.append(f"  {BOLD}{MAGENTA}╰───────────────────────────────────────────┴───────────────────────────────────────────╯{NC}")
        else:
            # Compact 8-Band Stereo Equalizer (77 columns)
            bands_l = levels_l[:8] if len(levels_l) >= 8 else np.pad(levels_l, (0, max(0, 8 - len(levels_l))))
            bands_r = levels_r[:8] if len(levels_r) >= 8 else np.pad(levels_r, (0, max(0, 8 - len(levels_r))))

            lines.append(f"  {BOLD}{MAGENTA}╭── LEFT CHANNEL (8-BAND) ───────────┬── RIGHT CHANNEL (8-BAND) ──────────╮{NC}")

            for r in range(height - 1, -1, -1):
                row_frac = float(r) / float(height)
                color = self._get_bar_color(row_frac)

                def _build_comp_side(bands, pk_offset=0):
                    parts = []
                    for c in range(8):
                        val = bands[c]
                        pk_idx = (c + pk_offset) % len(peaks) if len(peaks) > 0 else 0
                        peak_val = peaks[pk_idx] if len(peaks) > 0 else 0.0
                        peak_row = int(peak_val * height)
                        val_frac = val * height - r

                        if val_frac >= 1.0:
                            char = "█"
                        elif val_frac > 0.0:
                            sub_idx = int(val_frac * 8)
                            char = UNICODE_BLOCKS[max(1, min(8, sub_idx))]
                        elif peak_row == r:
                            char = "▔"
                        else:
                            char = " "
                        parts.append(f" {char*2} ")
                    return "  " + "".join(parts) + "  "

                side_l = _build_comp_side(bands_l, 0)
                side_r = _build_comp_side(bands_r, 8)
                lines.append(f"  │{color}{side_l}{NC}│{color}{side_r}{NC}│")

            lbls = f"  {DIM}{CYAN}│  32  64  125 250 500  1k  4k  16k  │  32  64  125 250 500  1k  4k  16k  │{NC}"
            lines.append(lbls)
            lines.append(f"  {BOLD}{MAGENTA}╰────────────────────────────────────┴────────────────────────────────────╯{NC}")

        return lines

    def render_master_spectrum(self, levels: np.ndarray, peaks: np.ndarray, height: int = 7) -> List[str]:
        lines = []
        lines.append(f"  {BOLD}{MAGENTA}╭── HIGH-RESOLUTION MASTER FREQUENCY SPECTRUM (30Hz - 18kHz) ──────────────╮{NC}")

        if len(levels) > 1:
            x_old = np.linspace(0, 1, len(levels))
            x_new = np.linspace(0, 1, 24)
            interp_levels = np.interp(x_new, x_old, levels)
            interp_peaks = np.interp(x_new, x_old, peaks) if len(peaks) > 1 else np.zeros(24)
        else:
            interp_levels = np.zeros(24)
            interp_peaks = np.zeros(24)

        for r in range(height - 1, -1, -1):
            row_frac = float(r) / float(height)
            color = self._get_bar_color(row_frac)
            row_chars = []

            for c, val in enumerate(interp_levels):
                peak_row = int(interp_peaks[c] * height)
                val_frac = val * height - r

                if val_frac >= 1.0:
                    char = "█"
                elif val_frac > 0.0:
                    sub_idx = int(val_frac * 8)
                    char = UNICODE_BLOCKS[max(1, min(8, sub_idx))]
                elif peak_row == r:
                    char = "▔"
                else:
                    char = " "
                row_chars.append(f"{char*2} ")

            lines.append(f"  │ {color}{''.join(row_chars)}{NC} │")

        lines.append(f"  {DIM}{CYAN}│  32  63  125  250  500   1k   2k   4k   8k  12k  16k  18k    PEAK HOLD ✦ │{NC}")
        lines.append(f"  {BOLD}{MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯{NC}")
        return lines

    def render_analog_vu(self, peak_db: float, levels_l: np.ndarray, levels_r: np.ndarray) -> List[str]:
        lines = []
        lines.append(f"  {BOLD}{MAGENTA}╭── DUAL ANALOG STUDIO VU METERS (PEAK & RMS BALLISTICS) ──────────────────╮{NC}")

        l_val = np.mean(levels_l) if len(levels_l) else 0.0
        r_val = np.mean(levels_r) if len(levels_r) else 0.0

        bar_len = 46
        l_filled = int(l_val * bar_len)
        r_filled = int(r_val * bar_len)

        def make_meter(filled: int, name: str) -> str:
            buf = []
            for i in range(bar_len):
                frac = i / bar_len
                col = self._get_bar_color(frac)
                if i < filled:
                    buf.append(f"{col}█{NC}")
                else:
                    buf.append(f"{DIM}░{NC}")
            clip = f"{BOLD}{RED}[CLIP]{NC}" if filled >= bar_len - 1 else f"{DIM}[SAFE]{NC}"
            return f"  │  {BOLD}{CYAN}{name}{NC} [{''.join(buf)}] {clip}   │"

        lines.append("  │  -40   -30   -20   -10   -7   -5   -3   -1    0  +1  +2  +3 dB           │")
        lines.append(make_meter(l_filled, "LEFT  CHANNEL"))
        lines.append(make_meter(r_filled, "RIGHT CHANNEL"))
        lines.append(f"  │  Peak Audio Level: {BOLD}{YELLOW}{peak_db:+6.1f} dBFS{NC}  │  Master Headroom: {BOLD}{GREEN}{max(0.0, -peak_db):5.1f} dB{NC}             │")
        lines.append(f"  {BOLD}{MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯{NC}")
        return lines

    def render_oscilloscope(self, levels: np.ndarray, height: int = 5) -> List[str]:
        lines = []
        lines.append(f"  {BOLD}{MAGENTA}╭── DYNAMIC OSCILLOSCOPE AUDIO WAVEFORM ───────────────────────────────────╮{NC}")
        wave_cols = 70
        pts = []
        for i in range(wave_cols):
            val = levels[i % len(levels)] if len(levels) else 0.0
            phase = math.sin(i * 0.4) * val
            pts.append(phase)

        half_h = max(1, height // 2)
        for r in range(half_h, -half_h - 1, -1):
            row_str = ["  │  "]
            for p in pts:
                val_row = int(p * (half_h + 0.5))
                if val_row == r:
                    row_str.append(f"{COLOR_ELECTRIC_CYAN}∿{NC}")
                elif r == 0:
                    row_str.append(f"{DIM}─{NC}")
                else:
                    row_str.append(" ")
            row_str.append("  │")
            lines.append("".join(row_str))

        lines.append(f"  {BOLD}{MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯{NC}")
        return lines

    def render(self, status: Dict[str, Any], width: int = 80, height: int = 7) -> List[str]:
        levels = np.array(status.get("levels", [0.0]*16))
        peaks = np.array(status.get("peaks", [0.0]*16))
        levels_l = np.array(status.get("levels_left", levels))
        levels_r = np.array(status.get("levels_right", levels))
        peak_db = status.get("peak_db", -60.0)

        if self.style == "stereo_eq":
            return self.render_stereo_eq(levels_l, levels_r, peaks, width=width, height=height)
        elif self.style == "master_spectrum":
            return self.render_master_spectrum(levels, peaks, height=height)
        elif self.style == "analog_vu":
            return self.render_analog_vu(peak_db, levels_l, levels_r)
        elif self.style == "oscilloscope":
            return self.render_oscilloscope(levels, height=min(5, height))
        else:
            return self.render_stereo_eq(levels_l, levels_r, peaks, width=width, height=height)


# ==============================================================================
# INTERACTIVE TERMINAL TUI PLAYER (DUAL MODE: LOCAL OR REMOTE ATTACH)
# ==============================================================================

class TerminalPlayerUI:
    """Full-featured interactive TUI for MP Audio Player."""

    def __init__(self, engine: Optional[AudioEngine], scanner: MixArchiveScanner, is_remote: bool = False):
        self.engine = engine
        self.scanner = scanner
        self.is_remote = is_remote
        self.visualizer = EqualizerVisualizer()
        self.running = True

        self.playlist_view_active = True
        self.search_mode = False
        self.search_query = ""
        self.selected_row = 0
        self.scroll_offset = 0
        self._initial_row_synced = False

        self.cached_status = {
            "title": "Loading...",
            "path": "",
            "state": "stopped",
            "position_fmt": "00:00",
            "duration_fmt": "00:00",
            "progress_pct": 0.0,
            "volume": 85,
            "muted": False,
            "shuffle": False,
            "repeat": "all",
            "levels": [0.0]*16,
            "peaks": [0.0]*16
        }

    def _get_status(self) -> Dict[str, Any]:
        if self.is_remote:
            if STATE_FILE.exists():
                try:
                    with open(STATE_FILE, "r", encoding="utf-8") as f:
                        self.cached_status = json.load(f)
                    return self.cached_status
                except Exception:
                    pass
            res = send_ipc_command("status")
            if res and "data" in res:
                self.cached_status = res["data"]
            return self.cached_status
        elif self.engine:
            return self.engine.get_status_dict()
        return self.cached_status

    def _sync_initial_selection(self, status: Dict[str, Any]):
        if self._initial_row_synced:
            return
        cur_path = status.get("path")
        if cur_path:
            mixes = self.scanner.get_mixes(self.search_query)
            for idx, m in enumerate(mixes):
                if m["path"] == cur_path:
                    self.selected_row = idx
                    self._initial_row_synced = True
                    return

    def _send_cmd(self, cmd: str, **kwargs):
        if self.is_remote:
            threading.Thread(target=send_ipc_command, args=(cmd,), kwargs=kwargs, daemon=True).start()
        elif self.engine:
            if cmd in ("toggle", "play_pause"):
                self.engine.toggle_play_pause()
            elif cmd == "play":
                file_arg = kwargs.get("file")
                if file_arg:
                    for idx, item in enumerate(self.engine.playlist):
                        if item["path"] == file_arg:
                            self.engine.load_track(idx, start_playing=True)
                            break
                    else:
                        new_track = {
                            "name": os.path.basename(file_arg),
                            "path": file_arg,
                            "size_mb": os.path.getsize(file_arg)/(1024*1024) if os.path.exists(file_arg) else 0,
                            "mtime": time.time(),
                            "ext": os.path.splitext(file_arg)[1].replace(".", "").upper()
                        }
                        self.engine.playlist.insert(0, new_track)
                        self.engine.load_track(0, start_playing=True)
                else:
                    self.engine.play()
            elif cmd == "pause":
                self.engine.pause()
            elif cmd == "next":
                self.engine.next_track()
            elif cmd == "prev":
                self.engine.prev_track()
            elif cmd == "seek":
                self.engine.seek_relative(kwargs.get("seconds", 10.0))
            elif cmd == "vol_up":
                self.engine.change_volume(kwargs.get("step", 5))
            elif cmd == "vol_down":
                self.engine.change_volume(-kwargs.get("step", 5))
            elif cmd == "mute":
                self.engine.toggle_mute()
            elif cmd == "shuffle":
                self.engine.toggle_shuffle()
            elif cmd == "repeat":
                self.engine.cycle_repeat()
            elif cmd == "stop":
                self.engine.stop_playback()
            elif cmd == "select_index":
                self.engine.load_track(kwargs.get("index", 0), start_playing=True)

    def run(self):
        fd = sys.stdin.fileno() if sys.stdin.isatty() else None
        old_settings = None
        if fd is not None and termios and tty:
            try:
                old_settings = termios.tcgetattr(fd)
                tty.setcbreak(fd)
                new_settings = termios.tcgetattr(fd)
                new_settings[1] |= termios.OPOST
                termios.tcsetattr(fd, termios.TCSADRAIN, new_settings)
            except Exception:
                pass

        sys.stdout.write("\033[?1049h\033[?25l\033[2J\033[H")
        sys.stdout.flush()

        threading.Thread(target=self._input_loop, daemon=True).start()

        try:
            while self.running:
                if not self.is_remote and self.engine:
                    self.engine.check_track_end()
                self._draw_frame()
                time.sleep(0.04)  # ~25 FPS animation
        except (KeyboardInterrupt, SystemExit):
            pass
        finally:
            self.running = False
            if fd is not None and old_settings and termios:
                try:
                    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                except Exception:
                    pass
            sys.stdout.write("\033[?25h\033[?1049l")
            sys.stdout.flush()

    def _input_loop(self):
        if not sys.stdin.isatty():
            return
        fd = sys.stdin.fileno()


        while self.running:
            try:
                r, _, _ = select.select([fd], [], [], 0.05)
                if not r or not self.running:
                    continue

                data = os.read(fd, 32)
                if not data:
                    continue

                # Distinguish standalone Escape from arrow/function escape sequences
                if data == b"\x1b":
                    r2, _, _ = select.select([fd], [], [], 0.03)
                    if r2:
                        data += os.read(fd, 31)

                self._process_key(data)
            except Exception:
                pass

    def _process_key(self, data: bytes):
        if not data:
            return

        # 1. Search Mode Handling
        if self.search_mode:
            if data in (b"\r", b"\n"):
                self.search_mode = False
                return
            elif data == b"\x1b":
                self.search_mode = False
                self.search_query = ""
                return
            elif data in (b"\x7f", b"\x08"):
                self.search_query = self.search_query[:-1]
                self.selected_row = 0
                return
            elif data in (b"\x1b[A", b"\x1bOA"):
                self._navigate_list(-1)
                return
            elif data in (b"\x1b[B", b"\x1bOB"):
                self._navigate_list(1)
                return
            else:
                try:
                    text = data.decode("utf-8", errors="ignore")
                    if text.isprintable():
                        self.search_query += text
                        self.selected_row = 0
                except Exception:
                    pass
                return

        # 2. Navigation Keys (Arrow keys, Page up/down, Home/End, Vim keys)
        if data in (b"\x1b[A", b"\x1bOA", b"k", b"K"):
            self._navigate_list(-1)
        elif data in (b"\x1b[B", b"\x1bOB", b"j", b"J"):
            self._navigate_list(1)
        elif data in (b"\x1b[5~",):
            self._navigate_list(-5)
        elif data in (b"\x1b[6~",):
            self._navigate_list(5)
        elif data in (b"\x1b[H", b"\x1b[1~", b"\x1b[7~", b"\x1bOH"):
            self.selected_row = 0
        elif data in (b"\x1b[F", b"\x1b[4~", b"\x1b[8~", b"\x1bOF"):
            filtered = self.scanner.get_mixes(self.search_query)
            if filtered:
                self.selected_row = len(filtered) - 1

        # 3. Seeking (Left/Right arrow)
        elif data in (b"\x1b[D", b"\x1bOD"):
            self._send_cmd("seek", seconds=-10.0)
        elif data in (b"\x1b[C", b"\x1bOC"):
            self._send_cmd("seek", seconds=10.0)

        # 4. Play Selected Mix (Enter)
        elif data in (b"\r", b"\n"):
            filtered = self.scanner.get_mixes(self.search_query)
            if filtered and 0 <= self.selected_row < len(filtered):
                chosen = filtered[self.selected_row]
                if self.is_remote:
                    self._send_cmd("play", file=chosen["path"])
                elif self.engine:
                    for idx, item in enumerate(self.engine.playlist):
                        if item["path"] == chosen["path"]:
                            self._send_cmd("select_index", index=idx)
                            break
                    else:
                        self._send_cmd("play", file=chosen["path"])

        # 5. Playback Controls
        elif data == b" ":
            self._send_cmd("toggle")
        elif data in (b"n", b"N", b">", b"]"):
            self._send_cmd("next")
        elif data in (b"p", b"P", b"<", b"["):
            self._send_cmd("prev")
        elif data in (b"+", b"="):
            self._send_cmd("vol_up", step=5)
        elif data in (b"-", b"_"):
            self._send_cmd("vol_down", step=5)
        elif data in (b"m", b"M"):
            self._send_cmd("mute")
        elif data in (b"s", b"S"):
            self._send_cmd("shuffle")
        elif data in (b"r", b"R"):
            self._send_cmd("repeat")

        # 6. EQ & Themes
        elif data in (b"e", b"E", b"v", b"V"):
            self.visualizer.cycle_style()
        elif data in (b"c", b"C", b"t", b"T"):
            self.visualizer.cycle_theme()

        # 7. Search Filter
        elif data == b"/":
            self.search_mode = True
            self.search_query = ""

        # 8. Stop & Exit
        elif data in (b"x", b"X"):
            self._send_cmd("stop")
            self.running = False

        # 9. Return to previous menu / Exit UI
        elif data in (b"q", b"Q", b"b", b"B", b"\x1b", b"\x03"):
            self.running = False

    def _navigate_list(self, delta: int):
        filtered = self.scanner.get_mixes(self.search_query)
        total = len(filtered)
        if total == 0:
            return
        self.selected_row = max(0, min(total - 1, self.selected_row + delta))

    def _draw_frame(self):
        term_width, term_height = shutil.get_terminal_size((80, 24))
        status = self._get_status()
        self._sync_initial_selection(status)
        lines = []

        # 1. Header Banner
        lines.append(f"  {BOLD}{MAGENTA}╭──────────────────────────────────────────────────────────────────────────╮{NC}")
        lines.append(f"  {BOLD}{MAGENTA}│           ✦ MP AUDIO PLAYER — HIGH-RESOLUTION ARCHIVE SUITE ✦            │{NC}")
        lines.append(f"  {BOLD}{MAGENTA}│           Dreamworlds Productions  •  Studio Audiophile Playback         │{NC}")
        lines.append(f"  {BOLD}{MAGENTA}╰──────────────────────────────────────────────────────────────────────────╯{NC}")

        # 2. Track & Format Details Card
        track_name = status.get("title", "Unknown Mix")
        if len(track_name) > 58:
            track_name = track_name[:55] + "..."
        fmt = status.get("channels", 2)
        ch_str = "Stereo" if fmt == 2 else "Mono"
        sr = status.get("sample_rate", 44100)
        ext = os.path.splitext(status.get("path", ""))[1].replace(".", "").upper() or "FLAC"

        st_badge = f"{BOLD}{GREEN}▶ PLAYING{NC}" if status.get("state") == "playing" else f"{BOLD}{YELLOW}⏸ PAUSED{NC}"
        if status.get("state") == "stopped":
            st_badge = f"{BOLD}{RED}⏹ STOPPED{NC}"

        lines.append(f"  {st_badge}  {BOLD}{COLOR_NEON_PINK}♫  {track_name}{NC}")
        if term_width >= 96:
            lines.append(f"  {DIM}{CYAN}Format: {ext} Lossless  │  Sample Rate: {sr/1000:.1f} kHz  │  Channels: {ch_str}  │  Archive: Configured{NC}")
        else:
            lines.append(f"  {DIM}{CYAN}Format: {ext}  │  Sample Rate: {sr/1000:.1f} kHz  │  Channels: {ch_str}  │  Archive: OK{NC}")

        # 3. Time Progress Bar
        pos_s = status.get("position_fmt", "00:00")
        dur_s = status.get("duration_fmt", "00:00")
        pct = float(status.get("progress_pct", 0.0))

        bar_width = max(20, min(42, term_width - 34))
        filled_w = int((pct / 100.0) * bar_width)
        bar_str = "━" * filled_w + "●" + "─" * max(0, bar_width - filled_w - 1)
        lines.append(f"  {COLOR_ELECTRIC_CYAN}{pos_s}{NC}  {COLOR_AMBER_ORANGE}{bar_str}{NC}  {COLOR_ELECTRIC_CYAN}{dur_s}{NC}  ({pct:.1f}%)")
        lines.append("")

        # Dynamic visualizer height based on terminal height
        if term_height >= 34:
            vis_h = 7
        elif term_height >= 28:
            vis_h = 5
        else:
            vis_h = 3

        # 4. Custom Animated Equalizer
        eq_lines = self.visualizer.render(status, width=term_width, height=vis_h)
        lines.extend(eq_lines)
        lines.append("")

        # 5. Archive Mix Selector / Playlist Browser
        mixes = self.scanner.get_mixes(self.search_query)
        total_mixes = len(mixes)

        search_header = f"  {BOLD}{CYAN}Filter / Search: [{self.search_query}█]{NC}" if self.search_mode else f"  {BOLD}Search Filter: '{self.search_query}' (Press '/' to search)" if self.search_query else ""
        if search_header:
            lines.append(search_header)

        title_txt = f"── MIX ARCHIVE PLAYLIST ({total_mixes} Mixes Available) "
        dashes_cnt = max(4, 74 - len(title_txt))
        lines.append(f"  {BOLD}{MAGENTA}┌{title_txt}{'─'*dashes_cnt}┐{NC}")

        overhead_lines = len(lines) + 4
        visible_rows = max(2, min(24, term_height - overhead_lines))

        if self.selected_row < self.scroll_offset:
            self.scroll_offset = self.selected_row
        elif self.selected_row >= self.scroll_offset + visible_rows:
            self.scroll_offset = self.selected_row - visible_rows + 1

        for idx in range(self.scroll_offset, min(total_mixes, self.scroll_offset + visible_rows)):
            mix = mixes[idx]
            is_active = (mix["path"] == status.get("path"))
            is_sel = (idx == self.selected_row)

            m_name = mix["name"]
            if len(m_name) > 51:
                m_name = m_name[:48] + "..."

            prefix = "▶ " if is_active else "  "
            sz_str = f"{mix['size_mb']:.0f}MB"

            if is_sel:
                line_str = f"  │ \033[7m{prefix}[{idx+1:4d}] {m_name:<51} {mix['ext']} {sz_str:>6s}\033[0m │"
            elif is_active:
                line_str = f"  │ {BOLD}{GREEN}{prefix}[{idx+1:4d}] {m_name:<51} {mix['ext']} {sz_str:>6s}{NC} │"
            else:
                line_str = f"  │ {prefix}[{idx+1:4d}] {m_name:<51} {mix['ext']} {sz_str:>6s} │"
            lines.append(line_str)

        foot_txt = "── ↑/↓: Scroll  •  Enter: Play Selection  •  /: Search Mixes "
        dashes_foot = max(4, 74 - len(foot_txt))
        lines.append(f"  {BOLD}{MAGENTA}└{foot_txt}{'─'*dashes_foot}┘{NC}")

        # 6. Status and Hotkey Footer
        shuf_badge = f"{GREEN}ON{NC}" if status.get("shuffle") else f"{DIM}OFF{NC}"
        rep_badge = f"{GREEN}{status.get('repeat', 'all').upper()}{NC}"
        vol_str = f"{status.get('volume', 85)}%" if not status.get("muted") else f"{RED}MUTED{NC}"

        lines.append(f"  🔊 Volume: {BOLD}{COLOR_ELECTRIC_CYAN}{vol_str}{NC}  │  🔀 Shuffle: {shuf_badge}  │  🔁 Repeat: {rep_badge}  │  🎨 EQ: {BOLD}{CYAN}{self.visualizer.style}{NC}")
        if term_width >= 96:
            lines.append(f"  {DIM}[Space] Play/Pause  [n/p] Next/Prev  [←/→] Seek  [+/-] Vol  [e] EQ Style  [b/q] Exit  [x] Stop{NC}")
        else:
            lines.append(f"  {DIM}[Space] Play  [n/p] Skip  [←/→] Seek  [+/-] Vol  [e] EQ  [b/q] Exit  [x] Stop{NC}")

        frame_str = "\r\n".join(f"{line}\033[K" for line in lines)
        sys.stdout.write(f"\033[H{frame_str}\r\n\033[J")
        sys.stdout.flush()


# ==============================================================================
# MAIN ENTRYPOINT & CLI DISPATCHER
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(description="MP Audio Player - High Resolution Playback & Custom Animated Equalizer")
    parser.add_argument("file", nargs="?", help="Audio file path to play immediately")
    parser.add_argument("--daemon", action="store_true", help="Run as headless background audio daemon")
    parser.add_argument("--interactive", "-i", action="store_true", help="Launch interactive TUI player")
    parser.add_argument("--play", nargs="?", const="", help="Play / resume audio (optionally specify file)")
    parser.add_argument("--pause", action="store_true", help="Pause playback")
    parser.add_argument("--toggle", action="store_true", help="Toggle play/pause")
    parser.add_argument("--stop", action="store_true", help="Stop playback")
    parser.add_argument("--next", action="store_true", help="Skip to next track")
    parser.add_argument("--prev", action="store_true", help="Skip to previous track")
    parser.add_argument("--vol", type=str, help="Set volume (e.g. 85, +5, -5)")
    parser.add_argument("--seek", type=float, help="Seek relative seconds (e.g. 10 or -10)")
    parser.add_argument("--status", action="store_true", help="Output JSON playback status")
    parser.add_argument("--status-line", action="store_true", help="Output single-line formatted status with mini-visualizer")
    parser.add_argument("--play-latest", action="store_true", help="Automatically play the newest mix from archive")
    parser.add_argument("--get-latest-mix", action="store_true", help="Print path of newest mix in archive and exit")
    parser.add_argument("--list-mixes", action="store_true", help="Print all available mixes in archive")
    parser.add_argument("--cmd", type=str, help="Send arbitrary IPC command (e.g. toggle, next, prev)")

    args, _ = parser.parse_known_args()
    base_dir = get_base_dir()

    # Fast metadata queries
    if args.get_latest_mix:
        scanner = MixArchiveScanner(base_dir)
        latest = scanner.get_latest_mix()
        if latest:
            print(latest["path"])
            sys.exit(0)
        sys.exit(1)

    if args.list_mixes:
        scanner = MixArchiveScanner(base_dir)
        for m in scanner.get_mixes():
            print(f"{m['path']}\t{m['size_mb']:.1f}MB\t{m['name']}")
        sys.exit(0)

    daemon_running = is_player_daemon_running()

    # Generic IPC command dispatcher
    if args.cmd:
        res = send_ipc_command(args.cmd)
        if res:
            print(json.dumps(res))
            sys.exit(0)
        sys.exit(1)

    if args.play_latest:
        scanner = MixArchiveScanner(base_dir)
        latest = scanner.get_latest_mix()
        if latest:
            if daemon_running:
                send_ipc_command("play", file=latest["path"])
                sys.exit(0)
            else:
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--daemon", latest["path"]], start_new_session=True)
                sys.exit(0)
        sys.exit(1)

    if args.toggle:
        if daemon_running:
            res = send_ipc_command("toggle")
            sys.exit(0 if res else 1)
        else:
            scanner = MixArchiveScanner(base_dir)
            latest = scanner.get_latest_mix()
            if latest:
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--daemon", latest["path"]], start_new_session=True)
            sys.exit(0)

    elif args.pause:
        if daemon_running:
            send_ipc_command("pause")
        sys.exit(0)

    elif args.play is not None:
        file_to_play = args.play if args.play else (args.file or "")
        if daemon_running:
            send_ipc_command("play", file=file_to_play if file_to_play else None)
            sys.exit(0)
        else:
            if not file_to_play:
                scanner = MixArchiveScanner(base_dir)
                latest = scanner.get_latest_mix()
                file_to_play = latest["path"] if latest else ""
            if file_to_play:
                subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "--daemon", file_to_play], start_new_session=True)
            sys.exit(0)

    elif args.stop:
        if daemon_running:
            send_ipc_command("stop")
            sys.exit(0)
        sys.exit(0)

    elif args.next:
        if daemon_running:
            send_ipc_command("next")
            sys.exit(0)
        sys.exit(0)

    elif args.prev:
        if daemon_running:
            send_ipc_command("prev")
            sys.exit(0)
        sys.exit(0)

    elif args.vol:
        if daemon_running:
            v = args.vol
            if v.startswith("+"):
                send_ipc_command("vol_up", step=int(v[1:]))
            elif v.startswith("-"):
                send_ipc_command("vol_down", step=int(v[1:]))
            else:
                send_ipc_command("set_volume", volume=int(v))
            sys.exit(0)
        sys.exit(0)

    elif args.seek is not None:
        if daemon_running:
            send_ipc_command("seek", seconds=args.seek)
            sys.exit(0)
        sys.exit(0)

    elif args.status:
        if daemon_running:
            st = send_ipc_command("status")
            if st and "data" in st:
                print(json.dumps(st["data"], indent=2))
                sys.exit(0)
        print(json.dumps({"running": False, "state": "stopped"}))
        sys.exit(0)

    elif args.status_line:
        if daemon_running:
            st = send_ipc_command("status")
            if st and "data" in st:
                d = st["data"]
                st_icon = "▶" if d["state"] == "playing" else "⏸"
                print(f"{st_icon} {d['title']} [{d['position_fmt']}/{d['duration_fmt']}] ({d['mini_eq']}) Vol: {d['volume']}%")
                sys.exit(0)
        print("○ MP Audio Player: Stopped")
        sys.exit(0)

    # Interactive TUI Mode (Attach to daemon or launch daemon in background)
    if args.interactive or (not args.daemon and sys.stdin.isatty()):
        scanner = MixArchiveScanner(base_dir)
        mixes = scanner.get_mixes()
        if not mixes and not daemon_running:
            print(f"{RED}No audio mixes found in any configured archive directory.{NC}", file=sys.stderr)
            sys.exit(1)

        target_file = os.path.abspath(args.file) if args.file else None

        if not daemon_running:
            initial_file = target_file
            if not initial_file and mixes:
                latest = scanner.get_latest_mix()
                initial_file = latest["path"] if latest else mixes[0]["path"]

            if initial_file:
                subprocess.Popen(
                    [sys.executable, str(Path(__file__).resolve()), "--daemon", initial_file],
                    start_new_session=True
                )
                for _ in range(30):
                    time.sleep(0.04)
                    if is_player_daemon_running() and (SOCKET_PATH.exists() or STATE_FILE.exists()):
                        break
        elif target_file:
            send_ipc_command("play", file=target_file)

        ui = TerminalPlayerUI(None, scanner, is_remote=True)
        ui.run()
        sys.exit(0)

    # Local Audio Engine Initialization (Daemon or Non-interactive CLI)
    scanner = MixArchiveScanner(base_dir)
    mixes = scanner.get_mixes()

    initial_track_idx = 0
    if args.file:
        target_path = os.path.abspath(args.file)
        found = False
        for idx, m in enumerate(mixes):
            if m["path"] == target_path:
                initial_track_idx = idx
                found = True
                break
        if not found and os.path.isfile(target_path):
            mixes.insert(0, {
                "name": os.path.basename(target_path),
                "path": target_path,
                "size_mb": os.path.getsize(target_path) / (1024*1024),
                "mtime": time.time(),
                "ext": os.path.splitext(target_path)[1].replace(".", "").upper()
            })
            initial_track_idx = 0

    if not mixes:
        print(f"{RED}No audio mixes found in any configured archive directory.{NC}", file=sys.stderr)
        sys.exit(1)

    engine = AudioEngine(mixes)

    # Start audio daemon & IPC socket
    ipc_server = PlayerIPCServer(engine)
    ipc_server.start()

    # Load initial track
    engine.load_track(initial_track_idx, start_playing=True)

    # Daemon mode (runs headlessly in background)
    try:
        while True:
            engine.check_track_end()
            time.sleep(0.5)
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        engine.stop_playback()
        try:
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump({"running": False, "state": "stopped"}, f)
        except OSError:
            pass
        try:
            if PID_FILE.exists():
                PID_FILE.unlink()
        except OSError:
            pass
        try:
            if SOCKET_PATH.exists():
                SOCKET_PATH.unlink()
        except OSError:
            pass
        sys.exit(0)



if __name__ == "__main__":
    main()
