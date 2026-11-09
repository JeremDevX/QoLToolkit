# QoL Toolkit

QoL Toolkit is a modular addon for **World of Warcraft Forever 1.60.1**. Build talent plans, track your session, and customize your interface from one dashboard.

## Modules

| Module | What it does |
| --- | --- |
| Talent Planner | Build a plan point by point. The talent tree shows when to take each rank and highlights the next available point. |
| Session Journal | Track time, XP, time to the next level, gold, deaths, and levels gained. Hover over XP or money gained for hourly rates. |
| Effect Reminders | Pick buffs, auras, stances, and tracking effects to watch. A customizable window shows the missing effects. |
| Tooltips | Move or scale supported tooltips, or have them follow the cursor. The addon preserves quest and tooltip content supplied by WoW. |
| Spell Rank Guard | Flag spells on supported action bars when a higher rank is already in your spellbook. Add exceptions for ranks you keep on purpose. |
| Target Distance | Display a color-coded distance or range estimate above the target frame's name. |
| Bags | Color item borders by rarity, adjust inner and outer glow, and optionally sort when you manually open your bags outside combat and away from the bank. |
| Advanced Settings | Browse available client settings and graphics options, check defaults, and reset individual or selected settings. |

Use the dashboard to pin modules, preview appearance changes, and position supported windows. Named profiles share selected module settings across characters on the same account. Talent builds and journal totals stay with their character.

## Install

1. Put the addon folder in `World of Warcraft/_forever_/Interface/AddOns/` and name it `QoLToolkit`. The `QoLToolkit.toc` file should sit directly inside that folder.
2. Restart WoW after installing. Open **Settings > Add-ons > QoL Toolkit** or type `/aqol`.
3. Open the default talent window with `N` to use the planner. Click **QoL** in the Blizzard bag header for quick bag settings.

The addon follows the game client language. A French client uses French. English is used on English clients and as the default on other clients.

When updating, keep the folder name and your existing SavedVariables.

## Local diagnostics

Type `/aqlog start`, reproduce the behavior manually, then use `/aqlog stop`. Open `/aqlog show` out of combat and copy the selected trace with Ctrl+C. Use `/aqlog mark` during capture to mark a step or `/aqlog clear` to erase the trace.

The addon samples frame geometry and selected events twice per second for up to two minutes. The trace includes visibility, anchors, scale, strata, and frame level. It stores the latest capture in WoW's local addon settings and starts a fresh trace on each explicit start. Copy the trace from the export window to share it.

## Development

- [QoLToolkit.toc](QoLToolkit.toc) defines the WoW interface version, saved variables, and Lua load order. [Core/](Core/) contains startup, shared UI, and settings. [Modules/](Modules/) contains the gameplay features.
- [Locales/](Locales/) contains English translations. Wrap player-facing text in `L("French source text")` and add its English translation to the matching catalog. Use `L(text, key)` when the same French label needs different translations by context. Keep IDs, saved values, and text supplied by WoW or players independent of the locale.
- [docs/](docs/) contains the [French user guide](docs/LISEZ-MOI.fr.txt) and advanced settings inventory.
- Run `lua tests/check.lua` from the repository root with Lua 5.1 to check the manifest, syntax, locale selection, and reminder matching offline.
- See [AGENTS.md](AGENTS.md) for WoW Forever API, asset, and testing rules.

## Releases

See [Releasing on CurseForge](docs/RELEASING.md) for the webhook, repository rules, and tag process.
