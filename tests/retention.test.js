const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('RetentionConfig and RetentionService source integrity', () => {
    const configPath = path.join(__dirname, '..', 'src', 'shared', 'RetentionConfig.luau');
    const servicePath = path.join(__dirname, '..', 'src', 'server', 'RetentionService.luau');

    assert.ok(fs.existsSync(configPath), 'RetentionConfig.luau must exist');
    assert.ok(fs.existsSync(servicePath), 'RetentionService.luau must exist');

    const configContent = fs.readFileSync(configPath, 'utf8');
    assert.match(configContent, /PLAYTIME_REWARDS/, 'Must define PLAYTIME_REWARDS');
    assert.match(configContent, /DAILY_STREAK/, 'Must define DAILY_STREAK');

    const serviceContent = fs.readFileSync(servicePath, 'utf8');
    assert.match(serviceContent, /claimPlaytimeReward/, 'Must export claimPlaytimeReward');
    assert.match(serviceContent, /claimDailyReward/, 'Must export claimDailyReward');
});

test('Playtime reward eligibility and single-claim enforcement', () => {
    const rewards = [
        { tier: 1, requiredSeconds: 300, amount: 5000 },
        { tier: 2, requiredSeconds: 600, amount: 15000 },
    ];

    function checkClaim(sessionSeconds, tier, claimedMap) {
        if (claimedMap[tier]) return { canClaim: false, reason: "Already claimed" };
        const reward = rewards.find(r => r.tier === tier);
        if (!reward) return { canClaim: false, reason: "Invalid tier" };
        if (sessionSeconds < reward.requiredSeconds) return { canClaim: false, reason: "Need more time" };
        return { canClaim: true };
    }

    const claimed = {};
    // При 200 сек -> tier 1 еще не доступен
    assert.equal(checkClaim(200, 1, claimed).canClaim, false);

    // При 300 сек -> tier 1 доступен
    assert.equal(checkClaim(300, 1, claimed).canClaim, true);
    claimed[1] = true;

    // Повторный клейм того же уровня заблокирован
    assert.equal(checkClaim(350, 1, claimed).canClaim, false);

    // Tier 2 при 350 сек не доступен
    assert.equal(checkClaim(350, 2, claimed).canClaim, false);
    // При 600 сек tier 2 доступен
    assert.equal(checkClaim(600, 2, claimed).canClaim, true);
});

test('Daily streak progression and 48h reset logic', () => {
    function calculateStreakDay(lastClaimTimestamp, currentStreakDay, nowTimestamp) {
        const SECONDS_24H = 86400;
        const SECONDS_48H = 172800;

        if (lastClaimTimestamp === 0) return { day: 1, canClaim: true };

        const diff = nowTimestamp - lastClaimTimestamp;
        if (diff > SECONDS_48H) {
            // Пропуск больше 48 часов -> сброс на день 1
            return { day: 1, canClaim: true };
        } else if (diff >= SECONDS_24H) {
            // Прошло от 24 до 48 часов -> готов забрать следующий день
            return { day: currentStreakDay, canClaim: true };
        } else {
            // Еще не прошло 24 часа -> кулдаун
            return { day: currentStreakDay, canClaim: false };
        }
    }

    const now = 1000000;
    // 1. Первый вход
    assert.deepEqual(calculateStreakDay(0, 1, now), { day: 1, canClaim: true });

    // 2. Попытка забрать через 5 часов -> кулдаун
    assert.deepEqual(calculateStreakDay(now - 18000, 2, now), { day: 2, canClaim: false });

    // 3. Забор на следующий день (через 25 часов) -> доступно
    assert.deepEqual(calculateStreakDay(now - 90000, 2, now), { day: 2, canClaim: true });

    // 4. Пропуск более 48 часов (через 50 часов) -> сброс на день 1
    assert.deepEqual(calculateStreakDay(now - 180000, 4, now), { day: 1, canClaim: true });
});
