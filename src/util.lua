-- Shared helpers. No side effects beyond caching services.
local U = {}

U.Players = game:GetService("Players")
U.RunService = game:GetService("RunService")
U.Http = game:GetService("HttpService")
U.Teleport = game:GetService("TeleportService")
U.Lighting = game:GetService("Lighting")
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

-- Attack helper: activate equipped tool + a virtual click. Generic, works for
-- melee / sword / gun / fruit. Combat modules call this.
function U.attack()
    local c = U.player.Character
    local tool = c and c:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
    pcall(function()
        U.VirtualUser:CaptureController()
        U.VirtualUser:ClickButton1(Vector2.new(0, 0))
    end)
end

function U.touch(a, b)
    if firetouchinterest and a and b then
        pcall(function() firetouchinterest(a, b, 0) end)
        pcall(function() firetouchinterest(a, b, 1) end)
    end
end

return U
