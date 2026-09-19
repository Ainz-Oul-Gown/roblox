--!strict

--[=[
    EconomyManager
    Управляет расчетами баланса, проверкой возможности покупки предметов
    и вычислением множителей дохода.
]=]

local TycoonConfig = require(script.Parent.TycoonConfig)

local EconomyManager = {}

-- Проверка достаточности средств
function EconomyManager.canAfford(currentBalance: number, cost: number): boolean
    return currentBalance >= cost and cost >= 0
end

-- Списание средств
function EconomyManager.deductCash(currentBalance: number, cost: number): number
    if not EconomyManager.canAfford(currentBalance, cost) then
        error("Insufficient funds or invalid cost")
    end
    return currentBalance - cost
end

-- Начисление средств с учетом множителя
function EconomyManager.addCash(currentBalance: number, amount: number, multiplier: number?): number
    local mult = multiplier or 1.0
    if mult < 1.0 then
        mult = 1.0
    end
    if amount < 0 then
        return currentBalance
    end
    return currentBalance + math.floor(amount * mult)
end

-- Проверка условий покупки предмета: наличие денег и выполнение зависимостей
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

    -- Проверка зависимости
    if item.dependsOn and not ownedItemIds[item.dependsOn] then
        return false, string.format("Requires prerequisite: %s", item.dependsOn)
    end

    -- Проверка баланса
    if not EconomyManager.canAfford(currentBalance, item.cost) then
        return false, "Insufficient funds"
    end

    return true, nil
end

return EconomyManager
