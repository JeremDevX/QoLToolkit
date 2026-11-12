local _, ns = ...
for source, translation in pairs({
    ["Temps de vol"] = "Flight times",
    ["Chronométrer les vols"] = "Time flight paths",
    ["Chronomètre les trajets des maîtres de vol et affiche les durées connues sur leur carte."] =
        "Times flight master routes and shows known durations on their map.",
    ["Durée inconnue. Le prochain vol complet sera chronométré."] = "Unknown duration. The next completed flight will be timed.",
    ["Temps mesuré · %s"] = "Measured time · %s",
    ["Temps communautaire · ≈ %s"] = "Community estimate · ≈ %s",
    ["Temps écoulé · %s"] = "Elapsed time · %s",
    ["Temps restant estimé · %s"] = "Estimated time remaining · %s",
    ["Vol en cours"] = "Flight in progress",
    ["Exporter mes temps de vol"] = "Export my flight times",
    ["Aucun vol complet à exporter."] = "No completed flights to export.",
    ["Copie le texte avec Ctrl+C et transmets-le en privé. L’export contient uniquement les trajets, les durées, la version du jeu et le bonus de vitesse."] =
        "Copy the text with Ctrl+C and share it privately. The export only contains routes, durations, game builds, and speed bonuses.",
}) do
    ns.English[source] = translation
end
