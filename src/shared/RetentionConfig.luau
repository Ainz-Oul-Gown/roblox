--!strict

export type PlaytimeReward = {
    tier: number,
    requiredSeconds: number,
    label: string,
    rewardType: "Cash" | "Multiplier" | "Rebirth",
    amount: number,
}

export type DailyStreakDay = {
    day: number,
    label: string,
    rewardCash: number,
    specialItem: string?,
}

local RetentionConfig = {
    -- Награды за время сессии (Playtime Gifts)
    PLAYTIME_REWARDS = {
        { tier = 1, requiredSeconds = 300,  label = "5 Минут",  rewardType = "Cash", amount = 5000 },
        { tier = 2, requiredSeconds = 600,  label = "10 Минут", rewardType = "Cash", amount = 15000 },
        { tier = 3, requiredSeconds = 900,  label = "15 Минут", rewardType = "Cash", amount = 35000 },
        { tier = 4, requiredSeconds = 1800, label = "30 Минут", rewardType = "Cash", amount = 100000 },
        { tier = 5, requiredSeconds = 3600, label = "60 Минут", rewardType = "Cash", amount = 300000 },
    } :: { PlaytimeReward },

    -- 7-дневный календарь ежедневного входа
    DAILY_STREAK = {
        { day = 1, label = "День 1", rewardCash = 5000,   specialItem = nil },
        { day = 2, label = "День 2", rewardCash = 12000,  specialItem = nil },
        { day = 3, label = "День 3", rewardCash = 25000,  specialItem = "SpeedCoil" },
        { day = 4, label = "День 4", rewardCash = 50000,  specialItem = nil },
        { day = 5, label = "День 5", rewardCash = 100000, specialItem = "GoldenAura" },
        { day = 6, label = "День 6", rewardCash = 200000, specialItem = nil },
        { day = 7, label = "День 7 (ДЖЕКПОТ)", rewardCash = 500000, specialItem = "GigachadPet" },
    } :: { DailyStreakDay },

    -- Окно сброса стрика (в секундах): если не зашел через 48 часов, стрик сбрасывается на день 1
    STREAK_RESET_WINDOW_SECONDS = 172800, -- 48 часов
    STREAK_CLAIM_COOLDOWN_SECONDS = 86400, -- 24 часа
}

return RetentionConfig
