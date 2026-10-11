--[[ Raf's Personal Script - BFHub (keyless, open source, no obfuscation).

     Paste ONE line in Delta while Blox Fruits is open:
       loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()

     RightCtrl toggles the UI; a floating button restores it when hidden.
     This is a cheat - use an alt account.
]]

local BASE = "https://raw.githubusercontent.com/MrEuwn/bfhub/main/"

-- some builds read game.GameId; executors often leave it empty
pcall(function()
    if game.GameId == nil or game.GameId == 0 then
        local universe = ({
            [2753915549] = 994732206,   -- Sea 1
            [4442272183] = 994732206,   -- Sea 2
            [7449423635] = 994732206,   -- Sea 3
        })[game.PlaceId]
        if universe then game.GameId = universe end
    end
end)

-- raw.githubusercontent.com serves transient 404s right after a push: retry
local function fetch(path)
    local url, err = BASE .. path, nil
    for _ = 1, 3 do
        local ok, body = pcall(game.HttpGet, game, url)
        if ok and type(body) == "string" and #body > 0 then return body end
        err = body
        task.wait(0.6)
    end
    error("fetch failed: " .. path .. " (" .. tostring(err) .. ")")
end

local mods, report, handles = {}, {}, {}

-- One uniform loader: a module may return a table (util/config/ui) OR a factory
-- function that needs the deps (features). Mixing the two is the classic trap -
-- calling the chunk once on a factory yields a function, not a table, and the
-- entry then dies AFTER the GUI is already drawn (empty window, no error).
local function load(name, deps)
    local ok, res = pcall(function()
        local chunk = loadstring(fetch("src/" .. name .. ".lua"), name)
        local v = chunk()
        if type(v) == "function" then
            local a = table.pack(deps)
            v = v(table.unpack(a, 1, a.n))
        end
        return v
    end)
    if ok and res ~= nil then
        table.insert(report, "[ok] " .. name)
        return res
    end
    table.insert(report, "[x] " .. name .. " -> " .. tostring(res))
    warn("[RPS] " .. name .. ": " .. tostring(res))
    return nil
end

local U = load("util")
if not U then
    return game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Raf's Personal Script", Text = "util.lua failed - see console", Duration = 8,
    })
end
local C = load("config")
local D = load("data")     -- dependency of farm/pages/extras, passed as deps

U.modules = report
function U.logText()
    return table.concat(U.logs, "\n")
end
U.C = C
U.log("i", "loading, executor " .. tostring(identifyexecutor()) .. ", sea " .. tostring(U.sea) .. ", level " .. U.level())

local UI = load("ui")
local win
if UI then
    local ok, err = pcall(function() win = UI.new(U, C) end)
    if not ok then
        win = nil
        U.log("x", "UI.new: " .. tostring(err))
    end
end

-- feature modules: each returns a module with optional init()/tick()
for _, name in ipairs({ "farm", "quests", "moon", "extras" }) do
    local m = load(name)
    if m then
        U.safe("init " .. name, function()
            if m.init then m.init(U, C, UI, win, { D = D, mods = handles }) end
        end)
        table.insert(mods, m)
        handles[name] = m
    end
end

-- tab modules build their UI only; they are not ticked
if win then
    for _, name in ipairs({ "home", "pages" }) do
        local m = load(name)
        if m and m.init then U.safe("init " .. name, function() m.init(U, C, UI, win, { D = D, mods = handles }) end) end
    end
    win:select("Home")
end

-- one scheduler for every feature module. mods must be an ARRAY: ipairs stops at
-- the first nil, so a name-keyed dict would silently tick nothing.
task.spawn(function()
    while win == nil or win.gui.Parent ~= nil do
        for _, m in ipairs(mods) do
            if m.tick then U.safe("tick " .. tostring(m), m.tick, U, C) end
        end
        task.wait(C.get("lowend") and 0.25 or 0.15)
    end
end)

U.notify("loaded - RightCtrl to toggle")
U.log("i", "loaded, " .. #mods .. " feature modules, " .. #(win and win.order or {}) .. " tabs")
