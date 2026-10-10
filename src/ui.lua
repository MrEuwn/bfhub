-- Minimal custom UI. No Rayfield/Fluent/Kavo -> smallest footprint on mobile.
-- API: UI.new(title) -> win
--   win:tab(name) -> tab
--   tab:section(name) -> sec
--   sec:toggle(label, default, cb) / sec:button(label, cb) / sec:label(text)
--   sec:paragraph(text) -> TextLabel (multi-line, auto height)
--   sec:dropdown(label, options, default, cb)
--   win:show() / win:hide()
-- A round floating button appears whenever the window is hidden (minimize or
-- win:hide()) and toggles it back. Tapping it again reopens the menu.
local UI = {}
local ACCENT = Color3.fromRGB(145, 155, 55)

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = o end
local function pad(o, n) local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, n); p.PaddingBottom = UDim.new(0, n)
    p.PaddingLeft = UDim.new(0, n); p.PaddingRight = UDim.new(0, n); p.Parent = o end

function UI.new(title)
    local plr = game:GetService("Players").LocalPlayer
    local pgui = plr:WaitForChild("PlayerGui")
    local old = pgui:FindFirstChild("BFHub")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "BFHub"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
    gui.Parent = pgui

    -- floating open/close button (visible only while the window is hidden)
    local fab = Instance.new("TextButton")
    fab.Name = "BFHubFab"; fab.Size = UDim2.fromOffset(52, 52)
    fab.Position = UDim2.new(0, 12, 0.5, -26); fab.BackgroundColor3 = ACCENT
    fab.Text = "BF"; fab.TextColor3 = Color3.fromRGB(20, 20, 16)
    fab.Font = Enum.Font.GothamBold; fab.TextSize = 18; fab.BorderSizePixel = 0
    fab.Active = true; fab.Draggable = true; fab.Visible = false; fab.Parent = gui
    corner(fab, 26)
    local fabStroke = Instance.new("UIStroke")
    fabStroke.Color = Color3.fromRGB(20, 20, 16); fabStroke.Thickness = 2; fabStroke.Parent = fab

    local frame = Instance.new("Frame")
    frame.Name = "BFHubMain"
    frame.Size = UDim2.fromOffset(420, 300)
    frame.Position = UDim2.new(0.5, 0, 0.5, 40); frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(16, 16, 21); frame.BorderSizePixel = 0
    frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true
    frame.Parent = gui
    corner(frame, 14)

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 36); top.BackgroundColor3 = Color3.fromRGB(30, 31, 27)
    top.BorderSizePixel = 0; top.Parent = frame
    corner(top, 14)

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -90, 1, 0); tl.Position = UDim2.new(0, 12, 0, 0)
    tl.BackgroundTransparency = 1; tl.Text = title .. "  |  BFHub"
    tl.TextColor3 = Color3.fromRGB(230, 230, 220); tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.Font = Enum.Font.GothamMedium; tl.TextSize = 14; tl.Parent = top

    local min = Instance.new("TextButton")
    min.Size = UDim2.fromOffset(28, 28); min.Position = UDim2.new(1, -34, 0, 4)
    min.BackgroundColor3 = Color3.fromRGB(55, 56, 48); min.Text = "-"; min.TextColor3 = Color3.fromRGB(235, 235, 225)
    min.Font = Enum.Font.GothamBold; min.TextSize = 18; min.BorderSizePixel = 0; min.Parent = top
    corner(min, 8)

    local tabbar = Instance.new("Frame")
    tabbar.Name = "Tabs"
    tabbar.Size = UDim2.new(0, 112, 1, -36); tabbar.Position = UDim2.new(0, 0, 0, 36)
    tabbar.BackgroundColor3 = Color3.fromRGB(22, 22, 27); tabbar.BorderSizePixel = 0; tabbar.Parent = frame
    local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 2); list.Parent = tabbar
    pad(tabbar, 4)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, -112, 1, -36); body.Position = UDim2.new(0, 112, 0, 36)
    body.BackgroundTransparency = 1; body.Parent = frame

    local pages = {}
    local win = {}
    local firstTab = true

    function win:show() frame.Visible = true; fab.Visible = false end
    function win:hide() frame.Visible = false; fab.Visible = true end

    function win:tab(name)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30); btn.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
        btn.Text = name; btn.TextColor3 = Color3.fromRGB(200, 200, 195)
        btn.Font = Enum.Font.GothamMedium; btn.TextSize = 13; btn.BorderSizePixel = 0
        btn.Parent = tabbar; corner(btn, 8)

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -8, 1, -8); page.Position = UDim2.new(0, 4, 0, 4)
        page.BackgroundTransparency = 1; page.BorderSizePixel = 0; page.Visible = false
        page.ScrollBarThickness = 4; page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y; page.Parent = body
        local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 6); ll.Parent = page
        pad(page, 4)
        pages[name] = page

        local tab = {}
        local function select()
            for n, p in pairs(pages) do p.Visible = (n == name) end
            for _, b in ipairs(tabbar:GetChildren()) do
                if b:IsA("TextButton") then b.TextColor3 = Color3.fromRGB(200, 200, 195) end
            end
            btn.TextColor3 = ACCENT
        end
        btn.MouseButton1Click:Connect(select)
        if firstTab then firstTab = false; task.defer(select) end

        function tab:section(sname)
            local box = Instance.new("Frame")
            box.Size = UDim2.new(1, -8, 0, 28); box.BackgroundColor3 = Color3.fromRGB(26, 27, 23)
            box.BorderSizePixel = 0; box.Parent = page; corner(box, 8)
            box.AutomaticSize = Enum.AutomaticSize.Y

            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, -12, 0, 24); t.Position = UDim2.new(0, 8, 0, 2)
            t.BackgroundTransparency = 1; t.Text = sname; t.TextXAlignment = Enum.TextXAlignment.Left
            t.TextColor3 = ACCENT; t.Font = Enum.Font.GothamBold; t.TextSize = 12; t.Parent = box

            local rows = Instance.new("Frame")
            rows.Size = UDim2.new(1, -8, 0, 0); rows.Position = UDim2.new(0, 4, 0, 26)
            rows.BackgroundTransparency = 1; rows.AutomaticSize = Enum.AutomaticSize.Y; rows.Parent = box
            local rl = Instance.new("UIListLayout"); rl.Padding = UDim.new(0, 4); rl.Parent = rows
            local rp = Instance.new("UIPadding"); rp.PaddingBottom = UDim.new(0, 6); rp.Parent = rows

            local sec = {}
            function sec:toggle(label, default, cb)
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 28); row.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
                row.Text = ""; row.BorderSizePixel = 0; row.AutoButtonColor = false; row.Parent = rows; corner(row, 6)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, -56, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
                l.BackgroundTransparency = 1; l.Text = label; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextColor3 = Color3.fromRGB(215, 215, 210); l.Font = Enum.Font.Gotham; l.TextSize = 12; l.Parent = row
                local state = default and true or false
                local ind = Instance.new("Frame")
                ind.Size = UDim2.fromOffset(36, 18); ind.Position = UDim2.new(1, -44, 0.5, -9)
                ind.BackgroundColor3 = state and ACCENT or Color3.fromRGB(70, 70, 78)
                ind.BorderSizePixel = 0; ind.Parent = row; corner(ind, 9)
                local knob = Instance.new("Frame")
                knob.Size = UDim2.fromOffset(14, 14)
                knob.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                knob.BackgroundColor3 = Color3.fromRGB(240, 240, 240); knob.BorderSizePixel = 0; knob.Parent = ind
                corner(knob, 7)
                row.MouseButton1Click:Connect(function()
                    state = not state
                    ind.BackgroundColor3 = state and ACCENT or Color3.fromRGB(70, 70, 78)
                    knob.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                    if cb then task.spawn(cb, state) end
                end)
                return function() return state end
            end
            function sec:button(label, cb)
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 28); row.BackgroundColor3 = Color3.fromRGB(42, 43, 38)
                row.Text = label; row.TextColor3 = Color3.fromRGB(230, 230, 220)
                row.Font = Enum.Font.GothamMedium; row.TextSize = 12; row.BorderSizePixel = 0
                row.Parent = rows; corner(row, 6)
                row.MouseButton1Click:Connect(function() if cb then task.spawn(cb) end end)
                return row
            end
            function sec:label(text)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 20); l.BackgroundTransparency = 1
                l.Text = text; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextColor3 = Color3.fromRGB(185, 185, 180); l.Font = Enum.Font.Gotham; l.TextSize = 12; l.Parent = rows
                return l
            end
            function sec:paragraph(text)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 20); l.BackgroundTransparency = 1
                l.Text = text or ""; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextYAlignment = Enum.TextYAlignment.Top; l.TextWrapped = true
                l.AutomaticSize = Enum.AutomaticSize.Y
                l.TextColor3 = Color3.fromRGB(190, 190, 185); l.Font = Enum.Font.Gotham; l.TextSize = 12
                l.Parent = rows
                return l
            end
            function sec:dropdown(label, options, default, cb)
                local idx = 1
                for i, o in ipairs(options) do if o == default then idx = i end end
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 28); row.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
                row.Text = ""; row.BorderSizePixel = 0; row.AutoButtonColor = false; row.Parent = rows; corner(row, 6)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(0.5, 0, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
                l.BackgroundTransparency = 1; l.Text = label; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextColor3 = Color3.fromRGB(215, 215, 210); l.Font = Enum.Font.Gotham; l.TextSize = 12; l.Parent = row
                local v = Instance.new("TextLabel")
                v.Size = UDim2.new(0.45, 0, 1, 0); v.Position = UDim2.new(0.55, 0, 0, 0)
                v.BackgroundTransparency = 1; v.Text = options[idx]; v.TextXAlignment = Enum.TextXAlignment.Right
                v.TextColor3 = ACCENT; v.Font = Enum.Font.GothamMedium; v.TextSize = 12; v.Parent = row
                row.MouseButton1Click:Connect(function()
                    idx = idx % #options + 1; v.Text = options[idx]
                    if cb then task.spawn(cb, options[idx]) end
                end)
                return function() return options[idx] end
            end
            return sec
        end
        return tab
    end

    min.MouseButton1Click:Connect(function() win:hide() end)
    fab.MouseButton1Click:Connect(function()
        if frame.Visible then win:hide() else win:show() end
    end)

    return win
end

return UI
