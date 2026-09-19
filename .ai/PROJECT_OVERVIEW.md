# Project Overview: roblox

## Описание проекта
Проект **roblox** предназначен для разработки плейса / игры на платформе Roblox с использованием современного инструментария синхронизации **Rojo** и типизированного языка **Luau**.

## Стек технологий
- **Платформа**: Roblox
- **Инструмент синхронизации**: Rojo (конфигурация `default.project.json`)
- **Язык**: Luau (strict typing `--!strict`)
- **Тестирование**: Node.js Test Runner (`npm test`, `node:test`)
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
├── src/
│   ├── client/             # Клиентские скрипты (StarterPlayerScripts)
│   │   └── init.client.luau
│   ├── server/             # Серверные скрипты (ServerScriptService)
│   │   └── init.server.luau
│   └── shared/             # Общие модули (ReplicatedStorage)
│       └── MathUtils.luau
├── tests/                  # Автотесты логики
│   └── mathUtils.test.js
├── default.project.json    # Rojo маппинг в Roblox DataModel
├── package.json            # Node.js конфигурация и тестовые скрипты
└── .gitignore
```

## Быстрый старт
1. **Тестирование**:
   ```powershell
   npm test
   ```
2. **Сборка / Синхронизация с Roblox Studio через Rojo**:
   ```powershell
   rojo serve
   ```
   (Затем в плагине Rojo в Roblox Studio нажать Connect).
