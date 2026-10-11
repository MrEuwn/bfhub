-- Redeem all working codes. Codes list from open-source Redz Hub V2.
return function(U, UI, C, win)
    local M = {}
    local CODES = {
        "NEWTROLL","KITT_RESET","Sub2Fer999","Magicbus","kittgaming","SECRET_ADMIN",
        "EXP_5B","CONTROL","UPDATE11","XMASEXP","1BILLION","ShutDownFix2","UPD14",
        "STRAWHATMAINE","TantaiGaming","Colosseum","Axiore","Sub2Daigrock","Sky Island 3",
        "Sub2OfficialNoobie","SUB2NOOBMASTER123","THEGREATACE","Fountain City","BIGNEWS",
        "FUDD10","SUB2GAMERROBOT_EXP1","UPD15","2BILLION","UPD16","3BVISITS",
        "Starcodeheo","Bluxxy","DRAGONABUSE","Sub2CaptainMaui","DEVSCOOKING","Enyu_is_Pro",
        "JCWK","fudd10_v2","Sub2NoobMaster123","Sub2UncleKizaru","Sub2Daigrock",
        "StrawHatMaine","FountainCity",
    }
    local t = win:tab("Codes")
    local s = t:section("Redeem")
    s:button("Redeem ALL Codes", function()
        local n = 0
        for _, code in ipairs(CODES) do
            task.spawn(function()
                pcall(function() U.ReplicatedStorage.Remotes.Redeem:InvokeServer(code) end)
            end)
            n = n + 1
            if n % 8 == 0 then task.wait(0.5) end
        end
        U.notify(("Redeeming %d codes..."):format(n))
    end)
    s:label(("%d codes in list"):format(#CODES))
    t:section("Single")
    s:textbox("Code", "", function(v)
        if v and v ~= "" then
            pcall(function() U.ReplicatedStorage.Remotes.Redeem:InvokeServer(v) end)
            U.notify("Redeemed: " .. v)
        end
    end)

    t:section("Team")
    s:button("Join Pirates", function() U.commF("SetTeam", "Pirates") end)
    s:button("Join Marines", function() U.commF("SetTeam", "Marines") end)

    return M
end
