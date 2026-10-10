-- Shop / buy items. Sends the game's buy remote; list kept short and honest.
return function(U, UI, C, win)
    local M = {}
    local ITEMS = {
        "Sword", "Gun", "Fruit", "Haki", "Race Reroll", "Microchip", "Legendary Sword",
        "Superhuman", "Death Step", "Sharkman Karate", "Electro", "Dragon Talon",
    }
    local t = win:tab("Shop")
    local s = t:section("Buy Items")
    s:label("Sends buy remote (CommF_ 'Buy'). Item must exist in current shop/NPC.")
    for _, name in ipairs(ITEMS) do
        s:button("Buy: " .. name, function()
            U.commF("Buy", name)
            U.notify("Buy -> " .. name)
        end)
    end
    t:section("Utility")
    s:button("Reroll Race", function() U.commF("BlackbeardReward", "Race", "2") end)
    return M
end
