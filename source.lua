--[[
    ╔══════════════════════════════════════════════════╗
    ║  Nebula UI Library  ·  v1.3.0  ·  MONOCHROME      ║
    ║  Pure black & white · comet glow border · glass   ║
    ╚══════════════════════════════════════════════════╝

    Features
      • Draggable window, minimize, close, toggle key + floating orb (mobile)
      • Sidebar tabs with search, locked tabs, 2-column pages
      • Collapsible sections
      • Toggle (pill switch), Slider, Dropdown (single/multi/search), Input,
        Button (shine + comet border), Keybind, Label, Paragraph, Divider
      • Notifications (Success / Error / Warning / Info) with progress bar
      • Built-in Settings panel (monochrome themes + UI scale)
      • Config save / load (writefile) + ready-made Config tab
      • Splash / loading screen

    Themes: Obsidian (default) | Eclipse (OLED black) | Graphite
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
    Version      = "1.3.0",
    Flags        = {},
    Options      = {},
    Windows      = {},
    CurrentTheme = "Obsidian",
    ConfigFolder = "NebulaUI",
    _themed  = {},
    _refresh = {},
    _conns   = {},
}

----------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------
Nebula.Themes = {
    Obsidian = {
        Accent = Color3.fromRGB(255, 255, 255), Accent2 = Color3.fromRGB(125, 125, 130),
        Glow1  = Color3.fromRGB(255, 255, 255), Glow2   = Color3.fromRGB(0, 0, 0),
        Btn1   = Color3.fromRGB(62, 62, 68),    Btn2    = Color3.fromRGB(14, 14, 16),
        Bg     = Color3.fromRGB(8, 8, 9),       Side    = Color3.fromRGB(13, 13, 15),
        Panel  = Color3.fromRGB(18, 18, 20),    Element = Color3.fromRGB(26, 26, 29),
        Stroke = Color3.fromRGB(62, 62, 68),    Text    = Color3.fromRGB(245, 245, 247),
        SubText= Color3.fromRGB(140, 140, 148),
    },
    Eclipse = {
        Accent = Color3.fromRGB(240, 240, 240), Accent2 = Color3.fromRGB(90, 90, 94),
        Glow1  = Color3.fromRGB(255, 255, 255), Glow2   = Color3.fromRGB(0, 0, 0),
        Btn1   = Color3.fromRGB(44, 44, 48),    Btn2    = Color3.fromRGB(0, 0, 0),
        Bg     = Color3.fromRGB(0, 0, 0),       Side    = Color3.fromRGB(6, 6, 7),
        Panel  = Color3.fromRGB(11, 11, 12),    Element = Color3.fromRGB(18, 18, 20),
        Stroke = Color3.fromRGB(48, 48, 52),    Text    = Color3.fromRGB(255, 255, 255),
        SubText= Color3.fromRGB(120, 120, 126),
    },
    Graphite = {
        Accent = Color3.fromRGB(228, 228, 231), Accent2 = Color3.fromRGB(110, 110, 116),
        Glow1  = Color3.fromRGB(240, 240, 244), Glow2   = Color3.fromRGB(22, 22, 25),
        Btn1   = Color3.fromRGB(80, 80, 86),    Btn2    = Color3.fromRGB(30, 30, 33),
        Bg     = Color3.fromRGB(20, 20, 23),    Side    = Color3.fromRGB(26, 26, 30),
        Panel  = Color3.fromRGB(32, 32, 36),    Element = Color3.fromRGB(41, 41, 46),
        Stroke = Color3.fromRGB(80, 80, 88),    Text    = Color3.fromRGB(240, 240, 243),
        SubText= Color3.fromRGB(158, 158, 168),
    },
}

-- status colors are shades of white/gray (icons tell them apart)
local Status = {
    Success = { Color3.fromRGB(255, 255, 255), "✓", "SUCCESS" },
    Error   = { Color3.fromRGB(226, 226, 231), "✕", "ERROR" },
    Warning = { Color3.fromRGB(190, 190, 197), "!", "WARNING" },
    Info    = { Color3.fromRGB(152, 152, 160), "i", "INFO" },
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
        -- comet: bright head fading into black (sharp, rotating border)
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, th.Glow1),
            ColorSequenceKeypoint.new(0.35, th.Glow2),
            ColorSequenceKeypoint.new(0.65, th.Glow2),
            ColorSequenceKeypoint.new(1, th.Glow1),
        })
    elseif key == "TextGrad" then
        return ColorSequence.new({
            ColorSequenceKeypoint.new(0, th.Accent),
            ColorSequenceKeypoint.new(0.5, th.Accent2),
            ColorSequenceKeypoint.new(1, th.Accent),
        })
    elseif key == "BtnGrad" then
        return ColorSequence.new(th.Btn1, th.Btn2)
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

-- Central animator: ONE Heartbeat connection drives every looping effect.
-- Runs at ~30Hz and skips anything whose window / tab is hidden -> no FPS cost.
local ANIM = {}

local function animate(inst, fn, gate)
    local e = { inst = inst, fn = fn, gate = gate }
    ANIM[#ANIM + 1] = e
    return { entry = e, Disconnect = function() e.dead = true end }
end

function Nebula:_startAnimator()
    if self._animConn then return end
    local acc, clean = 0, 0
    self._animConn = connect(RunService.Heartbeat, function(dt)
        acc = acc + dt
        if acc < 1 / 30 then return end
        acc = 0
        local t = os.clock()
        for i = 1, #ANIM do
            local e = ANIM[i]
            if not e.dead and e.on ~= false and (not e.gate or e.gate()) then e.fn(t) end
        end
        clean = clean + 1
        if clean >= 60 then
            clean = 0
            for i = #ANIM, 1, -1 do
                local e = ANIM[i]
                if e.dead or (self._gui and not e.inst:IsDescendantOf(self._gui)) then table.remove(ANIM, i) end
            end
        end
    end)
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

-- subtle white -> gray glass sheen (multiplies the frame colour)
local function sheen(p, rot, level)
    local d = level or 175
    return create("UIGradient", {
        Color = ColorSequence.new(WHITE, Color3.fromRGB(d, d, d)),
        Rotation = rot or 90, Parent = p,
    })
end

-- rotating black/white comet border (driven by the central animator)
-- opt.idle = only spins when entry.on = true (hover) · opt.gate = visibility check
local function glowStroke(p, thick, speed, tr, opt)
    opt = opt or {}
    local s = create("UIStroke", {
        Thickness = thick or 1, Color = WHITE, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p,
    })
    local g = gradient(s, "GlowGrad")
    local h = animate(p, function(t) g.Rotation = (t * (speed or 60)) % 360 end, opt.gate)
    if opt.idle then h.entry.on = false end
    return s, g, h
end

-- click ripple (host must not use a UIListLayout and should clip descendants)
local function ripple(host, x, scaleObj, alpha)
    local s = scaleObj and scaleObj.Scale or 1
    local w, h = host.AbsoluteSize.X / s, host.AbsoluteSize.Y / s
    local rx = math.clamp((x - host.AbsolutePosition.X) / s, 0, w)
    local d = math.max(w, h) * 2.2
    local r = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(rx, h / 2), Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = WHITE, BackgroundTransparency = alpha or 0.82, BorderSizePixel = 0, ZIndex = 2, Parent = host,
    })
    corner(r, 500)
    tween(r, 0.55, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
    task.delay(0.6, function() r:Destroy() end)
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
            local v = resolve(e[3])
            if typeof(v) == "Color3" then
                tween(e[1], 0.3, { [e[2]] = v }, Enum.EasingStyle.Quad)
            else
                e[1][e[2]] = v
            end
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
    self:_startAnimator()
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
    local BLACK = Color3.new(0, 0, 0)

    local wrap = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 68),
        LayoutOrder = self._notifCount, Parent = self._notifHolder,
    })
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(330, 0),
        BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, ClipsDescendants = true, Parent = wrap,
    })
    corner(card, 10)
    sheen(card, 20, 120)
    local _, _, spin = glowStroke(card, 1.2, 90, 0.2)

    local icon = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(28, 34),
        BackgroundColor3 = st[1], BorderSizePixel = 0, Parent = card,
    })
    corner(icon, 18)
    local iconTxt = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = st[2], TextTransparency = 1,
        TextColor3 = BLACK, TextSize = 18, Font = Enum.Font.GothamBlack, Parent = icon,
    })

    local tag = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(56, 7), Size = UDim2.new(1, -110, 0, 12),
        Text = "●  " .. st[3], TextColor3 = Color3.fromRGB(150, 150, 158), TextSize = 9, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    local title = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(56, 21), Size = UDim2.new(1, -66, 0, 16),
        Text = o.Title or "Notification", TextColor3 = Color3.fromRGB(250, 250, 252), TextSize = 13,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
    })
    local body = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(56, 38), Size = UDim2.new(1, -66, 0, 14),
        Text = o.Content or "", TextColor3 = Color3.fromRGB(150, 150, 158), TextSize = 11,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
    })
    local clock = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -62, 0, 7), Size = UDim2.fromOffset(34, 12),
        Text = os.date("%H:%M"), TextColor3 = Color3.fromRGB(110, 110, 118), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right, Parent = card,
    })

    local close = create("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -24, 0, 4), Size = UDim2.fromOffset(20, 18),
        Text = "X", TextColor3 = Color3.fromRGB(150, 150, 158), TextSize = 11, Font = Enum.Font.GothamBold, Parent = card,
    })

    local bar = create("Frame", {
        Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = card,
    })
    gradient(bar, "AccentGrad")

    local dead = false
    local function dismiss()
        if dead then return end
        dead = true
        tween(card, 0.3, { Position = UDim2.fromOffset(330, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.32, function() spin:Disconnect(); wrap:Destroy() end)
    end
    close.MouseButton1Click:Connect(dismiss)

    tween(card, 0.6, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
    task.delay(0.2, function()
        tween(icon, 0.5, { Size = UDim2.fromOffset(36, 36) }, Enum.EasingStyle.Back)
        tween(iconTxt, 0.3, { TextTransparency = 0 })
    end)
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

    local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 200, Parent = g })
    local bgG = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(44, 44, 48)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
        }),
        Rotation = 45, Parent = root,
    })

    local outer = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, 0, .5, -62), Size = UDim2.fromOffset(150, 150),
        BackgroundTransparency = 1, ZIndex = 201, Parent = root,
    })
    corner(outer, 75)
    local os1 = create("UIStroke", { Thickness = 1, Color = WHITE, Transparency = 0.75, Parent = outer })

    local ring = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(.5, 0, .5, 0), Size = UDim2.fromOffset(112, 112),
        BackgroundTransparency = 1, ZIndex = 201, Parent = outer,
    })
    corner(ring, 56)
    local rs = create("UIStroke", { Thickness = 3, Color = WHITE, Parent = ring })
    local rg = gradient(rs, "GlowGrad")
    local pulse = TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Size = UDim2.fromOffset(120, 120) })
    pulse:Play()

    for i = 1, 2 do
        local w = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(112, 112),
            BackgroundTransparency = 1, ZIndex = 200, Parent = outer,
        })
        corner(w, 500)
        local ws = create("UIStroke", { Thickness = 1.5, Color = WHITE, Transparency = 0.3, Parent = w })
        local info = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, (i - 1) * 1.1)
        TweenService:Create(w, info, { Size = UDim2.fromOffset(280, 280) }):Play()
        TweenService:Create(ws, info, { Transparency = 1 }):Play()
    end

    local dots = {}
    for i = 1, 3 do
        local d = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(i == 1 and 9 or 6, i == 1 and 9 or 6),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, BackgroundTransparency = i == 1 and 0 or 0.4, ZIndex = 203, Parent = outer,
        })
        corner(d, 5)
        dots[i] = d
    end

    local letter = create("TextLabel", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
        ZIndex = 202, Text = (o.Title or "N"):sub(1, 1):upper(), TextSize = 46, Font = Enum.Font.GothamBlack, Parent = ring,
    })
    bind(letter, "TextColor3", "Accent")

    local titleStr = o.Title or "NEBULA"
    local title = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 28),
        Size = UDim2.fromOffset(340, 36), Text = titleStr, TextSize = 30, Font = Enum.Font.GothamBlack,
        MaxVisibleGraphemes = 0, ZIndex = 201, TextColor3 = WHITE, Parent = root,
    })
    local tg = create("UIGradient", { Parent = title })
    bind(tg, "Color", "TextGrad")

    local sub = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 64),
        Size = UDim2.fromOffset(340, 16), Text = o.Subtitle or "", TextSize = 12, TextTransparency = 1,
        Font = Enum.Font.Gotham, ZIndex = 201, Parent = root,
    })
    bind(sub, "TextColor3", "SubText")
    local stepL = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 90),
        Size = UDim2.fromOffset(340, 16), Text = "", TextSize = 11, Font = Enum.Font.Code, ZIndex = 201, Parent = root,
    })
    bind(stepL, "TextColor3", "Accent")

    local track = create("Frame", { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 118), Size = UDim2.fromOffset(280, 6), BorderSizePixel = 0, ZIndex = 201, Parent = root })
    bind(track, "BackgroundColor3", "Element")
    corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 202, Parent = track })
    corner(fill, 3)
    gradient(fill, "AccentGrad")
    local pct = create("TextLabel", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, .5, 130),
        Size = UDim2.fromOffset(280, 16), Text = "0%", TextSize = 11, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 201, Parent = root,
    })
    bind(pct, "TextColor3", "SubText")

    local t0 = os.clock()
    local spin = RunService.Heartbeat:Connect(function()
        local t = os.clock() - t0
        rg.Rotation = (t * 200) % 360
        tg.Offset = Vector2.new(math.sin(t * 1.6) * 0.6, 0)
        bgG.Rotation = 45 + math.sin(t * 0.7) * 20
        for i, d in ipairs(dots) do
            local a = t * (2.4 - i * 0.4) + i * 2.1
            d.Position = UDim2.new(.5, math.cos(a) * 71, .5, math.sin(a) * 71)
        end
    end)

    -- title typewriter + subtitle fade
    task.spawn(function()
        for n = 1, #titleStr do title.MaxVisibleGraphemes = n; task.wait(0.05) end
        tween(sub, 0.5, { TextTransparency = 0 })
    end)

    local lastStep = 0
    local start = os.clock()
    while true do
        local a = math.clamp((os.clock() - start) / total, 0, 1)
        local e = 1 - (1 - a) ^ 2
        fill.Size = UDim2.fromScale(e, 1)
        pct.Text = math.floor(e * 100) .. "%"
        local idx = math.clamp(math.floor(a * #steps) + 1, 1, #steps)
        if idx ~= lastStep then
            lastStep = idx
            local str = "$ " .. steps[idx]
            stepL.Text = str
            task.spawn(function()
                stepL.MaxVisibleGraphemes = 0
                for n = 1, #str do
                    if lastStep ~= idx then return end
                    stepL.MaxVisibleGraphemes = n
                    task.wait(0.018)
                end
            end)
        end
        if a >= 1 then break end
        RunService.Heartbeat:Wait()
    end
    pct.Text = "100%"
    task.wait(0.3)

    pulse:Cancel()
    tween(outer, 0.5, { Size = UDim2.fromOffset(260, 260) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tween(root, 0.5, { BackgroundTransparency = 1 })
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") then tween(d, 0.45, { TextTransparency = 1 })
        elseif d:IsA("Frame") then tween(d, 0.45, { BackgroundTransparency = 1 })
        elseif d:IsA("UIStroke") then tween(d, 0.45, { Transparency = 1 }) end
    end
    task.wait(0.55)
    spin:Disconnect()
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
    for i = #ANIM, 1, -1 do ANIM[i] = nil end
    self._animConn = nil
    if self._gui then self._gui:Destroy() end
    self._gui = nil
end

----------------------------------------------------------------------
-- Element base
----------------------------------------------------------------------
local Section = {}
Section.__index = Section

local function gateOf(sec)
    return function()
        local t = sec.Tab
        local w = t and t.Window
        return w and w.Visible and not w.Minimized and t.Group and t.Group.Visible
    end
end

local function newRow(section, height)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, height), BorderSizePixel = 0, Parent = section.Body,
    })
    bind(row, "BackgroundColor3", "Element")
    row.ClipsDescendants = true
    corner(row, 8)
    sheen(row, 90, 200)
    local st = stroke(row, "Stroke", 1, 0.5)
    local pip = create("Frame", {
        AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 0, 0, (height > 0 and height or 34) / 2),
        Size = UDim2.fromOffset(2, 0), BorderSizePixel = 0, ZIndex = 3, Parent = row,
    })
    bind(pip, "BackgroundColor3", "Accent")
    row.MouseEnter:Connect(function()
        tween(st, 0.18, { Color = resolve("Accent"), Transparency = 0.35 })
        tween(pip, 0.25, { Size = UDim2.fromOffset(2, 16) }, Enum.EasingStyle.Back)
    end)
    row.MouseLeave:Connect(function()
        tween(st, 0.2, { Color = resolve("Stroke"), Transparency = 0.5 })
        tween(pip, 0.2, { Size = UDim2.fromOffset(2, 0) })
    end)
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
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = WHITE, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", ClipsDescendants = true, Parent = self.Body,
    })
    corner(btn, 8)
    gradient(btn, "BtnGrad").Rotation = 90
    local bst, _, bh = glowStroke(btn, 1.2, 70, 0.6, { idle = true, gate = gateOf(self) })
    local bs = create("UIScale", { Parent = btn })
    local shade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn })
    corner(shade, 8)
    -- diagonal shine that sweeps across on hover
    local shine = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(0, -40, .5, 0), Size = UDim2.new(0, 24, 2.4, 0),
        Rotation = 20, BackgroundColor3 = WHITE, BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 2, Parent = btn,
    })
    local l = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = o.Name or "Button",
        TextColor3 = WHITE, TextSize = 13, Font = Enum.Font.GothamBold, ZIndex = 4, Parent = btn,
    })
    local sc = self.Tab.Window._scaleObj
    btn.MouseEnter:Connect(function()
        bh.entry.on = true
        tween(shade, 0.2, { BackgroundTransparency = 0.94 })
        tween(bst, 0.2, { Transparency = 0 })
        shine.Position = UDim2.new(0, -40, .5, 0)
        tween(shine, 0.7, { Position = UDim2.new(1, 40, .5, 0) }, Enum.EasingStyle.Quad)
    end)
    btn.MouseLeave:Connect(function()
        bh.entry.on = false
        tween(bs, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
        tween(shade, 0.2, { BackgroundTransparency = 1 })
        tween(bst, 0.25, { Transparency = 0.6 })
    end)
    btn.MouseButton1Down:Connect(function(x)
        tween(shade, 0.08, { BackgroundTransparency = 0.8 })
        tween(bs, 0.1, { Scale = 0.96 })
        local s = sc and sc.Scale or 1
        local rx = (x - btn.AbsolutePosition.X) / s
        local d = (btn.AbsoluteSize.X / s) * 2.2
        local r = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(rx, 17), Size = UDim2.fromOffset(0, 0),
            BackgroundColor3 = WHITE, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 3, Parent = btn,
        })
        corner(r, 400)
        tween(r, 0.55, { Size = UDim2.fromOffset(d, d), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
        task.delay(0.6, function() r:Destroy() end)
    end)
    btn.MouseButton1Click:Connect(function()
        tween(bs, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
        tween(shade, 0.15, { BackgroundTransparency = 0.94 })
        if o.Callback then task.spawn(o.Callback) end
    end)
    function obj:SetText(s) l.Text = s end
    function obj:SetVisible(b) btn.Visible = b end
    return obj
end

---------------------------------------------------------------- Toggle
function Section:AddToggle(o)
    local obj = { Type = "Toggle", Value = o.Default == true }
    local row = newRow(self, 36)
    local l = text(row, o.Name or "Toggle", 13)
    l.Position = UDim2.fromOffset(10, 0); l.Size = UDim2.new(1, -64, 1, 0)

    local track = create("Frame", {
        AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -10, .5, 0),
        Size = UDim2.fromOffset(40, 20), BorderSizePixel = 0, Parent = row,
    })
    corner(track, 10)
    gradient(track, "AccentGrad")
    local ts = stroke(track, "Stroke", 1, 0.2)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 3, .5, 0),
        Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, Parent = track,
    })
    corner(knob, 7)
    local click = create("TextButton", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", Parent = row })

    local function render(animate)
        local on = obj.Value
        tween(track, 0.25, { BackgroundColor3 = on and WHITE or resolve("Panel") })
        tween(ts, 0.25, { Transparency = on and 1 or 0.2 })
        tween(knob, animate and 0.4 or 0, {
            Position = on and UDim2.new(1, -17, .5, 0) or UDim2.new(0, 3, .5, 0),
            BackgroundColor3 = on and Color3.fromRGB(10, 10, 12) or resolve("SubText"),
        }, Enum.EasingStyle.Back)
        if animate then
            knob.Size = UDim2.fromOffset(20, 14)
            tween(knob, 0.4, { Size = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Back)
        end
    end
    onTheme(function() render(false) end)

    function obj:Set(v, silent)
        obj.Value = v and true or false
        render(true); changed(obj, o, silent)
    end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) row.Visible = b end
    click.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
    click.MouseButton1Down:Connect(function(x) ripple(row, x, self.Tab.Window._scaleObj) end)

    register(obj, o); render(false)
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
    stroke(knob, "Bg", 2, 0)
    local halo = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, BorderSizePixel = 0, Parent = knob,
    })
    corner(halo, 100)
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
    local hovering = false
    local function knobSize(n) tween(knob, 0.2, { Size = UDim2.fromOffset(n, n) }, Enum.EasingStyle.Back) end
    hit.MouseEnter:Connect(function() hovering = true; if not dragging then knobSize(15) end end)
    hit.MouseLeave:Connect(function() hovering = false; if not dragging then knobSize(12) end end)
    hit.InputBegan:Connect(function(i)
        if isPress(i) then
            dragging = true
            knobSize(18)
            tween(halo, 0.3, { Size = UDim2.fromOffset(36, 36) }, Enum.EasingStyle.Back)
            tween(v, 0.15, { TextColor3 = resolve("Accent"), TextSize = 14 })
            self.Tab.Page.ScrollingEnabled = false
            fromInput(i.Position)
        end
    end)
    connect(UserInputService.InputChanged, function(i) if dragging and isMove(i) then fromInput(i.Position) end end)
    connect(UserInputService.InputEnded, function(i)
        if dragging and isPress(i) then
            dragging = false
            self.Tab.Page.ScrollingEnabled = true
            knobSize(hovering and 15 or 12)
            tween(halo, 0.25, { Size = UDim2.fromOffset(0, 0) })
            tween(v, 0.2, { TextColor3 = resolve("SubText"), TextSize = 12 })
        end
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
    box.ClipsDescendants = true
    local ul = create("Frame", {
        AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, 0), Size = UDim2.new(0, 0, 0, 2),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = box,
    })
    gradient(ul, "AccentGrad")
    box.Focused:Connect(function()
        bs.Color = resolve("Accent"); bs.Transparency = 0
        tween(ul, 0.35, { Size = UDim2.new(1, 0, 0, 2) }, Enum.EasingStyle.Quint)
    end)
    box.FocusLost:Connect(function()
        bs.Color = resolve("Stroke"); bs.Transparency = 0.5
        tween(ul, 0.25, { Size = UDim2.new(0, 0, 0, 2) })
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
        tween(btn, 0.2, { BackgroundColor3 = obj.Listening and resolve("Stroke") or resolve("Panel") })
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
    btn.MouseButton1Down:Connect(function(x) ripple(row, x, self.Tab.Window._scaleObj) end)
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

    local dsec = self
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
            tween(it[1], 0.15, { BackgroundTransparency = sel and 0.86 or 1 })
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
            b.MouseEnter:Connect(function()
                local sel = obj.Multi and obj.Value[k] or (not obj.Multi and obj.Value == k)
                if not sel then tween(b, 0.15, { BackgroundTransparency = 0.93 }) end
                tween(t, 0.2, { Position = UDim2.fromOffset(13, 0) })
            end)
            b.MouseLeave:Connect(function()
                local sel = obj.Multi and obj.Value[k] or (not obj.Multi and obj.Value == k)
                tween(b, 0.15, { BackgroundTransparency = sel and 0.86 or 1 })
                tween(t, 0.2, { Position = UDim2.fromOffset(8, 0) })
            end)
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

    local tok = 0
    function obj:Toggle(state)
        if state == nil then state = not obj.Open end
        if state == obj.Open then return end
        obj.Open = state
        tok = tok + 1
        local my = tok
        local sc = dsec.Tab.Window._scaleObj and dsec.Tab.Window._scaleObj.Scale or 1
        tween(arrow, 0.3, { Rotation = state and 180 or 0 }, Enum.EasingStyle.Back)
        wrap.ClipsDescendants = true
        if state then
            local h = (search and 28 or 0) + scroll.Size.Y.Offset + 6
            wrap.AutomaticSize = Enum.AutomaticSize.None
            wrap.Size = UDim2.new(1, 0, 0, 0)
            wrap.Visible = true
            tween(wrap, 0.32, { Size = UDim2.new(1, 0, 0, h) }, Enum.EasingStyle.Quint).Completed:Connect(function()
                if my == tok then
                    wrap.AutomaticSize = Enum.AutomaticSize.Y
                    wrap.Size = UDim2.new(1, 0, 0, 0)
                    wrap.ClipsDescendants = false
                end
            end)
        else
            wrap.AutomaticSize = Enum.AutomaticSize.None
            wrap.Size = UDim2.new(1, 0, 0, wrap.AbsoluteSize.Y / sc)
            tween(wrap, 0.25, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint).Completed:Connect(function()
                if my == tok then
                    wrap.Visible = false
                    wrap.AutomaticSize = Enum.AutomaticSize.Y
                    wrap.Size = UDim2.new(1, 0, 0, 0)
                end
            end)
        end
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
    head.ClipsDescendants = true
    corner(head, 8)
    head.MouseButton1Down:Connect(function(x) ripple(head, x, dsec.Tab.Window._scaleObj, 0.9) end)
    register(obj, o); build()
    return obj
end

---------------------------------------------------------------- Profile card
function Section:AddProfile()
    local row = newRow(self, 92)

    local av = create("ImageLabel", {
        Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(64, 64), BorderSizePixel = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150", Parent = row,
    })
    bind(av, "BackgroundColor3", "Panel")
    corner(av, 32)
    local ring = create("UIStroke", { Thickness = 2.5, Color = WHITE, Parent = av })
    local ringG = gradient(ring, "GlowGrad")
    animate(ring, function(t) ringG.Rotation = (t * 80) % 360 end, gateOf(self))

    local dot = create("Frame", { Position = UDim2.fromOffset(60, 60), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Status.Success[1], BorderSizePixel = 0, ZIndex = 3, Parent = row })
    corner(dot, 6)
    stroke(dot, "Element", 2, 0)
    TweenService:Create(dot, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.45 }):Play()

    local tag = text(row, "WELCOME BACK", 9, "Accent", Enum.Font.GothamBold)
    tag.Position = UDim2.fromOffset(90, 12); tag.Size = UDim2.new(1, -200, 0, 12)
    local nm = text(row, LocalPlayer.DisplayName, 18, "Text", Enum.Font.GothamBold)
    nm.Position = UDim2.fromOffset(90, 24); nm.Size = UDim2.new(1, -200, 0, 22)
    local un = text(row, "@" .. LocalPlayer.Name, 11, "SubText", Enum.Font.Gotham)
    un.Position = UDim2.fromOffset(90, 46); un.Size = UDim2.new(1, -200, 0, 14)

    local function pill(x, str, w)
        local p = create("Frame", { Position = UDim2.fromOffset(x, 66), Size = UDim2.fromOffset(w, 18), BorderSizePixel = 0, Parent = row })
        bind(p, "BackgroundColor3", "Panel")
        corner(p, 9)
        stroke(p, "Stroke", 1, 0.3)
        local t = text(p, str, 10, "SubText", Enum.Font.GothamBold)
        t.Size = UDim2.fromScale(1, 1); t.TextXAlignment = Enum.TextXAlignment.Center
    end
    pill(90, "ID " .. LocalPlayer.UserId, 112)
    pill(208, LocalPlayer.AccountAge .. " days old", 74)

    local box = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 14), Size = UDim2.fromOffset(84, 64), BorderSizePixel = 0, Parent = row })
    bind(box, "BackgroundColor3", "Panel")
    corner(box, 10)
    stroke(box, "Accent", 1, 0.55)
    local pt = text(box, "PLAYERS", 9, "SubText", Enum.Font.GothamBold)
    pt.Size = UDim2.new(1, 0, 0, 14); pt.Position = UDim2.fromOffset(0, 7); pt.TextXAlignment = Enum.TextXAlignment.Center
    local pn = text(box, "", 24, "Text", Enum.Font.GothamBlack)
    pn.Size = UDim2.new(1, 0, 0, 28); pn.Position = UDim2.fromOffset(0, 19); pn.TextXAlignment = Enum.TextXAlignment.Center
    local pm = text(box, "of " .. Players.MaxPlayers .. " max", 9, "SubText", Enum.Font.Gotham)
    pm.Size = UDim2.new(1, 0, 0, 12); pm.Position = UDim2.fromOffset(0, 48); pm.TextXAlignment = Enum.TextXAlignment.Center
    local function upd() pn.Text = tostring(#Players:GetPlayers()) end
    upd()
    connect(Players.PlayerAdded, upd)
    connect(Players.PlayerRemoving, function() task.defer(upd) end)
    return { Type = "Profile", SetVisible = function(_, b) row.Visible = b end }
end

---------------------------------------------------------------- Owner card
function Section:AddOwner(o)
    o = o or {}
    local row = newRow(self, 80)

    local icon = create("Frame", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = row })
    corner(icon, 14)
    local ig = gradient(icon, "AccentGrad")
    ig.Rotation = 45
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = (o.Name or "Y"):sub(1, 1):upper(),
        TextColor3 = Color3.new(0, 0, 0), TextSize = 28, Font = Enum.Font.GothamBlack, Parent = icon,
    })
    animate(icon, function(t) ig.Rotation = 45 + math.sin(t * 1.5) * 40 end, gateOf(self))

    local tag = text(row, "UI LIBRARY OWNER", 9, "SubText", Enum.Font.GothamBold)
    tag.Position = UDim2.fromOffset(76, 11); tag.Size = UDim2.new(1, -190, 0, 12)

    local name = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(76, 23), Size = UDim2.new(1, -190, 0, 26),
        Text = o.Name or "Yqantg Hub", TextColor3 = WHITE, TextSize = 21, Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    local ng = create("UIGradient", { Parent = name })
    bind(ng, "Color", "TextGrad")
    animate(name, function(t) ng.Offset = Vector2.new(math.sin(t * 1.3) * 0.65, 0) end, gateOf(self))

    local badge = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(76, 52), Size = UDim2.new(1, -190, 0, 14),
        Text = "✓ Verified  ·  " .. (o.Subtitle or o.Link or ""), TextColor3 = Status.Success[1], TextSize = 10,
        Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
    })

    local btn = create("TextButton", {
        AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0), Size = UDim2.fromOffset(96, 30),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
        TextColor3 = WHITE, TextSize = 11, Font = Enum.Font.GothamBold, ClipsDescendants = true, Parent = row,
    })
    corner(btn, 8)
    gradient(btn, "BtnGrad").Rotation = 90
    local _, _, oh = glowStroke(btn, 1.2, 70, 0.35, { idle = true, gate = gateOf(self) })
    local btnL = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "COPY LINK", ZIndex = 4,
        TextColor3 = WHITE, TextSize = 11, Font = Enum.Font.GothamBold, Parent = btn,
    })
    btn.MouseEnter:Connect(function() oh.entry.on = true; tween(btn, 0.2, { Size = UDim2.fromOffset(102, 32) }, Enum.EasingStyle.Back) end)
    btn.MouseLeave:Connect(function() oh.entry.on = false; tween(btn, 0.2, { Size = UDim2.fromOffset(96, 30) }, Enum.EasingStyle.Back) end)
    btn.MouseButton1Click:Connect(function()
        if setclipboard and o.Link then pcall(setclipboard, o.Link) end
        btnL.Text = "COPIED ✓"
        Nebula:Notify({ Title = "Link copied", Content = o.Link or "", Type = "Success", Duration = 2.5 })
        task.delay(1.6, function() btnL.Text = "COPY LINK" end)
        if o.Callback then task.spawn(o.Callback) end
    end)
    return { Type = "Owner", SetVisible = function(_, b) row.Visible = b end }
end

---------------------------------------------------------------- Live stats (FPS / ping / server)
function Section:AddStats()
    local row = newRow(self, 84)
    local function stat(x, title, w)
        local t = text(row, title, 9, "Accent", Enum.Font.GothamBold)
        t.Position = UDim2.fromOffset(x, 10); t.Size = UDim2.fromOffset(w or 80, 12)
        local v = text(row, "--", 24, "Text", Enum.Font.GothamBlack)
        v.Position = UDim2.fromOffset(x, 22); v.Size = UDim2.fromOffset(w or 80, 28)
        return v
    end
    local fpsL, pingL = stat(14, "FPS"), stat(100, "PING (MS)")
    local sid = text(row, "SERVER ID  " .. tostring(game.JobId):sub(1, 8), 10, "SubText", Enum.Font.Code)
    sid.Position = UDim2.fromOffset(200, 28); sid.Size = UDim2.new(1, -212, 0, 14)
    local fillT = text(row, "SERVER FILL", 9, "SubText", Enum.Font.GothamBold)
    fillT.Position = UDim2.fromOffset(14, 56); fillT.Size = UDim2.fromOffset(100, 12)
    local track = create("Frame", { Position = UDim2.new(0, 14, 0, 71), Size = UDim2.new(1, -28, 0, 5), BorderSizePixel = 0, Parent = row })
    bind(track, "BackgroundColor3", "Panel")
    corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = track })
    corner(fill, 3)
    gradient(fill, "AccentGrad")

    local frames, acc = 0, 0
    connect(RunService.Heartbeat, function(dt)
        frames = frames + 1; acc = acc + dt
        if acc >= 0.5 then
            local fps = math.floor(frames / acc + 0.5)
            frames, acc = 0, 0
            fpsL.Text = tostring(fps)
            tween(fpsL, 0.3, { TextColor3 = fps >= 50 and Status.Success[1] or (fps >= 30 and Status.Warning[1] or Status.Error[1]) })
            local ok, ping = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
            ping = ok and math.floor(ping) or 0
            pingL.Text = tostring(ping)
            tween(pingL, 0.3, { TextColor3 = ping < 100 and Status.Success[1] or (ping < 200 and Status.Warning[1] or Status.Error[1]) })
            tween(fill, 0.4, { Size = UDim2.fromScale(math.clamp(#Players:GetPlayers() / math.max(Players.MaxPlayers, 1), 0, 1), 1) })
        end
    end)
    return { Type = "Stats", SetVisible = function(_, b) row.Visible = b end }
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

    local col
    if o.Side == "Full" then
        col = self.Full
        self.FullPad.PaddingBottom = UDim.new(0, 8)
    else
        self._colCount = (self._colCount or 0) + 1
        col = (o.Side == "Right" or (o.Side == nil and self._colCount % 2 == 0)) and self.Right or self.Left
    end

    local sec = setmetatable({ Tab = self }, Section)
    local frame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
        LayoutOrder = self._sectionCount, Parent = col,
    })
    bind(frame, "BackgroundColor3", "Panel")
    corner(frame, 10)
    local fst = stroke(frame, "Stroke", 1, 0.5)
    sheen(frame, 90, 185)
    local pad = create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = frame })
    create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
    if o.NoHeader then
        frame.BackgroundTransparency = 1
        fst:Destroy()
        pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 0), UDim.new(0, 0), UDim.new(0, 0), UDim.new(0, 0)
    end

    local head, arrow, tl
    if not o.NoHeader then
        head = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = WHITE, BorderSizePixel = 0,
            AutoButtonColor = false, Text = "", LayoutOrder = 1, Parent = frame,
        })
        corner(head, 8)
        local hg = gradient(head, "AccentGrad", NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 0.97) }))
        local pip = create("Frame", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(3, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = head })
        corner(pip, 2)
        tl = create("TextLabel", {
            BackgroundTransparency = 1, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -40, 1, 0),
            Text = o.Name or "Section", TextColor3 = WHITE, TextSize = 13, Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
        })
        arrow = create("TextLabel", {
            BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, -16, .5, 0),
            Size = UDim2.fromOffset(16, 16), Text = "▾", TextColor3 = WHITE, TextSize = 14, Font = Enum.Font.GothamBold, Parent = head,
        })
        -- hover: header brightens, pip stretches
        head.MouseEnter:Connect(function()
            tween(hg, 0.25, { Offset = Vector2.new(0.25, 0) })
            tween(pip, 0.25, { Size = UDim2.fromOffset(3, 20), Position = UDim2.fromOffset(8, 4) }, Enum.EasingStyle.Back)
        end)
        head.MouseLeave:Connect(function()
            tween(hg, 0.25, { Offset = Vector2.new(0, 0) })
            tween(pip, 0.25, { Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(8, 7) }, Enum.EasingStyle.Back)
        end)
    end

    local body = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = frame })
    local layout = create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
    sec.Body = body

    -- smooth collapse / expand
    local open = o.Collapsed ~= true
    local fullH, busy = 0, 0
    local function sc() return self.Window._scaleObj and self.Window._scaleObj.Scale or 1 end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if body.AutomaticSize == Enum.AutomaticSize.Y then fullH = layout.AbsoluteContentSize.Y / sc() end
    end)

    local function apply(animate)
        if arrow then tween(arrow, 0.3, { Rotation = open and 0 or -90 }, Enum.EasingStyle.Back) end
        busy = busy + 1
        local my = busy
        if not animate then body.Visible = open; return end
        if open then
            body.Visible = true
            if fullH <= 1 then body.AutomaticSize = Enum.AutomaticSize.Y; return end
            body.ClipsDescendants = true
            body.AutomaticSize = Enum.AutomaticSize.None
            body.Size = UDim2.new(1, 0, 0, 0)
            tween(body, 0.35, { Size = UDim2.new(1, 0, 0, fullH) }, Enum.EasingStyle.Quint).Completed:Connect(function()
                if my == busy then
                    body.AutomaticSize = Enum.AutomaticSize.Y
                    body.ClipsDescendants = false
                    body.Size = UDim2.new(1, 0, 0, 0)
                end
            end)
        else
            fullH = layout.AbsoluteContentSize.Y / sc()
            body.ClipsDescendants = true
            body.AutomaticSize = Enum.AutomaticSize.None
            body.Size = UDim2.new(1, 0, 0, fullH)
            tween(body, 0.3, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint).Completed:Connect(function()
                if my == busy then
                    body.Visible = false
                    body.AutomaticSize = Enum.AutomaticSize.Y
                    body.Size = UDim2.new(1, 0, 0, 0)
                end
            end)
        end
    end
    if head then
        head.ClipsDescendants = true
        head.MouseButton1Down:Connect(function(x) ripple(head, x, self.Window._scaleObj, 0.88) end)
        head.MouseButton1Click:Connect(function() open = not open; apply(true) end)
    end
    apply(false)

    function sec:SetName(str) if tl then tl.Text = str end end
    function sec:Toggle(state) if state == nil then state = not open end; open = state; apply(true) end
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
    local function vgate() return Window.Visible end

    local fs = cfg.Size or UDim2.fromOffset(600, 380)
    local TOP, SIDE = 42, 150

    local Main = create("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(.5, .5), Position = cfg.Position or UDim2.fromScale(.5, .5),
        Size = fs, BorderSizePixel = 0, ClipsDescendants = true, Parent = gui,
    })
    bind(Main, "BackgroundColor3", "Bg")
    corner(Main, 12)
    sheen(Main, 65, 150)

    -- auto-fit to small screens
    local base = 1
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        base = math.clamp(math.min(vp.X / (fs.X.Offset + 40), vp.Y / (fs.Y.Offset + 40)), 0.5, 1)
    end
    local scale = create("UIScale", { Scale = base, Parent = Main })
    Window._scale = base
    Window._scaleObj = scale

    -- animated glow border
    local glow = create("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = WHITE, Parent = Main })
    local glowG = gradient(glow, "GlowGrad")
    animate(Main, function(t) glowG.Rotation = (t * 45) % 360 end, vgate)

    ------------------------------------------------ topbar
    local top = create("Frame", { Size = UDim2.new(1, 0, 0, TOP), BorderSizePixel = 0, Parent = Main })
    bind(top, "BackgroundColor3", "Side")
    sheen(top, 0, 165)

    local avatar = create("ImageLabel", {
        Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150", Parent = top,
    })
    bind(avatar, "BackgroundColor3", "Element")
    corner(avatar, 14)
    glowStroke(avatar, 1.6, 120, 0, { gate = vgate })
    local title = text(top, cfg.Title or "Nebula", 14, "Text", Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(46, 5); title.Size = UDim2.fromOffset(SIDE - 46, 16)
    local ttg = gradient(title, "TextGrad")
    animate(title, function(t) ttg.Offset = Vector2.new(math.sin(t * 1.2) * 0.55, 0) end, vgate)
    local subtitle = text(top, "●  " .. (cfg.Subtitle or LocalPlayer.Name), 10, "SubText", Enum.Font.Gotham)
    subtitle.Position = UDim2.fromOffset(46, 21); subtitle.Size = UDim2.fromOffset(SIDE - 46, 14)

    local function topButton(xFromRight)
        local b = create("TextButton", {
            AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -xFromRight, .5, 0),
            Size = UDim2.fromOffset(26, 26), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = top,
        })
        bind(b, "BackgroundColor3", "Element")
        corner(b, 7)
        b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundColor3 = resolve("Stroke") }) end)
        b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundColor3 = resolve("Element") }) end)
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

    closeBtn.MouseEnter:Connect(function() tween(closeBtn, .15, { BackgroundColor3 = WHITE }); cx.TextColor3 = Color3.new(0, 0, 0) end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, .15, { BackgroundColor3 = resolve("Element") }); cx.TextColor3 = resolve("SubText") end)

    makeDraggable(top, Main, function() return scale.Scale end)
    -- window "lifts" (border thickens) while dragging
    top.InputBegan:Connect(function(i) if isPress(i) then tween(glow, 0.2, { Thickness = 3.4 }) end end)
    connect(UserInputService.InputEnded, function(i) if isPress(i) then tween(glow, 0.35, { Thickness = 2 }) end end)

    -- shimmering line under the topbar
    local line = create("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = top })
    local lineG = gradient(line, "GlowGrad")
    animate(line, function(t) lineG.Offset = Vector2.new(math.sin(t * 1.1) * 0.7, 0) end, vgate)

    ------------------------------------------------ body
    local Body = create("Frame", { Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -TOP), BackgroundTransparency = 1, Parent = Main })

    local side = create("Frame", { Size = UDim2.new(0, SIDE, 1, 0), BorderSizePixel = 0, Parent = Body })
    bind(side, "BackgroundColor3", "Side")
    sheen(side, 90, 170)

    local search = create("TextBox", {
        Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 26), BorderSizePixel = 0, Text = "",
        PlaceholderText = "Search tabs...", TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = side,
    })
    bind(search, "BackgroundColor3", "Element"); bind(search, "TextColor3", "Text"); bind(search, "PlaceholderColor3", "SubText")
    corner(search, 8)
    stroke(search, "Stroke", 1, 0.5)
    create("UIPadding", { PaddingLeft = UDim.new(0, 10), Parent = search })

    -- sliding highlight behind the active tab
    local indicator = create("Frame", {
        Position = UDim2.fromOffset(6, 42), Size = UDim2.new(1, -12, 0, 32), BackgroundColor3 = WHITE,
        BorderSizePixel = 0, Visible = false, Parent = side,
    })
    corner(indicator, 8)
    gradient(indicator, "AccentGrad", NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.96) }))
    local ipip = create("Frame", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 0, .5, 0), Size = UDim2.fromOffset(3, 16), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = indicator })
    corner(ipip, 2)

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

    local credit = text(panel, (cfg.Brand or "Nebula UI") .. "  ·  v" .. self.Version, 10, "SubText", Enum.Font.Gotham)
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
            Text = "", ZIndex = 50, Parent = gui,
        })
        corner(orb, 22)
        gradient(orb, "BtnGrad").Rotation = 90
        create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 51,
            Text = (cfg.Title or "N"):sub(1, 1):upper(), TextColor3 = WHITE, TextSize = 20,
            Font = Enum.Font.GothamBlack, Parent = orb,
        })
        local os_ = create("UIStroke", { Thickness = 1.5, Color = WHITE, Parent = orb })
        local og = gradient(os_, "GlowGrad")
        animate(orb, function(t) og.Rotation = (t * 90) % 360 end)
        local osc = create("UIScale", { Parent = orb })
        local pulse = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(44, 44),
            BackgroundTransparency = 1, Parent = orb,
        })
        corner(pulse, 100)
        local ps = create("UIStroke", { Thickness = 1.5, Color = WHITE, Transparency = 0.45, Parent = pulse })
        local pinfo = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
        TweenService:Create(pulse, pinfo, { Size = UDim2.fromOffset(76, 76) }):Play()
        TweenService:Create(ps, pinfo, { Transparency = 1 }):Play()
        orb.MouseEnter:Connect(function() tween(osc, 0.25, { Scale = 1.12 }, Enum.EasingStyle.Back) end)
        orb.MouseLeave:Connect(function() tween(osc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end)
        orb.MouseButton1Down:Connect(function() tween(osc, 0.1, { Scale = 0.9 }) end)
        orb.MouseButton1Up:Connect(function() tween(osc, 0.3, { Scale = 1.12 }, Enum.EasingStyle.Back) end)
        local moved = 0
        makeDraggable(orb, orb, nil, function(d) moved = math.max(moved, math.abs(d.X) + math.abs(d.Y)) end)
        orb.InputBegan:Connect(function(i) if isPress(i) then moved = 0 end end)
        orb.MouseButton1Click:Connect(function() if moved < 8 then Window:Toggle() end end)
        Window._orb = orb
    end

    ------------------------------------------------ tabs
    function Window:SelectTab(tab)
        local prev = Window.ActiveTab
        for _, t in ipairs(Window.Tabs) do
            local on = t == tab
            tween(t.Label, 0.25, { TextColor3 = on and WHITE or resolve("SubText"), Position = UDim2.fromOffset(on and 18 or 14, 0) })
            t.Arrow.Visible = on
            if not on then t.Group.Visible = false end
        end
        tab.Group.Visible = true
        if prev ~= tab then
            tab.Group.GroupTransparency = 1
            tab.Group.Position = UDim2.fromOffset(0, 20)
            tween(tab.Group, 0.4, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
        end
        Window.ActiveTab = tab
        task.spawn(function()
            RunService.Heartbeat:Wait()
            if tab.Button.Parent and Window.ActiveTab == tab then
                local y = 42 + (tab.Button.AbsolutePosition.Y - tabList.AbsolutePosition.Y) / scale.Scale
                if not indicator.Visible then
                    indicator.Position = UDim2.fromOffset(6, y)
                    indicator.Visible = true
                else
                    tween(indicator, 0.45, { Position = UDim2.fromOffset(6, y) }, Enum.EasingStyle.Back)
                end
            end
        end)
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
        b.ClipsDescendants = true
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

        local group = create("CanvasGroup", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = content,
        })
        local page = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = group,
        })
        bind(page, "ScrollBarImageColor3", "Accent")
        create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = page })
        local holder = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page })
        create("UIListLayout", { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
        local full = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = holder })
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = full })
        local fullPad = create("UIPadding", { Parent = full })
        local cols = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = holder })
        create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Top, Parent = cols })
        local function column()
            local c = create("Frame", { Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = cols })
            create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
            return c
        end
        tab.Left, tab.Right = column(), column()
        tab.Full, tab.FullPad = full, fullPad
        tab.Page, tab.Button, tab.Label, tab.Arrow, tab.Group = page, b, lab, arrow, group

        b.MouseButton1Click:Connect(function()
            if tab.Locked then
                Nebula:Notify({ Title = "Access Denied", Content = o.LockedMessage or "This tab is locked.", Type = "Error" })
                return
            end
            Window:SelectTab(tab)
        end)

        b.MouseEnter:Connect(function()
            if Window.ActiveTab ~= tab then
                tween(b, 0.2, { BackgroundTransparency = 0.94 })
                tween(lab, 0.2, { TextColor3 = resolve("Text"), Position = UDim2.fromOffset(18, 0) })
            end
        end)
        b.MouseLeave:Connect(function()
            tween(b, 0.2, { BackgroundTransparency = 1 })
            if Window.ActiveTab ~= tab then tween(lab, 0.2, { TextColor3 = resolve("SubText"), Position = UDim2.fromOffset(14, 0) }) end
        end)
        b.MouseButton1Down:Connect(function(x) ripple(b, x, scale, 0.88) end)

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

    -- entrance animation
    glow.Transparency = 1
    scale.Scale = base * 0.85
    tween(glow, 0.8, { Transparency = 0 })
    tween(scale, 0.65, { Scale = base }, Enum.EasingStyle.Back)

    return Window
end

return Nebula
