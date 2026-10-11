-- Farm. Ported 1:1 from the Redz Hub V2 farm loop (open source, working):
--   travel by TWEENING A BLOCK part to the mob, hover the character on it,
--   click with a delay (PlayerClick), refresh haki, equip the farm tool, and
--   magnet the mobs. Mobs live in workspace.Enemies AND ReplicatedStorage.
return function(U, UI, C, win)
    local M = {}
    local mode            -- nil | "nearest" | "selected"
    local questFarm = false
    local chest, berry, material = false, false, false
    local lastQuest = 0

    local function baseName(n) return (n:gsub("%s*%[Lv%.%s*%d+%]$", "")) end

    -- FarmPos: the offset above the mob the player hovers at (Redz default 20).
    local function farmPos()
        local d = C.get("farmDist") or 20
        return Vector3.new(0, d, d)
    end

    -- GetNearest: scan Enemies + ReplicatedStorage, nearest with Health > 0.
    local function getNearest(filter)
        local r = U.root(); if not r then return nil end
        local best, bd = nil, 2500
        local function verify(m)
            if filter and not string.find(string.lower(m.Name), filter, 1, true) then return end
            local h = m:FindFirstChildOfClass("Humanoid")
            local pp = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
            if h and h.Health > 0 and pp then
                local d = (r.Position - pp.Position).Magnitude
                if d <= bd then bd = d; best = m end
            end
        end
        local e = U.enemies()
        if e then for _, m in ipairs(e:GetChildren()) do verify(m) end end
        for _, m in ipairs(U.ReplicatedStorage:GetChildren()) do
            if m:FindFirstChildOfClass("Humanoid") then verify(m) end
        end
        return best
    end

    -- PlayerClick (Redz): a real left click, rate-limited by Auto Click Delay.
    local lastClick = 0
    local function playerClick()
        local delay = C.get("clickDelay") or 0.18
        if os.clock() - lastClick < delay then return end
        lastClick = os.clock()
        U.VirtualUser:CaptureController()
        U.VirtualUser:Button1Down(Vector2.new(math.huge, math.huge))
    end

    -- Travel to the mob and farm it, exactly like Redz:
    --   tween the character to mob.CFrame + FarmPos, then click + haki + tool + magnet.
    local function farmMob(mob, name)
        local r = U.root(); if not r then return end
        local h = mob:FindFirstChildOfClass("Humanoid")
        local hrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
        if not h or h.Health <= 0 or not hrp then return end

        U.applyNoClip(true)
        U.simRadius()
        U.setHitbox(C.get("auraRadius") or 120)
        U.fastAttack()
        U.attackHit(C.get("auraRadius") or 120)

        -- travel (tween by default, hard set if tween is off)
        local dest = hrp.CFrame + farmPos()
        if C.get("useTween") == false then
            r.CFrame = dest
        else
            U.tweenTo(dest, 0.2)
        end

        -- the Redz order: click, haki, equip tool, magnet
        playerClick()
        U.autoHaki()
        local w = C.get("weapon")
        if w and w ~= "None" then U.equipWeapon(w) end
        if C.get("bring") then U.magnetMob(name or mob.Name, r.CFrame * CFrame.new(0, 0, -6), C.get("bringDist") or 250) end
    end

    local function waitForMobs(name, timeout)
        local t0 = os.clock()
        while os.clock() - t0 < (timeout or 6) do
            if #U.mobs(name) > 0 then return true end
            task.wait(0.3)
        end
        return false
    end

    -- Auto quest: accept the quest for the current level, kill its mobs (quest
    -- completes automatically on kill), repeat. StartQuest(NameQuest, number).
    local function runQuest()
        local sea, lvl = U.currentSea(), U.level()
        local row
        for _, q in ipairs(C.quests or {}) do
            if q[3] == sea and lvl >= q[1] and lvl <= q[2] then row = q; break end
        end
        if not row then return end
        local _, _, _, name, num, mon, qx, qy, qz = table.unpack(row)

        if not U.questActive() then
            local r = U.root()
            if r and (r.Position - Vector3.new(qx, qy, qz)).Magnitude > 6 then
                U.applyNoClip(true)
                if C.get("useTween") == false then r.CFrame = CFrame.new(qx, qy, qz)
                else U.tweenTo(CFrame.new(qx, qy, qz), 0.4) end
            end
            U.commF("StartQuest", name, num)
            task.wait(0.4)
        else
            C.set("farmTarget", mon)
            local mob = getNearest(mon)
            if mob then farmMob(mob, mon)
            elseif not waitForMobs(mon, 4) then
                local any = getNearest(nil)
                if any then farmMob(any, baseName(any.Name)) end
            end
        end
    end

    local t = win:tab("Farm")

    local ws = t:section("Weapon")
    ws:dropdown("Equip Category", { "Melee", "Sword", "Gun", "Fruit", "None" }, "Melee", function(v) C.set("weapon", v) end)

    local s = t:section("Auto Farm")
    s:dropdown("Farm Distance", { "10", "15", "20", "30", "40" }, "20", function(v) C.set("farmDist", tonumber(v)) end)
    s:dropdown("Farm Speed (click)", { "Fast (0.05)", "Normal (0.18)", "Slow (0.4)" }, "Normal (0.18)", function(v)
        C.set("clickDelay", tonumber(string.match(v, "%d+%.%d+")) or 0.18)
    end)
    s:toggle("Use Tween (smooth travel)", true, function(on) C.set("useTween", on) end)
    s:toggle("Fly / Hover (never fall)", true, function(on) C.set("fly", on) end)
    s:toggle("Bring Mob", true, function(on) C.set("bring", on) end)
    s:dropdown("Bring Distance", { "100", "200", "250", "400" }, "250", function(v) C.set("bringDist", tonumber(v)) end)
    s:toggle("NoClip", false, function(on) C.set("noclipAlways", on) end)
    s:toggle("Auto Farm Nearest", false, function(on) mode = on and "nearest" or nil end)

    -- Selected mob: live list from the Enemies folder.
    local liveMobs = {}
    task.spawn(function()
        while true do
            local seen, list = {}, {}
            for _, m in ipairs(U.mobs(nil)) do seen[baseName(m.Name)] = true end
            for k in pairs(seen) do table.insert(list, k) end
            table.sort(list)
            liveMobs = list
            task.wait(3)
        end
    end)

    local ss = t:section("Selected Mob")
    local selMon = "Bandit"
    local selLabel = ss:label("scanning nearby mobs...")
    local holder = ss:paragraph("selected: (none)")
    local built = false
    task.spawn(function()
        task.wait(4)
        if built then return end
        built = true
        selLabel.Text = ("%d mob types nearby"):format(#liveMobs)
        for i, n in ipairs(liveMobs) do
            if i > 40 then break end
            ss:button(n, function()
                selMon = n; C.set("farmMobName", n)
                holder.Text = "selected: " .. n
                if not C.get("farmSelected") then C.set("farmSelected", true); mode = "selected" end
            end)
        end
        if #liveMobs == 0 then selLabel.Text = "no mobs nearby" end
    end)
    ss:toggle("Farm Selected Mob", false, function(on)
        C.set("farmSelected", on)
        if on then mode = "selected" elseif mode == "selected" then mode = nil end
    end)

    t:section("Auto Quest (Level)")
    s:toggle("Auto Farm Level", false, function(on) questFarm = on end)
    s:label("Accepts the quest for your level and completes it automatically.")

    t:section("Chest / Collect")
    s:toggle("Auto Chest Farm", false, function(on) chest = on end)
    s:toggle("Auto Collect Berry", false, function(on) berry = on end)
    s:toggle("Auto Farm Material", false, function(on) material = on end)

    local function goTouch(pat)
        local r = U.root(); if not r then return end
        local best, bd
        for _, m in ipairs(workspace:GetChildren()) do
            if string.find(string.lower(m.Name), pat, 1, true) then
                local p = m:FindFirstChildWhichIsA("BasePart") or (m:IsA("BasePart") and m)
                if p then
                    local d = (p.Position - r.Position).Magnitude
                    if not bd or d < bd then bd = d; best = p end
                end
            end
        end
        if best then U.tp(best, 4); U.touch(r, best) end
    end

    function M.tick()
        local farming = questFarm or mode == "nearest" or mode == "selected"
        U.hover(farming and (C.get("fly") ~= false))
        if C.get("noclipAlways") then U.applyNoClip(true) end
        U.fastAttack()
        if C.get("hitbox") then U.setHitbox(C.get("hitbox")) end

        if questFarm then
            if os.clock() - lastQuest > 0.4 then lastQuest = os.clock(); runQuest() end
        elseif mode == "nearest" then
            local m = getNearest(nil)
            if m then C.set("farmTarget", baseName(m.Name)); farmMob(m, baseName(m.Name)) end
        elseif mode == "selected" then
            local nm = C.get("farmMobName") or selMon
            local m = getNearest(nm)
            if m then C.set("farmTarget", nm); farmMob(m, nm) else waitForMobs(nm, 3) end
        end

        if chest then goTouch("chest") end
        if berry then goTouch("berry") end
        if material then goTouch("material") end
    end

    return M
end
