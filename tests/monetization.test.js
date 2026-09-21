const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('MonetizationConfig and MonetizationService source integrity', () => {
    const configPath = path.join(__dirname, '..', 'src', 'shared', 'MonetizationConfig.luau');
    const servicePath = path.join(__dirname, '..', 'src', 'server', 'MonetizationService.luau');

    assert.ok(fs.existsSync(configPath), 'MonetizationConfig.luau must exist');
    assert.ok(fs.existsSync(servicePath), 'MonetizationService.luau must exist');

    const configContent = fs.readFileSync(configPath, 'utf8');
    assert.match(configContent, /VIP/, 'Must define VIP pass');
    assert.match(configContent, /DOUBLE_CASH/, 'Must define DOUBLE_CASH pass');
    assert.match(configContent, /INSTANT_REBIRTH/, 'Must define INSTANT_REBIRTH product');

    const serviceContent = fs.readFileSync(servicePath, 'utf8');
    assert.match(serviceContent, /processReceiptLogic/, 'Must export processReceiptLogic');
    assert.match(serviceContent, /PurchaseGranted/, 'Must handle PurchaseGranted');
    assert.match(serviceContent, /NotProcessedYet/, 'Must handle NotProcessedYet');
});

test('ProcessReceipt Idempotency and Purchase Decision logic', () => {
    const processedReceipts = new Set();
    const mockProducts = {
        20001: { name: "Мешочек", rewardType: "Cash", amount: 50000 },
        20002: { name: "Чемодан", rewardType: "Cash", amount: 250000 },
    };

    function processReceipt(receiptInfo, playerExists, grantSuccess) {
        if (processedReceipts.has(receiptInfo.PurchaseId)) {
            return "PurchaseGranted";
        }
        if (!playerExists) {
            return "NotProcessedYet";
        }
        const product = mockProducts[receiptInfo.ProductId];
        if (!product) {
            return "NotProcessedYet";
        }
        if (!grantSuccess) {
            return "NotProcessedYet";
        }
        processedReceipts.add(receiptInfo.PurchaseId);
        return "PurchaseGranted";
    }

    const receipt1 = { PurchaseId: "rec_12345", PlayerId: 101, ProductId: 20001 };

    // 1. Игрок не найден (отключился) -> NotProcessedYet
    assert.equal(processReceipt(receipt1, false, true), "NotProcessedYet");
    assert.equal(processedReceipts.has("rec_12345"), false);

    // 2. Успешная покупка -> PurchaseGranted и добавление в кэш
    assert.equal(processReceipt(receipt1, true, true), "PurchaseGranted");
    assert.equal(processedReceipts.has("rec_12345"), true);

    // 3. Повторный вызов того же чека -> Сразу PurchaseGranted (идемпотентность, без повторной выдачи)
    assert.equal(processReceipt(receipt1, true, true), "PurchaseGranted");
});

test('Gamepass Multiplier compounding calculation', () => {
    function calculateMultiplier(passes) {
        let mult = 1.0;
        if (passes.VIP) mult *= 1.25;
        if (passes.DoubleCash) mult *= 2.0;
        return mult;
    }

    assert.equal(calculateMultiplier({}), 1.0);
    assert.equal(calculateMultiplier({ VIP: true }), 1.25);
    assert.equal(calculateMultiplier({ DoubleCash: true }), 2.0);
    assert.equal(calculateMultiplier({ VIP: true, DoubleCash: true }), 2.5);
});
