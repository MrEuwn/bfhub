-- FuncsV3 adapter, rebuilt from the readable upstream file.
-- The recovered hub body calls result2:Toggle/Dropdown/Button/Textbox with a
-- different argument order than the UI shim's Add* primitives; this is the thin
-- translation layer between them (same contract as the original FuncsV3).
local Funcs = {}
local SaveConfig = nil

local function Checker(Val, Val1, Val2)
    return typeof(Val) == Val1 and Val or Val2
end

function Funcs:SetTable(path)
    SaveConfig = path
end

local function saved(name, fallback)
    if SaveConfig and SaveConfig[name] ~= nil then return SaveConfig[name] end
    return fallback
end

function Funcs:Toggle(Tab, Name, Content, Default, Callback)
    Name = Checker(Name, "string", tostring(Name))
    local def
    if Default == "Save" then def = Checker(saved(Name, nil), "boolean", false)
    else def = Checker(Default, "boolean", false) end
    return Tab:AddToggle({ Title = Name, Content = Content, Default = def, Callback = Callback })
end

function Funcs:Button(Tab, Name, Content, Callback)
    Name = Checker(Name, "string", tostring(Name))
    return Tab:AddButton({ Title = Name, Content = Content, Callback = Callback })
end

function Funcs:Dropdown(Tab, Name, Content, multi, options, Default, Callback)
    Name = Checker(Name, "string", tostring(Name))
    multi = Checker(multi, "boolean", false)
    options = Checker(options, "table", { "" })
    local def
    if Default == "Save" then
        def = type(saved(Name, nil)) == "table" and saved(Name) or { saved(Name, options[1]) }
    else
        def = type(Default) == "table" and Default or { Default or options[1] }
    end
    return Tab:AddDropdown({
        Title = Name, Content = Content, Multi = multi,
        Options = options, Default = def, Callback = Callback,
    })
end

function Funcs:Textbox(Tab, Name, Content, Default, Callback)
    Name = Checker(Name, "string", tostring(Name))
    local def
    if Default == "Save" then def = Checker(saved(Name, nil), "string", "")
    else def = Checker(Default, "string", "") end
    return Tab:AddInput({ Title = Name, Content = Content, Default = def, Callback = Callback })
end

return Funcs
