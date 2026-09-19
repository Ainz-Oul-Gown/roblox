# Конвенции разработки и стандарты кода

## 1. Стиль Luau
- **Строгая типизация**: Всегда начинать файлы с директивы `--!strict`.
- **Именование файлов**:
  - Модули: `PascalCase.luau` (например, `MathUtils.luau`, `EconomyManager.luau`).
  - Серверные скрипты: `*.server.luau` или `init.server.luau`.
  - Клиентские скрипты: `*.client.luau` или `init.client.luau`.
- **Именование переменных и функций**:
  - Локальные переменные и функции: `camelCase` (`local playerLevel = 1`).
  - Экспортируемые функции модулей: `PascalCase` или `camelCase` (`TycoonService.purchaseItem`, `MathUtils.clamp`).
  - Константы: `UPPER_SNAKE_CASE` (`local STARTING_CASH = 0`).

## 2. Тестирование и качество
- Для каждого нового модуля **обязательно** создается соответствующий юнит-тест в каталоге `tests/`.
- Тесты проверяют граничные условия, обработку невалидных входных данных и штатные сценарии.
- Все тесты должны успешно проходить локально перед пушем:
  ```powershell
  npm test
  ```

## 3. Процесс коммитов и CI/CD
- Сообщения коммитов формируются по стандарту Conventional Commits (например, `feat: add tycoon economy and configuration`).
- При каждом пуше на GitHub автоматически запускается GitHub Actions workflow (`.github/workflows/ci.yml`).
- Обязательно проверять успешность выполнения Actions перед завершением задачи.
