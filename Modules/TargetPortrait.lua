local _, ns = ...
local L, UI, WoW = ns.L, ns.UI, ns.WoW
local title = L("Portrait de cible")
local toggleSource = "Afficher l’entourage de classe"
local classTexture = "Interface\\WorldStateFrame\\Icons-Classes"
-- Zero-based cells in the native 4 × 4 texture. Forever has nine classes.
local classSlots = {WARRIOR = 0, MAGE = 1, ROGUE = 2, DRUID = 3,
    HUNTER = 4, SHAMAN = 5, PRIEST = 6, WARLOCK = 7, PALADIN = 8}
local events = {"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "CVAR_UPDATE"}
local db, driver, overlay, toggle
local anchoredPortrait, rejectedPortrait, paintedClass

local function AddArc(frame, first, last, count, alpha)
    local radius = 33.5
    local step = (last - first) / count
    for index = 1, count do
        -- A small overlap closes seams between successive chords at fractional UI scales.
        local startAngle = math.rad(first + (index - 1) * step - (index > 1 and .35 or 0))
        local endAngle = math.rad(first + index * step + (index < count and .35 or 0))
        local highlight = math.sin(math.pi * (index - .5) / count)
        local line = frame:CreateLine(nil, "ARTWORK")
        line:SetStartPoint("CENTER", frame, radius * math.sin(startAngle), radius * math.cos(startAngle))
        line:SetEndPoint("CENTER", frame, radius * math.sin(endAngle), radius * math.cos(endAngle))
        line:SetThickness(1.3 + highlight)
        frame.arcs[#frame.arcs + 1] = {line = line, highlight = .10 + .20 * highlight,
            alpha = alpha * (.66 + .34 * highlight)}
    end
end

local function AnchorOverlay(container, portrait)
    if portrait == rejectedPortrait then return end
    if overlay and anchoredPortrait == portrait then return overlay end
    local state, locked = WoW.Read(InCombatLockdown)
    if state ~= "ok" or locked then return end
    if portrait.IsAnchoringSecret and WoW.ReadValue(portrait.IsAnchoringSecret, portrait) ~= false then return end
    local level = WoW.ReadValue(container.GetFrameLevel, container)
    if not WoW.IsFiniteNumber(level) then return end
    if not overlay then
        overlay = CreateFrame("Frame", nil, container)
        overlay:Hide()
        overlay:EnableMouse(false)
        overlay:SetSize(1, 1)
        overlay.arcs = {}
        if overlay.CreateLine then
            AddArc(overlay, -42, 61, 10, .94)
            AddArc(overlay, 178, 234, 6, .82)
        end
        local icon = overlay:CreateTexture(nil, "OVERLAY")
        if icon:SetTexture(classTexture) then
            icon:SetSize(19, 19)
            -- The raid marker is centered over the portrait. The PvP badge is below the glyph.
            icon:SetPoint("CENTER", overlay, "CENTER", 25, 24)
            overlay.icon = icon
        else
            icon:Hide()
        end
    end
    overlay:SetParent(container)
    overlay:SetFrameLevel(level)
    overlay:ClearAllPoints()
    anchoredPortrait = nil
    if not pcall(overlay.SetPoint, overlay, "CENTER", portrait, "CENTER", 0, -1) then
        rejectedPortrait = portrait
        return
    end
    anchoredPortrait = portrait
    return overlay
end

local function IsClassPortrait(portrait)
    local atlas = WoW.ReadValue(portrait.GetAtlas, portrait)
    if type(atlas) == "string" and atlas:lower():match("^classicon%-") then return true end
    local isSelf = WoW.ReadValue(UnitIsUnit, "target", "player")
    if type(isSelf) ~= "boolean" then return false end
    local cvar = isSelf and "ReplaceMyPlayerPortrait" or "ReplaceOtherPlayerPortraits"
    return C_CVar and WoW.ReadValue(C_CVar.GetCVarBool, cvar) == true
end

local function Refresh()
    if overlay then overlay:Hide() end
    if not db.enabled then return end
    local target = TargetFrame
    if not WoW.IsPublic(target) or not target or WoW.ReadValue(target.IsForbidden, target) ~= false then return end
    local container = target.TargetFrameContainer
    if not WoW.IsPublic(container) or not container then return end
    local portrait = container.Portrait
    if not WoW.IsPublic(portrait) or not portrait then return end
    local frame = AnchorOverlay(container, portrait)
    if not frame or (not frame.icon and #frame.arcs == 0) then return end
    if WoW.ReadValue(portrait.IsShown, portrait) ~= true or WoW.ReadValue(UnitIsPlayer, "target") ~= true then return end
    if IsClassPortrait(portrait) then return end

    local class = WoW.ReadValue(UnitClassBase, "target")
    local slot = type(class) == "string" and classSlots[class]
    if not slot then return end
    if paintedClass ~= class then
        local color = C_ClassColor and WoW.ReadValue(C_ClassColor.GetClassColor, class)
        if type(color) ~= "table" or not WoW.IsFiniteNumber(color.r) or not WoW.IsFiniteNumber(color.g)
            or not WoW.IsFiniteNumber(color.b) then return end
        for _, segment in ipairs(frame.arcs) do
            local shine = segment.highlight
            segment.line:SetColorTexture(color.r + (1 - color.r) * shine, color.g + (.86 - color.g) * shine,
                color.b + (.62 - color.b) * shine, segment.alpha)
        end
        if frame.icon then
            local x, y = (slot % 4) / 4, math.floor(slot / 4) / 4
            local inset = .5 / 256
            frame.icon:SetTexCoord(x + inset, x + .25 - inset, y + inset, y + .25 - inset)
        end
        paintedClass = class
    end
    frame:Show()
end

local function SetEnabled(enabled)
    local changed = db.enabled ~= enabled
    db.enabled = enabled
    if toggle then toggle:SetChecked(enabled) end
    if enabled and (changed or not driver:IsEventRegistered("PLAYER_TARGET_CHANGED")) then
        for _, event in ipairs(events) do driver:RegisterEvent(event) end
        driver:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "target")
    elseif not enabled then
        driver:UnregisterAllEvents()
    end
    Refresh()
end

function ns.InitializeTargetPortrait(root)
    if db then return end
    if type(ForeverTooltipLibreDB.targetPortrait) ~= "table" then ForeverTooltipLibreDB.targetPortrait = {} end
    db = ForeverTooltipLibreDB.targetPortrait
    driver = CreateFrame("Frame")
    driver:SetScript("OnEvent", function(_, event, name)
        if event == "CVAR_UPDATE" then
            if not WoW.IsPublic(name) or type(name) ~= "string" then return end
            name = name:lower()
            if name ~= "replaceotherplayerportraits" and name ~= "replacemyplayerportrait" then return end
        elseif event == "PLAYER_ENTERING_WORLD" then
            rejectedPortrait = nil
        end
        Refresh()
    end)

    local panel = CreateFrame("Frame", "ArkannsQOLTargetPortraitSettings", UIParent, "BackdropTemplate")
    UI.StylePanel(panel)
    UI.Label(panel, title, 16, -16, 18)
    toggle = UI.Check(panel, "ArkannsQOLTargetPortraitEnabled", L(toggleSource), 16, -52, SetEnabled)
    local help = UI.Label(panel, L("Si WoW remplace le portrait par l’icône de classe, désactive ce réglage dans les options de WoW pour retrouver le visage."), 20, -92)
    help:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    help:SetWordWrap(true)
    local category = Settings.RegisterCanvasLayoutSubcategory(root, panel, title)
    ns.RegisterModule("targetPortrait", {
        label = title, icon = "Interface\\Icons\\Achievement_Character_Human_Male",
        category = function() return category end,
        SearchSettings = {toggleSource},
        toggleLabel = L(toggleSource),
        Summary = function() return L("Liseré et emblème de classe sur le portrait de la cible.") end,
        IsEnabled = function() return db.enabled end,
        SetEnabled = SetEnabled,
        ExportSettings = function() return {enabled = db.enabled} end,
        ImportSettings = function(config)
            if type(config) ~= "table" or type(config.enabled) ~= "boolean" then return false end
            SetEnabled(config.enabled)
            return true
        end,
    })
    SetEnabled(db.enabled ~= false)
end
