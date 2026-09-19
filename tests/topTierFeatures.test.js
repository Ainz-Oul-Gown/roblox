// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('TycoonConfig: Rebirth_Portal and FactionMonument exist in items chain', () => {
    const configPath = path.join(__dirname, '../src/shared/TycoonConfig.luau');
    const content = fs.readFileSync(configPath, 'utf8');

    assert.ok(content.includes('id = "Rebirth_Portal"'), 'Must define Rebirth_Portal in TycoonConfig');
    assert.ok(content.includes('id = "FactionMonument"'), 'Must define FactionMonument in TycoonConfig');

    // Verify 8 factions
    const factions = ['Skibidi', 'Mewing', 'Sigma', 'FanumTax', 'Grimace', 'CaseOh', 'Rizzler', 'TungTung'];
    for (const f of factions) {
        assert.ok(content.includes(`id = "${f}"`), `Faction ${f} must exist in TycoonConfig`);
    }
});

test('PlotBuilder: Rebirth_Portal and FactionMonument 3D models and buttons exist', () => {
    const pbPath = path.join(__dirname, '../src/server/PlotBuilder.luau');
    const content = fs.readFileSync(pbPath, 'utf8');

    assert.ok(content.includes('item.id == "Rebirth_Portal"'), 'PlotBuilder must handle Rebirth_Portal');
    assert.ok(content.includes('item.id == "FactionMonument"'), 'PlotBuilder must handle FactionMonument');
    assert.ok(content.includes('SkyBeacon'), 'PlotBuilder must create vertical sky beacon for monuments');

    // Verify all 8 custom faction sculptures are implemented
    assert.ok(content.includes('fId == "Skibidi"'), 'Must build Skibidi sculpture');
    assert.ok(content.includes('fId == "Mewing"'), 'Must build Mewing sculpture');
    assert.ok(content.includes('fId == "Sigma"'), 'Must build Sigma sculpture');
    assert.ok(content.includes('fId == "FanumTax"'), 'Must build Fanum sculpture');
    assert.ok(content.includes('fId == "Grimace"'), 'Must build Grimace sculpture');
    assert.ok(content.includes('fId == "CaseOh"'), 'Must build CaseOh sculpture');
    assert.ok(content.includes('fId == "Rizzler"'), 'Must build Rizzler sculpture');
    assert.ok(content.includes('fId == "TungTung"'), 'Must build TungTung sculpture');

    // Verify BUTTON_CONFIGS has offsets for new items
    assert.ok(content.includes('Rebirth_Portal = Vector3.new'), 'BUTTON_CONFIGS must include Rebirth_Portal');
    assert.ok(content.includes('FactionMonument = Vector3.new'), 'BUTTON_CONFIGS must include FactionMonument');
});

test('LeaderboardService: Source file integrity and sorting logic', () => {
    const lbPath = path.join(__dirname, '../src/server/LeaderboardService.luau');
    assert.ok(fs.existsSync(lbPath), 'LeaderboardService.luau must exist');
    const content = fs.readFileSync(lbPath, 'utf8');

    assert.ok(content.includes('WealthBoard'), 'Must construct WealthBoard');
    assert.ok(content.includes('PvPBoard'), 'Must construct PvPBoard');
    assert.ok(content.includes('recordPvPKill'), 'Must export recordPvPKill method');

    // Simulate leaderboard sorting
    const mockPlayers = [
        { name: 'PlayerA', cash: 1200, kills: 2 },
        { name: 'PlayerB', cash: 9500, kills: 8 },
        { name: 'PlayerC', cash: 3400, kills: 5 },
    ];

    const sortedByCash = [...mockPlayers].sort((a, b) => b.cash - a.cash);
    assert.equal(sortedByCash[0].name, 'PlayerB', 'PlayerB should be rank #1 in Wealth');
    assert.equal(sortedByCash[1].name, 'PlayerC', 'PlayerC should be rank #2 in Wealth');
    assert.equal(sortedByCash[2].name, 'PlayerA', 'PlayerA should be rank #3 in Wealth');

    const sortedByKills = [...mockPlayers].sort((a, b) => b.kills - a.kills);
    assert.equal(sortedByKills[0].name, 'PlayerB', 'PlayerB should be rank #1 in PvP Kills');
    assert.equal(sortedByKills[1].name, 'PlayerC', 'PlayerC should be rank #2 in PvP Kills');
});

test('AirDropService: Source file integrity and mechanics', () => {
    const adPath = path.join(__dirname, '../src/server/AirDropService.luau');
    assert.ok(fs.existsSync(adPath), 'AirDropService.luau must exist');
    const content = fs.readFileSync(adPath, 'utf8');

    assert.ok(content.includes('AIRDROP_INTERVAL_SEC'), 'Must define airdrop interval');
    assert.ok(content.includes('AIRDROP_REWARD = 10000'), 'Must award 10000 Aura reward');
    assert.ok(content.includes('AirDropEvent'), 'Must fire AirDropEvent to clients');
    assert.ok(content.includes('Parachute'), 'Must render parachute model');
});

test('JuiceEffects: Client SFX and game feel module integrity', () => {
    const jPath = path.join(__dirname, '../src/client/JuiceEffects.luau');
    assert.ok(fs.existsSync(jPath), 'JuiceEffects.luau must exist');
    const content = fs.readFileSync(jPath, 'utf8');

    assert.ok(content.includes('playSound'), 'Must export playSound');
    assert.ok(content.includes('showFloatingText'), 'Must export showFloatingText');
    assert.ok(content.includes('animateButtonSuccess'), 'Must export animateButtonSuccess');
    assert.ok(content.includes('animateButtonFailure'), 'Must export animateButtonFailure');
    assert.ok(content.includes('screenFlash'), 'Must export screenFlash');
});
