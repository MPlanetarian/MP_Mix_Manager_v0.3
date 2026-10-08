#!/usr/bin/env python3
"""
MP Mix Manager v0.3 - Studio & DJ Booth Mobile Web Companion
Lightweight, standalone HTTP & REST server providing a modern Dreamworlds-themed
web dashboard accessible from phones, tablets, and remote browsers on the local LAN.
Displays live mix playback, tracklists, Spek spectrograms, and remote playback controls.
"""

import argparse
import http.server
import json
import os
import shutil
import socket
import subprocess
import sys
import urllib.parse
from pathlib import Path

PORT = 8888
BASE_DIR = Path(__file__).resolve().parent.parent


def get_local_ip():
    """Detect LAN IP address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip


def get_playback_status():
    """Query player status (Audacious, Strawberry, or generic)."""
    status = {
        "player": "None",
        "state": "stopped",
        "title": "No Mix Playing",
        "artist": "MPlanetarian",
        "position": "00:00",
        "duration": "00:00",
        "progress_pct": 0,
        "active_file": ""
    }

    # Try playerctl if available
    if shutil.which("playerctl"):
        try:
            p_state = subprocess.check_output(["playerctl", "status"], stderr=subprocess.DEVNULL).decode('utf-8').strip().lower()
            p_title = subprocess.check_output(["playerctl", "metadata", "title"], stderr=subprocess.DEVNULL).decode('utf-8').strip()
            p_artist = subprocess.check_output(["playerctl", "metadata", "artist"], stderr=subprocess.DEVNULL).decode('utf-8').strip()
            p_pos = float(subprocess.check_output(["playerctl", "position"], stderr=subprocess.DEVNULL).decode('utf-8').strip() or 0)
            status["state"] = p_state
            status["title"] = p_title or "DJ Mix Session"
            status["artist"] = p_artist or "MPlanetarian"
            status["player"] = "MPRIS / playerctl"
            status["position"] = f"{int(p_pos // 60):02d}:{int(p_pos % 60):02d}"
            return status
        except Exception:
            pass

    # Try audacious / qdbus
    if shutil.which("qdbus"):
        try:
            aud_state = subprocess.check_output(["qdbus", "org.mpris.MediaPlayer2.audacious", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player.PlaybackStatus"], stderr=subprocess.DEVNULL).decode('utf-8').strip().lower()
            if aud_state:
                status["player"] = "Audacious"
                status["state"] = aud_state
                status["title"] = "Audacious Active Mix"
                return status
        except Exception:
            pass

    return status


def control_player(action):
    """Send playback control commands."""
    if shutil.which("playerctl"):
        if action in ["play-pause", "play", "pause", "next", "previous"]:
            subprocess.run(["playerctl", action], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
    return False


HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MP Mix Manager — DJ Booth Remote</title>
    <style>
        :root {
            --bg: #0d0f18;
            --card-bg: #151928;
            --accent-pink: #f72585;
            --accent-cyan: #00e5ff;
            --accent-coral: #ed254e;
            --accent-gold: #ffaa00;
            --text-main: #f0f3f6;
            --text-dim: #7f8ba4;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg);
            color: var(--text-main);
            margin: 0;
            padding: 20px;
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        .header {
            text-align: center;
            margin-bottom: 24px;
        }
        .header h1 {
            margin: 0;
            font-size: 1.8rem;
            background: linear-gradient(135deg, var(--accent-pink), var(--accent-cyan));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-weight: 800;
            letter-spacing: 1px;
        }
        .header p {
            margin: 6px 0 0 0;
            font-size: 0.85rem;
            color: var(--text-dim);
        }
        .card {
            background-color: var(--card-bg);
            border-radius: 16px;
            padding: 24px;
            width: 100%;
            max-width: 480px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
            border: 1px solid rgba(255,255,255,0.06);
            margin-bottom: 20px;
        }
        .now-playing {
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
        }
        .badge {
            background: rgba(0, 229, 255, 0.15);
            color: var(--accent-cyan);
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 12px;
        }
        .track-title {
            font-size: 1.25rem;
            font-weight: 700;
            margin: 0 0 6px 0;
            line-height: 1.3;
        }
        .track-artist {
            font-size: 0.95rem;
            color: var(--accent-pink);
            margin: 0 0 16px 0;
        }
        .time-row {
            display: flex;
            justify-content: space-between;
            width: 100%;
            font-size: 0.85rem;
            color: var(--text-dim);
            margin-top: 8px;
        }
        .controls {
            display: flex;
            justify-content: center;
            gap: 16px;
            margin-top: 24px;
            width: 100%;
        }
        button {
            background: #20263c;
            color: white;
            border: 1px solid rgba(255,255,255,0.1);
            padding: 14px 22px;
            border-radius: 12px;
            font-size: 1.1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.15s ease;
        }
        button:active {
            transform: scale(0.95);
            background: var(--accent-pink);
        }
        .btn-primary {
            background: linear-gradient(135deg, var(--accent-pink), var(--accent-coral));
            color: white;
            padding: 14px 28px;
            box-shadow: 0 4px 15px rgba(247, 37, 133, 0.4);
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>MP MIX MANAGER</h1>
        <p>Studio & DJ Booth Mobile Companion</p>
    </div>

    <div class="card now-playing">
        <div id="playBadge" class="badge">STANDBY</div>
        <div id="trackTitle" class="track-title">Loading Mix Stream...</div>
        <div id="trackArtist" class="track-artist">—</div>

        <div class="time-row">
            <span id="posTime">00:00</span>
            <span id="durTime">--:--</span>
        </div>

        <div class="controls">
            <button onclick="sendAction('previous')">⏮</button>
            <button class="btn-primary" onclick="sendAction('play-pause')">⏯ Play / Pause</button>
            <button onclick="sendAction('next')">⏭</button>
        </div>
    </div>

    <script>
        async function fetchStatus() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();
                document.getElementById('trackTitle').innerText = data.title;
                document.getElementById('trackArtist').innerText = data.artist || 'MPlanetarian';
                document.getElementById('posTime').innerText = data.position;
                document.getElementById('durTime').innerText = data.duration;
                const badge = document.getElementById('playBadge');
                badge.innerText = data.state.toUpperCase();
                if (data.state === 'playing') {
                    badge.style.background = 'rgba(0, 229, 255, 0.2)';
                    badge.style.color = '#00e5ff';
                } else {
                    badge.style.background = 'rgba(255, 170, 0, 0.2)';
                    badge.style.color = '#ffaa00';
                }
            } catch (e) {}
        }
        async function sendAction(act) {
            await fetch('/api/control?action=' + act, { method: 'POST' });
            setTimeout(fetchStatus, 300);
        }
        setInterval(fetchStatus, 2000);
        fetchStatus();
    </script>
</body>
</html>
"""


class CompanionHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/" or url.path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode("utf-8"))
        elif url.path == "/api/status":
            status = get_playback_status()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(status).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/api/control":
            params = urllib.parse.parse_qs(url.query)
            action = params.get("action", [""])[0]
            success = control_player(action)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": success, "action": action}).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass  # Quiet logging


def main():
    parser = argparse.ArgumentParser(description="MP Mix Manager Mobile Web Companion")
    parser.add_argument("--port", "-p", type=int, default=PORT, help=f"Server port (default: {PORT})")
    args = parser.parse_args()

    ip = get_local_ip()
    server_address = ('0.0.0.0', args.port)
    httpd = http.server.ThreadingHTTPServer(server_address, CompanionHandler)

    print(f"\n======================================================================")
    print(f"  🌌 MP MIX ARCHIVE MANAGER — MOBILE WEB COMPANION")
    print(f"======================================================================")
    print(f"  • Local Machine:  http://localhost:{args.port}")
    print(f"  • Phone / Tablet: http://{ip}:{args.port}")
    print(f"======================================================================\n")
    print("Press Ctrl+C to stop the companion server.\n")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Web Companion...")
        httpd.server_close()


if __name__ == "__main__":
    main()
