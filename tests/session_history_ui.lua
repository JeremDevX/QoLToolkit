-- Exercise real history-page callbacks and line geometry with explicit widgets.
local function CheckHistoryPage(english)
    local env = setmetatable({}, {__index = _G})
    local frames, widgets = {}, {}
    local methods = {}
    local function Widget(name, parent, kind)
        local widget = setmetatable({parent = parent, kind = kind, shown = true, enabled = true,
            width = 620, height = 14, text = "", scripts = {}, points = {}}, {__index = methods})
        widgets[#widgets + 1] = widget
        if name then frames[name] = widget end
        return widget
    end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetHeight(value)
        if self.height == value then return end
        self.height = value
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, self.width, value) end
    end
    function methods:SetWidth(value)
        if self.width == value then return end
        self.width = value
        if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, value, self.height) end
    end
    function methods:GetWidth() return self.width end
    function methods:SetText(value) self.text = value; if self.fontString then self.fontString.text = value end end
    function methods:GetText() return self.text end
    function methods:GetStringHeight()
        local count = 0
        for line in (self.text .. "\n"):gmatch("(.-)\n") do count = count + math.max(1, math.ceil(#line * 6 / math.max(1, self.width))) end
        return count * 14
    end
    function methods:GetFontString()
        if not self.fontString then self.fontString = Widget(nil, self, "text"); self.fontString.text = self.text end
        return self.fontString
    end
    function methods:CreateFontString(name) return Widget(name, self, "text") end
    function methods:CreateTexture(name) return Widget(name, self, "texture") end
    function methods:CreateLine(name) return Widget(name, self, "line") end
    function methods:SetScript(key, callback) self.scripts[key] = callback end
    function methods:HookScript(key, callback)
        local previous = self.scripts[key]
        self.scripts[key] = function(...) if previous then previous(...) end; callback(...) end
    end
    function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
    function methods:ClearAllPoints() self.points = {} end
    function methods:SetAllPoints() end
    function methods:SetJustifyH() end
    function methods:SetEnabled(value) self.enabled = value end
    function methods:SetShown(value) self.shown = value end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:SetColorTexture(...) self.color = {...} end
    function methods:SetThickness(value) self.thickness = value end
    function methods:SetStartPoint(_, owner, x, y) self.startPoint = {owner = owner, x = x, y = y} end
    function methods:SetEndPoint(_, owner, x, y) self.endPoint = {owner = owner, x = x, y = y} end
    env.CreateFrame = function(kind, name, parent) return Widget(name, parent, kind) end
    env.date = os.date
    local style = {bg = english and {.88, .9, .94} or {.08, .09, .12}, accent = {.3, .6, .9}}
    local ns = {English = {}, UI = {StyleButton = function() end, GetStyle = function() return style end}}
    ns.L = function(text) return english and ns.English[text] or text end
    local function Load(path)
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("QoLToolkit", ns)
    end
    Load("Locales/enUS-Utilities.lua"); Load("Locales/enUS-SessionHistory.lua")
    Load("Modules/SessionJournalModel.lua"); Load("Modules/SessionHistory.lua")
    local now, history, calls = 1700000000, {}, {new = 0, clear = 0, delete = 0}
    local active = {duration = 3600, xp = 99999, net = 50000, pause = "afk"}
    local parent = Widget("HistoryBody")
    local refresh = ns.CreateSessionHistoryPanel(parent, {
        GetHistory = function() return history end, GetCurrent = function() return active end,
        Now = function() return now end,
        FormatDuration = function(value) return string.format("%02d:%02d:%02d", math.floor(value / 3600), math.floor(value / 60) % 60, value % 60) end,
        FormatMoney = function(value) return string.format("%.2f gold", value / 10000) end,
        NewSession = function() calls.new = calls.new + 1 end,
        Delete = function(entry)
            calls.delete = calls.delete + 1
            for index, item in ipairs(history) do if item == entry then table.remove(history, index); break end end
        end,
        Clear = function() calls.clear = calls.clear + 1; history = {} end,
    })
    local function Button(suffix) return assert(frames["ArkannsQOLSessionHistory" .. suffix]) end
    local function Click(suffix)
        local button = Button(suffix); assert(button.enabled and button.shown)
        button.scripts.OnClick(button)
    end
    local function Record(index, days, duration)
        local stamp = now - days * 86400
        return {duration = duration or 600, xp = index * 100, income = 0, expense = 10000, net = -10000,
            levels = 0, deaths = index, startedAt = stamp - 600, endedAt = stamp, samples = {
                {elapsed = 0, xp = 0, net = 0, levels = 0, deaths = 0},
                {elapsed = duration or 600, xp = index * 100, net = -10000, levels = 0, deaths = index},
            }}
    end
    refresh()
    assert(not Button("Clear").enabled and not Button("Delete").shown, "Empty history has no destructive action")
    assert(not Button("Previous").enabled and not Button("Next").enabled)
    Click("New"); assert(calls.new == 1)
    history[1] = Record(1, 1)
    refresh()
    assert(Button("Row1").entry == history[1] and not Button("Row2").shown)
    Click("Row1")
    local lineCount = 0
    for _, widget in ipairs(widgets) do
        if widget.kind == "line" and widget.shown then
            lineCount = lineCount + 1
            assert(widget.startPoint.x >= 64 and widget.endPoint.x <= parent.width - 48)
        end
    end
    assert(lineCount > 0, "Selected samples render a real line, even for a single saved session")
    Click("Metric")
    for _, widget in ipairs(widgets) do
        if widget.kind == "line" and widget.shown then assert(widget.endPoint.y < widget.startPoint.y, "Negative gold remains below zero") end
    end
    Click("Mode") -- Across-session rates, one point is valid without a line.
    for index = 2, 8 do history[index] = Record(index, index * 5) end
    refresh()
    local summaryFound, progressionFound = false, false
    for _, widget in ipairs(widgets) do
        if widget.text == string.format(ns.L("Sessions : %d · Temps suivi : %s"), 8, "01:20:00") then summaryFound = true end
        if widget.text == string.format(ns.L("XP gagnée : %s%d · Niveaux : %d"), "", 3600, 0) then progressionFound = true end
    end
    assert(summaryFound and progressionFound, "Paused current session never enters saved KPIs")
    local createLine = methods.CreateLine
    methods.CreateLine = nil; refresh()
    local unavailable
    for _, widget in ipairs(widgets) do if widget.text == ns.L("Courbes indisponibles sur ce client.") then unavailable = true end end
    assert(unavailable, "Missing native charts have an explicit fallback")
    methods.CreateLine = createLine
    assert(Button("Next").enabled and Button("Row1").entry == history[8])
    Click("Next"); assert(Button("Previous").enabled and Button("Row1").entry == history[2])
    Click("Previous"); assert(Button("Row1").entry == history[8])
    Click("Period7"); assert(Button("Row1").entry == history[1] and not Button("Row2").shown)
    Click("Period30"); assert(Button("Row1").entry == history[6] and not Button("Next").enabled)
    Click("PeriodAll"); Click("Row2"); assert(Button("Row2").entry == history[7])
    Click("Delete"); assert(calls.delete == 1 and #history == 7)
    local wide = parent.height
    parent:SetWidth(300)
    assert(parent.height > wide, "Narrow page stacks controls and KPI rows")
    for _, widget in ipairs(widgets) do
        if widget.parent == parent and widget.shown and widget.points[1] then
            local point = widget.points[1]
            assert(point[2] >= 0 and point[2] + widget.width <= parent.width, "Visible controls fit the page")
        end
    end
    local prior = parent.height
    parent:Hide(); history[8] = Record(10, 1); refresh()
    assert(parent.height == prior, "Hidden page does no layout work")
    parent:Show(); refresh()
    active = nil; refresh(); assert(not Button("New").enabled)
    Click("Clear"); assert(calls.clear == 1 and #history == 0)
    assert(not Button("Delete").shown and not Button("Clear").enabled)
end
CheckHistoryPage(false)
CheckHistoryPage(true)
print("PASS: history page filters, pagination, selection, native charts, narrow layout and destructive callbacks in FR/EN")
