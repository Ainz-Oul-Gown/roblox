--!strict

-- Client initialization script (StarterPlayerScripts)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

-- Создание современного HUD на экране
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TycoonHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Контейнер статистики (в верхнем левом углу)
local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsFrame"
statsFrame.Size = UDim2.new(0, 220, 0, 90)
statsFrame.Position = UDim2.new(0, 20, 0, 20)
statsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
statsFrame.BackgroundTransparency = 0.2
statsFrame.BorderSizePixel = 0
statsFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = statsFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 60, 70)
stroke.Thickness = 2
stroke.Parent = statsFrame

-- Заголовок денег
local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLabel"
cashLabel.Size = UDim2.new(1, -20, 0, 45)
cashLabel.Position = UDim2.new(0, 10, 0, 5)
cashLabel.BackgroundTransparency = 1
cashLabel.Text = "$0"
cashLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
cashLabel.TextStrokeColor3 = Color3.fromRGB(0, 50, 0)
cashLabel.TextStrokeTransparency = 0.5
cashLabel.TextScaled = true
cashLabel.Font = Enum.Font.FredokaOne
cashLabel.Parent = statsFrame

-- Множитель дохода и Rebirths
local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Size = UDim2.new(1, -20, 0, 30)
infoLabel.Position = UDim2.new(0, 10, 0, 50)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Множитель: x1.0 | Rebirths: 0"
infoLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
infoLabel.TextScaled = true
infoLabel.Font = Enum.Font.FredokaOne
infoLabel.Parent = statsFrame

-- Подключение к leaderstats
local function bindLeaderstats()
    local leaderstats = localPlayer:WaitForChild("leaderstats", 10)
    if not leaderstats then return end

    local cashVal = leaderstats:WaitForChild("Cash", 10) :: IntValue?
    local rebirthVal = leaderstats:WaitForChild("Rebirths", 10) :: IntValue?

    local function updateDisplay()
        local cash = if cashVal then cashVal.Value else 0
        local rebirths = if rebirthVal then rebirthVal.Value else 0
        local mult = 1.0 + (rebirths * 0.5)

        cashLabel.Text = string.format("$%s", tostring(cash))
        infoLabel.Text = string.format("Множитель: x%.1f | Rebirths: %d", mult, rebirths)

        -- Легкая микроанимация масштаба
        local tweenIn = TweenService:Create(cashLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextColor3 = Color3.fromRGB(100, 255, 150)
        })
        local tweenOut = TweenService:Create(cashLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextColor3 = Color3.fromRGB(46, 204, 113)
        })
        tweenIn:Play()
        tweenIn.Completed:Connect(function() tweenOut:Play() end)
    end

    if cashVal then
        cashVal.Changed:Connect(updateDisplay)
    end
    if rebirthVal then
        rebirthVal.Changed:Connect(updateDisplay)
    end

    updateDisplay()
end

task.spawn(bindLeaderstats)
print("[CLIENT] TycoonHUD initialized successfully!")
