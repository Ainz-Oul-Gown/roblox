--!strict

--[=[
    PlotBuilder
    Процедурный генератор 3D-мира тайкуна: создает базу, конвейерную ленту,
    коллектор монет, интерактивные кнопки покупок и активные дропперы руды.
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
local TycoonService = require(script.Parent:WaitForChild("TycoonService"))

local PlotBuilder = {}

-- Расположение кнопок на базе
local BUTTON_OFFSETS: { [string]: Vector3 } = {
    StarterDropper = Vector3.new(-8, 0.6, -10),
    Walls = Vector3.new(-8, 0.6, -5),
    UpgradedDropper = Vector3.new(-8, 0.6, 0),
    Roof = Vector3.new(-8, 0.6, 5),
    GoldDropper = Vector3.new(-8, 0.6, 10),
    SecondFloor = Vector3.new(-8, 0.6, 15),
}

-- Создание информационного BillboardGui над деталью
local function createBillboard(parent: Instance, title: string, subtitle: string, textColor: Color3)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "InfoGui"
    billboard.Size = UDim2.new(0, 200, 0, 60)
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
end

-- Создание физической 3D-модели купленного предмета
local function spawnPurchasedStructure(plotModel: Model, owner: Player, item: TycoonConfig.TycoonItem, origin: Vector3)
    local itemsFolder = plotModel:FindFirstChild("PurchasedItems") :: Folder
    if not itemsFolder then return end

    if item.category == "Dropper" then
        local dropperHeight = 8
        local zOffset = -10
        local color = Color3.fromRGB(52, 152, 219)
        local oreColor = Color3.fromRGB(41, 128, 185)

        if item.id == "UpgradedDropper" then
            zOffset = -3
            color = Color3.fromRGB(155, 89, 182)
            oreColor = Color3.fromRGB(142, 68, 173)
        elseif item.id == "GoldDropper" then
            zOffset = 4
            color = Color3.fromRGB(241, 196, 15)
            oreColor = Color3.fromRGB(243, 156, 18)
        end

        local dropper = Instance.new("Part")
        dropper.Name = item.id
        dropper.Size = Vector3.new(3, 2, 3)
        dropper.Position = origin + Vector3.new(0, dropperHeight, zOffset)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = color
        dropper.Parent = itemsFolder

        createBillboard(dropper, item.name, string.format("+$%d / %.1fc", item.dropValue or 1, item.dropInterval or 2), color)

        -- Запуск спавна руды
        task.spawn(function()
            local interval = item.dropInterval or 2.0
            local val = item.dropValue or 1

            while dropper.Parent and owner.Parent do
                task.wait(interval)

                local ore = Instance.new("Part")
                ore.Name = "Ore"
                ore.Size = Vector3.new(1.2, 1.2, 1.2)
                ore.Position = dropper.Position - Vector3.new(0, 1.5, 0)
                ore.Material = Enum.Material.Neon
                ore.Color = oreColor
                ore.TopSurface = Enum.SurfaceType.Smooth
                ore.BottomSurface = Enum.SurfaceType.Smooth
                ore:SetAttribute("Value", val)
                ore.Parent = Workspace
                
                -- Удаление упавшей в пустоту руды через 15 сек
                task.delay(15, function()
                    if ore.Parent then ore:Destroy() end
                end)
            end
        end)

    elseif item.id == "Walls" then
        local wallLeft = Instance.new("Part")
        wallLeft.Name = "WallLeft"
        wallLeft.Size = Vector3.new(1, 10, 40)
        wallLeft.Position = origin + Vector3.new(-15, 5, 0)
        wallLeft.Anchored = true
        wallLeft.Material = Enum.Material.Brick
        wallLeft.Color = Color3.fromRGB(120, 120, 120)
        wallLeft.Parent = itemsFolder

        local wallBack = Instance.new("Part")
        wallBack.Name = "WallBack"
        wallBack.Size = Vector3.new(30, 10, 1)
        wallBack.Position = origin + Vector3.new(0, 5, -20)
        wallBack.Anchored = true
        wallBack.Material = Enum.Material.Brick
        wallBack.Color = Color3.fromRGB(120, 120, 120)
        wallBack.Parent = itemsFolder

    elseif item.id == "Roof" then
        local roof = Instance.new("Part")
        roof.Name = "Roof"
        roof.Size = Vector3.new(32, 1, 42)
        roof.Position = origin + Vector3.new(0, 10.5, 0)
        roof.Anchored = true
        roof.Material = Enum.Material.Glass
        roof.Transparency = 0.3
        roof.Color = Color3.fromRGB(52, 73, 94)
        roof.Parent = itemsFolder

    elseif item.id == "SecondFloor" then
        local floor2 = Instance.new("Part")
        floor2.Name = "SecondFloor"
        floor2.Size = Vector3.new(30, 1, 40)
        floor2.Position = origin + Vector3.new(0, 11, 0)
        floor2.Anchored = true
        floor2.Material = Enum.Material.WoodPlanks
        floor2.Color = Color3.fromRGB(180, 130, 80)
        floor2.Parent = itemsFolder
    end
end

-- Обновление доступных кнопок покупок на базе
local function updateButtons(plotModel: Model, owner: Player, origin: Vector3)
    local buttonsFolder = plotModel:FindFirstChild("Buttons") :: Folder
    if not buttonsFolder then return end

    for _, item in ipairs(TycoonConfig.ITEMS) do
        -- Если уже куплен, кнопка не нужна
        if TycoonService.hasItem(owner, item.id) then
            local existing = buttonsFolder:FindFirstChild("Button_" .. item.id)
            if existing then existing:Destroy() end
            continue
        end

        -- Проверяем выполнено ли условие (пререквизит)
        local isUnlocked = true
        if item.dependsOn and not TycoonService.hasItem(owner, item.dependsOn) then
            isUnlocked = false
        end

        local existing = buttonsFolder:FindFirstChild("Button_" .. item.id)

        if isUnlocked and not existing then
            local offset = BUTTON_OFFSETS[item.id] or Vector3.new(-8, 0.6, 0)
            
            -- Подставка кнопки
            local buttonStand = Instance.new("Part")
            buttonStand.Name = "Button_" .. item.id
            buttonStand.Size = Vector3.new(3.5, 0.4, 3.5)
            buttonStand.Position = origin + offset
            buttonStand.Anchored = true
            buttonStand.Material = Enum.Material.Plastic
            buttonStand.Color = Color3.fromRGB(40, 40, 40)
            buttonStand.Parent = buttonsFolder

            -- Нажимная пластина
            local pad = Instance.new("Part")
            pad.Name = "Pad"
            pad.Size = Vector3.new(2.8, 0.3, 2.8)
            pad.Position = buttonStand.Position + Vector3.new(0, 0.3, 0)
            pad.Anchored = true
            pad.Material = Enum.Material.Neon
            pad.Color = if item.cost == 0 then Color3.fromRGB(46, 204, 113) else Color3.fromRGB(230, 126, 34)
            pad.Parent = buttonStand

            local priceText = if item.cost == 0 then "Бесплатно" else string.format("$%d", item.cost)
            createBillboard(pad, item.name, priceText, pad.Color)

            -- Обработка наступления на кнопку
            local debounce = false
            pad.Touched:Connect(function(hit: BasePart)
                if debounce then return end
                local character = hit.Parent
                local player = Players:GetPlayerFromCharacter(character)
                if player and player == owner then
                    debounce = true
                    local success = TycoonService.purchaseItem(player, item.id)
                    if success then
                        buttonStand:Destroy()
                        spawnPurchasedStructure(plotModel, owner, item, origin)
                        updateButtons(plotModel, owner, origin)
                    else
                        task.wait(1)
                        debounce = false
                    end
                end
            end)
        elseif not isUnlocked and existing then
            existing:Destroy()
        end
    end
end

-- Создание базы для игрока
function PlotBuilder.createPlotForPlayer(player: Player, plotIndex: number)
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if not plotsContainer then
        plotsContainer = Instance.new("Folder")
        plotsContainer.Name = "TycoonPlots"
        plotsContainer.Parent = Workspace
    end

    -- Располагаем базу перед спавном (Z = 30)
    local origin = Vector3.new(0, 0.5, 30 + (plotIndex - 1) * 70)

    local plotModel = Instance.new("Model")
    plotModel.Name = string.format("Plot_%s", player.Name)
    plotModel.Parent = plotsContainer

    -- Папки для структуры
    local purchasedItems = Instance.new("Folder")
    purchasedItems.Name = "PurchasedItems"
    purchasedItems.Parent = plotModel

    local buttonsFolder = Instance.new("Folder")
    buttonsFolder.Name = "Buttons"
    buttonsFolder.Parent = plotModel

    -- 1. Основание базы (Пол)
    local baseFloor = Instance.new("Part")
    baseFloor.Name = "BaseFloor"
    baseFloor.Size = Vector3.new(34, 1, 44)
    baseFloor.Position = origin + Vector3.new(0, 0, 0)
    baseFloor.Anchored = true
    baseFloor.Material = Enum.Material.SmoothPlastic
    baseFloor.Color = Color3.fromRGB(30, 30, 35)
    baseFloor.Parent = plotModel

    -- Вывеска владельца базы перед входом
    local sign = Instance.new("Part")
    sign.Name = "OwnerSign"
    sign.Size = Vector3.new(14, 3, 1)
    sign.Position = origin + Vector3.new(0, 8, -21)
    sign.Anchored = true
    sign.Material = Enum.Material.Neon
    sign.Color = Color3.fromRGB(52, 152, 219)
    sign.Parent = plotModel
    createBillboard(sign, string.format("База: %s", player.Name), "Тайкун Запущен!", Color3.fromRGB(255, 255, 255))

    -- 2. Конвейерная лента
    local conveyor = Instance.new("Part")
    conveyor.Name = "Conveyor"
    conveyor.Size = Vector3.new(4, 0.8, 32)
    conveyor.Position = origin + Vector3.new(0, 0.6, -1)
    conveyor.Anchored = true
    conveyor.Material = Enum.Material.DiamondPlate
    conveyor.Color = Color3.fromRGB(45, 52, 54)
    conveyor.AssemblyLinearVelocity = Vector3.new(0, 0, TycoonConfig.CONVEYOR_SPEED)
    conveyor.Parent = plotModel

    -- Бортики конвейера
    local borderLeft = Instance.new("Part")
    borderLeft.Name = "BorderLeft"
    borderLeft.Size = Vector3.new(0.5, 1.6, 32)
    borderLeft.Position = origin + Vector3.new(-2.2, 1.0, -1)
    borderLeft.Anchored = true
    borderLeft.Color = Color3.fromRGB(20, 20, 20)
    borderLeft.Parent = plotModel

    local borderRight = Instance.new("Part")
    borderRight.Name = "BorderRight"
    borderRight.Size = Vector3.new(0.5, 1.6, 32)
    borderRight.Position = origin + Vector3.new(2.2, 1.0, -1)
    borderRight.Anchored = true
    borderRight.Color = Color3.fromRGB(20, 20, 20)
    borderRight.Parent = plotModel

    -- 3. Сборщик монет (Collector)
    local collector = Instance.new("Part")
    collector.Name = "Collector"
    collector.Size = Vector3.new(5, 1.5, 3)
    collector.Position = origin + Vector3.new(0, 1.0, 16)
    collector.Anchored = true
    collector.Material = Enum.Material.Neon
    collector.Color = Color3.fromRGB(46, 204, 113)
    collector.Parent = plotModel
    createBillboard(collector, "СБОРЩИК", "Дропни сюда руду!", Color3.fromRGB(46, 204, 113))

    -- Фиксация сбора руды
    collector.Touched:Connect(function(hit: BasePart)
        if hit.Name == "Ore" then
            local val = hit:GetAttribute("Value")
            if val and typeof(val) == "number" then
                TycoonService.addCash(player, val)
                hit:Destroy()
            end
        end
    end)

    -- Спавним стартовый комплект кнопок
    updateButtons(plotModel, player, origin)

    print(string.format("[PlotBuilder] Created Tycoon Plot for %s at %s", player.Name, tostring(origin)))
    return plotModel
end

-- Очистка базы при выходе игрока
function PlotBuilder.destroyPlotForPlayer(player: Player)
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if plotsContainer then
        local plot = plotsContainer:FindFirstChild(string.format("Plot_%s", player.Name))
        if plot then
            plot:Destroy()
            print(string.format("[PlotBuilder] Destroyed Tycoon Plot for %s", player.Name))
        end
    end
end

return PlotBuilder
