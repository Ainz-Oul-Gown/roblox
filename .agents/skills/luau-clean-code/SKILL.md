---
name: luau-clean-code
description: >-
  Стандарты чистого кода на Luau: строгая типизация (--!strict), экспорт типов,
  конфигурация линтера Selene и форматтера StyLua, правила безопасности и обработка ошибок.
---

# Luau Clean Code & Typing Standards

Руководство по написанию надежного, типизированного и быстрого кода на языке Luau для Roblox.

---

## 1. Режим строгой типизации (`--!strict`)

Все новые файлы должны начинаться с директивы строгой типизации:
```lua
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
```

### Экспорт и определение типов:
```lua
-- Определение структуры данных игрока
export type PlayerStats = {
    Cash: number,
    Rebirths: number,
    Multiplier: number,
    Inventory: { string },
    LastSave: number,
}

-- Определение интерфейса сервиса
export type IPlayerService = {
    GetStats: (player: Player) -> PlayerStats?,
    AddCash: (player: Player, amount: number) -> boolean,
}
```

---

## 2. Стандарты линтинга (Selene)

Файл конфигурации `selene.toml` в корне проекта:
```toml
std = "roblox"

[rules]
roblox_incorrect_roblox = "error"
unused_variable = "warn"
shadowing = "warn"
multiple_statements = "error"
manual_table_clone = "warn"
empty_if = "error"
```

Команда проверки линтером:
```powershell
selene src/
```

---

## 3. Форматирование кода (StyLua)

Файл конфигурации `stylua.toml`:
```toml
column_width = 120
line_endings = "Windows"
indent_type = "Spaces"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

Команды форматирования:
```powershell
# Проверить стиль без изменений:
stylua --check src/

# Отформатировать весь код:
stylua src/
```

---

## 4. Защитное программирование и обработка ошибок

1. **Никогда не доверяйте данным от клиента**:
   Всегда проверяйте типы и границы входных параметров в `OnServerEvent`:
   ```lua
   SomeRemote.OnServerEvent:Connect(function(player: Player, amount: any)
       if typeof(amount) ~= "number" or amount <= 0 or amount ~= amount or amount == math.huge then
           warn(`[Security] Подозреваемый ввод от {player.Name}: {tostring(amount)}`)
           return
       end
       -- Обработка
   end)
   ```

2. **Оборачивайте внешние API в `pcall`**:
   Все обращения к `DataStoreService`, `HttpService`, `MarketplaceService` обязаны быть в `pcall`:
   ```lua
   local success, result = pcall(function()
       return dataStore:GetAsync(`Player_{userId}`)
   end)

   if not success then
       warn(`[DataStore] Ошибка загрузки данных: {tostring(result)}`)
       return nil
   end
   ```

3. **Очистка ресурсов (`Maid` / `Janitor` / `Trove`)**:
   Всегда отключайте соединения (`RBXScriptConnection:Disconnect()`) и удаляйте временные инстансы (`Debris:AddItem` или очистка в `Destroy`).
