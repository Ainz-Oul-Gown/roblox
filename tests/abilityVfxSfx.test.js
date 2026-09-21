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

    // Review fixes assertions: P0, P1, P2
    assert.ok(content.includes('activeHitstopCount'), 'Must track active hitstops to prevent zero-speed lock');
    assert.ok(content.includes('cachedOriginalWalkSpeed'), 'Must cache original walk speed before setting to 0');
    assert.ok(!content.includes('math.noise(t, 0, seed) - 0.5'), 'Noise must be symmetric without -0.5 bias');
    assert.ok(content.includes('CombatColorPulse'), 'Must support color tint in screenBloomFlash');
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

test('AbilityVFX: implements Step 2 physical world fracture generators, LOD culling, and rock budgeting', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    // World fracture & physical generators
    assert.ok(content.includes('AbilityVFX.spawnEarthFracture = spawnEarthFracture'), 'Must export spawnEarthFracture');
    assert.ok(content.includes('AbilityVFX.spawnGroundCracks = spawnGroundCracks'), 'Must export spawnGroundCracks');
    assert.ok(content.includes('AbilityVFX.spawnAnticipationVortex = spawnAnticipationVortex'), 'Must export spawnAnticipationVortex');
    assert.ok(content.includes('AbilityVFX.spawnMagicCircle = spawnMagicCircle'), 'Must export spawnMagicCircle');
    assert.ok(content.includes('AbilityVFX.spawnVolumetricLaser = spawnVolumetricLaser'), 'Must export spawnVolumetricLaser');
    assert.ok(content.includes('AbilityVFX.spawnTexturedShockwave = spawnTexturedShockwave'), 'Must export spawnTexturedShockwave');

    // Performance budgeting & LOD
    assert.ok(content.includes('AbilityVFX.MAX_ACTIVE_ROCKS = MAX_ACTIVE_ROCKS'), 'Must export MAX_ACTIVE_ROCKS');
    assert.ok(content.includes('MAX_ACTIVE_ROCKS = 24'), 'Must set rock budget limit to 24');
    assert.ok(content.includes('AbilityVFX.isWithinLOD = isWithinLOD'), 'Must export isWithinLOD');
    assert.ok(content.includes('LOD_DISTANCE = 120'), 'Must set LOD distance to 120 studs');
    assert.ok(content.includes('pruneOldRocks'), 'Must implement FIFO queue pruning for active rocks');
    assert.ok(content.includes('Slate'), 'Fracture rocks must use Slate material');

    // Review Step 2 minor fixes: raycast ground detection & nil links pruning
    assert.ok(content.includes('AbilityVFX.getGroundPosition = getGroundPosition'), 'Must export getGroundPosition');
    assert.ok(content.includes('Workspace:Raycast'), 'getGroundPosition must cast a ray towards ground');
    assert.ok(content.includes('if not r or not r.Parent then'), 'pruneOldRocks must clean nil references');
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

test('AbilityVFX: Step 3 - all 48 ability slots integrate 4-phase VFX, earth fracture, and camera trauma', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    const factions = [
        'Skibidi', 'Mewing', 'Sigma', 'FanumTax',
        'Grimace', 'CaseOh', 'Rizzler', 'TungTung'
    ];
    const slots = ['base', 'tactical', 'ultimate', 'special', 'mobility', 'godmode'];

    // Verify each faction's section contains all 6 slots
    for (const f of factions) {
        const startIdx = content.indexOf(`fId == "${f}"`);
        assert.ok(startIdx !== -1, `AbilityVFX must handle faction ${f}`);
        // Find end of faction block (next faction or end of function)
        const nextFactionIdx = content.indexOf('elseif fId ==', startIdx + 1);
        const sectionEnd = nextFactionIdx !== -1 ? nextFactionIdx : content.indexOf('return AbilityVFX', startIdx);
        const section = content.slice(startIdx, sectionEnd);

        for (const s of slots) {
            assert.ok(
                section.includes(`slot == "${s}"`),
                `Faction ${f} must handle slot "${s}" in AbilityVFX.play`
            );
        }
    }

    // Verify AAA 4-phase VFX functions are actively called inside AbilityVFX.play
    const playFnStart = content.indexOf('function AbilityVFX.play');
    const playFn = content.slice(playFnStart);

    assert.ok(playFn.includes('spawnEarthFracture('), 'AbilityVFX.play must invoke spawnEarthFracture');
    assert.ok(playFn.includes('spawnGroundCracks('), 'AbilityVFX.play must invoke spawnGroundCracks');
    assert.ok(playFn.includes('spawnAnticipationVortex('), 'AbilityVFX.play must invoke spawnAnticipationVortex');
    assert.ok(playFn.includes('spawnMagicCircle('), 'AbilityVFX.play must invoke spawnMagicCircle');
    assert.ok(playFn.includes('spawnVolumetricLaser('), 'AbilityVFX.play must invoke spawnVolumetricLaser');
    assert.ok(playFn.includes('spawnTexturedShockwave('), 'AbilityVFX.play must invoke spawnTexturedShockwave');
    assert.ok(playFn.includes('spawnFallingSkyProp('), 'AbilityVFX.play must invoke spawnFallingSkyProp');
    assert.ok(playFn.includes('JuiceEffects.spawnLightBurst('), 'AbilityVFX.play must invoke JuiceEffects.spawnLightBurst');

    // Camera & Juice feel
    assert.ok(playFn.includes('JuiceEffects.traumaShake('), 'AbilityVFX.play must invoke traumaShake for high impact feel');
    assert.ok(playFn.includes('JuiceEffects.cameraKick('), 'AbilityVFX.play must invoke cameraKick for directional impact');
    assert.ok(playFn.includes('JuiceEffects.fovPulse('), 'AbilityVFX.play must invoke fovPulse for mobility abilities');
    assert.ok(playFn.includes('JuiceEffects.hitstop('), 'AbilityVFX.play must invoke hitstop for critical weight');
    assert.ok(playFn.includes('JuiceEffects.screenBloomFlash('), 'AbilityVFX.play must invoke screenBloomFlash for ultimate/godmode');
});

test('AbilityVFX: Step 3 Review Fixes - player character raycast filtering, prop rotation preservation, customCrater flag, and originPos/lookVector fallbacks', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    // Bug 1: getGroundPosition must exclude all players' characters
    assert.ok(content.includes('Players:GetPlayers()'), 'getGroundPosition must iterate Players:GetPlayers() to exclude all characters');
    assert.ok(content.includes('table.insert(ignoreList, p.Character)'), 'getGroundPosition must ignore remote player characters');

    // Bug 2: spawnFallingSkyProp supports customCrater to avoid double craters and Z-fighting
    assert.ok(content.includes('customCrater: boolean?'), 'spawnFallingSkyProp must accept customCrater parameter');
    assert.ok(content.includes('if not customCrater then'), 'spawnFallingSkyProp must guard default crater with not customCrater');

    // Bug 3: propBuilder rotation preservation
    assert.ok(content.includes('local rot = prop.CFrame.Rotation'), 'spawnFallingSkyProp must preserve builder rotation');
    assert.ok(content.includes('CFrame.new(spawnPos) * rot'), 'spawnFallingSkyProp must apply rotation to spawn CFrame');
    assert.ok(content.includes('CFrame.new(targetPos) * rot'), 'spawnFallingSkyProp must apply rotation to target CFrame');

    // Bug 4: originPos and lookVector nil-safe fallbacks
    assert.ok(content.includes('local pos = originPos or Vector3.zero'), 'AbilityVFX.play must provide safe fallback for originPos');
    assert.ok(content.includes('local look = if lookVector and lookVector.Magnitude > 0 then lookVector.Unit else Vector3.new(0, 0, -1)'), 'AbilityVFX.play must provide safe fallback for lookVector');
});


