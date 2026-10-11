-- Debug / status tab (HoHo-style live panel): FPS, ping, time played, level,
-- current farm target, quest state, fruit spawn, job id.
return function(U, UI, C, win)
    local M = {}
    local t0 = os.clock()
    local frames, fpsAcc, fpsTime = 0, 0, 0

    U.RunService.RenderStepped:Connect(function()
        frames = frames + 1
    end)

    local t = win:tab("Debug")
    local s = t:section("Status")
    local lbl = s:paragraph("starting...")

    local function fmtTime(sec)
        local m = math.floor(sec / 60); local ss = math.floor(sec % 60)
        return ("%02d:%02d"):format(m, ss)
    end

    local fruitAt, fruitVal = 0, false
    local function fruitSpawned()
        if os.clock() - fruitAt < 3 then return fruitVal end
        fruitAt = os.clock()
        fruitVal = false
        for _, d in ipairs(workspace:GetChildren()) do
            if d:IsA("Tool") and string.find(string.lower(d.Name), "fruit", 1, true) then fruitVal = true; break end
        end
        return fruitVal
    end

    function M.tick()
        frames = 0
        task.wait(1)
        local fps = frames
        local sea = U.currentSea()
        local lines = {
            ("Fps: %d   Ping: %dms"):format(fps, U.ping()),
            ("Time Played: %s"):format(fmtTime(os.clock() - t0)),
            ("Sea: %d   Level: %d"):format(sea, U.level()),
            ("Weapon: %s"):format(tostring(C.get("weapon") or "None")),
            ("Farm Target: %s"):format(tostring(C.get("farmTarget") or "-")),
            ("Quest Active: %s"):format(U.questActive() and "yes" or "no"),
            ("Tween: %s   NoClip: %s"):format(C.get("useTween") and "on" or "off", C.get("noclipAlways") and "on" or "off"),
            ("Fruit Spawned: %s"):format(fruitSpawned() and "yes" or "no"),
            ("Mobs Nearby: %d"):format(#U.mobs(nil)),
            ("Job ID: %s"):format(game.JobId or "-"),
        }
        lbl.Text = table.concat(lines, "\n")
    end

    return M
end
