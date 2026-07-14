# Changelog

## 3.0 - 2026-07-14

- Renamed the plugin from GQ List to GQ Dashboard and renamed its XML and Lua
  files to `GQ_Dashboard.xml` and `GQ_Dashboard.lua`.
- Assigned the new MUSHclient plugin id `300566e7f39f483cb01a2d6e`, making GQ
  Dashboard a separate installation with fresh saved settings and geometry.
- Renamed the miniwindow and internal capture-marker namespaces to match the new
  identity while preserving the existing `gqshow`, `gqhide`, `gqlist`, and
  `gqdebug` commands.
- Added README acknowledgment that GQ Dashboard was inspired by GQ-List by
  Memnoch1244.

## 2.8 - 2026-07-13

- Changed the final-level Cycle warning from bold italic to bold-only for a
  cleaner compact display.
- Corrected the look-ahead marker meaning: `+` now means the immediately
  following raw range is unrun (`No`), while `-` means it has run (`Yes`).
- Kept range selection, counts, colors, centering, click behavior, capture
  frequency, hotspots, and window geometry unchanged.

## 2.7 - 2026-07-13

- Rendered a displayed Cycle offset in bold italic when the character is on
  that range's final level, warning that the next level will leave the range.
- Added a neutral trailing `+` or `-` after three displayed offsets to show
  whether the immediately following raw server range has or has not run.
- Preserved the existing first-three-unrun selection and Cycle left-click
  details; the look-ahead marker does not search for a fourth unrun range.
- Measured and centered mixed normal/bold-italic Cycle segments by their actual
  fonts, retained green eligibility and all-yellow stale-state precedence, and
  kept the existing compact column geometry and whole-cell hotspot.
- Dropped the optional look-ahead marker before applying the existing
  whole-offset fallback when an unusually long value cannot fit.

## 2.6 - 2026-07-12

- Replaced Cycle percentages with the total number of ranges still unrun for
  the selected tier and up to three signed From-level offsets relative to the
  character, such as `34(-14,-9,-4)`.
- Highlighted offsets in lime when their ranges currently contain the
  character level; future offsets remain neutral and stale snapshots retain
  their existing all-yellow warning state.
- Made Cycle labels fit as whole offset tokens at every window width instead of
  clipping a sign or number.
- Changed Cycle left-click details to list every unrun range at the character's
  level or higher, retaining server order and duplicates and coloring ranges
  that can be joined immediately in lime.
- Shortened displayed statuses to `Prep`, `Ext`, and `NA`, rebalanced the
  measured columns for the denser Cycle values, and kept the entire Cycle cell
  as one click target.

## 2.5 - 2026-07-12

- Replaced character-padded table rows with measured pixel cells so every
  header and value is centered consistently, including `Tmr` and summary-row
  placeholders.
- Distributed available width across all seven columns while retaining the
  verified 330-pixel compact layout.
- Moved the `Plyrs` column one measured character to the right when expansion
  space is available, without moving it into `Cycle` or the resize grip.
- Replaced the uneven grouped dash text with one continuous one-pixel divider.
- Derived row, Players, and Cycle hotspots from the same responsive cell
  boundaries and expanded the runtime harness for centering and resize checks.

## 2.4 - 2026-07-12

- Added a compact `Cycle` column backed by an atomic, marker-fenced capture of
  `gquest ranges`.
- Displayed each tier as `percent(eligible remaining:next From level)`, such as
  `32(2:102)`, using inclusive eligibility and a strictly higher next From
  level.
- Added per-tier summary rows when an enabled tier has no active GQ, so cycle
  progress remains visible between quests.
- Made the Cycle cell left-clickable for full range details and right-clickable
  for one manual refresh without changing the rest of the row's join actions.
- Refreshed ranges once per connection/reload, once when a new GQ ID appears,
  and on explicit right-click; stable ticks, filters, levels, and resizes do not
  send additional range commands.
- Temporarily disabled Aardwolf paging around automatic fenced captures and
  restored it in the same command batch, preventing the 50-row ranges table
  from stopping at a pager prompt.
- Serialized ranges and competition captures while preserving the user's
  original prompt and compact settings across back-to-back requests.
- Validated all 50 ordered rows, retained duplicate ranges independently, and
  cross-checked separator positions and the three footer percentages against
  the captured Yes counts.
- Renamed the display columns to `Tier` and `Plyrs` and shortened tier values to
  `<25`, `25-199`, and `200+` to make room without changing filter semantics.
- Added accurate disconnected Cycle display/click feedback and corrected the
  unknown-to-known GMCP level redraw edge case.
- Added a sanitized full ranges fixture and expanded the runtime harness for
  cycle parsing, calculations, stale-data recovery, summary rows, and clicks.

## 2.3 - 2026-07-12

- Wrapped each automatic `swho` in unique, ordered Aardwolf `echo` markers so
  only the plugin-owned response is hidden and manual `who`/`swho` output stays
  visible.
- Made markers and every delayed callback unique to the current plugin load,
  added immortal `echo self` support, and suppressed/restored prompt, compact,
  and exact `echocommands` output around automatic scans.
- Required a complete header, `Players found` count, matching player-row count,
  and final footer before publishing a competition snapshot.
- Added staged `gq list` capture, request/capture watchdogs, and tick coalescing
  so an interrupted response cannot replace the last complete table or leave a
  gag group enabled, while routine polling remains one command per tick.
- Reset transient rows, queues, snapshots, and capture groups across disconnect,
  reconnect, disable, and enable; recreated the themed window after re-enable.
- Made failed competition snapshots retry once when their Players cell is
  left-clicked, without adding an automatic retry loop.
- Persisted sound, auto-hide, and all three tier-filter preferences while
  keeping GQ and player snapshots memory-only.
- Fixed repeated alerts with six or more active GQs, normalized tier parsing,
  redrew immediately on relevant level changes, honored modifier clicks and the
  miniwindow lock, clamped movement and restored geometry to the actual window
  size, and made disable/enable/close cleanup deterministic.
- Repaired `gqdebug`, rejected malformed GQ rows atomically, and stopped changing
  the world-wide background-sound option during installation.
- Preserved the intentional `swho` lower bound of GQ minimum minus one.

## 2.2 - 2026-07-12

- Moved the plugin's Lua implementation into the sibling `GQ_List.lua` file
  without intentionally changing behavior.
- Kept one plugin version in `GQ_List.xml`; the XML and Lua files together form
  the 2.2 release.

## 2.1 - 2026-07-11

- Recognized Aardwolf's trailing `***` server marker on `Preparing` GQ rows
  without treating it as a data column.
- Kept Preparing rows in the compact aligned layout and started their eligible
  competition scan immediately instead of waiting for the GQ to become Active.

## 2.0 - 2026-07-11

- Reduced the minimum height from the unnecessarily tall 75 pixels introduced
  in 1.8 to a compact 60 pixels that still fits the text and click targets.
- Preserved the full resize repaint, resize-grip reservation, and saved-position
  fixes while allowing the window to collapse to a more compact height.

## 1.9 - 2026-07-11

- Synchronized the themed helper's in-memory window coordinates while dragging
  the custom GQ titlebar.
- Saved the actual position on drag release so resizing uses the new location
  instead of snapping to limits calculated from a stale lower-right position.

## 1.8 - 2026-07-11

- Repainted the complete GQ body during and after themed-window resizing instead
  of calling the capture-only list finalizer.
- Added compact-layout minimum dimensions and corrected undersized saved window
  dimensions on reload.
- Reserved the themed lower-right resize-grip area so row and Players hotspots
  cannot interfere with resizing.
- Added a hand cursor to the active Players hotspot.

## 1.7 - 2026-07-11

- Replaced the raw server-row rendering with compact, aligned miniwindow
  columns.
- Shortened the displayed GQ tier labels to `<25 wins`, `25-199 wins`, and
  `200+ wins` without changing their filtering behavior.
- Combined From/To into one `Levels` column and moved Players to a stable,
  visible position after Timer.
- Removed the gap between the server and competition counts, rendering values
  such as `2(2)`.

## 1.6 - 2026-07-11

- Added one-time `swho` competition snapshots for visible, level-eligible GQs.
- Filtered visible online players according to each GQ's existing win tier,
  including the current character in the count.
- Appended `(...)`, `(number)`, or `(?)` to the server-provided Players value.
- Made the entire Players cell clickable to display matching player rows while
  preserving right-click join behavior.
- Scoped automatic `swho` capture and gagging to requests issued by this plugin,
  waiting behind outstanding manual or externally scripted `swho` commands.
- Kept snapshots memory-only, discarding a vanished GQ and only the relevant
  tier when its filter changes.
- Reused a single `swho` response for eligible GQs sharing a level range.
- Fixed invalid Lua replacement escapes when re-enabling existing menu options.
- Updated the plugin author metadata to `Morienda`.

## 1.5 - 2025-11-07

- Baseline miniwindow version imported into this workspace.
