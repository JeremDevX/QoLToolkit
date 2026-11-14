local function Setup()
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local state = {health = 1, power = 1, unit = "player", curves = {}, calls = {health = 0, power = 0}}
    env.Enum = {LuaCurveType = {Linear = 0}}
    env.CreateColor = function(r, g, b, a)
        return {r = r, g = g, b = b, a = a, GetRGBA = function(self)
            return self.r, self.g, self.b, self.a
        end}
    end
    env.C_CurveUtil = {CreateColorCurve = function()
        if state.refuseCreate then error("Refused color curve") end
        local curve = {points = {}}
        function curve:SetType(kind) self.kind = kind end
        function curve:AddPoint(x, color) self.points[#self.points + 1] = {x, color} end
        state.curves[#state.curves + 1] = curve
        return curve
    end}
    local function Evaluate(key, curve)
        state.calls[key] = state.calls[key] + 1
        if state.refused == key then error("Refused native percentage") end
        if state.opaqueColor then return state.opaqueColor end
        local fraction = state[key]
        for index = 2, #curve.points do
            local left, right = curve.points[index - 1], curve.points[index]
            if fraction <= right[1] then
                local weight = (fraction - left[1]) / (right[1] - left[1])
                return env.CreateColor(left[2].r + (right[2].r - left[2].r) * weight,
                    left[2].g + (right[2].g - left[2].g) * weight,
                    left[2].b + (right[2].b - left[2].b) * weight, 1)
            end
        end
        error("Synthetic fraction outside curve")
    end
    env.UnitHealthPercent = function(unit, usePredicted, curve)
        assert(unit == state.unit and usePredicted == true and curve == state.curves[1])
        return Evaluate("health", curve)
    end
    env.UnitPowerPercent = function(unit, powerType, unmodified, curve)
        assert(unit == state.unit and powerType == nil and unmodified == false
            and (curve == state.curves[2] or curve == state.curves[3]))
        return Evaluate("power", curve)
    end
    local function Bar()
        return {SetStatusBarColor = function(self, ...) self.color = {...} end,
            GetValue = function() error("Never read native reserve values") end,
            GetMinMaxValues = function() error("Never calculate native reserve percentages") end}
    end
    local ns = {}
    setfenv(assert(loadfile("Core/WoWRuntime.lua")), env)("QoLToolkit", ns)
    setfenv(assert(loadfile("Modules/PaladinFrameColors.lua")), env)("QoLToolkit", ns)
    return ns.PaladinFrameColors, env, state, Bar(), Bar()
end

local function AssertColor(bar, r, g, b)
    assert(math.abs(bar.color[1] - r) < 1e-10 and math.abs(bar.color[2] - g) < 1e-10
        and math.abs(bar.color[3] - b) < 1e-10 and bar.color[4] == 1, "Unexpected paladin bar color")
end

local colors, env, state, health, power = Setup()
assert(#state.curves == 0, "Color curves are created lazily")
colors.Apply(health, power)
assert(#state.curves == 2 and state.curves[1].kind == env.Enum.LuaCurveType.Linear
    and state.curves[2].kind == env.Enum.LuaCurveType.Linear, "Both native curves interpolate linearly")
local expected = {
    {{0, .90, .10, .07}, {.5, 1, .72, .08}, {1, .12, .68, .24}},
    {{0, .65, .20, .60}, {.5, .32, .40, .85}, {1, .12, .32, .85}},
}
for index, curve in ipairs(state.curves) do
    assert(#curve.points == 3)
    for pointIndex, point in ipairs(curve.points) do
        local wanted = expected[index][pointIndex]
        assert(point[1] == wanted[1] and point[2].r == wanted[2] and point[2].g == wanted[3]
            and point[2].b == wanted[4] and point[2].a == 1, "Configure exact reserve color stops")
    end
end
for index, fraction in ipairs({0, .5, 1}) do
    state.health, state.power = fraction, fraction
    colors.Apply(health, power)
    local h, p = expected[1][index], expected[2][index]
    AssertColor(health, h[2], h[3], h[4]); AssertColor(power, p[2], p[3], p[4])
end
state.health, state.power = .25, .75
colors.Apply(health, power)
AssertColor(health, .95, .41, .075); AssertColor(power, .22, .36, .85)
assert(#state.curves == 2 and state.calls.health == 5 and state.calls.power == 5,
    "Repeated updates reuse both curves while querying current reserves")

local opaque = setmetatable({}, {__index = function() error("Do not inspect secret components") end,
    __tostring = function() error("Do not log secret components") end,
    __lt = function() error("Do not compare secret components") end,
    __add = function() error("Do not calculate secret components") end,
    __sub = function() error("Do not calculate secret components") end,
    __mul = function() error("Do not calculate secret components") end,
    __div = function() error("Do not calculate secret components") end})
state.opaqueColor = {GetRGBA = function() return opaque, opaque, opaque, opaque end}
colors.Apply(health, power)
for _, bar in ipairs({health, power}) do
    for index = 1, 4 do assert(rawequal(bar.color[index], opaque), "Opaque components reach the UI sink unchanged") end
end
state.opaqueColor = nil

for _, absent in ipairs({"C_CurveUtil", "CreateColor", "Enum"}) do
    local fallback, missingEnv, missingState, h, p = Setup()
    missingEnv[absent] = false
    fallback.Apply(h, p)
    AssertColor(h, .12, .68, .24); AssertColor(p, .12, .32, .85)
    assert(#missingState.curves == 0, "Missing curve dependencies use fixed colors")
end
for _, key in ipairs({"health", "power"}) do
    local native, fallbackEnv, fallbackState, h, p = Setup()
    fallbackState.health, fallbackState.power = 0, 0
    local api = key == "health" and "UnitHealthPercent" or "UnitPowerPercent"
    local saved = fallbackEnv[api]
    fallbackEnv[api] = false
    native.Apply(h, p)
    if key == "health" then
        AssertColor(h, .12, .68, .24); AssertColor(p, .65, .20, .60)
    else
        AssertColor(h, .90, .10, .07); AssertColor(p, .12, .32, .85)
    end
    fallbackEnv[api], fallbackState.refused = saved, key
    native.Apply(h, p)
    if key == "health" then AssertColor(h, .12, .68, .24) else AssertColor(p, .12, .32, .85) end
    fallbackState.refused = nil
    native.Apply(h, p)
    AssertColor(h, .90, .10, .07); AssertColor(p, .65, .20, .60)
    assert(#fallbackState.curves == 2, "A refused or missing percentage API recovers without recreating curves")
end
local retry, _, retryState, h, p = Setup()
retryState.refuseCreate = true
retry.Apply(h, p)
AssertColor(h, .12, .68, .24); AssertColor(p, .12, .32, .85)
retryState.refuseCreate = false
retryState.health, retryState.power = 0, 0
retry.Apply(h, p)
AssertColor(h, .90, .10, .07); AssertColor(p, .65, .20, .60)
assert(#retryState.curves == 2, "A rejected curve creation can recover on the next native update")

local adaptive, adaptiveEnv, adaptiveState, targetHealth, targetPower = Setup()
adaptiveState.unit = "target"
adaptiveEnv.UnitPowerType = function(unit) assert(unit == "target"); return 1, "RAGE" end
adaptiveEnv.PowerBarColor = {RAGE = {r = 1, g = .1, b = .1}}
adaptive.Apply(targetHealth, targetPower, "target")
AssertColor(targetPower, 1, .1, .1)
assert(#adaptiveState.curves == 3, "A non-mana reserve creates its own cached native curve")
adaptiveState.power = 0
adaptive.Apply(targetHealth, targetPower, "target")
AssertColor(targetPower, .4, .04, .04)
adaptiveEnv.UnitPowerPercent = false
adaptive.Apply(targetHealth, targetPower, "target")
AssertColor(targetPower, 1, .1, .1)
assert(#adaptiveState.curves == 3, "Resource color survives missing percentage data without recreating curves")
adaptiveEnv.issecretvalue = function(value) return rawequal(value, opaque) end
adaptiveEnv.UnitPowerType = function() return 1, opaque end
adaptive.Apply(targetHealth, targetPower, "target")
AssertColor(targetPower, .12, .32, .85)
adaptiveEnv.UnitPowerType = function() return 1, "RAGE" end
adaptiveEnv.PowerBarColor.RAGE.r = opaque
adaptive.Apply(targetHealth, targetPower, "target")
AssertColor(targetPower, .12, .32, .85)
print("PASS: native paladin reserve curves, cached interpolation, opaque colors, independent fallbacks, and recovery")
