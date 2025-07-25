-- rayx.lua
-- Minimal Rayfield-like API implementation: Window/Tab/Button/Toggle/Slider/Input/Dropdown + Notify + Flags/Config
-- Send me screenshots/styles to finish polishing visuals & animations.

local RayX = {}
RayX.__index = RayX

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local protect = syn and syn.protect_gui or (protectgui) or function(gui) return gui end
local gethui_safe = gethui or function() return game:GetService("CoreGui") end

-- ======= Safe FS wrappers =======
local canfs = (writefile and readfile and makefolder and isfile and isfolder) and true or false

local function safe_isfolder(p)
    if not canfs then return false end
    local ok, res = pcall(isfolder, p)
    return ok and res or false
end

local function safe_isfile(p)
    if not canfs then return false end
    local ok, res = pcall(isfile, p)
    return ok and res or false
end

local function safe_makefolder(p)
    if not canfs then return end
    pcall(makefolder, p)
end

local function safe_writefile(p, d)
    if not canfs then return end
    pcall(writefile, p, d)
end

local function safe_readfile(p)
    if not canfs then return nil end
    local ok, res = pcall(readfile, p)
    return ok and res or nil
end

-- ======= Helpers =======
local function roundify(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = obj
    return c
end

local function padding(parent, px)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, px)
    p.PaddingBottom = UDim.new(0, px)
    p.PaddingLeft = UDim.new(0, px)
    p.PaddingRight = UDim.new(0, px)
    p.Parent = parent
    return p
end

local function tween(o, t, goal)
    local info = TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tw = TweenService:Create(o, info, goal)
    tw:Play()
    return tw
end

local function createText(parent, text, size, color, font, xalign, yalign)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Font = font or Enum.Font.Gotham
    lbl.TextSize = size or 14
    lbl.TextColor3 = color or Color3.new(1,1,1)
    lbl.Text = text or ""
    lbl.TextXAlignment = xalign or Enum.TextXAlignment.Left
    lbl.TextYAlignment = yalign or Enum.TextYAlignment.Center
    lbl.Parent = parent
    return lbl
end

local function measureText(text, size, font, width)
    local params = Instance.new("GetTextBoundsParams")
    params.Text = text
    params.Size = size
    params.Font = font
    params.Width = width or math.huge
    params.RichText = false
    return TextService:GetTextBoundsAsync(params)
end

-- ======= Theme =======
local DefaultTheme = {
    Font = Enum.Font.Gotham,
    TextSize = 14,

    Primary = Color3.fromRGB(33, 33, 33),
    Secondary = Color3.fromRGB(25, 25, 25),
    Tertiary = Color3.fromRGB(20, 20, 20),
    Outline = Color3.fromRGB(50, 50, 50),
    TextColor = Color3.fromRGB(235, 235, 235),
    Accent = Color3.fromRGB(0, 145, 255),

    Corner = 6,
    Padding = 8,

    AnimationTime = 0.15,

    Notification = {
        Width = 320,
        Padding = 10,
        Gap = 6
    }
}

-- ======= Lucide-like icon table (fill with your ids) =======
local LucideIcons = {
    -- put your ids here, e.g.:
    -- ["rewind"] = "rbxassetid://1234567890",
    -- ["info"] = "rbxassetid://...",
    -- ["check"] = "rbxassetid://...",
    rewind = "rbxassetid://4483362458" -- пример, замени на реальный, если нужно
}

local function resolveImage(image)
    if typeof(image) == "number" then
        return "rbxassetid://"..tostring(image)
    elseif typeof(image) == "string" then
        if tonumber(image) then
            return "rbxassetid://"..image
        end
        return LucideIcons[image] or "" -- пусто = без картинки
    end
    return ""
end

-- ======= Config Manager =======
local ConfigManager = {}
ConfigManager.__index = ConfigManager

function ConfigManager.new(enabled, path)
    local self = setmetatable({}, ConfigManager)
    self.Enabled = enabled
    self.Path = path or "RayXConfig.json"
    self.Data = {}
    if self.Enabled then
        self:Load()
    end
    return self
end

function ConfigManager:Write(flag, value)
    if not self.Enabled then return end
    self.Data[flag] = value
    self:Save()
end

function ConfigManager:Read(flag, default)
    if not self.Enabled then return default end
    local v = self.Data[flag]
    if v == nil then return default end
    return v
end

function ConfigManager:Save()
    if not self.Enabled or not canfs then return end
    local folder = self.Path:match("(.+)/[^/]+$")
    if folder and not safe_isfolder(folder) then
        safe_makefolder(folder)
    end
    safe_writefile(self.Path, HttpService:JSONEncode(self.Data))
end

function ConfigManager:Load()
    if not self.Enabled or not canfs then return end
    if safe_isfile(self.Path) then
        local str = safe_readfile(self.Path)
        if str and #str > 0 then
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, str)
            if ok and type(decoded) == "table" then
                self.Data = decoded
            end
        end
    end
end

-- ======= Core =======
function RayX:CreateWindow(opts)
    opts = opts or {}

    local theme = setmetatable(opts.Theme or {}, { __index = DefaultTheme })

    local gui = Instance.new("ScreenGui")
    gui.Name = opts.Name or "RayX"
    gui.IgnoreGuiInset = false
    gui.ResetOnSpawn = false
    protect(gui)
    gui.Parent = gethui_safe()

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.BackgroundColor3 = theme.Primary
    main.Size = UDim2.new(0, 600, 0, 400)
    main.Position = UDim2.new(0.5, -300, 0.5, -200)
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    roundify(main, theme.Corner)

    local header = Instance.new("Frame")
    header.Name = "Header"
    header.BackgroundColor3 = theme.Secondary
    header.Size = UDim2.new(1, 0, 0, 36)
    header.Parent = main
    roundify(header, theme.Corner)

    local title = createText(header, opts.Name or "RayX Window", theme.TextSize + 2, theme.TextColor, theme.Font)
    title.Size = UDim2.new(1, -10, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.TextXAlignment = Enum.TextXAlignment.Left

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, -16, 1, -52)
    container.Position = UDim2.new(0, 8, 0, 44)
    container.Parent = main

    local tabButtons = Instance.new("Frame")
    tabButtons.Name = "TabButtons"
    tabButtons.BackgroundTransparency = 1
    tabButtons.Size = UDim2.new(0, 140, 1, 0)
    tabButtons.Parent = container

    local tabsList = Instance.new("UIListLayout")
    tabsList.FillDirection = Enum.FillDirection.Vertical
    tabsList.SortOrder = Enum.SortOrder.LayoutOrder
    tabsList.Padding = UDim.new(0, 6)
    tabsList.Parent = tabButtons

    local tabContent = Instance.new("Frame")
    tabContent.Name = "TabContent"
    tabContent.BackgroundTransparency = 1
    tabContent.Position = UDim2.new(0, 150, 0, 0)
    tabContent.Size = UDim2.new(1, -150, 1, 0)
    tabContent.Parent = container

    local notifyRoot = Instance.new("Folder")
    notifyRoot.Name = "Notifications"
    notifyRoot.Parent = gui

    -- notifications holder (top-right)
    local notifyHolder = Instance.new("Frame")
    notifyHolder.Name = "NotifyHolder"
    notifyHolder.AnchorPoint = Vector2.new(1, 0)
    notifyHolder.BackgroundTransparency = 1
    notifyHolder.Size = UDim2.new(0, theme.Notification.Width, 1, -20)
    notifyHolder.Position = UDim2.new(1, -10, 0, 10)
    notifyHolder.Parent = gui

    local notifyLayout = Instance.new("UIListLayout")
    notifyLayout.FillDirection = Enum.FillDirection.Vertical
    notifyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    notifyLayout.Padding = UDim.new(0, theme.Notification.Gap)
    notifyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    notifyLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    notifyLayout.Parent = notifyHolder

    local config = ConfigManager.new(
        opts.Config and opts.Config.Enabled or false,
        opts.Config and opts.Config.FileName or "RayXConfig.json"
    )

    local windowObj = setmetatable({
        _gui = gui,
        _main = main,
        _header = header,
        _title = title,
        _tabButtons = tabButtons,
        _tabContent = tabContent,
        _notifyRoot = notifyRoot,
        _notifyHolder = notifyHolder,

        _tabs = {},
        _theme = theme,
        _config = config,
        _activeTab = nil,
    }, {
        __index = function(t, k)
            return RayX.Window[k]
        end
    })

    return windowObj
end

-- ======= Window methods =======
RayX.Window = {}

function RayX.Window:CreateTab(opts)
    opts = opts or {}
    local theme = self._theme

    local btn = Instance.new("TextButton")
    btn.Name = "TabButton"
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = theme.Secondary
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.Text = ""
    btn.Parent = self._tabButtons
    roundify(btn, theme.Corner)

    local lbl = createText(btn, opts.Name or "Tab", theme.TextSize, theme.TextColor, theme.Font)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Size = UDim2.new(1, -20, 1, 0)

    local iconId = resolveImage(opts.Icon)
    if iconId ~= "" then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(0, 16, 0, 16)
        img.Position = UDim2.new(0, 10, 0.5, -8)
        img.Image = iconId
        img.Parent = btn

        lbl.Position = UDim2.new(0, 32, 0, 0)
        lbl.Size = UDim2.new(1, -42, 1, 0)
    end

    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.BackgroundColor3 = theme.Tertiary
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 4
    content.ScrollBarImageTransparency = 0.5
    content.Visible = false
    content.CanvasSize = UDim2.new(0,0,0,0)
    content.Size = UDim2.new(1, 0, 1, 0)
    content.Parent = self._tabContent
    roundify(content, theme.Corner)

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, theme.Padding)
    list.Parent = content

    padding(content, theme.Padding)

    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 20)
    end)

    local tabObj = setmetatable({
        _window = self,
        _button = btn,
        _label = lbl,
        _content = content,
        _list = list,
        _theme = theme,
        _config = self._config,
        _controls = {}
    }, {
        __index = function(t, k)
            return RayX.Tab[k]
        end
    })

    table.insert(self._tabs, tabObj)

    btn.MouseButton1Click:Connect(function()
        self:ActivateTab(tabObj)
    end)

    if not self._activeTab then
        self:ActivateTab(tabObj)
    end

    return tabObj
end

function RayX.Window:ActivateTab(tabObj)
    for _, t in ipairs(self._tabs) do
        t._content.Visible = false
        t._button.BackgroundColor3 = self._theme.Secondary
    end
    tabObj._content.Visible = true
    tabObj._button.BackgroundColor3 = self._theme.Accent
    self._activeTab = tabObj
end

function RayX:Notify(opts)
    local win = self -- allow RayX:Notify if you stored the window instance in self?
    -- To keep API identical to Rayfield, expose Notify on the "library" object, not window.
    -- So we store last created window globally (simple approach) OR return the root lib.
end

-- We want RayX:Notify({...}). So store the current (last) window reference:
local _lastWindow = nil

function RayX:CreateWindow(opts)
    local w = setmetatable(RayX.CreateWindow(self, opts), {})
    _lastWindow = w
    return w
end

function RayX:Notify(opts)
    if not _lastWindow then return end
    return _lastWindow:Notify(opts)
end

function RayX.Window:Notify(opts)
    opts = opts or {}
    local theme = self._theme

    local holder = self._notifyHolder
    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = theme.Secondary
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = holder
    roundify(frame, theme.Corner)
    padding(frame, theme.Notification.Padding)

    local title = createText(frame, opts.Title or "Notification", theme.TextSize + 1, theme.TextColor, theme.Font)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(1, 0, 0, theme.TextSize + 4)

    local content = createText(frame, opts.Content or "", theme.TextSize, theme.TextColor, theme.Font)
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextYAlignment = Enum.TextYAlignment.Top
    content.TextWrapped = true
    content.Size = UDim2.new(1, 0, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Position = UDim2.new(0, 0, 0, theme.TextSize + 8)

    local imgId = resolveImage(opts.Image)
    if imgId ~= "" then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(0, 18, 0, 18)
        img.Position = UDim2.new(0, 0, 0, 0)
        img.Image = imgId
        img.Parent = frame
        -- shift text
        title.Position = UDim2.new(0, 24, 0, 0)
        title.Size = UDim2.new(1, -24, 0, theme.TextSize + 4)
        content.Position = UDim2.new(0, 24, 0, theme.TextSize + 8)
        content.Size = UDim2.new(1, -24, 0, 0)
    end

    frame.BackgroundTransparency = 1
    tween(frame, theme.AnimationTime, { BackgroundTransparency = 0 })

    task.spawn(function()
        task.wait(opts.Duration or 5)
        tween(frame, theme.AnimationTime, { BackgroundTransparency = 1 })
        task.wait(theme.AnimationTime)
        frame:Destroy()
    end)

    return frame
end

-- ======= Tab methods (controls) =======
RayX.Tab = {}

-- Button
function RayX.Tab:CreateButton(opts)
    opts = opts or {}
    local theme = self._theme

    local btn = Instance.new("TextButton")
    btn.Name = opts.Name or "Button"
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = theme.Secondary
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.Parent = self._content
    roundify(btn, theme.Corner)

    local lbl = createText(btn, opts.Name or "Button", theme.TextSize, theme.TextColor, theme.Font)
    lbl.Size = UDim2.new(1, -16, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)

    btn.MouseButton1Click:Connect(function()
        if opts.Callback then
            task.spawn(opts.Callback)
        end
    end)

    local obj = {
        Button = btn,
        Label = lbl,
        Set = function(self2, text)
            lbl.Text = text
        end
    }
    table.insert(self._controls, obj)
    return obj
end

-- Toggle
function RayX.Tab:CreateToggle(opts)
    opts = opts or {}
    local theme = self._theme
    local flag = opts.Flag

    local defaultValue = opts.CurrentValue or false
    defaultValue = self._config:Read(flag, defaultValue)

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = theme.Secondary
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.Parent = self._content
    roundify(holder, theme.Corner)

    local lbl = createText(holder, opts.Name or "Toggle", theme.TextSize, theme.TextColor, theme.Font)
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)

    local btn = Instance.new("TextButton")
    btn.Name = "Toggle"
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = defaultValue and theme.Accent or theme.Outline
    btn.Size = UDim2.new(0, 36, 0, 18)
    btn.Position = UDim2.new(1, -44, 0.5, -9)
    btn.Parent = holder
    roundify(btn, 9)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(defaultValue and 1 or 0, defaultValue and -16 or 2, 0.5, -7)
    knob.Parent = btn
    roundify(knob, 7)

    local state = defaultValue

    local function set(v, fire)
        state = v
        self._config:Write(flag, v)
        tween(btn, theme.AnimationTime, { BackgroundColor3 = v and theme.Accent or theme.Outline })
        tween(knob, theme.AnimationTime, {
            Position = UDim2.new(v and 1 or 0, v and -16 or 2, 0.5, -7)
        })
        if fire and opts.Callback then
            task.spawn(opts.Callback, v)
        end
    end

    btn.MouseButton1Click:Connect(function()
        set(not state, true)
    end)

    -- set initial without firing callback
    set(state, false)

    local obj = {
        Frame = holder,
        Label = lbl,
        Button = btn,
        Get = function() return state end,
        Set = function(_, v) set(v, true) end
    }
    table.insert(self._controls, obj)
    return obj
end

-- Slider
function RayX.Tab:CreateSlider(opts)
    opts = opts or {}
    local theme = self._theme
    local flag = opts.Flag

    local min, max = table.unpack(opts.Range or {0, 100})
    local inc = opts.Increment or 1
    local suffix = opts.Suffix or ""
    local defaultVal = opts.CurrentValue or min
    defaultVal = self._config:Read(flag, defaultVal)

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = theme.Secondary
    holder.Size = UDim2.new(1, 0, 0, 56)
    holder.Parent = self._content
    roundify(holder, theme.Corner)
    padding(holder, 6)

    local nameLbl = createText(holder, opts.Name or "Slider", theme.TextSize, theme.TextColor, theme.Font)
    nameLbl.Size = UDim2.new(1, -8, 0, theme.TextSize + 4)
    nameLbl.Position = UDim2.new(0, 4, 0, 0)

    local valueLbl = createText(holder, "", theme.TextSize, theme.TextColor, theme.Font, Enum.TextXAlignment.Right)
    valueLbl.Size = UDim2.new(1, -8, 0, theme.TextSize + 4)
    valueLbl.Position = UDim2.new(0, 4, 0, 0)

    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = theme.Tertiary
    bar.Size = UDim2.new(1, -8, 0, 6)
    bar.Position = UDim2.new(0, 4, 0, theme.TextSize + 12)
    bar.Parent = holder
    roundify(bar, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = theme.Accent
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = bar
    roundify(fill, 3)

    local dragging = false
    local value = defaultVal

    local function snap(v)
        v = math.clamp(v, min, max)
        v = math.floor((v - min) / inc + 0.5) * inc + min
        return math.clamp(v, min, max)
    end

    local function updateVisual(v)
        local pct = (v - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valueLbl.Text = tostring(v)..(suffix ~= "" and (" "..suffix) or "")
    end

    local function set(v, fire)
        v = snap(v)
        value = v
        self._config:Write(flag, v)
        updateVisual(v)
        if fire and opts.Callback then
            task.spawn(opts.Callback, v)
        end
    end

    updateVisual(value)

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            set(min + (max - min) * rel, true)
        end
    end)

    bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
            set(min + (max - min) * rel, true)
        end
    end)

    local obj = {
        Frame = holder,
        Get = function() return value end,
        Set = function(_, v) set(v, true) end,
    }
    table.insert(self._controls, obj)
    return obj
end

-- Input (TextBox)
function RayX.Tab:CreateInput(opts)
    opts = opts or {}
    local theme = self._theme
    local flag = opts.Flag

    local defaultVal = opts.CurrentValue or ""
    defaultVal = self._config:Read(flag, defaultVal)

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = theme.Secondary
    holder.Size = UDim2.new(1, 0, 0, 56)
    holder.Parent = self._content
    roundify(holder, theme.Corner)
    padding(holder, 6)

    local nameLbl = createText(holder, opts.Name or "Input", theme.TextSize, theme.TextColor, theme.Font)
    nameLbl.Size = UDim2.new(1, -8, 0, theme.TextSize + 4)
    nameLbl.Position = UDim2.new(0, 4, 0, 0)

    local box = Instance.new("TextBox")
    box.BackgroundColor3 = theme.Tertiary
    box.TextColor3 = theme.TextColor
    box.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    box.Font = theme.Font
    box.TextSize = theme.TextSize
    box.PlaceholderText = opts.PlaceholderText or ""
    box.ClearTextOnFocus = opts.RemoveTextAfterFocusLost or false
    box.Text = defaultVal
    box.Size = UDim2.new(1, -8, 0, 26)
    box.Position = UDim2.new(0, 4, 0, theme.TextSize + 10)
    box.Parent = holder
    roundify(box, theme.Corner)

    local function set(v, fire)
        box.Text = v
        self._config:Write(flag, v)
        if fire and opts.Callback then
            task.spawn(opts.Callback, v)
        end
    end

    box.FocusLost:Connect(function(enter)
        set(box.Text, true)
    end)

    local obj = {
        Frame = holder,
        Get = function() return box.Text end,
        Set = function(_, v) set(v, true) end,
    }
    table.insert(self._controls, obj)
    return obj
end

-- Dropdown
function RayX.Tab:CreateDropdown(opts)
    opts = opts or {}
    local theme = self._theme
    local flag = opts.Flag

    local options = opts.Options or {}
    local multiple = opts.MultipleOptions or false
    local current = opts.CurrentOption or (multiple and {} or (options[1] and {options[1]} or {}))
    current = self._config:Read(flag, current)

    local holder = Instance.new("Frame")
    holder.BackgroundColor3 = theme.Secondary
    holder.Size = UDim2.new(1, 0, 0, 40)
    holder.Parent = self._content
    roundify(holder, theme.Corner)
    padding(holder, 6)

    local nameLbl = createText(holder, opts.Name or "Dropdown", theme.TextSize, theme.TextColor, theme.Font)
    nameLbl.Size = UDim2.new(1, -30, 1, 0)
    nameLbl.Position = UDim2.new(0, 4, 0, 0)

    local openBtn = Instance.new("TextButton")
    openBtn.Text = ""
    openBtn.AutoButtonColor = false
    openBtn.BackgroundTransparency = 1
    openBtn.Size = UDim2.new(0, 24, 1, 0)
    openBtn.Position = UDim2.new(1, -24, 0, 0)
    openBtn.Parent = holder
    local arrow = createText(openBtn, "▼", theme.TextSize, theme.TextColor, theme.Font, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center)
    arrow.Size = UDim2.new(1, 0, 1, 0)

    local listFrame = Instance.new("Frame")
    listFrame.BackgroundColor3 = theme.Tertiary
    listFrame.Size = UDim2.new(1, 0, 0, 0)
    listFrame.Position = UDim2.new(0, 0, 1, 4)
    listFrame.Visible = false
    listFrame.Parent = holder
    roundify(listFrame, theme.Corner)
    padding(listFrame, 6)

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = listFrame

    local function isSelected(opt)
        for _, v in ipairs(current) do
            if v == opt then return true end
        end
        return false
    end

    local function updateLabel()
        if #current == 0 then
            nameLbl.Text = opts.Name or "Dropdown"
        else
            nameLbl.Text = (opts.Name or "Dropdown") .. " : " .. table.concat(current, ", ")
        end
    end

    local function fireCallback()
        if opts.Callback then
            local copy = {}
            for i,v in ipairs(current) do copy[i] = v end
            task.spawn(opts.Callback, copy)
        end
    end

    local function save()
        self._config:Write(flag, current)
    end

    local function toggleOpt(opt)
        if multiple then
            if isSelected(opt) then
                for i,v in ipairs(current) do
                    if v == opt then table.remove(current, i) break end
                end
            else
                table.insert(current, opt)
            end
        else
            current = { opt }
            listFrame.Visible = false
        end
        updateLabel()
        save()
        fireCallback()
    end

    local function rebuildList()
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("Frame") then
                c:Destroy()
            end
        end

        for _, opt in ipairs(options) do
            local b = Instance.new("TextButton")
            b.AutoButtonColor = false
            b.BackgroundColor3 = theme.Secondary
            b.Text = ""
            b.Size = UDim2.new(1, 0, 0, 26)
            b.Parent = listFrame
            roundify(b, theme.Corner)

            local lbl = createText(b, opt, theme.TextSize, theme.TextColor, theme.Font)
            lbl.Size = UDim2.new(1, -8, 1, 0)
            lbl.Position = UDim2.new(0, 4, 0, 0)

            local check = createText(b, isSelected(opt) and "✔" or "", theme.TextSize, theme.TextColor, theme.Font, Enum.TextXAlignment.Right)
            check.Size = UDim2.new(1, -8, 1, 0)

            b.MouseButton1Click:Connect(function()
                toggleOpt(opt)
                check.Text = isSelected(opt) and "✔" or ""
            end)
        end

        task.wait() -- wait a frame for layout to update
        listFrame.Size = UDim2.new(1, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
    end

    openBtn.MouseButton1Click:Connect(function()
        listFrame.Visible = not listFrame.Visible
        rebuildList()
    end)

    updateLabel()

    local obj = {
        Frame = holder,
        SetOptions = function(_, newOpts)
            options = newOpts or {}
            if not multiple and #current > 1 then
                current = { current[1] }
                save()
            end
            rebuildList()
            updateLabel()
        end,
        Get = function() 
            local copy = {}
            for i,v in ipairs(current) do copy[i] = v end
            return copy
        end,
        Set = function(_, tbl)
            if multiple then
                current = tbl or {}
            else
                current = { (tbl and tbl[1]) or options[1] }
            end
            save()
            updateLabel()
            fireCallback()
            rebuildList()
        end,
        Open = function()
            listFrame.Visible = true
            rebuildList()
        end,
        Close = function()
            listFrame.Visible = false
        end
    }

    table.insert(self._controls, obj)
    return obj
end

-- ======= Root object =======
local Root = {}
setmetatable(Root, RayX)

return Root
