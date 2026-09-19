--!strict

-- Server initialization script (ServerScriptService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtils = require(Shared:WaitForChild("MathUtils"))
local TycoonService = require(script.Parent:WaitForChild("TycoonService"))

print("[SERVER] Roblox Tycoon server initialized successfully!")

Players.PlayerAdded:Connect(function(player: Player)
    print(string.format("[SERVER] Player connected: %s (UserId: %d)", player.Name, player.UserId))
    TycoonService.onPlayerAdded(player)

    local defaultLevel = MathUtils.calculateLevel(0)
    print(string.format("[SERVER] Initial level for %s: %d", player.Name, defaultLevel))
end)

Players.PlayerRemoving:Connect(function(player: Player)
    print(string.format("[SERVER] Player disconnected: %s", player.Name))
    TycoonService.onPlayerRemoving(player)
end)
