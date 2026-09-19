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
        fovPulse = function() end,
        showFloatingText = function() end,
    }
end

local AbilityVFX = {}

local localPlayer = Players.LocalPlayer

-- Создание расширяющегося неонового ударного кольца на земле
local function createShockwaveRing(pos: Vector3, maxRadius: number, color: Color3, duration: number?)
    local dur = duration or 0.5
    local ring = Instance.new("Part")
    ring.Name = "ShockwaveRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.3, 1, 1)
    ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = 0.2
    ring.Parent = Workspace

    local tween = TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.3, maxRadius * 2, maxRadius * 2),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(ring, dur + 0.1)
end

-- Вспышка вертикального энергетического столба
local function createPillarOfLight(pos: Vector3, height: number, radius: number, color: Color3, duration: number?)
    local dur = duration or 0.6
    local pillar = Instance.new("Part")
    pillar.Name = "EnergyPillar"
    pillar.Shape = Enum.PartType.Cylinder
    pillar.Size = Vector3.new(height, radius * 2, radius * 2)
    pillar.CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
    pillar.Anchored = true
    pillar.CanCollide = false
    pillar.Material = Enum.Material.Neon
    pillar.Color = color
    pillar.Transparency = 0.25
    pillar.Parent = Workspace

    local tween = TweenService:Create(pillar, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(height, (radius * 2) * 1.6, (radius * 2) * 1.6),
        Transparency = 1,
    })
    tween:Play()
    Debris:AddItem(pillar, dur + 0.1)
end

-- Временный направленный неоновый лазер / луч
local function createBeamLine(fromPos: Vector3, toPos: Vector3, color: Color3, thickness: number?, duration: number?)
    local dur = duration or 0.4
    local thick = thickness or 0.8
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

-- Создание падающего объекта с неба (метеорит, наковальня, банхаммер, пицца)
local function spawnFallingSkyProp(targetPos: Vector3, propBuilder: () -> BasePart, onImpact: () -> (), fallHeight: number?)
    local h = fallHeight or 55
    local spawnPos = targetPos + Vector3.new(0, h, 0)
    local prop = propBuilder()
    prop.CFrame = CFrame.new(spawnPos)
    prop.Anchored = true
    prop.CanCollide = false
    prop.Parent = Workspace

    local fallTime = 0.45
    local tween = TweenService:Create(prop, TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        CFrame = CFrame.new(targetPos),
    })
    tween:Play()
    tween.Completed:Connect(function()
        prop:Destroy()
        onImpact()
    end)
end

-- Главная функция проигрывания VFX/SFX способности
function AbilityVFX.play(caster: Player, fId: string, slot: string, originPos: Vector3, lookVector: Vector3)
    local isSelf = (caster == localPlayer)
    local pos = originPos
    local currentFaction = fId
    if not currentFaction or currentFaction == "" then
        currentFaction = "Skibidi"
    end
    local fId = currentFaction

    print(string.format("[AbilityVFX] Playing %s VFX for %s (slot: %s, isSelf: %s)", fId, tostring(caster and caster.Name), tostring(slot), tostring(isSelf)))

    -- 1. SKIBIDI TOILET
    if fId == "Skibidi" then
        if slot == "base" then
            -- Вихрь смыва
            createShockwaveRing(pos, 18, Color3.fromRGB(0, 180, 255), 0.5)
            JuiceEffects.play3DSound("splash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🌊 СМЫВ!", Color3.fromRGB(0, 180, 255))
            if isSelf then JuiceEffects.screenShake(0.4, 0.3) end

        elseif slot == "tactical" then
            -- Скибиди Броня
            createPillarOfLight(pos, 8, 4, Color3.fromRGB(240, 240, 255), 0.5)
            JuiceEffects.play3DSound("magic", pos, 0.8)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🛡️ КЕРАМИЧЕСКИЙ ЩИТ!", Color3.fromRGB(255, 255, 255))

        elseif slot == "ultimate" then
            -- Мега-Смыв 3000
            createShockwaveRing(pos, 32, Color3.fromRGB(0, 120, 255), 0.8)
            createPillarOfLight(pos, 25, 8, Color3.fromRGB(0, 200, 255), 0.8)
            JuiceEffects.play3DSound("splash", pos, 1.2)
            JuiceEffects.play3DSound("slam", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🌀 МЕГА-СМЫВ 3000!", Color3.fromRGB(0, 220, 255))
            if isSelf then JuiceEffects.screenShake(0.8, 0.5) end

        elseif slot == "special" then
            -- Skibidi Dop Dop Anthem
            for i = 1, 3 do
                task.delay((i - 1) * 0.12, function()
                    createShockwaveRing(pos, 12 * i, Color3.fromRGB(255, 215, 0), 0.4)
                end)
            end
            JuiceEffects.play3DSound("horn", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "🎶 SKIBIDI DOP DOP YES YES!", Color3.fromRGB(255, 215, 0))

        elseif slot == "mobility" then
            -- Скибиди Ракета
            createBeamLine(pos, pos + lookVector * 30, Color3.fromRGB(255, 140, 0), 1.2, 0.35)
            JuiceEffects.play3DSound("dash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🚀 РАКЕТНЫЙ ВЫХЛОП!", Color3.fromRGB(255, 120, 0))
            if isSelf then JuiceEffects.fovPulse(15, 0.4) end

        elseif slot == "godmode" then
            -- Титан Скибиди-Крушитель
            createPillarOfLight(pos, 40, 14, Color3.fromRGB(255, 215, 0), 1.2)
            createShockwaveRing(pos, 45, Color3.fromRGB(255, 80, 0), 1.0)
            JuiceEffects.play3DSound("slam", pos, 1.5)
            JuiceEffects.play3DSound("fanfare", pos, 1.2)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "⚡ ТИТАН КРУШИТЕЛЬ!", Color3.fromRGB(255, 215, 0))
            if isSelf then
                JuiceEffects.screenShake(1.2, 0.8)
                JuiceEffects.screenFlash(Color3.fromRGB(255, 215, 0), 0.5)
            end
        end

    -- 2. GIGACHAD MEWING
    elseif fId == "Mewing" then
        if slot == "base" then
            -- Mewing Stare
            createBeamLine(pos + Vector3.new(0, 2, 0), pos + lookVector * 28 + Vector3.new(0, 2, 0), Color3.fromRGB(0, 210, 255), 0.6, 0.35)
            JuiceEffects.play3DSound("laser", pos, 0.8)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🤫 MEWING STARE!", Color3.fromRGB(0, 210, 255))

        elseif slot == "tactical" then
            -- Алмазный Подбородок
            createPillarOfLight(pos, 7, 3.5, Color3.fromRGB(180, 240, 255), 0.5)
            JuiceEffects.play3DSound("parry", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "💎 АЛМАЗНЫЙ ПОДБОРОДОК!", Color3.fromRGB(0, 230, 255))

        elseif slot == "ultimate" then
            -- Bye Bye Shockwave
            createShockwaveRing(pos, 35, Color3.fromRGB(0, 220, 255), 0.7)
            JuiceEffects.play3DSound("slam", pos, 1.1)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🤫🧏 BYE BYE!", Color3.fromRGB(0, 240, 255))
            if isSelf then JuiceEffects.screenShake(0.8, 0.5) end

        elseif slot == "special" then
            -- Looksmaxing Flash
            createShockwaveRing(pos, 22, Color3.fromRGB(255, 255, 255), 0.3)
            createPillarOfLight(pos, 16, 6, Color3.fromRGB(0, 220, 255), 0.4)
            JuiceEffects.play3DSound("magic", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "✨ LOOKSMAXING FLASH!", Color3.fromRGB(255, 255, 255))
            if isSelf then JuiceEffects.screenFlash(Color3.fromRGB(255, 255, 255), 0.3) end

        elseif slot == "mobility" then
            -- Гигачад Рывок
            createBeamLine(pos, pos + lookVector * 26, Color3.fromRGB(0, 210, 255), 1.0, 0.3)
            JuiceEffects.play3DSound("dash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🗿 ГИГАЧАД ТАРАН!", Color3.fromRGB(0, 210, 255))
            if isSelf then JuiceEffects.fovPulse(14, 0.35) end

        elseif slot == "godmode" then
            -- Альфа Доминация
            createPillarOfLight(pos, 50, 18, Color3.fromRGB(0, 220, 255), 1.4)
            createShockwaveRing(pos, 50, Color3.fromRGB(255, 255, 255), 1.0)
            JuiceEffects.play3DSound("fanfare", pos, 1.5)
            JuiceEffects.play3DSound("slam", pos, 1.3)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "👑 АЛЬФА ДОМИНАЦИЯ!", Color3.fromRGB(0, 220, 255))
            if isSelf then
                JuiceEffects.screenShake(1.3, 0.8)
                JuiceEffects.screenFlash(Color3.fromRGB(0, 220, 255), 0.5)
            end
        end

    -- 3. PATRICK SIGMA
    elseif fId == "Sigma" then
        if slot == "base" then
            -- Phonk Rage
            createPillarOfLight(pos, 8, 4, Color3.fromRGB(231, 76, 60), 0.5)
            JuiceEffects.play3DSound("powerup", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🎧 PHONK RAGE!", Color3.fromRGB(231, 76, 60))

        elseif slot == "tactical" then
            -- Сигма Парирование
            createShockwaveRing(pos, 10, Color3.fromRGB(20, 20, 20), 0.4)
            JuiceEffects.play3DSound("parry", pos, 1.1)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🍷 СИГМА ПАРИРОВАНИЕ!", Color3.fromRGB(231, 76, 60))

        elseif slot == "ultimate" then
            -- Сигма Доминация
            createShockwaveRing(pos, 35, Color3.fromRGB(200, 20, 20), 0.7)
            createPillarOfLight(pos, 20, 7, Color3.fromRGB(231, 76, 60), 0.7)
            JuiceEffects.play3DSound("slam", pos, 1.2)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🍷 ИСТИННЫЙ СИГМА!", Color3.fromRGB(231, 76, 60))
            if isSelf then JuiceEffects.screenShake(0.8, 0.5) end

        elseif slot == "special" then
            -- Lone Wolf Grindset
            createShockwaveRing(pos, 14, Color3.fromRGB(40, 40, 40), 0.5)
            JuiceEffects.play3DSound("teleport", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🐺 LONE WOLF GRINDSET!", Color3.fromRGB(180, 180, 180))

        elseif slot == "mobility" then
            -- Теневой Шаг
            createBeamLine(pos, pos + lookVector * 28, Color3.fromRGB(80, 20, 20), 0.8, 0.25)
            JuiceEffects.play3DSound("teleport", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "⚡ ТЕНЕВОЙ ШАГ!", Color3.fromRGB(231, 76, 60))
            if isSelf then JuiceEffects.fovPulse(16, 0.3) end

        elseif slot == "godmode" then
            -- Brazilian Phonk Overload
            createPillarOfLight(pos, 45, 15, Color3.fromRGB(255, 30, 30), 1.2)
            createShockwaveRing(pos, 45, Color3.fromRGB(150, 0, 0), 1.0)
            JuiceEffects.play3DSound("electric", pos, 1.4)
            JuiceEffects.play3DSound("slam", pos, 1.3)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "🔥 BRAZILIAN PHONK OVERLOAD!", Color3.fromRGB(255, 40, 40))
            if isSelf then
                JuiceEffects.screenShake(1.3, 0.8)
                JuiceEffects.screenFlash(Color3.fromRGB(231, 76, 60), 0.5)
            end
        end

    -- 4. FANUM TAX
    elseif fId == "FanumTax" then
        if slot == "base" then
            -- Tax Snatch
            createBeamLine(pos, pos + lookVector * 24, Color3.fromRGB(241, 196, 15), 0.6, 0.3)
            JuiceEffects.play3DSound("snatch", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "💸 FANUM TAX!", Color3.fromRGB(241, 196, 15))

        elseif slot == "tactical" then
            -- Ловушка Фастфуда
            createShockwaveRing(pos, 12, Color3.fromRGB(230, 126, 34), 0.5)
            JuiceEffects.play3DSound("explosion", pos, 0.8)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🍔 ЛОВУШКА ФАСТФУДА!", Color3.fromRGB(230, 126, 34))

        elseif slot == "ultimate" then
            -- Великий Налоговый Аудит
            createShockwaveRing(pos, 35, Color3.fromRGB(241, 196, 15), 0.8)
            createPillarOfLight(pos, 22, 8, Color3.fromRGB(241, 196, 15), 0.8)
            JuiceEffects.play3DSound("cash", pos, 1.3)
            JuiceEffects.play3DSound("slam", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "💰 НАЛОГОВЫЙ АУДИТ!", Color3.fromRGB(255, 215, 0))
            if isSelf then JuiceEffects.screenShake(0.8, 0.5) end

        elseif slot == "special" then
            -- Fries Carpet Bomb
            for i = 1, 4 do
                task.delay((i - 1) * 0.1, function()
                    local offset = Vector3.new((math.random() - 0.5) * 16, 0, (math.random() - 0.5) * 16)
                    createShockwaveRing(pos + offset, 8, Color3.fromRGB(241, 196, 15), 0.3)
                    JuiceEffects.play3DSound("explosion", pos + offset, 0.7)
                end)
            end
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "🍟 FRIES CARPET BOMB!", Color3.fromRGB(241, 196, 15))

        elseif slot == "mobility" then
            -- Cola Rocket Jump
            createPillarOfLight(pos, 12, 3, Color3.fromRGB(120, 60, 20), 0.4)
            JuiceEffects.play3DSound("splash", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🥤 COLA ROCKET JUMP!", Color3.fromRGB(200, 100, 30))
            if isSelf then JuiceEffects.fovPulse(15, 0.4) end

        elseif slot == "godmode" then
            -- Мега-Фанум Пиршество (Падение гигантской золотой пиццы)
            spawnFallingSkyProp(pos, function()
                local pizza = Instance.new("Part")
                pizza.Shape = Enum.PartType.Cylinder
                pizza.Size = Vector3.new(1.5, 18, 18)
                pizza.CFrame = CFrame.Angles(0, 0, math.rad(90))
                pizza.Material = Enum.Material.Neon
                pizza.Color = Color3.fromRGB(241, 196, 15)
                return pizza
            end, function()
                createShockwaveRing(pos, 45, Color3.fromRGB(241, 196, 15), 1.0)
                createPillarOfLight(pos, 35, 12, Color3.fromRGB(255, 140, 0), 1.0)
                JuiceEffects.play3DSound("slam", pos, 1.5)
                JuiceEffects.play3DSound("cash", pos, 1.4)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "🍕 МЕГА-ФАНУМ ПИРШЕСТВО!", Color3.fromRGB(255, 215, 0))
                if isSelf then
                    JuiceEffects.screenShake(1.3, 0.8)
                    JuiceEffects.screenFlash(Color3.fromRGB(241, 196, 15), 0.5)
                end
            end, 50)
        end

    -- 5. GRIMACE SHAKE
    elseif fId == "Grimace" then
        if slot == "base" then
            -- Grimace Cloud
            createShockwaveRing(pos, 16, Color3.fromRGB(142, 68, 173), 0.6)
            JuiceEffects.play3DSound("splash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🥤 GRIMACE CLOUD!", Color3.fromRGB(155, 89, 182))

        elseif slot == "tactical" then
            -- Коктейльная Лужа
            createShockwaveRing(pos, 14, Color3.fromRGB(120, 40, 150), 0.5)
            JuiceEffects.play3DSound("splash", pos, 0.8)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🟣 КОКТЕЙЛЬНАЯ ЛУЖА!", Color3.fromRGB(142, 68, 173))

        elseif slot == "ultimate" then
            -- Катаклизм Гримаса
            createShockwaveRing(pos, 35, Color3.fromRGB(142, 68, 173), 0.8)
            createPillarOfLight(pos, 25, 8, Color3.fromRGB(155, 89, 182), 0.8)
            JuiceEffects.play3DSound("slam", pos, 1.1)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "💜 КАТАКЛИЗМ ГРИМАСА!", Color3.fromRGB(168, 85, 247))
            if isSelf then JuiceEffects.screenShake(0.8, 0.5) end

        elseif slot == "special" then
            -- Grimace Birthday Eclipse
            createShockwaveRing(pos, 25, Color3.fromRGB(80, 20, 100), 0.6)
            createPillarOfLight(pos, 15, 6, Color3.fromRGB(142, 68, 173), 0.6)
            JuiceEffects.play3DSound("magic", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "🎂 HAPPY BIRTHDAY GRIMACE!", Color3.fromRGB(168, 85, 247))
            if isSelf then JuiceEffects.screenFlash(Color3.fromRGB(142, 68, 173), 0.4) end

        elseif slot == "mobility" then
            -- Слизистый Прыжок
            createShockwaveRing(pos, 10, Color3.fromRGB(155, 89, 182), 0.4)
            JuiceEffects.play3DSound("dash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🟣 СЛИЗИСТЫЙ ПРЫЖОК!", Color3.fromRGB(155, 89, 182))
            if isSelf then JuiceEffects.fovPulse(14, 0.35) end

        elseif slot == "godmode" then
            -- Ритуал 23 Июня (Фиолетовые щупальца бездны)
            createPillarOfLight(pos, 45, 14, Color3.fromRGB(100, 10, 130), 1.2)
            createShockwaveRing(pos, 45, Color3.fromRGB(142, 68, 173), 1.0)
            JuiceEffects.play3DSound("slam", pos, 1.4)
            JuiceEffects.play3DSound("electric", pos, 1.2)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "💀 РИТУАЛ 23 ИЮНЯ!", Color3.fromRGB(168, 85, 247))
            if isSelf then
                JuiceEffects.screenShake(1.3, 0.8)
                JuiceEffects.screenFlash(Color3.fromRGB(142, 68, 173), 0.5)
            end
        end

    -- 6. CASEOH GRAVITY
    elseif fId == "CaseOh" then
        if slot == "base" then
            -- CaseOh Slam
            createShockwaveRing(pos, 20, Color3.fromRGB(230, 126, 34), 0.5)
            JuiceEffects.play3DSound("slam", pos, 1.1)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "💥 CASEOH SLAM!", Color3.fromRGB(230, 126, 34))
            if isSelf then JuiceEffects.screenShake(0.6, 0.35) end

        elseif slot == "tactical" then
            -- Горизонт Событий
            createShockwaveRing(pos, 18, Color3.fromRGB(20, 20, 25), 0.6)
            JuiceEffects.play3DSound("magic", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🕳️ ГОРИЗОНТ СОБЫТИЙ!", Color3.fromRGB(230, 126, 34))

        elseif slot == "ultimate" then
            -- Метеорит КейсОха
            spawnFallingSkyProp(pos + lookVector * 18, function()
                local met = Instance.new("Part")
                met.Shape = Enum.PartType.Ball
                met.Size = Vector3.new(10, 10, 10)
                met.Material = Enum.Material.Neon
                met.Color = Color3.fromRGB(230, 126, 34)
                return met
            end, function()
                createShockwaveRing(pos + lookVector * 18, 35, Color3.fromRGB(230, 126, 34), 0.8)
                JuiceEffects.play3DSound("meteor", pos, 1.3)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 6, 0), "☄️ МЕТЕОРИТ КЕЙСОХА!", Color3.fromRGB(230, 126, 34))
                if isSelf then JuiceEffects.screenShake(1.0, 0.6) end
            end, 60)

        elseif slot == "special" then
            -- BAN HAMMER METEOR (Падение гигантского банхаммера)
            spawnFallingSkyProp(pos + lookVector * 12, function()
                local hammer = Instance.new("Part")
                hammer.Size = Vector3.new(8, 4, 12)
                hammer.Material = Enum.Material.Neon
                hammer.Color = Color3.fromRGB(231, 76, 60)
                return hammer
            end, function()
                createShockwaveRing(pos + lookVector * 12, 30, Color3.fromRGB(231, 76, 60), 0.7)
                JuiceEffects.play3DSound("hammer", pos, 1.4)
                JuiceEffects.play3DSound("slam", pos, 1.2)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🔨 YOU ARE BANNED!", Color3.fromRGB(255, 50, 50))
                if isSelf then JuiceEffects.screenShake(1.0, 0.5) end
            end, 55)

        elseif slot == "mobility" then
            -- Вафельный Каток
            createBeamLine(pos, pos + lookVector * 28, Color3.fromRGB(230, 126, 34), 1.4, 0.35)
            JuiceEffects.play3DSound("dash", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🧇 ВАФЕЛЬНЫЙ КАТОК!", Color3.fromRGB(230, 126, 34))
            if isSelf then JuiceEffects.fovPulse(16, 0.4) end

        elseif slot == "godmode" then
            -- Смещение Земной Оси
            createPillarOfLight(pos, 50, 20, Color3.fromRGB(230, 126, 34), 1.4)
            createShockwaveRing(pos, 60, Color3.fromRGB(255, 80, 0), 1.2)
            JuiceEffects.play3DSound("slam", pos, 1.6)
            JuiceEffects.play3DSound("meteor", pos, 1.5)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "🪐 СМЕЩЕНИЕ ОСИ ЗЕМЛИ!", Color3.fromRGB(255, 120, 0))
            if isSelf then
                JuiceEffects.screenShake(1.6, 1.0)
                JuiceEffects.screenFlash(Color3.fromRGB(230, 126, 34), 0.6)
            end
        end

    -- 7. RIZZLER & GRONK
    elseif fId == "Rizzler" then
        if slot == "base" then
            -- Unspoken Rizz
            createShockwaveRing(pos, 16, Color3.fromRGB(255, 105, 180), 0.5)
            JuiceEffects.play3DSound("chime", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "❤️ UNSPOKEN RIZZ!", Color3.fromRGB(255, 105, 180))

        elseif slot == "tactical" then
            -- Ризз Гипноз
            createShockwaveRing(pos, 14, Color3.fromRGB(255, 20, 147), 0.5)
            createPillarOfLight(pos, 8, 3, Color3.fromRGB(255, 105, 180), 0.5)
            JuiceEffects.play3DSound("magic", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🌀 РИЗЗ ГИПНОЗ!", Color3.fromRGB(255, 105, 180))

        elseif slot == "ultimate" then
            -- W Rizz Ураган
            createShockwaveRing(pos, 35, Color3.fromRGB(255, 105, 180), 0.8)
            createPillarOfLight(pos, 22, 7, Color3.fromRGB(255, 20, 147), 0.8)
            JuiceEffects.play3DSound("chime", pos, 1.2)
            JuiceEffects.play3DSound("slam", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "💖 W RIZZ УРАГАН!", Color3.fromRGB(255, 105, 180))
            if isSelf then JuiceEffects.screenShake(0.7, 0.5) end

        elseif slot == "special" then
            -- Cupid's Brainrot Arrow
            createBeamLine(pos + Vector3.new(0, 2, 0), pos + lookVector * 32 + Vector3.new(0, 2, 0), Color3.fromRGB(255, 20, 147), 0.7, 0.35)
            JuiceEffects.play3DSound("laser", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4.5, 0), "💘 СТРЕЛА АМУРА!", Color3.fromRGB(255, 105, 180))

        elseif slot == "mobility" then
            -- Лепестковый Блинк
            createShockwaveRing(pos, 12, Color3.fromRGB(255, 182, 193), 0.35)
            JuiceEffects.play3DSound("teleport", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "🌸 ЛЕПЕСТКОВЫЙ БЛИНК!", Color3.fromRGB(255, 105, 180))
            if isSelf then JuiceEffects.fovPulse(14, 0.3) end

        elseif slot == "godmode" then
            -- Аура Гипер-Ризза за 999+
            createPillarOfLight(pos, 45, 16, Color3.fromRGB(255, 20, 147), 1.2)
            createShockwaveRing(pos, 45, Color3.fromRGB(255, 105, 180), 1.0)
            JuiceEffects.play3DSound("fanfare", pos, 1.3)
            JuiceEffects.play3DSound("chime", pos, 1.3)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "💋 MAXIMUM HYPER-RIZZ!", Color3.fromRGB(255, 20, 147))
            if isSelf then
                JuiceEffects.screenShake(1.2, 0.8)
                JuiceEffects.screenFlash(Color3.fromRGB(255, 105, 180), 0.5)
            end
        end

    -- 8. TUNGTUNG SAHUR
    elseif fId == "TungTung" then
        if slot == "base" then
            -- Барабанный Дробь
            createShockwaveRing(pos, 16, Color3.fromRGB(46, 204, 113), 0.4)
            JuiceEffects.play3DSound("hammer", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🥁 БАРАБАННЫЙ ДРОБЬ!", Color3.fromRGB(46, 204, 113))

        elseif slot == "tactical" then
            -- Рассветный Щит
            createPillarOfLight(pos, 7, 3.5, Color3.fromRGB(39, 174, 96), 0.5)
            JuiceEffects.play3DSound("anvil", pos, 1.0)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 4, 0), "🛡️ РАССВЕТНЫЙ ЩИТ!", Color3.fromRGB(46, 204, 113))

        elseif slot == "ultimate" then
            -- Sahur Землетрясение
            createShockwaveRing(pos, 35, Color3.fromRGB(46, 204, 113), 0.7)
            JuiceEffects.play3DSound("slam", pos, 1.2)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🔨 SAHUR ЗЕМЛЕТРЯСЕНИЕ!", Color3.fromRGB(46, 204, 113))
            if isSelf then JuiceEffects.screenShake(0.8, 0.5) end

        elseif slot == "special" then
            -- Tungsten Anvil Drop (Падение вольфрамовой наковальни)
            spawnFallingSkyProp(pos + lookVector * 12, function()
                local anvil = Instance.new("Part")
                anvil.Size = Vector3.new(6, 4, 4)
                anvil.Material = Enum.Material.DiamondPlate
                anvil.Color = Color3.fromRGB(80, 80, 90)
                return anvil
            end, function()
                createShockwaveRing(pos + lookVector * 12, 25, Color3.fromRGB(46, 204, 113), 0.6)
                JuiceEffects.play3DSound("anvil", pos, 1.4)
                JuiceEffects.play3DSound("slam", pos, 1.1)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 5, 0), "🔔 ВОЛЬФРАМОВАЯ НАКОВАЛЬНЯ!", Color3.fromRGB(46, 204, 113))
                if isSelf then JuiceEffects.screenShake(0.9, 0.45) end
            end, 50)

        elseif slot == "mobility" then
            -- Реактивный Молот
            createBeamLine(pos, pos + lookVector * 26, Color3.fromRGB(46, 204, 113), 1.2, 0.3)
            JuiceEffects.play3DSound("dash", pos, 0.9)
            JuiceEffects.showFloatingText(pos + Vector3.new(0, 3.5, 0), "⚡ РЕАКТИВНЫЙ МОЛОТ!", Color3.fromRGB(46, 204, 113))
            if isSelf then JuiceEffects.fovPulse(14, 0.35) end

        elseif slot == "godmode" then
            -- Молот Бога Рассвета
            spawnFallingSkyProp(pos, function()
                local godHammer = Instance.new("Part")
                godHammer.Size = Vector3.new(10, 6, 6)
                godHammer.Material = Enum.Material.Neon
                godHammer.Color = Color3.fromRGB(46, 204, 113)
                return godHammer
            end, function()
                createPillarOfLight(pos, 50, 18, Color3.fromRGB(46, 204, 113), 1.3)
                createShockwaveRing(pos, 50, Color3.fromRGB(39, 174, 96), 1.1)
                JuiceEffects.play3DSound("slam", pos, 1.5)
                JuiceEffects.play3DSound("electric", pos, 1.3)
                JuiceEffects.showFloatingText(pos + Vector3.new(0, 7, 0), "⚡ МОЛОТ БОГА РАССВЕТА!", Color3.fromRGB(46, 204, 113))
                if isSelf then
                    JuiceEffects.screenShake(1.4, 0.9)
                    JuiceEffects.screenFlash(Color3.fromRGB(46, 204, 113), 0.5)
                end
            end, 55)
        end
    end
end

return AbilityVFX
