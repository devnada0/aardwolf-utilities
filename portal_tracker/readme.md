# Portal Usage Tracker (MUSHclient plugin)

Tracks portal usage statistics in Aardwolf (or any MUD with similar output) by detecting the **equip portal** line followed by the **WHOOOOOOOOOOOOSH!** travel line. Also tracks usage of the `home` command directly.

## Features

- Counts portal trips based on:
  - `You equip <portal> as a portal.` → then `WHOOOOOOOOOOOOSH!`
  - typing `home` (tracked as `(Command) home`)
- Persists stats across sessions (plugin save state)
- Two report formats:
  - Table view for local review
  - One-line “chat” view for easy copy/paste

## Requirements

- MUSHclient **4.00+**
- Lua scripting enabled
- `serialize` module available (the plugin uses `require "serialize"`)

## Installation

1. Save the plugin XML as `Portal_Usage_Tracker.xml`.
2. In MUSHclient: **File → Plugins → Add** (or drag the file into MUSHclient).
3. Verify it loaded: you should see a message indicating the plugin is loaded.
4. Type:
   - `portal help`

## Commands

- `portal report`  
  Shows a table of portal usage counts, percentages, and total usage.

- `portal report chat`  
  Prints a single-line summary suitable for sharing in chat.

- `portal reset`  
  Clears all statistics and resets the timer.

- `portal help` (or `portal ?`)  
  Displays the built-in help.

## How it works

### Standard portal tracking
The plugin watches for this sequence:
1. `You equip <portal name> as a portal.`
2. `WHOOOOOOOOOOOOSH!`

When both occur in order, it increments the counter for that portal name.

### `home` tracking
Typing `home` is intercepted, counted as `(Command) home`, and then passed through to the MUD via `Send("home")`.

## Data persistence

Stats are stored in plugin variables:
- `stats_data` — serialized table of counts
- `start_time` — session start marker used for duration reporting

These are saved automatically via `OnPluginSaveState()` and restored in `OnPluginInstall()`.

## Output notes

- Table mode shows: count, percent of total, and portal name.
- Chat mode prints: duration, per-portal counts with rounded percent, and total.

## Author

Morienda
