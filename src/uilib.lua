-- Raf's Personal Script - UI shim.
-- Drop-in replacement for the obfuscated Lib_5.5.0.lua that the recovered hub
-- body calls into. Same surface (CreateWindow / CreateTab / AddSection /
-- AddToggle / AddButton / AddDropdown / AddParagraph / AddSeperator / AddLine /
-- SetNotification / Unloaded), but built from Instance.new so it stays light on
-- mobile and matches our own palette.
local UILib = {}

local BG      = Color3.fromRGB(17, 18, 24)
local HEADER  = Color3.fromRGB(24, 26, 34)
local SIDEBAR = Color3.fromRGB(21, 22, 29)
local CARD    = Color3.fromRGB(26, 28, 36)
local ROW     = Color3.fromRGB(33, 35, 45)
local ROW_HI  = Color3.fromRGB(41, 44, 56)
local ACCENT  = Color3.fromRGB(122, 140, 255)
local ACCENT2 = Color3.fromRGB(90, 200, 210)
local TXT     = Color3.fromRGB(226, 228, 238)
local MUTED   = Color3.fromRGB(150, 154, 172)
local OFF     = Color3.fromRGB(60, 62, 74)

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = o; return c end
local function stroke(o, col, th, tr) local s = Instance.new("UIStroke")
    s.Color = col; s.Thickness = th or 1; s.Transparency = tr or 0.6
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = o; return s end
local function pad(o, n) local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, n); p.PaddingBottom = UDim.new(0, n)
    p.PaddingLeft = UDim.new(0, n); p.PaddingRight = UDim.new(0, n); p.Parent = o; return p end

local function text(parent, str, size, color, font, xa)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = str or ""
    l.TextSize = size or 12; l.TextColor3 = color or TXT
    l.Font = font or Enum.Font.Gotham
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 1, 0); l.Parent = parent
    return l
end

-- one section = one rounded card with a title and a stack of rows
local function makeSection(page, name)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(1, -8, 0, 30); box.BackgroundColor3 = CARD
    box.BorderSizePixel = 0; box.Parent = page; corner(box, 10)
    stroke(box, ACCENT, 1, 0.85)
    box.AutomaticSize = Enum.AutomaticSize.Y

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -16, 0, 26); t.Position = UDim2.new(0, 12, 0, 3)
    t.BackgroundTransparency = 1; t.Text = string.upper(name or "")
    t.TextColor3 = ACCENT2; t.Font = Enum.Font.GothamBold; t.TextSize = 11
    t.TextXAlignment = Enum.TextXAlignment.Left; t.Parent = box

    local rows = Instance.new("Frame")
    rows.Size = UDim2.new(1, -12, 0, 0); rows.Position = UDim2.new(0, 6, 0, 28)
    rows.BackgroundTransparency = 1; rows.AutomaticSize = Enum.AutomaticSize.Y; rows.Parent = box
    local rl = Instance.new("UIListLayout"); rl.Padding = UDim.new(0, 5); rl.Parent = rows
    local rp = Instance.new("UIPadding"); rp.PaddingBottom = UDim.new(0, 8); rp.Parent = rows

    local sec = {}

    -- live text block; hub keeps the handle and calls :Set{Title,Content}
    local function paragraph(cfg)
        cfg = cfg or {}
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 16); l.BackgroundTransparency = 1
        l.TextWrapped = true; l.AutomaticSize = Enum.AutomaticSize.Y
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Top
        l.TextColor3 = Color3.fromRGB(196, 199, 214); l.Font = Enum.Font.Gotham; l.TextSize = 12
        l.Text = cfg.Content or cfg.Title or ""
        l.Parent = rows
        local o = {}
        function o:Set(c) c = c or {}; l.Text = c.Content or c.Title or ""; return o end
        function o:AddLine() sec:AddLine(); return o end
        function o:AddParagraph(c) return paragraph(c) end
        function o:AddSeperator(c) return sec:AddSeperator(c) end
        function o:AddToggle(...) return sec:AddToggle(...) end
        function o:AddButton(...) return sec:AddButton(...) end
        function o:AddDropdown(...) return sec:AddDropdown(...) end
        return o
    end

    function sec:AddParagraph(cfg) return paragraph(cfg) end

    function sec:AddLine()
        local l = Instance.new("Frame")
        l.Size = UDim2.new(1, 0, 0, 1); l.BackgroundColor3 = ROW_HI
        l.BorderSizePixel = 0; l.Parent = rows
        return l
    end

    function sec:AddSeperator(list)
        local label = type(list) == "table" and (list[1] or "") or tostring(list or "")
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 14); l.BackgroundTransparency = 1
        l.Text = string.upper(label); l.TextColor3 = MUTED
        l.Font = Enum.Font.GothamBold; l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = rows
        return l
    end

    function sec:AddToggle(cfg)
        cfg = cfg or {}
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundColor3 = ROW
        row.Text = ""; row.BorderSizePixel = 0; row.AutoButtonColor = false
        row.Parent = rows; corner(row, 8)
        local l = text(row, cfg.Title or "", 12, TXT, Enum.Font.Gotham)
        l.Size = UDim2.new(1, -58, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)

        local state = cfg.Default and true or false
        local pill = Instance.new("Frame")
        pill.Size = UDim2.fromOffset(38, 20); pill.Position = UDim2.new(1, -48, 0.5, -10)
        pill.BackgroundColor3 = state and ACCENT or OFF
        pill.BorderSizePixel = 0; pill.Parent = row; corner(pill, 10)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.fromOffset(16, 16)
        knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        knob.BackgroundColor3 = Color3.fromRGB(245, 246, 252); knob.BorderSizePixel = 0
        knob.Parent = pill; corner(knob, 8)

        local function paint()
            pill.BackgroundColor3 = state and ACCENT or OFF
            knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        end
        row.MouseButton1Click:Connect(function()
            state = not state; paint()
            if cfg.Callback then task.spawn(cfg.Callback, state) end
        end)
        local o = {}
        function o:Set(v)
            if type(v) == "table" then state = v.Value and true or false else state = v and true or false end
            paint(); return o
        end
        return o
    end

    function sec:AddButton(cfg)
        cfg = cfg or {}
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundColor3 = ROW_HI
        row.Text = cfg.Title or ""; row.TextColor3 = TXT
        row.Font = Enum.Font.GothamMedium; row.TextSize = 12
        row.BorderSizePixel = 0; row.AutoButtonColor = true
        row.Parent = rows; corner(row, 8)
        row.MouseButton1Click:Connect(function()
            if cfg.Callback then task.spawn(cfg.Callback) end
        end)
        return row
    end

    function sec:AddDropdown(cfg)
        cfg = cfg or {}
        local opts = cfg.Options or { "" }
        local multi = cfg.Multi and true or false
        local cur = {}
        local def = cfg.Default
        if type(def) == "table" then cur = def
        elseif def ~= nil then cur = { def } end
        if #cur == 0 then cur = { opts[1] } end

        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundColor3 = ROW
        row.Text = ""; row.BorderSizePixel = 0; row.AutoButtonColor = false
        row.Parent = rows; corner(row, 8)
        local l = text(row, cfg.Title or "", 12, TXT, Enum.Font.Gotham)
        l.Size = UDim2.new(0.5, 0, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
        local v = text(row, table.concat(cur, ", "), 12, ACCENT, Enum.Font.GothamMedium,
                       Enum.TextXAlignment.Right)
        v.Size = UDim2.new(0.45, 0, 1, 0); v.Position = UDim2.new(0.55, 0, 0, 0)

        -- single-select cycles in place; multi-select opens a small picker so the
        -- hub's multi dropdowns (skills, materials) stay usable on mobile.
        local function fire()
            v.Text = table.concat(cur, ", ")
            if cfg.Callback then task.spawn(cfg.Callback, multi and cur or cur[1]) end
        end
        if not multi then
            row.MouseButton1Click:Connect(function()
                local i = 1
                for k, o in ipairs(opts) do if o == cur[1] then i = k end end
                cur = { opts[i % #opts + 1] }
                fire()
            end)
        else
            local open = false
            local menu = Instance.new("Frame")
            menu.Size = UDim2.new(1, 0, 0, 0); menu.BackgroundColor3 = SIDEBAR
            menu.BorderSizePixel = 0; menu.Visible = false; menu.Parent = rows; corner(menu, 8)
            menu.AutomaticSize = Enum.AutomaticSize.Y
            local ml = Instance.new("UIListLayout"); ml.Padding = UDim.new(0, 3); ml.Parent = menu
            pad(menu, 6)
            for _, o in ipairs(opts) do
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, 0, 0, 26); b.BackgroundColor3 = ROW
                b.Text = o; b.TextColor3 = TXT; b.Font = Enum.Font.Gotham; b.TextSize = 11
                b.BorderSizePixel = 0; b.Parent = menu; corner(b, 6)
                b.MouseButton1Click:Connect(function()
                    local found
                    for k, c in ipairs(cur) do if c == o then found = k end end
                    if found then table.remove(cur, found) else table.insert(cur, o) end
                    fire()
                end)
            end
            row.MouseButton1Click:Connect(function()
                open = not open; menu.Visible = open
            end)
        end
        local o = {}
        function o:Set(vals) cur = type(vals) == "table" and vals or { vals }; fire(); return o end
        return o
    end

    function sec:AddInput(cfg)
        cfg = cfg or {}
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 15); l.BackgroundTransparency = 1
        l.Text = cfg.Title or ""; l.TextColor3 = MUTED; l.Font = Enum.Font.Gotham
        l.TextSize = 11; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = rows
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(1, 0, 0, 28); box.BackgroundColor3 = ROW
        box.Text = tostring(cfg.Default or ""); box.PlaceholderText = "..."
        box.TextColor3 = TXT; box.Font = Enum.Font.Gotham; box.TextSize = 11
        box.BorderSizePixel = 0; box.ClearTextOnFocus = false; box.Parent = rows; corner(box, 8)
        box.FocusLost:Connect(function()
            if cfg.Callback then task.spawn(cfg.Callback, box.Text) end
        end)
        return box
    end

    -- lowercase aliases for the older positional API (used by our extra modules):
    --   sec:toggle(label, default, cb) / :dropdown(label, opts, default, cb)
    --   sec:button(label, cb) / :textbox(label, default, cb)
    -- label/paragraph return the TextLabel itself so callers can set `.Text`.
    function sec:toggle(label, default, cb)
        return sec:AddToggle({ Title = label, Default = default, Callback = cb })
    end
    function sec:button(label, cb)
        return sec:AddButton({ Title = label, Callback = cb })
    end
    function sec:dropdown(label, options, default, cb)
        return sec:AddDropdown({ Title = label, Options = options, Default = default, Callback = cb })
    end
    function sec:textbox(label, default, cb)
        return sec:AddInput({ Title = label, Default = default, Callback = cb })
    end
    function sec:label(txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1
        l.Text = txt or ""; l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = MUTED; l.Font = Enum.Font.Gotham; l.TextSize = 11
        l.Parent = rows
        return l
    end
    function sec:paragraph(txt)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1
        l.Text = txt or ""; l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Top; l.TextWrapped = true
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.TextColor3 = Color3.fromRGB(196, 199, 214)
        l.Font = Enum.Font.Gotham; l.TextSize = 12
        l.Parent = rows
        return l
    end

    return sec
end

function UILib.new()
    local lib = { Unloaded = false }

    function lib:CreateWindow(cfg)
        cfg = cfg or {}
        local plr = game:GetService("Players").LocalPlayer
        local pgui = plr:WaitForChild("PlayerGui")
        local old = pgui:FindFirstChild("RPS")
        if old then old:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name = "RPS"; gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.IgnoreGuiInset = true; gui.DisplayOrder = 999; gui.Parent = pgui

        local fab = Instance.new("TextButton")
        fab.Size = UDim2.fromOffset(54, 54); fab.Position = UDim2.new(0, 14, 0.5, -27)
        fab.BackgroundColor3 = ACCENT; fab.Text = "R"; fab.TextColor3 = Color3.fromRGB(16, 17, 22)
        fab.Font = Enum.Font.GothamBold; fab.TextSize = 22; fab.BorderSizePixel = 0
        fab.Active = true; fab.Draggable = true; fab.Visible = false; fab.Parent = gui
        corner(fab, 27); stroke(fab, Color3.fromRGB(255, 255, 255), 1, 0.75)

        local frame = Instance.new("Frame")
        frame.Size = UDim2.fromOffset(520, 400)
        frame.Position = UDim2.new(0.5, 0, 0.5, 20); frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundColor3 = BG; frame.BorderSizePixel = 0
        frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true
        frame.Parent = gui; corner(frame, 18); stroke(frame, ACCENT, 1, 0.55)

        local top = Instance.new("Frame")
        top.Size = UDim2.new(1, 0, 0, 46); top.BackgroundColor3 = HEADER
        top.BorderSizePixel = 0; top.Parent = frame; corner(top, 18)

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, 0, 0, 2); bar.Position = UDim2.new(0, 0, 0, 46)
        bar.BackgroundColor3 = ACCENT; bar.BorderSizePixel = 0; bar.Parent = frame

        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, -70, 1, -6); tl.Position = UDim2.new(0, 16, 0, 4)
        tl.BackgroundTransparency = 1; tl.Text = cfg.Title or "Script"
        tl.TextColor3 = TXT; tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.TextYAlignment = Enum.TextYAlignment.Top
        tl.Font = Enum.Font.GothamBold; tl.TextSize = 14; tl.Parent = top

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -70, 1, -8); sub.Position = UDim2.new(0, 16, 0, 10)
        sub.BackgroundTransparency = 1; sub.Text = "Raf's Personal Script"
        sub.TextColor3 = MUTED; sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.TextYAlignment = Enum.TextYAlignment.Bottom
        sub.Font = Enum.Font.Gotham; sub.TextSize = 11; sub.Parent = top

        local min = Instance.new("TextButton")
        min.Size = UDim2.fromOffset(30, 30); min.Position = UDim2.new(1, -40, 0, 8)
        min.BackgroundColor3 = ROW; min.Text = "-"; min.TextColor3 = TXT
        min.Font = Enum.Font.GothamBold; min.TextSize = 18
        min.BorderSizePixel = 0; min.Parent = top; corner(min, 9); stroke(min, ACCENT, 1, 0.7)

        local tabbar = Instance.new("ScrollingFrame")
        tabbar.Size = UDim2.new(0, 138, 1, -48); tabbar.Position = UDim2.new(0, 0, 0, 48)
        tabbar.BackgroundColor3 = SIDEBAR; tabbar.BorderSizePixel = 0; tabbar.Parent = frame
        tabbar.ScrollBarThickness = 3; tabbar.ScrollBarImageColor3 = ACCENT
        tabbar.ScrollingDirection = Enum.ScrollingDirection.Y
        tabbar.AutomaticCanvasSize = Enum.AutomaticSize.Y
        tabbar.CanvasSize = UDim2.new(0, 0, 0, 0); tabbar.Active = true
        local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 3); list.Parent = tabbar
        pad(tabbar, 6)

        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, -138, 1, -48); body.Position = UDim2.new(0, 138, 0, 48)
        body.BackgroundTransparency = 1; body.ClipsDescendants = true; body.Parent = frame

        local pages, buttons, first = {}, {}, true

        local function select(name)
            for n, p in pairs(pages) do p.Visible = (n == name) end
            for _, b in ipairs(buttons) do
                local on = (b.name == name)
                b.label.TextColor3 = on and TXT or MUTED
                b.mark.Visible = on
                b.btn.BackgroundColor3 = on and ROW_HI or ROW
            end
        end

        local win = {}
        function win:CreateTab(t)
            t = t or {}
            local name = t.Name or "Tab"
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 32); btn.BackgroundColor3 = ROW
            btn.Text = ""; btn.BorderSizePixel = 0; btn.AutoButtonColor = true
            btn.Parent = tabbar; corner(btn, 9)
            local mark = Instance.new("Frame")
            mark.Size = UDim2.new(0, 3, 0.6, 0); mark.Position = UDim2.new(0, 0, 0.2, 0)
            mark.BackgroundColor3 = ACCENT; mark.BorderSizePixel = 0
            mark.Visible = false; mark.Parent = btn; corner(mark, 2)
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -14, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
            l.BackgroundTransparency = 1; l.Text = name
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextColor3 = MUTED; l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.Parent = btn

            local page = Instance.new("ScrollingFrame")
            page.Size = UDim2.new(1, -8, 1, -8); page.Position = UDim2.new(0, 4, 0, 4)
            page.BackgroundTransparency = 1; page.BorderSizePixel = 0; page.Visible = false
            page.ScrollBarThickness = 6; page.ScrollBarImageColor3 = ACCENT
            page.ScrollingDirection = Enum.ScrollingDirection.Y
            page.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
            page.AutomaticCanvasSize = Enum.AutomaticSize.Y
            page.CanvasSize = UDim2.new(0, 0, 0, 0); page.Active = true
            page.Parent = body
            local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 8); ll.Parent = page
            pad(page, 6)

            pages[name] = page
            table.insert(buttons, { btn = btn, label = l, mark = mark, name = name })
            btn.MouseButton1Click:Connect(function() select(name) end)
            if first then first = false; task.defer(function() select(name) end) end

            local tab = {}
            function tab:AddSection(sname) return makeSection(page, sname) end
            return tab
        end

        min.MouseButton1Click:Connect(function() frame.Visible = false; fab.Visible = true end)
        fab.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible; fab.Visible = not frame.Visible
        end)
        return win
    end

    -- hub calls it as lib:SetNotification(t) and as setNotification(lib, t)
    function lib:SetNotification(t)
        t = t or {}
        local plr = game:GetService("Players").LocalPlayer
        pcall(function()
            plr:GetGui():SetCore("SendNotification", {
                Title = tostring(t[1] or "Raf's Personal Script"),
                Text = tostring(t[3] or t[2] or ""),
                Duration = tonumber(t[4]) or 5,
            })
        end)
        return true
    end

    return lib
end

return UILib
