-- Reviewed against Gethe/wow-ui-source forever, revision 9dc84f0d3bbae1768ac3405b3716000bd93eda06.
local _, ns = ...
ns.AdvancedSettingsCategories = {{id = "camera", label = "Caméra"}, {id = "plates", label = "Plaques"}, {id = "combat", label = "Combat"}, {id = "interface", label = "Interface"}, {id = "graphics", label = "Graphismes"}, {id = "images", label = "Captures"}, {id = "sound", label = "Sons"}}
ns.AdvancedSettingsCatalog = {
    {category = "camera", name = "cameraZoomSpeed", label = "Vitesse du zoom", help = "Vitesse du zoom à la molette. Plus haut : zoom plus rapide.", kind = "number", min = 1, max = 50, integer = false},
    {category = "camera", name = "rawMouseEnable", label = "Entrée souris brute", help = "Utilise directement les mouvements de la souris pour contrôler la caméra.", kind = "boolean"},
    {category = "plates", name = "nameplateMinScale", label = "Échelle minimale", help = "Taille minimale utilisée pour les plaques selon la distance.", kind = "number", min = 0.5, max = 2, integer = false},
    {category = "plates", name = "nameplateMaxScale", label = "Échelle maximale", help = "Taille maximale utilisée pour les plaques selon la distance.", kind = "number", min = 0.5, max = 2, integer = false},
    {category = "plates", name = "nameplateSelectedScale", label = "Échelle de la cible", help = "Multiplie la taille de la plaque de ta cible.", kind = "number", min = 0.5, max = 2, integer = false},
    {category = "plates", name = "nameplateMinAlpha", label = "Opacité minimale", help = "Opacité minimale des plaques. 0 : transparent ; 1 : opaque.", kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateMaxAlpha", label = "Opacité maximale", help = "Opacité maximale des plaques. 0 : transparent ; 1 : opaque.", kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateSelectedAlpha", label = "Opacité de la cible", help = "Opacité de la plaque ciblée. 1 : opaque.", kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateOccludedAlphaMult", label = "Opacité derrière un obstacle", help = "Multiplie l’opacité quand une unité est masquée par le décor.", kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateOverlapV", label = "Espacement vertical", help = "Espacement entre les plaques empilées. Plus haut : davantage d’espace.", kind = "number", min = 0.1, max = 3, integer = false},
    {category = "plates", name = "nameplateOverlapH", label = "Espacement horizontal", help = "Espacement horizontal utilisé pour éviter le chevauchement des plaques.", kind = "number", min = 0.1, max = 3, integer = false},
    {category = "plates", name = "nameplateMotionSpeed", label = "Vitesse de déplacement", help = "Vitesse à laquelle les plaques rejoignent leur nouvelle position.", kind = "number", min = 0, max = 1, integer = false},
    {category = "plates", name = "nameplateMaxDistance", label = "Distance d’affichage", help = "Distance demandée en yards. Le client peut imposer une limite plus basse.", kind = "number", min = 10, max = 60, integer = false},
    {category = "plates", name = "nameplateTopInset", label = "Marge en haut", help = "Marge supérieure des plaques, en fraction de la hauteur de l’écran.", kind = "number", min = 0, max = 0.5, integer = false},
    {category = "plates", name = "nameplateBottomInset", label = "Marge en bas", help = "Marge inférieure des plaques, en fraction de la hauteur de l’écran.", kind = "number", min = 0, max = 0.5, integer = false},
    {category = "combat", name = "ActionButtonUseKeyDown", label = "Lancer à l’appui", help = "Activé : déclenche le raccourci à l’appui. Désactivé : au relâchement.", kind = "boolean"},
    {category = "combat", name = "SpellQueueWindow", label = "File de sorts (ms)", help = "Fenêtre pour anticiper le prochain sort pendant une incantation ou le GCD. 0 : désactivée.", kind = "number", min = 0, max = 500, integer = true},
    {category = "combat", name = "autoUnshift", label = "Quitter la forme automatiquement", help = "Autorise les actions à quitter une forme de druide quand elles le nécessitent.", kind = "boolean"},
    {category = "interface", name = "alwaysCompareItems", label = "Comparer les objets", help = "Affiche la comparaison d’équipement sans maintenir Maj.", kind = "boolean"},
    {category = "interface", name = "autoQuestWatch", label = "Suivre les quêtes acceptées", help = "Ajoute automatiquement les nouvelles quêtes au suivi.", kind = "boolean"},
    {category = "interface", name = "autoQuestProgress", label = "Suivre les quêtes qui progressent", help = "Ajoute au suivi une quête dont un objectif vient de progresser.", kind = "boolean"},
    {category = "interface", name = "AutoPushSpellToActionBar", label = "Ajouter les nouveaux sorts aux barres", help = "Place automatiquement les nouveaux sorts dans une case libre des barres d’action.", kind = "boolean"},
    {category = "graphics", name = "groundEffectDensity", label = "Densité de la végétation", help = "Quantité d’herbe et de petits décors au sol. Une valeur élevée peut réduire les FPS.", kind = "number", min = 0, max = 256, integer = true, group = "Décor"},
    {category = "graphics", name = "groundEffectDist", label = "Distance de la végétation", help = "Distance d’affichage de l’herbe et des petits décors. Une valeur élevée peut réduire les FPS.", kind = "number", min = 0, max = 500, integer = true, group = "Décor"},
    {category = "graphics", name = "groundEffectFade", label = "Fondu de la végétation", help = "Distance de fondu des petits décors au sol. Le rendu dépend aussi de leur distance d’affichage.", kind = "number", min = 0, max = 500, integer = true, group = "Décor"},
    {category = "graphics", name = "lodObjectFadeScale", label = "Fondu des objets lointains", help = "Augmente la distance de fondu des objets. Plus haut : davantage de décor, coût GPU accru.", kind = "number", min = 1, max = 200, integer = true, group = "Décor"},
    {category = "graphics", name = "lodObjectCullSize", label = "Seuil des petits objets", help = "Plus bas : conserve les petits objets plus loin. Peut réduire les FPS.", kind = "number", min = 1, max = 100, integer = false, group = "Décor"},
    {category = "graphics", name = "terrainLodDist", label = "Détail du terrain lointain", help = "Distance avant simplification du terrain. Plus haut : relief plus détaillé, coût accru.", kind = "number", min = 100, max = 1000, integer = true, group = "Décor"},
    {category = "graphics", name = "doodadLodScale", label = "Détail des objets du décor", help = "Échelle de détail des objets du décor. Plus haut : modèles détaillés plus longtemps.", kind = "number", min = 1, max = 200, integer = true, group = "Décor"},
    {category = "graphics", name = "wmoLodDist", label = "Détail des bâtiments", help = "Distance de détail des grands bâtiments et structures. Plus haut : coût graphique accru.", kind = "number", min = 100, max = 1000, integer = true, group = "Décor"},
    {category = "graphics", name = "entityLodDist", label = "Détail des personnages", help = "Distance de détail des personnages et créatures. Plus haut : coût accru dans les foules.", kind = "number", min = 1, max = 100, integer = true, group = "Décor"},
    {category = "graphics", name = "shadowSoft", label = "Ombres adoucies", help = "Adoucit les contours des ombres, si le mode de rendu actif le permet.", kind = "boolean", group = "Ombres"},
    {category = "graphics", name = "entityShadowFadeScale", label = "Fondu des ombres des unités", help = "Distance de fondu des ombres des personnages et créatures. Dépend du mode d’ombres.", kind = "number", min = 1, max = 100, integer = true, group = "Ombres"},
    {category = "graphics", name = "shadowTextureSize", label = "Résolution des ombres", help = "Détail des textures d’ombres. 2048 utilise plus de mémoire graphique que 1024.", kind = "choice", choices = {{"1024", "1024"}, {"2048", "2048"}}, group = "Ombres"},
    {category = "graphics", name = "shadowNumCascades", label = "Cascades d’ombres", help = "Nombre de zones de calcul des ombres. Plus haut : couverture plus détaillée, coût GPU accru.", kind = "number", min = 1, max = 4, integer = true, group = "Ombres"},
    {category = "graphics", name = "shadowBlendCascades", label = "Transitions des ombres", help = "Adoucit les transitions entre les cascades. Nécessite plusieurs cascades actives.", kind = "boolean", group = "Ombres"},
    {category = "graphics", name = "assaoBlurPassCount", label = "Lissage de l’occlusion", help = "Nombre de passes de lissage ASSAO. Dépend du niveau d’occlusion ambiante ; plus haut coûte davantage.", kind = "number", min = 0, max = 6, integer = true, group = "Ombres"},
    {category = "graphics", name = "assaoDetailShadowStrength", label = "Ombres de contact fines", help = "Renforce les petits détails ASSAO. Peut faire scintiller les contours. Nécessite l’occlusion ambiante.", kind = "number", min = 0, max = 5, integer = false, group = "Ombres"},
    {category = "graphics", name = "assaoShadowMult", label = "Intensité de l’occlusion", help = "Renforce les ombres de contact ASSAO. Sans effet si cette méthode d’occlusion est inactive.", kind = "number", min = 0, max = 5, integer = false, group = "Ombres"},
    {category = "graphics", name = "assaoSharpness", label = "Netteté de l’occlusion", help = "Précision des bords ASSAO. 0 : fondu large ; 1 : contours préservés. Nécessite l’occlusion ambiante.", kind = "number", min = 0, max = 1, integer = false, group = "Ombres"},
    {category = "graphics", name = "weatherDensity", label = "Intensité météo", help = "Densité de la pluie et de la neige, selon la météo de la zone. 0 : effets réduits au minimum.", kind = "number", min = 0, max = 3, integer = true, group = "Effets"},
    {category = "graphics", name = "ffxGlow", label = "Halo lumineux classique", help = "Halo autour des zones lumineuses. Son effet dépend du mode de rendu utilisé.", kind = "boolean", group = "Effets"},
    {category = "graphics", name = "ffxDeath", label = "Effet visuel de mort", help = "Désature l’image lorsque ton personnage est mort.", kind = "boolean", group = "Effets"},
    {category = "graphics", name = "bloomEnable", label = "Bloom", help = "Active le bloom des zones lumineuses. Son intensité se règle dans les graphismes du jeu.", kind = "boolean", group = "Effets"},
    {category = "graphics", name = "showfootprintparticles", label = "Particules des pas", help = "Affiche les particules produites par les pas lorsque le sol le permet.", kind = "boolean", group = "Effets"},
    {category = "graphics", name = "ResampleAlwaysSharpen", label = "Netteté sans FSR", help = "Active le filtre de netteté même sans mise à l’échelle FSR. Intensité dans les graphismes du jeu.", kind = "boolean", group = "Image"},
    {category = "graphics", name = "CMAA2Quality", label = "Qualité du CMAA2", help = "Règle la qualité de l’anticrénelage quand le CMAA2 est actif.", kind = "choice", choices = {{"0", "Faible"}, {"1", "Moyenne"}, {"2", "Élevée"}, {"3", "Ultra"}}, group = "Image"},
    {category = "graphics", name = "CMAA2ExtraSharpness", label = "Netteté du CMAA2", help = "Préserve mieux les textes et contours avec CMAA2, au prix d’un anticrénelage moins marqué.", kind = "boolean", group = "Image"},
    {category = "graphics", name = "animFrameSkipLOD", label = "Animations lointaines allégées", help = "Réduit la fréquence des animations à distance. Peut économiser des ressources, avec moins de fluidité au loin.", kind = "boolean", group = "Image"},
    {category = "graphics", name = "maxFPSLoading", label = "FPS pendant les chargements", help = "Limite les FPS sur les écrans de chargement. Ne règle pas la vitesse de chargement.", kind = "number", min = 8, max = 240, integer = true, group = "Image"},
    {category = "graphics", name = "RAIDgroundEffectDensity", label = "Densité de la végétation — raid", help = "Profil raid activé dans WoW. Quantité d’herbe et de petits décors au sol. Une valeur élevée peut réduire les FPS.", kind = "number", min = 0, max = 256, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDgroundEffectDist", label = "Distance de la végétation — raid", help = "Profil raid activé dans WoW. Distance d’affichage de l’herbe et des petits décors. Une valeur élevée peut réduire les FPS.", kind = "number", min = 0, max = 500, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDgroundEffectFade", label = "Fondu de la végétation — raid", help = "Profil raid activé dans WoW. Distance de fondu des petits décors au sol. Le rendu dépend aussi de leur distance d’affichage.", kind = "number", min = 0, max = 500, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDweatherDensity", label = "Intensité météo — raid", help = "Profil raid activé dans WoW. Densité de la pluie et de la neige, selon la météo de la zone. 0 : effets réduits au minimum.", kind = "number", min = 0, max = 3, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDshadowSoft", label = "Ombres adoucies — raid", help = "Profil raid activé dans WoW. Adoucit les contours des ombres, si le mode de rendu actif le permet.", kind = "boolean", group = "Raid"},
    {category = "graphics", name = "RAIDlodObjectFadeScale", label = "Fondu des objets lointains — raid", help = "Profil raid activé dans WoW. Augmente la distance de fondu des objets. Plus haut : davantage de décor, coût GPU accru.", kind = "number", min = 1, max = 200, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDlodObjectCullSize", label = "Seuil des petits objets — raid", help = "Profil raid activé dans WoW. Plus bas : conserve les petits objets plus loin. Peut réduire les FPS.", kind = "number", min = 1, max = 100, integer = false, group = "Raid"},
    {category = "graphics", name = "RAIDterrainLodDist", label = "Détail du terrain lointain — raid", help = "Profil raid activé dans WoW. Distance avant simplification du terrain. Plus haut : relief plus détaillé, coût accru.", kind = "number", min = 100, max = 1000, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDdoodadLodScale", label = "Détail des objets du décor — raid", help = "Profil raid activé dans WoW. Échelle de détail des objets du décor. Plus haut : modèles détaillés plus longtemps.", kind = "number", min = 1, max = 200, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDwmoLodDist", label = "Détail des bâtiments — raid", help = "Profil raid activé dans WoW. Distance de détail des grands bâtiments et structures. Plus haut : coût graphique accru.", kind = "number", min = 100, max = 1000, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDentityLodDist", label = "Détail des personnages — raid", help = "Profil raid activé dans WoW. Distance de détail des personnages et créatures. Plus haut : coût accru dans les foules.", kind = "number", min = 1, max = 100, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDentityShadowFadeScale", label = "Fondu des ombres des unités — raid", help = "Profil raid activé dans WoW. Distance de fondu des ombres des personnages et créatures. Dépend du mode d’ombres.", kind = "number", min = 1, max = 100, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDshadowTextureSize", label = "Résolution des ombres — raid", help = "Profil raid activé dans WoW. Détail des textures d’ombres. 2048 utilise plus de mémoire graphique que 1024.", kind = "choice", choices = {{"1024", "1024"}, {"2048", "2048"}}, group = "Raid"},
    {category = "graphics", name = "RAIDshadowNumCascades", label = "Cascades d’ombres — raid", help = "Profil raid activé dans WoW. Nombre de zones de calcul des ombres. Plus haut : couverture plus détaillée, coût GPU accru.", kind = "number", min = 1, max = 4, integer = true, group = "Raid"},
    {category = "graphics", name = "RAIDshadowBlendCascades", label = "Transitions des ombres — raid", help = "Profil raid activé dans WoW. Adoucit les transitions entre les cascades. Nécessite plusieurs cascades actives.", kind = "boolean", group = "Raid"},
    {category = "images", name = "screenshotFormat", label = "Format des captures", help = "JPEG : fichiers plus légers. TGA : images sans compression JPEG.", kind = "choice", choices = {{"jpeg", "JPEG"}, {"tga", "TGA"}}},
    {category = "images", name = "screenshotQuality", label = "Qualité JPEG", help = "Qualité des captures JPEG, de 1 à 10. Sans effet sur les captures TGA.", kind = "number", min = 1, max = 10, integer = true},
    {category = "sound", name = "Sound_EnableArmorFoleySoundForSelf", label = "Bruits de ton armure", help = "Joue les frottements et cliquetis de ton équipement.", kind = "boolean"},
    {category = "sound", name = "Sound_EnableArmorFoleySoundForOthers", label = "Bruits des autres armures", help = "Joue les frottements et cliquetis de l’équipement des autres personnages.", kind = "boolean"},
    {category = "sound", name = "FootstepSounds", label = "Bruits de pas", help = "Joue les bruits de pas des personnages et créatures.", kind = "boolean"},
    {category = "sound", name = "Sound_ListenerAtCharacter", label = "Écouter depuis le personnage", help = "Place l’écoute des sons 3D sur ton personnage plutôt que sur la caméra.", kind = "boolean"},
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
