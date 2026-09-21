---
name: roblox-retention-engine
description: >-
  Проверенная система удержания игроков (Retention Engine) для топ-плейсов Roblox:
  подарки за сессионное время (Playtime Gifts), календарь ежедневного входа (Daily Streak)
  по UTC дням с защитой от накрутки системного времени и сохранением в DataStore/ProfileService.
---

# Roblox Retention Engine (Top-Tier Retention Pattern)

Движок максимизации двух ключевых метрик для алгоритмов Roblox Discovery:
1. **Average Session Length** (средняя длина сессии) — через подарки за время (5, 10, 15, 30, 60 мин).
2. **D1 / D7 Retention** (возвраты игроков) — через календарь ежедневных наград со стриками.

---

## 1. Календарь ежедневных наград (Daily Streak по UTC дням)

Вместо локального времени или простого 24-часового таймера, индустриальный стандарт использует **номер дня в эпохе UTC**:
$$\text{CurrentDay} = \lfloor \frac{\text{os.time()}}{86400} \rfloor$$

Это исключает манипуляции с часовыми поясами и гарантирует, что день обновляется для всех синхронно в 00:00 UTC.

### Эталонный алгоритм:
```lua
--!strict
local RetentionEngine = {}

local SECONDS_PER_DAY = 86400

function RetentionEngine.GetUTCDay(): number
    return math.floor(os.time() / SECONDS_PER_DAY)
end

function RetentionEngine.ProcessDailyLogin(profile: any): (boolean, number, string)
    local currentDay = RetentionEngine.GetUTCDay()
    local lastDay = profile.Data.LastDailyLoginDay or 0
    local streak = profile.Data.DailyStreak or 0

    if lastDay == currentDay then
        return false, streak, "Награда за сегодня уже забрана"
    end

    if lastDay == (currentDay - 1) then
        -- Игрок зашел на следующий день: стрик растет
        streak = (streak % 7) + 1
    else
        -- Игрок пропустил день: сброс на день 1
        streak = 1
    end

    profile.Data.LastDailyLoginDay = currentDay
    profile.Data.DailyStreak = streak

    return true, streak, `День {streak} активирован!`
end
```

---

## 2. Подарки за время в игре (Playtime Gifts)

### Стандартная сетка наград лучших игр:
| Уровень | Время в сессии | Цель для метрик | Типичная награда |
| :--- | :--- | :--- | :--- |
| **Tier 1** | **5 минут** | Пройти первый рубеж отвала | Стартовая сумма валюты (быстрый дофамин) |
| **Tier 2** | **15 минут** | Закрепить геймплейный цикл | Бустер дохода x2 на 10 минут |
| **Tier 3** | **30 минут** | Вход в категорию вовлеченных | Уникальный пет или скин |
| **Tier 4** | **60 минут** | Максимальный буст алгоритмам | Двойной Rebirth или редкий ящик |

### Серверный таймер:
```lua
local sessionStarts: { [Player]: number } = {}

function RetentionEngine.OnPlayerJoin(player: Player)
    sessionStarts[player] = os.clock()
end

function RetentionEngine.GetPlaytime(player: Player): number
    local start = sessionStarts[player]
    return start and (os.clock() - start) or 0
end
```

---

## 3. UI-индикация и вовлечение
* На экране всегда висит компактная иконка подарка с тикающим обратным отсчетом (`04:59`).
* При готовности подарка кнопка начинает сочно покачиваться (Wobble/Spring анимация) и испускать золотые искры.
