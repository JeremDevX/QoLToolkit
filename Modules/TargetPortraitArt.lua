local _, ns = ...

-- Native resources only. Forever FrameXML reference: 9dc84f0d3bbae1768ac3405b3716000bd93eda06.
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
