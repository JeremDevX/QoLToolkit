local _, ns = ...
local Data = {}
ns.TalentPlanData = Data

-- Blizzard's Forever UI and API contracts (read-only; never stage or commit talents):
-- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua
-- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua
-- https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TraitConstantsDocumentation.lua
local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Number(value)
    return Readable(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function Integer(value)
    return Number(value) and value == math.floor(value)
end

local function Positive(value)
    return Number(value) and value > 0
end

local function String(value)
    return Readable(value) and type(value) == "string" and value ~= ""
end

local function Call(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, result = pcall(func, ...)
    if ok and Readable(result) then return result end
end

local function Table(value)
    return Readable(value) and type(value) == "table"
end

local function Fail(reason)
    return nil, reason
end

local function Unsupported(node, reason)
    node.unsupported = node.unsupported or reason
end

local function RecognizeClassRows(rows, rowSet)
    -- Forever 1.60.1.70862 class grid. Require all seven rows before ignoring outliers.
    local firstY, spacing, rowCount = 2130, 600, 7
    for index = 0, rowCount - 1 do
        if not rowSet[firstY + index * spacing] then return nil end
    end
    local rowIndex = {}
    for _, y in ipairs(rows) do
        local index = math.floor((y - firstY) / spacing + 0.5)
        -- Some class talents sit ten units above or below their row.
        if index >= 0 and index < rowCount and math.abs(y - (firstY + index * spacing)) <= 10 then
            rowIndex[y] = index
        end
    end
    return rowIndex
end

local function Conditions(configID, ids, node, currencyID)
    if not Table(ids) then
        Unsupported(node, "Conditions de ce talent indisponibles.")
        return
    end
    -- Keep alternatives intact, including entry conditions. The native API documents
    -- isSufficient; the shared server implementation corroborates AND within a
    -- condition and sufficient alternatives across node/selected entry:
    -- https://github.com/TrinityCore/TrinityCore/blob/master/src/server/game/Spells/TraitMgr.cpp
    node.availability = {required = {}, sufficient = {}}
    for _, id in ipairs(ids) do
        local info = Integer(id) and Call(C_Traits.GetConditionInfo, configID, id)
        if not Table(info) then
            Unsupported(node, "Une condition de ce talent est indisponible.")
        elseif not Integer(info.type) or not Readable(info.isAlwaysMet) or not Readable(info.isSufficient) then
            Unsupported(node, "Une condition de ce talent est masquée.")
        elseif info.type == 0 or info.type == 5 then
            local condition = {minLevel = 0, requiredPoints = 0}
            local understood = info.isAlwaysMet == true
            if not info.isAlwaysMet and Integer(info.spentAmountRequired)
                and info.spentAmountRequired >= 0 then
                if Positive(info.traitCurrencyID) and info.traitCurrencyID ~= currencyID then
                    Unsupported(condition, "Ce palier utilise une autre réserve de points.")
                else
                    condition.requiredPoints = info.spentAmountRequired
                    node.requiredPointsSource = "condition"
                end
                understood = true
            end
            if not info.isAlwaysMet and Integer(info.playerLevel) and info.playerLevel > 0 then
                condition.minLevel = info.playerLevel
                understood = true
            end
            if not info.isAlwaysMet and (Positive(info.questID) or Positive(info.achievementID) or Positive(info.specSetID)
                or Positive(info.traitCondAccountElementID)) then
                -- isMet combines all sources. If a dynamic and a fixed source coexist,
                -- false cannot tell us whether the future level or the quest is missing.
                if not Readable(info.isMet) or info.isMet ~= true then
                    Unsupported(condition, "Condition de personnage ou d’Héritage non remplie ou indéterminée.")
                end
                understood = true
            end
            if not understood then
                -- Forever class-row conditions may omit their spending threshold.
                -- Resolve only plain Available conditions against a coherent row below.
                condition.inferRowGate = info.type == 0 and not info.isSufficient
                    and Readable(info.isGate) and Readable(info.spentAmountRequired)
                    and Readable(info.playerLevel) and Readable(info.questID)
                    and Readable(info.achievementID) and Readable(info.specSetID)
                    and Readable(info.traitCondAccountElementID) and Readable(info.traitCurrencyID)
                    and info.spentAmountRequired == nil
                    and (not Positive(info.traitCurrencyID) or info.traitCurrencyID == currencyID)
                Unsupported(condition, "Condition spéciale non simulable : vérifier ce talent dans le jeu.")
            end
            if info.type == 0 then
                local list = info.isSufficient and node.availability.sufficient or node.availability.required
                list[#list + 1] = condition
            elseif not info.isAlwaysMet then
                -- Rank-conditional scope is not exposed by GetConditionInfo. Never
                -- convert a partial-rank rule into one level for the entire talent.
                Unsupported(node, "Limite de rang conditionnelle : vérifier ce talent dans le jeu.")
            end
        elseif info.type == 2 then
            Unsupported(node, "Rangs accordés sans point : planification non prise en charge.")
        elseif info.type < 0 or info.type > 5 then
            Unsupported(node, "Type de condition non reconnu.")
        end
    end
end

local function Entry(configID, entryID)
    local entry = Call(C_Traits.GetEntryInfo, configID, entryID)
    if not Table(entry) or not Integer(entry.definitionID) then return nil end
    local definition = Call(C_Traits.GetDefinitionInfo, entry.definitionID)
    if not Table(definition) then return nil end
    local spellID = Integer(definition.spellID) and definition.spellID > 0 and definition.spellID or nil
    local spell = spellID and C_Spell and Call(C_Spell.GetSpellInfo, spellID)
    if spellID and not Table(spell) and C_Spell then
        Call(C_Spell.RequestLoadSpellData, spellID)
    end
    local name = String(definition.overrideName) and definition.overrideName
        or Table(spell) and String(spell.name) and spell.name
    if not name then return nil end
    local icon = Positive(definition.overrideIcon) and definition.overrideIcon
        or Table(spell) and Positive(spell.iconID) and spell.iconID or 134400
    return { name = name, icon = icon, spellID = spellID }, entry
end

local function Read(frame)
    if not frame or type(frame.GetConfigID) ~= "function" or type(frame.GetTalentTreeID) ~= "function" then
        return Fail("Ouvrez la fenêtre de talents de votre personnage.")
    end
    if type(frame.IsInspecting) == "function" then
        local inspecting = Call(frame.IsInspecting, frame)
        if inspecting == nil or inspecting then return Fail("Le plan est réservé aux talents de votre personnage.") end
    end
    if not C_Traits or not C_ClassTalents then return Fail("L’API de talents Forever est indisponible.") end
    local configID, treeID = Call(frame.GetConfigID, frame), Call(frame.GetTalentTreeID, frame)
    local activeID = Call(C_ClassTalents.GetActiveConfigID)
    if not Integer(configID) or configID <= 0 or not Integer(treeID) or not Integer(activeID) then
        return Fail("Les talents ne sont pas encore chargés.")
    end
    local ownConfig, specGroup = configID == activeID, nil
    if C_SpecializationInfo then
        for group = 1, 2 do
            local other = Call(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group)
            if Integer(other) and other == configID then ownConfig, specGroup = true, group end
        end
        if not specGroup and configID == activeID then
            local group = Call(C_SpecializationInfo.GetActiveSpecGroup)
            if group == 1 or group == 2 then specGroup = group end
        end
    end
    if not ownConfig then return Fail("Cette configuration n’appartient pas à votre personnage.") end
    local active = Call(C_Traits.GetConfigInfo, activeID)
    local config = Call(C_Traits.GetConfigInfo, configID)
    if not Table(active) or not Table(active.treeIDs) or not Table(config) or not Table(config.treeIDs) then
        return Fail("La configuration de talents est indisponible.")
    end
    local activeTree, configTree = false, false
    for _, id in ipairs(active.treeIDs) do if Integer(id) and id == treeID then activeTree = true end end
    for _, id in ipairs(config.treeIDs) do if Integer(id) and id == treeID then configTree = true end end
    if not activeTree or not configTree then return Fail("Cet arbre ne correspond pas à votre classe.") end
    local className, classToken = UnitClass("player")
    if not String(className) or not String(classToken) then return Fail("Votre classe est indisponible.") end
    local display = Call(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    local nodeIDs = Call(C_Traits.GetTreeNodes, treeID)
    if not Table(display) or not Table(nodeIDs) or #display == 0 or #nodeIDs == 0 then
        return Fail("Les arbres de talents ne sont pas encore chargés.")
    end
    local currencies = Call(C_Traits.GetTreeCurrencyInfo, configID, treeID, true)
    if not Table(currencies) or #currencies ~= 1 or not Table(currencies[1])
        or not Integer(currencies[1].traitCurrencyID) then
        return Fail("La réserve de points de talents est indisponible ou non reconnue.")
    end
    local currencyID = currencies[1].traitCurrencyID
    local catalog = { treeID = treeID, configID = configID, specGroup = specGroup or 1,
        classToken = classToken, className = className,
        groups = {}, nodes = {}, actualCounts = {}, actualChoices = {}, maxPoints = 51,
        levelSource = "Début à choisir : 10 sans bonus d’Héritage.",
        gateSource = "Paliers interprétés par branche ; validation finale dans le jeu.",
    }
    local groupMap, rawNodes = {}, {}
    for index, group in ipairs(display) do
        if not Table(group) or not Integer(group.groupID) or not String(group.displayName) then
            return Fail("Les branches de talents sont incomplètes.")
        end
        local item = { id = group.groupID, name = group.displayName,
            icon = Number(group.icon) and group.icon or 134400,
            order = Number(group.orderIndex) and group.orderIndex or index }
        groupMap[item.id] = item
        catalog.groups[#catalog.groups + 1] = item
    end
    table.sort(catalog.groups, function(a, b) return a.order == b.order and a.id < b.id or a.order < b.order end)
    local count = 0
    for _, nodeID in ipairs(nodeIDs) do
        if not Integer(nodeID) then return Fail("Identifiant de talent invalide.") end
        local info = Call(C_Traits.GetNodeInfo, configID, nodeID)
        if not Table(info) or not Readable(info.isVisible) then return Fail("Un talent est indisponible ou masqué.") end
        rawNodes[nodeID] = info
        if info.isVisible then
            local maxRanks = Number(info.totalMaxRanks) and info.totalMaxRanks > 0 and info.totalMaxRanks or info.maxRanks
            if not Integer(maxRanks) or maxRanks < 1 or maxRanks > 100 or not Table(info.groupIDs)
                or not Table(info.entryIDs) then return Fail("Les rangs ou les branches d’un talent sont incomplets.") end
            local node = { id = nodeID, entries = {}, maxRanks = maxRanks, minLevel = 0,
                requiredPoints = 0, required = {}, sufficient = {}, excludes = {},
                posX = Number(info.posX) and info.posX or nil, posY = Number(info.posY) and info.posY or nil }
            for _, groupID in ipairs(info.groupIDs) do
                if Integer(groupID) and groupMap[groupID] then
                    if node.groupID and node.groupID ~= groupID then Unsupported(node, "Talent partagé entre plusieurs branches.") end
                    node.groupID = groupID
                end
            end
            if not node.groupID then Unsupported(node, "Branche de ce talent inconnue.") end
            for _, entryID in ipairs(info.entryIDs) do
                if not Integer(entryID) then return Fail("Identifiant de rang invalide.") end
                local entry, rawEntry = Entry(configID, entryID)
                if not entry then return Fail("Le nom ou l’icône d’un talent est en cours de chargement.") end
                entry.minLevel, entry.requiredPoints = 0, 0
                if Integer(rawEntry.maxRanks) and rawEntry.maxRanks >= 1 and rawEntry.maxRanks <= 100 then
                    entry.maxRanks = rawEntry.maxRanks
                else
                    Unsupported(entry, "Rang maximal de ce choix indisponible.")
                end
                node.entries[entryID] = entry
                Conditions(configID, rawEntry.conditionIDs, entry, currencyID)
            end
            if next(node.entries) == nil then return Fail("Les options d’un talent sont indisponibles.") end
            Conditions(configID, info.conditionIDs, node, currencyID)
            local costs = Call(C_Traits.GetNodeCost, configID, nodeID)
            if not Table(costs) then
                Unsupported(node, "Coût de ce talent indisponible.")
            elseif #costs ~= 1 or not Table(costs[1]) or not Integer(costs[1].ID)
                or costs[1].ID ~= currencyID or not Number(costs[1].amount) or costs[1].amount ~= 1 then
                Unsupported(node, "Ce talent n’utilise pas un point de talent ordinaire.")
            end
            if Readable(info.type) and info.type == 1 and #info.entryIDs > 1 then
                -- Tiered entries are successive tiers, not mutually exclusive choices.
                Unsupported(node, "Talent à paliers multiples : planification non prise en charge.")
            end
            if Number(info.flags) and math.floor(info.flags / 2) % 2 == 1 then
                Unsupported(node, "Ce talent ne peut pas être acheté.")
            end
            if not Integer(info.ranksPurchased) or info.ranksPurchased < 0 or info.ranksPurchased > node.maxRanks then
                return Fail("Les points investis sont indisponibles.")
            end
            catalog.actualCounts[nodeID] = info.ranksPurchased
            if Table(info.activeEntry) and Integer(info.activeEntry.entryID) and node.entries[info.activeEntry.entryID] then
                catalog.actualChoices[nodeID] = info.activeEntry.entryID
            elseif info.ranksPurchased > 0 then
                return Fail("Le choix appris dans un talent est indisponible.")
            end
            catalog.nodes[nodeID] = node
            count = count + 1
        end
    end
    if count == 0 then return Fail("Aucun talent visible pour cette classe.") end
    -- Only infer points from a recognized grid.
    -- ponytail: five points per row is a Forever/Classic fallback, not a generic trait rule.
    for _, group in ipairs(catalog.groups) do
        local rowSet, rows, coherent = {}, {}, true
        -- A hidden row still occupies its tier; omitting it would make later
        -- talents appear five points cheaper when falling back to geometry.
        for _, raw in pairs(rawNodes) do
            if Table(raw.groupIDs) then
                for _, groupID in ipairs(raw.groupIDs) do
                    if Integer(groupID) and groupID == group.id then
                        if not Number(raw.posY) then coherent = false else rowSet[raw.posY] = true end
                    end
                end
            end
        end
        for y in pairs(rowSet) do rows[#rows + 1] = y end
        table.sort(rows)
        if #rows < 2 or #rows > 10 then coherent = false end
        local step = #rows > 1 and rows[2] - rows[1] or 0
        for i = 3, #rows do if math.abs(rows[i] - rows[i-1] - step) > 1 then coherent = false end end
        local rowIndex = {}
        if coherent and step > 0 then
            for i, y in ipairs(rows) do rowIndex[y] = i - 1 end
        else
            rowIndex = RecognizeClassRows(rows, rowSet) or rowIndex
        end
        for _, node in pairs(catalog.nodes) do
            if node.groupID == group.id then
                local row = rowIndex[node.posY]
                if row then
                    local rowPoints = row * 5
                    if not node.requiredPointsSource then
                        node.requiredPoints = rowPoints
                        node.requiredPointsSource = "position"
                        catalog.hasInferredGates = true
                    end
                    local function ResolveRowGate(subject)
                        if not subject.availability then return end
                        for _, condition in ipairs(subject.availability.required) do
                            if condition.inferRowGate and rowPoints > 0 then
                                condition.requiredPoints, condition.unsupported = rowPoints, nil
                                catalog.hasInferredGates = true
                            end
                        end
                    end
                    ResolveRowGate(node)
                    for _, entry in pairs(node.entries) do ResolveRowGate(entry) end
                elseif not node.requiredPointsSource then
                    Unsupported(node, "Palier de branche inconnu : disposition non reconnue.")
                end
            end
        end
    end
    for sourceID, raw in pairs(rawNodes) do
        local source = catalog.nodes[sourceID]
        if not Table(raw.visibleEdges) then
            if source then Unsupported(source, "Prérequis de ce talent indisponibles.") end
        else
            for _, edge in ipairs(raw.visibleEdges) do
                local target = Table(edge) and Integer(edge.targetNode) and catalog.nodes[edge.targetNode]
                if target and Readable(edge.type) and edge.type ~= 0 then
                    if not source then
                        Unsupported(target, "Prérequis invisible : vérification dans le jeu nécessaire.")
                    elseif edge.type == 2 or edge.type == 3 then
                        local rank = source.maxRanks
                        if Number(raw.flags) and math.floor(raw.flags / 16) % 2 == 1 then rank = 1 end
                        local list = edge.type == 3 and target.required or target.sufficient
                        list[#list + 1] = { nodeID = sourceID, rank = rank, fullRank = rank ~= 1 }
                    elseif edge.type == 4 then
                        source.excludes[#source.excludes + 1] = target.id
                        target.excludes[#target.excludes + 1] = source.id
                    else
                        Unsupported(target, "Type de liaison non simulable.")
                    end
                elseif target and not Readable(edge.type) then
                    Unsupported(target, "Prérequis de ce talent masqué.")
                end
            end
        end
    end
    local staged = Call(C_Traits.ConfigHasStagedChanges, configID)
    -- Unknown staging state must never make the UI claim these ranks are learned.
    catalog.hasStagedChanges = staged == nil or staged == true
    local quantity = currencies[1].quantity
    catalog.availablePoints = Integer(quantity) and quantity >= 0 and quantity <= catalog.maxPoints and quantity or 0
    local level = Call(UnitLevel, "player")
    if Table(currencies) and #currencies == 1 and Integer(level) then
        local currency = currencies[1]
        if Table(currency) and Number(currency.spent) and Number(currency.quantity) then
            local total = currency.spent + currency.quantity
            local first = level - total + 1
            if total > 0 and total < 51 and Integer(first) and first >= 5 and first <= 10 then
                catalog.detectedFirstLevel = first
                catalog.levelSource = "Déduit des points gagnés par ce personnage."
            end
        end
    end
    if not catalog.detectedFirstLevel and Constants and Constants.LegacyConsts then
        local legacy = Constants.LegacyConsts
        local legacyID = Integer(legacy.LEGACY_TREE_ADVENTURE_ID)
            and Call(C_Traits.GetConfigIDByTreeID, legacy.LEGACY_TREE_ADVENTURE_ID)
        local legacyNode = Integer(legacyID) and Integer(legacy.LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID)
            and Call(C_Traits.GetNodeInfo, legacyID, legacy.LEGACY_TREE_ADVENTURE_TALENTED_NODE_ID)
        local legacyStaged = Integer(legacyID) and Call(C_Traits.ConfigHasStagedChanges, legacyID)
        if legacyStaged == false and Table(legacyNode) and Integer(legacyNode.currentRank)
            and legacyNode.currentRank >= 0 and legacyNode.currentRank <= 5 then
            catalog.detectedFirstLevel = 10 - legacyNode.currentRank
            catalog.levelSource = "Héritage (un niveau avancé par rang, à vérifier)."
        end
    end
    return catalog
end

function Data.Read(frame)
    local ok, catalog, reason = pcall(Read, frame)
    if not ok then return nil, "Lecture des talents impossible pour le moment. Rouvrez la fenêtre hors combat." end
    return catalog, reason
end
