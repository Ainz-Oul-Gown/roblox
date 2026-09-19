--!strict

--[=[
    JuiceEffects
    Модуль сочности и тактильного отклика: звуки, всплывающие числа (+$$$),
    анимация кнопок (Squash & Stretch), тряска при ошибке и вспышки экрана.
]=]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

local JuiceEffects = {}

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
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 4)
end

-- Пространственный 3D-звук в заданной точке мира (слышен всем в радиусе)
function JuiceEffects.play3DSound(soundName: string, position: Vector3, volume: number?, maxDist: number?)
    local assetId = SOUND_IDS[soundName] or SOUND_IDS.powerup
    if not assetId then return end

    local char = localPlayer.Character
    local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    local dist = if root then (root.Position - position).Magnitude else 999

    -- Если кастер или игрок рядом (до 30 стадов) — проигрываем чистый 2D-звук напрямую
    if dist <= 30 then
        JuiceEffects.playSound(soundName, volume)
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
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 10
    sound.RollOffMaxDistance = maxDist or 120
    sound.Parent = soundPart
    sound:Play()

    Debris:AddItem(soundPart, 5)
end

-- Динамическая тряска камеры (Screen Shake) при мощных ударах
function JuiceEffects.screenShake(intensity: number?, duration: number?)
    local dur = duration or 0.45
    local str = intensity or 0.7
    local camera = Workspace.CurrentCamera
    if not camera then return end

    local startTime = tick()
    task.spawn(function()
        while tick() - startTime < dur do
            local elapsed = tick() - startTime
            local decay = 1 - (elapsed / dur)
            local rx = (math.random() - 0.5) * 2 * str * decay
            local ry = (math.random() - 0.5) * 2 * str * decay
            local rz = (math.random() - 0.5) * 2 * str * decay * 0.5

            camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
            task.wait(0.02)
        end
    end)
end

-- Импульс угла обзора (FOV Kick) при рывках мобильности
function JuiceEffects.fovPulse(fovKick: number?, duration: number?)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local kick = fovKick or 12
    local dur = duration or 0.4
    local origFOV = camera.FieldOfView

    local tUp = TweenService:Create(camera, TweenInfo.new(dur * 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        FieldOfView = math.min(105, origFOV + kick)
    })
    local tDown = TweenService:Create(camera, TweenInfo.new(dur * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = origFOV
    })

    tUp:Play()
    tUp.Completed:Connect(function()
        tDown:Play()
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
    tween.Completed:Connect(function()
        flashFrame:Destroy()
    end)
end

return JuiceEffects
