--[[
  Raf's Personal Script - entry point.

  The feature set is the RECOVERED Blox Fruits hub (deobfuscated from a Luraph
  v15 protected build of "Speed Hub X v5.5.0"). It carries the original engine -
  quest farming, bring-mob, mastery, chests, sea events, ESP, raids, race
  upgrades - and runs against our own lightweight UI (uilib.lua) instead of the
  author's obfuscated UI library.

  Stripped from the original: the key system, the luarmor loader, and a telemetry
  webhook that phoned home to the author's repo.

  Paste one line in Delta:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/MrEuwn/bfhub/main/bfhub.lua"))()

  Module convention: a file either returns a value directly (util, uilib, funcs,
  quests) or a factory `return function(...) ... end` (config, hub, extras).
]]

local REPO   = "MrEuwn/bfhub"
local BRANCH = "main"
local BASE   = ("https://raw.githubusercontent.com/%s/%s/src/"):format(REPO, BRANCH)

local function fetch(name)
    local last
    for _ = 1, 3 do
        local ok, src = pcall(function() return game:HttpGet(BASE .. name .. ".lua") end)
        if ok and type(src) == "string" and #src > 0 then
            local fn, err = loadstring(src, "RPS:" .. name)
            if fn then return fn end
            return nil, "compile: " .. tostring(err)
        end
        last = src
        task.wait(0.6)
    end
    return nil, "HttpGet failed (3 tries): " .. tostring(last)
end

local function run(name, ...)
    local chunk, ferr = fetch(name)
    if not chunk then return nil, ferr end
    local ok, v = pcall(chunk)
    if not ok then return nil, "exec: " .. tostring(v) end
    if type(v) == "function" then
        local args = table.pack(...)
        local ok2, r = pcall(v, table.unpack(args, 1, args.n))
        if not ok2 then return nil, "init: " .. tostring(r) end
        return r
    end
    return v
end

-- Base -----------------------------------------------------------------------
local U, e1 = run("util");      assert(U, "util: "   .. tostring(e1))
local C, e2 = run("config", U); assert(C, "config: " .. tostring(e2))

-- Quest table feeds our own auto-farm-level extra. The recovered hub ships its
-- own quest logic, so this stays optional.
local quests = run("quests")
C.quests = (type(quests) == "table") and quests or {}

-- Defaults: the recovered hub owns its own config keys; these are ours.
C.set("useTween", true)
C.set("fly", true)
C.set("hitbox", 120)
C.set("auraRadius", 120)
C.set("bring", true)
C.set("bringDist", 300)
C.set("weapon", "Melee")

-- UI shim (replaces the author's obfuscated Lib_5.5.0.lua) + FuncsV3 adapter.
local UILib, e3 = run("uilib"); assert(UILib, "uilib: " .. tostring(e3))
local lib = UILib.new()

local Funcs, e4 = run("funcs"); assert(Funcs, "funcs: " .. tostring(e4))

U.notify("Raf's Personal Script - starting", 3)

-- The recovered hub (owns the full feature set and its own window) ------------
local hubwin, err = run("hub", U, nil, C, nil, lib, Funcs)
if type(hubwin) ~= "table" then
    warn("[RPS] hub failed: " .. tostring(err))
    U.notify("Hub error - check console", 6)
end

-- Our extra modules use a tiny win:tab(...):section(...) API; map it onto the
-- hub's window so everything lands in one place.
local win
if type(hubwin) == "table" and type(hubwin.CreateTab) == "function" then
    win = {
        tab = function(_, name)
            local t = hubwin:CreateTab({ Name = name })
            return { section = function(_, sname) return t:AddSection(sname) end }
        end,
    }
end

-- Extra modules (our own additions; the hub covers the rest) ------------------
local ORDER = { "log" }
local mods, loaded = {}, {}
for _, name in ipairs(ORDER) do
    local o, mod = U.safe("load:" .. name, run, name, U, nil, C, win)
    if o and type(mod) == "table" then
        mod.name = name
        table.insert(mods, mod)
        table.insert(loaded, name)
    end
end

task.spawn(function()
    while true do
        for _, m in ipairs(mods) do
            if m.tick then U.safe("tick:" .. tostring(m.name), m.tick) end
        end
        task.wait(tonumber(C.get("tickRate")) or 0.1)
    end
end)

U.notify("Raf's Personal Script loaded - hub + " .. #loaded .. " extras", 4)
