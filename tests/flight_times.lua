local frames, hooks, buttons, badges = {}, {}, {}, {}
local noop = function() end
local methods = {}
for _, name in ipairs({"ClearAllPoints", "SetClampedToScreen", "SetWordWrap", "SetMultiLine", "SetJustifyH", "SetAllPoints",
    "SetAutoFocus", "SetFontObject", "SetScrollChild", "SetVerticalScroll", "ClearFocus"}) do
    methods[name] = noop
end
function methods:SetPoint(...) self.point = {...} end
function methods:EnableMouse(enabled) self.mouse = enabled end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetAtlas(atlas) self.atlas = atlas end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetStatusBarTexture(texture) self.texture = texture end
function methods:SetStatusBarColor(...) self.color = {...} end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetValue(value) self.value = value end
function methods:CreateTexture(_, layer)
    local texture = CreateFrame("Texture", nil, self)
    texture.layer = layer
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
function methods:SetChecked(value) self.checked = value end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetFocus() self.focus = true end
function methods:HighlightText() self.selected = true end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterAllEvents() self.events = {} end

CreateFrame = function(kind, name, parent)
    local frame = setmetatable({scripts = {}, events = {}, textures = {}, kind = kind, parent = parent,
        width = 360, height = 240, shown = true}, {__index = methods})
    if name then frames[name] = frame end
    return frame
end
Settings = {RegisterCanvasLayoutSubcategory = function(_, panel, label) return {panel = panel, label = label} end}
local module
local ns = {RegisterModule = function(id, descriptor) assert(id == "flights"); module = descriptor end}
ns.UI = {
    RegisterSettingsPanel = Settings.RegisterCanvasLayoutSubcategory,
    StylePanel = noop,
    Label = function(parent, text)
        local frame = CreateFrame("FontString")
        frame:SetText(text)
        if parent == frames.ArkannsQOLFlightTimerPanel then badges[#badges + 1] = frame end
        return frame
    end,
    Button = function(_, _, label, _, _, _, callback) buttons[label] = callback; return CreateFrame("Button") end,
    Check = function(_, name) return CreateFrame("CheckButton", name) end,
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
assert(tooltipText == "Shared duration · ≈ 1:42")
combat, tooltipText = true, nil
hooks.OnMouseEnter(destination)
assert(not tooltipText, "The native tooltip is untouched in combat")
combat = false
Event("TAXIMAP_CLOSED")
canReadRoute = false
hooks.TakeTaxiNode(3)
PollAt(2, true)
assert(badges[1].text == "Destination" and badges[2].text == "≈ 1:42" and badges[3].text == "Estimated arrival")
local progress = frames.ArkannsQOLFlightProgress
assert(progress.shown and progress.minimum == 0 and progress.maximum == 1 and progress.value == 0)
PollAt(62, true)
assert(badges[2].text == "≈ 0:42" and math.abs(progress.value - 60 / 102) < .0001)
PollAt(102, false)
assert(ArkannsQOLFlightsDB[route][1] == 100 and not driver.scripts.OnUpdate and not frames.ArkannsQOLFlightTimer.shown)

canReadRoute = true
Event("TAXIMAP_OPENED")
hooks.OnMouseEnter(destination)
assert(tooltipText == "Measured duration · 1:40", "Personal measurements have priority")
local start = Begin()
hooks.TaxiRequestEarlyLanding()
PollAt(start + 25, true)
assert(badges[2].text == "0:25" and badges[3].text == "Landing requested" and not progress.shown)
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
assert(tooltipText == "Past measurement · ≈ 1:40")
start = Begin()
assert(badges[2].text == "≈ 1:40" and badges[3].text == "Estimated arrival",
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
    assert(frame.width == 512 and panel.width == 320 and panel.height == 104)
    assert(#frame.textures == 2, "Reuse two ornaments per flight window")
    for index, side in ipairs({"Left", "Right"}) do
        local ornament = frame.textures[index]
        assert(ornament.point[2] == panel and ornament.width <= 96 and ornament.height <= 84)
        if creature then
            assert(ornament.atlas == "UI-HUD-ActionBar-" .. creature .. "-" .. side)
            assert(math.abs(ornament.width / ornament.height - atlasInfo.width / atlasInfo.height) < .0001)
        else
            assert(ornament.texture == "Interface\\TaxiFrame\\UI-Taxi-Icon-Green" and ornament.width == ornament.height)
        end
    end
    progress = frames.ArkannsQOLFlightProgress
    if faction == "Horde" then
        assert(progress.color[1] > progress.color[3], "Horde uses a red accent")
    elseif faction == "Alliance" then
        assert(progress.color[3] > progress.color[1], "Alliance uses a blue accent")
    end
    PollAt(started + 99, true)
    assert(badges[2].text == "≈ 0:01" and progress.shown)
    PollAt(started + 100, true)
    assert(badges[2].text == "1:40" and badges[3].text == ns.L("Temps écoulé") and not progress.shown,
        "An exceeded estimate returns to elapsed time")
    module.SetEnabled(false)
    assert(not frame.shown and not driver.scripts.OnUpdate)
    module.SetEnabled(true)
    Begin()
    assert(#frame.textures == 2 and progress.shown and progress.value == 0,
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
assert(tooltipText == "Ancienne mesure · ≈ 2:00",
    "Use the latest valid personal median for the same stops and speed before the shared estimate")
assert(not ArkannsQOLFlightsDB[currentKey], "An estimate must not become a measurement")

start = Begin()
PollAt(start + 115, false)
assert(ArkannsQOLFlightsDB[currentKey][1] == 115 and ArkannsQOLFlightsDB["70900,0,101>303>202"][2] == 120)
Event("TAXIMAP_OPENED")
hooks.TaxiNodeOnButtonEnter(destination)
assert(tooltipText == "Durée mesurée · 1:55", "The first measurement on the new build takes priority")
print("PASS: flight timing, saved estimates across builds, route isolation, export, profiles, and FR/EN display lifecycle")
