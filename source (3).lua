--[[
    ╔══════════════════════════════════════════════╗
    ║  Nebula UI Library  ·  v1.0.0                ║
    ║  Dark glass · animated glow border · mobile  ║
    ╚══════════════════════════════════════════════╝

    Features
      • Draggable window, minimize, close, toggle key + floating orb (mobile)
      • Sidebar tabs with search, locked tabs, 2-column pages
      • Collapsible sections
      • Toggle, Slider, Dropdown (single/multi/search), Input, Button,
        Keybind, Label, Paragraph, Divider
      • Notifications (Success / Error / Warning / Info) with progress bar
      • Built-in Settings panel (themes + UI scale)
      • Config save / load (writefile) + ready-made Config tab
      • Splash / loading screen

    Usage: see example.lua
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local Nebula = {
    Version      = "1.0.0",
    Flags        = {},
    Options      = {},
    Windows      = {},
    CurrentTheme = "Nebula",
    ConfigFolder = "NebulaUI",
    _themed  = {},
    _refresh = {},
    _conns   = {},
}

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
Nebula.Themes = {
    Nebula = {
        Accent = Color3.fromRGB(139, 92, 246), Accent2 = Color3.fromRGB(86, 58, 196),
        Glow1  = Color3.fromRGB(80, 220, 255), Glow2   = Color3.fromRGB(190, 90, 255),
        Bg     = Color3.fromRGB(13, 12, 19),   Side    = Color3.fromRGB(17, 16, 26),
        Panel  = Color3.fromRGB(21, 20, 32),   Element = Color3.fromRGB(29, 27, 43),
        Stroke = Color3.fromRGB(54, 48, 82),   Text    = Color3.fromRGB(240, 238, 250),
        SubText= Color3.fromRGB(150, 145, 178),
    },
    Crimson = {
        Accent = Color3.fromRGB(244, 63, 94),  Accent2 = Color3.fromRGB(159, 28, 60),
        Glow1  = Color3.fromRGB(251, 146, 60), Glow2   = Color3.fromRGB(244, 63, 94),
        Bg     = Color3.fromRGB(16, 11, 13),   Side    = Color3.fromRGB(22, 14, 17),
        Panel  = Color3.fromRGB(28, 18, 22),   Element = Color3.fromRGB(38, 24, 29),
        Stroke = Color3.fromRGB(78, 44, 52),   Text    = Color3.fromRGB(250, 238, 240),
        SubText= Color3.fromRGB(176, 143, 150),
    },
    Aqua = {
        Accent = Color3.fromRGB(34, 211, 238), Accent2 = Color3.fromRGB(14, 116, 144),
        Glow1  = Color3.fromRGB(52, 211, 153), Glow2   = Color3.fromRGB(56, 189, 248),
        Bg     = Color3.fromRGB(10, 15, 19),   Side    = Color3.fromRGB(13, 20, 26),
        Panel  = Color3.fromRGB(17, 26, 33),   Element = Color3.fromRGB(23, 35, 45),
        Stroke = Color3.fromRGB(38, 62, 78),   Text    = Color3.fromRGB(236, 247, 250),
        SubText= Color3.fromRGB(134, 164, 176),
    },
    Emerald = {
        Accent = Color3.fromRGB(52, 211, 105), Accent2 = Color3.fromRGB(21, 128, 61),
        Glow1  = Color3.fromRGB(163, 230, 53), Glow2   = Color3.fromRGB(45, 212, 191),
        Bg     = Color3.fromRGB(10, 16, 13),   Side    = Color3.fromRGB(13, 22, 17),
        Panel  = Color3.fromRGB(17, 29, 22),   Element = Color3.fromRGB(23, 40, 30),
        Stroke = Color3.fromRGB(38, 78, 55),   Text    = Color3.fromRGB(237, 250, 242),
        SubText= Color3.fromRGB(135, 176, 150),
    },
    Mono = {
        Accent = Color3.fromRGB(226, 226, 232), Accent2 = Color3.fromRGB(110, 110, 124),
        Glow1  = Color3.fromRGB(255, 255, 255), Glow2   = Color3.fromRGB(120, 120, 135),
        Bg     = Color3.fromRGB(12, 12, 14),    Side    = Color3.fromRGB(17, 17, 20),
        Panel  = Color3.fromRGB(22, 22, 26),    Element = Color3.fromRGB(30, 30, 35),
        Stroke = Color3.fromRGB(60, 60, 68),    Text    = Color3.fromRGB(245, 245, 248),
        SubText= Color3.fromRGB(148, 148, 158),
    },
}

local Status = {
    Success = { Color3.fromRGB(74, 222, 128),  "✓", "SUCCESS" },
    Error   = { Color3.fromRGB(248, 81, 92),   "✕", "ERROR" },
    Warning = { Color3.fromRGB(250, 204, 21),  "!", "WARNING" },
    Info    = { Color3.fromRGB(96, 165, 250),  "i", "INFO" },
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local WHITE = Color3.new(1, 1, 1)

local function create(class, props, kids)
    local o = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if parent then o.Parent = parent end
    return o
end

local function resolve(key)
    local th = Nebula.Themes[Nebula.CurrentTheme]
    if key == "AccentGrad" then
        return ColorSequence.new(th.Accent, th.Accent2)
    elseif key == "GlowGrad" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, th.Glow1),
            ColorSequenceKeypoint.new(0.5, th.Glow2),
            ColorSequenceKeypoint.new(1, th.Glow1),
        })
    end
    return th[key]
end

local function bind(inst, prop, key)
    inst[prop] = resolve(key)
    table.insert(Nebula._themed, { inst, prop, key })
    return inst
end

local function onTheme(fn)
    table.insert(Nebula._refresh, fn)
end

local function tween(o, t, p, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), p)
    tw:Play()
    return tw
end

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Nebula._conns, c)
    return c
end

local function corner(p, r)
    return create("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p })
end

local function stroke(p, key, thickness, transparency)
    local s = create("UIStroke", { Thickness = thickness or 1, Transparency = transparency or 0.4, Parent = p })
    bind(s, "Color", key or "Stroke")
    return s
end

local function text(parent, str, size, key, font)
    local l = create("TextLabel", {
        BackgroundTransparency = 1, Text = str, TextSize = size or 13,
        Font = font or Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent,
    })
    bind(l, "TextColor3", key or "Text")
    return l
end

local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function gradient(p, key, transparency)
    local g = create("UIGradient", { Parent = p })
    bind(g, "Color", key or "AccentGrad")
    if transparency then g.Transparency = transparency end
    return g
end

local function makeDraggable(handle, target, getScale, onMove)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging, dragStart, startPos = true, i.Position, target.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and isMove(i) then
            local d = i.Position - dragStart
            local s = getScale and getScale() or 1
            if onMove then onMove(d) end
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X / s,
                startPos.Y.Scale, startPos.Y.Offset + d.Y / s)
        end
    end)
end

----------------------------------------------------------------------
-- Theme switching
----------------------------------------------------------------------
function Nebula:SetTheme(name)
    if not self.Themes[name] then return end
    self.CurrentTheme = name
    for i = #self._themed, 1, -1 do
        local e = self._themed[i]
        if e[1] and e[1].Parent then
            e[1][e[2]] = resolve(e[3])
        else
            table.remove(self._themed, i)
        end
    end
    for _, fn in ipairs(self._refresh) do pcall(fn) end
end

----------------------------------------------------------------------
-- Root gui + notifications
----------------------------------------------------------------------
function Nebula:_ensureGui()
    if self._gui and self._gui.Parent then return self._gui end

    local g = create("ScreenGui", {
        Name = "NebulaUI_" .. HttpService:GenerateGUID(false):sub(1, 6),
        ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    if syn and syn.protect_gui then pcall(syn.protect_gui, g) end

    local ok = false
    if gethui then ok = pcall(function() g.Parent = gethui() end) end
    if not ok or not g.Parent then ok = pcall(function() g.Parent = CoreGui end) end
    if not ok or not g.Parent then g.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    self._gui = g
    self._notifHolder = create("Frame", {
        Name = "Notifications", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.new(0, 300, 1, -24), ZIndex = 100, Parent = g,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    return g
end

function Nebula:Notify(o)
    o = o or {}
    self:_ensureGui()
    local st = Status[o.Type or "Info"] or Status.Info
    local duration = o.Duration or 4
    self._notifCount = (self._notifCount or 0) + 1

    local wrap = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 68),
        LayoutOrder = self._notifCount, Parent = self._notifHolder,
    })
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(330, 0),
        BorderSizePixel = 0, ClipsDescendants = true, Parent = wrap,
    })
    bind(card, "BackgroundColor3", "Panel")
    corner(card, 10)
    local cs = create("UIStroke", { Thickness = 1, Transparency = 0.35, Color = st[1], Parent = card })

    local icon = create("Frame", {
        Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(10, 14),
        BackgroundColor3 = st[1], Parent = card,
    })
    corner(icon, 18)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = st[2],
        TextColor3 = Color3.new(1, 1, 1), TextSize = 18, Font = Enum.Font.GothamBold, Parent = icon,
    })

    local tag = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(56, 7), Size = UDim2.new(1, -110, 0, 12),
        Text = "●  " .. st[3], TextColor3 = st[1], TextSize = 9, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    local title = text(card, o.Title or "Notification", 13, "Text", Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(56, 21); title.Size = UDim2.new(1, -66, 0, 16)
    local body = text(card, o.Content or "", 11, "SubText", Enum.Font.Gotham)
    body.Position = UDim2.fromOffset(56, 38); body.Size = UDim2.new(1, -66, 0, 14)

    local clock = text(card, os.date("%H:%M"), 10, "SubText", Enum.Font.Gotham)
    clock.Position = UDim2.new(1, -62, 0, 7); clock.Size = UDim2.fromOffset(34, 12)
    clock.TextXAlignment = Enum.TextXAlignment.Right

    local close = create("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -24, 0, 4), Size = UDim2.fromOffset(20, 18),
        Text = "X", TextSize = 11, Font = Enum.Font.GothamBold, Parent = card,
    })
    bind(close, "TextColor3", "SubText")

    local bar = create("Frame", {
        Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = st[1], BorderSizePixel = 0, BackgroundTransparency = 0.15, Parent = card,
    })

    local dead = false
    local function dismiss()
        if dead then return end
        dead = true
        tween(card, 0.3, { Position = UDim2.fromOffset(330, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.32, function() wrap:Destroy() end)
    end
    close.MouseButton1Click:Connect(dismiss)

    tween(card, 0.4, { Position = UDim2.fromOffset(0, 0) })
    tween(bar, duration, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
    task.delay(duration, dismiss)
end

----------------------------------------------------------------------
-- Splash / loading screen (yields until finished)
----------------------------------------------------------------------
function Nebula:Splash(o)
    o = o or {}
    local g = self:_ensureGui()
    local steps = o.Steps or { "loading modules", "finalizing" }
    local total = o.Duration or 3

    local root = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 12),
        BorderSizePixel = 0, ZIndex = 200, Parent = g,
    })
    local ring = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, 0, .5, -60),
        Size = UDim2.fromOffset(110, 110), BackgroundTransparency = 1, ZIndex = 201, Parent = root,
    })
    corner(ring, 55)
    local rs = create("UIStroke", { Thickness = 3, Color = WHITE, Parent = ring })
    local rg = gradient(rs, "GlowGrad")

    local letter = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 202,
        Text = (o.Title or "N"):sub(1, 1):upper(), TextSize = 44, Font = Enum.Font.GothamBlack, Parent = ring,
    })
    bind(letter, "TextColor3", "Accent")

    local title = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 8),
        Size = UDim2.fromOffset(300, 34), Text = o.Title or "NEBULA", TextSize = 28,
        Font = Enum.Font.GothamBlack, ZIndex = 201, Parent = root,
    })
    bind(title, "TextColor3", "Text")
    local sub = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 40),
        Size = UDim2.fromOffset(300, 16), Text = o.Subtitle or "", TextSize = 12,
        Font = Enum.Font.Gotham, ZIndex = 201, Parent = root,
    })
    bind(sub, "TextColor3", "SubText")
    local stepL = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 66),
        Size = UDim2.fromOffset(300, 16), Text = "", TextSize = 11, Font = Enum.Font.Code, ZIndex = 201, Parent = root,
    })
    bind(stepL, "TextColor3", "Accent")

    local track = create("Frame", {
        AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 94), Size = UDim2.fromOffset(260, 6),
        BorderSizePixel = 0, ZIndex = 201, Parent = root,
    })
    bind(track, "BackgroundColor3", "Element")
    corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 202, Parent = track })
    corner(fill, 3)
    gradient(fill, "AccentGrad")
    local pct = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 106),
        Size = UDim2.fromOffset(260, 16), Text = "0%", TextSize = 11, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 201, Parent = root,
    })
    bind(pct, "TextColor3", "SubText")

    local spin = RunService.Heartbeat:Connect(function() rg.Rotation = (os.clock() * 180) % 360 end)

    for i, s in ipairs(steps) do
        stepL.Text = "$ " .. s
        local a = i / #steps
        tween(fill, total / #steps, { Size = UDim2.fromScale(a, 1) }, Enum.EasingStyle.Sine)
        task.wait(total / #steps)
        pct.Text = math.floor(a * 100) .. "%"
    end
    task.wait(0.25)
    spin:Disconnect()
    tween(root, 0.4, { BackgroundTransparency = 1 })
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") then tween(d, 0.4, { TextTransparency = 1 })
        elseif d:IsA("Frame") then tween(d, 0.4, { BackgroundTransparency = 1 })
        elseif d:IsA("UIStroke") then tween(d, 0.4, { Transparency = 1 }) end
    end
    task.wait(0.45)
    root:Destroy()
end

----------------------------------------------------------------------
-- Config
----------------------------------------------------------------------
function Nebula:ListConfigs()
    local out = {}
    if listfiles and isfolder and isfolder(self.ConfigFolder) then
        for _, f in ipairs(listfiles(self.ConfigFolder)) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n then table.insert(out, n) end
        end
    end
    return out
end

function Nebula:SaveConfig(name)
    if not (writefile and makefolder) or not name or name == "" then return false end
    local data = {}
    for flag, v in pairs(self.Flags) do
        local opt = self.Options[flag]
        if typeof(v) == "EnumItem" then data[flag] = { __enum = v.Name }
        elseif type(v) ~= "userdata" and not (opt and opt.NoSave) then data[flag] = v end
    end
    pcall(function() if not isfolder(self.ConfigFolder) then makefolder(self.ConfigFolder) end end)
    local ok = pcall(writefile, self.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return ok
end

function Nebula:LoadConfig(name)
    if not (readfile and isfile) or not name then return false end
    local path = self.ConfigFolder .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok then return false end
    for flag, v in pairs(data) do
        local opt = self.Options[flag]
        if opt then
            if type(v) == "table" and v.__enum then v = Enum.KeyCode[v.__enum] end
            pcall(function() opt:Set(v) end)
        end
    end
    return true
end

function Nebula:Unload()
    self._unloaded = true
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self._conns, self._themed, self._refresh = {}, {}, {}
    if self._gui then self._gui:Destroy() end
    self._gui = nil
end

----------------------------------------------------------------------
-- Element base
----------------------------------------------------------------------
local Section = {}
Section.__index = Section

local function newRow(section, height)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, Parent = section.Body,
    })
    bind(row, "BackgroundColor3", "Element")
    corner(row, 8)
    stroke(row, "Stroke", 1, 0.5)
    return row
end

local function register(obj, o)
    obj._flag = o.Flag
    obj.NoSave = o.NoSave
    if o.Flag then
        Nebula.Flags[o.Flag] = obj.Value
        Nebula.Options[o.Flag] = obj
    end
end

local function changed(obj, o, silent)
    if obj._flag then Nebula.Flags[obj._flag] = obj.Value end
    if not silent and o.Callback then task.spawn(o.Callback, obj.Value) end
end

local function hoverable(btn, target, base, over)
    btn.MouseEnter:Connect(function() tween(target, 0.15, { BackgroundTransparency = over }) end)
    btn.MouseLeave:Connect(function() tween(target, 0.15, { BackgroundTransparency = base }) end)
end

---------------------------------------------------------------- Label
function Section:AddLabel(str)
    local obj = { Type = "Label" }
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = self.Body })
    local l = text(row, str or "", 12, "SubText", Enum.Font.Gotham)
    l.Size = UDim2.new(1, -8, 0, 0); l.Position = UDim2.fromOffset(4, 0)
    l.AutomaticSize = Enum.AutomaticSize.Y; l.TextWrapped = true; l.TextTruncate = Enum.TextTruncate.None
    function obj:Set(s) l.Text = s end
    function obj:SetVisible(b) row.Visible = b end
    return obj
end

---------------------------------------------------------------- Paragraph
function Section:AddParagraph(o)
    local obj = { Type = "Paragraph" }
    local row = newRow(self, 0)
    row.AutomaticSize = Enum.AutomaticSize.Y
    create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = row })
    create("UIListLayout", { Padding = UDim.new(0, 3), Parent = row })
    local t = text(row, o.Title or "", 13, "Text", Enum.Font.GothamBold)
    t.Size = UDim2.new(1, 0, 0, 16)
    local c = text(row, o.Content or "", 11, "SubText", Enum.Font.Gotham)
    c.Size = UDim2.new(1, 0, 0, 0); c.AutomaticSize = Enum.AutomaticSize.Y
    c.TextWrapped = true; c.TextTruncate = Enum.TextTruncate.None
    function obj:Set(title, content) t.Text = title or t.Text; c.Text = content or c.Text end
    function obj:SetVisible(b) row.Visible = b end
    return obj
end

---------------------------------------------------------------- Divider
function Section:AddDivider()
    local d = create("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.5, Parent = self.Body })
    bind(d, "BackgroundColor3", "Stroke")
end

---------------------------------------------------------------- Button
function Section:AddButton(o)
    local obj = { Type = "Button" }
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = WHITE, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", Parent = self.Body,
    })
    corner(btn, 8)
    gradient(btn, "AccentGrad")
    local l = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = o.Name or "Button",
        TextColor3 = WHITE, TextSize = 13, Font = Enum.Font.GothamBold, Parent = btn,
    })
    local shade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn })
    corner(shade, 8)
    btn.MouseEnter:Connect(function() tween(shade, 0.15, { BackgroundTransparency = 0.85 }) end)
    btn.MouseLeave:Connect(function() tween(shade, 0.15, { BackgroundTransparency = 1 }) end)
    btn.MouseButton1Down:Connect(function() tween(shade, 0.08, { BackgroundTransparency = 0.7 }) end)
    btn.MouseButton1Click:Connect(function()
        tween(shade, 0.15, { BackgroundTransparency = 0.85 })
        if o.Callback then task.spawn(o.Callback) end
    end)
    function obj:SetText(s) l.Text = s end
    function obj:SetVisible(b) btn.Visible = b end
    return obj
end

---------------------------------------------------------------- Toggle
function Section:AddToggle(o)
    local obj = { Type = "Toggle", Value = o.Default == true }
    local row = newRow(self, 34)
    local l = text(row, o.Name or "Toggle", 13)
    l.Position = UDim2.fromOffset(10, 0); l.Size = UDim2.new(1, -48, 1, 0)

    local box = create("Frame", {
        AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -9, .5, 0),
        Size = UDim2.fromOffset(20, 20), BorderSizePixel = 0, Parent = row,
    })
    corner(box, 6)
    local bs = stroke(box, "Stroke", 1, 0.2)
    local check = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "✓", TextSize = 14,
        Font = Enum.Font.GothamBold, TextColor3 = WHITE, Parent = box,
    })
    local click = create("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = row })

    local function render()
        local on = obj.Value
        tween(box, 0.18, { BackgroundColor3 = on and resolve("Accent") or resolve("Panel") })
        tween(check, 0.18, { TextTransparency = on and 0 or 1 })
        tween(bs, 0.18, { Transparency = on and 1 or 0.2 })
    end
    onTheme(render)

    function obj:Set(v, silent)
        obj.Value = v and true or false
        render(); changed(obj, o, silent)
    end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) row.Visible = b end
    click.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)

    register(obj, o); render()
    return obj
end

---------------------------------------------------------------- Slider
function Section:AddSlider(o)
    local min, max, inc = o.Min or 0, o.Max or 100, o.Increment or 1
    local obj = { Type = "Slider", Value = math.clamp(o.Default or min, min, max) }
    local decimals = #((tostring(inc):match("%.(%d+)")) or "")

    local row = newRow(self, 46)
    local l = text(row, o.Name or "Slider", 13)
    l.Position = UDim2.fromOffset(10, 6); l.Size = UDim2.new(1, -90, 0, 16)
    local v = text(row, "", 12, "SubText", Enum.Font.GothamBold)
    v.AnchorPoint = Vector2.new(1, 0); v.Position = UDim2.new(1, -10, 0, 6)
    v.Size = UDim2.fromOffset(80, 16); v.TextXAlignment = Enum.TextXAlignment.Right

    local track = create("Frame", { Position = UDim2.new(0, 10, 0, 31), Size = UDim2.new(1, -20, 0, 6), BorderSizePixel = 0, Parent = row })
    bind(track, "BackgroundColor3", "Panel")
    corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track })
    corner(fill, 3)
    gradient(fill, "AccentGrad")
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track,
    })
    corner(knob, 6)
    local hit = create("TextButton", { BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 24), Parent = row })

    local function fmt(x)
        if decimals > 0 then return string.format("%." .. decimals .. "f", x) end
        return tostring(math.floor(x + 0.5))
    end
    local function render(animate)
        local a = (obj.Value - min) / math.max(max - min, 1e-9)
        local t = animate and 0.1 or 0
        tween(fill, t, { Size = UDim2.fromScale(a, 1) }, Enum.EasingStyle.Sine)
        tween(knob, t, { Position = UDim2.fromScale(a, .5) }, Enum.EasingStyle.Sine)
        v.Text = fmt(obj.Value) .. (o.Suffix or "")
    end

    function obj:Set(x, silent)
        x = tonumber(x); if not x then return end
        x = math.clamp(math.floor((x - min) / inc + 0.5) * inc + min, min, max)
        if decimals > 0 then x = tonumber(string.format("%." .. decimals .. "f", x)) end
        obj.Value = x
        render(true); changed(obj, o, silent)
    end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) row.Visible = b end

    local dragging = false
    local function fromInput(pos)
        local a = math.clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        obj:Set(min + (max - min) * a)
    end
    hit.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging = true
            self.Tab.Page.ScrollingEnabled = false
            fromInput(i.Position)
        end
    end)
    connect(UserInputService.InputChanged, function(i) if dragging and isMove(i) then fromInput(i.Position) end end)
    connect(UserInputService.InputEnded, function(i)
        if dragging and isPress(i) then dragging = false; self.Tab.Page.ScrollingEnabled = true end
    end)

    register(obj, o); render(false)
    return obj
end

---------------------------------------------------------------- Input
function Section:AddInput(o)
    local obj = { Type = "Input", Value = o.Default or "" }
    local row = newRow(self, 56)
    local l = text(row, o.Name or "Input", 13)
    l.Position = UDim2.fromOffset(10, 5); l.Size = UDim2.new(1, -20, 0, 16)

    local box = create("TextBox", {
        Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -20, 0, 24), BorderSizePixel = 0,
        Text = obj.Value, PlaceholderText = o.Placeholder or "Type here...", TextSize = 12,
        Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    bind(box, "BackgroundColor3", "Panel"); bind(box, "TextColor3", "Text"); bind(box, "PlaceholderColor3", "SubText")
    corner(box, 6)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box })
    local bs = stroke(box, "Stroke", 1, 0.5)
    box.Focused:Connect(function() bs.Color = resolve("Accent"); bs.Transparency = 0 end)
    box.FocusLost:Connect(function()
        bs.Color = resolve("Stroke"); bs.Transparency = 0.5
        if o.Numeric then
            local n = tonumber(box.Text)
            if not n then box.Text = tostring(obj.Value); return end
            box.Text = tostring(n)
        end
        obj.Value = o.Numeric and tonumber(box.Text) or box.Text
        changed(obj, o, false)
    end)

    function obj:Set(s, silent)
        obj.Value = s; box.Text = tostring(s); changed(obj, o, silent)
    end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) row.Visible = b end
    register(obj, o)
    return obj
end

---------------------------------------------------------------- Keybind
function Section:AddKeybind(o)
    local obj = { Type = "Keybind", Value = o.Default or Enum.KeyCode.Unknown, Listening = false }
    local row = newRow(self, 34)
    local l = text(row, o.Name or "Keybind", 13)
    l.Position = UDim2.fromOffset(10, 0); l.Size = UDim2.new(1, -90, 1, 0)

    local btn = create("TextButton", {
        AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0), Size = UDim2.fromOffset(70, 22),
        BorderSizePixel = 0, AutoButtonColor = false, TextSize = 11, Font = Enum.Font.GothamBold, Parent = row,
    })
    bind(btn, "BackgroundColor3", "Panel"); bind(btn, "TextColor3", "Accent")
    corner(btn, 6)

    local function render()
        btn.Text = obj.Listening and "..." or (obj.Value == Enum.KeyCode.Unknown and "None" or obj.Value.Name)
    end
    onTheme(render)

    function obj:Set(k, silent)
        if type(k) == "string" then
            local ok, e = pcall(function() return Enum.KeyCode[k] end)
            k = ok and e or Enum.KeyCode.Unknown
        end
        obj.Value = k or Enum.KeyCode.Unknown
        if obj._flag then Nebula.Flags[obj._flag] = obj.Value end
        render()
        if not silent and o.ChangedCallback then task.spawn(o.ChangedCallback, obj.Value) end
    end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) row.Visible = b end

    btn.MouseButton1Click:Connect(function() obj.Listening = true; render() end)
    connect(UserInputService.InputBegan, function(i, gp)
        if obj.Listening then
            if i.UserInputType == Enum.UserInputType.Keyboard then
                obj.Listening = false
                obj:Set(i.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or i.KeyCode)
            end
            return
        end
        if not gp and obj.Value ~= Enum.KeyCode.Unknown and i.KeyCode == obj.Value then
            if o.Callback then task.spawn(o.Callback, true) end
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if o.Hold and obj.Value ~= Enum.KeyCode.Unknown and i.KeyCode == obj.Value and o.Callback then
            task.spawn(o.Callback, false)
        end
    end)

    register(obj, o); render()
    return obj
end

---------------------------------------------------------------- Dropdown
function Section:AddDropdown(o)
    local obj = { Type = "Dropdown", Multi = o.Multi == true, Options = o.Options or {}, Open = false }
    if obj.Multi then
        obj.Value = {}
        if type(o.Default) == "table" then for _, k in ipairs(o.Default) do obj.Value[k] = true end end
    else
        obj.Value = o.Default
    end

    local root = newRow(self, 34)
    root.AutomaticSize = Enum.AutomaticSize.Y
    root.ClipsDescendants = true
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = root })

    local head = create("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", LayoutOrder = 1, Parent = root })
    local l = text(head, o.Name or "Dropdown", 13)
    l.Position = UDim2.fromOffset(10, 0); l.Size = UDim2.new(0.45, -10, 1, 0)
    local cur = text(head, "", 12, "Accent", Enum.Font.GothamBold)
    cur.Position = UDim2.new(0.45, 0, 0, 0); cur.Size = UDim2.new(0.55, -30, 1, 0)
    cur.TextXAlignment = Enum.TextXAlignment.Right
    local arrow = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0),
        Size = UDim2.fromOffset(16, 16), Text = "▾", TextSize = 14, Font = Enum.Font.GothamBold, Parent = head,
    })
    bind(arrow, "TextColor3", "SubText")

    local wrap = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, LayoutOrder = 2, Parent = root })
    create("UIListLayout", { Padding = UDim.new(0, 4), Parent = wrap })
    create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = wrap })

    local search
    if #obj.Options > 7 then
        search = create("TextBox", {
            Size = UDim2.new(1, 0, 0, 24), BorderSizePixel = 0, Text = "", PlaceholderText = "Search...",
            TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1, Parent = wrap,
        })
        bind(search, "BackgroundColor3", "Panel"); bind(search, "TextColor3", "Text"); bind(search, "PlaceholderColor3", "SubText")
        corner(search, 6)
        create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = search })
    end

    local scroll = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = 2,
        ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = wrap,
    })
    bind(scroll, "ScrollBarImageColor3", "Accent")
    create("UIListLayout", { Padding = UDim.new(0, 2), Parent = scroll })

    local items = {}
    local function display()
        if obj.Multi then
            local t = {}
            for _, k in ipairs(obj.Options) do if obj.Value[k] then t[#t + 1] = tostring(k) end end
            return #t > 0 and table.concat(t, ", ") or "None"
        end
        return obj.Value ~= nil and tostring(obj.Value) or "None"
    end
    local function paint()
        cur.Text = display()
        for k, it in pairs(items) do
            local sel = obj.Multi and obj.Value[k] or (not obj.Multi and obj.Value == k)
            tween(it[1], 0.15, { BackgroundTransparency = sel and 0.7 or 1 })
            it[2].TextColor3 = sel and resolve("Text") or resolve("SubText")
        end
    end
    onTheme(paint)

    local function choose(k)
        if obj.Multi then obj.Value[k] = (not obj.Value[k]) or nil
        else obj.Value = k end
        paint(); changed(obj, o, false)
        if not obj.Multi then obj:Toggle(false) end
    end

    local function build()
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        items = {}
        for n, k in ipairs(obj.Options) do
            local b = create("TextButton", { Size = UDim2.new(1, 0, 0, 26), AutoButtonColor = false, Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = n, Parent = scroll })
            bind(b, "BackgroundColor3", "Accent")
            corner(b, 6)
            local t = text(b, tostring(k), 12, "SubText")
            t.Position = UDim2.fromOffset(8, 0); t.Size = UDim2.new(1, -16, 1, 0)
            b.MouseButton1Click:Connect(function() choose(k) end)
            items[k] = { b, t }
        end
        scroll.Size = UDim2.new(1, 0, 0, math.clamp(#obj.Options * 28, 28, 140))
        paint()
    end

    if search then
        search:GetPropertyChangedSignal("Text"):Connect(function()
            local q = search.Text:lower()
            for k, it in pairs(items) do it[1].Visible = q == "" or tostring(k):lower():find(q, 1, true) ~= nil end
        end)
    end

    function obj:Toggle(state)
        if state == nil then state = not obj.Open end
        obj.Open = state
        wrap.Visible = state
        tween(arrow, 0.2, { Rotation = state and 180 or 0 })
    end
    function obj:Set(v, silent)
        if obj.Multi then
            obj.Value = {}
            if type(v) == "table" then
                for k, val in pairs(v) do
                    if type(k) == "number" then obj.Value[val] = true elseif val then obj.Value[k] = true end
                end
            end
        else obj.Value = v end
        paint(); changed(obj, o, silent)
    end
    function obj:Get() return obj.Value end
    function obj:SetOptions(list) obj.Options = list or {}; build() end
    function obj:SetVisible(b) root.Visible = b end

    head.MouseButton1Click:Connect(function() obj:Toggle() end)
    register(obj, o); build()
    return obj
end

----------------------------------------------------------------------
-- Tab
----------------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

function Tab:AddSection(o)
    if type(o) == "string" then o = { Name = o } end
    o = o or {}
    self._sectionCount = (self._sectionCount or 0) + 1
    local col = self.Left
    if o.Side == "Right" or (o.Side == nil and self._sectionCount % 2 == 0) then col = self.Right end

    local sec = setmetatable({ Tab = self }, Section)
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
        LayoutOrder = self._sectionCount, Parent = col,
    })
    bind(frame, "BackgroundColor3", "Panel")
    corner(frame, 10)
    stroke(frame, "Stroke", 1, 0.5)
    create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = frame })
    create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

    local head = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = WHITE, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", LayoutOrder = 1, Parent = frame,
    })
    corner(head, 8)
    gradient(head, "AccentGrad", NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.85) }))
    local pip = create("Frame", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(3, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = head })
    corner(pip, 2)
    local t = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -40, 1, 0),
        Text = o.Name or "Section", TextColor3 = WHITE, TextSize = 13, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
    })
    local arrow = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0),
        Size = UDim2.fromOffset(16, 16), Text = "▾", TextColor3 = WHITE, TextSize = 14, Font = Enum.Font.GothamBold, Parent = head,
    })

    local body = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = frame })
    create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
    sec.Body = body

    local open = o.Collapsed ~= true
    local function apply() body.Visible = open; tween(arrow, 0.2, { Rotation = open and 0 or -90 }) end
    head.MouseButton1Click:Connect(function() open = not open; apply() end)
    apply()

    function sec:SetName(s) t.Text = s end
    return sec
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function Nebula:CreateWindow(cfg)
    cfg = cfg or {}
    local gui = self:_ensureGui()
    local Window = { Tabs = {}, Visible = true, Minimized = false, ActiveTab = nil }
    table.insert(self.Windows, Window)

    local fs = cfg.Size or UDim2.fromOffset(600, 380)
    local TOP, SIDE = 42, 150

    local Main = create("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(.5, .5), Position = cfg.Position or UDim2.fromScale(.5, .5),
        Size = fs, BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
    })
    bind(Main, "BackgroundColor3", "Bg")
    corner(Main, 12)

    -- auto-fit to small screens
    local base = 1
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        base = math.clamp(math.min(vp.X / (fs.X.Offset + 40), vp.Y / (fs.Y.Offset + 40)), 0.5, 1)
    end
    local scale = create("UIScale", { Scale = base, Parent = Main })
    Window._scale = base

    -- animated glow border
    local glow = create("UIStroke", { Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = WHITE, Parent = Main })
    local glowG = gradient(glow, "GlowGrad")
    connect(RunService.Heartbeat, function()
        if Main.Visible then glowG.Rotation = (os.clock() * 45) % 360 end
    end)

    ------------------------------------------------ topbar
    local top = create("Frame", { Size = UDim2.new(1, 0, 0, TOP), BorderSizePixel = 0, Parent = Main })
    bind(top, "BackgroundColor3", "Side")

    local avatar = create("ImageLabel", {
        Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150", Parent = top,
    })
    bind(avatar, "BackgroundColor3", "Element")
    corner(avatar, 14)
    local title = text(top, cfg.Title or "Nebula", 14, "Text", Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(46, 5); title.Size = UDim2.fromOffset(SIDE - 46, 16)
    local subtitle = text(top, "●  " .. (cfg.Subtitle or LocalPlayer.Name), 10, "SubText", Enum.Font.Gotham)
    subtitle.Position = UDim2.fromOffset(46, 21); subtitle.Size = UDim2.fromOffset(SIDE - 46, 14)

    local function topButton(xFromRight)
        local b = create("TextButton", {
            AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -xFromRight, .5, 0),
            Size = UDim2.fromOffset(26, 26), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = top,
        })
        bind(b, "BackgroundColor3", "Element")
        corner(b, 7)
        return b
    end
    local function bar(parent, x, y, w, h)
        local f = create("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, x, .5, y), Size = UDim2.fromOffset(w, h), BorderSizePixel = 0, Parent = parent })
        bind(f, "BackgroundColor3", "SubText")
        corner(f, 1)
        return f
    end

    local closeBtn = topButton(10)
    local cx = create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "X", TextSize = 12, Font = Enum.Font.GothamBold, Parent = closeBtn })
    bind(cx, "TextColor3", "SubText")
    local minBtn = topButton(42)
    bar(minBtn, 0, 0, 10, 2)
    local setBtn = topButton(74)
    bar(setBtn, 0, -4, 12, 2); bar(setBtn, 0, 0, 12, 2); bar(setBtn, 0, 4, 12, 2)

    closeBtn.MouseEnter:Connect(function() tween(closeBtn, .15, { BackgroundColor3 = Status.Error[1] }); cx.TextColor3 = WHITE end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, .15, { BackgroundColor3 = resolve("Element") }); cx.TextColor3 = resolve("SubText") end)

    makeDraggable(top, Main, function() return scale.Scale end)

    ------------------------------------------------ body
    local Body = create("Frame", { Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -TOP), BackgroundTransparency = 1, Parent = Main })

    local side = create("Frame", { Size = UDim2.new(0, SIDE, 1, 0), BorderSizePixel = 0, Parent = Body })
    bind(side, "BackgroundColor3", "Side")

    local search = create("TextBox", {
        Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 26), BorderSizePixel = 0, Text = "",
        PlaceholderText = "Search tabs...", TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = side,
    })
    bind(search, "BackgroundColor3", "Element"); bind(search, "TextColor3", "Text"); bind(search, "PlaceholderColor3", "SubText")
    corner(search, 8)
    create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = search })

    local tabList = create("ScrollingFrame", {
        Position = UDim2.fromOffset(6, 42), Size = UDim2.new(1, -12, 1, -48), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = side,
    })
    create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })

    local content = create("Frame", { Position = UDim2.fromOffset(SIDE, 0), Size = UDim2.new(1, -SIDE, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Body })

    search:GetPropertyChangedSignal("Text"):Connect(function()
        local q = search.Text:lower()
        for _, t in ipairs(Window.Tabs) do
            t.Button.Visible = q == "" or t.Name:lower():find(q, 1, true) ~= nil
        end
    end)

    ------------------------------------------------ settings panel
    local panel = create("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, TOP + 6), Size = UDim2.fromOffset(210, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, ZIndex = 30, Parent = Main,
    })
    bind(panel, "BackgroundColor3", "Side")
    corner(panel, 10)
    stroke(panel, "Accent", 1, 0.3)
    create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = panel })
    create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })

    local ph = text(panel, "Settings", 14, "Text", Enum.Font.GothamBold)
    ph.Size = UDim2.new(1, 0, 0, 18); ph.LayoutOrder = 1
    local pt = text(panel, "THEME", 10, "SubText", Enum.Font.GothamBold)
    pt.Size = UDim2.new(1, 0, 0, 12); pt.LayoutOrder = 2

    local order = 3
    local themeNames = {}
    for n in pairs(self.Themes) do themeNames[#themeNames + 1] = n end
    table.sort(themeNames)
    local themeBtns = {}
    for _, n in ipairs(themeNames) do
        local b = create("TextButton", { Size = UDim2.new(1, 0, 0, 26), BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = order, ZIndex = 31, Parent = panel })
        order = order + 1
        bind(b, "BackgroundColor3", "Element")
        corner(b, 7)
        local dot = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = self.Themes[n].Accent, BorderSizePixel = 0, ZIndex = 32, Parent = b })
        corner(dot, 5)
        local tl = text(b, n, 12, "Text"); tl.Position = UDim2.fromOffset(26, 0); tl.Size = UDim2.new(1, -30, 1, 0); tl.ZIndex = 32
        local st = stroke(b, "Accent", 1, 1)
        themeBtns[n] = st
        b.MouseButton1Click:Connect(function() Nebula:SetTheme(n) end)
    end
    onTheme(function() for n, st in pairs(themeBtns) do st.Transparency = (n == Nebula.CurrentTheme) and 0.1 or 1 end end)
    themeBtns[self.CurrentTheme].Transparency = 0.1

    local sl = text(panel, "UI SCALE", 10, "SubText", Enum.Font.GothamBold)
    sl.Size = UDim2.new(1, 0, 0, 12); sl.LayoutOrder = order; order = order + 1
    local scaleRow = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 31, Parent = panel })
    local pctL = create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -64, 1, 0), Text = "", TextSize = 12, Font = Enum.Font.GothamBold, ZIndex = 32, Parent = scaleRow })
    bind(pctL, "TextColor3", "Text")
    local function scaleBtn(txt, anchorX, dx)
        local b = create("TextButton", { AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(anchorX, dx, 0, 0), Size = UDim2.fromOffset(26, 26), BorderSizePixel = 0, Text = txt, TextSize = 14, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 32, Parent = scaleRow })
        bind(b, "BackgroundColor3", "Element"); bind(b, "TextColor3", "Text")
        corner(b, 7)
        return b
    end
    local function setScale(s)
        Window._scale = math.clamp(math.floor(s * 10 + 0.5) / 10, 0.5, 1.5)
        scale.Scale = Window._scale
        pctL.Text = math.floor(Window._scale * 100 + 0.5) .. "%"
    end
    scaleBtn("-", 0, 0).MouseButton1Click:Connect(function() setScale(Window._scale - 0.1) end)
    scaleBtn("+", 1, 0).MouseButton1Click:Connect(function() setScale(Window._scale + 0.1) end)
    setScale(base)

    local credit = text(panel, "Nebula UI · v" .. self.Version, 10, "SubText", Enum.Font.Gotham)
    credit.Size = UDim2.new(1, 0, 0, 12); credit.LayoutOrder = order + 1; credit.TextXAlignment = Enum.TextXAlignment.Center

    setBtn.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)

    ------------------------------------------------ window methods
    function Window:Toggle(state)
        if state == nil then state = not Window.Visible end
        Window.Visible = state
        if state then
            Main.Visible = true
            scale.Scale = Window._scale * 0.94
            tween(scale, 0.25, { Scale = Window._scale })
        else
            tween(scale, 0.18, { Scale = Window._scale * 0.94 })
            task.delay(0.18, function()
                if not Window.Visible then Main.Visible = false; scale.Scale = Window._scale end
            end)
        end
    end

    function Window:Minimize()
        Window.Minimized = not Window.Minimized
        panel.Visible = false
        if Window.Minimized then
            Body.Visible = false
            tween(Main, 0.25, { Size = UDim2.new(fs.X.Scale, fs.X.Offset, 0, TOP) })
        else
            tween(Main, 0.25, { Size = fs })
            task.delay(0.1, function() Body.Visible = true end)
        end
    end

    function Window:Destroy()
        if Window._orb then Window._orb:Destroy() end
        Main:Destroy()
    end
    function Window:SetTitle(s, sub) title.Text = s or title.Text; if sub then subtitle.Text = "●  " .. sub end end
    function Window:Notify(o) Nebula:Notify(o) end

    minBtn.MouseButton1Click:Connect(function() Window:Minimize() end)
    closeBtn.MouseButton1Click:Connect(function() Window:Destroy() end)

    connect(UserInputService.InputBegan, function(i, gp)
        if not gp and i.KeyCode == (cfg.ToggleKey or Enum.KeyCode.RightShift) then Window:Toggle() end
    end)

    -- floating orb (mobile friendly)
    if cfg.ToggleButton ~= false then
        local orb = create("TextButton", {
            Name = "NebulaOrb", Position = UDim2.new(0, 14, .5, -22), Size = UDim2.fromOffset(44, 44),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false,
            Text = (cfg.Title or "N"):sub(1, 1):upper(), TextColor3 = WHITE, TextSize = 20,
            Font = Enum.Font.GothamBlack, ZIndex = 50, Parent = gui,
        })
        corner(orb, 22)
        gradient(orb, "AccentGrad")
        local os_ = create("UIStroke", { Thickness = 1.5, Color = WHITE, Parent = orb })
        local og = gradient(os_, "GlowGrad")
        connect(RunService.Heartbeat, function() og.Rotation = (os.clock() * 90) % 360 end)
        local moved = 0
        makeDraggable(orb, orb, nil, function(d) moved = math.max(moved, math.abs(d.X) + math.abs(d.Y)) end)
        orb.InputBegan:Connect(function(i) if isPress(i) then moved = 0 end end)
        orb.MouseButton1Click:Connect(function() if moved < 8 then Window:Toggle() end end)
        Window._orb = orb
    end

    ------------------------------------------------ tabs
    function Window:SelectTab(tab)
        for _, t in ipairs(Window.Tabs) do
            local on = t == tab
            t.Page.Visible = on
            tween(t.Button, 0.2, { BackgroundTransparency = on and 0 or 1 })
            tween(t.Label, 0.2, { TextColor3 = on and WHITE or resolve("SubText") })
            t.Arrow.Visible = on
        end
        Window.ActiveTab = tab
    end
    onTheme(function() if Window.ActiveTab then Window:SelectTab(Window.ActiveTab) end end)

    function Window:AddTab(o)
        if type(o) == "string" then o = { Name = o } end
        local tab = setmetatable({ Name = o.Name or "Tab", Locked = o.Locked == true, Window = Window }, Tab)

        local b = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = WHITE, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = #Window.Tabs + 1, Parent = tabList,
        })
        corner(b, 8)
        gradient(b, "AccentGrad", NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.55) }))
        local lab = text(b, tab.Name, 13, "SubText", Enum.Font.GothamMedium)
        lab.Position = UDim2.fromOffset(14, 0); lab.Size = UDim2.new(1, -44, 1, 0)
        local arrow = create("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0),
            Size = UDim2.fromOffset(14, 14), Text = "›", TextColor3 = WHITE, TextSize = 18, Font = Enum.Font.GothamBold, Visible = false, Parent = b,
        })
        if tab.Locked then
            create("TextLabel", {
                BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -8, .5, 0),
                Size = UDim2.fromOffset(14, 14), Text = "🔒", TextSize = 11, Font = Enum.Font.Gotham, Parent = b,
            })
        end

        local page = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
            ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = content,
        })
        bind(page, "ScrollBarImageColor3", "Accent")
        create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = page })
        local holder = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page })
        create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Top, Parent = holder })
        local function column()
            local c = create("Frame", { Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = holder })
            create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
            return c
        end
        tab.Left, tab.Right = column(), column()
        tab.Page, tab.Button, tab.Label, tab.Arrow = page, b, lab, arrow

        b.MouseButton1Click:Connect(function()
            if tab.Locked then
                Nebula:Notify({ Title = "Access Denied", Content = o.LockedMessage or "This tab is locked.", Type = "Error" })
                return
            end
            Window:SelectTab(tab)
        end)

        table.insert(Window.Tabs, tab)
        if not Window.ActiveTab and not tab.Locked then Window:SelectTab(tab) end
        return tab
    end

    -- ready-made config tab
    function Window:AddConfigTab(name)
        local tab = Window:AddTab(name or "Config")
        local sec = tab:AddSection("Configs")
        local nameBox = sec:AddInput({ Name = "Config name", Placeholder = "my-config", NoSave = true })
        local list = sec:AddDropdown({ Name = "Saved configs", Options = Nebula:ListConfigs(), NoSave = true })
        sec:AddButton({ Name = "Save", Callback = function()
            local n = nameBox.Value ~= "" and nameBox.Value or list.Value
            if n and Nebula:SaveConfig(n) then
                list:SetOptions(Nebula:ListConfigs())
                Nebula:Notify({ Title = "Config saved", Content = tostring(n), Type = "Success" })
            else
                Nebula:Notify({ Title = "Save failed", Content = "Enter a name (executor must support writefile).", Type = "Error" })
            end
        end })
        sec:AddButton({ Name = "Load", Callback = function()
            if list.Value and Nebula:LoadConfig(list.Value) then
                Nebula:Notify({ Title = "Config loaded", Content = tostring(list.Value), Type = "Success" })
            else
                Nebula:Notify({ Title = "Load failed", Content = "Pick a saved config first.", Type = "Warning" })
            end
        end })
        sec:AddButton({ Name = "Refresh list", Callback = function() list:SetOptions(Nebula:ListConfigs()) end })
        return tab
    end

    return Window
end

return Nebula
