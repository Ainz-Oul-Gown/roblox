--!strict

--[=[
    MathUtils
    Предоставляет вспомогательные математические и логические функции
    для расчета опыта, уровней и числовых интерполяций.
]=]

local MathUtils = {}

-- Ограничение значения диапазоном [min, max]
function MathUtils.clamp(value: number, minVal: number, maxVal: number): number
    if minVal > maxVal then
        error("minVal cannot be greater than maxVal")
    end
    if value < minVal then
        return minVal
    elseif value > maxVal then
        return maxVal
    end
    return value
end

-- Линейная интерполяция
function MathUtils.lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

-- Расчет текущего уровня на основе накопленного опыта
function MathUtils.calculateLevel(xp: number, xpPerLevel: number?): number
    local step = xpPerLevel or 100
    if xp < 0 or step <= 0 then
        return 1
    end
    return math.floor(xp / step) + 1
end

-- Расчет требуемого опыта для достижения следующего уровня
function MathUtils.calculateXpForNextLevel(currentLevel: number, xpPerLevel: number?): number
    local step = xpPerLevel or 100
    if currentLevel < 1 then
        return step
    end
    return currentLevel * step
end

return MathUtils
