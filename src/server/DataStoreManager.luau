--!strict

--[=[
    DataStoreManager
    Обеспечивает надежное сохранение и загрузку данных игроков в Roblox DataStore
    с безопасной обработкой ошибок (pcall), защитой от блокировок в Studio и валидацией схемы.
]=]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type PlayerSaveData = {
    version: number,
    cash: number,
    rebirths: number,
    ownedItems: { [string]: boolean },
    lastSaved: number,
}

local DATASTORE_NAME = "TycoonSave_v1"
local CURRENT_VERSION = 1

local DataStoreManager = {}

local tycoonDataStore: any = nil
local dataStoreChecked = false
local dataStoreAvailable = false
local failedToLoad: { [number]: boolean } = {}

local function ensureDataStore()
    if dataStoreChecked then return end
    dataStoreChecked = true
    local success, result = pcall(function()
        return DataStoreService:GetDataStore(DATASTORE_NAME)
    end)
    if success and result then
        tycoonDataStore = result
        dataStoreAvailable = true
        print("[DataStoreManager] Connected to Roblox DataStore successfully.")
    else
        warn("[DataStoreManager] DataStore unavailable (likely Studio API access disabled). Running in local session mode.")
    end
end

-- Дефолтные данные для нового игрока
function DataStoreManager.getDefaultData(): PlayerSaveData
    return {
        version = CURRENT_VERSION,
        cash = 0,
        rebirths = 0,
        ownedItems = {},
        lastSaved = os.time(),
    }
end

-- Валидация и миграция данных
function DataStoreManager.validateAndMigrate(raw: any): PlayerSaveData
    local defaultData = DataStoreManager.getDefaultData()
    if type(raw) ~= "table" then
        return defaultData
    end

    local validCash = if type(raw.cash) == "number" and raw.cash >= 0 then math.floor(raw.cash) else 0
    local validRebirths = if type(raw.rebirths) == "number" and raw.rebirths >= 0 then math.floor(raw.rebirths) else 0
    local validOwnedItems = if type(raw.ownedItems) == "table" then raw.ownedItems else {}

    return {
        version = CURRENT_VERSION,
        cash = validCash,
        rebirths = validRebirths,
        ownedItems = validOwnedItems,
        lastSaved = os.time(),
    }
end

-- Загрузка данных игрока с защитой от Data Wipe при сбоях сети
function DataStoreManager.loadData(userId: number): PlayerSaveData
    ensureDataStore()
    if not dataStoreAvailable or not tycoonDataStore then
        return DataStoreManager.getDefaultData()
    end

    local key = string.format("Player_%d", userId)
    local loadedData: any = nil
    local ok = false
    local err: any = nil

    for attempt = 1, 3 do
        ok, err = pcall(function()
            loadedData = tycoonDataStore:GetAsync(key)
        end)
        if ok then break end
        warn(string.format("[DataStoreManager] Attempt %d failed loading for %d: %s", attempt, userId, tostring(err)))
        task.wait(attempt * 1.0)
    end

    if ok and loadedData ~= nil then
        failedToLoad[userId] = nil
        print(string.format("[DataStoreManager] Loaded save data for UserId: %d", userId))
        return DataStoreManager.validateAndMigrate(loadedData)
    elseif ok and loadedData == nil then
        -- Новый игрок без сохранений: загрузка успешна
        failedToLoad[userId] = nil
        return DataStoreManager.getDefaultData()
    end

    -- КРИТИЧНО: При сбое сети блокируем последующее сохранение нулей поверх реальных данных!
    failedToLoad[userId] = true
    warn(string.format("[SECURITY] Critical DataStore load failure for %d. Saving disabled for this session to prevent wipe.", userId))
    return DataStoreManager.getDefaultData()
end

-- Сохранение данных игрока с повторными попытками
function DataStoreManager.saveData(userId: number, data: PlayerSaveData): boolean
    ensureDataStore()
    if not dataStoreAvailable or not tycoonDataStore then
        return true -- В режиме сессии считаем успешно
    end

    if failedToLoad[userId] then
        warn(string.format("[SECURITY] Aborted saving for UserId %d: load failed on join, preventing data wipe!", userId))
        return false
    end

    local key = string.format("Player_%d", userId)
    local validated = DataStoreManager.validateAndMigrate(data)

    local retries = 3
    local successSave = false

    for attempt = 1, retries do
        local ok, err = pcall(function()
            tycoonDataStore:SetAsync(key, validated)
        end)

        if ok then
            successSave = true
            print(string.format("[DataStoreManager] Successfully saved data for UserId: %d", userId))
            break
        else
            warn(string.format("[DataStoreManager] Attempt %d failed saving %d: %s", attempt, userId, tostring(err)))
            task.wait(attempt * 1.5)
        end
    end

    return successSave
end

function DataStoreManager.clearPlayerSession(userId: number)
    failedToLoad[userId] = nil
end

return DataStoreManager
