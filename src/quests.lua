--[[ quests.lua - the driving loops for the named quests and unlocks.

     Every feature is a step list walked by tick(), not a task.spawn loop: a toggle
     off has to actually stop the work, and one scheduler keeps it cheap on mobile.

     Two drivers:
       generic  - "kill this boss, else stand here" (data.bossFarms)
       chains   - the multi-step unlocks (data.chains), with spawner remotes
]]

local M = {}
local U, C, D

-- per-feature runtime state, reset when the feature is switched off
local state = {}
local function st(key)
    local s = state[key]
    if not s then
        s = { step = 1, nextSpawn = 0, wp = 0 }
        state[key] = s
    end
    return s
end

function M.reset(key) state[key] = nil end

function M.init(_U, _C, _UI, _win, deps)
    U, C, D = _U, _C, deps and deps.D
end

-- travel + fight the same way the main farm does ---------------------------
local function travel(cf)
    if not cf then return end
    if C.get("tween") then U.tweenTo(cf, C.get("TweenSpeed")) else U.tp(cf) end
end

local function engage(mob, opts)
    opts = opts or {}
    U.noclip(C.get("noclip"))
    if opts.tool then U.equipTool(opts.tool) else U.equip(C.get("FarmTool")) end
    if C.get("AutoHaki") or C.get("AutoKenV2") then U.autoHaki() end
    local d = C.get("FarmPos")
    travel(C.get("orbit") and U.orbit(mob, d) or (U.mobPos(mob).CFrame + Vector3.new(0, d, 0)))
    U.hover(C.get("hover"))
    if opts.bring ~= false and C.get("BringMobs") then U.bringMobs(U.baseName(mob.Name)) end
    local root, p = U.root(), U.mobPos(mob)
    if root and p and (p.Position - root.Position).Magnitude < 45 then
        if C.get("method") == "net" then U.netAttack(C.get("attackdist")) else U.attack(C.get("attackdist")) end
    end
end

-- find the first mob of any name in the list
local function firstMob(names)
    for _, n in ipairs(names) do
        local m = U.nearestMob(n)
        if m then return m end
    end
    return nil
end

-- spawner remotes: some bosses only appear after their remote is spammed
local function fireSpawner(key, s)
    local sp = D and D.spawners and D.spawners[key]
    if not sp then return end
    local now = os.clock()
    if now < s.nextSpawn then return end
    s.nextSpawn = now + (sp[2] or 2)
    for i = 3, #sp do U.F(table.unpack(sp[i])) end
    U.F(table.unpack(sp[1]))
end

-- a step from data.chains --------------------------------------------------
local function runStep(step, s)
    if step.level and U.level() < step.level then
        U.notify("needs level " .. step.level)
        return false
    end
    if step.mobs then
        local m = firstMob(step.mobs)
        if m then
            engage(m, { tool = step.tool })
            return false           -- keep killing until the mob is gone
        end
    end
    if step.remote then U.F(table.unpack(step.remote)) end
    if step.tool then U.equipTool(step.tool) end
    travel(step.cf)
    s.step = s.step + 1
    U.log("i", "step done, next: " .. s.step)
    return true
end

local function runChain(key)
    local chain = D and D.chains and D.chains[key]
    if not chain then return end
    local s = st(key)
    fireSpawner(key, s)
    local step = chain[s.step]
    if not step then
        U.notify(key .. " chain finished")
        C.set("chain_" .. key, false)
        return
    end
    runStep(step, s)
end

-- a row from data.bossFarms ------------------------------------------------
local function runBossFarm(key)
    local row = D and D.bossFarms and D.bossFarms[key]
    if not row then return end
    -- BossSelected: the dropdown value IS the key, resolve it at run time
    if key == "BossSelected" then row = D.bossFarms[C.get("BossSelected") or ""] end
    if not row then return end
    local s = st(key)
    if row[7] and U.level() < row[7] then return end
    fireSpawner(key, s)

    -- some bosses need a summoning tool equipped before they spawn
    if row[3] and U.hasTool(row[3]) then
        U.equipTool(row[3])
        travel(row[4] or row[2])
        return
    end
    local mob = firstMob(row[1])
    if mob then
        engage(mob, { bring = not row[8] })
    elseif row[6] and C.get(row[6]) then
        M.serverHop()
    else
        travel(row[2])
    end
end

-- registry: feature key -> how to drive it --------------------------------
local GENERIC = {
    ["boss_BossSelected"] = "BossSelected",
    ["boss_The Saw"] = "The Saw",
    ["boss_Thunder God"] = "Thunder God",
    ["boss_Cursed Captain"] = "Cursed Captain",
    ["boss_Don Swan"] = "Don Swan",
    ["boss_Darkbeard"] = "Darkbeard",
    ["boss_rip_indra True Form"] = "rip_indra True Form",
    ["boss_Soul Reaper"] = "Soul Reaper",
    ["boss_Order"] = "Order",
    ["mob_Bone"] = "Bone",
    ["mob_Ectoplasm"] = "Ectoplasm",
    ["mob_Candy"] = "Candy",
    ["mob_Pirates Sea"] = "Pirates Sea",
    ["mob_Factory"] = "Factory",
    ["mob_Rengoku"] = "Rengoku",
    ["mob_Tushita"] = "Tushita",
}

local CHAINS = {
    "Ken V2", "Musketeer Hat", "Saber", "Rainbow Haki", "Soul Guitar",
    "Race V2", "Second Sea", "Third Sea",
}

-- KillAllBosses: walk the sea's boss list and kill whatever is up
local function killAllBosses()
    local list = D and D.bossList[U.sea or 1] or {}
    for _, name in ipairs(list) do
        local m = U.nearestMob(name)
        if m then
            engage(m, {})
            return
        end
    end
end

function M.tick(_U, _C)
    if not U.alive() then return end
    for key, row in pairs(GENERIC) do
        if C.get(key) then runBossFarm(row) end
    end
    if C.get("KillAllBosses") then killAllBosses() end
    -- Elite Hunter has no fixed spot: the target changes with the quest
    if C.get("chain_Elite Hunter") then
        local names = { "Diablo", "Deandre", "Urban" }
        local m = firstMob(names)
        if m then
            engage(m, {})
        else
            U.F("EliteHunter")
            if C.get("AutoEliteHunterHop") then M.serverHop() else travel(CFrame.new(-5119, 315, -2964)) end
        end
    end
    for _, key in ipairs(CHAINS) do
        if C.get("chain_" .. key) then runChain(key) end
    end
    -- material farm: mobs + spot come from data.materials2
    if C.get("mat_" .. tostring(C.get("MaterialSelected"))) then
        local sea = D.materials2[U.sea or 1] or {}
        local row = sea[C.get("MaterialSelected")]
        if row then
            local mob = firstMob(row[1])
            if mob then engage(mob, {}) else travel(row[2]) end
        end
    end
    -- fighters: mastery then buy
    for _, f in ipairs(D and D.fighters or {}) do
        if C.get("fighter_" .. f[1]) then
            local mob = firstMob(f[2])
            if mob then
                engage(mob, { tool = C.get("FarmTool") })
            else
                travel(f[3])
                if U.mastery(f[1]) and U.mastery(f[1]) >= (C.get("AutoMasteryValue") or 300) then
                    U.F(f[4], true) U.F(f[4])
                    U.notify("buying " .. f[4])
                    C.set("fighter_" .. f[1], false)
                end
            end
        end
    end
    -- chests: grab whatever chest is in range while farming
    if C.get("AutoChestTween") or C.get("AutoChestBypass") then
        for _, p in ipairs(workspace:GetChildren()) do
            if p:IsA("MeshPart") and string.find(p.Name, "Chest") then
                travel(p.CFrame * CFrame.new(0, 3, 0))
                break
            end
        end
    end
    -- fruit pickup / store
    if C.get("TeleportToFruit") then
        local f = U.nearestFruit()
        if f then travel(f.CFrame * CFrame.new(0, 3, 0)) end
    end
    if C.get("AutoStoreFruits") then U.F("StoreFruit", "1") end
end

-- button actions -----------------------------------------------------------
function M.serverHop()
    local Http = game:GetService("HttpService")
    local TS = game:GetService("TeleportService")
    local ok, body = pcall(function()
        return game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=100", game.PlaceId))
    end)
    if not ok or not body then return U.notify("server list blocked") end
    for _, s in ipairs(Http:JSONDecode(body).data or {}) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            U.notify("hopping...")
            TS:TeleportToPlaceInstance(game.PlaceId, s.id, U.LP)
            return
        end
    end
    U.notify("no free server")
end

return M
