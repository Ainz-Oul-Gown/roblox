--!strict

--[=[
    TycoonService
    Серверная служба управления состоянием тайкуна, начислением валюты,
    обработкой покупок и инициализацией таблицы лидеров (leaderstats).
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
local EconomyManager = require(Shared:WaitForChild("EconomyManager"))

local TycoonService = {}

type PlayerData = {
    cash: number,
    ownedItems: { [string]: boolean },
}

local playerDataMap: { [number]: PlayerData } = {}

-- Инициализация данных и leaderstats для вошедшего игрока
function TycoonService.onPlayerAdded(player: Player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local cashValue = Instance.new("IntValue")
    cashValue.Name = "Cash"
    cashValue.Value = TycoonConfig.STARTING_CASH
    cashValue.Parent = leaderstats

    playerDataMap[player.UserId] = {
        cash = TycoonConfig.STARTING_CASH,
        ownedItems = {},
    }

    print(string.format("[TycoonService] Profile created for %s (UserId: %d)", player.Name, player.UserId))
end

-- Очистка данных при выходе игрока
function TycoonService.onPlayerRemoving(player: Player)
    playerDataMap[player.UserId] = nil
    print(string.format("[TycoonService] Cleaned up profile for %s", player.Name))
end

-- Получение текущего баланса
function TycoonService.getCash(player: Player): number
    local data = playerDataMap[player.UserId]
    return if data then data.cash else 0
end

-- Начисление денег игроку
function TycoonService.addCash(player: Player, amount: number)
    local data = playerDataMap[player.UserId]
    if not data then return end

    data.cash = EconomyManager.addCash(data.cash, amount)

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local cashVal = leaderstats:FindFirstChild("Cash") :: IntValue?
        if cashVal then
            cashVal.Value = data.cash
        end
    end
end

-- Попытка покупки предмета
function TycoonService.purchaseItem(player: Player, itemId: string): boolean
    local data = playerDataMap[player.UserId]
    if not data then return false end

    local canBuy, reason = EconomyManager.canPurchaseItem(data.cash, data.ownedItems, itemId)
    if not canBuy then
        warn(string.format("[TycoonService] %s cannot buy %s: %s", player.Name, itemId, reason or "unknown"))
        return false
    end

    local item = TycoonConfig.getItemById(itemId)
    if not item then return false end

    data.cash = EconomyManager.deductCash(data.cash, item.cost)
    data.ownedItems[itemId] = true

    -- Синхронизация leaderstats
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local cashVal = leaderstats:FindFirstChild("Cash") :: IntValue?
        if cashVal then
            cashVal.Value = data.cash
        end
    end

    print(string.format("[TycoonService] %s purchased %s! Remaining Cash: %d", player.Name, item.name, data.cash))
    return true
end

-- Проверка владения предметом
function TycoonService.hasItem(player: Player, itemId: string): boolean
    local data = playerDataMap[player.UserId]
    return if data then (data.ownedItems[itemId] == true) else false
end

return TycoonService
