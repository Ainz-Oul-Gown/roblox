--!strict

--[=[
    AbilityService
    Серверная обработка 8 уникальных способностей фракций:
    кулдауны, проверка владения стойкой способности и боевые эффекты.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
local PlotManager = require(script.Parent:WaitForChild("PlotManager"))
local TycoonService = require(script.Parent:WaitForChild("TycoonService"))

local AbilityService = {}

-- Создание RemoteEvent для взаимодействия с клиентом
local abilityEvent = ReplicatedStorage:FindFirstChild("AbilityEvent") :: RemoteEvent?
if not abilityEvent then
    local newEvent = Instance.new("RemoteEvent")
    newEvent.Name = "AbilityEvent"
    newEvent.Parent = ReplicatedStorage
    abilityEvent = newEvent
end

local cooldowns: { [number]: number } = {}
local COOLDOWN_DURATION = 12 -- 12 секунд между применениями

local function handleAbility(player: Player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char:FindFirstChild("Humanoid") :: Humanoid?
    if not root or not hum or hum.Health <= 0 then return end

    -- Проверка покупки стойки способности
    if not TycoonService.hasItem(player, "FactionAbilityStand") then
        warn(string.format("[AbilityService] %s hasn't unlocked FactionAbilityStand yet", player.Name))
        return
    end

    -- Проверка кулдауна
    local now = os.time()
    local lastCast = cooldowns[player.UserId] or 0
    if now - lastCast < COOLDOWN_DURATION then
        return
    end
    cooldowns[player.UserId] = now

    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then return end
    local faction = TycoonConfig.getFaction(plotIndex)

    print(string.format("[AbilityService] %s activated %s (%s)", player.Name, faction.abilityName, faction.id))

    if faction.id == "Skibidi" then
        -- Вихрь смыва: мощный крутящий импульс и отталкивание всех врагов
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if eRoot and (eRoot.Position - root.Position).Magnitude <= 24 then
                    local dir = (eRoot.Position - root.Position).Unit
                    eRoot.AssemblyLinearVelocity = (dir + Vector3.new(0, 0.6, 0)) * 65
                end
            end
        end

    elseif faction.id == "Mewing" then
        -- Мьюинг стан: замораживает всех врагов в конусе перед собой на 3 сек
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local eHum = enemy.Character:FindFirstChild("Humanoid") :: Humanoid?
                if eRoot and eHum and (eRoot.Position - root.Position).Magnitude <= 22 then
                    eHum.WalkSpeed = 0
                    task.delay(3, function()
                        if eHum then eHum.WalkSpeed = 16 end
                    end)
                end
            end
        end

    elseif faction.id == "Sigma" then
        -- Фонк-ярость: двойная скорость + силовое поле на 5 сек
        local prevSpeed = hum.WalkSpeed
        hum.WalkSpeed = 34
        local ff = Instance.new("ForceField")
        ff.Parent = char
        Debris:AddItem(ff, 5)
        task.delay(5, function()
            if hum then hum.WalkSpeed = prevSpeed end
        end)

    elseif faction.id == "FanumTax" then
        -- Фанум-налог: ворует 10% Ауры у ближайшего игрока
        local closestEnemy: Player? = nil
        local closestDist = 30

        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if eRoot then
                    local dist = (eRoot.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestEnemy = enemy
                    end
                end
            end
        end

        if closestEnemy then
            local enemyCash = TycoonService.getCash(closestEnemy)
            local stolen = math.floor(enemyCash * 0.1)
            if stolen > 0 then
                TycoonService.addCash(player, stolen)
                print(string.format("[FanumTax] %s taxed %d Aura from %s!", player.Name, stolen, closestEnemy.Name))
            end
        end

    elseif faction.id == "Grimace" then
        -- Токсичное облако: ядовитая зона вокруг
        local cloud = Instance.new("Part")
        cloud.Name = "GrimaceCloud"
        cloud.Shape = Enum.PartType.Ball
        cloud.Size = Vector3.new(20, 20, 20)
        cloud.Position = root.Position
        cloud.Anchored = true
        cloud.CanCollide = false
        cloud.Material = Enum.Material.ForceField
        cloud.Color = Color3.fromRGB(155, 89, 182)
        cloud.Transparency = 0.6
        cloud.Parent = workspace
        Debris:AddItem(cloud, 4)

        cloud.Touched:Connect(function(hit)
            local enemyChar = hit.Parent
            local enemyPlayer = Players:GetPlayerFromCharacter(enemyChar)
            if enemyPlayer and enemyPlayer ~= player then
                local eHum = enemyChar:FindFirstChild("Humanoid") :: Humanoid?
                if eHum then eHum:TakeDamage(15) end
            end
        end)

    elseif faction.id == "CaseOh" then
        -- Гравитационный слэм
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local eHum = enemy.Character:FindFirstChild("Humanoid") :: Humanoid?
                if eRoot and eHum and (eRoot.Position - root.Position).Magnitude <= 26 then
                    eRoot.AssemblyLinearVelocity = Vector3.new(0, 45, 0)
                    eHum:TakeDamage(20)
                end
            end
        end

    elseif faction.id == "Rizzler" then
        -- Несказанный Ризз: замедление врагов
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local eHum = enemy.Character:FindFirstChild("Humanoid") :: Humanoid?
                if eRoot and eHum and (eRoot.Position - root.Position).Magnitude <= 24 then
                    eHum.WalkSpeed = 6
                    task.delay(4, function()
                        if eHum then eHum.WalkSpeed = 16 end
                    end)
                end
            end
        end

    elseif faction.id == "TungTung" then
        -- Молот Тунг-Тунг: взлет врагов вверх на 60 studs
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if eRoot and (eRoot.Position - root.Position).Magnitude <= 20 then
                    eRoot.AssemblyLinearVelocity = Vector3.new(0, 75, 0)
                end
            end
        end
    end
end

if abilityEvent then
    abilityEvent.OnServerEvent:Connect(handleAbility)
end

return AbilityService
