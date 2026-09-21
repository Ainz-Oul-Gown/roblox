--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RetentionConfig = require(ReplicatedStorage.Shared.RetentionConfig)

export type PlayerRetentionData = {
    sessionStartTime: number,
    claimedPlaytimeTiers: { [number]: boolean },
    dailyStreakDay: number,
    lastDailyClaimTimestamp: number,
}

local RetentionService = {}
local playerDataMap: { [number]: PlayerRetentionData } = {}

type RewardCallback = (player: Player, rewardType: string, amount: number, specialItem: string?) -> boolean
local onRewardGranted: RewardCallback? = nil

function RetentionService.setRewardHandler(handler: RewardCallback)
    onRewardGranted = handler
end

function RetentionService.initPlayer(player: Player, savedStreakDay: number?, lastClaimTimestamp: number?)
    local now = os.time()
    local streakDay = savedStreakDay or 1
    local lastClaim = lastClaimTimestamp or 0

    -- Проверка на сброс стрика (если прошло больше 48 часов)
    if lastClaim > 0 and (now - lastClaim) > RetentionConfig.STREAK_RESET_WINDOW_SECONDS then
        streakDay = 1
    end

    playerDataMap[player.UserId] = {
        sessionStartTime = now,
        claimedPlaytimeTiers = {},
        dailyStreakDay = streakDay,
        lastDailyClaimTimestamp = lastClaim,
    }
end

function RetentionService.getSessionSeconds(player: Player): number
    local data = playerDataMap[player.UserId]
    if not data then return 0 end
    return os.time() - data.sessionStartTime
end

function RetentionService.canClaimPlaytimeReward(player: Player, tier: number): (boolean, string)
    local data = playerDataMap[player.UserId]
    if not data then return false, "Данные игрока не инициализированы" end

    if data.claimedPlaytimeTiers[tier] then
        return false, "Награда уже получена"
    end

    local reward = RetentionConfig.PLAYTIME_REWARDS[tier]
    if not reward then
        return false, "Несуществующий уровень награды"
    end

    local sessionSec = RetentionService.getSessionSeconds(player)
    if sessionSec < reward.requiredSeconds then
        return false, `Требуется еще {reward.requiredSeconds - sessionSec} секунд в игре`
    end

    return true, "OK"
end

function RetentionService.claimPlaytimeReward(player: Player, tier: number): (boolean, string)
    local canClaim, msg = RetentionService.canClaimPlaytimeReward(player, tier)
    if not canClaim then return false, msg end

    local data = playerDataMap[player.UserId]
    local reward = RetentionConfig.PLAYTIME_REWARDS[tier]

    data.claimedPlaytimeTiers[tier] = true
    if onRewardGranted then
        onRewardGranted(player, reward.rewardType, reward.amount, nil)
    end

    return true, `Получена награда: {reward.label} (+{reward.amount} {reward.rewardType})`
end

function RetentionService.canClaimDailyReward(player: Player): (boolean, string)
    local data = playerDataMap[player.UserId]
    if not data then return false, "Данные игрока не инициализированы" end

    local now = os.time()
    if data.lastDailyClaimTimestamp > 0 and (now - data.lastDailyClaimTimestamp) < RetentionConfig.STREAK_CLAIM_COOLDOWN_SECONDS then
        local remaining = RetentionConfig.STREAK_CLAIM_COOLDOWN_SECONDS - (now - data.lastDailyClaimTimestamp)
        return false, `Следующая награда доступна через {math.floor(remaining / 3600)} ч.`
    end

    return true, "OK"
end

function RetentionService.claimDailyReward(player: Player): (boolean, string)
    local canClaim, msg = RetentionService.canClaimDailyReward(player)
    if not canClaim then return false, msg end

    local data = playerDataMap[player.UserId]
    local now = os.time()

    local dayConfig = RetentionConfig.DAILY_STREAK[data.dailyStreakDay]
    if not dayConfig then
        dayConfig = RetentionConfig.DAILY_STREAK[1]
    end

    data.lastDailyClaimTimestamp = now
    if onRewardGranted then
        onRewardGranted(player, "Cash", dayConfig.rewardCash, dayConfig.specialItem)
    end

    -- Продвижение стрика: если достиг 7 дня, зацикливаем на 1
    local currentDay = data.dailyStreakDay
    if currentDay >= 7 then
        data.dailyStreakDay = 1
    else
        data.dailyStreakDay = currentDay + 1
    end

    return true, `Забран {dayConfig.label}: +{dayConfig.rewardCash} Cash!`
end

function RetentionService.removePlayer(player: Player)
    playerDataMap[player.UserId] = nil
end

return RetentionService
