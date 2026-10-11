# Raf's Personal Script

Blox Fruits hub, keyless, open source, no obfuscation. Feature set ported from the
public **Redz Hub V2** source (the plain-Lua copy, not the obfuscated redistribution).

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

Paste in Delta with Blox Fruits open. RightCtrl (or the floating button) toggles the UI.

## Layout

```
bfhub.lua           entry: fetch + load modules, one scheduler
src/util.lua        services, remotes, travel, combat, mob finders, logs
src/config.lua      flat toggle store shared by UI rows and features
src/data.lua        109 quest rows, 36 bosses, 47 codes, 39 fruits (ported values)
src/ui.lua          raw Instance.new GUI, no library
src/farm.lua        farm loops: level / nearest / boss / mastery
src/extras.lua      kill aura, ESP, low-end, anti-AFK, walk-on-water, server hop, codes
src/pages.lua       Farm / Combat / Stats / Teleport / Shop / Visual / Misc
src/home.lua        Home status + debug panel + Log + Credits
harness.lua         offline contract test (run with luau.exe)
```

## Feature map (source: 10 tabs, 61 sections, 222 UI elements)

| Tab | What is in it |
|---|---|
| Home | status, live debug panel (FPS/ping/uptime/mobs), module load report, Dump Environment |
| Farm | auto farm level (quest -> travel -> bring -> orbit -> hit), mode select, weapon select, farm distance, orbit, bring mobs + distance, tween travel + speed, portal hop, fly/hover, noclip, STOP TWEEN, boss list + take boss quest |
| Combat | fast attack (real credited M1), auto click, attack range, click delay, attack method m1/net, kill aura + range, auto buso/ken, heal when low |
| Stats | auto farm mastery + tool + stop-at, auto stat point + stat + points, check boost, race V2, race reroll, stat refund |
| Teleport | island dropdown read live from `Locations`, teleport, sea 1/2/3, server id + join, server hop |
| Shop | redeem all codes (47), 11 fighting styles, 9 swords, 7 guns |
| Visual | ESP mobs, ESP players, low-end mode, anti-AFK, walk on water |
| Misc | Discord webhook for the Log tab |
| Log | live ring buffer, copy to clipboard, clear, send to webhook |

## Verified

- `luau-compile` clean on all 9 files.
- `harness.lua` passes: every module returns a table or factory, every `init()` runs,
  three `tick()` calls per feature module run without error, 88 UI rows build, and the
  data tables validate (109 quest rows with ordered ranges and a quest giver CFrame,
  36 bosses each with a spawn CFrame, 47 codes, 39 fruits; every boss-list entry
  resolves to boss data).
- **Not tested in-game.** Game paths and remote names are version-sensitive. The Log
  tab prints every failure with a traceback instead of failing silently, and Home has
  a Dump Environment button that reports what the executor supports.

## How it works

Travel tweens an invisible anchored part that the camera watches (a raw `CFrame` set
does not move the camera). The farm loop order is: travel to the quest giver ->
`CommF_:InvokeServer("StartQuest", name, n)` -> travel to the mob -> bring all mobs of
that type (pin to a fixed anchor, enlarge the hitbox) -> orbit -> real M1.

Attacks go through the combat framework: cooldowns zeroed, `hitboxMagnitude` widened,
then a genuine left click, so the server credits the kill for money/exp. A `net` method
via `Net:RE/RegisterHit` is one tap away if the framework path breaks.

Instakill (`Humanoid.Health = 0`) is deliberately not offered: it is client-side, so no
money and no exp.

## Warning

Cheating violates Roblox's terms of service and carries a real ban risk. Use an alt account.
