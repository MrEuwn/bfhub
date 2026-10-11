-- Misc: server hop, anti-afk, walk on water, infinite jump, noclip, fly, fps.
return function(U, UI, C, win)
    local M = {}
    local noclip, iJump, fly, antiAfk, wow

    local function hop()
        local place = game.PlaceId
        local ok, res = pcall(function()
            return game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?limit=100"):format(place))
        end)
        if ok and res then
            local ok2, data = pcall(function() return U.Http:JSONDecode(res) end)
            if ok2 and data and data.data and #data.data > 0 then
                local srv = data.data[math.random(1, #data.data)]
                U.Teleport:TeleportToPlaceInstance(place, srv.id, U.player)
                return
            end
        end
        U.Teleport:Teleport(place)
    end

    local t = win:tab("Misc")
    local s = t:section("Movement")
    s:toggle("NoClip", false, function(on) noclip = on end)
    s:toggle("Infinite Jump", false, function(on) iJump = on end)
    s:toggle("Fly", false, function(on)
        fly = on
        if on then
            local bg = Instance.new("BodyVelocity")
            bg.Name = "BFHubFly"; bg.MaxForce = Vector3.new(1e5, 1e5, 1e5); bg.Velocity = Vector3.zero
            local r = U.root(); if r then bg.Parent = r end
        else
            local r = U.root()
            local bg = r and r:FindFirstChild("BFHubFly")
            if bg then bg:Destroy() end
        end
    end)
    s:toggle("Walk on Water", false, function(on) wow = on end)

    t:section("Server")
    s:button("Server Hop", function() hop() end)
    s:toggle("Anti-AFK", false, function(on) antiAfk = on end)

    t:section("Damage / Combat")
    s:toggle("Remove Damage (god health loop)", false, function(on) C.set("removeDamage", on) end)
    s:toggle("Auto Haki (Buso+Ken)", false, function(on) C.set("autoHaki", on) end)
    s:button("Race Reroll (300 Bones)", function() U.commF("Bones", "Buy", 1, 3) end)

    t:section("Client")
    s:button("FPS Boost", function()
        for _, v in ipairs(U.Lighting:GetChildren()) do
            if v:IsA("PostEffect") then v.Enabled = false end
        end
        U.Lighting.GlobalShadows = false
        U.Lighting.FogEnd = 1e6
        U.notify("FPS boost applied")
    end)
    s:toggle("Low-End Mode (perf)", false, function(on)
        C.set("useTween", not on)          -- tween off = less work
        for _, v in ipairs(U.Lighting:GetChildren()) do
            if v:IsA("PostEffect") then v.Enabled = false end
        end
        U.Lighting.GlobalShadows = false
        U.Lighting.FogEnd = 1e6
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        U.notify(on and "Low-end mode ON" or "Low-end mode OFF")
    end)
    s:button("Anti Night (bright)", function()
        U.Lighting.Brightness = 2
        U.Lighting.ClockTime = 14
        U.notify("Anti-night applied")
    end)

    local move = { f = false, b = false, l = false, r = false, u = false, d = false }
    U.RunService.RenderStepped:Connect(function(dt)
        if noclip then U.applyNoClip(true) end
        if iJump then
            local h = U.hum()
            if h and h:GetState() == Enum.HumanoidStateType.Freefall then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
        if wow then
            local r = U.root()
            if r then
                local p = r.Position
                r.CFrame = CFrame.new(p.X, math.max(p.Y, 0.5), p.Z)
            end
        end
        if C.get("removeDamage") then
            local h = U.hum(); if h then h.Health = h.MaxHealth end
        end
        if C.get("autoHaki") then U.autoHaki(); U.commF("Ken") end
        if fly then
            local r = U.root()
            local bg = r and r:FindFirstChild("BFHubFly")
            if bg then
                local cam = workspace.CurrentCamera
                bg.Velocity = cam.CFrame.LookVector * 60 + Vector3.new(0, 10, 0)
            end
        end
    end)

    U.player.Idled:Connect(function()
        if antiAfk then
            U.VirtualUser:CaptureController()
            U.VirtualUser:ClickButton2(Vector2.new(0, 0))
        end
    end)

    return M
end
