local _, ns = ...
local M = {}
ns.SessionJournalModel = M

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

-- The level-up event can arrive before the matching XP snapshot.
function M.ObserveLevelUp(session, level)
    if session.xpPending or not level or level <= session.lastLevel then return false end
    if level > session.lastLevel + 1 or session.lastMaxXP == 0 then session.approximateXP = true end
    session.xp = session.xp + RemainingXP(session.lastXP, session.lastMaxXP)
    session.lastLevel, session.lastXP, session.lastMaxXP = level, 0, 0
    return true
end

function M.ObserveXP(session, xp, maximum, level)
    if xp == nil then return false end
    if session.xpPending then
        session.lastXP, session.lastMaxXP, session.lastLevel = xp, maximum, level
        if session.startLevel == 0 then session.startLevel = level end
        session.xpPending = nil
        return true
    end
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
    session.lastXP, session.lastMaxXP, session.lastLevel = xp, maximum, level
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
        net = NetMoney(session), deaths = session.deaths, levels = math.max(0, session.lastLevel - session.startLevel)}
end
