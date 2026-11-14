local _, ns = ...
local WoW, L = ns.WoW, ns.L
local Test, states = {}, {player = {unit = "player"}, target = {unit = "target"}}
ns.PaladinCustomTest = Test
local driver
local syncingSettings, settingsReady = false, false
local hookedBars, hookedText = {}, {}
local hookedAuraOwners = {}
local auraDrop = 12
local predictionEvents = {UNIT_HEAL_PREDICTION = true, UNIT_HEALTH = true,
    UNIT_MAXHEALTH = true, UNIT_HEAL_ABSORB_AMOUNT_CHANGED = true}
local refreshEvents = {UNIT_PORTRAIT_UPDATE = true, UNIT_NAME_UPDATE = true, UNIT_CONNECTION = true}
local units = {"player", "target"}

-- Class-frame renderer with session-only manual previews. Native secure buttons
-- and data pipelines remain intact.
-- Native values/text go straight to permitted UI sinks; never inspect or calculate secret data.
-- Forever 4cd0ab7: PlayerFrame/TargetFrame XML and SimpleStatusBar/FontString API declarations.
local function Accessible(object)
    return WoW.IsPublic(object) and object and WoW.ReadValue(object.IsForbidden, object) == false
end

local function CanMoveAuras(auras)
    if not Accessible(auras) then return false end
    return WoW.ReadValue(InCombatLockdown) == false
        or WoW.ReadValue(auras.CanChangeProtectedState, auras) == true
end

local function RestoreAuras(state)
    if not state.shiftedAuras then return end
    local auras = state.shiftedAuras
    if CanMoveAuras(auras) and pcall(auras.AdjustPointsOffset, auras, 0, auraDrop) then
        state.shiftedAuras = nil
    end
end

local function ShiftAuras(state, owner)
    if state.shiftedAuras or not state.active or not state.source or state.source.owner ~= owner
        or WoW.ReadValue(UnitIsPlayer, "target") ~= true then return end
    local auras = WoW.ReadValue(owner.GetAuraContainer, owner)
    if not CanMoveAuras(auras)
        or WoW.ReadValue(auras.IsFlowLayoutMirroredVertically, auras) ~= false then return end
    -- Move the native container, not its buff/debuff rows or secret aura geometry.
    if pcall(auras.AdjustPointsOffset, auras, 0, -auraDrop) then state.shiftedAuras = auras end
end

local function LinkAuras(state, owner)
    if state.unit ~= "target" then return end
    if not hookedAuraOwners[owner] then
        if type(owner.AnchorAuraContainer) ~= "function" then return end
        local ok = pcall(hooksecurefunc, owner, "AnchorAuraContainer", function()
            -- Forever 4cd0ab7 AnchorAuraContainer clears/rebuilds the native anchor.
            state.shiftedAuras = nil
            ShiftAuras(state, owner)
        end)
        if not ok then return end
        hookedAuraOwners[owner] = true
    end
    ShiftAuras(state, owner)
end

local function ArtFor(class)
    local catalog = ns.TargetPortraitArt.customFrames
    return catalog and catalog[class] or (class == "PALADIN" and ns.TargetPortraitArt.paladinCustom)
end

local function SelectedClass(state)
    if state.override then return state.override end
    local class
    if type(UnitClassBase) == "function" then
        class = WoW.ReadValue(UnitClassBase, state.unit)
    else
        local status, _, token = WoW.Read(UnitClass, state.unit)
        if status == "ok" then class = token end
    end
    if type(class) == "string" and ArtFor(class) then return class end
end

local function Configured(unit)
    local module = ns.modules and ns.modules.targetPortrait
    if not module or not module.IsEnabled() then return false end
    local config = module.ExportSettings()[unit]
    return type(config) == "table" and config.enabled == true
end

local function SyncText(source, destination)
    destination:SetText(source:GetText())
    destination:SetShown(WoW.ReadValue(source.IsShown, source) == true)
end

local function SyncBar(source, destination)
    destination:SetMinMaxValues(source:GetMinMaxValues())
    destination:SetValue(source:GetValue())
end

local function UpdateColors(state)
    ns.PaladinFrameColors.Apply(state.frame.health, state.frame.power, state.unit)
end

local function RestoreAlpha(state)
    if not state.savedAlpha then return end
    for region, alpha in pairs(state.savedAlpha) do
        -- SetAlpha is not protected. Restore the native visuals during target changes in combat too.
        if Accessible(region) and WoW.ReadValue(region.GetAlpha, region) == 0 then pcall(region.SetAlpha, region, alpha) end
    end
    state.savedAlpha = nil
end

local function Suspend(state)
    state.active = false
    RestoreAuras(state)
    if state.frame then ns.PaladinFrameIndicators.Stop(state.frame.indicators); state.frame:Hide() end
    RestoreAlpha(state)
    state.source = nil
end

local function LinkBar(state, key, source)
    if hookedBars[source] then return end
    hookedBars[source] = true
    for _, method in ipairs({"SetMinMaxValues", "SetValue"}) do
        hooksecurefunc(source, method, function(_, ...)
            if state.active and state.source[key] == source then
                if not pcall(state.frame[key][method], state.frame[key], ...) or not pcall(UpdateColors, state) then Suspend(state) end
            end
        end)
    end
end

local function LinkText(state, key, source)
    if hookedText[source] then return end
    hookedText[source] = true
    for _, method in ipairs({"SetText", "SetFormattedText", "Show", "Hide", "SetShown"}) do
        hooksecurefunc(source, method, function()
            if state.active and state.source.text[key] == source
                and not pcall(SyncText, source, state.frame.text[key]) then Suspend(state) end
        end)
    end
end

local function Sources(unit)
    local player = unit == "player"
    local owner = player and PlayerFrame or TargetFrame
    if not Accessible(owner) or not WoW.IsPublic(owner.unit) or owner.unit ~= unit then return end
    local container = owner[player and "PlayerFrameContainer" or "TargetFrameContainer"]
    local content = owner[player and "PlayerFrameContent" or "TargetFrameContent"]
    if not Accessible(container) or not Accessible(content) then return end
    local main = content[player and "PlayerFrameContentMain" or "TargetFrameContentMain"]
    if not Accessible(main) then return end
    local healthContainer = main.HealthBarsContainer
    local manaArea = player and main.ManaBarArea or main
    if not Accessible(healthContainer) or not Accessible(manaArea) then return end
    local health, power = healthContainer.HealthBar, manaArea.ManaBar
    if not Accessible(health) or not Accessible(power) then return end
    for _, bar in ipairs({health, power}) do
        for _, method in ipairs({"GetMinMaxValues", "GetValue", "SetMinMaxValues", "SetValue"}) do
            if type(bar[method]) ~= "function" then return end
        end
    end
    local text = {name = player and PlayerName or main.Name, level = player and PlayerLevelText or main.LevelText,
        healthCenter = healthContainer.HealthBarText, healthLeft = healthContainer.LeftText, healthRight = healthContainer.RightText,
        powerCenter = power.ManaBarText, powerLeft = power.LeftText, powerRight = power.RightText}
    for _, key in ipairs({"name", "level", "healthCenter", "healthLeft", "healthRight", "powerCenter", "powerLeft", "powerRight"}) do
        if not Accessible(text[key]) or type(text[key].GetText) ~= "function" then return end
    end
    -- Target auras live in ContentContextual, beside ContentMain. Keep their
    -- parent visible so Blizzard retains aura buttons, tooltips and cooldowns.
    return {owner = owner, container = container, content = player and content or main,
        health = health, power = power, text = text}
end

local function Layout(state, art)
    local frame, reverse = state.frame, state.unit == "target"
    local scale = art.displayWidth / art.width
    local function Point(region, anchor, x, y, width)
        region:ClearAllPoints()
        if reverse then x = art.width - x - (width or 0) end
        region:SetPoint(anchor, frame, "TOPLEFT", x * scale, -y * scale)
    end
    Point(frame.body, "TOPLEFT", art.body[1], art.body[2], art.body[3])
    frame.body:SetSize(art.body[3] * scale, art.body[4] * scale)
    frame.skin:SetSize(art.displayWidth, art.height * scale)
    Point(frame.portrait, "CENTER", art.portrait[1], art.portrait[2])
    frame.portrait:SetSize(art.portrait[3] * scale, art.portrait[3] * scale)
    local name = frame.text.name
    name:ClearAllPoints()
    local nameX = reverse and art.width - art.name[1] - art.name[3] or art.name[1]
    name:SetPoint("TOPLEFT", frame.front, "TOPLEFT", nameX * scale, -art.name[2] * scale)
    name:SetSize(art.name[3] * scale, art.name[4] * scale)
    local level = frame.text.level
    level:ClearAllPoints()
    level:SetPoint("CENTER", frame.front, "TOPLEFT", (reverse and art.width - art.level[1] or art.level[1]) * scale, -art.level[2] * scale)
    level:SetSize(art.level[3] * scale, art.level[4] * scale)
    for _, key in ipairs({"health", "power"}) do
        local rect = art[key]
        Point(frame[key], "TOPLEFT", rect[1], rect[2], rect[3])
        frame[key]:SetSize(rect[3] * scale, rect[4] * scale)
    end
    frame.indicators.combat:ClearAllPoints()
    frame.indicators.combat:SetPoint("CENTER", frame.front, "TOPLEFT", reverse and art.displayWidth - 16 or 16, -68)
    state.art = art
end

local function Create(state, owner)
    local level = WoW.ReadValue(owner.GetFrameLevel, owner)
    if not WoW.IsFiniteNumber(level) then return end
    local name = state.unit == "player" and "ArkannsQOLPaladinCustomTest" or "ArkannsQOLClassCustomTarget"
    local frame = CreateFrame("Frame", name, owner)
    frame:Hide(); frame:EnableMouse(false); frame:SetAllPoints(owner); frame:SetFrameLevel(level + 5)
    frame.text = {}
    frame.body = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.body:SetColorTexture(.025, .02, .018, 1)
    frame.front = CreateFrame("Frame", nil, frame)
    frame.front:EnableMouse(false); frame.front:SetAllPoints(frame); frame.front:SetFrameLevel(level + 8)
    frame.skin = frame.front:CreateTexture(nil, "ARTWORK")
    frame.skin:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.portrait = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.portraitMask = frame:CreateMaskTexture()
    frame.portraitMask:SetAllPoints(frame.portrait); frame.portrait:AddMaskTexture(frame.portraitMask)
    local function Text(parent, key, anchor, x, y, width, font)
        local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        if anchor then text:SetPoint(anchor, parent, anchor, x, y) end
        text:SetWidth(width); text:SetWordWrap(false); text:SetJustifyV("MIDDLE")
        frame.text[key] = text
        return text
    end
    local nameText = Text(frame.front, "name", nil, nil, nil, 115, "GameFontNormal")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE"); nameText:SetJustifyH("CENTER")
    local levelText = Text(frame.front, "level", nil, nil, nil, 35, "GameFontHighlight")
    levelText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE"); levelText:SetTextColor(1, .97, .85, 1)
    levelText:SetShadowColor(0, 0, 0, 1); levelText:SetShadowOffset(1, -1); levelText:SetJustifyH("CENTER")
    for _, key in ipairs({"health", "power"}) do
        local bar = CreateFrame("StatusBar", nil, frame)
        bar:EnableMouse(false); bar:SetFrameLevel(level + 6)
        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(bar); background:SetColorTexture(.025, .02, .018, 1)
        frame[key] = bar
        Text(bar, key .. "Center", "CENTER", 0, 0, 115):SetJustifyH("CENTER")
        Text(bar, key .. "Left", "LEFT", 3, 0, 55):SetJustifyH("LEFT")
        Text(bar, key .. "Right", "RIGHT", -6, 0, 55):SetJustifyH("RIGHT")
        for _, suffix in ipairs({"Center", "Left", "Right"}) do frame.text[key .. suffix]:SetParent(frame.front) end
    end
    frame.indicators = ns.PaladinFrameIndicators.Create(frame.front, frame.health, state.unit)
    return frame
end

local function UpdatePortrait(state)
    state.frame.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    WoW.Read(SetPortraitTexture, state.frame.portrait, state.unit, true)
end

local function Refresh(state)
    if not state.requested then return false end
    if not Configured(state.unit) then
        Suspend(state)
        state.requested, state.manual, state.override = false, false, nil
        return false
    end
    if state.vehicle then Suspend(state); return false end
    if state.unit == "target" and WoW.ReadValue(UnitIsPlayer, "target") ~= true then Suspend(state); return false end
    local class = SelectedClass(state)
    local art = class and ArtFor(class)
    local source = art and Sources(state.unit)
    if not source then Suspend(state); return false end
    if WoW.ReadValue(InCombatLockdown) ~= false then
        if not state.active or state.class ~= class or state.source.owner ~= source.owner then Suspend(state); return false end
        UpdatePortrait(state); ns.PaladinFrameIndicators.Update(state.frame.indicators); UpdateColors(state)
        return true
    end
    if source.owner.IsAnchoringSecret and WoW.ReadValue(source.owner.IsAnchoringSecret, source.owner) ~= false then Suspend(state); return false end
    if state.frame and state.frame:GetParent() ~= source.owner then Suspend(state); return false end
    if not state.savedAlpha then
        local alpha = WoW.ReadValue(source.container.GetAlpha, source.container)
        local contentAlpha = WoW.ReadValue(source.content.GetAlpha, source.content)
        if not WoW.IsFiniteNumber(alpha) or not WoW.IsFiniteNumber(contentAlpha) then return false end
        state.savedAlpha = {[source.container] = alpha, [source.content] = contentAlpha}
    end
    local ok = pcall(function()
        if not state.frame then state.frame = Create(state, source.owner) end
        local frame = state.frame
        if not frame then error("Unavailable custom frame") end
        if state.art ~= art then Layout(state, art) end
        if not frame.skin:SetTexture(art.texture)
            or not frame.portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            or not frame.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            or not frame.power:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") then error("Unavailable custom texture") end
        local reverse = state.unit == "target"
        frame.skin:SetTexCoord(reverse and 1 or 0, reverse and 0 or 1, 0, 1)
        frame.skin:SetDesaturation(art.desaturation or 0)
        local brightness = art.brightness or 1
        frame.skin:SetVertexColor(brightness, brightness, brightness, 1)
        ns.PaladinFrameIndicators.Prepare(frame.indicators)
        SyncBar(source.health, frame.health); SyncBar(source.power, frame.power); UpdateColors(state)
        for key, text in pairs(source.text) do SyncText(text, frame.text[key]) end
    end)
    if not ok then Suspend(state); return false end
    state.source, state.class, state.active = source, class, true
    LinkBar(state, "health", source.health); LinkBar(state, "power", source.power)
    for key, text in pairs(source.text) do LinkText(state, key, text) end
    ns.PaladinFrameIndicators.Start(state.frame.indicators, source.owner, source.health, state.unit)
    local hidden = pcall(function() source.container:SetAlpha(0); source.content:SetAlpha(0) end)
    if not hidden then Suspend(state); return false end
    UpdatePortrait(state); state.frame:Show()
    LinkAuras(state, source.owner)
    return true
end

local function StopState(state)
    Suspend(state)
    state.requested, state.pendingStop, state.override, state.manual = false, false, nil, false
    state.vehicle = false
end

local function OnEvent(_, event, unit)
    if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        for _, key in ipairs(units) do
            local state = states[key]
            if not state.active then RestoreAuras(state) end
            if state.pendingStop then StopState(state)
            elseif not settingsReady and state.requested then Refresh(state) end
        end
        if settingsReady then Test.SyncSettings() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if states.target.requested then Refresh(states.target) end
    elseif WoW.IsPublic(unit) and states[unit] then
        local state = states[unit]
        if event == "UNIT_EXITED_VEHICLE" then state.vehicle = false end
        if not state.requested then return end
        if event == "UNIT_ENTERED_VEHICLE" then
            state.vehicle = state.unit == "player"
            if state.manual then StopState(state) else Suspend(state) end
        elseif event == "UNIT_EXITED_VEHICLE" then
            state.vehicle = false
            if settingsReady then Test.SyncSettings() else StopState(state) end
        elseif refreshEvents[event] then Refresh(state)
        elseif state.active then
            ns.PaladinFrameIndicators.Update(state.frame.indicators)
            if event == "UNIT_DISPLAYPOWER" then UpdateColors(state) end
        end
    end
end

local function RegisterDriver()
    local requested = {}
    for _, unit in ipairs(units) do if states[unit].requested then requested[#requested + 1] = unit end end
    if not driver and #requested == 0 then return end
    if not driver then driver = CreateFrame("Frame", "ArkannsQOLClassFrameEvents"); driver:SetScript("OnEvent", OnEvent) end
    driver:UnregisterAllEvents()
    if #requested == 0 then
        if states.target.shiftedAuras then driver:RegisterEvent("PLAYER_REGEN_ENABLED") end
        return
    end
    driver:RegisterEvent("PLAYER_REGEN_ENABLED"); driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    if states.target.requested then driver:RegisterEvent("PLAYER_TARGET_CHANGED") end
    for event in pairs(predictionEvents) do driver:RegisterUnitEvent(event, unpack(requested)) end
    for event in pairs(refreshEvents) do driver:RegisterUnitEvent(event, unpack(requested)) end
    driver:RegisterUnitEvent("UNIT_DISPLAYPOWER", unpack(requested))
    driver:RegisterUnitEvent("UNIT_FLAGS", unpack(requested))
    driver:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", unpack(requested)); driver:RegisterUnitEvent("UNIT_EXITED_VEHICLE", unpack(requested))
end

function Test.SyncSettings()
    if syncingSettings then return end
    local module = ns.modules and ns.modules.targetPortrait
    if not module then return end
    syncingSettings, settingsReady = true, true
    local config = module.ExportSettings()
    for _, unit in ipairs(units) do
        local state, options = states[unit], config[unit]
        local custom = type(options) == "table" and options.customFrame ~= false
        if state.option ~= nil and state.option ~= custom then
            state.manual, state.override, state.sessionBlocked = false, nil, false
        end
        state.option = custom
        local allowed = config.enabled and type(options) == "table" and options.enabled
        if not allowed then StopState(state)
        elseif state.manual or (custom and not state.sessionBlocked) then
            state.requested = true
            if not state.pendingStop then Refresh(state) end
        else StopState(state) end
    end
    RegisterDriver()
    syncingSettings = false
end

function Test.IsActive(unit)
    return WoW.IsPublic(unit) and states[unit] and states[unit].active == true or false
end

function Test.Start(unit, class)
    if not WoW.IsPublic(unit) or not WoW.IsPublic(class) then return false end
    -- Preserve the approved /qtpaladin2 test and its existing programmatic entry point.
    if unit == nil then unit, class = "player", "PALADIN" end
    local state = states[unit]
    if not state or (class ~= nil and (type(class) ~= "string" or not ArtFor(class))) then return false end
    if WoW.ReadValue(InCombatLockdown) ~= false then return false, L("Cadres de classe : utilise cette commande hors combat.") end
    if not Configured(unit) then return false, L("Cadres de classe : active d’abord le cadre concerné dans Portraits de classe.") end
    if type(hooksecurefunc) ~= "function" then return false end
    state.requested, state.override, state.pendingStop = true, class, false
    state.manual, state.sessionBlocked = true, false
    state.vehicle = false
    if ns.StopPaladinOverlayTest then
        local previous = syncingSettings
        syncingSettings = true
        ns.StopPaladinOverlayTest()
        syncingSettings = previous
    end
    local ok = Refresh(state)
    if not ok and unit == "player" then state.requested = false end
    RegisterDriver()
    return ok or (unit == "target" and state.requested)
end

function Test.Stop(unit, suppressDefaults)
    if not WoW.IsPublic(unit) then return false end
    if unit ~= nil and not states[unit] then return false end
    local stopped = true
    for _, key in ipairs(units) do
        if unit == nil or unit == key then
            local state = states[key]
            if suppressDefaults then state.sessionBlocked = true end
            if state.requested or state.active then
                if WoW.ReadValue(InCombatLockdown) ~= false then state.pendingStop = true; stopped = false else StopState(state) end
            end
        end
    end
    if driver then RegisterDriver() end
    return stopped
end

SLASH_QOLTOOLKITPALADINCUSTOM1 = "/qtpaladin2"
SlashCmdList.QOLTOOLKITPALADINCUSTOM = function(message)
    local command = (message or ""):lower():match("^%s*(%S*)")
    if command == "off" then
        print(Test.Stop(nil, true) and L("Test paladin arrêté. Habillage habituel rétabli.") or L("Le cadre natif sera rétabli après le combat."))
    elseif command == "" then
        local ok, reason = Test.Start()
        print(ok and L("Cadre paladin personnalisé actif. /qtpaladin2 off pour rétablir Blizzard.")
            or reason or L("Test paladin personnalisé indisponible : le cadre Blizzard est conservé."))
    else print("/qtpaladin2 [off]") end
end

SLASH_QOLTOOLKITCLASSFRAMES1 = "/qtclassframes"
SlashCmdList.QOLTOOLKITCLASSFRAMES = function(message)
    local command, class = (message or ""):match("^%s*(%S*)%s*(%S*)")
    command, class = command:lower(), class ~= "" and class:upper() or nil
    if command == "off" then
        print(Test.Stop(nil, true) and L("Cadres de classe arrêtés. Habillage habituel rétabli.") or L("Le cadre natif sera rétabli après le combat."))
        return
    end
    if command == "" then command = "both" end
    if command ~= "player" and command ~= "target" and command ~= "both" then print("/qtclassframes [player|target|both|off] [CLASS]"); return end
    local ok, reason = true
    for _, unit in ipairs(units) do
        if command == unit or command == "both" then
            local started, failure = Test.Start(unit, class)
            ok, reason = started and ok, reason or failure
        end
    end
    print(ok and L("Cadres de classe personnalisés actifs. /qtclassframes off pour rétablir Blizzard.")
        or reason or L("Cadre de classe indisponible : le cadre Blizzard est conservé."))
end
