local addonName, ns = ...
local L = ns.L
local WoW = ns.WoW

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
    background:SetSize(22, 22)
    background:SetPoint("TOPLEFT", 6, -4)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(background)
    local texture = C_AddOns and WoW.ReadValue(C_AddOns.GetAddOnMetadata, addonName, "IconTexture")
    if type(texture) ~= "string" or texture == "" or not icon:SetTexture(texture) then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
        icon:SetTexCoord(.05, .95, .05, .95)
    end
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
    function ns.IsMinimapVisible() return db.minimapHidden ~= true end
    function ns.SetMinimapVisible(value)
        db.minimapHidden = value ~= true
        button:SetShown(not db.minimapHidden)
    end
    ns.SetMinimapVisible(ns.IsMinimapVisible())
end

local function RegisterHome()
    local home = CreateFrame("Frame", "ArkannsQOLHome", UIParent, "BackdropTemplate")
    home:Hide()
    ns.home = home
    local root = Settings.RegisterCanvasLayoutCategory(home, "QoL Toolkit")
    Settings.RegisterAddOnCategory(root)
    if ns.UI.RegisterSettings then ns.UI.RegisterSettings("home", {category = function() return root end}) end
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
    "InitializeTargetPortrait",
    "InitializeBagSort",
    "InitializeFlightTimes",
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
