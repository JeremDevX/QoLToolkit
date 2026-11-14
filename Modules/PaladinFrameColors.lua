local _, ns = ...
local WoW = ns.WoW
local Colors, curves = {}, nil
ns.PaladinFrameColors = Colors

-- Forever 4cd0ab7: UnitHealthPercent/UnitPowerPercent evaluate color curves natively.
-- https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua
local function CreateCurves()
    local function Curve(points)
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        for _, point in ipairs(points) do
            curve:AddPoint(point[1], CreateColor(point[2], point[3], point[4], 1))
        end
        return curve
    end
    return {
        health = Curve({{0, .90, .10, .07}, {.5, 1, .72, .08}, {1, .12, .68, .24}}),
        power = Curve({{0, .65, .20, .60}, {.5, .32, .40, .85}, {1, .12, .32, .85}}),
    }
end

local function GetCurves()
    if curves then return curves end
    if type(C_CurveUtil) ~= "table" or type(C_CurveUtil.CreateColorCurve) ~= "function"
        or type(CreateColor) ~= "function" or type(Enum) ~= "table"
        or type(Enum.LuaCurveType) ~= "table" or type(Enum.LuaCurveType.Linear) ~= "number" then return end
    local ok, created = pcall(CreateCurves)
    if ok then curves = created end
    return curves
end

local function PowerStyle(unit, configured)
    local _, _, token = WoW.Read(UnitPowerType, unit)
    if token == "MANA" or type(token) ~= "string" then return configured and configured.power, .12, .32, .85 end
    local palette = WoW.IsPublic(PowerBarColor) and type(PowerBarColor) == "table" and PowerBarColor[token]
    if not WoW.IsPublic(palette) or type(palette) ~= "table" then return configured and configured.power, .12, .32, .85 end
    local r, g, b = palette.r, palette.g, palette.b
    if not WoW.IsFiniteNumber(r) or not WoW.IsFiniteNumber(g) or not WoW.IsFiniteNumber(b) then
        return configured and configured.power, .12, .32, .85
    end
    if configured and not configured[token] then
        local ok, curve = pcall(function()
            local result = C_CurveUtil.CreateColorCurve()
            result:SetType(Enum.LuaCurveType.Linear)
            for index, strength in ipairs({.4, .7, 1}) do
                result:AddPoint((index - 1) / 2, CreateColor(r * strength, g * strength, b * strength, 1))
            end
            return result
        end)
        if ok then configured[token] = curve end
    end
    return configured and configured[token], r, g, b
end

function Colors.Apply(healthBar, powerBar, unit)
    if not WoW.IsPublic(unit) then return end
    unit = unit or "player"
    local configured = GetCurves()
    -- Keep evaluated components opaque until their permitted display sink.
    local healthOK = configured and type(UnitHealthPercent) == "function" and pcall(function()
        healthBar:SetStatusBarColor(UnitHealthPercent(unit, true, configured.health):GetRGBA())
    end)
    if not healthOK then healthBar:SetStatusBarColor(.12, .68, .24, 1) end
    local powerCurve, r, g, b = PowerStyle(unit, configured)
    local powerOK = powerCurve and type(UnitPowerPercent) == "function" and pcall(function()
        powerBar:SetStatusBarColor(UnitPowerPercent(unit, nil, false, powerCurve):GetRGBA())
    end)
    if not powerOK then powerBar:SetStatusBarColor(r, g, b, 1) end
end
