--[[
  BFHub - Blox Fruits script hub (Delta / mobile friendly, no UI library).
  Paste this file into Delta and execute.
  Modules are fetched from GitHub raw so you only ever paste this one file.
]]
local REPO   = "MrEuwn/bfhub"
local BRANCH = "main"
local BASE   = ("https://raw.githubusercontent.com/%s/%s/src/"):format(REPO, BRANCH)

local function fetch(name)
    local ok, src = pcall(function() return game:HttpGet(BASE .. name .. ".lua") end)
    if not ok then warn(("[BFHub] cannot fetch %s: %s"):format(name, tostring(src))) return nil end
    local fn, err = loadstring(src, name)
    if not fn then warn(("[BFHub] compile error in %s: %s"):format(name, tostring(err))) return nil end
    return fn
end

local U  = assert(fetch("util"),   "util required")()
local UI = assert(fetch("ui"),     "ui required")()
local C  = assert(fetch("config"), "config required")(U)

local win = UI.new("BFHub")
C.win = win

local modules, loaded = {}, {}
for _, name in ipairs({ "farm", "combat", "fruit", "esp", "teleport", "sea", "shop", "misc" }) do
    local f = fetch(name)
    if f then
        local ok, mod = pcall(f, U, UI, C, win)
        if ok and type(mod) == "table" then
            mod.name = name
            modules[name] = mod
            table.insert(loaded, name)
        else
            warn(("[BFHub] module %s failed: %s"):format(name, tostring(mod)))
        end
    end
end

-- one central scheduler thread (10 Hz default) -> lightest option on mobile
task.spawn(function()
    while true do
        for _, m in ipairs(modules) do
            if m.tick then pcall(m.tick) end
        end
        task.wait(tonumber(C.get("tickRate")) or 0.1)
    end
end)

U.notify("BFHub loaded - " .. #loaded .. " modules")
U.log("loaded: " .. table.concat(loaded, ", "))
