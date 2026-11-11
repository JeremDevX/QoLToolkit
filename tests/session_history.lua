local ns = {}
assert(loadfile("Modules/SessionJournalModel.lua"))("QoLToolkit", ns)
local M = ns.SessionJournalModel
local migration
assert(loadfile("Modules/SessionJournalModel.lua"))("QoLToolkit", {SettingsState = {
    RegisterMigration = function(variable, version, callback)
        assert(variable == "ArkannsQOLSessionDB" and version == 2); migration = callback
    end,
}})
local old = {session = {elapsed = 123}, enabled = false}
migration(old)
assert(old.session.elapsed == 123 and old.enabled == false and #old.history == 0 and old.historyVersion == 1)
local preserved = old.history
migration(old)
assert(old.history == preserved, "History migration is idempotent and preserves existing counters")
local function New()
    return M.New(0, 1000, 10, 50000)
end

local session, db = New(), {}
assert(M.NormalizeHistory(db) and #db.history == 0)
M.StartHistory(session, 1000, 0)
assert(session.startedAt == 1000 and #session.samples == 1 and session.samples[1].elapsed == 0)
session.xp, session.income, session.expense = 100, 10000, 2000
assert(not M.Sample(session, 30))
assert(M.Sample(session, 60))
assert(M.Sample(session, 60, true) and #session.samples == 2)
M.StartHistory(session, 2000, 60)
assert(session.startedAt == 1000 and #session.samples == 2, "Reload must preserve date and samples")
local record = M.Archive(db, session, 3600, 5000, "new")
assert(record.duration == 3600 and record.net == 8000 and record.startedAt == 1000 and record.endedAt == 5000)
assert(record.reason == "new" and #record.samples == 3)
session.xp, session.samples[1].xp = 999, 999
assert(record.xp == 100 and record.samples[1].xp == 0, "Archives must not alias live state")
assert(not M.Archive(db, session, 3600, 6000, "new") and #db.history == 1, "Archive exactly once")

local second = New()
M.StartHistory(second, 6000, 0)
second.xp, second.expense, second.approximateXP = 900, 10000, true
M.Archive(db, second, 7200, 13200, "logout")
local totals = M.HistoryTotals(db.history)
assert(totals.count == 2 and totals.duration == 10800 and totals.xp == 1000 and totals.net == -2000)
assert(totals.xpPerHour == 333 and totals.netPerHour == -2000 / 3 and totals.approximateXP)
local series = M.HistorySeries(db.history, "xpPerHour")
assert(#series == 2 and series[1].y == 100 and series[2].y == 450, "Rates must not be averaged without duration weighting")
local net = M.HistorySeries(db.history, "net")
assert(net[2].y == -10000)

local legacy = New()
legacy.elapsed, legacy.xp = 123, 50
M.StartHistory(legacy, 10000, 123)
assert(legacy.startedAt == nil and legacy.samples[1].xp == 50 and legacy.samples[1].elapsed == 123,
    "Do not invent the start of a legacy session")
for elapsed = 180, 60000, 60 do M.Sample(legacy, elapsed) end
assert(#legacy.samples <= M.SampleLimit and legacy.samples[1].elapsed == 123)
M.Sample(legacy, 60010, true)
assert(legacy.samples[#legacy.samples].elapsed == 60010)
for i = 2, #legacy.samples do assert(legacy.samples[i].elapsed > legacy.samples[i - 1].elapsed) end

local empty = New()
assert(not M.Archive(db, empty, 0, 1000, "manual") and #db.history == 2)
local short = New()
short.xp = 5
assert(M.Archive(db, short, 0, nil, "manual"), "Do not drop gains when the clock was unavailable")
assert(M.HistoryTotals({db.history[3]}).xpPerHour == nil)
assert(#M.HistorySeries({db.history[3]}, "xpPerHour") == 0)
for i = 1, 110 do M.Archive(db, New(), i, i, "new") end
assert(#db.history == 100 and db.history[1].duration == 11 and db.history[100].duration == 110)
db.history[#db.history + 1] = {duration = 0 / 0}
db.history[#db.history + 1] = "bad"
assert(M.NormalizeHistory(db) and #db.history == 100)
local stored = db.history
db.historyVersion = 2
assert(not M.NormalizeHistory(db) and db.history == stored, "Preserve future history data")
assert(not M.Archive(db, New(), 10, 20000, "new") and #stored == 100)
print("PASS: session history snapshots, reload continuity, weighted KPIs, bounded samples, and legacy data")
