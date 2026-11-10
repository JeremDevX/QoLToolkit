-- Exercise the settings entry points without a client or native rendering.
local frames, writes, menu = {}, 0, nil
local methods = {}
local function Noop() end
function methods:SetScript(key, fn) self.scripts[key] = fn end
function methods:HookScript(key, fn)
    local before = self.scripts[key]
    self.scripts[key] = function(...) if before then before(...) end; fn(...) end
end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return rawget(self, "width") or 640 end
function methods:GetHeight() return rawget(self, "height") or 640 end
function methods:SetText(text) self.text = text end
function methods:GetText() return rawget(self, "text") or "" end
function methods:GetStringHeight() return 28 end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(value) self.enabled = not not value end
function methods:SetShown(value) self.shown = not not value end
function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown ~= false end
function methods:GetVerticalScroll() return rawget(self, "offset") or 0 end
function methods:SetVerticalScroll(value) self.offset = value end
function methods:SetScrollChild(child) self.child = child end
local function Create(kind, name, parent)
    local frame = setmetatable({kind = kind, name = name, parent = parent, scripts = {}}, {__index = function(_, key)
        if methods[key] then return methods[key] end
        if key:match("^[A-Z]") then return Noop end
    end})
    if kind == "CheckButton" then frame.Text = Create("FontString") end
    if name then frames[name] = frame end
    return frame
end
function methods:CreateFontString(name) return Create("FontString", name, self) end
function methods:CreateTexture(name) return Create("Texture", name, self) end
local values = {cameraZoomSpeed = "10", CMAA2Quality = "0"}
local env = setmetatable({
    ForeverTooltipLibreDB = {}, CreateFrame = Create, UIParent = {}, InCombatLockdown = function() return false end,
    Settings = {GetSetting = function() end, RegisterCanvasLayoutSubcategory = function(_, panel)
        return {GetID = function() return 1 end}
    end, OpenToCategory = function() frames.ArkannsQOLAdvancedPanel:Show() end},
    C_CVar = {GetCVarInfo = function(name)
        if values[name] then return values[name], "0", false, false, false, false, false end
    end, SetCVar = function(name, value) writes = writes + 1; values[name] = value; return true end},
    ConsoleGetAllCommands = function() return {{command = "cameraZoomSpeed", commandType = 0, help = "Camera"}} end,
    MenuUtil = {CreateContextMenu = function(_, build)
        menu = {}
        build(nil, {CreateButton = function(_, caption, callback) menu[caption] = callback end})
    end},
}, {__index = _G})
local ns = {
    L = function(text) return text end,
    AdvancedNativeSettings = {},
    AdvancedSettingsCategories = {{id = "camera", label = "Caméra"}, {id = "graphics", label = "Graphismes"}},
    AdvancedSettingsCatalog = {
        {category = "camera", name = "cameraZoomSpeed", label = "Zoom", help = "Camera", kind = "number", min = 1, max = 50},
        {category = "graphics", name = "CMAA2Quality", label = "CMAA2", help = "Graphics", kind = "choice", group = "Image", choices = {{"0", "Faible"}, {"1", "Moyenne"}, {"2", "Élevée"}, {"3", "Ultra"}}},
    },
}
local chunk = assert(loadfile("Modules/AdvancedSettings.lua")); setfenv(chunk, env); chunk("QoLToolkit", ns)
ns.InitializeAdvancedSettings({})
local panel = frames.ArkannsQOLAdvancedPanel
panel:Show()
assert(not frames.ArkannsQOLAdvancedTab2.shown and not frames.ArkannsQOLAdvancedTab3, "Graphics require opt-in; inventory has no normal tab")
local expert = frames.ArkannsQOLAdvancedExpert
expert:SetChecked(true); expert.scripts.OnClick(expert)
assert(frames.ArkannsQOLAdvancedTab2.shown)
frames.ArkannsQOLAdvancedTab2.scripts.OnClick()
local row = frames.ArkannsQOLAdvancedRow1
assert(row.option.name == "CMAA2Quality")
row.choice.scripts.OnClick(row.choice)
assert(writes == 0 and menu.Ultra, "Opening choices must not apply intermediate values")
menu.Ultra()
assert(writes == 1 and values.CMAA2Quality == "3")
ns.AdvancedSettings.ToggleFavorite("cameraZoomSpeed")
ns.AdvancedSettings.ToggleFavorite("CMAA2Quality")
local favorites = frames.ArkannsQOLAdvancedFavorites
favorites.scripts.OnClick(favorites)
assert(frames.ArkannsQOLAdvancedTab1.enabled and frames.ArkannsQOLAdvancedTab2.enabled, "Favorites must not claim an active category")
frames.ArkannsQOLAdvancedTab1.scripts.OnClick()
assert(row.option.name == "cameraZoomSpeed" and not frames.ArkannsQOLAdvancedRow2.shown, "Choosing a category leaves global favorites")
ns.OpenAdvancedInventory()
assert(not frames.ArkannsQOLAdvancedTab1.shown and frames.ArkannsQOLAdvancedReturn.shown)
assert(row.option == nil and not row.choice.enabled and writes == 1, "Diagnostic inventory stays read-only")
frames.ArkannsQOLAdvancedReturn.scripts.OnClick()
assert(frames.ArkannsQOLAdvancedTab1.shown and not frames.ArkannsQOLAdvancedReturn.shown)
print("PASS: expert opt-in, explicit choices, favorites navigation, and read-only diagnostic inventory")
