local _, ns = ...
local M = {}
ns.SessionJournalModel = M

if ns.SettingsState then
    ns.SettingsState.RegisterMigration("ArkannsQOLSessionDB", 2, function(data)
        if data.history == nil then data.history = {} end
        if data.historyVersion == nil then data.historyVersion = 1 end
    end)
end

local function FiniteNumber(value)
    return type(value) == "number" and value > -math.huge and value < math.huge
end

function M.IsResumable(session)
    if type(session) ~= "table" then return false end
    for _, key in ipairs({"elapsed", "xp", "income", "expense", "deaths", "lastLevel", "lastXP", "lastMaxXP", "startLevel"}) do
        if not FiniteNumber(session[key]) or session[key] < 0 then return false end
    end
    return true
end

function M.New(xp, maximum, level, money)
    return {elapsed = 0, xp = 0, income = 0, expense = 0, deaths = 0, lastMoney = money,
        lastXP = xp or 0, lastMaxXP = maximum or 0, lastLevel = level or 0, startLevel = level or 0,
        xpPending = xp == nil, approximateXP = xp == nil}
end

function M.Elapsed(session, now, startedAt)
    return (session and session.elapsed or 0) + (now and startedAt and math.max(0, now - startedAt) or 0)
end

function M.ObserveMoney(session, money)
    if money == nil then return end
    if FiniteNumber(session.lastMoney) then
        local difference = money - session.lastMoney
        if difference > 0 then session.income = session.income + difference
        elseif difference < 0 then session.expense = session.expense - difference end
    end
    session.lastMoney = money
end

function M.RecordDeath(session)
    if not session.dead then session.deaths = session.deaths + 1 end
    session.dead = true
end

function M.ObserveDeath(session, dead, count)
    if dead == nil then return end
    if count and dead and session.dead == false then M.RecordDeath(session) end
    session.dead = dead
end

local function RemainingXP(xp, maximum)
    return math.max(0, maximum - xp)
end

local function Levels(session)
    if FiniteNumber(session.levels) and session.levels >= 0 then return session.levels end
    return math.max(0, session.lastLevel - session.startLevel)
end

local function UpdateLevel(session, level, count)
    session.levels = Levels(session) + (count and math.max(0, level - session.lastLevel) or 0)
    session.lastLevel = level
end

function M.BaselineXP(session, xp, maximum, level)
    if xp == nil or level < session.lastLevel then
        session.xpPending, session.approximateXP = true, true
        return false
    end
    UpdateLevel(session, level, false)
    session.lastXP, session.lastMaxXP = xp, maximum
    if session.startLevel == 0 then session.startLevel = level end
    session.xpPending = nil
    return true
end

-- The level-up event can arrive before the matching XP snapshot.
function M.ObserveLevelUp(session, level, paused)
    if not level or level <= session.lastLevel then return false end
    if paused then
        UpdateLevel(session, level, false)
        return false
    end
    if session.xpPending then return false end
    if level > session.lastLevel + 1 or session.lastMaxXP == 0 then session.approximateXP = true end
    session.xp = session.xp + RemainingXP(session.lastXP, session.lastMaxXP)
    UpdateLevel(session, level, true)
    session.lastXP, session.lastMaxXP = 0, 0
    return true
end

function M.ObserveXP(session, xp, maximum, level)
    if xp == nil then return false end
    if session.xpPending then return M.BaselineXP(session, xp, maximum, level) end
    if level < session.lastLevel then return false end
    local difference
    if level > session.lastLevel then
        if level > session.lastLevel + 1 then session.approximateXP = true end
        difference = RemainingXP(session.lastXP, session.lastMaxXP) + xp
    else
        if xp < session.lastXP then return false end
        difference = xp - session.lastXP
    end
    session.xp = session.xp + math.max(0, difference)
    UpdateLevel(session, level, true)
    session.lastXP, session.lastMaxXP = xp, maximum
    return true
end

function M.NextLevel(session, elapsed, xp, maximum, level)
    if not session or xp == nil or level < session.lastLevel then return "unknown" end
    if maximum == 0 then return "max" end
    if session.xpPending or session.approximateXP then return "unknown" end
    if elapsed < 60 or session.xp == 0 then return "calculating" end
    return "estimate", math.ceil(RemainingXP(xp, maximum) * elapsed / session.xp)
end

local function NetMoney(session)
    return session.income - session.expense
end

function M.HourlyRates(session, elapsed)
    if not session or elapsed < 60 then return end
    return math.floor(session.xp * 3600 / elapsed), NetMoney(session) * 3600 / elapsed
end

function M.Totals(session, elapsed)
    if not session then return {} end
    return {duration = elapsed, xp = session.xp, income = session.income, expense = session.expense,
        net = NetMoney(session), deaths = session.deaths, levels = Levels(session)}
end

M.HistoryLimit, M.SampleLimit = 100, 120
local totalKeys = {"duration", "xp", "income", "expense", "deaths", "levels"}
local sampleKeys = {"elapsed", "xp", "net", "deaths", "levels"}

local function CopySample(sample)
    if type(sample) ~= "table" then return end
    local copy = {}
    for _, key in ipairs(sampleKeys) do
        if not FiniteNumber(sample[key]) or (key ~= "net" and sample[key] < 0) then return end
        copy[key] = sample[key]
    end
    return copy
end

local function CompactSamples(samples)
    if #samples <= M.SampleLimit then return samples end
    local compact = {samples[1]}
    for index = 3, #samples - 1, 2 do compact[#compact + 1] = samples[index] end
    compact[#compact + 1] = samples[#samples]
    return compact
end

local function CopySamples(samples)
    local clean = {}
    for _, sample in ipairs(type(samples) == "table" and samples or {}) do
        local copy = CopySample(sample)
        if copy and (#clean == 0 or copy.elapsed > clean[#clean].elapsed) then
            clean[#clean + 1] = copy
            clean = CompactSamples(clean)
        end
    end
    return clean
end

-- elapsed measures tracked time only; wall-clock dates must never be inferred
-- from it because manual and AFK pauses can span arbitrary periods.
function M.StartHistory(session, timestamp, elapsed)
    elapsed = FiniteNumber(elapsed) and math.max(0, elapsed) or session.elapsed
    if session.historyVersion == 1 then
        session.samples = CopySamples(session.samples)
        if not FiniteNumber(session.startedAt) or session.startedAt < 0 then session.startedAt = nil end
        M.Sample(session, elapsed, true)
        return
    end
    if session.historyVersion ~= nil then return end
    session.historyVersion = 1
    if elapsed == 0 and FiniteNumber(timestamp) and timestamp >= 0 then session.startedAt = timestamp end
    session.samples = {}
    M.Sample(session, elapsed, true)
end

function M.Sample(session, elapsed, force)
    if not session or session.historyVersion ~= 1 or session.archived or not FiniteNumber(elapsed) or elapsed < 0 then return false end
    local sample = CopySample({elapsed = elapsed, xp = session.xp, net = NetMoney(session),
        deaths = session.deaths, levels = Levels(session)})
    if not sample then return false end
    if type(session.samples) ~= "table" then session.samples = {} end
    local samples = session.samples
    local last = samples[#samples]
    if last and (elapsed < last.elapsed or (not force and elapsed - last.elapsed < 60)) then return false end
    if last and elapsed == last.elapsed then samples[#samples] = sample
    else samples[#samples + 1] = sample end
    session.samples = CompactSamples(samples)
    return true
end

local function CopyRecord(record, omitSamples)
    if type(record) ~= "table" then return end
    local copy = {}
    for _, key in ipairs(totalKeys) do
        if not FiniteNumber(record[key]) or record[key] < 0 then return end
        copy[key] = record[key]
    end
    copy.net = copy.income - copy.expense
    copy.approximateXP = record.approximateXP == true
    for _, key in ipairs({"startedAt", "endedAt"}) do
        if FiniteNumber(record[key]) and record[key] >= 0 then copy[key] = record[key] end
    end
    copy.reason = record.reason == "logout" and "logout" or record.reason == "new" and "new" or "manual"
    if not omitSamples then
        copy.samples = CopySamples(record.samples)
        while #copy.samples > 0 and copy.samples[#copy.samples].elapsed > copy.duration do table.remove(copy.samples) end
    end
    return copy
end

function M.NormalizeHistory(db)
    -- Preserve a future schema instead of silently reinterpreting its data.
    if db.historyVersion ~= nil and db.historyVersion ~= 1 then return false end
    local history = {}
    for _, record in ipairs(type(db.history) == "table" and db.history or {}) do
        local copy = CopyRecord(record)
        if copy then
            history[#history + 1] = copy
            if #history > M.HistoryLimit then table.remove(history, 1) end
        end
    end
    db.history, db.historyVersion = history, 1
    return true
end

function M.Archive(db, session, elapsed, timestamp, reason)
    if not session or session.archived or not M.IsResumable(session) or not FiniteNumber(elapsed) or elapsed < 0 then return end
    if db.historyVersion ~= nil and db.historyVersion ~= 1 then return end
    local totals = M.Totals(session, elapsed)
    if elapsed < 1 and totals.xp == 0 and totals.income == 0 and totals.expense == 0 and totals.deaths == 0 and totals.levels == 0 then
        session.archived = true
        return
    end
    M.StartHistory(session, timestamp, elapsed)
    M.Sample(session, elapsed, true)
    totals.startedAt, totals.endedAt = session.startedAt, timestamp
    totals.reason, totals.samples, totals.approximateXP = reason, session.samples, session.approximateXP
    local record = CopyRecord(totals)
    if not record then return end
    if type(db.history) ~= "table" then db.history = {} end
    db.historyVersion = 1
    db.history[#db.history + 1] = record
    while #db.history > M.HistoryLimit do table.remove(db.history, 1) end
    session.archived = true
    return record
end

function M.HistoryTotals(history)
    local totals = {count = 0, duration = 0, xp = 0, income = 0, expense = 0, net = 0, deaths = 0, levels = 0, approximateXP = false}
    for _, record in ipairs(type(history) == "table" and history or {}) do
        local valid = CopyRecord(record, true)
        if valid then
            totals.count = totals.count + 1
            for _, key in ipairs(totalKeys) do totals[key] = totals[key] + valid[key] end
            totals.approximateXP = totals.approximateXP or valid.approximateXP
        end
    end
    totals.net = totals.income - totals.expense
    if totals.duration >= 60 then
        totals.xpPerHour = math.floor(totals.xp * 3600 / totals.duration)
        totals.netPerHour = totals.net * 3600 / totals.duration
    end
    return totals
end

-- One point per completed session. Rates use each session's tracked duration;
-- totals above instead divide combined gains by combined duration.
function M.HistorySeries(history, metric)
    local points = {}
    for index, record in ipairs(type(history) == "table" and history or {}) do
        local valid = CopyRecord(record, true)
        if valid then
            local value = valid[metric]
            if metric == "xpPerHour" or metric == "netPerHour" then
                value = valid.duration >= 60 and (metric == "xpPerHour" and valid.xp or valid.net) * 3600 / valid.duration or nil
            end
            if FiniteNumber(value) then points[#points + 1] = {x = index, y = value, approximateXP = valid.approximateXP} end
        end
    end
    return points
end
