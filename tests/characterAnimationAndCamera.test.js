const fs = require('fs');
const path = require('path');
const { test, describe } = require('node:test');
const assert = require('node:assert');

describe('CharacterAnimator and CinematicCamera System Tests', () => {
    const rootDir = path.resolve(__dirname, '..');
    const animatorPath = path.join(rootDir, 'src', 'client', 'CharacterAnimator.luau');
    const cameraPath = path.join(rootDir, 'src', 'client', 'CinematicCamera.luau');
    const vfxPath = path.join(rootDir, 'src', 'client', 'AbilityVFX.luau');

    test('CharacterAnimator.luau exists and uses strict typing', () => {
        assert.ok(fs.existsSync(animatorPath), 'CharacterAnimator.luau should exist');
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.startsWith('--!strict'), 'CharacterAnimator.luau must start with --!strict');
    });

    test('CharacterAnimator exports all required procedural poses including SHHH gesture and stopAnimation', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        const requiredFunctions = [
            'CharacterAnimator.playShhhPose',
            'CharacterAnimator.playGigachadFlex',
            'CharacterAnimator.playSigmaTilt',
            'CharacterAnimator.playGroundPound',
            'CharacterAnimator.playHammerSwing',
            'CharacterAnimator.playRizzlerFlourish',
            'CharacterAnimator.playSpinSalute',
            'CharacterAnimator.playMoneySnatch',
            'CharacterAnimator.restoreJoints',
            'CharacterAnimator.stopAnimation',
        ];

        for (const fn of requiredFunctions) {
            assert.ok(content.includes(fn), `CharacterAnimator must define and export ${fn}`);
        }
    });

    test('CharacterAnimator supports both R15 and R6 joint hierarchies', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('RightUpperArm') && content.includes('Right Shoulder'), 'Must support R15 and R6 right arm joints');
        assert.ok(content.includes('LeftUpperArm') && content.includes('Left Shoulder'), 'Must support R15 and R6 left arm joints');
        assert.ok(content.includes('UpperTorso') && content.includes('RootJoint'), 'Must support R15 and R6 torso/waist joints');
        assert.ok(content.includes('originalC0Cache'), 'Must cache original joint C0s to prevent permanent deformation');
    });

    test('CharacterAnimator cancels active joint tweens to prevent limb jitter and clashing', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('activeJointTweens'), 'Must track active joint tweens');
        assert.ok(content.includes('prev:Cancel()'), 'Must cancel previous active tween on the joint before playing new tween');
        assert.ok(content.includes('activeAnimTokens[character] = (activeAnimTokens[character] or 0) + 1'), 'restoreJoints must invalidate token to cancel delayed attack phases');
    });

    test('CinematicCamera.luau exists and exports camera director functions', () => {
        assert.ok(fs.existsSync(cameraPath), 'CinematicCamera.luau should exist');
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.startsWith('--!strict'), 'CinematicCamera.luau must start with --!strict');

        const requiredCameraFns = [
            'CinematicCamera.focusCutIn',
            'CinematicCamera.explosiveSnapBack',
            'CinematicCamera.groundSlamPerspective',
            'CinematicCamera.safeReset',
        ];

        for (const fn of requiredCameraFns) {
            assert.ok(content.includes(fn), `CinematicCamera must define and export ${fn}`);
        }
    });

    test('CinematicCamera handles FOV animation, Dutch angles and safe camera reset', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('FieldOfView'), 'CinematicCamera must animate FieldOfView');
        assert.ok(content.includes('CFrame.Angles(0, 0, roll)'), 'CinematicCamera must support Dutch roll angles');
        assert.ok(content.includes('Enum.CameraType.Custom'), 'CinematicCamera must safely restore CameraType to Custom');
    });

    test('AbilityVFX imports and invokes CharacterAnimator and CinematicCamera with explosiveSnapBack', () => {
        const content = fs.readFileSync(vfxPath, 'utf8');
        assert.ok(content.includes('CharacterAnimator') && content.includes('pcall(require, animModule)'), 'AbilityVFX must require CharacterAnimator');
        assert.ok(content.includes('CinematicCamera') && content.includes('pcall(require, cameraModule)'), 'AbilityVFX must require CinematicCamera');
        assert.ok(content.includes('CinematicCamera.explosiveSnapBack'), 'AbilityVFX must invoke CinematicCamera.explosiveSnapBack on impacts');

        // Verify Sigma ultimate uses playShhhPose and focusCutIn
        const sigmaMatch = content.match(/fId == "Sigma"[\s\S]*?slot == "ultimate"[\s\S]*?CharacterAnimator\.playShhhPose[\s\S]*?CinematicCamera\.focusCutIn/);
        assert.ok(sigmaMatch, 'Sigma ultimate must trigger CharacterAnimator.playShhhPose and CinematicCamera.focusCutIn');

        // Verify Mewing ultimate uses playShhhPose
        const mewingMatch = content.match(/fId == "Mewing"[\s\S]*?slot == "ultimate"[\s\S]*?CharacterAnimator\.playShhhPose/);
        assert.ok(mewingMatch, 'Mewing ultimate must trigger CharacterAnimator.playShhhPose');

        // Verify CaseOh ultimate uses playGroundPound and groundSlamPerspective
        const caseOhMatch = content.match(/fId == "CaseOh"[\s\S]*?slot == "ultimate"[\s\S]*?CharacterAnimator\.playGroundPound[\s\S]*?CinematicCamera\.groundSlamPerspective/);
        assert.ok(caseOhMatch, 'CaseOh ultimate must trigger CharacterAnimator.playGroundPound and CinematicCamera.groundSlamPerspective');

        // Verify TungTung ultimate uses playHammerSwing and focusCutIn
        const tungTungMatch = content.match(/fId == "TungTung"[\s\S]*?slot == "ultimate"[\s\S]*?CharacterAnimator\.playHammerSwing[\s\S]*?CinematicCamera\.focusCutIn/);
        assert.ok(tungTungMatch, 'TungTung ultimate must trigger CharacterAnimator.playHammerSwing and CinematicCamera.focusCutIn');

        // Verify debug console spam print is removed
        assert.ok(!content.includes('[AbilityVFX] Playing %s VFX for %s'), 'AbilityVFX must not contain debug spam print');
    });

    test('CharacterAnimator uses weak tables for cache to prevent memory leaks on death/respawn', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('setmetatable({}, { __mode = "k" })'), 'CharacterAnimator must use weak table mode "k" for instance caches');
    });

    test('CharacterAnimator supports R6 torso animations via rootJoint fallback', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('joints.waist or joints.rootJoint') || content.includes('joints.rootJoint or joints.waist'), 'Must support rootJoint fallback for torso animation');
    });

    test('CinematicCamera guards against FOV drift and hooks CharacterAdded for reset', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('if not isCinematicActive then'), 'Must guard originalFOV caching against FOV drift');
        assert.ok(content.includes('localPlayer.CharacterAdded'), 'Must listen to CharacterAdded to reset camera on respawn');
    });

    test('CinematicCamera cancels activeCameraTween in resetCamera to avoid fighting other FOV animations', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('activeCameraTween'), 'CinematicCamera must define activeCameraTween reference');
        assert.ok(content.includes('activeCameraTween:Cancel()'), 'CinematicCamera.resetCamera must cancel activeCameraTween');
    });

    test('CinematicCamera performs raycast occlusion checks for front, floor, and rear walls', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('Workspace:Raycast(targetFocusPoint'), 'focusCutIn must raycast to avoid clipping through base walls');
        assert.ok(content.includes('Workspace:Raycast(root.Position, Vector3.new(0, -6, 0)'), 'groundSlamPerspective must raycast to avoid placing camera under floor');
        assert.ok(content.includes('Workspace:Raycast(root.Position, backDir'), 'groundSlamPerspective must raycast backwards to avoid pushing camera into rear walls');
    });

    test('CinematicCamera hooks Humanoid.Died for immediate camera restoration upon player death', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('hum.Died:Connect'), 'CinematicCamera must listen to Humanoid.Died to immediately reset camera');
    });

    test('CharacterAnimator correctly rotates R6 RootJoint around local Z axis for torso yaw', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('CFrame.Angles(0, 0, math.rad(-35))'), 'R6 torso windup in hammer swing must rotate around local Z axis');
        assert.ok(content.includes('CFrame.Angles(0, 0, math.rad(45))'), 'R6 torso swing in hammer swing must rotate around local Z axis');
        assert.ok(content.includes('CFrame.Angles(0, 0, math.rad(180))'), 'R6 spin salute must rotate around local Z axis');
    });

    test('CharacterAnimator resets joints at the start of every pose to prevent stuck poses upon ability switch', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        const poseStarts = content.match(/restoreJoints\(character, joints, 0\.08\)/g);
        assert.ok(poseStarts && poseStarts.length >= 8, 'All 8 signature poses must call restoreJoints at start');
    });

    test('CharacterAnimator guards callbacks with isCharacterAlive, prevents thread leaks via task.delay, and cleans up tweens', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('isCharacterAlive(character)'), 'CharacterAnimator must check isCharacterAlive in delayed phases');
        assert.ok(content.includes('tw.Completed:Connect'), 'CharacterAnimator must disconnect/clear completed tweens');
        assert.ok(content.includes('activeAnimTokens[character] == token and isCharacterAlive(character)'), 'CharacterAnimator.playSpinSalute must validate activeAnimTokens and isCharacterAlive');
        assert.ok(!content.includes('tw1.Completed:Wait()'), 'CharacterAnimator.playSpinSalute must not block threads with Wait to prevent thread leaks');
        assert.ok(content.includes('deadConnections[hum]:Disconnect()'), 'CharacterAnimator must disconnect and clear deadConnections on death');
    });

    test('CinematicCamera uses RenderStepped dynamic tracking and clamps FOV against leaks', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('RunService.RenderStepped:Connect'), 'CinematicCamera must dynamically track character via RenderStepped');
        assert.ok(content.includes('cameraUpdateConnection:Disconnect()'), 'CinematicCamera.resetCamera must disconnect RenderStepped update');
        assert.ok(content.includes('math.clamp(originalFOV, 60, 105)'), 'CinematicCamera must clamp originalFOV on restore to prevent distortion');
        assert.ok(content.includes('originalFOV = DEFAULT_BASE_FOV'), 'CinematicCamera must anchor originalFOV to DEFAULT_BASE_FOV to prevent FOV drift');
    });

    test('CharacterAnimator cleans up C++ Tween instances with Destroy on cancel and completion', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('prev:Destroy()'), 'Must destroy previous tween instance on cancellation');
        assert.ok(content.includes('tw:Destroy()'), 'Must destroy completed tween instance');
    });

    test('CharacterAnimator resolves R15 Root joint from HumanoidRootPart and connects Humanoid.Died', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('joints.rootJoint = (hrp:FindFirstChild("Root")'), 'Must resolve R15 Root joint from HumanoidRootPart');
        assert.ok(content.includes('deadConnections[hum] = hum.Died:Connect'), 'Must hook Humanoid.Died to safely stop animation on death');
    });

    test('CharacterAnimator correctly rotates R6 RootJoint around local Y axis for torso pitch', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('CFrame.Angles(0, math.rad(-15), 0)'), 'R6 torso arch in gigachad flex must rotate around local Y axis');
        assert.ok(content.includes('CFrame.Angles(0, math.rad(-20), 0)'), 'R6 torso windup in ground pound must rotate around local Y axis');
        assert.ok(content.includes('CFrame.Angles(0, math.rad(35), 0)'), 'R6 torso slam in ground pound must rotate around local Y axis');
    });

    test('CinematicCamera excludes all players and cleans up tweens with Destroy', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('activeCameraTween:Destroy()'), 'CinematicCamera.resetCamera must destroy activeCameraTween');
        assert.ok(content.includes('Players:GetPlayers()'), 'CinematicCamera must exclude other players from occlusion raycasts');
        assert.ok(content.includes('dynRay'), 'CinematicCamera must perform real-time dynamic occlusion raycast in RenderStepped');
        assert.ok(content.includes('1.8, currentDist'), 'CinematicCamera.focusCutIn must enforce min 1.8 studs distance to prevent head clipping');
        assert.ok(content.includes('curFloorHit'), 'CinematicCamera.groundSlamPerspective must dynamically check floor height in RenderStepped');
    });

    test('AbilityVFX loader uses non-blocking lookups and implements LOD culling for animations', () => {
        const content = fs.readFileSync(vfxPath, 'utf8');
        assert.ok(!content.includes('WaitForChild("CharacterAnimator", 2)'), 'AbilityVFX must not stall with WaitForChild timeout on animator');
        assert.ok(!content.includes('WaitForChild("CinematicCamera", 2)'), 'AbilityVFX must not stall with WaitForChild timeout on camera');
        assert.ok(content.includes('shouldAnimate = rawCasterChar ~= nil and (isSelf or isWithinLOD(pos))'), 'AbilityVFX must implement LOD culling for procedural character animations');
    });
});

