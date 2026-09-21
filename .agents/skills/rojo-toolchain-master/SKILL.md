---
name: rojo-toolchain-master
description: >-
  Руководство и стандарты работы со стеком Rojo: настройка default.project.json,
  запуск лайв-синхронизации (rojo serve), сборка плейсов (rojo build), sourcemap
  для автокомплита и управление утилитами через Aftman/Foreman.
---

# Rojo Toolchain Master Guide

Этот навык определяет стандарты сборки, синхронизации и конфигурации проектов Roblox с использованием инструмента **Rojo**.

---

## 1. Структура `default.project.json`

Типовой профессиональный маппинг сервисов Roblox на файловую структуру:

```json
{
  "name": "RobloxProject",
  "tree": {
    "$className": "DataModel",

    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "Shared": {
        "$path": "src/shared"
      },
      "Packages": {
        "$path": "Packages"
      }
    },

    "ServerScriptService": {
      "$className": "ServerScriptService",
      "Server": {
        "$path": "src/server"
      },
      "ServerPackages": {
        "$path": "ServerPackages"
      }
    },

    "StarterPlayer": {
      "$className": "StarterPlayer",
      "StarterPlayerScripts": {
        "$className": "StarterPlayerScripts",
        "Client": {
          "$path": "src/client"
        }
      }
    },

    "Workspace": {
      "$className": "Workspace",
      "$properties": {
        "FilteringEnabled": true
      }
    },

    "Lighting": {
      "$className": "Lighting",
      "$properties": {
        "Technology": "Future"
      }
    }
  }
}
```

---

## 2. Основные команды CLI

### Запуск лайв-синхронизации со Studio:
```powershell
# Запуск локального сервера синхронизации на порту 34872
rojo serve
# или через локальный бинарник
./bin/rojo.exe serve
```
*После запуска в Roblox Studio нажать кнопку **Connect** в официальном плагине Rojo.*

### Сборка плейса в файл:
```powershell
# Сборка в бинарный файл Roblox (.rbxl)
rojo build default.project.json -o build.rbxl

# Сборка в XML формат (удобно для diff и отладки метаданных)
rojo build default.project.json -o build.rbxlx
```

### Генерация `sourcemap.json`:
Необходима для работы LSP (автокомплит путей в VS Code / Antigravity) и генерации типов пакетов:
```powershell
rojo sourcemap default.project.json --output sourcemap.json
```

---

## 3. Соглашения по наименованию файлов в Rojo

Rojo определяет класс инстанса по суффиксу имени файла:

| Суффикс файла | Создаваемый класс в Roblox | Где используется |
| :--- | :--- | :--- |
| `name.server.luau` | `Script` (`RunContext = Legacy` или `Server`) | Серверный код в `ServerScriptService` |
| `name.client.luau` | `LocalScript` (`RunContext = Legacy` или `Client`) | Клиентский код в `StarterPlayerScripts` |
| `name.luau` | `ModuleScript` | Библиотеки, сервисы, общие модули |
| `init.luau` | `ModuleScript` (превращает папку в модуль) | Модули с вложенными подмодулями |
| `init.server.luau` | `Script` в корне папки | Главная точка входа сервера |
| `init.client.luau` | `LocalScript` в корне папки | Главная точка входа клиента |

---

## 4. Чек-лист проверки синхронизации
1. `rojo serve` запущен и слушает порт (по умолчанию `localhost:34872`).
2. В файле `default.project.json` пути `$path` соответствуют реальным каталогам в файловой системе.
3. В `sourcemap.json` нет циклических ссылок.
4. Отсутствуют конфликты имен файлов (например, нельзя иметь `Foo.luau` и `Foo.server.luau` в одной папке).
