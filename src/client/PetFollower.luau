--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local PetFollower = {}

type ActivePetVisual = {
    model: Model,
    slotIndex: number,
    totalSlots: number,
    baseOffset: Vector3,
}

local activePets: { ActivePetVisual } = {}
local updateConnection: RBXScriptConnection? = nil

local function computeBaseOffset(slotIndex: number, totalSlots: number): Vector3
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
        baseOffset = computeBaseOffset(slotIndex, totalSlots),
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
    local char = localPlayer and localPlayer.Character
    if not char or not char.PrimaryPart then return end

    local root = char.PrimaryPart
    local now = os.clock()
    local alpha = math.clamp(dt * 9, 0, 1)

    for _, pet in activePets do
        local model = pet.model
        if model and model.PrimaryPart then
            local primary = model.PrimaryPart
            local base = pet.baseOffset

            -- Мягкое покачивание (Bobbing) на синусоиде
            local bobY = math.sin(now * 3 + pet.slotIndex) * 0.35

            local targetCFrame = root.CFrame * CFrame.new(base.X, base.Y + bobY, base.Z)
            primary.CFrame = primary.CFrame:Lerp(targetCFrame, alpha)
        end
    end
end

function PetFollower.createPetVisual(def: { id: string, name: string, rarity: string, multiplier: number }): Model
    local model = Instance.new("Model")
    model.Name = "Pet_" .. (def.id or "Unknown")

    local part = Instance.new("Part")
    part.Name = "HumanoidRootPart"
    part.Size = Vector3.new(1.8, 1.8, 1.8)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon

    local rarityColors: { [string]: Color3 } = {
        Common = Color3.fromRGB(200, 200, 200),
        Rare = Color3.fromRGB(52, 152, 219),
        Epic = Color3.fromRGB(155, 89, 182),
        Legendary = Color3.fromRGB(241, 196, 15),
        Mythic = Color3.fromRGB(231, 76, 60),
    }
    part.Color = rarityColors[def.rarity] or Color3.fromRGB(255, 215, 0)
    part.Parent = model
    model.PrimaryPart = part

    local bGui = Instance.new("BillboardGui")
    bGui.Size = UDim2.new(0, 140, 0, 38)
    bGui.StudsOffset = Vector3.new(0, 1.8, 0)
    bGui.AlwaysOnTop = true
    bGui.Parent = part

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("%s\n[x%.2f AURA]", def.name or "Питомец", def.multiplier or 1)
    lbl.TextColor3 = part.Color
    lbl.TextStrokeTransparency = 0.2
    lbl.TextScaled = true
    lbl.Font = Enum.Font.FredokaOne
    lbl.Parent = bGui

    model.Parent = Workspace
    return model
end

function PetFollower.syncEquippedPets(petDefs: { any })
    PetFollower.clearPets()
    local total = #petDefs
    for i, def in ipairs(petDefs) do
        local m = PetFollower.createPetVisual(def)
        PetFollower.registerPet(m, i, total)
    end
end

return PetFollower
