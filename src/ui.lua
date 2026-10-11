--[[ ui.lua - raw Instance.new GUI, no library.

     Two things make this load fast:
       1. tabs are built LAZILY - only Home exists at load, the other pages are
          constructed the first time they are opened. 150 rows become ~12.
       2. one flat frame per row, no nested cards/strokes, so the UI tree stays small.

     Minimalist: single accent colour, no gradients, no icons, compact rows. ]]

local UI = {}
UI.__index = UI

local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local ACCENT = Color3.fromRGB(124, 142, 255)
local BG     = Color3.fromRGB(19, 20, 24)
local CARD   = Color3.fromRGB(28, 30, 36)
local TRACK  = Color3.fromRGB(46, 49, 58)
local TXT    = Color3.fromRGB(232, 234, 242)
local DIM    = Color3.fromRGB(138, 143, 158)

local function mk(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    i.Parent = parent
    return i
end

local function corner(i, r)
    mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, i)
    return i
end

local function to(inst, t, props)
    TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quad), props):Play()
end

function UI.new(U, C)
    local self = setmetatable({ U = U, C = C, pages = {}, order = {}, built = {} }, UI)

    local pg = U.LP:FindFirstChild("PlayerGui")
    local old = pg and pg:FindFirstChild("RPS")
    if old then old:Destroy() end

    local gui = mk("ScreenGui", {
        Name = "RPS", ResetOnSpawn = false, DisplayOrder = 999, IgnoreGuiInset = true,
    }, pg or game:GetService("CoreGui"))
    self.gui = gui

    local main = mk("Frame", {
        Size = UDim2.fromOffset(430, 300), Position = UDim2.new(0.5, -215, 0.5, -150),
        BackgroundColor3 = BG, BorderSizePixel = 0, Active = true, Draggable = true,
    }, gui)
    corner(main, 10)
    self.main = main

    -- header: title + one close button. no subtitle, no search box.
    local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = CARD, BorderSizePixel = 0 }, main)
    corner(header, 10)
    mk("Frame", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = CARD, BorderSizePixel = 0 }, header)
    mk("Frame", { Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(12, 9), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, header)
    mk("TextLabel", {
        Text = "Raf's Personal Script", Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = TXT,
        BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 6), Size = UDim2.new(1, -80, 0, 20),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    local min = mk("TextButton", {
        Text = "-", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -56, 0, 3),
    }, header)
    min.MouseButton1Click:Connect(function() self:hide() end)
    local kill = mk("TextButton", {
        Text = "x", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = DIM, BackgroundTransparency = 1,
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -28, 0, 3),
    }, header)
    kill.MouseButton1Click:Connect(function() self:destroy() end)

    -- tab rail: 100px, plain buttons, no icons
    local rail = mk("ScrollingFrame", {
        Size = UDim2.new(0, 100, 1, -42), Position = UDim2.fromOffset(8, 40), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = TRACK,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 3) }, rail)
    self.rail = rail

    local body = mk("ScrollingFrame", {
        Size = UDim2.new(1, -116, 1, -42), Position = UDim2.new(0, 108, 0, 40), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 5, ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarImageColor3 = ACCENT, ClipsDescendants = true,
    }, main)
    mk("UIListLayout", { Padding = UDim.new(0, 6) }, body)
    self.body = body

    -- floating restore button
    local fab = mk("TextButton", {
        Name = "FAB", Text = "R", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = TXT,
        BackgroundColor3 = ACCENT, Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.5, -23),
        Visible = false,
    }, gui)
    corner(fab, 23)
    fab.Draggable = true
    fab.MouseButton1Click:Connect(function() self:show() end)
    self.fab = fab

    UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightControl then self:toggle() end
    end)
    return self
end

function UI:show() self.main.Visible = true self.fab.Visible = false end
function UI:hide() self.main.Visible = false self.fab.Visible = true end
function UI:toggle() self.main.Visible = not self.main.Visible self.fab.Visible = not self.main.Visible end
function UI:destroy()
    if self._onDestroy then pcall(self._onDestroy) end
    self.gui:Destroy()
end

-- tabs ---------------------------------------------------------------------
-- builder runs on FIRST open only: that is what keeps the load instant.
function UI:tab(name, builder)
    if self.pages[name] then return self.pages[name] end

    local btn = mk("TextButton", {
        Text = name, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = DIM,
        BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 26),
        AutoButtonColor = false,
    }, self.rail)
    corner(btn, 6)
    local bar = mk("Frame", {
        Size = UDim2.new(0, 2, 0.5, 0), Position = UDim2.new(0, 0, 0.25, 0),
        BackgroundColor3 = ACCENT, BorderSizePixel = 0, Visible = false,
    }, btn)
    corner(bar, 1)

    local page = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false, AutomaticSize = Enum.AutomaticSize.Y,
    }, self.body)
    mk("UIListLayout", { Padding = UDim.new(0, 6) }, page)

    local entry = { btn = btn, bar = bar, page = page, builder = builder }
    self.pages[name] = entry
    table.insert(self.order, name)
    btn.MouseButton1Click:Connect(function() self:select(name) end)
    if not self.current then self:select(name) end
    return page
end

function UI:select(name)
    local e = self.pages[name]
    if not e then return end
    -- lazy build, once
    if e.builder and not self.built[name] then
        self.built[name] = true
        local ok, err = pcall(e.builder, e.page)
        if not ok then self.U.log("x", "tab " .. name .. ": " .. tostring(err)) end
    end
    self.current = name
    for n, p in pairs(self.pages) do
        local on = n == name
        p.page.Visible = on
        p.bar.Visible = on
        p.btn.TextColor3 = on and TXT or DIM
        p.btn.BackgroundColor3 = on and TRACK or CARD
    end
    self.body.CanvasPosition = Vector2.zero
end

-- widgets ------------------------------------------------------------------
function UI:card(page, title)
    local card = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 0), BackgroundColor3 = CARD, BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
    }, page)
    corner(card, 8)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, card)
    mk("UIListLayout", { Padding = UDim.new(0, 4) }, card)
    if title then
        mk("TextLabel", {
            Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = ACCENT,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
    end
    return card
end

local function rowFrame(parent, h)
    return mk("Frame", { Size = UDim2.new(1, 0, 0, h or 18), BackgroundTransparency = 1 }, parent)
end

local function rowText(f, title)
    return mk("TextLabel", {
        Text = title, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT,
        BackgroundTransparency = 1, Size = UDim2.new(1, -54, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
end

function UI:toggle(parent, title, key)
    local f = rowFrame(parent, 18)
    rowText(f, title)
    local track = mk("Frame", {
        Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -36, 0, 0),
        BackgroundColor3 = self.C.get(key) and ACCENT or TRACK, BorderSizePixel = 0,
    }, f)
    corner(track, 9)
    local knob = mk("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = self.C.get(key) and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, track)
    corner(knob, 7)
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function()
        local on = self.C.toggle(key)
        to(track, 0.12, { BackgroundColor3 = on and ACCENT or TRACK })
        to(knob, 0.12, { Position = on and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2) })
    end)
    return f
end

function UI:slider(parent, title, key, min, max, step)
    step = step or 1
    local f = rowFrame(parent, 26)
    local label = rowText(f, title)
    local bar = mk("Frame", {
        Size = UDim2.new(1, -4, 0, 4), Position = UDim2.new(0, 0, 0, 18),
        BackgroundColor3 = TRACK, BorderSizePixel = 0,
    }, f)
    corner(bar, 2)
    local fill = mk("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT, BorderSizePixel = 0 }, bar)
    corner(fill, 2)
    local function apply(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor((min + (max - min) * a) / step + 0.5) * step
        self.C.set(key, v)
        fill.Size = UDim2.new(a, 0, 1, 0)
        label.Text = title .. ": " .. tostring(v)
    end
    local v0 = self.C.get(key) or min
    label.Text = title .. ": " .. tostring(v0)
    fill.Size = UDim2.new((v0 - min) / math.max(max - min, 1), 0, 1, 0)
    local dragging = false
    local hit = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0) }, bar)
    hit.MouseButton1Down:Connect(function() dragging = true apply(UIS:GetMouseLocation().X) end)
    hit.MouseButton1Up:Connect(function() dragging = false end)
    UIS.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then apply(i.Position.X) end
    end)
    return f
end

function UI:dropdown(parent, title, key, values)
    local f = rowFrame(parent, 18)
    local label = rowText(f, title .. ": " .. tostring(self.C.get(key)))
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    local list
    btn.MouseButton1Click:Connect(function()
        if list then list:Destroy() list = nil return end
        list = mk("ScrollingFrame", {
            Size = UDim2.new(1, -14, 0, math.min(#values * 18 + 6, 150)), BackgroundColor3 = BG,
            BorderSizePixel = 0, ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
        }, parent)
        corner(list, 6)
        mk("UIListLayout", { Padding = UDim.new(0, 1) }, list)
        for _, v in ipairs(values) do
            local b = mk("TextButton", {
                Text = tostring(v), Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = TXT,
                BackgroundColor3 = CARD, BorderSizePixel = 0, Size = UDim2.new(1, -6, 0, 17),
                TextXAlignment = Enum.TextXAlignment.Left,
            }, list)
            corner(b, 3)
            b.MouseButton1Click:Connect(function()
                self.C.set(key, v)
                label.Text = title .. ": " .. tostring(v)
                if list then list:Destroy() list = nil end
            end)
        end
    end)
    return f
end

function UI:textbox(parent, title, key, placeholder)
    local f = rowFrame(parent, 34)
    rowText(f, title)
    local box = mk("TextBox", {
        Text = tostring(self.C.get(key) or ""), PlaceholderText = placeholder or "",
        Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = TXT, PlaceholderColor3 = DIM,
        BackgroundColor3 = BG, BorderSizePixel = 0, ClearTextOnFocus = false,
        Size = UDim2.new(1, -4, 0, 18), Position = UDim2.new(0, 0, 0, 15),
    }, f)
    corner(box, 4)
    box:GetPropertyChangedSignal("Text"):Connect(function() self.C.set(key, box.Text) end)
    return f
end

function UI:button(parent, title, fn)
    local f = rowFrame(parent, 18)
    local label = rowText(f, title)
    label.TextColor3 = ACCENT
    local btn = mk("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, f)
    btn.MouseButton1Click:Connect(function() self.U.safe(title, fn) end)
    return f
end

function UI:label(parent, text, color)
    return mk("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = color or DIM,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

-- live debug panel (3 numbers, no labels on separate rows)
function UI:debug(page, U, C)
    local card = self:card(page, "Debug")
    local l1 = self:label(card, "")
    local l2 = self:label(card, "")
    local t0 = os.clock()
    task.spawn(function()
        while self.gui.Parent do
            local fps = math.floor(1 / math.max(game:GetService("RunService").Heartbeat:Wait(), 1e-3))
            l1.Text = string.format("FPS %d   PING %d ms   MOBS %d", fps, math.floor(U.LP:GetNetworkPing() * 1000), #U.mobs())
            l2.Text = string.format("LV %d   SEA %s   UPTIME %ds", U.level(), tostring(U.sea), math.floor(os.clock() - t0))
            task.wait(0.5)
        end
    end)
    return card
end

return UI
