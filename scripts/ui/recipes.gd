class_name Recipes
extends RefCounted
## Spezial-Rezepte für die Oberfläche: was gebraucht wird, was man schon hat, was fehlt.
## owned ist eine Liste von [tower_id, stufe] (Tower auf dem Feld plus neue Gems der Runde).


## IDs aller Spezial-Tower mit Rezept.
static func ids() -> Array:
	return Database.special_ids().filter(func(id): return not (Database.towers[id].get("recipe", []) as Array).is_empty())


static func ingredient_label(ing: Dictionary) -> String:
	return Database.tower_label(str(ing.get("tower", "")), int(ing.get("tier", 0)))


## Nimmt eine passende Zutat aus dem Pool und gibt sie zurück (oder null).
static func _take(pool: Array, ing: Dictionary) -> Variant:
	for i in pool.size():
		if pool[i][0] == str(ing.get("tower", "")) and int(pool[i][1]) == int(ing.get("tier", 0)):
			return pool.pop_at(i)
	return null


static func _is_new(entry: Variant) -> bool:
	return entry != null and entry.size() > 2 and bool(entry[2])


## Rückgabe: {"lines": [{"text", "have", "new", "indent"}], "missing": int}.
## have ist null für Zwischenzeilen wie "einer von:". new: die Zutat ist ein neuer Gem dieser Runde,
## noch nicht fixiert (owned-Einträge dürfen dafür als drittes Feld true tragen).
static func status(id: String, owned: Array) -> Dictionary:
	var recipe: Array = Database.towers.get(id, {}).get("recipe", [])
	# Fixierte Tower zuerst, damit sie vor den neuen Gems als Zutat zählen
	var pool := owned.filter(func(o): return not _is_new(o)) + owned.filter(func(o): return _is_new(o))
	var taken := []
	taken.resize(recipe.size())
	# Erst die festen Zutaten, dann die Auswahl-Zutaten, damit "einer von" keine feste Zutat wegnimmt.
	for i in recipe.size():
		if not recipe[i].has("any_of"):
			taken[i] = _take(pool, recipe[i])
	var lines := []
	var missing := 0
	for i in recipe.size():
		var ing: Dictionary = recipe[i]
		if ing.has("any_of"):
			lines.append({"text": str(TranslationServer.translate("einer von:")), "have": null, "new": false, "indent": 0})
			var got: Variant = null
			for alt in ing.any_of:
				got = _take(pool, alt)
				if got != null:
					break
			for alt in ing.any_of:
				var match_got: bool = got != null and got[0] == str(alt.get("tower", "")) and int(got[1]) == int(alt.get("tier", 0))
				var h := match_got or pool.any(func(o): return o[0] == str(alt.get("tower", "")) and int(o[1]) == int(alt.get("tier", 0)))
				var n := _is_new(got) if match_got else false
				lines.append({"text": ingredient_label(alt), "have": h, "new": n, "indent": 1})
			if got == null:
				missing += 1
		else:
			lines.append({"text": ingredient_label(ing), "have": taken[i] != null, "new": _is_new(taken[i]), "indent": 0})
			if taken[i] == null:
				missing += 1
	return {"lines": lines, "missing": missing}


static func _matches(ing: Dictionary, id: String, tier: int) -> bool:
	if ing.has("any_of"):
		return (ing.any_of as Array).any(func(a): return _matches(a, id, tier))
	return str(ing.get("tower", "")) == id and int(ing.get("tier", 0)) == tier


## Ob das Rezept gerade jetzt baubar ist. now = {"pool": [[id, stufe]], "wave": bool}:
## während der Welle zählen die fertigen Tower auf dem Feld (ohne Rezepte nur aus einer Runde),
## beim Setzen und Auswählen nur die neuen Gems dieser Runde. Leeres now: alles zählt.
static func ready_now(id: String, owned: Array, now: Dictionary) -> bool:
	if now.is_empty():
		return status(id, owned).missing == 0
	if now.get("wave", false) and Database.towers.get(id, {}).get("recipe_same_round", false):
		return false
	return status(id, now.get("pool", [])).missing == 0


## Rezepte, in denen der Tower id/tier als Zutat vorkommt.
static func used_in(id: String, tier: int) -> Array:
	return ids().filter(func(sid): return (Database.towers[sid].get("recipe", []) as Array).any(func(ing): return _matches(ing, id, tier)))
