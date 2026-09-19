--!strict

--[=[
    TycoonService
    Управляет экономикой Ауры, покупками, 5 уровнями перерождений и начислением множителей.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TycoonConfig = require(Shared:WaitForChild("TycoonConfig"))
local EconomyManager = require(Shared:WaitForChild("EconomyManager"))
local DataStoreManager = require(script.Parent:WaitForChild("DataStoreManager"))

local TycoonService = {}

export type PlayerData = {
    cash: number,
    rebirths: number,
    ownedItems: { [string]: boolean },
}

local playerDataMap: { [number]: PlayerData } = {}

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
    if rebirths >= 4 then
        hum.JumpPower = 75 -- Суперпрыжки
    end
    if rebirths >= 5 then
        player:SetAttribute("GodWingsUnlocked", true)
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

    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        TycoonService.applyRebirthPerks(player)
    end)

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

function TycoonService.saveAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        local data = playerDataMap[player.UserId]
        if data then
            DataStoreManager.saveData(player.UserId, {
                version = 1,
                cash = data.cash,
                rebirths = data.rebirths,
                ownedItems = data.ownedItems,
                lastSaved = os.time(),
            })
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
    return if data then data.ownedItems else {}
end

function TycoonService.addCash(player: Player, amount: number)
    local data = playerDataMap[player.UserId]
    if not data then return end

    local mult = EconomyManager.calculateMultiplier(data.rebirths)
    data.cash = EconomyManager.addCash(data.cash, amount, mult)

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local auraVal = leaderstats:FindFirstChild("Aura") :: IntValue?
        if auraVal then
            auraVal.Value = data.cash
        end
    end
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

    print(string.format("[TycoonService] %s purchased %s! Remaining: %d Aura", player.Name, item.name, data.cash))
    return true
end

function TycoonService.performRebirth(player: Player): boolean
    local data = playerDataMap[player.UserId]
    if not data then return false end

    local canRebirth, reason, cost = EconomyManager.canPerformRebirth(data.cash, data.rebirths, data.ownedItems)
    if not canRebirth or not cost then
        warn(string.format("[TycoonService] Rebirth failed: %s", reason or "unknown"))
        return false
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
    print(string.format("[TycoonService] %s performed REBIRTH %d!", player.Name, data.rebirths))
    return true
end

function TycoonService.hasItem(player: Player, itemId: string): boolean
    local data = playerDataMap[player.UserId]
    return if data then (data.ownedItems[itemId] == true) else false
end

return TycoonService
