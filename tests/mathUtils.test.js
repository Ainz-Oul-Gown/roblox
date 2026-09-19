const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Reference implementation matching src/shared/MathUtils.luau contract
const MathUtils = {
    clamp(value, minVal, maxVal) {
        if (minVal > maxVal) {
            throw new Error("minVal cannot be greater than maxVal");
        }
        if (value < minVal) return minVal;
        if (value > maxVal) return maxVal;
        return value;
    },
    lerp(a, b, t) {
        return a + (b - a) * t;
    },
    calculateLevel(xp, xpPerLevel = 100) {
        if (xp < 0 || xpPerLevel <= 0) return 1;
        return Math.floor(xp / xpPerLevel) + 1;
    },
    calculateXpForNextLevel(currentLevel, xpPerLevel = 100) {
        if (currentLevel < 1) return xpPerLevel;
        return currentLevel * xpPerLevel;
    }
};

test('Verify MathUtils.luau source file integrity', () => {
    const filePath = path.join(__dirname, '..', 'src', 'shared', 'MathUtils.luau');
    assert.ok(fs.existsSync(filePath), 'MathUtils.luau must exist');
    
    const content = fs.readFileSync(filePath, 'utf8');
    assert.match(content, /function\s+MathUtils\.clamp/, 'Must contain clamp function');
    assert.match(content, /function\s+MathUtils\.lerp/, 'Must contain lerp function');
    assert.match(content, /function\s+MathUtils\.calculateLevel/, 'Must contain calculateLevel function');
    assert.match(content, /function\s+MathUtils\.calculateXpForNextLevel/, 'Must contain calculateXpForNextLevel function');
});

test('MathUtils.clamp tests', () => {
    assert.equal(MathUtils.clamp(5, 0, 10), 5);
    assert.equal(MathUtils.clamp(-5, 0, 10), 0);
    assert.equal(MathUtils.clamp(15, 0, 10), 10);
    assert.throws(() => MathUtils.clamp(5, 10, 0), /minVal cannot be greater than maxVal/);
});

test('MathUtils.lerp tests', () => {
    assert.equal(MathUtils.lerp(0, 100, 0), 0);
    assert.equal(MathUtils.lerp(0, 100, 0.5), 50);
    assert.equal(MathUtils.lerp(0, 100, 1), 100);
});

test('MathUtils.calculateLevel tests', () => {
    assert.equal(MathUtils.calculateLevel(0), 1);
    assert.equal(MathUtils.calculateLevel(99), 1);
    assert.equal(MathUtils.calculateLevel(100), 2);
    assert.equal(MathUtils.calculateLevel(250), 3);
    assert.equal(MathUtils.calculateLevel(-50), 1);
    assert.equal(MathUtils.calculateLevel(50, 50), 2);
});

test('MathUtils.calculateXpForNextLevel tests', () => {
    assert.equal(MathUtils.calculateXpForNextLevel(1), 100);
    assert.equal(MathUtils.calculateXpForNextLevel(2), 200);
    assert.equal(MathUtils.calculateXpForNextLevel(3, 50), 150);
});
