#!/usr/bin/env python3
"""Build master_tracklists.html from every configured mix archive.

Cloud archives mounted with rclone are not read through the FUSE mount.
A content read on that mount can sit forever in uninterruptible sleep.
Cached copies under ~/.cache/rclone/vfs are used instead, and anything
still missing is fetched with `rclone cat`, which can time out.
"""
import html
import json
import os
import re
import signal
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

try:
    sys.stdout.reconfigure(line_buffering=True)
except Exception:
    pass


def log(message):
    print(message, flush=True)


def load_config():
    env_vars = {}
    search_dirs = [
        os.path.dirname(os.path.abspath(__file__)),
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        os.getcwd(),
    ]
    for sdir in search_dirs:
        cfg = os.path.join(sdir, "config.env")
        if os.path.isfile(cfg):
            try:
                with open(cfg, "r", encoding="utf-8", errors="ignore") as handle:
                    for line in handle:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            key, value = line.split("=", 1)
                            env_vars[key.strip()] = value.strip().strip('"').strip("'")
                break
            except OSError:
                pass
    return env_vars


def unescape_mount_path(path):
    return (
        path.replace("\\040", " ")
        .replace("\\011", "\t")
        .replace("\\012", "\n")
        .replace("\\134", "\\")
    )


def rclone_mounts():
    mounts = []
    try:
        with open("/proc/mounts", "r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                parts = line.split()
                if len(parts) < 3 or "rclone" not in parts[2]:
                    continue
                remote = parts[0].split("{", 1)[0].rstrip(":")
                target = os.path.realpath(unescape_mount_path(parts[1]))
                if remote and os.path.isdir(target):
                    mounts.append((target, remote))
    except OSError:
        pass
    mounts.sort(key=lambda item: len(item[0]), reverse=True)
    return mounts


def rclone_location(path, mounts):
    real = os.path.realpath(path)
    for mount, remote in mounts:
        if real == mount or real.startswith(mount + os.sep):
            rel = os.path.relpath(real, mount).replace(os.sep, "/")
            if rel == ".":
                rel = ""
            return remote, rel
    return None


def cache_file(remote, rel_dir, name):
    bases = []
    xdg = os.environ.get("XDG_CACHE_HOME", "")
    if xdg:
        bases.append(xdg)
    bases.append(os.path.expanduser("~/.cache"))
    rel = "/".join(part for part in (rel_dir, name) if part)
    seen = set()
    for base in bases:
        root = os.path.join(base, "rclone", "vfs", remote, rel)
        if root in seen:
            continue
        seen.add(root)
        if os.path.isfile(root) and os.path.getsize(root) > 0:
            return root
    return None


def run_cmd(cmd, timeout):
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        out, err = proc.communicate(timeout=timeout)
        return proc.returncode, out, err
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            proc.kill()
        proc.communicate()
        return 124, b"", b"timeout"


def rclone_lsjson(remote, rel_dir):
    spec = f"{remote}:{rel_dir}" if rel_dir else f"{remote}:"
    code, out, err = run_cmd(
        ["rclone", "lsjson", spec, "--files-only", "--max-depth", "1"],
        timeout=180,
    )
    if code != 0 or not out:
        detail = err.decode("utf-8", errors="ignore").strip().splitlines()
        detail = [line for line in detail if "NOTICE:" not in line]
        raise RuntimeError(detail[-1] if detail else f"rclone lsjson failed ({code})")
    data = json.loads(out.decode("utf-8", errors="ignore") or "[]")
    files = {}
    for item in data:
        name = item.get("Name") or os.path.basename(item.get("Path") or "")
        if name:
            files[name] = int(item.get("Size") or 0)
    return files


def rclone_cat(remote, rel_dir, name, head=None, timeout=20):
    rel = "/".join(part for part in (rel_dir, name) if part)
    cmd = ["rclone", "cat"]
    if head:
        cmd.extend(["--head", str(head)])
    cmd.append(f"{remote}:{rel}")
    code, out, _err = run_cmd(cmd, timeout=timeout)
    if code != 0:
        return b""
    return out


def flac_duration_from_header(data):
    if len(data) < 42 or data[:4] != b"fLaC":
        return 0.0
    if (data[4] & 0x7F) != 0:
        return 0.0
    length = int.from_bytes(data[5:8], "big")
    if length < 34 or len(data) < 42:
        return 0.0
    info = data[8:42]
    bits = int.from_bytes(info[10:18], "big")
    sample_rate = bits >> 44
    total_samples = bits & ((1 << 36) - 1)
    if sample_rate <= 0 or total_samples <= 0:
        return 0.0
    return total_samples / float(sample_rate)


def read_local_prefix(path, size=128):
    try:
        with open(path, "rb") as handle:
            return handle.read(size)
    except OSError:
        return b""


def read_local_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as handle:
            return handle.read()
    except OSError:
        return ""


def parse_tracks(text):
    tracks = []
    in_tracklist = False
    for line in text.splitlines():
        line_str = line.strip()
        if "TRACKLIST" in line_str.upper() or "TRACK LIST" in line_str.upper():
            in_tracklist = True
            continue
        if in_tracklist or re.match(r"^\d+[\.\-]", line_str):
            if re.match(r"^\d+", line_str):
                tracks.append(line_str)
    if not tracks:
        for line in text.splitlines():
            line_str = line.strip()
            if re.match(r"^\d+[\.\-]", line_str):
                tracks.append(line_str)
    return [re.sub(r"\s+", " ", track) for track in tracks if track]


def get_readable_size(size_in_bytes):
    size = float(size_in_bytes)
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024.0:
            return f"{size:.2f} {unit}"
        size /= 1024.0
    return f"{size:.2f} TB"


def format_duration(seconds):
    seconds = int(seconds)
    hours, rem = divmod(seconds, 3600)
    minutes, secs = divmod(rem, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def format_total_duration(seconds):
    seconds = int(seconds)
    hours, rem = divmod(seconds, 3600)
    minutes, secs = divmod(rem, 60)
    return f"{hours}h {minutes}m {secs}s"


def local_names_and_sizes(dir_path):
    files = {}
    with os.scandir(dir_path) as entries:
        for entry in entries:
            try:
                if not entry.is_file(follow_symlinks=False):
                    continue
                files[entry.name] = entry.stat(follow_symlinks=False).st_size
            except OSError:
                continue
    return files


def cloud_names_and_sizes(dir_path, remote, rel_dir):
    log(f"  Listing {remote}:{rel_dir or '/'} without opening the Drive mount...")
    try:
        return rclone_lsjson(remote, rel_dir), "rclone"
    except (OSError, json.JSONDecodeError, RuntimeError) as exc:
        log(f"  rclone listing failed ({exc}). Using the cached directory names only.")
        names = {}
        try:
            for name in os.listdir(dir_path):
                names[name] = 0
        except OSError as list_exc:
            log(f"  Could not list {dir_path}: {list_exc}")
        return names, "names"


def collect_local_mix(dir_path, flac_name, size):
    flac_path = os.path.join(dir_path, flac_name)
    base = os.path.splitext(flac_name)[0]
    txt_path = os.path.join(dir_path, base + ".txt")
    text = read_local_text(txt_path) if os.path.isfile(txt_path) else ""
    duration = flac_duration_from_header(read_local_prefix(flac_path))
    return text, duration, size


def collect_cloud_mix(remote, rel_dir, flac_name, size, names):
    base = os.path.splitext(flac_name)[0]
    txt_name = base + ".txt"
    text = ""
    if txt_name in names:
        cached_txt = cache_file(remote, rel_dir, txt_name)
        if cached_txt:
            text = read_local_text(cached_txt)
        else:
            text = rclone_cat(remote, rel_dir, txt_name, timeout=20).decode("utf-8", errors="ignore")

    duration = 0.0
    cached_flac = cache_file(remote, rel_dir, flac_name)
    if cached_flac:
        duration = flac_duration_from_header(read_local_prefix(cached_flac))
    if duration <= 0:
        header = rclone_cat(remote, rel_dir, flac_name, head=128, timeout=20)
        duration = flac_duration_from_header(header)
    return text, duration, size


def build_entry(arch_label, dir_path, flac_name, text, duration, size):
    flac_base = os.path.splitext(flac_name)[0]
    show_match = re.search(r"(?:Frequency|Mix|SOF)[_ -]+(\d{3})", flac_base, re.IGNORECASE)
    if not show_match:
        show_match = re.search(r"(\d{3})", flac_base)
    show_id = show_match.group(1) if show_match else "Unknown"

    date_match = re.search(r"(20\d{2}-\d{2}-\d{2})", flac_base)
    if not date_match:
        date_match = re.search(r"(20\d{2}_\d{2}_\d{2})", flac_base)
    if not date_match:
        date_match = re.search(r"(20\d{2}-\d{2})", flac_base)
    if not date_match:
        date_match = re.search(r"(20\d{2})", flac_base)
    rec_date = date_match.group(1).replace("_", "-") if date_match else "Unknown"

    tracks = parse_tracks(text)
    return {
        "show_id": show_id,
        "rec_date": rec_date,
        "flac_name": flac_name,
        "flac_base": flac_base,
        "flac_size_bytes": size,
        "flac_size_readable": get_readable_size(size),
        "duration_seconds": duration,
        "duration_readable": format_duration(duration),
        "tracks": tracks,
        "has_tracklist": bool(tracks),
        "archive_label": arch_label,
        "dir_path": dir_path,
    }


def remember_entry(mix_entries, seen_mix_bases, entry):
    previous = seen_mix_bases.get(entry["flac_base"])
    if previous is None:
        mix_entries.append(entry)
        seen_mix_bases[entry["flac_base"]] = entry
        return
    if previous.get("has_tracklist") or not entry.get("has_tracklist"):
        return
    previous.clear()
    previous.update(entry)


def process_archive(arch_label, dir_path, mounts):
    located = rclone_location(dir_path, mounts)
    if located:
        remote, rel_dir = located
        log(f"Processing {arch_label} via rclone cache/API (Drive mount reads are skipped)...")
        names, _source = cloud_names_and_sizes(dir_path, remote, rel_dir)
        flacs = sorted(name for name in names if name.lower().endswith(".flac"))
        log(f"  {len(flacs)} FLAC mixes. Reading tracklists and durations...")
        results = []
        done = 0

        def one(name):
            return name, collect_cloud_mix(remote, rel_dir, name, names.get(name, 0), names)

        with ThreadPoolExecutor(max_workers=4) as pool:
            futures = [pool.submit(one, name) for name in flacs]
            for future in as_completed(futures):
                results.append(future.result())
                done += 1
                if done == len(flacs) or done % 25 == 0:
                    log(f"  {done}/{len(flacs)} mixes read in {arch_label}")
        results.sort(key=lambda item: item[0].lower())
        return [build_entry(arch_label, dir_path, name, text, duration, size) for name, (text, duration, size) in results]

    log(f"Processing metadata for local archive {arch_label}...")
    names = local_names_and_sizes(dir_path)
    flacs = sorted(name for name in names if name.lower().endswith(".flac"))
    log(f"  {len(flacs)} FLAC mixes.")
    entries = []
    for index, name in enumerate(flacs, 1):
        text, duration, size = collect_local_mix(dir_path, name, names.get(name, 0))
        entries.append(build_entry(arch_label, dir_path, name, text, duration, size))
        if index == len(flacs) or index % 50 == 0:
            log(f"  {index}/{len(flacs)} mixes read in {arch_label}")
    return entries


def discover_archives(cfg):
    mix_archive_dir = os.environ.get("MIX_ARCHIVE_DIR") or cfg.get("MIX_ARCHIVE_DIR")
    extra_archives_env = os.environ.get("EXTRA_MIX_ARCHIVE_DIRS") or cfg.get("EXTRA_MIX_ARCHIVE_DIRS")
    scan_dirs = []

    if mix_archive_dir:
        primary_flac = os.path.join(mix_archive_dir, "FLAC_CONVERTED_OUTPUTS")
        if os.path.isdir(primary_flac):
            label = os.path.basename(mix_archive_dir.rstrip("/"))
            scan_dirs.append((f"Primary Archive ({label})", os.path.abspath(primary_flac)))
        elif os.path.isdir(mix_archive_dir):
            label = os.path.basename(mix_archive_dir.rstrip("/"))
            scan_dirs.append((f"Primary Archive ({label})", os.path.abspath(mix_archive_dir)))
    elif os.path.isdir("FLAC_CONVERTED_OUTPUTS"):
        scan_dirs.append(("Primary Archive (Local)", os.path.abspath("FLAC_CONVERTED_OUTPUTS")))

    extra_list = []
    if extra_archives_env:
        for sep in (":", ";", ","):
            if sep in extra_archives_env:
                extra_list = [item.strip() for item in extra_archives_env.split(sep) if item.strip()]
                break
        if not extra_list and extra_archives_env.strip():
            extra_list = [extra_archives_env.strip()]

    for index, extra_dir in enumerate(extra_list, 1):
        flac_sub = os.path.join(extra_dir, "FLAC_CONVERTED_OUTPUTS")
        if os.path.isdir(flac_sub):
            cand = os.path.abspath(flac_sub)
            label_src = extra_dir
        elif os.path.isdir(extra_dir):
            cand = os.path.abspath(extra_dir)
            label_src = extra_dir
        else:
            continue
        if cand in [path for _label, path in scan_dirs]:
            continue
        label = os.path.basename(label_src.rstrip("/"))
        scan_dirs.append((f"Additional Storage #{index} ({label})", cand))
    return scan_dirs


def main():
    cfg = load_config()
    scan_dirs = discover_archives(cfg)
    if not scan_dirs:
        log("Error: No FLAC archive output directories found.")
        return 1

    mounts = rclone_mounts()
    log(f"Scanning {len(scan_dirs)} archive storage location(s)...")
    for label, path in scan_dirs:
        located = rclone_location(path, mounts)
        kind = f"rclone:{located[0]}" if located else "local disk"
        log(f"  • {label}: {path} [{kind}]")

    mix_entries = []
    seen_mix_bases = {}
    for arch_label, dir_path in scan_dirs:
        for entry in process_archive(arch_label, dir_path, mounts):
            remember_entry(mix_entries, seen_mix_bases, entry)

    def sort_key(entry):
        try:
            return (0, int(entry["show_id"]))
        except ValueError:
            return (1, entry["show_id"])

    mix_entries.sort(key=sort_key)

    total_mixes = len(mix_entries)
    total_with_tracklists = sum(1 for mix in mix_entries if mix["tracks"])
    total_size_bytes = sum(mix["flac_size_bytes"] for mix in mix_entries)
    total_tracks_played = sum(len(mix["tracks"]) for mix in mix_entries)
    total_duration_seconds = sum(mix["duration_seconds"] for mix in mix_entries)
    total_size_readable = get_readable_size(total_size_bytes)
    total_duration_readable = format_total_duration(total_duration_seconds)

    html_content = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>MPlanetarian - Stream of Frequency Master Archive Index</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background-color: #121212;
            color: #e0e0e0;
            line-height: 1.6;
            margin: 0;
            padding: 40px 20px;
        }}
        .container {{
            max-width: 900px;
            margin: 0 auto;
        }}
        h1 {{
            text-align: center;
            color: #ff007f;
            border-bottom: 2px solid #ff007f;
            padding-bottom: 15px;
            margin-bottom: 30px;
        }}
        .stats-box {{
            background: linear-gradient(135deg, #1f1c2c, #928dab);
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 40px;
            border: 1px solid #444;
            box-shadow: 0 4px 10px rgba(0,0,0,0.5);
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
        }}
        .stat-item {{
            text-align: center;
            padding: 10px 15px;
            min-width: 140px;
        }}
        .stat-val {{
            font-size: 1.6em;
            font-weight: bold;
            color: #00e5ff;
            margin-bottom: 5px;
        }}
        .stat-lbl {{
            font-size: 0.85em;
            color: #cfd8dc;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}
        .mix-card {{
            background-color: #1e1e1e;
            border: 1px solid #333;
            border-radius: 8px;
            padding: 25px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
        }}
        .mix-heading {{
            font-size: 1.3em;
            color: #00e5ff;
            margin-top: 0;
            margin-bottom: 15px;
            border-bottom: 1px solid #444;
            padding-bottom: 8px;
            word-break: break-all;
        }}
        .badge-arch {{
            display: inline-block;
            background: rgba(0, 229, 255, 0.15);
            color: #69f0ae;
            font-size: 0.75em;
            padding: 2px 8px;
            border-radius: 4px;
            margin-left: 10px;
            vertical-align: middle;
            border: 1px solid rgba(105, 240, 174, 0.3);
        }}
        .track-list {{
            margin: 0;
            padding-left: 20px;
        }}
        .track-item {{
            margin-bottom: 6px;
            color: #cfd8dc;
        }}
        .mix-metadata {{
            margin-top: 20px;
            padding-top: 10px;
            border-top: 1px dashed #444;
            font-size: 0.9em;
            color: #90a4ae;
        }}
        .meta-line {{
            margin: 4px 0;
        }}
        .meta-label {{
            font-weight: bold;
            color: #b0bec5;
        }}
    </style>
</head>
<body>
    <div class="container">
        <h1>MPlanetarian - Stream of Frequency Tracklistings</h1>

        <div class="stats-box">
            <div class="stat-item">
                <div class="stat-val">{total_mixes}</div>
                <div class="stat-lbl">Total Mixes</div>
            </div>
            <div class="stat-item">
                <div class="stat-val">{total_with_tracklists}</div>
                <div class="stat-lbl">Verified Tracklists</div>
            </div>
            <div class="stat-item">
                <div class="stat-val">{html.escape(total_size_readable)}</div>
                <div class="stat-lbl">Combined Size</div>
            </div>
            <div class="stat-item">
                <div class="stat-val">{total_tracks_played}</div>
                <div class="stat-lbl">Total Tracks Played</div>
            </div>
            <div class="stat-item">
                <div class="stat-val">{html.escape(total_duration_readable)}</div>
                <div class="stat-lbl">Total Mixing Duration</div>
            </div>
        </div>
"""

    for mix in mix_entries:
        html_content += f"""
        <div class="mix-card">
            <div class="mix-heading">
                Stream of Frequency - {html.escape(mix['show_id'])} - {html.escape(mix['flac_name'])} ({html.escape(mix['flac_size_readable'])})
                <span class="badge-arch">{html.escape(mix['archive_label'])}</span>
            </div>
            <ol class="track-list">
"""
        for track in mix["tracks"]:
            cleaned = re.sub(r"^\d+[\.\-]\s*", "", track)
            html_content += f'                <li class="track-item">{html.escape(cleaned)}</li>\n'
        if not mix["tracks"]:
            html_content += '                <li class="track-item" style="list-style-type: none; color: #ff5252;">No tracklist parsed</li>\n'
        html_content += f"""            </ol>
            <div class="mix-metadata">
                <div class="meta-line"><span class="meta-label">Storage Archive:</span> <span style="color: #69f0ae;">{html.escape(mix['archive_label'])}</span> ({html.escape(mix['dir_path'])})</div>
                <div class="meta-line"><span class="meta-label">Recording Date:</span> {html.escape(mix['rec_date'])}</div>
                <div class="meta-line"><span class="meta-label">Duration:</span> {html.escape(mix['duration_readable'])}</div>
                <div class="meta-line"><span class="meta-label">Local Filename:</span> {html.escape(mix['flac_name'])}</div>
            </div>
        </div>
"""

    html_content += """
    </div>
</body>
</html>
"""

    master_html = "master_tracklists.html"
    with open(master_html, "w", encoding="utf-8") as handle:
        handle.write(html_content)
    log(f"\nSuccessfully generated master tracklist HTML with {len(mix_entries)} entries across {len(scan_dirs)} archives at: {os.path.abspath(master_html)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
