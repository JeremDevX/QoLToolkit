local _, ns = ...
local L = ns.L
ns.modules = {}
local UI = {}
ns.UI = UI
local config, previewBar, previewModule, layout, home, appearanceRefresh
local styledPanels, styledButtons, styledLabels = {}, {}, {}
local moduleOrder = {"tooltips", "reminders", "session", "talents", "ranks", "distance", "bags", "advanced"}
local solidTexture = "Interface\\Buttons\\WHITE8X8"
local borders = {
    theme = {label = L("Selon le thème")},
    tooltip = {label = L("Cadre d’infobulle"), edge = "Interface\\Tooltips\\UI-Tooltip-Border", size = 12, inset = 3},
    blizzard = {label = L("Cadre Blizzard"), edge = "Interface\\DialogFrame\\UI-DialogBox-Border", size = 20, insetScale = .35},
    flat = {label = L("Trait simple"), edge = solidTexture, size = 1, insetScale = 1},
    none = {label = L("Sans bordure")},
}
local defaults = {theme = "warm", border = "theme", bg = {.12, .065, .025}, text = {1, .94, .8}, accent = {1, .76, .3},
    font = "standard", fontSize = 13, scale = 1, opacity = .85, borderSize = borders.tooltip.size, padding = 12, gap = 6,
    overrides = {}, pins = {}, grid = true, snap = true}
local themes = {
    warm = {label = L("Chaleureux"), settings = defaults, border = "tooltip"},
    blizzard = {label = L("Blizzard classique"), border = "blizzard",
        settings = {bg = {.24, .23, .21}, text = {1, .98, .9}, accent = {1, .82, .45},
            font = "standard", opacity = .96},
        background = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", tileSize = 32},
    modern = {label = L("Mode sombre moderne"), border = "flat",
        settings = {bg = {.065, .075, .095}, text = {.92, .94, .98}, accent = {.53, .7, .98},
            font = "narrow", opacity = .96},
        background = solidTexture},
}
local fonts = {standard = "Fonts\\FRIZQT__.TTF", narrow = "Fonts\\ARIALN.TTF", fantasy = "Fonts\\MORPHEUS.TTF"}
local bounds = {fontSize = {10, 24}, scale = {.6, 1.6}, opacity = {0, 1}, borderSize = {1, 24}, padding = {4, 24}, gap = {0, 20}}

local function Copy(value, depth)
    depth = depth or 0
    if depth > 10 then return nil end
    if type(value) ~= "table" then
        if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then return value end
        return nil
    end
    local result = {}
    for key, item in pairs(value) do
        if type(key) == "string" or type(key) == "number" then result[key] = Copy(item, depth + 1) end
    end
    return result
end
UI.Copy = Copy
local function Number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function Normalize(value)
    value = type(value) == "table" and value or {}
    local result = Copy(defaults)
    if themes[value.theme] then result.theme = value.theme end
    if borders[value.border] then result.border = value.border end
    for key, range in pairs(bounds) do
        if Number(value[key]) and value[key] >= range[1] and value[key] <= range[2] then result[key] = value[key] end
    end
    if fonts[value.font] then result.font = value.font end
    for _, key in ipairs({"bg", "text", "accent"}) do
        local color = value[key]
        if type(color) == "table" and Number(color[1]) and Number(color[2]) and Number(color[3]) then
            result[key] = {math.max(0, math.min(1, color[1])), math.max(0, math.min(1, color[2])), math.max(0, math.min(1, color[3]))}
        end
    end
    for _, key in ipairs({"overrides", "pins"}) do
        if type(value[key]) == "table" then for id, enabled in pairs(value[key]) do
            if type(id) == "string" and type(enabled) == "boolean" then result[key][id] = enabled end
        end end
    end
    for _, key in ipairs({"grid", "snap"}) do if type(value[key]) == "boolean" then result[key] = value[key] end end
    return result
end
function UI.Initialize()
    config = Normalize(ForeverTooltipLibreDB.ui)
    ForeverTooltipLibreDB.ui = config
end
function UI.IsOverride(id) return config and config.overrides[id] == true or false end
function UI.GetStyle(id)
    if not config then return nil end
    if id and UI.IsOverride(id) then return nil end
    local style = Copy(config)
    style.font = fonts[config.font]
    style.borderAlpha = .7
    return style
end
function UI.ExportSettings() return Copy(config or defaults) end
local function GetBorder(style)
    return borders[style.border == "theme" and themes[style.theme].border or style.border]
end
local function ApplySkin(frame, style)
    local theme = themes[style.theme]
    local border = GetBorder(style)
    local inset = border.inset or math.floor(style.borderSize * (border.insetScale or 0))
    frame:SetBackdrop({bgFile = theme.background or "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = border.edge, tile = style.theme ~= "modern",
        tileSize = theme.tileSize or 16, edgeSize = style.borderSize, insets = {left = inset, right = inset, top = inset, bottom = inset}})
    frame:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], style.opacity)
    frame:SetBackdropBorderColor(style.accent[1], style.accent[2], style.accent[3], .7)
end
function UI.StyleFrame(frame, id)
    local style = UI.GetStyle(id)
    if not frame or not style then return end
    if frame.SetBackdrop then ApplySkin(frame, style) end
end
function UI.StylePanel(panel)
    if not config or not panel then return end
    -- Settings reparents canvases when switching categories. A separate child
    -- frame can move above their text; backdrop textures stay behind the content.
    styledPanels[panel] = true
    ApplySkin(panel, UI.GetStyle())
end
function UI.StyleButton(button)
    if not config or not button then return end
    styledButtons[button] = true
    if button.SetNormalTexture then
        button:SetNormalTexture(solidTexture)
        local normal = button:GetNormalTexture()
        if config.theme == "blizzard" then
            -- Let UIPanelButtonTemplate draw its own three-piece artwork.
            local native = button.Left and button.Middle and button.Right
            normal:SetVertexColor(.30, .08, .04, native and 0 or .95)
        elseif config.theme == "modern" then
            normal:SetVertexColor(.14, .16, .21, .95)
        else
            normal:SetVertexColor(math.min(1,config.bg[1]+.1), math.min(1,config.bg[2]+.065), math.min(1,config.bg[3]+.035), .95)
        end
        button:SetHighlightTexture(solidTexture)
        button:GetHighlightTexture():SetVertexColor(config.accent[1], config.accent[2], config.accent[3], .18)
    end
    if button.GetFontString then
        local text = button:GetFontString()
        if text then text:SetTextColor(unpack(config.text)); text:SetFont(fonts[config.font], 12, "") end
    end
end
function UI.SetFavoriteIcon(button, active)
    if not button.favoriteIcon then
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18); icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\Common\\FavoritesIcon")
        icon:SetTexCoord(.03125, .8125, .03125, .8125)
        button.favoriteIcon = icon
        button:SetText("")
    end
    button.favoriteIcon:SetAlpha(active and 1 or .45)
end
function UI.Refresh()
    if previewBar then UI.StyleFrame(previewBar) end
    for panel in pairs(styledPanels) do UI.StylePanel(panel) end
    for button in pairs(styledButtons) do UI.StyleButton(button) end
    for label, size in pairs(styledLabels) do label:SetFont(fonts[config.font],size,""); label:SetTextColor(unpack(config.text)) end
    for _, module in pairs(ns.modules) do if module.Refresh then pcall(module.Refresh) end end
    if home and home.Refresh then home.Refresh() end
    if appearanceRefresh then appearanceRefresh() end
end
function UI.ImportSettings(value)
    if type(value) ~= "table" then return false, L("Apparence invalide.") end
    local normalized = Normalize(value)
    for key in pairs(config) do config[key] = nil end
    for key,item in pairs(normalized) do config[key] = item end
    UI.Refresh()
    return true
end
function UI.SetOverride(id, enabled)
    config.overrides[id] = enabled == true
    local module = ns.modules[id]
    if module and module.Refresh then module.Refresh() end
    if appearanceRefresh then appearanceRefresh() end
end
function ns.RegisterModule(id, descriptor)
    ns.modules[id] = descriptor
end
local function Label(parent, text, x, y, size)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y); label:SetJustifyH("LEFT"); label:SetText(text)
    local style = UI.GetStyle()
    label:SetFont(style.font, size or 13, ""); label:SetTextColor(unpack(style.text))
    styledLabels[label] = size or 13
    return label
end
local function Button(parent, name, text, x, y, width, callback)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26); button:SetPoint("TOPLEFT", x, y); button:SetText(text)
    button:SetScript("OnClick", callback); UI.StyleButton(button)
    return button
end
local function Check(parent, name, text, x, y, callback)
    local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y); check.label = Label(check, text, 32, -6)
    check:SetScript("OnClick", function(self) callback(self:GetChecked() == true) end)
    return check
end
local function Input(parent, name, x, y, width)
    local input = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", x, y); input:SetSize(width or 70, 24); input:SetAutoFocus(false); input:SetMaxLetters(40)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return input
end
UI.Label, UI.Button, UI.Check, UI.Input = Label, Button, Check, Input

function UI.Notify(message)
    if message then print("|cff33ccffQoL Toolkit :|r " .. message) end
end

function UI.Confirm(text, onAccept)
    if ns.WoW.ReadValue(InCombatLockdown) ~= false then
        UI.Notify(L("Action disponible hors combat.")); return false
    end
    if type(StaticPopup_ShowGenericConfirmation) ~= "function" then
        UI.Notify(L("Confirmation indisponible sur ce client.")); return false
    end
    StaticPopup_ShowGenericConfirmation(text, function()
        if ns.WoW.ReadValue(InCombatLockdown) == false then onAccept()
        else UI.Notify(L("Action disponible hors combat.")) end
    end)
    return true
end

function UI.PreviewEnded(id)
    if previewModule ~= id then return end
    previewModule = nil
    if previewBar then previewBar:Hide() end
end

local function StopModulePreviews()
    for _, module in pairs(ns.modules) do if module.StopPreview then pcall(module.StopPreview) end end
    previewModule = nil
    if previewBar then previewBar:Hide() end
end
function ns.StopAllPreviews()
    if UI.layoutActive then UI.EndLayout(true) else StopModulePreviews() end
end
function UI.PreviewModule(id)
    ns.StopAllPreviews()
    local module = ns.modules[id]
    if not module or not module.Preview then return false end
    if ns.WoW.ReadValue(InCombatLockdown) ~= false then
        UI.Notify(L("Aperçu disponible hors combat.")); return false
    end
    local started, reason = module.Preview()
    if started ~= true then UI.Notify(reason or L("Aperçu indisponible.")); return false end
    previewModule = id
    if not previewBar then
        previewBar = CreateFrame("Frame", "ArkannsQOLPreviewBar", UIParent, "BackdropTemplate")
        previewBar:SetSize(250, 42); previewBar:SetPoint("TOP", UIParent, "TOP", 0, -25)
        previewBar:SetFrameStrata("DIALOG")
        Button(previewBar, "ArkannsQOLStopPreviews", L("Arrêter les aperçus"), 12, -8, 226, ns.StopAllPreviews)
    end
    UI.StyleFrame(previewBar)
    previewBar:Show()
    return true
end

-- Movers are owned frames. Never move or restyle Blizzard's protected action buttons.
local movers, savedPositions, savedLayouts, changedPositions, selected = {}, {}, {}, {}, nil
local endingLayout
local function PositionMover(mover, x, y)
    mover:ClearAllPoints(); mover:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * UIParent:GetWidth(), y * UIParent:GetHeight())
end
function UI.SnapPosition(id, x, y)
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not Number(x) or not Number(y) or width <= 0 or height <= 0 then return nil end
    local mover = movers[id]
    local halfW, halfH = mover and mover:GetWidth() / 2 or 0, mover and mover:GetHeight() / 2 or 0
    local px, py = x * width, y * height
    if config.grid then px, py = math.floor(px / 16 + .5) * 16, math.floor(py / 16 + .5) * 16 end
    if config.snap then
        local xs, ys = {halfW, width / 2, width - halfW}, {halfH, height / 2, height - halfH}
        for otherId, other in pairs(movers) do if otherId ~= id and other:IsShown() then
            local ox, oy = other:GetCenter()
            if Number(ox) and Number(oy) then
                xs[#xs + 1], xs[#xs + 2], xs[#xs + 3] = ox, ox + other:GetWidth()/2 + halfW, ox - other:GetWidth()/2 - halfW
                ys[#ys + 1], ys[#ys + 2], ys[#ys + 3] = oy, oy + other:GetHeight()/2 + halfH, oy - other:GetHeight()/2 - halfH
            end
        end end
        local dx, dy = 9, 9
        for _, target in ipairs(xs) do if math.abs(target - px) < dx then dx, x = math.abs(target - px), target end end
        for _, target in ipairs(ys) do if math.abs(target - py) < dy then dy, y = math.abs(target - py), target end end
        if dx < 9 then px = x end
        if dy < 9 then py = y end
    end
    return math.max(math.min(halfW / width, .5), math.min(math.max(1 - halfW / width, .5), px / width)),
        math.max(math.min(halfH / height, .5), math.min(math.max(1 - halfH / height, .5), py / height))
end
local function UpdateCoordinates()
    if not layout or not selected then return end
    local module = ns.modules[selected]
    local x, y = module.GetPosition()
    layout.selection:SetText(module.label)
    layout.x:SetText(string.format("%.2f", x * 100)); layout.y:SetText(string.format("%.2f", y * 100))
end
local function SaveMover(id)
    local mover, module = movers[id], ns.modules[id]
    mover:StopMovingOrSizing(); mover.moving = false
    local x, y = mover:GetCenter()
    if Number(x) and Number(y) then
        x, y = UI.SnapPosition(id, x / UIParent:GetWidth(), y / UIParent:GetHeight())
        if x then changedPositions[id] = true; module.SetPosition(x, y); PositionMover(mover, x, y) end
    end
    UpdateCoordinates()
end
function UI.EndLayout(cancel)
    if not UI.layoutActive or endingLayout then return end
    endingLayout = true
    for id, mover in pairs(movers) do
        if mover.moving then SaveMover(id) end
        mover:Hide()
    end
    local positions = {}
    for id in pairs(savedPositions) do
        local x,y=ns.modules[id].GetPosition(); positions[id]={x,y}
    end
    UI.layoutActive = false
    if layout then layout:Hide(); layout.guides:Hide() end
    StopModulePreviews()
    for id, position in pairs(savedPositions) do
        local module = ns.modules[id]
        if cancel or not changedPositions[id] then
            if savedLayouts[id] and module.ImportSettings then module.ImportSettings(savedLayouts[id])
            elseif changedPositions[id] then module.SetPosition(position[1], position[2]) end
        else module.SetPosition(positions[id][1], positions[id][2]) end
    end
    endingLayout = nil
    if ns.Diagnostics then ns.Diagnostics.Note(cancel and "layout.cancel" or "layout.apply") end
end
function UI.StartLayout(focusId)
    if ns.WoW.ReadValue(InCombatLockdown) ~= false then
        local reason = L("Disposition disponible hors combat.")
        UI.Notify(reason); return false, reason
    end
    if type(focusId) ~= "string" then focusId = nil end
    ns.StopAllPreviews()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if not layout then
        layout = CreateFrame("Frame", "ArkannsQOLLayout", UIParent, "BackdropTemplate")
        layout:SetSize(620, 150); layout:SetPoint("TOP", UIParent, "TOP", 0, -28)
        layout:SetFrameStrata("DIALOG"); layout:SetFrameLevel(30); layout:SetClampedToScreen(true)
        Label(layout, L("Disposition — glisse les cadres"), 16, -12, 16)
        Button(layout, "ArkannsQOLLayoutApply", L("Valider"), 16, -42, 110, function() UI.EndLayout(false) end)
        Button(layout, "ArkannsQOLLayoutCancel", L("Annuler"), 136, -42, 110, function() UI.EndLayout(true) end)
        Button(layout, "ArkannsQOLLayoutCenter", L("Recentrer"), 256, -42, 110, function()
            if selected then changedPositions[selected] = true; ns.modules[selected].SetPosition(.5, .5); PositionMover(movers[selected], .5, .5); UpdateCoordinates() end
        end)
        layout.grid = Check(layout, "ArkannsQOLLayoutGrid", L("Grille"), 12, -78, function(value)
            config.grid = value; layout.guides:SetShown(value)
        end)
        layout.snap = Check(layout, "ArkannsQOLLayoutSnap", L("Accrochage"), 120, -78, function(value) config.snap = value end)
        layout.selection = Label(layout, "", 16, -119)
        Label(layout, "X %", 260, -86); layout.x = Input(layout, "ArkannsQOLLayoutX", 295, -80, 60)
        Label(layout, "Y %", 366, -86); layout.y = Input(layout, "ArkannsQOLLayoutY", 402, -80, 60)
        local function ApplyCoordinates()
            local x, y = tonumber((layout.x:GetText():gsub(",", "."))), tonumber((layout.y:GetText():gsub(",", ".")))
            if selected and Number(x) and Number(y) and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                x, y = UI.SnapPosition(selected, x/100, y/100)
                changedPositions[selected] = true
                ns.modules[selected].SetPosition(x, y); PositionMover(movers[selected], x, y)
                layout.x:ClearFocus(); layout.y:ClearFocus(); UpdateCoordinates()
            else layout.selection:SetText(L("Coordonnées : 0 à 100 %.")) end
        end
        Button(layout, "ArkannsQOLLayoutCoordinates", L("Appliquer"), 480, -80, 122, ApplyCoordinates)
        layout.x:SetScript("OnEnterPressed", ApplyCoordinates); layout.y:SetScript("OnEnterPressed", ApplyCoordinates)
        layout:SetScript("OnHide", function() if not endingLayout then UI.EndLayout(true) end end)
        UISpecialFrames[#UISpecialFrames + 1] = "ArkannsQOLLayout"
        layout.guides = CreateFrame("Frame", nil, UIParent)
        layout.guides:SetAllPoints(); layout.guides:EnableMouse(false)
        layout.lines = {}
    end
    UI.layoutActive, savedPositions, savedLayouts, changedPositions, selected = true, {}, {}, {}, nil
    for _, id in ipairs(moduleOrder) do
        local module = ns.modules[id]
        if module and module.GetPosition and module.SetPosition and module.frame then
            local x, y = module.GetPosition()
            if Number(x) and Number(y) then
                savedPositions[id] = {x, y}
                if module.ExportSettings then savedLayouts[id]=module.ExportSettings() end
                local started = not module.Preview or module.Preview(true)
                if started == true then
                local mover = movers[id]
                if not mover then
                    mover = CreateFrame("Frame", "ArkannsQOLMover_" .. id, UIParent, "BackdropTemplate")
                    movers[id] = mover
                    mover:SetMovable(true); mover:EnableMouse(true); mover:RegisterForDrag("LeftButton"); mover:SetClampedToScreen(true)
                    mover:SetFrameStrata("DIALOG"); mover:SetFrameLevel(20)
                    mover.caption = Label(mover, module.label, 12, -10)
                    mover.caption:ClearAllPoints(); mover.caption:SetPoint("BOTTOMLEFT",mover,"TOPLEFT",4,4)
                    mover:SetScript("OnDragStart", function(self)
                        selected = id; UpdateCoordinates(); self.moving = true; self:StartMoving()
                    end)
                    mover:SetScript("OnDragStop", function() SaveMover(id) end)
                    mover:SetScript("OnUpdate", function(self,delta)
                        if not self.moving then return end
                        self.elapsed=(self.elapsed or 0)+delta
                        if self.elapsed<.05 then return end
                        self.elapsed=0
                        local mx,my=self:GetCenter()
                        if Number(mx) and Number(my) then changedPositions[id] = true; module.SetPosition(mx/UIParent:GetWidth(),my/UIParent:GetHeight()); UpdateCoordinates() end
                    end)
                    mover:SetScript("OnMouseUp", function(_, button)
                        selected = id; UpdateCoordinates()
                        if button == "RightButton" then UI.EndLayout(true) end
                    end)
                end
                UI.StyleFrame(mover)
                local style=UI.GetStyle(); mover:SetBackdropColor(style.bg[1],style.bg[2],style.bg[3],.08)
                local scale = module.frame.GetEffectiveScale and module.frame:GetEffectiveScale() or 1
                local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
                mover:SetSize(math.max(130, module.frame:GetWidth() * scale / parentScale), math.max(45, module.frame:GetHeight() * scale / parentScale))
                PositionMover(mover, x, y); mover:Show(); selected = selected or id
                if id == focusId then selected = id end
                else savedPositions[id], savedLayouts[id] = nil, nil end
            end
        end
    end
    if not selected then UI.EndLayout(true); UI.Notify(L("Aucun cadre disponible à déplacer.")); return false end
    local width, height, index = UIParent:GetWidth(), UIParent:GetHeight(), 0
    local function Line(vertical, at, center)
        index = index + 1
        local line = layout.lines[index] or layout.guides:CreateTexture(nil, "BACKGROUND")
        layout.lines[index] = line; line:ClearAllPoints(); line:SetPoint("BOTTOMLEFT", vertical and at or 0, vertical and 0 or at)
        line:SetSize(vertical and 1 or width, vertical and height or 1)
        line:SetColorTexture(1, .76, .3, center and .6 or .09); line:Show()
    end
    for x = 0, width, 16 do Line(true, x) end
    for y = 0, height, 16 do Line(false, y) end
    Line(true, width/2, true); Line(false, height/2, true)
    for i = index + 1, #layout.lines do layout.lines[i]:Hide() end
    UI.StyleFrame(layout)
    layout.grid:SetChecked(config.grid); layout.snap:SetChecked(config.snap)
    layout.guides:SetShown(config.grid); layout:Show(); UpdateCoordinates()
    return true
end

local function BuildAppearance(root)
    local panel = CreateFrame("Frame", "ArkannsQOLCommonAppearance", UIParent, "BackdropTemplate")
    panel:Hide(); UI.StylePanel(panel)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -16); scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local body = CreateFrame("Frame", nil, scroll); body:SetSize(580, 1050); scroll:SetScrollChild(body)
    local heading=Label(body, L("Apparence générale"), 0, 0, 18)
    local description=Label(body, L("Même thème pour tous les modules. Les exceptions restent personnalisables."), 0, -34)
    local fields, syncing, advanced = {}, false, false
    local LayoutAppearance
    local themeButton = Button(body, "ArkannsQOLCommonTheme", "", 0, -86, 330, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            for _, id in ipairs({"warm", "blizzard", "modern"}) do
                local key, theme = id, themes[id]
                menu:CreateButton(theme.label, function()
                    config.theme = key
                    for _, field in ipairs({"bg", "text", "accent", "font", "opacity"}) do
                        config[field] = Copy(theme.settings[field])
                    end
                    if config.border == "theme" then config.borderSize = GetBorder(config).size end
                    UI.Refresh()
                end)
            end
        end)
    end)
    local borderButton = Button(body, "ArkannsQOLCommonBorder", "", 0, -120, 330, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            for _, id in ipairs({"theme", "tooltip", "blizzard", "flat", "none"}) do
                local key = id
                menu:CreateButton(borders[key].label, function()
                    if config.border == key then return end
                    config.border = key
                    config.borderSize = GetBorder(config).size or config.borderSize
                    UI.Refresh()
                end)
            end
        end)
    end)
    local function Slider(key, title, y, minimum, maximum, factor)
        factor = factor or 1
        local caption = Label(body, "", 0, y)
        local slider = CreateFrame("Slider", "ArkannsQOLCommon_" .. key, body, "BackdropTemplate")
        slider:SetPoint("TOPLEFT", 4, y-26); slider:SetSize(330, 18); slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(minimum, maximum); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
        slider:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background",edgeFile="Interface\\Buttons\\UI-SliderBar-Border",edgeSize=8})
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); slider:GetThumbTexture():SetSize(28,28)
        slider:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            config[key] = math.floor(value+.5)/factor; UI.Refresh()
        end)
        fields[key] = {slider=slider, caption=caption, title=title, factor=factor}
    end
    Slider("fontSize", L("Taille du texte des modules"), -162, 10, 24)
    Slider("scale", L("Échelle (%)"), -232, 60, 160, 100)
    Slider("opacity", L("Opacité du fond (%)"), -302, 0, 100, 100)
    Slider("borderSize", L("Épaisseur de bordure"), -290, 1, 24)
    Slider("padding", L("Marge intérieure"), -360, 4, 24)
    Slider("gap", L("Espacement"), -430, 0, 20)
    local advancedButton = Button(body, "ArkannsQOLCommonAdvanced", L("Personnalisation avancée"), 0, -372, 260, function()
        advanced = not advanced; LayoutAppearance()
    end)
    local fontButton = Button(body, "ArkannsQOLCommonFont", "", 0, -500, 330, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            for _, option in ipairs({{"standard", L("Classique")}, {"narrow", "Arial"}, {"fantasy", "Morpheus"}}) do
                local key = option[1]
                menu:CreateButton(option[2], function() config.font = key; UI.Refresh() end)
            end
        end)
    end)
    local colors, colorLabels, colorButtons = {}, {}, {}
    for index, spec in ipairs({{"bg", L("Fond")}, {"text", L("Texte")}, {"accent", L("Bordure et accents")}}) do
        local key, label = spec[1], spec[2]
        local y = -548 - (index - 1)*42
        colorLabels[key]=Label(body, label .. " (#RRGGBB)", 0, y-5)
        local input = Input(body, "ArkannsQOLCommonColor_"..key, 240, y, 90); input:SetMaxLetters(7)
        colors[key] = input
        local function Apply()
            local text = input:GetText():gsub("#", "")
            if text:match("^%x%x%x%x%x%x$") then
                config[key] = {tonumber(text:sub(1,2),16)/255,tonumber(text:sub(3,4),16)/255,tonumber(text:sub(5,6),16)/255}
                input:ClearFocus(); UI.Refresh()
            else UI.Notify(L("Code hex invalide. Exemple : FFCC44.")) end
        end
        input:SetScript("OnEnterPressed", Apply)
        colorButtons[key]=Button(body, nil, L("Appliquer"), 340, y, 95, Apply)
        local picker = Button(body, nil, label, 0, y, 190, function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local old = Copy(config[key])
            ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,
                swatchFunc=function() config[key]={ColorPickerFrame:GetColorRGB()}; UI.Refresh() end,
                cancelFunc=function() config[key]=old; UI.Refresh() end})
        end)
        colorLabels[key]:Hide(); colorLabels[key] = picker
    end
    local reset=Button(body, "ArkannsQOLCommonDefaults", L("Rétablir Chaleureux"), 0, -687, 220, function()
        local overrides, pins = config.overrides, config.pins
        local value=Copy(defaults); value.overrides,value.pins=overrides,pins
        UI.ImportSettings(value)
    end)
    local preview=Button(body, "ArkannsQOLCommonPreview", L("Aperçu du journal"), 232, -687, 200, function() UI.PreviewModule("session") end)
    appearanceRefresh = function()
        syncing = true
        themeButton:SetText(L("Thème : %s"):format(themes[config.theme].label))
        borderButton:SetText(L("Type de bordure : %s"):format(borders[config.border].label))
        local menuAvailable = MenuUtil and type(MenuUtil.CreateContextMenu) == "function" or false
        themeButton:SetEnabled(menuAvailable); borderButton:SetEnabled(menuAvailable)
        for key, field in pairs(fields) do field.slider:SetValue(config[key]*field.factor); field.caption:SetText(field.title .. " : " .. math.floor(config[key]*field.factor+.5)) end
        local hasBorder = config.border ~= "none"
        fields.borderSize.slider:SetEnabled(hasBorder)
        fields.borderSize.slider:SetAlpha(hasBorder and 1 or .5)
        fields.borderSize.caption:SetAlpha(hasBorder and 1 or .5)
        for key,input in pairs(colors) do if not input.HasFocus or not input:HasFocus() then
            local c=config[key]; input:SetText(string.format("%02X%02X%02X",math.floor(c[1]*255+.5),math.floor(c[2]*255+.5),math.floor(c[3]*255+.5)))
        end end
        fontButton:SetText(L("Police : ") .. ({standard=L("Classique"),narrow="Arial",fantasy="Morpheus"})[config.font])
        syncing = false
    end
    LayoutAppearance = function()
        local width=math.max(270,panel:GetWidth()-50)
        local narrow=width<435
        local extra=narrow and 118 or 0
        body:SetSize(width,advanced and 902+extra or 502)
        heading:SetWidth(width); heading:SetHeight(44)
        description:ClearAllPoints(); description:SetPoint("TOPLEFT",0,-48); description:SetWidth(width); description:SetHeight(30)
        for _,field in pairs(fields) do field.slider:SetWidth(math.min(330,width-8)) end
        themeButton:SetWidth(math.min(330,width))
        borderButton:SetWidth(math.min(330,width))
        fontButton:SetWidth(math.min(330,width))
        fontButton:SetShown(advanced)
        advancedButton:SetText(advanced and L("Masquer la personnalisation avancée") or L("Personnalisation avancée"))
        advancedButton:SetWidth(math.min(330,width))
        for index,key in ipairs({"borderSize","padding","gap"}) do
            local field=fields[key]
            local y=-422-(index-1)*70
            field.caption:ClearAllPoints(); field.caption:SetPoint("TOPLEFT",0,y)
            field.slider:ClearAllPoints(); field.slider:SetPoint("TOPLEFT",4,y-26)
            field.caption:SetShown(advanced); field.slider:SetShown(advanced)
        end
        fontButton:ClearAllPoints(); fontButton:SetPoint("TOPLEFT",0,-632)
        for index,key in ipairs({"bg","text","accent"}) do
            local y=-674-(index-1)*(narrow and 70 or 42)
            colorLabels[key]:ClearAllPoints(); colorLabels[key]:SetPoint("TOPLEFT",0,y-5)
            colorLabels[key]:SetShown(advanced); colors[key]:SetShown(advanced); colorButtons[key]:SetShown(advanced)
            colors[key]:ClearAllPoints(); colors[key]:SetPoint("TOPLEFT",narrow and 4 or 240,y-(narrow and 28 or 0))
            colorButtons[key]:ClearAllPoints(); colorButtons[key]:SetPoint("TOPLEFT",narrow and 110 or 340,y-(narrow and 28 or 0))
        end
        local bottom=advanced and -817-(narrow and 84 or 0) or -422
        reset:ClearAllPoints(); reset:SetPoint("TOPLEFT",0,bottom)
        preview:ClearAllPoints(); preview:SetPoint("TOPLEFT",narrow and 0 or 232,bottom-(narrow and 34 or 0))
    end
    panel:SetScript("OnShow", function() LayoutAppearance(); appearanceRefresh() end)
    panel:HookScript("OnSizeChanged",LayoutAppearance)
    panel:SetScript("OnHide", ns.StopAllPreviews)
    ns.appearanceCategory = Settings.RegisterCanvasLayoutSubcategory(root,panel,L("Apparence générale"))
    ns.RegisterModule("appearance", {label = L("Apparence générale"), category = function() return ns.appearanceCategory end,
        ExportSettings = UI.ExportSettings, ImportSettings = UI.ImportSettings,
        profileMigrations = {
            function(value) value.theme = value.theme or defaults.theme end,
            function(value) value.border = value.border or defaults.border end,
        },
        ProfileDisplay = function(value)
            if themes[value.theme] then value.theme = themes[value.theme].label end
            if borders[value.border] then value.border = borders[value.border].label end
        end})
    appearanceRefresh()
end

function UI.BuildHome(panel, root)
    home = panel; UI.StylePanel(home)
    Label(home, "QoL Toolkit",16,-16,20)
    Label(home, L("Ton interface, ton rythme."),16,-46)
    local toolbar={}
    toolbar[1]=Button(home,"ArkannsQOLHomeAppearance",L("Apparence"),16,-76,130,function() ns.StopAllPreviews(); Settings.OpenToCategory(ns.appearanceCategory:GetID()) end)
    toolbar[2]=Button(home,"ArkannsQOLHomeLayout",L("Disposition"),156,-76,130,UI.StartLayout)
    toolbar[3]=Button(home,"ArkannsQOLHomeProfiles",L("Profils"),296,-76,130,function() ns.StopAllPreviews(); if ns.profilesCategory then Settings.OpenToCategory(ns.profilesCategory:GetID()) end end)
    toolbar[4]=Button(home,"ArkannsQOLHomeDiagnostics",L("Diagnostics"),436,-76,180,function()
        ns.StopAllPreviews()
        if ns.diagnosticsCategory then Settings.OpenToCategory(ns.diagnosticsCategory:GetID()) end
    end)
    local minimap = Check(home,"ArkannsQOLShowMinimap",L("Afficher le bouton de minicarte"),12,-110,function(value)
        if ns.SetMinimapVisible then ns.SetMinimapVisible(value) end
    end)
    local scroll=CreateFrame("ScrollFrame",nil,home,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-118); scroll:SetPoint("BOTTOMRIGHT",-34,18)
    local body=CreateFrame("Frame",nil,scroll); body:SetSize(580,700); scroll:SetScrollChild(body)
    local cards={}
    local names={tooltips="Tooltips",reminders="Reminders",session="Session",talents="Talents",ranks="Ranks",distance="Distance",bags="Bags",advanced="Advanced"}
    for index,id in ipairs(moduleOrder) do
        local module=ns.modules[id]
        if module then
            local card=CreateFrame("Frame",nil,body,"BackdropTemplate"); cards[#cards+1]=card; UI.StyleFrame(card)
            card.icon=card:CreateTexture(nil,"ARTWORK"); card.icon:SetSize(30,30); card.icon:SetPoint("TOPLEFT",12,-12)
            local atlas=module.iconAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(module.iconAtlas)
            if type(atlas)=="table" and card.icon.SetAtlas and Number(atlas.width) and Number(atlas.height) and atlas.width>0 and atlas.height>0 then
                card.icon:SetAtlas(module.iconAtlas,false)
                local longest=math.max(atlas.width,atlas.height)
                card.icon:SetSize(30*atlas.width/longest,30*atlas.height/longest)
            else card.icon:SetTexture(module.icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
            card.title=Label(card,module.label,52,-14,14)
            card.title:SetPoint("TOPRIGHT",-12,-14); card.title:SetHeight(22)
            card.summary=Label(card,"",12,-52,12); card.summary:SetHeight(34); card.summary:SetPoint("TOPRIGHT",-12,-52)
            card.configure=Button(card,"ArkannsQOLHome"..names[id],L("Configurer"),12,-124,100,function()
                ns.StopAllPreviews(); local category=module.category and module.category(); if category then Settings.OpenToCategory(category:GetID()) end
            end)
            if module.Preview then Button(card,nil,L("Aperçu"),120,-124,90,function() UI.PreviewModule(id) end) end
            if module.IsEnabled and module.SetEnabled then
                card.enabled=Check(card,"ArkannsQOLHomeEnabled_"..id,module.toggleLabel or L("Activer ce module"),8,-84,function(value) module.SetEnabled(value); home.Refresh() end)
            end
            card.pin=Button(card,nil,"",218,-91,38,function() config.pins[id]=not config.pins[id]; home.Refresh() end)
            card.module,card.id=module,id
        end
    end
    local favoritesTitle=Label(body,L("Favoris"),0,0,16)
    local favoriteButtons={}
    home.Refresh=function()
        local width=math.max(270,home:GetWidth()-50)
        local toolbarColumns=width>=600 and 4 or 2
        local toolbarWidth=(width-(toolbarColumns-1)*10)/toolbarColumns
        for index,button in ipairs(toolbar) do
            button:ClearAllPoints(); button:SetPoint("TOPLEFT",16+((index-1)%toolbarColumns)*(toolbarWidth+10),-76-math.floor((index-1)/toolbarColumns)*34)
            button:SetWidth(toolbarWidth)
        end
        local headerBottom=-84-math.ceil(4/toolbarColumns)*34
        minimap:ClearAllPoints(); minimap:SetPoint("TOPLEFT",12,headerBottom)
        minimap:SetChecked(ns.IsMinimapVisible and ns.IsMinimapVisible())
        minimap:SetShown(ns.IsMinimapVisible ~= nil)
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT",16,headerBottom-36); scroll:SetPoint("BOTTOMRIGHT",-34,18)
        local columns=width>=540 and 2 or 1
        local cardWidth=(width-12*(columns-1))/columns
        for index,card in ipairs(cards) do
            card:SetSize(cardWidth,160); UI.StyleFrame(card)
            card.pin:ClearAllPoints(); card.pin:SetPoint("BOTTOMRIGHT",-10,9)
            UI.SetFavoriteIcon(card.pin,config.pins[card.id])
            card.summary:SetText(card.module.Summary and card.module.Summary() or L("Options et préférences."))
            if card.enabled then
                card.enabled:SetChecked(card.module.IsEnabled())
                card.enabled.label:SetWidth(cardWidth-48)
            end
        end
        favoritesTitle:ClearAllPoints(); favoritesTitle:SetPoint("TOPLEFT",0,0)
        favoritesTitle:SetWidth(width); favoritesTitle:SetHeight(40)
        local entries={}
        for _,id in ipairs(moduleOrder) do if config.pins[id] and ns.modules[id] then
            local module=ns.modules[id]
            entries[#entries+1]={label=module.label,Open=function() ns.StopAllPreviews(); Settings.OpenToCategory(module.category():GetID()) end}
        end end
        local advanced=ns.modules.advanced
        if advanced and advanced.Favorites then
            local list=advanced.Favorites()
            for _,entry in ipairs(list or {}) do entries[#entries+1]=entry end
        end
        favoritesTitle:SetShown(#entries>0)
        for index,entry in ipairs(entries) do
            local button=favoriteButtons[index]
            if not button then button=Button(body,nil,"",0,0,cardWidth,function() end); favoriteButtons[index]=button end
            button:ClearAllPoints(); button:SetPoint("TOPLEFT",0,-40-(index-1)*32); button:SetWidth(math.min(width,430))
            button:SetText(entry.label); button:SetScript("OnClick",function() ns.StopAllPreviews(); entry.Open() end); button:Show()
        end
        for index=#entries+1,#favoriteButtons do favoriteButtons[index]:Hide() end
        local favoritesHeight=#entries>0 and 52+#entries*32 or 0
        for index,card in ipairs(cards) do
            card:ClearAllPoints(); card:SetPoint("TOPLEFT",((index-1)%columns)*(cardWidth+12),-favoritesHeight-math.floor((index-1)/columns)*170)
        end
        body:SetSize(width,favoritesHeight+math.ceil(#cards/columns)*170)
    end
    home:SetScript("OnShow",home.Refresh)
    home:HookScript("OnSizeChanged",home.Refresh)
    home:SetScript("OnHide",ns.StopAllPreviews)
    home.Refresh()
end

function ns.InitializeInterface(root)
    BuildAppearance(root)
    UI.BuildHome(ns.home,root)
    if SettingsPanel and SettingsPanel.HookScript then SettingsPanel:HookScript("OnHide",ns.StopAllPreviews) end
    local events=CreateFrame("Frame","ArkannsQOLInterfaceEvents")
    for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_LOGOUT","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event)
        if UI.layoutActive then UI.EndLayout(event~="PLAYER_LOGOUT") else ns.StopAllPreviews() end
    end)
end
