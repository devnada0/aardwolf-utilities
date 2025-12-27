# Changelog

All notable changes to the SmartMove plugin will be documented in this file.

## [1.3] - 2025-12-26

### Added
- **Smart Scanning:** Added `smartmove scan` command. This performs a context-aware look:
  - **Non-Combat:** Always executes standard `scan` for speed.
  - **Combat:** Checks for the `survey` skill based on Class, Level, and Tier. If eligible, it executes `survey`; otherwise, it falls back to `scan`.
- **Auto-Stand (Scan):** Attempting to scan while sleeping or resting will now automatically send `stand` first.

### Changed
- **Status Display:** Updated `smartmove help` to show current eligibility for **Survey** alongside Retreat.
- **Code Structure:** Refactored the eligibility checking logic into a generic function to support multiple skills without code duplication.

## [1.0] - 2025-11-24

### Added
- **Initial Release:** Context-aware movement replacement.
- **Smart Retreat:** Automatically detects Combat state (8) and attempts to use the `retreat` skill if the character meets the Class and Effective Level requirements.
- **Auto-Stand (Move):** Attempting to move while sleeping or resting automatically sends `stand`.
- **Multiclass Support:** Checks the character's entire class history string (e.g., "013") to determine skill eligibility.
- **Tier Awareness:** Correctly calculates Effective Level (`Level + (Tier * 10)`) for skill checks.