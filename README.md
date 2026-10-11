# Raf's Personal Script

Runs **HoHo Hub** for Blox Fruits, **keyless**.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

Paste that in Delta while Blox Fruits is open. Press **RightCtrl** to show/hide
the UI; a **HoHo** button also appears on screen.

## Why there is no key

HoHo's own loader, `acsu123/HOHO_H` -> `main/new_load.lua`, has **no key system
and no ad gate**. It matches `game.GameId` against a table and runs that game's
script. Audited: no `getkey`, `luarmor`, `linkvertise`, `lootlabs` or `work.ink`
reference anywhere in it.

The key-and-ads flow people complain about comes from a **different** loader,
`acsu123/HohoV2` -> `main/ScriptLoad.lua`. This repo does not use that one.

Blox Fruits GameId is `994732206` (verified: place 2753915549 -> universe
994732206 -> "Blox Fruits" by Gamer Robot Inc), which maps to
`main/HohoHub.lua`.

## What this repo contains

Just the launcher. HoHo itself is fetched live from the author's repo, so it
stays current and we never redistribute it. If `new_load.lua` is ever gated or
breaks, the launcher falls back to calling the Blox Fruits payload directly.

## Credits

HoHo Hub by **acsu123** - https://github.com/acsu123/HOHO_H

This is a launcher, not a copy: HoHo is fetched from its author's repository at
run time and no part of it is redistributed here.

## Warning

This is a cheat. It violates Roblox's terms of service and carries a real ban
risk. Use an alt account.
