---
name: roblox-lighting-themes
description: >-
  Профессиональные кинематографические пресеты освещения и атмосферы для Roblox (Future Lighting):
  Atmosphere, Bloom, ColorCorrection, Skybox, цветовая гармония и мгновенное применение тем
  (Cyberpunk, Sunset, Midnight Sci-Fi, Candy Dream, Wasteland, Clean Studio).
---

# Roblox Lighting & Theme Presets (Cinematic Lighting)

Готовые рецепты освещения на базе технологии **Future Lighting** для создания визуально привлекательного плейса (высокий CTR и удержание).

---

## 1. Базовые требования к освещению в `Lighting`

Для того чтобы 3D-сцена выглядела современно, в корневом сервисе `Lighting` должны быть настроены эффекты:
1. `Technology = Enum.Technology.Future` (реалистичные тени и точечный свет).
2. Наличие дочерних эффектов:
   * `Atmosphere` (реалистичная дымка горизонта).
   * `BloomEffect` (свечение неоновых деталей).
   * `ColorCorrectionEffect` (контрастность и цветовой оттенок).
   * `SunRaysEffect` (лучи солнца сквозь проемы и крыши).

---

## 2. Каталог 6 проверенных стилей

| Стиль | Час (ClockTime) | Ambient / Outdoor | Настроение | Идеально для жанра |
| :--- | :--- | :--- | :--- | :--- |
| **CyberpunkNeon** | `0.5` (Ночь) | Фиолетовый / Пурпурный | Контрастный неоновый город | PvP Арены, Sci-Fi Тайкуны |
| **SunsetGlow** | `17.5` (Закат) | Теплый золотой / Оранжевый | Уют, кинематографичность | Симуляторы, RPG, Острова |
| **MidnightSciFi** | `22.0` (Полночь) | Темно-синий / Холодный | Космос, технологии | Базы, Космические шутеры |
| **CandyDream** | `14.0` (День) | Пастельный розовый / Белый | Радость, праздник, легкость | Pet Sim, Казуальные игры |
| **ToxicWasteland** | `16.0` (Смог) | Оливковый / Серый | Постапокалипсис, опасность | Выживание, Зомби-режимы |
| **CleanStudio** | `14.0` (Полдень) | Нейтральный серый | Чистый свет без бликов | Классические тайкуны, Обби |

---

## 3. Код применения пресета (`ApplyTheme`)

```lua
--!strict
local Lighting = game:GetService("Lighting")

function ApplyTheme(preset: {
    Ambient: Color3,
    OutdoorAmbient: Color3,
    Brightness: number,
    ClockTime: number,
    FogColor: Color3,
    AtmosphereDensity: number,
    BloomIntensity: number,
})
    Lighting.Ambient = preset.Ambient
    Lighting.OutdoorAmbient = preset.OutdoorAmbient
    Lighting.Brightness = preset.Brightness
    Lighting.ClockTime = preset.ClockTime
    Lighting.FogColor = preset.FogColor

    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then atmo.Density = preset.AtmosphereDensity end

    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if bloom then bloom.Intensity = preset.BloomIntensity end
end
```
