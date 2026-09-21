--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetFollower = {}

type ActivePetVisual = {
    model: Model,
    slotIndex: number,
    totalSlots: number,
}

local activePets: { ActivePetVisual } = {}
local updateConnection: RBXScriptConnection? = nil

local function getTargetOffset(slotIndex: number, totalSlots: number): Vector3
    local angleStep = math.pi / (totalSlots + 1)
    local angle = angleStep * slotIndex - (math.pi / 2)
    local radius = 4.5
    local offsetX = math.cos(angle) * radius
    local offsetZ = math.sin(angle) * radius + 3.0 -- чуть сзади игрока
    return Vector3.new(offsetX, 1.2, offsetZ)
end

function PetFollower.registerPet(petModel: Model, slotIndex: number, totalSlots: number)
    table.insert(activePets, {
        model = petModel,
        slotIndex = slotIndex,
        totalSlots = totalSlots,
    })

    if not updateConnection then
        updateConnection = RunService.RenderStepped:Connect(PetFollower.onRenderStep)
    end
end

function PetFollower.clearPets()
    for _, pet in activePets do
        if pet.model then
            pet.model:Destroy()
        end
    end
    activePets = {}
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
end

function PetFollower.onRenderStep(dt: number)
    local camera = Workspace.CurrentCamera
    local character = game:GetService("Players").LocalPlayer.Character
    if not character or not character.PrimaryPart then return end

    local root = character.PrimaryPart
    local now = os.clock()

    for _, pet in activePets do
        if pet.model and pet.model.PrimaryPart then
            local primary = pet.model.PrimaryPart
            local offset = getTargetOffset(pet.slotIndex, pet.totalSlots)

            -- Мягкое покачивание (Bobbing) на синусоиде
            local bobY = math.sin(now * 3 + pet.slotIndex) * 0.35

            local targetCFrame = root.CFrame * CFrame.new(offset.X, offset.Y + bobY, offset.Z)
            -- Плавное следование к целевой точке (Lerp с учетом dt)
            local alpha = math.clamp(dt * 9, 0, 1)
            primary.CFrame = primary.CFrame:Lerp(targetCFrame, alpha)
        end
    end
end

return PetFollower
