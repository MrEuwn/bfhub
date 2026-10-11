--[[ util.lua - services, remotes, world finders, travel, combat, logging.
     Everything game-version-sensitive lives here so one fix propagates. ]]

local U = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local LP = Players.LocalPlayer

U.Players, U.RS, U.LP, U.TweenService = Players, RS, LP, TweenService

-- sea detection: PlaceId is authoritative, island count is the fallback for subplaces
U.sea = ({ [2753915549] = 1, [4442272183] = 2, [7449423635] = 3 })[game.PlaceId]
if not U.sea then
    local w = workspace:FindFirstChild("_WorldOrigin")
    local loc = w and w:FindFirstChild("Locations")
    local n = loc and #loc:GetChildren() or 0
    U.sea = n > 30 and 3 or (n > 15 and 2 or 1)
end

local remotes = RS:WaitForChild("Remotes", 30)
U.CommF = remotes and remotes:WaitForChild("CommF_", 30)
U.CommE = remotes and remotes:FindFirstChild("CommE")
U.Redeem = remotes and remotes:FindFirstChild("Redeem")

U.angle = 0
U.logs = {}
U.TeleportPos = nil       -- last travel target, used to gate attacks by distance
U.block = nil             -- the invisible part the camera tweens (Redz travel method)
local MAXLOG = 250

function U.log(level, msg)
    msg = tostring(msg)
    table.insert(U.logs, "[" .. level .. "] " .. msg)
    if #U.logs > MAXLOG then table.remove(U.logs, 1) end
    if level == "x" then warn("[RPS] " .. msg) else print("[RPS] " .. msg) end
    if U.onLog then pcall(U.onLog, level, msg) end
end

-- pcall with traceback. NEVER use "..." inside the closure: pack it first.
function U.safe(label, fn, ...)
    local a = table.pack(...)
    local ok, res = xpcall(function()
        return fn(table.unpack(a, 1, a.n))
    end, debug.traceback)
    if not ok then U.log("x", label .. " -> " .. tostring(res)) end
    return ok, res
end

function U.notify(text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Raf's Personal Script", Text = tostring(text), Duration = dur or 4,
        })
    end)
end

-- remotes ------------------------------------------------------------------
function U.remote(remote, invoke, ...)
    if not remote then return false, "no remote" end
    local a = table.pack(...)
    local ok, res = pcall(function()
        if invoke then return remote:InvokeServer(table.unpack(a, 1, a.n)) end
        return remote:FireServer(table.unpack(a, 1, a.n))
    end)
    return ok, res
end

-- FireRemote: CommF_ is the action remote for gear/style/stats/quests
function U.F(name, ...)
    local ok, res = U.remote(U.CommF, true, name, ...)
    if not ok then U.log("x", "CommF " .. tostring(name) .. ": " .. tostring(res)) end
    return res
end

-- character ----------------------------------------------------------------
function U.char() return LP.Character end
function U.root()
    local c = LP.Character
    return c and (c.PrimaryPart or c:FindFirstChild("HumanoidRootPart"))
end
function U.hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
function U.alive()
    local h = U.hum()
    return h ~= nil and h.Health > 0
end
function U.level()
    local d = LP:FindFirstChild("Data")
    local l = d and d:FindFirstChild("Level")
    return l and l.Value or 0
end
function U.data(name)
    local d = LP:FindFirstChild("Data")
    local v = d and d:FindFirstChild(name)
    return v and v.Value
end

-- travel -------------------------------------------------------------------
function U.tp(cf)
    local r = U.root()
    if r then r.CFrame = cf end
end

-- The camera follows the player's PrimaryPart, so travel must be a tween on a
-- part the camera is watching, not a raw CFrame set (Redz method).
function U.ensureBlock()
    if U.block and U.block.Parent then return U.block end
    local b = Instance.new("Part")
    b.Name = "RPSBlock"
    b.Size = Vector3.new(1, 1, 1)
    b.Transparency = 1
    b.CanCollide = false
    b.Anchored = true
    b.Parent = workspace
    U.block = b
    return b
end

function U.tweenTo(cf, speed)
    local r = U.root()
    if not r then return end
    U.TeleportPos = cf.Position
    local dist = (r.Position - cf.Position).Magnitude
    if dist < 1 then r.CFrame = cf return end
    if not (U.C and U.C.get("tween")) then r.CFrame = cf return end
    local b = U.ensureBlock()
    -- ponytail: straight hop, no pathfinding. Add an A* module only if the server
    -- starts rejecting cross-island travel.
    if dist > 450 and U.C.get("portalhop") then
        r.CFrame = cf
        b.CFrame = cf
    else
        local t = TweenService:Create(b, TweenInfo.new(dist / (speed or 170), Enum.EasingStyle.Linear), { CFrame = cf })
        U.tween = t
        t:Play()
    end
end

function U.stopTween()
    if U.tween then pcall(function() U.tween:Cancel() end) end
    U.tween = nil
end

-- mobs ---------------------------------------------------------------------
-- Enemies are NOT children of workspace: they live in workspace.Enemies.
function U.baseName(n)
    return (n:gsub("%s*%[Lv%.%s*%d+%]%s*$", ""))
end

local function isMob(m)
    if not m:IsA("Model") then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    local r = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
    if not (h and r) or h.Health <= 0 then return false end
    if Players:GetPlayerFromCharacter(m) then return false end
    return true
end

function U.mobs(name)
    local out = {}
    for _, f in ipairs({ workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Characters"), RS }) do
        if f then
            for _, m in ipairs(f:GetChildren()) do
                if isMob(m) and (name == nil or U.baseName(m.Name) == name) then
                    table.insert(out, m)
                end
            end
        end
    end
    return out
end

function U.nearestMob(name, limit)
    local r = U.root()
    if not r then return nil end
    local best, bd = nil, limit or 2500
    for _, m in ipairs(U.mobs(name)) do
        local p = U.mobPos(m)
        if p then
            local d = (p.Position - r.Position).Magnitude
            if d <= bd then best, bd = m, d end
        end
    end
    return best, bd
end

function U.mobPos(m)
    return m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
end

-- Orbit instead of parking: a parked player stops crossing the hitbox.
function U.orbit(mob, height)
    U.angle = (U.angle + 5) % 360
    local a = math.rad(U.angle)
    local p = U.mobPos(mob)
    return p.CFrame + Vector3.new(math.sin(a) * 35, height or 20, math.cos(a) * 35)
end

-- attacking ----------------------------------------------------------------
-- A bare VirtualUser click does NOT damage. The hit must go through the combat
-- framework: zero its cooldowns + widen hitboxMagnitude, then send a real M1.
-- Because it is a genuine M1 the server credits the kill (money/exp).
local function controller()
    local ok, ac = pcall(function()
        local ups = debug.getupvalues(require(LP.PlayerScripts.CombatFramework))
        for i = 1, 5 do
            local u = ups[i]
            if type(u) == "table" and u.activeController then return u.activeController end
        end
    end)
    return ok and ac or nil
end

function U.fastAttack()
    pcall(function()
        local ac = controller()
        if not ac then return end
        ac.increment = 3
        ac.timeToNextAttack = 0
        ac.timeToNextBlock = 0
        ac.focusStart = 0
        ac.attacking = false
        ac.blocking = false
        if ac.humanoid then ac.humanoid.AutoRotate = true end
        ac.currentAttackTrack = 0
    end)
    pcall(function() sethiddenproperty(LP, "SimulationRadius", math.huge) end)
end

function U.attack(range)
    local c, hum = U.char(), U.hum()
    if not (c and hum and hum.Health > 0) then return end
    hum.Sit = false
    local stun = c:FindFirstChild("Stun")
    if stun then stun.Value = 0 end
    pcall(function()
        local ac = controller()
        if ac then ac.hitboxMagnitude = range or 60 end
    end)
    local vp = workspace.CurrentCamera.ViewportSize
    local vu = game:GetService("VirtualUser")
    vu:CaptureController()
    vu:Button1Down(Vector2.new(vp.X / 2, vp.Y / 2))
    vu:Button1Up(Vector2.new(vp.X / 2, vp.Y / 2))
end

-- Net attack (the game's own remotes). Only fire with a real weapon equipped.
function U.netAttack(range)
    local c = U.char()
    local mod = RS:FindFirstChild("Modules")
    local net = mod and mod:FindFirstChild("Net")
    if not (c and net) then return end
    local atk = net:FindFirstChild("RE/RegisterAttack")
    local hit = net:FindFirstChild("RE/RegisterHit")
    local root = U.root()
    if not (atk and hit and root) then return end
    local tool = c:FindFirstChildOfClass("Tool")
    local tip = tool and tool:FindFirstChild("ToolTip")
    if not (tip and ({ Melee = true, Sword = true, ["Blox Fruit"] = true, Gun = true })[tip.Value]) then return end
    local hits = {}
    for _, m in ipairs(U.mobs()) do
        local p = U.mobPos(m)
        if p and (p.Position - root.Position).Magnitude <= (range or 60) then
            table.insert(hits, { m, m:FindFirstChild("Head") or p })
        end
    end
    if #hits == 0 then return end
    atk:FireServer(0)
    hit:FireServer(table.remove(hits, 1)[2], hits, nil, "")
end

-- Bring mob: pin to a fixed anchor and blow up the hitbox, or the M1 sweeps over it.
function U.bringMobs(name)
    local r = U.root()
    if not r then return end
    local anchor = r.CFrame * CFrame.new(0, 0, -6)
    pcall(function() sethiddenproperty(LP, "SimulationRadius", math.huge) end)
    for _, m in ipairs(U.mobs(name)) do
        local p, h = U.mobPos(m), m:FindFirstChildOfClass("Humanoid")
        if p and h then
            p.Size = Vector3.new(60, 60, 60)
            p.CanCollide = false
            p.Transparency = 1
            h.PlatformStand = true
            h.WalkSpeed = 0
            h.JumpPower = 0
            p.CFrame = anchor
        end
    end
end

-- hover: without it gravity drops the player mid-farm and the loop jitters.
function U.hover(on)
    local r = U.root()
    if not r then return end
    local bv = r:FindFirstChild("RPSHover")
    if on then
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "RPSHover"
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bv.Velocity = Vector3.zero
            bv.Parent = r
        end
    elseif bv then
        bv:Destroy()
    end
end

function U.noclip(on)
    local c = U.char()
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = not on end
    end
end

function U.equip(cat)
    local hum, c = U.hum(), U.char()
    if not (hum and c) then return end
    local function want(tool)
        local tip = tool:FindFirstChild("ToolTip")
        return tip ~= nil and tip.Value == cat
    end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and want(t) then return end
    end
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        if t:IsA("Tool") and want(t) then hum:EquipTool(t) return end
    end
end

-- haki is a state flag, not fire-and-forget --------------------------------
function U.autoHaki()
    local c = U.char()
    if not c then return end
    if not c:FindFirstChild("HasBuso") then U.F("Buso") end
    U.F("Ken")
end

-- tool helpers -------------------------------------------------------------
function U.findTool(name)
    local c = U.char()
    for _, src in ipairs({ c, U.LP.Backpack }) do
        if src then
            for _, t in ipairs(src:GetChildren()) do
                if t:IsA("Tool") and t.Name == name then return t end
            end
        end
    end
    return nil
end

function U.hasTool(name) return U.findTool(name) ~= nil end

function U.equipTool(name)
    local hum, t = U.hum(), U.findTool(name)
    if hum and t and t.Parent ~= U.char() then hum:EquipTool(t) end
end

-- mastery of a tool by name (the game exposes it on the tool's own value)
function U.mastery(name)
    local t = U.findTool(name)
    if not t then return nil end
    local m = t:FindFirstChild("Mastery") or t:FindFirstChild("Level")
    return m and m.Value or nil
end

-- nearest dropped fruit on the ground
function U.nearestFruit()
    local r = U.root()
    if not r then return nil end
    local best, bd = nil, 2500
    for _, p in ipairs(workspace:GetChildren()) do
        if p:IsA("Tool") or string.find(p.Name, "Fruit") then
            local d = (p.Position - r.Position).Magnitude
            if d < bd then best, bd = p, d end
        end
    end
    return best
end

return U
