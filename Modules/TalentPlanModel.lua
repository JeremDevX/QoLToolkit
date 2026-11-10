local _, ns = ...
local M = {}
ns.TalentPlanModel = M

local function Integer(value, minimum, maximum)
    return type(value) == "number" and value == value and value < math.huge and value >= minimum and value <= maximum and value == math.floor(value)
end

local function Fail(state, index, reason)
    state.error, state.errorIndex = reason, index
    return state
end

local function Meets(requirement, state, catalog)
    if type(requirement) ~= "table" then return false end
    local rank = requirement.rank
    if requirement.fullRank then
        local source = catalog.nodes[requirement.nodeID]
        local entry = source and source.entries[state.choices[requirement.nodeID]]
        if not entry then return false end
        rank = math.min(source.maxRanks, entry.maxRanks or source.maxRanks)
    end
    return Integer(rank, 1, 51) and (state.counts[requirement.nodeID] or 0) >= rank
end

local function Available(node, entry, level, points)
    local reason, allMet = nil, true
    local function Met(condition)
        if condition.unsupported then reason = reason or condition.unsupported; return false end
        return level >= (condition.minLevel or 0) and points >= (condition.requiredPoints or 0)
    end
    -- Available conditions share one scope across the node and selected entry.
    -- Any satisfied sufficient condition wins; otherwise every condition must pass.
    for _, subject in ipairs({node, entry}) do
        local group = subject.availability
        if group then
            for _, condition in ipairs(group.required or {}) do
                if not Met(condition) then allMet = false end
            end
            for _, condition in ipairs(group.sufficient or {}) do
                if Met(condition) then return true end
                allMet = false
            end
        end
    end
    if allMet then return true end
    return false, reason or "Conditions de disponibilité non remplies."
end

-- Replay from zero: every prefix must be legal when its point is allocated.
function M.Replay(catalog, order, firstLevel, limit)
    local state = {counts = {}, choices = {}, levels = {}, groupPoints = {}, validCount = 0, points = 0}
    if type(catalog) ~= "table" or type(catalog.nodes) ~= "table" then
        return Fail(state, 1, "Arbre de talents indisponible.")
    end
    if not Integer(firstLevel, 5, 10) then return Fail(state, 1, "Premier niveau invalide (5 à 10).") end
    if type(order) ~= "table" then return Fail(state, 1, "Ordre de talents invalide.") end
    local length = #order
    for key in pairs(order) do
        if not Integer(key, 1, length) then return Fail(state, 1, "Ordre de talents incomplet ou invalide.") end
    end
    if limit ~= nil and not Integer(limit, 0, math.huge - 1) then
        return Fail(state, 1, "Niveau d’aperçu invalide.")
    end
    local count = limit and math.min(limit, length) or length
    local maximum = Integer(catalog.maxPoints, 0, 51) and catalog.maxPoints or 51
    for index = 1, count do
        if state.points >= maximum then return Fail(state, index, "Limite de points atteinte.") end
        local point = order[index]
        if type(point) ~= "table" or not Integer(point.nodeID, 1, math.huge - 1)
            or not Integer(point.entryID, 1, math.huge - 1) then
            return Fail(state, index, "Point de talent invalide.")
        end
        local node = catalog.nodes[point.nodeID]
        if type(node) ~= "table" or type(node.entries) ~= "table" or type(node.entries[point.entryID]) ~= "table" then
            return Fail(state, index, "Talent absent de cet arbre.")
        end
        local entry = node.entries[point.entryID]
        if node.unsupported then return Fail(state, index, tostring(node.unsupported)) end
        if entry.unsupported then return Fail(state, index, tostring(entry.unsupported)) end
        if node.groupID == nil or not Integer(node.maxRanks, 1, 51)
            or (entry.maxRanks ~= nil and not Integer(entry.maxRanks, 1, 51)) then
            return Fail(state, index, "Données du talent incomplètes.")
        end
        local rank = state.counts[point.nodeID] or 0
        local maxRanks = math.min(node.maxRanks, entry.maxRanks or node.maxRanks)
        if rank >= maxRanks then return Fail(state, index, "Rang maximal déjà atteint.") end
        if rank > 0 and state.choices[point.nodeID] ~= point.entryID then
            return Fail(state, index, "Ce talent possède déjà un autre choix.")
        end
        local level = firstLevel + index - 1
        if level < math.max(node.minLevel or 0, entry.minLevel or 0) then return Fail(state, index, "Niveau requis non atteint.") end
        if (state.groupPoints[node.groupID] or 0) < math.max(node.requiredPoints or 0, entry.requiredPoints or 0) then
            return Fail(state, index, "Pas assez de points dans cet arbre.")
        end
        local available, reason = Available(node, entry, level, state.groupPoints[node.groupID] or 0)
        if not available then return Fail(state, index, reason) end
        for _, requirement in ipairs(node.required or {}) do
            if not Meets(requirement, state, catalog) then return Fail(state, index, "Talent préalable incomplet.") end
        end
        -- A fulfilled required parent already satisfies the "at least one parent"
        -- rule. Alternative parents matter only when there is no required parent.
        if #(node.required or {}) == 0 and node.sufficient and #node.sufficient > 0 then
            local met = false
            for _, requirement in ipairs(node.sufficient) do
                if Meets(requirement, state, catalog) then met = true; break end
            end
            if not met then return Fail(state, index, "Un talent préalable est nécessaire.") end
        end
        for _, excluded in ipairs(node.excludes or {}) do
            if (state.counts[excluded] or 0) > 0 then return Fail(state, index, "Talents incompatibles.") end
        end
        -- Check both directions: a catalog edge may only be stored on its source.
        for selectedID in pairs(state.counts) do
            for _, excluded in ipairs(catalog.nodes[selectedID].excludes or {}) do
                if excluded == point.nodeID then return Fail(state, index, "Talents incompatibles.") end
            end
        end
        state.counts[point.nodeID], state.choices[point.nodeID] = rank + 1, point.entryID
        state.levels[point.nodeID] = state.levels[point.nodeID] or {}
        table.insert(state.levels[point.nodeID], level)
        state.groupPoints[node.groupID] = (state.groupPoints[node.groupID] or 0) + 1
        state.validCount, state.points = index, index
    end
    return state
end

function M.Append(catalog, order, nodeID, entryID, firstLevel)
    local state = M.Replay(catalog, order, firstLevel)
    if state.error then return false, state.error end
    local candidate = {}
    for index, point in ipairs(order) do candidate[index] = point end
    candidate[#candidate + 1] = {nodeID = nodeID, entryID = entryID}
    state = M.Replay(catalog, candidate, firstLevel)
    if state.error then return false, state.error end
    order[#order + 1] = candidate[#candidate]
    return true
end

function M.RemoveLast(catalog, order, nodeID, firstLevel)
    if type(order) ~= "table" then return false, "Ordre de talents invalide." end
    for key in pairs(order) do
        if not Integer(key, 1, #order) then return false, "Ordre de talents incomplet ou invalide." end
    end
    for index = 1, #order do
        if order[index] == nil then return false, "Ordre de talents incomplet ou invalide." end
    end
    local found
    for index = #order, 1, -1 do
        if type(order[index]) == "table" and order[index].nodeID == nodeID then found = index; break end
    end
    if not found then return false, "Aucun point prévu dans ce talent." end
    local candidate = {}
    for index = 1, #order do
        if index ~= found then candidate[#candidate + 1] = order[index] end
    end
    local state = M.Replay(catalog, candidate, firstLevel)
    if state.error then return false, "Retrait impossible : " .. state.error, state.error end
    table.remove(order, found)
    return true
end

function M.Undo(order)
    if type(order) == "table" and #order > 0 then return table.remove(order) end
end

function M.DeletePlan(bucket, plan)
    if type(bucket) ~= "table" or type(bucket.plans) ~= "table" then return false end
    for index, saved in ipairs(bucket.plans) do
        if saved == plan then
            table.remove(bucket.plans, index)
            local active = type(bucket.active) == "number" and bucket.active or 1
            if active > index then active = active - 1 end
            bucket.active = math.max(1, math.min(active, #bucket.plans))
            return true
        end
    end
    return false
end

function M.LevelLabel(levels)
    if type(levels) ~= "table" or #levels == 0 then return "" end
    local labels, first, last = {}, levels[1], levels[1]
    local function Finish()
        labels[#labels + 1] = first == last and tostring(first) or tostring(first) .. "–" .. tostring(last)
    end
    for index = 2, #levels do
        if levels[index] == last + 1 then last = levels[index]
        else Finish(); first, last = levels[index], levels[index] end
    end
    Finish()
    return table.concat(labels, ", ")
end

function M.NextMissing(order, actualCounts, actualChoices)
    local counts = {}
    actualCounts, actualChoices = actualCounts or {}, actualChoices or {}
    for index, point in ipairs(order or {}) do
        if type(point) ~= "table" or not Integer(point.nodeID, 1, math.huge)
            or not Integer(point.entryID, 1, math.huge) then return index end
        counts[point.nodeID] = (counts[point.nodeID] or 0) + 1
        local actual = actualCounts[point.nodeID]
        if not Integer(actual, 0, 51) or actual < counts[point.nodeID]
            or (actualChoices[point.nodeID] ~= nil and actualChoices[point.nodeID] ~= point.entryID) then
            return index
        end
    end
end
