// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('JuiceEffects: exports comprehensive sound catalog and dynamic screen effects', () => {
    const juicePath = path.join(__dirname, '../src/client/JuiceEffects.luau');
    const content = fs.readFileSync(juicePath, 'utf8');

    // Check sound catalog IDs
    const expectedSounds = [
        'laser', 'dash', 'explosion', 'electric', 'magic', 'teleport',
        'meteor', 'hammer', 'splash', 'whoosh', 'chime', 'horn', 'parry', 'snatch', 'anvil'
    ];
    for (const s of expectedSounds) {
        assert.ok(content.includes(s + ' ='), `JuiceEffects must define sound ${s}`);
    }

    // Check spatial 3D audio & dynamic effects functions
    assert.ok(content.includes('function JuiceEffects.play3DSound'), 'JuiceEffects must implement play3DSound');
    assert.ok(content.includes('function JuiceEffects.screenShake'), 'JuiceEffects must implement screenShake');
    assert.ok(content.includes('function JuiceEffects.fovPulse'), 'JuiceEffects must implement fovPulse');
    assert.ok(content.includes('function JuiceEffects.traumaShake'), 'JuiceEffects must implement traumaShake');
    assert.ok(content.includes('function JuiceEffects.cameraKick'), 'JuiceEffects must implement cameraKick');
    assert.ok(content.includes('function JuiceEffects.hitstop'), 'JuiceEffects must implement hitstop');
    assert.ok(content.includes('function JuiceEffects.impactFlash'), 'JuiceEffects must implement impactFlash');
    assert.ok(content.includes('function JuiceEffects.spawnLightBurst'), 'JuiceEffects must implement spawnLightBurst');
    assert.ok(content.includes('function JuiceEffects.screenBloomFlash'), 'JuiceEffects must implement screenBloomFlash');
    assert.ok(content.includes('sound.PlaybackSpeed ='), 'JuiceEffects must randomize PlaybackSpeed for pitch variation');
});

test('AbilityVFX: implements audiovisual rendering for all 8 factions and 6 ability slots', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    const factions = [
        'Skibidi', 'Mewing', 'Sigma', 'FanumTax',
        'Grimace', 'CaseOh', 'Rizzler', 'TungTung'
    ];

    for (const f of factions) {
        assert.ok(content.includes(`fId == "${f}"`), `AbilityVFX must handle faction ${f}`);
    }

    const slots = ['base', 'tactical', 'ultimate', 'special', 'mobility', 'godmode'];
    for (const s of slots) {
        assert.ok(content.includes(`slot == "${s}"`), `AbilityVFX must handle slot ${s}`);
    }

    // Check visual helpers
    assert.ok(content.includes('createShockwaveRing'), 'Must implement createShockwaveRing');
    assert.ok(content.includes('createPillarOfLight'), 'Must implement createPillarOfLight');
    assert.ok(content.includes('createBeamLine'), 'Must implement createBeamLine');
    assert.ok(content.includes('spawnFallingSkyProp'), 'Must implement spawnFallingSkyProp');
});

test('Replication: Server fires AbilityVFXEvent to all clients and Client connects to it', () => {
    const serverPath = path.join(__dirname, '../src/server/AbilityService.luau');
    const serverContent = fs.readFileSync(serverPath, 'utf8');
    assert.ok(serverContent.includes('local abilityVFXEvent = getOrCreateRemote("AbilityVFXEvent")'), 'Server must create AbilityVFXEvent');
    assert.ok(serverContent.includes('abilityVFXEvent:FireAllClients(player, fId, slot, root.Position, root.CFrame.LookVector)'), 'Server must fire AbilityVFXEvent to all clients');

    const clientPath = path.join(__dirname, '../src/client/init.client.luau');
    const clientContent = fs.readFileSync(clientPath, 'utf8');
    assert.ok(clientContent.includes('local abilityVFXEvent = ReplicatedStorage:WaitForChild("AbilityVFXEvent", 15)'), 'Client must resolve AbilityVFXEvent');
    assert.ok(clientContent.includes('AbilityVFX.play(caster, fId, slot, originPos, lookVector)'), 'Client must route AbilityVFXEvent to AbilityVFX.play');
});
