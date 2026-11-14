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
local driver, config, records, category, check, badge, refreshSettings, openSetting, stopPreview
local mapOpen, closedAt, nodes, origin, routes
local pending, flight
local takeoffHook, earlyLandingHook, taxiTooltipHook, flightMapTooltipHook
local panelWidth, panelHeight = 320, 62
local maxBeastSize, maxBeastGap = 120, 100
local maxBeastY = 60
local progressLabel = "Afficher la barre de progression"
local resetLabel = "Rétablir l’apparence du minuteur"
local screenPositionLabel = "Voir la position à l’écran"
local sides = {{"both", "Des deux côtés"}, {"left", "Gauche"}, {"right", "Droite"}, {"none", "Masqués"}}
local beastChoices = {
    {"flightBeasts", "Bêtes de vol", "both", sides},
    {"flightBeastAlign", "Alignement des bêtes", "bottom", {{"bottom", "En bas"}, {"middle", "Au milieu"}, {"top", "En haut"}}},
    {"flightBeastSize", "Taille des bêtes", 68, 24, maxBeastSize},
    {"flightBeastGap", "Écart des bêtes", -8, -64, maxBeastGap},
    {"flightBeastY", "Décalage vertical des bêtes", 0, -maxBeastY, maxBeastY},
}
local emblemChoices = {
    {"flightEmblems", "Emblèmes de faction", "both", {sides[1], sides[2], {"center", "Centre"}, sides[3], sides[4]}},
    {"flightEmblemInset", "Marge des emblèmes", 12, 0, 130},
    {"flightEmblemY", "Décalage vertical des emblèmes", 0, -50, 50},
    {"flightEmblemSize", "Taille des emblèmes", 60, 16, 100},
    {"flightEmblemOpacity", "Opacité des emblèmes", 22, 0, 100, "%"},
}
local timerChoices = {
    {"flightScale", "Échelle du minuteur", 100, 60, 150, "%"},
    {"flightX", "Décalage horizontal du minuteur", 0, -400, 400},
    {"flightTop", "Distance du minuteur au haut de l’écran", 106, 0, 600},
}
local appearanceGroups = {
    {"Bêtes de vol", beastChoices},
    {"Emblèmes de faction", emblemChoices},
    {"Minuteur", timerChoices},
}

local function Numeric(value, minimum, maximum)
    if WoW.IsFiniteNumber(value) then
        return math.max(minimum, math.min(maximum, math.floor(value + .5)))
    end
end

local function AppearanceLabel(choice, value)
    local options, unit = choice[4], choice[6]
    if type(options) == "table" then
        for _, option in ipairs(options) do
            if option[1] == value then return L(option[2]) end
        end
    end
    return tostring(value) .. (unit and " " .. unit or "")
end

local function Appearance(value)
    local source = type(value) == "table" and value or {}
    local result = {flightProgress = source.flightProgress ~= false}
    for _, group in ipairs(appearanceGroups) do
        for _, choice in ipairs(group[2]) do
            local key, _, default, options, maximum = unpack(choice)
            if type(options) == "table" then
                result[key] = default
                for _, option in ipairs(options) do
                    if source[key] == option[1] then result[key] = option[1]; break end
                end
            else
                result[key] = Numeric(source[key], options, maximum) or default
            end
        end
    end
    return result
end

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

local function LayoutBadge(view, onScreen)
    local style = config.appearance
    local minY, maxY, reach = 0, panelHeight, panelWidth / 2
    for _, side in ipairs({"left", "right"}) do
        local left = side == "left"
        local ornament = view.ornaments[side]
        local show = style.flightBeasts == "both" or style.flightBeasts == side
        ornament:SetShown(show)
        if show then
            local height = ornament.aspect and style.flightBeastSize or 32 * style.flightBeastSize / 68
            local width = height * (ornament.aspect or 1)
            local align = style.flightBeastAlign == "top" and 1 or style.flightBeastAlign == "middle" and .5 or 0
            local y = (panelHeight - height) * align + style.flightBeastY
            ornament:SetSize(width, height)
            ornament:ClearAllPoints()
            ornament:SetPoint(left and "BOTTOMRIGHT" or "BOTTOMLEFT", view.panel, left and "BOTTOMLEFT" or "BOTTOMRIGHT",
                (left and -1 or 1) * style.flightBeastGap, y)
            minY, maxY = math.min(minY, y), math.max(maxY, y + height)
            reach = math.max(reach, panelWidth / 2 + width + style.flightBeastGap)
        end
        local emblem = view.emblems[side]
        if emblem then
            local center = left and style.flightEmblems == "center"
            local anchor = center and "CENTER" or left and "LEFT" or "RIGHT"
            local shown = center or style.flightEmblems == "both" or style.flightEmblems == side
            local size, y = style.flightEmblemSize, style.flightEmblemY
            emblem:SetShown(shown)
            emblem:SetSize(size, size)
            emblem:SetAlpha(style.flightEmblemOpacity / 100)
            emblem:ClearAllPoints()
            emblem:SetPoint(anchor, view.panel, anchor, center and 0 or (left and 1 or -1) * style.flightEmblemInset, y)
            if shown then
                local middle = panelHeight / 2 + y
                minY, maxY = math.min(minY, middle - size / 2), math.max(maxY, middle + size / 2)
            end
        end
    end
    view.panel:ClearAllPoints()
    view.panel:SetPoint("BOTTOM", view, "BOTTOM", 0, -minY)
    view:SetSize(reach * 2, maxY - minY)
    view.progress:SetShown(view.countingDown and style.flightProgress or false)
    if onScreen then
        local scale = style.flightScale / 100
        view:SetScale(scale)
        view:ClearAllPoints()
        view:SetPoint("TOP", UIParent, "TOP", style.flightX / scale, -style.flightTop / scale + maxY - panelHeight)
    end
    return (minY + maxY - panelHeight) / 2
end

local function CreateBadge(parent, name)
    local view = CreateFrame("Frame", name, parent)
    view:EnableMouse(false)
    view.ornaments, view.emblems = {}, {}
    local panel = CreateFrame("Frame", name .. "Panel", view, "BackdropTemplate")
    view.panel = panel
    panel:SetSize(panelWidth, panelHeight)
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
        for _, side in ipairs({"left", "right"}) do
            local emblem = panel:CreateTexture(nil, "ARTWORK", nil, -2)
            emblem:SetTexture(texture)
            view.emblems[side] = emblem
        end
    end

    -- Native end caps, Forever 4cd0ab7. Read atlas dimensions for the client's art variant.
    for _, side in ipairs({"Left", "Right"}) do
        local ornament = panel:CreateTexture(nil, "ARTWORK", nil, -1)
        view.ornaments[side:lower()] = ornament
        local atlas = creature and ("UI-HUD-ActionBar-%s-%s"):format(creature, side)
        local info = atlas and C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, atlas)
        if type(info) == "table" and WoW.IsFiniteNumber(info.width) and info.width > 0
            and WoW.IsFiniteNumber(info.height) and info.height > 0 then
            ornament:SetAtlas(atlas, false)
            ornament.aspect = info.width / info.height
        else
            ornament:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Green")
        end
    end

    view.title = UI.Label(panel, "", 18, -6, 14)
    view.time = UI.Label(panel, "", 18, -22, 22)
    view.caption = UI.Label(panel, "", 18, -44, 10)
    for _, label in ipairs({view.title, view.time, view.caption}) do
        label:SetWidth(284)
        label:SetWordWrap(false)
        label:SetJustifyH("CENTER")
    end
    local progress = CreateFrame("StatusBar", nil, panel)
    view.progress = progress
    progress:SetPoint("BOTTOMLEFT", 18, 5)
    progress:SetSize(284, 3)
    progress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progress:SetStatusBarColor(red, green, blue)
    progress:SetMinMaxValues(0, 1)
    local track = progress:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(red, green, blue, .2)
    return view
end

local function ShowTime(elapsed)
    if not badge then
        badge = CreateBadge(UIParent, "ArkannsQOLFlightTimer")
        badge:SetClampedToScreen(true)
        LayoutBadge(badge, true)
    end
    if not badge:IsShown() or flight.lastSecond == nil then
        badge.title:SetText(flight.name or L("En vol"))
        badge:Show()
    end
    local seconds = math.floor(elapsed)
    if flight.lastSecond == seconds then return end
    flight.lastSecond = seconds
    badge.countingDown = flight.estimate and seconds < flight.estimate
    if badge.countingDown then
        badge.time:SetText(DurationText(flight.estimate - seconds))
        badge.caption:Hide()
        badge.progress:SetValue(math.min(1, elapsed / flight.estimate))
    else
        badge.time:SetText(DurationText(seconds))
        badge.caption:SetText(L(flight.interrupted and "Escale demandée" or "Temps écoulé"))
        badge.caption:Show()
    end
    badge.progress:SetShown(badge.countingDown and config.appearance.flightProgress or false)
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
    local previewArea = CreateFrame("Frame", nil, panel)
    previewArea:SetPoint("TOPLEFT", 16, -42)
    previewArea:SetPoint("TOPRIGHT", -16, -42)
    local previewHeight = 192
    previewArea:SetHeight(previewHeight)
    local preview, screenPreview
    local previewCenterY = 0

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", previewArea, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 16)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(1, 1)
    scroll:SetScrollChild(body)
    local targets, controls, groups = {}, {}, {}
    local syncing
    check = UI.Check(body, "ArkannsQOLFlightsEnabled", toggleLabel, 0, 0, SetEnabled)
    targets["Chronométrer les vols"] = check
    local function Changed()
        if badge then LayoutBadge(badge, true) end
        refreshSettings()
    end
    local progress = UI.Check(body, "ArkannsQOLFlightShowProgress", L(progressLabel), 0, -34, function(value)
        config.appearance.flightProgress = value
        Changed()
    end)
    targets[progressLabel] = progress
    local function Sample(view)
        view.title:SetText(L("Aperçu du minuteur"))
        view.time:SetText("1:23")
        view.caption:Hide()
        view.countingDown = true
        view.progress:SetValue(.45)
    end
    local position
    position = UI.Check(body, "ArkannsQOLFlightScreenPreview", L(screenPositionLabel), 0, -68, function(value)
        if value and WoW.ReadValue(InCombatLockdown) ~= false then
            position:SetChecked(false)
            UI.Notify(L("Aperçu disponible hors combat."))
            return
        end
        if value and not screenPreview then
            screenPreview = CreateBadge(UIParent, "ArkannsQOLFlightScreenSample")
            screenPreview:SetFrameStrata("FULLSCREEN_DIALOG")
            screenPreview:SetClampedToScreen(true)
            Sample(screenPreview)
        end
        if screenPreview then
            if value then LayoutBadge(screenPreview, true) end
            screenPreview:SetShown(value)
        end
    end)
    targets[screenPositionLabel] = position
    stopPreview = function()
        if screenPreview then screenPreview:Hide() end
        position:SetChecked(false)
    end

    local captionFormat = L("%s : %s")
    local function CreateChoice(choice)
        local key, source, _, options = unpack(choice)
        local button = UI.Button(body, "ArkannsQOL_" .. key, "", 0, 0, 340, function(self)
            if not MenuUtil or not MenuUtil.CreateContextMenu then return end
            MenuUtil.CreateContextMenu(self, function(_, menu)
                for _, option in ipairs(options) do
                    local value = option[1]
                    menu:CreateRadio(L(option[2]), function() return config.appearance[key] == value end, function()
                        config.appearance[key] = value
                        Changed()
                    end)
                end
            end)
        end)
        return {frame = button, height = 34, update = function(value)
            button:SetText(captionFormat:format(L(source), AppearanceLabel(choice, value)))
        end}
    end
    local function CreateRange(choice)
        local key, source, _, minimum, maximum, unit = unpack(choice)
        local row = CreateFrame("Frame", nil, body)
        local caption = UI.Label(row, L(source), 0, -2)
        caption:SetPoint("TOPRIGHT", 0, -2)
        caption:SetWordWrap(true)
        local note
        if key == "flightBeastGap" then
            note = UI.Label(row, L("0 aligne la texture sur le bord. Un nombre négatif la rapproche."), 0, -19, 11)
            note:SetPoint("TOPRIGHT", 0, -19)
            note:SetWordWrap(true)
        end
        local input = UI.Input(row, "ArkannsQOL_" .. key .. "Value", 0, 0, 58)
        input:ClearAllPoints()
        input:SetPoint("BOTTOMRIGHT", 0, 6)
        input:SetJustifyH("CENTER")
        local slider = CreateFrame("Slider", "ArkannsQOL_" .. key, row, "UISliderTemplate")
        slider:SetPoint("BOTTOMLEFT", 16, 9)
        slider:SetPoint("BOTTOMRIGHT", -86, 9)
        slider:SetHeight(18)
        slider:SetMinMaxValues(minimum, maximum)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        local function Commit(value)
            local number = Numeric(value, minimum, maximum)
            if number and config.appearance[key] ~= number then
                config.appearance[key] = number
                Changed()
            end
        end
        slider:SetScript("OnValueChanged", function(_, value)
            if not syncing then Commit(value) end
        end)
        local function RestoreValue() input:SetText(AppearanceLabel(choice, config.appearance[key])) end
        local originalText
        input:SetScript("OnEditFocusGained", function(self)
            originalText = tostring(config.appearance[key])
            self:SetText(originalText)
            self:HighlightText()
        end)
        input:SetScript("OnEditFocusLost", function(self)
            local text = self:GetText()
            if originalText and text ~= originalText then
                local number = text:match("^%s*([+-]?%d+)%s*%%?%s*$")
                Commit(tonumber(number))
            end
            originalText = nil
            RestoreValue()
        end)
        local function Finish(self) self:ClearFocus() end
        input:SetScript("OnEnterPressed", Finish)
        input:SetScript("OnTabPressed", Finish)
        input:SetScript("OnEscapePressed", function(self)
            originalText = nil
            self:ClearFocus()
        end)
        if unit then caption:SetText(L(source) .. " (%)") end
        return {frame = row, input = input, height = note and 78 or 60, update = function(value)
            if slider:GetValue() ~= value then slider:SetValue(value) end
            if not input:HasFocus() then RestoreValue() end
        end}
    end

    for _, group in ipairs(appearanceGroups) do
        local heading = UI.Label(body, L(group[1]), 0, 0, 15)
        local entries = {}
        for _, choice in ipairs(group[2]) do
            local control = type(choice[4]) == "table" and CreateChoice(choice) or CreateRange(choice)
            control.key = choice[1]
            entries[#entries + 1] = control
            controls[#controls + 1] = control
            targets[choice[2]] = control.frame
        end
        groups[#groups + 1] = {heading = heading, entries = entries}
    end
    local reset = UI.Button(body, "ArkannsQOLFlightResetAppearance", L(resetLabel), 0, 0, 340, function()
        config.appearance = Appearance()
        Changed()
    end)
    targets[resetLabel] = reset
    local help = UI.Label(body, "", 0, 0)
    help:SetWordWrap(true)
    local output = CreateFrame("EditBox", "ArkannsQOLFlightExport", body)
    output:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -10)
    output:Hide()
    output:SetMultiLine(true)
    output:SetAutoFocus(false)
    output:SetFontObject(GameFontHighlightSmall)
    output:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local export
    local function Resize()
        local width = math.max(1, panel:GetWidth() - 50)
        local wide = width >= 570
        local lane = math.min(390, wide and (width - 16) / 2 or width)
        local function PlaceGroup(group, x, y)
            group.heading:ClearAllPoints()
            group.heading:SetPoint("TOPLEFT", x, -y)
            y = y + 24
            for _, entry in ipairs(group.entries) do
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", x, -y)
                entry.frame:SetSize(lane, entry.height)
                y = y + entry.height + 5
            end
            return y + 10
        end
        local y = PlaceGroup(groups[1], 0, 110)
        y = math.max(y, PlaceGroup(groups[2], wide and lane + 16 or 0, wide and 110 or y))
        y = PlaceGroup(groups[3], 0, y)
        reset:ClearAllPoints()
        reset:SetPoint("TOPLEFT", 0, -y)
        reset:SetWidth(lane)
        export:ClearAllPoints()
        export:SetPoint("TOPLEFT", 0, -y - 42)
        export:SetWidth(math.min(215, width))
        help:ClearAllPoints()
        help:SetPoint("TOPLEFT", 0, -y - 77)
        help:SetWidth(width)
        output:SetWidth(width)
        local extra = output:IsShown() and output:GetHeight() or 0
        body:SetSize(width, y + 120 + extra)
        UI.ClampScroll(scroll, body:GetHeight())
        if preview then
            local aspect = math.max(preview.ornaments.left.aspect or 32 / 68, preview.ornaments.right.aspect or 32 / 68)
            local maxWidth = panelWidth + 2 * (maxBeastSize * aspect + maxBeastGap)
            -- Fit the largest decorations around a fixed panel center.
            local maxHeight = 2 * (maxBeastSize + maxBeastY) - panelHeight
            local scale = math.min((width + 18) / maxWidth, (previewHeight - 8) / maxHeight, config.appearance.flightScale / 100 * .55)
            preview:SetScale(scale)
            preview:ClearAllPoints()
            preview:SetPoint("CENTER", previewArea, "CENTER", 0, previewCenterY)
        end
    end
    export = UI.Button(body, nil, exportLabel, 0, 0, 215, function()
        local lines = ExportLines()
        if #lines == 0 then
            help:SetText(L("Aucun vol complet à exporter."))
            output:Hide()
            Resize()
            return
        end
        help:SetText(L("Ctrl+C pour copier les trajets et leurs durées."))
        output:SetText("QTF1\n" .. table.concat(lines, "\n"))
        local lineCount = WoW.ReadValue(output.GetNumLines, output)
        if not WoW.IsFiniteNumber(lineCount) or lineCount < 1 then lineCount = #lines + 1 end
        output:SetHeight(math.max(60, lineCount * 17))
        output:Show()
        Resize()
        UI.RevealControl(scroll, output)
        output:SetFocus()
        output:HighlightText()
    end)
    targets["Exporter les durées"] = export
    refreshSettings = function()
        check:SetChecked(config.enabled ~= false)
        progress:SetChecked(config.appearance.flightProgress)
        syncing = true
        for _, entry in ipairs(controls) do entry.update(config.appearance[entry.key]) end
        syncing = false
        if preview then previewCenterY = LayoutBadge(preview) end
        if screenPreview and screenPreview:IsShown() then LayoutBadge(screenPreview, true) end
        Resize()
    end
    refreshSettings()
    panel:SetScript("OnSizeChanged", Resize)
    panel:SetScript("OnShow", function()
        if not preview then
            preview = CreateBadge(previewArea, "ArkannsQOLFlightPreview")
            preview:SetPoint("CENTER")
            Sample(preview)
        end
        refreshSettings()
    end)
    panel:SetScript("OnHide", function()
        stopPreview()
        for _, entry in ipairs(controls) do
            if entry.input then entry.input:ClearFocus() end
        end
        output:ClearFocus()
        output:SetText("")
        output:Hide()
        help:SetText("")
    end)
    openSetting = function(source) UI.RevealControl(scroll, targets[source]) end
    category = UI.RegisterSettingsPanel(root, panel, title, "flights")
end

function ns.InitializeFlightTimes(root)
    local db = ForeverTooltipLibreDB
    if type(db.flights) ~= "table" then db.flights = {} end
    config = db.flights
    config.appearance = Appearance(config.appearance)
    if type(ArkannsQOLFlightsDB) ~= "table" then ArkannsQOLFlightsDB = {} end
    records = ArkannsQOLFlightsDB
    driver = CreateFrame("Frame", "ArkannsQOLFlightEvents")
    driver:SetScript("OnEvent", OnEvent)
    if root and Settings and Settings.RegisterCanvasLayoutSubcategory then RegisterSettings(root) end
    SetEnabled(config.enabled ~= false)
    local search = {"Chronométrer les vols", "Exporter les durées", progressLabel, resetLabel, screenPositionLabel}
    for _, group in ipairs(appearanceGroups) do
        for _, choice in ipairs(group[2]) do search[#search + 1] = choice[2] end
    end
    ns.RegisterModule(moduleID, {
        label = title,
        icon = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
        category = function() return category end,
        SearchSettings = search,
        OpenSettings = openSetting,
        StopPreview = stopPreview,
        Summary = function() return L("Affiche la durée des trajets et le temps restant en vol.") end,
        toggleLabel = toggleLabel,
        IsEnabled = function() return config.enabled end,
        SetEnabled = SetEnabled,
        ExportSettings = function() return {enabled = config.enabled, appearance = Appearance(config.appearance)} end,
        profileMigrations = {
            function(value, current)
                if value.appearance == nil then value.appearance = current.appearance end
            end,
            function(value) value.appearance = Appearance(value.appearance) end,
        },
        ProfileDisplay = function(value)
            local style = value.appearance
            if type(style) ~= "table" then return end
            local display = {[L(progressLabel)] = style.flightProgress}
            for _, group in ipairs(appearanceGroups) do
                for _, choice in ipairs(group[2]) do
                    local key, source = unpack(choice)
                    display[L(source)] = AppearanceLabel(choice, style[key])
                end
            end
            value.appearance = display
        end,
        ImportSettings = function(value)
            if type(value) ~= "table" or type(value.enabled) ~= "boolean" then return false end
            if value.appearance ~= nil then config.appearance = Appearance(value.appearance) end
            if value.enabled ~= config.enabled then SetEnabled(value.enabled) end
            if badge then LayoutBadge(badge, true) end
            if refreshSettings then refreshSettings() end
            return true
        end,
    })
end
