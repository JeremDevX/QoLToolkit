local addonName, ns = ...
local L = ns.L
local ReadAPI, Read = ns.WoW.Read, ns.WoW.ReadValue
local IsPublic, IsFiniteNumber = ns.WoW.IsPublic, ns.WoW.IsFiniteNumber

local title = L("Distance de la cible")
local directInterval, estimateInterval, hiddenInterval = .05, .10, .20
local maxProbeRange = 100 -- Ignore global or unlimited-range spells.
local refreshInterval = directInterval
local db, toggle, badge, label, anchor, rejectedAnchor, spellRanges
local closeRange, mediumRange = 10, 30
local closeColor, mediumColor, farColor = {.10, .38, .19, .97}, {.52, .34, .07, .97}, {.47, .10, .10, .97}
local activeColor
local itemBands, itemChecksBlocked, checkingItem
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

local function HideDistance()
    if badge then badge:Hide() end
end

local function GetMeters()
    local status, squaredYards, checked = ReadAPI(UnitDistanceSquared, "target")
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

local function ReadSpellBand(band)
    for _, probe in ipairs(band.probes) do
        local status, inRange = ReadAPI(C_SpellBook.IsSpellBookItemInRange, probe.slot, Enum.SpellBookSpellBank.Player, "target")
        if status == "absent" or (status == "ok" and inRange == nil) then
            status, inRange = ReadAPI(C_Spell.IsSpellInRange, probe.id, "target")
        end
        if status == "error" or status == "secret" then return end
        if type(inRange) == "boolean" then return inRange end
    end
end

local function GetRangeBand()
    local status, enemy = ReadAPI(UnitCanAttack, "player", "target")
    if status ~= "absent" and (status ~= "ok" or type(enemy) ~= "boolean") then return end
    if not enemy and Read(UnitCanAssist, "player", "target") ~= true then return end

    local lower, upper, failed = 0, math.huge, nil
    local checkedRanges = {}
    if C_Spell and C_SpellBook then
        spellRanges = spellRanges or ReadSpellRanges()
        for _, band in pairs(enemy and spellRanges.enemy or spellRanges.friendly) do
            local inRange = ReadSpellBand(band)
            if inRange == true then
                lower, upper = math.max(lower, band.min), math.min(upper, band.max)
            elseif inRange == false then
                if band.min == 0 then lower = math.max(lower, band.max)
                else failed = failed or {}; failed[#failed + 1] = band end
            end
            if band.min == 0 and type(inRange) == "boolean" then checkedRanges[band.max] = true end
        end
    end

    -- In combat, only test items against hostile outdoor NPCs.
    if enemy and C_Item and C_Item.IsItemInRange and not itemChecksBlocked then
        local locked = Read(InCombatLockdown)
        if locked == false or (locked == true and Read(IsInInstance) == false and Read(UnitIsPlayer, "target") == false) then
            itemBands = itemBands or ReadItemBands(not locked)
            local itemLower, itemUpper = 0, math.huge
            for _, band in pairs(itemBands) do
                if not checkedRanges[band.max] then
                    for _, id in ipairs(band.probes) do
                        checkingItem = true
                        local status, inRange = ReadAPI(C_Item.IsItemInRange, id, "target")
                        checkingItem = false
                        if status == "error" or itemChecksBlocked then itemChecksBlocked = true; break end
                        if status == "secret" then break end
                        if inRange == true then itemUpper = math.min(itemUpper, band.max); break end
                        if inRange == false then itemLower = math.max(itemLower, band.max); break end
                    end
                end
                if itemChecksBlocked then break end
            end
            if not itemChecksBlocked then
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
    if lower >= upper then return end
    local minimum = math.floor(lower * 0.9144)
    if upper < math.huge then
        local maximum = math.ceil(upper * 0.9144)
        return string.format("%d–%d", minimum, maximum), minimum, maximum
    end
    if lower > 0 then return string.format("%d+", minimum), minimum, math.huge end
end

local function UpdateDistance()
    local frame = TargetFrame
    refreshInterval = hiddenInterval
    if not IsPublic(frame) or not frame or Read(frame.IsForbidden, frame) ~= false
        or Read(frame.IsVisible, frame) ~= true then return HideDistance() end
    local content = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
    local name = frame.name or (content and content.Name) or TargetFrameName
    local relativeTo = name or frame.portrait or (frame.TargetFrameContainer and frame.TargetFrameContainer.Portrait) or TargetFramePortrait
    if not IsPublic(relativeTo) or not relativeTo or relativeTo == rejectedAnchor or Read(relativeTo.IsVisible, relativeTo) ~= true
        or (relativeTo.IsAnchoringSecret and Read(relativeTo.IsAnchoringSecret, relativeTo) ~= false) then return HideDistance() end
    local status, meters = GetMeters()
    local text, lower, upper
    if status == "ok" then
        refreshInterval = directInterval
        text, lower, upper = tostring(meters), meters, meters
    elseif status == "absent" or status == "unchecked" then
        refreshInterval = estimateInterval
        text, lower, upper = GetRangeBand()
    end
    if not text then return HideDistance() end

    if not badge then
        badge = CreateFrame("Frame", nil, driver, "BackdropTemplate")
        badge:Hide()
        badge:SetSize(48, 23)
        badge:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = {left = 3, right = 3, top = 3, bottom = 3},
        })
        badge:SetBackdropBorderColor(.82, .67, .37, 1)
        label = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        label:SetPoint("CENTER", 0, 0)
    end
    if anchor ~= relativeTo then
        badge:ClearAllPoints()
        if not pcall(badge.SetPoint, badge, "BOTTOM", relativeTo, "TOP", 0, name and 8 or 15) then
            rejectedAnchor, anchor = relativeTo, nil
            return HideDistance()
        end
        anchor = relativeTo
    end
    -- Yellow also covers estimates that cross a color threshold.
    local color = mediumColor
    if upper <= closeRange then
        color = closeColor
    elseif lower >= mediumRange and upper > mediumRange then
        color = farColor
    end
    if color ~= activeColor then
        badge:SetBackdropColor(unpack(color))
        activeColor = color
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
local function SetEnabled(value)
    db.enabled = value == true
    if toggle then toggle:SetChecked(db.enabled) end
    if db.enabled then
        spellRanges, itemBands = nil, nil
        for _, event in ipairs(events) do pcall(driver.RegisterEvent, driver, event) end
    else
        driver:UnregisterAllEvents()
    end
    RefreshTarget()
end

driver:SetScript("OnUpdate", function(_, delta)
    if not db or not db.enabled then return end
    elapsed = elapsed + delta
    if elapsed < refreshInterval then return end
    elapsed = elapsed % refreshInterval
    UpdateDistance()
end)
driver:SetScript("OnEvent", function(_, event, arg, action)
    if not db or not db.enabled then return end
    if event == "PLAYER_TARGET_CHANGED" then
        RefreshTarget()
    elseif event == "PLAYER_ENTERING_WORLD" then
        spellRanges, itemBands, rejectedAnchor = nil, nil, nil
        RefreshTarget()
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if IsPublic(arg) and requestedItems[arg] then itemBands = nil end
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if IsPublic(arg) and arg == addonName and (checkingItem
            or (IsPublic(action) and type(action) == "string" and action:find("IsItemInRange", 1, true))) then
            itemChecksBlocked = true
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        if event == "PLAYER_REGEN_ENABLED" then rejectedAnchor, itemBands = nil, nil end
        RefreshTarget()
    else
        -- Spell changes can arrive in bursts. Rebuild at the next distance tick.
        spellRanges = nil
    end
end)

local function RegisterSettings(root)
    if not root or not Settings or not Settings.RegisterCanvasLayoutSubcategory then return end
    local panel = CreateFrame("Frame", "ArkannsQOLTargetDistanceSettings", UIParent, "BackdropTemplate")
    panel:Hide()
    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 20, -20)
    heading:SetText(title)

    toggle = CreateFrame("CheckButton", "ArkannsQOLTargetDistanceEnabled", panel, "UICheckButtonTemplate")
    toggle:SetPoint("TOPLEFT", 20, -56)
    toggle:SetScript("OnClick", function(self) SetEnabled(self:GetChecked()) end)
    local caption = toggle:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    caption:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    caption:SetText(L("Afficher la distance en mètres"))

    local detail = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    detail:SetPoint("TOPLEFT", 24, -108)
    detail:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    detail:SetJustifyH("LEFT")
    detail:SetText(L("Au-dessus du nom de la cible. Vert jusqu’à 10 m, jaune jusqu’à 30 m, rouge au-delà. Jaune aussi si la fourchette chevauche un seuil. 28+ indique une borne basse seule."))
    if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(panel) end
    return Settings.RegisterCanvasLayoutSubcategory(root, panel, title)
end

function ns.InitializeTargetDistance(root)
    if db then return end
    if type(ForeverTooltipLibreDB.targetDistance) ~= "table" then ForeverTooltipLibreDB.targetDistance = {} end
    db = ForeverTooltipLibreDB.targetDistance
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    local category = RegisterSettings(root)
    SetEnabled(db.enabled)
    ns.RegisterModule("distance", {
        label = title, icon = "Interface\\Icons\\INV_Misc_Spyglass_02",
        category = function() return category end,
        DiagnosticFrame = function() return badge end,
        IsEnabled = function() return db.enabled end, SetEnabled = SetEnabled,
        Summary = function() return L("Au-dessus du nom · mètres") end,
        ExportSettings = function() return {enabled = db.enabled} end,
        ImportSettings = function(config)
            if type(config) ~= "table" or type(config.enabled) ~= "boolean" then return false end
            SetEnabled(config.enabled)
            return true
        end,
    })
end
