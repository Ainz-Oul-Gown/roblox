--!strict

--[=[
    PlotManager
    Управляет пулом из 8 круговых баз на арене:
    назначает свободные участки по сторонам света, фиксирует фракцию и координаты.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))

local PlotManager = {}

type PlotData = {
    index: number,
    owner: Player?,
    position: Vector3,
    cframe: CFrame,
    faction: TycoonConfig.Faction,
}

local plots: { [number]: PlotData } = {}
local playerPlotMap: { [number]: number } = {}

-- Инициализация 8 круговых баз вокруг центра (0, 0, 0)
local function initPlots()
    local total = TycoonConfig.TOTAL_PLOTS
    local radius = TycoonConfig.ARENA_RADIUS
    local center = Vector3.new(0, 0.5, 0)

    for i = 1, total do
        local angle = (i - 1) * (2 * math.pi / total)
        local posX = radius * math.cos(angle)
        local posZ = radius * math.sin(angle)
        local pos = Vector3.new(posX, 0.5, posZ)
        
        -- Поворот базы лицом к центральной арене (0, 0, 0)
        local lookAtCenter = CFrame.new(pos, Vector3.new(0, pos.Y, 0))

        plots[i] = {
            index = i,
            owner = nil,
            position = pos,
            cframe = lookAtCenter,
            faction = TycoonConfig.getFaction(i),
        }
    end
end

initPlots()

-- Получить свободную базу и закрепить за игроком
function PlotManager.claimPlot(player: Player): (number?, Vector3?, CFrame?, TycoonConfig.Faction?)
    -- Проверяем, есть ли уже база
    local existingIndex = playerPlotMap[player.UserId]
    if existingIndex then
        local p = plots[existingIndex]
        return p.index, p.position, p.cframe, p.faction
    end

    -- Ищем первый свободный участок
    for i = 1, TycoonConfig.TOTAL_PLOTS do
        if plots[i].owner == nil then
            plots[i].owner = player
            playerPlotMap[player.UserId] = i
            print(string.format("[PlotManager] Assigned Plot %d (%s) to %s", i, plots[i].faction.name, player.Name))
            return i, plots[i].position, plots[i].cframe, plots[i].faction
        end
    end

    warn(string.format("[PlotManager] All %d plots are occupied!", TycoonConfig.TOTAL_PLOTS))
    return nil, nil, nil, nil
end

-- Освободить базу при выходе игрока
function PlotManager.releasePlot(player: Player): number?
    local index = playerPlotMap[player.UserId]
    if index and plots[index] then
        plots[index].owner = nil
        playerPlotMap[player.UserId] = nil
        print(string.format("[PlotManager] Released Plot %d for %s", index, player.Name))
        return index
    end
    return nil
end

function PlotManager.getPlayerPlotIndex(player: Player): number?
    return playerPlotMap[player.UserId]
end

function PlotManager.getPlotOwner(plotIndex: number): Player?
    if plots[plotIndex] then
        return plots[plotIndex].owner
    end
    return nil
end

function PlotManager.getPlotData(plotIndex: number): PlotData?
    return plots[plotIndex]
end

function PlotManager.getAllPlots(): { [number]: PlotData }
    return plots
end

return PlotManager
