--!strict

--[=[
    PetService
    Система питомцев: взвешенный RNG из яиц, инвентарь, equipBest, множители.
    
    AUDIT FIXES: P0-06 (persistence), P1-15 (inventory limit), P1-16 (UUID fix)
]=]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.PetConfig)

export type OwnedPet = {
    uuid: string,
    petId: string,
    isEquipped: boolean,
}

local PetService = {}

-- P1-15: Лимит размера инвентаря питомцев
local MAX_INVENTORY_SIZE = 75

-- Инвентари игроков: [UserId] -> { OwnedPet }
local playerInventories: { [number]: { OwnedPet } } = {}

-- P0-06: initPlayer принимает сохранённых питомцев
function PetService.initPlayer(player: Player, savedPets: { OwnedPet }?)
    playerInventories[player.UserId] = savedPets or {}
end

function PetService.rollEgg(eggId: string): string?
    local egg = PetConfig.EGGS[eggId]
    if not egg or not egg.drops or #egg.drops == 0 then return nil end

    local totalWeight = 0
    for _, drop in egg.drops do
        totalWeight += drop.weight
    end
    if totalWeight <= 0 then return nil end

    local rand = math.random() * totalWeight
    local current = 0

    for _, drop in egg.drops do
        current += drop.weight
        if rand <= current then
            return drop.petId
        end
    end

    return egg.drops[1].petId
end

function PetService.addPet(player: Player, petId: string): OwnedPet?
    local petDef = PetConfig.PETS[petId]
    if not petDef then return nil end

    local inv = playerInventories[player.UserId]
    if not inv then
        inv = {}
        playerInventories[player.UserId] = inv
    end

    -- P1-15: Проверка лимита инвентаря
    if #inv >= MAX_INVENTORY_SIZE then
        warn(string.format("[PetService] %s inventory full (%d/%d)", player.Name, #inv, MAX_INVENTORY_SIZE))
        return nil
    end

    -- P1-16: Надёжный UUID через HttpService:GenerateGUID
    local guid: string
    local guidOk, guidResult = pcall(function()
        return HttpService:GenerateGUID(false)
    end)
    if guidOk and type(guidResult) == "string" then
        guid = guidResult
    else
        -- Fallback с высокой энтропией
        guid = string.format("%s_%d_%d_%d", petId, os.time(), math.random(100000, 999999), math.random(100000, 999999))
    end

    local newPet: OwnedPet = {
        uuid = guid,
        petId = petId,
        isEquipped = false,
    }

    table.insert(inv, newPet)
    return newPet
end

function PetService.getEquippedPets(player: Player): { OwnedPet }
    local inv = playerInventories[player.UserId]
    if not inv then return {} end

    local equipped: { OwnedPet } = {}
    for _, pet in inv do
        if pet.isEquipped then
            table.insert(equipped, pet)
        end
    end
    return equipped
end

function PetService.equipBest(player: Player): number
    local inv = playerInventories[player.UserId]
    if not inv then return 0 end

    -- 1. Снимаем всех
    for _, pet in inv do
        pet.isEquipped = false
    end

    -- 2. Сортируем по силе множителя
    table.sort(inv, function(a, b)
        local defA = PetConfig.PETS[a.petId]
        local defB = PetConfig.PETS[b.petId]
        local multA = defA and defA.multiplier or 1
        local multB = defB and defB.multiplier or 1
        return multA > multB
    end)

    -- 3. Надеваем до лимита
    local count = 0
    for i = 1, math.min(#inv, PetConfig.MAX_EQUIPPED_PETS) do
        inv[i].isEquipped = true
        count += 1
    end

    return count
end

function PetService.getTotalMultiplier(player: Player): number
    local equipped = PetService.getEquippedPets(player)
    if #equipped == 0 then return 1.0 end

    local mult = 1.0
    for _, pet in equipped do
        local def = PetConfig.PETS[pet.petId]
        if def then
            mult += (def.multiplier - 1.0)
        end
    end
    return mult
end

function PetService.getEquippedPetDefs(player: Player): { PetConfig.PetDefinition }
    local equipped = PetService.getEquippedPets(player)
    local result = {}
    for _, p in ipairs(equipped) do
        local def = PetConfig.PETS[p.petId]
        if def then
            table.insert(result, def)
        end
    end
    return result
end

-- P0-06: Получить инвентарь для сохранения в DataStore
function PetService.getInventoryForSave(player: Player): { OwnedPet }
    local inv = playerInventories[player.UserId]
    if not inv then return {} end
    return inv
end

function PetService.removePlayer(player: Player)
    playerInventories[player.UserId] = nil
end

return PetService
