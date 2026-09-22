--!strict

--[=[
    CharacterAnimator
    Движок процедурных кинематографических анимаций для R15 и R6 персонажей в Roblox:
    - Жест "SHHH / Mewing" (палец к губам, наклон головы, лок челюсти)
    - Гигачад двойной бицепс (флекс обеими руками, прогиб торса)
    - Сигма Phonk Tilt (стильный наклон головы и плеч)
    - CaseOh Ground Pound (двуручный сокрушительный замах и удар оземь)
    - TungTung Hammer Swing (круговой и вертикальный замах молота)
    - Rizzler Flourish (поправление прически, подача корпуса вперед)
    - Skibidi Spin & Salute (вращение корпуса на 720° с армейским салютом)
    - FanumTax Money Snatch (агрессивный бросок руками вперед и загребание)

    Автоматически восстанавливает исходную позу (Joint C0) без сбоев и багов анимации ходьбы.
    Предотвращает конфликты твинов через activeJointTweens.
]=]

local TweenService = game:GetService("TweenService")

export type JointMap = {
    rightShoulder: Motor6D?,
    leftShoulder: Motor6D?,
    rightElbow: Motor6D?,
    leftElbow: Motor6D?,
    neck: Motor6D?,
    waist: Motor6D?,
    rootJoint: Motor6D?,
    isR15: boolean,
}

local CharacterAnimator = {}

-- Кэш исходных C0 суставов для каждого персонажа (слабые ключи предотвращают утечки памяти при респавне)
local originalC0Cache: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" })
local activeAnimTokens: { [Model]: number } = setmetatable({}, { __mode = "k" })
local activeJointTweens: { [Motor6D]: Tween } = setmetatable({}, { __mode = "k" })
local deadConnections: { [Humanoid]: RBXScriptConnection } = setmetatable({}, { __mode = "k" })

-- Безопасный запуск твина сустава с отменой предыдущего и освобождением ресурсов C++
local function tweenJoint(joint: Motor6D, tweenInfo: TweenInfo, targetC0: CFrame): Tween
    local prev = activeJointTweens[joint]
    if prev then
        prev:Cancel()
        pcall(function()
            prev:Destroy()
        end)
        activeJointTweens[joint] = nil
    end
    local tw = TweenService:Create(joint, tweenInfo, { C0 = targetC0 })
    activeJointTweens[joint] = tw
    tw.Completed:Connect(function()
        if activeJointTweens[joint] == tw then
            activeJointTweens[joint] = nil
        end
        pcall(function()
            tw:Destroy()
        end)
    end)
    tw:Play()
    return tw
end
CharacterAnimator.tweenJoint = tweenJoint

-- Проверка живого состояния персонажа во избежание деформации трупа при смерти/рэгдолле
local function isCharacterAlive(character: Model): boolean
    if not character or not character.Parent then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end
CharacterAnimator.isCharacterAlive = isCharacterAlive

-- Вспомогательный поиск Motor6D с поддержкой разных родителей и вариантов имен
local function findMotor6D(parent: Instance?, ...: string): Motor6D?
    if not parent then return nil end
    for _, name in ipairs({ ... }) do
        local child = parent:FindFirstChild(name)
        if child and child:IsA("Motor6D") then
            return child :: Motor6D
        end
    end
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("Motor6D") then
            for _, name in ipairs({ ... }) do
                if child.Name == name or (child.Part1 and child.Part1.Name == name) then
                    return child :: Motor6D
                end
            end
        end
    end
    return nil
end

-- Поиск и классификация суставов персонажа (R15 и R6)
local function getJoints(character: Model): JointMap
    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local joints: JointMap = { isR15 = isR15 }

    if isR15 then
        local rightUpperArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("RightArm")
        local leftUpperArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("LeftArm")
        local upperTorso = character:FindFirstChild("UpperTorso")
        local lowerTorso = character:FindFirstChild("LowerTorso")

        joints.rightShoulder = (rightUpperArm and rightUpperArm:FindFirstChild("RightShoulder") :: Motor6D?)
            or findMotor6D(rightUpperArm, "RightShoulder", "Right Shoulder")
            or findMotor6D(upperTorso, "RightShoulder", "Right Shoulder")

        joints.leftShoulder = (leftUpperArm and leftUpperArm:FindFirstChild("LeftShoulder") :: Motor6D?)
            or findMotor6D(leftUpperArm, "LeftShoulder", "Left Shoulder")
            or findMotor6D(upperTorso, "LeftShoulder", "Left Shoulder")

        local rightLowerArm = character:FindFirstChild("RightLowerArm")
        if rightLowerArm then joints.rightElbow = rightLowerArm:FindFirstChild("RightElbow") :: Motor6D? end

        local leftLowerArm = character:FindFirstChild("LeftLowerArm")
        if leftLowerArm then joints.leftElbow = leftLowerArm:FindFirstChild("LeftElbow") :: Motor6D? end

        local head = character:FindFirstChild("Head")
        if head then joints.neck = head:FindFirstChild("Neck") :: Motor6D? end
        if not joints.neck and upperTorso then
            joints.neck = upperTorso:FindFirstChild("Neck") :: Motor6D?
        end

        if upperTorso then joints.waist = upperTorso:FindFirstChild("Waist") :: Motor6D? end
        if not joints.waist and lowerTorso then
            joints.waist = lowerTorso:FindFirstChild("Waist") :: Motor6D?
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            joints.rootJoint = (hrp:FindFirstChild("Root") or hrp:FindFirstChild("RootJoint")) :: Motor6D?
        end
        if not joints.rootJoint and lowerTorso then
            joints.rootJoint = lowerTorso:FindFirstChild("Root") :: Motor6D?
        end
    else
        -- R6 аватар
        local torso = character:FindFirstChild("Torso")
        local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightArm")
        local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftArm")
        if torso then
            joints.rightShoulder = (torso:FindFirstChild("Right Shoulder") :: Motor6D?)
                or findMotor6D(torso, "Right Shoulder", "RightShoulder")
                or findMotor6D(rightArm, "Right Shoulder", "RightShoulder")
            joints.leftShoulder = (torso:FindFirstChild("Left Shoulder") :: Motor6D?)
                or findMotor6D(torso, "Left Shoulder", "LeftShoulder")
                or findMotor6D(leftArm, "Left Shoulder", "LeftShoulder")
            joints.neck = (torso:FindFirstChild("Neck") :: Motor6D?)
                or findMotor6D(torso, "Neck")
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            joints.rootJoint = hrp:FindFirstChild("RootJoint") :: Motor6D?
        end
    end

    -- Сохраняем исходные C0 в кэш при первом обращении
    for _, joint in pairs(joints :: any) do
        if typeof(joint) == "Instance" and joint:IsA("Motor6D") and not originalC0Cache[joint] then
            originalC0Cache[joint] = joint.C0
        end
    end

    -- Автоматический сброс анимации при гибели персонажа во избежание застывания трупа в неестественной позе
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and not deadConnections[hum] then
        deadConnections[hum] = hum.Died:Connect(function()
            if deadConnections[hum] then
                deadConnections[hum]:Disconnect()
                deadConnections[hum] = nil
            end
            CharacterAnimator.stopAnimation(character)
        end)
    end

    return joints
end
CharacterAnimator.getJoints = getJoints

-- Безопасный возврат суставов в исходное состояние с инвалидацией отложенных фаз
local function restoreJoints(character: Model, joints: JointMap, tweenTime: number?)
    -- Инкремент токена отменяет любые незавершенные task.delay фаз удара
    activeAnimTokens[character] = (activeAnimTokens[character] or 0) + 1
    local t = tweenTime or 0.25
    for _, joint in pairs(joints :: any) do
        if typeof(joint) == "Instance" and joint:IsA("Motor6D") then
            local origC0 = originalC0Cache[joint]
            if origC0 and joint.Parent then
                tweenJoint(joint, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), origC0)
            end
        end
    end
end
CharacterAnimator.restoreJoints = restoreJoints

-- Принудительная остановка любой анимации (для оглушений, рэгдолла и смерти)
function CharacterAnimator.stopAnimation(character: Model)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    restoreJoints(character, joints, 0.1)
end

-- 1. Жест "SHHH" / Мьюинг (Палец к губам, фиксация подбородка, легкий наклон головы)
function CharacterAnimator.playShhhPose(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.2
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Разворот торса на 22 градуса в 3/4 профиль: жест становится отчетливо виден со спины при виде от 3-го лица!
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local turnRot = if joints.isR15
            then CFrame.Angles(math.rad(4), math.rad(22), math.rad(-4))
            else CFrame.Angles(0, 0, math.rad(22))
        tweenJoint(torsoJoint, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * turnRot)
    end

    -- Правая рука поднимается к лицу/губам с выносом локтя в сторону
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        local targetC0 = if joints.isR15
            then orig * CFrame.Angles(math.rad(105), math.rad(-25), math.rad(45)) * CFrame.new(-0.2, 0.2, -0.3)
            else orig * CFrame.Angles(math.rad(115), math.rad(-30), math.rad(50))

        tweenJoint(joints.rightShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), targetC0)
    end

    -- Сгибание правого локтя к губам (R15)
    if joints.rightElbow then
        local orig = originalC0Cache[joints.rightElbow] or joints.rightElbow.C0
        tweenJoint(joints.rightElbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(85), 0, 0))
    end

    -- Голова наклоняется слегка вперед и вбок (Mewing looksmaxing)
    if joints.neck then
        local orig = originalC0Cache[joints.neck] or joints.neck.C0
        tweenJoint(joints.neck, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-12), math.rad(15), math.rad(-8)))
    end

    -- Удержание позы и плавный возврат
    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 2. Гигачад Двойной Бицепс (Power Flex / Арочный прогиб торса)
function CharacterAnimator.playGigachadFlex(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.4
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Обе руки в позу двойного бицепса
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        tweenJoint(joints.rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(85), math.rad(25), math.rad(75)))
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        tweenJoint(joints.leftShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(85), math.rad(-25), math.rad(-75)))
    end

    if joints.rightElbow then
        local orig = originalC0Cache[joints.rightElbow] or joints.rightElbow.C0
        tweenJoint(joints.rightElbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(95), 0, 0))
    end
    if joints.leftElbow then
        local orig = originalC0Cache[joints.leftElbow] or joints.leftElbow.C0
        tweenJoint(joints.leftElbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(95), 0, 0))
    end

    -- Торс прогибается назад (поддержка R15 Waist и R6 RootJoint)
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local rot = if joints.isR15
            then CFrame.Angles(math.rad(-15), 0, 0)
            else CFrame.Angles(0, math.rad(-15), 0) -- В R6 RootJoint pitch управляется осью Y
        tweenJoint(torsoJoint, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * rot)
    end

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.35)
        end
    end)
end

-- 3. Сигма Phonk Tilt (Стильный наклон головы в ритм фонка)
function CharacterAnimator.playSigmaTilt(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.6
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    if joints.neck then
        local orig = originalC0Cache[joints.neck] or joints.neck.C0
        -- Резкий кивок и наклон
        tweenJoint(joints.neck, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-18), math.rad(-15), math.rad(-22)))
    end

    -- Руки отводятся назад в доминантную стойку
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        tweenJoint(joints.rightShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-25), 0, math.rad(15)))
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        tweenJoint(joints.leftShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-25), 0, math.rad(-15)))
    end

    -- Разворот торса на 16 градусов в полупрофиль: наклон головы и холодный взгляд становятся видны со спины
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local rot = if joints.isR15
            then CFrame.Angles(math.rad(4), math.rad(16), 0)
            else CFrame.Angles(0, 0, math.rad(16))
        tweenJoint(torsoJoint, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * rot)
    end

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 4. CaseOh Ground Pound (Огромный двуручный замах ввысь и удар в пол)
function CharacterAnimator.playGroundPound(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 0.9
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Фаза 1: Замах обеими руками над головой
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        tweenJoint(joints.rightShoulder, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(160), 0, math.rad(-15)))
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        tweenJoint(joints.leftShoulder, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(160), 0, math.rad(15)))
    end
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local rot = if joints.isR15
            then CFrame.Angles(math.rad(-20), 0, 0)
            else CFrame.Angles(0, math.rad(-20), 0)
        tweenJoint(torsoJoint, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * rot)
    end

    -- Фаза 2: Сокрушительный удар вниз
    task.delay(0.28, function()
        if activeAnimTokens[character] ~= token or not isCharacterAlive(character) then return end

        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            tweenJoint(joints.rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), orig * CFrame.Angles(math.rad(-30), 0, math.rad(-15)))
        end
        if joints.leftShoulder then
            local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
            tweenJoint(joints.leftShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), orig * CFrame.Angles(math.rad(-30), 0, math.rad(15)))
        end
        local slamTorso = joints.waist or joints.rootJoint
        if slamTorso then
            local orig = originalC0Cache[slamTorso] or slamTorso.C0
            local rot = if joints.isR15
                then CFrame.Angles(math.rad(35), 0, 0)
                else CFrame.Angles(0, math.rad(35), 0)
            tweenJoint(slamTorso, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), orig * rot)
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.28)
        end
    end)
end

-- 5. TungTung Hammer Swing (Двуручный горизонтальный и вертикальный клив)
function CharacterAnimator.playHammerSwing(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.0
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Замах вправо-назад
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        tweenJoint(joints.rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(120), math.rad(-60), math.rad(30)))
    end
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local windupRot = if joints.isR15 then CFrame.Angles(0, math.rad(-35), 0) else CFrame.Angles(0, 0, math.rad(-35))
        tweenJoint(torsoJoint, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * windupRot)
    end

    -- Рассекающий рубящий удар вперед
    task.delay(0.25, function()
        if activeAnimTokens[character] ~= token or not isCharacterAlive(character) then return end

        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            tweenJoint(joints.rightShoulder, TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-20), math.rad(70), math.rad(-20)))
        end
        local swingTorso = joints.waist or joints.rootJoint
        if swingTorso then
            local orig = originalC0Cache[swingTorso] or swingTorso.C0
            local swingRot = if joints.isR15 then CFrame.Angles(0, math.rad(45), 0) else CFrame.Angles(0, 0, math.rad(45))
            tweenJoint(swingTorso, TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), orig * swingRot)
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 6. Rizzler Flourish (Изящный жест рукой, поправление волос, наклон к цели)
function CharacterAnimator.playRizzlerFlourish(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.2
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Правая рука поправляет волосы и плавно вытягивается вперед
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        tweenJoint(joints.rightShoulder, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(130), math.rad(-20), math.rad(40)))
    end
    if joints.neck then
        local orig = originalC0Cache[joints.neck] or joints.neck.C0
        tweenJoint(joints.neck, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-8), math.rad(18), math.rad(15)))
    end

    -- Изящный наклон и полуразворот корпуса на 18 градусов для выразительного силуэта сзади
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local rot = if joints.isR15
            then CFrame.Angles(math.rad(4), math.rad(-18), math.rad(6))
            else CFrame.Angles(0, 0, math.rad(-18))
        tweenJoint(torsoJoint, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), orig * rot)
    end

    -- Плавный взмах в сторону цели
    task.delay(0.32, function()
        if activeAnimTokens[character] ~= token or not isCharacterAlive(character) then return end
        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            tweenJoint(joints.rightShoulder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(70), math.rad(30), math.rad(25)))
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 7. Skibidi Spin & Salute (Вращение всего корпуса вокруг вертикальной оси с армейским салютом)
function CharacterAnimator.playSpinSalute(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.0
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Армейский салют правой рукой
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        tweenJoint(joints.rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(115), math.rad(-30), math.rad(65)))
    end
    if joints.rightElbow then
        local orig = originalC0Cache[joints.rightElbow] or joints.rightElbow.C0
        tweenJoint(joints.rightElbow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(110), 0, 0))
    end

    -- Вращение всего аватара: используем rootJoint (HRP.Root для R15 / HRP.RootJoint для R6)
    local spinJoint = joints.rootJoint or joints.waist
    if spinJoint then
        local orig = originalC0Cache[spinJoint] or spinJoint.C0
        -- И в R15 (Root), и в R6 (RootJoint) локальная ось Z направлена вверх (Yaw)
        local rot180 = CFrame.Angles(0, 0, math.rad(180))
        local rotN179 = CFrame.Angles(0, 0, math.rad(-179))
        tweenJoint(spinJoint, TweenInfo.new(0.2, Enum.EasingStyle.Linear), orig * rot180)
        -- Безопасный переход фазы через task.delay вместо блокирующего tw.Completed:Wait() исключает утечку потоков
        task.delay(0.2, function()
            if activeAnimTokens[character] == token and isCharacterAlive(character) and spinJoint and spinJoint.Parent then
                spinJoint.C0 = orig * rotN179
                tweenJoint(spinJoint, TweenInfo.new(0.2, Enum.EasingStyle.Linear), orig)
            end
        end)
    end

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.25)
        end
    end)
end

-- 8. FanumTax Money Snatch (Агрессивный бросок руками вперед и загребание)
function CharacterAnimator.playMoneySnatch(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 0.9
    restoreJoints(character, joints, 0.08)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Руки выбрасываются вперед
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        tweenJoint(joints.rightShoulder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(85), math.rad(-15), 0))
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        tweenJoint(joints.leftShoulder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(85), math.rad(15), 0))
    end

    -- Наклон торса вперед на 18 градусов при броске за добычей
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local rot = if joints.isR15
            then CFrame.Angles(math.rad(18), 0, 0)
            else CFrame.Angles(0, math.rad(18), 0)
        tweenJoint(torsoJoint, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * rot)
    end

    -- Загребание назад к груди
    task.delay(0.2, function()
        if activeAnimTokens[character] ~= token or not isCharacterAlive(character) then return end
        if torsoJoint then
            local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
            local rot = if joints.isR15
                then CFrame.Angles(math.rad(-6), 0, 0)
                else CFrame.Angles(0, math.rad(-6), 0)
            tweenJoint(torsoJoint, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * rot)
        end
        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            tweenJoint(joints.rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(45), math.rad(25), math.rad(35)))
        end
        if joints.leftShoulder then
            local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
            tweenJoint(joints.leftShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(45), math.rad(-25), math.rad(-35)))
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.25)
        end
    end)
end

-- 9. Динамический рывок / Таран плечом (Leaning Dash & Shoulder Charge)
function CharacterAnimator.playDashPose(character: Model, duration: number?, isShoulderCharge: boolean?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 0.35
    restoreJoints(character, joints, 0.06)
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Торс наклоняется вперед на 30 градусов
    local torsoJoint = joints.waist or joints.rootJoint
    if torsoJoint then
        local orig = originalC0Cache[torsoJoint] or torsoJoint.C0
        local rot = if joints.isR15
            then CFrame.Angles(math.rad(30), isShoulderCharge and math.rad(18) or 0, 0)
            else CFrame.Angles(0, math.rad(30), 0)
        tweenJoint(torsoJoint, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * rot)
    end

    -- Шея приподнимает голову вверх, чтобы смотреть прямо по курсу рывка
    if joints.neck then
        local orig = originalC0Cache[joints.neck] or joints.neck.C0
        tweenJoint(joints.neck, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-18), 0, 0))
    end

    if isShoulderCharge then
        -- Правое плечо и локоть выставляются вперед как таран
        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            local chargeRot = if joints.isR15
                then orig * CFrame.Angles(math.rad(75), math.rad(-20), math.rad(35))
                else orig * CFrame.Angles(math.rad(80), math.rad(-25), math.rad(30))
            tweenJoint(joints.rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), chargeRot)
        end
        if joints.leftShoulder then
            local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
            tweenJoint(joints.leftShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-30), 0, math.rad(-15)))
        end
    else
        -- Аэродинамический спринт: обе руки отводятся назад
        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            tweenJoint(joints.rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-55), 0, math.rad(20)))
        end
        if joints.leftShoulder then
            local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
            tweenJoint(joints.leftShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), orig * CFrame.Angles(math.rad(-55), 0, math.rad(-20)))
        end
    end

    task.delay(dur, function()
        if activeAnimTokens[character] == token and isCharacterAlive(character) then
            restoreJoints(character, joints, 0.2)
        end
    end)
end

return CharacterAnimator
