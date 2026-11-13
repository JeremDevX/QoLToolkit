local addonName, ns = ...
local L = ns.L
local WoW = ns.WoW
local db, panel, check, qualityCheck, transmogCheck, status, category, homeCategory, refreshAppearance
local quick, quickBag, refreshQuick, ToggleQuickSettings
local merchantChecks, merchantEvents, merchantVisit, sellFailed, repairFailed
local coinListening, coinQueued, PaintSaleCoin, RefreshSaleCoins, QueueSaleCoinRefresh
local saleCoins = {}
local saleCoinEvents = {"GET_ITEM_INFO_RECEIVED", "ITEM_LOCK_CHANGED", "BAG_SLOT_FLAGS_UPDATED"}
local function HideSaleCoins(coins)
    if not coins then return end
    for _, coin in ipairs(coins) do coin:Hide() end
end
local listening, bankOpen, failed, scheduled
local qualityListening, getQualityColor, appearanceQueued, reagentEvents, waitingForReagents
local transmogEvents, transmogQueued
local pending = {}
local qualityBorders, samples, shortcuts = {}, {}, {}
local transmogIcons = {}
local shortcutMargins = {}
local appearanceDefaults = {
    qualityBorders = true, qualityOpacity = 100, qualityThickness = 1,
    qualityInnerGlow = 0, transmogIcons = true,
}
local defaults = {enabled = false, autoSell = false, sellEquipment = false, autoRepair = false}
for key, value in pairs(appearanceDefaults) do defaults[key] = value end
local merchantOptions = {
    {"autoSell", "AutoSell", "Vendre les objets gris"},
    {"sellEquipment", "SellEquipment", "Inclure l’équipement gris"},
    {"autoRepair", "AutoRepair", "Réparation automatique"},
}
local borderTexture = "Interface\\Common\\WhiteIconFrame"
local glowTexture = "Interface\\Buttons\\WHITE8X8"
local newItemGlowAtlas = "bags-glow-white"
local maxThickness = 4
local glowDepth = 11
local borderQuarters = {
    {"TOPLEFT", "CENTER", 0, 0}, {"TOP", "RIGHT", 1, 0},
    {"LEFT", "BOTTOM", 0, 1}, {"CENTER", "BOTTOMRIGHT", 1, 1},
}
local transmogAtlas = "lootroll-icon-transmog"
local transmogRefreshEvents = {
    "ITEM_DATA_LOAD_RESULT", "ITEM_LOCK_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_ITEM_UPDATE", "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "TRANSMOG_COLLECTION_SOURCE_REMOVED", "TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED", "TRANSMOG_SOURCE_COLLECTABILITY_UPDATE",
}
local shortcutSize, shortcutRight = 24, -32
local titleRight = shortcutRight - shortcutSize - 4

local function ValidSetting(key, value, default)
    if type(default) == "boolean" then return type(value) == "boolean" end
    if type(value) ~= "number" or value % 1 ~= 0 then return false end
    if key == "qualityThickness" then return value >= 1 and value <= maxThickness end
    return value >= 0 and value <= 100
end

local function IsBorderCategory(quality, maximum)
    return quality == "quest" or quality == "reagent"
        or type(quality) == "number" and quality >= 0 and quality <= maximum and quality % 1 == 0
end

local function ValidColor(quality, hex)
    return IsBorderCategory(quality, 8) and type(hex) == "string" and hex:match("^%x%x%x%x%x%x$")
end

local function CopyColors(source)
    local colors = {}
    for quality, hex in pairs(source) do
        if ValidColor(quality, hex) then colors[quality] = hex end
    end
    return colors
end

local function CopyHidden(source)
    local hidden = {}
    if type(source) == "table" then
        for quality, value in pairs(source) do
            if IsBorderCategory(quality, 5) and value == true then hidden[quality] = true end
        end
    end
    return hidden
end

local function LegacyHidden(uncommonOnly, hidden)
    if uncommonOnly == true then
        hidden[0], hidden[1] = true, true
    else
        hidden[0], hidden[1] = nil, nil
    end
    return hidden
end

local function NormalizeSettings(value)
    if type(value) ~= "table" then value = {} end
    for key, default in pairs(defaults) do
        if not ValidSetting(key, value[key], default) then value[key] = default end
    end
    value.qualityGlow = nil
    if type(value.qualityHidden) ~= "table" then
        value.qualityHidden = LegacyHidden(value.qualityUncommonOnly, {})
    end
    value.qualityHidden = CopyHidden(value.qualityHidden)
    value.qualityUncommonOnly = nil
    value.qualityColors = CopyColors(type(value.qualityColors) == "table" and value.qualityColors or {})
    return value
end

if ns.SettingsState then
    local function Migrate(root)
        root.bagSort = NormalizeSettings(root.bagSort)
    end
    ns.SettingsState.RegisterMigration("ForeverTooltipLibreDB", 1, Migrate)
    ns.SettingsState.RegisterMigration("ForeverTooltipLibreDB", 2, Migrate)
    ns.SettingsState.RegisterMigration("ForeverTooltipLibreDB", 3, Migrate)
    ns.SettingsState.RegisterMigration("ForeverTooltipLibreDB", 4, Migrate)
end

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsPersonalBagID(bagID)
    return not Secret(bagID) and type(bagID) == "number" and bagID >= 0 and bagID <= NUM_TOTAL_BAG_FRAMES
end

local function IsPersonalBag(frame)
    if frame and frame == ContainerFrameCombinedBags then return true end
    if not frame or not frame.GetBagID or not NUM_TOTAL_BAG_FRAMES then return false end
    return IsPersonalBagID(frame:GetBagID())
end

local function QualityColor(quality)
    local hex = db.qualityColors[quality] or (quality == "reagent" and "36D9CA")
    if hex then return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 end
    if quality == "quest" then return 1, .82, 0 end
    local ok, r, g, b = pcall(getQualityColor, quality)
    if ok and not Secret(r) and not Secret(g) and not Secret(b)
        and type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
end

local function RestoreNativeBorder(regions, key)
    local native = regions[key]
    if not native then return end
    local alpha = native:GetAlpha()
    if not Secret(alpha) and alpha == 0 then native:SetAlpha(regions[key .. "Alpha"]) end
    regions[key], regions[key .. "Alpha"] = nil, nil
end

local function SuppressNativeBorder(regions, key, native)
    if regions[key] ~= native then RestoreNativeBorder(regions, key) end
    if not native or not native.GetAlpha or not native.SetAlpha then return end
    local alpha = native:GetAlpha()
    if WoW.IsFiniteNumber(alpha) and alpha ~= 0 then
        regions[key], regions[key .. "Alpha"] = native, alpha
        native:SetAlpha(0)
    end
end

local function RestoreNewItemGlow(regions)
    local glow = regions.newItemGlow
    if not glow then return end
    if WoW.ReadValue(glow.GetAtlas, glow) == newItemGlowAtlas then glow:SetAtlas(regions.newItemAtlas) end
    glow:SetVertexColor(1, 1, 1)
    regions.newItemGlow, regions.newItemAtlas = nil, nil
end

local function PaintNewItemGlow(button, regions, nativeUpdated)
    if not regions or not regions.r then return end
    local glow = button.NewItemTexture
    if Secret(glow) or not glow or WoW.ReadValue(glow.IsShown, glow) ~= true then
        return RestoreNewItemGlow(regions)
    end
    local atlas = WoW.ReadValue(glow.GetAtlas, glow)
    if type(atlas) ~= "string" or atlas == "" then return end
    if nativeUpdated or not regions.newItemGlow or atlas ~= newItemGlowAtlas then
        regions.newItemGlow, regions.newItemAtlas = glow, atlas
    end
    -- The native glow is already colored in the atlas. Tint the white artwork instead.
    if atlas ~= newItemGlowAtlas then glow:SetAtlas(newItemGlowAtlas) end
    glow:SetVertexColor(regions.r, regions.g, regions.b)
end

local function HideBorder(regions)
    if not regions then return end
    for _, outline in ipairs(regions.outlines) do outline:Hide() end
    if regions.glow then for _, strip in ipairs(regions.glow) do strip:Hide() end end
    RestoreNativeBorder(regions, "nativeBorder")
    RestoreNativeBorder(regions, "questBorder")
    RestoreNewItemGlow(regions)
    regions.r = nil
end

local function PaintBorder(button, regions, native, icon, r, g, b)
    local anchor = native or icon
    local atlas = native and WoW.ReadValue(native.GetAtlas, native)
    if type(atlas) ~= "string" or atlas == "" then atlas = nil end
    local file = native and WoW.ReadValue(native.GetTextureFileID, native)
    if not WoW.IsFiniteNumber(file) or file <= 0 then
        file = native and WoW.ReadValue(native.GetTexture, native)
    end
    if not (type(file) == "string" and file ~= "") and not (WoW.IsFiniteNumber(file) and file > 0) then
        file = borderTexture
    end
    local thickness = atlas and 1 or db.qualityThickness
    local parts = thickness == 1 and 1 or #borderQuarters
    -- Magnify the outer artwork within each quadrant so the same edge grows inward.
    local span = .5 / (1 + (thickness - 1) * .35)
    for index = 1, parts do
        local outline = regions.outlines[index]
        local created = not outline
        if created then
            outline = button:CreateTexture(nil, "OVERLAY", nil, 0)
            regions.outlines[index] = outline
        end
        if created or regions.borderAtlas ~= atlas or regions.borderFile ~= file or regions.thickness ~= thickness then
            if atlas and outline.SetAtlas then
                outline:SetAtlas(atlas)
            else
                outline:SetTexture(file)
                if thickness == 1 then
                    outline:SetTexCoord(0, 1, 0, 1)
                else
                    local _, _, right, bottom = unpack(borderQuarters[index])
                    local left, top = right * (1 - span), bottom * (1 - span)
                    outline:SetTexCoord(left, left + span, top, top + span)
                end
            end
        end
        if created or regions.borderAnchor ~= anchor or regions.thickness ~= thickness then
            local topLeft, bottomRight = "TOPLEFT", "BOTTOMRIGHT"
            if thickness ~= 1 then topLeft, bottomRight = unpack(borderQuarters[index], 1, 2) end
            outline:ClearAllPoints()
            outline:SetPoint("TOPLEFT", anchor, topLeft)
            outline:SetPoint("BOTTOMRIGHT", anchor, bottomRight)
        end
        outline:SetVertexColor(r, g, b, db.qualityOpacity / 100)
        outline:Show()
    end
    for index = parts + 1, #regions.outlines do regions.outlines[index]:Hide() end
    regions.borderAtlas, regions.borderFile, regions.borderAnchor = atlas, file, anchor
    regions.thickness = thickness
end

local function PaintInnerGlow(button, regions, icon, r, g, b)
    local intensity = db.qualityInnerGlow
    if intensity == 0 or not CreateColor then
        if regions.glow then for _, strip in ipairs(regions.glow) do strip:Hide() end end
        return
    end
    if regions.glow == false then return end
    if not regions.glow then
        local strips = {}
        for index = 1, 4 do
            local strip = button:CreateTexture(nil, "ARTWORK", nil, -2)
            if not strip.SetGradient then regions.glow = false; return end
            strip:SetTexture(glowTexture)
            strip:SetBlendMode("BLEND")
            strips[index] = strip
        end
        strips[1]:SetHeight(glowDepth)
        strips[2]:SetHeight(glowDepth)
        strips[3]:SetWidth(glowDepth)
        strips[4]:SetWidth(glowDepth)
        regions.glow = strips
    end
    local top, bottom, left, right = unpack(regions.glow)
    if regions.glowAnchor ~= icon then
        top:SetPoint("TOPLEFT", icon, "TOPLEFT")
        top:SetPoint("TOPRIGHT", icon, "TOPRIGHT")
        bottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
        left:SetPoint("TOPLEFT", icon, "TOPLEFT")
        left:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
        right:SetPoint("TOPRIGHT", icon, "TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
        regions.glowAnchor = icon
    end
    if regions.glowIntensity ~= intensity or regions.glowR ~= r or regions.glowG ~= g or regions.glowB ~= b then
        -- Blend over bright and dark icons alike. Lift dark rarity colors for contrast.
        local red, green, blue = .2 + .8 * r, .2 + .8 * g, .2 + .8 * b
        local edge = CreateColor(red, green, blue, .95 * intensity / 100)
        local fade = CreateColor(red, green, blue, 0)
        top:SetGradient("VERTICAL", fade, edge)
        bottom:SetGradient("VERTICAL", edge, fade)
        left:SetGradient("HORIZONTAL", edge, fade)
        right:SetGradient("HORIZONTAL", fade, edge)
        regions.glowR, regions.glowG, regions.glowB = r, g, b
        regions.glowIntensity = intensity
    end
    local mask = WoW.ReadValue(icon.GetMaskTexture, icon, 1)
    for _, strip in ipairs(regions.glow) do
        if mask ~= regions.glowMask and strip.AddMaskTexture and strip.RemoveMaskTexture then
            if regions.glowMask then strip:RemoveMaskTexture(regions.glowMask) end
            if mask then strip:AddMaskTexture(mask) end
        end
        strip:Show()
    end
    regions.glowMask = mask
end

local function GetCraftingReagent(item)
    -- The Forever API returns isCraftingReagent in position 17.
    return (select(17, C_Item.GetItemInfo(item)))
end

local function BagBorderCategory(button, quality, item)
    if not WoW.IsFiniteNumber(quality) then return nil end
    local bagID = WoW.ReadValue(button.GetBagID, button)
    local slot = WoW.ReadValue(button.GetID, button)
    if IsPersonalBagID(bagID) and WoW.IsFiniteNumber(slot) and slot > 0 then
        local info = WoW.ReadValue(C_Container.GetContainerItemQuestInfo, bagID, slot)
        if type(info) == "table" then
            local hasQuestID = WoW.IsFiniteNumber(info.questID) and info.questID > 0
            if hasQuestID or WoW.IsPublic(info.isQuestItem) and info.isQuestItem == true then
                return "quest", not hasQuestID or WoW.IsPublic(info.isActive) and info.isActive == true
            end
        end
    end
    if C_Item and C_Item.GetItemInfo and WoW.IsPublic(item)
        and (type(item) == "string" and item ~= "" or WoW.IsFiniteNumber(item) and item > 0) then
        local state, reagent = WoW.Read(GetCraftingReagent, item)
        if state == "ok" and reagent == true then return "reagent" end
        if state == "ok" and reagent == nil then waitingForReagents = true end
    end
    return quality
end

local function PaintQualityBorder(button, quality, hasQuestBorder)
    if button.IsForbidden and button:IsForbidden() then return end
    local regions = qualityBorders[button]
    if not db.qualityBorders or Secret(quality) or not IsBorderCategory(quality, 5) or db.qualityHidden[quality] then
        return HideBorder(regions)
    end
    local r, g, b = QualityColor(quality)
    if not r then return HideBorder(regions) end
    if not regions then
        regions = {outlines = {}}
        qualityBorders[button] = regions
        if type(button.UpdateNewItem) == "function" then
            hooksecurefunc(button, "UpdateNewItem", function(self)
                PaintNewItemGlow(self, regions, true)
            end)
        end
    end
    local native = button.IconBorder
    if Secret(native) then native = nil end
    local icon = button.icon
    if Secret(icon) or not icon then icon = button.Icon end
    if Secret(icon) or not icon then icon = WoW.ReadValue(button.GetNormalTexture, button) end
    if Secret(icon) or not icon then icon = button end
    local questBorder = hasQuestBorder and button.IconQuestTexture or nil
    if Secret(questBorder) then questBorder = nil end
    SuppressNativeBorder(regions, "nativeBorder", native)
    SuppressNativeBorder(regions, "questBorder", questBorder)
    PaintBorder(button, regions, native, icon, r, g, b)
    PaintInnerGlow(button, regions, icon, r, g, b)
    regions.r, regions.g, regions.b = r, g, b
    PaintNewItemGlow(button, regions)
end

local function HasUncollectedAppearance(item)
    if Secret(item) or type(item) ~= "table" or Secret(item.isLocked) or item.isLocked ~= false then return false end
    local link = item.hyperlink
    if Secret(link) or type(link) ~= "string" or link == "" then return false end

    local collection = C_TransmogCollection
    if not collection then return false end
    local ok, appearanceID, sourceID = pcall(collection.GetItemInfo, link)
    if not ok or Secret(appearanceID) or type(appearanceID) ~= "number" or appearanceID <= 0
        or Secret(sourceID) or type(sourceID) ~= "number" or sourceID <= 0 then return false end

    local ready, hasItemData, canCollect = pcall(collection.PlayerCanCollectSource, sourceID)
    if not ready or Secret(hasItemData) or hasItemData ~= true or Secret(canCollect) or canCollect ~= true then return false end

    -- An appearance can already be collected from a different item source.
    local found, info = pcall(collection.GetAppearanceInfoBySource, sourceID)
    return found and not Secret(info) and type(info) == "table"
        and not Secret(info.appearanceID) and info.appearanceID == appearanceID
        and not Secret(info.appearanceIsCollected) and info.appearanceIsCollected == false
        and not Secret(info.sourceIsCollected) and info.sourceIsCollected == false
end

local function PaintTransmogIcon(button)
    local icon = transmogIcons[button]
    if button.IsForbidden and button:IsForbidden() then return end
    if button.GetBagID and button.GetID and button.CreateTexture then
        local bagID, slot = button:GetBagID(), button:GetID()
        if IsPersonalBagID(bagID) and not Secret(slot) and type(slot) == "number" and slot > 0 then
            local ok, item = pcall(C_Container.GetContainerItemInfo, bagID, slot)
            if ok and HasUncollectedAppearance(item) then
                if not icon then
                    icon = button:CreateTexture(nil, "OVERLAY", nil, 3)
                    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(transmogAtlas) and icon.SetAtlas then
                        icon:SetAtlas(transmogAtlas)
                    else
                        icon:SetTexture("Interface\\Icons\\INV_Shirt_01")
                    end
                    icon:SetSize(14, 14)
                    icon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -2)
                    transmogIcons[button] = icon
                    if button.HookScript then button:HookScript("OnHide", function() icon:Hide() end) end
                end
                icon:Show()
                return
            end
        end
    end
    if icon then icon:Hide() end
end

local function RefreshTransmogIcons()
    for _, icon in pairs(transmogIcons) do icon:Hide() end
    if not transmogEvents or not db.transmogIcons then return end
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if (not frame.IsForbidden or not frame:IsForbidden()) and IsPersonalBag(frame) and frame.EnumerateValidItems then
            local visible = frame:IsVisible()
            if not Secret(visible) and visible then
                for _, button in frame:EnumerateValidItems() do PaintTransmogIcon(button) end
            end
        end
    end
end

local function QueueTransmogRefresh()
    if not transmogEvents or not db.transmogIcons or transmogQueued
        or not ContainerFrameUtil_GetShownFrameForID() then return end
    transmogQueued = true
    C_Timer.After(.05, function()
        transmogQueued = false
        RefreshTransmogIcons()
    end)
end

local function RefreshTransmogSetting()
    if transmogEvents then
        for _, event in ipairs(transmogRefreshEvents) do
            if db.transmogIcons then transmogEvents:RegisterEvent(event) else transmogEvents:UnregisterEvent(event) end
        end
    end
    RefreshTransmogIcons()
end

local function OnItemQuality(button, quality, item)
    local showQuality = qualityListening and db.qualityBorders
    local showTransmog = transmogEvents and db.transmogIcons
    local showCoin = coinListening and db.autoSell
    if not (showQuality or showTransmog or showCoin) or Secret(button) or not button or not button.GetParent or not button.CreateTexture then return end
    local frame = button.containerFrame or button:GetParent()
    if IsPersonalBag(frame) and (frame == ContainerFrameCombinedBags
        or ContainerFrameUtil_GetShownFrameForID(frame:GetBagID()) == frame) then
        if showQuality then PaintQualityBorder(button, BagBorderCategory(button, quality, item)) end
        if showTransmog then PaintTransmogIcon(button) end
        if showCoin then PaintSaleCoin(button) end
    else
        HideBorder(qualityBorders[button])
        if transmogIcons[button] then transmogIcons[button]:Hide() end
        HideSaleCoins(saleCoins[button])
    end
end

local function RefreshQualityBorders()
    if not qualityListening then return end
    waitingForReagents = false
    if not db.qualityBorders then
        for _, regions in pairs(qualityBorders) do HideBorder(regions) end
        return
    end
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if (not frame.IsForbidden or not frame:IsForbidden()) and IsPersonalBag(frame)
            and WoW.ReadValue(frame.IsVisible, frame) == true and frame.EnumerateValidItems then
            for _, button in frame:EnumerateValidItems() do
                local info = WoW.ReadValue(C_Container.GetContainerItemInfo, button:GetBagID(), button:GetID())
                if type(info) == "table" then
                    PaintQualityBorder(button, BagBorderCategory(button, info.quality, info.itemID))
                else
                    PaintQualityBorder(button)
                end
            end
        end
    end
end

local function RefreshSamples()
    for button, quality in pairs(samples) do PaintQualityBorder(button, quality) end
end

local function QueueQualityRefresh()
    if appearanceQueued then return end
    if not C_Timer or not C_Timer.After then return RefreshQualityBorders() end
    appearanceQueued = true
    C_Timer.After(.05, function()
        appearanceQueued = false
        RefreshQualityBorders()
    end)
end

local function PreviewAppearance()
    RefreshSamples()
    QueueQualityRefresh()
end

local function IsBankOpen()
    if bankOpen then return true end
    local personal = BankFrame and BankFrame:IsShown()
    local guild = GuildBankFrame and GuildBankFrame:IsShown()
    return Secret(personal) or personal or Secret(guild) or guild
end

local function Unavailable()
    if failed then return L("Tri suspendu jusqu’au rechargement de l’interface.") end
    if not listening or not C_Container or type(C_Container.SortBags) ~= "function" then
        return L("Tri automatique indisponible sur ce client.")
    end
end

local function CanAutoSell()
    return not sellFailed and C_Container and NUM_TOTAL_BAG_FRAMES
        and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo and C_Container.UseContainerItem
        and C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemPurchaseInfo
        and C_Container.GetBackpackSellJunkDisabled and C_Container.GetBagSlotFlag
        and GetCursorInfo and SpellIsTargeting and InRepairMode
        and C_Item and C_Item.IsEquippableItem and C_Item.GetItemGUID
        and ItemLocation and ItemLocation.CreateFromBagAndSlot
        and Enum and Enum.ItemQuality and Enum.ItemQuality.Poor
        and Enum.BagSlotFlags and Enum.BagSlotFlags.ExcludeJunkSell
end

local function CanAutoRepair()
    return not repairFailed and CanMerchantRepair and GetRepairAllCost and GetMoney and RepairAllItems
end

local function ShowSaleCoins()
    return coinListening and merchantEvents and db.autoSell and CanAutoSell()
end

local function RefreshMerchantChecks(checks)
    for index, option in ipairs(merchantOptions) do checks[index]:SetChecked(db[option[1]]) end
    local sell, repair = merchantEvents and CanAutoSell(), merchantEvents and CanAutoRepair()
    checks[1]:SetEnabled(not not sell)
    checks[2]:SetEnabled(not not (sell and db.autoSell))
    checks[3]:SetEnabled(not not repair)
    checks[1].label:SetText(L(sell and merchantOptions[1][3] or "Vente automatique indisponible"))
    checks[3].label:SetText(L(repair and merchantOptions[3][3] or "Réparation automatique indisponible"))
end

local function RefreshMerchantEvents()
    if not merchantEvents then return end
    local sell = db.autoSell and CanAutoSell()
    if merchantVisit and not sell then merchantVisit.items = nil end
    if sell or (db.autoRepair and CanAutoRepair()) then
        merchantEvents:RegisterEvent("MERCHANT_SHOW")
        merchantEvents:RegisterEvent("MERCHANT_CLOSED")
        merchantEvents:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")
        merchantEvents:RegisterEvent("ADDON_ACTION_BLOCKED")
        merchantEvents:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        for _, event in ipairs(saleCoinEvents) do
            if ShowSaleCoins() then merchantEvents:RegisterEvent(event) else merchantEvents:UnregisterEvent(event) end
        end
    else
        merchantVisit = nil
        merchantEvents:UnregisterAllEvents()
    end
end

local function Refresh()
    check:SetChecked(db.enabled)
    check:SetEnabled(not Unavailable())
    qualityCheck:SetChecked(db.qualityBorders)
    transmogCheck:SetChecked(db.transmogIcons)
    RefreshMerchantEvents()
    RefreshMerchantChecks(merchantChecks)
    RefreshSaleCoins()
    status:SetText(Unavailable() or "")
    if reagentEvents then
        if db.qualityBorders then reagentEvents:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        else reagentEvents:UnregisterEvent("ITEM_DATA_LOAD_RESULT") end
    end
    if refreshAppearance then refreshAppearance() end
    if panel.Layout then panel.Layout() end
    if refreshQuick and quick:IsShown() then refreshQuick() end
end

local function SetQualityBorders(value)
    db.qualityBorders = value
    Refresh()
    RefreshQualityBorders()
end

local function SetTransmogIcons(value)
    db.transmogIcons = value == true
    Refresh()
    RefreshTransmogSetting()
end

local function CreateMerchantChecks(parent, prefix)
    local checks = {}
    for index, option in ipairs(merchantOptions) do
        local key, name, label = unpack(option)
        checks[index] = ns.UI.Check(parent, prefix .. name, L(label), 0, 0, function(value)
            db[key] = value == true
            ns.UI.Refresh()
        end)
    end
    checks[3]:HookScript("OnEnter", function(self)
        if not GameTooltip or GameTooltip:IsForbidden() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L(merchantOptions[3][3]))
        GameTooltip:AddLine(L("Utilise l’argent du personnage."), 1, 1, 1)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end
    checks[3]:HookScript("OnLeave", HideTooltip)
    checks[3]:HookScript("OnHide", HideTooltip)
    return checks
end

local function CloseQuickSettings(frame)
    if quick and (not frame or frame == quickBag) then quick:Hide() end
end

local function OpenSettings(destination)
    CloseQuickSettings()
    if ns.StopAllPreviews then ns.StopAllPreviews() end
    if destination then ns.UI.OpenCategory(destination) end
end

local function ReadTitleRight(title, frame)
    if not title or not title.GetPointByName then return end
    local ok, point, relativeTo, relativePoint, x, y = pcall(title.GetPointByName, title, "TOPRIGHT")
    if ok and not Secret(point) and not Secret(relativeTo) and not Secret(relativePoint)
        and not Secret(x) and not Secret(y) and point == "TOPRIGHT" and relativeTo == frame
        and relativePoint == "TOPRIGHT" and type(x) == "number" and type(y) == "number" then return x, y end
end

local function HideShortcut(frame)
    CloseQuickSettings(frame)
    local button = shortcuts[frame]
    if not button then return end
    button:Hide()
    local margin = shortcutMargins[frame]
    shortcutMargins[frame] = nil
    if not margin or margin.title ~= frame.TitleContainer then return end
    local x, y = ReadTitleRight(margin.title, frame)
    if x == titleRight and y == margin.y then
        pcall(margin.title.SetPoint, margin.title, "TOPRIGHT", frame, "TOPRIGHT", margin.x, y)
    end
end

local function AttachShortcut(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
    if not IsPersonalBag(frame) then
        return HideShortcut(frame)
    end
    local button = shortcuts[frame]
    if not button then
        button = CreateFrame("Button", nil, frame)
        shortcuts[frame] = button
        button:SetSize(shortcutSize, shortcutSize)
        if frame.CloseButton then
            local closeArt = WoW.ReadValue(frame.CloseButton.GetNormalTexture, frame.CloseButton)
            button:SetPoint("RIGHT", closeArt or frame.CloseButton, "LEFT", -4, 0)
        else
            button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", shortcutRight, -3)
        end
        local getAtlas = C_Texture and C_Texture.GetAtlasInfo
        for _, state in ipairs({
            {button.SetNormalTexture, "Up"}, {button.SetPushedTexture, "Down"},
        }) do
            local texture = button:CreateTexture(nil, "BACKGROUND")
            texture:SetAllPoints(button)
            local atlas = "UI-DialogBox-Button-" .. state[2]
            if WoW.ReadValue(getAtlas, atlas) then
                texture:SetAtlas(atlas)
                texture:SetTextureSliceMargins(8, 7, 8, 7)
            else
                texture:SetTexture("Interface\\Buttons\\UI-Panel-Button-" .. state[2])
                texture:SetTexCoord(0, .625, 0, .6875)
            end
            state[1](button, texture)
        end
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        if WoW.ReadValue(getAtlas, "Gear") then
            icon:SetAtlas("Gear")
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
        end
        if WoW.ReadValue(getAtlas, "RedButton-Highlight") then
            button:SetHighlightAtlas("RedButton-Highlight", "ADD")
        else
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        end
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
            if not IsPersonalBag(frame) then return end
            if mouseButton == "RightButton" then OpenSettings(homeCategory) else ToggleQuickSettings(frame) end
            if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end)
        button:SetScript("OnEnter", function(self)
            if not GameTooltip or GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L("Réglages des sacs"))
            GameTooltip:AddLine(L("Clic gauche · Réglages rapides"), 1, 1, 1)
            GameTooltip:AddLine(L("Clic droit · Accueil de l’addon"), 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self)
            if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end)
        if frame.HookScript then
            frame:HookScript("OnHide", function() CloseQuickSettings(frame) end)
        end
    end
    local level = frame:GetFrameLevel()
    for _, region in pairs({frame.TitleContainer, frame.NineSlice, frame.CloseButton}) do
        if region.GetFrameLevel then
            local headerLevel = region:GetFrameLevel()
            if not Secret(headerLevel) and type(headerLevel) == "number" then level = math.max(level, headerLevel) end
        end
    end
    button:SetFrameLevel(level + 1)
    local title = frame.TitleContainer
    local x, y = ReadTitleRight(title, frame)
    if x and x > titleRight and pcall(title.SetPoint, title, "TOPRIGHT", frame, "TOPRIGHT", titleRight, y) then
        shortcutMargins[frame] = {title = title, x = x, y = y}
    end
    button:Show()
end

local sampleIcons = {
    "Interface\\Icons\\INV_Stone_01",
    "Interface\\Icons\\INV_Misc_Gem_Pearl_01",
    "Interface\\Icons\\INV_Misc_Gem_Emerald_01",
    "Interface\\Icons\\INV_Misc_Gem_Sapphire_01",
    "Interface\\Icons\\INV_Misc_Gem_Amethyst_01",
    "Interface\\Icons\\INV_Misc_Gem_Topaz_01",
}
local qualityLabels = {L("Médiocre"), L("Commun"), L("Peu commun"), L("Rare"), L("Épique"), L("Légendaire")}

local function ChooseColor(quality)
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
    local r, g, b = QualityColor(quality)
    if not r then return end
    local previous = db.qualityColors[quality]
    ColorPickerFrame:SetupColorPickerAndShow({
        r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = function()
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            db.qualityColors[quality] = string.format("%02X%02X%02X", math.floor(red * 255 + .5), math.floor(green * 255 + .5), math.floor(blue * 255 + .5))
            PreviewAppearance()
        end,
        cancelFunc = function()
            db.qualityColors[quality] = previous
            PreviewAppearance()
        end,
    })
end

local function BuildAppearance(body, compact)
    local UI = ns.UI
    local prefix = compact and "ArkannsQOLBagQuick" or "ArkannsQOLBag"
    local syncing
    local targets, checks, sliders, palette = {}, {}, {}, {}
    local function Slider(key, name, y)
        local isThickness = key == "qualityThickness"
        local label = UI.Label(body, "", 20, y)
        local slider = CreateFrame("Slider", prefix .. "_" .. key, body, "BackdropTemplate")
        slider:SetPoint("TOPLEFT", 18, y - 22)
        slider:SetSize(244, 16)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(isThickness and 1 or 0, isThickness and maxThickness or 100)
        slider:SetValueStep(isThickness and 1 or 5)
        slider:SetObeyStepOnDrag(true)
        slider:SetBackdrop({bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border", edgeSize = 8})
        slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
        slider:GetThumbTexture():SetSize(28, 28)
        local format = isThickness and "%s · %d" or L("%s · %d %%")
        local function Caption() label:SetText(format:format(name, db[key])) end
        Caption()
        slider:SetScript("OnValueChanged", function(_, value)
            if syncing then return end
            db[key] = math.floor(value + .5)
            Caption()
            PreviewAppearance()
        end)
        local source = ({qualityOpacity = "Opacité du contour", qualityThickness = "Épaisseur du contour", qualityInnerGlow = "Halo intérieur"})[key]
        targets[source] = slider
        sliders[#sliders + 1] = {label = label, control = slider}
        return function() slider:SetValue(db[key]); Caption() end
    end
    local opacity = Slider("qualityOpacity", L("Opacité du contour"), 0)
    local thickness = Slider("qualityThickness", L("Épaisseur du contour"), -56)
    local innerGlow = Slider("qualityInnerGlow", L("Halo intérieur"), -112)
    targets["Couleurs de rareté"] = UI.Label(body, L("Couleurs et aperçu"), 20, -162, 15)
    local toggleHelp = L("Cochez pour appliquer la couleur.")
    local help = UI.Label(body, toggleHelp, 20, -186)
    local size, top = 28, -210
    local categories = {0, 1, 2, 3, 4, 5, "quest", "reagent"}
    for index, quality in ipairs(categories) do
        local source = quality == "quest" and "Objets de quête" or quality == "reagent" and "Composants d’artisanat"
        local name = source and L(source) or _G["ITEM_QUALITY" .. quality .. "_DESC"] or qualityLabels[quality + 1]
        local x, y = 19 + ((index - 1) % 4) * 58, top - math.floor((index - 1) / 4) * 38
        local sample = CreateFrame("Button", prefix .. "Color" .. quality, body)
        sample:SetSize(size, size)
        sample:SetPoint("TOPLEFT", x, y)
        sample:SetNormalTexture(quality == "reagent" and "Interface\\Icons\\INV_Ore_Copper_01"
            or sampleIcons[type(quality) == "number" and quality + 1 or 2])
        sample:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        sample:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        sample:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                db.qualityColors[quality] = nil
                PreviewAppearance()
            else
                ChooseColor(quality)
            end
        end)
        local control = UI.Check(body, prefix .. "ShowColor" .. quality, "", x + size + 1, y - 2, function(value)
            db.qualityHidden[quality] = not value and true or nil
            Refresh()
            RefreshQualityBorders()
        end)
        control:SetSize(24, 24)
        local function Tooltip(self)
            if not GameTooltip or GameTooltip:IsForbidden() then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(name)
            GameTooltip:AddLine(self == control and toggleHelp or L("Clic gauche · Couleur\nClic droit · Couleur par défaut"), 1, 1, 1)
            GameTooltip:Show()
        end
        local function HideTooltip(self)
            if GameTooltip and not GameTooltip:IsForbidden() and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end
        for _, widget in ipairs({sample, control}) do
            widget:SetScript("OnEnter", Tooltip)
            widget:SetScript("OnLeave", HideTooltip)
            widget:SetScript("OnHide", HideTooltip)
        end
        if source then targets[source] = sample end
        checks[quality], samples[sample] = control, quality
        palette[#palette + 1] = {sample = sample, control = control}
    end
    local footerY = top - 76
    local reset
    if not compact then
        reset = UI.Button(body, "ArkannsQOLBagAppearanceDefaults", L("Apparence par défaut"), 18, footerY, 190, function()
            UI.Confirm(L("Rétablir les bordures de rareté et leurs couleurs par défaut ?"), function()
                for key, value in pairs(appearanceDefaults) do
                    if key ~= "transmogIcons" then db[key] = value end
                end
                db.qualityColors, db.qualityHidden = {}, {}
                Refresh()
                RefreshQualityBorders()
            end)
        end)
    end
    local function Layout(width)
        local gap = compact and 16 or 24
        local paired = width >= (compact and 450 or 560)
        local columnWidth = paired and (width - gap) / 2 or width
        local function Place(widget, x, y, available)
            widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", x, -y)
            if available then widget:SetWidth(available) end
        end
        local y = 0
        for _, field in ipairs(sliders) do
            Place(field.label, 0, y, columnWidth)
            local clearance = compact and 8 or 10
            field.control:ClearAllPoints()
            field.control:SetPoint("TOPLEFT", field.label, "BOTTOMLEFT", 4, -clearance)
            field.control:SetWidth(math.max(1, math.min(330, columnWidth - 8)))
            y = y + field.label:GetStringHeight() + clearance + (compact and 24 or 38)
        end
        local rightX, paletteY = paired and columnWidth + gap or 0, paired and 0 or y + 8
        local title = targets["Couleurs de rareté"]
        Place(title, rightX, paletteY, columnWidth)
        paletteY = paletteY + title:GetStringHeight() + 8
        Place(help, rightX, paletteY, columnWidth)
        paletteY = paletteY + help:GetStringHeight() + 12
        local columns = math.max(1, math.min(4, math.floor(columnWidth / 58)))
        for index, item in ipairs(palette) do
            local x = rightX + ((index - 1) % columns) * 58
            local rowY = paletteY + math.floor((index - 1) / columns) * 40
            Place(item.sample, x, rowY)
            Place(item.control, x + size + 1, rowY + 2)
        end
        paletteY = paletteY + math.ceil(#palette / columns) * 40
        local bottom = math.max(y, paletteY) + 8
        if reset then Place(reset, 0, bottom, math.min(220, width)) end
        body:SetSize(width, bottom + (reset and 38 or 0))
    end
    return function()
        syncing = true
        for quality, control in pairs(checks) do control:SetChecked(not db.qualityHidden[quality]) end
        opacity()
        thickness()
        innerGlow()
        syncing = false
        RefreshSamples()
    end, footerY, targets, Layout
end

local function SetEnabled(value)
    db.enabled = value == true
    if not db.enabled then pending = {} end
    ns.UI.Refresh()
end

local function CreateTransmogCheck(body, name, x, y)
    local label = transmogEvents and L("Transmos manquantes") or L("Transmo indisponible")
    local control = ns.UI.Check(body, name, label, x, y, SetTransmogIcons)
    if not transmogEvents then control:Disable() end
    return control
end

local function CreateQuickSettings()
    local UI = ns.UI
    local name = "ArkannsQOLBagQuickSettings"
    quick = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    quick:Hide()
    quick:SetFrameStrata("DIALOG")
    quick:SetClampedToScreen(true)
    quick:EnableMouse(true)
    quick:SetScript("OnHide", function(self)
        quickBag = nil
        self:ClearAllPoints()
    end)
    UI.StylePanel(quick)
    UI.Label(quick, L("Réglages des sacs"), 18, -14, 15)
    local close = CreateFrame("Button", name .. "Close", quick, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", quick, "TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() CloseQuickSettings() end)
    local sort = UI.Check(quick, "ArkannsQOLBagQuickSort", L("Tri à l’ouverture"), 0, 0, SetEnabled)
    local borders = UI.Check(quick, "ArkannsQOLBagQuickBorders", L("Contours de rareté"), 0, 0, SetQualityBorders)
    local transmog = CreateTransmogCheck(quick, "ArkannsQOLBagQuickTransmog", 0, 0)
    local merchantTitle = UI.Label(quick, L("À l’ouverture d’un marchand"), 0, 0, 15)
    local checks = CreateMerchantChecks(quick, "ArkannsQOLBagQuick")
    local appearance, refreshAppearanceControls, layoutAppearance
    if qualityListening then
        appearance = CreateFrame("Frame", nil, quick)
        local _, unusedTargets
        refreshAppearanceControls, _, unusedTargets, layoutAppearance = BuildAppearance(appearance, true)
    else
        borders:Disable()
        borders.label:SetText(L("Bordures indisponibles"))
    end
    local more = UI.Button(quick, "ArkannsQOLBagQuickMore", L("Tous les réglages"), 0, 0, 234,
        function() OpenSettings(category) end)
    local quickChecks = {sort, borders, transmog}
    local function Place(widget, x, y)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", x, -y)
    end
    refreshQuick = function()
        sort:SetChecked(db.enabled)
        sort:SetEnabled(not Unavailable())
        borders:SetChecked(db.qualityBorders)
        transmog:SetChecked(db.transmogIcons)
        RefreshMerchantChecks(checks)
        local screenWidth = WoW.ReadValue(UIParent.GetWidth, UIParent)
        local width = WoW.IsFiniteNumber(screenWidth) and math.min(524, math.max(270, screenWidth - 36)) or 524
        local contentWidth = width - 36
        local paired = contentWidth >= 450
        local columnWidth = paired and (contentWidth - 16) / 2 or contentWidth
        quick:SetWidth(width)
        local function PlaceCheck(control, x, y, inset)
            control:SetSize(24, 24)
            control.label:SetWidth(columnWidth - 26 - inset)
            Place(control, x + inset, y)
            return y + math.max(24, control.label:GetStringHeight() + 10)
        end
        local y = 36
        for _, control in ipairs(quickChecks) do y = PlaceCheck(control, 14, y, 0) end
        local rightX, rightY = paired and 14 + columnWidth + 16 or 14, paired and 36 or y + 7
        merchantTitle:SetWidth(columnWidth)
        Place(merchantTitle, rightX + 4, rightY)
        rightY = rightY + merchantTitle:GetStringHeight() + 5
        for index, control in ipairs(checks) do
            rightY = PlaceCheck(control, rightX, rightY, index == 2 and 12 or 0)
        end
        y = math.max(y, rightY) + 10
        if appearance then
            Place(appearance, 18, y)
            refreshAppearanceControls()
            layoutAppearance(contentWidth)
            y = y + appearance:GetHeight()
        end
        Place(more, (width - 234) / 2, y)
        quick:SetHeight(y + 40)
    end
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
end

ToggleQuickSettings = function(frame)
    if quickBag == frame and quick:IsShown() then return CloseQuickSettings() end
    if not quick then CreateQuickSettings() end
    quick:ClearAllPoints()
    quick:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, -2)
    quickBag = frame
    refreshQuick()
    quick:Show()
end

local function Suspend()
    if failed then return end
    failed = true
    ns.UI.Refresh()
end

local function CanSort()
    if not db.enabled or Unavailable() or IsBankOpen() then return false end
    local combat = InCombatLockdown()
    if Secret(combat) or combat then return false end
    local cursor = GetCursorInfo()
    local targeting = SpellCanTargetItem()
    return not Secret(cursor) and cursor == nil and not Secret(targeting) and not targeting
end

local function SortOpenedBags()
    local opened = pending
    pending, scheduled = {}, false
    if not CanSort() then return end
    for frame, confirmed in pairs(opened) do
        local visible = frame:IsVisible()
        if confirmed and not Secret(visible) and visible and IsPersonalBag(frame) then
            if ns.Diagnostics then ns.Diagnostics.Note("bags.sort.request") end
            if not pcall(C_Container.SortBags) then Suspend() end
            return
        end
    end
end

local function OnBagOpened(_, frame)
    AttachShortcut(frame)
    if not IsPersonalBag(frame) then return end
    QueueTransmogRefresh()
    QueueSaleCoinRefresh()
    if not CanSort() then return end
    pending[frame] = false
    if not scheduled then
        scheduled = true
        C_Timer.After(0, SortOpenedBags)
    end
end

local function ConfirmBag(bagID)
    if Secret(bagID) or type(bagID) ~= "number" or bagID < 0 or bagID > NUM_TOTAL_BAG_FRAMES then return end
    if not next(pending) or not ContainerFrame_AllowedToOpenBags() then return end
    local frame = ContainerFrameUtil_GetShownFrameForID(bagID)
    if frame and pending[frame] ~= nil then pending[frame] = true end
end

local function ConfirmAllBags()
    if not next(pending) or not ContainerFrame_AllowedToOpenBags() then return end
    if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then
        -- The native gamepad command toggles only the combined backpack.
        ConfirmBag(0)
        return
    end
    for frame in pairs(pending) do pending[frame] = true end
end

local function MerchantIsReady(visit)
    if merchantVisit ~= visit or not MerchantFrame or IsBankOpen() then return false end
    local combatStatus, combat = WoW.Read(InCombatLockdown)
    local interaction = Enum.PlayerInteractionType.Merchant
    local tab = MerchantFrame.selectedTab
    return combatStatus == "ok" and not combat
        and WoW.ReadValue(C_PlayerInteractionManager.IsInteractingWithNpcOfType, interaction) == true
        and WoW.ReadValue(MerchantFrame.IsShown, MerchantFrame) == true and not Secret(tab) and tab == 1
end

local function RepairAtMerchant()
    if not db.autoRepair or not CanAutoRepair() or WoW.ReadValue(CanMerchantRepair) ~= true then return end
    local _, cost, canRepair = WoW.Read(GetRepairAllCost)
    if canRepair ~= true or not WoW.IsFiniteNumber(cost) or cost <= 0 then return end
    local money = WoW.ReadValue(GetMoney)
    if WoW.IsFiniteNumber(money) and cost <= money and WoW.Read(RepairAllItems) == "error" then
        repairFailed = true
        ns.UI.Refresh()
    end
end

local function BagAllowsSale(bag)
    if bag == 0 then return WoW.ReadValue(C_Container.GetBackpackSellJunkDisabled) == false end
    return WoW.ReadValue(C_Container.GetBagSlotFlag, bag, Enum.BagSlotFlags.ExcludeJunkSell) == false
end

local function ReadItemGUID(bag, slot)
    local location = WoW.ReadValue(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
    if location then return WoW.ReadValue(C_Item.GetItemGUID, location) end
end

local function GetSellableItem(bag, slot)
    local item = WoW.ReadValue(C_Container.GetContainerItemInfo, bag, slot)
    if type(item) ~= "table" or Secret(item.quality) or item.quality ~= Enum.ItemQuality.Poor
        or Secret(item.isLocked) or item.isLocked ~= false
        or Secret(item.hasNoValue) or item.hasNoValue ~= false
        or not WoW.IsFiniteNumber(item.itemID) or not WoW.IsFiniteNumber(item.stackCount) then return end

    local quest = WoW.ReadValue(C_Container.GetContainerItemQuestInfo, bag, slot)
    if type(quest) ~= "table" or Secret(quest.isQuestItem) or quest.isQuestItem ~= false
        or Secret(quest.questID) or quest.questID ~= nil then return end
    local purchaseStatus, purchase = WoW.Read(C_Container.GetContainerItemPurchaseInfo, bag, slot, false)
    if purchaseStatus ~= "ok" then return end
    if purchase ~= nil and (type(purchase) ~= "table"
        or Secret(purchase.money) or purchase.money ~= 0
        or Secret(purchase.itemCount) or purchase.itemCount ~= 0
        or Secret(purchase.currencyCount) or purchase.currencyCount ~= 0) then return end
    if not db.sellEquipment and WoW.ReadValue(C_Item.IsEquippableItem, item.itemID) ~= false then return end
    local guid = ReadItemGUID(bag, slot)
    if type(guid) == "string" and guid ~= "" then return guid, item end
end

local function ReadVendorPrice(item)
    return (select(11, C_Item.GetItemInfo(item)))
end

PaintSaleCoin = function(button)
    if button.IsForbidden and button:IsForbidden() then return end
    local coins = saleCoins[button]
    local bag = WoW.ReadValue(button.GetBagID, button)
    local slot = WoW.ReadValue(button.GetID, button)
    local price
    if ShowSaleCoins() and IsPersonalBagID(bag) and WoW.IsFiniteNumber(slot) and slot > 0 then
        local _, item = GetSellableItem(bag, slot)
        if item and BagAllowsSale(bag) and WoW.IsPublic(item.hyperlink) then
            local unitPrice = WoW.ReadValue(ReadVendorPrice, item.hyperlink or item.itemID)
            if WoW.IsFiniteNumber(unitPrice) then price = unitPrice * item.stackCount end
        end
    end
    if not WoW.IsFiniteNumber(price) or price <= 0 then return HideSaleCoins(coins) end

    if not coins then
        coins = {}
        for index = 1, 4 do
            local outline = index % 2 == 1
            local size = outline and 22 or 20
            local x = index <= 2 and -4 or 4
            local coin = button:CreateTexture(nil, "OVERLAY", nil, index + 2)
            coin:SetSize(size, size)
            coin:SetPoint("CENTER", button, "CENTER", x, -x * .75)
            if outline then coin:SetVertexColor(0, 0, 0, .85) end
            coins[index] = coin
        end
        saleCoins[button] = coins
        button:HookScript("OnHide", function() HideSaleCoins(coins) end)
    end
    local denomination = price >= 10000 and "Gold" or price >= 100 and "Silver" or "Copper"
    local atlas = "coin-" .. denomination:lower()
    local hasAtlas = C_Texture and WoW.ReadValue(C_Texture.GetAtlasInfo, atlas)
    for _, coin in ipairs(coins) do
        if hasAtlas then
            coin:SetAtlas(atlas)
            coin:Show()
        else
            coin:SetShown(coin:SetTexture("Interface\\MoneyFrame\\UI-" .. denomination .. "Icon") == true)
        end
    end
end

RefreshSaleCoins = function()
    if not ShowSaleCoins() then
        for _, coins in pairs(saleCoins) do HideSaleCoins(coins) end
        return
    end
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if (not frame.IsForbidden or not frame:IsForbidden()) and IsPersonalBag(frame)
            and WoW.ReadValue(frame.IsVisible, frame) == true and frame.EnumerateValidItems then
            for _, button in frame:EnumerateValidItems() do PaintSaleCoin(button) end
        end
    end
end

QueueSaleCoinRefresh = function()
    if coinQueued or not ShowSaleCoins() or not ContainerFrameUtil_GetShownFrameForID() then return end
    coinQueued = true
    C_Timer.After(0, function()
        coinQueued = false
        if ContainerFrameUtil_GetShownFrameForID() then RefreshSaleCoins() end
    end)
end

local function SellNextItem(visit)
    if not MerchantIsReady(visit) or not visit.items or not db.autoSell or not CanAutoSell() then return end
    local cursorStatus, cursor = WoW.Read(GetCursorInfo)
    local spellStatus, targeting = WoW.Read(SpellIsTargeting)
    local repairStatus, repairing = WoW.Read(InRepairMode)
    if cursorStatus ~= "ok" or cursor ~= nil or spellStatus ~= "ok" or targeting
        or repairStatus ~= "ok" or repairing then return end
    if visit.previous then
        local previous = visit.previous
        local status, item = WoW.Read(C_Container.GetContainerItemInfo, previous.bag, previous.slot)
        if status ~= "ok" then return end
        if item ~= nil then
            local guid = ReadItemGUID(previous.bag, previous.slot)
            if type(guid) ~= "string" then return end
            if guid == previous.guid then
                -- Wait for the sale to reach the bags. A refused sale is never retried.
                visit.waits = visit.waits + 1
                if visit.waits < 10 then C_Timer.After(.25, function() SellNextItem(visit) end)
                else visit.items = nil end
                return
            end
        end
        visit.previous = nil
    end
    while visit.index <= #visit.items do
        local item = visit.items[visit.index]
        visit.index = visit.index + 1
        if BagAllowsSale(item.bag) then
            local guid, current = GetSellableItem(item.bag, item.slot)
            if guid == item.guid and current.stackCount == item.count then
                visit.previous, visit.waits = item, 0
                if WoW.Read(C_Container.UseContainerItem, item.bag, item.slot) ~= "ok" then
                    sellFailed = true
                    ns.UI.Refresh()
                    return
                end
                if visit.items then C_Timer.After(.25, function() SellNextItem(visit) end) end
                return
            end
        end
    end
    visit.items = nil
end

local function AtMerchant(visit)
    if not MerchantIsReady(visit) then return end
    RepairAtMerchant()
    if not MerchantIsReady(visit) or not db.autoSell or not CanAutoSell() then return end
    local items = {}
    for bag = 0, NUM_TOTAL_BAG_FRAMES do
        if BagAllowsSale(bag) then
            local slots = WoW.ReadValue(C_Container.GetContainerNumSlots, bag)
            if WoW.IsFiniteNumber(slots) then
                for slot = 1, slots do
                    local guid, item = GetSellableItem(bag, slot)
                    if guid then items[#items + 1] = {bag = bag, slot = slot, guid = guid, count = item.stackCount} end
                end
            end
        end
    end
    visit.items, visit.index = items, 1
    SellNextItem(visit)
end

local function OnMerchantEvent(_, event, name, method)
    if event == "MERCHANT_SHOW" then
        if merchantVisit then return end
        local visit = {}
        merchantVisit = visit
        -- Let Blizzard finish showing the merchant and selecting the sell tab first.
        C_Timer.After(0, function() AtMerchant(visit) end)
    elseif event == "MERCHANT_CLOSED" then
        merchantVisit = nil
    elseif event == "MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL" then
        if merchantVisit then merchantVisit.items = nil end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if WoW.IsPublic(method) and method == true then QueueSaleCoinRefresh() end
    elseif event == "ITEM_LOCK_CHANGED" or event == "BAG_SLOT_FLAGS_UPDATED" then
        QueueSaleCoinRefresh()
    elseif not Secret(name) and name == addonName and not Secret(method) and type(method) == "string" then
        if method:find("UseContainerItem", 1, true) then sellFailed = true
        elseif method:find("RepairAllItems", 1, true) then repairFailed = true
        else return end
        ns.UI.Refresh()
    end
end

function ns.InitializeBagSort(rootCategory)
    if db then return end
    homeCategory = rootCategory
    db = NormalizeSettings(ForeverTooltipLibreDB.bagSort)
    ForeverTooltipLibreDB.bagSort = db
    if C_Timer and C_Timer.After and Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Merchant
        and C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType then
        merchantEvents = CreateFrame("Frame", "ArkannsQOLBagMerchantEvents")
        merchantEvents:SetScript("OnEvent", OnMerchantEvent)
    end

    getQualityColor = (C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
    if C_Container and C_Container.GetContainerItemInfo
        and hooksecurefunc and SetItemButtonQuality and NUM_TOTAL_BAG_FRAMES
        and ContainerFrameUtil_EnumerateContainerFrames and ContainerFrameUtil_GetShownFrameForID then
        qualityListening = type(getQualityColor) == "function"
        coinListening = C_Item and type(C_Item.GetItemInfo) == "function"
        if qualityListening and C_Item and type(C_Item.GetItemInfo) == "function" then
            reagentEvents = CreateFrame("Frame", "ArkannsQOLBagQualityEvents")
            reagentEvents:SetScript("OnEvent", function(_, _, _, success)
                if waitingForReagents and WoW.IsPublic(success) and success == true
                    and ContainerFrameUtil_GetShownFrameForID() then QueueQualityRefresh() end
            end)
        end
        local collection = C_TransmogCollection
        if collection and type(collection.GetItemInfo) == "function"
            and type(collection.PlayerCanCollectSource) == "function"
            and type(collection.GetAppearanceInfoBySource) == "function" and C_Timer and C_Timer.After then
            transmogEvents = CreateFrame("Frame")
            transmogEvents:SetScript("OnEvent", function(_, event, itemID, success)
                if event == "ITEM_DATA_LOAD_RESULT" and (Secret(success) or success ~= true) then return end
                QueueTransmogRefresh()
            end)
        end
        if qualityListening or transmogEvents or coinListening then hooksecurefunc("SetItemButtonQuality", OnItemQuality) end
        if coinListening and C_Container.SetBackpackSellJunkDisabled then
            hooksecurefunc(C_Container, "SetBackpackSellJunkDisabled", QueueSaleCoinRefresh)
        end
    end

    panel = CreateFrame("Frame", "ArkannsQOLBagsPanel", UIParent, "BackdropTemplate")
    panel:Hide()
    ns.UI.StylePanel(panel)
    local scroll = CreateFrame("ScrollFrame", "ArkannsQOLBagsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 16)
    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(282, 253)
    scroll:SetScrollChild(body)
    local heading = ns.UI.Label(body, L("Sacs"), 0, 0, 20)
    local sortTitle = ns.UI.Label(body, L("Tri à l’ouverture"), 0, 0, 15)
    local merchantTitle = ns.UI.Label(body, L("À l’ouverture d’un marchand"), 0, 0, 15)
    local displayTitle = ns.UI.Label(body, L("Affichage"), 0, 0, 15)
    check = ns.UI.Check(body, "ArkannsQOLBagsEnabled", L("Trier à l’ouverture manuelle"), 16, -54, SetEnabled)
    local sortHelp = ns.UI.Label(body, L("Hors combat et hors banque."), 20, -89)
    status = ns.UI.Label(body, "", 20, -112)
    transmogCheck = CreateTransmogCheck(body, "ArkannsQOLBagTransmog", 16, -140)
    qualityCheck = ns.UI.Check(body, "ArkannsQOLBagQualityBorders", L("Bordure selon la rareté"), 16, -191, SetQualityBorders)
    local searchTargets = {["Trier à l’ouverture manuelle"] = check, ["Bordure selon la rareté"] = qualityCheck,
        ["Transmos manquantes"] = transmogCheck}
    merchantChecks = CreateMerchantChecks(body, "ArkannsQOLBag")
    for index, option in ipairs(merchantOptions) do searchTargets[option[3]] = merchantChecks[index] end
    local appearanceTargets
    local advanced, advancedButton, ShowAppearance, layoutAppearance, unavailable
    if qualityListening then
        advanced = CreateFrame("Frame", nil, body)
        advanced:SetPoint("TOPLEFT", 0, -264)
        local footerY
        refreshAppearance, footerY, appearanceTargets, layoutAppearance = BuildAppearance(advanced)
        for key, target in pairs(appearanceTargets) do searchTargets[key] = target end
        advanced:SetSize(282, -footerY + 36)
        advanced:Hide()
        ShowAppearance = function(opened)
            advanced:SetShown(opened)
            advancedButton:SetText(opened and L("Masquer les réglages de bordure") or L("Personnaliser les bordures"))
            panel.Layout()
        end
        advancedButton = ns.UI.Button(body, "ArkannsQOLBagAdvanced", L("Personnaliser les bordures"), 18, -228, 245,
            function() ShowAppearance(not advanced:IsShown()) end)
        searchTargets["Personnaliser les bordures"] = advancedButton
        body:SetHeight(264)
    else
        qualityCheck:Disable()
        unavailable = ns.UI.Label(body, L("Bordures indisponibles sur ce client."), 20, -224)
    end
    panel.Layout = function()
        local width = math.max(1, panel:GetWidth() - 50)
        local paired = width >= 580
        local columnWidth = paired and (width - 24) / 2 or width
        local function Place(widget, x, y, available)
            widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", x, -y)
            if available then widget:SetWidth(available) end
        end
        local function Text(label, x, y, available)
            Place(label, x, y, available)
            return y + label:GetStringHeight()
        end
        local function Check(control, x, y, inset)
            inset = inset or 0
            control.label:SetWidth(math.max(1, columnWidth - 32 - inset))
            Place(control, x + inset - 4, y)
            return y + math.max(32, control.label:GetStringHeight() + 12)
        end
        local y = Text(heading, 0, 0, width) + 20
        local top = y
        y = Text(sortTitle, 0, y, columnWidth) + 10
        y = Check(check, 0, y)
        y = Text(sortHelp, 0, y, columnWidth) + 8
        local hasStatus = status:GetText() ~= ""
        status:SetShown(hasStatus)
        if hasStatus then y = Text(status, 0, y, columnWidth) + 8 end
        y = Text(merchantTitle, 0, y + 12, columnWidth) + 10
        for index, control in ipairs(merchantChecks) do
            y = Check(control, 0, y, index == 2 and 12 or 0)
        end
        local displayX = paired and columnWidth + 24 or 0
        local displayY = paired and top or y + 12
        displayY = Text(displayTitle, displayX, displayY, columnWidth) + 10
        displayY = Check(transmogCheck, displayX, displayY)
        displayY = Check(qualityCheck, displayX, displayY)
        if advancedButton then
            Place(advancedButton, displayX, displayY, math.min(295, columnWidth))
            displayY = displayY + 36
        elseif unavailable then
            displayY = Text(unavailable, displayX, displayY, columnWidth) + 8
        end
        y = math.max(y, displayY) + 12
        if advanced and advanced:IsShown() then
            Place(advanced, 0, y)
            layoutAppearance(width)
            y = y + advanced:GetHeight()
        end
        body:SetSize(width, y)
        ns.UI.ClampScroll(scroll, y)
    end
    panel:HookScript("OnSizeChanged", panel.Layout)
    panel:SetScript("OnShow", function() CloseQuickSettings(); Refresh() end)
    category = ns.UI.RegisterSettingsPanel(rootCategory, panel, L("Sacs"), "bags")
    AttachShortcut(ContainerFrameCombinedBags)
    if hooksecurefunc and type(ContainerFrame_GenerateFrame) == "function" then
        hooksecurefunc("ContainerFrame_GenerateFrame", AttachShortcut)
    end
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
            if frame:IsVisible() then AttachShortcut(frame) end
        end
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("ContainerFrame.OpenBag", OnBagOpened, panel)
        EventRegistry:RegisterCallback("ContainerFrame.CloseBag", function(_, frame)
            pending[frame] = nil
            if frame == ContainerFrameCombinedBags then CloseQuickSettings(frame) else HideShortcut(frame) end
        end, panel)
    end

    if EventRegistry and EventRegistry.RegisterCallback and C_Timer and C_Timer.After and NUM_TOTAL_BAG_FRAMES
        and hooksecurefunc and ToggleBag and ToggleBackpack and ToggleAllBags
        and ContainerFrameUtil_GetShownFrameForID and ContainerFrame_AllowedToOpenBags then
        local events = CreateFrame("Frame")
        events:RegisterEvent("BANKFRAME_OPENED")
        events:RegisterEvent("BANKFRAME_CLOSED")
        events:RegisterEvent("ADDON_ACTION_BLOCKED")
        events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        events:SetScript("OnEvent", function(_, event, name, method)
            if event == "BANKFRAME_OPENED" then
                bankOpen, pending = true, {}
            elseif event == "BANKFRAME_CLOSED" then
                bankOpen = false
            elseif not Secret(name) and name == addonName and not Secret(method)
                and type(method) == "string" and method:find("SortBags", 1, true) then
                Suspend()
            end
        end)
        -- The show event alone also fires when a merchant opens the bags. Only
        -- native toggle commands can confirm an opening observed this frame.
        hooksecurefunc("ToggleBag", ConfirmBag)
        hooksecurefunc("ToggleBackpack", function() ConfirmBag(0) end)
        hooksecurefunc("ToggleAllBags", ConfirmAllBags)
        listening = true
    end

    ns.RegisterModule("bags", {
        label = L("Sacs"), icon = "Interface\\Icons\\INV_Misc_Bag_08", category = function() return category end,
        Refresh = Refresh,
        SearchSettings = {"Trier à l’ouverture manuelle", "Bordure selon la rareté", "Transmos manquantes",
            "Personnaliser les bordures", "Couleurs de rareté", "Objets de quête", "Composants d’artisanat",
            "Opacité du contour", "Épaisseur du contour", "Halo intérieur",
            merchantOptions[1][3], merchantOptions[2][3], merchantOptions[3][3]},
        OpenSettings = function(source)
            if not source then return end
            local target = searchTargets[source]
            if not target then target = qualityCheck end
            if ShowAppearance and (target == advancedButton or appearanceTargets[source]) then ShowAppearance(true) end
            if ns.UI.RevealControl then ns.UI.RevealControl(scroll, target) end
        end,
        Summary = function()
            local function State(value) return value and L("actif") or L("inactif") end
            return L("Tri : %s · Contours : %s\nTransmos : %s"):format(
                Unavailable() and L("indisponible") or State(db.enabled),
                qualityListening and State(db.qualityBorders) or L("indisponible"),
                transmogEvents and State(db.transmogIcons) or L("indisponible"))
        end,
        ExportSettings = function()
            local config = {qualityColors = CopyColors(db.qualityColors), qualityHidden = CopyHidden(db.qualityHidden)}
            for key in pairs(defaults) do config[key] = db[key] end
            return config
        end,
        profileMigrations = {
            function(config, current)
                if config.qualityBorders == nil then config.qualityBorders = current.qualityBorders end
            end,
            function(config, current)
                for _, key in ipairs({"qualityOpacity", "qualityColors"}) do
                    if config[key] == nil then config[key] = current[key] end
                end
            end,
            function(config, current)
                if config.qualityInnerGlow == nil then config.qualityInnerGlow = current.qualityInnerGlow end
            end,
            function(config, current)
                if config.transmogIcons == nil then config.transmogIcons = current.transmogIcons end
            end,
            function(config, current)
                if config.qualityThickness == nil then config.qualityThickness = current.qualityThickness end
            end,
            function(config)
                config.qualityGlow = nil
            end,
            function(config, current)
                if config.qualityUncommonOnly == nil then
                    config.qualityHidden = CopyHidden(current.qualityHidden)
                else
                    config.qualityHidden = LegacyHidden(config.qualityUncommonOnly, {})
                end
                config.qualityUncommonOnly = nil
            end,
            function(config, current)
                for _, option in ipairs(merchantOptions) do
                    local key = option[1]
                    if config[key] == nil then config[key] = current[key] end
                end
            end,
        },
        ImportSettings = function(config)
            if type(config) ~= "table" or type(config.enabled) ~= "boolean" then return false end
            for key, default in pairs(defaults) do
                if config[key] ~= nil and not ValidSetting(key, config[key], default) then return false end
            end
            if config.qualityHidden ~= nil then
                if type(config.qualityHidden) ~= "table" then return false end
                for quality, hidden in pairs(config.qualityHidden) do
                    if not IsBorderCategory(quality, 5) or hidden ~= true then return false end
                end
            elseif config.qualityUncommonOnly ~= nil and type(config.qualityUncommonOnly) ~= "boolean" then
                return false
            end
            if config.qualityColors ~= nil then
                if type(config.qualityColors) ~= "table" then return false end
                for quality, hex in pairs(config.qualityColors) do
                    if not ValidColor(quality, hex) then return false end
                end
                db.qualityColors = CopyColors(config.qualityColors)
            end
            if config.qualityHidden ~= nil then
                db.qualityHidden = CopyHidden(config.qualityHidden)
            elseif config.qualityUncommonOnly ~= nil then
                LegacyHidden(config.qualityUncommonOnly, db.qualityHidden)
            end
            for key in pairs(defaults) do
                if key ~= "enabled" and config[key] ~= nil then db[key] = config[key] end
            end
            RefreshQualityBorders()
            RefreshTransmogSetting()
            SetEnabled(config.enabled)
            return true
        end,
    })
    Refresh()
    RefreshQualityBorders()
    RefreshTransmogSetting()
end
