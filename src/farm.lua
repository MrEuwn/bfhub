-- Farm: nearest mob, selected mob (live list), auto quest (accept + auto-complete
-- on kill), bring mob, tween, chest / berry / material.
-- Key fix vs first version: mobs live under workspace.Enemies, not workspace.
return function(U, UI, C, win)
    local M = {}
    local mode            -- nil | "nearest" | "selected"
    local questFarm = false
    local bring = false
    local chest, berry, material = false, false, false
    local lastQuest = 0

    -- "Bandit [Lv. 5]" -> "Bandit" (Enemies names carry a level tag)
    local function baseName(n) return (n:gsub("%s*%[Lv%.%s*%d+%]$", "")) end

    local function isMoving()
        local h = U.hum()
        return h and h.MoveDirection.Magnitude > 0.1
    end

    local function travelTo(pos, yOff)
        if C.get("useTween") then U.tweenTo(pos, C.get("tweenTime") or 0.4)
        else U.tp(pos, yOff or 0) end
    end

    -- bring mob: pull EVERY mob whose type matches the one being farmed onto
    -- the player, so the whole cluster stays in M1 range while you hover.
    local function bringSameType(name)
        local r = U.root(); if not r or not name then return end
        for _, m in ipairs(U.mobs(name)) do
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = r.CFrame * CFrame.new(0, 0, -3) end
        end
    end

    -- Farm loop: fly to the target mob, (optionally) gather all same-type mobs
    -- onto us, then attack. Bring makes travel unnecessary after the first pass.
    local function kill(mob, speed, name)
        local r = U.root(); if not r or not mob then return end
        local h = mob:FindFirstChildOfClass("Humanoid"); if not h or h.Health <= 0 then return end
        local hrp = mob:FindFirstChild("HumanoidRootPart")
        if hrp then r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0)) end  -- auto to mob
        if bring then bringSameType(name) end
        U.attack()
        task.wait(speed or 0.15)
    end

    -- Auto quest: accept the quest for the current level, kill its mobs (quest
    -- completes automatically on kill), repeat. Ported from public BF sources:
    -- StartQuest(NameQuest, LevelQuest); no CompleteQuest remote exists.
    local function runQuest()
        local sea = U.currentSea()
        local lvl = U.level()
        local row
        for _, q in ipairs(C.quests or {}) do
            if q[3] == sea and lvl >= q[1] and lvl <= q[2] then row = q; break end
        end
        if not row then return end
        local _, _, _, name, num, mon, qx, qy, qz = table.unpack(row)

        if not U.questActive() then
            -- stand on the quest giver, then accept
            local qpos = CFrame.new(qx, qy, qz)
            local r = U.root()
            if r and (r.Position - Vector3.new(qx, qy, qz)).Magnitude > 8 then
                travelTo(qpos, 0)
                task.wait(0.3)
            end
            U.commF("StartQuest", name, num)
            task.wait(0.4)
        else
            -- quest active: kill its mobs; kill() attacks until the mob dies and
            -- the quest counter advances, completing automatically.
            local mob = U.nearestMob(mon)
            if mob then kill(mob, C.get("farmSpeed") or 0.15, mon) end
        end
    end

    local t = win:tab("Farm")

    -- Weapon selector (applies to all combat / farm attacks)
    local ws = t:section("Weapon")
    ws:dropdown("Equip Category", { "Melee", "Sword", "Gun", "Fruit", "None" }, "Melee", function(v)
        C.set("weapon", v)
    end)

    local s = t:section("Auto Farm")
    s:dropdown("Farm Speed", { "Fast (0.05)", "Normal (0.15)", "Slow (0.4)" }, "Normal (0.15)", function(v)
        C.set("farmSpeed", tonumber(string.match(v, "%d+%.%d+")) or 0.15)
    end)
    s:toggle("Use Tween (smooth, slower)", false, function(on) C.set("useTween", on) end)
    s:toggle("Bring Mob (all same type)", false, function(on) bring = on end)
    s:toggle("Auto Farm Nearest", false, function(on) mode = on and "nearest" or nil end)

    -- Selected mob: live list from workspace.Enemies, tap to cycle.
    local liveMobs = {}
    local selLabel
    task.spawn(function()
        while true do
            local seen = {}
            for _, m in ipairs(U.mobs(nil)) do
                local base = m.Name:gsub("%s*%[Lv%.%s*%d+%]$", "")
                seen[base] = true
            end
            local list = {}
            for k in pairs(seen) do table.insert(list, k) end
            table.sort(list)
            liveMobs = list
            if selLabel and #list > 0 then selLabel.Text = ("%d mobs nearby"):format(#list) end
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
                selMon = n
                C.set("farmMobName", n)
                holder.Text = "selected: " .. n
                if not C.get("farmSelected") then
                    -- arm the toggle state
                    C.set("farmSelected", true)
                    mode = "selected"
                end
            end)
        end
        if #liveMobs == 0 then
            selLabel.Text = "no mobs nearby (Enemies folder empty?)"
        end
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
        local e = workspace
        local best, bd
        for _, m in ipairs(e:GetChildren()) do
            if string.find(string.lower(m.Name), pat, 1, true) then
                local p = m:FindFirstChildWhichIsA("BasePart") or (m:IsA("BasePart") and m)
                if p then
                    local d = (p.Position - r.Position).Magnitude
                    if not bd or d < bd then bd = d; best = p end
                end
            end
        end
        if best then travelTo(best, 4); U.touch(r, best) end
    end

    function M.tick()
        -- keep the requested weapon equipped
        local w = C.get("weapon")
        if w and w ~= "None" then U.equipWeapon(w) end

        if questFarm then
            if os.clock() - lastQuest > 0.4 then lastQuest = os.clock(); runQuest() end
        elseif mode == "nearest" then
            local m = U.nearestMob(nil); if m then kill(m, C.get("farmSpeed"), baseName(m.Name)) end
        elseif mode == "selected" then
            local m = U.nearestMob(C.get("farmMobName") or selMon)
            if m then kill(m, C.get("farmSpeed"), C.get("farmMobName") or selMon) end
        end

        if chest then goTouch("chest") end
        if berry then goTouch("berry") end
        if material then goTouch("material") end
    end

    return M
end
