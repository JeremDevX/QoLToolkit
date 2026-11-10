local addonName, ns = ...
local L = ns.L
local ReadAPI, Read = ns.WoW.Read, ns.WoW.ReadValue
local IsPublic, IsFiniteNumber = ns.WoW.IsPublic, ns.WoW.IsFiniteNumber

local title = L("Distance de la cible")
local directInterval, estimateInterval, hiddenInterval = .05, .10, .20
local maxProbeRange = 100 -- Ignore global or unlimited-range spells.
local refreshInterval = directInterval
local db, refreshSettings, badge, label, anchor, rejectedAnchor, spellRanges
local closeRange, mediumRange = 10, 30
local colors = {
    tooltip = {{.48, .92, .55}, {1, .82, .28}, {1, .45, .45}},
    text = {{1, 1, 1}, {1, 1, 1}, {1, 1, 1}},
    background = {{.10, .38, .19}, {.52, .34, .07}, {.47, .10, .10}},
}
local borderColor = {.82, .67, .37}
local backdrops = {
    framed = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    },
    background = {bgFile = "Interface\\Buttons\\WHITE8X8"},
    text = false,
}
local activeTier
local itemBands, checkingItemUnit
local blockedItemChecks = {}
local mouseoverEnabled, monitoring
local requestedItems = {}
local elapsed = 0
local driver = CreateFrame("Frame", "ArkannsQOLTargetDistanceEvents", UIParent)
driver:SetFrameStrata("HIGH")
driver:Hide()

-- Candidates from the Era/Forever hostile list, not assumed yard values.
-- https://github.com/WeakAuras/LibRangeCheck-3.0/blob/main/LibRangeCheck-3.0/LibRangeCheck-3.0.lua
local itemCandidates = {8149, 15826, 17117, 9606, 10699, 4559, 10645, 1191,
    13289, 835, 7734, 18904, 1399, 4945, 8348, 221316}

local function Finite(value)
    return IsFiniteNumber(value) and value >= 0
end

local function ValidOffset(value)
    return IsFiniteNumber(value) and value >= -250 and value <= 250
end

local function CopyColor(value, fallback)
    if type(value) == "table" then
        local r, g, b = value[1], value[2], value[3]
        if Finite(r) and r <= 1 and Finite(g) and g <= 1 and Finite(b) and b <= 1 then
            return {r, g, b}
        end
    end
    return {unpack(fallback)}
end

local function NormalizeAppearance(value)
    value = type(value) == "table" and value or {}
    local result = {
        rounded = value.rounded ~= false,
        portrait = value.portrait == true,
        x = ValidOffset(value.x) and value.x or 0,
        y = ValidOffset(value.y) and value.y or 0,
        frame = backdrops[value.frame] ~= nil and value.frame or "framed",
        border = CopyColor(value.border, borderColor),
    }
    for key, defaults in pairs(colors) do
        local palette = type(value[key]) == "table" and value[key] or {}
        result[key] = {}
        for tier, color in ipairs(defaults) do result[key][tier] = CopyColor(palette[tier], color) end
    end
    return result
end

local function HideDistance()
    if badge then badge:Hide() end
end

local function GetMeters(unit)
    local status, squaredYards, checked = ReadAPI(UnitDistanceSquared, unit)
    if status ~= "ok" then return status end
    if checked == false then return "unchecked" end
    if checked ~= true or not Finite(squaredYards) then return "invalid" end
    return "ok", math.floor(math.sqrt(squaredYards) * 0.9144 + 0.5)
end

local function AddProbe(bands, minimum, maximum, probe)
    local key = minimum .. ":" .. maximum
    local band = bands[key]
    if not band then
        band = {min = minimum, max = maximum, probes = {}}
        bands[key] = band
    end
    band.probes[#band.probes + 1] = probe
end

local function ValidRange(spell)
    return type(spell) == "table" and Finite(spell.minRange) and Finite(spell.maxRange)
        and spell.minRange < spell.maxRange and spell.maxRange <= maxProbeRange
end

local function ReadSpellRanges()
    local ranges, seen = {enemy = {}, friendly = {}}, {}
    local book = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    if not book or not C_Spell or not bank or not spellType then return ranges end
    local count = Read(book.GetNumSpellBookSkillLines)
    if not Finite(count) then return ranges end
    for lineIndex = 1, count do
        local line = Read(book.GetSpellBookSkillLineInfo, lineIndex)
        if type(line) == "table" and Finite(line.itemIndexOffset) and Finite(line.numSpellBookItems) then
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local item = Read(book.GetSpellBookItemInfo, slot, bank)
                if type(item) == "table" and IsPublic(item.itemType) and item.itemType == spellType
                    and IsPublic(item.isPassive) and not item.isPassive and IsPublic(item.isOffSpec) and not item.isOffSpec
                    and Finite(item.spellID) and item.spellID > 0 then
                    local spell = Read(C_Spell.GetSpellInfo, item.spellID)
                    if ValidRange(spell) and not seen[item.spellID]
                        and Read(C_Spell.SpellHasRange, item.spellID) == true then
                        seen[item.spellID] = true
                        local probe = {id = item.spellID, slot = slot}
                        if Read(C_Spell.IsSpellHarmful, probe.id) == true then AddProbe(ranges.enemy, spell.minRange, spell.maxRange, probe) end
                        if Read(C_Spell.IsSpellHelpful, probe.id) == true then AddProbe(ranges.friendly, spell.minRange, spell.maxRange, probe) end
                    end
                end
            end
        end
    end
    return ranges
end

local function ReadItemBands(canRequest)
    local bands = {}
    if not C_Spell or not C_Item.GetItemSpell then return bands end
    for _, id in ipairs(itemCandidates) do
        local status, cached = ReadAPI(C_Item.IsItemDataCachedByID, id)
        if status == "ok" and cached == false then
            if canRequest and C_Item.RequestLoadItemDataByID and not requestedItems[id] then
                requestedItems[id] = true
                Read(C_Item.RequestLoadItemDataByID, id)
            end
        elseif (status == "absent" or cached == true) and Read(C_Item.ItemHasRange, id) == true then
            local _, _, spellID = ReadAPI(C_Item.GetItemSpell, id)
            local spell = Finite(spellID) and Read(C_Spell.GetSpellInfo, spellID)
            if ValidRange(spell) and spell.minRange == 0 then AddProbe(bands, 0, spell.maxRange, id) end
        end
    end
    return bands
end

local function ReadSpellBand(band, unit)
    for _, probe in ipairs(band.probes) do
        local status, inRange = ReadAPI(C_SpellBook.IsSpellBookItemInRange, probe.slot, Enum.SpellBookSpellBank.Player, unit)
        if status == "absent" or (status == "ok" and inRange == nil) then
            status, inRange = ReadAPI(C_Spell.IsSpellInRange, probe.id, unit)
        end
        if status == "error" or status == "secret" then return end
        if type(inRange) == "boolean" then return inRange end
    end
end

local function GetRangeBand(unit)
    local status, enemy = ReadAPI(UnitCanAttack, "player", unit)
    if status ~= "absent" and (status ~= "ok" or type(enemy) ~= "boolean") then return end
    if not enemy and Read(UnitCanAssist, "player", unit) ~= true then return end

    local lower, upper, failed = 0, math.huge, nil
    local checkedRanges = {}
    if C_Spell and C_SpellBook then
        spellRanges = spellRanges or ReadSpellRanges()
        for _, band in pairs(enemy and spellRanges.enemy or spellRanges.friendly) do
            local inRange = ReadSpellBand(band, unit)
            if inRange == true then
                lower, upper = math.max(lower, band.min), math.min(upper, band.max)
            elseif inRange == false then
                if band.min == 0 then lower = math.max(lower, band.max)
                else failed = failed or {}; failed[#failed + 1] = band end
            end
            if band.min == 0 and type(inRange) == "boolean" then checkedRanges[band.max] = true end
        end
    end

    -- Keep the combat exception for the target badge. Mouseovers use spell checks only in combat.
    if enemy and C_Item and C_Item.IsItemInRange and not blockedItemChecks[unit] then
        local locked = Read(InCombatLockdown)
        if locked == false or (locked == true and unit == "target" and Read(IsInInstance) == false and Read(UnitIsPlayer, unit) == false) then
            itemBands = itemBands or ReadItemBands(not locked)
            local itemLower, itemUpper = 0, math.huge
            for _, band in pairs(itemBands) do
                if not checkedRanges[band.max] then
                    for _, id in ipairs(band.probes) do
                        checkingItemUnit = unit
                        local status, inRange = ReadAPI(C_Item.IsItemInRange, id, unit)
                        checkingItemUnit = nil
                        if status == "error" or blockedItemChecks[unit] then blockedItemChecks[unit] = true; break end
                        if status == "secret" then break end
                        if inRange == true then itemUpper = math.min(itemUpper, band.max); break end
                        if inRange == false then itemLower = math.max(itemLower, band.max); break end
                    end
                end
                if blockedItemChecks[unit] then break end
            end
            if not blockedItemChecks[unit] then
                lower, upper = math.max(lower, itemLower), math.min(upper, itemUpper)
            end
        end
    end
    if failed and lower < upper then
        -- A failed spell with a minimum excludes the interval in between.
        -- Another test must tell us which side of the interval still fits.
        for _ = 1, #failed do
            local beforeLower, beforeUpper = lower, upper
            for _, band in ipairs(failed) do
                if upper <= band.max then upper = math.min(upper, band.min)
                elseif lower >= band.min then lower = math.max(lower, band.max) end
            end
            if lower >= upper or (lower == beforeLower and upper == beforeUpper) then break end
        end
    end
    if lower < upper and (lower > 0 or upper < math.huge) then
        return lower * 0.9144, upper * 0.9144, enemy
    end
end

local function GetDistance(unit)
    local status, meters = GetMeters(unit)
    if status == "ok" then return ("%d m"):format(meters), meters, meters, directInterval, "measured" end
    if status == "absent" or status == "unchecked" then
        local lower, upper, enemy = GetRangeBand(unit)
        if not lower then return end
        local step = db.appearance.rounded and 5 or 1
        local minimum = math.floor(lower / step) * step
        local text
        if upper < math.huge then
            text = ("≈ %d–%d m"):format(minimum, math.ceil(upper / step) * step)
        else
            -- Keep a useful lower bound if rounding to 5 m would erase it.
            text = ("≥ %d m"):format(minimum > 0 and minimum or math.floor(lower))
        end
        return text, lower, upper, estimateInterval, enemy and "enemy" or "friendly"
    end
end

local function GetDistanceTier(lower, upper)
    if upper <= closeRange then return 1 end
    if lower >= mediumRange and upper > mediumRange then return 3 end
    return 2
end

local tooltipFormats = {
    measured = L("Distance mesurée · %s"),
    enemy = L("Ennemi · %s"),
    friendly = L("Allié · %s"),
}

function ns.GetMouseoverDistance()
    if not db then return end
    local text, lower, upper, _, source = GetDistance("mouseover")
    if text then return tooltipFormats[source]:format(text), db.appearance.tooltip[GetDistanceTier(lower, upper)] end
end

local function UpdateDistance()
    local frame = TargetFrame
    refreshInterval = hiddenInterval
    if not IsPublic(frame) or not frame or Read(frame.IsForbidden, frame) ~= false
        or Read(frame.IsVisible, frame) ~= true then return HideDistance() end
    local content = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
    local name = frame.name or (content and content.Name) or TargetFrameName
    local portrait = frame.portrait or (frame.TargetFrameContainer and frame.TargetFrameContainer.Portrait) or TargetFramePortrait
    local appearance = db.appearance
    local relativeTo = (appearance.portrait and portrait) or name or portrait
    if not IsPublic(relativeTo) or not relativeTo or relativeTo == rejectedAnchor or Read(relativeTo.IsVisible, relativeTo) ~= true
        or (relativeTo.IsAnchoringSecret and Read(relativeTo.IsAnchoringSecret, relativeTo) ~= false) then return HideDistance() end
    local text, lower, upper, interval = GetDistance("target")
    refreshInterval = interval or hiddenInterval
    if not text then return HideDistance() end

    if not badge then
        badge = CreateFrame("Frame", nil, driver, "BackdropTemplate")
        badge:Hide()
        badge:SetSize(48, 23)
        label = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        label:SetPoint("CENTER", 0, 0)
    end
    if anchor ~= relativeTo then
        badge:ClearAllPoints()
        local y = (IsPublic(name) and relativeTo == name and 8 or 15) + appearance.y
        if not pcall(badge.SetPoint, badge, "BOTTOM", relativeTo, "TOP", appearance.x, y) then
            rejectedAnchor, anchor = relativeTo, nil
            return HideDistance()
        end
        anchor = relativeTo
    end
    local tier = GetDistanceTier(lower, upper)
    if tier ~= activeTier then
        badge:SetBackdrop(backdrops[appearance.frame] or nil)
        local background = appearance.background[tier]
        badge:SetBackdropColor(background[1], background[2], background[3], .97)
        badge:SetBackdropBorderColor(unpack(appearance.border))
        label:SetTextColor(unpack(appearance.text[tier]))
        activeTier = tier
    end
    if text ~= label:GetText() then
        label:SetText(text)
        badge:SetWidth(math.max(48, math.ceil(label:GetStringWidth()) + 16))
    end
    badge:Show()
end

local function RefreshTarget()
    HideDistance()
    elapsed, refreshInterval = 0, directInterval
    local active = db.enabled and Read(UnitExists, "target") == true
    driver:SetShown(active)
    if active then UpdateDistance() end
end

local events = {"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "UPDATE_SHAPESHIFT_FORM", "TRAIT_CONFIG_UPDATED",
    "ITEM_DATA_LOAD_RESULT", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN"}
local function RefreshMonitoring()
    local active = db.enabled or mouseoverEnabled or false
    if monitoring == active then return end
    monitoring = active
    if active then
        spellRanges, itemBands = nil, nil
        for _, event in ipairs(events) do pcall(driver.RegisterEvent, driver, event) end
    else
        driver:UnregisterAllEvents()
    end
end

function ns.SetMouseoverDistanceEnabled(value)
    mouseoverEnabled = value == true
    if db then RefreshMonitoring() end
end

local function SetEnabled(value)
    db.enabled = value == true
    if refreshSettings then refreshSettings() end
    RefreshMonitoring()
    RefreshTarget()
end

driver:SetScript("OnUpdate", function(_, delta)
    if not db or not db.enabled then return end
    elapsed = elapsed + delta
    if elapsed < refreshInterval then return end
    elapsed = elapsed % refreshInterval
    UpdateDistance()
end)
driver:SetScript("OnEvent", function(_, event, arg)
    if not monitoring then return end
    if event == "PLAYER_TARGET_CHANGED" then
        if db.enabled then RefreshTarget() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        spellRanges, itemBands, rejectedAnchor = nil, nil, nil
        if db.enabled then RefreshTarget() end
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if IsPublic(arg) and requestedItems[arg] then itemBands = nil end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if checkingItemUnit and IsPublic(arg) and arg == addonName then
            blockedItemChecks[checkingItemUnit] = true
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if event == "PLAYER_REGEN_ENABLED" then rejectedAnchor, itemBands = nil, nil end
        if db.enabled then RefreshTarget() end
    else
        -- Spell changes can arrive in bursts. Rebuild at the next distance tick.
        spellRanges = nil
    end
end)

local function AppearanceChanged(reanchor)
    activeTier = nil
    if reanchor then anchor = nil end
    if refreshSettings then refreshSettings() end
end

local function RegisterSettings(root)
    if not root or not Settings or not Settings.RegisterCanvasLayoutSubcategory then return end
    local UI = ns.UI
    local panel = CreateFrame("Frame", "ArkannsQOLTargetDistanceSettings", UIParent, "BackdropTemplate")
    panel:Hide()
    UI.StylePanel(panel)
    UI.Label(panel, title, 20, -20, 18)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -54)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(508, 482)
    scroll:SetScrollChild(body)

    local toggle = UI.Check(body, "ArkannsQOLTargetDistanceEnabled", L("Afficher le badge de la cible"), 0, 0, SetEnabled)
    local rounded = UI.Check(body, nil, L("Arrondir les estimations par pas de 5 m"), 0, -30, function(value)
        db.appearance.rounded = value
    end)
    local detail = UI.Label(body, L("Groupe · WoW peut fournir une distance mesurée.\nEnnemi · Estimation via les sorts offensifs et, si autorisés, les objets.\nAllié hors groupe · Estimation via les sorts bénéfiques.\nLes fourchettes dépendent des portées disponibles. ≈ indique une estimation. ≥ indique une borne basse."), 4, -66)
    detail:SetWidth(496)

    UI.Label(body, L("Placement du badge"), 4, -180)
    local portrait = UI.Check(body, nil, L("Ancrer au portrait plutôt qu’au nom"), 0, -200, function(value)
        db.appearance.portrait = value
        AppearanceChanged(true)
    end)
    UI.Label(body, L("Décalage X / Y"), 4, -242)
    local offsetX = UI.Input(body, "ArkannsQOLTargetDistanceOffsetX", 110, -236, 54)
    local offsetY = UI.Input(body, "ArkannsQOLTargetDistanceOffsetY", 174, -236, 54)
    local function ApplyOffsets()
        local x = tonumber((offsetX:GetText():gsub(",", ".")))
        local y = tonumber((offsetY:GetText():gsub(",", ".")))
        if ValidOffset(x) and ValidOffset(y) then db.appearance.x, db.appearance.y = x, y end
        offsetX:ClearFocus()
        offsetY:ClearFocus()
        AppearanceChanged(true)
    end
    UI.Button(body, nil, L("Appliquer"), 240, -236, 100, ApplyOffsets)
    offsetX:SetScript("OnEnterPressed", ApplyOffsets)
    offsetY:SetScript("OnEnterPressed", ApplyOffsets)

    local frameModes = {framed = L("Fond et bordure"), background = L("Fond seul"), text = L("Texte seul")}
    local frame = UI.Button(body, nil, "", 4, -279, 165, function(self)
        if not MenuUtil then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            for _, mode in ipairs({"framed", "background", "text"}) do
                menu:CreateButton(frameModes[mode], function()
                    db.appearance.frame = mode
                    AppearanceChanged()
                end)
            end
        end)
    end)

    local swatches = {}
    local function ColorButton(x, y, width, caption, key, tier)
        local function GetColor(appearance)
            return tier and appearance[key][tier] or appearance[key]
        end
        local button = UI.Button(body, nil, caption, x, y, width, function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local appearance = db.appearance
            local old = GetColor(appearance)
            local function SetColor(color)
                if appearance ~= db.appearance then return end
                if tier then appearance[key][tier] = color else appearance[key] = color end
                AppearanceChanged()
            end
            ColorPickerFrame:SetupColorPickerAndShow({r = old[1], g = old[2], b = old[3], hasOpacity = false,
                swatchFunc = function() SetColor({ColorPickerFrame:GetColorRGB()}) end,
                cancelFunc = function() SetColor(old) end,
            })
        end)
        local swatch = button:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(18, 12)
        if caption == "" then swatch:SetPoint("CENTER") else swatch:SetPoint("RIGHT", -8, 0) end
        swatches[#swatches + 1] = function() swatch:SetColorTexture(unpack(GetColor(db.appearance))) end
    end
    ColorButton(180, -279, 145, L("Bordure"), "border")
    UI.Button(body, nil, L("Réinitialiser"), 336, -279, 130, function()
        db.appearance = NormalizeAppearance()
        AppearanceChanged(true)
    end)

    local columns = {
        {"tooltip", L("Texte infobulle")},
        {"text", L("Texte badge")},
        {"background", L("Fond du badge")},
    }
    for index, column in ipairs(columns) do
        local x = 152 + (index - 1) * 112
        UI.Label(body, column[2], x, -324)
        for tier = 1, 3 do ColorButton(x, -345 - (tier - 1) * 30, 102, "", column[1], tier) end
    end
    for tier, caption in ipairs({L("Proche · ≤ 10 m"), L("Intermédiaire"), L("Loin · > 30 m")}) do
        UI.Label(body, caption, 4, -351 - (tier - 1) * 30)
    end
    local colorHelp = UI.Label(body, L("La couleur intermédiaire couvre aussi les fourchettes qui chevauchent un seuil. Pour déplacer ou habiller l’infobulle, ouvre ses réglages."), 4, -438)
    colorHelp:SetWidth(496)

    refreshSettings = function()
        local appearance = db.appearance
        toggle:SetChecked(db.enabled)
        rounded:SetChecked(appearance.rounded)
        portrait:SetChecked(appearance.portrait)
        offsetX:SetText(tostring(appearance.x))
        offsetY:SetText(tostring(appearance.y))
        frame:SetText(frameModes[appearance.frame])
        for _, refresh in ipairs(swatches) do refresh() end
    end
    panel:SetScript("OnShow", refreshSettings)
    return Settings.RegisterCanvasLayoutSubcategory(root, panel, title)
end

function ns.InitializeTargetDistance(root)
    if db then return end
    if type(ForeverTooltipLibreDB.targetDistance) ~= "table" then ForeverTooltipLibreDB.targetDistance = {} end
    db = ForeverTooltipLibreDB.targetDistance
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    db.appearance = NormalizeAppearance(db.appearance)
    local category = RegisterSettings(root)
    SetEnabled(db.enabled)
    ns.RegisterModule("distance", {
        label = title, icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        category = function() return category end,
        DiagnosticFrame = function() return badge end,
        IsEnabled = function() return db.enabled end, SetEnabled = SetEnabled,
        Summary = function() return L("Mesure ou estimation · mètres") end,
        ExportSettings = function() return {enabled = db.enabled, appearance = NormalizeAppearance(db.appearance)} end,
        profileMigrations = {function(config, current) config.appearance = current.appearance end},
        ImportSettings = function(config)
            if type(config) ~= "table" or type(config.enabled) ~= "boolean" then return false end
            if config.appearance ~= nil then
                db.appearance = NormalizeAppearance(config.appearance)
                activeTier, anchor = nil, nil
            end
            SetEnabled(config.enabled)
            return true
        end,
    })
end
