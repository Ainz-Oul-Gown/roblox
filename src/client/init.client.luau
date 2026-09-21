--!strict

-- Client initialization script (StarterPlayerScripts)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

-- 1. Создание Gen Alpha Brainrot HUD (создается сразу, без блокирующих ожиданий!)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local abilityEvent = ReplicatedStorage:WaitForChild("AbilityEvent", 15) :: RemoteEvent?
local claimPlotEvent = ReplicatedStorage:WaitForChild("ClaimPlotEvent", 15) :: RemoteEvent?
local plotStateEvent = ReplicatedStorage:WaitForChild("PlotStateEvent", 15) :: RemoteEvent?
local vaultUpdatedEvent = ReplicatedStorage:WaitForChild("VaultUpdatedEvent", 15) :: RemoteEvent?
local withdrawEvent = ReplicatedStorage:WaitForChild("WithdrawEvent", 15) :: RemoteEvent?
local pvpKillEvent = ReplicatedStorage:WaitForChild("PvPKillEvent", 15) :: RemoteEvent?
local airDropEvent = ReplicatedStorage:WaitForChild("AirDropEvent", 15) :: RemoteEvent?
local adminGiveCashEvent = ReplicatedStorage:WaitForChild("AdminGiveCashEvent", 15) :: RemoteEvent?
local rebirthEvent = ReplicatedStorage:WaitForChild("RebirthEvent", 15) :: RemoteEvent?
local abilityVFXEvent = ReplicatedStorage:WaitForChild("AbilityVFXEvent", 15) :: RemoteEvent?
local equippedPetsEvent = ReplicatedStorage:WaitForChild("EquippedPetsEvent", 15) :: RemoteEvent?
local openEggEvent = ReplicatedStorage:WaitForChild("OpenEggEvent", 15) :: RemoteEvent?
local claimPlaytimeEvent = ReplicatedStorage:WaitForChild("ClaimPlaytimeRewardEvent", 15) :: RemoteEvent?
local claimDailyEvent = ReplicatedStorage:WaitForChild("ClaimDailyRewardEvent", 15) :: RemoteEvent?

-- Безопасная загрузка JuiceEffects (поддержка как script, так и script.Parent)
local juiceModule = script:FindFirstChild("JuiceEffects")
    or (script.Parent and script.Parent:FindFirstChild("JuiceEffects"))
    or script:WaitForChild("JuiceEffects", 3)
    or (script.Parent and script.Parent:WaitForChild("JuiceEffects", 1))

local JuiceEffects: any = nil
if juiceModule and juiceModule:IsA("ModuleScript") then
    local ok, res = pcall(require, juiceModule)
    if ok and res then
        JuiceEffects = res
    else
        warn("[CLIENT] JuiceEffects load warning:", res)
    end
end

if not JuiceEffects then
    JuiceEffects = {
        playSound = function(...) end,
        showFloatingText = function(...) end,
        animateButtonSuccess = function(...) end,
        animateButtonFailure = function(...) end,
        screenFlash = function(...) end,
        spawnConfetti = function(...) end,
    }
end

-- Безопасная загрузка PetFollower (Pet & Egg Gacha System)
local petFollowerModule = script:FindFirstChild("PetFollower")
    or (script.Parent and script.Parent:FindFirstChild("PetFollower"))
    or script:WaitForChild("PetFollower", 3)
    or (script.Parent and script.Parent:WaitForChild("PetFollower", 1))

local PetFollower: any = nil
if petFollowerModule and petFollowerModule:IsA("ModuleScript") then
    local ok, res = pcall(require, petFollowerModule)
    if ok and res then
        PetFollower = res
    end
end

-- Безопасная загрузка AbilityVFX
local abilityVfxModule = script:FindFirstChild("AbilityVFX")
    or (script.Parent and script.Parent:FindFirstChild("AbilityVFX"))
    or script:WaitForChild("AbilityVFX", 3)
    or (script.Parent and script.Parent:WaitForChild("AbilityVFX", 1))

local AbilityVFX: any = nil
if abilityVfxModule and abilityVfxModule:IsA("ModuleScript") then
    local ok, res = pcall(require, abilityVfxModule)
    if ok and res then
        AbilityVFX = res
    else
        warn("[CLIENT] AbilityVFX load warning:", res)
    end
end

local showToast: (string, Color3?) -> ()

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
mainFrame.Size = UDim2.new(0, 250, 0, 140)
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
auraLabel.Size = UDim2.new(1, -20, 0, 42)
auraLabel.Position = UDim2.new(0, 10, 0, 6)
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
rankLabel.Size = UDim2.new(1, -20, 0, 24)
rankLabel.Position = UDim2.new(0, 10, 0, 48)
rankLabel.BackgroundTransparency = 1
rankLabel.Text = "🗿 Ранг: Новичок Мьюинга"
rankLabel.TextColor3 = Color3.fromRGB(189, 195, 199)
rankLabel.TextScaled = true
rankLabel.Font = Enum.Font.FredokaOne
rankLabel.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Size = UDim2.new(1, -20, 0, 22)
infoLabel.Position = UDim2.new(0, 10, 0, 74)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Множитель: x1.0 | Rebirths: 0"
infoLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
infoLabel.TextScaled = true
infoLabel.Font = Enum.Font.FredokaOne
infoLabel.Parent = mainFrame

local vaultLabel = Instance.new("TextLabel")
vaultLabel.Name = "VaultLabel"
vaultLabel.Size = UDim2.new(1, -20, 0, 24)
vaultLabel.Position = UDim2.new(0, 10, 0, 104)
vaultLabel.BackgroundTransparency = 1
vaultLabel.Text = "🏦 СЕЙФ БАЗЫ: +0 🛡️"
vaultLabel.TextColor3 = Color3.fromRGB(52, 152, 219)
vaultLabel.TextScaled = true
vaultLabel.Font = Enum.Font.FredokaOne
vaultLabel.Parent = mainFrame

-- Кнопка открытия меню (ТОЛЬКО для смены базы если она уже есть)
local openSelectBtn = Instance.new("TextButton")
openSelectBtn.Name = "OpenSelectBtn"
openSelectBtn.Size = UDim2.new(0, 200, 0, 40)
openSelectBtn.Position = UDim2.new(0, 20, 0, 170)
openSelectBtn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
openSelectBtn.Text = "🗺️ СМЕНИТЬ БАЗУ"
openSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openSelectBtn.TextScaled = true
openSelectBtn.Font = Enum.Font.FredokaOne
openSelectBtn.Visible = false
openSelectBtn.Parent = screenGui

local openBtnCorner = Instance.new("UICorner")
openBtnCorner.CornerRadius = UDim.new(0, 10)
openBtnCorner.Parent = openSelectBtn

-- Временная кнопка для админа: моментальный лут ауры
local adminCashBtn = Instance.new("TextButton")
adminCashBtn.Name = "AdminCashBtn"
adminCashBtn.Size = UDim2.new(0, 220, 0, 42)
adminCashBtn.Position = UDim2.new(0, 20, 0, 220)
adminCashBtn.BackgroundColor3 = Color3.fromRGB(243, 156, 18)
adminCashBtn.Text = "👑 +1M AURA [P]"
adminCashBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
adminCashBtn.TextStrokeColor3 = Color3.fromRGB(150, 70, 0)
adminCashBtn.TextStrokeTransparency = 0.2
adminCashBtn.TextScaled = true
adminCashBtn.Font = Enum.Font.FredokaOne
adminCashBtn.BorderSizePixel = 0
adminCashBtn.Parent = screenGui

local adminBtnCorner = Instance.new("UICorner")
adminBtnCorner.CornerRadius = UDim.new(0, 10)
adminBtnCorner.Parent = adminCashBtn

local adminBtnStroke = Instance.new("UIStroke")
adminBtnStroke.Color = Color3.fromRGB(255, 240, 100)
adminBtnStroke.Thickness = 2.5
adminBtnStroke.Parent = adminCashBtn

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

-- P1-NEW-01 FIX: Удалён дубликат equippedPetsEvent (2-я декларация устранена —
-- используется единственный обработчик на строках 711-725)

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

showToast = function(message: string, color: Color3?)
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

-- Обработчик админ-фишки (лут ауры)
local function triggerAdminCash()
    if adminGiveCashEvent then
        adminGiveCashEvent:FireServer(1000000)
    end
    JuiceEffects.playSound("cash", 1.0)
    JuiceEffects.screenFlash(Color3.fromRGB(255, 215, 0), 0.35)

    local char = localPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            JuiceEffects.showFloatingText(root.Position + Vector3.new(0, 3.5, 0), "+1,000,000 AURA 👑", Color3.fromRGB(255, 215, 0), 1.5)
        end
    end
    showToast("👑 АДМИН: +1,000,000 АУРЫ ВЫДАНО!", Color3.fromRGB(255, 215, 0))

    -- Анимация сжатия кнопки
    local origSize = adminCashBtn.Size
    adminCashBtn.Size = UDim2.new(0, 235, 0, 46)
    task.delay(0.1, function()
        if adminCashBtn.Parent then
            adminCashBtn.Size = origSize
        end
    end)
end

adminCashBtn.MouseButton1Click:Connect(triggerAdminCash)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        triggerAdminCash()
    end
end)

-- 3. Центр уведомлений PvP (Лут при убийстве / Потеря при смерти)
local pvpBanner = Instance.new("Frame")
pvpBanner.Name = "PvPBanner"
pvpBanner.Size = UDim2.new(0, 520, 0, 78)
pvpBanner.Position = UDim2.new(0.5, -260, 0, -100)
pvpBanner.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
pvpBanner.BorderSizePixel = 0
pvpBanner.Visible = false
pvpBanner.Parent = screenGui

local pvpCorner = Instance.new("UICorner")
pvpCorner.CornerRadius = UDim.new(0, 14)
pvpCorner.Parent = pvpBanner

local pvpStroke = Instance.new("UIStroke")
pvpStroke.Thickness = 3
pvpStroke.Parent = pvpBanner

local pvpTitle = Instance.new("TextLabel")
pvpTitle.Name = "Title"
pvpTitle.Size = UDim2.new(1, -20, 0, 42)
pvpTitle.Position = UDim2.new(0, 10, 0, 6)
pvpTitle.BackgroundTransparency = 1
pvpTitle.TextScaled = true
pvpTitle.Font = Enum.Font.FredokaOne
pvpTitle.Parent = pvpBanner

local pvpSubtitle = Instance.new("TextLabel")
pvpSubtitle.Name = "Subtitle"
pvpSubtitle.Size = UDim2.new(1, -20, 0, 26)
pvpSubtitle.Position = UDim2.new(0, 10, 0, 46)
pvpSubtitle.BackgroundTransparency = 1
pvpSubtitle.TextScaled = true
pvpSubtitle.Font = Enum.Font.FredokaOne
pvpSubtitle.Parent = pvpBanner

local function showPvPBanner(isKill: boolean, enemyName: string, amount: number)
    pvpBanner.Visible = true
    if isKill then
        pvpStroke.Color = Color3.fromRGB(241, 196, 15)
        pvpTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
        pvpTitle.Text = string.format("💀 ВЫ УНИЧТОЖИЛИ: %s!", string.upper(enemyName))
        pvpSubtitle.TextColor3 = Color3.fromRGB(46, 204, 113)
        pvpSubtitle.Text = string.format("💰 ЛУТ С ЖЕРТВЫ: +%d AURA В КОШЕЛЁК!", amount)
    else
        pvpStroke.Color = Color3.fromRGB(231, 76, 60)
        pvpTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
        pvpTitle.Text = string.format("☠️ ВАС УНИЧТОЖИЛ: %s!", string.upper(enemyName))
        pvpSubtitle.TextColor3 = Color3.fromRGB(241, 196, 15)
        pvpSubtitle.Text = string.format("💸 Потеряно -%d Aura (СЕЙФ НА БАЗЕ ЦЕЛ! 🛡️)", amount)
    end

    pvpBanner.Position = UDim2.new(0.5, -260, 0, -100)
    local tweenIn = TweenService:Create(pvpBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -260, 0, 70)
    })
    tweenIn:Play()

    task.delay(4, function()
        if pvpBanner.Parent then
            local tweenOut = TweenService:Create(pvpBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -260, 0, -100)
            })
            tweenOut:Play()
            tweenOut.Completed:Connect(function()
                if pvpBanner.Position.Y.Offset <= -90 then
                    pvpBanner.Visible = false
                end
            end)
        end
    end)
end

if pvpKillEvent then
    pvpKillEvent.OnClientEvent:Connect(function(data)
        if type(data) ~= "table" then return end
        if data.type == "kill" then
            showPvPBanner(true, data.targetName or "Врага", data.amount or 0)
            JuiceEffects.playSound("powerup", 0.9)
            JuiceEffects.screenFlash(Color3.fromRGB(255, 215, 0), 0.35)
            local char = localPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                JuiceEffects.showFloatingText((char:FindFirstChild("HumanoidRootPart") :: BasePart).Position + Vector3.new(0, 3, 0), string.format("+$%d AURA! 💀", data.amount or 0), Color3.fromRGB(255, 215, 0), 1.6)
            end
        elseif data.type == "death" then
            showPvPBanner(false, data.killerName or "Враг", data.amount or 0)
            JuiceEffects.playSound("error", 0.8)
            JuiceEffects.screenFlash(Color3.fromRGB(231, 76, 60), 0.4)
            local char = localPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                JuiceEffects.showFloatingText((char:FindFirstChild("HumanoidRootPart") :: BasePart).Position + Vector3.new(0, 3, 0), string.format("-$%d AURA ☠️", data.amount or 0), Color3.fromRGB(255, 80, 80), 1.6)
            end
        end
    end)
end

-- Слушатели сейфа базы и вывода в кошелек
if vaultUpdatedEvent then
    vaultUpdatedEvent.OnClientEvent:Connect(function(plotIndex: number, newVaultTotal: number)
        vaultLabel.Text = string.format("🏦 СЕЙФ БАЗЫ: +%s 🛡️", tostring(newVaultTotal))
        local tPulse = TweenService:Create(vaultLabel, TweenInfo.new(0.2, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out, 0, true), {
            TextColor3 = Color3.fromRGB(46, 204, 113)
        })
        tPulse:Play()
    end)
end

if withdrawEvent then
    withdrawEvent.OnClientEvent:Connect(function(amount: number)
        vaultLabel.Text = "🏦 СЕЙФ БАЗЫ: +0 🛡️"
        showToast(string.format("💰 Забрано из сейфа базы: +%d AURA в кошелёк!", amount), Color3.fromRGB(46, 204, 113))
        JuiceEffects.playSound("cash", 0.9)
        JuiceEffects.screenFlash(Color3.fromRGB(255, 215, 0), 0.25)
        local char = localPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            JuiceEffects.showFloatingText((char:FindFirstChild("HumanoidRootPart") :: BasePart).Position + Vector3.new(0, 3, 0), string.format("+$%d AURA 💸", amount), Color3.fromRGB(46, 204, 113), 1.4)
        end
    end)
end

-- Слушатель динамических событий AirDrop
if airDropEvent then
    airDropEvent.OnClientEvent:Connect(function(eventType: string, data: any)
        if eventType == "spawn" then
            JuiceEffects.playSound("siren", 0.9)
            showToast("⚠️ ЗОЛОТОЙ АИРДРОП ПАДАЕТ НА ОСТРОВ! (+$10,000 AURA)", Color3.fromRGB(255, 215, 0))
        elseif eventType == "captured" then
            JuiceEffects.playSound("fanfare", 0.85)
            local winner = if data and data.winnerName then data.winnerName else "Игрок"
            local rew = if data and data.reward then data.reward else 10000
            showToast(string.format("🎉 %s ЗАХВАТИЛ АИРДРОП И ПОЛУЧИЛ +$%d AURA!", winner, rew), Color3.fromRGB(46, 204, 113))
            if winner == localPlayer.Name and localPlayer.Character and localPlayer.Character.PrimaryPart then
                JuiceEffects.spawnConfetti(localPlayer.Character.PrimaryPart.Position)
            end
        end
    end)
end

if rebirthEvent then
    rebirthEvent.OnClientEvent:Connect(function(newRebirths: number, newMult: number)
        JuiceEffects.playSound("fanfare", 1.0)
        JuiceEffects.screenFlash(Color3.fromRGB(255, 215, 0), 0.6)
        showToast(string.format("👑 ПЕРЕРОЖДЕНИЕ #%d ВЫПОЛНЕНО! Множитель x%.1f 🔥", newRebirths, newMult), Color3.fromRGB(255, 215, 0))
        local char = localPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = (char:FindFirstChild("HumanoidRootPart") :: BasePart).Position
            JuiceEffects.spawnConfetti(pos)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), string.format("👑 REBIRTH #%d! x%.1f MULTIPLIER", newRebirths, newMult), Color3.fromRGB(255, 215, 0), 2.5)
        end
    end)
end

-- Синхронизация надетых питомцев и вылупления (Pet Gacha & Anti-Lag Follower)
if equippedPetsEvent then
    equippedPetsEvent.OnClientEvent:Connect(function(petDefs: any, hatchedPetId: any)
        if PetFollower and type(petDefs) == "table" then
            PetFollower.syncEquippedPets(petDefs)
        end
        if hatchedPetId then
            JuiceEffects.playSound("fanfare", 1.0)
            local char = localPlayer.Character
            if char and char.PrimaryPart then
                JuiceEffects.spawnConfetti(char.PrimaryPart.Position)
                JuiceEffects.showFloatingText(char.PrimaryPart.Position, string.format("🐣 ВЫЛУПИЛСЯ: %s!", tostring(hatchedPetId)), Color3.fromRGB(255, 215, 0), 2.5)
            end
        end
    end)
end

-- 3.5 Виджет удержания и подарков (Retention Engine & Daily Streak)
local giftsBtn = Instance.new("TextButton")
giftsBtn.Name = "RetentionGiftsButton"
giftsBtn.Size = UDim2.new(0, 160, 0, 48)
giftsBtn.Position = UDim2.new(0, 20, 0.5, 30)
giftsBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
giftsBtn.Text = "🎁 ПОДАРКИ [T]\n[ЗАБРАТЬ ЛУТ]"
giftsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
giftsBtn.TextScaled = true
giftsBtn.Font = Enum.Font.FredokaOne
giftsBtn.Parent = screenGui

local gbCorner = Instance.new("UICorner")
gbCorner.CornerRadius = UDim.new(0, 10)
gbCorner.Parent = giftsBtn

local gbStroke = Instance.new("UIStroke")
gbStroke.Color = Color3.fromRGB(255, 215, 0)
gbStroke.Thickness = 2
gbStroke.Parent = giftsBtn

local function claimRetentionGifts()
    if claimPlaytimeEvent then
        -- P1-NEW-14 FIX: Запрашиваем все 5 тиров (сервер проверит какие доступны)
        for tier = 1, 5 do
            claimPlaytimeEvent:FireServer(tier)
        end
    end
    if claimDailyEvent then
        claimDailyEvent:FireServer()
    end
    showToast("🎁 Запрос ежедневных наград и сессионного лута отправлен!", Color3.fromRGB(155, 89, 182))
    JuiceEffects.playSound("cash", 0.9)
end

giftsBtn.MouseButton1Click:Connect(claimRetentionGifts)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.T then
        claimRetentionGifts()
    end
end)

-- 4. Способности фракций (Инвентарь, хоткей [E] для активного предмета)
local abilityBtn = Instance.new("TextButton")
abilityBtn.Name = "AbilityButton"
abilityBtn.Size = UDim2.new(0, 180, 0, 64)
abilityBtn.Position = UDim2.new(1, -200, 1, -85)
abilityBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
abilityBtn.Text = "⚡ СПОСОБНОСТЬ\n[E]"
abilityBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
abilityBtn.TextScaled = true
abilityBtn.Font = Enum.Font.FredokaOne
abilityBtn.Parent = screenGui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 14)
btnCorner.Parent = abilityBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(255, 255, 255)
btnStroke.Thickness = 2
btnStroke.Parent = abilityBtn

-- Панель горячих клавиш способностей
local hintsLabel = Instance.new("TextLabel")
hintsLabel.Name = "AbilityHints"
hintsLabel.Size = UDim2.new(0, 360, 0, 22)
hintsLabel.Position = UDim2.new(1, -370, 1, -112)
hintsLabel.BackgroundTransparency = 1
hintsLabel.Text = "[1/E] База • [2/R] Тактика • [3/Q] Ульт • [4/F] Спец • [5/Z] Мобильность • [6/X] Бог"
hintsLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
hintsLabel.TextScaled = true
hintsLabel.Font = Enum.Font.FredokaOne
hintsLabel.Parent = screenGui

local cooldownsRemaining: { [string]: number } = {
    base = 0,
    tactical = 0,
    ultimate = 0,
    special = 0,
    mobility = 0,
    godmode = 0,
}
local currentCooldownRemaining = 0

type ClientAbilitySlot = "base" | "tactical" | "ultimate" | "special" | "mobility" | "godmode"
local currentEquippedSlot: ClientAbilitySlot = "base"
local currentEquippedToolName: string? = nil

local function getEquippedAbilitySlot(): ClientAbilitySlot
    local char = localPlayer.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local slot = tool:GetAttribute("AbilitySlot")
            if slot == "base" or slot == "tactical" or slot == "ultimate" or slot == "special" or slot == "mobility" or slot == "godmode" then
                return slot :: any
            end
        end
    end
    return "base"
end

local function updateButtonDisplay()
    local char = localPlayer.Character
    local equippedTool = if char then char:FindFirstChildOfClass("Tool") else nil
    if equippedTool and equippedTool:GetAttribute("AbilitySlot") then
        local slot = equippedTool:GetAttribute("AbilitySlot") :: string
        currentEquippedSlot = slot :: any
        currentEquippedToolName = equippedTool.Name
        local cd = cooldownsRemaining[currentEquippedSlot] or 0
        if cd > 0 then
            abilityBtn.Text = string.format("⏳ %dс [КД]\n%s", cd, equippedTool.Name)
            abilityBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        else
            abilityBtn.Text = string.format("⚡ АКТИВИРОВАТЬ\n%s [E]", equippedTool.Name)
            abilityBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        end
    else
        currentEquippedToolName = nil
        local cd = cooldownsRemaining[currentEquippedSlot] or 0
        if cd > 0 then
            abilityBtn.Text = string.format("⏳ %dс [КД]\n[E]", cd)
            abilityBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        else
            abilityBtn.Text = "⚡ СПОСОБНОСТЬ\n[E]"
            abilityBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        end
    end
end

local function castAbility(slot: ClientAbilitySlot)
    local cd = cooldownsRemaining[slot] or 0
    if cd > 0 then
        showToast(string.format("⏳ Способность на перезарядке: %d сек!", cd), Color3.fromRGB(230, 126, 34))
        return
    end

    if abilityEvent then
        abilityEvent:FireServer(slot)
        local tIn = TweenService:Create(abilityBtn, TweenInfo.new(0.1), { Size = UDim2.new(0, 165, 0, 56) })
        local tOut = TweenService:Create(abilityBtn, TweenInfo.new(0.2), { Size = UDim2.new(0, 180, 0, 64) })
        tIn:Play()
        tIn.Completed:Connect(function() tOut:Play() end)
    end
end

abilityBtn.MouseButton1Click:Connect(function()
    castAbility(getEquippedAbilitySlot())
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E then
        castAbility(getEquippedAbilitySlot())
    elseif input.KeyCode == Enum.KeyCode.R then
        castAbility("tactical")
    elseif input.KeyCode == Enum.KeyCode.Q then
        castAbility("ultimate")
    elseif input.KeyCode == Enum.KeyCode.F then
        castAbility("special")
    elseif input.KeyCode == Enum.KeyCode.Z then
        castAbility("mobility")
    elseif input.KeyCode == Enum.KeyCode.X then
        castAbility("godmode")
    end
end)

-- Надежное связывание Tool с вызовом способности при клике
local boundTools: { [Tool]: boolean } = {}

local function bindTool(tool: Tool)
    if boundTools[tool] then return end
    boundTools[tool] = true
    tool.Activated:Connect(function()
        local slot = tool:GetAttribute("AbilitySlot")
        if slot then
            castAbility(slot :: any)
        else
            castAbility("base")
        end
    end)
end

-- Отслеживание экипировки инструмента
local function watchTools(char: Model)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            bindTool(child)
        end
    end
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            bindTool(child)
            task.wait(0.05)
            updateButtonDisplay()
        end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.05)
            updateButtonDisplay()
        end
    end)
end

-- Отслеживание инструментов в Backpack
local function watchBackpack(bp: Instance)
    for _, child in ipairs(bp:GetChildren()) do
        if child:IsA("Tool") then
            bindTool(child)
        end
    end
    bp.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            bindTool(child)
        end
    end)
end

local bp = localPlayer:FindFirstChild("Backpack")
if bp then watchBackpack(bp) end
localPlayer.ChildAdded:Connect(function(child)
    if child.Name == "Backpack" then
        watchBackpack(child)
    end
end)

if localPlayer.Character then watchTools(localPlayer.Character) end
localPlayer.CharacterAdded:Connect(function(newChar: Model)
    -- P1-NEW-16 FIX: Очищаем ссылки на старые уничтоженные Tool-объекты
    boundTools = {}
    watchTools(newChar)
end)

-- Обработка ответа сервера на способность
if abilityEvent then
    abilityEvent.OnClientEvent:Connect(function(status: string, messageOrName: string, duration: number, slot: string?)
        local s = slot or "base"
        if status == "CAST_SUCCESS" or status == "SUCCESS" then
            cooldownsRemaining[s] = duration or 12
            updateButtonDisplay()
            showToast(string.format("⚡ %s АКТИВИРОВАНА!", messageOrName), Color3.fromRGB(46, 204, 113))

            -- Локальные визуальные спецэффекты
            local char = localPlayer.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root and string.find(string.lower(messageOrName), "spin") then
                    task.spawn(function()
                        for _ = 1, 15 do
                            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(24), 0)
                            task.wait(0.03)
                        end
                    end)
                end
            end

            -- Таймер обратного отсчета для слота
            task.spawn(function()
                while (cooldownsRemaining[s] or 0) > 0 do
                    task.wait(1.0)
                    cooldownsRemaining[s] = math.max(0, (cooldownsRemaining[s] or 0) - 1)
                    updateButtonDisplay()
                end
                showToast(string.format("⚡ %s снова готова к бою!", messageOrName), Color3.fromRGB(241, 196, 15))
            end)

        elseif status == "COOLDOWN" then
            showToast(string.format("⏳ Перезарядка: %d сек!", duration or 0), Color3.fromRGB(230, 126, 34))

        elseif status == "ERROR" then
            showToast(string.format("⚠️ %s", messageOrName), Color3.fromRGB(231, 76, 60))
            if string.find(messageOrName, "выбери базу") then
                selectModal.Visible = true
            end
        end
    end)
end

-- Обработка спецэффектов и звука способностей для всех игроков вокруг
if abilityVFXEvent then
    abilityVFXEvent.OnClientEvent:Connect(function(caster: Player, fId: string, slot: string, originPos: Vector3, lookVector: Vector3)
        if AbilityVFX and AbilityVFX.play then
            AbilityVFX.play(caster, fId, slot, originPos, lookVector)
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
    local function hookLeaderstats(leaderstats: Instance)
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

    local existingLs = localPlayer:FindFirstChild("leaderstats")
    if existingLs then
        hookLeaderstats(existingLs)
    else
        task.spawn(function()
            local ls = localPlayer:WaitForChild("leaderstats", 30)
            if ls then
                hookLeaderstats(ls)
            end
        end)
        localPlayer.ChildAdded:Connect(function(child)
            if child.Name == "leaderstats" then
                hookLeaderstats(child)
            end
        end)
    end
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
