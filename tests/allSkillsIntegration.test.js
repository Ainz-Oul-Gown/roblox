const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execSync } = require('node:child_process');

test('Multi-Agent All Skills Integration: LightingThemes Future Technology and Presets', () => {
    const lightingPath = path.join(__dirname, '..', 'src', 'shared', 'LightingThemes.luau');
    assert.ok(fs.existsSync(lightingPath), 'LightingThemes.luau must exist');

    const content = fs.readFileSync(lightingPath, 'utf8');
    assert.match(content, /Technology\.Future/, 'Must configure Future Lighting technology');
    assert.match(content, /Atmosphere/, 'Must configure Atmosphere');
    assert.match(content, /BloomEffect/, 'Must configure BloomEffect');
    assert.match(content, /ColorCorrectionEffect/, 'Must configure ColorCorrectionEffect');
    assert.match(content, /SunRaysEffect/, 'Must configure SunRaysEffect');
    assert.match(content, /applyTheme/, 'Must export applyTheme');
    assert.match(content, /Cyberpunk/, 'Must contain Cyberpunk preset');
    assert.match(content, /SunsetGlow/, 'Must contain SunsetGlow preset');
    assert.match(content, /MidnightSciFi/, 'Must contain MidnightSciFi preset');
});

test('Multi-Agent All Skills Integration: Pet System Server & Client Wiring', () => {
    const petServicePath = path.join(__dirname, '..', 'src', 'server', 'PetService.luau');
    const petFollowerPath = path.join(__dirname, '..', 'src', 'client', 'PetFollower.luau');
    const serverInitPath = path.join(__dirname, '..', 'src', 'server', 'init.server.luau');

    const petServiceCode = fs.readFileSync(petServicePath, 'utf8');
    assert.match(petServiceCode, /PetService\.getEquippedPetDefs/, 'Must export getEquippedPetDefs');
    assert.match(petServiceCode, /PetService\.equipBest/, 'Must export equipBest');
    assert.match(petServiceCode, /PetService\.rollEgg/, 'Must export rollEgg');

    const followerCode = fs.readFileSync(petFollowerPath, 'utf8');
    assert.match(followerCode, /createPetVisual/, 'Must implement createPetVisual');
    assert.match(followerCode, /syncEquippedPets/, 'Must implement syncEquippedPets');
    assert.match(followerCode, /math\.sin/, 'Must compute client-side floating bobbing animation');

    const serverCode = fs.readFileSync(serverInitPath, 'utf8');
    assert.match(serverCode, /OpenEggEvent/, 'Must wire OpenEggEvent');
    assert.match(serverCode, /EquippedPetsEvent/, 'Must wire EquippedPetsEvent');
});

test('Multi-Agent All Skills Integration: JuiceKit Confetti and Polish', () => {
    const juicePath = path.join(__dirname, '..', 'src', 'client', 'JuiceEffects.luau');
    const juiceCode = fs.readFileSync(juicePath, 'utf8');

    assert.match(juiceCode, /JuiceEffects\.spawnConfetti/, 'Must export spawnConfetti');
    assert.match(juiceCode, /ParticleEmitter/, 'Must generate particle emitters for confetti');
    assert.match(juiceCode, /Debris:AddItem\(emitterPart/, 'Must clean up confetti emitters after lifetime');

    const clientInitPath = path.join(__dirname, '..', 'src', 'client', 'init.client.luau');
    const clientCode = fs.readFileSync(clientInitPath, 'utf8');
    assert.match(clientCode, /spawnConfetti/, 'Must trigger spawnConfetti on Rebirth or Celebration');
});

test('Multi-Agent All Skills Integration: Retention Engine Reward Claims', () => {
    const retentionPath = path.join(__dirname, '..', 'src', 'server', 'RetentionService.luau');
    const serverInitPath = path.join(__dirname, '..', 'src', 'server', 'init.server.luau');

    const retentionCode = fs.readFileSync(retentionPath, 'utf8');
    assert.match(retentionCode, /RetentionService\.claimPlaytimeReward/, 'Must export claimPlaytimeReward');
    assert.match(retentionCode, /RetentionService\.claimDailyReward/, 'Must export claimDailyReward');

    const serverCode = fs.readFileSync(serverInitPath, 'utf8');
    assert.match(serverCode, /ClaimPlaytimeRewardEvent/, 'Must wire ClaimPlaytimeRewardEvent');
    assert.match(serverCode, /ClaimDailyRewardEvent/, 'Must wire ClaimDailyRewardEvent');
});

test('Multi-Agent All Skills Integration: Monetization PromptPurchase Event', () => {
    const serverInitPath = path.join(__dirname, '..', 'src', 'server', 'init.server.luau');
    const serverCode = fs.readFileSync(serverInitPath, 'utf8');

    assert.match(serverCode, /PromptPurchaseEvent/, 'Must wire PromptPurchaseEvent');
    assert.match(serverCode, /MarketplaceService:PromptProductPurchase/, 'Must prompt developer products');
    assert.match(serverCode, /MarketplaceService:PromptGamePassPurchase/, 'Must prompt gamepass purchases');
});

test('Multi-Agent All Skills Integration: Economy Simulation CLI Execution', () => {
    const packageJsonPath = path.join(__dirname, '..', 'package.json');
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    assert.ok(packageJson.scripts.simulate, 'simulate script must be present in package.json');

    const output = execSync('node bin/simulate-economy.js', { encoding: 'utf8' });
    assert.match(output, /ROBLOX TYCOON ECONOMY BALANCE SIMULATOR/, 'Must output simulation header');
    assert.match(output, /Rebirth_Portal/, 'Must simulate and reach Rebirth Portal');
    assert.match(output, /Время до первого Rebirth \(TTFR\)/, 'Must output TTFR metric');
    assert.match(output, /БАЛАНС ИДЕАЛЕН/, 'Simulation must complete successfully');
});

test('Zero-Trust Adversarial Audit: P0 and P1 Security & Performance Fixes', () => {
    const serverInitPath = path.join(__dirname, '..', 'src', 'server', 'init.server.luau');
    const serverCode = fs.readFileSync(serverInitPath, 'utf8');

    // P0: OpenEggEvent debounce
    assert.match(serverCode, /eggOpenDebounce\[player\.UserId\]/, 'Must enforce egg open debounce');
    assert.match(serverCode, /eggOpenDebounce\[player\.UserId\] = nil/, 'Must clean up debounce on PlayerRemoving');

    // P0: PromptPurchaseEvent whitelist validation
    assert.match(serverCode, /isWhitelisted/, 'Must validate purchase ID against whitelist');
    assert.match(serverCode, /Blocked unauthorized purchase prompt/, 'Must log and block unauthorized product/gamepass prompts');

    // P1: Client connects to EquippedPetsEvent
    const clientInitPath = path.join(__dirname, '..', 'src', 'client', 'init.client.luau');
    const clientCode = fs.readFileSync(clientInitPath, 'utf8');
    assert.match(clientCode, /equippedPetsEvent\.OnClientEvent/, 'Client must connect to EquippedPetsEvent');
    assert.match(clientCode, /PetFollower\.syncEquippedPets/, 'Client must call PetFollower.syncEquippedPets on event');

    // P1: PetFollower performance optimization
    const followerPath = path.join(__dirname, '..', 'src', 'client', 'PetFollower.luau');
    const followerCode = fs.readFileSync(followerPath, 'utf8');
    assert.match(followerCode, /computeBaseOffset/, 'Must precalculate baseOffset on registration');
    assert.doesNotMatch(followerCode, /getTargetOffset/, 'Must not compute dynamic offset inside loop');
});

test('Zero-Trust Adversarial Audit Iteration 2: DoS & Input Validation', () => {
    const serverInitPath = path.join(__dirname, '..', 'src', 'server', 'init.server.luau');
    const serverCode = fs.readFileSync(serverInitPath, 'utf8');

    // P0: ClaimPlotEvent debounce to prevent Workspace recreation DoS
    assert.match(serverCode, /claimPlotDebounce\[player\.UserId\]/, 'Must enforce claim plot debounce');
    assert.match(serverCode, /claimPlotDebounce\[player\.UserId\] = nil/, 'Must clean up claim plot debounce on PlayerRemoving');

    // P1-14: Split debounce maps for playtime and daily
    assert.match(serverCode, /playtimeDebounce\[player\.UserId\]/, 'Must enforce playtime debounce');
    assert.match(serverCode, /dailyDebounce\[player\.UserId\]/, 'Must enforce daily debounce');
    assert.match(serverCode, /t >= 1 and t <= 5 and t == math\.floor\(t\)/, 'Must strictly validate tier as integer between 1 and 5');
    assert.match(serverCode, /playtimeDebounce\[player\.UserId\] = nil/, 'Must clean up playtime debounce on PlayerRemoving');

    // P1: AbilityService strict rejection of invalid slots (no fallback to base)
    const abilityPath = path.join(__dirname, '..', 'src', 'server', 'AbilityService.luau');
    const abilityCode = fs.readFileSync(abilityPath, 'utf8');
    assert.doesNotMatch(abilityCode, /AbilityService\.castAbility\(player, "base"\)/, 'Must not fallback to base ability on invalid slot');
});

test('Zero-Trust Adversarial Audit Iteration 3: Dead Player Objective & RNG Guard', () => {
    // P1: AirDropService ensures player is alive (Humanoid.Health > 0)
    const airdropPath = path.join(__dirname, '..', 'src', 'server', 'AirDropService.luau');
    const airdropCode = fs.readFileSync(airdropPath, 'utf8');
    assert.match(airdropCode, /hum\.Health <= 0/, 'AirDrop must cancel capture if player dies');
    assert.match(airdropCode, /capturingPlayer = nil/, 'AirDrop must reset capturingPlayer on death');

    // P1: PetService.rollEgg safely handles empty or zero-weight drops
    const petServicePath = path.join(__dirname, '..', 'src', 'server', 'PetService.luau');
    const petCode = fs.readFileSync(petServicePath, 'utf8');
    assert.match(petCode, /#egg\.drops == 0/, 'rollEgg must handle empty drops list');
    assert.match(petCode, /totalWeight <= 0/, 'rollEgg must return nil if totalWeight <= 0');
});

test('Zero-Trust Adversarial Audit Iteration 4: Ghost Vault Exploit & Rebirth Atomic Lock', () => {
    // P0: TycoonService exports resetVault and resets on Rebirth
    const tycoonServicePath = path.join(__dirname, '..', 'src', 'server', 'TycoonService.luau');
    const tycoonCode = fs.readFileSync(tycoonServicePath, 'utf8');
    assert.match(tycoonCode, /function TycoonService\.resetVault\(plotIndex/, 'TycoonService must export resetVault');
    assert.match(tycoonCode, /TycoonService\.resetVault\(pIndex\)/, 'Rebirth must reset base vault cash to prevent cheese');

    // P1: Atomic Rebirth transaction lock
    assert.match(tycoonCode, /rebirthLock\[player\.UserId\]/, 'performRebirth must use atomic transaction lock');
    assert.match(tycoonCode, /rebirthLock\[player\.UserId\] = nil/, 'Must release rebirth lock in all branches');

    // P0: PlotBuilder resets vault cash on plot resetToUnclaimed
    const plotBuilderPath = path.join(__dirname, '..', 'src', 'server', 'PlotBuilder.luau');
    const plotCode = fs.readFileSync(plotBuilderPath, 'utf8');
    assert.match(plotCode, /TycoonService\.resetVault\(plotIndex\)/, 'resetPlotToUnclaimed must reset vault cash');
});

test('Zero-Trust Adversarial Audit Iteration 5: Data Wipe Prevention & Backoff', () => {
    const dsPath = path.join(__dirname, '..', 'src', 'server', 'DataStoreManager.luau');
    const dsCode = fs.readFileSync(dsPath, 'utf8');

    // P0: Data wipe prevention on load failure
    assert.match(dsCode, /failedToLoad\[userId\] = true/, 'Must track load failures to protect real data');
    assert.match(dsCode, /if failedToLoad\[userId\] then/, 'saveData must check failedToLoad guard');
    assert.match(dsCode, /preventing data wipe/, 'Must log security warning and abort saving if load failed');

    // P1: Exponential backoff on retries
    assert.match(dsCode, /task\.wait\(attempt \* 1\.5\)/, 'saveData must use exponential backoff on retry');

    // P1: Cleanup session on player disconnect
    assert.match(dsCode, /function DataStoreManager\.clearPlayerSession/, 'DataStoreManager must export clearPlayerSession');
    const tycoonServicePath = path.join(__dirname, '..', 'src', 'server', 'TycoonService.luau');
    const tycoonCode = fs.readFileSync(tycoonServicePath, 'utf8');
    assert.match(tycoonCode, /DataStoreManager\.clearPlayerSession/, 'TycoonService must clear session on disconnect');
});

test('Zero-Trust Adversarial Audit Iteration 6: Scoping, Imports & Memory Leaks', () => {
    // P0: init.server.luau imports MonetizationConfig for purchase whitelisting
    const serverInitPath = path.join(__dirname, '..', 'src', 'server', 'init.server.luau');
    const serverCode = fs.readFileSync(serverInitPath, 'utf8');
    assert.match(serverCode, /local MonetizationConfig = require\(Shared:WaitForChild\("MonetizationConfig", 10\)\)/, 'Must require MonetizationConfig');

    // P1: TycoonService declares rebirthLock in module scope before onPlayerRemoving
    const tycoonPath = path.join(__dirname, '..', 'src', 'server', 'TycoonService.luau');
    const tycoonCode = fs.readFileSync(tycoonPath, 'utf8');
    const lockDeclPos = tycoonCode.indexOf('local rebirthLock: { [number]: boolean } = {}');
    const removingPos = tycoonCode.indexOf('function TycoonService.onPlayerRemoving');
    assert.ok(lockDeclPos !== -1, 'rebirthLock must be declared');
    assert.ok(removingPos !== -1, 'onPlayerRemoving must exist');
    assert.ok(lockDeclPos < removingPos, 'rebirthLock must be declared BEFORE onPlayerRemoving to prevent runtime scoping crash');

    // P1: JuiceEffects imports Workspace
    const juicePath = path.join(__dirname, '..', 'src', 'client', 'JuiceEffects.luau');
    const juiceCode = fs.readFileSync(juicePath, 'utf8');
    assert.match(juiceCode, /local Workspace = game:GetService\("Workspace"\)/, 'JuiceEffects must import Workspace');

    // P1: AbilityVFX Debris safety fallback on falling sky props
    const vfxPath = path.join(__dirname, '..', 'src', 'client', 'AbilityVFX.luau');
    const vfxCode = fs.readFileSync(vfxPath, 'utf8');
    assert.match(vfxCode, /Debris:AddItem\(prop, fallTime \+ 1\.0\)/, 'spawnFallingSkyProp must register Debris cleanup fallback');
    assert.match(vfxCode, /if prop and prop\.Parent then/, 'Must guard destruction against already destroyed props');
});
