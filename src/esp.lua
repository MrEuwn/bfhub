-- ESP: fruit / player / chest / island. BillboardGui only -> cheap.
return function(U, UI, C, win)
    local M = {}
    local tags = {}

    local function clearTag(inst, key)
        local id = key or "BFHubESP"
        local e = inst:FindFirstChild(id)
        if e then e:Destroy() end
    end

    -- Reuse an existing tag instead of destroying/recreating it every tick
    -- (destroying+cloning BillboardGuis each frame is the main mobile lag source).
    local function tag(inst, text, color, id)
        id = id or "BFHubESP"
        local old = inst:FindFirstChild(id)
        if old then
            local lbl = old:FindFirstChildWhichIsA("TextLabel")
            if lbl then
                if lbl.Text ~= text then lbl.Text = text end
                if lbl.TextColor3 ~= color then lbl.TextColor3 = color end
            end
            return old
        end
        local bb = Instance.new("BillboardGui")
        bb.Name = id; bb.Size = UDim2.fromOffset(120, 28); bb.AlwaysOnTop = true
        bb.StudsOffset = Vector3.new(0, 3, 0); bb.Parent = inst
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, 0, 1, 0); tl.BackgroundTransparency = 1
        tl.Text = text; tl.TextColor3 = color
        tl.TextStrokeTransparency = 0.3; tl.Font = Enum.Font.GothamBold; tl.TextSize = 12
        tl.Parent = bb
        return bb
    end

    local opts = { fruit = false, player = false, chest = false, island = false, enemy = false }

    local t = win:tab("ESP")
    local s = t:section("World")
    s:toggle("Fruit ESP", false, function(on) opts.fruit = on end)
    s:toggle("Chest ESP", false, function(on) opts.chest = on end)
    s:toggle("Island ESP", false, function(on) opts.island = on end)
    t:section("Players")
    s:toggle("Player ESP", false, function(on) opts.player = on end)
    s:toggle("Enemy ESP", false, function(on) opts.enemy = on end)

    function M.tick()
        if not opts.enemy then
            for _, m in ipairs(U.mobs(nil)) do
                local e = m:FindFirstChild("BFHubEnemy"); if e then e:Destroy() end
            end
        end
        if not opts.fruit then
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("Tool") then local e = d:FindFirstChild("BFHubFruit"); if e then e:Destroy() end end
            end
        end
        if opts.enemy then
            for _, m in ipairs(U.mobs(nil)) do
                local h = m:FindFirstChildOfClass("Humanoid")
                tag(m, m.Name .. (h and (" [" .. math.floor(h.Health) .. "]") or ""), Color3.fromRGB(255, 120, 60), "BFHubEnemy")
            end
        end
        if opts.fruit then
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("Tool") and string.find(string.lower(d.Name), "fruit", 1, true) then
                    tag(d, d.Name, Color3.fromRGB(255, 90, 90), "BFHubFruit")
                end
            end
        end
        if opts.chest then
            for _, m in ipairs(workspace:GetChildren()) do
                if string.find(string.lower(m.Name), "chest", 1, true) and m:IsA("Model") then
                    tag(m, "Chest", Color3.fromRGB(255, 215, 0), "BFHubChest")
                end
            end
        end
        if opts.island then
            for _, v in ipairs(U.islands()) do
                tag(v, v.Name, Color3.fromRGB(145, 200, 90), "BFHubIsland")
            end
        end
        if opts.player then
            for _, p in ipairs(U.Players:GetPlayers()) do
                if p ~= U.player and p.Character then
                    local h = p.Character:FindFirstChildOfClass("Humanoid")
                    local txt = p.Name .. (h and (" [" .. math.floor(h.Health) .. "]") or "")
                    tag(p.Character, txt, Color3.fromRGB(90, 170, 255), "BFHubPlr")
                end
            end
        end
    end

    return M
end
