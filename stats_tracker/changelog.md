# Changelog


## [6.0] - 2026-01-27

### Added
- **Combat Events:** Added a new report section to track defensive wish activations (Nodirt, Nomarbu, Noteleport, Novorpal, Noweb, Bravery) and successful Teleports against the player.
- **Superhero Logic:** Added logic to detect the "Stat Restore" phase when reaching level 201. The plugin now subtracts the refunded trains from the session total so that becoming a Superhero doesn't artificially inflate the "Trains Earned" stat.
- **Trivia Bonus:** Added tracking for Trivia Points earned specifically from killing "Trivia Bonus Mobs".
- **GQ Granularity:** Separated Global Quest rewards into two distinct categories in the report: "From GQ Mobs" (kills) and "From GQ Wins" (completion bonus).

### Fixed
- **Campaign Parsing:** Updated the Campaign Reward trigger to handle leading whitespace/indentation, which was causing rewards to be missed in the report.
- **Trivia Regex:** Fixed the trigger for Trivia Bonus Mobs to correctly match the trailing period in the game output.
- **Migration Safety:** Added explicit initialization for new data fields to prevent "nil value" crashes when upgrading from older versions with saved session data.

## [5.9] - 2026-01-11

### Added
- **Item & Key Tracking:** Added tracking for standard items and keys looted from corpses. Includes logic to ignore gold piles and automatically decrement the count if an item immediately crumbles to gold.
- **Reward Breakdowns:** The `statt report` now includes specific sub-rows showing contributions from Quests, Campaigns, and Global Quests for Gold, QP, TP, Trains, and Practices. These rows auto-hide if the value is zero.
- **Global Quest Support:** Added tracking for both GQ Mob kills (3 QP awards) and GQ Wins.
- **Campaign Support:** Added text parsing logic to capture specific rewards upon Campaign completion.

### Changed
- **Report Layout:** Widened table columns to ensure alignment of colons across all sections. Adjusted indentation for sub-rows ("From Sales", "From Quests", etc.).
- **Bloot Regex:** Relaxed the Bonus Loot trigger pattern to better handle irregular spacing in drop messages.

### Fixed
- **Quest Math:** Updated GMCP handling to use the `totqp` field. This ensures Lucky, Daily, and Double QP bonuses are correctly attributed to the Quest total.
- **Trigger Collisions:** Added `keep_evaluating="y"` to the generic Item Loot trigger. This fixes a bug where standard item detection was preventing the Bonus Loot trigger from firing on the same line.
- **Lua Crash:** Fixed a "base out of range" error in the Campaign reward parser caused by `string.gsub` returning multiple values to `tonumber`.

## [5.8] - 2025-12-26

### Fixed
- **Self-Loot Identity:** Switched character name detection from the MUSHclient window title (`GetInfo(1)`) to the GMCP server data (`char.base.name`). This fixes a bug where self-loot was still being counted if the user's world file name did not exactly match their character name.

### Changed
- **Persistent Debug:** The `statt debug` setting is now saved in the session state and persists across client restarts.
- **Debug Diagnostics:** Toggling debug mode now prints the detected "Target Name" and connection state, allowing users to verify the plugin is tracking the correct character.

## [5.7] - 2025-12-22

### Added
- **Debug Mode:** Added `statt debug` command. This toggles console messages showing exactly which text triggered a loot count and the source line, useful for verifying false positives.

### Fixed
- **Loot Validation:** Added strict validation to the Bloot trigger. It now checks captured text against the valid tier list, preventing false positives from tags like `(oOo)` or `(Aarchaeology)`.
- **Self-Loot Bug:** Modified the loot trigger to capture the corpse name. The plugin now ignores loot taken from your own corpse to prevent stat inflation after death.