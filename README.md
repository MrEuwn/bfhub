# Raf's Personal Script

Blox Fruits hub, keyless, open source, no obfuscation. Feature set ported from the
public **Redz Hub V2** plain-Lua source: values and behaviours only, none of its code.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

Paste in Delta with Blox Fruits open. RightCtrl (or the floating button) toggles the UI.

## Layout

```
bfhub.lua           entry: fetch + load modules, one scheduler
src/util.lua        services, remotes, travel, combat, tool/quest helpers, logs
src/config.lua      143 keys, generated from the source's own UI spec
src/data.lua        109 quest rows, 36 bosses, 15 boss-farm rows, 10 spawners,
                    8 quest chains, 6 fighters, 15 material spots, 47 codes, 39 fruits
src/ui.lua          raw Instance.new GUI, no library
src/farm.lua        farm loops: level / nearest / boss / mastery
src/quests.lua      named quests + unlocks, spawner remotes, chains, material farm
src/extras.lua      kill aura, skills, ESP, low-end, anti-AFK, walk-on-water
src/pages.lua       9 tabs, 150 rows
src/home.lua        Home status + debug panel + Log + Credits
harness.lua         offline contract test (run with luau.exe)
```

## Tabs

| Tab | What is in it |
|---|---|
| Home | status, live debug panel (FPS/ping/uptime/mobs/sea), module load report, Dump Environment |
| Farm | auto farm level, mode (level/nearest/boss/mastery), weapon, farm distance, orbit, bring mobs + distance, tween travel + speed, fly/hover, noclip, STOP TWEEN, boss list, all-boss sweep, take boss quest |
| Combat | fast attack, auto click, hitbox range, click delay, attack method m1/net, kill aura + range, skills Z/X/C/V/F + aimbot + health cutoff, auto buso/ken, heal |
| Stats | auto mastery + tool + stop-at, auto stats, check boost, race V2, race reroll, stat refund |
| Features | 8 boss farmers, 7 mob/material farmers + material dropdown, 7 quest chains, 6 fighting styles, fruit/chest, server/hop, 9 misc switches |
| Teleport | island dropdown read live from `Locations`, teleport, sea 1/2/3, server id + join |
| Shop | 47 codes, 11 fighting styles, 9 swords, 7 guns, race trainers, fruit shop |
| Visual | ESP fruits/chests/flowers/islands/players, low-end mode, anti-AFK, walk on water, panic mode |
| Log | live ring buffer, copy to clipboard, clear, send to Discord webhook |

## Named quests and unlocks (ported step by step)

Ken V2 (Citizen quest), Musketeer Hat, Saber (Rich Son + Relic), Rainbow Haki
(5 bosses + Horned Man bet), Soul Guitar (buy + ghost puzzle), Race V2 (Alchemist),
Second Sea (Detective Key -> Ice Admiral -> sail), Third Sea (rip_indra -> sail),
Elite Hunter (Diablo / Deandre / Urban, hops until one is up).

Boss farmers: The Saw, Thunder God, Cursed Captain, Don Swan, Darkbeard, rip_indra
True Form, Soul Reaper, Order. The three that need a summoning tool (Darkbeard =
Fist of Darkness, rip_indra = God's Chalice, Soul Reaper = Hallow Essence) equip it
and stand on the spawn point first. Cake Prince / Dough King / Elite Hunter spam
their spawner remote on a timer.

## Verified

- `luau-compile` clean on all 10 files.
- `harness.lua` passes: every module returns a table or factory, every `init()` runs,
  three `tick()` calls per feature module run without error, 150 UI rows build, and
  the data validates — 109 quest rows (ordered ranges, non-nil quest giver CFrame),
  36 bosses with spawn CFrames, 15 boss-farm rows with fallback CFrames, 10 spawners,
  8 chains whose every step does something, 6 fighters, materials present for all three
  seas, 47 codes, 39 fruits. Every `C.get()` key in the feature modules exists in config.
- **Not tested in-game.** Paths and remotes are version-sensitive. The Log tab prints
  every failure with a traceback, and Home has Dump Environment.

## Not ported (deliberately)

- **Instakill** (`Humanoid.Health = 0`): client-side, so no money and no exp.
- **Cursed Dual Katana**: the source's 264-line chain needs Tushita and Yama mastered
  first; the toggle exists and reports its requirement instead of half-running.
- **Auto Farm Sea / Auto Kitsune Island / Auto Mirage**: these need boat piloting
  (`BoatTP`) and the source's own A* pathfinding module. The switches are present but
  the loop only handles the island teleport; ask and the boat leg can be added.
- **Auto Trade / Auto Random Fruit**: economy actions against other players; left out.

## Warning

Cheating violates Roblox's terms of service and carries a real ban risk. Use an alt account.
