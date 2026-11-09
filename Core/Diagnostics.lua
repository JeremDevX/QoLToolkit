local addonName, ns = ...
local L, WoW = ns.L, ns.WoW
local diagnostics = {}
ns.Diagnostics = diagnostics

local interval, duration, rowLimit, eventLimit = 0.5, 120, 260, 24
local ticker, listener, export, editBox, scroll
local started, trace, previous, modules, pending, droppedEvents

local events = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED",
    "PLAYER_DEAD", "PLAYER_UNGHOST", "UNIT_AURA", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "PLAYER_MONEY", "CVAR_UPDATE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "PLAYER_LOGOUT",
}
local namedFrames = {
    {"home", "ArkannsQOLHome"}, {"layout", "ArkannsQOLLayout"},
    {"profiles", "ArkannsQOLProfilesPanel"}, {"bags.quick", "ArkannsQOLBagQuickSettings"},
    {"bags.settings", "ArkannsQOLBagsPanel"}, {"advanced.settings", "ArkannsQOLAdvancedPanel"},
    {"ranks.settings", "ArkannsQOLRankSettings"},
}
local strata = {
    BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
    FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true,
}

local function Bool(value)
    if value == true then return "1" end
    if value == false then return "0" end
    return "?"
end

local function Number(value, format)
    return WoW.IsFiniteNumber(value) and format:format(value) or "?"
end

local function Identifier(value)
    if type(value) == "string" and #value <= 32 and value:match("^[%w.%-+]+$") then return value end
    return "?"
end

local function Header()
    local _, client, build, _, interface = WoW.Read(GetBuildInfo)
    local addon = C_AddOns and WoW.ReadValue(C_AddOns.GetAddOnMetadata, addonName, "Version")
    return ("QoL Toolkit trace v1 | addon=%s | client=%s build=%s interface=%s locale=%s"):format(
        Identifier(addon), Identifier(client), Identifier(build), Number(interface, "%d"),
        Identifier(WoW.ReadValue(GetLocale)))
end

local function FrameState(frame)
    if not frame then return "absent" end
    if WoW.ReadValue(frame.IsForbidden, frame) ~= false then return "unavailable" end
    local visible = WoW.ReadValue(frame.IsVisible, frame)
    local state = "shown=" .. Bool(WoW.ReadValue(frame.IsShown, frame)) .. " visible=" .. Bool(visible)
    if visible ~= true then return state end

    local _, left, bottom, width, height = WoW.Read(frame.GetRect, frame)
    local _, anchor, _, relativeAnchor, offsetX, offsetY = WoW.Read(frame.GetPoint, frame, 1)
    local level = WoW.ReadValue(frame.GetFrameLevel, frame)
    local layer = WoW.ReadValue(frame.GetFrameStrata, frame)
    local alpha = WoW.ReadValue(frame.GetEffectiveAlpha, frame)
    local scale = WoW.ReadValue(frame.GetEffectiveScale, frame)
    return state .. (" rect=%s,%s,%s,%s scale=%s alpha=%s strata=%s level=%s anchor=%s/%s:%s,%s"):format(
        Number(left, "%.1f"), Number(bottom, "%.1f"), Number(width, "%.1f"), Number(height, "%.1f"),
        Number(scale, "%.3f"), Number(alpha, "%.2f"), strata[layer] and layer or "?", Number(level, "%d"),
        Identifier(anchor), Identifier(relativeAnchor), Number(offsetX, "%.1f"), Number(offsetY, "%.1f"))
end

function diagnostics.Note(label)
    if not started then return end
    if #pending < eventLimit then pending[#pending + 1] = label else droppedEvents = droppedEvents + 1 end
end

local function Capture(reason)
    local rows = {}
    local function Record(label, value)
        if previous[label] == value then return end
        previous[label] = value
        rows[#rows + 1] = label .. " " .. value
    end

    local combat = WoW.ReadValue(InCombatLockdown)
    Record("combat", Bool(combat))
    Record("viewport", ("%sx%s scale=%s"):format(
        Number(WoW.ReadValue(UIParent.GetWidth, UIParent), "%.1f"),
        Number(WoW.ReadValue(UIParent.GetHeight, UIParent), "%.1f"),
        Number(WoW.ReadValue(UIParent.GetEffectiveScale, UIParent), "%.3f")))

    for _, id in ipairs(modules) do
        local module = ns.modules[id]
        if module.IsEnabled then Record(id .. ".enabled", Bool(WoW.ReadValue(module.IsEnabled))) end
        if module.frame or module.DiagnosticFrame then
            local frame = module.frame or WoW.ReadValue(module.DiagnosticFrame)
            Record(id .. ".frame", FrameState(frame))
        end
    end
    for _, pair in ipairs(namedFrames) do Record(pair[1], FrameState(_G[pair[2]])) end
    local tooltipState = combat == true and "unavailable in combat" or "unavailable"
    if combat == false then tooltipState = FrameState(GameTooltip) end
    Record("tooltip.native", tooltipState)

    if #pending > 0 then rows[#rows + 1] = "events " .. table.concat(pending, " ") end
    if droppedEvents > 0 then rows[#rows + 1] = "events omitted=" .. droppedEvents end
    pending, droppedEvents = {}, 0
    if #rows == 0 and not reason then return end

    local row = ("+%.1fs %s"):format(GetTime() - started, reason or "change")
    if #rows > 0 then row = row .. "\n  " .. table.concat(rows, "\n  ") end
    if #trace.rows >= rowLimit then table.remove(trace.rows, 1) end
    trace.rows[#trace.rows + 1] = row
end

local function Stop(reason)
    if not started then return false end
    Capture(reason)
    started, trace, previous, modules, pending = nil, nil, nil, nil, nil
    listener:UnregisterAllEvents()
    if ticker then ticker:Cancel(); ticker = nil end
    return true
end

local function OnEvent(_, event, argument)
    if event == "PLAYER_LOGOUT" then Stop("logout"); return end
    if event == "UNIT_AURA" or event == "PLAYER_XP_UPDATE" then
        if not WoW.IsPublic(argument) or argument ~= "player" then return end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if not WoW.IsPublic(argument) or argument ~= addonName then return end
    end
    diagnostics.Note(event)
end

local function Tick()
    if not started then return end
    if GetTime() - started >= duration then
        Stop("timeout")
        print(L("Capture terminée. /aqlog show pour la copier."))
    else
        Capture()
    end
end

local function Start()
    if started then return L("Une capture est déjà en cours.") end
    if not C_Timer or type(C_Timer.NewTicker) ~= "function" or type(GetTime) ~= "function" then
        return L("Capture indisponible sur ce client.")
    end
    if not listener then
        listener = CreateFrame("Frame")
        listener:SetScript("OnEvent", OnEvent)
    end
    local ok, handle = pcall(C_Timer.NewTicker, interval, Tick)
    if not ok or not handle then return L("Capture indisponible sur ce client.") end
    ticker = handle
    for _, event in ipairs(events) do pcall(listener.RegisterEvent, listener, event) end
    modules = {}
    for id in pairs(ns.modules or {}) do modules[#modules + 1] = id end
    table.sort(modules)
    started, previous, pending, droppedEvents = GetTime(), {}, {}, 0
    trace = {header = Header(), rows = {}}
    ForeverTooltipLibreDB.diagnostics = trace
    Capture("start")
    return L("Capture démarrée pour 2 min. /aqlog stop pour l’arrêter.")
end

local function CreateExport()
    export = CreateFrame("Frame", "QoLToolkitDiagnosticsExport", UIParent, "BackdropTemplate")
    export:SetSize(700, 440)
    export:SetPoint("CENTER")
    export:SetFrameStrata("DIALOG")
    export:SetClampedToScreen(true)
    export:EnableMouse(true)
    ns.UI.StylePanel(export)
    ns.UI.Label(export, L("Trace de diagnostic"), 16, -16, 18)
    ns.UI.Label(export, L("Sélectionne la trace et copie-la avec Ctrl+C."), 16, -44)

    local close = CreateFrame("Button", nil, export, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    scroll = CreateFrame("ScrollFrame", nil, export, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -70)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetSize(648, 354)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() export:Hide() end)
    export:SetScript("OnHide", function() editBox:ClearFocus() end)
    scroll:SetScrollChild(editBox)
end

local function Show()
    local saved = ForeverTooltipLibreDB.diagnostics
    if type(saved) ~= "table" or type(saved.header) ~= "string" or type(saved.rows) ~= "table" then
        return L("Aucune trace. Utilise /aqlog start pour commencer.")
    end
    if WoW.ReadValue(InCombatLockdown) ~= false then return L("Ouvre la trace hors combat.") end
    if not export then CreateExport() end
    local lines = {saved.header, "rect=left,bottom,width,height (frame units)"}
    for index = math.max(1, #saved.rows - rowLimit + 1), #saved.rows do
        local row = saved.rows[index]
        if type(row) == "string" then lines[#lines + 1] = row end
    end
    local text = table.concat(lines, "\n")
    editBox:SetText(text)
    export:Show()
    local lineCount = WoW.ReadValue(editBox.GetNumLines, editBox)
    if not WoW.IsFiniteNumber(lineCount) or lineCount < 1 then
        local _, newlines = text:gsub("\n", "\n")
        lineCount = newlines + 1
    end
    editBox:SetHeight(math.max(354, lineCount * 16))
    editBox:SetFocus()
    editBox:HighlightText()
    scroll:SetVerticalScroll(0)
end

function ns.InitializeDiagnostics()
    SLASH_QOLTOOLKITDIAGNOSTICS1 = "/aqlog"
    SlashCmdList.QOLTOOLKITDIAGNOSTICS = function(input)
        local command = input:lower():match("^%s*(%S*)")
        local message
        if command == "start" then
            message = Start()
        elseif command == "stop" then
            message = Stop("stop") and L("Capture terminée. /aqlog show pour la copier.") or L("Aucune capture en cours.")
        elseif command == "mark" then
            if started then Capture("mark") else message = L("Aucune capture en cours.") end
        elseif command == "show" then
            message = Show()
        elseif command == "clear" then
            Stop("clear")
            ForeverTooltipLibreDB.diagnostics = nil
            if export then export:Hide(); editBox:SetText("") end
            message = L("Trace effacée.")
        else
            message = L("/aqlog start : enregistrer • mark : marquer • stop : arrêter • show : copier • clear : effacer")
        end
        if message then print(message) end
    end
end
