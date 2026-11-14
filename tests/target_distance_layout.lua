-- Exercise the live target-distance entry point without loading settings UI or the game.
local env = setmetatable({}, {__index = _G})
env._G = env
local secret = setmetatable({}, {__add = function() error("Secret arithmetic") end,
    __lt = function() error("Secret comparison") end})
env.issecretvalue = function(value) return value == secret end
local player, custom, combat, refusedPlayer = false, false, false, false
env.UnitIsPlayer = function(unit)
    assert(unit == "target")
    if refusedPlayer then error("Refused target type") end
    return player
end
env.UnitExists = function(unit) return unit == "target" end
env.UnitDistanceSquared = function(unit) assert(unit == "target"); return 400, true end
env.InCombatLockdown = function() return combat end
env.ForeverTooltipLibreDB = {targetDistance = {enabled = true, appearance = {x = 7, y = 4}}}
local frames, widgets, methods = {}, {}, {}
local nativeWrites, anchorWrites = 0, 0
local function Widget(name, parent, native)
    local object = setmetatable({parent = parent, native = native, shown = true, alpha = 1,
        scale = 1, level = 3, strata = "LOW", points = {}, scripts = {}, events = {}, text = ""}, {__index = methods})
    widgets[#widgets + 1] = object
    if name then frames[name] = object end
    return object
end
local function Mutation(object) if object.native then nativeWrites = nativeWrites + 1 end end
function methods:IsForbidden() return false end
function methods:IsVisible() return self.shown end
function methods:IsAnchoringSecret() return self.secretLayout or false end
function methods:GetFrameStrata() return self.strata end
function methods:GetFrameLevel() return self.level end
function methods:GetEffectiveScale() return self.scale end
function methods:GetEffectiveAlpha() return self.alpha end
function methods:SetFrameStrata(value) Mutation(self); self.strata = value end
function methods:SetFrameLevel(value) Mutation(self); self.level = value end
function methods:SetScale(value) Mutation(self); self.scale = value end
function methods:SetAlpha(value) Mutation(self); self.alpha = value end
function methods:Hide() Mutation(self); self.shown = false end
function methods:Show() Mutation(self); self.shown = true end
function methods:SetShown(value) Mutation(self); self.shown = value end
function methods:SetSize(width, height) Mutation(self); self.width, self.height = width, height end
function methods:SetWidth(width) Mutation(self); self.width = width end
function methods:SetClampedToScreen(value) Mutation(self); self.clamped = value end
function methods:EnableMouse(value) Mutation(self); self.mouse = value end
function methods:ClearAllPoints() Mutation(self); self.points = {} end
function methods:SetPoint(...)
    Mutation(self); anchorWrites = anchorWrites + 1; self.points[#self.points + 1] = {...}
end
function methods:CreateFontString() return Widget(nil, self) end
function methods:SetFont() end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #self.text * 7 end
function methods:SetTextColor(...) self.color = {...} end
function methods:SetBackdrop(value) self.backdrop = value end
function methods:SetBackdropColor(...) self.background = {...} end
function methods:SetBackdropBorderColor(...) self.border = {...} end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterAllEvents() self.events = {} end
env.UIParent = Widget()
env.CreateFrame = function(_, name, parent)
    return Widget(name, parent)
end
env.TargetFrame = Widget(nil, nil, true)
env.TargetFrame.level, env.TargetFrame.scale, env.TargetFrame.alpha = 4, .8, .6
local name = Widget(nil, nil, true)
local portrait = Widget(nil, nil, true)
env.TargetFrame.name, env.TargetFrame.portrait = name, portrait
env.TargetFrame.TargetFrameContent = {TargetFrameContentMain = {Name = name}}
local module
local ns = {L = function(value) return value end,
    RegisterModule = function(_, descriptor) module = descriptor end,
    PaladinCustomTest = {IsActive = function(unit) assert(unit == "target"); return custom end}}
local function Load(path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("QoLToolkit", ns)
end
Load("Core/WoWRuntime.lua")
Load("Modules/TargetDistance.lua")
ns.InitializeTargetDistance()
local driver = assert(frames.ArkannsQOLTargetDistanceEvents)
local badge = assert(module.DiagnosticFrame())
local function Tick() driver.scripts.OnUpdate(driver, .25) end
local function Event(event) driver.scripts.OnEvent(driver, event) end
local function Point() return assert(badge.points[1]) end
assert(badge.shown and badge.clamped and not badge.mouse and badge.scale == .8 and badge.alpha == .6)
assert(Point()[2] == name and Point()[3] == "TOP" and Point()[4] == 7 and Point()[5] == 12
    and badge.level == 5, "NPC names retain their native distance position, layer and saved offsets")
player = true
Tick()
assert(Point()[2] == name and Point()[4] == 7 and Point()[5] == 24 and badge.level == 5,
    "Player targets gain exactly 12 UI units without moving the shared native name anchor")
custom = true
Tick()
assert(Point()[5] == 24 and badge.level > env.TargetFrame.level + 8,
    "The distance badge stays above the full class skin and its opaque name plaque")
custom = false
Tick()
assert(badge.level == 5 and Point()[5] == 24, "Leaving custom mode restores the original frame level")
custom = true
player = false
Tick()
assert(Point()[5] == 12 and badge.level == 5,
    "Player-to-NPC transitions invalidate placement even when the native name region is unchanged")
player = secret
Tick()
assert(Point()[5] == 12 and badge.level == 5, "A secret target type cannot trigger a player-only offset or elevated layer")
player, refusedPlayer = true, true
Tick()
assert(Point()[5] == 12 and badge.level == 5, "A refused target-type query preserves native placement")
refusedPlayer = false
local isPlayer = env.UnitIsPlayer
env.UnitIsPlayer = false
Tick()
assert(Point()[5] == 12 and badge.level == 5, "An absent target-type API keeps the native layout")
env.UnitIsPlayer = isPlayer
Tick(); assert(Point()[5] == 24 and badge.level > env.TargetFrame.level + 8)

combat = true
local beforeCombatAnchors, beforeCombatWidgets = anchorWrites, #widgets
player = false
Event("PLAYER_TARGET_CHANGED")
assert(not badge.shown and anchorWrites == beforeCombatAnchors and #widgets == beforeCombatWidgets,
    "A player-to-NPC placement change waits for combat to end without creating or re-anchoring widgets")
combat = false
Event("PLAYER_REGEN_ENABLED")
assert(badge.shown and Point()[5] == 12 and badge.level == 5,
    "The deferred NPC placement and original layer return on the first safe event")
combat = true
beforeCombatAnchors = anchorWrites
player = true
Event("PLAYER_TARGET_CHANGED")
assert(not badge.shown and anchorWrites == beforeCombatAnchors,
    "The player-only lift also waits for a safe transition")
combat = false
Event("PLAYER_REGEN_ENABLED")
assert(badge.shown and Point()[5] == 24 and badge.level > env.TargetFrame.level + 8)
combat = true
beforeCombatAnchors = anchorWrites
Tick()
assert(badge.shown and anchorWrites == beforeCombatAnchors,
    "An unchanged player layout continues displaying distance during combat")
combat = false

name.secretLayout = true
Tick()
assert(Point()[2] == env.TargetFrame and Point()[3] == "TOPRIGHT" and Point()[4] == -129 and Point()[5] == -2,
    "The fixed public-frame fallback receives the same 12 UI lift without reading secret name geometry")
player = false
Tick()
assert(Point()[5] == -14 and badge.level == 5, "NPC fallback geometry remains identical to its previous placement")
name.secretLayout = false
local settings = module.ExportSettings()
assert(settings.appearance.x == 7 and settings.appearance.y == 4,
    "Player layout never rewrites saved placement preferences")
settings.appearance.portrait = true
assert(module.ImportSettings(settings))
assert(Point()[2] == portrait and Point()[5] == 19, "NPC portrait anchoring retains its original 15-unit gap")
player = true
Tick()
assert(Point()[2] == portrait and Point()[5] == 31, "The player lift also preserves an explicit portrait anchor")
assert(nativeWrites == 0, "No native frame, name or portrait is modified")
print("PASS: player-only target distance lift, custom skin layering, cached transitions, secret fallbacks and combat deferral")
