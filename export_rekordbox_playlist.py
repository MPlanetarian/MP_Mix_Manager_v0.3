#!/usr/bin/env python3
"""
MP Mix Manager v0.3 - Multi-Platform DJ Exporter (Pioneer Rekordbox XML)
Converts Traktor .nml histories/collections, CUE sheets, and M3U playlists
into standard Pioneer Rekordbox XML format (rekordbox.xml) for instant import
into Rekordbox 5/6/7 and export to CDJ USB drives.
"""

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
import xml.dom.minidom


def parse_m3u(filepath):
    """Parse M3U / M3U8 playlist file."""
    tracks = []
    current_title = ""
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if line.startswith("#EXTINF:"):
                # #EXTINF:123,Artist - Title
                parts = line.split(",", 1)
                if len(parts) > 1:
                    current_title = parts[1].strip()
            elif line and not line.startswith("#"):
                track_path = Path(line)
                artist, title = "Unknown Artist", track_path.stem
                if current_title and " - " in current_title:
                    artist, title = current_title.split(" - ", 1)
                elif " - " in track_path.stem:
                    artist, title = track_path.stem.split(" - ", 1)
                tracks.append({
                    "location": str(track_path.resolve()),
                    "artist": artist.strip(),
                    "title": title.strip(),
                    "duration": 0
                })
                current_title = ""
    return tracks


def parse_traktor_nml(filepath):
    """Parse Traktor .nml collection or history file."""
    tracks = []
    tree = ET.parse(filepath)
    root = tree.getroot()

    # Search for ENTRY elements in COLLECTION
    for entry in root.findall(".//ENTRY"):
        title = entry.get("TITLE", "")
        artist = entry.get("ARTIST", "")
        key = ""
        bpm = 0.0
        duration = 0

        info = entry.find("INFO")
        if info is not None:
            key = info.get("KEY", "")
            duration = int(float(info.get("PLAYTIME", 0)))

        tempo = entry.find("TEMPO")
        if tempo is not None:
            bpm = float(tempo.get("BPM", 0.0))

        loc = entry.find("LOCATION")
        location = ""
        if loc is not None:
            volume = loc.get("VOLUME", "")
            dir_path = loc.get("DIR", "").replace("/:", "/")
            file_name = loc.get("FILE", "")
            location = f"{volume}{dir_path}{file_name}"

        tracks.append({
            "location": location,
            "artist": artist,
            "title": title,
            "key": key,
            "bpm": bpm,
            "duration": duration
        })
    return tracks


def create_rekordbox_xml(playlist_name, tracks, output_xml):
    """Generate standard Rekordbox XML structure."""
    rb = ET.Element("DJ_PLAYLISTS", Version="1.0.0")
    ET.SubElement(rb, "PRODUCT", Name="rekordbox", Version="6.8.0", Company="AlphaTheta")

    collection = ET.SubElement(rb, "COLLECTION", Entries=str(len(tracks)))
    playlists_elem = ET.SubElement(rb, "PLAYLISTS")
    root_node = ET.SubElement(playlists_elem, "NODE", Type="0", Name="ROOT", Count="1")
    playlist_node = ET.SubElement(root_node, "NODE", Name=playlist_name, Type="1", KeyType="0", Entries=str(len(tracks)))

    for idx, t in enumerate(tracks, start=1):
        track_id = str(idx)
        loc = t.get("location", "")
        # Format location as file:// URL for Rekordbox
        loc_url = "file://localhost" + loc if loc.startswith("/") else loc

        ET.SubElement(
            collection,
            "TRACK",
            TrackID=track_id,
            Name=t.get("title", f"Track {idx}"),
            Artist=t.get("artist", "Unknown Artist"),
            TotalTime=str(int(t.get("duration", 0))),
            AverageBpm=f"{t.get('bpm', 138.0):.2f}" if t.get('bpm') else "138.00",
            Tonality=t.get("key", ""),
            Location=loc_url
        )

        ET.SubElement(playlist_node, "TRACK", Key=track_id)

    # Format prettily
    xml_str = ET.tostring(rb, encoding="utf-8")
    parsed_xml = xml.dom.minidom.parseString(xml_str)
    pretty_xml = parsed_xml.toprettyxml(indent="  ", encoding="utf-8").decode("utf-8")

    with open(output_xml, "w", encoding="utf-8") as f:
        f.write(pretty_xml)

    print(f"[✓] Successfully exported Rekordbox XML with {len(tracks)} tracks to: {output_xml}")


def main():
    parser = argparse.ArgumentParser(description="Export Playlists / Traktor Histories to Pioneer Rekordbox XML")
    parser.add_argument("input_file", help="Path to Traktor .nml, .m3u, or .m3u8 playlist")
    parser.add_argument("--name", "-n", help="Playlist name inside Rekordbox (default: filename stem)", default=None)
    parser.add_argument("--output", "-o", help="Output .xml file path", default=None)

    args = parser.parse_args()
    input_path = Path(args.input_file).resolve()

    if not input_path.is_file():
        print(f"Error: File '{args.input_file}' not found.", file=sys.stderr)
        sys.exit(1)

    pl_name = args.name or input_path.stem
    output_xml = args.output or input_path.parent / f"{pl_name}_rekordbox.xml"

    ext = input_path.suffix.lower()
    if ext == ".nml":
        tracks = parse_traktor_nml(input_path)
    elif ext in [".m3u", ".m3u8"]:
        tracks = parse_m3u(input_path)
    else:
        print("Error: Unsupported input format. Please provide a .nml or .m3u/.m3u8 playlist.", file=sys.stderr)
        sys.exit(1)

    if not tracks:
        print(f"Warning: No tracks could be extracted from {input_path.name}.")
        sys.exit(0)

    create_rekordbox_xml(pl_name, tracks, output_xml)


if __name__ == "__main__":
    main()
