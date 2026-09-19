// @ts-check
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('Admin Feature: Server-side RemoteEvent and chat commands', () => {
    const serverPath = path.join(__dirname, '../src/server/init.server.luau');
    const content = fs.readFileSync(serverPath, 'utf8');

    // RemoteEvent AdminGiveCashEvent existence
    assert.ok(content.includes('AdminGiveCashEvent'), 'Must define AdminGiveCashEvent');
    assert.ok(content.includes('adminCashEvent.OnServerEvent:Connect'), 'Must handle OnServerEvent for AdminGiveCashEvent');

    // Amount clamping logic
    assert.ok(content.includes('math.clamp(n, 1000, 100000000)'), 'Must clamp admin cash between 1,000 and 100,000,000');
    assert.ok(content.includes('TycoonService.addCash(player, n)'), 'Must grant cash via TycoonService.addCash');

    // Chat commands
    assert.ok(content.includes('player.Chatted:Connect'), 'Must listen to player.Chatted');
    assert.ok(content.includes('/aura'), 'Must support /aura command');
    assert.ok(content.includes('/rich'), 'Must support /rich command');
});

test('Admin Feature: Client-side button and [P] keybind', () => {
    const clientPath = path.join(__dirname, '../src/client/init.client.luau');
    const content = fs.readFileSync(clientPath, 'utf8');

    // Event listener
    assert.ok(content.includes('AdminGiveCashEvent'), 'Client must reference AdminGiveCashEvent');
    
    // UI Button
    assert.ok(content.includes('AdminCashBtn'), 'Client must create AdminCashBtn');
    assert.ok(content.includes('👑 +1M AURA [P]'), 'Button text must indicate [P] and +1M Aura');

    // Trigger function & Keybind
    assert.ok(content.includes('adminGiveCashEvent:FireServer(1000000)'), 'Must fire 1,000,000 aura to server');
    assert.ok(content.includes('Enum.KeyCode.P'), 'Must bind KeyCode.P to trigger admin cash');
    assert.ok(content.includes('JuiceEffects.playSound("cash", 1.0)'), 'Must play cash sound effect');
    assert.ok(content.includes('JuiceEffects.screenFlash'), 'Must trigger golden screen flash');
    assert.ok(content.includes('JuiceEffects.showFloatingText'), 'Must show floating 3D text');
});

test('Admin Feature: Mathematical simulation of cash addition', () => {
    let wallet = 0;
    const addCash = (amount) => {
        const clamped = Math.min(100000000, Math.max(1000, amount));
        wallet += clamped;
    };

    // Default 1M
    addCash(1000000);
    assert.equal(wallet, 1000000);

    // Multiple clicks / key presses
    addCash(1000000);
    addCash(1000000);
    assert.equal(wallet, 3000000);

    // Negative or exploit amount clamped to 1000
    addCash(-500);
    assert.equal(wallet, 3001000);

    // Excess amount clamped to 100M
    addCash(999999999);
    assert.equal(wallet, 103001000);
});
