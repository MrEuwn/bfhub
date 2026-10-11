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
