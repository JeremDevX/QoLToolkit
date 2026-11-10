local manifest = assert(io.open("QoLToolkit.toc", "r"))
local chunks, catalogs = {}, {}
local firstRuntimeFile, lastFile
local addonIcon
for line in manifest:lines() do
    addonIcon = line:match("^## IconTexture:%s+Interface\\AddOns\\QoLToolkit\\(.+)$") or addonIcon
    local path = line:match("^%s*([^#].-%.lua)%s*$")
    if path then
        path = path:gsub("\\", "/")
        assert(not chunks[path], "Duplicate manifest entry: " .. path)
        chunks[path] = assert(loadfile(path))
        if path:match("^Locales/") then
            assert(not firstRuntimeFile, "Locale file loaded after runtime code: " .. path)
            catalogs[#catalogs + 1] = path
        else
            firstRuntimeFile = firstRuntimeFile or path
        end
        lastFile = path
    end
end
manifest:close()
assert(catalogs[1] == "Locales/Locale.lua", "Load the locale selector before translations")
assert(lastFile == "Core/Bootstrap.lua", "Load bootstrap after the modules")
assert(addonIcon, "Declare the packaged addon icon in the manifest")
local iconFile = assert(io.open((addonIcon:gsub("\\", "/")), "rb"))
iconFile:close()

local function CheckLocale(locale, expected)
    GetLocale = locale and function() return locale end or nil
    local ns = {}
    chunks[catalogs[1]]("QoLToolkit", ns)
    local entries = {}
    ns.English = setmetatable({}, {
        __index = entries,
        __newindex = function(_, key, value)
            assert(type(key) == "string" and type(value) == "string" and value ~= "",
                "Invalid locale entry")
            assert(not entries[key] or entries[key] == value, "Conflicting translations: " .. key)
            entries[key] = value
        end,
    })
    for i = 2, #catalogs do
        chunks[catalogs[i]]("QoLToolkit", ns)
    end
    assert(ns.L("Infobulles") == expected, "Unexpected client language")
    assert(ns.L("Annuler", "talent.undo") == (locale == "frFR" and "Annuler" or "Undo"))
    assert(ns.L("Untranslated example") == "Untranslated example", "Missing translation should use source text")
end

CheckLocale("frFR", "Infobulles")
CheckLocale("enUS", "Tooltips")
CheckLocale("enGB", "Tooltips")
CheckLocale("deDE", "Tooltips")
CheckLocale(nil, "Tooltips")
print("PASS: Lua syntax, manifest order, translations, and locale fallback")

local reminders = {}
chunks["Modules/AuraReminderModel.lua"]("QoLToolkit", reminders)
local model = reminders.AuraReminderModel
local settings = {
    auras = {
        {kind = "buff", name = "Mot de pouvoir : Robustesse", spellID = 21562},
        {kind = "aura", name = "Aura de devotion", spellID = 465},
        {kind = "buff", name = "Custom buff"},
    },
    tracking = {{name = "Decouverte de gisements", spellID = 2580}},
}
local observed = {
    buffsKnown = true, formsKnown = true,
    buffs = {[21562] = true, ["devotion aura"] = true, ["custom buff"] = true},
    forms = {[465] = {active = false}},
    tracking = {[2580] = {name = "Find Minerals", active = false}},
    resolveName = function(rule)
        if rule.spellID == 21562 then return "Power Word: Fortitude" end
        if rule.spellID == 465 then return "Devotion Aura" end
    end,
}
local missing = model.Missing(settings, observed)
assert(#missing == 2 and missing[1].name == "Devotion Aura" and missing[2].name == "Find Minerals")
observed.buffs = {["power word: fortitude"] = true, ["custom buff"] = true}
observed.forms[465].active = true
observed.tracking[2580].active = true
assert(#model.Missing(settings, observed) == 0, "Spell rank and manual name fallback")
observed.buffs = {}
observed.buffsKnown = false
assert(#model.Missing(settings, observed) == 0, "Unavailable aura data should stay silent")
print("PASS: cross-locale effect IDs, name fallback, and unavailable aura data")

local diagnosticNS = {L = function(text) return text end}
chunks["Core/WoWRuntime.lua"]("QoLToolkit", diagnosticNS)
chunks["Core/Diagnostics.lua"]("QoLToolkit", diagnosticNS)
local now, combat, callback, cancelled, eventFrame, exportBox = 0, false, nil, 0
local screen = {width = 1440, height = 900}
function screen:GetWidth() return self.width end
function screen:GetHeight() return self.height end
function screen:GetEffectiveScale() return 0.9 end
local frame = {left = 10, visible = true}
function frame:IsForbidden() return false end
function frame:IsShown() return self.visible end
function frame:IsVisible() return self.visible end
function frame:GetRect() return self.left, 20, 300, 180 end
function frame:GetEffectiveScale() return 0.9 end
function frame:GetEffectiveAlpha() return 0.75 end
function frame:GetFrameStrata() return "DIALOG" end
function frame:GetFrameLevel() return 4 end
function frame:GetPoint() return "CENTER", screen, "BOTTOMLEFT", self.left, 20 end

UIParent, GameTooltip = screen, frame
diagnosticNS.modules = {session = {frame = frame, IsEnabled = function() return true end}}
diagnosticNS.UI = {StylePanel = function() end, Label = function() end}
ForeverTooltipLibreDB, SlashCmdList = {userSetting = true}, {}
GetTime = function() return now end
GetBuildInfo = function() return "1.60.1", "70862", "Nov 2026", 16001 end
InCombatLockdown = function() return combat end
issecretvalue = function(value) return value == "secret" end
C_AddOns = {GetAddOnMetadata = function() return "0.1.0" end}
local noop = function() end
CreateFrame = function(kind, name)
    local mock = setmetatable({
        SetScript = function(self, key, value) self[key] = value end,
        RegisterEvent = function(self, event) self[event] = true end,
        UnregisterAllEvents = function(self) self.eventsCleared = true end,
        SetText = function(self, text) self.text = text end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }, {__index = function() return noop end})
    if kind == "Frame" and not name then eventFrame = mock end
    if kind == "EditBox" then exportBox = mock end
    return mock
end

local previousPrint = print
print = noop
diagnosticNS.InitializeDiagnostics()
local command = SlashCmdList.QOLTOOLKITDIAGNOSTICS
C_Timer = nil
command("start")
assert(not eventFrame and not ForeverTooltipLibreDB.diagnostics, "No work without a timer")
C_Timer = {NewTicker = function(seconds, fn)
    assert(seconds == 0.5)
    callback = fn
    return {Cancel = function() cancelled = cancelled + 1 end}
end}
assert(not callback and not eventFrame, "Registration must stay idle")
local nativeTimer = C_Timer.NewTicker
C_Timer.NewTicker = function() error("timer unavailable") end
command("start")
assert(rawget(eventFrame, "PLAYER_LOGOUT") == nil and not ForeverTooltipLibreDB.diagnostics)
C_Timer.NewTicker = nativeTimer

command("start")
local trace = ForeverTooltipLibreDB.diagnostics
assert(trace.header:find("build=70862 interface=16001", 1, true))
assert(trace.rows[1]:find("session.enabled 1", 1, true))
assert(trace.rows[1]:find("rect=10.0,20.0,300.0,180.0", 1, true))
assert(trace.rows[1]:find("strata=DIALOG level=4 anchor=CENTER/BOTTOMLEFT:10.0,20.0", 1, true))
now = 0.5
callback()
assert(#trace.rows == 1, "Unchanged samples should be skipped")

eventFrame:OnEvent("UNIT_AURA", "target")
eventFrame:OnEvent("PLAYER_XP_UPDATE", "secret")
eventFrame:OnEvent("ADDON_ACTION_BLOCKED", "AnotherAddon")
callback()
assert(#trace.rows == 1, "Ignore unrelated and secret arguments")

frame.left, now, combat = 45, 1, true
eventFrame:OnEvent("PLAYER_REGEN_DISABLED")
eventFrame:OnEvent("UNIT_AURA", "player")
callback()
assert(trace.rows[2]:find("events PLAYER_REGEN_DISABLED UNIT_AURA", 1, true))
assert(trace.rows[2]:find("tooltip.native unavailable in combat", 1, true))
assert(trace.rows[2]:find("rect=45.0,20.0,300.0,180.0", 1, true))
frame.GetRect = function() return "secret", 20, 300, 180 end
diagnosticNS.Diagnostics.Note("layout.cancel")
command("mark")
assert(trace.rows[3]:find("rect=?,?,?,?", 1, true))
assert(trace.rows[3]:find("events layout.cancel", 1, true))
assert(not trace.rows[3]:find("rect=secret", 1, true))

for _ = 1, 300 do command("mark") end
assert(#trace.rows == 260, "Trace must stay bounded")
now = 120
callback()
assert(cancelled == 1 and eventFrame.eventsCleared == true)
assert(trace.rows[#trace.rows]:find("timeout", 1, true))
callback()
assert(cancelled == 1)
combat = false
command("show")
assert(exportBox.text:find(trace.header, 1, true))
command("clear")
assert(not ForeverTooltipLibreDB.diagnostics and ForeverTooltipLibreDB.userSetting and exportBox.text == "")
command("start")
eventFrame:OnEvent("PLAYER_LOGOUT")
trace = ForeverTooltipLibreDB.diagnostics
assert(cancelled == 2 and trace.rows[#trace.rows]:find("logout", 1, true))
diagnosticNS.InitializeDiagnostics()
assert(ForeverTooltipLibreDB.diagnostics == trace, "Keep the saved capture on startup")
print = previousPrint
print("PASS: opt-in diagnostics, geometry, filtered events, export, and limits")

local journalNS = {}
chunks["Modules/SessionJournalModel.lua"]("QoLToolkit", journalNS)
local journal = journalNS.SessionJournalModel
local legacySession = journal.New(90, 100, 10, 0)
legacySession.lastLevel, legacySession.xp = 11, 100
assert(journal.BaselineXP(legacySession, 40, 100, 13))
assert(journal.ObserveXP(legacySession, 60, 100, 13))
assert(journal.ObserveXP(legacySession, 5, 100, 14))
local tracked = journal.Totals(legacySession, 0)
assert(tracked.xp == 165 and tracked.levels == 2, "Do not count XP or levels gained while tracking was paused")
print("PASS: session XP and level baselines across a pause")

local distanceNS = {L = function(text) return text end}
local distanceModule
function distanceNS.RegisterModule(_, module) distanceModule = module end
ForeverTooltipLibreDB.targetDistance = {enabled = false}
local measured, checked, hostile = 400, true, true
UnitDistanceSquared = function() return measured, checked end
UnitCanAttack = function() return hostile end
UnitCanAssist = function() return not hostile end
Enum = {SpellBookSpellBank = {Player = 0}, SpellBookItemType = {Spell = 1}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = 3} end,
    GetSpellBookItemInfo = function(slot) return {itemType = 1, spellID = slot} end,
    IsSpellBookItemInRange = function(slot) return slot ~= 1 end,
}
C_Spell = {
    GetSpellInfo = function(id) return {minRange = 0, maxRange = ({30, 40, 45})[id]} end,
    SpellHasRange = function() return true end,
    IsSpellHarmful = function(id) return id <= 2 end,
    IsSpellHelpful = function(id) return id == 3 end,
}
chunks["Core/WoWRuntime.lua"]("QoLToolkit", distanceNS)
chunks["Modules/TargetDistance.lua"]("QoLToolkit", distanceNS)
distanceNS.InitializeTargetDistance()
local getDistance = distanceNS.GetMouseoverDistance
assert(not distanceModule.IsEnabled() and getDistance() == "Distance mesurée · 18 m")
measured = "secret"
assert(getDistance() == nil, "Private measurements stay unavailable")
measured, checked = 0, false
assert(getDistance() == "Ennemi · ≈ 25–40 m", "Round both bounds outward")
hostile = false
assert(getDistance() == "Allié · ≈ 0–45 m", "Use helpful spell ranges for allies")

local config = distanceModule.ExportSettings()
config.appearance.rounded = false
config.appearance.tooltip[2] = {.2, .3, .4}
assert(getDistance() == "Allié · ≈ 0–45 m", "Profile exports must be independent")
assert(distanceModule.ImportSettings(config))
hostile = true
local text, color = getDistance()
assert(text == "Ennemi · ≈ 27–37 m" and color[1] == .2 and color[2] == .3 and color[3] == .4)
C_SpellBook.IsSpellBookItemInRange = function() return false end
config.appearance.rounded = true
assert(distanceModule.ImportSettings(config) and getDistance() == "Ennemi · ≥ 35 m")
local oldProfile = {enabled = false}
distanceModule.profileMigrations[1](oldProfile, distanceModule.ExportSettings())
assert(oldProfile.appearance.tooltip[2][1] == .2)
print("PASS: target distance sources, conservative rounding, and legacy appearance settings")
