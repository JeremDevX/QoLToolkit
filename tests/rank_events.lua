-- Deterministic clock and explicit frame methods: no WoW process required.
local env = setmetatable({}, {__index = _G})
env._G = env
local frames, scans, rankReads, actionReads = {}, 0, 0, 0
local combat, oldRank, action = false, true, 1
local methods = {}
local function Frame(_, name)
    local frame = setmetatable({scripts = {}, events = {}, shown = false}, {__index = methods})
    if name then frames[name] = frame end
    return frame
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:RegisterEvent(name) self.events[name] = true end
function methods:UnregisterEvent(name) self.events[name] = nil end
function methods:UnregisterAllEvents() self.events = {} end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsVisible() return self.shown end
function methods:IsForbidden() return false end
function methods:GetObjectType() return "CheckButton" end
function methods:GetAttribute(key) return key == "type" and "action" or action end
function methods:GetLeft() return 10 end
function methods:GetBottom() return 20 end
function methods:GetWidth() return 36 end
function methods:GetHeight() return 36 end
function methods:GetEffectiveScale() return 1 end
function methods:GetEffectiveAlpha() return 1 end
function methods:GetFrameStrata() return "MEDIUM" end
function methods:GetFrameLevel() return 1 end
function methods:CreateTexture() return Frame() end
function methods:CreateFontString() return Frame() end
for _, name in ipairs({"SetSize", "EnableMouse", "SetAllPoints", "SetColorTexture", "SetText", "SetTextColor",
    "SetPoint", "SetTexture", "SetVertexColor", "SetAlpha", "ClearAllPoints", "SetFont", "SetFrameStrata",
    "SetFrameLevel"}) do methods[name] = function() end end
env.CreateFrame = Frame
env.UIParent = Frame()
env.SlashCmdList = {}
env.InCombatLockdown = function() return combat end
env.issecretvalue = function() return false end
env.ForeverTooltipLibreDB = {rankGuard = {enabled = true, interval = 0.5}}
env.Enum = {SpellBookSpellBank = {Player = 1}, SpellBookItemType = {Spell = 1}}
env.GetActionInfo = function(id)
    actionReads = actionReads + 1
    return "spell", id == 1 and 100 or 200
end
env.C_SpellBook = {
    FindSpellBookSlotForSpell = function(id) return id, 1 end,
    GetSpellBookItemInfo = function(id)
        return {itemType = 1, spellID = id, actionID = id, isOffSpec = false, isPassive = false}
    end,
    IsSpellBookItemLowRank = function(id) rankReads = rankReads + 1; return id == 100 and oldRank end,
}
local button = Frame(); button.icon = {}; button:Show()
env.EnumerateFrames = function(previous)
    assert(not combat, "Never enumerate frames in combat")
    if previous == nil then scans = scans + 1; return button end
end
local module
local ns = {L = function(text) return text end,
    RegisterModule = function(_, value) module = value end,
    UI = {GetStyle = function() end}}
local function Load(path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("QoLToolkit", ns)
end
Load("Core/WoWRuntime.lua")
Load("Modules/RankGuard.lua")
ns.InitializeRankGuard(nil)
local driver = assert(frames.ArkannsQOLRankEvents)
local function Event(name)
    if driver.events[name] then driver.scripts.OnEvent(driver, name) end
end
local function Tick(seconds)
    if driver.shown then driver.scripts.OnUpdate(driver, seconds) end
end
assert(module.ExportSettings().interval == 30, "Normalize legacy saved intervals")
assert(driver.events.TRAINER_SHOW and driver.events.LEARNED_SPELL_IN_SKILL_LINE and driver.events.SPELLS_CHANGED)
Event("PLAYER_ENTERING_WORLD")
assert(scans == 1 and rankReads == 1, "Check immediately on entering the world")
Tick(29)
assert(scans == 1 and rankReads == 1, "Visual updates must not rescan ranks")
Tick(1)
assert(scans == 2 and rankReads == 2, "Check ranks and discover buttons every 30 seconds")
for _ = 1, 30 do Event("ACTIONBAR_PAGE_CHANGED"); Tick(1) end
assert(scans == 3 and rankReads == 3, "Page events must not postpone or multiply the periodic scan")
local before = scans
Event("TRAINER_SHOW")
assert(scans == before + 1 and rankReads == 4, "Trainer opening checks immediately")
oldRank = false
Event("LEARNED_SPELL_IN_SKILL_LINE")
assert(scans == before + 2 and rankReads == 5, "Learning invalidates the cached rank immediately")
for _ = 1, 20 do Event("SPELLS_CHANGED") end
Tick(.2)
assert(scans == before + 2 and rankReads == 6, "Coalesce spell changes without rediscovering all frames")
action = 2
local readsBefore = actionReads
Event("ACTIONBAR_SLOT_CHANGED"); Tick(.2)
assert(actionReads > readsBefore and rankReads == 7, "Action changes inspect the live action")
combat = true; Event("PLAYER_REGEN_DISABLED"); Tick(30)
assert(scans == before + 2, "Defer periodic discovery in combat")
combat = false; Event("PLAYER_REGEN_ENABLED")
assert(scans == before + 3, "Perform deferred discovery when combat ends")
module.SetEnabled(false)
local stoppedScans, stoppedRanks, stoppedActions = scans, rankReads, actionReads
Tick(60); Event("TRAINER_SHOW"); Event("LEARNED_SPELL_IN_SKILL_LINE")
assert(scans == stoppedScans and rankReads == stoppedRanks and actionReads == stoppedActions,
    "Disabling stops timers and event work")
local old = module.ExportSettings(); old.interval = 2
module.profileMigrations[1](old)
assert(old.interval == 30 and module.ImportSettings(old) and module.ExportSettings().interval == 30,
    "Migrate and import old profiles at the fixed cadence")
old.enabled, old.interval = true, 10
assert(module.ImportSettings(old))
Tick(.2)
assert(scans == stoppedScans + 1, "Reactivation rediscovers buttons")
Tick(29.8)
assert(scans == stoppedScans + 2, "Reactivation restarts the 30-second clock")
print("PASS: rank cadence, immediate trainer/learning checks, event coalescing, combat, profiles, and disable")
