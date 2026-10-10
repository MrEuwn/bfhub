-- Sea events. The headline feature: hop until Mirage Island (or another event)
-- spawns, then stop hopping and teleport onto it. Uses live Locations registry,
-- so it works in Sea 3 and is not fooled by stale hardcoded coords.
return function(U, UI, C, win)
    local M = {}
    local hopping, autoTp = false, true
    local targets = { mirage = false, fullmoon = false, kitsune = false, prehistoric = false }
    local hopCount = 0
    local lastHop = 0

    local function hasMirage()
        for _, name in ipairs({ "MirageIsland", "Mirage Island" }) do
            if U.findIsland(name) then return true end
        end
        return false
    end
    local function hasKitsune()
        return U.findIsland("kitsune") ~= nil
    end
    local function hasPrehistoric()
        return U.findIsland("prehistoric") ~= nil
    end
    local function isFullMoon()
        local ok, ph = pcall(function() return U.Lighting:GetMoonPhase() end)
        return ok and ph == Enum.MoonPhase.Full
    end

    local function targetMet()
        if targets.mirage and hasMirage() then return "Mirage" end
        if targets.fullmoon and isFullMoon() then return "FullMoon" end
        if targets.kitsune and hasKitsune() then return "Kitsune" end
        if targets.prehistoric and hasPrehistoric() then return "Prehistoric" end
        return nil
    end

    -- Server list via Roblox public API; falls back to plain Teleport if blocked.
    local function hop()
        local place = game.PlaceId
        local ok, res = pcall(function()
            return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(place))
        end)
        if ok and res then
            local ok2, data = pcall(function() return U.Http:JSONDecode(res) end)
            if ok2 and data and data.data then
                local pool = {}
                for _, srv in ipairs(data.data) do
                    if srv.id and srv.playing and srv.maxPlayers and srv.playing < srv.maxPlayers then
                        table.insert(pool, srv.id)
                    end
                end
                if #pool > 0 then
                    local job = pool[math.random(1, #pool)]
                    U.Teleport:TeleportToPlaceInstance(place, job, U.player)
                    return true
                end
            end
        end
        U.Teleport:Teleport(place)   -- fallback
        return false
    end

    local t = win:tab("Sea Events")
    local s = t:section("Mirage Island")
    local status = s:label("checking...")
    s:toggle("Auto Mirage (hop -> tp)", false, function(on) hopping = on; targets.mirage = on end)
    s:toggle("Auto Teleport When Found", true, function(on) autoTp = on end)
    s:button("Check Mirage Now", function()
        status.Text = hasMirage() and "Mirage Island: SPAWNED" or "Mirage Island: not spawned"
    end)
    s:button("Teleport to Mirage Now", function()
        local v = U.findIsland("mirage")
        if v then U.tp(v, 40) U.notify("TP -> Mirage Island") else U.notify("Mirage not here") end
    end)

    t:section("Other Events")
    s:toggle("Also target Full Moon", false, function(on) targets.fullmoon = on end)
    s:toggle("Also target Kitsune", false, function(on) targets.kitsune = on end)
    s:toggle("Also target Prehistoric", false, function(on) targets.prehistoric = on end)
    s:button("Server Hop (manual)", function() hop() end)

    function M.tick()
        -- live status label
        status.Text = hasMirage() and "Mirage Island: SPAWNED" or "Mirage Island: not spawned"

        if not hopping then return end
        local hit = targetMet()
        if hit then
            hopping = false
            U.notify("Found: " .. hit .. " - stopping hop")
            if autoTp then
                local v = U.findIsland(hit == "Mirage" and "mirage" or hit)
                if v then task.wait(1) U.tp(v, 40) end
            end
            return
        end
        if os.clock() - lastHop > 3 then
            lastHop = os.clock()
            hopCount = hopCount + 1
            C.set("hopCount", hopCount)
            hop()
        end
    end

    return M
end
