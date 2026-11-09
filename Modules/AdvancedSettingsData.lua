-- Reviewed against Gethe/wow-ui-source forever, revision 9dc84f0d3bbae1768ac3405b3716000bd93eda06.
local _, ns = ...
local L = ns.L
ns.AdvancedSettingsCategories = {{id = "camera", label = L("Caméra")}, {id = "plates", label = L("Plaques")}, {id = "combat", label = L("Combat")}, {id = "interface", label = L("Interface")}, {id = "graphics", label = L("Graphismes")}, {id = "images", label = L("Captures")}, {id = "sound", label = L("Sons")}}
ns.AdvancedSettingsCatalog = {
    {category = "camera", name = "cameraZoomSpeed", label = L("Vitesse du zoom"), help = L("Vitesse du zoom à la molette. Plus haut : zoom plus rapide."), kind = "number", min = 1, max = 50, integer = false},
    {category = "camera", name = "rawMouseEnable", label = L("Entrée souris brute"), help = L("Utilise directement les mouvements de la souris pour contrôler la caméra."), kind = "boolean"},
    {category = "plates", name = "nameplateMinScale", label = L("Échelle minimale"), help = L("Taille minimale utilisée pour les plaques selon la distance."), kind = "number", min = 0.5, max = 2, integer = false},
    {category = "plates", name = "nameplateMaxScale", label = L("Échelle maximale"), help = L("Taille maximale utilisée pour les plaques selon la distance."), kind = "number", min = 0.5, max = 2, integer = false},
    {category = "plates", name = "nameplateSelectedScale", label = L("Échelle de la cible"), help = L("Multiplie la taille de la plaque de ta cible."), kind = "number", min = 0.5, max = 2, integer = false},
    {category = "plates", name = "nameplateMinAlpha", label = L("Opacité minimale"), help = L("Opacité minimale des plaques. 0 : transparent ; 1 : opaque."), kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateMaxAlpha", label = L("Opacité maximale"), help = L("Opacité maximale des plaques. 0 : transparent ; 1 : opaque."), kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateSelectedAlpha", label = L("Opacité de la cible"), help = L("Opacité de la plaque ciblée. 1 : opaque."), kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateOccludedAlphaMult", label = L("Opacité derrière un obstacle"), help = L("Multiplie l’opacité quand une unité est masquée par le décor."), kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateOverlapV", label = L("Espacement vertical"), help = L("Espacement entre les plaques empilées. Plus haut : davantage d’espace."), kind = "number", min = 0.1, max = 3, integer = false},
    {category = "plates", name = "nameplateOverlapH", label = L("Espacement horizontal"), help = L("Espacement horizontal utilisé pour éviter le chevauchement des plaques."), kind = "number", min = 0.1, max = 3, integer = false},
    {category = "plates", name = "nameplateMotionSpeed", label = L("Vitesse de déplacement"), help = L("Vitesse à laquelle les plaques rejoignent leur nouvelle position."), kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateMaxDistance", label = L("Distance d’affichage"), help = L("Distance demandée en yards. Le client peut imposer une limite plus basse."), kind = "number", min = 10, max = 60, integer = false},
    {category = "plates", name = "nameplateTopInset", label = L("Marge en haut"), help = L("Marge supérieure des plaques, en fraction de la hauteur de l’écran."), kind = "number", min = 0, max = 0.5, integer = false},
    {category = "plates", name = "nameplateBottomInset", label = L("Marge en bas"), help = L("Marge inférieure des plaques, en fraction de la hauteur de l’écran."), kind = "number", min = 0, max = 0.5, integer = false},
    {category = "combat", name = "ActionButtonUseKeyDown", label = L("Lancer à l’appui"), help = L("Activé : déclenche le raccourci à l’appui. Désactivé : au relâchement."), kind = "boolean"},
    {category = "combat", name = "SpellQueueWindow", label = L("File de sorts (ms)"), help = L("Fenêtre pour anticiper le prochain sort pendant une incantation ou le GCD. 0 : désactivée."), kind = "number", min = 0, max = 500, integer = true},
    {category = "combat", name = "autoUnshift", label = L("Quitter la forme automatiquement"), help = L("Autorise les actions à quitter une forme de druide quand elles le nécessitent."), kind = "boolean"},
    {category = "interface", name = "alwaysCompareItems", label = L("Comparer les objets"), help = L("Affiche la comparaison d’équipement sans maintenir Maj."), kind = "boolean"},
    {category = "interface", name = "autoQuestWatch", label = L("Suivre les quêtes acceptées"), help = L("Ajoute automatiquement les nouvelles quêtes au suivi."), kind = "boolean"},
    {category = "interface", name = "autoQuestProgress", label = L("Suivre les quêtes qui progressent"), help = L("Ajoute au suivi une quête dont un objectif vient de progresser."), kind = "boolean"},
    {category = "interface", name = "AutoPushSpellToActionBar", label = L("Ajouter les nouveaux sorts aux barres"), help = L("Place automatiquement les nouveaux sorts dans une case libre des barres d’action."), kind = "boolean"},
    {category = "graphics", name = "groundEffectDensity", label = L("Densité de la végétation"), help = L("Quantité d’herbe et de petits décors au sol. Une valeur élevée peut réduire les FPS."), kind = "number", min = 0, max = 256, integer = true, group = "Décor"},
    {category = "graphics", name = "groundEffectDist", label = L("Distance de la végétation"), help = L("Distance d’affichage de l’herbe et des petits décors. Une valeur élevée peut réduire les FPS."), kind = "number", min = 0, max = 500, integer = true, group = "Décor"},
    {category = "graphics", name = "groundEffectFade", label = L("Fondu de la végétation"), help = L("Distance de fondu des petits décors au sol. Le rendu dépend aussi de leur distance d’affichage."), kind = "number", min = 0, max = 500, integer = true, group = "Décor"},
    {category = "graphics", name = "lodObjectFadeScale", label = L("Fondu des objets lointains"), help = L("Augmente la distance de fondu des objets. Plus haut : davantage de décor, coût GPU accru."), kind = "number", min = 1, max = 200, integer = true, group = "Décor"},
    {category = "graphics", name = "lodObjectCullSize", label = L("Seuil des petits objets"), help = L("Plus bas : conserve les petits objets plus loin. Peut réduire les FPS."), kind = "number", min = 1, max = 100, integer = false, group = "Décor"},
    {category = "graphics", name = "terrainLodDist", label = L("Détail du terrain lointain"), help = L("Distance avant simplification du terrain. Plus haut : relief plus détaillé, coût accru."), kind = "number", min = 100, max = 1000, integer = true, group = "Décor"},
    {category = "graphics", name = "doodadLodScale", label = L("Détail des objets du décor"), help = L("Échelle de détail des objets du décor. Plus haut : modèles détaillés plus longtemps."), kind = "number", min = 1, max = 200, integer = true, group = "Décor"},
    {category = "graphics", name = "wmoLodDist", label = L("Détail des bâtiments"), help = L("Distance de détail des grands bâtiments et structures. Plus haut : coût graphique accru."), kind = "number", min = 100, max = 1000, integer = true, group = "Décor"},
    {category = "graphics", name = "entityLodDist", label = L("Détail des personnages"), help = L("Distance de détail des personnages et créatures. Plus haut : coût accru dans les foules."), kind = "number", min = 1, max = 100, integer = true, group = "Décor"},
    {category = "graphics", name = "shadowSoft", label = L("Ombres adoucies"), help = L("Adoucit les contours des ombres, si le mode de rendu actif le permet."), kind = "boolean", group = "Ombres"},
    {category = "graphics", name = "entityShadowFadeScale", label = L("Fondu des ombres des unités"), help = L("Distance de fondu des ombres des personnages et créatures. Dépend du mode d’ombres."), kind = "number", min = 1, max = 100, integer = true, group = "Ombres"},
    {category = "graphics", name = "shadowTextureSize", label = L("Résolution des ombres"), help = L("Détail des textures d’ombres. 2048 utilise plus de mémoire graphique que 1024."), kind = "choice", choices = {{"1024", "1024"}, {"2048", "2048"}}, group = "Ombres"},
    {category = "graphics", name = "shadowNumCascades", label = L("Cascades d’ombres"), help = L("Nombre de zones de calcul des ombres. Plus haut : couverture plus détaillée, coût GPU accru."), kind = "number", min = 1, max = 4, integer = true, group = "Ombres"},
    {category = "graphics", name = "shadowBlendCascades", label = L("Transitions des ombres"), help = L("Adoucit les transitions entre les cascades. Nécessite plusieurs cascades actives."), kind = "boolean", group = "Ombres"},
    {category = "graphics", name = "assaoBlurPassCount", label = L("Lissage de l’occlusion"), help = L("Nombre de passes de lissage ASSAO. Dépend du niveau d’occlusion ambiante ; plus haut coûte davantage."), kind = "number", min = 0, max = 6, integer = true, group = "Ombres"},
    {category = "graphics", name = "assaoDetailShadowStrength", label = L("Ombres de contact fines"), help = L("Renforce les petits détails ASSAO. Peut faire scintiller les contours. Nécessite l’occlusion ambiante."), kind = "number", min = 0, max = 5, integer = false, group = "Ombres"},
    {category = "graphics", name = "assaoShadowMult", label = L("Intensité de l’occlusion"), help = L("Renforce les ombres de contact ASSAO. Sans effet si cette méthode d’occlusion est inactive."), kind = "number", min = 0, max = 5, integer = false, group = "Ombres"},
    {category = "graphics", name = "assaoSharpness", label = L("Netteté de l’occlusion"), help = L("Précision des bords ASSAO. 0 : fondu large ; 1 : contours préservés. Nécessite l’occlusion ambiante."), kind = "number", min = 0, max = 1, integer = false, group = "Ombres"},
    {category = "graphics", name = "weatherDensity", label = L("Intensité météo"), help = L("Densité de la pluie et de la neige, selon la météo de la zone. 0 : effets réduits au minimum."), kind = "number", min = 0, max = 3, integer = true, group = "Effets"},
    {category = "graphics", name = "ffxGlow", label = L("Halo lumineux classique"), help = L("Halo autour des zones lumineuses. Son effet dépend du mode de rendu utilisé."), kind = "boolean", group = "Effets"},
    {category = "graphics", name = "ffxDeath", label = L("Effet visuel de mort"), help = L("Désature l’image lorsque ton personnage est mort."), kind = "boolean", group = "Effets"},
    {category = "graphics", name = "bloomEnable", label = L("Bloom"), help = L("Active le bloom des zones lumineuses. Son intensité se règle dans les graphismes du jeu."), kind = "boolean", group = "Effets"},
    {category = "graphics", name = "showfootprintparticles", label = L("Particules des pas"), help = L("Affiche les particules produites par les pas lorsque le sol le permet."), kind = "boolean", group = "Effets"},
    {category = "graphics", name = "ResampleAlwaysSharpen", label = L("Netteté sans FSR"), help = L("Active le filtre de netteté même sans mise à l’échelle FSR. Intensité dans les graphismes du jeu."), kind = "boolean", group = "Image"},
    {category = "graphics", name = "CMAA2Quality", label = L("Qualité du CMAA2"), help = L("Règle la qualité de l’anticrénelage quand le CMAA2 est actif."), kind = "choice", choices = {{"0", L("Faible")}, {"1", L("Moyenne")}, {"2", L("Élevée")}, {"3", L("Ultra")}}, group = "Image"},
    {category = "graphics", name = "CMAA2ExtraSharpness", label = L("Netteté du CMAA2"), help = L("Préserve mieux les textes et contours avec CMAA2, au prix d’un anticrénelage moins marqué."), kind = "boolean", group = "Image"},
    {category = "graphics", name = "animFrameSkipLOD", label = L("Animations lointaines allégées"), help = L("Réduit la fréquence des animations à distance. Peut économiser des ressources, avec moins de fluidité au loin."), kind = "boolean", group = "Image"},
    {category = "graphics", name = "maxFPSLoading", label = L("FPS pendant les chargements"), help = L("Limite les FPS sur les écrans de chargement. Ne règle pas la vitesse de chargement."), kind = "number", min = 8, max = 240, integer = true, group = "Image"},
    {category = "graphics", name = "RAIDgroundEffectDensity", label = L("Densité de la végétation — raid"), help = L("Profil raid activé dans WoW. Quantité d’herbe et de petits décors au sol. Une valeur élevée peut réduire les FPS."), kind = "number", min = 0, max = 256, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDgroundEffectDist", label = L("Distance de la végétation — raid"), help = L("Profil raid activé dans WoW. Distance d’affichage de l’herbe et des petits décors. Une valeur élevée peut réduire les FPS."), kind = "number", min = 0, max = 500, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDgroundEffectFade", label = L("Fondu de la végétation — raid"), help = L("Profil raid activé dans WoW. Distance de fondu des petits décors au sol. Le rendu dépend aussi de leur distance d’affichage."), kind = "number", min = 0, max = 500, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDweatherDensity", label = L("Intensité météo — raid"), help = L("Profil raid activé dans WoW. Densité de la pluie et de la neige, selon la météo de la zone. 0 : effets réduits au minimum."), kind = "number", min = 0, max = 3, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDshadowSoft", label = L("Ombres adoucies — raid"), help = L("Profil raid activé dans WoW. Adoucit les contours des ombres, si le mode de rendu actif le permet."), kind = "boolean", group = "Raid"},
    {category = "graphics", name = "RAIDlodObjectFadeScale", label = L("Fondu des objets lointains — raid"), help = L("Profil raid activé dans WoW. Augmente la distance de fondu des objets. Plus haut : davantage de décor, coût GPU accru."), kind = "number", min = 1, max = 200, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDlodObjectCullSize", label = L("Seuil des petits objets — raid"), help = L("Profil raid activé dans WoW. Plus bas : conserve les petits objets plus loin. Peut réduire les FPS."), kind = "number", min = 1, max = 100, integer = false, group = "Raid"},
    {category = "graphics", name = "RAIDterrainLodDist", label = L("Détail du terrain lointain — raid"), help = L("Profil raid activé dans WoW. Distance avant simplification du terrain. Plus haut : relief plus détaillé, coût accru."), kind = "number", min = 100, max = 1000, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDdoodadLodScale", label = L("Détail des objets du décor — raid"), help = L("Profil raid activé dans WoW. Échelle de détail des objets du décor. Plus haut : modèles détaillés plus longtemps."), kind = "number", min = 1, max = 200, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDwmoLodDist", label = L("Détail des bâtiments — raid"), help = L("Profil raid activé dans WoW. Distance de détail des grands bâtiments et structures. Plus haut : coût graphique accru."), kind = "number", min = 100, max = 1000, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDentityLodDist", label = L("Détail des personnages — raid"), help = L("Profil raid activé dans WoW. Distance de détail des personnages et créatures. Plus haut : coût accru dans les foules."), kind = "number", min = 1, max = 100, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDentityShadowFadeScale", label = L("Fondu des ombres des unités — raid"), help = L("Profil raid activé dans WoW. Distance de fondu des ombres des personnages et créatures. Dépend du mode d’ombres."), kind = "number", min = 1, max = 100, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDshadowTextureSize", label = L("Résolution des ombres — raid"), help = L("Profil raid activé dans WoW. Détail des textures d’ombres. 2048 utilise plus de mémoire graphique que 1024."), kind = "choice", choices = {{"1024", "1024"}, {"2048", "2048"}}, group = "Raid"},
    {category = "graphics", name = "RAIDshadowNumCascades", label = L("Cascades d’ombres — raid"), help = L("Profil raid activé dans WoW. Nombre de zones de calcul des ombres. Plus haut : couverture plus détaillée, coût GPU accru."), kind = "number", min = 1, max = 4, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDshadowBlendCascades", label = L("Transitions des ombres — raid"), help = L("Profil raid activé dans WoW. Adoucit les transitions entre les cascades. Nécessite plusieurs cascades actives."), kind = "boolean", group = "Raid"},
    {category = "images", name = "screenshotFormat", label = L("Format des captures"), help = L("JPEG : fichiers plus légers. TGA : images sans compression JPEG."), kind = "choice", choices = {{"jpeg", "JPEG"}, {"tga", "TGA"}}},
    {category = "images", name = "screenshotQuality", label = L("Qualité JPEG"), help = L("Qualité des captures JPEG, de 1 à 10. Sans effet sur les captures TGA."), kind = "number", min = 1, max = 10, integer = true},
    {category = "sound", name = "Sound_EnableArmorFoleySoundForSelf", label = L("Bruits de ton armure"), help = L("Joue les frottements et cliquetis de ton équipement."), kind = "boolean"},
    {category = "sound", name = "Sound_EnableArmorFoleySoundForOthers", label = L("Bruits des autres armures"), help = L("Joue les frottements et cliquetis de l’équipement des autres personnages."), kind = "boolean"},
    {category = "sound", name = "FootstepSounds", label = L("Bruits de pas"), help = L("Joue les bruits de pas des personnages et créatures."), kind = "boolean"},
    {category = "sound", name = "Sound_ListenerAtCharacter", label = L("Écouter depuis le personnage"), help = L("Place l’écoute des sons 3D sur ton personnage plutôt que sur la caméra."), kind = "boolean"},
}
-- Native setting names, including proxy components. See INVENTAIRE-REGLAGES.txt.
ns.AdvancedNativeSettings = {}
for name in string.gmatch([[
accessibilityscreennarrationenabled accessibilityscreennarrationspeechrate accessibilityscreennarrationspeechvolume accessibilityscreennarrationvoice actionbuttonusekeyheldspell advancedcombatlogging
arachnophobiamode audiolocale autoacceptquickjoinrequests autoclearafk autointeract autolootdefault
autorangedcombat autoselfcast bankconfirmtabcleanup blockchannelinvites blocktrades bloomusermult
brightness caadebuffselfalert caaenabled caainterruptcast caainterruptcastsuccess caapartyhealthfrequency
caapartyhealthpercent caapartyhealthvoice caapartyhealthvolume caaplayercastformat caaplayercastmintime caaplayercastmode
caaplayercastthrottle caaplayercastvoice caaplayercastvolume caaplayerhealthformat caaplayerhealthpercent caaplayerhealththrottle
caaplayerhealthvoice caaplayerhealthvolume caapulseplayerhealthpercent caapulseplayerhealthvolume caaresource1formats caaresource1percents
caaresource1throttle caaresource1voice caaresource1volume caaresource2formats caaresource2percents caaresource2throttle
caaresource2voice caaresource2volume caasaycombatend caasaycombatstart caasayiftargeted caasaytargetname
caasayyourdebuffs caasayyourdebuffsformat caasayyourdebuffsminduration caasayyourdebuffsvoice caasayyourdebuffsvolume caaspeed
caatargetcastformat caatargetcastmintime caatargetcastmode caatargetcastthrottle caatargetcastvoice caatargetcastvolume
caatargetdeathbehavior caatargethealthformat caatargethealthpercent caatargethealththrottle caatargethealthvoice caatargethealthvolume
caavoice caavolume camerabobbing cameradistancemaxzoomfactor camerafov camerakeepcharactercentered
camerapitchmovespeed camerapitchsmoothspeed camerapivot camerareduceunexpectedmovement camerasmoothstyle camerasmoothtrackingstyle
cameraterraintilt camerawatercollision camerayawmovespeed camerayawsmoothspeed chatbubbles chatbubblesparty
chatbubblesraid chatstyle classicstyleworldtext clipcursor closedinfoframes closedinfoframesaccountwide
colorblindmode colorblindsimulator colorblindweaknessfactor combinedbags contrast coordsbytenths
countdownforcooldowns cursorsizepreferred deselectonclick disableservernagle discorddisplayname displayfreebagslots
displayspellactivationoverlays donotflashlowhealthwarning empowertapcontrols enablecollectiontoasts enableconnecttophotosharing enablefloatingcombattext
enablelearnedrecipetoasts enableloottoasts enablemouseovercast enablemousespeed enablemovepad enablepings
excludedcensorsources ffxantialiasingmode findyourselfanywhere findyourselfmodecircle findyourselfmodeicon findyourselfmodeoutline
floatingcombattextauras_v2 floatingcombattextcombatdamage_v2 floatingcombattextcombathealing_v2 floatingcombattextcombathealingabsorbself_v2 floatingcombattextcombathealingabsorbtarget_v2 floatingcombattextcombatlogperiodicspells_v2
floatingcombattextcombatstate_v2 floatingcombattextcombopoints_v2 floatingcombattextdamagereduction_v2 floatingcombattextdodgeparrymiss_v2 floatingcombattextenergygains_v2 floatingcombattextfloatmode_v2
floatingcombattextfriendlyhealers_v2 floatingcombattexthonorgains_v2 floatingcombattextlowmanahealth_v2 floatingcombattextperiodicenergygains_v2 floatingcombattextreactives_v2 floatingcombattextrepchanges_v2
floatingcombattextspellmechanics_v2 floatingcombattextspellmechanicsother_v2 gamepadbackpedalthreshold gamepadcamerafollowonstick gamepadcamerafollowpitchoffset gamepadcamerapitchspeed
gamepadcamerayawspeed gamepadfacemovementfreeflying gamepadfacemovementmaxangle gamepadfacemovementmaxanglecombat gamepadfacemovementmount gamepadfacemovementswimming
gamepadfocusstatecolor gamepadfocusstateopacity gamepadhudmodifierusestoggle gamepadinvertpitch gamepadinvertyaw gamepadpossessbaroverride
gamepadraidtargetinghovermode gamepadrunthreshold gamepadshowpersistentinputlegend gamepadstancebaroverride gamepadswapfriendlytargetactions gamepadswaphostiletargetactions
gamepadswaptargetmodifiers gamepadturnwithcamera gamepadusepartytargeting gamma graphicscomputeeffects graphicsdeptheffects
graphicsenvironmentdetail graphicsgroundclutter graphicslightmode graphicsliquiddetail graphicsoutlinemode graphicsparticledensity
graphicspbrliquiddetail graphicsprojectedtextures graphicsquality graphicsshadowquality graphicsspelldensity graphicsssao
graphicstextureresolution graphicsviewdistance guildmembernotify gxadapter gxapi gxcompatasyncshadercompilation
gxcompatcommandlistmultithreading gxcompatoptionalgpufeatures gxcompatworksubmitoptimizations gxmaxframelatency gxmaximize gxmonitor
housingdecorlightradiusindicatorsenabled housingotherdecorlightradiusindicatortype housingselecteddecorlightradiusindicatortype inputdeviceinterfacestyle instantquesttext interactonleftclick
lockactionbars lootundermouse lossofcontrol lowlatencymode maxfps maxfpsbk
minimapshowplayercoords mouseinvertpitch mousespeed moviesubtitle moviesubtitlebackground moviesubtitlebackgroundalpha
msaaalphatest msaaquality nameplateaurascale nameplatedebuffpadding nameplateshowall nameplateshowclasscolor
nameplateshowenemies nameplateshowenemyminions nameplateshowenemyminus nameplateshowfriendlyclasscolor nameplateshowfriendlynpcs nameplateshowfriendlyplayerminions
nameplateshowfriendlyplayers nameplateshowfriendlyrealmname nameplateshowoffscreen nameplateshowonlynameforfriendlyplayerunits nameplateshowself nameplatesize
nameplatestyle nameplateuseclasscolorforfriendlyplayerunitnames notcheddisplaymode occludedsilhouetteplayer outline overridescreenflash
performeddeathtutorial performedvendortutorial physicslevel pingcategorytutorialshown pingmode pingtarget
profanityfilter pvpframesdisplayclasscolor pvpframesdisplayonlyhealerpowerbars pvpframesdisplaypowerbars pvpframeshealthtext pvpoptiondisplaypets
questpoi raidframescenterbigdefensive raidframesdispelindicatoranimatedborder raidframesdispelindicatoroverlay raidframesdispelindicatoroverlayanimation raidframesdispelindicatortype
raidframesdisplayaggrohighlight raidframesdisplayclasscolor raidframesdisplaydebuffs raidframesdisplayincomingheals raidframesdisplaylargerrolespecificdebuffs raidframesdisplayonlydispellabledebuffs
raidframesdisplayonlyhealerpowerbars raidframesdisplaypowerbars raidframeshealthbarcolor raidframeshealthbarcolorbg raidframeshealthtext raidgraphicscomputeeffects
raidgraphicsdeptheffects raidgraphicsenvironmentdetail raidgraphicsgroundclutter raidgraphicslightmode raidgraphicsliquiddetail raidgraphicsoutlinemode
raidgraphicsparticledensity raidgraphicspbrliquiddetail raidgraphicsprojectedtextures raidgraphicsquality raidgraphicsshadowquality raidgraphicsspelldensity
raidgraphicsssao raidgraphicstextureresolution raidgraphicsviewdistance raidoptiondisplaymaintankandassist raidoptiondisplaypets raidsettingsenabled
remotetexttospeech remotetexttospeechvoice renderscale replacemyplayerportrait replaceotherplayerportraits resamplequality
resamplesharpness restrictcalendarinvites shadowrt shakestrengthcamera shakestrengthui showingamenavigation
showloadingscreentips shownpetutorials showpingsinchat showpingsonraidframes showquestunitcircles showtargetoftarget
showtimestamps showtoastfriendrequest showtoastoffline showtoastonline showtoastwindow showtutorials
skiptutorialachievement softtargetenemy softtargeticonenemy softtargeticongameobject softtargeticoninteract softtargetinteract
softtargetlowpriorityicons softtargettinginteractkeysound softtargettooltipenemy softtargettooltipinteract sound_ambiencevolume sound_dialogvolume
sound_enableallsound sound_enableambience sound_enabledialog sound_enableemotesounds sound_enableencounterwarningssounds sound_enableerrorspeech
sound_enablegameplaysfx sound_enablemusic sound_enablepetbattlemusic sound_enablepetsounds sound_enablepingsounds sound_enablepositionallowpassfilter
sound_enablereverb sound_enablesfx sound_enablesoundwhengameisinbg sound_encounterwarningsvolume sound_gameplaysfx sound_mastervolume
sound_maxcachesizeinbytes sound_musicvolume sound_numchannels sound_outputdriverindex sound_pingvolume sound_sfxvolume
sound_zonemusicnodelay speechtotext spellactivationoverlayopacity statustext statustextdisplay targetfps
textlocale texttospeech texturefilteringmode uiscale unitnameenemyminionname unitnameenemyplayername
unitnamefriendlyminionname unitnamefriendlyplayername unitnamefriendlyspecialnpcname unitnamehostlenpc unitnameinteractivenpc unitnamenoncombatcreaturename
unitnamenpc unitnameown unitsurnameown usehighrestextures useipv6 usemaxfps
usemaxfpsbk usetargetfps useuiscale voicechatmastervolumescale voiceinputvolume voiceoutputvolume
voiceprovider voiceusediscordsettings voicevadsensitivity vrsvalar vsync whispermode
worldmapshowcursorcoords worldmapshowplayercoords worldtextminsize
]], "%S+") do ns.AdvancedNativeSettings[name] = true end
