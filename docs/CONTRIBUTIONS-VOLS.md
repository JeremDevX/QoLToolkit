# Temps de vol

Dans `/qt` → **Outils** → **Temps de vol**, le chronomètre est actif par défaut. La carte affiche la durée connue au survol d’une destination. Le premier vol affiche le temps écoulé si aucune durée n’est connue. L’addon calcule la médiane des cinq derniers vols valides pour ce trajet, ce build et ce bonus de vitesse. Après un patch, il utilise la médiane du dernier build mesuré pour le même trajet et le même bonus comme estimation jusqu’à un nouveau vol complet. Les vols interrompus et les trajets dont les escales ou le bonus ne sont pas identifiables ne contribuent pas à la base.

## Contribuer

Clique sur **Exporter mes temps de vol**, copie le texte sélectionné, puis transmets-le en privé au mainteneur. L’export contient les identifiants des escales, le build, le bonus et la durée. En transmettant ton export, tu autorises QoL Toolkit à agréger les durées et à redistribuer le résultat avec l’addon.

## Valider et distribuer

Attribue un alias stable et privé par contributeur. Stocke la base SQLite et les exports reçus hors du dépôt. Depuis la racine du projet, avec Python 3.10 ou supérieur et le chemin vers la base privée dans `$flightDb` sous PowerShell.

```powershell
Get-Clipboard -Raw | python docs/flight_contributions.py --database "$flightDb" receive contributeur-01
python docs/flight_contributions.py --database "$flightDb" receive contributeur-02 C:\chemin\export.txt
python docs/flight_contributions.py --database "$flightDb" build
```

Un nouvel export actualise la mesure du contributeur pour le trajet, le build et le bonus correspondants. Une durée publique demande trois contributeurs concordants au minimum et une majorité stricte dans la marge de trois secondes ou 3 %, selon la valeur la plus élevée. Un export client reste une déclaration. L’alias évite de compter plusieurs envois d’une même personne comme des confirmations indépendantes.

Vérifie le diff de `Modules/FlightTimesData.lua` et ajoute ce fichier généré à la prochaine version normale de l’addon. Le fichier ne contient que les durées agrégées et leurs clés. Une mesure personnelle correspondant au trajet et au bonus prend la priorité sur cette table, même si elle vient d’un build antérieur.
