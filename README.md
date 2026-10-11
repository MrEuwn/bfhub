# BFHub

Blox Fruits script hub. No UI library (raw `Instance.new` GUI) -> smallest footprint on mobile executors like Delta.

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

`bfhub.lua` fetches the modules under `src/` at runtime, so you only paste one line and repo updates apply instantly.

## Tabs

- **Farm** - Auto Farm Nearest, Auto Farm Level (accepts the quest for your level and completes it automatically), Selected Mob (live list), Bring Mob (all same-type), NoClip, Tween, weapon category (Melee/Sword/Gun/Fruit), chest/berry/material.
- **Combat** - fast attack, kill aura, god mode, auto buso/ken, auto Buddha, race v4.
- **Fruit** - sniper, auto store, mastery, notifier.
- **ESP** - fruit / chest / island / player / enemy.
- **Teleport** - live island list (Sea 1/2/3) + nearest player.
- **Sea Events** - Auto Mirage (hop -> stop -> tp), full moon, kitsune, prehistoric.
- **Bones** - auto farm bone (Haunted Castle) + auto roll bone.
- **Boss** - Auto Tyrant of the Skies (farm Tiki mobs -> break pots -> kill), generic boss farm.
- **Mastery** - auto mastery farm + buy/learn fighting styles.
- **Debug** - live FPS, ping, time played, level, farm target, quest state, mobs nearby, job id.
- **Shop** - buy items via the buy remote.
- **Misc** - noclip, infinite jump, fly, walk on water, server hop, anti-afk, FPS boost, anti-night, low-end mode.

Floating **STOP TWEEN** button (right edge) disables smooth travel instantly.

## Farm system

1. **Auto to mob** - flies to the target mob (`root.CFrame = mob.HRP.Position + (0,12,0)`).
2. **Bring mob** - pulls EVERY mob of the same type onto you, so the whole cluster stays in M1 range.
3. **NoClip forced while moving** - tween/flight never clips a wall.
4. **Auto hit** - equips the chosen weapon category, activates it and clicks.
5. **Wait + repeat** - when the mobs are dead it waits for respawn and keeps hitting until the quest counter is satisfied (quests complete automatically server-side; there is no CompleteQuest remote).

## Layout

```
bfhub.lua          entry point (paste this)
src/util.lua       services, tp/tween, remotes, Enemies helpers, noclip, ping
src/ui.lua         minimal custom GUI + floating toggle button
src/config.lua     runtime state store
src/quests.lua     81-row quest table (Sea 1/2/3, level 1-2524)
src/farm.lua  combat.lua  fruit.lua  esp.lua  teleport.lua
src/sea.lua  bones.lua  boss.lua  mastery.lua  debug.lua  shop.lua  misc.lua
```

## Status / caveats

- All files pass `luau-compile`; an offline harness loads every module and checks the quest table. Not runtime-tested in-game.
- Remote args (`StartQuest`, `Buy`, Death King roll, Race V4) are best-effort and version-sensitive; each is marked with a `ponytail:` comment.
- Mob detection uses `workspace.Enemies`; island/fruit/event detection uses live game state, not hardcoded coords.
- Using this violates Roblox ToS. Test on an alt.
