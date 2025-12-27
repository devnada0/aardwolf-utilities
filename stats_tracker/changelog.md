# Changelog

All notable changes to the Stat Tracker plugin will be documented in this file.

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