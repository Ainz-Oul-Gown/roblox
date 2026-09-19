# Project Overview: Gen Alpha Brainrot Multiplayer Tycoon

## Описание проекта
**Gen Alpha Brainrot Multiplayer Tycoon** — масштабный вирусный мультиплеерный тайкун на **8 игроков** в стилистике интернет-культуры поколения Альфа (Skibidi, Mewing, Sigma, Fanum Tax, Grimace, CaseOh, Rizzler, Tung Tung). Проект включает 8 круговых баз вокруг центральной боевой арены, 8 уникальных суперспособностей, лазерную защиту базы, 5 уровней Rebirth и современный экранный HUD.

## Стек технологий
- **Платформа**: Roblox
- **Инструмент синхронизации**: Rojo v7.7.0 (бинарник в `bin/rojo.exe`, плагин в `%LocalAppData%\Roblox\Plugins\Rojo.rbxm`)
- **Язык**: Luau (strict typing `--!strict`)
- **Мультиплеер**: 8 независимых баз по круговой сетке ($R = 90$ studs) + центральная зона царя горы `(0, 0, 0)`
- **Сохранение**: Roblox DataStoreService (`TycoonSave_v1`)
- **Тестирование**: Node.js Test Runner (`npm test`, 22 юнит-теста)
- **CI/CD**: GitHub Actions (`.github/workflows/ci.yml`)
- **Контроль версий**: Git + GitHub (`Ainz-Oul-Gown/roblox`)

## Структура каталогов
```text
roblox/
├── .ai/
│   ├── PROJECT_OVERVIEW.md
│   ├── ARCHITECTURE.md
│   └── CONVENTIONS.md
├── .github/
│   └── workflows/
│       └── ci.yml
├── bin/
│   └── rojo.exe
├── src/
│   ├── client/
│   │   └── init.client.luau          # BrainrotHUD, двойной прыжок, кнопка способности
│   ├── server/
│   │   ├── AbilityService.luau       # Серверная логика 8 способностей фракций
│   │   ├── CentralArena.luau         # Зона «Царь Горы Ауры» (+25/сек)
│   │   ├── DataStoreManager.luau     # Сохранение прогресса
│   │   ├── PlotBuilder.luau          # 3D-генератор фракционных баз и лазеров
│   │   ├── PlotManager.luau          # Круговое распределение 8 участков
│   │   ├── TycoonService.luau        # Экономика, Rebirth 1-5, множители
│   │   └── init.server.luau          # Серверная точка входа
│   └── shared/
│       ├── EconomyManager.luau       # Расчет баланса и 5 Rebirth тиров
│       ├── MathUtils.luau            # Математические утилиты
│       └── TycoonConfig.luau         # Конфигурация 8 фракций, способностей и цен
├── tests/
│   ├── brainrotMultiplayer.test.js   # 8 баз, способности, лазеры, арена
│   ├── dataStore.test.js
│   ├── economyManager.test.js
│   ├── mathUtils.test.js
│   ├── plotBuilder.test.js
│   └── rebirth.test.js
├── default.project.json
├── package.json
└── .gitignore
```

## Быстрый старт
1. **Тестирование**:
   ```powershell
   npm test
   ```
2. **Запуск сервера синхронизации Rojo**:
   ```powershell
   npm run serve
   ```
3. **Запуск игры в Studio**:
   - Нажать кнопку **Play (F5)** в Roblox Studio.
