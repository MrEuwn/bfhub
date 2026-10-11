-- Mastery: farm with a chosen weapon category equipped so mastery rises, and
-- best-effort auto-buy for the fighting styles HoHo advertises.
return function(U, UI, C, win)
    local M = {}
    local masteryOn = false

    local STYLES = {
        "Dragon Talon", "Electric Claw", "Godhuman", "Sharkman Karate",
        "Death Step", "Superhuman", "Fishman Karate", "Sanguine Art",
    }

    local t = win:tab("Mastery")
    local s = t:section("Auto Mastery Farm")
    s:dropdown("Weapon to Master", { "Melee", "Sword", "Gun", "Fruit" }, "Melee", function(v) C.set("masteryWeapon", v) end)
    s:toggle("Auto Mastery (farm nearest)", false, function(on) masteryOn = on end)
    s:label("Equips the chosen weapon and farms the nearest mob until mastery caps.")

    t:section("Auto Buy / Learn Style")
    s:label("Best-effort: sends the game's buy-move remote for the selected style.")
    local pick = "Dragon Talon"
    s:dropdown("Style", STYLES, "Dragon Talon", function(v) pick = v end)
    s:button("Buy / Learn Selected", function()
        -- ponytail: remote arg is version-sensitive; check the style NPC prompt.
        U.commF("Buy", pick)
        U.notify("Buy -> " .. pick)
    end)
    for _, name in ipairs(STYLES) do
        s:button("Farm+Buy: " .. name, function()
            U.commF("Buy", name)
            U.notify("Farm+Buy -> " .. name)
        end)
    end

    function M.tick()
        if not masteryOn then return end
        local w = C.get("masteryWeapon") or "Melee"
        U.equipWeapon(w)
        local m = U.nearestMob(nil)
        if m then
            local r = U.root()
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if r and hrp then
                U.applyNoClip(true)
                r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 12, 0))
                U.touch(r, hrp)
            end
            U.attack()
            task.wait(C.get("farmSpeed") or 0.15)
        end
    end

    return M
end
