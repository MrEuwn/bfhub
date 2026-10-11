--[[ util.lua - services, remotes, world finders, logging.
     Everything game-version-sensitive lives here so one fix propagates. ]]

local U = {}

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local LP = Players.LocalPlayer

U.Players, U.RS, U.LP, U.TweenService = Players, RS, LP, TweenService

local remotes = RS:WaitForChild("Remotes", 30)
U.CommF = remotes and remotes:WaitForChild("CommF_", 30)
U.CommE = remotes and remotes:FindFirstChild("CommE")
U.Redeem = remotes and remotes:FindFirstChild("Redeem")

U.angle = 0
U.logs = {}
local MAXLOG = 250

function U.log(level, msg)
    msg = tostring(msg)
    table.insert(U.logs, "[" .. level .. "] " .. msg)
    if #U.logs > MAXLOG then table.remove(U.logs, 1) end
    if level == "x" then warn("[BFHub] " .. msg) else print("[BFHub] " .. msg) end
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
            Title = "BFHub", Text = tostring(text), Duration = dur or 4,
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

function U.F(name, ...)  -- CommF_:InvokeServer
    local ok, res = U.remote(U.CommF, true, name, ...)
    if not ok then U.log("x", "CommF " .. tostring(name) .. ": " .. tostring(res)) end
    return res
end

-- character ----------------------------------------------------------------
function U.char() return LP.Character end
function U.root()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
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

function U.tp(cf)
    local r = U.root()
    if r then r.CFrame = cf end
end

function U.tweenTo(cf, speed)
    local r = U.root()
    if not r then return end
    local dist = (r.Position - cf.Position).Magnitude
    if dist < 1 then r.CFrame = cf return end
    local t = TweenService:Create(r, TweenInfo.new(dist / (speed or 170), Enum.EasingStyle.Linear), { CFrame = cf })
    U.tween = t
    t:Play()
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
    local r = m:FindFirstChild("HumanoidRootPart")
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

function U.nearestMob(name)
    local r = U.root()
    if not r then return nil end
    local best, bd
    for _, m in ipairs(U.mobs(name)) do
        local d = (m.HumanoidRootPart.Position - r.Position).Magnitude
        if not bd or d < bd then best, bd = m, d end
    end
    return best, bd
end

-- Orbit instead of parking: a parked player stops crossing the hitbox.
function U.orbit(mob, height)
    U.angle = (U.angle + 5) % 360
    local a = math.rad(U.angle)
    return mob.HumanoidRootPart.CFrame + Vector3.new(math.sin(a) * 35, height or 20, math.cos(a) * 35)
end

-- attacking ----------------------------------------------------------------
-- A bare VirtualUser click does NOT damage. The hit must go through the combat
-- framework: zero its cooldowns + widen hitboxMagnitude, then send a real M1.
-- Because it is a genuine M1 the server credits the kill (money/exp).
local function controller()
    local ok, ac = pcall(function()
        local ups = debug.getupvalues(require(U.LP.PlayerScripts.CombatFramework))
        for i = 1, 5 do
            local u = ups[i]
            if type(u) == "table" and u.activeController then return u.activeController end
        end
    end)
    return ok and ac or nil
end

function U.attack(range)
    local c, hum = U.char(), U.hum()
    if not (c and hum and hum.Health > 0) then return end
    hum.Sit = false
    local stun = c:FindFirstChild("Stun")
    if stun then stun.Value = 0 end
    pcall(function()
        local ac = controller()
        if ac then
            ac.attacking = false
            ac.blocking = false
            ac.timeToNextAttack = tick() - 1
            ac.timeToNextBlock = 0
            ac.increment = 3
            ac.hitboxMagnitude = range or 60
        end
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
        local hrp = m:FindFirstChild("HumanoidRootPart")
        if hrp and (hrp.Position - root.Position).Magnitude <= (range or 60) then
            table.insert(hits, { m, m:FindFirstChild("Head") or hrp })
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
        local hrp, h = m:FindFirstChild("HumanoidRootPart"), m:FindFirstChildOfClass("Humanoid")
        if hrp and h then
            hrp.Size = Vector3.new(60, 60, 60)
            hrp.CanCollide = false
            hrp.Transparency = 1
            h.PlatformStand = true
            h.WalkSpeed = 0
            h.JumpPower = 0
            hrp.CFrame = anchor
        end
    end
end

-- hover: without it gravity drops the player mid-farm and the loop jitters.
function U.hover(on)
    local r = U.root()
    if not r then return end
    local bv = r:FindFirstChild("BFHubHover")
    if on then
        if not bv then
            bv = Instance.new("BodyVelocity")
            bv.Name = "BFHubHover"
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

return U
