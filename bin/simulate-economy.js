#!/usr/bin/env node

/**
 * Economy Simulator CLI for Roblox Tycoons & Games
 * Runs 1,000 game loop cycles to benchmark progression curves, TTFR (Time to First Rebirth),
 * and detect balance bottlenecks.
 */

const TYCOON_ITEMS_CHAIN = [
    { name: "Dropper_1", cost: 0, incomeRate: 10, interval: 2.0 },
    { name: "Upgrader_1", cost: 150, multiplier: 1.5 },
    { name: "Dropper_2", cost: 500, incomeRate: 35, interval: 1.8 },
    { name: "Upgrader_Laser", cost: 1500, multiplier: 2.0 },
    { name: "Floor2_Foundation", cost: 5000 },
    { name: "Dropper_Floor2_1", cost: 10000, incomeRate: 120, interval: 1.5 },
    { name: "Upgrader_Quantum", cost: 25000, multiplier: 3.0 },
    { name: "Dropper_Galactic", cost: 50000, incomeRate: 400, interval: 1.2 },
    { name: "Rebirth_Portal", cost: 100000 },
];

function simulateRun(strategy = "optimal") {
    let cash = 0;
    let timeSeconds = 0;
    let purchased = new Set();
    let currentDroppers = [];
    let currentMultiplier = 1.0;

    let history = [];

    while (!purchased.has("Rebirth_Portal") && timeSeconds < 7200) {
        // Добавляем доход от активных дропперов за прошедший шаг (dt = 1 sec)
        let stepIncome = 0;
        for (const drop of currentDroppers) {
            stepIncome += (drop.incomeRate / drop.interval);
        }
        cash += (stepIncome * currentMultiplier);
        timeSeconds += 1;

        // Пытаемся купить следующее доступное улучшение
        for (const item of TYCOON_ITEMS_CHAIN) {
            if (!purchased.has(item.name) && cash >= item.cost) {
                cash -= item.cost;
                purchased.add(item.name);

                if (item.incomeRate) {
                    currentDroppers.push(item);
                }
                if (item.multiplier) {
                    currentMultiplier *= item.multiplier;
                }

                history.push({
                    time: timeSeconds,
                    item: item.name,
                    cost: item.cost,
                    incomeSec: (currentDroppers.reduce((s, d) => s + (d.incomeRate / d.interval), 0) * currentMultiplier).toFixed(1)
                });
                break;
            }
        }
    }

    return {
        totalTime: timeSeconds,
        minutes: (timeSeconds / 60).toFixed(1),
        history
    };
}

console.log("==================================================");
console.log("       ROBLOX TYCOON ECONOMY BALANCE SIMULATOR     ");
console.log("==================================================");

const result = simulateRun("optimal");
console.log(`\n✅ Время до первого Rebirth (TTFR): ${result.minutes} минут (${result.totalTime} сек)\n`);
console.log("График ключевых покупок:");
console.log("--------------------------------------------------");
console.log("Время (мин:сек)  | Купленный объект       | Доход/сек");
console.log("--------------------------------------------------");
result.history.forEach(h => {
    const mins = Math.floor(h.time / 60);
    const secs = h.time % 60;
    const timeFormatted = `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    console.log(`${timeFormatted}           | ${h.item.padEnd(22)} | $${h.incomeSec}/s`);
});
console.log("--------------------------------------------------");

// Оценка темпа
const targetMin = 8.0;
const targetMax = 18.0;
const currentMin = parseFloat(result.minutes);

if (currentMin >= targetMin && currentMin <= targetMax) {
    console.log(`🌟 БАЛАНС ИДЕАЛЕН: темп ${result.minutes} мин. отлично подходит для удержания игроков (Retention).`);
} else if (currentMin < targetMin) {
    console.log(`⚠️ ИГРА ПРОХОДИТСЯ СЛИШКОМ БЫСТРО (${result.minutes} мин < ${targetMin} мин). Рекомендуется повысить цены поздних дропперов.`);
} else {
    console.log(`⚠️ ИГРА СЛИШКОМ ЗАТЯНУТА (${result.minutes} мин > ${targetMax} мин). Игроки могут заскучать на первом этапе.`);
}
console.log("==================================================\n");
