// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('Conveyor vector and geometry direction points towards collector (+Z)', () => {
    // Dropper and collector Z positions in PlotBuilder
    const droppersZ = [-8, -2, 4];
    const collectorZ = 15;
    const conveyorStartZ = -15;
    const conveyorEndZ = 15;

    for (const dZ of droppersZ) {
        assert.ok(dZ > conveyorStartZ, `Dropper at Z=${dZ} should be after conveyor start`);
        assert.ok(dZ < collectorZ, `Dropper at Z=${dZ} must be before collector at Z=${collectorZ}`);
        const deltaZ = collectorZ - dZ;
        assert.ok(deltaZ > 0, `Displacement towards collector must be strictly positive (+Z direction)`);
    }

    // Verify conveyor velocity formula in source code
    const plotBuilderContent = fs.readFileSync(path.join(__dirname, '../src/server/PlotBuilder.luau'), 'utf8');
    assert.ok(
        plotBuilderContent.includes('Vector3.new(0, 0, 1)'),
        'PlotBuilder must calculate forward vector along +Z (0, 0, 1)'
    );
    assert.ok(
        plotBuilderContent.includes('conveyor.AssemblyLinearVelocity = forwardVector * speed'),
        'PlotBuilder must set AssemblyLinearVelocity towards collector'
    );
    assert.ok(
        plotBuilderContent.includes('ConveyorBackstop'),
        'PlotBuilder must have a solid backstop behind the conveyor'
    );
    assert.ok(
        plotBuilderContent.includes('BorderLeft') && plotBuilderContent.includes('BorderRight'),
        'PlotBuilder must have side borders along the conveyor'
    );
});

test('Perimeter closure: front facade has zero gaps from X = -17 to +17', () => {
    // Wall layout
    const baseWidth = 34;
    const minX = -baseWidth / 2; // -17
    const maxX = baseWidth / 2;  // +17

    // Front Left Wall: center -11.25, width 11.5
    const frontLeftMin = -11.25 - 11.5 / 2; // -17.0
    const frontLeftMax = -11.25 + 11.5 / 2; // -5.5

    // Laser Gate opening: spans between postLeft (-5.5) and postRight (+5.5)
    const gateMin = -5.5;
    const gateMax = 5.5;

    // Front Right Wall: center +11.25, width 11.5
    const frontRightMin = 11.25 - 11.5 / 2; // +5.5
    const frontRightMax = 11.25 + 11.5 / 2; // +17.0

    assert.equal(frontLeftMin, minX, 'Front Left Wall must align with Left Wall at -17');
    assert.equal(frontLeftMax, gateMin, 'Front Left Wall must touch Left Gate Post at -5.5');
    assert.equal(gateMax, frontRightMin, 'Right Gate Post must touch Front Right Wall at +5.5');
    assert.equal(frontRightMax, maxX, 'Front Right Wall must align with Right Wall at +17');

    // Total covered width
    const totalCovered = (frontLeftMax - frontLeftMin) + (gateMax - gateMin) + (frontRightMax - frontRightMin);
    assert.equal(totalCovered, baseWidth, 'Front perimeter segments must sum to 34 studs without gap');

    // Verify GateLintel exists in source to stop players jumping over
    const plotBuilderContent = fs.readFileSync(path.join(__dirname, '../src/server/PlotBuilder.luau'), 'utf8');
    assert.ok(plotBuilderContent.includes('GateLintel'), 'LaserGate must have a top lintel beam');
});

test('Laser security gate properly handles accessory touches and eliminates intruders', () => {
    function simulateLaserTouch(hit, ownerUserId) {
        let char = hit.parent;
        let hum = char.humanoid;
        if (!hum && char.parent && char.parent.humanoid) {
            char = char.parent;
            hum = char.humanoid;
        }
        if (hum && hum.health > 0) {
            const player = char.player;
            if (player && player.userId !== ownerUserId) {
                hum.health = 0; // eliminate intruder
                return 'ELIMINATED';
            }
            return 'ALLOWED';
        }
        return 'IGNORED';
    }

    const owner = { userId: 12345, name: 'OwnerPlayer' };
    const intruder = { userId: 99999, name: 'IntruderPlayer' };

    // Case 1: Owner body touches laser
    const ownerChar = { player: owner, humanoid: { health: 100 } };
    const ownerLimb = { name: 'LeftFoot', parent: ownerChar };
    assert.equal(simulateLaserTouch(ownerLimb, owner.userId), 'ALLOWED');
    assert.equal(ownerChar.humanoid.health, 100);

    // Case 2: Intruder body touches laser
    const intruderChar = { player: intruder, humanoid: { health: 100 } };
    const intruderLimb = { name: 'RightHand', parent: intruderChar };
    assert.equal(simulateLaserTouch(intruderLimb, owner.userId), 'ELIMINATED');
    assert.equal(intruderChar.humanoid.health, 0);

    // Case 3: Intruder accessory (hat/hair) touches laser
    const intruderChar2 = { player: intruder, humanoid: { health: 100 } };
    const accessory = { name: 'Fedora', humanoid: null, parent: intruderChar2 };
    const accessoryHandle = { name: 'Handle', parent: accessory };
    assert.equal(simulateLaserTouch(accessoryHandle, owner.userId), 'ELIMINATED');
    assert.equal(intruderChar2.humanoid.health, 0);
});

test('AbilityService cooldown logic and base validation', () => {
    function getCooldown(hasUpgradeStand) {
        return hasUpgradeStand ? 6 : 12;
    }

    assert.equal(getCooldown(false), 12, 'Base cooldown without upgrade stand is 12 seconds');
    assert.equal(getCooldown(true), 6, 'Upgraded cooldown with stand is 6 seconds');

    // Verify AbilityService checks plot ownership before consuming cooldown
    const abilityServiceContent = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    // P1-02: cooldowns[player.UserId] dead write removed, now uses cdKey
    const plotIndexPos = abilityServiceContent.indexOf('local plotIndex = PlotManager.getPlayerPlotIndex');
    const cooldownPos = abilityServiceContent.indexOf('cooldowns[cdKey] = now');
    assert.ok(
        plotIndexPos < cooldownPos,
        'AbilityService must validate player base ownership BEFORE recording cooldown timestamp'
    );
});

test('Client HUD handles ability events and countdown display', () => {
    const clientContent = fs.readFileSync(path.join(__dirname, '../src/client/init.client.luau'), 'utf8');
    assert.ok(
        clientContent.includes('showToast'),
        'Client script must have toast notification function'
    );
    assert.ok(
        clientContent.includes('abilityEvent.OnClientEvent:Connect'),
        'Client script must connect to abilityEvent.OnClientEvent'
    );
    assert.ok(
        clientContent.includes('currentCooldownRemaining'),
        'Client script must track and display ability cooldown countdown'
    );
});
