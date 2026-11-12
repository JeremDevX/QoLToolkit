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
local frameStrata = {BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true,
    FULLSCREEN = true, FULLSCREEN_DIALOG = true, TOOLTIP = true}
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

-- These Hunter spells use the caster or their pet regardless of the selected unit.
local implicitSpellTargets = {
    [2641] = "pet", [6991] = "pet", -- Dismiss Pet, Feed Pet
    [136] = "pet", [3111] = "pet", [3661] = "pet", [3662] = "pet",
    [13542] = "pet", [13543] = "pet", [13544] = "pet", -- Mend Pet ranks
    [13163] = "player", -- Aspect of the Monkey
}

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
    if checked == false or (checked == nil and squaredYards == nil) then return "unchecked" end
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
        local implicitTarget = implicitSpellTargets[probe.id]
        if not implicitTarget or Read(UnitIsUnit, unit, implicitTarget) == true then
            local status, inRange = ReadAPI(C_SpellBook.IsSpellBookItemInRange, probe.slot, Enum.SpellBookSpellBank.Player, unit)
            if status == "absent" or (status == "ok" and inRange == nil) then
                status, inRange = ReadAPI(C_Spell.IsSpellInRange, probe.id, unit)
            end
            if status == "error" or status == "secret" then return end
            if type(inRange) == "boolean" then return inRange end
        end
    end
end

local function GetRangeBand(unit)
    -- A public alias of the target must use the same permitted probes as its badge.
    if unit == "mouseover" and Read(UnitIsUnit, unit, "target") == true then unit = "target" end
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
        return lower * 0.9144, upper * 0.9144
    end
end

local function GetDistance(unit)
    local status, meters = GetMeters(unit)
    if status == "ok" then return ("%d m"):format(meters), meters, meters, directInterval end
    if status == "absent" or status == "unchecked" then
        local lower, upper = GetRangeBand(unit)
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
        return text, lower, upper, estimateInterval
    end
end

local function GetDistanceTier(lower, upper)
    if upper <= closeRange then return 1 end
    if lower >= mediumRange and upper > mediumRange then return 3 end
    return 2
end

local tooltipFormat = L("Distance · %s")

function ns.GetMouseoverDistance()
    if not db then return end
    local text, lower, upper = GetDistance("mouseover")
    if text then return tooltipFormat:format(text), db.appearance.tooltip[GetDistanceTier(lower, upper)] end
end

local function CreateBadge(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(48, 23)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    text:SetPoint("CENTER")
    return frame, text
end

local function PaintBadge(frame, text, appearance, tier)
    frame:SetBackdrop(backdrops[appearance.frame] or nil)
    if appearance.frame ~= "text" then
        local r, g, b = unpack(appearance.background[tier])
        frame:SetBackdropColor(r, g, b, .97)
        if appearance.frame == "framed" then frame:SetBackdropBorderColor(unpack(appearance.border)) end
    end
    text:SetTextColor(unpack(appearance.text[tier]))
end

local function SetBadgeText(frame, label, text)
    label:SetText(text)
    frame:SetWidth(math.max(48, math.ceil(label:GetStringWidth()) + 16))
end

local function CanAnchor(region)
    return IsPublic(region) and region and region ~= rejectedAnchor and Read(region.IsVisible, region) == true
        and (not region.IsAnchoringSecret or Read(region.IsAnchoringSecret, region) == false)
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
    -- Instance names may have secret geometry even when target range checks remain public.
    local nativeNameAnchor = content and IsPublic(name) and name == content.Name and CanAnchor(frame)
    local relativeTo
    if appearance.portrait and CanAnchor(portrait) then relativeTo = portrait
    elseif CanAnchor(name) then relativeTo = name
    elseif nativeNameAnchor then relativeTo = frame
    elseif CanAnchor(portrait) then relativeTo = portrait
    elseif CanAnchor(frame) then relativeTo = frame
    else return HideDistance() end
    local text, lower, upper, interval = GetDistance("target")
    refreshInterval = interval or hiddenInterval
    if not text then return HideDistance() end

    if not badge then
        badge, label = CreateBadge(driver)
        badge:Hide()
    end
    local layer, level = Read(frame.GetFrameStrata, frame), Read(frame.GetFrameLevel, frame)
    if frameStrata[layer] then badge:SetFrameStrata(layer) end
    if IsFiniteNumber(level) and level >= 0 then badge:SetFrameLevel(level + 1) end
    local targetScale, parentScale = Read(frame.GetEffectiveScale, frame), Read(driver.GetEffectiveScale, driver)
    if IsFiniteNumber(targetScale) and IsFiniteNumber(parentScale) and targetScale > 0 and parentScale > 0 then
        badge:SetScale(targetScale / parentScale)
    end
    local alpha = Read(frame.GetEffectiveAlpha, frame)
    local parentAlpha = Read(driver.GetEffectiveAlpha, driver)
    if IsFiniteNumber(alpha) and IsFiniteNumber(parentAlpha) and parentAlpha > 0 then
        badge:SetAlpha(math.max(0, math.min(1, alpha / parentAlpha)))
    end
    if anchor ~= relativeTo then
        badge:ClearAllPoints()
        local point, x = "TOP", appearance.x
        local y = (IsPublic(name) and relativeTo == name and 8 or 15) + appearance.y
        if relativeTo == frame and nativeNameAnchor then
            -- Forever 70888 TargetFrame.xml: name TOPLEFT = (-181, -26), width 90; badge 8 above.
            -- https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.xml#L114
            point, x, y = "TOPRIGHT", appearance.x - 136, appearance.y - 18
        end
        if not pcall(badge.SetPoint, badge, "BOTTOM", relativeTo, point, x, y) then
            rejectedAnchor, anchor = relativeTo, nil
            return HideDistance()
        end
        anchor = relativeTo
    end
    local tier = GetDistanceTier(lower, upper)
    if tier ~= activeTier then
        PaintBadge(badge, label, appearance, tier)
        activeTier = tier
    end
    if text ~= label:GetText() then SetBadgeText(badge, label, text) end
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

local function MouseoverSetting()
    if ns.GetMouseoverDistanceSetting then return ns.GetMouseoverDistanceSetting() end
    return ForeverTooltipLibreDB.mouseoverDistance ~= false
end

local function SetMouseoverSetting(value)
    if ns.SetMouseoverDistanceSetting then ns.SetMouseoverDistanceSetting(value)
    else ForeverTooltipLibreDB.mouseoverDistance = value == true end
    if refreshSettings then refreshSettings() end
end

local function RegisterSettings(root)
    if not root or not Settings or not Settings.RegisterCanvasLayoutSubcategory then return end
    local UI = ns.UI
    local host = ns.TooltipSettingsHost
    local panel = CreateFrame("Frame", "ArkannsQOLTargetDistanceSettings", host and host.panel or UIParent, "BackdropTemplate")
    panel:Hide()
    UI.StylePanel(panel)
    if not host then UI.Label(panel, title, 20, -20, 18) end

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", host and 0 or 20, host and 0 or -54)
    scroll:SetPoint("BOTTOMRIGHT", host and 0 or -34, host and 0 or 16)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(508, 556)
    scroll:SetScrollChild(body)

    local toggle = UI.Check(body, "ArkannsQOLTargetDistanceEnabled", L("Afficher le badge de la cible"), 0, 0, SetEnabled)
    local mouseover = UI.Check(body, "ArkannsQOLDistanceMouseover", L("Afficher la distance au survol"), 0, -30, SetMouseoverSetting)
    local rounded = UI.Check(body, nil, L("Arrondir les estimations par pas de 5 m"), 0, -60, function(value)
        db.appearance.rounded = value
    end)
    local estimateHelp = UI.Label(body, L("≈ indique une estimation. ≥ indique une distance minimale."), 4, -95)
    local advanced, Layout = false
    local advancedButton = UI.Button(body, "ArkannsQOLDistanceAdvanced", L("Placement et couleurs"), 4, -125, 260, function()
        advanced = not advanced
        Layout()
    end)

    local placementTitle = UI.Label(body, L("Placement du badge"), 4, -131, 15)
    local portrait = UI.Check(body, nil, L("Ancrer au portrait plutôt qu’au nom"), 0, -153, function(value)
        db.appearance.portrait = value
        AppearanceChanged(true)
    end)
    local offsetLabel = UI.Label(body, L("Décalage X / Y"), 4, -197)
    local offsetX = UI.Input(body, "ArkannsQOLTargetDistanceOffsetX", 110, -191, 54)
    local offsetY = UI.Input(body, "ArkannsQOLTargetDistanceOffsetY", 174, -191, 54)
    local function ApplyOffsets()
        local x = tonumber((offsetX:GetText():gsub(",", ".")))
        local y = tonumber((offsetY:GetText():gsub(",", ".")))
        if not ValidOffset(x) or not ValidOffset(y) then
            UI.Notify(L("Saisis deux décalages entre −250 et 250."))
            return
        end
        db.appearance.x, db.appearance.y = x, y
        offsetX:ClearFocus()
        offsetY:ClearFocus()
        AppearanceChanged(true)
    end
    local applyOffsets = UI.Button(body, nil, L("Appliquer"), 240, -191, 100, ApplyOffsets)
    offsetX:SetScript("OnEnterPressed", ApplyOffsets)
    offsetY:SetScript("OnEnterPressed", ApplyOffsets)

    local resetPosition = UI.Button(body, "ArkannsQOLDistanceResetPosition", L("Réinitialiser le placement"), 4, -228, 260, function()
        db.appearance.portrait, db.appearance.x, db.appearance.y = false, 0, 0
        AppearanceChanged(true)
    end)
    local colorsTitle = UI.Label(body, L("Couleurs et aperçu"), 4, -273, 15)
    local frameModes = {framed = L("Fond et bordure"), background = L("Fond seul"), text = L("Texte seul")}
    local frame = UI.Button(body, nil, "", 4, -298, 165, function(self)
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

    local previews = {}
    local function ColorButton(x, y, width, caption, key, tier, sample)
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
        local updateColor
        if sample then
            local line = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetPoint("CENTER")
            line:SetText(tooltipFormat:format(sample))
            updateColor = function(r, g, b) line:SetTextColor(r, g, b) end
        else
            local swatch = button:CreateTexture(nil, "OVERLAY")
            button.swatch = swatch
            swatch:SetSize(18, 12)
            if caption == "" then swatch:SetPoint("CENTER") else swatch:SetPoint("RIGHT", -8, 0) end
            updateColor = function(r, g, b) swatch:SetColorTexture(r, g, b) end
        end
        previews[#previews + 1] = function(appearance)
            updateColor(unpack(GetColor(appearance)))
            if key == "border" then button:SetEnabled(appearance.frame == "framed") end
            if key == "background" then button:SetEnabled(appearance.frame ~= "text") end
        end
        return button
    end
    local borderButton = ColorButton(180, -298, 130, L("Bordure"), "border")
    local resetColors = UI.Button(body, "ArkannsQOLDistanceResetColors", L("Réinitialiser les couleurs"), 4, -503, 260, function()
        local appearance = db.appearance
        UI.Confirm(L("Rétablir les couleurs par défaut du badge et des infobulles de distance ?"), function()
            if appearance ~= db.appearance then return end
            local defaults = NormalizeAppearance()
            for _, key in ipairs({"border", "tooltip", "text", "background"}) do appearance[key] = defaults[key] end
            AppearanceChanged()
        end)
    end)

    local headings = {
        UI.Label(body, L("Aperçu du badge"), 110, -343), UI.Label(body, L("Texte"), 219, -343),
        UI.Label(body, L("Fond"), 277, -343), UI.Label(body, L("Infobulle au survol"), 352, -343),
    }
    local rowControls = {}
    local rows = {
        {L("Proche · ≤ 10 m"), "8 m"},
        {L("Intermédiaire"), "≈ 15–25 m"},
        {L("Loin · > 30 m"), "≥ 35 m"},
    }
    for tier, row in ipairs(rows) do
        local y = -366 - (tier - 1) * 35
        local caption = UI.Label(body, row[1], 4, y - 6)
        local example, text = CreateBadge(body)
        example:SetPoint("CENTER", body, "TOPLEFT", 158, y - 13)
        SetBadgeText(example, text, row[2])
        previews[#previews + 1] = function(appearance) PaintBadge(example, text, appearance, tier) end
        rowControls[tier] = {caption = caption, badge = example,
            text = ColorButton(215, y, 48, "", "text", tier),
            background = ColorButton(273, y, 70, "", "background", tier),
            tooltip = ColorButton(351, y, 147, "", "tooltip", tier, row[2])}
    end
    local colorHelp = UI.Label(body, L("Clique sur un échantillon ou sur le texte d’une infobulle pour changer sa couleur. Les fourchettes qui chevauchent un seuil prennent la couleur intermédiaire."), 4, -460)
    colorHelp:SetWidth(496)

    Layout = function()
        local width = math.max(270, panel:GetWidth() - (host and 0 or 54))
        local totalWidth, columns = width, width >= 800
        local placementWidth = columns and 268 or width
        local originX = 0
        local function Place(control, x, y)
            control:ClearAllPoints(); control:SetPoint("TOPLEFT", body, "TOPLEFT", originX + x, y)
        end
        local y = 0
        for _, check in ipairs({toggle, mouseover, rounded, portrait}) do
            if check.label then check.label:SetWidth(width - 38) end
        end
        local function CheckRow(check)
            Place(check, 0, -y)
            y = y + math.max(30, check.label and check.label:GetStringHeight() + 8 or 30)
        end
        for _, check in ipairs({toggle, mouseover, rounded}) do CheckRow(check) end
        y = y + 5; Place(estimateHelp, 4, -y); estimateHelp:SetWidth(width - 8)
        y = y + estimateHelp:GetStringHeight() + 12
        Place(advancedButton, 4, -y)
        advancedButton:SetText(advanced and L("Masquer placement et couleurs") or L("Placement et couleurs"))
        y = y + 40
        for _, control in ipairs({placementTitle, portrait, offsetLabel, offsetX, offsetY, applyOffsets,
            resetPosition, colorsTitle, frame, resetColors, colorHelp}) do control:SetShown(advanced) end
        local frameMode = db.appearance.frame
        borderButton:SetShown(advanced and frameMode == "framed")
        local colorWidth = columns and width - placementWidth - 24 or width
        local narrow = colorWidth < 508
        for _, heading in ipairs(headings) do heading:SetShown(advanced and not narrow) end
        headings[3]:SetShown(advanced and not narrow and frameMode ~= "text")
        for _, controls in ipairs(rowControls) do
            for _, control in pairs(controls) do control:SetShown(advanced) end
            controls.background:SetShown(advanced and frameMode ~= "text")
        end
        if not advanced then
            offsetX:ClearFocus(); offsetY:ClearFocus()
            body:SetSize(width, y)
            UI.ClampScroll(scroll, y)
            return
        end
        local sectionTop = y
        if portrait.label then portrait.label:SetWidth(placementWidth - 38) end
        Place(placementTitle, 4, -y); y = y + 22; CheckRow(portrait)
        y = y + 8
        if columns then
            Place(offsetLabel, 4, -y); y = y + offsetLabel:GetStringHeight() + 10
            Place(offsetX, 10, -y); Place(offsetY, 74, -y); Place(applyOffsets, 138, -y)
            y = y + 36
        else
            local extra = width < 344 and 34 or 0
            Place(offsetLabel, 4, -y - 6); Place(offsetX, 110, -y); Place(offsetY, 174, -y)
            Place(applyOffsets, extra > 0 and 4 or 240, -y - extra)
            y = y + 36 + extra
        end
        Place(resetPosition, 4, -y)
        local placementBottom = y + 42
        if columns then originX, y, width = placementWidth + 24, sectionTop, colorWidth else y = y + 45 end
        Place(colorsTitle, 4, -y)
        y = y + 25; Place(frame, 4, -y)
        local borderExtra = width < 320 and frameMode == "framed" and 34 or 0
        Place(borderButton, borderExtra > 0 and 4 or 180, -y - borderExtra)
        y = y + 38 + borderExtra
        Place(colorHelp, 4, -y); colorHelp:SetWidth(width - 8)
        y = y + colorHelp:GetStringHeight() + 12
        for index, heading in ipairs(headings) do
            Place(heading, ({110, 219, 277, 352})[index], -y)
        end
        local top = -y - (narrow and 0 or 23)
        for index, controls in ipairs(rowControls) do
            local y = top - (index - 1) * (narrow and 110 or 35)
            Place(controls.caption, 4, y - 6)
            controls.badge:ClearAllPoints(); controls.badge:SetPoint("CENTER", body, "TOPLEFT", originX + (narrow and math.min(width - 64, 200) or 158), y - 13)
            Place(controls.text, narrow and 4 or 215, y - (narrow and 34 or 0))
            Place(controls.background, narrow and 120 or 273, y - (narrow and 34 or 0))
            controls.text:SetWidth(narrow and 106 or 48); controls.text:SetText(narrow and L("Texte") or "")
            controls.background:SetWidth(narrow and 106 or 70); controls.background:SetText(narrow and L("Fond") or "")
            for _, button in ipairs({controls.text, controls.background}) do
                button.swatch:ClearAllPoints(); button.swatch:SetPoint(narrow and "RIGHT" or "CENTER", narrow and -8 or 0, 0)
            end
            Place(controls.tooltip, narrow and 4 or 351, y - (narrow and 68 or 0))
        end
        local bottom = -top + (narrow and 330 or 105)
        Place(resetColors, 4, -bottom)
        body:SetSize(totalWidth, math.max(placementBottom, bottom + 42))
        UI.ClampScroll(scroll, body:GetHeight())
    end

    refreshSettings = function()
        local appearance = db.appearance
        toggle:SetChecked(db.enabled)
        mouseover:SetChecked(MouseoverSetting())
        rounded:SetChecked(appearance.rounded)
        portrait:SetChecked(appearance.portrait)
        offsetX:SetText(tostring(appearance.x))
        offsetY:SetText(tostring(appearance.y))
        frame:SetText(frameModes[appearance.frame])
        for _, refresh in ipairs(previews) do refresh(appearance) end
        Layout()
    end
    panel:SetScript("OnShow", refreshSettings)
    panel:HookScript("OnSizeChanged", Layout)
    local category
    if host then
        host.AddDistancePage(panel)
        category=host.category
    else category=UI.RegisterSettingsPanel(root, panel, title, "distance") end
    function ns.OpenDistanceSettings(source)
        UI.OpenCategory(category)
        if host then host.Select("distance") end
        local targets={
            ["Afficher le badge de la cible"]=toggle,["Afficher la distance au survol"]=mouseover,
            ["Arrondir les estimations par pas de 5 m"]=rounded,["Placement et couleurs"]=advancedButton,
            ["Ancrer au portrait plutôt qu’au nom"]=portrait,["Décalage X / Y"]=offsetX,
            ["Réinitialiser le placement"]=resetPosition,["Fond et bordure"]=frame,
            ["Fond seul"]=frame,["Texte seul"]=frame,["Couleur du texte"]=rowControls[1].text,
            ["Texte"]=rowControls[1].text,["Fond"]=rowControls[1].background,["Bordure"]=borderButton,
            ["Infobulle au survol"]=rowControls[1].tooltip,["Réinitialiser les couleurs"]=resetColors,
        }
        local target=targets[source]
        if target and target~=toggle and target~=mouseover and target~=rounded then advanced=true end
        refreshSettings()
        if target==borderButton and db.appearance.frame~="framed" then target=frame end
        if target==rowControls[1].background and db.appearance.frame=="text" then target=frame end
        if source and UI.RevealControl then UI.RevealControl(scroll,target or toggle) end
    end
    return category
end

function ns.InitializeTargetDistance(root)
    if db then return end
    if type(ForeverTooltipLibreDB.targetDistance) ~= "table" then ForeverTooltipLibreDB.targetDistance = {} end
    db = ForeverTooltipLibreDB.targetDistance
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    db.appearance = NormalizeAppearance(db.appearance)
    local category = RegisterSettings(root)
    ns.targetDistanceCategory = category
    SetEnabled(db.enabled)
    ns.RegisterModule("distance", {
        label = title, icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        category = function() return category end,
        OpenSettings = ns.OpenDistanceSettings,
        SearchSettings = {"Afficher le badge de la cible","Afficher la distance au survol","Arrondir les estimations par pas de 5 m",
            "Placement et couleurs","Ancrer au portrait plutôt qu’au nom","Décalage X / Y","Réinitialiser le placement",
            "Fond et bordure","Fond seul","Texte seul","Texte","Fond","Bordure","Infobulle au survol","Réinitialiser les couleurs"},
        DiagnosticFrame = function() return badge end,
        IsEnabled = function() return db.enabled end, SetEnabled = SetEnabled,
        toggleLabel = L("Afficher le badge de la cible"),
        Summary = function() return L("Mesure ou estimation · mètres") end,
        ExportSettings = function() return {enabled = db.enabled, appearance = NormalizeAppearance(db.appearance), mouseoverDistance = MouseoverSetting()} end,
        profileMigrations = {function(config, current) config.appearance = current.appearance end,
            function(config, current) if config.mouseoverDistance == nil then config.mouseoverDistance = current.mouseoverDistance end end},
        ImportSettings = function(config)
            if type(config) ~= "table" or type(config.enabled) ~= "boolean" then return false end
            if config.mouseoverDistance ~= nil and type(config.mouseoverDistance) ~= "boolean" then return false end
            if config.appearance ~= nil then
                db.appearance = NormalizeAppearance(config.appearance)
                activeTier, anchor = nil, nil
            end
            SetEnabled(config.enabled)
            if config.mouseoverDistance ~= nil then SetMouseoverSetting(config.mouseoverDistance) end
            return true
        end,
    })
end
