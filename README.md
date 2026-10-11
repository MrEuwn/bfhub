# Raf's Personal Script

Blox Fruits hub for Delta (mobile). One paste line:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

## What this is

The feature set is a **recovered hub**: the Blox Fruits build of "Speed Hub X
v5.5.0" was protected with Luraph v15, deobfuscated to readable Luau
(191 KB, 6764 lines), and grafted onto our own lightweight UI.

- **149 controls across 37 sections** - the original feature set, intact.
- **No key system.** The original's key check and luarmor loader are stripped.
- **No telemetry.** A webhook that phoned home to the author's repo is removed.
- **Our own UI.** The author's UI library was itself obfuscated, so it was
  replaced by `src/uilib.lua` (raw `Instance.new`, ~18 KB) which implements the
  same call surface. That keeps it light on mobile.

## Layout

```
bfhub.lua        entry: fetches modules, runs the hub, adds extras
src/util.lua     services, teleport, tween, notify
src/config.lua   config store
src/quests.lua   81-row quest table (level range -> quest/mob/position)
src/uilib.lua    UI shim (Instance.new) - replaces the obfuscated library
src/funcs.lua    FuncsV3 adapter (thin, readable upstream)
src/hub.lua      the recovered hub body (180 KB)
src/log.lua      error log + webhook reporting
reference/       the deobfuscated source + notes, for study
```

## Feature map (from the recovered hub)

Configuration, Local Player, Server Manager, Stat Manager, Stack Farming, Hop
Boss, Level Farming, Nearest Enemy Farming, Mastery Farming, Collection
Farming, Boss Farming, Material Farming, Third World, Dragon Hunter, Tyrant of
the Skies, Citizen Quest, Kitsune Island, Sea Event, Leviathan Farming, Wood
Planks, Prehistoric Island, Sea Items, Fruits, Shop, Automation Fishing, Mirage
Island, Upgrade Race, Raid, ESP, Anti-Cheat Bypass, Team, Menu UI, Redeem,
Water, Remove Effects, Automations, Reset Config.

## Notes

- Roblox ToS: this is a cheat. Ban risk is real. Use an alt account.
- `reference/deobf-bloxfruit-v15-full.lua` is the raw deobfuscated source.
- `reference/hoho-feature-map.txt` is HoHo Hub's own feature tree.
