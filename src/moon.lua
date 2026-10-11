--[[ moon.lua - server state detection + hop.

     WHAT IS AND IS NOT POSSIBLE (measured, do not promise otherwise):
     - Detecting a full moon or a live Mirage Island in SOMEONE ELSE'S server from
       outside is not possible. https://games.roblox.com/v1/games/<place>/servers/Public
       returns only id, maxPlayers, playing, playerIds, fps, ping, name, vipServerId,
       accessCode. There is no game state in it, and there is no endpoint that has one.
       The hubs that look like they do this (HoHo's "moon-servers" / "mirage-servers")
       are reading a DISCORD CHANNEL where humans post jobIds. That is the design
       copied here: post your own find, read other people's, jump to them.
     - What IS possible is local detection plus blind hopping: read the state of the
       server you are in, and if it is not what you want, hop to a public server and
       read again. That is what this module does, and it reports its own hit rate so
       you can see what the hop actually costs.

     Local detection is the one HoHo itself uses in-game:
       Lighting.Sky.MoonTextureId compared against the phase asset ids.
     MoonPhase is exposed per phase, so "3/4" = Full Moon (current) or Next Night
     (waning gibbous, the phase that becomes full on the next night). ]]

local M = {}
local U, C, D

-- asset ids as used by in-game moon checkers; the trailing number is what matters
local MOON = {
    ["9709135895"] = "Waxing Crescent",
    ["9709139597"] = "First Quarter",
    ["9709143733"] = "Waxing Gibbous",
    ["9709149052"] = "Next Night",        -- waning gibbous: full moon next night
    ["9709149431"] = "Full Moon",
    ["9709149680"] = "Waning Gibbous",
    ["9709150086"] = "Last Quarter",
    ["9709150401"] = "Waning Crescent",
}

local state = { hops = 0, found = 0, nextHop = 0, nextPost = 0, lastMoon = nil, lastMirage = nil }

function M.init(_U, _C, _UI, _win, deps)
    U, C, D = _U, _C, deps and deps.D
end

-- detection ----------------------------------------------------------------
function M.moonPhase()
    local ok, name = pcall(function()
        local l = game:GetService("Lighting")
        local sky = l:FindFirstChild("Sky") or l:FindFirstChild("FantasySky")
        if not sky then return "Unknown" end
        local id = tostring(sky.MoonTextureId or "")
        local n = id:match("(%d+)%s*$")
        return (n and MOON[n]) or ("Unknown (" .. n .. ")")
    end)
    return ok and name or "Unknown"
end

-- "3/4 moon" in the user's words = full moon now, or the phase that turns full next night
function M.isFullMoon()
    local p = M.moonPhase()
    return p == "Full Moon" or p == "Next Night", p
end

function M.mirage()
    local map = workspace:FindFirstChild("Map")
    if map and (map:FindFirstChild("MysticIsland") or map:FindFirstChild("MirageIsland")) then
        return true
    end
    local w = workspace:FindFirstChild("_WorldOrigin")
    local loc = w and w:FindFirstChild("Locations")
    if loc then
        for _, n in ipairs({ "Mirage Island", "MirageIsland", "MysticIsland" }) do
            if loc:FindFirstChild(n) then return true end
        end
    end
    return false
end

function M.status()
    local full, phase = M.isFullMoon()
    return phase, M.mirage(), full
end

-- server list (public servers only) ----------------------------------------
local function fetchPage(cursor)
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?limit=100&sortOrder=Asc", game.PlaceId)
    if cursor then url = url .. "&cursor=" .. cursor end
    local ok, body = pcall(game.HttpGet, game, url)
    if not ok or type(body) ~= "string" then return nil end
    local ok2, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(body)
    end)
    return ok2 and data or nil
end

-- Prefer an EMPTY server: a fresh one has a fresh moon clock and an unclaimed
-- Mirage. Then prefer the least full one.
function M.pickServer()
    local minPlayers = C.get("HopMinPlayers") or 0
    local best, bestScore, cursor = nil, nil, nil
    for _ = 1, 3 do
        local data = fetchPage(cursor)
        if not data then break end
        for _, s in ipairs(data.data or {}) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers and s.playing >= minPlayers then
                local empty = (#(s.playerIds or {}) == 0) and 0 or 1
                local score = empty * 100 + s.playing
                if not bestScore or score < bestScore then best, bestScore = s, score end
            end
        end
        cursor = data.nextPageCursor
        if not cursor then break end
    end
    return best
end

function M.hopTo(jobId, label)
    local TS = game:GetService("TeleportService")
    state.hops = state.hops + 1
    state.nextHop = os.clock() + (C.get("HopDelay") or 8)
    U.notify("hop " .. state.hops .. " -> " .. tostring(label or "server"))
    local ok, err = pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, jobId, U.LP) end)
    if not ok then
        U.log("x", "teleport failed: " .. tostring(err))
        U.notify("teleport failed - Roblox may be rate limiting")
    end
    return ok
end

function M.hop()
    local s = M.pickServer()
    if not s then return U.notify("no public server found") end
    return M.hopTo(s.id, s.playing .. "/" .. s.maxPlayers .. " players")
end

-- jobIds shared through a text file the user controls (GitHub raw, pastebin, ...)
local function jobIdsFrom(text)
    local out = {}
    for id in tostring(text):gmatch("[%w%-]+%-%w+%-%w+%-%w+%-%w+") do
        table.insert(out, id)
    end
    return out
end

function M.fetchShared()
    local url = C.get("SharedUrl")
    if not url or url == "" then return U.notify("set a shared jobId url first") end
    local ok, body = pcall(game.HttpGet, game, url)
    if not ok or type(body) ~= "string" then return U.notify("fetch failed") end
    local ids = jobIdsFrom(body)
    U.log("i", "shared url -> " .. #ids .. " jobId(s)")
    if #ids == 0 then return U.notify("no jobId in that url") end
    return M.hopTo(ids[1], "shared jobId")
end

-- post our find so other instances / people can jump to it
function M.post()
    local url = C.get("webhook")
    if not url or url == "" then return end
    local phase, mirage = M.status()
    if not (mirage or phase == "Full Moon" or phase == "Next Night") then return end
    local now = os.clock()
    if now < state.nextPost then return end
    state.nextPost = now + 60
    pcall(function()
        request({
            Url = url, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode({
                content = string.format("jobId=%s  place=%d  moon=%s  mirage=%s",
                    game.JobId, game.PlaceId, phase, tostring(mirage)),
            }),
        })
    end)
    U.log("i", "posted jobId to webhook")
end

-- tick ---------------------------------------------------------------------
function M.tick(_U, _C)
    local phase, mirage, full = M.status()
    state.lastMoon, state.lastMirage = phase, mirage

    local wantMirage = C.get("MirageHop")
    local wantMoon = C.get("MoonHop")
    if not (wantMirage or wantMoon) then return end

    local hit = (wantMirage and mirage) or (wantMoon and full)
    if hit then
        state.found = state.found + 1
        if state.found == 1 then
            U.notify((mirage and "MIRAGE ISLAND" or "FULL MOON") .. " - stopping hops")
            U.log("i", string.format("found on hop %d: moon=%s mirage=%s", state.hops, phase, tostring(mirage)))
        end
        M.post()
        return
    end

    local max = C.get("HopMax") or 40
    if state.hops >= max then
        if C.get("HopAutoOff") then
            C.set("MirageHop", false)
            C.set("MoonHop", false)
            U.notify("hop limit reached (" .. max .. ") - switching off")
        end
        return
    end
    if os.clock() < state.nextHop then return end
    if not U.alive() then return end
    M.hop()
end

function M.reset()
    state.hops, state.found, state.nextHop = 0, 0, 0
end

function M.stats() return state.hops, state.found, state.lastMoon, state.lastMirage end

return M
