local _, ns = ...
local WoW = ns.WoW
local Indicators = {}
ns.PaladinFrameIndicators = Indicators

local activeStates = {}
local statusHooked, predictionHooked = false, false
local segments = {"MyHealPredictionBar", "OtherHealPredictionBar", "TotalAbsorbBar", "HealAbsorbBar"}

-- Forever 4cd0ab7: PlayerFrame.xml, UnitFrame.lua and StatusBarOverlaySegment.lua.
-- Mirror public native layout for absorbs; render incoming heals through native UI sinks.
local function Accessible(object)
    return WoW.IsPublic(object) and object and WoW.ReadValue(object.IsForbidden, object) == false
end

local function Rect(region)
    if not Accessible(region) then return end
    local status, left, bottom, width, height = WoW.Read(region.GetRect, region)
    local scale = WoW.ReadValue(region.GetEffectiveScale, region)
    if status ~= "ok" or not WoW.IsFiniteNumber(left) or not WoW.IsFiniteNumber(bottom)
        or not WoW.IsFiniteNumber(width) or not WoW.IsFiniteNumber(height)
        or not WoW.IsFiniteNumber(scale) or width <= 0 or height <= 0 or scale <= 0 then return end
    return left, width, scale
end

local function SyncPrediction(state, key, destination)
    if not destination.available then return end
    local source = state.nativeHealth[key]
    if not Accessible(source) or WoW.ReadValue(source.IsShown, source) ~= true then return end
    local fill = source.Fill
    if not Accessible(fill) then return end
    local left, width, scale = Rect(source.FillMask)
    local healthLeft, healthWidth, healthScale = Rect(state.nativeHealth)
    local customWidth, customHeight = WoW.ReadValue(state.health.GetWidth, state.health), WoW.ReadValue(state.health.GetHeight, state.health)
    if not left or not healthLeft or not WoW.IsFiniteNumber(customWidth) or not WoW.IsFiniteNumber(customHeight)
        or customWidth <= 0 or customHeight <= 0 then return end
    -- GetRect values use each region's effective scale. Convert before taking fractions.
    local relativeScale = scale / healthScale
    local start = (left * relativeScale - healthLeft) / healthWidth * customWidth
    local span = width * relativeScale / healthWidth * customWidth
    if not WoW.IsFiniteNumber(start) or not WoW.IsFiniteNumber(span) then return end
    local finish = math.min(customWidth, start + span)
    start = math.max(0, start)
    if finish <= start then return end
    -- Native tint, including possible secret components, goes directly to its UI sink.
    destination:SetVertexColor(fill:GetVertexColor())
    destination:ClearAllPoints()
    destination:SetPoint("TOPLEFT", state.health, "TOPLEFT", start, 0)
    destination:SetSize(finish - start, customHeight)
    destination:Show()
end

-- Setup runs before the health bar receives its first native (possibly secret) value.
-- SetPoint only receives our own texture reference and constant offsets. Never re-anchor it.
function Indicators.Prepare(state)
    if not state or WoW.ReadValue(InCombatLockdown) ~= false then return false end
    state.forecastReady = false
    if type(CreateUnitHealPredictionCalculator) ~= "function" or type(UnitGetDetailedHealPrediction) ~= "function"
        or type(CreateFrame) ~= "function" then return false end
    local ok = pcall(function()
        if not state.calculator then
            local calculator = CreateUnitHealPredictionCalculator()
            calculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
            calculator:SetHealAbsorbMode(Enum.UnitHealAbsorbMode.ReducedByIncomingHeals)
            calculator:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
            calculator:SetIncomingHealOverflowPercent(1)
            state.calculator = calculator
        end
        if not state.clipper then
            local level = WoW.ReadValue(state.health.GetFrameLevel, state.health)
            if not WoW.IsFiniteNumber(level) then return end
            local clipper = CreateFrame("Frame", nil, state.health)
            state.clipper = clipper
            clipper:Hide()
            clipper:EnableMouse(false)
            clipper:SetAllPoints(state.health)
            clipper:SetClipsChildren(true)
            clipper:SetFrameLevel(level + 1)
            state.clipperPrepared = true
        end
        if not state.clipperPrepared then return end
        if not state.forecast then
            local width = WoW.ReadValue(state.health.GetWidth, state.health)
            if not WoW.IsFiniteNumber(width) or width <= 0 then return end
            local fill = WoW.ReadValue(state.health.GetStatusBarTexture, state.health)
            if not Accessible(fill)
                or (fill.IsAnchoringSecret and WoW.ReadValue(fill.IsAnchoringSecret, fill) ~= false) then return end
            local forecast = CreateFrame("StatusBar", nil, state.clipper)
            state.forecast = forecast
            forecast:Hide()
            forecast:EnableMouse(false)
            forecast:SetFrameLevel(state.clipper:GetFrameLevel())
            forecast:SetWidth(width)
            forecast:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
            forecast:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)
            state.forecastAnchored = true
        end
        -- A rejected setup stays cached and hidden; never retry anchors after native values arrive.
        if not state.forecastAnchored then return end
        if not state.forecast:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") then return end
        state.forecast:SetStatusBarColor(.35, 1, .65, .7)
        state.forecastReady = true
    end)
    return ok and state.forecastReady
end

local function SyncForecast(state)
    -- Forever 4cd0ab7 UnitHealPredictionCalculatorAPI: all arithmetic/clamping stays native.
    -- https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitHealPredictionCalculatorAPIDocumentation.lua
    UnitGetDetailedHealPrediction(state.unit, "player", state.calculator)
    state.forecast:SetMinMaxValues(0, state.calculator:GetMaximumHealth())
    state.forecast:SetValue((state.calculator:GetIncomingHeals()))
    state.forecast:Show()
    state.clipper:Show()
end

function Indicators.Update(state)
    if not state or not state.active then return end
    state.combat:Hide()
    if state.forecast then state.forecast:Hide() end
    if state.clipper then state.clipper:Hide() end
    local available = Accessible(state.owner) and Accessible(state.nativeHealth)
    if available and state.unit == "player" and state.statusLinked and state.combatAvailable then
        local content = state.owner.PlayerFrameContent
        local contextual = Accessible(content) and content.PlayerFrameContentContextual
        local icon = Accessible(contextual) and contextual.AttackIcon
        if Accessible(icon) then state.combat:SetShown(WoW.ReadValue(icon.IsShown, icon) == true) end
    elseif available and state.unit == "target" and state.combatAvailable then
        state.combat:SetShown(WoW.ReadValue(UnitAffectingCombat, "target") == true)
    end
    for _, key in ipairs(segments) do
        local destination = state.predictions[key]
        destination:Hide()
        local nativeHeal = key == "MyHealPredictionBar" or key == "OtherHealPredictionBar"
        if available and state.predictionLinked and not (state.forecastReady and nativeHeal) then
            local ok = pcall(SyncPrediction, state, key, destination)
            if not ok then destination:Hide() end
        end
    end
    if available and state.forecastReady then
        local ok = pcall(SyncForecast, state)
        if not ok then state.forecast:Hide(); state.clipper:Hide() end
    end
end

local function InstallHooks()
    if type(hooksecurefunc) ~= "function" then return end
    if not statusHooked and type(PlayerFrame_UpdateStatus) == "function" then
        statusHooked = pcall(hooksecurefunc, "PlayerFrame_UpdateStatus", function()
            for _, state in pairs(activeStates) do
                if state.unit == "player" then Indicators.Update(state) end
            end
        end)
    end
    if not predictionHooked and type(UnitFrameHealPredictionBars_Update) == "function" then
        predictionHooked = pcall(hooksecurefunc, "UnitFrameHealPredictionBars_Update", function(owner)
            if WoW.IsPublic(owner) then Indicators.Update(activeStates[owner]) end
        end)
    end
end

function Indicators.Create(root, customHealth, unit)
    if WoW.ReadValue(InCombatLockdown) ~= false then return end
    if not WoW.IsPublic(unit) then return end
    if unit == nil then unit = "player" end
    if unit ~= "player" and unit ~= "target" then return end
    local state = {health = customHealth, predictions = {}, unit = unit}
    state.combat = root:CreateTexture(nil, "OVERLAY")
    state.combat:SetPoint("CENTER", root, "TOPLEFT", unit == "target" and 216 or 16, -68)
    state.combat:SetSize(26, 26)
    state.combat:Hide()
    local atlas = "UI-HUD-UnitFrame-Player-CombatIcon"
    local info = WoW.IsPublic(C_Texture) and C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, atlas)
    if WoW.IsPublic(info) and type(info) == "table" then
        state.combatAvailable = pcall(state.combat.SetAtlas, state.combat, atlas, false)
    end
    for index, key in ipairs(segments) do
        local texture = customHealth:CreateTexture(nil, "ARTWORK", nil, index)
        texture:Hide()
        texture.available = texture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar") == true
        state.predictions[key] = texture
    end
    return state
end

function Indicators.Start(state, owner, nativeHealth, unit)
    if not state or not Accessible(owner) or not Accessible(nativeHealth) then return false end
    if not WoW.IsPublic(unit) then return false end
    if unit == nil then unit = state.unit or "player" end
    if unit ~= "player" and unit ~= "target" then return false end
    if activeStates[owner] and activeStates[owner] ~= state then Indicators.Stop(activeStates[owner]) end
    -- A failed first activation must not cache unavailable fill textures forever.
    for _, texture in pairs(state.predictions) do
        texture.available = texture:SetTexture("Interface\\TargetingFrame\\UI-StatusBar") == true
    end
    InstallHooks()
    state.owner, state.nativeHealth, state.unit = owner, nativeHealth, unit
    state.statusLinked, state.predictionLinked = statusHooked, predictionHooked
    state.active, activeStates[owner] = true, state
    Indicators.Update(state)
    return true
end

function Indicators.Stop(state)
    if not state then return end
    state.active = false
    if state.owner and activeStates[state.owner] == state then activeStates[state.owner] = nil end
    state.owner, state.nativeHealth = nil, nil
    state.combat:Hide()
    if state.forecast then state.forecast:Hide() end
    if state.clipper then state.clipper:Hide() end
    for _, texture in pairs(state.predictions) do texture:Hide() end
end
