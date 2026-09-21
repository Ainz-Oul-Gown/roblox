--!strict

--[=[
    TycoonService
    Управляет экономикой Ауры, хранилищем базы (Vault), покупками,
    5 уровнями перерождений, PvP-лутом кошелька при смерти и начислением множителей.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig", 10))
local EconomyManager = require(Shared:WaitForChild("EconomyManager", 10))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager", 10))

local TycoonService = {}

export type PlayerData = {
    cash: number,
    rebirths: number,
    ownedItems: { [string]: boolean },
}

local playerDataMap: { [number]: PlayerData } = {}
-- Хранилище накопленной руды в сборщиках баз (не уязвимо к PvP-смерти!)
local vaultCashMap: { [number]: number } = {}

local function getOrCreateRemote(name: string): RemoteEvent
    local existing = ReplicatedStorage:FindFirstChild(name) :: RemoteEvent?
    if existing then return existing end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = ReplicatedStorage
    return remote
end

local vaultUpdatedEvent = getOrCreateRemote("VaultUpdatedEvent")
local pvpKillEvent = getOrCreateRemote("PvPKillEvent")
local withdrawEvent = getOrCreateRemote("WithdrawEvent")
local rebirthEvent = getOrCreateRemote("RebirthEvent")

-- Ссылка на AbilityService для выдачи инструментов (устанавливается после инициализации)
TycoonService.onItemPurchased = nil :: ((player: Player, itemId: string) -> ())?

-- Применение пассивных перков Rebirth к персонажу
function TycoonService.applyRebirthPerks(player: Player)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid") :: Humanoid?
    if not hum then return end

    local rebirths = TycoonService.getRebirths(player)

    if rebirths >= 1 then
        player:SetAttribute("DoubleJumpUnlocked", true)
    end
    if rebirths >= 2 then
        player:SetAttribute("DashUnlocked", true)
    end
    if rebirths >= 3 then
        hum.MaxHealth = 130
        hum.Health = 130
    end
    if rebirths >= 4 then
        hum.JumpPower = 75
        hum.WalkSpeed = 22
    end
    if rebirths >= 5 then
        player:SetAttribute("GodWingsUnlocked", true)
        hum.MaxHealth = 175
        hum.Health = 175
    end
end

-- Обработка PvP гибели персонажа: убийца забирает весь наличный кошелек жертвы
function TycoonService.handlePlayerDeath(victim: Player)
    local char = victim.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid") :: Humanoid?
    if not hum then return end

    local victimData = playerDataMap[victim.UserId]
    if not victimData or victimData.cash <= 0 then return end

    local stolenCash = victimData.cash
    local killer: Player? = nil

    -- Ищем тег убийцы (creator tag)
    local creatorTag = hum:FindFirstChild("creator") :: ObjectValue?
    if creatorTag and creatorTag.Value and creatorTag.Value:IsA("Player") then
        local killerCandidate = creatorTag.Value :: Player
        if killerCandidate ~= victim and killerCandidate.Parent == Players then
            killer = killerCandidate
        end
    end

    -- Обнуляем кошелек жертвы
    victimData.cash = 0
    local vLeaderstats = victim:FindFirstChild("leaderstats")
    if vLeaderstats then
        local aVal = vLeaderstats:FindFirstChild("Aura") :: IntValue?
        if aVal then aVal.Value = 0 end
    end

    if killer then
        -- Убийца получает 100% кошелька жертвы!
        local killerData = playerDataMap[killer.UserId]
        if killerData then
            killerData.cash += stolenCash
            local kLeaderstats = killer:FindFirstChild("leaderstats")
            if kLeaderstats then
                local kaVal = kLeaderstats:FindFirstChild("Aura") :: IntValue?
                if kaVal then kaVal.Value = killerData.cash end
            end
        end

        if TycoonService.onPvPKill then
            TycoonService.onPvPKill(killer, victim, stolenCash)
        end

        print(string.format("[PvP] %s killed %s and LOOTED %d Aura!", killer.Name, victim.Name, stolenCash))
        pvpKillEvent:FireClient(killer, { type = "kill", targetName = victim.Name, amount = stolenCash })
        pvpKillEvent:FireClient(victim, { type = "death", killerName = killer.Name, amount = stolenCash })
    else
        print(string.format("[PvP] %s died and lost %d wallet Aura.", victim.Name, stolenCash))
        pvpKillEvent:FireClient(victim, { type = "death", killerName = "Опасная среда", amount = stolenCash })
    end
end

function TycoonService.onPlayerAdded(player: Player): PlayerData
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local savedData = DataStoreManager.loadData(player.UserId)

    local auraValue = Instance.new("IntValue")
    auraValue.Name = "Aura"
    auraValue.Value = savedData.cash
    auraValue.Parent = leaderstats

    local rebirthValue = Instance.new("IntValue")
    rebirthValue.Name = "Rebirths"
    rebirthValue.Value = savedData.rebirths
    rebirthValue.Parent = leaderstats

    local currentData: PlayerData = {
        cash = savedData.cash,
        rebirths = savedData.rebirths,
        ownedItems = savedData.ownedItems,
    }

    playerDataMap[player.UserId] = currentData

    local function onCharacter(char: Model)
        task.wait(0.3)
        TycoonService.applyRebirthPerks(player)

        local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
        if hum then
            hum.Died:Connect(function()
                TycoonService.handlePlayerDeath(player)
            end)
        end
    end

    if player.Character then
        task.spawn(onCharacter, player.Character)
    end
    player.CharacterAdded:Connect(onCharacter)

    print(string.format("[TycoonService] %s connected: Aura=%d, Rebirths=%d", player.Name, currentData.cash, currentData.rebirths))
    return currentData
end

function TycoonService.onPlayerRemoving(player: Player)
    local data = playerDataMap[player.UserId]
    if data then
        DataStoreManager.saveData(player.UserId, {
            version = 1,
            cash = data.cash,
            rebirths = data.rebirths,
            ownedItems = data.ownedItems,
            lastSaved = os.time(),
        })
        playerDataMap[player.UserId] = nil
    end
end

-- Ссылка на внешний расчет экстра-множителей (MonetizationService, PetService)
TycoonService.getExtraMultiplier = nil :: ((player: Player) -> number)?

local function getPlayerTotalMultiplier(player: Player, rebirths: number): number
    local mult = EconomyManager.calculateMultiplier(rebirths)
    if TycoonService.getExtraMultiplier then
        local ok, extra = pcall(TycoonService.getExtraMultiplier, player)
        if ok and type(extra) == "number" and extra > 0 then
            mult *= extra
        end
    end
    return mult
end

function TycoonService.saveAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = playerDataMap[player.UserId]
        if data then
            task.spawn(function()
                DataStoreManager.saveData(player.UserId, {
                    version = 1,
                    cash = data.cash,
                    rebirths = data.rebirths,
                    ownedItems = data.ownedItems,
                    lastSaved = os.time(),
                })
            end)
        end
    end
end

function TycoonService.getCash(player: Player): number
    local data = playerDataMap[player.UserId]
    return if data then data.cash else 0
end

function TycoonService.getRebirths(player: Player): number
    local data = playerDataMap[player.UserId]
    return if data then data.rebirths else 0
end

function TycoonService.getOwnedItems(player: Player): { [string]: boolean }
    local data = playerDataMap[player.UserId]
    local items = if data then table.clone(data.ownedItems) else {}
    items["Collector"] = true
    items["FactionDropper"] = true
    return items
end

-- Начисление напрямую в кошелек (используется для бонуса Центральной Арены "Царь Горы")
function TycoonService.addCash(player: Player, amount: number)
    local data = playerDataMap[player.UserId]
    if not data then return end

    local mult = getPlayerTotalMultiplier(player, data.rebirths)
    data.cash = EconomyManager.addCash(data.cash, amount, mult)

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local auraVal = leaderstats:FindFirstChild("Aura") :: IntValue?
        if auraVal then
            auraVal.Value = data.cash
        end
    end
end

-- Безопасное списание наличных из кошелька (не опускается ниже 0, обновляет leaderstats)
function TycoonService.deductCash(player: Player, amount: number): number
    local data = playerDataMap[player.UserId]
    if not data or amount <= 0 then return 0 end

    local actualDeducted = math.min(data.cash, math.floor(amount))
    data.cash -= actualDeducted

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local auraVal = leaderstats:FindFirstChild("Aura") :: IntValue?
        if auraVal then
            auraVal.Value = data.cash
        end
    end
    return actualDeducted
end

-- Добавление дохода от упавшей руды в СЕЙФ базы (Collector Vault)
function TycoonService.addToVault(plotIndex: number, amount: number, owner: Player?)
    local current = vaultCashMap[plotIndex] or 0
    local mult = 1.0
    if owner then
        local data = playerDataMap[owner.UserId]
        if data then
            mult = getPlayerTotalMultiplier(owner, data.rebirths)
        end
    end

    local added = math.floor(amount * mult)
    current += added
    vaultCashMap[plotIndex] = current

    if owner then
        vaultUpdatedEvent:FireClient(owner, plotIndex, current)
    end
    return current
end

function TycoonService.getVaultCash(plotIndex: number): number
    return vaultCashMap[plotIndex] or 0
end

-- Вывод накопленных денег из сейфа базы в кошелек игрока
function TycoonService.withdrawVault(player: Player, plotIndex: number): number
    local stored = vaultCashMap[plotIndex] or 0
    if stored <= 0 then return 0 end

    vaultCashMap[plotIndex] = 0
    local data = playerDataMap[player.UserId]
    if data then
        data.cash += stored
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local auraVal = leaderstats:FindFirstChild("Aura") :: IntValue?
            if auraVal then auraVal.Value = data.cash end
        end
    end

    vaultUpdatedEvent:FireClient(player, plotIndex, 0)
    withdrawEvent:FireClient(player, stored)
    print(string.format("[TycoonService] %s withdrew %d Aura from Base %d Vault!", player.Name, stored, plotIndex))
    return stored
end

function TycoonService.purchaseItem(player: Player, itemId: string): boolean
    local data = playerDataMap[player.UserId]
    if not data then return false end

    local canBuy, reason = EconomyManager.canPurchaseItem(data.cash, data.ownedItems, itemId)
    if not canBuy then
        warn(string.format("[TycoonService] %s cannot buy %s: %s", player.Name, itemId, reason or "unknown"))
        return false
    end

    local item = TycoonConfig.getItemById(itemId)
    if not item then return false end

    data.cash = EconomyManager.deductCash(data.cash, item.cost)
    data.ownedItems[itemId] = true

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local auraVal = leaderstats:FindFirstChild("Aura") :: IntValue?
        if auraVal then
            auraVal.Value = data.cash
        end
    end

    if TycoonService.onItemPurchased then
        TycoonService.onItemPurchased(player, itemId)
    end

    print(string.format("[TycoonService] %s purchased %s! Remaining: %d Aura", player.Name, item.name, data.cash))
    return true
end

function TycoonService.performRebirth(player: Player): (boolean, string?)
    local data = playerDataMap[player.UserId]
    if not data then return false, "No player data" end

    local canRebirth, reason, cost = EconomyManager.canPerformRebirth(data.cash, data.rebirths, data.ownedItems)
    if not canRebirth or not cost then
        warn(string.format("[TycoonService] Rebirth failed: %s", reason or "unknown"))
        return false, reason
    end

    data.cash = 0
    data.rebirths += 1
    data.ownedItems = {}

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local auraVal = leaderstats:FindFirstChild("Aura") :: IntValue?
        if auraVal then auraVal.Value = 0 end

        local rebirthVal = leaderstats:FindFirstChild("Rebirths") :: IntValue?
        if rebirthVal then rebirthVal.Value = data.rebirths end
    end

    TycoonService.applyRebirthPerks(player)
    
    local mult = EconomyManager.calculateMultiplier(data.rebirths)
    rebirthEvent:FireClient(player, data.rebirths, mult)

    print(string.format("[TycoonService] %s performed REBIRTH %d! Multiplier x%.1f", player.Name, data.rebirths, mult))
    return true, nil
end

function TycoonService.hasItem(player: Player, itemId: string): boolean
    if itemId == "Collector" or itemId == "FactionDropper" then
        return true
    end
    local data = playerDataMap[player.UserId]
    return if data then (data.ownedItems[itemId] == true) else false
end

-- Проверяет, захватил ли игрок хоть какую-то базу (используется CentralArena)
TycoonService.hasAnyBase = nil :: ((player: Player) -> boolean)?

return TycoonService
