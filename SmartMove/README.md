# SmartMove 🏃‍♂️

![Version](https://img.shields.io/badge/version-1.0-blue)
![Language](https://img.shields.io/badge/language-Lua-000080)
![Platform](https://img.shields.io/badge/platform-MUSHclient-orange)
![Game](https://img.shields.io/badge/game-Aardwolf-red)

**SmartMove** is a context-aware movement plugin for Aardwolf MUD. It replaces standard directional commands with intelligent logic to handle sleeping, resting, and tactical retreat requirements automatically.

---

## ✨ Features

*   **Auto-Stand:** Automatically sends `stand` before moving if you are Sleeping or Resting.
*   **Intelligent Retreat:** Detects if you are in combat.
    *   Checks your **Class History** (Multiclass) against `retreat` skill requirements.
    *   Calculates eligibility based on `Level + (Tier * 10)`.
    *   Executes `retreat <dir>` if eligible; otherwise attempts a standard move.
*   **Zero Spam:** Runs silently in the background unless `debug` mode is active.

## 🧠 Logic Breakdown

When you execute a direction (e.g., `smartmove n`):

| State | Action |
| :--- | :--- |
| **Sleeping / Resting** | Sends `stand` → Sends `north` |
| **Fighting (Eligible)** | Sends `retreat north` |
| **Fighting (Ineligible)** | Sends `north` (Game handles "No way! You are fighting!") |
| **Standard** | Sends `north` |

### Retreat Eligibility
The plugin checks your effective level (`Level + Tier*10`) against these requirements:

| Class | Required Level |
| :--- | :--- |
| **Thief** | 142 |
| **Ranger** | 121 |
| **Paladin** | 118 |
| **Warrior** | 116 |

---

## 📥 Installation

1.  Download **[SmartMove.xml](SmartMove.xml)**.
2.  Place it in your MUSHclient `worlds/plugins` folder.
3.  In MUSHclient, go to **File** → **Plugins** → **Add** and select the file.

## ⌨️ Usage

### Recommended Setup
Map your **Numpad** keys to the SmartMove syntax. 

*   **Numpad 8:** `smartmove n`
*   **Numpad 6:** `smartmove e`
*   **Numpad 2:** `smartmove s`
*   *etc...*

### Commands

```bash
smartmove <dir>   # Move n, s, e, w, u, or d
smartmove help    # View current status and effective level stats
smartmove debug   # Toggle verbose log output

📝 License
Written by Morienda for the Aardwolf community.
Free to use and modify.
