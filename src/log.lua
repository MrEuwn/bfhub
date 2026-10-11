-- Log tab: live error log (message + traceback + line), Copy, Clear, and push
-- to a Discord webhook. Also captures engine errors via LogService.
return function(U, UI, C, win)
    local M = {}
    local view, autoScroll

    -- capture Roblox engine errors too
    pcall(function()
        game:GetService("LogService").MessageOut:Connect(function(msg, typ)
            if typ == Enum.MessageType.MessageError then
                U.logAdd("ENGINE", msg)
            end
        end)
    end)

    local t = win:tab("Log")
    local s = t:section("Errors / Output")
    view = s:paragraph("no logs yet")

    t:section("Actions")
    s:button("Copy Log to Clipboard", function()
        pcall(function() setclipboard(U.logText()) end)
        U.notify("Log copied (" .. #U.logs .. " lines)")
    end)
    s:button("Clear Log", function() U.logs = {}; view.Text = "cleared" end)
    s:button("Send Log to Webhook", function()
        local ok, err = U.sendWebhook("BFHub log - Sea " .. U.currentSea() .. " Lv." .. U.level())
        U.notify(ok and "Log sent" or ("Webhook failed: " .. tostring(err)))
    end)

    t:section("Webhook")
    s:textbox("Discord webhook URL", "", function(v) U.webhook = v; U.notify("Webhook set") end)
    s:label("Paste a Discord webhook URL above to auto-report errors.")

    t:section("Diagnostics")
    s:button("Test Attack (RigControllerEvent)", function()
        local ok, err = U.safe("attackHit", U.attackHit, 60)
        U.notify(ok and "attackHit ran (check Log)" or "attackHit failed (see Log)")
    end)
    s:button("Test FastAttack", function()
        U.safe("fastAttack", U.fastAttack)
        U.notify("fastAttack ran (check Log)")
    end)
    s:button("Dump Environment", function()
        local lines = {
            "executor: " .. tostring(identifyexecutor and identifyexecutor() or "?"),
            "debug.getupvalues: " .. tostring(type(debug and debug.getupvalues)),
            "require: " .. tostring(type(require)),
            "request: " .. tostring(type(request)),
            "setclipboard: " .. tostring(type(setclipboard)),
            "RigControllerEvent: " .. tostring(U.ReplicatedStorage:FindFirstChild("RigControllerEvent") ~= nil),
            "CombatFramework: " .. tostring(U.ReplicatedStorage:FindFirstChild("CombatFramework") ~= nil),
            "Enemies folder: " .. tostring(U.enemies() ~= nil),
            "mobs found: " .. tostring(#U.mobs(nil)),
            "Data.Level: " .. tostring(U.level()),
        }
        U.logAdd("ENV", table.concat(lines, " | "))
        view.Text = U.logText()
        U.notify("Environment dumped to Log")
    end)

    local last = 0
    function M.tick()
        if os.clock() - last < 1 then return end
        last = os.clock()
        view.Text = (#U.logs > 0) and U.logText() or "no logs yet"
    end

    return M
end
