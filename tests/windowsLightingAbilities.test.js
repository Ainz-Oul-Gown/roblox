// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('TycoonConfig: All 8 factions have 6 unique thematic abilities (48 total)', () => {
    const configPath = path.join(__dirname, '../src/shared/TycoonConfig.luau');
    const content = fs.readFileSync(configPath, 'utf8');

    // 6 ability definitions per faction
    assert.ok(content.includes('baseAbility = {'), 'Must define baseAbility');
    assert.ok(content.includes('tacticalAbility = {'), 'Must define tacticalAbility');
    assert.ok(content.includes('ultimateAbility = {'), 'Must define ultimateAbility');
    assert.ok(content.includes('specialAbility = {'), 'Must define specialAbility [F]');
    assert.ok(content.includes('mobilityAbility = {'), 'Must define mobilityAbility [Z]');
    assert.ok(content.includes('godmodeAbility = {'), 'Must define godmodeAbility [X]');

    // Check specific new abilities for factions
    assert.ok(content.includes('Skibidi_Special'), 'Skibidi must have special ability');
    assert.ok(content.includes('Skibidi_Mobility'), 'Skibidi must have mobility ability');
    assert.ok(content.includes('Skibidi_Godmode'), 'Skibidi must have godmode ability');

    assert.ok(content.includes('Mewing_Special'), 'Mewing must have special ability');
    assert.ok(content.includes('Mewing_Mobility'), 'Mewing must have mobility ability');
    assert.ok(content.includes('Mewing_Godmode'), 'Mewing must have godmode ability');

    assert.ok(content.includes('Sigma_Special'), 'Sigma must have special ability');
    assert.ok(content.includes('Sigma_Mobility'), 'Sigma must have mobility ability');
    assert.ok(content.includes('Sigma_Godmode'), 'Sigma must have godmode ability');

    assert.ok(content.includes('FanumTax_Special'), 'FanumTax must have special ability');
    assert.ok(content.includes('FanumTax_Mobility'), 'FanumTax must have mobility ability');
    assert.ok(content.includes('FanumTax_Godmode'), 'FanumTax must have godmode ability');

    assert.ok(content.includes('Grimace_Special'), 'Grimace must have special ability');
    assert.ok(content.includes('Grimace_Mobility'), 'Grimace must have mobility ability');
    assert.ok(content.includes('Grimace_Godmode'), 'Grimace must have godmode ability');

    assert.ok(content.includes('CaseOh_Special'), 'CaseOh must have special ability');
    assert.ok(content.includes('CaseOh_Mobility'), 'CaseOh must have mobility ability');
    assert.ok(content.includes('CaseOh_Godmode'), 'CaseOh must have godmode ability');

    assert.ok(content.includes('Rizzler_Special'), 'Rizzler must have special ability');
    assert.ok(content.includes('Rizzler_Mobility'), 'Rizzler must have mobility ability');
    assert.ok(content.includes('Rizzler_Godmode'), 'Rizzler must have godmode ability');

    assert.ok(content.includes('TungTung_Special'), 'TungTung must have special ability');
    assert.ok(content.includes('TungTung_Mobility'), 'TungTung must have mobility ability');
    assert.ok(content.includes('TungTung_Godmode'), 'TungTung must have godmode ability');
});

test('TycoonConfig: Optional Windows, Lighting, and new AbilityStands exist in ITEMS', () => {
    const configPath = path.join(__dirname, '../src/shared/TycoonConfig.luau');
    const content = fs.readFileSync(configPath, 'utf8');

    const expectedNewItems = [
        'Lighting_Floor1',
        'Windows_Floor1',
        'AbilityStand_Special',
        'AbilityStand_Mobility',
        'Lighting_Floor2',
        'Windows_Floor2',
        'AbilityStand_Godmode',
    ];

    for (const id of expectedNewItems) {
        assert.ok(content.includes(`id = "${id}"`), `Item ${id} must be defined in ITEMS`);
    }
});

test('PlotBuilder: LaserGate door control switch for guest passage', () => {
    const pbPath = path.join(__dirname, '../src/server/PlotBuilder.luau');
    const content = fs.readFileSync(pbPath, 'utf8');

    assert.ok(content.includes('GateControlSwitch'), 'Must create GateControlSwitch part');
    assert.ok(content.includes('SwitchButton'), 'Must create SwitchButton part');
    assert.ok(content.includes('ProximityPrompt'), 'Must have ProximityPrompt for gate toggle');
    assert.ok(content.includes('ClickDetector'), 'Must have ClickDetector for click toggle');
    assert.ok(content.includes('gateOpen = not gateOpen'), 'Must toggle gateOpen state');
    assert.ok(content.includes('if gateOpen then return end'), 'Must bypass damage when gateOpen is true');
});

test('PlotBuilder: 3D models and buttons for new items', () => {
    const pbPath = path.join(__dirname, '../src/server/PlotBuilder.luau');
    const content = fs.readFileSync(pbPath, 'utf8');

    // Structures
    assert.ok(content.includes('item.id == "Lighting_Floor1"'), 'Must have Lighting_Floor1 handler');
    assert.ok(content.includes('item.id == "Windows_Floor1"'), 'Must have Windows_Floor1 handler');
    assert.ok(content.includes('item.id == "AbilityStand_Special"'), 'Must have AbilityStand_Special handler');
    assert.ok(content.includes('item.id == "AbilityStand_Mobility"'), 'Must have AbilityStand_Mobility handler');
    assert.ok(content.includes('item.id == "Lighting_Floor2"'), 'Must have Lighting_Floor2 handler');
    assert.ok(content.includes('item.id == "Windows_Floor2"'), 'Must have Windows_Floor2 handler');
    assert.ok(content.includes('item.id == "AbilityStand_Godmode"'), 'Must have AbilityStand_Godmode handler');

    // Button coordinates
    assert.ok(content.includes('Lighting_Floor1 = Vector3.new'), 'Must have button for Lighting_Floor1');
    assert.ok(content.includes('Windows_Floor1 = Vector3.new'), 'Must have button for Windows_Floor1');
    assert.ok(content.includes('AbilityStand_Special = Vector3.new'), 'Must have button for AbilityStand_Special');
    assert.ok(content.includes('AbilityStand_Mobility = Vector3.new'), 'Must have button for AbilityStand_Mobility');
    assert.ok(content.includes('Lighting_Floor2 = Vector3.new'), 'Must have button for Lighting_Floor2');
    assert.ok(content.includes('Windows_Floor2 = Vector3.new'), 'Must have button for Windows_Floor2');
    assert.ok(content.includes('AbilityStand_Godmode = Vector3.new'), 'Must have button for AbilityStand_Godmode');
});

test('AbilityService: Handles 6 slots and hotbar tools [1] through [6]', () => {
    const asPath = path.join(__dirname, '../src/server/AbilityService.luau');
    const content = fs.readFileSync(asPath, 'utf8');

    assert.ok(content.includes('AbilityStand_Special'), 'Must sync AbilityStand_Special');
    assert.ok(content.includes('AbilityStand_Mobility'), 'Must sync AbilityStand_Mobility');
    assert.ok(content.includes('AbilityStand_Godmode'), 'Must sync AbilityStand_Godmode');

    // Check all slots supported
    assert.ok(content.includes('"special"'), 'Must support special slot');
    assert.ok(content.includes('"mobility"'), 'Must support mobility slot');
    assert.ok(content.includes('"godmode"'), 'Must support godmode slot');
});

test('Client HUD: Keybindings for [E], [R], [Q], [F], [Z], [X] and 6-slot cooldown tracking', () => {
    const clientPath = path.join(__dirname, '../src/client/init.client.luau');
    const content = fs.readFileSync(clientPath, 'utf8');

    assert.ok(content.includes('Enum.KeyCode.F'), 'Must have keycode F for special ability');
    assert.ok(content.includes('Enum.KeyCode.Z'), 'Must have keycode Z for mobility ability');
    assert.ok(content.includes('Enum.KeyCode.X'), 'Must have keycode X for godmode ability');

    assert.ok(content.includes('special = 0'), 'Cooldowns must include special');
    assert.ok(content.includes('mobility = 0'), 'Cooldowns must include mobility');
    assert.ok(content.includes('godmode = 0'), 'Cooldowns must include godmode');

    assert.ok(content.includes('[4/F]'), 'Hints must include slot 4 [F]');
    assert.ok(content.includes('[5/Z]'), 'Hints must include slot 5 [Z]');
    assert.ok(content.includes('[6/X]'), 'Hints must include slot 6 [X]');
});
