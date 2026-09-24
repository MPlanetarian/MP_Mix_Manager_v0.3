#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 - Mix Archive Folder Playlists Generator
Generates .m3u8 and .xspf playlists for all configured Mix Archive Storage Folders
(Primary & Multiple Additional Locations) and a Complete Master Archive playlist.

Playlists are always saved into:
  1. Root of the Application: <APP_ROOT>/PLAYLISTS_GENERATED/
  2. Root of each configured Mix Archive storage folder: <ARCHIVE_DIR>/PLAYLISTS_GENERATED/
"""

import os
import sys
import re
import time
import shutil
import argparse
import subprocess
import urllib.parse
from pathlib import Path
import xml.sax.saxutils as saxutils

# --- ANSI Colors ---
BOLD = "\033[1m"
DIM = "\033[2m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
RED = "\033[0;31m"
BLUE = "\033[0;34m"
MAGENTA = "\033[0;35m"
CYAN = "\033[0;36m"
WHITE = "\033[1;37m"
NC = "\033[0m"

AUDIO_EXTS = {'.flac', '.wav', '.mp3'}

def get_base_dir():
    # If running from scripts/, return parent directory (app root)
    p = Path(__file__).resolve().parent
    if p.name == "scripts":
        return p.parent
    return p

def get_configured_archive_dirs():
    base_dir = get_base_dir()
    dirs = []
    seen = set()

    def add(d_str):
        if not d_str:
            return
        p = Path(d_str.strip().strip('"').strip("'")).resolve()
        if str(p) not in seen and p.is_dir():
            seen.add(str(p))
            dirs.append(p)

    if os.environ.get("MIX_ARCHIVE_DIR"):
        add(os.environ.get("MIX_ARCHIVE_DIR"))

    extra = os.environ.get("EXTRA_MIX_ARCHIVE_DIRS")
    cfg = base_dir / "config.env"
    if cfg.is_file():
        try:
            with open(cfg, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("MIX_ARCHIVE_DIR="):
                        add(line.split("=", 1)[1])
                    elif line.startswith("EXTRA_MIX_ARCHIVE_DIRS="):
                        if not extra:
                            extra = line.split("=", 1)[1].strip().strip('"').strip("'")
        except Exception:
            pass

    if extra:
        for sep in [':', ';', ',']:
            if sep in extra:
                for x in extra.split(sep):
                    add(x)
                break
        else:
            add(extra)

    if not dirs:
        fallback = base_dir / "MIX_ARCHIVE"
        if fallback.is_dir():
            dirs.append(fallback)

    return dirs

def get_target_playlists_generated_dirs(configured_dirs):
    base_dir = get_base_dir()
    targets = [base_dir / "PLAYLISTS_GENERATED"]
    for d in configured_dirs:
        targets.append(d / "PLAYLISTS_GENERATED")
        if d.name in ("FLAC_CONVERTED_OUTPUTS", "CONVERTED_WAV_FILES", "MP3_CONVERTED_OUTPUTS") and d.parent.is_dir():
            targets.append(d.parent / "PLAYLISTS_GENERATED")

    unique_targets = []
    seen = set()
    for t in targets:
        s = str(t.resolve())
        if s not in seen:
            seen.add(s)
            t.mkdir(parents=True, exist_ok=True)
            unique_targets.append(t)
    return unique_targets

def get_clean_folder_slug(p):
    parts = [part for part in p.parts if part not in ('/', 'run', 'media', 'Volumes', 'Users', 'home', 'var', os.environ.get("USER", ""))]
    if parts:
        name = "_".join(parts[-2:]) if len(parts) >= 2 else parts[0]
    else:
        name = p.name
    # Strip redundant output suffixes for cleaner titles
    name = re.sub(r'_FLAC_CONVERTED_OUTPUTS$', '', name, flags=re.IGNORECASE)
    name = re.sub(r'[^a-zA-Z0-9_-]', '_', name)
    name = re.sub(r'_+', '_', name).strip('_')
    return name or "Mix_Archive"

def scan_dir_mixes(directory):
    mixes = []
    d = Path(directory)
    if not d.is_dir():
        return mixes

    for root, subdirs, files in os.walk(str(d)):
        depth = 0 if root == str(d) else os.path.relpath(root, str(d)).count(os.sep) + 1
        # Limit to depth <= 1, except if mp3_converted_outputs
        if depth > 1 and 'mp3_converted_outputs' not in root.lower():
            continue
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in AUDIO_EXTS:
                if ext == '.mp3' and depth > 0 and 'mp3_converted_outputs' not in root.lower():
                    continue
                full_path = os.path.join(root, f)
                mixes.append({
                    "filename": f,
                    "path": full_path,
                    "ext": ext
                })
    mixes.sort(key=lambda x: x["filename"].lower())
    return mixes

def write_m3u(file_path, mixes):
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("#EXTM3U\n")
        for m in mixes:
            title = Path(m["filename"]).stem
            f.write(f"#EXTINF:-1,{title}\n")
            f.write(f"{m['path']}\n")

def write_xspf(file_path, title, mixes):
    with open(file_path, "w", encoding="utf-8") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write('<playlist version="1" xmlns="http://xspf.org/ns/0/">\n')
        f.write(f'  <title>{saxutils.escape(title)}</title>\n')
        f.write('  <trackList>\n')
        for m in mixes:
            stem = saxutils.escape(Path(m["filename"]).stem)
            loc = "file://" + urllib.parse.quote(str(Path(m["path"]).resolve()))
            f.write('    <track>\n')
            f.write(f'      <location>{loc}</location>\n')
            f.write(f'      <title>{stem}</title>\n')
            f.write('    </track>\n')
        f.write('  </trackList>\n')
        f.write('</playlist>\n')

def sync_playlists_to_targets(created_files, target_dirs):
    base_dir = get_base_dir()
    app_gen_dir = base_dir / "PLAYLISTS_GENERATED"
    for target in target_dirs:
        if target.resolve() == app_gen_dir.resolve():
            continue
        target.mkdir(parents=True, exist_ok=True)
        for cf in created_files:
            try:
                shutil.copy2(cf, target / cf.name)
            except Exception:
                pass

def launch_playlist_in_player(playlist_path, player="cliamp"):
    playlist_path = Path(playlist_path).resolve()
    print(f"\n{BOLD}{GREEN}Launching {player} with playlist: {playlist_path.name}...{NC}")
    base_dir = get_base_dir()
    
    if player == "cliamp":
        cliamp_bin = shutil.which("cliamp") or (base_dir / "bin" / "cliamp")
        if os.name == 'posix' and shutil.which("konsole"):
            subprocess.Popen(["konsole", "--hold", "-e", str(cliamp_bin), str(playlist_path)])
        elif os.name == 'posix' and shutil.which("ptyxis"):
            subprocess.Popen(["ptyxis", "--", str(cliamp_bin), str(playlist_path)])
        else:
            subprocess.Popen([str(cliamp_bin), str(playlist_path)])
    elif player == "strawberry":
        subprocess.Popen(["strawberry", str(playlist_path)])
    elif player == "vlc":
        if shutil.which("vlc"):
            subprocess.Popen(["vlc", str(playlist_path)])
        elif shutil.which("flatpak"):
            subprocess.Popen(["flatpak", "run", "org.videolan.VLC", str(playlist_path)])
    elif player == "mpv":
        if shutil.which("mpv"):
            subprocess.Popen(["mpv", f"--playlist={playlist_path}"])
    elif player == "kodi":
        if shutil.which("kodi"):
            subprocess.Popen(["kodi", str(playlist_path)])
        elif shutil.which("flatpak"):
            subprocess.Popen(["flatpak", "run", "tv.kodi.Kodi", str(playlist_path)])
    else:
        if sys.platform == "darwin":
            subprocess.Popen(["open", str(playlist_path)])
        elif sys.platform == "win32":
            subprocess.Popen(["cmd.exe", "/c", "start", "", str(playlist_path)])
        else:
            subprocess.Popen(["xdg-open", str(playlist_path)])

def generate_all_playlists():
    base_dir = get_base_dir()
    app_gen_dir = base_dir / "PLAYLISTS_GENERATED"
    app_gen_dir.mkdir(parents=True, exist_ok=True)
    
    configured = get_configured_archive_dirs()
    target_dirs = get_target_playlists_generated_dirs(configured)
    
    created_files = []
    folder_stats = []
    all_mixes_master = []
    seen_paths = set()

    for idx, d in enumerate(configured, start=1):
        slug = get_clean_folder_slug(d)
        mixes = scan_dir_mixes(d)
        folder_stats.append({
            "idx": idx,
            "path": str(d),
            "slug": slug,
            "count": len(mixes),
            "flac": sum(1 for m in mixes if m["ext"] == ".flac"),
            "wav": sum(1 for m in mixes if m["ext"] == ".wav"),
            "mp3": sum(1 for m in mixes if m["ext"] == ".mp3")
        })

        if mixes:
            # 1. Per-folder All Mixes .m3u8 and .xspf
            f_m3u = app_gen_dir / f"Mix_Archive_{slug}.m3u8"
            f_xspf = app_gen_dir / f"Mix_Archive_{slug}.xspf"
            write_m3u(f_m3u, mixes)
            write_xspf(f_xspf, f"Mix Archive - {slug}", mixes)
            created_files.extend([f_m3u, f_xspf])

            # If folder has both FLAC and WAV, also create format playlists
            flacs = [m for m in mixes if m["ext"] == ".flac"]
            wavs = [m for m in mixes if m["ext"] == ".wav"]
            if flacs and wavs:
                flac_m3u = app_gen_dir / f"Mix_Archive_{slug}_FLAC.m3u8"
                wav_m3u = app_gen_dir / f"Mix_Archive_{slug}_WAV.m3u8"
                write_m3u(flac_m3u, flacs)
                write_m3u(wav_m3u, wavs)
                created_files.extend([flac_m3u, wav_m3u])

            for m in mixes:
                if m["path"] not in seen_paths:
                    seen_paths.add(m["path"])
                    all_mixes_master.append(m)

    # 2. Combined Master Archive .m3u8 and .xspf across ALL storage locations
    if all_mixes_master:
        all_mixes_master.sort(key=lambda x: x["filename"].lower())
        master_m3u = app_gen_dir / "Complete_Mix_Archive_Master_Mixes.m3u8"
        master_xspf = app_gen_dir / "Complete_Mix_Archive_Master_Mixes.xspf"
        write_m3u(master_m3u, all_mixes_master)
        write_xspf(master_xspf, "Complete Mix Archive - All Storage Locations", all_mixes_master)
        created_files.extend([master_m3u, master_xspf])

        # FLAC master combined
        all_flacs = [m for m in all_mixes_master if m["ext"] == ".flac"]
        if all_flacs:
            flac_all_m3u = app_gen_dir / "Complete_Mix_Archive_FLAC_Mixes.m3u8"
            write_m3u(flac_all_m3u, all_flacs)
            created_files.append(flac_all_m3u)

    # 3. Sync all generated playlists to all target PLAYLISTS_GENERATED locations
    sync_playlists_to_targets(created_files, target_dirs)

    return created_files, folder_stats, target_dirs, len(all_mixes_master)

def interactive_menu():
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        configured = get_configured_archive_dirs()
        target_dirs = get_target_playlists_generated_dirs(configured)
        app_gen_dir = get_base_dir() / "PLAYLISTS_GENERATED"
        existing_playlists = list(app_gen_dir.glob("*.m3u*")) + list(app_gen_dir.glob("*.xspf"))
        existing_playlists.sort(key=lambda x: x.name.lower())

        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"{BOLD}{MAGENTA}        MIX ARCHIVE FOLDER PLAYLISTS GENERATOR SUITE                  {NC}")
        print(f"{BOLD}{MAGENTA}======================================================================{NC}")
        print(f"  • {BOLD}Configured Storage Folders:{NC}  {GREEN}{len(configured)}{NC} folders active")
        print(f"  • {BOLD}Application Output Dir:{NC}      {CYAN}{app_gen_dir}{NC}")
        print(f"  • {BOLD}Total Target Folders:{NC}        {WHITE}{len(target_dirs)}{NC} mirrored PLAYLISTS_GENERATED paths")
        print(f"  • {BOLD}Existing Generated Playlists:{NC}{YELLOW}{len(existing_playlists)}{NC} files ready")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
        
        print(f"{BOLD}Configured Mix Archive Folders:{NC}")
        for idx, d in enumerate(configured, start=1):
            mix_count = len(scan_dir_mixes(d))
            print(f"  [{idx}] {CYAN}{d}{NC} {DIM}({mix_count} mixes){NC}")
        print("")

        if existing_playlists:
            print(f"{BOLD}Available Generated Playlists:{NC}")
            for idx, p in enumerate(existing_playlists[:10], start=1):
                print(f"  {BOLD}{CYAN}{idx:2d}){NC} {p.name}")
            if len(existing_playlists) > 10:
                print(f"      {DIM}... and {len(existing_playlists) - 10} more in PLAYLISTS_GENERATED/{NC}")
            print("")

        print(f"{BOLD}Generation & Playback Options:{NC}")
        print(f"  {BOLD}{CYAN} 1){NC} {BOLD}{GREEN}Generate Playlists for ALL Configured Storage Locations (Recommended){NC}")
        print(f"  {BOLD}{CYAN} 2){NC} Select a Specific Storage Folder to Generate Playlists")
        print(f"  {BOLD}{CYAN} 3){NC} Generate Combined Complete Master Archive Playlist Only")
        print(f"  {BOLD}{CYAN} 4){NC} Launch a Generated Playlist in Player (cliamp, Strawberry, VLC, etc.)")
        print(f"  {BOLD}{CYAN} 5){NC} View Destination PLAYLISTS_GENERATED Folders & Sync Status")
        print(f"\n  {BOLD}{CYAN} 0){NC} Return to Main Menu {DIM}(or 'q'){NC}")
        print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")

        choice = input(f"{BOLD}Enter choice [0-5]: {NC}").strip()
        if choice in ('0', 'q', 'exit', 'quit'):
            break

        if choice == '1':
            print(f"\n{BOLD}{YELLOW}Generating playlists for all configured Mix Archive storage folders...{NC}")
            created, stats, targets, total_master = generate_all_playlists()
            print(f"\n{BOLD}{GREEN}✓ Successfully generated {len(created)} playlist files across {len(targets)} target directories!{NC}")
            print(f"{BOLD}{BLUE}──────────────────────────────────────────────────────────────────────{NC}")
            print(f"  • {BOLD}Total Master Mixes Tally:{NC} {BOLD}{WHITE}{total_master}{NC} tracks indexed")
            for st in stats:
                print(f"  • [{st['idx']}] {st['slug']}: {GREEN}{st['count']}{NC} mixes ({st['flac']} FLAC | {st['wav']} WAV | {st['mp3']} MP3)")
            print(f"\n{BOLD}Saved & Synchronized to:{NC}")
            for t in targets:
                print(f"  📁 {CYAN}{t}{NC}")
            input(f"\n{BOLD}Press Enter to continue...{NC}")

        elif choice == '2':
            print("\nSelect Configured Storage Location:")
            for idx, d in enumerate(configured, start=1):
                print(f"  {idx}) {d}")
            sel = input(f"Enter folder number [1-{len(configured)}]: ").strip()
            if sel.isdigit() and 1 <= int(sel) <= len(configured):
                target_dir = configured[int(sel) - 1]
                slug = get_clean_folder_slug(target_dir)
                mixes = scan_dir_mixes(target_dir)
                if not mixes:
                    print(f"{YELLOW}No mixes found in {target_dir}.{NC}")
                    time.sleep(1.5)
                    continue
                f_m3u = app_gen_dir / f"Mix_Archive_{slug}.m3u8"
                f_xspf = app_gen_dir / f"Mix_Archive_{slug}.xspf"
                write_m3u(f_m3u, mixes)
                write_xspf(f_xspf, f"Mix Archive - {slug}", mixes)
                sync_playlists_to_targets([f_m3u, f_xspf], target_dirs)
                print(f"\n{GREEN}✓ Generated {f_m3u.name} and {f_xspf.name} ({len(mixes)} tracks)!{NC}")
                input("Press Enter to continue...")

        elif choice == '3':
            print(f"\n{BOLD}{YELLOW}Generating Complete Master Archive Playlists...{NC}")
            all_mixes = []
            seen = set()
            for d in configured:
                for m in scan_dir_mixes(d):
                    if m["path"] not in seen:
                        seen.add(m["path"])
                        all_mixes.append(m)
            all_mixes.sort(key=lambda x: x["filename"].lower())
            f_m3u = app_gen_dir / "Complete_Mix_Archive_Master_Mixes.m3u8"
            f_xspf = app_gen_dir / "Complete_Mix_Archive_Master_Mixes.xspf"
            write_m3u(f_m3u, all_mixes)
            write_xspf(f_xspf, "Complete Mix Archive - All Storage Locations", all_mixes)
            sync_playlists_to_targets([f_m3u, f_xspf], target_dirs)
            print(f"\n{GREEN}✓ Generated Complete Master Archive Playlists ({len(all_mixes)} total mixes)!{NC}")
            input("Press Enter to continue...")

        elif choice == '4':
            if not existing_playlists:
                print(f"{YELLOW}No playlists found in PLAYLISTS_GENERATED. Generate some first!{NC}")
                time.sleep(1.5)
                continue
            print("\nSelect Playlist to Launch:")
            for idx, p in enumerate(existing_playlists, start=1):
                print(f"  {idx:2d}) {p.name}")
            psel = input(f"Select playlist [1-{len(existing_playlists)}]: ").strip()
            if psel.isdigit() and 1 <= int(psel) <= len(existing_playlists):
                chosen_p = existing_playlists[int(psel) - 1]
                print(f"\nSelect Audio Player:")
                print(f"  1) cliamp (Terminal Player)")
                print(f"  2) Strawberry Music Player")
                print(f"  3) VLC Media Player")
                print(f"  4) MPV Player")
                print(f"  5) Kodi Media Center")
                p_opt = input("Select player [1-5, default 1]: ").strip() or "1"
                p_map = {"1": "cliamp", "2": "strawberry", "3": "vlc", "4": "mpv", "5": "kodi"}
                player_name = p_map.get(p_opt, "cliamp")
                launch_playlist_in_player(chosen_p, player_name)
                time.sleep(1)

        elif choice == '5':
            print(f"\n{BOLD}{CYAN}Target PLAYLISTS_GENERATED Storage Directories:{NC}")
            for idx, t in enumerate(target_dirs, start=1):
                count = len(list(t.glob("*.m3u*")) + list(t.glob("*.xspf")))
                print(f"  [{idx}] {WHITE}{t}{NC} ➔ {GREEN}{count} playlists{NC}")
            input(f"\n{BOLD}Press Enter to return...{NC}")

def main():
    parser = argparse.ArgumentParser(description="Mix Archive Folder Playlists Generator")
    parser.add_argument("--all", action="store_true", help="Generate all playlists non-interactively")
    parser.add_argument("--list", action="store_true", help="List all generated playlists")
    parser.add_argument("--launch", help="Launch playlist file in player")
    parser.add_argument("--player", default="cliamp", help="Player to launch with (default cliamp)")
    args = parser.parse_args()

    if args.all:
        created, stats, targets, total_master = generate_all_playlists()
        print(f"✓ Generated {len(created)} playlists across {len(targets)} locations ({total_master} total mixes).")
    elif args.list:
        app_gen_dir = get_base_dir() / "PLAYLISTS_GENERATED"
        for p in sorted(app_gen_dir.iterdir()):
            if p.is_file() and p.suffix.lower() in ('.m3u', '.m3u8', '.xspf'):
                print(f"{p.name}")
    elif args.launch:
        launch_playlist_in_player(args.launch, args.player)
    else:
        interactive_menu()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("")
        sys.exit(0)
