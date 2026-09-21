---
name: roblox-ci-cd-opencloud
description: >-
  Автоматизация CI/CD для Roblox: настройка GitHub Actions, запуск модульных тестов,
  сборка .rbxl через Rojo и автоматическая публикация в плейс через Roblox Open Cloud API.
---

# Roblox CI/CD & Open Cloud Deployment

Пайплайн непрерывной интеграции и доставки (CI/CD) для автоматического тестирования и деплоя игр в Roblox.

---

## 1. Шаблон GitHub Actions (`.github/workflows/ci.yml`)

```yaml
name: CI & Auto-Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test_and_lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: npm ci || npm install

      - name: Run Unit Tests
        run: npm test

  deploy:
    needs: test_and_lint
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Aftman
        uses: ok-nick/setup-aftman@v0.4.2

      - name: Build Place File
        run: rojo build default.project.json -o build.rbxl

      - name: Deploy to Roblox via Open Cloud
        env:
          ROBLOX_API_KEY: ${{ secrets.ROBLOX_OPEN_CLOUD_KEY }}
          UNIVERSE_ID: ${{ secrets.ROBLOX_UNIVERSE_ID }}
          PLACE_ID: ${{ secrets.ROBLOX_PLACE_ID }}
        run: |
          curl -X POST \
            "https://apis.roblox.com/universes/v1/${UNIVERSE_ID}/places/${PLACE_ID}/versions?versionType=Published" \
            -H "x-api-key: ${ROBLOX_API_KEY}" \
            -H "Content-Type: application/octet-stream" \
            --data-binary @build.rbxl
```

---

## 2. Настройка Roblox Open Cloud API Key

1. Перейдите в **Creator Hub** -> **Open Cloud** -> **API Keys**.
2. Создайте новый ключ с правами:
   * **Universe**: Выберите вашу игру.
   * **Permissions**: `Publish Place` (Запись версий плейса).
3. Добавьте секреты в репозиторий GitHub (**Settings** -> **Secrets and variables** -> **Actions**):
   * `ROBLOX_OPEN_CLOUD_KEY`
   * `ROBLOX_UNIVERSE_ID`
   * `ROBLOX_PLACE_ID`

---

## 3. Проверка статуса деплоя через GitHub API

Для проверки состояния Action из скриптов и терминала:
```powershell
# Получить последние запуски Actions:
curl -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<OWNER>/<REPO>/actions/runs?per_page=1
```
