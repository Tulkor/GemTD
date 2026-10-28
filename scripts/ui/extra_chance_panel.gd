class_name ExtraChancePanel
extends PanelContainer
## Extra Chance (GemTD, wie im WC3-Original): in der Bauphase für Gold eine Gem-Sorte wählen, dann wird jeder
## Gem dieser Runde mit erhöhter Chance zu einem Perfekten dieser Sorte. Einmal pro Runde.
## Werte in data/balance.json unter "extra_chance", die Regel rechnet game.gd (Befehl "extra_chance").

signal chosen(id: String)

var _list: GridContainer
var _info: Label


func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel(16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	UiTheme.title(UiUtil.label("Extra Chance", v), 22)
	_info = UiUtil.wrap_label("", v, 420)
	_info.add_theme_color_override("font_color", UiTheme.MUTED)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	v.add_child(_list)
	UiUtil.button("Schließen", v, hide)
	hide()


## cfg: balance.extra_chance, gold: Gold des Spielers, active: schon gewählte Sorte dieser Runde ("" = keine).
func open(cfg: Dictionary, gold: int, active: String) -> void:
	var tier := int(cfg.get("tier", 4))
	_info.text = tr("Jeder Gem, den du in dieser Runde noch setzt, wird mit %s %% Chance zum gewählten Gem. Kostet %d Gold, einmal pro Runde.") % [
		TowerStats.num(float(cfg.get("chance", 0.06)) * 100.0, 1), int(cfg.get("cost", 175))]
	for c in _list.get_children():
		c.queue_free()
	for id in Database.gem_ids():
		var gem: String = id
		var b := UiUtil.button(Database.tower_label(gem, tier), _list, func():
			hide()
			chosen.emit(gem))
		b.custom_minimum_size.x = 210
		b.add_theme_color_override("font_color", Color(str(Database.towers[gem].get("color", "#ffffff"))).lightened(0.3))
		if gem == active:
			b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.CYAN, UiTheme.CYAN))
			b.add_theme_color_override("font_color", UiTheme.GOLD_DARK)
		b.disabled = active != "" or gold < int(cfg.get("cost", 175))
	show()
