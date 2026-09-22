--!strict

--[=[
    AbilityVFX
    Клиентский движок сочных визуальных и звуковых эффектов для всех 48 способностей (8 фракций x 6 слотов):
    - 3D-частицы, ударные неоновые кольца, световые столбы, метеориты, банхаммеры
    - Пространственный 3D-звук в месте применения
    - Динамическая тряска камеры (Screen Shake) при мощных ударах
    - Импульс угла обзора (FOV Kick) при рывках мобильности
    - Парящие мемные боевые надписи над персонажем
]=]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local juiceModule = script:FindFirstChild("JuiceEffects")
    or (script.Parent and script.Parent:FindFirstChild("JuiceEffects"))
    or script:WaitForChild("JuiceEffects", 2)
    or (script.Parent and script.Parent:WaitForChild("JuiceEffects", 5))

local JuiceEffects: any = nil
if juiceModule and juiceModule:IsA("ModuleScript") then
    local ok, res = pcall(require, juiceModule)
    if ok and res then
        JuiceEffects = res
    end
end
if not JuiceEffects then
    JuiceEffects = {
        play3DSound = function() end,
        screenShake = function() end,
        traumaShake = function() end,
        fovPulse = function() end,
        showFloatingText = function() end,
        playEpicImpact = function() end,
        spawnDebrisBlast = function() end,
        cinematicVignettePulse = function() end,
        screenBloomFlash = function() end,
        spawnLightBurst = function() end,
        hitstop = function() end,
        cameraKick = function() end,
    }
end

local animModule = script:FindFirstChild("CharacterAnimator")
    or (script.Parent and script.Parent:FindFirstChild("CharacterAnimator"))
    or script:WaitForChild("CharacterAnimator", 2)
    or (script.Parent and script.Parent:WaitForChild("CharacterAnimator", 2))

local CharacterAnimator: any = nil
if animModule and animModule:IsA("ModuleScript") then
    local ok, res = pcall(require, animModule)
    if ok and res then
        CharacterAnimator = res
    end
end
if not CharacterAnimator then
    CharacterAnimator = {
        playShhhPose = function() end,
        playGigachadFlex = function() end,
        playSigmaTilt = function() end,
        playGroundPound = function() end,
        playHammerSwing = function() end,
        playRizzlerFlourish = function() end,
        playSpinSalute = function() end,
        playMoneySnatch = function() end,
    }
end

local cameraModule = script:FindFirstChild("CinematicCamera")
    or (script.Parent and script.Parent:FindFirstChild("CinematicCamera"))
    or script:WaitForChild("CinematicCamera", 2)
    or (script.Parent and script.Parent:WaitForChild("CinematicCamera", 2))

local CinematicCamera: any = nil
if cameraModule and cameraModule:IsA("ModuleScript") then
    local ok, res = pcall(require, cameraModule)
    if ok and res then
        CinematicCamera = res
    end
end
if not CinematicCamera then
    CinematicCamera = {
        focusCutIn = function() end,
        explosiveSnapBack = function() end,
        groundSlamPerspective = function() end,
        resetCamera = function() end,
    }
end

local AbilityVFX = {}
AbilityVFX.CharacterAnimator = CharacterAnimator
AbilityVFX.CinematicCamera = CinematicCamera

local localPlayer = Players.LocalPlayer
local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================================
-- ОПТИМИЗАЦИЯ И БЮДЖЕТИРОВАНИЕ (LOD & INSTANCE BUDGET)
-- ============================================================================
local MAX_ACTIVE_ROCKS = if isMobileDevice then 14 else 24 -- MAX_ACTIVE_ROCKS = 24 на ПК и 14 на смартфонах
local activeRocks: { BasePart } = {}
local LOD_DISTANCE = 120

local function getQualityScale(): number
    return if isMobileDevice then 0.5 else 1.0
end
AbilityVFX.getQualityScale = getQualityScale
AbilityVFX.isMobile = function() return isMobileDevice end
AbilityVFX.MAX_ACTIVE_ROCKS = MAX_ACTIVE_ROCKS
AbilityVFX.LOD_DISTANCE = LOD_DISTANCE

-- Проверка дистанционного отсева тяжелых эффектов
local function isWithinLOD(pos: Vector3): boolean
    local camera = Workspace.CurrentCamera
    if camera then
        local dist = (camera.CFrame.Position - pos).Magnitude
        if dist > LOD_DISTANCE then
            return false
        end
    end
    return true
end
AbilityVFX.isWithinLOD = isWithinLOD

-- Вытеснение старейших камней при превышении лимита (FIFO) с очисткой недействительных ссылок
local function pruneOldRocks(countToFree: number)
    for i = #activeRocks, 1, -1 do
        local r = activeRocks[i]
        if not r or not r.Parent then
            table.remove(activeRocks, i)
        end
    end

    while #activeRocks + countToFree > MAX_ACTIVE_ROCKS and #activeRocks > 0 do
        local oldRock = table.remove(activeRocks, 1)
        if oldRock and oldRock.Parent then
            oldRock:Destroy()
        end
    end
end

-- Определение фактической точки пола под объектом (защита от парения эффектов в воздухе при прыжках)
local function getGroundPosition(pos: Vector3, maxDrop: number?, extraIgnore: Instance?): Vector3
    local drop = maxDrop or 30
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            table.insert(ignoreList, p.Character)
        end
    end
    if extraIgnore then
        table.insert(ignoreList, extraIgnore)
    end
    rayParams.FilterDescendantsInstances = ignoreList
    local result = Workspace:Raycast(pos + Vector3.new(0, 1.5, 0), Vector3.new(0, -(drop + 1.5), 0), rayParams)
    if result then
        return result.Position
    end
    return pos
end
AbilityVFX.getGroundPosition = getGroundPosition

-- ============================================================================
-- БАЗОВЫЕ ГЕНЕРАТОРЫ И УДАРНЫЕ ВОЛНЫ
-- ============================================================================

-- Создание расширяющегося неонового ударного кольца на земле
-- C6 & C7 FIX: isWithinLOD check + mobile quality scale
local function createShockwaveRing(pos: Vector3, maxRadius: number, color: Color3, duration: number?)
    local groundPos = getGroundPosition(pos)
    if not isWithinLOD(groundPos) then return end
    local qScale = getQualityScale()
    local scaledRadius = maxRadius * qScale
    local dur = duration or 0.5
    local ring = Instance.new("Part")
    ring.Name = "ShockwaveRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.3, 1, 1)
    ring.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = 0.2
    ring.Parent = Workspace

    local tween = TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.3, scaledRadius * 2, scaledRadius * 2),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(ring, dur + 0.1)
end
AbilityVFX.createShockwaveRing = createShockwaveRing

-- Двухконтурная текстурированная ударная волна (горячее ядро + приземная пыль)
local function spawnTexturedShockwave(pos: Vector3, maxRadius: number, color: Color3, duration: number?)
    local dur = duration or 0.5
    local groundPos = getGroundPosition(pos)
    createShockwaveRing(groundPos, maxRadius, color, dur)

    if not isWithinLOD(groundPos) then return end

    local dustPart = Instance.new("Part")
    dustPart.Name = "ShockwaveDustEmitter"
    dustPart.Size = Vector3.new(1, 0.2, 1)
    dustPart.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.1, 0))
    dustPart.Transparency = 1
    dustPart.Anchored = true
    dustPart.CanCollide = false
    dustPart.Parent = Workspace

    local attach = Instance.new("Attachment")
    attach.Parent = dustPart

    local dustEmitter = Instance.new("ParticleEmitter")
    dustEmitter.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(200, 200, 200), 0.5))
    dustEmitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 4.5),
    })
    dustEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    dustEmitter.Speed = NumberRange.new(maxRadius * 1.5, maxRadius * 2.2)
    dustEmitter.Drag = 7.5
    dustEmitter.SpreadAngle = Vector2.new(90, 10)
    dustEmitter.Lifetime = NumberRange.new(0.4, 0.7)
    dustEmitter.Rate = 0
    dustEmitter.Parent = attach
    local dustCount = math.max(8, math.floor(20 * getQualityScale()))
    dustEmitter:Emit(dustCount)

    Debris:AddItem(dustPart, dur + 0.8)
end
AbilityVFX.spawnTexturedShockwave = spawnTexturedShockwave

-- Вспышка вертикального энергетического столба
-- C6 & C7 FIX: isWithinLOD + getQualityScale
local function createPillarOfLight(pos: Vector3, height: number, radius: number, color: Color3, duration: number?)
    local groundPos = getGroundPosition(pos)
    if not isWithinLOD(groundPos) then return end
    local qScale = getQualityScale()
    local scaledRadius = radius * qScale
    local dur = duration or 0.6
    local pillar = Instance.new("Part")
    pillar.Name = "EnergyPillar"
    pillar.Shape = Enum.PartType.Cylinder
    pillar.Size = Vector3.new(height, scaledRadius * 2, scaledRadius * 2)
    pillar.CFrame = CFrame.new(groundPos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pillar.Anchored = true
    pillar.CanCollide = false
    pillar.Material = Enum.Material.Neon
    pillar.Color = color
    pillar.Transparency = 0.25
    pillar.Parent = Workspace

    local tween = TweenService:Create(pillar, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(height, (scaledRadius * 2) * 1.6, (scaledRadius * 2) * 1.6),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(pillar, dur + 0.1)
end
AbilityVFX.createPillarOfLight = createPillarOfLight

-- Временный направленный неоновый лазер / луч
-- C6 & D7 FIX: LOD check + minimum 0.35s duration
local function createBeamLine(fromPos: Vector3, toPos: Vector3, color: Color3, thickness: number?, duration: number?)
    if not isWithinLOD(fromPos) and not isWithinLOD(toPos) then return end
    local dur = math.max(duration or 0.4, 0.35)
    local thick = (thickness or 0.8) * getQualityScale()
    local dist = (toPos - fromPos).Magnitude
    local beamPart = Instance.new("Part")
    beamPart.Name = "LaserBeamPart"
    beamPart.Size = Vector3.new(thick, thick, dist)
    beamPart.CFrame = CFrame.lookAt((fromPos + toPos) / 2, toPos)
    beamPart.Anchored = true
    beamPart.CanCollide = false
    beamPart.Material = Enum.Material.Neon
    beamPart.Color = color
    beamPart.Transparency = 0.1
    beamPart.Parent = Workspace

    local tween = TweenService:Create(beamPart, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(thick * 1.8, thick * 1.8, dist),
    })
    tween:Play()
    Debris:AddItem(beamPart, dur + 0.05)
end
AbilityVFX.createBeamLine = createBeamLine

-- Объемный луч с высокоэнергетическим белым сердечником и рикошетными искрами
local function spawnVolumetricLaser(fromPos: Vector3, toPos: Vector3, color: Color3, thickness: number?, duration: number?)
    local dur = duration or 0.45
    local thick = thickness or 1.0
    local dist = (toPos - fromPos).Magnitude

    -- Внешняя цветная оболочка
    createBeamLine(fromPos, toPos, color, thick, dur)

    -- Внутренний белоснежный сердечник
    local corePart = Instance.new("Part")
    corePart.Name = "LaserCorePart"
    corePart.Size = Vector3.new(thick * 0.45, thick * 0.45, dist)
    corePart.CFrame = CFrame.lookAt((fromPos + toPos) / 2, toPos)
    corePart.Anchored = true
    corePart.CanCollide = false
    corePart.Material = Enum.Material.Neon
    corePart.Color = Color3.fromRGB(255, 255, 255)
    corePart.Transparency = 0.05
    corePart.Parent = Workspace

    local tweenCore = TweenService:Create(corePart, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1,
        Size = Vector3.new(thick * 0.8, thick * 0.8, dist),
    })
    tweenCore:Play()
    Debris:AddItem(corePart, dur + 0.05)

    -- Вспышка в точке соприкосновения
    if JuiceEffects.spawnLightBurst then
        JuiceEffects.spawnLightBurst(toPos, color, 14, 25, 0.2)
    end
end
AbilityVFX.spawnVolumetricLaser = spawnVolumetricLaser

-- ============================================================================
-- ПРОЦЕДУРНАЯ ФИЗИКА МИРА (EARTH FRACTURE & CRACKS)
-- ============================================================================

-- Процедурный взрыв земли (вылет 3D-камней с зависанием в воздухе)
local function spawnEarthFracture(pos: Vector3, radius: number?, rockCount: number?)
    if not isWithinLOD(pos) then return end

    local actualGroundPos = getGroundPosition(pos)
    local groundY = actualGroundPos.Y

    local rad = radius or 12
    local count = math.clamp(rockCount or 8, 4, 10)
    local actualCount = math.max(2, math.floor(count * getQualityScale()))
    pruneOldRocks(actualCount)

    local rockColors = {
        Color3.fromRGB(80, 85, 90),
        Color3.fromRGB(65, 68, 72),
        Color3.fromRGB(50, 52, 55),
    }

    for i = 1, actualCount do
        local angle = (i / count) * math.pi * 2 + (math.random(-15, 15) * math.pi / 180)
        local dist = rad * (0.6 + math.random() * 0.4)
        local spawnX = actualGroundPos.X + math.cos(angle) * dist
        local spawnZ = actualGroundPos.Z + math.sin(angle) * dist

        local sx = 1.2 + math.random() * 1.8
        local sy = 1.8 + math.random() * 2.4
        local sz = 1.2 + math.random() * 1.8

        local rock = Instance.new("Part")
        rock.Name = "FractureRock"
        rock.Size = Vector3.new(sx, sy, sz)
        rock.CFrame = CFrame.new(spawnX, groundY - sy * 0.6, spawnZ)
        rock.Material = Enum.Material.Slate
        rock.Color = rockColors[math.random(1, #rockColors)]
        rock.Anchored = true
        rock.CanCollide = false
        rock.Parent = Workspace

        table.insert(activeRocks, rock)

        local targetY = groundY + sy * 0.45
        local tiltAngleX = math.random(-25, 25)
        local tiltAngleZ = math.random(-25, 25)
        local targetCF = CFrame.new(spawnX, targetY, spawnZ) * CFrame.Angles(math.rad(tiltAngleX), angle, math.rad(tiltAngleZ))

        -- 1. Быстрый вылет из земли
        local tUp = TweenService:Create(rock, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            CFrame = targetCF,
        })
        tUp:Play()

        -- 2. Зависание и плавное погружение обратно под землю с очисткой из очереди
        task.delay(0.14 + 0.22, function()
            if rock and rock.Parent then
                local sinkCF = CFrame.new(spawnX, groundY - sy * 1.2, spawnZ) * CFrame.Angles(math.rad(tiltAngleX), angle, math.rad(tiltAngleZ))
                local tDown = TweenService:Create(rock, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    CFrame = sinkCF,
                    Transparency = 1,
                })
                tDown:Play()
                tDown.Completed:Connect(function()
                    local idx = table.find(activeRocks, rock)
                    if idx then
                        table.remove(activeRocks, idx)
                    end
                    if rock and rock.Parent then
                        rock:Destroy()
                    end
                end)
            end
        end)

        Debris:AddItem(rock, 1.1)
    end
end
AbilityVFX.spawnEarthFracture = spawnEarthFracture

-- Декаль трещин земли с плавным растворением
local function spawnGroundCracks(pos: Vector3, radius: number?, color: Color3?, duration: number?)
    if not isWithinLOD(pos) then return end

    local actualPos = getGroundPosition(pos)
    local rad = radius or 12
    local dur = duration or 3.0
    local crackColor = color or Color3.fromRGB(35, 35, 40)

    local crackPlate = Instance.new("Part")
    crackPlate.Name = "GroundCracksPlate"
    crackPlate.Shape = Enum.PartType.Cylinder
    crackPlate.Size = Vector3.new(0.04, rad * 2, rad * 2)
    crackPlate.CFrame = CFrame.new(actualPos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
    crackPlate.Anchored = true
    crackPlate.CanCollide = false
    crackPlate.Material = Enum.Material.Basalt
    crackPlate.Color = crackColor
    crackPlate.Transparency = 0.2
    crackPlate.Parent = Workspace

    local tween = TweenService:Create(crackPlate, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(crackPlate, dur + 0.1)
end
AbilityVFX.spawnGroundCracks = spawnGroundCracks

-- Втягивание частиц (Anticipation Vortex / Windup)
local function spawnAnticipationVortex(pos: Vector3, color: Color3, duration: number?)
    if not isWithinLOD(pos) then return end

    local dur = duration or 0.3
    local vortexPart = Instance.new("Part")
    vortexPart.Name = "AnticipationVortex"
    vortexPart.Size = Vector3.new(0.2, 0.2, 0.2)
    vortexPart.CFrame = CFrame.new(pos)
    vortexPart.Transparency = 1
    vortexPart.Anchored = true
    vortexPart.CanCollide = false
    vortexPart.Parent = Workspace

    local attach = Instance.new("Attachment")
    attach.Parent = vortexPart

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(color)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    emitter.Speed = NumberRange.new(-25, -12) -- Отрицательная скорость затягивает частицы внутрь
    emitter.Drag = 5.0
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Lifetime = NumberRange.new(0.2, 0.35)
    emitter.Rate = 0
    emitter.Parent = attach
    local vortexBurst = math.max(6, math.floor(18 * getQualityScale()))
    emitter:Emit(vortexBurst)

    Debris:AddItem(vortexPart, dur + 0.4)
end
AbilityVFX.spawnAnticipationVortex = spawnAnticipationVortex

-- Вращающийся магический круг под ногами кастера
local function spawnMagicCircle(pos: Vector3, color: Color3, duration: number?)
    if not isWithinLOD(pos) then return end

    local dur = duration or 0.8
    local circle = Instance.new("Part")
    circle.Name = "MagicRuneCircle"
    circle.Shape = Enum.PartType.Cylinder
    circle.Size = Vector3.new(0.05, 8, 8)
    circle.CFrame = CFrame.new(pos - Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
    circle.Anchored = true
    circle.CanCollide = false
    circle.Material = Enum.Material.Neon
    circle.Color = color
    circle.Transparency = 0.35
    circle.Parent = Workspace

    local tweenRot = TweenService:Create(circle, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
        CFrame = circle.CFrame * CFrame.Angles(math.rad(180), 0, 0),
        Transparency = 1,
    })
    tweenRot:Play()
    Debris:AddItem(circle, dur + 0.1)
end
AbilityVFX.spawnMagicCircle = spawnMagicCircle

-- Атмосферный вход падающего объекта с неба (метеорит, наковальня, банхаммер, пицца)
-- C6 & C13 FIX: isWithinLOD check + safe cleanup
local function spawnFallingSkyProp(targetPos: Vector3, propBuilder: () -> BasePart, onImpact: () -> (), fallHeight: number?, customCrater: boolean?)
    if not isWithinLOD(targetPos) then return end
    local h = fallHeight or 55
    -- Наклонная траектория падения (динамический угол входа в атмосферу)
    local spawnPos = targetPos + Vector3.new(10, h, 8)
    local prop = propBuilder()
    local rot = prop.CFrame.Rotation
    prop.CFrame = CFrame.new(spawnPos) * rot
    prop.Anchored = true
    prop.CanCollide = false
    prop.Parent = Workspace

    local fallTime = 0.42
    local tween = TweenService:Create(prop, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        CFrame = CFrame.new(targetPos) * rot,
    })
    tween:Play()
    -- C13 FIX: Debris safety fallback (в случае если tween.Completed не сработает)
    Debris:AddItem(prop, fallTime + 1.0)
    tween.Completed:Connect(function()
        if prop and prop.Parent then
            prop:Destroy()
        end
        -- Базовый физический кратер при детонации падающего объекта (если колбэк не реализует кастомный)
        if not customCrater then
            spawnEarthFracture(targetPos, 12, 8)
            spawnGroundCracks(targetPos, 14, Color3.fromRGB(35, 35, 40), 2.8)
            if JuiceEffects.spawnLightBurst then
                JuiceEffects.spawnLightBurst(targetPos, Color3.fromRGB(255, 190, 80), 18, 45, 0.25)
            end
        end
        onImpact()
    end)
end
AbilityVFX.spawnFallingSkyProp = spawnFallingSkyProp

-- Главная функция проигрывания VFX/SFX способности
function AbilityVFX.play(caster: Player, factionId: string, slot: string, originPos: Vector3, lookDir: Vector3)
    local isSelf = (caster == localPlayer)
    local pos = originPos or Vector3.zero
    local lookVector = if lookDir and lookDir.Magnitude > 0 then lookDir.Unit else Vector3.new(0, 0, -1)
    local fId = if factionId and factionId ~= "" then factionId else "Skibidi"
    local casterChar = if caster then caster.Character else nil

    print(string.format("[AbilityVFX] Playing %s VFX for %s (slot: %s, isSelf: %s)", fId, tostring(caster and caster.Name), tostring(slot), tostring(isSelf)))

    -- 1. SKIBIDI TOILET (Hydro-Chaos & Gold / Porcelain)
    if fId == "Skibidi" then
        if slot == "base" then
            -- Skibidi Spin (Вихрь смыва)
            if casterChar then CharacterAnimator.playSpinSalute(casterChar, 0.8) end
            spawnAnticipationVortex(pos, Color3.fromRGB(0, 180, 255), 0.3)
            spawnTexturedShockwave(pos, 22, Color3.fromRGB(0, 180, 255), 0.45)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(0, 200, 255), 14, 30, 0.2)
            JuiceEffects.play3DSound("splash", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🌊 ВИХРЬ СМЫВА!", Color3.fromRGB(0, 180, 255))
            if isSelf then JuiceEffects.traumaShake(0.4) end

        elseif slot == "tactical" then
            -- Скибиди Броня (Керамический панцирь)
            spawnMagicCircle(pos, Color3.fromRGB(241, 196, 15), 0.7)
            createPillarOfLight(pos, 10, 4.5, Color3.fromRGB(240, 240, 255), 0.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(241, 196, 15), 12, 25, 0.2)
            JuiceEffects.play3DSound("magic", pos, 0.8)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🛡️ КЕРАМИЧЕСКИЙ ПАНЦИРЬ!", Color3.fromRGB(255, 255, 255))

        elseif slot == "ultimate" then
            -- Мега-Смыв 3000 (Титанический водоворот)
            if casterChar then CharacterAnimator.playSpinSalute(casterChar, 1.2) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.4, 5.0, -10) end
            spawnAnticipationVortex(pos, Color3.fromRGB(0, 120, 255), 0.25)
            spawnMagicCircle(pos, Color3.fromRGB(0, 220, 255), 0.8)
            spawnTexturedShockwave(pos, 36, Color3.fromRGB(0, 180, 255), 0.7)
            spawnEarthFracture(pos, 14, 7)
            spawnGroundCracks(pos, 16, Color3.fromRGB(0, 100, 180), 2.8)
            createPillarOfLight(pos, 28, 8, Color3.fromRGB(0, 220, 255), 0.8)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(0, 200, 255), 20, 50, 0.3)
            JuiceEffects.spawnDebrisBlast(pos, 16, Color3.fromRGB(0, 200, 255))
            JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
            JuiceEffects.play3DSound("splash", pos, 1.3)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🌀 МЕГА-СМЫВ 3000!", Color3.fromRGB(0, 220, 255))
            if isSelf then
                JuiceEffects.traumaShake(0.85)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(0, 180, 255), 0.25)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(0, 180, 255), 0.7)
                JuiceEffects.hitstop(0.05)
            end

        elseif slot == "special" then
            -- Skibidi Dop Dop Anthem (Звуковой мем-взрыв)
            if casterChar then CharacterAnimator.playSpinSalute(casterChar, 0.9) end
            for i = 1, 3 do
                task.delay((i - 1) * 0.12, function()
                    spawnTexturedShockwave(pos, 12 * i + 4, Color3.fromRGB(255, 215, 0), 0.4)
                end)
            end
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(255, 215, 0), 16, 35, 0.25)
            JuiceEffects.play3DSound("horn", pos, 1.1)
            JuiceEffects.play3DSound("chime", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "🎶 SKIBIDI DOP DOP YES YES!", Color3.fromRGB(255, 215, 0))
            if isSelf then JuiceEffects.traumaShake(0.55) end

        elseif slot == "mobility" then
            -- Скибиди Ракета
            spawnVolumetricLaser(pos, pos + lookVector * 34, Color3.fromRGB(255, 140, 0), 1.4, 0.35)
            spawnTexturedShockwave(pos, 14, Color3.fromRGB(255, 120, 0), 0.35)
            JuiceEffects.play3DSound("dash", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🚀 РАКЕТНЫЙ СМЫВ!", Color3.fromRGB(255, 120, 0))
            if isSelf then
                JuiceEffects.fovPulse(16, 0.4)
                JuiceEffects.cameraKick(lookVector, 0.55)
            end

        elseif slot == "godmode" then
            -- Титан Скибиди-Крушитель (Падение Золотого Унитаза Титана)
            if casterChar then CharacterAnimator.playSpinSalute(casterChar, 1.5) end
            if isSelf and casterChar then CinematicCamera.groundSlamPerspective(casterChar, 0.65) end
            spawnFallingSkyProp(pos, function()
                local titanProp = Instance.new("Part")
                titanProp.Size = Vector3.new(10, 8, 8)
                titanProp.Material = Enum.Material.Neon
                titanProp.Color = Color3.fromRGB(241, 196, 15)
                return titanProp
            end, function()
                spawnEarthFracture(pos, 18, 10)
                spawnGroundCracks(pos, 20, Color3.fromRGB(200, 150, 0), 3.5)
                createPillarOfLight(pos, 45, 16, Color3.fromRGB(255, 215, 0), 1.2)
                spawnTexturedShockwave(pos, 48, Color3.fromRGB(255, 120, 0), 1.0)
                JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(255, 215, 0), 24, 65, 0.35)
                JuiceEffects.spawnDebrisBlast(pos, 22, Color3.fromRGB(241, 196, 15))
                JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "⚡ ТИТАН СКИБИДИ-КРУШИТЕЛЬ!", Color3.fromRGB(255, 215, 0))
                if isSelf then
                    JuiceEffects.traumaShake(1.3, 6, 0.8)
                    JuiceEffects.screenBloomFlash(Color3.fromRGB(255, 215, 0), 0.4)
                    JuiceEffects.cinematicVignettePulse(Color3.fromRGB(255, 215, 0), 0.85)
                    JuiceEffects.hitstop(0.07)
                end
            end, 55, true)
            -- C8 FIX: ongoing hammer quake VFX for 8s
            for step = 1, 7 do
                task.delay(step * 1.0, function()
                    local center = if caster and caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
                        then caster.Character.HumanoidRootPart.Position
                        else pos
                    spawnEarthFracture(center, 12, 6)
                    spawnTexturedShockwave(center, 20, Color3.fromRGB(255, 120, 0), 0.4)
                    JuiceEffects.spawnLightBurst(center, Color3.fromRGB(255, 215, 0), 16, 25, 0.2)
                    JuiceEffects.play3DSound("slam", center, 0.8)
                end)
            end
        end

    -- 2. GIGACHAD MEWING (Looksmaxing / Diamond & Granite Monolith)
    elseif fId == "Mewing" then
        if slot == "base" then
            -- Mewing Stare (Челюстной лазерный стан + жест SHHH)
            if casterChar then CharacterAnimator.playShhhPose(casterChar, 1.0) end
            spawnVolumetricLaser(pos + Vector3.new(0, 2, 0), pos + lookVector * 32 + Vector3.new(0, 2, 0), Color3.fromRGB(0, 220, 255), 0.85, 0.35)
            spawnTexturedShockwave(pos, 12, Color3.fromRGB(0, 220, 255), 0.3)
            JuiceEffects.play3DSound("laser", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🤫 MEWING STARE!", Color3.fromRGB(0, 220, 255))
            if isSelf then JuiceEffects.traumaShake(0.35) end

        elseif slot == "tactical" then
            -- Алмазный Подбородок (Отражающий кристалл + жест SHHH)
            if casterChar then CharacterAnimator.playShhhPose(casterChar, 1.1) end
            createPillarOfLight(pos, 9, 4, Color3.fromRGB(180, 240, 255), 0.5)
            spawnMagicCircle(pos, Color3.fromRGB(0, 240, 255), 0.6)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(0, 240, 255), 15, 30, 0.2)
            JuiceEffects.play3DSound("parry", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "💎 АЛМАЗНЫЙ ПОДБОРОДОК!", Color3.fromRGB(0, 230, 255))

        elseif slot == "ultimate" then
            -- Bye Bye Shockwave (Сверхзвуковой плоский срез + жест SHHH и наезд камеры)
            if casterChar then CharacterAnimator.playShhhPose(casterChar, 1.3) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.45, 4.5, 12) end
            spawnTexturedShockwave(pos, 38, Color3.fromRGB(0, 240, 255), 0.65)
            spawnEarthFracture(pos, 15, 8)
            spawnGroundCracks(pos, 16, Color3.fromRGB(0, 180, 220), 2.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(0, 240, 255), 22, 50, 0.25)
            JuiceEffects.spawnDebrisBlast(pos, 18, Color3.fromRGB(0, 240, 255))
            JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🤫🧏 BYE BYE!", Color3.fromRGB(0, 240, 255))
            if isSelf then
                JuiceEffects.traumaShake(0.9)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(0, 220, 255), 0.7)
                JuiceEffects.hitstop(0.06)
                JuiceEffects.cameraKick(-lookVector, 0.7)
            end

        elseif slot == "special" then
            -- Looksmaxing Flash (Вспышка ультра-резкости + жест SHHH)
            if casterChar then CharacterAnimator.playShhhPose(casterChar, 0.9) end
            spawnTexturedShockwave(pos, 25, Color3.fromRGB(0, 220, 255), 0.4)
            createPillarOfLight(pos, 20, 7, Color3.fromRGB(255, 255, 255), 0.45)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(255, 255, 255), 24, 45, 0.25)
            JuiceEffects.play3DSound("magic", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "✨ LOOKSMAXING FLASH!", Color3.fromRGB(255, 255, 255))
            -- C15 FIX: Ослепление близких игроков (для кастера лёгкая вспышка, для жертв — сервер отправит BLIND)
            if isSelf then
                JuiceEffects.screenBloomFlash(Color3.fromRGB(255, 255, 255), 0.35)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(255, 255, 255), 0.5)
            end

        elseif slot == "mobility" then
            -- Гигачад Рывок (Таран плечом)
            spawnVolumetricLaser(pos, pos + lookVector * 30, Color3.fromRGB(0, 220, 255), 1.2, 0.3)
            spawnTexturedShockwave(pos, 14, Color3.fromRGB(189, 195, 199), 0.35)
            JuiceEffects.play3DSound("dash", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🗿 ТАРАН ГИГАЧАДА!", Color3.fromRGB(0, 220, 255))
            if isSelf then
                JuiceEffects.fovPulse(15, 0.35)
                JuiceEffects.cameraKick(lookVector, 0.5)
            end

        elseif slot == "godmode" then
            -- Альфа Доминация (Монументальное сокрушение + Гигачад Power Flex)
            if casterChar then CharacterAnimator.playGigachadFlex(casterChar, 1.8) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.5, 4.8, 0) end
            spawnAnticipationVortex(pos, Color3.fromRGB(0, 240, 255), 0.3)
            spawnEarthFracture(pos, 18, 10)
            spawnGroundCracks(pos, 20, Color3.fromRGB(0, 160, 200), 3.2)
            createPillarOfLight(pos, 48, 14, Color3.fromRGB(0, 240, 255), 1.1)
            spawnTexturedShockwave(pos, 45, Color3.fromRGB(255, 255, 255), 0.9)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(0, 240, 255), 24, 60, 0.35)
            JuiceEffects.spawnDebrisBlast(pos, 24, Color3.fromRGB(0, 240, 255))
            JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "👑 АЛЬФА ДОМИНАЦИЯ!", Color3.fromRGB(0, 240, 255))
            if isSelf then
                JuiceEffects.traumaShake(1.25)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(0, 240, 255), 0.4)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(0, 240, 255), 0.85)
                JuiceEffects.hitstop(0.06)
            end
        end

    -- 3. PATRICK SIGMA (Phonk Rage / Dark Neon Crimson & Shadow Glitch)
    elseif fId == "Sigma" then
        if slot == "base" then
            -- Phonk Rage (Багрово-пурпурная ярость + наклон головы)
            if casterChar then CharacterAnimator.playSigmaTilt(casterChar, 0.7) end
            spawnTexturedShockwave(pos, 20, Color3.fromRGB(231, 76, 60), 0.45)
            spawnMagicCircle(pos, Color3.fromRGB(142, 68, 173), 0.7)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(231, 76, 60), 15, 30, 0.2)
            JuiceEffects.play3DSound("electric", pos, 0.9)
            JuiceEffects.play3DSound("slam", pos, 0.8)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🔥 PHONK RAGE!", Color3.fromRGB(231, 76, 60))
            if isSelf then JuiceEffects.traumaShake(0.4) end

        elseif slot == "tactical" then
            -- Сигма Парирование (Багровый защитный крест + стойка SHHH)
            if casterChar then CharacterAnimator.playShhhPose(casterChar, 0.6) end
            spawnVolumetricLaser(pos + Vector3.new(-3, 1.5, 0), pos + Vector3.new(3, 1.5, 0), Color3.fromRGB(255, 50, 50), 0.8, 0.45)
            spawnVolumetricLaser(pos + Vector3.new(0, -1.5, 0), pos + Vector3.new(0, 4.5, 0), Color3.fromRGB(255, 50, 50), 0.8, 0.45)
            JuiceEffects.spawnLightBurst(pos + lookVector * 3, Color3.fromRGB(255, 50, 50), 22, 25, 0.25)
            JuiceEffects.play3DSound("parry", pos, 1.2)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "⚡ СИГМА ПАРИРОВАНИЕ!", Color3.fromRGB(255, 50, 50))
            if isSelf then JuiceEffects.hitstop(0.07) end

        elseif slot == "ultimate" then
            -- Сигма Доминация (Аура превосходства + культовый жест SHHH и голландский угол камеры)
            if casterChar then CharacterAnimator.playShhhPose(casterChar, 1.4) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.5, 4.5, -14) end
            spawnEarthFracture(pos, 15, 8)
            spawnGroundCracks(pos, 16, Color3.fromRGB(60, 10, 20), 2.8)
            spawnTexturedShockwave(pos, 36, Color3.fromRGB(231, 76, 60), 0.7)
            createPillarOfLight(pos, 26, 8, Color3.fromRGB(142, 68, 173), 0.75)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(231, 76, 60), 22, 50, 0.3)
            JuiceEffects.spawnDebrisBlast(pos, 18, Color3.fromRGB(231, 76, 60))
            JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🤫 СИГМА ДОМИНАЦИЯ!", Color3.fromRGB(231, 76, 60))
            if isSelf then
                JuiceEffects.traumaShake(0.9)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(231, 76, 60), 0.3)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(231, 76, 60), 0.7)
            end

        elseif slot == "special" then
            -- Lone Wolf Grindset (Теневая невидимость + наклон)
            if casterChar then CharacterAnimator.playSigmaTilt(casterChar, 0.8) end
            spawnTexturedShockwave(pos, 16, Color3.fromRGB(30, 30, 35), 0.5)
            JuiceEffects.play3DSound("teleport", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🐺 LONE WOLF GRINDSET!", Color3.fromRGB(180, 180, 180))

        elseif slot == "mobility" then
            -- Теневой Шаг (Телепорт за спину)
            spawnVolumetricLaser(pos, pos + lookVector * 28, Color3.fromRGB(142, 68, 173), 1.0, 0.35)
            JuiceEffects.play3DSound("teleport", pos, 0.9)
            JuiceEffects.play3DSound("whoosh", pos, 0.8)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🔪 ТЕНЕВОЙ ШАГ!", Color3.fromRGB(142, 68, 173))
            if isSelf then JuiceEffects.fovPulse(16, 0.35) end

        elseif slot == "godmode" then
            -- Brazilian Phonk Overload (Перегрузка фонка и молний + наклон сигмы и кинематографическая камера)
            if casterChar then CharacterAnimator.playSigmaTilt(casterChar, 1.8) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.5, 4.8, 10) end
            spawnEarthFracture(pos, 18, 9)
            spawnGroundCracks(pos, 20, Color3.fromRGB(80, 10, 30), 3.5)
            createPillarOfLight(pos, 45, 12, Color3.fromRGB(231, 76, 60), 1.1)
            spawnTexturedShockwave(pos, 48, Color3.fromRGB(142, 68, 173), 1.0)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(231, 76, 60), 24, 60, 0.35)
            JuiceEffects.spawnDebrisBlast(pos, 22, Color3.fromRGB(231, 76, 60))
            JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "⚡ BRAZILIAN PHONK OVERLOAD!", Color3.fromRGB(231, 76, 60))
            if isSelf then
                JuiceEffects.traumaShake(1.3)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(231, 76, 60), 0.4)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(142, 68, 173), 0.85)
            end
            for step = 1, 7 do
                task.delay(step * 1.0, function()
                    local center = if caster and caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
                        then caster.Character.HumanoidRootPart.Position
                        else pos
                    local strikePos = center + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))
                    createBeamLine(strikePos + Vector3.new(0, 35, 0), strikePos, Color3.fromRGB(255, 50, 50), 0.9, 0.35)
                    createShockwaveRing(strikePos, 10, Color3.fromRGB(231, 76, 60), 0.4)
                    JuiceEffects.spawnLightBurst(strikePos, Color3.fromRGB(255, 50, 50), 16, 25, 0.2)
                    JuiceEffects.play3DSound("electric", strikePos, 0.8)
                end)
            end
        end

    -- 4. FANUM TAX (Grease / Street Food Feast / Cash & Sizzle)
    elseif fId == "FanumTax" then
        if slot == "base" then
            -- Tax Snatch (Выкачивание наличных + анимация кражи)
            if casterChar then CharacterAnimator.playMoneySnatch(casterChar, 0.6) end
            spawnVolumetricLaser(pos + lookVector * 22, pos, Color3.fromRGB(241, 196, 15), 0.9, 0.35)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(241, 196, 15), 14, 25, 0.2)
            JuiceEffects.play3DSound("snatch", pos, 1.1)
            JuiceEffects.play3DSound("cash", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🍔 НАЛОГ ВЗЯТ!", Color3.fromRGB(241, 196, 15))

        elseif slot == "tactical" then
            -- Ловушка Фастфуда (Масляная лужа)
            -- C11 FIX: Персистентная масляная зона на 8с
            local ground = getGroundPosition(pos)
            local oilPart = Instance.new("Part")
            oilPart.Name = "OilPuddleVFX"
            oilPart.Size = Vector3.new(18, 0.1, 18)
            oilPart.Shape = Enum.PartType.Cylinder
            oilPart.CFrame = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
            oilPart.Anchored = true
            oilPart.CanCollide = false
            oilPart.Material = Enum.Material.Glass
            oilPart.Color = Color3.fromRGB(60, 45, 15)
            oilPart.Transparency = 0.35
            oilPart.Parent = Workspace
            Debris:AddItem(oilPart, 8)

            spawnGroundCracks(pos, 14, Color3.fromRGB(200, 130, 20), 3.2)
            spawnTexturedShockwave(pos, 15, Color3.fromRGB(230, 126, 34), 0.5)
            JuiceEffects.play3DSound("splash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🍟 МАСЛЯНАЯ ЛОВУШКА!", Color3.fromRGB(230, 126, 34))

        elseif slot == "mobility_land" then
            -- C10 FIX: VFX приземления Cola Rocket Jump
            spawnEarthFracture(pos, 14, 6)
            spawnTexturedShockwave(pos, 22, Color3.fromRGB(230, 126, 34), 0.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(255, 140, 0), 18, 35, 0.25)
            JuiceEffects.spawnDebrisBlast(pos, 12, Color3.fromRGB(255, 140, 0))
            JuiceEffects.play3DSound("slam", pos, 1.2)
            JuiceEffects.play3DSound("splash", pos, 1.0)
            if isSelf then JuiceEffects.traumaShake(0.65) end

        elseif slot == "ultimate" then
            -- Великий Налоговый Аудит (Вихрь купюр и монет + анимация кражи и зум камеры)
            if casterChar then CharacterAnimator.playMoneySnatch(casterChar, 1.2) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.45, 5.0, 8) end
            spawnAnticipationVortex(pos, Color3.fromRGB(241, 196, 15), 0.25)
            spawnEarthFracture(pos, 14, 7)
            spawnGroundCracks(pos, 16, Color3.fromRGB(180, 90, 10), 2.8)
            spawnTexturedShockwave(pos, 35, Color3.fromRGB(241, 196, 15), 0.7)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(241, 196, 15), 20, 50, 0.3)
            JuiceEffects.spawnDebrisBlast(pos, 18, Color3.fromRGB(241, 196, 15))
            JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
            JuiceEffects.play3DSound("cash", pos, 1.3)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🍕 НАЛОГОВЫЙ АУДИТ!", Color3.fromRGB(241, 196, 15))
            if isSelf then
                JuiceEffects.traumaShake(0.85)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(241, 196, 15), 0.25)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(241, 196, 15), 0.7)
            end

        elseif slot == "special" then
            -- Fries Carpet Bomb (Ковровая бомбардировка картошкой фри)
            if casterChar then CharacterAnimator.playMoneySnatch(casterChar, 0.7) end
            for i = 1, 3 do
                task.delay((i - 1) * 0.12, function()
                    local bombPos = pos + lookVector * (9 * i)
                    spawnEarthFracture(bombPos, 8, 4)
                    spawnTexturedShockwave(bombPos, 14, Color3.fromRGB(230, 126, 34), 0.35)
                    JuiceEffects.spawnLightBurst(bombPos, Color3.fromRGB(255, 140, 0), 14, 25, 0.2)
                end)
            end
            JuiceEffects.play3DSound("explosion", pos, 1.1)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "🍟 КОВРОВАЯ БОМБАРДИРОВКА!", Color3.fromRGB(230, 126, 34))

        elseif slot == "mobility" then
            -- Cola Rocket Jump (Струя шипучей колы)
            createPillarOfLight(pos, 18, 5, Color3.fromRGB(100, 40, 20), 0.45)
            spawnTexturedShockwave(pos, 12, Color3.fromRGB(230, 126, 34), 0.35)
            JuiceEffects.play3DSound("dash", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🥤 COLA ROCKET JUMP!", Color3.fromRGB(211, 84, 0))
            if isSelf then
                JuiceEffects.fovPulse(17, 0.4)
                JuiceEffects.cameraKick(Vector3.new(0, 1, 0), 0.6)
            end

        elseif slot == "godmode" then
            -- Мега-Фанум Пиршество (Падение гигантской золотой пиццы)
            if casterChar then CharacterAnimator.playMoneySnatch(casterChar, 1.5) end
            if isSelf and casterChar then CinematicCamera.groundSlamPerspective(casterChar, 0.7) end
            spawnFallingSkyProp(pos, function()
                local pizza = Instance.new("Part")
                pizza.Shape = Enum.PartType.Cylinder
                pizza.Size = Vector3.new(3, 14, 14)
                pizza.CFrame = CFrame.Angles(0, 0, math.rad(90))
                pizza.Material = Enum.Material.Neon
                pizza.Color = Color3.fromRGB(241, 196, 15)
                return pizza
            end, function()
                createPillarOfLight(pos, 45, 15, Color3.fromRGB(255, 140, 0), 1.2)
                spawnTexturedShockwave(pos, 48, Color3.fromRGB(241, 196, 15), 1.0)
                JuiceEffects.spawnDebrisBlast(pos, 24, Color3.fromRGB(241, 196, 15))
                JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
                JuiceEffects.play3DSound("cash", pos, 1.4)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "🍕 МЕГА-ФАНУМ ПИРШЕСТВО!", Color3.fromRGB(255, 215, 0))
                if isSelf then
                    JuiceEffects.traumaShake(1.35)
                    JuiceEffects.screenBloomFlash(Color3.fromRGB(241, 196, 15), 0.4)
                    JuiceEffects.cinematicVignettePulse(Color3.fromRGB(241, 196, 15), 0.85)
                end
            end, 55)
        end

    -- 5. GRIMACE SHAKE (Toxic Biohazard / Eldritch Purple)
    elseif fId == "Grimace" then
        if slot == "base" then
            -- Grimace Cloud (Токсичное облако + стойка)
            if casterChar then CharacterAnimator.playGigachadFlex(casterChar, 0.7) end
            spawnTexturedShockwave(pos, 18, Color3.fromRGB(155, 89, 182), 0.6)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(155, 89, 182), 14, 28, 0.2)
            JuiceEffects.play3DSound("splash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🥤 ТОКСИЧНЫЙ ШЕЙК!", Color3.fromRGB(155, 89, 182))

        elseif slot == "tactical" then
            -- Коктейльная Лужа (Липкая фиолетовая жижа)
            spawnGroundCracks(pos, 15, Color3.fromRGB(74, 35, 90), 3.5)
            spawnTexturedShockwave(pos, 15, Color3.fromRGB(142, 68, 173), 0.5)
            JuiceEffects.play3DSound("splash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🟣 КОКТЕЙЛЬНАЯ ЛУЖА!", Color3.fromRGB(142, 68, 173))

        elseif slot == "ultimate" then
            -- Катаклизм Гримаса (Аренный токсичный туман + флекс и зум камеры)
            if casterChar then CharacterAnimator.playGigachadFlex(casterChar, 1.3) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.45, 4.5, -8) end
            spawnAnticipationVortex(pos, Color3.fromRGB(155, 89, 182), 0.3)
            spawnEarthFracture(pos, 16, 8)
            spawnGroundCracks(pos, 18, Color3.fromRGB(60, 20, 80), 3.0)
            spawnTexturedShockwave(pos, 38, Color3.fromRGB(155, 89, 182), 0.85)
            createPillarOfLight(pos, 30, 9, Color3.fromRGB(142, 68, 173), 0.85)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(155, 89, 182), 22, 50, 0.3)
            JuiceEffects.spawnDebrisBlast(pos, 18, Color3.fromRGB(155, 89, 182))
            JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "💜 КАТАКЛИЗМ ГРИМАСА!", Color3.fromRGB(168, 85, 247))
            if isSelf then
                JuiceEffects.traumaShake(0.9)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(155, 89, 182), 0.3)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(142, 68, 173), 0.7)
            end

        elseif slot == "special" then
            -- Grimace Birthday Eclipse (Затмение дня рождения + спин)
            if casterChar then CharacterAnimator.playSpinSalute(casterChar, 0.8) end
            spawnMagicCircle(pos, Color3.fromRGB(74, 35, 90), 0.9)
            createPillarOfLight(pos, 22, 7, Color3.fromRGB(155, 89, 182), 0.6)
            JuiceEffects.play3DSound("magic", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "🎂 GRIMACE BIRTHDAY ECLIPSE!", Color3.fromRGB(168, 85, 247))
            if isSelf then JuiceEffects.screenBloomFlash(Color3.fromRGB(142, 68, 173), 0.35) end

        elseif slot == "mobility" then
            -- Слизистый Прыжок
            spawnVolumetricLaser(pos, pos + lookVector * 26, Color3.fromRGB(155, 89, 182), 1.1, 0.3)
            spawnGroundCracks(pos, 10, Color3.fromRGB(74, 35, 90), 2.0)
            JuiceEffects.play3DSound("dash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🟣 СЛИЗИСТЫЙ ПРЫЖОК!", Color3.fromRGB(155, 89, 182))
            if isSelf then JuiceEffects.fovPulse(15, 0.35) end

        elseif slot == "mobility_land" then
            -- C14 FIX: Персистентная жижа при приземлении (липкая зона)
            local ground = getGroundPosition(pos)
            local slimePart = Instance.new("Part")
            slimePart.Name = "SlimePuddleVFX"
            slimePart.Size = Vector3.new(20, 0.15, 20)
            slimePart.Shape = Enum.PartType.Cylinder
            slimePart.CFrame = CFrame.new(ground + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
            slimePart.Anchored = true
            slimePart.CanCollide = false
            slimePart.Material = Enum.Material.Glass
            slimePart.Color = Color3.fromRGB(74, 35, 90)
            slimePart.Transparency = 0.3
            slimePart.Parent = Workspace
            Debris:AddItem(slimePart, 6)
            spawnEarthFracture(pos, 12, 6)
            spawnTexturedShockwave(pos, 18, Color3.fromRGB(155, 89, 182), 0.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(155, 89, 182), 16, 30, 0.25)
            JuiceEffects.spawnDebrisBlast(pos, 12, Color3.fromRGB(155, 89, 182))
            JuiceEffects.play3DSound("splash", pos, 1.1)
            JuiceEffects.play3DSound("slam", pos, 0.9)
            if isSelf then JuiceEffects.traumaShake(0.55) end

        elseif slot == "godmode" then
            -- Ритуал 23 Июня (Элдрические щупальца бездны + мощный флекс и динамический ракурс)
            if casterChar then CharacterAnimator.playGigachadFlex(casterChar, 1.8) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.5, 5.0, 12) end
            spawnEarthFracture(pos, 18, 10)
            spawnGroundCracks(pos, 20, Color3.fromRGB(50, 10, 70), 3.8)
            createPillarOfLight(pos, 48, 15, Color3.fromRGB(100, 10, 130), 1.2)
            spawnTexturedShockwave(pos, 48, Color3.fromRGB(142, 68, 173), 1.0)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(155, 89, 182), 24, 60, 0.35)
            JuiceEffects.spawnDebrisBlast(pos, 22, Color3.fromRGB(155, 89, 182))
            JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
            JuiceEffects.play3DSound("electric", pos, 1.3)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "💀 РИТУАЛ 23 ИЮНЯ!", Color3.fromRGB(168, 85, 247))
            if isSelf then
                JuiceEffects.traumaShake(1.35)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(142, 68, 173), 0.45)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(74, 35, 90), 0.85)
                JuiceEffects.hitstop(0.07)
            end
            -- C8 FIX: ongoing toxic VFX pulses for godmode duration (3.5s stun cycle)
            for step = 1, 3 do
                task.delay(step * 1.0, function()
                    local center = if caster and caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
                        then caster.Character.HumanoidRootPart.Position
                        else pos
                    spawnTexturedShockwave(center, 30, Color3.fromRGB(142, 68, 173), 0.6)
                    JuiceEffects.spawnLightBurst(center, Color3.fromRGB(155, 89, 182), 18, 30, 0.2)
                    JuiceEffects.play3DSound("electric", center, 0.7)
                end)
            end
        end

    -- 6. CASEOH GRAVITY (Singularity & Colossal Kinetic Mass)
    elseif fId == "CaseOh" then
        if slot == "base" then
            -- CaseOh Slam (Гравитационный слэм + мощный удар о землю двумя руками)
            if casterChar then CharacterAnimator.playGroundPound(casterChar, 0.8) end
            spawnEarthFracture(pos, 14, 7)
            spawnTexturedShockwave(pos, 22, Color3.fromRGB(230, 126, 34), 0.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(230, 126, 34), 16, 35, 0.2)
            JuiceEffects.play3DSound("slam", pos, 1.2)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "💥 CASEOH SLAM!", Color3.fromRGB(230, 126, 34))
            if isSelf then JuiceEffects.traumaShake(0.6) end

        elseif slot == "tactical" then
            -- Горизонт Событий (Черная дыра)
            if casterChar then CharacterAnimator.playGroundPound(casterChar, 0.6) end
            spawnAnticipationVortex(pos, Color3.fromRGB(241, 196, 15), 0.4)
            spawnMagicCircle(pos, Color3.fromRGB(30, 30, 35), 0.8)
            createPillarOfLight(pos, 16, 6, Color3.fromRGB(241, 196, 15), 0.6)
            JuiceEffects.play3DSound("magic", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🕳️ ГОРИЗОНТ СОБЫТИЙ!", Color3.fromRGB(230, 126, 34))

        elseif slot == "ultimate" then
            -- Метеорит КейсОха (Падение метеорита + слэм земли и нижний кинематографический ракурс)
            if casterChar then CharacterAnimator.playGroundPound(casterChar, 1.4) end
            if isSelf and casterChar then CinematicCamera.groundSlamPerspective(casterChar, 0.8) end
            spawnFallingSkyProp(pos, function()
                local met = Instance.new("Part")
                met.Shape = Enum.PartType.Ball
                met.Size = Vector3.new(12, 12, 12)
                met.Material = Enum.Material.Neon
                met.Color = Color3.fromRGB(230, 126, 34)
                return met
            end, function()
                createPillarOfLight(pos, 35, 12, Color3.fromRGB(230, 126, 34), 0.8)
                spawnTexturedShockwave(pos, 42, Color3.fromRGB(230, 126, 34), 0.8)
                JuiceEffects.spawnDebrisBlast(pos, 22, Color3.fromRGB(230, 126, 34))
                JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 6, 0), "☄️ МЕТЕОРИТ КЕЙСОХА!", Color3.fromRGB(230, 126, 34))
                if isSelf then
                    JuiceEffects.traumaShake(1.25)
                    JuiceEffects.screenBloomFlash(Color3.fromRGB(230, 126, 34), 0.35)
                    JuiceEffects.cinematicVignettePulse(Color3.fromRGB(230, 126, 34), 0.75)
                end
            end, 60)

        elseif slot == "special" then
            -- BAN HAMMER METEOR (Падение банхаммера + замах молота и наезд камеры)
            if casterChar then CharacterAnimator.playHammerSwing(casterChar, 1.1) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.4, 5.2, -10) end
            spawnFallingSkyProp(pos + lookVector * 12, function()
                local hammer = Instance.new("Part")
                hammer.Size = Vector3.new(8, 5, 12)
                hammer.Material = Enum.Material.Neon
                hammer.Color = Color3.fromRGB(231, 76, 60)
                return hammer
            end, function()
                createPillarOfLight(pos + lookVector * 12, 30, 10, Color3.fromRGB(231, 76, 60), 0.8)
                spawnTexturedShockwave(pos + lookVector * 12, 35, Color3.fromRGB(231, 76, 60), 0.7)
                JuiceEffects.spawnDebrisBlast(pos + lookVector * 12, 16, Color3.fromRGB(231, 76, 60))
                JuiceEffects.playEpicImpact(pos + lookVector * 12, "special", isSelf)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 6, 0), "🔨 YOU ARE BANNED!", Color3.fromRGB(231, 76, 60))
                if isSelf then
                    JuiceEffects.traumaShake(1.1)
                    JuiceEffects.hitstop(0.06)
                end
            end, 55)

        elseif slot == "mobility" or slot == "mobility_start" then
            -- Вафельный Каток
            spawnVolumetricLaser(pos, pos + lookVector * 32, Color3.fromRGB(230, 126, 34), 1.4, 0.35)
            spawnEarthFracture(pos, 10, 5)
            JuiceEffects.play3DSound("dash", pos, 1.0)
            JuiceEffects.play3DSound("slam", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🍩 ВАФЕЛЬНЫЙ КАТОК!", Color3.fromRGB(230, 126, 34))
            if isSelf then
                JuiceEffects.fovPulse(16, 0.4)
                JuiceEffects.traumaShake(0.5)
            end

        elseif slot == "mobility_land" then
            -- C10 FIX: VFX приземления Вафельного Катка
            if casterChar then CharacterAnimator.playGroundPound(casterChar, 0.7) end
            spawnEarthFracture(pos, 16, 8)
            spawnTexturedShockwave(pos, 26, Color3.fromRGB(230, 126, 34), 0.55)
            spawnGroundCracks(pos, 20, Color3.fromRGB(40, 45, 50), 2.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(230, 126, 34), 20, 40, 0.25)
            JuiceEffects.spawnDebrisBlast(pos, 14, Color3.fromRGB(230, 126, 34))
            JuiceEffects.play3DSound("slam", pos, 1.3)
            if isSelf then JuiceEffects.traumaShake(0.6) end

        elseif slot == "godmode" then
            -- Смещение Земной Оси (Планетарное сотрясение + сокрушительный слэм и перспектива земли)
            if casterChar then CharacterAnimator.playGroundPound(casterChar, 1.8) end
            if isSelf and casterChar then CinematicCamera.groundSlamPerspective(casterChar, 0.85) end
            spawnEarthFracture(pos, 22, 10)
            spawnGroundCracks(pos, 24, Color3.fromRGB(40, 45, 50), 3.8)
            spawnTexturedShockwave(pos, 55, Color3.fromRGB(230, 126, 34), 1.1)
            createPillarOfLight(pos, 55, 18, Color3.fromRGB(241, 196, 15), 1.3)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(241, 196, 15), 26, 70, 0.4)
            JuiceEffects.spawnDebrisBlast(pos, 26, Color3.fromRGB(230, 126, 34))
            JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "🌍 СМЕЩЕНИЕ ЗЕМНОЙ ОСИ!", Color3.fromRGB(241, 196, 15))
            if isSelf then
                JuiceEffects.traumaShake(1.4)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(230, 126, 34), 0.45)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(241, 196, 15), 0.85)
                JuiceEffects.hitstop(0.08)
            end
        end

    -- 7. RIZZLER & GRONK (Hypnotic Romance / Magenta & Roses)
    elseif fId == "Rizzler" then
        if slot == "base" then
            -- Unspoken Rizz (Розовый всплеск очарования + романтический жест)
            if casterChar then CharacterAnimator.playRizzlerFlourish(casterChar, 0.8) end
            spawnTexturedShockwave(pos, 18, Color3.fromRGB(255, 105, 180), 0.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(255, 105, 180), 14, 28, 0.2)
            JuiceEffects.play3DSound("chime", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "❤️ UNSPOKEN RIZZ!", Color3.fromRGB(255, 105, 180))

        elseif slot == "tactical" then
            -- Ризз Гипноз (Концентрические кольца любви + флуриш)
            if casterChar then CharacterAnimator.playRizzlerFlourish(casterChar, 0.9) end
            spawnMagicCircle(pos, Color3.fromRGB(255, 20, 147), 0.8)
            createPillarOfLight(pos, 10, 4, Color3.fromRGB(255, 105, 180), 0.5)
            JuiceEffects.play3DSound("magic", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🌀 РИЗЗ ГИПНОЗ!", Color3.fromRGB(255, 105, 180))

        elseif slot == "ultimate" then
            -- Взрыв Сверхризза (Ослепительная розовая вспышка + жест и кинематографический наезд)
            if casterChar then CharacterAnimator.playRizzlerFlourish(casterChar, 1.3) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.45, 4.2, 14) end
            spawnAnticipationVortex(pos, Color3.fromRGB(255, 105, 180), 0.25)
            spawnTexturedShockwave(pos, 36, Color3.fromRGB(255, 20, 147), 0.75)
            createPillarOfLight(pos, 26, 8, Color3.fromRGB(255, 105, 180), 0.8)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(255, 20, 147), 20, 45, 0.25)
            JuiceEffects.spawnDebrisBlast(pos, 18, Color3.fromRGB(255, 20, 147))
            JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
            JuiceEffects.play3DSound("chime", pos, 1.3)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "💖 ВЗРЫВ СВЕРХРИЗЗА!", Color3.fromRGB(255, 105, 180))
            if isSelf then
                JuiceEffects.traumaShake(0.8)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(255, 105, 180), 0.3)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(255, 105, 180), 0.7)
            end

        elseif slot == "special" then
            -- Cupid's Brainrot Arrow (Стрела Купидона + жест)
            if casterChar then CharacterAnimator.playRizzlerFlourish(casterChar, 0.9) end
            spawnVolumetricLaser(pos + Vector3.new(0, 2, 0), pos + lookVector * 34 + Vector3.new(0, 2, 0), Color3.fromRGB(255, 20, 147), 0.8, 0.35)
            JuiceEffects.play3DSound("laser", pos, 1.0)
            JuiceEffects.play3DSound("chime", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "💘 СТРЕЛА КУПИДОНА!", Color3.fromRGB(255, 105, 180))

        elseif slot == "mobility" then
            -- Лепестковый Блинк (Вихрь роз)
            spawnVolumetricLaser(pos, pos + lookVector * 28, Color3.fromRGB(255, 105, 180), 1.0, 0.25)
            spawnTexturedShockwave(pos, 12, Color3.fromRGB(255, 20, 147), 0.3)
            JuiceEffects.play3DSound("dash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🌹 ЛЕПЕСТКОВЫЙ БЛИНК!", Color3.fromRGB(255, 105, 180))
            if isSelf then JuiceEffects.fovPulse(15, 0.35) end

        elseif slot == "godmode" then
            -- Аура Гипер-Ризза 999+ (Культовый флуриш и динамический ракурс)
            if casterChar then CharacterAnimator.playRizzlerFlourish(casterChar, 1.6) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.5, 4.5, -12) end
            spawnMagicCircle(pos, Color3.fromRGB(255, 20, 147), 1.2)
            spawnTexturedShockwave(pos, 45, Color3.fromRGB(255, 105, 180), 0.9)
            createPillarOfLight(pos, 42, 14, Color3.fromRGB(255, 20, 147), 1.1)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(255, 105, 180), 24, 60, 0.35)
            JuiceEffects.spawnDebrisBlast(pos, 24, Color3.fromRGB(255, 20, 147))
            JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
            JuiceEffects.play3DSound("chime", pos, 1.5)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "💋 АУРА ГИПЕР-РИЗЗА 999+!", Color3.fromRGB(255, 20, 147))
            if isSelf then
                JuiceEffects.traumaShake(1.15)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(255, 105, 180), 0.4)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(255, 20, 147), 0.85)
            end
        end

    -- 8. TUNG TUNG SAHUR (Blacksmith Volcano / Molten Steel & Sparks)
    elseif fId == "TungTung" then
        if slot == "base" then
            -- Tung Tung Hammer (Сокрушительный удар молотом + процедурный взмах)
            if casterChar then CharacterAnimator.playHammerSwing(casterChar, 0.8) end
            spawnEarthFracture(pos, 12, 6)
            spawnTexturedShockwave(pos, 20, Color3.fromRGB(46, 204, 113), 0.45)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(46, 204, 113), 15, 30, 0.2)
            JuiceEffects.play3DSound("hammer", pos, 1.2)
            JuiceEffects.play3DSound("slam", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🔨 МОЛОТ ТУНГ-ТУНГ!", Color3.fromRGB(46, 204, 113))
            if isSelf then JuiceEffects.traumaShake(0.55) end

        elseif slot == "tactical" then
            -- Наковальня Сахура (Сброс вольфрамовой наковальни + нижний ракурс)
            if casterChar then CharacterAnimator.playHammerSwing(casterChar, 0.9) end
            if isSelf and casterChar then CinematicCamera.groundSlamPerspective(casterChar, 0.5) end
            spawnFallingSkyProp(pos + lookVector * 10, function()
                local anvil = Instance.new("Part")
                anvil.Size = Vector3.new(4, 3, 6)
                anvil.Material = Enum.Material.DiamondPlate
                anvil.Color = Color3.fromRGB(80, 80, 90)
                return anvil
            end, function()
                spawnTexturedShockwave(pos + lookVector * 10, 25, Color3.fromRGB(46, 204, 113), 0.6)
                JuiceEffects.spawnLightBurst(pos + lookVector * 10, Color3.fromRGB(46, 204, 113), 18, 35, 0.25)
                JuiceEffects.play3DSound("anvil", pos, 1.4)
                JuiceEffects.play3DSound("slam", pos, 1.1)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🔔 ВОЛЬФРАМОВАЯ НАКОВАЛЬНЯ!", Color3.fromRGB(46, 204, 113))
                if isSelf then JuiceEffects.traumaShake(0.7) end
            end, 50)

        elseif slot == "ultimate" then
            -- Итальянский Торнадо (Вихрь рассекающих молотов + анимация и кинематографический наезд)
            if casterChar then CharacterAnimator.playHammerSwing(casterChar, 1.3) end
            if isSelf and casterChar then CinematicCamera.focusCutIn(casterChar, 0.45, 4.6, -10) end
            spawnAnticipationVortex(pos, Color3.fromRGB(46, 204, 113), 0.25)
            spawnMagicCircle(pos, Color3.fromRGB(39, 174, 96), 0.8)
            spawnTexturedShockwave(pos, 38, Color3.fromRGB(46, 204, 113), 0.7)
            spawnEarthFracture(pos, 15, 8)
            spawnGroundCracks(pos, 16, Color3.fromRGB(30, 80, 40), 2.8)
            createPillarOfLight(pos, 28, 8, Color3.fromRGB(46, 204, 113), 0.8)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(46, 204, 113), 22, 50, 0.3)
            JuiceEffects.spawnDebrisBlast(pos, 18, Color3.fromRGB(46, 204, 113))
            JuiceEffects.playEpicImpact(pos, "ultimate", isSelf)
            JuiceEffects.play3DSound("electric", pos, 1.1)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🌪️ ИТАЛЬЯНСКИЙ ТОРНАДО!", Color3.fromRGB(46, 204, 113))
            if isSelf then
                JuiceEffects.traumaShake(0.85)
                JuiceEffects.screenBloomFlash(Color3.fromRGB(46, 204, 113), 0.3)
                JuiceEffects.cinematicVignettePulse(Color3.fromRGB(46, 204, 113), 0.7)
                JuiceEffects.hitstop(0.07)
            end

        elseif slot == "special" then
            -- Базука Сахура (Выстрел тяжелым снарядом молота)
            if casterChar then CharacterAnimator.playHammerSwing(casterChar, 0.8) end
            spawnVolumetricLaser(pos + Vector3.new(0, 2, 0), pos + lookVector * 36 + Vector3.new(0, 2, 0), Color3.fromRGB(46, 204, 113), 1.2, 0.35)
            spawnEarthFracture(pos + lookVector * 36, 10, 5)
            spawnTexturedShockwave(pos + lookVector * 36, 18, Color3.fromRGB(46, 204, 113), 0.4)
            JuiceEffects.spawnLightBurst(pos + lookVector * 36, Color3.fromRGB(46, 204, 113), 18, 35, 0.25)
            JuiceEffects.play3DSound("explosion", pos, 1.2)
            JuiceEffects.play3DSound("hammer", pos, 1.1)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "💥 БАЗУКА САХУРА!", Color3.fromRGB(46, 204, 113))
            if isSelf then
                JuiceEffects.traumaShake(0.65)
                JuiceEffects.cameraKick(-lookVector, 0.6)
            end

        elseif slot == "mobility" then
            -- Молот-Джамп
            spawnVolumetricLaser(pos, pos + lookVector * 26, Color3.fromRGB(46, 204, 113), 1.2, 0.3)
            spawnTexturedShockwave(pos, 14, Color3.fromRGB(46, 204, 113), 0.35)
            JuiceEffects.play3DSound("dash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "⚡ МОЛОТ-ДЖАМП!", Color3.fromRGB(46, 204, 113))
            if isSelf then
                JuiceEffects.fovPulse(15, 0.35)
                JuiceEffects.cameraKick(Vector3.new(0, 1, 0), 0.5)
            end

        elseif slot == "mobility_land" then
            -- C10 FIX: VFX приземления Молот-Джамп
            if casterChar then CharacterAnimator.playHammerSwing(casterChar, 0.7) end
            spawnEarthFracture(pos, 16, 8)
            spawnTexturedShockwave(pos, 24, Color3.fromRGB(46, 204, 113), 0.5)
            spawnGroundCracks(pos, 18, Color3.fromRGB(30, 80, 40), 2.5)
            JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(46, 204, 113), 20, 40, 0.25)
            JuiceEffects.spawnDebrisBlast(pos, 14, Color3.fromRGB(46, 204, 113))
            JuiceEffects.play3DSound("slam", pos, 1.3)
            JuiceEffects.play3DSound("hammer", pos, 1.1)
            if isSelf then JuiceEffects.traumaShake(0.7) end

        elseif slot == "godmode" then
            -- Ярость Вулкана Этна (Падение раскаленного молота вулкана + кинематографическая камера)
            if casterChar then CharacterAnimator.playHammerSwing(casterChar, 1.6) end
            if isSelf and casterChar then CinematicCamera.groundSlamPerspective(casterChar, 0.8) end
            spawnFallingSkyProp(pos, function()
                local godHammer = Instance.new("Part")
                godHammer.Size = Vector3.new(10, 6, 6)
                godHammer.Material = Enum.Material.Neon
                godHammer.Color = Color3.fromRGB(230, 126, 34)
                return godHammer
            end, function()
                spawnEarthFracture(pos, 20, 10)
                spawnGroundCracks(pos, 22, Color3.fromRGB(192, 57, 43), 3.5)
                createPillarOfLight(pos, 50, 18, Color3.fromRGB(230, 126, 34), 1.3)
                spawnTexturedShockwave(pos, 50, Color3.fromRGB(192, 57, 43), 1.1)
                JuiceEffects.spawnLightBurst(pos, Color3.fromRGB(230, 126, 34), 26, 65, 0.35)
                JuiceEffects.spawnDebrisBlast(pos, 26, Color3.fromRGB(230, 126, 34))
                JuiceEffects.playEpicImpact(pos, "godmode", isSelf)
                JuiceEffects.play3DSound("electric", pos, 1.3)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "🌋 ЯРОСТЬ ВУЛКАНА ЭТНА!", Color3.fromRGB(230, 126, 34))
                if isSelf then
                    JuiceEffects.traumaShake(1.35)
                    JuiceEffects.screenBloomFlash(Color3.fromRGB(230, 126, 34), 0.45)
                    JuiceEffects.cinematicVignettePulse(Color3.fromRGB(192, 57, 43), 0.85)
                    JuiceEffects.hitstop(0.07)
                end
            end, 55, true)
            -- C8 FIX: ongoing molten quake VFX for 10s
            for step = 1, 9 do
                task.delay(step * 1.0, function()
                    local center = if caster and caster.Character and caster.Character:FindFirstChild("HumanoidRootPart")
                        then caster.Character.HumanoidRootPart.Position
                        else pos
                    spawnEarthFracture(center, 14, 7)
                    spawnTexturedShockwave(center, 22, Color3.fromRGB(192, 57, 43), 0.5)
                    JuiceEffects.spawnLightBurst(center, Color3.fromRGB(230, 126, 34), 18, 30, 0.2)
                    JuiceEffects.play3DSound("hammer", center, 0.7)
                end)
            end
        end
    end
end

return AbilityVFX
