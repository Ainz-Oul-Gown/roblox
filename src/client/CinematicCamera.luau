--!strict

--[=[
    CinematicCamera
    Режиссер кинематографической камеры для Roblox боевой системы:
    - Focus Cut-In (драматический наезд камеры на лицо/торс при виндапах и жесте "SHHH")
    - Голландский угол (Dutch Angle: наклон горизонта на 10-15° для динамики блокбастера)
    - Сжатие угла обзора (FOV Compression 70 -> 48) с последующим взрывным отскоком
    - Низкий ракурс (Low-Angle Slam) для эпичных падающих ударов сверху вниз
    - Гарантированное восстановление управления Custom Camera при любых прерываниях
]=]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local CinematicCamera = {}

local activeCameraThread: thread? = nil
local originalFOV: number = 70
local isCinematicActive = false

-- Получение текущей камеры
local function getCamera(): Camera?
    return Workspace.CurrentCamera
end

-- Безопасный сброс камеры в дефолтный режим
function CinematicCamera.resetCamera()
    if activeCameraThread then
        task.cancel(activeCameraThread)
        activeCameraThread = nil
    end

    local cam = getCamera()
    if not cam then return end

    local char = localPlayer.Character
    local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil

    cam.CameraType = Enum.CameraType.Custom
    if hum then
        cam.CameraSubject = hum
    end
    cam.FieldOfView = originalFOV
    isCinematicActive = false
end

-- 1. Драматический наезд на лицо/торс (Focus Cut-In с голландским углом)
-- Используется на ультимейте Сигмы при жесте "SHHH" и ультимейтах других фракций
function CinematicCamera.focusCutIn(targetCharacter: Model, duration: number?, zoomDistance: number?, dutchAngleDeg: number?)
    local cam = getCamera()
    if not cam then return end

    local root = targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    local head = targetCharacter:FindFirstChild("Head") :: BasePart?
    if not root then return end

    if not isCinematicActive then
        originalFOV = cam.FieldOfView
    end
    CinematicCamera.resetCamera()
    isCinematicActive = true

    local dur = duration or 0.55
    local dist = zoomDistance or 5.5
    local roll = math.rad(dutchAngleDeg or -12)
    local targetFocusPoint = if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)

    -- Располагаем камеру прямо перед лицом/грудью персонажа
    local faceDir = root.CFrame.LookVector
    local startCamPos = targetFocusPoint + faceDir * (dist * 1.5) + Vector3.new(0, 0.4, 0)
    local targetCamPos = targetFocusPoint + faceDir * dist + Vector3.new(0, 0.2, 0)

    cam.CameraType = Enum.CameraType.Scriptable
    cam.CFrame = CFrame.lookAt(startCamPos, targetFocusPoint) * CFrame.Angles(0, 0, roll)

    -- Плавный драматический наезд
    local tweenInfo = TweenInfo.new(dur, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local twPos = TweenService:Create(cam, tweenInfo, {
        CFrame = CFrame.lookAt(targetCamPos, targetFocusPoint) * CFrame.Angles(0, 0, roll),
        FieldOfView = math.clamp(originalFOV - 18, 42, 65),
    })
    twPos:Play()

    activeCameraThread = task.delay(dur + 0.05, function()
        CinematicCamera.resetCamera()
    end)
end

-- 2. Взрывной отскок камеры (Explosive Snap-Back) в момент релиза атаки
function CinematicCamera.explosiveSnapBack(juiceEffects: any?, fovKick: number?, trauma: number?)
    CinematicCamera.resetCamera()

    if juiceEffects then
        if juiceEffects.fovPulse then
            juiceEffects.fovPulse(fovKick or 18, 0.4)
        end
        if juiceEffects.traumaShake then
            juiceEffects.traumaShake(trauma or 0.85)
        end
    end
end

-- 3. Низкий ракурс снизу вверх (Low-Angle Slam)
-- Используется для CaseOh, TungTung и Skibidi Titan при ударах с небес
function CinematicCamera.groundSlamPerspective(targetCharacter: Model, duration: number?)
    local cam = getCamera()
    if not cam then return end

    local root = targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    if not isCinematicActive then
        originalFOV = cam.FieldOfView
    end
    CinematicCamera.resetCamera()
    isCinematicActive = true

    local dur = duration or 0.6
    local focusPoint = root.Position + Vector3.new(0, 4, 0)
    local lowCamPos = root.Position - root.CFrame.LookVector * 12 - Vector3.new(0, 2.5, 0)

    cam.CameraType = Enum.CameraType.Scriptable
    cam.CFrame = CFrame.lookAt(lowCamPos, focusPoint) * CFrame.Angles(0, 0, math.rad(6))

    local tw = TweenService:Create(cam, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = math.clamp(originalFOV - 12, 45, 65),
    })
    tw:Play()

    activeCameraThread = task.delay(dur, function()
        CinematicCamera.resetCamera()
    end)
end

function CinematicCamera.isActive(): boolean
    return isCinematicActive
end

CinematicCamera.safeReset = CinematicCamera.resetCamera

-- Автоматический сброс камеры при респавне локального персонажа
if localPlayer then
    localPlayer.CharacterAdded:Connect(function()
        CinematicCamera.resetCamera()
    end)
end

return CinematicCamera
