--!strict

-- Client initialization script (StarterPlayerScripts)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local abilityEvent = ReplicatedStorage:WaitForChild("AbilityEvent", 10) :: RemoteEvent?

-- 1. Создание Gen Alpha Brainrot HUD
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Контейнер статистики слева вверху
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 240, 0, 110)
mainFrame.Position = UDim2.new(0, 20, 0, 20)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(241, 196, 15)
stroke.Thickness = 2
stroke.Parent = mainFrame

-- Счетчик Ауры
local auraLabel = Instance.new("TextLabel")
auraLabel.Name = "AuraLabel"
auraLabel.Size = UDim2.new(1, -20, 0, 45)
auraLabel.Position = UDim2.new(0, 10, 0, 8)
auraLabel.BackgroundTransparency = 1
auraLabel.Text = "AURA: +0 🔥"
auraLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
auraLabel.TextStrokeColor3 = Color3.fromRGB(150, 80, 0)
auraLabel.TextStrokeTransparency = 0.3
auraLabel.TextScaled = true
auraLabel.Font = Enum.Font.FredokaOne
auraLabel.Parent = mainFrame

-- Ранг и множитель
local rankLabel = Instance.new("TextLabel")
rankLabel.Name = "RankLabel"
rankLabel.Size = UDim2.new(1, -20, 0, 25)
rankLabel.Position = UDim2.new(0, 10, 0, 52)
rankLabel.BackgroundTransparency = 1
rankLabel.Text = "🗿 Ранг: Новичок Мьюинга"
rankLabel.TextColor3 = Color3.fromRGB(189, 195, 199)
rankLabel.TextScaled = true
rankLabel.Font = Enum.Font.FredokaOne
rankLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Size = UDim2.new(1, -20, 0, 22)
infoLabel.Position = UDim2.new(0, 10, 0, 80)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Множитель: x1.0 | Rebirths: 0"
infoLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
infoLabel.TextScaled = true
infoLabel.Font = Enum.Font.FredokaOne
infoLabel.Parent = mainFrame

-- 2. Кнопка активации способности на экране (справа внизу)
local abilityBtn = Instance.new("TextButton")
abilityBtn.Name = "AbilityButton"
abilityBtn.Size = UDim2.new(0, 140, 0, 60)
abilityBtn.Position = UDim2.new(1, -160, 1, -80)
abilityBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
abilityBtn.Text = "⚡ СПОСОБНОСТЬ\n[E]"
abilityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
abilityBtn.TextScaled = true
abilityBtn.Font = Enum.Font.FredokaOne
abilityBtn.Parent = screenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 12)
btnCorner.Parent = abilityBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(255, 255, 255)
btnStroke.Thickness = 2
btnStroke.Parent = abilityBtn

local function castAbility()
    if abilityEvent then
        abilityEvent:FireServer()
        local tIn = TweenService:Create(abilityBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 125, 0, 50) })
        local tOut = TweenService:Create(abilityBtn, TweenInfo.new(0.2), { Size = UDim2.new(0, 140, 0, 60) })
        tIn:Play()
        tIn.Completed:Connect(function() tOut:Play() end)
    end
end

abilityBtn.MouseButton1Click:Connect(castAbility)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E then
        castAbility()
    end
end)

-- 3. Двойной прыжок (Double Jump) при Rebirth >= 1
local canDoubleJump = false
local hasDoubleJumped = false

UserInputService.JumpRequest:Connect(function()
    if not localPlayer:GetAttribute("DoubleJumpUnlocked") then return end

    local char = localPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?

    if hum and root and canDoubleJump and not hasDoubleJumped then
        hasDoubleJumped = true
        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 48, root.AssemblyLinearVelocity.Z)
    end
end)

-- Отслеживание приземления
local function setupCharacter(char: Model)
    local hum = char:WaitForChild("Humanoid") :: Humanoid
    hum.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            canDoubleJump = false
            hasDoubleJumped = false
        elseif newState == Enum.HumanoidStateType.Freefall then
            canDoubleJump = true
        end
    end)
end

if localPlayer.Character then setupCharacter(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(setupCharacter)

-- 4. Привязка к лидерстатс
local function bindStats()
    local leaderstats = localPlayer:WaitForChild("leaderstats", 15)
    if not leaderstats then return end

    local auraVal = leaderstats:WaitForChild("Aura", 10) :: IntValue?
    local rebirthVal = leaderstats:WaitForChild("Rebirths", 10) :: IntValue?

    local function updateStats()
        local aura = if auraVal then auraVal.Value else 0
        local rebirths = if rebirthVal then rebirthVal.Value else 0

        auraLabel.Text = string.format("AURA: +%s 🔥", tostring(aura))

        local rankNames = {
            [0] = "🗿 Новичок Мьюинга",
            [1] = "🚽 Скибиди Сигма",
            [2] = "🕶️ Ризз Мастер",
            [3] = "📱 Айпад Повелитель",
            [4] = "🪐 КейсОх Гигачад",
            [5] = "👑 БОГ АЛЬФА ПОКОЛЕНИЯ",
        }
        rankLabel.Text = rankNames[math.min(rebirths, 5)] or "👑 БОГ АЛЬФА ПОКОЛЕНИЯ"

        local mults = { [0] = 1.0, [1] = 1.5, [2] = 2.2, [3] = 3.5, [4] = 5.5, [5] = 10.0 }
        local mult = mults[math.min(rebirths, 5)] or (10.0 + (rebirths - 5) * 2.0)
        infoLabel.Text = string.format("Множитель: x%.1f | Rebirths: %d", mult, rebirths)
    end

    if auraVal then auraVal.Changed:Connect(updateStats) end
    if rebirthVal then rebirthVal.Changed:Connect(updateStats) end
    updateStats()
end

task.spawn(bindStats)
print("[CLIENT] Gen Alpha BrainrotHUD ready!")
