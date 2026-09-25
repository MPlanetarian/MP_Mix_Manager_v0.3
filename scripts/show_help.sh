#!/usr/bin/env bash
# ==============================================================================
# MP_Mix_Manager_v0.3 - Help Usage & Available Options
# Purpose: Display help usage and all available options for mix-archive-manager
# Usage:
#   mix-archive-manager --help
#   mix-archive-manager -h
# ==============================================================================

set -euo pipefail

# Resolve codebase directory
_RESOLVED_SRC="${BASH_SOURCE[0]}"
while [ -h "$_RESOLVED_SRC" ]; do
    _RESOLVED_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
    _RESOLVED_SRC="$(readlink "$_RESOLVED_SRC")"
    [[ $_RESOLVED_SRC != /* ]] && _RESOLVED_SRC="$_RESOLVED_DIR/$_RESOLVED_SRC"
done
_SCRIPT_DIR="$(cd -P "$(dirname "$_RESOLVED_SRC")" >/dev/null 2>&1 && pwd)"
if [ "$(basename "$_SCRIPT_DIR")" = "scripts" ]; then
    CODEBASE_DIR="$(cd -P "$_SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"
else
    CODEBASE_DIR="$_SCRIPT_DIR"
fi
unset _RESOLVED_SRC _RESOLVED_DIR _SCRIPT_DIR

# Determine version
VERSION="0.3.0"
if [ -f "$CODEBASE_DIR/VERSION" ]; then
    VERSION="$(head -n 1 "$CODEBASE_DIR/VERSION" | tr -d ' \t\r\n')"
fi

# Terminal colors (respect NO_COLOR and non-interactive output)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    NC=$'\033[0m'
    CYAN=$'\033[38;5;51m'
    GREEN=$'\033[38;5;48m'
    YELLOW=$'\033[38;5;226m'
    BLUE=$'\033[38;5;45m'
    MAGENTA=$'\033[38;5;198m'
    RED=$'\033[38;5;196m'
else
    BOLD=''
    DIM=''
    NC=''
    CYAN=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    RED=''
fi

cat << EOF
${BOLD}${MAGENTA}===================================================================================${NC}
${BOLD}${MAGENTA}                     Mix Archive Manager (MP_Mix_Manager_v${VERSION})                     ${NC}
${BOLD}${MAGENTA}===================================================================================${NC}
${DIM}Comprehensive DJ Mix Ingestion, Transcoding, Playback, Video & Archive Suite${NC}

${BOLD}USAGE:${NC}
  ${CYAN}mix-archive-manager${NC} [${GREEN}OPTIONS${NC}] [${YELLOW}COMMAND${NC} | ${YELLOW}OPTION_NUMBER${NC}]
  ${CYAN}./Mix_Archive_Manager.sh${NC} [${GREEN}OPTIONS${NC}] [${YELLOW}COMMAND${NC} | ${YELLOW}OPTION_NUMBER${NC}]

${BOLD}DESCRIPTION:${NC}
  When executed without arguments, launches the interactive full-screen terminal
  menu. You can also supply launch flags, shortcut commands, or specific menu option
  numbers to execute operations directly.

${BOLD}LAUNCH FLAGS & OPTIONS:${NC}
  ${BOLD}${GREEN}-h, --help, help${NC}
      Display this help usage screen and list all available options.

  ${BOLD}${GREEN}-v, --version, version${NC}
      Display current installed version, Git commit hash, and commit timestamp.

  ${BOLD}${GREEN}update, --update${NC}
      Check for and automatically install the latest updates from remote Git.
      ${DIM}Sub-options:${NC}
        ${GREEN}--check, -c${NC}    Check for updates without installing
        ${GREEN}--force, -f${NC}    Force re-pull and reinstall from remote repository

  ${BOLD}${GREEN}-p, --track, --current-track${NC}
      Print the absolute filesystem path of the currently playing mix track.

  ${BOLD}${GREEN}--strawberry-info${NC}
      Display playback state, track metadata, and file path from Strawberry player.

  ${BOLD}${GREEN}--cliamp-info${NC}
      Display playback state, track metadata, and file path from cliamp player.

${BOLD}AVAILABLE MENU OPTIONS (INTERACTIVE & DIRECT SHORTCUTS):${NC}

  ${BOLD}${BLUE}─── [ SECTION 1: MIX ARCHIVE WORKFLOW & INGESTION ] ─────────────────────────${NC}
   ${BOLD}${CYAN}1${NC}   ${BOLD}Run FLAC Conversion Process${NC}
       Batch transcode audio to FLAC using Make_SOF_FLAC_CONVERSION.sh.
   ${BOLD}${CYAN}2${NC}   ${BOLD}Convert Audio Formats, Bit Depths & Split FLACs${NC}
       Convert to WAV, MP3, AAC, 16/24-bit depths, or split cue/audio files.
   ${BOLD}${CYAN}3${NC}   ${BOLD}Retrieve Unconverted WAVs from Archive${NC}
       Move pending uncompressed WAV files from archive storage to working space.
   ${BOLD}${CYAN}4${NC}   ${BOLD}Search & Import Mixes from Local Drives & SMB${NC}
       Scan internal/external drives and SMB shares to import new mixes.
   ${BOLD}${CYAN}5${NC}   ${BOLD}Rename a Mix and Associated Assets${NC}
       Coherently rename FLAC audio, tracklist text files, and Spek spectrograms.
   ${BOLD}${CYAN}6${NC}   ${BOLD}Find & Remove Duplicate Audio Files / Mixes${NC}
       Scan for duplicate content by audio hash or matching episode stems.
   ${BOLD}${CYAN}7${NC}   ${BOLD}Export / Copy Mixes to Specified Path${NC}
       Export selected mixes with artwork, tracklists, and spectrogram assets.
   ${BOLD}${CYAN}8${NC}   ${BOLD}Audio Integrity Checksums & FLAC Verification Suite${NC}
       Generate and verify SHA-256 manifests and FLAC stream decode integrity.
   ${BOLD}${CYAN}9${NC}   ${BOLD}Cloud & Remote Backup Suite${NC}
       Backup mixes to Google Drive, iCloud, Dropbox, or custom local/remote path.
  ${BOLD}${CYAN}10${NC}   ${BOLD}Storage Management & Multiple Mix Archives Setup${NC}
       Analyze storage capacity, rescan archives, and configure multi-archive storage.

  ${BOLD}${BLUE}─── [ SECTION 2: STUDIO AUDIO, PLAYBACK, METADATA & VIDEO ] ──────────────────${NC}
  ${BOLD}${CYAN}11${NC}   ${BOLD}Tracklist Management, Scanning & Metadata Suite${NC}
       Search tracklists, edit metadata via Picard, and generate HTML mix indexes.
  ${BOLD}${CYAN}12${NC}   ${BOLD}Audio Players & Retro Playback Suite${NC}
       Launch cliamp, Strawberry, VLC, Audacity, Haruna, Winamp, or Kodi.
  ${BOLD}${CYAN}13${NC}   ${BOLD}Configure Mix Archive Storage Locations${NC}
       Set primary and secondary archive folders, view disk space & master mix tallies.
  ${BOLD}${CYAN}14${NC}   ${BOLD}Custom Mix Playlists & Traktor History Suite${NC}
       Generate .m3u, .m3u8, .xspf playlists and parse Traktor 3 DJ set history.
  ${BOLD}${CYAN}15${NC}   ${BOLD}Digital Audio Workstations (DAWs) & Mix Dispatch${NC}
       Launch Reaper, Logic Pro, FL Studio, Ardour, or Traktor Pro.
  ${BOLD}${CYAN}16${NC}   ${BOLD}Studio Hardware, Audio Interfaces & Master Volume Control${NC}
       Manage PipeWire/ALSA sound cards, buffer latency, MIDI devices, and levels.
  ${BOLD}${CYAN}17${NC}   ${BOLD}Spectrogram Generation & Audio Frequency Analysis${NC}
       Generate Spek spectrograms, SoX frequency plots, and Praat acoustic analysis.
  ${BOLD}${CYAN}18${NC}   ${BOLD}Morning Alarm Clock & DJ Mix Playback Suite${NC}
       Wake up to random archive mixes, 3-min volume ramp, Steam breakfast games, daily brief & DJ playback scheduler.
  ${BOLD}${CYAN}19${NC}   ${BOLD}YouTube Video Generation Suite${NC}
       Render 4K UHD, 1080p, or 720p companion YouTube videos with hardware NVENC.
  ${BOLD}${CYAN}20${NC}   ${BOLD}Visual Media, Cover Art & Companion Video Suite${NC}
       Split/cut videos, create PPM banners, and manage visual art assets.
  ${BOLD}${CYAN}21${NC}   ${BOLD}Record Video of DJ Mix using GPU Screen Recorder (Linux)${NC}
       Open GPU Screen Recorder in a new desktop window, then return to the menu.

  ${BOLD}${BLUE}─── [ SECTION 3: SYSTEM, NETWORK, AI & SETTINGS ] ────────────────────────────${NC}
  ${BOLD}${CYAN}22${NC}   ${BOLD}Live Session, Stream & Transfer Monitors Suite${NC}
       Monitor active audio streams, live tracklists, Traktor logs, and uploads.
  ${BOLD}${CYAN}23${NC}   ${BOLD}System & Hardware Process Monitors Suite${NC}
       Launch btop resource monitor, nvtop GPU monitor, or top process monitor.
  ${BOLD}${CYAN}24${NC}   ${BOLD}View Advanced Archive Statistics${NC}
       Run SOF_Archive_Stats.sh to display detailed multi-drive archive analytics.
  ${BOLD}${CYAN}25${NC}   ${BOLD}Promotional Outreach, Syndication & Music Shopping${NC}
       Send promotional emails, syndicate RSS/podcasts, browse Bandcamp/Beatport.
  ${BOLD}${CYAN}26${NC}   ${BOLD}Network Services & Internet Access Control${NC}
       Manage SSH, Samba, FTP servers, or toggle internet connectivity block.
  ${BOLD}${CYAN}27${NC}   ${BOLD}Desktop Display Settings, Audio Routing & App Control${NC}
       Configure Wayland/X11, display scaling, audio routing, or kill audio apps.
  ${BOLD}${CYAN}28${NC}   ${BOLD}Universal System Maintenance & Cleanup${NC}
       Reclaim drive space, clean package manager caches, update OS packages.
  ${BOLD}${CYAN}29${NC}   ${BOLD}AI Assistant & Local LLM Servers Suite${NC}
       Manage Claude, GPT, Ollama (:11434), DeepSeek (:3080), WAN2GP, and Beszel (:8090).
  ${BOLD}${CYAN}30${NC}   ${BOLD}Dynamic MOTD Banner Manager & Drive Burner${NC}
       Generate custom login MOTDs with recent mixes, or burn ISO images to USB.
  ${BOLD}${CYAN}31${NC}   ${BOLD}Manager Settings, Themes, Shell CLI & Reboot${NC}
       Switch color themes (Dracula, Nord, Cyberpunk, etc.), migrate paths, reboot.
  ${BOLD}${CYAN}32${NC}   ${BOLD}Exit Manager${NC} (or 0 / q)
       Exit the application cleanly.

${BOLD}DIRECT COMMAND SHORTCUTS:${NC}
  You can execute these shortcuts directly from the command line:
    ${CYAN}split-flac${NC}        Split continuous FLAC audio via CUE sheet or track boundaries
    ${CYAN}split-video${NC}       Split video clips into segments
    ${CYAN}cut-video${NC}         Trim / cut video clips by timestamps
    ${CYAN}btop${NC}              Launch btop interactive hardware monitor
    ${CYAN}nvtop${NC}             Launch nvtop GPU performance monitor
    ${CYAN}top${NC}               Launch standard top process monitor
    ${CYAN}beszel${NC}            Manage Beszel Hub & Agent monitoring services
    ${CYAN}ollama${NC}            Manage Ollama LLM server & chat sessions
    ${CYAN}dsh${NC}               Manage DeepSeek Mobile Harness server
    ${CYAN}inspect${NC} | ${CYAN}specs${NC}   Inspect audio specifications of currently playing mix
    ${CYAN}audacity${NC}          Launch Audacity digital audio editor
    ${CYAN}strawberry${NC}        Launch Strawberry music player
    ${CYAN}vlc${NC}               Launch VLC media player
    ${CYAN}haruna${NC}            Launch Haruna video player
    ${CYAN}gimp${NC}              Launch GIMP image editor
    ${CYAN}electricsheep${NC}     Launch Electric Sheep screensaver
    ${CYAN}geexlab${NC}           Launch GeeXLab 3D demos
    ${CYAN}gpu-screen-recorder${NC}  Record a DJ mix with GPU Screen Recorder (Linux)
    ${CYAN}alarm${NC} | ${CYAN}alarm-clock${NC}   Launch MPlanetarians Alarm Clock (Wake Up Edition)

${BOLD}EXAMPLES:${NC}
  ${DIM}# Launch interactive terminal UI:${NC}
  ${GREEN}mix-archive-manager${NC}

  ${DIM}# Launch morning alarm clock control:${NC}
  ${GREEN}mix-archive-manager alarm${NC}

  ${DIM}# Display help usage and all available options:${NC}
  ${GREEN}mix-archive-manager --help${NC}
  ${GREEN}mix-archive-manager -h${NC}

  ${DIM}# Display version information:${NC}
  ${GREEN}mix-archive-manager --version${NC}

  ${DIM}# Check for and install software updates:${NC}
  ${GREEN}mix-archive-manager update${NC}

  ${DIM}# Directly jump into Option 13 (Configure Mix Archive Storage):${NC}
  ${GREEN}mix-archive-manager 13${NC}

  ${DIM}# Directly launch btop resource monitor:${NC}
  ${GREEN}mix-archive-manager btop${NC}

  ${DIM}# Query path of currently playing mix track:${NC}
  ${GREEN}mix-archive-manager --track${NC}

EOF
