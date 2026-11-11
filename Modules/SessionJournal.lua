local _, ns = ...
local L = ns.L
local Model, WoW = ns.SessionJournalModel, ns.WoW
local db, session, window, title, names, values, footer, settings, refreshSettings
local ready, moving = false, false
local startedAt
local afkUnavailable
local ticker, historyTicker, xpRetry, Draw
local refreshHistory
local rateTooltip, hovered
local moveHint
local trackingToggle, trackingTooltip
local trackingToggleSize = 20
local hoverRows = {}
local horizontalTexts = {}
local preview, expanded = false, false
local layoutPreview = false
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

local function WallTime()
    return ReadNumber(GetServerTime) or ReadNumber(time)
end

local function Checkpoint()
    if not ready then return end
    Model.Sample(session, Elapsed(), true)
    session.checkpointAt = WallTime()
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
        ObserveMoney(); ObserveXP(); ObserveDeath(true)
        Checkpoint()
        session.elapsed = Elapsed()
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
        if Model.IsResumable(db.session) then
            Model.Archive(db, db.session, db.session.elapsed, db.session.checkpointAt, "logout")
        end
        local xp, maximum, level = XPState()
        session = Model.New(xp, maximum, level, ReadNumber(GetMoney))
    end
    Model.StartHistory(session, WallTime(), session.elapsed)
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
    if IsTracking() then
        if not historyTicker and C_Timer and type(C_Timer.NewTicker) == "function" then
            historyTicker = C_Timer.NewTicker(30, function()
                if not IsTracking() then return end
                Model.Sample(session, Elapsed())
                session.checkpointAt = WallTime()
                if refreshHistory then refreshHistory() end
            end)
        end
    elseif historyTicker then
        historyTicker:Cancel(); historyTicker = nil
    end
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
    if preview and InCombat() then
        preview, expanded, layoutPreview = false, false, false
        if ns.UI.PreviewEnded then ns.UI.PreviewEnded("session") end
    end
    window:SetFrameStrata(preview and not layoutPreview and "DIALOG" or "MEDIUM")
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
    window:EnableMouse(not layoutPreview and not db.locked)
    if window.EnableMouseMotion then window:EnableMouseMotion(not layoutPreview and (not db.locked or (db.compact and db.expandOnHover))) end
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
    trackingToggle:EnableMouse(not layoutPreview)
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
    moveHint:SetShown(not layoutPreview and not db.locked)
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
            row:EnableMouseMotion(not layoutPreview and db.locked) -- Hover only; clicks still pass through while locked.
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
    preview, expanded, layoutPreview = false, false, false
    if ns.UI.PreviewEnded then ns.UI.PreviewEnded("session") end
    if window then Draw() end
end

local function Preview(forLayout)
    forLayout = forLayout == true
    if InCombat() then return false, L("Aperçu disponible hors combat.") end
    preview, layoutPreview = true, forLayout == true; Draw()
    if forLayout then window:EnableMouse(false) end
    return true
end

local function Place()
    return ns.UI.StartLayout("session")
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
    if (db.historyVersion ~= nil and db.historyVersion ~= 1)
        or (type(db.session) == "table" and db.session.historyVersion ~= nil and db.session.historyVersion ~= 1) then
        if ns.UI.Notify then ns.UI.Notify(L("Version des réglages non prise en charge. Utilise une version compatible de l’addon.")) end
        return
    end
    NormalizeOptions()
    Model.NormalizeHistory(db)
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
    for _, key in ipairs({"xp", "net"}) do
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
        preview, expanded, layoutPreview = false, false, false
        if ns.UI.PreviewEnded then ns.UI.PreviewEnded("session") end
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
    body:SetSize(620, 880); scroll:SetScrollChild(body)
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
    local appearancePage, displayBody = Page("ArkannsQOLSessionAppearance", 900)
    local historyPage, historyBody = Page("ArkannsQOLSessionHistory", 1100)
    local visibilityBody = CreateFrame("Frame", "ArkannsQOLSessionVisibility", displayBody)
    visibilityBody:SetPoint("TOPLEFT"); visibilityBody:SetPoint("TOPRIGHT"); visibilityBody:SetHeight(360)
    local appearanceBody = CreateFrame("Frame", nil, displayBody)
    appearanceBody:SetPoint("TOPLEFT", 0, -360); appearanceBody:SetPoint("TOPRIGHT", 0, -360); appearanceBody:SetSize(620, 340)
    local LayoutDisplay
    local tabs, activePage = {}, scroll
    local function SelectPage(page)
        activePage = page
        for _, tab in ipairs(tabs) do tab:SetEnabled(tab.page ~= page) end
        StopPreview()
        scroll:SetShown(page == scroll); appearancePage:SetShown(page == appearancePage)
        historyPage:SetShown(page == historyPage)
        if page == appearancePage then Preview() end
        refreshSettings()
    end
    local function Tab(label, x, page, name)
        local button = CreateFrame("Button", name, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, -10); button:SetSize(190, 26); button:SetText(label)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        tabs[#tabs + 1] = button
        button.page = page
        button:SetEnabled(page ~= activePage)
        button:SetScript("OnClick", function()
            SelectPage(page)
        end)
    end
    Tab(L("Suivi et statistiques"), 16, scroll, "ArkannsQOLSessionOperationTab")
    Tab(L("Affichage"), 216, appearancePage, "ArkannsQOLSessionAppearanceTab")
    Tab(L("Historique et progression"), 416, historyPage, "ArkannsQOLSessionHistoryTab")
    local function LayoutTabs()
        local width = math.max(280, panel:GetWidth() - 32)
        local columns = width >= 600 and 3 or (width >= 450 and 2 or 1)
        local size = (width - (columns - 1) * 8) / columns
        for index, button in ipairs(tabs) do
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", 16 + ((index - 1) % columns) * (size + 8), -10 - math.floor((index - 1) / columns) * 34)
            button:SetWidth(size)
        end
        for _, page in ipairs({scroll, appearancePage, historyPage}) do
            page:ClearAllPoints(); page:SetPoint("TOPLEFT", 0, -16 - math.ceil(#tabs / columns) * 34); page:SetPoint("BOTTOMRIGHT", -28, 8)
        end
    end
    panel:HookScript("OnSizeChanged", LayoutTabs)
    local function ArchiveAndRestart()
        if not ready then return end
        ObserveMoney(); ObserveXP(); Checkpoint()
        Model.Archive(db, session, Elapsed(), WallTime(), "manual")
        local pause = session.pause
        -- BeginSession sees the archived session and cannot save it twice.
        BeginSession(nil, pause)
        Draw(); refreshSettings()
    end
    refreshHistory = ns.CreateSessionHistoryPanel(historyBody, {
        GetHistory = function() return db.history end,
        GetCurrent = function()
            if not ready then return end
            local current = Model.Totals(session, Elapsed())
            current.startedAt, current.samples, current.approximateXP = session.startedAt, session.samples, session.approximateXP
            return current
        end,
        Now = WallTime, FormatMoney = Money, FormatDuration = Duration,
        NewSession = ArchiveAndRestart,
        Delete = function(entry)
            ns.UI.Confirm(L("Supprimer cette session de l’historique ?"), function()
                for index, saved in ipairs(db.history) do
                    if saved == entry then table.remove(db.history, index); break end
                end
                refreshHistory()
            end)
        end,
        Clear = function()
            ns.UI.Confirm(L("Effacer toutes les sessions enregistrées de ce personnage ? La session en cours est conservée."), function()
                db.history = {}; refreshHistory()
            end)
        end,
    })
    historyPage:HookScript("OnShow", function() refreshHistory() end)
    historyBody:HookScript("OnSizeChanged", function() ns.UI.ClampScroll(historyPage, historyBody:GetHeight()) end)
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
        return box
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
        slider:SetPoint("TOPLEFT", 20, y - 24); slider:SetPoint("TOPRIGHT", -20, y - 24); slider:SetHeight(18)
        slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(minimum, maximum)
        slider:SetValueStep(1); slider:SetObeyStepOnDrag(true); slider:EnableMouse(true)
        slider:SetBackdrop({bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", edgeSize = 8})
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); slider:GetThumbTexture():SetSize(32, 32)
        controls[#controls + 1] = function()
            local style = SharedStyle()
            local value = db[key]
            if style and key == "fontSize" then value = style.fontSize end
            if style and key == "opacity" then value = math.floor(style.opacity * 100 + .5) end
            slider:SetValue(value); text:SetText(string.format(L("%s : %s"), label, tostring(value)))
            local enabled = key ~= "fontSize" and key ~= "opacity" or ns.UI.IsOverride("session")
            slider:SetEnabled(enabled); slider:SetAlpha(enabled and 1 or .5)
            text:SetAlpha(enabled and 1 or .5)
        end
        slider:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            db[key] = math.max(minimum, math.min(maximum, math.floor(value + 0.5)))
            Draw(); refreshSettings()
        end)
    end
    Text(L("Suivi et statistiques"), -8, "GameFontNormalLarge")
    local trackingStatus = Text("", -36)
    local trackingButton = Button("ArkannsQOLSessionTracking", "", 16, -76, function()
        SetTracking(ready and session.pause == "manual")
    end)
    Check("pauseAFK", L("Mettre en pause pendant l’AFK"), -112, db, SyncAFK)
    local selectionStatus = Text("", -154)
    for index = 1, #metrics do
        local rowIndex = index
        local box = CreateFrame("CheckButton", "ArkannsQOLSessionMetric" .. index, body, "UICheckButtonTemplate")
        box:SetPoint("TOPLEFT", 12, -190 - (index - 1) * 32)
        local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", body, "TOPLEFT", 46, -198 - (index - 1) * 32)
        label:SetPoint("TOPRIGHT", body, "TOPRIGHT", -92, -198 - (index - 1) * 32)
        label:SetJustifyH("LEFT"); label:SetWordWrap(false)
        box:SetFontString(label)
        controls[#controls + 1] = function()
            local key = db.order[rowIndex]
            box:SetChecked(db.visible[key])
            for _, metric in ipairs(metrics) do if metric.key == key then label:SetText(metric.label) end end
        end
        box:SetScript("OnClick", function(self) db.visible[db.order[rowIndex]] = self:GetChecked() == true; Draw(); refreshSettings() end)
        for _, direction in ipairs({-1, 1}) do
            local delta = direction
            local button = Button("ArkannsQOLSessionMove" .. (delta == -1 and "Up" or "Down") .. index, "", 0, 0, function()
                local target = rowIndex + delta
                if target >= 1 and target <= #db.order then db.order[rowIndex], db.order[target] = db.order[target], db.order[rowIndex]; refreshSettings(); Draw() end
            end)
            button:SetWidth(30)
            button:ClearAllPoints(); button:SetPoint("TOPRIGHT", delta == -1 and -54 or -16, -192 - (index - 1) * 32)
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
    local showAll = Button("ArkannsQOLSessionShowAll", L("Tout afficher"), 16, -566, function()
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
        showAll:SetEnabled(count < #metrics or db.compact or db.hideZero)
    end
    local behaviorDefaults = Button(nil, L("Défauts de cette section"), 16, -646, function()
        ns.UI.Confirm(L("Rétablir la sélection des statistiques et la pause AFK ?"), function()
            for key in pairs(db.order) do db.order[key] = nil end
            db.pauseAFK = false
            for _, metric in ipairs(metrics) do db.visible[metric.key] = metric.key ~= "levels" end
            NormalizeOptions(); SyncAFK(); Draw(); refreshSettings()
        end)
    end)
    local resetButton = Button("ArkannsQOLSessionReset", L("Réinitialiser les stats"), 16, -686, function()
        if not ready then return end
        ns.UI.Confirm(L("Enregistrer cette session dans l’historique et remettre ses compteurs à zéro ?"), ArchiveAndRestart)
    end)
    local help = Text(L("Survole XP gagnée ou Solde pour le taux horaire.\nLe démarrage reprend les compteurs. L’option AFK suspend le suivi jusqu’au retour.\nUne nouvelle connexion remet les compteurs à zéro et démarre le suivi.\n/reload conserve les compteurs et l’arrêt manuel. ≥ indique des données XP incomplètes."), -730)
    local function LayoutOperation()
        local width = operationBody:GetWidth()
        local wide = width >= 460
        local y = 460
        showAll:ClearAllPoints(); showAll:SetPoint("TOPLEFT", 16, -y)
        y = y + 40
        behaviorDefaults:ClearAllPoints(); behaviorDefaults:SetPoint("TOPLEFT", 16, -y)
        resetButton:ClearAllPoints(); resetButton:SetPoint("TOPLEFT", wide and 216 or 16, -y - (wide and 0 or 34))
        y = y + (wide and 42 or 76)
        help:ClearAllPoints(); help:SetPoint("TOPLEFT", 16, -y); help:SetWidth(math.max(1, width - 32))
        local height = y + help:GetStringHeight() + 12
        operationBody:SetHeight(height)
        ns.UI.ClampScroll(scroll, height)
    end
    scroll:HookScript("OnSizeChanged", LayoutOperation)
    body = appearanceBody
    Text(L("Apparence"), -8, "GameFontNormalLarge")
    local override = Button(nil, "", 16, -42, function()
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("session", not ns.UI.IsOverride("session")) end
        Draw(); refreshSettings()
    end)
    local appearanceNotice = Text("", -78)
    Slider("fontSize", L("Taille du texte"), -126, 10, 32)
    Slider("opacity", L("Opacité du fond (%)"), -190, 0, 100)
    local themeButton = Button("ArkannsQOLSessionTheme", "", 16, -254, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        MenuUtil.CreateContextMenu(self, function(_, root)
            for _, key in ipairs({"dark", "warm", "light"}) do
                local themeKey = key
                root:CreateButton(themes[key].label, function() db.theme = themeKey; Draw(); refreshSettings() end)
            end
        end)
    end)
    local advanced = CreateFrame("Frame", nil, appearanceBody)
    advanced:SetPoint("TOPLEFT", 0, -370); advanced:SetPoint("TOPRIGHT", 0, -370); advanced:SetHeight(205); advanced:Hide()
    local advancedButton = Button("ArkannsQOLSessionAdvanced", L("Personnalisation avancée"), 16, -330, function(self)
        advanced:SetShown(not advanced:IsShown())
        self:SetText(advanced:IsShown() and L("Masquer la personnalisation avancée") or L("Personnalisation avancée"))
        local height = advanced:IsShown() and 558 or 374
        appearanceBody:SetHeight(height)
        if LayoutDisplay then LayoutDisplay() end
    end)
    advancedButton:SetWidth(260)
    if ns.UI.AddAppearanceLink then ns.UI.AddAppearanceLink(appearanceBody, "session", 16, -296, 260) end
    body = advanced
    Check("showTitle", L("Afficher le titre"), 0, db)
    Check("border", L("Afficher la bordure"), -34, db)
    Slider("width", L("Largeur min."), -80, 240, 1000)
    Button(nil, L("Défauts de cette section"), 16, -148, function()
        ns.UI.Confirm(L("Rétablir l’apparence par défaut du journal ?"), function()
            db.theme, db.width, db.fontSize, db.opacity, db.showTitle, db.border = "warm", 300, 13, 85, true, true
            ns.UI.SetOverride("session", false)
            Draw(); refreshSettings()
        end)
    end)
    appearanceBody:SetHeight(374)
    body = visibilityBody
    Text(L("Affichage"), -8, "GameFontNormalLarge")
    Check("enabled", L("Afficher la fenêtre"), -48, db)
    Check("hideCombat", L("Masquer en combat"), -80, db)
    Check("hideZero", L("Masquer les valeurs nulles"), -112, db)
    Check("compact", L("Mode compact (3 statistiques)"), -144, db)
    local expandOnHover = Check("expandOnHover", L("Développer au survol"), -176, db)
    local layoutButton = Button("ArkannsQOLSessionLayout", "", 16, -214, function()
        db.layout = db.layout == "horizontal" and "vertical" or "horizontal"; Draw(); refreshSettings()
    end)
    local lockButton = Button("ArkannsQOLSessionPlace", L("Déplacer"), 16, -130, Place)
    local previewButton = Button("ArkannsQOLSessionPreview", L("Aperçu"), 16, -164, Preview)
    local visibilityDefaults = Button(nil, L("Défauts de cette section"), 16, -174, function()
        ns.UI.Confirm(L("Rétablir l’affichage et la position par défaut du journal ?"), function()
            db.enabled, db.hideCombat, db.locked, db.x, db.y = true, false, true, 0.02, 0.75
            db.hideZero, db.compact, db.expandOnHover, db.layout = false, false, true, "vertical"
            RestorePosition(); Draw(); refreshSettings()
        end)
    end)
    local displayHelp = Text(L("Déplacer ouvre le mode Disposition.\nL'aperçu disparaît à la fermeture des réglages."), -226)
    LayoutDisplay = function()
        local width = math.max(1, displayBody:GetWidth())
        local wide = width >= 450
        visibilityBody:SetWidth(width); appearanceBody:SetWidth(width)
        expandOnHover:SetShown(db.compact)
        local y = db.compact and 214 or 182
        layoutButton:ClearAllPoints(); layoutButton:SetPoint("TOPLEFT", 16, -y)
        lockButton:ClearAllPoints(); lockButton:SetPoint("TOPLEFT", wide and 216 or 16, -y - (wide and 0 or 34))
        y = y + (wide and 40 or 74)
        visibilityDefaults:ClearAllPoints(); visibilityDefaults:SetPoint("TOPLEFT", 16, -y)
        previewButton:ClearAllPoints(); previewButton:SetPoint("TOPLEFT", wide and 216 or 16, -y - (wide and 0 or 34))
        y = y + (wide and 38 or 72)
        displayHelp:ClearAllPoints(); displayHelp:SetPoint("TOPLEFT", 16, -y); displayHelp:SetWidth(math.max(1, width - 32))
        y = y + displayHelp:GetStringHeight() + 24
        visibilityBody:SetHeight(y)
        appearanceBody:ClearAllPoints(); appearanceBody:SetPoint("TOPLEFT", 0, -y); appearanceBody:SetPoint("TOPRIGHT", 0, -y)
        local height = y + appearanceBody:GetHeight()
        displayBody:SetHeight(height)
        ns.UI.ClampScroll(appearancePage, height)
    end
    appearancePage:HookScript("OnSizeChanged", LayoutDisplay)
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
        themeButton:SetEnabled(ns.UI.IsOverride("session") and MenuUtil and MenuUtil.CreateContextMenu ~= nil)
        layoutButton:SetText(db.layout == "horizontal" and L("Disposition : ligne") or L("Disposition : liste"))
        override:SetText(ns.UI.IsOverride("session") and L("Apparence personnalisée") or L("Thème commun"))
        local note = ns.UI.IsOverride("session") and "" or L("Les réglages grisés utilisent le thème commun.")
        if appearancePage:IsShown() and InCombat() then note = note .. "\n" .. L("Aperçu disponible hors combat.") end
        appearanceNotice:SetText(note)
        lockButton:SetText(L("Déplacer"))
        LayoutOperation(); LayoutDisplay()
        syncing = false
        if historyPage:IsShown() then refreshHistory() end
    end
    panel:SetScript("OnShow", function()
        LayoutTabs()
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
            OpenSettings = function(source)
                if not source then return end
                if source == "Historique et progression" then SelectPage(historyPage); return end
                local operationControls = {
                    ["Démarrer le suivi"] = trackingButton, ["Arrêter le suivi"] = trackingButton,
                    ["Mettre en pause pendant l’AFK"] = _G.ArkannsQOLSession_pauseAFK,
                    ["Réinitialiser les stats"] = resetButton,
                }
                for _, metric in ipairs(metrics) do
                    if metric.label == L(source) then
                        for index, key in ipairs(db.order) do
                            if key == metric.key then operationControls[source] = _G["ArkannsQOLSessionMetric" .. index] end
                        end
                    end
                end
                local control = operationControls[source]
                if control then
                    SelectPage(scroll)
                    if ns.UI.RevealControl then ns.UI.RevealControl(scroll, control) end
                    return
                end
                SelectPage(appearancePage)
                local displayControls = {
                    ["Afficher la fenêtre"] = _G.ArkannsQOLSession_enabled, ["Masquer en combat"] = _G.ArkannsQOLSession_hideCombat,
                    ["Masquer les valeurs nulles"] = _G.ArkannsQOLSession_hideZero, ["Mode compact (3 statistiques)"] = _G.ArkannsQOLSession_compact,
                    ["Développer au survol"] = db.compact and expandOnHover or _G.ArkannsQOLSession_compact,
                    ["Disposition"] = layoutButton, ["Déplacer"] = lockButton, ["Taille du texte"] = _G.ArkannsQOLSession_fontSize,
                    ["Opacité du fond (%)"] = _G.ArkannsQOLSession_opacity, ["Thème"] = themeButton,
                    ["Apparence personnalisée"] = override, ["Thème commun"] = override,
                    ["Afficher le titre"] = _G.ArkannsQOLSession_showTitle, ["Afficher la bordure"] = _G.ArkannsQOLSession_border,
                    ["Largeur min."] = _G.ArkannsQOLSession_width,
                }
                if source == "Afficher le titre" or source == "Afficher la bordure" or source == "Largeur min." then
                    advanced:Show(); advancedButton:SetText(L("Masquer la personnalisation avancée"))
                    appearanceBody:SetHeight(558); LayoutDisplay()
                end
                if ns.UI.RevealControl then ns.UI.RevealControl(appearancePage, displayControls[source] or override) end
            end,
            toggleLabel = L("Afficher le journal"),
            frame = window, IsEnabled = function() return db.enabled end,
            SetEnabled = function(value) db.enabled = value == true; if not db.enabled then StopPreview() else Draw() end; refreshSettings() end,
            Summary = function()
                local visibility = db.enabled and L("Fenêtre affichée") or L("Fenêtre masquée")
                return visibility .. " · " .. TrackingStatus()
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
            Checkpoint()
            session.elapsed = Elapsed()
            startedAt, ready = nil, false
        elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
            if moving then SavePosition() else RestorePosition() end
        end
        Draw()
    end)
end
