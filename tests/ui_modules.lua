-- Exercise the real settings callbacks without starting the game.
local env = setmetatable({}, {__index = _G})
env._G = env
local frames, modules, overrides, menuItems = {}, {}, {}, {}
local combat, dead, confirmation, lastLayout, ended, revealed = false, false, nil, nil, nil, nil
local methods = {}
local function noop() end
local function Frame(name, parent)
    local frame = setmetatable({name = name, parent = parent, scripts = {}, shown = true,
        width = 620, height = 400, scale = 1, text = "", points = {}, enabled = true}, {__index = methods})
    if name then frames[name], env[name] = frame, frame end
    return frame
end
setmetatable(methods, {__index = function() return noop end})
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetVerticalScroll() return rawget(self, "scroll") or 0 end
function methods:SetVerticalScroll(value) self.scroll = value end
function methods:SetScrollChild(child) self.child = child end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale end
function methods:SetScale(value) self.scale = value end
function methods:GetLeft() return 100 end
function methods:GetTop() return 500 end
function methods:GetCenter() return 300, 300 end
function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
function methods:ClearAllPoints() self.points = {} end
function methods:SetText(value) self.text = value end
function methods:GetText() return self.text end
function methods:GetNumLines()
    local _, newlines = self.text:gsub("\n", "\n")
    return math.max(newlines + 1, math.ceil(#self.text / math.max(1, math.floor(self.width / 8))))
end
function methods:GetStringWidth() return #self.text * 6 end
function methods:GetUnboundedStringWidth() return #self.text * 6 end
function methods:GetStringHeight() return 14 * (1 + select(2, self.text:gsub("\n", ""))) end
function methods:SetScript(key, fn) self.scripts[key] = fn end
function methods:HookScript(key, fn)
    local previous = self.scripts[key]
    self.scripts[key] = function(...) if previous then previous(...) end; fn(...) end
end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(value) self.shown = value == true end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not rawget(self, "parent") or self.parent:IsVisible()) end
function methods:SetEnabled(value) self.enabled = value == true end
function methods:EnableMouse(value) self.mouse = value end
function methods:EnableMouseMotion(value) self.mouseMotion = value end
function methods:SetFrameStrata(value) self.strata = value end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetValue(value) self.value = value end
function methods:GetFontString() self.fontString = rawget(self, "fontString") or Frame(); return self.fontString end
function methods:CreateFontString(name) return Frame(name, self) end
function methods:CreateTexture(name) return Frame(name, self) end
function methods:GetThumbTexture() return Frame() end
function methods:HasFocus() return false end
function methods:IsForbidden() return false end
function methods:GetOwner() return self.owner end
function methods:SetOwner(value) self.owner = value end
function methods:SetParent(parent) self.parent = parent end
env.CreateFrame = function(_, name, parent) return Frame(name, parent) end
env.UIParent = Frame(); env.UIParent:SetSize(1440, 900)
env.UISpecialFrames, env.SlashCmdList = {}, {}
env.InCombatLockdown = function() return combat end
env.UnitIsDeadOrGhost = function() return dead end
env.GetTime = function() return 0 end
env.C_Timer = {After = noop, NewTicker = function() return {Cancel = noop} end}
env.Settings = {RegisterCanvasLayoutSubcategory = function() return {GetID = function() return 1 end} end}
env.MenuUtil = {CreateContextMenu = function(_, build)
    menuItems = {}
    build(nil, setmetatable({CreateButton = function(_, text, callback) menuItems[text] = callback end}, {__index = function() return noop end}))
end}
local ns = {L = function(text) return text end, UI = {}, TalentPlanData = {Read = function() return nil end}}
ns.UI.IsOverride = function(id) return overrides[id] == true end
ns.UI.SetOverride = function(id, value) overrides[id] = value; if modules[id] then modules[id].Refresh() end end
ns.UI.GetStyle = function() return nil end
ns.UI.StyleFrame, ns.UI.StylePanel, ns.UI.StyleButton = noop, noop, noop
ns.UI.Label = function(parent, text, x, y)
    local label = Frame(nil, parent); label:SetText(text); label:SetPoint("TOPLEFT", x, y); return label
end
ns.UI.ClampScroll = function(scroll, height)
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, height - scroll:GetHeight())))
end
ns.UI.StartLayout = function(id) lastLayout = id; return true end
ns.UI.Notify = noop
ns.UI.RevealControl = function(scroll, control) revealed = {scroll = scroll, control = control} end
ns.UI.Confirm = function(_, accept) confirmation = accept; return true end
ns.UI.PreviewEnded = function(id) ended = id end
ns.RegisterModule = function(id, descriptor) modules[id] = descriptor end
local function Load(path)
    local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("QoLToolkit", ns)
end
Load("Core/WoWRuntime.lua")
Load("Modules/AuraReminderModel.lua")
Load("Modules/AuraReminders.lua")
ns.InitializeReminders({})
assert(not frames.ArkannsQOLReminderVisibilityTab, "Reminder display uses one tab for appearance and visibility")
modules.reminders.OpenSettings("Mode compact : 2 effets")
assert(frames.ArkannsQOLAppearancePage.shown and not frames.ArkannsQOLEffectsPage.shown)
assert(revealed.control == frames.ArkannsQOLReminder_compact)
local reminderPageBeforeReturn = frames.ArkannsQOLAppearancePage
modules.reminders.OpenSettings(nil)
assert(reminderPageBeforeReturn.shown, "Returning from layout preserves the display tab")
modules.reminders.OpenSettings("Ajouter par nom / ID")
assert(frames.ArkannsQOLEffectsPage.shown and revealed.control == frames.ArkannsQOLManualInput)
local effectsList = frames.ArkannsQOLEffectsList
assert(not effectsList.shown, "Empty reminders leave room for the add controls")
local manual = frames.ArkannsQOLManualInput
manual:SetText("Test aura")
manual.scripts.OnEnterPressed()
assert(effectsList.shown and manual.points[1][3] > effectsList.points[1][3], "Manual add stays above the tracked list")
frames.ArkannsQOLEffectRow1.delete.scripts.OnClick()
assert(effectsList.shown, "A deletion prompt preserves the selected reminder")
confirmation()
assert(not effectsList.shown, "Confirmed removal of the last reminder frees the list space")
local previewStarted = modules.reminders.Preview(true)
local reminder = frames.ArkannsQOLReminder
assert(reminder.mouse == false and reminder.mouseMotion == false and reminder.strata == "HIGH", "Layout reminders must leave input to their mover")
assert(previewStarted == true)
assert(not frames.ArkannsQOLReminderTestControls.shown, "Layout has one set of controls")
modules.reminders.StopPreview(); assert(ended == "reminders")
combat = true
local ok, reason = modules.reminders.Preview()
assert(ok == false and type(reason) == "string", "Rejected preview must explain why")
combat = false
assert(frames.ArkannsQOLAppearancefontSize.enabled == false, "Inherited style cannot be edited")
modules.reminders.OpenSettings("Police")
assert(revealed.control == frames.ArkannsQOLAppearancefont)
modules.reminders.OpenSettings(nil)
assert(frames.ArkannsQOLAppearancePage.shown, "Reopening preserves the advanced reminder appearance section")
overrides.reminders = true; modules.reminders.Refresh()
assert(frames.ArkannsQOLAppearancefontSize.enabled)
local appearance = env.ArkannsQOLRemindersDB.appearance
appearance.title, appearance.customTitle = "My reminder", true
appearance.width, appearance.layout, appearance.columns = 555, "grid", 3
local reminderPage = frames.ArkannsQOLAppearancePage
-- Search already opens the detailed appearance controls.
local wideAppearance = reminderPage.child:GetHeight()
reminderPage.child:SetWidth(300)
reminderPage.scripts.OnSizeChanged(reminderPage, 300)
assert(reminderPage.child:GetHeight() > wideAppearance, "Narrow reminder appearance stacks independent groups")
assert(frames.ArkannsQOLAppearancecolumns.shown, "Column count is visible for grid mode")
appearance.layout = "vertical"; modules.reminders.Refresh()
assert(not frames.ArkannsQOLAppearancecolumns.shown, "List mode hides grid column count")
appearance.layout = "grid"
reminderPage:SetVerticalScroll(500)
frames.ArkannsQOLAppearanceAdvanced.scripts.OnClick(frames.ArkannsQOLAppearanceAdvanced)
assert(reminderPage:GetVerticalScroll() < 500, "Collapsing reminder appearance clamps scroll")
frames.ArkannsQOLAppearanceTheme.scripts.OnClick(frames.ArkannsQOLAppearanceTheme)
assert(menuItems["Compact"]); menuItems["Compact"]()
assert(appearance.title == "My reminder" and appearance.customTitle)
assert(appearance.width == 555 and appearance.layout == "grid" and appearance.columns == 3, "Theme keeps content and layout")
frames.ArkannsQOLAppearancePlace.scripts.OnClick()
assert(lastLayout == "reminders")
frames.ArkannsQOLReminderSettings:SetWidth(340)
frames.ArkannsQOLReminderSettings.scripts.OnSizeChanged()
assert(frames.ArkannsQOLAppearanceTab.points[1][3] < frames.ArkannsQOLEffectsTab.points[1][3], "Narrow tabs stack")

Load("Modules/SessionJournalModel.lua")
Load("Modules/SessionJournal.lua")
ns.InitializeSessionJournal({})
assert(not frames.ArkannsQOLSessionVisibilityTab, "Session display uses one tab for appearance and visibility")
assert(frames.ArkannsQOLSession_compact.parent == frames.ArkannsQOLSession_enabled.parent,
    "Compact mode and window visibility share the display group")
modules.session.OpenSettings("Largeur min.")
assert(frames.ArkannsQOLSessionAppearance.shown and revealed.control == frames.ArkannsQOLSession_width)
modules.session.OpenSettings(nil)
assert(frames.ArkannsQOLSessionAppearance.shown, "Layout return preserves session display tab")
modules.session.OpenSettings("XP gagnée")
assert(not frames.ArkannsQOLSessionAppearance.shown and revealed.control == frames.ArkannsQOLSessionMetric2)
local metricOrder = env.ArkannsQOLSessionDB.order
metricOrder[1], metricOrder[2] = metricOrder[2], metricOrder[1]
modules.session.OpenSettings("XP gagnée")
assert(revealed.control == frames.ArkannsQOLSessionMetric1, "Search follows the current statistic order")
metricOrder[1], metricOrder[2] = metricOrder[2], metricOrder[1]
assert(modules.session.toggleLabel == "Afficher le journal")
assert(modules.session.Preview(true) == true and frames.ArkannsQOLSessionWindow.mouse == false)
assert(frames.ArkannsQOLSessionWindow.strata == "MEDIUM")
assert(frames.ArkannsQOLSessionTrackingToggle.mouse == false)
assert(frames.ArkannsQOLSessionHover_xp.mouseMotion == false)
modules.session.StopPreview(); assert(ended == "session")
modules.session.Preview(); assert(frames.ArkannsQOLSessionWindow.strata == "DIALOG")
modules.session.StopPreview(); assert(frames.ArkannsQOLSessionWindow.strata == "MEDIUM")
assert(frames.ArkannsQOLSession_fontSize.enabled == false)
local previousStyle = ns.UI.GetStyle
ns.UI.GetStyle = function(id)
    if id == "session" and not overrides.session then
        return {fontSize = 19, opacity = .72, padding = 12, gap = 6, scale = 1, bg = {0, 0, 0}, text = {1, 1, 1}, accent = {1, 1, 1}}
    end
end
modules.session.Refresh()
assert(frames.ArkannsQOLSession_fontSize.value == 19 and frames.ArkannsQOLSession_opacity.value == 72)
assert(env.ArkannsQOLSessionDB.fontSize == 13 and env.ArkannsQOLSessionDB.opacity == 85, "Inherited values leave the local settings intact")
ns.UI.GetStyle = previousStyle
local compact = frames.ArkannsQOLSession_compact
local expand = frames.ArkannsQOLSession_expandOnHover
assert(not expand.shown)
compact:SetChecked(true); compact.scripts.OnClick(compact)
assert(expand.shown)
compact:SetChecked(false); compact.scripts.OnClick(compact)
assert(not expand.shown)
overrides.session = true; modules.session.Refresh()
assert(frames.ArkannsQOLSession_fontSize.enabled)
frames.ArkannsQOLSessionPlace.scripts.OnClick()
assert(lastLayout == "session")
assert(frames.ArkannsQOLSessionHover_net and not frames.ArkannsQOLSessionHover_income, "Net hourly rate belongs to net gold")
combat = true
assert(modules.session.Preview() == false)
combat = false

Load("Modules/TalentPlanModel.lua")
local first, second, third = {}, {}, {}
local bucket = {plans = {first, second, third}, active = 3}
assert(ns.TalentPlanModel.DeletePlan(bucket, second))
assert(#bucket.plans == 2 and bucket.plans[1] == first and bucket.plans[2] == third and bucket.active == 2)
assert(not ns.TalentPlanModel.DeletePlan(bucket, second), "Stale confirmation cannot delete another plan")
assert(ns.TalentPlanModel.DeletePlan(bucket, third) and bucket.active == 1)
assert(ns.TalentPlanModel.DeletePlan(bucket, first) and #bucket.plans == 0)
Load("Modules/TalentPlanner.lua")
ns.InitializeTalentPlanner({})
modules.talents.OpenSettings("Couleur du prochain point")
assert(frames.ArkannsQOLTalentAdvanced.shown and revealed.control == frames.ArkannsQOLTalentColornextColor)
modules.talents.OpenSettings("Déplacer")
assert(revealed.control == frames.ArkannsQOLTalentMove)
local talentOptions = frames.ArkannsQOLTalentSettings
local talentScroll = frames.ArkannsQOLTalentSettingsScroll
talentOptions.scripts.OnShow()
-- Close the advanced section opened by the search before exercising its toggle.
if frames.ArkannsQOLTalentAdvanced.shown then frames.ArkannsQOLTalentAdvancedToggle.scripts.OnClick() end
assert(not frames.ArkannsQOLTalentAdvanced.shown)
local moveY = frames.ArkannsQOLTalentMove.points[1][3]
local collapsedHeight = talentScroll.child:GetHeight()
frames.ArkannsQOLTalentAdvancedToggle.scripts.OnClick()
assert(frames.ArkannsQOLTalentAdvanced.shown and frames.ArkannsQOLTalentMove.points[1][3] == moveY)
local wideHeight = talentScroll.child:GetHeight()
assert(wideHeight > collapsedHeight, "The expanded colors extend the scroll content")
talentOptions:SetWidth(340); talentOptions.scripts.OnSizeChanged()
assert(talentScroll.child:GetWidth() == 290 and talentScroll.child:GetHeight() > wideHeight)
assert(frames.ArkannsQOLTalentColorfutureColor.points[1][3] < frames.ArkannsQOLTalentColornextColor.points[1][3], "Narrow talent colors stack")
talentScroll:SetVerticalScroll(300)
frames.ArkannsQOLTalentAdvancedToggle.scripts.OnClick()
assert(not frames.ArkannsQOLTalentAdvanced.shown and talentScroll:GetVerticalScroll() < 300)
assert(modules.talents.Preview(true))
local talentPreview = frames.ArkannsQOLTalentPreview
assert(talentPreview.mouse == false and talentPreview.strata == "HIGH" and not talentPreview.close.shown)
talentPreview.scripts.OnUpdate(talentPreview, 30)
assert(talentPreview.shown, "Placement preview must not expire")
modules.talents.Refresh()
assert(talentPreview.mouse == false and not talentPreview.close.shown, "Refresh preserves passive placement")
modules.talents.StopPreview(); assert(ended == "talents")
modules.talents.Preview()
talentPreview.scripts.OnUpdate(talentPreview, 13)
assert(not talentPreview.shown and ended == "talents", "Expired preview dismisses global stop controls")
frames.ArkannsQOLTalentMove.scripts.OnClick(); assert(lastLayout == "talents")
combat = true; assert(modules.talents.Preview() == false); combat = false
local native = Frame()
native.EnumerateAllTalentButtons = function() return noop end
env.PlayerSpellsFrame = {TalentsFrame = native}
env.C_Timer.After = function(_, callback) callback() end
ns.TalentPlanData.Read = function()
    return {classToken = "TEST", className = "Test", treeID = 1, configID = 1, maxPoints = 51, availablePoints = 0,
        nodes = {}, actualCounts = {}, actualChoices = {}}
end
local selected, other = {name = "Selected", order = {}}, {name = "Other", order = {}}
local saved = {plans = {selected, other}, active = 1}
env.ArkannsQOLTalentsDB.profiles["TEST:1:1"] = saved
frames.ArkannsQOLTalentEvents.scripts.OnEvent(nil, "PLAYER_ENTERING_WORLD")
frames.ArkannsQOLTalentBuild.scripts.OnClick(frames.ArkannsQOLTalentBuild)
menuItems["Supprimer ce build"]()
assert(confirmation and #saved.plans == 2, "Requesting deletion leaves saved builds untouched")
menuItems.Other()
confirmation()
assert(#saved.plans == 1 and saved.plans[1] == other, "Confirmation deletes the named build despite selection changes")
confirmation()
assert(#saved.plans == 1, "Repeated acceptance cannot delete another build")
frames.ArkannsQOLTalentBuild.scripts.OnClick(frames.ArkannsQOLTalentBuild)
menuItems["Supprimer ce build"]()
local replacement = {plans = {{name = "Replacement", order = {}}}, active = 1}
env.ArkannsQOLTalentsDB.profiles["TEST:1:1"] = replacement
modules.talents.Refresh(); confirmation()
assert(#saved.plans == 1 and #replacement.plans == 1, "A changed profile invalidates pending deletion")
-- Transfer and menu actions retain the exact bucket that the player reviewed.
ns.TalentPlanData.Read = function()
    return {classToken = "TEST", className = "Test", treeID = 1, configID = 1, maxPoints = 51, availablePoints = 0,
        nodes = {[1] = {id = 1, groupID = 1, maxRanks = 2, entries = {[2] = {name = "Talent", maxRanks = 2}}}},
        actualCounts = {}, actualChoices = {}}
end
local original = {name = "Original", firstLevel = 7, order = {{nodeID = 1, entryID = 2}}}
local transferBucket = {plans = {original}, active = 1}
env.ArkannsQOLTalentsDB.profiles["TEST:1:1"] = transferBucket
modules.talents.Refresh()
local function BuildMenu()
    frames.ArkannsQOLTalentBuild.scripts.OnClick(frames.ArkannsQOLTalentBuild)
end
BuildMenu(); menuItems["Dupliquer ce build"]()
assert(#transferBucket.plans == 2 and transferBucket.active == 2)
local duplicate = transferBucket.plans[2]
assert(duplicate.name == "Original (copie)" and duplicate.firstLevel == 7 and duplicate.order[1] ~= original.order[1])
duplicate.order[1].entryID = 99; assert(original.order[1].entryID == 2)
duplicate.order[1].entryID = 2
BuildMenu(); menuItems["Exporter ce build"]()
local dialog, input = frames.ArkannsQOLTalentTransfer, frames.ArkannsQOLTalentTransferInput
local text = input:GetText()
assert(dialog.shown and text:match("^QTB1;TEST;1;7;"))
local transferScroll = frames.ArkannsQOLTalentTransferScroll
transferScroll:SetHeight(100)
input:SetText(string.rep("1234567890", 250)); input.scripts.OnTextChanged(input)
assert(input:GetHeight() >= input:GetNumLines() * 16, "Long wrapped clipboard text expands the scroll child")
input.scripts.OnCursorChanged(input, 0, -500, 1, 14)
assert(transferScroll:GetVerticalScroll() == 414, "Cursor scrolls to the end of long text")
input.scripts.OnCursorChanged(input, 0, 0, 1, 14)
assert(transferScroll:GetVerticalScroll() == 0, "Cursor can return to the first character")
BuildMenu(); menuItems["Importer un build"]()
input:SetText(text)
frames.ArkannsQOLTalentTransferApply.scripts.OnClick()
assert(#transferBucket.plans == 2, "Import waits for confirmation")
confirmation()
assert(#transferBucket.plans == 3 and transferBucket.plans[1] == original and not dialog.shown)
confirmation(); assert(#transferBucket.plans == 3, "Repeated acceptance cannot duplicate the import")
BuildMenu(); menuItems["Importer un build"]()
input:SetText("QTB9;invalid")
frames.ArkannsQOLTalentTransferApply.scripts.OnClick()
assert(#transferBucket.plans == 3 and dialog.shown, "Invalid text preserves all builds")
input:SetText(text); frames.ArkannsQOLTalentTransferApply.scripts.OnClick()
local importConfirmation = confirmation
BuildMenu(); local oldSelection, oldDuplicate = menuItems.Original, menuItems["Dupliquer ce build"]
local newBucket = {plans = {{name = "New context", order = {}}}, active = 1}
env.ArkannsQOLTalentsDB.profiles["TEST:1:1"] = newBucket
modules.talents.Refresh()
oldSelection(); oldDuplicate(); importConfirmation()
assert(#newBucket.plans == 1 and newBucket.active == 1 and #transferBucket.plans == 3, "Stale menus and imports cannot change a replacement bucket")
BuildMenu(); menuItems["Importer un build"]()
combat = true; frames.ArkannsQOLTalentEvents.scripts.OnEvent(nil, "PLAYER_REGEN_DISABLED"); combat = false
assert(not dialog.shown, "Combat closes the transfer dialog")
print("PASS: passive module previews, inherited styles, build deletion, talent copy/transfer, stale menus, and preview cleanup")
