--[[
    Yqantg Hub  ·  example.lua  (built with Nebula UI)
    Demo of every component. Copy what you need.
]]

-- Load the library -------------------------------------------------------
-- From GitHub (a link needs game:HttpGet, NOT readfile):
local Nebula = loadstring(game:HttpGet("https://raw.githubusercontent.com/anhyeeuemnhieulam-ai/Yqantg-Hub/refs/heads/main/source.lua"))()
-- From a local file in the executor workspace:
-- local Nebula = loadstring(readfile("Nebula/source.lua"))()

local HUB_NAME = "Yqantg Hub"
local HUB_LINK = "https://raw.githubusercontent.com/anhyeeuemnhieulam-ai/Yqantg-Hub/refs/heads/main/source.lua"

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Optional loading screen (yields until it finishes) ----------------------
Nebula:Splash({
    Title    = "YQANTG",
    Subtitle = HUB_NAME .. "  ·  UI Library",
    Steps    = { "loading modules", "building interface", "syncing config", "finalizing" },
    Duration = 3,
})

-- Window ------------------------------------------------------------------
local Window = Nebula:CreateWindow({
    Title        = HUB_NAME,
    Brand        = HUB_NAME,                     -- shown in the Settings panel
    Subtitle     = LocalPlayer.Name,             -- text under the title
    Size         = UDim2.fromOffset(600, 380),   -- auto-shrinks on small screens
    ToggleKey    = Enum.KeyCode.RightShift,      -- show / hide
    ToggleButton = true,                         -- floating orb for mobile
})

----------------------------------------------------------------------
-- Tab 1: Info
----------------------------------------------------------------------
local Info = Window:AddTab("Info")

-- Full-width cards (Side = "Full"; NoHeader hides the section title)
local Cards = Info:AddSection({ Side = "Full", NoHeader = true })
Cards:AddProfile()                               -- avatar, name, ID, account age, players
Cards:AddOwner({ Name = HUB_NAME, Subtitle = "Official owner", Link = HUB_LINK })
Cards:AddStats()                                 -- live FPS / ping / server fill

local Welcome = Info:AddSection({ Name = "About", Side = "Left" })
Welcome:AddParagraph({
    Title   = "Welcome to " .. HUB_NAME,
    Content = "Black & white comet border, glass panels, smooth animations and config saving.",
})
Welcome:AddButton({
    Name = "Copy link",
    Callback = function()
        if setclipboard then setclipboard(HUB_LINK) end
        Nebula:Notify({ Title = "Copied", Content = "Link copied to clipboard.", Type = "Success" })
    end,
})

local Notifs = Info:AddSection({ Name = "Notifications", Side = "Right" })
Notifs:AddButton({ Name = "Success", Callback = function() Nebula:Notify({ Title = "Success", Content = "Config applied.", Type = "Success" }) end })
Notifs:AddButton({ Name = "Error",   Callback = function() Nebula:Notify({ Title = "Access Denied", Content = "You are not whitelisted.", Type = "Error" }) end })
Notifs:AddButton({ Name = "Warning", Callback = function() Nebula:Notify({ Title = "Careful", Content = "Something looks off.", Type = "Warning" }) end })
Notifs:AddButton({ Name = "Info",    Callback = function() Nebula:Notify({ Title = "FYI", Content = "Press RightShift to hide.", Type = "Info", Duration = 6 }) end })

----------------------------------------------------------------------
-- Tab 2: Movement (sliders, toggles, keybind)
----------------------------------------------------------------------
local Move = Window:AddTab("Movement")

local Speed = Move:AddSection({ Name = "Speed", Side = "Left" })
Speed:AddToggle({
    Name = "Enable WalkSpeed", Flag = "SpeedEnabled", Default = false,
    Callback = function(on)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = on and Nebula.Flags.SpeedValue or 16 end
    end,
})
Speed:AddSlider({
    Name = "WalkSpeed", Flag = "SpeedValue", Min = 16, Max = 120, Default = 32, Increment = 1,
    Callback = function(v)
        if Nebula.Flags.SpeedEnabled then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = v end
        end
    end,
})
Speed:AddSlider({ Name = "Smoothness", Flag = "Smooth", Min = 0, Max = 1, Default = 0.25, Increment = 0.05, Suffix = "x" })

local Jump = Move:AddSection({ Name = "Jump", Side = "Right" })
Jump:AddSlider({ Name = "JumpPower", Flag = "JumpPower", Min = 50, Max = 200, Default = 50, Increment = 5,
    Callback = function(v)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.UseJumpPower = true; hum.JumpPower = v end
    end,
})
Jump:AddKeybind({
    Name = "Quick jump key", Flag = "JumpKey", Default = Enum.KeyCode.H,
    Callback = function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end,
    ChangedCallback = function(key) Nebula:Notify({ Title = "Keybind", Content = "Now bound to " .. key.Name, Type = "Info", Duration = 2 }) end,
})

----------------------------------------------------------------------
-- Tab 3: Components (dropdowns, inputs, collapsed section)
----------------------------------------------------------------------
local Comp = Window:AddTab("Components")

local Drop = Comp:AddSection({ Name = "Dropdowns", Side = "Left" })
Drop:AddDropdown({
    Name = "Mode", Flag = "Mode", Options = { "Normal", "Fast", "Smooth" }, Default = "Normal",
    Callback = function(v) print("Mode:", v) end,
})
Drop:AddDropdown({
    Name = "Targets (multi)", Flag = "Targets", Multi = true,
    Options = { "Players", "NPCs", "Items", "Vehicles", "Doors", "Chests", "Zones", "Spawns", "Bosses" },
    Default = { "Players" },
    Callback = function(map) for k in pairs(map) do print("selected:", k) end end,
})

local Inputs = Comp:AddSection({ Name = "Inputs", Side = "Right" })
Inputs:AddInput({ Name = "Text input", Flag = "Text", Placeholder = "Type something...", Callback = function(s) print("Text:", s) end })
Inputs:AddInput({ Name = "Number input", Flag = "Num", Default = "12", Numeric = true, Callback = function(n) print("Number:", n) end })

local Misc = Comp:AddSection({ Name = "Collapsed section", Side = "Right", Collapsed = true })
Misc:AddLabel("Click the header to expand / collapse.")
Misc:AddDivider()
Misc:AddToggle({ Name = "Just a toggle", Flag = "Misc1" })

----------------------------------------------------------------------
-- Tab 4: Locked tab example
----------------------------------------------------------------------
Window:AddTab({ Name = "Premium", Locked = true, LockedMessage = "You are not whitelisted to unlock this tab." })

----------------------------------------------------------------------
-- Tab 5: Config (auto-built Save / Load UI)
----------------------------------------------------------------------
Window:AddConfigTab("Config")

Nebula:Notify({ Title = HUB_NAME .. " loaded", Content = "Gear icon = themes & scale.", Type = "Success" })

--[[ Handy API
    Nebula:SetTheme("Eclipse")        -- Obsidian | Eclipse | Graphite  (all black & white)
    Nebula:SaveConfig("name") / Nebula:LoadConfig("name")
    Nebula.Flags.SpeedValue          -- read any value by its Flag
    Nebula.Options.Mode:Set("Fast")  -- change a value from code
    Window:Toggle() / Window:Minimize() / Window:Destroy()
    Nebula:Unload()                  -- remove everything & disconnect events
]]
