---
name: roblox-data-persistence
description: >-
  Промышленное сохранение данных игроков в Roblox: шаблоны ProfileService,
  блокировка сессий (Session Locking), защита от дюпов, автосохранение,
  миграция схем данных и обработка сбоев серверов.
---

# Roblox Data Persistence (ProfileService Standards)

Надежная система сохранения данных игроков без потери инвентарей, дубликатов валюты и с защитой от одновременного входа на несколько серверов.

---

## 1. Схема данных по умолчанию (ProfileTemplate)

```lua
--!strict

export type ProfileData = {
    Cash: number,
    Gems: number,
    Rebirths: number,
    Level: number,
    Inventory: { string },
    Settings: {
        MusicVolume: number,
        SfxVolume: number,
        MuteTrade: boolean,
    },
    Version: number,
}

local ProfileTemplate: ProfileData = {
    Cash = 0,
    Gems = 0,
    Rebirths = 0,
    Level = 1,
    Inventory = {},
    Settings = {
        MusicVolume = 100,
        SfxVolume = 100,
        MuteTrade = false,
    },
    Version = 1,
}

return ProfileTemplate
```

---

## 2. Реализация DataManager с ProfileService

```lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileService = require(ReplicatedStorage.Packages.ProfileService)
local ProfileTemplate = require(script.Parent.ProfileTemplate)

local ProfileStore = ProfileService.GetProfileStore(
    "PlayerData_v1",
    ProfileTemplate
)

local Profiles: { [Player]: any } = {}

local DataManager = {}

local function OnPlayerAdded(player: Player)
    local profileKey = `Player_{player.UserId}`
    local profile = ProfileStore:LoadProfileAsync(profileKey)

    if profile ~= nil then
        profile:AddUserId(player.UserId) -- Соблюдение GDPR требования Roblox
        profile:Reconcile() -- Дополнить профиль новыми полями из шаблона

        profile:ListenToRelease(function()
            Profiles[player] = nil
            player:Kick("Ваша сессия была загружена на другом сервере.")
        end)

        if player:IsDescendantOf(Players) == true then
            Profiles[player] = profile
            print(`[DataManager] Профиль загружен для {player.Name}`)
            -- Инициализация лидерстатс или передача стейта
        else
            -- Игрок вышел пока профиль загружался
            profile:Release()
        end
    else
        -- Не удалось заблокировать сессию (например, игрок уже на другом сервере)
        player:Kick("Не удалось загрузить данные. Пожалуйста, перезайдите в игру.")
    end
end

local function OnPlayerRemoving(player: Player)
    local profile = Profiles[player]
    if profile ~= nil then
        profile:Release() -- Освобождаем сессию и сохраняем финальное состояние
    end
end

function DataManager.Init()
    Players.PlayerAdded:Connect(OnPlayerAdded)
    Players.PlayerRemoving:Connect(OnPlayerRemoving)

    for _, player in Players:GetPlayers() do
        task.spawn(OnPlayerAdded, player)
    end
end

function DataManager.GetProfile(player: Player)
    return Profiles[player]
end

function DataManager.AddCash(player: Player, amount: number): boolean
    local profile = Profiles[player]
    if not profile then return false end
    profile.Data.Cash += amount
    return true
end

return DataManager
```

---

## 3. Ключевые правила надежности
1. **Никаких прямых `SetAsync` каждые 5 секунд**:
   ProfileService автоматически кэширует данные в памяти и делает автосохранение раз в ~30 секунд. Все изменения мутируют `profile.Data.*` напрямую в оперативной памяти.
2. **Session Locking**:
   Запрещает игроку зайти на второй сервер и перекинуть инвентарь или сдублировать валюту. Если профиль занят другим сервером, `LoadProfileAsync` будет ожидать освобождения.
3. **Reconcile**:
   При добавлении нового поля в игру (например `Gems = 0`) старые игроки при входе автоматически получат это поле благодаря вызову `profile:Reconcile()`.
