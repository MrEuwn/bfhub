--[[
  Raf's Personal Script - HoHo Hub launcher (keyless build).

  WHY NOT THE NEWEST BUILD:
  HoHo's newest Blox Fruits build lives behind Luarmor (a server-side key
  service). Its loader is:
      HohoV2 main/ScriptLoad.lua
        GameList[994732206] = "e4aedc7ccd2bacd83555baa884f3d4b1"  -- Blox Fruits
        api = HttpGet("https://sdkapi-public.luarmor.net/library.lua")
        api.script_id = <that id>
        api.check_key(key)   -- must return KEY_VALID
        api.load_script(...) -- THEN the payload is handed over
  The payload is never in the GitHub repo and is not fetchable without a valid
  key: requesting the loader URL directly returns an HTML page, and adding
  ?key=NoKey returns "Unauthorized". That check is server-side, so it cannot be
  patched from the client. Nobody can remove that key - it is not in the code.

  WHAT THIS RUNS:
  HoHo's own free/keyless Blox Fruits builds, newest first. These carry no key
  gate at all (verified: no luarmor / script_key / check_key anywhere):
      1. Free/BloxFruitFreeV3.lua    2.17 MB  Luraph v14.2    2024-11-28  <- newest
      2. Free/BloxFruitTEST_ONLY.lua 2.41 MB  Luraph v13.8.1  2024-01-20
      3. main/HohoHub.lua            2.63 MB  Luraph v13.5.8  2022-10-18
  They are obfuscated, so we run them as-is; we do not modify them.

  Trade-off, stated plainly: the newest keyless build is from Nov 2024 and the
  game is now v30.0.8, so some features may be broken. That is the cost of
  skipping the key.

  Paste one line in Delta (while Blox Fruits is open):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()

  Press RightCtrl (or the on-screen button) to show/hide the UI.
  This is a cheat - use an alt account.
]]

local BUILDS = {
    "https://raw.githubusercontent.com/acsu123/HohoV2/Free/BloxFruitFreeV3.lua",     -- newest keyless
    "https://raw.githubusercontent.com/acsu123/HohoV2/Free/BloxFruitTEST_ONLY.lua",
    "https://raw.githubusercontent.com/acsu123/HOHO_H/main/HohoHub.lua",
}

-- new_load.lua and some builds check game.GameId. Fill it in from PlaceId when
-- the executor leaves it empty (Blox Fruits = 994732206 for all three seas).
pcall(function()
    if game.GameId == nil or game.GameId == 0 then
        local universe = ({
            [2753915549] = 994732206,   -- Sea 1
            [4442272183] = 994732206,   -- Sea 2
            [7449423635] = 994732206,   -- Sea 3
        })[game.PlaceId]
        if universe then game.GameId = universe end
    end
end)

local CoreGui = game:GetService("CoreGui")

local function loaded()
    for _, n in ipairs({ "Hoho_Hub", "HohoHub", "Hоhо_раssсhесk" }) do
        if CoreGui:FindFirstChild(n) then return true end
    end
    return false
end

local lastErr
for _, url in ipairs(BUILDS) do
    local ok, err = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    if ok and loaded() then
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Raf's Personal Script",
            Text = "HoHo loaded: " .. url:match("([^/]+)%.lua$"),
            Duration = 5,
        })
        return
    end
    lastErr = err
    warn("[RPS] " .. url:match("([^/]+)%.lua$") .. " failed: " .. tostring(err))
    task.wait(1)
end

warn("[RPS] all HoHo builds failed: " .. tostring(lastErr))
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Raf's Personal Script",
    Text = "HoHo failed - see console",
    Duration = 6,
})
