#!/usr/bin/env python3
import os
import re
import sys
import subprocess

def load_config():
    env_vars = {}
    search_dirs = [
        os.path.dirname(os.path.abspath(__file__)),
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        os.getcwd()
    ]
    for sdir in search_dirs:
        cfg = os.path.join(sdir, "config.env")
        if os.path.isfile(cfg):
            try:
                with open(cfg, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            env_vars[k.strip()] = v.strip().strip('"').strip("'")
                break
            except Exception:
                pass
    return env_vars

cfg = load_config()
mix_archive_dir = os.environ.get("MIX_ARCHIVE_DIR") or cfg.get("MIX_ARCHIVE_DIR")
extra_archives_env = os.environ.get("EXTRA_MIX_ARCHIVE_DIRS") or cfg.get("EXTRA_MIX_ARCHIVE_DIRS")

scan_dirs = []

# Primary mix archive directory
if mix_archive_dir:
    primary_flac = os.path.join(mix_archive_dir, "FLAC_CONVERTED_OUTPUTS")
    if os.path.isdir(primary_flac):
        cand = os.path.abspath(primary_flac)
        scan_dirs.append((f"Primary Archive ({os.path.basename(mix_archive_dir.rstrip('/'))})", cand))
    elif os.path.isdir(mix_archive_dir):
        cand = os.path.abspath(mix_archive_dir)
        scan_dirs.append((f"Primary Archive ({os.path.basename(mix_archive_dir.rstrip('/'))})", cand))
elif os.path.isdir("FLAC_CONVERTED_OUTPUTS"):
    scan_dirs.append(("Primary Archive (Local)", os.path.abspath("FLAC_CONVERTED_OUTPUTS")))

# Extra archives
if extra_archives_env:
    extra_list = []
    for sep in [':', ';', ',']:
        if sep in extra_archives_env:
            extra_list = [x.strip() for x in extra_archives_env.split(sep) if x.strip()]
            break
    if not extra_list and extra_archives_env.strip():
        extra_list = [extra_archives_env.strip()]

    for idx, ed in enumerate(extra_list, 1):
        if not ed:
            continue
        flac_sub = os.path.join(ed, "FLAC_CONVERTED_OUTPUTS")
        if os.path.isdir(flac_sub):
            cand = os.path.abspath(flac_sub)
            if cand not in [p[1] for p in scan_dirs]:
                scan_dirs.append((f"Additional Storage #{idx} ({os.path.basename(ed.rstrip('/'))})", cand))
        elif os.path.isdir(ed):
            cand = os.path.abspath(ed)
            if cand not in [p[1] for p in scan_dirs]:
                scan_dirs.append((f"Additional Storage #{idx} ({os.path.basename(ed.rstrip('/'))})", cand))

if not scan_dirs:
    print("Error: No FLAC archive output directories found.")
    sys.exit(1)

master_html = "master_tracklists.html"

def get_readable_size(size_in_bytes):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_in_bytes < 1024.0:
            return f"{size_in_bytes:.2f} {unit}"
        size_in_bytes /= 1024.0
    return f"{size_in_bytes:.2f} TB"

def get_flac_duration(filepath):
    try:
        cmd = ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', filepath]
        output = subprocess.check_output(cmd, timeout=3).decode().strip()
        return filepath, float(output)
    except Exception:
        return filepath, 0.0

def format_duration(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    return f"{h:02d}:{m:02d}:{s:02d}"

def format_total_duration(seconds):
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    return f"{h}h {m}m {s}s"

print(f"Scanning {len(scan_dirs)} archive storage location(s)...")
for label, path in scan_dirs:
    print(f"  • {label}: {path}")

# Pre-fetch all FLAC durations in parallel
all_flac_paths = []
for _, dpath in scan_dirs:
    for f in os.listdir(dpath):
        if f.lower().endswith(".flac"):
            all_flac_paths.append(os.path.join(dpath, f))

print(f"Analyzing {len(all_flac_paths)} FLAC files across all archives in parallel...")
import concurrent.futures
duration_map = {}
with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
    for fpath, dur in executor.map(get_flac_duration, all_flac_paths):
        duration_map[fpath] = dur

mix_entries = []
seen_mix_bases = {}

for arch_label, dir_path in scan_dirs:
    flac_files = [f for f in os.listdir(dir_path) if f.lower().endswith(".flac")]
    print(f"Processing metadata for {len(flac_files)} mixes in {arch_label}...")

    for flac_name in flac_files:
        flac_base = os.path.splitext(flac_name)[0]
        txt_name = f"{flac_base}.txt"
        txt_path = os.path.join(dir_path, txt_name)

        # Deduplicate if duplicate filename exists across archives
        if flac_base in seen_mix_bases:
            if os.path.exists(txt_path) and not seen_mix_bases[flac_base].get("has_tracklist"):
                pass
            else:
                continue

        # Get FLAC file size & duration
        flac_path = os.path.join(dir_path, flac_name)
        flac_size = os.path.getsize(flac_path) if os.path.exists(flac_path) else 0
        duration_seconds = duration_map.get(flac_path, 0.0)

        # Extract Show ID Number
        show_match = re.search(r'(?:Frequency|Mix|SOF)[_ -]+(\d{3})', flac_base, re.IGNORECASE)
        if not show_match:
            show_match = re.search(r'(\d{3})', flac_base)

        show_id = show_match.group(1) if show_match else "Unknown"

        # Extract Date from filename metadata
        date_match = re.search(r'(20\d{2}-\d{2}-\d{2})', flac_base)
        if not date_match:
            date_match = re.search(r'(20\d{2}_\d{2}_\d{2})', flac_base)
        if not date_match:
            date_match = re.search(r'(20\d{2}-\d{2})', flac_base)
        if not date_match:
            date_match = re.search(r'(20\d{2})', flac_base)

        rec_date = date_match.group(1).replace("_", "-") if date_match else "Unknown"

        # Read and parse tracklist from TXT
        tracks = []
        has_txt = os.path.exists(txt_path)
        if has_txt:
            with open(txt_path, "r", encoding="utf-8", errors="ignore") as f:
                in_tracklist = False
                for line in f:
                    line_str = line.strip()
                    if "TRACKLIST" in line_str.upper() or "TRACK LIST" in line_str.upper():
                        in_tracklist = True
                        continue

                    if in_tracklist or re.match(r'^\d+[\.\-]', line_str):
                        if re.match(r'^\d+', line_str):
                            tracks.append(line_str)

            if not tracks:
                with open(txt_path, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line_str = line.strip()
                        if re.match(r'^\d+[\.\-]', line_str):
                            tracks.append(line_str)

        tracks = [re.sub(r'\s+', ' ', t) for t in tracks if t]

        entry = {
            "show_id": show_id,
            "rec_date": rec_date,
            "flac_name": flac_name,
            "flac_base": flac_base,
            "flac_size_bytes": flac_size,
            "flac_size_readable": get_readable_size(flac_size),
            "duration_seconds": duration_seconds,
            "duration_readable": format_duration(duration_seconds),
            "tracks": tracks,
            "has_tracklist": has_txt and len(tracks) > 0,
            "archive_label": arch_label,
            "dir_path": dir_path
        }
        mix_entries.append(entry)
        seen_mix_bases[flac_base] = entry

# Sort entries by Show ID (numeric sort if possible, fallback to string)
def get_sort_key(entry):
    sid = entry["show_id"]
    try:
        return (0, int(sid))
    except ValueError:
        return (1, sid)

mix_entries.sort(key=get_sort_key)

# Calculate aggregate statistics
total_mixes = len(mix_entries)
total_with_tracklists = sum(1 for m in mix_entries if m["tracks"])
total_size_bytes = sum(m["flac_size_bytes"] for m in mix_entries)
total_tracks_played = sum(len(m["tracks"]) for m in mix_entries)
total_duration_seconds = sum(m["duration_seconds"] for m in mix_entries)

total_size_readable = get_readable_size(total_size_bytes)
total_duration_readable = format_total_duration(total_duration_seconds)

# Generate HTML file
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
                <div class="stat-val">{total_size_readable}</div>
                <div class="stat-lbl">Combined Size</div>
            </div>
            <div class="stat-item">
                <div class="stat-val">{total_tracks_played}</div>
                <div class="stat-lbl">Total Tracks Played</div>
            </div>
            <div class="stat-item">
                <div class="stat-val">{total_duration_readable}</div>
                <div class="stat-lbl">Total Mixing Duration</div>
            </div>
        </div>
"""

for mix in mix_entries:
    html_content += f"""
        <div class="mix-card">
            <div class="mix-heading">
                Stream of Frequency - {mix['show_id']} - {mix['flac_name']} ({mix['flac_size_readable']})
                <span class="badge-arch">{mix['archive_label']}</span>
            </div>
            <ol class="track-list">
"""
    for track in mix['tracks']:
        cleaned_track = re.sub(r'^\d+[\.\-]\s*', '', track)
        html_content += f'                <li class="track-item">{cleaned_track}</li>\n'

    if not mix['tracks']:
        html_content += '                <li class="track-item" style="list-style-type: none; color: #ff5252;">No tracklist parsed</li>\n'

    html_content += f"""            </ol>
            <div class="mix-metadata">
                <div class="meta-line"><span class="meta-label">Storage Archive:</span> <span style="color: #69f0ae;">{mix['archive_label']}</span> ({mix['dir_path']})</div>
                <div class="meta-line"><span class="meta-label">Recording Date:</span> {mix['rec_date']}</div>
                <div class="meta-line"><span class="meta-label">Duration:</span> {mix['duration_readable']}</div>
                <div class="meta-line"><span class="meta-label">Local Filename:</span> {mix['flac_name']}</div>
            </div>
        </div>
"""

html_content += """
    </div>
</body>
</html>
"""

with open(master_html, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"\nSuccessfully generated master tracklist HTML with {len(mix_entries)} entries across {len(scan_dirs)} archives at: {master_html}")
