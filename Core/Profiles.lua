local _, ns = ...
local L = ns.L
local api = {}
ns.Profiles = api
local profileVersion = 3
local styledModules = {tooltips = true, reminders = true, session = true, talents = true, ranks = true}
local screenPositions = {tooltips = true, reminders = true, session = true, talents = true}

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

local function Export(module, id)
    local ok, result = pcall(function() return Copy(module.ExportSettings()) end)
    if not ok or type(result) ~= "table" then return nil, L("Configuration illisible : ") .. (module.label or "module") end
    if id == "appearance" then result.overrides = nil
    elseif styledModules[id] and ns.UI then result._appearanceOverride = ns.UI.IsOverride(id) end
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
    if value == nil then return L("Non défini") end
    if value == true then return L("activé") end
    if value == false then return L("désactivé") end
    if type(value) == "table" then return L("(liste vide)") end
    return (tostring(value):gsub("|", "||"):gsub("[\r\n]", " "))
end

local fieldLabels = {
    _appearanceOverride = "Apparence personnalisée", enabled = "Activation", compact = "Mode compact",
    nextColor = "Couleur du prochain point", futureColor = "Couleur des points suivants", errorColor = "Couleur des erreurs",
    bg = "Fond", text = "Texte", accent = "Bordure et accents", font = "Police", fontSize = "Taille du texte",
    scale = "Échelle", opacity = "Opacité", borderSize = "Épaisseur de bordure", padding = "Marges", gap = "Espacement",
    appearance = "Apparence", favorites = "Favoris", pins = "Modules favoris", grid = "Grille", snap = "Accrochage",
    locked = "Position verrouillée", showTitle = "Afficher le titre", border = "Bordure", width = "Largeur",
    hideCombat = "Masquer en combat", pauseAFK = "Pause AFK", theme = "Thème", layout = "Disposition",
    hideZero = "Masquer les valeurs nulles", expandOnHover = "Développer au survol", visible = "Statistiques visibles",
    order = "Ordre d’affichage", cursor = "Suivre le curseur", offsetX = "Marge horizontale", offsetY = "Marge verticale",
    contexts = "Types d’infobulle", custom = "Réglages propres à ce type", units = "Unités", items = "Objets", spells = "Sorts",
    mouseoverDistance = "Distance au survol", rounded = "Arrondi des estimations", portrait = "Ancrage au portrait",
    frame = "Style du badge", background = "Fond", tooltip = "Texte d’infobulle",
    qualityBorders = "Contours de rareté", qualityOpacity = "Opacité du contour", qualityThickness = "Épaisseur du contour",
    qualityInnerGlow = "Halo intérieur", qualityUncommonOnly = "Masquer gris et blancs", qualityColors = "Couleurs de rareté",
    transmogIcons = "Transmos manquantes", glowIntensity = "Intensité de surbrillance", futureSteps = "Points suivants visibles",
    interval = "Fréquence de vérification", style = "Style", corner = "Coin", size = "Taille", color = "Couleur",
    exceptions = "Exceptions", ignored = "Exceptions", auras = "Effets surveillés", tracking = "Suivis surveillés",
    duration = "Durée", xp = "XP gagnée", nextLevel = "Prochain niveau", income = "Or reçu", expense = "Or dépensé",
    net = "Solde", deaths = "Morts", levels = "Niveaux gagnés", title = "Titre", customTitle = "Titre personnalisé",
    titleSize = "Taille du titre", columns = "Colonnes", align = "Alignement", outline = "Contour du texte",
    iconSize = "Taille des icônes", showIcons = "Afficher les icônes", shadow = "Ombre du texte",
    textColor = "Couleur du texte", titleColor = "Couleur du titre", borderColor = "Couleur de bordure", backgroundAlpha = "Opacité du fond",
}
local function FieldLabel(key)
    if fieldLabels[key] then return L(fieldLabels[key]) end
    local module = ns.modules and ns.modules[key]
    if module then return module.label end
    for _, option in ipairs(ns.AdvancedSettingsCatalog or {}) do if key == option.name then return option.label end end
    return Safe(key)
end
local function Color(value)
    if type(value) ~= "table" or #value ~= 3 then return end
    for i = 1, 3 do if type(value[i]) ~= "number" or value[i] < 0 or value[i] > 1 then return end end
    return ("#%02X%02X%02X"):format(math.floor(value[1] * 255 + .5), math.floor(value[2] * 255 + .5), math.floor(value[3] * 255 + .5))
end
local function Position(value, normalized)
    if type(value) ~= "table" or type(value.x) ~= "number" or type(value.y) ~= "number" then return L("Automatique") end
    if normalized then return ("X %.1f %% / Y %.1f %%"):format(value.x * 100, value.y * 100) end
    return ("X %.1f / Y %.1f"):format(value.x, value.y)
end
local function Differences(before, after, path, result, normalizedPosition)
    if Same(before, after) then return end
    if Color(before) or Color(after) then
        result[#result + 1] = path .. " : " .. (Color(before) or Safe(before)) .. " > " .. (Color(after) or Safe(after))
        return
    end
    if type(before) == "table" or type(after) == "table" then
        local keys, seen = {}, {}
        for key in pairs(type(before) == "table" and before or {}) do keys[#keys + 1] = key; seen[key] = true end
        for key in pairs(type(after) == "table" and after or {}) do if not seen[key] then keys[#keys + 1] = key end end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        if #keys == 0 then result[#result + 1] = path .. " : " .. Safe(before) .. " > " .. Safe(after) end
        local hasPosition = (type(before) == "table" and (before.x ~= nil or before.y ~= nil))
            or (type(after) == "table" and (after.x ~= nil or after.y ~= nil))
        if hasPosition and not Same({x = type(before) == "table" and before.x, y = type(before) == "table" and before.y},
            {x = type(after) == "table" and after.x, y = type(after) == "table" and after.y}) then
            result[#result + 1] = path .. " — " .. L("Position") .. " : " .. Position(before, normalizedPosition) .. " > " .. Position(after, normalizedPosition)
        end
        for _, key in ipairs(keys) do
            local old, new
            if type(before) == "table" then old = before[key] end
            if type(after) == "table" then new = after[key] end
            if key ~= "x" and key ~= "y" then Differences(old, new, path .. " — " .. FieldLabel(key), result) end
        end
    else result[#result + 1] = path .. " : " .. Safe(before) .. " > " .. Safe(after) end
end

function api.List()
    local names = {}
    for name in pairs(Store()) do if type(name) == "string" then names[#names + 1] = name end end
    table.sort(names)
    return names
end

function api.Delete(name)
    if type(name) ~= "string" or Store()[name] == nil then return false, L("Profil introuvable.") end
    Store()[name] = nil
    return true, L("Profil supprimé. Les réglages actuels sont conservés.")
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
        local config, message = Export(module, id)
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
    if not ok or type(profile) ~= "table" or (profile.version ~= 1 and profile.version ~= 2 and profile.version ~= profileVersion)
        or type(profile.modules) ~= "table" or (profile.version >= 2 and type(profile.moduleVersions) ~= "table") then
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
                local before, message = Export(module, id)
                if not before then return nil, message end
                config = Copy(config)
                if profile.version < 3 then
                    if styledModules[id] then
                        local appearance = profile.modules.appearance
                        local overrides = type(appearance) == "table" and appearance.overrides
                        if type(overrides) == "table" then config._appearanceOverride = overrides[id] == true
                        else config._appearanceOverride = before._appearanceOverride end
                    end
                    if id == "distance" then
                        local tooltips = profile.modules.tooltips
                        local value = type(tooltips) == "table" and tooltips.mouseoverDistance
                        if type(value) ~= "boolean" then value = before.mouseoverDistance end
                        config.mouseoverDistance = value
                    end
                end
                if id == "appearance" then config.overrides = nil end
                if id == "tooltips" then config.mouseoverDistance = nil end
                if styledModules[id] and type(config._appearanceOverride) ~= "boolean" then
                    return nil, L("Apparence du module invalide.")
                end
                local version = 0
                if profile.version >= 2 and profile.moduleVersions[id] ~= nil then
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
                        Differences(beforeView, afterView, module.label or id, plan.changes, screenPositions[id])
                    else
                        Differences(before, config, module.label or id, plan.changes, screenPositions[id])
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
    local ok, accepted, message = pcall(function()
        local candidate = Copy(config)
        if id == "appearance" then candidate.overrides = ns.UI.ExportSettings().overrides end
        if styledModules[id] then
            if type(candidate._appearanceOverride) ~= "boolean" then return false, L("Apparence du module invalide.") end
            candidate._appearanceOverride = nil
        end
        local accepted, message = module.ImportSettings(candidate)
        if accepted == true and styledModules[id] then ns.UI.SetOverride(id, config._appearanceOverride) end
        return accepted, message
    end)
    if not ok or accepted ~= true then return false, type(message) == "string" and message or ((module.label or id) .. L(" : configuration refusée.")) end
    if module.Refresh then pcall(module.Refresh) end
    local actual = Export(module, id)
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
        local current = module and Export(module, change.id)
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
        local current = module and Export(module, change.id)
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
        local after = Export(ns.modules[change.id], change.id)
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
        local current = ns.modules[change.id] and Export(ns.modules[change.id], change.id)
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
    local apply, undo, choose, save, remove, overwriteName
    local function CancelOverwrite()
        overwriteName = nil
        if save then save:SetText(L("Enregistrer")) end
    end
    local function Invalidate()
        plan = nil; apply:SetEnabled(false); preview:SetText(L("Choisis les modules puis clique sur « Voir les changements ». Aucun réglage n’est appliqué pendant l’aperçu."))
        if remove then remove:SetEnabled(profileName ~= nil and Store()[profileName] ~= nil) end
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
    remove = Button("ArkannsQOLProfileDelete", L("Supprimer"), 100, 242, -134, function()
        local target = profileName
        if not target or not ns.UI or not ns.UI.Confirm then return end
        local expected = Store()[target]
        ns.UI.Confirm(L("Supprimer le profil « %s » ? Les réglages actuels seront conservés."):format(Safe(target)), function()
            if Store()[target] ~= expected then status:SetText(L("Profil modifié depuis l’aperçu. Revois les changements.")); return end
            local ok, message = api.Delete(target)
            status:SetText(message)
            if ok and profileName == target then
                profileName = nil; name:SetText(""); choose:SetText(L("Choisir un profil"))
            end
            CancelOverwrite(); Invalidate()
        end)
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
        choose:SetWidth(math.max(160, width - 148))
        remove:ClearAllPoints(); remove:SetPoint("TOPRIGHT", -16, nameY - 34)
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
