--!strict

--[=[
    CentralArena
    Управляет центральной зоной «Царь Горы Ауры» (0, 0, 0):
    создает золотой пьедестал, вычисляет контролера зоны и начисляет бонусную Ауру (+25 в секунду).
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TycoonService = require(script.Parent:WaitForChild("TycoonService"))

local CentralArena = {}

local AURA_ZONE_RADIUS = 16
local AURA_REWARD_PER_SEC = 25
local GROUND_Y = 3 -- соответствует WorldBuilder.GROUND_Y

function CentralArena.init()
    local arenaModel = Instance.new("Model")
    arenaModel.Name = "CentralArena"
    arenaModel.Parent = Workspace

    -- 1. Золотой круглый пьедестал
    local pad = Instance.new("Part")
    pad.Name = "KingOfAuraPad"
    pad.Shape = Enum.PartType.Cylinder
    pad.Size = Vector3.new(1.2, AURA_ZONE_RADIUS * 2, AURA_ZONE_RADIUS * 2)
    pad.CFrame = CFrame.new(0, GROUND_Y + 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
    pad.Anchored = true
    pad.Material = Enum.Material.Neon
    pad.Color = Color3.fromRGB(241, 196, 15)
    pad.Parent = arenaModel

    -- Вывеска над центром
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ArenaGui"
    billboard.Size = UDim2.new(0, 240, 0, 70)
    billboard.StudsOffset = Vector3.new(0, 7, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 150
    billboard.Parent = pad

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "👑 ЦАРЬ ГОРЫ АУРЫ\n+25 AURA / СЕК"
    label.TextColor3 = Color3.fromRGB(255, 235, 59)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Parent = billboard

    -- Золотые частицы арены
    local auraParticles = Instance.new("ParticleEmitter")
    auraParticles.Name = "GoldParticles"
    auraParticles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    auraParticles.Rate = 12
    auraParticles.Speed = NumberRange.new(4, 8)
    auraParticles.Lifetime = NumberRange.new(1, 2)
    auraParticles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
    auraParticles.Parent = pad

    -- Цикл начисления награды лидеру зоны
    -- Только игрокам у которых есть своя база!
    task.spawn(function()
        while true do
            task.wait(1.0)
            local centerPos = Vector3.new(0, GROUND_Y + 0.6, 0)
            local currentKing: Player? = nil
            local closestDist = AURA_ZONE_RADIUS

            for _, player in ipairs(Players:GetPlayers()) do
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local hum = char:FindFirstChild("Humanoid") :: Humanoid?
                    if root and hum and hum.Health > 0 then
                        local dist = (root.Position - centerPos).Magnitude
                        if dist <= closestDist then
                            -- Только если у игрока есть база!
                            local hasBase = TycoonService.hasAnyBase and TycoonService.hasAnyBase(player)
                            if hasBase then
                                closestDist = dist
                                currentKing = player
                            end
                        end
                    end
                end
            end

            if currentKing then
                TycoonService.addCashRaw(currentKing, AURA_REWARD_PER_SEC)
                label.Text = string.format("👑 ЦАРЬ: %s\n+25 AURA / СЕК", currentKing.Name)
            else
                label.Text = "👑 ЦАРЬ ГОРЫ АУРЫ\nЗАХВАТИ ЗОНУ (+25/СЕК)!"
            end
        end
    end)


    print("[CentralArena] King of Aura Arena initialized at (0, 0, 0)")
end

return CentralArena
