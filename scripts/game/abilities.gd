class_name Abilities
extends RefCounted
## Alle Fähigkeiten, die ein Tower in seinen JSON-Daten haben kann, mit Standardwerten.
## Der Tower-Editor baut seine Eingabefelder aus dieser Liste.
## Neue Fähigkeit: hier eintragen und in Tower._attack() bzw. Game._update_auras() umsetzen.

const SCHEMA := {
	"splash": {"label": "Flächenschaden", "params": {"radius": 1.0, "factor": 0.5}},
	"slow": {"label": "Verlangsamung", "params": {"factor": 0.3, "duration": 2.0}},
	"poison": {"label": "Gift", "params": {"dps": 5.0, "duration": 3.0}},
	"crit": {"label": "Kritischer Treffer", "params": {"chance": 0.2, "multiplier": 2.0}},
	"multishot": {"label": "Mehrfachschuss", "params": {"targets": 3}},
	"speed_aura": {"label": "Tempo-Aura", "params": {"radius": 3.0, "bonus": 0.15}},
}

const PARAM_LABELS := {
	"radius": "Radius (Felder)",
	"factor": "Faktor",
	"duration": "Dauer (s)",
	"dps": "Schaden/s",
	"chance": "Chance",
	"multiplier": "Multiplikator",
	"targets": "Ziele",
	"bonus": "Bonus",
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
			return "Flächenschaden %d%% im Radius %.1f" % [float(ab.factor) * 100, float(ab.radius)]
		"slow":
			return "Verlangsamt um %d%% für %.1fs" % [float(ab.factor) * 100, float(ab.duration)]
		"poison":
			return "Gift: %.1f Schaden/s für %.1fs" % [float(ab.dps), float(ab.duration)]
		"crit":
			return "%d%% Chance auf %.1fx Schaden" % [float(ab.chance) * 100, float(ab.multiplier)]
		"multishot":
			return "Trifft %d Ziele gleichzeitig" % int(ab.targets)
		"speed_aura":
			return "Aura: +%d%% Angriffstempo im Radius %.1f" % [float(ab.bonus) * 100, float(ab.radius)]
	return type
