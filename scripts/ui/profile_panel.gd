class_name ProfilePanel
extends Control
## Profilseite im Warcraft-III-Stil über der 3D-Nachtszene des Hubs (Lukas 2026-11-01, Mockups unter
## /mnt/project-files/mockups/wc3-profil/): Übersicht wie Entwurf 6 (Heldenblatt: links Gesamtwerte, rechts Level
## und eine Karte je Modus), Klick auf einen Modus öffnet die Detailseite wie Entwurf 4 (Reiter, Kacheln, Rekorde,
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


# --- Übersicht (Entwurf 6) ---------------------------------------------------------------

func _overview() -> void:
	var t := Profile.totals()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	body.add_child(row)

	var left := Wc3Pillar.new(false, 430)
	row.add_child(left)
	var crest := CenterContainer.new()
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.box.add_child(crest)
	var gem := TextureRect.new()
	gem.texture = load(Wc3Pillar.GEM)
	gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.custom_minimum_size = Vector2(120, 120)
	crest.add_child(gem)
	var name_l := ProfileWc3.cin(_player_name(), left.box, 24)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var since := str(Profile.data().get("created", ""))
	if since.length() >= 10:
		var sl := ProfileWc3.body(tr("Profil seit %s") % RunHistoryPanel._date({"time": since}, true).get_slice(",", 0), left.box, 15, Wc3Theme.MUTED)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ProfileWc3.caption("Gesamt", left.box)
	ProfileWc3.kv(left.box, "Spielzeit", ProfileWc3.hours(int(t.play_time)))
	ProfileWc3.kv(left.box, "Runs", ProfileWc3.num(int(t.runs)))
	ProfileWc3.kv(left.box, "Siege", ProfileWc3.num(int(t.wins)), ProfileWc3.WIN)
	ProfileWc3.kv(left.box, "Niederlagen", ProfileWc3.num(int(t.losses)), ProfileWc3.LOSS)
	ProfileWc3.kv(left.box, "Siegquote", ProfileWc3.percent(int(t.wins), int(t.runs)))
	ProfileWc3.kv(left.box, "Abgebrochen", ProfileWc3.num(int(t.aborted)), Wc3Theme.MUTED)
	ProfileWc3.kv(left.box, "Kills", ProfileWc3.short(float(t.kills)))
	ProfileWc3.kv(left.box, "Gebaute Tower", ProfileWc3.num(int(t.built)))
	ProfileWc3.kv(left.box, "Gespielte Tage", ProfileWc3.num(Profile.data().daily.size()))
	if str(t.last_played) != "":
		ProfileWc3.kv(left.box, "Zuletzt gespielt", RunHistoryPanel._date({"time": t.last_played}), Wc3Theme.CREAM)

	var right := Wc3Pillar.new(false, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	scroll.add_child(inner)
	ProfileWc3.caption("Level", inner)
	for m in ["maul", "youtd"]:
		ProfileWc3.level_card(inner, m)
	ProfileWc3.body("GemTD, Roguelike, eeveTD und Randgruppen TD haben kein Spieler-Level, dort zählen Siege und Rekorde. Runs mit Debug-Menü geben keine EP.",
		inner, 14, Wc3Theme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ProfileWc3.caption("Modi", inner)
	var g := ProfileWc3.grid(inner, 3)
	for m in ProfileWc3.MODES:
		_mode_card(g, m[0])
	ProfileWc3.body("Klick auf einen Modus zeigt alle Werte.", inner, 14, Wc3Theme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer(right.box, func(): back_requested.emit())


func _mode_card(parent: Node, m: String) -> void:
	var md := Profile.mode(m)
	var card := Wc3Card.new()
	card.toggle_mode = false
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(220, 122)
	card.pressed.connect(show_view.bind(m))
	parent.add_child(card)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 12)
	card.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	ProfileWc3.gem(head, m, 20)
	var n := ProfileWc3.cin(ProfileWc3.tr_up(ProfileWc3.mode_name(m)), head, 14, Wc3Theme.MUTED, 2)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	var lv := ProfileWc3.level_info(m)
	if not lv.is_empty():
		ProfileWc3.cin("%s %s" % [lv.name, lv.value], head, 13, Wc3Theme.CREAM)
	ProfileWc3.cin(ProfileWc3.hours(int(md.play_time)), v, 24)
	var best := int(md.records.get("best_wave", {}).get("value", 0))
	ProfileWc3.body(tr("%d Runs · %d S / %d N · Welle %d") % [int(md.runs), int(md.wins), int(md.losses), best], v, 14, Wc3Theme.MUTED)


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
	ProfileWc3.caption("Letzte Runs", right)
	var list := Profile.runs(m).slice(0, 6)
	if list.is_empty():
		ProfileWc3.body("Noch keine Runs in diesem Modus.", right, 15, Wc3Theme.MUTED)
	for r in list:
		ProfileHistory.run_row(right, r, false)
	_footer(p.box, show_view.bind("overview"))


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
