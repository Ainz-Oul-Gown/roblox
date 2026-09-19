--!strict

--[=[
    TycoonConfig (Gen Alpha Brainrot Edition - Full 2-Floor Tycoon & Multi-Ability)
    Конфигурация 8 баз, фракций, 3 способностей на фракцию, апгрейдеров,
    двухэтажной цепочки улучшений и прогрессивной шкалы Rebirth.
]=]

export type AbilityInfo = {
    id: string,
    name: string,
    desc: string,
    cooldown: number,
    slot: "base" | "tactical" | "ultimate",
}

export type Faction = {
    id: string,
    name: string,
    color: Color3,
    secondaryColor: Color3,
    abilityName: string,
    abilityDesc: string,
    dropperItemName: string,
    oreColor: Color3,
    baseAbility: AbilityInfo,
    tacticalAbility: AbilityInfo,
    ultimateAbility: AbilityInfo,
}

export type TycoonItem = {
    id: string,
    name: string,
    cost: number,
    category: "Dropper" | "Structure" | "Collector" | "Ability" | "Defense" | "Upgrader",
    dependsOn: string?,
    dropValue: number?,
    dropInterval: number?,
    multiplier: number?,
    floor: number?,
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
    ARENA_RADIUS = 180, -- Расширенный радиус для просторных 48x64 баз
    BASE_WIDTH = 48,
    BASE_LENGTH = 64,
    CONVEYOR_SPEED = 16,
    AUTOSAVE_INTERVAL_SEC = 60,

    -- 8 Фракций баз: у каждой по 3 уникальные способности (базовая, тактическая, ультимейт)
    FACTIONS = {
        {
            id = "Skibidi",
            name = "🚽 СКИБИДИ ТАУН",
            color = Color3.fromRGB(241, 196, 15),
            secondaryColor = Color3.fromRGB(52, 152, 219),
            abilityName = "🚽 Skibidi Spin",
            abilityDesc = "Вихрь смыва: раскидывает всех врагов вокруг на 25 studs!",
            dropperItemName = "Золотой Скибиди-Унитаз",
            oreColor = Color3.fromRGB(243, 156, 18),
            baseAbility = {
                id = "Skibidi_Base",
                name = "🚽 Skibidi Spin",
                desc = "Вихрь смыва: раскидывает всех врагов вокруг на 25 studs!",
                cooldown = 10,
                slot = "base",
            },
            tacticalAbility = {
                id = "Skibidi_Tactical",
                name = "🛡️ Скибиди Броня",
                desc = "Керамический панцирь: -50% урона и ускорение бега на 6 сек!",
                cooldown = 16,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "Skibidi_Ultimate",
                name = "🌪️ Мега-Смыв 3000",
                desc = "Титанический водоворот: притягивает врагов в радиусе 35 studs и оглушает на 3 сек!",
                cooldown = 32,
                slot = "ultimate",
            },
        },
        {
            id = "Mewing",
            name = "🗿 ГИГАЧАД МЬЮИНГ",
            color = Color3.fromRGB(149, 165, 166),
            secondaryColor = Color3.fromRGB(44, 62, 80),
            abilityName = "🗿 Mewing Stare",
            abilityDesc = "Челюстной стан: замораживает врагов перед собой на 3 сек!",
            dropperItemName = "Каменная Челюсть Гигачада",
            oreColor = Color3.fromRGB(189, 195, 199),
            baseAbility = {
                id = "Mewing_Base",
                name = "🗿 Mewing Stare",
                desc = "Челюстной стан: замораживает врагов перед собой на 3 сек!",
                cooldown = 10,
                slot = "base",
            },
            tacticalAbility = {
                id = "Mewing_Tactical",
                name = "💪 Алмазный Подбородок",
                desc = "Отражает 40% урона атакующим и делает невосприимчивым к отталкиванию на 5 сек!",
                cooldown = 18,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "Mewing_Ultimate",
                name = "⚡ Bye Bye Shockwave",
                desc = "Разрушительная ударная волна 'Bye Bye': сбивает всех с ног и наносит 65 урона!",
                cooldown = 30,
                slot = "ultimate",
            },
        },
        {
            id = "Sigma",
            name = "🕶️ ПАТРИК СИГМА",
            color = Color3.fromRGB(142, 68, 173),
            secondaryColor = Color3.fromRGB(231, 76, 60),
            abilityName = "🕶️ Phonk Rage",
            abilityDesc = "Фонк-ярость: двойная скорость бега и силовое поле!",
            dropperItemName = "Кристалл Фонка",
            oreColor = Color3.fromRGB(155, 89, 182),
            baseAbility = {
                id = "Sigma_Base",
                name = "🕶️ Phonk Rage",
                desc = "Фонк-ярость: двойная скорость бега и силовое поле на 6 сек!",
                cooldown = 10,
                slot = "base",
            },
            tacticalAbility = {
                id = "Sigma_Tactical",
                name = "🔪 Сигма Парирование",
                desc = "Парирует следующую атаку и наносит мгновенный контрудар на 40 урона!",
                cooldown = 15,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "Sigma_Ultimate",
                name = "🔥 Сигма Доминация",
                desc = "Аура абсолютного превосходства: замедляет всех врагов на 60% и утраивает урон!",
                cooldown = 35,
                slot = "ultimate",
            },
        },
        {
            id = "FanumTax",
            name = "🍔 ФАНУМ ТАКС",
            color = Color3.fromRGB(230, 126, 34),
            secondaryColor = Color3.fromRGB(192, 57, 43),
            abilityName = "🍔 Tax Snatch",
            abilityDesc = "Налог Фанума: ворует 15% наличной Ауры у ближайшего игрока!",
            dropperItemName = "Гигантский Бургер",
            oreColor = Color3.fromRGB(211, 84, 0),
            baseAbility = {
                id = "FanumTax_Base",
                name = "🍔 Tax Snatch",
                desc = "Налог Фанума: ворует 15% наличной Ауры у ближайшего игрока!",
                cooldown = 12,
                slot = "base",
            },
            tacticalAbility = {
                id = "FanumTax_Tactical",
                name = "🍟 Ловушка Фастфуда",
                desc = "Разливает масло на 8 сек: любой враг скользит, падает и теряет управление!",
                cooldown = 16,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "FanumTax_Ultimate",
                name = "🍕 Великий Налоговый Аудит",
                desc = "Высасывает 30% кошелька у всех врагов поблизости и мгновенно лечит вас на 50 HP!",
                cooldown = 36,
                slot = "ultimate",
            },
        },
        {
            id = "Grimace",
            name = "🥤 ГРИМАС ШЕЙК",
            color = Color3.fromRGB(155, 89, 182),
            secondaryColor = Color3.fromRGB(74, 35, 90),
            abilityName = "🥤 Grimace Cloud",
            abilityDesc = "Токсичный Шейк: ядовитое фиолетовое облако с периодическим уроном!",
            dropperItemName = "Фиолетовый Коктейль Гримас",
            oreColor = Color3.fromRGB(142, 68, 173),
            baseAbility = {
                id = "Grimace_Base",
                name = "🥤 Grimace Cloud",
                desc = "Токсичный Шейк: ядовитое фиолетовое облако с уроном!",
                cooldown = 11,
                slot = "base",
            },
            tacticalAbility = {
                id = "Grimace_Tactical",
                name = "🧃 Коктейльная Лужа",
                desc = "Токсичная слизь под ногами врагов: замедляет на 70% и наносит 10 урона/сек!",
                cooldown = 17,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "Grimace_Ultimate",
                name = "☣️ Катаклизм Гримаса",
                desc = "Гигантский фиолетовый туман на всю арену: наносит 15 урона в секунду всем врагам!",
                cooldown = 34,
                slot = "ultimate",
            },
        },
        {
            id = "CaseOh",
            name = "🪐 КЕЙСОХ ГРАВИТИ",
            color = Color3.fromRGB(52, 73, 94),
            secondaryColor = Color3.fromRGB(241, 196, 15),
            abilityName = "🪐 CaseOh Slam",
            abilityDesc = "Гравитационный слэм: сбивает всех с ног мощным сотрясением земли!",
            dropperItemName = "Гравитационная Черная Дыра",
            oreColor = Color3.fromRGB(44, 62, 80),
            baseAbility = {
                id = "CaseOh_Base",
                name = "🪐 CaseOh Slam",
                desc = "Гравитационный слэм: сбивает всех с ног мощным сотрясением земли!",
                cooldown = 10,
                slot = "base",
            },
            tacticalAbility = {
                id = "CaseOh_Tactical",
                name = "🧲 Горизонт Событий",
                desc = "Гравитационный купол: притягивает все снаряды и врагов к центру!",
                cooldown = 19,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "CaseOh_Ultimate",
                name = "🌑 Метеорит КейсОха",
                desc = "С неба обрушивается колоссальный метеорит: 75 урона по огромной площади!",
                cooldown = 32,
                slot = "ultimate",
            },
        },
        {
            id = "Rizzler",
            name = "❤️ РИЗЗЛЕР & ГРОНК",
            color = Color3.fromRGB(231, 76, 60),
            secondaryColor = Color3.fromRGB(243, 104, 224),
            abilityName = "❤️ Unspoken Rizz",
            abilityDesc = "Несказанный Ризз: ослепляет врагов роем розовых сердечек!",
            dropperItemName = "Пылающее Сердце Ризза",
            oreColor = Color3.fromRGB(232, 67, 147),
            baseAbility = {
                id = "Rizzler_Base",
                name = "❤️ Unspoken Rizz",
                desc = "Несказанный Ризз: ослепляет врагов роем розовых сердечек!",
                cooldown = 9,
                slot = "base",
            },
            tacticalAbility = {
                id = "Rizzler_Tactical",
                name = "✨ Ризз Гипноз",
                desc = "Очаровывает врага: цель замирает на месте на 3.5 секунды, не в силах атаковать!",
                cooldown = 16,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "Rizzler_Ultimate",
                name = "💥 Взрыв Сверхризза",
                desc = "Ослепительная вспышка очарования: наносит 50 урона и отключает способности врагов на 5 сек!",
                cooldown = 30,
                slot = "ultimate",
            },
        },
        {
            id = "TungTung",
            name = "🔨 ИТАЛЬЯНСКИЙ ТУНГ-ТУНГ",
            color = Color3.fromRGB(39, 174, 96),
            secondaryColor = Color3.fromRGB(192, 57, 43),
            abilityName = "🔨 Tung Tung Hammer",
            abilityDesc = "Молот Тунг-Тунг: запускает врага в небеса на 45 studs!",
            dropperItemName = "Молот Тунг-Тунг Сахур",
            oreColor = Color3.fromRGB(46, 204, 113),
            baseAbility = {
                id = "TungTung_Base",
                name = "🔨 Tung Tung Hammer",
                desc = "Молот Тунг-Тунг: запускает врага в небеса на 45 studs!",
                cooldown = 10,
                slot = "base",
            },
            tacticalAbility = {
                id = "TungTung_Tactical",
                name = "⚡ Наковальня Сахура",
                desc = "Сбрасывает тяжелую наковальню на голову врага: оглушение на 3 сек!",
                cooldown = 16,
                slot = "tactical",
            },
            ultimateAbility = {
                id = "TungTung_Ultimate",
                name = "🌋 Итальянский Торнадо",
                desc = "Вихрь молотов на 6 секунд: рассекает всех врагов вокруг и дает бессмертие!",
                cooldown = 32,
                slot = "ultimate",
            },
        },
    } :: { Faction },

    -- 5 Уровней Rebirth с экспоненциальной шкалой цен и высокими множителями
    REBIRTH_TIERS = {
        {
            tier = 1,
            name = "Сигма Новичок",
            cost = 80000,
            multiplier = 2.0,
            unlockedPerk = "Двойной прыжок + Золотые искры ауры",
        },
        {
            tier = 2,
            name = "Ризз Мастер",
            cost = 250000,
            multiplier = 3.5,
            unlockedPerk = "Skibidi Dash (Рывок вперед) + Золотой конвейер x2",
        },
        {
            tier = 3,
            name = "Айпад Повелитель",
            cost = 700000,
            multiplier = 6.0,
            unlockedPerk = "Защитный купол на крыше + Силовые сапоги",
        },
        {
            tier = 4,
            name = "Гигачад Босс",
            cost = 2000000,
            multiplier = 10.0,
            unlockedPerk = "Gravity Coil (Прыжки x3) + Метеоритная броня",
        },
        {
            tier = 5,
            name = "БОГ АЛЬФА ПОКОЛЕНИЯ",
            cost = 6000000,
            multiplier = 20.0,
            unlockedPerk = "Крылья Сверхсигмы (Полный полет) + Золотая корона Бога",
        },
    } :: { RebirthTier },

    -- Полноценная 2-этажная цепочка улучшений базы (сбалансированная шкала цен)
    ITEMS = {
        -- 1 ЭТАЖ:
        {
            id = "Collector",
            name = "Сборщик Ауры и Сейф",
            cost = 0,
            category = "Collector",
            dependsOn = nil,
            floor = 1,
        },
        {
            id = "FactionDropper",
            name = "Фирменный Дроппер",
            cost = 0,
            category = "Dropper",
            dependsOn = "Collector",
            dropValue = 1,
            dropInterval = 1.8,
            floor = 1,
        },
        {
            id = "LaserGate",
            name = "⚡ Лазерные Ворота Безопасности",
            cost = 50,
            category = "Defense",
            dependsOn = "FactionDropper",
            floor = 1,
        },
        {
            id = "BrainrotWalls",
            name = "Неоновые Стены Периметра",
            cost = 150,
            category = "Structure",
            dependsOn = "LaserGate",
            floor = 1,
        },
        {
            id = "Upgrader_Laser",
            name = "🔬 Лазерный Умножитель (x2)",
            cost = 400,
            category = "Upgrader",
            dependsOn = "FactionDropper",
            multiplier = 2,
            floor = 1,
        },
        {
            id = "AbilityStand_1",
            name = "⚡ Стойка Базовой Способности [E]",
            cost = 900,
            category = "Ability",
            dependsOn = "FactionDropper",
            floor = 1,
        },
        {
            id = "Dropper_Prime",
            name = "Дроппер Prime Energy",
            cost = 2200,
            category = "Dropper",
            dependsOn = "FactionDropper",
            dropValue = 12,
            dropInterval = 1.4,
            floor = 1,
        },
        {
            id = "AbilityStand_Tactical",
            name = "🛡️ Стойка Тактической Способности [R]",
            cost = 5500,
            category = "Ability",
            dependsOn = "AbilityStand_1",
            floor = 1,
        },
        {
            id = "Stairs_To_Floor2",
            name = "🪜 Лестница на 2-й Этаж",
            cost = 11000,
            category = "Structure",
            dependsOn = "BrainrotWalls",
            floor = 1,
        },

        -- 2 ЭТАЖ:
        {
            id = "Floor2_Foundation",
            name = "🏗️ Платформа Второго Этажа",
            cost = 24000,
            category = "Structure",
            dependsOn = "Stairs_To_Floor2",
            floor = 2,
        },
        {
            id = "Floor2_Walls",
            name = "🧱 Неоновые Ограждения 2-го Этажа",
            cost = 38000,
            category = "Structure",
            dependsOn = "Floor2_Foundation",
            floor = 2,
        },
        {
            id = "Floor2_Conveyor",
            name = "🚀 Верхний Конвейер со Сбросом",
            cost = 58000,
            category = "Structure",
            dependsOn = "Floor2_Walls",
            floor = 2,
        },
        {
            id = "Upgrader_Quantum",
            name = "🌌 Квантовый Умножитель (x3)",
            cost = 95000,
            category = "Upgrader",
            dependsOn = "Floor2_Conveyor",
            multiplier = 3,
            floor = 2,
        },
        {
            id = "Dropper_Galactic",
            name = "⭐ Галактический Дроппер",
            cost = 150000,
            category = "Dropper",
            dependsOn = "Upgrader_Quantum",
            dropValue = 60,
            dropInterval = 1.1,
            floor = 2,
        },
        {
            id = "AbilityStand_Ultimate",
            name = "👑 Стойка Ультимейта [Q]",
            cost = 240000,
            category = "Ability",
            dependsOn = "Dropper_Galactic",
            floor = 2,
        },
        {
            id = "Upgrader_Annihilator",
            name = "🔥 Аннигилятор Ауры (x5)",
            cost = 400000,
            category = "Upgrader",
            dependsOn = "AbilityStand_Ultimate",
            multiplier = 5,
            floor = 2,
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
