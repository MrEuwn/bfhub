# Raf's Personal Script - BFHub

Own Blox Fruits hub, keyless, open source, no obfuscation. Built to match HoHo's
structure (Home / Farm / Combat / Player / Misc / Log / Credits, live debug panel,
feature search box, low-end mode) without any of its code.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

Paste in Delta with Blox Fruits open. RightCtrl (or the floating button) toggles
the UI.

## Layout

```
bfhub.lua           entry: fetch + load modules, one scheduler
src/util.lua        services, remotes, mob finders, attack, bring, hover, logs
src/config.lua      flat toggle store shared by UI rows and features
src/quests.lua      level -> {mob, quest name, quest #, quest giver CFrame}
src/ui.lua          raw Instance.new GUI (no library)
src/farm.lua        auto farm level (quest -> travel -> bring -> hit)
src/extras.lua      kill aura, ESP, auto stat, anti-AFK, low-end mode
src/pages.lua       Farm / Combat / Player / Misc tabs
src/home.lua        Home status + debug + Log + Credits
harness.lua         offline contract test (run with luau.exe)
```

## Verified

- `luau-compile` clean on all 9 files.
- `harness.lua` passes: every module returns a table or a factory, every `init()`
  runs, one `tick()` runs, the quest table is contiguous (Sea 1: 1-650,
  Sea 2: 700-1450, Sea 3: 1500-2525).
- **Not tested in-game.** Paths and remotes are version-sensitive; the Log tab
  prints every failure with a traceback instead of failing silently.

## How it works

Farm loop order: travel to the quest giver ->
`CommF_:InvokeServer("StartQuest", name, n)` -> travel to the mob -> bring all
mobs of that type (pin to a fixed anchor, blow up the hitbox) -> orbit the target
-> real M1. Attack uses the combat framework (zero cooldowns + widen
`hitboxMagnitude`, then a real click), so the server credits the kill for
money/exp. A `net` method via `Net:RE/RegisterHit` is one button away if the
framework path breaks.

Instakill (`Humanoid.Health = 0`) is deliberately not offered: it is client-side,
so no money and no exp.

## Warning

Cheating violates Roblox's terms of service and carries a real ban risk. Use an
alt account.
