--[[ farm.lua - the farm loops. One scheduler calls tick(); every loop here is a
     state machine, not a task.spawn per feature, so a toggle off actually stops it. ]]

local M = {}
local D, Q, U, C

function M.init(_U, _C, _UI, _win, deps)
    U, C, Q, D = _U, _C, deps and deps.Q, deps and deps.D
    M.quest = nil
end

local function travel(cf, speed)
    if C.get("tween") then U.tweenTo(cf, speed or C.get("TweenSpeed")) else U.tp(cf) end
end

-- level -> new quest row. Accepting teleports to the giver first: the call is
-- ignored when the player is nowhere near it.
local function ensureQuest()
    local lv = U.level()
    if M.quest and lv >= M.quest[1] and lv <= M.quest[2] then return end
    local sea = U.sea or 1
    local row = Q and Q.at(sea, lv)
    if row then
        M.quest = row
    elseif D then
        local r = D.questAt(sea, lv)
        if r then M.quest = { r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] } end
    end
    if not M.quest then return end
    local _, _, mon, nq, num, cfq = M.quest[1], M.quest[2], M.quest[3], M.quest[4], M.quest[5], M.quest[6]
    U.log("i", string.format("quest Lv%d -> %s (%s #%d)", lv, tostring(mon), tostring(nq), tonumber(num) or 1))
    travel(cfq * CFrame.new(0, 5, 0), 200)
    task.wait(C.get("tween") and 0.35 or 0.1)
    U.F("StartQuest", nq, num)
end

-- Level: accept quest -> travel to the mob -> bring -> orbit -> hit -> repeat
local function farmLevel()
    ensureQuest()
    if not M.quest then return end
    local mon, cfm, waypoints = M.quest[3], M.quest[7], M.quest[8]

    local mob = U.nearestMob(mon)
    if not mob then
        -- respawn wait: walk the recorded waypoints instead of standing still
        if waypoints and #waypoints > 0 then
            M.wp = (M.wp or 0) % #waypoints + 1
            travel(waypoints[M.wp] * CFrame.new(0, 5, 0))
        elseif cfm then
            travel(cfm * CFrame.new(0, 8, 0))
        end
        return
    end

    U.noclip(C.get("noclip"))
    U.equip(C.get("FarmTool"))
    if C.get("AutoHaki") then U.autoHaki() end

    local d = C.get("FarmPos")
    travel(C.get("orbit") and U.orbit(mob, d) or (U.mobPos(mob).CFrame + Vector3.new(0, d, 0)))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(mon) end

    -- clicks only land in range; skip the swing when still far away
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        if C.get("method") == "net" then U.netAttack(C.get("hitbox")) else U.attack(C.get("hitbox")) end
    end
end

-- Nearest: no quest, just kill the closest mob (or the chosen boss)
local function farmNearest()
    local mob = U.nearestMob()
    if not mob then return end
    U.noclip(C.get("noclip"))
    U.equip(C.get("FarmTool"))
    if C.get("AutoHaki") then U.autoHaki() end
    travel(U.orbit(mob, C.get("FarmPos")))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("hitbox"))
    end
end

-- Boss: travel to the spawn point, take the quest if the boss needs one, kill.
local function farmBoss()
    local name = C.get("BossSelected")
    if not name or not D then return end
    local row = D.bosses[name]
    if not row then return end
    local needQuest, cf, qname, qnum = row[1], row[2], row[3], row[4]
    if needQuest and C.get("TakeQuestBoss") and qname then U.F("StartQuest", qname, qnum or 1) end
    local mob = U.nearestMob(name)
    if not mob then travel(cf * CFrame.new(0, 8, 0)) return end
    travel(U.orbit(mob, C.get("FarmPos")))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(name) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("hitbox"))
    end
end

-- Mastery: same as level but with the chosen tool equipped
local function farmMastery()
    local tool = C.get("ToolMastery")
    local mob = U.nearestMob()
    if not mob then return end
    U.equip(tool)
    travel(U.orbit(mob, C.get("FarmPos")))
    U.hover(C.get("hover"))
    if C.get("BringMobs") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        U.attack(C.get("hitbox"))
    end
    if C.get("AutoStats") then
        local pts = U.data("Points")
        if pts and pts > 0 then U.F("AddPoint", "Melee", pts) end
    end
end

function M.tick(_U, _C)
    if not U.alive() then return end
    if C.get("FastAttack") or C.get("AttackDistance") then U.fastAttack() end
    if C.get("farm") then
        local mode = C.get("farmmode") or "level"
        if mode == "level" then farmLevel()
        elseif mode == "nearest" then farmNearest()
        elseif mode == "boss" then farmBoss()
        elseif mode == "mastery" then farmMastery()
        end
    end
end

return M
