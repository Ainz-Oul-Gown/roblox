const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');

// ============================================================================
// Tests for all 35 audit fixes (P0 + P1)
// ============================================================================

// === P0-01: Rate-limit + os.clock() ===
test('P0-01: AbilityService uses os.clock() for cooldown and has server debounce', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(src.includes('os.clock()'), 'Must use os.clock() for sub-second cooldown precision');
    assert.ok(!src.includes('os.time()'), 'Must NOT use os.time() for cooldowns (integer-second bypass)');
    assert.ok(src.includes('lastCastTime'), 'Must have server-side debounce map');
    assert.ok(src.includes('now - last < 0.3'), 'Must enforce 0.3s debounce between casts');
});

// === P0-02: FanumTax addCashRaw ===
test('P0-02: FanumTax stolen cash uses addCashRaw (no multiplier)', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(src.includes('TycoonService.addCashRaw(player, stolen)'), 'FanumTax must use addCashRaw for stolen cash');
    assert.ok(src.includes('TycoonService.addCashRaw(player, 2500)'), 'Skibidi special must use addCashRaw for fixed reward');
});

// === P0-03: Mewing MaxHealth cap ===
test('P0-03: Mewing tactical ability caps MaxHealth at 250', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(src.includes('math.min(hum.MaxHealth + 30, 250)'), 'Must cap MaxHealth at 250');
});

// === P0-04: Receipt persistence ===
test('P0-04: MonetizationService persists receipts to DataStore', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/MonetizationService.luau'), 'utf8');
    assert.ok(src.includes('ProcessedReceipts_v1'), 'Must use dedicated DataStore for receipts');
    assert.ok(src.includes('saveReceiptToDataStore'), 'Must save receipt before PurchaseGranted');
    assert.ok(src.includes('isReceiptInDataStore'), 'Must check DataStore for existing receipts');
    assert.ok(src.includes('getProcessedReceiptsList'), 'Must export receipt list for save payload');
});

// === P0-05: Rebirth/Nuke product handling ===
test('P0-05: init.server handles Rebirth and Nuke product types', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/init.server.luau'), 'utf8');
    assert.ok(src.includes('rewardType == "Rebirth"'), 'Must handle Rebirth product type');
    assert.ok(src.includes('rewardType == "Nuke"'), 'Must handle Nuke product type');
});

// === P0-06: Pet & Retention persistence ===
test('P0-06: DataStoreManager schema includes pets, retention, receipts, pvp', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/DataStoreManager.luau'), 'utf8');
    assert.ok(src.includes('pets:'), 'Schema must include pets field');
    assert.ok(src.includes('dailyStreakDay:'), 'Schema must include dailyStreakDay');
    assert.ok(src.includes('lastDailyClaimTimestamp:'), 'Schema must include lastDailyClaimTimestamp');
    assert.ok(src.includes('processedReceipts:'), 'Schema must include processedReceipts');
    assert.ok(src.includes('pvpKills:'), 'Schema must include pvpKills');
});

test('P0-06: PetService supports persistence via initPlayer/getInventoryForSave', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/PetService.luau'), 'utf8');
    assert.ok(src.includes('function PetService.initPlayer(player: Player, savedPets'), 'initPlayer must accept saved pets');
    assert.ok(src.includes('function PetService.getInventoryForSave'), 'Must export getInventoryForSave');
});

test('P0-06: RetentionService exports data for persistence', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/RetentionService.luau'), 'utf8');
    assert.ok(src.includes('function RetentionService.getRetentionDataForSave'), 'Must export getRetentionDataForSave');
});

// === P0-07: UpdateAsync ===
test('P0-07: DataStoreManager uses UpdateAsync instead of SetAsync', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/DataStoreManager.luau'), 'utf8');
    assert.ok(src.includes('UpdateAsync'), 'Must use UpdateAsync for atomic saves');
    assert.ok(!src.includes('SetAsync(key'), 'Must NOT use SetAsync for player data');
});

// === P0-08: BindToClose waits properly ===
test('P0-08: saveAllPlayers waits up to 25 seconds for completion', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/TycoonService.luau'), 'utf8');
    assert.ok(src.includes('os.clock() + 25'), 'Must set 25-second deadline for save completion');
    assert.ok(src.includes('remaining > 0'), 'Must track remaining saves');
});

// === P0-09: NaN guard ===
test('P0-09: NaN/Infinity guards in EconomyManager and TycoonService', () => {
    const eco = fs.readFileSync(path.join(__dirname, '../src/shared/EconomyManager.luau'), 'utf8');
    assert.ok(eco.includes('val == val'), 'EconomyManager must check for NaN');

    const ts = fs.readFileSync(path.join(__dirname, '../src/server/TycoonService.luau'), 'utf8');
    assert.ok(ts.includes('sanitizeNum'), 'TycoonService must use sanitizeNum');

    const dm = fs.readFileSync(path.join(__dirname, '../src/server/DataStoreManager.luau'), 'utf8');
    assert.ok(dm.includes('sanitizeNumber'), 'DataStoreManager must sanitize numbers');
});

// === P0-10: withdrawVault ownership check ===
test('P0-10: withdrawVault checks base ownership', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/TycoonService.luau'), 'utf8');
    assert.ok(src.includes('ownerPlot ~= plotIndex'), 'Must reject withdrawal from non-owned base');
    assert.ok(src.includes('[SECURITY]'), 'Must log security violation');
});

// === P1-01: WalkSpeed restore ===
test('P1-01: AbilityService saves and restores WalkSpeed instead of hardcoding 16', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(src.includes('getBaseWalkSpeed'), 'Must use getBaseWalkSpeed for restore');
    assert.ok(!src.includes('hum.WalkSpeed = 16'), 'Must NOT hardcode WalkSpeed = 16');
});

// === P1-02: Dead cooldown write removed ===
test('P1-02: No dead cooldowns[player.UserId] write', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(!src.includes('cooldowns[player.UserId] = now'), 'Must not write dead numeric cooldown key');
});

// === P1-04 & P1-05: JuiceEffects fixes ===
test('P1-04: play3DSound does not double-play sound within 30 studs', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/client/JuiceEffects.luau'), 'utf8');
    const idx = src.indexOf('dist <= 30');
    const retIdx = src.indexOf('return', idx);
    const nextBlock = src.indexOf('Позиционный 3D', idx);
    assert.ok(retIdx < nextBlock, 'Must return after 2D sound to prevent double-play');
});

test('P1-05: screenShake cancels previous shake thread', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/client/JuiceEffects.luau'), 'utf8');
    assert.ok(src.includes('activeShakeThread'), 'Must track active shake thread');
    assert.ok(src.includes('task.cancel(activeShakeThread)'), 'Must cancel previous shake');
});

// === P1-06 & P1-07: PetFollower fixes ===
test('P1-06: PetFollower uses Heartbeat instead of RenderStepped', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/client/PetFollower.luau'), 'utf8');
    assert.ok(src.includes('Heartbeat'), 'Must use Heartbeat');
    // Check that RenderStepped is NOT used in actual code (comments are OK)
    const codeLines = src.split('\n').filter(l => !l.trim().startsWith('--'));
    const hasRenderSteppedInCode = codeLines.some(l => l.includes('RenderStepped'));
    assert.ok(!hasRenderSteppedInCode, 'Must NOT use RenderStepped in code (comments OK)');
});

test('P1-07: PetFollower parents models to PetModels folder', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/client/PetFollower.luau'), 'utf8');
    assert.ok(src.includes('PetModels'), 'Must use PetModels folder');
});

// === P1-09 + P1-NEW-15: LeaderboardService conditional cleanup ===
test('P1-09/P1-NEW-15: LeaderboardService conditionally cleans zero-kill stats on disconnect', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/LeaderboardService.luau'), 'utf8');
    // P1-NEW-15 FIX: теперь записи с 0 kills удаляются для экономии памяти
    assert.ok(src.includes('stat.kills == 0'), 'Must clean up zero-kill entries on disconnect');
    // Записи с фрагами сохраняются для лидерборда
    assert.ok(src.includes('restorePvPStats'), 'Must support restoring stats from DataStore');
});

// === P1-12: Dead code removal ===
test('P1-12: EconomyManager has no dead SecondFloor reference in code', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/shared/EconomyManager.luau'), 'utf8');
    // Check that SecondFloor is NOT used in actual code (comments about the fix are OK)
    const codeLines = src.split('\n').filter(l => !l.trim().startsWith('--'));
    const hasSecondFloorInCode = codeLines.some(l => l.includes('"SecondFloor"') || l.includes("'SecondFloor'"));
    assert.ok(!hasSecondFloorInCode, 'Must not reference non-existent SecondFloor item in code');
    assert.ok(src.includes('"Floor2_Foundation"'), 'Must reference correct Floor2_Foundation item');
});

// === P1-13: Sigma transparency preservation ===
test('P1-13: Sigma special saves original transparency values', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(src.includes('savedTransparency'), 'Must save original transparency values');
    assert.ok(src.includes('origTrans'), 'Must restore from saved values');
});

// === P1-14: Split debounce ===
test('P1-14: Separate debounce maps for playtime and daily claims', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/init.server.luau'), 'utf8');
    assert.ok(src.includes('playtimeDebounce'), 'Must have playtimeDebounce map');
    assert.ok(src.includes('dailyDebounce'), 'Must have dailyDebounce map');
    assert.ok(!src.includes('retentionDebounce'), 'Must NOT use shared retentionDebounce');
});

// === P1-15: Pet inventory limit ===
test('P1-15: PetService enforces inventory size limit', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/PetService.luau'), 'utf8');
    assert.ok(src.includes('MAX_INVENTORY_SIZE'), 'Must define MAX_INVENTORY_SIZE');
    assert.ok(src.includes('#inv >= MAX_INVENTORY_SIZE'), 'Must check inventory limit before adding');
});

// === P1-16: UUID fix ===
test('P1-16: PetService uses HttpService:GenerateGUID for UUIDs', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/PetService.luau'), 'utf8');
    assert.ok(src.includes('GenerateGUID'), 'Must use GenerateGUID for reliable UUIDs');
});

// === P1-17: Gamepass perks implemented ===
test('P1-17: AUTO_COLLECT and SPEED_PERK gamepasses are implemented', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/init.server.luau'), 'utf8');
    assert.ok(src.includes('AutoCollectEnabled'), 'Must implement AUTO_COLLECT gamepass');
    assert.ok(src.includes('WalkSpeed = math.max'), 'Must implement SPEED_PERK gamepass');
});

// === P1-18: Rebirth clears tools ===
test('P1-18: Rebirth clears ability tools from Backpack', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/TycoonService.luau'), 'utf8');
    assert.ok(src.includes('AbilitySlot'), 'Must check for AbilitySlot attribute on tools');
    assert.ok(src.includes('tool:Destroy()'), 'Must destroy ability tools on rebirth');
});

// === P1-20: Minimal plot statuses ===
test('P1-20: PlotManager sends minimal data (factionId instead of full faction)', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/PlotManager.luau'), 'utf8');
    assert.ok(src.includes('factionId = p.faction.id'), 'Must send factionId instead of full faction object');
    assert.ok(!src.includes('faction = p.faction,'), 'Must NOT send full faction object');
});

// === P1-25: Deep ownedItems validation ===
test('P1-25: DataStoreManager deeply validates ownedItems', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/DataStoreManager.luau'), 'utf8');
    assert.ok(src.includes('deepValidateOwnedItems'), 'Must have deep validation function');
    assert.ok(src.includes("type(k) == \"string\""), 'Must check key types');
    assert.ok(src.includes("type(v) == \"boolean\""), 'Must check value types');
});

// === AUDIT v3 FIXES (Steps 1-6) ===
test('Audit v3 - Step 1: PlotBuilder right wall duplicate (rRight) removed to unblock windows', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/PlotBuilder.luau'), 'utf8');
    assert.ok(!src.includes('local rRight = Instance.new("Part")'), 'rRight solid wall must be removed');
});

test('Audit v3 - Step 2: Floor2_Conveyor button not placed inside ore drop chute', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/PlotBuilder.luau'), 'utf8');
    assert.ok(src.includes('Floor2_Conveyor = Vector3.new(10, 14.5, 10)'), 'Floor2_Conveyor button must be at (10, 14.5, 10)');
    assert.ok(!src.includes('Floor2_Conveyor = Vector3.new(0, 14.5, 6)'), 'Must not collide with ore drop opening at (0, 14.5, 6)');
});

test('Audit v3 - Step 3: Roads connect seamlessly from plaza edge (R=22) to base entrance and include curbs', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/WorldBuilder.luau'), 'utf8');
    assert.ok(src.includes('ROAD_START = 22'), 'ROAD_START must be 22 (plaza ring edge)');
    assert.ok(src.includes('ROAD_END_DIST = BASE_RADIUS - 2'), 'ROAD_END_DIST must be BASE_RADIUS - 2');
    assert.ok(src.includes('RoadCurb'), 'Must construct RoadCurb roadside curbs');
});

test('Audit v3 - Step 4: AbilityService exports clearPlayerTools and giveSpecificTool, stands have ProximityPrompt', () => {
    const abilitySrc = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(abilitySrc.includes('function AbilityService.clearPlayerTools(player: Player)'), 'Must export clearPlayerTools');
    assert.ok(abilitySrc.includes('function AbilityService.giveSpecificTool(player: Player, slot: AbilitySlot)'), 'Must export giveSpecificTool');

    const plotSrc = fs.readFileSync(path.join(__dirname, '../src/server/PlotBuilder.luau'), 'utf8');
    assert.ok(plotSrc.includes('PlotBuilder.onStandPickup'), 'Must support stand pickup callback');
    assert.ok(plotSrc.includes('local prompt = Instance.new("ProximityPrompt")'), 'Stands must create ProximityPrompt');

    const initSrc = fs.readFileSync(path.join(__dirname, '../src/server/init.server.luau'), 'utf8');
    assert.ok(initSrc.includes('AbilityService.clearPlayerTools(player)'), 'onClaimBase must clear old ability tools');
});

test('Audit v3 - Steps 5 & 6: applyDamage supports SigmaParryActive reflection with attacker passed', () => {
    const src = fs.readFileSync(path.join(__dirname, '../src/server/AbilityService.luau'), 'utf8');
    assert.ok(src.includes('SigmaParryActive'), 'applyDamage must handle SigmaParryActive');
    assert.ok(src.includes('rawDamage * 0.75'), 'Must reflect 75% damage');
    assert.ok(src.includes('applyDamage(oHum, 25, player)'), 'Must pass attacker player to applyDamage');
    assert.ok(src.includes('applyDamage(tHum, 45, player)'), 'Sigma Teleport must use applyDamage');
    assert.ok(src.includes('fId == "Grimace"'), 'Must have unique Grimace abilities block');
    assert.ok(src.includes('fId == "CaseOh"'), 'Must have unique CaseOh abilities block');
    assert.ok(src.includes('fId == "Rizzler"'), 'Must have unique Rizzler abilities block');
    assert.ok(src.includes('fId == "TungTung"'), 'Must have unique TungTung abilities block');
});
