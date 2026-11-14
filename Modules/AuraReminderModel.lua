local _, ns = ...
local M = {}
ns.AuraReminderModel = M

M.KindOrder = {aura = 1, buff = 2, tracking = 3}

function M.Match(rule, index, name)
    return index[rule.spellID] or index[(name or rule.name):lower()]
end

-- A matching stance takes precedence over a buff of the same name.
function M.AuraPresent(rule, observed, name)
    local form = M.Match(rule, observed.forms, name)
    if form then return form.active end
    if M.Match(rule, observed.buffs, name) then return true end
    if not observed.buffsKnown or (rule.kind == "aura" and not observed.formsKnown) then return nil end
    return false
end

function M.Missing(settings, observed)
    local missing = {}
    local function Name(rule)
        return observed.resolveName and observed.resolveName(rule) or rule.name
    end
    for _, rule in ipairs(settings.auras) do
        if rule.family then
            local name = observed.missingFamilies and observed.missingFamilies[rule.family]
            if name then
                missing[#missing + 1] = {name = name, kind = "aura", priority = rule.priority}
            end
        else
            local name = Name(rule)
            if M.AuraPresent(rule, observed, name) == false then
                missing[#missing + 1] = {name = name, kind = rule.kind or "buff", priority = rule.priority, icon = rule.icon}
            end
        end
    end
    for _, rule in ipairs(settings.tracking) do
        local name = Name(rule)
        local track = M.Match(rule, observed.tracking, name)
        if track and track.active == false then
            missing[#missing + 1] = {name = track.name or name, kind = "tracking", priority = rule.priority, icon = track.texture or rule.icon}
        end
    end
    return missing
end

function M.OrderAndLimit(effects, settings, expanded)
    table.sort(effects, function(a, b)
        if settings.grouped and a.kind ~= b.kind then
            return (M.KindOrder[a.kind] or 2) < (M.KindOrder[b.kind] or 2)
        end
        if (a.priority or 2) ~= (b.priority or 2) then return (a.priority or 2) < (b.priority or 2) end
        return a.name:lower() < b.name:lower()
    end)
    local limit = settings.visibleLimit
    if settings.compact then limit = settings.expandOnHover and expanded and #effects or math.min(2, limit) end
    return math.min(#effects, limit), math.max(0, #effects - limit)
end
