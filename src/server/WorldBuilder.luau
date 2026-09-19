--!strict

--[=[
    WorldBuilder
    Создаёт острову карту: центральный пьедестал, дороги от центра к каждой базе,
    окружающий океан, ограждения по краям. Даёт игроку ощущение закрытого острова
    с выразительной Gen Alpha Brainrot эстетикой.
]=]

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))

local WorldBuilder = {}

local ISLAND_RADIUS = TycoonConfig.ARENA_RADIUS + 70 -- достаточно места для баз 48x64
local BASE_RADIUS = TycoonConfig.ARENA_RADIUS
local ROAD_WIDTH = 10
local GROUND_Y = 3 -- уровень земли острова (верхняя поверхность IslandBase)

local function makeAnchoredPart(
    parent: Instance,
    name: string,
    size: Vector3,
    cf: CFrame,
    color: Color3,
    material: Enum.Material,
    transparency: number?
): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.CanCollide = true
    p.Material = material
    p.Color = color
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    if transparency then p.Transparency = transparency end
    p.Parent = parent
    return p
end

function WorldBuilder.buildWorld()
    local worldFolder = Instance.new("Folder")
    worldFolder.Name = "WorldMap"
    worldFolder.Parent = Workspace

    -- 1. Основной остров
    -- IslandBase: center at GROUND_Y-2, height=4, so top surface at GROUND_Y
    local islandBase = makeAnchoredPart(
        worldFolder,
        "IslandBase",
        Vector3.new(ISLAND_RADIUS * 2, 4, ISLAND_RADIUS * 2),
        CFrame.new(0, GROUND_Y - 2, 0),
        Color3.fromRGB(55, 130, 60),
        Enum.Material.Grass
    )

    -- 2. Центральная площадь
    local centerPlaza = makeAnchoredPart(
        worldFolder,
        "CenterPlaza",
        Vector3.new(40, 1, 40),
        CFrame.new(0, GROUND_Y + 0.5, 0),
        Color3.fromRGB(55, 55, 65),
        Enum.Material.Concrete
    )

    -- Неоновое кольцо по краю площади
    local plazaRing = Instance.new("Part")
    plazaRing.Name = "PlazaRing"
    plazaRing.Shape = Enum.PartType.Cylinder
    plazaRing.Size = Vector3.new(1, 40, 40)
    plazaRing.CFrame = CFrame.new(0, GROUND_Y + 1, 0) * CFrame.Angles(0, 0, math.rad(90))
    plazaRing.Anchored = true
    plazaRing.CanCollide = false
    plazaRing.Material = Enum.Material.Neon
    plazaRing.Color = Color3.fromRGB(241, 196, 15)
    plazaRing.Transparency = 0.5
    plazaRing.Parent = worldFolder

    -- 3. Дороги от центра к каждой базе (8 дорожек)
    local total = TycoonConfig.TOTAL_PLOTS
    for i = 1, total do
        local angle = (i - 1) * (2 * math.pi / total)
        local roadLength = BASE_RADIUS - 20

        local midX = (BASE_RADIUS / 2) * math.cos(angle)
        local midZ = (BASE_RADIUS / 2) * math.sin(angle)

        local roadCF = CFrame.new(
            midX, GROUND_Y + 0.3, midZ,
            math.cos(angle), 0, -math.sin(angle),
            0, 1, 0,
            math.sin(angle), 0, math.cos(angle)
        )

        local road = makeAnchoredPart(
            worldFolder,
            string.format("Road_%d", i),
            Vector3.new(ROAD_WIDTH, 0.5, roadLength),
            roadCF,
            Color3.fromRGB(60, 60, 65),
            Enum.Material.SmoothPlastic
        )

        local line = makeAnchoredPart(
            worldFolder,
            string.format("RoadLine_%d", i),
            Vector3.new(1, 0.51, roadLength),
            roadCF,
            Color3.fromRGB(255, 255, 255),
            Enum.Material.SmoothPlastic
        )
        line.CanCollide = false

        -- Billboard с названием базы над дорогой
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 80, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = false
        billboard.MaxDistance = 200
        billboard.Parent = road

        local faction = TycoonConfig.getFaction(i)
        local roadLabel = Instance.new("TextLabel")
        roadLabel.Size = UDim2.new(1, 0, 1, 0)
        roadLabel.BackgroundTransparency = 1
        roadLabel.Text = string.format("База %d\n%s", i, faction.name)
        roadLabel.TextColor3 = faction.color
        roadLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        roadLabel.TextStrokeTransparency = 0.2
        roadLabel.TextScaled = true
        roadLabel.Font = Enum.Font.FredokaOne
        roadLabel.Parent = billboard

        -- Фонари вдоль дороги
        for s = -1, 1, 2 do
            local lampX = midX + math.sin(angle) * (ROAD_WIDTH / 2 + 1) * s
            local lampZ = midZ - math.cos(angle) * (ROAD_WIDTH / 2 + 1) * s

            makeAnchoredPart(
                worldFolder,
                string.format("Lamp_%d_%d", i, s),
                Vector3.new(0.5, 10, 0.5),
                CFrame.new(lampX, GROUND_Y + 5, lampZ),
                Color3.fromRGB(50, 50, 55),
                Enum.Material.Metal
            )

            local lampLight = makeAnchoredPart(
                worldFolder,
                string.format("LampLight_%d_%d", i, s),
                Vector3.new(1.5, 1, 1.5),
                CFrame.new(lampX, GROUND_Y + 10.5, lampZ),
                faction.color,
                Enum.Material.Neon,
                0.3
            )
            lampLight.CanCollide = false

            local light = Instance.new("PointLight")
            light.Range = 22
            light.Brightness = 1.2
            light.Color = faction.color
            light.Parent = lampLight
        end
    end

    -- 4. Океан вокруг острова (ниже уровня земли)
    makeAnchoredPart(
        worldFolder,
        "Ocean",
        Vector3.new(3000, 1, 3000),
        CFrame.new(0, GROUND_Y - 4, 0),
        Color3.fromRGB(0, 100, 180),
        Enum.Material.Water,
        0.3
    )

    -- 5. Невидимые стены по краю острова
    local WALL_COUNT = 32
    for i = 0, WALL_COUNT - 1 do
        local ang = i * (2 * math.pi / WALL_COUNT)
        local wx = ISLAND_RADIUS * math.cos(ang)
        local wz = ISLAND_RADIUS * math.sin(ang)
        makeAnchoredPart(
            worldFolder,
            string.format("BoundaryWall_%d", i),
            Vector3.new(2 * math.pi * ISLAND_RADIUS / WALL_COUNT + 2, 80, 3),
            CFrame.new(
                wx, GROUND_Y + 40, wz,
                math.cos(ang + math.pi / 2), 0, -math.sin(ang + math.pi / 2),
                0, 1, 0,
                math.sin(ang + math.pi / 2), 0, math.cos(ang + math.pi / 2)
            ),
            Color3.fromRGB(255, 255, 255),
            Enum.Material.SmoothPlastic,
            1
        )
    end

    -- 6. Неоновые колонны по центру
    for i = 1, 8 do
        local angle = (i - 1) * (2 * math.pi / 8)
        local rx = 22 * math.cos(angle)
        local rz = 22 * math.sin(angle)
        local faction = TycoonConfig.getFaction(i)
        local pillar = makeAnchoredPart(
            worldFolder,
            string.format("CenterPillar_%d", i),
            Vector3.new(1.5, 6, 1.5),
            CFrame.new(rx, GROUND_Y + 3, rz),
            faction.color,
            Enum.Material.Neon,
            0.2
        )
        pillar.CanCollide = false
    end

    print(string.format("[WorldBuilder] Island built at GROUND_Y=%d: R=%d, 8 roads, ocean, %d walls", GROUND_Y, ISLAND_RADIUS, WALL_COUNT))
end

return WorldBuilder
