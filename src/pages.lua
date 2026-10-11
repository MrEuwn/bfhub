--[[ pages.lua - every tab. UI only: each row writes into the shared config store
     that farm.lua / quests.lua / extras.lua read each tick.

     Feature switches live in the Features tab; the source hub had them spread over
     its own tabs, but one flat list is easier to search on a phone. ]]

local M = {}
local U, C, UI, win, D

function M.init(_U, _C, _UI, _w, deps)
    U, C, UI, win = _U, _C, _UI, _w
    D = deps and deps.D

    -- FARM ------------------------------------------------------------------
    local p = win:tab("Farm")
    local c = win:card(p, "Auto Farm")
    win:toggle(c, "Auto Farm Level", "accept the quest, travel, bring, hit", "AutoFarm_Level")
    win:dropdown(c, "Mode", "farmmode", { "level", "nearest", "boss", "mastery" })
    win:dropdown(c, "Weapon", "FarmTool", { "Melee", "Sword", "Gun", "Blox Fruit" })
    win:slider(c, "Farm Distance", "FarmPos", 5, 60, 1)
    win:toggle(c, "Orbit Target", "circle the mob so hits keep landing", "orbit")
    win:toggle(c, "Bring Mobs", "pin mobs + enlarge hitbox", "BringMobs")
    win:slider(c, "Bring Distance", "BringMobsDistance", 50, 500, 10)
    win:toggle(c, "Auto Farm Nearest", "no quest, closest mob", "AutoFarmNearest")

    c = win:card(p, "Travel")
    win:toggle(c, "Tween Travel", "smooth flight instead of instant teleport", "tween")
    win:slider(c, "Tween Speed", "TweenSpeed", 60, 400, 10)
    win:toggle(c, "Fly / Hover", "hold position above the mob", "hover")
    win:toggle(c, "NoClip", nil, "noclip")
    win:button(c, "STOP TWEEN", "kill-switch for a stuck tween", function() U.stopTween() end)

    c = win:card(p, "Boss")
    win:dropdown(c, "Boss List", "BossSelected", D and D.bossList[U.sea] or {})
    win:toggle(c, "Auto Farm Boss Selected", nil, "boss_BossSelected")
    win:toggle(c, "Auto Farm All Boss", "sweeps the boss list", "KillAllBosses")
    win:toggle(c, "Take Boss Quest", "accept the boss quest first", "TakeQuestBoss")

    -- COMBAT ----------------------------------------------------------------
    p = win:tab("Combat")
    c = win:card(p, "Attack")
    win:toggle(c, "Fast Attack", "zero cooldowns, real credited M1", "FastAttack")
    win:toggle(c, "Auto Click", nil, "AutoClick")
    win:slider(c, "Hitbox Range", "hitbox", 20, 200, 5)
    win:slider(c, "Click Delay", "AutoClickDelay", 0.05, 1, 0.01)
    win:button(c, "Attack Method", "tap to switch m1 <-> net remote", function()
        C.set("method", C.get("method") == "m1" and "net" or "m1")
        U.notify("attack method: " .. C.get("method"))
    end)

    c = win:card(p, "Kill Aura")
    win:toggle(c, "Kill Aura", "long-range M1, snaps onto the mob first", "killaura")
    win:slider(c, "Aura Range", "aura", 40, 300, 10)
    win:label(c, "Instakill is not offered: writing Health client-side gives no money/exp.", Color3.fromRGB(230, 150, 150))

    c = win:card(p, "Skills")
    win:toggle(c, "AimBot Skill Enemy", "face the mob before firing skills", "AimBotSkill")
    win:toggle(c, "Skill Z", nil, "SkillZ")
    win:toggle(c, "Skill X", nil, "SkillX")
    win:toggle(c, "Skill C", nil, "SkillC")
    win:toggle(c, "Skill V", nil, "SkillV")
    win:toggle(c, "Skill F", nil, "SkillF")
    win:slider(c, "Skill Health Cutoff", "HealthSkill", 10, 100, 5)

    c = win:card(p, "Haki / Heal")
    win:toggle(c, "Auto Buso", nil, "AutoHaki")
    win:toggle(c, "Auto Ken", nil, "AutoKenV2")
    win:toggle(c, "Heal When Low", "under 30% HP", "heal")

    -- STATS ----------------------------------------------------------------
    p = win:tab("Stats")
    c = win:card(p, "Mastery")
    win:toggle(c, "Auto Farm Mastery", "grind the equipped tool", "AutoFarmMastery")
    win:dropdown(c, "Tool", "ToolMastery", { "Blox Fruit", "Melee", "Sword", "Gun" })
    win:slider(c, "Stop At", "AutoMasteryValue", 100, 600, 50)
    c = win:card(p, "Stat Points")
    win:toggle(c, "Auto Stats", "spend points as they arrive", "AutoStats")
    win:button(c, "Stat", "tap to cycle Melee/Sword/Gun/Defense/Blox Fruit", function()
        local order = { "Melee", "Sword", "Gun", "Defense", "Blox Fruit" }
        for i, s in ipairs(order) do
            if s == C.get("stat") then C.set("stat", order[i % #order + 1]) return U.notify("stat: " .. C.get("stat")) end
        end
        C.set("stat", "Melee")
    end)
    win:button(c, "Check Boost", "read your current boosts", function()
        local r = U.F("CheckBoost")
        U.log("i", "boost: " .. tostring(r))
        U.notify("boost -> Log tab")
    end)
    c = win:card(p, "Race")
    win:toggle(c, "Auto Race V2", "the Alchemist race quest", "chain_Race V2")
    win:button(c, "Race Reroll", "BlackbeardReward reroll 1", function() U.F("BlackbeardReward", "Reroll", "1") end)
    win:button(c, "Race Reroll (2)", "second reroll slot", function() U.F("BlackbeardReward", "Reroll", "2") end)
    win:button(c, "Stat Refund", "BlackbeardReward refund", function() U.F("BlackbeardReward", "Refund", "1") end)

    -- FEATURES --------------------------------------------------------------
    p = win:tab("Features")
    c = win:card(p, "Bosses")
    for _, name in ipairs({ "The Saw", "Thunder God", "Cursed Captain", "Don Swan",
                           "Darkbeard", "rip_indra True Form", "Soul Reaper", "Order" }) do
        win:toggle(c, "Auto " .. name, nil, "boss_" .. name)
    end

    c = win:card(p, "Mobs / Materials")
    win:toggle(c, "Auto Farm Bone", nil, "mob_Bone")
    win:toggle(c, "Auto Farm Ectoplasm", nil, "mob_Ectoplasm")
    win:toggle(c, "Auto Farm Candy", nil, "mob_Candy")
    win:toggle(c, "Auto Pirates Sea", nil, "mob_Pirates Sea")
    win:toggle(c, "Auto Factory", nil, "mob_Factory")
    win:toggle(c, "Auto Rengoku", nil, "mob_Rengoku")
    win:toggle(c, "Auto Tushita", nil, "mob_Tushita")
    win:dropdown(c, "Material", "MaterialSelected", D and D.materials[U.sea] or {})
    win:toggle(c, "Auto Farm Material", "uses the material above", "mob_Material")

    c = win:card(p, "Quests / Unlocks")
    for _, key in ipairs({ "Ken V2", "Musketeer Hat", "Saber", "Rainbow Haki",
                           "Soul Guitar", "Second Sea", "Third Sea" }) do
        win:toggle(c, "Auto " .. key, nil, "chain_" .. key)
    end

    c = win:card(p, "Fighting Styles")
    for _, f in ipairs(D and D.fighters or {}) do
        win:toggle(c, "Auto " .. f[1], "mastery then buy", "fighter_" .. f[1])
    end

    c = win:card(p, "Fruit / Chest")
    win:toggle(c, "Teleport To Fruit", "walk to any fruit on the ground", "TeleportToFruit")
    win:toggle(c, "Auto Store Fruits", nil, "AutoStoreFruits")
    win:toggle(c, "Auto Chest Tween", nil, "AutoChestTween")
    win:toggle(c, "Auto Chest Bypass", nil, "AutoChestBypass")

    c = win:card(p, "Server")
    win:toggle(c, "Auto Elite Hunter", "hops until the elite boss is up", "chain_Elite Hunter")
    win:toggle(c, "Hop If Don Swan", nil, "AutoDonSwanHop")
    win:toggle(c, "Hop If Elite Hunter", nil, "AutoEliteHunterHop")
    win:toggle(c, "Hop If Rengoku", nil, "AutoRengokuHop")
    win:toggle(c, "Hop If Tushita", nil, "AutoTushitaHop")
    win:toggle(c, "Hop If Rainbow Haki", nil, "RainbowHakiHop")
    win:button(c, "Server Hop", "jump to a less full server", function() M.serverHop() end)

    c = win:card(p, "Misc Switches")
    win:toggle(c, "Attack Distance", "widen hitboxMagnitude", "AttackDistance")
    win:toggle(c, "Auto Buy Chip", "raid chip", "AutoBuyChip")
    win:toggle(c, "Auto Farm Raid", nil, "AutoFarmRaid")
    win:toggle(c, "Auto Buy Haki Color", nil, "AutoBuyHakiColor")
    win:toggle(c, "Auto Legendary Sword", nil, "AutoLegendarySword")
    win:toggle(c, "Auto True Triple Katana", nil, "AutoTTK")
    win:toggle(c, "Auto Cursed Dual Katana", "long chain, needs Tushita + Yama", "AutoCursedDualKatana")
    win:toggle(c, "Auto Bartilo Quest", nil, "AutoBartiloQuest")
    win:toggle(c, "Auto Don Swan Hop", nil, "AutoDonSwanHop")

    -- TELEPORT --------------------------------------------------------------
    p = win:tab("Teleport")
    c = win:card(p, "Islands")
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

    -- SHOP ------------------------------------------------------------------
    p = win:tab("Shop")
    c = win:card(p, "Codes")
    win:button(c, "Redeem All Codes", "sends the current public code list", function() M.redeemCodes() end)
    c = win:card(p, "Fighting Styles")
    for _, s in ipairs({ "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
                         "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon",
                         "Godhuman", "Sanguine Art" }) do
        win:button(c, "Buy " .. s, nil, function() U.F(s, true) U.F(s) U.notify("buying " .. s) end)
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
    c = win:card(p, "Race / Misc")
    win:button(c, "Ghoul Race", nil, function() U.F("GhoulTrainer", "Buy") end)
    win:button(c, "Cyborg Race", nil, function() U.F("CyborgTrainer", "Buy") end)
    win:button(c, "Devil Fruit Shop", nil, function() U.F("Cousin", "Buy") end)

    -- VISUAL ----------------------------------------------------------------
    p = win:tab("Visual")
    c = win:card(p, "ESP")
    win:toggle(c, "ESP Fruits", nil, "EspFruits")
    win:toggle(c, "ESP Chests", nil, "EspChests")
    win:toggle(c, "ESP Flowers", nil, "EspFlowers")
    win:toggle(c, "ESP Islands", nil, "EspIslands")
    win:toggle(c, "ESP Players", nil, "EspPlayer")
    c = win:card(p, "Performance")
    win:toggle(c, "Low-End Mode", "kills particles + shadows (mobile fps)", "lowend")
    win:toggle(c, "Anti-AFK", nil, "AntiAFK")
    win:toggle(c, "Walk On Water", "platform under your feet", "WalkOnWater")
    win:toggle(c, "Panic Mode", "clears camera shake", "PanicMode")

    -- MISC ------------------------------------------------------------------
    p = win:tab("Misc")
    c = win:card(p, "Webhook")
    win:label(c, "paste a Discord webhook URL here, then Log tab > Send")
    win:textbox(c, "Webhook", "webhook", "https://discord.com/api/webhooks/...")
    c = win:card(p, "Credits")
    win:label(c, "Raf's Personal Script - use an alt account")
    return M
end

-- actions -------------------------------------------------------------------
function M.serverHop()
    local Http = game:GetService("HttpService")
    local TS = game:GetService("TeleportService")
    local ok, body = pcall(function()
        return game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId))
    end)
    if not ok or not body then return U.notify("server list blocked") end
    for _, s in ipairs(Http:JSONDecode(body).data or {}) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            U.notify("hopping...")
            TS:TeleportToPlaceInstance(game.PlaceId, s.id, U.LP)
            return
        end
    end
    U.notify("no free server")
end

function M.redeemCodes()
    if not U.Redeem then return U.notify("no Redeem remote") end
    local n = 0
    for _, code in ipairs(D and D.codes or {}) do
        U.remote(U.Redeem, true, code)
        n = n + 1
    end
    U.notify(n .. " codes sent")
end

function M.teleportIsland()
    local w = workspace:FindFirstChild("_WorldOrigin")
    local loc = w and w:FindFirstChild("Locations")
    if not loc then return U.notify("no Locations registry") end
    local island = loc:FindFirstChild(C.get("island") or "")
    if not island then
        local names = {}
        for _, i in ipairs(loc:GetChildren()) do table.insert(names, i.Name) end
        U.log("i", "islands: " .. table.concat(names, ", "))
        return U.notify("pick an island in the dropdown")
    end
    local part = island.PrimaryPart or island:FindFirstChildWhichIsA("BasePart")
    if part then U.tp(part.CFrame * CFrame.new(0, 30, 0)) end
end

return M
