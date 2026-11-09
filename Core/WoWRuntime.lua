local _, ns = ...
local WoW = {}
ns.WoW = WoW

function WoW.IsPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

function WoW.IsFiniteNumber(value)
    return WoW.IsPublic(value) and type(value) == "number" and value > -math.huge and value < math.huge
end

local function CheckedResults(ok, ...)
    if not ok then return "error" end
    for index = 1, select("#", ...) do
        if not WoW.IsPublic((select(index, ...))) then return "secret" end
    end
    return "ok", ...
end

-- Preserve nil positions and all results. Callers validate the expected types and fields.
function WoW.Read(api, ...)
    if not WoW.IsPublic(api) then return "secret" end
    if type(api) ~= "function" then return "absent" end
    return CheckedResults(pcall(api, ...))
end

function WoW.ReadValue(api, ...)
    local _, value = WoW.Read(api, ...)
    return value
end
