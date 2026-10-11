--[[ discord.lua - read jobIds out of a Discord channel (the "RODISCORD HOP FARM" idea).

     How it works: the REST endpoint returns recent messages as JSON, so the jobId
     someone posted is just a UUID inside `content`.
         GET https://discord.com/api/v10/channels/<channel_id>/messages?limit=100
         Authorization: Bot <token>
     A bot needs VIEW_CHANNEL + READ_MESSAGE_HISTORY in that channel. Message Content
     Intent is only required for the gateway/websocket, not for REST.

     Why this can work from an executor at all: requests go out from the DEVICE's IP.
     The 403 Cloudflare block everyone hits is HttpService from Roblox's own game
     servers, which Discord blocks.

     The token is typed into the UI at runtime and lives only in the config table -
     it is never written into this file or the repo. Treat it as a password: a bot
     token can read every channel that bot can see. Do not paste it into a public
     repo, and rotate it if it leaks. Do not use a user token (self-bot): that breaks
     Discord's ToS and gets the account banned. ]]

local M = {}
local U, C

local API = "https://discord.com/api/v10"
local JOBID = "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x"
local state = { lastId = nil, nextPoll = 0, hits = 0, errors = 0, lastInfo = "" }

function M.init(_U, _C)
    U, C = _U, _C
end

local function token()
    local t = C.get("DcToken")
    if not t or t == "" then return nil end
    return t
end

-- one REST call; returns (ok, decodedTableOrErrorText, statusCode)
local function api(path)
    local t = token()
    if not t then return false, "no token set", 0 end
    local url = API .. path
    local body, status
    local ok = pcall(function()
        local res = request({
            Url = url,
            Method = "GET",
            Headers = {
                ["Authorization"] = "Bot " .. t,
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "DiscordBot (https://github.com/MrEuwn/bfhub, 1.0)",
            },
        })
        if type(res) == "table" then
            body, status = res.Body, res.StatusCode
        else
            body = res
        end
    end)
    if not ok or type(body) ~= "string" then return false, "request failed", status or 0 end
    if status == 401 then return false, "bad token (401)", status end
    if status == 403 then return false, "bot lacks View Channel / Read Message History (403)", status end
    if status == 404 then return false, "channel not found (404)", status end
    if status == 429 then return false, "rate limited (429)", status end
    local ok2, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(body)
    end)
    if not ok2 then return false, "bad json", status or 0 end
    return true, data, status or 200
end

function M.me()
    local ok, data = api("/users/@me")
    if not ok then return U.notify("discord: " .. tostring(data)) end
    U.notify("bot: " .. tostring(data.username))
    U.log("i", "discord bot ok: " .. tostring(data.username) .. " (" .. tostring(data.id) .. ")")
    return data
end

-- newest message that contains a jobId and (if set) every word of the filter
function M.messages(limit)
    local ch = C.get("DcChannel")
    if not ch or ch == "" then return nil, "no channel id set" end
    return api("/channels/" .. tostring(ch) .. "/messages?limit=" .. tostring(limit or 50))
end

local function matches(content)
    local filter = C.get("DcFilter")
    if not filter or filter == "" then return true end
    content = string.lower(content)
    for word in string.gmatch(string.lower(filter), "[^%s,]+") do
        if not string.find(content, word, 1, true) then return false end
    end
    return true
end

function M.find()
    local ok, data, status = M.messages(50)
    if not ok then return nil, data end
    local out = {}
    for _, msg in ipairs(data or {}) do
        local content = tostring(msg.content or "")
        local id = content:match(JOBID)
        if id and matches(content) then
            table.insert(out, { id = id, msgId = tostring(msg.id), at = tostring(msg.timestamp or ""), text = content })
        end
    end
    return out, nil
end

-- a quick look: how many jobIds, and the newest one
function M.test()
    local list, err = M.find()
    if not list then return U.notify("discord: " .. tostring(err)) end
    state.lastInfo = #list .. " jobId(s) in the last 50 messages"
    U.notify(state.lastInfo)
    U.log("i", "discord: " .. state.lastInfo)
    for i = 1, math.min(#list, 3) do
        U.log("i", string.format("  %s  %s  %s", list[i].id, list[i].at, list[i].text:sub(1, 60)))
    end
    return list
end

function M.hopNewest()
    local list, err = M.find()
    if not list then return U.notify("discord: " .. tostring(err)) end
    if #list == 0 then return U.notify("no jobId in that channel (filter: " .. tostring(C.get("DcFilter")) .. ")") end
    local pick = list[1]
    state.lastId = pick.msgId
    state.hits = state.hits + 1
    U.notify("discord jobId: " .. pick.id:sub(1, 8) .. "...")
    local TS = game:GetService("TeleportService")
    pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, pick.id, U.LP) end)
end

-- auto: poll the channel, hop to a jobId we have not used yet
function M.tick()
    if not C.get("DcAuto") then return end
    if not token() then return end
    if os.clock() < state.nextPoll then return end
    state.nextPoll = os.clock() + (C.get("DcPoll") or 10)
    if not U.alive() then return end
    local list, err = M.find()
    if not list then
        state.errors = state.errors + 1
        if state.errors <= 3 then U.log("x", "discord poll: " .. tostring(err)) end
        return
    end
    if #list == 0 then return end
    local pick = list[1]
    if pick.msgId == state.lastId then return end      -- already used
    state.lastId = pick.msgId
    state.hits = state.hits + 1
    U.notify("discord hop " .. state.hits .. ": " .. pick.id:sub(1, 8))
    local TS = game:GetService("TeleportService")
    pcall(function() TS:TeleportToPlaceInstance(game.PlaceId, pick.id, U.LP) end)
end

function M.stats() return state.hits, state.errors, state.lastInfo end
function M.reset() state.lastId, state.hits, state.errors, state.nextPoll = nil, 0, 0, 0 end

return M
