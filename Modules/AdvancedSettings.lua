local _, ns = ...
local L = ns.L
local catalog, categories = ns.AdvancedSettingsCatalog, ns.AdvancedSettingsCategories
local byName = {}
for _, option in ipairs(catalog) do byName[option.name:lower()] = option end
local api = {}
ns.AdvancedSettings = api

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Text(value)
    if not Public(value) then return nil end
    if type(value) == "string" then return value end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return tostring(value) end
end

function api.IsNative(name)
    if not Public(name) or type(name) ~= "string" then return true end
    if ns.AdvancedNativeSettings[name:lower()] then return true end
    if Settings and Settings.GetSetting then
        local ok, setting = pcall(Settings.GetSetting, name)
        if not ok or not Public(setting) or setting then return true end
    end
    return false
end

function api.Read(name)
    local state = {name = name, native = api.IsNative(name)}
    if not C_CVar or type(C_CVar.GetCVarInfo) ~= "function" then
        state.reason = L("Lecture indisponible")
        return state
    end
    local ok, value, default, account, character, locked, secure, readOnly = pcall(C_CVar.GetCVarInfo, name)
    if not ok or not Text(value) then
        state.reason = L("Indisponible sur ce client")
        return state
    end
    state.value, state.default = Text(value), Text(default)
    state.present = true
    if Public(character) and character == true then state.scope = L("Personnage")
    elseif Public(account) and account == true then state.scope = L("Compte")
    else state.scope = L("Client") end
    if state.native then state.reason = L("Déjà dans les menus du jeu")
    elseif not Public(locked) or not Public(secure) or not Public(readOnly)
        or type(locked) ~= "boolean" or type(secure) ~= "boolean" or type(readOnly) ~= "boolean" then
        state.reason = L("Restrictions inconnues")
    elseif locked or readOnly then state.reason = L("Verrouillé par le client")
    elseif not state.default then state.reason = L("Défaut indisponible")
    elseif type(C_CVar.SetCVar) ~= "function" then state.reason = L("Modification indisponible")
    else state.writable = true end
    -- Keep the security flag separate from read-only. The client can still refuse a write.
    state.secure = Public(secure) and secure == true
    return state
end

local function Equal(a, b)
    return a == b or (tonumber(a) ~= nil and tonumber(a) == tonumber(b))
end

local function Preferences()
    ForeverTooltipLibreDB = ForeverTooltipLibreDB or {}
    if type(ForeverTooltipLibreDB.advanced) ~= "table" then ForeverTooltipLibreDB.advanced = {} end
    local settings = ForeverTooltipLibreDB.advanced
    if type(settings.favorites) ~= "table" then settings.favorites = {} end
    return settings
end

function api.ToggleFavorite(name)
    if not Public(name) then return false end
    local option = byName[type(name) == "string" and name:lower() or ""]
    if not option or api.IsNative(option.name) then return false end
    local favorites = Preferences().favorites
    favorites[option.name] = not favorites[option.name] or nil
    if api.Refresh then api.Refresh() end
    return true
end

function api.GetFavorites()
    local result = {}
    for _, option in ipairs(catalog) do
        if Preferences().favorites[option.name] and not api.IsNative(option.name) then
            local name = option.name
            result[#result + 1] = {name = name, label = option.label, Open = function() if api.OpenFavorite then api.OpenFavorite(name) end end}
        end
    end
    return result
end

function api.ExportSettings()
    local result = {favorites = {}}
    for _, item in ipairs(api.GetFavorites()) do result.favorites[item.name] = true end
    return result
end

function api.ImportSettings(settings)
    if not Public(settings) or type(settings) ~= "table" or not Public(settings.favorites) or type(settings.favorites) ~= "table" then return false, L("Favoris invalides.") end
    local favorites = {}
    for name, enabled in pairs(settings.favorites) do
        if not Public(name) or not Public(enabled) or type(name) ~= "string" or type(enabled) ~= "boolean" then return false, L("Favoris invalides.") end
        local option = byName[name:lower()]
        if option and enabled then favorites[option.name] = true end
    end
    local target = Preferences().favorites
    for name in pairs(target) do target[name] = nil end
    for name in pairs(favorites) do target[name] = true end
    if api.Refresh then api.Refresh() end
    return true
end

function api.ReviewReset(selected)
    local review = {}
    if not Public(selected) or type(selected) ~= "table" then return review end
    for _, option in ipairs(catalog) do
        if Public(selected[option.name]) and selected[option.name] then
            local state = api.Read(option.name)
            if state.writable and not Equal(state.value, state.default) then
                review[#review + 1] = {name = option.name, label = option.label, before = state.value, after = state.default}
            end
        end
    end
    return review
end

function api.ApplyReset(review)
    if InCombatLockdown and InCombatLockdown() then return false, L("Disponible hors combat.") end
    if not Public(review) or type(review) ~= "table" then return false, L("Sélection invalide. Revois les options.") end
    local function Current(change)
        if not Public(change) or type(change) ~= "table" or not Public(change.name)
            or not Public(change.before) or not Public(change.after) then return false end
        local option = byName[type(change.name) == "string" and change.name:lower() or ""]
        local state = option and api.Read(option.name)
        return state and state.writable and state.value == change.before and state.default == change.after
    end
    -- Validate the complete review before the first write; never accept stale consent.
    for _, change in ipairs(review) do
        if not Current(change) then
            return false, L("Les valeurs ont changé. Revois la sélection avant de confirmer.")
        end
    end
    local applied = 0
    for _, change in ipairs(review) do
        -- A previous write can update another CVar or its default synchronously.
        if not Current(change) then return false, L("%d réinitialisation(s) effectuée(s). Les valeurs ont changé : revois la sélection."):format(applied) end
        local ok, message = api.Write(change.name, nil, true)
        if not ok then return false, L("%d réinitialisation(s) effectuée(s). %s : %s"):format(applied, change.name, message) end
        applied = applied + 1
    end
    return true, (applied == 1 and L("%d option réinitialisée.") or L("%d options réinitialisées.")):format(applied)
end

function api.Write(name, input, reset)
    -- Only the reviewed catalog can write. The inventory is always read-only.
    if not Public(name) or (not reset and not Public(input)) then return false, L("Valeur privée non modifiable.") end
    local option = byName[type(name) == "string" and name:lower() or ""]
    if not option then return false, L("Option non documentée : lecture seule.") end
    if InCombatLockdown and InCombatLockdown() then return false, L("Disponible hors combat.") end
    local state = api.Read(option.name)
    if not state.writable then return false, state.reason end
    local value
    if reset then
        -- The client's real default may be outside our input range.
        value = state.default
    elseif option.kind == "boolean" then
        if input ~= true and input ~= false then return false, L("Choisis activé ou désactivé.") end
        value = input and "1" or "0"
    elseif option.kind == "choice" then
        for _, choice in ipairs(option.choices) do if input == choice[1] then value = input end end
        if not value then return false, L("Valeur non proposée.") end
    else
        local str = Text(input)
        local number = str and tonumber((str:gsub(",", ".")))
        if not number or number ~= number or number == math.huge or number == -math.huge
            or number < option.min or number > option.max or (option.integer and number % 1 ~= 0) then
            return false, (option.integer and L("Saisis un entier entre %s et %s.") or L("Saisis un nombre entre %s et %s.")):format(option.min, option.max)
        end
        value = tostring(number)
        -- Keep paired bounds coherent without silently changing the other option.
        local pairs = {nameplateMinScale = {"nameplateMaxScale", true}, nameplateMaxScale = {"nameplateMinScale", false},
            nameplateMinAlpha = {"nameplateMaxAlpha", true}, nameplateMaxAlpha = {"nameplateMinAlpha", false}}
        local pair = pairs[option.name]
        local other = pair and tonumber(api.Read(pair[1]).value)
        if other and ((pair[2] and number > other) or (not pair[2] and number < other)) then
            return false, L("Le minimum doit rester inférieur ou égal au maximum.")
        end
    end
    local ok, result = pcall(C_CVar.SetCVar, option.name, value)
    if not ok or not Public(result) or result ~= true then return false, L("Modification refusée par le client.") end
    local after = api.Read(option.name)
    if not after.value then return false, L("Valeur appliquée non vérifiable.") end
    if not Equal(after.value, value) then return false, L("Le client a retenu : %s."):format(after.value) end
    if option.category == "graphics" then
        return true, reset and L("Valeur par défaut confirmée par WoW.") or L("Valeur confirmée par WoW.")
    end
    return true, reset and L("Valeur par défaut rétablie.") or L("Appliqué.")
end

function api.Inventory()
    if type(ConsoleGetAllCommands) ~= "function" then return {}, L("Inventaire indisponible sur ce client.") end
    local ok, commands = pcall(ConsoleGetAllCommands)
    if not ok or not Public(commands) or type(commands) ~= "table" then return {}, L("Inventaire indisponible sur ce client.") end
    local entries, seen = {}, {}
    for _, command in ipairs(commands) do
        if Public(command) and type(command) == "table" and Public(command.commandType) and command.commandType == 0 then
            local name = Text(command.command)
            if name and name:match("^[%a][%w_]*$") and not seen[name:lower()] then
                seen[name:lower()] = true
                local state = api.Read(name)
                if state.present then
                    state.option = byName[name:lower()]
                    local help = Text(command.help)
                    state.help = help and help ~= "" and help or L("Aucune description fournie par le client.")
                    state.consoleCategory = Public(command.category) and command.category or nil
                    entries[#entries + 1] = state
                end
            end
        end
    end
    table.sort(entries, function(a, b) return a.name:lower() < b.name:lower() end)
    return entries
end

local function SafeLabel(value)
    -- Console descriptions are plain text, never active links or texture escapes.
    return (tostring(value or "—"):gsub("|", "||"))
end

local function SearchText(value)
    local text = value
    for _, group in ipairs({{"a", "à", "â", "ä", "À", "Â", "Ä"}, {"c", "ç", "Ç"},
        {"e", "é", "è", "ê", "ë", "É", "È", "Ê", "Ë"}, {"i", "î", "ï", "Î", "Ï"},
        {"o", "ô", "ö", "Ô", "Ö"}, {"u", "ù", "û", "ü", "Ù", "Û", "Ü"}, {"oe", "œ", "Œ"}}) do
        for index = 2, #group do text = text:gsub(group[index], group[1]) end
    end
    -- Fold ASCII only: C locale case conversion can corrupt UTF-8 bytes.
    return (text:gsub("[A-Z]", string.lower))
end

local function HideRowTooltip(row)
    if not GameTooltip or (GameTooltip.IsForbidden and GameTooltip:IsForbidden()) then return end
    local owner = GameTooltip:GetOwner()
    if Public(owner) and owner == row then GameTooltip:Hide() end
end

local function GraphicsHint(option)
    if not option or option.category ~= "graphics" then return nil end
    if option.group == "Raid" and Equal(api.Read("RAIDsettingsEnabled").value, "0") then
        return L("Profil raid désactivé dans WoW.")
    end
    if option.name == "CMAA2Quality" or option.name == "CMAA2ExtraSharpness" then
        local mode = tonumber(api.Read("ffxAntiAliasingMode").value)
        if mode and mode ~= 4 then return L("CMAA2 désactivé dans WoW.") end
    end
    if option.name == "shadowBlendCascades" or option.name == "RAIDshadowBlendCascades" then
        local cvar = option.group == "Raid" and "RAIDshadowNumCascades" or "shadowNumCascades"
        local cascades = tonumber(api.Read(cvar).value)
        if cascades and cascades < 2 then return L("Nécessite plusieurs cascades d’ombres.") end
    end
end

function ns.InitializeAdvancedSettings(rootCategory)
    if not rootCategory or not Settings then return end
    local panel = CreateFrame("Frame", "ArkannsQOLAdvancedPanel", UIParent, "BackdropTemplate")
    panel:Hide()
    local tab, query, filter = categories[1].id, "", 1
    local inventory, inventoryError, rows, tabs = nil, nil, {}, {}
    local listing, drafts = {}, {}
    local selected, resetReview = {}, nil
    local favoritesOnly, modifiedOnly, expert = false, false, false
    local filters = {"Hors menus", "Tout", "Menus du jeu", "Protégés", "Graphismes", "Graph. hors menus"}
    local graphicsFilters = {"Tout", "Décor", "Ombres", "Effets", "Image", "Raid"}
    local graphicsFilter = 1
    local refresh, render, layout, refreshing
    local rowHeight = 112
    local function Label(parent, text, x, y, font)
        local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", x, y)
        label:SetJustifyH("LEFT")
        label:SetText(text)
        return label
    end
    local function Button(parent, name, text, width, callback)
        local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
        button:SetSize(width, 24)
        button:SetText(text)
        button:SetScript("OnClick", callback)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button, "advanced") end
        return button
    end
    local title = Label(panel, L("Réglages avancés"), 16, -16, "GameFontNormalLarge")
    local intro = Label(panel, "", 16, -44)
    intro:SetPoint("TOPRIGHT", -16, -44)
    intro:SetHeight(28)
    local searchLabel = Label(panel, L("Rechercher"), 16, 0)
    local search = CreateFrame("EditBox", "ArkannsQOLAdvancedSearch", panel, "InputBoxTemplate")
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local filterButton = Button(panel, "ArkannsQOLAdvancedFilter", L(filters[filter]), 130, function(self)
        if not MenuUtil or not MenuUtil.CreateContextMenu then return end
        local ownerTab = tab
        local choices = ownerTab == "graphics" and graphicsFilters or filters
        MenuUtil.CreateContextMenu(self, function(_, menu)
            for index, caption in ipairs(choices) do
                local selected = index
                menu:CreateButton(L(caption), function()
                    if tab ~= ownerTab then return end
                    if tab == "graphics" then graphicsFilter = selected else filter = selected end
                    refresh(true)
                end)
            end
        end)
    end)
    local favoritesButton = Button(panel, "ArkannsQOLAdvancedFavorites", L("Favoris"), 94, function()
        favoritesOnly, resetReview = not favoritesOnly, nil
        refresh(true)
    end)
    local modifiedButton = Button(panel, "ArkannsQOLAdvancedModified", L("Modifiés"), 94, function()
        modifiedOnly, resetReview = not modifiedOnly, nil
        refresh(true)
    end)
    local reviewButton, confirmButton, cancelButton
    local status = Label(panel, "", 148, 0)
    status:ClearAllPoints()
    status:SetPoint("BOTTOMLEFT", 148, 14)
    status:SetPoint("BOTTOMRIGHT", -16, 14)
    status:SetHeight(34)
    local count = Label(panel, "", 16, 0)
    count:ClearAllPoints()
    count:SetPoint("BOTTOMLEFT", 16, 24)
    count:SetWidth(122)

    local scroll = CreateFrame("ScrollFrame", "ArkannsQOLAdvancedScroll", panel, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", "ArkannsQOLAdvancedContent", scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local function Instructions()
        status:SetText(L("Étoile : favori • Case : sélectionner pour réinitialiser • Défaut : cette ligne."))
    end
    reviewButton = Button(panel, "ArkannsQOLAdvancedReviewReset", L("Revoir la sélection"), 142, function()
        resetReview = api.ReviewReset(selected)
        refresh(true)
        status:SetText((#resetReview == 1 and L("%d option : compare Actuel et Défaut, puis confirme.")
            or L("%d options : compare Actuel et Défaut, puis confirme.")):format(#resetReview))
    end)
    confirmButton = Button(panel, "ArkannsQOLAdvancedConfirmReset", L("Confirmer"), 100, function()
        if not resetReview then return end
        local ok, message = api.ApplyReset(resetReview)
        resetReview = nil
        if ok then selected = {}; drafts = {} end
        refresh()
        status:SetText(message)
    end)
    cancelButton = Button(panel, "ArkannsQOLAdvancedCancelReset", L("Annuler"), 80, function()
        resetReview = nil
        Instructions()
        refresh(true)
    end)
    local function SelectTab(id)
        tab, query, drafts = id, "", {}
        resetReview, favoritesOnly = nil, false
        search:SetText("")
        search:ClearFocus()
        Instructions()
        if id == "inventory" then inventory, inventoryError = api.Inventory() end
        refresh(true)
    end
    local expertToggle = CreateFrame("CheckButton", "ArkannsQOLAdvancedExpert", panel, "InterfaceOptionsCheckButtonTemplate")
    expertToggle.Text:SetText(L("Afficher les graphismes experts"))
    expertToggle:SetScript("OnClick", function(self)
        expert = self:GetChecked() == true
        if not expert and tab == "graphics" then SelectTab(categories[1].id) else refresh(true) end
    end)
    local returnButton = Button(panel, "ArkannsQOLAdvancedReturn", L("Revenir aux réglages"), 180, function() SelectTab(categories[1].id) end)
    for index = 1, #categories do
        local category = categories[index]
        local button = CreateFrame("Button", "ArkannsQOLAdvancedTab" .. index, panel)
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        local label = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetAllPoints()
        label:SetText(category.label)
        local marker = button:CreateTexture(nil, "OVERLAY")
        marker:SetPoint("BOTTOMLEFT", 0, 0)
        marker:SetPoint("BOTTOMRIGHT", 0, 0)
        marker:SetHeight(2)
        marker:SetColorTexture(1, .72, .2, 1)
        button:SetScript("OnClick", function() SelectTab(category.id) end)
        tabs[index] = {button = button, id = category.id, background = background, label = label, marker = marker}
    end
    search:SetScript("OnTextChanged", function(self)
        query = SearchText(self:GetText() or "")
        if refresh then refresh(true) end
    end)

    local function Commit(row, value, reset)
        if not row.option then return end
        local option = row.option
        local ok, message = api.Write(option.name, value, reset)
        if ok or reset or option.kind ~= "number" then
            drafts[option.name] = nil
            row.input:ClearFocus()
        else
            drafts[option.name] = row.input:GetText()
        end
        status:SetText(SafeLabel(L("%s : %s"):format(option.label, message)))
        refresh()
    end
    local function CreateRow(index)
        local row = CreateFrame("Frame", "ArkannsQOLAdvancedRow" .. index, content)
        row:SetHeight(rowHeight - 4)
        row.title = Label(row, "", 0, 0, "GameFontNormal")
        row.title:SetPoint("TOPRIGHT", -74, 0)
        row.title:SetHeight(17)
        row.description = Label(row, "", 0, -21)
        row.description:SetPoint("TOPRIGHT", 0, -21)
        row.description:SetHeight(34)
        row.info = Label(row, "", 0, -90)
        row.info:SetPoint("TOPRIGHT", 0, -90)
        row.info:SetHeight(15)
        row.check = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        row.check:SetPoint("TOPLEFT", -3, -57)
        row.check.Text:SetText(L("Activé"))
        row.check:SetScript("OnClick", function(self) Commit(row, self:GetChecked() and true or false) end)
        row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        row.input:SetPoint("TOPLEFT", 5, -60)
        row.input:SetSize(74, 24)
        row.input:SetAutoFocus(false)
        row.input:SetMaxLetters(16)
        row.input:SetScript("OnTextChanged", function(self, userInput)
            if userInput and row.option then
                drafts[row.option.name] = self:GetText()
                row.dirty = true
            end
        end)
        row.input:SetScript("OnEnterPressed", function(self) Commit(row, self:GetText()) end)
        row.input:SetScript("OnEscapePressed", function(self)
            if row.option then drafts[row.option.name] = nil end
            self:ClearFocus()
            render()
        end)
        row.apply = Button(row, nil, L("Appliquer"), 84, function() Commit(row, row.input:GetText()) end)
        row.apply:SetPoint("TOPLEFT", 90, -60)
        row.choice = Button(row, nil, "", 130, function(self)
            if not row.option then return end
            if not MenuUtil or not MenuUtil.CreateContextMenu then return end
            local option = row.option
            MenuUtil.CreateContextMenu(self, function(_, menu)
                for _, choice in ipairs(option.choices) do
                    local value = choice[1]
                    menu:CreateButton(choice[2], function()
                        if row.option == option then Commit(row, value) end
                    end)
                end
            end)
        end)
        row.choice:SetPoint("TOPLEFT", 0, -60)
        row.default = Button(row, nil, L("Défaut"), 80, function() Commit(row, nil, true) end)
        row.default:SetPoint("TOPRIGHT", 0, -60)
        row.favorite = Button(row, nil, "", 32, function()
            if row.option then api.ToggleFavorite(row.option.name) end
        end)
        row.favorite:SetPoint("TOPRIGHT", -34, 2)
        row.select = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
        row.select:SetPoint("TOPRIGHT", 0, 4)
        row.select.Text:SetText("")
        row.select:SetScript("OnClick", function(self)
            if row.option then selected[row.option.name] = self:GetChecked() and true or nil end
            resetReview = nil
            refresh()
        end)
        row:SetScript("OnEnter", function(self)
            if not GameTooltip or not GameTooltip.SetOwner or not self.state then return end
            if GameTooltip.IsForbidden and GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(SafeLabel(self.state.name))
            GameTooltip:AddLine(SafeLabel(self.help), 1, 1, 1, true)
            if self.option and self.option.kind == "number" then
                GameTooltip:AddLine(L("Plage proposée : %s à %s"):format(self.option.min, self.option.max), 1, 1, 1, true)
            end
            GameTooltip:AddLine(L("Actuel : %s\nDéfaut : %s"):format(SafeLabel(self.state.value), SafeLabel(self.state.default)), 1, 1, 1, true)
            if self.state.reason then GameTooltip:AddLine(self.state.reason, 1, .8, .3, true) end
            if self.state.secure then GameTooltip:AddLine(L("Réglage protégé par WoW."), 1, .8, .3, true) end
            if self.state.graphicsHint then GameTooltip:AddLine(self.state.graphicsHint, 1, .8, .3, true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", HideRowTooltip)
        row:EnableMouse(true)
        rows[index] = row
    end
    render = function()
        local offset = scroll:GetVerticalScroll()
        local first = math.floor(offset / rowHeight) + 1
        local needed = math.ceil(scroll:GetHeight() / rowHeight) + 1
        while #rows < needed do CreateRow(#rows + 1) end
        local combat = InCombatLockdown and InCombatLockdown()
        for index, row in ipairs(rows) do
            local itemIndex = first + index - 1
            local entry = index <= needed and listing[itemIndex] or nil
            if not entry or not row.state or row.state.name ~= entry.name then
                HideRowTooltip(row)
                row.input:ClearFocus()
            end
            row:SetShown(entry ~= nil)
            if entry then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -(itemIndex - 1) * rowHeight)
                row:SetPoint("TOPRIGHT", 0, -(itemIndex - 1) * rowHeight)
                local option = (resetReview or favoritesOnly or tab ~= "inventory") and entry or nil
                local state = api.Read(entry.name)
                if not resetReview and not state.reason then state.graphicsHint = GraphicsHint(option) end
                if row.state and (row.state.value ~= state.value or row.state.default ~= state.default or row.state.reason ~= state.reason
                    or row.state.graphicsHint ~= state.graphicsHint) then HideRowTooltip(row) end
                row.option, row.state = option, state
                row.title:SetText(SafeLabel(option and option.label or entry.name))
                local description = option and option.help or entry.help
                row.help = description
                if option and option.kind == "number" then description = description .. " [" .. option.min .. "–" .. option.max .. "]" end
                row.description:SetText(SafeLabel(description))
                local summary = state.reason or (combat and option and L("Disponible hors combat")) or state.graphicsHint
                if not option and not summary then summary = entry.option and L("Documenté dans les catégories") or L("Non documenté : lecture seule") end
                row.info:SetText(SafeLabel(summary or L("Actuel : %s • Défaut : %s • %s"):format(state.value or "—", state.default or "—", state.scope or "")))
                row.check:SetShown(option ~= nil and option.kind == "boolean")
                row.input:SetShown(option ~= nil and option.kind == "number")
                row.apply:SetShown(option ~= nil and option.kind == "number")
                row.choice:SetShown(option == nil or option.kind == "choice")
                row.default:SetShown(option ~= nil)
                row.favorite:SetShown(option ~= nil)
                local favorite = option and Preferences().favorites[option.name]
                if ns.UI and ns.UI.SetFavoriteIcon then ns.UI.SetFavoriteIcon(row.favorite, favorite)
                else row.favorite:SetText(favorite and "*" or "+") end
                row.select:SetShown(option ~= nil)
                row.select:SetChecked(option and selected[option.name] or false)
                row.select:SetEnabled(option ~= nil and state.writable and not combat and not Equal(state.value, state.default))
                local writable = state.writable and not combat and option ~= nil and not resetReview
                row.check:SetEnabled(writable)
                row.apply:SetEnabled(writable)
                row.choice:SetEnabled(writable)
                row.input:SetEnabled(writable)
                row.default:SetEnabled(writable and not Equal(state.value, state.default))
                row.dirty = option and drafts[option.name] ~= nil or nil
                if option then
                    row.check:SetChecked(Equal(state.value, "1"))
                    local inputText = (not resetReview and drafts[option.name]) or state.value or ""
                    -- Do not reset the caret while typing or during unrelated CVar updates.
                    if row.input:GetText() ~= inputText then row.input:SetText(inputText) end
                    if option.choices then
                        local label = state.value or L("Indisponible")
                        for _, choice in ipairs(option.choices) do if Equal(state.value, choice[1]) then label = choice[2] end end
                        row.choice:SetText(SafeLabel(label))
                    end
                else row.choice:SetText(L("Lecture seule")) end
            else row.option, row.state, row.dirty = nil, nil, nil end
        end
    end
    layout = function()
        local width = math.max(320, panel:GetWidth())
        intro:SetHeight(math.max(28, intro:GetStringHeight()))
        local top = -52 - intro:GetHeight()
        expertToggle:ClearAllPoints(); expertToggle:SetPoint("TOPLEFT", 12, top)
        expertToggle.Text:SetWidth(width - 60); expertToggle.Text:SetJustifyH("LEFT")
        returnButton:ClearAllPoints(); returnButton:SetPoint("TOPLEFT", 16, top)
        top = top - 34
        local visibleTabs = {}
        for _, item in ipairs(tabs) do
            local visible = tab ~= "inventory" and (item.id ~= "graphics" or expert)
            item.button:SetShown(visible)
            if visible then visibleTabs[#visibleTabs + 1] = item end
        end
        local columns = math.max(1, math.min(#visibleTabs, math.floor((width - 32) / 72)))
        local tabRows = math.ceil(#visibleTabs / columns)
        local tabWidth = (width - 32) / columns
        for index, item in ipairs(visibleTabs) do
            item.button:ClearAllPoints()
            item.button:SetPoint("TOPLEFT", 16 + ((index - 1) % columns) * tabWidth, top - math.floor((index - 1) / columns) * 32)
            item.button:SetSize(tabWidth - 2, 28)
        end
        local toolbarY = top - 10 - tabRows * 32
        searchLabel:ClearAllPoints()
        searchLabel:SetPoint("TOPLEFT", 16, toolbarY - 6)
        search:ClearAllPoints()
        search:SetPoint("TOPLEFT", 96, toolbarY)
        search:SetSize(math.max(70, width - 262), 24)
        filterButton:ClearAllPoints()
        filterButton:SetPoint("TOPRIGHT", -16, toolbarY)
        favoritesButton:SetPoint("TOPLEFT", 16, toolbarY - 31)
        modifiedButton:SetPoint("TOPLEFT", 116, toolbarY - 31)
        reviewButton:SetPoint("TOPLEFT", 216, toolbarY - 31)
        reviewButton:SetWidth(math.max(80, math.min(142, width - 232)))
        confirmButton:SetPoint("TOPLEFT", 16, toolbarY - 62)
        cancelButton:SetPoint("TOPLEFT", 122, toolbarY - 62)
        local reviewHeight = resetReview and 31 or 0
        status:ClearAllPoints(); count:ClearAllPoints()
        status:SetPoint("BOTTOMLEFT", width < 460 and 16 or 148, 14)
        status:SetPoint("BOTTOMRIGHT", -16, 14)
        status:SetHeight(width < 460 and math.max(34, status:GetStringHeight()) or 34)
        count:SetPoint("BOTTOMLEFT", 16, width < 460 and status:GetHeight() + 22 or 24)
        local footerHeight = width < 460 and status:GetHeight() + 42 or 62
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 16, toolbarY - 73 - reviewHeight)
        scroll:SetSize(width - 50, math.max(80, panel:GetHeight() + toolbarY - 73 - reviewHeight - footerHeight))
        content:SetWidth(scroll:GetWidth())
    end
    refresh = function(resetScroll)
        if refreshing then return end
        refreshing = true
        listing = {}
        local isInventory = tab == "inventory" and not favoritesOnly and not resetReview
        title:SetText(isInventory and L("Diagnostic — inventaire du client") or L("Réglages avancés"))
        expertToggle:SetShown(not isInventory); expertToggle:SetChecked(expert)
        returnButton:SetShown(isInventory)
        favoritesButton:SetShown(not isInventory); reviewButton:SetShown(not isInventory)
        favoritesButton:SetText(favoritesOnly and L("Favoris seuls") or L("Favoris"))
        modifiedButton:SetText(modifiedOnly and L("Modifiés seuls") or L("Modifiés"))
        confirmButton:SetShown(resetReview ~= nil)
        cancelButton:SetShown(resetReview ~= nil)
        confirmButton:SetEnabled(resetReview ~= nil and #resetReview > 0 and not (InCombatLockdown and InCombatLockdown()))
        local selectionCount = 0
        for _ in pairs(selected) do selectionCount = selectionCount + 1 end
        reviewButton:SetText(L("Revoir (%d)"):format(selectionCount))
        reviewButton:SetEnabled(selectionCount > 0)
        filterButton:SetShown(isInventory or (tab == "graphics" and not favoritesOnly and not resetReview))
        filterButton:SetText(L(tab == "graphics" and graphicsFilters[graphicsFilter] or filters[filter]))
        for _, item in ipairs(tabs) do
            local active = not favoritesOnly and tab == item.id
            item.button:SetEnabled(not active)
            item.background:SetColorTexture(active and .24 or .09, active and .19 or .09, active and .09 or .09, .95)
            item.label:SetTextColor(1, active and .82 or .95, active and .38 or .95)
            item.marker:SetShown(active)
        end
        if resetReview then
            for _, change in ipairs(resetReview) do listing[#listing + 1] = byName[change.name:lower()] end
            intro:SetText(L("Réinitialisation sélectionnée : seules ces options seront remises à leur défaut. Aucun changement avant confirmation."))
        elseif isInventory then
            if not inventory then inventory, inventoryError = api.Inventory() end
            for _, entry in ipairs(inventory) do
                local matches = (filter == 1 and not entry.native) or filter == 2 or (filter == 3 and entry.native)
                    or (filter == 4 and (entry.secure or not entry.writable) and not entry.native)
                    or (filter == 5 and entry.consoleCategory == 1)
                    or (filter == 6 and entry.consoleCategory == 1 and not entry.native)
                local state = api.Read(entry.name)
                if matches and (not modifiedOnly or (state.value and state.default and not Equal(state.value, state.default)))
                    and (query == "" or SearchText(entry.name .. " " .. entry.help):find(query, 1, true)) then listing[#listing + 1] = entry end
            end
            intro:SetText(inventoryError or L("Inventaire du client, en lecture seule. « Hors menus » : aucun menu natif identifié."))
        else
            intro:SetText(favoritesOnly and L("Favoris de toutes les catégories. Active la vue expert pour inclure les graphismes.")
                or (tab == "graphics" and L("Graphismes experts : le rendu dépend du mode actif. Les préréglages de WoW peuvent remplacer ces valeurs.")
                or L("Réglages hors menus. Chaque bouton Défaut reprend la valeur du client.")))
            for _, option in ipairs(catalog) do
                local state = api.Read(option.name)
                if ((favoritesOnly and Preferences().favorites[option.name]) or (not favoritesOnly and option.category == tab)) and not state.native
                    and (option.category ~= "graphics" or expert)
                    and (favoritesOnly or tab ~= "graphics" or graphicsFilter == 1 or option.group == graphicsFilters[graphicsFilter])
                    and (not modifiedOnly or (state.value and state.default and not Equal(state.value, state.default)))
                    and (query == "" or SearchText(option.label .. " " .. option.name .. " " .. option.help):find(query, 1, true)) then listing[#listing + 1] = option end
            end
        end
        layout()
        count:SetText(L("Résultats : %d"):format(#listing))
        content:SetHeight(math.max(1, #listing * rowHeight))
        local maximum = math.max(0, #listing * rowHeight - scroll:GetHeight())
        scroll:SetVerticalScroll(resetScroll and 0 or math.min(scroll:GetVerticalScroll(), maximum))
        render()
        refreshing = nil
    end
    scroll:HookScript("OnVerticalScroll", function()
        if refreshing then return end
        for _, row in ipairs(rows) do HideRowTooltip(row) end
        render()
    end)
    panel:SetScript("OnShow", function() inventory = nil; Instructions(); refresh() end)
    panel:SetScript("OnHide", function()
        search:ClearFocus()
        drafts = {}
        resetReview = nil
        for _, row in ipairs(rows) do row.input:ClearFocus(); row.dirty = nil; HideRowTooltip(row) end
        if tab == "inventory" then tab = categories[1].id end
    end)
    panel:HookScript("OnSizeChanged", function() refresh() end)
    local events = CreateFrame("Frame", "ArkannsQOLAdvancedEvents")
    for _, event in ipairs({"CVAR_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
    local queued
    events:SetScript("OnEvent", function()
        if not panel:IsShown() or queued then return end
        queued = true
        local function Update()
            queued = nil
            if panel:IsShown() then inventory = nil; refresh() end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0, Update) else Update() end
    end)
    ns.advancedCategory = Settings.RegisterCanvasLayoutSubcategory(rootCategory, panel, L("Réglages avancés"))
    api.Refresh = function()
        if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(panel, "advanced") end
        if panel:IsShown() then refresh() end
    end
    api.OpenFavorites = function()
        favoritesOnly, modifiedOnly, resetReview = true, false, nil
        if tab == "inventory" then tab = categories[1].id end
        query = ""; search:SetText("")
        if Settings.OpenToCategory then Settings.OpenToCategory(ns.advancedCategory:GetID()) end
        refresh(true)
    end
    api.OpenFavorite = function(name)
        local option = byName[type(name) == "string" and name:lower() or ""]
        if option and option.category == "graphics" then expert = true end
        api.OpenFavorites()
        search:SetText(name); query = SearchText(name); refresh(true)
    end
    ns.OpenAdvancedInventory = function()
        favoritesOnly, modifiedOnly, resetReview = false, false, nil
        if Settings.OpenToCategory then Settings.OpenToCategory(ns.advancedCategory:GetID()) end
        SelectTab("inventory")
    end
    if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(panel, "advanced") end
    if ns.RegisterModule then
        ns.RegisterModule("advanced", {label = L("Réglages avancés"), icon = "Interface\\Icons\\Trade_Engineering", category = function() return ns.advancedCategory end,
            Summary = function() return L("%d favori(s) • %d options documentées"):format(#api.GetFavorites(), #catalog) end,
            Favorites = api.GetFavorites, OpenFavorites = api.OpenFavorites, Refresh = api.Refresh,
            ExportSettings = api.ExportSettings, ImportSettings = api.ImportSettings})
    end
end
