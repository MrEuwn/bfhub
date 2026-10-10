-- Bones: farm the Haunted Castle mobs and roll the Death King gacha.
-- Bone drop mobs are Reborn Skeleton / Living Zombie / Demonic Soul / Posessed Mummy.
return function(U, UI, C, win)
    local M = {}
    local farmBone = false
    local lastRoll = 0

    local BONE_MOBS = { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy" }
    local HAUNTED = { "Haunted", "Haunted Castle" }

    local function gotoHaunted()
        for _, name in ipairs(HAUNTED) do
            local v = U.findIsland(name)
            if v then U.tp(v, 40); return true end
        end
        return false
    end

    local function nearestBoneMob()
        for _, n in ipairs(BONE_MOBS) do
            local m = U.nearestMob(n)
            if m then return m end
        end
        return nil
    end

    local t = win:tab("Bones")
    local s = t:section("Auto Farm Bone")
    s:toggle("Auto Farm Bone (Haunted Castle)", false, function(on)
        farmBone = on
        if on then gotoHaunted() end
    end)
    s:button("Teleport to Haunted Castle", function() gotoHaunted() end)

    t:section("Auto Roll Bone")
    s:label("Rolls at the Death King (50 bones/roll).")
    s:toggle("Auto Roll Bone", false, function(on) C.set("autoRollBone", on) end)
    s:button("Roll Once", function()
        -- ponytail: Death King roll remote arg is version-sensitive. If this
        -- does nothing, check the NPC's ProximityPrompt name and pass it here.
        U.commF("DeathKing", "Roll")
        U.commF("RollBone")
        U.notify("Roll bone fired")
    end)

    function M.tick()
        if farmBone then
            local m = nearestBoneMob()
            if m then
                local r = U.root()
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if r and hrp then
                    r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0))
                    U.touch(r, hrp)
                end
                U.attack()
            else
                if os.clock() - lastRoll > 3 then lastRoll = os.clock(); gotoHaunted() end
            end
        end
        if C.get("autoRollBone") then
            if os.clock() - lastRoll > 1 then
                lastRoll = os.clock()
                U.commF("DeathKing", "Roll")
            end
        end
    end

    return M
end
