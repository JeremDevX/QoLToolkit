local _, ns = ...
local L = ns.L
local api = {}
ns.SettingsState = api

local schemaKey = "_arkannsQOLSchema"
local stores = {
    ForeverTooltipLibreDB = {version = 1},
    ArkannsQOLRemindersDB = {version = 1},
    ArkannsQOLSessionDB = {version = 1},
    ArkannsQOLTalentsDB = {version = 1},
}

-- An unversioned save (including 3.1.6) starts at schema 0. Migrations edit only the draft they receive.
function api.RegisterMigration(variable, version, migrate)
    local store = assert(stores[variable])
    assert(type(version) == "number" and version % 1 == 0 and version > 0 and type(migrate) == "function")
    local step = store[version] or {}
    step[#step + 1] = migrate
    store[version] = step
    store.version = math.max(store.version, version)
end

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[key] = Copy(item, seen) end
    return result
end

function api.Initialize()
    local pending = {}
    for variable, store in pairs(stores) do
        local data = _G[variable]
        if type(data) ~= "table" then data = {} end
        local version = data[schemaKey]
        if version == nil then version = 0 end
        if type(version) ~= "number" or version % 1 ~= 0 or version < 0 or version > store.version then
            return false, L("Version des réglages non prise en charge. Utilise une version compatible de l’addon.")
        end
        if version < store.version then pending[variable] = {data = data, version = version} end
    end

    -- Stage every update before changing any saved variables.
    for variable, entry in pairs(pending) do
        local store = stores[variable]
        local ok = pcall(function()
            local draft = entry.data
            for version = entry.version + 1, store.version do
                if store[version] then
                    if draft == entry.data then draft = Copy(draft, {}) end
                    for _, migrate in ipairs(store[version]) do migrate(draft) end
                end
            end
            entry.data = draft
        end)
        if not ok then return false, L("Impossible de mettre à jour les réglages. Les données enregistrées sont intactes.") end
    end

    for variable, entry in pairs(pending) do
        entry.data[schemaKey] = stores[variable].version
        _G[variable] = entry.data
    end
    return true
end
