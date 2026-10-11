-- Stats: auto-spend points across Melee/Defense/Sword/Gun/Fruit.
return function(U, UI, C, win)
    local M = {}
    local alloc = { Melee = true, Defense = true, Sword = false, Gun = false, Fruit = false }
    local last = 0

    local function points()
        local d = U.player:FindFirstChild("Data")
        for _, key in ipairs({ "Points", "StatPoint", "StatPoints" }) do
            local v = d and d:FindFirstChild(key)
            if v then return v.Value end
        end
        -- fallback: read from the stats GUI if present
        local pg = U.player:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("Main")
        local st = main and main:FindFirstChild("Stat")
        return 0
    end

    local t = win:tab("Stats")
    local s = t:section("Auto Stats")
    s:label("Spends available points on the checked stats.")
    s:toggle("Melee", true, function(on) alloc.Melee = on end)
    s:toggle("Defense", true, function(on) alloc.Defense = on end)
    s:toggle("Sword", false, function(on) alloc.Sword = on end)
    s:toggle("Gun", false, function(on) alloc.Gun = on end)
    s:toggle("Fruit", false, function(on) alloc.Fruit = on end)
    s:toggle("Auto Spend Points", false, function(on) C.set("autoStats", on) end)

    t:section("Manual")
    local S = { "Melee", "Defense", "Sword", "Gun", "Fruit" }
    for _, stat in ipairs(S) do
        s:button("+100 " .. stat, function() U.commF("AddPoint", stat, 100) end)
    end
    s:button("Reset Stats (Blackbeard Refund)", function()
        U.commF("BlackbeardReward", "Refund", "1"); U.commF("BlackbeardReward", "Refund", "2")
    end)

    function M.tick()
        if not C.get("autoStats") then return end
        if os.clock() - last < 0.5 then return end
        last = os.clock()
        for stat, on in pairs(alloc) do
            if on then U.commF("AddPoint", stat, 1) end
        end
    end

    return M
end
