--!strict

--[=[
    TycoonService
    Серверная служба управления состоянием тайкуна, начислением валюты,
    обработкой покупок, сохранением в DataStore и таблицей лидеров (leaderstats).
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
local EconomyManager = require(Shared:WaitForChild("EconomyManager"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

local TycoonService = {}

export type PlayerData = {
    cash: number,
    rebirths: number,
    ownedItems: { [string]: boolean },
}

local playerDataMap: { [number]: PlayerData } = {}

-- Инициализация данных и leaderstats для вошедшего игрока с загрузкой из DataStore
function TycoonService.onPlayerAdded(player: Player): PlayerData
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local savedData = DataStoreManager.loadData(player.UserId)

    local cashValue = Instance.new("IntValue")
    cashValue.Name = "Cash"
    cashValue.Value = savedData.cash
    cashValue.Parent = leaderstats

    local rebirthValue = Instance.new("IntValue")
    rebirthValue.Name = "Rebirths"
    rebirthValue.Value = savedData.rebirths
    rebirthValue.Parent = leaderstats

    local currentData: PlayerData = {
        cash = savedData.cash,
        rebirths = savedData.rebirths,
        ownedItems = savedData.ownedItems,
    }

    playerDataMap[player.UserId] = currentData
    print(string.format("[TycoonService] Profile loaded for %s: Cash=$%d, Rebirths=%d", player.Name, currentData.cash, currentData.rebirths))
    return currentData
end

-- Сохранение данных при выходе игрока
function TycoonService.onPlayerRemoving(player: Player)
    local data = playerDataMap[player.UserId]
    if data then
        DataStoreManager.saveData(player.UserId, {
            version = 1,
            cash = data.cash,
            rebirths = data.rebirths,
            ownedItems = data.ownedItems,
            lastSaved = os.time(),
        })
        playerDataMap[player.UserId] = nil
        print(string.format("[TycoonService] Saved & cleaned profile for %s", player.Name))
    end
end

-- Сохранение всех активных игроков (автосейв и BindToClose)
function TycoonService.saveAllPlayers()
    print("[TycoonService] Saving all players...")
    for _, player in ipairs(Players:GetPlayers()) do
        local data = playerDataMap[player.UserId]
        if data then
            DataStoreManager.saveData(player.UserId, {
                version = 1,
                cash = data.cash,
                rebirths = data.rebirths,
                ownedItems = data.ownedItems,
                lastSaved = os.time(),
            })
        end
    end
end

-- Получение текущего баланса
function TycoonService.getCash(player: Player): number
    local data = playerDataMap[player.UserId]
    return if data then data.cash else 0
end

-- Получение количества перерождений
function TycoonService.getRebirths(player: Player): number
    local data = playerDataMap[player.UserId]
    return if data then data.rebirths else 0
end

-- Получение всех купленных предметов
function TycoonService.getOwnedItems(player: Player): { [string]: boolean }
    local data = playerDataMap[player.UserId]
    return if data then data.ownedItems else {}
end

-- Начисление денег игроку с учетом множителя Rebirth
function TycoonService.addCash(player: Player, amount: number)
    local data = playerDataMap[player.UserId]
    if not data then return end

    local mult = 1.0 + (data.rebirths * 0.5) -- +50% дохода за каждое перерождение
    data.cash = EconomyManager.addCash(data.cash, amount, mult)

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local cashVal = leaderstats:FindFirstChild("Cash") :: IntValue?
        if cashVal then
            cashVal.Value = data.cash
        end
    end
end

-- Покупка предмета
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

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local cashVal = leaderstats:FindFirstChild("Cash") :: IntValue?
        if cashVal then
            cashVal.Value = data.cash
        end
    end

    print(string.format("[TycoonService] %s purchased %s! Remaining: $%d", player.Name, item.name, data.cash))
    return true
end

-- Выполнение перерождения (Rebirth)
function TycoonService.performRebirth(player: Player): boolean
    local data = playerDataMap[player.UserId]
    if not data then return false end

    -- Для Rebirth требуется построить SecondFloor и иметь $1000
    local REBIRTH_COST = 1000
    if not data.ownedItems["SecondFloor"] or data.cash < REBIRTH_COST then
        return false
    end

    data.cash = 0
    data.rebirths += 1
    data.ownedItems = {} -- Сброс всех улучшений

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local cashVal = leaderstats:FindFirstChild("Cash") :: IntValue?
        if cashVal then cashVal.Value = 0 end

        local rebirthVal = leaderstats:FindFirstChild("Rebirths") :: IntValue?
        if rebirthVal then rebirthVal.Value = data.rebirths end
    end

    print(string.format("[TycoonService] %s performed REBIRTH! Total Rebirths: %d", player.Name, data.rebirths))
    return true
end

-- Проверка владения предметом
function TycoonService.hasItem(player: Player, itemId: string): boolean
    local data = playerDataMap[player.UserId]
    return if data then (data.ownedItems[itemId] == true) else false
end

return TycoonService
