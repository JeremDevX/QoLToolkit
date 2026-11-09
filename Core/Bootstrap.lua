local addonName, ns = ...
local L = ns.L

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
    HomeText(L("/aqol : accueil • /ft options : infobulles\n/aqsession : journal • /aqbuild : talents • /arkrang : rangs"), -524)
    home:SetScript("OnShow", function()
        remindersButton:SetEnabled(ns.reminderCategory ~= nil)
        sessionButton:SetEnabled(ns.sessionCategory ~= nil)
        talentsButton:SetEnabled(ns.talentCategory ~= nil)
        advancedButton:SetEnabled(ns.advancedCategory ~= nil)
        ranksButton:SetEnabled(ns.rankGuardCategory ~= nil)
    end)
end

local function RegisterHome()
    local home = CreateFrame("Frame", "ArkannsQOLHome", UIParent, ns.UI and "BackdropTemplate" or nil)
    home:Hide()
    ns.home = home
    if not ns.UI then BuildFallbackHome(home) end
    local root = Settings.RegisterCanvasLayoutCategory(home, "QoL Toolkit")
    Settings.RegisterAddOnCategory(root)
    SLASH_ARKANNSQOL1 = "/aqol"
    SlashCmdList.ARKANNSQOL = function()
        if ns.StopAllPreviews then ns.StopAllPreviews() end
        Settings.OpenToCategory(root:GetID())
    end
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
    if firstRun then print(L("|cff33ccffQoL Toolkit :|r /aqol : options.")) end
end)
