const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Reference item configs matching TycoonConfig.luau
const ITEMS = [
    { id: "Collector", name: "Сборщик монет", cost: 0, category: "Collector", dependsOn: null },
    { id: "StarterDropper", name: "Начальный дроппер", cost: 0, category: "Dropper", dependsOn: "Collector", dropValue: 1 },
    { id: "Walls", name: "Базовые стены", cost: 25, category: "Structure", dependsOn: "StarterDropper" },
    { id: "UpgradedDropper", name: "Улучшенный дроппер", cost: 75, category: "Dropper", dependsOn: "Walls", dropValue: 5 },
    { id: "Roof", name: "Крыша базы", cost: 150, category: "Structure", dependsOn: "UpgradedDropper" },
    { id: "GoldDropper", name: "Золотой супер-дроппер", cost: 350, category: "Dropper", dependsOn: "Roof", dropValue: 25 },
    { id: "SecondFloor", name: "Второй этаж", cost: 700, category: "Structure", dependsOn: "GoldDropper" }
];

function getItemById(id) {
    return ITEMS.find(item => item.id === id) || null;
}

const EconomyManager = {
    canAfford(currentBalance, cost) {
        return currentBalance >= cost && cost >= 0;
    },
    deductCash(currentBalance, cost) {
        if (!this.canAfford(currentBalance, cost)) {
            throw new Error("Insufficient funds or invalid cost");
        }
        return currentBalance - cost;
    },
    addCash(currentBalance, amount, multiplier = 1.0) {
        let mult = multiplier < 1.0 ? 1.0 : multiplier;
        if (amount < 0) return currentBalance;
        return currentBalance + Math.floor(amount * mult);
    },
    canPurchaseItem(currentBalance, ownedItemIds, itemId) {
        if (ownedItemIds[itemId]) {
            return [false, "Already owned"];
        }
        const item = getItemById(itemId);
        if (!item) {
            return [false, "Item not found in config"];
        }
        if (item.dependsOn && !ownedItemIds[item.dependsOn]) {
            return [false, `Requires prerequisite: ${item.dependsOn}`];
        }
        if (!this.canAfford(currentBalance, item.cost)) {
            return [false, "Insufficient funds"];
        }
        return [true, null];
    }
};

test('Verify Tycoon Luau source files exist', () => {
    const configPath = path.join(__dirname, '..', 'src', 'shared', 'TycoonConfig.luau');
    const econPath = path.join(__dirname, '..', 'src', 'shared', 'EconomyManager.luau');
    const servicePath = path.join(__dirname, '..', 'src', 'server', 'TycoonService.luau');

    assert.ok(fs.existsSync(configPath), 'TycoonConfig.luau must exist');
    assert.ok(fs.existsSync(econPath), 'EconomyManager.luau must exist');
    assert.ok(fs.existsSync(servicePath), 'TycoonService.luau must exist');
});

test('EconomyManager: canAfford and deductCash', () => {
    assert.equal(EconomyManager.canAfford(100, 50), true);
    assert.equal(EconomyManager.canAfford(50, 50), true);
    assert.equal(EconomyManager.canAfford(49, 50), false);
    assert.equal(EconomyManager.canAfford(50, -10), false);

    assert.equal(EconomyManager.deductCash(100, 40), 60);
    assert.throws(() => EconomyManager.deductCash(30, 50), /Insufficient funds/);
});

test('EconomyManager: addCash with multipliers', () => {
    assert.equal(EconomyManager.addCash(0, 10), 10);
    assert.equal(EconomyManager.addCash(50, 20, 1.5), 80);
    assert.equal(EconomyManager.addCash(100, -10), 100);
    assert.equal(EconomyManager.addCash(100, 10, 0.5), 110); // Minimum multiplier clamped to 1.0
});

test('EconomyManager: canPurchaseItem validation', () => {
    const owned = {};

    // Collector has no prerequisite and cost is 0
    let [canBuy, reason] = EconomyManager.canPurchaseItem(0, owned, "Collector");
    assert.equal(canBuy, true);
    assert.equal(reason, null);

    // StarterDropper requires Collector
    [canBuy, reason] = EconomyManager.canPurchaseItem(0, owned, "StarterDropper");
    assert.equal(canBuy, false);
    assert.match(reason, /Requires prerequisite: Collector/);

    // Now own Collector
    owned["Collector"] = true;
    [canBuy] = EconomyManager.canPurchaseItem(0, owned, "StarterDropper");
    assert.equal(canBuy, true);

    // Buy StarterDropper
    owned["StarterDropper"] = true;

    // Walls cost 25
    [canBuy, reason] = EconomyManager.canPurchaseItem(10, owned, "Walls");
    assert.equal(canBuy, false);
    assert.match(reason, /Insufficient funds/);

    [canBuy] = EconomyManager.canPurchaseItem(25, owned, "Walls");
    assert.equal(canBuy, true);

    // Already owned check
    [canBuy, reason] = EconomyManager.canPurchaseItem(100, owned, "Collector");
    assert.equal(canBuy, false);
    assert.match(reason, /Already owned/);
});
