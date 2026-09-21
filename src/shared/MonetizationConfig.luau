--!strict

export type GamepassItem = {
    id: number,
    name: string,
    description: string,
    multiplier: number?,
    perk: string?,
}

export type ProductItem = {
    id: number,
    name: string,
    rewardType: "Cash" | "Rebirth" | "Nuke",
    rewardAmount: number,
}

local MonetizationConfig = {
    GAMEPASSES = {
        VIP = {
            id = 10001,
            name = "VIP Pass",
            description = "Золотой чат-тег, доступ в VIP-зону и множитель +25%",
            multiplier = 1.25,
            perk = "VIP_Access",
        } :: GamepassItem,

        DOUBLE_CASH = {
            id = 10002,
            name = "2x Cash Multiplier",
            description = "Удваивает всю собираемую валюту навсегда!",
            multiplier = 2.0,
            perk = "Double_Cash",
        } :: GamepassItem,

        AUTO_COLLECT = {
            id = 10003,
            name = "Auto Collector",
            description = "Автоматический вывод валюты из сейфа каждые 5 секунд",
            multiplier = 1.0,
            perk = "Auto_Withdraw",
        } :: GamepassItem,

        SPEED_PERK = {
            id = 10004,
            name = "Hyper Speed",
            description = "Увеличивает базовую скорость бега персонажа до 28",
            multiplier = 1.0,
            perk = "Speed_28",
        } :: GamepassItem,
    },

    PRODUCTS = {
        CASH_SMALL = {
            id = 20001,
            name = "Мешочек Ауры",
            rewardType = "Cash",
            rewardAmount = 50000,
        } :: ProductItem,

        CASH_MEDIUM = {
            id = 20002,
            name = "Чемодан Ауры",
            rewardType = "Cash",
            rewardAmount = 250000,
        } :: ProductItem,

        CASH_MEGA = {
            id = 20003,
            name = "Сейф Олигарха",
            rewardType = "Cash",
            rewardAmount = 1000000,
        } :: ProductItem,

        INSTANT_REBIRTH = {
            id = 20004,
            name = "Мгновенный Rebirth",
            rewardType = "Rebirth",
            rewardAmount = 1,
        } :: ProductItem,

        SERVER_NUKE = {
            id = 20005,
            name = "Мемный Серверный Nuke",
            rewardType = "Nuke",
            rewardAmount = 1,
        } :: ProductItem,
    },
}

return MonetizationConfig
