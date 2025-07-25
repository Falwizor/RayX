-- rayx.lua
-- Minimal Rayfield-like UI lib for Roblox executors (Xeno, Syn, etc.)
-- Controls: Notify, Tabs, Button, Toggle, Slider, Input, Dropdown (single)
-- Flags + JSON config, Lucide-like string icons table.

local RayX = {}
RayX.__index = RayX

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local protect = syn and syn.protect_gui or (protectgui) or function(gui) return gui end
local gethui_safe = gethui or function() return game:GetService("CoreGui") end

-- ===== FS wrappers =====
local canfs = writefile and readfile and isfile and isfolder and makefolder

local function sf(fn, ...)
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local function ensureFolder(path)
    if not canfs then return end
    local dir = path:match("(.+)/[^/]+$")
    if dir and not sf(isfolder, dir) then sf(makefolder, dir) end
end

-- ===== Helpers =====
local function roundify(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = obj
end

local function stroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = obj
    return s
end

local function padding(parent, px)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, px)
    p.PaddingBottom = UDim.new(0, px)
    p.PaddingLeft = UDim.new(0, px)
    p.PaddingRight = UDim.new(0, px)
    p.Parent = parent
end

local function label(parent, text, size, color, font, xalign, yalign)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = font or Enum.Font.Gotham
    t.TextSize = size or 14
    t.TextColor3 = color or Color3.new(1,1,1)
    t.Text = text or ""
    t.TextXAlignment = xalign or Enum.TextXAlignment.Left
    t.TextYAlignment = yalign or Enum.TextYAlignment.Center
    t.Parent = parent
    return t
end

local function tween(o, time, goal)
    local info = TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tw = TweenService:Create(o, info, goal)
    tw:Play()
    return tw
end

-- ===== Theme =====
local DefaultTheme = {
    Font = Enum.Font.Gotham,
    TextSize = 14,

    BG       = Color3.fromRGB(30, 30, 30),
    Sidebar  = Color3.fromRGB(24, 24, 24),
    Panel    = Color3.fromRGB(40, 40, 40),
    Panel2   = Color3.fromRGB(34, 34, 34),
    Stroke   = Color3.fromRGB(55, 55, 55),
    Text     = Color3.fromRGB(235, 235, 235),
    Accent   = Color3.fromRGB(255, 75, 75),

    Corner   = 8,
    Padding  = 8,

    Animation = 0.15,

    Notify = {
        Width = 320,
        Gap = 6,
        Padding = 10
    }
}

-- ===== Icons (lucide-like map) =====
local Lucide = {
    rewind = "rbxassetid://4483362458"
}

local function resolveImage(image)
    if typeof(image) == "number" then
        return "rbxassetid://" .. image
    elseif typeof(image) == "string" then
        if tonumber(image) then
            return "rbxassetid://"..image
        end
        return Lucide[image] or ""
    end
    return ""
end

-- ===== Config manager =====
local Config = {}
Config.__index = Config

function Config.new(enabled, file)
    local self = setmetatable({}, Config)
    self.Enabled = enabled
    self.File = file or "RayXConfig.json"
    self.Data = {}
    if self.Enabled then self:Load() end
    return self
end

function Config:Get(flag, default)
    if not self.Enabled then return default end
    local v = self.Data[flag]
    if v == nil then return default end
    return v
end

function Config:Set(flag, value)
    if not self.Enabled then return end
    self.Data[flag] = value
    self:Save()
end

function Config:Save()
    if not self.Enabled or not canfs then return end
    ensureFolder(self.File)
    sf(writefile, self.File, HttpService:JSONEncode(self.Data))
end

function Config:Load()
    if not self.Enabled or not canfs or not sf(isfile, self.File) then return end
    local str = sf(readfile, self.File)
    if not str or #str == 0 then return end
    local ok, tbl = pcall(HttpService.JSONDecode, HttpService, str)
    if ok and type(tbl) == "table" then self.Data = tbl end
end

-- ===== Root state =====
local _lastWindow

-- ===== Public: CreateWindow =====
function RayX:CreateWindow(opts)
    opts = opts or {}
    local theme = setmetatable(opts.Theme or {}, { __index = DefaultTheme })

    local Root = Instance.new("ScreenGui")
    Root.Name = opts.Name or "RayX"
    Root.ResetOnSpawn = false
    protect(Root); Root.Parent = gethui_safe()

    -- main frame
    local Main = Instance.new("Frame")
    Main.BackgroundColor3 = theme.BG
    Main.Size = UDim2.new(0, 720, 0, 470)
    Main.Position = UDim2.new(0.5, -360, 0.5, -235)
    Main.Active = true
    Main.Draggable = true
    Main.Parent = Root
    roundify(Main, theme.Corner)
    stroke(Main, theme.Stroke, 1)

    -- header
    local Header = Instance.new("Frame")
    Header.BackgroundTransparency = 1
    Header.Size = UDim2.new(1, -16, 0, 36)
    Header.Position = UDim2.new(0, 8, 0, 8)
    Header.Parent = Main

    local Title = label(Header, (opts.Name or "RayX") .. (opts.Subtitle and (" | "..opts.Subtitle) or ""), theme.TextSize + 2, theme.Text, theme.Font)
    Title.Size = UDim2.new(1, -80, 1, 0)

    -- notify holder
    local NotifyHolder = Instance.new("Frame")
    NotifyHolder.BackgroundTransparency = 1
    NotifyHolder.AnchorPoint = Vector2.new(1, 0)
    NotifyHolder.Position = UDim2.new(1, -10, 0, 10)
    NotifyHolder.Size = UDim2.new(0, theme.Notify.Width, 1, -20)
    NotifyHolder.Parent = Root

    local NotifyList = Instance.new("UIListLayout")
    NotifyList.FillDirection = Enum.FillDirection.Vertical
    NotifyList.SortOrder = Enum.SortOrder.LayoutOrder
    NotifyList.Padding = UDim.new(0, theme.Notify.Gap)
    NotifyList.HorizontalAlignment = Enum.HorizontalAlignment.Right
    NotifyList.VerticalAlignment = Enum.VerticalAlignment.Top
    NotifyList.Parent = NotifyHolder

    -- body
    local Body = Instance.new("Frame")
    Body.BackgroundTransparency = 1
    Body.Size = UDim2.new(1, -16, 1, -52)
    Body.Position = UDim2.new(0, 8, 0, 44)
    Body.Parent = Main

    local Sidebar = Instance.new("Frame")
    Sidebar.BackgroundColor3 = theme.Sidebar
    Sidebar.Size = UDim2.new(0, 160, 1, 0)
    Sidebar.Parent = Body
    roundify(Sidebar, theme.Corner)

    local TabButtonsLayout = Instance.new("UIListLayout")
    TabButtonsLayout.FillDirection = Enum.FillDirection.Vertical
    TabButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabButtonsLayout.Padding = UDim.new(0, 6)
    TabButtonsLayout.Parent = Sidebar
    padding(Sidebar, 8)

    local Content = Instance.new("Frame")
    Content.BackgroundTransparency = 1
    Content.Position = UDim2.new(0, 168, 0, 0)
    Content.Size = UDim2.new(1, -168, 1, 0)
    Content.Parent = Body

    local cfg = Config.new(opts.Config and opts.Config.Enabled, opts.Config and opts.Config.FileName)

    local window = setmetatable({
        _theme = theme,
        _root = Root,
        _main = Main,
        _header = Header,
        _notifyHolder = NotifyHolder,
        _content = Content,
        _sidebar = Sidebar,
        _tabs = {},
        _active = nil,
        _config = cfg
    }, { __index = RayX.Window })

    _lastWindow = window
    return window
end

-- allow RayX:Notify({...})
function RayX:Notify(opts)
    if not _lastWindow then return end
    return _lastWindow:Notify(opts)
end

-- ===== Window methods =====
RayX.Window = {}

function RayX.Window:Notify(opts)
    opts = opts or {}
    local theme = self._theme

    local frame = Instance.new("Frame")
    frame.BackgroundColor3 = theme.Panel
    frame.Size = UDim2.new(1, 0, 0, 0)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Parent = self._notifyHolder
    roundify(frame, theme.Corner)
    stroke(frame, theme.Stroke, 1)
    padding(frame, theme.Notify.Padding)

    local imgId = resolveImage(opts.Image)
    local xOff = 0
    if imgId ~= "" then
        local icon = Instance.new("ImageLabel")
        icon.BackgroundTransparency = 1
        icon.Image = imgId
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0, 0, 0, 2)
        icon.Parent = frame
        xOff = 22
    end

    local title = label(frame, opts.Title or "Notification", theme.TextSize + 1, theme.Text, theme.Font)
    title.Position = UDim2.new(0, xOff, 0, 0)
    title.Size = UDim2.new(1, -xOff, 0, theme.TextSize + 4)

    local content = label(frame, opts.Content or "", theme.TextSize, theme.Text, theme.Font, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top)
    content.Position = UDim2.new(0, xOff, 0, theme.TextSize + 6)
    content.Size = UDim2.new(1, -xOff, 0, 0)
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.TextWrapped = true

    frame.BackgroundTransparency = 1
    tween(frame, theme.Animation, { BackgroundTransparency = 0 })

    task.spawn(function()
        task.wait(opts.Duration or 5)
        tween(frame, theme.Animation, { BackgroundTransparency = 1 })
        task.wait(theme.Animation)
        frame:Destroy()
    end)
end

function RayX.Window:CreateTab(opts)
    opts = opts or {}
    local theme = self._theme

    local btn = Instance.new("TextButton")
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = theme.Panel2
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.Parent = self._sidebar
    roundify(btn, theme.Corner)
    stroke(btn, theme.Stroke, 1)

    local text = label(btn, opts.Name or "Tab", theme.TextSize, theme.Text, theme.Font)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.Size = UDim2.new(1, -20, 1, 0)

    local iconId = resolveImage(opts.Icon)
    if iconId ~= "" then
        local icon = Instance.new("ImageLabel")
        icon.BackgroundTransparency = 1
        icon.Image = iconId
        icon.Size = UDim2.new(0, 16, 0, 16)
        icon.Position = UDim2.new(0, 10, 0.5, -8)
        icon.Parent = btn

        text.Position = UDim2.new(0, 32, 0, 0)
        text.Size = UDim2.new(1, -42, 1, 0)
    end

    local page = Instance.new("ScrollingFrame")
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 4
    page.ScrollBarImageTransparency = 0.5
    page.Visible = false
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Parent = self._content

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, theme.Padding)
    layout.Parent = page

    padding(page, theme.Padding)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    local tab = setmetatable({
        _window = self,
        _theme = theme,
        _config = self._config,
        _btn = btn,
        _page = page,
        _layout = layout,
        _controls = {}
    }, { __index = RayX.Tab })

    table.insert(self._tabs, tab)

    btn.MouseButton1Click:Connect(function()
        for _, t in ipairs(self._tabs) do
            t._page.Visible = false
            t._btn.BackgroundColor3 = theme.Panel2
        end
        page.Visible = true
        btn.BackgroundColor3 = theme.Accent
        self._active = tab
    end)

    if not self._active then
        btn:MouseButton1Click()
    end

    return tab
end

-- ===== Tab controls =====
RayX.Tab = {}

-- Section (как на скрине блоки)
function RayX.Tab:_sectionContainer(titleText)
    local theme = self._theme

    local cont = Instance.new("Frame")
    cont.BackgroundColor3 = theme.Panel
    cont.Size = UDim2.new(1, 0, 0, 0)
    cont.AutomaticSize = Enum.AutomaticSize.Y
    cont.Parent = self._page
    roundify(cont, theme.Corner)
    stroke(cont, theme.Stroke, 1)
    padding(cont, theme.Padding)

    if titleText then
        local ttl = label(cont, titleText, theme.TextSize + 1, theme.Text, theme.Font)
        ttl.Size = UDim2.new(1, 0, 0, theme.TextSize + 6)
    end

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 6)
    list.Parent = cont

    return cont
end

-- Button
function RayX.Tab:CreateButton(opts)
    opts = opts or {}
    local theme = self._theme

    local cont = self:_sectionContainer()
    cont.Size = UDim2.new(1, 0, 0, 40)

    local btn = Instance.new("TextButton")
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = theme.Panel2
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = cont
    roundify(btn, theme.Corner)
    stroke(btn, theme.Stroke, 1)

    local lbl = label(btn, opts.Name or "Button", theme.TextSize, theme.Text, theme.Font)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.Size = UDim2.new(1, -16, 1, 0)

    btn.MouseButton1Click:Connect(function()
        if opts.Callback then task.spawn(opts.Callback) end
    end)

    local obj = {
        Frame = cont,
        Button = btn,
        Label  = lbl,
        Set = function(_, t) lbl.Text = t end
    }
    table.insert(self._controls, obj)
    return obj
end

-- Toggle
function RayX.Tab:CreateToggle(opts)
    opts = opts or {}
    local theme = self._theme
    local flag = opts.Flag
    local value = self._config:Get(flag, opts.CurrentValue or false)

    local cont = self:_sectionContainer()
    cont.Size = UDim2.new(1, 0, 0, 40)

    local lbl = label(cont, opts.Name or "Toggle", theme.TextSize, theme.Text, theme.Font)
    lbl.Size = UDim2.new(1, -60, 1, 0)

    local btn = Instance.new("TextButton")
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.BackgroundColor3 = value and theme.Accent or theme.Stroke
    btn.Size = UDim2.new(0, 40, 0, 20)
    btn.Position = UDim2.new(1, -48, 0.5, -10)
    btn.Parent = cont
    roundify(btn, 10)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(value and 1 or 0, value and -18 or 2, 0.5, -8)
    knob.Parent = btn
    roundify(knob, 8)

    local function set(v, fire)
        value = v
        self._config:Set(flag, v)
        tween(btn, theme.Animation, { BackgroundColor3 = v and theme.Accent or theme.Stroke })
        tween(knob, theme.Animation, { Position = UDim2.new(v and 1 or 0, v and -18 or 2, 0.5, -8) })
        if fire and opts.Callback then task.spawn(opts.Callback, v) end
    end

    btn.MouseButton1Click:Connect(function() set(not value, true) end)

    set(value, false)

    local obj = {
        Frame = cont,
        Get = function() return value end,
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

    local value = self._config:Get(flag, opts.CurrentValue or min)

    local cont = self:_sectionContainer()
    cont.Size = UDim2.new(1, 0, 0, 70)

    local nameLbl = label(cont, opts.Name or "Slider", theme.TextSize, theme.Text, theme.Font)
    nameLbl.Size = UDim2.new(1, 0, 0, theme.TextSize + 6)

    local valueLbl = label(cont, "", theme.TextSize, theme.Text, theme.Font, Enum.TextXAlignment.Right)
    valueLbl.Size = UDim2.new(1, 0, 0, theme.TextSize + 6)

    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = theme.Panel2
    bar.Size = UDim2.new(1, 0, 0, 6)
    bar.Parent = cont
    roundify(bar, 3)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = theme.Accent
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.Parent = bar
    roundify(fill, 3)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.Parent = bar
    roundify(knob, 5)

    local dragging = false

    local function snap(v)
        v = math.clamp(v, min, max)
        v = math.floor((v - min) / inc + 0.5) * inc + min
        return math.clamp(v, min, max)
    end

    local function updateUI(v)
        local pct = (v - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -5, 0.5, -5)
        valueLbl.Text = tostring(v) .. (suffix ~= "" and (" "..suffix) or "")
    end

    local function set(v, fire)
        value = snap(v)
        self._config:Set(flag, value)
        updateUI(value)
        if fire and opts.Callback then task.spawn(opts.Callback, value) end
    end

    local function mouseToValue(x)
        local rel = (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
        return min + (max - min) * rel
    end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            set(mouseToValue(i.Position.X), true)
        end
    end)
    bar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            set(mouseToValue(i.Position.X), true)
        end
    end)

    set(value, false)

    local obj = {
        Frame = cont,
        Get = function() return value end,
        Set = function(_, v) set(v, true) end
    }
    table.insert(self._controls, obj)
    return obj
end

-- Input
function RayX.Tab:CreateInput(opts)
    opts = opts or {}
    local theme = self._theme
    local flag = opts.Flag

    local value = self._config:Get(flag, opts.CurrentValue or "")

    local cont = self:_sectionContainer()
    cont.Size = UDim2.new(1, 0, 0, 70)

    local nameLbl = label(cont, opts.Name or "Input", theme.TextSize, theme.Text, theme.Font)
    nameLbl.Size = UDim2.new(1, 0, 0, theme.TextSize + 6)

    local box = Instance.new("TextBox")
    box.BackgroundColor3 = theme.Panel2
    box.Font = theme.Font
    box.TextSize = theme.TextSize
    box.TextColor3 = theme.Text
    box.PlaceholderText = opts.PlaceholderText or ""
    box.ClearTextOnFocus = opts.RemoveTextAfterFocusLost or false
    box.Text = value
    box.Size = UDim2.new(1, 0, 0, 28)
    box.Parent = cont
    roundify(box, theme.Corner)
    stroke(box, theme.Stroke, 1)

    local function set(v, fire)
        value = v
        self._config:Set(flag, value)
        if fire and opts.Callback then task.spawn(opts.Callback, v) end
    end

    box.FocusLost:Connect(function() set(box.Text, true) end)

    local obj = {
        Frame = cont,
        Get = function() return value end,
        Set = function(_, v) box.Text = v; set(v, true) end
    }
    table.insert(self._controls, obj)
    return obj
end

-- Dropdown (single)
function RayX.Tab:CreateDropdown(opts)
    opts = opts or {}
    local theme = self._theme
    local flag = opts.Flag
    local options = opts.Options or {}

    local current = self._config:Get(flag, opts.CurrentOption or { options[1] }) -- table
    if type(current) ~= "table" then current = { current } end

    local cont = self:_sectionContainer()
    cont.Size = UDim2.new(1, 0, 0, 70)

    local nameLbl = label(cont, opts.Name or "Dropdown", theme.TextSize, theme.Text, theme.Font)
    nameLbl.Size = UDim2.new(1, 0, 0, theme.TextSize + 6)

    local drop = Instance.new("TextButton")
    drop.AutoButtonColor = false
    drop.BackgroundColor3 = theme.Panel2
    drop.Text = ""
    drop.Size = UDim2.new(1, 0, 0, 28)
    drop.Parent = cont
    roundify(drop, theme.Corner)
    stroke(drop, theme.Stroke, 1)

    local text = label(drop, current[1] or "", theme.TextSize, theme.Text, theme.Font, Enum.TextXAlignment.Left)
    text.Size = UDim2.new(1, -24, 1, 0)
    text.Position = UDim2.new(0, 8, 0, 0)

    local arrow = label(drop, "▼", theme.TextSize, theme.Text, theme.Font, Enum.TextXAlignment.Right)
    arrow.Size = UDim2.new(1, -6, 1, 0)

    local list = Instance.new("Frame")
    list.BackgroundColor3 = theme.Panel2
    list.Visible = false
    list.Size = UDim2.new(1, 0, 0, 0)
    list.Position = UDim2.new(0, 0, 1, 4)
    list.Parent = cont
    roundify(list, theme.Corner)
    stroke(list, theme.Stroke, 1)
    padding(list, 6)

    local layout = Instance.new("UIListLayout")
    layout.Parent = list
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)

    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for _, opt in ipairs(options) do
            local b = Instance.new("TextButton")
            b.AutoButtonColor = false
            b.BackgroundColor3 = theme.Panel
            b.Text = ""
            b.Size = UDim2.new(1, 0, 0, 24)
            b.Parent = list
            roundify(b, theme.Corner)
            stroke(b, theme.Stroke, 1)

            local l = label(b, opt, theme.TextSize, theme.Text, theme.Font)
            l.Size = UDim2.new(1, -8, 1, 0)
            l.Position = UDim2.new(0, 8, 0, 0)

            b.MouseButton1Click:Connect(function()
                current = { opt }
                text.Text = opt
                self._config:Set(flag, current)
                if opts.Callback then task.spawn(opts.Callback, current) end
                list.Visible = false
            end)
        end
        task.wait()
        list.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end

    drop.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
        if list.Visible then rebuild() end
    end)

    local obj = {
        Frame = cont,
        Get = function()
            local copy = {}
            for i,v in ipairs(current) do copy[i] = v end
            return copy
        end,
        Set = function(_, tbl)
            current = { tbl and tbl[1] or options[1] }
            text.Text = current[1] or ""
            self._config:Set(flag, current)
            if opts.Callback then task.spawn(opts.Callback, current) end
        end,
        SetOptions = function(_, newOpts)
            options = newOpts
            rebuild()
        end
    }
    table.insert(self._controls, obj)
    return obj
end

-- ====== root export ======
local Root = {}
setmetatable(Root, RayX)
return Root
