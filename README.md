# Movable Windows Forever

Move Blizzard windows that Edit Mode does not let you move in **World of Warcraft: Forever**.

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
