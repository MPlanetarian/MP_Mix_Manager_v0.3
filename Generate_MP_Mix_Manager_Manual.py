#!/usr/bin/env python3
"""
MP_Mix_Manager_v0.3 Professional PDF Manual Generator
Uses ReportLab Platypus to construct a print-ready vector PDF manual.
"""

import os
import sys
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Image, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    """Two-pass canvas to dynamically compute and draw total page numbers."""
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        if self._pageNumber == 1:
            return  # Suppress headers and footers on the cover page

        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#718096"))

        # Running Header
        self.drawString(54, letter[1] - 36, "MPlanetarian // MP_Mix_Manager_v0.3")
        self.drawRightString(letter[0] - 54, letter[1] - 36, "OPERATIONS & ARCHIVE MANUAL")
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.5)
        self.line(54, letter[1] - 42, letter[0] - 54, letter[1] - 42)

        # Running Footer
        self.setFont("Helvetica", 8)
        self.drawString(54, 34, "Stream of Frequency // Electronic Music Workstation Console")
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(letter[0] - 54, 34, page_str)
        self.line(54, 44, letter[0] - 54, 44)
        self.restoreState()


def build_pdf(filename="MPlanetarian_MP_Mix_Manager_v0.3_Manual.pdf"):
    # Target page setup with 0.75-inch (54 pt) margins
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    printable_width = letter[0] - 108  # 504 pt

    styles = getSampleStyleSheet()
    
    # Custom Palette
    c_primary = colors.HexColor("#0F172A")    # Deep slate
    c_accent  = colors.HexColor("#4338CA")    # Indigo
    c_text    = colors.HexColor("#1E293B")    # Slate dark
    c_border  = colors.HexColor("#E2E8F0")

    # Typography Styles
    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=28,
        textColor=c_primary,
        alignment=1
    )
    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=11,
        leading=16,
        textColor=colors.HexColor("#475569"),
        alignment=1
    )
    badge_style = ParagraphStyle(
        'CoverBadge',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=12,
        textColor=c_accent,
        alignment=1
    )
    h1_style = ParagraphStyle(
        'SectionHeading',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=c_primary,
        spaceBefore=14,
        spaceAfter=6,
        keepWithNext=True
    )
    h2_style = ParagraphStyle(
        'SubHeading',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=10.5,
        leading=14,
        textColor=c_accent,
        spaceBefore=8,
        spaceAfter=4,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=c_text
    )
    callout_style = ParagraphStyle(
        'CalloutText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=colors.HexColor("#0F172A")
    )
    th_style = ParagraphStyle(
        'TH',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10,
        textColor=colors.white
    )
    td_num = ParagraphStyle(
        'TDNum',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10.5,
        textColor=c_accent,
        alignment=1
    )
    td_op = ParagraphStyle(
        'TDOp',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10.5,
        textColor=c_primary
    )
    td_desc = ParagraphStyle(
        'TDDesc',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.5,
        leading=10,
        textColor=colors.HexColor("#334155")
    )

    story = []

    # ---------------------------------------------------------
    # 1. FRONT COVER
    # ---------------------------------------------------------
    story.append(Spacer(1, 15))
    story.append(Paragraph("M P L A N E T A R I A N", ParagraphStyle('Artist', parent=badge_style, fontSize=11, leading=14, textColor=c_primary)))
    story.append(Spacer(1, 4))
    story.append(Paragraph("STREAM OF FREQUENCY WORKSTATION SUITE", ParagraphStyle('SubA', parent=badge_style, fontSize=8, leading=10, textColor=colors.HexColor("#64748B"))))
    story.append(Spacer(1, 14))

    # Album artwork placement
    cover_image_path = None
    for cand in ["Cover.png", "Cover.jpg", "cover.png", "cover.jpg", "Maenfact EP [Available on the 21st of June 2026] PRE ORDER NOW [album].jpg"]:
        if os.path.exists(cand):
            cover_image_path = cand
            break

    if cover_image_path:
        story.append(Image(cover_image_path, width=4.0 * inch, height=4.0 * inch))
    else:
        # Placeholder frame if script is run outside repository folder
        story.append(HRFlowable(width="60%", thickness=1, color=c_border, spaceBefore=40, spaceAfter=40))

    story.append(Spacer(1, 16))
    story.append(Paragraph("Mix Archive Manager", title_style))
    story.append(Paragraph("v0.3.0 Standard Reference Manual", ParagraphStyle('V', parent=title_style, fontSize=14, leading=18, textColor=c_accent)))
    story.append(Spacer(1, 10))
    story.append(Paragraph("Cross-Platform Media Orchestration Console & Lossless FLAC Mastering Suite", subtitle_style))
    story.append(Spacer(1, 12))

    meta_text = "<b>Platforms:</b> Linux (Bazzite / SteamOS / Fedora) &bull; macOS (Sequoia / Sonoma) &bull; Windows 10/11 &bull; FreeBSD<br/><b>Core Architecture:</b> Bash 5.x &bull; Python 3.11+ &bull; 32-Bit Lossless FLAC &bull; MIT License"
    story.append(Paragraph(meta_text, ParagraphStyle('CoverMeta', parent=badge_style, textColor=colors.HexColor("#475569"))))
    story.append(PageBreak())

    # ---------------------------------------------------------
    # 2. OVERVIEW & SPOTLIGHT HIGHLIGHTS
    # ---------------------------------------------------------
    story.append(Paragraph("System Architecture & Highlights", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_accent, spaceBefore=2, spaceAfter=8))
    story.append(Paragraph(
        "<b>Mix Archive Manager (MP_Mix_Manager_v0.3)</b> is a professional workstation orchestration console designed for high-resolution audio mastering, multi-hour DJ recording curation, Traktor Pro library management, live stream monitoring, and local AI workflow automation across Linux, macOS, Windows, and FreeBSD.",
        body_style
    ))
    story.append(Spacer(1, 10))

    # Spotlight 1: Alarm Clock Box
    alarm_box_data = [[
        Paragraph(
            "<b>SPOTLIGHT: MPlanetarians Alarm Clock (Wake Up Edition)</b><br/>"
            "&bull; <b>Lossless FLAC Wake-Up:</b> Selects a random mix from local archive drives and executes a 3-minute linear volume ramp (0% &rarr; 100%) in Strawberry or cliamp.<br/>"
            "&bull; <b>Active Motion Verification:</b> Detects physical mouse movements to silence the alarm. If stationary for 10 minutes, an alternate mix is triggered.<br/>"
            "&bull; <b>Right-Monitor Browser Geometry:</b> Calculates active display geometries and opens your morning browser window on the display to the right.<br/>"
            "&bull; <b>Steam Breakfast Selector:</b> Scans local <code>libraryfolders.vdf</code> files and presents 3 random video games to launch directly via one keypress.",
            callout_style
        )
    ]]
    t_alarm = Table(alarm_box_data, colWidths=[printable_width])
    t_alarm.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#CBD5E1")),
        ('LINEBEFORE', (0,0), (0,-1), 4, c_accent),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_alarm)
    story.append(Spacer(1, 10))

    # Spotlight 2: Traktor Harmonic Prep Box
    traktor_box_data = [[
        Paragraph(
            "<b>SPOTLIGHT: Traktor Pro Live Session History to 4-Deck Prep</b><br/>"
            "&bull; <b>Automated Discovery:</b> Automatically locates and reads <code>collection.nml</code> and <code>History.nml</code> across Traktor 3 and Traktor Pro 4 without manual path setup.<br/>"
            "&bull; <b>Harmonic Key Sorting:</b> Reconstructs past live setlists in ascending Camelot musical key order (1A&ndash;12B) to guarantee compatible initial transitions.<br/>"
            "&bull; <b>Root Collection Injection:</b> Generates a verified NML playlist directly into Traktor's root library tree (<code>$ROOT</code>).<br/>"
            "&bull; <b>Full-Screen Stage Launch:</b> Brings Traktor Pro to the foreground in full-screen mode and pre-loads Decks A, B, C, and D with the first four tracks ready to mix.",
            callout_style
        )
    ]]
    t_traktor = Table(traktor_box_data, colWidths=[printable_width])
    t_traktor.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F8FAFC")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#CBD5E1")),
        ('LINEBEFORE', (0,0), (0,-1), 4, colors.HexColor("#059669")),
        ('TOPPADDING', (0,0), (-1,-1), 8),
        ('BOTTOMPADDING', (0,0), (-1,-1), 8),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(t_traktor)
    story.append(Spacer(1, 14))

    # ---------------------------------------------------------
    # 3. CORE FEATURE MATRIX (78 OPERATIONS)
    # ---------------------------------------------------------
    story.append(Paragraph("Core Feature Matrix (78 Console Operations)", h1_style))
    story.append(HRFlowable(width="100%", thickness=1, color=c_accent, spaceBefore=2, spaceAfter=8))

    sections = [
        ("Section 1: Mix Archive Workflow & Ingestion", [
            ("01", "Run FLAC Conversion Process", "Concatenates split WAV files, master encodes to 32-bit FLAC (-sample_fmt s32 -compression_level 12), embeds resized artwork, and outputs acoustic spectrograms."),
            ("02", "Convert Formats & Split FLACs", "Transcodes audio between MP3 (320k, V0, 256k), Ogg, Opus, AAC, ALAC, and WAV bit depths; includes sample-accurate lossless FLAC splitting into equal segments."),
            ("03", "Retrieve Unconverted WAVs", "Scans archive directories and isolates WAV stems missing a processed master FLAC counterpart."),
            ("04", "Search & Import Mixes", "Auto-discovers external USB drives, local storage, and SMB network shares; filters files >= 100MB, deduplicates, and transfers with live logs."),
            ("05", "Rename Mix Assets", "Atomically renames FLAC audio, TXT tracklists, and spectrogram PNGs uniformly across all archive directories."),
            ("06", "Duplicate File Removal", "Executes fast chunk-based hashing to identify identical mixes and moves them to quarantine or deletes them."),
            ("07", "Export/Package Mixes", "Copies complete release packages (FLAC + Cover Art + TXT/HTML/PDF Tracklists + Spectrograms) to external storage drives."),
            ("08", "Manage SHA-256 Checksums", "Generates and validates checksums.sha256 manifests across audio libraries to protect archives against bit rot."),
            ("09", "Verify FLAC Integrity", "Runs multi-threaded decode passes across all CPU cores to detect and quarantine damaged FLAC bitstreams."),
            ("10", "Cloud & Remote Backup", "Automated backup suite targeting Google Drive, iCloud, Dropbox, and external directories with companion asset support."),
            ("11", "Mix Storage Drive Space", "Displays filesystem mount capacity, active usage progress bar, and hosted audio file counts on primary archive volumes."),
            ("12", "Refresh Archive Status", "Clears cache and performs full recounts of pending WAVs, converted WAVs, FLAC masters, and tracklists."),
            ("13", "Configure Storage Path", "Sets default storage path override (defaults to /run/media/$USER/WD_BLACK_B/MIX_ARCHIVE/ or MIX_ARCHIVE/).")
        ]),
        ("Section 2: Tracklist, Metadata & Promotion", [
            ("14", "Tracklist Suite", "Browses, searches, and exports tracklists to styled HTML and printable vector PDF documents."),
            ("15", "Mix Search & Live Playback", "Searches archive catalog, initiates cliamp playback, and displays live setlists in the console."),
            ("16", "Scan Missing Tracklists", "Parses Traktor Pro collection.nml history files to generate timestamped text tracklists."),
            ("17", "Master Tracklist Index", "Compiles all individual tracklists into a single, unified searchable HTML index file."),
            ("18", "MusicBrainz Picard", "Launches Picard audio tagger; automatically installs missing dependencies across platforms."),
            ("19", "Promo & Outreach Emailer", "Formats and delivers promotional emails to labels, publishers, and club promoters with artwork and cue attachments."),
            ("20", "Multi-Platform Syndication", "Release scheduler managing Apple Podcasts, Spotify, YouTube, SoundCloud, Mixcloud, DI.FM, Proton Radio, and Bandcamp with .ics / RSS exports."),
            ("21", "Music Store Quick-Launch", "Parallel browser dispatcher for Beatport, Apple Music, and Bandcamp store portals.")
        ]),
        ("Section 3: Audio Playback, DAWs & Sound Suite", [
            ("22", "DAWs Launch Hub", "Unified launcher for REAPER, Logic Pro, FL Studio, Traktor Pro, GarageBand, Ardour, LMMS, Bitwig, and Bespoke Synth."),
            ("23", "Open Mix in DAW", "Searches mixes by keyword and opens stems directly in REAPER, Logic Pro, FL Studio, or Audacity."),
            ("24", "Spectrogram Analysis Suite", "Renders in-place acoustic spectrograms using Spek, SoX 24-bit colormaps, Sonic Visualiser, and Praat."),
            ("25", "Audacity Audio Editor", "Launches Audacity or installs via Homebrew, Flatpak, winget, or native package managers."),
            ("26", "Audio Players Menu", "Quick launch hub for cliamp, Strawberry, VLC, foobar2000, Winamp, Apple Music, Haruna, and Kodi."),
            ("27", "Configure Audio Engine", "Sets default audio/video players, startup auto-play toggles, and console tracklist preferences."),
            ("28", "cliamp Terminal Player", "Built-in retro CLI audio player featuring cross-platform clipboard copying (pbcopy, clip.exe, wl-copy)."),
            ("29", "Audio Stream Specs HUD", "Probes bit depth (16/24/32-bit), sample rate (48 kHz), bitrate, compression ratios, and paired companion assets."),
            ("30", "Archive Playlists Suite", "Builds, synchronizes, and exports .m3u8 and .xspf playlists to Strawberry, VLC, mpv, or Kodi."),
            ("31", "Strawberry Music Player", "Opens Strawberry Music Player in a separate desktop window."),
            ("32", "VLC Media Player", "Launches VLC audio/video media player."),
            ("33", "Traktor Harmonic Prep / Haruna", "macOS: Sorts Traktor session history into harmonic Camelot keys (1A-12B), injects into root, and pre-loads Decks A-D. Linux: Launches Haruna."),
            ("34", "Kodi Media Center", "Launches Kodi home theater software."),
            ("35", "Connected USB MIDI Devices", "Enumerates connected MIDI synthesizers, DJ controllers, and hardware control surfaces."),
            ("36", "Studio Hardware Diagnostics", "Probes active PipeWire/ALSA audio sinks, sample rates, buffer latencies, and connected studio interfaces."),
            ("37", "Master Audio Volume Toggle", "Instantly mutes or unmutes system master audio via PipeWire wpctl, pactl, or AppleScript."),
            ("38", "Morning Alarm Clock", "Morning wake-up alarm with lossless volume ramp, mouse motion wake detection, and Steam breakfast game launcher.")
        ]),
        ("Section 4: Video Production, Art & Visual Media", [
            ("39", "Generate YouTube Video", "Encodes 4K UHD, 1080p, and 720p YouTube videos using NVENC/VideoToolbox hardware acceleration and 320k AAC audio."),
            ("40", "Cut or Split Video File", "Precision timestamp cutter and equal-segment video splitter supporting stream-copy or re-encoding."),
            ("41", "Launch Video Playlists", "Launches Defasten or visual companion playlists in VLC, mpv, or Haruna."),
            ("42", "Launch Specific Video", "Dispatches user-specified video files or streaming URLs to the default video playback engine."),
            ("43", "GIMP Image Editor", "Launches GIMP image editor or installs missing dependencies via system package manager."),
            ("44", "Convert Cover Art", "Converts artwork between JPEG, WebP, PNG, and TIFF with strict binary byte budgeting (<= 1MB podcast standard)."),
            ("45", "View Cover by Mix Number", "Searches COVERS/ directory by episode number and opens the artwork in the system image viewer."),
            ("46", "Procedural Netpbm Art", "Pure algorithmic P6 binary PPM art engine: renders mathematical gradients (linear, plasma, angular) with typography overlays."),
            ("47", "Electric Sheep Screensaver", "Launches Electric Sheep generative screensaver visualizer."),
            ("48", "Sync Video Companion", "Background daemon monitoring audio playback to auto-launch and sync matching video companions."),
            ("49", "GPU Screen Recorder (Linux)", "Launches hardware-accelerated DJ set video capture via gpu-screen-recorder-gtk or Flatpak.")
        ]),
        ("Section 5: Live Monitors & System Diagnostics", [
            ("50", "Live Tracklist Monitor", "Real-time console display tracking Strawberry MPRIS and cliamp playback progress."),
            ("51", "Traktor Live Monitor", "Cross-platform monitor displaying Traktor CPU %, RAM, deck states, active recording file locks, and AppleScript triggers."),
            ("52", "Live File Transfer Monitor", "Inspects transfer speeds, byte positions, and percentage for huge multi-gigabyte files."),
            ("53", "Chrome Upload Monitor", "Monitors web browser upload processes (Apple Podcasts Connect, YouTube Studio) in real time."),
            ("54", "Advanced Archive Statistics", "Calculates total audio duration, file counts, storage footprint, and tracklist completeness."),
            ("55", "View Running Background Tasks", "Scans process tables for active ffmpeg transcode passes, cloud syncs, or AI jobs."),
            ("56", "System Resource Monitor", "Launches btop for multi-core CPU and memory profiling."),
            ("57", "GPU Process Monitor", "Launches nvtop for real-time monitoring of NVIDIA GPU clock, VRAM, and power draw."),
            ("58", "Standard Process Viewer", "Quick-launches top inside the active manager terminal session.")
        ]),
        ("Section 6: System, Network & Remote Hardware", [
            ("59", "WAN2GP Video AI Server", "Manages WAN2GP AI video server profiles (Flux Klein 9B, LTX Video 2B/13B)."),
            ("60", "Beszel Monitoring Suite", "Manages Beszel server monitoring hub and hardware monitoring agent daemons."),
            ("61", "Ollama LLM Container Server", "Controls Ollama container instances (Qwen 2.5, Llama 3.1) with interactive chat options."),
            ("62", "DeepSeek Harness (dsh-mobile)", "Controls DeepSeek mobile web portal (pnpm dsh web) over local LAN (port 3080)."),
            ("63", "Network & Congen KDE Connect", "Controls SSH, Samba, and FTP daemons, plus the Congen KDE Connect smartphone remote controller."),
            ("64", "Block Internet Access", "Enables isolated firewall rules blocking WAN traffic while preserving local LAN transfers."),
            ("65", "Restore Internet Access", "Restores immediate full internet connectivity."),
            ("66", "Display Settings (OS Tailored)", "Opens Plasma Wayland display settings, macOS Display Settings, or Windows ms-settings:display."),
            ("67", "Audio Settings (OS Tailored)", "Opens Plasma X11, Audio MIDI Setup on macOS, or Windows Sound Panel."),
            ("68", "Close Desktop Applications", "Gracefully closes external desktop windows using AppleScript, PowerShell, or wmctrl."),
            ("69", "System Maintenance & Cleanup", "Executes platform maintenance (Linux ujust clean-system, macOS brew cleanup, Windows TRIM/winget, FreeBSD pkg clean)."),
            ("70", "GeeXLab Demo Launcher", "Runs 3D/OpenGL shader demos and GPU stress benchmarks."),
            ("71", "Burn ISO to USB Drive", "Writes bootable ISO images directly to removable USB storage with verification passes."),
            ("72", "Dynamic System MOTD Banner", "Generates stylized ANSI MOTD table summarizing recent mixes, sizes, formats, and hardware vitals.")
        ]),
        ("Section 7: AI Engine, Shell CLI & Settings", [
            ("73", "AI Assistant CLI (AGY)", "Antigravity CLI assistant interface managing Ollama, DeepSeek, and remote models."),
            ("74", "Interactive Bash Subshell", "Built-in interactive Bash shell and direct command execution runner."),
            ("75", "Terminal Theme Switcher", "Switch between 9 retro terminal palettes (Dracula, Nord, Matrix, Cyberpunk, Solarized, Tokyo Night, Monokai, Gruvbox, Emerald)."),
            ("76", "Config Migration & Snapshots", "Configuration backup and restore engine; exports portable .tar.gz bundles and handles automated updater checks."),
            ("77", "Reboot Workstation", "Cross-platform system reboot with safety confirmation dialogs."),
            ("78", "Exit Manager", "Cleans up and exits the console session.")
        ])
    ]

    col_widths = [26, 148, 330]

    for sec_title, ops in sections:
        sec_elements = []
        sec_elements.append(Paragraph(sec_title, h2_style))

        table_data = [[
            Paragraph("<b>#</b>", th_style),
            Paragraph("<b>Operation</b>", th_style),
            Paragraph("<b>Description</b>", th_style)
        ]]

        for op_num, op_name, op_desc in ops:
            table_data.append([
                Paragraph(op_num, td_num),
                Paragraph(op_name, td_op),
                Paragraph(op_desc, td_desc)
            ])

        t = Table(table_data, colWidths=col_widths, repeatRows=1)
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), c_primary),
            ('ALIGN', (0,0), (-1,-1), 'LEFT'),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('GRID', (0,0), (-1,-1), 0.5, c_border),
            ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor("#F8FAFC")]),
            ('TOPPADDING', (0,0), (-1,-1), 3.5),
            ('BOTTOMPADDING', (0,0), (-1,-1), 3.5),
            ('LEFTPADDING', (0,0), (-1,-1), 4),
            ('RIGHTPADDING', (0,0), (-1,-1), 4),
        ]))
        
        sec_elements.append(t)
        sec_elements.append(Spacer(1, 10))
        story.append(KeepTogether(sec_elements))

    # Build the document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[OK] Generated professional manual: {filename}")

if __name__ == "__main__":
    out_pdf = "MPlanetarian_MP_Mix_Manager_v0.3_Manual.pdf"
    if len(sys.argv) > 1:
        out_pdf = sys.argv[1]
    build_pdf(out_pdf)
