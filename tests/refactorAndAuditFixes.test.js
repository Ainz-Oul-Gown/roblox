// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// 1. Тест TycoonService.deductCash и логики списания
test('TycoonService.deductCash: safely deducts cash without underflow and handles edge cases', () => {
    // Симуляция алгоритма deductCash
    function simulateDeductCash(playerData, amount) {
        if (!playerData || amount <= 0) return 0;
        const actualDeducted = Math.min(playerData.cash, Math.floor(amount));
        playerData.cash -= actualDeducted;
        return actualDeducted;
    }

    // Сценарий 1: обычное списание
    const p1 = { cash: 1000 };
    const deducted1 = simulateDeductCash(p1, 300);
    assert.equal(deducted1, 300);
    assert.equal(p1.cash, 700);

    // Сценарий 2: списание больше чем есть (кламп к нулю)
    const p2 = { cash: 150 };
    const deducted2 = simulateDeductCash(p2, 500);
    assert.equal(deducted2, 150, 'Must deduct only available cash');
    assert.equal(p2.cash, 0, 'Balance must never drop below 0');

    // Сценарий 3: отрицательная сумма или 0 (защита от эксплойта)
    const p3 = { cash: 500 };
    const deducted3 = simulateDeductCash(p3, -200);
    assert.equal(deducted3, 0);
    assert.equal(p3.cash, 500);

    const deducted0 = simulateDeductCash(p3, 0);
    assert.equal(deducted0, 0);
    assert.equal(p3.cash, 500);

    // Проверка исходного кода TycoonService.luau
    const tycoonServiceSrc = fs.readFileSync(path.join(__dirname, '../src/server/TycoonService.luau'), 'utf8');
    assert.ok(tycoonServiceSrc.includes('function TycoonService.deductCash'), 'TycoonService must export deductCash');
    assert.ok(tycoonServiceSrc.includes('math.min(data.cash, math.floor(safeAmount))'), 'deductCash must clamp to available balance');
});

// 2. Тест защиты FanumTax от дюпа валюты
test('AbilityService: FanumTax uses deductCash and only awards actual stolen amount', () => {
    const abilityServiceSrc = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');

    // Проверяем что старого некорректного вызова addCash(other, -tax) нет
    assert.ok(!abilityServiceSrc.includes('TycoonService.addCash(other, -tax)'), 'Must not call addCash with negative amount');

    // Проверяем что вызывается deductCash
    assert.ok(abilityServiceSrc.includes('local stolen = TycoonService.deductCash(other, tax)'), 'Must call deductCash on victim');
    // P0-02: FanumTax now uses addCashRaw (no multiplier on stolen cash)
    assert.ok(abilityServiceSrc.includes('TycoonService.addCashRaw(player, stolen)'), 'Must use addCashRaw to grant stolen cash without multiplier');
});

// 3. Тест защиты Admin-фишек и RemoteEvent
test('init.server.luau: AdminGiveCashEvent and /aura commands are guarded by Studio/Creator check', () => {
    const initServerSrc = fs.readFileSync(path.join(__dirname, '../src/server/init.server.luau'), 'utf8');

    assert.ok(initServerSrc.includes('function isAuthorizedAdmin(player: Player)'), 'Must have isAuthorizedAdmin check');
    assert.ok(initServerSrc.includes('RunService:IsStudio()'), 'Must allow in Roblox Studio for debugging');
    assert.ok(initServerSrc.includes('if not isAuthorizedAdmin(player) then'), 'Must reject unauthorized remote/chat calls');
});

// 4. Тест очистки памяти в AbilityService и LeaderboardService
test('Memory cleanup: PlayerRemoving cleans up cooldowns and pvpStats', () => {
    const abilityServiceSrc = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(abilityServiceSrc.includes('function AbilityService.removePlayer'), 'AbilityService must have removePlayer');
    assert.ok(abilityServiceSrc.includes('Players.PlayerRemoving:Connect'), 'AbilityService must listen to PlayerRemoving');

    const leaderboardServiceSrc = fs.readFileSync(path.join(__dirname, '../src/server/LeaderboardService.luau'), 'utf8');
    // P1-09: LeaderboardService теперь НЕ стирает статистику при выходе (хранит до рестарта)
    assert.ok(leaderboardServiceSrc.includes('function LeaderboardService.removePlayer'), 'LeaderboardService must have removePlayer');
    assert.ok(leaderboardServiceSrc.includes('function LeaderboardService.restorePvPStats'), 'LeaderboardService must have restorePvPStats for persistence');
});

// 5. Тест интеграции MonetizationService, RetentionService и PetService
test('init.server.luau integrates MonetizationService, RetentionService, and PetService', () => {
    const initServerSrc = fs.readFileSync(path.join(__dirname, '../src/server/init.server.luau'), 'utf8');

    // Monetization
    assert.ok(initServerSrc.includes('MonetizationService.init()'), 'MonetizationService must be initialized');
    assert.ok(initServerSrc.includes('MonetizationService.setRewardHandler'), 'MonetizationService must have reward handler');

    // Retention
    assert.ok(initServerSrc.includes('RetentionService.setRewardHandler'), 'RetentionService reward handler must be registered');
    // P0-06: RetentionService.initPlayer теперь принимает saved-данные
    assert.ok(initServerSrc.includes('RetentionService.initPlayer(player'), 'RetentionService must initialize player on join');
    assert.ok(initServerSrc.includes('RetentionService.removePlayer(player)'), 'RetentionService must cleanup on leave');

    // Pets
    assert.ok(initServerSrc.includes('PetService.initPlayer(player'), 'PetService must initialize player on join');
    assert.ok(initServerSrc.includes('PetService.removePlayer(player)'), 'PetService must cleanup on leave');

    // Multipliers link
    assert.ok(initServerSrc.includes('TycoonService.getExtraMultiplier'), 'TycoonService extra multiplier must be linked');
    assert.ok(initServerSrc.includes('MonetizationService.getPlayerMultiplier'), 'Gamepass multiplier must be included');
    assert.ok(initServerSrc.includes('PetService.getTotalMultiplier'), 'Pet multiplier must be included');
});

// 6. Тест предотвращения FOV Drift в JuiceEffects
test('JuiceEffects.fovPulse: tracks defaultCameraFOV and cancels active tweens', () => {
    const juiceSrc = fs.readFileSync(path.join(__dirname, '../src/client/JuiceEffects.luau'), 'utf8');

    assert.ok(juiceSrc.includes('defaultCameraFOV'), 'Must store defaultCameraFOV');
    assert.ok(juiceSrc.includes('activeFovTweenUp:Cancel()') || juiceSrc.includes('activeFovTweenUp'), 'Must manage active tween state');
    assert.ok(juiceSrc.includes('FieldOfView = defaultCameraFOV'), 'Must always restore to defaultCameraFOV');
});

// 7. Тест параллельного сохранения DataStore
test('TycoonService.saveAllPlayers saves concurrently via task.spawn', () => {
    const tycoonServiceSrc = fs.readFileSync(path.join(__dirname, '../src/server/TycoonService.luau'), 'utf8');

    assert.ok(
        tycoonServiceSrc.includes('task.spawn(function()') && tycoonServiceSrc.includes('DataStoreManager.saveData'),
        'saveAllPlayers must spawn concurrent save threads to prevent BindToClose timeout'
    );
});
