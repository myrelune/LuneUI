local Library = {}
Library.__index = Library

local clonegetserv = clonefunction and clonefunction(game.GetService) or game.GetService
local cloneref = cloneref and (clonefunction and clonefunction(cloneref) or cloneref) or function(x) return x end

local servs = setmetatable({}, {
    __index = function(s, n)
        s[n] = cloneref(clonegetserv(game, n))
        return s[n]
    end
})

local Players = servs.Players
local CoreGui = servs.CoreGui
local UserInputService = servs.UserInputService
local RunService = servs.RunService
local TweenService = servs.TweenService
local HttpService = servs.HttpService

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local ProtectGui = function(gui)
    if not gui then
        return
    end
    if gethui then
        gui.Parent = gethui()
    else
        gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
    end
end

local Lucide = nil
pcall(
    function()
        Lucide =
            loadstring(
            game:HttpGet("https://github.com/latte-soft/lucide-roblox/releases/download/0.1.3/lucide-roblox.luau")
        )()
    end
)
if not Lucide then
    warn("LuneUI: Failed to load Lucide Icons. Network issue?")
end

local function Tween(obj, info, props)
    local t = TweenService:Create(obj, TweenInfo.new(unpack(info)), props)
    t:Play()
    return t
end

function Library:CreateSignal()
    local connections = {}
    return {
        Connect = function(self, callback)
            local connection = {
                Disconnect = function(self)
                    for i, c in ipairs(connections) do
                        if c == self then
                            table.remove(connections, i)
                            break
                        end
                    end
                end
            }
            table.insert(connections, {callback = callback, connection = connection})
            return connection
        end,
        Fire = function(self, ...)
            for _, c in ipairs(connections) do
                task.spawn(c.callback, ...)
            end
        end,
        Wait = function(self)
            local thread = coroutine.running()
            local connection
            connection = self:Connect(function(...)
                connection:Disconnect()
                coroutine.resume(thread, ...)
            end)
            return coroutine.yield()
        end
    }
end

local function MakeDraggable(frame, handle, onDragEnd)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos

    handle.InputBegan:Connect(
        function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position

                input.Changed:Connect(
                    function()
                        if input.UserInputState == Enum.UserInputState.End then
                            dragging = false
                            if onDragEnd then
                                task.defer(onDragEnd)
                            end
                        end
                    end
                )
            end
        end
    )

    handle.InputChanged:Connect(
        function(input)
            if
                input.UserInputType == Enum.UserInputType.MouseMovement or
                    input.UserInputType == Enum.UserInputType.Touch
             then
                dragInput = input
            end
        end
    )

    UserInputService.InputChanged:Connect(
        function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                local fadeInfo = {0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out}
                Tween(
                    frame,
                    fadeInfo,
                    {
                        Position = UDim2.new(
                            startPos.X.Scale,
                            startPos.X.Offset + delta.X,
                            startPos.Y.Scale,
                            startPos.Y.Offset + delta.Y
                        )
                    }
                )
            end
        end
    )
end

Library.Theme = {
    Main = Color3.fromRGB(25, 25, 25),
    Secondary = Color3.fromRGB(35, 35, 35),
    ElementBg = Color3.fromRGB(30, 30, 30),
    Text = Color3.fromRGB(240, 240, 240),
    TextDark = Color3.fromRGB(160, 160, 160),
    Accent = Color3.fromRGB(0, 150, 255),
    ToggleBg = Color3.fromRGB(45, 45, 45),
    Border = Color3.fromRGB(50, 50, 50),
    SectionBg = Color3.fromRGB(40, 40, 40),
    NotificationBg = Color3.fromRGB(30, 30, 30),
    Success = Color3.fromRGB(0, 255, 100),
    Warning = Color3.fromRGB(255, 200, 0),
    Error = Color3.fromRGB(255, 50, 50),
    Info = Color3.fromRGB(0, 150, 255)
}
Library.ColorPresets = {}
Library.Flags = {}
Library.Hotkeys = {}
Library.Notifications = {}
Library.Clipboard = nil
Library.ElementRegistry = {}
Library.PendingPinned = {}
Library.PendingKeybinds = {}
Library.PinnedWindowKeybind = nil
Library.WindowPositions = {}
Library.MainFrame = nil
Library.SavedKeybinds = {}
Library.PinnedWindowRef = nil
Library.MinimizedPosition = nil
Library.MaximizedPosition = nil
Library.DefaultConfigName = nil

UserInputService.InputBegan:Connect(
    function(input, gameProcessed)
        if gameProcessed then
            return
        end

        for _, hk in pairs(Library.Hotkeys) do
            if hk.Key and hk.Key ~= Enum.KeyCode.Unknown and input.KeyCode == hk.Key then
                if hk.Callback then
                    hk.Callback()
                end
            end
        end
    end
)

local ThemeRegistry = {}

local ThemeUpdateHooks = {}

function Library:RegisterTheme(obj, prop, themeKey)
    if not ThemeRegistry[obj] then
        ThemeRegistry[obj] = {}
    end
    ThemeRegistry[obj][prop] = themeKey
    obj[prop] = Library.Theme[themeKey]
end

function Library:UpdateTheme(newTheme)
    for k, v in pairs(newTheme) do
        Library.Theme[k] = v
    end
    for obj, props in pairs(ThemeRegistry) do
        if obj and obj.Parent then
            for prop, themeKey in pairs(props) do
                if Library.Theme[themeKey] then
                    Tween(
                        obj,
                        {0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out},
                        {[prop] = Library.Theme[themeKey]}
                    )
                end
            end
        end
    end
    for i = #ThemeUpdateHooks, 1, -1 do
        local hook = ThemeUpdateHooks[i]
        if hook then
            local ok = pcall(hook)
            if not ok then
                table.remove(ThemeUpdateHooks, i)
            end
        end
    end
end

function Library:SaveConfig(folder, name)
    if not folder or not name then
        return
    end
    if not isfolder(folder) then
        makefolder(folder)
    end
    local pinnedData = {}
    for _, pin in ipairs(Library.PinnedElements) do
        table.insert(pinnedData, {
            Name = pin.Name,
            Type = pin.Type
        })
    end
    local windowPositions = {}
    if Library.MainFrame and Library.MainFrame.Parent then
        local pos = Library.MaximizedPosition or Library.MainFrame.Position
        windowPositions.MainWindow = {
            XScale = pos.X.Scale, XOffset = pos.X.Offset,
            YScale = pos.Y.Scale, YOffset = pos.Y.Offset
        }
    end
    if Library.PinnedWindowRef and Library.PinnedWindowRef.Frame and Library.PinnedWindowRef.Frame.Parent then
        local pos = Library.PinnedWindowRef.Frame.Position
        windowPositions.PinnedWindow = {
            XScale = pos.X.Scale, XOffset = pos.X.Offset,
            YScale = pos.Y.Scale, YOffset = pos.Y.Offset
        }
    end
    if Library.MinimizedPosition then
        local pos = Library.MinimizedPosition
        windowPositions.MinimizedBar = {
            XScale = pos.X.Scale, XOffset = pos.X.Offset,
            YScale = pos.Y.Scale, YOffset = pos.Y.Offset
        }
    end
    
    local configData = {
        Flags = Library.Flags,
        PinnedElements = pinnedData,
        Keybinds = Library.SavedKeybinds,
        PinnedWindowKeybind = Library.PinnedWindowKeybind and Library.PinnedWindowKeybind.Name or nil,
        WindowPositions = windowPositions
    }
    
    local json = HttpService:JSONEncode(configData)
    writefile(folder .. "/" .. name .. ".json", json)
end

function Library:SaveConfigDebounced(folder, name)
    if not folder or not name then
        return
    end
    if Library._autoSaveTask then
        task.cancel(Library._autoSaveTask)
    end
    Library._autoSaveTask = task.delay(0.8, function()
        if Library._autoSaveTask then
            Library._autoSaveTask = nil
        end
        Library:SaveConfig(folder, name)
    end)
end

function Library:LoadConfig(folder, name)
    if not folder or not name then
        return
    end
    local path = folder .. "/" .. name .. ".json"
    if isfile(path) then
        local success, decoded =
            pcall(
            function()
                return HttpService:JSONDecode(readfile(path))
            end
        )
        if success then
            local flags = decoded.Flags or decoded
            for flag, value in pairs(flags) do
                Library.Flags[flag] = value
            end
            
            if decoded.PinnedElements then
                for _, pinInfo in ipairs(decoded.PinnedElements) do
                    Library.PendingPinned[pinInfo.Name] = pinInfo.Type
                end
            end
            
            if decoded.Keybinds then
                for elemName, keyName in pairs(decoded.Keybinds) do
                    Library.PendingKeybinds[elemName] = keyName
                    Library.SavedKeybinds[elemName] = keyName
                end
            end
            if decoded.PinnedWindowKeybind then
                local keyCode = Enum.KeyCode[decoded.PinnedWindowKeybind]
                if keyCode then
                    Library:SetPinnedWindowKeybind(keyCode)
                end
            end
            if decoded.WindowPositions then
                Library.WindowPositions = decoded.WindowPositions
                if decoded.WindowPositions.MinimizedBar then
                    local pos = decoded.WindowPositions.MinimizedBar
                    Library.MinimizedPosition = UDim2.new(pos.XScale, pos.XOffset, pos.YScale, pos.YOffset)
                end
            end
            
            return flags
        end
    end
    return {}
end

function Library:SaveDefaultConfigName(folder, configName)
    if not folder then return end
    if not isfolder(folder) then
        makefolder(folder)
    end
    local path = folder .. "/_default.json"
    local success = pcall(function()
        writefile(path, HttpService:JSONEncode({DefaultConfig = configName}))
    end)
    if success then
        Library.DefaultConfigName = configName
    end
    return success
end

function Library:LoadDefaultConfigName(folder)
    if not folder then return nil end
    local path = folder .. "/_default.json"
    if isfile(path) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if success and decoded and decoded.DefaultConfig then
            Library.DefaultConfigName = decoded.DefaultConfig
            return decoded.DefaultConfig
        end
    end
    return nil
end

function Library:TryRestorePending(elementData)
    if not elementData or not elementData.Name then
        return
    end
    if Library.PendingPinned[elementData.Name] then
        task.defer(function()
            if not Library:IsPinned(elementData.Name) then
                Library:PinElement(elementData)
            end
        end)
        Library.PendingPinned[elementData.Name] = nil
    end
    local keyName = Library.PendingKeybinds[elementData.Name]
    if keyName then
        local keyCode = Enum.KeyCode[keyName]
        if keyCode then
            if elementData.HotkeyIndex then
                Library.Hotkeys[elementData.HotkeyIndex] = nil
            end
            
            local hotkeyEntry = {
                Key = keyCode ~= Enum.KeyCode.Unknown and keyCode or nil,
                Callback = elementData.Fire or elementData.Toggle or elementData.Select
            }
            table.insert(Library.Hotkeys, hotkeyEntry)
            elementData.HotkeyIndex = #Library.Hotkeys
            elementData.Keybind = keyCode
        end
        Library.PendingKeybinds[elementData.Name] = nil
    end
end

function Library:RegisterElement(elementData)
    table.insert(Library.ElementRegistry, elementData)
    Library:TryRestorePending(elementData)
end

function Library:SetPinnedWindowKeybind(keyCode)
    
    if Library.PinnedWindowKeybindIndex then
        Library.Hotkeys[Library.PinnedWindowKeybindIndex] = nil
    end
    
    if keyCode then
        local hotkeyEntry = {
            Key = keyCode,
            Callback = function()
                Library:TogglePinnedWindow()
            end
        }
        table.insert(Library.Hotkeys, hotkeyEntry)
        Library.PinnedWindowKeybindIndex = #Library.Hotkeys
        Library.PinnedWindowKeybind = keyCode
    else
        Library.PinnedWindowKeybindIndex = nil
        Library.PinnedWindowKeybind = nil
    end
end

function Library:SendWebhook(url, payload)
    if not url or not payload then
        return
    end
    if not request then
        return
    end
    request(
        {
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        }
    )
end

local NotificationArea = nil
local NotifLayout = nil

function Library:InitNotifications()
    if NotificationArea then
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "LuneNotifications"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ProtectGui(gui)

    NotificationArea = Instance.new("Frame")
    NotificationArea.Parent = gui
    NotificationArea.Size = UDim2.new(0, 300, 1, 0)
    NotificationArea.Position = UDim2.new(1, -320, 0, 20)
    NotificationArea.BackgroundTransparency = 1

    NotifLayout = Instance.new("UIListLayout")
    NotifLayout.Parent = NotificationArea
    NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    NotifLayout.Padding = UDim.new(0, 10)

    local DragFrame = Instance.new("Frame")
    DragFrame.Parent = NotificationArea
    DragFrame.Size = UDim2.new(1, 0, 0, 20)
    DragFrame.Position = UDim2.new(0, 0, 1, 0)
    DragFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DragFrame.BackgroundTransparency = 0.9
    DragFrame.BorderSizePixel = 0
    DragFrame.Visible = false

    MakeDraggable(NotificationArea, DragFrame)
end

function Library:SendNotification(config)
    Library:InitNotifications()
    config = config or {}
    local TitleText = config.Title or "Notification"
    local ContentText = config.Content or ""
    local Duration = config.Duration or 5
    local Image = config.Image
    local Type = config.Type or "Info"

    local Frame = Instance.new("Frame")
    Frame.Parent = NotificationArea
    Frame.Size = UDim2.new(1, 0, 0, 0)
    Frame.AutomaticSize = Enum.AutomaticSize.Y
    Frame.BackgroundTransparency = 1

    local Bg = Instance.new("Frame")
    Bg.Name = "Bg"
    Bg.Parent = Frame
    Bg.Size = UDim2.new(1, 0, 0, 0)
    Bg.AutomaticSize = Enum.AutomaticSize.Y
    Bg.BackgroundColor3 = Library.Theme.NotificationBg
    Bg.BackgroundTransparency = 0.1
    Library:RegisterTheme(Bg, "BackgroundColor3", "NotificationBg")

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Bg

    local Stroke = Instance.new("UIStroke")
    Stroke.Parent = Bg
    Stroke.Thickness = 1
    Stroke.Transparency = 0.5

    local Color = Library.Theme.Info
    if Type == "Success" then
        Color = Library.Theme.Success
    elseif Type == "Warning" then
        Color = Library.Theme.Warning
    elseif Type == "Error" then
        Color = Library.Theme.Error
    end

    Stroke.Color = Color

    local IconLabel = nil
    if Lucide then
        local iconName = "info"
        if Type == "Success" then
            iconName = "check-circle"
        elseif Type == "Warning" then
            iconName = "alert-triangle"
        elseif Type == "Error" then
            iconName = "x-circle"
        end
        if Image then
            iconName = Image
        end

        pcall(
            function()
                IconLabel =
                    Lucide.ImageLabel(
                    iconName,
                    24,
                    {
                        Parent = Bg,
                        Position = UDim2.new(0, 10, 0.5, -12),
                        ImageColor3 = Color,
                        BackgroundTransparency = 1,
                        ImageTransparency = 1
                    }
                )
            end
        )
    end

    local Title = Instance.new("TextLabel")
    Title.Parent = Bg
    Title.Text = TitleText
    Title.Position = UDim2.new(0, 45, 0, 8)
    Title.Size = UDim2.new(1, -55, 0, 20)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Library.Theme.Text
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextTransparency = 1
    Title.TextWrapped = true
    Library:RegisterTheme(Title, "TextColor3", "Text")

    local Desc = Instance.new("TextLabel")
    Desc.Parent = Bg
    Desc.Text = ContentText
    Desc.Position = UDim2.new(0, 45, 0, 28)
    Desc.Size = UDim2.new(1, -55, 0, 0)
    Desc.BackgroundTransparency = 1
    Desc.TextColor3 = Library.Theme.TextDark
    Desc.Font = Enum.Font.Gotham
    Desc.TextSize = 13
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.TextWrapped = true
    Desc.AutomaticSize = Enum.AutomaticSize.Y
    Desc.TextTransparency = 1
    Library:RegisterTheme(Desc, "TextColor3", "TextDark")

    local Pad = Instance.new("UIPadding")
    Pad.Parent = Bg
    Pad.PaddingBottom = UDim.new(0, 12)
    Pad.PaddingTop = UDim.new(0, 0)

    local TimerBar = Instance.new("Frame")
    TimerBar.Parent = Frame
    TimerBar.Size = UDim2.new(1, 0, 0, 2)
    TimerBar.Position = UDim2.new(0, 0, 0, 0)
    TimerBar.BackgroundColor3 = Color
    TimerBar.BorderSizePixel = 0
    TimerBar.BackgroundTransparency = 1

    local Gap = Instance.new("Frame")
    Gap.Parent = Frame
    Gap.Size = UDim2.new(1, 0, 0, 4)
    Gap.BackgroundTransparency = 1
    Gap.BorderSizePixel = 0
    
    local Layout = Instance.new("UIListLayout")
    Layout.Parent = Frame
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    Bg.LayoutOrder = 1
    Gap.LayoutOrder = 2
    TimerBar.LayoutOrder = 3

    local TimerCorner = Instance.new("UICorner")
    TimerCorner.CornerRadius = UDim.new(1, 0)
    TimerCorner.Parent = TimerBar

    Tween(Bg, {0.3}, {BackgroundTransparency = 0.1})
    Tween(Stroke, {0.3}, {Transparency = 0.5})
    Tween(Title, {0.3}, {TextTransparency = 0})
    Tween(Desc, {0.3}, {TextTransparency = 0})
    if IconLabel then
        Tween(IconLabel, {0.3}, {ImageTransparency = 0})
    end

    Tween(TimerBar, {0.3}, {BackgroundTransparency = 0})
    Tween(TimerBar, {Duration, Enum.EasingStyle.Linear}, {Size = UDim2.new(0, 0, 0, 2)})

    task.delay(
        Duration,
        function()
            if Frame and Frame.Parent then
                pcall(Tween, Bg, {0.3}, {BackgroundTransparency = 1})
                pcall(Tween, Stroke, {0.3}, {Transparency = 1})
                pcall(Tween, Title, {0.3}, {TextTransparency = 1})
                pcall(Tween, Desc, {0.3}, {TextTransparency = 1})
                pcall(Tween, TimerBar, {0.3}, {BackgroundTransparency = 1})
                if IconLabel then
                    pcall(Tween, IconLabel, {0.3}, {ImageTransparency = 1})
                end

                task.wait(0.3)
                if Frame and Frame.Parent then
                    Frame:Destroy()
                end
            end
        end
    )
end

local ContextMenu = nil
function Library:ShowContextMenu(options)
    if ContextMenu then
        ContextMenu:Destroy()
        ContextMenu = nil
    end

    if Library._activeKeybindListener then
        Library._activeKeybindListener:Disconnect()
        Library._activeKeybindListener = nil
    end
    local mouse = LocalPlayer:GetMouse()
    local x, y = mouse.X, mouse.Y

    local gui = Instance.new("ScreenGui")
    gui.Name = "LuneContext"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    ProtectGui(gui)
    ContextMenu = gui

    local input = Instance.new("TextButton")
    input.Parent = gui
    input.Size = UDim2.new(1, 0, 1, 0)
    input.BackgroundTransparency = 1
    input.Text = ""
    input.MouseButton1Click:Connect(
        function()
            if Library._activeKeybindListener then
                Library._activeKeybindListener:Disconnect()
                Library._activeKeybindListener = nil
            end
            gui:Destroy()
            ContextMenu = nil
        end
    )

    local Frame = Instance.new("Frame")
    Frame.Parent = gui
    Frame.Position = UDim2.new(0, x + 5, 0, y + 5)
    Frame.BackgroundColor3 = Library.Theme.ElementBg
    Frame.BorderSizePixel = 0
    Frame.AutomaticSize = Enum.AutomaticSize.XY

    local Stroke = Instance.new("UIStroke")
    Stroke.Parent = Frame
    Stroke.Color = Library.Theme.Border
    Stroke.Thickness = 1

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 5)
    Corner.Parent = Frame

    local List = Instance.new("UIListLayout")
    List.Parent = Frame
    List.Padding = UDim.new(0, 2)

    local Pad = Instance.new("UIPadding")
    Pad.Parent = Frame
    Pad.PaddingTop = UDim.new(0, 5)
    Pad.PaddingBottom = UDim.new(0, 5)
    Pad.PaddingLeft = UDim.new(0, 5)
    Pad.PaddingRight = UDim.new(0, 5)

    for _, opt in pairs(options) do
        local btn = Instance.new("TextButton")
        btn.Parent = Frame
        btn.Size = UDim2.new(0, 120, 0, 24)
        btn.BackgroundColor3 = Library.Theme.ElementBg
        btn.Text = opt.Name
        btn.TextColor3 = Library.Theme.Text
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.AutoButtonColor = true

        local C = Instance.new("UICorner")
        C.CornerRadius = UDim.new(0, 6)
        C.Parent = btn

        btn.MouseButton1Click:Connect(
            function()
                if opt.Callback then
                    opt.Callback()
                end
                gui:Destroy()
                ContextMenu = nil
            end
        )
    end
end

function Library:ShowElementContextMenu(elementData)
    if not elementData then
        return
    end

    local options = {}

    if elementData.Type == "toggle" or elementData.Type == "button" or elementData.Type == "tab" then
        local currentKeyName = elementData.Keybind and elementData.Keybind.Name or "None"
        table.insert(
            options,
            {
                Name = "Keybind: " .. currentKeyName,
                Callback = function()
                    Library:SendNotification(
                        {
                            Title = "Keybind",
                            Content = "Press a key to bind (Escape to cancel)...",
                            Type = "Info",
                            Duration = 5
                        }
                    )

                    local listening = true
                    local conn
                    conn =
                        UserInputService.InputBegan:Connect(
                        function(input, processed)
                            if processed then
                                return
                            end
                            if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                                listening = false
                                conn:Disconnect()
                                Library._activeKeybindListener = nil

                                if input.KeyCode == Enum.KeyCode.Escape then
                                    Library:SendNotification(
                                        {
                                            Title = "Cancelled",
                                            Content = "Keybind not changed",
                                            Type = "Info",
                                            Duration = 2
                                        }
                                    )
                                    return
                                end

                                local key = input.KeyCode

                                if elementData.HotkeyIndex then
                                    Library.Hotkeys[elementData.HotkeyIndex] = nil
                                end

                                local hotkeyEntry = {
                                    Key = key,
                                    Callback = elementData.Fire or elementData.Toggle or elementData.Select
                                }
                                table.insert(Library.Hotkeys, hotkeyEntry)
                                elementData.HotkeyIndex = #Library.Hotkeys
                                elementData.Keybind = key
                                
                                Library.SavedKeybinds[elementData.Name] = key.Name

                                Library:SendNotification(
                                    {
                                        Title = "Keybind Set",
                                        Content = "Bound to " .. key.Name,
                                        Type = "Success",
                                        Duration = 2
                                    }
                                )
                                
                                if Library.ConfigSettings then
                                    Library:SaveConfigDebounced(Library.ConfigSettings.Folder, Library.ConfigSettings.Name)
                                end
                            end
                        end
                    )
                    Library._activeKeybindListener = conn
                end
            }
        )

        if elementData.Keybind then
            table.insert(
                options,
                {
                    Name = "Clear Keybind",
                    Callback = function()
                        if elementData.HotkeyIndex then
                            Library.Hotkeys[elementData.HotkeyIndex] = nil
                        end
                        elementData.Keybind = nil
                        elementData.HotkeyIndex = nil
                        Library.SavedKeybinds[elementData.Name] = nil
                        
                        Library:SendNotification(
                            {
                                Title = "Cleared",
                                Content = "Keybind removed",
                                Type = "Info",
                                Duration = 2
                            }
                        )
                        if Library.ConfigSettings then
                            Library:SaveConfigDebounced(Library.ConfigSettings.Folder, Library.ConfigSettings.Name)
                        end
                    end
                }
            )
        end
    end

    if elementData.Frame then
        local isPinned = Library:IsPinned(elementData.Name)
        table.insert(
            options,
            {
                Name = isPinned and "Unpin" or "Pin",
                Callback = function()
                    if isPinned then
                        Library:UnpinByName(elementData.Name)
                    else
                        Library:PinElement(elementData)
                    end
                end
            }
        )
    end

    if elementData.GetValue then
        table.insert(
            options,
            {
                Name = "Copy Value",
                Callback = function()
                    Library.Clipboard = {
                        Type = elementData.Type,
                        Value = elementData.GetValue()
                    }
                    Library:SendNotification(
                        {
                            Title = "Copied",
                            Content = "Value copied to clipboard",
                            Type = "Success",
                            Duration = 2
                        }
                    )
                end
            }
        )
    end

    if elementData.SetValue and Library.Clipboard and Library.Clipboard.Value ~= nil then
        table.insert(
            options,
            {
                Name = "Paste Value",
                Callback = function()
                    elementData.SetValue(Library.Clipboard.Value)
                    Library:SendNotification(
                        {
                            Title = "Pasted",
                            Content = "Value pasted from clipboard",
                            Type = "Success",
                            Duration = 2
                        }
                    )
                end
            }
        )
    end

    if elementData.SetValue and elementData.Default ~= nil then
        table.insert(
            options,
            {
                Name = "Reset to Default",
                Callback = function()
                    elementData.SetValue(elementData.Default)
                    Library:SendNotification(
                        {
                            Title = "Reset",
                            Content = "Value reset to default",
                            Type = "Info",
                            Duration = 2
                        }
                    )
                end
            }
        )
    end

    if #options > 0 then
        Library:ShowContextMenu(options)
    end
end

local PinnedWindow = nil
local PinnedContainer = nil
Library.PinnedElements = {}

local PinnedSection = nil

function Library:EnsurePinnedWindow()
    if PinnedWindow and PinnedWindow.Container and PinnedWindow.Container.Parent then
        return PinnedWindow
    end

    PinnedWindow =
        Library:CreateContextWindow(
        {
            Title = "Pinned Items",
            Size = UDim2.fromOffset(280, 60),
            AutoSize = true
        }
    )
    Library.PinnedWindowRef = PinnedWindow
    if Library.WindowPositions.PinnedWindow then
        local pos = Library.WindowPositions.PinnedWindow
        PinnedWindow.Frame.Position = UDim2.new(pos.XScale, pos.XOffset, pos.YScale, pos.YOffset)
    end

    PinnedContainer = PinnedWindow.Container

    PinnedSection = {Elements = {}}
    Library.AttachComponents(PinnedSection, PinnedContainer)

    for _, pinData in ipairs(Library.PinnedElements) do
        Library:AddPinnedElementToWindow(pinData)
    end

    return PinnedWindow
end

function Library:AddPinnedElementToWindow(pinData)
    if not PinnedSection then
        return
    end

    local element = nil

    if pinData.Type == "toggle" then
        element =
            PinnedSection:AddToggle(
            {
                Name = pinData.Name,
                Default = pinData.GetValue and pinData.GetValue() or false,
                Callback = function(val)
                    if pinData.SetValue then
                        pinData.SetValue(val)
                    end
                    if pinData.Callback then
                        pinData.Callback(val)
                    end
                end
            }
        )
    elseif pinData.Type == "button" then
        element =
            PinnedSection:AddButton(
            {
                Name = pinData.Name,
                Callback = pinData.Callback or pinData.Fire
            }
        )
    elseif pinData.Type == "slider" then
        element =
            PinnedSection:AddSlider(
            {
                Name = pinData.Name,
                Min = pinData.Min or 0,
                Max = pinData.Max or 100,
                Default = pinData.GetValue and pinData.GetValue() or 0,
                Callback = function(val)
                    if pinData.SetValue then
                        pinData.SetValue(val)
                    end
                    if pinData.Callback then
                        pinData.Callback(val)
                    end
                end
            }
        )
    end

    if element and element.Frame then
        pinData.PinnedElement = element
    end
end

function Library:PinElement(elementData)
    if not elementData then
        return
    end

    for _, pin in ipairs(Library.PinnedElements) do
        if pin.Name == elementData.Name then
            Library:SendNotification(
                {
                    Title = "Already Pinned",
                    Content = elementData.Name .. " is already pinned",
                    Type = "Info",
                    Duration = 2
                }
            )
            return
        end
    end

    Library:EnsurePinnedWindow()

    local pinData = {
        Name = elementData.Name,
        Type = elementData.Type,
        GetValue = elementData.GetValue,
        SetValue = elementData.SetValue,
        Default = elementData.Default,
        Fire = elementData.Fire,
        Toggle = elementData.Toggle,
        Callback = elementData.Callback,
        Min = elementData.Min,
        Max = elementData.Max,
        Frame = elementData.Frame
    }

    table.insert(Library.PinnedElements, pinData)

    Library:AddPinnedElementToWindow(pinData)

    Library:SendNotification(
        {
            Title = "Pinned",
            Content = elementData.Name .. " added to pinned items",
            Type = "Success",
            Duration = 2
        }
    )
    if Library.ConfigSettings then
        Library:SaveConfigDebounced(Library.ConfigSettings.Folder, Library.ConfigSettings.Name)
    end
end

function Library:UnpinElement(pinData)
    for i, pin in ipairs(Library.PinnedElements) do
        if pin == pinData then
            if pin.PinnedElement and pin.PinnedElement.Frame then
                pin.PinnedElement.Frame:Destroy()
            end
            table.remove(Library.PinnedElements, i)
            break
        end
    end
end

function Library:IsPinned(name)
    for _, pin in ipairs(Library.PinnedElements) do
        if pin.Name == name then
            return true
        end
    end
    return false
end

function Library:UnpinByName(name)
    for i, pin in ipairs(Library.PinnedElements) do
        if pin.Name == name then
            if pin.PinnedElement and pin.PinnedElement.Frame then
                pin.PinnedElement.Frame:Destroy()
            end
            table.remove(Library.PinnedElements, i)
            Library:SendNotification(
                {
                    Title = "Unpinned",
                    Content = name .. " removed from pinned items",
                    Type = "Info",
                    Duration = 2
                }
            )
            if Library.ConfigSettings then
                Library:SaveConfigDebounced(Library.ConfigSettings.Folder, Library.ConfigSettings.Name)
            end
            break
        end
    end
end

function Library:TogglePinnedWindow()
    if PinnedWindow and PinnedWindow.Container and PinnedWindow.Container.Parent then
        return
    end
    Library:EnsurePinnedWindow()
end

function Library:AddToPinned(name, type, args)
    if not PinnedWindow or not PinnedWindow.Container.Parent then
        Library:TogglePinnedWindow()
    end

    local container = PinnedWindow.Container

    local helper = {}
    Library.AttachComponents(helper, container)

    if type == "Toggle" then
        helper:AddToggle(name, args.Default, args.Callback)
    elseif type == "Slider" then
        helper:AddSlider(name, args.Min, args.Max, args.Default, args.Callback)
    elseif type == "Button" then
        helper:AddButton(name, args.Callback)
    elseif type == "Dropdown" then
        helper:AddDropdown(name, args.Options, args.Default, args.Callback)
    elseif type == "ColorPicker" then
        helper:AddColorPicker(name, args.Default, args.Callback)
    end
end

local TooltipGui, TooltipFrame, TooltipLabel, TooltipConnection, TooltipActiveFrame
local function InitTooltip()
    if TooltipGui then return end
    TooltipGui = Instance.new("ScreenGui")
    TooltipGui.Name = "LuneTooltips"
    TooltipGui.ResetOnSpawn = false
    TooltipGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    TooltipGui.DisplayOrder = 999
    TooltipGui.IgnoreGuiInset = true
    ProtectGui(TooltipGui)

    TooltipFrame = Instance.new("Frame")
    TooltipFrame.Parent = TooltipGui
    TooltipFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    TooltipFrame.BorderSizePixel = 0
    TooltipFrame.ZIndex = 100
    TooltipFrame.Visible = false
    TooltipFrame.AutomaticSize = Enum.AutomaticSize.XY

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = TooltipFrame

    TooltipLabel = Instance.new("TextLabel")
    TooltipLabel.Parent = TooltipFrame
    TooltipLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    TooltipLabel.TextSize = 12
    TooltipLabel.Font = Enum.Font.Gotham
    TooltipLabel.BackgroundTransparency = 1
    TooltipLabel.AutomaticSize = Enum.AutomaticSize.XY
    TooltipLabel.TextWrapped = true
    TooltipLabel.TextXAlignment = Enum.TextXAlignment.Left

    local Pad = Instance.new("UIPadding")
    Pad.Parent = TooltipFrame
    Pad.PaddingTop = UDim.new(0, 4)
    Pad.PaddingBottom = UDim.new(0, 4)
    Pad.PaddingLeft = UDim.new(0, 6)
    Pad.PaddingRight = UDim.new(0, 6)

    TooltipConnection = RunService.RenderStepped:Connect(
        function()
            if not TooltipFrame.Visible then return end
            local m = UserInputService:GetMouseLocation()
            TooltipFrame.Position = UDim2.fromOffset(m.X + 8, m.Y + 8)
        end
    )
end

local function ShowTooltip(frame, text)
    InitTooltip()
    TooltipActiveFrame = frame
    TooltipLabel.Text = text
    TooltipFrame.Visible = true
end

local function HideTooltip(frame)
    if TooltipActiveFrame == frame then
        TooltipActiveFrame = nil
        TooltipFrame.Visible = false
    end
end

local function AddTooltip(frame, text)
    if not text or text == "" then
        return
    end

    frame.MouseEnter:Connect(function()
        ShowTooltip(frame, text)
    end)

    frame.MouseLeave:Connect(function()
        HideTooltip(frame)
    end)

    frame.AncestryChanged:Connect(function()
        if not frame.Parent then
            HideTooltip(frame)
        end
    end)
end

function Library.AttachComponents(obj, container)
    obj.Elements = obj.Elements or {}

    local function AddContextMenu(frame, options)
        if not options or #options == 0 then
            return
        end

        frame.InputBegan:Connect(
            function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    Library:ShowContextMenu(options)
                end
            end
        )
    end

    local function CreateContainer(h, tooltip, contextMenu)
        local Frame = Instance.new("Frame")
        Frame.Parent = container
        Frame.Size = UDim2.new(1, 0, 0, h or 46)
        Frame.BackgroundColor3 = Library.Theme.ElementBg
        Library:RegisterTheme(Frame, "BackgroundColor3", "ElementBg")

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = Frame

        local Stroke = Instance.new("UIStroke")
        Stroke.Parent = Frame
        Stroke.Color = Library.Theme.Border
        Stroke.Thickness = 1
        Library:RegisterTheme(Stroke, "Color", "Border")

        if tooltip then
            AddTooltip(Frame, tooltip)
        end
        if contextMenu then
            AddContextMenu(Frame, contextMenu)
        end

        return Frame, Stroke
    end

    function obj:AddSection(name)
        local Section = {Name = name, Elements = {}}

        local Frame = Instance.new("Frame")
        Frame.Parent = container
        Frame.Size = UDim2.new(1, 0, 0, 0)
        Frame.AutomaticSize = Enum.AutomaticSize.Y
        Frame.BackgroundColor3 = Library.Theme.SectionBg
        Frame.BackgroundTransparency = 0.5
        Library:RegisterTheme(Frame, "BackgroundColor3", "SectionBg")

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = Frame

        local Stroke = Instance.new("UIStroke")
        Stroke.Parent = Frame
        Stroke.Color = Library.Theme.Border
        Stroke.Thickness = 1
        Stroke.Transparency = 0.5
        Library:RegisterTheme(Stroke, "Color", "Border")

        local Header = Instance.new("TextLabel")
        Header.Parent = Frame
        Header.Text = name
        Header.Size = UDim2.new(1, -20, 0, 24)
        Header.Position = UDim2.new(0, 10, 0, 4)
        Header.BackgroundTransparency = 1
        Header.TextColor3 = Library.Theme.Accent
        Library:RegisterTheme(Header, "TextColor3", "Accent")
        Header.Font = Enum.Font.GothamBold
        Header.TextSize = 13
        Header.TextXAlignment = Enum.TextXAlignment.Left

        local Content = Instance.new("Frame")
        Content.Parent = Frame
        Content.Size = UDim2.new(1, -10, 0, 28)
        Content.Position = UDim2.new(0, 5, 0, 28)
        Content.BackgroundTransparency = 1
        Content.AutomaticSize = Enum.AutomaticSize.Y

        local Layout = Instance.new("UIListLayout")
        Layout.Parent = Content
        Layout.Padding = UDim.new(0, 6)

        local Pad = Instance.new("UIPadding")
        Pad.Parent = Frame
        Pad.PaddingBottom = UDim.new(0, 8)

        Library.AttachComponents(Section, Content)
        table.insert(obj.Elements, {Frame = Frame, Name = name, Elements = Section.Elements})
        return Section
    end

    function obj:AddButton(config, callback)
        if type(config) == "string" then
            config = {Name = config, Callback = callback}
        end
        local Frame, Stroke = CreateContainer(42)

        local Btn = Instance.new("TextButton")
        Btn.Parent = Frame
        Btn.Size = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1
        Btn.Text = config.Name or "Button"
        Btn.TextColor3 = Library.Theme.Text
        Btn.Font = Enum.Font.GothamBold
        Btn.TextSize = 14
        Library:RegisterTheme(Btn, "TextColor3", "Text")

        local function paramsUpdate()
            Tween(Stroke, {0.2}, {Color = Library.Theme.Accent})
            Tween(Btn, {0.2}, {TextColor3 = Library.Theme.Accent})
        end

        local function paramsReset()
            Tween(Stroke, {0.2}, {Color = Library.Theme.Border})
            Tween(Btn, {0.2}, {TextColor3 = Library.Theme.Text})
        end

        Btn.MouseButton1Down:Connect(paramsUpdate)
        Btn.MouseButton1Up:Connect(paramsReset)
        Btn.MouseLeave:Connect(paramsReset)

        Btn.MouseButton1Click:Connect(
            function()
                if config.Callback then
                    config.Callback()
                end
            end
        )

        if config.Tooltip and config.Tooltip ~= "" then
            AddTooltip(Btn, config.Tooltip)
        end

        local CursorIcon = nil
        if Lucide then
            pcall(
                function()
                    CursorIcon =
                        Lucide.ImageLabel(
                        "mouse-pointer-2",
                        14,
                        {
                            Parent = Btn,
                            AnchorPoint = Vector2.new(1, 0.5),
                            Position = UDim2.new(1, -12, 0.5, 0),
                            ImageColor3 = Library.Theme.TextDark,
                            BackgroundTransparency = 1
                        }
                    )
                end
            )
        end

        local btnObj = {
            Frame = Frame,
            Name = config.Name or "Button",
            SetText = function(t)
                Btn.Text = t
            end,
            SetCallback = function(c)
                config.Callback = c
            end,
            Fire = function()
                if config.Callback then
                    config.Callback()
                end
            end
        }

        local elementData = {
            Type = "button",
            Name = config.Name or "Button",
            Frame = Frame,
            Fire = function()
                if config.Callback then
                    config.Callback()
                end
            end
        }
        
        Library:RegisterElement(elementData)

        Btn.MouseButton2Click:Connect(
            function()
                Library:ShowElementContextMenu(elementData)
            end
        )

        table.insert(obj.Elements, btnObj)
        return btnObj
    end

    function obj:AddInput(config, default, callback)
        if type(config) == "string" then
            config = {Name = config, Default = default, Callback = callback}
        end
        local Frame, Stroke = CreateContainer(42, config.Tooltip, config.ContextMenu)

        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = config.Name or "Input"
        Label.Size = UDim2.new(0.35, -12, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Library.Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.TextTruncate = Enum.TextTruncate.AtEnd
        Library:RegisterTheme(Label, "TextColor3", "Text")

        local Input = Instance.new("TextBox")
        Input.Parent = Frame
        Input.Size = UDim2.new(0.65, -24, 0, 26)
        Input.Position = UDim2.new(0.35, 12, 0.5, -13)
        Input.BackgroundColor3 = Library.Theme.ToggleBg
        Input.BackgroundTransparency = 0
        Input.Text = config.Default or ""
        Input.PlaceholderText = config.Placeholder or "..."
        Input.TextColor3 = Library.Theme.Text
        Input.PlaceholderColor3 = Library.Theme.TextDark
        Input.Font = Enum.Font.Gotham
        Input.TextSize = 13
        Input.TextXAlignment = Enum.TextXAlignment.Left
        Input.ClipsDescendants = true
        Input.ClearTextOnFocus = false
        Library:RegisterTheme(Input, "TextColor3", "Text")
        Library:RegisterTheme(Input, "PlaceholderColor3", "TextDark")

        local InputCorner = Instance.new("UICorner")
        InputCorner.CornerRadius = UDim.new(0, 6)
        InputCorner.Parent = Input

        local InputStroke = Instance.new("UIStroke")
        InputStroke.Parent = Input
        InputStroke.Color = Library.Theme.Border
        InputStroke.Thickness = 1
        Library:RegisterTheme(InputStroke, "Color", "Border")

        local function Update()
            Tween(InputStroke, {0.2}, {Color = Library.Theme.Accent})
        end

        local function Reset()
            Tween(InputStroke, {0.2}, {Color = Library.Theme.Border})
        end

        Input.Focused:Connect(
            function()
                pcall(
                    function()
                        if Library.ResetTimer then Library.ResetTimer() end
                    end
                )
                Update()
            end
        )
        Input:GetPropertyChangedSignal("Text"):Connect(
            function()
                pcall(
                    function()
                        if Library.ResetTimer then Library.ResetTimer() end
                    end
                )
            end
        )
        local changedEvent = Library:CreateSignal()
        Input.FocusLost:Connect(
            function()
                pcall(
                    function()
                        if Library.ResetTimer then Library.ResetTimer() end
                    end
                )
                Reset()
                if config.Callback then
                    config.Callback(Input.Text)
                end
                if config.Flag then
                    Library.Flags[config.Flag] = Input.Text
                end
                changedEvent:Fire(Input.Text)
                Library:SaveConfigDebounced(
                    config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                    config.ConfigName or Library.ConfigSettings.Name or "Default"
                )
            end
        )

        if config.Flag and Library.Flags[config.Flag] then
            Input.Text = Library.Flags[config.Flag]
        end

        if config.Callback then
            config.Callback(Input.Text)
        end
        if config.Flag then
            Library.Flags[config.Flag] = Input.Text
        end

        local inputObj = {
            Frame = Frame,
            Name = config.Name or "Input",
            GetValue = function() return Input.Text end,
            SetValue = function(v)
                Input.Text = v
                if config.Callback then config.Callback(v) end
                if config.Flag then Library.Flags[config.Flag] = v end
                changedEvent:Fire(v)
            end,
            OnChanged = changedEvent
        }
        table.insert(obj.Elements, inputObj)
        return inputObj
    end

    function obj:AddToggle(config, default, callback)
        if type(config) == "string" then
            config = {Name = config, Default = default, Callback = callback}
        end
        local toggle = {Name = config.Name, Flag = config.Flag, Callback = config.Callback}
        local toggled = config.Default or false

        local Frame, Stroke = CreateContainer(42)

        local Btn = Instance.new("TextButton")
        Btn.Parent = Frame
        Btn.Size = UDim2.new(1, 0, 1, 0)
        Btn.BackgroundTransparency = 1
        Btn.Text = ""

        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = config.Name
        Label.Size = UDim2.new(1, -50, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Library.Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Library:RegisterTheme(Label, "TextColor3", "Text")

        local ToggleBox = Instance.new("Frame")
        ToggleBox.Parent = Frame
        ToggleBox.Size = UDim2.new(0, 20, 0, 20)
        ToggleBox.Position = UDim2.new(1, -32, 0.5, -10)
        ToggleBox.BackgroundColor3 = Library.Theme.ToggleBg
        local TkCorner = Instance.new("UICorner")
        TkCorner.CornerRadius = UDim.new(0, 6)
        TkCorner.Parent = ToggleBox

        local TkStroke = Instance.new("UIStroke")
        TkStroke.Parent = ToggleBox
        TkStroke.Color = Library.Theme.Border
        TkStroke.Thickness = 1
        Library:RegisterTheme(TkStroke, "Color", "Border")

        local Checkmark = nil
        if Lucide then
            pcall(function()
                Checkmark = Lucide.ImageLabel("check", 16, {
                    Parent = ToggleBox,
                    Position = UDim2.new(0.5, -8, 0.5, -8),
                    BackgroundTransparency = 1,
                    ImageTransparency = 1,
                    ImageColor3 = Color3.new(1, 1, 1)
                })
            end)
        end

        if not Checkmark then
            Checkmark = Instance.new("ImageLabel")
            Checkmark.Parent = ToggleBox
            Checkmark.Size = UDim2.new(0, 16, 0, 16)
            Checkmark.Position = UDim2.new(0.5, -8, 0.5, -8)
            Checkmark.BackgroundTransparency = 1
            Checkmark.Image = "rbxassetid://6031068433"
            Checkmark.ImageColor3 = Color3.new(1, 1, 1)
            Checkmark.ImageTransparency = 1
        end

        local changedEvent = Library:CreateSignal()

        local function Update()
            if toggled then
                Tween(ToggleBox, {0.2}, {BackgroundColor3 = Library.Theme.Accent})
                if Checkmark then Tween(Checkmark, {0.2}, {ImageTransparency = 0}) end
            else
                Tween(ToggleBox, {0.2}, {BackgroundColor3 = Library.Theme.ToggleBg})
                if Checkmark then Tween(Checkmark, {0.2}, {ImageTransparency = 1}) end
            end

            Tween(Stroke, {0.2}, {Color = Library.Theme.Border})

            if config.Callback then
                config.Callback(toggled)
            end
            if config.Flag then
                Library.Flags[config.Flag] = toggled
            end
            changedEvent:Fire(toggled)
        end

        table.insert(
            ThemeUpdateHooks,
            function()
                if toggled then
                    Tween(ToggleBox, {0.2}, {BackgroundColor3 = Library.Theme.Accent})
                else
                    Tween(ToggleBox, {0.2}, {BackgroundColor3 = Library.Theme.ToggleBg})
                end
            end
        )

        Btn.MouseButton1Click:Connect(
            function()
                toggled = not toggled
                Update()
                Library:SaveConfigDebounced(
                    config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                    config.ConfigName or Library.ConfigSettings.Name or "Default"
                )
            end
        )

        if config.Tooltip and config.Tooltip ~= "" then
            AddTooltip(Btn, config.Tooltip)
        end

        if config.Flag and Library.Flags[config.Flag] ~= nil then
            toggled = Library.Flags[config.Flag]
        end
        Update()

        local toggleObj = {
            Frame = Frame,
            Name = config.Name,
            GetValue = function() return toggled end,
            SetValue = function(val)
                toggled = val
                Update()
            end,
            Toggle = function()
                toggled = not toggled
                Update()
            end,
            OnChanged = changedEvent
        }
        local elementData = {
            Type = "toggle",
            Name = config.Name,
            Frame = Frame,
            Default = config.Default or false,
            Callback = config.Callback,
            GetValue = toggleObj.GetValue,
            SetValue = toggleObj.SetValue,
            Toggle = toggleObj.Toggle
        }
        Library:RegisterElement(elementData)

        Btn.MouseButton2Click:Connect(
            function()
                Library:ShowElementContextMenu(elementData)
            end
        )

        table.insert(obj.Elements, toggleObj)
        return toggleObj
    end

    function obj:AddSlider(config, min, max, default, callback)
        if type(config) == "string" then
            config = {Name = config, Min = min, Max = max, Default = default, Callback = callback}
        end
        local slider = {Name = config.Name, Flag = config.Flag, Callback = config.Callback}
        local min, max = config.Min or 0, config.Max or 100
        local value = config.Default or min
        local dragging = false

        local Frame, Stroke = CreateContainer(50, config.Tooltip, config.ContextMenu)

        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = config.Name
        Label.Size = UDim2.new(1, 0, 0, 20)
        Label.Position = UDim2.new(0, 12, 0, 8)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Library.Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Library:RegisterTheme(Label, "TextColor3", "Text")

        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Parent = Frame
        ValueLabel.Text = tostring(value)
        ValueLabel.Size = UDim2.new(0, 30, 0, 20)
        ValueLabel.Position = UDim2.new(1, -42, 0, 8)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.TextColor3 = Library.Theme.TextDark
        ValueLabel.Font = Enum.Font.Gotham
        ValueLabel.TextSize = 13
        ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
        Library:RegisterTheme(ValueLabel, "TextColor3", "TextDark")

        local SliderBg = Instance.new("Frame")
        SliderBg.Parent = Frame
        SliderBg.Size = UDim2.new(1, -24, 0, 8)
        SliderBg.Position = UDim2.new(0, 12, 0, 32)
        SliderBg.BackgroundColor3 = Library.Theme.ToggleBg
        local SCorner = Instance.new("UICorner")
        SCorner.CornerRadius = UDim.new(1, 0)
        SCorner.Parent = SliderBg

        local Fill = Instance.new("Frame")
        Fill.Parent = SliderBg
        Fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        Fill.BackgroundColor3 = Library.Theme.Accent
        local FCorner = Instance.new("UICorner")
        FCorner.CornerRadius = UDim.new(1, 0)
        FCorner.Parent = Fill
        Library:RegisterTheme(Fill, "BackgroundColor3", "Accent")

        Library:RegisterTheme(Fill, "BackgroundColor3", "Accent")

        local lastClick = 0
        local function CheckDoubleClick()
            if tick() - lastClick < 0.4 then
                local Box = Instance.new("TextBox")
                Box.Parent = Frame
                Box.Size = UDim2.new(0, 50, 0, 20)
                Box.Position = UDim2.new(1, -60, 0, 8)
                Box.BackgroundTransparency = 1
                Box.BackgroundColor3 = Library.Theme.Main
                Box.TextColor3 = Library.Theme.Text
                Box.Font = Enum.Font.Gotham
                Box.TextSize = 14
                Box.TextXAlignment = Enum.TextXAlignment.Right
                Box.Text = tostring(value)
                Box.ClipsDescendants = true

                ValueLabel.Visible = false
                Box:CaptureFocus()

                Box.FocusLost:Connect(
                    function()
                        local num = tonumber(Box.Text)
                        if num then
                            value = math.clamp(num, min, max)
                            local percent = (value - min) / (max - min)
                            Tween(Fill, {0.1}, {Size = UDim2.new(percent, 0, 1, 0)})
                            ValueLabel.Text = tostring(value)
                            if config.Callback then
                                config.Callback(value)
                            end
                            if config.Flag then
                                Library.Flags[config.Flag] = value
                            end
                        end
                        ValueLabel.Visible = true
                        Box:Destroy()
                        Library:SaveConfigDebounced(
                            config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                            config.ConfigName or Library.ConfigSettings.Name or "Default"
                        )
                    end
                )
            end
            lastClick = tick()
        end

        local InputBtn = Instance.new("TextButton")
        InputBtn.Parent = Frame
        InputBtn.Size = UDim2.new(1, 0, 0, 30)
        InputBtn.Position = UDim2.new(0, 0, 0, 0)
        InputBtn.BackgroundTransparency = 1
        InputBtn.Text = ""
        InputBtn.ZIndex = 1

        InputBtn.MouseButton1Click:Connect(CheckDoubleClick)

        local Trigger = Instance.new("TextButton")
        Trigger.Parent = SliderBg
        Trigger.Size = UDim2.new(1, 0, 1, 0)
        Trigger.BackgroundTransparency = 1
        Trigger.Text = ""
        Trigger.ZIndex = 3

        local function paramsUpdate()
            Tween(Stroke, {0.2}, {Color = Library.Theme.Accent})
        end

        local function paramsReset()
            Tween(Stroke, {0.2}, {Color = Library.Theme.Border})
        end

        local changedEvent = Library:CreateSignal()

        local function Update(input)
            local percent = math.clamp((input.Position.X - SliderBg.AbsolutePosition.X) / SliderBg.AbsoluteSize.X, 0, 1)
            value = math.floor(min + (max - min) * percent)

            Tween(Fill, {0.1}, {Size = UDim2.new(percent, 0, 1, 0)})
            ValueLabel.Text = tostring(value)
            if config.Callback then
                config.Callback(value)
            end
            if config.Flag then
                Library.Flags[config.Flag] = value
            end
            changedEvent:Fire(value)
        end

        local dragEndConn
        Trigger.InputBegan:Connect(
            function(input)
                if
                    input.UserInputType == Enum.UserInputType.MouseButton1 or
                        input.UserInputType == Enum.UserInputType.Touch
                 then
                    CheckDoubleClick()
                    dragging = true
                    paramsUpdate()
                    Update(input)

                    if dragEndConn then dragEndConn:Disconnect() end
                    dragEndConn = UserInputService.InputEnded:Connect(function(input2)
                        if input2.UserInputType == Enum.UserInputType.MouseButton1 or input2.UserInputType == Enum.UserInputType.Touch then
                            dragging = false
                            paramsReset()
                            dragEndConn:Disconnect()
                            dragEndConn = nil
                            
                            Library:SaveConfigDebounced(
                                config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                                config.ConfigName or Library.ConfigSettings.Name or "Default"
                            )
                        end
                    end)
                end
            end
        )

        local sliderInputConn = UserInputService.InputChanged:Connect(
            function(input)
                if
                    dragging and
                        (input.UserInputType == Enum.UserInputType.MouseMovement or
                            input.UserInputType == Enum.UserInputType.Touch)
                 then
                    Update(input)
                end
            end
        )
        local function cleanupSlider()
            if sliderInputConn then
                sliderInputConn:Disconnect()
                sliderInputConn = nil
            end
            if dragEndConn then
                dragEndConn:Disconnect()
                dragEndConn = nil
            end
            dragging = false
        end
        Frame.AncestryChanged:Connect(function()
            if not Frame.Parent then
                cleanupSlider()
            end
        end)

        if config.Flag and Library.Flags[config.Flag] then
            value = Library.Flags[config.Flag]
            local p = (value - min) / (max - min)
            Fill.Size = UDim2.new(p, 0, 1, 0)
            ValueLabel.Text = tostring(value)
        end

        slider.Frame = Frame
        slider.GetValue = function()
            return value
        end

        local sliderObj = {
            Frame = Frame,
            Name = config.Name,
            GetValue = function() return value end,
            SetValue = function(val)
                value = math.clamp(val, min, max)
                local percent = (value - min) / (max - min)
                Tween(Fill, {0.1}, {Size = UDim2.new(percent, 0, 1, 0)})
                ValueLabel.Text = tostring(value)
                if config.Callback then config.Callback(value) end
                if config.Flag then Library.Flags[config.Flag] = value end
                changedEvent:Fire(value)
            end,
            OnChanged = changedEvent
        }

        local elementData = {
            Type = "slider",
            Name = config.Name,
            Frame = Frame,
            Default = config.Default or min,
            Min = min,
            Max = max,
            Callback = config.Callback,
            GetValue = sliderObj.GetValue,
            SetValue = sliderObj.SetValue
        }
        Library:RegisterElement(elementData)

        InputBtn.MouseButton2Click:Connect(
            function()
                Library:ShowElementContextMenu(elementData)
            end
        )

        table.insert(obj.Elements, sliderObj)
        return sliderObj
    end

    function obj:AddInfo(config, content)
        if type(config) == "string" then
            config = {Title = config, Content = content}
        end
        local para = obj:AddParagraph(config)
        function para:Update(newConfig)
            if newConfig.Title then
                para:SetTitle(newConfig.Title)
            end
            if newConfig.Content then
                para:SetContent(newConfig.Content)
            end
        end
        return para
    end

    function obj:AddKeybind(config, default, callback)
        if type(config) == "string" then
            config = {Name = config, Default = default, Callback = callback}
        end
        local Frame, Stroke = CreateContainer(42, config.Tooltip, config.ContextMenu)

        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = config.Name or "Hotkey"
        Label.Size = UDim2.new(1, -110, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Library.Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Library:RegisterTheme(Label, "TextColor3", "Text")

        local KeyBtn = Instance.new("TextButton")
        KeyBtn.Parent = Frame
        KeyBtn.Size = UDim2.new(0, 100, 0, 26)
        KeyBtn.Position = UDim2.new(1, -112, 0.5, -13)
        KeyBtn.BackgroundColor3 = Library.Theme.ToggleBg
        KeyBtn.TextColor3 = Library.Theme.TextDark
        KeyBtn.Font = Enum.Font.Gotham
        KeyBtn.TextSize = 13
        KeyBtn.Text = "[ None ]"

        local KCorner = Instance.new("UICorner")
        KCorner.CornerRadius = UDim.new(0, 6)
        KCorner.Parent = KeyBtn

        local currentKey = config.Default
        local listening = false
        local changedEvent = Library:CreateSignal()

        local function UpdateText()
            if listening then
                KeyBtn.Text = "..."
                KeyBtn.TextColor3 = Library.Theme.Accent
            else
                local name = (currentKey and currentKey.Name) or "None"
                KeyBtn.Text = "[ " .. name .. " ]"
                KeyBtn.TextColor3 = Library.Theme.TextDark
            end
        end

        if currentKey then
            UpdateText()
        end

        local hkData = {Key = currentKey, Callback = config.Callback}

        table.insert(Library.Hotkeys, hkData)

        KeyBtn.MouseButton1Click:Connect(
            function()
                listening = true
                UpdateText()
            end
        )

        local inputBeganConn = UserInputService.InputBegan:Connect(
            function(input)
                if listening then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode == Enum.KeyCode.Escape then
                            currentKey = nil
                        elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                            currentKey = input.KeyCode
                        else
                            return
                        end

                        listening = false
                        hkData.Key = currentKey
                        UpdateText()

                        if config.Flag then
                            Library.Flags[config.Flag] = currentKey and currentKey.Name or "None"
                            Library:SaveConfigDebounced(
                                config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                                config.ConfigName or Library.ConfigSettings.Name or "Default"
                            )
                        end
                    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        listening = false
                        UpdateText()
                    end
                end
            end
        )

        Frame.AncestryChanged:Connect(function()
            if not Frame.Parent then
                inputBeganConn:Disconnect()
                for i, hk in ipairs(Library.Hotkeys) do
                    if hk == hkData then
                        table.remove(Library.Hotkeys, i)
                        break
                    end
                end
            end
        end)

        if config.Flag and Library.Flags[config.Flag] then
            local keyName = Library.Flags[config.Flag]
            local key = Enum.KeyCode[keyName]
            if key then
                currentKey = key
                hkData.Key = key
                UpdateText()
            end
        end

        local hkObj = {
            Frame = Frame,
            Name = config.Name,
            SetCallback = function(c)
                hkData.Callback = c
            end,
            SetValue = function(self, key)
                currentKey = key
                hkData.Key = key
                UpdateText()
                if config.Flag then Library.Flags[config.Flag] = key.Name end
                changedEvent:Fire(key)
            end,
            GetValue = function(self)
                return currentKey
            end,
            OnChanged = changedEvent
        }
        table.insert(obj.Elements, hkObj)
        return hkObj
    end

    function obj:AddDropdown(config, options, default, callback)
        if type(config) == "string" then
            config = {Name = config, Options = options, Default = default, Callback = callback}
        end
        local drop = {Name = config.Name, Flag = config.Flag, Options = config.Options or {}, Multi = config.Multi}
        local selected = config.Default or (drop.Multi and {}) or drop.Options[1]
        local expanded = false

        local Frame, Stroke = CreateContainer(42, config.Tooltip, config.ContextMenu)
        Frame.ClipsDescendants = true

        local TopBtn = Instance.new("TextButton")
        TopBtn.Parent = Frame
        TopBtn.Size = UDim2.new(1, 0, 0, 42)
        TopBtn.BackgroundTransparency = 1
        TopBtn.Text = ""

        local Label = Instance.new("TextLabel")
        Label.Parent = TopBtn
        Label.Text = config.Name
        Label.Size = UDim2.new(0.5, 0, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Library.Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Library:RegisterTheme(Label, "TextColor3", "Text")

        local SelectedLabel = Instance.new("TextLabel")
        SelectedLabel.Parent = TopBtn
        SelectedLabel.Text = tostring(selected)
        SelectedLabel.Size = UDim2.new(0.5, -40, 1, 0)
        SelectedLabel.Position = UDim2.new(0.5, 0, 0, 0)
        SelectedLabel.BackgroundTransparency = 1
        SelectedLabel.TextColor3 = Library.Theme.TextDark
        SelectedLabel.Font = Enum.Font.Gotham
        SelectedLabel.TextSize = 13
        SelectedLabel.TextXAlignment = Enum.TextXAlignment.Right
        Library:RegisterTheme(SelectedLabel, "TextColor3", "TextDark")

        local Arrow = Instance.new("TextLabel")
        Arrow.Parent = TopBtn
        Arrow.Size = UDim2.new(0, 20, 1, 0)
        Arrow.Position = UDim2.new(1, -30, 0, 0)
        Arrow.BackgroundTransparency = 1
        Arrow.Text = ">"
        Arrow.TextColor3 = Library.Theme.Text
        Arrow.Font = Enum.Font.GothamBold
        Library:RegisterTheme(Arrow, "TextColor3", "Text")

        local OptionContainer = Instance.new("Frame")
        OptionContainer.Parent = Frame
        OptionContainer.Size = UDim2.new(1, -24, 0, 0)
        OptionContainer.Position = UDim2.new(0, 12, 0, 42)
        OptionContainer.BackgroundTransparency = 1

        local Layout = Instance.new("UIListLayout")
        Layout.Parent = OptionContainer
        Layout.Padding = UDim.new(0, 4)

        local searchQuery = ""
        local SearchBox = Instance.new("TextBox")
        SearchBox.Parent = Frame
        SearchBox.Size = UDim2.new(1, -24, 0, 24)
        SearchBox.Position = UDim2.new(0, 12, 0, 42)
        SearchBox.BackgroundColor3 = Library.Theme.ElementBg
        SearchBox.TextColor3 = Library.Theme.Text
        SearchBox.PlaceholderText = "Search..."
        SearchBox.PlaceholderColor3 = Library.Theme.TextDark
        SearchBox.Font = Enum.Font.Gotham
        SearchBox.TextSize = 13
        SearchBox.Text = ""
        Library:RegisterTheme(SearchBox, "TextColor3", "Text")
        Library:RegisterTheme(SearchBox, "PlaceholderColor3", "TextDark")
        SearchBox.TextXAlignment = Enum.TextXAlignment.Left
        SearchBox.Visible = false
        SearchBox.ClearTextOnFocus = false
        local SC = Instance.new("UICorner", SearchBox)
        SC.CornerRadius = UDim.new(0, 6)
        local SP = Instance.new("UIPadding", SearchBox)
        SP.PaddingLeft = UDim.new(0, 8)

        local optionsOffset = 42 + 30 
        OptionContainer.Position = UDim2.new(0, 12, 0, optionsOffset)

        local function UpdateSelectedDisplay()
            if drop.Multi then
                local count = 0
                local lastName = ""
                for k, v in pairs(selected) do
                    if v then
                        count = count + 1
                        lastName = k
                    end
                end
                
                if count == 0 then
                    SelectedLabel.Text = "None"
                elseif count == 1 then
                    SelectedLabel.Text = tostring(lastName)
                else
                    SelectedLabel.Text = count .. " selected"
                end
            else
                SelectedLabel.Text = tostring(selected)
            end
        end

        if drop.Multi then
            UpdateSelectedDisplay()
        end

        local function RefreshOptions()
            for _, v in pairs(OptionContainer:GetChildren()) do
                if v:IsA("TextButton") then
                    v:Destroy()
                end
            end

            for _, opt in pairs(drop.Options) do
                local optStr = tostring(opt)
                if searchQuery ~= "" and not optStr:lower():find(searchQuery, 1, true) then
                    continue
                end

                local btn = Instance.new("TextButton")
                btn.Parent = OptionContainer
                btn.Size = UDim2.new(1, 0, 0, 26)
                btn.BackgroundColor3 = Library.Theme.Secondary
                btn.Text = optStr
                btn.TextColor3 = Library.Theme.TextDark
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 13
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.ZIndex = 5
                local C = Instance.new("UICorner")
                C.CornerRadius = UDim.new(0, 6)
                C.Parent = btn
                local P = Instance.new("UIPadding")
                P.PaddingLeft = UDim.new(0, 10)
                P.Parent = btn

                local isSelected = drop.Multi and selected[opt] or (selected == opt)
                if isSelected then
                    btn.TextColor3 = Library.Theme.Accent
                end

                btn.MouseButton1Click:Connect(
                    function()
                        if drop.Multi then
                            selected[opt] = not selected[opt]
                            UpdateSelectedDisplay()
                            RefreshOptions()
                        else
                            selected = opt
                            SelectedLabel.Text = optStr
                            expanded = false
                            SearchBox.Visible = false
                            SearchBox.Text = ""
                            searchQuery = ""
                            Tween(Frame, {0.3}, {Size = UDim2.new(1, 0, 0, 42)})
                            Tween(Arrow, {0.3}, {Rotation = 0})
                            Tween(Stroke, {0.3}, {Color = Library.Theme.Border})
                        end

                        if config.Callback then
                            config.Callback(selected)
                        end
                        if config.Flag then
                            Library.Flags[config.Flag] = selected
                        end
                        Library:SaveConfigDebounced(
                            config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                            config.ConfigName or Library.ConfigSettings.Name or "Default"
                        )
                    end
                )
            end
        end

        SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
            searchQuery = SearchBox.Text:lower()
            if expanded then RefreshOptions() end
        end)

        local function UpdateSize()
            if expanded then
                local contentY = Layout.AbsoluteContentSize.Y
                OptionContainer.Size = UDim2.new(1, -24, 0, contentY + 5)
                Tween(Frame, {0.2}, {Size = UDim2.new(1, 0, 0, optionsOffset + contentY + 5)})
            else
                Tween(Frame, {0.3}, {Size = UDim2.new(1, 0, 0, 42)})
            end
        end

        Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateSize)

        TopBtn.MouseButton1Click:Connect(
            function()
                expanded = not expanded
                if expanded then
                    SearchBox.Visible = true
                    SearchBox.ZIndex = 10
                    RefreshOptions()
                    UpdateSize()
                    Tween(Arrow, {0.3}, {Rotation = 90})
                    Tween(Stroke, {0.3}, {Color = Library.Theme.Accent})
                else
                    SearchBox.Visible = false
                    SearchBox.Text = ""
                    searchQuery = ""
                    UpdateSize()
                    Tween(Arrow, {0.3}, {Rotation = 0})
                    Tween(Stroke, {0.3}, {Color = Library.Theme.Border})
                end
            end
        )

        if config.Flag and Library.Flags[config.Flag] then
            selected = Library.Flags[config.Flag]
            if drop.Multi then
                UpdateSelectedDisplay()
            else
                SelectedLabel.Text = tostring(selected)
            end
        end

        local changedEvent = Library:CreateSignal()

        drop.Frame = Frame
        drop.GetValue = function() return selected end
        drop.SetValue = function(val, silent)
            selected = val
            if drop.Multi then
                UpdateSelectedDisplay()
            else
                SelectedLabel.Text = tostring(val)
            end
            if config.Flag then Library.Flags[config.Flag] = selected end
            if not silent then
                if config.Callback then config.Callback(selected) end
                changedEvent:Fire(selected)
            end
        end
        drop.OnChanged = changedEvent
        drop.Refresh = function(newOpts)
            drop.Options = newOpts
            if expanded then
                RefreshOptions()
                Tween(Frame, {0.3}, {Size = UDim2.new(1, 0, 0, optionsOffset + OptionContainer.Size.Y.Offset)})
            end
        end
        table.insert(obj.Elements, drop)
        return drop
    end

    function obj:AddColorPicker(config, default, callback)
        if type(config) == "string" then
            config = {Name = config, Default = default, Callback = callback}
        end
        local picker = {Name = config.Name, Flag = config.Flag, Callback = config.Callback}
        local defaultColor = config.Default or Color3.fromRGB(255, 255, 255)
        local h, s, v = defaultColor:ToHSV()
        local color = defaultColor
        local changedEvent = Library:CreateSignal()

        local Frame, Stroke = CreateContainer(42, config.Tooltip, config.ContextMenu)

        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = config.Name or "Color Picker"
        Label.Size = UDim2.new(1, -60, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Library.Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Library:RegisterTheme(Label, "TextColor3", "Text")

        local ColorBtn = Instance.new("TextButton")
        ColorBtn.Parent = Frame
        ColorBtn.Size = UDim2.new(0, 36, 0, 20)
        ColorBtn.Position = UDim2.new(1, -48, 0.5, -10)
        ColorBtn.BackgroundColor3 = color
        ColorBtn.Text = ""

        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 6)
        Corner.Parent = ColorBtn

        ColorBtn.MouseButton1Click:Connect(
            function()
                local Context =
                    Library:CreateContextWindow(
                    {
                        Title = "Pick Color",
                        Size = UDim2.fromOffset(280, 400)
                    }
                )

                local Container = Context.Container
                local CPadding = Container:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding", Container)
                CPadding.PaddingBottom = UDim.new(0, 10)

                local SVMap = Instance.new("TextButton")
                SVMap.Name = "SVMap"
                SVMap.Parent = Container
                SVMap.Size = UDim2.new(1, -10, 0, 150)
                SVMap.Position = UDim2.new(0, 5, 0, 0)
                SVMap.BackgroundColor3 = Color3.new(1, 1, 1)
                SVMap.BorderSizePixel = 0
                SVMap.Text = ""
                SVMap.AutoButtonColor = false

                local SatGradient = Instance.new("UIGradient")
                SatGradient.Color =
                    ColorSequence.new(
                    {
                        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1))
                    }
                )

                SVMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)

                local SatOverlay = Instance.new("Frame")
                SatOverlay.Name = "SatOverlay"
                SatOverlay.Parent = SVMap
                SatOverlay.Size = UDim2.new(1, 0, 1, 0)
                SatOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
                SatOverlay.BorderSizePixel = 0

                local SatGrad = Instance.new("UIGradient")
                SatGrad.Transparency =
                    NumberSequence.new(
                    {
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1)
                    }
                )
                SatGrad.Parent = SatOverlay

                local ValOverlay = Instance.new("Frame")
                ValOverlay.Name = "ValOverlay"
                ValOverlay.Parent = SVMap
                ValOverlay.Size = UDim2.new(1, 0, 1, 0)
                ValOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
                ValOverlay.BorderSizePixel = 0
                ValOverlay.ZIndex = 2

                local ValGrad = Instance.new("UIGradient")
                ValGrad.Transparency =
                    NumberSequence.new(
                    {
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0)
                    }
                )
                ValGrad.Rotation = 90
                ValGrad.Parent = ValOverlay

                local SVCursor = Instance.new("Frame")
                SVCursor.Name = "Cursor"
                SVCursor.Parent = ValOverlay
                SVCursor.Size = UDim2.new(0, 10, 0, 10)
                SVCursor.AnchorPoint = Vector2.new(0.5, 0.5)
                SVCursor.BackgroundColor3 = Color3.new(1, 1, 1)
                SVCursor.BackgroundTransparency = 0
                SVCursor.BorderColor3 = Color3.new(0, 0, 0)
                SVCursor.BorderSizePixel = 0
                SVCursor.ZIndex = 3
                local SVCr = Instance.new("UICorner")
                SVCr.CornerRadius = UDim.new(1, 0)
                SVCr.Parent = SVCursor
                local SVIn = Instance.new("Frame")
                SVIn.Size = UDim2.new(1, -2, 1, -2)
                SVIn.Position = UDim2.new(0, 1, 0, 1)
                SVIn.BackgroundColor3 = color
                SVIn.ZIndex = 4
                local SVInCr = Instance.new("UICorner")
                SVInCr.CornerRadius = UDim.new(1, 0)
                SVInCr.Parent = SVIn
                SVIn.Parent = SVCursor

                SVCursor.BackgroundTransparency = 1
                local Ring = Instance.new("UIStroke")
                Ring.Parent = SVCursor
                Ring.Thickness = 2
                Ring.Color = Color3.new(1, 1, 1)

                local HueSlider = Instance.new("TextButton")
                HueSlider.Name = "HueSlider"
                HueSlider.Parent = Container
                HueSlider.Size = UDim2.new(1, -10, 0, 20)
                HueSlider.BackgroundColor3 = Color3.new(1, 1, 1)
                HueSlider.BorderSizePixel = 0
                HueSlider.Text = ""
                HueSlider.AutoButtonColor = false

                local HueGrad = Instance.new("UIGradient")
                HueGrad.Color =
                    ColorSequence.new(
                    {
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
                        ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167, 1, 1)),
                        ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333, 1, 1)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
                        ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667, 1, 1)),
                        ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833, 1, 1)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1))
                    }
                )
                HueGrad.Parent = HueSlider

                local HueCursor = Instance.new("Frame")
                HueCursor.Parent = HueSlider
                HueCursor.Size = UDim2.new(0, 8, 1, 4)
                HueCursor.Position = UDim2.new(h, -4, 0, -2)
                HueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
                HueCursor.BorderSizePixel = 0
                local HCr = Instance.new("UICorner")
                HCr.CornerRadius = UDim.new(0, 6)
                HCr.Parent = HueCursor
                local HStr = Instance.new("UIStroke")
                HStr.Parent = HueCursor
                HStr.Thickness = 1
                HStr.Color = Color3.new(0.2, 0.2, 0.2)

                local InputFrame = Instance.new("Frame")
                InputFrame.Parent = Container
                InputFrame.Size = UDim2.new(1, -10, 0, 30)
                InputFrame.BackgroundTransparency = 1

                local HexInput = Instance.new("TextBox")
                HexInput.Parent = InputFrame
                HexInput.Size = UDim2.new(0.4, 0, 1, 0)
                HexInput.Position = UDim2.new(0, 0, 0, 0)
                HexInput.BackgroundColor3 = Library.Theme.ElementBg
                HexInput.TextColor3 = Library.Theme.Text
                HexInput.Text = color:ToHex()
                HexInput.Font = Enum.Font.Gotham
                HexInput.TextSize = 13
                local HexC = Instance.new("UICorner")
                HexC.CornerRadius = UDim.new(0, 6)
                HexC.Parent = HexInput

                local function CreateRGBInput(name, x)
                    local Box = Instance.new("TextBox")
                    Box.Parent = InputFrame
                    Box.Size = UDim2.new(0.18, 0, 1, 0)
                    Box.Position = UDim2.new(0.42 + x * 0.2, 0, 0, 0)
                    Box.BackgroundColor3 = Library.Theme.ElementBg
                    Box.TextColor3 = Library.Theme.Text
                    Box.PlaceholderText = name
                    Box.Text = math.floor((name == "R" and color.R or name == "G" and color.G or color.B) * 255)
                    Box.Font = Enum.Font.Gotham
                    Box.TextSize = 13
                    local C = Instance.new("UICorner")
                    C.CornerRadius = UDim.new(0, 6)
                    C.Parent = Box
                    return Box
                end
                local RBox = CreateRGBInput("R", 0)
                local GBox = CreateRGBInput("G", 1)
                local BBox = CreateRGBInput("B", 2)

                local PresetsLabel = Instance.new("TextLabel")
                PresetsLabel.Parent = Container
                PresetsLabel.Text = "Presets"
                PresetsLabel.Size = UDim2.new(1, -10, 0, 20)
                PresetsLabel.BackgroundTransparency = 1
                PresetsLabel.TextColor3 = Library.Theme.TextDark
                PresetsLabel.Font = Enum.Font.GothamBold
                PresetsLabel.TextSize = 12
                PresetsLabel.TextXAlignment = Enum.TextXAlignment.Left
                PresetsLabel.Position = UDim2.new(0, 5, 0, 0)

                local PresetContainer = Instance.new("ScrollingFrame")
                PresetContainer.Parent = Container
                PresetContainer.Size = UDim2.new(1, -10, 0, 35)
                PresetContainer.BackgroundTransparency = 1
                PresetContainer.ScrollBarThickness = 2
                PresetContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

                local PresetLayout = Instance.new("UIListLayout")
                PresetLayout.Parent = PresetContainer
                PresetLayout.FillDirection = Enum.FillDirection.Horizontal
                PresetLayout.Padding = UDim.new(0, 5)
                PresetLayout.SortOrder = Enum.SortOrder.LayoutOrder

                local function UpdateColor(newColor)
                    color = newColor
                    ColorBtn.BackgroundColor3 = color
                    if config.Callback then
                        config.Callback(color)
                    end
                    if config.Flag then
                        Library.Flags[config.Flag] = {R = color.R, G = color.G, B = color.B}
                        Library:SaveConfigDebounced(
                            config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                            config.ConfigName or Library.ConfigSettings.Name or "Default"
                        )
                    end

                    HexInput.Text = "#" .. color:ToHex()
                    RBox.Text = math.floor(color.R * 255)
                    GBox.Text = math.floor(color.G * 255)
                    BBox.Text = math.floor(color.B * 255)
                end

                local function UpdateUI(updateInputs)
                    color = Color3.fromHSV(h, s, v)
                    SVMap.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    SVCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                    HueCursor.Position = UDim2.new(h, -4, 0, -2)

                    ColorBtn.BackgroundColor3 = color

                    if updateInputs then
                        HexInput.Text = "#" .. color:ToHex()
                        RBox.Text = math.floor(color.R * 255)
                        GBox.Text = math.floor(color.G * 255)
                        BBox.Text = math.floor(color.B * 255)
                    end

                    if config.Callback then
                        config.Callback(color)
                    end
                    if config.Flag then
                        Library.Flags[config.Flag] = {R = color.R, G = color.G, B = color.B}
                        Library:SaveConfigDebounced(
                            config.ConfigFolder or Library.ConfigSettings.Folder or "LuneConfigs",
                            config.ConfigName or Library.ConfigSettings.Name or "Default"
                        )
                    end
                end

                SVCursor.Position = UDim2.new(s, 0, 1 - v, 0)

                local draggingSV = false
                SVMap.InputBegan:Connect(
                    function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            draggingSV = true
                            local p =
                                math.clamp((input.Position.X - SVMap.AbsolutePosition.X) / SVMap.AbsoluteSize.X, 0, 1)
                            local y =
                                math.clamp((input.Position.Y - SVMap.AbsolutePosition.Y) / SVMap.AbsoluteSize.Y, 0, 1)
                            s = p
                            v = 1 - y
                            UpdateUI(true)
                        end
                    end
                )
                SVMap.InputEnded:Connect(
                    function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            draggingSV = false
                        end
                    end
                )
                local svInputChangedConn = UserInputService.InputChanged:Connect(
                    function(input)
                        if draggingSV and input.UserInputType == Enum.UserInputType.MouseMovement then
                            local p =
                                math.clamp((input.Position.X - SVMap.AbsolutePosition.X) / SVMap.AbsoluteSize.X, 0, 1)
                            local y =
                                math.clamp((input.Position.Y - SVMap.AbsolutePosition.Y) / SVMap.AbsoluteSize.Y, 0, 1)
                            s = p
                            v = 1 - y
                            UpdateUI(true)
                        end
                    end
                )
                table.insert(Context._cleanup, function() svInputChangedConn:Disconnect() end)

                local draggingHue = false
                HueSlider.InputBegan:Connect(
                    function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            draggingHue = true
                            local p =
                                math.clamp(
                                (input.Position.X - HueSlider.AbsolutePosition.X) / HueSlider.AbsoluteSize.X,
                                0,
                                1
                            )
                            h = p
                            UpdateUI(true)
                        end
                    end
                )
                HueSlider.InputEnded:Connect(
                    function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            draggingHue = false
                        end
                    end
                )
                local hueInputChangedConn = UserInputService.InputChanged:Connect(
                    function(input)
                        if draggingHue and input.UserInputType == Enum.UserInputType.MouseMovement then
                            local p =
                                math.clamp(
                                (input.Position.X - HueSlider.AbsolutePosition.X) / HueSlider.AbsoluteSize.X,
                                0,
                                1
                            )
                            h = p
                            UpdateUI(true)
                        end
                    end
                )
                table.insert(Context._cleanup, function() hueInputChangedConn:Disconnect() end)

                HexInput.FocusLost:Connect(
                    function()
                        local txt = HexInput.Text:gsub("#", "")

                        if #txt == 6 then
                            local r = tonumber("0x" .. txt:sub(1, 2))
                            local g = tonumber("0x" .. txt:sub(3, 4))
                            local b = tonumber("0x" .. txt:sub(5, 6))
                            if r and g and b then
                                color = Color3.fromRGB(r, g, b)
                                h, s, v = color:ToHSV()
                                UpdateUI(false)
                            end
                        end
                    end
                )

                local function UpdateFromRGB()
                    local r = tonumber(RBox.Text)
                    local g = tonumber(GBox.Text)
                    local b = tonumber(BBox.Text)
                    if r and g and b then
                        color = Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
                        h, s, v = color:ToHSV()
                        UpdateUI(true)
                    end
                end

                RBox.FocusLost:Connect(UpdateFromRGB)
                GBox.FocusLost:Connect(UpdateFromRGB)
                BBox.FocusLost:Connect(UpdateFromRGB)

                local function RefreshPresets()
                    for _, v in pairs(PresetContainer:GetChildren()) do
                        if v:IsA("TextButton") then
                            v:Destroy()
                        end
                    end

                    local AddBtn = Instance.new("TextButton")
                    AddBtn.Parent = PresetContainer
                    AddBtn.Size = UDim2.new(0, 30, 0, 30)
                    AddBtn.BackgroundColor3 = Library.Theme.ElementBg
                    AddBtn.Text = "+"
                    AddBtn.TextColor3 = Library.Theme.TextDark
                    AddBtn.TextSize = 18
                    AddBtn.Font = Enum.Font.GothamBold
                    AddBtn.LayoutOrder = 999
                    local C = Instance.new("UICorner")
                    C.CornerRadius = UDim.new(0, 6)
                    C.Parent = AddBtn

                    AddBtn.MouseButton1Click:Connect(
                        function()
                            table.insert(Library.ColorPresets, color)
                            RefreshPresets()
                        end
                    )

                    for i, pColor in ipairs(Library.ColorPresets) do
                        local pBtn = Instance.new("TextButton")
                        pBtn.Parent = PresetContainer
                        pBtn.Size = UDim2.new(0, 30, 0, 30)
                        pBtn.BackgroundColor3 = pColor
                        pBtn.Text = ""
                        pBtn.LayoutOrder = i
                        local C2 = Instance.new("UICorner")
                        C2.CornerRadius = UDim.new(0, 6)
                        C2.Parent = pBtn

                        pBtn.MouseButton1Click:Connect(
                            function()
                                local newH, newS, newV = pColor:ToHSV()
                                h, s, v = newH, newS, newV
                                UpdateUI(true)
                            end
                        )

                        pBtn.MouseButton2Click:Connect(
                            function()
                                table.remove(Library.ColorPresets, i)
                                RefreshPresets()
                            end
                        )
                    end
                    PresetContainer.CanvasSize = UDim2.new(0, PresetLayout.AbsoluteContentSize.X, 0, 0)
                end
                RefreshPresets()
            end
        )

        if config.Flag and Library.Flags[config.Flag] then
            local c = Library.Flags[config.Flag]

            if typeof(c) == "table" and c.R then
                color = Color3.new(c.R, c.G, c.B)
            end
            ColorBtn.BackgroundColor3 = color
            h, s, v = color:ToHSV()
            if config.Callback then
                config.Callback(color)
            end
        end

        picker.Frame = Frame
        picker.ColorBtn = ColorBtn
        function picker:SetColor(newColor)
            color = newColor
            h, s, v = newColor:ToHSV()
            ColorBtn.BackgroundColor3 = newColor
            if config.Flag then
                Library.Flags[config.Flag] = newColor
            end
        end

        function picker:SetValue(newColor)
            self:SetColor(newColor)
            if config.Callback then config.Callback(newColor) end
            changedEvent:Fire(newColor)
        end

        function picker:GetValue()
            return color
        end

        picker.OnChanged = changedEvent
        
        table.insert(obj.Elements, {Frame = Frame, Name = config.Name, SetValue = function(v) picker:SetValue(v) end, GetValue = function() return picker:GetValue() end})
        return picker
    end
    function obj:AddLabel(config)
        if type(config) == "string" then
            config = {Text = config}
        end
        local Frame, Stroke = CreateContainer(26)

        local Label = Instance.new("TextLabel")
        Label.Parent = Frame
        Label.Text = config.Text or "Label"
        Label.Size = UDim2.new(1, -24, 1, 0)
        Label.Position = UDim2.new(0, 12, 0, 0)
        Label.BackgroundTransparency = 1
        Label.TextColor3 = Library.Theme.Text
        Label.Font = Enum.Font.Gotham
        Label.TextSize = 14
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Library:RegisterTheme(Label, "TextColor3", "Text")

        local labelObj = {
            Frame = Frame,
            Name = config.Text or "Label",
            SetText = function(t)
                Label.Text = t
            end
        }
        table.insert(obj.Elements, labelObj)
        return labelObj
    end

    function obj:AddParagraph(config, content)
        if type(config) == "string" then
            config = {Title = config, Content = content}
        end
        local Frame, Stroke = CreateContainer(0)
        Frame.AutomaticSize = Enum.AutomaticSize.Y

        local Title = Instance.new("TextLabel")
        Title.Parent = Frame
        Title.Text = config.Title or "Paragraph"
        Title.Size = UDim2.new(1, -24, 0, 18)
        Title.Position = UDim2.new(0, 12, 0, 6)
        Title.BackgroundTransparency = 1
        Title.TextColor3 = Library.Theme.Text
        Title.Font = Enum.Font.GothamBold
        Title.TextSize = 14
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Library:RegisterTheme(Title, "TextColor3", "Text")

        local Content = Instance.new("TextLabel")
        Content.Parent = Frame
        Content.Text = config.Content or ""
        Content.Size = UDim2.new(1, -24, 0, 0)
        Content.Position = UDim2.new(0, 12, 0, 24)
        Content.BackgroundTransparency = 1
        Content.TextColor3 = Library.Theme.TextDark
        Content.Font = Enum.Font.Gotham
        Content.TextSize = 13
        Content.TextXAlignment = Enum.TextXAlignment.Left
        Content.TextWrapped = true
        Content.AutomaticSize = Enum.AutomaticSize.Y
        Library:RegisterTheme(Content, "TextColor3", "TextDark")

        local Pad = Instance.new("UIPadding")
        Pad.Parent = Frame
        Pad.PaddingBottom = UDim.new(0, 6)

        table.insert(obj.Elements, {Frame = Frame, Name = config.Title or "Paragraph"})
        return {
            Frame = Frame,
            SetTitle = function(t)
                Title.Text = t
            end,
            SetContent = function(c)
                Content.Text = c
            end
        }
    end

    function obj:AddDivider()
        local Frame = Instance.new("Frame")
        Frame.Parent = container
        Frame.Size = UDim2.new(1, 0, 0, 2)
        Frame.BackgroundColor3 = Library.Theme.Border
        Frame.BorderSizePixel = 0

        Library:RegisterTheme(Frame, "BackgroundColor3", "Border")

        table.insert(obj.Elements, {Frame = Frame, Name = "Divider"})
        return Frame
    end
end

function Library:CreateWindow(config)
    config = config or {}
    config.Title = config.Title or "Lune"
    config.Size = config.Size or UDim2.fromOffset(600, 450)
    config.ConfigFolder = config.ConfigFolder or "LuneConfigs"
    config.ConfigName = config.ConfigName or "Default"
    local defaultConfigName = Library:LoadDefaultConfigName(config.ConfigFolder)
    local configToLoad = defaultConfigName or config.ConfigName
    
    Library.ConfigSettings = {Folder = config.ConfigFolder, Name = configToLoad}
    Library:LoadConfig(config.ConfigFolder, configToLoad)

    local guiName = "LuneUI_" .. config.Title:gsub("%s+", "")
    local function cleanup(parent)
        if parent then
            for _, c in pairs(parent:GetChildren()) do
                if c.Name == guiName then
                    c:Destroy()
                end
            end
        end
    end
    cleanup(CoreGui)
    cleanup(LocalPlayer:FindFirstChild("PlayerGui"))

    local gui = Instance.new("ScreenGui")
    gui.Name = guiName
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ProtectGui(gui)

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = gui
    MainFrame.Size = config.Size
    MainFrame.AnchorPoint = Vector2.new(0.5, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
    MainFrame.BackgroundColor3 = Library.Theme.Main
    MainFrame.BorderSizePixel = 0
    Library:RegisterTheme(MainFrame, "BackgroundColor3", "Main")
    Library.MainFrame = MainFrame
    if Library.WindowPositions.MainWindow then
        local pos = Library.WindowPositions.MainWindow
        MainFrame.Position = UDim2.new(pos.XScale, pos.XOffset, pos.YScale, pos.YOffset)
    end

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Parent = MainFrame
    MainStroke.Color = Library.Theme.Accent
    MainStroke.Thickness = 2
    MainStroke.Transparency = 0
    Library:RegisterTheme(MainStroke, "Color", "Accent")

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 8)
    MainCorner.Parent = MainFrame

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Parent = MainFrame
    TopBar.Size = UDim2.new(1, 0, 0, 45)
    TopBar.BackgroundColor3 = Library.Theme.Secondary
    TopBar.BorderSizePixel = 0
    TopBar.ClipsDescendants = true
    Library:RegisterTheme(TopBar, "BackgroundColor3", "Secondary")

    local TopGradient = Instance.new("UIGradient")
    TopGradient.Parent = TopBar
    TopGradient.Rotation = 90
    TopGradient.Color =
        ColorSequence.new(
        {
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(0.95, 0.95, 0.95))
        }
    )

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 8)
    TopCorner.Parent = TopBar

    local TopCover = Instance.new("Frame")
    TopCover.Parent = TopBar
    TopCover.Size = UDim2.new(1, 0, 0, 10)
    TopCover.Position = UDim2.new(0, 0, 1, -10)
    TopCover.BackgroundColor3 = Library.Theme.Secondary
    TopCover.BorderSizePixel = 0
    Library:RegisterTheme(TopCover, "BackgroundColor3", "Secondary")

    local Title = Instance.new("TextLabel")
    Title.Parent = TopBar
    Title.Text = config.Title
    Title.Size = UDim2.new(0.5, 0, 1, 0)
    Title.Position = UDim2.new(0, 14, 0, 0)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextColor3 = Library.Theme.Text
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Library:RegisterTheme(Title, "TextColor3", "Text")

    local SearchBar = Instance.new("TextBox")
    SearchBar.Parent = TopBar
    SearchBar.Size = UDim2.new(0, 180, 0, 30)
    SearchBar.Position = UDim2.new(1, -210, 0.5, -15)
    SearchBar.AnchorPoint = Vector2.new(0, 0)
    SearchBar.BackgroundColor3 = Library.Theme.Main
    SearchBar.TextColor3 = Library.Theme.Text
    SearchBar.Text = ""
    SearchBar.PlaceholderText = "Search..."
    SearchBar.PlaceholderColor3 = Library.Theme.TextDark
    SearchBar.Font = Enum.Font.Gotham
    SearchBar.TextSize = 14

    local SearchStroke = Instance.new("UIStroke")
    SearchStroke.Parent = SearchBar
    SearchStroke.Color = Library.Theme.Border
    SearchStroke.Thickness = 1
    Library:RegisterTheme(SearchStroke, "Color", "Border")

    local SearchCorner = Instance.new("UICorner")
    SearchCorner.CornerRadius = UDim.new(0, 6)
    SearchCorner.Parent = SearchBar
    Library:RegisterTheme(SearchBar, "BackgroundColor3", "Main")
    Library:RegisterTheme(SearchBar, "TextColor3", "Text")

    local PinBtn = Instance.new("TextButton")
    PinBtn.Parent = TopBar
    PinBtn.Size = UDim2.new(0, 24, 0, 24)
    PinBtn.Position = UDim2.new(1, -240, 0.5, -12)
    PinBtn.BackgroundTransparency = 1
    PinBtn.Text = ""

    local PinIcon = nil
    if Lucide then
        pcall(
            function()
                PinIcon =
                    Lucide.ImageLabel(
                    "pin",
                    18,
                    {
                        Parent = PinBtn,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0.5, -9, 0.5, -9),
                        ImageColor3 = Library.Theme.Accent
                    }
                )
            end
        )
    end

    if not PinIcon then
        PinIcon = Instance.new("ImageLabel")
        PinIcon.Parent = PinBtn
        PinIcon.Size = UDim2.new(0, 18, 0, 18)
        PinIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
        PinIcon.BackgroundTransparency = 1
        PinIcon.Image = "rbxassetid://6034509993"
        PinIcon.ImageColor3 = Library.Theme.TextDark
    end

    Library:RegisterTheme(PinIcon, "ImageColor3", "TextDark")

    PinBtn.MouseButton1Click:Connect(
        function()
            Library:TogglePinnedWindow()
        end
    )

    local MinBtn = Instance.new("TextButton")
    MinBtn.Parent = TopBar
    MinBtn.Size = UDim2.new(0, 35, 1, 0)
    MinBtn.Position = UDim2.new(1, -35, 0, 0)
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Library.Theme.Text
    MinBtn.BackgroundTransparency = 1
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.TextSize = 22
    Library:RegisterTheme(MinBtn, "TextColor3", "Text")

    local ContentArea = Instance.new("Frame")
    ContentArea.Parent = MainFrame
    ContentArea.Size = UDim2.new(1, 0, 1, -45)
    ContentArea.Position = UDim2.new(0, 0, 0, 45)
    ContentArea.BackgroundTransparency = 1

    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Parent = ContentArea
    TabContainer.Size = UDim2.new(0, 130, 1, -20)
    TabContainer.Position = UDim2.new(0, 10, 0, 10)
    TabContainer.BackgroundColor3 = Library.Theme.Secondary
    TabContainer.BackgroundTransparency = 0
    TabContainer.ScrollBarThickness = 0
    TabContainer.BorderSizePixel = 0
    Library:RegisterTheme(TabContainer, "BackgroundColor3", "Secondary")

    local TabCorner = Instance.new("UICorner")
    TabCorner.CornerRadius = UDim.new(0, 8)
    TabCorner.Parent = TabContainer

    local TabList = Instance.new("UIListLayout")
    TabList.Parent = TabContainer
    TabList.Padding = UDim.new(0, 5)

    local TabPadding = Instance.new("UIPadding")
    TabPadding.Parent = TabContainer
    TabPadding.PaddingTop = UDim.new(0, 10)
    TabPadding.PaddingLeft = UDim.new(0, 5)
    TabPadding.PaddingRight = UDim.new(0, 5)

    local Pages = Instance.new("Frame")
    Pages.Parent = ContentArea
    Pages.Size = UDim2.new(1, -160, 1, -20)
    Pages.Position = UDim2.new(0, 150, 0, 10)
    Pages.BackgroundTransparency = 1

    local LastInteraction = tick()
    local IsDimmed = false
    Library.ActiveWindows = {MainFrame}

    local Win = {Frame = MainFrame, Tabs = {}, CurrentTab = nil, PriorTab = nil}
    local minimized = false
    local isHidden = false
    local isAutoMinimized = false

    local MaxPos = nil
    local MinPos = Library.MinimizedPosition

    local function ToggleWindow(shouldHide)
        if shouldHide then
            isHidden = not isHidden
            MainFrame.Visible = not isHidden
            return
        end

        minimized = not minimized
        if minimized then
            MaxPos = MainFrame.Position
            Library.MaximizedPosition = MaxPos

            local titleWidth = Title.TextBounds.X
            local targetWidth = titleWidth + 60
            if targetWidth < 150 then
                targetWidth = 150
            end

            local targetSize = UDim2.new(0, targetWidth, 0, 45)
            if MinPos then
                Tween(
                    MainFrame,
                    {0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out},
                    {Size = targetSize, Position = MinPos}
                )
            else
                Tween(MainFrame, {0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out}, {Size = targetSize})
            end

            ContentArea.Visible = false
            SearchBar.Visible = false
            Title.Visible = true
            MinBtn.Text = "+"
        else
            MinPos = MainFrame.Position
            Library.MinimizedPosition = MinPos
            Library.MaximizedPosition = nil

            if MaxPos then
                Tween(
                    MainFrame,
                    {0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out},
                    {Size = config.Size, Position = MaxPos}
                )
            else
                Tween(MainFrame, {0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out}, {Size = config.Size})
            end

            ContentArea.Visible = true
            SearchBar.Visible = true
            MinBtn.Text = "-"
        end
    end

    Win.ToggleWindow = ToggleWindow
    Win.SetMinimized = function(self, shouldHide)
        if shouldHide then
            isHidden = not isHidden
            MainFrame.Visible = not isHidden
        else
            ToggleWindow(false)
        end
    end

    MinBtn.MouseButton1Click:Connect(
        function()
            isAutoMinimized = false
            ToggleWindow(false)
        end
    )

    local function ResetTimer()
        LastInteraction = tick()
        if IsDimmed then
            IsDimmed = false

            if isAutoMinimized then
                if minimized then
                    ToggleWindow(false)
                end
                isAutoMinimized = false
            end
        end
    end
    Library.ResetTimer = ResetTimer

    MainFrame.InputBegan:Connect(ResetTimer)
    MainFrame.InputChanged:Connect(ResetTimer)
    UserInputService.InputBegan:Connect(ResetTimer)
    SearchBar:GetPropertyChangedSignal("Text"):Connect(ResetTimer)
    SearchBar.Focused:Connect(ResetTimer)

    MakeDraggable(MainFrame, TopBar, function()
        if Library.ConfigSettings then
            Library:SaveConfigDebounced(Library.ConfigSettings.Folder, Library.ConfigSettings.Name)
        end
    end)

    local _heartbeatTick = 0
    Win._heartbeatConn = RunService.Heartbeat:Connect(
        function()
            _heartbeatTick = _heartbeatTick + 1
            if _heartbeatTick % 60 ~= 0 then return end
            if isHidden then return end
            if not MainFrame or not MainFrame.Parent then
                return
            end
            if tick() - LastInteraction > 30 and not IsDimmed then
                IsDimmed = true

                if not minimized then
                    isAutoMinimized = true
                    ToggleWindow(false)
                end
            end
        end
    )
    MainFrame.AncestryChanged:Connect(function()
        if not MainFrame.Parent and Win._heartbeatConn then
            Win._heartbeatConn:Disconnect()
            Win._heartbeatConn = nil
        end
    end)

    SearchBar:GetPropertyChangedSignal("Text"):Connect(
        function()
            local query = SearchBar.Text:lower()
            local firstMatchTab = nil

            for _, tab in pairs(Win.Tabs) do
                local hasMatch = false
                for _, elem in pairs(tab.Elements) do
                    local function search(el)
                        local match = false
                        if not el.Name then
                            match = (query == "")
                        elseif string.find(el.Name:lower(), query) or query == "" then
                            match = true
                        end

                        local childMatch = false
                        if el.Elements then
                            for _, child in pairs(el.Elements) do
                                if search(child) then
                                    childMatch = true
                                end
                            end
                        end

                        if el.Frame then
                            el.Frame.Visible = match or childMatch
                        end
                        return match or childMatch
                    end

                    if search(elem) then
                        hasMatch = true
                    end
                end

                if query == "" then
                    tab.Button.Visible = true
                else
                    tab.Button.Visible = hasMatch
                end

                if hasMatch and not firstMatchTab then
                    firstMatchTab = tab
                end
            end

            if query ~= "" and firstMatchTab and Win.CurrentTab ~= firstMatchTab then
                Win:SelectTab(firstMatchTab)
            end
        end
    )

    function Win:SelectTab(tabObj)
        for _, t in pairs(Win.Tabs) do
            -- Add a check to ensure t.Button exists
            if t.Button then
                t.Button.BackgroundTransparency = 1
            end
            if t.Label then
                t.Label.TextColor3 = Library.Theme.TextDark
            end
            t.Page.Visible = false
            if t.Icon then
                t.Icon.ImageColor3 = Library.Theme.TextDark
            end
        end
    
        -- Add a check to ensure tabObj.Button exists
        if tabObj.Button then
            tabObj.Button.BackgroundTransparency = 0.8
            tabObj.Button.BackgroundColor3 = Library.Theme.Accent
        end
        
        if tabObj.Label then
            tabObj.Label.TextColor3 = Library.Theme.Text
        end
    
        tabObj.Page.Visible = true
        if tabObj.Icon then
            tabObj.Icon.ImageColor3 = Library.Theme.Accent
        end
        Win.CurrentTab = tabObj
    end

    function Win:AddTab(name, iconName)
        local TabBtn = Instance.new("TextButton")
        TabBtn.Parent = TabContainer
        TabBtn.Size = UDim2.new(1, 0, 0, 36)
        TabBtn.BackgroundTransparency = 1
        TabBtn.BackgroundColor3 = Library.Theme.Accent
        TabBtn.Text = ""
        TabBtn.AutoButtonColor = false

        local TabCorner = Instance.new("UICorner")
        TabCorner.CornerRadius = UDim.new(0, 6)
        TabCorner.Parent = TabBtn

        local TabLabel = Instance.new("TextLabel")
        TabLabel.Parent = TabBtn
        TabLabel.Text = name
        TabLabel.Size = UDim2.new(1, -34, 1, 0)
        TabLabel.Position = UDim2.new(0, 34, 0, 0)
        TabLabel.BackgroundTransparency = 1
        TabLabel.TextColor3 = Library.Theme.TextDark
        TabLabel.Font = Enum.Font.GothamMedium
        TabLabel.TextSize = 13
        TabLabel.TextXAlignment = Enum.TextXAlignment.Left

        local Icon = nil
        if iconName and Lucide then
            pcall(
                function()
                    Icon =
                        Lucide.ImageLabel(
                        iconName,
                        20,
                        {
                            Parent = TabBtn,
                            BackgroundTransparency = 1,
                            ImageColor3 = Library.Theme.TextDark,
                            Position = UDim2.new(0, 8, 0.5, -10)
                        }
                    )
                end
            )
        end

        if not Icon then
            TabLabel.Position = UDim2.new(0, 10, 0, 0)
            TabLabel.Size = UDim2.new(1, -10, 1, 0)
        end

        local Page = Instance.new("ScrollingFrame")
        Page.Parent = Pages
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.Visible = false
        Page.ScrollBarThickness = 0

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = Page
        PageLayout.Padding = UDim.new(0, 8)
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder

        local PagePadding = Instance.new("UIPadding")
        PagePadding.Parent = Page
        PagePadding.PaddingTop = UDim.new(0, 5)
        PagePadding.PaddingLeft = UDim.new(0, 5)
        PagePadding.PaddingRight = UDim.new(0, 5)
        PagePadding.PaddingBottom = UDim.new(0, 10)
        local function UpdateCanvasSize()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 15)
        end
        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
        UpdateCanvasSize()

        local TabObj = {Name = name, Button = TabBtn, Label = TabLabel, Page = Page, Elements = {}, Icon = Icon}

        table.insert(
            ThemeUpdateHooks,
            function()
                if Win.CurrentTab == TabObj then
                    Tween(TabBtn, {0.2}, {BackgroundColor3 = Library.Theme.Accent})
                    Tween(TabLabel, {0.2}, {TextColor3 = Library.Theme.Text})
                    if Icon then
                        Tween(Icon, {0.2}, {ImageColor3 = Library.Theme.Accent})
                    end
                else
                    Tween(TabBtn, {0.2}, {BackgroundColor3 = Library.Theme.Accent})

                    Tween(TabLabel, {0.2}, {TextColor3 = Library.Theme.TextDark})
                    if Icon then
                        Tween(Icon, {0.2}, {ImageColor3 = Library.Theme.TextDark})
                    end
                end
            end
        )

        TabBtn.MouseButton1Click:Connect(
            function()
                Win:SelectTab(TabObj)
            end
        )

        local elementData = {
            Type = "tab",
            Name = name,
            Frame = TabBtn,
            Select = function()
                Win:SelectTab(TabObj)
            end
        }

        TabBtn.MouseButton2Click:Connect(
            function()
                Library:ShowElementContextMenu(elementData)
            end
        )

        if #Win.Tabs == 0 then
            Win:SelectTab(TabObj)
        end
        table.insert(Win.Tabs, TabObj)

        Library.AttachComponents(TabObj, Page)

        return TabObj
    end

    return Win
end

function Library:CreateContextWindow(config)
    config = config or {}
    local CloseCallback = config.OnClose

    local guiName = "LuneContext_" .. (config.Name or "Context")
    local gui = Instance.new("ScreenGui")
    gui.Name = guiName
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ProtectGui(gui)

    local Frame = Instance.new("Frame")
    Frame.Parent = gui
    Frame.Size = config.Size or UDim2.fromOffset(300, 400)
    Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    Frame.AnchorPoint = Vector2.new(0.5, 0.5)
    Frame.BackgroundColor3 = Library.Theme.Main
    Frame.BorderSizePixel = 0
    Library:RegisterTheme(Frame, "BackgroundColor3", "Main")

    local FrameStroke = Instance.new("UIStroke")
    FrameStroke.Parent = Frame
    FrameStroke.Color = Library.Theme.Accent
    FrameStroke.Thickness = 2
    Library:RegisterTheme(FrameStroke, "Color", "Accent")

    local FrameCorner = Instance.new("UICorner")
    FrameCorner.CornerRadius = UDim.new(0, 8)
    FrameCorner.Parent = Frame

    local TopBar = Instance.new("Frame")
    TopBar.Parent = Frame
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundColor3 = Library.Theme.Secondary
    Library:RegisterTheme(TopBar, "BackgroundColor3", "Secondary")

    local TopCorner = Instance.new("UICorner")
    TopCorner.CornerRadius = UDim.new(0, 8)
    TopCorner.Parent = TopBar

    local Cover = Instance.new("Frame")
    Cover.Parent = TopBar
    Cover.Size = UDim2.new(1, 0, 0, 10)
    Cover.Position = UDim2.new(0, 0, 1, -10)
    Cover.BackgroundColor3 = Library.Theme.Secondary
    Cover.BorderSizePixel = 0
    Library:RegisterTheme(Cover, "BackgroundColor3", "Secondary")

    local Title = Instance.new("TextLabel")
    Title.Parent = TopBar
    Title.Text = config.Title or "Context Window"
    Title.Size = UDim2.new(1, -40, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextColor3 = Library.Theme.Text
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Library:RegisterTheme(Title, "TextColor3", "Text")

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = TopBar
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -30, 0, 2)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Library.Theme.Text
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.TextSize = 14
    Library:RegisterTheme(CloseBtn, "TextColor3", "Text")

    local Content = Instance.new("ScrollingFrame")
    Content.Parent = Frame
    Content.Size = UDim2.new(1, 0, 1, -45)
    Content.Position = UDim2.new(0, 0, 0, 40)
    Content.BackgroundTransparency = 1
    Content.ScrollBarThickness = 0
    if config.AutoSize then
        Frame.AutomaticSize = Enum.AutomaticSize.Y
        Content.AutomaticSize = Enum.AutomaticSize.Y
        Content.Size = UDim2.new(1, 0, 0, 0)
    end

    local Layout = Instance.new("UIListLayout")
    Layout.Parent = Content
    Layout.Padding = UDim.new(0, 5)

    local Padding = Instance.new("UIPadding")
    Padding.Parent = Content
    Padding.PaddingTop = UDim.new(0, 5)
    Padding.PaddingBottom = UDim.new(0, 5)
    Padding.PaddingLeft = UDim.new(0, 5)
    Padding.PaddingRight = UDim.new(0, 5)
    local function UpdateCanvasSize()
        Content.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 15)
    end
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvasSize)
    UpdateCanvasSize()

    MakeDraggable(Frame, TopBar, function()
        if Library.ConfigSettings then
            Library:SaveConfigDebounced(Library.ConfigSettings.Folder, Library.ConfigSettings.Name)
        end
    end)
    local cleanupCallbacks = {}

    CloseBtn.MouseButton1Click:Connect(
        function()
            gui:Destroy()
            if CloseCallback then
                CloseCallback()
            end
        end
    )
    gui.AncestryChanged:Connect(function()
        if not gui.Parent then
            for _, fn in ipairs(cleanupCallbacks) do
                pcall(fn)
            end
            cleanupCallbacks = nil
        end
    end)

    local ContextObj = {Frame = Frame, Container = Content, Elements = {}, _cleanup = cleanupCallbacks}
    Library.AttachComponents(ContextObj, Content)

    if Library.ActiveWindows then
        table.insert(Library.ActiveWindows, Frame)
    end

    return ContextObj
end

return Library
