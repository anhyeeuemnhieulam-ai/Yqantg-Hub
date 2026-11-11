--[[ Yqantg Hub · example.lua — one of every component the library has ]]

local Yqantg = loadstring(game:HttpGet("https://raw.githubusercontent.com/anhyeeuemnhieulam-ai/Yqantg-Hub/refs/heads/main/source.lua"))()
-- local file instead:  loadstring(readfile("Yqantg/source.lua"))()

local LocalPlayer = game:GetService("Players").LocalPlayer

-- optional settings ---------------------------------------------------------
-- Yqantg.BlockInput = true            -- sink camera/game input while over the UI (default on)
-- Yqantg.Icons.Notify = "rbxassetid://123"   -- id | url | {list} | false   (default: random anime girl)
-- Yqantg.Icons.Orb    = { "https://...png", 456789 }

-- cinematic intro: warp streaks, gyro logo, glitch title, segmented loader, shockwave exit
Yqantg:Splash({ Title = "YQANTG", Subtitle = "UI Library", Steps = { "loading modules", "building interface", "ready" }, Duration = 3 })

local Window = Yqantg:CreateWindow({
    Title        = "Yqantg Hub",
    Subtitle     = LocalPlayer.Name,
    Size         = UDim2.fromOffset(600, 380),
    ToggleKey    = Enum.KeyCode.RightShift,
    ToggleButton = true,                                   -- floating orb (anime image)
    Dust         = true,                                   -- floating space-dust particles behind the content
    Background   = { Image = "anime", Transparency = 0.6 },-- image id | url | "anime" ; 0 = solid, 1 = hidden
    -- Background = { Image = 1234567890, Transparency = 0.5 },
})
-- later:  Window:SetBackground(id, 0.4)   Window:SetBackgroundTransparency(0.7)   Window:SetBackground(nil)

----------------------------------------------------------------------
local Main = Window:AddTab("Main")

local Cards = Main:AddSection({ Side = "Full", NoHeader = true })
Cards:AddProfile()
Cards:AddOwner({ Name = "Yqantg Hub", Subtitle = "Official owner", Link = "https://github.com/anhyeeuemnhieulam-ai/Yqantg-Hub" })
Cards:AddStats()

local Basic = Main:AddSection({ Name = "Basic", Side = "Left" })
Basic:AddLabel("Label")
Basic:AddParagraph({ Title = "Paragraph", Content = "Title + wrapped text." })
Basic:AddDivider()
Basic:AddButton({
    Name = "Button", Tooltip = "Tooltip works on every element",
    Callback = function() Yqantg:Notify({ Title = "Hello", Content = "Button clicked.", Type = "Success" }) end,
})
Basic:AddToggle({ Name = "Toggle", Flag = "Toggle", Default = false, Callback = function(on) print("Toggle", on) end })

local Values = Main:AddSection({ Name = "Values", Side = "Right" })
Values:AddSlider({ Name = "Slider", Flag = "Slider", Min = 0, Max = 100, Default = 25, Increment = 1, Callback = function(v) print("Slider", v) end })
Values:AddInput({ Name = "Input", Flag = "Text", Placeholder = "Type...", Callback = function(s) print("Text", s) end })
Values:AddInput({ Name = "Numeric input", Flag = "Num", Default = "12", Numeric = true, Callback = function(n) print("Num", n) end })
Values:AddKeybind({ Name = "Keybind", Flag = "Key", Default = Enum.KeyCode.H, Callback = function() print("Key pressed") end })

----------------------------------------------------------------------
local More = Window:AddTab("More")

local Pick = More:AddSection({ Name = "Pickers", Side = "Left" })
Pick:AddDropdown({ Name = "Dropdown", Flag = "Mode", Options = { "Normal", "Fast", "Smooth" }, Default = "Normal", Callback = function(v) print("Mode", v) end })
Pick:AddDropdown({ Name = "Multi dropdown", Flag = "Targets", Multi = true, Options = { "Players", "NPCs", "Items" }, Default = { "Players" }, Callback = function(map) for k in pairs(map) do print("selected", k) end end })
Pick:AddSegment({ Name = "Segment", Flag = "Quality", Options = { "Low", "Medium", "High" }, Default = "Medium", Callback = function(v) print("Quality", v) end })
Pick:AddColorPicker({ Name = "Color picker", Flag = "Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(c) print("Color", c) end })

local Misc = More:AddSection({ Name = "Misc (collapsed)", Side = "Right", Collapsed = true })
local Bar = Misc:AddProgress({ Name = "Progress", Flag = "Progress", Default = 35, NoSave = true })
Misc:AddButton({ Name = "Animate progress", Callback = function() for i = 0, 100, 5 do Bar:Set(i); task.wait(0.05) end end })
Misc:AddButton({ Name = "Warning", Callback = function() Yqantg:Notify({ Title = "Careful", Content = "Something looks off.", Type = "Warning" }) end })
Misc:AddButton({ Name = "Error",   Callback = function() Yqantg:Notify({ Title = "Error", Content = "Access denied.", Type = "Error" }) end })

----------------------------------------------------------------------
local Dev = Window:AddTab("Dev")

local Rng = Dev:AddSection({ Name = "Range & Alpha", Side = "Left" })
Rng:AddRangeSlider({ Name = "Range slider", Flag = "Range", Min = 0, Max = 100, DefaultMin = 20, DefaultMax = 70, Callback = function(a, b) print("Range", a, b) end })
Rng:AddColorPicker({ Name = "Color + alpha", Flag = "ColorA", Default = Color3.fromRGB(120, 200, 255), AlphaDefault = 0.8, Callback = function(c, a) print("Color", c, "alpha", a) end })
Rng:AddButton({
    Name = "Notify with buttons",
    Callback = function()
        Yqantg:Notify({
            Title = "Clean memory?", Content = "Free RAM and flush caches now.", Duration = 8, Type = "Info",
            Buttons = { { Text = "Clean", Callback = function() Yqantg:Clean() end }, { Text = "Later" } },
        })
    end,
})

local Fx = Dev:AddSection({ Name = "Effects", Side = "Left" })
Fx:AddToggle({ Name = "Space dust", Flag = "Dust", Default = true, Callback = function(on) Window:EnableDustParticles(on) end })
Fx:AddToggle({ Name = "RGB flow (rainbow accent)", Flag = "RGB", Default = false, NoSave = true, Callback = function(on) Yqantg:ToggleRGBFlow(on) end })
Fx:AddToggle({ Name = "Parallax", Flag = "Parallax", Default = Yqantg.Parallax, Callback = function(on) Yqantg.Parallax = on end })
Fx:AddToggle({ Name = "Backdrop blur", Flag = "Blur", Default = Yqantg.BlurEnabled, Callback = function(on) Yqantg.BlurEnabled = on; Yqantg:_syncBlur() end })
Fx:AddDropdown({ Name = "Theme", Flag = "Theme", Options = { "Obsidian", "Eclipse", "Graphite" }, Default = "Obsidian", Callback = function(v) Yqantg:SetTheme(v) end })
Fx:AddSlider({ Name = "Depth", Flag = "Depth", Min = 0, Max = 1.5, Default = 1, Increment = 0.1, Callback = function(v) Yqantg:SetDepth(v) end })

local Con = Dev:AddSection({ Name = "Console", Side = "Right" })
local Log = Con:AddConsole({ Height = 140 })
Log:Log("Console ready", "Success")

-- memory cleaner API: anything tracked is cleaned by the Settings button / Auto Clear
local beat = Yqantg:Track(game:GetService("RunService").Heartbeat:Connect(function() end)) -- Disconnect()
local tmp  = Yqantg:Track(Instance.new("Folder"))                                           -- Destroy()
local seen = Yqantg:NewCache("k")                                                           -- weak cache, flushed
Yqantg:RegisterCleaner("my cache", function() table.clear(seen) end)
Con:AddButton({
    Name = "Clean now (logs result)",
    Callback = function()
        local r = Yqantg:Clean()
        if r then Log:Log(("freed %.2f MB · %d handlers · %d objects"):format(r.Freed, r.Conns + r.Dead, r.Objects), "Success") end
    end,
})

----------------------------------------------------------------------
Window:AddTab({ Name = "Premium", Locked = true, LockedMessage = "You are not whitelisted." })
Window:AddConfigTab("Config")      -- save / load / delete / auto-load UI

Yqantg:Notify({ Title = "Loaded", Content = "RightShift = hide · gear = settings", Type = "Info" })

--[[ API
    Yqantg:SetTheme("Obsidian" | "Eclipse" | "Graphite")   Yqantg:SetDepth(0..1.5)
    Yqantg.Parallax / BlurEnabled / SoundEnabled / BlockInput = true|false
    Yqantg:ToggleRGBFlow(true|false)       Window:EnableDustParticles(true|false)
    Yqantg:Splash({ Title, Subtitle, Steps, Duration })
    Yqantg.Flags.Slider          Yqantg.Options.Mode:Set("Fast")
    Yqantg:SaveConfig(n) / LoadConfig(n) / LoadAuto()
    Window:Toggle() / Minimize() / Close() / Destroy()     Yqantg:Unload()
]]
