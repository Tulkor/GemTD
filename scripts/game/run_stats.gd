class_name RunStats
extends RefCounted
## Statistik eines laufenden Spiels fürs Profil (profile.gd), in allen Modi gleich: je Tower-Art
## gebaut (mit Stufe), Schaden und Kills, je Tower und je Welle Schaden und Kills. Schaden und
## Kills werden der Tower-Art gutgeschrieben, die der Tower beim Austeilen hatte: vor jedem Umbau
## (Kombinieren, Aufwerten) ruft das Spiel flush() und danach rebase(), die beim Kombinieren
## übernommenen Kills zählen so nicht doppelt. Koop-Mitspieler rechnen nichts selbst, bei ihnen
## kommt beim Ende alles auf einmal an (flush ohne Basis), Wellenwerte fehlen dort.

var base := {}      ## Instanz-ID → [tower_id, tier, Schaden, Kills] beim letzten flush
var towers := {}    ## Instanz-ID → Werte eines Towers in diesem Spiel (siehe _tower)
var types := {}     ## tower_id → {built, tiers: {Stufe: Anzahl}, damage, kills, best_wave_damage, best_wave}
var waves := []     ## je beendeter Welle: {wave, damage, kills, leaks, towers: [[uid, id, tier, Schaden, Kills]]}
var actions := {}   ## keep/combine/upgrade/build → Anzahl
var _wave := {}     ## Instanz-ID → [Schaden, Kills] der laufenden Welle
var _next_uid := 1


func _uid(t) -> int:
	var key: int = t.get_instance_id()
	if not towers.has(key):
		towers[key] = {"uid": _next_uid, "id": t.tower_id, "tier": t.tier, "label": t.label(),
			"color": t.color.to_html(false) if "color" in t else "", "damage": 0.0, "kills": 0,
			"best_wave_damage": 0.0, "best_wave": 0, "built_wave": -1}
		_next_uid += 1
	return key


func _type(id: String) -> Dictionary:
	if not types.has(id):
		types[id] = {"built": 0, "tiers": {}, "damage": 0.0, "kills": 0, "best_wave_damage": 0.0, "best_wave": 0}
	return types[id]


## Ein Tower ist entstanden oder umgebaut (action: keep, combine, upgrade, build). Vorher flush(t).
func built(t, action: String, wave: int) -> void:
	rebase(t)
	var ty := _type(t.tower_id)
	ty.built += 1
	var k := str(t.tier)
	ty.tiers[k] = int(ty.tiers.get(k, 0)) + 1
	actions[action] = int(actions.get(action, 0)) + 1
	var tw: Dictionary = towers[_uid(t)]
	if int(tw.built_wave) < 0:
		tw.built_wave = wave


## Schaden und Kills seit dem letzten Aufruf der bisherigen Tower-Art gutschreiben.
func flush(t) -> void:
	if t == null or not is_instance_valid(t):
		return
	var key := _uid(t)
	var b: Array = base.get(key, [t.tower_id, t.tier, 0.0, 0])
	var dmg := maxf(float(t.total_damage) - float(b[2]), 0.0)
	var kills := maxi(int(t.kills) - int(b[3]), 0)
	base[key] = [t.tower_id, t.tier, float(t.total_damage), int(t.kills)]
	if dmg <= 0.0 and kills == 0:
		return
	var ty := _type(str(b[0]))
	ty.damage += dmg
	ty.kills += kills
	var tw: Dictionary = towers[key]
	tw.damage += dmg
	tw.kills += kills
	var w: Array = _wave.get(key, [0.0, 0])
	_wave[key] = [float(w[0]) + dmg, int(w[1]) + kills]


## Neuer Stand nach einem Umbau: übernommene Kills sind nicht neu.
func rebase(t) -> void:
	var key := _uid(t)
	base[key] = [t.tower_id, t.tier, float(t.total_damage), int(t.kills)]
	var tw: Dictionary = towers[key]
	tw.id = t.tower_id
	tw.tier = t.tier
	tw.label = t.label()


## Ende einer Welle (wave ab 1).
func wave_done(list: Array, wave: int, leaks := 0, killed := 0) -> void:
	for t in list:
		flush(t)
	var rows := []
	var total := 0.0
	for key in _wave:
		var w: Array = _wave[key]
		var tw: Dictionary = towers[key]
		var b: Array = base.get(key, [tw.id, tw.tier, 0, 0])
		rows.append([int(tw.uid), str(b[0]), int(b[1]), roundf(float(w[0])), int(w[1])])
		total += float(w[0])
		if float(w[0]) > float(tw.best_wave_damage):
			tw.best_wave_damage = float(w[0])
			tw.best_wave = wave
		var ty := _type(str(b[0]))
		if float(w[0]) > float(ty.best_wave_damage):
			ty.best_wave_damage = float(w[0])
			ty.best_wave = wave
	rows.sort_custom(func(a, b): return a[3] > b[3])
	waves.append({"wave": wave, "damage": roundf(total), "kills": killed, "leaks": leaks, "towers": rows})
	_wave.clear()


## Alles fürs Profil. list: Tower am Ende (die anderen wurden zu Steinen oder verbraucht).
func result(list: Array) -> Dictionary:
	for t in list:
		flush(t)
	var alive := {}
	for t in list:
		if is_instance_valid(t):
			alive[t.get_instance_id()] = true
	var ts := []
	for key in towers:
		var tw: Dictionary = towers[key].duplicate()
		tw.damage = roundf(float(tw.damage))
		tw.best_wave_damage = roundf(float(tw.best_wave_damage))
		tw.alive = alive.has(key)
		ts.append(tw)
	ts.sort_custom(func(a, b): return a.damage > b.damage)
	var ty := {}
	for id in types:
		var d: Dictionary = types[id].duplicate(true)
		d.damage = roundf(float(d.damage))
		d.best_wave_damage = roundf(float(d.best_wave_damage))
		d.alive = 0
		ty[id] = d
	for t in list:
		if is_instance_valid(t):
			ty[t.tower_id] = ty.get(t.tower_id, _blank_type())
			ty[t.tower_id].alive = int(ty[t.tower_id].alive) + 1
	return {"towers": ts, "types": ty, "wave_log": waves.duplicate(true), "actions": actions.duplicate()}


func _blank_type() -> Dictionary:
	return {"built": 0, "tiers": {}, "damage": 0.0, "kills": 0, "best_wave_damage": 0.0, "best_wave": 0, "alive": 0}


## Für Spielstände: Tower über ihre Nummer in list (Reihenfolge wie im Spielstand).
func capture(list: Array) -> Dictionary:
	var tw := {}
	for i in list.size():
		var key: int = list[i].get_instance_id()
		if towers.has(key):
			tw[str(i)] = {"t": towers[key], "b": base.get(key, []), "w": _wave.get(key, [])}
	var gone := []
	var alive_keys := list.map(func(t): return t.get_instance_id())
	for key in towers:
		if not alive_keys.has(key):
			gone.append(towers[key])
	return {"towers": tw, "gone": gone, "types": types, "waves": waves, "actions": actions, "next": _next_uid}


func restore(d: Dictionary, made: Array) -> void:
	types = d.get("types", {}).duplicate(true)
	waves = d.get("waves", []).duplicate(true)
	actions = d.get("actions", {}).duplicate()
	_next_uid = int(d.get("next", 1))
	towers.clear()
	base.clear()
	_wave.clear()
	var fake := -1
	for g in d.get("gone", []):
		towers[fake] = g.duplicate()
		fake -= 1
	var tw: Dictionary = d.get("towers", {})
	for k in tw:
		var i := int(k)
		if i < 0 or i >= made.size() or made[i] == null:
			continue
		var key: int = made[i].get_instance_id()
		towers[key] = tw[k].t.duplicate()
		if not tw[k].b.is_empty():
			base[key] = tw[k].b.duplicate()
		if not tw[k].w.is_empty():
			_wave[key] = tw[k].w.duplicate()
