# GQ Dashboard engineering review (conducted as GQ List 2.1)

- Reviewed: 2026-07-11
- Reviewed revision: `3f3bf09`
- Scope: correctness, response ownership, lifecycle, performance, persistence,
  miniwindow behavior, usability, maintainability, and regression coverage

This is a review record, not a change log. It captures the intended behavior and
the problems found in version 2.1 so later fixes can be made and tested in small,
separately committed versions.

This review predates the version 3.0 rename to GQ Dashboard and remains a record
of the plugin under its former name.

## Product decisions that must be preserved

1. **The `swho` lower bound is intentionally the GQ minimum minus one.** The
   automatic command is `swho 11 <minimum - 1> <maximum>`. Both bounds are
   inclusive. A player one level below can finish a lower-level GQ, level up,
   and join the new GQ while it is `Preparing`, so that player belongs in the
   projected competition pool. This is not an off-by-one defect.
2. **The current character counts.** If the character appears in the response
   and has the required number of GQ wins, its row and count are included.
3. **Only relevant visible GQs are scanned.** A tier must be enabled by the
   existing filter and the character's current level must be inside the actual
   GQ range. The one-level allowance applies to candidate discovery, not to the
   decision to launch a scan.
4. **The tier filters retain their existing behavior.** They are independent;
   zero, one, or several tiers may be selected. There is no new single-tier or
   default-`200+` rule.
5. **Snapshots are deliberately short-lived.** A GQ is scanned once while it
   remains present. Turning its tier off and back on requests a fresh snapshot.
   GQs sharing the same level range may share one request. Snapshots remain in
   memory and are not restored after a plugin or client restart.
6. **Automatic and manual commands have different presentation.** Output from
   an automatic plugin-owned `swho` is hidden. A manually entered `who` or
   `swho` must remain completely visible and must never be claimed by the
   automatic capture.
7. **The whole Players cell is the click target.** Left-clicking either the
   server player count or the parenthesized competition count prints the
   captured rows. Right-clicking it joins the GQ.
8. **Window geometry is user-owned.** Ordinary changes to the main MUSHclient
   window must not overwrite the miniwindow's preferred size or position. An
   explicit Aardwolf layout restore may intentionally change its geometry, but
   the miniwindow object and saved state must then be synchronized to that
   actual geometry.

## Overall assessment

The normal path is compact and inexpensive. Tier boundaries are correct,
same-range work is coalesced, commands are built from parsed numbers, and a
normal timely automatic response produces the intended count and rows. The
main reliability risk is not CPU cost; it is deciding which server response
belongs to which command when output is incomplete, delayed, interleaved, or
crosses a disconnect. Miniwindow lifecycle and externally changed geometry are
the next largest risk.

No code should be changed solely from this document without first adding the
relevant fixture or regression check. Each implementation phase below should be
a distinct tested version and commit.

## Findings

### Critical capture and lifecycle work

#### GQ-001: Automatic `swho` body capture starts before response ownership is established

The plugin enables the header, player-row, footer, and blank-line gag triggers
as one group before sending the command. The player callback accepts a row
whenever an automatic request exists; it does not require the expected header
to have been seen. Consequently, an unrelated bracketed row or blank line that
arrives before the `Gquests Won` header can be captured or hidden.

Use explicit phases. While waiting, enable only the exact expected header.
After that header is recognized, enable the body and footer triggers and accept
rows only in the body phase. Avoid gagging generic blank lines where possible.

#### GQ-002: Delayed responses can be assigned to a later request

Automatic capture expires after 10 seconds, while observed `who`/`swho`
commands remain in a separate outstanding-command queue for 15 seconds. Once an
old entry expires, a new automatic request can start even though the old server
response is still ambiguous. A late response to request A can then be stored as
request B. A delayed manual response can suffer the same ownership error and be
hidden, violating the manual-command contract.

Replace the split timeout model with one ordered ownership state machine. A
timed-out response must not make it safe to start another capture while the old
response could still arrive. Clear ambiguity only on a reliable ordered marker,
recognized server error, or connection reset.

#### GQ-003: `gq list` capture has no watchdog

The GQ header arms a broad digit-leading row gag, and only a blank line ends the
capture. A truncated response or disconnect can leave that group enabled
indefinitely. Later numeric output may then be hidden and appended to an
unbounded partial table.

Add a generation-guarded watchdog and a single abort/reset path. Prefer an
explicit response terminator if Aardwolf provides one; otherwise keep the
watchdog and tightly validate each candidate row before hiding it.

#### GQ-004: Disable followed by enable does not recreate the themed window

The themed helper deletes and clears registered windows during disable. The
plugin constructs `my_window` only at script load, while its enable handler
calls install logic without reconstructing it. A subsequent show or redraw can
therefore operate on a deleted object.

Move construction, minimum sizing, callbacks, and z-order registration into an
idempotent `create_window()` used by install and enable. Add explicit transient
cleanup on disable.

#### GQ-005: Successful `swho` completion is not checked for completeness

The `Players found` line is recognized only for gagging; its number is not
stored. A capture is treated as successful after seeing the header even if a
player-row format changed or a row was missed. That silently presents an
undercount as authoritative.

Capture the footer's expected row total. Require the expected header, the
`Players found` line, a raw captured-row total matching it, and the final footer
before publishing a successful snapshot. A mismatch should display `(?)` and
retain diagnostic information.

#### GQ-006: Connection and plugin lifecycle do not reset transient state

There are no connect/disconnect handlers covering active captures, trigger
groups, GQ rows, scan snapshots, queued scans, or observed manual commands. A
disconnect can carry stale rows and gag state into the next session, and a
failed snapshot for an unchanged GQ ID may never be retried.

Centralize transient reset. Invoke it on disconnect, disable, and install as
appropriate; request fresh GMCP/GQ data after reconnect. Any retry must be
bounded and tied to transport recovery, not a continuous polling loop.

### High-priority window and state work

#### GQ-007: Aardwolf layout restore desynchronizes actual and saved geometry

The Aardwolf layout plugin directly resizes and repositions miniwindows. The
themed GQ object does not copy that actual width and height back into its object
fields or persisted dimension variables before redraw. Hotspots and the next
resize can therefore use the old size, and reload can restore the pre-layout
geometry. This installation already showed a layout height and GQ saved height
differing by two pixels.

Add one geometry synchronization function based on `WindowInfo`. Use it after
theme/layout changes and before save, then recompute body bounds and redraw.
Keep ordinary parent-window clipping separate from an explicit layout restore;
clipping must not replace the preferred size.

#### GQ-008: Right-edge dragging conflicts with the minimum width

The window can be dragged until only about 100 pixels remain in the output
pane, although its minimum width is 330 pixels. The helper's boundary clamp can
then win over the minimum-width clamp and persist a much narrower window.

Limit the left coordinate to `pane width - minimum window width`, with a defined
fallback for an output pane narrower than the minimum. Exercise move and resize
in both orders.

#### GQ-009: Alert history fails with six or more eligible GQs

New-GQ history is capped at five IDs. With six stable eligible GQs, every redraw
evicts an ID before it is revisited, so the same six GQs can all alert again.
The review harness reproduced 12 alerts across two identical six-row draws.

Use an ID-keyed set and prune it against all IDs in the latest complete list.
History should represent presence, not a five-entry FIFO.

#### GQ-010: Settings described as persistent are only Lua session globals

Sound, auto-hide, and tier handlers call `SaveState`, but they never store or
load plugin variables. Only geometry currently survives reload. The README
accurately calls the other values session state, while the code comment calls
them persisted preferences.

Choose and document one contract. For a stable user experience, store normalized
booleans with `SetVariable`/`GetVariable`; do not use a rendered menu string as
the source of truth. Competition snapshots must remain memory-only regardless.

#### GQ-011: Tier classification depends on duplicated fixed character columns

Parsing already extracts the displayed type, but filtering and drawing inspect
hard-coded positions in the raw line again. A harmless spacing change can parse
the row yet fail to assign a tier, causing it to bypass a filter and receive no
competition scan.

Normalize and classify `type_text` once, store the resulting tier on the parsed
GQ object, and use that value everywhere. Reject unparseable digit-leading lines
before adding them to the table.

#### GQ-012: Polling and scan queues do unnecessary work under lag

Every eligible `comm.tick` can send another `gq list` without an in-flight flag.
Queued `swho` targets are not pruned promptly when their GQs disappear. Under
lag or continuous manual `who` use, duplicate list requests and obsolete scan
targets can accumulate.

Coalesce to one outstanding GQ-list request with a watchdog. Reconcile and
prune scan targets whenever a complete active-ID set arrives.

#### GQ-013: Character level changes leave eligibility and snapshots stale

A `char.status` broadcast updates the stored level but does not redraw the
window or invalidate competition state. Until the next tick/list response, a
row can retain the wrong eligibility color and auto-hide decision. If the
character leaves and later re-enters the range while the same GQ remains, the
old snapshot can be reused even though the candidate population may have
changed.

Compare the previous and new level. Redraw eligibility immediately, discard
snapshots whose scan eligibility changed, and use the normal one-request path
when the character becomes actually eligible again.

### Interaction, accessibility, and integration work

#### GQ-014: Custom mouse handling bypasses established helper behavior

The title drag does not honor Aardwolf's miniwindow lock. Click handlers compare
the entire mouse flag value to exact numbers, so Ctrl/Alt/Shift-modified clicks
and some double-click sequences do nothing. The title also uses an arrow cursor
despite being draggable.

Prefer the themed/movewindow helper's native drag path. Where custom handling is
required, use named constants with bit tests, honor the lock setting, and use
appropriate cursors.

#### GQ-015: Compact sizing can silently clip rows and relies on fixed pixels

A 60-pixel-tall window displays roughly one data row although independent
filters can expose several. Extra rows are clipped without scrolling or an
overflow indicator. Header, row, and hotspot positions are hard-coded rather
than derived from theme body bounds and font metrics. Eligibility also relies
mainly on red/yellow/green, and cached competition details have no keyboard or
alias route.

Define the intended compact overflow behavior before changing the minimum.
Then derive row geometry from the actual font/theme, use full-row targets, add a
non-color eligibility cue, and provide an accessible command for cached rows.

#### GQ-016: Install always brings the window to the front

An unconditional `bring_to_front()` on install, including enable, defeats a
previous `Send to Back` choice. Respect the z-order manager's saved placement;
only force an initial placement when no preference exists.

#### GQ-017: Miscellaneous integration issues need cleanup

- The plugin globally enables background sound playback even when its own sound
  option is off and does not restore the prior world setting.
- `gqlist` toggles a `log_info` trigger group that this plugin does not define
  and does not preserve its previous state.
- All manual `gq list` output is hidden; decide whether that is intentional and
  document it, as it differs from manual `swho` behavior.
- Command aliases are case-sensitive, `Threshold` is misspelled in one label,
  and failure details do not explain the cause or offer a retry.
- Row action IDs should use the parsed numeric ID rather than raw character
  slices so formatting or larger IDs cannot create collisions.
- Unused helper imports and debug-only alert behavior should be cleaned up.

### Maintainability and verification

#### GQ-018: Core behavior is difficult to test in its current form

Roughly 750 lines of Lua are embedded in the XML. The runtime harness used for
this review lives only in a temporary directory and invokes callbacks directly,
so it does not test XML trigger order or real timers. A separate inactive 1.5
copy also exists under the MUSHclient plugin tree while the active profile loads
workspace version 2.1, which can cause deployment confusion.

Move substantial behavior into a sibling Lua module, keeping XML trigger
definitions close to their parsing contract. Commit a small deterministic test
harness and sanitized fixtures. Clearly identify the workspace build as the
install source and remove or label stale copies outside the repository as a
separate, explicit maintenance action.

## Behaviors that held up well

- Win thresholds are correct at `<25`, `25..199`, and `>=200`.
- The current character is included when its row and tier match.
- Multiple visible GQs with the same level range share a normal automatic
  request.
- Normal timely manual `who`/`swho` output remains visible.
- Snapshots are memory-only and are pruned on normal GQ disappearance.
- Command arguments and timer serials come from parsed numeric/internal values;
  no command-injection path was found.
- Ordinary redraw cost is small, and competition scans are not duplicated by a
  resize redraw.
- The compact `200+ wins` label, combined Levels column, Players-cell hotspot,
  Preparing-row cleanup, hand cursor, and resize repaint behave correctly on
  the normal path.
- Ordinary parent-window resize clips an absolute miniwindow rather than
  deliberately changing its stored dimensions. Aardwolf layout restore is the
  confirmed external-resize path that needs synchronization.

## Recommended implementation order

1. **Test baseline:** commit fixtures and a harness covering normal and failure
   output before changing behavior.
2. **Capture state machine:** address GQ-001, GQ-002, GQ-003, GQ-005, and GQ-006.
   Preserve the intentional minimum-minus-one query.
3. **Window lifecycle and geometry:** address GQ-004, GQ-007, GQ-008, GQ-014,
   and GQ-016. Explicitly test preferred-size behavior separately from layout
   restore.
4. **Logic and persisted preferences:** address GQ-009 through GQ-013.
5. **UI, integration, and structure:** address GQ-015, GQ-017, and GQ-018.

Each phase should bump the plugin version, update the change log and README,
pass its focused checks, and be committed before the next phase begins.

## Regression matrix

### Competition selection

- A GQ of levels `94..104` sends exactly `swho 11 93 104`.
- A returned level-93 player is intentionally included if its win total matches
  the tier; levels 94 and 104 are included as boundary cases.
- A level-93 current character does not launch that scan until the character's
  own level enters `94..104`.
- Win totals 24, 25, 199, and 200 map to the correct tiers.
- The current character counts when present.
- Same-range GQs share a request; different ranges do not share one.
- Filter off/on reruns the relevant scan; normal redraw and repeated list output
  do not.
- A starred `Preparing` row is normalized and starts its scan immediately.

### Response ownership and failure recovery

- A bracketed player row or blank before the expected automatic header remains
  visible and is not captured.
- A timely automatic response is hidden and produces the correct cached rows.
- Manual `who` and `swho` responses are always visible before, during, and after
  an automatic request.
- Missing header, missing footer, server error, and footer-count mismatch all
  end in `(?)` without leaving a gag group enabled.
- A late response to timed-out request A is never assigned to request B.
- A delayed manual response is never hidden or assigned to an automatic scan.
- A GQ-list header without its terminating blank is aborted by its watchdog;
  later numeric output remains visible.
- Disconnect and disable during every capture phase clear triggers and transient
  state; reconnect/enable creates a usable window and requests fresh data.

### Queueing, alerts, and state

- Multiple ticks before a response send only one outstanding `gq list`.
- A vanished GQ is removed from the scan queue before its request is sent.
- Identical lists containing 1, 5, 6, and 20 eligible GQs alert once per new ID,
  not once per redraw.
- Level changes redraw eligibility immediately, invalidate obsolete snapshots,
  and start a new scan only when the character becomes actually eligible.
- Sound, auto-hide, filters, z-order, position, and size follow their documented
  reload/reconnect persistence contracts; snapshots do not persist.

### Window and interaction

- Disable/enable, reload, reconnect, theme change, and explicit Aard layout
  restore all leave drawing, Players hotspots, movement, and resizing usable.
- An explicit layout restore synchronizes actual and saved geometry; a later
  reload does not jump back to the pre-layout size.
- Shrinking/growing the main window does not overwrite preferred dimensions.
- Moving to every pane edge and then resizing cannot violate the minimum width
  or produce grip artifacts/snap-back.
- All visible rows have an intentional overflow/scroll policy at minimum height.
- Players and row actions work with modifier flags and respect miniwindow lock.
- Eligibility and cached competition details are usable without relying only on
  color or a tiny mouse target.

## Review evidence

The review used the complete plugin source, the bundled themed miniwindow,
movement and Aard layout helpers, saved window/layout state, targeted samples
from local Aardwolf logs, and a temporary Lua callback harness. The harness
confirmed the pre-header capture, delayed-response ownership, six-GQ alert
loop, tier boundaries, shared-range behavior, Preparing-row handling, and core
geometry observations. No production plugin code was modified by the review.
