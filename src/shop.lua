-- Shop / buy / redeem. Remote names taken from open-source Redz Hub V2.
return function(U, UI, C, win)
    local M = {}
    local t = win:tab("Shop")

    local STYLES = {
        "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
        "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon",
        "Godhuman", "Sanguine Art", "Geppo", "Buso", "Soru",
    }
    local SWORDS = {
        "Katana", "Cutlass", "Dual Katana", "Iron Mace", "Triple Katana", "Pipe",
        "Dual-Headed Blade", "Soul Cane", "Bisento", "Dark Blade", "Midnight Blade",
    }
    local GUNS = {
        "Musket", "Slingshot", "Flintlock", "Refined Slingshot", "Refined Flintlock",
        "Cannon", "Kabucha",
    }
    local ACCS = { "Black Cape", "Swordsman Hat", "Tomoe Ring" }

    local function buy(remote, ...)
        U.commF(remote, ...)
        U.notify("Buy -> " .. tostring(remote))
    end

    local s = t:section("Fighting Styles")
    for _, n in ipairs(STYLES) do
        s:button("Buy " .. n, function()
            U.commF(n, true)   -- Redz BuyFightStyle: FireRemote(style, true) then FireRemote(style)
            U.commF(n)
            U.notify("Learn -> " .. n)
        end)
    end

    -- ponytail: buy remotes for gear are "Buy<Name>" with spaces/dashes removed.
    -- If a specific item does nothing, check its shop NPC prompt and adjust.
    local function compact(nm) return (nm:gsub("[%s%-]","")) end

    local sw = t:section("Swords")
    for _, n in ipairs(SWORDS) do sw:button("Buy " .. n, function() buy("Buy" .. compact(n)) end) end

    local gs = t:section("Guns")
    for _, n in ipairs(GUNS) do gs:button("Buy " .. n, function() buy("Buy" .. compact(n)) end) end

    local ac = t:section("Accessories")
    for _, n in ipairs(ACCS) do ac:button("Buy " .. n, function() buy("Buy" .. compact(n)) end) end

    t:section("Fruit / Race / Stats")
    s = t:section("Cousin / Reroll")
    s:button("Auto Random Fruit (Cousin Buy)", function() U.commF("Cousin", "Buy"); U.notify("Cousin buy fired") end)
    s:button("Race Reroll (300 Bones)", function() U.commF("Bones", "Buy", 1, 3) end)
    s:button("Stats Refund (150 Bones)", function() U.commF("Bones", "Buy", 1, 2) end)
    s:button("Race Reroll (100 Candies)", function() U.commF("Candies", "Check"); U.commF("Candies", "Buy", 1, 3) end)
    s:button("Blackbeard Reroll", function()
        U.commF("BlackbeardReward", "Reroll", "1"); U.commF("BlackbeardReward", "Reroll", "2")
    end)
    s:button("Blackbeard Refund (reset stats)", function()
        U.commF("BlackbeardReward", "Refund", "1"); U.commF("BlackbeardReward", "Refund", "2")
    end)

    t:section("Raid Chip")
    s:button("Buy Special Microchip", function() U.commF("RaidsNpc", "Select", "Special Microchip") end)
    s:button("Trade Bone (Bones Buy 1,1)", function() U.commF("Bones", "Buy", 1, 1) end)

    return M
end
