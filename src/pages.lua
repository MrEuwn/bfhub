--[[ pages.lua - every tab. UI only: each row writes into the shared config store
     that farm.lua / extras.lua read each tick. ]]

local M = {}
local U, C, UI, win, D

local function cycle(key, list, label)
    local cur = C.get(key)
    for i, v in ipairs(list) do
        if v == cur then
            C.set(key, list[i % #list + 1])
            return U.notify(label .. ": " .. tostring(C.get(key)))
        end
    end
    C.set(key, list[1])
    U.notify(label .. ": " .. tostring(list[1]))
end

function M.init(_U, _C, _UI, _w, deps)
    U, C, UI, win = _U, _C, _UI, _w
    D = deps and deps.D

    -- FARM ------------------------------------------------------------------
    local p = win:tab("Farm")
    local c = win:card(p, "Auto Farm Level")
    win:toggle(c, "Auto Farm Level", "accept the quest, travel, bring, hit", "farm")
    win:toggle(c, "Auto Quest", "accept the quest automatically", "autoquest")
    win:dropdown(c, "Mode", "farmmode", { "level", "nearest", "boss", "mastery" })
    win:dropdown(c, "Weapon", "farmtool", { "Melee", "Sword", "Gun", "Blox Fruit" })
    win:slider(c, "Farm Distance", "farmdistance", 5, 60, 1)
    win:toggle(c, "Orbit Target", "circle the mob so hits keep landing", "orbit")
    win:toggle(c, "Bring Mobs", "pin mobs + enlarge hitbox", "bring")
    win:slider(c, "Bring Distance", "bringdist", 50, 500, 10)

    c = win:card(p, "Travel")
    win:toggle(c, "Tween Travel", "smooth flight instead of instant teleport", "tween")
    win:slider(c, "Tween Speed", "tweenspeed", 60, 400, 10)
    win:toggle(c, "Portal Hop", "hard teleport when far (faster, riskier)", "portalhop")
    win:toggle(c, "Fly / Hover", "hold position above the mob", "hover")
    win:toggle(c, "NoClip", nil, "noclip")
    win:button(c, "STOP TWEEN", "kill-switch for a stuck tween", function() U.stopTween() end)

    c = win:card(p, "Boss")
    win:dropdown(c, "Boss List", "bossselected", D and D.bossList[U.sea] or {})
    win:toggle(c, "Take Boss Quest", "accept the boss quest first", "bossquest")

    -- COMBAT ----------------------------------------------------------------
    p = win:tab("Combat")
    c = win:card(p, "Attack")
    win:toggle(c, "Fast Attack", "zero cooldowns, real credited M1", "fastattack")
    win:toggle(c, "Auto Click", nil, "autoclick")
    win:slider(c, "Attack Range", "attackdist", 20, 200, 5)
    win:slider(c, "Click Delay", "clickdelay", 0.05, 1, 0.01)
    win:button(c, "Attack Method", "tap to switch m1 <-> net remote", function()
        C.set("method", C.get("method") == "m1" and "net" or "m1")
        U.notify("attack method: " .. C.get("method"))
    end)

    c = win:card(p, "Kill Aura")
    win:toggle(c, "Kill Aura", "long-range M1, snaps onto the mob first", "killaura")
    win:slider(c, "Aura Range", "aura", 40, 300, 10)
    win:label(c, "Instakill is not offered: writing Health client-side gives no money/exp.", Color3.fromRGB(230, 150, 150))

    c = win:card(p, "Haki / Heal")
    win:toggle(c, "Auto Buso", nil, "autobuso")
    win:toggle(c, "Auto Ken", nil, "autoken")
    win:toggle(c, "Heal When Low", "under 30% HP", "heal")

    -- MASTERY / STATS -------------------------------------------------------
    p = win:tab("Stats")
    c = win:card(p, "Mastery")
    win:toggle(c, "Auto Farm Mastery", "grind the equipped tool", "automastery")
    win:dropdown(c, "Tool", "masterytool", { "Blox Fruit", "Melee", "Sword", "Gun" })
    win:slider(c, "Stop At", "masteryvalue", 100, 600, 50)
    c = win:card(p, "Stat Points")
    win:toggle(c, "Auto Stat Point", "spend points as they arrive", "autostat")
    win:dropdown(c, "Stat", "stat", { "Melee", "Sword", "Gun", "Defense", "Blox Fruit" })
    win:slider(c, "Points", "statpoints", 1, 100, 1)
    win:button(c, "Check Boost", "read your current boosts", function()
        local r = U.F("CheckBoost")
        U.log("i", "boost: " .. tostring(r))
        U.notify("boost -> Log tab")
    end)

    -- RACE / MISC -----------------------------------------------------------
    c = win:card(p, "Race")
    win:toggle(c, "Auto Race V2", "run the Alchemist race quest", "autoracev2")
    win:button(c, "Race Reroll", "BlackbeardReward reroll 1", function() U.F("BlackbeardReward", "Reroll", "1") end)
    win:button(c, "Race Reroll (2)", "second reroll slot", function() U.F("BlackbeardReward", "Reroll", "2") end)
    win:button(c, "Stat Refund", "BlackbeardReward refund", function() U.F("BlackbeardReward", "Refund", "1") end)

    -- TELEPORT --------------------------------------------------------------
    p = win:tab("Teleport")
    c = win:card(p, "Islands")
    -- read the live registry at build time; it is dynamic per sea, so never hardcode
    local islands = {}
    do
        local w = workspace:FindFirstChild("_WorldOrigin")
        local loc = w and w:FindFirstChild("Locations")
        if loc then
            for _, i in ipairs(loc:GetChildren()) do table.insert(islands, i.Name) end
            table.sort(islands)
        end
    end
    if #islands == 0 then islands = { "no Locations registry" } end
    win:dropdown(c, "Island", "island", islands)
    win:button(c, "Teleport", "jump to the island above", function() M.teleportIsland() end)
    c = win:card(p, "Sea")
    win:button(c, "Teleport to Sea 1", nil, function() U.F("TravelMain") end)
    win:button(c, "Teleport to Sea 2", nil, function() U.F("TravelDressrosa") end)
    win:button(c, "Teleport to Sea 3", nil, function() U.F("TravelZou") end)
    c = win:card(p, "Server")
    win:textbox(c, "Server ID", "serverid", "jobId")
    win:button(c, "Join Server", "teleport to the jobId above", function()
        local id = C.get("serverid")
        if id and #id > 10 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, id, U.LP)
        else
            U.notify("paste a jobId first")
        end
    end)
    win:button(c, "Server Hop", "jump to a less full server", function() M.serverHop() end)

    -- SHOP ------------------------------------------------------------------
    p = win:tab("Shop")
    c = win:card(p, "Codes")
    win:button(c, "Redeem All Codes", "sends the current public code list", function() M.redeemCodes() end)

    c = win:card(p, "Fighting Styles")
    for _, s in ipairs({ "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
                         "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon",
                         "Godhuman", "Sanguine Art" }) do
        win:button(c, "Buy " .. s, nil, function()
            U.F(s, true) U.F(s) U.notify("buying " .. s)
        end)
    end
    c = win:card(p, "Swords")
    for _, s in ipairs({ "Katana", "Cutlass", "Dual Katana", "Iron Mace", "Triple Katana",
                         "Pipe", "Dual-Headed Blade", "Soul Cane", "Bisento" }) do
        win:button(c, "Buy " .. s, nil, function()
            U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
        end)
    end
    c = win:card(p, "Guns")
    for _, s in ipairs({ "Musket", "Slingshot", "Flintlock", "Refined Slingshot",
                         "Refined Flintlock", "Cannon", "Kabucha" }) do
        win:button(c, "Buy " .. s, nil, function()
            U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
        end)
    end

    -- VISUAL ----------------------------------------------------------------
    p = win:tab("Visual")
    c = win:card(p, "ESP")
    win:toggle(c, "ESP Mobs", "name tags on enemies", "esp")
    win:toggle(c, "ESP Players", nil, "espplayers")
    c = win:card(p, "Performance")
    win:toggle(c, "Low-End Mode", "kills particles + shadows (mobile fps)", "lowend")
    win:toggle(c, "Anti-AFK", nil, "antiafk")
    win:toggle(c, "Walk On Water", "platform under your feet", "walkonwater")
    win:toggle(c, "Heal When Low", "under 30% HP", "heal")

    -- MISC ------------------------------------------------------------------
    p = win:tab("Misc")
    c = win:card(p, "Log Webhook")
    win:label(c, "paste a Discord webhook URL here, then Log tab > Send")
    win:textbox(c, "Webhook", "webhook", "https://discord.com/api/webhooks/...")
    c = win:card(p, "Credits")
    win:label(c, "use an alt account. this is a cheat.")
    return M
end

return M
