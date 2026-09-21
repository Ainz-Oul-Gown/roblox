--!strict

--[=[
    EconomyManager
    Управляет расчетами валюты (Aura), проверкой покупок и 5-уровневой системой Rebirth.
    
    AUDIT FIXES: P1-12 (dead code removal), P1-22 (NaN/Infinity guard)
]=]

local TycoonConfig = require(script.Parent:WaitForChild("TycoonConfig", 5))

local EconomyManager = {}

-- P1-22: NaN/Infinity guard
local function isSafeNumber(val: number): boolean
    return val == val and val ~= math.huge and val ~= -math.huge
end

function EconomyManager.canAfford(currentBalance: number, cost: number): boolean
    -- P1-22: NaN guard
    if not isSafeNumber(currentBalance) or not isSafeNumber(cost) then
        return false
    end
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
    if not isSafeNumber(rebirths) or rebirths <= 0 then
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
    -- P1-22: NaN guard на всех входных параметрах
    if not isSafeNumber(currentBalance) then currentBalance = 0 end
    if not isSafeNumber(amount) or amount < 0 then return currentBalance end

    local mult = multiplier or 1.0
    if not isSafeNumber(mult) or mult < 1.0 then mult = 1.0 end

    local result = currentBalance + math.floor(amount * mult)
    if not isSafeNumber(result) then return currentBalance end
    return result
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

    if item.dependsOn and item.dependsOn ~= "Collector" and item.dependsOn ~= "FactionDropper" then
        if not ownedItemIds[item.dependsOn] then
            return false, string.format("Requires prerequisite: %s", item.dependsOn)
        end
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
    -- P1-12: Убран мёртвый код "SecondFloor" — правильный ID: "Floor2_Foundation"
    local has2ndFloor = ownedItemIds["Floor2_Foundation"]
    if not has2ndFloor then
        return false, "Требуется построить Второй этаж", nil
    end

    local nextTierIndex = currentRebirths + 1
    local tier = TycoonConfig.getRebirthTier(nextTierIndex)
    local cost = if tier then tier.cost else 50000 + (nextTierIndex * 15000)

    if not isSafeNumber(currentBalance) or currentBalance < cost then
        return false, string.format("Недостаточно Ауры (нужно %d)", cost), cost
    end

    return true, nil, cost
end

return EconomyManager
