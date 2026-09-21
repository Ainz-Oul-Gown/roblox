---
name: roblox-map-templates
description: >-
  Готовые архитектурные и процедурные 3D-шаблоны карт для Roblox (Blockouts):
  Circular Tycoon Hub (круговой остров со слотами баз и дорогами),
  Simulator Linear Zones (линейные зоны с воротами требований),
  Arena PvP Island (многоуровневая арена с рампами, укрытиями и джамп-падами),
  Obby Sectioned Course (модульная полоса препятствий из 5 этапов).
---

# Roblox Ready-Made 3D Map Templates

Так как генеративные нейросети часто ошибаются в пространственной геометрии (создают щели, перекосы и летающие в воздухе детали), данный навык содержит **строгие математические шаблоны карт (Blockouts)** с точными координатами, симметрией и автоматической привязкой к сетке.

---

## 1. Шаблон 1: `CircularTycoonHub` (Круговой хаб на 4–8 баз)

### Геометрия:
* Центральный диск острова: радиус $R = 250$, толщина 4, материал `SmoothPlastic` или `Grass`.
* Центральная площадь: $R = 60$, золотой постамент в центре $(0, 3.6, 0)$.
* Радиальные дороги: 8 дорог шириной 14 стадов от центра к каждой базе.
* Слоты баз: равномерно по формуле $X_i = R_{base} \cdot \cos(i \cdot \frac{2\pi}{N})$, $Z_i = R_{base} \cdot \sin(i \cdot \frac{2\pi}{N})$.

### Генератор кода:
```lua
--!strict
local function BuildCircularHub(numPlots: number, arenaRadius: number): Folder
    local mapFolder = Instance.new("Folder")
    mapFolder.Name = "Map_CircularHub"
    mapFolder.Parent = workspace

    -- 1. Основание острова
    local base = Instance.new("Part")
    base.Name = "IslandBase"
    base.Shape = Enum.PartType.Cylinder
    base.Size = Vector3.new(6, arenaRadius * 2 + 100, arenaRadius * 2 + 100)
    base.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
    base.Anchored = true
    base.Material = Enum.Material.Concrete
    base.Color = Color3.fromRGB(45, 45, 50)
    base.Parent = mapFolder

    -- 2. Центральная арена
    local center = Instance.new("Part")
    center.Name = "CenterPlaza"
    center.Shape = Enum.PartType.Cylinder
    center.Size = Vector3.new(0.5, 70, 70)
    center.CFrame = CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0, math.rad(90))
    center.Anchored = true
    center.Material = Enum.Material.Neon
    center.Color = Color3.fromRGB(80, 160, 255)
    center.Parent = mapFolder

    -- 3. Слоты под базы игроков
    for i = 1, numPlots do
        local angle = (i - 1) * (2 * math.pi / numPlots)
        local posX = math.cos(angle) * arenaRadius
        local posZ = math.sin(angle) * arenaRadius

        local plotPad = Instance.new("Part")
        plotPad.Name = `PlotPad_{i}`
        plotPad.Size = Vector3.new(58, 2, 78)
        plotPad.CFrame = CFrame.new(posX, 2, posZ) * CFrame.Angles(0, -angle + math.pi/2, 0)
        plotPad.Anchored = true
        plotPad.Material = Enum.Material.SmoothPlastic
        plotPad.Color = Color3.fromRGB(30, 30, 35)
        plotPad.Parent = mapFolder
    end

    return mapFolder
end
```

---

## 2. Шаблон 2: `SimulatorLinearZones` (Линейная прогрессия зон)

### Геометрия:
* Каждая зона представляет собой огороженную площадку $80 \times 100$ стадов.
* Зоны соединяются монументальными воротами требований (**Requirement Gates**), на которых отображается цена перехода (`$10,000 Cash` ➡️ `$100,000 Cash`).
* Вдоль зоны: боковые стены высотой 24 стада (игрок не может сбежать за карту), пьедесталы яиц слева, зона продажи по центру.

```lua
local function BuildSimulatorZone(zoneIndex: number, length: number): Model
    local zoneModel = Instance.new("Model")
    zoneModel.Name = `Zone_{zoneIndex}`
    local startZ = (zoneIndex - 1) * length

    -- Пол зоны
    local floor = Instance.new("Part")
    floor.Size = Vector3.new(80, 2, length)
    floor.Position = Vector3.new(0, 0, startZ + length / 2)
    floor.Anchored = true
    floor.Material = Enum.Material.Grass
    floor.Parent = zoneModel

    -- Ворота перехода
    local gate = Instance.new("Part")
    gate.Name = "ProgressionGate"
    gate.Size = Vector3.new(80, 26, 4)
    gate.Position = Vector3.new(0, 13, startZ + length)
    gate.Anchored = true
    gate.Transparency = 0.5
    gate.CanCollide = true
    gate.Material = Enum.Material.ForceField
    gate.Color = Color3.fromRGB(255, 60, 60)
    gate.Parent = zoneModel

    zoneModel.Parent = workspace
    return zoneModel
end
```

---

## 3. Шаблон 3: `ArenaPvPIsland` (Многоуровневая тактическая арена)

### Геометрия:
* **Нижний ярус**: квадрат $140 \times 140$ стадов с 4 угловыми спавнами игроков.
* **4 укрытия-пилона**: колонны $10 \times 16 \times 10$ для тактической стрельбы и укрытия от способностей.
* **Центральный возвышенный пьедестал**: высота $Y = 12$, размеры $40 \times 40$ стадов.
* **4 наклонные рампы**: ширина 12 стадов, подъем с $Y = 1$ на $Y = 12$ под комфортным углом $22^\circ$.
* **2 Джамп-пада (Launch Pads)**: зеленые платформы с неоном, подбрасывающие наступившего игрока импульсом `root:ApplyImpulse(Vector3.new(0, 1500, 0))`.

---

## 4. Шаблон 4: `ObbySectionedCourse` (Модульный паркур из 5 секций)

### 5 готовых модулей:
1. **Секция 1: Столбики (Pillars)** — 6 круглых платформ диаметром 6 стадов с расстоянием 14 стадов (комфортный одиночный прыжок).
2. **Секция 2: Неоновые исчезающие ступени (Disappearing Tiles)** — ступени с циклом прозрачности: `Transparency = 0` (CanCollide = true) ➡️ мигание 1 сек ➡️ `Transparency = 1` (CanCollide = false на 2.5 сек).
3. **Секция 3: Лазерный коридор (Laser Beams)** — пол с периодическими красными лазерами толщиной 0.8 стада на высоте прыжка.
4. **Секция 4: Узкая балка (Tightrope)** — балка шириной ровно 1.4 стада над бездной длиной 60 стадов.
5. **Секция 5: Финишный подиум (Victory Podium)** — золотая площадка $24 \times 24$ со спавном салюта конфетти и авто-выдачей значка победы.
