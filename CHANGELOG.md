# 0.1.79
- The Legacy window (Y) can now be moved: known Legacy frame names are managed, and any other Legacy window is detected the first time it opens from its micro button or key.
- The Achievements row is now "Achievements / Legacy" and covers both.

# 0.1.78
- Section dividers are now snapped to whole screen pixels, so identical dividers always look the same (before, one could look thinner or brighter than another depending on where it fell on the screen).

# 0.1.77
- The settings window now uses the Blizzard Options-window look shared with Social Filter Forever: the flat charcoal Options body, white Options section headers with the Options divider, minimal Options check boxes with hover bands, an Options slider with arrow steppers, the Options (WowStyle2) dropdown for the Raid Manager toggle skin, and the Options tooltip.
- The look ships inside the addon (ForeverUI.lua); it does not need Social Filter Forever or any other Forever addon. Window moving and every setting work exactly as before.

# 0.1.76
- Updated the embedded Forever catalogue from v0.2.38 to v0.2.40 (15 public addons, including Social Filter Forever).
- Every catalogue card now shows its addon's own icon, even when that addon is not installed (icons bundled in Media/Catalogue).

# 0.1.75
- Updated the embedded Forever catalogue to v0.2.38: added Note Bag Forever and Talent Calculator Forever (14 public addons).

# 0.1.74

- Fixed the Social window mover by supporting Blizzard's `SocialUIFrame` in addition to the legacy `FriendsFrame`.
- The existing Social setting and reset control now manage both compatible Social frame implementations.

# 0.1.73
- Updated the embedded Forever Collection catalogue from v0.2.31 to v0.2.36.
- Synced the embedded catalogue directly with Darkspore Suite Forever v0.2.36.
- No Movable Windows functionality or SavedVariables were changed.

# 0.1.72
- Fixed Current Raid Arrow no longer flipping between open and closed states.
- Current now applies Blizzard's full native forward/back artwork for each state instead of copying only texture coordinates.
- Both states still use the same fixed button center and geometry reference.
- The Raid Manager Arrow Rotation slider continues to rotate Current after its native state is selected.
- Other Raid Manager arrow skins are unchanged.

# 0.1.71
- Made the Raid Manager Arrow Rotation slider apply to every arrow skin instead of only Current Raid Arrow.
- Expand / Collapse now rotates its real Normal, Pushed, Disabled, and Highlight button states with the selected angle.
- Spellbook, Scrollbar, Map, and Green Stream arrows now preserve their open/closed direction and then apply the selected slider rotation.
- Green Stream rotates only its arrow glyph so the surrounding button shell stays fixed.
- Current Raid Arrow behavior is otherwise unchanged.

# 0.1.70
- Restored the Raid Manager Arrow Rotation slider in Settings.
- Slider again provides the four saved orientations: 0°, 90°, 180°, and 270°.
- Restored mouse-wheel adjustment and the live degree readout.
- Kept the Raid Manager Toggle Button Skin selector directly underneath the rotation slider.
- No other Raid Manager skin behavior was changed from 0.1.69.

# 0.1.69
- Rebuilt from 0.1.67 and restored the Raid Manager arrow rotation function.
- Current Raid Arrow keeps 0.1.67's native Blizzard open/closed texture-state behavior, then rotates the completed native tab into MWF's top-mounted orientation.
- Restored the internal 270-degree arrow rotation without restoring the removed angle slider.
- Did not carry forward the 0.1.68 dimension-swap approach.
- Other Raid Manager skins remain unchanged.

# 0.1.67
- Corrected Current Raid Arrow behavior to match Blizzard's native Raid Manager toggle.
- The surrounding tab/button now remains completely stationary between open and closed states.
- Only the arrow state changes: closed points toward the flat edge, open points toward the curved edge.
- Removed rotation and the previous 1-pixel alignment compensation from Current Raid Arrow.
- Other Raid Manager toggle skins are unchanged.

# 0.1.66
- Fine-tuned Current Raid Arrow alignment by moving only its collapsed/up state 1 pixel upward.
- Keeps the same native artwork, proportions, rotation behavior, and fixed button center.
- No changes to the other Raid Manager toggle skins.

# 0.1.65
- Fixed the remaining Current Raid Arrow pixel shift between open and collapsed states.
- Current Raid Arrow now uses one identical captured Blizzard arrow artwork for both states and only rotates that same image up/down.
- Preserved the arrow's native proportions and fixed 32x32 button center.
- No changes to the working interactive Expand / Collapse skin or other Raid Manager skins.

# 0.1.64
- Reversed the interactive Expand / Collapse skin state so collapsed starts with the up arrow and open uses the down arrow.
- Fixed Current Raid Arrow deformation by keeping Blizzard's original artwork dimensions and centering them inside a stable 32x32 button.
- Current Raid Arrow once again rotates between up/down states without changing its visual center.
- Fixed Arrow - Map so it changes direction again using Blizzard's dedicated Arrow-Up-Up / Arrow-Down-Up textures instead of rotating an asymmetrically padded texture.

# 0.1.63
- Reworked the Raid Manager Expand / Collapse skin to use the same native Blizzard Button-state implementation as Minimap Button Groups Forever.
- Added the real Normal, Pushed, Disabled, and Highlight atlas states, including hover and mouse-down interaction.
- Expand / Collapse now swaps between Blizzard's up/down state artwork using the actual Raid Manager open/collapsed state.
- Preserved the Current Raid Arrow skin by restoring its captured native Blizzard artwork when selected.

# 0.1.62
- Fixed Raid Manager Map arrow shifting position between open and collapsed states.
- Map arrow now stays pointed down in both states so Blizzard's asymmetrically padded texture remains pixel-stable.
- Fixed Current Raid Arrow shifting by normalizing both native toggle states to the same 32x32 button footprint.
- Other arrow skins keep their state-aware down/open and up/collapsed behavior.

# 0.1.61
- Raid Manager toggle skins are now state-aware: arrows point down while the manager is open and up while it is collapsed.
- Restored the natural Blizzard Expand / Collapse up/down state instead of forcing both states downward.
- No rotation setting was reintroduced.

# 0.1.60
- Removed the Raid Manager Arrow Rotation slider.
- Raid Manager toggle arrow skins now use a fixed downward direction.
- Removed Arrow - Side Tab from the Raid Manager toggle skin list.
- Kept Blizzard Expand / Collapse, Current Raid Arrow, Spellbook, Scrollbar, Map, and Green Stream Arrow skins.
- Existing saved arrow-rotation values are ignored for backward compatibility.

# 0.1.59
- Added support for moving the Blizzard Achievements window (`AchievementFrame`).
- Achievements is now listed in Settings under Character & Social.
- Increased the Settings window height slightly and moved Group & Navigation down to keep the added row cleanly spaced.

# 0.1.58
- Added a Raid Manager Toggle Button Skin selector under the arrow rotation slider.
- Blizzard Expand / Collapse is the new default toggle artwork.
- Kept the previous MWF Raid Manager arrow as Current Raid Arrow.
- Added arrow-style skins based on Minimap Button Groups Forever: Spellbook, Scrollbar, Map, Side Tab, and Green Stream Arrow.
- Existing Raid Manager Arrow Rotation continues to rotate the selected arrow artwork where applicable.

# 0.1.56
- Fixed a MinimapCluster Lua error when switching display mode or UI scale by removing unsafe SetUserPlaced calls from minimap-specific positioning paths.

## 0.1.52

## 0.1.55 — settings footer spacing

- Increased the Settings window height slightly.
- Added proper breathing room below **Party / Raid Manager**.
- **Reset All Positions** and the footer text no longer overlap the last Group & Navigation row.
- No window-movement behavior changes.

## 0.1.54 — drag Minimap by zone title

- Minimap movement now uses the **zone title** as its drag handle.
- Simply **left-drag the zone title** to move the Minimap; Alt is no longer required.
- Normal interaction directly on the Minimap remains untouched.
- Saved position, Reset, and **Lock all window positions** behavior are unchanged.
- Added compatibility lookup for Blizzard's alternate zone-title frame layouts.

## 0.1.53 — movable Minimap

- Added **Minimap** to Supported Blizzard windows.
- Use **Alt + left-drag** directly on the Minimap to move it while preserving normal minimap clicks and addon buttons.
- Minimap position is saved across `/reload` and relog.
- **Lock all window positions** also locks Minimap movement.
- Per-window **Reset** restores Blizzard's original Minimap position.
- Disabling Minimap management restores its native Blizzard position.
- Saved Minimap placement is reapplied after login, entering the world, UI-scale changes, and Blizzard frame-position refreshes.

- Reworked the minimap launcher to use LibDBIcon when available so Show minimap button reliably hides and restores it; native button remains as fallback.

## 0.1.51
- Fixed the minimap launcher still using the old generic gear texture.
- The minimap launcher now uses Movable Windows Forever's bundled custom logo.
- Synchronized the internal addon version with the TOC version.

## 0.1.50
- Updated Movable Windows Forever to use its own custom addon logo where self-identity icons are needed.
- The new logo is now used for MWF's own minimap launcher and **Esc → AddOns** icon.

## 0.1.45
- Updated the Forever Collection catalogue to include **Minimap Button Groups Forever**.
- Bumped the shared catalogue revision so the new entry takes priority over older embedded catalogue copies.

## 0.1.44
- Added movable support for Blizzard's combined bag window and separate player/reagent bag windows.
- Added a **Bags** toggle/reset row to Settings.
- Bag positions are re-applied after Blizzard's `UpdateContainerFrameAnchors` runs so opening, closing, or refreshing bags no longer snaps them back to Blizzard's default anchors.
- Kept the combined-bag utility controls clickable by reserving the right side of its title area.

## 0.1.43
- Moved Raid Manager Arrow Rotation below the Trainer row into the intended empty right-column space.
- Prevented the rotation control from overlapping the Trainer setting.

## 0.1.42
- Added a saved Raid Manager Arrow Rotation slider with four snap positions: 0°, 90°, 180°, and 270°.
- Applying a rotation updates the Blizzard-derived Raid Manager toggle artwork immediately.
- When Party / Raid Manager movement is enabled without a saved position, its mover now appears at a safe visible default location instead of relying on an edge/off-screen native anchor.
- Existing player-saved Raid Manager positions remain unchanged and continue to take priority.

## 0.1.40
- Fixed the Party / Raid Manager toggle artwork on Forever clients.
- The secure MWF toggle now copies Blizzard's live native texture/atlas coordinates instead of assuming the arrow states are packed horizontally.
- Keeps the existing combat-safe expand/collapse and drag behavior unchanged.

# Changelog

## 0.1.39
- Replaced the custom Party / Raid Manager v/^ toggle with Blizzard's native raid-manager arrow artwork.
- Kept the existing combat-safe secure expand/collapse behavior and drag handling unchanged.

## 0.1.38
- Changed the Settings version number to the shared Forever gold used across the addon collection.

## 0.1.37
- Prepared the current standalone Blizzard-style Settings build for the next public release.
- Includes the organized Settings sections, public-only Forever Collection, optional minimap button, and left/right-click Settings toggle.
- Release-file cleanup only; no existing window-movement behavior was removed.

## 0.1.36
- Minimap button now toggles Settings with both left-click and right-click.
- Left-button dragging still moves the minimap button.

## 0.1.35
- Minimap button now toggles the Settings window open and closed with left-click.

## 0.1.34 — Minimap button
- Added a **Show minimap button** checkbox to the General section.
- Added a movable minimap launcher for quick access to Movable Windows Forever Settings.
- Left-clicking the minimap button opens Settings; dragging moves it around the minimap.
- The minimap button visibility and position are saved between sessions.

## 0.1.33 — Settings organization
- Reorganized the standalone Settings window into clear functional sections.
- Added Blizzard-style section separators for Character & Social, Group & Navigation, and NPC & Services.
- Sorted windows alphabetically inside each section.
- Switched the supported-window list to a compact two-column layout for faster scanning.
- Kept per-window Reset controls aligned consistently.
- Added a fallback Other section for future supported frames.
- Tightened the footer and Reset All layout.

## 0.1.32 — Native Blizzard settings window & Forever Collection

- Moved Movable Windows Forever out of the Blizzard AddOns settings category and into its own standalone Blizzard-style Settings window.
- Added the same fixed dark Blizzard dialog background and native panel frame used across the Forever UI.
- Added a left-aligned title, version display, movable title bar, and native close button.
- Added the red **!** Forever Collection button while keeping the Settings window open underneath.
- Embedded the corrected public-only Forever Collection catalogue.
- The catalogue is restricted to the 10 public Forever addons; Darkspore Dev Forever and other private/internal registrations are excluded from the visible list.
- Kept all existing movable-window, reset, combat-safety, and Party / Raid Manager behavior unchanged.

## 0.1.31 — Spellbook combat cleanup

- Removed the experimental secure combat-drag path for Spellbook / Talents because it was not reliable on WoW: Forever.
- Restored the standard, combat-safe drag implementation: Spellbook / Talents remains movable outside combat and is left untouched while Blizzard protects it in combat.
- Removed the associated secure attributes, combat-move bookkeeping, and post-combat persistence code.
- Kept the working Party / Raid Manager implementation from 0.1.29/0.1.30 unchanged.

## 0.1.30

- Added a secure combat-drag path for Spellbook / Talents. Blizzard blocks normal `StartMoving()` on its protected frame during combat, so MWF now records the drag securely and applies the new position on mouse release.
- Spellbook / Talents keeps normal smooth dragging outside combat; during combat the frame jumps to the released position rather than visually following the cursor.
- Saves the resulting secure combat position after combat ends so it does not revert to the pre-combat location.
- Left the working Party / Raid Manager implementation from 0.1.29 unchanged.

## 0.1.29 — Raid Manager visual restoration

- Fixed Party / Raid Manager opening with missing native artwork/visual regions in 0.1.28.
- The combat-safe secure holder now contains the entire Blizzard Raid Manager frame instead of only `displayFrame`, preserving its complete native appearance when collapsed/reopened in combat.
- Removed the experimental Spellbook / Talents panel-layout override; it did not enable combat dragging and could alter Blizzard's normal panel placement behavior.
- Spellbook / Talents remains movable outside combat, while Blizzard-protected combat dragging remains unavailable under the current secure-frame restrictions.

## 0.1.28 — Combat position and Raid Manager secure-state fix

- Fixed Spellbook / Talents snapping to Blizzard's fixed panel position when first opened during combat; MWF now preconfigures the protected panel so Blizzard shows it without re-anchoring it.
- Spellbook / Talents still cannot be freely dragged once combat lockdown has started, but it now keeps the MWF position that was configured before combat.
- Reworked Party / Raid Manager combat collapse/reopen again: MWF no longer forwards clicks to Blizzard's native toggle or imports Blizzard frame handles into RestrictedExecution.
- Party / Raid Manager now uses an MWF-owned secure visibility holder for the manager display, allowing the detached expand/collapse controls to work during combat without calling Blizzard's protected SetPoint/Expand/Collapse path.
- Combat collapse state is synchronized back to SavedVariables after combat and preserved across reloads.

## 0.1.27 — Raid Manager restricted-handle fix

- Fixed `RestrictedFrames.lua: Invalid frame handle` when using MWF's Party / Raid Manager control during combat.
- Replaced direct restricted-environment access to Blizzard's manager/display frames with secure clicks on Blizzard's own native expand/collapse buttons.
- Keeps MWF's detached expand/collapse buttons synchronized without importing Blizzard manager frames into RestrictedExecution.
- Spellbook / Talents remains movable outside combat only when Blizzard marks the frame protected; combat dragging cannot be safely forced by addon code.

## 0.1.26 — Raid Manager combat toggle

- Party / Raid Manager can now be collapsed and reopened from MWF's detached control during combat using a secure click handler.
- Combat collapse/expand keeps the manager on MWF's saved anchor and synchronizes back to Blizzard's native collapsed state when combat ends.
- Fixed combat-end reconciliation ordering so an in-combat collapse/open choice is not replaced by the pre-combat state.
- Avoids insecure protected-frame updates while combat lockdown is active.
- Clarified that protected windows such as Spellbook / Talents still cannot be dragged by normal addon code during combat under Blizzard's current protected-frame rules.

## 0.1.25 — Protected combat-drag safety

- Fixed failed combat drag attempts on protected windows still calling the restricted stop-moving path.
- Added clear in-game feedback when Blizzard marks a window as protected and therefore immovable during combat.
- Added drag-state tracking so only windows that actually started moving are stopped and saved.
- Active drags are now finalized immediately before combat lockdown begins, preventing mid-drag combat transitions from leaving stale or unsaved positions.
- Applied the same rejected-drag protection to the Party / Raid Manager controls.

## 0.1.24 — Combat dragging fix

- Removed the blanket combat-lockdown block from normal movable windows.
- Unprotected Blizzard windows can now be dragged and have their new positions saved during combat.
- Protected Blizzard frames remain blocked during combat, as required by WoW's protected-frame restrictions.
- Party / Raid Manager keeps its stricter combat handling because its managed frame is protected.

## 0.1.23 — Forever Looking For Group fix

- Fixed **Looking For Group** movement on WoW: Forever by supporting the Forever-specific `LFGParentFrame` loaded by `Blizzard_GroupFinder_VanillaStyle`.
- Retained `PVEFrame` as an alternate-client fallback under the same Looking For Group setting.

## 0.1.22 — Modern Forever window coverage

- Added modern **PlayerSpellsFrame** support plus Classic/alternate talent-frame fallbacks so Spellbook and Talents can be moved.
- Added **WorldMapFrame** support for the combined Map & Quest Log window.
- Added Guild & Communities, Looking For Group, Collections / Appearance, and Calendar support.
- Kept legacy frame aliases for compatibility with alternate Forever UI implementations.
- Party / Raid Manager's detached expand/collapse control can now be dragged while the manager is collapsed, with a drag hint in its tooltip.
- Increased the Party / Raid Manager top drag strip slightly for easier grabbing.
- Tightened Settings row spacing to keep the expanded supported-window list visible.

## 0.1.21 — Publishing cleanup

- Party / Raid Manager now restores the exact Blizzard anchor captured before Movable Windows Forever manages it when support is disabled.
- Disabling Party / Raid Manager no longer recreates MWF controls on the next UI load.
- Restores the manager's pre-MWF controller/jump-hint visibility when special handling is disabled.
- Resetting Party / Raid Manager now uses the captured Blizzard position instead of a hardcoded screen coordinate.
- Fixed deferred combat handling for Party / Raid Manager so it never falls through the generic `SetUserPlaced` path.
- Updated the in-game Settings description and README for movable-anchor and Party / Raid Manager behavior.
- Cleaned duplicate changelog headings and release wording.

## 0.1.18 — Party / Raid Manager reopen fix

- Fixed the detached top arrow changing state while the Party / Raid Manager itself stayed invisible.
- Expanding now restores the manager parent before calling Blizzard's native expand path.
- Explicitly restores Blizzard's native display frame after expansion while keeping collapse behavior and the saved movable anchor intact.

## 0.1.17

- Fixed the Party / Raid Manager arrow changing state while the actual manager stayed invisible.
- Collapsing no longer hides Blizzard child regions individually, which could leave them permanently hidden after expanding.
- The collapsed manager now uses parent transparency only, preserving Blizzard's native expand/collapse state and contents.

## 0.1.16

- Fixed the custom top Party / Raid Manager collapse/expand button not responding.
- Uses Blizzard's explicit expand/collapse path first, with Forever Forward/Back button compatibility fallbacks.
- Reapplies the saved movable position after the native manager changes state.

## 0.1.15 — Party / Raid Manager toggle persistence

- Fixed the custom top collapse/expand button disappearing after the Party / Raid Manager was collapsed or hidden.
- The top toggle remains available at its saved location whenever Party / Raid Manager management is enabled.
- Prevented the generic panel-position hook from applying normal `SetUserPlaced` handling to `CompactRaidFrameManager`.

## 0.1.14 — Party / Raid Manager settings entry

- Restored the **Party / Raid Manager** entry to a clearly visible position in Settings.
- Moved it near the top of the supported-window list.
- Tightened row spacing so the complete supported-window list fits more reliably.
- Corrected the in-addon version display.

## 0.1.13 — Party / Raid Manager cleanup

- Hid Blizzard controller/jump-hint overlays while the Party / Raid Manager is managed.
- Removed stray round buttons that appeared after moving the panel.
- Kept the custom top collapse button and movable anchor behavior unchanged.

## 0.1.12

- Fixed Party / Raid Manager taint/error caused by calling `SetUserPlaced()` on Blizzard's non-movable CompactRaidFrameManager.
- The special movable anchor repositions the manager without changing its user-placed state.

## 0.1.11

- Fixed a nil-function error when resetting the Party / Raid Manager.
- Corrected the special Party / Raid Manager function declaration order.

## 0.1.10

- Rebuilt Party / Raid Manager support from the stable 0.1.4 base.
- Uses an independent movable anchor instead of fighting Blizzard's frame position directly.
- Added a reliable top drag strip and top collapse/expand button.
- Keeps Blizzard's native expanded/collapsed state while hiding the empty manager shell when collapsed.

## 0.1.4

- Added **Party / Raid Manager** support (`CompactRaidFrameManager`).
- Added a dedicated thin top-border drag strip so the manager's own header controls remain clickable.
- Reapplies the saved position after expanding/collapsing the manager and keeps protected-frame handling combat-safe.

## 0.1.3

- Fixed duplicate Professions entries in Settings.
- TradeSkillFrame and ProfessionsFrame are handled as one user-facing Professions option while retaining compatibility with either Blizzard frame.

## 0.1.2

- Tightened Settings row spacing so the bottom controls fit cleanly inside the panel.
- Moved Reset All Positions and the footer tip above the Settings bottom separator.

## 0.1.1

- Fixed duplicate Auction House entries in Settings.
- AuctionFrame and AuctionHouseFrame are handled as one user-facing Auction House option while retaining compatibility with either Blizzard frame.

## 0.1.0

- Initial release.
- Added draggable support for common Blizzard windows not handled by Edit Mode.
- Added saved positions and per-window enable controls.
- Added Lock All, Reset, and Reset All controls.
- Added `/mwf` settings command and `/mwf reset`.
- Added lazy-loaded frame support and basic combat-safe deferral.
