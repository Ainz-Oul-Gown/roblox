--!strict

--[=[
    TycoonConfig (Gen Alpha Brainrot Edition)
    Конфигурация 8 баз, фракций, вирусных дропперов, 5 уровней Rebirth и способностей.
]=]

export type Faction = {
    id: string,
    name: string,
    color: Color3,
    secondaryColor: Color3,
    abilityName: string,
    abilityDesc: string,
    dropperItemName: string,
    oreColor: Color3,
}

export type TycoonItem = {
    id: string,
    name: string,
    cost: number,
    category: "Dropper" | "Structure" | "Collector" | "Ability" | "Defense",
    dependsOn: string?,
    dropValue: number?,
    dropInterval: number?,
    minRebirth: number?,
}

export type RebirthTier = {
    tier: number,
    name: string,
    cost: number,
    multiplier: number,
    unlockedPerk: string,
}

local TycoonConfig = {
    STARTING_AURA = 0,
    TOTAL_PLOTS = 8,
    ARENA_RADIUS = 90, -- Радиус кольца баз от центра (0, 0, 0)
    CONVEYOR_SPEED = 15,
    AUTOSAVE_INTERVAL_SEC = 60,

    -- 8 Фракций баз
    FACTIONS = {
        {
            id = "Skibidi",
            name = "🚽 СКИБИДИ ТАУН",
            color = Color3.fromRGB(241, 196, 15),
            secondaryColor = Color3.fromRGB(52, 152, 219),
            abilityName = "Skibidi Spin",
            abilityDesc = "Вихрь смыва: раскидывает всех врагов вокруг!",
            dropperItemName = "Золотой Скибиди-Унитаз",
            oreColor = Color3.fromRGB(243, 156, 18),
        },
        {
            id = "Mewing",
            name = "🗿 ГИГАЧАД МЬЮИНГ",
            color = Color3.fromRGB(149, 165, 166),
            secondaryColor = Color3.fromRGB(44, 62, 80),
            abilityName = "Mewing Stare",
            abilityDesc = "Челюстной стан: замораживает врагов перед собой на 3 сек!",
            dropperItemName = "Каменная Челюсть Гигачада",
            oreColor = Color3.fromRGB(189, 195, 199),
        },
        {
            id = "Sigma",
            name = "🕶️ ПАТРИК СИГМА",
            color = Color3.fromRGB(142, 68, 173),
            secondaryColor = Color3.fromRGB(231, 76, 60),
            abilityName = "Sigma Phonk Rage",
            abilityDesc = "Фонк-ярость: двойная скорость бега и силовое поле!",
            dropperItemName = "Кристалл Фонка",
            oreColor = Color3.fromRGB(155, 89, 182),
        },
        {
            id = "FanumTax",
            name = "🍔 ФАНУМ ТАКС",
            color = Color3.fromRGB(230, 126, 34),
            secondaryColor = Color3.fromRGB(192, 57, 43),
            abilityName = "Tax Snatch",
            abilityDesc = "Налог Фанума: ворует 10% свободной Ауры у ближайшего игрока!",
            dropperItemName = "Гигантский Бургер",
            oreColor = Color3.fromRGB(211, 84, 0),
        },
        {
            id = "Grimace",
            name = "🥤 ГРИМАС ШЕЙК",
            color = Color3.fromRGB(155, 89, 182),
            secondaryColor = Color3.fromRGB(74, 35, 90),
            abilityName = "Grimace Toxic Cloud",
            abilityDesc = "Токсичный Шейк: ядовитое фиолетовое облако с уроном!",
            dropperItemName = "Фиолетовый Коктейль Гримас",
            oreColor = Color3.fromRGB(142, 68, 173),
        },
        {
            id = "CaseOh",
            name = "🪐 КЕЙСОХ ГРАВИТИ",
            color = Color3.fromRGB(52, 73, 94),
            secondaryColor = Color3.fromRGB(241, 196, 15),
            abilityName = "CaseOh Slam",
            abilityDesc = "Гравитационный слэм: сбивает всех с ног землетрясением!",
            dropperItemName = "Гравитационная Черная Дыра",
            oreColor = Color3.fromRGB(44, 62, 80),
        },
        {
            id = "Rizzler",
            name = "❤️ РИЗЗЛЕР & ГРОНК",
            color = Color3.fromRGB(231, 76, 60),
            secondaryColor = Color3.fromRGB(243, 104, 224),
            abilityName = "Unspoken Rizz",
            abilityDesc = "Несказанный Ризз: ослепляет врагов роем сердечек!",
            dropperItemName = "Пылающее Сердце Ризза",
            oreColor = Color3.fromRGB(232, 67, 147),
        },
        {
            id = "TungTung",
            name = "🔨 ИТАЛЬЯНСКИЙ ТУНГ-ТУНГ",
            color = Color3.fromRGB(39, 174, 96),
            secondaryColor = Color3.fromRGB(192, 57, 43),
            abilityName = "Tung Tung Hammer",
            abilityDesc = "Молот Тунг-Тунг: запускает врага в небеса на 50 studs!",
            dropperItemName = "Молот Тунг-Тунг Сахур",
            oreColor = Color3.fromRGB(46, 204, 113),
        },
    } :: { Faction },

    -- 5 Уровней Rebirth с разблокировкой уникального функционала
    REBIRTH_TIERS = {
        {
            tier = 1,
            name = "Сигма Новичок",
            cost = 1500,
            multiplier = 1.5,
            unlockedPerk = "Двойной прыжок + Секретная комната Prime",
        },
        {
            tier = 2,
            name = "Ризз Мастер",
            cost = 4000,
            multiplier = 2.2,
            unlockedPerk = "Skibidi Dash (Рывок вперед) + Золотой конвейер x2",
        },
        {
            tier = 3,
            name = "Айпад Повелитель",
            cost = 10000,
            multiplier = 3.5,
            unlockedPerk = "Защитная турель на крыше + Экран Subway Surfers",
        },
        {
            tier = 4,
            name = "Гигачад Босс",
            cost = 25000,
            multiplier = 5.5,
            unlockedPerk = "Gravity Coil (Прыжки x3) + Метеоритный Дроппер",
        },
        {
            tier = 5,
            name = "БОГ АЛЬФА ПОКОЛЕНИЯ",
            cost = 60000,
            multiplier = 10.0,
            unlockedPerk = "Крылья Сверхсигмы (Полный полет) + Золотая корона",
        },
    } :: { RebirthTier },

    -- Общий список улучшений базы
    ITEMS = {
        {
            id = "Collector",
            name = "Сборщик Ауры",
            cost = 0,
            category = "Collector",
            dependsOn = nil,
        },
        {
            id = "FactionDropper",
            name = "Фирменный Дроппер",
            cost = 0,
            category = "Dropper",
            dependsOn = "Collector",
            dropValue = 1,
            dropInterval = 1.8,
        },
        {
            id = "LaserGate",
            name = "⚡ Лазерные Ворота Безопасности",
            cost = 30,
            category = "Defense",
            dependsOn = "FactionDropper",
        },
        {
            id = "BrainrotWalls",
            name = "Стены из Неона",
            cost = 75,
            category = "Structure",
            dependsOn = "LaserGate",
        },
        {
            id = "FactionAbilityStand",
            name = "⚡ Стойка Суперспособности",
            cost = 150,
            category = "Ability",
            dependsOn = "BrainrotWalls",
        },
        {
            id = "UpgradedDropper",
            name = "Дроппер Prime Energy",
            cost = 300,
            category = "Dropper",
            dependsOn = "FactionAbilityStand",
            dropValue = 8,
            dropInterval = 1.4,
        },
        {
            id = "NeonRoof",
            name = "Неоновая Крыша",
            cost = 600,
            category = "Structure",
            dependsOn = "UpgradedDropper",
        },
        {
            id = "GoldDropper",
            name = "Золотой Дроппер Ризза",
            cost = 1200,
            category = "Dropper",
            dependsOn = "NeonRoof",
            dropValue = 35,
            dropInterval = 1.0,
        },
        {
            id = "SecondFloor",
            name = "Второй Этаж и Трон Гигачада",
            cost = 2500,
            category = "Structure",
            dependsOn = "GoldDropper",
        },
    } :: { TycoonItem },
}

function TycoonConfig.getFaction(plotIndex: number): Faction
    local idx = ((plotIndex - 1) % #TycoonConfig.FACTIONS) + 1
    return TycoonConfig.FACTIONS[idx]
end

function TycoonConfig.getItemById(itemId: string): TycoonItem?
    for _, item in ipairs(TycoonConfig.ITEMS) do
        if item.id == itemId then
            return item
        end
    end
    return nil
end

function TycoonConfig.getRebirthTier(tierIndex: number): RebirthTier?
    return TycoonConfig.REBIRTH_TIERS[tierIndex]
end

return TycoonConfig
