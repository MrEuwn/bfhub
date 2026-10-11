-- Combat: fast attack, auto skill, kill aura, godmode, buso/ken, auto Buddha, race v4.
return function(U, UI, C, win)
    local M = {}
    local fast, aura, god, buso, ken, buddha = true, true, false, true, true, false
    local lastBuddha = 0

    -- Kill aura: hit EVERY mob within radius. Teleport onto the nearest one so
    -- the M1 lands, then fire the real RigControllerEvent hit at the aura range
    -- so everything around takes damage (a touch alone does not damage).
    local function auraTick()
        local r = U.root(); if not r then return end
        local radius = C.get("auraRadius") or 30
        local mobs = {}
        for _, m in ipairs(U.mobs(nil)) do
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - r.Position).Magnitude <= radius then
                table.insert(mobs, m)
            end
        end
        if #mobs == 0 then return end
        -- snap onto the closest mob so the hitbox definitely covers the cluster
        local best, bd
        for _, m in ipairs(mobs) do
            local hrp = m:FindFirstChild("HumanoidRootPart")
            local d = (hrp.Position - r.Position).Magnitude
            if not bd or d < bd then bd = d; best = m end
        end
        if best then
            local hrp = best:FindFirstChild("HumanoidRootPart")
            if hrp then r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 8, 0)) end
        end
        U.fastAttack()
        U.attackHit(radius + 20)     -- wide hit covering the whole aura
        for _, m in ipairs(mobs) do
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp then U.touch(r, hrp) end
        end
    end

    local t = win:tab("Combat")
    local s = t:section("Attack")
    s:toggle("Fast Attack (no cooldown)", true, function(on) fast = on end)
    s:toggle("Kill Aura", true, function(on) aura = on end)
    s:dropdown("Aura Radius", { "20", "30", "50", "80" }, "30", function(v) C.set("auraRadius", tonumber(v)) end)
    s:dropdown("Hitbox Range", { "40", "60", "80", "120" }, "60", function(v)
        C.set("hitbox", tonumber(v)); U.setHitbox(tonumber(v))
    end)

    t:section("Survival")
    s:toggle("God Mode", false, function(on) god = on end)
    s:toggle("Auto Buso (Haki)", true, function(on) buso = on end)
    s:toggle("Auto Ken (Observation)", true, function(on) ken = on end)

    t:section("Fruit")
    s:toggle("Auto Buddha Transform", false, function(on) buddha = on end)
    s:label("Keeps Buddha transformed for wide M1 hitbox while farming.")

    t:section("Race V4")
    s:button("Transform Race V4", function()
        U.commF("RaceV4Transform")   -- ponytail: remote name version-sensitive
        U.notify("Race V4 transform fired")
    end)

    -- defaults on at startup (auto haki + kill aura)
    C.set("auraRadius", 30); C.set("hitbox", 60)

    function M.tick()
        if fast then U.fastAttack(); U.attackHit(C.get("hitbox") or 60) end
        if aura then auraTick() end
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
