print("[SERVER] ========================================")
print("[SERVER] init.server.luau STARTING EXECUTION...")
print("[SERVER] ========================================")

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Индикатор инициализации сервера для передачи на клиент
local statusVal = ReplicatedStorage:FindFirstChild("ServerInitStatus")
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

-- Настройка Future Lighting через модуль LightingThemes
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local LightingThemes = require(Shared:WaitForChild("LightingThemes", 10))
local PetConfig = require(Shared:WaitForChild("PetConfig", 10))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig", 10))
local DataStoreManager = require(script:WaitForChild("DataStoreManager", 10))
LightingThemes.applyTheme("SunsetGlow")

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

-- Подключаем callback для стендов (избегаем circular require)
task.defer(function()
    PlotBuilder.onStandPickup = function(player: Player, slotId: string)
        AbilityService.giveSpecificTool(player, slotId)
    end
end)

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
    if currentPlotIndex == plotIndex then return end

    -- Очистка тулов старой фракции
    AbilityService.clearPlayerTools(player)

    if currentPlotIndex then
        local switched, oldIndex = PlotManager.switchPlot(player, plotIndex)
        if switched and oldIndex then
            PlotBuilder.resetPlotToUnclaimed(oldIndex, onClaimBase)
            PlotBuilder.activatePlot(player, plotIndex)
        end
    else
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

-- 3.1 Лидерборды и динамические события AirDrop
local LeaderboardService = require(script:WaitForChild("LeaderboardService", 10))
LeaderboardService.init()

TycoonService.onPvPKill = function(killer: Player, victim: Player, amount: number)
    LeaderboardService.recordPvPKill(killer, victim, amount)
end

local AirDropService = require(script:WaitForChild("AirDropService", 10))
AirDropService.init()

-- 3.2 Монетизация, удержание и питомцы
local MonetizationService = require(script:WaitForChild("MonetizationService", 10))
MonetizationService.init()

-- P0-05: Обработчик наград монетизации — теперь обрабатывает ВСЕ типы
MonetizationService.setRewardHandler(function(player: Player, rewardType: string, amount: number)
    if rewardType == "Aura" or rewardType == "Cash" then
        TycoonService.addCash(player, amount)
        return true
    elseif rewardType == "Rebirth" then
        -- P0-05: Мгновенный Rebirth через донат
        local ok, _ = TycoonService.performRebirth(player)
        if not ok then
            -- Если ребирт невозможен, начисляем эквивалент аурой
            TycoonService.addCash(player, 100000)
        end
        return true
    elseif rewardType == "Nuke" then
        -- P0-05: Серверный Nuke — визуальный эффект (фан-фича)
        print(string.format("[NUKE] %s activated Server Nuke!", player.Name))
        return true
    end
    return false
end)

local RetentionService = require(script:WaitForChild("RetentionService", 10))
RetentionService.setRewardHandler(function(player: Player, rewardType: string, amount: number, specialItem: string?)
    if rewardType == "Aura" or rewardType == "Cash" then
        TycoonService.addCash(player, amount)
    end
    return true
end)

local PetService = require(script:WaitForChild("PetService", 10))

-- Связываем множители геймпасов и питомцев с TycoonService
TycoonService.getExtraMultiplier = function(player: Player): number
    local passMult = MonetizationService.getPlayerMultiplier(player)
    local petMult = PetService.getTotalMultiplier(player)
    return passMult * petMult
end

-- P0-06: Связываем callbacks для persistence
TycoonService.getPetDataForSave = function(player: Player)
    return PetService.getInventoryForSave(player)
end

TycoonService.getRetentionDataForSave = function(player: Player)
    return RetentionService.getRetentionDataForSave(player)
end

TycoonService.getProcessedReceipts = function(player: Player)
    return MonetizationService.getProcessedReceiptsList(player.UserId)
end

TycoonService.getPvPStatsForSave = function(player: Player)
    local stats = LeaderboardService.getPvPStats(player)
    return stats.kills, stats.bountyStolen
end

-- Сетевые события системы питомцев (Pet Gacha System)
local openEggEvent = ReplicatedStorage:FindFirstChild("OpenEggEvent")
if not openEggEvent then
    openEggEvent = Instance.new("RemoteEvent")
    openEggEvent.Name = "OpenEggEvent"
    openEggEvent.Parent = ReplicatedStorage
end

local equippedPetsEvent = ReplicatedStorage:FindFirstChild("EquippedPetsEvent")
if not equippedPetsEvent then
    equippedPetsEvent = Instance.new("RemoteEvent")
    equippedPetsEvent.Name = "EquippedPetsEvent"
    equippedPetsEvent.Parent = ReplicatedStorage
end

local eggOpenDebounce: { [number]: number } = {}

openEggEvent.OnServerEvent:Connect(function(player: Player, eggId: any)
    local now = os.clock()
    if (eggOpenDebounce[player.UserId] or 0) > now then
        return
    end
    eggOpenDebounce[player.UserId] = now + 0.6

    if type(eggId) ~= "string" then return end
    local eggDef = PetConfig.EGGS[eggId]
    if not eggDef then return end

    local deducted = TycoonService.deductCash(player, eggDef.cost)
    if deducted < eggDef.cost then
        warn(string.format("[PetService] %s cannot afford egg %s", player.Name, eggId))
        return
    end

    local rolledPetId = PetService.rollEgg(eggId)
    if rolledPetId then
        PetService.addPet(player, rolledPetId)
        PetService.equipBest(player)
        local petDefs = PetService.getEquippedPetDefs(player)
        equippedPetsEvent:FireClient(player, petDefs, rolledPetId)
        print(string.format("[PetService] %s hatched %s from %s!", player.Name, rolledPetId, eggDef.name))
    end
end)

-- Сетевые события системы удержания (Retention Engine)
local claimPlaytimeEvent = ReplicatedStorage:FindFirstChild("ClaimPlaytimeRewardEvent")
if not claimPlaytimeEvent then
    claimPlaytimeEvent = Instance.new("RemoteEvent")
    claimPlaytimeEvent.Name = "ClaimPlaytimeRewardEvent"
    claimPlaytimeEvent.Parent = ReplicatedStorage
end

local claimDailyEvent = ReplicatedStorage:FindFirstChild("ClaimDailyRewardEvent")
if not claimDailyEvent then
    claimDailyEvent = Instance.new("RemoteEvent")
    claimDailyEvent.Name = "ClaimDailyRewardEvent"
    claimDailyEvent.Parent = ReplicatedStorage
end

-- P1-14: Раздельные debounce для playtime и daily
local playtimeDebounce: { [number]: number } = {}
local dailyDebounce: { [number]: number } = {}

claimPlaytimeEvent.OnServerEvent:Connect(function(player: Player, tier: any)
    local now = os.clock()
    if (playtimeDebounce[player.UserId] or 0) > now then return end
    playtimeDebounce[player.UserId] = now + 1.0

    local t = tonumber(tier)
    if t and t >= 1 and t <= 5 and t == math.floor(t) then
        local ok, msg = RetentionService.claimPlaytimeReward(player, t)
        print(string.format("[Retention] %s claimPlaytime tier %d: %s (%s)", player.Name, t, tostring(ok), msg))
    end
end)

claimDailyEvent.OnServerEvent:Connect(function(player: Player)
    local now = os.clock()
    if (dailyDebounce[player.UserId] or 0) > now then return end
    dailyDebounce[player.UserId] = now + 1.0

    local ok, msg = RetentionService.claimDailyReward(player)
    print(string.format("[Retention] %s claimDaily: %s (%s)", player.Name, tostring(ok), msg))
end)

-- Сетевое событие монетизации (PromptPurchase)
local promptPurchaseEvent = ReplicatedStorage:FindFirstChild("PromptPurchaseEvent")
if not promptPurchaseEvent then
    promptPurchaseEvent = Instance.new("RemoteEvent")
    promptPurchaseEvent.Name = "PromptPurchaseEvent"
    promptPurchaseEvent.Parent = ReplicatedStorage
end

promptPurchaseEvent.OnServerEvent:Connect(function(player: Player, purchaseType: any, assetId: any)
    local id = tonumber(assetId)
    if not id then return end

    local isWhitelisted = false
    if purchaseType == "Gamepass" then
        for _, item in pairs(MonetizationConfig.GAMEPASSES) do
            if item.id == id then
                isWhitelisted = true
                break
            end
        end
    elseif purchaseType == "Product" then
        for _, item in pairs(MonetizationConfig.PRODUCTS) do
            if item.id == id then
                isWhitelisted = true
                break
            end
        end
    end

    if not isWhitelisted then
        warn(string.format("[SECURITY] Blocked unauthorized purchase prompt for ID %s from %s", tostring(assetId), player.Name))
        return
    end

    if purchaseType == "Gamepass" then
        MarketplaceService:PromptGamePassPurchase(player, id)
    elseif purchaseType == "Product" then
        MarketplaceService:PromptProductPurchase(player, id)
    end
end)

-- Связываем PlotManager.hasAnyBase в TycoonService (нужно CentralArena)
TycoonService.hasAnyBase = function(player: Player): boolean
    return PlotManager.getPlayerPlotIndex(player) ~= nil
end
TycoonService.getPlayerPlotIndex = PlotManager.getPlayerPlotIndex

local claimPlotDebounce: { [number]: number } = {}

-- 4. Удаленный вызов смены базы из GUI (защищен от DoS/спама)
local claimPlotEvent = ReplicatedStorage:WaitForChild("ClaimPlotEvent") :: RemoteEvent
claimPlotEvent.OnServerEvent:Connect(function(player: Player, plotIndex: any)
    local now = os.clock()
    if (claimPlotDebounce[player.UserId] or 0) > now then
        warn(string.format("[SECURITY] Base switch spam blocked from %s", player.Name))
        return
    end
    claimPlotDebounce[player.UserId] = now + 3.0

    -- P1-21: Проверка целочисленности
    if type(plotIndex) == "number" and plotIndex >= 1 and plotIndex <= 8 and plotIndex == math.floor(plotIndex) then
        onClaimBase(player, plotIndex)
    end
end)

-- 4.1 Админ-фишка для моментального лута ауры (защищена от публичных эксплойтов)
local function isAuthorizedAdmin(player: Player): boolean
    if RunService:IsStudio() then return true end
    if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then return true end
    return false
end

local adminCashEvent = ReplicatedStorage:FindFirstChild("AdminGiveCashEvent")
if not adminCashEvent then
    adminCashEvent = Instance.new("RemoteEvent")
    adminCashEvent.Name = "AdminGiveCashEvent"
    adminCashEvent.Parent = ReplicatedStorage
end

adminCashEvent.OnServerEvent:Connect(function(player: Player, amount: any)
    if not isAuthorizedAdmin(player) then
        warn(string.format("[SECURITY] Unauthorized AdminGiveCashEvent attempt from %s (UserId: %d)", player.Name, player.UserId))
        return
    end
    local n = tonumber(amount) or 1000000
    n = math.clamp(n, 1000, 100000000)
    TycoonService.addCash(player, n)
    print(string.format("[ADMIN] Granted +%d Aura to %s", n, player.Name))
end)

-- P1-17: Применение геймпасс-перков AUTO_COLLECT и SPEED_PERK
local function applyGamepassPerks(player: Player)
    -- SPEED_PERK: увеличивает базовую скорость
    if MonetizationService.userOwnsGamepass(player, MonetizationConfig.GAMEPASSES.SPEED_PERK.id) then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = math.max(hum.WalkSpeed, 28)
            end
        end
    end

    -- AUTO_COLLECT: автоматический вывод из сейфа каждые 5 секунд
    if MonetizationService.userOwnsGamepass(player, MonetizationConfig.GAMEPASSES.AUTO_COLLECT.id) then
        player:SetAttribute("AutoCollectEnabled", true)
    end
end

-- Фоновый цикл AUTO_COLLECT для владельцев геймпаса
task.spawn(function()
    while true do
        task.wait(5)
        for _, player in ipairs(Players:GetPlayers()) do
            if player:GetAttribute("AutoCollectEnabled") then
                local plotIndex = PlotManager.getPlayerPlotIndex(player)
                if plotIndex then
                    local stored = TycoonService.getVaultCash(plotIndex)
                    if stored > 0 then
                        TycoonService.withdrawVault(player, plotIndex)
                    end
                end
            end
        end
    end
end)

-- 5. Подключение игроков
local function onPlayerAdded(player: Player)
    print(string.format("[SERVER] Player connected: %s (UserId: %d)", player.Name, player.UserId))

    -- Загружаем saved данные один раз
    local savedData = DataStoreManager.loadData(player.UserId)

    TycoonService.onPlayerAdded(player, savedData)

    -- P0-06: Передаем сохранённые данные retention и питомцев
    RetentionService.initPlayer(player, savedData.dailyStreakDay, savedData.lastDailyClaimTimestamp)

    -- P0-06: Восстанавливаем питомцев из сохранения
    local savedPets: { any } = {}
    if savedData.pets then
        for _, entry in ipairs(savedData.pets) do
            if type(entry) == "table" and type(entry.uuid) == "string" and type(entry.petId) == "string" then
                table.insert(savedPets, {
                    uuid = entry.uuid,
                    petId = entry.petId,
                    isEquipped = entry.isEquipped == true,
                })
            end
        end
    end
    PetService.initPlayer(player, savedPets)

    -- P0-NEW-02 FIX: Загружаем обработанные receipts per-player
    MonetizationService.loadProcessedReceipts(player.UserId, savedData.processedReceipts)

    -- Восстанавливаем PvP-статистику
    if savedData.pvpKills and savedData.pvpKills > 0 then
        LeaderboardService.restorePvPStats(player, savedData.pvpKills, savedData.pvpBountyStolen or 0)
    end

    -- Чат-команда админа: /aura или /rich
    player.Chatted:Connect(function(msg: string)
        local lower = string.lower(msg)
        if string.sub(lower, 1, 5) == "/aura" or string.sub(lower, 1, 5) == "/rich" then
            if not isAuthorizedAdmin(player) then
                warn(string.format("[SECURITY] Unauthorized chat command from %s: %s", player.Name, msg))
                return
            end
            local parts = string.split(msg, " ")
            local amt = (parts[2] and tonumber(parts[2])) or 1000000
            amt = math.clamp(amt, 1000, 100000000)
            TycoonService.addCash(player, amt)
            print(string.format("[ADMIN CHAT] %s executed %s -> +%d Aura", player.Name, msg, amt))
        end
    end)

    local function setupChar(char: Model)
        local root = char:WaitForChild("HumanoidRootPart", 5)
        if root then
            task.wait(0.1)
            root.CFrame = CFrame.new(0, 11, 0) -- Центр острова, над площадью
        end
        -- P1-17: Применяем геймпасс-перки при каждом респавне
        task.wait(0.3)
        applyGamepassPerks(player)
    end

    if player.Character then
        task.spawn(setupChar, player.Character)
    end
    player.CharacterAdded:Connect(setupChar)

    -- Отправляем новому игроку актуальные статусы 8 баз
    local plotStateEvent = ReplicatedStorage:WaitForChild("PlotStateEvent") :: RemoteEvent
    task.delay(1, function()
        if not player.Parent then return end
        plotStateEvent:FireClient(player, PlotManager.getPlotStatuses())
        if player.Parent then
            local petDefs = PetService.getEquippedPetDefs(player)
            equippedPetsEvent:FireClient(player, petDefs)
        end
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
    RetentionService.removePlayer(player)
    PetService.removePlayer(player)
    eggOpenDebounce[player.UserId] = nil
    claimPlotDebounce[player.UserId] = nil
    playtimeDebounce[player.UserId] = nil
    dailyDebounce[player.UserId] = nil
end)

-- 6. Автосохранение каждые 60 секунд
task.spawn(function()
    while true do
        task.wait(60)
        TycoonService.saveAllPlayers()
    end
end)

-- P0-08: BindToClose — ждём до 25 секунд для завершения всех save
game:BindToClose(function()
    print("[SERVER] Server shutting down, saving data...")
    TycoonService.saveAllPlayers() -- saveAllPlayers теперь сам ждёт до 25с
end)

print("[SERVER] All 8 Bases ready for player selection!")
