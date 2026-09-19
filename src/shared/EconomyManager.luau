--!strict

--[=[
    EconomyManager
    Управляет расчетами валюты (Aura), проверкой покупок и 5-уровневой системой Rebirth.
]=]

local TycoonConfig = require(script.Parent.TycoonConfig)

local EconomyManager = {}

function EconomyManager.canAfford(currentBalance: number, cost: number): boolean
    return currentBalance >= cost and cost >= 0
end

function EconomyManager.deductCash(currentBalance: number, cost: number): number
    if not EconomyManager.canAfford(currentBalance, cost) then
        error("Insufficient funds or invalid cost")
    end
    return currentBalance - cost
end

-- Расчет множителя дохода на основе очков перерождений (Rebirths)
function EconomyManager.calculateMultiplier(rebirths: number): number
    if rebirths <= 0 then
        return 1.0
    end

    local tier = TycoonConfig.getRebirthTier(rebirths)
    if tier then
        return tier.multiplier
    end

    -- Свыше 5 уровня: +2.0 множителя за каждый дополнительный уровень
    return 10.0 + (rebirths - 5) * 2.0
end

function EconomyManager.addCash(currentBalance: number, amount: number, multiplier: number?): number
    local mult = multiplier or 1.0
    if mult < 1.0 then mult = 1.0 end
    if amount < 0 then return currentBalance end
    return currentBalance + math.floor(amount * mult)
end

function EconomyManager.canPurchaseItem(
    currentBalance: number,
    ownedItemIds: { [string]: boolean },
    itemId: string
): (boolean, string?)
    if ownedItemIds[itemId] then
        return false, "Already owned"
    end

    local item = TycoonConfig.getItemById(itemId)
    if not item then
        return false, "Item not found in config"
    end

    if item.dependsOn and not ownedItemIds[item.dependsOn] then
        return false, string.format("Requires prerequisite: %s", item.dependsOn)
    end

    if not EconomyManager.canAfford(currentBalance, item.cost) then
        return false, "Insufficient Aura"
    end

    return true, nil
end

-- Проверка возможности выполнения следующего Rebirth
function EconomyManager.canPerformRebirth(
    currentBalance: number,
    currentRebirths: number,
    ownedItemIds: { [string]: boolean }
): (boolean, string?, number?)
    if not ownedItemIds["SecondFloor"] then
        return false, "Требуется построить Второй этаж", nil
    end

    local nextTierIndex = currentRebirths + 1
    local tier = TycoonConfig.getRebirthTier(nextTierIndex)
    local cost = if tier then tier.cost else 50000 + (nextTierIndex * 15000)

    if currentBalance < cost then
        return false, string.format("Недостаточно Ауры (нужно %d)", cost), cost
    end

    return true, nil, cost
end

return EconomyManager
