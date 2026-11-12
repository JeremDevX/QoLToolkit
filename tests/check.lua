local testGlobals = {}
for key, value in pairs(_G) do testGlobals[key] = value end
local manifest = assert(io.open("QoLToolkit.toc", "r"))
local chunks, catalogs = {}, {}
local firstRuntimeFile, lastFile
local addonIcon
for line in manifest:lines() do
    addonIcon = line:match("^## IconTexture:%s+(.+)$") or addonIcon
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
assert(addonIcon == "Interface\\AddOns\\QoLToolkit\\Media\\QoLToolkit.tga", "Use the bundled addon icon")
local iconFile = assert(io.open("Media/QoLToolkit.tga", "rb"))
local iconHeader = iconFile:read(18)
iconFile:close()
assert(#iconHeader == 18 and iconHeader:byte(3) == 2 and iconHeader:byte(17) == 32,
    "Use an uncompressed 32-bit TGA")
assert(iconHeader:byte(13) == 128 and iconHeader:byte(14) == 0
    and iconHeader:byte(15) == 128 and iconHeader:byte(16) == 0, "Keep the icon square at 128 pixels")

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
    assert(ns.L("Infobulles et distance") == (locale == "frFR" and "Infobulles et distance" or "Tooltips and distance"))
    assert(ns.L("Affichage") == (locale == "frFR" and "Affichage" or "Display"))
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
eventFrame:OnEvent("ADDON_ACTION_FORBIDDEN", "QoLToolkit", "C_Container.UseContainerItem()")
eventFrame:OnEvent("ADDON_ACTION_BLOCKED", "QoLToolkit", "ContainerFrame1:Hide()")
eventFrame:OnEvent("ADDON_ACTION_FORBIDDEN", "QoLToolkit", "secret")
eventFrame:OnEvent("ADDON_ACTION_FORBIDDEN", "QoLToolkit", "bad\nmethod")
eventFrame:OnEvent("ADDON_ACTION_FORBIDDEN", "QoLToolkit", string.rep("x", 161))
eventFrame:OnEvent("ADDON_ACTION_BLOCKED", "AnotherAddon", "OtherFunction()")
callback()
local actions = ForeverTooltipLibreDB.diagnostics.rows[2]
assert(actions:find("ADDON_ACTION_FORBIDDEN function=C_Container.UseContainerItem()", 1, true),
    "Preserve the rejected function so a blocked item use can be diagnosed")
assert(actions:find("ADDON_ACTION_BLOCKED function=ContainerFrame1:Hide()", 1, true))
assert(actions:find("ADDON_ACTION_FORBIDDEN function=?", 1, true))
assert(not actions:find("secret", 1, true) and not actions:find("bad", 1, true)
    and not actions:find(string.rep("x", 161), 1, true) and not actions:find("OtherFunction", 1, true))
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
local spellIDs = {1, 2, 3, 2641, 6991, 136, 13163}
local spellRanges = {[1] = 30, [2] = 40, [3] = 45, [2641] = 10, [6991] = 10, [136] = 20, [13163] = 100}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #spellIDs} end,
    GetSpellBookItemInfo = function(slot) return {itemType = 1, spellID = spellIDs[slot]} end,
    IsSpellBookItemInRange = function(slot) return slot ~= 1 end,
}
C_Spell = {
    GetSpellInfo = function(id) return {minRange = 0, maxRange = spellRanges[id]} end,
    SpellHasRange = function() return true end,
    IsSpellHarmful = function(id) return id <= 2 end,
    IsSpellHelpful = function(id) return id >= 3 end,
}
chunks["Core/WoWRuntime.lua"]("QoLToolkit", distanceNS)
chunks["Modules/TargetDistance.lua"]("QoLToolkit", distanceNS)
distanceNS.InitializeTargetDistance()
local getDistance = distanceNS.GetMouseoverDistance
assert(not distanceModule.IsEnabled() and getDistance() == "Distance · 18 m", "Use the same label for every tooltip distance")
measured = "secret"
assert(getDistance() == nil, "Private measurements stay unavailable")
measured, checked = 0, false
assert(getDistance() == "Distance · ≈ 25–40 m", "Round both bounds outward")
measured, checked = nil, nil
assert(getDistance() == "Distance · ≈ 25–40 m", "A missing direct measurement must not suppress public range estimates")
measured, checked = 400, true
assert(getDistance() == "Distance · 18 m", "A direct measurement takes priority again when available")
measured, checked = "secret", true
assert(getDistance() == nil, "Restricted measurements must not trigger the missing-measurement fallback")
measured, checked = 0, false
hostile = false
assert(getDistance() == "Distance · ≈ 0–45 m", "Use helpful spell ranges for allies and ignore implicit pet/self targets")

local config = distanceModule.ExportSettings()
config.appearance.rounded = false
config.appearance.tooltip[2] = {.2, .3, .4}
assert(getDistance() == "Distance · ≈ 0–45 m", "Profile exports must be independent")
assert(distanceModule.ImportSettings(config))
hostile = true
local text, color = getDistance()
assert(text == "Distance · ≈ 27–37 m" and color[1] == .2 and color[2] == .3 and color[3] == .4)
C_SpellBook.IsSpellBookItemInRange = function() return false end
config.appearance.rounded = true
assert(distanceModule.ImportSettings(config) and getDistance() == "Distance · ≥ 35 m")
local oldProfile = {enabled = false}
distanceModule.profileMigrations[1](oldProfile, distanceModule.ExportSettings())
assert(oldProfile.appearance.tooltip[2][1] == .2)
hostile = false
C_SpellBook.IsSpellBookItemInRange = function(slot) if slot > 3 then return true end end
assert(getDistance() == nil, "No estimate when only spells with implicit targets answer")
UnitIsUnit = function(unit, other) return unit == "mouseover" and other == "pet" end
assert(getDistance() == "Distance · ≈ 0–10 m", "Use pet spells when hovering the player's pet")
UnitIsUnit = function() return "secret" end
assert(getDistance() == nil, "An unreadable unit comparison does not identify the player's pet")
UnitIsUnit = nil
print("PASS: target distance sources, conservative rounding, and legacy appearance settings")

local frames = {}
local createStub = CreateFrame
local missingTexture
CreateFrame = function(kind, name)
    local widget = createStub(kind, name)
    setmetatable(widget, {__index = function(_, key)
        if key ~= "IconBorder" and key ~= "IconQuestTexture" and key ~= "NewItemTexture"
            and key ~= "UpdateNewItem" and key ~= "Icon" and key ~= "icon" then return noop end
    end})
    widget.GetScript = rawget
    widget.ClearAllPoints = function(self) self.points = {} end
    widget:ClearAllPoints()
    widget.SetPoint = function(self, point, ...) self.points[point] = {...} end
    widget.SetTexture = function(self, asset)
        self.asset = asset
        return asset ~= missingTexture
    end
    widget.SetAllPoints = function(self, relative) self.relative = relative end
    widget.AddMaskTexture = function(self, mask) self.mask = mask end
    widget.SetTexCoord = function(self, ...) self.coords = {...} end
    widget.SetVertexColor = function(self, ...) self.color = {...} end
    widget.SetGradient = function(self, _, ...) self.gradient = {...} end
    widget.SetBlendMode = function(self, mode) self.blend = mode end
    widget.SetAlpha = function(self, alpha) self.alpha = alpha end
    widget.GetAlpha = function(self) return self.alpha end
    widget.CreateTexture = function(self, _, layer)
        local texture = CreateFrame("Texture")
        texture.layer = layer
        self.textures = rawget(self, "textures") or {}
        table.insert(self.textures, texture)
        return texture
    end
    widget.CreateMaskTexture = function() return CreateFrame("MaskTexture") end
    widget.GetThumbTexture = function() return CreateFrame("Texture") end
    if name then frames[name] = widget end
    return widget
end

do
    local opened, diameter = nil, 198
    Settings = {
        RegisterCanvasLayoutCategory = function() return {GetID = function() return 42 end} end,
        RegisterAddOnCategory = noop,
        OpenToCategory = function(id) opened = id end,
    }
    Minimap = {
        GetSize = function() return diameter, diameter end,
        GetFrameLevel = function() return 4 end,
        GetCenter = function() return 500, 400 end,
        GetEffectiveScale = function() return .5 end,
        HookScript = function(self, event, fn) self[event] = fn end,
    }
    GetCursorPosition = function() return 250, 250 end
    local metadata = C_AddOns.GetAddOnMetadata
    C_AddOns.GetAddOnMetadata = function(name, key)
        if name == "QoLToolkit" and key == "IconTexture" then return addonIcon end
    end
    local bootstrapNS = {L = distanceNS.L, WoW = distanceNS.WoW, UI = {Initialize = noop},
        SettingsState = {Initialize = function() return true end}}
    bootstrapNS.UI.RegisterSettingsPanel = function() return Settings.RegisterCanvasLayoutCategory() end
    bootstrapNS.UI.OpenSettings = function(id) assert(id == "home"); opened = "standalone" end
    local function LoadButton()
        chunks["Core/Bootstrap.lua"]("QoLToolkit", bootstrapNS)
        frames.ArkannsQOLBootstrapEvents:OnEvent("ADDON_LOADED", "QoLToolkit")
        return frames.ArkannsQOLMinimapButton
    end
    local button = LoadButton()
    local background, icon, border = unpack(button.textures)
    assert(icon.asset == addonIcon and not rawget(icon, "coords"), "Use the full bundled artwork")
    assert(icon.relative == background and icon.mask == background.mask and icon.mask.relative == background,
        "Fill the round area and clip the artwork with its mask")
    assert(border.layer == "OVERLAY")
    button:OnClick()
    assert(opened == "standalone")
    button:OnDragStart()
    button:OnUpdate()
    button:OnDragStop()
    assert(not button:GetScript("OnUpdate") and ForeverTooltipLibreDB.minimapAngle == math.pi / 2,
        "Drag must save the angle and stop following the cursor")
    button = LoadButton()
    local center = button.points.CENTER
    assert(center[1] == Minimap and center[2] == "CENTER" and math.abs(center[3]) < .001 and center[4] == 103)
    bootstrapNS.SetMinimapVisible(false)
    assert(ForeverTooltipLibreDB.minimapHidden and not bootstrapNS.IsMinimapVisible())
    button = LoadButton()
    assert(not bootstrapNS.IsMinimapVisible(), "Keep minimap visibility across reload")
    bootstrapNS.SetMinimapVisible(true)
    assert(bootstrapNS.IsMinimapVisible())
    diameter = 160
    Minimap:OnSizeChanged()
    assert(button.points.CENTER[4] == 84)
    missingTexture = addonIcon
    assert(LoadButton().textures[2].asset == "Interface\\Icons\\INV_Misc_Wrench_01", "Missing artwork uses the native icon")
    missingTexture = nil
    C_AddOns.GetAddOnMetadata = nil
    assert(LoadButton().textures[2].asset == "Interface\\Icons\\INV_Misc_Wrench_01", "Missing metadata uses the native icon")
    C_AddOns.GetAddOnMetadata = metadata
end
print("PASS: minimap artwork, mask, fallback, click, scaled drag, reload, and map resize")

do
    local hook, bagModule, shortcut, opened
    local bag = {GetBagID = function() return 0 end, GetFrameLevel = function() return 1 end,
        IsVisible = function() return true end}
    ContainerFrameCombinedBags = bag
    local createWidget = CreateFrame
    CreateFrame = function(kind, name, parent)
        local widget = createWidget(kind, name)
        widget.parent = parent
        widget.SetHeight = function(self, height) self.height = height end
        widget.GetHeight = function(self) return rawget(self, "height") or 300 end
        widget.SetSize = function(self, _, height) self:SetHeight(height) end
        widget.SetShown = function(self, shown) self.shown = shown end
        widget.IsShown = function(self) return self.shown end
        if parent == bag then shortcut = widget end
        return widget
    end
    local slot = CreateFrame("ItemButton")
    slot.containerFrame, slot.IconBorder, slot.icon = bag, CreateFrame("Texture"), CreateFrame("Texture")
    slot.GetBagID, slot.GetID = bag.GetBagID, function() return 1 end
    bag.EnumerateValidItems = function() return ipairs({slot}) end
    slot.IconBorder.alpha = .8
    slot.IconBorder.GetTexture = function() return "Interface\\Common\\WhiteIconFrame" end
    local mask = CreateFrame("MaskTexture")
    slot.icon.GetMaskTexture = function() return mask end
    NUM_TOTAL_BAG_FRAMES = 5
    ContainerFrameUtil_GetShownFrameForID = function() return bag end
    ContainerFrameUtil_EnumerateContainerFrames = function() return ipairs({bag}) end
    local newItemHook
    slot.UpdateNewItem = noop
    hooksecurefunc = function(target, name, fn)
        if target == "SetItemButtonQuality" then hook = name
        else
            assert(target == slot and name == "UpdateNewItem")
            newItemHook = fn
        end
    end
    SetItemButtonQuality = function(...) hook(...) end
    local newItemGlow = CreateFrame("Texture")
    slot.NewItemTexture = newItemGlow
    newItemGlow.GetAtlas = function(self) return self.atlas end
    newItemGlow.SetAtlas = function(self, atlas) self.atlas = atlas end
    local questInfo
    slot.IconQuestTexture = CreateFrame("Texture")
    slot.IconQuestTexture.alpha = .9
    local bagItem = {quality = 4, itemID = 42}
    C_Container = {GetContainerItemInfo = function() return bagItem end,
        GetContainerItemQuestInfo = function() return questInfo end}
    ITEM_QUALITY6_DESC, ITEM_QUALITY7_DESC, ITEM_QUALITY8_DESC = "Artifact", "Heirloom", "WoW Token"
    local reagent
    C_Item = {GetItemQualityColor = function() return .64, .21, .93 end,
        GetItemInfo = function(item)
            assert(item == 42 or item == "item:42")
            return "Linen", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, reagent
        end}
    CreateColor = function(...) return {...} end
    local bagsCategory = {GetID = function() return 2 end}
    Settings.RegisterCanvasLayoutSubcategory = function() return bagsCategory end
    Settings.OpenToCategory = function(id) opened = id end
    local function Control() return CreateFrame("Frame") end
    local function Check(_, name, _, _, _, callback)
        local control = CreateFrame("CheckButton", name)
        control.SetChecked = function(self, value) self.checked = value end
        control:SetScript("OnClick", function(_, value) callback(value) end)
        return control
    end
    local function Button(_, name, _, _, _, _, callback)
        local button = CreateFrame("Button", name)
        button:SetScript("OnClick", callback)
        return button
    end
    local bagNS = {L = distanceNS.L, WoW = distanceNS.WoW,
        UI = {StylePanel = noop, Label = Control, Check = Check, Button = Button, Refresh = noop,
            ClampScroll = function(scroll, height) scroll.offset = math.min(scroll.offset, math.max(0, height - scroll:GetHeight())) end},
        RegisterModule = function(_, module) bagModule = module end}
    bagNS.UI.RegisterSettingsPanel = Settings.RegisterCanvasLayoutSubcategory
    bagNS.UI.OpenCategory = function(category) opened = category:GetID(); return true end
    ForeverTooltipLibreDB.bagSort = {qualityInnerGlow = 100, qualityUncommonOnly = true}
    chunks["Modules/BagSort.lua"]("QoLToolkit", bagNS)
    bagNS.InitializeBagSort({GetID = function() return 1 end})
    assert(not frames.ArkannsQOLBagShowColor0.checked and not frames.ArkannsQOLBagShowColor1.checked
        and frames.ArkannsQOLBagShowColorreagent.checked, "Migrate the old filter on reload")
    local advanced = frames.ArkannsQOLBagColor4.parent
    local body, scroll = advanced.parent, advanced.parent.parent
    local collapsedHeight = body:GetHeight()
    assert(not advanced.shown)
    scroll.offset = 0
    frames.ArkannsQOLBagAdvanced:OnClick()
    assert(advanced.shown and body:GetHeight() > collapsedHeight)
    scroll.offset = 200
    frames.ArkannsQOLBagAdvanced:OnClick()
    assert(not advanced.shown and body:GetHeight() == collapsedHeight and scroll.offset == 0)
    local revealedScroll, revealedControl
    bagNS.UI.RevealControl = function(viewport, control) revealedScroll, revealedControl = viewport, control end
    bagModule.OpenSettings("Halo intérieur")
    assert(advanced.shown and revealedScroll == scroll and revealedControl == frames.ArkannsQOLBag_qualityInnerGlow,
        "Bag search opens the border section and reveals the exact control")
    scroll.offset = 48
    bagModule.OpenSettings(nil)
    assert(advanced.shown and scroll.offset == 48, "Returning to bags preserves the section and scroll")
    frames.ArkannsQOLBagAdvanced:OnClick()
    SetItemButtonQuality(slot, 4)
    local outline, glow = slot.textures[1], slot.textures[2]
    assert(outline.points.TOPLEFT[1] == slot.IconBorder and outline.points.BOTTOMRIGHT[2] == "BOTTOMRIGHT")
    assert(bagModule.ImportSettings({enabled = false, qualityThickness = 4, qualityOpacity = 50}))
    SetItemButtonQuality(slot, 4)
    assert(outline.points.BOTTOMRIGHT[2] == "CENTER" and outline.coords[2] < .5,
        "Thick border must magnify the native edge with no inset ring")
    assert(slot.textures[6].points.TOPLEFT[2] == "TOP" and slot.textures[8].points.TOPLEFT[2] == "CENTER")
    assert(glow.layer == "ARTWORK" and glow.blend == "BLEND" and glow.gradient[2][4] >= .9)
    frames.ArkannsQOLBag_qualityInnerGlow:OnValueChanged(15)
    assert(glow.shown and glow.gradient[1][4] == 0 and math.abs(glow.gradient[2][4] - .1425) < .0001,
        "The main slider must update the gradient opacity on open bag slots")
    assert(bagModule.ImportSettings({enabled = false, qualityThickness = 1, qualityInnerGlow = 0}))
    SetItemButtonQuality(slot, 4)
    assert(not slot.textures[6].shown and not glow.shown and outline.points.BOTTOMRIGHT[2] == "BOTTOMRIGHT")
    assert(slot.IconBorder.alpha == 0)
    newItemGlow:SetAtlas("bags-glow-purple")
    newItemGlow:Show()
    if newItemHook then newItemHook(slot) end
    assert(newItemGlow.atlas == "bags-glow-white" and newItemGlow.color[1] == outline.color[1],
        "A fresh item's native halo must follow the replacement color")
    SetItemButtonQuality(slot, "secret")
    assert(not outline.shown and slot.IconBorder.alpha == .8)
    assert(newItemGlow.atlas == "bags-glow-purple" and newItemGlow.color[1] == 1)
    newItemGlow:Hide()

    assert(not frames.ArkannsQOLBagColor6 and not frames.ArkannsQOLBagColor7 and not frames.ArkannsQOLBagColor8)
    assert(frames.ArkannsQOLBagColorquest, "Quest items need a separate color sample")
    assert(bagModule.ImportSettings({enabled = false, qualityUncommonOnly = true,
        qualityColors = {quest = "FFCC00", [1] = "FFFFFF", [6] = "123456"}}))
    questInfo = {isQuestItem = true}
    SetItemButtonQuality(slot, 1)
    assert(outline.shown and outline.color[1] == 1 and outline.color[2] == .8 and outline.color[3] == 0,
        "Quest color must override common quality and survive the gray/white filter")
    assert(slot.IconQuestTexture.alpha == 0, "Replace the native quest border too")
    questInfo = {isQuestItem = false, questID = 123}
    SetItemButtonQuality(slot, 1)
    assert(outline.shown and slot.IconQuestTexture.alpha == .9, "Keep the native quest-start marker")
    questInfo = {isQuestItem = false}
    SetItemButtonQuality(slot, 1)
    assert(not outline.shown, "Ordinary whites still obey the filter")
    questInfo = {isQuestItem = "secret", questID = "secret"}
    SetItemButtonQuality(slot, 1)
    assert(not outline.shown, "Secret quest fields must not classify an item")
    local questAPI = C_Container.GetContainerItemQuestInfo
    C_Container.GetContainerItemQuestInfo = nil
    SetItemButtonQuality(slot, 1)
    assert(not outline.shown, "Missing quest API falls back to item quality")
    C_Container.GetContainerItemQuestInfo = function() error("unavailable") end
    SetItemButtonQuality(slot, 1)
    assert(not outline.shown, "Refused quest reads fall back to item quality")
    C_Container.GetContainerItemQuestInfo = questAPI
    local exported = bagModule.ExportSettings()
    assert(exported.qualityColors.quest == "FFCC00" and exported.qualityColors[6] == "123456")
    assert(bagModule.ImportSettings(exported), "Quest colors must survive a profile round trip")
    assert(bagModule.ImportSettings({enabled = false, qualityUncommonOnly = false, qualityColors = {}}))
    questInfo = {isQuestItem = true}
    SetItemButtonQuality(slot, 1)
    assert(outline.color[2] == .82, "Reset restores the default yellow quest color")
    questInfo = nil

    bagModule.OpenSettings("Composants d’artisanat")
    assert(revealedControl == frames.ArkannsQOLBagColorreagent)
    SetItemButtonQuality(slot, 4, "item:42")
    assert(outline.color[1] == .64, "An item awaiting data keeps its quality color")
    reagent = true
    frames.ArkannsQOLBagQualityEvents:OnEvent("ITEM_DATA_LOAD_RESULT", 42, true)
    assert(outline.color[1] == 0x36 / 255 and outline.color[2] == 0xD9 / 255, "Late reagent data applies turquoise")
    local colorOptions
    ColorPickerFrame = {
        SetupColorPickerAndShow = function(_, options) colorOptions = options end,
        GetColorRGB = function() return 1, .5, 0 end,
    }
    frames.ArkannsQOLBagColorreagent:OnClick("LeftButton")
    assert(colorOptions.r == 0x36 / 255)
    colorOptions.swatchFunc()
    assert(outline.color[1] == 1 and outline.color[2] == 0x80 / 255)
    colorOptions.cancelFunc()
    assert(outline.color[1] == 0x36 / 255)
    colorOptions.swatchFunc()
    frames.ArkannsQOLBagShowColorreagent:OnClick(false)
    assert(not outline.shown and slot.IconBorder.alpha == .8
        and bagModule.ExportSettings().qualityColors.reagent == "FF8000", "Unchecked reagents use the native border")
    assert(bagModule.ImportSettings(bagModule.ExportSettings()), "Reagent color and checkbox survive a profile round trip")
    local old = {enabled = false, qualityUncommonOnly = true}
    bagModule.profileMigrations[#bagModule.profileMigrations](old, bagModule.ExportSettings())
    assert(old.qualityUncommonOnly == nil and old.qualityHidden[0] and old.qualityHidden[1])
    ColorPickerFrame = nil

    local tooltip = GameTooltip
    GameTooltip = nil
    shortcut:OnClick("LeftButton")
    local quick = frames.ArkannsQOLBagQuickSettings
    assert(quick.shown and quick.points.TOPRIGHT[1] == bag)
    assert(not frames.ArkannsQOLBagQuickShowColorreagent.checked and frames.ArkannsQOLBagQuickShowColor4.checked)
    frames.ArkannsQOLBagQuickShowColorreagent:OnClick(true)
    assert(outline.shown and frames.ArkannsQOLBagShowColorreagent.checked)
    frames.ArkannsQOLBagQuickColorreagent:OnClick("RightButton")
    assert(outline.color[1] == 0x36 / 255, "Reset the reagent color to turquoise from quick settings")
    assert(frames.ArkannsQOLBagQuickColorquest and not frames.ArkannsQOLBagQuickColor6)
    for key, value in pairs({qualityOpacity = 75, qualityThickness = 3, qualityInnerGlow = 40}) do
        local slider = assert(frames["ArkannsQOLBagQuick_" .. key], "Missing backpack slider " .. key)
        slider:OnValueChanged(value)
        assert(bagModule.ExportSettings()[key] == value, "Backpack controls must update the shared bag settings")
    end
    assert(glow.shown and math.abs(glow.gradient[2][4] - .38) < .0001,
        "The backpack slider must restore the glow at the chosen intensity")
    frames.ArkannsQOLBagQuickMore:OnClick()
    assert(not quick.shown and opened == 2)
    shortcut:OnClick("RightButton")
    assert(opened == 1)
    GameTooltip = tooltip
    CreateFrame = createWidget
end
print("PASS: bag border geometry, inner glow, native restoration, and backpack settings")

-- Keep each simulation isolated from the globals used above.
for _, path in ipairs({"tests/session_history.lua","tests/session_history_ui.lua","tests/talent_plan.lua","tests/ui_core.lua","tests/ui_profiles.lua","tests/ui_advanced.lua","tests/advanced_bounds.lua","tests/ui_utilities.lua","tests/rank_events.lua","tests/ui_modules.lua","tests/flight_times.lua"}) do
    local chunk = assert(loadfile(path))
    local environment = setmetatable({}, {__index = testGlobals})
    environment._G = environment
    setfenv(chunk, environment)()
end
