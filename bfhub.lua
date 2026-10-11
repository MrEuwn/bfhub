--[[
  BFHub - Blox Fruits script hub (Delta / mobile friendly, no UI library).
  Paste this file into Delta and execute. Modules are fetched from GitHub raw
  so you only ever paste this one file. A Home tab reports load status.

  Module convention: a file either returns a value directly (util, ui, quests)
  or a factory function `return function(U, UI, C, win) ... end` (config,
  features). run() executes the chunk, then calls the result if it is a
  function, so both styles work with one code path.
]]
local REPO   = "MrEuwn/bfhub"
local BRANCH = "main"
local BASE   = ("https://raw.githubusercontent.com/%s/%s/src/"):format(REPO, BRANCH)

local function fetch(name)
    local last
    for _ = 1, 3 do
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

local U, e1 = run("util");   assert(U,  "util: "   .. tostring(e1))
local UI, e2 = run("ui");    assert(UI, "ui: "     .. tostring(e2))
local C, e3 = run("config", U); assert(C, "config: " .. tostring(e3))

-- quest table (level range -> quest name/number/mob/giver position)
local quests, eq = run("quests")
C.quests = (type(quests) == "table") and quests or {}

-- sensible defaults on first run (auto haki, kill aura, tween travel, fly)
C.set("useTween", true)
C.set("fly", true)
C.set("auraRadius", 30)
C.set("hitbox", 60)

local win = UI.new("Raf's Personal Script")
C.win = win

-- Home tab reports exactly what loaded and any error, so a broken module is
-- never a silent empty window.
local home = win:tab("Home")
local st = home:section("Load Status")
local info = st:paragraph("loading modules...")
local lines = {}
local function say(s) table.insert(lines, s); info.Text = table.concat(lines, "\n") end
say("Raf's Personal Script - Sea " .. tostring(U.currentSea()) .. "  Lv." .. tostring(U.level()))
say("quests: " .. tostring(#C.quests) .. " rows")
say("repo: " .. REPO .. "@" .. BRANCH)

local ORDER = { "farm", "combat", "fruit", "esp", "teleport", "sea", "bones", "boss", "mastery", "stats", "debug", "log", "shop", "codes", "misc" }
local mods, loaded = {}, {}
for _, name in ipairs(ORDER) do
    local ok, mod = U.safe("load:" .. name, run, name, U, UI, C, win)
    if ok and type(mod) == "table" then
        mod.name = name
        table.insert(mods, mod)
        table.insert(loaded, name)
        say("[ok] " .. name)
    else
        say(("[x] %s - %s"):format(name, tostring(mod)))
    end
end
say(("done: %d/%d modules"):format(#loaded, #ORDER))

task.spawn(function()
    while true do
        for _, m in ipairs(mods) do
            if m.tick then U.safe("tick:" .. tostring(m.name), m.tick) end
        end
        task.wait(tonumber(C.get("tickRate")) or 0.1)
    end
end)

-- STOP TWEEN kill-switch (HoHo-style): one tap disables smooth travel.
do
    local pg = U.player:WaitForChild("PlayerGui")
    local sg = pg:FindFirstChild("RPS")
    if sg then
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(96, 34); b.Position = UDim2.new(1, -104, 0.5, 40)
        b.BackgroundColor3 = Color3.fromRGB(150, 45, 45); b.Text = "STOP TWEEN"
        b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.GothamBold
        b.TextSize = 12; b.BorderSizePixel = 0; b.Active = true; b.Draggable = true
        b.Parent = sg
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = b
        b.MouseButton1Click:Connect(function()
            C.set("useTween", false)
            U.notify("Tween stopped (travel is now instant)")
        end)
    end
end

U.notify("Raf's Personal Script loaded - " .. #loaded .. "/" .. #ORDER .. " modules")
