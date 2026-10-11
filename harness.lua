-- Offline harness (no io in the standalone luau sandbox, so sources are embedded).
-- Checks the contract the entry relies on: every module must return a table or a
-- factory that yields a table, and every init() must run without error.
local FILES = {}
FILES["src/util.lua"] = [==[
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
]==]
FILES["src/config.lua"] = [==[
--[[ config.lua - flat state store. Toggles are plain booleans keyed by name,
     shared by the UI rows and the feature modules. ]]

local C = {}

C.values = {
    -- farm
    farm = false,
    autoquest = true,
    farmdistance = 20,
    orbit = true,
    bring = true,
    bringdist = 250,
    -- travel
    tween = true,
    tweenspeed = 170,
    hover = true,
    noclip = true,
    -- combat
    weapon = "Melee",
    method = "m1",
    fastattack = true,
    attackdist = 60,
    killaura = false,
    aura = 120,
    autobuso = true,
    autoken = true,
    -- player
    autostat = false,
    stat = "Melee",
    heal = false,
    -- misc
    esp = false,
    lowend = false,
    antiafk = false,
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
FILES["src/quests.lua"] = [==[
--[[ quests.lua - level -> {minLv, maxLv, mob, questName, questNum, questGiverCF, mobCF}.
     Generated from the public quest table used by open-source Blox Fruits hubs.
     ponytail: static snapshot - if the game adds levels, add a row; the farm loop only
     needs the row matching player.Data.Level.Value. ]]

local Q = {}

Q[1] = {
    { 1, 9, "Bandit", "BanditQuest1", 1, CFrame.new(1059.37195, 15.4495068, 1550.4231, 0.939700544, -0, -0.341998369, 0, 1, -0, 0.341998369, 0, 0.939700544), CFrame.new(1045.962646484375, 27.00250816345215, 1560.8203125) },
    { 10, 14, "Monkey", "JungleQuest", 1, CFrame.new(-1598.08911, 35.5501175, 153.377838, 0, 0, 1, 0, 1, -0, -1, 0, 0), CFrame.new(-1448.51806640625, 67.85301208496094, 11.46579647064209) },
    { 15, 29, "Gorilla", "JungleQuest", 2, CFrame.new(-1598.08911, 35.5501175, 153.377838, 0, 0, 1, 0, 1, -0, -1, 0, 0), CFrame.new(-1129.8836669921875, 40.46354675292969, -525.4237060546875) },
    { 30, 39, "Pirate", "BuggyQuest1", 1, CFrame.new(-1141.07483, 4.10001802, 3831.5498, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627), CFrame.new(-1103.513427734375, 13.752052307128906, 3896.091064453125) },
    { 40, 59, "Brute", "BuggyQuest1", 2, CFrame.new(-1141.07483, 4.10001802, 3831.5498, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627), CFrame.new(-1140.083740234375, 14.809885025024414, 4322.92138671875) },
    { 60, 74, "Desert Bandit", "DesertQuest", 1, CFrame.new(894.488647, 5.14000702, 4392.43359, 0.819155693, -0, -0.573571265, 0, 1, -0, 0.573571265, 0, 0.819155693), CFrame.new(924.7998046875, 6.44867467880249, 4481.5859375) },
    { 75, 89, "Desert Officer", "DesertQuest", 2, CFrame.new(894.488647, 5.14000702, 4392.43359, 0.819155693, -0, -0.573571265, 0, 1, -0, 0.573571265, 0, 0.819155693), CFrame.new(1608.2822265625, 8.614224433898926, 4371.00732421875) },
    { 90, 99, "Snow Bandit", "SnowQuest", 1, CFrame.new(1389.74451, 88.1519318, -1298.90796, -0.342042685, 0, 0.939684391, 0, 1, 0, -0.939684391, 0, -0.342042685), CFrame.new(1354.347900390625, 87.27277374267578, -1393.946533203125) },
    { 100, 119, "Snowman", "SnowQuest", 2, CFrame.new(1389.74451, 88.1519318, -1298.90796, -0.342042685, 0, 0.939684391, 0, 1, 0, -0.939684391, 0, -0.342042685), CFrame.new(1201.6412353515625, 144.57958984375, -1550.0670166015625) },
    { 120, 149, "Chief Petty Officer", "MarineQuest2", 1, CFrame.new(-5039.58643, 27.3500385, 4324.68018, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-4881.23095703125, 22.65204429626465, 4273.75244140625) },
    { 150, 174, "Sky Bandit", "SkyQuest", 1, CFrame.new(-4839.53027, 716.368591, -2619.44165, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), CFrame.new(-4953.20703125, 295.74420166015625, -2899.22900390625) },
    { 175, 189, "Dark Master", "SkyQuest", 2, CFrame.new(-4839.53027, 716.368591, -2619.44165, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), CFrame.new(-5259.8447265625, 391.3976745605469, -2229.035400390625) },
    { 190, 209, "Prisoner", "PrisonerQuest", 1, CFrame.new(5308.93115, 1.65517521, 475.120514, -0.0894274712, -5.00292918e-09, -0.995993316, 1.60817859e-09, 1, -5.16744869e-09, 0.995993316, -2.06384709e-09, -0.0894274712), CFrame.new(5098.9736328125, -0.3204058110713959, 474.2373352050781) },
    { 210, 249, "Dangerous Prisoner", "PrisonerQuest", 2, CFrame.new(5308.93115, 1.65517521, 475.120514, -0.0894274712, -5.00292918e-09, -0.995993316, 1.60817859e-09, 1, -5.16744869e-09, 0.995993316, -2.06384709e-09, -0.0894274712), CFrame.new(5654.5634765625, 15.633401870727539, 866.2991943359375) },
    { 250, 274, "Toga Warrior", "ColosseumQuest", 1, CFrame.new(-1580.04663, 6.35000277, -2986.47534, -0.515037298, 0, -0.857167721, 0, 1, 0, 0.857167721, 0, -0.515037298), CFrame.new(-1820.21484375, 51.68385696411133, -2740.6650390625) },
    { 275, 299, "Gladiator", "ColosseumQuest", 2, CFrame.new(-1580.04663, 6.35000277, -2986.47534, -0.515037298, 0, -0.857167721, 0, 1, 0, 0.857167721, 0, -0.515037298), CFrame.new(-1292.838134765625, 56.380882263183594, -3339.031494140625) },
    { 300, 324, "Military Soldier", "MagmaQuest", 1, CFrame.new(-5313.37012, 10.9500084, 8515.29395, -0.499959469, 0, 0.866048813, 0, 1, 0, -0.866048813, 0, -0.499959469), CFrame.new(-5411.16455078125, 11.081554412841797, 8454.29296875) },
    { 325, 374, "Military Spy", "MagmaQuest", 2, CFrame.new(-5313.37012, 10.9500084, 8515.29395, -0.499959469, 0, 0.866048813, 0, 1, 0, -0.866048813, 0, -0.499959469), CFrame.new(-5802.8681640625, 86.26241302490234, 8828.859375) },
    { 375, 399, "Fishman Warrior", "FishmanQuest", 1, CFrame.new(61122.65234375, 18.497442245483, 1569.3997802734), CFrame.new(60878.30078125, 18.482830047607422, 1543.7574462890625) },
    { 400, 449, "Fishman Commando", "FishmanQuest", 2, CFrame.new(61122.65234375, 18.497442245483, 1569.3997802734), CFrame.new(61922.6328125, 18.482830047607422, 1493.934326171875) },
    { 450, 474, "God's Guard", "SkyExp1Quest", 1, CFrame.new(-4721.88867, 843.874695, -1949.96643, 0.996191859, -0, -0.0871884301, 0, 1, -0, 0.0871884301, 0, 0.996191859), CFrame.new(-4710.04296875, 845.2769775390625, -1927.3079833984375) },
    { 475, 524, "Shanda", "SkyExp1Quest", 2, CFrame.new(-7859.09814, 5544.19043, -381.476196, -0.422592998, 0, 0.906319618, 0, 1, 0, -0.906319618, 0, -0.422592998), CFrame.new(-7678.48974609375, 5566.40380859375, -497.2156066894531) },
    { 525, 549, "Royal Squad", "SkyExp2Quest", 1, CFrame.new(-7906.81592, 5634.6626, -1411.99194, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-7624.25244140625, 5658.13330078125, -1467.354248046875) },
    { 550, 624, "Royal Soldier", "SkyExp2Quest", 2, CFrame.new(-7906.81592, 5634.6626, -1411.99194, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-7836.75341796875, 5645.6640625, -1790.6236572265625) },
    { 625, 649, "Galley Pirate", "FountainQuest", 1, CFrame.new(5259.81982, 37.3500175, 4050.0293, 0.087131381, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, 0.087131381), CFrame.new(5551.02197265625, 78.90135192871094, 3930.412841796875) },
    { 650, 650, "Galley Captain", "FountainQuest", 2, CFrame.new(5259.81982, 37.3500175, 4050.0293, 0.087131381, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, 0.087131381), CFrame.new(5441.95166015625, 42.50205993652344, 4950.09375) },
}

Q[2] = {
    { 700, 724, "Raider", "Area1Quest", 1, CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985), CFrame.new(-728.3267211914062, 52.779319763183594, 2345.7705078125) },
    { 725, 774, "Mercenary", "Area1Quest", 2, CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985), CFrame.new(-1004.3244018554688, 80.15886688232422, 1424.619384765625) },
    { 775, 799, "Swan Pirate", "Area2Quest", 1, CFrame.new(638.43811, 71.769989, 918.282898, 0.139203906, 0, 0.99026376, 0, 1, 0, -0.99026376, 0, 0.139203906), CFrame.new(1068.664306640625, 137.61428833007812, 1322.1060791015625) },
    { 800, 874, "Factory Staff", "Area2Quest", 2, CFrame.new(632.698608, 73.1055908, 918.666321, -0.0319722369, 8.96074881e-10, -0.999488771, 1.36326533e-10, 1, 8.92172336e-10, 0.999488771, -1.07732087e-10, -0.0319722369), CFrame.new(73.07867431640625, 81.86344146728516, -27.470672607421875) },
    { 875, 899, "Marine Lieutenant", "MarineQuest3", 1, CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), CFrame.new(-2821.372314453125, 75.89727783203125, -3070.089111328125) },
    { 900, 949, "Marine Captain", "MarineQuest3", 2, CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268), CFrame.new(-1861.2310791015625, 80.17658233642578, -3254.697509765625) },
    { 950, 974, "Zombie", "ZombieQuest", 1, CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146), CFrame.new(-5657.77685546875, 78.96973419189453, -928.68701171875) },
    { 975, 999, "Vampire", "ZombieQuest", 2, CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146), CFrame.new(-6037.66796875, 32.18463897705078, -1340.6597900390625) },
    { 1000, 1049, "Snow Trooper", "SnowMountainQuest", 1, CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106), CFrame.new(549.1473388671875, 427.3870544433594, -5563.69873046875) },
    { 1050, 1099, "Winter Warrior", "SnowMountainQuest", 2, CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106), CFrame.new(1142.7451171875, 475.6398010253906, -5199.41650390625) },
    { 1100, 1124, "Lab Subordinate", "IceSideQuest", 1, CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, -0, -0.891015649, 0, 1, -0, 0.891015649, 0, 0.453972578), CFrame.new(-5707.4716796875, 15.951709747314453, -4513.39208984375) },
    { 1125, 1174, "Horned Warrior", "IceSideQuest", 2, CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, -0, -0.891015649, 0, 1, -0, 0.891015649, 0, 0.453972578), CFrame.new(-6341.36669921875, 15.951770782470703, -5723.162109375) },
    { 1175, 1199, "Magma Ninja", "FireSideQuest", 1, CFrame.new(-5428.03174, 15.0622921, -5299.43457, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), CFrame.new(-5449.6728515625, 76.65874481201172, -5808.20068359375) },
    { 1200, 1249, "Lava Pirate", "FireSideQuest", 2, CFrame.new(-5428.03174, 15.0622921, -5299.43457, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), CFrame.new(-5213.33154296875, 49.73788070678711, -4701.451171875) },
    { 1250, 1274, "Ship Deckhand", "ShipQuest1", 1, CFrame.new(1037.80127, 125.092171, 32911.6016), CFrame.new(1212.0111083984375, 150.79205322265625, 33059.24609375) },
    { 1275, 1299, "Ship Engineer", "ShipQuest1", 2, CFrame.new(1037.80127, 125.092171, 32911.6016), CFrame.new(919.4786376953125, 43.54401397705078, 32779.96875) },
    { 1300, 1324, "Ship Steward", "ShipQuest2", 1, CFrame.new(968.80957, 125.092171, 33244.125), CFrame.new(919.4385375976562, 129.55599975585938, 33436.03515625) },
    { 1325, 1349, "Ship Officer", "ShipQuest2", 2, CFrame.new(968.80957, 125.092171, 33244.125), CFrame.new(1036.0179443359375, 181.4390411376953, 33315.7265625) },
    { 1350, 1374, "Arctic Warrior", "FrostQuest", 1, CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909), CFrame.new(5966.24609375, 62.97002029418945, -6179.3828125) },
    { 1375, 1424, "Snow Lurker", "FrostQuest", 2, CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909), CFrame.new(5407.07373046875, 69.19437408447266, -6880.88037109375) },
    { 1425, 1449, "Sea Soldier", "ForgottenQuest", 1, CFrame.new(-3054.44458, 235.544281, -10142.8193, 0.990270376, -0, -0.13915664, 0, 1, -0, 0.13915664, 0, 0.990270376), CFrame.new(-3028.2236328125, 64.67451477050781, -9775.4267578125) },
    { 1450, 1450, "Water Fighter", "ForgottenQuest", 2, CFrame.new(-3054.44458, 235.544281, -10142.8193, 0.990270376, -0, -0.13915664, 0, 1, -0, 0.13915664, 0, 0.990270376), CFrame.new(-3352.9013671875, 285.01556396484375, -10534.841796875) },
}

Q[3] = {
    { 1500, 1524, "Pirate Millionaire", "PiratePortQuest", 1, CFrame.new(-290.074677, 42.9034653, 5581.58984, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627), CFrame.new(-245.9963836669922, 47.30615234375, 5584.1005859375) },
    { 1525, 1574, "Pistol Billionaire", "PiratePortQuest", 2, CFrame.new(-290.074677, 42.9034653, 5581.58984, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627), CFrame.new(-187.3301544189453, 86.23987579345703, 6013.513671875) },
    { 1575, 1599, "Dragon Crew Warrior", "AmazonQuest", 1, CFrame.new(5832.83594, 51.6806107, -1101.51563, 0.898790359, -0, -0.438378751, 0, 1, -0, 0.438378751, 0, 0.898790359), CFrame.new(6141.140625, 51.35136413574219, -1340.738525390625) },
    { 1600, 1624, "Dragon Crew Archer", "AmazonQuest", 2, CFrame.new(5833.1147460938, 51.60498046875, -1103.0693359375), CFrame.new(6616.41748046875, 441.7670593261719, 446.0469970703125) },
    { 1625, 1649, "Female Islander", "AmazonQuest2", 1, CFrame.new(5446.8793945313, 601.62945556641, 749.45672607422), CFrame.new(4685.25830078125, 735.8078002929688, 815.3425903320312) },
    { 1650, 1699, "Giant Islander", "AmazonQuest2", 2, CFrame.new(5446.8793945313, 601.62945556641, 749.45672607422), CFrame.new(4729.09423828125, 590.436767578125, -36.97627639770508) },
    { 1700, 1724, "Marine Commodore", "MarineTreeIsland", 1, CFrame.new(2180.54126, 27.8156815, -6741.5498, -0.965929747, 0, 0.258804798, 0, 1, 0, -0.258804798, 0, -0.965929747), CFrame.new(2286.0078125, 73.13391876220703, -7159.80908203125) },
    { 1725, 1774, "Marine Rear Admiral", "MarineTreeIsland", 2, CFrame.new(2179.98828125, 28.731239318848, -6740.0551757813), CFrame.new(3656.773681640625, 160.52406311035156, -7001.5986328125) },
    { 1775, 1799, "Fishman Raider", "DeepForestIsland3", 1, CFrame.new(-10581.6563, 330.872955, -8761.18652, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), CFrame.new(-10407.5263671875, 331.76263427734375, -8368.5166015625) },
    { 1800, 1824, "Fishman Captain", "DeepForestIsland3", 2, CFrame.new(-10581.6563, 330.872955, -8761.18652, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213), CFrame.new(-10994.701171875, 352.38140869140625, -9002.1103515625) },
    { 1825, 1849, "Forest Pirate", "DeepForestIsland", 1, CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, -0, -0.707079291, 0, 1, -0, 0.707079291, 0, 0.707134247), CFrame.new(-13274.478515625, 332.3781433105469, -7769.58056640625) },
    { 1850, 1899, "Mythological Pirate", "DeepForestIsland", 2, CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, -0, -0.707079291, 0, 1, -0, 0.707079291, 0, 0.707134247), CFrame.new(-13680.607421875, 501.08154296875, -6991.189453125) },
    { 1900, 1924, "Jungle Pirate", "DeepForestIsland2", 1, CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002), CFrame.new(-12256.16015625, 331.73828125, -10485.8369140625) },
    { 1925, 1974, "Musketeer Pirate", "DeepForestIsland2", 2, CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002), CFrame.new(-13457.904296875, 391.545654296875, -9859.177734375) },
    { 1975, 1999, "Reborn Skeleton", "HauntedQuest1", 1, CFrame.new(-9479.2168, 141.215088, 5566.09277, 0, 0, 1, 0, 1, -0, -1, 0, 0), CFrame.new(-8763.7236328125, 165.72299194335938, 6159.86181640625) },
    { 2000, 2024, "Living Zombie", "HauntedQuest1", 2, CFrame.new(-9479.2168, 141.215088, 5566.09277, 0, 0, 1, 0, 1, -0, -1, 0, 0), CFrame.new(-10144.1318359375, 138.62667846679688, 5838.0888671875) },
    { 2025, 2049, "Demonic Soul", "HauntedQuest2", 1, CFrame.new(-9516.99316, 172.017181, 6078.46533, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-9505.8720703125, 172.10482788085938, 6158.9931640625) },
    { 2050, 2074, "Posessed Mummy", "HauntedQuest2", 2, CFrame.new(-9516.99316, 172.017181, 6078.46533, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-9582.0224609375, 6.251527309417725, 6205.478515625) },
    { 2075, 2099, "Peanut Scout", "NutsIslandQuest", 1, CFrame.new(-2104.3908691406, 38.104167938232, -10194.21875, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-2143.241943359375, 47.72198486328125, -10029.9951171875) },
    { 2100, 2124, "Peanut President", "NutsIslandQuest", 2, CFrame.new(-2104.3908691406, 38.104167938232, -10194.21875, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-1859.35400390625, 38.10316848754883, -10422.4296875) },
    { 2125, 2149, "Ice Cream Chef", "IceCreamIslandQuest", 1, CFrame.new(-820.64825439453, 65.819526672363, -10965.795898438, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-872.24658203125, 65.81957244873047, -10919.95703125) },
    { 2150, 2199, "Ice Cream Commander", "IceCreamIslandQuest", 2, CFrame.new(-820.64825439453, 65.819526672363, -10965.795898438, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-558.06103515625, 112.04895782470703, -11290.7744140625) },
    { 2200, 2224, "Cookie Crafter", "CakeQuest1", 1, CFrame.new(-2021.32007, 37.7982254, -12028.7295, 0.957576931, -8.80302053e-08, 0.288177818, 6.9301187e-08, 1, 7.51931211e-08, -0.288177818, -5.2032135e-08, 0.957576931), CFrame.new(-2374.13671875, 37.79826354980469, -12125.30859375) },
    { 2225, 2249, "Cake Guard", "CakeQuest1", 2, CFrame.new(-2021.32007, 37.7982254, -12028.7295, 0.957576931, -8.80302053e-08, 0.288177818, 6.9301187e-08, 1, 7.51931211e-08, -0.288177818, -5.2032135e-08, 0.957576931), CFrame.new(-1598.3070068359375, 43.773197174072266, -12244.5810546875) },
    { 2250, 2274, "Baking Staff", "CakeQuest2", 1, CFrame.new(-1927.91602, 37.7981339, -12842.5391, -0.96804446, 4.22142143e-08, 0.250778586, 4.74911062e-08, 1, 1.49904711e-08, -0.250778586, 2.64211941e-08, -0.96804446), CFrame.new(-1887.8099365234375, 77.6185073852539, -12998.3505859375) },
    { 2275, 2299, "Head Baker", "CakeQuest2", 2, CFrame.new(-1927.91602, 37.7981339, -12842.5391, -0.96804446, 4.22142143e-08, 0.250778586, 4.74911062e-08, 1, 1.49904711e-08, -0.250778586, 2.64211941e-08, -0.96804446), CFrame.new(-2216.188232421875, 82.884521484375, -12869.2939453125) },
    { 2300, 2324, "Cocoa Warrior", "ChocQuest1", 1, CFrame.new(233.22836303710938, 29.876001358032227, -12201.2333984375), CFrame.new(-21.55328369140625, 80.57499694824219, -12352.3876953125) },
    { 2325, 2349, "Chocolate Bar Battler", "ChocQuest1", 2, CFrame.new(233.22836303710938, 29.876001358032227, -12201.2333984375), CFrame.new(582.590576171875, 77.18809509277344, -12463.162109375) },
    { 2350, 2374, "Sweet Thief", "ChocQuest2", 1, CFrame.new(150.5066375732422, 30.693693161010742, -12774.5029296875), CFrame.new(165.1884765625, 76.05885314941406, -12600.8369140625) },
    { 2375, 2399, "Candy Rebel", "ChocQuest2", 2, CFrame.new(150.5066375732422, 30.693693161010742, -12774.5029296875), CFrame.new(134.86563110351562, 77.2476806640625, -12876.5478515625) },
    { 2400, 2424, "Candy Pirate", "CandyQuest1", 1, CFrame.new(-1150.0400390625, 20.378934860229492, -14446.3349609375), CFrame.new(-1310.5003662109375, 26.016523361206055, -14562.404296875) },
    { 2425, 2449, "Snow Demon", "CandyQuest1", 2, CFrame.new(-1150.0400390625, 20.378934860229492, -14446.3349609375), CFrame.new(-880.2006225585938, 71.24776458740234, -14538.609375) },
    { 2450, 2474, "Isle Outlaw", "TikiQuest1", 1, CFrame.new(-16545.9355, 55.6863556, -173.230499), CFrame.new(-16120.6035, 116.520554, -103.038849) },
    { 2475, 2499, "Island Boy", "TikiQuest1", 2, CFrame.new(-16545.9355, 55.6863556, -173.230499), CFrame.new(-16751.3125, 121.226219, -264.015015) },
    { 2500, 2524, "Sun-kissed Warrio", "TikiQuest2", 1, CFrame.new(-16539.078125, 55.68632888793945, 1051.5738525390625), CFrame.new(-16294.6748, 32.7874393, 1062.4856) },
    { 2525, 2525, "Isle Champion", "TikiQuest2", 2, CFrame.new(-16539.078125, 55.68632888793945, 1051.5738525390625), CFrame.new(-16933.2129, 93.3503036, 999.450989) },
}

-- highest row whose range contains level ("for" is reserved, hence .at)
function Q.at(sea, level)
    local t = Q[sea]
    if not t then return nil end
    for _, r in ipairs(t) do
        if level >= r[1] and level <= r[2] then return r end
    end
    return t[#t]
end

return Q]==]
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
--[[ farm.lua - auto farm level. No UI here; farm.lua only exposes tick(). ]]

local M = {}
local Q = nil

function M.init(U, C, UI, win, deps)
    M.U, M.C = U, C
    M.Q = deps and deps.Q
end

local function sea(U)
    if U.LP.Data:FindFirstChild("Level") == nil then return 1 end
    -- island names are the reliable sea signal when PlaceId is a subplace
    local loc = workspace:FindFirstChild("_WorldOrigin")
    loc = loc and loc:FindFirstChild("Locations")
    local n = loc and loc:GetChildren() and #loc:GetChildren() or 0
    if game.PlaceId == 7449423635 then return 3 end
    if game.PlaceId == 4442272183 then return 2 end
    if game.PlaceId == 2753915549 then return 1 end
    return n > 30 and 3 or (n > 15 and 2 or 1)
end

local function travel(U, C, cf)
    if C.get("tween") then
        U.tweenTo(cf, C.get("tweenspeed"))
    else
        U.tp(cf)
    end
end

-- level up -> new quest row. Accepting teleports to the giver first: the call is
-- ignored when the player is nowhere near it.
local function ensureQuest(U, C)
    local lv = U.level()
    if M.quest and lv >= M.quest[1] and lv <= M.quest[2] then return end
    M.quest = M.Q and M.Q.at(sea(U), lv)
    if not M.quest then return end
    local _, mon, nq, num, cfq = table.unpack(M.quest)
    U.log("i", string.format("quest Lv%d -> %s (%s #%d)", lv, mon, nq, num))
    travel(U, C, cfq * CFrame.new(0, 5, 0))
    task.wait(C.get("tween") and 0.35 or 0.1)
    U.F("StartQuest", nq, num)
end

function M.tick(U, C)
    if not C.get("farm") or not U.alive() then return end
    ensureQuest(U, C)
    if not M.quest then return end

    local _, mon, _, _, _, cfm = table.unpack(M.quest)
    local mob = U.nearestMob(mon)
    if not mob then
        -- respawn wait: walk to the recorded mob spot instead of standing still
        travel(U, C, cfm * CFrame.new(0, 10, 0))
        return
    end

    U.noclip(C.get("noclip"))
    U.equip(C.get("weapon"))
    if C.get("autobuso") or C.get("autoken") then U.autoHaki() end
    if C.get("heal") then
        local h = U.hum()
        if h and h.Health / h.MaxHealth < 0.3 then U.F("Heal") end
    end

    -- orbit keeps re-crossing the hitbox; parking above it often hits nothing
    local d = C.get("farmdistance")
    local dest = C.get("orbit") and U.orbit(mob, d) or (mob.HumanoidRootPart.CFrame + Vector3.new(0, d, 0))
    travel(U, C, dest)
    U.hover(C.get("hover"))

    if C.get("bring") then U.bringMobs(mon) end

    -- clicks only land in range; skip the swing when still far away
    local root = U.root()
    if root and (mob.HumanoidRootPart.Position - root.Position).Magnitude < 45 then
        if C.get("method") == "net" then U.netAttack(C.get("attackdist")) else U.attack(C.get("attackdist")) end
    end
end

return M
]==]
FILES["src/extras.lua"] = [==[
--[[ extras.lua - combat helpers + ESP, quest teleport, stats, low-end mode. ]]

local M = {}

function M.init(U, C)
    M.U, M.C = U, C
    -- lowend touches every descendant: apply on change, not every tick
    C.onChange = function(k)
        if k == "lowend" then M.lowend(U, C) end
    end
    M.lowend(U, C)
end

-- kill aura: snap onto the cluster BEFORE swinging, a distant swing misses.
function M.aura(U, C)
    if not C.get("killaura") or not U.alive() then return end
    local mob = U.nearestMob()
    if not mob then return end
    local root = U.root()
    if root then root.CFrame = mob.HumanoidRootPart.CFrame + Vector3.new(0, 12, 0) end
    U.equip(C.get("weapon"))
    if C.get("method") == "net" then U.netAttack(C.get("aura")) else U.attack(C.get("aura")) end
end

-- ESP: reuse the existing tag, never destroy+recreate per tick (main mobile lag source).
local tags = {}
function M.esp(U, C)
    local want = C.get("esp")
    if not want then
        for _, t in pairs(tags) do pcall(function() t:Destroy() end) end
        tags = {}
        return
    end
    local seen = {}
    for _, m in ipairs(U.mobs()) do
        seen[m] = true
        local hrp = m:FindFirstChild("HumanoidRootPart")
        if hrp then
            local tag = tags[m]
            if not tag or not tag.Parent then
                tag = Instance.new("BillboardGui")
                tag.Name = "BFHubESP"
                tag.Size = UDim2.fromOffset(110, 30)
                tag.StudsOffset = Vector3.new(0, 3, 0)
                tag.AlwaysOnTop = true
                tag.Adornee = hrp
                tag.Parent = hrp
                local tl = Instance.new("TextLabel")
                tl.Size = UDim2.fromScale(1, 1)
                tl.BackgroundTransparency = 1
                tl.Font = Enum.Font.GothamBold
                tl.TextSize = 12
                tl.TextStrokeTransparency = 0.3
                tl.TextColor3 = Color3.fromRGB(255, 235, 120)
                tl.Parent = tag
                tags[m] = tag
            end
            local tl = tag:FindFirstChildOfClass("TextLabel")
            if tl then tl.Text = U.baseName(m.Name) end
        end
    end
    for m, t in pairs(tags) do
        if not seen[m] then pcall(function() t:Destroy() end) tags[m] = nil end
    end
end

-- low-end mode: what actually costs frames on mobile
local originals = {}
function M.lowend(U, C)
    local on = C.get("lowend")
    local l = game:GetService("Lighting")
    if on then
        originals.global = originals.global or l.GlobalShadows
        originals.tech = originals.tech or l.Technology
        l.GlobalShadows = false
        pcall(function() l.Technology = Enum.Technology.Compatibility end)
        pcall(function() game:GetService("UserInputService").MouseIconEnabled = true end)
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

-- auto stat point: AddPoint takes the stat name; only fires when a point exists.
function M.stats(U, C)
    if not C.get("autostat") then return end
    local d = U.LP:FindFirstChild("Data")
    local pts = d and d:FindFirstChild("Points")
    local n = pts and pts.Value or 0
    if n and n > 0 then U.F("AddPoint", C.get("stat"), n) end
end

-- anti-AFK: fires the idle event the server watches
function M.antiafk(U, C)
    if C.get("antiafk") then
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new(0, 0))
    end
end

function M.tick(U, C)
    M.aura(U, C)
    M.esp(U, C)
    M.stats(U, C)
    M.antiafk(U, C)
end

return M
]==]
FILES["src/pages.lua"] = [==[
--[[ pages.lua - Farm / Combat / Player / Misc tabs. UI only: every toggle writes
     into the shared config store that farm.lua and extras.lua read each tick. ]]

local M = {}

function M.init(U, C, UI, win)
    M.U, M.C = U, C

    -- Farm ---------------------------------------------------------------
    local p = win:tab("Farm")
    local c = win:card(p, "Auto Farm")
    win:toggle(c, "Auto Farm Level", "kill quest mobs for your level", "farm")
    win:toggle(c, "Auto Quest", "accept the quest automatically", "autoquest")
    win:slider(c, "Farm Distance", "farmdistance", 5, 60, 1)
    win:toggle(c, "Orbit Target", "circle the mob so hits keep landing", "orbit")

    c = win:card(p, "Bring Mobs")
    win:toggle(c, "Bring Mobs", "pin mobs + enlarge hitbox", "bring")
    win:slider(c, "Bring Distance", "bringdist", 50, 500, 10)

    c = win:card(p, "Travel")
    win:toggle(c, "Tween Travel", "smooth flight instead of instant teleport", "tween")
    win:slider(c, "Tween Speed", "tweenspeed", 60, 400, 10)
    win:toggle(c, "Fly / Hover", "hold position above the mob", "hover")
    win:toggle(c, "NoClip", nil, "noclip")
    win:button(c, "STOP TWEEN", "kill-switch for a stuck tween", function() U.stopTween() end)

    -- Combat -------------------------------------------------------------
    p = win:tab("Combat")
    c = win:card(p, "Attack")
    win:toggle(c, "Fast Attack", "zero cooldowns, real credited M1", "fastattack")
    win:slider(c, "Attack Range", "attackdist", 20, 200, 5)
    win:button(c, "Attack Method", "tap to switch m1 <-> net remote", function()
        C.set("method", C.get("method") == "m1" and "net" or "m1")
        U.notify("attack method: " .. C.get("method"))
    end)
    win:button(c, "Weapon", "tap to cycle Melee/Sword/Gun/Blox Fruit", function()
        local order = { "Melee", "Sword", "Gun", "Blox Fruit" }
        for i, w in ipairs(order) do
            if w == C.get("weapon") then
                C.set("weapon", order[i % #order + 1])
                return U.notify("weapon: " .. C.get("weapon"))
            end
        end
        C.set("weapon", "Melee")
    end)

    c = win:card(p, "Kill Aura")
    win:toggle(c, "Kill Aura", "long-range M1, snaps onto the mob first", "killaura")
    win:slider(c, "Aura Range", "aura", 40, 300, 10)
    win:label(c, "Instakill is not offered: writing Health client-side gives no money/exp.", Color3.fromRGB(230, 150, 150))

    c = win:card(p, "Haki / Heal")
    win:toggle(c, "Auto Buso", nil, "autobuso")
    win:toggle(c, "Auto Ken", nil, "autoken")
    win:toggle(c, "Heal When Low", "under 30% HP", "heal")

    -- Player -------------------------------------------------------------
    p = win:tab("Player")
    c = win:card(p, "Stats")
    win:toggle(c, "Auto Stat Point", "spend points as they arrive", "autostat")
    win:button(c, "Stat", "tap to cycle Melee/Sword/Gun/Defense/Blox Fruit", function()
        local order = { "Melee", "Sword", "Gun", "Defense", "Blox Fruit" }
        for i, s in ipairs(order) do
            if s == C.get("stat") then
                C.set("stat", order[i % #order + 1])
                return U.notify("stat: " .. C.get("stat"))
            end
        end
        C.set("stat", "Melee")
    end)
    win:button(c, "Check Boost", "read your current boosts", function()
        local r = U.F("CheckBoost")
        U.log("i", "boost: " .. tostring(r))
        U.notify("boost -> Log tab")
    end)

    c = win:card(p, "Race")
    win:button(c, "Race Reroll", "BlackbeardReward reroll 1", function() U.F("BlackbeardReward", "Reroll", "1") end)
    win:button(c, "Race Reroll (2)", "second reroll slot", function() U.F("BlackbeardReward", "Reroll", "2") end)
    win:button(c, "Stat Refund", "BlackbeardReward refund", function() U.F("BlackbeardReward", "Refund", "1") end)

    -- Misc ---------------------------------------------------------------
    p = win:tab("Misc")
    c = win:card(p, "World")
    win:toggle(c, "ESP Mobs", "name tags on enemies", "esp")
    win:button(c, "Teleport to Island", "reads the live Locations registry", function()
        local loc = workspace:FindFirstChild("_WorldOrigin")
        loc = loc and loc:FindFirstChild("Locations")
        if not loc then return U.notify("no Locations registry") end
        local names = {}
        for _, i in ipairs(loc:GetChildren()) do table.insert(names, i.Name) end
        U.log("i", "islands: " .. table.concat(names, ", "))
        U.notify(#names .. " islands -> Log tab")
    end)

    c = win:card(p, "Codes")
    win:button(c, "Redeem All Known Codes", "tries the current public code list", function()
        local codes = {
            "Sub2CaptainMaui", "DEVSCOOKING", "kittgaming", "Sub2Fer999", "Enyu_is_Pro",
            "Magicbus", "JCWK", "StarcodeHEO", "Bluxxy", "fudd10_v2", "Fudd10", "Bignews",
            "THEGREATACE", "SUB2GAMERROBOT_EXP1", "Sub2NoobMaster123", "Sub2UncleKizaru",
            "Sub2Daigrock", "AxiTpSword", "SwordTycoon",
        }
        for _, code in ipairs(codes) do
            if U.Redeem then U.remote(U.Redeem, true, code) end
        end
        U.notify("codes tried")
    end)

    c = win:card(p, "Log Webhook")
    win:label(c, "paste a Discord webhook URL here, then Log tab > Send")
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 24)
    box.BackgroundColor3 = Color3.fromRGB(22, 23, 28)
    box.TextColor3 = Color3.fromRGB(232, 234, 242)
    box.Font = Enum.Font.Gotham
    box.TextSize = 11
    box.Text = C.get("webhook")
    box.PlaceholderText = "https://discord.com/api/webhooks/..."
    box.ClearTextOnFocus = false
    box.Parent = c
    box:GetPropertyChangedSignal("Text"):Connect(function() C.set("webhook", box.Text) end)

    c = win:card(p, "Credits")
    win:label(c, "use an alt account. this is a cheat.")
    return M
end

return M
]==]
FILES["src/home.lua"] = [==[
--[[ home.lua - Home tab: status, module load results, Log tab, Credits. ]]

local M = {}

function M.init(U, C, UI, win)
    M.U, M.C, M.UI, M.win = U, C, UI, win

    local home = win:tab("Home")
    local st = win:card(home, "Status")
    M.lvl = win:label(st, "loading...")
    local body = win:label(st, "")

    -- module load report: a silent pcall around a module is what produces an
    -- empty menu with no error, so failures are printed here.
    local okCount, failCount = 0, 0
    for _, line in ipairs(U.modules or {}) do
        if string.find(line, "^%[ok%]") then okCount = okCount + 1 else failCount = failCount + 1 end
    end
    body.Text = "modules: " .. okCount .. " ok, " .. failCount .. " failed"
        .. (failCount > 0 and "\nsee Log tab" or "")

    win:debug(home, U, C)

    local cf = win:card(home, "Config")
    win:toggle(cf, "Auto Quest", "accept the quest matching your level", "autoquest")
    win:toggle(cf, "Low-End Mode", "kills particles + shadows (mobile fps)", "lowend")
    win:toggle(cf, "Anti-AFK", nil, "antiafk")
    win:button(cf, "Dump Environment", "executor capabilities + game state", function()
        U.log("i", "executor " .. tostring(identifyexecutor()))
        U.log("i", "debug.getupvalues " .. type(debug.getupvalues) .. "  require " .. type(require) .. "  request " .. type(request))
        U.log("i", "setclipboard " .. type(setclipboard) .. "  sethiddenproperty " .. type(sethiddenproperty))
        U.log("i", "CombatFramework " .. tostring(U.LP.PlayerScripts:FindFirstChild("CombatFramework") ~= nil))
        U.log("i", "RigControllerEvent " .. tostring(U.RS:FindFirstChild("RigControllerEvent") ~= nil))
        U.log("i", "mobs " .. #U.mobs() .. "  level " .. U.level() .. "  place " .. game.PlaceId)
        U.notify("dumped to Log tab")
    end)

    -- Log tab --------------------------------------------------------------
    local logp = win:tab("Log")
    local lc = win:card(logp, "Log")
    M.loglabel = win:label(lc, "")
    win:button(lc, "Copy to Clipboard", nil, function()
        pcall(function() setclipboard(U.logText()) end)
        U.notify("log copied")
    end)
    win:button(lc, "Clear", nil, function()
        U.logs = {}
        M.loglabel.Text = ""
    end)
    win:button(lc, "Send to Webhook", "URL set in Misc", function()
        local url = C.get("webhook")
        if url == "" then return U.notify("no webhook url") end
        pcall(function()
            local body = U.logText():sub(1, 1900)
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
            M.lvl.Text = string.format("Lv %d   sea %s   mobs %d", U.level(), tostring(game.PlaceId), #U.mobs())
            M.loglabel.Text = U.logText()
            task.wait(1)
        end
    end)

    -- Credits --------------------------------------------------------------
    local cr = win:tab("Credits")
    local cc = win:card(cr, "Credits")
    win:label(cc, "Raf's Personal Script - BFHub")
    win:label(cc, "keyless, open source, no obfuscation")
    win:label(cc, "quest table + farm loop order learned from public open-source hubs")
    win:label(cc, "this is a cheat - use an alt account")
    return M
end

return M
]==]

-- auto-vivifying mock; numeric keys return nil so ipairs terminates
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
            if k == "Magnitude" then return 1 end
            if k == "Unit" then return Vector3.new() end
            if k == "ViewportSize" then return Vector2.new() end
            if k == "X" or k == "Y" then return 1 end
            if k == "Value" then return 0 end
            local v = Any(k)
            rawset(self, k, v)
            return v
        end,
        __call = function() return Any() end,
        __len = function() return 0 end,
        __tostring = function() return "Any" end,
        __add = function() return Any() end,
        __sub = function() return Any() end,
        __mul = function() return Any() end,
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
game = setmetatable({ PlaceId = 7449423635, GameId = 994732206, HttpGet = function() error("offline") end,
    GetService = function() return svc end }, { __index = function() return svc end })
workspace = svc
script = { Parent = svc }
require = function() return Any("module") end
identifyexecutor = function() return "harness" end
request, setclipboard, sethiddenproperty = function() end, function() end, function() end
debug = { getupvalues = function() return {} end, traceback = function() return "" end }

local loaded, okCount, failCount = {}, 0, 0
for _, f in ipairs({ "src/util.lua", "src/config.lua", "src/quests.lua", "src/ui.lua",
                     "src/farm.lua", "src/extras.lua", "src/pages.lua", "src/home.lua" }) do
    local chunk, err = loadstring(FILES[f], f)
    if not chunk then
        print("[x] " .. f .. " compile: " .. tostring(err)) failCount = failCount + 1
    else
        local ok, res = pcall(chunk)
        local v = ok and res or nil
        if type(v) == "function" then
            local ok2, r2 = pcall(v, {})
            v = ok2 and r2 or nil
        end
        if type(v) == "table" then
            print("[ok] " .. f .. (v.tick and "  (tick)" or ""))
            loaded[f] = v okCount = okCount + 1
        else
            print("[x] " .. f .. " -> " .. type(v) .. "  " .. tostring(res)) failCount = failCount + 1
        end
    end
end

local U, C, Q = loaded["src/util.lua"], loaded["src/config.lua"], loaded["src/quests.lua"]
local UI = loaded["src/ui.lua"]
U.logText = function() return table.concat(U.logs, "\n") end

-- quest table sanity: rows must be contiguous within each sea
for sea, rows in pairs(Q) do
  if type(rows) == "table" then
    for i, r in ipairs(rows) do
        assert(r[1] <= r[2], "row " .. i .. " sea " .. sea .. " min>max")
        assert(type(r[3]) == "string" and #r[3] > 0, "row " .. i .. " no mob")
        if i > 1 then assert(r[1] == rows[i - 1][2] + 1, "gap/overlap at sea " .. sea .. " row " .. i) end
    end
  end
end
print("[ok] quest table contiguous, 1.." .. tostring(Q[1][#Q[1]][2]) .. " / " .. tostring(Q[3][#Q[3]][2]))

-- UI must build, then every tab module must init against it
local win
local okU, errU = pcall(function() win = UI.new(U, C) end)
assert(okU, "UI.new: " .. tostring(errU))
print("[ok] UI.new built, tabs: " .. tostring(win.current))

for _, pair in ipairs({ { "src/farm.lua", "farm" }, { "src/extras.lua", "extras" } }) do
    local m = loaded[pair[1]]
    local ok, err = pcall(function() m.init(U, C, UI, win, { Q = Q }) end)
    if ok then print("[ok] init " .. pair[2]) else print("[x] init " .. pair[2] .. ": " .. tostring(err)) failCount = failCount + 1 end
    -- tick once: must not throw
    local ok2, err2 = pcall(m.tick, U, C)
    if ok2 then print("[ok] tick " .. pair[2]) else print("[x] tick " .. pair[2] .. ": " .. tostring(err2)) failCount = failCount + 1 end
end
for _, pair in ipairs({ { "src/pages.lua", "pages" }, { "src/home.lua", "home" } }) do
    local m = loaded[pair[1]]
    local ok, err = pcall(function() m.init(U, C, UI, win) end)
    if ok then print("[ok] init " .. pair[2]) else print("[x] init " .. pair[2] .. ": " .. tostring(err)) failCount = failCount + 1 end
end

-- config round-trip
C.set("farm", true) assert(C.get("farm") == true)
C.toggle("farm") assert(C.get("farm") == false)
print("[ok] config round-trip")

print(string.format("HARNESS: %d ok, %d failed", okCount, failCount))
assert(failCount == 0, "FAILED")
