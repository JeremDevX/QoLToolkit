local _, ns = ...
local L, Model = ns.L, ns.SessionJournalModel

-- History contains character data; this page never writes profile settings.
function ns.CreateSessionHistoryPanel(parent, context)
    local period, page, selected, metric, mode = 0, 1, nil, "xp", "sessions"
    local rows, lines, dots = {}, {}, {}
    local refresh
    local function Label(text, size, owner)
        owner = owner or parent
        if ns.UI.Label then return ns.UI.Label(owner, text, 0, 0, size or 13) end
        local label = owner:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetJustifyH("LEFT"); label:SetText(text)
        return label
    end
    local function Button(suffix, text, callback)
        local button = CreateFrame("Button", "ArkannsQOLSessionHistory" .. suffix, parent, "UIPanelButtonTemplate")
        button:SetSize(180, 26); button:SetText(text); button:SetScript("OnClick", callback)
        if ns.UI.StyleButton then ns.UI.StyleButton(button) end
        return button
    end
    local function Stamp(value)
        return type(value) == "number" and value > 0 and date and date("%d/%m/%Y %H:%M", value) or L("Date inconnue")
    end
    local function Rate(entry)
        if entry.duration < 60 then return L("Disponible après 1 min.") end
        if metric == "xp" then return (entry.approximateXP and "≥ " or "") .. math.floor(entry.xp * 3600 / entry.duration) end
        return context.FormatMoney(entry.net * 3600 / entry.duration)
    end
    local function Place(widget, x, y, width)
        widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", x, -y)
        if width then widget:SetWidth(width) end
    end
    local heading = Label(L("Historique et progression"), 18)
    local notice = Label(L("100 dernières sessions de ce personnage. Les pauses sont exclues du temps suivi."))
    local current = Label("")
    local newButton = Button("New", L("Enregistrer et recommencer"), function() context.NewSession(); refresh() end)
    local clear = Button("Clear", L("Effacer l’historique"), function() context.Clear(); refresh() end)
    local filters = {}
    for _, item in ipairs({{0, "Tout", "All"}, {7, "7 jours", "7"}, {30, "30 jours", "30"}}) do
        local days = item[1]
        filters[#filters + 1] = Button("Period" .. item[3], L(item[2]), function() period, page, selected = days, 1, nil; refresh() end)
    end
    local kpis = {}
    for index = 1, 6 do kpis[index] = Label("") end
    local graphTitle = Label("", 15)
    local modeButton = Button("Mode", "", function() mode = mode == "sessions" and "detail" or "sessions"; refresh() end)
    local metricButton = Button("Metric", "", function() metric = metric == "xp" and "net" or "xp"; refresh() end)
    local graph = CreateFrame("Frame", "ArkannsQOLSessionHistoryGraph", parent)
    graph:SetHeight(190)
    local background = graph:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(); background:SetColorTexture(.08, .09, .12, .8)
    local zeroLine = graph:CreateTexture(nil, "BACKGROUND")
    zeroLine:SetHeight(1)
    local maximum, minimum = Label("", 11, graph), Label("", 11, graph)
    local firstX, lastX = Label("", 11, graph), Label("", 11, graph)
    local graphMessage = Label("", 13, graph)
    local graphHelp = Label("")
    local listTitle = Label(L("Sessions enregistrées"), 15)
    local empty = Label(L("Aucune session enregistrée pour cette période."))
    for index = 1, 6 do
        local row = Button("Row" .. index, "", function(self) selected = self.entry; mode = "detail"; refresh() end)
        row:SetHeight(48)
        rows[index] = row
    end
    local previous = Button("Previous", L("Précédent"), function() page = page - 1; refresh() end)
    local nextButton = Button("Next", L("Suivant"), function() page = page + 1; refresh() end)
    local pageLabel = Label("")
    local detail = Label("")
    local delete = Button("Delete", L("Supprimer cette session"), function()
        if selected then context.Delete(selected); refresh() end
    end)

    local function DrawGraph(history, width)
        for _, line in ipairs(lines) do line:Hide() end
        for _, dot in ipairs(dots) do dot:Hide() end
        local points, approximate = {}, false
        if mode == "detail" and selected then
            for _, sample in ipairs(selected.samples or {}) do
                points[#points + 1] = {x = sample.elapsed, value = metric == "xp" and sample.xp or sample.net / 10000}
            end
            approximate = selected.approximateXP
        elseif mode == "sessions" then
            for index, entry in ipairs(history) do
                local value
                if entry.duration >= 60 then value = (metric == "xp" and entry.xp or entry.net / 10000) * 3600 / entry.duration end
                points[#points + 1] = {x = index, value = value}
                approximate = approximate or entry.approximateXP
            end
        end
        local low, high, count = 0, 0, 0
        for _, point in ipairs(points) do
            if point.value then low = math.min(low, point.value); high = math.max(high, point.value); count = count + 1 end
        end
        local function Value(value)
            return metric == "xp" and tostring(math.floor(value + .5)) or string.format("%.2f", value)
        end
        maximum:SetText(Value(high)); minimum:SetText(Value(low))
        maximum:ClearAllPoints(); maximum:SetPoint("TOPLEFT", 6, -8)
        minimum:ClearAllPoints(); minimum:SetPoint("BOTTOMLEFT", 6, 24)
        firstX:ClearAllPoints(); firstX:SetPoint("BOTTOMLEFT", 62, 5)
        lastX:ClearAllPoints(); lastX:SetPoint("BOTTOMRIGHT", -8, 5); lastX:SetJustifyH("RIGHT")
        if mode == "detail" then
            firstX:SetText(context.FormatDuration(points[1] and points[1].x or 0))
            lastX:SetText(context.FormatDuration(points[#points] and points[#points].x or 0))
        else
            local function ShortStamp(entry) return entry and entry.startedAt and date and date("%d/%m", entry.startedAt) or "" end
            firstX:SetText(ShortStamp(history[1]))
            lastX:SetText(#history > 1 and ShortStamp(history[#history]) or "")
        end
        local message = ""
        if count == 0 then message = mode == "detail" and L("Sélectionne une session avec des relevés pour afficher sa courbe.") or L("Les courbes utilisent les sessions d’au moins une minute.")
        elseif type(graph.CreateLine) ~= "function" then message = L("Courbes indisponibles sur ce client.") end
        graphMessage:SetText(message); graphMessage:ClearAllPoints(); graphMessage:SetPoint("CENTER"); graphMessage:SetWidth(math.max(1, width - 80))
        graphMessage:SetJustifyH("CENTER")
        local style = ns.UI.GetStyle and ns.UI.GetStyle()
        local color = style and style.accent or {1, .76, .3}
        local bg = style and style.bg or {.08, .09, .12}
        background:SetColorTexture(bg[1], bg[2], bg[3], 1)
        local span = high - low
        if span == 0 then span = 1 end
        zeroLine:ClearAllPoints(); zeroLine:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", 64, 30 + (0 - low) / span * 145)
        zeroLine:SetWidth(math.max(1, width - 80)); zeroLine:SetColorTexture(color[1], color[2], color[3], .25)
        local xlow, xhigh = points[1] and points[1].x or 0, points[#points] and points[#points].x or 1
        local xspan = math.max(1, xhigh - xlow)
        local last, segment = nil, 0
        for index, point in ipairs(points) do
            if point.value ~= nil then
                local x = 64 + (point.x - xlow) / xspan * math.max(1, width - 80)
                local y = 30 + (point.value - low) / span * 145
                local dot = dots[index]
                if not dot then dot = graph:CreateTexture(nil, "OVERLAY"); dot:SetSize(5, 5); dots[index] = dot end
                dot:SetColorTexture(color[1], color[2], color[3], 1); dot:ClearAllPoints(); dot:SetPoint("CENTER", graph, "BOTTOMLEFT", x, y); dot:Show()
                if last and type(graph.CreateLine) == "function" then
                    segment = segment + 1
                    local line = lines[segment]
                    if not line then line = graph:CreateLine(nil, "ARTWORK"); lines[segment] = line end
                    if line then
                        line:SetColorTexture(color[1], color[2], color[3], 1); line:SetThickness(2)
                        line:SetStartPoint("BOTTOMLEFT", graph, last.x, last.y); line:SetEndPoint("BOTTOMLEFT", graph, x, y); line:Show()
                    end
                end
                last = {x = x, y = y}
            else last = nil end
        end
        local unit = metric == "xp" and L("XP") or L("Or (pièces d’or)")
        if mode == "sessions" then unit = metric == "xp" and L("XP / heure") or L("Or net / heure (pièces d’or)") end
        graphTitle:SetText(unit .. ((metric == "xp" and approximate) and " · ≥" or ""))
        graphHelp:SetText(mode == "sessions" and L("Une valeur par session, de la plus ancienne à la plus récente. Les sessions courtes créent une interruption.")
            or L("Valeurs cumulées selon le temps suivi. Les pauses sont exclues. ≥ indique des données XP incomplètes."))
    end

    refresh = function()
        if parent.IsVisible and not parent:IsVisible() then return end
        parent.historyWidth = parent:GetWidth()
        local width = math.max(220, parent:GetWidth() - 32)
        local y = 12
        local function Text(widget)
            Place(widget, 16, y, width); y = y + widget:GetStringHeight() + 12
        end
        local function Buttons(buttons)
            local columns = width >= 480 and #buttons or 1
            local buttonWidth = (width - (columns - 1) * 8) / columns
            for index, button in ipairs(buttons) do Place(button, 16 + ((index - 1) % columns) * (buttonWidth + 8), y + math.floor((index - 1) / columns) * 34, buttonWidth) end
            y = y + math.ceil(#buttons / columns) * 34
        end
        local history, now = {}, context.Now and context.Now() or (time and time())
        for _, entry in ipairs(context.GetHistory()) do
            if period == 0 or (now and entry.endedAt and entry.endedAt >= now - period * 86400) then history[#history + 1] = entry end
        end
        local found
        for _, entry in ipairs(history) do if entry == selected then found = true end end
        if not found then selected = history[#history] end
        local totals = Model.HistoryTotals(history)
        local ongoing = context.GetCurrent()
        current:SetText(ongoing and string.format(L("Session en cours : %s · %d XP · %s. Exclue du bilan enregistré."),
            context.FormatDuration(ongoing.duration), ongoing.xp, context.FormatMoney(ongoing.net)) or L("Le suivi démarrera à l’entrée en jeu."))
        newButton:SetEnabled(ongoing ~= nil); clear:SetEnabled(#context.GetHistory() > 0)
        Text(heading); Text(notice); Text(current); Buttons({newButton, clear}); Buttons(filters)
        for index, days in ipairs({0, 7, 30}) do filters[index]:SetEnabled(period ~= days) end
        local xpRate = totals.xpPerHour and ((totals.approximateXP and "≥ " or "") .. math.floor(totals.xpPerHour)) or "—"
        local goldRate = totals.netPerHour and context.FormatMoney(totals.netPerHour) or "—"
        local texts = {
            string.format(L("Sessions : %d · Temps suivi : %s"), totals.count, context.FormatDuration(totals.duration)),
            string.format(L("XP gagnée : %s%d · Niveaux : %d"), totals.approximateXP and "≥ " or "", totals.xp, totals.levels),
            L("XP / heure") .. " : " .. xpRate,
            L("Or net / heure") .. " : " .. goldRate,
            L("Solde") .. " : " .. context.FormatMoney(totals.net),
            string.format(L("Morts : %d"), totals.deaths),
        }
        -- Two columns only when the money values fit comfortably.
        local columns = width >= 620 and 2 or 1
        local kpiWidth = (width - (columns - 1) * 16) / columns
        local rowHeight = 0
        for index, label in ipairs(kpis) do
            label:SetText(texts[index]); Place(label, 16 + ((index - 1) % columns) * (kpiWidth + 16), y, kpiWidth)
            rowHeight = math.max(rowHeight, label:GetStringHeight() + 14)
            if index % columns == 0 or index == #kpis then y = y + rowHeight; rowHeight = 0 end
        end
        y = y + 8
        modeButton:SetText(mode == "sessions" and L("Vue : entre sessions") or L("Vue : session sélectionnée"))
        metricButton:SetText(metric == "xp" and L("Mesure : XP") or L("Mesure : or net"))
        DrawGraph(history, width)
        Buttons({modeButton, metricButton}); Text(graphTitle)
        Place(graph, 16, y, width); y = y + 202
        Text(graphHelp); Text(listTitle)
        local pages = math.max(1, math.ceil(#history / #rows))
        page = math.max(1, math.min(page, pages))
        empty:SetShown(#history == 0)
        if #history == 0 then Text(empty) end
        for index, row in ipairs(rows) do
            local entry = history[#history - ((page - 1) * #rows + index) + 1]
            row.entry = entry; row:SetShown(entry ~= nil)
            if entry then
                row:SetText((entry == selected and L("Sélectionnée") .. " · " or "") .. Stamp(entry.startedAt) .. " · " .. context.FormatDuration(entry.duration)
                    .. "\n" .. L("XP gagnée") .. " : " .. (entry.approximateXP and "≥ " or "") .. entry.xp .. " · " .. L("Solde") .. " : " .. context.FormatMoney(entry.net))
                Place(row, 16, y, width)
                local text = row:GetFontString()
                if text then text:SetWidth(math.max(1, width - 20)) end
                local height = text and math.max(48, text:GetStringHeight() + 12) or 48
                row:SetHeight(height); y = y + height + 6
            end
        end
        previous:SetEnabled(page > 1); nextButton:SetEnabled(page < pages)
        Buttons({previous, nextButton}); pageLabel:SetText(string.format(L("Page %d / %d"), page, pages)); Text(pageLabel)
        delete:SetShown(selected ~= nil); detail:SetShown(selected ~= nil)
        if selected then
            detail:SetText(Stamp(selected.startedAt) .. " — " .. Stamp(selected.endedAt) .. "\n"
                .. L("Durée") .. " : " .. context.FormatDuration(selected.duration) .. " · " .. L("Morts") .. " : " .. selected.deaths .. " · " .. L("Niveaux gagnés") .. " : " .. selected.levels .. "\n"
                .. L("Or reçu") .. " : " .. context.FormatMoney(selected.income) .. "\n" .. L("Or dépensé") .. " : " .. context.FormatMoney(selected.expense) .. "\n"
                .. (metric == "xp" and L("XP / heure") or L("Or net / heure")) .. " : " .. Rate(selected))
            Text(detail); Buttons({delete})
        end
        parent:SetHeight(y + 12)
    end
    parent:HookScript("OnSizeChanged", function(_, width)
        if parent.historyWidth ~= width then parent.historyWidth = width; refresh() end
    end)
    return refresh
end
