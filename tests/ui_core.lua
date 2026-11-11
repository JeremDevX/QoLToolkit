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
function methods:HookScript(key, callback) self.scripts[key] = callback end
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
function methods:GetScale() return 1 end
methods.GetEffectiveScale = methods.GetScale
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
ns.home=Frame(); ns.home:SetSize(400,600)
ns.InitializeInterface({})
local panel=frames.ArkannsQOLCommonAppearance
panel:SetSize(400,600)
panel.scripts.OnShow()
local scroll=frames.ArkannsQOLCommonTheme.parent.parent
local collapsedHeight=scroll.child:GetHeight()
assert(frames.ArkannsQOLCommon_fontSize:IsShown() and frames.ArkannsQOLCommonPreview:IsShown())
assert(not frames.ArkannsQOLCommonBorder:IsShown(), "Border type belongs with its advanced adjustments")
assert(not frames.ArkannsQOLCommon_borderSize:IsShown(),"Detailed appearance starts collapsed")
frames.ArkannsQOLCommonAdvanced.scripts.OnClick()
assert(frames.ArkannsQOLCommon_borderSize:IsShown())
assert(frames.ArkannsQOLCommon_borderSize:GetWidth()<=350,"Appearance controls fit a narrow panel")
panel:SetWidth(619); panel.scripts.OnSizeChanged()
local scale, opacity=frames.ArkannsQOLCommon_scale, frames.ArkannsQOLCommon_opacity
assert(scale.points.TOPLEFT[2]>opacity.points.TOPLEFT[2])
local oneColumnHeight=scroll.child:GetHeight()
panel:SetWidth(620); panel.scripts.OnSizeChanged()
assert(scale.points.TOPLEFT[2]==opacity.points.TOPLEFT[2] and opacity.points.TOPLEFT[1]>scale.points.TOPLEFT[1])
assert(scroll.child:GetHeight()<oneColumnHeight)
scroll:SetHeight(400); scroll:SetVerticalScroll(250)
frames.ArkannsQOLCommonAdvanced.scripts.OnClick()
assert(scroll:GetVerticalScroll()==0 and scroll.child:GetHeight()==collapsedHeight)
assert(not frames.ArkannsQOLCommonColor_bg:IsShown())
frames.ArkannsQOLCommonAdvanced.scripts.OnClick()
local appearance=UI.ExportSettings(); appearance.pins.talents=true; UI.ImportSettings(appearance)
local card=frames.ArkannsQOLHomeTalents
card.scripts.OnClick()
assert(opened==2)
local homeScroll=frames.ArkannsQOLHomeScroll
local favoriteOpened
for _, button in ipairs(homeScroll.child.children) do
    if button:GetText()==module.label then
        opened=nil; button.scripts.OnClick(); favoriteOpened=opened
        break
    end
end
assert(favoriteOpened==2 and card.parent.parent==homeScroll.child)
ns.home:SetWidth(589); ns.home.Refresh()
local journal=frames.ArkannsQOLHomeSession.parent
assert(journal.points.TOPLEFT[2]>card.parent.points.TOPLEFT[2])
local narrowHomeHeight=homeScroll.child:GetHeight()
ns.home:SetWidth(590); ns.home.Refresh()
assert(journal.points.TOPLEFT[2]==card.parent.points.TOPLEFT[2] and card.parent.points.TOPLEFT[1]>0)
assert(homeScroll.child:GetHeight()<narrowHomeHeight)
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
local modulesHeading
for _,child in ipairs(homeScroll.child.children) do
    if child:GetText()=="Modules" then modulesHeading=child end
end
assert(modulesHeading and modulesHeading:IsShown())
ns.home:SetWidth(320)
search:SetText("talents erreurs"); search.scripts.OnTextChanged()
local result=frames.ArkannsQOLHomeSearchResult1
assert(result:IsShown() and result:GetWidth()==270 and not card.parent:IsShown())
search.scripts.OnEnterPressed(); assert(opened==2)
search:SetText("zz-no-match"); search.scripts.OnTextChanged()
assert(not result:IsShown() and not card.parent:IsShown())
search.scripts.OnEscapePressed()
assert(search:GetText()=="" and card.parent:IsShown() and not result:IsShown())
assert(modulesHeading:IsShown(), "Escape restores the modules heading")
for _,path in ipairs({"Locales/enUS-Core.lua","Locales/enUS-Advanced.lua","Locales/enUS-TalentsAuras.lua","Locales/enUS-Utilities.lua"}) do Load(path) end
useEnglish=true
results=UI.SearchSettings("talents error")
assert(#results==1 and results[1].label:find("Error",1,true))
search:SetText("talents error"); search.scripts.OnTextChanged()
assert(result:GetText():find("Error",1,true))
frames.ArkannsQOLHomeSearchClear.scripts.OnClick()
assert(search:GetText()=="" and card.parent:IsShown())
assert(modulesHeading:IsShown(), "Clear restores the modules heading")
ns.modules.session.label="Session Journal"
JournalSetting("journal theme", "Thème")
JournalSetting("journal layout", "Disposition")
print("PASS: global settings search, accent folding, English labels, advanced navigation, and narrow results")
