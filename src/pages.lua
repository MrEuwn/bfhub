--[[ pages.lua - every tab, built lazily by ui.lua (a page is constructed the first
     time it is opened, so load stays instant).

     Only Redz V2 features live here. Everything is grouped the way the source
     grouped it, minus the rows the source itself shipped as dead. ]]

local M = {}
local U, C, UI, win, D

function M.init(_U, _C, _UI, _w, deps)
    U, C, UI, win = _U, _C, _UI, _w
    D = deps and deps.D

    -- FARM ------------------------------------------------------------------
    win:tab("Farm", function(page)
        local c = win:card(page, "Auto Farm")
        win:toggle(c, "Auto Farm Level", "AutoFarm_Level")
        win:dropdown(c, "Mode", "farmmode", { "level", "nearest", "boss", "mastery" })
        win:dropdown(c, "Weapon", "FarmTool", { "Melee", "Sword", "Gun", "Blox Fruit" })
        win:slider(c, "Farm Distance", "FarmPos", 5, 60, 1)
        win:toggle(c, "Bring Mobs", "BringMobs")
        win:slider(c, "Bring Distance", "BringMobsDistance", 50, 500, 10)
        win:toggle(c, "Auto Farm Nearest", "AutoFarmNearest")

        c = win:card(page, "Travel")
        win:toggle(c, "Tween Travel", "tween")
        win:slider(c, "Tween Speed", "TweenSpeed", 60, 400, 10)
        win:toggle(c, "NoClip", "noclip")
        win:button(c, "STOP TWEEN", function() U.stopTween() end)

        c = win:card(page, "Boss")
        win:dropdown(c, "Boss List", "BossSelected", D.bossList[U.sea] or {})
        win:toggle(c, "Auto Farm Boss Selected", "boss_BossSelected")
        win:toggle(c, "Auto Farm All Boss", "KillAllBosses")
        win:toggle(c, "Take Boss Quest", "TakeQuestBoss")
    end)

    -- COMBAT ----------------------------------------------------------------
    win:tab("Combat", function(page)
        local c = win:card(page, "Attack")
        win:toggle(c, "Fast Attack", "FastAttack")
        win:toggle(c, "Auto Click", "AutoClick")
        win:toggle(c, "Attack Distance", "AttackDistance")
        win:slider(c, "Click Delay", "AutoClickDelay", 0.05, 1, 0.01)
        win:button(c, "Attack Method: m1", function()
            C.set("method", C.get("method") == "m1" and "net" or "m1")
            U.notify("attack method: " .. C.get("method"))
        end)

        c = win:card(page, "Kill Aura")
        win:toggle(c, "Kill Aura", "killaura")
        win:slider(c, "Aura Range", "aura", 40, 300, 10)
        win:label(c, "instakill is off the table: writing Health client-side pays nothing", Color3.fromRGB(220, 140, 140))

        c = win:card(page, "Skills")
        win:toggle(c, "AimBot Skill Enemy", "AimBotSkill")
        win:toggle(c, "Skill Z", "SkillZ")
        win:toggle(c, "Skill X", "SkillX")
        win:toggle(c, "Skill C", "SkillC")
        win:toggle(c, "Skill V", "SkillV")
        win:toggle(c, "Skill F", "SkillF")
        win:slider(c, "Health Cutoff", "HealthSkill", 10, 100, 5)

        c = win:card(page, "Haki / Heal")
        win:toggle(c, "Auto Haki (Buso + Ken)", "AutoHaki")
        win:toggle(c, "Heal When Low", "heal")
    end)

    -- FARMING (the named farmers from the source) ---------------------------
    win:tab("Farming", function(page)
        local c = win:card(page, "Bosses")
        for _, name in ipairs({ "The Saw", "Thunder God", "Cursed Captain", "Don Swan",
                               "Darkbeard", "rip_indra True Form", "Soul Reaper", "Order" }) do
            win:toggle(c, "Auto " .. name, "boss_" .. name)
        end

        c = win:card(page, "Mobs / Materials")
        win:toggle(c, "Auto Farm Bone", "mob_Bone")
        win:toggle(c, "Auto Farm Ectoplasm", "mob_Ectoplasm")
        win:toggle(c, "Auto Farm Candy", "mob_Candy")
        win:toggle(c, "Auto Pirates Sea", "mob_Pirates Sea")
        win:toggle(c, "Auto Factory", "mob_Factory")
        win:toggle(c, "Auto Rengoku", "mob_Rengoku")
        win:toggle(c, "Auto Tushita", "mob_Tushita")
        win:dropdown(c, "Material", "MaterialSelected", D.materials[U.sea] or {})
        win:toggle(c, "Auto Farm Material", "mob_Material")

        c = win:card(page, "Mastery")
        win:toggle(c, "Auto Farm Mastery", "AutoFarmMastery")
        win:dropdown(c, "Tool", "ToolMastery", { "Blox Fruit", "Melee", "Sword", "Gun" })
        win:slider(c, "Stop At", "AutoMasteryValue", 100, 600, 50)

        c = win:card(page, "Fighting Styles")
        for _, f in ipairs(D.fighters) do
            win:toggle(c, "Auto " .. f[1], "fighter_" .. f[1])
        end
    end)

    -- QUESTS ----------------------------------------------------------------
    win:tab("Quests", function(page)
        local c = win:card(page, "Unlocks")
        for _, key in ipairs({ "Ken V2", "Musketeer Hat", "Saber", "Rainbow Haki",
                               "Soul Guitar", "Race V2", "Second Sea", "Third Sea" }) do
            win:toggle(c, "Auto " .. key, "chain_" .. key)
        end
        c = win:card(page, "Elite Hunter")
        win:toggle(c, "Auto Elite Hunter", "chain_Elite Hunter")
        win:toggle(c, "Hop If Not Spawned", "AutoEliteHunterHop")
        c = win:card(page, "Server Hop")
        win:toggle(c, "Hop If Don Swan", "AutoDonSwanHop")
        win:toggle(c, "Hop If Rengoku", "AutoRengokuHop")
        win:toggle(c, "Hop If Tushita", "AutoTushitaHop")
        win:toggle(c, "Hop If Rainbow Haki", "RainbowHakiHop")
        win:button(c, "Server Hop Now", function() M.serverHop() end)
        c = win:card(page, "Race")
        win:button(c, "Race Reroll", function() U.F("BlackbeardReward", "Reroll", "1") end)
        win:button(c, "Race Reroll (2)", function() U.F("BlackbeardReward", "Reroll", "2") end)
        win:button(c, "Stat Refund", function() U.F("BlackbeardReward", "Refund", "1") end)
    end)

    -- ITEMS -----------------------------------------------------------------
    win:tab("Items", function(page)
        local c = win:card(page, "Fruit / Chest")
        win:toggle(c, "Teleport To Fruit", "TeleportToFruit")
        win:toggle(c, "Auto Store Fruits", "AutoStoreFruits")
        win:toggle(c, "Auto Chest Tween", "AutoChestTween")
        win:toggle(c, "Auto Chest Bypass", "AutoChestBypass")
        c = win:card(page, "Raid")
        win:toggle(c, "Auto Farm Raid", "AutoFarmRaid")
        win:toggle(c, "Auto Buy Chip", "AutoBuyChip")
        c = win:card(page, "Misc Buys")
        win:toggle(c, "Auto Buy Haki Color", "AutoBuyHakiColor")
        win:toggle(c, "Auto Legendary Sword", "AutoLegendarySword")
        win:toggle(c, "Auto True Triple Katana", "AutoTTK")
        win:toggle(c, "Auto Bartilo Quest", "AutoBartiloQuest")
        win:toggle(c, "Auto Cursed Dual Katana", "AutoCursedDualKatana")
        win:label(c, "CDK needs Tushita and Yama mastered first", Color3.fromRGB(150, 155, 170))
    end)

    -- TELEPORT --------------------------------------------------------------
    win:tab("Teleport", function(page)
        local c = win:card(page, "Islands")
        local islands = {}
        local w = workspace:FindFirstChild("_WorldOrigin")
        local loc = w and w:FindFirstChild("Locations")
        if loc then
            for _, i in ipairs(loc:GetChildren()) do table.insert(islands, i.Name) end
            table.sort(islands)
        end
        if #islands == 0 then islands = { "no Locations registry" } end
        win:dropdown(c, "Island", "island", islands)
        win:button(c, "Teleport", function() M.teleportIsland() end)
        c = win:card(page, "Sea")
        win:button(c, "Sea 1", function() U.F("TravelMain") end)
        win:button(c, "Sea 2", function() U.F("TravelDressrosa") end)
        win:button(c, "Sea 3", function() U.F("TravelZou") end)
        c = win:card(page, "Server")
        win:textbox(c, "Server ID", "serverid", "jobId")
        win:button(c, "Join Server", function()
            local id = C.get("serverid")
            if id and #id > 10 then
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, id, U.LP)
            else
                U.notify("paste a jobId first")
            end
        end)
    end)

    -- SHOP ------------------------------------------------------------------
    win:tab("Shop", function(page)
        local c = win:card(page, "Codes")
        win:button(c, "Redeem All Codes", function() M.redeemCodes() end)
        c = win:card(page, "Fighting Styles")
        for _, s in ipairs({ "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
                             "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon",
                             "Godhuman", "Sanguine Art" }) do
            win:button(c, "Buy " .. s, function() U.F(s, true) U.F(s) U.notify("buying " .. s) end)
        end
        c = win:card(page, "Swords")
        for _, s in ipairs({ "Katana", "Cutlass", "Dual Katana", "Iron Mace", "Triple Katana",
                             "Pipe", "Dual-Headed Blade", "Soul Cane", "Bisento" }) do
            win:button(c, "Buy " .. s, function()
                U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
            end)
        end
        c = win:card(page, "Guns")
        for _, s in ipairs({ "Musket", "Slingshot", "Flintlock", "Refined Slingshot",
                             "Refined Flintlock", "Cannon", "Kabucha" }) do
            win:button(c, "Buy " .. s, function()
                U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
            end)
        end
        c = win:card(page, "Race")
        win:button(c, "Ghoul Race", function() U.F("GhoulTrainer", "Buy") end)
        win:button(c, "Cyborg Race", function() U.F("CyborgTrainer", "Buy") end)
        win:button(c, "Random Fruit", function() U.F("Cousin", "Buy") end)
    end)

    -- VISUAL ----------------------------------------------------------------
    win:tab("Visual", function(page)
        local c = win:card(page, "ESP")
        win:toggle(c, "ESP Fruits", "EspFruits")
        win:toggle(c, "ESP Chests", "EspChests")
        win:toggle(c, "ESP Flowers", "EspFlowers")
        win:toggle(c, "ESP Islands", "EspIslands")
        win:toggle(c, "ESP Players", "EspPlayer")
        c = win:card(page, "Performance")
        win:toggle(c, "Low-End Mode", "lowend")
        win:toggle(c, "Anti-AFK", "AntiAFK")
        win:toggle(c, "Walk On Water", "WalkOnWater")
        win:toggle(c, "Panic Mode", "PanicMode")
    end)

    -- MISC ------------------------------------------------------------------
    win:tab("Misc", function(page)
        local c = win:card(page, "Stats")
        win:toggle(c, "Auto Stats", "AutoStats")
        win:button(c, "Check Boost", function()
            U.log("i", "boost: " .. tostring(U.F("CheckBoost")))
            U.notify("boost -> Log")
        end)
        c = win:card(page, "Webhook")
        win:textbox(c, "Webhook", "webhook", "https://discord.com/api/webhooks/...")
        c = win:card(page, "About")
        win:label(c, "Raf's Personal Script")
        win:label(c, "keyless, open source, no obfuscation")
        win:label(c, "use an alt account")
    end)

    -- LOG -------------------------------------------------------------------
    win:tab("Log", function(page)
        local c = win:card(page, "Log")
        local out = win:label(c, "")
        win:button(c, "Copy", function()
            pcall(function() setclipboard(U.logText()) end)
            U.notify("copied")
        end)
        win:button(c, "Clear", function()
            U.logs = {}
            out.Text = ""
        end)
        win:button(c, "Send to Webhook", function()
            local url = C.get("webhook")
            if not url or url == "" then return U.notify("no webhook url") end
            pcall(function()
                request({
                    Url = url, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = game:GetService("HttpService"):JSONEncode({ content = "```" .. U.logText():sub(1, 1900) .. "```" }),
                })
            end)
            U.notify("sent")
        end)
        task.spawn(function()
            while win.gui.Parent do
                out.Text = U.logText()
                task.wait(1)
            end
        end)
    end)
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
    for _, code in ipairs(D.codes) do
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
    if not island then return U.notify("pick an island") end
    local part = island.PrimaryPart or island:FindFirstChildWhichIsA("BasePart")
    if part then U.tp(part.CFrame * CFrame.new(0, 30, 0)) end
end

return M
