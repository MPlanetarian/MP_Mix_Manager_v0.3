# MPlanetarians Alarm Clock (Wake Up Edition)

Version 0.1 by MPlanetarian.

A command-line alarm clock written in Bash. It plays a shuffled mix loudly through Strawberry or cliamp, watches the mouse, and opens with a morning brief so the day can start.

```bash
git clone https://github.com/MPlanetarian/MPlanetarians_Alarm_Clock_v0.1.git
cd MPlanetarians_Alarm_Clock_v0.1
chmod +x alarm.sh
ln -sfn "$PWD/alarm.sh" ~/.local/bin/mplanetarians-alarm
mplanetarians-alarm
```

## What happens at alarm time

The clock picks **Strawberry** or **cliamp** at random, so it does not use cliamp every morning. It unmutes the speakers and starts quietly, then turns the volume up until it reaches the full alarm level at 3 minutes. Snooze plays at full volume straight away. It plays a shuffled mix from the playlist already loaded in that player. If nothing is ready, it adds one random mix from the local archive disks. Google Drive is skipped.

Move the mouse to stop the alarm. Your default web browser then opens on the display to the right of the screen you are using. A saved browser address opens there. The clock tells you how long you took and compares that with earlier mornings. If the mouse stays still for 10 minutes, a different local mix starts.

You can still add one console window as an extra wake-up action.

## Commands

```bash
mplanetarians-alarm set 07:30 --daily --volume 100
mplanetarians-alarm list
mplanetarians-alarm snooze 10
mplanetarians-alarm stop
mplanetarians-alarm disable
mplanetarians-alarm enable
mplanetarians-alarm theme forest-hour
mplanetarians-alarm task browser https://example.com
mplanetarians-alarm task console
mplanetarians-alarm task clear
mplanetarians-alarm note add "Stretch before coffee"
mplanetarians-alarm test
```

`set` accepts `07:30`, `6:45am`, or `1930`. `--daily` repeats every day. Without it, the alarm rings once. `--music PATH` forces one file instead of the player playlist.

## Themes

- **Midnight Ink** — navy and silver
- **Warm Brass** — amber lamp-light
- **Forest Hour** — deep green and gold
- **Porcelain** — warm grey and rose

## Morning screen

When the program opens it shows:

- An animated clock and version 0.1
- A phrase of the day and a word of the day from the internet
- A random manual page, with its name and a short description
- The date, the time, and the uptime
- CPU, memory, disks, GPU, USB devices, and the monitor layout
- The last three desktop applications
- Important overnight errors from the system journal, or a clear line when there are none
- Your notes
- A breakfast idea, a short exercise routine, the day's weather, and a rain alert when rain is expected
- Three random games from your Steam library, and the question of whether you would like to play one for breakfast
- The last Bash command, and the kernel line from `uname -a`

## Logs

Activity, including schedules and settings, is appended to:

`~/.local/state/mplanetarians-alarm-clock/alarm.log`

Wake-up times are kept in:

`~/.local/state/mplanetarians-alarm-clock/wakeups.tsv`

Saved alarms, the theme, notes, and the single wake-up action live in:

`~/.config/mplanetarians-alarm-clock/`

## Requirements

Bash, a graphical session, systemd (your user session), PipeWire `wpctl`, `xdotool`, and either Strawberry or cliamp. Weather, the phrase, and the word of the day need a network connection. The computer has to be switched on. A missed alarm rings the next time you log in.

`disable` turns the whole clock off and keeps the saved alarms for later. `cancel` removes alarms. `snooze` is for when you are awake enough to ask for more time, and it does not count as the morning wake-up.
