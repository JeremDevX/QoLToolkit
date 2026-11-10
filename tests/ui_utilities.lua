-- Run the real settings callbacks with a small offline widget model.
local env = setmetatable({}, {__index = _G})
env._G = env
local frames, widgets, modules = {}, {}, {}
local noop = function() end
local methods = {}
local function Widget(kind, name, parent)
    local widget = setmetatable({kind = kind, parent = parent, width = 600, height = 400,
        scale = 1, alpha = 1, scripts = {}, shown = false, points = {}, text = ""}, {__index = methods})
    widgets[#widgets + 1] = widget
    if name then frames[name] = widget; env[name] = widget end
    return widget
end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetScale(s) self.scale = s end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetEffectiveAlpha() return self.alpha end
function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
function methods:ClearAllPoints() self.points = {} end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:HookScript(event, fn)
    local before = self.scripts[event]
    self.scripts[event] = function(...) if before then before(...) end; fn(...) end
end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:IsForbidden() return false end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #self.text * 6 end
function methods:GetStringHeight() return math.max(14, math.ceil(#self.text * 6 / math.max(1, self.width)) * 14) end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = value end
function methods:Disable() self.enabled = false end
function methods:SetClampedToScreen(value) self.clamped = value end
function methods:EnableMouse(value) self.mouse = value end
function methods:SetFrameStrata(value) self.strata = value end
function methods:GetFrameStrata() return self.strata or "MEDIUM" end
function methods:SetFrameLevel(value) self.level = value end
function methods:GetFrameLevel() return self.level or 0 end
function methods:CreateFontString() return Widget("FontString", nil, self) end
function methods:CreateTexture() return Widget("Texture", nil, self) end
function methods:GetFontString() self.font = self.font or self:CreateFontString(); return self.font end
function methods:GetThumbTexture() return Widget("Texture", nil, self) end
function methods:SetScrollChild(child) self.child = child end
for _, name in ipairs({"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetMovable", "RegisterForDrag",
    "SetAllPoints", "SetFont", "SetTextColor", "SetJustifyH", "SetFontString", "SetAutoFocus", "SetMaxLetters",
    "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetOrientation", "SetThumbTexture", "SetValue",
    "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "SetNormalTexture", "SetHighlightTexture",
    "RegisterForClicks", "SetTexCoord", "SetVertexColor", "SetColorTexture", "SetTexture", "SetWordWrap",
    "ClearFocus", "SetVerticalScroll", "StartMoving", "StopMovingOrSizing"}) do methods[name] = noop end
function methods:HasFocus() return false end
env.CreateFrame = Widget
env.UIParent = Widget("Frame"); env.UIParent:SetSize(1200, 800)
env.GameTooltip = Widget("GameTooltip")
env.SlashCmdList = {}
env.InCombatLockdown = function() return false end
env.issecretvalue = function(value) return value == "secret" end
env.Enum = {TooltipDataType = {Unit = 1, Item = 2, Spell = 3}}
env.hooksecurefunc = noop
env.Settings = {
    RegisterCanvasLayoutSubcategory = function(_, frame) return {frame = frame, GetID = function() return 1 end} end,
    OpenToCategory = noop,
}
env.ForeverTooltipLibreDB = {targetDistance = {enabled = false}, rankGuard = {enabled = false}}
env.UnitExists = function() return true end
env.UnitDistanceSquared = function() return 400, true end
env.UnitCanAttack = function() return true end
env.EnumerateFrames = function() return nil end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}; for key, item in pairs(value) do copy[key] = Copy(item) end; return copy
end
local ns = {L = function(text) return text end, RegisterModule = function(id, module) modules[id] = module end}
local ui = {Copy = Copy, StylePanel = noop, StyleFrame = noop, StyleButton = noop, Refresh = noop,
    GetStyle = function() return nil end, IsOverride = function() return false end, SetOverride = noop}
ns.UI = ui
function ui.Label(parent, text, x, y)
    local label = parent:CreateFontString(); label:SetText(text); label:SetPoint("TOPLEFT", x, y); return label
end
function ui.Button(parent, name, text, x, y, width, callback)
    local button = Widget("Button", name, parent); button:SetText(text); button:SetSize(width, 26)
    button:SetPoint("TOPLEFT", x, y); button:SetScript("OnClick", callback); return button
end
function ui.Check(parent, name, text, x, y, callback)
    local check = Widget("CheckButton", name, parent); check.label = ui.Label(check, text, 32, -6)
    check:SetPoint("TOPLEFT", x, y); check:SetScript("OnClick", function(self) callback(self:GetChecked()) end); return check
end
function ui.Input(parent, name) return Widget("EditBox", name, parent) end
local selected
function ui.StartLayout(id) selected = id; return true end
function ui.PreviewModule(id) return modules[id].Preview() end
ns.StopAllPreviews = noop
local function Load(path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("QoLToolkit", ns)
end
local function Click(name)
    local widget = assert(frames[name], name); assert(widget.scripts.OnClick, name)(widget)
end
Load("Core/WoWRuntime.lua")
Load("Modules/Tooltips.lua")
ns.InitializeTooltips({})
Load("Modules/TargetDistance.lua")
ns.InitializeTargetDistance({})
frames.ArkannsQOLTargetDistanceSettings.scripts.OnShow()

local settings = modules.distance.ExportSettings()
settings.mouseoverDistance = false
settings.appearance.x, settings.appearance.y, settings.appearance.portrait = 35, -22, true
settings.appearance.rounded = false
settings.appearance.tooltip[1] = {.1, .2, .3}
assert(modules.distance.ImportSettings(settings))
assert(not ns.GetMouseoverDistanceSetting())
Click("ArkannsQOLDistanceResetColors")
local after = modules.distance.ExportSettings()
assert(after.appearance.x == 35 and after.appearance.y == -22 and after.appearance.portrait,
    "Resetting colors must preserve the chosen target anchor")
assert(not after.appearance.rounded and not after.mouseoverDistance)
assert(after.appearance.tooltip[1][1] ~= .1)
settings.appearance.tooltip[1] = {.1, .2, .3}
assert(modules.distance.ImportSettings(settings))
Click("ArkannsQOLDistanceResetPosition")
after = modules.distance.ExportSettings()
assert(after.appearance.x == 0 and after.appearance.y == 0 and not after.appearance.portrait)
assert(after.appearance.tooltip[1][1] == .1 and not after.appearance.rounded,
    "Resetting placement must preserve colors and range rounding")
local checkbox = frames.ArkannsQOLDistanceMouseover
checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox)
assert(ns.GetMouseoverDistanceSetting() and modules.distance.ExportSettings().mouseoverDistance)
assert(modules.tooltips.ExportSettings().mouseoverDistance == nil, "Distance settings have one profile owner")
Click("ForeverTooltipLibrePlace")
assert(selected == "tooltips")
assert(modules.tooltips.Preview(true) == true and not frames.ForeverTooltipLibreAnchor.mouse)
assert(frames.ForeverTooltipLibreAnchor.strata == "MEDIUM", "Placement previews stay below movers")
env.InCombatLockdown = function() return true end
modules.tooltips.StopPreview()
local ok, reason = modules.tooltips.Preview(true)
assert(ok == false and type(reason) == "string" and not frames.ForeverTooltipLibreAnchor.shown)
env.InCombatLockdown = function() return false end
local ended
ui.PreviewEnded = function(id) ended = id end
assert(modules.tooltips.Preview())
assert(frames.ForeverTooltipLibreAnchor.strata == "DIALOG", "Appearance previews stay above native settings")
modules.tooltips.StopPreview()
assert(ended == "tooltips", "Stopping a preview must clear its shared controls")
modules.tooltips.SetEnabled(false)
assert(modules.tooltips.Summary() == "Placement WoW" and ns.GetMouseoverDistanceSetting(),
    "The tooltip switch describes placement while mouseover distance remains independent")
modules.tooltips.SetEnabled(true)

env.TargetFrame = Widget("Frame"); env.TargetFrame:Show(); env.TargetFrame:SetScale(.8); env.TargetFrame:SetAlpha(.6)
env.TargetFrame:SetFrameStrata("LOW"); env.TargetFrame:SetFrameLevel(4)
env.TargetFrame.name = Widget("FontString"); env.TargetFrame.name:Show()
modules.distance.SetEnabled(true)
local badge
for _, widget in ipairs(widgets) do
    if widget.parent == frames.ArkannsQOLTargetDistanceEvents then badge = widget end
end
assert(badge and badge.clamped and not badge.mouse and badge.scale == .8 and badge.alpha == .6)
assert(badge.strata == "LOW" and badge.level == 5, "The badge must follow the target frame's presentation")
local panel = frames.ArkannsQOLTargetDistanceSettings
panel:SetWidth(330); panel.scripts.OnSizeChanged()
assert(frames.ArkannsQOLDistanceResetColors.points[1][5] < -700, "Narrow color controls must wrap vertically")

Load("Modules/RankGuard.lua")
ns.InitializeRankGuard({})
local rankPanel = frames.ArkannsQOLRankSettings
rankPanel:SetWidth(330); rankPanel.scripts.OnShow()
assert(not frames.ArkannsQOLRankStyle.shown and frames.ArkannsQOLRankAddException.shown)
Click("ArkannsQOLRankAppearanceToggle")
assert(frames.ArkannsQOLRankStyle.shown and frames.ArkannsQOLRankStyle.width <= 280)
assert(frames.ArkannsQOLRankStyle.parent.height > 900, "A narrow rank page must scroll rather than clip")
env.InCombatLockdown = function() return true end
ok, reason = modules.ranks.Preview()
assert(ok == false and type(reason) == "string")
env.InCombatLockdown = function() return false end
ended = nil
assert(modules.ranks.Preview())
frames.ArkannsQOLRankEvents.scripts.OnUpdate(nil, 12)
assert(ended == "ranks", "Expiring a rank preview must clear its shared controls")
print("PASS: utility settings, independent resets, shared placement, badge bounds, and narrow rank layout")

-- Exercise profile migration through the actual tooltip and distance importers.
env.InCombatLockdown = function() return false end
ns.modules = {tooltips = modules.tooltips, distance = modules.distance}
local overrides = {}
ui.IsOverride = function(id) return overrides[id] == true end
ui.SetOverride = function(id, value) overrides[id] = value == true end
Load("Core/Profiles.lua")
local profiles = ns.Profiles
ns.SetMouseoverDistanceSetting(true)
assert(profiles.Save("Utilities"))
local source = env.ForeverTooltipLibreDB.profiles.Utilities
assert(source.version == 3 and source.modules.tooltips.mouseoverDistance == nil)
assert(source.modules.distance.mouseoverDistance == true)
ns.SetMouseoverDistanceSetting(false)
modules.tooltips.SetEnabled(false)
assert(profiles.Apply(assert(profiles.Preview("Utilities", {distance = true}))))
assert(ns.GetMouseoverDistanceSetting() and not modules.tooltips.IsEnabled())
assert(profiles.Undo() and not ns.GetMouseoverDistanceSetting())
assert(profiles.Apply(assert(profiles.Preview("Utilities", {tooltips = true}))))
assert(modules.tooltips.IsEnabled() and not ns.GetMouseoverDistanceSetting())
assert(profiles.Undo() and not modules.tooltips.IsEnabled())

for _, version in ipairs({1, 2}) do
    local legacy = Copy(source)
    legacy.version = version
    legacy.modules.appearance = {overrides = {tooltips = true}}
    legacy.modules.tooltips._appearanceOverride = nil
    legacy.modules.tooltips.mouseoverDistance = true
    legacy.modules.distance.mouseoverDistance = nil
    legacy.moduleVersions = version == 2 and {tooltips = 1, distance = 1} or nil
    env.ForeverTooltipLibreDB.profiles.LegacyUtilities = legacy
    assert(profiles.Apply(assert(profiles.Preview("LegacyUtilities", {tooltips = true}))))
    assert(modules.tooltips.IsEnabled() and ui.IsOverride("tooltips"))
    assert(not ns.GetMouseoverDistanceSetting(), "Old tooltip-only transfers must preserve Distance ownership")
    assert(profiles.Undo() and not modules.tooltips.IsEnabled() and not ui.IsOverride("tooltips"))
    assert(profiles.Apply(assert(profiles.Preview("LegacyUtilities", {distance = true}))))
    assert(ns.GetMouseoverDistanceSetting() and not modules.tooltips.IsEnabled())
    assert(profiles.Undo() and not ns.GetMouseoverDistanceSetting())
    assert(profiles.Apply(assert(profiles.Preview("LegacyUtilities", {tooltips = true, distance = true}))))
    assert(ns.GetMouseoverDistanceSetting() and modules.tooltips.IsEnabled() and ui.IsOverride("tooltips"))
    assert(profiles.Undo())
    assert(not ns.GetMouseoverDistanceSetting() and not modules.tooltips.IsEnabled() and not ui.IsOverride("tooltips"))
    assert(legacy.modules.tooltips.mouseoverDistance == true and legacy.modules.distance.mouseoverDistance == nil,
        "Reading a legacy profile must preserve its saved contents")
end
local legacy = env.ForeverTooltipLibreDB.profiles.LegacyUtilities
legacy.modules.tooltips = nil
legacy.modules.distance.enabled = not modules.distance.IsEnabled()
assert(profiles.Apply(assert(profiles.Preview("LegacyUtilities", {distance = true}))))
assert(not ns.GetMouseoverDistanceSetting(), "An old profile without tooltip data keeps the current mouseover choice")
assert(profiles.Undo())
print("PASS: real tooltip/distance profile migrations, partial/full apply, saved-data preservation, and undo")
