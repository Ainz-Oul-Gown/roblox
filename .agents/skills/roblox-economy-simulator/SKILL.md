---
name: roblox-economy-simulator
description: >-
  Математическое моделирование и балансировка экономики игр в Roblox:
  CLI-скрипт симуляции сессий (Node.js / Luau), расчет TTFR (Time to First Rebirth),
  поиск узких горлышек прогрессии и автоматическая настройка экспоненциального баланса.
---

# Roblox Economy Simulator (Game Balance Engine)

Инструмент математического бенчмарка темпа игры без необходимости часами вручную гриндить в Roblox Studio для проверки баланса.

---

## 1. Зачем нужна симуляция экономики?

В тайкунах и симуляторах 80% игроков уходят из-за двух ошибок геймдизайна:
1. **Слишком долго (Grind Wall)**: если до первого Rebirth нужно копить 40+ минут, 90% игроков выйдут через 7 минут.
2. **Слишком быстро**: если игрок покупает все за 3 минуты, ему становится скучно.

🎯 **Золотой стандарт Roblox**:
* Время до первого Rebirth (TTFR): **10–15 минут**.
* Промежуток между первыми покупками: **3–8 секунд** (постоянный микро-дофамин).
* Стоимость каждого следующего этапа растет по степенной формуле: $\text{Cost}_{n} = \text{BaseCost} \times 1.45^n$.

---

## 2. Шаблон скрипта симуляции (`simulate.js`)

Запуск 1 000 игровых шагов за 1 секунду прямо в консоли:

```javascript
// simulate.js
function runEconomySim(itemsChain, targetGoal = "Rebirth") {
    let cash = 0;
    let time = 0;
    let incomePerSec = 5;
    let purchased = new Set();

    while (!purchased.has(targetGoal) && time < 3600) {
        cash += incomePerSec;
        time += 1;

        // Жадный алгоритм игрока: покупка самого дешевого доступного апгрейда
        const affordable = itemsChain
            .filter(item => !purchased.has(item.name) && cash >= item.cost)
            .sort((a, b) => a.cost - b.cost);

        if (affordable.length > 0) {
            const buy = affordable[0];
            cash -= buy.cost;
            purchased.add(buy.name);
            incomePerSec += buy.incomeBoost;
        }
    }

    return { timeMinutes: (time / 60).toFixed(1) };
}
```

---

## 3. Команда проверки баланса
```powershell
node bin/simulate-economy.js
```
Скрипт мгновенно выведет временную шкалу прохождения и вердикт: сбалансирована ли экономика или где-то возник затык.
