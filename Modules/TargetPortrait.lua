local _, ns = ...
local L, UI, WoW = ns.L, ns.UI, ns.WoW
local title = L("Portraits de classe")
local toggleSource = "Activer les portraits de classe"
local Art = ns.TargetPortraitArt
local classTexture = "Interface\\WorldStateFrame\\Icons-Classes"
local circleMask = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local classSlots = Art.classSlots
local events = {"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "CVAR_UPDATE"}
local db, driver, overlay, toggle, refreshSettings, category
local anchoredPortrait, rejectedPortrait, paintedClass
local revision, selectedUnit, previewClass = 0, "target", "MAGE"
local sample, previewActive, settingsPanel, previewButton
local decorations = {target = {}, player = {}}
local defaults = {enabled = true, intensity = "ornate", size = 100, borderSize = 2, gap = 0,
    opacity = 1, glow = .35, animated = false, classColor = true, color = {1, .82, .35}, x = 0, y = 0}
local ranges = {size = {80, 140}, borderSize = {1, 4}, gap = {0, 10}, opacity = {.2, 1},
    glow = {0, 1}, x = {-40, 40}, y = {-40, 40}}

local function Normalize(value)
    value = type(value) == "table" and value or {}
    local result = {}
    for key, fallback in pairs(defaults) do
        local candidate = value[key]
        if ranges[key] then
            local range = ranges[key]
            result[key] = WoW.IsFiniteNumber(candidate) and math.max(range[1], math.min(range[2], candidate)) or fallback
            if key == "borderSize" then result[key] = math.floor(result[key]) end
        elseif key == "color" then
            result.color = {}
            for index = 1, 3 do
                local component = type(candidate) == "table" and candidate[index]
                result.color[index] = WoW.IsFiniteNumber(component) and math.max(0, math.min(1, component)) or fallback[index]
            end
        elseif key == "intensity" then
            result[key] = (candidate == "subtle" or candidate == "ornate" or candidate == "epic") and candidate or fallback
        elseif type(candidate) == "boolean" then
            result[key] = candidate
        else
            result[key] = fallback
        end
    end
    return result
end

local function Resource(texture, resource)
    if C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, resource.atlas) then
        texture:SetAtlas(resource.atlas, false)
        return true
    end
    if texture:SetTexture(resource.texture) then
        texture:SetTexCoord(unpack(resource.coords))
        return true
    end
    return false
end

local function StopDecoration(frame)
    if not frame then return end
    frame:Hide()
    for _, ornament in ipairs(frame.ornaments) do ornament:Hide() end
    frame.pulse:Stop()
    frame.glowHost:SetAlpha(1)
end

local function CreateDecoration(parent, name)
    local frame = CreateFrame("Frame", name, parent)
    frame:Hide()
    frame:EnableMouse(false)
    -- The native portrait is BACKGROUND sublevel 1. Its opaque face covers the crest center.
    -- Native ornamental edges have low alpha; repeated layers make their relief readable.
    frame.ornaments = {}
    for index = 1, 4 do
        local ornament = parent:CreateTexture(nil, "BACKGROUND", nil, 0)
        ornament:Hide()
        frame.ornaments[index] = ornament
    end
    frame.rings = {}
    for index = 1, 4 do
        local ring = frame:CreateTexture(nil, "BORDER")
        ring:SetPoint("CENTER")
        ring:SetDesaturated(true)
        ring.available = Resource(ring, Art.ring)
        frame.rings[index] = ring
    end
    frame.glowHost = CreateFrame("Frame", nil, frame)
    frame.glowHost:SetAllPoints(frame)
    frame.glowHost:EnableMouse(false)
    frame.glow = frame.glowHost:CreateTexture(nil, "ARTWORK")
    frame.glow:SetPoint("CENTER")
    frame.glow:SetDesaturated(true)
    frame.glow.available = Resource(frame.glow, Art.glow)
    if frame.glowHost.CreateMaskTexture and Art.glowMask then
        frame.glowMask = frame.glowHost:CreateMaskTexture()
        local mask = frame.glowMask
        if C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, Art.glowMask.atlas) then
            mask:SetAtlas(Art.glowMask.atlas, false, "LINEAR", true, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        elseif mask:SetTexture(Art.glowMask.texture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
            mask:SetTexCoord(unpack(Art.glowMask.coords))
        else
            frame.glow.available = false
        end
        mask:SetPoint("CENTER")
        frame.glow:AddMaskTexture(mask)
    else
        frame.glow.available = false
    end
    frame.pulse = frame.glowHost:CreateAnimationGroup()
    frame.pulse:SetLooping("REPEAT")
    for index, alphas in ipairs({{.45, 1}, {1, .45}}) do
        local animation = frame.pulse:CreateAnimation("Alpha")
        animation:SetOrder(index)
        animation:SetDuration(1.8)
        animation:SetFromAlpha(alphas[1])
        animation:SetToAlpha(alphas[2])
    end
    frame:SetScript("OnShow", function()
        for index, ornament in ipairs(frame.ornaments) do ornament:SetShown(index <= (frame.ornamentCount or 0)) end
    end)
    frame:SetScript("OnHide", function()
        for _, ornament in ipairs(frame.ornaments) do ornament:Hide() end
        frame.pulse:Stop()
        frame.glowHost:SetAlpha(1)
    end)
    return frame
end

local function LayoutDecoration(frame, config, unit)
    -- Start with a 64-unit inner span for the native 79-unit border; allow visual adjustment.
    local portraitSize = unit == "player" and 60 or 58
    local side = 79 * portraitSize / 64 * config.size / 100 + config.gap * 2
    frame:SetSize(side, side)
    frame:SetAlpha(config.opacity)
    for index, ring in ipairs(frame.rings) do
        ring:SetSize(side + (index - 1) * 1.2, side + (index - 1) * 1.2)
        ring:SetShown(ring.available and index <= config.borderSize)
    end
    frame.glow:SetSize(side, side)
    if frame.glowMask then frame.glowMask:SetSize(side * 121 / 79, side * 121 / 79) end
    frame.glow:SetAlpha(config.glow)
    frame.glow:SetShown(frame.glow.available and config.glow > 0)
    local ornamentSize = side * (config.intensity == "epic" and 1.5 or 1.32)
    for _, ornament in ipairs(frame.ornaments) do
        ornament:ClearAllPoints()
        ornament:SetPoint("CENTER", frame, "CENTER")
        ornament:SetSize(ornamentSize, ornamentSize)
        ornament:SetAlpha(config.opacity)
    end
    frame.config, frame.paintedClass = Normalize(config), nil
end

local function PaintDecoration(frame, class)
    local config, artwork = frame.config, Art.classes[class]
    if not config or not artwork or not frame.rings[1].available then return false end
    if frame.paintedClass ~= class then
        local color = config.color
        if config.classColor then
            local native = C_ClassColor and WoW.ReadValue(C_ClassColor.GetClassColor, class)
            if type(native) ~= "table" or not WoW.IsFiniteNumber(native.r)
                or not WoW.IsFiniteNumber(native.g) or not WoW.IsFiniteNumber(native.b) then return false end
            color = {native.r, native.g, native.b}
        end
        for _, ring in ipairs(frame.rings) do ring:SetVertexColor(unpack(color)) end
        frame.glow:SetVertexColor(unpack(color))
        frame.ornamentCount = config.intensity == "subtle" and 0 or config.intensity == "epic" and 4 or 3
        for _, ornament in ipairs(frame.ornaments) do
            if not Resource(ornament, artwork.rune) then frame.ornamentCount = 0 end
            ornament:SetDesaturated(not config.classColor)
            if config.classColor then ornament:SetVertexColor(1, 1, 1) else ornament:SetVertexColor(unpack(color)) end
        end
        frame.paintedClass = class
    end
    for index, ornament in ipairs(frame.ornaments) do ornament:SetShown(index <= frame.ornamentCount) end
    if config.animated and config.glow > 0 and frame.glow.available then
        if not frame.pulse:IsPlaying() then frame.pulse:Play() end
    else
        frame.pulse:Stop()
        frame.glowHost:SetAlpha(1)
    end
    return true
end

local function RefreshDecoration(unit)
    local state, config = decorations[unit], db[unit]
    local owner = _G[unit == "player" and "PlayerFrame" or "TargetFrame"]
    if not db.enabled or not config.enabled or not WoW.IsPublic(owner) or not owner
        or WoW.ReadValue(owner.IsForbidden, owner) ~= false or WoW.ReadValue(UnitIsPlayer, unit) ~= true then
        StopDecoration(state.frame)
        return
    end
    local container = owner[unit == "player" and "PlayerFrameContainer" or "TargetFrameContainer"]
    if not WoW.IsPublic(container) or not container then StopDecoration(state.frame); return end
    local portrait = container[unit == "player" and "PlayerPortrait" or "Portrait"]
    if not WoW.IsPublic(portrait) or not portrait or WoW.ReadValue(portrait.IsShown, portrait) ~= true
        or (portrait.IsAnchoringSecret and WoW.ReadValue(portrait.IsAnchoringSecret, portrait) ~= false) then
        StopDecoration(state.frame)
        return
    end
    local class = WoW.ReadValue(UnitClassBase, unit)
    if type(class) ~= "string" or not Art.classes[class] then StopDecoration(state.frame); return end
    if WoW.ReadValue(InCombatLockdown) == false then
        local level = WoW.ReadValue(container.GetFrameLevel, container)
        if not WoW.IsFiniteNumber(level) or state.rejected == portrait then StopDecoration(state.frame); return end
        if not state.frame then
            state.frame = CreateDecoration(container, "ArkannsQOLClassPortrait" .. (unit == "player" and "Player" or "Target"))
        end
        if state.portrait ~= portrait or state.revision ~= revision then
            StopDecoration(state.frame)
            state.frame:SetParent(container)
            state.frame:SetFrameLevel(level + 1)
            state.frame:ClearAllPoints()
            state.portrait, state.revision = nil, nil
            if not pcall(state.frame.SetPoint, state.frame, "CENTER", portrait, "CENTER", config.x, config.y) then
                state.rejected = portrait
                return
            end
            LayoutDecoration(state.frame, config, unit)
            state.portrait, state.revision = portrait, revision
        end
    end
    if not state.frame or state.portrait ~= portrait then StopDecoration(state.frame); return end
    if PaintDecoration(state.frame, class) then state.frame:Show() else StopDecoration(state.frame) end
end

local function MaskCircle(frame, texture, size)
    local mask = frame:CreateMaskTexture()
    -- Same circular mask as Forever's target portrait (FrameXML 9dc84f0).
    if C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, "CircleMask") then
        mask:SetAtlas("CircleMask", false, "LINEAR", true, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    elseif not mask:SetTexture(circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
        return false
    end
    mask:SetPoint("CENTER", frame, "CENTER")
    mask:SetSize(size, size)
    texture:SetPoint("CENTER", frame, "CENTER")
    texture:SetSize(size, size)
    texture:AddMaskTexture(mask)
    return mask
end

local function AnchorOverlay(container, portrait)
    if portrait == rejectedPortrait then return end
    if overlay and anchoredPortrait == portrait then return overlay end
    local state, locked = WoW.Read(InCombatLockdown)
    if state ~= "ok" or locked then return end
    if portrait.IsAnchoringSecret and WoW.ReadValue(portrait.IsAnchoringSecret, portrait) ~= false then return end
    local level = WoW.ReadValue(container.GetFrameLevel, container)
    if not WoW.IsFiniteNumber(level) then return end
    if not overlay then
        overlay = CreateFrame("Frame", nil, container)
        overlay:Hide()
        overlay:EnableMouse(false)
        overlay:SetSize(28, 28)
        if overlay.CreateMaskTexture then
            local outline = overlay:CreateTexture(nil, "BACKGROUND")
            outline:SetColorTexture(.025, .02, .015, .95)
            local rim = overlay:CreateTexture(nil, "BORDER")
            rim:SetColorTexture(1, 1, 1, 1)
            rim:SetGradient("VERTICAL", CreateColor(.38, .38, .38, 1), CreateColor(1, 1, 1, 1))
            local background = overlay:CreateTexture(nil, "ARTWORK")
            background:SetColorTexture(.055, .045, .035, 1)
            background:SetGradient("VERTICAL", CreateColor(.45, .45, .45, 1), CreateColor(1, 1, 1, 1))
            local icon = overlay:CreateTexture(nil, "OVERLAY")
            if MaskCircle(overlay, outline, 28) and MaskCircle(overlay, rim, 26)
                and MaskCircle(overlay, background, 23) and MaskCircle(overlay, icon, 20)
                and icon:SetTexture(classTexture) then
                overlay.rim, overlay.icon = rim, icon
            end
        end
    end
    overlay:SetParent(container)
    overlay:SetFrameLevel(level + 1)
    overlay:ClearAllPoints()
    anchoredPortrait = nil
    -- Sit on the upper-right rim, clear of the central raid marker and lower PvP/level badges.
    if not pcall(overlay.SetPoint, overlay, "CENTER", portrait, "CENTER", 25, 24) then
        rejectedPortrait = portrait
        return
    end
    anchoredPortrait = portrait
    return overlay
end

local function IsClassPortrait(portrait)
    local atlas = WoW.ReadValue(portrait.GetAtlas, portrait)
    if type(atlas) == "string" and atlas:lower():match("^classicon%-") then return true end
    local isSelf = WoW.ReadValue(UnitIsUnit, "target", "player")
    if type(isSelf) ~= "boolean" then return false end
    local cvar = isSelf and "ReplaceMyPlayerPortrait" or "ReplaceOtherPlayerPortraits"
    return C_CVar and WoW.ReadValue(C_CVar.GetCVarBool, cvar) == true
end

local function RefreshMedallion()
    if overlay then overlay:Hide() end
    if not db.enabled or not db.medallion then return end
    local target = TargetFrame
    if not WoW.IsPublic(target) or not target or WoW.ReadValue(target.IsForbidden, target) ~= false then return end
    local container = target.TargetFrameContainer
    if not WoW.IsPublic(container) or not container then return end
    local portrait = container.Portrait
    if not WoW.IsPublic(portrait) or not portrait then return end
    local frame = AnchorOverlay(container, portrait)
    if not frame or not frame.icon then return end
    if WoW.ReadValue(portrait.IsShown, portrait) ~= true or WoW.ReadValue(UnitIsPlayer, "target") ~= true then return end
    if IsClassPortrait(portrait) then return end

    local class = WoW.ReadValue(UnitClassBase, "target")
    local slot = type(class) == "string" and classSlots[class]
    if not slot then return end
    if paintedClass ~= class then
        local color = C_ClassColor and WoW.ReadValue(C_ClassColor.GetClassColor, class)
        if type(color) ~= "table" or not WoW.IsFiniteNumber(color.r) or not WoW.IsFiniteNumber(color.g)
            or not WoW.IsFiniteNumber(color.b) then return end
        frame.rim:SetVertexColor(.18 + .82 * color.r, .18 + .82 * color.g, .18 + .82 * color.b)
        local x, y = (slot % 4) / 4, math.floor(slot / 4) / 4
        local inset = .5 / 256
        frame.icon:SetTexCoord(x + inset, x + .25 - inset, y + inset, y + .25 - inset)
        paintedClass = class
    end
    frame:Show()
end

local function Refresh()
    RefreshMedallion()
    RefreshDecoration("target")
    RefreshDecoration("player")
end

local function StopPreview()
    previewActive = false
    StopDecoration(sample)
    if sample and sample.face then sample.face:Hide() end
    if previewButton then previewButton:Show() end
    if UI.PreviewEnded then UI.PreviewEnded("targetPortrait") end
end

local function RefreshPreview()
    if not previewActive or not settingsPanel:IsShown() or WoW.ReadValue(InCombatLockdown) ~= false then
        StopPreview()
        return
    end
    if not sample then
        sample = CreateDecoration(settingsPanel.previewHost, "ArkannsQOLClassPortraitPreview")
        sample.face = settingsPanel.previewHost:CreateTexture(nil, "BACKGROUND", nil, 1)
        sample.faceMask = sample.face:SetTexture(classTexture) and settingsPanel.previewHost.CreateMaskTexture
            and MaskCircle(settingsPanel.previewHost, sample.face, 58)
    end
    if not sample.faceMask then StopPreview(); return end
    LayoutDecoration(sample, db[selectedUnit], selectedUnit)
    sample:ClearAllPoints()
    sample:SetPoint("CENTER", settingsPanel.previewHost, "CENTER", db[selectedUnit].x, db[selectedUnit].y)
    if WoW.ReadValue(UnitExists, "player") == true and WoW.Read(SetPortraitTexture, sample.face, "player", true) == "ok" then
        sample.face:SetTexCoord(0, 1, 0, 1)
    else
        sample.face:SetTexture(classTexture)
        local slot = Art.classSlots[previewClass]
        local x, y = (slot % 4) / 4, math.floor(slot / 4) / 4
        sample.face:SetTexCoord(x + .5 / 256, x + .25 - .5 / 256, y + .5 / 256, y + .25 - .5 / 256)
    end
    local portraitSize = selectedUnit == "player" and 60 or 58
    sample.face:SetSize(portraitSize, portraitSize)
    sample.faceMask:SetSize(portraitSize, portraitSize)
    if PaintDecoration(sample, previewClass) then
        sample.face:Show()
        sample:Show()
    else
        StopDecoration(sample)
        sample.face:Hide()
    end
end

local function Changed()
    revision = revision + 1
    Refresh()
    if refreshSettings then refreshSettings() end
end

local function SetEnabled(enabled)
    local changed = db.enabled ~= enabled
    db.enabled = enabled
    if toggle then toggle:SetChecked(enabled) end
    if enabled and (changed or not driver:IsEventRegistered("PLAYER_TARGET_CHANGED")) then
        for _, event in ipairs(events) do driver:RegisterEvent(event) end
        driver:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "target", "player")
    elseif not enabled then
        driver:UnregisterAllEvents()
        StopPreview()
    end
    Refresh()
    if refreshSettings then refreshSettings() end
end

function ns.InitializeTargetPortrait(root)
    if db then return end
    if type(ForeverTooltipLibreDB.targetPortrait) ~= "table" then ForeverTooltipLibreDB.targetPortrait = {} end
    db = ForeverTooltipLibreDB.targetPortrait
    db.target, db.player = Normalize(db.target), Normalize(db.player)
    if type(db.medallion) ~= "boolean" then db.medallion = false end
    driver = CreateFrame("Frame")
    driver:SetScript("OnEvent", function(_, event, name)
        if event == "CVAR_UPDATE" then
            if not WoW.IsPublic(name) or type(name) ~= "string" then return end
            name = name:lower()
            if name ~= "replaceotherplayerportraits" and name ~= "replacemyplayerportrait" then return end
        elseif event == "PLAYER_ENTERING_WORLD" then
            rejectedPortrait = nil
            for _, state in pairs(decorations) do state.rejected, state.revision = nil, nil end
        elseif event == "PLAYER_REGEN_DISABLED" then
            StopPreview()
        end
        Refresh()
        if refreshSettings then refreshSettings() end
    end)

    local panel = CreateFrame("Frame", "ArkannsQOLTargetPortraitSettings", UIParent, "BackdropTemplate")
    panel:Hide()
    settingsPanel = panel
    UI.StylePanel(panel)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -16)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(500, 1)
    scroll:SetScrollChild(body)
    local rows, updates, targets = {}, {}, {}
    local activeSection, syncing, Layout = "style", false
    local function Track(control, kind, source)
        rows[#rows + 1] = {frame = control, kind = kind, source = source}
        if source then targets[source] = control end
        return control
    end
    local function Button(name, source, action)
        return Track(UI.Button(body, "ArkannsQOLTargetPortrait" .. name, L(source), 0, 0, 330, action), "button", source)
    end
    local function Check(name, source, getter, setter)
        local control = Track(UI.Check(body, "ArkannsQOLTargetPortrait" .. name, L(source), 0, 0, function(value)
            setter(value)
            Changed()
        end), "check", source)
        updates[#updates + 1] = function() control:SetChecked(getter()) end
        return control
    end
    local function Choice(name, source, values, getter, setter)
        local control = Button(name, source, function(self)
            if not MenuUtil or not MenuUtil.CreateContextMenu then return end
            MenuUtil.CreateContextMenu(self, function(_, menu)
                for _, item in ipairs(values) do
                    local value = item[1]
                    menu:CreateButton(L(item[2]), function() setter(value); Changed() end)
                end
            end)
        end)
        updates[#updates + 1] = function()
            for _, item in ipairs(values) do
                if getter() == item[1] then
                    control:SetText(L("%s : %s"):format(L(name == "Intensity" and "Ornements" or source), L(item[2])))
                end
            end
        end
        return control
    end
    local function Slider(key, source, minimum, maximum, factor)
        local short = ({size = "Taille (%)", borderSize = "Épaisseur", gap = "Écart du cadre",
            opacity = "Opacité (%)", glow = "Halo (%)", x = "Horizontal", y = "Vertical"})[key]
        local caption = UI.Label(body, "", 0, 0)
        local control = Track(CreateFrame("Slider", "ArkannsQOLTargetPortrait" .. key:sub(1, 1):upper() .. key:sub(2), body, "BackdropTemplate"), "slider", source)
        rows[#rows].caption = caption
        control:SetSize(330, 18)
        control:SetOrientation("HORIZONTAL")
        control:SetMinMaxValues(minimum, maximum)
        control:SetValueStep(1)
        control:SetObeyStepOnDrag(true)
        control:SetBackdrop({bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", edgeSize = 8})
        control:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        control:GetThumbTexture():SetSize(28, 28)
        control:SetScript("OnValueChanged", function(_, value)
            if syncing or not WoW.IsFiniteNumber(value) then return end
            db[selectedUnit][key] = math.max(minimum, math.min(maximum, math.floor(value + .5))) / (factor or 1)
            Changed()
        end)
        updates[#updates + 1] = function()
            local value = math.floor(db[selectedUnit][key] * (factor or 1) + .5)
            control:SetValue(value)
            caption:SetText(L("%s : %s"):format(L(short), tostring(value)))
        end
    end
    toggle = Track(UI.Check(body, "ArkannsQOLTargetPortraitEnabled", L(toggleSource), 0, 0, SetEnabled), "check", toggleSource)
    updates[#updates + 1] = function() toggle:SetChecked(db.enabled) end
    local unitChoice = Choice("Unit", "Portrait à personnaliser", {{"target", "Cible"}, {"player", "Joueur"}},
        function() return selectedUnit end, function(value) selectedUnit = value end)
    local unitEnabled = Check("UnitEnabled", "Afficher le cadre de ce portrait", function() return db[selectedUnit].enabled end,
        function(value) db[selectedUnit].enabled = value end)
    Choice("Intensity", "Intensité des ornements", {{"subtle", "Sobre"}, {"ornate", "Ornée"}, {"epic", "Spectaculaire"}},
        function() return db[selectedUnit].intensity end, function(value) db[selectedUnit].intensity = value end)
    local classes = {}
    for _, class in ipairs(Art.order) do classes[#classes + 1] = {class, Art.classes[class].label} end
    local previewChoice = Choice("PreviewClass", "Classe de l’aperçu", classes, function() return previewClass end, function(value) previewClass = value end)
    previewButton = Button("Preview", "Afficher l’aperçu", function()
        previewActive = true
        RefreshPreview()
        Layout()
    end)
    panel.previewHost = CreateFrame("Frame", nil, panel)
    panel.previewHost:SetSize(250, 250)
    local pending = Track(UI.Label(body, L("Les changements du cadre s’appliquent après le combat."), 0, 0), "text")
    Slider("size", "Taille du cadre (%)", 80, 140)
    Slider("borderSize", "Épaisseur de bordure", 1, 4)
    Slider("gap", "Distance autour du portrait", 0, 10)
    Slider("opacity", "Opacité (%)", 20, 100, 100)
    Slider("glow", "Intensité du halo (%)", 0, 100, 100)
    Slider("x", "Décalage horizontal", -40, 40)
    Slider("y", "Décalage vertical", -40, 40)
    Check("ClassColor", "Utiliser la couleur de classe", function() return db[selectedUnit].classColor end,
        function(value) db[selectedUnit].classColor = value end)
    local colorButton = Button("Color", "Couleur personnalisée", function()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local unit, config = selectedUnit, db[selectedUnit]
        local old = {unpack(config.color)}
        ColorPickerFrame:SetupColorPickerAndShow({r = old[1], g = old[2], b = old[3], hasOpacity = false,
            swatchFunc = function()
                if db[unit] ~= config then return end
                config.color = Normalize({color = {ColorPickerFrame:GetColorRGB()}}).color
                Changed()
            end,
            cancelFunc = function()
                if db[unit] ~= config then return end
                config.color = old
                Changed()
            end,
        })
    end)
    local swatch = colorButton:CreateTexture(nil, "OVERLAY")
    swatch:SetSize(18, 12)
    swatch:SetPoint("RIGHT", -8, 0)
    updates[#updates + 1] = function()
        colorButton:SetEnabled(not db[selectedUnit].classColor and ColorPickerFrame and type(ColorPickerFrame.SetupColorPickerAndShow) == "function" or false)
        swatch:SetColorTexture(unpack(db[selectedUnit].color))
    end
    Check("Animated", "Animer le halo", function() return db[selectedUnit].animated end,
        function(value) db[selectedUnit].animated = value end)
    local medallion = Check("Medallion", "Afficher le médaillon de classe", function() return db.medallion end,
        function(value) db.medallion = value end)
    local medallionHelp = Track(UI.Label(body, L("Le médaillon supplémentaire concerne uniquement la cible."), 0, 0), "text")
    local reset = Button("Reset", "Réinitialiser ce portrait", function()
        local unit, config = selectedUnit, db[selectedUnit]
        UI.Confirm(L("Rétablir l’apparence par défaut de ce portrait ?"), function()
            if db[unit] ~= config then return end
            db[unit] = Normalize()
            Changed()
        end)
    end)
    local sectionButtons = {}
    for _, entry in ipairs({{"style", "Style", "Style"}, {"placement", "Placement", "Advanced"}, {"effects", "Effets", "Effects"}}) do
        local id = entry[1]
        sectionButtons[id] = UI.Button(panel, "ArkannsQOLTargetPortrait" .. entry[3], L(entry[2]), 0, 0, 100, function()
            activeSection = id
            scroll:SetVerticalScroll(0)
            Layout()
        end)
    end
    targets["Personnalisation avancée"] = sectionButtons.placement
    local pinned = {[toggle] = true, [unitChoice] = true, [unitEnabled] = true, [previewChoice] = true,
        [previewButton] = true, [pending] = true, [reset] = true}
    for control in pairs(pinned) do control:SetParent(panel) end
    local sourceSections = {
        ["Intensité des ornements"] = "style", ["Épaisseur de bordure"] = "style",
        ["Utiliser la couleur de classe"] = "style", ["Couleur personnalisée"] = "style",
        ["Taille du cadre (%)"] = "placement", ["Distance autour du portrait"] = "placement",
        ["Décalage horizontal"] = "placement", ["Décalage vertical"] = "placement",
        ["Opacité (%)"] = "effects", ["Intensité du halo (%)"] = "effects", ["Animer le halo"] = "effects",
        ["Afficher le médaillon de classe"] = "effects",
    }
    Layout = function()
        local width = math.max(250, panel:GetWidth() - 32)
        local height = panel:GetHeight()
        local paired = width >= 500
        local previewWidth = paired and 204 or 122
        local controlWidth = paired and width - previewWidth - 24 or width - 18
        local top = paired and 50 or 182
        local function Place(control, x, y, w)
            control:ClearAllPoints()
            control:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
            if w then control:SetWidth(w) end
        end
        Place(toggle, 16, 12)
        toggle.label:SetText(L("Activer"))
        toggle.label:SetWidth(80)
        Place(unitChoice, paired and 104 or 16, paired and 12 or 48, paired and 96 or math.max(120, width - previewWidth - 16))
        unitChoice:SetText(selectedUnit == "player" and L("Joueur") or L("Cible"))
        Place(unitEnabled, paired and 208 or 16, paired and 12 or 106)
        unitEnabled.label:SetText(L("Afficher"))
        unitEnabled.label:SetWidth(paired and 72 or width - 38)
        local tabWidth = (controlWidth - 12) / 3
        for index, id in ipairs({"style", "placement", "effects"}) do
            local button = sectionButtons[id]
            Place(button, 16 + (index - 1) * (tabWidth + 6), top, tabWidth)
            button:SetEnabled(activeSection ~= id)
        end
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -top - 38)
        scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", paired and -previewWidth - 40 or -34, 54)
        local previewX = width - previewWidth + 16
        local previewTop = 10
        local previewScale = previewWidth / 250
        Place(previewChoice, previewX, previewTop, previewWidth)
        previewChoice:SetText(L(Art.classes[previewClass].label))
        panel.previewHost:ClearAllPoints()
        panel.previewHost:SetPoint("TOPLEFT", panel, "TOPLEFT", previewX / previewScale, -(previewTop + 34) / previewScale)
        panel.previewHost:SetScale(previewScale)
        Place(previewButton, previewX, previewTop + previewWidth + 40, previewWidth)
        previewButton:SetShown(not previewActive)
        Place(reset, 16, math.max(top + 40, height - 40), math.min(controlWidth, 250))
        pending:SetShown(WoW.ReadValue(InCombatLockdown) ~= false)
        Place(pending, paired and previewX or 16, paired and previewTop + previewWidth + 80 or height - 80, paired and previewWidth or controlWidth)
        local visibleRows = {}
        for _, row in ipairs(rows) do
            local control = row.frame
            local section = sourceSections[row.source] or "effects"
            local visible = not pinned[control] and section == activeSection
            if control == colorButton and db[selectedUnit].classColor then visible = false end
            if (control == medallion or control == medallionHelp) and selectedUnit ~= "target" then visible = false end
            if not pinned[control] then control:SetShown(visible) end
            if row.caption then row.caption:SetShown(visible) end
            if visible then visibleRows[#visibleRows + 1] = row end
        end
        local function PlaceRow(row, x, y, space)
            local control = row.frame
            control:ClearAllPoints()
            if row.kind == "slider" then
                row.caption:ClearAllPoints()
                row.caption:SetPoint("TOPLEFT", body, "TOPLEFT", x + 4, -y)
                row.caption:SetWidth(space - 8)
                local captionHeight = math.max(20, row.caption:GetStringHeight())
                control:SetWidth(space - 8)
                control:SetPoint("TOPLEFT", body, "TOPLEFT", x + 4, -y - captionHeight)
                return captionHeight + 24
            end
            control:SetPoint("TOPLEFT", body, "TOPLEFT", x, -y)
            if row.kind == "check" then
                control.label:SetWidth(space - 38)
                return math.max(28, control.label:GetStringHeight() + 8)
            end
            control:SetWidth(space)
            if row.kind == "text" then return math.max(20, control:GetStringHeight()) end
            local text = control:GetFontString()
            text:SetWidth(space - 24)
            text:SetWordWrap(true)
            control:SetHeight(math.max(26, text:GetStringHeight() + 10))
            return control:GetHeight()
        end
        local y, index = 0, 1
        while index <= #visibleRows do
            local row, nextRow = visibleRows[index], visibleRows[index + 1]
            local beside = controlWidth >= 260 and row.kind == "slider" and nextRow and nextRow.kind == "slider"
            if beside then
                local column = (controlWidth - 16) / 2
                local leftHeight = PlaceRow(row, 0, y, column)
                local rightHeight = PlaceRow(nextRow, column + 16, y, column)
                y = y + math.max(leftHeight, rightHeight) + 8
                index = index + 2
            else
                y = y + PlaceRow(row, 0, y, controlWidth) + 8
                index = index + 1
            end
        end
        body:SetSize(controlWidth, y + 6)
        UI.ClampScroll(scroll, body:GetHeight())
        if scroll.ScrollBar then scroll.ScrollBar:SetShown(body:GetHeight() > scroll:GetHeight() + 1) end
    end
    refreshSettings = function()
        syncing = true
        for _, update in ipairs(updates) do update() end
        syncing = false
        Layout()
        RefreshPreview()
    end
    panel:SetScript("OnShow", function()
        previewActive = WoW.ReadValue(InCombatLockdown) == false
        refreshSettings()
    end)
    panel:SetScript("OnHide", StopPreview)
    panel:HookScript("OnSizeChanged", Layout)
    category = UI.RegisterSettingsPanel(root, panel, title, "targetPortrait")
    ns.RegisterModule("targetPortrait", {
        label = title, icon = "Interface\\Icons\\Achievement_Character_Human_Male",
        category = function() return category end,
        SearchSettings = {toggleSource, "Portrait à personnaliser", "Afficher le cadre de ce portrait", "Intensité des ornements",
            "Classe de l’aperçu", "Personnalisation avancée", "Taille du cadre (%)", "Épaisseur de bordure", "Distance autour du portrait",
            "Opacité (%)", "Intensité du halo (%)", "Décalage horizontal", "Décalage vertical", "Utiliser la couleur de classe",
            "Couleur personnalisée", "Animer le halo", "Afficher le médaillon de classe", "Réinitialiser ce portrait"},
        toggleLabel = L(toggleSource),
        Summary = function() return L("Cadres de classe du joueur et de la cible.") end,
        IsEnabled = function() return db.enabled end,
        SetEnabled = SetEnabled,
        Preview = function()
            if WoW.ReadValue(InCombatLockdown) ~= false then return false, L("Aperçu disponible hors combat.") end
            UI.OpenCategory(category)
            previewActive = true
            refreshSettings()
            return sample and sample:IsShown() == true
        end,
        StopPreview = StopPreview,
        OpenSettings = function(source)
            local target = targets[source]
            if source == "Afficher le médaillon de classe" then selectedUnit = "target" end
            if target == colorButton and db[selectedUnit].classColor then target = targets["Utiliser la couleur de classe"] end
            activeSection = sourceSections[source] or (source == "Personnalisation avancée" and "placement") or activeSection
            refreshSettings()
            if target and not pinned[target] and sourceSections[source] and UI.RevealControl then UI.RevealControl(scroll, target) end
        end,
        ExportSettings = function()
            return {enabled = db.enabled, medallion = db.medallion, target = Normalize(db.target), player = Normalize(db.player)}
        end,
        profileMigrations = {function(config, current)
            config.medallion, config.target, config.player = current.medallion, current.target, current.player
        end},
        ImportSettings = function(config)
            if type(config) ~= "table" or type(config.enabled) ~= "boolean" then return false end
            if config.medallion ~= nil and type(config.medallion) ~= "boolean" then return false end
            if config.target ~= nil and type(config.target) ~= "table" then return false end
            if config.player ~= nil and type(config.player) ~= "table" then return false end
            if config.medallion ~= nil then db.medallion = config.medallion end
            if config.target then db.target = Normalize(config.target) end
            if config.player then db.player = Normalize(config.player) end
            revision = revision + 1
            SetEnabled(config.enabled)
            return true
        end,
    })
    SetEnabled(db.enabled ~= false)
end
