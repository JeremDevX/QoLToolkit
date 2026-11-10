-- Exercise the shared editor outside WoW. Geometry checks do not replace visual QA.
local env = setmetatable({}, {__index = _G})
env._G = env
local frames, methods = {}, {}
local function noop() end
for _, key in ipairs({"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetTextColor", "SetFont",
    "SetJustifyH", "SetOrientation", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag", "SetMaxLetters",
    "SetAutoFocus", "RegisterForDrag", "SetClampedToScreen", "SetMovable", "SetVertexColor", "SetTexCoord",
    "SetColorTexture", "SetTexture", "SetAlpha", "RegisterEvent", "ClearFocus", "StartMoving", "StopMovingOrSizing"}) do
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
function methods:SetText(value) self.text=value end
function methods:GetText() return self.text or "" end
function methods:GetStringHeight() return 20 end
function methods:SetChecked(value) self.checked=value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled=value end
function methods:SetValue(value) self.value=value end
local function Frame(_, name, parent)
    local frame=setmetatable({scripts={},points={},shown=true,width=200,height=80,parent=parent},{__index=methods})
    if name then frames[name]=frame; env[name]=frame end
    return frame
end
function methods:CreateTexture() return Frame() end
function methods:CreateFontString() return Frame() end
function methods:GetFontString() self.fontString=self.fontString or Frame(); return self.fontString end
function methods:SetNormalTexture() self.normal=Frame() end
function methods:GetNormalTexture() return self.normal end
function methods:SetHighlightTexture() self.highlight=Frame() end
function methods:GetHighlightTexture() return self.highlight end
function methods:SetThumbTexture() self.thumb=Frame() end
function methods:GetThumbTexture() return self.thumb end
function methods:SetScrollChild(frame) self.child=frame end
env.CreateFrame=Frame
env.UIParent=Frame(); env.UIParent:SetSize(1000,800)
env.UISpecialFrames={}
env.ForeverTooltipLibreDB={}
local combat, message, popup = false
env.InCombatLockdown=function() return combat end
env.print=function(value) message=value end
env.StaticPopup_ShowGenericConfirmation=function(text,callback) popup={text=text,callback=callback} end
env.issecretvalue=function() return false end
local ns={L=function(text) return text end}
local function Load(path)
    local chunk = path=="Core/QOLInterface.lua" and QOL_UI_SOURCE and assert(loadstring(QOL_UI_SOURCE)) or assert(loadfile(path))
    setfenv(chunk,env)("QoLToolkit",ns)
end
Load("Core/WoWRuntime.lua"); Load("Core/QOLInterface.lua")
local UI=ns.UI
UI.Initialize()
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
env.Settings={RegisterCanvasLayoutSubcategory=function() return {GetID=function() return 1 end} end}
ns.home=Frame(); ns.home:SetSize(400,600)
ns.InitializeInterface({})
frames.ArkannsQOLCommonAppearance:SetSize(400,600)
frames.ArkannsQOLCommonAppearance.scripts.OnShow()
assert(not frames.ArkannsQOLCommon_borderSize:IsShown(),"Detailed appearance starts collapsed")
frames.ArkannsQOLCommonAdvanced.scripts.OnClick()
assert(frames.ArkannsQOLCommon_borderSize:IsShown())
assert(frames.ArkannsQOLCommon_borderSize:GetWidth()<=350,"Appearance controls fit a narrow panel")
local appearance=UI.ExportSettings(); appearance.pins.talents=true; UI.ImportSettings(appearance)
assert(ns.home.Refresh)
print("PASS: layout preservation, apply/cancel, preview refusal, layers, and confirmation")
