#!/usr/bin/env python3
"""
scripts/get_mp_audio_player_file.py
Queries the MP Audio Player instance (via IPC socket, live process check, or state sync)
and reports the filepath of the track currently being played (or last played).

Part of MP_Mix_Manager_v0.3 (Dreamworlds Productions)
"""

import sys
import os
import json
import socket
import argparse
from pathlib import Path

# ANSI colors for formatted output
BOLD = "\033[1m"
DIM = "\033[2m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
MAGENTA = "\033[35m"
BLUE = "\033[34m"
RED = "\033[31m"
WHITE = "\033[37m"
NC = "\033[0m"


def is_pid_alive(pid: int) -> bool:
    """Checks whether a process with the given PID is running."""
    if not pid or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ValueError):
        return False


def query_socket(sock_path: Path, timeout: float = 0.5) -> dict | None:
    """Connects to MP Audio Player's Unix domain socket and retrieves live status."""
    if not sock_path.is_socket():
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(str(sock_path))
        payload = json.dumps({"cmd": "status"}) + "\n"
        s.sendall(payload.encode("utf-8"))
        raw = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            raw += chunk
            if b"\n" in chunk or len(chunk) < 4096:
                break
        s.close()
        if raw:
            res = json.loads(raw.decode("utf-8").strip())
            if isinstance(res, dict) and res.get("status") == "ok":
                return res.get("data")
            elif isinstance(res, dict) and "path" in res:
                return res
    except Exception:
        pass
    return None


def read_state_file(state_path: Path) -> dict | None:
    """Reads state from mp_player_state.json if present."""
    if not state_path.is_file():
        return None
    try:
        with open(state_path, "r", encoding="utf-8", errors="ignore") as f:
            data = json.load(f)
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    return None


def get_player_status() -> tuple[dict | None, str, bool]:
    """
    Retrieves MP Audio Player status dictionary, source, and whether the process is live.
    Returns: (status_dict, source, is_alive)
    """
    config_dir = Path.home() / ".config" / "mix-manager"
    sock_path = config_dir / "mp_audio_player.sock"
    state_path = config_dir / "mp_player_state.json"
    pid_path = config_dir / "mp_player.pid"

    # Check pid file
    pid = None
    if pid_path.is_file():
        try:
            pid = int(pid_path.read_text().strip())
        except (ValueError, OSError):
            pid = None

    # 1. Try Unix domain socket IPC (indicates active live daemon)
    status = query_socket(sock_path)
    if status:
        return status, "ipc_socket", True

    # 2. Try JSON state file
    state_data = read_state_file(state_path)
    if state_data:
        saved_pid = state_data.get("pid") or pid
        live = is_pid_alive(saved_pid) if saved_pid else False
        return state_data, "state_file", live

    # 3. Direct execution fallback
    base_dir = Path(__file__).resolve().parent.parent
    player_py = base_dir / "MP_Audio_Player.py"
    if not player_py.is_file():
        player_py = Path(__file__).resolve().parent / "MP_Audio_Player.py"

    if player_py.is_file():
        try:
            import subprocess
            proc = subprocess.run(
                [sys.executable, str(player_py), "--status"],
                capture_output=True,
                text=True,
                timeout=1.0
            )
            if proc.returncode == 0 and proc.stdout.strip():
                data = json.loads(proc.stdout.strip())
                if isinstance(data, dict):
                    cli_pid = data.get("pid")
                    live = is_pid_alive(cli_pid) if cli_pid else False
                    return data, "cli_status", live
        except Exception:
            pass

    return None, "none", False


def format_file_size(num_bytes: int) -> str:
    b = float(num_bytes)
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(b) < 1024.0:
            return f"{b:3.2f} {unit}"
        b /= 1024.0
    return f"{b:.2f} PB"


def main():
    parser = argparse.ArgumentParser(
        description="Query MP Audio Player and output current (or last played) audio filepath."
    )
    parser.add_argument("-r", "--raw", action="store_true", help="Print only the raw filepath")
    parser.add_argument("-j", "--json", action="store_true", help="Output complete player status JSON")
    parser.add_argument("-v", "--verbose", "-d", "--details", action="store_true", help="Display detailed formatted track information")
    parser.add_argument("--live-only", action="store_true", help="Only succeed if the MP Audio Player process is actively running")
    args = parser.parse_args()

    status, source, is_alive = get_player_status()

    if not status:
        if args.json:
            print(json.dumps({"running": False, "state": "stopped", "path": ""}, indent=2))
        elif not args.raw:
            print(f"{RED}Error: No MP Audio Player playback status found.{NC}", file=sys.stderr)
        sys.exit(2)

    path = status.get("path", "")
    state = status.get("state", "stopped")

    if args.live_only and not is_alive:
        if args.json:
            print(json.dumps({**status, "running": False, "live": False}, indent=2))
        elif not args.raw:
            print(f"{RED}Error: MP Audio Player is not actively running.{NC}", file=sys.stderr)
        sys.exit(2)

    if not path:
        if args.json:
            print(json.dumps(status, indent=2))
        elif not args.raw:
            print(f"{YELLOW}Notice: MP Audio Player is found ({state}) but no audio track is loaded.{NC}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        status_copy = dict(status)
        status_copy["live_process"] = is_alive
        print(json.dumps(status_copy, indent=2))
        sys.exit(0)

    if args.raw:
        print(path)
        sys.exit(0)

    if args.verbose:
        title = status.get("title", os.path.basename(path))
        pos_fmt = status.get("position_fmt", "00:00")
        dur_fmt = status.get("duration_fmt", "00:00")
        pct = status.get("progress_pct", 0.0)
        vol = status.get("volume", 100)
        pitch = status.get("pitch_percent", 0)
        sr = status.get("sample_rate", 44100)
        ch = status.get("channels", 2)
        mini_eq = status.get("mini_eq", "")
        pid = status.get("pid", "N/A")

        file_exists = os.path.isfile(path)
        size_str = format_file_size(os.path.getsize(path)) if file_exists else "File Not Found"

        if is_alive:
            status_banner = f"{GREEN}LIVE ACTIVE PLAYBACK{NC}" if state == "playing" else f"{YELLOW}PAUSED (PROCESS ACTIVE){NC}"
        else:
            status_banner = f"{DIM}OFFLINE (LAST RECORDED PLAYBACK){NC}"

        pitch_str = f"{pitch:+d}%" if pitch != 0 else "0% (Detent)"

        print(f"\n{BOLD}{MAGENTA}==================================================================================={NC}")
        print(f"{BOLD}{WHITE}                   🎵 MP AUDIO PLAYER — PLAYBACK STATUS 🎵                         {NC}")
        print(f"{BOLD}{MAGENTA}==================================================================================={NC}\n")
        print(f"  {BOLD}{CYAN}Playback State:{NC}  {status_banner}  {DIM}[PID: {pid} via {source}]{NC}")
        print(f"  {BOLD}{CYAN}Track Title:{NC}     {WHITE}{title}{NC}")
        print(f"  {BOLD}{CYAN}File Path:{NC}       {GREEN}{path}{NC}")
        print(f"  {BOLD}{CYAN}Position:{NC}        {WHITE}{pos_fmt}{NC} / {WHITE}{dur_fmt}{NC}  {DIM}({pct}% complete){NC}")
        print(f"  {BOLD}{CYAN}Format Info:{NC}     {WHITE}{sr} Hz{NC} | {WHITE}{ch} Channels{NC} | {YELLOW}{size_str}{NC}")
        print(f"  {BOLD}{CYAN}Controls:{NC}        Volume: {YELLOW}{vol}%{NC} | Pitch: {CYAN}{pitch_str}{NC}")
        if mini_eq and is_alive:
            print(f"  {BOLD}{CYAN}Live EQ:{NC}         {MAGENTA}{mini_eq}{NC}")
        print(f"\n{BOLD}{MAGENTA}==================================================================================={NC}\n")
        sys.exit(0)

    # Default output: print filepath (with note if offline and running interactively in terminal)
    if not is_alive and sys.stdout.isatty():
        print(f"{DIM}[Player Offline - Last Played Track]{NC} {path}")
    else:
        print(path)


if __name__ == "__main__":
    main()
