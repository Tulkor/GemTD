class_name Recipes
extends RefCounted
## Spezial-Rezepte für die Oberfläche: was gebraucht wird, was man schon hat, was fehlt.
## owned ist eine Liste von [tower_id, stufe] (Tower auf dem Feld plus neue Gems der Runde).


## IDs aller Spezial-Tower mit Rezept.
static func ids() -> Array:
	return Database.special_ids().filter(func(id): return not (Database.towers[id].get("recipe", []) as Array).is_empty())


static func ingredient_label(ing: Dictionary) -> String:
	return Database.tower_label(str(ing.get("tower", "")), int(ing.get("tier", 0)))


static func _take(pool: Array, ing: Dictionary) -> bool:
	for i in pool.size():
		if pool[i][0] == str(ing.get("tower", "")) and int(pool[i][1]) == int(ing.get("tier", 0)):
			pool.remove_at(i)
			return true
	return false


## Rückgabe: {"lines": [{"text", "have", "indent"}], "missing": int}.
## have ist null für Zwischenzeilen wie "einer von:".
static func status(id: String, owned: Array) -> Dictionary:
	var recipe: Array = Database.towers.get(id, {}).get("recipe", [])
	var pool := owned.duplicate()
	var have := []
	have.resize(recipe.size())
	# Erst die festen Zutaten, dann die Auswahl-Zutaten, damit "einer von" keine feste Zutat wegnimmt.
	for i in recipe.size():
		if not recipe[i].has("any_of"):
			have[i] = _take(pool, recipe[i])
	var lines := []
	var missing := 0
	for i in recipe.size():
		var ing: Dictionary = recipe[i]
		if ing.has("any_of"):
			lines.append({"text": "einer von:", "have": null, "indent": 0})
			var any := false
			for alt in ing.any_of:
				var h := pool.any(func(o): return o[0] == str(alt.get("tower", "")) and int(o[1]) == int(alt.get("tier", 0)))
				lines.append({"text": ingredient_label(alt), "have": h, "indent": 1})
				any = any or h
			if any:
				for alt in ing.any_of:
					if _take(pool, alt):
						break
			else:
				missing += 1
		else:
			lines.append({"text": ingredient_label(ing), "have": have[i], "indent": 0})
			if not have[i]:
				missing += 1
	return {"lines": lines, "missing": missing}


static func _matches(ing: Dictionary, id: String, tier: int) -> bool:
	if ing.has("any_of"):
		return (ing.any_of as Array).any(func(a): return _matches(a, id, tier))
	return str(ing.get("tower", "")) == id and int(ing.get("tier", 0)) == tier


## Rezepte, in denen der Tower id/tier als Zutat vorkommt.
static func used_in(id: String, tier: int) -> Array:
	return ids().filter(func(sid): return (Database.towers[sid].get("recipe", []) as Array).any(func(ing): return _matches(ing, id, tier)))
