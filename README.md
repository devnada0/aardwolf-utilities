# Aardwolf MUSHclient Plugins 🐺

![Platform](https://img.shields.io/badge/platform-MUSHclient-orange)
![Game](https://img.shields.io/badge/game-Aardwolf-red)
![Language](https://img.shields.io/badge/language-Lua-000080)
![Maintenance](https://img.shields.io/badge/maintenance-Active-green)

A collection of **Lua-based plugins** designed to enhance gameplay on Aardwolf MUD. These tools focus on quality of life, automation of tedious tasks, and better statistical tracking.

---

## 📂 The Collection

| Plugin | Type | Description |
| :--- | :--- | :--- |
| [**SmartMove**](./SmartMove) | 🏃‍♂️ **Movement** | Context-aware movement. Automatically handles **Sleeping/Resting** (auto-stand) and intelligent combat **Retreat** logic based on class/level. |
| [**GQ Dashboard**](./gq_dashboard) | 🏆 **Utility** | Resizable Global Quest dashboard with tier filters, competition snapshots, cycle progress, and upcoming range visibility. |
| [**StatTracker**](./stats_tracker) | 📊 **Utility** | Comprehensive session tracking. Monitors **XP/hr** (with visual widget), Gold, QP, Trains, and tracks "Bloot" (Bonus Loot) drops. |
| [**Portal Usage Tracker**](./portal_tracker) | 🚪 **Utility** | Tracks portal usage statistics by detecting **equip → WHOOSH** travel and direct `home` commands. Provides persistent stats with table and one-line chat reports. |


> *More utilities will be added to this repository over time.*

---

## 🚀 General Installation

1.  Navigate to the folder of the plugin you want to use (links above).
2.  Download the files listed by that plugin's installation instructions.
    *   Most plugins use one `.xml` file. **GQ Dashboard requires both
        `GQ_Dashboard.xml` and `GQ_Dashboard.lua`.**
    *   *Tip: Click each file, then click the "Download raw file" button.*
3.  Keep the required files together in your MUSHclient
    **`worlds/plugins`** directory or one of its subdirectories.
4.  In MUSHclient:
    *   Press **Ctrl+Shift+P** (or go to **File** → **Plugins**).
    *   Click **Add**.
    *   Select the downloaded file.

---

## 🤝 Support & feedback

If you encounter issues or have feature requests, please check the individual plugin folders for specific instructions or open an issue in this repository.

**Author:** Morienda
