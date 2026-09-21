---
name: roblox-architecture-knit
description: >-
  Модульная сервис-ориентированная архитектура (Knit / Sleitnick pattern):
  разделение ответственности (Services на сервере, Controllers на клиенте),
  жизненный цикл (KnitInit/KnitStart), безопасная валидация сетевых вызовов и сигналы.
---

# Roblox Architecture: Knit & Service Pattern

Архитектурный стандарт построения масштабируемых проектов Roblox без спагетти-кода и с четким разделением клиентской и серверной логики.

---

## 1. Концепция архитектуры

* **Сервер (`ServerScriptService.Server`)**:
  * Состоит из независимых сервисов (**Services**), например: `DataService`, `InventoryService`, `CombatService`.
  * Сервер является единственным источником истины (**Single Source of Truth**).
  * Экспортирует клиентские методы через `Client = {}`.
* **Клиент (`StarterPlayerScripts.Client`)**:
  * Состоит из контроллеров (**Controllers**), например: `UIController`, `CameraController`, `CombatController`.
  * Отвечает исключительно за отображение, звук, опрос ввода (клавиши/мышь) и оптимистичный отклик.

---

## 2. Пример Сервиса (Server-Side)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ShopService = Knit.CreateService {
    Name = "ShopService",
    Client = {
        ItemPurchased = Knit.CreateSignal(), -- Сервер -> Клиент оповещение
    },
}

-- Внутренние данные сервиса
local ItemPrices = {
    Sword = 100,
    SpeedPotion = 50,
}

-- Метод, вызываемый клиентом через RemoteFunction
function ShopService.Client:BuyItem(player: Player, itemId: string): (boolean, string)
    local price = ItemPrices[itemId]
    if not price then
        return false, "Товар не найден"
    end

    local DataService = Knit.GetService("DataService")
    local profile = DataService:GetProfile(player)
    if not profile or profile.Data.Cash < price then
        return false, "Недостаточно средств"
    end

    -- Списание и выдача
    profile.Data.Cash -= price
    table.insert(profile.Data.Inventory, itemId)

    self.ItemPurchased:Fire(player, itemId)
    return true, "Покупка успешна"
end

function ShopService:KnitInit()
    -- Инициализация структур данных, подготовка таблиц
end

function ShopService:KnitStart()
    -- Запуск слушателей событий, когда ВСЕ сервисы уже инициализированы
    print("[ShopService] Сервис успешно запущен")
end

return ShopService
```

---

## 3. Пример Контроллера (Client-Side)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ShopController = Knit.CreateController {
    Name = "ShopController",
}

function ShopController:RequestPurchase(itemId: string)
    local ShopService = Knit.GetService("ShopService")
    
    -- Асинхронный вызов сервера с обработкой результата
    task.spawn(function()
        local success, msg = ShopService:BuyItem(itemId)
        if success then
            print(`[Shop] Куплено: {itemId}`)
        else
            warn(`[Shop] Ошибка: {msg}`)
        end
    end)
end

function ShopController:KnitStart()
    local ShopService = Knit.GetService("ShopService")
    ShopService.ItemPurchased:Connect(function(itemId: string)
        -- Воспроизвести звук покупки и показать всплывающее уведомление
    end)
end

return ShopController
```

---

## 4. Золотые правила сетевой безопасности
1. **Никогда не передавать баланс или урон от клиента на сервер**: Клиент шлет лишь намерение: `ShopService:BuyItem("Sword")`, а сервер сам списывает точную стоимость.
2. **Rate Limiting (Кулдауны сетевых вызовов)**: Защищайте методы от клик-спама и макросов, запоминая `LastActionTime[player]`.
3. **Строгая проверка дистанции**: Если игрок взаимодействует с объектом в мире (сундук, NPC), проверьте на сервере:
   ```lua
   if (player.Character.PrimaryPart.Position - targetPos).Magnitude > 25 then
       return false -- Слишком далеко (подозрение на телепорт)
   end
   ```
