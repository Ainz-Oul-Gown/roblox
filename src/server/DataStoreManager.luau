--!strict

--[=[
    DataStoreManager
    Обеспечивает надежное сохранение и загрузку данных игроков в Roblox DataStore
    с безопасной обработкой ошибок (pcall), защитой от блокировок в Studio,
    валидацией схемы и защитой от NaN/Infinity (P0-09).
    Использует UpdateAsync вместо SetAsync для атомарности (P0-07).
]=]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type PetSaveEntry = {
    uuid: string,
    petId: string,
    isEquipped: boolean,
}

export type PlayerSaveData = {
    version: number,
    cash: number,
    rebirths: number,
    ownedItems: { [string]: boolean },
    lastSaved: number,
    -- P0-06: Persistence для питомцев и retention
    pets: { PetSaveEntry }?,
    dailyStreakDay: number?,
    lastDailyClaimTimestamp: number?,
    -- P0-04: Persistence для обработанных чеков
    processedReceipts: { string }?,
    -- P1-09: PvP статистика
    pvpKills: number?,
    pvpBountyStolen: number?,
}

local DATASTORE_NAME = "TycoonSave_v1"
local CURRENT_VERSION = 2

local DataStoreManager = {}

local tycoonDataStore: any = nil
local dataStoreChecked = false
local dataStoreAvailable = false
local failedToLoad: { [number]: boolean } = {}
local studioMockStore: { [number]: PlayerSaveData } = {}

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
        warn("[DataStoreManager] DataStore unavailable. Running in local session mode.")
    end
end

-- P0-09: Проверка числа на NaN и Infinity
local function sanitizeNumber(val: any, default: number): number
    if type(val) ~= "number" then return default end
    if val ~= val then return default end -- NaN check
    if val == math.huge or val == -math.huge then return default end
    return val
end

-- Дефолтные данные для нового игрока
function DataStoreManager.getDefaultData(): PlayerSaveData
    return {
        version = CURRENT_VERSION,
        cash = 0,
        rebirths = 0,
        ownedItems = {},
        lastSaved = os.time(),
        pets = {},
        dailyStreakDay = 1,
        lastDailyClaimTimestamp = 0,
        processedReceipts = {},
        pvpKills = 0,
        pvpBountyStolen = 0,
    }
end

-- P1-25: Глубокая валидация ownedItems — только string -> boolean
local function deepValidateOwnedItems(raw: any): { [string]: boolean }
    if type(raw) ~= "table" then return {} end
    local cleaned: { [string]: boolean } = {}
    for k, v in pairs(raw) do
        if type(k) == "string" and type(v) == "boolean" then
            cleaned[k] = v
        end
    end
    return cleaned
end

-- Валидация массива питомцев
local function validatePets(raw: any): { PetSaveEntry }
    if type(raw) ~= "table" then return {} end
    local result: { PetSaveEntry } = {}
    for _, entry in ipairs(raw) do
        if type(entry) == "table" and type(entry.uuid) == "string" and type(entry.petId) == "string" then
            table.insert(result, {
                uuid = entry.uuid,
                petId = entry.petId,
                isEquipped = entry.isEquipped == true,
            })
        end
    end
    return result
end

-- Валидация массива receipt IDs
local function validateReceipts(raw: any): { string }
    if type(raw) ~= "table" then return {} end
    local result: { string } = {}
    for _, v in ipairs(raw) do
        if type(v) == "string" then
            table.insert(result, v)
        end
    end
    return result
end

-- Валидация и миграция данных
function DataStoreManager.validateAndMigrate(raw: any): PlayerSaveData
    local defaultData = DataStoreManager.getDefaultData()
    if type(raw) ~= "table" then
        return defaultData
    end

    -- P0-09: Sanitize all numbers against NaN/Infinity
    local validCash = sanitizeNumber(raw.cash, 0)
    if validCash < 0 then validCash = 0 end
    validCash = math.floor(validCash)

    local validRebirths = sanitizeNumber(raw.rebirths, 0)
    if validRebirths < 0 then validRebirths = 0 end
    validRebirths = math.floor(validRebirths)

    local validStreakDay = sanitizeNumber(raw.dailyStreakDay, 1)
    if validStreakDay < 1 or validStreakDay > 7 then validStreakDay = 1 end
    validStreakDay = math.floor(validStreakDay)

    local validLastClaim = sanitizeNumber(raw.lastDailyClaimTimestamp, 0)
    if validLastClaim < 0 then validLastClaim = 0 end
    validLastClaim = math.floor(validLastClaim)

    local validPvpKills = sanitizeNumber(raw.pvpKills, 0)
    if validPvpKills < 0 then validPvpKills = 0 end
    validPvpKills = math.floor(validPvpKills)

    local validPvpBounty = sanitizeNumber(raw.pvpBountyStolen, 0)
    if validPvpBounty < 0 then validPvpBounty = 0 end
    validPvpBounty = math.floor(validPvpBounty)

    return {
        version = CURRENT_VERSION,
        cash = validCash,
        rebirths = validRebirths,
        ownedItems = deepValidateOwnedItems(raw.ownedItems),
        lastSaved = os.time(),
        pets = validatePets(raw.pets),
        dailyStreakDay = validStreakDay,
        lastDailyClaimTimestamp = validLastClaim,
        processedReceipts = validateReceipts(raw.processedReceipts),
        pvpKills = validPvpKills,
        pvpBountyStolen = validPvpBounty,
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

        local errStr = tostring(err)
        if RunService:IsStudio() and (errStr:find("Studio access to APIs is not allowed") or errStr:find("Error code: 7") or errStr:find("StudioAccessToApisNotAllowed")) then
            warn("[DataStoreManager] Studio API access is disabled in Game Settings. Running with local in-memory Mock DataStore.")
            dataStoreAvailable = false
            failedToLoad[userId] = nil
            if studioMockStore[userId] then
                return DataStoreManager.validateAndMigrate(studioMockStore[userId])
            end
            return DataStoreManager.getDefaultData()
        end

        warn(string.format("[DataStoreManager] Attempt %d failed loading for %d: %s", attempt, userId, errStr))
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

-- P0-07: Сохранение данных с UpdateAsync вместо SetAsync (атомарность)
function DataStoreManager.saveData(userId: number, data: PlayerSaveData): boolean
    ensureDataStore()
    local validated = DataStoreManager.validateAndMigrate(data)

    if not dataStoreAvailable or not tycoonDataStore then
        studioMockStore[userId] = validated
        return true -- В режиме сессии сохраняем в памяти
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
            tycoonDataStore:UpdateAsync(key, function(oldData)
                -- Защита от перезаписи более свежих данных другого сервера
                if type(oldData) == "table" and type(oldData.lastSaved) == "number" then
                    if oldData.lastSaved > validated.lastSaved then
                        return nil -- Не перезаписываем более свежие данные
                    end
                end
                return validated
            end)
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
