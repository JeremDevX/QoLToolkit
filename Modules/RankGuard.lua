-- Module Rangs de sorts : lecture seule des boutons et du grimoire.
local _, ns = ...
local L = ns.L
local ReadAPI, Read = ns.WoW.Read, ns.WoW.ReadValue
local Public, FiniteNumber = ns.WoW.IsPublic, ns.WoW.IsFiniteNumber
local db, initialized
local buttons, rankCache, warnings = {}, {}, {}
local REFRESH_INTERVAL, EVENT_INTERVAL = 30, 0.2
local elapsed, visualElapsed, periodicElapsed = 0, 0, 0
local discoveryPending = true
local refreshPending, cachePending, immediatePending = true, true, false
local enabled, active = false, false
local preview, previewRemaining = nil, 0
local defaults = {enabled = true, interval = 30, style = "mark", corner = "BOTTOMLEFT", size = 14,
    opacity = 1, color = {1, 0.72, 0.15}, showCombat = true, showRest = true, exceptions = {}}
local driver = CreateFrame("Frame", "ArkannsQOLRankEvents")
driver:Hide()

local function PositiveNumber(value)
    return FiniteNumber(value) and value > 0
end

local function Identifier(value)
    return PositiveNumber(value) and value % 1 == 0
end

local function ReadWithDefault(api, button, default)
    local status, value = ReadAPI(api, button)
    if status == "absent" then return default end
    return value
end

local function Copy(value, depth)
    depth = depth or 0
    if depth > 8 then return nil end
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = Copy(item, depth + 1) end; return result
end
local function Validate(target)
    for key, value in pairs(defaults) do if type(target[key]) ~= type(value) then target[key] = Copy(value) end end
    target.interval = REFRESH_INTERVAL -- Keep the legacy profile key with the fixed cadence.
    for key, bounds in pairs({size = {8, 32}, opacity = {0.1, 1}}) do
        if not FiniteNumber(target[key]) then target[key] = defaults[key] end
        target[key] = math.max(bounds[1], math.min(bounds[2], target[key]))
    end
    if target.style ~= "mark" and target.style ~= "dot" and target.style ~= "border" then target.style = "mark" end
    if target.corner ~= "TOPLEFT" and target.corner ~= "TOPRIGHT" and target.corner ~= "BOTTOMRIGHT" then target.corner = "BOTTOMLEFT" end
    for i = 1, 3 do if not FiniteNumber(target.color[i]) or target.color[i] < 0 or target.color[i] > 1 then target.color[i] = defaults.color[i] end end
    for id, value in pairs(target.exceptions) do if not Identifier(id) or value ~= true then target.exceptions[id] = nil end end
end
local function Visible()
    if not enabled then return false end
    local combat = Read(InCombatLockdown)
    return (combat == true and db.showCombat) or (combat == false and db.showRest)
end

local function IsOldRank(spellID)
    if not Identifier(spellID) then return false end
    if rankCache[spellID] ~= nil then return rankCache[spellID] end
    local book = C_SpellBook
    if not book or not Enum or not Enum.SpellBookSpellBank or not Enum.SpellBookItemType then
        return false
    end
    -- Inclure les rangs masqués, mais jamais les sorts futurs, les flyouts ou les autres spécialisations.
    local _, slot, bank = ReadAPI(book.FindSpellBookSlotForSpell, spellID, true, false, false, false)
    local old = false
    if Identifier(slot) and bank == Enum.SpellBookSpellBank.Player then
        local info = Read(book.GetSpellBookItemInfo, slot, bank)
        if type(info) == "table" and Public(info.itemType) and Public(info.isOffSpec)
            and Public(info.spellID) and Public(info.actionID) and Public(info.isPassive)
            and info.itemType == Enum.SpellBookItemType.Spell and not info.isOffSpec
            and not info.isPassive and (info.spellID == spellID or info.actionID == spellID) then
            -- Le client compare les rangs de la même chaîne ET exige un rang supérieur connu.
            old = Read(book.IsSpellBookItemLowRank, slot, bank) == true
        end
    end
    rankCache[spellID] = old
    return old
end

local function SpellOnButton(button)
    local action
    -- LibActionButton (notamment certaines versions de Bartender/ElvUI).
    if type(button.GetAction) == "function" and type(button.state_types) == "table"
        and type(button.state_actions) == "table" then
        local _, kind, id = ReadAPI(button.GetAction, button)
        if kind == "spell" then return Identifier(id) and id or nil end
        if kind ~= "action" then return nil end
        action = id
    else
        local status, buttonType = ReadAPI(button.GetAttribute, button, "type")
        if status ~= "ok" then return nil end
        if buttonType ~= nil and buttonType ~= "action" then return nil end
        -- Le champ action natif suit déjà les pages et les formes. Ne jamais déduire du GetID().
        if type(button.CalculateAction) == "function" then
            action = button.action
            if not Public(action) then return nil end
            if action == nil then action = Read(button.GetAttribute, button, "action") end
        else
            -- An unreadable or absent live attribute is not evidence for a cached slot.
            action = Read(button.GetAttribute, button, "action")
        end
        if not Public(action) then return nil end
    end
    if not Identifier(action) then return nil end
    local _, actionType, spellID = ReadAPI(GetActionInfo, action)
    if actionType == "spell" and Identifier(spellID) then return spellID end
end

local function IsActionButton(button)
    if button.IsForbidden and Read(button.IsForbidden, button) ~= false then return false end
    local objectType = Read(button.GetObjectType, button)
    if objectType ~= "Button" and objectType ~= "CheckButton" then return false end
    if not button.icon and not button.Icon then return false end
    if type(button.GetAction) == "function" and type(button.state_types) == "table"
        and type(button.state_actions) == "table" then return true end
    return type(button.CalculateAction) == "function"
        or Read(button.GetAttribute, button, "type") == "action"
end

local function NewBadge()
    -- Parent et ancrages indépendants des boutons protégés : aucune mutation de leurs frames.
    local badge = CreateFrame("Frame", nil, UIParent)
    badge:SetSize(12, 14)
    badge:EnableMouse(false)
    local background = badge:CreateTexture(nil, "BACKGROUND")
    badge.background = background
    background:SetAllPoints()
    background:SetColorTexture(0.12, 0.07, 0, 0.90)
    local label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints()
    label:SetText("!")
    label:SetTextColor(1, 0.72, 0.15)
    badge.label = label
    badge.dot = badge:CreateTexture(nil, "OVERLAY")
    badge.dot:SetPoint("CENTER")
    badge.dot:SetTexture("Interface\\Common\\Indicator-Gray")
    badge.edges = {}
    for i = 1, 4 do badge.edges[i] = badge:CreateTexture(nil, "OVERLAY") end
    badge:Hide()
    return badge
end

local function StyleBadge(badge, width, height, ratio)
    local style = ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("ranks")
    local color = style and style.accent or db.color
    badge:SetSize(width, height)
    local bg = style and style.bg or {0.12, 0.07, 0}
    badge.background:SetColorTexture(bg[1], bg[2], bg[3], db.style == "mark" and (style and style.opacity or 0.90) or 0)
    badge.label:SetText(db.style == "mark" and "!" or "")
    badge.label:SetTextColor(unpack(color))
    if badge.label.SetFont then badge.label:SetFont(style and style.font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", db.size * ratio, "OUTLINE") end
    local diameter = math.min(width, height) * .75
    badge.dot:SetSize(diameter, diameter)
    badge.dot:SetVertexColor(unpack(color))
    badge.dot:SetAlpha(db.style == "dot" and 1 or 0)
    local thickness = math.max(1, db.size / 7 * ratio)
    for i, edge in ipairs(badge.edges) do
        edge:ClearAllPoints()
        edge:SetPoint(i <= 2 and "TOPLEFT" or "BOTTOMRIGHT", badge, i <= 2 and "TOPLEFT" or "BOTTOMRIGHT", 0, 0)
        edge:SetSize(i % 2 == 1 and width or thickness, i % 2 == 1 and thickness or height)
        edge:SetColorTexture(color[1], color[2], color[3], db.style == "border" and 1 or 0)
    end
end

local function DiscoverButtons()
    local button = EnumerateFrames()
    while button do
        if not buttons[button] then
            local ok, candidate = pcall(IsActionButton, button)
            if ok and candidate then buttons[button] = NewBadge() end
        end
        button = EnumerateFrames(button)
    end
end

local function PositionBadge(button, badge)
    if button.IsForbidden and Read(button.IsForbidden, button) ~= false then badge:Hide(); return end
    if Read(button.IsVisible, button) ~= true then badge:Hide(); return end
    local left, bottom = Read(button.GetLeft, button), Read(button.GetBottom, button)
    local scale, parentScale = Read(button.GetEffectiveScale, button), Read(UIParent.GetEffectiveScale, UIParent)
    local alpha = Read(button.GetEffectiveAlpha, button)
    if not FiniteNumber(left) or not FiniteNumber(bottom) or not PositiveNumber(scale)
        or not PositiveNumber(parentScale) or not PositiveNumber(alpha) then
        badge:Hide(); return
    end
    local ratio = scale / parentScale
    local width = ReadWithDefault(button.GetWidth, button, 36)
    local height = ReadWithDefault(button.GetHeight, button, 36)
    if not PositiveNumber(width) or not PositiveNumber(height) then badge:Hide(); return end
    local strata = ReadWithDefault(button.GetFrameStrata, button, "MEDIUM")
    local level = ReadWithDefault(button.GetFrameLevel, button, 0)
    if type(strata) ~= "string" or not FiniteNumber(level) then badge:Hide(); return end
    local badgeWidth, badgeHeight = db.size * 12 / 14 * ratio, db.size * ratio
    local x, y = left * ratio + 2, bottom * ratio + 2
    if db.style == "border" then
        x, y, badgeWidth, badgeHeight = left * ratio, bottom * ratio, width * ratio, height * ratio
    else
        if db.corner:find("RIGHT") then x = (left + width) * ratio - badgeWidth - 2 end
        if db.corner:find("TOP") then y = (bottom + height) * ratio - badgeHeight - 2 end
    end
    if not PositiveNumber(ratio) or not FiniteNumber(x) or not FiniteNumber(y)
        or not FiniteNumber(14 * ratio) then badge:Hide(); return end
    badge:ClearAllPoints()
    badge:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
    StyleBadge(badge, badgeWidth, badgeHeight, ratio)
    badge:SetFrameStrata(strata)
    badge:SetFrameLevel(level + 10)
    badge:SetAlpha(alpha * db.opacity)
    badge:Show()
end

local function UpdateBadge(button, badge)
    warnings[button] = nil
    if not enabled or (button.IsForbidden and Read(button.IsForbidden, button) ~= false) then
        badge:Hide(); return
    end
    if Read(button.IsVisible, button) ~= true then badge:Hide(); return end
    local spellID = SpellOnButton(button)
    if not spellID or db.exceptions[spellID] or not IsOldRank(spellID) then badge:Hide(); return end
    warnings[button] = badge
    PositionBadge(button, badge)
end

local function Refresh()
    if not active then
        for _, badge in pairs(warnings) do badge:Hide() end
        if not enabled then warnings = {} end
        return
    end
    for button, badge in pairs(buttons) do
        local ok = pcall(UpdateBadge, button, badge)
        if not ok then badge:Hide() end
    end
end

local function Invalidate()
    cachePending, refreshPending = true, true
end

local function UpdateDriver()
    local visible = Visible()
    if visible and not active then
        Invalidate()
    end
    active = visible
    if active or previewRemaining > 0 then driver:Show() else driver:Hide() end
end

local settingsPanel
local function StopPreview()
    if previewRemaining == 0 then return end
    previewRemaining = 0
    if preview then preview:Hide() end
    if not enabled then driver:UnregisterEvent("PLAYER_REGEN_DISABLED") end
    UpdateDriver()
    if ns.UI and ns.UI.PreviewEnded then ns.UI.PreviewEnded("ranks") end
end
local function Preview()
    if not db or Read(InCombatLockdown) ~= false then return false, L("Aperçu disponible hors combat.") end
    if not preview then
        preview = NewBadge(); preview:SetFrameStrata("TOOLTIP")
        preview:SetScript("OnHide", StopPreview)
    end
    preview:ClearAllPoints(); preview:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    StyleBadge(preview, db.style == "border" and 42 or db.size * 12 / 14, db.style == "border" and 42 or db.size, 1)
    preview:SetAlpha(db.opacity); preview:Show(); previewRemaining = 12
    if not enabled then driver:RegisterEvent("PLAYER_REGEN_DISABLED") end
    driver:Show()
    return true
end
local function Changed()
    UpdateDriver()
    Refresh()
    if previewRemaining > 0 then Preview() end
    if settingsPanel and settingsPanel.OnRefresh then settingsPanel:OnRefresh() end
end
local events = {"PLAYER_ENTERING_WORLD", "TRAINER_SHOW", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
    "LEARNED_SPELL_IN_TAB", "SPELL_TEXT_UPDATE", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UPDATE_OVERRIDE_ACTIONBAR",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}
local function SetEnabled(value)
    enabled = value == true
    if not db then return end
    db.enabled = enabled
    if enabled then
        for _, event in ipairs(events) do pcall(driver.RegisterEvent, driver, event) end
    else
        StopPreview()
        driver:UnregisterAllEvents()
    end
    rankCache, periodicElapsed, cachePending = {}, 0, true
    discoveryPending = enabled
    elapsed, visualElapsed, refreshPending = 0, 0, enabled
    immediatePending = false
    UpdateDriver()
    Refresh()
    if settingsPanel and settingsPanel.OnRefresh then settingsPanel:OnRefresh() end
end

local function RegisterSettings(rootCategory)
    if settingsPanel or not rootCategory or not Settings or not Settings.RegisterCanvasLayoutSubcategory then return end
    local UI = ns.UI
    local canvas = CreateFrame("Frame", "ArkannsQOLRankSettings", UIParent, "BackdropTemplate")
    canvas:Hide()
    UI.Label(canvas, L("Rangs de sorts"), 20, -20, 18)
    local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -54); scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local panel = CreateFrame("Frame", nil, scroll)
    panel:SetSize(540, 1000); scroll:SetScrollChild(panel)
    local items, advanced, appearanceSection, Layout = {}, false, false
    local function Track(frame, kind, width)
        items[#items + 1] = {frame = frame, kind = kind, width = width, advanced = appearanceSection}
        return frame
    end
    local updates = {}
    local function Text(text, size)
        return Track(UI.Label(panel, text, 0, 0, size), "text")
    end
    local function Button(name, label, width, action)
        return Track(UI.Button(panel, "ArkannsQOLRank" .. name, label, 0, 0, width, action), "button", width)
    end
    local function Check(name, label, key)
        local check = UI.Check(panel, "ArkannsQOLRank" .. name, label, 0, 0, function(value)
            if key == "enabled" then SetEnabled(value) else db[key] = value; Changed() end
        end)
        updates[#updates + 1] = function() check:SetChecked(db[key]) end
        return Track(check, "check")
    end
    local function Choice(name, label, key, values)
        local button = Button(name, label, 190, function(self)
            if not MenuUtil or not MenuUtil.CreateContextMenu then return end
            MenuUtil.CreateContextMenu(self, function(_, menu)
                for _, item in ipairs(values) do
                    local value, caption = item[1], item[2]
                    menu:CreateButton(caption, function() db[key] = value; Changed() end)
                end
            end)
        end)
        updates[#updates + 1] = function()
            local caption = tostring(db[key]); for _, item in ipairs(values) do if item[1] == db[key] then caption = item[2] end end
            button:SetText(string.format(L("%s : %s"), label, caption))
        end
    end
    local activation = Check("Enabled", L("Avertissements de rang"), "enabled")
    if not C_SpellBook or not C_SpellBook.IsSpellBookItemLowRank then
        activation:SetEnabled(false)
        Text(L("API de rangs Forever indisponible : aucun avertissement affiché."))
    end
    Text(L("Rang supérieur appris uniquement. Macros ignorées. Aucun sort remplacé."))
    Text(L("Vérification toutes les 30 s, à l’ouverture d’un maître et à l’apprentissage d’un sort."))
    Button("Preview", L("Aperçu · 12 s"), 185, function() UI.PreviewModule("ranks") end)

    Text(L("Visibilité"), 15)
    Check("Combat", L("En combat"), "showCombat")
    Check("Rest", L("Hors combat"), "showRest")
    items[#items].pair = true

    Text(L("Rangs inférieurs volontaires"), 15)
    Text(L("Ajoute un sort signalé ou saisis son identifiant exact de rang."))
    Button("AddException", L("Ignorer un sort signalé"), 240, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            local seen, count = {}, 0
            for button in pairs(warnings) do
                local id = SpellOnButton(button)
                if id and not seen[id] then
                    seen[id], count = true, count + 1
                    local name = C_Spell and Read(C_Spell.GetSpellName, id)
                    menu:CreateButton((name or L("Sort")) .. " · " .. id, function() db.exceptions[id] = true; Changed() end)
                end
            end
            if count == 0 then menu:CreateTitle(L("Aucun ancien rang détecté")) end
        end)
    end)
    Button("RemoveException", L("Retirer une exception"), 260, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            local ids = {}; for id in pairs(db.exceptions) do ids[#ids + 1] = id end; table.sort(ids)
            for _, id in ipairs(ids) do
                local chosen = id; local name = C_Spell and Read(C_Spell.GetSpellName, id)
                menu:CreateButton((name or L("Sort")) .. " · " .. id, function() db.exceptions[chosen] = nil; Changed() end)
            end
            if #ids == 0 then menu:CreateTitle(L("Aucune exception")) end
        end)
    end)
    items[#items].pair = true
    local input = UI.Input(panel, "ArkannsQOLRankExceptionID", 0, 0, 150)
    input:SetMaxLetters(10)
    Track(input, "input", 150)
    local status
    local function AddID()
        local id = tonumber(input:GetText())
        if not Identifier(id) then status:SetText(L("Saisis un identifiant numérique valide.")); Layout(); return end
        db.exceptions[id] = true; input:SetText(""); input:ClearFocus(); status:SetText(string.format(L("Exception ajoutée : %s"), tostring(id))); Changed()
    end
    input:SetScript("OnEnterPressed", AddID)
    Button("AddID", L("Ajouter l’identifiant"), 180, AddID)
    items[#items].pair = true
    Button("ResetExceptions", L("Retirer toutes les exceptions"), 240, function()
        local exceptions = db.exceptions
        UI.Confirm(L("Retirer toutes les exceptions de rang de sort ?"), function()
            if db.exceptions ~= exceptions then return end
            db.exceptions = {}; status:SetText(""); Changed()
        end)
    end)
    status = Text("")
    items[#items].condition = function() return (status:GetText() or "") ~= "" end
    Button("ResetBehavior", L("Fonctionnement par défaut"), 235, function()
        UI.Confirm(L("Réactiver les avertissements de rang ?"), function()
            db.interval = defaults.interval; SetEnabled(defaults.enabled)
        end)
    end)
    Button("ResetVisibility", L("Visibilité par défaut"), 215, function()
        UI.Confirm(L("Afficher de nouveau les avertissements en combat et hors combat ?"), function()
            db.showCombat, db.showRest = defaults.showCombat, defaults.showRest
            Changed()
        end)
    end)
    Button("AppearanceToggle", L("Apparence du badge"), 280, function(self)
        advanced = not advanced
        self:SetText(advanced and L("Masquer l’apparence du badge") or L("Apparence du badge"))
        Layout()
    end)
    appearanceSection = true
    local own = UI.Check(panel, "ArkannsQOLRankOwnStyle", L("Apparence propre à ce module"), 0, 0, function(value)
        UI.SetOverride("ranks", value); Changed()
    end)
    Track(own, "check")
    updates[#updates + 1] = function() own:SetChecked(UI.IsOverride("ranks")) end
    Choice("Style", L("Badge"), "style", {{"mark", "!"}, {"dot", L("Point")}, {"border", L("Bordure")}})
    Choice("Corner", L("Coin"), "corner", {{"BOTTOMLEFT", L("Bas gauche")}, {"BOTTOMRIGHT", L("Bas droite")}, {"TOPLEFT", L("Haut gauche")}, {"TOPRIGHT", L("Haut droite")}})
    items[#items].condition = function() return db.style ~= "border" end
    Choice("Size", L("Taille"), "size", {{10, "10"}, {14, "14"}, {18, "18"}, {24, "24"}, {32, "32"}})
    Choice("Opacity", L("Opacité"), "opacity", {{0.25, L("25 %")}, {0.5, L("50 %")}, {0.75, L("75 %")}, {1, L("100 %")}})
    items[#items].pair = true
    local colorButton = Button("Color", L("Couleur"), 110, function()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local old = Copy(db.color)
        local oldOverride = UI.IsOverride("ranks")
        ColorPickerFrame:SetupColorPickerAndShow({r = old[1], g = old[2], b = old[3], hasOpacity = false,
            swatchFunc = function()
                db.color = {ColorPickerFrame:GetColorRGB()}
                UI.SetOverride("ranks", true)
                Changed()
            end,
            cancelFunc = function()
                db.color = old
                UI.SetOverride("ranks", oldOverride)
                Changed()
            end})
    end)
    updates[#updates + 1] = function() colorButton:SetEnabled(UI.IsOverride("ranks")) end
    Button("ResetAppearance", L("Apparence par défaut"), 230, function()
        UI.Confirm(L("Rétablir l’apparence par défaut du badge de rang ?"), function()
            for _, key in ipairs({"style", "corner", "size", "opacity", "color"}) do db[key] = Copy(defaults[key]) end
            UI.SetOverride("ranks", false)
            Changed()
        end)
    end)

    Layout = function()
        local width = math.max(240, canvas:GetWidth() - 50)
        local y, rowY, rowHeight = 0, 0, 0
        local paired = width >= 540
        local columnWidth = math.floor((width - 12) / 2)
        for index, item in ipairs(items) do
            local control = item.frame
            local visible = (not item.advanced or advanced) and (not item.condition or item.condition())
            control:SetShown(visible)
            if visible then
                local besidePrevious = paired and item.pair
                local pairWithNext = paired and items[index+1] and items[index+1].pair
                local available = (besidePrevious or pairWithNext) and columnWidth or width
                local x = besidePrevious and columnWidth + 12 or item.kind == "input" and 6 or 0
                control:ClearAllPoints(); control:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -(besidePrevious and rowY or y))
                local height = 26
                if item.kind == "text" then
                    control:SetWidth(width); height = math.max(20, control:GetStringHeight())
                elseif item.kind == "check" then
                    control.label:SetWidth(available - 38)
                    height = math.max(28, control.label:GetStringHeight() + 8)
                else control:SetWidth(math.min(item.width or 280, available - 6)) end
                if besidePrevious then
                    y = rowY + math.max(rowHeight, height) + 10
                else
                    rowY, rowHeight = y, height
                    y = y + height + 10
                end
            end
        end
        panel:SetSize(width, y + 12)
        UI.ClampScroll(scroll, panel:GetHeight())
    end
    canvas.OnRefresh = function() for _, update in ipairs(updates) do update() end; Layout() end
    canvas:SetScript("OnShow", canvas.OnRefresh)
    canvas:HookScript("OnSizeChanged", Layout)
    canvas:SetScript("OnHide", StopPreview)
    UI.StylePanel(canvas)
    ns.rankGuardCategory = Settings.RegisterCanvasLayoutSubcategory(rootCategory, canvas, L("Rangs de sorts"))
    settingsPanel = canvas
end

local function MigrateRankGuard(root)
    if type(root.rankGuard) ~= "table" then
        local legacy = type(ArkannsRankGuardDB) == "table" and ArkannsRankGuardDB
        root.rankGuard = {enabled = not legacy or legacy.enabled ~= false}
    end
end
if ns.SettingsState then ns.SettingsState.RegisterMigration("ForeverTooltipLibreDB", 1, MigrateRankGuard) end

function ns.InitializeRankGuard(rootCategory)
    if initialized then return end
    MigrateRankGuard(ForeverTooltipLibreDB)
    db = ForeverTooltipLibreDB.rankGuard
    Validate(db)
    RegisterSettings(rootCategory)
    initialized = true
    SetEnabled(db.enabled)
    Invalidate()
    if ns.RegisterModule then ns.RegisterModule("ranks", {
        label = L("Rangs de sorts"), icon = "Interface\\Icons\\INV_Misc_Book_11", iconAtlas = "UI-HUD-MicroMenu-SpellbookAbilities-Up", category = function() return ns.rankGuardCategory end,
        IsEnabled = function() return enabled end, SetEnabled = SetEnabled,
        Summary = function() local count = 0; for _ in pairs(db.exceptions) do count = count + 1 end; return string.format(L("%d exception(s) · %s s"), count, tostring(db.interval)) end,
        Preview = Preview, StopPreview = StopPreview, Refresh = Changed,
        ExportSettings = function() local result = {}; for key in pairs(defaults) do result[key] = Copy(db[key]) end; return result end,
        profileMigrations = {function(config) config.interval = REFRESH_INTERVAL end},
        ImportSettings = function(config)
            if type(config) ~= "table" then return false end
            local candidate = {}; for key, value in pairs(defaults) do candidate[key] = Copy(config[key] == nil and value or config[key]) end
            Validate(candidate); for key, value in pairs(candidate) do db[key] = value end
            SetEnabled(db.enabled); Changed(); return true
        end,
    }) end
end

local function CheckRanks()
    if cachePending then rankCache, cachePending = {}, false end
    if discoveryPending and type(EnumerateFrames) == "function" and Read(InCombatLockdown) == false then
        DiscoverButtons()
        discoveryPending = false
    end
    Refresh()
    elapsed, refreshPending, immediatePending = 0, false, false
end

local function FullCheck()
    Invalidate()
    discoveryPending, periodicElapsed = true, 0
    -- All learning notifications from this frame share the next frame's check.
    immediatePending = true
end

driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then StopPreview() end
    if not initialized or not enabled then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        UpdateDriver()
        if not active then Refresh() end
    end
    if event == "TRAINER_SHOW" or event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE"
        or event == "PLAYER_ENTERING_WORLD" then
        FullCheck()
        return
    end
    refreshPending = true
    if event == "SPELLS_CHANGED" or event == "SPELL_TEXT_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        cachePending = true
    end
    if event == "PLAYER_REGEN_ENABLED" and discoveryPending and active then CheckRanks() end
end)

driver:SetScript("OnUpdate", function(_, delta)
    if previewRemaining > 0 then
        if delta >= previewRemaining then StopPreview() else previewRemaining = previewRemaining - delta end
    end
    if not active then return end
    elapsed, visualElapsed, periodicElapsed = elapsed + delta, visualElapsed + delta, periodicElapsed + delta
    if periodicElapsed >= REFRESH_INTERVAL then
        periodicElapsed = periodicElapsed % REFRESH_INTERVAL
        discoveryPending = true
        Invalidate()
        immediatePending = true
    end
    if immediatePending or (refreshPending and elapsed >= EVENT_INTERVAL) then
        CheckRanks()
        visualElapsed = 0
    elseif visualElapsed >= EVENT_INTERVAL then
        -- Seuls les avertissements connus suivent les déplacements et le masquage des barres.
        -- Aucun accès au grimoire ni lecture des actions dans ce passage visuel.
        visualElapsed = 0
        for button, badge in pairs(warnings) do
            local ok = pcall(PositionBadge, button, badge)
            if not ok then badge:Hide() end
        end
    end
end)

SLASH_ARKANNSRANKGUARD1 = "/qtrank"
SLASH_ARKANNSRANKGUARD2 = "/arkrang"
SLASH_ARKANNSRANKGUARD3 = "/rankguard"
SlashCmdList.ARKANNSRANKGUARD = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "on" or command == "activer" then SetEnabled(true)
    elseif command == "off" or command == "desactiver" or command == "désactiver" then SetEnabled(false) end
    print(string.format(L("|cffffb829QoL Toolkit — Rangs de sorts|r : %s"), enabled and L("activé.") or L("désactivé.")))
    print(L("Un ! orange indique un rang supérieur déjà appris. /qtrank on ou /qtrank off."))
    if not C_SpellBook or not C_SpellBook.IsSpellBookItemLowRank then
        print(L("API de rangs Forever indisponible : aucun avertissement affiché."))
    end
end
