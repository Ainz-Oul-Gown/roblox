--!strict

--[=[
    PlotManager
    Управляет пулом из 8 круговых баз на арене:
    позволяет игрокам выбирать конкретную базу (Скибиди, Гигачад, Сигма и т.д.)
    или вставать на ClaimPad у входа.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))

local PlotManager = {}

export type PlotData = {
    index: number,
    owner: Player?,
    position: Vector3,
    cframe: CFrame,
    faction: TycoonConfig.Faction,
}

local plots: { [number]: PlotData } = {}
local playerPlotMap: { [number]: number } = {}

-- Создание RemoteEvent для выбора базы и синхронизации статуса
local function getOrCreateRemote(name: string): RemoteEvent
    local existing = ReplicatedStorage:FindFirstChild(name) :: any :: RemoteEvent?
    if existing then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = ReplicatedStorage
    return remote
end

local claimPlotEvent = getOrCreateRemote("ClaimPlotEvent")
local plotStateEvent = getOrCreateRemote("PlotStateEvent")

-- Инициализация 8 круговых баз вокруг центра (0, 0, 0)
local function initPlots()
    local total = TycoonConfig.TOTAL_PLOTS
    local radius = TycoonConfig.ARENA_RADIUS

    for i = 1, total do
        local angle = (i - 1) * (2 * math.pi / total)
        local posX = radius * math.cos(angle)
        local posZ = radius * math.sin(angle)
        local pos = Vector3.new(posX, 3, posZ) -- Y=3 (GROUND_Y) = поверхность острова

        -- База смотрит ВГЛУБЬ (от центра наружу).
        -- LookVector = направление К центру (entrée лицом к центру).
        -- CFrame.new(pos, target): LookVector = normalize(target - pos) = к центру.
        -- Поскольку коллектор на +Z (локальный), а дроппер на -Z,
        -- база должна смотреть ОТ центра (LookVector к центру = вход у нас),
        -- но в Roblox CFrame.new(pos, lookTarget) строит CFrame где -Z = lookTarget.
        -- Значит -Z направлен к центру => вход (Z=+14) направлен НАРУЖУ от центра.
        -- Чтобы вход был к ЦЕНТРУ, нам нужно ориентировать базу:
        --   LookVector (==+Z локальный) указывает К ЦЕНТРУ
        -- => используем lookAt = pos (не centre), т.е. разворачиваем на 180°
        local lookAwayFromCenter = CFrame.new(pos, Vector3.new(0, pos.Y, 0))
        -- Разворачиваем на 180° чтобы +Z (вход/клаймпад) смотрел к центру
        local lookTowardCenter = lookAwayFromCenter * CFrame.Angles(0, math.rad(180), 0)

        plots[i] = {
            index = i,
            owner = nil,
            position = pos,
            cframe = lookTowardCenter,
            faction = TycoonConfig.getFaction(i),
        }
    end
end


initPlots()

-- P1-20: Минимальный payload (только isClaimed, ownerName, factionId — без полного faction)
function PlotManager.getPlotStatuses(): { [number]: { isClaimed: boolean, ownerName: string?, factionId: string } }
    local res = {}
    for i = 1, TycoonConfig.TOTAL_PLOTS do
        local p = plots[i]
        res[i] = {
            isClaimed = p.owner ~= nil,
            ownerName = if p.owner then p.owner.Name else nil,
            factionId = p.faction.id,
        }
    end
    return res
end

-- Захват конкретной выбранной базы игроком
function PlotManager.claimSpecificPlot(player: Player, plotIndex: number): boolean
    if playerPlotMap[player.UserId] then
        warn(string.format("[PlotManager] %s already owns a plot!", player.Name))
        return false
    end

    local plot = plots[plotIndex]
    if not plot or plot.owner ~= nil then
        warn(string.format("[PlotManager] Plot %d is unavailable!", plotIndex))
        return false
    end

    plot.owner = player
    playerPlotMap[player.UserId] = plotIndex
    print(string.format("[PlotManager] %s successfully claimed Plot %d: %s", player.Name, plotIndex, plot.faction.name))

    -- Оповещаем всех клиентов об изменении статуса баз
    plotStateEvent:FireAllClients(PlotManager.getPlotStatuses())
    return true
end

-- Автоматический захват первой свободной базы (fallback)
function PlotManager.claimFirstAvailablePlot(player: Player): number?
    if playerPlotMap[player.UserId] then
        return playerPlotMap[player.UserId]
    end

    for i = 1, TycoonConfig.TOTAL_PLOTS do
        if plots[i].owner == nil then
            if PlotManager.claimSpecificPlot(player, i) then
                return i
            end
        end
    end
    return nil
end

-- Освобождение базы при выходе
function PlotManager.releasePlot(player: Player): number?
    local index = playerPlotMap[player.UserId]
    if index and plots[index] then
        plots[index].owner = nil
        playerPlotMap[player.UserId] = nil
        print(string.format("[PlotManager] Released Plot %d for %s", index, player.Name))
        plotStateEvent:FireAllClients(PlotManager.getPlotStatuses())
        return index
    end
    return nil
end

-- Смена базы: освобождает текущую и занимает новую
function PlotManager.switchPlot(player: Player, newPlotIndex: number): (boolean, number?)
    local currentIndex = playerPlotMap[player.UserId]
    if currentIndex == newPlotIndex then
        warn(string.format("[PlotManager] %s is already at Plot %d!", player.Name, newPlotIndex))
        return false, nil
    end

    -- Освобождаем текущую если есть
    if currentIndex then
        plots[currentIndex].owner = nil
        playerPlotMap[player.UserId] = nil
        print(string.format("[PlotManager] %s released Plot %d to switch to %d", player.Name, currentIndex, newPlotIndex))
    end

    -- Занимаем новую
    local newPlot = plots[newPlotIndex]
    if not newPlot or newPlot.owner ~= nil then
        warn(string.format("[PlotManager] Plot %d is unavailable for switch!", newPlotIndex))
        -- Если новая занята, нужно вернуть старую (восстановить)
        if currentIndex then
            plots[currentIndex].owner = player
            playerPlotMap[player.UserId] = currentIndex
        end
        return false, nil
    end

    newPlot.owner = player
    playerPlotMap[player.UserId] = newPlotIndex
    print(string.format("[PlotManager] %s switched to Plot %d: %s", player.Name, newPlotIndex, newPlot.faction.name))
    plotStateEvent:FireAllClients(PlotManager.getPlotStatuses())
    return true, currentIndex
end


function PlotManager.getPlayerPlotIndex(player: Player): number?
    return playerPlotMap[player.UserId]
end

function PlotManager.getPlotData(plotIndex: number): PlotData?
    return plots[plotIndex]
end

function PlotManager.getAllPlots(): { [number]: PlotData }
    return plots
end

return PlotManager
