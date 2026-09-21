---
name: roblox-modern-ui
description: >-
  Современная декларативная разработка пользовательского интерфейса (UI) в Roblox
  на базе Fusion / React-Lua: реактивное состояние, анимации пружин (Springs),
  компоненты кнопок, адаптивная верстка (UIAspectRatio/UIScale) под Mobile/PC.
---

# Modern Declarative UI in Roblox (Fusion Standards)

Руководство по созданию премиального, реактивного и анимированного интерфейса в коде без ручной сборки в Explorer Roblox Studio.

---

## 1. Концепция реактивного состояния

В декларативном UI интерфейс автоматически обновляется при изменении переменной состояния (`State` / `Value`):

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local New = Fusion.New
local State = Fusion.State
local Computed = Fusion.Computed
local Spring = Fusion.Spring

-- Переменные состояния
local cash = State(1500)
local isHovered = State(false)

-- Вычисляемое значение (автоматически форматирует баланс)
local formattedCash = Computed(function()
    return `💰 ${tostring(cash:get())}`
end)

-- Пружинная анимация для масштаба кнопки
local buttonScale = Spring(Computed(function()
    return isHovered:get() and 1.1 or 1.0
end), 25, 0.6)
```

---

## 2. Шаблон переиспользуемого компонента (JuicyButton)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)

local New = Fusion.New
local State = Fusion.State
local Spring = Fusion.Spring
local OnEvent = Fusion.OnEvent

type ButtonProps = {
    Text: string,
    Color: Color3,
    Size: UDim2,
    Position: UDim2,
    OnClick: () -> (),
}

local function JuicyButton(props: ButtonProps)
    local isPressed = State(false)
    local isHovered = State(false)

    local currentScale = Spring(Fusion.Computed(function()
        if isPressed:get() then
            return 0.92
        elseif isHovered:get() then
            return 1.05
        end
        return 1.0
    end), 30, 0.5)

    return New "TextButton" {
        Text = props.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 18,
        TextColor3 = Color3.new(1, 1, 1),
        BackgroundColor3 = props.Color,
        Size = props.Size,
        Position = props.Position,
        AnchorPoint = Vector2.new(0.5, 0.5),
        AutoButtonColor = false,

        [OnEvent "MouseButton1Down"] = function()
            isPressed:set(true)
        end,
        [OnEvent "MouseButton1Up"] = function()
            isPressed:set(false)
            props.OnClick()
        end,
        [OnEvent "MouseEnter"] = function()
            isHovered:set(true)
        end,
        [OnEvent "MouseLeave"] = function()
            isHovered:set(false)
            isPressed:set(false)
        end,

        [Fusion.Children] = {
            New "UICorner" {
                CornerRadius = UDim.new(0, 10),
            },
            New "UIStroke" {
                Color = Color3.new(1, 1, 1),
                Thickness = 2,
                Transparency = 0.3,
            },
            New "UIScale" {
                Scale = currentScale,
            },
        }
    }
end

return JuicyButton
```

---

## 3. Правила адаптивности (Mobile & Desktop)

1. **Используйте `UIAspectRatioConstraint`**:
   Гарантирует, что кнопки и карточки не растянутся и сохранят идеальные пропорции 16:9, 1:1 или 4:3 на ультрашироких мониторах и смартфонах.
2. **Используйте `UIScale` для общего зума**:
   Привязывайте корневой `UIScale.Scale` к разрешению экрана игрока (`Camera.ViewportSize`), чтобы интерфейс был комфортного физического размера для пальцев на смартфонах.
3. **Безопасная зона (`GuiService:GetGuiInset`)**:
   Всегда учитывайте вырез под фронтальную камеру смартфона и верхнюю системную панель Roblox.
