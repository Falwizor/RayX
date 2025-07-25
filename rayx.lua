-- Rayfield.lua
local Rayfield = {}
Rayfield.__index = Rayfield

-- Создание главного окна
function Rayfield:CreateWindow(settings)
    local self = setmetatable({}, Rayfield)
    self.Title = settings.Name or "Rayfield UI"
    self.Tabs = {}

    -- Простейшее окно (для теста)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RayfieldUI"
    ScreenGui.Parent = game.CoreGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 400, 0, 300)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    MainFrame.Parent = ScreenGui
    self.MainFrame = MainFrame

    return self
end

-- Создание вкладки
function Rayfield:CreateTab(name)
    local tab = {}
    tab.Name = name or "Tab"
    tab.Elements = {}

    -- Простейший UI Label для таба
    local TabLabel = Instance.new("TextLabel")
    TabLabel.Text = name
    TabLabel.Size = UDim2.new(1, 0, 0, 30)
    TabLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TabLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabLabel.Parent = self.MainFrame

    -- Методы таба
    function tab:CreateButton(settings)
        local button = Instance.new("TextButton")
        button.Text = settings.Name or "Button"
        button.Size = UDim2.new(1, 0, 0, 30)
        button.Position = UDim2.new(0, 0, 0, #self.Elements * 35 + 35)
        button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Parent = self.MainFrame

        button.MouseButton1Click:Connect(function()
            if settings.Callback then
                settings.Callback()
            end
        end)

        table.insert(self.Elements, button)
        return button
    end

    self.Tabs[name] = tab
    return tab
end

-- Уведомления (простейшая версия)
function Rayfield:Notify(settings)
    warn("[Notification] " .. (settings.Title or "No Title") .. ": " .. (settings.Content or ""))
end

return Rayfield
