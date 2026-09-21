--!strict

--[=[
    AirDropService
    Каждые 3.5 минуты генерирует динамическое событие:
    Золотой АирДроп с неба в случайную точку острова с наградой +$10,000 Aura!
]=]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local serverScript = script.Parent or game:GetService("ServerScriptService"):WaitForChild("Server", 10)
local TycoonService = require(serverScript:WaitForChild("TycoonService", 10))
local TycoonConfig = require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("TycoonConfig", 10))

local AirDropService = {}

local AIRDROP_INTERVAL_SEC = 210
local AIRDROP_REWARD = 10000

local function getOrCreateRemote(name: string): RemoteEvent
    local existing = ReplicatedStorage:FindFirstChild(name) :: RemoteEvent?
    if existing then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = ReplicatedStorage
    return remote
end

local airDropEvent = getOrCreateRemote("AirDropEvent")

local currentCrate: Model? = nil

local function spawnAirDrop()
    if currentCrate then
        currentCrate:Destroy()
        currentCrate = nil
    end

    -- Выбираем случайную дорогу из 8 направлений
    local randomRoadAngle = math.rad(math.random(1, 8) * 45)
    local randomDist = math.random(60, 120)
    local landX = math.cos(randomRoadAngle) * randomDist
    local landZ = math.sin(randomRoadAngle) * randomDist
    local landY = 3.5

    local crateModel = Instance.new("Model")
    crateModel.Name = "GoldAirDrop"
    crateModel.Parent = Workspace
    currentCrate = crateModel

    -- Основной золотой ящик
    local crate = Instance.new("Part")
    crate.Name = "Crate"
    crate.Size = Vector3.new(6, 6, 6)
    crate.CFrame = CFrame.new(landX, 85, landZ)
    crate.Anchored = true
    crate.Material = Enum.Material.Neon
    crate.Color = Color3.fromRGB(255, 215, 0)
    crate.Parent = crateModel

    -- Неоновые крепежные ленты
    local band1 = Instance.new("Part")
    band1.Size = Vector3.new(6.2, 1.2, 6.2)
    band1.CFrame = crate.CFrame
    band1.Anchored = true
    band1.Material = Enum.Material.DiamondPlate
    band1.Color = Color3.fromRGB(30, 30, 35)
    band1.Parent = crateModel

    -- Парашют сверху
    local chute = Instance.new("Part")
    chute.Name = "Parachute"
    chute.Size = Vector3.new(14, 2, 14)
    chute.CFrame = crate.CFrame * CFrame.new(0, 10, 0)
    chute.Anchored = true
    chute.Material = Enum.Material.Fabric
    chute.Color = Color3.fromRGB(231, 76, 60)
    chute.Parent = crateModel

    -- Небесный маяк
    local beacon = Instance.new("Part")
    beacon.Size = Vector3.new(1.5, 300, 1.5)
    beacon.CFrame = CFrame.new(landX, 150, landZ)
    beacon.Anchored = true
    beacon.CanCollide = false
    beacon.Material = Enum.Material.Neon
    beacon.Color = Color3.fromRGB(255, 215, 0)
    beacon.Transparency = 0.5
    beacon.Parent = crateModel

    -- Billboard над ящиком
    local bGui = Instance.new("BillboardGui")
    bGui.Size = UDim2.new(0, 260, 0, 70)
    bGui.StudsOffset = Vector3.new(0, 6, 0)
    bGui.AlwaysOnTop = true
    bGui.Parent = crate

    local bLbl = Instance.new("TextLabel")
    bLbl.Size = UDim2.new(1, 0, 1, 0)
    bLbl.BackgroundTransparency = 1
    bLbl.Text = "📦 ЗОЛОТОЙ АИРДРОП\n[Удерживай 4с для +$10,000!]"
    bLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    bLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    bLbl.TextStrokeTransparency = 0.1
    bLbl.TextScaled = true
    bLbl.Font = Enum.Font.FredokaOne
    bLbl.Parent = bGui

    -- Оповещаем всех клиентов
    airDropEvent:FireAllClients("spawn", { pos = Vector3.new(landX, landY, landZ), reward = AIRDROP_REWARD })
    print(string.format("[AirDropService] Gold AirDrop descending at (%.1f, %.1f)!", landX, landZ))

    -- Анимация спуска с неба (6 секунд)
    local fallTween = TweenService:Create(crate, TweenInfo.new(6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(landX, landY + 3, landZ),
    })
    local bandTween = TweenService:Create(band1, TweenInfo.new(6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(landX, landY + 3, landZ),
    })
    local chuteTween = TweenService:Create(chute, TweenInfo.new(6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(landX, landY + 13, landZ),
    })

    fallTween:Play()
    bandTween:Play()
    chuteTween:Play()

    fallTween.Completed:Connect(function()
        if chute.Parent then chute:Destroy() end

        -- Логика удержания и захвата
        local capturingPlayer: Player? = nil
        local captureSecondsLeft = 4
        local isCaptured = false
        local captureThreadActive = false -- P1-NEW-02 FIX: защита от множественных task.spawn
        local touchConnection: RBXScriptConnection? = nil

        touchConnection = crate.Touched:Connect(function(hit)
            if isCaptured then return end
            if captureThreadActive then return end -- P1-NEW-02 FIX: блокируем параллельные потоки
            local char = hit.Parent
            local p = Players:GetPlayerFromCharacter(char)
            if p and not capturingPlayer then
                capturingPlayer = p
                captureThreadActive = true
                task.spawn(function()
                    while capturingPlayer == p and captureSecondsLeft > 0 and crate.Parent do
                        bLbl.Text = string.format("⏳ ЗАХВАТ: %s (%dс)...", p.Name, captureSecondsLeft)
                        task.wait(1.0)
                        -- Проверяем жив ли и рядом ли
                        if isCaptured then return end -- P1-NEW-02: выход если кто-то уже захватил
                        local captureChar = p.Character
                        if not captureChar then
                            capturingPlayer = nil
                            captureThreadActive = false
                            break
                        end
                        local hum = captureChar:FindFirstChildOfClass("Humanoid")
                        local hrp = captureChar:FindFirstChild("HumanoidRootPart") :: BasePart?
                        if not hum or hum.Health <= 0 or not hrp then
                            capturingPlayer = nil
                            captureThreadActive = false
                            break
                        end
                        if (hrp.Position - crate.Position).Magnitude > 14 then
                            capturingPlayer = nil
                            captureThreadActive = false
                            break
                        end
                        captureSecondsLeft -= 1
                    end

                    if captureSecondsLeft <= 0 and not isCaptured then
                        isCaptured = true
                        -- P1-NEW-02 FIX: отключаем Touched после захвата
                        if touchConnection then
                            touchConnection:Disconnect()
                            touchConnection = nil
                        end
                        bLbl.Text = string.format("🎉 ЗАХВАЧЕНО: %s!", p.Name)
                        TycoonService.addCashRaw(p, AIRDROP_REWARD)

                        -- Салют и фейерверк
                        local spark = Instance.new("ParticleEmitter")
                        spark.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
                        spark.Size = NumberSequence.new(1.5)
                        spark.Speed = NumberRange.new(20, 35)
                        spark.Parent = crate
                        spark:Emit(45)

                        airDropEvent:FireAllClients("captured", { winnerName = p.Name, reward = AIRDROP_REWARD })
                        print(string.format("[AirDropService] %s captured AirDrop and won +$%d Aura!", p.Name, AIRDROP_REWARD))

                        task.wait(2)
                        if crateModel.Parent then crateModel:Destroy() end
                        currentCrate = nil
                    else
                        captureSecondsLeft = 4
                        captureThreadActive = false
                        bLbl.Text = "📦 ЗОЛОТОЙ АИРДРОП\n[Удерживай 4с для +$10,000!]"
                    end
                end)
            end
        end)
    end)
end

function AirDropService.init()
    task.spawn(function()
        -- Первый дроп через 60 секунд после старта сервера
        task.wait(60)
        spawnAirDrop()

        while true do
            task.wait(AIRDROP_INTERVAL_SEC)
            pcall(spawnAirDrop)
        end
    end)
    print("[AirDropService] Dynamic AirDrop events loop scheduled!")
end

return AirDropService
