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

local frames = {}
local methods = {}
function methods:SetScript(key, callback) self.scripts[key] = callback end
methods.HookScript = methods.SetScript
function methods:SetPoint(_, x, y) self.x, self.y = x, y end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:GetUnboundedStringWidth() return #self.text * 6 end
function methods:GetStringHeight() return 14 * math.max(1, math.ceil(#self.text * 6 / self.width)) end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetChecked(checked) self.checked = checked end
function methods:GetChecked() return self.checked end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow() end end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetVerticalScroll(offset) self.offset = offset end
function methods:GetVerticalScroll() return self.offset end
function methods:SetScrollChild(child) self.child = child end
local function Noop() end
local function Frame(kind, name, parent)
    local frame = setmetatable({parent = parent, scripts = {}, width = 1, height = 1, offset = 0, text = ""},
        {__index = function(_, key) return methods[key] or Noop end})
    if kind == "CheckButton" then frame.Text = Frame() end
    if name then frames[name] = frame end
    return frame
end
function methods:CreateFontString() return Frame() end
env.CreateFrame, env.Settings = Frame, {RegisterCanvasLayoutSubcategory = Noop}
ns.UI.RegisterSettingsPanel = Noop
ns.UI.StyleButton = Noop
ns.InitializeProfiles({})
local panel, scroll = frames.ArkannsQOLProfilesPanel, frames.ArkannsQOLProfilePreviewScroll
local reviewButton, applyButton = frames.ArkannsQOLProfileReview, frames.ArkannsQOLProfileApply
panel:SetSize(320, 280); scroll:SetSize(270, 248); panel:Show()
assert(not reviewButton.enabled and reviewButton.parent == scroll.child and scroll.child.height > scroll.height)
local longName = ("LongName"):rep(12)
frames.ArkannsQOLProfileName:SetText(longName)
frames.ArkannsQOLProfileSave.scripts.OnClick()
assert(env.ForeverTooltipLibreDB.profiles[longName] and reviewButton.enabled and not applyButton.enabled)
assert(reviewButton.y > applyButton.y and applyButton.x + applyButton.width <= scroll.child.width)
values.talents.x = .91
reviewButton.scripts.OnClick()
assert(applyButton.enabled and values.talents.x == .91, "Review does not apply settings")
panel:SetWidth(640); scroll:SetWidth(590); panel.scripts.OnSizeChanged()
assert(reviewButton.y == applyButton.y and applyButton.enabled)
scroll:SetVerticalScroll(10000)
local first = frames.ArkannsQOLProfileModule1
first:SetChecked(false); first.scripts.OnClick(first)
assert(not applyButton.enabled and scroll.offset == math.max(0, scroll.child.height - scroll.height))
print("PASS: partial profile appearance, legacy migration, distance ownership, readable review, undo, and deletion")
