--!strict

--[=[
    CinematicCamera
    Режиссер кинематографической камеры для Roblox боевой системы:
    - Focus Cut-In (драматический наезд камеры на лицо/торс при виндапах и жесте "SHHH")
    - Голландский угол (Dutch Angle: наклон горизонта на 10-15° для динамики блокбастера)
    - Сжатие угла обзора (FOV Compression 70 -> 48) с последующим взрывным отскоком
    - Низкий ракурс (Low-Angle Slam) для эпичных падающих ударов сверху вниз
    - Гарантированное восстановление управления Custom Camera при любых прерываниях
    - Защита от клиппинга в стены спереди и сзади через рейкасты
]=]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local CinematicCamera = {}

local activeCameraThread: thread? = nil
local activeCameraTween: Tween? = nil
local originalFOV: number? = nil
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

    if activeCameraTween then
        activeCameraTween:Cancel()
        activeCameraTween = nil
    end

    local cam = getCamera()
    if not cam then return end

    local char = localPlayer.Character
    local hum = if char then char:FindFirstChildOfClass("Humanoid") else nil

    cam.CameraType = Enum.CameraType.Custom
    if hum then
        cam.CameraSubject = hum
    end

    -- Восстанавливаем исходный угол обзора игрока только если синематик модифицировал его
    if isCinematicActive and originalFOV then
        cam.FieldOfView = originalFOV
    end
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
    local cachedFOV = originalFOV or cam.FieldOfView
    CinematicCamera.resetCamera()
    originalFOV = cachedFOV
    isCinematicActive = true

    local dur = duration or 0.55
    local dist = zoomDistance or 5.5
    local roll = math.rad(dutchAngleDeg or -12)
    local targetFocusPoint = if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)

    -- Рейкаст для предотвращения клиппинга камеры в стены базы
    local faceDir = root.CFrame.LookVector
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { targetCharacter }

    local maxDist = dist
    local hit = Workspace:Raycast(targetFocusPoint, faceDir * (dist * 1.5), rayParams)
    if hit then
        maxDist = math.clamp(hit.Distance - 0.4, 0.8, dist)
    end

    local startCamPos = targetFocusPoint + faceDir * maxDist + Vector3.new(0, 0.4, 0)
    local targetCamPos = targetFocusPoint + faceDir * (maxDist * 0.85) + Vector3.new(0, 0.2, 0)

    cam.CameraType = Enum.CameraType.Scriptable
    cam.CFrame = CFrame.lookAt(startCamPos, targetFocusPoint) * CFrame.Angles(0, 0, roll)

    -- Плавный драматический наезд
    local tweenInfo = TweenInfo.new(dur, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local twPos = TweenService:Create(cam, tweenInfo, {
        CFrame = CFrame.lookAt(targetCamPos, targetFocusPoint) * CFrame.Angles(0, 0, roll),
        FieldOfView = math.clamp(cachedFOV - 18, 42, 65),
    })
    activeCameraTween = twPos
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
    local cachedFOV = originalFOV or cam.FieldOfView
    CinematicCamera.resetCamera()
    originalFOV = cachedFOV
    isCinematicActive = true

    local dur = duration or 0.6
    local focusPoint = root.Position + Vector3.new(0, 4, 0)

    -- Рейкаст для проверки уровня пола под камерой (предотвращает проваливание под землю)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { targetCharacter }

    local groundOffset = -2.5
    local floorHit = Workspace:Raycast(root.Position, Vector3.new(0, -6, 0), rayParams)
    if floorHit then
        local floorY = floorHit.Position.Y
        if (root.Position.Y + groundOffset) < (floorY + 0.8) then
            groundOffset = (floorY + 0.8) - root.Position.Y
        end
    end

    -- Рейкаст назад: предотвращает пробитие стен арены/базы позади игрока
    local backDir = -root.CFrame.LookVector
    local desiredDist = 12
    local backHit = Workspace:Raycast(root.Position, backDir * desiredDist, rayParams)
    if backHit then
        desiredDist = math.clamp(backHit.Distance - 0.6, 2.0, desiredDist)
    end

    local lowCamPos = root.Position + backDir * desiredDist + Vector3.new(0, groundOffset, 0)

    cam.CameraType = Enum.CameraType.Scriptable
    cam.CFrame = CFrame.lookAt(lowCamPos, focusPoint) * CFrame.Angles(0, 0, math.rad(6))

    local tw = TweenService:Create(cam, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FieldOfView = math.clamp(cachedFOV - 12, 45, 65),
    })
    activeCameraTween = tw
    tw:Play()

    activeCameraThread = task.delay(dur, function()
        CinematicCamera.resetCamera()
    end)
end

function CinematicCamera.isActive(): boolean
    return isCinematicActive
end

CinematicCamera.safeReset = CinematicCamera.resetCamera

-- Автоматический сброс камеры при гибели или респавне локального персонажа
local function bindCharacter(char: Model)
    if isCinematicActive then
        CinematicCamera.resetCamera()
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            CinematicCamera.resetCamera()
        end)
    end
end

if localPlayer then
    if localPlayer.Character then
        bindCharacter(localPlayer.Character)
    end
    localPlayer.CharacterAdded:Connect(bindCharacter)
end

return CinematicCamera
