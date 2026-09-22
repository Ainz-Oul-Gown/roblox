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

-- Кэш исходных C0 суставов для каждого персонажа
local originalC0Cache: { [Motor6D]: CFrame } = {}
local activeAnimTokens: { [Model]: number } = {}

-- Поиск и классификация суставов персонажа (R15 и R6)
local function getJoints(character: Model): JointMap
    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local joints: JointMap = { isR15 = isR15 }

    if isR15 then
        local rightUpperArm = character:FindFirstChild("RightUpperArm")
        if rightUpperArm then joints.rightShoulder = rightUpperArm:FindFirstChild("RightShoulder") :: Motor6D? end

        local leftUpperArm = character:FindFirstChild("LeftUpperArm")
        if leftUpperArm then joints.leftShoulder = leftUpperArm:FindFirstChild("LeftShoulder") :: Motor6D? end

        local rightLowerArm = character:FindFirstChild("RightLowerArm")
        if rightLowerArm then joints.rightElbow = rightLowerArm:FindFirstChild("RightElbow") :: Motor6D? end

        local leftLowerArm = character:FindFirstChild("LeftLowerArm")
        if leftLowerArm then joints.leftElbow = leftLowerArm:FindFirstChild("LeftElbow") :: Motor6D? end

        local head = character:FindFirstChild("Head")
        if head then joints.neck = head:FindFirstChild("Neck") :: Motor6D? end

        local upperTorso = character:FindFirstChild("UpperTorso")
        if upperTorso then joints.waist = upperTorso:FindFirstChild("Waist") :: Motor6D? end

        local lowerTorso = character:FindFirstChild("LowerTorso")
        if lowerTorso then joints.rootJoint = lowerTorso:FindFirstChild("Root") :: Motor6D? end
    else
        -- R6 аватар
        local torso = character:FindFirstChild("Torso")
        if torso then
            joints.rightShoulder = torso:FindFirstChild("Right Shoulder") :: Motor6D?
            joints.leftShoulder = torso:FindFirstChild("Left Shoulder") :: Motor6D?
            joints.neck = torso:FindFirstChild("Neck") :: Motor6D?
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

    return joints
end
CharacterAnimator.getJoints = getJoints

-- Безопасный возврат суставов в исходное состояние
local function restoreJoints(character: Model, joints: JointMap, tweenTime: number?)
    local t = tweenTime or 0.25
    for _, joint in pairs(joints :: any) do
        if typeof(joint) == "Instance" and joint:IsA("Motor6D") then
            local origC0 = originalC0Cache[joint]
            if origC0 and joint.Parent then
                local tw = TweenService:Create(joint, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    C0 = origC0,
                })
                tw:Play()
            end
        end
    end
end
CharacterAnimator.restoreJoints = restoreJoints

-- 1. Жест "SHHH" / Мьюинг (Палец к губам, фиксация подбородка, легкий наклон головы)
function CharacterAnimator.playShhhPose(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.2
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Правая рука поднимается к лицу/губам
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        local targetC0 = if joints.isR15
            then orig * CFrame.Angles(math.rad(105), math.rad(-25), math.rad(45)) * CFrame.new(-0.2, 0.2, -0.3)
            else orig * CFrame.Angles(math.rad(115), math.rad(-30), math.rad(50))

        local tw = TweenService:Create(joints.rightShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = targetC0,
        })
        tw:Play()
    end

    -- Сгибание правого локтя к губам (R15)
    if joints.rightElbow then
        local orig = originalC0Cache[joints.rightElbow] or joints.rightElbow.C0
        local tw = TweenService:Create(joints.rightElbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(85), 0, 0),
        })
        tw:Play()
    end

    -- Голова наклоняется слегка вперед и вбок (Mewing looksmaxing)
    if joints.neck then
        local orig = originalC0Cache[joints.neck] or joints.neck.C0
        local tw = TweenService:Create(joints.neck, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(-12), math.rad(8), math.rad(-8)),
        })
        tw:Play()
    end

    -- Удержание позы и плавный возврат
    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 2. Гигачад Двойной Бицепс (Power Flex / Арочный прогиб торса)
function CharacterAnimator.playGigachadFlex(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.4
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Обе руки в позу двойного бицепса
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        local tw = TweenService:Create(joints.rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(85), math.rad(25), math.rad(75)),
        })
        tw:Play()
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        local tw = TweenService:Create(joints.leftShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(85), math.rad(-25), math.rad(-75)),
        })
        tw:Play()
    end

    if joints.rightElbow then
        local orig = originalC0Cache[joints.rightElbow] or joints.rightElbow.C0
        TweenService:Create(joints.rightElbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(95), 0, 0),
        }):Play()
    end
    if joints.leftElbow then
        local orig = originalC0Cache[joints.leftElbow] or joints.leftElbow.C0
        TweenService:Create(joints.leftElbow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(95), 0, 0),
        }):Play()
    end

    -- Торс прогибается назад
    if joints.waist then
        local orig = originalC0Cache[joints.waist] or joints.waist.C0
        TweenService:Create(joints.waist, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(-15), 0, 0),
        }):Play()
    end

    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.35)
        end
    end)
end

-- 3. Сигма Phonk Tilt (Стильный наклон головы в ритм фонка)
function CharacterAnimator.playSigmaTilt(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.6
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    if joints.neck then
        local orig = originalC0Cache[joints.neck] or joints.neck.C0
        -- Резкий кивок и наклон
        local tw = TweenService:Create(joints.neck, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(-18), math.rad(-15), math.rad(-22)),
        })
        tw:Play()
    end

    -- Руки скрещиваются или отводятся назад в доминантную стойку
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        TweenService:Create(joints.rightShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(-25), 0, math.rad(15)),
        }):Play()
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        TweenService:Create(joints.leftShoulder, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(-25), 0, math.rad(-15)),
        }):Play()
    end

    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 4. CaseOh Ground Pound (Огромный двуручный замах ввысь и удар в пол)
function CharacterAnimator.playGroundPound(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 0.9
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Фаза 1: Замах обеими руками над головой
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        TweenService:Create(joints.rightShoulder, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(160), 0, math.rad(-15)),
        }):Play()
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        TweenService:Create(joints.leftShoulder, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(160), 0, math.rad(15)),
        }):Play()
    end
    if joints.waist then
        local orig = originalC0Cache[joints.waist] or joints.waist.C0
        TweenService:Create(joints.waist, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(-20), 0, 0),
        }):Play()
    end

    -- Фаза 2: Сокрушительный удар вниз
    task.delay(0.28, function()
        if activeAnimTokens[character] ~= token or not character.Parent then return end

        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            TweenService:Create(joints.rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                C0 = orig * CFrame.Angles(math.rad(-30), 0, math.rad(-15)),
            }):Play()
        end
        if joints.leftShoulder then
            local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
            TweenService:Create(joints.leftShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                C0 = orig * CFrame.Angles(math.rad(-30), 0, math.rad(15)),
            }):Play()
        end
        if joints.waist then
            local orig = originalC0Cache[joints.waist] or joints.waist.C0
            TweenService:Create(joints.waist, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                C0 = orig * CFrame.Angles(math.rad(35), 0, 0),
            }):Play()
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.28)
        end
    end)
end

-- 5. TungTung Hammer Swing (Двуручный горизонтальный и вертикальный клив)
function CharacterAnimator.playHammerSwing(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.0
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Замах вправо-назад
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        TweenService:Create(joints.rightShoulder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(120), math.rad(-60), math.rad(30)),
        }):Play()
    end
    if joints.waist then
        local orig = originalC0Cache[joints.waist] or joints.waist.C0
        TweenService:Create(joints.waist, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(0, math.rad(-35), 0),
        }):Play()
    end

    -- Рассекающий рубящий удар вперед
    task.delay(0.25, function()
        if activeAnimTokens[character] ~= token or not character.Parent then return end

        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            TweenService:Create(joints.rightShoulder, TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                C0 = orig * CFrame.Angles(math.rad(-20), math.rad(70), math.rad(-20)),
            }):Play()
        end
        if joints.waist then
            local orig = originalC0Cache[joints.waist] or joints.waist.C0
            TweenService:Create(joints.waist, TweenInfo.new(0.15, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
                C0 = orig * CFrame.Angles(0, math.rad(45), 0),
            }):Play()
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 6. Rizzler Flourish (Изящный жест рукой, поправление волос, наклон к цели)
function CharacterAnimator.playRizzlerFlourish(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.2
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Правая рука поправляет волосы и плавно вытягивается вперед
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        TweenService:Create(joints.rightShoulder, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(130), math.rad(-20), math.rad(40)),
        }):Play()
    end
    if joints.neck then
        local orig = originalC0Cache[joints.neck] or joints.neck.C0
        TweenService:Create(joints.neck, TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(-8), math.rad(18), math.rad(15)),
        }):Play()
    end

    -- Плавный взмах в сторону камеры
    task.delay(0.32, function()
        if activeAnimTokens[character] ~= token or not character.Parent then return end
        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            TweenService:Create(joints.rightShoulder, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                C0 = orig * CFrame.Angles(math.rad(70), math.rad(30), math.rad(25)),
            }):Play()
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.3)
        end
    end)
end

-- 7. Skibidi Spin & Salute (Вращение корпуса на 720° с армейским салютом)
function CharacterAnimator.playSpinSalute(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 1.0
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Армейский салют правой рукой
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        TweenService:Create(joints.rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(115), math.rad(-30), math.rad(65)),
        }):Play()
    end
    if joints.rightElbow then
        local orig = originalC0Cache[joints.rightElbow] or joints.rightElbow.C0
        TweenService:Create(joints.rightElbow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(110), 0, 0),
        }):Play()
    end

    -- Вихревое вращение торса (waist/root)
    if joints.waist then
        local orig = originalC0Cache[joints.waist] or joints.waist.C0
        task.spawn(function()
            local tw1 = TweenService:Create(joints.waist, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
                C0 = orig * CFrame.Angles(0, math.rad(180), 0),
            })
            tw1:Play()
            tw1.Completed:Wait()
            if activeAnimTokens[character] == token and joints.waist then
                local tw2 = TweenService:Create(joints.waist, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {
                    C0 = orig * CFrame.Angles(0, math.rad(360), 0),
                })
                tw2:Play()
            end
        end)
    end

    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.25)
        end
    end)
end

-- 8. FanumTax Money Snatch (Агрессивный бросок руками вперед и загребание)
function CharacterAnimator.playMoneySnatch(character: Model, duration: number?)
    if not character or not character:IsA("Model") then return end
    local joints = getJoints(character)
    local dur = duration or 0.9
    local token = (activeAnimTokens[character] or 0) + 1
    activeAnimTokens[character] = token

    -- Руки выбрасываются вперед (схватить ауру/бургер)
    if joints.rightShoulder then
        local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
        TweenService:Create(joints.rightShoulder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(85), math.rad(-15), 0),
        }):Play()
    end
    if joints.leftShoulder then
        local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
        TweenService:Create(joints.leftShoulder, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            C0 = orig * CFrame.Angles(math.rad(85), math.rad(15), 0),
        }):Play()
    end

    -- Загребание назад к груди
    task.delay(0.2, function()
        if activeAnimTokens[character] ~= token or not character.Parent then return end
        if joints.rightShoulder then
            local orig = originalC0Cache[joints.rightShoulder] or joints.rightShoulder.C0
            TweenService:Create(joints.rightShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                C0 = orig * CFrame.Angles(math.rad(45), math.rad(25), math.rad(35)),
            }):Play()
        end
        if joints.leftShoulder then
            local orig = originalC0Cache[joints.leftShoulder] or joints.leftShoulder.C0
            TweenService:Create(joints.leftShoulder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                C0 = orig * CFrame.Angles(math.rad(45), math.rad(-25), math.rad(-35)),
            }):Play()
        end
    end)

    task.delay(dur, function()
        if activeAnimTokens[character] == token and character.Parent then
            restoreJoints(character, joints, 0.25)
        end
    end)
end

return CharacterAnimator
