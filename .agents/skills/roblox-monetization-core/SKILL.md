---
name: roblox-monetization-core
description: >-
  Промышленный стандарт монетизации в Roblox на базе официальных спецификаций Roblox Developer Hub:
  безопасный MarketplaceService.ProcessReceipt с идемпотентностью, кэширование геймпасов,
  защита от потери донатов при дисконнектах и шаблоны магазинов (DevProducts & Gamepasses).
---

# Roblox Monetization Core (Developer Hub Standard)

Официальный и проверенный сообществом стандарт обработки внутриигровых покупок (DevProducts) и геймпасов (GamePasses) без риска бана за потерю робуксов игроков.

---

## 1. Официальный паттерн `ProcessReceipt`

Roblox требует строгого соблюдения контракта `ProcessReceipt`:
1. Если сервер вернул `PurchaseGranted`, Roblox списывает робуксы и больше **никогда** не повторяет этот чек.
2. Если сервер упал, вернул ошибку или `NotProcessedYet`, Roblox будет слать чек повторно при каждом входе игрока, пока не получит `PurchaseGranted`.
3. **Идемпотентность**: сервер обязан сохранять ID чека (`receiptInfo.PurchaseId`) в DataStore/профиле, чтобы при повторной отправке одного и того же чека не выдать товар дважды.

### Эталонная реализация (Server):
```lua
--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PurchaseHistoryStore = DataStoreService:GetDataStore("PurchaseHistory_v1")

local MonetizationService = {}

-- Каталог товаров с привязкой к функциям выдачи
local ProductHandlers = {
    [100001] = function(player: Player): boolean
        -- Пример: Мешок валюты (+50,000)
        return true
    end,
    [100002] = function(player: Player): boolean
        -- Пример: Мгновенный Rebirth (+1)
        return true
    end,
}

local function ProcessReceipt(receiptInfo: {
    PurchaseId: string,
    PlayerId: number,
    ProductId: number,
    CurrencySpent: number,
}): Enum.ProductPurchaseDecision
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Игрок вышел из игры до завершения транзакции
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- 1. Проверка на дубликат чека в DataStore (защита от лагов сети)
    local receiptKey = `Receipt_{receiptInfo.PurchaseId}`
    local alreadyHandled = false
    local success, err = pcall(function()
        alreadyHandled = PurchaseHistoryStore:GetAsync(receiptKey) ~= nil
    end)

    if success and alreadyHandled then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- 2. Поиск обработчика товара
    local handler = ProductHandlers[receiptInfo.ProductId]
    if not handler then
        warn(`[Monetization] Не зарегистрирован товар с ID {receiptInfo.ProductId}`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- 3. Выдача награды
    local grantSuccess, grantErr = pcall(handler, player)
    if not grantSuccess or not grantErr then
        warn(`[Monetization] Ошибка начисления награды: {tostring(grantErr)}`)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- 4. Фиксация чека в истории покупок
    pcall(function()
        PurchaseHistoryStore:SetAsync(receiptKey, {
            PlayerId = receiptInfo.PlayerId,
            ProductId = receiptInfo.ProductId,
            Timestamp = os.time(),
        })
    end)

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
    MarketplaceService.ProcessReceipt = ProcessReceipt
end

return MonetizationService
```

---

## 2. Проверка владения геймпасами (с защитой от квоты API)

Вызов `MarketplaceService:UserOwnsGamePassAsync` имеет жесткий лимит вызовов. Обязательно кэшировать результат на сессию игрока:

```lua
local passCache: { [number]: { [number]: boolean } } = {}

function MonetizationService.UserOwnsPass(player: Player, passId: number): boolean
    local userId = player.UserId
    if passCache[userId] and passCache[userId][passId] ~= nil then
        return passCache[userId][passId]
    end

    local owns = false
    local s, e = pcall(function()
        owns = MarketplaceService:UserOwnsGamePassAsync(userId, passId)
    end)

    if s then
        if not passCache[userId] then passCache[userId] = {} end
        passCache[userId][passId] = owns
        return owns
    end
    return false
end
```

---

## 3. Чек-лист безопасности монетизации
* [x] `ProcessReceipt` назначен ровно один раз на сервере.
* [x] Награды начисляются только на сервере, клиент никогда не передает сумму начисления.
* [x] Проверена обработка случая выхода игрока (`return NotProcessedYet`).
* [x] ID чеков сохраняются для предотвращения дюпов при повторных запросах Roblox.
