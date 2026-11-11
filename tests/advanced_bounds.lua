-- Real CVar writer and reset review, with deterministic native values.
local env = setmetatable({}, {__index = _G})
env._G = env
env.InCombatLockdown = function() return false end
env.Settings = {GetSetting = function() end}
local values, defaults, writes = {}, {}, 0
env.C_CVar = {
    GetCVarInfo = function(name)
        return values[name], defaults[name], false, false, false, false, false
    end,
    SetCVar = function(name, value)
        writes = writes + 1
        values[name] = value
        return true
    end,
}
local ns = {L = function(text) return text end}
for _, path in ipairs({"Modules/AdvancedSettingsData.lua", "Modules/AdvancedSettings.lua"}) do
    local chunk = assert(loadfile(path)); setfenv(chunk, env)("QoLToolkit", ns)
end
local api = ns.AdvancedSettings
for _, pair in ipairs({{"nameplateMinScale", "nameplateMaxScale"}, {"nameplateMinAlpha", "nameplateMaxAlpha"}}) do
    local low, high = pair[1], pair[2]
    values[low], values[high] = "0.5", "0.5"
    defaults[low], defaults[high] = "1", "1"
    local before = writes
    assert(not api.Write(low, "1"), "Manual input must respect paired bounds")
    assert(not api.Write(low, nil, true), "Reset must respect paired bounds too")
    assert(writes == before and values[low] == "0.5", "Reject before writing")
    assert(api.ApplyReset(api.ReviewReset({[low] = true, [high] = true})), "Reset both bounds in safe order")
    assert(values[low] == "1" and values[high] == "1")
    values[low], values[high] = "1", "1"
    defaults[low], defaults[high] = "0.5", "0.5"
    assert(not api.Write(high, nil, true), "Do not lower max below current min")
    assert(api.ApplyReset(api.ReviewReset({[low] = true, [high] = true})))
    assert(values[low] == "0.5" and values[high] == "0.5")
    defaults[low], defaults[high] = "1", "0.25"
    before = writes
    assert(not api.ApplyReset(api.ReviewReset({[low] = true, [high] = true})), "Reject incompatible defaults together")
    assert(writes == before, "Validate final bounds before any reset")
end
print("PASS: single and grouped default resets preserve paired bounds")
