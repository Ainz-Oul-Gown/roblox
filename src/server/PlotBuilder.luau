--!strict

--[=[
    PlotBuilder (Gen Alpha 8-Base Multiplayer Edition)
    Процедурно строит 8 уникальных круговых баз с лазерными воротами безопасности,
    персонализированными фракционными дропперами, Rebirth 1-5 разблокировками и эффектами.
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
local EconomyManager = require(Shared:WaitForChild("EconomyManager"))
local TycoonService = require(script.Parent:WaitForChild("TycoonService"))
local PlotManager = require(script.Parent:WaitForChild("PlotManager"))

local PlotBuilder = {}

-- Создание информационного BillboardGui над деталью
local function createBillboard(parent: Instance, title: string, subtitle: string, textColor: Color3)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "InfoGui"
    billboard.Size = UDim2.new(0, 220, 0, 65)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 100
    billboard.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s\n%s", title, subtitle)
    label.TextColor3 = textColor
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Parent = billboard
    return label
end

-- Спавн купленной структуры в локальных координатах базы
local function spawnStructure(plotModel: Model, owner: Player, item: TycoonConfig.TycoonItem, baseCF: CFrame, faction: TycoonConfig.Faction)
    local itemsFolder = plotModel:FindFirstChild("PurchasedItems") :: Folder
    if not itemsFolder then return end

    if item.id == "FactionDropper" then
        -- Фирменный дроппер фракции
        local dropper = Instance.new("Part")
        dropper.Name = "FactionDropper"
        dropper.Size = Vector3.new(3, 2, 3)
        dropper.CFrame = baseCF * CFrame.new(0, 8, -8)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = faction.color
        dropper.Parent = itemsFolder

        createBillboard(dropper, faction.dropperItemName, "+1 Aura / 1.8c", faction.color)

        task.spawn(function()
            while dropper.Parent and owner.Parent do
                task.wait(1.8)
                local ore = Instance.new("Part")
                ore.Name = "Ore"
                ore.Size = Vector3.new(1.2, 1.2, 1.2)
                ore.Position = dropper.Position - Vector3.new(0, 1.5, 0)
                ore.Material = Enum.Material.Neon
                ore.Color = faction.oreColor
                ore:SetAttribute("Value", 1)
                ore.Parent = Workspace
                task.delay(15, function() if ore.Parent then ore:Destroy() end end)
            end
        end)

    elseif item.id == "LaserGate" then
        -- Лазерные ворота безопасности (сжигают чужаков)
        local gateModel = Instance.new("Model")
        gateModel.Name = "LaserGate"
        gateModel.Parent = itemsFolder

        local postLeft = Instance.new("Part")
        postLeft.Size = Vector3.new(1, 8, 1)
        postLeft.CFrame = baseCF * CFrame.new(-6, 4, 18)
        postLeft.Anchored = true
        postLeft.Color = Color3.fromRGB(30, 30, 30)
        postLeft.Parent = gateModel

        local postRight = Instance.new("Part")
        postRight.Size = Vector3.new(1, 8, 1)
        postRight.CFrame = baseCF * CFrame.new(6, 4, 18)
        postRight.Anchored = true
        postRight.Color = Color3.fromRGB(30, 30, 30)
        postRight.Parent = gateModel

        local beam = Instance.new("Part")
        beam.Name = "LaserBeam"
        beam.Size = Vector3.new(11, 7, 0.4)
        beam.CFrame = baseCF * CFrame.new(0, 4, 18)
        beam.Anchored = true
        beam.CanCollide = false
        beam.Material = Enum.Material.ForceField
        beam.Color = Color3.fromRGB(231, 76, 60)
        beam.Transparency = 0.4
        beam.Parent = gateModel

        createBillboard(beam, "⚡ ЗАЩИТНЫЙ ЛАЗЕР", "Чужим вход воспрещен!", Color3.fromRGB(231, 76, 60))

        beam.Touched:Connect(function(hit)
            local char = hit.Parent
            local p = Players:GetPlayerFromCharacter(char)
            if p and p ~= owner then
                local hum = char:FindFirstChild("Humanoid") :: Humanoid?
                if hum then
                    hum:TakeDamage(100) -- Испепеляет воров
                end
            end
        end)

    elseif item.id == "BrainrotWalls" then
        local wLeft = Instance.new("Part")
        wLeft.Size = Vector3.new(1, 10, 40)
        wLeft.CFrame = baseCF * CFrame.new(-16, 5, 0)
        wLeft.Anchored = true
        wLeft.Material = Enum.Material.SmoothPlastic
        wLeft.Color = faction.secondaryColor
        wLeft.Parent = itemsFolder

        local wRight = Instance.new("Part")
        wRight.Size = Vector3.new(1, 10, 40)
        wRight.CFrame = baseCF * CFrame.new(16, 5, 0)
        wRight.Anchored = true
        wRight.Material = Enum.Material.SmoothPlastic
        wRight.Color = faction.secondaryColor
        wRight.Parent = itemsFolder

        local wBack = Instance.new("Part")
        wBack.Size = Vector3.new(32, 10, 1)
        wBack.CFrame = baseCF * CFrame.new(0, 5, -20)
        wBack.Anchored = true
        wBack.Material = Enum.Material.SmoothPlastic
        wBack.Color = faction.secondaryColor
        wBack.Parent = itemsFolder

    elseif item.id == "FactionAbilityStand" then
        -- Стойка суперспособности
        local stand = Instance.new("Part")
        stand.Name = "AbilityStand"
        stand.Size = Vector3.new(4, 1, 4)
        stand.CFrame = baseCF * CFrame.new(10, 0.6, -10)
        stand.Anchored = true
        stand.Material = Enum.Material.Neon
        stand.Color = faction.color
        stand.Parent = itemsFolder

        createBillboard(stand, string.format("⚡ %s", faction.abilityName), faction.abilityDesc, faction.color)

    elseif item.id == "UpgradedDropper" then
        local dropper = Instance.new("Part")
        dropper.Name = "UpgradedDropper"
        dropper.Size = Vector3.new(3, 2, 3)
        dropper.CFrame = baseCF * CFrame.new(0, 8, -2)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = Color3.fromRGB(46, 204, 113)
        dropper.Parent = itemsFolder

        createBillboard(dropper, "Дроппер Prime Energy", "+8 Aura / 1.4c", Color3.fromRGB(46, 204, 113))

        task.spawn(function()
            while dropper.Parent and owner.Parent do
                task.wait(1.4)
                local ore = Instance.new("Part")
                ore.Name = "Ore"
                ore.Size = Vector3.new(1.3, 1.3, 1.3)
                ore.Position = dropper.Position - Vector3.new(0, 1.5, 0)
                ore.Material = Enum.Material.Neon
                ore.Color = Color3.fromRGB(46, 204, 113)
                ore:SetAttribute("Value", 8)
                ore.Parent = Workspace
                task.delay(15, function() if ore.Parent then ore:Destroy() end end)
            end
        end)

    elseif item.id == "NeonRoof" then
        local roof = Instance.new("Part")
        roof.Name = "NeonRoof"
        roof.Size = Vector3.new(34, 1, 42)
        roof.CFrame = baseCF * CFrame.new(0, 10.5, 0)
        roof.Anchored = true
        roof.Material = Enum.Material.Glass
        roof.Transparency = 0.3
        roof.Color = faction.color
        roof.Parent = itemsFolder

    elseif item.id == "GoldDropper" then
        local dropper = Instance.new("Part")
        dropper.Name = "GoldDropper"
        dropper.Size = Vector3.new(3, 2, 3)
        dropper.CFrame = baseCF * CFrame.new(0, 8, 4)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = Color3.fromRGB(241, 196, 15)
        dropper.Parent = itemsFolder

        createBillboard(dropper, "Золотой Дроппер Ризза", "+35 Aura / 1.0c", Color3.fromRGB(241, 196, 15))

        task.spawn(function()
            while dropper.Parent and owner.Parent do
                task.wait(1.0)
                local ore = Instance.new("Part")
                ore.Name = "Ore"
                ore.Size = Vector3.new(1.4, 1.4, 1.4)
                ore.Position = dropper.Position - Vector3.new(0, 1.5, 0)
                ore.Material = Enum.Material.Neon
                ore.Color = Color3.fromRGB(241, 196, 15)
                ore:SetAttribute("Value", 35)
                ore.Parent = Workspace
                task.delay(15, function() if ore.Parent then ore:Destroy() end end)
            end
        end)

    elseif item.id == "SecondFloor" then
        local floor2 = Instance.new("Part")
        floor2.Name = "SecondFloor"
        floor2.Size = Vector3.new(32, 1, 40)
        floor2.CFrame = baseCF * CFrame.new(0, 11, 0)
        floor2.Anchored = true
        floor2.Material = Enum.Material.SmoothPlastic
        floor2.Color = Color3.fromRGB(40, 40, 45)
        floor2.Parent = itemsFolder

        -- Трон Сигмы на 2 этаже
        local throne = Instance.new("Part")
        throne.Name = "SigmaThrone"
        throne.Size = Vector3.new(4, 4, 3)
        throne.CFrame = baseCF * CFrame.new(0, 13.5, -14)
        throne.Anchored = true
        throne.Material = Enum.Material.Neon
        throne.Color = Color3.fromRGB(241, 196, 15)
        throne.Parent = itemsFolder
        createBillboard(throne, "👑 ТРОН СИГМЫ", "+10000 RIZZ", Color3.fromRGB(241, 196, 15))
    end
end

-- Размещение интерактивных кнопок
local function updateButtons(plotModel: Model, owner: Player, baseCF: CFrame, faction: TycoonConfig.Faction)
    local buttonsFolder = plotModel:FindFirstChild("Buttons") :: Folder
    if not buttonsFolder then return end

    local localOffsets: { [string]: Vector3 } = {
        FactionDropper = Vector3.new(-10, 0.6, -10),
        LaserGate = Vector3.new(-10, 0.6, -6),
        BrainrotWalls = Vector3.new(-10, 0.6, -2),
        FactionAbilityStand = Vector3.new(-10, 0.6, 2),
        UpgradedDropper = Vector3.new(-10, 0.6, 6),
        NeonRoof = Vector3.new(-10, 0.6, 10),
        GoldDropper = Vector3.new(10, 0.6, -6),
        SecondFloor = Vector3.new(10, 0.6, -2),
    }

    for _, item in ipairs(TycoonConfig.ITEMS) do
        if TycoonService.hasItem(owner, item.id) then
            local existing = buttonsFolder:FindFirstChild("Button_" .. item.id)
            if existing then existing:Destroy() end
            continue
        end

        local isUnlocked = true
        if item.dependsOn and not TycoonService.hasItem(owner, item.dependsOn) then
            isUnlocked = false
        end

        local existing = buttonsFolder:FindFirstChild("Button_" .. item.id)

        if isUnlocked and not existing then
            local offset = localOffsets[item.id] or Vector3.new(-10, 0.6, 0)
            local stand = Instance.new("Part")
            stand.Name = "Button_" .. item.id
            stand.Size = Vector3.new(3.5, 0.4, 3.5)
            stand.CFrame = baseCF * CFrame.new(offset)
            stand.Anchored = true
            stand.Color = Color3.fromRGB(30, 30, 30)
            stand.Parent = buttonsFolder

            local pad = Instance.new("Part")
            pad.Name = "Pad"
            pad.Size = Vector3.new(2.8, 0.3, 2.8)
            pad.CFrame = stand.CFrame * CFrame.new(0, 0.3, 0)
            pad.Anchored = true
            pad.Material = Enum.Material.Neon
            pad.Color = if item.cost == 0 then Color3.fromRGB(46, 204, 113) else Color3.fromRGB(230, 126, 34)
            pad.Parent = stand

            local priceText = if item.cost == 0 then "БЕСПЛАТНО" else string.format("%d AURA", item.cost)
            createBillboard(pad, item.name, priceText, pad.Color)

            local debounce = false
            pad.Touched:Connect(function(hit)
                if debounce then return end
                local char = hit.Parent
                local p = Players:GetPlayerFromCharacter(char)
                if p and p == owner then
                    debounce = true
                    local success = TycoonService.purchaseItem(p, item.id)
                    if success then
                        stand:Destroy()
                        spawnStructure(plotModel, owner, item, baseCF, faction)
                        updateButtons(plotModel, owner, baseCF, faction)
                    else
                        task.wait(0.8)
                        debounce = false
                    end
                end
            end)
        elseif not isUnlocked and existing then
            existing:Destroy()
        end
    end

    -- Кнопка многоуровневого Rebirth (1..5)
    local currentRebirths = TycoonService.getRebirths(owner)
    local hasSecondFloor = TycoonService.hasItem(owner, "SecondFloor")
    local existingRebirth = buttonsFolder:FindFirstChild("Button_Rebirth")

    if hasSecondFloor and currentRebirths < 5 and not existingRebirth then
        local nextTier = TycoonConfig.getRebirthTier(currentRebirths + 1)
        if nextTier then
            local rStand = Instance.new("Part")
            rStand.Name = "Button_Rebirth"
            rStand.Size = Vector3.new(4.5, 0.5, 4.5)
            rStand.CFrame = baseCF * CFrame.new(10, 0.6, 6)
            rStand.Anchored = true
            rStand.Color = Color3.fromRGB(20, 20, 20)
            rStand.Parent = buttonsFolder

            local pad = Instance.new("Part")
            pad.Name = "Pad"
            pad.Size = Vector3.new(3.8, 0.4, 3.8)
            pad.CFrame = rStand.CFrame * CFrame.new(0, 0.3, 0)
            pad.Anchored = true
            pad.Material = Enum.Material.Neon
            pad.Color = Color3.fromRGB(155, 89, 182)
            pad.Parent = rStand

            createBillboard(pad, string.format("🔥 REBIRTH %d: %s", nextTier.tier, nextTier.name), string.format("%d Aura | %s", nextTier.cost, nextTier.unlockedPerk), pad.Color)

            local debounce = false
            pad.Touched:Connect(function(hit)
                if debounce then return end
                local char = hit.Parent
                local p = Players:GetPlayerFromCharacter(char)
                if p and p == owner then
                    debounce = true
                    local success = TycoonService.performRebirth(p)
                    if success then
                        local itemsFolder = plotModel:FindFirstChild("PurchasedItems")
                        if itemsFolder then itemsFolder:ClearAllChildren() end
                        updateButtons(plotModel, owner, baseCF, faction)
                    else
                        task.wait(1)
                        debounce = false
                    end
                end
            end)
        end
    elseif not hasSecondFloor and existingRebirth then
        existingRebirth:Destroy()
    end
end

-- Постройка базы для игрока
function PlotBuilder.createPlotForPlayer(player: Player, plotIndex: number)
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if not plotsContainer then
        plotsContainer = Instance.new("Folder")
        plotsContainer.Name = "TycoonPlots"
        plotsContainer.Parent = Workspace
    end

    local plotData = PlotManager.getPlotData(plotIndex)
    if not plotData then return end

    local baseCF = plotData.cframe
    local faction = plotData.faction

    local plotModel = Instance.new("Model")
    plotModel.Name = string.format("Plot_%s", player.Name)
    plotModel.Parent = plotsContainer

    local purchasedItems = Instance.new("Folder")
    purchasedItems.Name = "PurchasedItems"
    purchasedItems.Parent = plotModel

    local buttonsFolder = Instance.new("Folder")
    buttonsFolder.Name = "Buttons"
    buttonsFolder.Parent = plotModel

    -- 1. Пол базы
    local baseFloor = Instance.new("Part")
    baseFloor.Name = "BaseFloor"
    baseFloor.Size = Vector3.new(34, 1, 42)
    baseFloor.CFrame = baseCF * CFrame.new(0, 0, 0)
    baseFloor.Anchored = true
    baseFloor.Material = Enum.Material.SmoothPlastic
    baseFloor.Color = Color3.fromRGB(25, 25, 30)
    baseFloor.Parent = plotModel

    -- Вывеска базы фракции
    local sign = Instance.new("Part")
    sign.Name = "OwnerSign"
    sign.Size = Vector3.new(16, 3.5, 1)
    sign.CFrame = baseCF * CFrame.new(0, 8, -20)
    sign.Anchored = true
    sign.Material = Enum.Material.Neon
    sign.Color = faction.color
    sign.Parent = plotModel
    createBillboard(sign, faction.name, string.format("Владелец: %s", player.Name), Color3.fromRGB(255, 255, 255))

    -- 2. Конвейер
    local conveyor = Instance.new("Part")
    conveyor.Name = "Conveyor"
    conveyor.Size = Vector3.new(4, 0.8, 30)
    conveyor.CFrame = baseCF * CFrame.new(0, 0.6, 0)
    conveyor.Anchored = true
    conveyor.Material = Enum.Material.DiamondPlate
    conveyor.Color = Color3.fromRGB(40, 40, 45)
    
    -- Направление движения по ленте в локальных координатах
    local speed = TycoonConfig.CONVEYOR_SPEED
    if TycoonService.getRebirths(player) >= 2 then
        speed = 28 -- Золотой скоростной конвейер Rebirth 2
        conveyor.Material = Enum.Material.Neon
        conveyor.Color = Color3.fromRGB(241, 196, 15)
    end
    conveyor.AssemblyLinearVelocity = baseCF.LookVector * speed
    conveyor.Parent = plotModel

    -- 3. Сборщик монет (Collector)
    local collector = Instance.new("Part")
    collector.Name = "Collector"
    collector.Size = Vector3.new(5, 1.5, 3)
    collector.CFrame = baseCF * CFrame.new(0, 1.0, 15)
    collector.Anchored = true
    collector.Material = Enum.Material.Neon
    collector.Color = Color3.fromRGB(46, 204, 113)
    collector.Parent = plotModel
    createBillboard(collector, "СБОРЩИК АУРЫ", "Дропай руду сюда!", Color3.fromRGB(46, 204, 113))

    local coinSound = Instance.new("Sound")
    coinSound.SoundId = "rbxassetid://9114223177"
    coinSound.Volume = 0.6
    coinSound.Parent = collector

    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Rate = 0
    particles.Speed = NumberRange.new(5, 10)
    particles.Lifetime = NumberRange.new(0.4, 0.8)
    particles.Color = ColorSequence.new(Color3.fromRGB(46, 204, 113))
    particles.Parent = collector

    collector.Touched:Connect(function(hit)
        if hit.Name == "Ore" then
            local val = hit:GetAttribute("Value")
            if val and typeof(val) == "number" then
                TycoonService.addCash(player, val)
                coinSound:Play()
                particles:Emit(6)
                hit:Destroy()
            end
        end
    end)

    -- Восстановление ранее купленных объектов
    local owned = TycoonService.getOwnedItems(player)
    for _, item in ipairs(TycoonConfig.ITEMS) do
        if owned[item.id] then
            spawnStructure(plotModel, player, item, baseCF, faction)
        end
    end

    updateButtons(plotModel, player, baseCF, faction)
    print(string.format("[PlotBuilder] Built %s Base for %s", faction.name, player.Name))
    return plotModel
end

function PlotBuilder.destroyPlotForPlayer(player: Player)
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if plotsContainer then
        local plot = plotsContainer:FindFirstChild(string.format("Plot_%s", player.Name))
        if plot then
            plot:Destroy()
            print(string.format("[PlotBuilder] Destroyed Base for %s", player.Name))
        end
    end
end

return PlotBuilder
