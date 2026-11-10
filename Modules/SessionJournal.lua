local _, ns = ...
local L = ns.L
local Model, WoW = ns.SessionJournalModel, ns.WoW
local db, session, window, title, names, values, footer, settings, refreshSettings
local ready, moving = false, false
local startedAt
local afkUnavailable
local ticker, xpRetry, Draw
local rateTooltip, hovered
local moveHint
local trackingToggle, trackingTooltip
local trackingToggleSize = 20
local hoverRows = {}
local horizontalTexts = {}
local preview, expanded = false, false
local pauseLabels = {manual = L("Session arrêtée"), afk = L("En pause (AFK)")}
local metrics = {
    {key = "duration", label = L("Durée"), icon = "INV_Misc_PocketWatch_01"},
    {key = "xp", label = L("XP gagnée"), icon = "INV_Misc_Book_09"},
    {key = "nextLevel", label = L("Prochain niveau"), icon = "Ability_Rogue_Sprint", always = true},
    {key = "income", label = L("Or reçu"), icon = "INV_Misc_Coin_01"},
    {key = "expense", label = L("Or dépensé"), icon = "INV_Misc_Coin_02"},
    {key = "net", label = L("Solde"), icon = "INV_Misc_Bag_10"},
    {key = "deaths", label = L("Morts"), icon = "Ability_Rogue_FeignDeath"},
    {key = "levels", label = L("Niveaux gagnés"), icon = "Spell_Holy_InnerFire"},
}
local themes = {
    dark = {label = L("Ardoise"), bg = {0.035, 0.055, 0.08}, text = {0.91, 0.94, 1}, accent = {0.3, 0.8, 1}},
    warm = {label = L("Chaleureux"), bg = {0.12, 0.065, 0.025}, text = {1, 0.94, 0.8}, accent = {1, 0.76, 0.3}},
    light = {label = L("Clair"), bg = {0.88, 0.9, 0.94}, text = {0.08, 0.1, 0.15}, accent = {0.1, 0.25, 0.5}},
}

local Number = WoW.IsFiniteNumber

local function ReadNumber(api, ...)
    local status, value = WoW.Read(api, ...)
    if status == "ok" and Number(value) then return value end
end

local function InCombat()
    local status, combat = WoW.Read(InCombatLockdown)
    return status ~= "ok" or combat ~= false
end

local function NormalizeOptions()
    for key, value in pairs({enabled = true, locked = true, showTitle = true, border = true, compact = false, hideZero = false, expandOnHover = true, hideCombat = false, pauseAFK = false}) do
        if type(db[key]) ~= "boolean" then db[key] = value end
    end
    for key, bounds in pairs({x = {0, 1, 0.02}, y = {0, 1, 0.75}, width = {240, 1000, 300}, fontSize = {10, 32, 13}, opacity = {0, 100, 85}}) do
        if not Number(db[key]) or db[key] < bounds[1] or db[key] > bounds[2] then db[key] = bounds[3] end
    end
    if not themes[db.theme] then db.theme = "warm" end
    if db.layout ~= "horizontal" then db.layout = "vertical" end
    if type(db.visible) ~= "table" then db.visible = {} end
    db.visible.xpRate = nil
    local known, seen, clean = {}, {}, {}
    for _, metric in ipairs(metrics) do
        known[metric.key] = true
        if type(db.visible[metric.key]) ~= "boolean" then db.visible[metric.key] = metric.key ~= "levels" end
    end
    for _, key in ipairs(type(db.order) == "table" and db.order or {}) do
        if known[key] and not seen[key] then clean[#clean + 1] = key; seen[key] = true end
    end
    for _, metric in ipairs(metrics) do if not seen[metric.key] then clean[#clean + 1] = metric.key end end
    if type(db.order) ~= "table" then db.order = {} end
    for key in pairs(db.order) do db.order[key] = nil end
    for index, key in ipairs(clean) do db.order[index] = key end
end

local function SharedStyle()
    return ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("session")
end

local function Elapsed()
    return Model.Elapsed(session, startedAt and ReadNumber(GetTime), startedAt)
end

local function IsTracking()
    return ready and not session.pause
end

local function TrackingAction()
    return ready and session.pause == "manual" and L("Démarrer le suivi") or L("Arrêter le suivi")
end

local function Money(copper)
    local sign = copper < 0 and "−" or ""
    copper = math.floor(math.abs(copper))
    local style = SharedStyle()
    local size = style and style.fontSize or db.fontSize
    local gold = string.format("|TInterface\\MoneyFrame\\UI-GoldIcon:%d:%d|t", size, size)
    local silver = string.format("|TInterface\\MoneyFrame\\UI-SilverIcon:%d:%d|t", size, size)
    local bronze = string.format("|TInterface\\MoneyFrame\\UI-CopperIcon:%d:%d|t", size, size)
    return string.format("%s%d%s %02d%s %02d%s", sign, math.floor(copper / 10000), gold, math.floor(copper / 100) % 100, silver, copper % 100, bronze)
end

local function Duration(seconds)
    return string.format("%02d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

local function HideRateTooltip(row)
    if not row or hovered == row then
        hovered = nil
        if rateTooltip then rateTooltip:Hide() end
    end
end

local function RefreshRateTooltip()
    if not hovered then return end
    if preview or not db.locked or not db.enabled or not hovered:IsShown() then HideRateTooltip(); return end
    if rateTooltip:GetOwner() ~= hovered then rateTooltip:SetOwner(hovered, "ANCHOR_RIGHT") end
    rateTooltip:ClearLines()
    local xpRate = hovered.metric == "xp"
    rateTooltip:AddLine(xpRate and L("XP / heure") or L("Or net / heure"), 1, 0.82, 0)
    local xpPerHour, netPerHour = Model.HourlyRates(session, Elapsed())
    if xpPerHour == nil then
        rateTooltip:AddLine(L("Disponible après 1 min."), 1, 1, 1)
    elseif xpRate then
        rateTooltip:AddLine((session.approximateXP and "≥ " or "") .. xpPerHour, 1, 1, 1)
    else
        rateTooltip:AddLine(Money(netPerHour), 1, 1, 1)
        rateTooltip:AddLine(L("Reçu − dépensé"), 0.7, 0.7, 0.7)
    end
    rateTooltip:Show()
end

local function ObserveMoney()
    if IsTracking() then Model.ObserveMoney(session, ReadNumber(GetMoney)) end
end

local function XPState()
    local xp = ReadNumber(UnitXP, "player")
    local maximum = ReadNumber(UnitXPMax, "player")
    local level = ReadNumber(UnitLevel, "player")
    if xp and maximum and level and xp >= 0 and maximum >= xp and level >= 1 then
        return xp, maximum, level
    end
end

local nextLevelLabels = {unknown = "—", max = L("Niv. max"), calculating = L("Calcul...")}
local function NextLevel(elapsed)
    if not IsTracking() then return nextLevelLabels.unknown end
    local status, seconds = Model.NextLevel(session, elapsed, XPState())
    return nextLevelLabels[status] or "~ " .. Duration(seconds)
end

local function ObserveDeath(count)
    local status, dead = WoW.Read(UnitIsDeadOrGhost, "player")
    if status == "ok" and type(dead) == "boolean" then Model.ObserveDeath(session, dead, count) end
end

local function ObserveXP(newLevel)
    if not ready then return end
    local tracking = IsTracking()
    if Number(newLevel) and Model.ObserveLevelUp(session, newLevel, not tracking) then
        xpRetry = true
    elseif tracking then
        xpRetry = not Model.ObserveXP(session, XPState())
    end
end

local function AFKPause(current)
    afkUnavailable = false
    if not db.pauseAFK then return end
    local status, afk = WoW.Read(UnitIsAFK, "player")
    if status ~= "ok" or type(afk) ~= "boolean" then
        afkUnavailable = true
        return current
    end
    return afk and "afk" or nil
end

local function Baseline()
    session.lastMoney = ReadNumber(GetMoney)
    xpRetry = not Model.BaselineXP(session, XPState())
    session.dead = nil
    ObserveDeath(false)
end

local function SetPause(pause)
    if not ready or session.pause == pause then return end
    if IsTracking() then
        session.elapsed = Elapsed()
        ObserveMoney(); ObserveXP(); ObserveDeath(true)
        startedAt, xpRetry = nil, false
    elseif not pause then
        Baseline()
        startedAt = ReadNumber(GetTime)
    end
    session.pause = pause
end

local function SyncAFK()
    if ready and session.pause ~= "manual" then SetPause(AFKPause(session.pause)) end
end

local function BeginSession(previous, pause)
    local resumed = Model.IsResumable(previous)
    if resumed then
        session = previous
        pause = session.pause
    else
        local xp, maximum, level = XPState()
        session = Model.New(xp, maximum, level, ReadNumber(GetMoney))
    end
    db.session = session
    startedAt, ready, xpRetry = nil, true, false
    if pause == "manual" then
        session.pause = pause
    else
        session.pause = AFKPause(pause == "afk" and pause or nil)
    end
    if IsTracking() then
        startedAt = ReadNumber(GetTime)
        if pause == "afk" then Baseline()
        else ObserveMoney(); ObserveXP(); ObserveDeath(resumed) end
    end
end

local function RestorePosition()
    window:ClearAllPoints()
    local scale = window:GetScale()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.x * UIParent:GetWidth() / scale, db.y * UIParent:GetHeight() / scale)
end

local function SavePosition()
    if moving then window:StopMovingOrSizing(); moving = false end
    local x, y = window:GetLeft(), window:GetTop()
    if x and y and UIParent:GetWidth() > 0 and UIParent:GetHeight() > 0 then
        local scale = window:GetScale()
        db.x = math.max(0, math.min(1, x * scale / UIParent:GetWidth()))
        db.y = math.max(0, math.min(1, y * scale / UIParent:GetHeight()))
    end
    RestorePosition()
end

local function Visible()
    if window.IsVisible then return window:IsVisible() end
    return window:IsShown()
end

local function SyncTicker()
    if IsTracking() and (xpRetry or (Visible() and not preview)) then
        if not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
            ticker = C_Timer.NewTicker(1, function()
                if not ticker then return end
                ObserveXP()
                if Visible() and not preview then Draw() else SyncTicker() end
            end)
        end
    elseif ticker then
        if ticker.Cancel then ticker:Cancel() end
        ticker = nil
    end
end

Draw = function()
    if not db then return end
    if preview and InCombat() then preview, expanded = false, false end
    if not preview and (not db.enabled or (db.hideCombat and InCombat())) then
        window:Hide()
        SyncTicker()
        return
    end
    local style = SharedStyle()
    local theme = style or themes[db.theme]
    local fontSize = style and style.fontSize or db.fontSize
    local padding = style and style.padding or 12
    local collapsed = db.compact and not (db.expandOnHover and expanded)
    window:SetWidth(db.width)
    local previousScale = window:GetScale()
    window:SetScale(style and style.scale or 1)
    if previousScale ~= window:GetScale() and not moving then RestorePosition() end
    window:SetBackdropColor(theme.bg[1], theme.bg[2], theme.bg[3], style and style.opacity or db.opacity / 100)
    if style and ns.UI.StyleFrame then ns.UI.StyleFrame(window, "session")
    elseif not style then
        window:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3}})
        window:SetBackdropColor(theme.bg[1], theme.bg[2], theme.bg[3], db.opacity / 100)
    end
    window:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], db.border and 0.7 or 0)
    window:EnableMouse(not db.locked)
    if window.EnableMouseMotion then window:EnableMouseMotion(not db.locked or (db.compact and db.expandOnHover)) end
    local font = style and style.font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    title:SetFont(font, fontSize + 1, "")
    names:SetFont(font, fontSize, "")
    values:SetFont(font, fontSize, "")
    footer:SetFont(font, math.max(10, fontSize - 2), "")
    names:SetTextColor(unpack(theme.text)); values:SetTextColor(unpack(theme.text))
    title:SetTextColor(unpack(theme.accent)); footer:SetTextColor(unpack(theme.accent))
    local spacing = collapsed and 2 or (style and style.gap or 6)
    names:SetSpacing(spacing); values:SetSpacing(spacing)
    title:SetShown(db.showTitle)
    local headerHeight = math.max(trackingToggleSize, fontSize + 2)
    local headerY = -padding - headerHeight / 2
    trackingToggle:ClearAllPoints()
    trackingToggle:SetPoint("RIGHT", window, "TOPRIGHT", -padding, headerY)
    trackingToggle:SetShown(db.showTitle)
    local canToggle = ready and not preview
    trackingToggle:SetEnabled(canToggle)
    trackingToggle.icon:SetAlpha(canToggle and 1 or 0.5)
    -- An AFK pause still resumes automatically unless the player stops tracking.
    trackingToggle.icon:SetTexture(ready and session.pause ~= "manual"
        and "Interface\\TimeManager\\PauseButton" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    if trackingTooltip:IsShown() then
        if canToggle then trackingTooltip:SetText(TrackingAction()); trackingTooltip:Show()
        else trackingTooltip:Hide() end
    end
    names:ClearAllPoints(); values:ClearAllPoints()
    local top = db.showTitle and (headerHeight + padding * 2) or padding
    title:ClearAllPoints()
    title:SetPoint("LEFT", window, "TOPLEFT", padding, headerY)
    title:SetPoint("RIGHT", trackingToggle, "LEFT", -6, 0)
    title:SetText(preview and L("Journal de session • Aperçu") or ready and pauseLabels[session.pause] or L("Journal de session"))
    names:SetPoint("TOPLEFT", padding, -top)
    values:SetPoint("TOPRIGHT", -padding, -top)
    names:SetWidth(db.width * 0.43 - 12)
    values:SetWidth(db.width * 0.57 - 12)
    local labelLines, valueLines, rowIndices = {}, {}, {}
    local elapsed = math.floor(Elapsed())
    local data = {duration = Duration(elapsed), nextLevel = NextLevel(elapsed)}
    local raw = Model.Totals(session, elapsed)
    if session then
        local prefix = session.approximateXP and "≥ " or ""
        data.xp = prefix .. math.floor(raw.xp)
        data.income, data.expense, data.net = Money(raw.income), Money(raw.expense), Money(raw.net)
        data.deaths, data.levels = tostring(raw.deaths), tostring(raw.levels)
    end
    if preview then
        data = {duration = "00:42:18", xp = "12450", nextLevel = "~ 00:18:32", income = Money(183456), expense = Money(24500), net = Money(158956), deaths = "1", levels = "2"}
        raw = {}
    end
    local byKey = {}; for _, metric in ipairs(metrics) do byKey[metric.key] = metric end
    for _, key in ipairs(db.order) do
        local metric = byKey[key]
        if db.visible[key] and not (db.hideZero and raw[key] == 0) then
            -- Native client textures, sized to the text to keep both columns aligned.
            labelLines[#labelLines + 1] = string.format("|TInterface\\Icons\\%s:%d:%d:0:0:64:64:4:60:4:60|t %s", metric.icon, fontSize, fontSize, metric.label)
            valueLines[#valueLines + 1] = data[metric.key] or "—"
            rowIndices[metric.key] = #labelLines
            if collapsed and #labelLines >= 3 then break end
        end
    end
    if #labelLines == 0 then labelLines[1], valueLines[1] = L("Aucune statistique affichée"), "" end
    names:SetText(table.concat(labelLines, "\n")); values:SetText(table.concat(valueLines, "\n"))
    local horizontal = db.layout == "horizontal"
    if horizontal then
        local cells = {}
        for index, label in ipairs(labelLines) do cells[index] = string.format(L("%s : %s"), label, valueLines[index]) end
        names:SetText(table.concat(cells, "   •   ")); values:SetText("")
    end
    -- Keep columns aligned at large font sizes; the configured width is a minimum.
    local labelWidth, valueWidth = names:GetUnboundedStringWidth(), values:GetUnboundedStringWidth()
    local width = math.max(db.width, labelWidth + valueWidth + padding * 2 + 16)
    local horizontalPositions, horizontalHeight = {}, 0
    if horizontal then
        width = math.min(width, math.max(240, UIParent:GetWidth() / window:GetScale() - 24))
        local x, y, rowHeight = padding, 0, fontSize + spacing
        for index, label in ipairs(labelLines) do
            local text = horizontalTexts[index]
            if not text then text = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); horizontalTexts[index] = text end
            text:SetFont(font, fontSize, ""); text:SetTextColor(unpack(theme.text)); text:SetJustifyH("LEFT")
            text:SetText(string.format(L("%s : %s"), label, valueLines[index]))
            local cellWidth = math.min(width - padding * 2, text:GetUnboundedStringWidth() + 4)
            if x > padding and x + cellWidth > width - padding then x, y = padding, y + rowHeight; rowHeight = fontSize + spacing end
            text:ClearAllPoints(); text:SetPoint("TOPLEFT", x, -top - y); text:SetWidth(cellWidth); text:Show()
            local cellHeight = math.max(fontSize, text:GetStringHeight())
            rowHeight = math.max(rowHeight, cellHeight + spacing)
            horizontalPositions[index] = {x = x, y = y, width = cellWidth, height = cellHeight}
            x = x + cellWidth + 20
            horizontalHeight = y + rowHeight
        end
    end
    names:SetShown(not horizontal); values:SetShown(not horizontal)
    for index, text in ipairs(horizontalTexts) do if not horizontal or index > #labelLines then text:Hide() end end
    window:SetWidth(width)
    names:SetWidth(labelWidth + 2); values:SetWidth(width - labelWidth - padding * 2 - 16)
    footer:SetText(L("Glisser • clic droit pour verrouiller"))
    moveHint:SetWidth(math.min(width, footer:GetUnboundedStringWidth() + 16))
    moveHint:SetHeight(footer:GetStringHeight() + 12)
    moveHint:SetBackdropColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.95)
    moveHint:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.7)
    moveHint:SetShown(not db.locked)
    local contentHeight = horizontal and horizontalHeight or math.max(names:GetStringHeight(), values:GetStringHeight())
    local rowHeight = (contentHeight + spacing) / math.max(1, #labelLines)
    for key, row in pairs(hoverRows) do
        if rowIndices[key] then
            row:ClearAllPoints()
            if horizontal then
                local cell = horizontalPositions[rowIndices[key]]
                row:SetPoint("TOPLEFT", window, "TOPLEFT", cell.x, -top - cell.y)
                row:SetSize(cell.width, cell.height)
            else
                row:SetPoint("TOPLEFT", window, "TOPLEFT", padding, -top - (rowIndices[key] - 1) * rowHeight)
                row:SetSize(width - padding * 2, rowHeight)
            end
            row:EnableMouse(false)
            row:EnableMouseMotion(db.locked) -- Hover only; clicks still pass through while locked.
            row:Show()
        else row:Hide() end
    end
    -- Movement help is an independent overlay: unlocking never reserves space
    -- inside the journal or changes its screen-clamping rectangle.
    window:SetHeight(top + contentHeight + padding + 2)
    window:Show()
    RefreshRateTooltip()
    SyncTicker()
end

local function StopPreview()
    preview, expanded = false, false
    if window then Draw() end
end

local function Preview()
    if InCombat() then return end
    preview = true; Draw()
end

local function Place()
    preview = false
    db.enabled, db.locked = true, false
    if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
    Draw(); refreshSettings()
end

local function TrackingStatus()
    if not ready then return "" end
    return pauseLabels[session.pause] or L("Session en cours")
end

local function SetTracking(enabled)
    if not ready then return end
    if not enabled then SetPause("manual")
    elseif session.pause == "manual" then SetPause(AFKPause())
    else SyncAFK() end
    Draw(); refreshSettings()
end

function ns.InitializeSessionJournal(parentCategory)
    if type(ArkannsQOLSessionDB) ~= "table" then ArkannsQOLSessionDB = {} end
    db = ArkannsQOLSessionDB
    NormalizeOptions()
    window = CreateFrame("Frame", "ArkannsQOLSessionWindow", UIParent, "BackdropTemplate")
    window:SetFrameStrata("MEDIUM"); window:SetMovable(true); window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3}})
    title = window:CreateFontString("ArkannsQOLSessionTitle", "OVERLAY", "GameFontNormal")
    title:SetJustifyH("LEFT"); title:SetWordWrap(false)
    trackingToggle = CreateFrame("Button", "ArkannsQOLSessionTrackingToggle", window)
    trackingToggle:SetSize(trackingToggleSize, trackingToggleSize)
    trackingToggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    trackingToggle.icon = trackingToggle:CreateTexture(nil, "ARTWORK")
    trackingToggle.icon:SetAllPoints()
    trackingTooltip = CreateFrame("GameTooltip", "ArkannsQOLSessionTrackingTooltip", UIParent, "GameTooltipTemplate")
    trackingTooltip:SetClampedToScreen(true); trackingTooltip:Hide()
    trackingToggle:SetScript("OnClick", function()
        if ready and not preview then SetTracking(session.pause == "manual") end
    end)
    trackingToggle:SetScript("OnEnter", function(self)
        if not ready or preview then return end
        trackingTooltip:SetOwner(self, "ANCHOR_TOP")
        trackingTooltip:SetText(TrackingAction())
        trackingTooltip:Show()
    end)
    local function CollapseOnLeave()
        if expanded and not (window.IsMouseOver and window:IsMouseOver()) then expanded = false; Draw() end
    end
    trackingToggle:SetScript("OnLeave", function()
        trackingTooltip:Hide()
        CollapseOnLeave()
    end)
    trackingToggle:SetScript("OnHide", function() trackingTooltip:Hide() end)
    names = window:CreateFontString("ArkannsQOLSessionNames", "OVERLAY", "GameFontHighlight")
    names:SetJustifyH("LEFT")
    values = window:CreateFontString("ArkannsQOLSessionValues", "OVERLAY", "GameFontHighlight")
    values:SetJustifyH("RIGHT")
    moveHint = CreateFrame("Frame", "ArkannsQOLSessionMoveHint", window, "BackdropTemplate")
    moveHint:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 0, 6)
    moveHint:SetClampedToScreen(true); moveHint:EnableMouse(false)
    moveHint:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    footer = moveHint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("TOPLEFT", 8, -6); footer:SetPoint("TOPRIGHT", -8, -6)
    rateTooltip = CreateFrame("GameTooltip", "ArkannsQOLSessionTooltip", UIParent, "GameTooltipTemplate")
    rateTooltip:SetClampedToScreen(true); rateTooltip:Hide()
    for _, key in ipairs({"xp", "income"}) do
        local row = CreateFrame("Frame", "ArkannsQOLSessionHover_" .. key, window)
        row.metric = key
        row:SetScript("OnEnter", function(self)
            if db.compact and db.expandOnHover and not expanded then expanded = true; Draw() end
            hovered = self; RefreshRateTooltip()
        end)
        row:SetScript("OnLeave", function(self)
            HideRateTooltip(self)
            if expanded and window.IsMouseOver and not window:IsMouseOver() then expanded = false; Draw() end
        end)
        row:SetScript("OnHide", HideRateTooltip)
        hoverRows[key] = row
    end
    window:SetScript("OnDragStart", function(self) if not db.locked then moving = true; self:StartMoving() end end)
    window:SetScript("OnDragStop", SavePosition)
    window:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" and not db.locked then SavePosition(); db.locked = true; Draw(); refreshSettings() end
    end)
    window:SetScript("OnShow", SyncTicker)
    window:SetScript("OnHide", function()
        preview, expanded = false, false
        HideRateTooltip()
        if moving then SavePosition() end
        SyncTicker()
    end)
    window:SetScript("OnEnter", function() if db.compact and db.expandOnHover then expanded = true; Draw() end end)
    window:SetScript("OnLeave", CollapseOnLeave)
    RestorePosition()

    local panel = CreateFrame("Frame", "ArkannsQOLSessionSettings", UIParent, "BackdropTemplate")
    panel:Hide()
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -48); scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(620, 740); scroll:SetScrollChild(body)
    local function Page(name, height)
        local page = CreateFrame("ScrollFrame", name, panel, "UIPanelScrollFrameTemplate")
        page:SetPoint("TOPLEFT", 0, -48); page:SetPoint("BOTTOMRIGHT", -28, 8)
        local content = CreateFrame("Frame", nil, page)
        content:SetSize(620, height); page:SetScrollChild(content)
        page:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
        page:Hide()
        return page, content
    end
    local operationBody = body
    scroll:SetScript("OnSizeChanged", function(_, width) operationBody:SetWidth(math.max(1, width)) end)
    local appearancePage, appearanceBody = Page("ArkannsQOLSessionAppearance", 490)
    local visibilityPage, visibilityBody = Page("ArkannsQOLSessionVisibility", 310)
    local function Tab(label, x, page, name)
        local button = CreateFrame("Button", name, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, -10); button:SetSize(190, 26); button:SetText(label)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        button:SetScript("OnClick", function()
            StopPreview()
            scroll:SetShown(page == scroll); appearancePage:SetShown(page == appearancePage); visibilityPage:SetShown(page == visibilityPage)
            if page == appearancePage then Preview() end
            refreshSettings()
        end)
    end
    Tab(L("Fonctionnement"), 16, scroll, "ArkannsQOLSessionOperationTab")
    Tab(L("Apparence"), 216, appearancePage, "ArkannsQOLSessionAppearanceTab")
    Tab(L("Visibilité"), 416, visibilityPage, "ArkannsQOLSessionVisibilityTab")
    if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(panel) end
    local function Text(text, y, font)
        local label = body:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 16, y); label:SetPoint("TOPRIGHT", -16, y); label:SetJustifyH("LEFT"); label:SetText(text)
        return label
    end
    local controls, syncing = {}, false
    local function Check(key, label, y, source, onChange)
        local box = CreateFrame("CheckButton", "ArkannsQOLSession_" .. key, body, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 12, y)
        local text = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        text:SetPoint("LEFT", box, "RIGHT", 2, 0); text:SetText(label); box:SetFontString(text)
        controls[#controls + 1] = function() box:SetChecked(source[key]) end
        box:SetScript("OnClick", function(self)
            source[key] = self:GetChecked() == true
            if onChange then onChange() end
            Draw(); refreshSettings()
        end)
    end
    local function Button(name, label, x, y, callback)
        local button = CreateFrame("Button", name, body, "UIPanelButtonTemplate")
        button:SetSize(190, 26); button:SetPoint("TOPLEFT", x, y); button:SetText(label); button:SetScript("OnClick", callback)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        return button
    end
    local function Slider(key, label, y, minimum, maximum)
        local text = Text("", y, "GameFontNormal")
        local slider = CreateFrame("Slider", "ArkannsQOLSession_" .. key, body, "BackdropTemplate")
        slider:SetPoint("TOPLEFT", 20, y - 24); slider:SetSize(330, 18)
        slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(minimum, maximum)
        slider:SetValueStep(1); slider:SetObeyStepOnDrag(true); slider:EnableMouse(true)
        slider:SetBackdrop({bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", edgeSize = 8})
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); slider:GetThumbTexture():SetSize(32, 32)
        controls[#controls + 1] = function() slider:SetValue(db[key]); text:SetText(string.format(L("%s : %s"), label, tostring(db[key]))) end
        slider:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            db[key] = math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
            Draw(); refreshSettings()
        end)
    end
    Text(L("Fonctionnement"), -8, "GameFontNormalLarge")
    local trackingStatus = Text("", -46)
    trackingStatus:ClearAllPoints()
    trackingStatus:SetPoint("TOPLEFT", 218, -46); trackingStatus:SetPoint("TOPRIGHT", -16, -46)
    local trackingButton = Button("ArkannsQOLSessionTracking", "", 16, -40, function()
        SetTracking(ready and session.pause == "manual")
    end)
    Check("pauseAFK", L("Mettre en pause pendant l’AFK"), -76, db, SyncAFK)
    local selectionStatus = Text("", -120)
    for index = 1, #metrics do
        local rowIndex = index
        local box = CreateFrame("CheckButton", "ArkannsQOLSessionMetric" .. index, body, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 12, -150 - (index - 1) * 32)
        local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", box, "RIGHT", 2, 0); box:SetFontString(label)
        controls[#controls + 1] = function()
            local key = db.order[rowIndex]
            box:SetChecked(db.visible[key])
            for _, metric in ipairs(metrics) do if metric.key == key then label:SetText(metric.label) end end
        end
        box:SetScript("OnClick", function(self) db.visible[db.order[rowIndex]] = self:GetChecked() == true; Draw(); refreshSettings() end)
        for _, direction in ipairs({-1, 1}) do
            local delta = direction
            local button = Button("ArkannsQOLSessionMove" .. (delta == -1 and "Up" or "Down") .. index, "", delta == -1 and 370 or 410, -152 - (index - 1) * 32, function()
                local target = rowIndex + delta
                if target >= 1 and target <= #db.order then db.order[rowIndex], db.order[target] = db.order[target], db.order[rowIndex]; refreshSettings(); Draw() end
            end)
            button:SetWidth(30)
            -- Text arrows are missing from some WoW fonts. Keep the icon separate
            -- from the normal texture so common button styling cannot replace it.
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetSize(18, 18); icon:SetPoint("CENTER")
            icon:SetTexture(delta == -1 and "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up" or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
            controls[#controls + 1] = function()
                local enabled = rowIndex + delta >= 1 and rowIndex + delta <= #db.order
                button:SetEnabled(enabled); icon:SetAlpha(enabled and 1 or 0.3)
            end
        end
    end
    Check("hideZero", L("Masquer les valeurs nulles"), -420, db)
    Check("compact", L("Mode compact (3 statistiques)"), -452, db)
    Check("expandOnHover", L("Développer au survol"), -484, db)
    local showAll = Button("ArkannsQOLSessionShowAll", L("Tout afficher"), 370, -452, function()
        for _, metric in ipairs(metrics) do db.visible[metric.key] = true end
        db.compact, db.hideZero, expanded = false, false, false
        Draw(); refreshSettings()
    end)
    showAll:SetWidth(160)
    controls[#controls + 1] = function()
        local count = 0
        for _, metric in ipairs(metrics) do if db.visible[metric.key] then count = count + 1 end end
        local status = string.format(L("Sélection : %d"), count)
        if db.compact then
            status = status .. L(" / Mode compact : 3")
            if db.expandOnHover then status = status .. L(" / Survol : tout") end
        end
        if db.hideZero then status = status .. L(" / Zéros masqués") end
        selectionStatus:SetText(status)
        ArkannsQOLSession_expandOnHover:SetEnabled(db.compact)
        showAll:SetEnabled(count < #metrics or db.compact or db.hideZero)
    end
    local layoutButton = Button("ArkannsQOLSessionLayout", "", 16, -530, function()
        db.layout = db.layout == "horizontal" and "vertical" or "horizontal"; Draw(); refreshSettings()
    end)
    Button(nil, L("Défauts de cette section"), 218, -530, function()
        for key in pairs(db.order) do db.order[key] = nil end
        db.hideZero, db.compact, db.expandOnHover, db.layout = false, false, true, "vertical"
        db.pauseAFK = false
        for _, metric in ipairs(metrics) do db.visible[metric.key] = metric.key ~= "levels" end
        NormalizeOptions(); SyncAFK(); Draw(); refreshSettings()
    end)
    local resetButton = Button("ArkannsQOLSessionReset", L("Réinitialiser les stats"), 16, -570, function()
        if not ready then return end
        BeginSession(nil, session.pause); Draw(); refreshSettings()
    end)
    Text(L("Survole XP gagnée ou Or reçu pour le taux horaire.\nLe démarrage reprend les compteurs. L’option AFK suspend le suivi jusqu’au retour.\nUne nouvelle connexion remet les compteurs à zéro et démarre le suivi.\n/reload conserve les compteurs et l’arrêt manuel. ≥ indique des données XP incomplètes."), -620)
    body = appearanceBody
    Text(L("Apparence"), -8, "GameFontNormalLarge")
    local override = Button(nil, "", 16, -42, function()
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("session", not ns.UI.IsOverride("session")) end
        Draw(); refreshSettings()
    end)
    Text(L("Police, opacité et thème : apparence personnalisée."), -78)
    Check("showTitle", L("Afficher le titre"), -104, db)
    Check("border", L("Afficher la bordure"), -136, db)
    Slider("width", L("Largeur min."), -182, 240, 1000)
    Slider("fontSize", L("Taille du texte"), -240, 10, 32)
    Slider("opacity", L("Opacité du fond (%)"), -298, 0, 100)
    local themeButton = Button("ArkannsQOLSessionTheme", "", 16, -362, function(self)
        MenuUtil.CreateContextMenu(self, function(_, root)
            for _, key in ipairs({"dark", "warm", "light"}) do
                local themeKey = key
                root:CreateButton(themes[key].label, function() db.theme = themeKey; Draw(); refreshSettings() end)
            end
        end)
    end)
    Button(nil, L("Défauts de cette section"), 218, -362, function()
        db.theme, db.width, db.fontSize, db.opacity, db.showTitle, db.border = "warm", 300, 13, 85, true, true
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("session", false) end
        Draw(); refreshSettings()
    end)
    body = visibilityBody
    Text(L("Visibilité"), -8, "GameFontNormalLarge")
    Check("enabled", L("Afficher la fenêtre"), -48, db)
    Check("hideCombat", L("Masquer en combat"), -80, db)
    local lockButton = Button("ArkannsQOLSessionPlace", "", 16, -130, function()
        if db.locked then Place()
        else SavePosition(); db.locked = true; Draw(); refreshSettings() end
    end)
    Button("ArkannsQOLSessionCenter", L("Recentrer"), 218, -130, function()
        SavePosition(); db.x, db.y = 0.35, 0.7; RestorePosition(); Place()
    end)
    Button(nil, L("Défauts de cette section"), 16, -174, function()
        db.enabled, db.hideCombat, db.locked, db.x, db.y = true, false, true, 0.02, 0.75
        RestorePosition(); Draw(); refreshSettings()
    end)
    Text(L("Glisser : déplacer • Clic droit : verrouiller.\nL'aperçu disparaît à la fermeture des réglages."), -226)
    refreshSettings = function()
        syncing = true
        for _, sync in ipairs(controls) do sync() end
        local pause = ready and session.pause
        local status = TrackingStatus()
        if ready and pause ~= "manual" and afkUnavailable then status = status .. "\n" .. L("Statut AFK indisponible") end
        trackingStatus:SetText(status)
        trackingButton:SetText(TrackingAction())
        trackingButton:SetEnabled(ready)
        resetButton:SetEnabled(ready)
        themeButton:SetText(string.format(L("Thème : %s"), themes[db.theme].label))
        layoutButton:SetText(db.layout == "horizontal" and L("Disposition : ligne") or L("Disposition : liste"))
        override:SetText(ns.UI and ns.UI.IsOverride and ns.UI.IsOverride("session") and L("Apparence personnalisée") or L("Apparence commune"))
        lockButton:SetText(db.locked and L("Déverrouiller") or L("Verrouiller"))
        syncing = false
    end
    panel:SetScript("OnShow", function()
        operationBody:SetWidth(math.max(1, scroll:GetWidth())); refreshSettings()
        if appearancePage:IsShown() then Preview() end
    end)
    panel:SetScript("OnHide", StopPreview)
    settings = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, L("Journal de session"))
    ns.sessionCategory = settings
    SLASH_ARKANNSQOLSESSION1 = "/qtsession"
    SLASH_ARKANNSQOLSESSION2 = "/aqsession"
    SlashCmdList.ARKANNSQOLSESSION = function(message)
        local command = type(message) == "string" and message:lower():match("^%s*(%S+)%s*$")
        if command == "start" or command == "stop" then
            SetTracking(command == "start")
            if ready then print(L("Journal de session") .. " · " .. TrackingStatus()) end
        else
            Settings.OpenToCategory(settings:GetID())
        end
    end
    refreshSettings(); Draw()

    if ns.RegisterModule then
        local configKeys = {"enabled", "locked", "showTitle", "border", "compact", "hideZero", "expandOnHover", "hideCombat", "pauseAFK", "x", "y", "width", "fontSize", "opacity", "theme", "layout"}
        ns.RegisterModule("session", {
            label = L("Journal de session"), icon = "Interface\\Icons\\INV_Misc_Book_09", category = function() return settings end,
            frame = window, IsEnabled = function() return db.enabled end,
            SetEnabled = function(value) db.enabled = value == true; if not db.enabled then preview = false end; Draw(); refreshSettings() end,
            Summary = function()
                if db.compact then return L("Mode compact · 3 statistiques") end
                return db.layout == "horizontal" and L("Statistiques en ligne") or L("Statistiques de la session")
            end,
            Preview = Preview, StopPreview = StopPreview,
            Refresh = function() Draw(); refreshSettings() end,
            GetPosition = function()
                local x, y = window:GetCenter()
                local scale = window:GetScale()
                return x and x * scale / UIParent:GetWidth() or db.x, y and y * scale / UIParent:GetHeight() or db.y
            end,
            SetPosition = function(x, y)
                if not Number(x) or not Number(y) then return end
                local scale = window:GetScale()
                db.x = math.max(0, math.min(1, x - window:GetWidth() * scale / (2 * UIParent:GetWidth())))
                db.y = math.max(0, math.min(1, y + window:GetHeight() * scale / (2 * UIParent:GetHeight())))
                RestorePosition(); Draw()
            end,
            ExportSettings = function()
                local result = {visible = {}, order = {}}
                for _, key in ipairs(configKeys) do result[key] = db[key] end
                for _, metric in ipairs(metrics) do result.visible[metric.key] = db.visible[metric.key] end
                for index, key in ipairs(db.order) do result.order[index] = key end
                return result
            end,
            profileMigrations = {function(config)
                if config.pauseAFK == nil then config.pauseAFK = false end
            end},
            ImportSettings = function(config)
                if type(config) ~= "table" then return false, L("Réglages du journal invalides.") end
                if moving then window:StopMovingOrSizing(); moving = false end
                StopPreview()
                for _, key in ipairs(configKeys) do if config[key] ~= nil then db[key] = config[key] end end
                if type(config.visible) == "table" then
                    for _, metric in ipairs(metrics) do if type(config.visible[metric.key]) == "boolean" then db.visible[metric.key] = config.visible[metric.key] end end
                end
                if type(config.order) == "table" then
                    local order = {}; for _, key in ipairs(config.order) do if type(key) == "string" then order[#order + 1] = key end end
                    for key in pairs(db.order) do db.order[key] = nil end
                    for index, key in ipairs(order) do db.order[index] = key end
                end
                NormalizeOptions(); SyncAFK(); StopPreview(); RestorePosition(); Draw(); refreshSettings()
                return true
            end,
        })
    end

    local events = CreateFrame("Frame", "ArkannsQOLSessionEvents")
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_FLAGS_CHANGED", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_LOGOUT", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event, first, reloading)
        if event == "PLAYER_ENTERING_WORLD" then
            if not ready or (WoW.IsPublic(first) and first) then
                BeginSession(WoW.IsPublic(reloading) and reloading == true and db.session)
            else
                SyncAFK()
            end
            refreshSettings()
        elseif event == "PLAYER_FLAGS_CHANGED" then
            if not db.pauseAFK or not ready or session.pause == "manual" or not WoW.IsPublic(first) or first ~= "player" then return end
            SyncAFK(); refreshSettings()
        elseif event == "PLAYER_LEVEL_UP" then
            ObserveXP(first)
        elseif event == "PLAYER_XP_UPDATE" then
            if WoW.IsPublic(first) and first == "player" then ObserveXP() end
        elseif event == "PLAYER_MONEY" then
            ObserveMoney()
        elseif event == "PLAYER_DEAD" and IsTracking() then
            Model.RecordDeath(session)
        elseif (event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST") and IsTracking() then
            ObserveDeath(false)
        elseif event == "PLAYER_LOGOUT" and ready then
            ObserveMoney(); ObserveXP(); SavePosition()
            session.elapsed = Elapsed()
            startedAt, ready = nil, false
        elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
            if moving then SavePosition() else RestorePosition() end
        end
        Draw()
    end)
end
