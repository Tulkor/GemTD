class_name ProfilePanel
extends VBoxContainer
## Profil im Hauptmenü (Art déco): Reiter Übersicht, je Modus und Tower. Zeigt nur das Wichtigste,
## gespeichert ist viel mehr (profile.gd, jeder Run komplett unter user://profile/runs/).

const MODE_TABS := [["gemtd", "GemTD"], ["eeve", "eeveTD"], ["maul", "Shopping Maul"]]
const RECORDS := [
	["most_kills", "Meiste Kills in einem Spiel"],
	["tower_kills_run", "Meiste Kills eines Towers (Spiel)"],
	["tower_damage_run", "Meister Schaden eines Towers (Spiel)"],
	["tower_damage_wave", "Meister Schaden eines Towers (Welle)"],
	["wave_damage", "Meister Schaden in einer Welle"],
	["best_score", "Beste Punkte"],
	["longest_path", "Längster Weg"],
	["fastest_win", "Schnellster Sieg"],
]
## Spalten der Tower-Tabelle: [Schlüssel, Überschrift]
const COLUMNS := [["built", "Gebaut"], ["wins", "In Siegen"], ["kills", "Kills"], ["best_run_kills", "Rekord Kills / Spiel"],
	["damage", "Schaden"], ["best_tower_damage", "Rekord / Tower"], ["best_wave_damage", "Rekord / Welle"]]

var tabs: HBoxContainer
var content: VBoxContainer
var current := 0
var tower_mode := "gemtd"
var tower_sort := "damage"


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	var group := ButtonGroup.new()
	var names := ["Übersicht"]
	for m in MODE_TABS:
		names.append(m[1])
	names.append("Tower")
	for i in names.size():
		var b := UiUtil.button(names[i], tabs, show_tab.bind(i))
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("pressed", DecoTheme.box(DecoTheme.CYAN, DecoTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", DecoTheme.GOLD_DARK)
		# feste Breite, sonst schneidet der schmalere Rahmen im Normalzustand den Text ab
		b.custom_minimum_size.x = b.get_theme_font("font").get_string_size(tr(names[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x + 36
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	show_tab(current)


func reload() -> void:
	if content != null:
		show_tab(current)


func show_tab(i: int) -> void:
	current = i
	for j in tabs.get_child_count():
		(tabs.get_child(j) as Button).set_pressed_no_signal(j == i)
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	if i == 0:
		_overview()
	elif i <= MODE_TABS.size():
		_mode_page(MODE_TABS[i - 1][0])
	else:
		_tower_page()


# --- Übersicht -----------------------------------------------------------------------

func _overview() -> void:
	var t := Profile.totals()
	var grid := _tiles()
	var per := []
	for m in MODE_TABS:
		per.append("%s %d" % [m[1], int(Profile.mode(m[0]).runs)])
	_tile(grid, "Spiele", _num(t.runs), " · ".join(per))
	_tile(grid, "Siege", _num(t.wins), "%d %%" % roundi(100.0 * t.wins / maxf(t.runs, 1)))
	_tile(grid, "Spielzeit", _hours(t.play_time), "")
	_tile(grid, "Kills", _num(t.kills), tr("Ø %s pro Spiel") % _num(roundi(t.kills / maxf(t.runs, 1))))
	_tile(grid, "Tower gebaut", _num(t.built), "")
	if t.runs == 0:
		_hint("Noch keine Spiele im Profil. Spiel eine Runde, dann stehen hier deine Statistiken.")
	var cols := _cols()
	_best_box(cols, Profile.best_run())
	_recent_box(cols, Profile.runs().slice(0, 8))


# --- Modus ---------------------------------------------------------------------------

func _mode_page(m: String) -> void:
	var md := Profile.mode(m)
	var grid := _tiles()
	var runs := int(md.runs)
	_tile(grid, "Spiele", _num(runs), tr("%d Siege · %d Niederlagen") % [int(md.wins), int(md.losses)])
	_tile(grid, "Spielzeit", _hours(int(md.play_time)), "")
	_tile(grid, "Kills", _num(int(md.kills)), "")
	_tile(grid, "Schaden", _short(float(md.damage)), "")
	_tile(grid, "Wellen geschafft" if m != "maul" else "Level geschafft", _num(int(md.waves)),
		tr("höchste: %d") % int(md.records.get("best_wave", {}).get("value", 0)))
	_tile(grid, "Tower gebaut", _num(int(md.built)), "")
	if m == "maul":
		var mp := MaulProfilePanel.new()
		mp.xp = MaulXp.load_xp()
		var box := _box(content, "Erfahrung und Filialen")
		mp.build_content(box)
		mp.free()
	var cols := _cols()
	_best_box(cols, md.best_run)
	_records_box(cols, md.records)
	_recent_box(content, Profile.runs(m).slice(0, 8))


func _records_box(parent: Node, rec: Dictionary) -> void:
	var g := _pairs(_box(parent, "Rekorde"))
	var any := false
	for r in RECORDS:
		if not rec.has(r[0]):
			continue
		any = true
		var d: Dictionary = rec[r[0]]
		var v := float(d.value)
		var text := _duration(int(v)) if r[0] == "fastest_win" else (_short(v) if v >= 100000 else _num(roundi(v)))
		if d.has("label"):
			text = "%s · %s" % [tr(str(d.label)), text]
		if d.has("wave") and int(d.wave) > 0:
			text += " " + tr("(W %d)") % int(d.wave)
		_pair(g, r[1], text)
	if not any:
		_pair(g, "Noch keine Rekorde", "")


# --- Tower ---------------------------------------------------------------------------

func _tower_page() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	content.add_child(head)
	var group := ButtonGroup.new()
	for m in MODE_TABS:
		var id: String = m[0]
		var b := UiUtil.button(m[1], head, func():
			tower_mode = id
			show_tab(current))
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("pressed", DecoTheme.box(DecoTheme.CYAN, DecoTheme.CYAN, 0, 2))
		b.add_theme_color_override("font_pressed_color", DecoTheme.GOLD_DARK)
		b.set_pressed_no_signal(id == tower_mode)
	var hint := UiUtil.label("Klick auf eine Spalte sortiert.", head, 13)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.add_theme_color_override("font_color", DecoTheme.MUTED)

	var ts := Profile.towers(tower_mode)
	if ts.is_empty():
		_hint("Noch keine Tower in diesem Modus.")
		return
	var ids := ts.keys()
	ids.sort_custom(func(a, b): return float(ts[a].get(tower_sort, 0)) > float(ts[b].get(tower_sort, 0)))
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size() + 1
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)
	var name_head := DecoTheme.caption("Tower", grid)
	name_head.custom_minimum_size.x = 260
	for c in COLUMNS:
		var key: String = c[0]
		var b := Button.new()
		b.text = tr(c[1]) + (" ▼" if key == tower_sort else "")
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", DecoTheme.GOLD if key == tower_sort else DecoTheme.MUTED)
		b.pressed.connect(func():
			tower_sort = key
			show_tab(current))
		grid.add_child(b)
	for id in ids:
		var d: Dictionary = ts[id]
		var n := UiUtil.label(_tower_name(tower_mode, id), grid, 15)
		n.clip_text = true
		n.custom_minimum_size.x = 260
		for c in COLUMNS:
			var v := float(d.get(c[0], 0))
			var l := UiUtil.label(_short(v) if v >= 1000000 else _num(roundi(v)), grid, 15)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.add_theme_color_override("font_color", DecoTheme.TEXT if c[0] == tower_sort else DecoTheme.DIM)


func _tower_name(m: String, id: String) -> String:
	if m == "maul":
		return str(MaulData.tower(id).get("name", id))
	return Database.tower_label(id, 0) if Database.towers.has(id) else id


# --- Bausteine -----------------------------------------------------------------------

func _best_box(parent: Node, r: Dictionary) -> void:
	var box := _box(parent, "Bester Run")
	if r.is_empty():
		_hint("Noch kein Run.", box)
		return
	var g := _pairs(box)
	_pair(g, "Modus · Map", "%s · %s" % [_mode_name(str(r.get("mode", ""))), str(r.get("map", ""))])
	_pair(g, "Schwierigkeit", _difficulty(r))
	var res := tr("GEWONNEN") if r.get("victory", false) else tr("VERLOREN")
	_pair(g, "Ergebnis", "%s · %d / %d" % [res, int(r.get("wave", 0)), int(r.get("waves", 0))],
		DecoTheme.HAVE if r.get("victory", false) else DecoTheme.MISSING)
	if int(r.get("score", 0)) > 0:
		_pair(g, "Punkte", _num(int(r.score)))
	_pair(g, "Kills", _num(int(r.get("kills", 0))))
	_pair(g, "Spieldauer", _duration(int(r.get("play_time", 0))))
	var top: Dictionary = r.get("top", {})
	if not top.is_empty():
		_pair(g, "Stärkster Tower", "%s · %s" % [tr(str(top.label)), _short(float(top.damage))])
	_pair(g, "Datum", RunHistoryPanel._date(r, true))


func _recent_box(parent: Node, runs: Array) -> void:
	var box := _box(parent, "Letzte Runs")
	if runs.is_empty():
		_hint("Noch keine Runs.", box)
		return
	var g := _pairs(box)
	for r in runs:
		var left := "%s · %s · %s" % [RunHistoryPanel._date(r), _mode_name(str(r.get("mode", ""))), str(r.get("map", ""))]
		var right := (tr("GEWONNEN") if r.get("victory", false) else tr("Welle %d") % int(r.get("wave", 0)))
		if r.get("debug", false):
			right += " · " + tr("Debug")
		_pair(g, left, right, DecoTheme.HAVE if r.get("victory", false) else DecoTheme.MUTED)


func _tiles() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 10)
	f.add_theme_constant_override("v_separation", 10)
	content.add_child(f)
	return f


func _tile(parent: Node, caption: String, value: String, sub: String) -> void:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = 200
	p.add_theme_stylebox_override("panel", DecoTheme.box(DecoTheme.PANEL_2, DecoTheme.BORDER, 0, 2, 10))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	DecoTheme.caption(caption, v).add_theme_font_size_override("font_size", 13)
	var l := UiUtil.label(value, v, 24)
	l.add_theme_color_override("font_color", DecoTheme.BRASS_LIGHT)
	if sub != "":
		var s := UiUtil.label(sub, v, 13)
		s.add_theme_color_override("font_color", DecoTheme.MUTED)


func _cols() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	content.add_child(h)
	return h


func _box(parent: Node, caption: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", DecoTheme.box(DecoTheme.PANEL, DecoTheme.BORDER_2, 0, 1, 14))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	DecoTheme.caption(caption, v)
	return v


func _pairs(parent: Node) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 5)
	parent.add_child(g)
	return g


func _pair(g: GridContainer, key: String, value: String, col := DecoTheme.TEXT) -> void:
	var k := UiUtil.label(key, g, 15)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	k.add_theme_color_override("font_color", DecoTheme.MUTED)
	var v := UiUtil.label(value, g, 15)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", col)


func _hint(text: String, parent: Node = null) -> void:
	var l := UiUtil.wrap_label(text, parent if parent != null else content, 520)
	l.add_theme_color_override("font_color", DecoTheme.MUTED)


func _mode_name(m: String) -> String:
	for t in MODE_TABS:
		if t[0] == m:
			return t[1]
	return tr("Roguelike") if m == "roguelike" else m


func _difficulty(r: Dictionary) -> String:
	if str(r.get("mode", "")) == "maul":
		return str(int(r.get("difficulty", 0)))
	var d := clampi(int(r.get("difficulty", 1)), 0, Session.DIFFICULTIES.size() - 1)
	return tr(str(Session.DIFFICULTIES[d].name))


static func _num(v: int) -> String:
	return RunHistoryPanel._num(v)


## 4.120.000 -> "4,1 Mio."
static func _short(v: float) -> String:
	if v < 1000000.0:
		return _num(roundi(v))
	var s := "%.1f" % (v / 1000000.0)
	if TranslationServer.get_locale().begins_with("de"):
		s = s.replace(".", ",")
	return s + " " + TranslationServer.translate("Mio.")


static func _duration(sec: int) -> String:
	return RunHistoryPanel._duration(sec)


static func _hours(sec: int) -> String:
	return "%d h %02d min" % [sec / 3600, (sec / 60) % 60]
