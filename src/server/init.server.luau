print("[SERVER] ========================================")
print("[SERVER] init.server.luau STARTING EXECUTION...")
print("[SERVER] ========================================")

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Индикатор инициализации сервера для передачи на клиент
local statusVal = ReplicatedStorage:FindFirstChild("ServerInitStatus") :: StringValue?
if not statusVal then
    statusVal = Instance.new("StringValue")
    statusVal.Name = "ServerInitStatus"
    statusVal.Parent = ReplicatedStorage
end
statusVal.Value = "🔨 Удаление Baseplate..."

-- Удаляем стандартный Baseplate из Studio (мешает виду острова)
local existingBaseplate = Workspace:FindFirstChild("Baseplate") or Workspace:FindFirstChild("baseplate")
if existingBaseplate then
    existingBaseplate:Destroy()
    print("[SERVER] Removed default Baseplate")
end

statusVal.Value = "🏝️ Постройка острова (WorldBuilder)..."
local WorldBuilder = require(script:WaitForChild("WorldBuilder", 10))
local wbOk, wbErr = pcall(function()
    WorldBuilder.buildWorld()
end)
if not wbOk then
    statusVal.Value = "❌ Ошибка WorldBuilder: " .. tostring(wbErr)
    warn("[SERVER] WorldBuilder error: " .. tostring(wbErr))
else
    print("[SERVER] WorldBuilder.buildWorld completed successfully")
end

statusVal.Value = "📦 Загрузка PlotManager..."
local PlotManager = require(script:WaitForChild("PlotManager", 10))

statusVal.Value = "📦 Загрузка TycoonService..."
local TycoonService = require(script:WaitForChild("TycoonService", 10))

statusVal.Value = "👑 Постройка Центральной Арены..."
local CentralArena = require(script:WaitForChild("CentralArena", 10))
CentralArena.init()

statusVal.Value = "📦 Загрузка AbilityService..."
local AbilityService = require(script:WaitForChild("AbilityService", 10))

statusVal.Value = "📦 Загрузка PlotBuilder..."
local PlotBuilder: any = nil
local reqOk, reqErr = pcall(function()
    PlotBuilder = require(script:WaitForChild("PlotBuilder", 10))
end)
if not reqOk or not PlotBuilder then
    statusVal.Value = "❌ Ошибка require PlotBuilder: " .. tostring(reqErr)
    warn("[SERVER] Error loading PlotBuilder:", reqErr)
    return
end

-- Перемещаем стандартный SpawnLocation в центр острова
local defaultSpawn = Workspace:FindFirstChild("SpawnLocation") :: SpawnLocation?
if defaultSpawn and defaultSpawn:IsA("SpawnLocation") then
    defaultSpawn.CFrame = CFrame.new(0, 4, 0)
    defaultSpawn.Transparency = 1
    local decal = defaultSpawn:FindFirstChildOfClass("Decal")
    if decal then decal.Transparency = 1 end
end

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
statusVal.Value = "🏗️ Постройка 8 баз (PlotBuilder)..."
local pbOk, pbErr = pcall(function()
    PlotBuilder.initAllBases(onClaimBase)
end)
if not pbOk then
    statusVal.Value = "❌ Ошибка PlotBuilder: " .. tostring(pbErr)
    warn("[SERVER] PlotBuilder error:", pbErr)
else
    statusVal.Value = "✅ Остров и 8 баз активны! Выбери базу"
    print("[SERVER] All 8 Bases ready for player selection!")
end

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

    local function setupChar(char: Model)
        local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
        if root then
            task.wait(0.1)
            root.CFrame = CFrame.new(0, 11, 0) -- Центр острова, над площадью
        end
    end

    if player.Character then
        task.spawn(setupChar, player.Character)
    end
    player.CharacterAdded:Connect(setupChar)

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
