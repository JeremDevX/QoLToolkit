local _, ns = ...
local Model, WoW = ns.AuraReminderModel, ns.WoW
local db, reminder, message, category, manualInput, status, enabled, list, listBody, emptyList
local apiNotice
local rows = {}
local testMode, testControls
local reminderRows = {}
local appearanceRefresh
local expanded, effectiveAppearance, activeStyle = false, nil, nil
local RestorePosition
local events, observingEffects
local effectEvents = {"UNIT_AURA", "MINIMAP_UPDATE_TRACKING", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "SPELLS_CHANGED"}
local priorityLabels = {[1] = "Haute", [2] = "Normale", [3] = "Basse"}
local labels = {aura = "Auras / postures", buff = "Buffs", tracking = "Minicarte"}
local order = Model.KindOrder

local defaults = {
    layout = "vertical", columns = 2, width = 400, gap = 6, padding = 12,
    font = "standard", fontSize = 16, titleSize = 18, outline = "", align = "LEFT",
    iconSize = 28, showIcons = true, showTitle = true, title = "À réactiver",
    background = "140803", backgroundAlpha = 85, border = "tooltip", borderSize = 12,
    borderColor = "FFCC44", textColor = "FF6633", titleColor = "FFCC44", shadow = true,
}
local ranges = {columns = {1, 6}, width = {180, 1000}, gap = {0, 30}, padding = {4, 40},
    fontSize = {10, 32}, titleSize = {10, 40}, iconSize = {16, 64}, backgroundAlpha = {0, 100}, borderSize = {1, 24}}
local choices = {
    layout = {{"vertical", "Liste verticale"}, {"horizontal", "Ligne"}, {"grid", "Grille"}},
    font = {{"standard", "Classique"}, {"narrow", "Arial"}, {"fantasy", "Morpheus"}},
    outline = {{"", "Aucun contour"}, {"OUTLINE", "Contour fin"}, {"THICKOUTLINE", "Contour épais"}},
    align = {{"LEFT", "Gauche"}, {"CENTER", "Centre"}, {"RIGHT", "Droite"}},
    border = {{"none", "Sans bordure"}, {"tooltip", "Classique"}, {"flat", "Trait simple"}},
}
local themes = {
    {"Classique", {}},
    {"Sobre", {background = "101820", backgroundAlpha = 80, textColor = "FFFFFF", titleColor = "82D8FF", borderColor = "477082", border = "flat", borderSize = 1}},
    {"Lumineux", {background = "EEE8D8", backgroundAlpha = 95, textColor = "302820", titleColor = "943600", borderColor = "806B50", border = "flat", borderSize = 2, shadow = false}},
    {"Compact", {width = 280, fontSize = 12, titleSize = 14, iconSize = 20, gap = 2, padding = 6, background = "101010", textColor = "FFFFFF", border = "none"}},
}

local function ValidID(value)
    return WoW.IsFiniteNumber(value) and value >= 1 and value <= 2147483647 and value == math.floor(value)
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
    if remaining > 0 then result[#result + 1] = {name = "+" .. remaining .. " restants", heading = true} end
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
    if reminder.EnableMouseMotion then reminder:EnableMouseMotion(testMode ~= nil or (db.compact and db.expandOnHover)) end
    local edge = a.border == "tooltip" and "Interface\\Tooltips\\UI-Tooltip-Border" or (a.border == "flat" and "Interface\\Buttons\\WHITE8X8" or nil)
    reminder:SetWidth(a.width)
    reminder:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = edge, edgeSize = a.borderSize,
        insets = {left = 0, right = 0, top = 0, bottom = 0}})
    local r, g, b = RGB(a.background)
    reminder:SetBackdropColor(r, g, b, a.backgroundAlpha / 100)
    if edge then reminder:SetBackdropBorderColor(RGB(a.borderColor)) end
    if activeStyle and ns.UI.StyleFrame then ns.UI.StyleFrame(reminder, "reminders") end
    message:ClearAllPoints()
    local testHeight = testMode and 26 or 0
    message:SetPoint("TOPLEFT", a.padding, -a.padding - testHeight)
    message:SetWidth(a.width - 2 * a.padding)
    StyleText(message, a.titleSize, a.titleColor)
    message:SetText(a.title)
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
    testControls:SetShown(testMode ~= nil)
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

local function EffectIcon(rule)
    if not rule.icon then
        local _, _, icon = Spell(rule.name)
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
            result[info.name:lower()] = {name = info.name, active = ActiveFlag(info.active),
                spellID = WoW.IsPublic(info.spellID) and info.spellID or nil, texture = WoW.IsPublic(info.texture) and info.texture or nil}
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
        local name, active = FormInfo(index)
        if name then
            local key = name:lower()
            if not forms[key] then forms[key] = {active = active} end
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

local function SavePosition()
    reminder:StopMovingOrSizing()
    local x, y = reminder:GetCenter()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if x and y and width > 0 and height > 0 then
        local scale = reminder:GetScale()
        db.x = math.max(0, math.min(1, x * scale / width))
        db.y = math.max(0, math.min(1, y * scale / height))
    end
    RestorePosition()
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
    if testMode == "place" then SavePosition() end
    testMode = nil -- Clear before Hide: OnHide also ends the test (including Escape).
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
                if #samples < 8 then samples[#samples + 1] = {name = rule.name, icon = EffectIcon(rule), priority = rule.priority, kind = key == "tracking" and "tracking" or rule.kind or "buff"} end
            end
        end
        if #samples == 0 then
            samples = {{name = "Aura de dévotion", icon = 135893, kind = "aura", priority = 1}, {name = "Bénédiction de puissance", icon = 135906, kind = "buff", priority = 1}, {name = "Bénédiction de sagesse", icon = 135970, kind = "buff"}, {name = "Détection des minerais", icon = 136025, kind = "tracking"}, {name = "Détection des herbes", icon = 133939, kind = "tracking"}, {name = "Élixir", icon = 134838, kind = "buff"}, {name = "Nourriture", icon = 133971, kind = "buff", priority = 3}}
        end
        Render(samples)
        return
    end
    local observed = {tracking = #db.tracking > 0 and Tracking() or {}}
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

local function Kind(rule, key, forms)
    if key == "tracking" then return "tracking" end
    if rule.kind == "aura" or forms[rule.name:lower()] then return "aura" end
    return "buff"
end

local Refresh
Refresh = function()
    local entries = {}
    local tracking = #db.tracking > 0 and Tracking() or {}
    local forms = #db.auras > 0 and Forms() or {}
    local unavailable = {}
    if not HasSpellLookup() then unavailable[#unavailable + 1] = "recherche par ID" end
    if not HasForms() then unavailable[#unavailable + 1] = "auras / postures" end
    if not HasBuffs() then unavailable[#unavailable + 1] = "buffs" end
    if not HasTracking() then unavailable[#unavailable + 1] = "minicarte" end
    if not HasMenus() then unavailable[#unavailable + 1] = "menus" end
    apiNotice:SetText(#unavailable > 0 and "Indisponible : " .. table.concat(unavailable, ", ") or "")
    for _, key in ipairs({"auras", "tracking"}) do
        for _, rule in ipairs(db[key]) do
            entries[#entries + 1] = {rule = rule, key = key, kind = Kind(rule, key, forms)}
        end
    end
    table.sort(entries, function(a, b)
        if a.kind ~= b.kind then return order[a.kind] < order[b.kind] end
        return a.rule.name:lower() < b.rule.name:lower()
    end)
    for index, entry in ipairs(entries) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", "ArkannsQOLEffectRow" .. index, listBody)
            row:SetHeight(36)
            row:SetPoint("TOPLEFT", 0, -(index - 1) * 38)
            row:SetPoint("TOPRIGHT", 0, -(index - 1) * 38)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(28, 28); row.icon:SetPoint("LEFT", 4, 0)
            row.delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.delete:SetSize(26, 26); row.delete:SetPoint("RIGHT", -4, 0); row.delete:SetText("×")
            row.kindLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            row.priority = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.priority:SetSize(78, 26); row.priority:SetPoint("RIGHT", row.delete, "LEFT", -6, 0)
            row.priority:SetScript("OnClick", function()
                row.rule.priority = (row.rule.priority or 2) % 3 + 1; Refresh(); Update()
            end)
            if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(row.priority); ns.UI.StyleButton(row.delete) end
            row.kindLabel:SetWidth(96); row.kindLabel:SetPoint("RIGHT", row.priority, "LEFT", -6, 0)
            row.kindLabel:SetJustifyH("RIGHT")
            row.nameLabel = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            row.nameLabel:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
            row.nameLabel:SetPoint("RIGHT", row.kindLabel, "LEFT", -10, 0)
            row.nameLabel:SetJustifyH("LEFT"); row.nameLabel:SetWordWrap(false)
            row.delete:SetScript("OnClick", function()
                for itemIndex, rule in ipairs(db[row.key]) do
                    if rule == row.rule then
                        table.remove(db[row.key], itemIndex)
                        status:SetText(rule.name .. " : rappel supprimé.")
                        Refresh(); Update(); break
                    end
                end
            end)
            rows[index] = row
        end
        row.rule, row.key = entry.rule, entry.key
        local _, _, spellIcon = Spell(entry.rule.name)
        local track = entry.key == "tracking" and tracking[entry.rule.name:lower()]
        local icon = track and track.texture or entry.rule.icon or spellIcon
        row.icon:SetTexture(SafeIcon(icon))
        row.nameLabel:SetText(entry.rule.name)
        row.kindLabel:SetText(labels[entry.kind])
        row.priority:SetText(priorityLabels[entry.rule.priority or 2])
        row:Show()
    end
    for index = #entries + 1, #rows do rows[index]:Hide() end
    listBody:SetHeight(math.max(1, #entries * 38))
    list:SetVerticalScroll(math.min(list:GetVerticalScroll(), math.max(0, #entries * 38 - list:GetHeight())))
    emptyList:SetShown(#entries == 0)
    enabled:SetChecked(db.enabled)
end

local function AddEffect(name, kind, spellID, icon)
    spellID = ValidID(spellID) and spellID or nil
    icon = ValidID(icon) and icon or nil
    local key = kind == "tracking" and "tracking" or "auras"
    for _, rule in ipairs(db[key]) do
        if rule.name:lower() == name:lower() then
            -- Enrich older saved entries without creating duplicates.
            rule.kind, rule.icon = kind, icon or rule.icon
            Refresh(); status:SetText(name .. " est déjà dans la liste.")
            return
        end
    end
    db[key][#db[key] + 1] = {name = name, kind = kind, spellID = spellID, icon = icon, priority = 2}
    Refresh(); Update()
    status:SetText(name .. " : rappel ajouté.")
end

local function AddManual()
    local value = manualInput:GetText():match("^%s*(.-)%s*$")
    if value == "" or #value > 160 or value:find("[|\r\n]") then
        status:SetText("Nom exact ou ID du sort requis."); return
    end
    local id = tonumber(value)
    if id and (id ~= id or id < 1 or id > 2147483647 or id ~= math.floor(id)) then
        status:SetText("ID de sort invalide."); return
    end
    if id and not HasSpellLookup() then status:SetText("Recherche par ID indisponible."); return end
    local name, spellID, icon = Spell(id or value)
    if id and not name then status:SetText("Sort introuvable."); return end
    name = id and name or value
    local track = Tracking()[name:lower()]
    local forms = not track and Forms()
    local kind = track and "tracking" or (forms[name:lower()] and "aura" or "buff")
    if track then icon = track.texture or icon end
    AddEffect(name, kind, spellID, icon)
    manualInput:SetText(""); manualInput:ClearFocus()
end

local function ChooseEffect(owner, kind)
    if Blocked() then
        status:SetText("Indisponible en combat ou à la mort.")
        return
    end
    if not HasMenus() then status:SetText("Menu indisponible. Ajoute l’effet par nom."); return end
    if (kind == "tracking" and not HasTracking()) or (kind == "aura" and not HasForms())
        or (kind == "buff" and not HasBuffs()) then
        status:SetText(labels[kind] .. " : lecture indisponible.")
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
        for _, info in pairs(Tracking()) do Add(info.name, info.spellID, info.texture) end
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
        status:SetText(kind == "tracking" and "Aucun suivi disponible." or (kind == "aura" and "Aucune aura ou posture." or "Active le buff, puis rouvre le menu."))
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
        status:SetText("Indisponible en combat ou à la mort.")
        return
    end
    EndTest()
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    testMode = "place"
    reminder:EnableMouse(true)
    reminder:SetFrameStrata("FULLSCREEN_DIALOG")
    RestorePosition()
    Update()
end

local function Preview()
    if Blocked() then return end
    testMode = "preview"
    reminder:EnableMouse(true); reminder:SetFrameStrata("FULLSCREEN_DIALOG"); Update()
end

local function BuildAppearance(body, visibilityBody)
    local refreshers, syncing = {}, false
    local function Text(text, x, y, font)
        local label = body:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
        label:SetPoint("TOPLEFT", x, y); label:SetWidth(590 - x); label:SetJustifyH("LEFT"); label:SetText(text)
        return label
    end
    local function Button(name, text, x, y, action)
        local button = CreateFrame("Button", "ArkannsQOLAppearance" .. name, body, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y); button:SetSize(250, 26); button:SetText(text)
        button:SetScript("OnClick", action)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        return button
    end
    local note = Text("Aperçu immédiat • Données de jeu conservées.", 16, -44, "GameFontHighlightSmall")
    local function Changed()
        note:SetText("Aperçu immédiat • Données de jeu conservées.")
        if not testMode and body:IsVisible() then Preview() end
        Update()
        if appearanceRefresh then appearanceRefresh() end
    end
    local function Choice(key, label, x, y)
        Text(label, x, y)
        local button = Button(key, "", x, y - 22, function(self)
            if not HasMenus() then note:SetText("Menu indisponible."); return end
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateTitle(label)
                for _, option in ipairs(choices[key]) do
                    local value = option[1]
                    root:CreateButton(option[2], function() db.appearance[key] = value; Changed() end)
                end
            end)
        end)
        refreshers[#refreshers + 1] = function()
            for _, option in ipairs(choices[key]) do if option[1] == db.appearance[key] then button:SetText(option[2]) end end
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
        refreshers[#refreshers + 1] = function()
            slider:SetValue(db.appearance[key]); caption:SetText(label .. " : " .. db.appearance[key] .. (suffix or ""))
        end
    end
    local function Check(key, label, x, y)
        local check = CreateFrame("CheckButton", "ArkannsQOLAppearance" .. key, body, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", x - 4, y)
        local caption = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        caption:SetPoint("LEFT", check, "RIGHT", 2, 0); caption:SetText(label); check:SetFontString(caption)
        check:SetScript("OnClick", function(self) db.appearance[key] = self:GetChecked() == true; Changed() end)
        refreshers[#refreshers + 1] = function() check:SetChecked(db.appearance[key]) end
    end
    local function Input(key, label, x, y, color)
        Text(label, x, y)
        local input = CreateFrame("EditBox", "ArkannsQOLAppearance" .. key, body, "InputBoxTemplate")
        input:SetPoint("TOPLEFT", x + 6, y - 24); input:SetSize(color and 180 or 554, 26)
        input:SetAutoFocus(false); input:SetMaxLetters(color and 7 or 48)
        local swatch
        if color then
            local picker = CreateFrame("Button", "ArkannsQOLAppearancePicker" .. key, body)
            picker:SetPoint("TOPLEFT", x + 206, y - 24); picker:SetSize(26, 26)
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
                db.appearance[key] = value; Changed()
            else
                self:SetText(db.appearance[key])
                note:SetText(color and "Code hex invalide. Exemple : FFCC44." or "Titre : 1 à 48 caractères, sans balises.")
            end
        end
        input:SetScript("OnEnterPressed", function(self) Save(self); self:ClearFocus() end)
        input:SetScript("OnEditFocusLost", Save)
        input:SetScript("OnEscapePressed", function(self) self:SetText(db.appearance[key]); self:ClearFocus() end)
        refreshers[#refreshers + 1] = function()
            -- Do not replace an unfinished title/color while another control refreshes.
            if not input:HasFocus() then input:SetText(db.appearance[key]) end
            if swatch then swatch:SetColorTexture(RGB(db.appearance[key])) end
        end
    end
    Text("Apparence", 16, -16, "GameFontNormalLarge")
    local override = Button("Override", "", 326, -12, function()
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("reminders", not ns.UI.IsOverride("reminders")) end
        Changed()
    end)
    refreshers[#refreshers + 1] = function()
        override:SetText(ns.UI and ns.UI.IsOverride and ns.UI.IsOverride("reminders") and "Apparence personnalisée" or "Apparence commune")
    end
    Text("Thème", 16, -84)
    Button("Theme", "Choisir…", 16, -106, function(self)
        if not HasMenus() then note:SetText("Menu indisponible."); return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateTitle("Thèmes")
            for _, theme in ipairs(themes) do
                local selected = theme
                root:CreateButton(theme[1], function()
                    for key in pairs(defaults) do db.appearance[key] = defaults[key] end
                    for key, value in pairs(selected[2]) do db.appearance[key] = value end
                    Changed()
                end)
            end
        end)
    end)
    local previewButton = Button("Preview", "Tester", 326, -106, function()
        if testMode then EndTest(); return end
        if Blocked() then
            note:SetText("Indisponible en combat ou à la mort."); return
        end
        testMode = "preview"
        reminder:EnableMouse(true)
        reminder:SetFrameStrata("FULLSCREEN_DIALOG")
        Changed()
    end)
    refreshers[#refreshers + 1] = function() previewButton:SetText(testMode and "Fermer le test" or "Tester") end
    Text("Cadre", 16, -154, "GameFontNormalLarge")
    Choice("layout", "Disposition", 16, -182); Choice("align", "Alignement", 326, -182)
    Slider("width", "Largeur", 16, -246, " px"); Slider("columns", "Colonnes (grille)", 326, -246)
    Slider("gap", "Espacement", 16, -308, " px"); Slider("padding", "Marges", 326, -308, " px")
    Text("Texte et icônes", 16, -376, "GameFontNormalLarge")
    Choice("font", "Police", 16, -402); Choice("outline", "Contour", 326, -402)
    Slider("fontSize", "Taille du texte", 16, -466, " px"); Slider("titleSize", "Taille du titre", 326, -466, " px")
    Slider("iconSize", "Taille des icônes", 16, -528, " px"); Check("showIcons", "Afficher les icônes", 326, -548)
    Check("showTitle", "Afficher le titre", 16, -590); Check("shadow", "Ombre du texte", 326, -590)
    Input("title", "Titre personnalisé", 16, -636)
    Text("Couleurs : clic sur le carré ou code hex + Entrée.", 16, -692, "GameFontNormal")
    Input("background", "Fond", 16, -720, true); Input("textColor", "Texte", 326, -720, true)
    Input("titleColor", "Titre", 16, -790, true); Input("borderColor", "Bordure", 326, -790, true)
    Slider("backgroundAlpha", "Opacité du fond", 16, -860, " %"); Slider("borderSize", "Épaisseur de bordure", 326, -860, " px")
    Choice("border", "Bordure", 16, -924)
    local placeButton = Button("Place", "Déplacer", 326, -946, function()
        if Blocked() then note:SetText("Indisponible en combat ou à la mort."); return end
        Place()
    end)
    local centerButton = Button("Center", "Recentrer", 326, -986, function()
        if Blocked() then note:SetText("Indisponible en combat ou à la mort."); return end
        EndTest()
        db.x, db.y = 0.5, 0.7; Place()
    end)
    placeButton:SetParent(visibilityBody); placeButton:ClearAllPoints(); placeButton:SetPoint("TOPLEFT", 16, -240); placeButton:SetWidth(190)
    centerButton:SetParent(visibilityBody); centerButton:ClearAllPoints(); centerButton:SetPoint("TOPLEFT", 218, -240); centerButton:SetWidth(190)
    Button("Defaults", "Défauts de cette section", 16, -986, function()
        for key, value in pairs(defaults) do db.appearance[key] = value end
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("reminders", false) end
        Changed()
    end)
    Text("Réglages locaux : active Apparence personnalisée.\nGlisser : déplacer • ×, clic droit ou Échap : fermer le test.", 16, -1032, "GameFontHighlightSmall")
    appearanceRefresh = function()
        syncing = true
        for _, refresh in ipairs(refreshers) do refresh() end
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
    reminder:SetMovable(true)
    reminder:SetClampedToScreen(true)
    reminder:EnableMouse(false)
    reminder:RegisterForDrag("LeftButton")
    message = reminder:CreateFontString("ArkannsQOLReminderText", "OVERLAY", "GameFontNormalLarge")
    reminderRows = {}
    reminder:SetScript("OnDragStart", function(self) if testMode == "place" then self:StartMoving() end end)
    reminder:SetScript("OnDragStop", SavePosition)
    reminder:SetScript("OnEnter", function() if db.compact and db.expandOnHover then expanded = true; Update() end end)
    reminder:SetScript("OnLeave", function() if expanded then expanded = false; Update() end end)
    reminder:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then EndTest() end
    end)
    testControls = CreateFrame("Frame", "ArkannsQOLReminderTestControls", reminder)
    testControls:SetPoint("TOPLEFT", 6, -4); testControls:SetPoint("TOPRIGHT", -6, -4); testControls:SetHeight(24)
    local testLabel = testControls:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    testLabel:SetPoint("LEFT", 4, 0); testLabel:SetText("Test")
    local close = CreateFrame("Button", "ArkannsQOLReminderTestClose", testControls, "UIPanelButtonTemplate")
    close:SetPoint("RIGHT", 0, 0); close:SetSize(26, 22); close:SetText("×"); close:SetScript("OnClick", EndTest)
    testControls:Hide()
    testControls:SetScript("OnHide", EndTest)
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
    local visibilityPage, visibilityBody = ScrollPage("ArkannsQOLReminderVisibility", 360)
    visibilityPage:Hide()
    appearancePage:Hide()
    local function Tab(name, text, x, page)
        local button = CreateFrame("Button", name, settingsPanel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, -10); button:SetSize(190, 26); button:SetText(text)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        button:SetScript("OnClick", function()
            EndTest()
            effectsPage:SetShown(page == effectsPage); appearancePage:SetShown(page == appearancePage); visibilityPage:SetShown(page == visibilityPage)
            if page == appearancePage then Preview() end
            if appearanceRefresh then appearanceRefresh() end
        end)
    end
    Tab("ArkannsQOLEffectsTab", "Fonctionnement", 16, effectsPage)
    Tab("ArkannsQOLAppearanceTab", "Apparence", 216, appearancePage)
    Tab("ArkannsQOLReminderVisibilityTab", "Visibilité", 416, visibilityPage)
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
    Text("Rappels d'effets", -16, "GameFontNormalLarge")
    Text("Par personnage • Masqué en combat et à la mort.", -44)
    apiNotice = Text("", -72)
    enabled = CreateFrame("CheckButton", "ArkannsQOLReminderEnabled", panel, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", 12, -82)
    local label = enabled:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", enabled, "RIGHT", 2, 0); label:SetText("Activer les rappels")
    enabled:SetFontString(label)
    enabled:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked() == true
        EndTest(); Update()
    end)
    Button("ArkannsQOLChooseAura", "+ Auras / postures", 16, -120, function(self) ChooseEffect(self, "aura") end)
    Button("ArkannsQOLChooseBuff", "+ Buffs", 216, -120, function(self) ChooseEffect(self, "buff") end)
    Button("ArkannsQOLChooseTracking", "+ Minicarte", 416, -120, function(self) ChooseEffect(self, "tracking") end)
    Text("Effets suivis", -160, "GameFontNormal")
    list = CreateFrame("ScrollFrame", "ArkannsQOLEffectsList", panel, "UIPanelScrollFrameTemplate")
    list:SetPoint("TOPLEFT", 16, -184); list:SetPoint("TOPRIGHT", -36, -184); list:SetHeight(170)
    listBody = CreateFrame("Frame", nil, list)
    listBody:SetSize(580, 1)
    list:SetScrollChild(listBody)
    list:SetScript("OnSizeChanged", function(_, width) listBody:SetWidth(math.max(1, width)) end)
    emptyList = Text("Aucun effet. Ajoute une aura, un buff ou un suivi.", -198)
    rows = {}
    manualInput = CreateFrame("EditBox", "ArkannsQOLManualInput", panel, "InputBoxTemplate")
    manualInput:SetPoint("TOPLEFT", 22, -370); manualInput:SetSize(370, 26)
    manualInput:SetAutoFocus(false); manualInput:SetMaxLetters(160)
    manualInput:SetScript("OnEnterPressed", AddManual)
    manualInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    Button("ArkannsQOLAddManual", "Ajouter par nom / ID", 416, -370, AddManual)
    status = Text("", -408)
    Text("Buff absent du menu ? Active-le ou saisis son nom / ID.\nPlacement : onglet Visibilité.", -446)
    local behaviorControls = {}
    local function BehaviorCheck(key, text, y)
        local box = CreateFrame("CheckButton", "ArkannsQOLReminder_" .. key, panel, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 12, y)
        local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", box, "RIGHT", 2, 0); label:SetText(text); box:SetFontString(label)
        behaviorControls[#behaviorControls + 1] = function() box:SetChecked(db[key]) end
        box:SetScript("OnClick", function(self) db[key] = self:GetChecked() == true; Update() end)
    end
    BehaviorCheck("grouped", "Regrouper par type d'effet", -496)
    Text("Priorité : clique Haute, Normale ou Basse dans la liste.", -538)
    Button(nil, "Défauts de cette section", 16, -574, function()
        db.grouped = false
        for _, key in ipairs({"auras", "tracking"}) do for _, rule in ipairs(db[key]) do rule.priority = 2 end end
        for _, sync in ipairs(behaviorControls) do sync() end
        Refresh(); Update()
    end)
    local effectsBody = panel
    panel = visibilityBody
    enabled:SetParent(panel); enabled:ClearAllPoints(); enabled:SetPoint("TOPLEFT", 12, -48)
    Text("Visibilité", -16, "GameFontNormalLarge")
    Text("Masqué en combat et à la mort. Aucun rappel pour un effet inconnu.", -88)
    BehaviorCheck("compact", "Mode compact : 2 effets", -116)
    BehaviorCheck("expandOnHover", "Développer au survol", -148)
    local limitButton = Button(nil, "", 16, -194, function(self)
        if not HasMenus() then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            for count = 1, 20 do
                local value = count
                root:CreateButton(tostring(value) .. " effets", function() db.visibleLimit = value; self:SetText("Limite : " .. value); Update() end)
            end
        end)
    end)
    Button(nil, "Défauts de cette section", 218, -194, function()
        db.enabled, db.compact, db.expandOnHover, db.visibleLimit = true, false, true, 6
        EndTest(); db.x, db.y = 0.5, 0.7; RestorePosition()
        for _, sync in ipairs(behaviorControls) do sync() end
        limitButton:SetText("Limite : 6"); Refresh(); Update()
    end)
    Text("Les effets restants sont indiqués par +N.\nL'aperçu disparaît à la fermeture des réglages.", -284)
    panel = effectsBody
    BuildAppearance(appearanceBody, visibilityBody)
    settingsPanel:SetScript("OnShow", function()
        EndTest()
        panel:SetWidth(math.max(1, effectsPage:GetWidth()))
        appearanceBody:SetWidth(math.max(1, appearancePage:GetWidth()))
        listBody:SetWidth(math.max(1, list:GetWidth()))
        Refresh(); status:SetText("")
        appearanceRefresh()
        for _, sync in ipairs(behaviorControls) do sync() end
        limitButton:SetText("Limite : " .. db.visibleLimit)
        if appearancePage:IsShown() then Preview() end
    end)
    settingsPanel:SetScript("OnHide", EndTest)
    category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, settingsPanel, "Rappels d'effets")
    ns.reminderCategory = category
    Refresh()

    if ns.RegisterModule then
        local function RefreshAll()
            Refresh(); Update(); appearanceRefresh()
            for _, sync in ipairs(behaviorControls) do sync() end
            limitButton:SetText("Limite : " .. db.visibleLimit)
        end
        local configKeys = {"enabled", "grouped", "compact", "expandOnHover", "visibleLimit", "x", "y"}
        ns.RegisterModule("reminders", {
            label = "Rappels d'effets", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", category = function() return category end,
            frame = reminder, IsEnabled = function() return db.enabled end,
            SetEnabled = function(value) db.enabled = value == true; EndTest(); RefreshAll() end,
            Summary = function() return (#db.auras + #db.tracking) .. " effets surveillés" end,
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
            ImportSettings = function(config)
                if type(config) ~= "table" then return false, "Réglages des rappels invalides." end
                EndTest()
                for _, key in ipairs(configKeys) do if config[key] ~= nil then db[key] = config[key] end end
                if type(config.appearance) == "table" then
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
