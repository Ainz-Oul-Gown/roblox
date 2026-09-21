---
name: roblox-ability-combat-system
description: >-
  Промышленный шаблон боевой системы и способностей в Roblox: полный цикл активации,
  пространственные хитбоксы (Raycast, OverlapParams, FastCast), воздействие на игроков
  (урон, отбрасывание, оглушение/регдолл) и физику мира, сочные визуальные эффекты (VFX),
  3D/2D пространственный звук (SFX) и отклик (CameraShake, FOV pulse, 3D урон).
---

# Roblox Ability & Combat System Standards

Стандарт разработки сочных, отзывчивых и защищенных от читеров способностей, магии и боевых механик в Roblox.

---

## 1. Архитектурный цикл способности

Любая способность должна следовать строгому конвейеру:

```text
[Клиент] 
  1. Нажатие клавиши (Q/E/R/Mouse1)
  2. Проверка локального кулдауна
  3. Оптимистичный отклик (звук замаха, анимация кастера)
  4. Отправка пакета на сервер -> RemoteEvent:FireServer(abilityId, targetData)

[Сервер]
  5. Валидация кулдауна и состояния (жив ли кастер, не в стане ли он)
  6. Проверка дистанции и таргетинга
  7. Расчет хитбокса (Melee / Raycast / AoE)
  8. Воздействие на цель (урон, физический импульс, дебафф)
  9. Воздействие на мир (импульс объектов, разрушение)
  10. Репликация всем клиентам вокруг -> AbilityVFXEvent:FireAllClients(...)

[Все клиенты в радиусе видимости]
  11. Спавн 3D VFX (частицы, световые кольца, лучи, метеориты)
  12. Воспроизведение 3D SFX в точке удара с затуханием (RollOff)
  13. Тряска камеры (CameraShake) и всплывающий урон (Damage Numbers)
```

---

## 2. Детекция попаданий и хитбоксы

### А. AoE и ближний бой (Spatial Query - `GetPartBoundsInRadius`):
```lua
--!strict
local function PerformAoEAttack(caster: Model, center: Vector3, radius: number, damage: number, knockbackForce: number)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { caster }

    local parts = workspace:GetPartBoundsInRadius(center, radius, overlapParams)
    local hitHumanoids: { [Humanoid]: boolean } = {}

    for _, part in parts do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model ~= caster then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?

            if humanoid and rootPart and humanoid.Health > 0 and not hitHumanoids[humanoid] then
                hitHumanoids[humanoid] = true

                -- 1. Воздействие: Урон
                humanoid:TakeDamage(damage)

                -- 2. Воздействие: Отбрасывание (Knockback)
                local pushDirection = (rootPart.Position - center).Unit + Vector3.new(0, 0.5, 0)
                rootPart:ApplyImpulse(pushDirection * knockbackForce * rootPart.AssemblyMass)

                -- 3. Воздействие: Кратковременный стан
                ApplyStun(humanoid, 0.8)
            end
        end
    end
end
```

### Б. Снаряды и магия дальнего боя (FastCast / Физический луч):
Для магии и выстрелов используйте Raycast с шагом по времени или библиотеку **FastCastRedux**, рассчитывающую баллистику, гравитацию и пробитие стен.

---

## 3. Воздействие на физику мира

Чтобы атака ощущалась мощной, взрывы и удары должны воздействовать на незакрепленные объекты окружения:
```lua
local function ImpactWorldPhysics(epicenter: Vector3, explosionRadius: number, blastForce: number)
    local parts = workspace:GetPartBoundsInRadius(epicenter, explosionRadius)
    for _, part in parts do
        if part:IsA("BasePart") and not part.Anchored and part.AssemblyMass < 500 then
            local dir = (part.Position - epicenter).Unit
            local dist = (part.Position - epicenter).Magnitude
            local falloff = 1 - (dist / explosionRadius)
            part:ApplyImpulse(dir * blastForce * falloff * part.AssemblyMass)
        end
    end
end
```

---

## 4. Сочные визуальные эффекты (VFX)

При репликации VFX на клиенте используйте процедурные кольца, неоновые вспышки и TweenService:

```lua
--!strict
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local function SpawnShockwaveRing(position: Vector3, color: Color3, maxRadius: number)
    local ring = Instance.new("Part")
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = 0.2
    ring.Anchored = true
    ring.CanCollide = false
    ring.Size = Vector3.new(0.5, 2, 2)
    ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = workspace

    local tweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
    local tween = TweenService:Create(ring, tweenInfo, {
        Size = Vector3.new(0.1, maxRadius * 2, maxRadius * 2),
        Transparency = 1,
    })

    tween:Play()
    Debris:AddItem(ring, 0.5)
end
```

---

## 5. Пространственный 3D/2D звук (SFX)

1. **3D Пространственный звук для окружающих игроков**:
   Звук спавнится в невидимом `Attachment` в точке удара с `RollOffMode.InverseTapered`, `RollOffMinDistance = 10`, `RollOffMaxDistance = 120`.
2. **2D Отклик для кастера**:
   Кастер мгновенно слышит громкий и четкий звук через `SoundService` без задержки и искажений расстояния.

```lua
local function PlayAbilitySound(soundId: string, position: Vector3?, isLocalPlayer: boolean)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = 1.0

    if isLocalPlayer then
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        Debris:AddItem(sound, 3)
    elseif position then
        local attach = Instance.new("Attachment")
        attach.WorldPosition = position
        attach.Parent = workspace.Terrain

        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.RollOffMinDistance = 15
        sound.RollOffMaxDistance = 150
        sound.Parent = attach
        sound:Play()

        Debris:AddItem(attach, 3)
    end
end
```

---

## 6. Juice & Game Feel: Тряска экрана и всплывающий урон

* **CameraShake**: При сильных ударах вызывать локальное смещение `Camera.CFrame` через шум Перлина или затухающую синусоиду:
  ```lua
  local function ShakeCamera(duration: number, intensity: number)
      task.spawn(function()
          local elapsed = 0
          while elapsed < duration do
              local dt = task.wait()
              elapsed += dt
              local damp = 1 - (elapsed / duration)
              local rotX = (math.random() - 0.5) * intensity * damp
              local rotY = (math.random() - 0.5) * intensity * damp
              workspace.CurrentCamera.CFrame *= CFrame.Angles(math.rad(rotX), math.rad(rotY), 0)
          end
      end)
  end
  ```
* **Всплывающий 3D-урон (Damage Indicator)**: Спавнить над головой жертвы `BillboardGui` с желтым/красным числом, анимируя подъем вверх на 4 стада и затухание прозрачности за 0.7с.
