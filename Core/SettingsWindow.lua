local _, ns = ...
-- Forever 70888 (4cd0ab7): SimpleFrameAPI resize methods and
-- Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua (UISpecialFrames).
local UI, L = ns.UI, ns.L
local pages, window, active, content = {}, nil, nil, nil
local groups = {
    {id = "home", label = L("Accueil"), pages = {"home"}},
    {id = "character", label = L("Personnage"), pages = {"talents", "session", "reminders", "ranks"}},
    {id = "interface", label = L("Interface"), pages = {"tooltips", "distance", "targetPortrait", "bags"}},
    {id = "appearance", label = L("Personnalisation"), pages = {"appearance"}},
    {id = "tools", label = L("Outils"), pages = {"flights", "advanced", "profiles", "diagnostics"}},
}
local mainTabs, subTabs, selected = {}, {}, {}
local Layout

-- Blizzard owns only these launchers. The real canvases always belong to our window.
function UI.RegisterSettingsPanel(parent, panel, label, id)
    local launcher = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    launcher:Hide()
    UI.StylePanel(launcher)
    UI.Label(launcher, "QoL Toolkit", 20, -20, 20)
    UI.Button(launcher, nil, L("Ouvrir les réglages"), 20, -60, 240, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        UI.OpenSettings(id)
    end)
    local category
    if parent then category = Settings.RegisterCanvasLayoutSubcategory(parent, launcher, label)
    else category = Settings.RegisterCanvasLayoutCategory(launcher, label) end
    pages[id] = {id = id, panel = panel, label = label, category = category}
    return category
end

local function PageGroup(id)
    for _, group in ipairs(groups) do
        for _, pageID in ipairs(group.pages) do if pageID == id then return group end end
    end
end

local function CreateTab(name, text, callback)
    -- Match the flat category tabs in Advanced Settings, including their font.
    local button = CreateFrame("Button", name, window)
    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.label = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    button.label:SetAllPoints()
    button.label:SetText(text)
    button.marker = button:CreateTexture(nil, "OVERLAY")
    button.marker:SetPoint("BOTTOMLEFT", 0, 0)
    button.marker:SetPoint("BOTTOMRIGHT", 0, 0)
    button.marker:SetHeight(2)
    button.marker:SetColorTexture(1, .72, .2, 1)
    button:SetScript("OnClick", callback)
    return button
end

local function PlaceTabs(tabs, y)
    local width, minimum = window:GetWidth() - 32, 90
    for _, tab in ipairs(tabs) do
        minimum = math.max(minimum, tab.button.label:GetUnboundedStringWidth() + 24)
    end
    local columns = math.max(1, math.min(#tabs, math.floor(width / minimum)))
    local tabWidth = width / columns
    for index, tab in ipairs(tabs) do
        local button = tab.button
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 16 + ((index - 1) % columns) * tabWidth, y - math.floor((index - 1) / columns) * 32)
        button:SetSize(tabWidth - 2, 28)
    end
    return y - math.ceil(#tabs / columns) * 32 - 4
end

Layout = function()
    if not active then return end
    local page, group = pages[active], PageGroup(active)
    local visibleMain, visibleSub = {}, {}
    local function Update(tab, isActive)
        tab.button:SetEnabled(not isActive)
        tab.button.background:SetColorTexture(isActive and .24 or .09, isActive and .19 or .09, .09, .95)
        tab.button.label:SetTextColor(1, isActive and .82 or .95, isActive and .38 or .95)
        tab.button.marker:SetShown(isActive)
    end
    for _, tab in ipairs(mainTabs) do
        local available = false
        for _, id in ipairs(tab.group.pages) do if pages[id] then available = true end end
        tab.button:SetShown(available)
        if available then visibleMain[#visibleMain + 1] = tab end
        Update(tab, tab.group == group)
    end
    local count = 0
    for _, id in ipairs(group.pages) do if pages[id] then count = count + 1 end end
    for _, tab in ipairs(subTabs) do
        local visible = count > 1 and PageGroup(tab.id) == group
        tab.button:SetShown(visible)
        if visible then visibleSub[#visibleSub + 1] = tab end
        Update(tab, tab.id == active)
    end
    local y = PlaceTabs(visibleMain, -46)
    if #visibleSub > 0 then y = PlaceTabs(visibleSub, y) end
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", 12, y - 2)
    -- Explicit dimensions also let each existing canvas recalculate its scroll range.
    content:SetSize(math.max(1, window:GetWidth() - 24), math.max(1, window:GetHeight() + y - 40))
    page.panel:SetSize(content:GetWidth(), content:GetHeight())
end

function UI.FitSettingsWindow()
    if not window then return end
    local width, height = math.max(320, UIParent:GetWidth() - 24), math.max(240, UIParent:GetHeight() - 24)
    window:SetResizeBounds(math.min(600, width), math.min(480, height), width, height)
    window:SetSize(math.min(window:GetWidth(), width), math.min(window:GetHeight(), height))
    Layout()
end

local function BuildWindow()
    window = CreateFrame("Frame", "ArkannsQOLSettingsWindow", UIParent, "BackdropTemplate")
    window:Hide()
    window:SetSize(math.min(980, UIParent:GetWidth() - 24), math.min(740, UIParent:GetHeight() - 24))
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetResizable(true)
    window:EnableMouse(true)
    UI.StylePanel(window)
    local titleBar = CreateFrame("Frame", nil, window)
    titleBar:SetPoint("TOPLEFT", 8, -4); titleBar:SetPoint("TOPRIGHT", -110, -4); titleBar:SetHeight(36)
    titleBar:EnableMouse(true); titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() window:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    UI.Label(titleBar, "QoL Toolkit", 8, -8, 20)
    local close = UI.Button(window, "ArkannsQOLSettingsClose", L("Fermer"), 0, 0, 90, function() window:Hide() end)
    close:ClearAllPoints(); close:SetPoint("TOPRIGHT", -12, -10)
    local hint = UI.Label(window, L("Glisse le titre pour déplacer la fenêtre."), 16, 0, 12)
    hint:ClearAllPoints(); hint:SetPoint("BOTTOMLEFT", 16, 14)
    hint:SetPoint("BOTTOMRIGHT", -100, 14); hint:SetJustifyH("LEFT")
    local resize = UI.Button(window, "ArkannsQOLSettingsResize", L("Taille"), 0, 0, 70, function() end)
    resize:ClearAllPoints(); resize:SetPoint("BOTTOMRIGHT", -12, 8)
    resize:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then window:StartSizing("BOTTOMRIGHT") end end)
    resize:SetScript("OnMouseUp", function() window:StopMovingOrSizing() end)
    content = CreateFrame("Frame", nil, window)
    for _, group in ipairs(groups) do
        local owner = group
        mainTabs[#mainTabs + 1] = {group = owner, button = CreateTab("ArkannsQOLSettingsTab_" .. owner.id, owner.label, function()
            local id = selected[owner.id]
            if not id then for _, candidate in ipairs(owner.pages) do if pages[candidate] then id = candidate; break end end end
            if id then UI.OpenSettings(id) end
        end)}
        for _, id in ipairs(group.pages) do
            local page = pages[id]
            if page then
                subTabs[#subTabs + 1] = {id = id, button = CreateTab("ArkannsQOLSettingsSubTab_" .. id, page.label, function() UI.OpenSettings(id) end)}
                page.panel:Hide()
                page.panel:SetParent(content)
                page.panel:ClearAllPoints(); page.panel:SetPoint("TOPLEFT", content, "TOPLEFT")
            end
        end
    end
    window:SetScript("OnSizeChanged", Layout)
    window:SetScript("OnHide", function()
        window:StopMovingOrSizing()
        if active then pages[active].panel:Hide() end
        ns.StopAllPreviews()
    end)
    table.insert(UISpecialFrames, "ArkannsQOLSettingsWindow")
    UI.FitSettingsWindow()
end

function UI.OpenCategory(category)
    local destination
    for _, page in pairs(pages) do if page.category == category then destination = page; break end end
    if not destination then return false end
    if not window then BuildWindow() end
    if active ~= destination.id then
        ns.StopAllPreviews()
        if active then pages[active].panel:Hide() end
    end
    active = destination.id
    selected[PageGroup(active).id] = active
    window:Show()
    Layout()
    destination.panel:Show()
    return true
end

function UI.HideSettingsWindow()
    if window then window:Hide() end
end

function UI.RefreshSettingsWindow()
    if window then Layout() end
end
