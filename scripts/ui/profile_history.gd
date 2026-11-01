class_name ProfileHistory
extends HBoxContainer
## Run-History im Profil wie Entwurf 9 (Lukas 2026-11-01): links die Bestwerte je Modus, rechts die erreichte
## Welle der letzten 30 Runs als Säulen (grün Sieg, rot Niederlage, grau Debug, dunkel abgebrochen) und die Liste
## aller Runs mit Filter je Modus. GemTD-Runs lassen sich nochmal spielen (gleiche Map und Schwierigkeit).

signal back_requested
signal replay_requested(run: Dictionary)

const PAGE := 60  ## Runs je Seite der Liste

var filter := ""
var list: VBoxContainer
var chart: WaveChart
var filter_row: HBoxContainer
var more: Wc3Button
var _shown := 0


func _ready() -> void:
	add_theme_constant_override("separation", 22)
	var left := Wc3Pillar.new(false, 420)
	add_child(left)
	ProfileWc3.caption("Bestwerte je Modus", left.box)
	for x in ProfileWc3.MODES:
		_best(left.box, x[0])
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.box.add_child(fill)
	var seal := ProfileWc3.cin(tr("PROFIL VERSIEGELT · PRÜFSUMME ✓ GÜLTIG") if Profile.sealed() else tr("PROFIL VON HAND GEÄNDERT · PRÜFSUMME ✗"),
		left.box, 12, Wc3Theme.MUTED, 2)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var right := Wc3Pillar.new(false, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	ProfileWc3.caption("Letzte 30 Runs · erreichte Welle", right.box)
	chart = WaveChart.new()
	right.box.add_child(chart)
	ProfileWc3.body("Grün Sieg · Rot Niederlage · Grau Debug (keine EP) · Dunkel abgebrochen", right.box, 14, Wc3Theme.MUTED)
	filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	right.box.add_child(filter_row)
	for key in [""] + ProfileWc3.MODES.map(func(x): return x[0]):
		var b := Wc3Button.new("Alle" if key == "" else ProfileWc3.short_name(key), false)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(60, 42)
		b.set_meta("key", key)
		b.pressed.connect(set_filter.bind(key))
		filter_row.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.box.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	scroll.add_child(v)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	v.add_child(list)
	more = Wc3Button.new("Weitere Runs", false)
	more.pressed.connect(_add_page)
	v.add_child(more)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	right.box.add_child(foot)
	var back := Wc3Button.new("Zurück", false)
	back.custom_minimum_size.x = 200
	back.pressed.connect(func(): back_requested.emit())
	foot.add_child(back)
	set_filter(filter)


func set_filter(key: String) -> void:
	filter = key
	for b in filter_row.get_children():
		# Gewählter Filter rot (Umschaltknopf)
		b.set_pressed_no_signal(b.get_meta("key") == key)
		b.queue_redraw()
	chart.runs = Profile.runs(key).slice(0, 30)
	chart.runs.reverse()
	chart.queue_redraw()
	for c in list.get_children():
		c.queue_free()
	_shown = 0
	_add_page()


func _add_page() -> void:
	var runs := Profile.runs(filter)
	if runs.is_empty() and _shown == 0:
		ProfileWc3.body("Noch keine Runs.", list, 16, Wc3Theme.MUTED)
	for r in runs.slice(_shown, _shown + PAGE):
		run_row(list, r, true, func(): _replay(r))
	_shown += PAGE
	more.visible = _shown < runs.size()


func _replay(r: Dictionary) -> void:
	var full := Profile.load_run(str(r.get("id", "")))
	var run := r.duplicate()
	run.merge(full, true)
	run.mode = "gemtd"
	replay_requested.emit(run)


func _best(parent: Node, m: String) -> void:
	var md := Profile.mode(m)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	ProfileWc3.gem(head, m, 18)
	ProfileWc3.cin(tr(ProfileWc3.mode_name(m)), head, 17).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b: Dictionary = md.best_run
	ProfileWc3.cin(tr("Welle %d / %d") % [int(b.get("wave", 0)), int(b.get("waves", 0))] if not b.is_empty() else "–", head, 16, Wc3Theme.CREAM)
	var text := tr("Noch kein Run")
	if not b.is_empty():
		text = "%s · %s · %s" % [tr(ProfileWc3.result(b)[0]), str(b.get("map", "")), ProfileWc3.duration(int(b.get("play_time", 0)))]
		if int(b.get("score", 0)) > 0:
			text += " · " + tr("%s Punkte") % ProfileWc3.num(int(b.score))
	ProfileWc3.body(text, box, 14, Wc3Theme.MUTED)
	var line := ColorRect.new()
	line.color = Color(Wc3Theme.GOLD_LO, 0.4)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


## Eine Zeile der Run-Liste: Ergebnis, Modus, Map · Schwierigkeit, Welle, Dauer, Datum, Hinweis.
static func run_row(parent: Node, r: Dictionary, with_mode := true, on_replay := Callable()) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ProfileWc3.flat(ProfileWc3.ROW_BG, Color(0, 0, 0, 0), 6))
	parent.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var res: Array = ProfileWc3.result(r)
	ProfileWc3.cin(TranslationServer.translate(res[0]), row, 15, res[1]).custom_minimum_size.x = 120
	if with_mode:
		ProfileWc3.cin(TranslationServer.translate(ProfileWc3.mode_name(str(r.get("mode", "")))), row, 15).custom_minimum_size.x = 150
	var map := ProfileWc3.body("%s · %s" % [str(r.get("map", "")), ProfileWc3.difficulty(r)], row, 15, Wc3Theme.MUTED)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.clip_text = true
	map.autowrap_mode = TextServer.AUTOWRAP_OFF
	map.custom_minimum_size.x = 60
	ProfileWc3.body(TranslationServer.translate("Welle %d / %d") % [int(r.get("wave", 0)), int(r.get("waves", 0))], row, 15).custom_minimum_size.x = 110
	ProfileWc3.body(ProfileWc3.duration(int(r.get("play_time", 0))), row, 15, Wc3Theme.MUTED).custom_minimum_size.x = 70
	ProfileWc3.body(RunHistoryPanel._date(r), row, 15, Wc3Theme.MUTED).custom_minimum_size.x = 100
	var note := ""
	if r.get("debug", false):
		note = TranslationServer.translate("Debug – keine EP")
	elif r.has("xp_gain") and int(r.xp_gain) > 0:
		note = "+%s XP" % MaulXp.text(int(r.xp_gain))
	var n := ProfileWc3.cin(note, row, 12, Color("f0a090") if r.get("debug", false) else Wc3Theme.CREAM, 1)
	n.custom_minimum_size.x = 120
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if on_replay.is_valid() and str(r.get("mode", "")) == "gemtd" and not r.get("aborted", false):
		var b := Wc3Button.new("Nochmal", false)
		b.custom_minimum_size = Vector2(120, 38)
		b.pressed.connect(on_replay)
		row.add_child(b)
	elif on_replay.is_valid():
		var gap := Control.new()
		gap.custom_minimum_size.x = 120
		row.add_child(gap)
	return p


## Säulen: erreichte Welle je Run (Anteil an allen Wellen), ältester links.
class WaveChart extends Control:
	var runs: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(300, 200)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.35))
		draw_rect(r, Wc3Theme.GOLD_LO, false, 1.0)
		if runs.is_empty():
			return
		var pad := 10.0
		var slot := (size.x - 2 * pad) / 30.0
		for i in runs.size():
			var run: Dictionary = runs[i]
			var frac := clampf(float(run.get("wave", 0)) / maxf(float(run.get("waves", 1)), 1.0), 0.03, 1.0)
			var h := (size.y - 2 * pad) * frac
			var col: Color = ProfileWc3.WIN if run.get("victory", false) else ProfileWc3.LOSS
			if run.get("debug", false):
				col = Color("6b6b6b")
			elif run.get("aborted", false):
				col = Color("4a3d30")
			var bar := Rect2(pad + i * slot + 2, size.y - pad - h, slot - 4, h)
			draw_rect(bar, col.darkened(0.35))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x, bar.size.y * 0.35)), col)
			draw_rect(bar, Color.BLACK, false, 1.0)
