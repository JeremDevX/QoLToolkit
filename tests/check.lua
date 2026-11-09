local manifest = assert(io.open("QoLToolkit.toc", "r"))
local chunks, catalogs = {}, {}
local firstRuntimeFile, lastFile
for line in manifest:lines() do
    local path = line:match("^%s*([^#].-%.lua)%s*$")
    if path then
        path = path:gsub("\\", "/")
        assert(not chunks[path], "Duplicate manifest entry: " .. path)
        chunks[path] = assert(loadfile(path))
        if path:match("^Locales/") then
            assert(not firstRuntimeFile, "Locale file loaded after runtime code: " .. path)
            catalogs[#catalogs + 1] = path
        else
            firstRuntimeFile = firstRuntimeFile or path
        end
        lastFile = path
    end
end
manifest:close()
assert(catalogs[1] == "Locales/Locale.lua", "Load the locale selector before translations")
assert(lastFile == "Core/Bootstrap.lua", "Load bootstrap after the modules")

local function CheckLocale(locale, expected)
    GetLocale = locale and function() return locale end or nil
    local ns = {}
    chunks[catalogs[1]]("QoLToolkit", ns)
    local entries = {}
    ns.English = setmetatable({}, {
        __index = entries,
        __newindex = function(_, key, value)
            assert(type(key) == "string" and type(value) == "string" and value ~= "",
                "Invalid locale entry")
            assert(not entries[key] or entries[key] == value, "Conflicting translations: " .. key)
            entries[key] = value
        end,
    })
    for i = 2, #catalogs do
        chunks[catalogs[i]]("QoLToolkit", ns)
    end
    assert(ns.L("Infobulles") == expected, "Unexpected client language")
    assert(ns.L("Annuler", "talent.undo") == (locale == "frFR" and "Annuler" or "Undo"))
    assert(ns.L("Untranslated example") == "Untranslated example", "Missing translation should use source text")
end

CheckLocale("frFR", "Infobulles")
CheckLocale("enUS", "Tooltips")
CheckLocale("enGB", "Tooltips")
CheckLocale("deDE", "Tooltips")
CheckLocale(nil, "Tooltips")
print("PASS: Lua syntax, manifest order, translations, and locale fallback")

local reminders = {}
chunks["Modules/AuraReminderModel.lua"]("QoLToolkit", reminders)
local model = reminders.AuraReminderModel
local settings = {
    auras = {
        {kind = "buff", name = "Mot de pouvoir : Robustesse", spellID = 21562},
        {kind = "aura", name = "Aura de devotion", spellID = 465},
        {kind = "buff", name = "Custom buff"},
    },
    tracking = {{name = "Decouverte de gisements", spellID = 2580}},
}
local observed = {
    buffsKnown = true, formsKnown = true,
    buffs = {[21562] = true, ["devotion aura"] = true, ["custom buff"] = true},
    forms = {[465] = {active = false}},
    tracking = {[2580] = {name = "Find Minerals", active = false}},
    resolveName = function(rule)
        if rule.spellID == 21562 then return "Power Word: Fortitude" end
        if rule.spellID == 465 then return "Devotion Aura" end
    end,
}
local missing = model.Missing(settings, observed)
assert(#missing == 2 and missing[1].name == "Devotion Aura" and missing[2].name == "Find Minerals")
observed.buffs = {["power word: fortitude"] = true, ["custom buff"] = true}
observed.forms[465].active = true
observed.tracking[2580].active = true
assert(#model.Missing(settings, observed) == 0, "Spell rank and manual name fallback")
observed.buffs = {}
observed.buffsKnown = false
assert(#model.Missing(settings, observed) == 0, "Unavailable aura data should stay silent")
print("PASS: cross-locale effect IDs, name fallback, and unavailable aura data")
