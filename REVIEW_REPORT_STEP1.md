# 🛡️ Независимый отчет о код-ревью: Шаг 1 (JuiceEffects AAA Overhaul)

**Дата проведения ревью**: 22 сентября 2026 г.  
**Роль**: Независимый ведущий архитектор / код-ревьювер  
**Проверяемый коммит**: `19ed09a` (*feat(vfx): Step 1 - AAA JuiceEffects overhaul with trauma shake, hitstop, light bursts, and audio jitter*)  
**Проверяемые файлы**:
- `src/client/JuiceEffects.luau`
- `tests/abilityVfxSfx.test.js`
- `implementation_plan.md`
- `.ai/ARCHITECTURE.md`

---

## 1. Резюме ревью (Executive Summary)

| Критерий | Оценка | Статус |
| :--- | :---: | :---: |
| **Архитектурная чистота и стиль Luau** | 9.0 / 10 | ✅ Отлично |
| **Тактильный отклик и кинематографичность (Juice)** | 9.5 / 10 | 🌟 Превосходно |
| **Устойчивость к граничным условиям (Edge Cases)** | 7.0 / 10 | ⚠️ Требуются доработки |
| **Управление памятью и Debris (Zero-Leak)** | 9.5 / 10 | ✅ Отлично |
| **Тестовое покрытие и CI/CD** | 8.5 / 10 | ✅ Пройдено |
| **ИТОГОВЫЙ ВЕРДИКТ** | **8.7 / 10** | **ПРИНЯТО С ЗАМЕЧАНИЯМИ** |

Первый этап плана модернизации боевой системы успешно заложил фундамент кинематографичности уровня современных AAA-тайкунов Roblox (*The Strongest Battlegrounds*, *Jujutsu Shenanigans*). Внедрены нелинейное затухание травмы ($Trauma^2$), микрофриз при ударах (Hitstop), подсветка пораженной цели (Impact Flash), импульсный динамический свет и акустический джиттер.

Вместе с тем в ходе независимого анализа логики выявлены **2 критических замечания** (гонка сброса скорости в `hitstop` и смещение нуля шума в `traumaShake`), а также **1 архитектурная неточность** (`screenBloomFlash`).

---

## 2. Покомпонентный детальный аудит

### 2.1. Физическая тряска камеры на шуме Перлина (`traumaShake`, `addTrauma`)
```luau
-- lines 134-154 in src/client/JuiceEffects.luau
activeShakeThread = task.spawn(function()
    while currentTrauma > 0.01 do
        local shakeIntensity = currentTrauma * currentTrauma
        local t = tick() * 32

        local rx = (math.noise(t, 0, seed) - 0.5) * 2 * rotLimit * shakeIntensity
        local ry = (math.noise(0, t, seed) - 0.5) * 2 * rotLimit * shakeIntensity
        local rz = (math.noise(seed, t, 0) - 0.5) * 2 * (rotLimit * 0.5) * shakeIntensity

        local px = (math.noise(t + 50, 0, seed) - 0.5) * 2 * posLimit * shakeIntensity
        local py = (math.noise(0, t + 50, seed) - 0.5) * 2 * posLimit * shakeIntensity

        camera.CFrame = camera.CFrame * CFrame.new(px, py, 0) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
        currentTrauma = math.clamp(currentTrauma - 0.045, 0, 1)
        task.wait(0.016)
    end
    currentTrauma = 0
    activeShakeThread = nil
end)
```
- **Плюсы**:
  - Квадратичный закон $Intensity = Trauma^2$ обеспечивает естественный спад кинетической энергии.
  - Корректная отмена предыдущего потока (`task.cancel(activeShakeThread)`) при сохранении накопленной травмы через `addTrauma`.
  - Разделение осей шума Перлина (разные аргументы `(t, 0, seed)`, `(0, t, seed)` и т.д.) исключает диагональный синхронный сдвиг.
- **Найденные дефекты и риски**:
  1. ⚠️ **Асимметричное смещение нуля шума (Noise Bias)**: В Roblox Luau стандартная функция `math.noise(x, y, z)` уже возвращает центрированные значения в диапазоне от `-0.5` до `+0.5`. Конструкция `(math.noise(...) - 0.5) * 2` сдвигает рабочий диапазон в `[-2.0, 0.0]` (строго в отрицательную область), из-за чего камера при тряске систематически кренится и съезжает вниз/влево, вместо симметричной вибрации относительно центра прицела.  
     *Рекомендация*: Использовать `math.noise(...) * 2 * rotLimit * shakeIntensity`.
  2. ⚠️ **Рендер-цикл через `task.wait(0.016)`**: Изменение `camera.CFrame` внутри асинхронного `task.spawn` с `task.wait(0.016)` конкурирует со стандартным скриптом камеры Roblox (`PlayerModule.CameraModule`), работающим на этапе `RunService:BindToRenderStep`. При плавающем FPS это может приводить к микро-статтерам (дрожанию кадров).  
     *Рекомендация*: В перспективе привязать смещение к RenderStepped через аддитивный CFrame-офсет.

---

### 2.2. Направленный толчок камеры (`cameraKick`)
```luau
-- lines 108-117 in src/client/JuiceEffects.luau
function JuiceEffects.cameraKick(direction: Vector3, strength: number?)
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local kickStr = strength or 0.5
    local dirNorm = if direction.Magnitude > 0 then direction.Unit else Vector3.new(0, 1, 0)
    local kickAngleX = -dirNorm.Y * kickStr * 1.5
    local kickAngleY = dirNorm.X * kickStr * 1.5

    camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(kickAngleX), math.rad(kickAngleY), 0)
end
```
- **Плюсы**: Безопасная нормализация вектора с защитой от деления на 0 при нулевой магнитуде (`if direction.Magnitude > 0`). Физически верные знаки углов Эйлера (взрыв снизу откидывает угол обзора вверх).
- **Замечание**: Однократный сдвиг `camera.CFrame` без пружины (Spring) будет сброшен контроллером камеры игрока на следующем рендер-кадре. Функция дает мгновенный отклик, но наибольший кинематографический эффект достигается при сочетании с `traumaShake`.

---

### 2.3. Движок хитстопа (`hitstop`)
```luau
-- lines 168-183 in src/client/JuiceEffects.luau
function JuiceEffects.hitstop(duration: number?)
    local dur = duration or 0.05
    local char = localPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local origWalkSpeed = humanoid.WalkSpeed
    humanoid.WalkSpeed = 0

    task.delay(dur, function()
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = origWalkSpeed
        end
    end)
end
```
- **Плюсы**: Достигнут классический файтинговый эффект сокрушительного веса удара (0.05с микро-пауза).
- 🚨 **КРИТИЧЕСКИЙ БАГ: Гонка состояний при серии ударов (Speed Zero-Lock)**:
  Если игрок наносит комбо-удар или получает урон повторно в течение активного окна хитстопа (0.05с):
  1. Удар 1: `origWalkSpeed = 16`, `WalkSpeed` устанавливается в `0`.
  2. Через 0.02с происходит Удар 2: `origWalkSpeed` считывает текущий `humanoid.WalkSpeed`, который **уже равен 0**!
  3. Через 0.03с завершается Удар 1: `WalkSpeed` восстанавливается в `16`.
  4. Через 0.02с завершается Удар 2: `WalkSpeed` устанавливается в запомненный `origWalkSpeed` (то есть **0**)!
  5. **Результат**: Игрок навсегда теряет способность двигаться до респавна!
  *Рекомендация*: Ввести модульную переменную `activeHitstopCount: number` или проверять `if humanoid.WalkSpeed > 0 then cachedWalkSpeed = humanoid.WalkSpeed end`, не затирая оригинальную скорость нулем.

---

### 2.4. Реакция цели на урон (`impactFlash`)
```luau
-- lines 186-210 in src/client/JuiceEffects.luau
function JuiceEffects.impactFlash(targetChar: Model, color: Color3?, duration: number?)
    if not targetChar or not targetChar:IsA("Model") then return end
    local dur = duration or 0.08
    local flashColor = color or Color3.fromRGB(255, 255, 255)

    local existingHighlight = targetChar:FindFirstChild("ImpactFlashHighlight")
    if existingHighlight then
        existingHighlight:Destroy()
    end
    ...
    tween:Play()
    Debris:AddItem(highlight, dur + 0.02)
end
```
- **Плюсы**:
  - Строгая проверка `targetChar:IsA("Model")`.
  - Принудительное удаление старого `ImpactFlashHighlight` гарантирует соблюдение жесткого лимита движка Roblox (максимум 31 активный `Highlight` на весь клиент).
  - Плавное угасание `FillTransparency` и `OutlineTransparency` через `TweenService`.
  - Гарантированная очистка через `Debris:AddItem`.
- **Оценка**: 10 / 10. Чистый, безопасный промышленный код.

---

### 2.5. Динамический импульсный свет (`spawnLightBurst`)
```luau
-- lines 213-240 in src/client/JuiceEffects.luau
function JuiceEffects.spawnLightBurst(pos: Vector3, color: Color3, brightness: number?, radius: number?, duration: number?)
    ...
    pointLight.Shadows = true
    ...
    local tween = TweenService:Create(pointLight, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Brightness = 0,
        Range = r * 1.3,
    })
    tween:Play()
    Debris:AddItem(lightPart, dur + 0.05)
end
```
- **Плюсы**: Создание объема на базе Future Lighting. Сочетание расширения радиуса (`Range = r * 1.3`) с экспоненциальным затуханием яркости до 0 создает реалистичную световую вспышку взрыва.
- **Предостережение по производительности**: Включение `Shadows = true` на точечных источниках света создает нагрузку на мобильных GPU при массовых сражениях. В Шаге 2 при интеграции в `AbilityVFX` необходимо строго соблюдать дистанционный отсев (LOD > 120 studs).

---

### 2.6. Пост-процессинг вспышка (`screenBloomFlash`)
```luau
-- lines 243-260 in src/client/JuiceEffects.luau
function JuiceEffects.screenBloomFlash(color: Color3, duration: number?)
    local dur = duration or 0.18
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
    local tween = TweenService:Create(bloom, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Intensity = 0,
    })
    tween:Play()
end
```
- **Плюсы**: Использование синглтона в `Lighting` (`CombatBloomPulse`) исключает утечки объектов.
- ⚠️ **Замечание по API**: Параметр `color: Color3` объявлен в сигнатуре функции, однако стандартный класс Roblox `BloomEffect` не имеет свойства цвета (только `Intensity`, `Size`, `Threshold`). В текущей реализации параметр `color` полностью игнорируется.  
  *Рекомендация*: Либо удалить неиспользуемый параметр `color`, либо дополнительно анимировать оттенок через `ColorCorrectionEffect`.

---

### 2.7. Аудио-джиттер высоты тона (`PlaybackSpeed`)
```luau
sound.PlaybackSpeed = math.random(94, 106) / 100
```
- Внедрен в `playSound` и `play3DSound`.
- Обеспечивает диапазон $\pm 6\%$ от базовой частоты звука.
- Полностью решает проблему слуховой усталости ("machine-gun effect") при спаме способностей.
- Оценка: 10 / 10.

---

## 3. Анализ тестов и документации

1. **Модульные тесты (`tests/abilityVfxSfx.test.js`)**:
   - Тест `JuiceEffects: exports comprehensive sound catalog and dynamic screen effects` успешно дополнен валидацией новых функций: `traumaShake`, `cameraKick`, `hitstop`, `impactFlash`, `spawnLightBurst`, `screenBloomFlash`, `PlaybackSpeed`.
   - Общее количество тестов в проекте: **115 тестов** (все успешно пройдены за 1.02 сек).
   - Замечание: Тест использует проверку сигнатур через регулярные выражения/строковый поиск. Рекомендуется добавить функциональные тесты логики расчетов.
2. **Документация (`.ai/ARCHITECTURE.md`)**:
   - Раздел «Сочность и Game Feel (JuiceEffects)» актуализирован, детально описаны новые механики и параметры затухания.

---

## 4. Рекомендации к устранению перед Шагом 2

| Приоритет | Файл | Описание проблемы | Рекомендуемое исправление |
| :---: | :--- | :--- | :--- |
| **P0** | `JuiceEffects.luau` | Риск перманентной блокировки скорости игрока при комбо-хитстопах | Сохранять `cachedOriginalSpeed` только если текущий `WalkSpeed > 0`, восстанавливать по счетчику активных хитстопов |
| **P1** | `JuiceEffects.luau` | Асимметричный сдвиг камеры из-за `- 0.5` в `math.noise` | Убрать вычитание `0.5`, так как `math.noise` уже центрирован вокруг 0 |
| **P2** | `JuiceEffects.luau` | Неиспользуемый аргумент `color` в `screenBloomFlash` | Очистить сигнатуру или добавить `ColorCorrectionEffect.TintColor` |

---

## 5. Заключение

Код Шага 1 выполнен на высоком инженерном уровне, полностью соответствует стандартам `--!strict` типизации Luau и органично расширяет боевую архитектуру.

После исправления выявленных нюансов в `hitstop` и `math.noise` модуль `JuiceEffects.luau` полностью готов к интеграции в Шаг 2 (`AbilityVFX.luau` — процедурные камни земли, декали трещин, волюметрические лучи и 48 уникальных способностей фракций).
