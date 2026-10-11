-- Fruit: ESP handled in esp.lua; here: sniper, auto store, mastery, notifier.
return function(U, UI, C, win)
    local M = {}
    local sniper, store, mastery, notifier
    local seen = {}

    -- cached: a full workspace descendant scan is expensive on mobile, so the
    -- tool list is refreshed at most twice a second.
    local cache, cacheAt = {}, 0
    local function fruitTools()
        if os.clock() - cacheAt < 0.5 then return cache end
        cacheAt = os.clock()
        local out = {}
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Tool") and string.find(string.lower(d.Name), "fruit", 1, true) then
                table.insert(out, d)
            end
        end
        cache = out
        return out
    end

    local RARITY = {
        Rocket = 1, Spin = 1, Chop = 1, Spring = 1, Bomb = 1, Smoke = 1, Spike = 1, Flame = 2,
        Falcon = 2, Ice = 2, Sand = 2, Dark = 2, Diamond = 2, Light = 2, Rubber = 2, Barrier = 2,
        Ghost = 2, Magma = 3, Door = 3, Quake = 3, Buddha = 4, Love = 3, Spider = 3, Sound = 3,
        Phoenix = 4, Portal = 3, Rumble = 3, Pain = 3, Blizzard = 4, Gravity = 4, Mammoth = 4,
        ["T-Rex"] = 5, Dough = 4, Shadow = 4, Venom = 4, Control = 4, Spirit = 4, Dragon = 6,
        Leopard = 6, Kitsune = 6, Gas = 5, Yeti = 5,
    }
    local function rarity(name)
        for k, v in pairs(RARITY) do if string.find(name, k, 1, true) then return v end end
        return 0
    end

    local t = win:tab("Fruit")
    local s = t:section("Sniper")
    s:toggle("Fruit Sniper (auto tp + pick)", false, function(on) sniper = on end)
    s:toggle("Auto Store Fruit", false, function(on) store = on end)
    s:dropdown("Min Rarity to Store", { "Common(1)", "Uncommon(2)", "Rare(3)", "Legendary(4)", "Mythical(5)" },
        "Legendary(4)", function(v) C.set("minRarity", tonumber(string.match(v, "%d"))) end)

    t:section("Mastery")
    s:toggle("Auto Devil Fruit Mastery", false, function(on) mastery = on end)

    t:section("Notifier")
    s:toggle("Fruit Notifier", false, function(on) notifier = on end)

    function M.tick()
        local r = U.root()
        for _, f in ipairs(fruitTools()) do
            local handle = f:FindFirstChild("Handle")
            if handle and r then
                local rar = rarity(f.Name)
                if notifier and not seen[f] then
                    seen[f] = true
                    U.notify(("Fruit: %s (r%d)"):format(f.Name, rar))
                end
                if sniper then
                    r.CFrame = handle.CFrame
                    U.touch(r, handle)
                    task.wait(0.1)
                elseif store and rar >= (C.get("minRarity") or 4) then
                    r.CFrame = handle.CFrame
                    U.touch(r, handle)
                end
            end
        end
        if mastery then
            -- equip a fruit tool then attack; keep it generic
            local c = U.player.Character
            local tool = c and c:FindFirstChildOfClass("Tool")
            if tool then U.attack() end
        end
    end

    return M
end
