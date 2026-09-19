--!strict

--[=[
    AbilityService
    Обрабатывает применение 8 суперспособностей фракций:
    дает визуальные/звуковые эффекты на самого игрока (даже при соло-игре)
    и применяет боевые эффекты к окружающим врагам.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
local PlotManager = require(script.Parent:WaitForChild("PlotManager"))
local TycoonService = require(script.Parent:WaitForChild("TycoonService"))

local AbilityService = {}

local function getOrCreateRemote(name: string): RemoteEvent
    local existing = ReplicatedStorage:FindFirstChild(name) :: RemoteEvent?
    if existing then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = ReplicatedStorage
    return remote
end

local abilityEvent = getOrCreateRemote("AbilityEvent")

local cooldowns: { [number]: number } = {}

local function handleAbility(player: Player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char:FindFirstChild("Humanoid") :: Humanoid?
    if not root or not hum or hum.Health <= 0 then return end

    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then
        warn("[AbilityService] Player has no base claimed yet!")
        abilityEvent:FireClient(player, "ERROR", "Сначала выбери базу в меню!", 0, "")
        return
    end

    local hasUpgradeStand = TycoonService.hasItem(player, "FactionAbilityStand")
    local cooldownDuration = if hasUpgradeStand then 6 else 12

    local now = os.time()
    local lastCast = cooldowns[player.UserId] or 0
    if now - lastCast < cooldownDuration then
        local rem = cooldownDuration - (now - lastCast)
        warn(string.format("[AbilityService] %s ability on cooldown (%ds remaining)", player.Name, rem))
        abilityEvent:FireClient(player, "COOLDOWN", "Способность перезаряжается", rem, "")
        return
    end
    cooldowns[player.UserId] = now

    local faction = TycoonConfig.getFaction(plotIndex)

    -- Звук активации
    local sfx = Instance.new("Sound")
    sfx.SoundId = "rbxassetid://138090596"
    sfx.Volume = 0.8
    sfx.Parent = root
    sfx:Play()
    Debris:AddItem(sfx, 3)

    -- Вспышка частиц вокруг игрока
    local burst = Instance.new("ParticleEmitter")
    burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    burst.Rate = 0
    burst.Speed = NumberRange.new(10, 20)
    burst.Lifetime = NumberRange.new(0.6, 1.2)
    burst.Color = ColorSequence.new(faction.color)
    burst.Parent = root
    burst:Emit(25)
    Debris:AddItem(burst, 2)

    -- Оповещаем клиента о кулдауне и запуске
    abilityEvent:FireClient(player, "SUCCESS", faction.abilityName, cooldownDuration, faction.id)
    print(string.format("[AbilityService] %s cast %s (%s)!", player.Name, faction.abilityName, faction.id))

    -- Логика фракций
    if faction.id == "Skibidi" then
        -- Вихрь смыва: вращение самого игрока + раскидывание всех рядом
        local bav = Instance.new("BodyAngularVelocity")
        bav.MaxTorque = Vector3.new(0, 1000000, 0)
        bav.AngularVelocity = Vector3.new(0, 35, 0)
        bav.Parent = root
        Debris:AddItem(bav, 1.5)

        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if eRoot and (eRoot.Position - root.Position).Magnitude <= 26 then
                    local dir = (eRoot.Position - root.Position).Unit
                    eRoot.AssemblyLinearVelocity = (dir + Vector3.new(0, 0.7, 0)) * 75
                end
            end
        end

    elseif faction.id == "Mewing" then
        -- Мьюинг: неуязвимость + стан врагов перед собой
        local prevSpeed = hum.WalkSpeed
        hum.WalkSpeed = 24
        task.delay(3, function() if hum then hum.WalkSpeed = prevSpeed end end)

        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local eHum = enemy.Character:FindFirstChild("Humanoid") :: Humanoid?
                if eRoot and eHum and (eRoot.Position - root.Position).Magnitude <= 25 then
                    eHum.WalkSpeed = 0
                    task.delay(3, function() if eHum then eHum.WalkSpeed = 16 end end)
                end
            end
        end

    elseif faction.id == "Sigma" then
        -- Фонк-ярость: резкое ускорение до 38 + щит
        local prevSpeed = hum.WalkSpeed
        hum.WalkSpeed = 38
        local ff = Instance.new("ForceField")
        ff.Parent = char
        Debris:AddItem(ff, 5)
        task.delay(5, function() if hum then hum.WalkSpeed = prevSpeed end end)

    elseif faction.id == "FanumTax" then
        -- Налог Фанума: если есть соперники - крадет Аура, если соло - начисляет бонус +50 Ауры!
        local enemyFound = false
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if eRoot and (eRoot.Position - root.Position).Magnitude <= 35 then
                    local enemyCash = TycoonService.getCash(enemy)
                    local stolen = math.floor(enemyCash * 0.1)
                    if stolen > 0 then
                        TycoonService.addCash(player, stolen)
                        enemyFound = true
                        break
                    end
                end
            end
        end
        if not enemyFound then
            TycoonService.addCash(player, 50) -- Соло-бонус налога
        end

    elseif faction.id == "Grimace" then
        -- Ядовитое облако под ногами
        local cloud = Instance.new("Part")
        cloud.Name = "GrimaceCloud"
        cloud.Shape = Enum.PartType.Ball
        cloud.Size = Vector3.new(24, 24, 24)
        cloud.Position = root.Position
        cloud.Anchored = true
        cloud.CanCollide = false
        cloud.Material = Enum.Material.ForceField
        cloud.Color = Color3.fromRGB(155, 89, 182)
        cloud.Transparency = 0.5
        cloud.Parent = Workspace
        Debris:AddItem(cloud, 4)

        cloud.Touched:Connect(function(hit)
            local enemyChar = hit.Parent
            local enemyPlayer = Players:GetPlayerFromCharacter(enemyChar)
            if enemyPlayer and enemyPlayer ~= player then
                local eHum = enemyChar:FindFirstChild("Humanoid") :: Humanoid?
                if eHum then eHum:TakeDamage(25) end
            end
        end)

    elseif faction.id == "CaseOh" then
        -- Гравитационный слэм: прыжок вверх и сокрушительный удар о землю
        root.AssemblyLinearVelocity = Vector3.new(0, 35, 0)
        task.wait(0.5)
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local eHum = enemy.Character:FindFirstChild("Humanoid") :: Humanoid?
                if eRoot and eHum and (eRoot.Position - root.Position).Magnitude <= 30 then
                    eRoot.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
                    eHum:TakeDamage(30)
                end
            end
        end

    elseif faction.id == "Rizzler" then
        -- Ризз-ослепление: ускорение себя + замедление врагов
        hum.WalkSpeed = 26
        task.delay(4, function() if hum then hum.WalkSpeed = 16 end end)

        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eHum = enemy.Character:FindFirstChild("Humanoid") :: Humanoid?
                if eHum then
                    eHum.WalkSpeed = 6
                    task.delay(4, function() if eHum then eHum.WalkSpeed = 16 end end)
                end
            end
        end

    elseif faction.id == "TungTung" then
        -- Молот Тунг-Тунг: рокет-джамп для игрока и взлет врагов
        root.AssemblyLinearVelocity = Vector3.new(0, 75, 0)
        for _, enemy in ipairs(Players:GetPlayers()) do
            if enemy ~= player and enemy.Character then
                local eRoot = enemy.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if eRoot and (eRoot.Position - root.Position).Magnitude <= 22 then
                    eRoot.AssemblyLinearVelocity = Vector3.new(0, 80, 0)
                end
            end
        end
    end
end

abilityEvent.OnServerEvent:Connect(handleAbility)

return AbilityService
