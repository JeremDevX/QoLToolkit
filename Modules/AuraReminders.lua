local _, ns = ...
local L = ns.L
local Model, WoW = ns.AuraReminderModel, ns.WoW
local db, reminder, message, category, manualInput, status, enabled, list, listBody, emptyList
local apiNotice, layoutEffects
local rows = {}
local testMode, testControls
local reminderRows = {}
local appearanceRefresh
local expanded, effectiveAppearance, activeStyle = false, nil, nil
local RestorePosition
local events, observingEffects
local effectEvents = {"UNIT_AURA", "MINIMAP_UPDATE_TRACKING", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "SPELLS_CHANGED"}
local priorityLabels = {[1] = L("Haute"), [2] = L("Normale"), [3] = L("Basse")}
local labels = {aura = L("Auras / postures"), buff = "Buffs", tracking = L("Minicarte")}
local order = Model.KindOrder

local defaults = {
    layout = "vertical", columns = 2, width = 400, gap = 6, padding = 12,
    font = "standard", fontSize = 16, titleSize = 18, outline = "", align = "LEFT",
    iconSize = 28, showIcons = true, showTitle = true, title = "À réactiver", customTitle = false,
    background = "140803", backgroundAlpha = 85, border = "tooltip", borderSize = 12,
    borderColor = "FFCC44", textColor = "FF6633", titleColor = "FFCC44", shadow = true,
}
local ranges = {columns = {1, 6}, width = {180, 1000}, gap = {0, 30}, padding = {4, 40},
    fontSize = {10, 32}, titleSize = {10, 40}, iconSize = {16, 64}, backgroundAlpha = {0, 100}, borderSize = {1, 24}}
local choices = {
    layout = {{"vertical", L("Liste verticale")}, {"horizontal", L("Ligne")}, {"grid", L("Grille")}},
    font = {{"standard", L("Classique")}, {"narrow", "Arial"}, {"fantasy", "Morpheus"}},
    outline = {{"", L("Aucun contour")}, {"OUTLINE", L("Contour fin")}, {"THICKOUTLINE", L("Contour épais")}},
    align = {{"LEFT", L("Gauche")}, {"CENTER", L("Centre")}, {"RIGHT", L("Droite")}},
    border = {{"none", L("Sans bordure")}, {"tooltip", L("Classique")}, {"flat", L("Trait simple")}},
}
local themes = {
    {L("Classique"), {}},
    {L("Sobre"), {background = "101820", backgroundAlpha = 80, textColor = "FFFFFF", titleColor = "82D8FF", borderColor = "477082", border = "flat", borderSize = 1}},
    {L("Lumineux"), {background = "EEE8D8", backgroundAlpha = 95, textColor = "302820", titleColor = "943600", borderColor = "806B50", border = "flat", borderSize = 2, shadow = false}},
    {L("Compact"), {width = 280, fontSize = 12, titleSize = 14, iconSize = 20, gap = 2, padding = 6, background = "101010", textColor = "FFFFFF", border = "none"}},
}

local function ValidID(value)
    return WoW.IsFiniteNumber(value) and value >= 1 and value <= 2147483647 and value == math.floor(value)
end

local function TitleText(appearance)
    if appearance.title == defaults.title and not appearance.customTitle then return L(defaults.title) end
    return appearance.title
end

local function NormalizeAppearance()
    if type(db.appearance) ~= "table" then db.appearance = {} end
    for key, default in pairs(defaults) do
        local value, valid = db.appearance[key], false
        if ranges[key] then
            valid = type(value) == "number" and value == value and value >= ranges[key][1] and value <= ranges[key][2]
            if valid then value = math.floor(value + 0.5) end
        elseif choices[key] then
            for _, choice in ipairs(choices[key]) do if value == choice[1] then valid = true end end
        elseif key == "title" then
            valid = type(value) == "string" and #value > 0 and #value <= 120 and not value:find("[|\r\n]")
            if not valid then db.appearance.customTitle = false end
        elseif type(default) == "boolean" then valid = type(value) == "boolean"
        else valid = type(value) == "string" and value:match("^%x%x%x%x%x%x$") ~= nil end
        if valid then db.appearance[key] = value else db.appearance[key] = default end
    end
end

local function RGB(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function FontPath()
    if activeStyle then return activeStyle.font end
    if db.appearance.font == "narrow" then return "Fonts\\ARIALN.TTF" end
    if db.appearance.font == "fantasy" then return "Fonts\\MORPHEUS.TTF" end
    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function StyleText(text, size, color)
    text:SetFont(FontPath(), size, db.appearance.outline)
    text:SetTextColor(RGB(color))
    if activeStyle then text:SetTextColor(unpack(text == message and activeStyle.accent or activeStyle.text)) end
    text:SetJustifyH(db.appearance.align)
    text:SetShadowColor(0, 0, 0, db.appearance.shadow and 0.8 or 0)
    text:SetShadowOffset(1, -1)
end

local function NormalizeBehavior()
    for key, value in pairs({enabled = true, grouped = false, compact = false, expandOnHover = true}) do
        if type(db[key]) ~= "boolean" then db[key] = value end
    end
    if type(db.visibleLimit) ~= "number" or db.visibleLimit ~= db.visibleLimit or db.visibleLimit < 1 or db.visibleLimit > 20 then db.visibleLimit = 6 end
    db.visibleLimit = math.floor(db.visibleLimit)
    for _, key in ipairs({"auras", "tracking"}) do
        local clean, seen = {}, {}
        for _, rule in ipairs(type(db[key]) == "table" and db[key] or {}) do
            if type(rule) == "table" and type(rule.name) == "string" and rule.name ~= "" and #rule.name <= 160 and not rule.name:find("[|\r\n]") and not seen[rule.name:lower()] then
                seen[rule.name:lower()] = true
                if key == "tracking" then rule.kind = "tracking" elseif rule.kind ~= "aura" then rule.kind = "buff" end
                if rule.priority ~= 1 and rule.priority ~= 2 and rule.priority ~= 3 then rule.priority = 2 end
                rule.spellID = ValidID(rule.spellID) and rule.spellID or nil
                rule.icon = ValidID(rule.icon) and rule.icon or nil
                clean[#clean + 1] = rule
            end
        end
        if type(db[key]) ~= "table" then db[key] = {} end
        for index in pairs(db[key]) do db[key][index] = nil end
        for index, rule in ipairs(clean) do db[key][index] = rule end
    end
end

local function DisplayEffects(effects)
    local visible, remaining = Model.OrderAndLimit(effects, db, expanded)
    local result, lastKind = {}, nil
    for index = 1, visible do
        local effect = effects[index]
        local kind = effect.kind or "buff"
        if db.grouped and kind ~= lastKind then result[#result + 1] = {name = labels[kind], heading = true}; lastKind = kind end
        result[#result + 1] = effect
    end
    if remaining > 0 then result[#result + 1] = {name = ("+" .. remaining), heading = true} end
    return result
end

local function Render(effects)
    effects = DisplayEffects(effects)
    local a = {}; for key, value in pairs(db.appearance) do a[key] = value end
    activeStyle = ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("reminders")
    if activeStyle then
        a.fontSize, a.titleSize, a.gap, a.padding = activeStyle.fontSize, activeStyle.fontSize + 1, activeStyle.gap, activeStyle.padding
        a.border, a.borderSize, a.backgroundAlpha = "tooltip", activeStyle.borderSize, activeStyle.opacity * 100
    end
    effectiveAppearance = a
    local previousScale = reminder:GetScale()
    reminder:SetScale(activeStyle and activeStyle.scale or 1)
    if previousScale ~= reminder:GetScale() then RestorePosition() end
    if reminder.EnableMouseMotion then reminder:EnableMouseMotion(testMode ~= "layout" and (testMode ~= nil or (db.compact and db.expandOnHover))) end
    local edge = a.border == "tooltip" and "Interface\\Tooltips\\UI-Tooltip-Border" or (a.border == "flat" and "Interface\\Buttons\\WHITE8X8" or nil)
    reminder:SetWidth(a.width)
    reminder:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = edge, edgeSize = a.borderSize,
        insets = {left = 0, right = 0, top = 0, bottom = 0}})
    local r, g, b = RGB(a.background)
    reminder:SetBackdropColor(r, g, b, a.backgroundAlpha / 100)
    if edge then reminder:SetBackdropBorderColor(RGB(a.borderColor)) end
    if activeStyle and ns.UI.StyleFrame then ns.UI.StyleFrame(reminder, "reminders") end
    message:ClearAllPoints()
    local testHeight = testMode and testMode ~= "layout" and 26 or 0
    message:SetPoint("TOPLEFT", a.padding, -a.padding - testHeight)
    message:SetWidth(a.width - 2 * a.padding)
    StyleText(message, a.titleSize, a.titleColor)
    message:SetText(TitleText(a))
    message:SetShown(a.showTitle)
    local y = a.padding + testHeight + (a.showTitle and message:GetStringHeight() + a.gap or 0)
    local available = a.width - 2 * a.padding
    local minCell = math.max(64, (a.showIcons and a.iconSize + a.gap or 0) + a.fontSize * 3)
    local capacity = math.max(1, math.floor((available + a.gap) / (minCell + a.gap)))
    local columns = not db.grouped and (a.layout == "grid" and math.min(a.columns, capacity) or (a.layout == "horizontal" and math.min(#effects, capacity) or 1)) or 1
    columns = math.max(1, columns)
    local cellWidth = (available - (columns - 1) * a.gap) / columns
    local iconGap = math.min(a.gap, cellWidth / 8)
    local iconSize = math.min(a.iconSize, math.max(16, cellWidth - iconGap - a.fontSize * 2))
    local rowHeight = 0
    for index, effect in ipairs(effects) do
        local row = reminderRows[index]
        if not row then
            row = CreateFrame("Frame", "ArkannsQOLReminderItem" .. index, reminder)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetWordWrap(true)
            reminderRows[index] = row
        end
        local column = (index - 1) % columns
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", a.padding + column * (cellWidth + a.gap), -y)
        row:SetWidth(cellWidth)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", 0, 0)
        row.icon:SetSize(iconSize, iconSize)
        row.icon:SetTexture(effect.icon or 134400)
        row.icon:SetShown(a.showIcons and not effect.heading)
        local offset = a.showIcons and not effect.heading and iconSize + iconGap or 0
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", offset, 0)
        row.text:SetWidth(math.max(1, cellWidth - offset))
        StyleText(row.text, a.fontSize, a.textColor)
        if effect.heading then
            if activeStyle then row.text:SetTextColor(unpack(activeStyle.accent)) else row.text:SetTextColor(RGB(a.titleColor)) end
        end
        row.text:SetText(effect.name)
        local height = math.max(a.showIcons and not effect.heading and iconSize or 0, row.text:GetStringHeight())
        row:SetHeight(height)
        row:Show()
        rowHeight = math.max(rowHeight, height)
        if column == columns - 1 or index == #effects then y = y + rowHeight + a.gap; rowHeight = 0 end
    end
    for index = #effects + 1, #reminderRows do reminderRows[index]:Hide() end
    reminder:SetHeight(math.max(30, y - a.gap + a.padding))
    testControls:SetShown(testMode ~= nil and testMode ~= "layout")
    reminder:Show()
end

local function SafeIcon(icon)
    if ValidID(icon) then return icon end
    return 134400
end

local function HasSpellLookup()
    return C_Spell and type(C_Spell.GetSpellInfo) == "function"
end

local function HasForms()
    return HasSpellLookup() and type(GetNumShapeshiftForms) == "function" and type(GetShapeshiftFormInfo) == "function"
end

local function ReadCount(api)
    local count = WoW.ReadValue(api)
    if WoW.IsFiniteNumber(count) and count >= 0 and count <= 255 and count == math.floor(count) then return count end
end

local function FormCount()
    if HasForms() then return ReadCount(GetNumShapeshiftForms) end
end

local function HasBuffs()
    return C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function"
end

local function HasTracking()
    return C_Minimap and type(C_Minimap.GetNumTrackingTypes) == "function" and type(C_Minimap.GetTrackingInfo) == "function"
end

local function HasMenus()
    return MenuUtil and type(MenuUtil.CreateContextMenu) == "function"
end

local function Spell(value)
    if not HasSpellLookup() then return end
    local info = WoW.ReadValue(C_Spell.GetSpellInfo, value)
    if type(info) ~= "table" or not WoW.IsPublic(info.name) or type(info.name) ~= "string" or not WoW.IsPublic(info.spellID) then return end
    return info.name, info.spellID, WoW.IsPublic(info.iconID) and info.iconID or nil
end

local function RuleName(rule)
    return rule.spellID and Spell(rule.spellID) or rule.name
end

local function EffectIcon(rule)
    if not rule.icon then
        local _, _, icon = Spell(rule.spellID or rule.name)
        return SafeIcon(icon)
    end
    return SafeIcon(rule.icon)
end

local function ActiveFlag(value)
    if not WoW.IsPublic(value) then return end
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
end

local function Tracking()
    local result = {}
    local count = HasTracking() and ReadCount(C_Minimap.GetNumTrackingTypes)
    if not count then return result end
    for index = 1, count do
        local info = WoW.ReadValue(C_Minimap.GetTrackingInfo, index)
        if type(info) == "table" and WoW.IsPublic(info.name) and type(info.name) == "string" then
            local tracking = {name = info.name, active = ActiveFlag(info.active),
                spellID = ValidID(info.spellID) and info.spellID or nil, texture = WoW.IsPublic(info.texture) and info.texture or nil}
            result[info.name:lower()] = tracking
            if tracking.spellID then result[tracking.spellID] = tracking end
        end
    end
    return result
end

local function FormInfo(index)
    local ok, icon, active, _, spellID = pcall(GetShapeshiftFormInfo, index)
    if ok and ValidID(spellID) then return Spell(spellID), ActiveFlag(active), spellID, icon end
end

local function Forms()
    local forms, count = {}, FormCount()
    local known = count ~= nil
    for index = 1, count or 0 do
        local name, active, spellID = FormInfo(index)
        local form = {active = active}
        if spellID then forms[spellID] = form end
        if name then
            local key = name:lower()
            if not forms[key] then forms[key] = form end
        else
            known = false
        end
    end
    return forms, known
end

local function Buffs()
    local buffs, known = {}, HasBuffs()
    if not known then return buffs, false end
    for index = 1, 255 do
        local status, aura = WoW.Read(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        if status ~= "ok" then return buffs, false end
        if aura == nil then break end
        if type(aura) == "table" and WoW.IsPublic(aura.name) and type(aura.name) == "string" then
            buffs[aura.name:lower()] = true
            if ValidID(aura.spellId) then buffs[aura.spellId] = true end
        else
            known = false
        end
    end
    return buffs, known
end

local function Blocked()
    local combatStatus, combat = WoW.Read(InCombatLockdown)
    if combatStatus ~= "ok" or combat ~= false then return true end
    local deathStatus, dead = WoW.Read(UnitIsDeadOrGhost, "player")
    return deathStatus ~= "ok" or dead ~= false
end

RestorePosition = function()
    reminder:ClearAllPoints()
    local scale = reminder:GetScale()
    reminder:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.x * UIParent:GetWidth() / scale, db.y * UIParent:GetHeight() / scale)
end

local Update
local function SyncEffectEvents(active)
    if not events or active == observingEffects then return end
    for _, event in ipairs(effectEvents) do
        if active then events:RegisterEvent(event) else events:UnregisterEvent(event) end
    end
    observingEffects = active
end

local function EndTest()
    if not testMode then return end
    testMode = nil -- Clear before Hide: OnHide also ends the test (including Escape).
    if ns.UI.PreviewEnded then ns.UI.PreviewEnded("reminders") end
    expanded = false
    testControls:Hide()
    reminder:EnableMouse(false)
    reminder:SetFrameStrata("HIGH")
    Update()
    if appearanceRefresh then appearanceRefresh() end
end

Update = function()
    if not db then return end
    local active = db.enabled and (#db.auras > 0 or #db.tracking > 0)
    SyncEffectEvents(active)
    if not active and not testMode then reminder:Hide(); return end
    if Blocked() then
        EndTest()
        reminder:EnableMouse(false)
        reminder:Hide()
        return
    end
    if testMode then
        local samples = {}
        for _, key in ipairs({"auras", "tracking"}) do
            for _, rule in ipairs(db[key]) do
                if #samples < 8 then samples[#samples + 1] = {name = RuleName(rule), icon = EffectIcon(rule), priority = rule.priority, kind = key == "tracking" and "tracking" or rule.kind or "buff"} end
            end
        end
        if #samples == 0 then
            samples = {{name = L("Aura de dévotion"), icon = 135893, kind = "aura", priority = 1}, {name = L("Bénédiction de puissance"), icon = 135906, kind = "buff", priority = 1}, {name = L("Bénédiction de sagesse"), icon = 135970, kind = "buff"}, {name = L("Détection des minerais"), icon = 136025, kind = "tracking"}, {name = L("Détection des herbes"), icon = 133939, kind = "tracking"}, {name = L("Élixir"), icon = 134838, kind = "buff"}, {name = L("Nourriture"), icon = 133971, kind = "buff", priority = 3}}
        end
        Render(samples)
        return
    end
    local observed = {tracking = #db.tracking > 0 and Tracking() or {}, resolveName = RuleName}
    if #db.auras > 0 then
        observed.buffs, observed.buffsKnown = Buffs()
        observed.forms, observed.formsKnown = Forms()
    end
    local missing = Model.Missing(db, observed)
    if #missing == 0 then reminder:Hide(); return end
    for _, effect in ipairs(missing) do
        effect.icon = effect.kind == "tracking" and SafeIcon(effect.icon) or EffectIcon(effect)
    end
    Render(missing)
end

local function Kind(rule, key, forms, name)
    if key == "tracking" then return "tracking" end
    if rule.kind == "aura" or Model.Match(rule, forms, name) then return "aura" end
    return "buff"
end

local function LayoutRows()
    local narrow = listBody:GetWidth() < 420
    local step = narrow and 48 or 38
    local count = 0
    for index, row in ipairs(rows) do
        if row:IsShown() then
            local y = -(index - 1) * step
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, y); row:SetPoint("TOPRIGHT", 0, y)
            row:SetHeight(step - 2)
            row.kindLabel:ClearAllPoints(); row.nameLabel:ClearAllPoints()
            if narrow then
                row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 8, 8)
                row.nameLabel:SetPoint("RIGHT", row.priority, "LEFT", -8, 8)
                row.kindLabel:SetPoint("TOPLEFT", row.nameLabel, "BOTTOMLEFT", 0, -1)
                row.kindLabel:SetJustifyH("LEFT")
            else
                row.kindLabel:SetPoint("RIGHT", row.priority, "LEFT", -6, 0)
                row.kindLabel:SetJustifyH("RIGHT")
                row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
                row.nameLabel:SetPoint("RIGHT", row.kindLabel, "LEFT", -10, 0)
            end
            count = count + 1
        end
    end
    local height = count * step
    list:SetHeight(math.max(1, math.min(height, 152)))
    listBody:SetHeight(math.max(1, height))
    ns.UI.ClampScroll(list, height)
end

local Refresh
Refresh = function()
    local entries = {}
    local tracking = #db.tracking > 0 and Tracking() or {}
    local forms = #db.auras > 0 and Forms() or {}
    local unavailable = {}
    if not HasSpellLookup() then unavailable[#unavailable + 1] = L("recherche par ID") end
    if not HasForms() then unavailable[#unavailable + 1] = L("auras / postures") end
    if not HasBuffs() then unavailable[#unavailable + 1] = "buffs" end
    if not HasTracking() then unavailable[#unavailable + 1] = L("minicarte") end
    if not HasMenus() then unavailable[#unavailable + 1] = "menus" end
    apiNotice:SetText(#unavailable > 0 and L("Indisponible : %s"):format(table.concat(unavailable, ", ")) or "")
    for _, key in ipairs({"auras", "tracking"}) do
        for _, rule in ipairs(db[key]) do
            local name = RuleName(rule)
            local track = key == "tracking" and Model.Match(rule, tracking, name)
            entries[#entries + 1] = {rule = rule, key = key, kind = Kind(rule, key, forms, name),
                name = track and track.name or name, track = track}
        end
    end
    table.sort(entries, function(a, b)
        if a.kind ~= b.kind then return order[a.kind] < order[b.kind] end
        return a.name:lower() < b.name:lower()
    end)
    for index, entry in ipairs(entries) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", "ArkannsQOLEffectRow" .. index, listBody)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(28, 28); row.icon:SetPoint("LEFT", 4, 0)
            row.delete = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.delete:SetSize(26, 26); row.delete:SetPoint("RIGHT", -4, 0)
            row.delete:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L("Supprimer le rappel"))
                GameTooltip:Show()
            end)
            local function HideDeleteTooltip(self)
                if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
            end
            row.delete:SetScript("OnLeave", HideDeleteTooltip)
            row.delete:SetScript("OnHide", HideDeleteTooltip)
            row.kindLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.priority = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.priority:SetSize(78, 26); row.priority:SetPoint("RIGHT", row.delete, "LEFT", -6, 0)
            row.priority:SetScript("OnClick", function()
                row.rule.priority = (row.rule.priority or 2) % 3 + 1; Refresh(); Update()
            end)
            if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(row.priority) end
            row.kindLabel:SetWidth(96)
            row.nameLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            row.nameLabel:SetJustifyH("LEFT"); row.nameLabel:SetWordWrap(false)
            row.delete:SetScript("OnClick", function()
                local selected, key, name = row.rule, row.key, row.nameLabel:GetText()
                ns.UI.Confirm(L("Supprimer le rappel « %s » ?"):format(name), function()
                    for itemIndex, rule in ipairs(db[key]) do
                        if rule == selected then
                            table.remove(db[key], itemIndex)
                            status:SetText(L("%s : rappel supprimé."):format(name))
                            Refresh(); Update(); break
                        end
                    end
                end)
            end)
            rows[index] = row
        end
        row.rule, row.key = entry.rule, entry.key
        local icon = entry.track and entry.track.texture or EffectIcon(entry.rule)
        row.icon:SetTexture(SafeIcon(icon))
        row.nameLabel:SetText(entry.name)
        row.kindLabel:SetText(labels[entry.kind])
        row.priority:SetText(priorityLabels[entry.rule.priority or 2])
        row:Show()
    end
    for index = #entries + 1, #rows do rows[index]:Hide() end
    list:SetShown(#entries > 0)
    emptyList:SetShown(#entries == 0)
    enabled:SetChecked(db.enabled)
    layoutEffects()
end

local function AddEffect(name, kind, spellID, icon)
    spellID = ValidID(spellID) and spellID or nil
    icon = ValidID(icon) and icon or nil
    local key = kind == "tracking" and "tracking" or "auras"
    for _, rule in ipairs(db[key]) do
        if (spellID and spellID == rule.spellID) or RuleName(rule):lower() == name:lower() then
            -- Enrich older saved entries without creating duplicates.
            rule.kind, rule.spellID, rule.icon = kind, rule.spellID or spellID, icon or rule.icon
            Refresh(); Update(); status:SetText(L("%s est déjà dans la liste."):format(name))
            return
        end
    end
    db[key][#db[key] + 1] = {name = name, kind = kind, spellID = spellID, icon = icon, priority = 2}
    Refresh(); Update()
    status:SetText(L("%s : rappel ajouté."):format(name))
end

local function AddManual()
    local value = manualInput:GetText():match("^%s*(.-)%s*$")
    if value == "" or #value > 160 or value:find("[|\r\n]") then
        status:SetText(L("Nom exact ou ID du sort requis.")); return
    end
    local id = tonumber(value)
    if id and (id ~= id or id < 1 or id > 2147483647 or id ~= math.floor(id)) then
        status:SetText(L("ID de sort invalide.")); return
    end
    if id and not HasSpellLookup() then status:SetText(L("Recherche par ID indisponible.")); return end
    local name, spellID, icon = Spell(id or value)
    if id and not name then status:SetText(L("Sort introuvable.")); return end
    name = id and name or value
    local rule = {name = name, spellID = spellID}
    local track = Model.Match(rule, Tracking())
    local forms = not track and Forms()
    local kind = track and "tracking" or (Model.Match(rule, forms) and "aura" or "buff")
    if track then spellID, icon = track.spellID or spellID, track.texture or icon end
    AddEffect(name, kind, spellID, icon)
    manualInput:SetText(""); manualInput:ClearFocus()
end

local function ChooseEffect(owner, kind)
    if Blocked() then
        status:SetText(L("Indisponible en combat ou à la mort."))
        if ns.UI.Notify then ns.UI.Notify(L("Indisponible en combat ou à la mort.")) end
        return
    end
    if not HasMenus() then status:SetText(L("Menu indisponible. Ajoute l’effet par nom.")); return end
    if (kind == "tracking" and not HasTracking()) or (kind == "aura" and not HasForms())
        or (kind == "buff" and not HasBuffs()) then
        status:SetText(L("%s : lecture indisponible."):format(labels[kind]))
        return
    end
    local choices, seen = {}, {}
    local function Add(name, spellID, icon)
        if not WoW.IsPublic(name) or type(name) ~= "string" or name == "" or name:find("[|\r\n]") then return end
        local key = name:lower()
        if not seen[key] then
            choices[#choices + 1] = {name = name, spellID = ValidID(spellID) and spellID or nil, icon = SafeIcon(icon)}
            seen[key] = true
        end
    end
    if kind == "tracking" then
        for key, info in pairs(Tracking()) do
            if type(key) == "string" then Add(info.name, info.spellID, info.texture) end
        end
    elseif kind == "aura" then
        for index = 1, FormCount() or 0 do
            local name, _, spellID, icon = FormInfo(index)
            Add(name, spellID, icon)
        end
    else
        local forms = Forms()
        for index = 1, 255 do
            local aura = WoW.ReadValue(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
            if type(aura) ~= "table" then break end
            if WoW.IsPublic(aura.name) and type(aura.name) == "string" and not forms[aura.name:lower()] then
                Add(aura.name, aura.spellId, aura.icon)
            end
        end
    end
    table.sort(choices, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    if #choices == 0 then
        status:SetText(kind == "tracking" and L("Aucun suivi disponible.") or (kind == "aura" and L("Aucune aura ou posture.") or L("Active le buff, puis rouvre le menu.")))
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:SetScrollMode(320)
        root:CreateTitle(labels[kind])
        for _, choice in ipairs(choices) do
            local effect = choice
            root:CreateButton(effect.name, function() AddEffect(effect.name, kind, effect.spellID, effect.icon) end)
        end
    end)
end

local function Place()
    if Blocked() then
        ns.UI.Notify(L("Indisponible en combat ou à la mort."))
        return
    end
    return ns.UI.StartLayout("reminders")
end

local function Preview(forLayout)
    forLayout = forLayout == true
    if Blocked() then return false, L("Indisponible en combat ou à la mort.") end
    testMode = forLayout == true and "layout" or "preview"
    reminder:EnableMouse(not forLayout)
    reminder:SetFrameStrata(forLayout and "HIGH" or "DIALOG")
    Update()
    return true
end

local function BuildAppearance(body, scroll)
    local appearanceBody = body
    local refreshers, syncing = {}, false
    local inherited = {font = true, fontSize = true, titleSize = true, gap = true, padding = true,
        border = true, borderSize = true, backgroundAlpha = true, background = true,
        borderColor = true, textColor = true, titleColor = true}
    local function Inherited(control, key)
        if not inherited[key] then return end
        refreshers[#refreshers + 1] = function()
            local own = ns.UI.IsOverride("reminders")
            control:SetEnabled(own)
            control:SetAlpha(own and 1 or .5)
        end
    end
    local function Text(text, x, y, font)
        local label = body:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
        label:SetPoint("TOPLEFT", x, y); label:SetPoint("TOPRIGHT", -16, y); label:SetJustifyH("LEFT"); label:SetText(text)
        return label
    end
    local function Button(name, text, x, y, action)
        local button = CreateFrame("Button", "ArkannsQOLAppearance" .. name, body, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y); button:SetSize(250, 26); button:SetText(text)
        button:SetScript("OnClick", action)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        return button
    end
    local note = Text(L("Les réglages grisés utilisent le thème commun."), 16, -44, "GameFontHighlightSmall")
    local function Changed()
        note:SetText(L("Les réglages grisés utilisent le thème commun."))
        if not testMode and appearanceBody:IsVisible() then Preview() end
        Update()
        if appearanceRefresh then appearanceRefresh() end
    end
    local function Choice(key, label, x, y)
        local caption = Text(label, x, y)
        local button = Button(key, "", x, y - 22, function(self)
            if not HasMenus() then note:SetText(L("Menu indisponible.")); return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle(label)
                for _, option in ipairs(choices[key]) do
                    local value = option[1]
                    root:CreateButton(option[2], function() db.appearance[key] = value; Changed() end)
                end
            end)
        end)
        Inherited(button, key)
        refreshers[#refreshers + 1] = function()
            for _, option in ipairs(choices[key]) do if option[1] == db.appearance[key] then button:SetText(option[2]) end end
        end
        return function(y)
            caption:ClearAllPoints(); caption:SetPoint("TOPLEFT", x, -y); caption:SetPoint("TOPRIGHT", -16, -y)
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", x, -y - 22)
        end
    end
    local function Slider(key, label, x, y, suffix)
        local caption = Text("", x, y)
        caption:SetWidth(250)
        local slider = CreateFrame("Slider", "ArkannsQOLAppearance" .. key, body, "BackdropTemplate")
        slider:SetPoint("TOPLEFT", x, y - 26); slider:SetSize(250, 18)
        slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(ranges[key][1], ranges[key][2])
        slider:SetValueStep(1); slider:SetObeyStepOnDrag(true); slider:EnableMouse(true)
        slider:SetBackdrop({bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", edgeSize = 8})
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); slider:GetThumbTexture():SetSize(32, 32)
        slider:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            db.appearance[key] = math.max(ranges[key][1], math.min(ranges[key][2], math.floor(value + 0.5)))
            Changed()
        end)
        Inherited(slider, key)
        refreshers[#refreshers + 1] = function()
            slider:SetValue(db.appearance[key]); caption:SetText(L("%s : %d%s"):format(label, db.appearance[key], suffix or ""))
        end
        return function(y, shown, left)
            left = left or x
            caption:ClearAllPoints(); caption:SetPoint("TOPLEFT", left, -y)
            slider:ClearAllPoints(); slider:SetPoint("TOPLEFT", left, -y - 26)
            caption:SetShown(shown); slider:SetShown(shown)
        end
    end
    local function Check(key, label, x, y)
        local check = CreateFrame("CheckButton", "ArkannsQOLAppearance" .. key, body, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x - 4, y)
        local caption = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        caption:SetPoint("LEFT", check, "RIGHT", 2, 0); caption:SetText(label); check:SetFontString(caption)
        check:SetScript("OnClick", function(self) db.appearance[key] = self:GetChecked() == true; Changed() end)
        Inherited(check, key)
        refreshers[#refreshers + 1] = function() check:SetChecked(db.appearance[key]) end
    end
    local function Input(key, label, x, y, color)
        local function SavedText()
            return color and db.appearance[key] or TitleText(db.appearance)
        end
        Text(label, x, y)
        local input = CreateFrame("EditBox", "ArkannsQOLAppearance" .. key, body, "InputBoxTemplate")
        input:SetPoint("TOPLEFT", x + 6, y - 24); input:SetSize(color and 180 or 250, 26)
        Inherited(input, key)
        input:SetAutoFocus(false); input:SetMaxLetters(color and 7 or 48)
        local swatch
        if color then
            local picker = CreateFrame("Button", "ArkannsQOLAppearancePicker" .. key, body)
            picker:SetPoint("TOPLEFT", x + 206, y - 24); picker:SetSize(26, 26)
            Inherited(picker, key)
            swatch = picker:CreateTexture(nil, "ARTWORK"); swatch:SetAllPoints()
            picker:SetScript("OnClick", function()
                if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
                ColorPickerFrame:Hide()
                local previous = db.appearance[key]
                local r, g, b = RGB(previous)
                ColorPickerFrame:SetupColorPickerAndShow({r = r, g = g, b = b, hasOpacity = false,
                    swatchFunc = function()
                        local red, green, blue = ColorPickerFrame:GetColorRGB()
                        db.appearance[key] = string.format("%02X%02X%02X", math.floor(red * 255 + 0.5), math.floor(green * 255 + 0.5), math.floor(blue * 255 + 0.5))
                        input:SetText(db.appearance[key]); Changed()
                    end,
                    cancelFunc = function() db.appearance[key] = previous; input:SetText(previous); Changed() end})
            end)
        end
        local function Save(self)
            local value = self:GetText():match("^%s*(.-)%s*$")
            if color then value = value:gsub("^#", ""):upper() end
            if (color and value:match("^%x%x%x%x%x%x$")) or (not color and #value > 0 and #value <= 120 and not value:find("[|\r\n]")) then
                if not color then
                    if value == SavedText() then return end
                    db.appearance.customTitle = true
                end
                db.appearance[key] = value; Changed()
            else
                self:SetText(SavedText())
                note:SetText(color and L("Code hex invalide. Exemple : FFCC44.") or L("Titre : 1 à 48 caractères, sans balises."))
            end
        end
        input:SetScript("OnEnterPressed", function(self) Save(self); self:ClearFocus() end)
        input:SetScript("OnEditFocusLost", Save)
        input:SetScript("OnEscapePressed", function(self) self:SetText(SavedText()); self:ClearFocus() end)
        refreshers[#refreshers + 1] = function()
            -- Do not replace an unfinished title/color while another control refreshes.
            if not input:HasFocus() then input:SetText(SavedText()) end
            if swatch then swatch:SetColorTexture(RGB(db.appearance[key])) end
        end
    end
    Text(L("Apparence"), 16, -16, "GameFontNormalLarge")
    local override = Button("Override", "", 16, -48, function()
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("reminders", not ns.UI.IsOverride("reminders")) end
        Changed()
    end)
    refreshers[#refreshers + 1] = function()
        override:SetText(ns.UI.IsOverride("reminders") and L("Apparence personnalisée") or L("Thème commun"))
    end
    note:ClearAllPoints(); note:SetPoint("TOPLEFT", 16, -84); note:SetPoint("TOPRIGHT", -16, -84)
    Text(L("Thème personnalisé"), 16, -128)
    local themeButton = Button("Theme", L("Choisir…"), 16, -150, function(self)
        if not HasMenus() then note:SetText(L("Menu indisponible.")); return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle(L("Thèmes"))
            for _, theme in ipairs(themes) do
                local selected = theme
                root:CreateButton(theme[1], function()
                    for _, key in ipairs({"font", "fontSize", "titleSize", "outline", "background", "backgroundAlpha",
                        "border", "borderSize", "borderColor", "textColor", "titleColor", "shadow"}) do
                        db.appearance[key] = selected[2][key]
                        if db.appearance[key] == nil then db.appearance[key] = defaults[key] end
                    end
                    Changed()
                end)
            end
        end)
    end)
    Inherited(themeButton, "font")
    Slider("fontSize", L("Taille du texte"), 16, -194, " px")
    local opacity = Slider("backgroundAlpha", L("Opacité du fond"), 16, -258, " %")
    local frameWidth = Slider("width", L("Largeur"), 16, -322, " px")
    local previewButton = Button("Preview", L("Aperçu"), 16, -386, function()
        if testMode then EndTest(); return end
        if Blocked() then
            note:SetText(L("Indisponible en combat ou à la mort.")); return
        end
        Preview()
        Changed()
    end)
    refreshers[#refreshers + 1] = function() previewButton:SetText(testMode and L("Arrêter l’aperçu") or L("Aperçu")) end
    local advanced = CreateFrame("Frame", nil, appearanceBody)
    advanced:Hide()
    local Layout
    local advancedButton = Button("Advanced", L("Personnalisation avancée"), 16, -426, function(self)
        advanced:SetShown(not advanced:IsShown())
        self:SetText(advanced:IsShown() and L("Masquer la personnalisation avancée") or L("Personnalisation avancée"))
        Layout()
    end)
    local layoutGroup = CreateFrame("Frame", nil, advanced); body = layoutGroup
    Text(L("Cadre"), 0, 0)
    Choice("layout", L("Disposition"), 0, -26)
    local columns = Slider("columns", L("Colonnes (grille)"), 0, -86)
    local gap = Slider("gap", L("Espacement"), 0, -148, " px")
    local padding = Slider("padding", L("Marges"), 0, -210, " px")
    local align = Choice("align", L("Alignement"), 0, -272)
    local textGroup = CreateFrame("Frame", nil, advanced); body = textGroup
    Text(L("Texte et icônes"), 0, 0)
    Choice("font", L("Police"), 0, -26)
    Choice("outline", L("Contour"), 0, -86)
    Check("shadow", L("Ombre du texte"), 0, -136)
    Check("showTitle", L("Afficher le titre"), 0, -170)
    Input("title", L("Titre personnalisé"), 0, -210)
    Slider("titleSize", L("Taille du titre"), 0, -272, " px")
    Check("showIcons", L("Afficher les icônes"), 0, -330)
    Slider("iconSize", L("Taille des icônes"), 0, -372, " px")
    local colorsGroup = CreateFrame("Frame", nil, advanced); body = colorsGroup
    Text(L("Couleurs"), 0, 0)
    Text(L("Couleurs : clic sur le carré ou code hex + Entrée."), 0, -26, "GameFontHighlightSmall")
    Input("background", L("Fond"), 0, -68, true)
    Input("textColor", L("Texte"), 0, -130, true)
    Input("titleColor", L("Titre"), 0, -192, true)
    local borderGroup = CreateFrame("Frame", nil, advanced); body = borderGroup
    Text(L("Bordure"), 0, 0)
    Choice("border", L("Type de bordure"), 0, -26)
    Slider("borderSize", L("Épaisseur de bordure"), 0, -86, " px")
    Input("borderColor", L("Bordure"), 0, -148, true)
    body = advanced
    local reset = Button("Defaults", L("Défauts de cette section"), 0, 0, function()
        ns.UI.Confirm(L("Rétablir l’apparence par défaut des rappels ?"), function()
            for key, value in pairs(defaults) do db.appearance[key] = value end
            ns.UI.SetOverride("reminders", false)
            Changed()
        end)
    end)
    local function Position(widget, x, y, width, height)
        widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", x, -y)
        if width then widget:SetWidth(width) end
        if height then widget:SetHeight(height) end
    end
    Layout = function()
        local width = math.max(1, appearanceBody:GetWidth() - 32)
        local wide = width >= 522
        local height = wide and 366 or 466
        Position(previewButton, wide and 282 or 16, wide and 48 or 386, wide and 210 or math.min(250, width))
        opacity(wide and 194 or 258, true, wide and 282 or 16)
        frameWidth(wide and 258 or 322, true)
        Position(advancedButton, 16, height - 38, math.min(295, width))
        if advanced:IsShown() then
            local groupWidth = wide and (width - 20) / 2 or width
            local grid = db.appearance.layout == "grid" and not db.grouped
            local afterLayout = grid and 148 or 86
            columns(86, grid)
            gap(afterLayout, true)
            padding(afterLayout + 62, true)
            align(afterLayout + 124)
            local leftHeight = afterLayout + 190
            local rightX = wide and groupWidth + 20 or 0
            local textY = wide and 0 or leftHeight
            local colorsY = textY + 440
            local borderY = colorsY + (wide and 0 or 262)
            local resetY = math.max(colorsY + 262, borderY + 222)
            Position(layoutGroup, 0, 0, groupWidth, leftHeight)
            Position(textGroup, rightX, textY, groupWidth, 440)
            Position(colorsGroup, 0, colorsY, groupWidth, 262)
            Position(borderGroup, rightX, borderY, groupWidth, 222)
            Position(reset, 0, resetY)
            Position(advanced, 16, height, width, resetY + 38)
            height = height + resetY + 38
        end
        appearanceBody:SetHeight(height)
        ns.UI.ClampScroll(scroll, height)
    end
    scroll:HookScript("OnSizeChanged", Layout)
    appearanceRefresh = function()
        syncing = true
        for _, refresh in ipairs(refreshers) do refresh() end
        Layout()
        syncing = false
    end
    appearanceRefresh()
end

function ns.InitializeReminders(parentCategory)
    if type(ArkannsQOLRemindersDB) ~= "table" then ArkannsQOLRemindersDB = {} end
    db = ArkannsQOLRemindersDB
    NormalizeAppearance()
    NormalizeBehavior()
    for key, default in pairs({x = 0.5, y = 0.7}) do
        if type(db[key]) ~= "number" or db[key] ~= db[key] or db[key] < 0 or db[key] > 1 then db[key] = default end
    end

    reminder = CreateFrame("Frame", "ArkannsQOLReminder", UIParent, "BackdropTemplate")
    reminder:SetSize(400, 100)
    reminder:SetFrameStrata("HIGH")
    reminder:SetClampedToScreen(true)
    reminder:EnableMouse(false)
    message = reminder:CreateFontString("ArkannsQOLReminderText", "OVERLAY", "GameFontNormalLarge")
    reminderRows = {}
    reminder:SetScript("OnEnter", function() if db.compact and db.expandOnHover then expanded = true; Update() end end)
    reminder:SetScript("OnLeave", function() if expanded then expanded = false; Update() end end)
    reminder:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then EndTest() end
    end)
    testControls = CreateFrame("Frame", "ArkannsQOLReminderTestControls", reminder)
    testControls:SetPoint("TOPLEFT", 6, -4); testControls:SetPoint("TOPRIGHT", -6, -4); testControls:SetHeight(24)
    local testLabel = testControls:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    testLabel:SetPoint("LEFT", 4, 0); testLabel:SetText(L("Aperçu"))
    local close = CreateFrame("Button", "ArkannsQOLReminderTestClose", testControls, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 0, 0); close:SetSize(26, 26); close:SetScript("OnClick", EndTest)
    testControls:Hide()
    testControls:SetScript("OnHide", function() if testMode ~= "layout" then EndTest() end end)
    table.insert(UISpecialFrames, "ArkannsQOLReminderTestControls")
    RestorePosition()
    reminder:Hide()

    local settingsPanel = CreateFrame("Frame", "ArkannsQOLReminderSettings", UIParent, "BackdropTemplate")
    settingsPanel:Hide()
    if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(settingsPanel) end
    local function ScrollPage(name, height)
        local scroll = CreateFrame("ScrollFrame", name, settingsPanel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, -44); scroll:SetPoint("BOTTOMRIGHT", -28, 12)
        local body = CreateFrame("Frame", nil, scroll)
        body:SetSize(620, height); scroll:SetScrollChild(body)
        scroll:SetScript("OnSizeChanged", function(_, width) body:SetWidth(math.max(1, width)) end)
        return scroll, body
    end
    local effectsPage, panel = ScrollPage("ArkannsQOLEffectsPage", 700)
    local appearancePage, appearanceBody = ScrollPage("ArkannsQOLAppearancePage", 1080)
    local visibilityPage, visibilityBody = ScrollPage("ArkannsQOLReminderVisibility", 390)
    visibilityPage:Hide()
    appearancePage:Hide()
    local tabs, activePage = {}, effectsPage
    local function Tab(name, text, x, page)
        local button = CreateFrame("Button", name, settingsPanel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, -10); button:SetSize(190, 26); button:SetText(text)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        tabs[#tabs + 1] = button
        button:SetEnabled(page ~= activePage)
        button:SetScript("OnClick", function()
            activePage = page
            for _, tab in ipairs(tabs) do tab:SetEnabled(tab ~= button) end
            EndTest()
            effectsPage:SetShown(page == effectsPage); appearancePage:SetShown(page == appearancePage); visibilityPage:SetShown(page == visibilityPage)
            if page == appearancePage then Preview() end
            if appearanceRefresh then appearanceRefresh() end
        end)
    end
    Tab("ArkannsQOLEffectsTab", L("Fonctionnement"), 16, effectsPage)
    Tab("ArkannsQOLAppearanceTab", L("Apparence"), 216, appearancePage)
    Tab("ArkannsQOLReminderVisibilityTab", L("Visibilité"), 416, visibilityPage)
    local function LayoutTabs()
        local width = math.max(280, settingsPanel:GetWidth() - 32)
        local columns = width >= 450 and 3 or 1
        local size = (width - (columns - 1) * 8) / columns
        for index, button in ipairs(tabs) do
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", 16 + ((index - 1) % columns) * (size + 8), -10 - math.floor((index - 1) / columns) * 34)
            button:SetWidth(size)
        end
        for _, page in ipairs({effectsPage, appearancePage, visibilityPage}) do
            page:ClearAllPoints(); page:SetPoint("TOPLEFT", 0, -16 - math.ceil(3 / columns) * 34); page:SetPoint("BOTTOMRIGHT", -28, 12)
        end
    end
    settingsPanel:HookScript("OnSizeChanged", LayoutTabs)
    local function Text(text, y, font)
        local label = panel:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 16, y); label:SetPoint("TOPRIGHT", -16, y)
        label:SetJustifyH("LEFT"); label:SetText(text)
        return label
    end
    local function Button(name, text, x, y, callback)
        local button = CreateFrame("Button", name, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y); button:SetSize(190, 26); button:SetText(text)
        button:SetScript("OnClick", callback)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        return button
    end
    local heading = Text(L("Rappels d'effets"), -16, "GameFontNormalLarge")
    local scope = Text(L("Par personnage • Masqué en combat et à la mort."), -44)
    apiNotice = Text("", -72)
    enabled = CreateFrame("CheckButton", "ArkannsQOLReminderEnabled", panel, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 12, -82)
    local label = enabled:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", enabled, "RIGHT", 2, 0); label:SetText(L("Activer les rappels"))
    enabled:SetFontString(label)
    enabled:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() == true
        EndTest(); Update()
    end)
    local chooseButtons = {
        Button("ArkannsQOLChooseAura", L("+ Auras / postures"), 16, -120, function(self) ChooseEffect(self, "aura") end),
        Button("ArkannsQOLChooseBuff", L("+ Buffs"), 216, -120, function(self) ChooseEffect(self, "buff") end),
        Button("ArkannsQOLChooseTracking", L("+ Minicarte"), 416, -120, function(self) ChooseEffect(self, "tracking") end),
    }
    local effectsTitle = Text(L("Effets suivis"), -160, "GameFontNormal")
    list = CreateFrame("ScrollFrame", "ArkannsQOLEffectsList", panel, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 16, -184); list:SetPoint("TOPRIGHT", -36, -184); list:SetHeight(170)
    listBody = CreateFrame("Frame", nil, list)
    listBody:SetSize(580, 1)
    list:SetScrollChild(listBody)
    emptyList = Text(L("Aucun effet. Ajoute une aura, un buff ou un suivi."), -198)
    rows = {}
    manualInput = CreateFrame("EditBox", "ArkannsQOLManualInput", panel, "InputBoxTemplate")
    manualInput:SetPoint("TOPLEFT", 22, -370); manualInput:SetSize(370, 26)
    manualInput:SetAutoFocus(false); manualInput:SetMaxLetters(160)
    manualInput:SetScript("OnEnterPressed", AddManual)
    manualInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local addManual = Button("ArkannsQOLAddManual", L("Ajouter par nom / ID"), 416, -370, AddManual)
    status = Text("", -408)
    local manualHelp = Text(L("Buff absent du menu ? Active-le ou saisis son nom / ID."), -446)
    local behaviorControls = {}
    local function BehaviorCheck(key, text, y, onChange)
        local box = CreateFrame("CheckButton", "ArkannsQOLReminder_" .. key, panel, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 12, y)
        local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", box, "RIGHT", 2, 0); label:SetText(text); box:SetFontString(label)
        behaviorControls[#behaviorControls + 1] = function() box:SetChecked(db[key]) end
        box:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() == true
            if onChange then onChange() end
            Update()
        end)
        return box
    end
    local grouped = BehaviorCheck("grouped", L("Regrouper par type d'effet"), -496, function() appearanceRefresh() end)
    local priorityHelp = Text(L("Priorité : clique Haute, Normale ou Basse dans la liste."), -538)
    local behaviorDefaults = Button(nil, L("Défauts de cette section"), 16, -574, function()
        ns.UI.Confirm(L("Rétablir le regroupement et les priorités par défaut des rappels ?"), function()
            db.grouped = false
            for _, key in ipairs({"auras", "tracking"}) do for _, rule in ipairs(db[key]) do rule.priority = 2 end end
            for _, sync in ipairs(behaviorControls) do sync() end
            Refresh(); Update(); appearanceRefresh()
        end)
    end)
    local effectsBody = panel
    local function Position(widget, x, y)
        widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", x, -y)
    end
    local function TextBlock(widget, y, width)
        Position(widget, 16, y); widget:SetWidth(math.max(1, width - 32))
        return y + widget:GetStringHeight() + 8
    end
    layoutEffects = function()
        local width = effectsBody:GetWidth()
        local columns = width >= 500 and 3 or width >= 310 and 2 or 1
        local size = math.min(250, math.max(1, (width - 32 - (columns - 1) * 10) / columns))
        local y = TextBlock(heading, 16, width)
        Position(enabled, 12, y)
        y = TextBlock(scope, y + 32, width)
        if apiNotice:GetText() ~= "" then
            apiNotice:Show()
            y = TextBlock(apiNotice, y, width)
        else apiNotice:Hide() end
        chooseButtons[1]:SetEnabled(HasMenus() and HasForms() and true or false)
        chooseButtons[2]:SetEnabled(HasMenus() and HasBuffs() and true or false)
        chooseButtons[3]:SetEnabled(HasMenus() and HasTracking() and true or false)
        for index, button in ipairs(chooseButtons) do
            Position(button, 16 + ((index - 1) % columns) * (size + 10), y + math.floor((index - 1) / columns) * 34)
            button:SetWidth(size)
        end
        y = TextBlock(manualHelp, y + math.ceil(3 / columns) * 34, width)
        local inline = columns == 3
        Position(manualInput, 22, y); manualInput:SetWidth(math.max(1, width - (inline and 250 or 44)))
        Position(addManual, inline and width - 206 or 16, y + (inline and 0 or 34))
        y = y + (inline and 34 or 68)
        Position(status, 16, y); status:SetWidth(math.max(1, width - 32)); status:SetHeight(38)
        y = TextBlock(effectsTitle, y + 44, width)
        if list:IsShown() then
            y = TextBlock(priorityHelp, y, width)
            Position(list, 16, y); list:SetPoint("TOPRIGHT", -36, -y)
            listBody:SetWidth(math.max(1, width - 52))
            LayoutRows()
            y = y + list:GetHeight() + 8
        else
            ns.UI.ClampScroll(list, 0)
            y = TextBlock(emptyList, y, width)
        end
        priorityHelp:SetShown(list:IsShown())
        Position(grouped, 12, y)
        Position(behaviorDefaults, 16, y + 38)
        effectsBody:SetHeight(y + 78)
        ns.UI.ClampScroll(effectsPage, y + 78)
    end
    effectsBody:HookScript("OnSizeChanged", function(_, width)
        if width ~= effectsBody.layoutWidth then effectsBody.layoutWidth = width; layoutEffects() end
    end)
    panel = visibilityBody
    Text(L("Visibilité"), -16, "GameFontNormalLarge")
    local visibilityHelp = Text(L("Masqué en combat et à la mort. Aucun rappel pour un effet inconnu."), -50)
    local LayoutVisibility
    local compact = BehaviorCheck("compact", L("Mode compact : 2 effets"), -116, function() LayoutVisibility() end)
    local expand = BehaviorCheck("expandOnHover", L("Développer au survol"), -148)
    local limitButton = Button(nil, "", 16, -194, function(self)
        if not HasMenus() then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            for count = 1, 20 do
                local value = count
                root:CreateButton(L("Afficher %d"):format(value), function() db.visibleLimit = value; self:SetText(L("Limite : %d"):format(value)); Update() end)
            end
        end)
    end)
    local place = Button("ArkannsQOLAppearancePlace", L("Déplacer"), 16, -240, Place)
    local visibilityDefaults = Button(nil, L("Défauts de cette section"), 16, -332, function()
        ns.UI.Confirm(L("Rétablir la visibilité par défaut des rappels ?"), function()
            db.enabled, db.compact, db.expandOnHover, db.visibleLimit = true, false, true, 6
            EndTest()
            for _, sync in ipairs(behaviorControls) do sync() end
            limitButton:SetText(L("Limite : %d"):format(db.visibleLimit)); LayoutVisibility(); Refresh(); Update()
        end)
    end)
    local limitHelp = Text(L("Les effets restants sont indiqués par +N.\nL'aperçu disparaît à la fermeture des réglages."), -284)
    LayoutVisibility = function()
        local width = visibilityBody:GetWidth()
        local y = TextBlock(visibilityHelp, 50, width)
        Position(compact, 12, y)
        Position(expand, 28, y + 34); expand:SetShown(db.compact)
        y = y + (db.compact and 72 or 38)
        Position(limitButton, 16, y)
        y = TextBlock(limitHelp, y + 34, width)
        Position(place, 16, y)
        Position(visibilityDefaults, 16, y + 36)
        visibilityBody:SetHeight(y + 74)
        ns.UI.ClampScroll(visibilityPage, y + 74)
    end
    visibilityPage:HookScript("OnSizeChanged", LayoutVisibility)
    panel = effectsBody
    BuildAppearance(appearanceBody, appearancePage)
    settingsPanel:SetScript("OnShow", function()
        LayoutTabs()
        EndTest()
        panel:SetWidth(math.max(1, effectsPage:GetWidth()))
        appearanceBody:SetWidth(math.max(1, appearancePage:GetWidth()))
        Refresh(); status:SetText("")
        appearanceRefresh()
        for _, sync in ipairs(behaviorControls) do sync() end
        LayoutVisibility()
        limitButton:SetText(L("Limite : %d"):format(db.visibleLimit))
        if appearancePage:IsShown() then Preview() end
    end)
    settingsPanel:SetScript("OnHide", EndTest)
    category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, settingsPanel, L("Rappels d'effets"))
    ns.reminderCategory = category
    Refresh()

    if ns.RegisterModule then
        local function RefreshAll()
            Refresh(); Update(); appearanceRefresh()
            for _, sync in ipairs(behaviorControls) do sync() end
            LayoutVisibility()
            limitButton:SetText(L("Limite : %d"):format(db.visibleLimit))
        end
        local configKeys = {"enabled", "grouped", "compact", "expandOnHover", "visibleLimit", "x", "y"}
        ns.RegisterModule("reminders", {
            label = L("Rappels d'effets"), icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", category = function() return category end,
            frame = reminder, IsEnabled = function() return db.enabled end,
            SetEnabled = function(value) db.enabled = value == true; EndTest(); RefreshAll() end,
            Summary = function() return L("Effets surveillés : %d"):format(#db.auras + #db.tracking) end,
            Preview = Preview, StopPreview = EndTest, Refresh = RefreshAll,
            GetPosition = function() return db.x, db.y end,
            SetPosition = function(x, y)
                if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then return end
                db.x, db.y = math.max(0, math.min(1, x)), math.max(0, math.min(1, y)); RestorePosition(); Update()
            end,
            ExportSettings = function()
                local result = {appearance = {}, auras = {}, tracking = {}}
                for _, key in ipairs(configKeys) do result[key] = db[key] end
                for key in pairs(defaults) do result.appearance[key] = db.appearance[key] end
                for _, key in ipairs({"auras", "tracking"}) do
                    for _, rule in ipairs(db[key]) do
                        result[key][#result[key] + 1] = {name = rule.name, kind = rule.kind, priority = rule.priority, spellID = rule.spellID, icon = rule.icon}
                    end
                end
                return result
            end,
            ProfileDisplay = function(config)
                if type(config.appearance) == "table" then
                    config.appearance.title = TitleText(config.appearance)
                end
            end,
            profileMigrations = {
                function(config)
                    if type(config.appearance) == "table" and config.appearance.customTitle == nil then
                        config.appearance.customTitle = false
                    end
                end,
            },
            ImportSettings = function(config)
                if type(config) ~= "table" then return false, L("Réglages des rappels invalides.") end
                EndTest()
                for _, key in ipairs(configKeys) do if config[key] ~= nil then db[key] = config[key] end end
                if type(config.appearance) == "table" then
                    if config.appearance.title ~= nil then db.appearance.customTitle = config.appearance.customTitle == true end
                    for key in pairs(defaults) do if config.appearance[key] ~= nil then db.appearance[key] = config.appearance[key] end end
                end
                for _, key in ipairs({"auras", "tracking"}) do
                    if type(config[key]) == "table" then
                        local rules = {}
                        for _, rule in ipairs(config[key]) do
                            if type(rule) == "table" then
                                rules[#rules + 1] = {name = rule.name, kind = rule.kind, priority = rule.priority, spellID = rule.spellID, icon = rule.icon}
                            end
                        end
                        for index in pairs(db[key]) do db[key][index] = nil end
                        for index, rule in ipairs(rules) do db[key][index] = rule end
                    end
                end
                NormalizeAppearance(); NormalizeBehavior()
                for key, default in pairs({x = 0.5, y = 0.7}) do
                    if type(db[key]) ~= "number" or db[key] ~= db[key] or db[key] < 0 or db[key] > 1 then db[key] = default end
                end
                EndTest(); RestorePosition(); RefreshAll()
                return true
            end,
        })
    end

    events = CreateFrame("Frame", "ArkannsQOLReminderEvents")
    observingEffects = false
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_DEAD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_LOGOUT", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" and (not WoW.IsPublic(unit) or unit ~= "player") then return end
        if event == "PLAYER_LOGOUT" then EndTest(); return end
        if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then RestorePosition() end
        Update()
    end)
    SyncEffectEvents(db.enabled and (#db.auras > 0 or #db.tracking > 0))
end
