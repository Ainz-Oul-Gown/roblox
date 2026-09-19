--!strict
-- DEBUG: Запускается первым при старте сервера.
-- Записывает в output подробный лог инициализации.
print("=== [DEBUG] Server init started ===")
print("=== [DEBUG] Workspace children BEFORE build ===")
local Workspace = game:GetService("Workspace")
for _, child in ipairs(Workspace:GetChildren()) do
    print("  WS child:", child.Name, child.ClassName)
end

local ok, err = pcall(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Shared = ReplicatedStorage:WaitForChild("Shared", 5)
    if not Shared then
        print("[DEBUG] ERROR: Shared not found in ReplicatedStorage!")
        return
    end
    print("[DEBUG] Shared found:", Shared:GetFullName())
    
    local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
    print("[DEBUG] TycoonConfig loaded, ARENA_RADIUS =", TycoonConfig.ARENA_RADIUS)
    print("[DEBUG] TOTAL_PLOTS =", TycoonConfig.TOTAL_PLOTS)
end)

if not ok then
    print("[DEBUG] CRITICAL ERROR:", err)
end

-- Проверяем ServerScriptService.Server
local SSS = game:GetService("ServerScriptService")
local Server = SSS:FindFirstChild("Server")
if Server then
    print("[DEBUG] Server module found:", Server:GetFullName())
    for _, child in ipairs(Server:GetChildren()) do
        print("  Server child:", child.Name, child.ClassName)
    end
else
    print("[DEBUG] ERROR: ServerScriptService.Server NOT FOUND!")
end

print("=== [DEBUG] done ===")
