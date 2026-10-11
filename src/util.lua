-- Shared helpers. No side effects beyond caching services.
local U = {}
local C_hitbox = 120   -- current M1 hitbox magnitude (long-range kill aura)

U.Players = game:GetService("Players")
U.RunService = game:GetService("RunService")
U.Http = game:GetService("HttpService")
U.Teleport = game:GetService("TeleportService")
U.Lighting = game:GetService("Lighting")
U.Tween = game:GetService("TweenService")
U.VirtualUser = game:GetService("VirtualUser")
U.ReplicatedStorage = game:GetService("ReplicatedStorage")
U.StarterGui = game:GetService("StarterGui")
U.player = U.Players.LocalPlayer

-- Blox Fruits place ids (per sea)
U.SEA_PLACE = { [1] = 2753915549, [2] = 4442272183, [3] = 7449423635 }

function U.log(msg) print("[BFHub] " .. tostring(msg)) end

function U.notify(text, dur)
    pcall(function()
        U.StarterGui:SetCore("SendNotification", {
            Title = "BFHub", Text = tostring(text), Duration = dur or 3,
        })
    end)
end

function U.char()
    return U.player.Character or U.player.CharacterAdded:Wait()
end

function U.root()
    local c = U.player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function U.hum()
    local c = U.player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function U.tp(pos, yOff)
    local r = U.root()
    if not r then return false end
    yOff = yOff or 0
    if typeof(pos) == "Vector3" then
        r.CFrame = CFrame.new(pos + Vector3.new(0, yOff, 0))
    elseif typeof(pos) == "CFrame" then
        r.CFrame = pos * CFrame.new(0, yOff, 0)
    elseif typeof(pos) == "BasePart" then
        r.CFrame = pos.CFrame * CFrame.new(0, yOff, 0)
    elseif typeof(pos) == "Model" then
        local p = pos.PrimaryPart or pos:FindFirstChildWhichIsA("BasePart")
        if p then r.CFrame = p.CFrame * CFrame.new(0, yOff, 0) end
    end
    return true
end

-- Smooth move (optional). Tween is prettier but slower than a hard CFrame set.
function U.tweenTo(pos, time)
    local r = U.root()
    if not r then return end
    local target
    if typeof(pos) == "Vector3" then target = CFrame.new(pos)
    elseif typeof(pos) == "CFrame" then target = pos
    elseif typeof(pos) == "BasePart" then target = pos.CFrame
    elseif typeof(pos) == "Model" then
        local p = pos.PrimaryPart or pos:FindFirstChildWhichIsA("BasePart")
        if not p then return end
        target = p.CFrame
    end
    local t = U.Tween:Create(r, TweenInfo.new(time or 0.4, Enum.EasingStyle.Linear), { CFrame = target })
    t:Play(); t.Completed:Wait()
end

-- Remotes
function U.commF(...)
    local R = U.ReplicatedStorage:FindFirstChild("Remotes")
    local c = R and R:FindFirstChild("CommF_")
    if not c then return nil end
    local args = table.pack(...)
    local ok, res = pcall(function() return c:InvokeServer(table.unpack(args, 1, args.n)) end)
    if ok then return res end
    return nil
end

function U.commE(...)
    local R = U.ReplicatedStorage:FindFirstChild("Remotes")
    local e = R and R:FindFirstChild("CommE")
    if not e then return end
    local args = table.pack(...)
    pcall(function() e:FireServer(table.unpack(args, 1, args.n)) end)
end

-- World / islands. Islands live under workspace._WorldOrigin.Locations
function U.worldLocations()
    local w = workspace:FindFirstChild("_WorldOrigin")
    return w and w:FindFirstChild("Locations")
end

function U.islands()
    local loc = U.worldLocations()
    return loc and loc:GetChildren() or {}
end

function U.findIsland(pat)
    pat = string.lower(pat)
    for _, v in ipairs(U.islands()) do
        if string.find(string.lower(v.Name), pat, 1, true) then return v end
    end
    return nil
end

function U.currentSea()
    local id = game.PlaceId
    for sea, place in pairs(U.SEA_PLACE) do
        if place == id then return sea end
    end
    -- fallback: infer from the loaded island registry (PlaceId can change)
    local loc = U.worldLocations()
    if loc then
        local names = {}
        for _, v in ipairs(loc:GetChildren()) do names[string.lower(v.Name)] = true end
        local function any(list)
            for _, k in ipairs(list) do
                for n in pairs(names) do if string.find(n, k, 1, true) then return true end end
            end
            return false
        end
        if any({ "port town", "hydra", "haunted", "floating turtle", "sea of treats", "tiki", "castle on the sea" }) then return 3 end
        if any({ "kingdom of rose", "green zone", "graveyard", "cursed ship", "ice castle", "forgotten" }) then return 2 end
        if any({ "bandit", "jungle", "pirate village", "desert", "frozen village", "marine fortress", "magma" }) then return 1 end
    end
    return 0
end

-- Mobs live under workspace.Enemies (NOT direct children of workspace).
function U.enemies()
    return workspace:FindFirstChild("Enemies")
end

function U.isPlayerModel(m)
    for _, p in ipairs(U.Players:GetPlayers()) do
        if p.Character == m then return true end
    end
    return false
end

-- All alive enemy models, optionally filtered by name substring.
function U.mobs(filter)
    local out = {}
    filter = filter and string.lower(filter)
    local function scan(container)
        for _, m in ipairs(container:GetChildren()) do
            local h = m:FindFirstChildOfClass("Humanoid")
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.Health > 0 and not U.isPlayerModel(m) then
                if not filter or string.find(string.lower(m.Name), filter, 1, true) then
                    table.insert(out, m)
                end
            end
        end
    end
    local e = U.enemies()
    if e then scan(e) end
    if #out == 0 then scan(U.ReplicatedStorage) end
    return out
end

function U.nearestMob(filter)
    local r = U.root(); if not r then return nil end
    local best, bd
    for _, m in ipairs(U.mobs(filter)) do
        local hrp = m:FindFirstChild("HumanoidRootPart")
        local d = (hrp.Position - r.Position).Magnitude
        if not bd or d < bd then bd = d; best = m end
    end
    return best
end

-- Real M1 attack. A bare VirtualUser click does NOT damage enemies in Blox
-- Fruits; the server only accepts hits fired through RigControllerEvent with
-- the blade hits from CombatFramework.RigLib (method taken from Redz Hub).
function U.getBladeHit()
    local ok, res = pcall(function()
        local CF = debug.getupvalues(require(U.player.PlayerScripts.CombatFramework))[2]
        local ac = CF.activeController
        local weapon = ac.blades[1]
        if not weapon then return nil end
        local guard = 0
        while weapon.Parent ~= U.player.Character and guard < 50 do
            task.wait(); weapon = weapon.Parent; guard = guard + 1
        end
        return weapon
    end)
    return ok and res or nil
end

function U.attackHit(range)
    return pcall(function()
        local c = U.player.Character
        if not c or not c:FindFirstChild("HumanoidRootPart") then return end
        local rig = U.ReplicatedStorage:FindFirstChild("CombatFramework")
        rig = rig and rig:FindFirstChild("RigLib")
        local ev = U.ReplicatedStorage:FindFirstChild("RigControllerEvent")
        if not rig or not ev then return end
        local hits = require(rig).getBladeHits(c, { c.HumanoidRootPart }, range or 60)
        local out, seen = {}, {}
        for _, v in ipairs(hits) do
            local par = v.Parent
            if par and par:FindFirstChild("HumanoidRootPart") and not seen[par] then
                seen[par] = true
                table.insert(out, par.HumanoidRootPart)
            end
        end
        if #out > 0 then
            local w = U.getBladeHit()
            pcall(function() ev:FireServer("weaponChange", tostring(w)) end)
            ev:FireServer("hit", out, 1, "")
        end
    end)
end

-- Fast attack (MUXHUB method). Neutralises every combat cooldown and fires a
-- REAL left-click at screen centre every call. A big hitboxMagnitude (set via
-- setHitbox) is what gives the swing its long range, and because the hit is a
-- genuine M1 the server credits the kill -> money/exp.
function U.fastAttack()
    pcall(function()
        local c = U.player.Character
        local AC = debug.getupvalues(require(U.player.PlayerScripts.CombatFramework))[2].activeController
        AC.attacking = false
        AC.blocking = false
        AC.timeToNextAttack = tick() - 1
        AC.timeToNextBlock = 0
        AC.increment = 3
        AC.hitboxMagnitude = C_hitbox or 120
        if c then
            local stun = c:FindFirstChild("Stun"); if stun then stun.Value = 0 end
            local h = c:FindFirstChildOfClass("Humanoid"); if h then h.Sit = false end
        end
        U.VirtualUser:CaptureController()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        U.VirtualUser:Button1Down(Vector2.new(vp.X / 2, vp.Y / 2))
        U.VirtualUser:Button1Up(Vector2.new(vp.X / 2, vp.Y / 2))
        local shaker = U.ReplicatedStorage:FindFirstChild("Util")
        shaker = shaker and shaker:FindFirstChild("CameraShaker")
        if shaker then pcall(function() require(shaker):Stop() end) end
    end)
end

function U.setHitbox(mag)
    C_hitbox = mag
    pcall(function()
        local AC = debug.getupvalues(require(U.player.PlayerScripts.CombatFramework))[2].activeController
        AC.hitboxMagnitude = mag
    end)
end

-- Attack helper: real hit first, then a virtual tap as a fallback.
function U.attack()
    local c = U.player.Character
    local tool = c and c:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
    U.attackHit(60)
    pcall(function()
        U.VirtualUser:CaptureController()
        U.VirtualUser:Button1Down(Vector2.new(math.huge, math.huge))
    end)
end

function U.touch(a, b)
    if firetouchinterest and a and b then
        pcall(function() firetouchinterest(a, b, 0) end)
        pcall(function() firetouchinterest(a, b, 1) end)
    end
end

-- Equip the first tool in the backpack/character matching a weapon category.
-- ponytail: keyword match, not the game's real ToolType enum. Extend the lists
-- if a weapon is missing.
U.WEAPON = {
    Melee = { "Combat", "Black Leg", "Electro", "Fishman Karate", "Superhuman", "Death Step",
              "Sharkman Karate", "Dragon Talon", "Godhuman", "Sanguine Art", "Buso" },
    Sword = { "Sword", "Katana", "Blade", "Saber", "Cutlass", "Trident", "Halberd", "Yama",
              "Koko", "Shisui", "Tushita", "Pole", "Scythe", "Rengoku", "Longsword", "Dark Blade" },
    Gun   = { "Gun", "Pistol", "Rifle", "Slingshot", "Bazooka", "Cannon", "Flintlock",
              "Acidum", "Kabucha", "Bow", "Revolver", "Shotgun" },
    Fruit = { "-" },   -- fruit tools are named like "Dragon-Dragon"; matched by that pattern
}

function U.equipWeapon(kind)
    local c = U.player.Character
    if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local function matches(name)
        if kind == "Fruit" then return string.find(name, "%-") ~= nil end
        for _, kw in ipairs(U.WEAPON[kind] or {}) do
            if string.find(string.lower(name), string.lower(kw), 1, true) then return true end
        end
        return false
    end
    local sources = { c, U.player:FindFirstChild("Backpack") }
    for _, src in ipairs(sources) do
        if src then
            for _, tool in ipairs(src:GetChildren()) do
                if tool:IsA("Tool") and matches(tool.Name) then
                    if tool.Parent ~= c then
                        pcall(function() hum:EquipTool(tool) end)
                        task.wait(0.1)
                    end
                    return true
                end
            end
        end
    end
    return false
end

-- Level / quest state
function U.level()
    local d = U.player:FindFirstChild("Data")
    local lv = d and d:FindFirstChild("Level")
    return lv and lv.Value or 0
end

function U.questActive()
    local pg = U.player:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local q = main and main:FindFirstChild("Quest")
    return q and q.Visible == true
end

function U.questTitle()
    local pg = U.player:FindFirstChild("PlayerGui")
    local main = pg and pg:FindFirstChild("Main")
    local q = main and main:FindFirstChild("Quest")
    if not q then return "" end
    local cont = q:FindFirstChild("Container")
    local tt = cont and cont:FindFirstChild("QuestTitle")
    local t = tt and tt:FindFirstChild("Title")
    return t and t.Text or ""
end

-- Hover: cancels gravity so the character floats in place (no falling during
-- farm). Uses a BodyVelocity pinned to zero; removed when turned off.
function U.hover(on)
    local r = U.root()
    if on then
        if r and not r:FindFirstChild("RPSHover") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "RPSHover"
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.zero
            bv.Parent = r
        end
    elseif r then
        local b = r:FindFirstChild("RPSHover")
        if b then b:Destroy() end
    end
end

-- NoClip: turn collision off/on for every part of the character. Used by
-- movement (tween/fly) so we do not clip walls, and forced on while farming.
function U.applyNoClip(on)
    local c = U.player.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = not on end
    end
end

-- Ping (ms) via Stats, and a lightweight FPS estimate. Both best-effort.
function U.ping()
    local ok, v = pcall(function()
        return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and math.floor(v) or 0
end

--=========================================================================
-- Logger: captures every error (message + traceback + line) raised inside a
-- pcall wrapper, keeps a ring buffer, can push to a Discord webhook.
--=========================================================================
U.logs = {}                 -- ring buffer of strings
U.LOG_MAX = 200
U.webhook = nil             -- set via the Log tab

local function stamp()
    local t = os.date("*t")
    return ("%02d:%02d:%02d"):format(t.hour, t.minute, t.second)
end

local lastPush = 0
function U.logAdd(kind, msg)
    local line = ("[%s] %s: %s"):format(stamp(), kind, tostring(msg))
    table.insert(U.logs, line)
    if #U.logs > U.LOG_MAX then table.remove(U.logs, 1) end
    print("[BFHub] " .. line)
    -- auto-report real errors, at most once every 15s, when a webhook is set
    if kind:sub(1, 5) == "ERROR" and U.webhook and os.clock() - lastPush > 15 then
        lastPush = os.clock()
        task.spawn(function() U.sendWebhook("BFHub auto-report") end)
    end
    return line
end

-- Wraps a function so any error is logged with a traceback. Returns a pcall
-- style (ok, result).
function U.safe(label, fn, ...)
    local args = table.pack(...)
    local ok, res = pcall(fn, table.unpack(args, 1, args.n))
    if not ok then
        local tb = debug and debug.traceback and debug.traceback(tostring(res), 2) or tostring(res)
        U.logAdd("ERROR " .. tostring(label), tostring(res))
        U.logAdd("TRACE " .. tostring(label), tb)
    end
    return ok, res
end

function U.logText()
    return table.concat(U.logs, "\n")
end

function U.sendWebhook(extra)
    if not U.webhook or U.webhook == "" then return false, "no webhook set" end
    local body = U.logText()
    if extra then body = tostring(extra) .. "\n" .. body end
    if #body > 1900 then body = body:sub(-1900) end
    local payload = U.Http:JSONEncode({ content = "```" .. body .. "```" })
    local ok = pcall(function()
        request({
            Url = U.webhook, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = payload,
        })
    end)
    return ok
end

--=========================================================================
-- Redz-style combat helpers (the methods that actually work in Blox Fruits)
--=========================================================================

-- Huge SimulationRadius makes the client own nearby NPCs, so client-side
-- changes (kill, bring) replicate. Required by killAura + bringMob.
function U.simRadius()
    if sethiddenproperty then
        pcall(function() sethiddenproperty(U.player, "SimulationRadius", math.huge) end)
    end
end

-- Kill Aura (REAL): a long-range M1. getBladeHits takes a range argument, so a
-- big range makes one swing reach everything nearby; the hit goes through
-- RigControllerEvent like a normal attack, so the server credits the kill and
-- the player gets money/exp. (Setting Health = 0 does NOT — that is instakill,
-- visual only, no rewards.)
function U.killAura(radius)
    radius = radius or 120
    U.simRadius()
    U.setHitbox(radius)      -- wide M1 reach
    U.fastAttack()           -- real, credited hit
    U.attackHit(radius)      -- also fire the rig hit for good measure
end

-- Instakill: set Health = 0 directly. Instant clear but the server does NOT
-- credit the kill, so no money/exp. Kept as a separate, off-by-default option.
function U.instakill(radius)
    radius = radius or 1500
    local r = U.root(); if not r then return end
    U.simRadius()
    local function kill(_, m)
        local h = m:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            local pp = m.PrimaryPart
            if pp and (pp.Position - r.Position).Magnitude < radius then
                pcall(function() h.Health = 0 end)
                pcall(function() pp.Size = Vector3.new(75, 75, 75); pp.CanCollide = false end)
            end
        end
    end
    local e = U.enemies()
    if e then for _, m in ipairs(e:GetChildren()) do kill(nil, m) end end
    for _, m in ipairs(U.ReplicatedStorage:GetChildren()) do
        if m:FindFirstChildOfClass("Humanoid") then kill(nil, m) end
    end
end

-- Bring Mob (the method real hubs use — recovered from deobfuscated source).
-- A PlatformStand/Sit freeze is NOT it: the mob has to be dragged by physics so
-- it keeps a live hitbox next to you. BodyVelocity + BodyGyro + Physics state.
function U.magnetMob(name, anchor, dist)
    local r = U.root(); if not r or not name then return end
    dist = dist or 300
    anchor = anchor or r.CFrame
    pcall(function()
        sethiddenproperty(U.Players.LocalPlayer, "SimulationRadius", math.huge)
        sethiddenproperty(U.Players.LocalPlayer, "MaxSimulationRadius", math.huge)
    end)
    local pos, rad2 = anchor.Position, dist * dist
    for _, m in ipairs(U.enemies():GetChildren()) do
        local h = m:FindFirstChildOfClass("Humanoid")
        local hrp = m:FindFirstChild("HumanoidRootPart")
        if h and hrp and m:FindFirstChild("CharacterReady") and h.Health > 0
           and string.find(m.Name, name, 1, true)
           and (hrp.Position - pos).Magnitude ^ 2 <= rad2 then
            if not hrp:GetAttribute("BeingBrought") then
                hrp:SetAttribute("BeingBrought", true)
                for _, d in ipairs(m:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.CanCollide = false; d.CanTouch = false; d.Massless = true
                        d.AssemblyLinearVelocity = Vector3.zero
                        d.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                local lock = Instance.new("BodyVelocity")
                lock.Name = "Lock"; lock.MaxForce = Vector3.new(9e9, 9e9, 9e9); lock.P = 9000
                lock.Parent = hrp
                local gyro = Instance.new("BodyGyro")
                gyro.Name = "BringGyro"; gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                gyro.P, gyro.D = 30000, 1000; gyro.Parent = hrp
                hrp.CanCollide = false; hrp.Massless = true
                h.AutoRotate = false
                h.PlatformStand = false
                h.BreakJointsOnDeath = false
                pcall(function() h:ChangeState(Enum.HumanoidStateType.Physics) end)
                task.spawn(function()
                    local target = pos + Vector3.new(math.random(-20,20)/100, math.random(-20,20)/100, math.random(-20,20)/100)
                    local dv = target - hrp.Position
                    local mag = dv.Magnitude
                    if mag > 0.5 then
                        lock.Velocity = dv.Unit * math.clamp(mag * 10, 20, 1200)
                    else
                        lock.Velocity = Vector3.zero
                        pcall(function() hrp.CFrame = CFrame.new(target) end)
                    end
                    gyro.CFrame = anchor
                end)
            else
                local lock = hrp:FindFirstChild("Lock")
                local gyro = hrp:FindFirstChild("BringGyro")
                if lock then
                    local dv = pos - hrp.Position
                    lock.Velocity = dv.Magnitude > 0.5 and dv.Unit * math.clamp(dv.Magnitude*10, 20, 1200) or Vector3.zero
                end
                if gyro then gyro.CFrame = anchor end
            end
        end
    end
end

U.bringMob = U.magnetMob

-- Farm offset. Real hubs ORBIT the mob (angle steps 5 deg per call, radius 35)
-- instead of parking above it: the sweep keeps crossing the mob's hitbox, so
-- M1 connects. A fixed offset is what makes farm look "visual only".
local _ang = 0
function U.orbitPos(cf, dist, radius)
    _ang = (_ang + 5) % 360
    local a = math.rad(_ang)
    radius = radius or 35
    return cf + Vector3.new(math.sin(a) * radius, dist or 20, math.cos(a) * radius)
end

function U.farmPos(dist)
    dist = dist or 20
    return Vector3.new(0, dist, dist)
end

-- Real attack, recovered from deobfuscated source: fire the game's own Net
-- remotes. A bare VirtualUser click does NOT damage; these do, and they pay.
local _net
local function net()
    if _net then return _net end
    local m = U.ReplicatedStorage:FindFirstChild("Modules")
    local n = m and m:FindFirstChild("Net")
    if n then _net = n end
    return _net
end

function U.getHits(radius)
    local r = U.root(); local out = {}
    if not r then return out end
    for _, folder in ipairs({ U.enemies(), workspace:FindFirstChild("Characters") }) do
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                local h = m:FindFirstChildOfClass("Humanoid")
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if h and hrp and h.Health > 0
                   and (hrp.Position - r.Position).Magnitude <= (radius or 60) then
                    table.insert(out, { m, m:FindFirstChild("Head") or hrp })
                end
            end
        end
    end
    return out
end

-- Net attack: RegisterAttack:FireServer(0) then RegisterHit:FireServer(head, hits)
function U.netAttack(radius)
    local n = net(); if not n then return false end
    local atk = n:FindFirstChild("RE/RegisterAttack")
    local hit = n:FindFirstChild("RE/RegisterHit")
    if not (atk and hit) then return false end
    local hits = U.getHits(radius or 60)
    if #hits == 0 then return false end
    pcall(function()
        atk:FireServer(0)
        local head = table.remove(hits, 1)[2]
        hit:FireServer(head, hits, nil, "")
    end)
    return true
end

-- Auto Haki: buso is a state flag on the character, not a fire-and-forget call.
function U.autoHaki()
    local c = U.player.Character
    if not c then return end
    if not c:FindFirstChild("HasBuso") then U.commF("Buso") end
end

return U
