-- Combat: fast attack, auto skill, kill aura, godmode, buso/ken, auto Buddha, race v4.
return function(U, UI, C, win)
    local M = {}
    local fast, aura, god, buso, ken, buddha
    local lastBuddha = 0

    local function nearbyMobs(radius)
        local r = U.root(); if not r then return {} end
        radius = radius or 30
        local out = {}
        for _, m in ipairs(U.mobs(nil)) do
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - r.Position).Magnitude <= radius then
                table.insert(out, m)
            end
        end
        return out
    end

    local t = win:tab("Combat")
    local s = t:section("Attack")
    s:toggle("Fast Attack (no cooldown)", false, function(on) fast = on end)
    s:toggle("Kill Aura", false, function(on) aura = on end)
    s:dropdown("Aura Radius", { "20", "30", "50", "80" }, "30", function(v) C.set("auraRadius", tonumber(v)) end)
    s:dropdown("Hitbox Range", { "40", "60", "80", "120" }, "60", function(v)
        C.set("hitbox", tonumber(v)); U.setHitbox(tonumber(v))
    end)

    t:section("Survival")
    s:toggle("God Mode", false, function(on) god = on end)
    s:toggle("Auto Buso (Haki)", false, function(on) buso = on end)
    s:toggle("Auto Ken (Observation)", false, function(on) ken = on end)

    t:section("Fruit")
    s:toggle("Auto Buddha Transform", false, function(on) buddha = on end)
    s:label("Keeps Buddha transformed for wide M1 hitbox while farming.")

    t:section("Race V4")
    s:button("Transform Race V4", function()
        U.commF("RaceV4Transform")   -- ponytail: remote name version-sensitive
        U.notify("Race V4 transform fired")
    end)

    function M.tick()
        if fast then U.fastAttack(); U.attackHit(C.get("hitbox") or 60) end
        if aura then
            local r = U.root()
            for _, m in ipairs(nearbyMobs(C.get("auraRadius") or 30)) do
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if r and hrp then U.touch(r, hrp) end
            end
            U.attack()
        end
        if god then
            local h = U.hum()
            if h then pcall(function() h.Health = h.MaxHealth end) end
        end
        if buso then U.commE("Buso") end
        if ken then U.commE("Ken") end
        if buddha and os.clock() - lastBuddha > 1 then
            lastBuddha = os.clock()
            -- Buddha transform keybind is "Z"; a fruit skill activate is safer
            local c = U.player.Character
            local tool = c and c:FindFirstChildOfClass("Tool")
            if tool and string.find(tool.Name, "Buddha", 1, true) then
                pcall(function() tool:Activate() end)
            end
        end
    end

    return M
end
