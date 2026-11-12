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
local navigation, navigationBody, breadcrumb, titleBar, searchButton, sidebarPage
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
    pages[id] = {id = id, panel = panel, label = id == "home" and L("Accueil") or label, category = category}
    return category
end

local function PageGroup(id)
    for _, group in ipairs(groups) do
        for _, pageID in ipairs(group.pages) do if pageID == id then return group end end
    end
end

local function CreateTab(name, text, callback)
    local button = CreateFrame("Button", name, window)
    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.label = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    button.label:SetPoint("TOPLEFT", 12, -6)
    button.label:SetPoint("TOPRIGHT", -12, -6)
    button.label:SetText(text)
    button.label:SetWordWrap(true)
    button.marker = button:CreateTexture(nil, "OVERLAY")
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
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
        button:SetParent(window)
        button.label:SetJustifyH("CENTER")
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 16 + ((index - 1) % columns) * tabWidth, y - math.floor((index - 1) / columns) * 32)
        button:SetSize(tabWidth - 2, 28)
    end
    return y - math.ceil(#tabs / columns) * 32 - 4
end

Layout = function()
    if not active then return end
    local page, group = pages[active], PageGroup(active)
    local style = UI.GetStyle()
    -- Reserve enough width for the longest localized page name and the canvas.
    local navigationWidth = 200
    for _, tab in ipairs(subTabs) do
        tab.button.label:SetFont(style.font, 12, "")
        navigationWidth = math.max(navigationWidth, tab.button.label:GetUnboundedStringWidth() + 56)
    end
    navigationWidth = math.min(260, navigationWidth)
    local sidebar = window:GetWidth() >= math.max(900, navigationWidth + 650)
    navigation:SetShown(sidebar)
    searchButton:SetShown(window:GetWidth() >= 520)
    titleBar:SetPoint("TOPRIGHT", window:GetWidth() >= 520 and -250 or -110, -4)
    local visibleMain, visibleSub = {}, {}
    local function Update(tab, isActive, vertical)
        local button = tab.button
        tab.button:SetEnabled(not isActive)
        local color = isActive and style.accent or style.text
        button.label:SetFont(style.font, 12, "")
        button.label:SetTextColor(unpack(color))
        button.background:SetColorTexture(style.accent[1], style.accent[2], style.accent[3], isActive and .16 or .035)
        button:GetHighlightTexture():SetVertexColor(style.accent[1], style.accent[2], style.accent[3], .12)
        button.marker:ClearAllPoints()
        button.marker:SetPoint(vertical and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
        if vertical then
            button.marker:SetPoint("BOTTOMLEFT", 0, 0); button.marker:SetWidth(3)
        else
            button.marker:SetPoint("BOTTOMRIGHT", 0, 0); button.marker:SetHeight(2)
        end
        button.marker:SetColorTexture(style.accent[1], style.accent[2], style.accent[3], 1)
        button.marker:SetShown(isActive)
    end
    for _, tab in ipairs(mainTabs) do
        local available = false
        for _, id in ipairs(tab.group.pages) do if pages[id] then available = true end end
        tab.button:SetShown(available and not sidebar)
        if available then visibleMain[#visibleMain + 1] = tab end
        Update(tab, tab.group == group)
        tab.heading:SetShown(available and sidebar and tab.group.id ~= "home")
        tab.heading:SetTextColor(style.accent[1], style.accent[2], style.accent[3], .85)
    end
    local count = 0
    for _, id in ipairs(group.pages) do if pages[id] then count = count + 1 end end
    for _, tab in ipairs(subTabs) do
        local visible = sidebar or (count > 1 and PageGroup(tab.id) == group)
        tab.button:SetShown(visible)
        if visible then visibleSub[#visibleSub + 1] = tab end
        Update(tab, tab.id == active, sidebar)
    end
    local x, y = 12, -60
    if sidebar then
        navigation:SetSize(navigationWidth - 24, math.max(1, window:GetHeight() - 104))
        local top, buttonWidth, activeButton = 0, navigationWidth - 24
        for _, tab in ipairs(visibleMain) do
            if tab.group.id ~= "home" then
                tab.heading:ClearAllPoints(); tab.heading:SetPoint("TOPLEFT", 8, -top)
                tab.heading:SetWidth(buttonWidth - 8)
                top = top + tab.heading:GetStringHeight() + 6
            end
            for _, item in ipairs(subTabs) do
                if PageGroup(item.id) == tab.group then
                    local button = item.button
                    button:SetParent(navigationBody)
                    button.label:SetJustifyH("LEFT")
                    button:SetWidth(buttonWidth)
                    local height = math.max(30, button.label:GetStringHeight() + 12)
                    button:ClearAllPoints(); button:SetPoint("TOPLEFT", 0, -top)
                    button:SetSize(buttonWidth, height)
                    if item.id == active then activeButton = button end
                    top = top + height + 2
                end
            end
            top = top + 12
        end
        navigationBody:SetSize(buttonWidth, top)
        UI.ClampScroll(navigation, top)
        if sidebarPage ~= active then UI.RevealControl(navigation, activeButton) end
        sidebarPage = active
        x = navigationWidth + 24
    else
        sidebarPage = nil
        y = PlaceTabs(visibleMain, y)
        if #visibleSub > 0 then y = PlaceTabs(visibleSub, y) end
    end
    breadcrumb:SetText(group.label == page.label and page.label or group.label .. "  /  " .. page.label)
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", x, y - 2)
    -- Explicit dimensions also let each existing canvas recalculate its scroll range.
    content:SetSize(math.max(1, window:GetWidth() - x - 12), math.max(1, window:GetHeight() + y - 40))
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
    titleBar = CreateFrame("Frame", nil, window)
    titleBar:SetPoint("TOPLEFT", 8, -4); titleBar:SetPoint("TOPRIGHT", -250, -4); titleBar:SetHeight(48)
    titleBar:EnableMouse(true); titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() window:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    UI.Label(titleBar, "QoL Toolkit", 8, -8, 20)
    breadcrumb = UI.Label(titleBar, "", 8, -32, 12)
    breadcrumb:SetPoint("TOPRIGHT", -8, -32)
    breadcrumb:SetWordWrap(false)
    searchButton = UI.Button(window, "ArkannsQOLSettingsSearch", L("Rechercher"), 0, 0, 120, function()
        if UI.OpenSettings("home") and UI.FocusSettingsSearch then UI.FocusSettingsSearch() end
    end)
    searchButton:ClearAllPoints(); searchButton:SetPoint("TOPRIGHT", -110, -10)
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
    navigation = CreateFrame("ScrollFrame", "ArkannsQOLSettingsNavigation", window, "UIPanelScrollFrameTemplate")
    navigation:SetPoint("TOPLEFT", 16, -62)
    navigationBody = CreateFrame("Frame", nil, navigation)
    navigationBody:SetSize(1, 1); navigation:SetScrollChild(navigationBody)
    for _, group in ipairs(groups) do
        local owner = group
        mainTabs[#mainTabs + 1] = {group = owner, heading = UI.Label(navigationBody, owner.label, 0, 0, 12), button = CreateTab("ArkannsQOLSettingsTab_" .. owner.id, owner.label, function()
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
