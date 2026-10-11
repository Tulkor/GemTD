class_name Abilities
extends RefCounted
## Alle Fähigkeiten, die ein Tower in seinen JSON-Daten haben kann, mit Standardwerten.
## Der Tower-Editor baut seine Eingabefelder aus dieser Liste.
## Neue Fähigkeit: hier eintragen und in Tower._attack()/_hit()/_apply_enemy_auras()
## bzw. Game._update_auras() umsetzen.

const SCHEMA := {
	"splash": {"label": "Flächenschaden", "params": {"radius": 1.0, "factor": 0.5}},
	"slow": {"label": "Verlangsamung", "params": {"factor": 0.3, "duration": 2.0}},
	"poison": {"label": "Gift", "params": {"dps": 5.0, "duration": 3.0}},
	"crit": {"label": "Kritischer Treffer", "params": {"chance": 0.2, "multiplier": 2.0}},
	"multishot": {"label": "Mehrfachschuss", "params": {"targets": 3}},
	"bounce": {"label": "Kettenblitz", "params": {"targets": 3, "falloff": 0.8, "radius": 2.5}},
	"armor_reduce": {"label": "Rüstung senken", "params": {"amount": 3.0, "duration": 5.0}},
	"stun": {"label": "Betäubung", "params": {"chance": 0.1, "duration": 1.0}},
	"air_bonus": {"label": "Bonus gegen Luft", "params": {"multiplier": 2.0}},
	"gold_on_hit": {"label": "Gold bei Treffer", "params": {"chance": 0.05, "gold": 1}},
	"speed_aura": {"label": "Tempo-Aura (Tower)", "params": {"radius": 3.0, "bonus": 0.15}},
	"damage_aura": {"label": "Schadens-Aura (Tower)", "params": {"radius": 3.0, "bonus": 0.15}},
	"burn_aura": {"label": "Brand-Aura (Gegner)", "params": {"radius": 2.0, "dps": 20.0}},
	"slow_aura": {"label": "Verlangsamungs-Aura (Gegner)", "params": {"radius": 2.0, "factor": 0.3}},
	"armor_aura": {"label": "Rüstungs-Aura (Gegner)", "params": {"radius": 2.0, "amount": 3.0}},
}

const PARAM_LABELS := {
	"radius": "Radius (Towerbreiten)",
	"factor": "Faktor",
	"duration": "Dauer (s)",
	"dps": "Schaden/s",
	"chance": "Chance",
	"multiplier": "Multiplikator",
	"targets": "Ziele",
	"bonus": "Bonus",
	"falloff": "Abnahme",
	"amount": "Menge",
	"gold": "Gold",
}


static func types() -> Array:
	return SCHEMA.keys()


static func default_for(type: String) -> Dictionary:
	var d := {"type": type}
	var params: Dictionary = SCHEMA.get(type, {}).get("params", {})
	for k in params:
		d[k] = params[k]
	return d


static func describe(ab: Dictionary) -> String:
	var type := str(ab.get("type", "?"))
	match type:
		"splash":
			return str(TranslationServer.translate("Flächenschaden %d%% im Radius %.1f")) % [float(ab.factor) * 100, float(ab.radius)]
		"slow":
			return str(TranslationServer.translate("Verlangsamt um %d%% für %.1fs")) % [float(ab.factor) * 100, float(ab.duration)]
		"poison":
			return str(TranslationServer.translate("Gift: %.1f Schaden/s für %.1fs")) % [float(ab.dps), float(ab.duration)]
		"crit":
			return str(TranslationServer.translate("%d%% Chance auf %.1fx Schaden")) % [float(ab.chance) * 100, float(ab.multiplier)]
		"multishot":
			return str(TranslationServer.translate("Trifft %d Ziele gleichzeitig")) % int(ab.targets)
		"bounce":
			return str(TranslationServer.translate("Springt auf %d weitere Ziele (je %d%% Schaden)")) % [int(ab.targets), float(ab.falloff) * 100]
		"armor_reduce":
			return str(TranslationServer.translate("Senkt Rüstung um %.0f für %.1fs")) % [float(ab.amount), float(ab.duration)]
		"stun":
			return str(TranslationServer.translate("%d%% Chance, %.1fs zu betäuben")) % [float(ab.chance) * 100, float(ab.duration)]
		"air_bonus":
			return str(TranslationServer.translate("%.1fx Schaden gegen Flieger")) % float(ab.multiplier)
		"gold_on_hit":
			if float(ab.get("gold_per_wave", 0)) > 0.0:
				return str(TranslationServer.translate("%d%% Chance auf Gold pro Treffer (%s × Welle)")) % [float(ab.chance) * 100, str(snappedf(float(ab.gold_per_wave), 0.01))]
			return str(TranslationServer.translate("%d%% Chance auf %d Gold pro Treffer")) % [float(ab.chance) * 100, int(ab.gold)]
		"speed_aura":
			return str(TranslationServer.translate("Aura: +%d%% Angriffstempo für Tower im Radius %.1f")) % [float(ab.bonus) * 100, float(ab.radius)]
		"damage_aura":
			return str(TranslationServer.translate("Aura: +%d%% Schaden für Tower im Radius %.1f")) % [float(ab.bonus) * 100, float(ab.radius)]
		"burn_aura":
			return str(TranslationServer.translate("Verbrennt Gegner im Radius %.1f: %.0f Schaden/s")) % [float(ab.radius), float(ab.dps)]
		"slow_aura":
			return str(TranslationServer.translate("Verlangsamt Gegner im Radius %.1f um %d%%")) % [float(ab.radius), float(ab.factor) * 100]
		"armor_aura":
			return str(TranslationServer.translate("Senkt Rüstung von Gegnern im Radius %.1f um %.0f")) % [float(ab.radius), float(ab.amount)]
	return type
