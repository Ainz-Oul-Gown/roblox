const test = require('node:test');
const assert = require('node:assert/strict');

function calculateRebirthMultiplier(rebirths) {
    if (rebirths < 0) rebirths = 0;
    return 1.0 + (rebirths * 0.5);
}

function canPerformRebirth(cash, ownedItems, requiredItem = "SecondFloor", cost = 1000) {
    if (!ownedItems[requiredItem]) return false;
    if (cash < cost) return false;
    return true;
}

test('Rebirth multiplier calculations', () => {
    assert.equal(calculateRebirthMultiplier(0), 1.0);
    assert.equal(calculateRebirthMultiplier(1), 1.5);
    assert.equal(calculateRebirthMultiplier(2), 2.0);
    assert.equal(calculateRebirthMultiplier(4), 3.0);
});

test('Rebirth requirements check', () => {
    assert.equal(canPerformRebirth(1500, {}), false, 'Must require SecondFloor');
    assert.equal(canPerformRebirth(500, { SecondFloor: true }), false, 'Must require $1000');
    assert.equal(canPerformRebirth(1000, { SecondFloor: true }), true, 'Allowed with exact cost and item');
    assert.equal(canPerformRebirth(2500, { SecondFloor: true }), true);
});
