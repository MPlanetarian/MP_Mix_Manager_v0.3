#!/usr/bin/env python3
"""Audit and generate missing tracklists across all 3 configured MIX_ARCHIVE folders.

Storage Folders:
1) /run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS
2) /run/media/mplanetarian/DATA/MIX_ARCHIVE2/FLAC_CONVERTED_OUTPUTS
3) /var/home/mplanetarian/GoogleDrive/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS

Ensures every FLAC mix has a corresponding valid tracklist file.
If missing or dummy fallback, searches:
1) Existing valid tracklists in any of the 3 archive storage locations
2) Traktor history database files (*.nml)
If not in Traktor, skips to the next FLAC immediately.
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

ARCHIVE_FOLDERS = [
    "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS",
    "/run/media/mplanetarian/DATA/MIX_ARCHIVE2/FLAC_CONVERTED_OUTPUTS",
    "/var/home/mplanetarian/GoogleDrive/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"
]

TRAKTOR_HISTORY_DIR = "/run/media/mplanetarian/WD BLACK B/MIX_ARCHIVE/Traktor 3.11.1/History"
CACHE_DIR = "/home/mplanetarian/.cache/rclone/vfs/google3/MIX_ARCHIVE/FLAC_CONVERTED_OUTPUTS"


def is_valid_tracklist_content(text):
    if not text:
        return False
    if "TRACKLIST (Automatic Fallback)" in text:
        return False
    track_lines = [
        line for line in text.splitlines()
        if re.match(r"^\s*\d+[\.\)]\s+", line.strip())
    ]
    return len(track_lines) >= 2


def parse_traktor_nml(nml_path):
    """Parse Traktor NML file and extract ordered tracklist."""
    try:
        tree = ET.parse(nml_path)
        root = tree.getroot()

        collection_tracks = {}
        for entry in root.findall(".//ENTRY"):
            loc = entry.find("LOCATION")
            fkey = ""
            fname = ""
            if loc is not None:
                fkey = f"{loc.get('VOLUME', '')}{loc.get('DIR', '')}{loc.get('FILE', '')}"
                fname = loc.get("FILE", "")
            art = entry.get("ARTIST", "").strip()
            tit = entry.get("TITLE", "").strip()
            tinfo = f"{art} - {tit}".strip(" -")
            if tinfo:
                if fkey:
                    collection_tracks[fkey] = tinfo
                if fname:
                    collection_tracks[fname] = tinfo

        tracks = []
        seen = set()
        pl = root.find(".//PLAYLIST")
        scope = pl if pl is not None else root
        for entry in scope.findall(".//ENTRY"):
            pkey = entry.find("PRIMARYKEY")
            if pkey is not None:
                kval = pkey.get("KEY", "")
                t = collection_tracks.get(kval)
                if not t:
                    for k, v in collection_tracks.items():
                        if k and k in kval:
                            t = v
                            break
                if not t:
                    parts = kval.split("/")
                    if parts:
                        t = parts[-1].replace(".flac", "").replace(".wav", "").replace(".mp3", "")
                if t and t not in seen:
                    seen.add(t)
                    tracks.append(t)

        if not tracks:
            for k, v in collection_tracks.items():
                if v and v not in seen:
                    seen.add(v)
                    tracks.append(v)

        return tracks
    except Exception as e:
        print(f"Error parsing NML {nml_path}: {e}", file=sys.stderr)
        return []


def format_tracklist_file(title, flac_filename, tracks, conversion_date=""):
    lines = [
        "==================================================",
        "RELEASE INFO & SOURCE MANIFEST",
        "==================================================",
        "Artist:        MPlanetarian",
        "Album:         Stream of Frequency",
        f"Title:         {title}",
        f"Conversion Date: {conversion_date or '2026-09-25 00:00:00'}",
        "--------------------------------------------------",
        f"Source Files Merged/Converted (1 file(s)):",
        f" - {flac_filename}",
        "==================================================",
        "TRACKLIST (Extracted from Traktor Database)",
        "=================================================="
    ]
    for idx, trk in enumerate(tracks, start=1):
        lines.append(f"{idx:02d}. {trk}")
    lines.append("")
    return "\n".join(lines)


def main():
    print("=" * 60)
    print("      MIX ARCHIVE TRACKLIST AUDIT & RESOLUTION      ")
    print("=" * 60)

    # 1. Index Traktor History files
    print("\n[1/4] Indexing Traktor History files...")
    hist_files = []
    if os.path.isdir(TRAKTOR_HISTORY_DIR):
        hist_files = [
            os.path.join(TRAKTOR_HISTORY_DIR, f)
            for f in os.listdir(TRAKTOR_HISTORY_DIR)
            if f.endswith(".nml")
        ]
    print(f"Found {len(hist_files)} Traktor history files in {TRAKTOR_HISTORY_DIR}")

    hist_by_dt = {}
    hist_by_date = {}
    for hf in hist_files:
        fn = os.path.basename(hf)
        m = re.search(r"history_(\d{4})y(\d{2})m(\d{2})d_(\d{2})h(\d{2})m(\d{2})s", fn)
        if m:
            y, mo, d, h, mi, s = m.groups()
            dt_key = f"{y}-{mo}-{d}_{h}h{mi}m"
            hist_by_dt[dt_key] = hf
            hist_by_date.setdefault(f"{y}-{mo}-{d}", []).append(hf)
        else:
            m2 = re.search(r"history_(\d{4})y(\d{2})m(\d{2})d", fn)
            if m2:
                y, mo, d = m2.groups()
                hist_by_date.setdefault(f"{y}-{mo}-{d}", []).append(hf)

    # 2. Index all known valid tracklists locally across archives & vfs cache
    print("\n[2/4] Indexing all existing valid tracklists across local archives & cache...")
    scan_sources = [
        ARCHIVE_FOLDERS[0],
        ARCHIVE_FOLDERS[1],
        CACHE_DIR
    ]

    known_by_filename = {}
    known_by_prefix = {}
    known_by_ep = {}

    def register_tracklist(filepath):
        if not os.path.isfile(filepath):
            return
        fn = os.path.basename(filepath)
        if not fn.endswith(".txt") or fn == "requirements.txt" or fn.startswith("checksums"):
            return
        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            if is_valid_tracklist_content(content):
                known_by_filename[fn] = content
                # Check for dated prefix: e.g. Stream_of_Frequency_FLAC_Conversaion_Mix_115_...
                m = re.match(r"(Stream_of_Frequency_FLAC_Conversaion_Mix_\d+)", fn)
                if m:
                    prefix = m.group(1)
                    if prefix not in known_by_prefix or len(content) > len(known_by_prefix[prefix]):
                        known_by_prefix[prefix] = content
                # Check episode number
                m_ep = re.search(r"(?:Mix_|Episode\s*|Stream_of_Frequency\s*)([0-9]{2,3})", fn, re.I)
                if m_ep:
                    ep_str = m_ep.group(1)
                    if ep_str not in known_by_ep or len(content) > len(known_by_ep[ep_str]):
                        known_by_ep[ep_str] = content
        except Exception:
            pass

    for sdir in scan_sources:
        if os.path.isdir(sdir):
            try:
                for entry in os.scandir(sdir):
                    if entry.is_file() and entry.name.endswith(".txt"):
                        register_tracklist(entry.path)
            except Exception as e:
                print(f"Warning scanning {sdir}: {e}", file=sys.stderr)

    print(f"Indexed {len(known_by_filename)} valid tracklists, {len(known_by_prefix)} prefixes, {len(known_by_ep)} episode tracklists.")

    # 3. Process each archive folder
    print("\n[3/4] Checking and resolving tracklists in the 3 configured archive folders...")
    total_audited = 0
    total_already_valid = 0
    total_resolved_from_archive = 0
    total_resolved_from_traktor = 0
    total_skipped_no_traktor = 0

    for fld in ARCHIVE_FOLDERS:
        if not os.path.isdir(fld):
            print(f"\nSkipping missing folder: {fld}")
            continue

        is_gdrive = (fld == ARCHIVE_FOLDERS[2])
        flac_files = sorted([f for f in os.listdir(fld) if f.lower().endswith(".flac")])
        print(f"\nFolder: {fld} ({len(flac_files)} FLAC files)")

        for fl in flac_files:
            total_audited += 1
            flac_path = os.path.join(fld, fl)
            stem = os.path.splitext(fl)[0]
            txt_path = os.path.join(fld, stem + ".txt")
            cache_txt_path = os.path.join(CACHE_DIR, stem + ".txt") if is_gdrive else None

            # Check if current txt is valid (check cache first if gdrive to avoid slow FUSE reads)
            is_valid = False
            check_paths = [cache_txt_path, txt_path] if cache_txt_path else [txt_path]
            for cp in check_paths:
                if cp and os.path.isfile(cp):
                    try:
                        with open(cp, "r", encoding="utf-8", errors="ignore") as f:
                            c = f.read()
                        if is_valid_tracklist_content(c):
                            is_valid = True
                            break
                    except Exception:
                        pass

            if is_valid:
                total_already_valid += 1
                continue

            # Need tracklist!
            content_to_write = None
            resolution_source = None

            # Strategy 1: Check known tracklists by exact stem.txt
            if (stem + ".txt") in known_by_filename:
                content_to_write = known_by_filename[stem + ".txt"]
                resolution_source = "archive match (exact name)"

            # Strategy 2: Check prefix (e.g. short name matching dated name)
            if not content_to_write and stem in known_by_prefix:
                content_to_write = known_by_prefix[stem]
                resolution_source = "archive match (dated counterpart)"

            # Strategy 3: Check candidate dated filenames in known_by_filename
            if not content_to_write:
                for k, v in known_by_filename.items():
                    if k.startswith(stem + "_") or k.startswith(stem + "."):
                        content_to_write = v
                        resolution_source = f"archive match ({k})"
                        break

            # Strategy 4: Search Traktor History
            if not content_to_write:
                # Extract date and time
                m_dt = re.search(r"(\d{4}-\d{2}-\d{2})_(\d{1,2})h(\d{2})m", stem)
                matched_nml = None
                matched_date = ""
                if m_dt:
                    date_str, h_str, m_str = m_dt.groups()
                    h_str = h_str.zfill(2)
                    dt_key = f"{date_str}_{h_str}h{m_str}m"
                    matched_nml = hist_by_dt.get(dt_key)
                    matched_date = date_str

                if not matched_nml:
                    m_d = re.search(r"(\d{4}-\d{2}-\d{2})", stem)
                    if m_d:
                        date_str = m_d.group(1)
                        cands = hist_by_date.get(date_str, [])
                        if len(cands) == 1:
                            matched_nml = cands[0]
                            matched_date = date_str

                if matched_nml:
                    tracks = parse_traktor_nml(matched_nml)
                    if len(tracks) >= 2:
                        readable_title = stem.replace("_", " ")
                        content_to_write = format_tracklist_file(readable_title, fl, tracks, matched_date)
                        resolution_source = f"Traktor database ({os.path.basename(matched_nml)})"

            # Apply resolution or skip
            if content_to_write:
                try:
                    with open(txt_path, "w", encoding="utf-8") as f:
                        f.write(content_to_write)
                    if cache_txt_path:
                        try:
                            with open(cache_txt_path, "w", encoding="utf-8") as f:
                                f.write(content_to_write)
                        except Exception:
                            pass
                    if "Traktor" in resolution_source:
                        total_resolved_from_traktor += 1
                    else:
                        total_resolved_from_archive += 1
                    print(f"  [RESOLVED] {fl} -> {resolution_source}")
                except Exception as e:
                    print(f"  [ERROR WRITING] {txt_path}: {e}", file=sys.stderr)
            else:
                total_skipped_no_traktor += 1
                # User constraint: "if it's not in Traktor then skip and process the next flac immediately"
                # If a dummy fallback was previously created, remove it so it's not falsely presented as a tracklist
                for dp in ([cache_txt_path, txt_path] if cache_txt_path else [txt_path]):
                    if dp and os.path.isfile(dp):
                        try:
                            with open(dp, "r", encoding="utf-8", errors="ignore") as f:
                                c = f.read()
                            if "TRACKLIST (Automatic Fallback)" in c:
                                os.remove(dp)
                        except Exception:
                            pass
                print(f"  [SKIPPED] {fl} (not in Traktor)")

    print("\n" + "=" * 60)
    print("AUDIT & RESOLUTION COMPLETE")
    print("=" * 60)
    print(f"Total FLAC files audited:              {total_audited}")
    print(f"Already had valid tracklists:          {total_already_valid}")
    print(f"Resolved from counterpart archives:    {total_resolved_from_archive}")
    print(f"Generated directly from Traktor NML:   {total_resolved_from_traktor}")
    print(f"Skipped (not found in Traktor/archive):{total_skipped_no_traktor}")
    print("=" * 60)


if __name__ == "__main__":
    main()
