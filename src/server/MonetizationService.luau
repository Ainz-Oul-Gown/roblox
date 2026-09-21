--!strict

--[=[
    MonetizationService
    Промышленная обработка чеков MarketplaceService.ProcessReceipt
    с идемпотентностью и кэшированием геймпасов.
    
    AUDIT FIX P0-04: Receipt IDs сохраняются через DataStore (не только RAM).
]=]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local MonetizationConfig = require(ReplicatedStorage.Shared.MonetizationConfig)

local MonetizationService = {}

-- P0-04: Кэш обработанных чеков в RAM + DataStore для persistence
local processedReceipts: { [string]: boolean } = {}
local receiptDataStore: any = nil

-- Кэш купленных геймпасов игроков: [UserId]: { [GamepassId]: boolean }
local playerGamepasses: { [number]: { [number]: boolean } } = {}

-- Callback для начисления валюты/наград в основной сервис
type RewardCallback = (player: Player, rewardType: string, amount: number) -> boolean
local onRewardGranted: RewardCallback? = nil

function MonetizationService.setRewardHandler(handler: RewardCallback)
    onRewardGranted = handler
end

-- P0-04: Проверка receipt через DataStore
local function isReceiptInDataStore(receiptId: string): boolean
    if not receiptDataStore then return false end
    local ok, result = pcall(function()
        return receiptDataStore:GetAsync("receipt_" .. receiptId)
    end)
    return ok and result == true
end

-- P0-04: Сохранение receipt в DataStore
local function saveReceiptToDataStore(receiptId: string)
    if not receiptDataStore then return end
    pcall(function()
        receiptDataStore:SetAsync("receipt_" .. receiptId, true)
    end)
end

function MonetizationService.isReceiptProcessed(receiptId: string): boolean
    if processedReceipts[receiptId] then return true end
    return isReceiptInDataStore(receiptId)
end

-- P0-04: Получить все закэшированные receipt IDs для сохранения в player data
function MonetizationService.getProcessedReceiptsList(): { string }
    local list: { string } = {}
    for key in pairs(processedReceipts) do
        table.insert(list, key)
    end
    return list
end

-- Загрузить ранее обработанные receipts из player data
function MonetizationService.loadProcessedReceipts(receiptIds: { string }?)
    if not receiptIds then return end
    for _, id in ipairs(receiptIds) do
        processedReceipts[id] = true
    end
end

function MonetizationService.processReceiptLogic(receiptInfo: {
    PurchaseId: string,
    PlayerId: number,
    ProductId: number,
}): Enum.ProductPurchaseDecision
    local receiptKey = receiptInfo.PurchaseId

    -- P0-04: Проверка и в RAM, и в DataStore
    if processedReceipts[receiptKey] or isReceiptInDataStore(receiptKey) then
        processedReceipts[receiptKey] = true
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Игрок отключился до обработки, Roblox повторит запрос при следующем входе
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local matchedProduct: any = nil
    for _, product in pairs(MonetizationConfig.PRODUCTS) do
        if product.id == receiptInfo.ProductId then
            matchedProduct = product
            break
        end
    end

    if not matchedProduct then
        warn(`[MonetizationService] Неизвестный ProductId: {receiptInfo.ProductId}`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local success = true
    if onRewardGranted then
        success = onRewardGranted(player, matchedProduct.rewardType, matchedProduct.rewardAmount)
    end

    if success then
        -- P0-04: Сначала сохраняем в DataStore, потом PurchaseGranted
        processedReceipts[receiptKey] = true
        saveReceiptToDataStore(receiptKey)
        print(`[MonetizationService] Товар {matchedProduct.name} успешно выдан игроку {player.Name}`)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        warn(`[MonetizationService] Сбой выдачи награды игроку {player.Name}`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
end

function MonetizationService.userOwnsGamepass(player: Player, passId: number): boolean
    local userId = player.UserId
    if playerGamepasses[userId] and playerGamepasses[userId][passId] ~= nil then
        return playerGamepasses[userId][passId]
    end

    local owns = false
    local success, err = pcall(function()
        owns = MarketplaceService:UserOwnsGamePassAsync(userId, passId)
    end)

    if success then
        if not playerGamepasses[userId] then
            playerGamepasses[userId] = {}
        end
        playerGamepasses[userId][passId] = owns
        return owns
    else
        warn(`[MonetizationService] Ошибка проверки геймпаса {passId}: {tostring(err)}`)
        return false
    end
end

function MonetizationService.getPlayerMultiplier(player: Player): number
    local mult = 1.0
    if MonetizationService.userOwnsGamepass(player, MonetizationConfig.GAMEPASSES.VIP.id) then
        mult *= (MonetizationConfig.GAMEPASSES.VIP.multiplier or 1.0)
    end
    if MonetizationService.userOwnsGamepass(player, MonetizationConfig.GAMEPASSES.DOUBLE_CASH.id) then
        mult *= (MonetizationConfig.GAMEPASSES.DOUBLE_CASH.multiplier or 1.0)
    end
    return mult
end

function MonetizationService.init()
    -- P0-04: Инициализация отдельного DataStore для чеков
    local dsOk, dsResult = pcall(function()
        return DataStoreService:GetDataStore("ProcessedReceipts_v1")
    end)
    if dsOk and dsResult then
        receiptDataStore = dsResult
        print("[MonetizationService] Receipt DataStore connected.")
    else
        warn("[MonetizationService] Receipt DataStore unavailable, using RAM-only mode.")
    end

    MarketplaceService.ProcessReceipt = function(receiptInfo)
        return MonetizationService.processReceiptLogic(receiptInfo)
    end

    Players.PlayerRemoving:Connect(function(player)
        playerGamepasses[player.UserId] = nil
    end)
end

return MonetizationService
