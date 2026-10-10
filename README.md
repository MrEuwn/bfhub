# BFHub

Blox Fruits script hub. No UI library (raw `Instance.new` GUI) -> smallest footprint on mobile executors like Delta.

## Run

Paste this one line into Delta (or any UNC executor) and execute:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

`bfhub.lua` fetches the modules under `src/` from this repo at runtime, so you only ever paste one line and updates are instant.

## Tabs / features

- **Farm** - auto farm nearest, selected mob, include bosses, farm speed, auto quest (level), auto chest, auto berry, auto material.
- **Combat** - fast attack, kill aura (+radius), god mode, auto buso, auto ken, race v4 transform.
- **Fruit** - fruit sniper (auto tp + pick), auto store fruit (min rarity), auto devil fruit mastery, fruit notifier.
- **ESP** - fruit / chest / island / player ESP.
- **Teleport** - live island list (read from `workspace._WorldOrigin.Locations`, so Sea 1/2/3 are covered automatically) + tp to nearest player.
- **Sea Events** - **Auto Mirage**: hops servers until Mirage Island spawns, then stops hopping and teleports onto it. Optional targets: full moon, kitsune, prehistoric.
- **Shop** - buy items via the game buy remote.
- **Misc** - noclip, infinite jump, fly, walk on water, server hop, anti-afk, FPS boost, anti-night.

## Layout

```
bfhub.lua          entry point (paste this)
src/util.lua       services, tp, remotes, world/island helpers
src/ui.lua         minimal custom GUI
src/config.lua     runtime state store
src/farm.lua  combat.lua  fruit.lua  esp.lua
src/teleport.lua  sea.lua  shop.lua  misc.lua
```

## Status / caveats

- All files pass `luau-compile` (syntax clean). Not yet runtime-tested in-game.
- Remote names (`CommF_` args like `getLevel`, `StartQuest`, `Buy`) are best-effort and may need adjusting per game version - each spot is marked with a `ponytail:` comment naming the ceiling.
- Mirage/full-moon detection uses live game state, not hardcoded coords, so it survives map updates.
- Using this violates Roblox ToS. Test on an alt.
