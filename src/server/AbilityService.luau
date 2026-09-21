--!strict

--[=[
    AbilityService (Multi-Ability & Inventory Tools Edition - 6 Slots / 48 Abilities)
    Управляет 6 тематическими способностями для каждой из 8 баз (48 способностей всего):
    1. Базовая [E] (Слот 1) - AbilityStand_1
    2. Тактическая [R] (Слот 2) - AbilityStand_Tactical
    3. Ультимейт [Q] (Слот 3) - AbilityStand_Ultimate
    4. Спец-способность [F] (Слот 4) - AbilityStand_Special
    5. Мобильность [Z] (Слот 5) - AbilityStand_Mobility
    6. Финишер Бога [X] (Слот 6) - AbilityStand_Godmode

    Каждая способность выдается как предмет в Backpack (хотбар 1..6):
    игрок берет предмет в руки и нажимает [E] / кликает мышью (или жмет горячую клавишу) для применения!
    Все нанесенные повреждения помечаются тегом creator для 100% PvP-лута!
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

export type AbilitySlot = "base" | "tactical" | "ultimate" | "special" | "mobility" | "godmode"

local function getOrCreateRemote(name: string): RemoteEvent
    local existing = ReplicatedStorage:FindFirstChild(name) :: RemoteEvent?
    if existing then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = ReplicatedStorage
    return remote
end

local abilityEvent = getOrCreateRemote("AbilityEvent")
local abilityVFXEvent = getOrCreateRemote("AbilityVFXEvent")

-- Кулдауны хранятся по ключу: userId_slot
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
local function createAbilityTool(player: Player, slot: AbilitySlot, abilityInfo: TycoonConfig.AbilityInfo, factionColor: Color3)
    local slotNum = if slot == "base" then "1"
        elseif slot == "tactical" then "2"
        elseif slot == "ultimate" then "3"
        elseif slot == "special" then "4"
        elseif slot == "mobility" then "5"
        else "6"

    local toolName = string.format("[%s] %s", slotNum, abilityInfo.name)

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

    local function makeTool(): Tool
        local t = Instance.new("Tool")
        t.Name = toolName
        t.RequiresHandle = false
        t.CanBeDropped = false
        t.ToolTip = string.format("%s (Нажми [E] или кликни мышью для активации)", abilityInfo.desc)
        t:SetAttribute("AbilitySlot", slot)
        t:SetAttribute("Cooldown", abilityInfo.cooldown)
        t.Activated:Connect(function()
            AbilityService.castAbility(player, slot)
        end)
        return t
    end

    if backpack then
        makeTool().Parent = backpack
    end
    if starterGear then
        makeTool().Parent = starterGear
    end
end

-- Проверка и выдача доступных способностей игроку
function AbilityService.syncPlayerTools(player: Player)
    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then return end

    local faction = TycoonConfig.getFaction(plotIndex)
    local owned = TycoonService.getOwnedItems(player)

    -- 1. Базовая способность [1]
    if owned["AbilityStand_1"] then
        createAbilityTool(player, "base", faction.baseAbility, faction.color)
    end

    -- 2. Тактическая способность [2]
    if owned["AbilityStand_Tactical"] then
        createAbilityTool(player, "tactical", faction.tacticalAbility, faction.secondaryColor)
    end

    -- 3. Ультимативная способность [3]
    if owned["AbilityStand_Ultimate"] then
        createAbilityTool(player, "ultimate", faction.ultimateAbility, faction.color)
    end

    -- 4. Спец-способность [4]
    if owned["AbilityStand_Special"] then
        createAbilityTool(player, "special", faction.specialAbility, Color3.fromRGB(168, 85, 247))
    end

    -- 5. Мобильность [5]
    if owned["AbilityStand_Mobility"] then
        createAbilityTool(player, "mobility", faction.mobilityAbility, Color3.fromRGB(6, 182, 212))
    end

    -- 6. Финишер Бога [6]
    if owned["AbilityStand_Godmode"] then
        createAbilityTool(player, "godmode", faction.godmodeAbility, Color3.fromRGB(239, 68, 68))
    end
end

-- Вызов способности
function AbilityService.castAbility(player: Player, slot: AbilitySlot)
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
        elseif slot == "ultimate" then faction.ultimateAbility
        elseif slot == "special" then faction.specialAbility
        elseif slot == "mobility" then faction.mobilityAbility
        else faction.godmodeAbility

    -- Проверка наличия предмета в тайкуне
    local requiredItem = if slot == "base" then "AbilityStand_1"
        elseif slot == "tactical" then "AbilityStand_Tactical"
        elseif slot == "ultimate" then "AbilityStand_Ultimate"
        elseif slot == "special" then "AbilityStand_Special"
        elseif slot == "mobility" then "AbilityStand_Mobility"
        else "AbilityStand_Godmode"

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

    local fId = faction.id

    -- Запуск визуала на клиенте
    abilityEvent:FireClient(player, "CAST_SUCCESS", abilityInfo.name, abilityInfo.cooldown, slot)
    abilityVFXEvent:FireAllClients(player, fId, slot, root.Position, root.CFrame.LookVector)

    -- Применение эффектов в зависимости от фракции и слота:
    if fId == "Skibidi" then
        if slot == "base" then
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
            hum.WalkSpeed = 26
            task.delay(6, function() if hum.Parent then hum.WalkSpeed = 16 end end)
        elseif slot == "ultimate" then
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
        elseif slot == "special" then
            -- Skibidi Dop Dop Anthem: оглушение + аура
            TycoonService.addCash(player, 2500)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 25 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(20)
                        local prevSpeed = oHum.WalkSpeed
                        oHum.WalkSpeed = 0
                        task.delay(2.5, function() if oHum.Parent then oHum.WalkSpeed = prevSpeed end end)
                    end
                end
            end
        elseif slot == "mobility" then
            -- Скибиди Ракета: реактивный рывок
            local look = root.CFrame.LookVector
            root.AssemblyLinearVelocity = look * 95 + Vector3.new(0, 25, 0)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 14 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(35)
                        oRoot.AssemblyLinearVelocity = (look + Vector3.new(0, 0.5, 0)) * 55
                    end
                end
            end
        else
            -- Титан Скибиди: колоссальный сплэш
            hum.WalkSpeed = 28
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(80)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 60, 0)
                    end
                end
            end
            task.delay(8, function() if hum.Parent then hum.WalkSpeed = 16 end end)
        end

    elseif fId == "Mewing" then
        if slot == "base" then
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
        elseif slot == "ultimate" then
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
        elseif slot == "special" then
            -- Looksmaxing Flash
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 28 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(25)
                        oHum.WalkSpeed = 4
                        task.delay(4, function() if oHum.Parent then oHum.WalkSpeed = 16 end end)
                    end
                end
            end
        elseif slot == "mobility" then
            -- Гигачад Рывок
            local look = root.CFrame.LookVector
            root.AssemblyLinearVelocity = look * 85 + Vector3.new(0, 15, 0)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 15 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(40)
                        oRoot.AssemblyLinearVelocity = (look + Vector3.new(0, 0.4, 0)) * 60
                    end
                end
            end
        else
            -- Альфа Доминация: 100% отхил и нокдаун
            hum.Health = hum.MaxHealth
            hum.WalkSpeed = 24
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 30 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(50)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, -30, 0)
                    end
                end
            end
            task.delay(7, function() if hum.Parent then hum.WalkSpeed = 16 end end)
        end

    elseif fId == "Sigma" then
        if slot == "base" then
            hum.WalkSpeed = 32
            task.delay(6, function() if hum.Parent then hum.WalkSpeed = 16 end end)
        elseif slot == "tactical" then
            player:SetAttribute("SigmaParryActive", true)
            task.delay(4, function() player:SetAttribute("SigmaParryActive", false) end)
        elseif slot == "ultimate" then
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
        elseif slot == "special" then
            -- Lone Wolf Grindset: невидимость + крит
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    p.Transparency = 0.9
                end
            end
            player:SetAttribute("SigmaCritActive", true)
            task.delay(5, function()
                player:SetAttribute("SigmaCritActive", false)
                if char.Parent then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                            p.Transparency = 0
                        end
                    end
                end
            end)
        elseif slot == "mobility" then
            -- Теневой Шаг: телепорт за спину врага
            local nearestTarget: Player? = nil
            local minDist = 45
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if oRoot then
                        local d = (oRoot.Position - root.Position).Magnitude
                        if d < minDist then
                            minDist = d
                            nearestTarget = other
                        end
                    end
                end
            end
            if nearestTarget and nearestTarget.Character then
                local tRoot = nearestTarget.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local tHum = nearestTarget.Character:FindFirstChild("Humanoid") :: Humanoid?
                if tRoot and tHum then
                    root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 4)
                    tagHumanoid(tHum, player)
                    tHum:TakeDamage(45)
                end
            else
                root.CFrame = root.CFrame * CFrame.new(0, 0, -30)
            end
        else
            -- Brazilian Phonk Overload
            hum.WalkSpeed = 36
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(70)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 40, 0)
                    end
                end
            end
            task.delay(8, function() if hum.Parent then hum.WalkSpeed = 16 end end)
        end

    elseif fId == "FanumTax" then
        if slot == "base" then
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
                            local stolen = TycoonService.deductCash(other, tax)
                            if stolen > 0 then
                                TycoonService.addCash(player, stolen)
                            end
                        end
                        break
                    end
                end
            end
        elseif slot == "tactical" then
            local puddle = Instance.new("Part")
            puddle.Size = Vector3.new(12, 0.2, 12)
            puddle.CFrame = root.CFrame * CFrame.new(0, -2.8, -4)
            puddle.Anchored = true
            puddle.Material = Enum.Material.Ice
            puddle.Color = Color3.fromRGB(230, 126, 34)
            puddle.Parent = Workspace
            Debris:AddItem(puddle, 8)
        elseif slot == "ultimate" then
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
                            local stolen = TycoonService.deductCash(other, tax)
                            if stolen > 0 then
                                TycoonService.addCash(player, stolen)
                            end
                        end
                    end
                end
            end
            hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
        elseif slot == "special" then
            -- Fries Carpet Bomb
            local look = root.CFrame.LookVector
            for i = 1, 3 do
                task.delay(i * 0.2, function()
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= player and other.Character then
                            local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                            local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                            if oRoot and oHum and (oRoot.Position - (root.Position + look * (i * 12))).Magnitude <= 14 then
                                tagHumanoid(oHum, player)
                                oHum:TakeDamage(18)
                                oHum.WalkSpeed = 6
                                task.delay(3, function() if oHum.Parent then oHum.WalkSpeed = 16 end end)
                            end
                        end
                    end
                end)
            end
        elseif slot == "mobility" then
            -- Cola Rocket Jump
            root.AssemblyLinearVelocity = Vector3.new(0, 90, 0) + root.CFrame.LookVector * 45
        else
            -- Пицца-Метеорит
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 35 then
                        tagHumanoid(oHum, player)
                        oHum:TakeDamage(75)
                        oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 60
                    end
                end
            end
            hum.Health = hum.MaxHealth
        end

    else
        -- Grimace, CaseOh, Rizzler, TungTung
        local baseDmg = if slot == "base" then 25
            elseif slot == "tactical" then 35
            elseif slot == "ultimate" then 65
            elseif slot == "special" then 50
            elseif slot == "mobility" then 35
            else 85

        if slot == "mobility" then
            -- Универсальный рывок / прыжок вперед
            root.AssemblyLinearVelocity = root.CFrame.LookVector * 80 + Vector3.new(0, 30, 0)
        end

        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player and other.Character then
                local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 26 then
                    tagHumanoid(oHum, player)
                    oHum:TakeDamage(baseDmg)
                    oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 45
                end
            end
        end
    end

    print(string.format("[AbilityService] %s cast %s (%s)", player.Name, abilityInfo.name, slot))
end

-- Подключение удаленного вызова
abilityEvent.OnServerEvent:Connect(function(player: Player, slot: any)
    if slot == "base" or slot == "tactical" or slot == "ultimate" or slot == "special" or slot == "mobility" or slot == "godmode" then
        AbilityService.castAbility(player, slot)
    else
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

-- Очистка кэша кулдаунов при выходе игрока
function AbilityService.removePlayer(player: Player)
    local prefix = string.format("%d_", player.UserId)
    for key in pairs(cooldowns) do
        if string.sub(key, 1, #prefix) == prefix then
            cooldowns[key] = nil
        end
    end
end

Players.PlayerRemoving:Connect(function(player: Player)
    AbilityService.removePlayer(player)
end)

return AbilityService
