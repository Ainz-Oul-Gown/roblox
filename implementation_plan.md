# ФИНАЛЬНЫЙ ПЛАН ИСПРАВЛЕНИЙ v3 — Для исполняющего агента

> [!CAUTION]  
> Выполняй строго по порядку шагов 1→7. После ВСЕХ изменений: `npm test`, git push, обновить `.ai/`.  
> Все файлы в `x:\roblox\src\`. Все строки 1-indexed.

---

## ШАГ 1: Глухое окно 2 этажа

**Файл**: `src/server/PlotBuilder.luau`, **строки 801-807**  
**Действие**: УДАЛИТЬ целиком эти 7 строк (блок `rRight`).

```diff
-        -- Правая стена 2 этажа
-        local rRight = Instance.new("Part")
-        rRight.Size = Vector3.new(1, 10, 76)
-        rRight.CFrame = baseCF * CFrame.new(28, 19, 0)
-        rRight.Anchored = true
-        rRight.Color = Color3.fromRGB(40, 40, 48)
-        rRight.Parent = f2Walls
```

**Причина**: Цикл ниже (строки 811-854) уже создаёт правую стену X=28 с оконным проёмом. `rRight` — цельная стена поверх, блокирующая окно.

---

## ШАГ 2: Кнопка конвейера в проёме руды

**Файл**: `src/server/PlotBuilder.luau`, **строка ~1650** (таблица `BUTTON_CONFIGS`)

**Заменить**:
```lua
    Floor2_Conveyor = Vector3.new(0, 14.5, 6),
```
**На**:
```lua
    Floor2_Conveyor = Vector3.new(10, 14.5, 10),
```

---

## ШАГ 3: Дороги не соединяются с базами

**Файл**: `src/server/WorldBuilder.luau`, **строки 86-171**  
**Действие**: Заменить ВСЮ секцию `-- 3. Дороги` (от строки 86 до конца цикла фонарей на строке 171) на:

```lua
    -- 3. Дороги от центральной площади до входа каждой базы
    local total = TycoonConfig.TOTAL_PLOTS
    local ROAD_START = 22  -- край центральной площади (R=20 площадь + 2 отступ)
    local ROAD_END_DIST = BASE_RADIUS - 2  -- до входа базы
    for i = 1, total do
        local angle = (i - 1) * (2 * math.pi / total)
        local roadLength = ROAD_END_DIST - ROAD_START
        local midDist = (ROAD_START + ROAD_END_DIST) / 2

        local midX = midDist * math.cos(angle)
        local midZ = midDist * math.sin(angle)

        -- CFrame дороги: ось Z вдоль радиуса
        local roadCF = CFrame.new(
            midX, GROUND_Y + 0.3, midZ,
            math.cos(angle), 0, -math.sin(angle),
            0, 1, 0,
            math.sin(angle), 0, math.cos(angle)
        )

        -- Полотно дороги
        local road = makeAnchoredPart(
            worldFolder,
            string.format("Road_%d", i),
            Vector3.new(ROAD_WIDTH, 0.5, roadLength),
            roadCF,
            Color3.fromRGB(60, 60, 65),
            Enum.Material.SmoothPlastic
        )

        -- Бордюры по краям дороги (паттерн roblox-map-templates Road Kit)
        for _, side in ipairs({ -1, 1 }) do
            makeAnchoredPart(
                worldFolder,
                string.format("RoadCurb_%d_%d", i, side),
                Vector3.new(1.2, 0.8, roadLength),
                roadCF * CFrame.new(side * (ROAD_WIDTH / 2 + 0.6), 0.15, 0),
                Color3.fromRGB(45, 45, 50),
                Enum.Material.Concrete
            )
        end

        -- Центральная разделительная линия
        local line = makeAnchoredPart(
            worldFolder,
            string.format("RoadLine_%d", i),
            Vector3.new(0.8, 0.52, roadLength),
            roadCF,
            Color3.fromRGB(241, 196, 15),
            Enum.Material.Neon
        )
        line.CanCollide = false
        line.Transparency = 0.4

        -- Billboard с названием базы
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 80, 0, 60)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = false
        billboard.MaxDistance = 200
        billboard.Parent = road

        local faction = TycoonConfig.getFaction(i)
        local roadLabel = Instance.new("TextLabel")
        roadLabel.Size = UDim2.new(1, 0, 1, 0)
        roadLabel.BackgroundTransparency = 1
        roadLabel.Text = string.format("База %d\n%s", i, faction.name)
        roadLabel.TextColor3 = faction.color
        roadLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        roadLabel.TextStrokeTransparency = 0.2
        roadLabel.TextScaled = true
        roadLabel.Font = Enum.Font.FredokaOne
        roadLabel.Parent = billboard

        -- Фонари (2 шт на средней точке дороги)
        for s = -1, 1, 2 do
            local lampX = midX + math.sin(angle) * (ROAD_WIDTH / 2 + 1) * s
            local lampZ = midZ - math.cos(angle) * (ROAD_WIDTH / 2 + 1) * s

            makeAnchoredPart(
                worldFolder,
                string.format("Lamp_%d_%d", i, s),
                Vector3.new(0.5, 10, 0.5),
                CFrame.new(lampX, GROUND_Y + 5, lampZ),
                Color3.fromRGB(50, 50, 55),
                Enum.Material.Metal
            )

            local lampLight = makeAnchoredPart(
                worldFolder,
                string.format("LampLight_%d_%d", i, s),
                Vector3.new(1.5, 1, 1.5),
                CFrame.new(lampX, GROUND_Y + 10.5, lampZ),
                faction.color,
                Enum.Material.Neon,
                0.3
            )
            lampLight.CanCollide = false

            local light = Instance.new("PointLight")
            light.Range = 22
            light.Brightness = 1.2
            light.Color = faction.color
            light.Parent = lampLight
        end
    end
```

---

## ШАГ 4: Инвентарь при смене базы + потеря тулов при смерти

### 4A. AbilityService — добавить `clearPlayerTools` и `giveSpecificTool`

**Файл**: `src/server/AbilityService.luau`  
**Вставить ПЕРЕД строкой 156** (перед `function AbilityService.castAbility`):

```lua
-- Очистка всех тулов способностей (смена базы / ребирт)
function AbilityService.clearPlayerTools(player: Player)
    for _, container in ipairs({
        player:FindFirstChild("Backpack"),
        player:FindFirstChild("StarterGear"),
        player.Character,
    }) do
        if container then
            for _, tool in container:GetChildren() do
                if tool:IsA("Tool") and tool:GetAttribute("AbilitySlot") then
                    tool:Destroy()
                end
            end
        end
    end
end

-- Выдать один тул по слоту (вызов со стенда через ProximityPrompt)
function AbilityService.giveSpecificTool(player: Player, slot: AbilitySlot)
    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then return end
    local faction = TycoonConfig.getFaction(plotIndex)

    local abilityInfo, color
    if slot == "base" then abilityInfo = faction.baseAbility; color = faction.color
    elseif slot == "tactical" then abilityInfo = faction.tacticalAbility; color = faction.secondaryColor
    elseif slot == "ultimate" then abilityInfo = faction.ultimateAbility; color = faction.color
    elseif slot == "special" then abilityInfo = faction.specialAbility; color = Color3.fromRGB(168, 85, 247)
    elseif slot == "mobility" then abilityInfo = faction.mobilityAbility; color = Color3.fromRGB(6, 182, 212)
    else abilityInfo = faction.godmodeAbility; color = Color3.fromRGB(239, 68, 68) end

    createAbilityTool(player, slot, abilityInfo, color)
end
```

### 4B. Убрать авто-выдачу при респавне

**Файл**: `src/server/AbilityService.luau`, **строки 610-628**  
**Заменить на**:

```lua
-- Тулы НЕ выдаются при респавне — игрок забирает со стенда на базе
local function setupAbilityPlayer(_player: Player)
    -- Пустой: тулы выдаются только при покупке (onItemPurchased) или со стенда (ProximityPrompt)
end

Players.PlayerAdded:Connect(setupAbilityPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(setupAbilityPlayer, p)
end
```

### 4C. Очистка тулов при смене базы

**Файл**: `src/server/init.server.luau`, **строки 81-99**  
**Заменить функцию `onClaimBase` на**:

```lua
local function onClaimBase(player: Player, plotIndex: number)
    local currentPlotIndex = PlotManager.getPlayerPlotIndex(player)
    if currentPlotIndex == plotIndex then return end

    -- Очистка тулов старой фракции
    AbilityService.clearPlayerTools(player)

    if currentPlotIndex then
        local switched, oldIndex = PlotManager.switchPlot(player, plotIndex)
        if switched and oldIndex then
            PlotBuilder.resetPlotToUnclaimed(oldIndex, onClaimBase)
            PlotBuilder.activatePlot(player, plotIndex)
        end
    else
        local success = PlotManager.claimSpecificPlot(player, plotIndex)
        if success then
            PlotBuilder.activatePlot(player, plotIndex)
        end
    end
end
```

### 4D. ProximityPrompt на стендах — БЕЗ циклической зависимости

**Файл**: `src/server/PlotBuilder.luau`

**1)** После строки 29 (`local PlotBuilder = {}`) добавить:
```lua
-- Callback для выдачи тула со стенда (устанавливается из init.server.luau, чтобы избежать циклического require)
PlotBuilder.onStandPickup = nil :: ((player: Player, slotId: string) -> ())?
```

**2)** Изменить сигнатуру `createAbilityPedestal` (строка 181):
```lua
local function createAbilityPedestal(parent: Instance, id: string, cf: CFrame, title: string, subtitle: string, color: Color3, owner: Player?, slotId: string?)
```

**3)** После строки 217 (`createBillboard(orb, ...)`) вставить:
```lua
    if owner and slotId then
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText = string.format("Забрать %s", title)
        prompt.ObjectText = subtitle
        prompt.MaxActivationDistance = 10
        prompt.HoldDuration = 0.3
        prompt.RequiresLineOfSight = false
        prompt.Parent = orb

        prompt.Triggered:Connect(function(triggerPlayer: Player)
            if triggerPlayer == owner and PlotBuilder.onStandPickup then
                PlotBuilder.onStandPickup(triggerPlayer, slotId)
            end
        end)
    end
```

**4)** Обновить ВСЕ 6 вызовов `createAbilityPedestal` — добавить `owner, slotId`:

| Строка | id | Добавить |
|--------|----|----------|
| ~463 | AbilityStand_1 | `, owner, "base"` |
| ~493 | AbilityStand_Tactical | `, owner, "tactical"` |
| ~1028 | AbilityStand_Ultimate | `, owner, "ultimate"` |
| ~1039 | AbilityStand_Special | `, owner, "special"` |
| ~1050 | AbilityStand_Mobility | `, owner, "mobility"` |
| ~1248 | AbilityStand_Godmode | `, owner, "godmode"` |

**5)** В `init.server.luau` после строки ~63 (после `PlotBuilder = require(...)`) добавить:
```lua
-- Подключаем callback для стендов (избегаем circular require)
task.defer(function()
    PlotBuilder.onStandPickup = function(player: Player, slotId: string)
        AbilityService.giveSpecificTool(player, slotId)
    end
end)
```

---

## ШАГ 5: Фиксы серверных эффектов способностей

### 5A. Sigma Parry + applyDamage с attacker

**Файл**: `src/server/AbilityService.luau`, **строки 62-71** — заменить `applyDamage`:

```lua
local function applyDamage(targetHum: Humanoid, rawDamage: number, attacker: Player?)
    local targetPlayer = Players:GetPlayerFromCharacter(targetHum.Parent)
    if targetPlayer then
        -- Sigma Parry: отражение 75% урона на атакующего
        if targetPlayer:GetAttribute("SigmaParryActive") then
            if attacker and attacker.Character then
                local aHum = attacker.Character:FindFirstChild("Humanoid") :: Humanoid?
                if aHum and aHum.Health > 0 then
                    aHum:TakeDamage(rawDamage * 0.75)
                end
            end
            return
        end
        local reduction = targetPlayer:GetAttribute("DamageReduction")
        if type(reduction) == "number" and reduction > 0 and reduction < 1 then
            rawDamage = rawDamage * (1 - reduction)
        end
    end
    targetHum:TakeDamage(rawDamage)
end
```

> [!IMPORTANT]
> После этого: найти ВСЕ вызовы `applyDamage(oHum, число)` в файле и добавить 3-й аргумент `, player)`. Их ~25 штук. Пример: `applyDamage(oHum, 25)` → `applyDamage(oHum, 25, player)`.

### 5B. Sigma Teleport — TakeDamage → applyDamage

**Строка 453**: `tHum:TakeDamage(45)` → `applyDamage(tHum, 45, player)`

### 5C. FanumTax Tactical — лужа без эффекта

**После строки 506** (`Debris:AddItem(puddle, 8)`), вставить:
```lua
            local puddleHits: { [number]: boolean } = {}
            puddle.Touched:Connect(function(hit)
                local touchChar = hit.Parent
                if not touchChar then return end
                local touchPlayer = Players:GetPlayerFromCharacter(touchChar)
                if not touchPlayer or touchPlayer == player then return end
                if puddleHits[touchPlayer.UserId] then return end
                puddleHits[touchPlayer.UserId] = true
                local touchHum = touchChar:FindFirstChild("Humanoid") :: Humanoid?
                if touchHum and touchHum.Health > 0 then
                    tagHumanoid(touchHum, player)
                    applyDamage(touchHum, 15, player)
                    local ps = touchHum.WalkSpeed
                    touchHum.WalkSpeed = 6
                    task.delay(3, function()
                        if touchHum.Parent then touchHum.WalkSpeed = ps end
                        puddleHits[touchPlayer.UserId] = nil
                    end)
                end
            end)
```

### 5D. Замена генерик-блока 4 фракций

**Строки 567-592**: Заменить `else -- Grimace, CaseOh, Rizzler, TungTung` на 4 `elseif`:

```lua
    elseif fId == "Grimace" then
        if slot == "base" then
            -- Shake Splash: конусная волна яда
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local toOther = oRoot.Position - root.Position
                        if toOther.Magnitude <= 22 and root.CFrame.LookVector:Dot(toOther.Unit) > 0.4 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 22, player)
                            local ps = oHum.WalkSpeed; oHum.WalkSpeed = 8
                            task.delay(3, function() if oHum.Parent then oHum.WalkSpeed = ps end end)
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- Purple Shield: щит + реген
            hum.MaxHealth = math.min(hum.MaxHealth + 40, 250)
            hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
            player:SetAttribute("DamageReduction", 0.35)
            task.delay(5, function() player:SetAttribute("DamageReduction", nil) end)
        elseif slot == "ultimate" then
            -- Purple Rain: AoE + подброс
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 30 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 60, player)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 35, 0)
                    end
                end
            end
        elseif slot == "special" then
            -- Shake Vortex: притягивание + урон
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = root.Position - oRoot.Position
                        if diff.Magnitude <= 28 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 30, player)
                            oRoot.AssemblyLinearVelocity = diff.Unit * 40 + Vector3.new(0, 10, 0)
                        end
                    end
                end
            end
        elseif slot == "mobility" then
            -- Grimace Slide
            root.AssemblyLinearVelocity = root.CFrame.LookVector * 75 + Vector3.new(0, 10, 0)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 14 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 30, player)
                    end
                end
            end
        else
            -- Grimace Tsunami: массовый нокдаун + хил
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 35 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 85, player)
                        oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 55 + Vector3.new(0, 30, 0)
                    end
                end
            end
            hum.Health = math.min(hum.MaxHealth, hum.Health + 60)
        end

    elseif fId == "CaseOh" then
        if slot == "base" then
            -- Black Hole Pull: стягивание к себе
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = root.Position - oRoot.Position
                        if diff.Magnitude <= 26 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 20, player)
                            oRoot.AssemblyLinearVelocity = diff.Unit * 50
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- Gravity Well: щит + ускорение
            local ps = TycoonService.getBaseWalkSpeed(player)
            hum.WalkSpeed = 26; player:SetAttribute("DamageReduction", 0.4)
            task.delay(6, function()
                if hum.Parent then hum.WalkSpeed = ps end
                player:SetAttribute("DamageReduction", nil)
            end)
        elseif slot == "ultimate" then
            -- Event Horizon: AoE + стан + высокий урон
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = root.Position - oRoot.Position
                        if diff.Magnitude <= 35 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 70, player)
                            oRoot.AssemblyLinearVelocity = diff.Unit * 60 + Vector3.new(0, 20, 0)
                            local ps2 = oHum.WalkSpeed; oHum.WalkSpeed = 0
                            task.delay(2.5, function() if oHum.Parent then oHum.WalkSpeed = ps2 end end)
                        end
                    end
                end
            end
        elseif slot == "special" then
            -- Mukbang Heal: полный хил
            hum.MaxHealth = math.min(hum.MaxHealth + 50, 250); hum.Health = hum.MaxHealth
        elseif slot == "mobility" then
            -- Belly Flop: прыжок + AoE при приземлении
            root.AssemblyLinearVelocity = Vector3.new(0, 80, 0) + root.CFrame.LookVector * 30
            task.delay(1.2, function()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                        local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 18 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 45, player)
                            oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 50 + Vector3.new(0, 25, 0)
                        end
                    end
                end
            end)
        else
            -- Singularity: телепорт врагов к себе + макс урон
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 90, player)
                        oRoot.CFrame = root.CFrame * CFrame.new(0, 5, -5)
                    end
                end
            end
        end

    elseif fId == "Rizzler" then
        if slot == "base" then
            -- Rizz Charm: ближайший враг оглушён
            local nearest, minD = nil :: Player?, 20
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if oRoot then
                        local d = (oRoot.Position - root.Position).Magnitude
                        if d < minD then minD = d; nearest = other end
                    end
                end
            end
            if nearest and nearest.Character then
                local oHum = nearest.Character:FindFirstChild("Humanoid") :: Humanoid?
                if oHum then
                    tagHumanoid(oHum, player); applyDamage(oHum, 25, player)
                    local ps = oHum.WalkSpeed; oHum.WalkSpeed = 0
                    task.delay(3, function() if oHum.Parent then oHum.WalkSpeed = ps end end)
                end
            end
        elseif slot == "tactical" then
            -- Heart Barrier: хил + ускорение
            hum.Health = math.min(hum.MaxHealth, hum.Health + 35)
            local ps = TycoonService.getBaseWalkSpeed(player); hum.WalkSpeed = 28
            task.delay(5, function() if hum.Parent then hum.WalkSpeed = ps end end)
        elseif slot == "ultimate" then
            -- Mega Rizz: AoE замедление + разворот врагов спиной
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 28 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 55, player)
                        oRoot.CFrame = CFrame.new(oRoot.Position, oRoot.Position - root.CFrame.LookVector)
                        local ps2 = oHum.WalkSpeed; oHum.WalkSpeed = 6
                        task.delay(3, function() if oHum.Parent then oHum.WalkSpeed = ps2 end end)
                    end
                end
            end
        elseif slot == "special" then
            -- Love Steal: кража 20% кеша + хил
            local nearest2, minD2 = nil :: Player?, 22
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if oRoot then
                        local d = (oRoot.Position - root.Position).Magnitude
                        if d < minD2 then minD2 = d; nearest2 = other end
                    end
                end
            end
            if nearest2 then
                local stolen = TycoonService.deductCash(nearest2, math.floor(TycoonService.getCash(nearest2) * 0.20))
                if stolen > 0 then TycoonService.addCashRaw(player, stolen) end
                hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
            end
        elseif slot == "mobility" then
            -- Heartbreak Dash: рывок + оглушение
            root.AssemblyLinearVelocity = root.CFrame.LookVector * 85 + Vector3.new(0, 15, 0)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 14 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 30, player)
                        local ps = oHum.WalkSpeed; oHum.WalkSpeed = 0
                        task.delay(2, function() if oHum.Parent then oHum.WalkSpeed = ps end end)
                    end
                end
            end
        else
            -- God of Rizz: полный хил + массовый стан + кража ауры
            hum.Health = hum.MaxHealth
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 30 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 70, player)
                        local ps = oHum.WalkSpeed; oHum.WalkSpeed = 0
                        task.delay(4, function() if oHum.Parent then oHum.WalkSpeed = ps end end)
                        local tax = TycoonService.deductCash(other, math.floor(TycoonService.getCash(other) * 0.15))
                        if tax > 0 then TycoonService.addCashRaw(player, tax) end
                    end
                end
            end
        end

    elseif fId == "TungTung" then
        if slot == "base" then
            -- Hammer Strike: направленный удар
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and oHum.Health > 0 then
                        local toOther = oRoot.Position - root.Position
                        if toOther.Magnitude <= 18 and root.CFrame.LookVector:Dot(toOther.Unit) > 0.5 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 30, player)
                            oRoot.AssemblyLinearVelocity = (toOther.Unit + Vector3.new(0, 0.6, 0)) * 55
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- Anvil Block: 80% DR + контратака при окончании
            player:SetAttribute("DamageReduction", 0.8)
            local ps = TycoonService.getBaseWalkSpeed(player); hum.WalkSpeed = 6
            task.delay(3, function()
                player:SetAttribute("DamageReduction", nil)
                if hum.Parent then hum.WalkSpeed = ps end
                if char.Parent then
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= player and other.Character then
                            local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                            local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                            if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 16 then
                                tagHumanoid(oHum, player); applyDamage(oHum, 35, player)
                                oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 45
                            end
                        end
                    end
                end
            end)
        elseif slot == "ultimate" then
            -- Earthquake: AoE подброс + высокий урон
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 65, player)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 55, 0)
                    end
                end
            end
        elseif slot == "special" then
            -- Forge Flame: 3 волны огня перед собой
            local look = root.CFrame.LookVector
            for i = 1, 3 do
                task.delay(i * 0.25, function()
                    if not char.Parent then return end
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= player and other.Character then
                            local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                            local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                            if oRoot and oHum and (oRoot.Position - (root.Position + look * (i * 10))).Magnitude <= 12 then
                                tagHumanoid(oHum, player); applyDamage(oHum, 22, player)
                            end
                        end
                    end
                end)
            end
        elseif slot == "mobility" then
            -- Hammer Launch: прыжок вверх
            root.AssemblyLinearVelocity = root.CFrame.LookVector * 60 + Vector3.new(0, 70, 0)
        else
            -- God Hammer: массовый урон + ускорение
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot = other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                    local oHum = other.Character:FindFirstChild("Humanoid") :: Humanoid?
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 30 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 85, player)
                        oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 60 + Vector3.new(0, 40, 0)
                    end
                end
            end
            hum.WalkSpeed = 30
            local psGod = TycoonService.getBaseWalkSpeed(player)
            task.delay(8, function() if hum.Parent then hum.WalkSpeed = psGod end end)
        end
```

> [!WARNING]
> Убедись что после `TungTung` end стоит финальный `end` закрывающий основной `if fId == "Skibidi" then ... end` блок. Структура: `if .. elseif .. elseif .. end` (один end для всего блока фракций).

---

## ШАГ 6: Обновить существующие вызовы applyDamage для Skibidi/Mewing/Sigma/FanumTax

Во ВСЕХ существующих блоках фракций (Skibidi строки ~209-303, Mewing ~305-386, Sigma ~388-474, FanumTax ~476-565), найти каждый вызов `applyDamage(oHum, число)` и заменить на `applyDamage(oHum, число, player)`.

Это ~25 замен. Используй `AllowMultiple = false` в replace и делай по одной, либо вручную. Пример:
- `applyDamage(oHum, 25)` → `applyDamage(oHum, 25, player)` 
- `applyDamage(oHum, 60)` → `applyDamage(oHum, 60, player)`
- и т.д.

---

## ШАГ 7: Тесты, пуш, обновление .ai

1. Обновить `tests/auditFixes.test.js` — добавить тесты на:
   - `clearPlayerTools` удаляет Tool с AbilitySlot
   - `giveSpecificTool` создаёт тул нужного слота
   - `applyDamage` с SigmaParryActive возвращает без урона
   - Кнопка Floor2_Conveyor не в зоне `X∈[-4,4], Z∈[3.5,11.5]`
   - Дороги: ROAD_START ≥ 22

2. `npm test` — все должно пройти
3. Git add + commit + push
4. Дождаться CI (GitHub Actions)
5. Обновить `.ai/ARCHITECTURE.md` и `.ai/PROJECT_OVERVIEW.md`:
   - Добавить: ProximityPrompt на стендах, потеря тулов при смерти
   - Обновить: 24 уникальные способности вместо 4 генерик
   - Обновить: дороги от R=22 до R=178 с бордюрами
   - Исправить: убран rRight дубликат стены
