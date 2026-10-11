# Raf's Personal Script - HoHo Hub launcher

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()
```

Paste in Delta with Blox Fruits open. RightCtrl (or the on-screen button) toggles
the UI.

## Read this before asking for "newest, no key"

The **newest** HoHo Blox Fruits build is **locked by Luarmor**, a server-side key
service. Its loader is `HohoV2/main/ScriptLoad.lua`:

```lua
GameList[994732206] = "e4aedc7ccd2bacd83555baa884f3d4b1"   -- Blox Fruits
api = HttpGet("https://sdkapi-public.luarmor.net/library.lua")
api.script_id = <that id>
local status = api.check_key(key)          -- must be KEY_VALID
if status.code == "KEY_VALID" then api.load_script(...) end
```

The payload is **not in the GitHub repo**, and it cannot be fetched without a
valid key - requesting the loader URL returns an HTML page, and `?key=NoKey`
returns `Unauthorized`. The check runs on Luarmor's server, so it **cannot be
patched from the client**. The key is not in the code to remove.

Anyone who tells you otherwise is selling you a key-logger or a re-upload.

## What this launcher does instead

It runs HoHo's **own free/keyless builds**, newest first:

| Build | Size | Obfuscator | Last commit |
|---|---|---|---|
| `Free/BloxFruitFreeV3.lua` | 2.17 MB | Luraph v14.2 | **2024-11-28** |
| `Free/BloxFruitTEST_ONLY.lua` | 2.41 MB | Luraph v13.8.1 | 2024-01-20 |
| `main/HohoHub.lua` | 2.63 MB | Luraph v13.5.8 | 2022-10-18 |

Verified keyless: no `luarmor`, `script_key`, `check_key` or `load_script`
anywhere in them. They are obfuscated, so they are run as-is - not modified, not
redistributed (fetched live from the author's repo).

**Trade-off:** the newest keyless build is from Nov 2024 and the game is now
v30.0.8, so expect some features to be broken. That is the cost of skipping the
key.

## Credits

HoHo Hub by **acsu123** - https://github.com/acsu123/HohoV2 and
https://github.com/acsu123/HOHO_H

## Warning

Cheating violates Roblox's terms of service and carries a real ban risk. Use an
alt account.
