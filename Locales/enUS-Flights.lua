local _, ns = ...
for source, translation in pairs({
    ["Temps de vol"] = "Flight times",
    ["Chronométrer les vols"] = "Time flight paths",
    ["Affiche la durée des trajets et le temps restant en vol."] = "Shows route durations and time remaining in flight.",
    ["Durée inconnue"] = "Unknown duration",
    ["Durée mesurée · %s"] = "Measured duration · %s",
    ["Ancienne mesure · ≈ %s"] = "Past measurement · ≈ %s",
    ["Durée partagée · ≈ %s"] = "Shared duration · ≈ %s",
    ["≈ %s"] = "≈ %s",
    ["Temps écoulé"] = "Elapsed time",
    ["Arrivée estimée"] = "Estimated arrival",
    ["Escale demandée"] = "Landing requested",
    ["En vol"] = "In flight",
    ["Exporter les durées"] = "Export durations",
    ["Aucun vol complet à exporter."] = "No completed flights to export.",
    ["Ctrl+C pour copier les trajets et leurs durées."] = "Ctrl+C to copy routes and their durations.",
}) do
    ns.English[source] = translation
end
