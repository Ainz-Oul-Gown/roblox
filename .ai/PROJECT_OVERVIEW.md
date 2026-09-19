# Project Overview: Gen Alpha Brainrot Multiplayer Tycoon

## Описание проекта
**Gen Alpha Brainrot Multiplayer Tycoon** — мультиплеерный тайкун на **8 игроков** в стилистике интернет-культуры поколения Альфа (Skibidi, Mewing, Sigma, Fanum Tax, Grimace, CaseOh, Rizzler, Tung Tung). Проект включает 8 круговых баз вокруг центральной боевой арены, интерактивное меню выбора базы/фракции (`FactionSelectModal`), физические стартовые площадки (`ClaimPad`), 8 уникальных суперспособностей, лазерную защиту базы, 5 уровней Rebirth и современный экранный HUD.

## Стек технологий
- **Платформа**: Roblox
- **Инструмент синхронизации**: Rojo v7.7.0 (бинарник в `bin/rojo.exe`, плагин в `%LocalAppData%\Roblox\Plugins\Rojo.rbxm`)
- **Язык**: Luau (strict typing `--!strict`)
- **Мультиплеер**: 8 независимых баз по круговой сетке ($R = 90$ studs), меню выбора фракции, центральная зона царя горы `(0, 0, 0)`
- **Сохранение**: Roblox DataStoreService (`TycoonSave_v1`)
- **Тестирование**: Node.js Test Runner (`npm test`, 22 юнит-теста)
- **CI/CD**: GitHub Actions (`.github/workflows/ci.yml`)
- **Контроль версий**: Git + GitHub (`Ainz-Oul-Gown/roblox`)

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
   - Нажать кнопку **Play (F5)** в Roblox Studio. Откроется окно выбора базы с 8 карточками фракций, а на карте появятся все 8 площадок с ClaimPad.
