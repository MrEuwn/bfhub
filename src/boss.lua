-- Boss tab. Headline: Tyrant of the Skies (Tiki Outpost, Sea 3).
-- Spawn ritual: kill ~300 Tiki mobs (lights 4 eagle eyes) then break the pots.
return function(U, UI, C, win)
    local M = {}
    local tyrant = false
    local lastPot = 0

    local TIKI_MOBS = { "Isle Outlaw", "Island Boy", "Sun-kissed Warrio", "Sun-kissed Warrior" }
    local TIKI_ISLANDS = { "Tiki", "Tiki Outpost" }

    local function gotoTiki()
        for _, name in ipairs(TIKI_ISLANDS) do
            local v = U.findIsland(name)
            if v then U.tp(v, 40); return true end
        end
        return false
    end

    local function nearestTikiMob()
        for _, n in ipairs(TIKI_MOBS) do
            local m = U.nearestMob(n)
            if m then return m end
        end
        return nil
    end

    -- break pots: workspace parts whose name contains "pot"/"vase"; touch them
    local function breakPots()
        local r = U.root(); if not r then return end
        local best, bd
        for _, d in ipairs(workspace:GetDescendants()) do
            local nm = string.lower(d.Name)
            if d:IsA("BasePart") and (string.find(nm, "pot") or string.find(nm, "vase") or string.find(nm, "jar")) then
                local dist = (d.Position - r.Position).Magnitude
                if not bd or dist < bd then bd = dist; best = d end
            end
        end
        if best then
            r.CFrame = CFrame.new(best.Position + Vector3.new(0, 6, 0))
            U.touch(r, best)
        end
    end

    local function tyrantAlive()
        return U.nearestMob("Tyrant") ~= nil
    end

    local t = win:tab("Boss")

    local s = t:section("Tyrant of the Skies")
    local status = s:label("Tyrant: not spawned")
    s:toggle("Auto Tyrant of the Skies", false, function(on) tyrant = on; if on then gotoTiki() end end)
    s:button("Teleport to Tiki Outpost", function() gotoTiki() end)
    s:button("Break Pots Now", function() breakPots() end)
    s:label("Kills Tiki mobs to light the eagle eyes, then breaks the pots.")

    t:section("Generic Boss Farm")
    local gb = false
    s:toggle("Auto Farm Nearest Boss", false, function(on) gb = on end)
    s:label("Farms any nearby mob whose name contains a known boss keyword.")

    local BOSSES = { "Tyrant", "Dough King", "Cursed Captain", "Rip Indra", "Cake Prince",
                     "Kilo Admiral", "Hydra Leader", "Beautiful Pirate", "Captain Elephant" }
    local function nearestBoss()
        for _, b in ipairs(BOSSES) do
            local m = U.nearestMob(b)
            if m then return m end
        end
        return nil
    end

    function M.tick()
        if tyrant then
            status.Text = tyrantAlive() and "Tyrant: SPAWNED - attacking" or "Tyrant: not spawned - farming Tiki"
            local boss = U.nearestMob("Tyrant")
            if boss then
                local r = U.root()
                local hrp = boss:FindFirstChild("HumanoidRootPart")
                if r and hrp then r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0)); U.touch(r, hrp) end
                U.attack()
            else
                local m = nearestTikiMob()
                if m then
                    local r = U.root()
                    local hrp = m:FindFirstChild("HumanoidRootPart")
                    if r and hrp then r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0)); U.touch(r, hrp) end
                    U.attack()
                else
                    if os.clock() - lastPot > 1 then lastPot = os.clock(); breakPots() end
                end
            end
        end
        if gb then
            local b = nearestBoss()
            if b then
                local r = U.root()
                local hrp = b:FindFirstChild("HumanoidRootPart")
                if r and hrp then r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0)); U.touch(r, hrp) end
                U.attack()
            end
        end
    end

    return M
end
