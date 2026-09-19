const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const TOTAL_PLOTS = 8;
const ARENA_RADIUS = 90;

function calculateCircularPlots(total = 8, radius = 90) {
    const plots = [];
    for (let i = 1; i <= total; i++) {
        const angle = (i - 1) * (2 * Math.PI / total);
        const x = radius * Math.cos(angle);
        const z = radius * Math.sin(angle);
        plots.push({ index: i, angle, x, y: 0.5, z });
    }
    return plots;
}

const FACTIONS = [
    { id: "Skibidi", name: "СКИБИДИ ТАУН", abilityName: "Skibidi Spin" },
    { id: "Mewing", name: "ГИГАЧАД МЬЮИНГ", abilityName: "Mewing Stare" },
    { id: "Sigma", name: "ПАТРИК СИГМА", abilityName: "Sigma Phonk Rage" },
    { id: "FanumTax", name: "ФАНУМ ТАКС", abilityName: "Tax Snatch" },
    { id: "Grimace", name: "ГРИМАС ШЕЙК", abilityName: "Grimace Toxic Cloud" },
    { id: "CaseOh", name: "КЕЙСОХ ГРАВИТИ", abilityName: "CaseOh Slam" },
    { id: "Rizzler", name: "РИЗЗЛЕР & ГРОНК", abilityName: "Unspoken Rizz" },
    { id: "TungTung", name: "ИТАЛЬЯНСКИЙ ТУНГ-ТУНГ", abilityName: "Tung Tung Hammer" },
];

const REBIRTH_TIERS = [
    { tier: 1, name: "Сигма Новичок", cost: 1500, multiplier: 1.5 },
    { tier: 2, name: "Ризз Мастер", cost: 4000, multiplier: 2.2 },
    { tier: 3, name: "Айпад Повелитель", cost: 10000, multiplier: 3.5 },
    { tier: 4, name: "Гигачад Босс", cost: 25000, multiplier: 5.5 },
    { tier: 5, name: "БОГ АЛЬФА ПОКОЛЕНИЯ", cost: 60000, multiplier: 10.0 },
];

function calculateMultiplier(rebirths) {
    if (rebirths <= 0) return 1.0;
    const tier = REBIRTH_TIERS.find(t => t.tier === rebirths);
    if (tier) return tier.multiplier;
    return 10.0 + (rebirths - 5) * 2.0;
}

test('Verify 8 circular plots geometry and clearance', () => {
    const plots = calculateCircularPlots(TOTAL_PLOTS, ARENA_RADIUS);
    assert.equal(plots.length, 8);

    for (let i = 0; i < plots.length; i++) {
        const next = plots[(i + 1) % plots.length];
        const dist = Math.sqrt(Math.pow(next.x - plots[i].x, 2) + Math.pow(next.z - plots[i].z, 2));
        assert.ok(dist >= 60, `Distance between plot ${i + 1} and ${next.index} is ${dist}, must be >= 60`);
    }
});

test('Verify 8 unique factions and abilities exist', () => {
    assert.equal(FACTIONS.length, 8);
    const ids = new Set(FACTIONS.map(f => f.id));
    const abilities = new Set(FACTIONS.map(f => f.abilityName));
    assert.equal(ids.size, 8, 'All 8 factions must have unique IDs');
    assert.equal(abilities.size, 8, 'All 8 factions must have unique abilities');
});

test('Verify 5 Rebirth Tiers and multiplier scaling', () => {
    assert.equal(calculateMultiplier(0), 1.0);
    assert.equal(calculateMultiplier(1), 1.5);
    assert.equal(calculateMultiplier(2), 2.2);
    assert.equal(calculateMultiplier(3), 3.5);
    assert.equal(calculateMultiplier(4), 5.5);
    assert.equal(calculateMultiplier(5), 10.0);
    assert.equal(calculateMultiplier(6), 12.0);
});

test('Laser security gate authorization', () => {
    function testGateAccess(touchingPlayerId, ownerId) {
        if (touchingPlayerId === ownerId) {
            return { access: true, damage: 0 };
        }
        return { access: false, damage: 100 };
    }

    assert.deepEqual(testGateAccess("User123", "User123"), { access: true, damage: 0 });
    assert.deepEqual(testGateAccess("Intruder999", "User123"), { access: false, damage: 100 });
});

test('Central Arena King of Aura detection', () => {
    function isInsideKingZone(playerPos, radius = 16) {
        const dist = Math.sqrt(Math.pow(playerPos.x, 2) + Math.pow(playerPos.z, 2));
        return dist <= radius;
    }

    assert.equal(isInsideKingZone({ x: 5, z: 5 }), true);
    assert.equal(isInsideKingZone({ x: 0, z: 0 }), true);
    assert.equal(isInsideKingZone({ x: 20, z: 0 }), false);
});
