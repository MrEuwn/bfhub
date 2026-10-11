--[[ home.lua - Home tab: status, module load report, Log tab, Credits. ]]

local M = {}
local U, C, UI, win

function M.init(_U, _C, _UI, _w)
    U, C, UI, win = _U, _C, _UI, _w

    local home = win:tab("Home")
    local st = win:card(home, "Status")
    M.lvl = win:label(st, "loading...")
    local ok, bad = 0, 0
    for _, line in ipairs(U.modules or {}) do
        if line:find("^%[ok%]") then ok = ok + 1 else bad = bad + 1 end
    end
    win:label(st, "modules: " .. ok .. " ok, " .. bad .. " failed" .. (bad > 0 and "  -> Log tab" or ""))
    win:debug(home, U, C)

    local cf = win:card(home, "Quick")
    win:toggle(cf, "Auto Farm Level", "the main switch", "farm")
    win:toggle(cf, "Low-End Mode", "kills particles + shadows (mobile fps)", "lowend")
    win:toggle(cf, "Anti-AFK", nil, "antiafk")
    win:button(cf, "Dump Environment", "executor capabilities + game state", function()
        U.log("i", "executor " .. tostring(identifyexecutor()))
        U.log("i", "debug.getupvalues " .. type(debug.getupvalues) .. "  require " .. type(require) .. "  request " .. type(request))
        U.log("i", "setclipboard " .. type(setclipboard) .. "  sethiddenproperty " .. type(sethiddenproperty))
        U.log("i", "CombatFramework " .. tostring(U.LP.PlayerScripts:FindFirstChild("CombatFramework") ~= nil))
        U.log("i", "mobs " .. #U.mobs() .. "  level " .. U.level() .. "  sea " .. tostring(U.sea) .. "  place " .. game.PlaceId)
        U.notify("dumped to Log tab")
    end)
    win:button(cf, "Refresh", "re-read islands and reload", function() U.notify("ok") end)

    -- Log tab --------------------------------------------------------------
    local logp = win:tab("Log")
    local lc = win:card(logp, "Log")
    M.loglabel = win:label(lc, "")
    win:button(lc, "Copy to Clipboard", nil, function()
        pcall(function() setclipboard(U.logText and U.logText() or table.concat(U.logs, "\n")) end)
        U.notify("log copied")
    end)
    win:button(lc, "Clear", nil, function()
        U.logs = {}
        M.loglabel.Text = ""
    end)
    win:button(lc, "Send to Webhook", "URL set in Misc", function()
        local url = C.get("webhook")
        if not url or url == "" then return U.notify("no webhook url") end
        pcall(function()
            local body = (U.logText and U.logText() or table.concat(U.logs, "\n")):sub(1, 1900)
            request({
                Url = url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = game:GetService("HttpService"):JSONEncode({ content = "```" .. body .. "```" }),
            })
        end)
        U.notify("sent")
    end)

    task.spawn(function()
        while win.gui.Parent do
            M.lvl.Text = string.format("Lv %d   sea %s   mobs %d   %s",
                U.level(), tostring(U.sea), #U.mobs(), tostring(C.get("farm") and "FARMING" or "idle"))
            M.loglabel.Text = (U.logText and U.logText() or table.concat(U.logs, "\n"))
            task.wait(1)
        end
    end)

    -- Credits --------------------------------------------------------------
    local cr = win:tab("Credits")
    local cc = win:card(cr, "Credits")
    win:label(cc, "Raf's Personal Script")
    win:label(cc, "keyless, open source, no obfuscation")
    win:label(cc, "feature set ported from the public Redz Hub V2 source")
    win:label(cc, "this is a cheat - use an alt account")
    return M
end

return M
