-- Module Rangs de sorts : lecture seule des boutons et du grimoire.
local _, ns = ...
local L = ns.L
local ReadAPI, Read = ns.WoW.Read, ns.WoW.ReadValue
local Public, FiniteNumber = ns.WoW.IsPublic, ns.WoW.IsFiniteNumber
local db, initialized
local buttons, rankCache, warnings = {}, {}, {}
local REFRESH_INTERVAL, EVENT_INTERVAL, CACHE_INTERVAL, DISCOVERY_INTERVAL = 2, 0.2, 30, 60
local elapsed, visualElapsed, discoveryElapsed, cacheElapsed = 0, 0, DISCOVERY_INTERVAL, 0
local refreshPending, cachePending = true, true
local enabled, active = false, false
local preview, previewRemaining = nil, 0
local defaults = {enabled = true, interval = 2, style = "mark", corner = "BOTTOMLEFT", size = 14,
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
    for key, bounds in pairs({interval = {0.2, 10}, size = {8, 32}, opacity = {0.1, 1}}) do
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
        discoveryElapsed = DISCOVERY_INTERVAL
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
end
local function Preview()
    if not db or Read(InCombatLockdown) ~= false then return end
    if not preview then
        preview = NewBadge(); preview:SetFrameStrata("TOOLTIP")
        preview:SetScript("OnHide", StopPreview)
    end
    preview:ClearAllPoints(); preview:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    StyleBadge(preview, db.style == "border" and 42 or db.size * 12 / 14, db.style == "border" and 42 or db.size, 1)
    preview:SetAlpha(db.opacity); preview:Show(); previewRemaining = 12
    if not enabled then driver:RegisterEvent("PLAYER_REGEN_DISABLED") end
    driver:Show()
end
local function Changed()
    UpdateDriver()
    Refresh()
    if previewRemaining > 0 then Preview() end
    if settingsPanel and settingsPanel.OnRefresh then settingsPanel:OnRefresh() end
end
local events = {"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
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
    rankCache, cacheElapsed, cachePending = {}, 0, false
    if enabled then discoveryElapsed = DISCOVERY_INTERVAL end
    elapsed, visualElapsed, refreshPending = 0, 0, enabled
    UpdateDriver()
    Refresh()
    if settingsPanel and settingsPanel.OnRefresh then settingsPanel:OnRefresh() end
end

local function RegisterSettings(rootCategory)
    if settingsPanel or not rootCategory or not Settings or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame", "ArkannsQOLRankSettings", UIParent, "BackdropTemplate")
    panel:Hide()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -20)
    title:SetText(L("Rangs de sorts"))
    local updates = {}
    local function Text(text, x, y)
        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y); label:SetText(text); return label
    end
    local function Button(name, label, x, y, width, action)
        local button = CreateFrame("Button", "ArkannsQOLRank" .. name, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y); button:SetSize(width, 26); button:SetText(label)
        button:SetScript("OnClick", action)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        return button
    end
    local function Check(name, label, key, x, y)
        local check = CreateFrame("CheckButton", "ArkannsQOLRank" .. name, panel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
        local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        text:SetPoint("LEFT", check, "RIGHT", 4, 0); text:SetText(label)
        check:SetScript("OnClick", function(self)
            if key == "enabled" then SetEnabled(self:GetChecked()) else db[key] = self:GetChecked() == true; Changed() end
        end)
        updates[#updates + 1] = function() check:SetChecked(db[key]) end
    end
    local function Choice(name, label, key, values, x, y, width)
        local button = Button(name, label, x, y, width or 185, function(self)
            if not MenuUtil then return end
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
    Text(L("Fonctionnement"), 24, -62)
    Check("Enabled", L("Avertissements de rang"), "enabled", 20, -86)
    Choice("Interval", L("Actualisation"), "interval", {{0.5, L("0,5 s")}, {1, "1 s"}, {2, "2 s"}, {5, "5 s"}, {10, "10 s"}}, 320, -88, 220)
    Text(L("Rang supérieur appris uniquement. Macros ignorées. Aucun sort remplacé."), 24, -128)
    Button("ResetBehavior", L("Réinitialiser"), 430, -54, 110, function() db.interval = 2; SetEnabled(true) end)

    Text(L("Apparence"), 24, -176)
    Choice("Style", L("Badge"), "style", {{"mark", "!"}, {"dot", L("Point")}, {"border", L("Bordure")}}, 24, -204)
    Choice("Corner", L("Coin"), "corner", {{"BOTTOMLEFT", L("Bas gauche")}, {"BOTTOMRIGHT", L("Bas droite")}, {"TOPLEFT", L("Haut gauche")}, {"TOPRIGHT", L("Haut droite")}}, 224, -204, 190)
    Choice("Size", L("Taille"), "size", {{10, "10"}, {14, "14"}, {18, "18"}, {24, "24"}, {32, "32"}}, 24, -240)
    Choice("Opacity", L("Opacité"), "opacity", {{0.25, L("25 %")}, {0.5, L("50 %")}, {0.75, L("75 %")}, {1, L("100 %")}}, 224, -240, 190)
    Button("Color", L("Couleur"), 430, -240, 110, function()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local old = Copy(db.color)
        local oldOverride = ns.UI and ns.UI.IsOverride and ns.UI.IsOverride("ranks")
        ColorPickerFrame:SetupColorPickerAndShow({r = old[1], g = old[2], b = old[3], hasOpacity = false,
            swatchFunc = function()
                db.color = {ColorPickerFrame:GetColorRGB()}
                if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("ranks", true) end
                Changed()
            end,
            cancelFunc = function()
                db.color = old
                if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("ranks", oldOverride == true) end
                Changed()
            end})
    end)
    Button("Preview", L("Aperçu · 12 s"), 24, -278, 185, Preview)
    Button("StopPreview", L("Arrêter l’aperçu"), 224, -278, 190, StopPreview)
    Button("ResetAppearance", L("Réinitialiser"), 430, -168, 110, function()
        for _, key in ipairs({"style", "corner", "size", "opacity", "color"}) do db[key] = Copy(defaults[key]) end
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("ranks", false) end
        Changed()
    end)

    Text(L("Visibilité"), 24, -356)
    Check("Combat", L("En combat"), "showCombat", 20, -380)
    Check("Rest", L("Hors combat"), "showRest", 224, -380)
    Button("ResetVisibility", L("Réinitialiser"), 430, -348, 110, function() db.showCombat, db.showRest = true, true; Changed() end)

    Text(L("Rangs inférieurs volontaires"), 24, -436)
    Text(L("Ajoute un sort signalé ou saisis son identifiant exact de rang."), 24, -462)
    Button("AddException", L("Ignorer un sort signalé"), 24, -492, 240, function(self)
        if not MenuUtil then return end
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
    Button("RemoveException", L("Retirer une exception"), 280, -492, 260, function(self)
        if not MenuUtil then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            local ids = {}; for id in pairs(db.exceptions) do ids[#ids + 1] = id end; table.sort(ids)
            for _, id in ipairs(ids) do
                local chosen = id; local name = C_Spell and Read(C_Spell.GetSpellName, id)
                menu:CreateButton((name or L("Sort")) .. " · " .. id, function() db.exceptions[chosen] = nil; Changed() end)
            end
            if #ids == 0 then menu:CreateTitle(L("Aucune exception")) end
        end)
    end)
    local input = CreateFrame("EditBox", "ArkannsQOLRankExceptionID", panel, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -532); input:SetSize(150, 24)
    input:SetAutoFocus(false); input:SetMaxLetters(10)
    local status = Text("", 24, -570)
    local function AddID()
        local id = tonumber(input:GetText())
        if not Identifier(id) then status:SetText(L("Saisis un identifiant numérique valide.")); return end
        db.exceptions[id] = true; input:SetText(""); input:ClearFocus(); status:SetText(string.format(L("Exception ajoutée : %s"), tostring(id))); Changed()
    end
    input:SetScript("OnEnterPressed", AddID)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    Button("AddID", L("Ajouter l’identifiant"), 200, -530, 180, AddID)
    Button("ResetExceptions", L("Tout retirer"), 400, -530, 140, function() db.exceptions = {}; status:SetText(""); Changed() end)
    if ns.UI and ns.UI.IsOverride and ns.UI.SetOverride then
        local own = CreateFrame("CheckButton", "ArkannsQOLRankOwnStyle", panel, "UICheckButtonTemplate")
        own:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -312)
        local ownLabel = own:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ownLabel:SetPoint("LEFT", own, "RIGHT", 4, 0); ownLabel:SetText(L("Apparence propre à ce module"))
        own:SetScript("OnClick", function(self) ns.UI.SetOverride("ranks", self:GetChecked() == true) end)
        updates[#updates + 1] = function() own:SetChecked(ns.UI.IsOverride("ranks")) end
    end
    panel.OnRefresh = function() for _, update in ipairs(updates) do update() end end
    panel:SetScript("OnShow", panel.OnRefresh)
    panel:SetScript("OnHide", StopPreview)
    if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(panel) end
    ns.rankGuardCategory = Settings.RegisterCanvasLayoutSubcategory(rootCategory, panel, L("Rangs de sorts"))
    settingsPanel = panel
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
    elapsed = REFRESH_INTERVAL
    if ns.RegisterModule then ns.RegisterModule("ranks", {
        label = L("Rangs de sorts"), icon = "Interface\\Icons\\INV_Misc_Book_11", iconAtlas = "UI-HUD-MicroMenu-SpellbookAbilities-Up", category = function() return ns.rankGuardCategory end,
        IsEnabled = function() return enabled end, SetEnabled = SetEnabled,
        Summary = function() local count = 0; for _ in pairs(db.exceptions) do count = count + 1 end; return string.format(L("%d exception(s) · %s s"), count, tostring(db.interval)) end,
        Preview = Preview, StopPreview = StopPreview, Refresh = Changed,
        ExportSettings = function() local result = {}; for key in pairs(defaults) do result[key] = Copy(db[key]) end; return result end,
        ImportSettings = function(config)
            if type(config) ~= "table" then return false end
            local candidate = {}; for key, value in pairs(defaults) do candidate[key] = Copy(config[key] == nil and value or config[key]) end
            Validate(candidate); for key, value in pairs(candidate) do db[key] = value end
            SetEnabled(db.enabled); Changed(); return true
        end,
    }) end
end

driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then StopPreview() end
    if not initialized or not enabled then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        UpdateDriver()
        if not active then Refresh() end
    end
    refreshPending = true
    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "SPELL_TEXT_UPDATE"
        or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        cachePending = true
    end
    if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" then
        discoveryElapsed = DISCOVERY_INTERVAL
    end
end)

driver:SetScript("OnUpdate", function(_, delta)
    if previewRemaining > 0 then
        if delta >= previewRemaining then StopPreview() else previewRemaining = previewRemaining - delta end
    end
    if not active then return end
    elapsed, visualElapsed = elapsed + delta, visualElapsed + delta
    discoveryElapsed, cacheElapsed = discoveryElapsed + delta, cacheElapsed + delta
    -- Regrouper les événements : aucun scan complet plus de cinq fois par seconde.
    if elapsed >= db.interval or (refreshPending and elapsed >= EVENT_INTERVAL) then
        if cachePending or cacheElapsed >= CACHE_INTERVAL then
            rankCache, cacheElapsed, cachePending = {}, 0, false
        end
        if discoveryElapsed >= DISCOVERY_INTERVAL and type(EnumerateFrames) == "function" and Read(InCombatLockdown) == false then
            DiscoverButtons()
            discoveryElapsed = 0
        end
        Refresh()
        elapsed, visualElapsed, refreshPending = 0, 0, false
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
