--!strict

--[=[
    JuiceEffects
    Модуль сочности и тактильного отклика: звуки, всплывающие числа (+$$$),
    анимация кнопок (Squash & Stretch), тряска при ошибке и вспышки экрана.
]=]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local JuiceEffects = {}

function JuiceEffects.isMobile(): boolean
    return isMobileDevice
end

-- Каталог надежных Roblox аудио-идентификаторов (встроенные rbxasset и официальные rbxassetid)
local SOUND_IDS: { [string]: string } = {
    cash = "rbxassetid://6895079853",                  -- Звон кассы (Cha-ching! Официальный Roblox)
    buy = "rbxasset://sounds/button.mp3",               -- Щелчок успешной покупки
    error = "rbxasset://sounds/uuhhh.mp3",              -- Звук ошибки / недостатка денег
    siren = "rbxassetid://2865227271",                 -- Сирена AirDrop (Официальный Roblox)
    fanfare = "rbxasset://sounds/victory.mp3",          -- Торжественная фанфара Rebirth
    powerup = "rbxasset://sounds/electronicpingshort.wav", -- Активация способности
    slam = "rbxasset://sounds/bass.mp3",                -- Удар / землетрясение
    laser = "rbxassetid://130976108",                  -- Лазерный луч
    dash = "rbxasset://sounds/swordlunge.wav",          -- Свистящий рывок
    explosion = "rbxassetid://12222084",               -- Мощный взрыв
    electric = "rbxasset://sounds/electronicpingshort.wav", -- Электрический разряд
    magic = "rbxassetid://131070686",                  -- Магическое сияние
    teleport = "rbxassetid://131070686",               -- Теневой телепорт
    meteor = "rbxasset://sounds/collide.mp3",           -- Падение метеорита
    hammer = "rbxasset://sounds/bass.mp3",              -- Удар банхаммера
    splash = "rbxasset://sounds/splat.mp3",             -- Всплеск / смыв
    whoosh = "rbxasset://sounds/swordlunge.wav",        -- Быстрый свист
    chime = "rbxasset://sounds/bell.mp3",               -- Ризз-колокольчик
    horn = "rbxasset://sounds/victory.mp3",             -- Мемный горн / фанфара
    parry = "rbxasset://sounds/swordhit.wav",           -- Парирование / металлический лязг
    snatch = "rbxasset://sounds/snap.mp3",              -- Налог / звон монет
    anvil = "rbxasset://sounds/metal.mp3",              -- Звон наковальни
}

function JuiceEffects.playSound(soundName: string, volume: number?)
    local assetId = SOUND_IDS[soundName] or SOUND_IDS.powerup
    if not assetId then return end

    local sound = Instance.new("Sound")
    sound.SoundId = assetId
    sound.Volume = volume or 0.85
    sound.PlaybackSpeed = math.random(94, 106) / 100
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 4)
end

-- Пространственный 3D-звук в заданной точке мира (слышен всем в радиусе)
function JuiceEffects.play3DSound(soundName: string, position: Vector3, volume: number?, maxDist: number?)
    local assetId = SOUND_IDS[soundName] or SOUND_IDS.powerup
    if not assetId then return end

    local char = localPlayer.Character
    local root: BasePart? = if char then char:FindFirstChild("HumanoidRootPart") else nil
    local dist = if root then (root.Position - position).Magnitude else 999

    -- P1-04: Если кастер или игрок рядом (до 30 стадов) — проигрываем только 2D-звук (не дублируем 3D)
    if dist <= 30 then
        JuiceEffects.playSound(soundName, volume)
        return
    end

    -- Позиционный 3D-звук для пространственной локализации в мире
    local soundPart = Instance.new("Part")
    soundPart.Name = "SoundSource"
    soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
    soundPart.Position = position
    soundPart.Transparency = 1
    soundPart.CanCollide = false
    soundPart.Anchored = true
    soundPart.Parent = Workspace

    local sound = Instance.new("Sound")
    sound.SoundId = assetId
    sound.Volume = volume or 0.85
    sound.PlaybackSpeed = math.random(94, 106) / 100
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 10
    sound.RollOffMaxDistance = maxDist or 120
    sound.Parent = soundPart
    sound:Play()

    Debris:AddItem(soundPart, 5)
end

-- P1-05: Защита от наложения трясок
local activeShakeThread: thread? = nil
local currentTrauma: number = 0

-- Добавление травмы для упругой физической тряски экрана (Trauma-based Shake)
function JuiceEffects.addTrauma(amount: number)
    currentTrauma = math.clamp(currentTrauma + amount, 0, 1)
end

-- Кинематический толчок камеры в заданном направлении (Directional Camera Kick)
function JuiceEffects.cameraKick(direction: Vector3, strength: number?)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local kickStr = strength or 0.5
    local dirNorm = if direction.Magnitude > 0 then direction.Unit else Vector3.new(0, 1, 0)
    local kickAngleX = -dirNorm.Y * kickStr * 1.5
    local kickAngleY = dirNorm.X * kickStr * 1.5

    camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(kickAngleX), math.rad(kickAngleY), 0)
end

-- Trauma-based Screen Shake по шуму Перлина с квадратичным затуханием (Trauma^2)
function JuiceEffects.traumaShake(trauma: number, maxRot: number?, maxPos: number?)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    JuiceEffects.addTrauma(trauma)

    if activeShakeThread then
        task.cancel(activeShakeThread)
        activeShakeThread = nil
    end

    local rotLimit = maxRot or 4.5
    local posLimit = maxPos or 0.6
    local seed = math.random(1, 10000)

    activeShakeThread = task.spawn(function()
        while currentTrauma > 0.01 do
            local shakeIntensity = currentTrauma * currentTrauma -- Квадратичный закон затухания
            local t = tick() * 32

            -- P1 Fix: math.noise в Roblox возвращает [-0.5, 0.5], поэтому центрируем без вычитания 0.5
            local rx = math.noise(t, 0, seed) * 2 * rotLimit * shakeIntensity
            local ry = math.noise(0, t, seed) * 2 * rotLimit * shakeIntensity
            local rz = math.noise(seed, t, 0) * rotLimit * shakeIntensity

            local px = math.noise(t + 50, 0, seed) * 2 * posLimit * shakeIntensity
            local py = math.noise(0, t + 50, seed) * 2 * posLimit * shakeIntensity

            camera.CFrame = camera.CFrame * CFrame.new(px, py, 0) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))

            -- Экспоненциальное затухание травмы
            currentTrauma = math.clamp(currentTrauma - 0.045, 0, 1)
            task.wait(0.016)
        end
        currentTrauma = 0
        activeShakeThread = nil
    end)
end

-- Обратно совместимая динамическая тряска камеры
function JuiceEffects.screenShake(intensity: number?, duration: number?)
    if activeShakeThread then
        task.cancel(activeShakeThread)
        activeShakeThread = nil
    end
    local str = intensity or 0.7
    JuiceEffects.traumaShake(math.clamp(str * 0.8, 0.2, 1.0))
end

-- P0 Fix: Счетчик активных хитстопов и кэш оригинальной скорости (защита от зануления скорости при комбо)
local activeHitstopCount: number = 0
local cachedOriginalWalkSpeed: number = 16

-- Хитстоп (Hitstop / Micro-Freeze) для колоссального ощущения веса удара
-- D4 FIX: минимум 0.07с = 4+ кадра при 60fps (1.5 кадра было недостаточно на Mobile)
function JuiceEffects.hitstop(duration: number?)
    local dur = math.max(duration or 0.07, 0.07)
    local char = localPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if activeHitstopCount == 0 then
        if humanoid.WalkSpeed > 0 then
            cachedOriginalWalkSpeed = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = 0
    end
    activeHitstopCount += 1

    task.delay(dur, function()
        activeHitstopCount = math.max(0, activeHitstopCount - 1)
        if activeHitstopCount == 0 and humanoid and humanoid.Parent then
            humanoid.WalkSpeed = cachedOriginalWalkSpeed
        end
    end)
end

-- Target Impact Flash (кратковременный белый силуэт цели при получении урона)
-- D3 FIX: 0.08с → 0.15с (был невидим на Mobile: ~2.4 кадра → теперь минимум 4.5 кадра)
function JuiceEffects.impactFlash(targetChar: Model, color: Color3?, duration: number?)
    if not targetChar or not targetChar:IsA("Model") then return end
    local dur = duration or 0.15
    local flashColor = color or Color3.fromRGB(255, 255, 255)

    local existingHighlight = targetChar:FindFirstChild("ImpactFlashHighlight")
    if existingHighlight then
        existingHighlight:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ImpactFlashHighlight"
    highlight.FillColor = flashColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.2
    highlight.OutlineTransparency = 0.1
    highlight.Parent = targetChar

    local tween = TweenService:Create(highlight, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FillTransparency = 1,
        OutlineTransparency = 1,
    })
    tween:Play()
    Debris:AddItem(highlight, dur + 0.02)
end

-- Динамический импульсный свет (PointLight Impact Burst) для мгновенных объемных теней
-- D8 FIX: LOD check + min 0.25с на дальних дистанциях
function JuiceEffects.spawnLightBurst(pos: Vector3, color: Color3, brightness: number?, radius: number?, duration: number?)
    -- LOD: пропуск далёких вспышек за 120 studs
    local cam = Workspace.CurrentCamera
    if cam and (cam.CFrame.Position - pos).Magnitude > 120 then return end

    local baseDur = duration or 0.22
    -- На дальних дистанциях (>50 studs) увеличиваем длительность для видимости
    if cam and (cam.CFrame.Position - pos).Magnitude > 50 then
        baseDur = math.max(baseDur, 0.3)
    end
    local dur = math.max(baseDur, 0.25)
    local b = brightness or 16
    local r = if isMobileDevice then math.min(radius or 40, 24) else (radius or 40)

    local lightPart = Instance.new("Part")
    lightPart.Name = "ImpactLightBurst"
    lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
    lightPart.CFrame = CFrame.new(pos)
    lightPart.Transparency = 1
    lightPart.CanCollide = false
    lightPart.Anchored = true
    lightPart.Parent = Workspace

    local pointLight = Instance.new("PointLight")
    pointLight.Color = color
    pointLight.Brightness = b
    pointLight.Range = r
    pointLight.Shadows = not isMobileDevice -- На мобильных GPU динамические тени отключаются для стабильных 60 FPS
    pointLight.Parent = lightPart

    local tween = TweenService:Create(pointLight, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Brightness = 0,
        Range = r * 1.3,
    })
    tween:Play()
    Debris:AddItem(lightPart, dur + 0.05)
end

-- Пост-процессинг вспышка Bloom / ColorCorrection
-- D6 FIX: default 0.18с → 0.25с; для godmode-способностей вызывать с 0.35с явно
function JuiceEffects.screenBloomFlash(color: Color3?, duration: number?)
    local dur = duration or 0.25
    local bloom = Lighting:FindFirstChild("CombatBloomPulse") :: BloomEffect?
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "CombatBloomPulse"
        bloom.Intensity = 0
        bloom.Size = 24
        bloom.Threshold = 0.8
        bloom.Parent = Lighting
    end

    bloom.Intensity = 2.4
    local tweenBloom = TweenService:Create(bloom, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Intensity = 0,
    })
    tweenBloom:Play()

    -- P2 Fix: Полноценное задействование параметра color через ColorCorrectionEffect
    if color then
        local cc = Lighting:FindFirstChild("CombatColorPulse") :: ColorCorrectionEffect?
        if not cc then
            cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "CombatColorPulse"
            cc.TintColor = Color3.new(1, 1, 1)
            cc.Parent = Lighting
        end
        cc.TintColor = color
        local tweenCC = TweenService:Create(cc, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TintColor = Color3.new(1, 1, 1),
        })
        tweenCC:Play()
    end
end

local activeFovTweenUp: Tween? = nil
local activeFovTweenDown: Tween? = nil
local defaultCameraFOV: number = 70

-- Импульс угла обзора (FOV Kick) при рывках мобильности (защита от FOV Drift)
function JuiceEffects.fovPulse(fovKick: number?, duration: number?)
    local camera = Workspace.CurrentCamera
    if not camera then return end

    -- Если твин не активен, фиксируем текущий честный FOV игрока
    if not activeFovTweenUp and not activeFovTweenDown then
        defaultCameraFOV = camera.FieldOfView
    end

    if activeFovTweenUp then
        activeFovTweenUp:Cancel()
        activeFovTweenUp = nil
    end
    if activeFovTweenDown then
        activeFovTweenDown:Cancel()
        activeFovTweenDown = nil
    end

    local kick = fovKick or 12
    local dur = duration or 0.4
    local targetPeakFOV = math.min(105, defaultCameraFOV + kick)

    local tUp = TweenService:Create(camera, TweenInfo.new(dur * 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        FieldOfView = targetPeakFOV,
    })
    local tDown = TweenService:Create(camera, TweenInfo.new(dur * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = defaultCameraFOV,
    })

    activeFovTweenUp = tUp
    activeFovTweenDown = tDown

    tUp:Play()
    tUp.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed then
            activeFovTweenUp = nil
            tDown:Play()
        end
    end)

    tDown.Completed:Connect(function(playbackState)
        if playbackState == Enum.PlaybackState.Completed then
            activeFovTweenDown = nil
            camera.FieldOfView = defaultCameraFOV
        end
    end)
end

-- Всплывающий 3D-текст (+$$$ / урон / лут) в мировом пространстве
function JuiceEffects.showFloatingText(worldPos: Vector3, text: string, color: Color3, duration: number?)
    local dur = duration or 1.2

    local part = Instance.new("Part")
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.CFrame = CFrame.new(worldPos)
    part.Transparency = 1
    part.CanCollide = false
    part.Anchored = true
    part.Parent = Workspace

    local bGui = Instance.new("BillboardGui")
    bGui.Size = UDim2.new(0, 180, 0, 50)
    bGui.StudsOffset = Vector3.new(0, 1.5, 0)
    bGui.AlwaysOnTop = true
    bGui.MaxDistance = 90
    bGui.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.1
    label.TextScaled = true
    label.Font = Enum.Font.FredokaOne
    label.Parent = bGui

    -- Анимация взлета вверх и растворения
    local tweenPos = TweenService:Create(bGui, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = Vector3.new(0, 5.5, 0),
    })
    local tweenFade = TweenService:Create(label, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })

    tweenPos:Play()
    tweenFade:Play()

    task.delay(dur, function()
        part:Destroy()
    end)
end

-- Анимация успешного нажатия кнопки (Squash & Stretch)
function JuiceEffects.animateButtonSuccess(buttonPart: BasePart)
    JuiceEffects.playSound("buy", 0.8)

    local origSize = buttonPart.Size
    local origCF = buttonPart.CFrame

    -- Сжатие вниз
    local squashSize = Vector3.new(origSize.X * 1.08, 0.12, origSize.Z * 1.08)
    local squashCF = origCF * CFrame.new(0, -0.15, 0)

    local tweenDown = TweenService:Create(buttonPart, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = squashSize,
        CFrame = squashCF,
    })

    local tweenUp = TweenService:Create(buttonPart, TweenInfo.new(0.2, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
        Size = origSize,
        CFrame = origCF,
    })

    tweenDown:Play()
    tweenDown.Completed:Connect(function()
        tweenUp:Play()
    end)

    -- Всплывающий текст "КУПЛЕНО!"
    JuiceEffects.showFloatingText(buttonPart.Position + Vector3.new(0, 2, 0), "✅ КУПЛЕНО!", Color3.fromRGB(46, 204, 113), 0.9)
end

-- Анимация отказа (тряска кнопки при нехватке денег)
function JuiceEffects.animateButtonFailure(buttonPart: BasePart, neededCash: number)
    JuiceEffects.playSound("error", 0.6)

    local origCF = buttonPart.CFrame
    local origColor = buttonPart.Color

    -- Красная вспышка
    buttonPart.Color = Color3.fromRGB(231, 76, 60)

    -- Быстрая тряска влево-вправо
    task.spawn(function()
        for _ = 1, 3 do
            buttonPart.CFrame = origCF * CFrame.new(0.4, 0, 0)
            task.wait(0.04)
            buttonPart.CFrame = origCF * CFrame.new(-0.4, 0, 0)
            task.wait(0.04)
        end
        buttonPart.CFrame = origCF
        task.wait(0.2)
        buttonPart.Color = origColor
    end)

    JuiceEffects.showFloatingText(buttonPart.Position + Vector3.new(0, 2.5, 0), string.format("❌ Нужно %d Aura!", neededCash), Color3.fromRGB(255, 80, 80), 1.2)
end

-- Вспышка экрана при PvP-луте или Rebirth
function JuiceEffects.screenFlash(color: Color3, duration: number?)
    local dur = duration or 0.4
    local hud = playerGui:FindFirstChild("BrainrotHUD") :: ScreenGui?
    if not hud then return end

    local flashFrame = Instance.new("Frame")
    flashFrame.Name = "ScreenFlash"
    flashFrame.Size = UDim2.new(1, 0, 1, 0)
    flashFrame.Position = UDim2.new(0, 0, 0, 0)
    flashFrame.BackgroundColor3 = color
    flashFrame.BackgroundTransparency = 0.4
    flashFrame.BorderSizePixel = 0
    flashFrame.ZIndex = 100
    flashFrame.Parent = hud

    local tween = TweenService:Create(flashFrame, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 1,
    })
    tween:Play()
    Debris:AddItem(flashFrame, dur + 0.05) -- Гарантированная очистка даже при прерывании твина
    tween.Completed:Connect(function()
        if flashFrame and flashFrame.Parent then
            flashFrame:Destroy()
        end
    end)
end

-- Процедурный праздничный салют конфетти (Rebirth & Win Celebration из roblox-juice-kit)
function JuiceEffects.spawnConfetti(position: Vector3)
    local emitterPart = Instance.new("Part")
    emitterPart.Name = "ConfettiBurst"
    emitterPart.Size = Vector3.new(1, 1, 1)
    emitterPart.Position = position
    emitterPart.Transparency = 1
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Parent = Workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = emitterPart

    local colors = {
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(80, 255, 80),
        Color3.fromRGB(80, 150, 255),
        Color3.fromRGB(255, 230, 80),
        Color3.fromRGB(255, 80, 255),
        Color3.fromRGB(241, 196, 15),
    }

    local countPerColor = if isMobileDevice then 12 else 25
    for _, color in ipairs(colors) do
        local particles = Instance.new("ParticleEmitter")
        particles.Color = ColorSequence.new(color)
        particles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 0.2),
        })
        particles.Speed = NumberRange.new(20, 38)
        particles.SpreadAngle = Vector2.new(50, 50)
        particles.Lifetime = NumberRange.new(1.5, 2.5)
        particles.Rate = 0
        particles.Parent = attachment
        particles:Emit(countPerColor)
    end

    Debris:AddItem(emitterPart, 3.5)
end

return JuiceEffects
