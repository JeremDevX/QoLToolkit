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
function methods:GetTop() return self.nativeOrigin and self.nativeOrigin[2] + self.height end
function methods:GetBottom() return self.nativeOrigin and self.nativeOrigin[2] end
function methods:SetScale(s) self.scale = s end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale end
function methods:GetParent() return self.parent end
function methods:SetAlpha(a) self.alpha = a end
function methods:SetDesaturation(value) self.desaturation = value end
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
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:SetVerticalScroll(value) self.offset = value end
for _, name in ipairs({"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetMovable", "RegisterForDrag",
    "SetAllPoints", "SetFont", "SetTextColor", "SetJustifyH", "SetFontString", "SetAutoFocus", "SetMaxLetters",
    "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetOrientation", "SetThumbTexture", "SetValue",
    "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "SetNormalTexture", "SetHighlightTexture",
    "RegisterForClicks", "SetTexCoord", "SetVertexColor", "SetColorTexture", "SetTexture", "SetWordWrap",
    "ClearFocus", "StartMoving", "StopMovingOrSizing"}) do methods[name] = noop end
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
local ns = {L = function(text) return text end}
function ns.RegisterModule(id, module)
    modules[id] = module
    if ns.modules then ns.modules[id] = module end
end
local ui = {Copy = Copy, StylePanel = noop, StyleFrame = noop, StyleButton = noop, Refresh = noop,
    GetStyle = function() return nil end, IsOverride = function() return false end, SetOverride = noop}
ns.UI = ui
ui.RegisterSettingsPanel = env.Settings.RegisterCanvasLayoutSubcategory
ui.OpenCategory = env.Settings.OpenToCategory
function ui.ClampScroll(scroll, height)
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, height - scroll:GetHeight())))
end
local confirmation, menu
function ui.Confirm(_, accept) confirmation = accept end
env.MenuUtil = {CreateContextMenu = function(_, setup)
    menu = {}
    setup(nil, {CreateButton = function(_, label, callback) menu[label] = callback end})
end}
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
assert(modules.tooltips.category() == modules.distance.category(), "Tooltips and distance share one settings category")
assert(frames.ArkannsQOLTargetDistanceSettings.parent == frames.ForeverTooltipLibreSettings,
    "Distance settings are embedded in the shared page")

local settings = modules.distance.ExportSettings()
settings.mouseoverDistance = false
settings.appearance.x, settings.appearance.y, settings.appearance.portrait = 35, -22, true
settings.appearance.rounded = false
settings.appearance.tooltip[1] = {.1, .2, .3}
assert(modules.distance.ImportSettings(settings))
assert(not ns.GetMouseoverDistanceSetting())
local colorReset = frames.ArkannsQOLDistanceResetColors
assert(not colorReset.shown, "Color customization starts collapsed")
Click("ArkannsQOLDistanceAdvanced")
assert(colorReset.shown)
Click("ArkannsQOLDistanceResetColors")
assert(confirmation and modules.distance.ExportSettings().appearance.tooltip[1][1] == .1)
confirmation()
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
local cursor = frames.ForeverTooltipLibreCursor
local offsetToggle = frames.ArkannsQOLTooltipAdvanced
local offsetBody = frames.ArkannsQOLTooltipOffsetX.parent
local behavior = frames.ForeverTooltipLibrePlace.parent
assert(not offsetToggle.shown and frames.ForeverTooltipLibrePlace.shown)
cursor:SetChecked(true); Click("ForeverTooltipLibreCursor")
assert(offsetToggle.shown and not frames.ForeverTooltipLibrePlace.shown and not offsetBody.shown)
local collapsedHeight = behavior.height
Click("ArkannsQOLTooltipAdvanced")
assert(offsetBody.shown and behavior.height > collapsedHeight)
behavior.parent:SetVerticalScroll(100)
Click("ArkannsQOLTooltipAdvanced")
assert(not offsetBody.shown and behavior.height == collapsedHeight and behavior.parent:GetVerticalScroll() == 0)
Click("ArkannsQOLTooltipKind"); menu["Objets"]()
assert(not cursor.shown and not frames.ForeverTooltipLibreEnabled.shown, "Inherited types hide redundant controls")
assert(modules.tooltips.ExportSettings().cursor, "Choosing a type keeps the general cursor setting")
Click("ArkannsQOLTooltipKind"); menu["Réglages généraux"]()
cursor:SetChecked(false); Click("ForeverTooltipLibreCursor")
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
do
    local panel = frames.ForeverTooltipLibreSettings
    local main = frames.ArkannsQOLTooltipGeneralEnabled.parent
    panel:SetWidth(857); panel.scripts.OnSizeChanged()
    local narrowMain, narrowBehavior = main:GetHeight(), behavior:GetHeight()
    assert(frames.ArkannsQOLTooltipOwnStyle.points[1][2] == 0)
    panel:SetWidth(858); panel.scripts.OnSizeChanged()
    assert(frames.ArkannsQOLTooltipOwnStyle.points[1][2] > 0,
        "Tooltip placement and appearance use separate columns")
    assert(frames.ArkannsQOLTooltipCombat.points[1][2] > 0,
        "Tooltip scale and combat behavior remain beside type placement")
    assert(main:GetHeight() < narrowMain and behavior:GetHeight() < narrowBehavior,
        "Both tooltip tabs need less scrolling when groups fit side by side")
    assert(frames.ForeverTooltipLibreSize:GetWidth() > 330, "Tooltip sliders use the available column width")
    panel:SetWidth(600); panel.scripts.OnSizeChanged()
    assert(frames.ArkannsQOLTooltipOwnStyle.points[1][2] == 0)
end

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
-- Dungeon names can have secret geometry while the portrait and target frame stay public.
do
    local frame, driver = env.TargetFrame, frames.ArkannsQOLTargetDistanceEvents
    local name, portrait = frame.name, Widget("Texture")
    portrait:Show(); frame.portrait = portrait
    frame.TargetFrameContent = {TargetFrameContentMain = {Name = name}}
    local nameSecret, portraitSecret, frameSecret = true, false, false
    name.IsAnchoringSecret = function() return nameSecret end
    portrait.IsAnchoringSecret = function() return portraitSecret end
    frame.IsAnchoringSecret = function() return frameSecret end
    local function Tick() driver.scripts.OnUpdate(nil, .2) end
    Tick()
    assert(badge.shown and badge.points[1][2] == frame and badge.points[1][3] == "TOPRIGHT"
        and badge.points[1][4] == -136 and badge.points[1][5] == -18,
        "A secret native name must retain its above-name position using the public frame")
    portraitSecret = true
    Tick()
    assert(badge.shown and badge.points[1][2] == frame,
        "A public target frame remains usable when both child anchors are restricted")
    frameSecret = true
    Tick()
    assert(not badge.shown, "Never anchor a badge when all target anchors are secret")
    nameSecret = false
    Tick()
    assert(badge.shown and badge.points[1][2] == name,
        "Restore the selected name anchor when it becomes public again")
    name.IsAnchoringSecret, frame.IsAnchoringSecret, frame.portrait = nil, nil, nil
    frame.TargetFrameContent = nil
end
-- The same hostile unit must use the target's permitted probes in both displays.
do
    local combat, same, instance, player, calls = true, true, false, false, 0
    env.UnitDistanceSquared = function() return nil, nil end
    env.UnitIsUnit = function(a, b) assert(a == "mouseover" and b == "target"); return same end
    env.InCombatLockdown = function() return combat end
    env.IsInInstance = function() return instance end
    env.UnitIsPlayer = function() return player end
    env.Enum.SpellBookSpellBank, env.Enum.SpellBookItemType = {Player = 0}, {Spell = 1}
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = 1} end,
        GetSpellBookItemInfo = function() return {itemType = 1, spellID = 1} end,
        IsSpellBookItemInRange = function() return true end,
    }
    env.C_Spell = {
        GetSpellInfo = function(id) return {minRange = 0, maxRange = id == 1 and 10 or 5} end,
        SpellHasRange = function() return true end,
        IsSpellHarmful = function() return true end,
        IsSpellHelpful = function() return false end,
    }
    env.C_Item = {
        ItemHasRange = function(id) return id == 8149 end,
        GetItemSpell = function() return "Probe", 2 end,
        IsItemInRange = function(_, unit)
            calls = calls + 1
            assert(not combat or unit == "target", "Never probe another mouseover with items in combat")
            return true
        end,
    }
    local driver = frames.ArkannsQOLTargetDistanceEvents
    driver.scripts.OnUpdate(nil, .2)
    local label
    for _, widget in ipairs(widgets) do if widget.parent == badge then label = widget end end
    assert(label.text == "≈ 0–5 m")
    assert(ns.GetMouseoverDistance() == "Distance · " .. label.text,
        "Hovering the target must match the badge's more precise combat estimate")
    for _, comparison in ipairs({false, "secret"}) do
        same = comparison
        local before = calls
        assert(ns.GetMouseoverDistance() == "Distance · ≈ 0–10 m" and calls == before)
    end
    same = true
    for _, restricted in ipairs({"instance", "player"}) do
        instance, player = restricted == "instance", restricted == "player"
        local before = calls
        driver.scripts.OnUpdate(nil, .2)
        assert(ns.GetMouseoverDistance() == "Distance · " .. label.text and calls == before)
        assert(label.text == "≈ 0–10 m")
    end
    instance, player, combat, same = false, false, false, false
    assert(ns.GetMouseoverDistance() == "Distance · ≈ 0–5 m", "Other mouseovers retain item estimates out of combat")
    same, combat = true, true
    modules.distance.SetEnabled(false)
    assert(ns.GetMouseoverDistance() == "Distance · ≈ 0–5 m", "The tooltip works with the badge disabled")
    env.UnitDistanceSquared = function() return "secret", true end
    local before = calls
    assert(ns.GetMouseoverDistance() == nil and calls == before, "Secret direct measurements never fall back to probes")
    env.UnitDistanceSquared = function() return 400, true end
    assert(ns.GetMouseoverDistance() == "Distance · 18 m")
    env.InCombatLockdown = function() return false end
    modules.distance.SetEnabled(true)
end
local panel = frames.ArkannsQOLTargetDistanceSettings
panel:SetWidth(330); panel.scripts.OnSizeChanged()
local narrowColorHeight = colorReset.parent.height
panel:SetWidth(580); panel.scripts.OnSizeChanged()
assert(colorReset.parent.height < narrowColorHeight, "Wide color controls use a table")
local tableHeight = colorReset.parent.height
panel:SetWidth(840); panel.scripts.OnSizeChanged()
assert(colorReset.points[1][4] > frames.ArkannsQOLDistanceResetPosition.points[1][4],
    "Wide distance settings place colors beside placement")
assert(colorReset.parent.height < tableHeight, "Independent distance groups reduce scrolling")
panel:SetWidth(580); panel.scripts.OnSizeChanged()
colorReset.parent.parent:SetVerticalScroll(550)
Click("ArkannsQOLDistanceAdvanced")
assert(not colorReset.shown and colorReset.parent.parent:GetVerticalScroll() == 0)

local revealed
ui.RevealControl = function(_, control) revealed = control end
modules.distance.OpenSettings("Couleur du texte")
assert(colorReset.shown, "A color result opens the advanced distance controls")
assert(revealed and revealed.parent == colorReset.parent, "A distance color result reveals its editable control")
assert(panel.shown)
modules.tooltips.OpenSettings(nil)
assert(panel.shown, "Returning from placement preserves the Distance section")
modules.tooltips.OpenSettings("Échelle")
assert(not panel.shown and revealed == frames.ForeverTooltipLibreSize)
modules.tooltips.OpenSettings("Objets")
assert(revealed == frames.ArkannsQOLTooltipKind and frames.ArkannsQOLTooltipCustom.shown)
modules.tooltips.OpenSettings("Décalage du curseur")
assert(revealed == frames.ForeverTooltipLibreCursor, "An unavailable offset reveals its cursor prerequisite")
cursor:SetChecked(true); Click("ForeverTooltipLibreCursor")
modules.tooltips.OpenSettings("Décalage X / Y (0 à 100)")
assert(revealed == frames.ArkannsQOLTooltipOffsetX and offsetBody.shown)
local advancedPage = behavior.parent
advancedPage:SetHeight(100)
advancedPage:SetVerticalScroll(45)
modules.tooltips.OpenSettings(nil)
assert(advancedPage.shown and advancedPage:GetVerticalScroll() == 45,
    "Returning from placement preserves the advanced section and its scroll")
modules.tooltips.OpenSettings("Personnaliser les infobulles")
assert(revealed == frames.ArkannsQOLTooltipGeneralEnabled and not advancedPage.shown)

Load("Modules/RankGuard.lua")
ns.InitializeRankGuard({})
local rankPanel = frames.ArkannsQOLRankSettings
rankPanel:SetWidth(330); rankPanel.scripts.OnShow()
assert(not frames.ArkannsQOLRankStyle.shown and frames.ArkannsQOLRankAddException.shown and frames.ArkannsQOLRankPreview.shown)
Click("ArkannsQOLRankAppearanceToggle")
assert(frames.ArkannsQOLRankStyle.shown and frames.ArkannsQOLRankStyle.width <= 280)
local narrowRankHeight = frames.ArkannsQOLRankStyle.parent.height
rankPanel:SetWidth(600); rankPanel.scripts.OnSizeChanged()
assert(frames.ArkannsQOLRankStyle.parent.height < narrowRankHeight, "Wide independent rank controls share rows")
assert(frames.ArkannsQOLRankCombat.points[1][5] == frames.ArkannsQOLRankRest.points[1][5])
local stackedRankHeight = frames.ArkannsQOLRankStyle.parent.height
rankPanel:SetWidth(760); rankPanel.scripts.OnSizeChanged()
assert(frames.ArkannsQOLRankAddException.points[1][4] > frames.ArkannsQOLRankPreview.points[1][4],
    "Wide rank settings place exceptions beside activation and visibility")
assert(frames.ArkannsQOLRankStyle.parent.height < stackedRankHeight,
    "Independent rank groups reduce scrolling")
rankPanel:SetWidth(600); rankPanel.scripts.OnSizeChanged()
local style = frames.ArkannsQOLRankStyle
Click("ArkannsQOLRankStyle"); menu["Bordure"]()
assert(not frames.ArkannsQOLRankCorner.shown and style.parent.height < narrowRankHeight)
env.InCombatLockdown = function() return true end
ok, reason = modules.ranks.Preview()
assert(ok == false and type(reason) == "string")
env.InCombatLockdown = function() return false end
ended = nil
assert(modules.ranks.Preview())
frames.ArkannsQOLRankEvents.scripts.OnUpdate(nil, 12)
assert(ended == "ranks", "Expiring a rank preview must clear its shared controls")
modules.ranks.OpenSettings("Couleur")
assert(frames.ArkannsQOLRankStyle.shown and revealed == frames.ArkannsQOLRankColor)
modules.ranks.OpenSettings("Exceptions")
assert(revealed == frames.ArkannsQOLRankExceptionID)
modules.ranks.OpenSettings("Coin")
assert(revealed == frames.ArkannsQOLRankStyle, "A hidden corner setting reveals the badge style prerequisite")
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

do
    local combat, player, class, replacement, secretAnchor = true, true, "MAGE", false, false
    local atlasAvailable, maskAvailable, iconAvailable = true, true, true
    local colors = {MAGE = {r = .25, g = .78, b = .92}, DRUID = {r = 1, g = .49, b = .04}}
    local container = Widget("Frame", nil, env.TargetFrame)
    local portrait = Widget("Texture", nil, container)
    portrait:Show()
    portrait.IsAnchoringSecret = function() return secretAnchor end
    env.TargetFrame.TargetFrameContainer, container.Portrait = container, portrait
    container:SetFrameLevel(4)
    env.InCombatLockdown = function() return combat end
    env.UnitIsPlayer = function(unit) assert(unit == "target"); return player end
    env.UnitClassBase = function(unit) assert(unit == "target"); return class end
    env.UnitIsUnit = function(a, b) assert(a == "target" and b == "player"); return false end
    env.C_ClassColor = {GetClassColor = function(token) return colors[token] end}
    env.C_CVar = {GetCVarBool = function(name)
        assert(name == "ReplaceOtherPlayerPortraits")
        return replacement
    end}
    function methods:SetParent(parent)
        if parent == container then assert(not combat) end
        self.parent = parent
    end
    function methods:RegisterEvent(event)
        self.events = self.events or {}; self.events[event] = true
    end
    function methods:RegisterUnitEvent(event, unit)
        self.events[event] = unit
    end
    function methods:IsEventRegistered(event) return self.events and self.events[event] ~= nil end
    function methods:UnregisterAllEvents() self.events = {} end
    function methods:CreateLine() error("Do not redraw the native portrait rim with line segments") end
    function methods:CreateMaskTexture() assert(not combat); return Widget("MaskTexture", nil, self) end
    function methods:AddMaskTexture(mask) self.mask = mask end
    methods.SetTexelSnappingBias, methods.SetSnapToPixelGrid = noop, noop
    env.C_Texture = {GetAtlasInfo = function(atlas)
        assert(atlas == "CircleMask")
        if atlasAvailable then return {width = 64, height = 64} end
    end}
    function methods:SetAtlas(atlas, useAtlasSize, filter, resetCoords, wrapH, wrapV)
        assert(self.kind == "MaskTexture" and atlasAvailable and atlas == "CircleMask")
        assert(not useAtlasSize and filter == "LINEAR" and resetCoords)
        assert(wrapH == "CLAMPTOBLACKADDITIVE" and wrapV == "CLAMPTOBLACKADDITIVE")
        self.atlas = atlas
    end
    function methods:SetDesaturated(value) self.desaturated = value end
    function methods:SetVertexColor(...) self.color = {...} end
    local maskTexture = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    function methods:SetTexture(texture, wrapH, wrapV)
        self.texture = texture
        if texture == maskTexture then
            assert(wrapH == "CLAMPTOBLACKADDITIVE" and wrapV == "CLAMPTOBLACKADDITIVE")
            return maskAvailable
        end
        assert(texture == "Interface\\WorldStateFrame\\Icons-Classes")
        return iconAvailable
    end
    function methods:SetColorTexture(...) self.fill = {...} end
    function methods:CreateTexture(_, layer)
        local texture = Widget("Texture", nil, self)
        texture.layer = layer
        return texture
    end
    env.CreateColor = function(...) return {...} end
    function methods:SetGradient(orientation, bottom, top)
        assert(orientation == "VERTICAL" and bottom[4] == 1 and top[4] == 1)
        self.gradient = {bottom, top}
    end
    function methods:SetTexCoord(...) self.coords = {...} end

    Load("Modules/TargetPortraitArt.lua")
    env.ForeverTooltipLibreDB.targetPortrait = {medallion = true, target = {enabled = false}, player = {enabled = false}}
    local nextWidget = #widgets + 1
    Load("Modules/TargetPortrait.lua")
    ns.InitializeTargetPortrait({})
    local module, driver = modules.targetPortrait, widgets[nextWidget]
    local toggle = frames.ArkannsQOLTargetPortraitEnabled
    assert(toggle.checked and module.ExportSettings().enabled and driver.events.UNIT_PORTRAIT_UPDATE == "target")
    local function Event(event, name) driver.scripts.OnEvent(driver, event, name) end
    local function Overlay()
        for index = #widgets, 1, -1 do
            local widget = widgets[index]
            if widget.parent == container and widget.kind == "Frame" then return widget end
        end
    end
    Event("PLAYER_TARGET_CHANGED")
    assert(not Overlay(), "Never create or anchor on a Blizzard frame in combat")
    combat, secretAnchor = false, true
    Event("PLAYER_REGEN_ENABLED")
    assert(not Overlay(), "Leave secret anchors alone")
    secretAnchor = false
    Event("PLAYER_ENTERING_WORLD")
    local frame = assert(Overlay())
    assert(frame.shown and not frame.mouse and frame.level == container.level + 1 and frame.points[1][2] == portrait)
    assert(frame.width == 28 and frame.height == 28 and frame.points[1][4] == 25 and frame.points[1][5] == 24,
        "Seat the medallion on the upper-right rim, clear of the central marker and lower level/PvP badges")
    assert(frame.icon.width == 20 and frame.icon.height == 20 and frame.icon.points[1][2] == frame)
    assert(frame.icon.texture == "Interface\\WorldStateFrame\\Icons-Classes" and frame.icon.coords[1] > .25)
    local discs = {}
    for _, widget in ipairs(widgets) do
        if widget.parent == frame and widget.kind == "Texture" then
            discs[#discs + 1] = widget
            assert(widget.width == widget.height and widget.mask.atlas == "CircleMask")
            assert(widget.mask.width == widget.width and widget.mask.height == widget.height)
            assert(widget.points[1][2] == frame and widget.mask.points[1][2] == frame)
        end
    end
    assert(#discs == 4 and discs[1].width == 28 and discs[2] == frame.rim and frame.rim.width == 26)
    assert(discs[1].layer == "BACKGROUND" and frame.rim.layer == "BORDER"
        and discs[3].layer == "ARTWORK" and frame.icon.layer == "OVERLAY")
    assert(discs[3].width == 23 and discs[3].fill[4] == 1 and discs[3].fill[1] < .1,
        "Keep an opaque dark well behind the glyph and a thin class-colored rim")
    assert(frame.rim.gradient[1][1] < frame.rim.gradient[2][1] and discs[3].gradient,
        "Use a shaded rim and recessed well to integrate the badge with the native frame")
    local firstColor = frame.rim.color[1]
    local widgetCount = #widgets
    combat, class = true, "DRUID"
    Event("PLAYER_TARGET_CHANGED")
    assert(frame.shown and frame.icon.coords[1] > .75 and frame.rim.color[1] > firstColor)
    assert(#widgets == widgetCount, "Changing class in combat only repaints existing regions")
    class = "secret"
    Event("PLAYER_TARGET_CHANGED")
    assert(not frame.shown)
    class, player = "MAGE", false
    Event("PLAYER_TARGET_CHANGED")
    assert(not frame.shown)
    player, replacement = true, true
    Event("CVAR_UPDATE", "ReplaceOtherPlayerPortraits")
    assert(not frame.shown, "Avoid duplicating the native class portrait")
    replacement = false
    Event("CVAR_UPDATE", "ReplaceOtherPlayerPortraits")
    assert(frame.shown)
    portrait:Hide()
    Event("UNIT_PORTRAIT_UPDATE", "target")
    assert(not frame.shown)
    portrait:Show()
    local readClass = env.UnitClassBase
    env.UnitClassBase = nil
    Event("PLAYER_TARGET_CHANGED")
    assert(not frame.shown)
    env.UnitClassBase = readClass

    combat = false
    Event("PLAYER_REGEN_ENABLED")
    ns.modules.targetPortrait = module
    assert(profiles.Save("With class trim"))
    toggle:SetChecked(false); Click("ArkannsQOLTargetPortraitEnabled")
    assert(not frame.shown and not module.IsEnabled() and not driver:IsEventRegistered("PLAYER_TARGET_CHANGED"))
    assert(profiles.Apply(assert(profiles.Preview("With class trim", {targetPortrait = true}))))
    assert(toggle.checked and frame.shown)
    assert(profiles.Undo() and not toggle.checked and not frame.shown)

    atlasAvailable = false
    env.ForeverTooltipLibreDB.targetPortrait = {medallion = true, target = {enabled = false}, player = {enabled = false}}
    Load("Modules/TargetPortrait.lua")
    ns.InitializeTargetPortrait({})
    local fallback = assert(Overlay())
    assert(fallback ~= frame and fallback.shown and fallback.icon.mask.texture == maskTexture
        and fallback.rim.mask.texture == maskTexture, "Use the native texture when CircleMask is unavailable")
    maskAvailable = false
    env.ForeverTooltipLibreDB.targetPortrait = {medallion = true, target = {enabled = false}, player = {enabled = false}}
    Load("Modules/TargetPortrait.lua")
    ns.InitializeTargetPortrait({})
    assert(not Overlay().shown, "Hide the medallion if its circular mask cannot load")
    atlasAvailable, maskAvailable, iconAvailable = true, true, false
    env.ForeverTooltipLibreDB.targetPortrait = {medallion = true, target = {enabled = false}, player = {enabled = false}}
    Load("Modules/TargetPortrait.lua")
    ns.InitializeTargetPortrait({})
    assert(not Overlay().shown, "Hide the medallion if the class icon cannot load")
end
print("PASS: target class medallion geometry, circular masks, protected anchors, class changes, native portrait setting, and profiles")

do
    local combat, targetClass, playerClass, targetPlayer = true, "MAGE", "PALADIN", true
    local secretAnchor, forbidden, atlasesAvailable = false, false, true
    local fallbackAvailable, classAvailable = true, true
    local targetContainer = env.TargetFrame.TargetFrameContainer
    local targetPortrait = targetContainer.Portrait
    env.PlayerFrame = Widget("Frame"); env.PlayerFrame:Show()
    local playerContainer = Widget("Frame", nil, env.PlayerFrame)
    local playerPortrait = Widget("Texture", nil, playerContainer); playerPortrait:Show()
    env.PlayerFrame.PlayerFrameContainer, playerContainer.PlayerPortrait = playerContainer, playerPortrait
    targetContainer:SetFrameLevel(4); playerContainer:SetFrameLevel(4)
    targetPortrait.IsAnchoringSecret = function() return secretAnchor end
    playerPortrait.IsAnchoringSecret = function() return secretAnchor end
    env.TargetFrame.IsForbidden = function() return forbidden end
    env.PlayerFrame.IsForbidden = function() return forbidden end
    env.InCombatLockdown = function() return combat end
    env.UnitIsPlayer = function(unit) return unit == "player" or targetPlayer end
    env.UnitClassBase = function(unit)
        if not classAvailable then return end
        return unit == "player" and playerClass or targetClass
    end
    env.UnitIsUnit = function() return false end
    env.C_CVar = {GetCVarBool = function() return false end}
    ui.OpenCategory = function(category) category.frame:Show() end
    env.C_ClassColor = {GetClassColor = function(token)
        if not ns.TargetPortraitArt.classes[token] then return end
        local slot = ns.TargetPortraitArt.classSlots[token]
        return {r = .2 + slot / 20, g = .7, b = .9 - slot / 20}
    end}
    local atlasInfo, fileTextures = {CircleMask = {width = 64, height = 64},
        ["UI-HUD-UnitFrame-Player-CombatIcon"] = {width = 16, height = 16}}, {}
    local function RegisterAsset(asset)
        atlasInfo[asset.atlas] = {width = asset.width, height = asset.height}
        fileTextures[asset.texture] = true
    end
    RegisterAsset(ns.TargetPortraitArt.ring); RegisterAsset(ns.TargetPortraitArt.glow)
    if ns.TargetPortraitArt.glowMask then RegisterAsset(ns.TargetPortraitArt.glowMask) end
    for _, art in pairs(ns.TargetPortraitArt.classes) do
        RegisterAsset(art.rune)
    end
    for _, art in pairs(ns.TargetPortraitArt.customFrames or {}) do fileTextures[art.texture] = true end
    env.C_Texture = {GetAtlasInfo = function(atlas)
        assert(atlasInfo[atlas], "An atlas used by the portrait must have a verified resource entry")
        if atlasesAvailable then return atlasInfo[atlas] end
    end}
    function methods:SetAtlas(atlas, useAtlasSize, filter, resetCoords, wrapH, wrapV)
        assert(self ~= targetPortrait and self ~= playerPortrait, "Never repaint the native portrait")
        assert(atlasesAvailable and atlasInfo[atlas], "Only set an available atlas")
        if self.kind == "MaskTexture" then
            assert(not useAtlasSize and filter == "LINEAR" and resetCoords)
            assert(wrapH == "CLAMPTOBLACKADDITIVE" and wrapV == "CLAMPTOBLACKADDITIVE")
        end
        self.atlas, self.texture = atlas, nil
    end
    function methods:SetTexture(texture, wrapH, wrapV)
        assert(self ~= targetPortrait and self ~= playerPortrait, "Never replace the native portrait texture")
        assert(fileTextures[texture] or texture == ns.TargetPortraitArt.paladinTest.texture
            or texture == ns.TargetPortraitArt.paladinCustom.texture
            or texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask"
            or texture == "Interface\\WorldStateFrame\\Icons-Classes"
            or texture == "Interface\\TargetingFrame\\UI-StatusBar"
            or texture == "Interface\\Icons\\INV_Misc_QuestionMark", "Only use verified native fallback textures")
        self.texture, self.atlas = texture, nil
        return fallbackAvailable
    end
    local function IsGameplay(widget)
        while widget do
            if widget == targetContainer or widget == playerContainer then return true end
            widget = widget.parent
        end
        return false
    end
    local geometryWrites = 0
    function methods:CreateTexture(_, layer, _, sublevel)
        assert(not combat or not IsGameplay(self), "Create native-container ornaments outside combat")
        local texture = Widget("Texture", nil, self)
        texture.layer, texture.sublevel = layer, sublevel or 0
        return texture
    end
    function methods:GetHeight()
        if self.kind == "ScrollFrame" then
            local top, bottom
            for _, point in ipairs(self.points) do
                if point[1] == "TOPLEFT" and point[2] == self.parent then top = point[5] end
                if point[1] == "BOTTOMRIGHT" and point[2] == self.parent then bottom = point[5] end
            end
            if top and bottom then return math.max(0, self.parent:GetHeight() + top - bottom) end
        end
        return self.height
    end
    function methods:SetParent(parent)
        assert(not combat or not IsGameplay(parent), "Never parent a decoration to Blizzard frames during combat")
        self.parent = parent
    end
    function methods:SetPoint(...)
        if self.kind == "Frame" and IsGameplay(self) then
            assert(not combat, "Never reanchor a gameplay decoration in combat")
            geometryWrites = geometryWrites + 1
        end
        self.points[#self.points + 1] = {...}
    end
    function methods:CreateMaskTexture() assert(not combat); return Widget("MaskTexture", nil, self) end
    function methods:CreateAnimationGroup()
        assert(not combat, "Create animation resources outside combat")
        return Widget("AnimationGroup", nil, self)
    end
    function methods:CreateAnimation(kind) return Widget(kind, nil, self) end
    function methods:SetLooping(value) self.looping = value end
    function methods:SetOrder(value) self.order = value end
    function methods:SetDuration(value) self.duration = value end
    function methods:SetFromAlpha(value) self.fromAlpha = value end
    function methods:SetToAlpha(value) self.toAlpha = value end
    function methods:SetSmoothing(value) self.smoothing = value end
    function methods:Play() self.playing = true end
    function methods:Stop() self.playing = false end
    function methods:IsPlaying() return self.playing == true end
    function methods:SetRotation(value) self.rotation = value end
    function methods:SetBlendMode(value) self.blendMode = value end
    function methods:SetValue(value)
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end
    local function Event(driver, event, unit) driver.scripts.OnEvent(driver, event, unit) end
    local function TextureFor(frame, atlas)
        for _, widget in ipairs(widgets) do
            if widget.atlas == atlas and (widget.parent == frame or (frame.ornaments and widget == frame.ornaments[1])) then return widget end
        end
    end
    local function AssertOrnaments(frame, token, count)
        assert(#frame.ornaments == 4)
        for index, ornament in ipairs(frame.ornaments) do
            assert(ornament.parent == frame.parent and ornament.layer == "BACKGROUND" and ornament.sublevel == 0,
                "Class relief shares the native container below its sublevel-one portrait")
            assert(ornament.shown == (index <= count), "Only the requested relief layers are visible")
            if index <= count then
                assert(ornament.atlas == ns.TargetPortraitArt.classes[token].rune.atlas)
                assert(ornament.width > 80 and ornament.width == ornament.height,
                    "Class artwork surrounds the portrait as one proportionate ornament")
            end
        end
    end
    local function AssertHiddenOrnaments(frame)
        for _, ornament in ipairs(frame.ornaments) do assert(not ornament.shown, "Hidden frames release sibling ornaments") end
    end
    local function Check(name, value)
        local control = assert(frames["ArkannsQOLTargetPortrait" .. name])
        control:SetChecked(value); control.scripts.OnClick(control)
    end
    local function Change(name, value)
        local control = assert(frames["ArkannsQOLTargetPortrait" .. name])
        assert(control.scripts.OnValueChanged, name .. " must update its saved setting")(control, value)
    end
    local function Choose(name, caption)
        Click("ArkannsQOLTargetPortrait" .. name)
        local callback = menu[caption]
        if not callback then
            for text, item in pairs(menu) do if text:find(caption, 1, true) then callback = item; break end end
        end
        assert(callback, "Missing portrait choice: " .. caption)()
    end
    env.ForeverTooltipLibreDB.targetPortrait = {enabled = true}
    local nextWidget = #widgets + 1
    Load("Modules/TargetPortrait.lua")
    ns.InitializeTargetPortrait({})
    local module, driver = modules.targetPortrait, widgets[nextWidget]
    ns.modules.targetPortrait = module
    local config = module.ExportSettings()
    assert(config.target.enabled and config.player.enabled and not config.medallion,
        "Old saved activation gains independent player and target decorations")
    assert(config.target.customFrame and config.player.customFrame,
        "Absent legacy style settings adopt full class frames without changing activation")
    config.target.customFrame, config.player.customFrame = false, false
    assert(module.ImportSettings(config), "Legacy ornament scenarios explicitly select the preserved old style")
    config = module.ExportSettings()
    assert(config.target ~= config.player and config.target.color ~= config.player.color,
        "Player and target settings own independent tables")
    local untouched = module.ExportSettings()
    config.target.color[1], config.target.size = 0, 140
    assert(module.ExportSettings().target.size == untouched.target.size
        and module.ExportSettings().target.color[1] == untouched.target.color[1], "Exports cannot mutate live settings")
    assert(not frames.ArkannsQOLClassPortraitTarget and not frames.ArkannsQOLClassPortraitPlayer,
        "Loading during combat defers creation of gameplay ornaments")
    combat = false
    Event(driver, "PLAYER_REGEN_ENABLED")
    local target = assert(frames.ArkannsQOLClassPortraitTarget)
    local player = assert(frames.ArkannsQOLClassPortraitPlayer)
    assert(target.shown and player.shown and not target.mouse and not player.mouse)
    assert(target.parent == targetContainer and player.parent == playerContainer)
    assert(target.points[1][2] == targetPortrait and player.points[1][2] == playerPortrait)
    assert(TextureFor(target, ns.TargetPortraitArt.ring.atlas), "The frame surrounds the native portrait with a ring")
    AssertOrnaments(target, "MAGE", 3)
    AssertOrnaments(player, "PALADIN", 3)
    local playerEmblem = player.ornaments[1]
    local widgetCount, geometryCount = #widgets, geometryWrites
    combat, targetClass = true, "DRUID"
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(target.shown and player.shown and TextureFor(target, ns.TargetPortraitArt.classes.DRUID.rune.atlas))
    assert(playerEmblem.atlas == ns.TargetPortraitArt.classes.PALADIN.rune.atlas,
        "Changing target class leaves the player's class artwork intact")
    assert(#widgets == widgetCount and geometryWrites == geometryCount,
        "Changing class in combat only repaints existing resources")
    targetClass = "secret"
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not target.shown and player.shown, "A secret target class hides only its own ornament")
    AssertHiddenOrnaments(target)
    targetClass, targetPlayer = "MAGE", false
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not target.shown and player.shown, "Creature targets never inherit the previous player's class")
    AssertHiddenOrnaments(target)
    targetPlayer, classAvailable = true, false
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not target.shown and not player.shown, "Unavailable class data hides stale artwork")
    classAvailable, combat = true, false
    Event(driver, "PLAYER_REGEN_ENABLED")
    assert(target.shown and player.shown)
    local readClass = env.UnitClassBase
    env.UnitClassBase = nil
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not target.shown and not player.shown, "An absent class API clears both ornaments")
    env.UnitClassBase = readClass
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(target.shown and player.shown)
    forbidden = true
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not target.shown and not player.shown)
    forbidden = false
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(target.shown and player.shown)
    secretAnchor = true
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not target.shown and not player.shown, "Secret native anchors hide both owned decorations")
    AssertHiddenOrnaments(target); AssertHiddenOrnaments(player)
    secretAnchor = false
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(target.shown and player.shown, "Public anchors restore their class relief")

    local setPoint, rejectAnchor = methods.SetPoint, true
    function methods:SetPoint(...)
        if self == target and rejectAnchor then error("Restricted portrait anchor") end
        return setPoint(self, ...)
    end
    local anchored = module.ExportSettings()
    local rejected = module.ExportSettings(); rejected.target.x = 7
    assert(module.ImportSettings(rejected))
    assert(not target.shown and #target.points == 0, "A rejected reanchor leaves its ornament hidden")
    combat = true
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not target.shown, "Combat refresh cannot revive an ornament whose anchor was rejected")
    combat, rejectAnchor = false, false
    Event(driver, "PLAYER_ENTERING_WORLD")
    assert(target.shown and target.points[1][4] == 7, "Entering the world retries a previously rejected anchor")
    methods.SetPoint = setPoint
    assert(module.ImportSettings(anchored))

    local portraitCalls = 0
    env.SetPortraitTexture = function(texture, unit, disableMasking)
        assert(texture ~= targetPortrait and texture ~= playerPortrait)
        assert(unit == "player" and disableMasking == true)
        texture.portraitUnit = unit
        portraitCalls = portraitCalls + 1
    end
    local panel = frames.ArkannsQOLTargetPortraitSettings
    panel:SetSize(576, 312); panel:Show(); panel.scripts.OnShow(panel)
    local placement = frames.ArkannsQOLTargetPortraitSize
    local body, scroll = placement.parent, placement.parent.parent
    assert(body:GetHeight() <= scroll:GetHeight(), "The default portrait style fits a compact page without scrolling")
    assert(panel.previewHost.parent == panel and frames.ArkannsQOLTargetPortraitPreviewClass.parent == panel,
        "The class preview stays outside the settings scroll")
    module.OpenSettings("Couleur personnalisée")
    assert(revealed == frames.ArkannsQOLTargetPortraitClassColor and not frames.ArkannsQOLTargetPortraitColor.shown,
        "Searching for a custom color reveals its controlling class-color setting while automatic color is active")
    Choose("Unit", "Joueur")
    module.OpenSettings("Afficher le médaillon de classe")
    assert(frames.ArkannsQOLTargetPortraitUnit:GetText() == "Cible" and frames.ArkannsQOLTargetPortraitMedallion.shown,
        "Searching for the target medallion selects its portrait and shows the matching Effects setting")
    Click("ArkannsQOLTargetPortraitStyle")
    Click("ArkannsQOLTargetPortraitAdvanced")
    assert(placement.shown and not frames.ArkannsQOLTargetPortraitBorderSize.shown)
    local gap = frames.ArkannsQOLTargetPortraitGap
    assert(placement.points[1][5] == gap.points[1][5] and placement.points[1][4] < gap.points[1][4],
        "Compact placement pairs related sliders instead of growing a long column")
    assert(body:GetHeight() <= scroll:GetHeight(), "All placement controls fit the compact page")
    scroll:SetVerticalScroll(80)
    Click("ArkannsQOLTargetPortraitStyle")
    assert(scroll:GetVerticalScroll() == 0 and not placement.shown and frames.ArkannsQOLTargetPortraitBorderSize.shown)
    Choose("Intensity", "Sobre")
    AssertOrnaments(target, "MAGE", 0)
    Choose("Intensity", "Spectaculaire")
    AssertOrnaments(target, "MAGE", 4)
    Choose("Intensity", "Ornée")
    AssertOrnaments(target, "MAGE", 3)
    panel:SetSize(740, 600); panel.scripts.OnSizeChanged(panel)
    assert(body:GetHeight() <= scroll:GetHeight(), "Style controls fit a comfortable page")
    Click("ArkannsQOLTargetPortraitAdvanced")
    Change("Size", 120)
    Change("BorderSize", 1)
    Change("Opacity", 65)
    Check("ClassColor", false)
    local changed = module.ExportSettings()
    assert(changed.target.size == 120 and changed.target.opacity == .65 and not changed.target.classColor)
    assert(target.alpha == .65 and target.rings[1].shown and not target.rings[2].shown,
        "Appearance controls change the actual decoration")
    assert(changed.player.size == untouched.player.size and changed.player.opacity == untouched.player.opacity,
        "Target appearance controls preserve the player's appearance")
    local picker
    env.ColorPickerFrame = {
        SetupColorPickerAndShow = function(_, options) picker = options end,
        GetColorRGB = function() return .12, .34, .56 end,
    }
    local originalColor = module.ExportSettings().target.color[1]
    Click("ArkannsQOLTargetPortraitColor")
    picker.swatchFunc()
    assert(module.ExportSettings().target.color[1] == .12)
    Choose("Unit", "Joueur")
    picker.cancelFunc()
    assert(module.ExportSettings().target.color[1] == originalColor,
        "Canceling a color edit restores its original portrait after changing the selected portrait")
    Choose("Unit", "Cible")
    Click("ArkannsQOLTargetPortraitColor")
    local stalePicker = picker
    local replacement = module.ExportSettings(); replacement.target.color = {.9, .1, .2}
    assert(module.ImportSettings(replacement))
    stalePicker.swatchFunc(); stalePicker.cancelFunc()
    assert(module.ExportSettings().target.color[1] == .9,
        "Callbacks from a replaced color configuration cannot overwrite an imported profile")
    Choose("Unit", "Joueur")
    Change("Size", 90)
    assert(module.ExportSettings().player.size == 90 and module.ExportSettings().target.size == 120)
    Check("Animated", true)
    assert(player.pulse.playing and not target.pulse.playing, "Animation follows each portrait's own preference")
    local beforePreview = module.ExportSettings()
    assert(module.Preview())
    Choose("PreviewClass", "Druide")
    local preview = assert(frames.ArkannsQOLClassPortraitPreview)
    assert(preview.shown and TextureFor(preview, ns.TargetPortraitArt.classes.DRUID.rune.atlas))
    assert(preview.face.parent == panel.previewHost and preview.face.sublevel == 1,
        "The preview face covers the relief through the same layer order as the native portrait")
    assert(portraitCalls > 0 and preview.face.portraitUnit == "player",
        "A public portrait API supplies the preview face while only the class relief changes")
    assert(preview.face.width == 60 and preview.faceMask.width == 60,
        "The player preview keeps portrait and circular mask at the same size")
    assert(module.ExportSettings().target.size == beforePreview.target.size
        and module.ExportSettings().player.size == beforePreview.player.size,
        "Choosing an example class never saves it as the real class or changes appearance")
    module.StopPreview()
    assert(not preview.shown and not preview.face.shown and frames.ArkannsQOLTargetPortraitPreview.shown,
        "Stopping the shared preview exposes the inline restart action immediately")
    Click("ArkannsQOLTargetPortraitPreview")
    assert(preview.shown and not frames.ArkannsQOLTargetPortraitPreview.shown,
        "The inline restart action restores the preview and then releases its button space")
    panel:Hide(); panel.scripts.OnHide(panel)
    assert(not preview.shown and not preview.pulse.playing, "Closing settings releases the preview and its animation")
    AssertHiddenOrnaments(preview)
    assert(not preview.face.shown)
    env.SetPortraitTexture = nil
    assert(module.Preview())
    assert(preview.face.texture == "Interface\\WorldStateFrame\\Icons-Classes",
        "A missing preview portrait API uses the verified class-icon sample")
    combat = true
    Event(driver, "PLAYER_REGEN_DISABLED")
    assert(not preview.shown, "Entering combat stops the shared preview")

    geometryCount = geometryWrites
    local pending = module.ExportSettings()
    pending.target.size, pending.player.size, pending.target.x = 135, 110, 13
    assert(module.ImportSettings(pending))
    assert(geometryWrites == geometryCount, "Saved geometry changes wait until combat ends")
    module.SetEnabled(false)
    assert(not target.shown and not player.shown)
    AssertHiddenOrnaments(target); AssertHiddenOrnaments(player)
    combat = false
    if driver:IsEventRegistered("PLAYER_REGEN_ENABLED") then Event(driver, "PLAYER_REGEN_ENABLED") end
    assert(not target.shown and not player.shown, "Disabling during a pending change cannot revive ornaments")
    module.SetEnabled(true)
    assert(target.shown and player.shown and module.ExportSettings().target.x == 13)
    assert(target.points[1][4] == 13, "Reactivation applies the latest requested geometry")
    assert(not module.ImportSettings({enabled = "yes"}) and module.IsEnabled(),
        "Invalid activation imports are rejected before changing live settings")

    assert(profiles.Save("Class portrait appearance"))
    pending = module.ExportSettings(); pending.target.size, pending.player.enabled = 85, false
    assert(module.ImportSettings(pending))
    assert(not player.shown)
    assert(profiles.Apply(assert(profiles.Preview("Class portrait appearance", {targetPortrait = true}))))
    assert(module.ExportSettings().target.size == 135 and player.shown)
    assert(profiles.Undo() and module.ExportSettings().target.size == 85 and not player.shown)
    local legacy = env.ForeverTooltipLibreDB.profiles["Class portrait appearance"]
    legacy.modules.targetPortrait = {enabled = false}
    legacy.moduleVersions.targetPortrait = nil
    local prior = module.ExportSettings()
    assert(profiles.Apply(assert(profiles.Preview("Class portrait appearance", {targetPortrait = true}))))
    assert(not module.IsEnabled() and module.ExportSettings().target.size == prior.target.size
        and module.ExportSettings().player.enabled == prior.player.enabled,
        "Applying an old activation-only profile preserves the new appearance preferences")
    assert(legacy.modules.targetPortrait.target == nil, "Legacy profile migration leaves saved profile data intact")
    assert(profiles.Undo() and module.IsEnabled())

    local baseline = module.ExportSettings()
    baseline.player.enabled = true
    assert(module.ImportSettings(baseline))
    for _, token in ipairs(ns.TargetPortraitArt.order) do
        targetClass = token
        Event(driver, "PLAYER_TARGET_CHANGED")
        assert(target.shown and TextureFor(target, ns.TargetPortraitArt.classes[token].rune.atlas),
            "Each supported class has its own verified native ornament: " .. token)
    end
    -- The temporary paladin test uses real native geometry and never changes its content or saved preferences.
    local playerMain = Widget("Frame", nil, env.PlayerFrame)
    local playerHealth = Widget("Frame", nil, playerMain); playerHealth:SetSize(124, 20)
    local playerManaArea = Widget("Frame", nil, playerMain)
    local playerMana = Widget("StatusBar", nil, playerManaArea); playerMana:SetSize(124, 10)
    env.PlayerFrame.PlayerFrameContent = {PlayerFrameContentMain = playerMain}
    playerMain.HealthBarsContainer, playerMain.ManaBarArea = playerHealth, playerManaArea
    playerManaArea.ManaBar = playerMana
    local targetMain = Widget("Frame", nil, env.TargetFrame)
    local targetHealth = Widget("Frame", nil, targetMain); targetHealth:SetSize(126, 20)
    local targetMana = Widget("StatusBar", nil, targetMain); targetMana:SetSize(134, 10)
    env.TargetFrame.TargetFrameContent = {TargetFrameContentMain = targetMain}
    targetMain.HealthBarsContainer, targetMain.ManaBar = targetHealth, targetMana
    playerPortrait:SetSize(60, 60); targetPortrait:SetSize(58, 58)
    playerPortrait.nativeOrigin, playerHealth.nativeOrigin, playerMana.nativeOrigin = {24, -79}, {85, -60}, {85, -71}
    targetPortrait.nativeOrigin, targetHealth.nativeOrigin, targetMana.nativeOrigin = {148, -77}, {22, -48}, {22, -59}
    local testCommand = assert(env.SlashCmdList.QOLTOOLKITPALADINTEST)
    local priorTest = module.ExportSettings()
    testCommand("")
    assert(player.testActive and player.shown and not player.rings[1].shown and not player.glow.shown)
    AssertHiddenOrnaments(player)
    for _, part in pairs(player.testParts) do
        assert(part.shown and part.parent == playerContainer and part.layer == "BACKGROUND")
        assert(part.sublevel == (part == player.testParts.ring and 0 or 3), "The native portrait covers its ring while rails sit above the native border")
        assert(part.texture == ns.TargetPortraitArt.paladinTest.texture)
    end
    assert(player.testParts.topStart.points[1][2] == playerHealth
        and player.testParts.bottomStart.points[1][2] == playerMana, "Test rails anchor to the real native bars")
    assert(player.testParts.topFill.points[2][2] == player.testParts.capTop
        and player.testParts.bottomFill.points[2][2] == player.testParts.capBottom,
        "Plain rail spans terminate at the cap's painted contacts")
    assert(player.testParts.capTop.points[1][2] == playerHealth and player.testParts.capBottom.points[1][2] == playerHealth,
        "Both cap corners share the same horizontal native edge")
    assert(player.testParts.ring.width == 444 * 64 / 340 and player.testParts.ring.height == 499 * 64 / 340,
        "The ring uses its source aperture rather than treating its off-center artwork as a centered square")
    assert(playerHealth.width == 124 and playerMana.width == 124 and playerPortrait.width == 60,
        "The test never resizes native portrait or status bars")
    local playerTopWidth = player.testParts.topStart.width
    playerHealth:SetWidth(180)
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(player.testParts.topStart.width == playerTopWidth and player.testParts.capTop.points[1][2] == playerHealth,
        "Decorative ends keep their proportions while plain spans follow native geometry")
    local anchorFactors = {TOPLEFT = {0, 1}, TOPRIGHT = {1, 1}, BOTTOMLEFT = {0, 0}, BOTTOMRIGHT = {1, 0}, CENTER = {.5, .5}}
    local function Rect(region)
        if region.nativeOrigin then return {region.nativeOrigin[1], region.nativeOrigin[2], region.width, region.height} end
        local constraints = {{}, {}}
        for _, point in ipairs(region.points) do
            local own, relative, parent = anchorFactors[point[1]], anchorFactors[point[3]], Rect(point[2])
            for axis = 1, 2 do
                constraints[axis][#constraints[axis] + 1] = {own[axis], parent[axis] + relative[axis] * parent[axis + 2] + (point[axis + 3] or 0)}
            end
        end
        local result = {}
        for axis = 1, 2 do
            local first, size = assert(constraints[axis][1]), axis == 1 and region.width or region.height
            for _, item in ipairs(constraints[axis]) do
                if item[1] ~= first[1] then size = (item[2] - first[2]) / (item[1] - first[1]); break end
            end
            result[axis], result[axis + 2] = first[2] - first[1] * size, size
            assert(size > 0, "Every paladin piece has positive geometry")
            for _, item in ipairs(constraints[axis]) do
                assert(math.abs(result[axis] + item[1] * size - item[2]) < 1e-7, "Paladin anchors agree on the same horizontal/vertical line")
            end
        end
        return result
    end
    local function Project(region, x, y)
        local rect, uv = Rect(region), region.coords
        return rect[1] + (x / 1024 - uv[1]) / (uv[2] - uv[1]) * rect[3],
            rect[2] + rect[4] - (y / 1024 - uv[3]) / (uv[4] - uv[3]) * rect[4]
    end
    local function AssertContacts(frame, portrait, health, direction)
        local parts = frame.testParts
        local x, y = Project(parts.ring, 255, 285)
        assert(math.abs(x - (portrait.nativeOrigin[1] + portrait.width / 2)) < 1e-7
            and math.abs(y - (portrait.nativeOrigin[2] + portrait.height / 2)) < 1e-7,
            "The painted aperture, including mirrored artwork, centers on the real portrait")
        for _, contact in ipairs({{"topStart", "topFill", 570.5, "capTop", 771.5}, {"bottomStart", "bottomFill", 686.5, "capBottom", 970}}) do
            local start, fill, cap = parts[contact[1]], parts[contact[2]], parts[contact[4]]
            local _, startY = Project(start, 220, contact[3])
            local fillX, fillY = Project(fill, 983.5, contact[3])
            local capX, capY = Project(cap, 771.5, contact[5])
            assert(math.abs(startY - fillY) < 1e-7 and math.abs(fillY - capY) < 1e-7,
                "The actual opaque strokes meet at exactly the same height")
            assert((fillX - capX) * direction >= 0 and (fillX - capX) * direction < 1,
                "Painted horizontal rails overlap the cap instead of ending in its transparent padding")
        end
        local cap = Rect(parts.capTop)
        local outer = direction == 1 and cap[1] + cap[3] or cap[1]
        local native = direction == 1 and health.nativeOrigin[1] + health.width or health.nativeOrigin[1]
        assert(math.abs(outer - native - direction * 6) < 1e-7, "The cap's outer edge follows the native bars without a detached extension")
        assert(Rect(parts.capFill)[4] > 0 and parts.capGem.width == parts.capTop.width,
            "Only the plain cap stem stretches; the gem retains its original aspect ratio")
    end
    AssertContacts(player, playerPortrait, playerHealth, 1)
    local testWidgets = #widgets
    combat = true
    testCommand("off")
    assert(player.testActive and #widgets == testWidgets, "The test command refuses mutations during combat")
    targetPlayer = false
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(player.testParts.ring.shown, "A creature target does not change the player test")
    targetPlayer, combat = true, false
    testCommand("target")
    assert(target.testActive and not player.testActive)
    assert(not player.testParts.ring.shown and target.testParts.ring.shown)
    assert(target.testParts.ring.coords[1] > target.testParts.ring.coords[2]
        and target.testParts.ring.points[1][1] == "TOPRIGHT", "Target art mirrors around its right-hand portrait")
    assert(target.testParts.topStart.points[1][1] == "BOTTOMRIGHT"
        and target.testParts.capTop.points[1][1] == "TOPLEFT", "The target test extends to the left of its portrait")
    AssertContacts(target, targetPortrait, targetHealth, -1)
    fallbackAvailable = false
    testCommand("player")
    assert(not player.testActive and not target.testParts.ring.shown and not player.testParts.ring.shown,
        "A missing bundled test texture clears old test pieces")
    fallbackAvailable = true
    testCommand("")
    assert(player.testActive)
    playerHealth.IsAnchoringSecret = function() return true end
    testCommand("")
    assert(not player.testActive and not player.testParts.ring.shown, "Secret bar anchors leave only the native frame")
    playerHealth.IsAnchoringSecret = nil
    testCommand("")
    assert(player.testActive)
    playerHealth.IsAnchoringSecret = function() return true end
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(not player.shown and not player.testParts.ring.shown, "A bar becoming secret also hides an already active test")
    playerHealth.IsAnchoringSecret = nil
    Event(driver, "PLAYER_TARGET_CHANGED")
    assert(player.shown and player.testParts.ring.shown, "Public bar anchors restore the existing test without reallocating it")
    playerHealth.GetTop = function() return "secret" end
    testCommand("")
    assert(not player.testActive and not player.testParts.ring.shown, "A secret bar position cannot enter cap span arithmetic")
    playerHealth.GetTop = false
    testCommand("")
    assert(not player.testActive and not player.testParts.ring.shown, "An unavailable geometry API leaves the test hidden")
    playerHealth.GetTop = nil
    testCommand("")
    assert(player.testActive, "Public bar geometry restores the calibrated test")
    local setTestPoint = methods.SetPoint
    function methods:SetPoint(...)
        if self == player.testParts.topStart then error("Restricted test bar anchor") end
        return setTestPoint(self, ...)
    end
    testCommand("")
    assert(not player.testActive and not player.testParts.ring.shown and player.shown,
        "A rejected test anchor safely falls back to the regular decoration")
    methods.SetPoint = setTestPoint
    testCommand("")
    assert(player.testActive)
    module.SetEnabled(false)
    assert(not player.testParts.ring.shown, "Disabling the owning module releases test regions too")
    module.SetEnabled(true)
    assert(not player.testActive and not player.testParts.ring.shown, "Reactivation does not retain a session test")
    testCommand("")
    testCommand("off")
    assert(not player.testActive and player.rings[1].shown and not player.testParts.ring.shown,
        "Stopping the prototype restores the regular class decoration")
    assert(module.ExportSettings().player.size == priorTest.player.size
        and module.ExportSettings().player.opacity == priorTest.player.opacity
        and module.ExportSettings().target.size == priorTest.target.size,
        "The temporary test does not alter saved appearance or profile exports")
    print("PASS: temporary paladin overlay, native bar anchors, mirrored target, combat refusal, cleanup, and restoration")
    -- Second test: custom visuals with native secure clicks and update pipelines retained.
    env.PlayerFrame.nativeOrigin = {0, -100}; env.PlayerFrame:SetSize(232, 100)
    env.PlayerFrame.unit = "player"
    local playerContent = Widget("Frame", nil, env.PlayerFrame)
    playerContent.PlayerFrameContentMain = playerMain
    env.PlayerFrame.PlayerFrameContent = playerContent
    playerContent:SetAlpha(.8); playerContainer:SetAlpha(.9)
    local nativeHealth = Widget("StatusBar", nil, playerHealth)
    playerHealth.HealthBar = nativeHealth
    nativeHealth:SetSize(124, 20); nativeHealth.nativeOrigin = {85, -60}
    function methods:GetAlpha() return self.alpha end
    function methods:GetMinMaxValues() return self.minimum, self.maximum end
    function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
    function methods:GetValue() return self.value end
    function methods:SetValue(value) self.value = value end
    function methods:SetStatusBarTexture(texture)
        assert(texture == "Interface\\TargetingFrame\\UI-StatusBar")
        self.barTexture = texture
        self.barColor = {1, 1, 1, 1}
        return fallbackAvailable
    end
    function methods:SetStatusBarColor(...) self.barColor = {...} end
    function methods:GetStatusBarTexture()
        assert(self.fillTexture or self.value == nil, "Forecast anchors are installed before the first health value")
        self.fillTexture = self.fillTexture or Widget("Texture", nil, self)
        return self.fillTexture
    end
    function methods:SetClipsChildren(value) self.clipsChildren = value end
    function methods:SetFont(...) self.font = {...}; return true end
    function methods:SetTextColor(...) self.textColor = {...} end
    function methods:SetShadowColor(...) self.shadowColor = {...} end
    function methods:SetShadowOffset(...) self.shadowOffset = {...} end
    function methods:SetJustifyH(value) self.justifyH = value end
    function methods:SetJustifyV(value) self.justifyV = value end
    function methods:SetFormattedText(format, ...) self.text = string.format(format, ...) end
    function methods:SetAllPoints(relative)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0)
    end
    function methods:GetTop()
        local rect = Rect(self)
        return rect[2] + rect[4]
    end
    function methods:GetBottom() return Rect(self)[2] end
    function methods:GetRect() return unpack(Rect(self)) end
    local function NativeText(parent, text, shown)
        local region = Widget("FontString", nil, parent)
        region:SetText(text); region:SetShown(shown ~= false)
        return region
    end
    env.PlayerName = NativeText(playerMain, "Léan Léandoras")
    env.PlayerLevelText = NativeText(playerMain, "23")
    playerHealth.HealthBarText = NativeText(playerHealth, "", false)
    playerHealth.LeftText, playerHealth.RightText = NativeText(playerHealth, "100%"), NativeText(playerHealth, "769")
    playerMana.ManaBarText = NativeText(playerMana, "", false)
    playerMana.LeftText, playerMana.RightText = NativeText(playerMana, "100%"), NativeText(playerMana, "1014")
    nativeHealth:SetMinMaxValues(0, 769); nativeHealth:SetValue(769)
    playerMana:SetMinMaxValues(0, 1089); playerMana:SetValue(1014)
    local hookCount = 0
    env.hooksecurefunc = function(object, method, callback)
        if type(object) == "string" then
            local name, original = object, assert(env[object])
            env[name] = function(...) original(...); method(...) end
            hookCount = hookCount + 1
            return
        end
        local before = assert(object[method], "Missing native method: " .. method)
        object[method] = function(self, ...)
            before(self, ...)
            callback(self, ...)
        end
        hookCount = hookCount + 1
    end
    env.SetPortraitTexture = function(texture, unit, disableMasking)
        assert(texture ~= playerPortrait and texture ~= targetPortrait
            and (unit == "player" or unit == "target") and disableMasking)
        texture.portraitUnit = unit
    end
    local contextual = Widget("Frame", nil, playerContent)
    contextual.AttackIcon = Widget("Texture", nil, contextual); contextual.AttackIcon:Show()
    playerContent.PlayerFrameContentContextual = contextual
    local incoming = Widget("Frame", nil, nativeHealth); incoming:Show()
    incoming.Fill = Widget("Texture", nil, incoming)
    incoming.Fill.GetVertexColor = function() return .15, .9, .7, .65 end
    incoming.FillMask = Widget("MaskTexture", nil, incoming)
    incoming.FillMask.nativeOrigin = {160, -60}; incoming.FillMask:SetSize(18, 20)
    nativeHealth.MyHealPredictionBar = incoming
    -- Reproduce the live contract: mask geometry can be secret even when the
    -- native calculator may still forward its values to display-only widgets.
    incoming.FillMask.GetRect = function() return "secret", 0, 18, 20 end
    local forecastAmount, forecastMaximum, forecastRefused = 100, 769, false
    local targetForecastAmount, targetCombat = 75, true
    env.UnitAffectingCombat = function(unit) return unit == "target" and targetCombat end
    env.Enum.UnitMaximumHealthMode = {Default = 0}
    env.Enum.UnitHealAbsorbMode = {ReducedByIncomingHeals = 0}
    env.Enum.UnitIncomingHealClampMode = {MissingHealth = 0}
    env.CreateUnitHealPredictionCalculator = function()
        return {SetMaximumHealthMode = noop, SetHealAbsorbMode = noop,
            SetIncomingHealClampMode = noop, SetIncomingHealOverflowPercent = noop,
            GetMaximumHealth = function(self) return self.unit == "target" and 1000 or forecastMaximum end,
            GetIncomingHeals = function(self) return self.unit == "target" and targetForecastAmount or forecastAmount, 40, 60, false end}
    end
    env.UnitGetDetailedHealPrediction = function(unit, healer, calculator)
        assert((unit == "player" or unit == "target") and healer == "player")
        calculator.unit = unit
        if forecastRefused then error("Refused prediction") end
    end
    env.PlayerFrame_UpdateStatus, env.UnitFrameHealPredictionBars_Update = function() end, function() end
    Load("Modules/PaladinFrameColors.lua")
    Load("Modules/PaladinFrameIndicators.lua")
    local colorUpdates, colorUnits, applyColors = 0, {}, ns.PaladinFrameColors.Apply
    ns.PaladinFrameColors.Apply = function(health, power, unit)
        colorUpdates = colorUpdates + 1
        colorUnits[unit or "player"] = (colorUnits[unit or "player"] or 0) + 1
        return applyColors(health, power, unit)
    end
    Load("Modules/PaladinCustomTest.lua")
    local custom = ns.PaladinCustomTest
    combat = true
    local preCustomWidgets = #widgets
    assert(not custom.Start() and #widgets == preCustomWidgets and playerContainer.alpha == .9,
        "The full custom test cannot create frames or hide native art during combat")
    combat = false
    fallbackAvailable = false
    assert(not custom.Start() and playerContainer.alpha == .9 and playerContent.alpha == .8,
        "Missing custom texture resources preserve every native visual")
    fallbackAvailable = true
    assert(custom.Start(), "The full custom test starts from public native frame references")
    local customFrame = assert(frames.ArkannsQOLPaladinCustomTest)
    assert(customFrame.shown and customFrame.parent == env.PlayerFrame and not customFrame.mouse,
        "The passive custom visuals inherit native frame movement, scale and visibility without taking clicks")
    local customArt, customScale = ns.TargetPortraitArt.paladinCustom, 232 / 1024
    local front = assert(customFrame.front)
    assert(front.parent == customFrame and not front.mouse
        and front:GetFrameLevel() == customFrame:GetFrameLevel() + 3
        and customFrame.health:GetFrameLevel() == customFrame:GetFrameLevel() + 1
        and customFrame.power:GetFrameLevel() == customFrame:GetFrameLevel() + 1,
        "The passive front frame keeps the contour and text above both status bars")
    local frameRect, frontRect = Rect(customFrame), Rect(front)
    for index = 1, 4 do
        assert(math.abs(frameRect[index] - frontRect[index]) < 1e-7,
            "The front frame covers the complete custom frame without shifting its artwork")
    end
    assert(customFrame.skin.texture == customArt.texture and customFrame.skin.layer == "ARTWORK"
        and customFrame.skin.parent == front and customFrame.skin.width == 232 and customFrame.skin.height == 116,
        "The full custom frame uses one proportionally scaled skin")
    assert(customFrame.skin.points[1][1] == "TOPLEFT" and customFrame.skin.points[1][2] == customFrame
        and customFrame.skin.points[1][3] == "TOPLEFT", "The custom skin starts at its visual frame origin")
    local skinCount, maskCount = 0, 0
    for _, widget in ipairs(widgets) do
        local parent = widget.parent
        while parent and parent ~= customFrame do parent = parent.parent end
        if parent == customFrame and widget.kind == "MaskTexture" then maskCount = maskCount + 1 end
        if parent == customFrame and widget.kind == "Texture" then
            if widget.texture == customArt.texture then skinCount = skinCount + 1 end
            assert(widget.texture ~= ns.TargetPortraitArt.paladinTest.texture,
                "The full custom frame does not reuse sliced overlay artwork")
        end
    end
    assert(skinCount == 1 and not customFrame.decoration,
        "The full custom frame has one skin and no overlay decoration frame")
    assert(maskCount == 1 and customFrame.portrait.mask == customFrame.portraitMask,
        "The front contour covers rectangular bar edges without adding masks beyond the portrait")
    local body = customFrame.body
    assert(body.parent == customFrame and body.layer == "BACKGROUND" and body.sublevel == -1
        and body.points[1][1] == "TOPLEFT" and body.points[1][2] == customFrame
        and body.points[1][4] == 330 * customScale and body.points[1][5] == -154 * customScale
        and body.width == 618 * customScale and body.height == 162 * customScale
        and body.fill[1] < .06 and body.fill[2] < .06 and body.fill[3] < .06 and body.fill[4] == 1,
        "An opaque dark background fills the transparent central panel behind both bars")
    for _, key in ipairs({"health", "power"}) do
        local bar, rect = customFrame[key], customArt[key]
        local point = bar.points[1]
        assert(point[1] == "TOPLEFT" and point[2] == customFrame and point[3] == "TOPLEFT"
            and point[4] == rect[1] * customScale and point[5] == -rect[2] * customScale
            and bar.width == rect[3] * customScale and bar.height == rect[4] * customScale,
            "The real status bar follows its calibrated skin rectangle: " .. key)
        assert(rect[1] == 350 and rect[3] == 596 and rect[4] == 72 and rect[1] + rect[3] == 946,
            "Both bars reach the inner right contour at the same width and height")
    end
    assert(customArt.health[2] == 158 and customArt.power[2] == 238
        and customFrame.health.height == customFrame.power.height,
        "Equal-height bars occupy the two calibrated rows beneath the skin")
    local levelText, levelPoint = customFrame.text.level, customFrame.text.level.points[1]
    assert(levelPoint[1] == "CENTER" and levelPoint[2] == front and levelPoint[3] == "TOPLEFT"
        and levelPoint[4] == customArt.level[1] * customScale and levelPoint[5] == -customArt.level[2] * customScale
        and levelText.width == customArt.level[3] * customScale,
        "The level is centered on its opaque plaque below the portrait")
    assert(levelText.font[2] == 14 and levelText.font[3] == "OUTLINE"
        and levelText.textColor[1] >= .8 and levelText.textColor[2] >= .8 and levelText.textColor[3] >= .8
        and levelText.textColor[4] == 1 and levelText.shadowColor[1] == 0
        and levelText.shadowColor[2] == 0 and levelText.shadowColor[3] == 0 and levelText.shadowColor[4] == 1,
        "The level stays readable with clear outlined text")
    assert(customArt.level[2] > customArt.portrait[2] + customArt.portrait[3] / 2,
        "The level text centers below the portrait face")
    for _, entry in ipairs({{"name", 626.5, 100.5}, {"level", 212.5, 388.5}}) do
        local text = customFrame.text[entry[1]]
        local rect = Rect(text)
        assert(text.parent == front and text.justifyH == "CENTER" and text.justifyV == "MIDDLE"
            and math.abs(rect[1] + rect[3] / 2 - (frameRect[1] + entry[2] * customScale)) < 1e-7
            and math.abs(rect[2] + rect[4] / 2 - (frameRect[2] + frameRect[4] - entry[3] * customScale)) < 1e-7,
            "The text is centered horizontally and vertically on its opaque front plaque: " .. entry[1])
    end
    local function AssertCustomBarColors()
        local health, power = customFrame.health.barColor, customFrame.power.barColor
        assert(health[1] == .12 and health[2] == .68 and health[3] == .24 and health[4] == 1
            and power[1] == .12 and power[2] == .32 and power[3] == .85 and power[4] == 1,
            "The full custom test reapplies green health and blue mana after loading fill textures")
    end
    AssertCustomBarColors()
    assert(customFrame.text.name.points[1][5] == -customArt.name[2] * customScale
        and customArt.name[2] + customArt.name[4] < customArt.health[2],
        "The real name widget occupies the upper plaque rather than the health rows")
    local forecast = assert(customFrame.indicators.forecast)
    assert(customFrame.indicators.combat.shown and forecast.shown and forecast.value == 100,
        "Starting the full prototype displays incoming heals despite secret native mask geometry")
    assert(customFrame.indicators.combat.parent == front
        and forecast:GetFrameLevel() > customFrame.health:GetFrameLevel()
        and forecast:GetFrameLevel() < front:GetFrameLevel(),
        "The forecast covers the fill while the contour and text stay above it")
    for _, key in ipairs({"health", "power"}) do
        for _, suffix in ipairs({"Left", "Center", "Right"}) do
            local text = customFrame.text[key .. suffix]
            assert(text.parent == front and text.points[1][2] == customFrame[key],
                "Stat text stays anchored to its bar above the prediction")
        end
    end
    contextual.AttackIcon:Hide(); env.PlayerFrame_UpdateStatus()
    assert(not customFrame.indicators.combat.shown)
    forecastAmount = 0; env.UnitFrameHealPredictionBars_Update(env.PlayerFrame)
    assert(forecast.value == 0, "Cancelled heals clear through the real post-hook")
    forecastAmount = 100; env.UnitFrameHealPredictionBars_Update(env.PlayerFrame)
    assert(forecast.value == 100 and forecast.shown)
    assert(playerContainer.alpha == 0 and playerContent.alpha == 0 and env.PlayerFrame.shown,
        "Only the old visual containers are faded; the secure player button stays visible and usable")
    assert(customFrame.health.value == 769 and customFrame.power.value == 1014
        and customFrame.health.maximum == 769 and customFrame.power.maximum == 1089)
    assert(customFrame.text.name.text == "Léan Léandoras" and customFrame.text.level.text == "23")
    assert(customFrame.text.healthLeft.text == "100%" and customFrame.text.healthRight.text == "769"
        and not customFrame.text.healthCenter.shown, "Native text formats and visibility are mirrored without duplication")
    assert(customFrame.portrait.portraitUnit == "player" and customFrame.portrait ~= playerPortrait)
    local beforeColors = colorUpdates
    nativeHealth:SetValue(500); nativeHealth:SetMinMaxValues(0, 1000)
    assert(colorUpdates == beforeColors + 2, "Native reserve and maximum changes refresh gradient colors")
    assert(customFrame.health.value == 500 and customFrame.health.maximum == 1000,
        "Custom bars follow the native update pipeline instead of starting a second polling loop")
    local opaque = setmetatable({}, {__tostring = function() error("Do not stringify secret data") end,
        __lt = function() error("Do not compare secret data") end, __add = function() error("Do not calculate secret data") end})
    nativeHealth:SetValue(opaque)
    nativeHealth:SetMinMaxValues(0, opaque)
    playerHealth.RightText:SetText(opaque)
    assert(customFrame.health.value == opaque and customFrame.health.maximum == opaque
        and customFrame.text.healthRight.text == opaque, "Opaque native data passes directly to permitted display widgets")
    playerHealth.LeftText:Hide()
    assert(not customFrame.text.healthLeft.shown)
    playerHealth.LeftText:SetShown(true)
    playerHealth.RightText:SetFormattedText("%d / %d", 500, 1000)
    assert(customFrame.text.healthLeft.shown and customFrame.text.healthRight.text == "500 / 1000")
    local customDriver = assert(frames.ArkannsQOLClassFrameEvents)
    for _, event in ipairs({"UNIT_HEAL_PREDICTION", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED"}) do
        assert(customDriver.events[event] == "player", "Prediction updates subscribe to the player event: " .. event)
    end
    combat = true
    forecastAmount, forecastMaximum = opaque, opaque
    Event(customDriver, "UNIT_HEAL_PREDICTION", "player")
    assert(forecast.shown and forecast.value == opaque and forecast.maximum == opaque,
        "The real heal event forwards opaque calculator results in combat without reading native mask geometry")
    forecastRefused = true
    Event(customDriver, "UNIT_HEALTH", "player")
    assert(not forecast.shown, "A refused calculator update clears the preceding prediction")
    forecastRefused, forecastAmount, forecastMaximum = false, 125, 1000
    Event(customDriver, "UNIT_MAXHEALTH", "player")
    assert(forecast.shown and forecast.value == 125 and forecast.maximum == 1000,
        "The next valid event restores the existing forecast")
    forecastAmount = 0
    Event(customDriver, "UNIT_HEAL_PREDICTION", "player")
    assert(forecast.value == 0, "Heal completion or cancellation clears the forecast without testing its amount")
    combat = false
    combat = true
    assert(not custom.Stop() and customFrame.shown, "Restoration requested in combat waits for the safe transition")
    combat = false
    Event(customDriver, "PLAYER_REGEN_ENABLED")
    assert(not customFrame.shown and playerContainer.alpha == .9 and playerContent.alpha == .8,
        "Stopping the test restores both native visual containers to their original opacity")
    local inactiveValue = customFrame.health.value
    local inactiveColors = colorUpdates
    nativeHealth:SetValue(700)
    assert(customFrame.health.value == inactiveValue, "Permanent hooks become inert after stopping the test")
    assert(colorUpdates == inactiveColors and not customFrame.indicators.combat.shown
        and not customFrame.indicators.predictions.MyHealPredictionBar.shown and not forecast.shown,
        "Stopped tests leave color and indicator hooks inert")
    local priorHooks, priorWidgets = hookCount, #widgets
    assert(custom.Start() and hookCount == priorHooks and #widgets == priorWidgets,
        "Repeated custom tests reuse widgets and never stack native hooks")
    AssertCustomBarColors()
    env.SlashCmdList.QOLTOOLKITPALADINTEST("")
    assert(not customFrame.shown and player.testActive and playerContainer.alpha == .9,
        "The first test restores native visuals before applying its overlay")
    assert(custom.Start() and not player.testActive, "The second test stops the first overlay without changing profiles")
    local disablePlayer = module.ExportSettings(); disablePlayer.player.enabled = false
    assert(module.ImportSettings(disablePlayer) and not customFrame.shown and playerContainer.alpha == .9,
        "Disabling the player portrait through its real settings also restores the full native frame")
    disablePlayer.player.enabled = true
    assert(module.ImportSettings(disablePlayer) and custom.Start())
    playerContent:SetAlpha(.45)
    assert(custom.Stop() and playerContent.alpha == .45, "Restoration preserves an opacity changed by another owner")
    assert(custom.Start())
    module.SetEnabled(false)
    assert(not customFrame.shown and playerContainer.alpha == .9, "The owner module's switch also stops the second test")
    module.SetEnabled(true)
    local getter = nativeHealth.GetValue
    nativeHealth.GetValue = function() error("Refused native value") end
    assert(not custom.Start() and playerContainer.alpha == .9 and not customFrame.shown,
        "Refused native data never leaves the player without its original frame")
    nativeHealth.GetValue = getter
    assert(custom.Start())
    local textGetter = playerHealth.RightText.GetText
    playerHealth.RightText.GetText = function() error("Refused native text") end
    playerHealth.RightText:SetText("500")
    assert(not customFrame.shown and playerContainer.alpha == .9, "A native text read refused during an update restores Blizzard")
    playerHealth.RightText.GetText = textGetter
    assert(custom.Start())
    Event(customDriver, "UNIT_ENTERED_VEHICLE", "player")
    assert(not customFrame.shown and playerContainer.alpha == .9, "Vehicle transitions restore the native interface")
    env.PlayerFrame.unit = "vehicle"
    assert(not custom.Start() and playerContainer.alpha == .9, "The prototype cannot replace a vehicle unit frame")
    env.PlayerFrame.unit = "player"
    print("PASS: full custom paladin visuals, native values/text, opaque display data, combat deferral, hooks, mode switches, and native restoration")
    -- The same passive renderer supports real player and target sources at the same time.
    env.TargetFrame.unit = "target"
    env.TargetFrame.nativeOrigin = {300, -100}; env.TargetFrame:SetSize(232, 100)
    local targetContent = Widget("Frame", nil, env.TargetFrame)
    targetContent.TargetFrameContentMain = targetMain
    env.TargetFrame.TargetFrameContent = targetContent
    targetMain:SetParent(targetContent)
    targetContainer:SetAlpha(.85); targetContent:SetAlpha(.65)
    local targetContextual = Widget("Frame", nil, targetContent)
    local nativeAuras = Widget("Frame", nil, targetContextual)
    targetContent.TargetFrameContentContextual, targetContextual.Auras = targetContextual, nativeAuras
    targetContextual:Show(); nativeAuras:Show()
    nativeAuras:SetPoint("TOPLEFT", env.TargetFrame, "BOTTOMLEFT", 5, 9)
    local aurasOnTop, auraProtected = false, false
    function nativeAuras:IsFlowLayoutMirroredVertically() return aurasOnTop end
    function nativeAuras:CanChangeProtectedState() return not combat or not auraProtected end
    function nativeAuras:AdjustPointsOffset(x, y)
        assert(self:CanChangeProtectedState(), "Do not move protected auras in combat")
        for _, point in ipairs(self.points) do point[4], point[5] = point[4] + x, point[5] + y end
    end
    function env.TargetFrame:GetAuraContainer() return nativeAuras end
    function env.TargetFrame:AnchorAuraContainer()
        nativeAuras:ClearAllPoints()
        nativeAuras:SetPoint(aurasOnTop and "BOTTOMLEFT" or "TOPLEFT", self,
            aurasOnTop and "TOPLEFT" or "BOTTOMLEFT", 5, aurasOnTop and -6 or 9)
    end
    local buffRow, debuffRow = Widget("Frame", nil, nativeAuras), Widget("Frame", nil, nativeAuras)
    buffRow:SetPoint("TOPLEFT", nativeAuras, "TOPLEFT", 0, 0)
    debuffRow:SetPoint("TOPLEFT", nativeAuras, "TOPLEFT", 0, -24)
    nativeAuras.scripts.OnEnter, nativeAuras.scripts.OnLeave = function() return "native tooltip" end, noop
    function nativeAuras:GetEffectiveAlpha()
        local alpha, parent = self.alpha, self.parent
        while parent do alpha, parent = alpha * parent.alpha, parent.parent end
        return alpha
    end
    local auraAlpha, auraPoint, auraEnter = nativeAuras:GetEffectiveAlpha(), nativeAuras.points[1], nativeAuras.scripts.OnEnter
    targetContent:SetAlpha(0)
    assert(nativeAuras:GetEffectiveAlpha() == 0, "Hiding all target content reproduces the missing native aura display")
    targetContent:SetAlpha(.65)
    local targetNativeHealth = Widget("StatusBar", nil, targetHealth)
    targetHealth.HealthBar = targetNativeHealth
    targetNativeHealth:SetMinMaxValues(0, 1000); targetNativeHealth:SetValue(600)
    targetMana:SetMinMaxValues(0, 800); targetMana:SetValue(400)
    targetMain.Name, targetMain.LevelText = NativeText(targetMain, "Cible mage"), NativeText(targetMain, "24")
    targetHealth.HealthBarText = NativeText(targetHealth, "", false)
    targetHealth.LeftText, targetHealth.RightText = NativeText(targetHealth, "60%"), NativeText(targetHealth, "600")
    targetMana.ManaBarText = NativeText(targetMana, "", false)
    targetMana.LeftText, targetMana.RightText = NativeText(targetMana, "50%"), NativeText(targetMana, "400")
    local enabledFrames = module.ExportSettings()
    enabledFrames.player.enabled, enabledFrames.target.enabled = true, true
    assert(module.ImportSettings(enabledFrames))
    playerClass, targetClass, targetPlayer = "PALADIN", "MAGE", true
    forecastAmount, forecastMaximum, targetForecastAmount = 30, 1000, 75
    assert(not custom.Start("secret") and not custom.Start("player", "secret") and not custom.Stop("secret"),
        "Secret unit/class arguments are rejected before indexing or comparison")
    local variantsCommand = assert(env.SlashCmdList.QOLTOOLKITCLASSFRAMES)
    variantsCommand("both")
    local targetFrame = assert(frames.ArkannsQOLClassCustomTarget)
    assert(nativeAuras:GetEffectiveAlpha() == auraAlpha and nativeAuras.shown
        and nativeAuras.parent == targetContextual and nativeAuras.points[1] == auraPoint
        and nativeAuras.scripts.OnEnter == auraEnter and auraEnter() == "native tooltip",
        "Native target auras stay visible with their original layout and tooltip pipeline")
    assert(nativeAuras.points[1][4] == 5 and nativeAuras.points[1][5] == -3
        and buffRow.points[1][5] == 0 and debuffRow.points[1][5] == -24,
        "The complete buff/debuff container moves down twelve units without changing the spacing between rows")
    env.TargetFrame:AnchorAuraContainer(); env.TargetFrame:AnchorAuraContainer()
    assert(nativeAuras.points[1][5] == -3, "Native aura relayout reapplies a single drop without accumulating offsets")
    aurasOnTop = true; env.TargetFrame:AnchorAuraContainer()
    assert(nativeAuras.points[1][5] == -6, "An explicit native buffs-on-top layout keeps its own position")
    aurasOnTop = false; env.TargetFrame:AnchorAuraContainer()
    combat = true; env.TargetFrame:AnchorAuraContainer()
    assert(nativeAuras.points[1][5] == -3, "Unprotected native auras retain the gap during combat relayout")
    auraProtected = true; env.TargetFrame:AnchorAuraContainer()
    assert(nativeAuras.points[1][5] == 9, "A protected native aura layout is left to the client during combat")
    combat = false
    auraProtected = false; env.TargetFrame:AnchorAuraContainer()
    assert(nativeAuras.points[1][5] == -3)
    assert(customFrame.shown and targetFrame.shown and targetFrame.parent == env.TargetFrame
        and playerContainer.alpha == 0 and targetContainer.alpha == 0 and targetMain.alpha == 0 and targetContent.alpha == .65,
        "Both native secure buttons keep separate, simultaneously active custom visuals")
    local mageArt = ns.TargetPortraitArt.customFrames.MAGE
    assert(targetFrame.skin.texture == mageArt.texture and targetFrame.skin.coords[1] == 1
        and targetFrame.skin.coords[2] == 0 and targetFrame.skin.coords[3] == 0 and targetFrame.skin.coords[4] == 1,
        "The target uses exactly the same class image with a horizontal UV flip")
    local targetScale = mageArt.displayWidth / mageArt.width
    assert(targetFrame.portrait.points[1][4] == (mageArt.width - mageArt.portrait[1]) * targetScale
        and targetFrame.health.points[1][4] == (mageArt.width - mageArt.health[1] - mageArt.health[3]) * targetScale
        and targetFrame.text.name.points[1][4] == (mageArt.width - mageArt.name[1] - mageArt.name[3]) * targetScale
        and targetFrame.text.level.points[1][4] == (mageArt.width - mageArt.level[1]) * targetScale,
        "Target portrait, bar, name and level follow reflected pixel coordinates")
    assert(targetFrame.portrait.portraitUnit == "target" and customFrame.portrait.portraitUnit == "player"
        and targetFrame.text.name.text == "Cible mage" and targetFrame.text.level.text == "24"
        and targetFrame.text.healthLeft.text == "60%" and targetFrame.text.healthRight.text == "600"
        and targetFrame.health.value == 600 and targetFrame.power.value == 400 and colorUnits.target,
        "Target text, portrait, reserve values and colors come from the target rather than the player")
    assert(targetFrame.indicators.forecast.value == 75 and customFrame.indicators.forecast.value == 30,
        "Each unit owns an independent heal calculator and forecast")
    targetForecastAmount = 90
    env.UnitFrameHealPredictionBars_Update(env.TargetFrame)
    assert(targetFrame.indicators.forecast.value == 90 and customFrame.indicators.forecast.value == 30,
        "A target heal update cannot replace the player's forecast")
    targetCombat = false; Event(customDriver, "UNIT_FLAGS", "target")
    assert(not targetFrame.indicators.combat.shown)
    targetCombat = true; Event(customDriver, "UNIT_FLAGS", "target")
    assert(targetFrame.indicators.combat.shown, "Target combat follows its public unit state")
    local playerValue = customFrame.health.value
    targetNativeHealth:SetValue(opaque); targetNativeHealth:SetMinMaxValues(0, opaque)
    targetHealth.RightText:SetText(opaque)
    assert(targetFrame.health.value == opaque and targetFrame.health.maximum == opaque
        and targetFrame.text.healthRight.text == opaque and customFrame.health.value == playerValue,
        "Target opaque data goes directly to its own display sinks")
    local classes = ns.TargetPortraitArt.order
    local stableHooks, stableWidgets = hookCount, #widgets
    for _, token in ipairs(classes) do
        playerClass, targetClass = token, token
        assert(custom.Start("player"))
        Event(customDriver, "PLAYER_TARGET_CHANGED")
        assert(customFrame.shown and targetFrame.shown
            and customFrame.skin.texture == ns.TargetPortraitArt.customFrames[token].texture
            and targetFrame.skin.texture == customFrame.skin.texture and nativeAuras:GetEffectiveAlpha() == auraAlpha,
            "All nine public class tokens select their own image for both units: " .. token)
        local style = ns.TargetPortraitArt.customFrames[token]
        for _, visual in ipairs({customFrame, targetFrame}) do
            assert(visual.skin.desaturation == (style.desaturation or 0)
                and visual.skin.color[1] == (style.brightness or 1)
                and visual.skin.color[2] == (style.brightness or 1)
                and visual.skin.color[3] == (style.brightness or 1) and visual.skin.color[4] == 1
                and visual.alpha == 1 and visual.portrait.alpha == 1
                and visual.health.alpha == 1 and visual.text.name.alpha == 1,
                "Only the skin receives class-specific brightness and desaturation: " .. token)
        end
    end
    playerClass = "MAGE"; assert(custom.Start("player"))
    playerClass = "PALADIN"; assert(custom.Start("player"))
    assert(customFrame.skin.desaturation == 0 and customFrame.skin.color[1] == 1,
        "Returning from a subdued mage skin resets the approved paladin style")
    assert(hookCount == stableHooks and #widgets == stableWidgets,
        "Switching class variants reuses existing frames, sources, hooks and forecast anchors")
    combat = true
    local beforeTargetFallback = #widgets
    targetClass = "secret"; Event(customDriver, "PLAYER_TARGET_CHANGED")
    assert(not targetFrame.shown and targetContainer.alpha == .85 and targetContent.alpha == .65 and targetMain.alpha == 1
        and customFrame.shown and #widgets == beforeTargetFallback,
        "A secret target class restores native visuals immediately during combat without creating resources")
    assert(nativeAuras.points[1][5] == 9, "Leaving the custom player frame restores the native aura position")
    targetPlayer, targetClass = false, "WARRIOR"
    Event(customDriver, "PLAYER_TARGET_CHANGED")
    assert(not targetFrame.shown and targetContainer.alpha == .85 and customFrame.shown,
        "NPC warrior-class metadata never replaces the native creature frame")
    targetPlayer, targetClass = true, "MAGE"
    Event(customDriver, "PLAYER_TARGET_CHANGED")
    assert(not targetFrame.shown and targetContainer.alpha == .85,
        "A suspended target waits until combat ends before preparing a different class layout")
    combat = false; Event(customDriver, "PLAYER_REGEN_ENABLED")
    assert(targetFrame.shown and targetFrame.skin.texture == mageArt.texture and targetContainer.alpha == 0,
        "The requested target mode resumes on the first safe transition")
    fallbackAvailable = false; Event(customDriver, "PLAYER_TARGET_CHANGED")
    assert(not targetFrame.shown and targetContainer.alpha == .85 and customFrame.shown,
        "A missing class image restores that native unit without stopping the other frame")
    fallbackAvailable = true; Event(customDriver, "PLAYER_TARGET_CHANGED")
    assert(targetFrame.shown)
    assert(custom.Stop("target") and not targetFrame.shown and customFrame.shown and targetContent.alpha == .65
        and targetMain.alpha == 1 and nativeAuras:GetEffectiveAlpha() == auraAlpha and nativeAuras.points[1][5] == 9,
        "Stopping one unit restores only its own native containers")
    variantsCommand("target ROGUE")
    assert(targetFrame.shown and targetFrame.skin.texture == ns.TargetPortraitArt.customFrames.ROGUE.texture)
    targetClass = "PRIEST"; Event(customDriver, "PLAYER_TARGET_CHANGED")
    assert(targetFrame.skin.texture == ns.TargetPortraitArt.customFrames.ROGUE.texture,
        "An explicit preview class remains selected until the session command changes it")
    local profile = module.ExportSettings()
    assert(not profile.customFrames and not profile.previewClass and not profile.player.customClass,
        "Variant selection is session-only and never enters settings or profiles")
    variantsCommand("off")
    assert(not targetFrame.shown and not customFrame.shown and playerContainer.alpha == .9
        and targetContainer.alpha == .85 and targetContent.alpha == .65,
        "The public off command restores both original native frames")
    print("PASS: nine class variants, exact target image mirroring, two units, opaque sinks, combat fallback and session-only previews")
    atlasesAvailable = false
    env.ForeverTooltipLibreDB.targetPortrait = {enabled = true, target = {customFrame = false}, player = {customFrame = false}}
    nextWidget = #widgets + 1
    Load("Modules/TargetPortrait.lua"); ns.InitializeTargetPortrait({})
    module, driver = modules.targetPortrait, widgets[nextWidget]
    target = assert(frames.ArkannsQOLClassPortraitTarget)
    assert(target.shown and target.rings[1].texture == ns.TargetPortraitArt.ring.texture,
        "Missing atlases use verified native file fallbacks")
    fallbackAvailable = false
    env.ForeverTooltipLibreDB.targetPortrait = {enabled = true, target = {customFrame = false}, player = {customFrame = false}}
    Load("Modules/TargetPortrait.lua"); ns.InitializeTargetPortrait({})
    assert(not frames.ArkannsQOLClassPortraitTarget.shown, "Missing artwork leaves the native portrait usable")
    -- Simulate the normal addon initialization after a reload, with no slash command.
    fallbackAvailable, atlasesAvailable, classAvailable = true, true, true
    combat, targetPlayer, playerClass, targetClass = false, true, "MAGE", "PRIEST"
    env.ForeverTooltipLibreDB.targetPortrait = {enabled = true,
        target = {enabled = true, intensity = "epic", size = 117}, player = {enabled = true, glow = .19}}
    Load("Modules/PaladinCustomTest.lua")
    Load("Modules/TargetPortrait.lua")
    ns.InitializeTargetPortrait({})
    local defaultModule, defaultTest = modules.targetPortrait, ns.PaladinCustomTest
    local defaultPlayer = assert(frames.ArkannsQOLPaladinCustomTest)
    local defaultTarget = assert(frames.ArkannsQOLClassCustomTarget)
    local defaultDriver = assert(frames.ArkannsQOLClassFrameEvents)
    local defaults = defaultModule.ExportSettings()
    assert(defaultPlayer.shown and defaultTarget.shown and defaults.player.customFrame and defaults.target.customFrame,
        "Normal initialization activates both class frames without a test command")
    assert(defaults.target.size == 117 and defaults.target.intensity == "epic" and defaults.player.glow == .19,
        "Default full frames preserve saved legacy ornament settings for a later return")
    assert(defaultPlayer.skin.texture == ns.TargetPortraitArt.customFrames.MAGE.texture
        and defaultTarget.skin.texture == ns.TargetPortraitArt.customFrames.PRIEST.texture,
        "Default activation chooses the current public class of each unit")
    local defaultPanel = frames.ArkannsQOLTargetPortraitSettings
    defaultPanel:SetSize(250, 312); defaultPanel:Show(); defaultPanel.scripts.OnShow(defaultPanel)
    local customCheck = assert(frames.ArkannsQOLTargetPortraitCustomFrame)
    local defaultScroll
    for _, widget in ipairs(widgets) do
        if widget.kind == "ScrollFrame" and widget.parent == defaultPanel then defaultScroll = widget end
    end
    assert(defaultScroll and defaultScroll.child:GetWidth() <= defaultPanel.width - 50,
        "Full-frame controls and help stay inside the narrow scroll viewport")
    local showUnit = frames.ArkannsQOLTargetPortraitUnitEnabled
    assert(customCheck.shown and customCheck.checked and not frames.ArkannsQOLTargetPortraitIntensity.shown
        and not frames.ArkannsQOLTargetPortraitAdvanced.shown and not frames.ArkannsQOLTargetPortraitEffects.shown
        and not frames.ArkannsQOLTargetPortraitPreviewClass.shown,
        "Full-frame mode shows its setting and hides unrelated ornament controls and tabs")
    assert(showUnit.points[1][4] + 22 + showUnit.label.width <= defaultPanel.width
        and frames.ArkannsQOLTargetPortraitUnit.points[1][4] + frames.ArkannsQOLTargetPortraitUnit.width <= defaultPanel.width,
        "Full-frame headers remain inside a 250px settings panel")
    Check("CustomFrame", false)
    assert(not defaultTarget.shown and defaultPlayer.shown and targetContainer.alpha == .85,
        "The per-unit checkbox restores the target's native frame while the player remains custom")
    Click("ArkannsQOLTargetPortraitEffects")
    local legacyAppearance = defaultModule.ExportSettings()
    legacyAppearance.target.customFrame = true
    assert(defaultModule.ImportSettings(legacyAppearance))
    assert(customCheck.shown and customCheck.checked and not frames.ArkannsQOLTargetPortraitEffects.shown
        and not frames.ArkannsQOLTargetPortraitGlow.shown and defaultTarget.shown,
        "Importing full-frame settings returns from Effects to the visible Style section")
    local fullProfile = defaultModule.ExportSettings()
    local offPlayer = defaultModule.ExportSettings(); offPlayer.player.enabled = false
    assert(defaultModule.ImportSettings(offPlayer) and not defaultPlayer.shown and defaultTarget.shown,
        "Default full frames respect an existing disabled player unit")
    assert(defaultModule.ImportSettings(fullProfile) and defaultPlayer.shown)
    defaultModule.SetEnabled(false)
    assert(not defaultPlayer.shown and not defaultTarget.shown)
    defaultModule.SetEnabled(true)
    assert(defaultPlayer.shown and defaultTarget.shown, "Re-enabling the module restores its configured defaults")
    local sessionOff = assert(env.SlashCmdList.QOLTOOLKITCLASSFRAMES)
    sessionOff("off")
    Event(defaultDriver, "PLAYER_ENTERING_WORLD")
    assert(not defaultPlayer.shown and not defaultTarget.shown,
        "The explicit off command prevents automatic reactivation for the remainder of the session")
    Check("CustomFrame", false); Check("CustomFrame", true)
    assert(defaultTarget.shown and not defaultPlayer.shown,
        "Changing the target's configured style explicitly re-arms only that unit")
    assert(defaultTest.Start("player"))
    combat = true
    Event(defaultDriver, "UNIT_ENTERED_VEHICLE", "target")
    targetPlayer = false; Event(defaultDriver, "PLAYER_TARGET_CHANGED")
    assert(not defaultTarget.shown and targetContainer.alpha == .85,
        "A non-player target keeps native visuals when default mode changes during combat")
    targetPlayer = true
    combat = false; Event(defaultDriver, "PLAYER_REGEN_ENABLED")
    assert(defaultTarget.shown)
    -- Return the player to automatic ownership, then test a vehicle round trip.
    local rearm = defaultModule.ExportSettings(); rearm.player.customFrame = false
    assert(defaultModule.ImportSettings(rearm))
    rearm.player.customFrame = true; assert(defaultModule.ImportSettings(rearm))
    env.PlayerFrame.unit = "vehicle"
    Event(defaultDriver, "UNIT_ENTERED_VEHICLE", "player")
    assert(not defaultPlayer.shown and playerContainer.alpha == .9)
    env.PlayerFrame.unit = "player"
    Event(defaultDriver, "UNIT_EXITED_VEHICLE", "player")
    assert(defaultPlayer.shown, "Default player frames resume after leaving a vehicle without a slash command")
    env.PlayerFrame.unit = "vehicle"; Event(defaultDriver, "UNIT_ENTERED_VEHICLE", "player")
    defaultModule.SetEnabled(false)
    env.PlayerFrame.unit = "player"
    defaultModule.SetEnabled(true)
    assert(defaultPlayer.shown,
        "Re-enabling after a vehicle exit missed while disabled does not retain a stale vehicle suspension")
    local roundTrip = defaultModule.ExportSettings()
    roundTrip.target.customFrame = false
    assert(defaultModule.ImportSettings(roundTrip) and not defaultTarget.shown)
    roundTrip.target.customFrame = true
    assert(defaultModule.ImportSettings(roundTrip) and defaultTarget.shown,
        "The new style preference round-trips through the existing profile import/export contract")
    assert(ns.Profiles.Save("Class frame defaults"))
    roundTrip.target.customFrame = false
    assert(defaultModule.ImportSettings(roundTrip) and not defaultTarget.shown)
    assert(ns.Profiles.Apply(assert(ns.Profiles.Preview("Class frame defaults", {targetPortrait = true}))) and defaultTarget.shown)
    assert(ns.Profiles.Undo() and not defaultTarget.shown and defaultPlayer.shown,
        "Applying and undoing a real profile restores each unit's complete-frame preference")
    roundTrip.target.customFrame = true
    assert(defaultModule.ImportSettings(roundTrip) and nativeAuras.points[1][5] == -3)
    auraProtected, combat = true, true
    defaultModule.SetEnabled(false)
    assert(nativeAuras.points[1][5] == -3 and defaultDriver.events.PLAYER_REGEN_ENABLED,
        "A protected pending aura restoration retains the safe-transition event after both units are disabled")
    combat = false; Event(defaultDriver, "PLAYER_REGEN_ENABLED")
    assert(nativeAuras.points[1][5] == 9 and not next(defaultDriver.events),
        "The native aura position is restored once on combat exit and the idle driver is released")
    auraProtected = false
    print("PASS: default class-frame initialization, migration, per-unit settings, compact controls, session off and automatic vehicle recovery")
end
print("PASS: class portrait settings, class transitions, combat deferral, previews, legacy profiles, and native fallbacks")
