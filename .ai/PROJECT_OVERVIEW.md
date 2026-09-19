# Project Overview: roblox (Tycoon)

## Описание проекта
Проект **roblox** — это полнофункциональный тайкун для платформы Roblox с синхронизацией через **Rojo**, типизированной базой на **Luau**, облачным сохранением в **DataStore**, системой перерождений (**Rebirth**), звуковыми и визуальными эффектами (**SFX/VFX**) и экранным **HUD**.

## Стек технологий
- **Платформа**: Roblox
- **Инструмент синхронизации**: Rojo v7.7.0 (бинарник в `bin/rojo.exe`, плагин в `%LocalAppData%\Roblox\Plugins\Rojo.rbxm`)
- **Язык**: Luau (strict mode `--!strict`)
- **Сохранение данных**: Roblox DataStoreService (`TycoonSave_v1`) с автосохранением и pcall
- **Тестирование**: Node.js Test Runner (`npm test`, 17 юнит-тестов)
- **CI/CD**: GitHub Actions (`.github/workflows/ci.yml`)
- **Контроль версий**: Git + GitHub (`Ainz-Oul-Gown/roblox`)

## Структура каталогов
```text
roblox/
├── .ai/                    # AI контекст, архитектура, конвенции
│   ├── PROJECT_OVERVIEW.md
│   ├── ARCHITECTURE.md
│   └── CONVENTIONS.md
├── .github/
│   └── workflows/
│       └── ci.yml          # GitHub Actions автотесты
├── bin/                    # Локальные утилиты (rojo.exe)
├── src/
│   ├── client/             # Клиентские скрипты (StarterPlayerScripts)
│   │   └── init.client.luau # TycoonHUD (анимированный баланс, множитель, Rebirths)
│   ├── server/             # Серверные скрипты (ServerScriptService)
│   │   ├── init.server.luau # Точка входа, автосохранение, BindToClose
│   │   ├── DataStoreManager.luau # Облачное сохранение/загрузка профилей
│   │   ├── PlotBuilder.luau # 3D-генератор базы, SFX, VFX, конвейер, кнопки
│   │   └── TycoonService.luau # Экономика, Rebirth, транзакции, leaderstats
│   └── shared/             # Общие модули (ReplicatedStorage)
│       ├── EconomyManager.luau
│       ├── MathUtils.luau
│       └── TycoonConfig.luau
├── tests/                  # Автотесты логики
│   ├── dataStore.test.js
│   ├── economyManager.test.js
│   ├── mathUtils.test.js
│   ├── plotBuilder.test.js
│   └── rebirth.test.js
├── default.project.json    # Rojo маппинг в Roblox DataModel
├── package.json            # Node.js конфигурация и скрипты (test, serve, build)
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
