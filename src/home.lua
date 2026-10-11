--[[ home.lua - Home tab: status + debug panel. Built first (it is the landing page). ]]

local M = {}

function M.init(U, C, UI, win)
    local page = win:tab("Home", function(p)
        local c = win:card(p, "Status")
        M.lvl = win:label(c, "")
        local ok, bad = 0, 0
        for _, line in ipairs(U.modules or {}) do
            if line:find("^%[ok%]") then ok = ok + 1 else bad = bad + 1 end
        end
        win:label(c, "modules " .. ok .. " ok" .. (bad > 0 and (", " .. bad .. " failed -> Log") or ""))
        win:debug(p, U, C)

        c = win:card(p, "Quick")
        win:toggle(c, "Auto Farm Level", "AutoFarm_Level")
        win:toggle(c, "Low-End Mode", "lowend")
        win:toggle(c, "Anti-AFK", "AntiAFK")

        c = win:card(p, "Diagnostics")
        win:button(c, "Dump Environment", function()
            U.log("i", "executor " .. tostring(identifyexecutor()))
            U.log("i", "getupvalues " .. type(debug.getupvalues) .. " require " .. type(require) .. " request " .. type(request))
            U.log("i", "setclipboard " .. type(setclipboard) .. " sethiddenproperty " .. type(sethiddenproperty))
            U.log("i", "CombatFramework " .. tostring(U.LP.PlayerScripts:FindFirstChild("CombatFramework") ~= nil))
            U.log("i", "mobs " .. #U.mobs() .. " level " .. U.level() .. " sea " .. tostring(U.sea) .. " place " .. game.PlaceId)
            U.notify("dumped to Log")
        end)

        task.spawn(function()
            while win.gui.Parent do
                if M.lvl then
                    M.lvl.Text = string.format("Lv %d   sea %s   mobs %d   %s",
                        U.level(), tostring(U.sea), #U.mobs(), C.get("AutoFarm_Level") and "FARMING" or "idle")
                end
                task.wait(1)
            end
        end)
    end)
    return M
end

return M
