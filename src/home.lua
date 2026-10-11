--[[ home.lua - Home tab: status, module load results, Log tab, Credits. ]]

local M = {}

function M.init(U, C, UI, win)
    M.U, M.C, M.UI, M.win = U, C, UI, win

    local home = win:tab("Home")
    local st = win:card(home, "Status")
    M.lvl = win:label(st, "loading...")
    local body = win:label(st, "")

    -- module load report: a silent pcall around a module is what produces an
    -- empty menu with no error, so failures are printed here.
    local okCount, failCount = 0, 0
    for _, line in ipairs(U.modules or {}) do
        if string.find(line, "^%[ok%]") then okCount = okCount + 1 else failCount = failCount + 1 end
    end
    body.Text = "modules: " .. okCount .. " ok, " .. failCount .. " failed"
        .. (failCount > 0 and "\nsee Log tab" or "")

    win:debug(home, U, C)

    local cf = win:card(home, "Config")
    win:toggle(cf, "Auto Quest", "accept the quest matching your level", "autoquest")
    win:toggle(cf, "Low-End Mode", "kills particles + shadows (mobile fps)", "lowend")
    win:toggle(cf, "Anti-AFK", nil, "antiafk")
    win:button(cf, "Dump Environment", "executor capabilities + game state", function()
        U.log("i", "executor " .. tostring(identifyexecutor()))
        U.log("i", "debug.getupvalues " .. type(debug.getupvalues) .. "  require " .. type(require) .. "  request " .. type(request))
        U.log("i", "setclipboard " .. type(setclipboard) .. "  sethiddenproperty " .. type(sethiddenproperty))
        U.log("i", "CombatFramework " .. tostring(U.LP.PlayerScripts:FindFirstChild("CombatFramework") ~= nil))
        U.log("i", "RigControllerEvent " .. tostring(U.RS:FindFirstChild("RigControllerEvent") ~= nil))
        U.log("i", "mobs " .. #U.mobs() .. "  level " .. U.level() .. "  place " .. game.PlaceId)
        U.notify("dumped to Log tab")
    end)

    -- Log tab --------------------------------------------------------------
    local logp = win:tab("Log")
    local lc = win:card(logp, "Log")
    M.loglabel = win:label(lc, "")
    win:button(lc, "Copy to Clipboard", nil, function()
        pcall(function() setclipboard(U.logText()) end)
        U.notify("log copied")
    end)
    win:button(lc, "Clear", nil, function()
        U.logs = {}
        M.loglabel.Text = ""
    end)
    win:button(lc, "Send to Webhook", "URL set in Misc", function()
        local url = C.get("webhook")
        if url == "" then return U.notify("no webhook url") end
        pcall(function()
            local body = U.logText():sub(1, 1900)
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
            M.lvl.Text = string.format("Lv %d   sea %s   mobs %d", U.level(), tostring(game.PlaceId), #U.mobs())
            M.loglabel.Text = U.logText()
            task.wait(1)
        end
    end)

    -- Credits --------------------------------------------------------------
    local cr = win:tab("Credits")
    local cc = win:card(cr, "Credits")
    win:label(cc, "Raf's Personal Script - BFHub")
    win:label(cc, "keyless, open source, no obfuscation")
    win:label(cc, "quest table + farm loop order learned from public open-source hubs")
    win:label(cc, "this is a cheat - use an alt account")
    return M
end

return M
