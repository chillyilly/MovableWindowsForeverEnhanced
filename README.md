# Movable Windows Forever

Move Blizzard windows that Edit Mode does not let you move in **World of Warcraft: Forever**.

> This is the **Enhanced** edition — it builds on Movable Windows Forever with the extra options listed below (v0.2.0).

## What's enhanced (v0.2.0)

Everything the original does, plus:

- **Per-window scaling** — hold **Ctrl** and mouse-wheel over a window's title to scale it (50%–200%). Saved per window and reapplied on login.
- **Keyboard nudging** — hover a window's title and use the **arrow keys** to move it one pixel at a time (**Shift** = 10px steps).
- **Off-screen protection** — saved positions are automatically pulled back onto the screen when a window opens and after any resolution or UI-scale change, so a layout saved on one setup can't strand a window out of reach. `/mwf rescue` fixes open windows on demand.
- **Per-character layouts** — optionally give the current character its own window layout instead of the shared account-wide one (**Layout Tools → Separate layout for this character**).
- **Snap to grid** — optional 8px grid snap when you finish dragging a window (**Layout Tools**).
- **Highlight movable windows** — optional overlay that marks each window's draggable title strip with a faint band and its name, so invisible drag areas are easy to find.
- **Layout export / import** — copy your whole layout (positions, scales, enabled windows, options) to a shareable plain-text string, or paste one in. No code execution.
- **Reset safety** — **Reset All Positions** and `/mwf reset` now ask for confirmation, and **`/mwf undo`** restores the layout from before the last reset.
- **Multi-anchor windows** — windows anchored by more than one point now save and restore every anchor point, not just the first.
- **More slash commands** — `/mwf lock`, `/mwf unlock`, `/mwf snap`, `/mwf list`, `/mwf reset <window>`, `/mwf rescue`, `/mwf undo`, `/mwf help`.

A new **Layout Tools** section in the Settings window groups the per-character, snap, highlight, and export/import controls. See the [CHANGELOG](CHANGELOG.md) for the full history.

## Installation

1. Download the addon:
   - From this repo, click **Code → Download ZIP** (or clone it), **or** grab a tagged release under **Releases**.
2. Extract it. You will get a folder whose contents include `MovableWindowsForever.toc`.
3. Make sure the folder is named exactly **`MovableWindowsForever`** (GitHub ZIPs unpack as `MovableWindowsForeverEnhanced-main` or similar — rename it to `MovableWindowsForever`, matching the `.toc`, or the addon will not load).
4. Copy that `MovableWindowsForever` folder into your WoW Forever AddOns directory:
   - `World of Warcraft/<version>/Interface/AddOns/`
   - The final path should be `.../Interface/AddOns/MovableWindowsForever/MovableWindowsForever.toc`.
5. Restart WoW, or at the character-select/login screen open the **AddOns** list and ensure **Movable Windows Forever** is enabled (tick **Load out of date AddOns** if needed).
6. Log in and type **`/mwf`** to open Settings.

This addon targets the **WoW Forever** client (`## Interface: 16001`). It will not load on retail or Classic Blizzard clients without adjusting the interface version.

## Features

- Drag supported Blizzard windows by their normal title area or movable anchor.
- Move Blizzard combined bags or individual player/reagent bag windows; saved bag positions survive Blizzard bag re-anchoring.
- Window positions are remembered between sessions.
- Per-window scaling: hold **Ctrl** and mouse-wheel over a window's title to scale it (50%–200%).
- Keyboard nudging: hover a window's title and use the arrow keys to nudge it a pixel at a time (Shift = 10px steps).
- Off-screen protection: saved positions are clamped back onto the screen on show and after a resolution or UI-scale change; `/mwf rescue` pulls open windows back into view on demand.
- Per-character layouts: optionally give the current character its own layout instead of the account-wide one.
- Layout export / import as a plain-text string for sharing or backup.
- Optional snap-to-grid while dragging and an optional overlay that highlights each draggable title strip.
- Per-window enable/disable controls, grouped into clear Settings sections.
- Lock all saved positions when you are done arranging the UI.
- Reset individual windows or reset every saved position (with a confirmation prompt and `/mwf undo`).
- Standalone Blizzard-style Settings window with the Forever Collection button.
- Optional movable minimap button; left-click or right-click toggles Settings.
- Unprotected supported windows remain movable during combat; WoW-protected frames stay locked until combat ends.
- Spellbook / Talents remains movable outside combat. On Forever, Blizzard protects that frame during combat, so MWF intentionally leaves it locked until combat ends.
- Supports lazily loaded Blizzard UI windows.
- Includes special movable support for the **Party / Raid Manager**, including combat-safe collapse/reopen through an MWF-owned secure holder around the complete manager frame, without calling Blizzard's protected native expand/collapse path in combat.

## Supported windows

Supported panels include Bags (combined and separate player/reagent containers), Character, Merchant, Spellbook / Talents, Map & Quest Log, Guild & Communities, Looking For Group, Collections / Appearance, Calendar, Quest and Gossip dialogue, Bank, Mail, Trainer, Auction House, Professions / Trade Skills, Guild Bank, Social, Inspect, Party / Raid Manager, and compatible alternate Blizzard frame implementations.

## Party / Raid Manager

The Blizzard Party / Raid Manager normally docks to the edge of the screen, so Movable Windows Forever handles it separately from normal title-bar windows. It receives a movable anchor and a relocated expand/collapse control while it is managed. The expanded panel can be dragged from its top strip outside combat, and the detached control can be dragged while the manager is collapsed outside combat. Its detached expand/collapse controls use an MWF-owned secure holder around Blizzard's complete manager frame. This lets a real user click hide/show the full manager during combat without importing Blizzard frame handles into RestrictedExecution or invoking the native protected SetPoint path, while preserving Blizzard's artwork and child regions.

Disabling or resetting Party / Raid Manager support restores the original Blizzard anchor captured before Movable Windows Forever moved it.

## Settings

Movable Windows Forever now uses its own Blizzard-style Settings window instead of the Blizzard AddOns settings category. Open it with:

`/mwf`

Use `/mwf reset` to clear all saved positions (it asks to confirm first). The red **!** button opens the Forever Collection.

Other slash commands:

- `/mwf lock` / `/mwf unlock` — lock or unlock all windows.
- `/mwf reset <window>` — reset a single window (see `/mwf list` for names).
- `/mwf undo` — restore the layout from before the last reset.
- `/mwf rescue` — bring any open, off-screen windows back into view.
- `/mwf snap` — toggle snap-to-grid while dragging.
- `/mwf list` — list managed windows and their state.
- `/mwf help` — show the full command list.

The **Layout Tools** section of Settings adds **Separate layout for this character**, **Snap to grid while dragging**, **Highlight movable windows**, and **Export** / **Import** buttons for sharing or backing up a layout.

The **General** section includes **Show minimap button**. The minimap launcher can be dragged around the minimap and remembers its position between sessions. Both left-click and right-click toggle the Settings window.


## Minimap

The Minimap can be managed like the other supported Blizzard windows. Enable **Minimap** in settings, then **left-drag the Minimap zone title** to reposition it. The position is saved automatically, respects **Lock all window positions**, and can be restored with **Reset**.
