-- Farm: nearest mob, selected mob, auto quest, chest, berry/material, bones.
-- ponytail: mob/quest resolution uses generic workspace + CommF_ calls; if the
-- game renames internals, only the finders here need updating.
return function(U, UI, C, win)
    local M = {}
    local farmMob, farmChest, farmBerry, farmQuest, farmMaterial
    local lastQuest = 0

    local function isPlayerModel(m)
        local h = m:FindFirstChildOfClass("Humanoid")
        if not h then return false end
        for _, p in ipairs(U.Players:GetPlayers()) do
            if p.Character == m then return true end
        end
        return false
    end

    local function aliveMobs()
        local out = {}
        for _, m in ipairs(workspace:GetChildren()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not isPlayerModel(m) then
                local h = m:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then table.insert(out, m) end
            end
        end
        return out
    end

    local function nearestMob(nameFilter)
        local r = U.root(); if not r then return nil end
        local best, bd
        for _, m in ipairs(aliveMobs()) do
            if not nameFilter or string.find(string.lower(m.Name), nameFilter, 1, true) then
                local hrp = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                if hrp then
                    local d = (hrp.Position - r.Position).Magnitude
                    if not bd or d < bd then bd = d; best = m end
                end
            end
        end
        return best
    end

    local function kill(mob, speed)
        local r = U.root(); if not r or not mob then return end
        local h = mob:FindFirstChildOfClass("Humanoid"); if not h then return end
        local hrp = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart")
        if hrp then
            r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0))
            U.touch(r, hrp)
        end
        U.attack()
        task.wait(speed or 0.15)
    end

    -- Farm tab
    local t = win:tab("Farm")
    local s = t:section("Auto Farm")

    local speed = 0.15
    s:dropdown("Farm Speed", { "Fast (0.05)", "Normal (0.15)", "Slow (0.4)" }, "Normal (0.15)", function(v)
        speed = tonumber(string.match(v, "%d+%.%d+")) or 0.15
    end)
    s:toggle("Auto Farm Nearest", false, function(on) farmMob = on and "nearest" or nil end)
    s:toggle("Include Bosses", false, function(on) C.set("farmBosses", on) end)

    local mobNames = { "Bandit", "Monkey", "Brute", "Pirate", "Fishman", "Snowman", "Desert", "Zombie", "Magma" }
    s:dropdown("Selected Mob", mobNames, "Bandit", function(v) C.set("farmMobName", v) end)
    s:toggle("Farm Selected Mob", false, function(on) farmMob = on and "selected" or nil end)

    t:section("Quests")
    s:toggle("Auto Farm Level (Quests)", false, function(on) farmQuest = on end)
    s:label("Loops the current quest: accept -> kill -> turn in.")

    t:section("Chest / Collect")
    s:toggle("Auto Chest Farm", false, function(on) farmChest = on end)
    s:toggle("Auto Collect Berry", false, function(on) farmBerry = on end)
    s:toggle("Auto Farm Material", false, function(on) farmMaterial = on end)

    -- Generic "go to nearest instance whose name matches, then touch" used by
    -- chest / berry / material. Blox Fruits spawns these as workspace children.
    local function goTouch(pat)
        local r = U.root(); if not r then return false end
        local best, bd
        for _, m in ipairs(workspace:GetChildren()) do
            if string.find(string.lower(m.Name), pat, 1, true) then
                local p = m:FindFirstChildWhichIsA("BasePart")
                if p then
                    local d = (p.Position - r.Position).Magnitude
                    if not bd or d < bd then bd = d; best = p end
                end
            end
        end
        if best then
            r.CFrame = CFrame.new(best.Position + Vector3.new(0, 4, 0))
            U.touch(r, best)
            return true
        end
        return false
    end

    function M.tick()
        if farmMob == "nearest" then
            local m = nearestMob(nil); if m then kill(m, speed) end
        elseif farmMob == "selected" then
            local m = nearestMob(string.lower(C.get("farmMobName") or "bandit"))
            if m then kill(m, speed) end
        end

        if farmQuest and os.clock() - lastQuest > 1 then
            lastQuest = os.clock()
            local lvl = U.commF("getLevel") or 0
            local name = U.commF("getCurrentQuest")
            if not name then
                -- start/accept: "StartQuest" with the level-derived quest is game-specific;
                -- fall back to the generic quest remote.
                U.commF("StartQuest")
            else
                local m = nearestMob(nil); if m then kill(m, speed) end
                U.commF("CompleteQuest")
            end
            C.set("level", lvl)
        end

        if farmChest then goTouch("chest") end
        if farmBerry then goTouch("berry") end
        if farmMaterial then goTouch("material") end
    end

    return M
end
