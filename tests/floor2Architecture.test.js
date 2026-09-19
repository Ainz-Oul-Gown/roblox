// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('PlotBuilder: 56x76 expanded base footprint and height 14 walls', () => {
    const pbPath = path.join(__dirname, '../src/server/PlotBuilder.luau');
    const content = fs.readFileSync(pbPath, 'utf8');

    // Base floor 56x76
    assert.ok(content.includes('Vector3.new(56, 1, 76)'), 'Base floor must be 56x76 studs');

    // Walls height 14
    assert.ok(content.includes('Vector3.new(1, 14, 76)'), 'Left and right walls must be height 14');
    assert.ok(content.includes('Vector3.new(56, 14, 1)'), 'Back wall must be width 56 and height 14');

    // Floor 2 resting on walls at Y = 14 with drop chute hole
    assert.ok(content.includes('CFrame.new(-9, 14, 0)'), 'Floor 2 left wing must sit at Y = 14');
    assert.ok(content.includes('CFrame.new(16, 14, 0)'), 'Floor 2 right wing must sit at Y = 14');
    assert.ok(content.includes('Floor2_CenterBack'), 'Floor 2 must have center back section');
    assert.ok(content.includes('Floor2_CenterFront'), 'Floor 2 must have center front section');

    // Chute slide to Floor 1
    assert.ok(content.includes('OreDropChute'), 'Ore drop chute must exist');
    assert.ok(content.includes('ChuteWall'), 'Chute must have side guide walls');

    // Ore despawn timer is exactly 20 seconds
    assert.ok(content.includes('Debris:AddItem(ore, 20)'), 'Ore must despawn after 20 seconds');

    // TycoonRoof and FactionMonument on roof
    assert.ok(content.includes('item.id == "TycoonRoof"'), 'TycoonRoof handler must exist in PlotBuilder');
    assert.ok(content.includes('Roof_Main'), 'TycoonRoof must create main solid roof');
    assert.ok(content.includes('MonumentPedestal'), 'FactionMonument pedestal must exist');
    assert.ok(content.includes('CFrame.new(0, 26, -6)'), 'Monument pedestal must sit at Y = 26 on top of roof');

    // Rebirth Altar in spacious open location with legible billboard
    assert.ok(content.includes('CFrame.new(-18, 14.4, 18)'), 'Rebirth Altar must be positioned in open area away from conveyor');
    assert.ok(content.includes('AltarPedestal'), 'Rebirth Altar must have altar pedestal');

    // Stairs climb to Y = 14
    assert.ok(content.includes('totalHeight = 14'), 'Stairs totalHeight must equal 14');
    assert.ok(content.includes('startZ = 24'), 'Stairs must start at Z = 24');
    assert.ok(content.includes('endZ = -6'), 'Stairs must end at Z = -6');
});

test('PlotBuilder: Anti-clutter BillboardGui configuration', () => {
    const pbPath = path.join(__dirname, '../src/server/PlotBuilder.luau');
    const content = fs.readFileSync(pbPath, 'utf8');

    // BillboardGui must default to AlwaysOnTop = false
    assert.ok(content.includes('billboard.AlwaysOnTop = if alwaysOnTop ~= nil then alwaysOnTop else false'), 'Billboards must default to AlwaysOnTop = false');
    assert.ok(content.includes('billboard.MaxDistance = maxDist or 30'), 'Billboards must default to MaxDistance = 30');
});

test('PlotBuilder: Floor 2 button is not placed under the stairs, Roof & Rebirth buttons properly placed', () => {
    const pbPath = path.join(__dirname, '../src/server/PlotBuilder.luau');
    const content = fs.readFileSync(pbPath, 'utf8');

    // Button positions
    assert.ok(content.includes('Floor2_Foundation = Vector3.new(-10, 0.5, 26)'), 'Floor2_Foundation button must be at Z=26 in front of stairs');
    assert.ok(content.includes('Stairs_To_Floor2 = Vector3.new(-10, 0.5, 20)'), 'Stairs button must be at Z=20');
    assert.ok(content.includes('TycoonRoof = Vector3.new(18, 14.5, 16)'), 'TycoonRoof button must be on 2nd floor');
    assert.ok(content.includes('Rebirth_Portal = Vector3.new(-18, 14.5, 8)'), 'Rebirth_Portal button must lead to altar');
    assert.ok(content.includes('FactionMonument = Vector3.new(18, 14.5, 24)'), 'FactionMonument button must be on 2nd floor');
});

test('TycoonService: RebirthEvent exists and fires to client with multiplier', () => {
    const tsPath = path.join(__dirname, '../src/server/TycoonService.luau');
    const content = fs.readFileSync(tsPath, 'utf8');

    assert.ok(content.includes('getOrCreateRemote("RebirthEvent")'), 'Must create RebirthEvent RemoteEvent');
    assert.ok(content.includes('rebirthEvent:FireClient(player, data.rebirths, mult)'), 'Must fire RebirthEvent to player on rebirth');

    // Client init script handles RebirthEvent
    const clientPath = path.join(__dirname, '../src/client/init.client.luau');
    const clientContent = fs.readFileSync(clientPath, 'utf8');
    assert.ok(clientContent.includes('rebirthEvent.OnClientEvent:Connect'), 'Client must handle RebirthEvent');
    assert.ok(clientContent.includes('JuiceEffects.playSound("fanfare"'), 'Client must play fanfare on rebirth');
});
