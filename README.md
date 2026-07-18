# Lune UI Library

A Roblox UI library for script executors with tabs, theming, keybinds, config persistence, and pinned elements.

## Quick Start

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/myrelune/LuneUI/refs/heads/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title = "My Script",
    Size = UDim2.fromOffset(600, 450),
    ConfigFolder = "MyConfigs",
    ConfigName = "Default"
})

local Tab = Window:AddTab("Combat", "sword")

local section = Tab:AddSection("Aimbot")

section:AddToggle({
    Name = "Enabled",
    Default = false,
    Flag = "aimbot_enabled",
    Callback = function(val)
        print("Aimbot:", val)
    end
})

section:AddSlider({
    Name = "FOV",
    Min = 10,
    Max = 360,
    Default = 90,
    Flag = "fov",
    Callback = function(val)
        print("FOV:", val)
    end
})
```

## Window

`Library:CreateWindow(config)` creates the main UI window.

| Config field | Type | Default | Description |
|---|---|---|---|
| `Title` | string | `"Lune"` | Window title |
| `Size` | UDim2 | `UDim2.fromOffset(600, 450)` | Window dimensions |
| `ConfigFolder` | string | `"LuneConfigs"` | Save folder for configs |
| `ConfigName` | string | `"Default"` | Config file name |

Returns a window object with:
- `Window:AddTab(name, icon?)` — create a tab (icon = Lucide icon name)
- `Window:SelectTab(tab)` — switch to a tab
- `Window.ToggleWindow()` — minimize/restore the window
- `Window.Frame` — the raw Frame instance

## Tabs

Each tab has the same `.Elements` list and supports:

| Method | Description |
|---|---|
| `tab:AddSection(name)` | Create a grouped section |
| `tab:AddButton(config)` | Text button |
| `tab:AddToggle(config)` | On/off toggle |
| `tab:AddSlider(config)` | Number slider |
| `tab:AddInput(config)` | Text input field |
| `tab:AddDropdown(config)` | Single or multi-select dropdown |
| `tab:AddKeybind(config)` | Keybind picker |
| `tab:AddColorPicker(config)` | HSV color picker |
| `tab:AddLabel(config)` | Single line of text |
| `tab:AddParagraph(config)` | Title + description block |
| `tab:AddInfo(config)` | Alias for AddParagraph with `.Update()` |
| `tab:AddDivider()` | Horizontal separator |

All `Add*` methods can be called with either positional args or a config table. Both are equivalent:

```lua
tab:AddToggle("Enabled", false, function(v) end)
tab:AddToggle({ Name = "Enabled", Default = false, Callback = function(v) end })
```

### Common Config Fields

Every element accepts these optional fields:

| Field | Type | Description |
|---|---|---|
| `Flag` | string | Auto-saved key for config persistence |
| `Tooltip` | string | Hover tooltip text |
| `ContextMenu` | table | Custom right-click menu options |
| `ConfigFolder` | string | Override the window's config folder |
| `ConfigName` | string | Override the window's config name |

---

### `tab:AddButton(config)`

```lua
local btn = tab:AddButton({
    Name = "Execute",
    Callback = function()
        print("clicked")
    end,
    Tooltip = "Run the script"
})
btn:SetText("New Label")
btn:Fire() -- trigger programmatically
```

**Return value:** `{ Frame, Name, SetText, SetCallback, Fire }`

---

### `tab:AddToggle(config)`

```lua
local toggle = tab:AddToggle({
    Name = "Auto Farm",
    Default = false,
    Flag = "autofarm",
    Callback = function(enabled)
        if enabled then
            startFarm()
        else
            stopFarm()
        end
    end
})
toggle:SetValue(true)  -- update without firing callback
toggle:Toggle()         -- flip state
toggle.OnChanged:Connect(function(val) end)
```

**Return value:** `{ Frame, Name, GetValue, SetValue, Toggle, OnChanged }`

---

### `tab:AddSlider(config)`

```lua
local slider = tab:AddSlider({
    Name = "Speed",
    Min = 1,
    Max = 100,
    Default = 16,
    Flag = "speed",
    Callback = function(val) end
})
slider:SetValue(50)
-- Double-click the slider to type a value directly
```

**Return value:** `{ Frame, Name, GetValue, SetValue, OnChanged }`

---

### `tab:AddInput(config)`

```lua
local input = tab:AddInput({
    Name = "Webhook URL",
    Default = "",
    Placeholder = "https://...",
    Flag = "webhook",
    Callback = function(text) end
})
input:SetValue("new text")
input.OnChanged:Connect(function(text) end)
```

**Return value:** `{ Frame, Name, GetValue, SetValue, OnChanged }`

---

### `tab:AddDropdown(config)`

```lua
-- Single-select
local drop = tab:AddDropdown({
    Name = "Weapon",
    Options = {"Sword", "Gun", "Fist"},
    Default = "Sword",
    Flag = "weapon",
    Callback = function(selected) end
})

-- Multi-select
local drop = tab:AddDropdown({
    Name = "Targets",
    Options = {"Players", "NPCs", "Bosses"},
    Multi = true,
    Default = {Players = true},
    Flag = "targets",
    Callback = function(selected) end
})
drop:SetValue("Gun")            -- single: set selection
drop:SetValue({Players = true}) -- multi: set table
drop:Refresh({"A", "B", "C"})   -- update options list
drop.OnChanged:Connect(function(val) end)
```

**Return value:** `{ Frame, Name, GetValue, SetValue, Refresh, OnChanged }`

---

### `tab:AddKeybind(config)`

```lua
local kb = tab:AddKeybind({
    Name = "Panic",
    Default = Enum.KeyCode.P,
    Flag = "panic_key",
    Callback = function() end  -- called on press
})
kb:SetValue(key, Enum.KeyCode.X)
```

**Return value:** `{ Frame, Name, GetValue, SetValue, SetCallback, OnChanged }`

---

### `tab:AddColorPicker(config)`

```lua
local cp = tab:AddColorPicker({
    Name = "ESP Color",
    Default = Color3.fromRGB(255, 0, 0),
    Flag = "esp_color",
    Callback = function(color) end
})
cp:SetColor(Color3.fromRGB(0, 255, 0))
cp.OnChanged:Connect(function(color) end)
```

**Return value:** `{ Frame, ColorBtn, SetColor, SetValue, GetValue, OnChanged }`

---

### `tab:AddLabel(config)`

```lua
local label = tab:AddLabel({ Text = "Status: Running" })
-- or just a string:
local label = tab:AddLabel("Status: Running")
label:SetText("Status: Paused")
```

**Return value:** `{ Frame, Name, SetText }`

---

### `tab:AddParagraph(config)` / `tab:AddInfo(config)`

```lua
local para = tab:AddParagraph({
    Title = "Instructions",
    Content = "Press the Execute button to start."
})
para:SetTitle("Updated")
para:SetContent("New text")
```

`AddInfo` is identical but adds an `.Update()` method:

```lua
local info = tab:AddInfo({ Title = "Status", Content = "..." })
info:Update({ Title = "New Title", Content = "New content" })
```

**Return value:** `{ Frame, SetTitle, SetContent }` (AddInfo also has `.Update()`)

---

### `tab:AddDivider()`

```lua
tab:AddDivider()
```

Inserts a thin horizontal line between elements.

---

## Sections

```lua
local section = tab:AddSection("Aimbot Settings")
```

Sections are grouping containers — all `Add*` methods work on them too:

```lua
section:AddToggle({ Name = "Silent Aim", ... })
section:AddSlider({ Name = "FOV", ... })
```

## Theming

```lua
-- Default theme
Library.Theme = {
    Main            = Color3.fromRGB(25, 25, 25),
    Secondary       = Color3.fromRGB(35, 35, 35),
    ElementBg       = Color3.fromRGB(30, 30, 30),
    Text            = Color3.fromRGB(240, 240, 240),
    TextDark        = Color3.fromRGB(160, 160, 160),
    Accent          = Color3.fromRGB(0, 150, 255),
    ToggleBg        = Color3.fromRGB(45, 45, 45),
    Border          = Color3.fromRGB(50, 50, 50),
    SectionBg       = Color3.fromRGB(40, 40, 40),
    NotificationBg  = Color3.fromRGB(30, 30, 30),
    Success         = Color3.fromRGB(0, 255, 100),
    Warning         = Color3.fromRGB(255, 200, 0),
    Error           = Color3.fromRGB(255, 50, 50),
    Info            = Color3.fromRGB(0, 150, 255),
}

-- Change all at once (animates to new colors)
Library:UpdateTheme({
    Accent = Color3.fromRGB(255, 50, 100),
    Main = Color3.fromRGB(20, 20, 20),
})
```

## Config Persistence

Auto-saving works through the `Flag` field on elements. Configs are saved as JSON.

```lua
Library:SaveConfig("MyFolder", "config1")       -- save now
Library:LoadConfig("MyFolder", "config1")       -- load now
Library:SaveDefaultConfigName("MyFolder", "main")  -- set which config loads automatically
```

The config saves: all flagged values, pinned element names, keybind assignments, and window positions.

## Notifications

```lua
Library:SendNotification({
    Title = "Loaded",
    Content = "Script initialized successfully",
    Type = "Success",   -- "Success", "Warning", "Error", "Info"
    Duration = 5,        -- seconds
    Image = "check"      -- optional Lucide icon override
})
```

## Keybinds

Element keybinds are set via right-click → "Keybind". They work on toggles, buttons, and tabs.

```lua
Library:SetPinnedWindowKeybind(Enum.KeyCode.RightShift)  -- hotkey for pinned window
```

## Pinned Elements

Right-click any element → "Pin" to add it to a floating pinned window. Pinned items persist across config loads.

```lua
Library:TogglePinnedWindow()           -- show/hide
Library:IsPinned("Element Name")       -- check
Library:UnpinByName("Element Name")    -- remove
```

## Context Windows

Create standalone popup windows (used internally for color picker):

```lua
local ctx = Library:CreateContextWindow({
    Title = "Custom Window",
    Size = UDim2.fromOffset(300, 400),
    AutoSize = true,       -- auto-height
    OnClose = function() end
})

ctx:AddToggle({ Name = "Option", Callback = function(v) end })
-- All Add* methods work in context windows
```

## Context Menus

Custom right-click menus:

```lua
Library:ShowContextMenu({
    { Name = "Option 1", Callback = function() end },
    { Name = "Option 2", Callback = function() end },
})
```

## Signals (Custom Events)

```lua
local sig = Library:CreateSignal()

local conn = sig:Connect(function(msg)
    print("got:", msg)
end)

sig:Fire("hello")
conn:Disconnect()

-- Wait pattern:
local result = sig:Wait()  -- yields until next Fire
```

## Webhooks

```lua
Library:SendWebhook("https://discord.com/api/webhooks/...", {
    content = "Hello!",
    embeds = { ... }
})
```

## Window Hooks

```lua
local Window = Library:CreateWindow({ ... })

Window.ToggleWindow()     -- minimize/restore
Window.SetMinimized()     -- visibility toggle
```

The window auto-minimizes after 30 seconds of inactivity and restores on any input. Window positions are saved across sessions.

## Full Example

```lua
local Library = loadstring(game:HttpGet("..."))()

local Window = Library:CreateWindow({
    Title = "Universal Script",
    ConfigFolder = "MyScript",
    ConfigName = "Profile1",
})

local main = Window:AddTab("Main", "home")

main:AddParagraph({
    Title = "Welcome",
    Content = "Select your settings below and press Execute."
})

local combat = main:AddSection("Combat")

combat:AddToggle({
    Name = "Kill Aura",
    Default = true,
    Flag = "killaura",
    Callback = function(v) end
})

combat:AddSlider({
    Name = "Attack Range",
    Min = 5,
    Max = 50,
    Default = 15,
    Flag = "range",
    Callback = function(v) end
})

local misc = main:AddSection("Misc")

misc:AddDropdown({
    Name = "Mode",
    Options = {"Normal", "Speed", "God"},
    Default = "Normal",
    Flag = "mode",
    Callback = function(v) end
})

misc:AddKeybind({
    Name = "Toggle UI",
    Default = Enum.KeyCode.RightControl,
})

misc:AddColorPicker({
    Name = "Highlight Color",
    Default = Color3.fromRGB(0, 255, 100),
    Callback = function(c) end
})

misc:AddButton({
    Name = "Execute",
    Callback = function()
        Library:SendNotification({
            Title = "Done",
            Content = "Script executed!",
            Type = "Success",
        })
    end
})

main:AddDivider()

main:AddLabel("Script by you — v1.0.0")

-- Custom theme
Library:UpdateTheme({
    Accent = Color3.fromRGB(120, 80, 255),
})
```
