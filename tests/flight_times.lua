local frames, hooks, buttons, badges = {}, {}, {}, {}
local noop = function() end
local methods = {}
for _, name in ipairs({"ClearAllPoints", "SetClampedToScreen", "SetWordWrap", "SetMultiLine", "SetJustifyH", "SetAllPoints",
    "SetAutoFocus", "SetFontObject", "SetScrollChild", "SetVerticalScroll", "SetOrientation", "SetValueStep",
    "SetObeyStepOnDrag", "SetBackdrop", "SetFrameStrata"}) do
    methods[name] = noop
end
function methods:SetPoint(...) self.point = {...} end
function methods:EnableMouse(enabled) self.mouse = enabled end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetAtlas(atlas) self.atlas = atlas end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetStatusBarTexture(texture) self.texture = texture end
function methods:SetStatusBarColor(...) self.color = {...} end
function methods:SetMinMaxValues(minimum, maximum)
    self.minimum, self.maximum = minimum, maximum
    if minimum == 0 and maximum == 0 then self.timer = nil end
end
function methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:GetValue() return self.value end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetScale(scale) self.scale = scale end
function methods:SetShown(shown) self.shown = shown end
function methods:CreateTexture(_, layer, _, sublevel)
    local texture = CreateFrame("Texture", nil, self)
    texture.layer, texture.sublevel = layer, sublevel
    self.textures[#self.textures + 1] = texture
    return texture
end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetChecked(value) self.checked = value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetFocus()
    if self.focus then return end
    self.focus = true
    if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function methods:HasFocus() return self.focus == true end
function methods:ClearFocus()
    local focused = self.focus
    self.focus = false
    if focused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function methods:HighlightText() self.selected = true end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterAllEvents() self.events = {} end

CreateFrame = function(kind, name, parent, template)
    local frame = setmetatable({scripts = {}, events = {}, textures = {}, kind = kind, parent = parent,
        width = 360, height = 240, shown = true, template = template}, {__index = methods})
    if name then frames[name] = frame end
    return frame
end
Settings = {RegisterCanvasLayoutSubcategory = function(_, panel, label) return {panel = panel, label = label} end}
local module
local ns = {modules = {}}
function ns.RegisterModule(id, descriptor)
    assert(id == "flights")
    ns.modules[id], module = descriptor, descriptor
end
ns.UI = {
    RegisterSettingsPanel = Settings.RegisterCanvasLayoutSubcategory,
    StylePanel = noop,
    ClampScroll = noop,
    Notify = noop,
    RevealControl = function(_, control) ns.revealed = control end,
    Label = function(parent, text, _, _, size)
        local frame = CreateFrame("FontString")
        frame.fontSize = size
        frame:SetText(text)
        if parent == frames.ArkannsQOLFlightTimerPanel then badges[#badges + 1] = frame end
        return frame
    end,
    Button = function(parent, name, label, _, _, _, callback)
        buttons[label] = callback
        local control = CreateFrame("Button", name, parent)
        control:SetText(label)
        control:SetScript("OnClick", callback)
        return control
    end,
    Input = function(parent, name) return CreateFrame("EditBox", name, parent) end,
    Check = function(parent, name, _, _, _, callback)
        local control = CreateFrame("CheckButton", name, parent)
        control:SetScript("OnClick", function(self) callback(self.checked == true) end)
        return control
    end,
}
local function Load(path) setfenv(assert(loadfile(path)), _G)("QoLToolkit", ns) end
Load("Locales/Locale.lua")
Load("Locales/enUS-Flights.lua")
Load("Core/WoWRuntime.lua")
Load("Modules/FlightTimesData.lua")
Load("Modules/FlightTimes.lua")

local now, onTaxi, rank, build, combat = 1, false, 0, "70888", false
local secret = {}
issecretvalue = function(value) return value == secret end
GetTime = function() return now end
GetBuildInfo = function() return "1.60.1", build, "", 16001 end
UnitOnTaxi = function(unit) assert(unit == "player"); return onTaxi end
UnitFactionGroup = function(unit) assert(unit == "player"); return "Alliance" end
C_Texture = {GetAtlasInfo = function() return {width = 240, height = 140} end}
InCombatLockdown = function() return combat end
Constants = {LegacyConsts = {LEGACY_TREE_ADVENTURE_ID = 1188}}
C_Traits = {
    GetConfigIDByTreeID = function(tree) assert(tree == 1188); return 17 end,
    GetNodeInfo = function(config, node)
        assert(config == 17 and node == 110300)
        return {activeRank = rank}
    end,
}
Enum = {FlightPathState = {Current = 0, Reachable = 1, Unreachable = 2}}
local chain, canReadRoute = {1, 2, 3}, true
local taxiNodes = {
    {slotIndex = 1, nodeID = 101, state = 0, name = "Start"},
    {slotIndex = 2, nodeID = 303, state = 1, name = "Stop"},
    {slotIndex = 3, nodeID = 202, state = 1, name = "Destination"},
}
GetTaxiMapID = function() return 1415 end
C_TaxiMap = {GetAllTaxiNodes = function(map) assert(map == 1415); return taxiNodes end}
GetNumRoutes = function(slot) assert(slot == chain[#chain]); return canReadRoute and #chain - 1 end
TaxiGetNodeSlot = function(slot, leg, fromSource)
    assert(slot == chain[#chain])
    return chain[fromSource and leg or leg + 1]
end
TakeTaxiNode, TaxiRequestEarlyLanding, TaxiNodeOnButtonEnter = noop, noop, noop
FlightMap_FlightPointPinMixin = {OnMouseEnter = noop}
hooksecurefunc = function(target, method, callback)
    local name = type(target) == "table" and method or target
    assert(not hooks[name], "Secure observers must be installed once")
    hooks[name] = callback or method
end

local destination = {GetID = function() return 3 end, taxiNodeData = {slotIndex = 3}}
local tooltipText
GameTooltip = {
    IsForbidden = function() return false end, GetOwner = function() return destination end, Show = noop,
    AddLine = function(_, value) tooltipText = value end,
}
ForeverTooltipLibreDB = {}
local route = "70888,0,101>303>202"
ns.FlightTimesData[route] = 102
ns.InitializeFlightTimes({})
local driver = frames.ArkannsQOLFlightEvents
local function Event(event) assert(driver.events[event]); driver.scripts.OnEvent(driver, event) end
local function PollAt(time, flying)
    now, onTaxi = time, flying
    driver.scripts.OnUpdate(driver, .2)
end
local function Begin()
    onTaxi = false
    Event("TAXIMAP_OPENED")
    hooks.TakeTaxiNode(chain[#chain])
    PollAt(now + 1, true)
    return now
end

assert(module.IsEnabled() and module.category().label == "Flight times")
buttons["Export durations"]()
assert(not frames.ArkannsQOLFlightExport.selected, "An empty export does not expose copyable data")
Event("TAXIMAP_OPENED")
hooks.TaxiNodeOnButtonEnter(destination)
assert(tooltipText == "Travel time: 1:42")
rank, tooltipText = 1, nil
hooks.TaxiNodeOnButtonEnter(destination)
hooks.OnMouseEnter(destination)
assert(not tooltipText, "Neither map adds a line without a known duration")
rank = 0
combat, tooltipText = true, nil
hooks.OnMouseEnter(destination)
assert(not tooltipText, "The native tooltip is untouched in combat")
combat = false
Event("TAXIMAP_CLOSED")
canReadRoute = false
hooks.TakeTaxiNode(3)
PollAt(2, true)
assert(badges[1].text == "Destination" and badges[1].fontSize == 14 and badges[2].text == "1:42" and not badges[3].shown)
local progress = frames.ArkannsQOLFlightTimer.progress
assert(progress.shown and progress.minimum == 0 and progress.maximum == 1 and progress.value == 0)
PollAt(2.5, true)
assert(progress.value == .5 / 102 and badges[2].text == "1:42", "The fallback bar updates between text changes")
PollAt(62, true)
assert(badges[2].text == "0:42" and math.abs(progress.value - 60 / 102) < .0001)
PollAt(102, false)
assert(ArkannsQOLFlightsDB[route][1] == 100 and not driver.scripts.OnUpdate and not frames.ArkannsQOLFlightTimer.shown)

canReadRoute = true
Event("TAXIMAP_OPENED")
hooks.OnMouseEnter(destination)
assert(tooltipText == "Travel time: 1:40", "Personal measurements have priority")
local start = Begin()
assert(badges[2].text == "1:40" and not badges[3].shown, "Use the current personal measurement directly")
hooks.TaxiRequestEarlyLanding()
PollAt(start + 25, true)
assert(badges[2].text == "0:25" and badges[3].shown and badges[3].text == "Landing requested" and not progress.shown)
PollAt(start + 26, false)
assert(#ArkannsQOLFlightsDB[route] == 1)

-- A landing request can arrive before the first periodic taxi-state check.
onTaxi = false
Event("TAXIMAP_OPENED")
hooks.TakeTaxiNode(3)
now, onTaxi = now + .1, true
hooks.TaxiRequestEarlyLanding()
PollAt(now + .1, true)
assert(badges[2].text == "0:00" and badges[3].text == "Landing requested", "An interrupted pending flight must discard its estimate")
PollAt(now + 30, false)
assert(#ArkannsQOLFlightsDB[route] == 1, "An interrupted pending flight must not add a complete-route sample")

rank = 1
start = Begin()
assert(badges[2].text == "0:00" and badges[3].text == "Elapsed time" and not progress.shown)
PollAt(start + 82, false)
assert(ArkannsQOLFlightsDB["70888,1,101>303>202"][1] == 82)

rank, chain = 0, {1, 3}
start = Begin()
PollAt(start + 75, false)
assert(ArkannsQOLFlightsDB["70888,0,101>202"][1] == 75, "Different stop sequences remain distinct")

build, chain = "70999", {1, 2, 3}
Event("TAXIMAP_OPENED")
hooks.TaxiNodeOnButtonEnter(destination)
assert(tooltipText == "Travel time: 1:40")
start = Begin()
assert(badges[2].text == "1:40" and not badges[3].shown,
    "A game update must reuse the saved personal duration in the countdown")
Event("PLAYER_LEAVING_WORLD")
assert(not driver.scripts.OnUpdate and not ArkannsQOLFlightsDB["70999,0,101>303>202"])
onTaxi = false

rank = secret
start = Begin()
PollAt(start + 100, false)
assert(not ArkannsQOLFlightsDB["70999,0,101>303>202"], "An unknown speed cannot enter the database")
rank = 0
local getTaxiMapID = GetTaxiMapID
GetTaxiMapID = nil
start = Begin()
assert(badges[1].text == "In flight")
PollAt(start + 100, false)
assert(not ArkannsQOLFlightsDB["70999,0,101>303>202"], "Missing taxi data only allows elapsed time")
GetTaxiMapID = getTaxiMapID
Event("TAXIMAP_OPENED")
hooks.TakeTaxiNode(3)
PollAt(now + 6, false)
assert(not driver.scripts.OnUpdate, "A failed taxi selection stops polling")

start = Begin()
assert(module.ImportSettings({enabled = false}))
assert(not driver.scripts.OnUpdate and not driver.events.TAXIMAP_OPENED and not frames.ArkannsQOLFlightTimer.shown)
assert(module.ImportSettings({enabled = true}) and module.ExportSettings().enabled)
assert(not module.ExportSettings().records)

buttons["Export durations"]()
local output = frames.ArkannsQOLFlightExport
assert(output.focus and output.selected)
assert(output.text == "QTF1\n70888,0,101>202,75\n70888,0,101>303>202,100\n70888,1,101>303>202,82")
module.category().panel.scripts.OnHide()
assert(output.text == "")

local function Choose(key, label)
    local selected
    MenuUtil = {CreateContextMenu = function(owner, generate)
        generate(owner, {CreateRadio = function(_, item, isSelected, choose)
            if item == label then choose(); selected = isSelected() end
        end})
    end}
    local button = frames["ArkannsQOL_" .. key]
    button.scripts.OnClick(button)
    assert(selected, label)
end

-- The settings page previews the same placement applied to an active flight.
local settings = module.category().panel
settings.scripts.OnShow()
local preview, live = frames.ArkannsQOLFlightPreview, frames.ArkannsQOLFlightTimer
local oldProfile = module.ExportSettings()
assert(preview.scale < 1 and preview.width * preview.scale <= settings.width - 32)
local narrowScale = preview.scale
settings:SetSize(900, 650)
settings.scripts.OnSizeChanged()
assert(preview.scale > narrowScale and preview.width * preview.scale <= settings.width - 32)
assert(preview.scale >= 1 and preview.parent.height <= 110, "Use the available width instead of a tall preview slot")
local regularPreviewHeight = preview.parent.height
assert(preview.progress.shown and not live.shown and not driver.scripts.OnUpdate)
module.OpenSettings("Emblèmes de faction")
assert(ns.revealed == frames.ArkannsQOL_flightEmblems)
local screenCheck = frames.ArkannsQOLFlightScreenPreview
combat = true
screenCheck:SetChecked(true)
screenCheck.scripts.OnClick(screenCheck)
assert(not screenCheck.checked and not frames.ArkannsQOLFlightScreenSample)
combat = false
screenCheck:SetChecked(true)
screenCheck.scripts.OnClick(screenCheck)
local screenPreview = frames.ArkannsQOLFlightScreenSample
assert(screenPreview.shown and not driver.scripts.OnUpdate and not live.shown)

local function SetRange(key, value)
    local slider = frames["ArkannsQOL_" .. key]
    slider:SetValue(slider.value + value - module.ExportSettings().appearance[key])
end
local function EnterValue(key, value)
    local input = frames["ArkannsQOL_" .. key .. "Value"]
    input:SetFocus()
    input:SetText(value)
    input.scripts.OnEnterPressed(input)
end

start = Begin()
for _, key in ipairs({"flightBeastGap", "flightBeastY", "flightEmblemY", "flightX", "flightEmblemOpacity", "flightTop"}) do
    local slider = frames["ArkannsQOL_" .. key]
    assert(slider.minimum >= 1 and slider.value >= slider.minimum, "The native thumb always has a positive position")
    local zeroPosition = slider.value - oldProfile.appearance[key]
    EnterValue(key, "0")
    assert(slider.value == zeroPosition and module.ExportSettings().appearance[key] == 0)
    SetRange(key, oldProfile.appearance[key])
end
local previewScale, timerTop = preview.scale, live.point[5] - live.height + live.panel.point[5] + live.panel.height
Choose("flightBeasts", "Hidden")
assert(not live.ornaments.left.shown and not preview.ornaments.right.shown and preview.width == 320)
Choose("flightBeasts", ns.L("Gauche"))
Choose("flightBeastAlign", "Top")
SetRange("flightBeastSize", 91)
EnterValue("flightBeastGap", "17")
local gapInput = frames.ArkannsQOL_flightBeastGapValue
gapInput:SetFocus()
gapInput:SetText("18")
gapInput:ClearFocus()
assert(live.ornaments.left.point[4] == -18, "Leaving the field must apply the typed value")
gapInput:SetFocus()
gapInput:SetText("17")
gapInput.scripts.OnTabPressed(gapInput)
assert(live.ornaments.left.point[4] == -17, "Tab must apply the typed value")
gapInput:SetFocus()
gapInput:SetText("-60")
gapInput.scripts.OnEscapePressed(gapInput)
assert(live.ornaments.left.point[4] == -17 and gapInput:GetText() == "17", "Escape must cancel editing")
gapInput:SetFocus()
SetRange("flightBeastGap", 19)
gapInput:ClearFocus()
assert(live.ornaments.left.point[4] == -19, "An untouched field must not undo a slider change")
EnterValue("flightBeastGap", "17")
local gapSlider = frames.ArkannsQOL_flightBeastGap
assert(gapSlider.template == "UISliderTemplate" and gapSlider.point[2] == -86 and gapSlider.point[3] == 9)
assert(live.ornaments.left.shown and not live.ornaments.right.shown)
assert(live.ornaments.left.height == 91 and live.height == 91 and live.panel.point[5] == 29)
assert(live.ornaments.left.point[4] == -17 and live.ornaments.left.point[5] == -29)
assert(preview.scale == previewScale, "Changing the gap must not change the preview zoom")
Choose("flightBeasts", "Both sides")
EnterValue("flightBeastGap", "-23")
assert(live.ornaments.left.point[4] == 23 and live.ornaments.right.point[4] == -23)
assert(live.ornaments.left.parent == live.panel and live.ornaments.left.sublevel == -1)
EnterValue("flightBeastGap", "0")
assert(live.ornaments.left.point[4] == 0 and live.ornaments.right.point[4] == 0)
EnterValue("flightBeastGap", "abc")
assert(live.ornaments.left.point[4] == 0 and frames.ArkannsQOL_flightBeastGapValue.text == "0")
SetRange("flightBeastY", 48)
assert(live.ornaments.left.point[5] == 19 and live.point[5] - live.height + live.panel.point[5] + live.panel.height == timerTop)
Choose("flightBeasts", ns.L("Gauche"))
Choose("flightEmblems", ns.L("Centre"))
assert(preview.emblems.left.shown and preview.emblems.left.point[1] == "CENTER" and not preview.emblems.right.shown)
Choose("flightEmblems", ns.L("Droite"))
EnterValue("flightEmblemInset", "37")
SetRange("flightEmblemSize", 41)
EnterValue("flightEmblemOpacity", "53 %")
SetRange("flightEmblemY", -13)
assert(not live.emblems.left.shown and live.emblems.right.shown and live.emblems.right.point[4] == -37)
assert(live.emblems.right.width == 41 and live.emblems.right.alpha == .53 and live.emblems.right.point[5] == -13)
SetRange("flightScale", 120)
EnterValue("flightX", "-83")
EnterValue("flightTop", "181")
assert(live.scale == 1.2 and math.abs(live.point[4] * live.scale + 83) < .00001
    and math.abs((live.point[5] - live.height + live.panel.point[5] + live.panel.height) * live.scale + 181) < .00001)
assert(screenPreview.scale == live.scale and screenPreview.point[4] == live.point[4] and screenPreview.point[5] == live.point[5])
assert(preview.parent.height > regularPreviewHeight and preview.width * preview.scale <= settings.width - 32,
    "Reserve extra height only when the configured decorations need it")

local progressCheck = frames.ArkannsQOLFlightShowProgress
progressCheck:SetChecked(false)
progressCheck.scripts.OnClick(progressCheck)
local customProfile = module.ExportSettings()
assert(not live.progress.shown and not preview.progress.shown and not customProfile.appearance.flightProgress)
Load("Core/Profiles.lua")
local profiles = ns.Profiles
assert(profiles.Save("Flight theme"))
local reset = frames.ArkannsQOLFlightResetAppearance
reset.scripts.OnClick(reset)
assert(live.progress.shown and preview.emblems.left.shown and preview.emblems.right.shown)
local plan = assert(profiles.Preview("Flight theme", {flights = true}))
assert(#plan.changes > 0 and not table.concat(plan.changes, "\n"):find("flightBeast", 1, true))
assert(profiles.Apply(plan) and not preview.progress.shown and not live.progress.shown)
assert(ForeverTooltipLibreDB.flights.appearance.flightBeasts == "left")
assert(profiles.Undo() and preview.progress.shown and live.progress.shown)
local priorAppearance = {flightBeastGap = -8, flightEmblems = "right", flightEmblemOpacity = 30}
local priorProfile = {appearance = priorAppearance, enabled = true}
module.profileMigrations[2](priorProfile)
assert(priorProfile.appearance.flightBeastGap == -8 and priorProfile.appearance.flightEmblemOpacity == 30
    and priorProfile.appearance.flightScale == 100 and priorProfile.appearance.flightBeastY == 0)
assert(module.ImportSettings(customProfile))
local legacy = {enabled = false}
module.profileMigrations[1](legacy, customProfile)
assert(module.ImportSettings(legacy) and not module.IsEnabled())
assert(module.ExportSettings().appearance.flightEmblems == "right" and not preview.progress.shown)
assert(ArkannsQOLFlightsDB[route][1] == 100 and #ArkannsQOLFlightsDB[route] == 1)
assert(module.ImportSettings(oldProfile))
Event("PLAYER_LEAVING_WORLD")
onTaxi = false
settings.scripts.OnHide()
assert(not screenPreview.shown and not screenCheck.checked)

-- Recreate the module as on another character, with both native art variants and missing APIs.
local function CheckFactionArt(faction, creature, atlasInfo)
    frames, hooks, buttons, badges = {}, {}, {}, {}
    UnitFactionGroup = faction and function() return faction end or nil
    C_Texture = atlasInfo and {GetAtlasInfo = function() return atlasInfo end} or nil
    Load("Modules/FlightTimes.lua")
    ns.InitializeFlightTimes({})
    module.SetEnabled(true)
    driver = frames.ArkannsQOLFlightEvents
    local started = Begin()
    local frame, panel = frames.ArkannsQOLFlightTimer, frames.ArkannsQOLFlightTimerPanel
    assert(frame.mouse == false and panel.mouse == false, "Flight decorations allow game clicks through")
    assert(panel.width == 320 and panel.height == 62 and panel.point[1] == "BOTTOM")
    assert(frame.ornaments.left and frame.ornaments.right, "Reuse two ornaments per flight window")
    for index, side in ipairs({"Left", "Right"}) do
        local ornament = frame.ornaments[side:lower()]
        local isLeft = side == "Left"
        assert(ornament.point[1] == (isLeft and "BOTTOMRIGHT" or "BOTTOMLEFT")
            and ornament.point[2] == panel and ornament.point[3] == (isLeft and "BOTTOMLEFT" or "BOTTOMRIGHT")
            and ornament.point[5] == 0, "Align both ornaments with the bottom edge of the panel")
        assert(frame.width / 2 >= panel.width / 2 + ornament.width - math.abs(ornament.point[4]),
            "Screen clamping includes the ornaments")
        if creature then
            assert(ornament.atlas == "UI-HUD-ActionBar-" .. creature .. "-" .. side)
            assert(ornament.height == frame.height and ornament.height >= panel.height)
            assert(math.abs(ornament.width / ornament.height - atlasInfo.width / atlasInfo.height) < .0001)
        else
            assert(ornament.texture == "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" and ornament.width == ornament.height)
        end
    end
    progress = frame.progress
    if faction == "Alliance" or faction == "Horde" then
        assert(#panel.textures == 4, "Show two beasts and one faction emblem at each edge")
        for index, edge in ipairs({"LEFT", "RIGHT"}) do
            local emblem = panel.textures[index]
            assert(emblem.texture == "Interface\\Timer\\" .. faction .. "-Logo")
            assert(emblem.point[1] == edge and emblem.point[2] == panel and emblem.point[3] == edge
                and emblem.point[4] == (edge == "LEFT" and 12 or -12) and emblem.point[5] == 0)
            assert(emblem.layer == "ARTWORK" and emblem.sublevel == -2 and emblem.alpha == .22
                and emblem.width == 60 and emblem.height == 60)
        end
    else
        assert(#panel.textures == 2, "No emblem is created without a known faction")
    end
    if faction == "Horde" then
        assert(progress.color[1] > progress.color[3], "Horde uses a red progress bar")
    elseif faction == "Alliance" then
        assert(progress.color[3] > progress.color[1], "Alliance uses a blue progress bar")
    end
    PollAt(started + 99, true)
    assert(badges[2].text == "0:01" and not badges[3].shown and progress.shown)
    PollAt(started + 100, true)
    assert(badges[2].text == "1:40" and badges[3].shown and badges[3].text == ns.L("Temps écoulé") and not progress.shown,
        "An exceeded estimate returns to elapsed time")
    module.SetEnabled(false)
    assert(not frame.shown and not driver.scripts.OnUpdate)
    module.SetEnabled(true)
    Begin()
    assert(#panel.textures == (frame.emblems.left and 4 or 2) and progress.shown and progress.value == 0,
        "Reopening resets the display without allocating more ornaments")
    module.SetEnabled(false)
end
CheckFactionArt("Alliance", "Gryphon", {width = 240, height = 140})
CheckFactionArt("Horde", "Wyvern", {width = 178, height = 167})
CheckFactionArt("Alliance", nil, {width = secret, height = 140})
CheckFactionArt("Horde", nil, nil)
CheckFactionArt(secret, nil, {width = 240, height = 140})
CheckFactionArt(nil, nil, nil)
GetLocale = function() return "frFR" end
Load("Locales/Locale.lua")
Load("Locales/enUS-Flights.lua")
CheckFactionArt("Alliance", "Gryphon", {width = 240, height = 140})
CheckFactionArt("Horde", "Wyvern", {width = 240, height = 140})

-- A fresh login after a patch receives the existing account save from WoW.
frames, hooks, buttons, badges = {}, {}, {}, {}
ForeverTooltipLibreDB = {flights = {enabled = true}}
build, rank = "70938", 0
local currentKey = "70938,0,101>303>202"
ArkannsQOLFlightsDB = {
    [route] = {100},
    ["70900,0,101>303>202"] = {110, 120, 130},
    ["70910,0,101>303>202"] = {0},
    ["70920,1,101>303>202"] = {85},
    ["70925,0,101>202"] = {90},
    ["70950,0,101>303>202"] = {150},
}
ns.FlightTimesData[currentKey] = 105
Load("Modules/FlightTimes.lua")
ns.InitializeFlightTimes({})
driver = frames.ArkannsQOLFlightEvents
Event("TAXIMAP_OPENED")
hooks.OnMouseEnter(destination)
assert(tooltipText == "Durée du trajet : 2:00",
    "Use the latest valid personal median for the same stops and speed before the shared estimate")
assert(not ArkannsQOLFlightsDB[currentKey], "An estimate must not become a measurement")

start = Begin()
PollAt(start + 115, false)
assert(ArkannsQOLFlightsDB[currentKey][1] == 115 and ArkannsQOLFlightsDB["70900,0,101>303>202"][2] == 120)
Event("TAXIMAP_OPENED")
hooks.TaxiNodeOnButtonEnter(destination)
assert(tooltipText == "Durée du trajet : 1:55", "The first measurement on the new build takes priority")

C_DurationUtil = {CreateDuration = function()
    return {SetTimeFromStart = function(self, started, estimate)
        self.started, self.estimate = started, estimate
    end}
end}
function methods:SetTimerDuration(timer)
    assert(not self.timer, "Bind the timer only once per flight")
    self.timer = timer
end
start = Begin()
progress = frames.ArkannsQOLFlightTimer.progress
local timer = assert(progress.timer)
assert(timer.started == start and timer.estimate == 115 and progress.shown)
PollAt(start + 1.5, true)
assert(progress.timer == timer and badges[2].text == "1:54", "Text updates leave the native timer running")
hooks.TaxiRequestEarlyLanding()
PollAt(start + 1.7, true)
assert(not progress.timer and not progress.shown, "An early landing releases the timer")
PollAt(start + 10, false)
start = Begin()
assert(progress.timer and progress.timer.started == start and progress.timer ~= timer)
PollAt(start + 103, false)
assert(not progress.timer and not frames.ArkannsQOLFlightTimer.shown, "Landing releases the timer")
Event("TAXIMAP_OPENED")
hooks.OnMouseEnter(destination)
assert(tooltipText == "Durée du trajet : 1:49", "A new flight measurement updates the displayed median")

print("PASS: flight timing, saved estimates across builds, route isolation, export, profiles, and FR/EN display lifecycle")
