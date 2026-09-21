--!strict

local Lighting = game:GetService("Lighting")

export type ThemeSettings = {
    name: string,
    ambient: Color3,
    outdoorAmbient: Color3,
    brightness: number,
    clockTime: number,
    fogColor: Color3,
    fogEnd: number,
    atmosphereDensity: number,
    bloomIntensity: number,
    bloomSize: number,
}

local LightingThemes = {
    THEMES = {
        CyberpunkNeon = {
            name = "Cyberpunk Neon",
            ambient = Color3.fromRGB(80, 50, 110),
            outdoorAmbient = Color3.fromRGB(60, 40, 95),
            brightness = 2.2,
            clockTime = 0.5, -- Глубокая ночь с ярким неоном
            fogColor = Color3.fromRGB(30, 15, 55),
            fogEnd = 500,
            atmosphereDensity = 0.45,
            bloomIntensity = 1.6,
            bloomSize = 24,
        } :: ThemeSettings,

        SunsetGlow = {
            name = "Sunset Glow",
            ambient = Color3.fromRGB(150, 115, 110),
            outdoorAmbient = Color3.fromRGB(180, 120, 90),
            brightness = 2.6,
            clockTime = 17.5, -- Золотой закат
            fogColor = Color3.fromRGB(200, 130, 80),
            fogEnd = 650,
            atmosphereDensity = 0.35,
            bloomIntensity = 1.0,
            bloomSize = 18,
        } :: ThemeSettings,

        MidnightSciFi = {
            name = "Midnight Sci-Fi",
            ambient = Color3.fromRGB(70, 90, 120),
            outdoorAmbient = Color3.fromRGB(50, 70, 100),
            brightness = 1.8,
            clockTime = 22.0,
            fogColor = Color3.fromRGB(15, 25, 45),
            fogEnd = 450,
            atmosphereDensity = 0.4,
            bloomIntensity = 1.2,
            bloomSize = 20,
        } :: ThemeSettings,

        CandyDream = {
            name = "Candy Dream",
            ambient = Color3.fromRGB(175, 155, 185),
            outdoorAmbient = Color3.fromRGB(190, 170, 200),
            brightness = 3.2,
            clockTime = 14.0, -- Солнечный день
            fogColor = Color3.fromRGB(240, 200, 230),
            fogEnd = 800,
            atmosphereDensity = 0.25,
            bloomIntensity = 0.8,
            bloomSize = 16,
        } :: ThemeSettings,

        ToxicWasteland = {
            name = "Toxic Wasteland",
            ambient = Color3.fromRGB(90, 120, 80),
            outdoorAmbient = Color3.fromRGB(80, 110, 70),
            brightness = 1.6,
            clockTime = 16.0,
            fogColor = Color3.fromRGB(60, 90, 50),
            fogEnd = 350,
            atmosphereDensity = 0.55,
            bloomIntensity = 1.4,
            bloomSize = 28,
        } :: ThemeSettings,

        CleanStudio = {
            name = "Clean Studio",
            ambient = Color3.fromRGB(155, 155, 170),
            outdoorAmbient = Color3.fromRGB(170, 170, 185),
            brightness = 2.5,
            clockTime = 14.0,
            fogColor = Color3.fromRGB(190, 200, 215),
            fogEnd = 1000,
            atmosphereDensity = 0.3,
            bloomIntensity = 0.6,
            bloomSize = 14,
        } :: ThemeSettings,
    },
}

function LightingThemes.applyTheme(themeName: string): boolean
    local theme = LightingThemes.THEMES[themeName]
    if not theme then
        warn(`[LightingThemes] Тема не найдена: {themeName}`)
        return false
    end

    Lighting.Ambient = theme.ambient
    Lighting.OutdoorAmbient = theme.outdoorAmbient
    Lighting.Brightness = theme.brightness
    Lighting.ClockTime = theme.clockTime
    Lighting.FogColor = theme.fogColor
    Lighting.FogEnd = theme.fogEnd

    -- Стандарт Future Lighting для сочных теней и реалистичного освещения
    pcall(function()
        Lighting.Technology = Enum.Technology.Future
    end)

    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "BrainrotAtmosphere"
        atmosphere.Parent = Lighting
    end
    atmosphere.Density = theme.atmosphereDensity
    atmosphere.Offset = 0.25
    atmosphere.Haze = 0.5

    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not bloom then
        bloom = Instance.new("BloomEffect")
        bloom.Name = "BrainrotBloom"
        bloom.Parent = Lighting
    end
    bloom.Intensity = theme.bloomIntensity
    bloom.Size = theme.bloomSize
    bloom.Threshold = 2.0 -- анти-ослепление экрана

    local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not colorCorrection then
        colorCorrection = Instance.new("ColorCorrectionEffect")
        colorCorrection.Name = "BrainrotColorCorrection"
        colorCorrection.Parent = Lighting
    end
    colorCorrection.Saturation = 0.15
    colorCorrection.Contrast = 0.12

    local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
    if not sunRays then
        sunRays = Instance.new("SunRaysEffect")
        sunRays.Name = "BrainrotSunRays"
        sunRays.Parent = Lighting
    end
    sunRays.Intensity = 0.12
    sunRays.Spread = 0.8

    print(`[LightingThemes] Успешно применена кинематографическая тема Future Lighting: {theme.name}`)
    return true
end

return LightingThemes
