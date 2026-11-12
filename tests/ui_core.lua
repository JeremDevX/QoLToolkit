-- Exercise the shared editor outside WoW. Geometry checks do not replace visual QA.
local env = setmetatable({}, {__index = _G})
env._G = env
local frames, methods = {}, {}
local function noop() end
function methods:SetBackdrop(value) self.backdrop = value end
for _, key in ipairs({"SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetFont",
    "SetJustifyH", "SetOrientation", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetMaxLetters",
    "SetAutoFocus", "RegisterForDrag", "SetClampedToScreen", "SetMovable", "SetVertexColor", "SetTexCoord",
    "SetColorTexture", "SetTexture", "SetAlpha", "RegisterEvent", "ClearFocus", "StartMoving", "StopMovingOrSizing",
    "SetWordWrap"}) do
    methods[key] = noop
end
function methods:SetScript(key, callback) self.scripts[key] = callback end
function methods:HookScript(key, callback)
    local previous=self.scripts[key]
    self.scripts[key]=function(...) if previous then previous(...) end; callback(...) end
end
function methods:GetScript(key) return self.scripts[key] end
function methods:Hide()
    local visible = self.shown
    self.shown = false
    if visible and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:Show() self.shown = true end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
methods.IsVisible = methods.IsShown
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetParent(parent) self.parent=parent end
function methods:GetScale() return self.scale or 1 end
methods.GetEffectiveScale = methods.GetScale
function methods:GetTop() return self.top end
function methods:GetCenter() return self.x or 700,self.y or 400 end
function methods:ClearAllPoints() self.points={} end
function methods:SetPoint(point,relative,relativePoint,x,y)
    self.points[point]={relative,relativePoint,x,y}
    if point == "CENTER" and type(x)=="number" then self.x,self.y=x,y end
end
function methods:SetAllPoints() end
function methods:SetFrameStrata(value) self.strata=value end
function methods:SetFrameLevel(value) self.level=value end
function methods:EnableMouse(value) self.mouse=value end
function methods:SetText(value)
    self.text=value
    if self.fontString then self.fontString:SetText(value) end
end
function methods:GetText() return self.text or "" end
function methods:GetStringHeight() return 20 end
function methods:GetUnboundedStringWidth() return #self:GetText()*6 end
function methods:SetChecked(value) self.checked=value end
function methods:SetFocus() self.focused=true end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled=value end
function methods:SetValue(value) self.value=value end
local function Frame(_, name, parent)
    local frame=setmetatable({scripts={},points={},shown=true,width=200,height=80,parent=parent},{__index=methods})
    if name then frames[name]=frame; env[name]=frame end
    if parent then
        parent.children=parent.children or {}
        parent.children[#parent.children+1]=frame
    end
    return frame
end
function methods:CreateTexture() return Frame() end
function methods:CreateFontString() return Frame(nil,nil,self) end
function methods:GetFontString()
    if not self.fontString then self.fontString=Frame(); self.fontString:SetText(self:GetText()) end
    return self.fontString
end
function methods:SetNormalTexture() self.normal=Frame() end
function methods:GetNormalTexture() return self.normal end
function methods:SetHighlightTexture() self.highlight=Frame() end
function methods:GetHighlightTexture() return self.highlight end
function methods:SetThumbTexture() self.thumb=Frame() end
function methods:GetThumbTexture() return self.thumb end
function methods:SetScrollChild(frame) self.child=frame end
function methods:GetScrollChild() return self.child end
function methods:GetVerticalScroll() return self.offset or 0 end
function methods:SetVerticalScroll(value) self.offset=value end
env.CreateFrame=Frame
env.UIParent=Frame(); env.UIParent:SetSize(1000,800)
env.UISpecialFrames={}
env.ForeverTooltipLibreDB={ui={bg={.2, .1, .05}, scale=1.2}}
local combat, message, popup = false
env.InCombatLockdown=function() return combat end
env.print=function(value) message=value end
env.StaticPopup_ShowGenericConfirmation=function(text,callback) popup={text=text,callback=callback} end
env.issecretvalue=function() return false end
local useEnglish=false
local ns={English={}}
ns.L=function(text) return useEnglish and ns.English[text] or text end
local function Load(path)
    local chunk = path=="Core/QOLInterface.lua" and QOL_UI_SOURCE and assert(loadstring(QOL_UI_SOURCE)) or assert(loadfile(path))
    setfenv(chunk,env)("QoLToolkit",ns)
end
Load("Core/WoWRuntime.lua"); Load("Core/QOLInterface.lua")
local UI=ns.UI
-- Most editor checks isolate navigation; the actual window is exercised below.
UI.RegisterSettingsPanel=function(parent, panel, label) return env.Settings.RegisterCanvasLayoutSubcategory(parent,panel,label) end
UI.OpenCategory=function(category) env.Settings.OpenToCategory(category:GetID()); return true end
UI.Initialize()
assert(UI.GetStyle().theme == "warm" and UI.GetStyle().bg[1] == .2, "Old settings retain their custom palette")
assert(UI.GetStyle().border == "theme", "Old settings use the theme border")
local settings, writes, imports = {},0,0
local module={label="Talents",frame=Frame()}
module.GetPosition=function() return settings.x or .7,settings.y or .5 end
module.SetPosition=function(x,y) writes=writes+1; settings.x,settings.y=x,y end
module.ExportSettings=function() return UI.Copy(settings) end
module.ImportSettings=function(value) imports=imports+1; settings=UI.Copy(value); return true end
module.Preview=function() return true end
module.StopPreview=noop
ns.RegisterModule("talents",module)
assert(UI.StartLayout("talents"))
assert(writes==0,"Opening layout must preserve automatic anchoring")
UI.EndLayout(false)
assert(settings.x==nil and writes==0,"Applying an untouched layout must preserve automatic anchoring")
assert(UI.StartLayout("talents"))
frames.ArkannsQOLLayoutCenter.scripts.OnClick()
assert(settings.x==.5)
UI.EndLayout(true)
assert(settings.x==nil,"Cancel must restore the original automatic anchor")
assert(UI.StartLayout("talents"))
frames.ArkannsQOLLayoutCenter.scripts.OnClick()
UI.EndLayout(false)
assert(settings.x==.5,"Apply must retain an explicitly moved position")
assert(not frames.ArkannsQOLLayoutStop,"Remove the duplicate cancel action")
assert(frames.ArkannsQOLLayout.level > frames.ArkannsQOLMover_talents.level)
assert(UI.StartLayout("talents"))
local mover = frames.ArkannsQOLMover_talents
mover.scripts.OnDragStart(mover)
assert(mover.scripts.OnUpdate)
UI.EndLayout(true)
assert(not mover.scripts.OnUpdate and not mover:IsShown(), "Cancelling a drag releases the mover")
combat=true; message=nil
assert(UI.StartLayout()==false and message:find("hors combat",1,true))
combat=false
module.Preview=function() return false,"Aperçu refusé" end
assert(UI.PreviewModule("talents")==false and message:find("Aperçu refusé",1,true))
assert(not frames.ArkannsQOLPreviewBar,"No stop bar for a rejected preview")
module.Preview=function() return true end
assert(UI.PreviewModule("talents"))
assert(frames.ArkannsQOLPreviewBar:IsShown())
UI.PreviewEnded("session"); assert(frames.ArkannsQOLPreviewBar:IsShown())
UI.PreviewEnded("talents"); assert(not frames.ArkannsQOLPreviewBar:IsShown(),"An expired or closed preview must remove its stop bar")
assert(UI.PreviewModule("talents"))
ns.StopAllPreviews(); assert(not frames.ArkannsQOLPreviewBar:IsShown())
local deleted=false
assert(UI.Confirm("Supprimer ?",function() deleted=true end))
assert(not deleted); combat=true; popup.callback(); assert(not deleted)
combat=false; UI.Confirm("Supprimer ?",function() deleted=true end); popup.callback(); assert(deleted)
local opened
env.Settings={RegisterCanvasLayoutSubcategory=function() return {GetID=function() return 1 end} end,
    OpenToCategory=function(id) opened=id end}
module.category=function() return {GetID=function() return 2 end} end
ns.RegisterModule("session", {label="Journal"})
ns.RegisterModule("tooltips", {label="Infobulles", category=function() return {GetID=function() return 3 end} end})
ns.RegisterModule("bags", {label="Sacs", category=function() return {GetID=function() return 4 end} end})
ns.RegisterModule("advanced", {label="Réglages avancés", category=function() return {GetID=function() return 5 end} end})
ns.home=Frame(); ns.home:SetSize(400,600)
ns.InitializeInterface({})
local panel=frames.ArkannsQOLCommonAppearance
panel:SetSize(400,600)
panel.scripts.OnShow()
local scroll=frames.ArkannsQOLCommonTheme.parent.parent
assert(frames.ArkannsQOLCommon_fontSize:IsShown() and frames.ArkannsQOLCommonPreview:IsShown())
assert(not frames.ArkannsQOLCommonBorder:IsShown(), "General settings show theme and typography first")
assert(not frames.ArkannsQOLCommon_borderSize:IsShown(),"Each appearance section shows its own controls")
frames.ArkannsQOLCommonAdvanced.scripts.OnClick()
assert(frames.ArkannsQOLCommonBorder:IsShown() and frames.ArkannsQOLCommonColor_bg:IsShown())
assert(not frames.ArkannsQOLCommonFont:IsShown() and not frames.ArkannsQOLCommon_fontSize:IsShown())
local oneColumnHeight=scroll.child:GetHeight()
local specimen=frames.ArkannsQOLCommonSample
assert(specimen.parent==scroll.child, "Narrow layouts use one scroll surface for preview and controls")
panel:SetWidth(700); panel.scripts.OnSizeChanged()
assert(specimen.parent==panel, "The common appearance preview stays beside controls at a comfortable width")
assert(scroll.child:GetHeight()<oneColumnHeight)
assert(scroll.child:GetHeight()<=scroll:GetHeight(), "The style section fits without scrolling at the normal panel size")
frames.ArkannsQOLCommonDimensions.scripts.OnClick()
assert(frames.ArkannsQOLCommon_borderSize:IsShown() and not frames.ArkannsQOLCommonColor_bg:IsShown())
assert(frames.ArkannsQOLCommon_borderSize:GetWidth()<=scroll.child:GetWidth(),"Appearance controls fit their content column")
panel:SetWidth(400); panel.scripts.OnSizeChanged()
scroll:SetVerticalScroll(250)
frames.ArkannsQOLCommonGeneral.scripts.OnClick()
assert(scroll:GetVerticalScroll()==0 and frames.ArkannsQOLCommon_fontSize:IsShown())
assert(not frames.ArkannsQOLCommonColor_bg:IsShown())
panel:SetSize(576,276); panel.scripts.OnSizeChanged()
assert(not specimen:IsShown() and frames.ArkannsQOLCommonPreview:IsShown(),
    "The minimum window keeps the journal preview action and releases the inline specimen space")
assert(scroll.child:GetHeight()==156 and scroll:GetHeight()==190,
    "General appearance controls fit in the minimum window without scrolling")
frames.ArkannsQOLCommonDimensions.scripts.OnClick()
assert(scroll.child:GetHeight()==138 and scroll.child:GetHeight()<=scroll:GetHeight(),
    "Dimensions fit in the minimum window without scrolling")
frames.ArkannsQOLCommonAdvanced.scripts.OnClick()
assert(scroll.child:GetHeight()==202 and scroll:GetHeight()==190,
    "Colors need only twelve units of scrolling in the minimum window")
assert(UI.OpenSettings("appearance",nil,"talents"))
frames.ArkannsQOLCommonGeneral.scripts.OnClick()
assert(frames.ArkannsQOLAppearanceBack:IsShown() and scroll.child:GetHeight()==156 and scroll:GetHeight()==160,
    "The module return stays available while general settings still fit the minimum window")
frames.ArkannsQOLAppearanceBack.scripts.OnClick()
panel:SetSize(400,600); panel.scripts.OnSizeChanged()
frames.ArkannsQOLCommonAdvanced.scripts.OnClick()
local appearance=UI.ExportSettings(); appearance.pins.talents=true; UI.ImportSettings(appearance)
local card=frames.ArkannsQOLHomeTalents
card.scripts.OnClick()
assert(opened==2)
local homeScroll=frames.ArkannsQOLHomeScroll
local duplicateFavorite=false
for _, button in ipairs(homeScroll.child.children) do
    if button:GetText()==module.label and button.scripts.OnClick then duplicateFavorite=true end
end
assert(not duplicateFavorite and card.parent.parent==homeScroll.child, "Favorites reuse the module card without a duplicate shortcut")
local journal=frames.ArkannsQOLHomeSession.parent
assert(card.parent.points.TOPLEFT[2]>journal.points.TOPLEFT[2], "Favorite cards appear before their original group")
local groupTitles={}
for _,child in ipairs(homeScroll.child.children) do groupTitles[child:GetText()]=child end
assert(groupTitles.Favoris:IsShown() and groupTitles.Personnage:IsShown() and groupTitles.Interface:IsShown())
assert(groupTitles.Outils:IsShown() and not groupTitles.Modules)
assert(frames.ArkannsQOLHomeAppearance.points.TOPLEFT[2] > groupTitles.Favoris.points.TOPLEFT[2],
    "Shared appearance, layout, profiles and diagnostics stay above all module cards")
appearance=UI.ExportSettings(); appearance.pins.session=true; UI.ImportSettings(appearance)
ns.home:SetWidth(589); ns.home.Refresh()
assert(journal.points.TOPLEFT[2]~=card.parent.points.TOPLEFT[2])
local narrowHomeHeight=homeScroll.child:GetHeight()
ns.home:SetWidth(590); ns.home.Refresh()
assert(journal.points.TOPLEFT[2]==card.parent.points.TOPLEFT[2] and journal.points.TOPLEFT[1]~=card.parent.points.TOPLEFT[1])
assert(homeScroll.child:GetHeight()<narrowHomeHeight)
appearance=UI.ExportSettings(); appearance.pins.bags=true; UI.ImportSettings(appearance)
ns.home:SetWidth(949); ns.home.Refresh()
local twoColumnHomeHeight=homeScroll.child:GetHeight()
ns.home:SetWidth(950); ns.home.Refresh()
assert(frames.ArkannsQOLHomeBags.parent.points.TOPLEFT[2]==card.parent.points.TOPLEFT[2],
    "Large dashboards use three columns for independent module cards")
assert(homeScroll.child:GetHeight()<twoColumnHomeHeight)
appearance=UI.ExportSettings(); appearance.pins.bags=nil; UI.ImportSettings(appearance)
appearance=UI.ExportSettings(); appearance.pins.session=nil; UI.ImportSettings(appearance)

local openedSource, openedCalls=nil,0
module.OpenSettings=function(source) openedSource=source; openedCalls=openedCalls+1 end
assert(UI.OpenSettings("talents", "Couleur des erreurs") and opened==2 and openedSource=="Couleur des erreurs")
module.SearchSettings={"Couleur des erreurs"}
local preciseResults=UI.SearchSettings("talents erreurs")
assert(#preciseResults==1)
openedSource=nil; preciseResults[1].Open()
assert(openedSource=="Couleur des erreurs", "Search forwards the source label to the module destination")
assert(#UI.SearchSettings("talents nouveau")==0, "Modules only index their declared destinations")
for _,buttonName in ipairs({"ArkannsQOLLayoutApply", "ArkannsQOLLayoutCancel"}) do
    assert(UI.StartLayout("talents"))
    opened=nil
    local before=openedCalls
    frames[buttonName].scripts.OnClick()
    assert(opened==2 and openedCalls==before+1 and openedSource==nil,
        "Applying or cancelling returns to the owning page without reopening a searched fold")
end
module.OpenSettings=nil
local revealScroll,revealBody,revealTarget=Frame(),Frame(),Frame()
revealScroll:SetHeight(200); revealBody:SetHeight(900); revealScroll:SetScrollChild(revealBody)
revealBody.top,revealTarget.top=800,300
UI.RevealControl(revealScroll,revealTarget)
assert(revealScroll:GetVerticalScroll()==488, "Search reveals the target with a readable top margin")
revealBody.scale,revealTarget.scale=2,1
UI.RevealControl(revealScroll,revealTarget)
assert(revealScroll:GetVerticalScroll()==638, "Search accounts for the control's effective scale")
revealTarget.top=-1000
UI.RevealControl(revealScroll,revealTarget)
assert(revealScroll:GetVerticalScroll()==700, "Search remains inside the scroll range")
revealTarget.top=2000
UI.RevealControl(revealScroll,revealTarget)
assert(revealScroll:GetVerticalScroll()==0)
revealScroll:SetVerticalScroll(100); revealTarget.top=nil
UI.RevealControl(revealScroll,revealTarget)
assert(revealScroll:GetVerticalScroll()==100, "Missing geometry leaves the current scroll position intact")
UI.SetOverride("talents", true)
local themeButton, options = frames.ArkannsQOLCommonTheme, {}
local borderButton = frames.ArkannsQOLCommonBorder
assert(themeButton:GetText() == "Thème : Chaleureux" and not themeButton.enabled)
assert(borderButton:IsShown() and not borderButton.enabled)
env.MenuUtil = {CreateContextMenu = function(owner, build)
    build(owner, {CreateButton = function(_, label, select) options[label] = select end})
end}
UI.Refresh()
assert(themeButton.enabled)
themeButton.scripts.OnClick(themeButton)
Load("Core/Profiles.lua")
local profiles = ns.Profiles
assert(profiles.Save("Legacy theme"))
local legacy = env.ForeverTooltipLibreDB.profiles["Legacy theme"]
legacy.modules.appearance.theme, legacy.modules.appearance.border, legacy.moduleVersions.appearance = nil, nil, nil
options["Blizzard classique"]()
assert(panel.backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border")
options["Mode sombre moderne"]()
assert(panel.backdrop.edgeFile == "Interface\\Buttons\\WHITE8X8" and panel.backdrop.edgeSize == 1)
assert(themeButton:GetText() == "Thème : Mode sombre moderne")
assert(UI.ExportSettings().scale == 1.2 and UI.ExportSettings().pins.talents and UI.IsOverride("talents"))
UI.Initialize(); UI.Refresh()
assert(UI.GetStyle().theme == "modern" and UI.GetStyle("talents") == nil, "Theme and overrides survive reload")
assert(profiles.Save("Modern theme"))
assert(profiles.Apply(assert(profiles.Preview("Legacy theme", {appearance = true}))))
assert(UI.GetStyle().theme == "warm" and UI.GetStyle().bg[1] == .2 and UI.IsOverride("talents"))
assert(profiles.Undo() and UI.GetStyle().theme == "modern")
options["Chaleureux"]()
assert(panel.backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" and UI.GetStyle().bg[1] == .12)
assert(profiles.Apply(assert(profiles.Preview("Modern theme", {appearance = true}))))
assert(panel.backdrop.edgeSize == 1 and UI.GetStyle().theme == "modern")
local modern = env.ForeverTooltipLibreDB.profiles["Modern theme"]
modern.moduleVersions.appearance, modern.modules.appearance.border = 1, nil

borderButton.scripts.OnClick(borderButton)
options["Cadre d’infobulle"]()
assert(panel.backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" and panel.backdrop.edgeSize == 12)
options["Cadre Blizzard"]()
assert(panel.backdrop.edgeFile == "Interface\\DialogFrame\\UI-DialogBox-Border")
options["Trait simple"]()
local thickness = frames.ArkannsQOLCommon_borderSize
thickness.scripts.OnValueChanged(thickness, 3)
options["Chaleureux"]()
assert(panel.backdrop.edgeFile == "Interface\\Buttons\\WHITE8X8" and panel.backdrop.edgeSize == 3)
options["Sans bordure"]()
assert(panel.backdrop.edgeFile == nil and panel.backdrop.bgFile and not thickness.enabled)
assert(borderButton:GetText() == "Type de bordure : Sans bordure" and UI.IsOverride("talents"))
UI.Initialize(); UI.Refresh()
assert(UI.GetStyle().border == "none" and panel.backdrop.edgeFile == nil)
assert(profiles.Save("Borderless"))
assert(profiles.Apply(assert(profiles.Preview("Modern theme", {appearance = true}))))
assert(UI.GetStyle().border == "theme" and thickness.enabled and panel.backdrop.edgeSize == 1)
assert(profiles.Undo() and UI.GetStyle().border == "none")
options["Selon le thème"]()
assert(panel.backdrop.edgeFile == "Interface\\Tooltips\\UI-Tooltip-Border" and thickness.enabled)
local borderPlan = assert(profiles.Preview("Borderless", {appearance = true}))
assert(table.concat(borderPlan.changes, "\n"):find("Selon le thème > Sans bordure", 1, true))
assert(profiles.Apply(borderPlan) and panel.backdrop.edgeFile == nil)
local beforeReset = UI.ExportSettings()
beforeReset.grid, beforeReset.snap = false, false
UI.ImportSettings(beforeReset)
frames.ArkannsQOLCommonDefaults.scripts.OnClick()
assert(UI.GetStyle().border == "none", "Requesting a reset must leave appearance unchanged")
popup.callback()
local afterReset = UI.ExportSettings()
assert(afterReset.border == "theme" and afterReset.scale == 1)
assert(not afterReset.grid and not afterReset.snap and afterReset.pins.talents and afterReset.overrides.talents)
assert(ns.home.Refresh)
print("PASS: shared layout, responsive home and appearance, scoped reset, previews, and profiles")

-- Layout owns position only; commands remain effective while it is open.
settings.x, settings.y, settings.enabled = .75, .65, true
assert(UI.StartLayout("talents"))
frames.ArkannsQOLLayoutCenter.scripts.OnClick()
settings.enabled = false
UI.EndLayout(true)
assert(settings.x == .75 and settings.y == .65 and settings.enabled == false,
    "Cancelling layout preserves unrelated changes")
assert(UI.StartLayout("talents"))
frames.ArkannsQOLLayoutCenter.scripts.OnClick()
frames.ArkannsQOLInterfaceEvents.scripts.OnEvent(nil, "PLAYER_LOGOUT")
assert(settings.x == .75 and settings.y == .65, "Logout cancels unconfirmed layout positions")
assert(UI.StartLayout("talents"))
settings.enabled = true
UI.EndLayout(false)
assert(settings.enabled == true, "Applying untouched layout preserves unrelated changes")

-- Search uses settings labels, supports accents, and opens the owning category.
local function Category(id) return {GetID=function() return id end} end
ns.RegisterModule("tooltips",{label="Infobulles",category=function() return Category(3) end})
ns.RegisterModule("bags",{label="Sacs",category=function() return Category(4) end})
ns.RegisterModule("flights",{label="Temps de vol",category=function() return Category(10) end})
ns.RegisterModule("advanced",{label="Réglages avancés",category=function() return Category(5) end})
local advancedName
ns.AdvancedSettings={IsNative=function(name) return name=="nativeSetting" end,
    OpenSetting=function(name) advancedName=name end}
ns.AdvancedSettingsCatalog={
    {name="cameraZoomSpeed",label="Vitesse du zoom",help="Vitesse du zoom à la molette."},
    {name="nativeSetting",label="Option native"},
}
ns.profilesCategory,ns.diagnosticsCategory=Category(6),Category(7)
ns.modules.session.category=function() return Category(8) end
ns.modules.session.label="Journal de session"
local function JournalSetting(query, label)
    for _,entry in ipairs(UI.SearchSettings(query)) do
        if entry.label==ns.modules.session.label.." · "..ns.L(label) then
            entry.Open(); assert(opened==8); return
        end
    end
    error("Missing journal setting: "..query)
end
JournalSetting("journal theme", "Thème")
JournalSetting("journal disposition", "Disposition")
JournalSetting("journal historique", "Historique et progression")
local function FlightSetting(query, label)
    local matches=UI.SearchSettings(query)
    assert(#matches==1 and matches[1].label==ns.modules.flights.label.." · "..ns.L(label),
        "Flight settings must be searchable: "..query)
    matches[1].Open(); assert(opened==10, "Flight search opens its owning category")
end
assert(#UI.SearchSettings("Temps de vol")==3, "Index the flight category and both settings")
FlightSetting("Chronométrer les vols", "Chronométrer les vols")
FlightSetting("Exporter les durées", "Exporter les durées")
assert(#UI.SearchSettings("  ")==0)
local results=UI.SearchSettings("ÉCHELLE infobulles")
assert(#results==1 and results[1].label:find("Échelle",1,true))
assert(#UI.SearchSettings("echelle infobulles")==1, "Unaccented queries match accented labels")
results[1].Open(); assert(opened==3)
results=UI.SearchSettings("talents erreurs")
assert(#results==1); results[1].Open(); assert(opened==2)
assert(#UI.SearchSettings("nativeSetting")==0, "Native-only options stay in the game's menus")
results=UI.SearchSettings("cameraZoomSpeed")
assert(#results==1); results[1].Open(); assert(advancedName=="cameraZoomSpeed")
results=UI.SearchSettings("profils enregistrer")
assert(#results==1); results[1].Open(); assert(opened==6)
results=UI.SearchSettings("diagnostics trace")
assert(#results==1); results[1].Open(); assert(opened==7)
local search=frames.ArkannsQOLHomeSearch
local personHeading
for _,child in ipairs(homeScroll.child.children) do
    if child:GetText()=="Personnage" then personHeading=child end
end
assert(personHeading and personHeading:IsShown())
ns.home:SetWidth(320)
search:SetText("talents erreurs"); search.scripts.OnTextChanged()
local result=frames.ArkannsQOLHomeSearchResult1
assert(result:IsShown() and result:GetWidth()==270 and not card.parent:IsShown())
search.scripts.OnEnterPressed(); assert(opened==2)
search:SetText("zz-no-match"); search.scripts.OnTextChanged()
assert(not result:IsShown() and not card.parent:IsShown())
search.scripts.OnEscapePressed()
assert(search:GetText()=="" and card.parent:IsShown() and not result:IsShown())
assert(personHeading:IsShown(), "Escape restores the task groups")
for _,path in ipairs({"Locales/enUS-Core.lua","Locales/enUS-Advanced.lua","Locales/enUS-TalentsAuras.lua","Locales/enUS-Utilities.lua","Locales/enUS-SessionHistory.lua","Locales/enUS-Flights.lua"}) do Load(path) end
useEnglish=true
results=UI.SearchSettings("talents error")
assert(#results==1 and results[1].label:find("Error",1,true))
search:SetText("talents error"); search.scripts.OnTextChanged()
assert(result:GetText():find("Error",1,true))
frames.ArkannsQOLHomeSearchClear.scripts.OnClick()
assert(search:GetText()=="" and card.parent:IsShown())
assert(personHeading:IsShown(), "Clear restores the task groups")
ns.modules.session.label="Session Journal"
JournalSetting("journal theme", "Thème")
JournalSetting("journal layout", "Disposition")
JournalSetting("journal history", "Historique et progression")
ns.modules.flights.label=ns.L("Temps de vol")
assert(#UI.SearchSettings("Flight times")==3)
FlightSetting("Time flight paths", "Chronométrer les vols")
FlightSetting("Export durations", "Exporter les durées")
print("PASS: global settings search, accent folding, English labels, advanced navigation, and narrow results")

-- Legacy distance favorites remain usable after their settings page is merged.
useEnglish=false
local sharedCategory=Category(9)
ns.modules.tooltips.category=function() return sharedCategory end
ns.RegisterModule("distance",{label="Distance",category=function() return sharedCategory end})
local favorites=UI.ExportSettings()
favorites.pins.tooltips=nil; favorites.pins.distance=true
UI.ImportSettings(favorites)
local tooltipText
env.GameTooltip={SetOwner=function() end,SetText=function(_,value) tooltipText=value end,Show=function() end,
    GetOwner=function() return nil end}
UI.BuildHome(ns.home)
local merged=frames.ArkannsQOLHomeTooltips.parent
assert(not frames.ArkannsQOLHomeDistance, "The merged page has one home card")
local pin
for _,child in ipairs(merged.children) do if child.scripts.OnEnter then pin=child; break end end
pin.scripts.OnEnter(pin)
assert(tooltipText=="Retirer des favoris", "Inherited distance favorite has matching help")
pin.scripts.OnClick(pin)
assert(not UI.ExportSettings().pins.distance and not UI.ExportSettings().pins.tooltips)

-- Shared appearance offers a return only while visiting from a module.
assert(UI.OpenSettings("appearance",nil,"talents"))
panel.scripts.OnShow()
assert(frames.ArkannsQOLAppearanceBack:IsShown())
frames.ArkannsQOLAppearanceBack.scripts.OnClick()
assert(opened==2)
assert(UI.OpenSettings("appearance",nil,"talents"))
panel.scripts.OnHide(); panel.scripts.OnShow()
assert(not frames.ArkannsQOLAppearanceBack:IsShown(), "Native navigation clears an old return destination")
print("PASS: merged favorites and scoped shared-theme return")

-- Use the real window and bootstrap entry points with the existing frame simulation.
Load("Core/SettingsWindow.lua")
function methods:SetParent(parent) self.parent=parent end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetTextColor(...) self.color={...} end
function methods:SetResizeBounds(...) self.resizeBounds={...} end
function methods:SetResizable(value) self.resizable=value end
function methods:StartSizing(direction) self.sizing=direction end
function methods:StopMovingOrSizing() self.sizing=nil; self.moving=false end
function methods:Show()
    local before=self.shown
    self.shown=true
    if not before and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:SetSize(width,height)
    local changed=self.width~=width or self.height~=height
    self.width,self.height=width,height
    if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,width,height) end
end
local nativeCanvases={}
local function RegisterCanvas(_, canvas)
    local category=Category(#nativeCanvases+1)
    nativeCanvases[#nativeCanvases+1]=canvas
    return category
end
env.Settings.RegisterCanvasLayoutCategory=function(canvas) return RegisterCanvas(nil,canvas) end
env.Settings.RegisterCanvasLayoutSubcategory=RegisterCanvas
env.Settings.RegisterAddOnCategory=noop
env.Settings.OpenToCategory=function() error("Standalone navigation must not open Blizzard Settings") end
env.SettingsPanel=Frame(); env.SettingsPanel:Hide()
env.HideUIPanel=function(frame) frame:Hide() end
env.SlashCmdList={}
env.Minimap=Frame(); env.Minimap:SetSize(180,180)
function methods:GetSize() return self.width,self.height end
function methods:GetFrameLevel() return self.level or 1 end
methods.UnregisterEvent=noop
function methods:CreateMaskTexture() return Frame() end
methods.AddMaskTexture=noop
env.C_AddOns={GetAddOnMetadata=function() return nil end}
ns.SettingsState={Initialize=function() return true end}
local initializeInterface,initializeProfiles=ns.InitializeInterface,ns.InitializeProfiles
ns.InitializeInterface,ns.InitializeProfiles=nil,nil
Load("Core/Bootstrap.lua")
frames.ArkannsQOLBootstrapEvents.scripts.OnEvent(frames.ArkannsQOLBootstrapEvents,"ADDON_LOADED","QoLToolkit")
ns.InitializeInterface,ns.InitializeProfiles=initializeInterface,initializeProfiles
local root=ns.home
local categories={}
local panels={home=root,appearance=panel}
local pageLabels={talents="Builds de talents",session="Journal de session",reminders="Rappels d'effets",ranks="Rangs de sorts",
    tooltips="Infobulles et distance",targetPortrait="Portrait de la cible",bags="Sacs",advanced="Réglages avancés",
    appearance="Apparence générale",profiles="Profils",diagnostics="Diagnostics"}
for _,id in ipairs({"talents","session","reminders","ranks","tooltips","targetPortrait","bags","advanced","appearance","profiles","diagnostics"}) do
    panels[id]=panels[id] or Frame()
    panels[id]:Hide()
    local destination=id
    categories[id]=UI.RegisterSettingsPanel({},panels[id],pageLabels[id],id)
    ns.RegisterModule(id,{label=id,category=function() return categories[destination] end})
end
-- The distance module shares the tooltip canvas in the real addon.
ns.RegisterModule("distance",{label="Distance",category=function() return categories.tooltips end,
    OpenSettings=function() panels.tooltips.distanceSelected=true end})
env.UIParent:SetSize(1400,900)
frames.ArkannsQOLMinimapButton.scripts.OnClick()
local settingsWindow=assert(frames.ArkannsQOLSettingsWindow)
assert(settingsWindow:GetWidth()==1180 and settingsWindow:GetHeight()==780,
    "The initial settings window uses available desktop width and height")
env.UIParent:SetSize(1000,800); UI.FitSettingsWindow()
assert(settingsWindow:IsShown() and root:IsShown() and not env.SettingsPanel:IsShown())
assert(root.parent.parent==settingsWindow and settingsWindow.resizable and settingsWindow.resizeBounds[1]==600)
local navigation=frames.ArkannsQOLSettingsNavigation
assert(navigation:IsShown() and not panels.talents:IsShown())
assert(frames.ArkannsQOLSettingsSubTab_talents:IsShown()
    and frames.ArkannsQOLSettingsSubTab_bags:IsShown(),"Every subsection is directly reachable in the sidebar")
assert(frames.ArkannsQOLSettingsTab_character:IsShown())
frames.ArkannsQOLSettingsTab_character.scripts.OnClick()
assert(panels.talents:IsShown() and not root:IsShown())
assert(frames.ArkannsQOLSettingsSubTab_talents.marker:IsShown() and not frames.ArkannsQOLSettingsSubTab_talents.enabled)
local mainTab=frames.ArkannsQOLSettingsTab_character
local subTab=frames.ArkannsQOLSettingsSubTab_talents
for _,tab in ipairs({mainTab,subTab}) do
    local style=UI.GetStyle()
    for i=1,3 do
        assert(tab.label.color[i]==style.accent[i] and tab.marker.color[i]==style.accent[i])
    end
    assert(tab.background.color[4]==.16)
    assert(not tab.normal,"Flat navigation tabs must not use the themed button artwork")
end
assert(subTab:GetWidth()==frames.ArkannsQOLSettingsSubTab_session:GetWidth(),"Navigation rows share one width")
frames.ArkannsQOLSettingsSubTab_session.scripts.OnClick()
assert(panels.session:IsShown() and not panels.talents:IsShown())
assert(subTab.background.color[4]==.035 and subTab.label.color[2]==UI.GetStyle().text[2] and not subTab.marker:IsShown())
frames.ArkannsQOLSettingsTab_interface.scripts.OnClick()
assert(panels.tooltips:IsShown() and not panels.session:IsShown())
frames.ArkannsQOLSettingsTab_character.scripts.OnClick()
assert(panels.session:IsShown(),"Returning to a group keeps its selected subsection")
assert(UI.OpenSettings("distance") and panels.tooltips.distanceSelected and panels.tooltips:IsShown())
assert(not frames.ArkannsQOLSettingsSubTab_distance,"The merged distance page has no duplicate tab")
-- Approximate wrapping for both shipped languages; the client still owns glyph metrics.
local nativeHeight=methods.GetStringHeight
function methods:GetStringHeight()
    local available=self.parent and self.points.TOPRIGHT and self.parent:GetWidth()-24 or self:GetWidth()
    return math.max(12,math.ceil(self:GetUnboundedStringWidth()/math.max(1,available))*12)
end
for _,english in ipairs({false,true}) do
    for id,label in pairs(pageLabels) do
        frames["ArkannsQOLSettingsSubTab_"..id].label:SetText(english and (ns.English[label] or label) or label)
    end
    settingsWindow:SetSize(980,740)
    UI.RefreshSettingsWindow()
    for id in pairs(pageLabels) do
        local button=frames["ArkannsQOLSettingsSubTab_"..id]
        if button:IsShown() then
            assert(button:GetHeight()>=button.label:GetStringHeight()+10,"Localized sidebar labels fit their click target")
            assert(button.points.TOPLEFT[1]+button:GetWidth()<=navigation.child:GetWidth())
        end
    end
    settingsWindow:SetSize(600,480)
    for _,id in ipairs({"tooltips","targetPortrait","bags"}) do
        local button=frames["ArkannsQOLSettingsSubTab_"..id]
        assert(button:GetHeight()>=button.label:GetStringHeight()+12,"Localized compact labels fit their tab")
    end
end
methods.GetStringHeight=nativeHeight
for id,label in pairs(pageLabels) do frames["ArkannsQOLSettingsSubTab_"..id].label:SetText(label) end
settingsWindow:SetSize(980,740)
assert(UI.OpenSettings("appearance",nil,"talents"))
assert(frames.ArkannsQOLAppearanceBack:IsShown())
frames.ArkannsQOLAppearanceBack.scripts.OnClick()
assert(panels.talents:IsShown())
settingsWindow:SetSize(600,480)
assert(panels.talents:GetWidth()==576 and panels.talents:GetHeight()>200)
assert(not navigation:IsShown() and mainTab:IsShown() and subTab.parent==settingsWindow,
    "Compact navigation releases sidebar width and reparents its visible buttons")
for _,id in ipairs({"talents","session","reminders","ranks"}) do
    local button=frames["ArkannsQOLSettingsSubTab_"..id]
    assert(button.points.TOPLEFT[1]+button:GetWidth()<=settingsWindow:GetWidth()-16)
end
local compactHeight=panels.talents:GetHeight()
settingsWindow:SetSize(980,740)
assert(navigation:IsShown() and subTab.parent==navigation.child and mainTab:IsShown())
assert(panels.talents:GetWidth()>=600 and panels.talents:GetHeight()>compactHeight,
    "Wide navigation leaves useful canvas width and removes stacked tab rows")
-- Short windows scroll the complete navigation and reveal the selected destination.
settingsWindow:SetSize(980,480)
navigation:SetVerticalScroll(900)
UI.RefreshSettingsWindow()
assert(navigation:GetVerticalScroll()<=math.max(0,navigation.child:GetHeight()-navigation:GetHeight()))
assert(navigation.child:GetHeight()>navigation:GetHeight(), "All destinations remain available in short sidebars")
navigation:SetVerticalScroll(0)
navigation.child.top=1000
frames.ArkannsQOLSettingsSubTab_diagnostics.top=400
frames.ArkannsQOLSettingsSubTab_diagnostics.scripts.OnClick()
assert(panels.diagnostics:IsShown() and not panels.talents:IsShown())
assert(navigation:GetVerticalScroll()>0,"Opening the last destination reveals its navigation row")
navigation:SetVerticalScroll(0); UI.RefreshSettingsWindow()
assert(navigation:GetVerticalScroll()==0,"Theme refresh does not pull the sidebar away from the user's scroll position")
for _,theme in ipairs({"modern","blizzard","warm"}) do
    local value=UI.ExportSettings(); value.theme=theme; value.accent={.3,.6,.9}; value.text={.8,.85,.95}
    UI.ImportSettings(value)
    local tab=frames.ArkannsQOLSettingsSubTab_diagnostics
    assert(tab.label.color[1]==.3 and tab.marker.color[3]==.9,
        "Theme changes refresh navigation along with its canvas")
end
frames.ArkannsQOLSettingsSearch.scripts.OnClick()
local searchLayer=frames.ArkannsQOLSettingsSearchPanel
local query=frames.ArkannsQOLSettingsQuery
assert(panels.diagnostics:IsShown() and searchLayer:IsShown() and query.focused,
    "Global search opens above the current page without a trip through Home")
query:SetText("talents"); query.scripts.OnTextChanged()
assert(frames.ArkannsQOLSettingsResult1:IsShown())
query.scripts.OnEscapePressed()
assert(not searchLayer:IsShown() and panels.diagnostics:IsShown(),"Escape returns to the unchanged page")
frames.ArkannsQOLSettingsSearch.scripts.OnClick()
assert(query:GetText()=="talents","Search preserves its query for repeated lookups")
frames.ArkannsQOLSettingsResult1.scripts.OnClick()
assert(panels.talents:IsShown() and not searchLayer:IsShown(),"Search opens the exact destination and closes its overlay")
frames.ArkannsQOLSettingsSearch.scripts.OnClick()
query:SetText("minicarte"); query.scripts.OnTextChanged()
query.scripts.OnEnterPressed()
assert(root:IsShown() and not searchLayer:IsShown(),"Minimap search reaches its Home control from any module")
assert(UI.OpenSettings("talents"))
settingsWindow:SetSize(600,480)
frames.ArkannsQOLSettingsResize.scripts.OnMouseDown(nil,"LeftButton")
assert(settingsWindow.sizing=="BOTTOMRIGHT")
frames.ArkannsQOLSettingsResize.scripts.OnMouseUp()
assert(not settingsWindow.sizing)
env.UIParent:SetSize(560,420)
UI.FitSettingsWindow()
assert(settingsWindow:GetWidth()==536 and settingsWindow:GetHeight()==396)
env.UIParent:SetSize(344,360)
UI.FitSettingsWindow()
assert(settingsWindow:GetWidth()==320 and not frames.ArkannsQOLSettingsSearch:IsShown(),
    "Very narrow headers reserve room for the title and close button")
assert(frames.ArkannsQOLSettingsTab_home:IsShown(),"Global search stays reachable through Home on very narrow windows")
env.UIParent:SetSize(1000,800)
env.GameTooltip=nil
local previewRunning=false
for _,key in ipairs({"frame","GetPosition","SetPosition","ExportSettings","ImportSettings"}) do ns.modules.talents[key]=module[key] end
ns.modules.talents.Preview=function() previewRunning=true; return true end
ns.modules.talents.StopPreview=function() previewRunning=false end
assert(UI.PreviewModule("talents") and previewRunning)
frames.ArkannsQOLSettingsClose.scripts.OnClick()
assert(not settingsWindow:IsShown() and not panels.talents:IsShown() and not previewRunning)
assert(env.UISpecialFrames[#env.UISpecialFrames]=="ArkannsQOLSettingsWindow","Escape owns the standalone window")
env.SlashCmdList.ARKANNSQOL()
assert(settingsWindow:IsShown() and root:IsShown(),"The slash command reopens the same window at home")
assert(UI.OpenSettings("talents") and UI.StartLayout("talents"))
assert(not settingsWindow:IsShown(),"Moving a module hides the settings window")
frames.ArkannsQOLLayoutApply.scripts.OnClick()
assert(settingsWindow:IsShown() and panels.talents:IsShown(),"Applying layout returns to the module in the same window")
combat=true
assert(UI.OpenSettings("bags") and panels.bags:IsShown(),"Opening an owned settings canvas remains available in combat")
combat=false
local sourceSeen
ns.modules.bags.OpenSettings=function(source) sourceSeen=source; assert(panels.bags:IsShown()) end
assert(UI.OpenSettings("bags","Halo intérieur") and sourceSeen=="Halo intérieur")
assert(not UI.OpenCategory({}) and not UI.OpenSettings("missing"))
assert(UI.OpenSettings("advanced"))
settingsWindow:Hide()
assert(not panels.advanced:IsShown(),"Closing the window hides its active canvas")
env.SettingsPanel:Show()
local launcher=nativeCanvases[#nativeCanvases]
launcher.children[#launcher.children].scripts.OnClick()
assert(settingsWindow:IsShown() and panels.diagnostics:IsShown() and not env.SettingsPanel:IsShown(),
    "The Blizzard entry launches the same canvas in the standalone window")
print("PASS: settings sidebar and compact tabs, themed navigation, global search, shared distance, resize, close, and native launcher")
