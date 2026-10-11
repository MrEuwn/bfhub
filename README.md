# speedhubx-nokey.luau

Source: `BloxFruit.devirt.luau` (191,237 bytes) - the KryptIT deobfuscator's output for
`samples/Blox Fruit.lua` (Luraph v15.0, 646,490 bytes, a real Blox Fruits hub published as
"Speed Hub X | Version 5.5.0 | discord.gg/speedhubx").

## Why it is 6,471 lines instead of 6,767

The file is one chunk:

| lines | what |
|---|---|
| 1-95 | anti-tamper preamble + `local function fn2()` opening |
| 96-6471 | **the entire hub body**, inside `fn2` |
| 6472-6768 | the Luarmor key system: `CheckerKey` against `sdkapi-public.luarmor.net`, `isfile("SpeedHubX_Key.txt")`, `script_key`, and the `KeySystemV2.5.lua` UI |

Only the last block is the key system, so only the last block was dropped.

**The payload was never server-gated.** `fn2` is the hub itself; it is fully lifted and
already in the file. The key system did not protect it - it only decided whether `fn2`
was called. That is why deleting the gate leaves a complete, runnable hub.

## What was changed

1. Deleted the whole key-system tail - **and re-added the one line that mattered**. In the
   original, the tail was the *only* place `fn2` was called:

   ```lua
   if tbl2:KqNajm...fnSWF() or tbl2 then   -- `or tbl2` is always truthy
       task.spawn(fn2)                      -- this is what started the hub
       return
   end
   ```

   So deleting the tail wholesale produced a file that loaded and then did nothing. The last
   line of this build is now `task.spawn(fn2)`. The dropped block also contained a folder-wipe
   over the author's config folders.
3. Removed `loadstring(game:HttpGet(".../Webhook/Tracker%20Bosses.lua"))()` — it sits at the
   **end of the hub body**, not in the key tail, so it survived the first cut and fired on every
   load. It is a remote payload from the original author's GitHub and its contents are not in
   this file, so what it does cannot be audited here. Gone now.
4. Rebranded: window title, all 11 notification titles, and the config folder
   (`SpeedHubX/BloxFruit_V5.json` -> `RafPersonalScript/BloxFruit_V5.json`). The old
   "Copy Invite Link" button was copying `nil` (the `Discord` variable is never assigned in the
   original); it is now "Copy Script URL". There is no logo image in the UI to remove —
   `CreateWindow` carries a title and no image field.
2. Repaired three deobfuscator lift artifacts, which were the only genuinely broken
   spots. The lifter dropped the `pairs`/`ipairs` iterator, leaving a generic-for with a
   table in the iterator slot - valid Lua, broken at runtime:

   ```lua
   for _, v21 in v20, nil, nil do          -->  for _, v21 in pairs(v20) do
   for k, v19 in tbl24, nil, nil do        -->  for k, v19 in pairs(tbl24) do
   for _, v49 in response2, nil, nil do    -->  for _, v49 in pairs(response2) do
   for _, v54 in loadstring(...)(), nil, nil do
                                           -->  for _, v54 in pairs(loadstring(...)()) do
   ```

   Sites that were already correct (`for _, v in next, tbl, nil do`) were left alone.

## Load

```lua
loadstring(game:HttpGet("<raw url of this file>"))()
```

It is not hosted anywhere by default - host it yourself or paste the file's contents.

## What still talks to the network

Left as-is, it is the author's code:

- `Lib_5.5.0.lua`, `FuncsV3` - the UI library and its wrapper, fetched from the author's
  GitHub at load. Both are required; the UI is built through `FuncsV3`.
- `Codes_BloxFruit` - the redeem-code list.
- `https://prvf.onrender.com/data` - the boss data table (boss name -> id), used by the
  boss dropdown and by server hopping to a specific boss.
- `Tracker%20Bosses.lua` - only in the deleted block, so no longer fetched.

## Honest status

- **Compiles clean** under `luau-compile` after the fix.
- **Not run in-game.** The lift is a reconstruction, so behaviour can still differ from
  the original obfuscated build in ways a compiler cannot see. The three `pairs` fixes are
  the only defects found by static inspection; there may be more that only show at runtime.
- The 121 feature rows it builds (8 tabs, 41 sections: 100 toggles, 28 dropdowns,
  21 buttons) come from the author's own UI definition and were not rewritten.
