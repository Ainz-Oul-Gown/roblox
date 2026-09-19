# Project Overview: roblox (Tycoon)

## Описание проекта
Проект **roblox** — это тайкун для платформы Roblox с синхронизацией через **Rojo** и типизированной кодовой базой на **Luau**.

## Стек технологий
- **Платформа**: Roblox
- **Инструмент синхронизации**: Rojo v7.7.0 (бинарник в `bin/rojo.exe`, плагин в `%LocalAppData%\Roblox\Plugins\Rojo.rbxm`)
- **Язык**: Luau (strict mode `--!strict`)
- **Тестирование**: Node.js Test Runner (`npm test`, 9 юнит-тестов)
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
│   │   └── init.client.luau
│   ├── server/             # Серверные скрипты (ServerScriptService)
│   │   ├── init.server.luau
│   │   └── TycoonService.luau
│   └── shared/             # Общие модули (ReplicatedStorage)
│       ├── EconomyManager.luau
│       ├── MathUtils.luau
│       └── TycoonConfig.luau
├── tests/                  # Автотесты логики
│   ├── economyManager.test.js
│   └── mathUtils.test.js
├── default.project.json    # Rojo маппинг в Roblox DataModel
├── package.json            # Node.js конфигурация и скрипты (test, serve, build)
└── .gitignore
```

## Быстрый старт
1. **Тестирование**:
   ```powershell
   npm test
   ```
2. **Запуск локального сервера Rojo**:
   ```powershell
   npm run serve
   ```
   (Затем в Roblox Studio нажать кнопку Rojo -> Connect).
3. **Сборка файла плейса**:
   ```powershell
   npm run build
   ```
