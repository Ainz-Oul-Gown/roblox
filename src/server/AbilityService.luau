--!strict

--[=[
    AbilityService (Multi-Ability & Inventory Tools Edition)
    Управляет 3 способностями для каждой из 8 баз:
    1. Базовая способность ([E]) - выдается при покупке AbilityStand_1
    2. Тактическая способность ([R]) - выдается при покупке AbilityStand_Tactical
    3. Ультимейт 2-го этажа ([Q]) - выдается при покупке AbilityStand_Ultimate

    Способности оформлены как предметы в Backpack (хотбар 1, 2, 3):
    игрок берет предмет в руки и нажимает [E] (или кликает мышью) для применения!
    Все нанесенные повреждения помечаются тегом creator для PvP-лута!
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig", 10))
local PlotManager = require(script.Parent:WaitForChild("PlotManager", 10))
local TycoonService = require(script.Parent:WaitForChild("TycoonService", 10))

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

-- Кулдауны хранятся по ключу: userId_slot (base / tactical / ultimate)
local cooldowns: { [string]: number } = {}

-- Пометка цели тегом создателя урона для PvP-лута кошелька
local function tagHumanoid(targetHum: Humanoid, attacker: Player)
    local old = targetHum:FindFirstChild("creator")
    if old then old:Destroy() end
    local tag = Instance.new("ObjectValue")
    tag.Name = "creator"
    tag.Value = attacker
    tag.Parent = targetHum
    Debris:AddItem(tag, 6)
end

-- Создание и выдача Tool в инвентарь игрока
local function createAbilityTool(player: Player, slot: "base" | "tactical" | "ultimate", abilityInfo: TycoonConfig.AbilityInfo, factionColor: Color3)
    local toolName = string.format("[%s] %s", if slot == "base" then "1" elseif slot == "tactical" then "2" else "3", abilityInfo.name)

    -- Удаляем старый такой же тул если есть
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local old = backpack:FindFirstChild(toolName)
        if old then old:Destroy() end
    end
    local starterGear = player:FindFirstChild("StarterGear")
    if starterGear then
        local old = starterGear:FindFirstChild(toolName)
        if old then old:Destroy() end
    end

    local tool = Instance.new("Tool")
    tool.Name = toolName
    tool.RequiresHandle = false
    tool.ToolTip = string.format("%s (Нажми E для активации)", abilityInfo.desc)
    tool:SetAttribute("AbilitySlot", slot)
    tool:SetAttribute("Cooldown", abilityInfo.cooldown)

    tool.Activated:Connect(function()
        AbilityService.castAbility(player, slot)
    end)

    if backpack then
        tool:Clone().Parent = backpack
    end
    if starterGear then
        tool.Parent = starterGear
    end
end

-- Проверка и выдача доступных способностей игроку
function AbilityService.syncPlayerTools(player: Player)
    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then return end

    local faction = TycoonConfig.getFaction(plotIndex)
    local owned = TycoonService.getOwnedItems(player)

    -- 1. Базовая способность
    if owned["AbilityStand_1"] then
        createAbilityTool(player, "base", faction.baseAbility, faction.color)
    end

    -- 2. Тактическая способность
    if owned["AbilityStand_Tactical"] then
        createAbilityTool(player, "tactical", faction.tacticalAbility, faction.secondaryColor)
    end

    -- 3. Ультимативная способность
    if owned["AbilityStand_Ultimate"] then
        createAbilityTool(player, "ultimate", faction.ultimateAbility, faction.color)
    end
end

-- Вызов способности
function AbilityService.castAbility(player: Player, slot: "base" | "tactical" | "ultimate")
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum = char:FindFirstChild("Humanoid") :: Humanoid?
    if not root or not hum or hum.Health <= 0 then return end

    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then
        abilityEvent:FireClient(player, "ERROR", "Сначала выбери базу!", 0, slot)
        return
    end

    local faction = TycoonConfig.getFaction(plotIndex)
    local abilityInfo = if slot == "base" then faction.baseAbility
        elseif slot == "tactical" then faction.tacticalAbility
        else faction.ultimateAbility

    -- Проверка наличия предмета в тайкуне
    local requiredItem = if slot == "base" then "AbilityStand_1"
        elseif slot == "tactical" then "AbilityStand_Tactical"
        else "AbilityStand_Ultimate"

    if not TycoonService.hasItem(player, requiredItem) then
        abilityEvent:FireClient(player, "ERROR", "Сначала купи стойку этой способности на базе!", 0, slot)
        return
    end

    -- Проверка кулдауна
    local cdKey = string.format("%d_%s", player.UserId, slot)
    local now = os.time()
    local lastCast = cooldowns[cdKey] or 0
    if now - lastCast < abilityInfo.cooldown then
        local rem = abilityInfo.cooldown - (now - lastCast)
        abilityEvent:FireClient(player, "COOLDOWN", "Перезарядка", rem, slot)
        return
    end
    cooldowns[cdKey] = now
    cooldowns[player.UserId] = now

    -- Запуск визуала на клиенте
    abilityEvent:FireClient(player, "CAST_SUCCESS", abilityInfo.name, abilityInfo.cooldown, slot)

    local fId = faction.id

    -- Применение эффектов в зависимости от фракции и слота:
    if fId == "Skibidi" then
        if slot == "base" then
            -- Вихрь смыва: раскидывание
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = oRoot.Position - root.Position
                        if diff.Magnitude <= 24 then
                            tagHumanoid(oHum, player)
                            oHum:TakeDamage(25)
                            oRoot.AssemblyLinearVelocity = (diff.Unit + Vector3.new(0, 0.8, 0)) * 60
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- Скибиди Броня: ускорение и щит
            hum.WalkSpeed = 26
            task.delay(6, function()
                if hum.Parent then hum.WalkSpeed = 16 end
            end)
        else
            -- Мега-Смыв 3000: притягивание врагов
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = root.Position - oRoot.Position
                        if diff.Magnitude <= 35 then
                            tagHumanoid(oHum, player)
                            oHum:TakeDamage(60)
                            oRoot.AssemblyLinearVelocity = (diff.Unit + Vector3.new(0, 0.5, 0)) * 50
                        end
                    end
                end
            end
        end

    elseif fId == "Mewing" then
        if slot == "base" then
            -- Челюстной стан
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local toOther = (oRoot.Position - root.Position)
                        if toOther.Magnitude <= 22 and root.CFrame.LookVector:Dot(toOther.Unit) > 0.3 then
                            tagHumanoid(oHum, player)
                            oHum:TakeDamage(20)
                            local prevSpeed = oHum.WalkSpeed
                            oHum.WalkSpeed = 0
                            task.delay(3, function() if oHum.Parent then oHum.WalkSpeed = prevSpeed end end)
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            hum.MaxHealth = hum.MaxHealth + 30
            hum.Health = math.min(hum.MaxHealth, hum.Health + 30)
        else
            -- Bye Bye Shockwave
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(65)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 45, 0)
                    end
                end
            end
        end

    elseif fId == "Sigma" then
        if slot == "base" then
            hum.WalkSpeed = 32
            task.delay(6, function() if hum.Parent then hum.WalkSpeed = 16 end end)
        elseif slot == "tactical" then
            -- Парирование: следующий удар отразится
            player:SetAttribute("SigmaParryActive", true)
            task.delay(4, function() player:SetAttribute("SigmaParryActive", false) end)
        else
            -- Сигма Доминация
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 28 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(55)
                        oHum.WalkSpeed = 6
                        task.delay(5, function() if oHum.Parent then oHum.WalkSpeed = 16 end end)
                    end
                end
            end
        end

    elseif fId == "FanumTax" then
        if slot == "base" then
            -- Налог 15%
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 20 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(20)
                        local victimCash = TycoonService.getCash(other)
                        local tax = math.floor(victimCash * 0.15)
                        if tax > 0 then
                            TycoonService.addCash(other, -tax)
                            TycoonService.addCash(player, tax)
                        end
                        break
                    end
                end
            end
        elseif slot == "tactical" then
            -- Ловушка
            local puddle = Instance.new("Part")
            puddle.Size = Vector3.new(12, 0.2, 12)
            puddle.CFrame = root.CFrame * CFrame.new(0, -2.8, -4)
            puddle.Anchored = true
            puddle.Material = Enum.Material.Ice
            puddle.Color = Color3.fromRGB(230, 126, 34)
            puddle.Parent = Workspace
            Debris:AddItem(puddle, 8)
        else
            -- Великий Аудит
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(40)
                        local victimCash = TycoonService.getCash(other)
                        local tax = math.floor(victimCash * 0.30)
                        if tax > 0 then
                            TycoonService.addCash(other, -tax)
                            TycoonService.addCash(player, tax)
                        end
                    end
                end
            end
            hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
        end

    else
        -- Общий обработчик для Grimace, CaseOh, Rizzler, TungTung
        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player and other.Character then
                local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 24 then
                    tagHumanoid(oHum, player)
                    local dmg = if slot == "base" then 25 elseif slot == "tactical" then 35 else 65
                    oHum:TakeDamage(dmg)
                    oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 45
                end
            end
        end
    end

    print(string.format("[AbilityService] %s cast %s (%s)", player.Name, abilityInfo.name, slot))
end

-- Подключение удаленного вызова
abilityEvent.OnServerEvent:Connect(function(player: Player, slot: any)
    if slot == "base" or slot == "tactical" or slot == "ultimate" then
        AbilityService.castAbility(player, slot)
    else
        -- Fallback для совместимости
        AbilityService.castAbility(player, "base")
    end
end)

-- Автоматическая выдача тулов при респавне персонажа
Players.PlayerAdded:Connect(function(player: Player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        AbilityService.syncPlayerTools(player)
    end)
end)

-- Связываем покупку стойки способности в TycoonService с моментальной выдачей предмета
TycoonService.onItemPurchased = function(player: Player, itemId: string)
    if string.find(itemId, "AbilityStand") then
        AbilityService.syncPlayerTools(player)
    end
end

return AbilityService
