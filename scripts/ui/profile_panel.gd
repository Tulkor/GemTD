class_name ProfilePanel
extends Control
## Profilseite im Warcraft-III-Stil über der 3D-Nachtszene des Hubs (Lukas 2026-11-01, Mockups unter
## /mnt/project-files/mockups/wc3-profil/): Übersicht wie Entwurf 5 (Spielzeit groß, eine Zeile je Modus mit
## Balken, Zeit, Runs, S/N, Welle und Level), Klick auf einen Modus öffnet die Detailseite wie Entwurf 4 (Reiter, Kacheln, Rekorde,
## Tower, letzte Runs), unten links geht es zur Run-History wie Entwurf 9 (profile_history.gd).
## Gezeigt wird das Wichtigste; gespeichert ist viel mehr (profile.gd, jeder Run unter user://profile/runs/).

signal back_requested
signal replay_requested(run: Dictionary)

const RECORDS := [
	["most_kills", "Meiste Kills"],
	["best_score", "Meiste Punkte"],
	["longest_path", "Längster Weg"],
	["tower_damage_run", "Stärkster Tower (Run)"],
	["tower_kills_run", "Meiste Kills eines Towers"],
	["tower_damage_wave", "Stärkster Tower (Welle)"],
	["wave_damage", "Stärkste Welle"],
	["fastest_win", "Schnellster Sieg"],
]

## Bau-Aktionen aus run_stats.gd
const ACTIONS := {"keep": "Gems behalten", "combine": "Kombiniert", "build": "Gebaut", "upgrade": "Aufgewertet",
	"trap": "Fallen", "copy": "Kopiert", "special": "Sondertower", "downgrade": "Abgestuft",
	"move": "Verschoben", "swap": "Getauscht", "take_back": "Zurückgenommen"}

## "overview", "history" oder ein Modus-Schlüssel (Detailseite)
var view := "overview"
var title: Label
var body: MarginContainer
var tabs: HBoxContainer
var _history_from := "overview"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0, 0, 0, 0.45)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	var a := ProfileWc3.rule()
	a.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	a.custom_minimum_size.x = 110
	head.add_child(a)
	Wc3Theme.label("◆", head, 16, Wc3Theme.GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title = Wc3Theme.label("", head, 40, Wc3Theme.GOLD_HI, 6)
	Wc3Theme.label("◆", head, 16, Wc3Theme.GOLD).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := ProfileWc3.rule()
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size.x = 110
	head.add_child(b)
	body = MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	show_view(view)


func reload() -> void:
	if body != null:
		show_view(view)


func show_history() -> void:
	_history_from = view if view != "history" else _history_from
	show_view("history")


func show_view(v: String) -> void:
	view = v
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	tabs = null
	if v == "overview":
		title.text = _player_name().to_upper()
		_overview()
	elif v == "history":
		title.text = ProfileWc3.tr_up("Rekorde und Verlauf")
		var h := ProfileHistory.new()
		h.back_requested.connect(func(): show_view(_history_from))
		h.replay_requested.connect(func(r): replay_requested.emit(r))
		body.add_child(h)
	else:
		title.text = ProfileWc3.tr_up(ProfileWc3.mode_name(v))
		_detail(v)


func _player_name() -> String:
	var n := str(Profile.data().get("name", ""))
	if n == "":
		n = str(Net.my_name)
	return n if n != "" else tr("Profil")


## Fußzeile: links Run-History, Mitte Siegel, rechts Zurück.
func _footer(parent: Node, on_back: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var hist := Wc3Button.new("Run-History", false)
	hist.custom_minimum_size.x = 230
	hist.pressed.connect(show_history)
	row.add_child(hist)
	var seal := ProfileWc3.cin(_seal_text(), row, 12, Wc3Theme.MUTED, 2)
	seal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back := Wc3Button.new("Zurück", false)
	back.custom_minimum_size.x = 200
	back.pressed.connect(on_back)
	row.add_child(back)


func _seal_text() -> String:
	if Profile.sealed():
		return tr("PROFIL VERSIEGELT · PRÜFSUMME ✓ GÜLTIG")
	return tr("PROFIL VON HAND GEÄNDERT · PRÜFSUMME ✗")


# --- Übersicht (Entwurf 5) ---------------------------------------------------------------

## Spielzeit im Mittelpunkt (Lukas 2026-11-01): oben die Gesamtzeit groß mit Runs, Siegen und Kills,
## darunter eine Zeile je Modus mit Balken (Anteil an der Spielzeit), Zeit, Runs, S/N, höchster Welle und Level.
func _overview() -> void:
	var t := Profile.totals()
	var p := Wc3Pillar.new(false, 0)
	body.add_child(p)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	p.box.add_child(top)
	var big := VBoxContainer.new()
	big.custom_minimum_size.x = 400
	big.add_theme_constant_override("separation", 0)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(big)
	ProfileWc3.cin(ProfileWc3.tr_up("Spielzeit gesamt"), big, 15, Wc3Theme.MUTED, 3).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var total := ProfileWc3.cin(ProfileWc3.hours(int(t.play_time)), big, 54, Wc3Theme.HOT, 2)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var days: int = Profile.data().daily.size()
	var sub := tr("%s Tage gespielt") % ProfileWc3.num(days)
	if days > 0:
		sub += " · " + tr("Ø %s pro Tag") % ProfileWc3.hours(int(t.play_time) / days)
	ProfileWc3.body(sub, big, 15, Wc3Theme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tiles := HBoxContainer.new()
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("separation", 10)
	top.add_child(tiles)
	ProfileWc3.tile(tiles, "Runs", ProfileWc3.num(int(t.runs)), tr("%d abgebrochen · %d mit Debug") % [int(t.aborted), int(t.debug_runs)])
	ProfileWc3.tile(tiles, "Siege / Niederlagen", "%s / %s" % [ProfileWc3.num(int(t.wins)), ProfileWc3.num(int(t.losses))],
		tr("%s Siegquote") % ProfileWc3.percent(int(t.wins), int(t.runs)))
	ProfileWc3.tile(tiles, "Kills", ProfileWc3.short(float(t.kills)), tr("%s Tower gebaut") % ProfileWc3.num(int(t.built)))

	ProfileWc3.caption("Zeit und Runs je Modus", p.box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for x in ProfileWc3.MODES:
		_mode_row(rows, x[0], int(t.play_time))
	ProfileWc3.body("Klick auf einen Modus zeigt alle Werte. Runs mit Debug-Menü geben keine EP.", p.box, 14, Wc3Theme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer(p.box, func(): back_requested.emit())


## Zeile je Modus: Edelstein und Name, Balken (Anteil an der Spielzeit), Zeit, Runs, S/N, Welle, Level. Klick → Detailseite.
func _mode_row(parent: Node, m: String, total_time: int) -> void:
	var md := Profile.mode(m)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 58
	b.add_theme_stylebox_override("normal", ProfileWc3.flat(ProfileWc3.ROW_BG, Color(Wc3Theme.GOLD_LO, 0.5), 0))
	b.add_theme_stylebox_override("hover", ProfileWc3.flat(Color(Wc3Theme.DARK_HOVER, 0.8), Wc3Theme.GOLD, 0))
	b.add_theme_stylebox_override("pressed", ProfileWc3.flat(Color(Wc3Theme.DARK_HOVER, 0.9), Wc3Theme.GOLD_HI, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(show_view.bind(m))
	parent.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	ProfileWc3.gem(row, m, 24)
	var name_l := ProfileWc3.cin(tr(ProfileWc3.mode_name(m)), row, 17)
	name_l.custom_minimum_size.x = 190
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar := ProfileWc3.Bar.new()
	bar.frac = float(md.play_time) / maxf(total_time, 1)
	bar.color = ProfileWc3.mode_color(m)
	bar.text = ProfileWc3.percent(int(md.play_time), total_time)
	bar.custom_minimum_size = Vector2(160, 24)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var cells := [[ProfileWc3.hours(int(md.play_time)), 130, Wc3Theme.GOLD_HI],
		[tr("%d Runs") % int(md.runs), 90, Wc3Theme.CREAM],
		["%d / %d" % [int(md.wins), int(md.losses)], 90, Wc3Theme.CREAM],
		[tr("Welle %d") % int(md.records.get("best_wave", {}).get("value", 0)), 100, Wc3Theme.CREAM]]
	for c in cells:
		var l := ProfileWc3.cin(c[0], row, 16, c[2])
		l.custom_minimum_size.x = c[1]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Level nur, wo der Modus eines hat (Maul-XP, YouTD-Spielerlevel)
	var lv := ProfileWc3.level_info(m)
	var lvl_box := HBoxContainer.new()
	lvl_box.custom_minimum_size.x = 200
	lvl_box.add_theme_constant_override("separation", 8)
	lvl_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lvl_box)
	if not lv.is_empty():
		var d := ProfileWc3.LevelDiamond.new()
		d.level = int(lv.level)
		d.tint = ProfileWc3.mode_color(m)
		d.custom_minimum_size = Vector2(48, 48)
		lvl_box.add_child(d)
		var lb := VBoxContainer.new()
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.alignment = BoxContainer.ALIGNMENT_CENTER
		lb.add_theme_constant_override("separation", 3)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lvl_box.add_child(lb)
		ProfileWc3.cin("%s %s" % [lv.name, lv.value], lb, 13, Wc3Theme.CREAM)
		var lbar := ProfileWc3.Bar.new()
		lbar.frac = float(lv.frac)
		lbar.color = ProfileWc3.mode_color(m)
		lbar.custom_minimum_size.y = 8
		lb.add_child(lbar)


# --- Detail je Modus (Entwurf 4) ---------------------------------------------------------

func _detail(m: String) -> void:
	var p := Wc3Pillar.new(false, 0)
	body.add_child(p)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	p.box.add_child(tabs)
	var all := Wc3Button.new("Übersicht", false)
	all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all.pressed.connect(show_view.bind("overview"))
	tabs.add_child(all)
	for x in ProfileWc3.MODES:
		var b := Wc3Button.new(ProfileWc3.short_name(x[0]), false)
		b.toggle_mode = true
		b.set_pressed_no_signal(x[0] == m)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 46
		b.pressed.connect(show_view.bind(x[0]))
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.box.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	scroll.add_child(cols)

	var md := Profile.mode(m)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 520
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	ProfileWc3.caption(ProfileWc3.mode_name(m), left)
	var runs := int(md.runs)
	var g := ProfileWc3.grid(left, 2)
	ProfileWc3.tile(g, "Spielzeit", ProfileWc3.hours(int(md.play_time)),
		tr("Ø %s pro Run") % ProfileWc3.duration(int(md.play_time) / maxi(runs + int(md.aborted), 1)))
	ProfileWc3.tile(g, "Runs", ProfileWc3.num(runs), tr("%d abgebrochen · %d mit Debug") % [int(md.aborted), int(md.debug_runs)])
	ProfileWc3.tile(g, "Siege", ProfileWc3.num(int(md.wins)), tr("%s Siegquote") % ProfileWc3.percent(int(md.wins), runs), ProfileWc3.WIN)
	ProfileWc3.tile(g, "Niederlagen", ProfileWc3.num(int(md.losses)), tr("Beste Siegesserie %d") % int(md.best_streak), ProfileWc3.LOSS)
	var best: Dictionary = md.best_run
	var best_wave := int(md.records.get("best_wave", {}).get("value", 0))
	ProfileWc3.tile(g, "Höchste Welle" if m != "maul" else "Höchstes Level",
		"%d / %d" % [best_wave, int(best.get("waves", best_wave))] if best_wave > 0 else "–",
		tr("%s Wellen insgesamt") % ProfileWc3.num(int(md.waves)))
	var fast: Dictionary = md.records.get("fastest_win", {})
	ProfileWc3.tile(g, "Schnellster Sieg", ProfileWc3.duration(int(fast.value)) if not fast.is_empty() else "–",
		ProfileWc3.difficulty(best) if not best.is_empty() else "")
	if not ProfileWc3.level_info(m).is_empty():
		ProfileWc3.caption("Level", left)
		ProfileWc3.level_card(left, m)
	_groups(left, md.by_difficulty, "Je Schwierigkeit", m)
	_groups(left, md.by_map, "Je Filiale" if m == "maul" else "Je Map", m)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	ProfileWc3.caption("Rekorde", right)
	_records(right, md.records)
	ProfileWc3.caption("Stärkste Tower", right)
	_towers(right, m)
	ProfileWc3.caption("Statistiken", right)
	_stats(right, m, md)
	if not (md.actions as Dictionary).is_empty():
		ProfileWc3.caption("Bauen", right)
		var ag := ProfileWc3.grid(right, 3)
		var keys: Array = md.actions.keys()
		keys.sort_custom(func(x, y): return int(md.actions[x]) > int(md.actions[y]))
		for k in keys:
			ProfileWc3.tile(ag, ACTIONS.get(k, str(k)), ProfileWc3.num(int(md.actions[k])))
	_footer(p.box, show_view.bind("overview"))


## Weitere Werte eines Modus, teils aus der Run-Liste gerechnet (Durchschnitte, längster Run).
func _stats(parent: Node, m: String, md: Dictionary) -> void:
	var runs := int(md.runs)
	var n := maxi(runs, 1)
	var waves_sum := 0
	var longest := 0
	var counted := 0
	var last20 := 0
	var last20_wins := 0
	for r in Profile.runs(m):
		if r.get("debug", false) or r.get("aborted", false):
			continue
		counted += 1
		waves_sum += int(r.get("wave", 0))
		longest = maxi(longest, int(r.get("play_time", 0)))
		if last20 < 20:
			last20 += 1
			last20_wins += 1 if r.get("victory", false) else 0
	var g := ProfileWc3.grid(parent, 3)
	ProfileWc3.tile(g, "Kills", ProfileWc3.short(float(md.kills)), tr("Ø %s pro Run") % ProfileWc3.num(int(md.kills) / n))
	ProfileWc3.tile(g, "Schaden", ProfileWc3.short(float(md.damage)), tr("Ø %s pro Run") % ProfileWc3.short(float(md.damage) / n))
	ProfileWc3.tile(g, "Tower gebaut", ProfileWc3.num(int(md.built)), tr("Ø %s pro Run") % ProfileWc3.num(int(md.built) / n))
	ProfileWc3.tile(g, "Ø erreichte Welle", String.num(float(waves_sum) / maxi(counted, 1), 1).replace(".", ","),
		tr("%s Wellen insgesamt") % ProfileWc3.num(int(md.waves)))
	ProfileWc3.tile(g, "Leben verloren", ProfileWc3.num(int(md.leaks)), tr("Ø %s pro Run") % String.num(float(md.leaks) / n, 1).replace(".", ","))
	ProfileWc3.tile(g, "Letzte 20 Runs", ProfileWc3.percent(last20_wins, last20), tr("%d von %d gewonnen") % [last20_wins, last20])
	ProfileWc3.tile(g, "Längster Run", ProfileWc3.duration(longest) if longest > 0 else "–", "")
	ProfileWc3.tile(g, "Siegesserie", str(int(md.streak)), tr("Beste Siegesserie %d") % int(md.best_streak))
	ProfileWc3.tile(g, "Zeit mit Debug", ProfileWc3.hours(int(md.debug_time)), tr("%d Runs ohne EP") % int(md.debug_runs))
	var first := str(md.get("first_played", ""))
	var last := str(md.get("last_played", ""))
	ProfileWc3.tile(g, "Zuerst gespielt", RunHistoryPanel._date({"time": first}, true).get_slice(",", 0) if first != "" else "–", "")
	ProfileWc3.tile(g, "Zuletzt gespielt", RunHistoryPanel._date({"time": last}) if last != "" else "–", "")
	var best: Dictionary = md.best_run
	ProfileWc3.tile(g, "Bester Run", tr("Welle %d / %d") % [int(best.get("wave", 0)), int(best.get("waves", 0))] if not best.is_empty() else "–",
		str(best.get("map", "")))


func _groups(parent: Node, groups: Dictionary, caption_de: String, m: String) -> void:
	if groups.is_empty():
		return
	ProfileWc3.caption(caption_de, parent)
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return int(groups[a].get("runs", 0)) > int(groups[b].get("runs", 0)))
	for k in keys.slice(0, 6):
		var s: Dictionary = groups[k]
		var name: String = str(k)
		if caption_de == "Je Schwierigkeit":
			name = ProfileWc3.difficulty({"mode": m, "difficulty": int(k)})
		elif m == "maul":
			name = MaulData.name_of(MaulData.shop(name), name)
		ProfileWc3.kv(parent, name, tr("%d Runs · %d S · Welle %d") % [int(s.get("runs", 0)), int(s.get("wins", 0)), int(s.get("best_wave", 0))],
			Wc3Theme.CREAM)


func _records(parent: Node, rec: Dictionary) -> void:
	var g := ProfileWc3.grid(parent, 3)
	var any := false
	for r in RECORDS:
		if not rec.has(r[0]):
			continue
		any = true
		var d: Dictionary = rec[r[0]]
		var v := float(d.value)
		var value := ProfileWc3.duration(int(v)) if r[0] == "fastest_win" else ProfileWc3.short(v)
		var sub := ""
		if d.has("label"):
			sub = tr(str(d.label))
		if d.has("wave") and int(d.wave) > 0:
			sub += (" · " if sub != "" else "") + tr("Welle %d") % int(d.wave)
		if r[0] == "longest_path":
			value = tr("%s Felder") % ProfileWc3.num(roundi(v))
		ProfileWc3.tile(g, r[1], value, sub)
	if not any:
		ProfileWc3.body("Noch keine Rekorde.", parent, 15, Wc3Theme.MUTED)


func _towers(parent: Node, m: String) -> void:
	var ts := Profile.towers(m)
	if ts.is_empty():
		ProfileWc3.body("Noch keine Tower in diesem Modus.", parent, 15, Wc3Theme.MUTED)
		return
	var ids := ts.keys()
	ids.sort_custom(func(a, b): return float(ts[a].get("damage", 0)) > float(ts[b].get("damage", 0)))
	for id in ids.slice(0, 6):
		var d: Dictionary = ts[id]
		ProfileWc3.kv(parent, _tower_name(m, id), tr("%s gebaut · %s Kills · %s Schaden") % [ProfileWc3.num(int(d.get("built", 0))),
			ProfileWc3.num(int(d.get("kills", 0))), ProfileWc3.short(float(d.get("damage", 0)))], Wc3Theme.CREAM)


func _tower_name(m: String, id: String) -> String:
	if m == "maul":
		return str(MaulData.tower(id).get("name", id))
	return Database.tower_label(id, 0) if Database.towers.has(id) else id
