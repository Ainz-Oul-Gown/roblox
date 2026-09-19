--!strict

-- Server initialization script (ServerScriptService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtils = require(Shared:WaitForChild("MathUtils"))
local TycoonService = require(script.Parent:WaitForChild("TycoonService"))
local PlotBuilder = require(script.Parent:WaitForChild("PlotBuilder"))

print("[SERVER] Roblox Tycoon Server Initializing...")

local assignedPlotCount = 0

Players.PlayerAdded:Connect(function(player: Player)
    assignedPlotCount += 1
    print(string.format("[SERVER] Player connected: %s (UserId: %d, Plot: %d)", player.Name, player.UserId, assignedPlotCount))
    
    TycoonService.onPlayerAdded(player)
    PlotBuilder.createPlotForPlayer(player, assignedPlotCount)

    local initialLevel = MathUtils.calculateLevel(0)
    print(string.format("[SERVER] Initial level for %s: %d", player.Name, initialLevel))
end)

Players.PlayerRemoving:Connect(function(player: Player)
    print(string.format("[SERVER] Player disconnected: %s", player.Name))
    PlotBuilder.destroyPlotForPlayer(player)
    TycoonService.onPlayerRemoving(player)
end)

print("[SERVER] Roblox Tycoon Server Ready!")
