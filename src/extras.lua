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
