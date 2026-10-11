--[[ pages.lua - Farm / Combat / Player / Misc tabs. UI only: every toggle writes
     into the shared config store that farm.lua and extras.lua read each tick. ]]

local M = {}

function M.init(U, C, UI, win)
    M.U, M.C = U, C

    -- Farm ---------------------------------------------------------------
    local p = win:tab("Farm")
    local c = win:card(p, "Auto Farm")
    win:toggle(c, "Auto Farm Level", "kill quest mobs for your level", "farm")
    win:toggle(c, "Auto Quest", "accept the quest automatically", "autoquest")
    win:slider(c, "Farm Distance", "farmdistance", 5, 60, 1)
    win:toggle(c, "Orbit Target", "circle the mob so hits keep landing", "orbit")

    c = win:card(p, "Bring Mobs")
    win:toggle(c, "Bring Mobs", "pin mobs + enlarge hitbox", "bring")
    win:slider(c, "Bring Distance", "bringdist", 50, 500, 10)

    c = win:card(p, "Travel")
    win:toggle(c, "Tween Travel", "smooth flight instead of instant teleport", "tween")
    win:slider(c, "Tween Speed", "tweenspeed", 60, 400, 10)
    win:toggle(c, "Fly / Hover", "hold position above the mob", "hover")
    win:toggle(c, "NoClip", nil, "noclip")
    win:button(c, "STOP TWEEN", "kill-switch for a stuck tween", function() U.stopTween() end)

    -- Combat -------------------------------------------------------------
    p = win:tab("Combat")
    c = win:card(p, "Attack")
    win:toggle(c, "Fast Attack", "zero cooldowns, real credited M1", "fastattack")
    win:slider(c, "Attack Range", "attackdist", 20, 200, 5)
    win:button(c, "Attack Method", "tap to switch m1 <-> net remote", function()
        C.set("method", C.get("method") == "m1" and "net" or "m1")
        U.notify("attack method: " .. C.get("method"))
    end)
    win:button(c, "Weapon", "tap to cycle Melee/Sword/Gun/Blox Fruit", function()
        local order = { "Melee", "Sword", "Gun", "Blox Fruit" }
        for i, w in ipairs(order) do
            if w == C.get("weapon") then
                C.set("weapon", order[i % #order + 1])
                return U.notify("weapon: " .. C.get("weapon"))
            end
        end
        C.set("weapon", "Melee")
    end)

    c = win:card(p, "Kill Aura")
    win:toggle(c, "Kill Aura", "long-range M1, snaps onto the mob first", "killaura")
    win:slider(c, "Aura Range", "aura", 40, 300, 10)
    win:label(c, "Instakill is not offered: writing Health client-side gives no money/exp.", Color3.fromRGB(230, 150, 150))

    c = win:card(p, "Haki / Heal")
    win:toggle(c, "Auto Buso", nil, "autobuso")
    win:toggle(c, "Auto Ken", nil, "autoken")
    win:toggle(c, "Heal When Low", "under 30% HP", "heal")

    -- Player -------------------------------------------------------------
    p = win:tab("Player")
    c = win:card(p, "Stats")
    win:toggle(c, "Auto Stat Point", "spend points as they arrive", "autostat")
    win:button(c, "Stat", "tap to cycle Melee/Sword/Gun/Defense/Blox Fruit", function()
        local order = { "Melee", "Sword", "Gun", "Defense", "Blox Fruit" }
        for i, s in ipairs(order) do
            if s == C.get("stat") then
                C.set("stat", order[i % #order + 1])
                return U.notify("stat: " .. C.get("stat"))
            end
        end
        C.set("stat", "Melee")
    end)
    win:button(c, "Check Boost", "read your current boosts", function()
        local r = U.F("CheckBoost")
        U.log("i", "boost: " .. tostring(r))
        U.notify("boost -> Log tab")
    end)

    c = win:card(p, "Race")
    win:button(c, "Race Reroll", "BlackbeardReward reroll 1", function() U.F("BlackbeardReward", "Reroll", "1") end)
    win:button(c, "Race Reroll (2)", "second reroll slot", function() U.F("BlackbeardReward", "Reroll", "2") end)
    win:button(c, "Stat Refund", "BlackbeardReward refund", function() U.F("BlackbeardReward", "Refund", "1") end)

    -- Misc ---------------------------------------------------------------
    p = win:tab("Misc")
    c = win:card(p, "World")
    win:toggle(c, "ESP Mobs", "name tags on enemies", "esp")
    win:button(c, "Teleport to Island", "reads the live Locations registry", function()
        local loc = workspace:FindFirstChild("_WorldOrigin")
        loc = loc and loc:FindFirstChild("Locations")
        if not loc then return U.notify("no Locations registry") end
        local names = {}
        for _, i in ipairs(loc:GetChildren()) do table.insert(names, i.Name) end
        U.log("i", "islands: " .. table.concat(names, ", "))
        U.notify(#names .. " islands -> Log tab")
    end)

    c = win:card(p, "Codes")
    win:button(c, "Redeem All Known Codes", "tries the current public code list", function()
        local codes = {
            "Sub2CaptainMaui", "DEVSCOOKING", "kittgaming", "Sub2Fer999", "Enyu_is_Pro",
            "Magicbus", "JCWK", "StarcodeHEO", "Bluxxy", "fudd10_v2", "Fudd10", "Bignews",
            "THEGREATACE", "SUB2GAMERROBOT_EXP1", "Sub2NoobMaster123", "Sub2UncleKizaru",
            "Sub2Daigrock", "AxiTpSword", "SwordTycoon",
        }
        for _, code in ipairs(codes) do
            if U.Redeem then U.remote(U.Redeem, true, code) end
        end
        U.notify("codes tried")
    end)

    c = win:card(p, "Log Webhook")
    win:label(c, "paste a Discord webhook URL here, then Log tab > Send")
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 24)
    box.BackgroundColor3 = Color3.fromRGB(22, 23, 28)
    box.TextColor3 = Color3.fromRGB(232, 234, 242)
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.Text = C.get("webhook")
    box.PlaceholderText = "https://discord.com/api/webhooks/..."
    box.ClearTextOnFocus = false
    box.Parent = c
    box:GetPropertyChangedSignal("Text"):Connect(function() C.set("webhook", box.Text) end)

    c = win:card(p, "Credits")
    win:label(c, "use an alt account. this is a cheat.")
    return M
end

return M
