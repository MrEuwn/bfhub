--[[ ui.lua - raw Instance.new GUI. No UI library on purpose: a library adds
     hundreds of KB and lags mobile executors. ~400 lines, instant load. ]]

local UI = {}
UI.__index = UI

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local ACCENT = Color3.fromRGB(122, 140, 255)
local CYAN = Color3.fromRGB(120, 220, 220)
local BG = Color3.fromRGB(22, 23, 28)
local CARD = Color3.fromRGB(32, 34, 41)
local TRACK = Color3.fromRGB(52, 55, 66)
local TXT = Color3.fromRGB(232, 234, 242)
local DIM = Color3.fromRGB(150, 155, 170)

local function mk(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    i.Parent = parent
    return i
end

local function round(i, r)
    mk("UICorner", { CornerRadius = UDim.new(0, r or 8) }, i)
    return i
end

local function stroke(i, c, t)
    mk("UIStroke", { Color = c or TRACK, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, i)
    return i
end

-- one scheduler-free tween helper
local function to(inst, t, props)
    TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

function UI.new(U, C)
    local self = setmetatable({ U = U, C = C, tabs = {}, pages = {}, rows = {} }, UI)

    -- double-load guard
    local pg = U.LP:FindFirstChild("PlayerGui")
    local old = pg and pg:FindFirstChild("BFHub")
    if old then old:Destroy() end

    local gui = mk("ScreenGui", {
        Name = "BFHub", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true,
    }, pg or game:GetService("CoreGui"))
    self.gui = gui

    local main = mk("Frame", {
        Name = "Main", Size = UDim2.fromOffset(470, 340), Position = UDim2.new(0.5, -235, 0.5, -170),
        BackgroundColor3 = BG, BorderSizePixel = 0, Active = true, Draggable = true,
    }, gui)
    round(main, 12) stroke(main, TRACK)
    self.main = main

    -- header ---------------------------------------------------------------
    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = CARD, BorderSizePixel = 0 }, main)
    round(header, 12)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = CARD, BorderSizePixel = 0 }, header)

    mk("TextLabel", {
        Text = "Raf's Personal Script", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = TXT,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -120, 0, 18),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    mk("TextLabel", {
        Text = "BFHub - keyless", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = CYAN,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 21), Size = UDim2.new(1, -120, 0, 14),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)

    local min = mk("TextButton", {
        Text = "-", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -64, 0, 6),
    }, header)
    min.MouseButton1Click:Connect(function() self:hide() end)

    local kill = mk("TextButton", {
        Text = "X", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -32, 0, 6),
    }, header)
    kill.MouseButton1Click:Connect(function() self:destroy() end)

    -- feature search -------------------------------------------------------
    local search = mk("TextBox", {
        PlaceholderText = "search...", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT,
        PlaceholderColor3 = DIM, BackgroundColor3 = BG, BorderSizePixel = 0, ClearTextOnFocus = false,
        Size = UDim2.fromOffset(96, 22), Position = UDim2.new(1, -170, 0, 9),
    }, header)
    round(search, 6) stroke(search)
    search:GetPropertyChangedSignal("Text"):Connect(function() self:filter(search.Text) end)

    -- tab rail: a ScrollingFrame, NOT a Frame - a Frame silently clips tab 10+
    local rail = mk("ScrollingFrame", {
        Size = UDim2.new(0, 124, 1, -50), Position = UDim2.fromOffset(10, 46), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = TRACK,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, rail)
    self.rail = rail

    local body = mk("ScrollingFrame", {
        Size = UDim2.new(1, -144, 1, -50), Position = UDim2.new(0, 134, 0, 46), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = ACCENT, ClipsDescendants = true,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)
    self.body = body

    -- floating restore button ---------------------------------------------
    local fab = mk("TextButton", {
        Name = "FAB", Text = "B", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = TXT,
        BackgroundColor3 = ACCENT, Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 16, 0.5, -26),
        Visible = false, AutoButtonColor = true,
    }, gui)
    round(fab, 26)
    fab.Draggable = true
    fab.MouseButton1Click:Connect(function() self:show() end)
    self.fab = fab

    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightControl then self:toggle() end
    end)
    return self
end

-- window state -------------------------------------------------------------
function UI:show() self.main.Visible = true self.fab.Visible = false end
function UI:hide() self.main.Visible = false self.fab.Visible = true end
function UI:toggle() self.main.Visible = not self.main.Visible self.fab.Visible = not self.main.Visible end
function UI:destroy()
    if self._onDestroy then pcall(self._onDestroy) end
    self.gui:Destroy()
end

-- tabs ---------------------------------------------------------------------
function UI:tab(name)
    if self.pages[name] then return self.pages[name] end
    local btn = mk("TextButton", {
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = DIM,
        BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 32),
        AutoButtonColor = false,
    }, self.rail)
    round(btn, 8)
    local bar = mk("Frame", {
        Size = UDim2.new(0, 3, 0.6, 0), Position = UDim2.new(0, 0, 0.2, 0),
        BackgroundColor3 = ACCENT, BorderSizePixel = 0, Visible = false,
    }, btn)
    round(bar, 2)

    local page = mk("Frame", {
        Size = UDim2.new(1, -6, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, AutomaticSize = Enum.AutomaticSize.Y,
    }, self.body)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)

    local entry = { btn = btn, bar = bar, page = page }
    self.pages[name] = entry
    btn.MouseButton1Click:Connect(function() self:select(name) end)
    if not self.current then self:select(name) end
    return page
end

function UI:select(name)
    self.current = name
    for n, e in pairs(self.pages) do
        local on = n == name
        e.page.Visible = on
        e.bar.Visible = on
        e.btn.TextColor3 = on and TXT or DIM
        e.btn.BackgroundColor3 = on and TRACK or CARD
    end
    self.body.CanvasPosition = Vector2.zero
end

-- widgets ------------------------------------------------------------------
function UI:card(page, title)
    local card = mk("Frame", {
        Size = UDim2.new(1, -6, 0, 0), BackgroundColor3 = CARD, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
    round(card, 10) stroke(card)
    mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, card)
    mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, card)
    if title then
        mk("TextLabel", {
            Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = CYAN,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
    end
    return card
end

local function row(parent, title, caption)
    local f = mk("Frame", { Size = UDim2.new(1, 0, 0, caption and 34 or 22), BackgroundTransparency = 1 }, parent)
    mk("TextLabel", {
        Text = title, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = TXT,
        BackgroundTransparency = 1, Size = UDim2.new(1, -70, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    if caption then
        mk("TextLabel", {
            Text = caption, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = DIM,
            BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, -70, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
    end
    return f
end

function UI:row(parent, title, caption)
    local f = row(parent, title, caption)
    table.insert(self.rows, { frame = f, title = string.lower(title) })
    return f
end

function UI:toggle(parent, title, caption, key)
    local f = self:row(parent, title, caption)
    local track = mk("Frame", {
        Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -42, 0, 1),
        BackgroundColor3 = self.C.get(key) and ACCENT or TRACK, BorderSizePixel = 0,
    }, f)
    round(track, 10)
    local knob = mk("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = self.C.get(key) and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, track)
    round(knob, 8)
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function()
        local on = self.C.toggle(key)
        to(track, 0.15, { BackgroundColor3 = on and ACCENT or TRACK })
        to(knob, 0.15, { Position = on and UDim2.fromOffset(22, 2) or UDim2.fromOffset(2, 2) })
    end)
    return f
end

function UI:slider(parent, title, key, min, max, step)
    step = step or 1
    local f = self:row(parent, title .. ": " .. tostring(self.C.get(key)))
    local bar = mk("Frame", {
        Size = UDim2.new(1, -10, 0, 8), Position = UDim2.new(0, 0, 0, 14),
        BackgroundColor3 = TRACK, BorderSizePixel = 0,
    }, f)
    round(bar, 4)
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, bar)
    round(fill, 4)
    local label = f:FindFirstChildOfClass("TextLabel")
    local function apply(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + (max - min) * a) / step + 0.5) * step
        self.C.set(key, v)
        fill.Size = UDim2.new(a, 0, 1, 0)
        label.Text = title .. ": " .. tostring(v)
    end
    local dragging = false
    local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, bar)
    hit.MouseButton1Down:Connect(function() dragging = true apply(UIS:GetMouseLocation().X) end)
    hit.MouseButton1Up:Connect(function() dragging = false end)
    hit.TouchLongPress:Connect(function() dragging = true end)
    UIS.InputChanged:Connect(function(i)
        local t = i.UserInputType
        if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
            apply(i.Position.X)
        end
    end)
    -- initial fill
    local v0 = self.C.get(key)
    fill.Size = UDim2.new((v0 - min) / (max - min), 0, 1, 0)
    return f
end

function UI:button(parent, title, caption, fn)
    local f = self:row(parent, title, caption)
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function() self.U.safe(title, fn) end)
    local go = mk("TextLabel", {
        Text = ">", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = ACCENT,
        BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -22, 0, 1),
    }, f)
    return f, go
end

function UI:label(parent, text, color)
    return mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = color or DIM,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

-- dropdown: an inline popup list. A cycle button would be cheaper but a 15-item
-- boss list is unusable that way on a phone.
function UI:dropdown(parent, title, key, values)
    local f = self:row(parent, title .. ": " .. tostring(self.C.get(key)))
    local label = f:FindFirstChildOfClass("TextLabel")
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    local open = false
    local list
    btn.MouseButton1Click:Connect(function()
        if open and list then list:Destroy() list = nil open = false return end
        open = true
        list = mk("ScrollingFrame", {
            Size = UDim2.new(1, -20, 0, math.min(#values * 22 + 8, 180)), BackgroundColor3 = BG,
            BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        }, parent)
        round(list, 8) stroke(list)
        mk("UIListLayout", { Padding = UDim.new(0, 2) }, list)
        for _, v in ipairs(values) do
            local b = mk("TextButton", {
                Text = tostring(v), Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT,
                BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 20),
                TextXAlignment = Enum.TextXAlignment.Left,
            }, list)
            round(b, 4)
            b.MouseButton1Click:Connect(function()
                self.C.set(key, v)
                label.Text = title .. ": " .. tostring(v)
                if list then list:Destroy() list = nil end
                open = false
            end)
        end
    end)
    return f
end

function UI:textbox(parent, title, key, placeholder)
    local f = self:row(parent, title)
    local box = mk("TextBox", {
        Text = tostring(self.C.get(key) or ""), PlaceholderText = placeholder or "",
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT, PlaceholderColor3 = DIM,
        BackgroundColor3 = BG, BorderSizePixel = 0, ClearTextOnFocus = false,
        Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0, 0, 0, 14),
    }, f)
    round(box, 5) stroke(box)
    box:GetPropertyChangedSignal("Text"):Connect(function() self.C.set(key, box.Text) end)
    return f
end

function UI:filter(q)
    q = string.lower(q or "")
    for _, r in ipairs(self.rows) do
        r.frame.Visible = q == "" or string.find(r.title, q, 1, true) ~= nil
    end
end

-- live debug panel ---------------------------------------------------------
function UI:debug(page, U, C)
    local card = self:card(page, "Debug")
    local l1 = self:label(card, "")
    local l2 = self:label(card, "")
    local t0 = os.clock()
    task.spawn(function()
        while self.gui.Parent do
            local fps = math.floor(1 / math.max(game:GetService("RunService").Heartbeat:Wait(), 1e-3))
            l1.Text = string.format("FPS %d   PING %d ms", fps, math.floor(U.LP:GetNetworkPing() * 1000))
            l2.Text = string.format("LV %d   UPTIME %d s   MOBS %d", U.level(), math.floor(os.clock() - t0), #U.mobs())
            task.wait(0.5)
        end
    end)
    return card
end

return UI
