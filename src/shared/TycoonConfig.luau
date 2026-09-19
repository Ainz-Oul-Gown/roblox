--!strict

--[=[
    TycoonConfig
    Конфигурация предметов, улучшений и параметров тайкуна.
]=]

export type TycoonItem = {
    id: string,
    name: string,
    cost: number,
    category: "Dropper" | "Structure" | "Collector" | "Decoration",
    dependsOn: string?,
    dropValue: number?,
    dropInterval: number?,
}

local TycoonConfig = {
    STARTING_CASH = 0,
    MAX_PLOTS = 4,
    CONVEYOR_SPEED = 14,
    AUTOSAVE_INTERVAL_SEC = 60,

    ITEMS = {
        {
            id = "Collector",
            name = "Сборщик монет",
            cost = 0,
            category = "Collector",
            dependsOn = nil,
        },
        {
            id = "StarterDropper",
            name = "Начальный дроппер",
            cost = 0,
            category = "Dropper",
            dependsOn = "Collector",
            dropValue = 1,
            dropInterval = 2.0,
        },
        {
            id = "Walls",
            name = "Базовые стены",
            cost = 25,
            category = "Structure",
            dependsOn = "StarterDropper",
        },
        {
            id = "UpgradedDropper",
            name = "Улучшенный дроппер",
            cost = 75,
            category = "Dropper",
            dependsOn = "Walls",
            dropValue = 5,
            dropInterval = 1.5,
        },
        {
            id = "Roof",
            name = "Крыша базы",
            cost = 150,
            category = "Structure",
            dependsOn = "UpgradedDropper",
        },
        {
            id = "GoldDropper",
            name = "Золотой супер-дроппер",
            cost = 350,
            category = "Dropper",
            dependsOn = "Roof",
            dropValue = 25,
            dropInterval = 1.0,
        },
        {
            id = "SecondFloor",
            name = "Второй этаж",
            cost = 700,
            category = "Structure",
            dependsOn = "GoldDropper",
        },
    } :: { TycoonItem },
}

-- Поиск предмета по идентификатору
function TycoonConfig.getItemById(itemId: string): TycoonItem?
    for _, item in ipairs(TycoonConfig.ITEMS) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

return TycoonConfig
