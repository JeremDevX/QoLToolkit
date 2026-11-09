# QoL Toolkit

Ces règles s’appliquent à tous les fichiers de l’addon et à sa distribution.

## Ressources WoW

- Utiliser uniquement les textures, atlas, icônes, polices, modèles et sons fournis par le client WoW Forever pris en charge. Référencer les ressources en jeu, sans redistribuer de fichiers extraits, d’images externes ou d’assets générés.
- Vérifier les chemins, identifiants et atlas dans les ressources de la branche Forever. Garder les proportions des icônes. Pour un atlas facultatif, prévoir une texture WoW de secours. Éviter les glyphes non vérifiés pour les boutons.
- Préférer les modèles d’interface de WoW et réutiliser les composants du thème commun. Les fonds simples peuvent être dessinés avec les API natives.

## Règles Blizzard

- Respecter la [politique des addons WoW](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534/1) et le [contrat Blizzard](https://www.blizzard.com/en-us/legal/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement). Distribuer gratuitement un code lisible. Aucun paywall, publicité ou sollicitation de dons en jeu.
- Utiliser uniquement les API publiques exposées aux addons de la branche Forever. Respecter les actions protégées, les restrictions de combat, le taint et les valeurs secrètes. Si le client refuse un accès, laisser la fonctionnalité indisponible et l’indiquer dans l’interface quand c’est utile.
- Aucun bot, clic simulé, commande injectée, accès mémoire, interception réseau ou contournement d’une protection. Ne pas modifier les fichiers de Blizzard. Pour le tri des sacs, utiliser exclusivement le tri natif sur ouverture explicite si le client l’autorise.
- Éviter les comportements qui nuisent au client, aux autres joueurs ou au serveur. Un appel réussi ne prouve pas que la fonctionnalité est autorisée dans tous les contextes.

## Développement

- Garder un addon unique. Intégrer chaque fonctionnalité à ses réglages, au registre des modules et aux profils lorsque les options peuvent être copiées sans effet indésirable. Préserver les sauvegardes et les clés existantes lors d’une mise à jour.
- Partir des événements du jeu. Regrouper les événements répétés, limiter la fréquence des mises à jour et couper les tâches lorsqu’elles sont inutiles. Libérer les aperçus, rappels et éléments visuels au moment approprié.
- Garder les réglages graphiques natifs accessibles depuis WoW. Vérifier la disponibilité et relire toute valeur modifiée. Distinguer une valeur enregistrée de son effet visuel.
- Tester hors jeu les cas normaux et les API absentes, valeurs secrètes, restrictions de combat, transitions et mises à jour. Ne pas lancer, contrôler ni inspecter le processus WoW dans le cadre du développement. Identifier les vérifications visuelles qui restent à faire en jeu.
- Vérifier le manifeste et les tests avant de synchroniser les copies Bureau et AddOns. Garder `AGENTS.md` hors du manifeste Lua.

## Liens de référence

Pour une décision de compatibilité, partir des fichiers Blizzard de la version ciblée. La révision `9dc84f0` ci-dessous correspond à la base Forever utilisée pour les vérifications de la 3.1.0. Consulter la branche Forever pour les mises à jour, puis fixer la révision de référence pour les tests.

- [Interface Blizzard de la branche Forever](https://github.com/Gethe/wow-ui-source/tree/forever) — miroir du code Lua et XML livré avec le client. Vérifier les modèles, événements et comportements natifs.
- [Documentation générée des API Blizzard](https://github.com/Gethe/wow-ui-source/tree/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_APIDocumentationGenerated) — signatures, résultats, événements et annotations de confidentialité du client ciblé.
- [Graphismes natifs Forever](https://github.com/Gethe/wow-ui-source/blob/9dc84f0d3bbae1768ac3405b3716000bd93eda06/Interface/AddOns/Blizzard_SettingsDefinitions_Shared/Graphics.lua) — vérifier les options déjà proposées et les dépendances entre réglages.
- [Liste vérifiée des fichiers WoW](https://github.com/wowdev/wow-listfile/releases/tag/202611072341) — le fichier `verified-listfile.csv` permet de retrouver les chemins et `FileDataID`. Vérifier séparément la présence dans la version ciblée si elle est incertaine.
- [Index des atlas Forever](https://github.com/Ketho/BlizzardInterfaceResources/blob/d1ee569878094270c0ad8d8b00de0762158fd578/Resources/AtlasInfo.lua) — relever le nom exact, les dimensions et les coordonnées. Référencer la ressource dans le client.
- [Forum Interface et macros de Blizzard](https://us.forums.blizzard.com/en/wow/c/guides/ui-macro/35) — annonces et retours de développeurs. La [politique des addons](https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534/1) reste la référence pour la distribution.
