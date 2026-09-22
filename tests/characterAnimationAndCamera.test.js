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

    test('CharacterAnimator exports all required procedural poses including SHHH gesture', () => {
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

    test('AbilityVFX imports and invokes CharacterAnimator and CinematicCamera', () => {
        const content = fs.readFileSync(vfxPath, 'utf8');
        assert.ok(content.includes('CharacterAnimator') && content.includes('pcall(require, animModule)'), 'AbilityVFX must require CharacterAnimator');
        assert.ok(content.includes('CinematicCamera') && content.includes('pcall(require, cameraModule)'), 'AbilityVFX must require CinematicCamera');

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
    });

    test('CharacterAnimator uses weak tables for cache to prevent memory leaks on death/respawn', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('setmetatable({}, { __mode = "k" })'), 'CharacterAnimator must use weak table mode "k" for instance caches');
    });

    test('CharacterAnimator supports R6 torso animations via rootJoint fallback', () => {
        const content = fs.readFileSync(animatorPath, 'utf8');
        assert.ok(content.includes('joints.waist or joints.rootJoint'), 'Must fallback to rootJoint when waist is nil for R6 torso animation');
    });

    test('CinematicCamera guards against FOV drift and hooks CharacterAdded for reset', () => {
        const content = fs.readFileSync(cameraPath, 'utf8');
        assert.ok(content.includes('if not isCinematicActive then'), 'Must guard originalFOV caching against FOV drift');
        assert.ok(content.includes('localPlayer.CharacterAdded'), 'Must listen to CharacterAdded to reset camera on respawn');
    });
});

