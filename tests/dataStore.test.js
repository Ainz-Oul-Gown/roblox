const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const DataStoreManager = {
    CURRENT_VERSION: 1,
    getDefaultData() {
        return {
            version: this.CURRENT_VERSION,
            cash: 0,
            rebirths: 0,
            ownedItems: {},
            lastSaved: 1000
        };
    },
    validateAndMigrate(raw) {
        const def = this.getDefaultData();
        if (!raw || typeof raw !== 'object') return def;

        const cash = (typeof raw.cash === 'number' && raw.cash >= 0) ? Math.floor(raw.cash) : 0;
        const rebirths = (typeof raw.rebirths === 'number' && raw.rebirths >= 0) ? Math.floor(raw.rebirths) : 0;
        const ownedItems = (raw.ownedItems && typeof raw.ownedItems === 'object') ? raw.ownedItems : {};

        return {
            version: this.CURRENT_VERSION,
            cash,
            rebirths,
            ownedItems,
            lastSaved: 1000
        };
    }
};

test('DataStoreManager source file exists', () => {
    const filePath = path.join(__dirname, '..', 'src', 'server', 'DataStoreManager.luau');
    assert.ok(fs.existsSync(filePath), 'DataStoreManager.luau must exist');
    const content = fs.readFileSync(filePath, 'utf8');
    assert.match(content, /function\s+DataStoreManager\.loadData/, 'Must export loadData');
    assert.match(content, /function\s+DataStoreManager\.saveData/, 'Must export saveData');
});

test('DataStore validation & fallback on corrupted/empty data', () => {
    assert.deepEqual(DataStoreManager.validateAndMigrate(null), DataStoreManager.getDefaultData());
    assert.deepEqual(DataStoreManager.validateAndMigrate("corrupted string"), DataStoreManager.getDefaultData());

    const partialData = { cash: 500 };
    const validated = DataStoreManager.validateAndMigrate(partialData);
    assert.equal(validated.cash, 500);
    assert.equal(validated.rebirths, 0);
    assert.deepEqual(validated.ownedItems, {});
});

test('DataStore negative numbers clamped to 0', () => {
    const invalid = { cash: -100, rebirths: -5 };
    const validated = DataStoreManager.validateAndMigrate(invalid);
    assert.equal(validated.cash, 0);
    assert.equal(validated.rebirths, 0);
});
