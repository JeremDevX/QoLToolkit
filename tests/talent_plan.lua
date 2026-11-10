local ns = {}
for _, path in ipairs({"Modules/TalentPlanModel.lua", "Modules/TalentPlanData.lua"}) do
    setfenv(assert(loadfile(path)), _G)("QoLToolkit", ns)
end

-- Hunter Marksmanship grid from Forever 1.60.1.70862, with one node per row.
local lethalAttacks, nextTier, offGrid = 105011, 105008, 105003
local nodeIDs = {lethalAttacks, nextTier, 105007, 105004, 105001, 104998, 104997, offGrid}
local positions = {[offGrid] = 39300}
for index = 1, 7 do positions[nodeIDs[index]] = 2130 + (index - 1) * 600 end

local showOffGrid = false
local frame = {GetConfigID = function() return 1 end, GetTalentTreeID = function() return 1091 end}
C_ClassTalents = {GetActiveConfigID = frame.GetConfigID}
UnitClass = function() return "Hunter", "HUNTER" end
C_Traits = {
    GetConfigInfo = function() return {treeIDs = {1091}} end,
    GetGroupDisplayInfoByTreeID = function() return {{groupID = 11371, displayName = "Marksmanship"}} end,
    GetTreeNodes = function() return nodeIDs end,
    GetTreeCurrencyInfo = function() return {{traitCurrencyID = 3820, quantity = 5, spent = 0}} end,
    GetNodeInfo = function(_, nodeID)
        return {posY = positions[nodeID], groupIDs = {11371},
            isVisible = nodeID ~= 105007 and (nodeID ~= offGrid or showOffGrid),
            entryIDs = {nodeID}, maxRanks = 5, ranksPurchased = 0,
            visibleEdges = {}, conditionIDs = {}, type = 0, flags = 0}
    end,
    GetEntryInfo = function(_, entryID) return {definitionID = entryID, maxRanks = 5, conditionIDs = {}} end,
    GetDefinitionInfo = function(entryID)
        return {overrideName = entryID == lethalAttacks and "Lethal Attacks" or "Other talent"}
    end,
    GetNodeCost = function() return {{ID = 3820, amount = 1}} end,
    ConfigHasStagedChanges = function() return false end,
}

local catalog = assert(ns.TalentPlanData.Read(frame))
local plan, append = {}, ns.TalentPlanModel.Append
assert(not append(catalog, plan, nextTier, nextTier, 10), "Second row requires five points")
for _ = 1, 5 do
    assert(append(catalog, plan, lethalAttacks, lethalAttacks, 10))
end
assert(append(catalog, plan, nextTier, nextTier, 10))
assert(catalog.nodes[105004].requiredPoints == 15, "A hidden row still counts toward later tiers")

showOffGrid = true
local offsetNode = 12345
nodeIDs[#nodeIDs + 1], positions[offsetNode] = offsetNode, 2720
catalog = assert(ns.TalentPlanData.Read(frame))
assert(catalog.nodes[offsetNode].requiredPoints == 5 and not catalog.nodes[offsetNode].unsupported,
    "A small position offset still belongs to the nearest row")
assert(catalog.nodes[offGrid].unsupported, "A visible off-grid node has no inferred tier")
assert(not ns.TalentPlanModel.Replay(catalog, plan, 10).error, "A visible off-grid node does not invalidate a saved plan")
print("PASS: Hunter talent ranks, branch tiers, and off-grid nodes")
