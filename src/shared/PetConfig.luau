--!strict

export type PetRarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type PetDefinition = {
    id: string,
    name: string,
    rarity: PetRarity,
    multiplier: number,
    modelName: string,
}

export type EggDefinition = {
    id: string,
    name: string,
    cost: number,
    costType: "Cash" | "Rebirth",
    drops: {
        { petId: string, weight: number }
    }
}

local PetConfig = {
    MAX_EQUIPPED_PETS = 3,

    PETS = {
        SkibidiNoob = {
            id = "SkibidiNoob",
            name = "Нубик Скибиди",
            rarity = "Common",
            multiplier = 1.15,
            modelName = "Pet_SkibidiNoob",
        } :: PetDefinition,

        SigmaCat = {
            id = "SigmaCat",
            name = "Сигма Кот",
            rarity = "Rare",
            multiplier = 1.35,
            modelName = "Pet_SigmaCat",
        } :: PetDefinition,

        GigachadDog = {
            id = "GigachadDog",
            name = "Гигачад Дог",
            rarity = "Epic",
            multiplier = 1.75,
            modelName = "Pet_GigachadDog",
        } :: PetDefinition,

        GrimaceMonster = {
            id = "GrimaceMonster",
            name = "Гримас Шейкер",
            rarity = "Legendary",
            multiplier = 2.50,
            modelName = "Pet_GrimaceMonster",
        } :: PetDefinition,

        CaseOhBlackHole = {
            id = "CaseOhBlackHole",
            name = "КейсОх Сингулярность",
            rarity = "Mythic",
            multiplier = 5.00,
            modelName = "Pet_CaseOhBlackHole",
        } :: PetDefinition,
    },

    EGGS = {
        BasicBrainrotEgg = {
            id = "BasicBrainrotEgg",
            name = "Мемное Яйцо 1 Уровня",
            cost = 10000,
            costType = "Cash",
            drops = {
                { petId = "SkibidiNoob", weight = 60 },      -- 60%
                { petId = "SigmaCat", weight = 28 },        -- 28%
                { petId = "GigachadDog", weight = 10 },     -- 10%
                { petId = "GrimaceMonster", weight = 1.9 },  -- 1.9%
                { petId = "CaseOhBlackHole", weight = 0.1 },-- 0.1% (Сверхредкий)
            }
        } :: EggDefinition,
    }
}

return PetConfig
