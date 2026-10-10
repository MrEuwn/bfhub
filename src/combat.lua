-- Combat: fast attack, auto skill, kill aura, godmode, buso/ken, race v4.
return function(U, UI, C, win)
    local M = {}
    local fast, aura, god, buso, ken

    local function nearbyMobs(radius)
        local r = U.root(); if not r then return {} end
        radius = radius or 30
        local out = {}
        for _, m in ipairs(workspace:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
                local isP = false
                for _, p in ipairs(U.Players:GetPlayers()) do if p.Character == m then isP = true end end
                if not isP then
                    local hrp = m:FindFirstChild("HumanoidRootPart")
                    local h = m:FindFirstChildOfClass("Humanoid")
                    if hrp and h and h.Health > 0 and (hrp.Position - r.Position).Magnitude <= radius then
                        table.insert(out, m)
                    end
                end
            end
        end
        return out
    end

    local t = win:tab("Combat")
    local s = t:section("Attack")
    s:toggle("Fast Attack (no cooldown)", false, function(on) fast = on end)
    s:toggle("Kill Aura", false, function(on) aura = on end)
    s:dropdown("Aura Radius", { "20", "30", "50", "80" }, "30", function(v) C.set("auraRadius", tonumber(v)) end)

    t:section("Survival")
    s:toggle("God Mode", false, function(on) god = on end)
    s:toggle("Auto Buso (Haki)", false, function(on) buso = on end)
    s:toggle("Auto Ken (Observation)", false, function(on) ken = on end)

    t:section("Race V4")
    s:button("Transform Race V4", function()
        U.commF("RaceV4Transform")   -- ponytail: exact remote name may differ; harmless if nil
        U.notify("Race V4 transform fired")
    end)

    function M.tick()
        if fast then
            U.attack()
        end
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
    end

    return M
end
