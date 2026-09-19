--!strict

-- Server initialization script (ServerScriptService.Server)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtils = require(Shared:WaitForChild("MathUtils"))
local TycoonService = require(script:WaitForChild("TycoonService"))
local PlotManager = require(script:WaitForChild("PlotManager"))
local PlotBuilder = require(script:WaitForChild("PlotBuilder"))
local AbilityService = require(script:WaitForChild("AbilityService"))
local CentralArena = require(script:WaitForChild("CentralArena"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))

print("[SERVER] Initializing 8-Base Gen Alpha Brainrot Tycoon World...")

-- 0. Строим карту острова (пол, дороги, океан, фонари)
WorldBuilder.buildWorld()

-- 1. Центральная арена (0, 0, 0)
CentralArena.init()

-- 2. Обработчик захвата/смены базы
local function onClaimBase(player: Player, plotIndex: number)
    local currentPlotIndex = PlotManager.getPlayerPlotIndex(player)

    if currentPlotIndex == plotIndex then
        -- Уже на этой базе
        return
    end

    if currentPlotIndex then
        -- Смена базы: сначала сбрасываем старую
        local switched, oldIndex = PlotManager.switchPlot(player, plotIndex)
        if switched and oldIndex then
            PlotBuilder.resetPlotToUnclaimed(oldIndex, onClaimBase)
            PlotBuilder.activatePlot(player, plotIndex)
        end
    else
        -- Первый захват
        local success = PlotManager.claimSpecificPlot(player, plotIndex)
        if success then
            PlotBuilder.activatePlot(player, plotIndex)
        end
    end
end

-- 3. Строим все 8 баз по кругу арены
PlotBuilder.initAllBases(onClaimBase)

-- Связываем PlotManager.hasAnyBase в TycoonService (нужно CentralArena)
TycoonService.hasAnyBase = function(player: Player): boolean
    return PlotManager.getPlayerPlotIndex(player) ~= nil
end

-- 4. Удаленный вызов смены базы из GUI (для совместимости)
local claimPlotEvent = ReplicatedStorage:WaitForChild("ClaimPlotEvent") :: RemoteEvent
claimPlotEvent.OnServerEvent:Connect(function(player: Player, plotIndex: any)
    if type(plotIndex) == "number" and plotIndex >= 1 and plotIndex <= 8 then
        onClaimBase(player, plotIndex)
    end
end)

-- 5. Подключение игроков
local function onPlayerAdded(player: Player)
    print(string.format("[SERVER] Player connected: %s (UserId: %d)", player.Name, player.UserId))
    TycoonService.onPlayerAdded(player)

    -- Телепортируем игрока в центр при спавне
    player.CharacterAdded:Connect(function(char)
        local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
        if root then
            task.wait(0.2)
            root.CFrame = CFrame.new(0, 8, 0) -- Центр арены, над землёй
        end
    end)

    -- Отправляем новому игроку актуальные статусы 8 баз
    local plotStateEvent = ReplicatedStorage:WaitForChild("PlotStateEvent") :: RemoteEvent
    task.delay(1, function()
        plotStateEvent:FireClient(player, PlotManager.getPlotStatuses())
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
    print(string.format("[SERVER] Player %s disconnected", player.Name))
    local releasedIndex = PlotManager.releasePlot(player)
    if releasedIndex then
        PlotBuilder.resetPlotToUnclaimed(releasedIndex, onClaimBase)
    end
    TycoonService.onPlayerRemoving(player)
end)

-- 6. Автосохранение каждые 60 секунд
task.spawn(function()
    while true do
        task.wait(60)
        TycoonService.saveAllPlayers()
    end
end)

game:BindToClose(function()
    print("[SERVER] Server shutting down, saving data...")
    TycoonService.saveAllPlayers()
    task.wait(1)
end)

print("[SERVER] All 8 Bases ready for player selection!")
