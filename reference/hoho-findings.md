# HoHo Hub obfuscation findings

Investigated https://github.com/acsu123/HohoV2 and https://github.com/acsu123/HOHO_H.

## What is obfuscated (Luraph) — CANNOT be deobfuscated
- HohoV2@Free/BloxFruitFreeV3.lua      2.1 MB  Luraph v14.2   <- free Blox Fruits payload
- HohoV2@Free/BloxFruitFree.lua        4.6 MB  Luraph
- HohoV2@Free/BloxFruitFreeV33.lua     9.3 MB  Luraph
- HohoV2@main/BloxFruit/huhuhud.lua    7.1 MB  Luraph v13.8.1 <- main hub
- HohoV2@main/BloxFruit/bypassAC_2.lua 185 KB  Luraph v13.6.7 <- anti-cheat bypass
- HOHO_H@main/HohoHub.lua                      Luraph v13.5.8
- HOHO_H@Paid/bloxfruitU17P*.lua               Luraph

## What is READABLE (plain Lua) — use these
- HohoV2@main/ScriptLoad.lua           63 KB  key/loader UI + GameList
- HohoV2@main/BloxFruit/train-ai/HoHoGuiBuild.json  140 KB  <-- FULL GUI/feature tree
- HohoV2@main/BloxFruit/train-ai/HoHo Knowledge.txt 18 KB   internal docs
- HohoV2@main/BloxFruit/AStar.lua      pathfinding
- HohoV2@main/BloxFruit/FreeCam.lua    free camera
- HohoV2@main/BloxFruit/TopbarUI.lua   topbar UI
- HohoV2@main/BloxFruit/Sirius.lua     UI lib
- HohoV2@main/BloxFruit/SliderModule.lua, DragModule.lua, ObjectPool.lua, Heap.lua
- HohoV2@main/BloxFruit/RainModule.lua, animatekeyframeSequance.lua, gui2lua.lua
- HohoV2@main/BloxFruit/somevalues.lua (fixed Vector3/CFrame constants)
- HohoV2@main/BloxFruit/preload/*.hoho  encrypted per-place payloads (place ids as names)

## Conclusion
Deobfuscating Luraph is not practical. The GUI build JSON gives HoHo's complete feature
list + config layout for free; the readable modules give its UI/pathfinding/camera code.
Feature names + structure are recoverable; the obfuscated algorithm bodies are not.
