-- Profile transfers use real UI and profile code; game-facing modules expose small contracts.
local env = setmetatable({
    ForeverTooltipLibreDB = {},
    UnitClass = function() return "Mage", "MAGE" end,
    InCombatLockdown = function() return false end,
}, {__index = _G})
local ns = {L = function(text) return text end}
local function Load(path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("QoLToolkit", ns)
end
Load("Core/QOLInterface.lua")
ns.UI.Initialize()
local copy = ns.UI.Copy
local values = {
    talents = {enabled = true, nextColor = {1, 0, 0}, x = .4, y = .6, customTitle = "true|test\nfalse"},
    tooltips = {enabled = true},
    distance = {enabled = true, mouseoverDistance = true},
}
for id, value in pairs(values) do
    local key = id
    ns.RegisterModule(key, {
        label = key == "talents" and "Talents" or key,
        profileClassIndependent = true,
        ExportSettings = function() return copy(values[key]) end,
        ImportSettings = function(config) values[key] = copy(config); return true end,
    })
end
ns.RegisterModule("appearance", {label = "Apparence", ExportSettings = ns.UI.ExportSettings, ImportSettings = ns.UI.ImportSettings})
Load("Core/Profiles.lua")
local profiles = ns.Profiles
ns.UI.SetOverride("talents", true)
assert(profiles.Save("Source"))
local source = env.ForeverTooltipLibreDB.profiles.Source
assert(source.version == 3 and source.modules.talents._appearanceOverride == true)
assert(source.modules.appearance.overrides == nil)
ns.UI.SetOverride("talents", false)
ns.UI.SetOverride("session", true)
values.talents.nextColor, values.talents.x = {0, 0, 1}, .8
values.talents.customTitle = nil
local plan = assert(profiles.Preview("Source", {talents = true}))
local review = table.concat(plan.changes, "\n")
assert(review:find("Couleur du prochain point", 1, true) and review:find("#0000FF > #FF0000", 1, true))
assert(review:find("Position", 1, true) and not review:find("nextColor", 1, true))
assert(review:find("X 80.0 % / Y 60.0 % > X 40.0 % / Y 60.0 %", 1, true))
assert(review:find("désactivé > activé", 1, true) and review:find("Non défini > true||test false", 1, true))
assert(profiles.Apply(plan))
assert(ns.UI.IsOverride("talents") and ns.UI.IsOverride("session"), "Partial profile must restore its style without changing another module")
assert(profiles.Undo())
assert(not ns.UI.IsOverride("talents") and ns.UI.IsOverride("session") and values.talents.x == .8)

-- Old profiles stored style selection inside the global appearance payload.
for _, version in ipairs({1, 2}) do
    local legacy = copy(source)
    legacy.version = version
    legacy.modules.appearance.overrides = {talents = true}
    legacy.modules.talents._appearanceOverride = nil
    legacy.modules.tooltips._appearanceOverride = nil
    if version == 1 then legacy.moduleVersions = nil end
    env.ForeverTooltipLibreDB.profiles.Legacy = legacy
    assert(profiles.Apply(assert(profiles.Preview("Legacy", {talents = true}))))
    assert(ns.UI.IsOverride("talents"))
    assert(profiles.Undo() and not ns.UI.IsOverride("talents"))
end
local legacy = env.ForeverTooltipLibreDB.profiles.Legacy
legacy.modules.tooltips.mouseoverDistance = false
legacy.modules.distance.mouseoverDistance = nil
assert(profiles.Apply(assert(profiles.Preview("Legacy", {distance = true}))))
assert(values.distance.mouseoverDistance == false)
assert(profiles.Undo() and values.distance.mouseoverDistance == true)
values.tooltips.enabled = false
assert(profiles.Apply(assert(profiles.Preview("Legacy", {tooltips = true}))))
assert(values.distance.mouseoverDistance == true, "Tooltip-only profile must preserve distance settings")
assert(profiles.Undo())

-- Applying only the common theme keeps every module's style selection.
local theme = ns.UI.ExportSettings(); theme.opacity = .4; ns.UI.ImportSettings(theme)
assert(profiles.Apply(assert(profiles.Preview("Source", {appearance = true}))))
assert(ns.UI.IsOverride("session") and not ns.UI.IsOverride("talents"))
assert(profiles.Undo())
local before = copy(values.talents)
assert(profiles.Delete("Source") and env.ForeverTooltipLibreDB.profiles.Source == nil)
assert(values.talents.x == before.x and ns.UI.IsOverride("session"))
assert(not profiles.Delete("Source"))
print("PASS: partial profile appearance, legacy migration, distance ownership, readable review, undo, and deletion")
