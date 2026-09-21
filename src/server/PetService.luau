--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetConfig = require(ReplicatedStorage.Shared.PetConfig)

export type OwnedPet = {
    uuid: string,
    petId: string,
    isEquipped: boolean,
}

local PetService = {}

-- Инвентари игроков: [UserId] -> { OwnedPet }
local playerInventories: { [number]: { OwnedPet } } = {}

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

    local newPet: OwnedPet = {
        uuid = `{petId}_{os.time()}_{math.random(1000, 9999)}`,
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

function PetService.removePlayer(player: Player)
    playerInventories[player.UserId] = nil
end

return PetService
