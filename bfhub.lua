--[[
  Raf's Personal Script - HoHo launcher.

  Runs HoHo Hub for Blox Fruits, keyless.

  Why this is keyless: HoHo's own loader
  (acsu123/HOHO_H main/new_load.lua) has NO key system and NO ad gate. Audited -
  it contains no getkey / luarmor / linkvertise / lootlabs / work.ink reference.
  It matches game.GameId against a table and runs the script for that game. The
  key+ad flow people complain about lives in a DIFFERENT loader
  (acsu123/HohoV2 main/ScriptLoad.lua), which this does not use.

  Blox Fruits GameId is 994732206 -> HoHo runs main/HohoHub.lua
  (Luraph v13.5.8 protected; we run it, we do not modify it).

  Paste one line in Delta:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()

  In game: press RightCtrl to show/hide the HoHo UI. A "HoHo" button also appears
  on screen. This is a cheat - use an alt account.
]]

local HOHO_LOADER = "https://raw.githubusercontent.com/acsu123/HOHO_H/main/new_load.lua"
local HOHO_BLOX   = "https://raw.githubusercontent.com/acsu123/HOHO_H/main/HohoHub.lua"

-- new_load.lua checks game.GameId. On some executors that field is absent, so
-- fill it in from the place id (the authoritative mapping) before running.
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

local function run(url)
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(url, true))()
    end)
    return ok, res
end

local ok, err = run(HOHO_LOADER)

if not ok or not (game:GetService("CoreGui"):FindFirstChild("Hoho_Hub")) then
    warn("[RPS] loader path failed (" .. tostring(err) .. "), calling HoHo directly")
    local ok2, err2 = run(HOHO_BLOX)
    if not ok2 then
        warn("[RPS] HoHo failed: " .. tostring(err2))
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Raf's Personal Script",
            Text = "HoHo failed to load - see console",
            Duration = 6,
        })
    end
end
