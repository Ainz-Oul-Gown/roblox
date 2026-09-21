---
name: roblox-pet-gacha-system
description: >-
  Индустриальный стандарт системы питомцев и яиц (Pet Simulator / Mining Simulator pattern):
  взвешенный генератор шансов (Weighted RNG), инвентарь с Equip Best, расчет множителей сбора
  и оптимизированный клиентский рендеринг следования (AlignPosition / Lerp) без серверных лагов.
---

# Roblox Pet & Egg Gacha System (Pet Sim Standard)

Универсальный шаблон системы питомцев и яиц, проверенный топ-играми Roblox (Pet Simulator, Arm Wrestle Simulator, Mining Simulator).

---

## 1. Взвешенный рандом (Weighted Cumulative RNG)

Таблица вероятностей выпадения задается через целые или дробные веса. Никаких жестких `if math.random() == 1`:

```lua
--!strict
export type DropRate = { petId: string, weight: number }

local function RollEgg(drops: { DropRate }): string
    local totalWeight = 0
    for _, drop in drops do
        totalWeight += drop.weight
    end

    local randomPoint = math.random() * totalWeight
    local cumulative = 0

    for _, drop in drops do
        cumulative += drop.weight
        if randomPoint <= cumulative then
            return drop.petId
        end
    end

    return drops[1].petId
end
```

---

## 2. Архитектура следования питомцев (Anti-Lag Pattern)

### ⚠️ Критическая ошибка новичков:
Двигать питомцев на сервере физическими телами (`BodyPosition`, неанкоренные парты). Когда на сервере 10 игроков по 3 питомца (30 физических тел), физический движок Roblox начинает лагать.

### 🌟 Индустриальный стандарт:
1. **Сервер**: хранит только данные инвентаря и отправляет клиентам массив ID надетых питомцев (`EquippedPetsEvent`).
2. **Клиент**: локально спавнит модели питомцев (`Anchored = true`, `CanCollide = false`) и плавно смещает их в `RunService.RenderStepped` через `CFrame:Lerp` или сплайны за спиной персонажа.

```lua
-- Клиентский контроллер полета (PetFollower.client.luau)
local function UpdatePets(dt: number)
    local char = player.Character
    if not char or not char.PrimaryPart then return end
    local root = char.PrimaryPart
    local now = os.clock()

    for index, petModel in ipairs(activePetModels) do
        -- Радиальное распределение за спиной
        local angle = ((index - 1) / (#activePetModels)) * math.pi - (math.pi / 2)
        local targetOffset = Vector3.new(math.cos(angle) * 4, 1.2 + math.sin(now * 3 + index) * 0.3, math.sin(angle) * 4 + 3)
        local targetCFrame = root.CFrame * CFrame.new(targetOffset)

        petModel.PrimaryPart.CFrame = petModel.PrimaryPart.CFrame:Lerp(targetCFrame, math.clamp(dt * 8, 0, 1))
    end
end
```

---

## 3. Алгоритм «Equip Best» (Экипировать лучших)

Сортировка инвентаря по убыванию множителя с отсечением по лимиту слотов (по умолчанию 3, увеличивается геймпасом до 5–6):

```lua
function PetManager.EquipBest(inventory: { any }, maxSlots: number)
    for _, item in inventory do item.isEquipped = false end

    table.sort(inventory, function(a, b)
        return a.multiplier > b.multiplier
    end)

    for i = 1, math.min(#inventory, maxSlots) do
        inventory[i].isEquipped = true
    end
end
```
