local _, ns = ...
local L = ns.L
local db, native, panel, catalog, bucket, plan, fullState
local title, buildButton, nameInput, editButton, undoButton, summary, levelLabel, levelSlider, firstButton, listBody, tooltip
local infoCard, progressLabel, progressFill, listTitle, scroll, footer, emptyText
local learned, remainingLevels, pointRanks, learnedCount = {}, {}, {}, 0
local confirmed = {}
local listPlan, listEditing, listCount
local editing, dismissed, queued, syncing = false, false, false, false
local automaticHide = false
local previewLevel = 60
local overlays, rows = {}, {}
local Refresh, Draw, QueueRefresh, PositionPanel
local Model = ns.TalentPlanModel
local preview, previewRemaining, options, PositionPreview
local defaults = {enabled = true, glowIntensity = 1, futureSteps = 0, compact = false,
    nextColor = {1, 0.72, 0.15}, futureColor = {0.82, 0.77, 0.69}, errorColor = {1, 0.4, 0.32}}
local function Copy(value, depth)
    depth = depth or 0
    if depth > 8 then return nil end
    if type(value) ~= "table" then return value end
    local result = {}; for key, item in pairs(value) do result[key] = Copy(item, depth + 1) end; return result
end
local function Finite(value) return type(value) == "number" and value == value and value > -math.huge and value < math.huge end
local function Validate(target)
    for key, value in pairs(defaults) do if type(target[key]) ~= type(value) then target[key] = Copy(value) end end
    if not Finite(target.glowIntensity) then target.glowIntensity = 1 end
    target.glowIntensity = math.max(0, math.min(1, target.glowIntensity))
    if not Finite(target.futureSteps) then target.futureSteps = 0 end
    target.futureSteps = math.max(0, math.min(60, math.floor(target.futureSteps)))
    for _, key in ipairs({"nextColor", "futureColor", "errorColor"}) do
        for i = 1, 3 do if not Finite(target[key][i]) or target[key][i] < 0 or target[key][i] > 1 then target[key][i] = defaults[key][i] end end
    end
end
local function Color(kind)
    local style = ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("talents")
    if style then
        if kind == "next" then return style.accent end
        if kind == "future" then return style.text end
    end
    return db[kind .. "Color"]
end
local function ApplyStyle()
    if not panel then return end
    panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3}})
    panel:SetBackdropColor(0.08, 0.065, 0.05, 0.97); panel:SetBackdropBorderColor(0.65, 0.5, 0.2, 1)
    if ns.UI and ns.UI.StyleFrame then ns.UI.StyleFrame(panel, "talents") end
    local style = ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("talents")
    panel:SetHeight((db.compact and not editing and 460 or 600) + math.max(0, (style and style.fontSize or 13) - 13) * 8)
    local scale = style and style.scale or 1
    if UIParent:GetHeight() > 24 then scale = math.min(scale, (UIParent:GetHeight() - 24) / panel:GetHeight()) end
    local previousScale = panel:GetScale()
    panel:SetScale(scale)
    if scale ~= previousScale and PositionPanel then PositionPanel() end
    for _, label in ipairs({title, summary, listTitle, footer, progressLabel, levelLabel}) do
        if label.SetFont then label:SetFont(style and style.font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", style and style.fontSize or 13, "") end
        label:SetTextColor(unpack(style and style.text or {1, 0.94, 0.8}))
    end
    local color = Color("next")
    if progressFill then progressFill:SetColorTexture(color[1], color[2], color[3], 1) end
    if title then title:SetTextColor(unpack(color)) end
end

local function Combat() return InCombatLockdown() end
local function NativeVisible() return native and native:IsVisible() end
local function HidePanel()
    automaticHide = true; panel:Hide(); automaticHide = false
end
local function CleanName(value)
    return type(value) == "string" and #value > 0 and #value <= 120 and not value:find("[|\r\n]")
end
local function FirstLevel()
    return plan and plan.firstLevel or (catalog and catalog.detectedFirstLevel) or 10
end
local function EntryFor(point)
    if type(point) ~= "table" then return end
    local node = catalog and catalog.nodes[point.nodeID]
    return node and node.entries[point.entryID], node
end
local function MaxRanks(node, entry)
    return math.min(node.maxRanks, entry and entry.maxRanks or node.maxRanks)
end
local function UpdateProgress()
    if not catalog.hasStagedChanges then
        confirmed[catalog.configID] = {counts = catalog.actualCounts, choices = catalog.actualChoices}
    end
    local actual = confirmed[catalog.configID] or {counts = {}, choices = {}}
    learned, remainingLevels, pointRanks, learnedCount = {}, {}, {}, 0
    local counts = {}
    for index, point in ipairs(plan.order) do
        if index > catalog.maxPoints then break end
        local entry, node = EntryFor(point)
        if entry then
            counts[node.id] = (counts[node.id] or 0) + 1
            pointRanks[index] = counts[node.id]
            if index <= fullState.validCount and actual.choices[node.id] == point.entryID
                and (actual.counts[node.id] or 0) >= counts[node.id] then
                learned[index], learnedCount = true, learnedCount + 1
            elseif index <= fullState.validCount then
                remainingLevels[node.id] = remainingLevels[node.id] or {}
                table.insert(remainingLevels[node.id], FirstLevel() + index - 1)
            end
        end
    end
end
local function HideOverlays()
    for _, overlay in pairs(overlays) do overlay:Hide() end
    if tooltip then tooltip:Hide() end
end
local function Message(text)
    if summary then summary:SetText(text) end
end
local function Layout()
    local style = ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("talents")
    local fontSize = style and style.fontSize or 13
    panel:SetHeight((db.compact and not editing and 460 or 600) + math.max(0, fontSize - 13) * 8)
    editButton:SetWidth(editing and 196 or 296)
    nameInput:SetShown(editing); undoButton:SetShown(editing)
    levelLabel:SetShown(editing); levelSlider:SetShown(editing); firstButton:SetShown(editing)
    local cardTop = editing and 156 or 122
    local summaryTop = math.max(28, fontSize + 14)
    local summaryHeight = math.max(36, fontSize * 2)
    local cardHeight = math.max(80, summaryTop + summaryHeight + 16)
    infoCard:ClearAllPoints(); infoCard:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -cardTop); infoCard:SetHeight(cardHeight)
    summary:ClearAllPoints(); summary:SetPoint("TOPLEFT", 12, -summaryTop); summary:SetHeight(summaryHeight)
    local levelTop = cardTop + cardHeight + 12
    levelLabel:ClearAllPoints(); levelLabel:SetPoint("TOPLEFT", 12, -levelTop)
    levelSlider:ClearAllPoints(); levelSlider:SetPoint("TOPLEFT", 16, -levelTop - fontSize - 9)
    firstButton:ClearAllPoints(); firstButton:SetPoint("TOPLEFT", 12, -levelTop - fontSize - 33)
    local listTop = editing and (levelTop + fontSize + 77) or (cardTop + cardHeight + 18)
    listTitle:SetText(editing and L("Ordre du build") or L("Prochains points"))
    listTitle:ClearAllPoints(); listTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -listTop)
    footer:SetText(editing and L("Clic : +1 • Clic droit : retirer\nAnnuler : dernier point du build") or L("Badge : prochain niveau du talent\nHalo : point disponible"))
    scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -listTop - fontSize - 11)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, math.max(52, footer:GetStringHeight() + 24))
end

local function CurrentBucket()
    local key = catalog.classToken .. ":" .. catalog.treeID .. ":" .. (catalog.specGroup or 1)
    if type(db.profiles[key]) ~= "table" then db.profiles[key] = {} end
    bucket = db.profiles[key]
    if type(bucket.plans) ~= "table" then bucket.plans = {} end
    if #bucket.plans == 0 then bucket.plans[1] = {name = "Build 1", order = {}} end
    if type(bucket.active) ~= "number" or bucket.active % 1 ~= 0 or not bucket.plans[bucket.active] then bucket.active = 1 end
    if type(bucket.plans[bucket.active]) ~= "table" then bucket.plans[bucket.active] = {} end
    plan = bucket.plans[bucket.active]
    if not CleanName(plan.name) then plan.name = "Build " .. bucket.active end
    if type(plan.order) ~= "table" then plan.order = {} end
    if type(plan.firstLevel) ~= "number" or plan.firstLevel % 1 ~= 0 or plan.firstLevel < 5 or plan.firstLevel > 10 then plan.firstLevel = nil end
end

local function ShowPointTooltip(owner, nodeID, entryID)
    local node = catalog and catalog.nodes[nodeID]
    local entry = node and node.entries[entryID]
    if not entry then return end
    tooltip:SetOwner(owner, "ANCHOR_RIGHT"); tooltip:ClearLines()
    tooltip:AddLine(entry.name, 1, 0.82, 0)
    tooltip:AddLine(L("Prévu : %d/%d"):format(fullState.counts[nodeID] or 0, MaxRanks(node, entry)), 1, 1, 1)
    local levels = (editing and fullState.levels or remainingLevels)[nodeID] or {}
    local levelText = Model.LevelLabel(levels)
    tooltip:AddLine(L(editing and "Niveaux : %s" or "À prendre : %s"):format(levelText ~= "" and levelText or "—"), 1, 1, 1)
    local actual = catalog.actualCounts[nodeID] or 0
    tooltip:AddLine(L(catalog.hasStagedChanges and "En jeu (non validé) : %d" or "Appris : %d"):format(actual), 0.7, 0.8, 1)
    if C_Traits.GetTraitDescription then
        local rank = math.max(1, math.min(MaxRanks(node, entry), (fullState.counts[nodeID] or 0) + 1))
        local ok, description = pcall(C_Traits.GetTraitDescription, entryID, rank)
        if ok and type(description) == "string" then tooltip:AddLine(description, 1, 1, 1, true) end
    end
    if editing then tooltip:AddLine(L("Clic : +1 • Clic droit : retirer"), 0.7, 0.7, 0.7) end
    local unsupported = node.unsupported or entry.unsupported
    if unsupported then tooltip:AddLine(L(unsupported), 1, 0.4, 0.3, true) end
    tooltip:Show()
end

local function AddPoint(nodeID, entryID)
    if not editing or Combat() or not plan or not catalog then return end
    local ok, reason = Model.Append(catalog, plan.order, nodeID, entryID, FirstLevel())
    if not ok then Message(L(reason)); return end
    previewLevel = math.min(60, FirstLevel() + #plan.order - 1)
    Draw()
end

local function ClickTalent(self, button)
    if not editing or Combat() then return end
    local node = catalog.nodes[self.nodeID]
    if not node then return end
    if button == "RightButton" then
        local ok, reason, detail = Model.RemoveLast(catalog, plan.order, self.nodeID, FirstLevel())
        if ok then Draw() else Message(detail and L("Retrait impossible : %s"):format(L(detail)) or L(reason)) end
        return
    end
    local chosen = fullState.choices[self.nodeID]
    if chosen then AddPoint(self.nodeID, chosen); return end
    local entries = {}
    for entryID in pairs(node.entries) do entries[#entries + 1] = entryID end
    table.sort(entries)
    if #entries == 1 then AddPoint(self.nodeID, entries[1]); return end
    local nodeID = self.nodeID
    MenuUtil.CreateContextMenu(self, function(_, menu)
        menu:CreateTitle(L("Choisir le talent"))
        for _, entryID in ipairs(entries) do
            local choice = entryID
            menu:CreateButton(node.entries[choice].name, function() AddPoint(nodeID, choice) end)
        end
    end)
end

local function NextHighlight()
    if editing or fullState.error or catalog.hasStagedChanges or catalog.availablePoints < 1 then return end
    local index = Model.NextMissing(plan.order, catalog.actualCounts, catalog.actualChoices)
    local point = index and plan.order[index]
    if not point or not C_Traits.CanPurchaseRank then return end
    if (catalog.actualCounts[point.nodeID] or 0) > 0 and catalog.actualChoices[point.nodeID] ~= point.entryID then return end
    -- Read-only native check: do not suggest a blocked rank when the character diverged from the plan.
    local ok, canPurchase = pcall(C_Traits.CanPurchaseRank, catalog.configID, point.nodeID, point.entryID)
    if ok and not (issecretvalue and issecretvalue(canPurchase)) and canPurchase == true then return point.nodeID end
end

local function DrawOverlays()
    if not native or not native.EnumerateAllTalentButtons then return end
    local present = {}
    local highlightID = NextHighlight()
    local visibleNodes, nextNode, pendingCount = {}, nil, 0
    for index, point in ipairs(plan.order) do
        if index > catalog.maxPoints then break end
        if not learned[index] then
            pendingCount = pendingCount + 1
            if type(point) == "table" and Finite(point.nodeID) and point.nodeID > 0 and point.nodeID % 1 == 0 then
                if not nextNode then nextNode = point.nodeID end
                if db.futureSteps == 0 or pendingCount <= db.futureSteps then visibleNodes[point.nodeID] = true end
            end
        end
    end
    local shown = Model.Replay(catalog, plan.order, FirstLevel(), math.max(0, previewLevel - FirstLevel() + 1))
    for button in native:EnumerateAllTalentButtons() do
        local nodeID = button:GetNodeID()
        local node = catalog.nodes[nodeID]
        if node and (not button.ShouldBeVisible or button:ShouldBeVisible()) then
            local overlay = overlays[button]
            if not overlay then
                -- Own buttons cover native icons only in edit mode. No native handler is replaced.
                overlay = CreateFrame("Button", nil, button, "BackdropTemplate")
                overlay:SetAllPoints(button); overlay:SetFrameLevel(button:GetFrameLevel() + 10)
                overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                overlay:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
                overlay.icon = overlay:CreateTexture(nil, "ARTWORK"); overlay.icon:SetAllPoints()
                overlay.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
                overlay.glow = overlay:CreateTexture(nil, "OVERLAY")
                overlay.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                overlay.glow:SetBlendMode("ADD"); overlay.glow:SetVertexColor(1, 0.82, 0.1)
                overlay.glow:SetPoint("TOPLEFT", overlay, "TOPLEFT", -12, 12)
                overlay.glow:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", 12, -12)
                local function Badge(point, width)
                    local badge = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
                    badge:SetPoint(point, overlay, point, 0, point == "TOP" and -1 or 1)
                    badge:SetSize(width, 14); badge:EnableMouse(false)
                    badge:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
                    badge:SetBackdropColor(0.025, 0.03, 0.04, 0.95)
                    badge:SetBackdropBorderColor(0.45, 0.35, 0.13, 1)
                    local text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    text:SetPoint("CENTER"); text:SetWidth(width - 2); text:SetWordWrap(false)
                    return badge, text
                end
                overlay.levelBadge, overlay.levels = Badge("TOP", 26)
                overlay.rankBadge, overlay.rank = Badge("BOTTOM", 30)
                overlay.levels:SetTextColor(1, 0.82, 0)
                overlay:SetScript("OnClick", ClickTalent)
                overlay:SetScript("OnEnter", function(self)
                    local entryID = fullState.choices[self.nodeID] or next(catalog.nodes[self.nodeID].entries)
                    ShowPointTooltip(self, self.nodeID, entryID)
                end)
                overlay:SetScript("OnLeave", function() tooltip:Hide() end)
                overlay:SetScript("OnHide", function(self) if tooltip:GetOwner() == self then tooltip:Hide() end end)
                overlays[button] = overlay
            end
            present[button] = true
            overlay.nodeID = nodeID
            local count = shown.counts[nodeID] or 0
            local chosen = fullState.choices[nodeID] or next(node.entries)
            local entry = node.entries[chosen]
            overlay.icon:SetTexture(entry and entry.icon or 134400)
            overlay.icon:SetShown(editing)
            overlay.rank:SetText(count .. "/" .. MaxRanks(node, entry))
            overlay.rankBadge:SetShown(editing)
            local levels = (editing and fullState.levels or remainingLevels)[nodeID]
            if not editing and not visibleNodes[nodeID] then levels = nil end
            overlay.levels:SetText(levels and tostring(levels[1]) or "")
            overlay.levelBadge:SetShown(levels ~= nil)
            local highlighted = nodeID == highlightID
            local color = Color(nodeID == nextNode and "next" or "future")
            overlay.levels:SetTextColor(unpack(color))
            local glowColor = Color("next")
            overlay.glow:SetVertexColor(glowColor[1], glowColor[2], glowColor[3], db.glowIntensity)
            overlay.glow:SetShown(highlighted and db.glowIntensity > 0)
            overlay:SetBackdropBorderColor(color[1], color[2], color[3], (editing or highlighted) and 1 or 0)
            overlay:EnableMouse(editing and not Combat())
            overlay:SetShown(editing or levels ~= nil)
        end
    end
    for button, overlay in pairs(overlays) do if not present[button] then overlay:Hide() end end
end

Draw = function()
    if Combat() or not db.enabled or not NativeVisible() or dismissed then HidePanel(); return end
    if not catalog or not plan then return end
    fullState = Model.Replay(catalog, plan.order, FirstLevel())
    UpdateProgress()
    ApplyStyle()
    title:SetText(L("Builds · %s"):format(catalog.className))
    buildButton:SetText(plan.name)
    if nameInput.ownerPlan ~= plan then
        nameInput:ClearFocus()
        nameInput.ownerPlan = plan
        nameInput:SetText(plan.name)
    elseif not nameInput:HasFocus() then nameInput:SetText(plan.name) end
    editButton:SetText(editing and L("Terminer") or L("Modifier le build"))
    Layout()
    undoButton:SetEnabled(#plan.order > 0 and not Combat())
    levelLabel:SetText(L("Aperçu au niveau %d"):format(previewLevel))
    syncing = true; levelSlider:SetValue(previewLevel); syncing = false
    local source = plan.firstLevel and L("manuel") or (catalog.detectedFirstLevel and L("auto") or L("à vérifier"))
    firstButton:SetText(L("1er point : niv. %d (%s)"):format(FirstLevel(), source))
    local nextIndex
    for index = 1, math.min(#plan.order, catalog.maxPoints) do
        if not learned[index] then nextIndex = index; break end
    end
    progressLabel:SetText(editing and L("%d / %d points prévus"):format(#plan.order, catalog.maxPoints) or L("%d / %d points appris"):format(learnedCount, #plan.order))
    local fraction = editing and (#plan.order / catalog.maxPoints) or (#plan.order > 0 and learnedCount / #plan.order or 0)
    progressFill:SetWidth(math.max(1, 272 * math.min(1, fraction))); progressFill:SetShown(fraction > 0)
    local message
    if fullState.error then message = L("Plan à revoir : %s"):format(L(fullState.error))
    elseif editing then message = #plan.order >= catalog.maxPoints and L("Build complet") or L("Prochain ajout : niveau %d"):format(FirstLevel() + #plan.order)
    elseif catalog.hasStagedChanges then message = L("Changements en attente de validation")
    elseif nextIndex then
        local entry = EntryFor(plan.order[nextIndex])
        message = L("Niv. %d · %s"):format(FirstLevel() + nextIndex - 1, entry and entry.name or L("Talent indisponible"))
    else message = #plan.order > 0 and L("Build terminé") or L("Ajoute tes talents avec Modifier le build.") end
    Message(message)
    summary:SetTextColor(unpack(Color(fullState.error and "error" or "next")))
    for _, row in ipairs(rows) do row:Hide() end
    local visibleCount = 0
    local style = ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("talents")
    local fontSize = style and style.fontSize or 12
    local rowHeight = math.max(44, fontSize * 2 + (style and style.gap or 6) + 12)
    for index, point in ipairs(plan.order) do
        if index > catalog.maxPoints then break end
        if editing or (not learned[index] and (db.futureSteps == 0 or visibleCount < db.futureSteps)) then
            visibleCount = visibleCount + 1
            local row = rows[visibleCount]
            if not row then
                row = CreateFrame("Button", nil, listBody)
                row:SetPoint("TOPLEFT", 0, -(visibleCount - 1) * 44); row:SetPoint("TOPRIGHT", 0, -(visibleCount - 1) * 44); row:SetHeight(42)
                row.background = row:CreateTexture(nil, "BACKGROUND"); row.background:SetAllPoints()
                row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.level:SetPoint("LEFT", 4, 0); row.level:SetWidth(32); row.level:SetWordWrap(false)
                row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetPoint("LEFT", 40, 0); row.icon:SetSize(28, 28)
                row.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("TOPLEFT", 76, -6); row.text:SetPoint("TOPRIGHT", -6, -6); row.text:SetHeight(14); row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                row.detail:SetPoint("BOTTOMLEFT", 76, 6); row.detail:SetPoint("BOTTOMRIGHT", -6, 6); row.detail:SetHeight(12)
                row.detail:SetJustifyH("LEFT"); row.detail:SetWordWrap(false)
                row:SetScript("OnEnter", function(self)
                    local selected = plan.order[self.index]
                    if type(selected) == "table" then ShowPointTooltip(self, selected.nodeID, selected.entryID) end
                end)
                row:SetScript("OnLeave", function() tooltip:Hide() end)
                row:SetScript("OnHide", function(self) if tooltip:GetOwner() == self then tooltip:Hide() end end)
                rows[visibleCount] = row
            end
            row.index = index
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(visibleCount - 1) * rowHeight)
            row:SetPoint("TOPRIGHT", 0, -(visibleCount - 1) * rowHeight); row:SetHeight(rowHeight - 2)
            if row.text.SetFont then
                local font = style and style.font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
                row.level:SetFont(font, fontSize, ""); row.text:SetFont(font, fontSize, ""); row.detail:SetFont(font, math.max(10, fontSize - 2), "")
                row.text:SetHeight(fontSize + 2); row.detail:SetHeight(fontSize)
            end
            local entry = type(point) == "table" and EntryFor(point) or nil
            row.icon:SetTexture(entry and entry.icon or 134400)
            row.level:SetText(tostring(FirstLevel() + index - 1))
            row.text:SetText(entry and entry.name or L("Talent indisponible"))
            local node = type(point) == "table" and catalog.nodes[point.nodeID]
            row.detail:SetText(entry and L("Rang %d / %d"):format(pointRanks[index] or 0, MaxRanks(node, entry)) or L("À revoir"))
            local nextColor = Color("next")
            row.background:SetColorTexture(index == nextIndex and not editing and nextColor[1] * 0.22 or 0.09, index == nextIndex and not editing and nextColor[2] * 0.22 or 0.075, 0.055, 0.85)
            if fullState.errorIndex and index >= fullState.errorIndex then row.text:SetTextColor(unpack(Color("error")))
            elseif index == nextIndex then row.text:SetTextColor(unpack(nextColor))
            elseif learned[index] then row.text:SetTextColor(0.4, 0.9, 0.5)
            else row.text:SetTextColor(unpack(Color("future"))) end
            row:Show()
        end
    end
    emptyText:SetText(#plan.order > 0 and L("Aucun point restant.") or L("Ton build est vide."))
    emptyText:SetShown(visibleCount == 0)
    listBody:SetHeight(math.max(60, visibleCount * rowHeight))
    if listPlan ~= plan or listEditing ~= editing or listCount ~= visibleCount then scroll:SetVerticalScroll(0) end
    listPlan, listEditing, listCount = plan, editing, visibleCount
    DrawOverlays()
end

PositionPanel = function()
    panel:ClearAllPoints()
    if type(db.x) == "number" and type(db.y) == "number" and db.x >= 0 and db.x <= 1 and db.y >= 0 and db.y <= 1 then
        local scale = panel.GetEffectiveScale and panel:GetEffectiveScale() or panel:GetScale()
        local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or UIParent:GetScale()
        local ratio = scale / math.max(0.01, parentScale)
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.x * UIParent:GetWidth() / ratio, db.y * UIParent:GetHeight() / ratio)
    elseif native then panel:SetPoint("TOPLEFT", native, "TOPRIGHT", 8, 0) end
end

Refresh = function()
    if not db.enabled or dismissed or not NativeVisible() or Combat() then HidePanel(); return end
    if native.IsInspecting and native:IsInspecting() then HidePanel(); return end
    local ok, result, reason = pcall(ns.TalentPlanData.Read, native)
    if not ok or not result then
        catalog, plan, bucket, editing = nil, nil, nil, false
        HideOverlays(); PositionPanel(); panel:Show()
        title:SetText(L("Builds de talents"))
        Layout(); progressLabel:SetText(L("Lecture indisponible")); progressFill:Hide(); emptyText:Hide()
        Message(L(reason or "Talents indisponibles. Rouvre l'arbre hors combat."))
        editButton:SetEnabled(false); undoButton:SetEnabled(false); buildButton:SetEnabled(false); firstButton:SetEnabled(false)
        for _, row in ipairs(rows) do row:Hide() end
        return
    end
    local changed = not catalog or catalog.treeID ~= result.treeID or catalog.configID ~= result.configID
    catalog = result
    if changed then editing = false; tooltip:Hide() end
    CurrentBucket()
    editButton:SetEnabled(true); buildButton:SetEnabled(true); firstButton:SetEnabled(true)
    PositionPanel(); panel:Show(); Draw()
end

QueueRefresh = function()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; Refresh() end)
end

local function Attach()
    if Combat() then return end
    local frame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not frame or frame == native then return end
    native = frame
    native:HookScript("OnShow", function() dismissed = false; QueueRefresh() end)
    native:HookScript("OnHide", HidePanel)
    if NativeVisible() then QueueRefresh() end
end

local function StopPreview()
    previewRemaining = 0
    if preview then preview:Hide() end
end
local function Preview()
    if Combat() then return end
    if not preview then
        preview = CreateFrame("Frame", "ArkannsQOLTalentPreview", UIParent, "BackdropTemplate")
        preview:SetPoint("CENTER", UIParent, "CENTER", 0, 0); preview:SetSize(320, 220)
        preview:SetFrameStrata("DIALOG"); preview:EnableMouse(true)
        preview:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
        preview:SetBackdropColor(0.08, 0.065, 0.05, 0.97); preview:SetBackdropBorderColor(0.65, 0.5, 0.2, 1)
        preview.labels = {}
        for i, text in ipairs({L("Aperçu · Builds de talents"), L("Niv. 20 · Prochain talent"), L("Niv. 21 · Talent suivant"), L("Exemple : plan à revoir")}) do
            local label = preview:CreateFontString(nil, "OVERLAY", i == 1 and "GameFontNormalLarge" or "GameFontHighlight")
            label:SetPoint("TOPLEFT", 18, -18 - (i - 1) * 36); label:SetText(text); preview.labels[i] = label
        end
        preview.glow = preview:CreateTexture(nil, "ARTWORK")
        preview.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); preview.glow:SetBlendMode("ADD")
        preview.glow:SetPoint("RIGHT", preview, "RIGHT", -12, 30); preview.glow:SetSize(68, 68)
        local close = CreateFrame("Button", nil, preview, "UIPanelButtonTemplate")
        close:SetPoint("BOTTOM", preview, "BOTTOM", 0, 12); close:SetSize(150, 26); close:SetText(L("Arrêter l’aperçu"))
        close:SetScript("OnClick", StopPreview)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(close) end
        preview:SetScript("OnUpdate", function(_, delta)
            if ns.UI and ns.UI.layoutActive then return end
            previewRemaining = previewRemaining - delta; if previewRemaining <= 0 then StopPreview() end
        end)
        preview:SetScript("OnHide", function() previewRemaining = 0 end)
    end
    preview:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12})
    preview:SetBackdropColor(0.08, 0.065, 0.05, 0.97); preview:SetBackdropBorderColor(0.65, 0.5, 0.2, 1)
    if ns.UI and ns.UI.StyleFrame then ns.UI.StyleFrame(preview, "talents") end
    preview:SetScale(panel:GetScale()); preview:SetSize(panel:GetWidth(), panel:GetHeight())
    if PositionPreview then PositionPreview() end
    local style = ns.UI and ns.UI.GetStyle and ns.UI.GetStyle("talents")
    local y = 18
    for _, label in ipairs(preview.labels) do
        label:SetFont(style and style.font or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", style and style.fontSize or 13, "")
        label:SetWidth(preview:GetWidth() - 36)
        label:ClearAllPoints(); label:SetPoint("TOPLEFT", 18, -y)
        y = y + label:GetStringHeight() + 14
    end
    local nextColor = Color("next")
    preview.labels[1]:SetTextColor(unpack(nextColor)); preview.labels[2]:SetTextColor(unpack(nextColor))
    preview.labels[3]:SetTextColor(unpack(Color("future"))); preview.labels[3]:SetShown(db.futureSteps ~= 1)
    preview.labels[4]:SetTextColor(unpack(Color("error")))
    preview.glow:SetVertexColor(nextColor[1], nextColor[2], nextColor[3], db.glowIntensity)
    preview.glow:SetShown(db.glowIntensity > 0)
    previewRemaining = 12; preview:Show()
end

local function SettingsChanged()
    ApplyStyle(); dismissed = false; Refresh()
    if options and options.OnRefresh then options:OnRefresh() end
    if previewRemaining and previewRemaining > 0 then Preview() end
end
local function SetEnabled(value)
    db.enabled = value == true
    if not db.enabled then StopPreview() end
    SettingsChanged()
end

local function FrameRatio()
    local scale = panel.GetEffectiveScale and panel:GetEffectiveScale() or panel:GetScale()
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or UIParent:GetScale()
    return scale / math.max(0.01, parentScale)
end

local function GetPosition()
    local width, height, ratio = UIParent:GetWidth(), UIParent:GetHeight(), FrameRatio()
    if width <= 0 or height <= 0 then return 0.7, 0.5 end
    if Finite(db.x) and Finite(db.y) then
        return db.x + panel:GetWidth() * ratio / (2 * width), db.y - panel:GetHeight() * ratio / (2 * height)
    end
    -- A closed native tree cannot provide a current default anchor; ignore stale dragged geometry.
    if not NativeVisible() or not panel:IsShown() then return 0.7, 0.5 end
    local x, y
    if panel.GetCenter then x, y = panel:GetCenter() end
    if Finite(x) and Finite(y) then return x * ratio / width, y * ratio / height end
    return 0.7, 0.5
end
PositionPreview = function()
    if not preview then return end
    local x, y = GetPosition()
    local ratio = FrameRatio()
    preview:ClearAllPoints(); preview:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * UIParent:GetWidth() / ratio, y * UIParent:GetHeight() / ratio)
end
local function SetPosition(x, y)
    if not Finite(x) or not Finite(y) then return end
    local width, height, ratio = UIParent:GetWidth(), UIParent:GetHeight(), FrameRatio()
    if width <= 0 or height <= 0 then return end
    db.x = math.max(0, math.min(1, x - panel:GetWidth() * ratio / (2 * width)))
    db.y = math.max(0, math.min(1, y + panel:GetHeight() * ratio / (2 * height)))
    PositionPanel()
    PositionPreview()
end

function ns.InitializeTalentPlanner(parentCategory)
    if type(ArkannsQOLTalentsDB) ~= "table" then ArkannsQOLTalentsDB = {} end
    db = ArkannsQOLTalentsDB
    Validate(db)
    if type(db.profiles) ~= "table" then db.profiles = {} end
    panel = CreateFrame("Frame", "ArkannsQOLTalentPlanner", UIParent, "BackdropTemplate")
    panel:SetSize(320, 600); panel:SetFrameStrata("DIALOG"); panel:SetMovable(true); panel:SetClampedToScreen(true); panel:EnableMouse(true)
    panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = {left = 3, right = 3, top = 3, bottom = 3}})
    panel:SetBackdropColor(0.035, 0.045, 0.065, 0.97); panel:SetBackdropBorderColor(0.65, 0.5, 0.2, 1)
    panel:Hide()
    local function Text(parent, text, x, y, font)
        local value = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        value:SetPoint("TOPLEFT", x, y); value:SetWidth(296); value:SetJustifyH("LEFT"); value:SetText(text)
        return value
    end
    local function Button(name, label, x, y, width, action)
        local value = CreateFrame("Button", "ArkannsQOLTalent" .. name, panel, "UIPanelButtonTemplate")
        value:SetPoint("TOPLEFT", x, y); value:SetSize(width, 26); value:SetText(label); value:SetScript("OnClick", action)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(value) end
        return value
    end
    title = Text(panel, L("Builds de talents"), 12, -14, "GameFontNormal")
    title:SetWidth(264); title:SetWordWrap(false)
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 4, -4); header:SetSize(274, 32); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() panel:StartMoving() end)
    header:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local x, y = panel:GetLeft(), panel:GetTop()
        if x and y and UIParent:GetWidth() > 0 and UIParent:GetHeight() > 0 then
            local ratio = FrameRatio()
            db.x = math.max(0, math.min(1, x * ratio / UIParent:GetWidth())); db.y = math.max(0, math.min(1, y * ratio / UIParent:GetHeight()))
        end
    end)
    Button("Close", "×", 284, -6, 26, function() dismissed = true; panel:Hide() end)
    tooltip = CreateFrame("GameTooltip", "ArkannsQOLTalentPlanTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetClampedToScreen(true); tooltip:Hide()
    panel:SetScript("OnHide", function()
        if not automaticHide then dismissed = true end
        editing = false; panel:StopMovingOrSizing(); HideOverlays()
    end)
    table.insert(UISpecialFrames, "ArkannsQOLTalentPlanner")
    buildButton = Button("Build", "Build 1", 12, -46, 204, function(self)
        if not bucket then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:SetScrollMode(300)
            for index, saved in ipairs(bucket.plans) do
                local selected = index
                menu:CreateButton(type(saved) == "table" and CleanName(saved.name) and saved.name or "Build " .. index, function()
                    bucket.active = selected; editing = false; CurrentBucket(); Draw()
                end)
            end
        end)
    end)
    buildButton:GetFontString():SetWidth(180); buildButton:GetFontString():SetWordWrap(false)
    Button("New", L("Nouveau"), 224, -46, 84, function()
        if not bucket or Combat() then return end
        bucket.plans[#bucket.plans + 1] = {name = "Build " .. (#bucket.plans + 1), order = {}}
        bucket.active = #bucket.plans; CurrentBucket(); editing = true; Draw()
    end)
    nameInput = CreateFrame("EditBox", "ArkannsQOLTalentName", panel, "InputBoxTemplate")
    nameInput:SetPoint("TOPLEFT", 18, -120); nameInput:SetSize(284, 24); nameInput:SetAutoFocus(false); nameInput:SetMaxLetters(40)
    local function SaveName(self)
        local owner = self.ownerPlan
        if not owner then return end
        local text = self:GetText():match("^%s*(.-)%s*$")
        if CleanName(text) then owner.name = text else self:SetText(owner.name) end
        if owner == plan then buildButton:SetText(owner.name) end
    end
    nameInput:SetScript("OnEnterPressed", function(self) SaveName(self); self:ClearFocus() end)
    nameInput:SetScript("OnEditFocusLost", SaveName)
    nameInput:SetScript("OnEscapePressed", function(self) if plan then self:SetText(plan.name) end; self:ClearFocus() end)
    editButton = Button("Edit", L("Modifier le build"), 12, -84, 196, function()
        if Combat() then Message(L("Édition hors combat.")); return end
        nameInput:ClearFocus()
        editing = not editing; if editing then previewLevel = 60 end; Draw()
    end)
    undoButton = Button("Undo", L("Annuler", "talent.undo"), 216, -84, 92, function()
        if plan and not Combat() then Model.Undo(plan.order); Draw() end
    end)
    infoCard = CreateFrame("Frame", "ArkannsQOLTalentProgress", panel, "BackdropTemplate")
    infoCard:SetSize(296, 80)
    infoCard:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"}); infoCard:SetBackdropColor(0.13, 0.105, 0.075, 1)
    infoCard:EnableMouse(true)
    infoCard:SetScript("OnEnter", function(self)
        tooltip:SetOwner(self, "ANCHOR_RIGHT"); tooltip:ClearLines()
        tooltip:AddLine(progressLabel:GetText(), 0.7, 0.7, 0.7)
        tooltip:AddLine(summary:GetText(), 1, 0.82, 0, true); tooltip:Show()
    end)
    infoCard:SetScript("OnLeave", function() tooltip:Hide() end)
    progressLabel = Text(infoCard, "", 12, -10, "GameFontDisableSmall"); progressLabel:SetWidth(272)
    summary = Text(infoCard, L("Ouvre tes talents (N)."), 12, -28, "GameFontNormal")
    summary:SetWidth(272); summary:SetHeight(36); summary:SetWordWrap(true)
    local track = infoCard:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("BOTTOMLEFT", 12, 8); track:SetSize(272, 3); track:SetColorTexture(0.18, 0.2, 0.24, 1)
    progressFill = infoCard:CreateTexture(nil, "ARTWORK")
    progressFill:SetPoint("BOTTOMLEFT", 12, 8); progressFill:SetSize(1, 3); progressFill:SetColorTexture(0.9, 0.68, 0.2, 1)
    levelLabel = Text(panel, "", 12, -248, "GameFontNormal")
    levelSlider = CreateFrame("Slider", "ArkannsQOLTalentLevel", panel, "BackdropTemplate")
    levelSlider:SetPoint("TOPLEFT", 16, -270); levelSlider:SetSize(288, 16)
    levelSlider:SetOrientation("HORIZONTAL"); levelSlider:SetMinMaxValues(5, 60); levelSlider:SetValueStep(1); levelSlider:SetObeyStepOnDrag(true)
    levelSlider:SetBackdrop({bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", edgeSize = 8})
    levelSlider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal"); levelSlider:GetThumbTexture():SetSize(32, 32)
    levelSlider:SetScript("OnValueChanged", function(_, value)
        if not syncing and plan then previewLevel = math.max(5, math.min(60, math.floor(value + 0.5))); Draw() end
    end)
    firstButton = Button("FirstLevel", L("1er point"), 12, -294, 296, function(self)
        if not plan then return end
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:CreateTitle(L("Niveau du premier point"))
            menu:CreateButton(L("Automatique"), function() plan.firstLevel = nil; Draw() end)
            for level = 5, 10 do
                local chosen = level
                menu:CreateButton(L("Niveau %d"):format(level), function() plan.firstLevel = chosen; Draw() end)
            end
        end)
    end)
    firstButton:SetScript("OnEnter", function(self)
        if not catalog then return end
        tooltip:SetOwner(self, "ANCHOR_RIGHT"); tooltip:ClearLines()
        tooltip:AddLine(L("Premier point de talent"), 1, 0.82, 0)
        tooltip:AddLine(L(plan.firstLevel and "Niveau choisi manuellement." or catalog.levelSource), 1, 1, 1, true)
        tooltip:AddLine(L("Modifie-le ici si ton bonus Héritage diffère."), 0.7, 0.7, 0.7, true)
        tooltip:Show()
    end)
    firstButton:SetScript("OnLeave", function() tooltip:Hide() end)
    listTitle = Text(panel, L("Prochains points"), 12, -220, "GameFontNormal")
    scroll = CreateFrame("ScrollFrame", "ArkannsQOLTalentOrder", panel, "UIPanelScrollFrameTemplate")
    listBody = CreateFrame("Frame", nil, scroll); listBody:SetSize(278, 60); scroll:SetScrollChild(listBody)
    scroll:SetScript("OnSizeChanged", function(_, width) listBody:SetWidth(math.max(1, width)) end)
    emptyText = Text(listBody, L("Ton build est vide."), 8, -16); emptyText:SetWidth(262)
    footer = Text(panel, "", 12, -550, "GameFontDisableSmall")
    footer:ClearAllPoints(); footer:SetPoint("BOTTOMLEFT", 12, 12)

    options = CreateFrame("Frame", "ArkannsQOLTalentSettings", UIParent, "BackdropTemplate"); options:Hide()
    Text(options, L("Builds de talents"), 16, -16, "GameFontNormalLarge")
    local updates = {}
    local function OptionButton(name, label, x, y, width, action)
        local button = CreateFrame("Button", "ArkannsQOLTalent" .. name, options, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y); button:SetSize(width, 26); button:SetText(label); button:SetScript("OnClick", action)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button) end
        return button
    end
    local function Choice(name, label, key, values, x, y, width)
        local button = OptionButton(name, label, x, y, width, function(self)
            MenuUtil.CreateContextMenu(self, function(_, menu)
                for _, item in ipairs(values) do
                    local value, caption = item[1], item[2]
                    menu:CreateButton(caption, function() db[key] = value; SettingsChanged() end)
                end
            end)
        end)
        updates[#updates + 1] = function()
            local caption = tostring(db[key]); for _, item in ipairs(values) do if item[1] == db[key] then caption = item[2] end end
            button:SetText(L("%s : %s"):format(label, caption))
        end
    end
    Text(options, L("Fonctionnement"), 16, -58, "GameFontNormal")
    local check = CreateFrame("CheckButton", "ArkannsQOLTalentEnabled", options, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 12, -84)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0); label:SetText(L("Afficher avec les talents")); check:SetFontString(label)
    check:SetScript("OnClick", function(self) SetEnabled(self:GetChecked()) end)
    Choice("FutureSteps", L("Étapes visibles"), "futureSteps", {{1, L("Prochaine seule")}, {3, L("3 prochaines")}, {5, L("5 prochaines")}, {10, L("10 prochaines")}, {0, L("Toutes")}}, 16, -128, 290)
    OptionButton("ResetBehavior", L("Réinitialiser"), 430, -52, 110, function() db.futureSteps = 0; SetEnabled(true) end)
    local help = Text(options, L("Le build complet reste enregistré. Modifier le build affiche tous ses points.\nAucun talent n’est acheté automatiquement."), 16, -168); help:SetWidth(550)

    Text(options, L("Apparence"), 16, -224, "GameFontNormal")
    Choice("Glow", L("Intensité du halo"), "glowIntensity", {{0, L("Aucun")}, {0.25, "25 %"}, {0.5, "50 %"}, {0.75, "75 %"}, {1, "100 %"}}, 16, -256, 260)
    local compact = CreateFrame("CheckButton", "ArkannsQOLTalentCompact", options, "UICheckButtonTemplate")
    compact:SetPoint("TOPLEFT", 300, -254)
    local compactLabel = compact:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    compactLabel:SetPoint("LEFT", compact, "RIGHT", 2, 0); compactLabel:SetText(L("Panneau compact"))
    compact:SetScript("OnClick", function(self) db.compact = self:GetChecked() == true; SettingsChanged() end)
    for index, item in ipairs({{"nextColor", L("Prochain")}, {"futureColor", L("Suivants")}, {"errorColor", L("Erreur")}}) do
        local key, label = item[1], item[2]
        OptionButton("Color" .. key, label, 16 + (index - 1) * 180, -296, 165, function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local old, oldOverride = Copy(db[key]), ns.UI and ns.UI.IsOverride and ns.UI.IsOverride("talents")
            ColorPickerFrame:SetupColorPickerAndShow({r = old[1], g = old[2], b = old[3], hasOpacity = false,
                swatchFunc = function()
                    db[key] = {ColorPickerFrame:GetColorRGB()}
                    if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("talents", true) end
                    SettingsChanged()
                end,
                cancelFunc = function()
                    db[key] = old
                    if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("talents", oldOverride == true) end
                    SettingsChanged()
                end})
        end)
    end
    if ns.UI and ns.UI.IsOverride and ns.UI.SetOverride then
        local own = CreateFrame("CheckButton", "ArkannsQOLTalentOwnStyle", options, "UICheckButtonTemplate")
        own:SetPoint("TOPLEFT", 12, -334)
        local ownLabel = own:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ownLabel:SetPoint("LEFT", own, "RIGHT", 2, 0); ownLabel:SetText(L("Apparence propre à ce module"))
        own:SetScript("OnClick", function(self) ns.UI.SetOverride("talents", self:GetChecked() == true) end)
        updates[#updates + 1] = function() own:SetChecked(ns.UI.IsOverride("talents")) end
    end
    OptionButton("Preview", L("Aperçu · 12 s"), 16, -378, 260, Preview)
    OptionButton("StopPreview", L("Arrêter l’aperçu"), 296, -378, 240, StopPreview)
    OptionButton("ResetAppearance", L("Réinitialiser"), 430, -218, 110, function()
        for _, key in ipairs({"compact", "glowIntensity", "nextColor", "futureColor", "errorColor"}) do db[key] = Copy(defaults[key]) end
        if ns.UI and ns.UI.SetOverride then ns.UI.SetOverride("talents", false) end
        SettingsChanged()
    end)

    Text(options, L("Disposition"), 16, -438, "GameFontNormal")
    OptionButton("Reposition", L("Replacer près des talents"), 16, -466, 260, function() db.x, db.y = nil, nil; SettingsChanged() end)
    local tip = Text(options, L("Ouvre les talents (N). Glisse le titre pour déplacer le panneau.\n/aqbuild réaffiche le panneau fermé.\nLes profils généraux copient les réglages, jamais tes builds."), 16, -510); tip:SetWidth(550)
    options.OnRefresh = function()
        check:SetChecked(db.enabled); compact:SetChecked(db.compact)
        for _, update in ipairs(updates) do update() end
    end
    options:SetScript("OnShow", options.OnRefresh); options:SetScript("OnHide", StopPreview)
    if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(options) end
    ns.talentCategory = Settings.RegisterCanvasLayoutSubcategory(parentCategory, options, L("Builds de talents"))
    if ns.RegisterModule then ns.RegisterModule("talents", {
        label = L("Builds de talents"), icon = "Interface\\Buttons\\UI-MicroButton-Talents-Up", iconAtlas = "UI-HUD-MicroMenu-SpecTalents-Up", category = function() return ns.talentCategory end,
        profileClassIndependent = true,
        frame = panel, GetPosition = GetPosition, SetPosition = SetPosition,
        IsEnabled = function() return db.enabled end, SetEnabled = SetEnabled,
        Summary = function()
            local mode = db.compact and "Compact" or L("Confort")
            if db.futureSteps == 0 then return L("%s · toutes les étapes"):format(mode) end
            if db.futureSteps == 1 then return L("%s · 1 étape"):format(mode) end
            return L("%s · %d étapes"):format(mode, db.futureSteps)
        end,
        Preview = Preview, StopPreview = StopPreview, Refresh = SettingsChanged,
        ExportSettings = function()
            local result = {}; for key in pairs(defaults) do result[key] = Copy(db[key]) end
            result.x, result.y = db.x, db.y
            return result
        end,
        ImportSettings = function(config)
            if type(config) ~= "table" then return false end
            local candidate = {}; for key, value in pairs(defaults) do candidate[key] = Copy(config[key] == nil and value or config[key]) end
            Validate(candidate); for key, value in pairs(candidate) do db[key] = value end
            for _, key in ipairs({"x", "y"}) do db[key] = Finite(config[key]) and math.max(0, math.min(1, config[key])) or nil end
            PositionPanel()
            SetEnabled(db.enabled); return true
        end,
    }) end
    ApplyStyle()
    SLASH_ARKANNSQOLTALENTS1 = "/aqbuild"
    SlashCmdList.ARKANNSQOLTALENTS = function()
        dismissed = false; Attach(); Refresh()
        if not panel:IsShown() then print(L("|cff33ccffQoL Toolkit :|r Ouvre tes talents (N) et active le module dans /aqol.")) end
    end
    local events = CreateFrame("Frame", "ArkannsQOLTalentEvents")
    for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_NODE_CHANGED_PARTIAL", "TRAIT_NODE_ENTRY_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_SUB_TREE_CHANGED", "TRAIT_TREE_CHANGED", "SPELL_DATA_LOAD_RESULT", "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do events:RegisterEvent(event) end
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then StopPreview(); HidePanel(); return end
        if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then SettingsChanged(); return end
        Attach(); if NativeVisible() then QueueRefresh() end
    end)
    if EventRegistry then EventRegistry:RegisterCallback("TalentFrameBase.ButtonsUpdated", function() QueueRefresh() end, panel) end
    Attach()
end
