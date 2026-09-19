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

print("[SERVER] Initializing 8-Base Gen Alpha Brainrot Tycoon World...")

-- 1. Центральная арена (0, 0, 0)
CentralArena.init()

-- 2. Обработчик захвата базы
local function onClaimBase(player: Player, plotIndex: number)
    local success = PlotManager.claimSpecificPlot(player, plotIndex)
    if success then
        PlotBuilder.activatePlot(player, plotIndex)
    end
end

-- 3. Строим все 8 баз по кругу арены
PlotBuilder.initAllBases(onClaimBase)

-- 4. Удаленный вызов выбора базы из GUI
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
