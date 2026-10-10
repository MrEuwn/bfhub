--[[
  BFHub - Blox Fruits script hub (Delta / mobile friendly, no UI library).
  Paste this file into Delta and execute. Modules are fetched from GitHub raw
  so you only ever paste this one file. A Home tab reports load status.
]]
local REPO   = "MrEuwn/bfhub"
local BRANCH = "main"
local BASE   = ("https://raw.githubusercontent.com/%s/%s/src/"):format(REPO, BRANCH)

local function fetch(name)
    local last
    for attempt = 1, 3 do
        local ok, src = pcall(function() return game:HttpGet(BASE .. name .. ".lua") end)
        if ok and type(src) == "string" and #src > 0 then
            local fn, err = loadstring(src, "BFHub:" .. name)
            if fn then return fn end
            return nil, "compile: " .. tostring(err)
        end
        last = src
        task.wait(0.6)
    end
    return nil, "HttpGet failed (3 tries): " .. tostring(last)
end

local U  = assert(fetch("util"),   "util required")()
local UI = assert(fetch("ui"),     "ui required")()
local C  = assert(fetch("config"), "config required")(U)

local win = UI.new("BFHub")
C.win = win

-- Home tab shows exactly what loaded and any error, so a broken module is
-- never a silent empty window.
local home = win:tab("Home")
local st = home:section("Load Status")
local info = st:paragraph("loading modules...")
local lines = {}
local function say(s) table.insert(lines, s); info.Text = table.concat(lines, "\n") end
say("BFHub - Sea " .. tostring(U.currentSea()))
say("repo: " .. REPO .. "@" .. BRANCH)

local ORDER = { "farm", "combat", "fruit", "esp", "teleport", "sea", "shop", "misc" }
local mods, loaded = {}, {}
for _, name in ipairs(ORDER) do
    local f, ferr = fetch(name)
    if not f then
        say(("[x] %s - %s"):format(name, tostring(ferr)))
    else
        local ok, mod = pcall(f, U, UI, C, win)
        if ok and type(mod) == "table" then
            mod.name = name
            table.insert(mods, mod)     -- array: scheduler uses ipairs
            table.insert(loaded, name)
            say("[ok] " .. name)
        else
            say(("[x] %s - runtime: %s"):format(name, tostring(mod)))
        end
    end
end
say(("done: %d/%d modules"):format(#loaded, #ORDER))

-- one central scheduler thread (default 10 Hz) -> lightest option on mobile
task.spawn(function()
    while true do
        for _, m in ipairs(mods) do
            if m.tick then pcall(m.tick) end
        end
        task.wait(tonumber(C.get("tickRate")) or 0.1)
    end
end)

U.notify("BFHub loaded - " .. #loaded .. "/" .. #ORDER .. " modules")
