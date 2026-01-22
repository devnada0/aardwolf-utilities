Here is the updated `README.md` using the name **ClanRank**.

***

# ClanRank

**Author:** Morienda  
**Client:** MUSHclient  
**Game:** Aardwolf MUD

## Overview

**ClanRank** is a MUSHclient plugin designed for the **Aardwolf MUD**. It solves a common annoyance: the standard `who <clan>` command shows online members but isn't sorted by rank, while the `roster <clan>` command is sorted by rank but includes offline members.

**ClanRank** combines these two commands. It captures the list of currently online players and cross-references it with the sorted roster to produce a clean, rank-sorted list of only the people currently playing.

## Features

*   **Rank Sorting:** Displays online members sorted from lowest rank to highest (or vice versa depending on game settings), making it easy to find officers or leaders.
*   **AFK Detection:** Automatically detects players marked as `*AFK*` in the `who` list and appends a yellow `[AFK]` tag to their row.
*   **Spam Suppression:** Hides (gags) the raw output from the `who` and `roster` commands, so your screen stays clean.
*   **Universal Support:** Works with any clan, regardless of how they format their `who` output (custom borders, colors, etc).

## Installation

1.  Download the `clanrank.xml` file from this repository.
2.  Open **MUSHclient**.
3.  Go to the **File** menu and select **Plugins** (or press `Ctrl+Shift+P`).
4.  Click the **Add** button.
5.  Navigate to where you saved `clanrank.xml`, select it, and click **Open**.

## Usage

In the game, simply type:

```text
clanrank <clanname>
```

### Examples:
*   `clanrank boot`
*   `clanrank emerald`

## Example Output

```text
Checking online members for clan: boot...

--- Online Members of boot (Sorted by Rank) ---
No.  Name         Rank                 Lvl  Class     
-----------------------------------------------------------------
313  Player01     Drill Sergeant       53   Cleric    
340  Player02     General              201  Mage       [AFK]

-----------------------------------------------------------------
End of sorted online list.
```

## How It Works

1.  **Snapshot:** The plugin sends `who <clan>`. It captures the raw text of every line containing a player name. It keeps the raw text so it can detect flags like `(OPK)`, `(Linkdead)`, or `*AFK*`.
2.  **Cross-Reference:** Once the `who` list is captured, the plugin sends `roster <clan> 2` (which asks the game for a roster sorted by rank).
3.  **Filter:** As the roster lines arrive, the plugin performs a reverse-lookup. It checks if the name on the roster exists within the list of online players captured in step 1.
4.  **Display:** If a match is found, it formats the line and prints it to the screen. If the original capture contained `*AFK*`, it appends the tag. Offline members are ignored.
