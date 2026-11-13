local _, ns = ...
local L, UI, WoW = ns.L, ns.UI, ns.WoW
local moduleID = "flights"
local title = L("Temps de vol")
local toggleLabel = L("Chronométrer les vols")
local exportLabel = L("Exporter les durées")
local minSeconds, maxSeconds = 5, 1800
local maxLegs = 31
local frequentFlierNode = 110300
local events = {"TAXIMAP_OPENED", "TAXIMAP_CLOSED", "ADDON_LOADED", "PLAYER_LEAVING_WORLD", "PLAYER_DEAD", "PLAYER_LOGOUT"}
local driver, config, records, category, check, badge, badgeTitle, badgeTime, badgeCaption, badgeProgress
local mapOpen, closedAt, nodes, origin, routes
local pending, flight
local takeoffHook, earlyLandingHook, taxiTooltipHook, flightMapTooltipHook

local function IsID(value)
    return WoW.IsFiniteNumber(value) and value >= 1 and value <= 2147483647 and value % 1 == 0
end

local function IsSeconds(value)
    return WoW.IsFiniteNumber(value) and value >= minSeconds and value <= maxSeconds and value % 1 == 0
end

local function GetBuild()
    local state, _, build, _, interface = WoW.Read(GetBuildInfo)
    if state ~= "ok" or interface ~= 16001 then return end
    local number = type(build) == "string" and tonumber(build) or build
    if IsID(number) then return number end
end

local function GetSpeed()
    local legacy = Constants and Constants.LegacyConsts
    local tree = legacy and legacy.LEGACY_TREE_ADVENTURE_ID
    if not IsID(tree) or not C_Traits then return end
    local state, configID = WoW.Read(C_Traits.GetConfigIDByTreeID, tree)
    if state ~= "ok" then return end
    if configID == nil then return 0 end
    if not IsID(configID) then return end
    local node = WoW.ReadValue(C_Traits.GetNodeInfo, configID, frequentFlierNode)
    local rank = type(node) == "table" and node.activeRank
    if WoW.IsFiniteNumber(rank) and rank >= 0 and rank % 1 == 0 then
        return rank > 0 and 1 or 0
    end
end

local function SampleMedian(samples)
    if type(samples) ~= "table" then return end
    local sorted = {}
    for _, seconds in ipairs(samples) do
        if IsSeconds(seconds) then sorted[#sorted + 1] = seconds end
    end
    if #sorted == 0 then return end
    table.sort(sorted)
    local middle = math.floor((#sorted + 1) / 2)
    if #sorted % 2 == 1 then return sorted[middle] end
    return math.floor((sorted[middle] + sorted[middle + 1]) / 2 + .5)
end

local function Remember(key, seconds)
    if not key or not IsSeconds(seconds) then return end
    local samples = records[key]
    if type(samples) ~= "table" then samples = {}; records[key] = samples end
    while #samples >= 5 do table.remove(samples, 1) end
    samples[#samples + 1] = seconds
end

local function Estimate(key)
    if not key then return end
    local personal = SampleMedian(records[key])
    if personal then return personal, "Durée mesurée · %s" end

    local build, routeAndSpeed = key:match("^(%d+),(.+)$")
    build = tonumber(build)
    local latestBuild, previous = 0, nil
    for savedKey, samples in pairs(records) do
        if type(savedKey) == "string" then
            local savedBuild, savedRouteAndSpeed = savedKey:match("^(%d+),(.+)$")
            savedBuild = tonumber(savedBuild)
            if savedRouteAndSpeed == routeAndSpeed and savedBuild and savedBuild > latestBuild and savedBuild < build then
                local seconds = SampleMedian(samples)
                if seconds then latestBuild, previous = savedBuild, seconds end
            end
        end
    end
    if previous then return previous, "Ancienne mesure · %s" end

    local community = ns.FlightTimesData[key]
    if IsSeconds(community) then return community, "Durée partagée · %s" end
end

local function DurationText(seconds)
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function ResetMap()
    mapOpen, closedAt, nodes, origin, routes = false, nil, nil, nil, {}
end

local function ReadTaxiMap()
    local mapID = WoW.ReadValue(GetTaxiMapID)
    if not IsID(mapID) then return end
    local taxiNodes = WoW.ReadValue(C_TaxiMap and C_TaxiMap.GetAllTaxiNodes, mapID)
    local states = Enum and Enum.FlightPathState
    if type(taxiNodes) ~= "table" or not states then return end
    local bySlot, source = {}, nil
    for _, node in ipairs(taxiNodes) do
        if WoW.IsPublic(node) and type(node) == "table" and IsID(node.slotIndex) and IsID(node.nodeID)
            and WoW.IsPublic(node.state) and WoW.IsPublic(node.isMapLayerTransition) and not node.isMapLayerTransition then
            bySlot[node.slotIndex] = node
            if node.state == states.Current then source = node end
        end
    end
    if source then nodes, origin = bySlot, source end
end

local function ReadRoute(slot)
    if not IsID(slot) then return end
    if routes[slot] then return routes[slot] end
    if not nodes then ReadTaxiMap() end
    local destination = nodes and nodes[slot]
    if not destination or destination.state ~= Enum.FlightPathState.Reachable or destination.nodeID == origin.nodeID then return end
    local legs = WoW.ReadValue(GetNumRoutes, slot)
    if not IsID(legs) or legs > maxLegs then return end

    local path, previous = {origin.nodeID}, origin
    local visited = {[origin.nodeID] = true}
    for index = 1, legs do
        local fromSlot = WoW.ReadValue(TaxiGetNodeSlot, slot, index, true)
        local toSlot = WoW.ReadValue(TaxiGetNodeSlot, slot, index, false)
        local target = IsID(toSlot) and nodes[toSlot]
        if fromSlot ~= previous.slotIndex or not target or visited[target.nodeID] then return end
        path[#path + 1] = target.nodeID
        visited[target.nodeID] = true
        previous = target
    end
    if previous.nodeID ~= destination.nodeID then return end
    local name = WoW.IsPublic(destination.name) and type(destination.name) == "string" and destination.name or nil
    local route = {path = table.concat(path, ">"), name = name}
    routes[slot] = route
    return route
end

local function RouteKey(route)
    if not route then return end
    local build, speed = GetBuild(), GetSpeed()
    if build and speed ~= nil then return ("%d,%d,%s"):format(build, speed, route.path) end
end

local function AddTaxiTooltip(owner, slot)
    if not config.enabled or not mapOpen then return end
    local route = ReadRoute(slot)
    if not route or not GameTooltip or WoW.ReadValue(InCombatLockdown) ~= false
        or WoW.ReadValue(GameTooltip.IsForbidden, GameTooltip) ~= false
        or WoW.ReadValue(GameTooltip.GetOwner, GameTooltip) ~= owner then return end
    local key = RouteKey(route)
    if not key then return end
    local seconds, label = Estimate(key)
    local text = seconds and L(label):format(DurationText(seconds)) or L("Durée inconnue")
    GameTooltip:AddLine(text, 1, .82, 0, true)
    GameTooltip:Show()
end

local function CreateBadge()
    local panelWidth, panelHeight, ornamentHeight = 320, 62, 68
    local overlap, maxOrnamentWidth = 8, 0
    badge = CreateFrame("Frame", "ArkannsQOLFlightTimer", UIParent)
    badge:SetPoint("TOP", UIParent, "TOP", 0, -100)
    badge:SetClampedToScreen(true)
    badge:EnableMouse(false)

    local panel = CreateFrame("Frame", "ArkannsQOLFlightTimerPanel", badge, "BackdropTemplate")
    panel:SetSize(panelWidth, panelHeight)
    panel:SetPoint("BOTTOM")
    panel:EnableMouse(false)
    UI.StylePanel(panel)

    local faction = WoW.ReadValue(UnitFactionGroup, "player")
    local red, green, blue = .85, .65, .3
    local creature
    if faction == "Horde" then
        red, green, blue, creature = .85, .22, .16, "Wyvern"
    elseif faction == "Alliance" then
        red, green, blue, creature = .22, .52, .95, "Gryphon"
    end

    if creature then
        local texture = ("Interface\\Timer\\%s-Logo"):format(faction)
        local size = panelHeight - 2
        for _, edge in ipairs({"LEFT", "RIGHT"}) do
            local emblem = panel:CreateTexture(nil, "ARTWORK", nil, -1)
            emblem:SetTexture(texture)
            emblem:SetSize(size, size)
            emblem:SetPoint(edge, panel, edge, edge == "LEFT" and 12 or -12, 0)
            emblem:SetAlpha(.22)
        end
    end

    -- Native end caps, Forever 4cd0ab7. Read atlas dimensions for the client's art variant.
    for _, side in ipairs({"Left", "Right"}) do
        local ornament = badge:CreateTexture(nil, "ARTWORK")
        local atlas = creature and ("UI-HUD-ActionBar-%s-%s"):format(creature, side)
        local info = atlas and C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, atlas)
        local width, height = 32, 32
        if type(info) == "table" and WoW.IsFiniteNumber(info.width) and info.width > 0
            and WoW.IsFiniteNumber(info.height) and info.height > 0 then
            ornament:SetAtlas(atlas, false)
            width, height = ornamentHeight * info.width / info.height, ornamentHeight
        else
            ornament:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
        end
        ornament:SetSize(width, height)
        maxOrnamentWidth = math.max(maxOrnamentWidth, width)
        if side == "Left" then
            ornament:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", overlap, 0)
        else
            ornament:SetPoint("BOTTOMLEFT", panel, "BOTTOMRIGHT", -overlap, 0)
        end
    end
    badge:SetSize(panelWidth + 2 * (maxOrnamentWidth - overlap), ornamentHeight)

    local accent = panel:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(red, green, blue, .9)
    accent:SetSize(80, 2)
    accent:SetPoint("TOP", 0, -3)
    badgeTitle = UI.Label(panel, "", 18, -6, 14)
    badgeTime = UI.Label(panel, "", 18, -22, 22)
    badgeCaption = UI.Label(panel, "", 18, -44, 10)
    for _, label in ipairs({badgeTitle, badgeTime, badgeCaption}) do
        label:SetWidth(284)
        label:SetWordWrap(false)
        label:SetJustifyH("CENTER")
    end
    badgeProgress = CreateFrame("StatusBar", "ArkannsQOLFlightProgress", panel)
    badgeProgress:SetPoint("BOTTOMLEFT", 18, 5)
    badgeProgress:SetSize(284, 3)
    badgeProgress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    badgeProgress:SetStatusBarColor(red, green, blue)
    badgeProgress:SetMinMaxValues(0, 1)
    local track = badgeProgress:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(red, green, blue, .2)
end

local function ShowTime(elapsed)
    if not badge then CreateBadge() end
    if not badge:IsShown() or flight.lastSecond == nil then
        badgeTitle:SetText(flight.name or L("En vol"))
        badge:Show()
    end
    local seconds = math.floor(elapsed)
    if flight.lastSecond == seconds then return end
    flight.lastSecond = seconds
    if flight.estimate and seconds < flight.estimate then
        badgeTime:SetText(DurationText(flight.estimate - seconds))
        badgeCaption:Hide()
        badgeProgress:SetValue(math.min(1, elapsed / flight.estimate))
        badgeProgress:Show()
    else
        badgeTime:SetText(DurationText(seconds))
        badgeCaption:SetText(L(flight.interrupted and "Escale demandée" or "Temps écoulé"))
        badgeCaption:Show()
        badgeProgress:Hide()
    end
end

local function Stop()
    pending, flight = nil, nil
    driver:SetScript("OnUpdate", nil)
    if badge then badge:Hide() end
end

local function Poll()
    local now = WoW.ReadValue(GetTime)
    local onTaxi = WoW.ReadValue(UnitOnTaxi, "player")
    if not WoW.IsFiniteNumber(now) or type(onTaxi) ~= "boolean" then Stop(); return end

    if pending then
        if now - pending.selected > 5 then Stop(); return end
        if not onTaxi then return end
        flight, pending = pending, nil
        flight.started = now
    end
    if not flight then Stop(); return end

    local elapsed = now - flight.started
    if elapsed < 0 or elapsed > maxSeconds then Stop(); return end
    if not onTaxi then
        if not flight.interrupted then Remember(flight.key, math.floor(elapsed + .5)) end
        Stop()
        return
    end
    ShowTime(elapsed)
end

local function ObserveTakeoff(slot)
    if not config.enabled or flight then return end
    local now = WoW.ReadValue(GetTime)
    if not WoW.IsFiniteNumber(now)
        or (not mapOpen and (not WoW.IsFiniteNumber(closedAt) or now - closedAt > 1)) then return end
    local route = ReadRoute(slot)
    local key = RouteKey(route)
    pending = {selected = now, key = earlyLandingHook and key or nil, estimate = Estimate(key), name = route and route.name}
    local sincePoll = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        sincePoll = sincePoll + elapsed
        if sincePoll < .2 then return end
        sincePoll = 0
        Poll()
    end)
    Poll()
end

local function InstallHooks()
    if not takeoffHook and type(TakeTaxiNode) == "function" then
        takeoffHook = WoW.Read(hooksecurefunc, "TakeTaxiNode", ObserveTakeoff) == "ok"
    end
    if not earlyLandingHook and type(TaxiRequestEarlyLanding) == "function" then
        earlyLandingHook = WoW.Read(hooksecurefunc, "TaxiRequestEarlyLanding", function()
            local current = flight or pending
            if not current then return end
            current.interrupted, current.estimate, current.lastSecond = true, nil, nil
        end) == "ok"
    end
    if not taxiTooltipHook and type(TaxiNodeOnButtonEnter) == "function" then
        taxiTooltipHook = WoW.Read(hooksecurefunc, "TaxiNodeOnButtonEnter", function(button)
            if not config.enabled or not mapOpen then return end
            AddTaxiTooltip(button, WoW.ReadValue(button.GetID, button))
        end) == "ok"
    end
    local pin = FlightMap_FlightPointPinMixin
    if not flightMapTooltipHook and pin and type(pin.OnMouseEnter) == "function" then
        flightMapTooltipHook = WoW.Read(hooksecurefunc, pin, "OnMouseEnter", function(owner)
            if config.enabled and mapOpen and WoW.IsPublic(owner.isMapLayerTransition) and not owner.isMapLayerTransition
                and WoW.IsPublic(owner.taxiNodeData) and type(owner.taxiNodeData) == "table" then
                AddTaxiTooltip(owner, owner.taxiNodeData.slotIndex)
            end
        end) == "ok"
    end
end

local function OnEvent(_, event, addon)
    if event == "TAXIMAP_OPENED" then
        ResetMap()
        mapOpen = true
        InstallHooks()
        ReadTaxiMap()
    elseif event == "TAXIMAP_CLOSED" then
        mapOpen, closedAt = false, WoW.ReadValue(GetTime)
    elseif event == "ADDON_LOADED" then
        if addon == "Blizzard_FlightMap" then InstallHooks() end
    else
        Stop()
        ResetMap()
    end
end

local function SetEnabled(enabled)
    config.enabled = enabled == true
    if check then check:SetChecked(config.enabled) end
    driver:UnregisterAllEvents()
    Stop()
    ResetMap()
    if not config.enabled then return end
    for _, event in ipairs(events) do driver:RegisterEvent(event) end
    InstallHooks()
    if (TaxiFrame and WoW.ReadValue(TaxiFrame.IsShown, TaxiFrame) == true)
        or (FlightMapFrame and WoW.ReadValue(FlightMapFrame.IsShown, FlightMapFrame) == true) then
        OnEvent(driver, "TAXIMAP_OPENED")
    end
end

local function ExportLines()
    local lines = {}
    for key, samples in pairs(records) do
        if type(key) == "string" and key:match("^%d+,[01],%d[%d>]+%d$") then
            local seconds = SampleMedian(samples)
            if seconds then lines[#lines + 1] = key .. "," .. seconds end
        end
    end
    table.sort(lines)
    return lines
end

local function RegisterSettings(root)
    local panel = CreateFrame("Frame", "ArkannsQOLFlightSettings", UIParent, "BackdropTemplate")
    panel:Hide()
    UI.StylePanel(panel)
    UI.Label(panel, title, 16, -16, 18)
    check = UI.Check(panel, "ArkannsQOLFlightsEnabled", toggleLabel, 12, -44, SetEnabled)
    local description = UI.Label(panel, L("Affiche la durée des trajets et le temps restant en vol."), 16, 0)
    description:ClearAllPoints()
    description:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 4, -4)
    description:SetWordWrap(true)

    local help = UI.Label(panel, "", 16, 0)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 16)
    scroll:Hide()
    local output = CreateFrame("EditBox", "ArkannsQOLFlightExport", scroll)
    output:SetSize(1, 1)
    output:SetMultiLine(true)
    output:SetAutoFocus(false)
    output:SetFontObject(GameFontHighlightSmall)
    output:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(output)
    scroll:SetScript("OnSizeChanged", function(_, width) output:SetWidth(math.max(1, width - 4)) end)

    local export = UI.Button(panel, nil, exportLabel, 16, 0, 215, function()
        local lines = ExportLines()
        if #lines == 0 then
            help:SetText(L("Aucun vol complet à exporter."))
            scroll:Hide()
            return
        end
        help:SetText(L("Ctrl+C pour copier les trajets et leurs durées."))
        scroll:Show()
        output:SetWidth(math.max(1, scroll:GetWidth() - 4))
        output:SetText("QTF1\n" .. table.concat(lines, "\n"))
        local lineCount = WoW.ReadValue(output.GetNumLines, output)
        if not WoW.IsFiniteNumber(lineCount) or lineCount < 1 then lineCount = #lines + 1 end
        output:SetHeight(math.max(scroll:GetHeight(), lineCount * 17))
        output:SetFocus()
        output:HighlightText()
        scroll:SetVerticalScroll(0)
    end)
    export:ClearAllPoints()
    export:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -14)
    help:ClearAllPoints()
    help:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -9)
    help:SetWordWrap(true)
    local function Resize(_, width)
        description:SetWidth(math.max(1, width - 32))
        help:SetWidth(math.max(1, width - 32))
    end
    panel:SetScript("OnSizeChanged", Resize)
    panel:SetScript("OnShow", function()
        check:SetChecked(config.enabled)
        Resize(panel, panel:GetWidth())
    end)
    panel:SetScript("OnHide", function()
        output:ClearFocus()
        output:SetText("")
        help:SetText("")
        scroll:Hide()
    end)
    category = UI.RegisterSettingsPanel(root, panel, title, "flights")
end

function ns.InitializeFlightTimes(root)
    local db = ForeverTooltipLibreDB
    if type(db.flights) ~= "table" then db.flights = {} end
    config = db.flights
    if type(ArkannsQOLFlightsDB) ~= "table" then ArkannsQOLFlightsDB = {} end
    records = ArkannsQOLFlightsDB
    driver = CreateFrame("Frame", "ArkannsQOLFlightEvents")
    driver:SetScript("OnEvent", OnEvent)
    if root and Settings and Settings.RegisterCanvasLayoutSubcategory then RegisterSettings(root) end
    SetEnabled(config.enabled ~= false)
    ns.RegisterModule(moduleID, {
        label = title,
        icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
        category = function() return category end,
        Summary = function() return L("Affiche la durée des trajets et le temps restant en vol.") end,
        toggleLabel = toggleLabel,
        IsEnabled = function() return config.enabled end,
        SetEnabled = SetEnabled,
        ExportSettings = function() return {enabled = config.enabled} end,
        ImportSettings = function(value)
            if type(value) ~= "table" or type(value.enabled) ~= "boolean" then return false end
            if value.enabled ~= config.enabled then SetEnabled(value.enabled) end
            return true
        end,
    })
end
