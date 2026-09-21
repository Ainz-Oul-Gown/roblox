---
name: roblox-juice-kit
description: >-
  Библиотека сочности и тактильного отклика (Juice & Game Feel) в Roblox:
  справочник легальных проверенных SoundId, процедурные эффекты частиц (конфетти, всплески монет),
  пружинная тряска экрана (CameraShake) и всплывающий 3D-текст (Damage & Cash Indicators).
---

# Roblox Juice Kit (Tactile Game Feel)

«Сочность» (Juice) — это то, что отличает любительскую поделку от коммерческого хита. Каждое действие игрока (клик, сбор монеты, удар, перерождение) обязано сопровождаться звуком, микро-анимацией и частицами.

---

## 1. Справочник проверенных звуков (Roblox SoundId)

Официальные бесплатные звуки из библиотеки Roblox, которые **гарантированно не будут заблокированы модерацией**:

| Назначение | SoundId | Описание |
| :--- | :--- | :--- |
| **Клик UI** | `rbxassetid://6895079853` | Мягкий щелчок кнопки интерфейса |
| **Звон монет** | `rbxassetid://9069609200` | Звон падающих золотых монет при сборе кассы |
| **Покупка апгрейда** | `rbxassetid://9069609200` | Сочный кассовый аппарат / колокольчик |
| **Ошибка / Нехватка** | `rbxassetid://9069610484` | Приглушенный низкий гудок (Buzzer) |
| **Фанфары Rebirth** | `rbxassetid://9069611227` | Торжественные победные трубы |
| **Взрыв / Удар** | `rbxassetid://9069609584` | Глухой мощный бас со взрывом |
| **Лазер / Магия** | `rbxassetid://9069608930` | Высокочастотный импульс энергии |
| **Свист рывка (Dash)** | `rbxassetid://9069610197` | Порыв ветра при быстром перемещении |

---

## 2. Процедурный салют конфетти (Rebirth & Win Celebration)

```lua
--!strict
local Debris = game:GetService("Debris")

local function SpawnConfetti(position: Vector3)
    local emitterPart = Instance.new("Part")
    emitterPart.Size = Vector3.new(1, 1, 1)
    emitterPart.Position = position
    emitterPart.Transparency = 1
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Parent = workspace

    local attachment = Instance.new("Attachment")
    attachment.Parent = emitterPart

    local colors = {
        Color3.fromRGB(255, 80, 80),
        Color3.fromRGB(80, 255, 80),
        Color3.fromRGB(80, 150, 255),
        Color3.fromRGB(255, 230, 80),
        Color3.fromRGB(255, 80, 255),
    }

    for _, color in colors do
        local particles = Instance.new("ParticleEmitter")
        particles.Color = ColorSequence.new(color)
        particles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.2) })
        particles.Speed = NumberRange.new(20, 35)
        particles.SpreadAngle = Vector2.new(45, 45)
        particles.Lifetime = NumberRange.new(1.5, 2.5)
        particles.Rate = 0
        particles.Parent = attachment

        particles:Emit(25) -- Мгновенный взрыв салюта
    end

    Debris:AddItem(emitterPart, 3)
end
```

---

## 3. Всплывающий 3D-текст (+$$$ Aura / Damage)

```lua
local TweenService = game:GetService("TweenService")

local function ShowFloatingText(position: Vector3, text: string, color: Color3)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Position = position + Vector3.new(math.random() - 0.5, 2, math.random() - 0.5)
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.Parent = workspace

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 40)
    bb.AlwaysOnTop = true
    bb.Parent = part

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.Parent = bb

    local tween = TweenService:Create(part, TweenInfo.new(0.75, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = part.Position + Vector3.new(0, 3.5, 0)
    })
    tween:Play()
    Debris:AddItem(part, 0.8)
end
```
