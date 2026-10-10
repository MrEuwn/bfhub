-- Teleport: islands are read live from workspace._WorldOrigin.Locations, so the
-- list is never stale and covers Sea 1/2/3 automatically.
return function(U, UI, C, win)
    local M = {}

    local function tpIsland(name)
        local v = U.findIsland(name)
        if v then
            local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if p then U.tp(p, 30) else U.tp(v, 30) end
            U.notify("TP -> " .. v.Name)
        else
            U.notify("Island not found: " .. name)
        end
    end

    local t = win:tab("Teleport")
    local s = t:section("Islands (live)")
    local holder = s:label("reading islands...")
    local built = 0
    task.spawn(function()
        task.wait(2)
        local isles = U.islands()
        holder.Text = ("Sea %d - %d islands"):format(U.currentSea(), #isles)
        for _, v in ipairs(isles) do
            s:button(v.Name, function() tpIsland(v.Name) end)
            built = built + 1
            if built % 25 == 0 then task.wait() end
        end
    end)

    t:section("Players")
    s:button("Teleport to Nearest Player", function()
        local r = U.root(); if not r then return end
        local best, bd
        for _, p in ipairs(U.Players:GetPlayers()) do
            if p ~= U.player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local d = (p.Character.HumanoidRootPart.Position - r.Position).Magnitude
                if not bd or d < bd then bd = d; best = p end
            end
        end
        if best then U.tp(best.Character.HumanoidRootPart, 6) U.notify("TP -> " .. best.Name) end
    end)

    return M
end
