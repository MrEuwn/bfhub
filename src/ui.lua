-- Raf's Personal Script - UI.
-- Hand-built from Instance.new (no Rayfield/Fluent/Kavo) so it stays tiny and
-- instant on mobile executors. Calm dark palette, soft accent, rounded cards.
--
-- API (unchanged):
--   UI.new(title) -> win
--   win:tab(name) -> tab ; tab:section(name) -> sec
--   sec:toggle(label, default, cb) / :button / :label / :paragraph
--   sec:dropdown(label, options, default, cb) / :textbox(label, default, cb)
--   win:show() / win:hide()
-- A round floating button appears whenever the window is hidden.
local UI = {}

-- palette (easy on the eyes: deep charcoal + soft periwinkle accent)
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

local function corner(o, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = o; return c end
local function pad(o, n) local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, n); p.PaddingBottom = UDim.new(0, n)
    p.PaddingLeft = UDim.new(0, n); p.PaddingRight = UDim.new(0, n); p.Parent = o; return p end
local function stroke(o, col, th, tr) local s = Instance.new("UIStroke")
    s.Color = col; s.Thickness = th or 1; s.Transparency = tr or 0.6; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = o; return s end

function UI.new(title)
    local plr = game:GetService("Players").LocalPlayer
    local pgui = plr:WaitForChild("PlayerGui")
    local old = pgui:FindFirstChild("RPS")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "RPS"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true; gui.DisplayOrder = 999
    gui.Parent = pgui

    -- floating open/close button
    local fab = Instance.new("TextButton")
    fab.Name = "RPSFab"; fab.Size = UDim2.fromOffset(54, 54)
    fab.Position = UDim2.new(0, 14, 0.5, -27); fab.BackgroundColor3 = ACCENT
    fab.Text = "R"; fab.TextColor3 = Color3.fromRGB(16, 17, 22)
    fab.Font = Enum.Font.GothamBold; fab.TextSize = 22; fab.BorderSizePixel = 0
    fab.AutoButtonColor = true; fab.Active = true; fab.Draggable = true; fab.Visible = false; fab.Parent = gui
    corner(fab, 27)
    stroke(fab, Color3.fromRGB(255, 255, 255), 1, 0.75)

    local frame = Instance.new("Frame")
    frame.Name = "RPSMain"
    frame.Size = UDim2.fromOffset(500, 380)
    frame.Position = UDim2.new(0.5, 0, 0.5, 20); frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = BG; frame.BorderSizePixel = 0
    frame.Active = true; frame.Draggable = true; frame.ClipsDescendants = true
    frame.Parent = gui
    corner(frame, 18)
    stroke(frame, ACCENT, 1, 0.55)

    -- header
    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 46); top.BackgroundColor3 = HEADER
    top.BorderSizePixel = 0; top.Parent = frame
    corner(top, 18)

    local bar = Instance.new("Frame")   -- accent strip under header
    bar.Size = UDim2.new(1, 0, 0, 2); bar.Position = UDim2.new(0, 0, 0, 46)
    bar.BackgroundColor3 = ACCENT; bar.BorderSizePixel = 0; bar.Parent = frame

    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, -70, 1, -6); tl.Position = UDim2.new(0, 16, 0, 4)
    tl.BackgroundTransparency = 1; tl.Text = title
    tl.TextColor3 = TXT; tl.TextXAlignment = Enum.TextXAlignment.Left
    tl.TextYAlignment = Enum.TextYAlignment.Top; tl.Font = Enum.Font.GothamBold; tl.TextSize = 15; tl.Parent = top

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -70, 1, -8); sub.Position = UDim2.new(0, 16, 0, 10)
    sub.BackgroundTransparency = 1; sub.Text = "Blox Fruits  •  mobile"
    sub.TextColor3 = MUTED; sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextYAlignment = Enum.TextYAlignment.Bottom; sub.Font = Enum.Font.Gotham; sub.TextSize = 11; sub.Parent = top

    local min = Instance.new("TextButton")
    min.Size = UDim2.fromOffset(30, 30); min.Position = UDim2.new(1, -40, 0, 8)
    min.BackgroundColor3 = ROW; min.Text = "-"; min.TextColor3 = TXT
    min.Font = Enum.Font.GothamBold; min.TextSize = 18; min.BorderSizePixel = 0; min.Parent = top
    corner(min, 9); stroke(min, ACCENT, 1, 0.7)

    -- sidebar (scrollable tab rail)
    local tabbar = Instance.new("ScrollingFrame")
    tabbar.Name = "Tabs"
    tabbar.Size = UDim2.new(0, 132, 1, -48); tabbar.Position = UDim2.new(0, 0, 0, 48)
    tabbar.BackgroundColor3 = SIDEBAR; tabbar.BorderSizePixel = 0; tabbar.Parent = frame
    tabbar.ScrollBarThickness = 3; tabbar.ScrollBarImageColor3 = ACCENT
    tabbar.ScrollingDirection = Enum.ScrollingDirection.Y
    tabbar.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabbar.CanvasSize = UDim2.new(0, 0, 0, 0); tabbar.Active = true
    local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 3); list.Parent = tabbar
    pad(tabbar, 6)

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, -132, 1, -48); body.Position = UDim2.new(0, 132, 0, 48)
    body.BackgroundTransparency = 1; body.ClipsDescendants = true; body.Parent = frame

    local pages = {}
    local win = {}
    local firstTab = true
    local tabButtons = {}

    function win:show() frame.Visible = true; fab.Visible = false end
    function win:hide() frame.Visible = false; fab.Visible = true end

    function win:tab(name)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 32); btn.BackgroundColor3 = ROW
        btn.Text = ""; btn.BorderSizePixel = 0; btn.AutoButtonColor = true
        btn.Parent = tabbar; corner(btn, 9)
        local mark = Instance.new("Frame")   -- active accent bar
        mark.Size = UDim2.new(0, 3, 0.6, 0); mark.Position = UDim2.new(0, 0, 0.2, 0)
        mark.BackgroundColor3 = ACCENT; mark.BorderSizePixel = 0; mark.Visible = false
        mark.Parent = btn
        corner(mark, 2)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -14, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
        l.BackgroundTransparency = 1; l.Text = name; l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = MUTED; l.Font = Enum.Font.GothamMedium; l.TextSize = 13; l.Parent = btn

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -8, 1, -8); page.Position = UDim2.new(0, 4, 0, 4)
        page.BackgroundTransparency = 1; page.BorderSizePixel = 0; page.Visible = false
        page.ScrollBarThickness = 6; page.ScrollBarImageColor3 = ACCENT
        page.ScrollingDirection = Enum.ScrollingDirection.Y
        page.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new(0, 0, 0, 0); page.Active = true; page.ScrollingEnabled = true
        page.Parent = body
        local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 8); ll.Parent = page
        pad(page, 6)
        pages[name] = page
        table.insert(tabButtons, { btn = btn, l = l, mark = mark, name = name })

        local tab = {}
        local function select()
            for n, p in pairs(pages) do p.Visible = (n == name) end
            for _, tb in ipairs(tabButtons) do
                local on = (tb.name == name)
                tb.l.TextColor3 = on and TXT or MUTED
                tb.mark.Visible = on
                tb.btn.BackgroundColor3 = on and ROW_HI or ROW
            end
        end
        btn.MouseButton1Click:Connect(select)
        if firstTab then firstTab = false; task.defer(select) end

        function tab:section(sname)
            local box = Instance.new("Frame")
            box.Size = UDim2.new(1, -8, 0, 30); box.BackgroundColor3 = CARD
            box.BorderSizePixel = 0; box.Parent = page; corner(box, 10)
            stroke(box, ACCENT, 1, 0.85)
            box.AutomaticSize = Enum.AutomaticSize.Y

            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, -16, 0, 26); t.Position = UDim2.new(0, 12, 0, 3)
            t.BackgroundTransparency = 1; t.Text = string.upper(sname)
            t.TextXAlignment = Enum.TextXAlignment.Left
            t.TextColor3 = ACCENT2; t.Font = Enum.Font.GothamBold; t.TextSize = 11; t.Parent = box

            local rows = Instance.new("Frame")
            rows.Size = UDim2.new(1, -12, 0, 0); rows.Position = UDim2.new(0, 6, 0, 28)
            rows.BackgroundTransparency = 1; rows.AutomaticSize = Enum.AutomaticSize.Y; rows.Parent = box
            local rl = Instance.new("UIListLayout"); rl.Padding = UDim.new(0, 5); rl.Parent = rows
            local rp = Instance.new("UIPadding"); rp.PaddingBottom = UDim.new(0, 8); rp.Parent = rows

            local sec = {}
            function sec:toggle(label, default, cb)
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundColor3 = ROW
                row.Text = ""; row.BorderSizePixel = 0; row.AutoButtonColor = false; row.Parent = rows; corner(row, 8)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, -58, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
                l.BackgroundTransparency = 1; l.Text = label; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextColor3 = TXT; l.Font = Enum.Font.Gotham; l.TextSize = 12; l.Parent = row
                local state = default and true or false
                local pill = Instance.new("Frame")
                pill.Size = UDim2.fromOffset(38, 20); pill.Position = UDim2.new(1, -48, 0.5, -10)
                pill.BackgroundColor3 = state and ACCENT or Color3.fromRGB(60, 62, 74)
                pill.BorderSizePixel = 0; pill.Parent = row; corner(pill, 10)
                local knob = Instance.new("Frame")
                knob.Size = UDim2.fromOffset(16, 16)
                knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                knob.BackgroundColor3 = Color3.fromRGB(245, 246, 252); knob.BorderSizePixel = 0; knob.Parent = pill
                corner(knob, 8)
                row.MouseButton1Click:Connect(function()
                    state = not state
                    pill.BackgroundColor3 = state and ACCENT or Color3.fromRGB(60, 62, 74)
                    knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
                    if cb then task.spawn(cb, state) end
                end)
                return function() return state end
            end
            function sec:button(label, cb)
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundColor3 = ROW_HI
                row.Text = label; row.TextColor3 = TXT
                row.Font = Enum.Font.GothamMedium; row.TextSize = 12; row.BorderSizePixel = 0
                row.AutoButtonColor = true; row.Parent = rows; corner(row, 8)
                row.MouseButton1Click:Connect(function() if cb then task.spawn(cb) end end)
                return row
            end
            function sec:label(text)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1
                l.Text = text; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextColor3 = MUTED; l.Font = Enum.Font.Gotham; l.TextSize = 11; l.Parent = rows
                return l
            end
            function sec:paragraph(text)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 18); l.BackgroundTransparency = 1
                l.Text = text or ""; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextYAlignment = Enum.TextYAlignment.Top; l.TextWrapped = true
                l.AutomaticSize = Enum.AutomaticSize.Y
                l.TextColor3 = Color3.fromRGB(196, 199, 214); l.Font = Enum.Font.Gotham; l.TextSize = 12
                l.Parent = rows
                return l
            end
            function sec:dropdown(label, options, default, cb)
                local idx = 1
                for i, o in ipairs(options) do if o == default then idx = i end end
                local row = Instance.new("TextButton")
                row.Size = UDim2.new(1, 0, 0, 30); row.BackgroundColor3 = ROW
                row.Text = ""; row.BorderSizePixel = 0; row.AutoButtonColor = false; row.Parent = rows; corner(row, 8)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(0.5, 0, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
                l.BackgroundTransparency = 1; l.Text = label; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextColor3 = TXT; l.Font = Enum.Font.Gotham; l.TextSize = 12; l.Parent = row
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
            function sec:textbox(label, default, cb)
                local l = Instance.new("TextLabel")
                l.Size = UDim2.new(1, 0, 0, 15); l.BackgroundTransparency = 1
                l.Text = label; l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextColor3 = MUTED; l.Font = Enum.Font.Gotham; l.TextSize = 11; l.Parent = rows
                local box = Instance.new("TextBox")
                box.Size = UDim2.new(1, 0, 0, 28); box.BackgroundColor3 = ROW
                box.Text = default or ""; box.PlaceholderText = "..."
                box.TextColor3 = TXT; box.Font = Enum.Font.Gotham; box.TextSize = 11
                box.BorderSizePixel = 0; box.ClearTextOnFocus = false; box.Parent = rows; corner(box, 8)
                box.FocusLost:Connect(function() if cb then task.spawn(cb, box.Text) end end)
                return function() return box.Text end
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
