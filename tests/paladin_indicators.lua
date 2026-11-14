-- Isolated native-layout mirror checks; never launch or inspect the game client.
local env = setmetatable({}, {__index = _G})
env._G = env
local secret = setmetatable({}, {__add = function() error("Secret arithmetic") end,
    __sub = function() error("Secret arithmetic") end, __mul = function() error("Secret arithmetic") end,
    __div = function() error("Secret arithmetic") end, __lt = function() error("Secret comparison") end})
env.issecretvalue = function(value) return value == secret end
local combat = false
env.InCombatLockdown = function() return combat end
local widgets, hooks, nativeWrites = {}, {}, 0
local methods = {}
local function Widget(native)
    local widget = setmetatable({native = native, shown = false, scale = 1,
        rect = {100, 20, 100, 20}, tint = {.2, .8, .6, .7}}, {__index = methods})
    widgets[#widgets + 1] = widget
    return widget
end
local function Mutation(self) if self.native then nativeWrites = nativeWrites + 1 end end
function methods:IsForbidden() return self.forbidden or false end
function methods:GetRect()
    if self.refused then error("Refused geometry") end
    return unpack(self.rect)
end
function methods:GetEffectiveScale() return self.scale end
function methods:GetWidth() return self.rect[3] end
function methods:GetHeight() return self.rect[4] end
function methods:GetVertexColor()
    if self.refusedColor then error("Refused tint") end
    return unpack(self.tint)
end
function methods:IsShown() return self.shown end
function methods:CreateTexture(_, layer, _, sublevel)
    local child = Widget(false)
    child.parent, child.layer, child.sublevel = self, layer, sublevel
    return child
end
function methods:Hide() Mutation(self); self.shown = false end
function methods:Show() Mutation(self); self.shown = true end
function methods:SetShown(value) Mutation(self); self.shown = value end
function methods:SetPoint(...)
    local relative = select(2, ...)
    assert(not relative.noNewAnchors, "Do not re-anchor after the health fill acquires secret layout")
    Mutation(self); self.point = {...}
    self.points = self.points or {}; self.points[#self.points + 1] = self.point
end
function methods:ClearAllPoints() Mutation(self); self.point, self.points = nil, {} end
function methods:SetSize(width, height) Mutation(self); self.rect[3], self.rect[4] = width, height end
function methods:SetWidth(width) Mutation(self); self.rect[3] = width end
function methods:GetFrameLevel() return self.level or 0 end
function methods:SetFrameLevel(level) Mutation(self); self.level = level end
function methods:EnableMouse(enabled) Mutation(self); self.mouse = enabled end
function methods:SetAllPoints(relative) Mutation(self); self.allPoints = relative end
function methods:SetClipsChildren(enabled) Mutation(self); self.clipsChildren = enabled end
function methods:GetStatusBarTexture()
    assert(not self.forbidFillLookup, "Prepare must reuse the original anchors after secret values arrive")
    if self.missingFill then return nil end
    self.barFill = self.barFill or Widget(false)
    return self.barFill
end
function methods:IsAnchoringSecret() return self.secretLayout or false end
function methods:SetStatusBarTexture(texture) Mutation(self); self.barTexture = texture; return not self.refusedTexture end
function methods:SetStatusBarColor(...) Mutation(self); self.barColor = {...} end
function methods:SetMinMaxValues(minimum, maximum)
    Mutation(self); self.minimum, self.maximum = minimum, maximum
end
function methods:SetValue(value, ...)
    assert(select("#", ...) == 0, "Only the first incoming-heal result reaches the status bar")
    if self.refusedValue then error("Refused forecast value") end
    Mutation(self); self.value = value
end
function methods:SetVertexColor(...) Mutation(self); self.tint = {...} end
function methods:SetTexture(texture) Mutation(self); self.texture = texture; return true end
function methods:SetAtlas(atlas) Mutation(self); self.atlas = atlas end
env.C_Texture = {GetAtlasInfo = function() return {width = 16, height = 16} end}
env.PlayerFrame_UpdateStatus = function() end
env.UnitFrameHealPredictionBars_Update = function() end
env.hooksecurefunc = function(name, callback)
    assert(type(name) == "string" and type(env[name]) == "function")
    hooks[name] = (hooks[name] or 0) + 1
    local original = env[name]
    env[name] = function(...) original(...); callback(...) end
end
local ns = {}
local function Load(path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("QoLToolkit", ns)
end
Load("Core/WoWRuntime.lua")
Load("Modules/PaladinFrameIndicators.lua")
local Indicators = ns.PaladinFrameIndicators
local root, health = Widget(false), Widget(false)
health.rect = {0, 0, 200, 22}
combat = true
assert(not Indicators.Create(root, health), "Indicator widgets are only created outside combat")
combat = false
local state = assert(Indicators.Create(root, health))
assert(state.combat.atlas == "UI-HUD-UnitFrame-Player-CombatIcon" and state.combat.rect[3] == 26)
assert(state.combat.point[1] == "CENTER" and state.combat.point[4] == 16 and state.combat.point[5] == -68)
local owner, nativeHealth = Widget(true), Widget(true)
local content, contextual, attack = Widget(true), Widget(true), Widget(true)
owner.PlayerFrameContent, content.PlayerFrameContentContextual, contextual.AttackIcon = content, contextual, attack
local keys = {"MyHealPredictionBar", "OtherHealPredictionBar", "TotalAbsorbBar", "HealAbsorbBar"}
for index, key in ipairs(keys) do
    local segment = Widget(true)
    segment.Fill, segment.FillMask = Widget(true), Widget(true)
    segment.FillMask.rect = {120 + (index - 1) * 10, 20, 10, 20}
    nativeHealth[key] = segment
    local destination = state.predictions[key]
    assert(destination.parent == health and destination.layer == "ARTWORK" and destination.sublevel == index,
        "Predictions stay below OVERLAY text on the custom status bar")
end
nativeHealth.MyHealPredictionBar.shown, nativeHealth.OtherHealPredictionBar.shown = true, true
attack.shown = true
assert(Indicators.Start(state, owner, nativeHealth) and state.combat.shown)
local own, others = state.predictions.MyHealPredictionBar, state.predictions.OtherHealPredictionBar
assert(own.shown and own.point[4] == 40 and own.rect[3] == 20 and own.rect[4] == 22)
assert(others.shown and others.point[4] == 60 and others.rect[3] == 20)
assert(own.tint[1] == .2 and own.tint[4] == .7, "Native prediction tint is retained")
nativeHealth.MyHealPredictionBar.shown = false
env.UnitFrameHealPredictionBars_Update(owner)
assert(not own.shown and others.shown, "Cancelling one heal removes its old segment")
nativeHealth.OtherHealPredictionBar.FillMask.rect = {190, 20, 40, 20}
env.UnitFrameHealPredictionBars_Update(owner)
assert(others.point[4] == 180 and others.rect[3] == 20, "Right overflow is clipped to the custom health bar")
nativeHealth.OtherHealPredictionBar.FillMask.rect = {90, 20, 20, 20}
Indicators.Update(state)
assert(others.point[4] == 0 and others.rect[3] == 20, "Left overflow is clipped")
nativeHealth.TotalAbsorbBar.shown, nativeHealth.HealAbsorbBar.shown = true, true
Indicators.Update(state)
assert(state.predictions.TotalAbsorbBar.shown and state.predictions.HealAbsorbBar.shown)
local mask = nativeHealth.OtherHealPredictionBar.FillMask
mask.scale, mask.rect = 2, {60, 10, 5, 10}
Indicators.Update(state)
assert(others.point[4] == 40 and others.rect[3] == 20, "Rectangles are normalized across effective scales")
mask.scale, mask.rect = 1, {120, 20, 10, 20}
for _, bad in ipairs({secret, math.huge, 0 / 0}) do
    mask.rect[1] = bad
    Indicators.Update(state)
    assert(not others.shown, "Unavailable geometry never leaves the previous prediction visible")
end
mask.rect = {120, 20, 10, 20}
mask.scale = secret
Indicators.Update(state); assert(not others.shown)
mask.scale, mask.refused = 1, true
Indicators.Update(state); assert(not others.shown)
mask.refused = false
mask.forbidden = true
Indicators.Update(state); assert(not others.shown)
mask.forbidden = false
mask.GetRect = false
Indicators.Update(state); assert(not others.shown)
mask.GetRect = nil
nativeHealth.OtherHealPredictionBar.FillMask = nil
Indicators.Update(state); assert(not others.shown)
nativeHealth.OtherHealPredictionBar.FillMask = mask
nativeHealth.OtherHealPredictionBar.shown = secret
Indicators.Update(state); assert(not others.shown)
nativeHealth.OtherHealPredictionBar.shown = true
nativeHealth.OtherHealPredictionBar.Fill.tint = {secret, .3, .4, 1}
Indicators.Update(state)
assert(others.shown and others.tint[1] == secret, "Secret tint goes directly to the allowed display sink")
nativeHealth.OtherHealPredictionBar.Fill.refusedColor = true
Indicators.Update(state); assert(not others.shown)
nativeHealth.OtherHealPredictionBar.Fill = nil
Indicators.Update(state); assert(not others.shown)
nativeHealth.OtherHealPredictionBar.Fill = Widget(true)
attack.shown = false
env.PlayerFrame_UpdateStatus()
assert(not state.combat.shown, "Combat icon follows the native status update")
attack.shown = true
env.PlayerFrame_UpdateStatus(); assert(state.combat.shown)
owner.forbidden = true
Indicators.Update(state)
assert(not state.combat.shown and not others.shown, "A newly forbidden native owner clears all old indicators")
owner.forbidden = false
Indicators.Update(state)
assert(state.combat.shown and others.shown, "Public owner access restores the existing indicator resources")
combat = true
nativeHealth.OtherHealPredictionBar.FillMask.rect = {150, 20, 10, 20}
env.UnitFrameHealPredictionBars_Update(owner)
assert(others.point[4] == 100, "Private prediction textures keep updating in combat")
combat = false
nativeHealth.OtherHealPredictionBar.FillMask.rect = {120, 20, 10, 20}
env.UnitFrameHealPredictionBars_Update(Widget(true))
assert(others.point[4] == 100, "Other unit-frame updates do not touch this mirror")
Indicators.Stop(state)
assert(not state.combat.shown and not others.shown and not state.owner and not state.nativeHealth)
env.PlayerFrame_UpdateStatus(); env.UnitFrameHealPredictionBars_Update(owner)
assert(not state.combat.shown and not others.shown, "Permanent hooks are inert after stop")
local count = #widgets
assert(Indicators.Start(state, owner, nativeHealth))
assert(#widgets == count and hooks.PlayerFrame_UpdateStatus == 1 and hooks.UnitFrameHealPredictionBars_Update == 1,
    "Restart reuses indicator widgets and does not stack hooks")
Indicators.Stop(state)
env.C_Texture.GetAtlasInfo = function() return nil end
local noAtlas = assert(Indicators.Create(root, health))
assert(Indicators.Start(noAtlas, owner, nativeHealth) and not noAtlas.combat.shown,
    "A missing native atlas leaves the combat art unavailable")
Indicators.Stop(noAtlas)
local unavailableEnv = setmetatable({hooksecurefunc = false}, {__index = env})
local unavailableNS = {}
local unavailableChunk = assert(loadfile("Core/WoWRuntime.lua"))
setfenv(unavailableChunk, unavailableEnv); unavailableChunk("QoLToolkit", unavailableNS)
unavailableChunk = assert(loadfile("Modules/PaladinFrameIndicators.lua"))
setfenv(unavailableChunk, unavailableEnv); unavailableChunk("QoLToolkit", unavailableNS)
local unlinked = unavailableNS.PaladinFrameIndicators
local unlinkedState = assert(unlinked.Create(root, health))
assert(unlinked.Start(unlinkedState, owner, nativeHealth))
assert(not unlinkedState.combat.shown and not unlinkedState.predictions.TotalAbsorbBar.shown,
    "Missing secure hooks cannot leave a prediction that will never receive updates")
unlinked.Stop(unlinkedState)

-- Regression: native mask geometry can be secret even though the frame references are public.
for _, key in ipairs(keys) do nativeHealth[key].shown = false end
nativeHealth.MyHealPredictionBar.shown, nativeHealth.OtherHealPredictionBar.shown = true, true
nativeHealth.MyHealPredictionBar.FillMask.rect = {secret, 20, 10, 20}
nativeHealth.OtherHealPredictionBar.FillMask.rect = {secret, 20, 10, 20}
local forecastHealth = Widget(false)
forecastHealth.rect, forecastHealth.level = {0, 0, 200, 22}, 6
local forecastState = assert(Indicators.Create(root, forecastHealth))
assert(Indicators.Start(forecastState, owner, nativeHealth))
assert(not forecastState.predictions.MyHealPredictionBar.shown and not forecastState.predictions.OtherHealPredictionBar.shown,
    "The old public-rectangle mirror cannot display native heals when their mask anchors are secret")
Indicators.Stop(forecastState)
local amounts = {maximum = 100, incoming = 30, factories = 0, updates = 0}
env.CreateFrame = function(kind, _, parent)
    assert(not combat, "Forecast frames are created outside combat")
    local frame = Widget(false); frame.kind, frame.parent = kind, parent
    return frame
end
env.Enum = {UnitMaximumHealthMode = {Default = 0}, UnitHealAbsorbMode = {ReducedByIncomingHeals = 0},
    UnitIncomingHealClampMode = {MissingHealth = 0}}
env.CreateUnitHealPredictionCalculator = function()
    if amounts.refusedCreate then error("Refused calculator creation") end
    amounts.factories = amounts.factories + 1
    local calculator = {}
    function calculator:SetMaximumHealthMode(value) self.maximumMode = value end
    function calculator:SetHealAbsorbMode(value) self.absorbMode = value end
    function calculator:SetIncomingHealClampMode(value) self.clampMode = value end
    function calculator:SetIncomingHealOverflowPercent(value) self.overflow = value end
    function calculator:GetMaximumHealth()
        local values = amounts.byUnit and amounts.byUnit[self.unit] or amounts
        return values.maximum
    end
    function calculator:GetIncomingHeals()
        local values = amounts.byUnit and amounts.byUnit[self.unit] or amounts
        return values.incoming, secret, secret, false
    end
    return calculator
end
env.UnitGetDetailedHealPrediction = function(unit, healer, calculator)
    assert((unit == "player" or unit == "target") and healer == "player" and calculator)
    if amounts.refusedUpdate then error("Refused detailed heal prediction") end
    calculator.unit = unit
    amounts.updates = amounts.updates + 1
    if amounts.unitUpdates then amounts.unitUpdates[unit] = (amounts.unitUpdates[unit] or 0) + 1 end
end
combat = true
local beforePrepare = #widgets
assert(not Indicators.Prepare(forecastState) and #widgets == beforePrepare,
    "Forecast setup does not allocate or anchor during combat")
combat = false
assert(Indicators.Prepare(forecastState))
local forecast, clipper = forecastState.forecast, forecastState.clipper
assert(amounts.factories == 1 and forecastState.calculator.maximumMode == 0
    and forecastState.calculator.absorbMode == 0 and forecastState.calculator.clampMode == 0
    and forecastState.calculator.overflow == 1, "Clamping and heal-absorb processing are configured explicitly")
assert(clipper.parent == forecastHealth and clipper.allPoints == forecastHealth and clipper.clipsChildren
    and not clipper.mouse and not forecast.mouse and clipper.level == 7 and forecast.level == 7,
    "A passive clipping frame keeps the native forecast above the health fill and inside its public rectangle")
assert(forecast.parent == clipper and forecast.rect[3] == 200 and #forecast.points == 2
    and forecast.points[1][1] == "TOPLEFT" and forecast.points[1][2] == forecastHealth.barFill
    and forecast.points[1][3] == "TOPRIGHT" and forecast.points[1][4] == 0 and forecast.points[1][5] == 0
    and forecast.points[2][1] == "BOTTOMLEFT" and forecast.points[2][2] == forecastHealth.barFill
    and forecast.points[2][3] == "BOTTOMRIGHT" and forecast.points[2][4] == 0 and forecast.points[2][5] == 0,
    "The fixed-width native status bar starts at our own health texture endpoint with only public offsets")
assert(forecast.barColor[1] == .35 and forecast.barColor[2] == 1
    and forecast.barColor[3] == .65 and forecast.barColor[4] == .7)
forecastHealth.barFill.noNewAnchors, forecastHealth.forbidFillLookup = true, true
local maskReads = 0
for _, key in ipairs({"MyHealPredictionBar", "OtherHealPredictionBar"}) do
    nativeHealth[key].FillMask.GetRect = function() maskReads = maskReads + 1; error("Secret native geometry") end
end
assert(Indicators.Start(forecastState, owner, nativeHealth))
assert(forecast.shown and clipper.shown and forecast.minimum == 0 and forecast.maximum == 100 and forecast.value == 30
    and maskReads == 0 and not forecastState.predictions.MyHealPredictionBar.shown
    and not forecastState.predictions.OtherHealPredictionBar.shown,
    "The native calculator renders total incoming heals without reading secret native mask geometry")
amounts.maximum, amounts.incoming = secret, secret
env.UnitFrameHealPredictionBars_Update(owner)
assert(rawequal(forecast.maximum, secret) and rawequal(forecast.value, secret) and forecast.shown,
    "Opaque maximum and incoming-heal amounts pass directly to the permitted status bar sinks")
amounts.maximum, amounts.incoming = 100, 0
Indicators.Update(forecastState)
assert(forecast.value == 0 and forecast.shown, "Cancellation sends zero to the engine instead of retaining old healing fill")
amounts.refusedUpdate = true
Indicators.Update(forecastState)
assert(not forecast.shown and not clipper.shown, "A refused calculator update hides the previous forecast")
amounts.refusedUpdate, amounts.incoming = false, 25
Indicators.Update(forecastState)
assert(forecast.shown and clipper.shown and forecast.value == 25)
forecast.refusedValue = true
Indicators.Update(forecastState)
assert(not forecast.shown and not clipper.shown, "A refused display sink also clears old forecast visuals")
forecast.refusedValue = false
Indicators.Update(forecastState)
assert(forecast.shown and forecast.value == 25)
Indicators.Stop(forecastState)
assert(not forecast.shown and not clipper.shown)
local preparedWidgets, preparedUpdates = #widgets, amounts.updates
env.UnitFrameHealPredictionBars_Update(owner)
assert(amounts.updates == preparedUpdates, "Stopped forecast hooks remain inert")
assert(Indicators.Prepare(forecastState) and Indicators.Start(forecastState, owner, nativeHealth))
assert(#widgets == preparedWidgets and amounts.factories == 1 and #forecast.points == 2,
    "Restart reuses the calculator, clipping frame and original anchors after secret layout arrives")
Indicators.Stop(forecastState)

local detailed = env.UnitGetDetailedHealPrediction
env.UnitGetDetailedHealPrediction = false
local fallback = assert(Indicators.Create(root, Widget(false)))
local fallbackWidgets = #widgets
assert(not Indicators.Prepare(fallback) and #widgets == fallbackWidgets,
    "Missing calculator APIs leave the old public-geometry path available without allocating a forecast")
for _, key in ipairs({"MyHealPredictionBar", "OtherHealPredictionBar"}) do
    nativeHealth[key].FillMask.GetRect = nil
    nativeHealth[key].FillMask.rect = {120, 20, 10, 20}
end
assert(Indicators.Start(fallback, owner, nativeHealth) and fallback.predictions.MyHealPredictionBar.shown)
Indicators.Stop(fallback)
env.UnitGetDetailedHealPrediction, amounts.refusedCreate = detailed, true
assert(not Indicators.Prepare(fallback) and #widgets == fallbackWidgets,
    "Refused calculator creation preserves the public native mirror")
amounts.refusedCreate = false
assert(Indicators.Prepare(fallback) and Indicators.Start(fallback, owner, nativeHealth),
    "Calculator availability can recover on a later preparation")
Indicators.Stop(fallback)

local missingHealth = Widget(false)
missingHealth.missingFill = true
local missingFill = assert(Indicators.Create(root, missingHealth))
assert(not Indicators.Prepare(missingFill) and not missingFill.forecast,
    "A missing health texture never turns a nil relative anchor into the frame parent")
local missingWidgets = #widgets
assert(not Indicators.Prepare(missingFill) and #widgets == missingWidgets,
    "Repeated missing textures do not leak clipping frames")
missingHealth.missingFill = false
assert(Indicators.Prepare(missingFill), "A public texture can recover before values are synchronized")
missingFill.forecast.refusedTexture = true
assert(not Indicators.Prepare(missingFill) and not missingFill.forecastReady,
    "A missing forecast fill texture keeps the native public mirror as the fallback")
local textureWidgets = #widgets
missingHealth.barFill.noNewAnchors, missingHealth.forbidFillLookup = true, true
missingFill.forecast.refusedTexture = false
assert(Indicators.Prepare(missingFill) and #widgets == textureWidgets and #missingFill.forecast.points == 2,
    "Texture recovery reuses the original forecast anchors without reading the now-secret health fill")
Indicators.Stop(missingFill)

local rejectedHealth = Widget(false)
rejectedHealth.barFill = Widget(false); rejectedHealth.barFill.noNewAnchors = true
local rejected = assert(Indicators.Create(root, rejectedHealth))
assert(not Indicators.Prepare(rejected) and rejected.forecast and not rejected.forecastAnchored,
    "A rejected forecast anchor keeps its partial frame hidden and retained")
local rejectedWidgets = #widgets
rejectedHealth.forbidFillLookup = true
assert(not Indicators.Prepare(rejected) and #widgets == rejectedWidgets
    and not rejected.forecast.shown and not rejected.clipper.shown,
    "Rejected anchors are never retried after native values can make layout secret")
local secretHealth = Widget(false)
secretHealth.barFill = Widget(false); secretHealth.barFill.secretLayout = true
local secretFill = assert(Indicators.Create(root, secretHealth))
assert(not Indicators.Prepare(secretFill) and not secretFill.forecast,
    "A first setup cannot inherit a health texture layout that is already secret")

-- Player and target keep separate calculators, post-hook owners and active lifetimes.
env.C_Texture.GetAtlasInfo = function() return {width = 26, height = 26} end
local targetCombat, targetCombatRefused = true, false
env.UnitAffectingCombat = function(unit)
    assert(unit == "target", "Only target combat uses the unit combat query")
    if targetCombatRefused then error("Refused target combat state") end
    return targetCombat
end
amounts.byUnit = {player = {maximum = 100, incoming = 11}, target = {maximum = secret, incoming = secret}}
amounts.unitUpdates = {player = 0, target = 0}
local pairPlayerHealth, pairTargetHealth = Widget(false), Widget(false)
pairPlayerHealth.rect, pairTargetHealth.rect = {0, 0, 200, 22}, {0, 0, 200, 22}
pairPlayerHealth.level, pairTargetHealth.level = 6, 6
local pairPlayer = assert(Indicators.Create(root, pairPlayerHealth))
local pairTarget = assert(Indicators.Create(root, pairTargetHealth, "target"))
assert(pairPlayer.unit == "player" and pairTarget.unit == "target")
assert(pairPlayer.combat.rect[3] == 26 and pairTarget.combat.rect[3] == 26
    and pairPlayer.combat.rect[4] == 26 and pairTarget.combat.rect[4] == 26
    and pairPlayer.combat.point[1] == "CENTER" and pairTarget.combat.point[1] == "CENTER"
    and pairPlayer.combat.point[4] == 16 and pairTarget.combat.point[4] == 216
    and pairPlayer.combat.point[5] == pairTarget.combat.point[5],
    "Player and target combat icons keep the same size and mirrored horizontal placement")
local targetOwner, targetNativeHealth = Widget(true), Widget(true)
targetNativeHealth.rect = {secret, secret, secret, secret}
local targetNativeReads = 0
targetNativeHealth.GetValue = function() targetNativeReads = targetNativeReads + 1; error("Opaque target health") end
targetNativeHealth.GetMinMaxValues = function() targetNativeReads = targetNativeReads + 1; error("Opaque target range") end
for _, key in ipairs(keys) do
    local segment = Widget(true)
    segment.Fill, segment.FillMask = Widget(true), Widget(true)
    if key == "MyHealPredictionBar" or key == "OtherHealPredictionBar" then
        segment.shown = true
        segment.FillMask.GetRect = function()
            targetNativeReads = targetNativeReads + 1; error("Opaque target prediction geometry")
        end
    end
    targetNativeHealth[key] = segment
end
assert(Indicators.Prepare(pairPlayer) and Indicators.Prepare(pairTarget))
pairPlayerHealth.barFill.noNewAnchors, pairPlayerHealth.forbidFillLookup = true, true
pairTargetHealth.barFill.noNewAnchors, pairTargetHealth.forbidFillLookup = true, true
local pairWidgets, pairFactories = #widgets, amounts.factories
attack.shown = true
assert(Indicators.Start(pairPlayer, owner, nativeHealth, "player"))
assert(Indicators.Start(pairTarget, targetOwner, targetNativeHealth, "target"))
assert(#widgets == pairWidgets and amounts.factories == pairFactories,
    "Activating prepared player and target states creates no additional widgets or calculators")
assert(pairPlayer.active and pairTarget.active and pairPlayer.combat.shown and pairTarget.combat.shown
    and pairPlayer.forecast.shown and pairTarget.forecast.shown,
    "Player and target indicators remain active and visible simultaneously")
assert(pairPlayer.forecast.value == 11 and rawequal(pairTarget.forecast.maximum, secret)
    and rawequal(pairTarget.forecast.value, secret) and targetNativeReads == 0,
    "Target forecast values remain opaque and never require native bar or mask getters")
amounts.byUnit.player.incoming, amounts.byUnit.target.incoming = 17, 27
local playerUpdates, targetUpdates = amounts.unitUpdates.player, amounts.unitUpdates.target
env.UnitFrameHealPredictionBars_Update(targetOwner)
assert(amounts.unitUpdates.target == targetUpdates + 1 and amounts.unitUpdates.player == playerUpdates
    and pairTarget.forecast.value == 27 and pairPlayer.forecast.value == 11,
    "A target-owner prediction hook updates only its target state")
targetUpdates = amounts.unitUpdates.target
env.PlayerFrame_UpdateStatus()
assert(amounts.unitUpdates.player == playerUpdates + 1 and amounts.unitUpdates.target == targetUpdates
    and pairPlayer.forecast.value == 17,
    "The native player-status hook does not update target indicators")
playerUpdates, targetUpdates = amounts.unitUpdates.player, amounts.unitUpdates.target
env.UnitFrameHealPredictionBars_Update(secret)
env.UnitFrameHealPredictionBars_Update(Widget(true))
assert(amounts.unitUpdates.player == playerUpdates and amounts.unitUpdates.target == targetUpdates,
    "Secret or unrelated owners never index or update an active-state entry")
targetCombat = secret
Indicators.Update(pairTarget)
assert(not pairTarget.combat.shown and pairTarget.forecast.shown,
    "A secret target combat flag hides the old icon without hiding the valid forecast")
targetCombat, targetCombatRefused = true, true
Indicators.Update(pairTarget)
assert(not pairTarget.combat.shown and pairTarget.forecast.shown,
    "A refused target combat query clears the old icon")
targetCombatRefused = false
Indicators.Update(pairTarget); assert(pairTarget.combat.shown)
targetCombat = false
Indicators.Update(pairTarget); assert(not pairTarget.combat.shown)
targetCombat = true
local targetCombatAPI = env.UnitAffectingCombat
env.UnitAffectingCombat = false
Indicators.Update(pairTarget); assert(not pairTarget.combat.shown)
env.UnitAffectingCombat = targetCombatAPI
Indicators.Update(pairTarget); assert(pairTarget.combat.shown)

Indicators.Stop(pairPlayer)
playerUpdates, targetUpdates = amounts.unitUpdates.player, amounts.unitUpdates.target
amounts.byUnit.target.incoming = 29
env.UnitFrameHealPredictionBars_Update(targetOwner)
assert(not pairPlayer.active and not pairPlayer.forecast.shown and pairTarget.active
    and pairTarget.forecast.value == 29 and amounts.unitUpdates.target == targetUpdates + 1
    and amounts.unitUpdates.player == playerUpdates,
    "Stopping the player leaves target hooks and forecasts active")
local stoppedPairWidgets = #widgets
assert(Indicators.Prepare(pairPlayer) and Indicators.Start(pairPlayer, owner, nativeHealth))
assert(#widgets == stoppedPairWidgets and amounts.factories == pairFactories
    and hooks.PlayerFrame_UpdateStatus == 1 and hooks.UnitFrameHealPredictionBars_Update == 1,
    "Restart reuses both calculators, frames, anchors and shared hooks")
assert(#pairPlayer.forecast.points == 2 and #pairTarget.forecast.points == 2)

for _, invalid in ipairs({false, 0, "", "pet", "focus", {}, secret}) do
    local beforeInvalidWidgets = #widgets
    playerUpdates, targetUpdates = amounts.unitUpdates.player, amounts.unitUpdates.target
    assert(not Indicators.Create(root, pairTargetHealth, invalid) and #widgets == beforeInvalidWidgets,
        "Invalid or secret unit tokens fail before creating indicator widgets")
    assert(not Indicators.Start(pairTarget, targetOwner, targetNativeHealth, invalid),
        "Invalid or secret unit tokens cannot activate an existing indicator state")
    assert(pairPlayer.active and pairTarget.active and pairTarget.unit == "target"
        and amounts.unitUpdates.player == playerUpdates and amounts.unitUpdates.target == targetUpdates,
        "Rejected unit tokens leave the existing player and target states untouched")
end

local replacementHealth = Widget(false); replacementHealth.rect, replacementHealth.level = {0, 0, 200, 22}, 6
local replacementPlayer = assert(Indicators.Create(root, replacementHealth, "player"))
assert(Indicators.Prepare(replacementPlayer))
assert(Indicators.Start(replacementPlayer, owner, nativeHealth, "player"))
assert(replacementPlayer.active and not pairPlayer.active and not pairPlayer.forecast.shown and pairTarget.active,
    "Starting a replacement stops only the prior state for that same native owner")
playerUpdates, targetUpdates = amounts.unitUpdates.player, amounts.unitUpdates.target
env.UnitFrameHealPredictionBars_Update(owner)
assert(amounts.unitUpdates.player == playerUpdates + 1 and amounts.unitUpdates.target == targetUpdates
    and replacementPlayer.forecast.shown and not pairPlayer.forecast.shown,
    "The replaced owner's hook reaches its new state exclusively")
Indicators.Stop(pairPlayer)
playerUpdates = amounts.unitUpdates.player
env.UnitFrameHealPredictionBars_Update(owner)
assert(amounts.unitUpdates.player == playerUpdates + 1 and replacementPlayer.forecast.shown,
    "Stopping an old replaced state cannot unregister the current state for its owner")
Indicators.Stop(pairTarget)
playerUpdates, targetUpdates = amounts.unitUpdates.player, amounts.unitUpdates.target
env.UnitFrameHealPredictionBars_Update(owner)
env.UnitFrameHealPredictionBars_Update(targetOwner)
assert(amounts.unitUpdates.player == playerUpdates + 1 and amounts.unitUpdates.target == targetUpdates
    and replacementPlayer.forecast.shown and not pairTarget.forecast.shown,
    "Stopping the target leaves the independent player state updating")
local targetRestartWidgets, targetRestartFactories = #widgets, amounts.factories
assert(Indicators.Prepare(pairTarget) and Indicators.Start(pairTarget, targetOwner, targetNativeHealth))
assert(pairTarget.unit == "target" and pairTarget.forecast.shown and replacementPlayer.active
    and #widgets == targetRestartWidgets and amounts.factories == targetRestartFactories,
    "Target restart keeps its original unit and resources while the player remains active")
Indicators.Stop(pairTarget)
local replacementWidgets, replacementFactories = #widgets, amounts.factories
Indicators.Stop(replacementPlayer)
assert(Indicators.Prepare(replacementPlayer) and Indicators.Start(replacementPlayer, owner, nativeHealth))
assert(#widgets == replacementWidgets and amounts.factories == replacementFactories,
    "Restarting the replacement state allocates no additional widgets or calculators")
Indicators.Stop(replacementPlayer)
assert(nativeWrites == 0, "Native frames, masks, colors and visibility remain untouched")
print("PASS: player and target heal forecasts, opaque UI sinks, native owner isolation, safe combat icons, cleanup and reusable anchors")
