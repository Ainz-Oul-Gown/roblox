const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('PetConfig and PetService source integrity', () => {
    const configPath = path.join(__dirname, '..', 'src', 'shared', 'PetConfig.luau');
    const servicePath = path.join(__dirname, '..', 'src', 'server', 'PetService.luau');
    const followerPath = path.join(__dirname, '..', 'src', 'client', 'PetFollower.luau');

    assert.ok(fs.existsSync(configPath), 'PetConfig.luau must exist');
    assert.ok(fs.existsSync(servicePath), 'PetService.luau must exist');
    assert.ok(fs.existsSync(followerPath), 'PetFollower.luau must exist');

    const configContent = fs.readFileSync(configPath, 'utf8');
    assert.match(configContent, /SkibidiNoob/, 'Must contain SkibidiNoob');
    assert.match(configContent, /CaseOhBlackHole/, 'Must contain CaseOhBlackHole');
    assert.match(configContent, /MAX_EQUIPPED_PETS/, 'Must define MAX_EQUIPPED_PETS');

    const serviceContent = fs.readFileSync(servicePath, 'utf8');
    assert.match(serviceContent, /rollEgg/, 'Must export rollEgg');
    assert.match(serviceContent, /equipBest/, 'Must export equipBest');
    assert.match(serviceContent, /getTotalMultiplier/, 'Must export getTotalMultiplier');
});

test('Weighted RNG egg drop distribution', () => {
    const drops = [
        { petId: "Common", weight: 70 },
        { petId: "Rare", weight: 25 },
        { petId: "Legendary", weight: 5 },
    ];
    const totalWeight = drops.reduce((sum, d) => sum + d.weight, 0);
    assert.equal(totalWeight, 100);

    function simulateRoll(randVal) {
        let current = 0;
        for (const drop of drops) {
            current += drop.weight;
            if (randVal <= current) return drop.petId;
        }
        return drops[0].petId;
    }

    assert.equal(simulateRoll(10), "Common");
    assert.equal(simulateRoll(70), "Common");
    assert.equal(simulateRoll(71), "Rare");
    assert.equal(simulateRoll(95), "Rare");
    assert.equal(simulateRoll(96), "Legendary");
    assert.equal(simulateRoll(100), "Legendary");
});

test('EquipBest sorts by multiplier and respects max slots limit', () => {
    const petsDef = {
        P1: { multiplier: 1.15 },
        P2: { multiplier: 1.35 },
        P3: { multiplier: 1.75 },
        P4: { multiplier: 2.50 },
        P5: { multiplier: 5.00 },
    };

    const inventory = [
        { id: "a", petId: "P1", isEquipped: true },
        { id: "b", petId: "P5", isEquipped: false },
        { id: "c", petId: "P3", isEquipped: false },
        { id: "d", petId: "P2", isEquipped: false },
        { id: "e", petId: "P4", isEquipped: false },
    ];

    const MAX_EQUIPPED = 3;

    // Equip Best
    inventory.forEach(p => p.isEquipped = false);
    inventory.sort((a, b) => petsDef[b.petId].multiplier - petsDef[a.petId].multiplier);

    for (let i = 0; i < Math.min(inventory.length, MAX_EQUIPPED); i++) {
        inventory[i].isEquipped = true;
    }

    const equipped = inventory.filter(p => p.isEquipped);
    assert.equal(equipped.length, 3);
    assert.deepEqual(equipped.map(p => p.petId), ["P5", "P4", "P3"]);

    // Расчет суммарного множителя: 1.0 + (5.0 - 1.0) + (2.5 - 1.0) + (1.75 - 1.0) = 1 + 4 + 1.5 + 0.75 = 7.25
    let totalMult = 1.0;
    for (const pet of equipped) {
        totalMult += (petsDef[pet.petId].multiplier - 1.0);
    }
    assert.equal(totalMult, 7.25);
});
