-- Offline harness. The standalone luau sandbox has no io, so sources are embedded.
-- Checks the contract the entry relies on, then drives init()/tick() for real.
local FILES = {}
FILES["src/util.lua"] = [==[
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

return U
]==]
FILES["src/config.lua"] = [==[
--[[ config.lua - flat state store. Toggles are plain booleans/numbers/strings
     keyed by name, shared by the UI rows and the feature modules. ]]

local C = {}

C.values = {
    -- farm
    farm = false,
    autoquest = true,
    farmtool = "Melee",
    farmdistance = 20,
    orbit = true,
    bring = true,
    bringdist = 250,
    autoclick = true,
    clickdelay = 0.18,
    -- travel
    tween = true,
    tweenspeed = 170,
    portalhop = false,
    hover = true,
    noclip = true,
    -- combat
    method = "m1",
    fastattack = true,
    attackdist = 60,
    killaura = false,
    aura = 120,
    autobuso = true,
    autoken = true,
    healthskill = 25,
    -- mastery / stats
    automastery = false,
    masterytool = "Blox Fruit",
    masteryvalue = 300,
    autostat = false,
    stat = "Melee",
    statpoints = 1,
    -- races / misc
    autoracev2 = false,
    heal = false,
    esp = false,
    espplayers = false,
    lowend = false,
    antiafk = true,
    walkonwater = false,
    webhook = "",
}

function C.get(k) return C.values[k] end

function C.set(k, v)
    C.values[k] = v
    if C.onChange then pcall(C.onChange, k, v) end
end

function C.toggle(k)
    C.set(k, not C.get(k))
    return C.get(k)
end

return C
]==]
FILES["src/data.lua"] = [==[
--[[ data.lua - tables ported from the Redz V2 feature set (values as that source had them).
     Regenerate rather than hand-edit: a wrong CFrame teleports the player into the void. ]]

local D = {}

-- quests[sea] = { {minLv, maxLv, mob, questName, questNum, questCF, monCF|nil, waypoints|nil, team|nil} }
D.quests = {}
D.quests[1] = {
    { 1, 9, "Bandit", "BanditQuest1", 1, CFrame.new(1059, 17, 1546), nil, {CFrame.new(943, 45, 1562), CFrame.new(1115, 45, 1619), CFrame.new(1265, 45, 1606)}, "Pirates" },
    { 1, 9, "Trainee", "MarineQuest", 1, CFrame.new(-2708, 25, 2103), nil, {CFrame.new(-2754, 50, 2063), CFrame.new(-2950, 70, 2240)}, "Pirates" },
    { 10, 14, "Monkey", "JungleQuest", 1, CFrame.new(-1598, 37, 153), nil, {CFrame.new(-1524, 50, 37), CFrame.new(-1424, 50, 216), CFrame.new(-1554, 50, 359), CFrame.new(-1772, 50, 78), CFrame.new(-1715, 50, -61), CFrame.new(-1594, 50, -45)}, nil },
    { 15, 29, "The Gorilla King", "JungleQuest", 3, CFrame.new(-1598, 37, 153), CFrame.new(-1128, 6, -451), {CFrame.new(-1128, 40, -451), CFrame.new(-1313, 40, -546)}, nil },
    { 15, 29, "Gorilla", "JungleQuest", 2, CFrame.new(-1598, 37, 153), nil, {CFrame.new(-1128, 40, -451), CFrame.new(-1313, 40, -546)}, nil },
    { 30, 39, "Pirate", "BuggyQuest1", 1, CFrame.new(-1140, 4, 3829), nil, {CFrame.new(-1262, 40, 3905), CFrame.new(-1167, 40, 3942)}, nil },
    { 40, 59, "Bobby", "BuggyQuest1", 3, CFrame.new(-1140, 4, 3829), CFrame.new(-1131, 14, 4080), {CFrame.new(-976, 55, 4304), CFrame.new(-1196, 55, 4287), CFrame.new(-1363, 55, 4162)}, nil },
    { 40, 59, "Brute", "BuggyQuest1", 2, CFrame.new(-1140, 4, 3829), nil, {CFrame.new(-976, 55, 4304), CFrame.new(-1196, 55, 4287), CFrame.new(-1363, 55, 4162)}, nil },
    { 60, 74, "Desert Bandit", "DesertQuest", 1, CFrame.new(897, 6, 4389), CFrame.new(938, 6, 4470), nil, nil },
    { 75, 89, "Desert Officer", "DesertQuest", 2, CFrame.new(897, 6, 4389), CFrame.new(1546, 14, 4384), nil, nil },
    { 90, 99, "Snow Bandit", "SnowQuest", 1, CFrame.new(1385, 87, -1298), CFrame.new(1303, 106, -1441), {CFrame.new(1362, 120, -1531), CFrame.new(1357, 120, -1381), CFrame.new(1228, 120, -1354)}, nil },
    { 100, 119, "Yeti", "SnowQuest", 3, CFrame.new(1385, 87, -1298), CFrame.new(1185, 106, -1518), {CFrame.new(1243, 140, -1437), CFrame.new(1072, 140, -1458), CFrame.new(1076, 140, -1621), CFrame.new(1209, 140, -1644), CFrame.new(1252, 140, -1480)}, nil },
    { 100, 119, "Snowman", "SnowQuest", 2, CFrame.new(1385, 87, -1298), CFrame.new(1185, 106, -1518), {CFrame.new(1243, 140, -1437), CFrame.new(1072, 140, -1458), CFrame.new(1076, 140, -1621), CFrame.new(1209, 140, -1644), CFrame.new(1252, 140, -1480)}, nil },
    { 120, 149, "Vice Admiral", "MarineQuest2", 2, CFrame.new(-5035, 29, 4326), CFrame.new(-4807, 21, 4360), nil, nil },
    { 120, 149, "Chief Petty Officer", "MarineQuest2", 1, CFrame.new(-5035, 29, 4326), CFrame.new(-4807, 21, 4360), nil, nil },
    { 150, 174, "Sky Bandit", "SkyQuest", 1, CFrame.new(-4844, 718, -2621), CFrame.new(-4956, 296, -2901), nil, nil },
    { 175, 189, "Dark Master", "SkyQuest", 2, CFrame.new(-4844, 718, -2621), CFrame.new(-5268, 392, -2213), nil, nil },
    { 190, 209, "Prisoner", "PrisonerQuest", 1, CFrame.new(5306, 2, 477), CFrame.new(5288, 2, 470), nil, nil },
    { 210, 249, "Swan", "ImpelQuest", 3, CFrame.new(5191, 4, 692), CFrame.new(5230, 4, 749), nil, nil },
    { 210, 249, "Chief Warden", "ImpelQuest", 2, CFrame.new(5191, 4, 692), CFrame.new(5230, 4, 749), nil, nil },
    { 210, 249, "Warden", "ImpelQuest", 1, CFrame.new(5191, 4, 692), CFrame.new(5230, 4, 749), nil, nil },
    { 210, 249, "Dangerous Prisoner", "PrisonerQuest", 2, CFrame.new(5306, 2, 477), CFrame.new(5282, 2, 1052), nil, nil },
    { 250, 274, "Toga Warrior", "ColosseumQuest", 1, CFrame.new(-1581, 7, -2982), CFrame.new(-1897, 7, -2796), nil, nil },
    { 275, 299, "Gladiator", "ColosseumQuest", 2, CFrame.new(-1581, 7, -2982), CFrame.new(-1327, 59, -3231), {CFrame.new(-1268, 30, -2996), CFrame.new(-1472, 30, -3194), CFrame.new(-1387, 30, -3438), CFrame.new(-1198, 30, -3508)}, nil },
    { 300, 324, "Military Soldier", "MagmaQuest", 1, CFrame.new(-5319, 12, 8515), nil, {CFrame.new(-5335, 46, 8638), CFrame.new(-5512, 30, 8366)}, nil },
    { 325, 374, "Magma Admiral", "MagmaQuest", 3, CFrame.new(-5319, 12, 8515), CFrame.new(-5694, 18, 8735), nil, nil },
    { 325, 374, "Military Spy", "MagmaQuest", 2, CFrame.new(-5319, 12, 8515), CFrame.new(-5791, 97, 8834), nil, nil },
    { 375, 399, "Fishman Warrior", "FishmanQuest", 1, CFrame.new(61122, 18, 1567), nil, {CFrame.new(60998, 50, 1534), CFrame.new(60880, 50, 1675), CFrame.new(60785, 50, 1552), CFrame.new(60923, 60, 1262)}, nil },
    { 400, 449, "Fishman Lord", "FishmanQuest", 3, CFrame.new(61122, 18, 1567), CFrame.new(61350, 31, 1095), {CFrame.new(61866, 55, 1655), CFrame.new(62043, 55, 1510), CFrame.new(61812, 55, 1254)}, nil },
    { 400, 449, "Fishman Commando", "FishmanQuest", 2, CFrame.new(61122, 18, 1567), nil, {CFrame.new(61866, 55, 1655), CFrame.new(62043, 55, 1510), CFrame.new(61812, 55, 1254)}, nil },
    { 450, 474, "God's Guard", "SkyExp1Quest", 1, CFrame.new(-4720, 846, -1951), nil, {CFrame.new(-4641, 880, -1902), CFrame.new(-4781, 880, -1817)}, nil },
    { 475, 524, "Wysper", "SkyExp1Quest", 3, CFrame.new(-7861, 5545, -381), CFrame.new(-7927, 5551, -637), {CFrame.new(-7741, 5580, -395), CFrame.new(-7591, 5580, -466), CFrame.new(-7643, 5580, -608)}, nil },
    { 475, 524, "Shanda", "SkyExp1Quest", 2, CFrame.new(-7861, 5545, -381), nil, {CFrame.new(-7741, 5580, -395), CFrame.new(-7591, 5580, -466), CFrame.new(-7643, 5580, -608)}, nil },
    { 525, 549, "Royal Squad", "SkyExp2Quest", 1, CFrame.new(-7903, 5636, -1412), nil, {CFrame.new(-7727, 5650, -1410), CFrame.new(-7522, 5650, -1499)}, nil },
    { 525, 624, "Thunder God", "SkyExp2Quest", 3, CFrame.new(-7903, 5636, -1412), CFrame.new(-7751, 5607, -2315), {CFrame.new(-7894, 5640, -1629), CFrame.new(-7678, 5640, -1696), CFrame.new(-7672, 5640, -1903), CFrame.new(-7925, 5640, -1854)}, nil },
    { 525, 624, "Royal Soldier", "SkyExp2Quest", 2, CFrame.new(-7903, 5636, -1412), nil, {CFrame.new(-7894, 5640, -1629), CFrame.new(-7678, 5640, -1696), CFrame.new(-7672, 5640, -1903), CFrame.new(-7925, 5640, -1854)}, nil },
    { 625, 649, "Galley Pirate", "FountainQuest", 1, CFrame.new(5258, 39, 4052), nil, {CFrame.new(5391, 70, 4023), CFrame.new(5780, 70, 3969)}, nil },
    { 650, 2525, "Cyborg", "FountainQuest", 3, CFrame.new(5258, 39, 4052), CFrame.new(6138, 10, 3939), {CFrame.new(5985, 70, 4790), CFrame.new(5472, 70, 4887)}, nil },
    { 650, 2525, "Galley Captain", "FountainQuest", 2, CFrame.new(5258, 39, 4052), nil, {CFrame.new(5985, 70, 4790), CFrame.new(5472, 70, 4887)}, nil },
}
D.quests[2] = {
    { 700, 724, "Raider", "Area1Quest", 1, CFrame.new(-427, 73, 1835), nil, {CFrame.new(-614, 90, 2240), CFrame.new(-894, 90, 2275), CFrame.new(-872, 90, 2481), CFrame.new(-552, 90, 2528)}, nil },
    { 725, 774, "Diamond", "Area1Quest", 3, CFrame.new(-427, 73, 1835), CFrame.new(-1569, 199, -31), {CFrame.new(-867, 110, 1621), CFrame.new(-1047, 110, 1779), CFrame.new(-1025, 110, 1087), CFrame.new(-1204, 110, 1195)}, nil },
    { 725, 774, "Mercenary", "Area1Quest", 2, CFrame.new(-427, 73, 1835), nil, {CFrame.new(-867, 110, 1621), CFrame.new(-1047, 110, 1779), CFrame.new(-1025, 110, 1087), CFrame.new(-1204, 110, 1195)}, nil },
    { 775, 799, "Swan Pirate", "Area2Quest", 1, CFrame.new(635, 73, 919), nil, {CFrame.new(778, 110, 1129), CFrame.new(1018, 110, 1128), CFrame.new(1020, 110, 1366), CFrame.new(1016, 110, 1115)}, nil },
    { 800, 874, "Jeremy", "Area2Quest", 3, CFrame.new(635, 73, 919), CFrame.new(2316, 449, 787), {CFrame.new(882, 110, -49), CFrame.new(723, 110, 212), CFrame.new(473, 110, 108), CFrame.new(-115, 110, 39)}, nil },
    { 800, 874, "Factory Staff", "Area2Quest", 2, CFrame.new(635, 73, 919), nil, {CFrame.new(882, 110, -49), CFrame.new(723, 110, 212), CFrame.new(473, 110, 108), CFrame.new(-115, 110, 39)}, nil },
    { 875, 899, "Marine Lieutenant", "MarineQuest3", 1, CFrame.new(-2441, 73, -3219), nil, {CFrame.new(-2552, 110, -3050), CFrame.new(-2860, 110, -3089), CFrame.new(-3114, 110, -2947), CFrame.new(-2864, 110, -2679)}, nil },
    { 900, 949, "Fajita", "MarineQuest3", 3, CFrame.new(-2441, 73, -3219), CFrame.new(-2086, 73, -4208), {CFrame.new(-1695, 110, -3299), CFrame.new(-1953, 110, -3165), CFrame.new(-2144, 110, -3341)}, nil },
    { 900, 949, "Marine Captain", "MarineQuest3", 2, CFrame.new(-2441, 73, -3219), nil, {CFrame.new(-1695, 110, -3299), CFrame.new(-1953, 110, -3165), CFrame.new(-2144, 110, -3341)}, nil },
    { 950, 974, "Zombie", "ZombieQuest", 1, CFrame.new(-5495, 48, -794), nil, {CFrame.new(-5715, 90, -917), CFrame.new(-5534, 90, -942), CFrame.new(-5445, 90, -806), CFrame.new(-5485, 90, -663), CFrame.new(-5730, 90, -590), CFrame.new(-5816, 90, -756)}, nil },
    { 975, 999, "Vampire", "ZombieQuest", 2, CFrame.new(-5495, 48, -794), nil, {CFrame.new(-6027, 50, -1130), CFrame.new(-6248, 50, -1281), CFrame.new(-6120, 50, -1450), CFrame.new(-5951, 50, -1520), CFrame.new(-5803, 50, -1360)}, nil },
    { 1000, 1049, "Snow Trooper", "SnowMountainQuest", 1, CFrame.new(607, 401, -5371), nil, {CFrame.new(445, 440, -5175), CFrame.new(523, 440, -5484), CFrame.new(699, 440, -5612)}, nil },
    { 1050, 1099, "Winter Warrior", "SnowMountainQuest", 2, CFrame.new(607, 401, -5371), nil, {CFrame.new(1224, 460, -5332), CFrame.new(1404, 460, -5323), CFrame.new(1258, 460, -5220), CFrame.new(1145, 460, -5077), CFrame.new(1022, 460, -5139)}, nil },
    { 1100, 1124, "Lab Subordinate", "IceSideQuest", 1, CFrame.new(-6061, 16, -4904), nil, {CFrame.new(-5941, 50, -4322), CFrame.new(-5765, 50, -4304), CFrame.new(-5608, 50, -4445), CFrame.new(-5683, 50, -4629)}, nil },
    { 1125, 1174, "Smoke Admiral", "IceSideQuest", 3, CFrame.new(-6061, 16, -4904), CFrame.new(-5078, 24, -5352), {CFrame.new(-6306, 50, -5752), CFrame.new(-6161, 50, -5979), CFrame.new(-6518, 50, -5795), CFrame.new(-6535, 50, -5640)}, nil },
    { 1125, 1174, "Horned Warrior", "IceSideQuest", 2, CFrame.new(-6061, 16, -4904), nil, {CFrame.new(-6306, 50, -5752), CFrame.new(-6161, 50, -5979), CFrame.new(-6518, 50, -5795), CFrame.new(-6535, 50, -5640)}, nil },
    { 1175, 1199, "Magma Ninja", "FireSideQuest", 1, CFrame.new(-5430, 16, -5298), nil, {CFrame.new(-5233, 60, -6227), CFrame.new(-5194, 60, -6031), CFrame.new(-5651, 60, -5854)}, nil },
    { 1200, 1249, "Lava Pirate", "FireSideQuest", 2, CFrame.new(-5430, 16, -5298), nil, {CFrame.new(-4955, 60, -4836), CFrame.new(-5119, 60, -4634), CFrame.new(-5389, 60, -4616), CFrame.new(-5342, 60, -4897)}, nil },
    { 1250, 1274, "Ship Deckhand", "ShipQuest1", 1, CFrame.new(1033, 125, 32909), nil, {CFrame.new(1185, 180, 32979), CFrame.new(1204, 180, 33174), CFrame.new(615, 180, 33169), CFrame.new(638, 180, 32962)}, nil },
    { 1275, 1299, "Ship Engineer", "ShipQuest1", 2, CFrame.new(1033, 125, 32909), nil, {CFrame.new(809, 80, 33090), CFrame.new(751, 80, 32957), CFrame.new(927, 80, 32724), CFrame.new(1040, 80, 32915), CFrame.new(1034, 80, 33058)}, nil },
    { 1300, 1324, "Ship Steward", "ShipQuest2", 1, CFrame.new(973, 125, 33245), nil, {CFrame.new(838, 160, 33408), CFrame.new(1026, 160, 33510)}, nil },
    { 1325, 1349, "Ship Officer", "ShipQuest2", 2, CFrame.new(973, 125, 33245), nil, {CFrame.new(1238, 220, 33148), CFrame.new(1220, 220, 33426), CFrame.new(622, 220, 33435), CFrame.new(593, 220, 33172)}, nil },
    { 1350, 1374, "Arctic Warrior", "FrostQuest", 1, CFrame.new(5668, 28, -6484), nil, {CFrame.new(5836, 80, -6257), CFrame.new(6132, 80, -6098), CFrame.new(6275, 80, -6237), CFrame.new(6095, 80, -6349)}, nil },
    { 1375, 1424, "Awakened Ice Admiral", "FrostQuest", 3, CFrame.new(5668, 28, -6484), CFrame.new(6473, 297, -6944), {CFrame.new(5700, 80, -6724), CFrame.new(5542, 80, -6898), CFrame.new(5512, 80, -6641)}, nil },
    { 1375, 1424, "Snow Lurker", "FrostQuest", 2, CFrame.new(5668, 28, -6484), nil, {CFrame.new(5700, 80, -6724), CFrame.new(5542, 80, -6898), CFrame.new(5512, 80, -6641)}, nil },
    { 1425, 1449, "Sea Soldier", "ForgottenQuest", 1, CFrame.new(-3056, 240, -10145), nil, {CFrame.new(-2583, 80, -9821), CFrame.new(-2830, 80, -9809), CFrame.new(-3271, 80, -9729), CFrame.new(-3486, 80, -9813)}, nil },
    { 1450, 2525, "Tide Keeper", "ForgottenQuest", 3, CFrame.new(-3056, 240, -10145), CFrame.new(-3711, 77, -11469), {CFrame.new(-3339, 290, -10412), CFrame.new(-3518, 290, -10419), CFrame.new(-3536, 290, -10607), CFrame.new(-3345, 280, -10667)}, nil },
    { 1450, 2525, "Water Fighter", "ForgottenQuest", 2, CFrame.new(-3056, 240, -10145), nil, {CFrame.new(-3339, 290, -10412), CFrame.new(-3518, 290, -10419), CFrame.new(-3536, 290, -10607), CFrame.new(-3345, 280, -10667)}, nil },
}
D.quests[3] = {
    { 1500, 1524, "Pirate Millionaire", "PiratePortQuest", 1, CFrame.new(-291, 44, 5580), nil, {CFrame.new(-44, 70, 5623), CFrame.new(-219, 70, 5546), CFrame.new(-574, 70, 5496)}, nil },
    { 1525, 1574, "Stone", "PiratePortQuest", 3, CFrame.new(-291, 44, 5580), CFrame.new(-1049, 40, 6791), {CFrame.new(219, 105, 6018), CFrame.new(-24, 105, 6155), CFrame.new(-312, 105, 6028)}, nil },
    { 1525, 1574, "Pistol Billionaire", "PiratePortQuest", 2, CFrame.new(-291, 44, 5580), nil, {CFrame.new(219, 105, 6018), CFrame.new(-24, 105, 6155), CFrame.new(-312, 105, 6028)}, nil },
    { 1575, 1599, "Dragon Crew Warrior", "AmazonQuest", 1, CFrame.new(5834, 51, -1103), nil, {CFrame.new(5992, 90, -1581), CFrame.new(6364, 90, -1512), CFrame.new(6501, 90, -1104), CFrame.new(6612, 90, -938), CFrame.new(6393, 90, -939)}, nil },
    { 1600, 1624, "Dragon Crew Archer", "AmazonQuest", 2, CFrame.new(5834, 51, -1103), nil, {CFrame.new(6472, 370, -151), CFrame.new(6547, 370, -51), CFrame.new(6539, 410, 72), CFrame.new(6737, 410, 249), CFrame.new(6768, 410, 390), CFrame.new(6625, 410, 371)}, nil },
    { 1625, 1649, "Female Islander", "AmazonQuest2", 1, CFrame.new(5448, 602, 748), nil, {CFrame.new(4836, 740, 928), CFrame.new(4708, 770, 911), CFrame.new(4672, 790, 695), CFrame.new(4657, 800, 498), CFrame.new(4575, 810, 281)}, nil },
    { 1650, 1699, "Island Empress", "AmazonQuest2", 3, CFrame.new(5448, 602, 748), CFrame.new(5730, 602, 199), {CFrame.new(4784, 660, 155), CFrame.new(4662, 660, -57), CFrame.new(4869, 660, -178), CFrame.new(5056, 660, -267), CFrame.new(5332, 660, -166)}, nil },
    { 1650, 1699, "Giant Islander", "AmazonQuest2", 2, CFrame.new(5448, 602, 748), nil, {CFrame.new(4784, 660, 155), CFrame.new(4662, 660, -57), CFrame.new(4869, 660, -178), CFrame.new(5056, 660, -267), CFrame.new(5332, 660, -166)}, nil },
    { 1700, 1724, "Marine Commodore", "MarineTreeIsland", 1, CFrame.new(2180, 29, -6738), nil, {CFrame.new(3156, 120, -7837), CFrame.new(2904, 120, -7863), CFrame.new(2606, 120, -7745), CFrame.new(2409, 120, -7874), CFrame.new(2269, 120, -7416), CFrame.new(2413, 120, -7232), CFrame.new(2284, 120, -6911)}, nil },
    { 1725, 1774, "Kilo Admiral", "MarineTreeIsland", 3, CFrame.new(2180, 29, -6738), CFrame.new(2889, 424, -7233), {CFrame.new(3205, 120, -6742), CFrame.new(3345, 120, -6649), CFrame.new(3776, 210, -7254), CFrame.new(3879, 220, -7083), CFrame.new(3887, 210, -6841), CFrame.new(3546, 210, -6809), CFrame.new(3448, 210, -7014), CFrame.new(3504, 210, -7230)}, nil },
    { 1725, 1774, "Marine Rear Admiral", "MarineTreeIsland", 2, CFrame.new(2180, 29, -6738), nil, {CFrame.new(3205, 120, -6742), CFrame.new(3345, 120, -6649), CFrame.new(3776, 210, -7254), CFrame.new(3879, 220, -7083), CFrame.new(3887, 210, -6841), CFrame.new(3546, 210, -6809), CFrame.new(3448, 210, -7014), CFrame.new(3504, 210, -7230)}, nil },
    { 1775, 1799, "Fishman Raider", "DeepForestIsland3", 1, CFrame.new(-10581, 332, -8758), nil, {CFrame.new(-10550, 380, -8574), CFrame.new(-10860, 380, -8459), CFrame.new(-10578, 380, -8331), CFrame.new(-10377, 380, -8238), CFrame.new(-10147, 380, -8216), CFrame.new(-10234, 380, -8454)}, nil },
    { 1800, 1824, "Fishman Captain", "DeepForestIsland3", 2, CFrame.new(-10581, 332, -8758), nil, {CFrame.new(-10764, 380, -8799), CFrame.new(-10844, 380, -9030), CFrame.new(-11160, 380, -9166), CFrame.new(-11073, 380, -8846), CFrame.new(-11043, 380, -8619)}, nil },
    { 1825, 1849, "Forest Pirate", "DeepForestIsland", 1, CFrame.new(-13233, 332, -7626), nil, {CFrame.new(-13335, 380, -7660), CFrame.new(-13138, 380, -7713), CFrame.new(-13298, 380, -7876), CFrame.new(-13512, 380, -7983), CFrame.new(-13632, 380, -7815)}, nil },
    { 1850, 1899, "Captain Elephant", "DeepForestIsland", 3, CFrame.new(-13233, 332, -7626), CFrame.new(-13393, 319, -8423), {CFrame.new(-13844, 520, -7016), CFrame.new(-13710, 520, -6856), CFrame.new(-13482, 520, -6985), CFrame.new(-13224, 580, -6806)}, nil },
    { 1850, 1899, "Mythological Pirate", "DeepForestIsland", 2, CFrame.new(-13233, 332, -7626), nil, {CFrame.new(-13844, 520, -7016), CFrame.new(-13710, 520, -6856), CFrame.new(-13482, 520, -6985), CFrame.new(-13224, 580, -6806)}, nil },
    { 1900, 1924, "Jungle Pirate", "DeepForestIsland2", 1, CFrame.new(-12682, 391, -9901), nil, {CFrame.new(-12166, 380, -10375), CFrame.new(-12303, 380, -10639), CFrame.new(-11904, 380, -10469), CFrame.new(-11636, 380, -10511), CFrame.new(-11735, 380, -10687), CFrame.new(-11937, 380, -10713)}, nil },
    { 1925, 1974, "Musketeer Pirate", "DeepForestIsland2", 3, CFrame.new(-12682, 391, -9901), CFrame.new(5241, 23, 129), {CFrame.new(-13098, 450, -9831), CFrame.new(-13222, 450, -9621), CFrame.new(-13530, 450, -9760), CFrame.new(-13455, 450, -9940)}, nil },
    { 1925, 1974, "Musketeer Pirate", "DeepForestIsland2", 2, CFrame.new(-12682, 391, -9901), nil, {CFrame.new(-13098, 450, -9831), CFrame.new(-13222, 450, -9621), CFrame.new(-13530, 450, -9760), CFrame.new(-13455, 450, -9940)}, nil },
    { 1975, 1999, "Reborn Skeleton", "HauntedQuest1", 1, CFrame.new(-9481, 142, 5565), nil, {CFrame.new(-8680, 190, 5852), CFrame.new(-8879, 190, 5900), CFrame.new(-8865, 190, 6100), CFrame.new(-8774, 170, 6169), CFrame.new(-8649, 190, 6071)}, nil },
    { 200, 2024, "Living Zombie", "HauntedQuest1", 2, CFrame.new(-9481, 142, 5565), nil, {CFrame.new(-10104, 200, 5739), CFrame.new(-10078, 200, 5953), CFrame.new(-10195, 200, 6139), CFrame.new(-10252, 200, 5973)}, nil },
    { 2025, 2049, "Demonic Soul", "HauntedQuest2", 1, CFrame.new(-9515, 172, 6078), nil, {CFrame.new(-9275, 210, 6166), CFrame.new(-9379, 210, 6076), CFrame.new(-9565, 210, 6201), CFrame.new(-9671, 210, 6096)}, nil },
    { 2050, 2074, "Posessed Mummy", "HauntedQuest2", 2, CFrame.new(-9515, 172, 6078), nil, {CFrame.new(-9442, 60, 6304), CFrame.new(-9427, 60, 6148), CFrame.new(-9598, 60, 6121), CFrame.new(-9733, 60, 6119), CFrame.new(-9735, 60, 6336), CFrame.new(-9618, 60, 6323)}, nil },
    { 2075, 2099, "Peanut Scout", "NutsIslandQuest", 1, CFrame.new(-2104, 38, -10194), nil, {CFrame.new(-1870, 100, -10225), CFrame.new(-2143, 100, -10106)}, nil },
    { 2100, 2124, "Peanut President", "NutsIslandQuest", 2, CFrame.new(-2104, 38, -10194), nil, {CFrame.new(-2005, 100, -10585), CFrame.new(-2293, 88, -10512)}, nil },
    { 2125, 2149, "Ice Cream Chef", "IceCreamIslandQuest", 1, CFrame.new(-818, 66, -10964), nil, {CFrame.new(-501, 100, -10883), CFrame.new(-763, 100, -10834), CFrame.new(-990, 100, -11085)}, nil },
    { 2150, 2199, "Cake Queen", "IceCreamIslandQuest", 3, CFrame.new(-818, 66, -10964), CFrame.new(-710, 382, -11150), {CFrame.new(-690, 100, -11350), CFrame.new(-534, 100, -11284), CFrame.new(-720, 180, -11162)}, nil },
    { 2150, 2199, "Ice Cream Commander", "IceCreamIslandQuest", 2, CFrame.new(-818, 66, -10964), nil, {CFrame.new(-690, 100, -11350), CFrame.new(-534, 100, -11284), CFrame.new(-720, 180, -11162)}, nil },
    { 2200, 2224, "Cookie Crafter", "CakeQuest1", 1, CFrame.new(-2023, 38, -12028), nil, {CFrame.new(-2332, 90, -12049), CFrame.new(-2468, 90, -12121), CFrame.new(-2401, 90, -12224), CFrame.new(-2296, 90, -12114)}, nil },
    { 2225, 2249, "Cake Guard", "CakeQuest1", 2, CFrame.new(-2023, 38, -12028), nil, {CFrame.new(-1514, 90, -12422), CFrame.new(-1455, 90, -12244), CFrame.new(-1674, 90, -12206), CFrame.new(-1707, 90, -12360)}, nil },
    { 2250, 2274, "Baking Staff", "CakeQuest2", 1, CFrame.new(-1931, 38, -12840), nil, {CFrame.new(-1930, 90, -12963), CFrame.new(-1803, 90, -13115), CFrame.new(-1769, 90, -12955), CFrame.new(-1873, 90, -12755)}, nil },
    { 2275, 2299, "Head Baker", "CakeQuest2", 2, CFrame.new(-1931, 38, -12840), nil, {CFrame.new(-2123, 110, -12777), CFrame.new(-2281, 110, -12748), CFrame.new(-2317, 110, -12994), CFrame.new(-2140, 110, -12989)}, nil },
    { 2300, 2324, "Cocoa Warrior", "ChocQuest1", 1, CFrame.new(235, 25, -12199), nil, {CFrame.new(110, 80, -12245), CFrame.new(-71, 80, -12292)}, nil },
    { 2325, 2349, "Chocolate Bar Battler", "ChocQuest1", 2, CFrame.new(235, 25, -12199), nil, {CFrame.new(579, 80, -12413), CFrame.new(735, 80, -12659)}, nil },
    { 2350, 2374, "Sweet Thief", "ChocQuest2", 1, CFrame.new(150, 25, -12777), nil, {CFrame.new(-68, 80, -12692), CFrame.new(90, 80, -12519)}, nil },
    { 2375, 2399, "Candy Rebel", "ChocQuest2", 2, CFrame.new(150, 25, -12777), nil, {CFrame.new(17, 80, -12962), CFrame.new(158, 80, -12961)}, nil },
    { 2400, 2424, "Candy Pirate", "CandyQuest1", 1, CFrame.new(-1148, 14, -14446), nil, {CFrame.new(-1371, 70, -14405), CFrame.new(-1318, 70, -14715)}, nil },
    { 2425, 2449, "Snow Demon", "CandyQuest1", 2, CFrame.new(-1148, 14, -14446), nil, {CFrame.new(-836, 70, -14326), CFrame.new(-884, 70, -14708)}, nil },
    { 2450, 2474, "Isle Outlaw", "TikiQuest1", 1, CFrame.new(-16547, 56, -172), nil, {CFrame.new(-16431, 90, -223), CFrame.new(-16313, 50, -210), CFrame.new(-16160, 35, -156)}, nil },
    { 2475, 2499, "Island Boy", "TikiQuest1", 2, CFrame.new(-16547, 56, -172), nil, {CFrame.new(-16668, 70, -243), CFrame.new(-16744, 60, -195), CFrame.new(-16912, 45, -152)}, nil },
    { 2500, 2524, "Sun-kissed Warrior", "TikiQuest2", 1, CFrame.new(-16540, 56, 1051), nil, {CFrame.new(-16345, 80, 1004), CFrame.new(-16425, 77, 1059), CFrame.new(-16069, 37, 1029)}, nil },
    { 2525, 2525, "Isle Champion", "TikiQuest2", 2, CFrame.new(-16540, 56, 1051), nil, {CFrame.new(-16634, 85, 1106), CFrame.new(-16735, 60, 1075), CFrame.new(-16888, 35, 1011)}, nil },
}

-- bosses[name] = { needQuest, spawnCF, questName, questNum? }
D.bosses = {}
D.bosses["The Gorilla King"] = { true, CFrame.new(-1128, 6, -451), "JungleQuest" }
D.bosses["Bobby"] = { true, CFrame.new(-1131, 14, 4080), "BuggyQuest1" }
D.bosses["Yeti"] = { true, CFrame.new(1185, 106, -1518), "SnowQuest" }
D.bosses["Vice Admiral"] = { true, CFrame.new(-4807, 21, 4360), "MarineQuest2", 2 }
D.bosses["Swan"] = { true, CFrame.new(5230, 4, 749), "ImpelQuest" }
D.bosses["Chief Warden"] = { true, CFrame.new(5230, 4, 749), "ImpelQuest", 2 }
D.bosses["Warden"] = { true, CFrame.new(5230, 4, 749), "ImpelQuest", 1 }
D.bosses["Magma Admiral"] = { true, CFrame.new(-5694, 18, 8735), "MagmaQuest" }
D.bosses["Fishman Lord"] = { true, CFrame.new(61350, 31, 1095), "FishmanQuest" }
D.bosses["Wysper"] = { true, CFrame.new(-7927, 5551, -637), "SkyExp1Quest" }
D.bosses["Thunder God"] = { true, CFrame.new(-7751, 5607, -2315), "SkyExp2Quest" }
D.bosses["Cyborg"] = { true, CFrame.new(6138, 10, 3939), "FountainQuest" }
D.bosses["Saber Expert"] = { false, CFrame.new(-1461, 30, -51) }
D.bosses["The Saw"] = { false, CFrame.new(-690, 15, 1583) }
D.bosses["Greybeard"] = { false, CFrame.new(-4807, 21, 4360) }
D.bosses["Diamond"] = { true, CFrame.new(-1569, 199, -31), "Area1Quest" }
D.bosses["Jeremy"] = { true, CFrame.new(2316, 449, 787), "Area2Quest" }
D.bosses["Fajita"] = { true, CFrame.new(-2086, 73, -4208), "MarineQuest3" }
D.bosses["Smoke Admiral"] = { true, CFrame.new(-5078, 24, -5352), "IceSideQuest" }
D.bosses["Awakened Ice Admiral"] = { true, CFrame.new(6473, 297, -6944), "FrostQuest" }
D.bosses["Tide Keeper"] = { true, CFrame.new(-3711, 77, -11469), "ForgottenQuest" }
D.bosses["Don Swan"] = { false, CFrame.new(2289, 15, 808) }
D.bosses["Cursed Captain"] = { false, CFrame.new(912, 186, 33591) }
D.bosses["Darkbeard"] = { false, CFrame.new(3695, 13, -3599) }
D.bosses["Longma"] = { false, CFrame.new(-10218, 333, -9444) }
D.bosses["Stone"] = { true, CFrame.new(-1049, 40, 6791), "PiratePortQuest" }
D.bosses["Beautiful Pirate"] = { true, CFrame.new(5241, 23, 129), "DeepForestIsland2" }
D.bosses["Island Empress"] = { true, CFrame.new(5730, 602, 199), "AmazonQuest2" }
D.bosses["Kilo Admiral"] = { true, CFrame.new(2889, 424, -7233), "MarineTreeIsland" }
D.bosses["Captain Elephant"] = { true, CFrame.new(-13393, 319, -8423), "DeepForestIsland" }
D.bosses["Cake Queen"] = { true, CFrame.new(-710, 382, -11150), "IceCreamIslandQuest" }
D.bosses["Cake Prince"] = { false, CFrame.new(-2103, 70, -12165) }
D.bosses["rip_indra True Form"] = { false, CFrame.new(-5333, 424, -2673) }

-- these three have no GetBossQuest row in the source: spawn CFrames come from their
-- dedicated auto-kill loops (Order = Law raid boss, Soul Reaper = Hallow Essence boss)
D.bosses["Order"] = { false, CFrame.new(-6300, 16, -4997) }
D.bosses["Soul Reaper"] = { false, CFrame.new(-9529, 316, 6712) }
D.bosses["Dough King"] = D.bosses["Cake Prince"]

D.bossList = {
    [1] = { "Greybeard", "The Saw", "Saber Expert", "The Gorilla King", "Bobby", "Yeti", "Vice Admiral", "Warden", "Chief Warden", "Swan", "Magma Admiral", "Fishman Lord", "Wysper", "Thunder God", "Cyborg" },
    [2] = { "Darkbeard", "Cursed Captain", "Order", "Don Swan", "Diamond", "Jeremy", "Fajita", "Smoke Admiral", "Awakened Ice Admiral", "Tide Keeper" },
    [3] = { "Dough King", "Cake Prince", "rip_indra True Form", "Soul Reaper", "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate", "Cake Queen", "Longma" },
}

D.materials = {
}

D.fruits = {
    ["Rocket Fruit"] = "Rocket-Rocket",
    ["Spin Fruit"] = "Spin-Spin",
    ["Chop Fruit"] = "Chop-Chop",
    ["Spring Fruit"] = "Spring-Spring",
    ["Bomb Fruit"] = "Bomb-Bomb",
    ["Smoke Fruit"] = "Smoke-Smoke",
    ["Spike Fruit"] = "Spike-Spike",
    ["Flame Fruit"] = "Flame-Flame",
    ["Falcon Fruit"] = "Falcon-Falcon",
    ["Ice Fruit"] = "Ice-Ice",
    ["Sand Fruit"] = "Sand-Sand",
    ["Dark Fruit"] = "Dark-Dark",
    ["Ghost Fruit"] = "Ghost-Ghost",
    ["Diamond Fruit"] = "Diamond-Diamond",
    ["Light Fruit"] = "Light-Light",
    ["Rubber Fruit"] = "Rubber-Rubber",
    ["Barrier Fruit"] = "Barrier-Barrier",
    ["Magma Fruit"] = "Magma-Magma",
    ["Quake Fruit"] = "Quake-Quake",
    ["Buddha Fruit"] = "Buddha-Buddha",
    ["Love Fruit"] = "Love-Love",
    ["Spider Fruit"] = "Spider-Spider",
    ["Sound Fruit"] = "Sound-Sound",
    ["Phoenix Fruit"] = "Phoenix-Phoenix",
    ["Portal Fruit"] = "Portal-Portal",
    ["Rumble Fruit"] = "Rumble-Rumble",
    ["Pain Fruit"] = "Pain-Pain",
    ["Blizzard Fruit"] = "Blizzard-Blizzard",
    ["Gravity Fruit"] = "Gravity-Gravity",
    ["Mammoth Fruit"] = "Mammoth-Mammoth",
    ["T-Rex Fruit"] = "T-Rex-T-Rex",
    ["Dough Fruit"] = "Dough-Dough",
    ["Shadow Fruit"] = "Shadow-Shadow",
    ["Venom Fruit"] = "Venom-Venom",
    ["Control Fruit"] = "Control-Control",
    ["Spirit Fruit"] = "Spirit-Spirit",
    ["Dragon Fruit"] = "Dragon-Dragon",
    ["Leopard Fruit"] = "Leopard-Leopard",
    ["Kitsune Fruit"] = "Kitsune-Kitsune",
}

D.codes = {
    "NEWTROLL", "KITT_RESET", "Sub2Fer999", "Magicbus", "kittgaming", "SECRET_ADMIN", "EXP_5B", "CONTROL", "UPDATE11", "XMASEXP", "1BILLION", "ShutDownFix2", "UPD14", "STRAWHATMAINE", "TantaiGaming", "Colosseum", "Axiore", "Sub2Daigrock", "Sky Island 3", "Sub2OfficialNoobie", "SUB2NOOBMASTER123", "THEGREATACE", "Fountain City", "BIGNEWS", "FUDD10", "SUB2GAMERROBOT_EXP1", "UPD15", "2BILLION", "UPD16", "3BVISITS", "Starcodeheo", "Bluxxy", "DRAGONABUSE", "Sub2CaptainMaui", "DEVSCOOKING", "Enyu_is_Pro", "JCWK", "Starcodeheo", "Bluxxy", "fudd10_v2", "SUB2GAMERROBOT_EXP1", "Sub2NoobMaster123", "Sub2UncleKizaru", "Sub2Daigrock", "Axiore", "TantaiGaming", "StrawHatMaine"
}

-- highest row whose range contains the level ("for" is reserved, hence .at)
function D.questAt(sea, level)
    local t = D.quests[sea]
    if not t then return nil end
    for _, r in ipairs(t) do
        if level >= r[1] and level <= r[2] then return r end
    end
    return t[#t]
end

return D
]==]
FILES["src/ui.lua"] = [==[
--[[ ui.lua - raw Instance.new GUI. No UI library on purpose: a library adds
     hundreds of KB and lags mobile executors. ~400 lines, instant load. ]]

local UI = {}
UI.__index = UI

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local ACCENT = Color3.fromRGB(122, 140, 255)
local CYAN = Color3.fromRGB(120, 220, 220)
local BG = Color3.fromRGB(22, 23, 28)
local CARD = Color3.fromRGB(32, 34, 41)
local TRACK = Color3.fromRGB(52, 55, 66)
local TXT = Color3.fromRGB(232, 234, 242)
local DIM = Color3.fromRGB(150, 155, 170)

local function mk(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    i.Parent = parent
    return i
end

local function round(i, r)
    mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, i)
    return i
end

local function stroke(i, c, t)
    mk("UIStroke", { Color = c or TRACK, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, i)
    return i
end

-- one scheduler-free tween helper
local function to(inst, t, props)
    TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

function UI.new(U, C)
    local self = setmetatable({ U = U, C = C, tabs = {}, pages = {}, rows = {} }, UI)

    -- double-load guard
    local pg = U.LP:FindFirstChild("PlayerGui")
    local old = pg and pg:FindFirstChild("BFHub")
    if old then old:Destroy() end

    local gui = mk("ScreenGui", {
        Name = "BFHub", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true,
    }, pg or game:GetService("CoreGui"))
    self.gui = gui

    local main = mk("Frame", {
        Name = "Main", Size = UDim2.fromOffset(470, 340), Position = UDim2.new(0.5, -235, 0.5, -170),
        BackgroundColor3 = BG, BorderSizePixel = 0, Active = true, Draggable = true,
    }, gui)
    round(main, 12) stroke(main, TRACK)
    self.main = main

    -- header ---------------------------------------------------------------
    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = CARD, BorderSizePixel = 0 }, main)
    round(header, 12)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = CARD, BorderSizePixel = 0 }, header)

    mk("TextLabel", {
        Text = "Raf's Personal Script", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = TXT,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -120, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    mk("TextLabel", {
        Text = "BFHub - keyless", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = CYAN,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 21), Size = UDim2.new(1, -120, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local min = mk("TextButton", {
        Text = "-", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -64, 0, 6),
    }, header)
    min.MouseButton1Click:Connect(function() self:hide() end)

    local kill = mk("TextButton", {
        Text = "X", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -32, 0, 6),
    }, header)
    kill.MouseButton1Click:Connect(function() self:destroy() end)

    -- feature search -------------------------------------------------------
    local search = mk("TextBox", {
        PlaceholderText = "search...", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT,
        PlaceholderColor3 = DIM, BackgroundColor3 = BG, BorderSizePixel = 0, ClearTextOnFocus = false,
        Size = UDim2.fromOffset(96, 22), Position = UDim2.new(1, -170, 0, 9),
    }, header)
    round(search, 6) stroke(search)
    search:GetPropertyChangedSignal("Text"):Connect(function() self:filter(search.Text) end)

    -- tab rail: a ScrollingFrame, NOT a Frame - a Frame silently clips tab 10+
    local rail = mk("ScrollingFrame", {
        Size = UDim2.new(0, 124, 1, -50), Position = UDim2.fromOffset(10, 46), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = TRACK,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, rail)
    self.rail = rail

    local body = mk("ScrollingFrame", {
        Size = UDim2.new(1, -144, 1, -50), Position = UDim2.new(0, 134, 0, 46), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = ACCENT, ClipsDescendants = true,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    self.body = body

    -- floating restore button ---------------------------------------------
    local fab = mk("TextButton", {
        Name = "FAB", Text = "B", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = TXT,
        BackgroundColor3 = ACCENT, Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 16, 0.5, -26),
        Visible = false, AutoButtonColor = true,
    }, gui)
    round(fab, 26)
    fab.Draggable = true
    fab.MouseButton1Click:Connect(function() self:show() end)
    self.fab = fab

    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightControl then self:toggle() end
    end)
    return self
end

-- window state -------------------------------------------------------------
function UI:show() self.main.Visible = true self.fab.Visible = false end
function UI:hide() self.main.Visible = false self.fab.Visible = true end
function UI:toggle() self.main.Visible = not self.main.Visible self.fab.Visible = not self.main.Visible end
function UI:destroy()
    if self._onDestroy then pcall(self._onDestroy) end
    self.gui:Destroy()
end

-- tabs ---------------------------------------------------------------------
function UI:tab(name)
    if self.pages[name] then return self.pages[name] end
    local btn = mk("TextButton", {
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = DIM,
        BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 32),
        AutoButtonColor = false,
    }, self.rail)
    round(btn, 8)
    local bar = mk("Frame", {
        Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, 0, 0.2, 0),
        BackgroundColor3 = ACCENT, BorderSizePixel = 0, Visible = false,
    }, btn)
    round(bar, 2)

    local page = mk("Frame", {
        Size = UDim2.new(1, -6, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, AutomaticSize = Enum.AutomaticSize.Y,
    }, self.body)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)

    local entry = { btn = btn, bar = bar, page = page }
    self.pages[name] = entry
    btn.MouseButton1Click:Connect(function() self:select(name) end)
    if not self.current then self:select(name) end
    return page
end

function UI:select(name)
    self.current = name
    for n, e in pairs(self.pages) do
        local on = n == name
        e.page.Visible = on
        e.bar.Visible = on
        e.btn.TextColor3 = on and TXT or DIM
        e.btn.BackgroundColor3 = on and TRACK or CARD
    end
    self.body.CanvasPosition = Vector2.zero
end

-- widgets ------------------------------------------------------------------
function UI:card(page, title)
    local card = mk("Frame", {
        Size = UDim2.new(1, -6, 0, 0), BackgroundColor3 = CARD, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
    round(card, 10) stroke(card)
    mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, card)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, card)
    if title then
        mk("TextLabel", {
            Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = CYAN,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
    end
    return card
end

local function row(parent, title, caption)
    local f = mk("Frame", { Size = UDim2.new(1, 0, 0, caption and 34 or 22), BackgroundTransparency = 1 }, parent)
    mk("TextLabel", {
        Text = title, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TXT,
        BackgroundTransparency = 1, Size = UDim2.new(1, -70, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    if caption then
        mk("TextLabel", {
            Text = caption, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = DIM,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -70, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
    end
    return f
end

function UI:row(parent, title, caption)
    local f = row(parent, title, caption)
    table.insert(self.rows, { frame = f, title = string.lower(title) })
    return f
end

function UI:toggle(parent, title, caption, key)
    local f = self:row(parent, title, caption)
    local track = mk("Frame", {
        Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -42, 0, 1),
        BackgroundColor3 = self.C.get(key) and ACCENT or TRACK, BorderSizePixel = 0,
    }, f)
    round(track, 10)
    local knob = mk("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = self.C.get(key) and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, track)
    round(knob, 8)
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function()
        local on = self.C.toggle(key)
        to(track, 0.15, { BackgroundColor3 = on and ACCENT or TRACK })
        to(knob, 0.15, { Position = on and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) })
    end)
    return f
end

function UI:slider(parent, title, key, min, max, step)
    step = step or 1
    local f = self:row(parent, title .. ": " .. tostring(self.C.get(key)))
    local bar = mk("Frame", {
        Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0, 0, 0, 14),
        BackgroundColor3 = TRACK, BorderSizePixel = 0,
    }, f)
    round(bar, 4)
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, bar)
    round(fill, 4)
    local label = f:FindFirstChildOfClass("TextLabel")
    local function apply(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + (max - min) * a) / step + 0.5) * step
        self.C.set(key, v)
        fill.Size = UDim2.new(a, 0, 1, 0)
        label.Text = title .. ": " .. tostring(v)
    end
    local dragging = false
    local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, bar)
    hit.MouseButton1Down:Connect(function() dragging = true apply(UIS:GetMouseLocation().X) end)
    hit.MouseButton1Up:Connect(function() dragging = false end)
    hit.TouchLongPress:Connect(function() dragging = true end)
    UIS.InputChanged:Connect(function(i)
        local t = i.UserInputType
        if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
            apply(i.Position.X)
        end
    end)
    -- initial fill
    local v0 = self.C.get(key)
    fill.Size = UDim2.new((v0 - min) / (max - min), 0, 1, 0)
    return f
end

function UI:button(parent, title, caption, fn)
    local f = self:row(parent, title, caption)
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function() self.U.safe(title, fn) end)
    local go = mk("TextLabel", {
        Text = ">", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = ACCENT,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -22, 0, 1),
    }, f)
    return f, go
end

function UI:label(parent, text, color)
    return mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = color or DIM,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

-- dropdown: an inline popup list. A cycle button would be cheaper but a 15-item
-- boss list is unusable that way on a phone.
function UI:dropdown(parent, title, key, values)
    local f = self:row(parent, title .. ": " .. tostring(self.C.get(key)))
    local label = f:FindFirstChildOfClass("TextLabel")
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    local open = false
    local list
    btn.MouseButton1Click:Connect(function()
        if open and list then list:Destroy() list = nil open = false return end
        open = true
        list = mk("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, math.min(#values * 22 + 8, 180)), BackgroundColor3 = BG,
            BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        }, parent)
        round(list, 8) stroke(list)
        mk("UIListLayout", { Padding = UDim.new(0, 2) }, list)
        for _, v in ipairs(values) do
            local b = mk("TextButton", {
                Text = tostring(v), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT,
                BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 20),
                TextXAlignment = Enum.TextXAlignment.Left,
            }, list)
            round(b, 4)
            b.MouseButton1Click:Connect(function()
                self.C.set(key, v)
                label.Text = title .. ": " .. tostring(v)
                if list then list:Destroy() list = nil end
                open = false
            end)
        end
    end)
    return f
end

function UI:textbox(parent, title, key, placeholder)
    local f = self:row(parent, title)
    local box = mk("TextBox", {
        Text = tostring(self.C.get(key) or ""), PlaceholderText = placeholder or "",
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT, PlaceholderColor3 = DIM,
        BackgroundColor3 = BG, BorderSizePixel = 0, ClearTextOnFocus = false,
        Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0, 0, 0, 14),
    }, f)
    round(box, 5) stroke(box)
    box:GetPropertyChangedSignal("Text"):Connect(function() self.C.set(key, box.Text) end)
    return f
end

function UI:filter(q)
    q = string.lower(q or "")
    for _, r in ipairs(self.rows) do
        r.frame.Visible = q == "" or string.find(r.title, q, 1, true) ~= nil
    end
end

-- live debug panel ---------------------------------------------------------
function UI:debug(page, U, C)
    local card = self:card(page, "Debug")
    local l1 = self:label(card, "")
    local l2 = self:label(card, "")
    local t0 = os.clock()
    task.spawn(function()
        while self.gui.Parent do
            local fps = math.floor(1 / math.max(game:GetService("RunService").Heartbeat:Wait(), 1e-3))
            l1.Text = string.format("FPS %d   PING %d ms", fps, math.floor(U.LP:GetNetworkPing() * 1000))
            l2.Text = string.format("LV %d   UPTIME %d s   MOBS %d", U.level(), math.floor(os.clock() - t0), #U.mobs())
            task.wait(0.5)
        end
    end)
    return card
end

return UI
]==]
FILES["src/farm.lua"] = [==[
--[[ farm.lua - the farm loops. One scheduler calls tick(); every loop here is a
     state machine, not a task.spawn per feature, so a toggle off actually stops it. ]]

local M = {}
local D, U, C

function M.init(_U, _C, _UI, _win, deps)
    U, C, D = _U, _C, deps and deps.D
    M.quest = nil
end

local function travel(cf, speed)
    if C.get("tween") then U.tweenTo(cf, speed or C.get("tweenspeed")) else U.tp(cf) end
end

-- level -> new quest row. Accepting teleports to the giver first: the call is
-- ignored when the player is nowhere near it.
local function ensureQuest()
    local lv = U.level()
    if M.quest and lv >= M.quest[1] and lv <= M.quest[2] then return end
    local row = D and D.questAt(U.sea or 1, lv)
    if not row then return end
    M.quest = row
    local _, _, mon, nq, num, cfq = M.quest[1], M.quest[2], M.quest[3], M.quest[4], M.quest[5], M.quest[6]
    U.log("i", string.format("quest Lv%d -> %s (%s #%d)", lv, tostring(mon), tostring(nq), tonumber(num) or 1))
    travel(cfq * CFrame.new(0, 5, 0), 200)
    task.wait(C.get("tween") and 0.35 or 0.1)
    U.F("StartQuest", nq, num)
end

-- Level: accept quest -> travel to the mob -> bring -> orbit -> hit -> repeat
local function farmLevel()
    ensureQuest()
    if not M.quest then return end
    local mon, cfm, waypoints = M.quest[3], M.quest[7], M.quest[8]

    local mob = U.nearestMob(mon)
    if not mob then
        -- respawn wait: walk the recorded waypoints instead of standing still
        if waypoints and #waypoints > 0 then
            M.wp = (M.wp or 0) % #waypoints + 1
            travel(waypoints[M.wp] * CFrame.new(0, 5, 0))
        elseif cfm then
            travel(cfm * CFrame.new(0, 8, 0))
        end
        return
    end

    U.noclip(C.get("noclip"))
    U.equip(C.get("farmtool"))
    if C.get("autobuso") or C.get("autoken") then U.autoHaki() end

    local d = C.get("farmdistance")
    travel(C.get("orbit") and U.orbit(mob, d) or (U.mobPos(mob).CFrame + Vector3.new(0, d, 0)))
    U.hover(C.get("hover"))
    if C.get("bring") then U.bringMobs(mon) end

    -- clicks only land in range; skip the swing when still far away
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        if C.get("method") == "net" then U.netAttack(C.get("attackdist")) else U.attack(C.get("attackdist")) end
    end
end

-- Nearest: no quest, just kill the closest mob (or the chosen boss)
local function farmNearest()
    local mob = U.nearestMob()
    if not mob then return end
    U.noclip(C.get("noclip"))
    U.equip(C.get("farmtool"))
    if C.get("autobuso") then U.autoHaki() end
    travel(U.orbit(mob, C.get("farmdistance")))
    U.hover(C.get("hover"))
    if C.get("bring") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("attackdist"))
    end
end

-- Boss: travel to the spawn point, take the quest if the boss needs one, kill.
local function farmBoss()
    local name = C.get("bossselected")
    if not name or not D then return end
    local row = D.bosses[name]
    if not row then return end
    local needQuest, cf, qname, qnum = row[1], row[2], row[3], row[4]
    if needQuest and C.get("bossquest") and qname then U.F("StartQuest", qname, qnum or 1) end
    local mob = U.nearestMob(name)
    if not mob then travel(cf * CFrame.new(0, 8, 0)) return end
    travel(U.orbit(mob, C.get("farmdistance")))
    U.hover(C.get("hover"))
    if C.get("bring") then U.bringMobs(name) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("attackdist"))
    end
end

-- Mastery: same as level but with the chosen tool equipped
local function farmMastery()
    local tool = C.get("masterytool")
    local mob = U.nearestMob()
    if not mob then return end
    U.equip(tool)
    travel(U.orbit(mob, C.get("farmdistance")))
    U.hover(C.get("hover"))
    if C.get("bring") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("attackdist"))
    end
    if C.get("autostat") then
        local pts = U.data("Points")
        if pts and pts > 0 then U.F("AddPoint", C.get("stat"), pts) end
    end
end

function M.tick(_U, _C)
    if not U.alive() then return end
    if C.get("fastattack") then U.fastAttack() end
    if C.get("farm") then
        local mode = C.get("farmmode") or "level"
        if mode == "level" then farmLevel()
        elseif mode == "nearest" then farmNearest()
        elseif mode == "boss" then farmBoss()
        elseif mode == "mastery" then farmMastery()
        end
    end
end

return M
]==]
FILES["src/extras.lua"] = [==[
--[[ extras.lua - combat helpers, ESP, world utilities, server hop, codes, shops.
     Each block is gated on its own toggle so the scheduler stays cheap. ]]

local M = {}
local U, C, D

function M.init(_U, _C, _UI, _win, deps)
    U, C, D = _U, _C, deps and deps.D
    -- lowend touches every descendant: apply on change, not every tick
    C.onChange = function(k)
        if k == "lowend" then M.lowend() end
    end
    M.lowend()
end

-- kill aura: snap onto the cluster BEFORE swinging, a distant swing misses.
function M.aura()
    if not C.get("killaura") or not U.alive() then return end
    local mob = U.nearestMob()
    if not mob then return end
    local root = U.root()
    if root then root.CFrame = U.mobPos(mob).CFrame + Vector3.new(0, 12, 0) end
    U.equip(C.get("farmtool"))
    if C.get("method") == "net" then U.netAttack(C.get("aura")) else U.attack(C.get("aura")) end
end

-- ESP: reuse the existing tag, never destroy+recreate per tick (main mobile lag source).
local tags = {}
local function clearTags()
    for _, t in pairs(tags) do pcall(function() t:Destroy() end) end
    tags = {}
end

local function tag(m, hrp, text, color)
    local t = tags[m]
    if not t or not t.Parent then
        t = Instance.new("BillboardGui")
        t.Name = "RPSESP"
        t.Size = UDim2.fromOffset(110, 30)
        t.StudsOffset = Vector3.new(0, 3, 0)
        t.AlwaysOnTop = true
        t.Adornee = hrp
        t.Parent = hrp
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.fromScale(1, 1)
        tl.BackgroundTransparency = 1
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 12
        tl.TextStrokeTransparency = 0.3
        tl.Parent = t
        tags[m] = t
    end
    local tl = t:FindFirstChildOfClass("TextLabel")
    if tl then
        tl.Text = text
        tl.TextColor3 = color
    end
end

function M.esp()
    local want = C.get("esp")
    if not want then
        if next(tags) then clearTags() end
        return
    end
    local seen = {}
    for _, m in ipairs(U.mobs()) do
        local p = U.mobPos(m)
        if p then
            seen[m] = true
            tag(m, p, U.baseName(m.Name), Color3.fromRGB(255, 235, 120))
        end
    end
    -- players
    if C.get("espplayers") then
        for _, plr in ipairs(U.Players:GetPlayers()) do
            if plr ~= U.LP and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    seen[plr] = true
                    tag(plr, hrp, plr.Name, Color3.fromRGB(255, 120, 120))
                end
            end
        end
    end
    for k, t in pairs(tags) do
        if not seen[k] then pcall(function() t:Destroy() end) tags[k] = nil end
    end
end

-- low-end mode: what actually costs frames on mobile
local originals = {}
function M.lowend()
    if not (U and C) then return end
    local on = C.get("lowend")
    local l = game:GetService("Lighting")
    if on then
        originals.global = originals.global == nil and l.GlobalShadows or originals.global
        l.GlobalShadows = false
    elseif originals.global ~= nil then
        l.GlobalShadows = originals.global
    end
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") then
            if on then
                if originals[p] == nil then originals[p] = p.Enabled end
                p.Enabled = false
            elseif originals[p] ~= nil then
                p.Enabled = originals[p]
            end
        end
    end
end

-- anti-AFK: fires the idle event the server watches
function M.antiafk()
    if not C.get("antiafk") then return end
    local vu = game:GetService("VirtualUser")
    vu:CaptureController()
    vu:ClickButton2(Vector2.new(0, 0))
end

-- walk on water: a platform under the player while moving
function M.water()
    local on = C.get("walkonwater")
    local r = U.root()
    if not r then return end
    local p = r:FindFirstChild("RPSWater")
    if on and not p then
        p = Instance.new("Part")
        p.Name = "RPSWater"
        p.Size = Vector3.new(30, 1, 30)
        p.Anchored = true
        p.CanCollide = true
        p.Transparency = 0.7
        p.Parent = workspace
        M.waterPart = p
    end
    if M.waterPart and M.waterPart.Parent then
        M.waterPart.CFrame = CFrame.new(r.Position - Vector3.new(0, 4, 0))
        if not on then M.waterPart:Destroy() M.waterPart = nil end
    end
end

function M.tick(_U, _C)
    M.aura()
    M.esp()
    M.water()
    M.antiafk()
end

-- actions (buttons) --------------------------------------------------------
function M.serverHop()
    local Http = game:GetService("HttpService")
    local TS = game:GetService("TeleportService")
    local ok, body = pcall(function()
        return game:HttpGet(string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId))
    end)
    if not ok or not body then return U.notify("server list blocked") end
    local data = Http:JSONDecode(body)
    for _, s in ipairs(data.data or {}) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            U.notify("hopping...")
            TS:TeleportToPlaceInstance(game.PlaceId, s.id, U.LP)
            return
        end
    end
    U.notify("no free server, retrying")
end

function M.redeemCodes()
    if not U.Redeem then return U.notify("no Redeem remote") end
    local n = 0
    for _, code in ipairs(D and D.codes or {}) do
        U.remote(U.Redeem, true, code)
        n = n + 1
    end
    U.notify(n .. " codes sent")
end

-- gear/style buys are CommF_ with the name concatenated (Redz names, no spaces)
function M.buy(name)
    U.F(name)
    U.notify("sent: " .. name)
end

function M.teleportIsland()
    local w = workspace:FindFirstChild("_WorldOrigin")
    local loc = w and w:FindFirstChild("Locations")
    if not loc then return U.notify("no Locations registry") end
    local name = C.get("island")
    local island = name and loc:FindFirstChild(name)
    if not island then
        local names = {}
        for _, i in ipairs(loc:GetChildren()) do table.insert(names, i.Name) end
        U.log("i", "islands: " .. table.concat(names, ", "))
        return U.notify("pick an island in the dropdown")
    end
    local part = island.PrimaryPart or island:FindFirstChildWhichIsA("BasePart")
    if part then U.tp(part.CFrame * CFrame.new(0, 30, 0)) end
end

function M.islands()
    local w = workspace:FindFirstChild("_WorldOrigin")
    local loc = w and w:FindFirstChild("Locations")
    if not loc then return {} end
    local out = {}
    for _, i in ipairs(loc:GetChildren()) do table.insert(out, i.Name) end
    table.sort(out)
    return out
end

return M
]==]
FILES["src/pages.lua"] = [==[
--[[ pages.lua - every tab. UI only: each row writes into the shared config store
     that farm.lua / extras.lua read each tick. ]]

local M = {}
local U, C, UI, win, D

local function cycle(key, list, label)
    local cur = C.get(key)
    for i, v in ipairs(list) do
        if v == cur then
            C.set(key, list[i % #list + 1])
            return U.notify(label .. ": " .. tostring(C.get(key)))
        end
    end
    C.set(key, list[1])
    U.notify(label .. ": " .. tostring(list[1]))
end

function M.init(_U, _C, _UI, _w, deps)
    U, C, UI, win = _U, _C, _UI, _w
    D = deps and deps.D

    -- FARM ------------------------------------------------------------------
    local p = win:tab("Farm")
    local c = win:card(p, "Auto Farm Level")
    win:toggle(c, "Auto Farm Level", "accept the quest, travel, bring, hit", "farm")
    win:toggle(c, "Auto Quest", "accept the quest automatically", "autoquest")
    win:dropdown(c, "Mode", "farmmode", { "level", "nearest", "boss", "mastery" })
    win:dropdown(c, "Weapon", "farmtool", { "Melee", "Sword", "Gun", "Blox Fruit" })
    win:slider(c, "Farm Distance", "farmdistance", 5, 60, 1)
    win:toggle(c, "Orbit Target", "circle the mob so hits keep landing", "orbit")
    win:toggle(c, "Bring Mobs", "pin mobs + enlarge hitbox", "bring")
    win:slider(c, "Bring Distance", "bringdist", 50, 500, 10)

    c = win:card(p, "Travel")
    win:toggle(c, "Tween Travel", "smooth flight instead of instant teleport", "tween")
    win:slider(c, "Tween Speed", "tweenspeed", 60, 400, 10)
    win:toggle(c, "Portal Hop", "hard teleport when far (faster, riskier)", "portalhop")
    win:toggle(c, "Fly / Hover", "hold position above the mob", "hover")
    win:toggle(c, "NoClip", nil, "noclip")
    win:button(c, "STOP TWEEN", "kill-switch for a stuck tween", function() U.stopTween() end)

    c = win:card(p, "Boss")
    win:dropdown(c, "Boss List", "bossselected", D and D.bossList[U.sea] or {})
    win:toggle(c, "Take Boss Quest", "accept the boss quest first", "bossquest")

    -- COMBAT ----------------------------------------------------------------
    p = win:tab("Combat")
    c = win:card(p, "Attack")
    win:toggle(c, "Fast Attack", "zero cooldowns, real credited M1", "fastattack")
    win:toggle(c, "Auto Click", nil, "autoclick")
    win:slider(c, "Attack Range", "attackdist", 20, 200, 5)
    win:slider(c, "Click Delay", "clickdelay", 0.05, 1, 0.01)
    win:button(c, "Attack Method", "tap to switch m1 <-> net remote", function()
        C.set("method", C.get("method") == "m1" and "net" or "m1")
        U.notify("attack method: " .. C.get("method"))
    end)

    c = win:card(p, "Kill Aura")
    win:toggle(c, "Kill Aura", "long-range M1, snaps onto the mob first", "killaura")
    win:slider(c, "Aura Range", "aura", 40, 300, 10)
    win:label(c, "Instakill is not offered: writing Health client-side gives no money/exp.", Color3.fromRGB(230, 150, 150))

    c = win:card(p, "Haki / Heal")
    win:toggle(c, "Auto Buso", nil, "autobuso")
    win:toggle(c, "Auto Ken", nil, "autoken")
    win:toggle(c, "Heal When Low", "under 30% HP", "heal")

    -- MASTERY / STATS -------------------------------------------------------
    p = win:tab("Stats")
    c = win:card(p, "Mastery")
    win:toggle(c, "Auto Farm Mastery", "grind the equipped tool", "automastery")
    win:dropdown(c, "Tool", "masterytool", { "Blox Fruit", "Melee", "Sword", "Gun" })
    win:slider(c, "Stop At", "masteryvalue", 100, 600, 50)
    c = win:card(p, "Stat Points")
    win:toggle(c, "Auto Stat Point", "spend points as they arrive", "autostat")
    win:dropdown(c, "Stat", "stat", { "Melee", "Sword", "Gun", "Defense", "Blox Fruit" })
    win:slider(c, "Points", "statpoints", 1, 100, 1)
    win:button(c, "Check Boost", "read your current boosts", function()
        local r = U.F("CheckBoost")
        U.log("i", "boost: " .. tostring(r))
        U.notify("boost -> Log tab")
    end)

    -- RACE / MISC -----------------------------------------------------------
    c = win:card(p, "Race")
    win:toggle(c, "Auto Race V2", "run the Alchemist race quest", "autoracev2")
    win:button(c, "Race Reroll", "BlackbeardReward reroll 1", function() U.F("BlackbeardReward", "Reroll", "1") end)
    win:button(c, "Race Reroll (2)", "second reroll slot", function() U.F("BlackbeardReward", "Reroll", "2") end)
    win:button(c, "Stat Refund", "BlackbeardReward refund", function() U.F("BlackbeardReward", "Refund", "1") end)

    -- TELEPORT --------------------------------------------------------------
    p = win:tab("Teleport")
    c = win:card(p, "Islands")
    -- read the live registry at build time; it is dynamic per sea, so never hardcode
    local islands = {}
    do
        local w = workspace:FindFirstChild("_WorldOrigin")
        local loc = w and w:FindFirstChild("Locations")
        if loc then
            for _, i in ipairs(loc:GetChildren()) do table.insert(islands, i.Name) end
            table.sort(islands)
        end
    end
    if #islands == 0 then islands = { "no Locations registry" } end
    win:dropdown(c, "Island", "island", islands)
    win:button(c, "Teleport", "jump to the island above", function() M.teleportIsland() end)
    c = win:card(p, "Sea")
    win:button(c, "Teleport to Sea 1", nil, function() U.F("TravelMain") end)
    win:button(c, "Teleport to Sea 2", nil, function() U.F("TravelDressrosa") end)
    win:button(c, "Teleport to Sea 3", nil, function() U.F("TravelZou") end)
    c = win:card(p, "Server")
    win:textbox(c, "Server ID", "serverid", "jobId")
    win:button(c, "Join Server", "teleport to the jobId above", function()
        local id = C.get("serverid")
        if id and #id > 10 then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, id, U.LP)
        else
            U.notify("paste a jobId first")
        end
    end)
    win:button(c, "Server Hop", "jump to a less full server", function() M.serverHop() end)

    -- SHOP ------------------------------------------------------------------
    p = win:tab("Shop")
    c = win:card(p, "Codes")
    win:button(c, "Redeem All Codes", "sends the current public code list", function() M.redeemCodes() end)

    c = win:card(p, "Fighting Styles")
    for _, s in ipairs({ "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
                         "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon",
                         "Godhuman", "Sanguine Art" }) do
        win:button(c, "Buy " .. s, nil, function()
            U.F(s, true) U.F(s) U.notify("buying " .. s)
        end)
    end
    c = win:card(p, "Swords")
    for _, s in ipairs({ "Katana", "Cutlass", "Dual Katana", "Iron Mace", "Triple Katana",
                         "Pipe", "Dual-Headed Blade", "Soul Cane", "Bisento" }) do
        win:button(c, "Buy " .. s, nil, function()
            U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
        end)
    end
    c = win:card(p, "Guns")
    for _, s in ipairs({ "Musket", "Slingshot", "Flintlock", "Refined Slingshot",
                         "Refined Flintlock", "Cannon", "Kabucha" }) do
        win:button(c, "Buy " .. s, nil, function()
            U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
        end)
    end

    -- VISUAL ----------------------------------------------------------------
    p = win:tab("Visual")
    c = win:card(p, "ESP")
    win:toggle(c, "ESP Mobs", "name tags on enemies", "esp")
    win:toggle(c, "ESP Players", nil, "espplayers")
    c = win:card(p, "Performance")
    win:toggle(c, "Low-End Mode", "kills particles + shadows (mobile fps)", "lowend")
    win:toggle(c, "Anti-AFK", nil, "antiafk")
    win:toggle(c, "Walk On Water", "platform under your feet", "walkonwater")
    win:toggle(c, "Heal When Low", "under 30% HP", "heal")

    -- MISC ------------------------------------------------------------------
    p = win:tab("Misc")
    c = win:card(p, "Log Webhook")
    win:label(c, "paste a Discord webhook URL here, then Log tab > Send")
    win:textbox(c, "Webhook", "webhook", "https://discord.com/api/webhooks/...")
    c = win:card(p, "Credits")
    win:label(c, "use an alt account. this is a cheat.")
    return M
end

return M
]==]
FILES["src/home.lua"] = [==[
--[[ home.lua - Home tab: status, module load report, Log tab, Credits. ]]

local M = {}
local U, C, UI, win

function M.init(_U, _C, _UI, _w)
    U, C, UI, win = _U, _C, _UI, _w

    local home = win:tab("Home")
    local st = win:card(home, "Status")
    M.lvl = win:label(st, "loading...")
    local ok, bad = 0, 0
    for _, line in ipairs(U.modules or {}) do
        if line:find("^%[ok%]") then ok = ok + 1 else bad = bad + 1 end
    end
    win:label(st, "modules: " .. ok .. " ok, " .. bad .. " failed" .. (bad > 0 and "  -> Log tab" or ""))
    win:debug(home, U, C)

    local cf = win:card(home, "Quick")
    win:toggle(cf, "Auto Farm Level", "the main switch", "farm")
    win:toggle(cf, "Low-End Mode", "kills particles + shadows (mobile fps)", "lowend")
    win:toggle(cf, "Anti-AFK", nil, "antiafk")
    win:button(cf, "Dump Environment", "executor capabilities + game state", function()
        U.log("i", "executor " .. tostring(identifyexecutor()))
        U.log("i", "debug.getupvalues " .. type(debug.getupvalues) .. "  require " .. type(require) .. "  request " .. type(request))
        U.log("i", "setclipboard " .. type(setclipboard) .. "  sethiddenproperty " .. type(sethiddenproperty))
        U.log("i", "CombatFramework " .. tostring(U.LP.PlayerScripts:FindFirstChild("CombatFramework") ~= nil))
        U.log("i", "mobs " .. #U.mobs() .. "  level " .. U.level() .. "  sea " .. tostring(U.sea) .. "  place " .. game.PlaceId)
        U.notify("dumped to Log tab")
    end)
    win:button(cf, "Refresh", "re-read islands and reload", function() U.notify("ok") end)

    -- Log tab --------------------------------------------------------------
    local logp = win:tab("Log")
    local lc = win:card(logp, "Log")
    M.loglabel = win:label(lc, "")
    win:button(lc, "Copy to Clipboard", nil, function()
        pcall(function() setclipboard(U.logText and U.logText() or table.concat(U.logs, "\n")) end)
        U.notify("log copied")
    end)
    win:button(lc, "Clear", nil, function()
        U.logs = {}
        M.loglabel.Text = ""
    end)
    win:button(lc, "Send to Webhook", "URL set in Misc", function()
        local url = C.get("webhook")
        if not url or url == "" then return U.notify("no webhook url") end
        pcall(function()
            local body = (U.logText and U.logText() or table.concat(U.logs, "\n")):sub(1, 1900)
            request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = game:GetService("HttpService"):JSONEncode({ content = "```" .. body .. "```" }),
            })
        end)
        U.notify("sent")
    end)

    task.spawn(function()
        while win.gui.Parent do
            M.lvl.Text = string.format("Lv %d   sea %s   mobs %d   %s",
                U.level(), tostring(U.sea), #U.mobs(), tostring(C.get("farm") and "FARMING" or "idle"))
            M.loglabel.Text = (U.logText and U.logText() or table.concat(U.logs, "\n"))
            task.wait(1)
        end
    end)

    -- Credits --------------------------------------------------------------
    local cr = win:tab("Credits")
    local cc = win:card(cr, "Credits")
    win:label(cc, "Raf's Personal Script")
    win:label(cc, "keyless, open source, no obfuscation")
    win:label(cc, "feature set ported from the public Redz Hub V2 source")
    win:label(cc, "this is a cheat - use an alt account")
    return M
end

return M
]==]
local function Any(name)
    local t = {}
    return setmetatable(t, {
        __index = function(self, k)
            if type(k) == "number" then return nil end
            if k == "Value" then return 0 end
            if k == "Health" or k == "MaxHealth" then return 100 end
            if k == "Name" then return name or "Mock" end
            if k == "Position" or k == "Velocity" then return Vector3.new() end
            if k == "CFrame" then return CFrame.new() end
            if k == "p" then return Vector3.new() end
            if k == "Magnitude" then return 1 end
            if k == "Unit" then return Vector3.new() end
            if k == "ViewportSize" then return Vector2.new() end
            if k == "X" or k == "Y" then return 1 end
            local v = Any(k); rawset(self, k, v); return v
        end,
        __call = function() return Any() end,
        __len = function() return 0 end,
        __tostring = function() return "Any" end,
        __add = function() return Any() end, __sub = function() return Any() end,
        __mul = function() return Any() end, __div = function() return Any() end,
    })
end
local vec = { new = function() return Any("v") end, zero = Any("v") }
Vector3, Vector2 = vec, vec
CFrame = { new = function() return Any("cf") end }
UDim = { new = function() return Any() end }
UDim2 = { new = function() return Any() end, fromOffset = function() return Any() end, fromScale = function() return Any() end }
Color3 = { new = function() return Any() end, fromRGB = function() return Any() end }
Enum = setmetatable({}, { __index = function() return Any() end })
TweenInfo = { new = function() return Any() end }
Instance = { new = function() return Any("Instance") end }
task = { wait = function() end, spawn = function() end, defer = function() end }

local svc = Any("svc")
game = setmetatable({ PlaceId = 7449423635, GameId = 994732206, JobId = "x", HttpGet = function() error("offline") end,
    GetService = function() return svc end }, { __index = function() return svc end })
workspace = svc
script = { Parent = svc }
require = function() return Any("module") end
identifyexecutor = function() return "harness" end
request, setclipboard, sethiddenproperty = function() end, function() end, function() end
debug = { getupvalues = function() return {} end, traceback = function() return "" end }

local loaded, okCount, failCount = {}, 0, 0
for _, f in ipairs({ "src/util.lua", "src/config.lua", "src/data.lua", "src/ui.lua",
                     "src/farm.lua", "src/extras.lua", "src/pages.lua", "src/home.lua" }) do
    local chunk, err = loadstring(FILES[f], f)
    if not chunk then
        print("[x] " .. f .. " compile: " .. tostring(err)) failCount = failCount + 1
    else
        local ok, res = pcall(chunk)
        local v = ok and res or nil
        if type(v) == "function" then local ok2, r2 = pcall(v, {}) v = ok2 and r2 or nil end
        if type(v) == "table" then
            print("[ok] " .. f .. (v.tick and "  (tick)" or ""))
            loaded[f] = v okCount = okCount + 1
        else
            print("[x] " .. f .. " -> " .. type(v) .. "  " .. tostring(res)) failCount = failCount + 1
        end
    end
end

local U, C, D = loaded["src/util.lua"], loaded["src/config.lua"], loaded["src/data.lua"]
local UI = loaded["src/ui.lua"]
U.C = C
U.logText = function() return table.concat(U.logs, "\n") end

-- data table sanity: quest ranges ordered, boss list non-empty, every boss has a CFrame
assert(type(D) == "table", "data.lua did not return a table")
local qn, bn = 0, 0
for sea = 1, 3 do
    local rows = D.quests[sea]
    assert(rows and #rows > 0, "no quest rows for sea " .. sea)
    for i, r in ipairs(rows) do
        assert(r[1] <= r[2], "quest row " .. i .. " sea " .. sea .. " min>max")
        assert(type(r[3]) == "string" and #r[3] > 0, "quest row " .. i .. " no mob")
        assert(type(r[4]) == "string" and #r[4] > 0, "quest row " .. i .. " no quest name")
        assert(r[6] ~= nil, "quest row " .. i .. " no quest CFrame")
        qn = qn + 1
    end
    assert(#D.bossList[sea] > 0, "no boss list for sea " .. sea)
end
for name, row in pairs(D.bosses) do
    assert(row[2] ~= nil, "boss " .. name .. " has no CFrame")
    bn = bn + 1
end
assert(#D.codes > 0, "no codes")
local fcount = 0
for _ in pairs(D.fruits) do fcount = fcount + 1 end
assert(fcount > 0, "no fruits")
print(string.format("[ok] data: %d quest rows, %d bosses, %d codes, %d fruits", qn, bn, #D.codes, fcount))
-- every boss in a sea list must exist in the boss table
for sea = 1, 3 do
    for _, n in ipairs(D.bossList[sea]) do
        if not D.bosses[n] then print("[!] boss list entry without data: " .. n) end
    end
end

local win
local okU, errU = pcall(function() win = UI.new(U, C) end)
assert(okU, "UI.new: " .. tostring(errU))
print("[ok] UI.new built, first tab: " .. tostring(win.current))

for _, pair in ipairs({ { "src/farm.lua", "farm" }, { "src/extras.lua", "extras" } }) do
    local m = loaded[pair[1]]
    local ok, err = pcall(function() m.init(U, C, UI, win, { D = D }) end)
    if ok then print("[ok] init " .. pair[2]) else print("[x] init " .. pair[2] .. ": " .. tostring(err)) failCount = failCount + 1 end
    for i = 1, 3 do
        local ok2, err2 = pcall(m.tick, U, C)
        if not ok2 then print("[x] tick " .. pair[2] .. " #" .. i .. ": " .. tostring(err2)) failCount = failCount + 1 break end
    end
end
for _, pair in ipairs({ { "src/pages.lua", "pages" }, { "src/home.lua", "home" } }) do
    local m = loaded[pair[1]]
    local ok, err = pcall(function() m.init(U, C, UI, win, { D = D }) end)
    if ok then print("[ok] init " .. pair[2]) else print("[x] init " .. pair[2] .. ": " .. tostring(err)) failCount = failCount + 1 end
end
print("[ok] tabs: " .. tostring(#win.rows) .. " rows registered")

C.set("farm", true) assert(C.get("farm") == true)
C.toggle("farm") assert(C.get("farm") == false)
print("[ok] config round-trip")

print(string.format("HARNESS: %d ok, %d failed", okCount, failCount))
assert(failCount == 0, "FAILED")
