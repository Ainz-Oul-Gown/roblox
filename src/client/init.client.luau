--!strict

-- Client initialization script (StarterPlayerScripts)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local abilityEvent = ReplicatedStorage:WaitForChild("AbilityEvent", 15) :: RemoteEvent?
local claimPlotEvent = ReplicatedStorage:WaitForChild("ClaimPlotEvent", 15) :: RemoteEvent?
local plotStateEvent = ReplicatedStorage:WaitForChild("PlotStateEvent", 15) :: RemoteEvent?

-- 1. Создание Gen Alpha Brainrot HUD
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Индикатор статуса карты в центре экрана
local statusBanner = Instance.new("TextLabel")
statusBanner.Name = "StatusBanner"
statusBanner.Size = UDim2.new(0, 560, 0, 42)
statusBanner.Position = UDim2.new(0.5, -280, 0, 15)
statusBanner.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
statusBanner.BackgroundTransparency = 0.05
statusBanner.TextColor3 = Color3.fromRGB(255, 255, 255)
statusBanner.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
statusBanner.TextStrokeTransparency = 0
statusBanner.TextScaled = true
statusBanner.Font = Enum.Font.FredokaOne
statusBanner.BorderSizePixel = 0
statusBanner.Parent = screenGui

local sbCorner = Instance.new("UICorner")
sbCorner.CornerRadius = UDim.new(0, 10)
sbCorner.Parent = statusBanner

local sbStroke = Instance.new("UIStroke")
sbStroke.Color = Color3.fromRGB(241, 196, 15)
sbStroke.Thickness = 2
sbStroke.Parent = statusBanner

local function applyStatusText(txt: string)
    statusBanner.Text = txt
    if string.find(txt, "✅") then
        statusBanner.TextColor3 = Color3.fromRGB(80, 255, 120)
        sbStroke.Color = Color3.fromRGB(46, 204, 113)
        task.delay(4, function()
            statusBanner.Visible = false
        end)
    elseif string.find(txt, "❌") or string.find(txt, "⚠️") then
        statusBanner.TextColor3 = Color3.fromRGB(255, 100, 100)
        sbStroke.Color = Color3.fromRGB(231, 76, 60)
    else
        statusBanner.TextColor3 = Color3.fromRGB(255, 220, 80)
        sbStroke.Color = Color3.fromRGB(241, 196, 15)
    end
end

local function updateWorldStatus()
    local wm = game.Workspace:FindFirstChild("WorldMap")
    local tp = game.Workspace:FindFirstChild("TycoonPlots")
    if wm and tp then
        applyStatusText("✅ Остров и 8 баз активны! Выбери базу")
        return
    end

    local statusVal = ReplicatedStorage:FindFirstChild("ServerInitStatus") :: StringValue?
    if statusVal and statusVal.Value ~= "" then
        applyStatusText(statusVal.Value)
    else
        applyStatusText("⚠️ Сервер ещё не загрузился (нажми Stop [Shift+F5] → Play [F5])")
    end
end

updateWorldStatus()

-- Слушаем изменения ServerInitStatus от сервера
local function listenToStatusVal(sv: Instance)
    if sv.Name == "ServerInitStatus" and sv:IsA("StringValue") then
        applyStatusText(sv.Value)
        sv.Changed:Connect(function(newVal)
            applyStatusText(newVal)
        end)
    end
end

local existingSv = ReplicatedStorage:FindFirstChild("ServerInitStatus")
if existingSv then
    listenToStatusVal(existingSv)
end
ReplicatedStorage.ChildAdded:Connect(listenToStatusVal)

game.Workspace.ChildAdded:Connect(function(child)
    if child.Name == "WorldMap" or child.Name == "TycoonPlots" then
        updateWorldStatus()
    end
end)

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

-- Кнопка открытия меню (ТОЛЬКО для смены базы если она уже есть)
-- Убираем эту кнопку — базу теперь выбирают физически
local openSelectBtn = Instance.new("TextButton")
openSelectBtn.Name = "OpenSelectBtn"
openSelectBtn.Size = UDim2.new(0, 200, 0, 40)
openSelectBtn.Position = UDim2.new(0, 20, 0, 140)
openSelectBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
openSelectBtn.Text = "🗺️ СМЕНИТЬ БАЗУ"
openSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openSelectBtn.TextScaled = true
openSelectBtn.Font = Enum.Font.FredokaOne
openSelectBtn.Visible = false -- скрыта пока нет базы; появится после захвата
openSelectBtn.Parent = screenGui

local openBtnCorner = Instance.new("UICorner")
openBtnCorner.CornerRadius = UDim.new(0, 10)
openBtnCorner.Parent = openSelectBtn

-- 2. Окно СМЕНЫ базы (изначально скрыто)
local selectModal = Instance.new("Frame")
selectModal.Name = "SelectModal"
selectModal.Size = UDim2.new(0, 680, 0, 480)
selectModal.Position = UDim2.new(0.5, -340, 0.5, -240)
selectModal.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
selectModal.BorderSizePixel = 0
selectModal.Visible = false -- Не показывается при старте! Базу выбирают ногами.
selectModal.Parent = screenGui

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 16)
modalCorner.Parent = selectModal

local modalStroke = Instance.new("UIStroke")
modalStroke.Color = Color3.fromRGB(241, 196, 15)
modalStroke.Thickness = 3
modalStroke.Parent = selectModal

local modalTitle = Instance.new("TextLabel")
modalTitle.Size = UDim2.new(1, -60, 0, 45)
modalTitle.Position = UDim2.new(0, 20, 0, 10)
modalTitle.BackgroundTransparency = 1
modalTitle.Text = "🔥 ВЫБЕРИ СВОЮ БАЗУ (ФРАКЦИЮ) 🔥"
modalTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
modalTitle.TextScaled = true
modalTitle.Font = Enum.Font.FredokaOne
modalTitle.Parent = selectModal

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.Parent = selectModal
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    selectModal.Visible = false
end)

openSelectBtn.MouseButton1Click:Connect(function()
    selectModal.Visible = not selectModal.Visible
end)

-- Сетка карточек 8 баз
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -30, 1, -70)
scroll.Position = UDim2.new(0, 15, 0, 60)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, 640)
scroll.Parent = selectModal

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 305, 0, 140)
gridLayout.CellPadding = UDim2.new(0, 15, 0, 15)
gridLayout.Parent = scroll

local FACTION_CARDS = {
    { id = 1, name = "🚽 Скибиди Таун", ability = "Skibidi Spin (Вихрь смыва)", color = Color3.fromRGB(241, 196, 15) },
    { id = 2, name = "🗿 Гигачад Мьюинг", ability = "Mewing Stare (Стан челюстью)", color = Color3.fromRGB(149, 165, 166) },
    { id = 3, name = "🕶️ Патрик Сигма", ability = "Phonk Rage (Скорость + Щит)", color = Color3.fromRGB(142, 68, 173) },
    { id = 4, name = "🍔 Фанум Такс", ability = "Tax Snatch (Кража 10% Ауры)", color = Color3.fromRGB(230, 126, 34) },
    { id = 5, name = "🥤 Гримас Шейк", ability = "Grimace Cloud (Ядовитый дым)", color = Color3.fromRGB(155, 89, 182) },
    { id = 6, name = "🪐 КейсОх Гравити", ability = "CaseOh Slam (Землетрясение)", color = Color3.fromRGB(52, 73, 94) },
    { id = 7, name = "❤️ Риззлер & Гронк", ability = "Unspoken Rizz (Ослепление)", color = Color3.fromRGB(231, 76, 60) },
    { id = 8, name = "🔨 Тунг-Тунг Сахур", ability = "Tung Hammer (Подброс в небо)", color = Color3.fromRGB(39, 174, 96) },
}

local cardButtons: { [number]: TextButton } = {}

for _, item in ipairs(FACTION_CARDS) do
    local card = Instance.new("Frame")
    card.Name = "Card_" .. item.id
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    card.BorderSizePixel = 0
    card.Parent = scroll

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 10)
    cCorner.Parent = card

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = item.color
    cStroke.Thickness = 2
    cStroke.Parent = card

    local tLabel = Instance.new("TextLabel")
    tLabel.Size = UDim2.new(1, -20, 0, 30)
    tLabel.Position = UDim2.new(0, 10, 0, 8)
    tLabel.BackgroundTransparency = 1
    tLabel.Text = item.name
    tLabel.TextColor3 = item.color
    tLabel.TextScaled = true
    tLabel.Font = Enum.Font.FredokaOne
    tLabel.Parent = card

    local aLabel = Instance.new("TextLabel")
    aLabel.Size = UDim2.new(1, -20, 0, 35)
    aLabel.Position = UDim2.new(0, 10, 0, 42)
    aLabel.BackgroundTransparency = 1
    aLabel.Text = "⚡ " .. item.ability
    aLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    aLabel.TextScaled = true
    aLabel.Font = Enum.Font.SourceSans
    aLabel.Parent = card

    local pickBtn = Instance.new("TextButton")
    pickBtn.Name = "PickBtn"
    pickBtn.Size = UDim2.new(1, -20, 0, 40)
    pickBtn.Position = UDim2.new(0, 10, 1, -48)
    pickBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    pickBtn.Text = "👉 ВЫБРАТЬ ЭТУ БАЗУ"
    pickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pickBtn.TextScaled = true
    pickBtn.Font = Enum.Font.FredokaOne
    pickBtn.Parent = card

    local pCorner = Instance.new("UICorner")
    pCorner.CornerRadius = UDim.new(0, 8)
    pCorner.Parent = pickBtn

    pickBtn.MouseButton1Click:Connect(function()
        if claimPlotEvent then
            claimPlotEvent:FireServer(item.id)
            selectModal.Visible = false
        end
    end)

    cardButtons[item.id] = pickBtn
end

-- Синхронизация статусов занятости баз
local localHasBase = false

if plotStateEvent then
    plotStateEvent.OnClientEvent:Connect(function(statuses)
        if type(statuses) == "table" then
            for plotIndex = 1, 8 do
                local status = statuses[plotIndex]
                local btn = cardButtons[plotIndex]
                if btn and status then
                    if status.isClaimed then
                        local isOwnBase = status.ownerName == localPlayer.Name
                        if isOwnBase then
                            btn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
                            btn.Text = "✅ МОЯ БАЗА"
                            btn.Active = false
                            -- Показываем кнопку смены базы и обновляем HUD
                            openSelectBtn.Visible = true
                            localHasBase = true
                        else
                            btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                            btn.Text = string.format("🔒 ЗАНЯТО: %s", status.ownerName or "Игроком")
                            btn.Active = false
                        end
                    else
                        btn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
                        btn.Text = "👉 ЗАНЯТЬ ЭТУ БАЗУ"
                        btn.Active = true
                    end
                end
            end
        end
    end)
end

-- Всплывающее уведомление (Toast)
local toastFrame = Instance.new("Frame")
toastFrame.Name = "ToastFrame"
toastFrame.Size = UDim2.new(0, 420, 0, 50)
toastFrame.Position = UDim2.new(0.5, -210, 0, -60)
toastFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
toastFrame.BackgroundTransparency = 0.1
toastFrame.BorderSizePixel = 0
toastFrame.Visible = false
toastFrame.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 12)
toastCorner.Parent = toastFrame

local toastStroke = Instance.new("UIStroke")
toastStroke.Color = Color3.fromRGB(241, 196, 15)
toastStroke.Thickness = 2
toastStroke.Parent = toastFrame

local toastLabel = Instance.new("TextLabel")
toastLabel.Size = UDim2.new(1, -20, 1, 0)
toastLabel.Position = UDim2.new(0, 10, 0, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.Text = ""
toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
toastLabel.TextScaled = true
toastLabel.Font = Enum.Font.FredokaOne
toastLabel.Parent = toastFrame

local function showToast(message: string, color: Color3?)
    toastLabel.Text = message
    toastStroke.Color = color or Color3.fromRGB(241, 196, 15)
    toastFrame.Visible = true
    toastFrame.Position = UDim2.new(0.5, -210, 0, -60)
    
    local inTween = TweenService:Create(toastFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -210, 0, 30)
    })
    inTween:Play()
    
    task.delay(2.8, function()
        if toastFrame.Parent then
            local outTween = TweenService:Create(toastFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -210, 0, -60)
            })
            outTween:Play()
            outTween.Completed:Connect(function()
                if toastFrame.Position.Y.Offset <= -50 then
                    toastFrame.Visible = false
                end
            end)
        end
    end)
end

-- 3. Кнопка активации способности на экране (справа внизу)
local abilityBtn = Instance.new("TextButton")
abilityBtn.Name = "AbilityButton"
abilityBtn.Size = UDim2.new(0, 150, 0, 60)
abilityBtn.Position = UDim2.new(1, -170, 1, -80)
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

local isAbilityOnCooldown = false
local currentCooldownRemaining = 0

local function castAbility()
    if isAbilityOnCooldown then
        showToast(string.format("⏳ Перезарядка: %d сек!", currentCooldownRemaining), Color3.fromRGB(230, 126, 34))
        return
    end

    if abilityEvent then
        abilityEvent:FireServer()
        local tIn = TweenService:Create(abilityBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 135, 0, 50) })
        local tOut = TweenService:Create(abilityBtn, TweenInfo.new(0.2), { Size = UDim2.new(0, 150, 0, 60) })
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

-- Обработка ответа сервера на применение способности
if abilityEvent then
    abilityEvent.OnClientEvent:Connect(function(status: string, messageOrName: string, duration: number, factionId: string?)
        if status == "SUCCESS" then
            isAbilityOnCooldown = true
            currentCooldownRemaining = duration or 12
            abilityBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
            btnStroke.Color = Color3.fromRGB(150, 150, 150)
            showToast(string.format("⚡ %s АКТИВИРОВАНА!", messageOrName), Color3.fromRGB(46, 204, 113))

            -- Локальные визуальные спецэффекты для игрока
            local char = localPlayer.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root and factionId == "Skibidi" then
                    task.spawn(function()
                        for _ = 1, 15 do
                            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(24), 0)
                            task.wait(0.03)
                        end
                    end)
                end
            end

            -- Таймер обратного отсчета на кнопке
            task.spawn(function()
                while currentCooldownRemaining > 0 do
                    abilityBtn.Text = string.format("⏳ %dс\n[КД]", currentCooldownRemaining)
                    task.wait(1.0)
                    currentCooldownRemaining -= 1
                end
                isAbilityOnCooldown = false
                abilityBtn.Text = "⚡ СПОСОБНОСТЬ\n[E]"
                abilityBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
                btnStroke.Color = Color3.fromRGB(255, 255, 255)
                showToast("⚡ Способность снова готова к бою!", Color3.fromRGB(241, 196, 15))
            end)

        elseif status == "COOLDOWN" then
            showToast(string.format("⏳ Перезарядка: %d сек!", duration or 0), Color3.fromRGB(230, 126, 34))

        elseif status == "ERROR" then
            showToast(string.format("⚠️ %s", messageOrName), Color3.fromRGB(231, 76, 60))
            selectModal.Visible = true
        end
    end)
end

-- 4. Двойной прыжок (Double Jump)
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

-- 5. Привязка к leaderstats
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

-- 6. Приветственная подсказка при спавне (как выбрать базу)
task.delay(1.5, function()
    if not localHasBase then
        showToast("🏃 БЕГИ К ЛЮБОЙ БАЗЕ И ВСТАНЬ НА КВАДРАТ!", Color3.fromRGB(52, 152, 219))
        task.delay(4, function()
            if not localHasBase then
                showToast("👀 Смотри на фонари — они ведут к 8 базам по дороге!", Color3.fromRGB(241, 196, 15))
            end
        end)
    end
end)

print("[CLIENT] Gen Alpha BrainrotHUD ready! Physical base selection active.")
