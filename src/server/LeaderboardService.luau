--!strict

--[=[
    LeaderboardService
    Создает две большие неоновые доски лидеров на центральной площади:
    1. 🏆 ТОП ПО АУРЕ (Самые богатые игроки сервера)
    2. 💀 ТОП ПО PVP УБИЙСТВАМ (Лучшие охотники за головами)
]=]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LeaderboardService = {}

type PvPStat = {
    kills: number,
    bountyStolen: number,
}

local pvpStatsMap: { [number]: PvPStat } = {}

-- Ссылки на UI-компоненты строк досок
local wealthRows: { TextLabel } = {}
local pvpRows: { TextLabel } = {}

local function createBoard(name: string, title: string, cf: CFrame, titleColor: Color3)
    local container = Workspace:FindFirstChild("Leaderboards")
    if not container then
        container = Instance.new("Folder")
        container.Name = "Leaderboards"
        container.Parent = Workspace
    end

    local board = Instance.new("Part")
    board.Name = name
    board.Size = Vector3.new(22, 16, 1.2)
    board.CFrame = cf
    board.Anchored = true
    board.Material = Enum.Material.SmoothPlastic
    board.Color = Color3.fromRGB(15, 15, 20)
    board.Parent = container

    -- Неоновая рамка
    local frameTop = Instance.new("Part")
    frameTop.Size = Vector3.new(22.4, 0.6, 1.4)
    frameTop.CFrame = cf * CFrame.new(0, 8.2, 0)
    frameTop.Anchored = true
    frameTop.Material = Enum.Material.Neon
    frameTop.Color = titleColor
    frameTop.Parent = container

    local frameBottom = Instance.new("Part")
    frameBottom.Size = Vector3.new(22.4, 0.6, 1.4)
    frameBottom.CFrame = cf * CFrame.new(0, -8.2, 0)
    frameBottom.Anchored = true
    frameBottom.Material = Enum.Material.Neon
    frameBottom.Color = titleColor
    frameBottom.Parent = container

    -- SurfaceGui на лицевой стороне
    local sGui = Instance.new("SurfaceGui")
    sGui.Name = "BoardGui"
    sGui.Face = Enum.NormalId.Front
    sGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sGui.PixelsPerStud = 30
    sGui.AlwaysOnTop = false
    sGui.Parent = board

    local bgFrame = Instance.new("Frame")
    bgFrame.Size = UDim2.new(1, 0, 1, 0)
    bgFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = sGui

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 65)
    titleLbl.Position = UDim2.new(0, 10, 0, 12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = titleColor
    titleLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleLbl.TextStrokeTransparency = 0.2
    titleLbl.TextScaled = true
    titleLbl.Font = Enum.Font.FredokaOne
    titleLbl.Parent = bgFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Padding = UDim.new(0, 8)

    local rowsContainer = Instance.new("Frame")
    rowsContainer.Size = UDim2.new(1, -30, 1, -95)
    rowsContainer.Position = UDim2.new(0, 15, 0, 85)
    rowsContainer.BackgroundTransparency = 1
    rowsContainer.Parent = bgFrame
    listLayout.Parent = rowsContainer

    local rowLabels: { TextLabel } = {}
    local rankMedals = { "🥇 #1", "🥈 #2", "🥉 #3", "👤 #4", "👤 #5" }
    local rowColors = {
        Color3.fromRGB(255, 215, 0),   -- Золото
        Color3.fromRGB(220, 220, 225), -- Серебро
        Color3.fromRGB(205, 127, 50),  -- Бронза
        Color3.fromRGB(180, 180, 190),
        Color3.fromRGB(180, 180, 190),
    }

    for i = 1, 5 do
        local row = Instance.new("TextLabel")
        row.Name = "Row_" .. i
        row.Size = UDim2.new(1, 0, 0, 52)
        row.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
        row.BackgroundTransparency = 0.3
        row.Text = string.format("%s [Ожидание игрока]", rankMedals[i])
        row.TextColor3 = rowColors[i]
        row.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        row.TextStrokeTransparency = 0.3
        row.TextScaled = true
        row.Font = Enum.Font.FredokaOne
        row.Parent = rowsContainer

        local rCorner = Instance.new("UICorner")
        rCorner.CornerRadius = UDim.new(0, 8)
        rCorner.Parent = row

        table.insert(rowLabels, row)
    end

    return rowLabels
end

function LeaderboardService.recordPvPKill(killer: Player, victim: Player, amount: number)
    local stat = pvpStatsMap[killer.UserId] or { kills = 0, bountyStolen = 0 }
    stat.kills += 1
    stat.bountyStolen += amount
    pvpStatsMap[killer.UserId] = stat
end

function LeaderboardService.getPvPStats(player: Player): PvPStat
    return pvpStatsMap[player.UserId] or { kills = 0, bountyStolen = 0 }
end

local function updateLeaderboards()
    local allPlayers = Players:GetPlayers()

    -- 1. Сортировка по Ауре
    local wealthList = table.clone(allPlayers)
    table.sort(wealthList, function(a, b)
        local aStat = a:FindFirstChild("leaderstats")
        local bStat = b:FindFirstChild("leaderstats")
        local aCash = if aStat and aStat:FindFirstChild("Aura") then (aStat:FindFirstChild("Aura")).Value else 0
        local bCash = if bStat and bStat:FindFirstChild("Aura") then (bStat:FindFirstChild("Aura")).Value else 0
        return aCash > bCash
    end)

    local rankMedals = { "🥇", "🥈", "🥉", "👤", "👤" }
    for i = 1, 5 do
        local p = wealthList[i]
        local row = wealthRows[i]
        if row then
            if p then
                local aStat = p:FindFirstChild("leaderstats")
                local val = if aStat and aStat:FindFirstChild("Aura") then (aStat:FindFirstChild("Aura")).Value else 0
                row.Text = string.format("%s #%d %s — %d AURA 🔥", rankMedals[i], i, p.Name, val)
            else
                row.Text = string.format("%s #%d [Свободно]", rankMedals[i], i)
            end
        end
    end

    -- 2. Сортировка по PvP убийствам
    local pvpList = table.clone(allPlayers)
    table.sort(pvpList, function(a, b)
        local aStat = pvpStatsMap[a.UserId] or { kills = 0, bountyStolen = 0 }
        local bStat = pvpStatsMap[b.UserId] or { kills = 0, bountyStolen = 0 }
        if aStat.kills == bStat.kills then
            return aStat.bountyStolen > bStat.bountyStolen
        end
        return aStat.kills > bStat.kills
    end)

    for i = 1, 5 do
        local p = pvpList[i]
        local row = pvpRows[i]
        if row then
            if p then
                local stat = pvpStatsMap[p.UserId] or { kills = 0, bountyStolen = 0 }
                row.Text = string.format("%s #%d %s — 💀 %d фрагов (+$%d)", rankMedals[i], i, p.Name, stat.kills, stat.bountyStolen)
            else
                row.Text = string.format("%s #%d [Свободно]", rankMedals[i], i)
            end
        end
    end
end

function LeaderboardService.init()
    -- Размещаем доски на Центральной Площади у Арены
    local wealthCF = CFrame.new(-22, 11, -22) * CFrame.Angles(0, math.rad(45), 0)
    wealthRows = createBoard("WealthBoard", "🏆 ТОП БОГАЧЕЙ СЕРВЕРА (AURA)", wealthCF, Color3.fromRGB(241, 196, 15))

    local pvpCF = CFrame.new(22, 11, -22) * CFrame.Angles(0, math.rad(-45), 0)
    pvpRows = createBoard("PvPBoard", "💀 ТОП ОХОТНИКОВ (PVP KILLS)", pvpCF, Color3.fromRGB(231, 76, 60))

    -- Фоновое автообновление каждые 4 секунды
    task.spawn(function()
        while true do
            task.wait(4)
            pcall(updateLeaderboards)
        end
    end)

    -- P1-09: Не стираем статистику при выходе — данные живут до рестарта сервера
    -- (pvpStatsMap не очищается, чтобы лидеры не пропадали с доски)

    print("[LeaderboardService] Central plaza cyber leaderboards created and active!")
end

function LeaderboardService.removePlayer(player: Player)
    -- P1-NEW-15 FIX: Очищаем запись если игрок ушёл И у него 0 kills
    -- (Игроки с фрагами остаются для отображения на доске до рестарта)
    local stat = pvpStatsMap[player.UserId]
    if stat and stat.kills == 0 then
        pvpStatsMap[player.UserId] = nil
    end
end

-- P0-06: Восстановление PvP-статистики из DataStore
function LeaderboardService.restorePvPStats(player: Player, kills: number, bountyStolen: number)
    pvpStatsMap[player.UserId] = { kills = kills, bountyStolen = bountyStolen }
end

return LeaderboardService
