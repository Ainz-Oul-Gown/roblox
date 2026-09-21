--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.MonetizationConfig)

local MonetizationService = {}

-- Кэш обработанных чеков (PurchaseId) для предотвращения дубликатов при лагах сети
local processedReceipts: { [string]: boolean } = {}

-- Кэш купленных геймпасов игроков: [UserId]: { [GamepassId]: boolean }
local playerGamepasses: { [number]: { [number]: boolean } } = {}

-- Callback для начисления валюты/наград в основной сервис (например TycoonService)
type RewardCallback = (player: Player, rewardType: string, amount: number) -> boolean
local onRewardGranted: RewardCallback? = nil

function MonetizationService.setRewardHandler(handler: RewardCallback)
    onRewardGranted = handler
end

function MonetizationService.isReceiptProcessed(receiptId: string): boolean
    return processedReceipts[receiptId] == true
end

function MonetizationService.processReceiptLogic(receiptInfo: {
    PurchaseId: string,
    PlayerId: number,
    ProductId: number,
}): Enum.ProductPurchaseDecision
    local receiptKey = receiptInfo.PurchaseId
    if processedReceipts[receiptKey] then
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
        processedReceipts[receiptKey] = true
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
    MarketplaceService.ProcessReceipt = function(receiptInfo)
        return MonetizationService.processReceiptLogic(receiptInfo)
    end

    Players.PlayerRemoving:Connect(function(player)
        playerGamepasses[player.UserId] = nil
    end)
end

return MonetizationService
