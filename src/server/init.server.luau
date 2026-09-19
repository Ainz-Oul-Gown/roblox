--!strict

-- Server initialization script (ServerScriptService.Server)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtils = require(Shared:WaitForChild("MathUtils"))
local TycoonService = require(script:WaitForChild("TycoonService"))
local PlotBuilder = require(script:WaitForChild("PlotBuilder"))

print("[SERVER] Roblox Tycoon Server Initializing...")

local assignedPlotCount = 0

local function setupPlayer(player: Player)
    assignedPlotCount += 1
    print(string.format("[SERVER] Player connected: %s (UserId: %d, Plot: %d)", player.Name, player.UserId, assignedPlotCount))
    
    TycoonService.onPlayerAdded(player)
    PlotBuilder.createPlotForPlayer(player, assignedPlotCount)

    local initialLevel = MathUtils.calculateLevel(0)
    print(string.format("[SERVER] Initial level for %s: %d", player.Name, initialLevel))
end

-- Подключаем слушатель новых игроков
Players.PlayerAdded:Connect(setupPlayer)

-- Обработка игроков, которые уже успели загрузиться при старте сервера в Studio
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player: Player)
    print(string.format("[SERVER] Player disconnected: %s", player.Name))
    PlotBuilder.destroyPlotForPlayer(player)
    TycoonService.onPlayerRemoving(player)
end)

print("[SERVER] Roblox Tycoon Server Ready!")
