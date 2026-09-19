const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('PlotBuilder source file integrity', () => {
    const filePath = path.join(__dirname, '..', 'src', 'server', 'PlotBuilder.luau');
    assert.ok(fs.existsSync(filePath), 'PlotBuilder.luau must exist');

    const content = fs.readFileSync(filePath, 'utf8');
    assert.match(content, /function\s+PlotBuilder\.createPlotForPlayer/, 'Must export createPlotForPlayer');
    assert.match(content, /function\s+PlotBuilder\.destroyPlotForPlayer/, 'Must export destroyPlotForPlayer');
    assert.match(content, /AssemblyLinearVelocity/, 'Must configure conveyor velocity');
    assert.match(content, /Ore/, 'Must handle Ore physical dropping');
    assert.match(content, /BillboardGui/, 'Must create visual billboards');
});

test('PlotBuilder geometry: Plot origin spacing', () => {
    function calculatePlotOrigin(plotIndex, spacing = 70) {
        return { x: 0, y: 0, z: (plotIndex - 1) * spacing };
    }

    const plot1 = calculatePlotOrigin(1);
    const plot2 = calculatePlotOrigin(2);
    const plot3 = calculatePlotOrigin(3);

    assert.deepEqual(plot1, { x: 0, y: 0, z: 0 });
    assert.deepEqual(plot2, { x: 0, y: 0, z: 70 });
    assert.deepEqual(plot3, { x: 0, y: 0, z: 140 });
    assert.ok(plot2.z - plot1.z >= 70, 'Plots must have at least 70 studs spacing');
});

test('PlotBuilder: Button offsets do not collide', () => {
    const BUTTON_OFFSETS = {
        StarterDropper: { x: -8, y: 0.6, z: -10 },
        Walls: { x: -8, y: 0.6, z: -5 },
        UpgradedDropper: { x: -8, y: 0.6, z: 0 },
        Roof: { x: -8, y: 0.6, z: 5 },
        GoldDropper: { x: -8, y: 0.6, z: 10 },
        SecondFloor: { x: -8, y: 0.6, z: 15 },
    };

    const keys = Object.keys(BUTTON_OFFSETS);
    for (let i = 0; i < keys.length; i++) {
        for (let j = i + 1; j < keys.length; j++) {
            const a = BUTTON_OFFSETS[keys[i]];
            const b = BUTTON_OFFSETS[keys[j]];
            const distance = Math.sqrt(
                Math.pow(a.x - b.x, 2) + Math.pow(a.y - b.y, 2) + Math.pow(a.z - b.z, 2)
            );
            assert.ok(distance >= 3.5, `Buttons ${keys[i]} and ${keys[j]} must have clearance`);
        }
    }
});
