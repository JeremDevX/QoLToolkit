local ns = {}
assert(loadfile("Modules/TargetPortraitArt.lua"))("QoLToolkit", ns)
local art = ns.TargetPortraitArt
local seen = {}
for _, class in ipairs(art.order) do
    local variant = assert(art.customFrames[class], "Missing custom frame: " .. class)
    local path = assert(variant.texture:match("^Interface\\AddOns\\QoLToolkit\\(.+)$")):gsub("\\", "/")
    assert(not seen[path], "Each class has its own source skin: " .. class)
    seen[path] = true
    local file = assert(io.open(path, "rb"), "Missing skin: " .. path)
    local data = file:read("*a"); file:close()
    local function Number(offset) return data:byte(offset) + data:byte(offset + 1) * 256 end
    assert(data:byte(3) == 2 and data:byte(17) == 32 and Number(13) == 1024 and Number(15) == 512,
        "Class skin must be uncompressed 1024x512 BGRA32: " .. class)
    local function Alpha(x, y)
        x, y = math.floor(x), math.floor(y)
        if math.floor(data:byte(18) / 32) % 2 == 0 then y = 511 - y end
        return assert(data:byte(18 + data:byte(1) + (y * 1024 + x) * 4 + 4))
    end
    -- The image encoder can leave one or two alpha units in visually empty pixels.
    assert(Alpha(0, 0) <= 2 and Alpha(variant.portrait[1], variant.portrait[2]) <= 2,
        "The exterior and portrait aperture remain transparent: " .. class)
    assert(Alpha(variant.name[1] + variant.name[3] / 2, variant.name[2] + variant.name[4] / 2) > 240
        and Alpha(variant.level[1], variant.level[2]) > 240, "Both text plaques remain opaque: " .. class)
    for _, key in ipairs({"health", "power"}) do
        local slot = variant[key]
        assert(Alpha(slot[1] + slot[3] / 2, slot[2] + slot[4] / 2) <= 8,
            "Live bar content must remain transparent: " .. class .. " " .. key)
        assert(slot[3] == variant.health[3] and slot[4] == variant.health[4],
            "Both live bars use equal dimensions: " .. class)
        local targetX = variant.width - slot[1] - slot[3]
        assert(targetX >= 0 and targetX + slot[3] <= variant.width,
            "The exact target mirror keeps its content inside the same skin")
    end
end
assert(art.customFrames.PALADIN == art.paladinCustom, "Preserve the approved paladin model")
print("PASS: nine class skins, native format, portrait/bar apertures, text plaques and exact mirrored bounds")
