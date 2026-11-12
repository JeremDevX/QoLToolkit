local _, ns = ...
local L = ns.L
ns.modules = {}
local UI = {}
ns.UI = UI
local config, previewBar, previewModule, layout, home, appearanceRefresh
local styledPanels, styledButtons, styledLabels = {}, {}, {}
local moduleOrder = {"tooltips", "reminders", "session", "talents", "ranks", "distance", "targetPortrait", "bags", "flights", "advanced"}
local settingsPages, appearanceBack = {}, nil

function UI.OpenSettings(id, source, back)
    local module = ns.modules[id] or settingsPages[id]
    local category = module and module.category and module.category()
    category = category or ns[({profiles="profilesCategory",diagnostics="diagnosticsCategory"})[id] or ""]
    if not category then return false end
    ns.StopAllPreviews()
    if id == "appearance" then appearanceBack = back end
    if not UI.OpenCategory(category) then return false end
    if module and module.OpenSettings then module.OpenSettings(source) end
    return true
end

function UI.RegisterSettings(id, descriptor)
    settingsPages[id] = descriptor
end

-- Coordinates are measured after the destination page and its folds are laid out.
function UI.RevealControl(scroll, control)
    if not scroll or not control then return end
    local child = scroll:GetScrollChild()
    local top, target = child and child:GetTop(), control:GetTop()
    if type(top) ~= "number" or type(target) ~= "number" then return end
    local childScale = child:GetEffectiveScale()
    local targetScale = control:GetEffectiveScale()
    scroll:SetVerticalScroll(math.max(0, top - target * targetScale / childScale - 12))
    UI.ClampScroll(scroll, child:GetHeight())
end
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
    if UI.RefreshSettingsWindow then UI.RefreshSettingsWindow() end
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

function UI.AddAppearanceLink(parent, id, x, y, width)
    return Button(parent, nil, L("Régler le thème commun"), x, y, width or 240, function()
        UI.OpenSettings("appearance", nil, id)
    end)
end

function UI.ClampScroll(scroll, contentHeight)
    local offset, height = scroll:GetVerticalScroll(), scroll:GetHeight()
    if not Number(offset) or not Number(height) or height <= 0 then return end
    local maximum = math.max(0, contentHeight - height)
    if offset > maximum then scroll:SetVerticalScroll(maximum) end
end

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
local endingLayout, layoutReturn
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
    mover:SetScript("OnUpdate", nil)
    local x, y = mover:GetCenter()
    if Number(x) and Number(y) then
        x, y = UI.SnapPosition(id, x / UIParent:GetWidth(), y / UIParent:GetHeight())
        if x then changedPositions[id] = true; module.SetPosition(x, y); PositionMover(mover, x, y) end
    end
    UpdateCoordinates()
end
function UI.EndLayout(cancel, returnToSettings)
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
            if savedLayouts[id] and module.ExportSettings and module.ImportSettings then
                -- Restore placement only; commands may have changed other settings during the preview.
                local current = module.ExportSettings()
                current.x, current.y = savedLayouts[id].x, savedLayouts[id].y
                module.ImportSettings(current)
            elseif changedPositions[id] then module.SetPosition(position[1], position[2]) end
        else module.SetPosition(positions[id][1], positions[id][2]) end
    end
    local destination = layoutReturn
    layoutReturn, endingLayout = nil, nil
    if ns.Diagnostics then ns.Diagnostics.Note(cancel and "layout.cancel" or "layout.apply") end
    if returnToSettings and destination and ns.WoW.ReadValue(InCombatLockdown) == false then
        UI.OpenSettings(destination)
    end
end
function UI.StartLayout(focusId)
    if ns.WoW.ReadValue(InCombatLockdown) ~= false then
        local reason = L("Disposition disponible hors combat.")
        UI.Notify(reason); return false, reason
    end
    if type(focusId) ~= "string" then focusId = nil end
    ns.StopAllPreviews()
    layoutReturn = focusId
    if not layoutReturn then
        layoutReturn = ns.appearancePanel and ns.appearancePanel:IsVisible() and "appearance" or "home"
    end
    if UI.HideSettingsWindow then UI.HideSettingsWindow() end
    if not layout then
        layout = CreateFrame("Frame", "ArkannsQOLLayout", UIParent, "BackdropTemplate")
        layout:SetSize(620, 164); layout:SetPoint("TOP", UIParent, "TOP", 0, -28)
        layout:SetFrameStrata("DIALOG"); layout:SetFrameLevel(30); layout:SetClampedToScreen(true)
        Label(layout, L("Disposition — glisse les cadres"), 16, -12, 16)
        Label(layout, L("Les positions restent en aperçu jusqu’à validation."), 16, -35)
        Button(layout, "ArkannsQOLLayoutApply", L("Valider"), 16, -58, 110, function() UI.EndLayout(false, true) end)
        Button(layout, "ArkannsQOLLayoutCancel", L("Annuler"), 136, -58, 110, function() UI.EndLayout(true, true) end)
        Button(layout, "ArkannsQOLLayoutCenter", L("Recentrer"), 256, -58, 110, function()
            if selected then changedPositions[selected] = true; ns.modules[selected].SetPosition(.5, .5); PositionMover(movers[selected], .5, .5); UpdateCoordinates() end
        end)
        layout.grid = Check(layout, "ArkannsQOLLayoutGrid", L("Grille"), 12, -94, function(value)
            config.grid = value; layout.guides:SetShown(value)
        end)
        layout.snap = Check(layout, "ArkannsQOLLayoutSnap", L("Accrochage"), 120, -94, function(value) config.snap = value end)
        layout.selection = Label(layout, "", 16, -135)
        Label(layout, "X %", 260, -102); layout.x = Input(layout, "ArkannsQOLLayoutX", 295, -96, 60)
        Label(layout, "Y %", 366, -102); layout.y = Input(layout, "ArkannsQOLLayoutY", 402, -96, 60)
        local function ApplyCoordinates()
            local x, y = tonumber((layout.x:GetText():gsub(",", "."))), tonumber((layout.y:GetText():gsub(",", ".")))
            if selected and Number(x) and Number(y) and x >= 0 and x <= 100 and y >= 0 and y <= 100 then
                x, y = UI.SnapPosition(selected, x/100, y/100)
                changedPositions[selected] = true
                ns.modules[selected].SetPosition(x, y); PositionMover(movers[selected], x, y)
                layout.x:ClearFocus(); layout.y:ClearFocus(); UpdateCoordinates()
            else layout.selection:SetText(L("Coordonnées : 0 à 100 %.")) end
        end
        Button(layout, "ArkannsQOLLayoutCoordinates", L("Déplacer"), 480, -96, 122, ApplyCoordinates)
        layout.x:SetScript("OnEnterPressed", ApplyCoordinates); layout.y:SetScript("OnEnterPressed", ApplyCoordinates)
        layout:SetScript("OnHide", function() if not endingLayout then UI.EndLayout(true, true) end end)
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
                    local function FollowMover(self, delta)
                        self.elapsed=(self.elapsed or 0)+delta
                        if self.elapsed<.05 then return end
                        self.elapsed=0
                        local mx,my=self:GetCenter()
                        if Number(mx) and Number(my) then changedPositions[id] = true; module.SetPosition(mx/UIParent:GetWidth(),my/UIParent:GetHeight()); UpdateCoordinates() end
                    end
                    mover:SetScript("OnDragStart", function(self)
                        selected = id; UpdateCoordinates(); self.moving = true; self.elapsed = 0
                        self:StartMoving(); self:SetScript("OnUpdate", FollowMover)
                    end)
                    mover:SetScript("OnDragStop", function() SaveMover(id) end)
                    mover:SetScript("OnMouseUp", function(_, button)
                        selected = id; UpdateCoordinates()
                        if button == "RightButton" then UI.EndLayout(true, true) end
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

local function Place(control, x, y, width)
    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", x, -y)
    if width then control:SetWidth(width) end
end

local function BuildAppearance(root)
    local panel = CreateFrame("Frame", "ArkannsQOLCommonAppearance", UIParent, "BackdropTemplate")
    ns.appearancePanel = panel
    panel:Hide(); UI.StylePanel(panel)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    local body = CreateFrame("Frame", nil, scroll); body:SetSize(1, 1); scroll:SetScrollChild(body)
    local heading=Label(panel, L("Apparence générale"), 0, 0, 18)
    local back=Button(panel,"ArkannsQOLAppearanceBack",L("Retour au module"),0,0,240,function()
        local id = appearanceBack
        appearanceBack = nil
        if id then UI.OpenSettings(id) end
    end)
    local description=Label(panel, L("Les modules qui suivent l’apparence commune changent immédiatement."), 0, 0)
    local fields, syncing, section = {}, false, "general"
    local LayoutAppearance
    local themeButton = Button(body, "ArkannsQOLCommonTheme", "", 0, 0, 330, function(self)
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
    local borderButton = Button(body, "ArkannsQOLCommonBorder", "", 0, 0, 330, function(self)
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
    local function Slider(key, title, minimum, maximum, factor)
        factor = factor or 1
        local caption = Label(body, "", 0, 0)
        local slider = CreateFrame("Slider", "ArkannsQOLCommon_" .. key, body, "BackdropTemplate")
        slider:SetSize(330, 18); slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(minimum, maximum); slider:SetValueStep(1); slider:SetObeyStepOnDrag(true)
        slider:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background",edgeFile="Interface\\Buttons\\UI-SliderBar-Border",edgeSize=8})
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); slider:GetThumbTexture():SetSize(28,28)
        slider:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            config[key] = math.floor(value+.5)/factor; UI.Refresh()
        end)
        fields[key] = {slider=slider, caption=caption, title=title, factor=factor}
    end
    Slider("fontSize", L("Taille du texte des modules"), 10, 24)
    Slider("scale", L("Échelle (%)"), 60, 160, 100)
    Slider("opacity", L("Opacité du fond (%)"), 0, 100, 100)
    Slider("borderSize", L("Épaisseur de bordure"), 1, 24)
    Slider("padding", L("Marge intérieure"), 4, 24)
    Slider("gap", L("Espacement"), 0, 20)
    local tabs = {}
    for _, spec in ipairs({{"general", "ArkannsQOLCommonGeneral", "Général"},
        {"style", "ArkannsQOLCommonAdvanced", "Couleurs et bordure"},
        {"dimensions", "ArkannsQOLCommonDimensions", "Dimensions"}}) do
        local id = spec[1]
        tabs[#tabs + 1] = {id = id, button = Button(panel, spec[2], L(spec[3]), 0, 0, 150, function()
            section = id
            scroll:SetVerticalScroll(0)
            LayoutAppearance()
        end)}
    end
    local fontButton = Button(body, "ArkannsQOLCommonFont", "", 0, 0, 330, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            for _, option in ipairs({{"standard", L("Classique")}, {"narrow", "Arial"}, {"fantasy", "Morpheus"}}) do
                local key = option[1]
                menu:CreateButton(option[2], function() config.font = key; UI.Refresh() end)
            end
        end)
    end)
    local colors, pickers, colorButtons = {}, {}, {}
    for _, spec in ipairs({{"bg", L("Fond")}, {"text", L("Texte")}, {"accent", L("Bordure et accents")}}) do
        local key, label = spec[1], spec[2]
        local input = Input(body, "ArkannsQOLCommonColor_"..key, 0, 0, 80); input:SetMaxLetters(7)
        colors[key] = input
        local function Apply()
            local text = input:GetText():gsub("#", "")
            if text:match("^%x%x%x%x%x%x$") then
                config[key] = {tonumber(text:sub(1,2),16)/255,tonumber(text:sub(3,4),16)/255,tonumber(text:sub(5,6),16)/255}
                input:ClearFocus(); UI.Refresh()
            else UI.Notify(L("Code hex invalide. Exemple : FFCC44.")) end
        end
        input:SetScript("OnEnterPressed", Apply)
        colorButtons[key]=Button(body, nil, L("Appliquer"), 0, 0, 90, Apply)
        pickers[key] = Button(body, nil, label, 0, 0, 144, function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local old = Copy(config[key])
            ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,
                swatchFunc=function() config[key]={ColorPickerFrame:GetColorRGB()}; UI.Refresh() end,
                cancelFunc=function() config[key]=old; UI.Refresh() end})
        end)
    end
    local colorHint=Label(body, L("Couleurs · code hexadécimal (#RRGGBB)"), 0, 0)
    local reset=Button(panel, "ArkannsQOLCommonDefaults", L("Rétablir Chaleureux"), 0, 0, 220, function()
        UI.Confirm(L("Rétablir tous les réglages de l’apparence commune sur Chaleureux ?"), function()
            local value = Copy(defaults)
            value.overrides, value.pins, value.grid, value.snap = config.overrides, config.pins, config.grid, config.snap
            UI.ImportSettings(value)
        end)
    end)
    local preview=Button(panel, "ArkannsQOLCommonPreview", L("Aperçu du journal"), 0, 0, 200, function() UI.PreviewModule("session") end)
    local specimen = CreateFrame("Frame", "ArkannsQOLCommonSample", panel, "BackdropTemplate")
    local specimenTitle = Label(specimen, L("Aperçu"), 12, -12, 15)
    local specimenText = Label(specimen, L("Texte"), 12, -44)
    local specimenLine = specimen:CreateTexture(nil, "ARTWORK")
    specimenLine:SetPoint("BOTTOMLEFT", 12, 14)
    specimenLine:SetPoint("BOTTOMRIGHT", -12, 14)
    specimenLine:SetHeight(3)
    appearanceRefresh = function()
        syncing = true
        themeButton:SetText(L("Thème : %s"):format(themes[config.theme].label))
        borderButton:SetText(L("Type de bordure : %s"):format(borders[config.border].label))
        local menuAvailable = MenuUtil and type(MenuUtil.CreateContextMenu) == "function" or false
        themeButton:SetEnabled(menuAvailable); borderButton:SetEnabled(menuAvailable); fontButton:SetEnabled(menuAvailable)
        preview:SetEnabled(ns.modules.session and type(ns.modules.session.Preview) == "function" or false)
        for key, field in pairs(fields) do field.slider:SetValue(config[key]*field.factor); field.caption:SetText(field.title .. " : " .. math.floor(config[key]*field.factor+.5)) end
        local hasBorder = config.border ~= "none"
        fields.borderSize.slider:SetEnabled(hasBorder)
        fields.borderSize.slider:SetAlpha(hasBorder and 1 or .5)
        fields.borderSize.caption:SetAlpha(hasBorder and 1 or .5)
        local pickerAvailable = ColorPickerFrame and type(ColorPickerFrame.SetupColorPickerAndShow) == "function" or false
        for key,input in pairs(colors) do
            pickers[key]:SetEnabled(pickerAvailable)
            if not input.HasFocus or not input:HasFocus() then
                local c=config[key]; input:SetText(string.format("%02X%02X%02X",math.floor(c[1]*255+.5),math.floor(c[2]*255+.5),math.floor(c[3]*255+.5)))
            end
        end
        fontButton:SetText(L("Police : ") .. ({standard=L("Classique"),narrow="Arial",fantasy="Morpheus"})[config.font])
        UI.StyleFrame(specimen)
        specimenTitle:SetFont(fonts[config.font], config.fontSize + 2, "")
        specimenTitle:SetTextColor(unpack(config.accent))
        specimenText:SetFont(fonts[config.font], config.fontSize, "")
        specimenText:SetTextColor(unpack(config.text))
        specimenLine:SetColorTexture(unpack(config.accent))
        syncing = false
        LayoutAppearance()
    end
    LayoutAppearance = function()
        local width = math.max(1, panel:GetWidth() - 50)
        local short = panel:GetHeight() < 420
        local beside = width >= 620
        local contentWidth = beside and width - 238 or width
        local function SliderRow(key, y, shown)
            local field = fields[key]
            field.caption:SetShown(shown); field.slider:SetShown(shown)
            if not shown then return y end
            Place(field.caption, 0, y, contentWidth)
            local captionHeight = field.caption:GetStringHeight()
            Place(field.slider, 4, y + captionHeight + (short and 4 or 6), math.max(1, contentWidth - 8))
            return y + captionHeight + (short and 26 or 34)
        end
        local function MenuRow(button, y, shown)
            button:SetShown(shown)
            if not shown then return y end
            local buttonWidth = contentWidth
            Place(button, 0, y, buttonWidth)
            local text = button:GetFontString()
            text:SetWidth(math.max(1, buttonWidth - 24)); text:SetWordWrap(true)
            button:SetHeight(math.max(26, text:GetStringHeight() + (short and 6 or 10)))
            return y + button:GetHeight() + (short and 6 or 10)
        end
        heading:SetShown(not short)
        description:SetShown(not short)
        local top = 8
        if not short then
            Place(heading, 16, 16, width)
            top = heading:GetStringHeight() + 24
        end
        back:SetShown(appearanceBack ~= nil)
        if appearanceBack then
            Place(back, 16, top, math.min(240, width))
            top = top + (short and 30 or 34)
        end
        if not short then
            Place(description, 16, top, width)
            top = top + description:GetStringHeight() + 12
        end
        local tabX, tabY = 16, top
        local equalTabs = width >= 420
        local tabWidth = (width - 12) / 3
        for _, tab in ipairs(tabs) do
            local button = tab.button
            local needed = equalTabs and tabWidth or math.min(width, button:GetFontString():GetUnboundedStringWidth() + 24)
            if tabX > 16 and tabX + needed > width + 16 then tabX, tabY = 16, tabY + 34 end
            Place(button, tabX, tabY, needed)
            button:SetHeight(28)
            button:SetEnabled(tab.id ~= section)
            tabX = tabX + needed + 6
        end
        top = tabY + (short and 36 or 42)
        local footerHeight = width >= 440 and (short and 42 or 48) or (short and 76 or 82)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -top)
        scroll:SetSize(contentWidth, math.max(1, panel:GetHeight() - top - footerHeight))
        specimen:SetParent(beside and panel or body)
        specimen:SetShown(beside or not short)
        if beside then
            Place(specimen, 16 + contentWidth + 24, top, 214)
        else
            Place(specimen, 0, 0, contentWidth)
        end
        specimen:SetHeight(110)
        specimenTitle:SetWidth(specimen:GetWidth() - 24)
        specimenText:SetWidth(specimen:GetWidth() - 24)
        local y = (beside or short) and 0 or 126
        y = MenuRow(themeButton, y, section == "general")
        y = MenuRow(fontButton, y, section == "general")
        y = SliderRow("fontSize", y, section == "general")
        y = SliderRow("scale", y, section == "general")
        y = MenuRow(borderButton, y, section == "style")
        y = SliderRow("opacity", y, section == "style")
        y = SliderRow("borderSize", y, section == "dimensions" and config.border ~= "none")
        y = SliderRow("padding", y, section == "dimensions")
        y = SliderRow("gap", y, section == "dimensions")
        colorHint:SetShown(section == "style")
        if section == "style" then
            Place(colorHint, 0, y, contentWidth)
            y = y + colorHint:GetStringHeight() + (short and 8 or 10)
        end
        for _, key in ipairs({"bg", "text", "accent"}) do
            local visible = section == "style"
            pickers[key]:SetShown(visible); colors[key]:SetShown(visible); colorButtons[key]:SetShown(visible)
            if visible then
                local sameRow = contentWidth >= 334
                Place(pickers[key], 0, y, sameRow and contentWidth - 190 or contentWidth)
                if not sameRow then y = y + 34 end
                Place(colors[key], sameRow and contentWidth - 182 or 4, y)
                Place(colorButtons[key], sameRow and contentWidth - 94 or 92, y)
                y = y + (short and 32 or 36)
            else
                colors[key]:ClearFocus()
            end
        end
        Place(reset, 16, panel:GetHeight() - footerHeight + 8, math.min(220, width))
        Place(preview, width >= 440 and width - 184 or 16, panel:GetHeight() - (width >= 440 and footerHeight - 8 or 40), math.min(200, width))
        body:SetSize(contentWidth, y)
        UI.ClampScroll(scroll, y)
        if scroll.ScrollBar then scroll.ScrollBar:SetShown(y > scroll:GetHeight() + 1) end
    end
    panel:SetScript("OnShow", appearanceRefresh)
    panel:HookScript("OnSizeChanged",LayoutAppearance)
    panel:SetScript("OnHide", function() appearanceBack = nil; ns.StopAllPreviews() end)
    ns.appearanceCategory = UI.RegisterSettingsPanel(root,panel,L("Apparence générale"),"appearance")
    ns.RegisterModule("appearance", {label = L("Apparence générale"), category = function() return ns.appearanceCategory end,
        OpenSettings = function(source)
            if not source then return end
            local targets = { ["Thème"] = themeButton, ["Type de bordure"] = borderButton, ["Police"] = fontButton,
                ["Fond"] = pickers.bg, ["Texte"] = pickers.text, ["Bordure et accents"] = pickers.accent }
            for _, field in pairs(fields) do targets[field.title] = field.slider end
            local target = targets[L(source)] or targets[source]
            local sections = { ["Thème"] = "general", ["Taille du texte des modules"] = "general", ["Police"] = "general", ["Échelle (%)"] = "general",
                ["Type de bordure"] = "style", ["Opacité du fond (%)"] = "style", ["Fond"] = "style", ["Texte"] = "style", ["Bordure et accents"] = "style" }
            section = sections[source] or "dimensions"
            scroll:SetVerticalScroll(0)
            LayoutAppearance()
            UI.RevealControl(scroll, target)
        end,
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

function UI.BuildHome(panel)
    home = panel; UI.StylePanel(home)
    local scroll=CreateFrame("ScrollFrame","ArkannsQOLHomeScroll",home,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-16); scroll:SetPoint("BOTTOMRIGHT",-34,18)
    local body=CreateFrame("Frame",nil,scroll); body:SetSize(1,1); scroll:SetScrollChild(body)
    local heading=Label(body, L("Accueil"),0,0,18)
    local searchLabel=Label(body,L("Rechercher dans tous les réglages"),0,0)
    local search=Input(body,"ArkannsQOLHomeSearch",6,0)
    search:SetMaxLetters(80)
    local clearSearch=Button(body,"ArkannsQOLHomeSearchClear",L("Effacer"),0,0,90,function()
        search:SetText(""); search:ClearFocus(); home.Refresh()
    end)
    local searchStatus=Label(body,"",0,0)
    local resultButtons, matches, minimap = {}, {}, nil
    -- Index settings, never session values, player names, or generated preview labels.
    local settingLabels = {
        tooltips = {"Personnaliser les infobulles", "Suivre le curseur", "Position fixe", "Échelle", "Réglages propres à ce type", "Décalage du curseur",
            "Décalage X / Y (0 à 100)", "Masquer en combat", "Types d’infobulle", "Unités", "Objets", "Sorts", "Apparence propre à ce module"},
        reminders = {"Activer les rappels", "Auras / postures", "Buffs", "Minicarte", "Ajouter par nom / ID", "Regrouper par type d'effet",
            "Mode compact : 2 effets", "Développer au survol", "Limite", "Taille du texte", "Opacité du fond", "Largeur", "Disposition",
            "Colonnes (grille)", "Espacement", "Marges", "Alignement", "Police", "Contour", "Ombre du texte", "Afficher le titre",
            "Titre personnalisé", "Taille du titre", "Afficher les icônes", "Taille des icônes", "Fond", "Texte", "Bordure", "Épaisseur de bordure"},
        session = {"Historique et progression", "Afficher la fenêtre", "Démarrer le suivi", "Arrêter le suivi", "Mettre en pause pendant l’AFK", "Masquer les valeurs nulles",
            "Mode compact (3 statistiques)", "Développer au survol", "Réinitialiser les stats", "Taille du texte", "Opacité du fond (%)",
            "Afficher le titre", "Afficher la bordure", "Largeur min.", "Masquer en combat", "Durée", "XP gagnée", "Prochain niveau",
            "Or reçu", "Or dépensé", "Solde", "Morts", "Niveaux gagnés", "Thème", "Disposition",
            "Apparence personnalisée", "Thème commun", "Déplacer"},
        talents = {"Modifier le build", "Retirer le dernier point", "Nouveau", "Dupliquer ce build", "Exporter ce build", "Importer un build", "1er point", "Couleur du prochain point",
            "Couleur des points suivants", "Couleur des erreurs", "Points suivants visibles", "Déplacer"},
        ranks = {"Avertissements de rang", "Exceptions", "Badge", "Coin", "Taille", "Opacité", "Couleur", "En combat", "Hors combat"},
        distance = {"Afficher le badge de la cible", "Afficher la distance au survol", "Arrondir les estimations par pas de 5 m",
            "Ancrer au portrait plutôt qu’au nom", "Placement et couleurs", "Décalage X / Y", "Réinitialiser le placement",
            "Fond et bordure", "Fond seul", "Texte seul", "Couleur du texte"},
    flights = {"Chronométrer les vols", "Exporter les durées"},
        bags = {"Trier à l’ouverture manuelle", "Bordure selon la rareté", "Personnaliser les bordures", "Transmos manquantes",
            "Couleurs de rareté", "Objets de quête", "Composants d’artisanat", "Opacité du contour", "Épaisseur du contour", "Halo intérieur"},
        appearance = {"Thème", "Taille du texte des modules", "Type de bordure", "Épaisseur de bordure", "Police", "Échelle (%)",
            "Opacité du fond (%)", "Marge intérieure", "Espacement", "Fond", "Texte", "Bordure et accents"},
    }
    local accents = { ["à"]="a", ["â"]="a", ["ä"]="a", ["À"]="a", ["Â"]="a", ["Ä"]="a",
        ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e", ["É"]="e", ["È"]="e", ["Ê"]="e", ["Ë"]="e",
        ["î"]="i", ["ï"]="i", ["Î"]="i", ["Ï"]="i", ["ô"]="o", ["ö"]="o", ["Ô"]="o", ["Ö"]="o",
        ["ù"]="u", ["û"]="u", ["ü"]="u", ["Ù"]="u", ["Û"]="u", ["Ü"]="u", ["ç"]="c", ["Ç"]="c", ["œ"]="oe", ["Œ"]="oe" }
    local function SearchText(value)
        local text=tostring(value or "")
        for accented, plain in pairs(accents) do text=text:gsub(accented,plain) end
        return text:lower()
    end
    function UI.SearchSettings(query)
        local words, result = {}, {}
        for word in SearchText(query):gmatch("%S+") do words[#words+1]=word end
        if #words==0 then return result end
        local function Add(label, detail, open)
            local text=SearchText(label.." "..(detail or ""))
            for _,word in ipairs(words) do if not text:find(word,1,true) then return end end
            result[#result+1]={label=label,Open=open}
        end
        if ns.IsMinimapVisible then
            Add(L("Afficher le bouton de minicarte"),"",function()
                search:SetText(""); home.Refresh(); UI.OpenSettings("home")
                UI.RevealControl(scroll, minimap)
            end)
        end
        for _,id in ipairs({"tooltips","reminders","session","talents","ranks","distance","targetPortrait","bags","flights","appearance"}) do
            local module=ns.modules[id]
            if module and module.category then
                local function Open() UI.OpenSettings(id) end
                Add(module.label,"",Open)
                for _,source in ipairs(module.SearchSettings or settingLabels[id] or {}) do
                    local target = source
                    Add(module.label.." · "..L(source),source.." "..((ns.English or {})[source] or ""),function() UI.OpenSettings(id,target) end)
                end
            end
        end
        local advanced=ns.modules.advanced
        if advanced and advanced.category then
            Add(advanced.label,"",function() UI.OpenSettings("advanced") end)
            for _,option in ipairs(ns.AdvancedSettingsCatalog or {}) do
                if not ns.AdvancedSettings or not ns.AdvancedSettings.IsNative(option.name) then
                    local name=option.name
                    Add(advanced.label.." · "..option.label,name.." "..(option.help or ""),function()
                        if ns.AdvancedSettings and ns.AdvancedSettings.OpenSetting then ns.AdvancedSettings.OpenSetting(name)
                        else UI.OpenSettings("advanced") end
                    end)
                end
            end
        end
        for _,entry in ipairs({
            {"Profils","profilesCategory",{"Enregistrer les réglages actuels","Restaurer un profil","Annuler l’application"}},
            {"Diagnostics","diagnosticsCategory",{"Démarrer une capture","Arrêter la capture","Copier la dernière trace","Inventaire du client"}},
        }) do
            if ns[entry[2]] then
                local key=entry[2]
                local function Open() UI.OpenSettings(key == "profilesCategory" and "profiles" or "diagnostics") end
                Add(L(entry[1]),"",Open)
                for _,source in ipairs(entry[3]) do
                    local target=source
                    Add(L(entry[1]).." · "..L(source),source.." "..((ns.English or {})[source] or ""),function()
                        UI.OpenSettings(key == "profilesCategory" and "profiles" or "diagnostics",target)
                    end)
                end
            end
        end
        table.sort(result,function(a,b) return a.label<b.label end)
        return result
    end
    local function OpenResult(entry)
        search:ClearFocus(); ns.StopAllPreviews(); entry.Open()
    end
    local toolbar={}
    toolbar[1]=Button(body,"ArkannsQOLHomeAppearance",L("Apparence"),0,0,130,function() UI.OpenSettings("appearance") end)
    toolbar[2]=Button(body,"ArkannsQOLHomeLayout",L("Disposition"),0,0,130,UI.StartLayout)
    toolbar[3]=Button(body,"ArkannsQOLHomeProfiles",L("Profils"),0,0,130,function() UI.OpenSettings("profiles") end)
    toolbar[4]=Button(body,"ArkannsQOLHomeDiagnostics",L("Diagnostics"),0,0,130,function()
        UI.OpenSettings("diagnostics")
    end)
    minimap = Check(body,"ArkannsQOLShowMinimap",L("Afficher le bouton de minicarte"),0,0,function(value)
        if ns.SetMinimapVisible then ns.SetMinimapVisible(value) end
    end)
    local function IsPinned(id, module)
        local distance=ns.modules.distance
        local combined=id=="tooltips" and distance and distance.category and module.category
            and distance.category()==module.category()
        return config.pins[id] or (combined and config.pins.distance)
    end
    local cards={}
    local names={tooltips="Tooltips",reminders="Reminders",session="Session",talents="Talents",ranks="Ranks",distance="Distance",targetPortrait="TargetPortrait",bags="Bags",flights="Flights",advanced="Advanced"}
    for _,id in ipairs(moduleOrder) do
        local module=ns.modules[id]
        local combinedDistance = id == "distance" and ns.modules.tooltips and ns.modules.tooltips.category
            and module and module.category and ns.modules.tooltips.category() == module.category()
        if module and not combinedDistance then
            local card=CreateFrame("Frame",nil,body,"BackdropTemplate"); cards[#cards+1]=card; UI.StyleFrame(card)
            card.icon=card:CreateTexture(nil,"ARTWORK"); card.icon:SetSize(30,30); card.icon:SetPoint("TOPLEFT",12,-12)
            local atlas=module.iconAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(module.iconAtlas)
            if type(atlas)=="table" and card.icon.SetAtlas and Number(atlas.width) and Number(atlas.height) and atlas.width>0 and atlas.height>0 then
                card.icon:SetAtlas(module.iconAtlas,false)
                local longest=math.max(atlas.width,atlas.height)
                card.icon:SetSize(30*atlas.width/longest,30*atlas.height/longest)
            else card.icon:SetTexture(module.icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
            card.title=Label(card,module.label,52,-12,14)
            card.summary=Label(card,"",12,0,12)
            card.configure=Button(card,"ArkannsQOLHome"..names[id],L("Configurer"),12,0,100,function()
                UI.OpenSettings(id)
            end)
            if module.Preview then card.preview=Button(card,nil,L("Aperçu"),120,0,80,function() UI.PreviewModule(id) end) end
            if module.IsEnabled and module.SetEnabled then
                card.enabled=Check(card,"ArkannsQOLHomeEnabled_"..id,module.toggleLabel or L("Activer ce module"),8,-84,function(value) module.SetEnabled(value); home.Refresh() end)
            end
            local function PinHelp()
                GameTooltip:SetText(IsPinned(id,module) and L("Retirer des favoris") or L("Ajouter aux favoris"))
                GameTooltip:Show()
            end
            card.pin=Button(card,nil,"",0,0,34,function(self)
                local distance=ns.modules.distance
                local combined=id=="tooltips" and distance and distance.category and module.category
                    and distance.category()==module.category()
                local active=IsPinned(id,module)
                config.pins[id]=not active
                if combined then config.pins.distance=nil end
                home.Refresh()
                if GameTooltip and GameTooltip:GetOwner()==self then PinHelp() end
            end)
            card.pin:SetScript("OnEnter",function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                PinHelp()
            end)
            card.pin:SetScript("OnLeave",function(self)
                if GameTooltip and GameTooltip:GetOwner()==self then GameTooltip:Hide() end
            end)
            card.pin:SetScript("OnHide",card.pin:GetScript("OnLeave"))
            card.module,card.id=module,id
        end
    end
    local favoritesTitle=Label(body,L("Favoris"),0,0,16)
    local groups = {
        {label=L("Personnage"),ids={"talents","session","reminders","ranks"}},
        {label=L("Interface"),ids={"tooltips","distance","targetPortrait","bags"}},
        {label=L("Outils"),ids={"flights","advanced"}},
    }
    for _,group in ipairs(groups) do group.title=Label(body,group.label,0,0,16) end
    local function Pinned(card)
        return IsPinned(card.id,card.module)
    end
    local favoriteButtons={}
    home.Refresh=function()
        local width=math.max(1,home:GetWidth()-50)
        local y=heading:GetStringHeight()+10
        Place(searchLabel,0,y,width)
        y=y+searchLabel:GetStringHeight()+6
        Place(search,6,y,math.max(1,width-110)); Place(clearSearch,width-90,y,90)
        y=y+36
        local searching=search:GetText():find("%S")~=nil
        for _,button in ipairs(resultButtons) do button:Hide() end
        searchStatus:SetShown(searching)
        if searching then
            minimap:Hide(); favoritesTitle:Hide()
            for _,group in ipairs(groups) do group.title:Hide() end
            for _,button in ipairs(toolbar) do button:Hide() end
            for _,button in ipairs(favoriteButtons) do button:Hide() end
            for _,card in ipairs(cards) do card:Hide() end
            matches=UI.SearchSettings(search:GetText())
            searchStatus:SetText(#matches==0 and L("Aucun réglage trouvé.") or L("%d résultat(s) — ouvre la rubrique correspondante."):format(#matches))
            Place(searchStatus,0,y,width); y=y+searchStatus:GetStringHeight()+10
            for index,entry in ipairs(matches) do
                local button=resultButtons[index]
                if not button then button=Button(body,"ArkannsQOLHomeSearchResult"..index,"",0,0,width,function() end); resultButtons[index]=button end
                button:SetText(entry.label); button:SetScript("OnClick",function() OpenResult(entry) end)
                local caption=button:GetFontString(); caption:SetWidth(math.max(1,width-20)); caption:SetWordWrap(true)
                Place(button,0,y,width); button:SetHeight(math.max(28,caption:GetStringHeight()+10)); button:Show()
                y=y+button:GetHeight()+6
            end
            body:SetSize(width,y); UI.ClampScroll(scroll,y); return
        end
        matches={}
        -- Frequent actions stay above module cards, regardless of favorites or module count.
        local actionColumns = math.max(1, math.min(#toolbar, math.floor((width + 8) / 138)))
        local actionWidth = (width - (actionColumns - 1) * 8) / actionColumns
        for index, button in ipairs(toolbar) do
            button:Show()
            Place(button, ((index - 1) % actionColumns) * (actionWidth + 8),
                y + math.floor((index - 1) / actionColumns) * 34, actionWidth)
        end
        y = y + math.ceil(#toolbar / actionColumns) * 34 + 8
        for _,card in ipairs(cards) do card:Show() end
        minimap:SetShown(ns.IsMinimapVisible ~= nil)
        if ns.IsMinimapVisible then
            minimap.label:SetWidth(math.max(1,width-32))
            minimap:SetChecked(ns.IsMinimapVisible())
        end
        local columns=width>=900 and 3 or width>=540 and 2 or 1
        local cardWidth=(width-12*(columns-1))/columns
        local titleHeight, summaryHeight, toggleHeight, stackedPreview = 44, 0, 0, false
        -- Measure every module before placing groups, so favorites share the same card size.
        for _, card in ipairs(cards) do
            card:SetWidth(cardWidth)
            card.title:SetWidth(math.max(1,cardWidth-64))
            titleHeight=math.max(titleHeight,card.title:GetStringHeight()+18)
            card.summary:SetText(card.module.Summary and card.module.Summary() or L("Options et préférences."))
            card.summary:SetWidth(math.max(1,cardWidth-24))
            summaryHeight=math.max(summaryHeight,card.summary:GetStringHeight())
            if card.enabled then
                card.enabled:SetChecked(card.module.IsEnabled())
                card.enabled.label:SetWidth(math.max(1,cardWidth-48))
                toggleHeight=math.max(toggleHeight,32,card.enabled.label:GetStringHeight()+12)
            end
            stackedPreview=stackedPreview or (card.preview ~= nil and cardWidth<244)
        end
        local toggleY=titleHeight+summaryHeight+6
        local actionY=toggleY+toggleHeight
        local cardHeight=actionY+36+(stackedPreview and 32 or 0)
        local entries={}
        local advanced=ns.modules.advanced
        if advanced and advanced.Favorites then
            local list=advanced.Favorites()
            for _,entry in ipairs(list or {}) do entries[#entries+1]=entry end
        end
        local favoriteCards={}
        for _,card in ipairs(cards) do if Pinned(card) then favoriteCards[#favoriteCards+1]=card end end
        favoritesTitle:SetShown(#entries>0 or #favoriteCards>0)
        local favoriteColumns=columns
        if #entries>0 or #favoriteCards>0 then
            Place(favoritesTitle,0,y,width)
            y=y+favoritesTitle:GetStringHeight()+8
        end
        for index,entry in ipairs(entries) do
            local button=favoriteButtons[index]
            if not button then button=Button(body,nil,"",0,0,cardWidth,function() end); favoriteButtons[index]=button end
            button:SetText(entry.label); button:SetScript("OnClick",function() ns.StopAllPreviews(); entry.Open() end); button:Show()
            if button:GetFontString():GetUnboundedStringWidth()+20>cardWidth then favoriteColumns=1 end
        end
        local favoriteWidth=(width-12*(favoriteColumns-1))/favoriteColumns
        for index=1,#entries do
            local button=favoriteButtons[index]
            Place(button,((index-1)%favoriteColumns)*(favoriteWidth+12),y,favoriteWidth)
            local caption=button:GetFontString()
            caption:SetWidth(math.max(1,favoriteWidth-20)); caption:SetWordWrap(true)
            local height=math.max(26,caption:GetStringHeight()+8)
            button:SetHeight(height)
            if index%favoriteColumns==0 or index==#entries then y=y+height+6 end
        end
        for index=#entries+1,#favoriteButtons do favoriteButtons[index]:Hide() end
        if #entries>0 then y=y+8 end
        local function DrawCards(list)
            for index,card in ipairs(list) do
                Place(card,((index-1)%columns)*(cardWidth+12),y,cardWidth)
                UI.StyleFrame(card)
                UI.SetFavoriteIcon(card.pin,Pinned(card))
                Place(card.summary,12,titleHeight)
                if card.enabled then Place(card.enabled,8,toggleY) end
                Place(card.configure,12,actionY)
                Place(card.pin,cardWidth-44,actionY)
                if card.preview then
                    local inline=cardWidth>=244
                    Place(card.preview,inline and 120 or 12,inline and actionY or actionY+32)
                end
                card:SetHeight(cardHeight)
                if index%columns==0 or index==#list then y=y+cardHeight+12 end
            end
        end
        DrawCards(favoriteCards)
        for _,group in ipairs(groups) do
            local list={}
            for _,id in ipairs(group.ids) do
                for _,card in ipairs(cards) do
                    if card.id==id and not Pinned(card) then list[#list+1]=card end
                end
            end
            local visible=#list>0
            group.title:SetShown(visible)
            if visible then
                Place(group.title,0,y,width); y=y+group.title:GetStringHeight()+8
                DrawCards(list)
                y=y+12
            end
        end
        if ns.IsMinimapVisible then
            Place(minimap, 0, y + 8)
            y=y+math.max(32,minimap.label:GetStringHeight()+12)+16
        end
        body:SetSize(width,y)
        UI.ClampScroll(scroll,y)
    end
    home:SetScript("OnShow",home.Refresh)
    home:HookScript("OnSizeChanged",home.Refresh)
    search:SetScript("OnTextChanged",function() if home.Refresh then home.Refresh(); scroll:SetVerticalScroll(0) end end)
    search:SetScript("OnEnterPressed",function() if matches[1] then OpenResult(matches[1]) end end)
    search:SetScript("OnEscapePressed",function() search:SetText(""); search:ClearFocus(); home.Refresh() end)
    home:SetScript("OnHide",function() search:ClearFocus(); ns.StopAllPreviews() end)
    function UI.FocusSettingsSearch()
        scroll:SetVerticalScroll(0)
        search:SetFocus()
    end
    home.Refresh()
end

function ns.InitializeInterface(root)
    BuildAppearance(root)
    UI.BuildHome(ns.home)
    local events=CreateFrame("Frame","ArkannsQOLInterfaceEvents")
    for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_LOGOUT","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent",function(_,event)
        if UI.layoutActive then UI.EndLayout(true) else ns.StopAllPreviews() end
        if (event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED") and UI.FitSettingsWindow then UI.FitSettingsWindow() end
    end)
end
