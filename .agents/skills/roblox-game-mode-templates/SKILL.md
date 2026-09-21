---
name: roblox-game-mode-templates
description: >-
  Готовые архитектурные шаблоны и серверные движки для популярных жанров Roblox:
  Tycoon (дропперы, конвейеры, сейф, кнопки зависимостей, Rebirth),
  Simulator (кликер, рюкзак, продажа, ворота зон, питомцы),
  Round-based Minigames / Arena (лобби, интермиссия, голосование за карту, спавн, награды),
  Obby / Parkour (чекпоинты, сохранение этапа, анти-спам лазеры, таймер спидрана).
---

# Roblox Game Mode Templates

Коллекция проверенных архитектурных шаблонов для быстрой сборки популярных режимов в Roblox на Luau.

---

## 1. Режим: Tycoon Engine (Тайкун)

### Архитектура:
* **PlotManager**: Выделение плота игроку при входе (`PlayerAdded`) и очистка при выходе.
* **ButtonTree**: Покупка объектов с проверкой зависимостей (`Dependency`) и стоимости (`Cost`).
* **Dropper & Conveyor**: Физический спавн руды (`Part` с `Debris`) или расчетный стриминг.
* **Collector & Vault**: Накопление прибыли в изолированном сейфе базы (`WithdrawPad`).

### Шаблон ButtonService (Сервер):
```lua
--!strict
local ButtonService = {}

type TycoonButton = {
    Id: string,
    Cost: number,
    Dependency: string?,
    TargetInstanceName: string,
}

function ButtonService.CanPurchase(profile: any, button: TycoonButton): (boolean, string)
    if profile.Data.Purchased[button.Id] then
        return false, "Уже куплено"
    end
    if button.Dependency and not profile.Data.Purchased[button.Dependency] then
        return false, "Требуется предыдущее улучшение"
    end
    if profile.Data.Cash < button.Cost then
        return false, "Недостаточно средств"
    end
    return true, "OK"
end

function ButtonService.Purchase(player: Player, profile: any, button: TycoonButton, plotModel: Model): boolean
    local canBuy, _ = ButtonService.CanPurchase(profile, button)
    if not canBuy then return false end

    profile.Data.Cash -= button.Cost
    profile.Data.Purchased[button.Id] = true

    -- Отобразить купленную деталь на плоту
    local target = plotModel:FindFirstChild(button.TargetInstanceName, true)
    if target and target:IsA("BasePart") then
        target.Transparency = 0
        target.CanCollide = true
    end

    return true
end

return ButtonService
```

---

## 2. Режим: Simulator Engine (Симулятор)

### Механика:
1. Игрок кликает или использует инструмент (`Tool.Activated`).
2. За клик начисляется сырой ресурс (Power, Bubble, Clicks) с учетом множителей питомцев.
3. Ограничение по объему рюкзака (`MaxCapacity`).
4. При входе в `SellZone` весь ресурс конвертируется в монеты (`Coins`).

### Шаблон SimulatorService:
```lua
--!strict
local SimulatorService = {}

function SimulatorService.OnClick(player: Player, profile: any)
    if profile.Data.CurrentCapacity >= profile.Data.MaxCapacity then
        -- Рюкзак полон, вызов клиентского предупреждения
        return false
    end

    local multiplier = profile.Data.PetMultiplier or 1.0
    local gain = math.floor(1 * multiplier)

    profile.Data.CurrentCapacity = math.min(
        profile.Data.MaxCapacity, 
        profile.Data.CurrentCapacity + gain
    )
    return true
end

function SimulatorService.OnEnterSellZone(player: Player, profile: any)
    if profile.Data.CurrentCapacity <= 0 then return end

    local reward = profile.Data.CurrentCapacity * (profile.Data.SellRate or 1)
    profile.Data.Coins += reward
    profile.Data.CurrentCapacity = 0

    -- Звук звона монет и визуальные летающие цифры
end

return SimulatorService
```

---

## 3. Режим: Round-based Minigames / Arena (Матчи и Арены)

### Стейт-машина раундов:
`Lobby` ➡️ `Intermission (15s)` ➡️ `Map Select` ➡️ `Teleport to Arena` ➡️ `Round Loop (120s)` ➡️ `Victory Check` ➡️ `Give Rewards` ➡️ `Cleanup & Return`.

### Шаблон MatchController (Сервер):
```lua
--!strict
local MatchService = {}
local Players = game:GetService("Players")

export type MatchState = "Lobby" | "Intermission" | "InGame" | "Ending"
local currentState: MatchState = "Lobby"

function MatchService.StartGameLoop()
    task.spawn(function()
        while true do
            -- 1. Интермиссия в лобби
            currentState = "Intermission"
            for t = 15, 1, -1 do
                -- Отправка обратного отсчета клиентам
                task.wait(1)
            end

            -- 2. Сбор живых игроков
            local contestants: { Player } = {}
            for _, player in Players:GetPlayers() do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(contestants, player)
                end
            end

            if #contestants < 1 then
                task.wait(2)
                continue
            end

            -- 3. Телепортация на арену
            currentState = "InGame"
            local spawns = workspace.Arena.Spawns:GetChildren()
            for i, player in contestants do
                local spawnPart = spawns[((i - 1) % #spawns) + 1] :: BasePart
                player.Character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
            end

            -- 4. Игровой таймер и детекция победителей
            local roundTime = 60
            while roundTime > 0 and #contestants > 1 do
                task.wait(1)
                roundTime -= 1
                -- Проверка выбывших
                for i = #contestants, 1, -1 do
                    local char = contestants[i].Character
                    if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then
                        table.remove(contestants, i)
                    end
                end
            end

            -- 5. Награждение победителей
            currentState = "Ending"
            for _, winner in contestants do
                -- Выдача победных очков / валюты
            end

            -- Возврат в лобби
            for _, player in Players:GetPlayers() do
                if player.Character then
                    player:LoadCharacter() -- Перезагрузка или телепорт в лобби
                end
            end
            task.wait(4)
        end
    end)
end

return MatchService
```

---

## 4. Режим: Obby / Parkour Speedrun (Полоса препятствий)

### Ключевые компоненты:
1. **Touch-чекпоинты с защитой от скипа**:
   Игрок может активировать только `Stage + 1`, нельзя сразу наступить на последний чекпоинт.
2. **Безопасные KillBricks**:
   Обязательный `Debounce` на касание лазера, чтобы не перегружать сервер тысячами событий:
   ```lua
   killPart.Touched:Connect(function(hit)
       local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
       if humanoid and humanoid.Health > 0 then
           humanoid.Health = 0
       end
   end)
   ```
3. **Автоматический респавн на текущем чекпоинте**:
   Слушатель `player.CharacterAdded` берет CFrame детали `Checkpoints[stage]`.
