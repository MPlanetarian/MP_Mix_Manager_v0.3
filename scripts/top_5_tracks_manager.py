#!/usr/bin/env python3
"""
scripts/top_5_tracks_manager.py - Mix Archive Manager: Top 5 Tracks Suite & Traktor Dispatch
Features:
1. Parse master_tracklists.html across all mix archives.
2. Select & manage user's Top 5 Tracks of all time.
3. Search Traktor database (collection.nml or History/*.nml) by audio ID / title / artist.
4. Remote audio import from Mac / network via SMB, NFS, SSH/rsync, or local storage into TOP_5_TRACKS/.
5. Generate M3U8, M3U, and XSPF playlists and immediately trigger playback of Track 1.
6. Export joined continuous mix into:
   - Mix_Archive_Top_5_Tracks_[YYYY-MM-DD]_Auto_Generated_by_MP_Mix.FLAC
   - Matching WAV and 320kbps MP3
   - Embedded cover art & metadata tags
   - Lossless Spek spectrogram PNG
   - Detailed timestamped Tracklist (.txt) & Cue sheet (.cue)
7. Check prerequisites and manage custom menu status ([Unlock Mystery] vs [Ready]).
"""

import os
import sys
import re
import json
import glob
import time
import shutil
import datetime
import subprocess
import xml.etree.ElementTree as ET

# ANSI Colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"

SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOP5_STATE_FILE = os.path.join(SCRIPT_DIR, "top_5_tracks.json")
TOP5_AUDIO_DIR = os.path.join(SCRIPT_DIR, "TOP_5_TRACKS")
PLAYLISTS_DIR = os.path.join(SCRIPT_DIR, "PLAYLISTS_GENERATED")


def load_config():
    """Load settings from config.env if available."""
    cfg = {}
    search_dirs = [
        SCRIPT_DIR,
        os.path.join(SCRIPT_DIR, "scripts"),
        os.getcwd()
    ]
    for sdir in search_dirs:
        env_file = os.path.join(sdir, "config.env")
        if os.path.isfile(env_file):
            try:
                with open(env_file, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            cfg[k.strip()] = v.strip().strip('"').strip("'")
                break
            except Exception:
                pass
    return cfg


def save_config_key(key, value):
    """Save or update a key in config.env."""
    env_file = os.path.join(SCRIPT_DIR, "config.env")
    lines = []
    found = False
    if os.path.isfile(env_file):
        with open(env_file, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()

    new_lines = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith(f"{key}=") or stripped.startswith(f"export {key}="):
            new_lines.append(f'{key}="{value}"\n')
            found = True
        else:
            new_lines.append(line)

    if not found:
        if new_lines and not new_lines[-1].endswith("\n"):
            new_lines.append("\n")
        new_lines.append(f'{key}="{value}"\n')

    with open(env_file, "w", encoding="utf-8") as f:
        f.writelines(new_lines)


def get_master_html_path():
    """Find master_tracklists.html in script dir or mix archive."""
    p1 = os.path.join(SCRIPT_DIR, "master_tracklists.html")
    if os.path.isfile(p1):
        return p1
    cfg = load_config()
    mix_dir = cfg.get("MIX_ARCHIVE_DIR", "")
    if mix_dir and os.path.isdir(mix_dir):
        p2 = os.path.join(mix_dir, "master_tracklists.html")
        if os.path.isfile(p2):
            return p2
    return None


def has_processed_mix():
    """Check if at least one mix has been recorded/processed with the Manager."""
    cfg = load_config()
    # Check marker
    marker = os.path.join(SCRIPT_DIR, ".first_mix_processed")
    if os.path.isfile(marker):
        return True

    # Check FLAC_CONVERTED_OUTPUTS
    candidates = [
        os.path.join(SCRIPT_DIR, "FLAC_CONVERTED_OUTPUTS"),
    ]
    mix_dir = cfg.get("MIX_ARCHIVE_DIR", "")
    if mix_dir and os.path.isdir(mix_dir):
        candidates.append(os.path.join(mix_dir, "FLAC_CONVERTED_OUTPUTS"))
        candidates.append(mix_dir)

    extra_dirs = cfg.get("EXTRA_MIX_ARCHIVE_DIRS", "")
    if extra_dirs:
        for ed in re.split(r"[:;,]", extra_dirs):
            ed = ed.strip()
            if ed and os.path.isdir(ed):
                candidates.append(ed)
                candidates.append(os.path.join(ed, "FLAC_CONVERTED_OUTPUTS"))

    for c in candidates:
        if os.path.isdir(c):
            flacs = glob.glob(os.path.join(c, "*.flac")) + glob.glob(os.path.join(c, "*.FLAC"))
            if flacs:
                return True
    return False


def check_prerequisites():
    """
    Returns (status, reasons) where status is 'READY' or 'LOCKED'.
    Prerequisites:
    1. Master HTML Tracklist file must exist.
    2. At least one mix must be recorded & processed.
    """
    html_path = get_master_html_path()
    processed = has_processed_mix()

    reasons = []
    if not html_path:
        reasons.append("Master HTML Tracklist (master_tracklists.html) has not been generated.")
    if not processed:
        reasons.append("No recorded mix has been processed yet with the Manager (FLAC conversion).")

    if not reasons:
        return "READY", []
    else:
        return "LOCKED", reasons


def parse_master_html():
    """
    Parse master_tracklists.html and extract all tracks with their mix source.
    Returns list of dicts: [{'artist': ..., 'title': ..., 'full_text': ..., 'mix': ...}, ...]
    """
    html_path = get_master_html_path()
    if not html_path or not os.path.isfile(html_path):
        return []

    try:
        with open(html_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception as e:
        print(f"{RED}Error reading {html_path}: {e}{NC}")
        return []

    cards = re.findall(r'<div class="mix-card">(.*?)</div>\s*</div>', content, re.DOTALL)
    track_list = []
    seen = set()

    for card in cards:
        h_match = re.search(r'<div class="mix-heading">(.*?)</div>', card, re.DOTALL)
        mix_heading = "Unknown Mix"
        if h_match:
            mix_heading = re.sub(r'<[^>]+>', '', h_match.group(1)).strip()

        track_items = re.findall(r'<li class="track-item">(.*?)</li>', card)
        for item in track_items:
            item = item.strip()
            if not item or item == "No tracklist parsed":
                continue

            cleaned = re.sub(r'<[^>]+>', '', item).strip()
            if not cleaned or cleaned in seen:
                continue
            seen.add(cleaned)

            # Split Artist - Title
            if " - " in cleaned:
                parts = cleaned.split(" - ", 1)
                artist = parts[0].strip()
                title = parts[1].strip()
            else:
                artist = "Unknown Artist"
                title = cleaned

            track_list.append({
                "artist": artist,
                "title": title,
                "full_text": cleaned,
                "mix": mix_heading
            })

    return track_list


def load_top_5_state():
    """Load existing Top 5 tracks from JSON file."""
    if os.path.isfile(TOP5_STATE_FILE):
        try:
            with open(TOP5_STATE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"tracks": [], "last_updated": ""}


def save_top_5_state(state):
    """Save Top 5 tracks to JSON file."""
    state["last_updated"] = datetime.datetime.now().isoformat()
    with open(TOP5_STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)


def display_top_5():
    """Print the user's currently selected Top 5 tracks."""
    state = load_top_5_state()
    tracks = state.get("tracks", [])
    print(f"\n{BOLD}{CYAN}═══════════════════════════════════════════════════════════════════════════════════{NC}")
    print(f"{BOLD}{MAGENTA}      ★ YOUR PRE-SELECTED TOP 5 TRACKS OF ALL TIME (MIX ARCHIVES) ★      {NC}")
    print(f"{BOLD}{CYAN}═══════════════════════════════════════════════════════════════════════════════════{NC}")

    if not tracks:
        print(f"  {YELLOW}No Top 5 Tracks selected yet.{NC}")
        print(f"  {DIM}Use option 'Select / Change Top 5 Tracks' to pick them from your Master HTML Tracklist.{NC}")
    else:
        for i, t in enumerate(tracks, start=1):
            audio_status = f"{GREEN}✓ Ready{NC}" if t.get("audio_path") and os.path.isfile(t.get("audio_path")) else f"{YELLOW}Pending Traktor Import{NC}"
            print(f"  {BOLD}{CYAN}[Track #{i}]{NC} {BOLD}{GREEN}{t.get('artist')}{NC} - {BOLD}{t.get('title')}{NC}")
            print(f"            {DIM}Mix Source:{NC} {t.get('mix_source', 'Unknown')}")
            if t.get("traktor_audio_id"):
                print(f"            {DIM}Traktor ID:{NC} {t.get('traktor_audio_id')[:32]}...")
            print(f"            {DIM}Audio Status:{NC} {audio_status}")
            if t.get("audio_path") and os.path.isfile(t.get("audio_path")):
                print(f"            {DIM}Local File:{NC} {t.get('audio_path')}")
            print(f"  {DIM}─────────────────────────────────────────────────────────────────────────────{NC}")
    print(f"{BOLD}{CYAN}═══════════════════════════════════════════════════════════════════════════════════{NC}\n")


def select_top_5_interactive():
    """Interactive CLI to select 5 tracks from the Master HTML Tracklist."""
    status, reasons = check_prerequisites()
    if status != "READY":
        print(f"\n{BOLD}{RED}⚠️  Feature Locked: Prerequisite requirements not met!{NC}")
        for r in reasons:
            print(f"   • {YELLOW}{r}{NC}")
        input(f"\n{BOLD}Press Enter to return...{NC}")
        return

    all_tracks = parse_master_html()
    if not all_tracks:
        print(f"\n{RED}No tracks found in Master HTML Tracklist! Please regenerate the master tracklist first.{NC}")
        input(f"\n{BOLD}Press Enter to return...{NC}")
        return

    print(f"\n{BOLD}{GREEN}Loaded {len(all_tracks)} verified tracks from Master HTML Tracklist.{NC}")
    print(f"{CYAN}You will now select your Top 5 Tracks of all time.{NC}\n")

    chosen = []
    for rank in range(1, 6):
        while True:
            print(f"\n{BOLD}{YELLOW}--- Selecting Track #{rank} of 5 ---{NC}")
            query = input(f"Search track by Artist, Title or Mix (or 'L' to list first 25, 'q' to cancel): ").strip()
            if query.lower() in ['q', 'quit', 'exit']:
                print(f"{YELLOW}Track selection cancelled.{NC}")
                return

            if query.lower() == 'l':
                matches = all_tracks[:25]
            else:
                q_lower = query.lower()
                matches = [t for t in all_tracks if q_lower in t["full_text"].lower() or q_lower in t["mix"].lower()]

            if not matches:
                print(f"{RED}No matching tracks found for '{query}'. Please try another search.{NC}")
                continue

            print(f"\n{BOLD}Found {len(matches)} matching track(s) (displaying up to 20):{NC}")
            for idx, m in enumerate(matches[:20], start=1):
                print(f"  {BOLD}{CYAN}[{idx}]{NC} {m['artist']} - {m['title']}  {DIM}({m['mix']}){NC}")

            sel = input(f"\nEnter number [1-{min(len(matches), 20)}] to select, or 's' to search again: ").strip()
            if sel.isdigit() and 1 <= int(sel) <= min(len(matches), 20):
                picked = matches[int(sel) - 1]
                chosen.append({
                    "rank": rank,
                    "artist": picked["artist"],
                    "title": picked["title"],
                    "full_text": picked["full_text"],
                    "mix_source": picked["mix"],
                    "traktor_audio_id": "",
                    "audio_path": ""
                })
                print(f"{BOLD}{GREEN}✓ Selected Track #{rank}:{NC} {picked['artist']} - {picked['title']}")
                break
            elif sel.lower() == 's':
                continue
            else:
                print(f"{RED}Invalid choice.{NC}")

    state = {"tracks": chosen}
    save_top_5_state(state)
    print(f"\n{BOLD}{GREEN}🎉 Successfully saved your Top 5 Tracks of all time!{NC}")
    display_top_5()
    input(f"{BOLD}Press Enter to return...{NC}")


def find_traktor_nml_sources():
    """Locate collection.nml and history NML files."""
    cfg = load_config()
    sources = []

    # Configured collection path
    col_path = cfg.get("TRAKTOR_COLLECTION_PATH", "")
    if col_path and os.path.isfile(col_path):
        sources.append(col_path)

    # Configured history directory
    hist_dir = cfg.get("TRAKTOR_HISTORY_DIR", "")
    if hist_dir and os.path.isdir(hist_dir):
        sources.extend(glob.glob(os.path.join(hist_dir, "*.nml")))

    # Standard locations
    std_hist = "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History"
    if os.path.isdir(std_hist):
        for nml in glob.glob(os.path.join(std_hist, "*.nml")):
            if nml not in sources:
                sources.append(nml)

    # User Documents on Linux/Mac
    user_docs = os.path.expanduser("~/Documents/Native Instruments")
    if os.path.isdir(user_docs):
        for root, _, files in os.walk(user_docs):
            for file in files:
                if file.endswith(".nml"):
                    full_p = os.path.join(root, file)
                    if full_p not in sources:
                        sources.append(full_p)

    return sources


def search_traktor_for_track(artist, title, full_text=""):
    """
    Search Traktor NML files for matching entry.
    Returns dict with {audio_id, volume, dir, file, full_path_hint} or None.
    """
    nml_sources = find_traktor_nml_sources()
    if not nml_sources:
        return None

    clean_artist = re.sub(r'[^a-zA-Z0-9]', '', artist).lower()
    clean_title = re.sub(r'[^a-zA-Z0-9]', '', title).lower()

    for nml in nml_sources:
        try:
            tree = ET.parse(nml)
            root = tree.getroot()
            col = root.find("COLLECTION")
            if col is None:
                continue

            for entry in col.findall("ENTRY"):
                e_title = entry.attrib.get("TITLE", "")
                e_artist = entry.attrib.get("ARTIST", "")
                e_audio_id = entry.attrib.get("AUDIO_ID", "")
                loc = entry.find("LOCATION")

                if loc is None:
                    continue

                e_vol = loc.attrib.get("VOLUME", "")
                e_dir = loc.attrib.get("DIR", "")
                e_file = loc.attrib.get("FILE", "")

                c_etitle = re.sub(r'[^a-zA-Z0-9]', '', e_title).lower()
                c_eartist = re.sub(r'[^a-zA-Z0-9]', '', e_artist).lower()

                # Check match (require non-empty strings)
                matched = False
                if clean_title and c_etitle:
                    if clean_title == c_etitle:
                        if not clean_artist or not c_eartist or clean_artist in c_eartist or c_eartist in clean_artist:
                            matched = True
                    elif len(clean_title) >= 4 and len(c_etitle) >= 4:
                        if clean_title in c_etitle or c_etitle in clean_title:
                            if clean_artist and c_eartist:
                                if clean_artist in c_eartist or c_eartist in clean_artist:
                                    matched = True
                            elif not clean_artist:
                                matched = True

                if matched:

                    # Clean directory format /:folder/:subfolder/: -> folder/subfolder/
                    norm_dir = e_dir.replace("/:", "/").rstrip("/")
                    if norm_dir.startswith("/"):
                        norm_dir = norm_dir[1:]

                    return {
                        "audio_id": e_audio_id,
                        "volume": e_vol,
                        "dir": norm_dir,
                        "file": e_file,
                        "nml_source": nml
                    }
        except Exception:
            continue

    return None


def resolve_audio_file(traktor_info, artist, title):
    """
    Attempt to locate the actual physical audio file on local disks, SMB, NFS, or Mac.
    Returns path to local file (or downloaded file in TOP_5_TRACKS), or None.
    """
    cfg = load_config()
    os.makedirs(TOP5_AUDIO_DIR, exist_ok=True)

    dest_stem = f"{artist} - {title}".replace("/", "_").replace("\\", "_")

    # 1. Check if already imported
    for existing in glob.glob(os.path.join(TOP5_AUDIO_DIR, f"*{dest_stem}*")):
        if os.path.isfile(existing) and os.path.getsize(existing) > 1000:
            return existing

    vol = traktor_info.get("volume", "") if traktor_info else ""
    rel_dir = traktor_info.get("dir", "") if traktor_info else ""
    file_name = traktor_info.get("file", "") if traktor_info else ""

    # Potential local search roots
    search_roots = []

    # Configured Audio Root
    cfg_audio = cfg.get("TRAKTOR_AUDIO_ROOT", "")
    if cfg_audio and os.path.isdir(cfg_audio):
        search_roots.append(cfg_audio)

    # Local mounted media
    if vol:
        search_roots.append(f"/run/media/mplanetarian/{vol}")
        search_roots.append(f"/Volumes/{vol}")

    # Standard media drives
    search_roots.extend([
        "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE",
        "/run/media/mplanetarian/WD BLACK B",
        "/run/media/mplanetarian/DATA/MIX_ARCHIVE2",
        "/run/media/mplanetarian/DATA",
        "/run/media/mplanetarian/GAMES1",
        "/run/media/mplanetarian/GAMES2",
        os.path.expanduser("~/Music"),
    ])

    # Check SMB share mount if configured
    smb_mount = cfg.get("TRAKTOR_SMB_MOUNT", "")
    if smb_mount and os.path.isdir(smb_mount):
        search_roots.append(smb_mount)

    # Check NFS mount if configured
    nfs_mount = cfg.get("TRAKTOR_NFS_MOUNT", "")
    if nfs_mount and os.path.isdir(nfs_mount):
        search_roots.append(nfs_mount)

    # Direct match on path
    if rel_dir and file_name:
        for root in search_roots:
            cand = os.path.join(root, rel_dir, file_name)
            if os.path.isfile(cand):
                dest_file = os.path.join(TOP5_AUDIO_DIR, f"{dest_stem}{os.path.splitext(file_name)[1]}")
                shutil.copy2(cand, dest_file)
                return dest_file

    # Search by filename in roots
    if file_name:
        for root in search_roots:
            if not os.path.isdir(root):
                continue
            for r, _, files in os.walk(root):
                if file_name in files:
                    cand = os.path.join(r, file_name)
                    dest_file = os.path.join(TOP5_AUDIO_DIR, f"{dest_stem}{os.path.splitext(file_name)[1]}")
                    shutil.copy2(cand, dest_file)
                    return dest_file

    # Remote Mac transfer via SSH / rsync if configured
    mac_host = cfg.get("TRAKTOR_MAC_HOST", "")
    mac_user = cfg.get("TRAKTOR_MAC_USER", "")
    if mac_host and mac_user and file_name:
        print(f"  {YELLOW}Attempting remote transfer from Mac ({mac_user}@{mac_host})...{NC}")
        remote_path = f"/Volumes/{vol}/{rel_dir}/{file_name}"
        dest_file = os.path.join(TOP5_AUDIO_DIR, f"{dest_stem}{os.path.splitext(file_name)[1]}")
        try:
            cmd = ["rsync", "-avz", "--timeout=10", f"{mac_user}@{mac_host}:{remote_path}", dest_file]
            res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if res.returncode == 0 and os.path.isfile(dest_file):
                return dest_file
        except Exception:
            pass

    # Search local archive by title keywords as fallback
    clean_kw = re.sub(r'[^a-zA-Z0-9]', '', title).lower()
    for root in search_roots:
        if not os.path.isdir(root):
            continue
        try:
            for r, _, files in os.walk(root):
                for f in files:
                    ext = os.path.splitext(f)[1].lower()
                    if ext in ['.flac', '.wav', '.mp3', '.aiff', '.m4a']:
                        c_f = re.sub(r'[^a-zA-Z0-9]', '', f).lower()
                        if clean_kw and clean_kw in c_f:
                            cand = os.path.join(r, f)
                            dest_file = os.path.join(TOP5_AUDIO_DIR, f"{dest_stem}{ext}")
                            shutil.copy2(cand, dest_file)
                            return dest_file
        except Exception:
            pass

    return None


def import_top_5_and_playlist():
    """
    Search Traktor DB for each Top 5 track, copy to TOP_5_TRACKS/,
    build M3U8/M3U/XSPF playlists, and immediately start playback of Track 1!
    """
    status, reasons = check_prerequisites()
    if status != "READY":
        print(f"\n{BOLD}{RED}⚠️  Feature Locked: Prerequisite requirements not met!{NC}")
        for r in reasons:
            print(f"   • {YELLOW}{r}{NC}")
        input(f"\n{BOLD}Press Enter to return...{NC}")
        return

    state = load_top_5_state()
    tracks = state.get("tracks", [])
    if len(tracks) < 5:
        print(f"\n{RED}Error: You must select all 5 tracks first (currently {len(tracks)} selected).{NC}")
        input(f"{BOLD}Press Enter to return...{NC}")
        return

    print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}   IMPORTING TOP 5 TRACKS FROM TRAKTOR & GENERATING PLAYLIST          {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}\n")

    os.makedirs(TOP5_AUDIO_DIR, exist_ok=True)
    os.makedirs(PLAYLISTS_DIR, exist_ok=True)

    imported_files = []
    for i, t in enumerate(tracks, start=1):
        print(f"[{i}/5] Processing: {BOLD}{CYAN}{t['artist']} - {t['title']}{NC}")
        # Search Traktor DB
        info = search_traktor_for_track(t["artist"], t["title"], t.get("full_text", ""))
        if info:
            t["traktor_audio_id"] = info.get("audio_id", "")
            print(f"      {GREEN}✓ Found in Traktor:{NC} {info.get('file')} (Volume: {info.get('volume')})")
        else:
            print(f"      {YELLOW}Notice:{NC} Not found in local Traktor History files, checking storage & fallback...")

        # Resolve Audio File
        audio_file = resolve_audio_file(info, t["artist"], t["title"])
        if audio_file and os.path.isfile(audio_file):
            t["audio_path"] = audio_file
            imported_files.append(audio_file)
            print(f"      {BOLD}{GREEN}✓ Local Audio Ready:{NC} {audio_file}")
        else:
            print(f"      {RED}✗ Audio file could not be automatically located.{NC}")
            manual = input("      Enter path to this audio file manually (or Enter to skip): ").strip()
            if manual and os.path.isfile(manual):
                dest_file = os.path.join(TOP5_AUDIO_DIR, f"{t['artist']} - {t['title']}{os.path.splitext(manual)[1]}")
                shutil.copy2(manual, dest_file)
                t["audio_path"] = dest_file
                imported_files.append(dest_file)
                print(f"      {GREEN}✓ Saved manual audio file:{NC} {dest_file}")

    save_top_5_state(state)

    if not imported_files:
        print(f"\n{RED}Error: None of the 5 audio files could be resolved. Please check Traktor configuration.{NC}")
        input(f"{BOLD}Press Enter to return...{NC}")
        return

    # Build Playlists
    m3u8_file = os.path.join(PLAYLISTS_DIR, "Mix_Archive_Top_5_Tracks_Traktor_Playlist.m3u8")
    m3u_file = os.path.join(PLAYLISTS_DIR, "Mix_Archive_Top_5_Tracks_Traktor_Playlist.m3u")
    xspf_file = os.path.join(PLAYLISTS_DIR, "Mix_Archive_Top_5_Tracks_Traktor_Playlist.xspf")

    with open(m3u8_file, "w", encoding="utf-8") as f_m3u8, open(m3u_file, "w", encoding="utf-8") as f_m3u:
        f_m3u8.write("#EXTM3U\n")
        f_m3u.write("#EXTM3U\n")
        for f in imported_files:
            bname = os.path.splitext(os.path.basename(f))[0]
            f_m3u8.write(f"#EXTINF:-1,{bname}\n{f}\n")
            f_m3u.write(f"#EXTINF:-1,{bname}\n{f}\n")

    # XSPF
    with open(xspf_file, "w", encoding="utf-8") as f_xspf:
        f_xspf.write('<?xml version="1.0" encoding="UTF-8"?>\n<playlist version="1" xmlns="http://xspf.org/ns/0/">\n  <title>MPlanetarian Top 5 Tracks of All Time</title>\n  <trackList>\n')
        for f in imported_files:
            f_xspf.write(f'    <track><location>file://{f}</location></track>\n')
        f_xspf.write('  </trackList>\n</playlist>\n')

    print(f"\n{BOLD}{GREEN}✓ Generated Playlists:{NC}")
    print(f"   • {m3u8_file}")
    print(f"   • {m3u_file}")
    print(f"   • {xspf_file}")

    # Immediately start playing Track #1!
    cfg = load_config()
    player = cfg.get("DEFAULT_AUDIO_PLAYER", "audacious")
    first_track = imported_files[0]
    print(f"\n{BOLD}{CYAN}▶ Launching Audio Player ({player}) for Track #1:{NC} {first_track}\n")

    play_audio(player, m3u8_file, first_track)
    input(f"{BOLD}Press Enter to return...{NC}")


def play_audio(player, playlist_file, first_track):
    """Trigger playback in configured audio player."""
    target = playlist_file if os.path.isfile(playlist_file) else first_track
    try:
        if player == "audacious":
            if shutil.which("audacious"):
                subprocess.Popen(["audacious", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                subprocess.Popen(["flatpak", "run", "org.atheme.audacious", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif player == "strawberry":
            if shutil.which("strawberry"):
                subprocess.Popen(["strawberry", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                subprocess.Popen(["flatpak", "run", "org.strawberrymusicplayer.strawberry", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif player == "cliamp":
            cliamp = shutil.which("cliamp") or os.path.expanduser("~/.local/bin/cliamp")
            if os.path.isfile(cliamp) and os.access(cliamp, os.X_OK):
                subprocess.run([cliamp, "queue", target], check=False)
                subprocess.Popen([cliamp, "--auto-play", "play"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif player == "vlc":
            if shutil.which("vlc"):
                subprocess.Popen(["vlc", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                subprocess.Popen(["flatpak", "run", "org.videolan.VLC", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            # Fallback xdg-open
            subprocess.Popen(["xdg-open", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"{RED}Error launching audio player: {e}{NC}")


def get_audio_duration(file_path):
    """Use ffprobe to get audio duration in seconds."""
    try:
        out = subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", file_path
        ], stderr=subprocess.DEVNULL, text=True).strip()
        return float(out)
    except Exception:
        return 0.0


def format_timestamp(seconds):
    """Format seconds into HH:MM:SS."""
    hrs = int(seconds // 3600)
    mins = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    return f"{hrs:02d}:{mins:02d}:{secs:02d}"


def export_top_5_mix():
    """
    Export the 5 Tracks as a joined continuous FLAC mix (+ WAV, MP3, Spek, Tracklist).
    Prompts user for:
    - Artist
    - Title
    - Cover Image
    Auto-names FLAC: Mix_Archive_Top_5_Tracks_[Date]_Auto_Generated_by_MP_Mix.FLAC
    """
    status, reasons = check_prerequisites()
    if status != "READY":
        print(f"\n{BOLD}{RED}⚠️  Feature Locked: Prerequisite requirements not met!{NC}")
        for r in reasons:
            print(f"   • {YELLOW}{r}{NC}")
        input(f"\n{BOLD}Press Enter to return...{NC}")
        return

    state = load_top_5_state()
    tracks = state.get("tracks", [])
    if len(tracks) < 5:
        print(f"\n{RED}Error: You must select and import all 5 tracks first.{NC}")
        input(f"{BOLD}Press Enter to return...{NC}")
        return

    # Check that audio files exist
    audio_files = []
    for t in tracks:
        p = t.get("audio_path", "")
        if not p or not os.path.isfile(p):
            print(f"\n{RED}Error: Track '{t.get('artist')} - {t.get('title')}' audio file is missing!{NC}")
            print(f"{YELLOW}Please run 'Import Your Top 5 Tracks from Traktor Now & Playlist Them' first.{NC}")
            input(f"{BOLD}Press Enter to return...{NC}")
            return
        audio_files.append(p)

    print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}   EXPORT TOP 5 TRACKS CONTINUOUS MIX (FLAC, WAV, MP3, SPEK)         {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}\n")

    # Prompt user for metadata
    default_artist = "MPlanetarian"
    default_title = "Mix Archive Top 5 Tracks of All Time"

    mix_artist = input(f"Enter Mix Artist [{default_artist}]: ").strip() or default_artist
    mix_title = input(f"Enter Mix Title [{default_title}]: ").strip() or default_title

    # Cover Image
    cfg = load_config()
    mix_dir = cfg.get("MIX_ARCHIVE_DIR", "")
    suggested_cover = ""
    for cand in [
        os.path.join(mix_dir, "Cover.png"),
        os.path.join(mix_dir, "Cover.jpg"),
        os.path.join(SCRIPT_DIR, "assets", "MP_Mix_Manager_v0.1_Structure.png")
    ]:
        if os.path.isfile(cand):
            suggested_cover = cand
            break

    cover_prompt = f"Enter Cover Image Path [{suggested_cover}]: " if suggested_cover else "Enter Cover Image Path: "
    cover_path = input(cover_prompt).strip() or suggested_cover

    if not cover_path or not os.path.isfile(cover_path):
        print(f"{YELLOW}Warning: Valid cover image not provided. Proceeding without embedded cover art.{NC}")
        cover_path = None

    date_str = datetime.date.today().strftime("%Y-%m-%d")
    out_dir = cfg.get("MIX_ARCHIVE_DIR", SCRIPT_DIR)
    if os.path.isdir(os.path.join(out_dir, "FLAC_CONVERTED_OUTPUTS")):
        out_dir = os.path.join(out_dir, "FLAC_CONVERTED_OUTPUTS")

    flac_filename = f"Mix_Archive_Top_5_Tracks_{date_str}_Auto_Generated_by_MP_Mix.FLAC"
    wav_filename = f"Mix_Archive_Top_5_Tracks_{date_str}_Auto_Generated_by_MP_Mix.wav"
    mp3_filename = f"Mix_Archive_Top_5_Tracks_{date_str}_Auto_Generated_by_MP_Mix.mp3"
    tracklist_filename = f"Mix_Archive_Top_5_Tracks_{date_str}_Auto_Generated_by_MP_Mix.txt"
    cue_filename = f"Mix_Archive_Top_5_Tracks_{date_str}_Auto_Generated_by_MP_Mix.cue"
    spek_filename = f"Mix_Archive_Top_5_Tracks_{date_str}_Auto_Generated_by_MP_Mix.spek.png"

    flac_out = os.path.join(out_dir, flac_filename)
    wav_out = os.path.join(out_dir, wav_filename)
    mp3_out = os.path.join(out_dir, mp3_filename)
    tracklist_out = os.path.join(out_dir, tracklist_filename)
    cue_out = os.path.join(out_dir, cue_filename)
    spek_out = os.path.join(out_dir, spek_filename)

    print(f"\n{CYAN}Target Destination Directory:{NC} {out_dir}")
    print(f"  • FLAC:      {flac_filename}")
    print(f"  • WAV:       {wav_filename}")
    print(f"  • MP3:       {mp3_filename}")
    print(f"  • Tracklist: {tracklist_filename}")
    print(f"  • Spek:      {spek_filename}")

    # Build concat file and calculate timestamps
    concat_list = os.path.join(TOP5_AUDIO_DIR, "concat_list.txt")
    timestamps = []
    current_time = 0.0

    with open(concat_list, "w", encoding="utf-8") as f_c:
        for i, a_file in enumerate(audio_files):
            dur = get_audio_duration(a_file)
            f_c.write(f"file '{os.path.abspath(a_file)}'\n")
            timestamps.append({
                "index": i + 1,
                "artist": tracks[i]["artist"],
                "title": tracks[i]["title"],
                "start": current_time,
                "duration": dur,
                "timestamp": format_timestamp(current_time)
            })
            current_time += dur

    # Generate Tracklist .txt
    with open(tracklist_out, "w", encoding="utf-8") as f_tl:
        f_tl.write(f"======================================================================\n")
        f_tl.write(f"  {mix_artist} - {mix_title}\n")
        f_tl.write(f"  Continuous Top 5 Mix (Unmixed Single Tracks)\n")
        f_tl.write(f"  Date Generated: {date_str}\n")
        f_tl.write(f"  Total Duration: {format_timestamp(current_time)}\n")
        f_tl.write(f"======================================================================\n\n")
        for ts in timestamps:
            f_tl.write(f"[{ts['timestamp']}] {ts['index']:02d}. {ts['artist']} - {ts['title']} ({format_timestamp(ts['duration'])})\n")

    # Generate Cue Sheet .cue
    with open(cue_out, "w", encoding="utf-8") as f_cue:
        f_cue.write(f'PERFORMER "{mix_artist}"\n')
        f_cue.write(f'TITLE "{mix_title}"\n')
        f_cue.write(f'FILE "{flac_filename}" WAVE\n')
        for ts in timestamps:
            mins = int(ts['start'] // 60)
            secs = int(ts['start'] % 60)
            frames = int((ts['start'] - int(ts['start'])) * 75)
            f_cue.write(f'  TRACK {ts["index"]:02d} AUDIO\n')
            f_cue.write(f'    TITLE "{ts["title"]}"\n')
            f_cue.write(f'    PERFORMER "{ts["artist"]}"\n')
            f_cue.write(f'    INDEX 01 {mins:02d}:{secs:02d}:{frames:02d}\n')

    print(f"\n{BOLD}{YELLOW}[1/5] Encoding Continuous Lossless FLAC Mix...{NC}")
    # FLAC command
    ffmpeg_flac = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", concat_list]
    if cover_path:
        ffmpeg_flac.extend(["-i", cover_path, "-map", "0:a", "-map", "1:v", "-disposition:v:0", "attached_pic"])
    else:
        ffmpeg_flac.extend(["-map", "0:a"])

    ffmpeg_flac.extend([
        "-c:a", "flac", "-compression_level", "12",
        "-metadata", f"artist={mix_artist}",
        "-metadata", f"title={mix_title}",
        "-metadata", f"album=Stream of Frequency Top 5",
        "-metadata", f"date={date_str}",
        flac_out
    ])
    subprocess.run(ffmpeg_flac, check=True)
    print(f"      {GREEN}✓ Created FLAC:{NC} {flac_out}")

    print(f"\n{BOLD}{YELLOW}[2/5] Generating Uncompressed Master WAV...{NC}")
    ffmpeg_wav = ["ffmpeg", "-y", "-i", flac_out, "-c:a", "pcm_s24le", wav_out]
    subprocess.run(ffmpeg_wav, check=True)
    print(f"      {GREEN}✓ Created WAV:{NC} {wav_out}")

    print(f"\n{BOLD}{YELLOW}[3/5] Generating 320kbps MP3 Mix with Embedded Artwork...{NC}")
    ffmpeg_mp3 = ["ffmpeg", "-y", "-i", flac_out]
    if cover_path:
        ffmpeg_mp3.extend(["-i", cover_path, "-map", "0:a", "-map", "1:v", "-c:v", "mjpeg", "-id3v2_version", "3"])
    else:
        ffmpeg_mp3.extend(["-map", "0:a"])

    ffmpeg_mp3.extend([
        "-c:a", "libmp3lame", "-b:a", "320k",
        "-metadata", f"artist={mix_artist}",
        "-metadata", f"title={mix_title}",
        "-metadata", f"album=Stream of Frequency Top 5",
        "-metadata", f"date={date_str}",
        mp3_out
    ])
    subprocess.run(ffmpeg_mp3, check=True)
    print(f"      {GREEN}✓ Created MP3:{NC} {mp3_out}")

    print(f"\n{BOLD}{YELLOW}[4/5] Generating High-Resolution Spek Spectrogram PNG...{NC}")
    ffmpeg_spek = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", flac_out,
        "-lavfi", "showspectrumpic=s=1920x1080:mode=combined:color=magma:scale=log:legend=1:saturation=1.2",
        "-frames:v", "1", spek_out
    ]
    subprocess.run(ffmpeg_spek, check=True)
    print(f"      {GREEN}✓ Created Spek Spectrogram:{NC} {spek_out}")

    print(f"\n{BOLD}{YELLOW}[5/5] Created Timestamped Tracklist and Cue Sheet:{NC}")
    print(f"      {GREEN}✓ Tracklist:{NC} {tracklist_out}")
    print(f"      {GREEN}✓ Cue Sheet:{NC} {cue_out}")

    if os.path.isfile(concat_list):
        os.remove(concat_list)

    print(f"\n{BOLD}{GREEN}═══════════════════════════════════════════════════════════════════════════════{NC}")
    print(f"{BOLD}{GREEN}  🎉 ALL 5 EXPORTS GENERATED SUCCESSFULLY! 🎉{NC}")
    print(f"{BOLD}{GREEN}═══════════════════════════════════════════════════════════════════════════════{NC}\n")
    input(f"{BOLD}Press Enter to return...{NC}")


def configure_traktor_interactive():
    """Configure Traktor DB location and network settings (SMB, NFS, Mac)."""
    cfg = load_config()
    print(f"\n{BOLD}{MAGENTA}======================================================================{NC}")
    print(f"{BOLD}{MAGENTA}   CONFIGURE TRAKTOR DATABASE & REMOTE IMPORT (SMB, NFS, MAC)        {NC}")
    print(f"{BOLD}{MAGENTA}======================================================================{NC}\n")

    current_col = cfg.get("TRAKTOR_COLLECTION_PATH", "")
    current_audio = cfg.get("TRAKTOR_AUDIO_ROOT", "")
    current_smb = cfg.get("TRAKTOR_SMB_MOUNT", "")
    current_nfs = cfg.get("TRAKTOR_NFS_MOUNT", "")
    current_mac_host = cfg.get("TRAKTOR_MAC_HOST", "")
    current_mac_user = cfg.get("TRAKTOR_MAC_USER", "")

    print(f"  {BOLD}1) Traktor Collection / History Path:{NC} {current_col or '[Auto-detect]'}")
    print(f"  {BOLD}2) Audio Storage Root Directory:    {NC} {current_audio or '[Auto-detect]'}")
    print(f"  {BOLD}3) SMB Share Mount Point:           {NC} {current_smb or '[Not set]'}")
    print(f"  {BOLD}4) NFS Share Mount Point:           {NC} {current_nfs or '[Not set]'}")
    print(f"  {BOLD}5) Remote Mac SSH Host / IP:        {NC} {current_mac_host or '[Not set]'}")
    print(f"  {BOLD}6) Remote Mac SSH User:             {NC} {current_mac_user or '[Not set]'}")
    print(f"  {BOLD}0) Save and Return{NC}\n")

    while True:
        choice = input("Select setting to modify [1-6, or 0 to finish]: ").strip()
        if choice == "1":
            val = input(f"Enter Traktor collection.nml path (or History dir) [{current_col}]: ").strip()
            if val:
                save_config_key("TRAKTOR_COLLECTION_PATH", val)
                current_col = val
        elif choice == "2":
            val = input(f"Enter local audio root folder [{current_audio}]: ").strip()
            if val:
                save_config_key("TRAKTOR_AUDIO_ROOT", val)
                current_audio = val
        elif choice == "3":
            val = input(f"Enter SMB mount point (e.g. /run/user/1000/gvfs/... or /mnt/mac_smb) [{current_smb}]: ").strip()
            save_config_key("TRAKTOR_SMB_MOUNT", val)
            current_smb = val
        elif choice == "4":
            val = input(f"Enter NFS mount point (e.g. /mnt/mac_nfs) [{current_nfs}]: ").strip()
            save_config_key("TRAKTOR_NFS_MOUNT", val)
            current_nfs = val
        elif choice == "5":
            val = input(f"Enter Mac Hostname or IP [{current_mac_host}]: ").strip()
            save_config_key("TRAKTOR_MAC_HOST", val)
            current_mac_host = val
        elif choice == "6":
            val = input(f"Enter Mac SSH Username [{current_mac_user}]: ").strip()
            save_config_key("TRAKTOR_MAC_USER", val)
            current_mac_user = val
        elif choice in ["0", "q", "exit", ""]:
            break


def main_menu():
    """Interactive top-level menu for Top 5 Tracks Suite."""
    while True:
        status, reasons = check_prerequisites()
        badge = f"{GREEN}[Ready]{NC}" if status == "READY" else f"{YELLOW}[Unlock Mystery]{NC}"

        os.system("clear" if os.name == "posix" else "cls")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}   LISTEN TO YOUR TOP 5 TRACKS RIGHT NOW (SPECIAL OPTION) {badge}      {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")

        if status != "READY":
            print(f"\n  {BOLD}{YELLOW}⚠️  FEATURE LOCKED - UNLOCK MYSTERY STATUS:{NC}")
            for r in reasons:
                print(f"     • {RED}{r}{NC}")
            print(f"\n  {CYAN}To unlock this special feature, you must:{NC}")
            print(f"  1. Record & process at least one mix with the Manager ({GREEN}Option 1{NC}).")
            print(f"  2. Generate the Master Tracklist HTML Index ({GREEN}Option 11 -> 4{NC}).\n")
            print(f"  {BOLD}{CYAN}1)${NC} Generate Master Tracklist HTML Now ({GREEN}Generate_Master_Tracklist.sh${NC})")
            print(f"  {BOLD}{CYAN}2)${NC} Run FLAC Mix Conversion Process Now ({GREEN}Make_SOF_FLAC_CONVERSION.sh${NC})")
            print(f"  {BOLD}{CYAN}0)${NC} Return to Main Menu\n")
            c = input("Enter choice [0-2]: ").strip()
            if c == "1":
                gen_sh = os.path.join(SCRIPT_DIR, "Generate_Master_Tracklist.sh")
                if os.path.isfile(gen_sh):
                    subprocess.run(["bash", gen_sh])
                input("\nPress Enter to refresh...")
            elif c == "2":
                conv_sh = os.path.join(SCRIPT_DIR, "Make_SOF_FLAC_CONVERSION.sh")
                if os.path.isfile(conv_sh):
                    subprocess.run(["bash", conv_sh])
                input("\nPress Enter to refresh...")
            elif c in ["0", "q", "exit"]:
                return
            continue

        # Ready menu
        state = load_top_5_state()
        t_count = len(state.get("tracks", []))
        print(f"\n  {DIM}Status: {GREEN}Ready{NC} {DIM}| Current Top 5 Selection: {CYAN}{t_count}/5 tracks selected{NC}\n")

        print(f"  ${BOLD}${CYAN}1)${NC} View Current Top 5 Tracks of All Time")
        print(f"  ${BOLD}${CYAN}2)${NC} Select / Change Top 5 Tracks ({GREEN}Browse Master HTML Tracklist{NC})")
        print(f"  ${BOLD}${CYAN}3)${NC} Import Your Top 5 Tracks from Traktor Now & Playlist Them ({GREEN}Auto-Play Track 1{NC})")
        print(f"  ${BOLD}${CYAN}4)${NC} Export Top 5 Tracks as Continuous Joined Mix ({GREEN}FLAC, WAV, MP3, Spek, Tracklist{NC})")
        print(f"  ${BOLD}${CYAN}5)${NC} Configure Traktor Database & Remote Mac Import ({GREEN}SMB, NFS, Local, SSH{NC})")
        print(f"  ${BOLD}${CYAN}6)${NC} View Master Tracklist HTML Index in Browser")
        print(f"  ${BOLD}${CYAN}0)${NC} Return to Main Menu\n")

        choice = input("Enter choice [0-6]: ").strip()
        if choice == "1":
            display_top_5()
            input(f"{BOLD}Press Enter to return...{NC}")
        elif choice == "2":
            select_top_5_interactive()
        elif choice == "3":
            import_top_5_and_playlist()
        elif choice == "4":
            export_top_5_mix()
        elif choice == "5":
            configure_traktor_interactive()
        elif choice == "6":
            h_path = get_master_html_path()
            if h_path and os.path.isfile(h_path):
                subprocess.Popen(["xdg-open", h_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            input(f"{BOLD}Press Enter to return...{NC}")
        elif choice in ["0", "q", "exit"]:
            return


if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg = sys.argv[1].lower()
        if arg in ["--status", "status"]:
            st, rs = check_prerequisites()
            print(st)
            for r in rs:
                print(r)
            sys.exit(0 if st == "READY" else 1)
        elif arg in ["--badge", "badge"]:
            st, _ = check_prerequisites()
            print(f"{GREEN}[Ready]{NC}" if st == "READY" else f"{YELLOW}[Unlock Mystery]{NC}")
            sys.exit(0)
        elif arg in ["--select", "select"]:
            select_top_5_interactive()
            sys.exit(0)
        elif arg in ["--import", "import", "--playlist", "playlist"]:
            import_top_5_and_playlist()
            sys.exit(0)
        elif arg in ["--export", "export", "--mix", "mix"]:
            export_top_5_mix()
            sys.exit(0)
        elif arg in ["--config", "config"]:
            configure_traktor_interactive()
            sys.exit(0)

    main_menu()
