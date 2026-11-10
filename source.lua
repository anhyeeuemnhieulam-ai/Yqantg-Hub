--[[
    ╔══════════════════════════════════════════════════╗
    ║  Nebula UI Library  ·  v2.0.0  ·  3D MONOCHROME   ║
    ║  Layered depth · parallax · 3D keycaps · glass    ║
    ╚══════════════════════════════════════════════════╝

    NEW in 2.0 (3D edition)
      • Window = real depth stack: slab layers + soft shadows + mouse parallax
        + specular light that follows the cursor
      • Full open / close choreography: rise + tilt + scale (Back easing),
        staggered top-bar / tab / section pop-in, backdrop blur, sound cues
      • Drag = window "lifts" off the surface, drop = bounce back
      • 3D keycap buttons (extruded base, press-down, cursor parallax label)
      • Rows lift toward the viewer on hover and tilt their lighting
      • Tab pages slide in/out in depth with cascading section pop-in
      • Resizable window (3D grip), animated settings panel
      • Tooltips on every element (Tooltip = "text")
      • New elements: ColorPicker, Progress, Segment
      • Config: delete, auto-load, Color3 support
      • Window:Close() (animated), Nebula:SetDepth(0..1.5)

    NEW in 2.1
      • BlockInput: camera / game input is sunk while the pointer is over the UI
        (no more dragging the screen / zooming when you touch the menu)
      • Windows and the orb are clamped on-screen while dragging
      • Backdrop blur is removed while the window is minimized ( - button )
      • Notify icons + floating orb use random anime-girl images from the web
        (override with Nebula.Icons.Notify / Nebula.Icons.Orb = id | url | {list})
      • Window background image: Background = { Image = id|url|"anime", Transparency = 0..1 }
        Window:SetBackground(img, transparency) / Window:SetBackgroundTransparency(t)

    Usage: see example.lua
]]

-- optional executor APIs are always nil-checked: the library runs from UNC 0% upward
local function svc(name)
    local s = game:GetService(name)
    if cloneref then
        local ok, c = pcall(cloneref, s)
        if ok and c then return c end
    end
    return s
end

local Players          = svc("Players")
local TweenService     = svc("TweenService")
local UserInputService = svc("UserInputService")
local RunService       = svc("RunService")
local CoreGui          = svc("CoreGui")
local HttpService      = svc("HttpService")
local Lighting         = svc("Lighting")
local ContextActionService = svc("ContextActionService")


if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    repeat task.wait() until Players.LocalPlayer
    LocalPlayer = Players.LocalPlayer
end

----------------------------------------------------------------------
-- Executor compatibility layer
-- Every executor function is optional. Missing ones fall back to something that still works:
--   files     -> in-memory store (configs work for the session)
--   http      -> HttpGet -> request/http_request/syn.request/... -> HttpGetAsync -> HttpService
--   clipboard -> setclipboard / toclipboard / set_clipboard / Clipboard.set / syn.write_clipboard
--   gui mount -> gethui -> CoreGui -> PlayerGui
--   images    -> need writefile + getcustomasset, otherwise skipped (drawn icons stay)
----------------------------------------------------------------------
local Compat = {}
do
    local mem = { files = {}, folders = {} }
    local function has(f) return f ~= nil and f ~= false end
    local function norm(p) return (tostring(p):gsub("\\", "/")) end

    Compat.canFiles  = has(writefile) and has(readfile) and has(isfile)
    Compat.canAssets = has(writefile) and (has(getcustomasset) or has(getsynasset))

    do
        local ok, name = pcall(function() if identifyexecutor then return (identifyexecutor()) end end)
        Compat.executor = (ok and name) and tostring(name) or "Unknown"
    end

    ---------------------------------------------- files
    function Compat.makefolder(p)
        p = norm(p)
        local acc = ""
        for seg in p:gmatch("[^/]+") do
            acc = acc == "" and seg or (acc .. "/" .. seg)
            if has(makefolder) then
                local ok, ex = pcall(function() return has(isfolder) and isfolder(acc) end)
                if not (ok and ex) then pcall(makefolder, acc) end
            end
            mem.folders[acc] = true
        end
    end
    function Compat.isfolder(p)
        p = norm(p)
        if has(isfolder) then
            local ok, r = pcall(isfolder, p)
            if ok and r then return true end
        end
        return mem.folders[p] == true
    end
    function Compat.writefile(p, data)
        p = norm(p)
        mem.files[p] = tostring(data)
        if has(writefile) then
            local folder = p:match("^(.*)/[^/]+$")
            if folder then Compat.makefolder(folder) end
            local ok = pcall(writefile, p, data)
            return true, ok          -- (saved, persisted to disk)
        end
        return true, false
    end
    function Compat.isfile(p)
        p = norm(p)
        if has(isfile) then
            local ok, r = pcall(isfile, p)
            if ok and r then return true end
        end
        return mem.files[p] ~= nil
    end
    function Compat.readfile(p)
        p = norm(p)
        if has(readfile) then
            local ok, r = pcall(readfile, p)
            if ok and type(r) == "string" then return r end
        end
        return mem.files[p]
    end
    function Compat.delfile(p)
        p = norm(p)
        mem.files[p] = nil
        if has(delfile) then pcall(delfile, p) end
        return true
    end
    function Compat.listfiles(folder)
        folder = norm(folder)
        local out, seen = {}, {}
        if has(listfiles) then
            local ok, r = pcall(listfiles, folder)
            if ok and type(r) == "table" then
                for _, f in ipairs(r) do
                    f = norm(f)
                    if not seen[f] then seen[f] = true; out[#out + 1] = f end
                end
            end
        end
        for f in pairs(mem.files) do
            if f:sub(1, #folder + 1) == folder .. "/" and not seen[f] then
                seen[f] = true; out[#out + 1] = f
            end
        end
        return out
    end

    ---------------------------------------------- http
    local function requestFns()
        local list = {}
        if syn and syn.request then list[#list + 1] = syn.request end
        if http and http.request then list[#list + 1] = http.request end
        if fluxus and fluxus.request then list[#list + 1] = fluxus.request end
        if has(http_request) then list[#list + 1] = http_request end
        if has(request) then list[#list + 1] = request end
        return list
    end
    Compat.canHttp = function()
        if #requestFns() > 0 then return true end
        return pcall(function() return game.HttpGet end) and true or false
    end
    function Compat.get(url)
        local function good(r) return type(r) == "string" and #r > 0 end
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and good(res) then return res end
        for _, fn in ipairs(requestFns()) do
            local ok2, r = pcall(fn, { Url = url, Method = "GET" })
            if ok2 and type(r) == "table" and good(r.Body) and (r.StatusCode == nil or (r.StatusCode >= 200 and r.StatusCode < 300)) then
                return r.Body
            end
        end
        ok, res = pcall(function() return game:HttpGetAsync(url) end)
        if ok and good(res) then return res end
        ok, res = pcall(function() return HttpService:GetAsync(url) end)
        if ok and good(res) then return res end
    end

    ---------------------------------------------- clipboard
    local function clipFns()
        local list = {}
        if has(setclipboard) then list[#list + 1] = setclipboard end
        if has(toclipboard) then list[#list + 1] = toclipboard end
        if has(set_clipboard) then list[#list + 1] = set_clipboard end
        if Clipboard and Clipboard.set then list[#list + 1] = Clipboard.set end
        if syn and syn.write_clipboard then list[#list + 1] = syn.write_clipboard end
        return list
    end
    Compat.canClip = function() return #clipFns() > 0 end
    function Compat.copy(text)
        text = tostring(text)
        for _, fn in ipairs(clipFns()) do
            if pcall(fn, text) then return true end
        end
        return false
    end

    ---------------------------------------------- gui mount
    function Compat.mountGui(g)
        if syn and syn.protect_gui then pcall(syn.protect_gui, g)
        elseif has(protect_gui) then pcall(protect_gui, g)
        elseif has(protectgui) then pcall(protectgui, g) end

        if has(gethui) then
            local ok = pcall(function() g.Parent = gethui() end)
            if ok and g.Parent then return "gethui" end
        end
        local ok = pcall(function() g.Parent = CoreGui end)
        if ok and g.Parent then return "CoreGui" end
        g.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 15)
        return "PlayerGui"
    end

    ---------------------------------------------- report
    function Compat.report()
        return {
            Executor  = Compat.executor,
            Files     = Compat.canFiles,       -- configs persist on disk (otherwise: this session only)
            Assets    = Compat.canAssets,      -- web images (anime icons / backgrounds / social pictures)
            Http      = Compat.canHttp(),
            Clipboard = Compat.canClip(),
            HiddenUI  = has(gethui),
            CloneRef  = has(cloneref),
        }
    end
end

local Nebula = {
    Version      = "2.2.0",
    Depth        = 1,        -- 3D intensity (0 = flat, 1 = default, 1.5 = max)
    Parallax     = true,     -- window follows cursor with depth
    BlurEnabled  = true,     -- backdrop blur while a window is open
    SoundEnabled = true,
    SoundVolume  = 1,        -- 0..1.5 multiplier for all sound cues
    Tooltips     = true,
    BlockInput   = true,     -- sink camera / game input while the pointer is over the UI
    AnimeIcons   = true,     -- random anime-girl images for notify icons / orb (needs writefile + getcustomasset)
    Icons        = {},       -- Icons.Notify / Icons.Orb = id | url | {list} | false (off) ; nil = random anime
    ImageFolder  = "NebulaUI/img",
    SoundIds     = { Click = "rbxassetid://6895079853" },  -- swap for your own ids
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
    Success = { Color3.fromRGB(255, 255, 255), "check", "SUCCESS" },
    Error   = { Color3.fromRGB(226, 226, 231), "cross", "ERROR" },
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


local BLACK = Color3.new(0, 0, 0)
local SHADOW_IMG = "rbxassetid://6014261993"

-- soft drop shadow (9-slice). parent must NOT use a layout.
local function softShadow(parent, o)
    o = o or {}
    return create("ImageLabel", {
        Name = "Shadow", BackgroundTransparency = 1, Image = SHADOW_IMG, ImageColor3 = BLACK,
        ImageTransparency = o.transparency or 0.5, ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450), AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.new(.5, 0, .5, o.offset or 6),
        Size = UDim2.new(1, o.spread or 30, 1, o.spread or 30), ZIndex = o.z or 0, Parent = parent,
    })
end

-- light-on-top / dark-on-bottom edge (gives strokes a bevel)
local function bevelGrad(st)
    return create("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(105, 105, 110)), Rotation = 90, Parent = st })
end

-- sound cues
function Nebula:_sfx(kind)
    if not self.SoundEnabled or not self._gui then return end
    local id = self.SoundIds[kind] or self.SoundIds.Click
    if not id then return end
    local speed = ({ Click = 1, Toggle = 1.25, Open = 0.85, Close = 0.7, Notify = 1.5 })[kind] or 1
    local snd = create("Sound", { SoundId = id, Volume = 0.25 * (self.SoundVolume or 1), PlaybackSpeed = speed, Parent = self._gui })
    pcall(function() snd:Play() end)
    task.delay(2.5, function() snd:Destroy() end)
end

-- backdrop blur
function Nebula:_blur(size)
    if not self.BlurEnabled then size = 0 end
    if not self._blurFx or not self._blurFx.Parent then
        local b = Instance.new("BlurEffect")
        b.Name = "NebulaBlur"; b.Size = 0
        pcall(function() b.Parent = Lighting end)
        self._blurFx = b
    end
    tween(self._blurFx, 0.45, { Size = size }, Enum.EasingStyle.Quad)
end

-- blur only while at least one window is open AND not minimized
function Nebula:_syncBlur()
    local on = false
    for _, w in ipairs(self.Windows) do
        if w.Visible and not w.Minimized then on = true; break end
    end
    self:_blur(on and 14 or 0)
end

-- input sink: while any lock is held, camera / game actions don't receive the input
function Nebula:_lock(key, on)
    self._locks = self._locks or {}
    self._locks[key] = on and true or nil
    local want = self.BlockInput and next(self._locks) ~= nil
    if want and not self._sinking then
        self._sinking = true
        pcall(function()
            ContextActionService:BindActionAtPriority("NebulaSink", function()
                return Enum.ContextActionResult.Sink
            end, false, Enum.ContextActionPriority.High.Value + 100,
                Enum.UserInputType.Touch, Enum.UserInputType.MouseButton1,
                Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseWheel)
        end)
    elseif not want and self._sinking then
        self._sinking = false
        pcall(function() ContextActionService:UnbindAction("NebulaSink") end)
    end
end

-- images from the web (executor needs writefile + getcustomasset) ---------
local httpGet = Compat.get

local imgCache, imgN = {}, 0
function Nebula:_download(url)
    if imgCache[url] then return imgCache[url] end
    local toAsset = getcustomasset or getsynasset
    if not (Compat.canAssets and toAsset) then return nil end
    local body = httpGet(url)
    if not body then return nil end
    Compat.makefolder(self.ImageFolder)
    imgN = imgN + 1
    local ext = (url:match("%.(%a+)$") or url:match("%.(%a+)%?") or "png"):lower()
    local path = ("%s/img_%d_%d.%s"):format(self.ImageFolder, os.time(), imgN, ext)
    if not pcall(writefile, path, body) then return nil end
    local ok, asset = pcall(toAsset, path)
    if ok and asset then imgCache[url] = asset; return asset end
end

local ANIME_APIS = {
    { "https://api.waifu.pics/sfw/waifu", function(j) return j.url end },
    { "https://nekos.best/api/v2/waifu", function(j) return j.results and j.results[1] and j.results[1].url end },
}
function Nebula:_randomAnime()
    for _ = 1, 6 do
        if self._unloaded then return nil end
        local api = ANIME_APIS[math.random(#ANIME_APIS)]
        local raw = httpGet(api[1])
        if raw then
            local ok, j = pcall(HttpService.JSONDecode, HttpService, raw)
            local url = ok and type(j) == "table" and api[2](j)
            if type(url) == "string" then
                local l = url:lower()
                if not l:find("%.gif") and not l:find("%.webp") then   -- Roblox can't show those
                    local a = self:_download(url)
                    if a then return a end
                end
            end
        end
    end
end

function Nebula:_warmPool(n)
    if self._warming or not self.AnimeIcons or not Compat.canAssets then return end
    self._warming = true
    self._pool = self._pool or {}
    task.spawn(function()
        for _ = 1, n do
            if self._unloaded then break end
            local a = self:_randomAnime()
            if a then
                table.insert(self._pool, a)
                local w = self._waiters or {}
                self._waiters = {}
                for _, cb in ipairs(w) do pcall(cb, self._pool[math.random(#self._pool)]) end
            end
        end
        self._warming = false
    end)
end

local function pickAnime(self, cb)
    if self._pool and #self._pool > 0 then cb(self._pool[math.random(#self._pool)]); return end
    self._waiters = self._waiters or {}
    table.insert(self._waiters, cb)
    self:_warmPool(4)
end

-- src: number / "123" / "rbxassetid://.." / "https://.." / {list} / nil|"anime" (random anime) / false (none)
function Nebula:_image(src, cb)
    if src == false then return end
    if type(src) == "table" then src = src[math.random(#src)] end
    if src == nil or src == true or src == "anime" then
        if self.AnimeIcons and Compat.canAssets then pickAnime(self, cb) end
        return
    end
    if type(src) == "number" or (type(src) == "string" and src:match("^%d+$")) then
        cb("rbxassetid://" .. src); return
    end
    if type(src) == "string" and src:match("^https?://") then
        task.spawn(function()
            local a = self:_download(src)
            if a then cb(a) end
        end)
        return
    end
    cb(src)
end

function Nebula:SetDepth(v) self.Depth = math.clamp(tonumber(v) or 1, 0, 1.5) end

-- tooltips
local function addTip(inst, str)
    if not str or str == "" then return end
    inst.MouseEnter:Connect(function() Nebula:_showTip(str) end)
    inst.MouseLeave:Connect(function() Nebula:_hideTip() end)
    inst.MouseMoved:Connect(function(x, y) Nebula:_moveTip(x, y) end)
end

-- row "press into the screen" feedback (rows register their UIScale here)
local ROWPOP = setmetatable({}, { __mode = "k" })
local function pressDepth(hit, row)
    local pp = ROWPOP[row]
    if not pp then return end
    hit.MouseButton1Down:Connect(function() tween(pp, 0.08, { Scale = 0.982 }) end)
    hit.MouseButton1Up:Connect(function() tween(pp, 0.4, { Scale = 1.01 }, Enum.EasingStyle.Back) end)
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

-- touch-only device (phone): GetMouseLocation() follows whichever finger moved last,
-- so anything driven by it (parallax / hover) would jitter when a 2nd finger swipes elsewhere.
local function touchOnly()
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- vector icons built from frames (no font glyphs -> never shows the "[]" missing-glyph box)
-- kind: check | cross | down | right | grip | lock
-- o.size = number | UDim2, o.color = Color3 | theme key, o.thick, o.pos, o.anchor, o.z
local function paintTo(inst, prop, color)
    if type(color) == "string" then bind(inst, prop, color) else inst[prop] = color end
end

local function drawIcon(parent, kind, o)
    o = o or {}
    local sz = o.size or 14
    if type(sz) == "number" then sz = UDim2.fromOffset(sz, sz) end
    local th, color, z = o.thick or 2, o.color or WHITE, o.z or 1
    local root = create("CanvasGroup", {
        Name = "Icon_" .. kind, BackgroundTransparency = 1, BorderSizePixel = 0,
        AnchorPoint = o.anchor or Vector2.new(.5, .5), Position = o.pos or UDim2.fromScale(.5, .5),
        Size = sz, ZIndex = z, Parent = parent,
    })
    local function bar(cx, cy, len, rot)
        local b = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(cx, cy),
            Size = UDim2.new(len, 0, 0, th), Rotation = rot, BorderSizePixel = 0, ZIndex = z, Parent = root,
        })
        create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = b })
        paintTo(b, "BackgroundColor3", color)
    end
    if kind == "check" then
        bar(.29, .63, .31, 45); bar(.62, .51, .64, -46)
    elseif kind == "cross" then
        bar(.5, .5, .8, 45); bar(.5, .5, .8, -45)
    elseif kind == "down" then
        bar(.34, .52, .5, 45); bar(.66, .52, .5, -45)
    elseif kind == "right" then
        bar(.52, .34, .5, 45); bar(.52, .66, .5, -45)
    elseif kind == "grip" then
        bar(.78, .78, .16, -45); bar(.62, .62, .46, -45); bar(.46, .46, .76, -45)
    elseif kind == "lock" then
        local sh = create("Frame", {
            AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .06), Size = UDim2.fromScale(.44, .56),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, Parent = root,
        })
        create("UICorner", { CornerRadius = UDim.new(0, 99), Parent = sh })
        local ss = create("UIStroke", { Thickness = th, Parent = sh })
        paintTo(ss, "Color", color)
        local body = create("Frame", {
            AnchorPoint = Vector2.new(.5, 0), Position = UDim2.fromScale(.5, .46), Size = UDim2.fromScale(.74, .5),
            BorderSizePixel = 0, ZIndex = z, Parent = root,
        })
        create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = body })
        paintTo(body, "BackgroundColor3", color)
    end
    return root
end

local function iconTween(root, t, color)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("Frame") and d.BackgroundTransparency < 1 then
            tween(d, t, { BackgroundColor3 = color })
        elseif d:IsA("UIStroke") then
            tween(d, t, { Color = color })
        end
    end
end

-- status glyph: drawn icon for check / cross, plain text for "!" and "i"
local DRAWN = { check = true, cross = true }
local function statusGlyph(parent, glyph, textSize, color, z, alpha, frac)
    if DRAWN[glyph] then
        local g = drawIcon(parent, glyph, { size = UDim2.fromScale(frac or .5, frac or .5), color = color, z = z, thick = 2 })
        g.GroupTransparency = alpha or 0
        return g
    end
    return create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = glyph, TextTransparency = alpha or 0,
        TextColor3 = color, TextSize = textSize, Font = Enum.Font.GothamBlack, ZIndex = z, Parent = parent,
    })
end
local function fadeGlyph(g, t, a)
    if g:IsA("CanvasGroup") then tween(g, t, { GroupTransparency = a }) else tween(g, t, { TextTransparency = a }) end
end

-- multi-touch safe tracking: a drag only follows the finger (InputObject) that started it.
-- mouse: any MouseMovement / MouseButton1 counts.
local function ownsMove(tracked, i)
    if not tracked then return false end
    if tracked.UserInputType == Enum.UserInputType.Touch then return i == tracked end
    return i.UserInputType == Enum.UserInputType.MouseMovement
end
local function ownsEnd(tracked, i)
    if not tracked then return false end
    if tracked.UserInputType == Enum.UserInputType.Touch then return i == tracked end
    return i.UserInputType == Enum.UserInputType.MouseButton1
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

-- keep: "window" (top bar always reachable) | "full" (fully on-screen) | nil
local function makeDraggable(handle, target, getScale, onMove, keep)
    local dragging, dragStart, startPos, startAbs, track = false, nil, nil, nil, nil
    local function stop()
        if dragging then dragging = false; Nebula:_lock("drag", false) end
    end
    handle.InputBegan:Connect(function(i)
        if isPress(i) then
            if dragging then return end   -- already held by another finger
            dragging, dragStart, startPos, startAbs, track = true, i.Position, target.Position, target.AbsolutePosition, i
            Nebula:_lock("drag", true)
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then stop() end
            end)
        end
    end)
    connect(UserInputService.InputEnded, function(i) if dragging and ownsEnd(track, i) then stop() end end)
    connect(UserInputService.InputChanged, function(i)
        if dragging and ownsMove(track, i) then
            local d = i.Position - dragStart
            local s = getScale and getScale() or 1
            local par = target.Parent
            if keep and par then
                local vp, sz = par.AbsoluteSize, target.AbsoluteSize
                local nx, ny = startAbs.X + d.X, startAbs.Y + d.Y
                if keep == "full" then
                    nx = math.clamp(nx, 0, math.max(vp.X - sz.X, 0))
                    ny = math.clamp(ny, 0, math.max(vp.Y - sz.Y, 0))
                else
                    nx = math.clamp(nx, 80 - sz.X, vp.X - 80)
                    ny = math.clamp(ny, 0, vp.Y - 44)
                end
                d = Vector2.new(nx - startAbs.X, ny - startAbs.Y)
            end
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
    Compat.mountGui(g)

    self._gui = g
    self:_startAnimator()
    self._notifHolder = create("Frame", {
        Name = "Notifications", BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.new(0, 300, 1, -24), ZIndex = 100, Parent = g,
    }, {
        create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    self:_buildTip(g)
    if self.AnimeIcons and (self.Icons.Notify == nil or self.Icons.Orb == nil) then self:_warmPool(4) end
    return g
end

function Nebula:_buildTip(g)
    local tip = create("CanvasGroup", {
        Name = "Tooltip", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Color3.fromRGB(14, 14, 16), BorderSizePixel = 0, GroupTransparency = 1,
        Visible = false, ZIndex = 180, Parent = g,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 7), Parent = tip })
    create("UIStroke", { Thickness = 1, Color = Color3.fromRGB(90, 90, 98), Transparency = 0.3, Parent = tip })
    create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = tip })
    local lbl = create("TextLabel", {
        BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
        Text = "", TextSize = 11, Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(235, 235, 240),
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 181, Parent = tip,
    })
    create("UISizeConstraint", { MaxSize = Vector2.new(230, math.huge), Parent = lbl })
    local sc = create("UIScale", { Scale = 0.9, Parent = tip })
    self._tip = { frame = tip, label = lbl, scale = sc, tok = 0 }
end

function Nebula:_showTip(str)
    if self.Tooltips == false then return end
    local t = self._tip
    if not t then return end
    t.tok = t.tok + 1
    local my = t.tok
    t.label.Text = str
    task.delay(0.35, function()
        if my ~= t.tok then return end
        t.frame.Visible = true
        t.scale.Scale = 0.9
        tween(t.frame, 0.18, { GroupTransparency = 0 })
        tween(t.scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
    end)
end

function Nebula:_hideTip()
    local t = self._tip
    if not t then return end
    t.tok = t.tok + 1
    local my = t.tok
    tween(t.frame, 0.12, { GroupTransparency = 1 })
    task.delay(0.13, function() if my == t.tok then t.frame.Visible = false end end)
end

function Nebula:_moveTip(x, y)
    local t = self._tip
    if not t then return end
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local px = math.min(x + 14, vp.X - t.frame.AbsoluteSize.X - 8)
    t.frame.Position = UDim2.fromOffset(px, y + 18)
end

function Nebula:Notify(o)
    o = o or {}
    self:_ensureGui()
    self:_sfx("Notify")
    local st = Status[o.Type or "Info"] or Status.Info
    local duration = o.Duration or 4
    self._notifCount = (self._notifCount or 0) + 1
    local BLACK = Color3.new(0, 0, 0)

    local wrap = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 68),
        LayoutOrder = self._notifCount, Parent = self._notifHolder,
    })
    -- 3D: card lives on a "slide" layer with its own soft shadow, swings in with a tilt
    local slide = create("Frame", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(330, 0),
        Rotation = 9, Parent = wrap,
    })
    softShadow(slide, { offset = 7, spread = 36, transparency = 0.35 })
    local card = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 14, 16),
        BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = slide,
    })
    corner(card, 10)
    sheen(card, 20, 120)
    local _, _, spin = glowStroke(card, 1.2, 90, 0.2)

    local icon = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(28, 34),
        BackgroundColor3 = st[1], BorderSizePixel = 0, Parent = card,
    })
    corner(icon, 18)
    local iconTxt = statusGlyph(icon, st[2], 18, BLACK, 1, 1, 0.5)
    -- anime picture inside the icon (status glyph moves to a small badge)
    local hasPic = false
    local pic = create("ImageLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4),
        ImageTransparency = 1, ScaleType = Enum.ScaleType.Crop, ZIndex = 2, Parent = icon,
    })
    corner(pic, 18)
    local badge = create("Frame", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 3, 1, 3), Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = st[1], BorderSizePixel = 0, Visible = false, ZIndex = 4, Parent = icon,
    })
    corner(badge, 8)
    create("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(14, 14, 16), Parent = badge })
    statusGlyph(badge, st[2], 10, BLACK, 5, 0, 0.62)
    self:_image(self.Icons.Notify, function(asset)
        if not pic.Parent then return end
        hasPic = true
        pic.Image = asset
        tween(pic, 0.35, { ImageTransparency = 0 })
        fadeGlyph(iconTxt, 0.2, 1)
        badge.Visible = true
    end)

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

    local cardScale = create("UIScale", { Parent = card })
    card.MouseEnter:Connect(function() tween(cardScale, 0.25, { Scale = 1.035 }, Enum.EasingStyle.Back) end)
    card.MouseLeave:Connect(function() tween(cardScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end)
    local dead = false
    local function dismiss()
        if dead then return end
        dead = true
        tween(slide, 0.3, { Position = UDim2.fromOffset(330, 0), Rotation = -10 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.32, function() spin:Disconnect(); wrap:Destroy() end)
    end
    close.MouseButton1Click:Connect(dismiss)

    tween(slide, 0.7, { Position = UDim2.fromOffset(0, 0), Rotation = 0 }, Enum.EasingStyle.Back)
    task.delay(0.2, function()
        tween(icon, 0.5, { Size = UDim2.fromOffset(36, 36) }, Enum.EasingStyle.Back)
        if not hasPic then fadeGlyph(iconTxt, 0.3, 0) end
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
    local exiting = false
    local spin = RunService.Heartbeat:Connect(function()
        local t = os.clock() - t0
        rg.Rotation = (t * 200) % 360
        tg.Offset = Vector2.new(math.sin(t * 1.6) * 0.6, 0)
        bgG.Rotation = 45 + math.sin(t * 0.7) * 20
        -- 3D orbits: tilted ellipses, depth = size + opacity + draw order
        for i, d in ipairs(dots) do
            local a = t * (2.4 - i * 0.4) + i * 2.1
            local tilt, phi = 0.5 + i * 0.45, i * 1.25
            local ox, oy = math.cos(a) * 80, math.sin(a) * 80 * math.sin(tilt)
            local z = math.sin(a) * math.cos(tilt)
            d.Position = UDim2.new(.5, ox * math.cos(phi) - oy * math.sin(phi), .5, ox * math.sin(phi) + oy * math.cos(phi))
            local sz = (i == 1 and 9 or 6) * (1 + z * 0.55)
            d.Size = UDim2.fromOffset(sz, sz)
            d.ZIndex = z > 0 and 203 or 199
            if not exiting then d.BackgroundTransparency = math.clamp(0.4 - z * 0.4, 0, 0.9) end
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
    exiting = true
    tween(outer, 0.55, { Size = UDim2.fromOffset(460, 460) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
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
    local out, seenN = {}, {}
    do
        for _, f in ipairs(Compat.listfiles(self.ConfigFolder)) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n and n ~= "autoload" and not seenN[n] then seenN[n] = true; table.insert(out, n) end
        end
    end
    return out
end

function Nebula:SaveConfig(name)
    if not name or name == "" then return false end
    local data = {}
    for flag, v in pairs(self.Flags) do
        local opt = self.Options[flag]
        if typeof(v) == "EnumItem" then data[flag] = { __enum = v.Name }
        elseif typeof(v) == "Color3" then data[flag] = { __c3 = { v.R, v.G, v.B } }
        elseif type(v) ~= "userdata" and not (opt and opt.NoSave) then data[flag] = v end
    end
    Compat.makefolder(self.ConfigFolder)
    local ok = Compat.writefile(self.ConfigFolder .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    return ok
end

function Nebula:LoadConfig(name)
    if not name then return false end
    local path = self.ConfigFolder .. "/" .. name .. ".json"
    if not Compat.isfile(path) then return false end
    local ok, data = pcall(function() return HttpService:JSONDecode(Compat.readfile(path)) end)
    if not ok then return false end
    for flag, v in pairs(data) do
        local opt = self.Options[flag]
        if opt then
            if type(v) == "table" and v.__enum then v = Enum.KeyCode[v.__enum] elseif type(v) == "table" and v.__c3 then v = Color3.new(v.__c3[1], v.__c3[2], v.__c3[3]) end
            pcall(function() opt:Set(v) end)
        end
    end
    return true
end

function Nebula:DeleteConfig(name)
    if not name then return false end
    local path = self.ConfigFolder .. "/" .. name .. ".json"
    if not Compat.isfile(path) then return false end
    return Compat.delfile(path)
end

function Nebula:SetAutoLoad(name)
    local path = self.ConfigFolder .. "/autoload.txt"
    Compat.makefolder(self.ConfigFolder)
    if name and name ~= "" then
        return (Compat.writefile(path, name))
    end
    if Compat.isfile(path) then Compat.delfile(path) end
    return true
end

function Nebula:GetAutoLoad()
    local path = self.ConfigFolder .. "/autoload.txt"
    if Compat.isfile(path) then
        local n = Compat.readfile(path)
        if n and n ~= "" then return n end
    end
end

function Nebula:LoadAuto()
    local n = self:GetAutoLoad()
    return n and self:LoadConfig(n) or false
end

function Nebula:Unload()
    self._unloaded = true
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self._conns, self._themed, self._refresh = {}, {}, {}
    for i = #ANIM, 1, -1 do ANIM[i] = nil end
    self._animConn = nil
    if self._gui then self._gui:Destroy() end
    if self._blurFx then self._blurFx:Destroy(); self._blurFx = nil end
    self._tip = nil
    self._gui = nil
    self._locks = {}
    pcall(function() ContextActionService:UnbindAction("NebulaSink") end)
    self._sinking = false
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
    local sh = sheen(row, 90, 200)
    local st = stroke(row, "Stroke", 1, 0.5)
    bevelGrad(st)
    local pop = create("UIScale", { Parent = row })
    ROWPOP[row] = pop
    local pip = create("Frame", {
        AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 0, 0, (height > 0 and height or 34) / 2),
        Size = UDim2.fromOffset(2, 0), BorderSizePixel = 0, ZIndex = 3, LayoutOrder = -1, Parent = row,
    })
    bind(pip, "BackgroundColor3", "Accent")
    row.MouseEnter:Connect(function()
        tween(st, 0.18, { Color = resolve("Accent"), Transparency = 0.3 })
        tween(pip, 0.25, { Size = UDim2.fromOffset(2, 16) }, Enum.EasingStyle.Back)
        tween(pop, 0.3, { Scale = 1.01 }, Enum.EasingStyle.Back)
    end)
    row.MouseMoved:Connect(function(x)
        -- the light direction follows the cursor -> surface looks tilted toward it
        local rel = math.clamp((x - row.AbsolutePosition.X) / math.max(row.AbsoluteSize.X, 1), 0, 1)
        sh.Rotation = 90 + (rel - 0.5) * 70 * Nebula.Depth
    end)
    row.MouseLeave:Connect(function()
        tween(st, 0.2, { Color = resolve("Stroke"), Transparency = 0.5 })
        tween(pip, 0.2, { Size = UDim2.fromOffset(2, 0) })
        tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
        tween(sh, 0.35, { Rotation = 90 })
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

---------------------------------------------------------------- Button (3D keycap)
function Section:AddButton(o)
    local obj = { Type = "Button" }
    local wrap = create("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = self.Body })
    -- extruded base (the "side" of the key)
    local base = create("Frame", {
        Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0, ZIndex = 1, Parent = wrap,
    })
    bind(base, "BackgroundColor3", "Element")
    corner(base, 8)
    local baseGlow = stroke(base, "Stroke", 1, 0.35)
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = WHITE, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", ClipsDescendants = true, ZIndex = 2, Parent = wrap,
    })
    corner(btn, 8)
    gradient(btn, "BtnGrad").Rotation = 90
    local bst, _, bh = glowStroke(btn, 1.2, 70, 0.6, { idle = true, gate = gateOf(self) })
    local bs = create("UIScale", { Parent = btn })
    local shade = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn })
    corner(shade, 8)
    -- top specular edge (light hits the upper lip of the key)
    local lip = create("Frame", { Position = UDim2.fromOffset(8, 1), Size = UDim2.new(1, -16, 0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 3, Parent = btn })
    local shine = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(0, -40, .5, 0), Size = UDim2.new(0, 24, 2.4, 0),
        Rotation = 20, BackgroundColor3 = WHITE, BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 2, Parent = btn,
    })
    local l = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = o.Name or "Button",
        TextColor3 = WHITE, TextSize = 13, Font = Enum.Font.GothamBold, ZIndex = 4, Parent = btn,
    })
    local sc = self.Tab.Window._scaleObj
    local FACE = {
        rest  = UDim2.fromOffset(0, 0),
        hover = UDim2.fromOffset(0, -1),
        press = UDim2.fromOffset(0, 3),
    }
    btn.MouseEnter:Connect(function()
        bh.entry.on = true
        tween(btn, 0.2, { Position = FACE.hover }, Enum.EasingStyle.Back)
        tween(shade, 0.2, { BackgroundTransparency = 0.94 })
        tween(bst, 0.2, { Transparency = 0 })
        tween(baseGlow, 0.2, { Transparency = 0.1 })
        shine.Position = UDim2.new(0, -40, .5, 0)
        tween(shine, 0.7, { Position = UDim2.new(1, 40, .5, 0) }, Enum.EasingStyle.Quad)
    end)
    btn.MouseMoved:Connect(function(x, y)
        -- label drifts opposite to the cursor -> parallax inside the key
        local rx = math.clamp((x - btn.AbsolutePosition.X) / math.max(btn.AbsoluteSize.X, 1), 0, 1)
        local ry = math.clamp((y - btn.AbsolutePosition.Y) / math.max(btn.AbsoluteSize.Y, 1), 0, 1)
        l.Position = UDim2.fromOffset(-(rx - 0.5) * 6 * Nebula.Depth, -(ry - 0.5) * 4 * Nebula.Depth)
    end)
    btn.MouseLeave:Connect(function()
        bh.entry.on = false
        tween(btn, 0.3, { Position = FACE.rest }, Enum.EasingStyle.Back)
        tween(bs, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
        tween(shade, 0.2, { BackgroundTransparency = 1 })
        tween(bst, 0.25, { Transparency = 0.6 })
        tween(baseGlow, 0.25, { Transparency = 0.35 })
        tween(l, 0.25, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
    end)
    btn.MouseButton1Down:Connect(function(x)
        tween(btn, 0.06, { Position = FACE.press }, Enum.EasingStyle.Quad)
        tween(shade, 0.08, { BackgroundTransparency = 0.8 })
        tween(bs, 0.1, { Scale = 0.975 })
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
    btn.MouseButton1Up:Connect(function()
        tween(btn, 0.4, { Position = FACE.hover }, Enum.EasingStyle.Back)
    end)
    btn.MouseButton1Click:Connect(function()
        tween(bs, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
        tween(shade, 0.15, { BackgroundTransparency = 0.94 })
        Nebula:_sfx("Click")
        if o.Callback then task.spawn(o.Callback) end
    end)
    addTip(btn, o.Tooltip)
    function obj:SetText(s) l.Text = s end
    function obj:SetVisible(b) wrap.Visible = b end
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
    -- sphere shading + specular dot
    create("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(150, 150, 150)), Rotation = 90, Parent = knob })
    stroke(knob, "Bg", 1, 0.3)
    local spec = create("Frame", { Position = UDim2.fromOffset(3, 2), Size = UDim2.fromOffset(5, 3), BackgroundColor3 = WHITE, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = knob })
    corner(spec, 2)
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
    click.MouseButton1Click:Connect(function() Nebula:_sfx("Toggle"); obj:Set(not obj.Value) end)
    addTip(click, o.Tooltip); pressDepth(click, row)
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
    create("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(165, 165, 165)), Rotation = 90, Parent = knob })
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

    addTip(hit, o.Tooltip)
    local dragging = false
    local function fromInput(pos)
        local a = math.clamp((pos.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        obj:Set(min + (max - min) * a)
    end
    local hovering, sTrack = false, nil
    local function knobSize(n) tween(knob, 0.2, { Size = UDim2.fromOffset(n, n) }, Enum.EasingStyle.Back) end
    hit.MouseEnter:Connect(function() hovering = true; if not dragging then knobSize(15) end end)
    hit.MouseLeave:Connect(function() hovering = false; if not dragging then knobSize(12) end end)
    hit.InputBegan:Connect(function(i)
        if isPress(i) and not dragging then
            dragging = true; sTrack = i
            knobSize(18)
            tween(halo, 0.3, { Size = UDim2.fromOffset(36, 36) }, Enum.EasingStyle.Back)
            tween(v, 0.15, { TextColor3 = resolve("Accent"), TextSize = 14 })
            self.Tab.Page.ScrollingEnabled = false
            fromInput(i.Position)
        end
    end)
    connect(UserInputService.InputChanged, function(i) if dragging and ownsMove(sTrack, i) then fromInput(i.Position) end end)
    connect(UserInputService.InputEnded, function(i)
        if dragging and ownsEnd(sTrack, i) then
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
    addTip(box, o.Tooltip)
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

    addTip(btn, o.Tooltip); pressDepth(btn, row)
    btn.MouseButton1Click:Connect(function() Nebula:_sfx("Click"); obj.Listening = true; render() end)
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
    local arrow = drawIcon(head, "down", { size = 12, color = "SubText", pos = UDim2.new(1, -16, .5, 0), thick = 2 })

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
        Nebula:_sfx("Click")
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

    local lastH
    local function cascadeItems()
        local n = 0
        for _, k in ipairs(obj.Options) do
            local it = items[k]
            if it then
                n = n + 1
                it[2].TextTransparency = 1
                it[2].Position = UDim2.fromOffset(-8, 0)
                task.delay(0.03 * n, function()
                    tween(it[2], 0.3, { TextTransparency = 0, Position = UDim2.fromOffset(8, 0) }, Enum.EasingStyle.Back)
                end)
            end
        end
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
            lastH = h
            cascadeItems()
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
            wrap.Size = UDim2.new(1, 0, 0, lastH or wrap.AbsoluteSize.Y / sc)
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

    addTip(head, o.Tooltip); pressDepth(head, root)
    head.MouseButton1Click:Connect(function() Nebula:_sfx("Click"); obj:Toggle() end)
    head.ClipsDescendants = true
    corner(head, 8)
    head.MouseButton1Down:Connect(function(x) ripple(head, x, dsec.Tab.Window._scaleObj, 0.9) end)
    register(obj, o); build()
    return obj
end

---------------------------------------------------------------- Progress
function Section:AddProgress(o)
    o = o or {}
    local min, max = o.Min or 0, o.Max or 100
    local obj = { Type = "Progress", Value = math.clamp(o.Default or min, min, max) }
    local row = newRow(self, 44)
    local l = text(row, o.Name or "Progress", 13)
    l.Position = UDim2.fromOffset(10, 6); l.Size = UDim2.new(1, -90, 0, 16)
    local v = text(row, "", 12, "SubText", Enum.Font.GothamBold)
    v.AnchorPoint = Vector2.new(1, 0); v.Position = UDim2.new(1, -10, 0, 6)
    v.Size = UDim2.fromOffset(80, 16); v.TextXAlignment = Enum.TextXAlignment.Right

    local track = create("Frame", { Position = UDim2.new(0, 10, 0, 29), Size = UDim2.new(1, -20, 0, 8), BorderSizePixel = 0, Parent = row })
    bind(track, "BackgroundColor3", "Panel")
    corner(track, 4)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ClipsDescendants = true, Parent = track })
    corner(fill, 4)
    gradient(fill, "AccentGrad")
    -- moving gloss inside the filled part
    local gloss = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(-.3, .5), Size = UDim2.new(0, 30, 3, 0),
        Rotation = 20, BackgroundColor3 = WHITE, BackgroundTransparency = 0.65, BorderSizePixel = 0, Parent = fill,
    })
    animate(track, function(t) gloss.Position = UDim2.fromScale((t * 0.7) % 1.8 - 0.3, .5) end, gateOf(self))

    local function render(anim)
        local a = (obj.Value - min) / math.max(max - min, 1e-9)
        tween(fill, anim and 0.5 or 0, { Size = UDim2.fromScale(a, 1) }, Enum.EasingStyle.Quint)
        v.Text = (o.Percent == false) and (tostring(math.floor(obj.Value * 100 + 0.5) / 100) .. (o.Suffix or ""))
            or (math.floor(a * 100 + 0.5) .. "%")
    end
    function obj:Set(x, silent)
        x = tonumber(x); if not x then return end
        obj.Value = math.clamp(x, min, max)
        render(true); changed(obj, o, silent)
    end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) row.Visible = b end
    addTip(row, o.Tooltip)
    register(obj, o); render(false)
    return obj
end

---------------------------------------------------------------- Segment (sliding pill)
function Section:AddSegment(o)
    o = o or {}
    local opts = o.Options or {}
    local obj = { Type = "Segment", Value = o.Default or opts[1] }
    local row = newRow(self, 62)
    local l = text(row, o.Name or "Segment", 13)
    l.Position = UDim2.fromOffset(10, 5); l.Size = UDim2.new(1, -20, 0, 16)

    local bar = create("Frame", { Position = UDim2.fromOffset(10, 27), Size = UDim2.new(1, -20, 0, 28), BorderSizePixel = 0, Parent = row })
    bind(bar, "BackgroundColor3", "Panel")
    corner(bar, 8)
    local n = math.max(#opts, 1)
    local pill = create("Frame", { Position = UDim2.new(0, 2, 0, 2), Size = UDim2.new(1 / n, -4, 1, -4), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = bar })
    corner(pill, 6)
    gradient(pill, "AccentGrad").Rotation = 90

    local btns = {}
    for i, k in ipairs(opts) do
        local b = create("TextButton", {
            Position = UDim2.new((i - 1) / n, 0, 0, 0), Size = UDim2.new(1 / n, 0, 1, 0), BackgroundTransparency = 1,
            Text = tostring(k), TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, ZIndex = 3, Parent = bar,
        })
        btns[i] = { b, k }
        b.MouseButton1Click:Connect(function() Nebula:_sfx("Click"); obj:Set(k) end)
        addTip(b, o.Tooltip)
    end
    local function render(anim)
        local idx = 1
        for i, e in ipairs(btns) do if e[2] == obj.Value then idx = i end end
        tween(pill, anim and 0.45 or 0, { Position = UDim2.new((idx - 1) / n, 2, 0, 2) }, Enum.EasingStyle.Back)
        if anim then
            -- squash & stretch while travelling
            pill.Size = UDim2.new(1 / n, 4, 1, -4)
            tween(pill, 0.4, { Size = UDim2.new(1 / n, -4, 1, -4) }, Enum.EasingStyle.Back)
        end
        for i, e in ipairs(btns) do
            tween(e[1], 0.25, { TextColor3 = i == idx and Color3.fromRGB(10, 10, 12) or resolve("SubText") })
        end
    end
    onTheme(function() render(false) end)
    function obj:Set(v, silent) obj.Value = v; render(true); changed(obj, o, silent) end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) row.Visible = b end
    register(obj, o); render(false)
    return obj
end

---------------------------------------------------------------- Color picker
function Section:AddColorPicker(o)
    o = o or {}
    local def = o.Default or Color3.fromRGB(255, 255, 255)
    local obj = { Type = "ColorPicker", Value = def, Open = false }
    local h, s, v = def:ToHSV()

    local root = newRow(self, 34)
    root.AutomaticSize = Enum.AutomaticSize.Y
    create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = root })
    local head = create("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", LayoutOrder = 1, Parent = root })
    local l = text(head, o.Name or "Color", 13)
    l.Position = UDim2.fromOffset(10, 0); l.Size = UDim2.new(1, -120, 1, 0)
    local hex = text(head, "", 11, "SubText", Enum.Font.Code)
    hex.AnchorPoint = Vector2.new(1, 0); hex.Position = UDim2.new(1, -54, 0, 0)
    hex.Size = UDim2.fromOffset(70, 34); hex.TextXAlignment = Enum.TextXAlignment.Right
    local sw = create("Frame", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -10, .5, 0), Size = UDim2.fromOffset(34, 18), BackgroundColor3 = def, BorderSizePixel = 0, Parent = head })
    corner(sw, 6)
    stroke(sw, "Accent", 1, 0.5)
    local swScale = create("UIScale", { Parent = sw })

    local H = 112
    local wrap = create("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true, Visible = false, LayoutOrder = 2, Parent = root })

    local svBox = create("Frame", { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 78), BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, Parent = wrap })
    corner(svBox, 6)
    local white = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = svBox })
    corner(white, 6)
    create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
    local black = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, Parent = svBox })
    corner(black, 6)
    create("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
    local cur = create("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = svBox })
    corner(cur, 7)
    create("UIStroke", { Thickness = 2, Color = WHITE, Parent = cur })

    local hue = create("Frame", { Position = UDim2.fromOffset(10, 92), Size = UDim2.new(1, -20, 0, 12), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = wrap })
    corner(hue, 6)
    local kps = {}
    for i = 0, 6 do kps[#kps + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
    create("UIGradient", { Color = ColorSequence.new(kps), Parent = hue })
    local hknob = create("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(6, 16), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = hue })
    corner(hknob, 3)
    stroke(hknob, "Bg", 1, 0)

    local function refresh(silent)
        local c = Color3.fromHSV(h, s, v)
        obj.Value = c
        svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        cur.Position = UDim2.fromScale(s, 1 - v)
        hknob.Position = UDim2.fromScale(h, .5)
        sw.BackgroundColor3 = c
        hex.Text = "#" .. c:ToHex():upper()
        changed(obj, o, silent)
    end

    local dragSV, dragH, cTrack = false, false, nil
    local function svFrom(pos)
        s = math.clamp((pos.X - svBox.AbsolutePosition.X) / math.max(svBox.AbsoluteSize.X, 1), 0, 1)
        v = 1 - math.clamp((pos.Y - svBox.AbsolutePosition.Y) / math.max(svBox.AbsoluteSize.Y, 1), 0, 1)
        refresh()
    end
    local function hFrom(pos)
        h = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(hue.AbsoluteSize.X, 1), 0, 1)
        refresh()
    end
    local svHit = create("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = svBox })
    local hHit = create("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = hue })
    svHit.InputBegan:Connect(function(i)
        if isPress(i) and not (dragSV or dragH) then
            dragSV = true; cTrack = i; self.Tab.Page.ScrollingEnabled = false
            tween(cur, 0.2, { Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
            svFrom(i.Position)
        end
    end)
    hHit.InputBegan:Connect(function(i)
        if isPress(i) and not (dragSV or dragH) then
            dragH = true; cTrack = i; self.Tab.Page.ScrollingEnabled = false
            tween(hknob, 0.2, { Size = UDim2.fromOffset(8, 20) }, Enum.EasingStyle.Back)
            hFrom(i.Position)
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if (dragSV or dragH) and ownsMove(cTrack, i) then
            if dragSV then svFrom(i.Position) elseif dragH then hFrom(i.Position) end
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if (dragSV or dragH) and ownsEnd(cTrack, i) then
            dragSV, dragH = false, false
            self.Tab.Page.ScrollingEnabled = true
            tween(cur, 0.25, { Size = UDim2.fromOffset(10, 10) }, Enum.EasingStyle.Back)
            tween(hknob, 0.25, { Size = UDim2.fromOffset(6, 16) }, Enum.EasingStyle.Back)
        end
    end)

    function obj:Toggle(state)
        if state == nil then state = not obj.Open end
        obj.Open = state
        tween(swScale, 0.35, { Scale = state and 1.18 or 1 }, Enum.EasingStyle.Back)
        if state then
            wrap.Visible = true
            tween(wrap, 0.38, { Size = UDim2.new(1, 0, 0, H) }, Enum.EasingStyle.Quint)
        else
            tween(wrap, 0.28, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint).Completed:Connect(function()
                if not obj.Open then wrap.Visible = false end
            end)
        end
    end
    function obj:Set(c, silent)
        if typeof(c) ~= "Color3" then return end
        h, s, v = c:ToHSV()
        refresh(silent)
    end
    function obj:Get() return obj.Value end
    function obj:SetVisible(b) root.Visible = b end

    head.ClipsDescendants = true
    corner(head, 8)
    head.MouseButton1Down:Connect(function(x) ripple(head, x, self.Tab.Window._scaleObj, 0.9) end)
    head.MouseButton1Click:Connect(function() Nebula:_sfx("Click"); obj:Toggle() end)
    addTip(head, o.Tooltip); pressDepth(head, root)
    register(obj, o); refresh(true)
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

    drawIcon(row, "check", { size = 11, color = Status.Success[1], anchor = Vector2.new(0, .5), pos = UDim2.fromOffset(76, 59), thick = 1.8 })
    local badge = create("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(92, 52), Size = UDim2.new(1, -206, 0, 14),
        Text = "Verified  ·  " .. (o.Subtitle or o.Link or ""), TextColor3 = Status.Success[1], TextSize = 10,
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
        local copied = o.Link ~= nil and Compat.copy(o.Link)
        btnL.Text = copied and "COPIED!" or "SEE LINK"
        Nebula:Notify({
            Title = copied and "Link copied" or "Clipboard not supported", Content = o.Link or "",
            Type = copied and "Success" or "Warning", Duration = copied and 2.5 or 6,
        })
        task.delay(1.6, function() btnL.Text = "COPY LINK" end)
        if o.Callback then task.spawn(o.Callback) end
    end)
    -- YouTube + Discord cards under the owner card (o.Socials = false to hide, o.YouTube / o.Discord = link | false)
    local rows = { row }
    if o.Socials ~= false then
        local yt = o.YouTube == nil and "https://youtube.com/@yqantg" or o.YouTube
        local dc = o.Discord == nil and "https://discord.gg/yurKERvexU" or o.Discord
        if yt then rows[#rows + 1] = self:AddSocial({ Kind = "YouTube", Link = yt, Image = o.YouTubeImage }).Row end
        if dc then rows[#rows + 1] = self:AddSocial({ Kind = "Discord", Link = dc, Image = o.DiscordImage }).Row end
    end
    return { Type = "Owner", SetVisible = function(_, b) for _, r in ipairs(rows) do r.Visible = b end end }
end

-- same ping the Roblox performance HUD shows (Stats.PerformanceStats.Ping), with fallbacks
local function readPing()
    local Stats = game:GetService("Stats")
    local ok, v = pcall(function()
        local ps = Stats:FindFirstChild("PerformanceStats")
        if not ps then return nil end
        for _, n in ipairs({ "Ping", "NetworkPing" }) do
            local it = ps:FindFirstChild(n)
            if it then return it:GetValue() end
        end
    end)
    if ok and type(v) == "number" and v > 0 then return v end
    ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    if ok and type(v) == "number" and v > 0 then return v end
    ok, v = pcall(function() return LocalPlayer:GetNetworkPing() * 2000 end)
    if ok and type(v) == "number" then return v end
    return 0
end

---------------------------------------------------------------- Social card (YouTube / Discord)
-- o.Kind = "YouTube" | "Discord" · o.Link · o.Title · o.Subtitle · o.Image = id | url (banner / avatar, optional)
local function playShape(parent, w, h, color, z)
    local holder = create("Frame", {
        BackgroundTransparency = 1, AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.53, .5),
        Size = UDim2.fromOffset(w, h), ZIndex = z, Parent = parent,
    })
    local n = 14
    for i = 0, n - 1 do
        local mid = (i + 0.5) / n
        local frac = 1 - math.abs(mid - 0.5) * 2
        create("Frame", {
            Position = UDim2.fromScale(0, i / n), Size = UDim2.new(frac, 0, 1 / n, 1),
            BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z, Parent = holder,
        })
    end
end

function Section:AddSocial(o)
    o = o or {}
    local isYT = tostring(o.Kind or "YouTube"):lower():find("you", 1, true) ~= nil
    local brand = isYT and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(88, 101, 242)
    local link = o.Link or (isYT and "https://youtube.com/@yqantg" or "https://discord.gg/yurKERvexU")
    local row = newRow(self, 88)

    local thumb = create("Frame", {
        Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(104, 64), BackgroundColor3 = WHITE,
        BorderSizePixel = 0, ClipsDescendants = true, Parent = row,
    })
    corner(thumb, 10)
    local tg = create("UIGradient", {
        Color = ColorSequence.new(brand:Lerp(BLACK, 0.45), Color3.fromRGB(12, 12, 14)), Rotation = 35, Parent = thumb,
    })
    animate(thumb, function(t) tg.Rotation = 35 + math.sin(t * 1.2) * 20 end, gateOf(self))
    local glow = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(90, 58),
        BackgroundColor3 = brand, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 1, Parent = thumb,
    })
    corner(glow, 18)
    local logo = create("Frame", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1,
        Size = UDim2.fromOffset(64, 46), ZIndex = 2, Parent = thumb,
    })
    if isYT then
        local plate = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(58, 40),
            BackgroundColor3 = Color3.fromRGB(255, 0, 0), BorderSizePixel = 0, ZIndex = 2, Parent = logo,
        })
        corner(plate, 12)
        playShape(plate, 15, 17, WHITE, 3)
    else
        local head = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(48, 34),
            BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = logo,
        })
        corner(head, 14)
        for _, x in ipairs({ .32, .68 }) do
            local eye = create("Frame", {
                AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(x, .46), Size = UDim2.fromOffset(7, 11),
                BackgroundColor3 = brand, BorderSizePixel = 0, ZIndex = 3, Parent = head,
            })
            corner(eye, 4)
        end
    end
    -- optional real picture (banner / avatar) fades in over the drawn logo
    local pic = create("ImageLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop,
        ImageTransparency = 1, ZIndex = 4, Parent = thumb,
    })
    if o.Image ~= nil and o.Image ~= false then
        Nebula:_image(o.Image, function(asset)
            if not pic.Parent then return end
            pic.Image = asset
            tween(pic, 0.4, { ImageTransparency = 0 })
            logo.Visible = false; glow.Visible = false
        end)
    end

    local tag = text(row, isYT and "YOUTUBE" or "DISCORD", 9, "SubText", Enum.Font.GothamBold)
    tag.Position = UDim2.fromOffset(130, 13); tag.Size = UDim2.new(1, -234, 0, 12)
    local name = text(row, o.Title or (isYT and "@yqantg" or "Yqantg Community"), 18, "Text", Enum.Font.GothamBlack)
    name.Position = UDim2.fromOffset(130, 26); name.Size = UDim2.new(1, -234, 0, 24)
    local sub = text(row, o.Subtitle or (isYT and "Subscribe for updates" or "Join the community"), 10, "SubText", Enum.Font.GothamMedium)
    sub.Position = UDim2.fromOffset(130, 54); sub.Size = UDim2.new(1, -234, 0, 14)

    local btn = create("TextButton", {
        AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -12, .5, 0), Size = UDim2.fromOffset(86, 30),
        BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = "", ClipsDescendants = true, Parent = row,
    })
    corner(btn, 8)
    gradient(btn, "BtnGrad").Rotation = 90
    local _, _, bh = glowStroke(btn, 1.2, 70, 0.35, { idle = true, gate = gateOf(self) })
    local btnL = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "COPY LINK", ZIndex = 4,
        TextColor3 = WHITE, TextSize = 11, Font = Enum.Font.GothamBold, Parent = btn,
    })
    btn.MouseEnter:Connect(function() bh.entry.on = true; tween(btn, 0.2, { Size = UDim2.fromOffset(92, 32) }, Enum.EasingStyle.Back) end)
    btn.MouseLeave:Connect(function() bh.entry.on = false; tween(btn, 0.2, { Size = UDim2.fromOffset(86, 30) }, Enum.EasingStyle.Back) end)
    btn.MouseButton1Click:Connect(function()
        local copied = Compat.copy(link)
        btnL.Text = copied and "COPIED!" or "SEE LINK"
        Nebula:Notify({
            Title = copied and (isYT and "YouTube link copied" or "Discord link copied") or "Clipboard not supported",
            Content = link, Type = copied and "Success" or "Warning", Duration = copied and 2.5 or 6,
        })
        task.delay(1.6, function() btnL.Text = "COPY LINK" end)
        if o.Callback then task.spawn(o.Callback) end
    end)
    return { Type = "Social", Row = row, SetVisible = function(_, b) row.Visible = b end }
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
            local ping = math.floor(readPing() + 0.5)
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

-- sections rise out of the page one after another (scale + Back easing)
function Tab:_cascade(delay0)
    self._ctok = (self._ctok or 0) + 1
    local my = self._ctok
    local list = self._secs or {}
    for i, sc in ipairs(list) do
        sc.Scale = 0.9
        task.delay((delay0 or 0) + (i - 1) * 0.07, function()
            if my == self._ctok then tween(sc, 0.6, { Scale = 1 }, Enum.EasingStyle.Back) end
        end)
    end
    task.delay((delay0 or 0) + #list * 0.07 + 0.8, function()
        if my == self._ctok then for _, sc in ipairs(list) do sc.Scale = 1 end end
    end)
end

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
    if self.Window and self.Window._panels then
        table.insert(self.Window._panels, { frame = frame, clear = o.NoHeader == true })
        if self.Window._glass and not o.NoHeader then self.Window:_glass() end
    end
    corner(frame, 10)
    local fst = stroke(frame, "Stroke", 1, 0.5)
    bevelGrad(fst)
    sheen(frame, 90, 185)
    local fscale = create("UIScale", { Parent = frame })
    self._secs = self._secs or {}
    self._secs[#self._secs + 1] = fscale
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
        arrow = drawIcon(head, "down", { size = 12, color = WHITE, pos = UDim2.new(1, -16, .5, 0), thick = 2 })
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

    -- Root holds the whole 3D stack: shadows -> slabs -> face (Main)
    local Root = create("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(.5, .5), Position = cfg.Position or UDim2.fromScale(.5, .5),
        Size = fs, BackgroundTransparency = 1, Parent = gui,
    })
    local shFar  = softShadow(Root, { offset = 16, spread = 76, transparency = 0.5, z = 0 })
    local shNear = softShadow(Root, { offset = 5, spread = 28, transparency = 0.35, z = 0 })
    local slab2 = create("Frame", { Position = UDim2.fromOffset(8, 13), Size = UDim2.new(1, -16, 1, 0), BorderSizePixel = 0, ZIndex = 1, Parent = Root })
    bind(slab2, "BackgroundColor3", "Panel")
    corner(slab2, 12)
    local slab = create("Frame", { Position = UDim2.fromOffset(0, 7), Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 1, Parent = Root })
    bind(slab, "BackgroundColor3", "Side")
    corner(slab, 12)
    local Main = create("CanvasGroup", { Name = "Face", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = Root })
    bind(Main, "BackgroundColor3", "Bg")
    corner(Main, 12)
    local bgImg = create("ImageLabel", {
        Name = "Background", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0,
        ScaleType = Enum.ScaleType.Crop, ImageTransparency = 1, Visible = false, Parent = Main,
    })
    corner(bgImg, 12)
    local mainSheen = sheen(Main, 65, 150)

    -- depth machinery: introV (0..1 = how "deployed" the stack is), liftV (drag lift)
    local introV = create("NumberValue", { Value = 1, Parent = Root })
    local liftV  = create("NumberValue", { Value = 0, Parent = Root })
    local par = { x = 0, y = 0 }
    local function applyDepth()
        local k, f, lf = Nebula.Depth, math.clamp(introV.Value, 0, 1.25), liftV.Value
        slab.Position  = UDim2.fromOffset(-par.x * 5 * k, (7 + lf) * k * f)
        slab2.Position = UDim2.fromOffset(8 - par.x * 10 * k, (13 + lf * 1.8) * k * f)
        slab.BackgroundTransparency  = math.clamp(1 - f, 0, 1)
        slab2.BackgroundTransparency = math.clamp(1 - f * 0.6, 0, 1)
        shNear.Position = UDim2.new(.5, -par.x * 8 * k, .5, (5 + lf * 0.6 - par.y * 4) * k)
        shFar.Position  = UDim2.new(.5, -par.x * 18 * k, .5, (16 + lf - par.y * 6) * k)
        shNear.ImageTransparency = math.clamp(1 - 0.65 * f * math.min(k, 1), 0, 1)
        shFar.ImageTransparency  = math.clamp(1 - 0.5 * f * math.min(k, 1), 0, 1)
    end
    introV.Changed:Connect(applyDepth)
    liftV.Changed:Connect(applyDepth)
    applyDepth()

    -- cursor parallax: layers slide against each other, specular light follows the mouse
    local ptx, pty = 0, 0
    animate(Root, function()
        if Nebula.Parallax and not touchOnly() then
            local m = UserInputService:GetMouseLocation()
            local c = Root.AbsolutePosition + Root.AbsoluteSize / 2
            ptx = math.clamp((m.X - c.X) / math.max(Root.AbsoluteSize.X, 1), -1, 1)
            pty = math.clamp((m.Y - c.Y) / math.max(Root.AbsoluteSize.Y, 1), -1, 1)
        else
            ptx, pty = 0, 0
        end
        par.x = par.x + (ptx - par.x) * 0.28
        par.y = par.y + (pty - par.y) * 0.28
        mainSheen.Rotation = 65 + par.x * 24 * Nebula.Depth
        applyDepth()
    end, vgate)

    -- auto-fit to small screens
    local base = 1
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        base = math.clamp(math.min(vp.X / (fs.X.Offset + 40), vp.Y / (fs.Y.Offset + 40)), 0.5, 1)
    end
    local scale = create("UIScale", { Scale = base, Parent = Root })
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
    -- settings gear: centre of the top bar. hover = metallic black/white sheen + spin, hold = fast spin + glow
    local panelOpen, setPanel = false, nil

    local function buildGear(parent, px, color, z)
        local k = px / 26
        local holder = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(px, px),
            BackgroundTransparency = 1, ZIndex = z, Parent = parent,
        })
        for n = 0, 7 do
            local a = math.rad(n * 45)
            local tooth = create("Frame", {
                AnchorPoint = Vector2.new(.5, .5),
                Position = UDim2.new(.5, math.sin(a) * 9.4 * k, .5, -math.cos(a) * 9.4 * k),
                Size = UDim2.fromOffset(4.4 * k, 4 * k), Rotation = n * 45, BorderSizePixel = 0, ZIndex = z, Parent = holder,
            })
            create("UICorner", { CornerRadius = UDim.new(0, 1.2 * k), Parent = tooth })
            paintTo(tooth, "BackgroundColor3", color)
        end
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(9 * k, 9 * k),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z, Parent = holder,
        })
        create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
        local st = create("UIStroke", { Thickness = 3.2 * k, Parent = ring })
        paintTo(st, "Color", color)
        return holder
    end

    local gearBtn = create("TextButton", {
        AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromOffset(32, 32),
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", ClipsDescendants = true, Parent = top,
    })
    bind(gearBtn, "BackgroundColor3", "Element")
    corner(gearBtn, 16)
    local metal = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2, Parent = gearBtn,
    })
    local metalG = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(0.3, Color3.fromRGB(150, 150, 158)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(248, 248, 250)),
            ColorSequenceKeypoint.new(0.8, Color3.fromRGB(112, 112, 120)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
        }), Rotation = 45, Parent = metal,
    })
    local gear = buildGear(gearBtn, 26, WHITE, 3)
    local gStroke, _, gSpin = glowStroke(gearBtn, 1.4, 80, 0.45, { idle = true, gate = vgate })

    local hovering, holding, holdTrack = false, false, nil
    local spinV, spinR, lastT = 0, 0, os.clock()
    local function applyGear()
        local active = hovering or holding or panelOpen
        tween(metal, 0.28, { BackgroundTransparency = holding and 0 or (active and 0.1 or 1) })
        iconTween(gear, 0.2, active and BLACK or WHITE)
        tween(gStroke, 0.25, { Thickness = holding and 2.8 or 1.4, Transparency = active and 0 or 0.45 })
        gSpin.entry.on = active
        local sz = holding and 28 or (hovering and 37 or 32)
        tween(gearBtn, 0.3, { Size = UDim2.fromOffset(sz, sz) }, Enum.EasingStyle.Back)
    end
    animate(gearBtn, function(t)
        local dt = math.min(t - lastT, 0.1); lastT = t
        local target = holding and 540 or (hovering and 110 or (panelOpen and 34 or 0))
        spinV = spinV + (target - spinV) * math.min(dt * 6, 1)
        spinR = (spinR + spinV * dt) % 360
        gear.Rotation = spinR
        metalG.Rotation = (t * (holding and 330 or 130)) % 360
    end, vgate)
    gearBtn.MouseEnter:Connect(function() hovering = true; applyGear() end)
    gearBtn.MouseLeave:Connect(function() hovering = false; applyGear() end)
    gearBtn.InputBegan:Connect(function(i)
        if isPress(i) and not holdTrack then holdTrack = i; holding = true; applyGear() end
    end)
    connect(UserInputService.InputEnded, function(i)
        if holdTrack and ownsEnd(holdTrack, i) then
            holdTrack = nil; holding = false
            if i.UserInputType == Enum.UserInputType.Touch then hovering = false end
            applyGear()
        end
    end)
    gearBtn.MouseButton1Click:Connect(function()
        Nebula:_sfx("Click")
        if setPanel then setPanel(not panelOpen) end
    end)

    closeBtn.MouseEnter:Connect(function() tween(closeBtn, .15, { BackgroundColor3 = WHITE }); cx.TextColor3 = Color3.new(0, 0, 0) end)
    closeBtn.MouseLeave:Connect(function() tween(closeBtn, .15, { BackgroundColor3 = resolve("Element") }); cx.TextColor3 = resolve("SubText") end)

    makeDraggable(top, Root, function() return scale.Scale end, nil, "full")
    -- window "lifts" off the surface while dragging, drops back with a bounce
    local lifted, liftTrack = false, nil
    top.InputBegan:Connect(function(i)
        if isPress(i) and not lifted then
            lifted = true; liftTrack = i
            tween(glow, 0.2, { Thickness = 3.4 })
            tween(liftV, 0.25, { Value = 12 }, Enum.EasingStyle.Quint)
            tween(scale, 0.25, { Scale = Window._scale * 1.02 }, Enum.EasingStyle.Quint)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if lifted and ownsEnd(liftTrack, i) then
            lifted = false
            tween(glow, 0.35, { Thickness = 2 })
            tween(liftV, 0.55, { Value = 0 }, Enum.EasingStyle.Bounce)
            tween(scale, 0.45, { Scale = Window._scale }, Enum.EasingStyle.Back)
        end
    end)

    -- shimmering line under the topbar
    local line = create("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = top })
    local lineG = gradient(line, "GlowGrad")
    animate(line, function(t) lineG.Offset = Vector2.new(math.sin(t * 1.1) * 0.7, 0) end, vgate)

    ------------------------------------------------ body
    local Body = create("CanvasGroup", { Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -TOP), BackgroundTransparency = 1, Parent = Main })

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

    -- 3D resize grip
    local grip = create("TextButton", {
        AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1, Text = "", ZIndex = 40, Parent = Main,
    })
    local gripIcon = drawIcon(grip, "grip", { size = 12, color = "SubText", z = 41, thick = 1.6 })
    local gripScale = create("UIScale", { Parent = grip })
    grip.MouseEnter:Connect(function()
        iconTween(gripIcon, 0.2, resolve("Accent"))
        tween(gripScale, 0.25, { Scale = 1.3 }, Enum.EasingStyle.Back)
    end)
    grip.MouseLeave:Connect(function()
        iconTween(gripIcon, 0.2, resolve("SubText"))
        tween(gripScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
    end)
    local rz
    grip.InputBegan:Connect(function(i)
        if isPress(i) and not Window.Minimized and not rz then
            rz = { track = i, p = i.Position, w = fs.X.Offset, h = fs.Y.Offset, pos = Root.Position }
            tween(liftV, 0.2, { Value = 8 })
        end
    end)
    connect(UserInputService.InputChanged, function(i)
        if rz and ownsMove(rz.track, i) then
            local sc = scale.Scale
            local d = i.Position - rz.p
            local nw = math.clamp(rz.w + d.X / sc, 420, 1100)
            local nh = math.clamp(rz.h + d.Y / sc, 270, 760)
            fs = UDim2.fromOffset(nw, nh)
            Root.Size = fs
            -- keep the top-left corner pinned (Root is centre-anchored)
            Root.Position = UDim2.new(rz.pos.X.Scale, rz.pos.X.Offset + (nw - rz.w) / 2, rz.pos.Y.Scale, rz.pos.Y.Offset + (nh - rz.h) / 2)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if rz and ownsEnd(rz.track, i) then
            rz = nil
            tween(liftV, 0.45, { Value = 0 }, Enum.EasingStyle.Bounce)
        end
    end)

    search:GetPropertyChangedSignal("Text"):Connect(function()
        local q = search.Text:lower()
        for _, t in ipairs(Window.Tabs) do
            t.Button.Visible = q == "" or t.Name:lower():find(q, 1, true) ~= nil
        end
    end)

    ------------------------------------------------ settings panel (opens from the gear)
    local PW = 296
    local refreshers = {}
    local scrim = create("TextButton", {
        Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -TOP), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, Visible = false, ZIndex = 28, Parent = Main,
    })
    local panel = create("CanvasGroup", {
        AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, TOP + 10), Size = UDim2.fromOffset(PW, 300),
        BorderSizePixel = 0, Visible = false, ZIndex = 30, Parent = Main,
    })
    bind(panel, "BackgroundColor3", "Side")
    corner(panel, 14)
    sheen(panel, 70, 150)
    glowStroke(panel, 1.4, 60, 0.15, { gate = function() return panelOpen end })

    -- header
    local hIcon = create("Frame", {
        Position = UDim2.fromOffset(12, 9), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 31, Parent = panel,
    })
    corner(hIcon, 9)
    local hg = gradient(hIcon, "AccentGrad")
    local hGear = buildGear(hIcon, 20, BLACK, 32)
    animate(panel, function(t)
        hg.Rotation = 45 + math.sin(t * 1.5) * 40
        hGear.Rotation = (t * 40) % 360
    end, function() return panelOpen end)
    local hTitle = text(panel, "Settings", 15, "Text", Enum.Font.GothamBold)
    hTitle.Position = UDim2.fromOffset(50, 6); hTitle.Size = UDim2.new(1, -96, 0, 18); hTitle.ZIndex = 31
    local hTg = gradient(hTitle, "TextGrad")
    animate(hTitle, function(t) hTg.Offset = Vector2.new(math.sin(t * 1.2) * 0.55, 0) end, function() return panelOpen end)
    local hSub = text(panel, "Customize your interface", 10, "SubText", Enum.Font.Gotham)
    hSub.Position = UDim2.fromOffset(50, 24); hSub.Size = UDim2.new(1, -96, 0, 14); hSub.ZIndex = 31
    local pClose = create("TextButton", {
        AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -10, 0, 22), Size = UDim2.fromOffset(26, 26),
        BorderSizePixel = 0, AutoButtonColor = false, Text = "", ZIndex = 31, Parent = panel,
    })
    bind(pClose, "BackgroundColor3", "Element")
    corner(pClose, 8)
    local pcx = drawIcon(pClose, "cross", { size = 11, color = "SubText", z = 32, thick = 1.8 })
    pClose.MouseEnter:Connect(function() tween(pClose, 0.15, { BackgroundColor3 = WHITE }); iconTween(pcx, 0.15, BLACK) end)
    pClose.MouseLeave:Connect(function() tween(pClose, 0.15, { BackgroundColor3 = resolve("Element") }); iconTween(pcx, 0.15, resolve("SubText")) end)
    local sep = create("Frame", { Position = UDim2.fromOffset(0, 43), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, ZIndex = 31, Parent = panel })
    bind(sep, "BackgroundColor3", "Stroke")

    local scroll = create("ScrollingFrame", {
        Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(150, 150, 158), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 31, Parent = panel,
    })
    create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = scroll })
    create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

    local cardOrder, rowN = 0, setmetatable({}, { __mode = "k" })
    local function nextLO(c) rowN[c] = (rowN[c] or 0) + 1; return rowN[c] end
    local function card(title)
        cardOrder = cardOrder + 1
        local c = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
            LayoutOrder = cardOrder, ZIndex = 32, Parent = scroll,
        })
        bind(c, "BackgroundColor3", "Element")
        corner(c, 10)
        stroke(c, "Stroke", 1, 0.55)
        create("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = c })
        create("UIListLayout", { Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
        if title then
            local h = text(c, title, 10, "SubText", Enum.Font.GothamBold)
            h.Size = UDim2.new(1, 0, 0, 12); h.LayoutOrder = nextLO(c); h.ZIndex = 33
        end
        return c
    end

    local function pct(v) return math.floor(v * 100 + 0.5) .. "%" end

    local function toggleRow(c, label, get, set)
        local r = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
            LayoutOrder = nextLO(c), ZIndex = 33, Parent = c,
        })
        local tl = text(r, label, 12, "Text"); tl.Size = UDim2.new(1, -50, 1, 0); tl.ZIndex = 34
        local tr = create("Frame", { AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, 0, .5, 0), Size = UDim2.fromOffset(36, 20), BorderSizePixel = 0, ZIndex = 34, Parent = r })
        corner(tr, 10)
        local kn = create("Frame", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 3, .5, 0), Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, ZIndex = 35, Parent = tr })
        corner(kn, 7)
        local function render()
            local on = get()
            tween(tr, 0.2, { BackgroundColor3 = on and WHITE or resolve("Panel") })
            tween(kn, 0.3, {
                Position = on and UDim2.new(1, -17, .5, 0) or UDim2.new(0, 3, .5, 0),
                BackgroundColor3 = on and BLACK or resolve("SubText"),
            }, Enum.EasingStyle.Back)
        end
        onTheme(render); render()
        refreshers[#refreshers + 1] = render
        r.MouseButton1Click:Connect(function() set(not get()); render(); Nebula:_sfx("Toggle") end)
    end

    -- slider: follows only the finger that started on it (multi-touch safe), scroll is paused while dragging
    local function sliderRow(c, label, lo, hi, step, get, set, fmt, commitOnRelease)
        local r = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = nextLO(c), ZIndex = 33, Parent = c })
        local tl = text(r, label, 12, "Text"); tl.Size = UDim2.new(1, -60, 0, 16); tl.ZIndex = 34
        local vl = text(r, "", 11, "Accent", Enum.Font.GothamBold)
        vl.Size = UDim2.fromOffset(56, 16); vl.Position = UDim2.new(1, -56, 0, 0); vl.TextXAlignment = Enum.TextXAlignment.Right; vl.ZIndex = 34
        local hit = create("TextButton", {
            Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, ZIndex = 34, Parent = r,
        })
        local track = create("Frame", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 0, .5, 0), Size = UDim2.new(1, 0, 0, 6), BorderSizePixel = 0, ZIndex = 34, Parent = hit })
        bind(track, "BackgroundColor3", "Panel")
        corner(track, 3)
        local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 35, Parent = track })
        corner(fill, 3)
        gradient(fill, "AccentGrad")
        local knob = create("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(0, .5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 36, Parent = track })
        corner(knob, 8)
        create("UIStroke", { Thickness = 2, Color = BLACK, Transparency = 0.55, Parent = knob })
        local kscale = create("UIScale", { Parent = knob })

        local shown
        local function show(v)
            shown = v
            local a = math.clamp((v - lo) / (hi - lo), 0, 1)
            fill.Size = UDim2.fromScale(a, 1)
            knob.Position = UDim2.fromScale(a, .5)
            vl.Text = fmt(v)
        end
        local function render() show(get()) end
        render()
        refreshers[#refreshers + 1] = render

        local tracked, gx, gw
        local function valueAt(x)
            local a = math.clamp((x - gx) / math.max(gw, 1), 0, 1)
            return math.clamp(math.floor((lo + a * (hi - lo)) / step + 0.5) * step, lo, hi)
        end
        local function drag(x)
            local v = valueAt(x)
            show(v)
            if not commitOnRelease then set(v) end
        end
        local function finish()
            if not tracked then return end
            tracked = nil
            scroll.ScrollingEnabled = true
            tween(kscale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
            if commitOnRelease and shown ~= nil then set(shown); render() end
        end
        hit.InputBegan:Connect(function(i)
            if isPress(i) and not tracked then
                tracked = i
                gx, gw = track.AbsolutePosition.X, track.AbsoluteSize.X
                scroll.ScrollingEnabled = false
                tween(kscale, 0.15, { Scale = 1.25 }, Enum.EasingStyle.Back)
                drag(i.Position.X)
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End and tracked == i then finish() end
                end)
            end
        end)
        connect(UserInputService.InputChanged, function(i) if tracked and ownsMove(tracked, i) then drag(i.Position.X) end end)
        connect(UserInputService.InputEnded, function(i) if tracked and ownsEnd(tracked, i) then finish() end end)
    end

    local function buttonRow(c, label, fn)
        local b = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = WHITE, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            ClipsDescendants = true, LayoutOrder = nextLO(c), ZIndex = 33, Parent = c,
        })
        corner(b, 8)
        gradient(b, "BtnGrad").Rotation = 90
        local _, _, bh = glowStroke(b, 1.2, 70, 0.4, { idle = true, gate = function() return panelOpen end })
        local l = create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = label, ZIndex = 35,
            TextColor3 = WHITE, TextSize = 11, Font = Enum.Font.GothamBold, Parent = b,
        })
        b.MouseEnter:Connect(function() bh.entry.on = true end)
        b.MouseLeave:Connect(function() bh.entry.on = false end)
        b.MouseButton1Down:Connect(function(x) ripple(b, x, scale, 0.82) end)
        b.MouseButton1Click:Connect(function() Nebula:_sfx("Click"); fn() end)
        return b
    end

    local function setScale(s)
        Window._scale = math.clamp(math.floor(s * 20 + 0.5) / 20, 0.5, 1.5)
        scale.Scale = Window._scale
    end

    -- THEME (chips)
    local themeNames = {}
    for n in pairs(self.Themes) do themeNames[#themeNames + 1] = n end
    table.sort(themeNames)
    local themeCard = card("THEME")
    local chipRow = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = nextLO(themeCard), ZIndex = 33, Parent = themeCard })
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chipRow })
    local nT = math.max(#themeNames, 1)
    local themeBtns = {}
    for idx, n in ipairs(themeNames) do
        local b = create("TextButton", {
            Size = UDim2.new(1 / nT, -(6 * (nT - 1)) / nT, 1, 0), BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            LayoutOrder = idx, ZIndex = 34, Parent = chipRow,
        })
        bind(b, "BackgroundColor3", "Panel")
        corner(b, 8)
        local dot = create("Frame", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 8, .5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = self.Themes[n].Accent, BorderSizePixel = 0, ZIndex = 35, Parent = b })
        corner(dot, 5)
        create("UIStroke", { Thickness = 1, Color = Color3.fromRGB(120, 120, 128), Transparency = 0.4, Parent = dot })
        local tl = text(b, n, 11, "Text"); tl.Position = UDim2.fromOffset(24, 0); tl.Size = UDim2.new(1, -26, 1, 0); tl.ZIndex = 35
        themeBtns[n] = stroke(b, "Accent", 1.4, 1)
        b.MouseButton1Click:Connect(function() Nebula:_sfx("Click"); Nebula:SetTheme(n) end)
    end
    local function renderThemes() for n, st in pairs(themeBtns) do st.Transparency = (n == Nebula.CurrentTheme) and 0.05 or 1 end end
    onTheme(renderThemes); renderThemes()

    -- INTERFACE
    local uiCard = card("INTERFACE")
    sliderRow(uiCard, "UI scale", 0.5, 1.5, 0.05, function() return Window._scale end, setScale, pct, true)
    sliderRow(uiCard, "3D depth", 0, 1.5, 0.05, function() return Nebula.Depth end, function(v) Nebula:SetDepth(v) end, pct)
    toggleRow(uiCard, "3D parallax", function() return Nebula.Parallax end, function(b) Nebula.Parallax = b end)
    toggleRow(uiCard, "Backdrop blur", function() return Nebula.BlurEnabled end, function(b) Nebula.BlurEnabled = b; Nebula:_syncBlur() end)
    toggleRow(uiCard, "Tooltips", function() return Nebula.Tooltips ~= false end, function(b) Nebula.Tooltips = b end)

    -- BACKGROUND
    local bgCard = card("BACKGROUND")
    sliderRow(bgCard, "Image opacity", 0, 1, 0.05, function() return 1 - (Window._bgAlpha or 0.6) end,
        function(v) Window:SetBackgroundTransparency(1 - v) end, pct)
    buttonRow(bgCard, "NEW RANDOM BACKGROUND", function()
        if not Compat.canAssets then
            Nebula:Notify({ Title = "Images unavailable", Content = "This executor can't load web images.", Type = "Warning" })
            return
        end
        Nebula.AnimeIcons = true
        Window:SetBackground("anime")
    end)
    buttonRow(bgCard, "REMOVE BACKGROUND", function() Window:SetBackground(false) end)

    -- SOUND & INPUT
    local sndCard = card("SOUND & INPUT")
    toggleRow(sndCard, "Sound cues", function() return Nebula.SoundEnabled end, function(b) Nebula.SoundEnabled = b end)
    sliderRow(sndCard, "Volume", 0, 1.5, 0.05, function() return Nebula.SoundVolume or 1 end, function(v) Nebula.SoundVolume = v end, pct)
    toggleRow(sndCard, "Block camera drag", function() return Nebula.BlockInput end, function(b) Nebula.BlockInput = b; Nebula:_lock("refresh", false) end)

    -- RESET + info
    local defaults = {
        theme = self.CurrentTheme, scale = base, depth = Nebula.Depth, par = Nebula.Parallax, blur = Nebula.BlurEnabled,
        snd = Nebula.SoundEnabled, vol = Nebula.SoundVolume or 1, block = Nebula.BlockInput, tips = Nebula.Tooltips ~= false, bg = 0.6,
    }
    local function resetAll()
        Nebula:SetTheme(defaults.theme)
        setScale(defaults.scale)
        Nebula:SetDepth(defaults.depth)
        Nebula.Parallax = defaults.par
        Nebula.BlurEnabled = defaults.blur; Nebula:_syncBlur()
        Nebula.SoundEnabled = defaults.snd
        Nebula.SoundVolume = defaults.vol
        Nebula.BlockInput = defaults.block; Nebula:_lock("refresh", false)
        Nebula.Tooltips = defaults.tips
        Window:SetBackgroundTransparency(defaults.bg)
        for _, f in ipairs(refreshers) do f() end
    end
    local footCard = card(nil)
    buttonRow(footCard, "RESET ALL SETTINGS", resetAll)
    local sup = Compat.report()
    local function onoff(b) return b and "on" or "off" end
    local credit = text(footCard, (cfg.Brand or "Nebula UI") .. "  ·  v" .. self.Version, 10, "SubText", Enum.Font.GothamBold)
    credit.Size = UDim2.new(1, 0, 0, 12); credit.LayoutOrder = nextLO(footCard); credit.TextXAlignment = Enum.TextXAlignment.Center; credit.ZIndex = 33
    local info = text(footCard, ("%s  ·  files %s  ·  images %s  ·  clipboard %s"):format(sup.Executor, onoff(sup.Files), onoff(sup.Assets), onoff(sup.Clipboard)), 9, "SubText", Enum.Font.Gotham)
    info.Size = UDim2.new(1, 0, 0, 24); info.LayoutOrder = nextLO(footCard); info.TextXAlignment = Enum.TextXAlignment.Center
    info.TextWrapped = true; info.TextYAlignment = Enum.TextYAlignment.Top; info.ZIndex = 33

    -- open / close
    local pscale = create("UIScale", { Scale = 1, Parent = panel })
    local ptok = 0
    setPanel = function(state)
        if state == panelOpen then return end
        panelOpen = state
        ptok = ptok + 1
        local my = ptok
        if state then
            panel.Size = UDim2.fromOffset(PW, math.clamp(fs.Y.Offset - TOP - 22, 160, 430))
            panel.GroupTransparency = 1; pscale.Scale = 0.55
            panel.Position = UDim2.new(.5, 0, 0, TOP - 6)
            panel.Visible = true; scrim.Visible = true
            scroll.CanvasPosition = Vector2.new(0, 0)
            tween(panel, 0.25, { GroupTransparency = 0 })
            tween(panel, 0.5, { Position = UDim2.new(.5, 0, 0, TOP + 10) }, Enum.EasingStyle.Back)
            tween(pscale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
        else
            scrim.Visible = false
            tween(panel, 0.18, { GroupTransparency = 1 })
            tween(pscale, 0.2, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(panel, 0.2, { Position = UDim2.new(.5, 0, 0, TOP) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.21, function() if my == ptok then panel.Visible = false end end)
        end
        applyGear()
    end
    scrim.MouseButton1Click:Connect(function() setPanel(false) end)
    pClose.MouseButton1Click:Connect(function() Nebula:_sfx("Click"); setPanel(false) end)

    ------------------------------------------------ window methods (3D open / close)
    local popItems = {}
    for _, b in ipairs({ avatar, closeBtn, minBtn, gearBtn }) do
        popItems[#popItems + 1] = create("UIScale", { Parent = b })
    end

    local restPos
    local tok = 0

    local function intro()
        tok = tok + 1
        local my = tok
        restPos = restPos or Root.Position
        Root.Visible = true
        -- start state: low, tilted, small, transparent, stack collapsed
        Root.Position = UDim2.new(restPos.X.Scale, restPos.X.Offset, restPos.Y.Scale, restPos.Y.Offset + 60)
        Root.Rotation = -9
        scale.Scale = Window._scale * 0.78
        Main.GroupTransparency = 1
        introV.Value = 0
        glow.Thickness = 0.5
        for _, p in ipairs(popItems) do p.Scale = 0 end
        title.TextTransparency = 1; subtitle.TextTransparency = 1
        -- fly in
        tween(Main, 0.45, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
        tween(scale, 0.75, { Scale = Window._scale }, Enum.EasingStyle.Back)
        tween(Root, 0.8, { Rotation = 0, Position = restPos }, Enum.EasingStyle.Back)
        tween(introV, 0.9, { Value = 1 }, Enum.EasingStyle.Back)
        tween(glow, 0.8, { Thickness = 2 })
        Nebula:_syncBlur()
        Nebula:_sfx("Open")
        -- staggered pop-in of top bar / tabs / sections
        for i, p in ipairs(popItems) do
            task.delay(0.22 + i * 0.06, function() if my == tok then tween(p, 0.5, { Scale = 1 }, Enum.EasingStyle.Back) end end)
        end
        task.delay(0.3, function()
            if my == tok then
                tween(title, 0.4, { TextTransparency = 0 }); tween(subtitle, 0.5, { TextTransparency = 0 })
            end
        end)
        task.spawn(function()
            RunService.Heartbeat:Wait()
            if my ~= tok then return end
            for i, t in ipairs(Window.Tabs) do
                t.Label.TextTransparency = 1
                task.delay(0.3 + i * 0.06, function()
                    if my == tok and t.Label.Parent then tween(t.Label, 0.4, { TextTransparency = 0 }) end
                end)
            end
            if Window.ActiveTab then Window.ActiveTab:_cascade(0.3) end
        end)
    end

    local function outro()
        Nebula:_lock("hover" .. tostring(Window), false)
        tok = tok + 1
        local my = tok
        restPos = Root.Position
        setPanel(false)
        tween(Main, 0.32, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(scale, 0.38, { Scale = Window._scale * 0.82 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        tween(Root, 0.38, {
            Rotation = 7,
            Position = UDim2.new(restPos.X.Scale, restPos.X.Offset, restPos.Y.Scale, restPos.Y.Offset + 50),
        }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        tween(introV, 0.32, { Value = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(glow, 0.3, { Thickness = 0.5 })
        Nebula:_syncBlur()
        Nebula:_sfx("Close")
        task.delay(0.42, function()
            if my ~= tok then return end
            Root.Visible = false
            Root.Rotation = 0
            Root.Position = restPos
            scale.Scale = Window._scale
        end)
    end

    function Window:Toggle(state)
        if state == nil then state = not Window.Visible end
        if state == Window.Visible then return end
        Window.Visible = state
        if state then intro() else outro() end
    end

    -- minimize: collapses to a floating top bar (bobs in the air, drag it anywhere);
    -- restore: the window flies back to the exact spot it had before minimizing
    local savedPos
    animate(Main, function(t)
        Main.Position = UDim2.fromOffset(0, math.sin(t * 2.2) * 3)
        Main.Rotation = math.sin(t * 1.6) * 1.4
    end, function() return Window.Minimized end)

    function Window:Minimize()
        Window.Minimized = not Window.Minimized
        Nebula:_syncBlur()   -- minimized = no blur, restored = blur again
        setPanel(false)
        Nebula:_sfx("Click")
        grip.Visible = not Window.Minimized
        if Window.Minimized then
            savedPos = Root.Position
            tween(liftV, 0.25, { Value = 12 })
            task.delay(0.3, function() tween(liftV, 0.6, { Value = 0 }, Enum.EasingStyle.Bounce) end)
            tween(Body, 0.2, { GroupTransparency = 1 })
            task.delay(0.12, function()
                if Window.Minimized then
                    tween(Root, 0.5, { Size = UDim2.fromOffset(fs.X.Offset, TOP) }, Enum.EasingStyle.Back)
                end
            end)
            task.delay(0.2, function() if Window.Minimized then Body.Visible = false end end)
        else
            Body.Visible = true
            Root.Rotation = -6
            tween(Main, 0.4, { Position = UDim2.fromOffset(0, 0), Rotation = 0 }, Enum.EasingStyle.Quad)
            tween(liftV, 0.25, { Value = 14 })
            task.delay(0.3, function() tween(liftV, 0.6, { Value = 0 }, Enum.EasingStyle.Bounce) end)
            -- float back to the old place while growing back to full size
            tween(Root, 0.75, { Size = fs, Position = savedPos or Root.Position, Rotation = 0 }, Enum.EasingStyle.Back)
            task.delay(0.3, function()
                if not Window.Minimized then
                    tween(Body, 0.35, { GroupTransparency = 0 })
                    if Window.ActiveTab then Window.ActiveTab:_cascade(0) end
                end
            end)
        end
    end

    function Window:Close()
        if Window._closing then return end
        Window._closing = true
        Window.Visible = false
        outro()
        task.delay(0.5, function() Window:Destroy() end)
    end

    function Window:Destroy()
        if Window._orb then Window._orb:Destroy() end
        Root:Destroy()
        for i = #Nebula.Windows, 1, -1 do if Nebula.Windows[i] == Window then table.remove(Nebula.Windows, i) end end
        Nebula:_lock("hover" .. tostring(Window), false)
        Nebula:_lock("press" .. tostring(Window), false)
        Nebula:_syncBlur()
    end
    function Window:SetTitle(s, sub) title.Text = s or title.Text; if sub then subtitle.Text = "●  " .. sub end end
    function Window:Notify(o) Nebula:Notify(o) end

    -- background image (id / url / "anime"); transparency 0 = solid image, 1 = invisible
    Window._bgAlpha = 0.6
    Window._panels = {}
    function Window:_glass()
        local on = bgImg.Visible
        for _, p in ipairs(Window._panels) do
            if p.frame.Parent then p.frame.BackgroundTransparency = p.clear and 1 or (on and 0.35 or 0) end
        end
        side.BackgroundTransparency = on and 0.25 or 0
        top.BackgroundTransparency  = on and 0.25 or 0
    end
    function Window:SetBackgroundTransparency(t)
        Window._bgAlpha = math.clamp(tonumber(t) or 0.6, 0, 1)
        if bgImg.Visible then tween(bgImg, 0.25, { ImageTransparency = Window._bgAlpha }) end
        if Window._bgLabel then Window._bgLabel.Text = math.floor((1 - Window._bgAlpha) * 100 + 0.5) .. "%" end
    end
    function Window:SetBackground(src, transparency)
        if transparency ~= nil then Window:SetBackgroundTransparency(transparency) end
        if not src then
            bgImg.Visible = false; bgImg.Image = ""; Window:_glass(); return
        end
        Nebula:_image(src, function(asset)
            if not bgImg.Parent then return end
            bgImg.Image = asset
            bgImg.Visible = true
            bgImg.ImageTransparency = 1
            Window:_glass()
            tween(bgImg, 0.5, { ImageTransparency = Window._bgAlpha })
        end)
    end

    minBtn.MouseButton1Click:Connect(function() Window:Minimize() end)
    closeBtn.MouseButton1Click:Connect(function() Window:Close() end)

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
        local letter = create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 51,
            Text = (cfg.Title or "N"):sub(1, 1):upper(), TextColor3 = WHITE, TextSize = 20,
            Font = Enum.Font.GothamBlack, Parent = orb,
        })
        local orbPic = create("ImageLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 51, ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Crop, Parent = orb,
        })
        corner(orbPic, 22)
        Nebula:_image(cfg.ToggleIcon ~= nil and cfg.ToggleIcon or Nebula.Icons.Orb, function(asset)
            if not orbPic.Parent then return end
            orbPic.Image = asset
            tween(orbPic, 0.4, { ImageTransparency = 0 })
            tween(letter, 0.3, { TextTransparency = 1 })
        end)
        local os_ = create("UIStroke", { Thickness = 1.5, Color = WHITE, Parent = orb })
        local og = gradient(os_, "GlowGrad")
        animate(orb, function(t) og.Rotation = (t * 90) % 360 end)
        local osc = create("UIScale", { Parent = orb })
        -- glossy sphere highlight
        local hl = create("Frame", {
            Position = UDim2.fromOffset(9, 5), Size = UDim2.fromOffset(18, 9), BackgroundColor3 = WHITE,
            BackgroundTransparency = 0.78, BorderSizePixel = 0, Rotation = -28, ZIndex = 52, Parent = orb,
        })
        corner(hl, 100)
        animate(orb, function(t) hl.BackgroundTransparency = 0.78 + math.sin(t * 2) * 0.08 end)
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
        makeDraggable(orb, orb, nil, function(d) moved = math.max(moved, math.abs(d.X) + math.abs(d.Y)) end, "full")
        orb.InputBegan:Connect(function(i) if isPress(i) then moved = 0 end end)
        local spinT = 0
        orb.MouseButton1Click:Connect(function()
            if moved < 8 then
                spinT = spinT + 360
                tween(orb, 0.7, { Rotation = spinT }, Enum.EasingStyle.Back)
                Window:Toggle()
            end
        end)
        Window._orb = orb
    end

    ------------------------------------------------ tabs
    function Window:SelectTab(tab)
        local prev = Window.ActiveTab
        local dir = (prev and prev ~= tab and tab.Index < prev.Index) and -1 or 1
        for _, t in ipairs(Window.Tabs) do
            local on = t == tab
            tween(t.Label, 0.25, { TextColor3 = on and WHITE or resolve("SubText"), Position = UDim2.fromOffset(on and 18 or 14, 0) })
            t.Arrow.Visible = on
            if not on and t ~= prev then t.Group.Visible = false end
        end
        if prev ~= tab then
            Nebula:_sfx("Click")
            if prev then
                prev._tok = (prev._tok or 0) + 1
                local my = prev._tok
                tween(prev.Group, 0.22, { GroupTransparency = 1, Position = UDim2.fromOffset(-dir * 44, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                task.delay(0.24, function()
                    if prev._tok == my and Window.ActiveTab ~= prev then prev.Group.Visible = false end
                end)
            end
            tab._tok = (tab._tok or 0) + 1
            tab.Group.Position = UDim2.fromOffset(dir * 44, 0)
            tab.Group.GroupTransparency = 1
            tab.Group.Visible = true
            tween(tab.Group, 0.5, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
            tab:_cascade(0.05)
        else
            tab.Group.Visible = true
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
                    tween(indicator, 0.5, { Position = UDim2.fromOffset(6, y) }, Enum.EasingStyle.Back)
                    -- stretch while travelling, then settle
                    tween(indicator, 0.14, { Size = UDim2.new(1, -12, 0, 42) }, Enum.EasingStyle.Quad)
                    task.delay(0.14, function() tween(indicator, 0.4, { Size = UDim2.new(1, -12, 0, 32) }, Enum.EasingStyle.Back) end)
                end
            end
        end)
    end
    onTheme(function() if Window.ActiveTab then Window:SelectTab(Window.ActiveTab) end end)

    function Window:AddTab(o)
        if type(o) == "string" then o = { Name = o } end
        local tab = setmetatable({ Name = o.Name or "Tab", Locked = o.Locked == true, Window = Window, Index = #Window.Tabs + 1 }, Tab)

        local b = create("TextButton", {
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = WHITE, BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = #Window.Tabs + 1, Parent = tabList,
        })
        corner(b, 8)
        b.ClipsDescendants = true
        local lab = text(b, tab.Name, 13, "SubText", Enum.Font.GothamMedium)
        lab.Position = UDim2.fromOffset(14, 0); lab.Size = UDim2.new(1, -44, 1, 0)
        local arrow = drawIcon(b, "right", { size = 11, color = WHITE, pos = UDim2.new(1, -14, .5, 0), thick = 2 })
        arrow.Visible = false
        if tab.Locked then
            drawIcon(b, "lock", { size = 13, color = Color3.fromRGB(240, 175, 60), pos = UDim2.new(1, -15, .5, 0), thick = 1.6 })
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
                Nebula:Notify({ Title = "Config saved", Content = tostring(n) .. (Compat.canFiles and "" or "  (this session only)"), Type = "Success" })
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
        sec:AddButton({ Name = "Delete", Callback = function()
            if list.Value and Nebula:DeleteConfig(list.Value) then
                Nebula:Notify({ Title = "Config deleted", Content = tostring(list.Value), Type = "Warning" })
                list:Set(nil, true)
                list:SetOptions(Nebula:ListConfigs())
            else
                Nebula:Notify({ Title = "Delete failed", Content = "Pick a saved config first.", Type = "Error" })
            end
        end })
        local auto = Nebula:GetAutoLoad()
        local autoLbl = sec:AddLabel(auto and ("Auto-load: " .. auto) or "Auto-load: off")
        sec:AddButton({ Name = "Set as auto-load", Callback = function()
            local n = list.Value
            if n and Nebula:SetAutoLoad(n) then
                autoLbl:Set("Auto-load: " .. tostring(n))
                Nebula:Notify({ Title = "Auto-load", Content = tostring(n), Type = "Success" })
            else
                Nebula:Notify({ Title = "Auto-load failed", Content = "Pick a saved config first.", Type = "Warning" })
            end
        end })
        sec:AddButton({ Name = "Clear auto-load", Callback = function()
            Nebula:SetAutoLoad(nil); autoLbl:Set("Auto-load: off")
        end })
        return tab
    end

    -- block camera / game input while the pointer is over this window
    local hoverKey, pressKey = "hover" .. tostring(Window), "press" .. tostring(Window)
    local function inside(pos)
        local p, sz = Root.AbsolutePosition, Root.AbsoluteSize
        return Window.Visible and pos.X >= p.X and pos.X <= p.X + sz.X and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y
    end
    local hovering = false
    animate(Root, function()
        local h = (not touchOnly()) and inside(UserInputService:GetMouseLocation())
        if h ~= hovering then hovering = h; Nebula:_lock(hoverKey, h) end
    end)
    local pressed = {}   -- every finger that started on this window; unlock when all are up
    connect(UserInputService.InputBegan, function(i)
        if isPress(i) and inside(Vector2.new(i.Position.X, i.Position.Y)) then
            pressed[i] = true; Nebula:_lock(pressKey, true)
        end
    end)
    connect(UserInputService.InputEnded, function(i)
        if pressed[i] then
            pressed[i] = nil
            if next(pressed) == nil then Nebula:_lock(pressKey, false) end
        end
    end)

    if cfg.Background then
        local bg = cfg.Background
        if type(bg) == "table" and bg.Image == nil and bg[1] == nil then bg = { Image = "anime" } end
        if type(bg) == "table" and bg.Image ~= nil then
            Window:SetBackground(bg.Image, bg.Transparency)
        else
            Window:SetBackground(bg)
        end
    end

    -- entrance: same 3D choreography as re-opening the window
    Window.Root = Root
    intro()

    return Window
end

Nebula.Compat = Compat
-- what this executor supports: { Executor, Files, Assets, Http, Clipboard, HiddenUI, CloneRef }
function Nebula:GetSupport() return Compat.report() end

return Nebula
