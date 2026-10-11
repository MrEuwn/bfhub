--[[ farm.lua - auto farm level. No UI here; farm.lua only exposes tick(). ]]

local M = {}
local Q = nil

function M.init(U, C, UI, win, deps)
    M.U, M.C = U, C
    M.Q = deps and deps.Q
end

local function sea(U)
    if U.LP.Data:FindFirstChild("Level") == nil then return 1 end
    -- island names are the reliable sea signal when PlaceId is a subplace
    local loc = workspace:FindFirstChild("_WorldOrigin")
    loc = loc and loc:FindFirstChild("Locations")
    local n = loc and loc:GetChildren() and #loc:GetChildren() or 0
    if game.PlaceId == 7449423635 then return 3 end
    if game.PlaceId == 4442272183 then return 2 end
    if game.PlaceId == 2753915549 then return 1 end
    return n > 30 and 3 or (n > 15 and 2 or 1)
end

local function travel(U, C, cf)
    if C.get("tween") then
        U.tweenTo(cf, C.get("tweenspeed"))
    else
        U.tp(cf)
    end
end

-- level up -> new quest row. Accepting teleports to the giver first: the call is
-- ignored when the player is nowhere near it.
local function ensureQuest(U, C)
    local lv = U.level()
    if M.quest and lv >= M.quest[1] and lv <= M.quest[2] then return end
    M.quest = M.Q and M.Q.at(sea(U), lv)
    if not M.quest then return end
    local _, mon, nq, num, cfq = table.unpack(M.quest)
    U.log("i", string.format("quest Lv%d -> %s (%s #%d)", lv, mon, nq, num))
    travel(U, C, cfq * CFrame.new(0, 5, 0))
    task.wait(C.get("tween") and 0.35 or 0.1)
    U.F("StartQuest", nq, num)
end

function M.tick(U, C)
    if not C.get("farm") or not U.alive() then return end
    ensureQuest(U, C)
    if not M.quest then return end

    local _, mon, _, _, _, cfm = table.unpack(M.quest)
    local mob = U.nearestMob(mon)
    if not mob then
        -- respawn wait: walk to the recorded mob spot instead of standing still
        travel(U, C, cfm * CFrame.new(0, 10, 0))
        return
    end

    U.noclip(C.get("noclip"))
    U.equip(C.get("weapon"))
    if C.get("autobuso") or C.get("autoken") then U.autoHaki() end
    if C.get("heal") then
        local h = U.hum()
        if h and h.Health / h.MaxHealth < 0.3 then U.F("Heal") end
    end

    -- orbit keeps re-crossing the hitbox; parking above it often hits nothing
    local d = C.get("farmdistance")
    local dest = C.get("orbit") and U.orbit(mob, d) or (mob.HumanoidRootPart.CFrame + Vector3.new(0, d, 0))
    travel(U, C, dest)
    U.hover(C.get("hover"))

    if C.get("bring") then U.bringMobs(mon) end

    -- clicks only land in range; skip the swing when still far away
    local root = U.root()
    if root and (mob.HumanoidRootPart.Position - root.Position).Magnitude < 45 then
        if C.get("method") == "net" then U.netAttack(C.get("attackdist")) else U.attack(C.get("attackdist")) end
    end
end

return M
