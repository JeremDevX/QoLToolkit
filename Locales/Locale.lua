local _, ns = ...
local french = type(GetLocale) == "function" and GetLocale() == "frFR"

ns.English = {}

-- French source text is also the fallback for missing translations.
function ns.L(text, key)
    if french then return text end
    return ns.English[key or text] or text
end
