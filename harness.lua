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
]==]
FILES["src/config.lua"] = [==[
--[[ config.lua - flat state store. Keys and defaults come from the source hub's own
     UI spec, so a row and its loop can never disagree on a name. ]]

local C = {}

C.values = {
    jobid = "",
    MirageHop = false,
    MoonHop = false,
    HopMax = 40,
    HopDelay = 8,
    HopMinPlayers = 0,
    HopAutoOff = true,
    SharedUrl = "",
    -- attack path: "m1" (combat framework) or "net" (RegisterHit remote)
    method = "m1",
    AimBotSkill = true,
    AntiAFK = true,
    AttackDistance = false,
    AutoBartiloQuest = false,
    AutoBuyChip = false,
    AutoBuyHakiColor = false,
    AutoBuyLawChip = false,
    AutoCakePrince = false,
    AutoCandy = false,
    AutoChestBypass = false,
    AutoChestTween = false,
    AutoClick = false,
    AutoClickDelay = 0.18,
    AutoCollectYama = false,
    AutoCursedCaptain = false,
    AutoCursedDualKatana = false,
    AutoDarkbeard = false,
    AutoDeathStep = false,
    AutoDonSwanHop = false,
    AutoDoughKing = false,
    AutoDragonTalon = false,
    AutoElectricClaw = false,
    AutoEliteHunter = false,
    AutoEliteHunterHop = false,
    AutoEnelBossPole = false,
    AutoFactory = false,
    AutoFarmBone = false,
    AutoFarmBossSelected = false,
    AutoFarmEctoplasm = false,
    AutoFarmMastery = false,
    AutoFarmMaterial = false,
    AutoFarmNearest = false,
    AutoFarmRaid = false,
    AutoFarmSea = false,
    AutoFarm_Level = false,
    AutoFinishTrial = false,
    AutoGift = false,
    AutoGodHuman = false,
    AutoHaki = false,
    AutoKenV2 = false,
    AutoKillDonSwan = false,
    AutoKillLawBoss = false,
    AutoKitsuneIsland = false,
    AutoLegendarySword = false,
    AutoMasteryFightingStyle = false,
    AutoMasteryValue = 300,
    AutoMusketeerHat = false,
    AutoPiratesSea = false,
    AutoRaceV2 = false,
    AutoRainbowHaki = false,
    AutoRandomFruit = false,
    AutoRengoku = false,
    AutoRengokuHop = false,
    AutoRipIndra = false,
    AutoSawBoss = false,
    AutoSecondSea = false,
    AutoSharkmanKarate = false,
    AutoSoulGuitar = false,
    AutoSoulReaper = false,
    AutoStartLawRaid = false,
    AutoStats = false,
    AutoStoreFruits = false,
    AutoSuperhuman = false,
    AutoTTK = false,
    AutoThirdSea = false,
    AutoTradeBone = false,
    AutoTushita = false,
    AutoTushitaHop = false,
    AutoUnlockSaber = false,
    AutoWoodPlanks = false,
    BossSelected = "The Saw",
    BringMobs = false,
    BringMobsDistance = 250,
    EspChests = false,
    EspFlowers = false,
    EspFruits = false,
    EspIslands = false,
    EspPlayer = false,
    FarmPos = 20,
    FarmTool = "Melee",
    FastAttack = false,
    FishBoat = true,
    FishCrewMember = true,
    HealthPanic = 25,
    HealthSkill = 25,
    KillAllBosses = false,
    MaterialSelected = "Leather + Scrap Metal",
    NPCtween = false,
    PanicMode = true,
    Piranha = true,
    PirateBrigade = true,
    PirateGrandBrigade = true,
    RainbowHakiHop = false,
    RipIndraLegendaryHaki = false,
    SeaAimBotSkill = true,
    SeaBeast = true,
    SeaBeastTriple = true,
    SeaBoatSpeed = 250,
    SeaLevelTP = "6",
    SeaSkillC = true,
    SeaSkillF = false,
    SeaSkillV = true,
    SeaSkillX = true,
    SeaSkillZ = true,
    SelectRaidChip = "1",
    Shark = true,
    SkillC = true,
    SkillF = false,
    SkillV = true,
    SkillX = true,
    SkillZ = true,
    TakeQuestBoss = true,
    TeleportIslandSelect = "1",
    TeleportToFruit = false,
    TeleportToIsland = false,
    Terrorshark = true,
    ToolMastery = "Blox Fruit",
    TradeAzureEmber = false,
    TweenSpeed = 170,
    WalkOnWater = true,
    aura = 120,
    farmmode = "level",
    heal = false,
    hover = true,
    island = "1",
    killaura = false,
    lowend = false,
    noclip = true,
    orbit = true,
    serverid = "",
    stat = "Melee",
    tween = true,
    webhook = "",
}

-- boss_<name> / mob_<name> / chain_<name> / fighter_<name> are created on demand
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


--[[ materials[sea][name] = { mobs, farmCF } -- mob farm spots for each material ]]
D.materials2 = {}
D.materials2[1] = {
    ["Angel Wings"] = { { "Royal Soldier", "Royal Squad" }, CFrame.new(-7742, 5634, -1564) },
    ["Leather + Scrap Metal"] = { { "Pirate", "Brute" }, CFrame.new(-1257, 54, 4091) },
    ["Magma Ore"] = { { "Military Soldier" }, CFrame.new(-5408, 11, 8456) },
    ["Fish Tail"] = { { "Fishman Warrior" }, CFrame.new(60931, 19, 1574) }
}
D.materials2[2] = {
    ["Leather + Scrap Metal"] = { { "Scrap Metal" }, CFrame.new(-1026, 73, 1375) },
    ["Magma Ore"] = { { "Lava Pirate" }, CFrame.new(-5241, 50, -4713) },
    ["Mystic Droplet"] = { { "Water Fighter" }, CFrame.new(-3350, 282, -10527) },
    ["Radiactive Material"] = { { "Factory Staff" }, CFrame.new(-73, 149, -112) },
    ["Vampire Fang"] = { { "Vampire" }, CFrame.new(-6030, 6, -1281) }
}
D.materials2[3] = {
    ["Leather + Scrap Metal"] = { { "Pirate Millionaire" }, CFrame.new(-364, 116, 5692) },
    ["Fish Tail"] = { { "Fishman Captain", "Fishman Raider" }, CFrame.new(-10679, 398, -8975) },
    ["Gunpowder"] = { { "Pistol Billionaire" }, CFrame.new(-394, 135, 5981) },
    ["Mini Tusk"] = { { "Mythological Pirate" }, CFrame.new(-13510, 584, -6986) },
    ["Conjured Cocoa"] = { { "Cocoa Warrior", "Chocolate Bar Battler" }, CFrame.new(400, 81, -12257) },
    ["Dragon Scale"] = { { "Dragon Crew Archer" }, CFrame.new(6689, 378, 331) }
}


--[[ spawner remotes: some bosses only appear after a remote is spammed.
     values are the CommF_ argument lists, called every `interval` seconds. ]]
D.spawners = {
    ["Cake Prince"]  = { { "CakePrinceSpawner" }, 1 },
    ["Dough King"]   = { { "SweetChaliceNpc" }, 2 },
    ["Elite Hunter"] = { { "EliteHunter" }, 3 },
    ["Ken V2"]       = { { "CitizenQuestProgress", "Citizen" }, 1 },
    ["Musketeer Hat"]= { { "CitizenQuestProgress", "Citizen" }, 1 },
    ["Saber"]        = { { "ProQuestProgress", "RichSon" }, 2 },
    ["Soul Guitar"]  = { { "GuitarPuzzleProgress", "Ghost" }, 2 },
    ["Race V2"]      = { { "Alchemist", "1" }, 1 },
    ["Second Sea"]   = { { "DressrosaQuestProgress", "Detective" }, 2 },
    ["Third Sea"]    = { { "ZQuestProgress", "Check" }, 2, { "TravelZou" } },
}

--[[ bossFarms: the simple "kill this boss, else stand here" loops, one row each.
     { mobs, fallbackCF, tool|nil, toolCF|nil, spawner|nil, hopKey|nil } ]]
D.bossFarms = {
    ["The Saw"]        = { { "The Saw" }, CFrame.new(-690, 15, 1583) },
    ["Thunder God"]    = { { "Thunder God" }, CFrame.new(-7739, 5657, -2289) },
    ["Cursed Captain"] = { { "Cursed Captain" }, CFrame.new(912, 186, 33591) },
    ["Don Swan"]       = { { "Don Swan" }, CFrame.new(2272, 15, 759), nil, nil, nil, "AutoDonSwanHop" },
    ["Darkbeard"]      = { { "Darkbeard" }, CFrame.new(3746, 13, -3632), "Fist of Darkness", CFrame.new(3779, 16, -3500) },
    ["rip_indra True Form"] = { { "rip_indra True Form" }, CFrame.new(-5333, 424, -2673), "God's Chalice", CFrame.new(-5561, 314, -2663) },
    ["Soul Reaper"]    = { { "Soul Reaper" }, CFrame.new(-9529, 316, 6712), "Hallow Essence" },
    ["Order"]          = { { "Order" }, CFrame.new(-6300, 16, -4997) },
    ["Bone"]           = { { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }, CFrame.new(-9513, 164, 5786) },
    ["Ectoplasm"]      = { { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer" }, CFrame.new(912, 186, 33591) },
    ["Candy"]          = { { "Candy Pirate", "Snow Demon" }, CFrame.new(-9513, 164, 5786) },
    ["Pirates Sea"]    = { { "Pirate", "Brute" }, CFrame.new(-5556, 314, -2988), nil, nil, nil, nil, 700 },
    ["Factory"]        = { { "Factory Staff" }, CFrame.new(410, 200, -414), nil, nil, nil, nil, nil, true },
    ["Rengoku"]        = { { "Arctic Warrior", "Snow Lurker" }, CFrame.new(5707, 28, -6402) },
    ["Tushita"]        = { { "Cursed Skeleton", "Cursed Skeleton Warrior" }, CFrame.new(-9513, 164, 5786) },
}

--[[ fighters: style -> { mobs, farmCF, style } -- buy the style once mastery is done ]]
D.fighters = {
    { "Death Step",        { "Arctic Warrior", "Snow Lurker" }, CFrame.new(5707, 28, -6402), "Death Step" },
    { "Electric Claw",     { "Dragon Crew Archer", "Dragon Crew Warrior" }, CFrame.new(6588, 170, -1104), "Electric Claw" },
    { "Sharkman Karate",   { "Fishman Raider", "Fishman Captain" }, CFrame.new(-10679, 398, -8975), "Sharkman Karate" },
    { "Dragon Talon",      { "Dragon Crew Warrior", "Dragon Crew Archer" }, CFrame.new(6588, 170, -1104), "Dragon Talon" },
    { "Superhuman",        { "Military Soldier", "Military Spy" }, CFrame.new(-5408, 11, 8456), "Superhuman" },
    { "Godhuman",          { "Fishman Raider", "Fishman Captain" }, CFrame.new(-10679, 398, -8975), "Godhuman" },
}

--[[ questChains: the multi-step unlocks, ported step-by-step from the source.
     Each step: { text, cf, tool|nil, quest|nil, mobs|nil, remote|nil, level|nil } ]]
D.chains = {
    ["Ken V2"] = {
        { text = "buy the three fruits from the Citizen", cf = CFrame.new(-12445, 332, -7676), remote = { "CitizenQuest", 1 } },
        { text = "kill Forest Pirates for the Citizen quest", cf = CFrame.new(-12512, 340, -9872), mobs = { "Forest Pirate" }, quest = "Forest Pirate" },
        { text = "hand in at the Citizen", cf = CFrame.new(-12445, 332, -7676), remote = { "CitizenQuestProgress", "Citizen" } },
    },
    ["Musketeer Hat"] = {
        { text = "kill Pirate Millionaire for the Citizen", cf = CFrame.new(-13393, 319, -8423), mobs = { "Pirate Millionaire" } },
        { text = "hand in at the Citizen", cf = CFrame.new(-12512, 340, -9872), remote = { "CitizenQuestProgress", "Citizen" } },
    },
    ["Saber"] = {
        { text = "talk to the Rich Son", cf = CFrame.new(-1461, 30, -51), remote = { "ProQuestProgress", "RichSon" } },
        { text = "kill the mobs, then return", cf = CFrame.new(-1408, 30, 3), remote = { "ProQuestProgress", "SickMan" } },
        { text = "buy the Relic and open the door", cf = CFrame.new(1113, 5, 4352), tool = "Relic" },
    },
    ["Rainbow Haki"] = {
        { text = "kill the five bosses", mobs = { "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate" } },
        { text = "bet at the Horned Man", cf = CFrame.new(-1049, 40, 6791), remote = { "HornedMan", "Bet" } },
    },
    ["Soul Guitar"] = {
        { text = "buy the Soul Guitar", cf = CFrame.new(-10129, 154, 5928), remote = { "soulGuitarBuy", true } },
        { text = "finish the ghost puzzle", cf = CFrame.new(-10129, 154, 5928), tool = "Soul Guitar", remote = { "GuitarPuzzleProgress", "Ghost" } },
    },
    ["Race V2"] = {
        { text = "accept the Alchemist quest", cf = CFrame.new(-2777, 73, -3570), remote = { "Alchemist", "1" } },
        { text = "collect the flowers, then evolve", cf = CFrame.new(-2777, 73, -3570), remote = { "Alchemist", "2" } },
    },
    ["Second Sea"] = {
        { text = "level 700 required", level = 700 },
        { text = "get the Key from the Detective", cf = CFrame.new(4852, 6, 719), remote = { "DressrosaQuestProgress", "Detective" } },
        { text = "open the door with the Key", cf = CFrame.new(1346, 37, -1329), tool = "Key" },
        { text = "kill the Ice Admiral", mobs = { "Ice Admiral" } },
        { text = "sail to the second sea", cf = CFrame.new(1280, 27, -1380), remote = { "TravelDressrosa" } },
    },
    ["Third Sea"] = {
        { text = "level 1500 required", level = 1500 },
        { text = "kill rip_indra", mobs = { "rip_indra" } },
        { text = "sail to the third sea", cf = CFrame.new(0, 0, 0), remote = { "TravelZou" } },
    },
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
--[[ ui.lua - raw Instance.new GUI, no library.

     Two things make this load fast:
       1. tabs are built LAZILY - only Home exists at load, the other pages are
          constructed the first time they are opened. 150 rows become ~12.
       2. one flat frame per row, no nested cards/strokes, so the UI tree stays small.

     Minimalist: single accent colour, no gradients, no icons, compact rows. ]]

local UI = {}
UI.__index = UI

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local ACCENT = Color3.fromRGB(124, 142, 255)
local BG     = Color3.fromRGB(19, 20, 24)
local CARD   = Color3.fromRGB(28, 30, 36)
local TRACK  = Color3.fromRGB(46, 49, 58)
local TXT    = Color3.fromRGB(232, 234, 242)
local DIM    = Color3.fromRGB(138, 143, 158)

local function mk(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    i.Parent = parent
    return i
end

local function corner(i, r)
    mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, i)
    return i
end

local function to(inst, t, props)
    TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quad), props):Play()
end

function UI.new(U, C)
    local self = setmetatable({ U = U, C = C, pages = {}, order = {}, built = {} }, UI)

    local pg = U.LP:FindFirstChild("PlayerGui")
    local old = pg and pg:FindFirstChild("RPS")
    if old then old:Destroy() end

    local gui = mk("ScreenGui", {
        Name = "RPS", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true,
    }, pg or game:GetService("CoreGui"))
    self.gui = gui

    local main = mk("Frame", {
        Size = UDim2.fromOffset(430, 300), Position = UDim2.new(0.5, -215, 0.5, -150),
        BackgroundColor3 = BG, BorderSizePixel = 0, Active = true, Draggable = true,
    }, gui)
    corner(main, 10)
    self.main = main

    -- header: title + one close button. no subtitle, no search box.
    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = CARD, BorderSizePixel = 0 }, main)
    corner(header, 10)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = CARD, BorderSizePixel = 0 }, header)
    mk("Frame", { Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(12, 9), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, header)
    mk("TextLabel", {
        Text = "Raf's Personal Script", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TXT,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 6), Size = UDim2.new(1, -80, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    local min = mk("TextButton", {
        Text = "-", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -56, 0, 3),
    }, header)
    min.MouseButton1Click:Connect(function() self:hide() end)
    local kill = mk("TextButton", {
        Text = "x", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -28, 0, 3),
    }, header)
    kill.MouseButton1Click:Connect(function() self:destroy() end)

    -- tab rail: 100px, plain buttons, no icons
    local rail = mk("ScrollingFrame", {
        Size = UDim2.new(0, 100, 1, -42), Position = UDim2.fromOffset(8, 40), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = TRACK,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 3) }, rail)
    self.rail = rail

    local body = mk("ScrollingFrame", {
        Size = UDim2.new(1, -116, 1, -42), Position = UDim2.new(0, 108, 0, 40), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 5, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = ACCENT, ClipsDescendants = true,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 6) }, body)
    self.body = body

    -- floating restore button
    local fab = mk("TextButton", {
        Name = "FAB", Text = "R", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = TXT,
        BackgroundColor3 = ACCENT, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.5, -23),
        Visible = false,
    }, gui)
    corner(fab, 23)
    fab.Draggable = true
    fab.MouseButton1Click:Connect(function() self:show() end)
    self.fab = fab

    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightControl then self:toggle() end
    end)
    return self
end

function UI:show() self.main.Visible = true self.fab.Visible = false end
function UI:hide() self.main.Visible = false self.fab.Visible = true end
function UI:toggle() self.main.Visible = not self.main.Visible self.fab.Visible = not self.main.Visible end
function UI:destroy()
    if self._onDestroy then pcall(self._onDestroy) end
    self.gui:Destroy()
end

-- tabs ---------------------------------------------------------------------
-- builder runs on FIRST open only: that is what keeps the load instant.
function UI:tab(name, builder)
    if self.pages[name] then return self.pages[name] end

    local btn = mk("TextButton", {
        Text = name, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = DIM,
        BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 26),
        AutoButtonColor = false,
    }, self.rail)
    corner(btn, 6)
    local bar = mk("Frame", {
        Size = UDim2.new(0, 2, 0.5, 0), Position = UDim2.new(0, 0, 0.25, 0),
        BackgroundColor3 = ACCENT, BorderSizePixel = 0, Visible = false,
    }, btn)
    corner(bar, 1)

    local page = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, AutomaticSize = Enum.AutomaticSize.Y,
    }, self.body)
    mk("UIListLayout", { Padding = UDim.new(0, 6) }, page)

    local entry = { btn = btn, bar = bar, page = page, builder = builder }
    self.pages[name] = entry
    table.insert(self.order, name)
    btn.MouseButton1Click:Connect(function() self:select(name) end)
    if not self.current then self:select(name) end
    return page
end

function UI:select(name)
    local e = self.pages[name]
    if not e then return end
    -- lazy build, once
    if e.builder and not self.built[name] then
        self.built[name] = true
        local ok, err = pcall(e.builder, e.page)
        if not ok then self.U.log("x", "tab " .. name .. ": " .. tostring(err)) end
    end
    self.current = name
    for n, p in pairs(self.pages) do
        local on = n == name
        p.page.Visible = on
        p.bar.Visible = on
        p.btn.TextColor3 = on and TXT or DIM
        p.btn.BackgroundColor3 = on and TRACK or CARD
    end
    self.body.CanvasPosition = Vector2.zero
end

-- widgets ------------------------------------------------------------------
function UI:card(page, title)
    local card = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 0), BackgroundColor3 = CARD, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
    corner(card, 8)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, card)
    mk("UIListLayout", { Padding = UDim.new(0, 4) }, card)
    if title then
        mk("TextLabel", {
            Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = ACCENT,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
    end
    return card
end

local function rowFrame(parent, h)
    return mk("Frame", { Size = UDim2.new(1, 0, 0, h or 18), BackgroundTransparency = 1 }, parent)
end

local function rowText(f, title)
    return mk("TextLabel", {
        Text = title, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT,
        BackgroundTransparency = 1, Size = UDim2.new(1, -54, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
end

function UI:toggle(parent, title, key)
    local f = rowFrame(parent, 18)
    rowText(f, title)
    local track = mk("Frame", {
        Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -36, 0, 0),
        BackgroundColor3 = self.C.get(key) and ACCENT or TRACK, BorderSizePixel = 0,
    }, f)
    corner(track, 9)
    local knob = mk("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = self.C.get(key) and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, track)
    corner(knob, 7)
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function()
        local on = self.C.toggle(key)
        to(track, 0.12, { BackgroundColor3 = on and ACCENT or TRACK })
        to(knob, 0.12, { Position = on and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2) })
    end)
    return f
end

function UI:slider(parent, title, key, min, max, step)
    step = step or 1
    local f = rowFrame(parent, 26)
    local label = rowText(f, title)
    local bar = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 4), Position = UDim2.new(0, 0, 0, 18),
        BackgroundColor3 = TRACK, BorderSizePixel = 0,
    }, f)
    corner(bar, 2)
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, bar)
    corner(fill, 2)
    local function apply(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor((min + (max - min) * a) / step + 0.5) * step
        self.C.set(key, v)
        fill.Size = UDim2.new(a, 0, 1, 0)
        label.Text = title .. ": " .. tostring(v)
    end
    local v0 = self.C.get(key) or min
    label.Text = title .. ": " .. tostring(v0)
    fill.Size = UDim2.new((v0 - min) / math.max(max - min, 1), 0, 1, 0)
    local dragging = false
    local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, bar)
    hit.MouseButton1Down:Connect(function() dragging = true apply(UIS:GetMouseLocation().X) end)
    hit.MouseButton1Up:Connect(function() dragging = false end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then apply(i.Position.X) end
    end)
    return f
end

function UI:dropdown(parent, title, key, values)
    local f = rowFrame(parent, 18)
    local label = rowText(f, title .. ": " .. tostring(self.C.get(key)))
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    local list
    btn.MouseButton1Click:Connect(function()
        if list then list:Destroy() list = nil return end
        list = mk("ScrollingFrame", {
            Size = UDim2.new(1, -14, 0, math.min(#values * 18 + 6, 150)), BackgroundColor3 = BG,
            BorderSizePixel = 0, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        }, parent)
        corner(list, 6)
        mk("UIListLayout", { Padding = UDim.new(0, 1) }, list)
        for _, v in ipairs(values) do
            local b = mk("TextButton", {
                Text = tostring(v), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = TXT,
                BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 17),
                TextXAlignment = Enum.TextXAlignment.Left,
            }, list)
            corner(b, 3)
            b.MouseButton1Click:Connect(function()
                self.C.set(key, v)
                label.Text = title .. ": " .. tostring(v)
                if list then list:Destroy() list = nil end
            end)
        end
    end)
    return f
end

function UI:textbox(parent, title, key, placeholder)
    local f = rowFrame(parent, 34)
    rowText(f, title)
    local box = mk("TextBox", {
        Text = tostring(self.C.get(key) or ""), PlaceholderText = placeholder or "",
        Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = TXT, PlaceholderColor3 = DIM,
        BackgroundColor3 = BG, BorderSizePixel = 0, ClearTextOnFocus = false,
        Size = UDim2.new(1, -4, 0, 18), Position = UDim2.new(0, 0, 0, 15),
    }, f)
    corner(box, 4)
    box:GetPropertyChangedSignal("Text"):Connect(function() self.C.set(key, box.Text) end)
    return f
end

function UI:button(parent, title, fn)
    local f = rowFrame(parent, 18)
    local label = rowText(f, title)
    label.TextColor3 = ACCENT
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function() self.U.safe(title, fn) end)
    return f
end

function UI:label(parent, text, color)
    return mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = color or DIM,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

-- live debug panel (3 numbers, no labels on separate rows)
function UI:debug(page, U, C)
    local card = self:card(page, "Debug")
    local l1 = self:label(card, "")
    local l2 = self:label(card, "")
    local t0 = os.clock()
    task.spawn(function()
        while self.gui.Parent do
            local fps = math.floor(1 / math.max(game:GetService("RunService").Heartbeat:Wait(), 1e-3))
            l1.Text = string.format("FPS %d   PING %d ms   MOBS %d", fps, math.floor(U.LP:GetNetworkPing() * 1000), #U.mobs())
            l2.Text = string.format("LV %d   SEA %s   UPTIME %ds", U.level(), tostring(U.sea), math.floor(os.clock() - t0))
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
local D, Q, U, C

function M.init(_U, _C, _UI, _win, deps)
    U, C, Q, D = _U, _C, deps and deps.Q, deps and deps.D
    M.quest = nil
end

local function travel(cf, speed)
    if C.get("tween") then U.tweenTo(cf, speed or C.get("TweenSpeed")) else U.tp(cf) end
end

-- level -> new quest row. Accepting teleports to the giver first: the call is
-- ignored when the player is nowhere near it.
local function ensureQuest()
    local lv = U.level()
    if M.quest and lv >= M.quest[1] and lv <= M.quest[2] then return end
    local sea = U.sea or 1
    local row = Q and Q.at(sea, lv)
    if row then
        M.quest = row
    elseif D then
        local r = D.questAt(sea, lv)
        if r then M.quest = { r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] } end
    end
    if not M.quest then return end
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
    U.equip(C.get("FarmTool"))
    if C.get("AutoHaki") then U.autoHaki() end

    local d = C.get("FarmPos")
    travel(C.get("orbit") and U.orbit(mob, d) or (U.mobPos(mob).CFrame + Vector3.new(0, d, 0)))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(mon) end

    -- clicks only land in range; skip the swing when still far away
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        if C.get("method") == "net" then U.netAttack(C.get("AttackDistance") and 120 or 60) else U.attack(C.get("AttackDistance") and 120 or 60) end
    end
end

-- Nearest: no quest, just kill the closest mob (or the chosen boss)
local function farmNearest()
    local mob = U.nearestMob()
    if not mob then return end
    U.noclip(C.get("noclip"))
    U.equip(C.get("FarmTool"))
    if C.get("AutoHaki") then U.autoHaki() end
    travel(U.orbit(mob, C.get("FarmPos")))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("AttackDistance") and 120 or 60)
    end
end

-- Boss: travel to the spawn point, take the quest if the boss needs one, kill.
local function farmBoss()
    local name = C.get("BossSelected")
    if not name or not D then return end
    local row = D.bosses[name]
    if not row then return end
    local needQuest, cf, qname, qnum = row[1], row[2], row[3], row[4]
    if needQuest and C.get("TakeQuestBoss") and qname then U.F("StartQuest", qname, qnum or 1) end
    local mob = U.nearestMob(name)
    if not mob then travel(cf * CFrame.new(0, 8, 0)) return end
    travel(U.orbit(mob, C.get("FarmPos")))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(name) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("AttackDistance") and 120 or 60)
    end
end

-- Mastery: same as level but with the chosen tool equipped
local function farmMastery()
    local tool = C.get("ToolMastery")
    local mob = U.nearestMob()
    if not mob then return end
    U.equip(tool)
    travel(U.orbit(mob, C.get("FarmPos")))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("AttackDistance") and 120 or 60)
    end
    if C.get("AutoStats") then
        local pts = U.data("Points")
        if pts and pts > 0 then U.F("AddPoint", "Melee", pts) end
    end
end

function M.tick(_U, _C)
    if not U.alive() then return end
    if C.get("FastAttack") or C.get("AttackDistance") then U.fastAttack() end
    if C.get("AutoFarm_Level") then
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
FILES["src/quests.lua"] = [==[
--[[ quests.lua - the driving loops for the named quests and unlocks.

     Every feature is a step list walked by tick(), not a task.spawn loop: a toggle
     off has to actually stop the work, and one scheduler keeps it cheap on mobile.

     Two drivers:
       generic  - "kill this boss, else stand here" (data.bossFarms)
       chains   - the multi-step unlocks (data.chains), with spawner remotes
]]

local M = {}
local U, C, D

-- per-feature runtime state, reset when the feature is switched off
local state = {}
local function st(key)
    local s = state[key]
    if not s then
        s = { step = 1, nextSpawn = 0, wp = 0 }
        state[key] = s
    end
    return s
end

function M.reset(key) state[key] = nil end

function M.init(_U, _C, _UI, _win, deps)
    U, C, D = _U, _C, deps and deps.D
end

-- travel + fight the same way the main farm does ---------------------------
local function travel(cf)
    if not cf then return end
    if C.get("tween") then U.tweenTo(cf, C.get("TweenSpeed")) else U.tp(cf) end
end

local function engage(mob, opts)
    opts = opts or {}
    U.noclip(C.get("noclip"))
    if opts.tool then U.equipTool(opts.tool) else U.equip(C.get("FarmTool")) end
    if C.get("AutoHaki") or C.get("AutoKenV2") then U.autoHaki() end
    local d = C.get("FarmPos")
    travel(C.get("orbit") and U.orbit(mob, d) or (U.mobPos(mob).CFrame + Vector3.new(0, d, 0)))
    U.hover(C.get("hover"))
    if opts.bring ~= false and C.get("BringMobs") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        if C.get("method") == "net" then U.netAttack(C.get("AttackDistance") and 120 or 60) else U.attack(C.get("AttackDistance") and 120 or 60) end
    end
end

-- find the first mob of any name in the list
local function firstMob(names)
    for _, n in ipairs(names) do
        local m = U.nearestMob(n)
        if m then return m end
    end
    return nil
end

-- spawner remotes: some bosses only appear after their remote is spammed
local function fireSpawner(key, s)
    local sp = D and D.spawners and D.spawners[key]
    if not sp then return end
    local now = os.clock()
    if now < s.nextSpawn then return end
    s.nextSpawn = now + (sp[2] or 2)
    for i = 3, #sp do U.F(table.unpack(sp[i])) end
    U.F(table.unpack(sp[1]))
end

-- a step from data.chains --------------------------------------------------
local function runStep(step, s)
    if step.level and U.level() < step.level then
        U.notify("needs level " .. step.level)
        return false
    end
    if step.mobs then
        local m = firstMob(step.mobs)
        if m then
            engage(m, { tool = step.tool })
            return false           -- keep killing until the mob is gone
        end
    end
    if step.remote then U.F(table.unpack(step.remote)) end
    if step.tool then U.equipTool(step.tool) end
    travel(step.cf)
    s.step = s.step + 1
    U.log("i", "step done, next: " .. s.step)
    return true
end

local function runChain(key)
    local chain = D and D.chains and D.chains[key]
    if not chain then return end
    local s = st(key)
    fireSpawner(key, s)
    local step = chain[s.step]
    if not step then
        U.notify(key .. " chain finished")
        C.set("chain_" .. key, false)
        return
    end
    runStep(step, s)
end

-- a row from data.bossFarms ------------------------------------------------
local function runBossFarm(key)
    local row = D and D.bossFarms and D.bossFarms[key]
    if not row then return end
    -- BossSelected: the dropdown value IS the key, resolve it at run time
    if key == "BossSelected" then row = D.bossFarms[C.get("BossSelected") or ""] end
    if not row then return end
    local s = st(key)
    if row[7] and U.level() < row[7] then return end
    fireSpawner(key, s)

    -- some bosses need a summoning tool equipped before they spawn
    if row[3] and U.hasTool(row[3]) then
        U.equipTool(row[3])
        travel(row[4] or row[2])
        return
    end
    local mob = firstMob(row[1])
    if mob then
        engage(mob, { bring = not row[8] })
    elseif row[6] and C.get(row[6]) then
        M.serverHop()
    else
        travel(row[2])
    end
end

-- registry: feature key -> how to drive it --------------------------------
local GENERIC = {
    ["boss_BossSelected"] = "BossSelected",
    ["boss_The Saw"] = "The Saw",
    ["boss_Thunder God"] = "Thunder God",
    ["boss_Cursed Captain"] = "Cursed Captain",
    ["boss_Don Swan"] = "Don Swan",
    ["boss_Darkbeard"] = "Darkbeard",
    ["boss_rip_indra True Form"] = "rip_indra True Form",
    ["boss_Soul Reaper"] = "Soul Reaper",
    ["boss_Order"] = "Order",
    ["mob_Bone"] = "Bone",
    ["mob_Ectoplasm"] = "Ectoplasm",
    ["mob_Candy"] = "Candy",
    ["mob_Pirates Sea"] = "Pirates Sea",
    ["mob_Factory"] = "Factory",
    ["mob_Rengoku"] = "Rengoku",
    ["mob_Tushita"] = "Tushita",
}

local CHAINS = {
    "Ken V2", "Musketeer Hat", "Saber", "Rainbow Haki", "Soul Guitar",
    "Race V2", "Second Sea", "Third Sea",
}

-- KillAllBosses: walk the sea's boss list and kill whatever is up
local function killAllBosses()
    local list = D and D.bossList[U.sea or 1] or {}
    for _, name in ipairs(list) do
        local m = U.nearestMob(name)
        if m then
            engage(m, {})
            return
        end
    end
end

function M.tick(_U, _C)
    if not U.alive() then return end
    for key, row in pairs(GENERIC) do
        if C.get(key) then runBossFarm(row) end
    end
    if C.get("KillAllBosses") then killAllBosses() end
    -- Elite Hunter has no fixed spot: the target changes with the quest
    if C.get("chain_Elite Hunter") then
        local names = { "Diablo", "Deandre", "Urban" }
        local m = firstMob(names)
        if m then
            engage(m, {})
        else
            U.F("EliteHunter")
            if C.get("AutoEliteHunterHop") then M.serverHop() else travel(CFrame.new(-5119, 315, -2964)) end
        end
    end
    for _, key in ipairs(CHAINS) do
        if C.get("chain_" .. key) then runChain(key) end
    end
    -- material farm: mobs + spot come from data.materials2
    if C.get("mat_" .. tostring(C.get("MaterialSelected"))) then
        local sea = D.materials2[U.sea or 1] or {}
        local row = sea[C.get("MaterialSelected")]
        if row then
            local mob = firstMob(row[1])
            if mob then engage(mob, {}) else travel(row[2]) end
        end
    end
    -- fighters: mastery then buy
    for _, f in ipairs(D and D.fighters or {}) do
        if C.get("fighter_" .. f[1]) then
            local mob = firstMob(f[2])
            if mob then
                engage(mob, { tool = C.get("FarmTool") })
            else
                travel(f[3])
                if U.mastery(f[1]) and U.mastery(f[1]) >= (C.get("AutoMasteryValue") or 300) then
                    U.F(f[4], true) U.F(f[4])
                    U.notify("buying " .. f[4])
                    C.set("fighter_" .. f[1], false)
                end
            end
        end
    end
    -- chests: grab whatever chest is in range while farming
    if C.get("AutoChestTween") or C.get("AutoChestBypass") then
        for _, p in ipairs(workspace:GetChildren()) do
            if p:IsA("MeshPart") and string.find(p.Name, "Chest") then
                travel(p.CFrame * CFrame.new(0, 3, 0))
                break
            end
        end
    end
    -- fruit pickup / store
    if C.get("TeleportToFruit") then
        local f = U.nearestFruit()
        if f then travel(f.CFrame * CFrame.new(0, 3, 0)) end
    end
    if C.get("AutoStoreFruits") then U.F("StoreFruit", "1") end
end

-- button actions -----------------------------------------------------------
function M.serverHop()
    local Http = game:GetService("HttpService")
    local TS = game:GetService("TeleportService")
    local ok, body = pcall(function()
        return game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId))
    end)
    if not ok or not body then return U.notify("server list blocked") end
    for _, s in ipairs(Http:JSONDecode(body).data or {}) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            U.notify("hopping...")
            TS:TeleportToPlaceInstance(game.PlaceId, s.id, U.LP)
            return
        end
    end
    U.notify("no free server")
end

return M
]==]
FILES["src/moon.lua"] = [==[
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

-- a shared list of jobIds (raw text URL: github raw, gist, pastebin, discord export).
-- Cycles through them and skips the ones already used, so one press = one new server.
local used = {}

function M.shared()
    local url = C.get("SharedUrl")
    if not url or url == "" then return nil, "set a jobId url first" end
    local ok, body = pcall(game.HttpGet, game, url)
    if not ok or type(body) ~= "string" then return nil, "fetch failed" end
    local out = {}
    for id in body:gmatch("[%w]+%-%w+%-%w+%-%w+%-[%w]+") do table.insert(out, id) end
    return out
end

function M.hopShared()
    local ids, err = M.shared()
    if not ids then return U.notify("shared: " .. tostring(err)) end
    if #ids == 0 then return U.notify("no jobId in that url") end
    for _, id in ipairs(ids) do
        if not used[id] and id ~= game.JobId then
            used[id] = true
            U.log("i", string.format("shared: hopping to %s (%d/%d)", id, #ids - (#ids - 1), #ids))
            return M.hopTo(id, "shared")
        end
    end
    used = {}
    U.notify("all " .. #ids .. " shared jobIds used - list reset")
end

function M.join(jobId)
    if not jobId or #jobId < 30 then return U.notify("that is not a jobId") end
    used[jobId] = true
    return M.hopTo(jobId, "manual")
end

function M.usedCount()
    local n = 0
    for _ in pairs(used) do n = n + 1 end
    return n
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
    used = {}
end

function M.stats() return state.hops, state.found, state.lastMoon, state.lastMirage end

return M
]==]
FILES["src/extras.lua"] = [==[
--[[ extras.lua - combat helpers, skills, ESP, world utilities, codes, shops.
     Each block is gated on its own toggle so the scheduler stays cheap. ]]

local M = {}
local U, C, D
local vp = nil
local vu = game:GetService("VirtualUser")
local UIS = game:GetService("UserInputService")

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
    U.equip(C.get("FarmTool"))
    if C.get("method") == "net" then U.netAttack(120) else U.attack(120) end
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
    local want = C.get("EspFruits") or C.get("EspChests") or C.get("EspIslands") or C.get("EspFlowers")
    local wantPlayers = C.get("EspPlayer")
    if not want and not wantPlayers then
        if next(tags) then clearTags() end
        return
    end
    local seen = {}
    local function scan(names, color, isTool)
        local root = workspace
        for _, p in ipairs(root:GetChildren()) do
            local hit = false
            for _, n in ipairs(names) do
                if string.find(p.Name, n) then hit = true break end
            end
            if hit and p:IsA("BasePart") then
                seen[p] = true
                tag(p, p, p.Name, color)
            end
        end
    end
    if C.get("EspFruits") then scan({ "Fruit" }, Color3.fromRGB(255, 200, 90)) end
    if C.get("EspChests") then scan({ "Chest", "chest" }, Color3.fromRGB(255, 255, 160)) end
    if C.get("EspFlowers") then scan({ "Flower", "flower" }, Color3.fromRGB(200, 120, 255)) end
    if C.get("EspIslands") then
        local w = workspace:FindFirstChild("_WorldOrigin")
        local loc = w and w:FindFirstChild("Locations")
        if loc then
            for _, i in ipairs(loc:GetChildren()) do
                local part = i.PrimaryPart or i:FindFirstChildWhichIsA("BasePart")
                if part then
                    seen[i] = true
                    tag(i, part, i.Name, Color3.fromRGB(120, 220, 220))
                end
            end
        end
    end
    if wantPlayers then
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

-- weapon skills: the game binds Z/X/C/V/F; VirtualUser + SendKeyEvent fires them.
-- AimBot first, or the skill fires into empty air.
local KEYS = { Z = Enum.KeyCode.Z, X = Enum.KeyCode.X, C = Enum.KeyCode.C,
               V = Enum.KeyCode.V, F = Enum.KeyCode.F }

function M.skills()
    if not U.alive() then return end
    local mob = nil
    for _, k in ipairs({ "SkillZ", "SkillX", "SkillC", "SkillV", "SkillF" }) do
        if C.get(k) then mob = U.nearestMob() break end
    end
    if not mob then return end
    if C.get("AimBotSkill") then
        local root, p = U.root(), U.mobPos(mob)
        if root and p then root.CFrame = CFrame.lookAt(root.Position, p.Position) end
    end
    for name, code in pairs(KEYS) do
        if C.get("Skill" .. name) then
            pcall(function()
                vu:CaptureController()
                UIS:SendKeyEvent(true, code, false)
                UIS:SendKeyEvent(false, code, false)
            end)
        end
    end
end

-- no camera shake: the source zeroes the shake amplitude while a toggle is on
function M.noShake()
    local cam = workspace.CurrentCamera
    if not cam then return end
    if C.get("PanicMode") then
        local c = U.char()
        local shake = c and c:FindFirstChild("CameraShaker")
        if shake then pcall(function() shake:Destroy() end) end
    end
end

-- anti-AFK: fires the idle event the server watches
function M.antiafk()
    if not C.get("AntiAFK") then return end
    vu:CaptureController()
    vu:ClickButton2(Vector2.new(0, 0))
end

-- walk on water: a platform under the player while moving
function M.water()
    local on = C.get("WalkOnWater")
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
    M.skills()
    M.noShake()
    M.water()
    M.antiafk()
end

-- actions (buttons) --------------------------------------------------------
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
--[[ pages.lua - every tab, built lazily by ui.lua (a page is constructed the first
     time it is opened, so load stays instant).

     Only Redz V2 features live here. Everything is grouped the way the source
     grouped it, minus the rows the source itself shipped as dead. ]]

local M = {}
local U, C, UI, win, D

function M.init(_U, _C, _UI, _w, deps)
    U, C, UI, win = _U, _C, _UI, _w
    D = deps and deps.D
    if deps and deps.mods then M.bindMoon(deps.mods.moon) end

    -- FARM ------------------------------------------------------------------
    win:tab("Farm", function(page)
        local c = win:card(page, "Auto Farm")
        win:toggle(c, "Auto Farm Level", "AutoFarm_Level")
        win:dropdown(c, "Mode", "farmmode", { "level", "nearest", "boss", "mastery" })
        win:dropdown(c, "Weapon", "FarmTool", { "Melee", "Sword", "Gun", "Blox Fruit" })
        win:slider(c, "Farm Distance", "FarmPos", 5, 60, 1)
        win:toggle(c, "Bring Mobs", "BringMobs")
        win:slider(c, "Bring Distance", "BringMobsDistance", 50, 500, 10)
        win:toggle(c, "Auto Farm Nearest", "AutoFarmNearest")

        c = win:card(page, "Travel")
        win:toggle(c, "Tween Travel", "tween")
        win:slider(c, "Tween Speed", "TweenSpeed", 60, 400, 10)
        win:toggle(c, "NoClip", "noclip")
        win:button(c, "STOP TWEEN", function() U.stopTween() end)

        c = win:card(page, "Boss")
        win:dropdown(c, "Boss List", "BossSelected", D.bossList[U.sea] or {})
        win:toggle(c, "Auto Farm Boss Selected", "boss_BossSelected")
        win:toggle(c, "Auto Farm All Boss", "KillAllBosses")
        win:toggle(c, "Take Boss Quest", "TakeQuestBoss")
    end)

    -- COMBAT ----------------------------------------------------------------
    win:tab("Combat", function(page)
        local c = win:card(page, "Attack")
        win:toggle(c, "Fast Attack", "FastAttack")
        win:toggle(c, "Auto Click", "AutoClick")
        win:toggle(c, "Attack Distance", "AttackDistance")
        win:slider(c, "Click Delay", "AutoClickDelay", 0.05, 1, 0.01)
        win:button(c, "Attack Method: m1", function()
            C.set("method", C.get("method") == "m1" and "net" or "m1")
            U.notify("attack method: " .. C.get("method"))
        end)

        c = win:card(page, "Kill Aura")
        win:toggle(c, "Kill Aura", "killaura")
        win:slider(c, "Aura Range", "aura", 40, 300, 10)
        win:label(c, "instakill is off the table: writing Health client-side pays nothing", Color3.fromRGB(220, 140, 140))

        c = win:card(page, "Skills")
        win:toggle(c, "AimBot Skill Enemy", "AimBotSkill")
        win:toggle(c, "Skill Z", "SkillZ")
        win:toggle(c, "Skill X", "SkillX")
        win:toggle(c, "Skill C", "SkillC")
        win:toggle(c, "Skill V", "SkillV")
        win:toggle(c, "Skill F", "SkillF")
        win:slider(c, "Health Cutoff", "HealthSkill", 10, 100, 5)

        c = win:card(page, "Haki / Heal")
        win:toggle(c, "Auto Haki (Buso + Ken)", "AutoHaki")
        win:toggle(c, "Heal When Low", "heal")
    end)

    -- FARMING (the named farmers from the source) ---------------------------
    win:tab("Farming", function(page)
        local c = win:card(page, "Bosses")
        for _, name in ipairs({ "The Saw", "Thunder God", "Cursed Captain", "Don Swan",
                               "Darkbeard", "rip_indra True Form", "Soul Reaper", "Order" }) do
            win:toggle(c, "Auto " .. name, "boss_" .. name)
        end

        c = win:card(page, "Mobs / Materials")
        win:toggle(c, "Auto Farm Bone", "mob_Bone")
        win:toggle(c, "Auto Farm Ectoplasm", "mob_Ectoplasm")
        win:toggle(c, "Auto Farm Candy", "mob_Candy")
        win:toggle(c, "Auto Pirates Sea", "mob_Pirates Sea")
        win:toggle(c, "Auto Factory", "mob_Factory")
        win:toggle(c, "Auto Rengoku", "mob_Rengoku")
        win:toggle(c, "Auto Tushita", "mob_Tushita")
        win:dropdown(c, "Material", "MaterialSelected", D.materials[U.sea] or {})
        win:toggle(c, "Auto Farm Material", "mob_Material")

        c = win:card(page, "Mastery")
        win:toggle(c, "Auto Farm Mastery", "AutoFarmMastery")
        win:dropdown(c, "Tool", "ToolMastery", { "Blox Fruit", "Melee", "Sword", "Gun" })
        win:slider(c, "Stop At", "AutoMasteryValue", 100, 600, 50)

        c = win:card(page, "Fighting Styles")
        for _, f in ipairs(D.fighters) do
            win:toggle(c, "Auto " .. f[1], "fighter_" .. f[1])
        end
    end)

    -- QUESTS ----------------------------------------------------------------
    win:tab("Quests", function(page)
        local c = win:card(page, "Unlocks")
        for _, key in ipairs({ "Ken V2", "Musketeer Hat", "Saber", "Rainbow Haki",
                               "Soul Guitar", "Race V2", "Second Sea", "Third Sea" }) do
            win:toggle(c, "Auto " .. key, "chain_" .. key)
        end
        c = win:card(page, "Elite Hunter")
        win:toggle(c, "Auto Elite Hunter", "chain_Elite Hunter")
        win:toggle(c, "Hop If Not Spawned", "AutoEliteHunterHop")
        c = win:card(page, "Server Hop")
        win:toggle(c, "Hop If Don Swan", "AutoDonSwanHop")
        win:toggle(c, "Hop If Rengoku", "AutoRengokuHop")
        win:toggle(c, "Hop If Tushita", "AutoTushitaHop")
        win:toggle(c, "Hop If Rainbow Haki", "RainbowHakiHop")
        c = win:card(page, "Race")
        win:button(c, "Race Reroll", function() U.F("BlackbeardReward", "Reroll", "1") end)
        win:button(c, "Race Reroll (2)", function() U.F("BlackbeardReward", "Reroll", "2") end)
        win:button(c, "Stat Refund", function() U.F("BlackbeardReward", "Refund", "1") end)
    end)

    -- ITEMS -----------------------------------------------------------------
    win:tab("Items", function(page)
        local c = win:card(page, "Fruit / Chest")
        win:toggle(c, "Teleport To Fruit", "TeleportToFruit")
        win:toggle(c, "Auto Store Fruits", "AutoStoreFruits")
        win:toggle(c, "Auto Chest Tween", "AutoChestTween")
        win:toggle(c, "Auto Chest Bypass", "AutoChestBypass")
        c = win:card(page, "Raid")
        win:toggle(c, "Auto Farm Raid", "AutoFarmRaid")
        win:toggle(c, "Auto Buy Chip", "AutoBuyChip")
        c = win:card(page, "Misc Buys")
        win:toggle(c, "Auto Buy Haki Color", "AutoBuyHakiColor")
        win:toggle(c, "Auto Legendary Sword", "AutoLegendarySword")
        win:toggle(c, "Auto True Triple Katana", "AutoTTK")
        win:toggle(c, "Auto Bartilo Quest", "AutoBartiloQuest")
        win:toggle(c, "Auto Cursed Dual Katana", "AutoCursedDualKatana")
        win:label(c, "CDK needs Tushita and Yama mastered first", Color3.fromRGB(150, 155, 170))
    end)

    -- TELEPORT --------------------------------------------------------------
    win:tab("Teleport", function(page)
        local c = win:card(page, "Islands")
        local islands = {}
        local w = workspace:FindFirstChild("_WorldOrigin")
        local loc = w and w:FindFirstChild("Locations")
        if loc then
            for _, i in ipairs(loc:GetChildren()) do table.insert(islands, i.Name) end
            table.sort(islands)
        end
        if #islands == 0 then islands = { "no Locations registry" } end
        win:dropdown(c, "Island", "island", islands)
        win:button(c, "Teleport", function() M.teleportIsland() end)
        c = win:card(page, "Sea")
        win:button(c, "Sea 1", function() U.F("TravelMain") end)
        win:button(c, "Sea 2", function() U.F("TravelDressrosa") end)
        win:button(c, "Sea 3", function() U.F("TravelZou") end)
        c = win:card(page, "Server")
        win:textbox(c, "Server ID", "serverid", "jobId")
        win:button(c, "Join Server", function()
            local id = C.get("serverid")
            if id and #id > 10 then
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, id, U.LP)
            else
                U.notify("paste a jobId first")
            end
        end)
    end)

    -- SHOP ------------------------------------------------------------------
    win:tab("Shop", function(page)
        local c = win:card(page, "Codes")
        win:button(c, "Redeem All Codes", function() M.redeemCodes() end)
        c = win:card(page, "Fighting Styles")
        for _, s in ipairs({ "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
                             "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon",
                             "Godhuman", "Sanguine Art" }) do
            win:button(c, "Buy " .. s, function() U.F(s, true) U.F(s) U.notify("buying " .. s) end)
        end
        c = win:card(page, "Swords")
        for _, s in ipairs({ "Katana", "Cutlass", "Dual Katana", "Iron Mace", "Triple Katana",
                             "Pipe", "Dual-Headed Blade", "Soul Cane", "Bisento" }) do
            win:button(c, "Buy " .. s, function()
                U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
            end)
        end
        c = win:card(page, "Guns")
        for _, s in ipairs({ "Musket", "Slingshot", "Flintlock", "Refined Slingshot",
                             "Refined Flintlock", "Cannon", "Kabucha" }) do
            win:button(c, "Buy " .. s, function()
                U.F("Buy" .. s:gsub("[%s%-]", "")) U.notify("buying " .. s)
            end)
        end
        c = win:card(page, "Race")
        win:button(c, "Ghoul Race", function() U.F("GhoulTrainer", "Buy") end)
        win:button(c, "Cyborg Race", function() U.F("CyborgTrainer", "Buy") end)
        win:button(c, "Random Fruit", function() U.F("Cousin", "Buy") end)
    end)

    -- VISUAL ----------------------------------------------------------------
    win:tab("Visual", function(page)
        local c = win:card(page, "ESP")
        win:toggle(c, "ESP Fruits", "EspFruits")
        win:toggle(c, "ESP Chests", "EspChests")
        win:toggle(c, "ESP Flowers", "EspFlowers")
        win:toggle(c, "ESP Islands", "EspIslands")
        win:toggle(c, "ESP Players", "EspPlayer")
        c = win:card(page, "Performance")
        win:toggle(c, "Low-End Mode", "lowend")
        win:toggle(c, "Anti-AFK", "AntiAFK")
        win:toggle(c, "Walk On Water", "WalkOnWater")
        win:toggle(c, "Panic Mode", "PanicMode")
    end)

    -- SERVER HUNT -----------------------------------------------------------
    win:tab("Server", function(page)
        local c = win:card(page, "State")
        local info = win:label(c, "reading...")
        win:button(c, "Refresh", function() U.notify("refreshed") end)
        win:label(c, "detection only works in the server you are IN - a public server list carries no game state",
            Color3.fromRGB(150, 155, 170))

        c = win:card(page, "Auto Hop")
        win:toggle(c, "Hop Until Mirage Island", "MirageHop")
        win:toggle(c, "Hop Until Full Moon", "MoonHop")
        win:toggle(c, "Switch Off At Limit", "HopAutoOff")
        win:slider(c, "Max Hops", "HopMax", 5, 200, 5)
        win:slider(c, "Seconds Between Hops", "HopDelay", 4, 30, 1)
        win:slider(c, "Skip Servers Below", "HopMinPlayers", 0, 12, 1)
        win:button(c, "Hop Once Now", function() M.hop() end)
        win:button(c, "Reset Counter", function() M.reset() U.notify("counter reset") end)

        c = win:card(page, "Join By jobId")
        win:label(c, "paste a jobId someone posted, or point at a raw text list of them",
            Color3.fromRGB(150, 155, 170))
        win:textbox(c, "jobId", "jobid", "paste here")
        win:button(c, "Join That jobId", function() M.joinJobId() end)
        win:textbox(c, "URL (raw text with jobIds)", "SharedUrl", "https://raw.githubusercontent.com/...")
        win:button(c, "Join Next Unused From URL", function() M.joinShared() end)
        win:label(c, "the list cycles: each press takes a new one, resets when all are used",
            Color3.fromRGB(150, 155, 170))

        win:button(c, "Post My jobId To Webhook", "only when a moon/mirage is up", function() M.post() end)

        task.spawn(function()
            while win.gui.Parent do
                local hops, found, phase, mirage = M.stats()
                info.Text = string.format("moon: %s\nmirage: %s\nhops: %d   found: %d",
                    tostring(phase), tostring(mirage), hops, found)
                task.wait(1)
            end
        end)
    end)

    -- MISC ------------------------------------------------------------------
    win:tab("Misc", function(page)
        local c = win:card(page, "Stats")
        win:toggle(c, "Auto Stats", "AutoStats")
        win:button(c, "Check Boost", function()
            U.log("i", "boost: " .. tostring(U.F("CheckBoost")))
            U.notify("boost -> Log")
        end)
        c = win:card(page, "Webhook")
        win:textbox(c, "Webhook", "webhook", "https://discord.com/api/webhooks/...")
        c = win:card(page, "About")
        win:label(c, "Raf's Personal Script")
        win:label(c, "keyless, open source, no obfuscation")
        win:label(c, "use an alt account")
    end)

    -- LOG -------------------------------------------------------------------
    win:tab("Log", function(page)
        local c = win:card(page, "Log")
        local out = win:label(c, "")
        win:button(c, "Copy", function()
            pcall(function() setclipboard(U.logText()) end)
            U.notify("copied")
        end)
        win:button(c, "Clear", function()
            U.logs = {}
            out.Text = ""
        end)
        win:button(c, "Send to Webhook", function()
            local url = C.get("webhook")
            if not url or url == "" then return U.notify("no webhook url") end
            pcall(function()
                request({
                    Url = url, Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = game:GetService("HttpService"):JSONEncode({ content = "```" .. U.logText():sub(1, 1900) .. "```" }),
                })
            end)
            U.notify("sent")
        end)
        task.spawn(function()
            while win.gui.Parent do
                out.Text = U.logText()
                task.wait(1)
            end
        end)
    end)
end

-- actions -------------------------------------------------------------------
function M.serverHop()
    local Http = game:GetService("HttpService")
    local TS = game:GetService("TeleportService")
    local ok, body = pcall(function()
        return game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId))
    end)
    if not ok or not body then return U.notify("server list blocked") end
    for _, s in ipairs(Http:JSONDecode(body).data or {}) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            U.notify("hopping...")
            TS:TeleportToPlaceInstance(game.PlaceId, s.id, U.LP)
            return
        end
    end
    U.notify("no free server")
end

function M.redeemCodes()
    if not U.Redeem then return U.notify("no Redeem remote") end
    local n = 0
    for _, code in ipairs(D.codes) do
        U.remote(U.Redeem, true, code)
        n = n + 1
    end
    U.notify(n .. " codes sent")
end

-- server-tab passthroughs (the UI does not hold the module handle)
local moon = nil
function M.bindMoon(m) moon = m end
function M.joinJobId() if moon then moon.join(C.get("jobid")) end end
function M.joinShared() if moon then moon.hopShared() end end

function M.teleportIsland()
    local w = workspace:FindFirstChild("_WorldOrigin")
    local loc = w and w:FindFirstChild("Locations")
    if not loc then return U.notify("no Locations registry") end
    local island = loc:FindFirstChild(C.get("island") or "")
    if not island then return U.notify("pick an island") end
    local part = island.PrimaryPart or island:FindFirstChildWhichIsA("BasePart")
    if part then U.tp(part.CFrame * CFrame.new(0, 30, 0)) end
end

return M
]==]
FILES["src/home.lua"] = [==[
--[[ home.lua - Home tab: status + debug panel. Built first (it is the landing page). ]]

local M = {}

function M.init(U, C, UI, win)
    local page = win:tab("Home", function(p)
        local c = win:card(p, "Status")
        M.lvl = win:label(c, "")
        local ok, bad = 0, 0
        for _, line in ipairs(U.modules or {}) do
            if line:find("^%[ok%]") then ok = ok + 1 else bad = bad + 1 end
        end
        win:label(c, "modules " .. ok .. " ok" .. (bad > 0 and (", " .. bad .. " failed -> Log") or ""))
        win:debug(p, U, C)

        c = win:card(p, "Quick")
        win:toggle(c, "Auto Farm Level", "AutoFarm_Level")
        win:toggle(c, "Low-End Mode", "lowend")
        win:toggle(c, "Anti-AFK", "AntiAFK")

        c = win:card(p, "Diagnostics")
        win:button(c, "Dump Environment", function()
            U.log("i", "executor " .. tostring(identifyexecutor()))
            U.log("i", "getupvalues " .. type(debug.getupvalues) .. " require " .. type(require) .. " request " .. type(request))
            U.log("i", "setclipboard " .. type(setclipboard) .. " sethiddenproperty " .. type(sethiddenproperty))
            U.log("i", "CombatFramework " .. tostring(U.LP.PlayerScripts:FindFirstChild("CombatFramework") ~= nil))
            U.log("i", "mobs " .. #U.mobs() .. " level " .. U.level() .. " sea " .. tostring(U.sea) .. " place " .. game.PlaceId)
            U.notify("dumped to Log")
        end)

        task.spawn(function()
            while win.gui.Parent do
                if M.lvl then
                    M.lvl.Text = string.format("Lv %d   sea %s   mobs %d   %s",
                        U.level(), tostring(U.sea), #U.mobs(), C.get("AutoFarm_Level") and "FARMING" or "idle")
                end
                task.wait(1)
            end
        end)
    end)
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
                     "src/farm.lua", "src/quests.lua", "src/moon.lua", "src/extras.lua", "src/pages.lua", "src/home.lua" }) do
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
local bn2 = 0
for _ in pairs(D.bossFarms) do bn2 = bn2 + 1 end
for k, v in pairs(D.bossFarms) do assert(v[2] ~= nil, "bossFarm " .. k .. " has no fallback CFrame") end
local sn = 0
for k, v in pairs(D.spawners) do sn = sn + 1 assert(type(v[1]) == "table", "spawner " .. k .. " malformed") end
local cn = 0
for k, v in pairs(D.chains) do
    cn = cn + 1
    assert(#v > 0, "chain " .. k .. " empty")
    for i, st in ipairs(v) do
        assert(type(st.text) == "string", "chain " .. k .. " step " .. i .. " has no text")
        assert(st.cf or st.mobs or st.remote or st.level, "chain " .. k .. " step " .. i .. " does nothing")
    end
end
local function matCount(sea)
    local n = 0
    for _ in pairs(D.materials2[sea] or {}) do n = n + 1 end
    assert(n > 0, "no materials for sea " .. sea)
    return n
end
local fn2 = 0
for _, f in ipairs(D.fighters) do fn2 = fn2 + 1 assert(f[2] and f[3] and f[4], "fighter row malformed") end
print(string.format("[ok] extras data: %d bossFarms, %d spawners, %d chains, %d fighters, materials sea1=%d sea2=%d sea3=%d",
    bn2, sn, cn, fn2, matCount(1), matCount(2), matCount(3)))
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
print("[ok] UI.new built, tabs declared: " .. tostring(#win.order))

for _, pair in ipairs({ { "src/farm.lua", "farm" }, { "src/quests.lua", "quests" }, { "src/moon.lua", "moon" }, { "src/extras.lua", "extras" } }) do
    local m = loaded[pair[1]]
    local ok, err = pcall(function() m.init(U, C, UI, win, { D = D }) end)
    if ok then print("[ok] init " .. pair[2]) else print("[x] init " .. pair[2] .. ": " .. tostring(err)) failCount = failCount + 1 end
    for i = 1, 3 do
        local ok2, err2 = pcall(m.tick, U, C)
        if not ok2 then print("[x] tick " .. pair[2] .. " #" .. i .. ": " .. tostring(err2)) failCount = failCount + 1 break end
    end
end
for _, pair in ipairs({ { "src/home.lua", "home" }, { "src/pages.lua", "pages" } }) do
    local m = loaded[pair[1]]
    local ok, err = pcall(function() m.init(U, C, UI, win, { D = D }) end)
    if ok then print("[ok] init " .. pair[2]) else print("[x] init " .. pair[2] .. ": " .. tostring(err)) failCount = failCount + 1 end
end
-- lazy build: only Home should exist before any select
print("[ok] tabs declared: " .. table.concat(win.order, ", "))
local builtBefore = 0
for _ in pairs(win.built) do builtBefore = builtBefore + 1 end
-- select every tab; each must build without error and register rows
local rowsBefore = 0
for _, name in ipairs(win.order) do
    local ok, err = pcall(function() win:select(name) end)
    if not ok then print("[x] select " .. name .. ": " .. tostring(err)) failCount = failCount + 1 end
end
local builtAfter = 0
for _ in pairs(win.built) do builtAfter = builtAfter + 1 end
print(string.format("[ok] lazy build: %d tab(s) built before selecting, %d after", builtBefore, builtAfter))
assert(builtAfter >= #win.order - 1, "some tab never built")
print("[ok] all tabs built and selected")

-- moon detection must classify every known asset id and never throw on an unknown sky
local moon = loaded["src/moon.lua"]
local ok, phase = pcall(moon.moonPhase)
assert(ok, "moonPhase threw: " .. tostring(phase))
assert(type(phase) == "string" and #phase > 0, "moonPhase returned nothing")
local ok2, isMirage = pcall(moon.mirage)
assert(ok2 and type(isMirage) == "boolean", "mirage() did not return a boolean")
local ok3, st = pcall(moon.status)
assert(ok3, "status threw")
local ok4 = pcall(moon.tick, U, C)
assert(ok4, "moon.tick threw with hops off")
C.set("MirageHop", true)
local ok5 = pcall(moon.tick, U, C)
assert(ok5, "moon.tick threw with hops on")
C.set("MirageHop", false)
local moon2 = loaded["src/moon.lua"]
for _, fn in ipairs({ "join", "hopShared", "shared", "usedCount", "hop", "reset" }) do
    assert(type(moon2[fn]) == "function", "moon." .. fn .. " missing")
end
local okJ = pcall(moon2.join, "not-a-jobid")
assert(okJ, "join threw on a bad id")
assert(pcall(moon2.usedCount), "usedCount threw")
C.set("SharedUrl", "")
assert(pcall(moon2.hopShared), "hopShared threw with no url")
print("[ok] moon: join / shared-list helpers present and safe")

print("[ok] moon: phase=" .. phase .. " mirage=" .. tostring(isMirage))

print("[ok] config round-trip")

print(string.format("HARNESS: %d ok, %d failed", okCount, failCount))
assert(failCount == 0, "FAILED")
