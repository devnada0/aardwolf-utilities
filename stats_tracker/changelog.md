# Changelog

All notable changes to the Stat Tracker plugin will be documented in this file.

## [5.7] - 2025-12-22

### Added
- **Debug Mode:** Added `statt debug` command. This toggles console messages showing exactly which text triggered a loot count and the source line, useful for verifying false positives.

### Fixed
- **Loot Validation:** Added strict validation to the Bloot trigger. It now checks captured text against the valid tier list, preventing false positives from tags like `(oOo)` or `(Aarchaeology)`.
- **Self-Loot Bug:** Modified the loot trigger to capture the corpse name. The plugin now ignores loot taken from your own corpse to prevent stat inflation after death.