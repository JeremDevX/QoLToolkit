# QoL Toolkit

QoL Toolkit is a modular addon for **World of Warcraft Forever 1.60.1**. Build talent plans, track your session, and customize your interface from one dashboard.

Click the minimap icon or type `/qt` to open the standalone settings window. Tabs group Character, Interface, Customization, and Tools; subtabs select each module. Drag the title to move the window, use Size to resize it, and close it with Escape or Close. The Blizzard Add-ons categories also link to this window.

## Modules

| Module | What it does |
| --- | --- |
| Talent Planner | Build a plan point by point. The talent tree shows when to take each rank and highlights the next available point. |
| Session Journal | Track time, XP, time to the next level, gold, deaths, and levels gained. Hover over XP gained or the gold balance for hourly rates. Start or stop tracking manually, or enable automatic AFK pauses. |
| Effect Reminders | Pick buffs, auras, stances, and tracking effects to watch. A customizable window shows the missing effects. |
| Tooltips | Move or scale supported tooltips, or have them follow the cursor. Unit tooltips can also show a measured or estimated distance. WoW quest details and tooltip content are preserved. |
| Spell Rank Guard | Flag spells on supported action bars when a higher rank is already in your spellbook. Add exceptions for ranks you keep on purpose. |
| Target Distance | Show a measured distance or range estimate on the target frame. Customize placement, badge style, and colors for the badge and unit tooltip. |
| Bags | Customize rarity colors, border thickness, and inner glow. Mark uncollected appearances and optionally sort on manual bag opening, outside combat and away from the bank. |
| Flight Times | Time flight master routes, see known durations on the taxi map, and export local measurements. |
| Advanced Settings | Browse available client settings and graphics options, check defaults, and reset individual or selected settings. |

The dashboard groups tools under Character, Interface, Customization, and Tools. Pinning moves a module card to Favorites without duplicating it. Tooltip and distance settings share one page, while their displays remain independently controlled. Local Move buttons open the shared Layout editor; Apply keeps moved frames and Cancel restores their original placement. Both actions return to the original settings section. The minimap button can be dragged or hidden from the dashboard. Named profiles share selected module settings across characters on the same account. Talent builds and journal totals stay with their character. Partial profiles include each module’s shared/custom appearance choice. Profiles and talent builds can be deleted after confirmation.

Search from the dashboard to find settings across modules. Results open the matching section, expand its detailed options when needed, and scroll to the control. Controls that depend on a disabled option lead to that prerequisite. Searching never changes the option. Clear the search to return to the dashboard.

The talent build menu offers **Duplicate**, **Export**, and **Import**. Copy or paste the versioned text in the transfer window. Imports validate the class, tree, first-point level, and complete point order before adding a new build after confirmation. Existing builds are preserved. This format is specific to QoL Toolkit.

Spell Rank Guard checks ranks and discovers action buttons every 30 seconds, immediately when opening a trainer, and immediately when learning a spell. Action-bar changes still refresh existing buttons promptly. Button discovery waits until combat ends when necessary.

Session Journal includes **History and progression**: the character's last 100 saved sessions, all-time/7-day/30-day summaries, tracked time, XP, levels, deaths, net gold, and hourly rates weighted by tracked duration. Select a session to view its cumulative XP or net gold curve, or compare hourly rates across sessions. Pauses are excluded. Sessions shorter than one minute have no hourly rate. Incomplete XP remains marked with ≥.

**Save and start a new session** archives the current counters. Resetting stats also saves them first. A new login archives the previous session; `/reload` resumes it without creating a duplicate. The active session is shown separately from saved totals. History remains with the character and is excluded from profiles. Samples are taken once per minute while tracking, even when the journal window is hidden, and compacted to at most 120 points per session. Older sessions from before this update have no reconstructed dates or curves. Individual and bulk history deletion require confirmation.

Layout changes require **Apply**. Cancelling or logging out restores the original placement while preserving other settings changed during the preview.

## Install

1. Put the addon folder in `World of Warcraft/_forever_/Interface/AddOns/` and name it `QoLToolkit`. The `QoLToolkit.toc` file should sit directly inside that folder.
2. Restart WoW after installing. Click the minimap icon or type `/qt` to open settings.
3. Open the default talent window with `N` to use the planner. Click **QoL** in the Blizzard bag header for quick bag settings.

The addon follows the game client language. A French client uses French. English is used on English clients and as the default on other clients.

When updating, keep the folder name and your existing SavedVariables.

## Commands

- `/qt` opens the dashboard.
- `/qtsession` opens the journal settings. Add `start` or `stop` to control tracking.
- `/qttooltip` opens the shared Layout editor with tooltips selected. Add `options` to open tooltip settings.
- `/qtbuild` reopens the talent plan when the talent tree is open.
- `/qtrank on` and `/qtrank off` control spell rank warnings.
- `/qtlog` shows the diagnostics commands.

## Settings and appearance

Module settings distinguish visibility from tracking and automatic actions. Hiding the journal keeps tracking running; use its play/pause control to stop tracking. Bag sorting, rarity borders, and transmog markers are independent. Quick bag settings contain these three switches and a link to the full editor.

Shared appearance applies unless a module uses custom appearance. Inherited controls are disabled. Detailed appearance controls are collapsed by default. Configure mouseover distance in the Distance section of Tooltips and distance.
The journal groups Tracking and statistics separately from Display. Effect Reminders groups Tracked effects separately from Display. Display brings visibility, compact mode, appearance, previews, and placement together. Shared-theme links open common appearance settings with a return button for the original module.

Advanced graphics are opt-in. The read-only client inventory is under Diagnostics, also available with /qtlog inventory.

## Local diagnostics

Type `/qtlog start`, reproduce the behavior manually, then use `/qtlog stop`. Open `/qtlog show` out of combat and copy the selected trace with Ctrl+C. Use `/qtlog mark` during capture to mark a step or `/qtlog clear` to erase the trace.

The addon samples frame geometry and selected events twice per second for up to two minutes. The trace includes visibility, anchors, scale, strata, and frame level. It stores the latest capture in WoW's local addon settings and starts a fresh trace on each explicit start. Copy the trace from the export window to share it.

## Development

- [QoLToolkit.toc](QoLToolkit.toc) defines the WoW interface version, saved variables, and Lua load order. [Core/](Core/) contains startup, shared UI, and settings. [Modules/](Modules/) contains the gameplay features.
- [Locales/](Locales/) contains English translations. Wrap player-facing text in `L("French source text")` and add its English translation to the matching catalog. Use `L(text, key)` when the same French label needs different translations by context. Keep IDs, saved values, and text supplied by WoW or players independent of the locale.
- [docs/](docs/) contains the [French user guide](docs/LISEZ-MOI.fr.txt) and advanced settings inventory.
- [Flight contributions](docs/CONTRIBUTIONS-VOLS.md) explains how to export, validate, and publish measured flight times.
- Run `lua tests/check.lua` from the repository root with Lua 5.1 to check the manifest, syntax, locale selection, and reminder matching offline.
- See [AGENTS.md](AGENTS.md) for WoW Forever API, asset, and testing rules.

## Releases

See [Releasing on CurseForge](docs/RELEASING.md) for the webhook, repository rules, and tag process.
