# StatTracker 📊

![Version](https://img.shields.io/badge/version-5.6-blue)
![Language](https://img.shields.io/badge/language-Lua-000080)
![Platform](https://img.shields.io/badge/platform-MUSHclient-orange)
![Game](https://img.shields.io/badge/game-Aardwolf-red)

**StatTracker** is a comprehensive session monitor for Aardwolf MUD. It combines GMCP data and text triggers to track your economy, progression, and combat efficiency in real-time.

---

## ✨ Features

*   **Hybrid Tracking:** Uses both GMCP and Text Triggers for maximum accuracy.
*   **XP Monitor Widget:** A draggable miniwindow displaying XP/hour rates over 1m, 5m, and 15m intervals.
*   **Deep Stats:**
    *   **Economy:** Gold earned, Gold from Sales, Net Worth changes.
    *   **Progression:** XP, Levels, Trains, Practices, QP, TP.
    *   **Activities:** Quests, Campaigns, Global Quests (Joined/Won/Completed).
    *   **Loot:** Tracks "Bloot" (Bonus Loot) drops by Tier (Polished through Godly).
*   **Smart Reporting:** Generates detailed tables for you, or compact colored summary strings for chat channels.

---

## 🖥️ The XP Monitor

The plugin includes a visual **XP Rate Widget**.

*   **Columns:** 1 minute | 5 minutes | 15 minutes (Average XP/hr).
*   **Color Logic:**
    *   **<span style="color:red">Red</span>**: Data is still stabilizing (not enough time passed).
    *   **<span style="color:green">Green</span>**: Data is accurate.
*   **Interaction:**
    *   **Left Drag:** Move the window.
    *   **Right Click:** Open context menu (Report, Reset, Hide).

---

## 📥 Installation

1.  Download **[stats_tracker.xml](stats_tracker.xml)**.
2.  Place it in your MUSHclient `worlds/plugins` folder.
3.  In MUSHclient, go to **File** → **Plugins** → **Add** and select the file.

---

## ⌨️ Commands

| Command | Description |
| :--- | :--- |
| `statt` | Show help and status. |
| `statt report` | Print a detailed statistics table to your output window. |
| `statt report chat` | Send a compact, color-coded summary to the local buffer. |
| `statt report chat <ch>` | Send summary to a specific channel (e.g., `statt report chat gtell`). |
| `statt xpmeter` | Toggle the XP Monitor miniwindow on/off. |
| `statt xpmeter reset` | Reset the miniwindow position if it gets lost. |
| `statt reset` | Reset all session counters to zero. |

### Sample Output

**Table Report (`statt report`):**
```text
------------------------------------------------------------
 Session Statistics                     1h 15m
------------------------------------------------------------
 Experience   :       12,500,000       (166,666/min)
   Levels     :                2
 Gold         :        5,000,000        (66,666/min)
   From Sales :          500,000
 ...
```

**Chat Summary** (`statt report chat`):
<remove me>```text
[1h 15m] XP:12.5m LV:2 | G:5.0m | QP:15 TP:2 Tr:4 Pr:4 | Q:10 CP:1 GQ:2 (0w/2c)
```

---

## 📝 License

Written by **Morienda** for the Aardwolf community.  
Free to use, modify, and distribute.
