local _, ns = ...
local L = ns.L
local api = {}
ns.Profiles = api
local profileVersion = 2

local function Copy(value, seen, depth, budget)
    if issecretvalue and issecretvalue(value) then error(L("Valeur privée non transférable.")) end
    budget = budget or {items = 0, bytes = 0}
    budget.items = budget.items + 1
    if type(value) == "string" then budget.bytes = budget.bytes + #value end
    if budget.items > 10000 or budget.bytes > 1048576 then error(L("Configuration trop volumineuse.")) end
    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "string" then return value end
    if kind == "number" and value == value and math.abs(value) < math.huge then return value end
    if kind ~= "table" or (depth or 0) > 16 then error(L("Configuration invalide.")) end
    seen = seen or {}
    if seen[value] then error(L("Configuration circulaire.")) end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
        if issecretvalue and issecretvalue(key) then error(L("Clé privée non transférable.")) end
        if type(key) ~= "string" and type(key) ~= "number" then error(L("Clé de configuration invalide.")) end
        Copy(key, seen, (depth or 0) + 1, budget)
        result[key] = Copy(item, seen, (depth or 0) + 1, budget)
    end
    seen[value] = nil
    return result
end

local function Same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not Same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

local function Class()
    if not UnitClass then return nil end
    local _, class = UnitClass("player")
    if not (issecretvalue and issecretvalue(class)) and type(class) == "string" then return class end
end

local function Store()
    ForeverTooltipLibreDB = ForeverTooltipLibreDB or {}
    if type(ForeverTooltipLibreDB.profiles) ~= "table" then ForeverTooltipLibreDB.profiles = {} end
    return ForeverTooltipLibreDB.profiles
end

local function Modules()
    local ids = {}
    for id, module in pairs(ns.modules or {}) do
        if type(module.ExportSettings) == "function" and type(module.ImportSettings) == "function" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

local function Export(module)
    local ok, result = pcall(function() return Copy(module.ExportSettings()) end)
    if not ok or type(result) ~= "table" then return nil, L("Configuration illisible : ") .. (module.label or "module") end
    return result
end

local function Migrate(module, config, before, version)
    local migrations = module.profileMigrations or {}
    local label = module.label or "module"
    if type(version) ~= "number" or version % 1 ~= 0 or version < 0 or version > #migrations then
        return nil, L("Version de configuration non prise en charge pour « ") .. label .. L(" ».")
    end
    if version == #migrations then return config end
    local ok, result = pcall(function()
        local candidate, current = Copy(config), Copy(before)
        for step = version + 1, #migrations do migrations[step](candidate, current) end
        return Copy(candidate)
    end)
    if not ok then return nil, L("Impossible de mettre à jour la configuration de « ") .. label .. L(" ».") end
    return result
end

local function Safe(value)
    if value == nil then return L("(absent)") end
    if value == true then return L("activé") end
    if value == false then return L("désactivé") end
    if type(value) == "table" then return L("(liste vide)") end
    return (tostring(value):gsub("|", "||"):gsub("[\r\n]", " "))
end

local function Differences(before, after, path, result)
    if Same(before, after) then return end
    if type(before) == "table" or type(after) == "table" then
        local keys, seen = {}, {}
        for key in pairs(type(before) == "table" and before or {}) do keys[#keys + 1] = key; seen[key] = true end
        for key in pairs(type(after) == "table" and after or {}) do if not seen[key] then keys[#keys + 1] = key end end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        if #keys == 0 then result[#result + 1] = path .. " : " .. Safe(before) .. " > " .. Safe(after) end
        for _, key in ipairs(keys) do
            local old, new
            if type(before) == "table" then old = before[key] end
            if type(after) == "table" then new = after[key] end
            Differences(old, new, path .. "." .. Safe(key), result)
        end
    else result[#result + 1] = path .. " : " .. Safe(before) .. " > " .. Safe(after) end
end

function api.List()
    local names = {}
    for name in pairs(Store()) do if type(name) == "string" then names[#names + 1] = name end end
    table.sort(names)
    return names
end

function api.Save(name, overwrite)
    if type(name) ~= "string" then return false, L("Donne un nom au profil.") end
    name = name:match("^%s*(.-)%s*$")
    local _, letters = name:gsub("[^\128-\191]", "")
    if name == "" or #name > 400 or letters > 100 or name:find("[%c|]") then return false, L("Nom invalide (100 caractères maximum).") end
    if Store()[name] ~= nil and not overwrite then return false, L("Ce profil existe déjà. Clique sur « Remplacer » pour confirmer."), "exists" end
    local profile = {version = profileVersion, class = Class(), modules = {}, moduleVersions = {}}
    for _, id in ipairs(Modules()) do
        local module = ns.modules[id]
        local config, message = Export(module)
        if not config then return false, message end
        profile.modules[id] = config
        if module.profileMigrations then profile.moduleVersions[id] = #module.profileMigrations end
    end
    local ok = pcall(Copy, profile)
    if not ok then return false, L("Configuration trop volumineuse ou invalide.") end
    Store()[name] = profile
    return true, L("Profil « ") .. name .. L(" » enregistré pour le compte.")
end

function api.Preview(name, selected)
    local ok, profile = pcall(Copy, Store()[name])
    if not ok or type(profile) ~= "table" or (profile.version ~= 1 and profile.version ~= profileVersion)
        or type(profile.modules) ~= "table" or (profile.version == profileVersion and type(profile.moduleVersions) ~= "table") then
        return nil, L("Profil invalide ou version non prise en charge.")
    end
    if type(selected) ~= "table" then return nil, L("Sélectionne les modules à copier.") end
    local plan = {name = name, modules = {}, changes = {}, warnings = {}, class = Class(), source = profile}
    for _, id in ipairs(Modules()) do
        if selected[id] then
            local module, config = ns.modules[id], profile.modules[id]
            if config == nil then
                plan.warnings[#plan.warnings + 1] = module.label .. L(" : absent du profil, conservé.")
            elseif id == "talents" and not module.profileClassIndependent and (not profile.class or not plan.class or profile.class ~= plan.class) then
                plan.warnings[#plan.warnings + 1] = L("Talents : classe différente ou inconnue, configuration actuelle conservée.")
            elseif type(config) ~= "table" then return nil, L("Configuration invalide : ") .. module.label
            else
                local before, message = Export(module)
                if not before then return nil, message end
                local version = 0
                if profile.version == profileVersion and profile.moduleVersions[id] ~= nil then
                    version = profile.moduleVersions[id]
                end
                config, message = Migrate(module, config, before, version)
                if not config then return nil, message end
                if not Same(before, config) then
                    plan.modules[#plan.modules + 1] = {id = id, before = before, after = config}
                    if module.ProfileDisplay then
                        local beforeView, afterView = Copy(before), Copy(config)
                        module.ProfileDisplay(beforeView)
                        module.ProfileDisplay(afterView)
                        Differences(beforeView, afterView, module.label or id, plan.changes)
                    else
                        Differences(before, config, module.label or id, plan.changes)
                    end
                end
            end
        end
    end
    for id in pairs(profile.modules) do
        if selected[id] and not (ns.modules and ns.modules[id]) then plan.warnings[#plan.warnings + 1] = Safe(id) .. L(" : module indisponible, ignoré.") end
    end
    return plan
end

local function Import(id, config)
    local module = ns.modules and ns.modules[id]
    if not module or type(module.ImportSettings) ~= "function" then return false, L("Module indisponible : ") .. id end
    local ok, accepted, message = pcall(function() return module.ImportSettings(Copy(config)) end)
    if not ok or accepted ~= true then return false, type(message) == "string" and message or ((module.label or id) .. L(" : configuration refusée.")) end
    if module.Refresh then pcall(module.Refresh) end
    local actual = Export(module)
    if not actual or not Same(actual, config) then return false, (module.label or id) .. L(" : résultat différent de l’aperçu ou non vérifiable.") end
    return true
end

local function Restore(changes)
    local errors = {}
    for index = #changes, 1, -1 do
        local change = changes[index]
        local ok, message = Import(change.id, change.before)
        if not ok then errors[#errors + 1] = message end
    end
    return #errors == 0, table.concat(errors, " ")
end

local function RemainingUndo(changes)
    local undo = {modules = {}}
    for _, change in ipairs(changes) do
        local module = ns.modules and ns.modules[change.id]
        local current = module and Export(module)
        if not current or not Same(current, change.before) then
            undo.modules[#undo.modules + 1] = {id = change.id, before = change.before, after = current}
        end
    end
    return #undo.modules > 0 and undo or nil
end

function api.Apply(plan)
    if type(plan) ~= "table" or type(plan.modules) ~= "table" or plan.class ~= Class() then return false, L("Recrée l’aperçu du profil.") end
    if InCombatLockdown and InCombatLockdown() then return false, L("Disponible hors combat.") end
    local ok, source = pcall(Copy, Store()[plan.name])
    if not ok or not Same(source, plan.source) then return false, L("Profil modifié depuis l’aperçu. Revois les changements.") end
    if #plan.modules == 0 then return false, L("Aucun changement sélectionné.") end
    -- Closing the layout preview may restore saved positions. Validate afterwards.
    if ns.StopAllPreviews then ns.StopAllPreviews() end
    for _, change in ipairs(plan.modules) do
        local module = ns.modules and ns.modules[change.id]
        local current = module and Export(module)
        if not current or not Same(current, change.before) then return false, L("Configuration modifiée depuis l’aperçu. Revois les changements.") end
    end
    local attempted = {}
    for _, change in ipairs(plan.modules) do
        attempted[#attempted + 1] = change
        local ok, message = Import(change.id, change.after)
        if not ok then
            local restored, failure = Restore(attempted)
            if not restored then
                api.undo = RemainingUndo(attempted)
            end
            return false, message .. (restored and L(" Configuration initiale restaurée.") or L(" Restauration incomplète : ") .. failure)
        end
    end
    local undo = {modules = {}}
    for _, change in ipairs(plan.modules) do
        local after = Export(ns.modules[change.id])
        undo.modules[#undo.modules + 1] = {id = change.id, before = Copy(change.before), after = after}
    end
    api.undo = undo
    return true, L("Profil appliqué. Les modules non sélectionnés sont conservés.")
end

function api.Undo()
    if not api.undo then return false, L("Aucun profil à annuler.") end
    if InCombatLockdown and InCombatLockdown() then return false, L("Disponible hors combat.") end
    if ns.StopAllPreviews then ns.StopAllPreviews() end
    for _, change in ipairs(api.undo.modules) do
        local current = ns.modules[change.id] and Export(ns.modules[change.id])
        if not current or not Same(current, change.after) then return false, L("Configuration modifiée depuis l’application : annulation bloquée pour préserver tes changements.") end
    end
    local ok, message = Restore(api.undo.modules)
    if ok then api.undo = nil else api.undo = RemainingUndo(api.undo.modules) end
    return ok, ok and L("Configuration initiale restaurée.") or (L("Restauration incomplète : ") .. message)
end

function ns.InitializeProfiles(rootCategory)
    if not rootCategory or not Settings then return end
    local panel = CreateFrame("Frame", "ArkannsQOLProfilesPanel", UIParent, "BackdropTemplate")
    panel:Hide()
    local selected, checks, plan, profileName = {}, {}, nil, nil
    local function Label(text, x, y, font)
        local label = panel:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", x, y); label:SetJustifyH("LEFT"); label:SetText(text)
        return label
    end
    local function Button(name, text, width, x, y, callback)
        local button = CreateFrame("Button", name, panel, "UIPanelButtonTemplate")
        button:SetPoint("TOPLEFT", x, y); button:SetSize(width, 24); button:SetText(text); button:SetScript("OnClick", callback)
        if ns.UI and ns.UI.StyleButton then ns.UI.StyleButton(button, "profiles") end
        return button
    end
    Label(L("Profils du compte"), 16, -16, "GameFontNormalLarge")
    local intro = Label(L("Réglages des modules et apparence, partagés entre tes personnages.\nCompteurs, builds de talents et valeurs du jeu (CVars/graphismes) exclus. Favoris inclus."), 16, -46)
    intro:SetPoint("TOPRIGHT", -16, -46); intro:SetHeight(44)
    local name = CreateFrame("EditBox", "ArkannsQOLProfileName", panel, "InputBoxTemplate")
    name:SetPoint("TOPLEFT", 22, -100); name:SetSize(220, 24); name:SetAutoFocus(false); name:SetMaxLetters(100)
    name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local status = Label("", 16, -166)
    status:SetPoint("TOPRIGHT", -16, -166); status:SetHeight(42)
    local scroll = CreateFrame("ScrollFrame", "ArkannsQOLProfilePreviewScroll", panel, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(1, 1); scroll:SetScrollChild(content)
    local preview = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    preview:SetPoint("TOPLEFT"); preview:SetJustifyH("LEFT"); preview:SetText("")
    local apply, undo, choose, save, overwriteName
    local function CancelOverwrite()
        overwriteName = nil
        if save then save:SetText(L("Enregistrer")) end
    end
    local function Invalidate()
        plan = nil; apply:SetEnabled(false); preview:SetText(L("Choisis les modules puis clique sur « Voir les changements ». Aucun réglage n’est appliqué pendant l’aperçu."))
        content:SetHeight(math.max(1, preview:GetStringHeight() + 20)); scroll:SetVerticalScroll(0)
    end
    save = Button("ArkannsQOLProfileSave", L("Enregistrer"), 110, 254, -100, function()
        local entered = name:GetText():match("^%s*(.-)%s*$")
        local ok, message, reason = api.Save(entered, overwriteName == entered)
        status:SetText(Safe(message))
        if reason == "exists" then overwriteName = entered; save:SetText(L("Remplacer"))
        else CancelOverwrite() end
        if ok then profileName = entered; choose:SetText(Safe(profileName)); name:ClearFocus(); Invalidate() end
    end)
    name:SetScript("OnTextChanged", CancelOverwrite)
    choose = Button("ArkannsQOLProfileChoose", L("Choisir un profil"), 220, 16, -134, function()
        local names, index = api.List(), 0
        local function Select(saved)
            CancelOverwrite()
            profileName = saved
            choose:SetText(profileName and Safe(profileName) or L("Aucun profil enregistré"))
            if profileName then name:SetText(profileName) end
            Invalidate()
        end
        if #names > 0 and MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(choose, function(_, menu)
                if menu.SetScrollMode then menu:SetScrollMode(300) end
                for _, saved in ipairs(names) do menu:CreateButton(Safe(saved), function() Select(saved) end) end
            end)
            return
        end
        for i, saved in ipairs(names) do if saved == profileName then index = i end end
        Select(#names > 0 and names[index % #names + 1] or nil)
    end)
    Button("ArkannsQOLProfileReview", L("Voir les changements"), 180, 16, -246, function()
        local message
        plan, message = api.Preview(profileName, selected)
        if not plan then status:SetText(message); apply:SetEnabled(false); return end
        local lines = {L("Profil : ") .. Safe(profileName), ""}
        for _, warning in ipairs(plan.warnings) do lines[#lines + 1] = warning end
        for _, change in ipairs(plan.changes) do lines[#lines + 1] = change end
        if #plan.changes == 0 then lines[#lines + 1] = L("Aucun changement pour les modules sélectionnés.") end
        preview:SetText(table.concat(lines, "\n"))
        content:SetHeight(math.max(1, preview:GetStringHeight() + 20)); scroll:SetVerticalScroll(0)
        apply:SetEnabled(#plan.modules > 0)
        status:SetText(#plan.modules .. L(" module(s), ") .. #plan.changes .. L(" valeur(s) à modifier. Vérifie la liste avant d’appliquer."))
    end)
    apply = Button("ArkannsQOLProfileApply", L("Appliquer"), 100, 202, -246, function()
        local ok, message = api.Apply(plan)
        Invalidate(); status:SetText(Safe(message)); undo:SetEnabled(api.undo ~= nil)
    end)
    undo = Button("ArkannsQOLProfileUndo", L("Annuler l’application"), 166, 308, -246, function()
        local ok, message = api.Undo()
        Invalidate(); status:SetText(Safe(message)); undo:SetEnabled(api.undo ~= nil)
    end)
    local function Layout()
        local width = math.max(320, panel:GetWidth())
        intro:SetHeight(math.max(44, intro:GetStringHeight()))
        local nameY = -56 - intro:GetHeight()
        name:ClearAllPoints(); name:SetPoint("TOPLEFT", 22, nameY); name:SetWidth(width - 160)
        save:ClearAllPoints(); save:SetPoint("TOPRIGHT", -16, nameY)
        choose:ClearAllPoints(); choose:SetPoint("TOPLEFT", 16, nameY - 34)
        status:ClearAllPoints(); status:SetPoint("TOPLEFT", 16, nameY - 66); status:SetPoint("TOPRIGHT", -16, nameY - 66)
        local columns = math.max(1, math.floor((width - 32) / 140))
        for index, check in ipairs(checks) do
            check:ClearAllPoints(); check:SetPoint("TOPLEFT", 12 + ((index - 1) % columns) * ((width - 32) / columns), nameY - 110 - math.floor((index - 1) / columns) * 27)
            check.Text:SetWidth((width - 32) / columns - 32)
        end
        local y = nameY - 118 - math.ceil(#checks / columns) * 27
        local review = _G.ArkannsQOLProfileReview
        review:ClearAllPoints(); review:SetPoint("TOPLEFT", 16, y)
        apply:ClearAllPoints(); apply:SetPoint("TOPLEFT", 202, y)
        undo:ClearAllPoints(); undo:SetPoint("TOPLEFT", 16, y - 30)
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 16, y - 68)
        scroll:SetSize(width - 50, math.max(80, panel:GetHeight() + y - 88))
        content:SetWidth(scroll:GetWidth()); preview:SetWidth(scroll:GetWidth() - 8)
        content:SetHeight(math.max(1, preview:GetStringHeight() + 20))
    end
    for index, id in ipairs(Modules()) do
        local check = CreateFrame("CheckButton", "ArkannsQOLProfileModule" .. index, panel, "InterfaceOptionsCheckButtonTemplate")
        check.Text:SetText(ns.modules[id].label or id); check.Text:SetWidth(126); check.Text:SetJustifyH("LEFT")
        check:SetChecked(true); selected[id] = true; check.moduleID = id
        check:SetScript("OnClick", function(self) selected[id] = self:GetChecked() and true or nil; Invalidate() end)
        checks[#checks + 1] = check
    end
    panel:HookScript("OnSizeChanged", Layout)
    panel:SetScript("OnShow", function()
        Invalidate(); undo:SetEnabled(api.undo ~= nil); Layout()
        if ns.UI and ns.UI.StylePanel then ns.UI.StylePanel(panel, "profiles") end
    end)
    panel:SetScript("OnHide", function() name:ClearFocus(); CancelOverwrite(); Invalidate() end)
    Invalidate(); undo:SetEnabled(false)
    ns.profilesCategory = Settings.RegisterCanvasLayoutSubcategory(rootCategory, panel, L("Profils"))
end
