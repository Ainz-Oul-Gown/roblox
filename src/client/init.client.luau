--!strict

-- Client initialization script (StarterPlayerScripts)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtils = require(Shared:WaitForChild("MathUtils"))

print(string.format("[CLIENT] Hello from client script, %s!", localPlayer.Name))
print(string.format("[CLIENT] MathUtils loaded: lerp(0, 100, 0.5) = %d", MathUtils.lerp(0, 100, 0.5)))
