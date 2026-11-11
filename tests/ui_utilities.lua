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
local ns = {L = function(text) return text end, RegisterModule = function(id, module) modules[id] = module end}
local ui = {Copy = Copy, StylePanel = noop, StyleFrame = noop, StyleButton = noop, Refresh = noop,
    GetStyle = function() return nil end, IsOverride = function() return false end, SetOverride = noop}
ns.UI = ui
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
    function methods:SetParent(parent) assert(not combat); self.parent = parent end
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
    function methods:SetAtlas() error("The trim must work without the live unit frame atlas") end
    function methods:SetDesaturated(value) self.desaturated = value end
    function methods:SetVertexColor(...) self.color = {...} end
    local rimTexture = "Interface\\Minimap\\MiniMap-TrackingBorder"
    local rimAvailable = true
    function methods:SetTexture(texture)
        self.texture = texture
        return texture ~= rimTexture or rimAvailable
    end
    function methods:SetTexCoord(...) self.coords = {...} end

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
    assert(#frame.trims == 2 and frame.trims[1].texture == rimTexture,
        "Draw visible class trim even when the live unit frame atlas is unavailable")
    assert(frame.shown and not frame.mouse and frame.level == container.level + 1 and frame.points[1][2] == portrait)
    assert(frame.icon.width == 16 and frame.icon.points[1][4] == 24)
    assert(frame.icon.texture == "Interface\\WorldStateFrame\\Icons-Classes" and frame.icon.coords[1] > .25)
    for _, trim in ipairs(frame.trims) do
        assert(trim.texture == rimTexture and trim.desaturated and trim.points[1][2] == frame)
        assert(trim.mask.texture == "Interface\\CharacterFrame\\TempPortraitAlphaMask")
        assert(trim.mask.width < 29 and trim.mask.height < 29, "Keep each arc in a corner of the portrait")
    end
    local top, bottom = frame.trims[1], frame.trims[2]
    assert(top.mask.points[1][4] > 0 and top.mask.points[1][5] > 0 and top.coords[1] > top.coords[2])
    assert(bottom.mask.points[1][4] < 0 and bottom.mask.points[1][5] < 0 and bottom.coords[3] > bottom.coords[4])
    assert(top.alpha >= .9 and top.alpha > bottom.alpha, "Keep the accent under the emblem clearly visible")
    local firstColor = frame.trims[1].color[1]
    combat, class = true, "DRUID"
    Event("PLAYER_TARGET_CHANGED")
    assert(frame.shown and frame.icon.coords[1] > .75 and frame.trims[1].color[1] > firstColor)
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

    rimAvailable = false
    env.ForeverTooltipLibreDB.targetPortrait = nil
    Load("Modules/TargetPortrait.lua")
    ns.InitializeTargetPortrait({})
    local fallback = assert(Overlay())
    assert(fallback ~= frame and fallback.shown and #fallback.trims == 0 and fallback.icon,
        "If the native rim texture cannot load, keep the class emblem")
end
print("PASS: target class trim geometry, protected anchors, class changes, native portrait setting, and profiles")
