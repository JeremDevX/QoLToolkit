local addonName, ns = ...
local L = ns.L
local WoW = ns.WoW

local function BuildFallbackHome(home)
    local function HomeText(text, y, font)
        local label = home:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
        label:SetPoint("TOPLEFT", 16, y)
        label:SetPoint("TOPRIGHT", -16, y)
        label:SetJustifyH("LEFT")
        label:SetText(text)
    end
    HomeText("QoL Toolkit", -16, "GameFontNormalLarge")
    HomeText(L("Choisis un module."), -52)
    local function HomeButton(name, text, y, callback)
        local button = CreateFrame("Button", name, home, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", 16, y)
        button:SetSize(240, 30)
        button:SetText(text)
        button:SetScript("OnClick", callback)
        return button
    end
    local remindersButton = HomeButton("ArkannsQOLHomeReminders", L("Rappels d'effets"), -94, function()
        if ns.reminderCategory then Settings.OpenToCategory(ns.reminderCategory:GetID()) end
    end)
    HomeText(L("Auras, buffs et suivis manquants."), -132)
    HomeButton("ArkannsQOLHomeTooltips", L("Infobulles"), -164, function()
        SlashCmdList.FOREVERTOOLTIPLIBRE("options")
    end)
    HomeText(L("Échelle, ancrage et suivi du curseur."), -202)
    local sessionButton = HomeButton("ArkannsQOLHomeSession", L("Journal de session"), -234, function()
        if ns.sessionCategory then Settings.OpenToCategory(ns.sessionCategory:GetID()) end
    end)
    HomeText(L("Temps de jeu, XP, or et morts."), -272)
    local talentsButton = HomeButton("ArkannsQOLHomeTalents", L("Builds de talents"), -304, function()
        if ns.talentCategory then Settings.OpenToCategory(ns.talentCategory:GetID()) end
    end)
    HomeText(L("Ton build, point par point et niveau par niveau."), -342)
    local advancedButton = HomeButton("ArkannsQOLHomeAdvanced", L("Réglages avancés"), -374, function()
        if ns.advancedCategory then Settings.OpenToCategory(ns.advancedCategory:GetID()) end
    end)
    HomeText(L("Options hors menus, par catégorie et inventaire du client."), -412)
    local ranksButton = HomeButton("ArkannsQOLHomeRanks", L("Rangs de sorts"), -444, function()
        if ns.rankGuardCategory then Settings.OpenToCategory(ns.rankGuardCategory:GetID()) end
    end)
    HomeText(L("Un ! sur les sorts dont un meilleur rang est déjà appris."), -482)
    HomeText(L("/qt : accueil • /qttooltip options : infobulles\n/aqsession : journal • /qtbuild : talents • /qtrank : rangs"), -524)
    home:SetScript("OnShow", function()
        remindersButton:SetEnabled(ns.reminderCategory ~= nil)
        sessionButton:SetEnabled(ns.sessionCategory ~= nil)
        talentsButton:SetEnabled(ns.talentCategory ~= nil)
        advancedButton:SetEnabled(ns.advancedCategory ~= nil)
        ranksButton:SetEnabled(ns.rankGuardCategory ~= nil)
    end)
end

local function RegisterMinimapButton(openHome)
    if not Minimap then return end

    local map = Minimap
    local db = ForeverTooltipLibreDB
    local angle = WoW.IsFiniteNumber(db.minimapAngle) and db.minimapAngle % (2 * math.pi) or math.rad(156)
    local button = CreateFrame("Button", "ArkannsQOLMinimapButton", map)
    button:SetSize(31, 31)
    button:SetFrameLevel(map:GetFrameLevel() + 8)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(background)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    icon:SetTexCoord(.05, .95, .05, .95)
    local mask = button:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(background)
    icon:AddMaskTexture(mask)
    background:AddMaskTexture(mask)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function UpdatePosition()
        local state, width, height = WoW.Read(map.GetSize, map)
        if state ~= "ok" or width <= 0 or height <= 0 then return end
        button:SetPoint("CENTER", map, "CENTER", math.cos(angle) * (width / 2 + 4), math.sin(angle) * (height / 2 + 4))
    end
    local function FollowCursor()
        local state, x, y = WoW.Read(map.GetCenter, map)
        local scale = WoW.ReadValue(map.GetEffectiveScale, map)
        if state ~= "ok" or not x or not y or not scale or scale <= 0 then return end
        local cursorX, cursorY = GetCursorPosition()
        local dx, dy = cursorX / scale - x, cursorY / scale - y
        if dx == 0 and dy == 0 then return end
        angle = math.atan2(dy, dx)
        UpdatePosition()
    end
    map:HookScript("OnSizeChanged", UpdatePosition)
    UpdatePosition()

    button:SetScript("OnClick", openHome)
    button:SetScript("OnEnter", function(self)
        if self:GetScript("OnUpdate") or not GameTooltip or GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QoL Toolkit")
        GameTooltip:AddLine(L("Glisse le bouton autour de la minicarte."), 1, 1, 1)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip and not GameTooltip:IsForbidden() and WoW.ReadValue(GameTooltip.GetOwner, GameTooltip) == self then
            GameTooltip:Hide()
        end
    end
    button:SetScript("OnLeave", HideTooltip)
    button:SetScript("OnDragStart", function(self)
        HideTooltip(self)
        self:SetScript("OnUpdate", FollowCursor)
    end)
    local function StopDrag(self)
        if not self:GetScript("OnUpdate") then return end
        self:SetScript("OnUpdate", nil)
        db.minimapAngle = angle
    end
    button:SetScript("OnDragStop", StopDrag)
    button:SetScript("OnHide", function(self)
        StopDrag(self)
        HideTooltip(self)
    end)
end

local function RegisterHome()
    local home = CreateFrame("Frame", "ArkannsQOLHome", UIParent, ns.UI and "BackdropTemplate" or nil)
    home:Hide()
    ns.home = home
    if not ns.UI then BuildFallbackHome(home) end
    local root = Settings.RegisterCanvasLayoutCategory(home, "QoL Toolkit")
    Settings.RegisterAddOnCategory(root)
    SLASH_ARKANNSQOL1 = "/qt"
    SLASH_ARKANNSQOL2 = "/aqol"
    local function OpenHome()
        if ns.StopAllPreviews then ns.StopAllPreviews() end
        Settings.OpenToCategory(root:GetID())
    end
    SlashCmdList.ARKANNSQOL = OpenHome
    RegisterMinimapButton(OpenHome)
    return root
end

local initializers = {
    "InitializeTooltips",
    "InitializeSessionJournal",
    "InitializeReminders",
    "InitializeTalentPlanner",
    "InitializeAdvancedSettings",
    "InitializeRankGuard",
    "InitializeTargetDistance",
    "InitializeBagSort",
    "InitializeInterface",
    "InitializeProfiles",
    "InitializeDiagnostics",
}

local events = CreateFrame("Frame", "ArkannsQOLBootstrapEvents")
local started
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
    if started or event ~= "ADDON_LOADED" or name ~= addonName then return end
    started = true
    self:UnregisterEvent("ADDON_LOADED")
    local firstRun = type(ForeverTooltipLibreDB) ~= "table"
    local ready, message = ns.SettingsState.Initialize()
    if not ready then
        print("|cff33ccffQoL Toolkit :|r " .. message)
        return
    end
    if ns.UI then ns.UI.Initialize() end
    local root = RegisterHome()
    local failures = {}
    for _, initializer in ipairs(initializers) do
        if ns[initializer] then
            local ok, reason = pcall(ns[initializer], root)
            if not ok then failures[#failures + 1] = initializer .. ": " .. tostring(reason) end
        end
    end
    if #failures > 0 then error(table.concat(failures, "\n")) end
    if firstRun then print(L("|cff33ccffQoL Toolkit :|r /qt : options.")) end
end)
