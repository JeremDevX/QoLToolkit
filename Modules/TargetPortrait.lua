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
local sample, previewActive, settingsPanel
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
    frame.pulse:Stop()
    frame.glowHost:SetAlpha(1)
end

local function CreateDecoration(parent, name)
    local frame = CreateFrame("Frame", name, parent)
    frame:Hide()
    frame:EnableMouse(false)
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
    frame.crest = frame:CreateTexture(nil, "OVERLAY")
    frame.runes = {frame:CreateTexture(nil, "ARTWORK"), frame:CreateTexture(nil, "ARTWORK")}
    frame:SetScript("OnHide", function()
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
    local radius = side / 2
    local outward = unit == "player" and -1 or 1
    frame.crest:ClearAllPoints()
    frame.crest:SetPoint("CENTER", frame, "CENTER", 0, radius + 5)
    frame.crest:SetSize(24, 24)
    for index, rune in ipairs(frame.runes) do
        rune:ClearAllPoints()
        local x = index == 1 and outward * (radius + 5) or -outward * radius * .7
        local y = index == 1 and 16 or radius * .8 + 8
        rune:SetPoint("CENTER", frame, "CENTER", x, y)
        rune:SetSize(config.intensity == "epic" and 22 or 16, config.intensity == "epic" and 22 or 16)
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
        frame.crest:SetShown(config.intensity ~= "subtle" and Resource(frame.crest, artwork.emblem))
        for index, rune in ipairs(frame.runes) do
            rune:SetShown(config.intensity ~= "subtle" and (index == 1 or config.intensity == "epic") and Resource(rune, artwork.rune))
        end
        for _, ornament in ipairs({frame.crest, frame.runes[1], frame.runes[2]}) do
            ornament:SetDesaturated(not config.classColor)
            if config.classColor then ornament:SetVertexColor(1, 1, 1) else ornament:SetVertexColor(unpack(color)) end
        end
        frame.paintedClass = class
    end
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
    if UI.PreviewEnded then UI.PreviewEnded("targetPortrait") end
end

local function RefreshPreview()
    if not previewActive or not settingsPanel:IsShown() or WoW.ReadValue(InCombatLockdown) ~= false then
        StopPreview()
        return
    end
    if not sample then
        sample = CreateDecoration(settingsPanel.previewHost, "ArkannsQOLClassPortraitPreview")
        sample.face = settingsPanel.previewHost:CreateTexture(nil, "BACKGROUND")
        sample.faceMask = sample.face:SetTexture(classTexture) and settingsPanel.previewHost.CreateMaskTexture
            and MaskCircle(settingsPanel.previewHost, sample.face, 58)
    end
    if not sample.faceMask then StopPreview(); return end
    LayoutDecoration(sample, db[selectedUnit], selectedUnit)
    sample:ClearAllPoints()
    sample:SetPoint("CENTER", settingsPanel.previewHost, "CENTER", db[selectedUnit].x, db[selectedUnit].y)
    local slot = Art.classSlots[previewClass]
    local x, y = (slot % 4) / 4, math.floor(slot / 4) / 4
    sample.face:SetTexCoord(x + .5 / 256, x + .25 - .5 / 256, y + .5 / 256, y + .25 - .5 / 256)
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
    local advanced, syncing, Layout = false, false
    local function Track(control, kind, source, isAdvanced)
        rows[#rows + 1] = {frame = control, kind = kind, advanced = isAdvanced}
        if source then targets[source] = control end
        return control
    end
    local function Text(source, size)
        return Track(UI.Label(body, L(source), 0, 0, size), "text")
    end
    local function Button(name, source, action, isAdvanced)
        return Track(UI.Button(body, "ArkannsQOLTargetPortrait" .. name, L(source), 0, 0, 330, action), "button", source, isAdvanced)
    end
    local function Check(name, source, getter, setter, isAdvanced)
        local control = Track(UI.Check(body, "ArkannsQOLTargetPortrait" .. name, L(source), 0, 0, function(value)
            setter(value)
            Changed()
        end), "check", source, isAdvanced)
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
                if getter() == item[1] then control:SetText(L("%s : %s"):format(L(source), L(item[2]))) end
            end
        end
        return control
    end
    local function Slider(key, source, minimum, maximum, factor)
        local caption = UI.Label(body, "", 0, 0)
        local control = Track(CreateFrame("Slider", "ArkannsQOLTargetPortrait" .. key:sub(1, 1):upper() .. key:sub(2), body, "BackdropTemplate"), "slider", source, true)
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
            caption:SetText(L("%s : %s"):format(L(source), tostring(value)))
        end
    end
    Text("Portraits de classe", 18)
    toggle = Track(UI.Check(body, "ArkannsQOLTargetPortraitEnabled", L(toggleSource), 0, 0, SetEnabled), "check", toggleSource)
    updates[#updates + 1] = function() toggle:SetChecked(db.enabled) end
    Choice("Unit", "Portrait à personnaliser", {{"target", "Cible"}, {"player", "Joueur"}},
        function() return selectedUnit end, function(value) selectedUnit = value end)
    Check("UnitEnabled", "Afficher le cadre de ce portrait", function() return db[selectedUnit].enabled end,
        function(value) db[selectedUnit].enabled = value end)
    Choice("Intensity", "Intensité des ornements", {{"subtle", "Sobre"}, {"ornate", "Ornée"}, {"epic", "Spectaculaire"}},
        function() return db[selectedUnit].intensity end, function(value) db[selectedUnit].intensity = value end)
    local classes = {}
    for _, class in ipairs(Art.order) do classes[#classes + 1] = {class, Art.classes[class].label} end
    Choice("PreviewClass", "Classe de l’aperçu", classes, function() return previewClass end, function(value) previewClass = value end)
    Button("Preview", "Afficher l’aperçu", function() UI.PreviewModule("targetPortrait") end)
    panel.previewHost = Track(CreateFrame("Frame", nil, body), "preview")
    panel.previewHost:SetSize(250, 250)
    Text("Les changements du cadre s’appliquent après le combat.")
    rows[#rows].combat = true
    local advancedButton = Button("Advanced", "Personnalisation avancée", function()
        advanced = not advanced
        Layout()
    end)
    Slider("size", "Taille du cadre (%)", 80, 140)
    Slider("borderSize", "Épaisseur de bordure", 1, 4)
    Slider("gap", "Distance autour du portrait", 0, 10)
    Slider("opacity", "Opacité (%)", 20, 100, 100)
    Slider("glow", "Intensité du halo (%)", 0, 100, 100)
    Slider("x", "Décalage horizontal", -40, 40)
    Slider("y", "Décalage vertical", -40, 40)
    Check("ClassColor", "Utiliser la couleur de classe", function() return db[selectedUnit].classColor end,
        function(value) db[selectedUnit].classColor = value end, true)
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
    end, true)
    local swatch = colorButton:CreateTexture(nil, "OVERLAY")
    swatch:SetSize(18, 12)
    swatch:SetPoint("RIGHT", -8, 0)
    updates[#updates + 1] = function()
        colorButton:SetEnabled(not db[selectedUnit].classColor and ColorPickerFrame and type(ColorPickerFrame.SetupColorPickerAndShow) == "function" or false)
        swatch:SetColorTexture(unpack(db[selectedUnit].color))
    end
    Check("Animated", "Animer le halo", function() return db[selectedUnit].animated end,
        function(value) db[selectedUnit].animated = value end, true)
    Check("Medallion", "Afficher le médaillon de classe", function() return db.medallion end,
        function(value) db.medallion = value end, true)
    Track(UI.Label(body, L("Le médaillon supplémentaire concerne uniquement la cible."), 0, 0), "text", nil, true)
    Button("Reset", "Réinitialiser ce portrait", function()
        local unit, config = selectedUnit, db[selectedUnit]
        UI.Confirm(L("Rétablir l’apparence par défaut de ce portrait ?"), function()
            if db[unit] ~= config then return end
            db[unit] = Normalize()
            Changed()
        end)
    end, true)
    Track(UI.Label(body, L("Si WoW remplace le portrait par l’icône de classe, désactive ce réglage dans les options de WoW pour retrouver le visage."), 0, 0), "text")
    Layout = function()
        local width = math.max(250, panel:GetWidth() - 54)
        local y = 0
        advancedButton:SetText(advanced and L("Masquer la personnalisation avancée") or L("Personnalisation avancée"))
        for _, row in ipairs(rows) do
            local control = row.frame
            local visible = (not row.advanced or advanced) and (not row.combat or WoW.ReadValue(InCombatLockdown) ~= false)
            control:SetShown(visible)
            if row.caption then row.caption:SetShown(visible) end
            if visible then
                control:ClearAllPoints()
                local height = 26
                if row.kind == "text" then
                    control:SetWidth(width)
                    height = math.max(20, control:GetStringHeight())
                elseif row.kind == "check" then
                    control.label:SetWidth(width - 38)
                    height = math.max(28, control.label:GetStringHeight() + 8)
                elseif row.kind == "preview" then
                    height = 250
                    control:SetSize(width, height)
                elseif row.kind == "slider" then
                    row.caption:ClearAllPoints()
                    row.caption:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y)
                    row.caption:SetWidth(width - 8)
                    local captionHeight = math.max(20, row.caption:GetStringHeight())
                    control:SetWidth(math.min(330, width - 8))
                    control:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -y - captionHeight)
                    height = captionHeight + 24
                else
                    control:SetWidth(math.min(330, width))
                end
                if row.kind ~= "slider" then control:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y) end
                y = y + height + 10
            end
        end
        body:SetSize(width, y + 6)
        UI.ClampScroll(scroll, body:GetHeight())
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
            for _, row in ipairs(rows) do if row.frame == target and row.advanced then advanced = true end end
            refreshSettings()
            if target and UI.RevealControl then UI.RevealControl(scroll, target) end
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
