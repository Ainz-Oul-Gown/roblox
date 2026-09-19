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

print("[SERVER] Initializing Gen Alpha Brainrot Multiplayer Tycoon...")

-- 1. Инициализация центральной арены Ауры (0, 0, 0)
CentralArena.init()

-- 2. Подключение игроков
local function setupPlayer(player: Player)
    local plotIndex, pos, cframe, faction = PlotManager.claimPlot(player)
    if not plotIndex or not faction then
        warn("[SERVER] Could not allocate plot for " .. player.Name)
        return
    end

    print(string.format("[SERVER] Player %s claimed Base %d: %s", player.Name, plotIndex, faction.name))
    
    TycoonService.onPlayerAdded(player)
    PlotBuilder.createPlotForPlayer(player, plotIndex)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
    print(string.format("[SERVER] Player %s disconnected, cleaning up...", player.Name))
    PlotBuilder.destroyPlotForPlayer(player)
    PlotManager.releasePlot(player)
    TycoonService.onPlayerRemoving(player)
end)

-- 3. Автосохранение каждые 60 секунд
task.spawn(function()
    while true do
        task.wait(60)
        TycoonService.saveAllPlayers()
    end
end)

-- 4. Сохранение при выключении сервера
game:BindToClose(function()
    print("[SERVER] Shutting down, saving all players...")
    TycoonService.saveAllPlayers()
    task.wait(1)
end)

print("[SERVER] 8-Base Brainrot Multiplayer Tycoon Ready!")
