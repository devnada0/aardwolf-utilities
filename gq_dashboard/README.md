# GQ Dashboard

GQ Dashboard is an Aardwolf MUSHclient plugin that displays active Global
Quests in a compact, resizable miniwindow. It shows whether your character can
join, estimates the visible competition, and summarizes which level ranges are
still available in the current GQ cycle.

## Features

- Displays active GQs with their tier, level range, status, timer, and players.
- Colors each row according to your character's level eligibility.
- Estimates visible competition using each GQ tier's win requirements.
- Shows remaining GQ-cycle ranges near your current level.
- Provides clickable GQ information, joining, player lists, and cycle details.
- Supports sound alerts, auto-hide, tier filters, resizing, and saved position.

## Installation

GQ Dashboard requires both of these files:

- [`GQ_Dashboard.xml`](GQ_Dashboard.xml)
- [`GQ_Dashboard.lua`](GQ_Dashboard.lua)

1. Download both files.
2. Keep them together in the same directory under MUSHclient's
   `worlds/plugins` directory.
3. In MUSHclient, open **File > Plugins**, click **Add**, and select
   `GQ_Dashboard.xml`.

MUSHclient's Add Plugin window normally shows only XML files. The Lua file will
not appear in that window, but it must remain beside the XML file.

This plugin is intended for the standard Aardwolf MUSHclient package and uses
helpers included with that package.

## Quick start

After installation, the window opens automatically. A new installation shows
the `200+` win tier by default.

- Drag the title bar to move the window.
- Drag the lower-right corner to resize it.
- Right-click the title bar to configure sound, auto-hide, tier filters, and
  window stacking.
- Use `gqshow` if the window is hidden.

## Reading the window

```text
Num   Tier   Levels   Status   Tmr   Plyrs   Cycle
5400  200+   29-40    Ext      254   2(3)    35(-11,-7,-3)+
```

| Column | Meaning |
| :--- | :--- |
| `Num` | The GQ number. |
| `Tier` | The required GQ-win tier: `<25`, `25-199`, or `200+`. |
| `Levels` | The inclusive level range that can join. |
| `Status` | The current state. `Prep` means Preparing, `Ext` means Extended, and `NA` means no active GQ for that enabled tier. |
| `Tmr` | The server-provided GQ timer. |
| `Plyrs` | Players already joined, followed by the visible competition estimate. |
| `Cycle` | Remaining cycle ranges and the nearest ranges that include or extend above your level. |

### Row colors

- **Green:** Your character is currently inside the GQ level range.
- **Yellow:** The GQ begins one level above you, so you could level and join.
- **Red:** The GQ is outside your current level range.

### Players

`2(3)` means:

- `2` players are reported by the server as already joined.
- `3` visible online players are in the candidate level range and have the
  number of GQ wins required for that tier.

The number in parentheses estimates possible competition; it is not a list of
confirmed participants. It includes your own character when you match and
cannot include invisible players.

- `(...)` means the competition scan is running.
- `(0)` means no visible players matched.
- `(?)` means the scan failed. Left-click the Players cell to retry it.

### Cycle

For a level-40 character, `35(-11,-7,-3)+` means:

- `35` ranges remain unrun in that win tier.
- `-11`, `-7`, and `-3` are the starting levels of the nearest remaining
  ranges relative to level 40. They represent ranges starting at levels 29,
  33, and 37.
- A green offset means that range includes your current level.
- A bold offset means you are at the final level allowed for that range.
- A trailing `+` means the immediately following server range has not run. A
  trailing `-` means it has already run.

Other Cycle displays:

- `0` means every range in that tier has run.
- `N(-)` means ranges remain, but all of them are below your level.
- `...` means cycle data is loading.
- `?` means no complete cycle snapshot is available.
- Yellow Cycle text means the latest refresh failed and the last complete
  snapshot is being shown.
- `-` means cycle data is unavailable while disconnected.

## Mouse controls

| Location | Left-click | Right-click |
| :--- | :--- | :--- |
| Title bar | Drag to move | Open settings menu |
| GQ row | Show `gq info` | Join the GQ |
| Players cell | Show matching players, or retry a failed scan | Join the GQ |
| Cycle cell | List all relevant remaining ranges | Refresh `gquest ranges` |

## Commands

| Command | Action |
| :--- | :--- |
| `gqshow` | Show the miniwindow. |
| `gqhide` | Hide the miniwindow. |
| `gqlist` | Request a fresh `gq list`. |
| `gqdebug` | Display sample rows for testing the window layout. |

## Troubleshooting

- **The plugin reports that it cannot open `GQ_Dashboard.lua`:** Confirm that
  the XML and Lua files have those exact names and are in the same directory.
- **No tiers are displayed:** Right-click the title bar and enable at least one
  win tier.
- **The window is missing:** Enter `gqshow`.
- **Competition shows `(?)`:** Left-click the Players cell to retry once.
- **Cycle shows `?`:** Right-click the Cycle cell to request a refresh.

For other problems or feature requests, open an issue in the
[aardwolf-utilities repository](https://github.com/devnada0/aardwolf-utilities/issues).

## Acknowledgments

GQ Dashboard was inspired by
[GQ-List](https://github.com/Memnoch1244/GQ-List) by Memnoch1244.
