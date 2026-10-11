# Raf's Personal Script

Blox Fruits hub, keyless, open source, no obfuscation. Every feature comes from the
public **Redz Hub V2** plain-Lua source — its values and behaviours, none of its code.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

Paste in Delta with Blox Fruits open. RightCtrl (or the floating button) toggles the UI.

## UI

Raw `Instance.new`, no library, minimalist: one accent colour, no gradients, no icons,
compact 18px rows, 430x300 window.

Load is instant because **tabs are built lazily** — only Home is constructed at load
(~10 rows); the other ten pages are built the first time you open them. Nothing is
built twice.

```
bfhub.lua           entry: fetch + load modules, one scheduler
src/util.lua        services, remotes, travel, combat, tool/quest helpers, logs
src/config.lua      134 keys, generated from the source's own UI spec
src/data.lua        109 quest rows, 36 bosses, 15 boss-farm rows, 10 spawners,
                    8 quest chains, 6 fighters, 15 material spots, 47 codes, 39 fruits
src/ui.lua          lazy minimalist GUI
src/farm.lua        Auto Farm Level / Nearest / Boss / Mastery
src/quests.lua      the named farmers, unlocks, spawner remotes, material farm
src/moon.lua        moon phase + Mirage detection, auto hop, shared jobIds
src/moon.lua        moon phase + Mirage detection, auto hop, shared jobIds
src/extras.lua      kill aura, skills, ESP, low-end, anti-AFK, walk-on-water
src/pages.lua       11 tabs
src/home.lua        Home status + debug panel
harness.lua         offline contract test (run with luau.exe)
```

## Tabs

| Tab | Contents |
|---|---|
| Home | status, live debug (FPS/ping/mobs/level/sea/uptime), module report, Dump Environment |
| Farm | Auto Farm Level, mode, weapon, farm distance, bring mobs + distance, auto farm nearest, tween travel + speed, noclip, STOP TWEEN, boss list, all-boss sweep, take boss quest |
| Combat | fast attack, auto click, attack distance, click delay, attack method m1/net, kill aura, skills Z/X/C/V/F + aimbot + health cutoff, auto haki, heal |
| Farming | 8 boss farmers, 7 mob/material farmers + material dropdown, auto mastery, 6 fighting styles |
| Quests | Ken V2, Musketeer Hat, Saber, Rainbow Haki, Soul Guitar, Race V2, Second Sea, Third Sea, Elite Hunter + hops, race reroll / refund |
| Items | teleport to fruit, store fruits, chest tween/bypass, raid, chip, haki color, legendary sword, TTK, Bartilo, CDK |
| Teleport | island dropdown from the live `Locations` registry, sea 1/2/3, server id + join |
| Server | moon phase + Mirage readout, hop until Mirage, hop until full moon, hop limits, join by jobId, shared jobId url list, post my jobId |
| Server | moon phase + Mirage readout, hop until Mirage, hop until full moon, hop limits, join by jobId, shared jobId url list, post my jobId |
| Shop | 47 codes, 11 fighting styles, 9 swords, 7 guns, ghoul/cyborg race, random fruit |
| Visual | ESP fruits/chests/flowers/islands/players, low-end, anti-AFK, walk on water, panic mode |
| Misc | auto stats, check boost, webhook, about |
| Log | live buffer, copy, clear, send to webhook |

## Verified

- `luau-compile` clean on all 10 files.
- `harness.lua` passes: every module returns a table or factory, every `init()` runs,
  three `tick()` calls per feature module run without error, all 11 tabs build, and the
  lazy contract is asserted (1 tab built at load, 11 after selecting them all).
- Data validates: 109 quest rows with ordered ranges and non-nil quest giver CFrames,
  36 bosses with spawn CFrames, 15 boss-farm rows each with a fallback CFrame, 10
  spawners, 8 chains whose every step does something, 6 fighters, materials present for
  all three seas, 47 codes, 39 fruits. Every `C.get()` key in the feature modules exists
  in config (checked mechanically).
- **Not tested in-game.** Paths and remotes are version-sensitive. Log tab prints every
  failure with a traceback; Home has Dump Environment.

## Moon / Mirage server hunting (what is actually possible)

Read this before expecting it to work like the hubs' "moon-servers" feature.

**Detecting a full moon or a live Mirage in someone else's server from outside is
impossible.** `https://games.roblox.com/v1/games/<placeId>/servers/Public` returns only
`id`, `maxPlayers`, `playing`, `playerIds`, `fps`, `ping`, `name`, `vipServerId`,
`accessCode`. No game state, and no endpoint carries any. The hubs that appear to do this
are reading a **Discord channel where humans post jobIds** (HoHo's `RODISCORD HOP FARM`,
channels `moon-servers` / `mirage-servers`) - a human looks, the script only teleports to
the id that was pasted. That is the mechanism this hub uses too, without needing a bot:
you read the channel yourself and paste the jobId.

What this hub does:

1. **Local detection** in the server you are in, the way in-game moon checkers do it:
   compare `Lighting.Sky.MoonTextureId` against the phase asset ids. `9709149431` =
   Full Moon, `9709149052` = Next Night (waning gibbous, becomes full on the next night)
   - that pair is what "3/4 moon" means here. `Lighting:GetMoonPhase()` is deprecated and
   returns a constant, so it is not used. Mirage is read from `workspace.Map.MysticIsland`
   / `MirageIsland`, then from the `_WorldOrigin.Locations` registry.
2. **Blind hop + re-read**: hop to a public server, read again, repeat up to a limit you
   set. Empty servers are preferred (a fresh server has a fresh moon clock), then the
   least full one. The counter shows how many hops it cost, so the real hit rate is
   visible rather than promised.
3. **Join by jobId**: paste a jobId someone posted and the hub teleports straight to it.
   No token, no bot, nothing to configure beyond the paste.
4. **Shared jobId list**: a URL of raw text containing jobIds (a GitHub raw file or gist
   you keep). `Join Next Unused From URL` takes the next one it has not used yet and
   cycles, so repeated presses walk the list instead of hammering the same server.
   `Post My jobId To Webhook` sends your own `jobId=` line to your Discord webhook when a
   moon or Mirage is up, so a second instance (or a friend) can pick it up - that is how a
   private channel of finds gets built without a bot.

Public servers only, as asked: `servers/Public` never returns private servers, and
nothing here touches the private-server endpoint.

## Deliberately not included

- **Instakill** (`Humanoid.Health = 0`): client-side, pays no money and no exp.
- **Cursed Dual Katana**: the source's 264-line chain needs Tushita and Yama mastered
  first; the toggle reports the requirement instead of half-running.
- **Auto Farm Sea / Auto Kitsune Island / Auto Mirage**: these need the source's boat
  piloting plus its A* pathfinding module. Not shipped rather than shipped broken.
- **Auto Trade / Auto Random Fruit**: economy actions against other players.

## Warning

Cheating violates Roblox's terms of service and carries a real ban risk. Use an alt account.
