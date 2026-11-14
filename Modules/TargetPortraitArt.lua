local _, ns = ...

-- Native resources, except the explicitly requested temporary paladin test below.
-- Forever FrameXML reference: 9dc84f0d3bbae1768ac3405b3716000bd93eda06.
-- Resource usage, portrait layout and required API declarations rechecked on Forever 1.60.1.70888
-- at 4cd0ab752a77164f654ccbca9d0c1fe8dafceebe; relevant sources match the reference above.
-- PlayerChoiceGenericPowerChoiceOptionTemplate uses the portrait border and glow.
-- ArtifactPerks:RefreshBackground uses the class artwork.
-- Dimensions and fallback UVs: BlizzardInterfaceResources AtlasInfo d1ee569878094270c0ad8d8b00de0762158fd578.
-- The full class artwork has an opaque central crest and translucent ornamental edges.
-- Draw it below the native portrait (BACKGROUND 0 vs 1), which occludes its center.
ns.TargetPortraitArt = {
    ring = {
        atlas = "UI-Frame-GenericPlayerChoice-Portrait-Border",
        texture = "Interface\\PlayerChoice\\GenericPlayerChoice",
        coords = {0.2373046875, 0.27587890625, 0.96044921875, 0.9990234375},
        width = 79, height = 79,
    },
    glow = {
        atlas = "UI-Frame-GenericPlayerChoice-Portrait-Border-Glow",
        texture = "Interface\\PlayerChoice\\GenericPlayerChoice",
        coords = {0.583984375, 0.63037109375, 0.82177734375, 0.8681640625},
        width = 95, height = 95,
    },
    glowMask = {
        atlas = "UI-Frame-GenericPlayerChoice-Portrait-Border-Mask",
        texture = "Interface\\PlayerChoice\\GenericPlayerChoiceIconMask",
        coords = {0, 1, 0, 1},
        width = 128, height = 128,
    },
    -- Temporary generated paladin test, explicitly requested by the player.
    -- Measured directly on the installed 1024px TGA, not the requested generation size.
    paladinTest = {
        texture = "Interface\\AddOns\\QoLToolkit\\Media\\PaladinFrameTest.tga",
        side = 1024,
        ring = {32, 476, 6, 505}, ringCenter = {255, 285}, aperture = 340,
        -- Keep engraved ends separate from the plain extensible rails.
        topStart = {38, 282, 544, 597}, topFill = {282, 986, 544, 597},
        bottomStart = {38, 238, 663, 710}, bottomFill = {238, 986, 663, 710},
        -- Stretch only the plain vertical stem; corners and the gem keep their proportions.
        capTop = {769, 958, 752, 840}, capFill = {769, 958, 892, 900},
        capBottom = {769, 958, 900, 988}, capGem = {769, 958, 850, 886},
    },
    -- One continuous skin for the custom player frame. Positions were measured
    -- on the compiled TGA; only UI scale changes its proportions.
    paladinCustom = {
        texture = "Interface\\AddOns\\QoLToolkit\\Media\\PaladinCustomFrame.tga",
        width = 1024, height = 512, displayWidth = 232,
        -- Radius 131 covers the closed aperture (max radius < 130) without crossing its right rim.
        portrait = {205, 232, 262},
        -- Centers measured from each opaque plaque, independently of its text.
        name = {368.5, 70.5, 516, 60}, level = {212.5, 388.5, 134, 64},
        body = {330, 154, 618, 162},
        health = {350, 158, 596, 72}, power = {350, 238, 596, 72},
    },
    order = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"},
    -- Zero-based cells in Interface\WorldStateFrame\Icons-Classes.
    classSlots = {WARRIOR = 0, MAGE = 1, ROGUE = 2, DRUID = 3,
        HUNTER = 4, SHAMAN = 5, PRIEST = 6, WARLOCK = 7, PALADIN = 8},
    classes = {
        WARRIOR = {
            label = "Guerrier",
            rune = {
                atlas = "Artifacts-Warrior-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIWarrior",
                coords = {0.0009765625, 0.2744140625, 0.603515625, 0.876953125},
                width = 280, height = 280,
            },
        },
        PALADIN = {
            label = "Paladin",
            rune = {
                atlas = "Artifacts-Paladin-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIPaladin",
                coords = {0.0009765625, 0.2001953125, 0.6865234375, 0.8857421875},
                width = 204, height = 204,
            },
        },
        HUNTER = {
            label = "Chasseur",
            rune = {
                atlas = "Artifacts-Hunter-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIHunter",
                coords = {0.0009765625, 0.2060546875, 0.6689453125, 0.8740234375},
                width = 210, height = 210,
            },
        },
        ROGUE = {
            label = "Voleur",
            rune = {
                atlas = "Artifacts-Rogue-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIRogue",
                coords = {0.0009765625, 0.2001953125, 0.6826171875, 0.8818359375},
                width = 204, height = 204,
            },
        },
        PRIEST = {
            label = "Prêtre",
            rune = {
                atlas = "Artifacts-Priest-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIPriest",
                coords = {0.0009765625, 0.2412109375, 0.712890625, 0.953125},
                width = 246, height = 246,
            },
        },
        SHAMAN = {
            label = "Chaman",
            rune = {
                atlas = "Artifacts-Shaman-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIShaman",
                coords = {0.0009765625, 0.2001953125, 0.7021484375, 0.9013671875},
                width = 204, height = 204,
            },
        },
        MAGE = {
            label = "Mage",
            rune = {
                atlas = "Artifacts-MageArcane-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIMageArcane",
                coords = {0.0009765625, 0.2001953125, 0.740234375, 0.939453125},
                width = 204, height = 204,
            },
        },
        WARLOCK = {
            label = "Démoniste",
            rune = {
                atlas = "Artifacts-Warlock-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIWarlock",
                coords = {0.0009765625, 0.2001953125, 0.6953125, 0.89453125},
                width = 204, height = 204,
            },
        },
        DRUID = {
            label = "Druide",
            rune = {
                atlas = "Artifacts-Druid-BG-rune",
                texture = "Interface\\Artifacts\\ArtifactUIDruid",
                coords = {0.0009765625, 0.2158203125, 0.78125, 0.99609375},
                width = 220, height = 220,
            },
        },
    },
}

-- Class-frame variants, explicitly requested by the player.
-- All skins share the approved paladin bar slots. Portrait and text coordinates
-- are calibrated against each compiled 1024x512 image. Targets reuse these files
-- with horizontal UVs reversed; their text remains a separate native font region.
-- Only the brighter materials are softened; portrait, text and live bars keep their colors.
local customVariants = {
    WARRIOR = {file = "Warrior", portrait = {205.797, 234.017, 258},
        name = {370, 69, 516, 60}, level = {210.5, 389, 134, 64}},
    HUNTER = {file = "Hunter", portrait = {205.88, 234.69, 258},
        name = {369.5, 69.5, 516, 60}, level = {210.5, 388, 134, 64}},
    ROGUE = {file = "Rogue", portrait = {206.708, 233.294, 254},
        name = {369, 69, 516, 60}, level = {209.5, 388, 134, 64}},
    SHAMAN = {file = "Shaman", desaturation = .25, brightness = .82, portrait = {206.234, 234.435, 260},
        name = {369, 68.5, 516, 60}, level = {210.5, 389, 134, 64}},
    MAGE = {file = "Mage", desaturation = .40, brightness = .76, portrait = {204.255, 233.065, 262},
        name = {369, 71, 516, 60}, level = {208.5, 390, 134, 64}},
    WARLOCK = {file = "Warlock", desaturation = .20, brightness = .88, portrait = {212.4167, 233.4416, 262},
        name = {370.5, 69, 516, 60}, level = {217, 387.5, 134, 64}},
    PRIEST = {file = "Priest", desaturation = .12, brightness = .78, portrait = {206.7409, 233.7503, 262},
        name = {369, 71, 516, 60}, level = {211, 390, 134, 64}},
    DRUID = {file = "Druid", desaturation = .22, brightness = .86, portrait = {205.0768, 232.7654, 262},
        name = {369, 70, 516, 60}, level = {209.5, 390, 134, 64}},
}
ns.TargetPortraitArt.customFrames = {PALADIN = ns.TargetPortraitArt.paladinCustom}
for class, variant in pairs(customVariants) do
    local art = {}
    for key, value in pairs(ns.TargetPortraitArt.paladinCustom) do art[key] = value end
    art.texture = "Interface\\AddOns\\QoLToolkit\\Media\\ClassFrame" .. variant.file .. ".tga"
    art.desaturation, art.brightness = variant.desaturation or 0, variant.brightness or 1
    for _, key in ipairs({"portrait", "name", "level"}) do
        if variant[key] then art[key] = variant[key] end
    end
    ns.TargetPortraitArt.customFrames[class] = art
end
