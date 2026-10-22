class_name TowerStats
extends RefCounted
## Werte eines Towers fürs Infofenster: Kacheln (Reichweite, Tempo, Schaden, Schadensart),
## woher Boni kommen (für die Tooltips), Kill-Rang und der Vergleich mit einem Upgrade.
## Liest nur den Tower und Database; ändert nichts.


static func _t(text: String) -> String:
	return str(TranslationServer.translate(text))


## Zahl mit Komma auf Deutsch, z. B. 0,32.
static func num(v: float, digits := 1) -> String:
	var s := ("%." + str(digits) + "f") % v
	return s.replace(".", ",") if TranslationServer.get_locale().begins_with("de") else s


static func pct(v: float) -> String:
	return "+%d %%" % roundi(v * 100.0)


## Schaden als "55" oder "50–60".
static func dmg_text(lo: float, hi: float) -> String:
	return "%d" % roundi(lo) if roundi(lo) == roundi(hi) else "%d–%d" % [roundi(lo), roundi(hi)]


static func range_text(s: Dictionary, trap: bool) -> String:
	var r := float(s.get("range", 3.0))
	var text := ""
	if trap and r <= Board3D.TRAP_CELLS * Board3D.CELL:
		text = "%d×%d" % [Board3D.TRAP_CELLS, Board3D.TRAP_CELLS]
	else:
		text = num(r)
	if s.has("range_air"):
		text += " / " + _t("Luft") + " " + num(float(s.range_air))
	return text


static func can_attack(s: Dictionary) -> bool:
	var dmg: Array = s.get("damage", [0, 0])
	var wave_damage := false
	for ab in s.get("abilities", []):
		wave_damage = wave_damage or str(ab.get("type", "")) == "wave_damage"
	return float(s.get("cooldown", 0)) > 0.0 and (float(dmg[1]) > 0.0 or wave_damage)


static func targets_text(mode: String) -> String:
	match mode:
		"air":
			return _t("nur Luft")
		"ground":
			return _t("nur Boden")
	return _t("trifft Boden + Luft")


## Kill-Rang wie tower.kill_bonus(): Rang, Bonus jetzt, nächster Rang und Fortschritt dorthin.
static func kill_info(kills: int) -> Dictionary:
	var kr: Dictionary = Database.balance.get("kill_rank", {})
	var per := maxi(int(kr.get("kills_per_rank", 10)), 1)
	var step := float(kr.get("bonus_per_rank", 0.1))
	var cap := float(kr.get("max_bonus", 1.2))
	var rank := floori(kills / float(per))
	var bonus := minf(rank * step, cap) if not kr.is_empty() else 0.0
	var maxed := kr.is_empty() or step <= 0.0 or bonus >= cap - 0.0001
	return {"kills": kills, "rank": rank, "bonus": bonus, "per_rank": per, "step": step, "max": cap,
			"maxed": maxed, "next_at": (rank + 1) * per, "missing": (rank + 1) * per - kills,
			"next_bonus": minf((rank + 1) * step, cap), "progress": kills - rank * per}


## Alles fürs Infofenster eines Towers:
## {subtitle, tiles, abilities, description, kills (kill_info + total_damage, oder {} bei neuen Gems)}.
## tiles: [{key, caption, value, mod, rows, total}], rows: [[Text, Wert, Farbe]] mit Farbe "", "up" oder "muted".
static func view(t) -> Dictionary:
	var s: Dictionary = t.stats
	var trap: bool = t.is_trap()
	var kind := _t("Falle") if trap else (_t("Spezialtower") if str(t.def.get("category", "gem")) == "special" else _t("Gem"))
	var subtitle := kind + " · " + targets_text(t.target_mode())
	if trap and t.moves_left > 0:
		subtitle += " · " + _t("noch %d× verschiebbar") % t.moves_left
	var tiles := []
	var attack := can_attack(s)
	# Reichweite (wird nicht verändert); ohne Angriff zählt die Aura
	var reach := range_text(s, trap)
	if not attack and t._aura_radius() > 0.0:
		reach = num(t._aura_radius())
	var range_rows := [[_t("Grundwert"), reach, ""]]
	var range_total := []
	if t.rogue_range > 0.0 and attack:
		var boosted := s.duplicate()
		boosted.range = float(s.get("range", 3.0)) * (1.0 + t.rogue_range)
		if s.has("range_air"):
			boosted.range_air = float(s.range_air) * (1.0 + t.rogue_range)
		range_rows.append([_t("Roguelike-Bonus"), pct(t.rogue_range), "up"])
		reach = range_text(boosted, trap)
		range_total = [_t("Gesamt"), reach]
	tiles.append({"key": "range", "caption": _t("Reichweite"), "value": reach, "mod": t.rogue_range > 0.0 and attack,
			"rows": range_rows, "total": range_total})
	if attack:
		var base_cd := float(s.get("cooldown", 1.0))
		var rows := [[_t("Grundwert"), num(base_cd, 2) + " s", ""]]
		if t.speed_bonus > 0.0:
			rows.append([(t.speed_source if t.speed_source != "" else _t("Tempo")) + " " + _t("(Aura)"), pct(t.speed_bonus), "up"])
		if t.rogue_speed > 0.0:
			rows.append([_t("Roguelike-Bonus"), pct(t.rogue_speed), "up"])
		tiles.append({"key": "speed", "caption": _t("Tempo"), "value": num(t.cooldown(), 2) + " s", "mod": t.speed_bonus + t.rogue_speed > 0.0,
				"rows": rows, "total": [_t("Gesamt"), num(t.cooldown(), 2) + " s"]})
		var dmg: Array = s.get("damage", [0, 0])
		var lo := float(dmg[0])
		var hi := float(dmg[1])
		var drows := [[_t("Grundwert"), dmg_text(lo, hi), ""]]
		var wd: Dictionary = t.ability("wave_damage")
		if not wd.is_empty() and t.game != null:
			var extra: float = float(wd.per_wave) * t.game.current_wave()
			lo += extra
			hi += extra
			drows.append([_t("Wellenbonus · Welle %d") % t.game.current_wave(), "+%d" % roundi(extra), "up"])
		var kb: float = t.kill_bonus()
		if kb > 0.0:
			drows.append([_t("Kills · Rang %d") % kill_info(t.kills).rank, pct(kb), "up"])
		if t.damage_bonus > 0.0:
			drows.append([(t.damage_source if t.damage_source != "" else _t("Schaden")) + " " + _t("(Aura)"), pct(t.damage_bonus), "up"])
		if t.rogue_damage > 0.0:
			drows.append([_t("Roguelike-Bonus"), pct(t.rogue_damage), "up"])
		var f: float = 1.0 + t.damage_bonus + kb + t.rogue_damage
		var total := dmg_text(lo * f, hi * f)
		tiles.append({"key": "damage", "caption": _t("Schaden"), "value": total, "mod": drows.size() > 1,
				"rows": drows, "total": [_t("Gesamt"), total]})
		var dt: String = t.damage_type()
		tiles.append({"key": "type", "caption": _t("Schadensart"),
				"value": _t(Database.DAMAGE_TYPE_NAMES.get(dt, dt)) if dt != "" else "–", "mod": false, "rows": [], "total": []})
	var kills := {}
	if not t.is_new:
		kills = kill_info(t.kills)
		kills.total_damage = t.total_damage
	return {"subtitle": subtitle, "tiles": tiles, "kills": kills,
			"abilities": t.abilities().map(func(ab): return Abilities.describe(ab))
				+ t.rogue_fx.get("flasks", []).map(func(f): return _t(str(f.get("name", ""))) + ": " + Rogue._flask_text(f)),
			"description": _t(str(t.def.description)) if t.def.has("description") else ""}


## Was sich ändert, wenn aus Tower t der Tower id/tier wird (Grundwerte ohne Aura- und Kill-Bonus).
## [{label, old, new, dir}] mit dir 1 = besser, -1 = schlechter, 0 = anders; Fähigkeiten mit leerem old.
static func diff(t, id: String, tier: int) -> Array:
	var a: Dictionary = t.stats
	var b: Dictionary = Database.tower_tier(id, tier)
	var def: Dictionary = Database.towers.get(id, {})
	var trap_a: bool = t.is_trap()
	var trap_b := str(def.get("kind", "tower")) == "trap"
	var out := []
	var ra := range_text(a, trap_a)
	var rb := range_text(b, trap_b)
	if ra != rb:
		out.append({"label": _t("Reichweite"), "old": ra, "new": rb,
				"dir": int(signf(Tower.ring_radius(b, trap_b) - Tower.ring_radius(a, trap_a)))})
	var att_a := can_attack(a)
	var att_b := can_attack(b)
	if att_a or att_b:
		var ca := float(a.get("cooldown", 0))
		var cb := float(b.get("cooldown", 0))
		if not is_equal_approx(ca, cb) or att_a != att_b:
			out.append({"label": _t("Tempo"), "old": num(ca, 2) + " s" if att_a else "–", "new": num(cb, 2) + " s" if att_b else "–",
					"dir": (1 if cb < ca else -1) if att_a and att_b else (1 if att_b else -1)})
		var da: Array = a.get("damage", [0, 0])
		var db: Array = b.get("damage", [0, 0])
		var ta := dmg_text(float(da[0]), float(da[1])) if att_a else "–"
		var tb := dmg_text(float(db[0]), float(db[1])) if att_b else "–"
		if ta != tb:
			var avg_a := (float(da[0]) + float(da[1])) if att_a else 0.0
			var avg_b := (float(db[0]) + float(db[1])) if att_b else 0.0
			out.append({"label": _t("Schaden"), "old": ta, "new": tb, "dir": int(signf(avg_b - avg_a))})
		var dta := str(a.get("damage_type", t.def.get("damage_type", "")))
		var dtb := str(b.get("damage_type", def.get("damage_type", "")))
		if dta != dtb and att_b:
			out.append({"label": _t("Schadensart"), "old": _t(Database.DAMAGE_TYPE_NAMES.get(dta, dta)) if dta != "" else "–",
					"new": _t(Database.DAMAGE_TYPE_NAMES.get(dtb, dtb)) if dtb != "" else "–", "dir": 0})
	var ma := str(a.get("targets", t.def.get("targets", "both")))
	var mb := str(b.get("targets", def.get("targets", "both")))
	if ma != mb:
		out.append({"label": _t("Ziele"), "old": targets_text(ma), "new": targets_text(mb), "dir": 1 if mb == "both" else (-1 if ma == "both" else 0)})
	# Fähigkeiten: gleiche Art mit anderen Werten als alt → neu, sonst weggefallen (−) oder neu (+)
	var old_ab: Array = a.get("abilities", [])
	var new_ab: Array = b.get("abilities", [])
	var types_new: Array = new_ab.map(func(ab): return str(ab.get("type", "")))
	var types_old: Array = old_ab.map(func(ab): return str(ab.get("type", "")))
	for ab in old_ab:
		var i := types_new.find(str(ab.get("type", "")))
		if i < 0:
			out.append({"label": "", "old": "", "new": "− " + Abilities.describe(ab), "dir": -1})
		elif Abilities.describe(ab) != Abilities.describe(new_ab[i]):
			out.append({"label": "", "old": Abilities.describe(ab), "new": Abilities.describe(new_ab[i]), "dir": 0})
	for ab in new_ab:
		if not types_old.has(str(ab.get("type", ""))):
			out.append({"label": "", "old": "", "new": "+ " + Abilities.describe(ab), "dir": 1})
	return out
