-- Shared helpers. No side effects beyond caching services.
local U = {}

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

-- Fast attack: neutralise the CombatFramework cooldowns (Redz method).
function U.fastAttack()
    pcall(function()
        local AC = debug.getupvalues(require(U.player.PlayerScripts.CombatFramework))[2].activeController
        AC.increment = 3
        AC.timeToNextAttack = 0
        AC.timeToNextBlock = 0
        AC.focusStart = 0
        AC.attacking = false
        if AC.humanoid then AC.humanoid.AutoRotate = true end
        AC.currentAttackTrack = 0
        if sethiddenproperty then sethiddenproperty(U.player, "SimulationRadius", math.huge) end
    end)
end

function U.setHitbox(mag)
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

return U
