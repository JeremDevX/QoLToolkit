local frames, hooks, buttons, badges = {}, {}, {}, {}
local noop = function() end
local methods = {}
for _, name in ipairs({"SetPoint", "ClearAllPoints", "SetClampedToScreen", "SetWordWrap", "SetMultiLine",
    "SetAutoFocus", "SetFontObject", "SetScrollChild", "SetVerticalScroll", "ClearFocus"}) do
    methods[name] = noop
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

CreateFrame = function(_, name)
    local frame = setmetatable({scripts = {}, events = {}, width = 360, height = 240, shown = true}, {__index = methods})
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
        if parent == frames.ArkannsQOLFlightTimer then badges[#badges + 1] = frame end
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
buttons["Export my flight times"]()
assert(not frames.ArkannsQOLFlightExport.selected, "An empty export does not expose copyable data")
Event("TAXIMAP_OPENED")
hooks.TaxiNodeOnButtonEnter(destination)
assert(tooltipText == "Community estimate · ≈ 1:42")
combat, tooltipText = true, nil
hooks.OnMouseEnter(destination)
assert(not tooltipText, "The native tooltip is untouched in combat")
combat = false
Event("TAXIMAP_CLOSED")
canReadRoute = false
hooks.TakeTaxiNode(3)
PollAt(2, true)
assert(badges[1].text == "Destination" and badges[2].text == "Estimated time remaining · 1:42")
PollAt(62, true)
assert(badges[2].text == "Estimated time remaining · 0:42")
PollAt(102, false)
assert(ArkannsQOLFlightsDB[route][1] == 100 and not driver.scripts.OnUpdate and not frames.ArkannsQOLFlightTimer.shown)

canReadRoute = true
Event("TAXIMAP_OPENED")
hooks.OnMouseEnter(destination)
assert(tooltipText == "Measured time · 1:40", "Personal measurements have priority")
local start = Begin()
hooks.TaxiRequestEarlyLanding()
PollAt(start + 25, true)
assert(badges[2].text == "Elapsed time · 0:25")
PollAt(start + 26, false)
assert(#ArkannsQOLFlightsDB[route] == 1)

rank = 1
start = Begin()
assert(badges[2].text == "Elapsed time · 0:00")
PollAt(start + 82, false)
assert(ArkannsQOLFlightsDB["70888,1,101>303>202"][1] == 82)

rank, chain = 0, {1, 3}
start = Begin()
PollAt(start + 75, false)
assert(ArkannsQOLFlightsDB["70888,0,101>202"][1] == 75, "Different stop sequences remain distinct")

build, chain = "70999", {1, 2, 3}
start = Begin()
assert(badges[2].text == "Elapsed time · 0:00", "A different build must not reuse the community value")
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
assert(badges[1].text == "Flight in progress")
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

buttons["Export my flight times"]()
local output = frames.ArkannsQOLFlightExport
assert(output.focus and output.selected)
assert(output.text == "QTF1\n70888,0,101>202,75\n70888,0,101>303>202,100\n70888,1,101>303>202,82")
module.category().panel.scripts.OnHide()
assert(output.text == "")
print("PASS: taxi state, tooltip, route and speed isolation, rejected samples, account export, and profiles")
