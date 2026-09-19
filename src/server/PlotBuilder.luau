--!strict

--[=[
    PlotBuilder (Full 2-Floor Tycoon with Upgraders, Vault & Multi-Abilities)
    Особенности:
    - Размеры базы 48 x 64 стадов (комфортный масштаб под 2 этажа).
    - Хранилище Сборщика (Vault): руда накапливается в сейфе базы,
      игрок забирает деньги в кошелек наступая на WithdrawPad.
    - Апгрейдеры с мутацией руды: Лазерный (x2, золото), Квантовый (x3, бирюза),
      Аннигилятор (x5, огненно-малиновый) меняют цвет, неон и частицы.
    - Лестница на 2-й этаж со ступеньками и перилами.
    - Полноценный 2-й этаж с верхним конвейером и шахтой вертикального сброса руды в нижний Сборщик.
    - Стойки способностей на 1-м и 2-м этажах (Базовая, Тактическая, Ультимейт).
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig", 10))
local EconomyManager = require(Shared:WaitForChild("EconomyManager", 10))

local serverScript = script.Parent or game:GetService("ServerScriptService"):WaitForChild("Server", 10)
local TycoonService = require(serverScript:WaitForChild("TycoonService", 10))
local PlotManager = require(serverScript:WaitForChild("PlotManager", 10))

local PlotBuilder = {}

-- Ссылки на табло вывода сейфа по базам для живого обновления суммы
local vaultLabels: { [number]: TextLabel } = {}

local function createBillboard(
    parent: Instance,
    title: string,
    subtitle: string,
    textColor: Color3,
    offset: Vector3?,
    maxDist: number?,
    alwaysOnTop: boolean?
)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "InfoGui"
    billboard.Size = UDim2.new(0, 220, 0, 56)
    billboard.StudsOffset = offset or Vector3.new(0, 3.2, 0)
    billboard.AlwaysOnTop = if alwaysOnTop ~= nil then alwaysOnTop else false
    billboard.MaxDistance = maxDist or 30
    billboard.Parent = parent

    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.new(1, 0, 1, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    bgFrame.BackgroundTransparency = 0.35
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = bgFrame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, -6)
    label.Position = UDim2.new(0, 5, 0, 3)
    label.BackgroundTransparency = 1
    label.Text = string.format("%s\n%s", title, subtitle)
    label.TextColor3 = textColor
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Parent = bgFrame
    return label
end

-- Создание руды из дроппера
local function spawnOre(originCF: CFrame, baseValue: number, oreColor: Color3, tag: string)
    local ore = Instance.new("Part")
    ore.Name = "Ore"
    ore.Size = Vector3.new(1.4, 1.4, 1.4)
    ore.CFrame = originCF
    ore.Material = Enum.Material.Neon
    ore.Color = oreColor
    ore.TopSurface = Enum.SurfaceType.Smooth
    ore.BottomSurface = Enum.SurfaceType.Smooth
    ore:SetAttribute("Value", baseValue)
    ore:SetAttribute("OreTag", tag)

    local highlight = Instance.new("SelectionBox")
    highlight.Adornee = ore
    highlight.Color3 = oreColor
    highlight.LineThickness = 0.04
    highlight.Parent = ore

    ore.Parent = Workspace
    Debris:AddItem(ore, 25)
    return ore
end

-- Апгрейдер: неоновая арка над конвейером с умножением руды и мутацией цвета
local function createUpgrader(
    parent: Instance,
    id: string,
    cf: CFrame,
    width: number,
    height: number,
    mult: number,
    neonColor: Color3,
    title: string
)
    local upgraderModel = Instance.new("Model")
    upgraderModel.Name = id
    upgraderModel.Parent = parent

    -- Левая и правая стойки арки
    local pLeft = Instance.new("Part")
    pLeft.Name = "PostLeft"
    pLeft.Size = Vector3.new(1, height, 1)
    pLeft.CFrame = cf * CFrame.new(-width / 2, height / 2, 0)
    pLeft.Anchored = true
    pLeft.Color = Color3.fromRGB(30, 30, 35)
    pLeft.Parent = upgraderModel

    local pRight = Instance.new("Part")
    pRight.Name = "PostRight"
    pRight.Size = Vector3.new(1, height, 1)
    pRight.CFrame = cf * CFrame.new(width / 2, height / 2, 0)
    pRight.Anchored = true
    pRight.Color = Color3.fromRGB(30, 30, 35)
    pRight.Parent = upgraderModel

    -- Верхняя перекладина
    local topBeam = Instance.new("Part")
    topBeam.Name = "TopBeam"
    topBeam.Size = Vector3.new(width + 1, 1, 1)
    topBeam.CFrame = cf * CFrame.new(0, height, 0)
    topBeam.Anchored = true
    topBeam.Color = neonColor
    topBeam.Material = Enum.Material.Neon
    topBeam.Parent = upgraderModel

    -- Лазерный сенсор прохода
    local scanner = Instance.new("Part")
    scanner.Name = "ScanField"
    scanner.Size = Vector3.new(width - 0.2, height - 0.8, 0.4)
    scanner.CFrame = cf * CFrame.new(0, height / 2, 0)
    scanner.Anchored = true
    scanner.CanCollide = false
    scanner.Material = Enum.Material.ForceField
    scanner.Color = neonColor
    scanner.Transparency = 0.3
    scanner.Parent = upgraderModel

    createBillboard(topBeam, title, string.format("x%d МНОЖИТЕЛЬ РУДЫ", mult), neonColor, Vector3.new(0, 2.5, 0))

    -- Логика умножения при касании
    scanner.Touched:Connect(function(hit)
        if hit.Name == "Ore" and not hit:GetAttribute("Upgraded_" .. id) then
            hit:SetAttribute("Upgraded_" .. id, true)
            local curVal = hit:GetAttribute("Value") or 1
            local newVal = math.floor(curVal * mult)
            hit:SetAttribute("Value", newVal)

            -- Мутация визуала кубика
            hit.Color = neonColor
            hit.Material = Enum.Material.Neon

            -- Вспышка искр
            local pe = Instance.new("ParticleEmitter")
            pe.Rate = 18
            pe.Speed = NumberRange.new(4, 8)
            pe.Lifetime = NumberRange.new(0.4, 0.8)
            pe.Color = ColorSequence.new(neonColor)
            pe.Parent = hit
            task.delay(0.6, function() if pe.Parent then pe:Destroy() end end)
        end
    end)
end

-- Стойка способности с пьедесталом и витриной предмета
local function createAbilityPedestal(parent: Instance, id: string, cf: CFrame, title: string, subtitle: string, color: Color3)
    local stand = Instance.new("Model")
    stand.Name = id
    stand.Parent = parent

    local base = Instance.new("Part")
    base.Name = "PedestalBase"
    base.Size = Vector3.new(5, 1, 5)
    base.CFrame = cf * CFrame.new(0, 0.5, 0)
    base.Anchored = true
    base.Material = Enum.Material.SmoothPlastic
    base.Color = Color3.fromRGB(30, 30, 35)
    base.Parent = stand

    local ring = Instance.new("Part")
    ring.Name = "PedestalRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.4, 4.6, 4.6)
    ring.CFrame = cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Parent = stand

    local orb = Instance.new("Part")
    orb.Name = "AbilityOrb"
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(2, 2, 2)
    orb.CFrame = cf * CFrame.new(0, 3, 0)
    orb.Anchored = true
    orb.CanCollide = false
    orb.Material = Enum.Material.Neon
    orb.Color = color
    orb.Parent = stand

    createBillboard(orb, title, subtitle, color, Vector3.new(0, 3, 0))
end

local function spawnStructure(plotModel: Model, owner: Player, item: TycoonConfig.TycoonItem, baseCF: CFrame, faction: TycoonConfig.Faction)
    local itemsFolder = plotModel:FindFirstChild("PurchasedItems") :: Folder
    if not itemsFolder then return end

    if item.id == "FactionDropper" then
        local dropper = Instance.new("Part")
        dropper.Name = "FactionDropper"
        dropper.Size = Vector3.new(4, 2.5, 4)
        dropper.CFrame = baseCF * CFrame.new(0, 10, -20)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = faction.color
        dropper.Parent = itemsFolder

        createBillboard(dropper, faction.dropperItemName, "+1 Aura / 1.8c", faction.color)

        task.spawn(function()
            while dropper.Parent and owner.Parent do
                task.wait(1.8)
                spawnOre(dropper.CFrame * CFrame.new(0, -2.2, 0), 1, faction.oreColor, "Base")
            end
        end)

    elseif item.id == "LaserGate" then
        local gateModel = Instance.new("Model")
        gateModel.Name = "LaserGate"
        gateModel.Parent = itemsFolder

        local postL = Instance.new("Part")
        postL.Size = Vector3.new(1.8, 14, 1.8)
        postL.CFrame = baseCF * CFrame.new(-6, 7, 36)
        postL.Anchored = true
        postL.Color = Color3.fromRGB(25, 25, 30)
        postL.Parent = gateModel

        local postR = Instance.new("Part")
        postR.Size = Vector3.new(1.8, 14, 1.8)
        postR.CFrame = baseCF * CFrame.new(6, 7, 36)
        postR.Anchored = true
        postR.Color = Color3.fromRGB(25, 25, 30)
        postR.Parent = gateModel

        local lintel = Instance.new("Part")
        lintel.Name = "GateLintel"
        lintel.Size = Vector3.new(13.8, 1.6, 1.8)
        lintel.CFrame = baseCF * CFrame.new(0, 13.2, 36)
        lintel.Anchored = true
        lintel.Color = Color3.fromRGB(25, 25, 30)
        lintel.Parent = gateModel

        local beam = Instance.new("Part")
        beam.Name = "LaserBeam"
        beam.Size = Vector3.new(10.2, 12.4, 0.4)
        beam.CFrame = baseCF * CFrame.new(0, 6.2, 36)
        beam.Anchored = true
        beam.CanCollide = false
        beam.Material = Enum.Material.ForceField
        beam.Color = Color3.fromRGB(231, 76, 60)
        beam.Transparency = 0.35
        beam.Parent = gateModel

        createBillboard(beam, "⚡ ЗАЩИТНЫЙ ЛАЗЕР", "Вход только для владельца!", Color3.fromRGB(231, 76, 60), Vector3.new(0, 4, 0), 28, false)

        beam.Touched:Connect(function(hit)
            local char = hit.Parent
            if not char then return end
            if char:IsA("Accessory") then char = char.Parent end
            local player = Players:GetPlayerFromCharacter(char)
            if player and player ~= owner then
                local hum = char:FindFirstChild("Humanoid") :: Humanoid?
                if hum and hum.Health > 0 then
                    local tag = Instance.new("ObjectValue")
                    tag.Name = "creator"
                    tag.Value = owner
                    tag.Parent = hum
                    hum.Health = 0
                end
            end
        end)

    elseif item.id == "BrainrotWalls" then
        local wallsModel = Instance.new("Model")
        wallsModel.Name = "BrainrotWalls"
        wallsModel.Parent = itemsFolder

        -- 1. Левая стена (X = -28)
        local wL = Instance.new("Part")
        wL.Size = Vector3.new(1, 14, 76)
        wL.CFrame = baseCF * CFrame.new(-28, 7, 0)
        wL.Anchored = true
        wL.Color = Color3.fromRGB(35, 35, 42)
        wL.Parent = wallsModel

        -- 2. Правая стена (X = +28)
        local wR = Instance.new("Part")
        wR.Size = Vector3.new(1, 14, 76)
        wR.CFrame = baseCF * CFrame.new(28, 7, 0)
        wR.Anchored = true
        wR.Color = Color3.fromRGB(35, 35, 42)
        wR.Parent = wallsModel

        -- 3. Задняя стена (Z = -38)
        local wB = Instance.new("Part")
        wB.Size = Vector3.new(56, 14, 1)
        wB.CFrame = baseCF * CFrame.new(0, 7, -38)
        wB.Anchored = true
        wB.Color = Color3.fromRGB(35, 35, 42)
        wB.Parent = wallsModel

        -- 4. Передний фасад слева от ворот (X = -28..-6, ширина 22, центр X=-17)
        local wFL = Instance.new("Part")
        wFL.Size = Vector3.new(22, 14, 1)
        wFL.CFrame = baseCF * CFrame.new(-17, 7, 36)
        wFL.Anchored = true
        wFL.Color = Color3.fromRGB(35, 35, 42)
        wFL.Parent = wallsModel

        -- 5. Передний фасад справа от ворот (X = 6..28, ширина 22, центр X=17)
        local wFR = Instance.new("Part")
        wFR.Size = Vector3.new(22, 14, 1)
        wFR.CFrame = baseCF * CFrame.new(17, 7, 36)
        wFR.Anchored = true
        wFR.Color = Color3.fromRGB(35, 35, 42)
        wFR.Parent = wallsModel

        -- Неоновые полосы по верху стен фракционного цвета на Y = 14
        for _, pos in ipairs({
            Vector3.new(-28, 14, 0),
            Vector3.new(28, 14, 0),
            Vector3.new(0, 14, -38),
            Vector3.new(-17, 14, 36),
            Vector3.new(17, 14, 36),
        }) do
            local neonStripe = Instance.new("Part")
            neonStripe.Size = if pos.Z == 0 then Vector3.new(1.2, 0.4, 76) elseif pos.Z == -38 then Vector3.new(56, 0.4, 1.2) else Vector3.new(22, 0.4, 1.2)
            neonStripe.CFrame = baseCF * CFrame.new(pos)
            neonStripe.Anchored = true
            neonStripe.CanCollide = false
            neonStripe.Material = Enum.Material.Neon
            neonStripe.Color = faction.color
            neonStripe.Parent = wallsModel
        end

    elseif item.id == "Upgrader_Laser" then
        -- Лазерный умножитель x2 на 1 этаже
        createUpgrader(
            itemsFolder,
            "Upgrader_Laser",
            baseCF * CFrame.new(0, 0, -4),
            7, 6, 2,
            Color3.fromRGB(241, 196, 15),
            "🔬 ЛАЗЕРНЫЙ УМНОЖИТЕЛЬ"
        )

    elseif item.id == "AbilityStand_1" then
        -- Стойка базовой способности [E] на 1 этаже
        createAbilityPedestal(
            itemsFolder,
            "AbilityStand_1",
            baseCF * CFrame.new(-16, 0, 8),
            faction.baseAbility.name,
            "ПРЕДМЕТ ИНВЕНТАРЯ [1] (E)",
            faction.color
        )

    elseif item.id == "Dropper_Prime" then
        local dropper = Instance.new("Part")
        dropper.Name = "Dropper_Prime"
        dropper.Size = Vector3.new(4, 2.5, 4)
        dropper.CFrame = baseCF * CFrame.new(0, 10, -12)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = Color3.fromRGB(52, 152, 219)
        dropper.Parent = itemsFolder

        createBillboard(dropper, "Дроппер Prime Energy", "+12 Aura / 1.4c", Color3.fromRGB(52, 152, 219))

        task.spawn(function()
            while dropper.Parent and owner.Parent do
                task.wait(1.4)
                spawnOre(dropper.CFrame * CFrame.new(0, -2.2, 0), 12, Color3.fromRGB(52, 152, 219), "Prime")
            end
        end)

    elseif item.id == "AbilityStand_Tactical" then
        -- Стойка тактической способности [R] на 1 этаже
        createAbilityPedestal(
            itemsFolder,
            "AbilityStand_Tactical",
            baseCF * CFrame.new(16, 0, 8),
            faction.tacticalAbility.name,
            "ПРЕДМЕТ ИНВЕНТАРЯ [2] (R)",
            faction.secondaryColor
        )

    elseif item.id == "Stairs_To_Floor2" then
        -- Лестница на 2-й этаж вдоль левой стены (от Z=24 до Z=-6, подъем на Y=14)
        local stairsModel = Instance.new("Model")
        stairsModel.Name = "Stairs_To_Floor2"
        stairsModel.Parent = itemsFolder

        local STEPS = 20
        local startZ = 24
        local endZ = -6
        local totalHeight = 14

        for i = 1, STEPS do
            local t = (i - 1) / (STEPS - 1)
            local curY = 0.5 + t * totalHeight
            local curZ = startZ - t * (startZ - endZ)

            local step = Instance.new("Part")
            step.Name = string.format("Step_%d", i)
            step.Size = Vector3.new(8, 0.7, 1.6)
            step.CFrame = baseCF * CFrame.new(-22, curY, curZ)
            step.Anchored = true
            step.Material = Enum.Material.SmoothPlastic
            step.Color = Color3.fromRGB(45, 45, 52)
            step.Parent = stairsModel
        end

        -- Перила лестницы
        local rail = Instance.new("Part")
        rail.Name = "StairRail"
        rail.Size = Vector3.new(0.4, 0.8, math.sqrt((startZ - endZ)^2 + totalHeight^2))
        local midY = 0.5 + totalHeight / 2 + 2.5
        local midZ = (startZ + endZ) / 2
        local angleX = math.atan2(totalHeight, startZ - endZ)
        rail.CFrame = baseCF * CFrame.new(-17.8, midY, midZ) * CFrame.Angles(-angleX, 0, 0)
        rail.Anchored = true
        rail.Material = Enum.Material.Neon
        rail.Color = faction.color
        rail.Parent = stairsModel

    elseif item.id == "Floor2_Foundation" then
        -- Полноценная платформа 2-го этажа на Y = 14 (лежит ровно на стенах 1 этажа 56x76)
        local f2Model = Instance.new("Model")
        f2Model.Name = "Floor2_Foundation"
        f2Model.Parent = itemsFolder

        -- 1. Основное перекрытие 2 этажа (X = -14..+28, Z = -38..+38)
        local mainFloor2 = Instance.new("Part")
        mainFloor2.Name = "Floor2_Main"
        mainFloor2.Size = Vector3.new(42, 1, 76)
        mainFloor2.CFrame = baseCF * CFrame.new(7, 14, 0)
        mainFloor2.Anchored = true
        mainFloor2.Color = Color3.fromRGB(30, 30, 36)
        mainFloor2.Material = Enum.Material.SmoothPlastic
        mainFloor2.Parent = f2Model

        -- 2. Задняя секция перекрытия слева от лестницы (X = -28..-14, Z = -38..-6)
        local backFloor2 = Instance.new("Part")
        backFloor2.Name = "Floor2_Back"
        backFloor2.Size = Vector3.new(14, 1, 32)
        backFloor2.CFrame = baseCF * CFrame.new(-21, 14, -22)
        backFloor2.Anchored = true
        backFloor2.Color = Color3.fromRGB(30, 30, 36)
        backFloor2.Material = Enum.Material.SmoothPlastic
        backFloor2.Parent = f2Model

        -- 3. Площадка выхода с лестницы (стык на Z = -6)
        local landing = Instance.new("Part")
        landing.Name = "StairLanding"
        landing.Size = Vector3.new(14, 1, 6)
        landing.CFrame = baseCF * CFrame.new(-21, 14, -6)
        landing.Anchored = true
        landing.Color = Color3.fromRGB(38, 38, 46)
        landing.Parent = f2Model

    elseif item.id == "Floor2_Walls" then
        -- Стены и защитные ограждения 2-го этажа (периметр 56x76, высота Y=14..24)
        local f2Walls = Instance.new("Model")
        f2Walls.Name = "Floor2_Walls"
        f2Walls.Parent = itemsFolder

        -- Задняя стена 2 этажа
        local rBack = Instance.new("Part")
        rBack.Size = Vector3.new(56, 10, 1)
        rBack.CFrame = baseCF * CFrame.new(0, 19, -38)
        rBack.Anchored = true
        rBack.Color = Color3.fromRGB(40, 40, 48)
        rBack.Parent = f2Walls

        -- Правая стена 2 этажа
        local rRight = Instance.new("Part")
        rRight.Size = Vector3.new(1, 10, 76)
        rRight.CFrame = baseCF * CFrame.new(28, 19, 0)
        rRight.Anchored = true
        rRight.Color = Color3.fromRGB(40, 40, 48)
        rRight.Parent = f2Walls

        -- Левая стена 2 этажа
        local rLeft = Instance.new("Part")
        rLeft.Size = Vector3.new(1, 10, 76)
        rLeft.CFrame = baseCF * CFrame.new(-28, 19, 0)
        rLeft.Anchored = true
        rLeft.Color = Color3.fromRGB(40, 40, 48)
        rLeft.Parent = f2Walls

        -- Переднее ограждение 2 этажа
        local rFront = Instance.new("Part")
        rFront.Size = Vector3.new(56, 10, 1)
        rFront.CFrame = baseCF * CFrame.new(0, 19, 36)
        rFront.Anchored = true
        rFront.Color = Color3.fromRGB(40, 40, 48)
        rFront.Parent = f2Walls

        -- Защитные перила вокруг лестничного проема
        local stairGuard = Instance.new("Part")
        stairGuard.Name = "StairGuard"
        stairGuard.Size = Vector3.new(0.4, 3.5, 32)
        stairGuard.CFrame = baseCF * CFrame.new(-14, 16.25, 10)
        stairGuard.Anchored = true
        stairGuard.Color = Color3.fromRGB(50, 50, 60)
        stairGuard.Parent = f2Walls

        -- Неоновый поручень на guard rail
        local guardNeon = Instance.new("Part")
        guardNeon.Size = Vector3.new(0.6, 0.3, 32)
        guardNeon.CFrame = baseCF * CFrame.new(-14, 18, 10)
        guardNeon.Anchored = true
        guardNeon.CanCollide = false
        guardNeon.Material = Enum.Material.Neon
        guardNeon.Color = faction.color
        guardNeon.Parent = f2Walls

        -- Неоновые полосы по верху стен 2 этажа на Y = 24
        for _, pos in ipairs({
            Vector3.new(-28, 24, 0),
            Vector3.new(28, 24, 0),
            Vector3.new(0, 24, -38),
            Vector3.new(0, 24, 36),
        }) do
            local neonStripe = Instance.new("Part")
            neonStripe.Size = if pos.Z == 0 then Vector3.new(1.2, 0.4, 76) else Vector3.new(56, 0.4, 1.2)
            neonStripe.CFrame = baseCF * CFrame.new(pos)
            neonStripe.Anchored = true
            neonStripe.CanCollide = false
            neonStripe.Material = Enum.Material.Neon
            neonStripe.Color = faction.color
            neonStripe.Parent = f2Walls
        end

    elseif item.id == "Floor2_Conveyor" then
        -- Верхний конвейер со сбросом руды в нижний приёмник
        local f2ConvModel = Instance.new("Model")
        f2ConvModel.Name = "Floor2_Conveyor"
        f2ConvModel.Parent = itemsFolder

        local topConv = Instance.new("Part")
        topConv.Name = "TopConveyor"
        topConv.Size = Vector3.new(5, 1, 32)
        topConv.CFrame = baseCF * CFrame.new(0, 14.5, -12)
        topConv.Anchored = true
        topConv.Material = Enum.Material.DiamondPlate
        topConv.Color = Color3.fromRGB(40, 40, 48)

        local forwardV = baseCF:VectorToWorldSpace(Vector3.new(0, 0, 1))
        topConv.AssemblyLinearVelocity = forwardV * 18
        topConv.Parent = f2ConvModel

        -- Направляющий желоб сброса (Chute)
        local chute = Instance.new("Part")
        chute.Name = "OreDropChute"
        chute.Size = Vector3.new(6, 12, 1)
        chute.CFrame = baseCF * CFrame.new(0, 8, 5) * CFrame.Angles(math.rad(18), 0, 0)
        chute.Anchored = true
        chute.Material = Enum.Material.SmoothPlastic
        chute.Color = Color3.fromRGB(30, 30, 35)
        chute.Parent = f2ConvModel

    elseif item.id == "Upgrader_Quantum" then
        -- Квантовый умножитель x3 на 2 этаже
        createUpgrader(
            itemsFolder,
            "Upgrader_Quantum",
            baseCF * CFrame.new(0, 14.5, -16),
            7, 6, 3,
            Color3.fromRGB(0, 220, 255),
            "🌌 КВАНТОВЫЙ УМНОЖИТЕЛЬ"
        )

    elseif item.id == "Dropper_Galactic" then
        local dropper = Instance.new("Part")
        dropper.Name = "Dropper_Galactic"
        dropper.Size = Vector3.new(4.5, 3, 4.5)
        dropper.CFrame = baseCF * CFrame.new(0, 22, -26)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = Color3.fromRGB(155, 89, 182)
        dropper.Parent = itemsFolder

        createBillboard(dropper, "⭐ Галактический Дроппер", "+60 Aura / 1.1c", Color3.fromRGB(155, 89, 182), Vector3.new(0, 3.5, 0), 28, false)

        task.spawn(function()
            while dropper.Parent and owner.Parent do
                task.wait(1.1)
                spawnOre(dropper.CFrame * CFrame.new(0, -2.5, 0), 60, Color3.fromRGB(155, 89, 182), "Galactic")
            end
        end)

    elseif item.id == "AbilityStand_Ultimate" then
        -- Стойка ультимейта [Q] на 2 этаже
        createAbilityPedestal(
            itemsFolder,
            "AbilityStand_Ultimate",
            baseCF * CFrame.new(18, 14, -14),
            faction.ultimateAbility.name,
            "👑 УЛЬТИМЕЙТ [3] (Q)",
            Color3.fromRGB(255, 215, 0)
        )

    elseif item.id == "Upgrader_Annihilator" then
        -- Аннигилятор Ауры x5 на 2 этаже
        createUpgrader(
            itemsFolder,
            "Upgrader_Annihilator",
            baseCF * CFrame.new(0, 14.5, -2),
            7, 6, 5,
            Color3.fromRGB(255, 40, 100),
            "🔥 АННИГИЛЯТОР АУРЫ"
        )

    elseif item.id == "Rebirth_Portal" then
        -- Алтарь Перерождения Rebirth на 2 этаже в отдельной золотой зоне
        local portalModel = Instance.new("Model")
        portalModel.Name = "Rebirth_Portal"
        portalModel.Parent = itemsFolder

        local postL = Instance.new("Part")
        postL.Size = Vector3.new(2, 10, 2)
        postL.CFrame = baseCF * CFrame.new(-6, 19.5, -28)
        postL.Anchored = true
        postL.Color = Color3.fromRGB(255, 215, 0)
        postL.Material = Enum.Material.Neon
        postL.Parent = portalModel

        local postR = Instance.new("Part")
        postR.Size = Vector3.new(2, 10, 2)
        postR.CFrame = baseCF * CFrame.new(6, 19.5, -28)
        postR.Anchored = true
        postR.Color = Color3.fromRGB(255, 215, 0)
        postR.Material = Enum.Material.Neon
        postR.Parent = portalModel

        local archTop = Instance.new("Part")
        archTop.Size = Vector3.new(14, 2, 2)
        archTop.CFrame = baseCF * CFrame.new(0, 25.5, -28)
        archTop.Anchored = true
        archTop.Color = Color3.fromRGB(255, 215, 0)
        archTop.Material = Enum.Material.Neon
        archTop.Parent = portalModel

        local field = Instance.new("Part")
        field.Name = "PortalField"
        field.Size = Vector3.new(10, 8.5, 0.8)
        field.CFrame = baseCF * CFrame.new(0, 19.5, -28)
        field.Anchored = true
        field.CanCollide = false
        field.Material = Enum.Material.ForceField
        field.Color = Color3.fromRGB(241, 196, 15)
        field.Transparency = 0.25
        field.Parent = portalModel

        local curRebirths = TycoonService.getRebirths(owner)
        local rTier = TycoonConfig.getRebirthTier(curRebirths + 1)
        local cost = if rTier then rTier.cost else (50000 + (curRebirths + 1) * 15000)
        local mult = if rTier then rTier.multiplier else 2.0
        local tierTitle = if rTier then rTier.name else "MAX TIER"

        createBillboard(
            field,
            string.format("👑 АЛТАРЬ REBIRTH [УРОВЕНЬ %d]", curRebirths + 1),
            string.format("Цена: %d Aura | Множитель: x%.1f\n👉 ВОЙДИ ВНУТРЬ ДЛЯ ПЕРЕРОЖДЕНИЯ", cost, mult),
            Color3.fromRGB(255, 215, 0),
            Vector3.new(0, 5.5, 0),
            35,
            false
        )

        local debounce = false
        field.Touched:Connect(function(hit)
            if debounce then return end
            local char = hit.Parent
            local p = Players:GetPlayerFromCharacter(char)
            if p == owner then
                debounce = true
                local success, reason = TycoonService.performRebirth(p)
                if success then
                    local pIndex = PlotManager.getPlayerPlotIndex(p)
                    if pIndex then
                        PlotBuilder.activatePlot(p, pIndex)
                    end
                else
                    warn(string.format("[PlotBuilder] Rebirth rejected: %s", reason or "Unknown"))
                end
                task.wait(2)
                debounce = false
            end
        end)

    elseif item.id == "FactionMonument" then
        -- 2. Мега-Монумент Фракции на крыше
        local monModel = Instance.new("Model")
        monModel.Name = "FactionMonument"
        monModel.Parent = itemsFolder

        local ped = Instance.new("Part")
        ped.Name = "MonumentPedestal"
        ped.Size = Vector3.new(14, 2, 14)
        ped.CFrame = baseCF * CFrame.new(0, 28, -6)
        ped.Anchored = true
        ped.Material = Enum.Material.DiamondPlate
        ped.Color = Color3.fromRGB(20, 20, 25)
        ped.Parent = monModel

        local beacon = Instance.new("Part")
        beacon.Name = "SkyBeacon"
        beacon.Size = Vector3.new(2.5, 400, 2.5)
        beacon.CFrame = baseCF * CFrame.new(0, 228, -6)
        beacon.Anchored = true
        beacon.CanCollide = false
        beacon.Material = Enum.Material.Neon
        beacon.Color = faction.color
        beacon.Transparency = 0.45
        beacon.Parent = monModel

        local fId = faction.id
        local centerCF = baseCF * CFrame.new(0, 31, -6)

        if fId == "Skibidi" then
            local bowl = Instance.new("Part")
            bowl.Size = Vector3.new(6, 4, 7)
            bowl.CFrame = centerCF
            bowl.Anchored = true
            bowl.Material = Enum.Material.Neon
            bowl.Color = Color3.fromRGB(241, 196, 15)
            bowl.Parent = monModel

            local tank = Instance.new("Part")
            tank.Size = Vector3.new(6, 6, 2.5)
            tank.CFrame = centerCF * CFrame.new(0, 3, -3)
            tank.Anchored = true
            tank.Material = Enum.Material.Neon
            tank.Color = Color3.fromRGB(255, 215, 0)
            tank.Parent = monModel

        elseif fId == "Mewing" then
            local head = Instance.new("Part")
            head.Size = Vector3.new(6, 8, 5)
            head.CFrame = centerCF
            head.Anchored = true
            head.Material = Enum.Material.Slate
            head.Color = Color3.fromRGB(120, 120, 130)
            head.Parent = monModel

            local jaw = Instance.new("Part")
            jaw.Size = Vector3.new(7.5, 3, 4)
            jaw.CFrame = centerCF * CFrame.new(0, -3.5, 1)
            jaw.Anchored = true
            jaw.Material = Enum.Material.Slate
            jaw.Color = Color3.fromRGB(150, 150, 160)
            jaw.Parent = monModel

            for _, eyeX in ipairs({ -1.5, 1.5 }) do
                local eye = Instance.new("Part")
                eye.Size = Vector3.new(0.8, 0.4, 0.4)
                eye.CFrame = centerCF * CFrame.new(eyeX, 1.5, 2.6)
                eye.Anchored = true
                eye.Material = Enum.Material.Neon
                eye.Color = Color3.fromRGB(0, 255, 255)
                eye.Parent = monModel
            end

        elseif fId == "Sigma" then
            local glassL = Instance.new("Part")
            glassL.Size = Vector3.new(4, 2.5, 0.6)
            glassL.CFrame = centerCF * CFrame.new(-2.5, 0, 0)
            glassL.Anchored = true
            glassL.Material = Enum.Material.Neon
            glassL.Color = Color3.fromRGB(142, 68, 173)
            glassL.Parent = monModel

            local glassR = Instance.new("Part")
            glassR.Size = Vector3.new(4, 2.5, 0.6)
            glassR.CFrame = centerCF * CFrame.new(2.5, 0, 0)
            glassR.Anchored = true
            glassR.Material = Enum.Material.Neon
            glassR.Color = Color3.fromRGB(142, 68, 173)
            glassR.Parent = monModel

        elseif fId == "FanumTax" then
            local patty = Instance.new("Part")
            patty.Size = Vector3.new(7, 2, 7)
            patty.CFrame = centerCF
            patty.Anchored = true
            patty.Color = Color3.fromRGB(100, 50, 20)
            patty.Parent = monModel

            local cheese = Instance.new("Part")
            cheese.Size = Vector3.new(7.2, 0.5, 7.2)
            cheese.CFrame = centerCF * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(45), 0)
            cheese.Anchored = true
            cheese.Material = Enum.Material.Neon
            cheese.Color = Color3.fromRGB(241, 196, 15)
            cheese.Parent = monModel

        elseif fId == "Grimace" then
            local cup = Instance.new("Part")
            cup.Size = Vector3.new(5, 7, 5)
            cup.CFrame = centerCF
            cup.Anchored = true
            cup.Material = Enum.Material.Neon
            cup.Color = Color3.fromRGB(155, 89, 182)
            cup.Parent = monModel

        elseif fId == "CaseOh" then
            local hole = Instance.new("Part")
            hole.Shape = Enum.PartType.Ball
            hole.Size = Vector3.new(5, 5, 5)
            hole.CFrame = centerCF
            hole.Anchored = true
            hole.Color = Color3.fromRGB(10, 10, 15)
            hole.Parent = monModel

            local ring = Instance.new("Part")
            ring.Size = Vector3.new(10, 0.4, 10)
            ring.CFrame = centerCF * CFrame.Angles(math.rad(25), 0, math.rad(15))
            ring.Anchored = true
            ring.Material = Enum.Material.Neon
            ring.Color = Color3.fromRGB(0, 220, 255)
            ring.Parent = monModel

        elseif fId == "Rizzler" then
            local heartL = Instance.new("Part")
            heartL.Size = Vector3.new(4, 5, 2.5)
            heartL.CFrame = centerCF * CFrame.new(-1.6, 1, 0) * CFrame.Angles(0, 0, math.rad(28))
            heartL.Anchored = true
            heartL.Material = Enum.Material.Neon
            heartL.Color = Color3.fromRGB(231, 76, 60)
            heartL.Parent = monModel

            local heartR = Instance.new("Part")
            heartR.Size = Vector3.new(4, 5, 2.5)
            heartR.CFrame = centerCF * CFrame.new(1.6, 1, 0) * CFrame.Angles(0, 0, math.rad(-28))
            heartR.Anchored = true
            heartR.Material = Enum.Material.Neon
            heartR.Color = Color3.fromRGB(231, 76, 60)
            heartR.Parent = monModel

        elseif fId == "TungTung" then
            local anvil = Instance.new("Part")
            anvil.Size = Vector3.new(5, 3.5, 3)
            anvil.CFrame = centerCF * CFrame.new(0, -2, 0)
            anvil.Anchored = true
            anvil.Material = Enum.Material.DiamondPlate
            anvil.Color = Color3.fromRGB(60, 60, 70)
            anvil.Parent = monModel

            local hammerHead = Instance.new("Part")
            hammerHead.Size = Vector3.new(6.5, 3, 3)
            hammerHead.CFrame = centerCF * CFrame.new(0, 2.5, 0)
            hammerHead.Anchored = true
            hammerHead.Material = Enum.Material.Neon
            hammerHead.Color = Color3.fromRGB(39, 174, 96)
            hammerHead.Parent = monModel
        end

        createBillboard(ped, string.format("⭐ МОНУМЕНТ: %s", faction.name), "СИЛА ФРАКЦИИ АЛЬФА", faction.color, Vector3.new(0, 12, 0))
    end
end

-- Позиции кнопок покупки для всех предметов (просторная расстановка без наслоений)
local BUTTON_CONFIGS: { [string]: Vector3 } = {
    LaserGate = Vector3.new(-8, 0.5, 30),
    BrainrotWalls = Vector3.new(8, 0.5, 30),
    Upgrader_Laser = Vector3.new(-10, 0.5, 6),
    AbilityStand_1 = Vector3.new(-18, 0.5, -12),
    Dropper_Prime = Vector3.new(18, 0.5, -18),
    AbilityStand_Tactical = Vector3.new(18, 0.5, 8),
    Stairs_To_Floor2 = Vector3.new(-10, 0.5, 20),
    Floor2_Foundation = Vector3.new(-10, 0.5, 26), -- Свободная зона перед лестницей (НЕ под ней!)
    Floor2_Walls = Vector3.new(20, 14.5, 14),
    Floor2_Conveyor = Vector3.new(0, 14.5, 10),
    Upgrader_Quantum = Vector3.new(-10, 14.5, -4),
    Dropper_Galactic = Vector3.new(14, 14.5, -20),
    AbilityStand_Ultimate = Vector3.new(18, 14.5, -6),
    Upgrader_Annihilator = Vector3.new(10, 14.5, 4),
    Rebirth_Portal = Vector3.new(-10, 14.5, 18),
    FactionMonument = Vector3.new(10, 14.5, 18),
}

local function buildButtonsForPlot(plotModel: Model, owner: Player, plotIndex: number, baseCF: CFrame, faction: TycoonConfig.Faction)
    local buttonsFolder = plotModel:FindFirstChild("Buttons") :: Folder?
    if not buttonsFolder then
        buttonsFolder = Instance.new("Folder")
        buttonsFolder.Name = "Buttons"
        buttonsFolder.Parent = plotModel
    end
    buttonsFolder:ClearAllChildren()

    local count = 0
    for _, item in ipairs(TycoonConfig.ITEMS) do
        if item.category == "Collector" or item.id == "FactionDropper" then
            continue
        end

        if TycoonService.hasItem(owner, item.id) then
            continue
        end

        if item.dependsOn and item.dependsOn ~= "Collector" and item.dependsOn ~= "FactionDropper" then
            if not TycoonService.hasItem(owner, item.dependsOn) then
                continue
            end
        end

        count += 1
        local pos = BUTTON_CONFIGS[item.id] or Vector3.new(0, 0.5, 0)
        local btnPart = Instance.new("Part")
        btnPart.Name = "Button_" .. item.id
        btnPart.Size = Vector3.new(4.5, 0.4, 4.5)
        btnPart.CFrame = baseCF * CFrame.new(pos)
        btnPart.Anchored = true
        btnPart.Material = Enum.Material.Neon
        btnPart.Color = Color3.fromRGB(46, 204, 113)
        btnPart.Parent = buttonsFolder

        local subTxt = string.format("Цена: %d AURA", item.cost)
        createBillboard(btnPart, item.name, subTxt, Color3.fromRGB(46, 204, 113), Vector3.new(0, 3.2, 0), 28, false)

        local debounce = false
        btnPart.Touched:Connect(function(hit)
            if debounce then return end
            local char = hit.Parent
            local p = Players:GetPlayerFromCharacter(char)
            if p == owner then
                debounce = true
                local success = TycoonService.purchaseItem(p, item.id)
                if success then
                    spawnStructure(plotModel, owner, item, baseCF, faction)
                    buildButtonsForPlot(plotModel, owner, plotIndex, baseCF, faction)
                end
                task.wait(0.5)
                debounce = false
            end
        end)
    end
    print(string.format("[PlotBuilder] Base %d: Created %d available buttons for %s", plotIndex, count, owner.Name))
end

-- Инициализация пустых баз при старте сервера
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

        -- Основание базы 56 x 76 стадов (просторное основание)
        local baseFloor = Instance.new("Part")
        baseFloor.Name = "BaseFloor"
        baseFloor.Size = Vector3.new(56, 1, 76)
        baseFloor.CFrame = baseCF * CFrame.new(0, 0, 0)
        baseFloor.Anchored = true
        baseFloor.Material = Enum.Material.SmoothPlastic
        baseFloor.Color = Color3.fromRGB(22, 22, 26)
        baseFloor.Parent = plotModel

        local sign = Instance.new("Part")
        sign.Name = "OwnerSign"
        sign.Size = Vector3.new(24, 4, 1)
        sign.CFrame = baseCF * CFrame.new(0, 11, -37)
        sign.Anchored = true
        sign.Material = Enum.Material.Neon
        sign.Color = faction.color
        sign.Parent = plotModel
        createBillboard(sign, faction.name, "[СВОБОДНО] Встань на площадку у входа!", Color3.fromRGB(255, 255, 255), Vector3.new(0, 3.5, 0), 45, false)

        -- Площадка выбора/захвата базы
        local claimPad = Instance.new("Part")
        claimPad.Name = "ClaimPad"
        claimPad.Size = Vector3.new(12, 0.4, 10)
        claimPad.CFrame = baseCF * CFrame.new(0, 0.4, 28)
        claimPad.Anchored = true
        claimPad.Material = Enum.Material.Neon
        claimPad.Color = faction.color
        claimPad.Parent = plotModel

        createBillboard(claimPad, string.format("👉 ЗАХВАТИТЬ: %s", faction.name), "Встань сюда, чтобы выбрать эту базу!", faction.color, Vector3.new(0, 3.5, 0), 40, false)

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
    print("[PlotBuilder] All 8 circular bases created with expanded 56x76 footprint!")
end

-- Активация базы за игроком
function PlotBuilder.activatePlot(player: Player, plotIndex: number)
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if not plotsContainer then return end
    local plotModel = plotsContainer:FindFirstChild(string.format("Base_%d", plotIndex)) :: Model?
    if not plotModel then return end

    local plotData = PlotManager.getPlotData(plotIndex)
    if not plotData then return end
    local baseCF = plotData.cframe
    local faction = plotData.faction

    -- Убираем ClaimPad
    local claimPad = plotModel:FindFirstChild("ClaimPad")
    if claimPad then claimPad:Destroy() end

    -- Обновляем вывеску владельца
    local sign = plotModel:FindFirstChild("OwnerSign") :: Part?
    if sign then
        local gui = sign:FindFirstChild("InfoGui")
        if gui then gui:Destroy() end
        createBillboard(sign, string.format("БАЗА: %s", player.Name), faction.name, faction.color, Vector3.new(0, 3.5, 0), 50, false)
    end

    local itemsFolder = plotModel:FindFirstChild("PurchasedItems") :: Folder
    if itemsFolder then itemsFolder:ClearAllChildren() end

    -- 1. Сборщик и Сейф (Collector + Vault)
    local collector = Instance.new("Part")
    collector.Name = "Collector"
    collector.Size = Vector3.new(8, 3.5, 6)
    collector.CFrame = baseCF * CFrame.new(0, 1.75, 14)
    collector.Anchored = true
    collector.Material = Enum.Material.Neon
    collector.Color = Color3.fromRGB(46, 204, 113)
    collector.Parent = itemsFolder

    -- Площадка снятия денег из сейфа (WithdrawPad)
    local withdrawPad = Instance.new("Part")
    withdrawPad.Name = "WithdrawPad"
    withdrawPad.Size = Vector3.new(8, 0.4, 6)
    withdrawPad.CFrame = baseCF * CFrame.new(0, 0.4, 20)
    withdrawPad.Anchored = true
    withdrawPad.Material = Enum.Material.Neon
    withdrawPad.Color = Color3.fromRGB(241, 196, 15)
    withdrawPad.Parent = itemsFolder

    local vLabel = createBillboard(
        withdrawPad,
        "💸 В СЕЙФЕ: +0 AURA",
        "[ВСТАНЬ, ЧТОБЫ ЗАБРАТЬ В КОШЕЛЕК]",
        Color3.fromRGB(255, 215, 0),
        Vector3.new(0, 4, 0),
        32,
        false
    )
    vaultLabels[plotIndex] = vLabel

    -- Снятие денег при касании владельца
    local withDebounce = false
    withdrawPad.Touched:Connect(function(hit)
        if withDebounce then return end
        local char = hit.Parent
        local p = Players:GetPlayerFromCharacter(char)
        if p == player then
            withDebounce = true
            local amount = TycoonService.withdrawVault(player, plotIndex)
            if amount > 0 then
                vLabel.Text = "💸 В СЕЙФЕ: +0 AURA\n[ВСТАНЬ, ЧТОБЫ ЗАБРАТЬ В КОШЕЛЕК]"
            end
            task.wait(0.6)
            withDebounce = false
        end
    end)

    -- Поглощение руды в сейф Сборщика
    collector.Touched:Connect(function(hit)
        if hit.Name == "Ore" and not hit:GetAttribute("Collected") then
            hit:SetAttribute("Collected", true)
            local val = hit:GetAttribute("Value") or 1
            hit:Destroy()

            local newTotal = TycoonService.addToVault(plotIndex, val, player)
            vLabel.Text = string.format("💸 В СЕЙФЕ: +%d AURA\n[ВСТАНЬ, ЧТОБЫ ЗАБРАТЬ В КОШЕЛЕК]", newTotal)
        end
    end)

    -- 2. Нижний конвейер 1-го этажа
    local conveyor = Instance.new("Part")
    conveyor.Name = "MainConveyor"
    conveyor.Size = Vector3.new(5, 1, 34)
    conveyor.CFrame = baseCF * CFrame.new(0, 0.5, -5)
    conveyor.Anchored = true
    conveyor.Material = Enum.Material.DiamondPlate
    conveyor.Color = Color3.fromRGB(35, 35, 40)

    local forwardVector = baseCF:VectorToWorldSpace(Vector3.new(0, 0, 1))
    local speed = TycoonConfig.CONVEYOR_SPEED
    conveyor.AssemblyLinearVelocity = forwardVector * speed
    conveyor.Parent = itemsFolder

    -- Стоппер сзади
    local backstop = Instance.new("Part")
    backstop.Name = "ConveyorBackstop"
    backstop.Size = Vector3.new(5.5, 3, 0.6)
    backstop.CFrame = baseCF * CFrame.new(0, 2, -22.3)
    backstop.Anchored = true
    backstop.Color = Color3.fromRGB(20, 20, 20)
    backstop.Parent = itemsFolder

    -- Боковые бортики конвейера
    local borderLeft = Instance.new("Part")
    borderLeft.Name = "BorderLeft"
    borderLeft.Size = Vector3.new(0.4, 1.8, 34)
    borderLeft.CFrame = baseCF * CFrame.new(-2.7, 1.4, -5)
    borderLeft.Anchored = true
    borderLeft.Color = Color3.fromRGB(25, 25, 30)
    borderLeft.Parent = itemsFolder

    local borderRight = Instance.new("Part")
    borderRight.Name = "BorderRight"
    borderRight.Size = Vector3.new(0.4, 1.8, 34)
    borderRight.CFrame = baseCF * CFrame.new(2.7, 1.4, -5)
    borderRight.Anchored = true
    borderRight.Color = Color3.fromRGB(25, 25, 30)
    borderRight.Parent = itemsFolder

    -- Стартовый дроппер фракции
    local fDropItem = TycoonConfig.getItemById("FactionDropper")
    if fDropItem then
        spawnStructure(plotModel, player, fDropItem, baseCF, faction)
    end

    -- Постройка уже купленных предметов (при переподключении)
    local owned = TycoonService.getOwnedItems(player)
    for itemId, _ in pairs(owned) do
        local itm = TycoonConfig.getItemById(itemId)
        if itm then
            spawnStructure(plotModel, player, itm, baseCF, faction)
        end
    end

    -- Кнопки покупки
    buildButtonsForPlot(plotModel, player, plotIndex, baseCF, faction)
    print(string.format("[PlotBuilder] Base %d activated for %s", plotIndex, player.Name))
end

-- Сброс базы в свободное состояние
function PlotBuilder.resetPlotToUnclaimed(plotIndex: number, onClaimCallback: (player: Player, plotIndex: number) -> ())
    local plotsContainer = Workspace:FindFirstChild("TycoonPlots")
    if not plotsContainer then return end
    local plotModel = plotsContainer:FindFirstChild(string.format("Base_%d", plotIndex)) :: Model?
    if not plotModel then return end

    local plotData = PlotManager.getPlotData(plotIndex)
    if not plotData then return end
    local baseCF = plotData.cframe
    local faction = plotData.faction

    local purchased = plotModel:FindFirstChild("PurchasedItems") :: Folder?
    if purchased then purchased:ClearAllChildren() end

    local buttons = plotModel:FindFirstChild("Buttons") :: Folder?
    if buttons then buttons:ClearAllChildren() end

    vaultLabels[plotIndex] = nil

    local sign = plotModel:FindFirstChild("OwnerSign") :: Part?
    if sign then
        local gui = sign:FindFirstChild("InfoGui")
        if gui then gui:Destroy() end
        createBillboard(sign, faction.name, "[СВОБОДНО] Встань на площадку у входа!", Color3.fromRGB(255, 255, 255))
    end

    local existingPad = plotModel:FindFirstChild("ClaimPad")
    if not existingPad then
        local claimPad = Instance.new("Part")
        claimPad.Name = "ClaimPad"
        claimPad.Size = Vector3.new(10, 0.4, 10)
        claimPad.CFrame = baseCF * CFrame.new(0, 0.4, 24)
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
