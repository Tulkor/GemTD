class_name MaulXp
extends RefCounted
## Erfahrung (XP) in Shopping Maul wie im Original: in Zehnteln gezählt (10 = 1,0 XP), bleibt über
## Spiele hinweg erhalten (user://maul.cfg statt des 6-stelligen Codes). Nach jedem Level wächst
## ein Topf; solange er größer als 4·√XP ist, gibt es +0,1 XP (höchstens 5× pro Level), so wird
## jedes weitere Zehntel teurer. Ab 25 XP sind die Profi-Filialen offen, die XP-Tower des XPert
## ab 25 … 800 XP (Forschungen R00E … R00R in pro.json → xp.unlocks).

const FILE := "user://maul.cfg"


static func cfg() -> Dictionary:
	return MaulData.pro().get("xp", {})


## Gespeicherte XP dieses Rechners (in Zehnteln).
static func load_xp() -> int:
	var c := ConfigFile.new()
	if c.load(FILE) != OK:
		return int(cfg().get("start", 10))
	return int(c.get_value("xp", "tenths", int(cfg().get("start", 10))))


static func save_xp(tenths: int) -> void:
	var c := ConfigFile.new()
	c.load(FILE)
	c.set_value("xp", "tenths", tenths)
	c.save(FILE)


## XP-Topf nach Level n wachsen lassen. Gibt [neue XP, neuer Topf] zurück.
static func gain(xp: int, pot: float, n: int, players: int, factor: float) -> Array:
	var x := cfg()
	pot += n * float(x.get("per_level", 5)) * (1.0 + players * float(x.get("per_player", 0.1))) * factor
	for i in int(x.get("max_steps", 5)):
		var cost := float(x.get("cost", 4)) * sqrt(float(maxi(xp, 1)))
		if pot <= cost or xp >= int(x.get("max", 9999)):
			break
		xp += 1
		pot -= cost
	return [xp, pot]


## XP, die eine Voraussetzung (R00E …) verlangt, 0 = keine XP-Voraussetzung.
static func needed(req: String) -> int:
	return int(cfg().get("unlocks", {}).get(req, 0)) * 10


static func pro_unlocked(xp: int) -> bool:
	return xp >= int(cfg().get("pro_shops", 25)) * 10


## 123 → „12,3“
static func text(tenths: int) -> String:
	return "%d,%d" % [tenths / 10, tenths % 10]
