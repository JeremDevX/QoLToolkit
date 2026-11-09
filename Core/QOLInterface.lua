local _, ns = ...
local L = ns.L
ns.modules = {}
local UI = {}
ns.UI = UI
local config, previewBar, layout, home, appearanceRefresh
local styledPanels, styledButtons, styledLabels = {}, {}, {}
local moduleOrder = {"tooltips", "reminders", "session", "talents", "ranks", "distance", "bags", "advanced"}
local defaults = {bg = {.12, .065, .025}, text = {1, .94, .8}, accent = {1, .76, .3},
    font = "standard", fontSize = 13, scale = 1, opacity = .85, borderSize = 12, padding = 12, gap = 6,
    overrides = {}, pins = {}, grid = true, snap = true}
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
local function ApplySkin(frame, style)
    frame:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = style.borderSize, insets = {left = 3, right = 3, top = 3, bottom = 3}})
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
        button:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
        button:GetNormalTexture():SetVertexColor(math.min(1,config.bg[1]+.1), math.min(1,config.bg[2]+.065), math.min(1,config.bg[3]+.035), .95)
        button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
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
    check:SetPoint("TOPLEFT", x, y); Label(check, text, 32, -6)
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

local function StopModulePreviews()
    for _, module in pairs(ns.modules) do if module.StopPreview then pcall(module.StopPreview) end end
    if previewBar then previewBar:Hide() end
end
function ns.StopAllPreviews()
    if UI.layoutActive then UI.EndLayout(true) else StopModulePreviews() end
end
function UI.PreviewModule(id)
    ns.StopAllPreviews()
    local module = ns.modules[id]
    if not module or not module.Preview then return end
    module.Preview()
    if not previewBar then
        previewBar = CreateFrame("Frame", "ArkannsQOLPreviewBar", UIParent, "BackdropTemplate")
        previewBar:SetSize(250, 42); previewBar:SetPoint("TOP", UIParent, "TOP", 0, -25)
        previewBar:SetFrameStrata("DIALOG")
        Button(previewBar, "ArkannsQOLStopPreviews", L("Arrêter les aperçus"), 12, -8, 226, ns.StopAllPreviews)
    end
    UI.StyleFrame(previewBar)
    previewBar:Show()
end

-- Movers are owned frames. Never move or restyle Blizzard's protected action buttons.
local movers, savedPositions, savedLayouts, selected = {}, {}, {}, nil
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
        if x then module.SetPosition(x, y); PositionMover(mover, x, y) end
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
    if cancel then for id, position in pairs(savedPositions) do
        local module = ns.modules[id]
        if savedLayouts[id] and module.ImportSettings then module.ImportSettings(savedLayouts[id])
        elseif module and module.SetPosition then module.SetPosition(position[1], position[2]) end
    end else for id,position in pairs(positions) do ns.modules[id].SetPosition(position[1],position[2]) end end
    endingLayout = nil
end
function UI.StartLayout()
    if InCombatLockdown and InCombatLockdown() then return false, L("Disposition disponible hors combat.") end
    ns.StopAllPreviews()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    if not layout then
        layout = CreateFrame("Frame", "ArkannsQOLLayout", UIParent, "BackdropTemplate")
        layout:SetSize(620, 150); layout:SetPoint("TOP", UIParent, "TOP", 0, -28)
        layout:SetFrameStrata("DIALOG"); layout:SetClampedToScreen(true)
        Label(layout, L("Disposition — glisse les cadres"), 16, -12, 16)
        Button(layout, "ArkannsQOLLayoutApply", L("Valider"), 16, -42, 110, function() UI.EndLayout(false) end)
        Button(layout, "ArkannsQOLLayoutCancel", L("Annuler"), 136, -42, 110, function() UI.EndLayout(true) end)
        Button(layout, "ArkannsQOLLayoutCenter", L("Recentrer"), 256, -42, 110, function()
            if selected then ns.modules[selected].SetPosition(.5, .5); PositionMover(movers[selected], .5, .5); UpdateCoordinates() end
        end)
        Button(layout, "ArkannsQOLLayoutStop", L("Quitter les aperçus"), 376, -42, 226, function() UI.EndLayout(true) end)
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
                ns.modules[selected].SetPosition(x/100, y/100); PositionMover(movers[selected], x/100, y/100)
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
    UI.layoutActive, savedPositions, savedLayouts, selected = true, {}, {}, nil
    for _, id in ipairs(moduleOrder) do
        local module = ns.modules[id]
        if module and module.GetPosition and module.SetPosition and module.frame then
            local x, y = module.GetPosition()
            if Number(x) and Number(y) then
                savedPositions[id] = {x, y}
                if module.ExportSettings then savedLayouts[id]=module.ExportSettings() end
                if module.Preview then module.Preview() end
                module.SetPosition(x,y)
                local mover = movers[id]
                if not mover then
                    mover = CreateFrame("Frame", "ArkannsQOLMover_" .. id, UIParent, "BackdropTemplate")
                    movers[id] = mover
                    mover:SetMovable(true); mover:EnableMouse(true); mover:RegisterForDrag("LeftButton"); mover:SetClampedToScreen(true)
                    mover:SetFrameStrata("DIALOG")
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
                        if Number(mx) and Number(my) then module.SetPosition(mx/UIParent:GetWidth(),my/UIParent:GetHeight()); UpdateCoordinates() end
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
            end
        end
    end
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
    local heading=Label(body, L("Apparence générale — Chaleureux"), 0, 0, 18)
    local description=Label(body, L("Même thème pour tous les modules. Les exceptions restent personnalisables."), 0, -34)
    local fields, syncing = {}, false
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
    Slider("fontSize", L("Taille du texte"), -80, 10, 24)
    Slider("scale", L("Échelle (%)"), -150, 60, 160, 100)
    Slider("opacity", L("Opacité du fond (%)"), -220, 0, 100, 100)
    Slider("borderSize", L("Épaisseur de bordure"), -290, 1, 24)
    Slider("padding", L("Marge intérieure"), -360, 4, 24)
    Slider("gap", L("Espacement"), -430, 0, 20)
    local fontButton = Button(body, "ArkannsQOLCommonFont", "", 0, -500, 330, function()
        config.font = config.font == "standard" and "narrow" or config.font == "narrow" and "fantasy" or "standard"; UI.Refresh()
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
            end
        end
        input:SetScript("OnEnterPressed", Apply)
        colorButtons[key]=Button(body, nil, L("Appliquer"), 340, y, 95, Apply)
    end
    local reset=Button(body, "ArkannsQOLCommonDefaults", L("Rétablir Chaleureux"), 0, -687, 220, function()
        local overrides, pins = config.overrides, config.pins
        local value=Copy(defaults); value.overrides,value.pins=overrides,pins
        UI.ImportSettings(value)
    end)
    local preview=Button(body, "ArkannsQOLCommonPreview", L("Aperçu du journal"), 232, -687, 200, function() UI.PreviewModule("session") end)
    local overrideTitle=Label(body, L("Apparence propre à un module"), 0, -742, 16)
    local overrides = {}
    local overrideOrder = {}
    for _,id in ipairs(moduleOrder) do
        local module = ns.modules[id]
        if module and id ~= "advanced" and id ~= "bags" and id ~= "distance" then
            overrideOrder[#overrideOrder + 1] = id
            overrides[id] = Check(body, "ArkannsQOLCommonOverride_"..id, module.label, 0, -774-(#overrideOrder-1)*34, function(value) UI.SetOverride(id,value) end)
        end
    end
    appearanceRefresh = function()
        syncing = true
        for key, field in pairs(fields) do field.slider:SetValue(config[key]*field.factor); field.caption:SetText(field.title .. " : " .. math.floor(config[key]*field.factor+.5)) end
        for key,input in pairs(colors) do if not input.HasFocus or not input:HasFocus() then
            local c=config[key]; input:SetText(string.format("%02X%02X%02X",math.floor(c[1]*255+.5),math.floor(c[2]*255+.5),math.floor(c[3]*255+.5)))
        end end
        fontButton:SetText(L("Police : ") .. ({standard=L("Classique"),narrow="Arial",fantasy="Morpheus"})[config.font])
        for id,check in pairs(overrides) do check:SetChecked(UI.IsOverride(id)) end
        syncing = false
    end
    local function LayoutAppearance()
        local width=math.max(270,panel:GetWidth()-50)
        local narrow=width<435
        local extra=narrow and 118 or 0
        body:SetSize(width,1050+extra)
        heading:SetWidth(width); heading:SetHeight(44)
        description:ClearAllPoints(); description:SetPoint("TOPLEFT",0,-48); description:SetWidth(width); description:SetHeight(30)
        for _,field in pairs(fields) do field.slider:SetWidth(math.min(330,width-8)) end
        fontButton:SetWidth(math.min(330,width))
        for index,key in ipairs({"bg","text","accent"}) do
            local y=-548-(index-1)*(narrow and 70 or 42)
            colorLabels[key]:ClearAllPoints(); colorLabels[key]:SetPoint("TOPLEFT",0,y-5)
            colors[key]:ClearAllPoints(); colors[key]:SetPoint("TOPLEFT",narrow and 4 or 240,y-(narrow and 28 or 0))
            colorButtons[key]:ClearAllPoints(); colorButtons[key]:SetPoint("TOPLEFT",narrow and 110 or 340,y-(narrow and 28 or 0))
        end
        reset:ClearAllPoints(); reset:SetPoint("TOPLEFT",0,-687-(narrow and 84 or 0))
        preview:ClearAllPoints(); preview:SetPoint("TOPLEFT",narrow and 0 or 232,-687-extra)
        overrideTitle:ClearAllPoints(); overrideTitle:SetPoint("TOPLEFT",0,-742-extra); overrideTitle:SetWidth(width); overrideTitle:SetHeight(38)
        for index,id in ipairs(overrideOrder) do
            overrides[id]:ClearAllPoints(); overrides[id]:SetPoint("TOPLEFT",0,-790-extra-(index-1)*34)
        end
    end
    panel:SetScript("OnShow", function() LayoutAppearance(); appearanceRefresh() end)
    panel:HookScript("OnSizeChanged",LayoutAppearance)
    panel:SetScript("OnHide", ns.StopAllPreviews)
    ns.appearanceCategory = Settings.RegisterCanvasLayoutSubcategory(root,panel,L("Apparence générale"))
    ns.RegisterModule("appearance",{label=L("Apparence générale"),category=function() return ns.appearanceCategory end, ExportSettings=UI.ExportSettings,ImportSettings=UI.ImportSettings})
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
    toolbar[4]=Button(home,"ArkannsQOLHomeStop",L("Arrêter les aperçus"),436,-76,180,ns.StopAllPreviews)
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
            card.title:SetPoint("TOPRIGHT",-42,-14); card.title:SetHeight(22)
            card.summary=Label(card,"",12,-52,12); card.summary:SetHeight(34); card.summary:SetPoint("TOPRIGHT",-12,-52)
            card.configure=Button(card,"ArkannsQOLHome"..names[id],L("Configurer"),12,-91,100,function()
                ns.StopAllPreviews(); local category=module.category and module.category(); if category then Settings.OpenToCategory(category:GetID()) end
            end)
            if module.Preview then Button(card,nil,L("Aperçu"),120,-91,90,function() UI.PreviewModule(id) end) end
            if module.IsEnabled and module.SetEnabled then
                card.enabled=Check(card,"ArkannsQOLHomeEnabled_"..id,"",0,0,function(value) module.SetEnabled(value); home.Refresh() end)
                card.enabled:ClearAllPoints(); card.enabled:SetPoint("TOPRIGHT",-6,-8)
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
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT",16,-84-math.ceil(4/toolbarColumns)*34); scroll:SetPoint("BOTTOMRIGHT",-34,18)
        local columns=width>=540 and 2 or 1
        local cardWidth=(width-12*(columns-1))/columns
        for index,card in ipairs(cards) do
            card:ClearAllPoints(); card:SetPoint("TOPLEFT",((index-1)%columns)*(cardWidth+12),-math.floor((index-1)/columns)*136)
            card:SetSize(cardWidth,126); UI.StyleFrame(card)
            card.pin:ClearAllPoints(); card.pin:SetPoint("BOTTOMRIGHT",-10,9)
            UI.SetFavoriteIcon(card.pin,config.pins[card.id])
            card.summary:SetText(card.module.Summary and card.module.Summary() or L("Options et préférences."))
            if card.enabled then card.enabled:SetChecked(card.module.IsEnabled()) end
        end
        local bottom=math.ceil(#cards/columns)*136+8
        favoritesTitle:ClearAllPoints(); favoritesTitle:SetPoint("TOPLEFT",0,-bottom)
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
        favoritesTitle:SetText(#entries>0 and L("Favoris") or L("Clique sur l’étoile pour épingler un module."))
        for index,entry in ipairs(entries) do
            local button=favoriteButtons[index]
            if not button then button=Button(body,nil,"",0,0,cardWidth,function() end); favoriteButtons[index]=button end
            button:ClearAllPoints(); button:SetPoint("TOPLEFT",0,-bottom-48-(index-1)*32); button:SetWidth(math.min(width,430))
            button:SetText(entry.label); button:SetScript("OnClick",function() ns.StopAllPreviews(); entry.Open() end); button:Show()
        end
        for index=#entries+1,#favoriteButtons do favoriteButtons[index]:Hide() end
        body:SetSize(width,bottom+88+#entries*32)
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
