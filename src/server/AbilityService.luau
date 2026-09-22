--!strict

--[=[
    AbilityService (Multi-Ability & Inventory Tools Edition - 6 Slots / 48 Abilities)
    Управляет 6 тематическими способностями для каждой из 8 баз (48 способностей всего):
    1. Базовая [E] (Слот 1) - AbilityStand_1
    2. Тактическая [R] (Слот 2) - AbilityStand_Tactical
    3. Ультимейт [Q] (Слот 3) - AbilityStand_Ultimate
    4. Спец-способность [F] (Слот 4) - AbilityStand_Special
    5. Мобильность [Z] (Слот 5) - AbilityStand_Mobility
    6. Финишер Бога [X] (Слот 6) - AbilityStand_Godmode

    Каждая способность выдается как предмет в Backpack (хотбар 1..6):
    игрок берет предмет в руки и нажимает [E] / кликает мышью (или жмет горячую клавишу) для применения!
    Все нанесенные повреждения помечаются тегом creator для 100% PvP-лута!
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig", 10))
local PlotManager = require(script.Parent:WaitForChild("PlotManager", 10))
local TycoonService = require(script.Parent:WaitForChild("TycoonService", 10))

local AbilityService = {}

export type AbilitySlot = "base" | "tactical" | "ultimate" | "special" | "mobility" | "godmode"

local function getOrCreateRemote(name: string): RemoteEvent
    local existing: any = ReplicatedStorage:FindFirstChild(name)
    if existing then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = ReplicatedStorage
    return remote
end

local abilityEvent = getOrCreateRemote("AbilityEvent")
local abilityVFXEvent = getOrCreateRemote("AbilityVFXEvent")

-- Кулдауны хранятся по ключу: userId_slot (P0-01: os.clock() для субсекундной точности)
local cooldowns: { [string]: number } = {}

-- P0-01: Серверный debounce на RemoteEvent (0.3с между вызовами)
local lastCastTime: { [number]: number } = {}

-- Пометка цели тегом создателя урона для PvP-лута кошелька
local function tagHumanoid(targetHum: Humanoid, attacker: Player)
    local old = targetHum:FindFirstChild("creator")
    if old then old:Destroy() end
    local tag = Instance.new("ObjectValue")
    tag.Name = "creator"
    tag.Value = attacker
    tag.Parent = targetHum
    Debris:AddItem(tag, 6)
end

local function applyDamage(targetHum: Humanoid, rawDamage: number, attacker: Player?)
    if targetHum.Health <= 0 then return end
    local targetPlayer = Players:GetPlayerFromCharacter(targetHum.Parent)
    -- 1. Invulnerable
    if targetPlayer and targetPlayer:GetAttribute("Invulnerable") then return end
    -- 2. SigmaParryActive: reflect 75% back
    if targetPlayer and targetPlayer:GetAttribute("SigmaParryActive") then
        if attacker and attacker.Character then
            local aHum = attacker.Character:FindFirstChildOfClass("Humanoid")
            if aHum and aHum.Health > 0 then aHum:TakeDamage(rawDamage * 0.75) end
        end
        return
    end
    -- 3. ReflectDamage: copy % back (Mewing tactical 40%)
    if targetPlayer then
        local ref = targetPlayer:GetAttribute("ReflectDamage")
        if type(ref) == "number" and ref > 0 and attacker and attacker.Character then
            local aHum = attacker.Character:FindFirstChildOfClass("Humanoid")
            if aHum and aHum.Health > 0 then aHum:TakeDamage(rawDamage * ref) end
        end
    end
    -- 4. DamageReduction
    if targetPlayer then
        local red = targetPlayer:GetAttribute("DamageReduction")
        if type(red) == "number" and red > 0 and red < 1 then rawDamage = rawDamage * (1 - red) end
    end
    -- 5. DamageVulnerability (Rizzler godmode: +100%)
    if targetPlayer then
        local vuln = targetPlayer:GetAttribute("DamageVulnerability")
        if type(vuln) == "number" and vuln > 0 then rawDamage = rawDamage * (1 + vuln) end
    end
    -- 6. SigmaCritActive: fixed 90 dmg
    if attacker and attacker:GetAttribute("SigmaCritActive") then
        rawDamage = 90
        attacker:SetAttribute("SigmaCritActive", false)
    end
    -- 7. DoubleDamage (Mewing godmode)
    if attacker and attacker:GetAttribute("DoubleDamage") then rawDamage = rawDamage * 2 end
    -- 8. TripleDamage (Sigma ultimate)
    if attacker and attacker:GetAttribute("TripleDamage") then rawDamage = rawDamage * 3 end
    targetHum:TakeDamage(rawDamage)
end

-- Safe stun: anti-stun-lock, respects StunImmune
local activeStunThreads: { [number]: thread } = {}
local function applyStun(targetHum: Humanoid, duration: number)
    if not targetHum.Parent then return end
    local tp = Players:GetPlayerFromCharacter(targetHum.Parent)
    if tp and tp:GetAttribute("StunImmune") then return end
    local uid = tp and tp.UserId or 0
    if uid > 0 and activeStunThreads[uid] then
        task.cancel(activeStunThreads[uid]); activeStunThreads[uid] = nil
    end
    local base = if tp then TycoonService.getBaseWalkSpeed(tp) else 16
    local prev = math.max(targetHum.WalkSpeed, base)
    targetHum.WalkSpeed = 0
    local t = task.delay(duration, function()
        if uid > 0 then activeStunThreads[uid] = nil end
        if targetHum and targetHum.Parent then targetHum.WalkSpeed = math.max(prev, base) end
    end)
    if uid > 0 then activeStunThreads[uid] = t end
end

-- Jump block (Birthday Eclipse)
local activeJumpThreads: { [number]: thread } = {}
local function applyJumpBlock(targetHum: Humanoid, duration: number)
    local tp = Players:GetPlayerFromCharacter(targetHum.Parent)
    local uid = tp and tp.UserId or 0
    if uid > 0 and activeJumpThreads[uid] then task.cancel(activeJumpThreads[uid]) end
    local pj = targetHum.JumpPower
    targetHum.JumpPower = 0
    activeJumpThreads[uid] = task.delay(duration, function()
        if uid > 0 then activeJumpThreads[uid] = nil end
        if targetHum and targetHum.Parent then targetHum.JumpPower = pj end
    end)
end

-- Clip blink: teleport through walls with floor detection
local function getClipBlinkCFrame(originCF: CFrame, dist: number): CFrame
    local tp = originCF.Position + originCF.LookVector * dist
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ig: { Instance } = {}
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ig, p.Character) end end
    rp.FilterDescendantsInstances = ig
    local hit = Workspace:Raycast(tp + Vector3.new(0, 10, 0), Vector3.new(0, -25, 0), rp)
    if hit then tp = hit.Position + Vector3.new(0, 3, 0) end
    return CFrame.new(tp) * originCF.Rotation
end

-- Victim-side VFX helpers
local function fireVictimVFX(vp: Player, fId: string, slot: string, dmg: number)
    abilityVFXEvent:FireClient(vp, "VICTIM_IMPACT", fId, slot, dmg)
end
local function fireBlind(vp: Player, dur: number)
    abilityVFXEvent:FireClient(vp, "BLIND", dur)
end

-- Block abilities (Rizzler ultimate)
local function applyAbilityBlock(tp: Player, duration: number)
    tp:SetAttribute("AbilityDisabled", true)
    task.delay(duration, function() if tp.Parent then tp:SetAttribute("AbilityDisabled", false) end end)
end

-- Создание и выдача Tool в инвентарь игрока
local function createAbilityTool(player: Player, slot: AbilitySlot, abilityInfo: TycoonConfig.AbilityInfo, factionColor: Color3)
    local slotNum = if slot == "base" then "1"
        elseif slot == "tactical" then "2"
        elseif slot == "ultimate" then "3"
        elseif slot == "special" then "4"
        elseif slot == "mobility" then "5"
        else "6"

    local toolName = string.format("[%s] %s", slotNum, abilityInfo.name)

    -- Удаляем старый такой же тул если есть
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local old = backpack:FindFirstChild(toolName)
        if old then old:Destroy() end
    end
    local starterGear = player:FindFirstChild("StarterGear")
    if starterGear then
        local old = starterGear:FindFirstChild(toolName)
        if old then old:Destroy() end
    end

    local function makeTool(): Tool
        local t = Instance.new("Tool")
        t.Name = toolName
        t.RequiresHandle = false
        t.CanBeDropped = false
        t.ToolTip = string.format("%s (Нажми [E] или кликни мышью для активации)", abilityInfo.desc)
        t:SetAttribute("AbilitySlot", slot)
        t:SetAttribute("Cooldown", abilityInfo.cooldown)
        -- P0-NEW-06 FIX: Удалён Tool.Activated на сервере — каст идёт только через RemoteEvent (клиент)
        return t
    end

    if backpack then
        makeTool().Parent = backpack
    end
    if starterGear then
        makeTool().Parent = starterGear
    end
end

-- Проверка и выдача доступных способностей игроку
function AbilityService.syncPlayerTools(player: Player)
    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then return end

    local faction = TycoonConfig.getFaction(plotIndex)
    local owned = TycoonService.getOwnedItems(player)

    -- 1. Базовая способность [1]
    if owned["AbilityStand_1"] then
        createAbilityTool(player, "base", faction.baseAbility, faction.color)
    end

    -- 2. Тактическая способность [2]
    if owned["AbilityStand_Tactical"] then
        createAbilityTool(player, "tactical", faction.tacticalAbility, faction.secondaryColor)
    end

    -- 3. Ультимативная способность [3]
    if owned["AbilityStand_Ultimate"] then
        createAbilityTool(player, "ultimate", faction.ultimateAbility, faction.color)
    end

    -- 4. Спец-способность [4]
    if owned["AbilityStand_Special"] then
        createAbilityTool(player, "special", faction.specialAbility, Color3.fromRGB(168, 85, 247))
    end

    -- 5. Мобильность [5]
    if owned["AbilityStand_Mobility"] then
        createAbilityTool(player, "mobility", faction.mobilityAbility, Color3.fromRGB(6, 182, 212))
    end

    -- 6. Финишер Бога [6]
    if owned["AbilityStand_Godmode"] then
        createAbilityTool(player, "godmode", faction.godmodeAbility, Color3.fromRGB(239, 68, 68))
    end
end

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

-- Вызов способности
function AbilityService.castAbility(player: Player, slot: AbilitySlot)
    local char = player.Character
    if not char then return end
    local root: BasePart? = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then return end
    if player:GetAttribute("AbilityDisabled") then
        abilityEvent:FireClient(player, "ERROR", "Способности заблокированы!", 0, slot)
        return
    end


    local plotIndex = PlotManager.getPlayerPlotIndex(player)
    if not plotIndex then
        abilityEvent:FireClient(player, "ERROR", "Сначала выбери базу!", 0, slot)
        return
    end

    local faction = TycoonConfig.getFaction(plotIndex)
    local abilityInfo = if slot == "base" then faction.baseAbility
        elseif slot == "tactical" then faction.tacticalAbility
        elseif slot == "ultimate" then faction.ultimateAbility
        elseif slot == "special" then faction.specialAbility
        elseif slot == "mobility" then faction.mobilityAbility
        else faction.godmodeAbility

    -- Проверка наличия предмета в тайкуне
    local requiredItem = if slot == "base" then "AbilityStand_1"
        elseif slot == "tactical" then "AbilityStand_Tactical"
        elseif slot == "ultimate" then "AbilityStand_Ultimate"
        elseif slot == "special" then "AbilityStand_Special"
        elseif slot == "mobility" then "AbilityStand_Mobility"
        else "AbilityStand_Godmode"

    if not TycoonService.hasItem(player, requiredItem) then
        abilityEvent:FireClient(player, "ERROR", "Сначала купи стойку этой способности на базе!", 0, slot)
        return
    end

    -- P0-01: Проверка кулдауна с os.clock() (субсекундная точность)
    local cdKey = string.format("%d_%s", player.UserId, slot)
    local now = os.clock()
    local lastCast = cooldowns[cdKey] or 0
    if now - lastCast < abilityInfo.cooldown then
        local rem = math.ceil(abilityInfo.cooldown - (now - lastCast))
        abilityEvent:FireClient(player, "COOLDOWN", "Перезарядка", rem, slot)
        return
    end
    cooldowns[cdKey] = now
    -- P1-02: Удалена мёртвая запись cooldowns[player.UserId]

    local fId = faction.id

    -- Запуск визуала на клиенте
    abilityEvent:FireClient(player, "CAST_SUCCESS", abilityInfo.name, abilityInfo.cooldown, slot)
    abilityVFXEvent:FireAllClients(player, fId, slot, root.Position, root.CFrame.LookVector)

    -- Применение эффектов в зависимости от фракции и слота:
    if fId == "Skibidi" then
        if slot == "base" then
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = oRoot.Position - root.Position
                        if diff.Magnitude <= 24 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 25, player)
                            oRoot.AssemblyLinearVelocity = (diff.Unit + Vector3.new(0, 0.8, 0)) * 60
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- P1-NEW-06 FIX: Скибиди Броня: -50% урона + ускорение на 6сек
            hum.WalkSpeed = 26
            local _prevSpeed = TycoonService.getBaseWalkSpeed(player)
            -- Устанавливаем атрибут защиты, который проверяется перед TakeDamage
            player:SetAttribute("DamageReduction", 0.5)
            task.delay(6, function()
                if hum.Parent then hum.WalkSpeed = _prevSpeed end
                player:SetAttribute("DamageReduction", nil)
            end)
        elseif slot == "ultimate" then
            -- P1-NEW-07 FIX: Мега-Смыв: притягивание + урон + оглушение на 3с
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = root.Position - oRoot.Position
                        if diff.Magnitude <= 35 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 60, player)
                            oRoot.AssemblyLinearVelocity = (diff.Unit + Vector3.new(0, 0.5, 0)) * 50
                            applyStun(oHum, 3)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 60) end
                        end
                    end
                end
            end
        elseif slot == "special" then
            -- Skibidi Dop Dop Anthem: оглушение + аура
            TycoonService.addCashRaw(player, 2500)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 25 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 20, player)
                        applyStun(oHum, 2.5)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then fireVictimVFX(ov, fId, slot, 20) end
                    end
                end
            end
        elseif slot == "mobility" then
            -- Скибиди Ракета: реактивный рывок
            local look = root.CFrame.LookVector
            root.AssemblyLinearVelocity = look * 95 + Vector3.new(0, 25, 0)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 14 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 35, player)
                        oRoot.AssemblyLinearVelocity = (look + Vector3.new(0, 0.5, 0)) * 55
                    end
                end
            end
        else
            -- A20+B7 FIX: StunImmune + серия из 4 AoE ударов каждые 2с
            local godBase = TycoonService.getBaseWalkSpeed(player)
            hum.WalkSpeed = 28
            player:SetAttribute("StunImmune", true)
            local function doTitanSlam()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 40, player)
                            oRoot.AssemblyLinearVelocity = Vector3.new(0, 55, 0)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 40) end
                        end
                    end
                end
                abilityVFXEvent:FireAllClients(player, fId, "godmode_slam", root.Position, root.CFrame.LookVector)
            end
            doTitanSlam()
            for i = 1, 3 do
                task.delay(i * 2, doTitanSlam)
            end
            task.delay(8, function()
                if hum.Parent then hum.WalkSpeed = godBase end
                if player.Parent then player:SetAttribute("StunImmune", false) end
            end)
        end

    elseif fId == "Mewing" then
        if slot == "base" then
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and oHum.Health > 0 then
                        local toOther = (oRoot.Position - root.Position)
                        if toOther.Magnitude <= 22 and root.CFrame.LookVector:Dot(toOther.Unit) > 0.3 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 20, player)
                            applyStun(oHum, 3)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 20) end
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- A4 FIX: ReflectDamage 40% + KnockbackImmune 5s (was: MaxHealth+30)
            player:SetAttribute("ReflectDamage", 0.4)
            player:SetAttribute("KnockbackImmune", true)
            task.delay(5, function()
                if player.Parent then
                    player:SetAttribute("ReflectDamage", nil)
                    player:SetAttribute("KnockbackImmune", false)
                end
            end)
        elseif slot == "ultimate" then
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 65, player)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 45, 0)
                    end
                end
            end
        elseif slot == "special" then
            -- B10 FIX: Looksmaxing Flash — ослепление жертв (fireBlind) + замедление
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 28 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 25, player)
                        applyStun(oHum, 1)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then
                            fireBlind(ov, 3)
                            fireVictimVFX(ov, fId, slot, 25)
                        end
                        -- Остаточное замедление после стана
                        local prevSp = oHum.WalkSpeed
                        task.delay(1.1, function()
                            if oHum and oHum.Parent then
                                oHum.WalkSpeed = math.max(4, prevSp * 0.25)
                                task.delay(3, function() if oHum.Parent then oHum.WalkSpeed = prevSp end end)
                            end
                        end)
                    end
                end
            end
        elseif slot == "mobility" then
            -- Гигачад Рывок
            local look = root.CFrame.LookVector
            root.AssemblyLinearVelocity = look * 85 + Vector3.new(0, 15, 0)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 15 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 40, player)
                        oRoot.AssemblyLinearVelocity = (look + Vector3.new(0, 0.4, 0)) * 60
                    end
                end
            end
        else
            -- A13+B11 FIX: DoubleDamage 7s + applyStun вместо Y=-30 (вдавливало в пол)
            hum.Health = hum.MaxHealth
            hum.WalkSpeed = 24
            local alphaBase = TycoonService.getBaseWalkSpeed(player)
            player:SetAttribute("DoubleDamage", true)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 30 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 50, player)
                        applyStun(oHum, 2.5)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 35, 0)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then fireVictimVFX(ov, fId, slot, 50) end
                    end
                end
            end
            task.delay(7, function()
                if hum.Parent then hum.WalkSpeed = alphaBase end
                if player.Parent then player:SetAttribute("DoubleDamage", false) end
            end)
        end

    elseif fId == "Sigma" then
        if slot == "base" then
            -- A14 FIX: Phonk Rage — double speed + DamageReduction 0.4
            local sigmaBase = TycoonService.getBaseWalkSpeed(player)
            hum.WalkSpeed = 32
            player:SetAttribute("DamageReduction", 0.4)
            task.delay(6, function()
                if hum.Parent then hum.WalkSpeed = sigmaBase end
                if player.Parent then player:SetAttribute("DamageReduction", nil) end
            end)
        elseif slot == "tactical" then
            player:SetAttribute("SigmaParryActive", true)
            task.delay(4, function() player:SetAttribute("SigmaParryActive", false) end)
        elseif slot == "ultimate" then
            -- B5 FIX: TripleDamage 5s (was: plain 55 dmg, no multiplier)
            player:SetAttribute("TripleDamage", true)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 28 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 55, player)
                        applyStun(oHum, 5)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then fireVictimVFX(ov, fId, slot, 55) end
                    end
                end
            end
            task.delay(5, function() if player.Parent then player:SetAttribute("TripleDamage", false) end end)
        elseif slot == "special" then
            -- Lone Wolf Grindset: невидимость + крит
            -- P1-13: Сохраняем оригинальные transparency
            local savedTransparency: { [BasePart]: number } = {}
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    savedTransparency[(p :: any) :: BasePart] = p.Transparency
                    p.Transparency = 0.9
                end
            end
            player:SetAttribute("SigmaCritActive", true)
            task.delay(5, function()
                player:SetAttribute("SigmaCritActive", false)
                if char.Parent then
                    for part, origTrans in pairs(savedTransparency) do
                        if part.Parent then
                            part.Transparency = origTrans
                        end
                    end
                end
            end)
        elseif slot == "mobility" then
            -- A3 FIX: Shadow Step — PivotTo + TELEPORT FireClient (без отставания серверной CFrame)
            local nearestTarget: Player? = nil
            local minDist = 45
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    if oRoot then
                        local d = (oRoot.Position - root.Position).Magnitude
                        if d < minDist then minDist = d; nearestTarget = other end
                    end
                end
            end
            if nearestTarget and nearestTarget.Character then
                local tRoot: BasePart? = nearestTarget.Character:FindFirstChild("HumanoidRootPart")
                local tHum = nearestTarget.Character:FindFirstChildOfClass("Humanoid")
                if tRoot and tHum then
                    local blinkCF = tRoot.CFrame * CFrame.new(0, 0, 4)
                    char:PivotTo(blinkCF)
                    root.AssemblyLinearVelocity = Vector3.zero
                    abilityEvent:FireClient(player, "TELEPORT", "ShadowStep", 0, blinkCF)
                    tagHumanoid(tHum, player)
                    applyDamage(tHum, 45, player)
                    local ov = Players:GetPlayerFromCharacter(nearestTarget.Character)
                    if ov then fireVictimVFX(ov, fId, slot, 45) end
                end
            else
                local blinkCF = getClipBlinkCFrame(root.CFrame, 30)
                char:PivotTo(blinkCF)
                root.AssemblyLinearVelocity = Vector3.zero
                abilityEvent:FireClient(player, "TELEPORT", "ShadowStep", 0, blinkCF)
            end
        else
            -- B6 FIX: Brazilian Phonk Overload — DoT 20/с × 8с (вместо одноразового 70 урона)
            local phonkBase = TycoonService.getBaseWalkSpeed(player)
            hum.WalkSpeed = 36
            local function lightningStrike()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 20, player)
                            oRoot.AssemblyLinearVelocity = Vector3.new(0, 35, 0)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 20) end
                        end
                    end
                end
                abilityVFXEvent:FireAllClients(player, fId, "godmode_lightning", root.Position, root.CFrame.LookVector)
            end
            for i = 0, 7 do
                task.delay(i, lightningStrike)
            end
            task.delay(8, function() if hum.Parent then hum.WalkSpeed = phonkBase end end)
        end

    elseif fId == "FanumTax" then
        if slot == "base" then
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 20 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 20, player)
                        local victimCash = TycoonService.getCash(other)
                        local tax = math.floor(victimCash * 0.15)
                        if tax > 0 then
                            local stolen = TycoonService.deductCash(other, tax)
                            if stolen > 0 then
                                -- P0-02: addCashRaw — без множителя для PvP-кражи
                                TycoonService.addCashRaw(player, stolen)
                            end
                        end
                        break
                    end
                end
            end
        elseif slot == "tactical" then
            local puddle = Instance.new("Part")
            puddle.Size = Vector3.new(12, 0.2, 12)
            puddle.CFrame = root.CFrame * CFrame.new(0, -2.8, -4)
            puddle.Anchored = true
            puddle.Material = Enum.Material.Ice
            puddle.Color = Color3.fromRGB(230, 126, 34)
            puddle.Parent = Workspace
            Debris:AddItem(puddle, 8)

            local puddleHits: { [number]: boolean } = {}
            puddle.Touched:Connect(function(hit)
                local touchChar = hit.Parent
                if not touchChar then return end
                local touchPlayer = Players:GetPlayerFromCharacter(touchChar)
                if not touchPlayer or touchPlayer == player then return end
                if puddleHits[touchPlayer.UserId] then return end
                puddleHits[touchPlayer.UserId] = true
                local touchHum = touchChar:FindFirstChildOfClass("Humanoid")
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
        elseif slot == "ultimate" then
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 40, player)
                        local victimCash = TycoonService.getCash(other)
                        local tax = math.floor(victimCash * 0.30)
                        if tax > 0 then
                            local stolen = TycoonService.deductCash(other, tax)
                            if stolen > 0 then
                                -- P0-02: addCashRaw — без множителя для PvP-кражи
                                TycoonService.addCashRaw(player, stolen)
                            end
                        end
                    end
                end
            end
            hum.Health = math.min(hum.MaxHealth, hum.Health + 50)
        elseif slot == "special" then
            -- Fries Carpet Bomb
            local look = root.CFrame.LookVector
            for i = 1, 3 do
                task.delay(i * 0.2, function()
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= player and other.Character then
                            local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                            local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                            if oRoot and oHum and (oRoot.Position - (root.Position + look * (i * 12))).Magnitude <= 14 then
                                tagHumanoid(oHum, player)
                                applyDamage(oHum, 18, player)
                                local _psFries = oHum.WalkSpeed
                                oHum.WalkSpeed = 6
                                task.delay(3, function() if oHum.Parent then oHum.WalkSpeed = _psFries end end)
                            end
                        end
                    end
                end)
            end
        elseif slot == "mobility" then
            -- A18 FIX: Cola Rocket Jump + AoE при приземлении
            root.AssemblyLinearVelocity = Vector3.new(0, 90, 0) + root.CFrame.LookVector * 45
            task.delay(1.8, function()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 16 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 35, player)
                            oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 55 + Vector3.new(0, 20, 0)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 35) end
                        end
                    end
                end
                abilityVFXEvent:FireAllClients(player, fId, "mobility_land", root.Position, Vector3.new(0, 1, 0))
            end)
        else
            -- A15 FIX: Пицца-Метеорит + Invulnerable 4с
            player:SetAttribute("Invulnerable", true)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 35 then
                        tagHumanoid(oHum, player)
                        applyDamage(oHum, 75, player)
                        oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 60
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then fireVictimVFX(ov, fId, slot, 75) end
                    end
                end
            end
            hum.Health = hum.MaxHealth
            task.delay(4, function() if player.Parent then player:SetAttribute("Invulnerable", false) end end)
        end

    elseif fId == "Grimace" then
        if slot == "base" then
            -- Shake Splash: конусная волна яда
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and oHum.Health > 0 then
                        local toOther = oRoot.Position - root.Position
                        if toOther.Magnitude <= 22 and root.CFrame.LookVector:Dot(toOther.Unit) > 0.4 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 22, player)
                            applyStun(oHum, 1.5)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 22) end
                            -- B17: DoT облако 3с
                            local prevSp = oHum.WalkSpeed
                            task.delay(1.6, function()
                                if oHum and oHum.Parent then
                                    oHum.WalkSpeed = math.max(6, prevSp * 0.4)
                                    task.delay(2, function() if oHum.Parent then oHum.WalkSpeed = prevSp end end)
                                end
                            end)
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- A9 FIX: Лужа под врагами + DoT (было: щит кастера)
            local puddle = Instance.new("Part")
            puddle.Size = Vector3.new(14, 0.2, 14)
            puddle.CFrame = root.CFrame * CFrame.new(0, -2.8, -6)
            puddle.Anchored = true
            puddle.Material = Enum.Material.Neon
            puddle.Color = Color3.fromRGB(128, 0, 200)
            puddle.Transparency = 0.5
            puddle.CanCollide = false
            puddle.Parent = Workspace
            Debris:AddItem(puddle, 6)
            local dotHits: { [number]: boolean } = {}
            puddle.Touched:Connect(function(hit)
                local tc = hit.Parent; if not tc then return end
                local tp2 = Players:GetPlayerFromCharacter(tc)
                if not tp2 or tp2 == player then return end
                if dotHits[tp2.UserId] then return end
                dotHits[tp2.UserId] = true
                local tHum = tc:FindFirstChildOfClass("Humanoid")
                if tHum and tHum.Health > 0 then
                    tagHumanoid(tHum, player)
                    applyDamage(tHum, 12, player)
                    applyStun(tHum, 2.5)
                    fireVictimVFX(tp2, fId, slot, 12)
                    task.delay(2.6, function() dotHits[tp2.UserId] = nil end)
                end
            end)
        elseif slot == "ultimate" then
            -- B12 FIX: Катаклизм Гримаса — DoT 15/с × 5с на арене (было: одноразовый 60)
            local function grimaceDoT()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and oHum.Health > 0 and (oRoot.Position - root.Position).Magnitude <= 50 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 15, player)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 15) end
                        end
                    end
                end
            end
            for i = 0, 4 do task.delay(i, grimaceDoT) end
        elseif slot == "special" then
            -- A10 FIX: Birthday Eclipse — JumpBlock 4с + DoT 15/с (было: vortex pull)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and oHum.Health > 0 and (oRoot.Position - root.Position).Magnitude <= 28 then
                        tagHumanoid(oHum, player)
                        applyJumpBlock(oHum, 4)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        for i = 0, 3 do
                            task.delay(i, function()
                                if oHum and oHum.Parent and oHum.Health > 0 then
                                    applyDamage(oHum, 15, player)
                                    if ov then fireVictimVFX(ov, fId, slot, 15) end
                                end
                            end)
                        end
                    end
                end
            end
        elseif slot == "mobility" then
            -- B13 FIX: Slime Jump + персистентная зона жижи 8с
            root.AssemblyLinearVelocity = root.CFrame.LookVector * 75 + Vector3.new(0, 35, 0)
            task.delay(1.0, function()
                if not char.Parent then return end
                local slimePart = Instance.new("Part")
                slimePart.Size = Vector3.new(12, 0.2, 12)
                slimePart.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0))
                slimePart.Anchored = true
                slimePart.Material = Enum.Material.Neon
                slimePart.Color = Color3.fromRGB(100, 0, 180)
                slimePart.Transparency = 0.4
                slimePart.CanCollide = false
                slimePart.Parent = Workspace
                Debris:AddItem(slimePart, 8)
                local slimeHits: { [number]: boolean } = {}
                slimePart.Touched:Connect(function(hit)
                    local tc = hit.Parent; if not tc then return end
                    local tp3 = Players:GetPlayerFromCharacter(tc)
                    if not tp3 or tp3 == player then return end
                    if slimeHits[tp3.UserId] then return end
                    slimeHits[tp3.UserId] = true
                    local tHum = tc:FindFirstChildOfClass("Humanoid")
                    if tHum and tHum.Health > 0 then
                        tagHumanoid(tHum, player)
                        applyDamage(tHum, 30, player)
                        applyStun(tHum, 3.5)
                        fireVictimVFX(tp3, fId, slot, 30)
                        task.delay(3.6, function() slimeHits[tp3.UserId] = nil end)
                    end
                end)
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 14 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 30, player)
                            applyStun(oHum, 3.5)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 30) end
                        end
                    end
                end
            end
        else
            -- A17 FIX: Grimace Godmode — стан 3.5с + 85 урона
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 35 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 85, player)
                        applyStun(oHum, 3.5)
                        oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 45 + Vector3.new(0, 20, 0)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then fireVictimVFX(ov, fId, slot, 85) end
                    end
                end
            end
            hum.Health = math.min(hum.MaxHealth, hum.Health + 40)
        end

    elseif fId == "CaseOh" then
        if slot == "base" then
            -- B1 FIX: Нокдаун вверх (был Black Hole Pull на себя)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and oHum.Health > 0 then
                        local toOther = oRoot.Position - root.Position
                        if toOther.Magnitude <= 18 and root.CFrame.LookVector:Dot(toOther.Unit) > 0.3 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 25, player)
                            oRoot.AssemblyLinearVelocity = Vector3.new(0, 70, 0)
                            applyStun(oHum, 0.8)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 25) end
                        end
                    end
                end
            end
        elseif slot == "tactical" then
            -- A11 FIX: Гравитационный купол — притягивает врагов в зону 6с (был: щит кастера)
            local gravStart = os.clock()
            local gravConn; gravConn = game:GetService("RunService").Heartbeat:Connect(function()
                if os.clock() - gravStart > 6 then gravConn:Disconnect(); return end
                if not char.Parent then gravConn:Disconnect(); return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        if oRoot and (oRoot.Position - root.Position).Magnitude <= 28 then
                            local pull = (root.Position - oRoot.Position).Unit * 12
                            oRoot.AssemblyLinearVelocity = oRoot.AssemblyLinearVelocity + pull
                        end
                    end
                end
            end)
        elseif slot == "ultimate" then
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and oHum.Health > 0 then
                        local diff = root.Position - oRoot.Position
                        if diff.Magnitude <= 35 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 70, player)
                            oRoot.AssemblyLinearVelocity = diff.Unit * 60 + Vector3.new(0, 20, 0)
                            applyStun(oHum, 2.5)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 70) end
                        end
                    end
                end
            end
        elseif slot == "special" then
            -- Mukbang Heal: полный хил
            hum.MaxHealth = math.min(hum.MaxHealth + 50, 250); hum.Health = hum.MaxHealth
        elseif slot == "mobility" then
            -- B2 FIX: Горизонтальный перекат + AoE при приземлении (был: прыжок вверх)
            local rollDir = root.CFrame.LookVector
            root.AssemblyLinearVelocity = rollDir * 100 + Vector3.new(0, 8, 0)
            abilityVFXEvent:FireAllClients(player, fId, "mobility_start", root.Position, rollDir)
            task.delay(0.7, function()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 20 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 45, player)
                            oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 55 + Vector3.new(0, 25, 0)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 45) end
                        end
                    end
                end
            end)
        else
            -- A12 FIX: Singularity — 50% hp среза + телепорт + 90 урона
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player)
                        local hpCut = oHum.Health * 0.5
                        applyDamage(oHum, hpCut, player)
                        applyDamage(oHum, 30, player)
                        oRoot.CFrame = root.CFrame * CFrame.new(0, 2, -5)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 30, 0)
                        applyStun(oHum, 1.5)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then fireVictimVFX(ov, fId, slot, 90) end
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
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    if oRoot then
                        local d = (oRoot.Position - root.Position).Magnitude
                        if d < minD then minD = d; nearest = other end
                    end
                end
            end
            if nearest and nearest.Character then
                local oHum = nearest.Character:FindFirstChildOfClass("Humanoid")
                if oHum then
                    tagHumanoid(oHum, player); applyDamage(oHum, 25, player)
                    applyStun(oHum, 3)
                    local ov = Players:GetPlayerFromCharacter(nearest.Character)
                    if ov then fireVictimVFX(ov, fId, slot, 25) end
                end
            end

        elseif slot == "tactical" then
            -- A7 FIX: Hypnosis 3.5s on nearest enemy (was: self heal+speed)
            local near3, minD3 = nil :: Player?, 30
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    if oRoot then
                        local d = (oRoot.Position - root.Position).Magnitude
                        if d < minD3 then minD3 = d; near3 = other end
                    end
                end
            end
            if near3 and near3.Character then
                local oHum = near3.Character:FindFirstChildOfClass("Humanoid")
                if oHum then
                    applyStun(oHum, 3.5)
                    near3:SetAttribute("HypnotizedBy", player.UserId)
                    task.delay(3.5, function() if near3.Parent then near3:SetAttribute("HypnotizedBy", nil) end end)
                    local ov = Players:GetPlayerFromCharacter(near3.Character)
                    if ov then fireVictimVFX(ov, fId, slot, 0) end
                end
            end

        elseif slot == "ultimate" then
            -- Mega Rizz: AoE замедление + разворот врагов спиной
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 28 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 50, player)
                        oRoot.CFrame = CFrame.new(oRoot.Position, oRoot.Position - root.CFrame.LookVector)
                        applyStun(oHum, 2)
                        local ov2 = Players:GetPlayerFromCharacter(other.Character)
                        if ov2 then
                            applyAbilityBlock(ov2, 5)
                            fireVictimVFX(ov2, fId, slot, 50)
                        end
                    end
                end
            end
        elseif slot == "special" then
            -- Love Steal: кража 20% кеша + хил
            local nearest2, minD2 = nil :: Player?, 22
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
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
            -- A2 FIX: Blink + explosion on arrival
            local blinkCF = getClipBlinkCFrame(root.CFrame, 20)
            char:PivotTo(blinkCF)
            root.AssemblyLinearVelocity = Vector3.zero
            abilityEvent:FireClient(player, "TELEPORT", "HeartbreakDash", 0, blinkCF)
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 14 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 30, player)
                        applyStun(oHum, 2)
                        local ov = Players:GetPlayerFromCharacter(other.Character)
                        if ov then fireVictimVFX(ov, fId, slot, 30) end
                    end
                end
            end
        else
            -- B4 FIX: God of Rizz - DamageVulnerability 100% + stun 7s
            hum.Health = hum.MaxHealth
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 30 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 70, player)
                        applyStun(oHum, 7)
                        local ov3 = Players:GetPlayerFromCharacter(other.Character)
                        if ov3 then
                            ov3:SetAttribute("DamageVulnerability", 1.0)
                            task.delay(7, function() if ov3.Parent then ov3:SetAttribute("DamageVulnerability", nil) end end)
                            fireVictimVFX(ov3, fId, slot, 70)
                        end
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
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
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
            -- A1 FIX: Anvil Drop — наковальня падает сверху на ближайшего врага
            local tNear, tDist = nil :: Player?, 30
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    if oRoot then
                        local d = (oRoot.Position - root.Position).Magnitude
                        if d < tDist then tDist = d; tNear = other end
                    end
                end
            end
            if tNear and tNear.Character then
                local oRoot: BasePart? = tNear.Character:FindFirstChild("HumanoidRootPart")
                local oHum = tNear.Character:FindFirstChildOfClass("Humanoid")
                if oRoot and oHum then
                    local anvilPart = Instance.new("Part")
                    anvilPart.Size = Vector3.new(4, 2, 4)
                    anvilPart.CFrame = CFrame.new(oRoot.Position + Vector3.new(0, 20, 0))
                    anvilPart.Anchored = true
                    anvilPart.Material = Enum.Material.Metal
                    anvilPart.Color = Color3.fromRGB(70, 70, 70)
                    anvilPart.Parent = Workspace
                    task.delay(0.6, function()
                        anvilPart:Destroy()
                        if oHum and oHum.Parent and oHum.Health > 0 then
                            tagHumanoid(oHum, player)
                            applyDamage(oHum, 45, player)
                            applyStun(oHum, 2)
                            oRoot.AssemblyLinearVelocity = Vector3.new(0, -25, 0)
                            local ov = Players:GetPlayerFromCharacter(tNear.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 45) end
                        end
                    end)
                    abilityVFXEvent:FireAllClients(player, fId, slot, oRoot.Position + Vector3.new(0, 20, 0), Vector3.new(0, -1, 0))
                end
            end
        elseif slot == "ultimate" then
            -- Earthquake: AoE подброс + высокий урон
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                    local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                    if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 32 then
                        tagHumanoid(oHum, player); applyDamage(oHum, 65, player)
                        oRoot.AssemblyLinearVelocity = Vector3.new(0, 55, 0)
                    end
                end
            end
        elseif slot == "special" then
            -- B15 FIX: Forge Flame — 55 урона за один удар (было: 22 за волну)
            local look = root.CFrame.LookVector
            for i = 1, 3 do
                task.delay(i * 0.3, function()
                    if not char.Parent then return end
                    for _, other in ipairs(Players:GetPlayers()) do
                        if other ~= player and other.Character then
                            local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                            local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                            if oRoot and oHum and (oRoot.Position - (root.Position + look * (i * 10))).Magnitude <= 12 then
                                tagHumanoid(oHum, player); applyDamage(oHum, 55, player)
                                oRoot.AssemblyLinearVelocity = (look + Vector3.new(0, 0.3, 0)) * 40
                                local ov = Players:GetPlayerFromCharacter(other.Character)
                                if ov then fireVictimVFX(ov, fId, slot, 55) end
                            end
                        end
                    end
                end)
            end
        elseif slot == "mobility" then
            -- A19 FIX: Hammer Launch + AoE сплэш при приземлении
            root.AssemblyLinearVelocity = root.CFrame.LookVector * 60 + Vector3.new(0, 70, 0)
            task.delay(1.5, function()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 18 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 40, player)
                            oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 50 + Vector3.new(0, 20, 0)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 40) end
                        end
                    end
                end
                abilityVFXEvent:FireAllClients(player, fId, "mobility_land", root.Position, Vector3.new(0, 1, 0))
            end)
        else
            -- B8 FIX: God Hammer — DoT 20/с × 10с + Invulnerable 6с
            local tungBase = TycoonService.getBaseWalkSpeed(player)
            hum.WalkSpeed = 30
            player:SetAttribute("Invulnerable", true)
            local function godHammerStrike()
                if not char.Parent then return end
                for _, other in ipairs(Players:GetPlayers()) do
                    if other ~= player and other.Character then
                        local oRoot: BasePart? = other.Character:FindFirstChild("HumanoidRootPart")
                        local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                        if oRoot and oHum and (oRoot.Position - root.Position).Magnitude <= 30 then
                            tagHumanoid(oHum, player); applyDamage(oHum, 20, player)
                            oRoot.AssemblyLinearVelocity = (oRoot.Position - root.Position).Unit * 50 + Vector3.new(0, 30, 0)
                            local ov = Players:GetPlayerFromCharacter(other.Character)
                            if ov then fireVictimVFX(ov, fId, slot, 20) end
                        end
                    end
                end
                abilityVFXEvent:FireAllClients(player, fId, "godmode_quake", root.Position, root.CFrame.LookVector)
            end
            for i = 0, 9 do task.delay(i, godHammerStrike) end
            task.delay(10, function()
                if hum.Parent then hum.WalkSpeed = tungBase end
                if player.Parent then player:SetAttribute("Invulnerable", false) end
            end)
        end
    end

    print(string.format("[AbilityService] %s cast %s (%s)", player.Name, abilityInfo.name, slot))
end

-- P0-01: Подключение с серверным debounce (0.3с)
abilityEvent.OnServerEvent:Connect(function(player: Player, slot: any)
    if slot == "base" or slot == "tactical" or slot == "ultimate" or slot == "special" or slot == "mobility" or slot == "godmode" then
        local now = os.clock()
        local last = lastCastTime[player.UserId] or 0
        if now - last < 0.3 then return end
        lastCastTime[player.UserId] = now
        AbilityService.castAbility(player, slot)
    else
        return
    end
end)

-- Тулы НЕ выдаются при респавне — игрок забирает со стенда на базе
local function setupAbilityPlayer(_player: Player)
    -- Пустой: тулы выдаются только при покупке (onItemPurchased) или со стенда (ProximityPrompt)
end

Players.PlayerAdded:Connect(setupAbilityPlayer)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(setupAbilityPlayer, p)
end

-- Связываем покупку стойки способности в TycoonService с моментальной выдачей предмета
TycoonService.onItemPurchased = function(player: Player, itemId: string)
    if string.find(itemId, "AbilityStand") then
        AbilityService.syncPlayerTools(player)
    end
end

-- Очистка кэша кулдаунов и debounce при выходе игрока
function AbilityService.removePlayer(player: Player)
    local prefix = string.format("%d_", player.UserId)
    for key in pairs(cooldowns) do
        if type(key) == "string" and string.sub(key, 1, #prefix) == prefix then
            cooldowns[key] = nil
        end
    end
    lastCastTime[player.UserId] = nil
end

Players.PlayerRemoving:Connect(function(player: Player)
    AbilityService.removePlayer(player)
end)

return AbilityService
