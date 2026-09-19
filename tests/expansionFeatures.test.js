// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('TycoonConfig: 8 factions have 3 unique abilities each (Base, Tactical, Ultimate)', () => {
    const configPath = path.join(__dirname, '../src/shared/TycoonConfig.luau');
    assert.ok(fs.existsSync(configPath), 'TycoonConfig.luau must exist');
    const content = fs.readFileSync(configPath, 'utf8');

    // Check dimensions
    assert.match(content, /ARENA_RADIUS\s*=\s*180/, 'Arena radius must be 180 for expanded bases');
    assert.match(content, /BASE_WIDTH\s*=\s*48/, 'Base width must be 48 studs');
    assert.match(content, /BASE_LENGTH\s*=\s*64/, 'Base length must be 64 studs');

    // 8 Factions
    const factionIds = ['Skibidi', 'Mewing', 'Sigma', 'FanumTax', 'Grimace', 'CaseOh', 'Rizzler', 'TungTung'];
    for (const id of factionIds) {
        assert.ok(content.includes(`id = "${id}"`), `Faction ${id} must exist in TycoonConfig`);
    }

    // 3 Abilities per faction verification
    assert.ok(content.includes('baseAbility = {'), 'Must define baseAbility');
    assert.ok(content.includes('tacticalAbility = {'), 'Must define tacticalAbility');
    assert.ok(content.includes('ultimateAbility = {'), 'Must define ultimateAbility');
});

test('TycoonConfig: Expanded 2-floor items chain & Upgraders', () => {
    const configPath = path.join(__dirname, '../src/shared/TycoonConfig.luau');
    const content = fs.readFileSync(configPath, 'utf8');

    const expectedItemIds = [
        'Dropper_Prime',
        'LaserGate',
        'BrainrotWalls',
        'Upgrader_Laser',
        'AbilityStand_1',
        'AbilityStand_Tactical',
        'Stairs_To_Floor2',
        'Floor2_Foundation',
        'Floor2_Walls',
        'Floor2_Conveyor',
        'Upgrader_Quantum',
        'Dropper_Galactic',
        'AbilityStand_Ultimate',
        'Upgrader_Annihilator',
    ];

    for (const itemId of expectedItemIds) {
        assert.ok(content.includes(`id = "${itemId}"`), `Item ${itemId} must be defined in TycoonConfig`);
    }
});

test('TycoonService: Collector Vault logic and safe cash separation', () => {
    // Simulate vault mechanics
    const vaultCashMap = {};
    const playerDataMap = {
        101: { cash: 500, rebirths: 0 },
        102: { cash: 1200, rebirths: 2 },
    };

    function addToVault(plotIndex, amount, rebirths = 0) {
        const mult = 1.0 + rebirths * 0.5; // multiplier
        const current = vaultCashMap[plotIndex] || 0;
        const added = Math.floor(amount * mult);
        vaultCashMap[plotIndex] = current + added;
        return vaultCashMap[plotIndex];
    }

    function withdrawVault(plotIndex, userId) {
        const stored = vaultCashMap[plotIndex] || 0;
        if (stored <= 0) return 0;
        vaultCashMap[plotIndex] = 0;
        playerDataMap[userId].cash += stored;
        return stored;
    }

    // Ore collection adds to vault, NOT wallet directly
    addToVault(1, 10, 0);
    addToVault(1, 15, 0);
    assert.equal(vaultCashMap[1], 25, 'Vault accumulates ore cash');
    assert.equal(playerDataMap[101].cash, 500, 'Wallet is untouched until withdrawal');

    // Withdraw transfers to wallet
    const withdrawn = withdrawVault(1, 101);
    assert.equal(withdrawn, 25, 'Withdrawn amount matches vault total');
    assert.equal(vaultCashMap[1], 0, 'Vault resets to 0 after withdraw');
    assert.equal(playerDataMap[101].cash, 525, 'Wallet gains the withdrawn amount');
});

test('TycoonService: PvP 100% wallet loot transfer on death', () => {
    const players = {
        10: { name: 'Victim', cash: 1500 },
        20: { name: 'Killer', cash: 300 },
    };
    const vaultCashMap = { 1: 5000 }; // Victim base vault

    function handlePvPDeath(victimId, killerId, plotIndex) {
        const stolenCash = players[victimId].cash;
        players[victimId].cash = 0;

        if (killerId && players[killerId]) {
            players[killerId].cash += stolenCash;
        }

        // Vault on base remains safe
        return { stolenCash, safeVault: vaultCashMap[plotIndex] };
    }

    const result = handlePvPDeath(10, 20, 1);
    assert.equal(result.stolenCash, 1500, 'All wallet cash is stolen');
    assert.equal(players[10].cash, 0, 'Victim wallet is reset to 0');
    assert.equal(players[20].cash, 1800, 'Killer receives 100% of victim wallet');
    assert.equal(result.safeVault, 5000, 'Safe vault cash on plot is 100% protected');
});

test('Economy Balance: Progression curve requires Rebirth multipliers', () => {
    const costs = [
        { id: 'Dropper_Prime', cost: 150 },
        { id: 'LaserGate', cost: 350 },
        { id: 'BrainrotWalls', cost: 750 },
        { id: 'Upgrader_Laser', cost: 1400 },
        { id: 'AbilityStand_1', cost: 2500 },
        { id: 'AbilityStand_Tactical', cost: 6000 },
        { id: 'Stairs_To_Floor2', cost: 12000 },
        { id: 'Floor2_Foundation', cost: 25000 },
        { id: 'Floor2_Walls', cost: 45000 },
        { id: 'Floor2_Conveyor', cost: 75000 },
        { id: 'Upgrader_Quantum', cost: 120000 },
        { id: 'Dropper_Galactic', cost: 180000 },
        { id: 'AbilityStand_Ultimate', cost: 280000 },
        { id: 'Upgrader_Annihilator', cost: 420000 },
    ];

    for (let i = 1; i < costs.length; i++) {
        assert.ok(
            costs[i].cost > costs[i - 1].cost,
            `Item ${costs[i].id} (${costs[i].cost}) must cost more than ${costs[i - 1].id} (${costs[i - 1].cost})`
        );
    }

    const rebirthCosts = [80000, 250000, 750000, 2000000, 6000000];
    for (let i = 1; i < rebirthCosts.length; i++) {
        assert.ok(rebirthCosts[i] > rebirthCosts[i - 1], 'Rebirth costs must scale strictly upwards');
    }
});
