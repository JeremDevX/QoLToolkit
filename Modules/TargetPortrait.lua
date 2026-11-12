local _, ns = ...
local L, UI, WoW = ns.L, ns.UI, ns.WoW
local title = L("Portrait de cible")
local toggleSource = "Afficher le médaillon de classe"
local classTexture = "Interface\\WorldStateFrame\\Icons-Classes"
local circleMask = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- Zero-based cells in the native 4 × 4 texture. Forever has nine classes.
local classSlots = {WARRIOR = 0, MAGE = 1, ROGUE = 2, DRUID = 3,
    HUNTER = 4, SHAMAN = 5, PRIEST = 6, WARLOCK = 7, PALADIN = 8}
local events = {"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "CVAR_UPDATE"}
local db, driver, overlay, toggle
local anchoredPortrait, rejectedPortrait, paintedClass

local function MaskCircle(frame, texture, size)
    local mask = frame:CreateMaskTexture()
    -- Same circular mask as Forever's target portrait (FrameXML 9dc84f0).
    if C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, "CircleMask") then
        mask:SetAtlas("CircleMask", false, "LINEAR", true, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    elseif not mask:SetTexture(circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
        return false
    end
    mask:SetPoint("CENTER", frame, "CENTER")
    mask:SetSize(size, size)
    texture:SetPoint("CENTER", frame, "CENTER")
    texture:SetSize(size, size)
    texture:AddMaskTexture(mask)
    return true
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
        overlay:SetSize(28, 28)
        if overlay.CreateMaskTexture then
            local outline = overlay:CreateTexture(nil, "BACKGROUND")
            outline:SetColorTexture(.025, .02, .015, .95)
            local rim = overlay:CreateTexture(nil, "BORDER")
            rim:SetColorTexture(1, 1, 1, 1)
            rim:SetGradient("VERTICAL", CreateColor(.38, .38, .38, 1), CreateColor(1, 1, 1, 1))
            local background = overlay:CreateTexture(nil, "ARTWORK")
            background:SetColorTexture(.055, .045, .035, 1)
            background:SetGradient("VERTICAL", CreateColor(.45, .45, .45, 1), CreateColor(1, 1, 1, 1))
            local icon = overlay:CreateTexture(nil, "OVERLAY")
            if MaskCircle(overlay, outline, 28) and MaskCircle(overlay, rim, 26)
                and MaskCircle(overlay, background, 23) and MaskCircle(overlay, icon, 20)
                and icon:SetTexture(classTexture) then
                overlay.rim, overlay.icon = rim, icon
            end
        end
    end
    overlay:SetParent(container)
    overlay:SetFrameLevel(level + 1)
    overlay:ClearAllPoints()
    anchoredPortrait = nil
    -- Sit on the upper-right rim, clear of the central raid marker and lower PvP/level badges.
    if not pcall(overlay.SetPoint, overlay, "CENTER", portrait, "CENTER", 25, 24) then
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
    if not frame or not frame.icon then return end
    if WoW.ReadValue(portrait.IsShown, portrait) ~= true or WoW.ReadValue(UnitIsPlayer, "target") ~= true then return end
    if IsClassPortrait(portrait) then return end

    local class = WoW.ReadValue(UnitClassBase, "target")
    local slot = type(class) == "string" and classSlots[class]
    if not slot then return end
    if paintedClass ~= class then
        local color = C_ClassColor and WoW.ReadValue(C_ClassColor.GetClassColor, class)
        if type(color) ~= "table" or not WoW.IsFiniteNumber(color.r) or not WoW.IsFiniteNumber(color.g)
            or not WoW.IsFiniteNumber(color.b) then return end
        frame.rim:SetVertexColor(.18 + .82 * color.r, .18 + .82 * color.g, .18 + .82 * color.b)
        local x, y = (slot % 4) / 4, math.floor(slot / 4) / 4
        local inset = .5 / 256
        frame.icon:SetTexCoord(x + inset, x + .25 - inset, y + inset, y + .25 - inset)
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
    local category = UI.RegisterSettingsPanel(root, panel, title, "targetPortrait")
    ns.RegisterModule("targetPortrait", {
        label = title, icon = "Interface\\Icons\\Achievement_Character_Human_Male",
        category = function() return category end,
        SearchSettings = {toggleSource},
        toggleLabel = L(toggleSource),
        Summary = function() return L("Médaillon de classe à bordure colorée sur le portrait de la cible.") end,
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
