--!strict

--[=[
    PlotBuilder (Bug-Fixed & Perimeter-Sealed Edition)
    Исправления:
    1. Направление движения конвейера строго в сторону Сборщика (без вылетания назад).
    2. Задний стоппер и высокие бортики конвейера, чтобы руда не падала мимо.
    3. Полностью закрытый передний фасад стен вокруг лазерных ворот (без щелей и дыр).
    4. Звуковые и визуальные эффекты.
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

local function spawnStructure(plotModel: Model, owner: Player, item: TycoonConfig.TycoonItem, baseCF: CFrame, faction: TycoonConfig.Faction)
    local itemsFolder = plotModel:FindFirstChild("PurchasedItems") :: Folder
    if not itemsFolder then return end

    if item.id == "FactionDropper" then
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
                ore.CFrame = dropper.CFrame * CFrame.new(0, -1.8, 0)
                ore.Material = Enum.Material.Neon
                ore.Color = faction.oreColor
                ore.TopSurface = Enum.SurfaceType.Smooth
                ore.BottomSurface = Enum.SurfaceType.Smooth
                ore.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 1, 1)
                ore:SetAttribute("Value", 1)
                ore.Parent = Workspace
                task.delay(15, function() if ore.Parent then ore:Destroy() end end)
            end
        end)

    elseif item.id == "LaserGate" then
        -- Лазерные ворота по центру фасада с верхней защитной балкой (lintel)
        local gateModel = Instance.new("Model")
        gateModel.Name = "LaserGate"
        gateModel.Parent = itemsFolder

        local postLeft = Instance.new("Part")
        postLeft.Name = "PostLeft"
        postLeft.Size = Vector3.new(1.2, 10, 1.2)
        postLeft.CFrame = baseCF * CFrame.new(-5.5, 5, 20)
        postLeft.Anchored = true
        postLeft.Color = Color3.fromRGB(20, 20, 20)
        postLeft.Parent = gateModel

        local postRight = Instance.new("Part")
        postRight.Name = "PostRight"
        postRight.Size = Vector3.new(1.2, 10, 1.2)
        postRight.CFrame = baseCF * CFrame.new(5.5, 5, 20)
        postRight.Anchored = true
        postRight.Color = Color3.fromRGB(20, 20, 20)
        postRight.Parent = gateModel

        local lintel = Instance.new("Part")
        lintel.Name = "GateLintel"
        lintel.Size = Vector3.new(12.2, 1.2, 1.2)
        lintel.CFrame = baseCF * CFrame.new(0, 9.5, 20)
        lintel.Anchored = true
        lintel.Color = Color3.fromRGB(20, 20, 20)
        lintel.Parent = gateModel

        local beam = Instance.new("Part")
        beam.Name = "LaserBeam"
        beam.Size = Vector3.new(10, 8.8, 0.4)
        beam.CFrame = baseCF * CFrame.new(0, 4.5, 20)
        beam.Anchored = true
        beam.CanCollide = false
        beam.Material = Enum.Material.ForceField
        beam.Color = Color3.fromRGB(231, 76, 60)
        beam.Transparency = 0.4
        beam.Parent = gateModel

        createBillboard(beam, "⚡ ЗАЩИТНЫЙ ЛАЗЕР", "Вход только для владельца!", Color3.fromRGB(231, 76, 60))

        local function onLaserTouch(hit: BasePart)
            local char = hit.Parent
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum and char.Parent then
                hum = char.Parent:FindFirstChildOfClass("Humanoid")
                if hum then char = char.Parent end
            end
            if hum and hum.Health > 0 then
                local p = Players:GetPlayerFromCharacter(char)
                if p and p ~= owner then
                    hum.Health = 0 -- Защита базы: мгновенная ликвидация нарушителя
                end
            end
        end
        beam.Touched:Connect(onLaserTouch)

    elseif item.id == "BrainrotWalls" then
        -- 100% герметичный периметр стен без единой дыры
        -- Левая стена
        local wLeft = Instance.new("Part")
        wLeft.Name = "WallLeft"
        wLeft.Size = Vector3.new(1, 10, 42)
        wLeft.CFrame = baseCF * CFrame.new(-17, 5, 0)
        wLeft.Anchored = true
        wLeft.Material = Enum.Material.SmoothPlastic
        wLeft.Color = faction.secondaryColor
        wLeft.Parent = itemsFolder

        -- Правая стена
        local wRight = Instance.new("Part")
        wRight.Name = "WallRight"
        wRight.Size = Vector3.new(1, 10, 42)
        wRight.CFrame = baseCF * CFrame.new(17, 5, 0)
        wRight.Anchored = true
        wRight.Material = Enum.Material.SmoothPlastic
        wRight.Color = faction.secondaryColor
        wRight.Parent = itemsFolder

        -- Задняя стена
        local wBack = Instance.new("Part")
        wBack.Name = "WallBack"
        wBack.Size = Vector3.new(35, 10, 1)
        wBack.CFrame = baseCF * CFrame.new(0, 5, -21)
        wBack.Anchored = true
        wBack.Material = Enum.Material.SmoothPlastic
        wBack.Color = faction.secondaryColor
        wBack.Parent = itemsFolder

        -- Передняя левая стена (от угла до ворот)
        local wFrontLeft = Instance.new("Part")
        wFrontLeft.Name = "WallFrontLeft"
        wFrontLeft.Size = Vector3.new(11.5, 10, 1)
        wFrontLeft.CFrame = baseCF * CFrame.new(-11.25, 5, 20)
        wFrontLeft.Anchored = true
        wFrontLeft.Material = Enum.Material.SmoothPlastic
        wFrontLeft.Color = faction.secondaryColor
        wFrontLeft.Parent = itemsFolder

        -- Передняя правая стена (от ворот до угла)
        local wFrontRight = Instance.new("Part")
        wFrontRight.Name = "WallFrontRight"
        wFrontRight.Size = Vector3.new(11.5, 10, 1)
        wFrontRight.CFrame = baseCF * CFrame.new(11.25, 5, 20)
        wFrontRight.Anchored = true
        wFrontRight.Material = Enum.Material.SmoothPlastic
        wFrontRight.Color = faction.secondaryColor
        wFrontRight.Parent = itemsFolder

    elseif item.id == "FactionAbilityStand" then
        local stand = Instance.new("Part")
        stand.Name = "AbilityStand"
        stand.Size = Vector3.new(4, 1, 4)
        stand.CFrame = baseCF * CFrame.new(10, 0.6, -10)
        stand.Anchored = true
        stand.Material = Enum.Material.Neon
        stand.Color = faction.color
        stand.Parent = itemsFolder

        createBillboard(stand, string.format("⚡ %s (УЛУЧШЕНО)", faction.abilityName), "Кулдаун сокращен в 2 раза!", faction.color)

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
                ore.CFrame = dropper.CFrame * CFrame.new(0, -1.8, 0)
                ore.Material = Enum.Material.Neon
                ore.Color = Color3.fromRGB(46, 204, 113)
                ore.TopSurface = Enum.SurfaceType.Smooth
                ore.BottomSurface = Enum.SurfaceType.Smooth
                ore.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 1, 1)
                ore:SetAttribute("Value", 8)
                ore.Parent = Workspace
                task.delay(15, function() if ore.Parent then ore:Destroy() end end)
            end
        end)

    elseif item.id == "NeonRoof" then
        local roof = Instance.new("Part")
        roof.Name = "NeonRoof"
        roof.Size = Vector3.new(35, 1, 43)
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
                ore.CFrame = dropper.CFrame * CFrame.new(0, -1.8, 0)
                ore.Material = Enum.Material.Neon
                ore.Color = Color3.fromRGB(241, 196, 15)
                ore.TopSurface = Enum.SurfaceType.Smooth
                ore.BottomSurface = Enum.SurfaceType.Smooth
                ore.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 1, 1)
                ore:SetAttribute("Value", 35)
                ore.Parent = Workspace
                task.delay(15, function() if ore.Parent then ore:Destroy() end end)
            end
        end)

    elseif item.id == "SecondFloor" then
        local floor2 = Instance.new("Part")
        floor2.Name = "SecondFloor"
        floor2.Size = Vector3.new(34, 1, 41)
        floor2.CFrame = baseCF * CFrame.new(0, 11, 0)
        floor2.Anchored = true
        floor2.Material = Enum.Material.SmoothPlastic
        floor2.Color = Color3.fromRGB(40, 40, 45)
        floor2.Parent = itemsFolder

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

    -- Кнопка Rebirth
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

function PlotBuilder.initAllBases(onClaimCallback: (player: Player, plotIndex: number) -> ())
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if not plotsContainer then
        plotsContainer = Instance.new("Folder")
        plotsContainer.Name = "TycoonPlots"
        plotsContainer.Parent = Workspace
    end

    local allPlots = PlotManager.getAllPlots()
    for plotIndex = 1, TycoonConfig.TOTAL_PLOTS do
        local plotData = allPlots[plotIndex]
        local baseCF = plotData.cframe
        local faction = plotData.faction

        local plotModel = Instance.new("Model")
        plotModel.Name = string.format("Base_%d", plotIndex)
        plotModel.Parent = plotsContainer

        local purchasedItems = Instance.new("Folder")
        purchasedItems.Name = "PurchasedItems"
        purchasedItems.Parent = plotModel

        local buttonsFolder = Instance.new("Folder")
        buttonsFolder.Name = "Buttons"
        buttonsFolder.Parent = plotModel

        local baseFloor = Instance.new("Part")
        baseFloor.Name = "BaseFloor"
        baseFloor.Size = Vector3.new(34, 1, 42)
        baseFloor.CFrame = baseCF * CFrame.new(0, 0, 0)
        baseFloor.Anchored = true
        baseFloor.Material = Enum.Material.SmoothPlastic
        baseFloor.Color = Color3.fromRGB(25, 25, 30)
        baseFloor.Parent = plotModel

        local sign = Instance.new("Part")
        sign.Name = "OwnerSign"
        sign.Size = Vector3.new(16, 3.5, 1)
        sign.CFrame = baseCF * CFrame.new(0, 8, -20)
        sign.Anchored = true
        sign.Material = Enum.Material.Neon
        sign.Color = faction.color
        sign.Parent = plotModel
        createBillboard(sign, faction.name, "[СВОБОДНО] Встань, чтобы занять!", Color3.fromRGB(255, 255, 255))

        local claimPad = Instance.new("Part")
        claimPad.Name = "ClaimPad"
        claimPad.Size = Vector3.new(8, 0.4, 8)
        claimPad.CFrame = baseCF * CFrame.new(0, 0.4, 14)
        claimPad.Anchored = true
        claimPad.Material = Enum.Material.Neon
        claimPad.Color = faction.color
        claimPad.Parent = plotModel

        createBillboard(claimPad, string.format("👉 ЗАХВАТИТЬ: %s", faction.name), "Встань сюда, чтобы выбрать эту базу!", faction.color)

        local debounce = false
        claimPad.Touched:Connect(function(hit)
            if debounce then return end
            local char = hit.Parent
            local player = Players:GetPlayerFromCharacter(char)
            if player then
                debounce = true
                onClaimCallback(player, plotIndex)
                task.wait(1)
                debounce = false
            end
        end)
    end
    print("[PlotBuilder] All 8 circular bases created with ClaimPads!")
end

function PlotBuilder.activatePlot(player: Player, plotIndex: number)
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if not plotsContainer then return end
    local plotModel = plotsContainer:FindFirstChild(string.format("Base_%d", plotIndex)) :: Model?
    if not plotModel then return end

    local plotData = PlotManager.getPlotData(plotIndex)
    if not plotData then return end
    local baseCF = plotData.cframe
    local faction = plotData.faction

    local claimPad = plotModel:FindFirstChild("ClaimPad")
    if claimPad then claimPad:Destroy() end

    local sign = plotModel:FindFirstChild("OwnerSign") :: Part?
    if sign then
        local oldGui = sign:FindFirstChild("InfoGui")
        if oldGui then oldGui:Destroy() end
        createBillboard(sign, faction.name, string.format("Владелец: %s", player.Name), Color3.fromRGB(255, 255, 255))
    end

    local char = player.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            -- Телепортируем игрока ВНУТРЬ базы (в сторону дроппера/конвейера)
            -- ClaimPad на +Z, но дроппер на -Z, поэтому игрок идёт в центр базы
            root.CFrame = baseCF * CFrame.new(0, 4, 0)
        end
    end

    -- 1. Конвейер с ПРАВИЛЬНЫМ направлением вектора (строго в сторону Сборщика на +Z!)
    local conveyor = Instance.new("Part")
    conveyor.Name = "Conveyor"
    conveyor.Size = Vector3.new(4, 0.8, 30)
    conveyor.CFrame = baseCF * CFrame.new(0, 0.6, 0)
    conveyor.Anchored = true
    conveyor.Material = Enum.Material.DiamondPlate
    conveyor.Color = Color3.fromRGB(40, 40, 45)
    conveyor.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1.0, 0, 1, 1)
    
    local speed = TycoonConfig.CONVEYOR_SPEED
    if TycoonService.getRebirths(player) >= 2 then
        speed = 28
        conveyor.Material = Enum.Material.Neon
        conveyor.Color = Color3.fromRGB(241, 196, 15)
    end
    -- Направление строго по локальной оси +Z (вперед к сборщику!)
    local forwardVector = baseCF:VectorToWorldSpace(Vector3.new(0, 0, 1))
    conveyor.AssemblyLinearVelocity = forwardVector * speed
    (conveyor :: any).Velocity = forwardVector * speed
    conveyor.Parent = plotModel

    -- 2. Задний стоппер конвейера (чтобы руда никогда не вылетала назад)
    local conveyorBackstop = Instance.new("Part")
    conveyorBackstop.Name = "ConveyorBackstop"
    conveyorBackstop.Size = Vector3.new(4.5, 2.5, 0.6)
    conveyorBackstop.CFrame = baseCF * CFrame.new(0, 1.6, -15.2)
    conveyorBackstop.Anchored = true
    conveyorBackstop.Material = Enum.Material.Metal
    conveyorBackstop.Color = Color3.fromRGB(20, 20, 20)
    conveyorBackstop.Parent = plotModel

    -- Боковые бортики конвейера (высота 2.5 studs)
    local borderLeft = Instance.new("Part")
    borderLeft.Name = "BorderLeft"
    borderLeft.Size = Vector3.new(0.5, 2.5, 30)
    borderLeft.CFrame = baseCF * CFrame.new(-2.2, 1.6, 0)
    borderLeft.Anchored = true
    borderLeft.Color = Color3.fromRGB(20, 20, 20)
    borderLeft.Parent = plotModel

    local borderRight = Instance.new("Part")
    borderRight.Name = "BorderRight"
    borderRight.Size = Vector3.new(0.5, 2.5, 30)
    borderRight.CFrame = baseCF * CFrame.new(2.2, 1.6, 0)
    borderRight.Anchored = true
    borderRight.Color = Color3.fromRGB(20, 20, 20)
    borderRight.Parent = plotModel

    -- 3. Сборщик монет (Collector)
    local collector = Instance.new("Part")
    collector.Name = "Collector"
    collector.Size = Vector3.new(6, 2.2, 3.5)
    collector.CFrame = baseCF * CFrame.new(0, 1.4, 15.2)
    collector.Anchored = true
    collector.CanCollide = true
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
        if hit.Name == "Ore" and not hit:GetAttribute("Collected") then
            hit:SetAttribute("Collected", true)
            local val = hit:GetAttribute("Value")
            if val and typeof(val) == "number" then
                TycoonService.addCash(player, val)
                coinSound:Play()
                particles:Emit(8)
                hit:Destroy()
            end
        end
    end)

    local owned = TycoonService.getOwnedItems(player)
    for _, item in ipairs(TycoonConfig.ITEMS) do
        if owned[item.id] then
            spawnStructure(plotModel, player, item, baseCF, faction)
        end
    end

    updateButtons(plotModel, player, baseCF, faction)
    print(string.format("[PlotBuilder] Base %d activated for %s", plotIndex, player.Name))
end

function PlotBuilder.resetPlotToUnclaimed(plotIndex: number, onClaimCallback: (player: Player, plotIndex: number) -> ())
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if not plotsContainer then return end
    local plotModel = plotsContainer:FindFirstChild(string.format("Base_%d", plotIndex)) :: Model?
    if not plotModel then return end

    local plotData = PlotManager.getPlotData(plotIndex)
    if not plotData then return end
    local baseCF = plotData.cframe
    local faction = plotData.faction

    local pItems = plotModel:FindFirstChild("PurchasedItems")
    if pItems then pItems:ClearAllChildren() end

    local buttons = plotModel:FindFirstChild("Buttons")
    if buttons then buttons:ClearAllChildren() end

    local conveyor = plotModel:FindFirstChild("Conveyor")
    if conveyor then conveyor:Destroy() end

    local backstop = plotModel:FindFirstChild("ConveyorBackstop")
    if backstop then backstop:Destroy() end

    local borderLeft = plotModel:FindFirstChild("BorderLeft")
    if borderLeft then borderLeft:Destroy() end

    local borderRight = plotModel:FindFirstChild("BorderRight")
    if borderRight then borderRight:Destroy() end

    local collector = plotModel:FindFirstChild("Collector")
    if collector then collector:Destroy() end

    local sign = plotModel:FindFirstChild("OwnerSign") :: Part?
    if sign then
        local oldGui = sign:FindFirstChild("InfoGui")
        if oldGui then oldGui:Destroy() end
        createBillboard(sign, faction.name, "[СВОБОДНО] Встань, чтобы занять!", Color3.fromRGB(255, 255, 255))
    end

    local claimPad = Instance.new("Part")
    claimPad.Name = "ClaimPad"
    claimPad.Size = Vector3.new(8, 0.4, 8)
    claimPad.CFrame = baseCF * CFrame.new(0, 0.4, 14)
    claimPad.Anchored = true
    claimPad.Material = Enum.Material.Neon
    claimPad.Color = faction.color
    claimPad.Parent = plotModel

    createBillboard(claimPad, string.format("👉 ЗАХВАТИТЬ: %s", faction.name), "Встань сюда, чтобы выбрать эту базу!", faction.color)

    local debounce = false
    claimPad.Touched:Connect(function(hit)
        if debounce then return end
        local char = hit.Parent
        local player = Players:GetPlayerFromCharacter(char)
        if player then
            debounce = true
            onClaimCallback(player, plotIndex)
            task.wait(1)
            debounce = false
        end
    end)

    print(string.format("[PlotBuilder] Base %d reset to unclaimed.", plotIndex))
end

function PlotBuilder.createPlotForPlayer(player: Player, plotIndex: number)
    PlotBuilder.activatePlot(player, plotIndex)
end

function PlotBuilder.destroyPlotForPlayer(player: Player)
    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if plotIndex then
        PlotBuilder.resetPlotToUnclaimed(plotIndex, function() end)
    end
end

return PlotBuilder
