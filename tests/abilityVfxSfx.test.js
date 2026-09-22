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

test('Replication: Server fires AbilityVFXEvent to all clients and Client connects with routing', () => {
    const serverPath = path.join(__dirname, '../src/server/AbilityService.luau');
    const serverContent = fs.readFileSync(serverPath, 'utf8');
    assert.ok(serverContent.includes('local abilityVFXEvent = getOrCreateRemote("AbilityVFXEvent")'), 'Server must create AbilityVFXEvent');
    assert.ok(serverContent.includes('abilityVFXEvent:FireAllClients(player, fId, slot, root.Position, root.CFrame.LookVector)'), 'Server must fire AbilityVFXEvent to all clients');

    // Victim-side helpers
    assert.ok(serverContent.includes('function fireVictimVFX'), 'Server must define fireVictimVFX helper');
    assert.ok(serverContent.includes('function fireBlind'), 'Server must define fireBlind helper');
    assert.ok(serverContent.includes('VICTIM_IMPACT'), 'Server must fire VICTIM_IMPACT events');
    assert.ok(serverContent.includes('BLIND'), 'Server must fire BLIND events');

    const clientPath = path.join(__dirname, '../src/client/init.client.luau');
    const clientContent = fs.readFileSync(clientPath, 'utf8');
    assert.ok(clientContent.includes('local abilityVFXEvent = ReplicatedStorage:WaitForChild("AbilityVFXEvent", 15)'), 'Client must resolve AbilityVFXEvent');
    // C9/C15: Client must handle VICTIM_IMPACT, BLIND, and standard VFX
    assert.ok(clientContent.includes('VICTIM_IMPACT'), 'Client must handle VICTIM_IMPACT events');
    assert.ok(clientContent.includes('BLIND'), 'Client must handle BLIND events');
    assert.ok(clientContent.includes('TELEPORT'), 'Client must handle TELEPORT events');
    assert.ok(clientContent.includes('AbilityVFX.play(caster, fId, slot, originPos, lookVector)'), 'Client must route standard events to AbilityVFX.play');
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

    // Bug 4: originPos and lookVector nil-safe fallbacks (C12 renamed to avoid shadowing)
    assert.ok(content.includes('local pos = originPos or Vector3.zero'), 'AbilityVFX.play must provide safe fallback for originPos');
    assert.ok(content.includes('lookDir'), 'AbilityVFX.play must use lookDir param to avoid variable shadowing');
});

test('AbilityVFX & JuiceEffects: Step 4 - mobile LOD scaling, GPU shadow culling, particle budgeting, and memory cleanup', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const vfxContent = fs.readFileSync(vfxPath, 'utf8');

    const juicePath = path.join(__dirname, '../src/client/JuiceEffects.luau');
    const juiceContent = fs.readFileSync(juicePath, 'utf8');

    // JuiceEffects mobile detection & shadow optimization
    assert.ok(juiceContent.includes('function JuiceEffects.isMobile'), 'JuiceEffects must export isMobile');
    assert.ok(juiceContent.includes('pointLight.Shadows = not isMobileDevice'), 'PointLight shadows must be disabled on mobile for 60 FPS');
    assert.ok(juiceContent.includes('math.min(radius or 40, 24)'), 'PointLight range must be capped on mobile devices');
    assert.ok(juiceContent.includes('countPerColor = if isMobileDevice then 12 else 25'), 'Confetti particles must be scaled on mobile devices');
    assert.ok(juiceContent.includes('Debris:AddItem(flashFrame, dur + 0.05)'), 'screenFlash must include Debris fallback cleanup');

    // AbilityVFX mobile LOD scaling & dynamic budgeting
    assert.ok(vfxContent.includes('AbilityVFX.getQualityScale = getQualityScale'), 'AbilityVFX must export getQualityScale');
    assert.ok(vfxContent.includes('AbilityVFX.isMobile ='), 'AbilityVFX must export isMobile');
    assert.ok(vfxContent.includes('MAX_ACTIVE_ROCKS = if isMobileDevice then 14 else 24'), 'Rock budget must adapt to mobile devices');
    assert.ok(vfxContent.includes('dustCount = math.max(8, math.floor(20 * getQualityScale()))'), 'Shockwave dust must scale with quality scale');
    assert.ok(vfxContent.includes('actualCount = math.max(2, math.floor(count * getQualityScale()))'), 'Earth fracture rocks must scale with quality scale');
    assert.ok(vfxContent.includes('vortexBurst = math.max(6, math.floor(18 * getQualityScale()))'), 'Anticipation vortex particles must scale with quality scale');
});

test('61-defect audit: LOD checks on ShockwaveRing/Pillar/Beam/SkyProp (C6)', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    // C6: isWithinLOD guard on heavy effects
    const shockwaveIdx = content.indexOf('function createShockwaveRing');
    const shockwaveSection = content.slice(shockwaveIdx, shockwaveIdx + 300);
    assert.ok(shockwaveSection.includes('isWithinLOD'), 'createShockwaveRing must check isWithinLOD');

    const pillarIdx = content.indexOf('function createPillarOfLight');
    const pillarSection = content.slice(pillarIdx, pillarIdx + 300);
    assert.ok(pillarSection.includes('isWithinLOD'), 'createPillarOfLight must check isWithinLOD');

    const beamIdx = content.indexOf('function createBeamLine');
    const beamSection = content.slice(beamIdx, beamIdx + 300);
    assert.ok(beamSection.includes('isWithinLOD'), 'createBeamLine must check isWithinLOD');

    const skyPropIdx = content.indexOf('function spawnFallingSkyProp');
    const skyPropSection = content.slice(skyPropIdx, skyPropIdx + 300);
    assert.ok(skyPropSection.includes('isWithinLOD'), 'spawnFallingSkyProp must check isWithinLOD');
});

test('61-defect audit: quality scale on ShockwaveRing/Pillar (C7)', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    const shockwaveIdx = content.indexOf('function createShockwaveRing');
    const shockwaveSection = content.slice(shockwaveIdx, shockwaveIdx + 400);
    assert.ok(shockwaveSection.includes('getQualityScale'), 'createShockwaveRing must use getQualityScale');

    const pillarIdx = content.indexOf('function createPillarOfLight');
    const pillarSection = content.slice(pillarIdx, pillarIdx + 400);
    assert.ok(pillarSection.includes('getQualityScale'), 'createPillarOfLight must use getQualityScale');
});

test('61-defect audit: timing fixes D1-D8', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const vfxContent = fs.readFileSync(vfxPath, 'utf8');
    const juicePath = path.join(__dirname, '../src/client/JuiceEffects.luau');
    const juiceContent = fs.readFileSync(juicePath, 'utf8');

    // D1: Sigma parry cross 0.45s
    assert.ok(vfxContent.includes('0.45)'), 'Sigma parry lasers must use 0.45s duration');
    // D2: AnticipationVortex 0.3s
    assert.ok(vfxContent.includes('0, 180, 255), 0.3)'), 'Skibidi base AnticipationVortex must be 0.3s');
    // D3: impactFlash 0.15s
    assert.ok(juiceContent.includes('local dur = duration or 0.15'), 'impactFlash default must be 0.15s');
    // D4: hitstop min 0.07s
    assert.ok(juiceContent.includes('math.max(duration or 0.07, 0.07)'), 'hitstop must enforce 0.07s minimum');
    // D7: BeamLine min 0.35s
    const beamIdx = vfxContent.indexOf('function createBeamLine');
    const beamSection = vfxContent.slice(beamIdx, beamIdx + 400);
    assert.ok(beamSection.includes('math.max('), 'createBeamLine must enforce minimum duration');
    // D8: LightBurst LOD check
    assert.ok(juiceContent.includes('Magnitude > 120'), 'spawnLightBurst must skip distant bursts at 120+ studs');
});

test('61-defect audit: ongoing godmode VFX (C8)', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    // Sigma godmode: ongoing lightning
    const sigmaGodIdx = content.indexOf('BRAZILIAN PHONK OVERLOAD');
    assert.ok(sigmaGodIdx !== -1, 'Must have Sigma godmode VFX');
    const sigmaAfter = content.slice(sigmaGodIdx, sigmaGodIdx + 600);
    assert.ok(sigmaAfter.includes('task.delay(step'), 'Sigma godmode must have ongoing VFX with task.delay');

    // Skibidi godmode: ongoing quakes
    const skibidiGodIdx = content.indexOf('ТИТАН СКИБИДИ-КРУШИТЕЛЬ');
    assert.ok(skibidiGodIdx !== -1, 'Must have Skibidi godmode VFX');
    const skibidiAfter = content.slice(skibidiGodIdx, skibidiGodIdx + 600);
    assert.ok(skibidiAfter.includes('task.delay(step'), 'Skibidi godmode must have ongoing VFX with task.delay');

    // TungTung godmode: ongoing quakes
    const tungGodIdx = content.indexOf('ЯРОСТЬ ВУЛКАНА ЭТНА');
    assert.ok(tungGodIdx !== -1, 'Must have TungTung godmode VFX');
    const tungAfter = content.slice(tungGodIdx, tungGodIdx + 600);
    assert.ok(tungAfter.includes('task.delay(step'), 'TungTung godmode must have ongoing VFX with task.delay');
});

test('61-defect audit: mobility_land VFX handlers (C10)', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    assert.ok(content.includes('"mobility_land"'), 'AbilityVFX must handle mobility_land slot');

    // Verify FanumTax, TungTung, CaseOh, Grimace have mobility_land
    const fanuIdx = content.indexOf('fId == "FanumTax"');
    const grimIdx = content.indexOf('fId == "Grimace"');
    const caseIdx = content.indexOf('fId == "CaseOh"');
    const tungIdx = content.indexOf('fId == "TungTung"');
    
    for (const [name, idx] of [['FanumTax', fanuIdx], ['CaseOh', caseIdx], ['TungTung', tungIdx], ['Grimace', grimIdx]]) {
        const nextFaction = content.indexOf('elseif fId ==', idx + 1);
        const section = content.slice(idx, nextFaction !== -1 ? nextFaction : undefined);
        assert.ok(section.includes('mobility_land'), `${name} must have mobility_land VFX handler`);
    }
});

test('61-defect audit: C5 CaseOh ultimate VFX offset fix', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    // C5: meteor VFX should target pos, not pos + lookVector * 18
    const meteorIdx = content.indexOf('МЕТЕОРИТ КЕЙСОХА');
    assert.ok(meteorIdx !== -1, 'Must have CaseOh meteor VFX');
    const meteorSection = content.slice(Math.max(0, meteorIdx - 400), meteorIdx);
    // The spawnFallingSkyProp should use pos not pos + lookVector * 18
    assert.ok(!meteorSection.includes('lookVector * 18'), 'CaseOh ultimate VFX must NOT offset by lookVector * 18');
});

test('61-defect audit: C11 FanumTax tactical persistent oil puddle', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    assert.ok(content.includes('OilPuddleVFX'), 'FanumTax tactical VFX must spawn persistent oil puddle part');
});

test('61-defect audit: C12 variable shadowing fix', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    // C12: play() must NOT shadow fId or lookVector from outer params
    const playIdx = content.indexOf('function AbilityVFX.play');
    const playSignature = content.slice(playIdx, playIdx + 200);
    assert.ok(playSignature.includes('factionId'), 'play() param must be factionId not fId to avoid shadowing');
    assert.ok(playSignature.includes('lookDir'), 'play() param must be lookDir not lookVector to avoid shadowing');
    // Must NOT contain "local fId = currentFaction" (old shadowing pattern)
    assert.ok(!content.includes('local fId = currentFaction'), 'Must not shadow fId with local redeclaration');
});

test('61-defect audit: C14 Grimace mobility persistent slime puddle', () => {
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const content = fs.readFileSync(vfxPath, 'utf8');

    assert.ok(content.includes('SlimePuddleVFX'), 'Grimace mobility_land VFX must spawn persistent slime puddle');
});

test('Cinematic Audio & VFX Overhaul: verified audio catalog, layered epic sound, and cinematic VFX helpers', () => {
    const juicePath = path.join(__dirname, '../src/client/JuiceEffects.luau');
    const juiceContent = fs.readFileSync(juicePath, 'utf8');

    // Verify broken sound URLs are eliminated
    assert.ok(!juiceContent.includes('sounds/bell.mp3'), 'Broken bell.mp3 must be removed');
    assert.ok(!juiceContent.includes('130976108'), 'Broken asset 130976108 must be removed');
    assert.ok(!juiceContent.includes('sounds/swordhit.wav'), 'Broken swordhit.wav must be removed');

    // Verify layered epic impact & cinematic functions
    assert.ok(juiceContent.includes('function JuiceEffects.playEpicImpact'), 'Must implement playEpicImpact');
    assert.ok(juiceContent.includes('function JuiceEffects.spawnDebrisBlast'), 'Must implement spawnDebrisBlast');
    assert.ok(juiceContent.includes('function JuiceEffects.cinematicVignettePulse'), 'Must implement cinematicVignettePulse');

    // Verify AbilityVFX calls layered audio and cinematic helpers
    const vfxPath = path.join(__dirname, '../src/client/AbilityVFX.luau');
    const vfxContent = fs.readFileSync(vfxPath, 'utf8');
    assert.ok(vfxContent.includes('JuiceEffects.playEpicImpact'), 'AbilityVFX must call playEpicImpact');
    assert.ok(vfxContent.includes('JuiceEffects.spawnDebrisBlast'), 'AbilityVFX must call spawnDebrisBlast');
    assert.ok(vfxContent.includes('JuiceEffects.cinematicVignettePulse'), 'AbilityVFX must call cinematicVignettePulse');
});

test('DataStoreManager: Graceful Studio mock persistence when API access is disabled', () => {
    const dsmPath = path.join(__dirname, '../src/server/DataStoreManager.luau');
    const dsmContent = fs.readFileSync(dsmPath, 'utf8');

    assert.ok(dsmContent.includes('studioMockStore'), 'DataStoreManager must maintain in-memory studioMockStore');
    assert.ok(dsmContent.includes('Studio access to APIs is not allowed'), 'DataStoreManager must detect Studio API restriction');
});

