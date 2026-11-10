local _, ns = ...
local L = ns.L
local WoW = ns.WoW
local db
local dragging = false
local originalScale
local settingsCategory
local tooltipPreview = false
local tooltipSkin, savedSliceAlpha
local tooltipFonts = {}
local nativeTooltipAnchor, restoringNative, tooltipControlled
local distanceAdded, distanceLine, distanceText, distanceElapsed
local RefreshSettings = function() end
local events = CreateFrame("Frame", "ArkannsQOLTooltipEvents")
local anchor = CreateFrame("Frame", "ForeverTooltipLibreAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(290, 90)
anchor:SetFrameStrata("DIALOG")
anchor:SetClampedToScreen(true)
anchor:SetMovable(true)
anchor:EnableMouse(true)
anchor:RegisterForDrag("LeftButton")
anchor:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
anchor:SetBackdropColor(0.04, 0.12, 0.17, 0.95)
anchor:SetBackdropBorderColor(0.2, 0.8, 1)
local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
label:SetPoint("TOP", 0, -12)
label:SetText(L("QoL Toolkit — Infobulles"))
local help = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
help:SetPoint("TOP", label, "BOTTOM", 0, -8)
help:SetText(L("Glisser : déplacer • Clic droit : verrouiller\nAncrage : coin inférieur gauche."))
anchor:Hide()

local function Say(message)
    print("|cff33ccffQoL Toolkit :|r " .. message)
end

local function RestorePosition()
    if dragging then
        anchor:StopMovingOrSizing()
        dragging = false
    end
    anchor:ClearAllPoints()
    local scale=anchor:GetScale()
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x * UIParent:GetWidth()/scale, db.y * UIParent:GetHeight()/scale)
end

local function SavePosition()
    if dragging then
        anchor:StopMovingOrSizing()
        dragging = false
    end
    local x, y = anchor:GetLeft(), anchor:GetBottom()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not x or not y or width <= 0 or height <= 0 then return end
    db.x = math.max(0, math.min(1, x * anchor:GetScale() / width))
    db.y = math.max(0, math.min(1, y * anchor:GetScale() / height))
    RestorePosition()
end

-- Move the original tooltip without rebuilding its contents.
local function RestoreTooltipLook()
    if GameTooltip:IsForbidden() then return end
    if tooltipSkin then tooltipSkin:Hide() end
    if savedSliceAlpha and GameTooltip.NineSlice then GameTooltip.NineSlice:SetAlpha(savedSliceAlpha); savedSliceAlpha = nil end
    for text, font in pairs(tooltipFonts) do text:SetFont(unpack(font)) end
    tooltipFonts = {}
end
local function CaptureNativeAnchor(tooltip, owner, force)
    if restoringNative or (nativeTooltipAnchor and nativeTooltipAnchor.owner==owner and not force) then return end
    local snapshot={owner=owner,points={}}
    local kind = WoW.ReadValue(tooltip.GetAnchorType, tooltip)
    if type(kind) == "string" then snapshot.kind = kind end
    local clamped = WoW.ReadValue(tooltip.IsClampedToScreen, tooltip)
    if type(clamped) == "boolean" then snapshot.clamped = clamped end
    local count = WoW.ReadValue(tooltip.GetNumPoints, tooltip)
    if WoW.IsFiniteNumber(count) and tooltip.GetPoint then
        for index = 1, math.min(count, 8) do
            local status, point, relativeTo, relativePoint, x, y = WoW.Read(tooltip.GetPoint, tooltip, index)
            if status == "ok" and point and relativeTo and relativePoint and x and y then
                snapshot.points[#snapshot.points + 1] = {point, relativeTo, relativePoint, x, y}
            end
        end
    end
    nativeTooltipAnchor=snapshot
    tooltipControlled=false
end
local function RestoreNativeAnchor()
    if restoringNative or not tooltipControlled or GameTooltip:IsForbidden() then return end
    restoringNative=true
    tooltipControlled=false
    local snapshot=nativeTooltipAnchor
    if snapshot and (#snapshot.points>0 or snapshot.kind) then
        GameTooltip:ClearAllPoints(); GameTooltip:SetAnchorType(snapshot.kind or "ANCHOR_NONE")
        for _,point in ipairs(snapshot.points) do GameTooltip:SetPoint(unpack(point)) end
    elseif GameTooltip_SetDefaultAnchor then
        local owner = WoW.ReadValue(GameTooltip.GetOwner, GameTooltip)
        if owner == UIParent or owner == WorldFrame then GameTooltip_SetDefaultAnchor(GameTooltip, owner) end
    end
    if snapshot and snapshot.clamped~=nil then GameTooltip:SetClampedToScreen(snapshot.clamped) end
    restoringNative=nil
end
local function ReleaseTooltip()
    if GameTooltip:IsForbidden() then return end
    RestoreTooltipLook()
    RestoreNativeAnchor()
    if originalScale then GameTooltip:SetScale(originalScale) end
    originalScale, nativeTooltipAnchor, tooltipControlled = nil, nil, nil
end
local function StyleTooltip(tooltip, style)
    if not style then RestoreTooltipLook(); return end
    if not tooltipSkin then
        tooltipSkin = CreateFrame("Frame",nil,tooltip,"BackdropTemplate")
        tooltipSkin:SetAllPoints(); tooltipSkin:EnableMouse(false)
    end
    if tooltip.GetFrameLevel then tooltipSkin:SetFrameLevel(math.max(0,tooltip:GetFrameLevel()-1)) end
    local slice=tooltip.NineSlice
    if slice and slice.GetAlpha and slice.SetAlpha then
        local alpha = WoW.ReadValue(slice.GetAlpha, slice)
        if WoW.IsFiniteNumber(alpha) then
            savedSliceAlpha=savedSliceAlpha or alpha; slice:SetAlpha(0)
        end
    end
    ns.UI.StyleFrame(tooltipSkin,"tooltips"); tooltipSkin:Show()
    if tooltip.NumLines then
        local count = WoW.ReadValue(tooltip.NumLines, tooltip)
        if WoW.IsFiniteNumber(count) then
            for index=1,math.min(100,count) do for _,side in ipairs({"Left","Right"}) do
                local text=_G["GameTooltipText"..side..index]
                if text and text.GetFont then
                    if not tooltipFonts[text] then
                        local status, font, size, flags = WoW.Read(text.GetFont, text)
                        if status == "ok" and type(font) == "string" and WoW.IsFiniteNumber(size) and size > 0 then
                            tooltipFonts[text]={font,size,flags or ""}
                        end
                    end
                    if tooltipFonts[text] then text:SetFont(style.font,style.fontSize+(index==1 and 1 or 0),"") end
                end
            end end
        end
    end
end
local function PositionTooltip(tooltip, data)
    if restoringNative or not db or not db.enabled or tooltip ~= GameTooltip or tooltip:IsForbidden() then return end
    local status, owner = WoW.Read(tooltip.GetOwner, tooltip)
    if status ~= "ok" then return end
    CaptureNativeAnchor(tooltip,owner)
    if db.hideCombat and InCombatLockdown and InCombatLockdown() then
        if originalScale then tooltip:SetScale(originalScale) end
        RestoreTooltipLook(); RestoreNativeAnchor(); return
    end
    local kind
    if not WoW.IsPublic(data) then return end
    if type(data) ~= "table" then data = WoW.ReadValue(tooltip.GetTooltipData, tooltip) end
    if type(data) == "table" and WoW.IsPublic(data.type) and Enum and Enum.TooltipDataType then
        if data.type == Enum.TooltipDataType.Item then kind = "items"
        elseif data.type == Enum.TooltipDataType.Spell then kind = "spells"
        elseif data.type == Enum.TooltipDataType.Unit then kind = "units" end
    end
    if not kind and (owner == UIParent or owner == WorldFrame) then kind = "units" end
    local context = kind and db.contexts and db.contexts[kind]
    local options = context and context.custom and context or db
    if options.enabled == false then
        if originalScale then tooltip:SetScale(originalScale) end
        RestoreTooltipLook()
        RestoreNativeAnchor()
        return
    end
    local scale = WoW.ReadValue(tooltip.GetScale, tooltip)
    if not WoW.IsFiniteNumber(scale) or scale <= 0 then return end
    originalScale = originalScale or scale
    tooltipControlled=true
    local style = ns.UI and ns.UI.GetStyle("tooltips")
    if ns.UI then StyleTooltip(tooltip,style) end
    local desiredScale = originalScale * options.scale / 100 * (style and style.scale or 1)
    if scale ~= desiredScale then tooltip:SetScale(desiredScale) end
    if options.cursor then
        -- Native cursor tracking also covers bags, spells and interface buttons.
        tooltip:ClearAllPoints()
        tooltip:SetAnchorType("ANCHOR_CURSOR_RIGHT", options.offsetX or 16, options.offsetY or 16)
        tooltip:SetClampedToScreen(true)
        return
    end
    if owner ~= UIParent and owner ~= WorldFrame and not (context and context.custom) then return end
    tooltip:SetAnchorType("ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
    tooltip:SetClampedToScreen(true)
end

local function MouseoverDistanceEnabled()
    local units = db.contexts.units
    return db.enabled and db.mouseoverDistance and (not units.custom or units.enabled)
end

local function UnitTooltipGUID(data)
    if not WoW.IsPublic(data) or type(data) ~= "table" then return end
    local kind, guid = data.type, data.guid
    if WoW.IsPublic(kind) and kind == Enum.TooltipDataType.Unit and WoW.IsPublic(guid) and type(guid) == "string" then
        return guid
    end
end

local function StopDistanceUpdates()
    if not distanceElapsed then return end
    distanceElapsed = nil
    events:SetScript("OnUpdate", nil)
    events:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
end

local function ForgetDistanceLine()
    StopDistanceUpdates()
    distanceAdded, distanceLine, distanceText = nil, nil, nil
end

local function UpdateMouseoverDistance(data, processing)
    local tooltip = GameTooltip
    if tooltip:IsForbidden() or (distanceAdded and not distanceLine) then return StopDistanceUpdates() end
    if distanceLine then
        local status, previous = WoW.Read(distanceLine.GetText, distanceLine)
        if status ~= "ok" or (previous or "") ~= distanceText then return StopDistanceUpdates() end
    end
    local shown = WoW.ReadValue(tooltip.IsShown, tooltip)
    -- Keep watching the unit tooltip when selection temporarily interrupts mouseover.
    local guid = (processing or shown) and MouseoverDistanceEnabled() and ns.GetMouseoverDistance
        and tooltip.GetLeftLine and tooltip.AddLine and tooltip.NumLines
        and WoW.ReadValue(UnitTooltipGUID, data or WoW.ReadValue(tooltip.GetTooltipData, tooltip))
    local distance = guid and WoW.ReadValue(UnitGUID, "mouseover") == guid and ns.GetMouseoverDistance()
    local text = distance and L("Distance : %s m"):format(distance)
    local changed
    if distanceLine then
        text = text or ""
        if text ~= distanceText then
            if WoW.Read(distanceLine.SetText, distanceLine, text) ~= "ok" then return StopDistanceUpdates() end
            distanceText, changed = text, true
        end
    elseif text then
        local count = WoW.ReadValue(tooltip.NumLines, tooltip)
        if not WoW.IsFiniteNumber(count) then return StopDistanceUpdates() end
        distanceAdded = true
        if WoW.Read(tooltip.AddLine, tooltip, text, 0.65, 0.85, 1) ~= "ok" then return StopDistanceUpdates() end
        distanceLine = WoW.ReadValue(tooltip.GetLeftLine, tooltip, count + 1)
        distanceText = text
        changed = true
    end
    -- A post-call is followed by the native Show. Live row changes need the same layout pass.
    if changed and not processing and shown then WoW.Read(tooltip.Show, tooltip) end
    if (distanceAdded and not distanceLine) or not guid then return StopDistanceUpdates() end
    return true
end

local function StartDistanceUpdates()
    if distanceElapsed then return end
    distanceElapsed = 0
    events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    events:SetScript("OnUpdate", function(_, delta)
        distanceElapsed = distanceElapsed + delta
        if distanceElapsed < .2 then return end
        distanceElapsed = 0
        UpdateMouseoverDistance()
    end)
end

local function ApplyMouseoverDistanceSetting()
    if ns.SetMouseoverDistanceEnabled then ns.SetMouseoverDistanceEnabled(MouseoverDistanceEnabled()) end
    if UpdateMouseoverDistance() then StartDistanceUpdates() end
end

local function AfterTooltipData(tooltip, data)
    if tooltip == GameTooltip and not distanceElapsed and not tooltip:IsForbidden()
        and MouseoverDistanceEnabled() and WoW.IsPublic(data) and type(data) == "table"
        and data == WoW.ReadValue(tooltip.GetTooltipData, tooltip) and UpdateMouseoverDistance(data, true) then
        StartDistanceUpdates()
    end
    PositionTooltip(tooltip, data)
end

local function NormalizeTooltipOptions()
    if type(db.contexts) ~= "table" then db.contexts = {} end
    for _, key in ipairs({"units", "items", "spells"}) do
        local value = db.contexts[key]
        if type(value) ~= "table" then value = {}; db.contexts[key] = value end
        for _, name in ipairs({"custom", "cursor"}) do if type(value[name]) ~= "boolean" then value[name] = false end end
        if type(value.enabled) ~= "boolean" then value.enabled = true end
        if type(value.scale) ~= "number" or value.scale ~= value.scale or value.scale < 50 or value.scale > 200 then value.scale = 100 end
    end
    for _, value in ipairs({db, db.contexts.units, db.contexts.items, db.contexts.spells}) do
        for _, key in ipairs({"offsetX", "offsetY"}) do
            if type(value[key]) ~= "number" or value[key] ~= value[key] or value[key] < 0 or value[key] > 100 then value[key] = 16 end
        end
    end
    if type(db.hideCombat) ~= "boolean" then db.hideCombat = false end
    if type(db.mouseoverDistance) ~= "boolean" then db.mouseoverDistance = true end
end

local function HideTooltip()
    if GameTooltip:IsForbidden() then return end
    GameTooltip:Hide()
    -- Hide also runs when the tooltip is already hidden, without an OnHide event.
    ReleaseTooltip()
end

anchor:SetScript("OnDragStart", function(self)
    dragging = true
    self:StartMoving()
end)
anchor:SetScript("OnDragStop", SavePosition)
anchor:SetScript("OnHide", function()
    if dragging then SavePosition() end
end)
anchor:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
        SavePosition()
        self:Hide()
        Say(L("Position enregistrée. /qttooltip pour la modifier."))
    end
end)

local function SetEditing(editing)
    if not editing then
        SavePosition()
        anchor:Hide()
        Say(L("Position enregistrée."))
    else
        db.enabled = true
        db.cursor = false
        HideTooltip()
        RestorePosition()
        anchor:Show()
        Say(L("Glisser : déplacer • Clic droit : verrouiller."))
    end
end

SLASH_FOREVERTOOLTIPLIBRE1 = "/qttooltip"
SLASH_FOREVERTOOLTIPLIBRE2 = "/ft"
SLASH_FOREVERTOOLTIPLIBRE3 = "/tooltiplibre"
SlashCmdList.FOREVERTOOLTIPLIBRE = function(message)
    if not db then return end
    local command, argument = message:lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "" then
        SetEditing(not anchor:IsShown())
    elseif command == "unlock" or command == "placer" then
        SetEditing(true)
    elseif command == "lock" then
        SetEditing(false)
    elseif command == "reset" then
        db.x, db.y, db.enabled, db.cursor = 0.65, 0.25, true, false
        HideTooltip()
        RestorePosition()
        anchor:Show()
        Say(L("Position réinitialisée. Glissez le cadre, puis clic droit."))
    elseif command == "off" then
        db.enabled = false
        anchor:Hide()
        HideTooltip()
        Say(L("Désactivé. /qttooltip on pour réactiver."))
    elseif command == "on" then
        db.enabled = true
        Say(L("Activé."))
    elseif command == "taille" or command == "scale" then
        if argument == "" then
            Say(L("Échelle : %s %%. Exemple : /qttooltip taille 120 (50 à 200)."):format(db.scale))
            return
        end
        local value = tonumber((argument:gsub(",", ".")))
        if not value or value ~= value or value < 50 or value > 200 then
            Say(L("Indiquez une taille entre 50 et 200 %. Exemple : /qttooltip taille 120."))
            return
        end
        db.scale = value
        HideTooltip()
        Say(L("Échelle : %s %%."):format(value))
    elseif command == "curseur" or command == "cursor" then
        if argument ~= "" and argument ~= "on" and argument ~= "off" then
            Say(L("/qttooltip curseur on : suivre la souris ; /qttooltip curseur off : position fixe."))
            return
        end
        if argument == "" then db.cursor = not db.cursor else db.cursor = argument == "on" end
        db.enabled = true
        anchor:Hide()
        HideTooltip()
        Say(db.cursor and L("Suivi du curseur activé.") or L("Position fixe restaurée."))
    elseif command == "options" or command == "parametres" then
        if settingsCategory then Settings.OpenToCategory(settingsCategory:GetID()) end
    else
        Say(L("/qttooltip options : paramètres ; /qttooltip : placer ; /qttooltip taille 120 : taille ; /qttooltip curseur on ou off : suivi ; /qttooltip reset : recentrer ; /qttooltip off ou on : désactiver ou activer."))
    end
    RefreshSettings()
end

local function CreateModernSettings(root)
    local UI = ns.UI
    local panel = CreateFrame("Frame", "ForeverTooltipLibreSettings", UIParent, "BackdropTemplate")
    panel:Hide(); UI.StylePanel(panel)
    UI.Label(panel,L("Infobulles"),16,-16,18)
    local intro=UI.Label(panel,L("Position et échelle par type. Le contenu WoW reste intact."),16,-45)
    intro:SetPoint("TOPRIGHT",-16,-45); intro:SetHeight(28)
    local tabs, bodies, pages = {}, {}, {}
    local order = {"behavior", "appearance", "visibility"}
    local captions = {behavior = L("Fonctionnement"), appearance = L("Apparence"), visibility = L("Visibilité")}
    local function Select(selected)
        for key, page in pairs(pages) do page:SetShown(key == selected) end
        for key, button in pairs(tabs) do button:SetEnabled(key ~= selected) end
        ns.StopAllPreviews()
    end
    for index,name in ipairs(order) do
        pages[name]=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
        bodies[name] = CreateFrame("Frame",nil,pages[name]); bodies[name]:SetSize(580,470); pages[name]:SetScrollChild(bodies[name])
        tabs[name] = UI.Button(panel,nil,captions[name],16+(index-1)*194,-78,184,function() Select(name) end)
    end
    local body=bodies.behavior
    local context="general"
    local function Current() return context=="general" and db or db.contexts[context] end
    local kindButton=UI.Button(body,"ArkannsQOLTooltipKind","",0,0,270,function()
        local order={"general","units","items","spells"}
        for i,key in ipairs(order) do if key==context then context=order[i%#order+1]; break end end
        RefreshSettings()
    end)
    local custom=UI.Check(body,"ArkannsQOLTooltipCustom",L("Réglages propres à ce type"),0,-38,function(value) Current().custom=value; HideTooltip(); RefreshSettings() end)
    local enabled=UI.Check(body,"ForeverTooltipLibreEnabled",L("Activer"),0,-78,function(value)
        Current().enabled=value; HideTooltip(); RefreshSettings()
    end)
    local cursor=UI.Check(body,"ForeverTooltipLibreCursor",L("Suivre le curseur"),0,-116,function(value)
        Current().cursor=value; anchor:Hide(); HideTooltip(); RefreshSettings()
    end)
    local positionHelp=UI.Label(body,L("Position fixe : utilise le cadre Infobulles du mode Disposition."),4,-152)
    local place=UI.Button(body,"ForeverTooltipLibrePlace",L("Déplacer"),0,-196,170,UI.StartLayout)
    local center=UI.Button(body,"ForeverTooltipLibreCenter",L("Recentrer"),182,-196,170,function() db.x,db.y=.5,.5; RestorePosition(); RefreshSettings() end)
    local advanced=false
    local advancedBody=CreateFrame("Frame",nil,body); advancedBody:SetPoint("TOPLEFT",0,-282); advancedBody:SetSize(500,95); advancedBody:Hide()
    local advancedButton=UI.Button(body,"ArkannsQOLTooltipAdvanced",L("Avancé +"),0,-242,170,function()
        advanced=not advanced; advancedBody:SetShown(advanced)
    end)
    UI.Label(advancedBody,L("Marge X / Y du curseur"),0,0)
    local offsetX=UI.Input(advancedBody,"ArkannsQOLTooltipOffsetX",4,-30,65)
    local offsetY=UI.Input(advancedBody,"ArkannsQOLTooltipOffsetY",84,-30,65)
    local function ApplyOffsets()
        local x,y=tonumber((offsetX:GetText():gsub(",", "."))), tonumber((offsetY:GetText():gsub(",", ".")))
        if x and y and x>=0 and x<=100 and y>=0 and y<=100 then Current().offsetX,Current().offsetY=x,y; HideTooltip(); RefreshSettings() end
    end
    UI.Button(advancedBody,nil,L("Appliquer"),164,-30,106,ApplyOffsets)
    offsetX:SetScript("OnEnterPressed",ApplyOffsets); offsetY:SetScript("OnEnterPressed",ApplyOffsets)
    local typeDefaults=UI.Button(body,"ForeverTooltipLibreDefaults",L("Défaut de ce type"),0,-390,190,function()
        local target=Current(); target.enabled,target.cursor,target.scale,target.offsetX,target.offsetY=true,false,100,16,16
        if context~="general" then target.custom=false end
        HideTooltip(); RefreshSettings()
    end)
    local a=bodies.appearance
    local own=UI.Check(a,"ArkannsQOLTooltipOwnStyle",L("Apparence propre à ce module"),0,0,function(value) UI.SetOverride("tooltips",value) end)
    UI.Button(a,nil,L("Reprendre le thème commun"),0,-42,260,function() UI.SetOverride("tooltips",false) end)
    local scaleHelp=UI.Label(a,L("L’échelle ci-dessous s’applique au type sélectionné dans Fonctionnement."),0,-78)
    local sizeLabel=UI.Label(a,"",0,-126)
    local size=CreateFrame("Slider","ForeverTooltipLibreSize",a,"BackdropTemplate")
    size:SetPoint("TOPLEFT",4,-158); size:SetSize(330,18); size:SetOrientation("HORIZONTAL")
    size:SetMinMaxValues(50,200); size:SetValueStep(1); size:SetObeyStepOnDrag(true)
    size:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background",edgeFile="Interface\\Buttons\\UI-SliderBar-Border",edgeSize=8})
    size:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); size:GetThumbTexture():SetSize(28,28)
    local syncing
    size:SetScript("OnValueChanged",function(_,value)
        if syncing then return end
        Current().scale=math.max(50,math.min(200,math.floor(value+.5))); HideTooltip(); RefreshSettings()
    end)
    UI.Button(a,"ArkannsQOLTooltipPreview",L("Aperçu"),0,-210,160,function() UI.PreviewModule("tooltips") end)
    local stopPreview=UI.Button(a,nil,L("Arrêter l’aperçu"),172,-210,180,ns.StopAllPreviews)
    local appearanceDefaults=UI.Button(a,nil,L("Défaut d’apparence"),0,-256,220,function() Current().scale=100; UI.SetOverride("tooltips",false); RefreshSettings() end)
    local v=bodies.visibility
    local hideCombat=UI.Check(v,"ArkannsQOLTooltipCombat",L("Garder le placement WoW en combat"),0,0,function(value) db.hideCombat=value; HideTooltip() end)
    local combatHelp=UI.Label(v,L("Les infobulles restent visibles. Seul le placement personnalisé est suspendu."),0,-42)
    local mouseoverDistance=UI.Check(v,"ArkannsQOLTooltipMouseoverDistance",L("Afficher la distance au survol"),0,-92,function(value)
        db.mouseoverDistance=value; ApplyMouseoverDistanceSetting()
    end)
    UI.Button(v,nil,L("Défaut de visibilité"),0,-134,220,function() db.hideCombat=false; db.mouseoverDistance=true; RefreshSettings() end)
    RefreshSettings=function()
        syncing=true
        local options=Current()
        kindButton:SetText(({general=L("Réglages généraux"),units=L("Unités et interactions"),items=L("Objets"),spells=L("Sorts")})[context])
        custom:SetShown(context~="general"); custom:SetChecked(options.custom)
        enabled:SetChecked(options.enabled); cursor:SetChecked(options.cursor); size:SetValue(options.scale)
        local canEdit=context=="general" or options.custom
        enabled:SetEnabled(canEdit); cursor:SetEnabled(canEdit); size:SetEnabled(canEdit)
        sizeLabel:SetText(L("Échelle : %s %%"):format(options.scale))
        offsetX:SetText(tostring(options.offsetX)); offsetY:SetText(tostring(options.offsetY))
        offsetX:SetEnabled(canEdit); offsetY:SetEnabled(canEdit)
        advancedButton:SetText(advanced and L("Avancé −") or L("Avancé +"))
        own:SetChecked(UI.IsOverride("tooltips")); hideCombat:SetChecked(db.hideCombat); mouseoverDistance:SetChecked(db.mouseoverDistance)
        ApplyMouseoverDistanceSetting()
        UI.StyleFrame(anchor,"tooltips")
        local style=UI.GetStyle("tooltips")
        local previousScale=anchor:GetScale()
        anchor:SetScale(style and style.scale*options.scale/100 or options.scale/100)
        if previousScale~=anchor:GetScale() and not dragging then RestorePosition() end
        if style then
            label:SetTextColor(unpack(style.accent)); help:SetTextColor(unpack(style.text)); label:SetFont(style.font,style.fontSize+1,""); help:SetFont(style.font,style.fontSize,"")
            anchor:SetSize(math.max(290,style.fontSize*24),math.max(90,style.fontSize*4+style.padding*2+style.gap))
            label:ClearAllPoints(); label:SetPoint("TOP",0,-style.padding)
            help:ClearAllPoints(); help:SetPoint("TOP",label,"BOTTOM",0,-style.gap)
        else
            anchor:SetSize(290,90)
            anchor:SetBackdropColor(.04,.12,.17,.95); anchor:SetBackdropBorderColor(.2,.8,1)
            label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",13,""); help:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",12,"")
            label:SetTextColor(1,.82,0); help:SetTextColor(1,1,1)
            label:ClearAllPoints(); label:SetPoint("TOP",0,-12); help:ClearAllPoints(); help:SetPoint("TOP",label,"BOTTOM",0,-8)
        end
        label:SetWidth(anchor:GetWidth()-24); help:SetWidth(anchor:GetWidth()-24)
        if tooltipPreview then label:SetText(L("Loup des bois — Niveau 12")); help:SetText(L("Bête • Ennemi\nQuête : Loups abattus 2 / 5")) end
        syncing=false
    end
    panel.OnRefresh=RefreshSettings
    panel.OnDefault=function() db.enabled,db.cursor,db.scale,db.x,db.y=true,false,100,.65,.25; db.contexts={}; db.mouseoverDistance=true; NormalizeTooltipOptions(); HideTooltip(); RestorePosition(); RefreshSettings() end
    local function LayoutSettings()
        local width=math.max(320,panel:GetWidth())
        local bodyWidth=width-50
        local extra=bodyWidth<352 and 34 or 0
        local columns=math.max(1,math.min(3,math.floor((width-32)/175)))
        local tabWidth=(width-32)/columns
        for index,name in ipairs(order) do
            tabs[name]:ClearAllPoints(); tabs[name]:SetPoint("TOPLEFT",16+((index-1)%columns)*tabWidth,-78-math.floor((index-1)/columns)*34)
            tabs[name]:SetWidth(tabWidth-10)
            pages[name]:ClearAllPoints(); pages[name]:SetPoint("TOPLEFT",16,-90-math.ceil(3/columns)*34); pages[name]:SetPoint("BOTTOMRIGHT",-34,16)
            bodies[name]:SetSize(bodyWidth,470+extra)
        end
        positionHelp:SetWidth(bodyWidth-4); positionHelp:SetHeight(40)
        scaleHelp:SetWidth(bodyWidth); scaleHelp:SetHeight(42)
        combatHelp:SetWidth(bodyWidth); combatHelp:SetHeight(42)
        size:SetWidth(math.min(330,bodyWidth-8))
        center:ClearAllPoints(); center:SetPoint("TOPLEFT",extra>0 and 0 or 182,-196-extra)
        advancedButton:ClearAllPoints(); advancedButton:SetPoint("TOPLEFT",0,-242-extra)
        advancedBody:ClearAllPoints(); advancedBody:SetPoint("TOPLEFT",0,-282-extra); advancedBody:SetWidth(bodyWidth)
        typeDefaults:ClearAllPoints(); typeDefaults:SetPoint("TOPLEFT",0,-390-extra)
        stopPreview:ClearAllPoints(); stopPreview:SetPoint("TOPLEFT",extra>0 and 0 or 172,-210-extra)
        appearanceDefaults:ClearAllPoints(); appearanceDefaults:SetPoint("TOPLEFT",0,-256-extra)
    end
    panel:SetScript("OnShow",function() ns.StopAllPreviews(); LayoutSettings(); RefreshSettings() end)
    panel:HookScript("OnSizeChanged",LayoutSettings)
    panel:SetScript("OnHide",ns.StopAllPreviews)
    settingsCategory=Settings.RegisterCanvasLayoutSubcategory(root,panel,L("Infobulles"))
    ns.RegisterModule("tooltips",{
        label=L("Infobulles"),icon="Interface\\Icons\\INV_Misc_Note_01",frame=anchor,category=function() return settingsCategory end,
        IsEnabled=function() return db.enabled end,SetEnabled=function(value) db.enabled=value; HideTooltip(); RefreshSettings() end,
        Summary=function() return db.cursor and L("Suit le curseur") or L("Position fixe • %s %%"):format(db.scale) end,
        Preview=function() tooltipPreview=true; RestorePosition(); RefreshSettings(); anchor:Show() end,
        StopPreview=function() tooltipPreview=false; anchor:Hide(); label:SetText(L("QoL Toolkit — Infobulles")); help:SetText(L("Glisser : déplacer • Clic droit : verrouiller")) end,
        Refresh=function() RefreshSettings(); if db.enabled and GameTooltip:IsShown() then PositionTooltip(GameTooltip) end end,
        GetPosition=function()
            local scale=anchor:GetScale(); return db.x+anchor:GetWidth()*scale/(2*UIParent:GetWidth()),db.y+anchor:GetHeight()*scale/(2*UIParent:GetHeight())
        end,
        SetPosition=function(x,y)
            local scale=anchor:GetScale(); db.x=math.max(0,math.min(1,x-anchor:GetWidth()*scale/(2*UIParent:GetWidth()))); db.y=math.max(0,math.min(1,y-anchor:GetHeight()*scale/(2*UIParent:GetHeight())))
            RestorePosition()
        end,
        ExportSettings=function()
            local result={mouseoverDistance=db.mouseoverDistance}; for _,key in ipairs({"enabled","cursor","scale","x","y","contexts","offsetX","offsetY","hideCombat"}) do result[key]=UI.Copy(db[key]) end; return result
        end,
        profileMigrations={function(config,current)
            if config.mouseoverDistance == nil then config.mouseoverDistance=current.mouseoverDistance end
        end},
        ImportSettings=function(value)
            if type(value)~="table" or type(value.enabled)~="boolean" or type(value.cursor)~="boolean" or type(value.scale)~="number" or value.scale~=value.scale or value.scale<50 or value.scale>200 then return false,L("Infobulles invalides.") end
            for _,key in ipairs({"x","y"}) do if type(value[key])~="number" or value[key]~=value[key] or value[key]<0 or value[key]>1 then return false,L("Position invalide.") end end
            if value.mouseoverDistance ~= nil and type(value.mouseoverDistance) ~= "boolean" then return false,L("Infobulles invalides.") end
            for _,key in ipairs({"enabled","cursor","scale","x","y","contexts","offsetX","offsetY","hideCombat"}) do db[key]=UI.Copy(value[key]) end
            if value.mouseoverDistance ~= nil then db.mouseoverDistance=value.mouseoverDistance end
            NormalizeTooltipOptions(); HideTooltip(); RestorePosition(); RefreshSettings(); return true
        end,
    })
    Select("behavior"); LayoutSettings(); RefreshSettings()
end

local function CreateSettings(root)
    if ns.UI then CreateModernSettings(root); return end
    local panel = CreateFrame("Frame", "ForeverTooltipLibreSettings", UIParent)
    panel:Hide()

    local function Text(text, y, font)
        local label = panel:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 16, y)
        label:SetPoint("TOPRIGHT", -16, y)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end
    local function Checkbox(name, text, y)
        local box = CreateFrame("CheckButton", name, panel, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 12, y)
        local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", box, "RIGHT", 2, 0)
        label:SetText(text)
        box:SetFontString(label)
        return box
    end
    local function Button(name, text, x, y, width, callback)
        local button = CreateFrame("Button", name, panel, "UIPanelButtonTemplate")
        button:SetSize(width, 26)
        button:SetPoint("TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", callback)
        return button
    end
    local function Place(command)
        -- Close the settings window so it does not cover the movable frame.
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        SlashCmdList.FOREVERTOOLTIPLIBRE(command)
    end

    Text(L("Infobulles"), -16, "GameFontNormalLarge")
    Text(L("Réglages communs aux personnages."), -44)
    local enabled = Checkbox("ForeverTooltipLibreEnabled", L("Activer"), -72)
    local cursor = Checkbox("ForeverTooltipLibreCursor", L("Suivre le curseur"), -108)
    local mouseoverDistance = Checkbox("ArkannsQOLTooltipMouseoverDistance", L("Afficher la distance au survol"), -408)
    Text(L("Désactivé : position fixe pour les PNJ et objets."), -144)
    local sizeLabel = Text("", -178, "GameFontNormal")

    -- Build a standard slider without the obsolete OptionsSliderTemplate.
    local size = CreateFrame("Slider", "ForeverTooltipLibreSize", panel, "BackdropTemplate")
    size:SetPoint("TOPLEFT", 20, -204)
    size:SetSize(300, 18)
    size:SetOrientation("HORIZONTAL")
    size:SetMinMaxValues(50, 200)
    size:SetValueStep(1)
    size:SetObeyStepOnDrag(true)
    size:EnableMouse(true)
    size:SetBackdrop({bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", tile = true, tileSize = 8, edgeSize = 8, insets = {left = 3, right = 3, top = 3, bottom = 3}})
    size:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    size:GetThumbTexture():SetSize(32, 32)
    Text(L("100 % : taille native."), -234)

    local place = Button("ForeverTooltipLibrePlace", L("Déplacer"), 16, -268, 180, function() Place("placer") end)
    local center = Button("ForeverTooltipLibreCenter", L("Recentrer"), 208, -268, 180, function() Place("reset") end)
    Text(L("Glisser : déplacer • Clic droit : verrouiller."), -310)
    Text(L("Survole à nouveau pour voir les changements.\nSuivi du curseur : PNJ, objets, sacs et sorts. Hors comparaisons."), -346)

    local syncing = false
    RefreshSettings = function()
        syncing = true
        enabled:SetChecked(db.enabled)
        cursor:SetChecked(db.cursor)
        mouseoverDistance:SetChecked(db.mouseoverDistance)
        ApplyMouseoverDistanceSetting()
        cursor:SetEnabled(db.enabled)
        size:SetEnabled(db.enabled)
        size:SetAlpha(db.enabled and 1 or 0.5)
        size:SetValue(db.scale)
        sizeLabel:SetText(L("Échelle : %s %%"):format(db.scale))
        place:SetEnabled(db.enabled and not db.cursor)
        center:SetEnabled(db.enabled and not db.cursor)
        syncing = false
    end
    enabled:SetScript("OnClick", function(self)
        SlashCmdList.FOREVERTOOLTIPLIBRE(self:GetChecked() and "on" or "off")
    end)
    cursor:SetScript("OnClick", function(self)
        SlashCmdList.FOREVERTOOLTIPLIBRE(self:GetChecked() and "curseur on" or "curseur off")
    end)
    mouseoverDistance:SetScript("OnClick", function(self)
        db.mouseoverDistance=self:GetChecked(); ApplyMouseoverDistanceSetting()
    end)
    size:SetScript("OnValueChanged", function(_, value)
        if syncing or not db.enabled then return end
        db.scale = math.max(50, math.min(200, math.floor(value + 0.5)))
        HideTooltip()
        RefreshSettings()
    end)
    local function Defaults()
        anchor:Hide()
        db.enabled, db.cursor, db.scale, db.x, db.y = true, false, 100, 0.65, 0.25
        db.mouseoverDistance = true
        HideTooltip()
        RestorePosition()
        RefreshSettings()
    end
    Button("ForeverTooltipLibreDefaults", L("Valeurs par défaut"), 16, -446, 180, Defaults)
    panel:SetScript("OnShow", RefreshSettings)
    panel.OnRefresh = RefreshSettings
    panel.OnDefault = Defaults
    settingsCategory = Settings.RegisterCanvasLayoutSubcategory(root, panel, L("Infobulles"))
    RefreshSettings()
end

function ns.InitializeTooltips(root)
    if db then return end
    db = ForeverTooltipLibreDB
    for key, value in pairs({x = 0.65, y = 0.25}) do
        if type(db[key]) ~= "number" or db[key] ~= db[key] then db[key] = value end
        db[key] = math.max(0, math.min(1, db[key]))
    end
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.cursor) ~= "boolean" then db.cursor = false end
    if type(db.scale) ~= "number" or db.scale ~= db.scale or db.scale < 50 or db.scale > 200 then db.scale = 100 end
    NormalizeTooltipOptions()
    RestorePosition()
    CreateSettings(root)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip)
        if tooltip==GameTooltip and not tooltip:IsForbidden() and not restoringNative then
            local status, owner = WoW.Read(tooltip.GetOwner, tooltip)
            if status == "ok" then CaptureNativeAnchor(tooltip, owner, true) end
        end
        PositionTooltip(tooltip)
    end)
    GameTooltip:HookScript("OnShow", PositionTooltip)
    GameTooltip:HookScript("OnHide", function() ForgetDistanceLine(); ReleaseTooltip() end)
    GameTooltip:HookScript("OnTooltipCleared", ForgetDistanceLine)
    if GameTooltip.ClearLines then hooksecurefunc(GameTooltip, "ClearLines", ForgetDistanceLine) end
    -- Also handles consecutive mouseovers and refreshed quest lines.
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, AfterTooltipData)
    end
end

for _, event in ipairs({"DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_LOGOUT", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if not db then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if db.hideCombat and GameTooltip:IsShown() then PositionTooltip(GameTooltip) end
        UpdateMouseoverDistance()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        UpdateMouseoverDistance()
    elseif event == "PLAYER_LOGOUT" then
        if dragging then SavePosition() end
    else
        RestorePosition()
    end
end)
