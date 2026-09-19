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

local function createBillboard(parent: Instance, title: string, subtitle: string, textColor: Color3, offset: Vector3?)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "InfoGui"
    billboard.Size = UDim2.new(0, 240, 0, 70)
    billboard.StudsOffset = offset or Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 120
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
        postL.Size = Vector3.new(1.5, 12, 1.5)
        postL.CFrame = baseCF * CFrame.new(-6, 6, 30)
        postL.Anchored = true
        postL.Color = Color3.fromRGB(25, 25, 30)
        postL.Parent = gateModel

        local postR = Instance.new("Part")
        postR.Size = Vector3.new(1.5, 12, 1.5)
        postR.CFrame = baseCF * CFrame.new(6, 6, 30)
        postR.Anchored = true
        postR.Color = Color3.fromRGB(25, 25, 30)
        postR.Parent = gateModel

        local lintel = Instance.new("Part")
        lintel.Name = "GateLintel"
        lintel.Size = Vector3.new(13.5, 1.5, 1.5)
        lintel.CFrame = baseCF * CFrame.new(0, 11.25, 30)
        lintel.Anchored = true
        lintel.Color = Color3.fromRGB(25, 25, 30)
        lintel.Parent = gateModel

        local beam = Instance.new("Part")
        beam.Name = "LaserBeam"
        beam.Size = Vector3.new(10.5, 10.5, 0.4)
        beam.CFrame = baseCF * CFrame.new(0, 5.25, 30)
        beam.Anchored = true
        beam.CanCollide = false
        beam.Material = Enum.Material.ForceField
        beam.Color = Color3.fromRGB(231, 76, 60)
        beam.Transparency = 0.35
        beam.Parent = gateModel

        createBillboard(beam, "⚡ ЗАЩИТНЫЙ ЛАЗЕР", "Вход только для владельца!", Color3.fromRGB(231, 76, 60))

        beam.Touched:Connect(function(hit)
            local char = hit.Parent
            if not char then return end
            if char:IsA("Accessory") then char = char.Parent end
            local player = Players:GetPlayerFromCharacter(char)
            if player and player ~= owner then
                local hum = char:FindFirstChild("Humanoid") :: Humanoid?
                if hum and hum.Health > 0 then
                    -- Помечаем тегом создателя для лута
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

        -- 1. Левая стена (X = -24)
        local wL = Instance.new("Part")
        wL.Size = Vector3.new(1, 12, 64)
        wL.CFrame = baseCF * CFrame.new(-24, 6, 0)
        wL.Anchored = true
        wL.Color = Color3.fromRGB(35, 35, 42)
        wL.Parent = wallsModel

        -- 2. Правая стена (X = +24)
        local wR = Instance.new("Part")
        wR.Size = Vector3.new(1, 12, 64)
        wR.CFrame = baseCF * CFrame.new(24, 6, 0)
        wR.Anchored = true
        wR.Color = Color3.fromRGB(35, 35, 42)
        wR.Parent = wallsModel

        -- 3. Задняя стена (Z = -32)
        local wB = Instance.new("Part")
        wB.Size = Vector3.new(48, 12, 1)
        wB.CFrame = baseCF * CFrame.new(0, 6, -32)
        wB.Anchored = true
        wB.Color = Color3.fromRGB(35, 35, 42)
        wB.Parent = wallsModel

        -- 4. Передний фасад слева от ворот (X = -24..-6, ширина 18, центр X=-15)
        local wFL = Instance.new("Part")
        wFL.Size = Vector3.new(18, 12, 1)
        wFL.CFrame = baseCF * CFrame.new(-15, 6, 30)
        wFL.Anchored = true
        wFL.Color = Color3.fromRGB(35, 35, 42)
        wFL.Parent = wallsModel

        -- 5. Передний фасад справа от ворот (X = 6..24, ширина 18, центр X=15)
        local wFR = Instance.new("Part")
        wFR.Size = Vector3.new(18, 12, 1)
        wFR.CFrame = baseCF * CFrame.new(15, 6, 30)
        wFR.Anchored = true
        wFR.Color = Color3.fromRGB(35, 35, 42)
        wFR.Parent = wallsModel

        -- Неоновые полосы по верху стен фракционного цвета
        for _, pos in ipairs({
            Vector3.new(-24, 12, 0),
            Vector3.new(24, 12, 0),
            Vector3.new(0, 12, -32),
            Vector3.new(-15, 12, 30),
            Vector3.new(15, 12, 30),
        }) do
            local neonStripe = Instance.new("Part")
            neonStripe.Size = if pos.Z == 0 then Vector3.new(1.2, 0.4, 64) elseif pos.Z == -32 then Vector3.new(48, 0.4, 1.2) else Vector3.new(18, 0.4, 1.2)
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
        -- Лестница на 2-й этаж вдоль левой стены (от Z=16 до Z=-6, подъем на Y=16)
        local stairsModel = Instance.new("Model")
        stairsModel.Name = "Stairs_To_Floor2"
        stairsModel.Parent = itemsFolder

        local STEPS = 20
        local startZ = 16
        local endZ = -6
        local totalHeight = 16

        for i = 1, STEPS do
            local t = (i - 1) / (STEPS - 1)
            local curY = 0.5 + t * totalHeight
            local curZ = startZ - t * (startZ - endZ)

            local step = Instance.new("Part")
            step.Name = string.format("Step_%d", i)
            step.Size = Vector3.new(7, 0.8, 1.3)
            step.CFrame = baseCF * CFrame.new(-18, curY, curZ)
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
        rail.CFrame = baseCF * CFrame.new(-14.3, midY, midZ) * CFrame.Angles(-angleX, 0, 0)
        rail.Anchored = true
        rail.Material = Enum.Material.Neon
        rail.Color = faction.color
        rail.Parent = stairsModel

    elseif item.id == "Floor2_Foundation" then
        -- Платформа 2-го этажа на Y = 16
        local f2Model = Instance.new("Model")
        f2Model.Name = "Floor2_Foundation"
        f2Model.Parent = itemsFolder

        -- Основной пол 2 этажа (с вырезом под лестницу слева и шахту сброса спереди)
        local mainFloor2 = Instance.new("Part")
        mainFloor2.Name = "Floor2_Main"
        mainFloor2.Size = Vector3.new(34, 1, 44)
        mainFloor2.CFrame = baseCF * CFrame.new(5, 16, -10)
        mainFloor2.Anchored = true
        mainFloor2.Color = Color3.fromRGB(30, 30, 36)
        mainFloor2.Material = Enum.Material.SmoothPlastic
        mainFloor2.Parent = f2Model

        -- Площадка выхода с лестницы
        local landing = Instance.new("Part")
        landing.Name = "StairLanding"
        landing.Size = Vector3.new(12, 1, 14)
        landing.CFrame = baseCF * CFrame.new(-18, 16, -10)
        landing.Anchored = true
        landing.Color = Color3.fromRGB(30, 30, 36)
        landing.Parent = f2Model

    elseif item.id == "Floor2_Walls" then
        -- Неоновые ограждения периметра 2-го этажа
        local f2Walls = Instance.new("Model")
        f2Walls.Name = "Floor2_Walls"
        f2Walls.Parent = itemsFolder

        local rBack = Instance.new("Part")
        rBack.Size = Vector3.new(48, 4, 1)
        rBack.CFrame = baseCF * CFrame.new(0, 18.5, -32)
        rBack.Anchored = true
        rBack.Color = Color3.fromRGB(40, 40, 48)
        rBack.Parent = f2Walls

        local rRight = Instance.new("Part")
        rRight.Size = Vector3.new(1, 4, 44)
        rRight.CFrame = baseCF * CFrame.new(24, 18.5, -10)
        rRight.Anchored = true
        rRight.Color = Color3.fromRGB(40, 40, 48)
        rRight.Parent = f2Walls

        local rFront = Instance.new("Part")
        rFront.Size = Vector3.new(40, 4, 1)
        rFront.CFrame = baseCF * CFrame.new(4, 18.5, 12)
        rFront.Anchored = true
        rFront.Color = Color3.fromRGB(40, 40, 48)
        rFront.Parent = f2Walls

    elseif item.id == "Floor2_Conveyor" then
        -- Верхний конвейер со сбросом руды в нижний приёмник
        local f2ConvModel = Instance.new("Model")
        f2ConvModel.Name = "Floor2_Conveyor"
        f2ConvModel.Parent = itemsFolder

        local topConv = Instance.new("Part")
        topConv.Name = "TopConveyor"
        topConv.Size = Vector3.new(5, 1, 32)
        topConv.CFrame = baseCF * CFrame.new(0, 16.5, -6)
        topConv.Anchored = true
        topConv.Material = Enum.Material.DiamondPlate
        topConv.Color = Color3.fromRGB(40, 40, 48)

        local forwardV = baseCF:VectorToWorldSpace(Vector3.new(0, 0, 1))
        topConv.AssemblyLinearVelocity = forwardV * 18
        topConv.Parent = f2ConvModel

        -- Направляющий желоб сброса (Chute)
        local chute = Instance.new("Part")
        chute.Name = "OreDropChute"
        chute.Size = Vector3.new(6, 14, 1)
        chute.CFrame = baseCF * CFrame.new(0, 9, 11) * CFrame.Angles(math.rad(15), 0, 0)
        chute.Anchored = true
        chute.Material = Enum.Material.SmoothPlastic
        chute.Color = Color3.fromRGB(30, 30, 35)
        chute.Parent = f2ConvModel

    elseif item.id == "Upgrader_Quantum" then
        -- Квантовый умножитель x3 на 2 этаже
        createUpgrader(
            itemsFolder,
            "Upgrader_Quantum",
            baseCF * CFrame.new(0, 17, -10),
            7, 6, 3,
            Color3.fromRGB(0, 220, 255),
            "🌌 КВАНТОВЫЙ УМНОЖИТЕЛЬ"
        )

    elseif item.id == "Dropper_Galactic" then
        local dropper = Instance.new("Part")
        dropper.Name = "Dropper_Galactic"
        dropper.Size = Vector3.new(4.5, 3, 4.5)
        dropper.CFrame = baseCF * CFrame.new(0, 24, -20)
        dropper.Anchored = true
        dropper.Material = Enum.Material.Neon
        dropper.Color = Color3.fromRGB(155, 89, 182)
        dropper.Parent = itemsFolder

        createBillboard(dropper, "⭐ Галактический Дроппер", "+60 Aura / 1.1c", Color3.fromRGB(155, 89, 182))

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
            baseCF * CFrame.new(16, 16, -16),
            faction.ultimateAbility.name,
            "👑 УЛЬТИМЕЙТ [3] (Q)",
            Color3.fromRGB(255, 215, 0)
        )

    elseif item.id == "Upgrader_Annihilator" then
        -- Аннигилятор Ауры x5 на 2 этаже
        createUpgrader(
            itemsFolder,
            "Upgrader_Annihilator",
            baseCF * CFrame.new(0, 17, 4),
            7, 6, 5,
            Color3.fromRGB(255, 40, 100),
            "🔥 АННИГИЛЯТОР АУРЫ"
        )
    end
end

-- Позиции кнопок покупки для всех предметов
local BUTTON_CONFIGS: { [string]: Vector3 } = {
    LaserGate = Vector3.new(-8, 0.5, 26),
    BrainrotWalls = Vector3.new(8, 0.5, 26),
    Upgrader_Laser = Vector3.new(-8, 0.5, 0),
    AbilityStand_1 = Vector3.new(-16, 0.5, 2),
    Dropper_Prime = Vector3.new(8, 0.5, -12),
    AbilityStand_Tactical = Vector3.new(16, 0.5, 2),
    Stairs_To_Floor2 = Vector3.new(-18, 0.5, 20),
    Floor2_Foundation = Vector3.new(-18, 16.5, -6),
    Floor2_Walls = Vector3.new(16, 16.5, 6),
    Floor2_Conveyor = Vector3.new(0, 16.5, 8),
    Upgrader_Quantum = Vector3.new(-8, 16.5, -10),
    Dropper_Galactic = Vector3.new(8, 16.5, -20),
    AbilityStand_Ultimate = Vector3.new(16, 16.5, -10),
    Upgrader_Annihilator = Vector3.new(8, 16.5, 4),
}

local function buildButtonsForPlot(plotModel: Model, owner: Player, plotIndex: number, baseCF: CFrame, faction: TycoonConfig.Faction)
    local buttonsFolder = plotModel:FindFirstChild("Buttons") :: Folder
    if not buttonsFolder then return end
    buttonsFolder:ClearAllChildren()

    for _, item in ipairs(TycoonConfig.ITEMS) do
        if item.category == "Collector" or item.id == "FactionDropper" then
            continue
        end

        if TycoonService.hasItem(owner, item.id) then
            continue
        end

        if item.dependsOn and not TycoonService.hasItem(owner, item.dependsOn) then
            continue
        end

        local pos = BUTTON_CONFIGS[item.id] or Vector3.new(0, 0.5, 0)
        local btnPart = Instance.new("Part")
        btnPart.Name = "Button_" .. item.id
        btnPart.Size = Vector3.new(4, 0.4, 4)
        btnPart.CFrame = baseCF * CFrame.new(pos)
        btnPart.Anchored = true
        btnPart.Material = Enum.Material.Neon
        btnPart.Color = Color3.fromRGB(46, 204, 113)
        btnPart.Parent = buttonsFolder

        local subTxt = string.format("Цена: %d AURA", item.cost)
        createBillboard(btnPart, item.name, subTxt, Color3.fromRGB(46, 204, 113))

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

        -- Основание базы 48 x 64 стада
        local baseFloor = Instance.new("Part")
        baseFloor.Name = "BaseFloor"
        baseFloor.Size = Vector3.new(48, 1, 64)
        baseFloor.CFrame = baseCF * CFrame.new(0, 0, 0)
        baseFloor.Anchored = true
        baseFloor.Material = Enum.Material.SmoothPlastic
        baseFloor.Color = Color3.fromRGB(22, 22, 26)
        baseFloor.Parent = plotModel

        local sign = Instance.new("Part")
        sign.Name = "OwnerSign"
        sign.Size = Vector3.new(20, 4, 1)
        sign.CFrame = baseCF * CFrame.new(0, 10, -31)
        sign.Anchored = true
        sign.Material = Enum.Material.Neon
        sign.Color = faction.color
        sign.Parent = plotModel
        createBillboard(sign, faction.name, "[СВОБОДНО] Встань на площадку у входа!", Color3.fromRGB(255, 255, 255))

        -- Площадка выбора/захвата базы
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
    print("[PlotBuilder] All 8 circular bases created with expanded 48x64 footprint!")
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
        createBillboard(sign, string.format("БАЗА: %s", player.Name), faction.name, faction.color)
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
        Vector3.new(0, 4, 0)
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
