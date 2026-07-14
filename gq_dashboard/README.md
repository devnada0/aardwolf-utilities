# GQ Dashboard

`GQ_Dashboard` displays Aardwolf's active Global Quests in a themed MUSHclient
miniwindow. It preserves the server-provided player count, filters rows by GQ
win tier, colors rows by the current character's level eligibility, and can
play an alert for a newly available GQ. Its Cycle column summarizes which GQ
ranges have already run and what remains near the character's level.

## Acknowledgments

GQ Dashboard was inspired by
[GQ-List](https://github.com/Memnoch1244/GQ-List) by Memnoch1244.

## Installation

Keep `GQ_Dashboard.xml` and `GQ_Dashboard.lua` in the same directory, then
install `GQ_Dashboard.xml` through MUSHclient's plugin manager. When updating,
replace both files together. `GQ_Dashboard.xml` contains the single version
number for the whole plugin; the Lua file does not have a separate version.

## Commands

- `gqshow` shows the miniwindow.
- `gqhide` hides the miniwindow.
- `gqlist` requests a fresh `gq list` from Aardwolf.
- `gqdebug` displays sample GQ rows for layout testing without sending commands.

Right-click the title to configure sound, auto-hide, the existing GQ-tier
filters, or window stacking. The three tier filters remain independent, so the
menu can show none, one, or several tiers.

## Competition snapshot

For each visible GQ whose level range contains the current character level, the
plugin runs this command once while that GQ remains active:

```text
swho 11 <minimum level minus 1> <maximum level>
```

The lower bound is deliberately one level below the GQ minimum. Aardwolf treats
both `swho` level bounds as inclusive, and players commonly finish a lower-level
GQ, gain a level, and then join the newer GQ while it is still `Preparing`.
Including those players makes this a projected near-term competition snapshot,
not a list limited to players who are eligible at the instant of the query.

The plugin surrounds each automatic request with unique, per-load Aardwolf
`echo` markers and hides only recognized response lines between those ordered
markers. It temporarily suppresses paging, server prompts, and compact-mode
blank lines, hides its exact `echocommands` lines, and uses `echo self` for
immortal characters. Prompt and compact settings are restored and the standard
paging option is re-enabled in the same outbound command batch. Automatic
`swho` and `gquest ranges` captures are serialized so those temporary settings
cannot interfere with one another.
Manual or externally scripted `who` and `swho` output remains visible whether
it is sent before, during, or after an automatic scan. A snapshot is accepted
only when its header, reported player count, captured row count, and footer
agree.

The plugin filters the second bracketed value in each `swho` player row using
the GQ's tier:

- `Less than 25 wins`: fewer than 25 wins.
- `25 to 199 wins`: 25 through 199 wins.
- `200 Wins or more`: 200 or more wins.

A redacted capture of the expected header, player rows, and footers is kept in
[`samples/gq-dashboard-swho-gquests.txt`](samples/gq-dashboard-swho-gquests.txt).

The character running the plugin is included if present in the `swho` output.
The miniwindow renders the server's joined-player count followed by the number
of matching visible online players, for example `1(2)`. The snapshot markers
are:

- `(...)` while the request is running.
- `(0)` when no visible players match.
- `(?)` when the request does not complete successfully.

Left-clicking a Players cell that shows `(?)` queues one manual retry. It does
not create a repeating automatic retry loop.

While a GQ is `Preparing`, Aardwolf may append `***` after its Players value.
That is a server-side GQ marker, not the competition count.
The plugin removes it before formatting and starts the level-range `swho`
immediately; only the normal command/response round trip leaves `(...)`
temporarily visible.

The miniwindow uses compact tier labels (`<25`, `25-199`, and `200+`), renames
the player column to `Plyrs`, combines the server's From/To fields into one
`Levels` column, and displays `Preparing`, `Extended`, and no active GQ as
`Prep`, `Ext`, and `NA`. These abbreviations change only the presentation;
matching still uses the original GQ tier, status, and numeric level range.

Headers and values are centered inside measured pixel cells rather than padded
with spaces. The cells share additional width when the window grows, `Plyrs`
moves one measured character farther right when room is available, and one
continuous divider replaces the old grouped dashes. The same cell boundaries
define the row, Players, and Cycle hotspots, keeping the visual columns and
click targets aligned throughout a resize.

For an in-range row with a competition scan, the entire Players cell is a
hotspot. Left-click either number to print the captured matching rows in the
main output window. Right-click the Players cell still joins the GQ. An
out-of-range Players value remains part of the normal row hotspot. The rest of
the row retains its existing behavior: left-click for `gq info` and right-click
to join.

The active Players hotspot uses a hand cursor. Its right edge stops before the
themed lower-right resize grip so clicking and resizing do not compete. The
window repaints throughout a resize and enforces a compact minimum size of
330 by 60 pixels. As with other `ThemedBasicWindow` windows, its maximum size is
the remaining MUSHclient output-pane area; it cannot be dragged beyond that
pane's right or bottom edge. Moving the window updates and saves the same
coordinates used by the themed resizer, so moving left/up immediately creates
usable expansion room. The 60-pixel minimum is the one-row compact view; make
the window taller when several independent tier filters or GQs produce more
rows.

Snapshots live only in memory. They are discarded when the GQ disappears. A
tier filter change discards that tier's snapshots, so its currently visible,
level-eligible GQs are scanned again without disturbing other enabled tiers.
Multiple eligible GQs with the same level range share one `swho` request.

The parenthesized number is a snapshot of visible online players who fall within
the queried candidate range (GQ minimum minus one through GQ maximum) and match
the win tier. The one-level-below candidates are intentionally included. It is
not a count of confirmed participants, and it cannot include invisible players.

## Cycle column

The plugin captures Aardwolf's `gquest ranges` table and displays one compact
Cycle value per enabled tier. For example:

```text
34(-14,-9,-4)-
```

- `34` is the total number of ranges that have not yet run for that win tier.
- Each parenthesized number is a range's From level relative to the character's
  current level. For example, `-14` began 14 levels below the character, `+3`
  begins three levels above, and `+0` begins at the current level.
- The miniwindow shows the first three unrun ranges whose To level is the
  character's level or higher, in the same order Aardwolf reports them.
- An offset is lime when that range currently contains the character level;
  future offsets and the surrounding punctuation remain neutral.
- A displayed offset is bold when the character level equals that
  range's To level. The character is still eligible, but the next level will
  leave that range. This boundary warning is based only on the character's
  position within the range.
- When three offsets are displayed, a trailing `+` means the immediately
  following raw server range has not run (`No`); a trailing `-` means it has
  already run (`Yes`). The marker is absent when there is no following row or
  fewer than three offsets are displayed. It does not represent a fourth unrun
  range.
- `N(-)` means ranges remain in the tier, but all of them are below the
  character. A fully completed tier displays `0`.

The Cycle value is centered as one aggregate even though individual offsets can
have different colors and font styles. If an unusually long value does not fit
at the current window width, the optional look-ahead marker is omitted before
any complete trailing offset; a sign or number is never clipped. Left-click
still shows the complete relevant list.

Duplicate server rows are retained and counted independently. This matters for
the two legitimate `191-199` rows. A `Yes` row has already run in the current
cycle and does not contribute to either remaining value.

If an enabled tier has no active GQ, the plugin adds a compact `NA`
summary row for that tier. This keeps its Cycle value available between active
quests whenever the window is shown; the optional existing auto-hide setting
can still hide the whole window. The three existing tier filters remain
independent, so enabling several tiers can display several summary rows.

Left-click a Cycle cell to list every unrun range whose To level is the current
character level or higher. Ranges whose inclusive bounds currently contain the
character level are lime; future ranges use the normal output color. Server
order and duplicate rows are preserved. Right-click the Cycle cell to refresh
`gquest ranges`; it never joins a GQ. The Players and rest-of-row click behavior
remains unchanged.

Cycle shows `...` during capture and `?` when no complete snapshot is available.
If a later refresh fails, the last complete snapshot stays visible in yellow
and its details explain that it is stale. While disconnected, Cycle shows `-`
and a click explains that range data is unavailable. Range snapshots are
memory-only.

The plugin requests ranges once after load/reconnect, once when a newly seen GQ
ID indicates the cycle may have advanced, and on a Cycle-cell right-click. It
does not rerun the command for stable ticks, filter changes, level changes, or
window redraws. Manually entered `gquest ranges` output remains visible and is
not claimed by the automatic capture.

A complete sanitized response is kept in
[`samples/gq-dashboard-ranges.txt`](samples/gq-dashboard-ranges.txt).

## Engineering review

The decisions, findings, implementation order, and regression matrix from the
2026-07-11 review of version 2.1 are recorded in
[`CODE_REVIEW.md`](CODE_REVIEW.md). That document is the baseline for future
hardening work; it distinguishes confirmed requirements from defects so the
intentional minimum-minus-one range is not accidentally "fixed."

## Dependencies and GMCP

The plugin expects the standard Aardwolf MUSHclient package and these helpers:

- `themed_miniwindows`
- `movewindow`
- `gmcphelper`
- `telnet_options`
- `gag_next_blank_line`
- `tprint`
- `aardwolf_colors.lua`

It receives broadcasts from Aardwolf's standard GMCP handler plugin,
`3e7dedbe37e44942dd46d264`, and uses:

- `char.status.level` for level-range eligibility.
- `char.status.state` to limit periodic refreshes to supported character states.
- `comm.tick` to request `gq list` updates.

Routine `gq list` polling remains one server command per eligible tick. Its
header starts a staged capture, and only a complete, parseable list replaces the
last good table. The legacy behavior of hiding both automatic and manually
requested `gq list` tables is preserved.

The themed miniwindow helper manages its window state. Sound, auto-hide, and
the three tier-filter choices are saved plugin preferences. Active GQs,
competition snapshots, captured player rows, and command queues remain
memory-only and are cleared across disconnect/reload boundaries.

## Automated verification

With Lua available on the command line, run:

```text
lua gq_dashboard/tests/runtime_test.lua
```

The harness checks centered responsive columns, the continuous divider,
minimum/wide hotspot boundaries, ordered capture markers, mortal and immortal
fence forms, paging and quiet-setting restoration, serialized automatic
captures, response completeness, reload-safe timers, the minimum-minus-one
range, click-to-retry,
the full 50-row Cycle fixture, separator/footer validation, duplicate and
inclusive range calculations, final-level font styling, raw next-row suffixes,
mixed-font centering, Cycle details/refresh clicks, summary rows,
interrupted capture recovery, disconnected feedback, tick coalescing, alert
history, saved preferences, modifier clicks, debug data, and lifecycle cleanup
and window recreation.

## Manual verification

1. Load or reload the plugin and confirm there are no XML or Lua errors.
2. Confirm only visible, level-eligible GQs trigger `swho 11 from-minus-one to`.
3. Confirm repeated `gq list` updates for the same GQ do not send another
   `swho` request.
4. Test win totals at 24, 25, 199, and 200 against all three GQ tiers.
5. Confirm the current character is included when its row matches the tier.
6. Confirm the Players cell progresses from `2(...)` to an adjacent result such
   as `2(2)`, including `2(0)`, and shows `2(?)` after a failed or timed-out
   capture.
7. Left-click both the server count and parenthesized count and confirm the same
   matching list is printed. Right-click the cell and confirm `gq join` is sent.
8. Confirm the rest of the row still opens `gq info` on left-click and joins on
   right-click.
9. Change a tier filter and confirm visible eligible rows receive a fresh,
   one-time scan.
10. Enter `swho` manually immediately before and immediately after an eligible
    GQ is detected. Confirm both manual responses remain completely visible and
    only the marker-fenced automatic response is hidden.
    Repeat with Aardwolf prompts, compact mode, and `echocommands` enabled and
    confirm the automatic scan leaves no command-echo or extra-prompt clutter.
11. Resize the window repeatedly in both directions. Confirm the body redraws
    without resize-grip trails, the compact minimum is enforced, all headers and
    values remain centered, the divider stays continuous, and the active
    Players cell shows a hand cursor and remains clickable.
12. Move the window left and upward, release it, and enlarge it from the
    lower-right grip. Confirm it expands into the newly available space without
    snapping back to the prior lower-right limit.
13. Shrink the window vertically and confirm it reaches 60 pixels without
    snapping back to the former 75-pixel minimum.
14. Capture an in-range `Preparing` row ending in `***`. Confirm it is compact
    and aligned immediately, displays `0(...)`, and sends its `swho` without
    waiting for the GQ to become `Active`.
15. Interrupt or time out a competition response. Confirm it becomes `(?)`,
    then left-click the Players cell and confirm exactly one retry is queued.
16. Disable and re-enable the plugin, then disconnect and reconnect. Confirm
    the window recreates, stale rows disappear, and fresh data is requested.
17. Change sound, auto-hide, and tier filters, reload the plugin, and confirm
    those preferences survive while old snapshots do not.
18. If testing an immortal character, confirm automatic scans use `echo self`,
    hide both immortal echo confirmations, and still complete normally. Also
    confirm a `SUPERHERO` or other custom first-bracket WHO field is counted.
19. Confirm the Cycle column reaches a value such as `34(-14,-9,-4)-`, its
    leading count matches the tier's unrun rows, and only offsets for ranges
    containing the current level are lime. Confirm an offset whose To level
    equals the character level is bold but not italic, while other offsets are
    not.
    Verify the trailing `+`/`-` against the raw row immediately after the third
    displayed unrun range. Left-click and confirm all unrun ranges at the
    character's level or higher are listed, with immediately joinable ranges
    lime and duplicate rows preserved.
20. Confirm an enabled tier with no active GQ has an `NA` summary row.
    Left-click its Cycle value for details and right-click it for one refresh.
21. With Aardwolf paging enabled, refresh Cycle and confirm the full ranges
    response completes without a pager prompt or a stuck `...` value.
