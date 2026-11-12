local _, ns = ...
local L = ns.L
local WoW = ns.WoW
local db
local originalScale
local settingsCategory
local tooltipPreview = false
local tooltipSkin, savedSliceAlpha
local tooltipFonts = {}
local nativeTooltipAnchor, restoringNative, tooltipControlled
local distanceAdded, distanceLine, distanceText, distanceColor, distanceElapsed
local RefreshSettings = function() end
local events = CreateFrame("Frame", "ArkannsQOLTooltipEvents")
local anchor = CreateFrame("Frame", "ForeverTooltipLibreAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(290, 90)
anchor:SetFrameStrata("MEDIUM")
anchor:SetClampedToScreen(true)
anchor:EnableMouse(false)
anchor:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
anchor:SetBackdropColor(0.04, 0.12, 0.17, 0.95)
anchor:SetBackdropBorderColor(0.2, 0.8, 1)
local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
label:SetPoint("TOP", 0, -12)
label:SetText(L("QoL Toolkit — Infobulles"))
local help = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
help:SetPoint("TOP", label, "BOTTOM", 0, -8)
help:SetText(L("Position fixe des infobulles."))
anchor:Hide()

local function Say(message)
    print("|cff33ccffQoL Toolkit :|r " .. message)
end

local function RestorePosition()
    anchor:ClearAllPoints()
    local scale=anchor:GetScale()
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x * UIParent:GetWidth()/scale, db.y * UIParent:GetHeight()/scale)
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
    return db.mouseoverDistance
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
    distanceAdded, distanceLine, distanceText, distanceColor = nil, nil, nil, nil
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
    local text, color
    if guid and WoW.ReadValue(UnitGUID, "mouseover") == guid then
        text, color = ns.GetMouseoverDistance()
    end
    local changed
    if distanceLine then
        text = text or ""
        if text ~= distanceText then
            if WoW.Read(distanceLine.SetText, distanceLine, text) ~= "ok" then return StopDistanceUpdates() end
            distanceText, changed = text, true
        end
        if color and (changed or color ~= distanceColor) then WoW.Read(distanceLine.SetTextColor, distanceLine, unpack(color)) end
        distanceColor = color
    elseif text then
        local count = WoW.ReadValue(tooltip.NumLines, tooltip)
        if not WoW.IsFiniteNumber(count) then return StopDistanceUpdates() end
        distanceAdded = true
        if WoW.Read(tooltip.AddLine, tooltip, text, unpack(color)) ~= "ok" then return StopDistanceUpdates() end
        distanceLine = WoW.ReadValue(tooltip.GetLeftLine, tooltip, count + 1)
        distanceText, distanceColor = text, color
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

function ns.GetMouseoverDistanceSetting()
    return (db or ForeverTooltipLibreDB).mouseoverDistance ~= false
end

function ns.SetMouseoverDistanceSetting(value)
    (db or ForeverTooltipLibreDB).mouseoverDistance = value == true
    if db then ApplyMouseoverDistanceSetting() end
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

anchor:SetScript("OnHide", function()
    if tooltipPreview then
        tooltipPreview = false
        if ns.UI.PreviewEnded then ns.UI.PreviewEnded("tooltips") end
    end
end)

local function SetEditing(editing)
    if editing then ns.UI.StartLayout("tooltips")
    elseif ns.UI.layoutActive then ns.UI.EndLayout(false)
    else ns.StopAllPreviews() end
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
        ns.UI.StartLayout("tooltips")
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
        if settingsCategory then ns.UI.OpenCategory(settingsCategory) end
    else
        Say(L("/qttooltip options : paramètres ; /qttooltip : placer ; /qttooltip taille 120 : taille ; /qttooltip curseur on ou off : suivi ; /qttooltip reset : recentrer ; /qttooltip off ou on : désactiver ou activer."))
    end
    RefreshSettings()
end

local function CreateModernSettings(root)
    local UI = ns.UI
    local panel = CreateFrame("Frame", "ForeverTooltipLibreSettings", UIParent, "BackdropTemplate")
    panel:Hide(); UI.StylePanel(panel)
    UI.Label(panel,L("Infobulles et distance"),16,-16,18)
    local intro=UI.Label(panel,L("Position et échelle par type. Le contenu WoW reste intact."),16,-45)
    local tabs, bodies, pages = {}, {}, {}
    local LayoutSettings, appearanceLink
    local order = {"appearance", "behavior"}
    local captions = {behavior = L("Options avancées"), appearance = L("Infobulles")}
    local activePage, context = "appearance", "general"
    local function Select(selected)
        activePage = selected
        if selected=="appearance" then context="general" end
        for key, page in pairs(pages) do page:SetShown(key == selected) end
        for key, button in pairs(tabs) do button:SetEnabled(key ~= selected) end
        ns.StopAllPreviews()
        if LayoutSettings then RefreshSettings() end
    end
    for index,name in ipairs(order) do
        pages[name]=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
        bodies[name] = CreateFrame("Frame",nil,pages[name]); bodies[name]:SetSize(580,470); pages[name]:SetScrollChild(bodies[name])
        tabs[name] = UI.Button(panel,nil,captions[name],16+(index-1)*194,-78,184,function()
            if name=="behavior" then context="units" end
            Select(name)
        end)
    end
    local body=bodies.behavior
    local offsetX, offsetY
    local function Current() return context=="general" and db or db.contexts[context] end
    local kindOrder={"general","units","items","spells"}
    local kinds={general=L("Réglages généraux"),units=L("Unités et interactions"),items=L("Objets"),spells=L("Sorts")}
    local function SetContext(key)
        offsetX:ClearFocus(); offsetY:ClearFocus()
        context=key; RefreshSettings()
    end
    local function SelectType(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then
            for index,key in ipairs(kindOrder) do
                if key==context then SetContext(kindOrder[index%#kindOrder+1]); return end
            end
            return
        end
        MenuUtil.CreateContextMenu(self,function(_,menu)
            for _,kind in ipairs(kindOrder) do
                local key=kind
                menu:CreateButton(kinds[key],function() SetContext(key) end)
            end
        end)
    end
    local kindButton=UI.Button(body,"ArkannsQOLTooltipKind","",0,0,270,SelectType)
    local custom=UI.Check(body,"ArkannsQOLTooltipCustom",L("Réglages propres à ce type"),0,-38,function(value) Current().custom=value; HideTooltip(); RefreshSettings() end)
    local enabled=UI.Check(body,"ForeverTooltipLibreEnabled",L("Personnaliser les infobulles"),0,-78,function(value)
        Current().enabled=value; HideTooltip(); RefreshSettings()
    end)
    local cursor=UI.Check(body,"ForeverTooltipLibreCursor",L("Suivre le curseur"),0,-116,function(value)
        Current().cursor=value; anchor:Hide(); HideTooltip(); RefreshSettings()
    end)
    local inherited=UI.Label(body,L("Ce type utilise les réglages généraux."),4,0)
    local positionHelp=UI.Label(body,L("La position fixe est commune à tous les types."),4,-152)
    local place=UI.Button(body,"ForeverTooltipLibrePlace",L("Déplacer"),0,-196,170,function() UI.StartLayout("tooltips") end)
    local center=UI.Button(body,"ForeverTooltipLibreCenter",L("Recentrer"),182,-196,170,function() db.x,db.y=.5,.5; RestorePosition(); RefreshSettings() end)
    local advanced=false
    local advancedBody=CreateFrame("Frame",nil,body); advancedBody:SetPoint("TOPLEFT",0,-282); advancedBody:SetSize(500,95); advancedBody:Hide()
    local advancedButton=UI.Button(body,"ArkannsQOLTooltipAdvanced",L("Décalage du curseur"),0,-242,270,function()
        advanced=not advanced; RefreshSettings()
    end)
    UI.Label(advancedBody,L("Décalage X / Y (0 à 100)"),0,0)
    offsetX=UI.Input(advancedBody,"ArkannsQOLTooltipOffsetX",4,-30,65)
    offsetY=UI.Input(advancedBody,"ArkannsQOLTooltipOffsetY",84,-30,65)
    local function ApplyOffsets()
        local x,y=tonumber((offsetX:GetText():gsub(",", "."))), tonumber((offsetY:GetText():gsub(",", ".")))
        if x and y and x>=0 and x<=100 and y>=0 and y<=100 then
            Current().offsetX,Current().offsetY=x,y
            offsetX:ClearFocus(); offsetY:ClearFocus()
            HideTooltip(); RefreshSettings()
        else
            UI.Notify(L("Saisis deux valeurs entre 0 et 100."))
        end
    end
    UI.Button(advancedBody,nil,L("Appliquer"),164,-30,106,ApplyOffsets)
    offsetX:SetScript("OnEnterPressed",ApplyOffsets); offsetY:SetScript("OnEnterPressed",ApplyOffsets)
    local typeDefaults=UI.Button(body,"ForeverTooltipLibreDefaults",L("Défaut de ce type"),0,-390,190,function()
        local key, target=context,Current()
        UI.Confirm(L("Rétablir les réglages par défaut pour « %s » ?"):format(kinds[key]),function()
            if target~=(key=="general" and db or db.contexts[key]) then return end
            target.enabled,target.cursor,target.scale,target.offsetX,target.offsetY=true,false,100,16,16
            if key~="general" then target.custom=false end
            HideTooltip(); RefreshSettings()
        end)
    end)
    local a=bodies.appearance
    local placementHeading=UI.Label(a,L("Infobulles"),0,0,15)
    local appearanceHeading=UI.Label(a,L("Apparence"),0,0,15)
    local generalEnabled=UI.Check(a,"ArkannsQOLTooltipGeneralEnabled",L("Personnaliser les infobulles"),0,0,function(value)
        db.enabled=value; HideTooltip(); RefreshSettings()
    end)
    local generalCursor=UI.Check(a,"ArkannsQOLTooltipGeneralCursor",L("Suivre le curseur"),0,-36,function(value)
        db.cursor=value; anchor:Hide(); HideTooltip(); RefreshSettings()
    end)
    local generalPlace=UI.Button(a,"ArkannsQOLTooltipGeneralPlace",L("Déplacer"),0,-72,170,function() UI.StartLayout("tooltips") end)
    local generalCenter=UI.Button(a,"ArkannsQOLTooltipGeneralCenter",L("Recentrer"),182,-72,170,function()
        db.x,db.y=.5,.5; RestorePosition(); RefreshSettings()
    end)
    local own=UI.Check(a,"ArkannsQOLTooltipOwnStyle",L("Apparence propre à ce module"),0,0,function(value) UI.SetOverride("tooltips",value) end)
    local sizeLabel=UI.Label(a,"",0,-126)
    local size=CreateFrame("Slider","ForeverTooltipLibreSize",a,"BackdropTemplate")
    size:SetPoint("TOPLEFT",4,-158); size:SetSize(330,18); size:SetOrientation("HORIZONTAL")
    size:SetMinMaxValues(50,200); size:SetValueStep(1); size:SetObeyStepOnDrag(true)
    size:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background",edgeFile="Interface\\Buttons\\UI-SliderBar-Border",edgeSize=8})
    size:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); size:GetThumbTexture():SetSize(28,28)
    local syncing
    size:SetScript("OnValueChanged",function(_,value)
        if syncing then return end
        db.scale=math.max(50,math.min(200,math.floor(value+.5))); HideTooltip(); RefreshSettings()
    end)
    local typeSizeLabel=UI.Label(body,"",0,0)
    local typeSize=CreateFrame("Slider","ArkannsQOLTooltipTypeSize",body,"BackdropTemplate")
    typeSize:SetSize(330,18); typeSize:SetOrientation("HORIZONTAL")
    typeSize:SetMinMaxValues(50,200); typeSize:SetValueStep(1); typeSize:SetObeyStepOnDrag(true)
    typeSize:SetBackdrop({bgFile="Interface\\Buttons\\UI-SliderBar-Background",edgeFile="Interface\\Buttons\\UI-SliderBar-Border",edgeSize=8})
    typeSize:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); typeSize:GetThumbTexture():SetSize(28,28)
    typeSize:SetScript("OnValueChanged",function(_,value)
        if syncing then return end
        Current().scale=math.max(50,math.min(200,math.floor(value+.5))); HideTooltip(); RefreshSettings()
    end)
    local preview=UI.Button(a,"ArkannsQOLTooltipPreview",L("Aperçu"),0,-210,160,function() UI.PreviewModule("tooltips") end)
    local appearanceDefaults=UI.Button(a,nil,L("Défaut d’apparence"),0,-256,220,function()
        local key, target=context,Current()
        UI.Confirm(L("Rétablir l’échelle de « %s » et le thème commun des infobulles ?"):format(kinds[key]),function()
            if target~=(key=="general" and db or db.contexts[key]) then return end
            target.scale=100; UI.SetOverride("tooltips",false); RefreshSettings()
        end)
    end)
    local v=bodies.behavior
    local hideCombat=UI.Check(v,"ArkannsQOLTooltipCombat",L("Garder le placement WoW en combat"),0,0,function(value) db.hideCombat=value; HideTooltip() end)
    local combatHelp=UI.Label(v,L("Les infobulles restent visibles. Seul le placement personnalisé est suspendu."),0,-42)
    local visibilityDefaults=UI.Button(v,nil,L("Défaut de visibilité"),0,-134,220,function() db.hideCombat=false; RefreshSettings() end)
    RefreshSettings=function()
        syncing=true
        local options=Current()
        kindButton:SetText(kinds[context])
        custom:SetChecked(options.custom)
        enabled.label:SetText(context=="general" and L("Personnaliser les infobulles") or L("Personnaliser ce type"))
        local canEdit=context=="general" or options.custom
        local effective=canEdit and options or db
        enabled:SetChecked(options.enabled); cursor:SetChecked(options.cursor); size:SetValue(db.scale)
        typeSize:SetValue(effective.scale); typeSize:SetEnabled(canEdit==true)
        sizeLabel:SetText(L("Échelle : %s %%"):format(db.scale))
        typeSizeLabel:SetText((canEdit and L("Échelle : %s %%") or L("Échelle héritée : %s %%")):format(effective.scale))
        if not offsetX:HasFocus() then offsetX:SetText(tostring(options.offsetX)) end
        if not offsetY:HasFocus() then offsetY:SetText(tostring(options.offsetY)) end
        advancedButton:SetText(advanced and L("Masquer le décalage du curseur") or L("Décalage du curseur"))
        own:SetChecked(UI.IsOverride("tooltips")); hideCombat:SetChecked(db.hideCombat)
        generalEnabled:SetChecked(db.enabled); generalCursor:SetChecked(db.cursor)
        ApplyMouseoverDistanceSetting()
        UI.StyleFrame(anchor,"tooltips")
        local style=UI.GetStyle("tooltips")
        local previousScale=anchor:GetScale()
        anchor:SetScale(style and style.scale*effective.scale/100 or effective.scale/100)
        if previousScale~=anchor:GetScale() then RestorePosition() end
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
        LayoutSettings()
    end
    panel.OnRefresh=RefreshSettings
    panel.OnDefault=function() db.enabled,db.cursor,db.scale,db.x,db.y=true,false,100,.65,.25; db.contexts={}; NormalizeTooltipOptions(); HideTooltip(); RestorePosition(); RefreshSettings() end
    LayoutSettings=function()
        local width=math.max(320,panel:GetWidth())
        local bodyWidth=width-50
        local wide=bodyWidth>=808
        local columnWidth=wide and (bodyWidth-24)/2 or bodyWidth
        local right=wide and columnWidth+24 or 0
        local columns=math.max(1,math.min(3,math.floor((width-32)/175)))
        local tabWidth=(width-32)/columns
        intro:SetWidth(width-32)
        local tabTop=45+intro:GetStringHeight()+12
        for index,name in ipairs(order) do
            tabs[name]:ClearAllPoints(); tabs[name]:SetPoint("TOPLEFT",16+((index-1)%columns)*tabWidth,-tabTop-math.floor((index-1)/columns)*34)
            tabs[name]:SetWidth(tabWidth-10)
            pages[name]:ClearAllPoints(); pages[name]:SetPoint("TOPLEFT",16,-tabTop-math.ceil(#order/columns)*34); pages[name]:SetPoint("BOTTOMRIGHT",-34,16)
            if bodies[name] then bodies[name]:SetWidth(bodyWidth) end
        end
        local function Place(control,x,y)
            control:ClearAllPoints(); control:SetPoint("TOPLEFT",x,-y)
        end
        for _,check in ipairs({enabled,custom,cursor,own,hideCombat,generalEnabled,generalCursor}) do check.label:SetWidth(columnWidth-36) end
        kindButton:SetWidth(math.min(270,columnWidth))
        Place(kindButton,0,0); Place(custom,0,38)
        local options=Current()
        local canEdit=context=="general" or options.custom==true
        local fixed=canEdit and options.enabled and not options.cursor
        local followsCursor=canEdit and options.enabled and options.cursor
        custom:SetShown(context~="general"); inherited:SetShown(not canEdit)
        enabled:SetShown(canEdit); cursor:SetShown(canEdit and options.enabled)
        positionHelp:SetShown(fixed); place:SetShown(fixed); center:SetShown(fixed)
        advancedButton:SetShown(followsCursor); advancedBody:SetShown(followsCursor and advanced)
        if not (followsCursor and advanced) then offsetX:ClearFocus(); offsetY:ClearFocus() end
        local y=context=="general" and 36 or 72
        if canEdit then
            Place(enabled,0,y); y=y+math.max(32,enabled.label:GetStringHeight()+8)
            if options.enabled then Place(cursor,0,y); y=y+32 end
        else
            inherited:SetWidth(columnWidth-4); Place(inherited,4,y); y=y+inherited:GetStringHeight()+12
        end
        if fixed then
            positionHelp:SetWidth(columnWidth-4); Place(positionHelp,4,y); y=y+positionHelp:GetStringHeight()+10
            Place(place,0,y)
            if columnWidth<352 then y=y+32; Place(center,0,y) else Place(center,182,y) end
            y=y+36
        elseif followsCursor then
            Place(advancedButton,0,y); y=y+34
            if advanced then Place(advancedBody,0,y); advancedBody:SetSize(columnWidth,62); y=y+68 end
        end
        typeDefaults:SetShown(canEdit); Place(typeDefaults,0,y)
        y=y+(canEdit and 42 or 12)
        local placementHeight=y
        if wide then y=0 end
        Place(typeSizeLabel,right,y); Place(typeSize,right+4,y+25); typeSize:SetWidth(columnWidth-8); y=y+64
        Place(hideCombat,right,y); y=y+math.max(36,hideCombat.label:GetStringHeight()+10)
        combatHelp:SetWidth(columnWidth); Place(combatHelp,right,y)
        y=y+combatHelp:GetStringHeight()+14
        Place(visibilityDefaults,right,y); body:SetHeight(math.max(placementHeight,y+42))

        generalCursor:SetShown(db.enabled)
        generalPlace:SetShown(db.enabled and not db.cursor); generalCenter:SetShown(db.enabled and not db.cursor)
        placementHeading:SetShown(wide); appearanceHeading:SetShown(wide)
        Place(placementHeading,0,0); placementHeading:SetWidth(columnWidth)
        Place(appearanceHeading,right,0); appearanceHeading:SetWidth(columnWidth)
        local start=wide and 30 or 0
        local mainY=start+math.max(36,generalEnabled.label:GetStringHeight()+12)
        Place(generalEnabled,0,start); Place(generalCursor,0,mainY)
        if db.enabled then mainY=mainY+math.max(36,generalCursor.label:GetStringHeight()+12) end
        if db.enabled and not db.cursor then
            Place(generalPlace,0,mainY)
            if columnWidth<352 then mainY=mainY+34; Place(generalCenter,0,mainY) else Place(generalCenter,182,mainY) end
            mainY=mainY+42
        end
        local generalHeight=mainY
        if wide then mainY=start end
        Place(own,right,mainY); mainY=mainY+math.max(36,own.label:GetStringHeight()+12)
        Place(sizeLabel,right,mainY); Place(size,right+4,mainY+25)
        size:SetWidth(columnWidth-8); mainY=mainY+64
        Place(preview,right,mainY)
        if columnWidth>=392 then Place(appearanceDefaults,right+172,mainY)
        else mainY=mainY+34; Place(appearanceDefaults,right,mainY) end
        mainY=mainY+38
        if appearanceLink then Place(appearanceLink,right,mainY); mainY=mainY+38 end
        a:SetHeight(math.max(generalHeight,mainY))
        for _,name in ipairs(order) do if bodies[name] then UI.ClampScroll(pages[name],bodies[name]:GetHeight()) end end
    end
    if UI.AddAppearanceLink then appearanceLink=UI.AddAppearanceLink(a,"tooltips",0,0,270) end
    panel:SetScript("OnShow",function() ns.StopAllPreviews(); RefreshSettings() end)
    panel:HookScript("OnSizeChanged",LayoutSettings)
    panel:SetScript("OnHide",ns.StopAllPreviews)
    settingsCategory=ns.UI.RegisterSettingsPanel(root,panel,L("Infobulles et distance"),"tooltips")
    ns.TooltipSettingsHost = {panel=panel, category=settingsCategory, Select=Select}
    function ns.TooltipSettingsHost.AddDistancePage(page)
        pages.distance=page
        table.insert(order,2,"distance")
        tabs.distance=UI.Button(panel,"ArkannsQOLTooltipDistanceTab",L("Distance"),0,0,184,function() Select("distance") end)
        Select(activePage); LayoutSettings()
    end
    function ns.OpenTooltipSettings(source)
        ns.UI.OpenCategory(settingsCategory)
        if not source then RefreshSettings(); return end
        local advancedSources={
            ["Réglages propres à ce type"]=custom,["Types d’infobulle"]=kindButton,
            ["Unités"]=kindButton,["Unités et interactions"]=kindButton,["Objets"]=kindButton,["Sorts"]=kindButton,
            ["Décalage du curseur"]=advancedButton,["Décalage X / Y (0 à 100)"]=offsetX,
            ["Masquer en combat"]=hideCombat,["Garder le placement WoW en combat"]=hideCombat,
        }
        local target=advancedSources[source]
        context=(source=="Unités" or source=="Unités et interactions" or source=="Réglages propres à ce type") and "units" or source=="Objets" and "items" or source=="Sorts" and "spells" or "general"
        if source=="Décalage du curseur" or source=="Décalage X / Y (0 à 100)" then advanced=true end
        Select(target and "behavior" or "appearance"); RefreshSettings()
        if (source=="Décalage du curseur" or source=="Décalage X / Y (0 à 100)") and not Current().cursor then target=cursor end
        if target==cursor and not Current().enabled then target=enabled end
        local mainSources={
            ["Échelle"]=size,["Suivre le curseur"]=generalCursor,["Apparence propre à ce module"]=own,
            ["Position fixe"]=generalPlace,["Déplacer"]=generalPlace,["Recentrer"]=generalCenter,["Aperçu"]=preview,
        }
        target=target or mainSources[source] or generalEnabled
        if (target==generalPlace or target==generalCenter) and db.cursor then target=generalCursor end
        if (target==generalCursor or target==generalPlace or target==generalCenter) and not db.enabled then target=generalEnabled end
        if UI.RevealControl then UI.RevealControl(advancedSources[source] and pages.behavior or pages.appearance,target) end
    end
    ns.RegisterModule("tooltips",{
        label=L("Infobulles et distance"),icon="Interface\\Icons\\INV_Misc_Note_01",frame=anchor,category=function() return settingsCategory end,
        OpenSettings=ns.OpenTooltipSettings,
        SearchSettings={"Personnaliser les infobulles","Suivre le curseur","Échelle","Déplacer","Recentrer","Aperçu",
            "Apparence propre à ce module","Réglages propres à ce type","Unités et interactions","Objets","Sorts",
            "Décalage du curseur","Décalage X / Y (0 à 100)","Garder le placement WoW en combat"},
        IsEnabled=function() return db.enabled end,SetEnabled=function(value) db.enabled=value; HideTooltip(); RefreshSettings() end,
        toggleLabel=L("Personnaliser les infobulles"),
        Summary=function()
            if not db.enabled then return L("Placement WoW") end
            local count=0; for _,options in pairs(db.contexts) do if options.custom then count=count+1 end end
            local placement=db.cursor and L("Suit le curseur") or L("Position fixe • %s %%"):format(db.scale)
            return count>0 and L("%s\nTypes personnalisés : %d"):format(placement,count) or placement
        end,
        Preview=function(forLayout)
            if WoW.ReadValue(InCombatLockdown) ~= false then return false,L("Aperçu disponible hors combat.") end
            tooltipPreview=true; anchor:EnableMouse(false); anchor:SetFrameStrata(forLayout == true and "MEDIUM" or "DIALOG")
            RestorePosition(); RefreshSettings(); anchor:Show(); return true
        end,
        StopPreview=function()
            tooltipPreview=false; anchor:Hide(); label:SetText(L("QoL Toolkit — Infobulles")); help:SetText(L("Position fixe des infobulles."))
            if UI.PreviewEnded then UI.PreviewEnded("tooltips") end
        end,
        Refresh=function() RefreshSettings(); if db.enabled and GameTooltip:IsShown() then PositionTooltip(GameTooltip) end end,
        GetPosition=function()
            local scale=anchor:GetScale(); return db.x+anchor:GetWidth()*scale/(2*UIParent:GetWidth()),db.y+anchor:GetHeight()*scale/(2*UIParent:GetHeight())
        end,
        SetPosition=function(x,y)
            local scale=anchor:GetScale(); db.x=math.max(0,math.min(1,x-anchor:GetWidth()*scale/(2*UIParent:GetWidth()))); db.y=math.max(0,math.min(1,y-anchor:GetHeight()*scale/(2*UIParent:GetHeight())))
            RestorePosition()
        end,
        ExportSettings=function()
            local result={}; for _,key in ipairs({"enabled","cursor","scale","x","y","contexts","offsetX","offsetY","hideCombat"}) do result[key]=UI.Copy(db[key]) end; return result
        end,
        profileMigrations={function() end, function(config) config.mouseoverDistance=nil end},
        ImportSettings=function(value)
            if type(value)~="table" or type(value.enabled)~="boolean" or type(value.cursor)~="boolean" or type(value.scale)~="number" or value.scale~=value.scale or value.scale<50 or value.scale>200 then return false,L("Infobulles invalides.") end
            for _,key in ipairs({"x","y"}) do if type(value[key])~="number" or value[key]~=value[key] or value[key]<0 or value[key]>1 then return false,L("Position invalide.") end end
            if value.mouseoverDistance ~= nil and type(value.mouseoverDistance) ~= "boolean" then return false,L("Infobulles invalides.") end
            for _,key in ipairs({"enabled","cursor","scale","x","y","contexts","offsetX","offsetY","hideCombat"}) do db[key]=UI.Copy(value[key]) end
            if value.mouseoverDistance ~= nil then db.mouseoverDistance=value.mouseoverDistance end
            NormalizeTooltipOptions(); HideTooltip(); RestorePosition(); RefreshSettings(); return true
        end,
    })
    Select("appearance"); RefreshSettings()
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
    CreateModernSettings(root)
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

for _, event in ipairs({"DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if not db then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if db.hideCombat and GameTooltip:IsShown() then PositionTooltip(GameTooltip) end
        UpdateMouseoverDistance()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        UpdateMouseoverDistance()
    else
        RestorePosition()
    end
end)
