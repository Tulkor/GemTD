extends Control
## Tower-Editor: Tower anlegen und bearbeiten, als JSON speichern und direkt im Spiel testen.
## Das Formular wird aus den Daten und aus Abilities.SCHEMA erzeugt.

const CATEGORIES := ["gem", "special"]
const CATEGORY_LABELS := ["Gem (zufällig würfelbar)", "Spezial (per Rezept)"]
const KINDS := ["tower", "trap"]
const KIND_LABELS := ["Tower (blockiert den Weg)", "Falle (Gegner laufen darüber)"]
const TARGETS := ["both", "ground", "air"]
const TARGET_LABELS := ["Boden und Luft", "Nur Boden", "Nur Luft"]

var current: Dictionary = {}
var ids: Array = []
var tower_list: ItemList
var form: VBoxContainer
var status_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("14161c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	root.add_child(left)
	UiUtil.label("Tower-Editor", left, 24)
	tower_list = ItemList.new()
	tower_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower_list.item_selected.connect(_on_tower_selected)
	left.add_child(tower_list)
	UiUtil.button("Neuer Gem", left, func(): _new_tower("gem"))
	UiUtil.button("Neuer Spezial-Tower", left, func(): _new_tower("special"))
	UiUtil.button("Duplizieren", left, _duplicate)
	UiUtil.button("Zurück zum Menü", left, func(): Session.goto(Session.MAIN_MENU))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	form = VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	scroll.add_child(form)
	var bottom := HBoxContainer.new()
	right.add_child(bottom)
	UiUtil.button("Speichern", bottom, _save)
	UiUtil.button("Speichern und im Spiel testen", bottom, _test)
	status_label = UiUtil.label("", bottom)

	_refresh_list()
	if not ids.is_empty():
		tower_list.select(0)
		_on_tower_selected(0)


func _refresh_list(select_id := "") -> void:
	ids = Database.tower_ids()
	tower_list.clear()
	for id in ids:
		var def: Dictionary = Database.towers[id]
		var idx := tower_list.add_item("%s  [%s]" % [def.get("name", id), id])
		tower_list.set_item_custom_fg_color(idx, Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE))
	var i := ids.find(select_id)
	if i >= 0:
		tower_list.select(i)


func _on_tower_selected(i: int) -> void:
	current = Database.towers[ids[i]].duplicate(true)
	current.erase("_path")
	_build_form()


func _new_tower(category: String) -> void:
	current = {
		"id": "neuer_tower",
		"name": "Neuer Tower",
		"category": category,
		"color": "#ffffff",
		"targets": "both",
		"tiers": [_default_tier()],
	}
	if category == "special":
		current["recipe"] = []
	tower_list.deselect_all()
	_build_form()


func _duplicate() -> void:
	if current.is_empty():
		return
	current = current.duplicate(true)
	current["id"] = str(current.get("id", "tower")) + "_kopie"
	current["name"] = str(current.get("name", "")) + " (Kopie)"
	tower_list.deselect_all()
	_build_form()


func _default_tier() -> Dictionary:
	return {"damage": [10, 15], "range": 3.0, "cooldown": 1.0, "abilities": []}


# --- Formular ----------------------------------------------------------------

func _build_form() -> void:
	for c in form.get_children():
		form.remove_child(c)
		c.queue_free()
	if current.is_empty():
		return

	_line_edit("ID (Dateiname)", "id")
	_line_edit("Name", "name")

	var cat_row := UiUtil.row("Kategorie", form)
	var cat := _option(cat_row, CATEGORY_LABELS, CATEGORIES.find(current.get("category", "gem")))
	cat.item_selected.connect(func(i):
		current["category"] = CATEGORIES[i]
		if CATEGORIES[i] == "special" and not current.has("recipe"):
			current["recipe"] = []
		_build_form())

	var kind_row := UiUtil.row("Art", form)
	var kind := _option(kind_row, KIND_LABELS, KINDS.find(current.get("kind", "tower")))
	kind.item_selected.connect(func(i): current["kind"] = KINDS[i])

	var color_row := UiUtil.row("Farbe", form)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(96, 28)
	picker.color = Color.from_string(str(current.get("color", "#ffffff")), Color.WHITE)
	picker.color_changed.connect(func(c: Color): current["color"] = "#" + c.to_html(false))
	color_row.add_child(picker)

	_line_edit("Modell (optional, res://…glb)", "model")

	var target_row := UiUtil.row("Ziele", form)
	var tgt := _option(target_row, TARGET_LABELS, TARGETS.find(current.get("targets", "both")))
	tgt.item_selected.connect(func(i): current["targets"] = TARGETS[i])

	if current.get("category", "gem") == "special":
		_build_recipe()
	_build_tiers()
	if current.get("category", "gem") == "special":
		_build_upgrades()


func _line_edit(text: String, key: String) -> void:
	var r := UiUtil.row(text, form)
	var e := LineEdit.new()
	e.text = str(current.get(key, ""))
	e.custom_minimum_size.x = 260
	e.text_changed.connect(func(s): current[key] = s)
	r.add_child(e)


func _option(parent: Node, labels: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	for l in labels:
		o.add_item(l)
	o.select(maxi(selected, 0))
	parent.add_child(o)
	return o


func _section(title: String) -> VBoxContainer:
	form.add_child(HSeparator.new())
	UiUtil.label(title, form, 18)
	var box := VBoxContainer.new()
	form.add_child(box)
	return box


func _build_recipe() -> void:
	var box := _section("Rezept (der ausgewählte Gem muss eine Zutat sein; die anderen werden zu Steinen)")
	if not current.has("recipe"):
		current["recipe"] = []
	var same := CheckBox.new()
	same.text = "Nur aus Gems derselben Runde (sonst auch fertige Tower auf dem Feld)"
	same.button_pressed = bool(current.get("recipe_same_round", false))
	same.toggled.connect(func(on): current["recipe_same_round"] = on)
	box.add_child(same)
	_ingredient_list(box, current["recipe"])


## Zeilen für eine Zutatenliste [{tower, tier}] mit Hinzufügen/Entfernen.
func _ingredient_list(box: Node, recipe: Array) -> void:
	var ids := Database.tower_ids()
	for k in recipe.size():
		var ing: Dictionary = recipe[k]
		if ing.has("any_of"):
			var r0 := HBoxContainer.new()
			box.add_child(r0)
			var names: Array = ing.any_of.map(func(a): return Database.tower_label(str(a.get("tower", "")), int(a.get("tier", 0))))
			UiUtil.label("Einer von: " + ", ".join(names), r0)
			_any_of_row(box, ing.any_of)
			UiUtil.button("Entfernen", r0, func():
				recipe.remove_at(k)
				_build_form())
			continue
		if str(ing.get("tower", "")) == "" and not ids.is_empty():
			ing["tower"] = ids[0]
		var r := HBoxContainer.new()
		box.add_child(r)
		var o := _option(r, ids.map(func(id): return Database.towers[id].get("name", id)), ids.find(ing.get("tower", "")))
		o.item_selected.connect(func(i): ing["tower"] = ids[i])
		UiUtil.label("Stufe", r)
		var tier_labels := []
		for t in Database.TIER_NAMES.size():
			tier_labels.append("%d – %s" % [t + 1, Database.TIER_NAMES[t]])
		var to := _option(r, tier_labels, int(ing.get("tier", 0)))
		to.item_selected.connect(func(i): ing["tier"] = i)
		UiUtil.button("Entfernen", r, func():
			recipe.remove_at(k)
			_build_form())
	var add_row := HBoxContainer.new()
	box.add_child(add_row)
	UiUtil.button("+ Zutat", add_row, func():
		recipe.append({"tower": Database.gem_ids()[0] if not Database.gem_ids().is_empty() else "", "tier": 0})
		_build_form())
	UiUtil.button("+ Zutat „einer von …“", add_row, func():
		recipe.append({"any_of": []})
		_build_form())


## Alternativen einer „einer von“-Zutat, eingerückt.
func _any_of_row(box: Node, alts: Array) -> void:
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 40)
	box.add_child(inner)
	var v := VBoxContainer.new()
	inner.add_child(v)
	_ingredient_list(v, alts)


## Upgrade von Stufe i auf i+1: Zutaten müssen als fertige Tower auf dem Feld stehen und werden zu Steinen.
func _build_upgrades() -> void:
	var tiers: Array = current.get("tiers", [])
	if tiers.size() < 2:
		return
	var box := _section("Upgrades (Goldkosten; optionale Zutaten müssen fertig auf dem Feld stehen und werden zu Steinen)")
	if not current.has("upgrades"):
		current["upgrades"] = []
	var ups: Array = current["upgrades"]
	while ups.size() < tiers.size() - 1:
		ups.append({"recipe": [], "cost": 0})
	for i in tiers.size() - 1:
		var up: Dictionary = ups[i]
		if not up.has("recipe"):
			up["recipe"] = []
		UiUtil.label("Stufe %d → %d" % [i + 1, i + 2], box, 16)
		UiUtil.spin(UiUtil.row("Goldkosten", box), float(up.get("cost", 0)), 0, 100000, 1, func(x): up["cost"] = int(x))
		_ingredient_list(box, up["recipe"])


func _build_tiers() -> void:
	var box := _section("Stufen (bei Gems: Splitter, Fehlerhaft, Normal, Makellos, Perfekt)")
	var tiers: Array = current.get("tiers", [])
	current["tiers"] = tiers
	for i in tiers.size():
		var tier: Dictionary = tiers[i]
		if not tier.has("damage"):
			tier["damage"] = [10, 15]
		if not tier.has("abilities"):
			tier["abilities"] = []
		var panel := PanelContainer.new()
		box.add_child(panel)
		var v := VBoxContainer.new()
		panel.add_child(v)

		var head := HBoxContainer.new()
		v.add_child(head)
		var title := "Stufe %d" % (i + 1)
		if current.get("category", "gem") == "gem" and i < Database.TIER_NAMES.size():
			title += " – " + Database.TIER_NAMES[i]
		UiUtil.label(title, head, 16)
		UiUtil.button("Entfernen", head, func():
			tiers.remove_at(i)
			_build_form())

		var dmg: Array = tier.damage
		var dr := UiUtil.row("Schaden min / max", v)
		UiUtil.spin(dr, float(dmg[0]), 0, 100000, 1, func(x): dmg[0] = int(x))
		UiUtil.spin(dr, float(dmg[1]), 0, 100000, 1, func(x): dmg[1] = int(x))
		UiUtil.spin(UiUtil.row("Reichweite (Towerbreiten)", v), float(tier.get("range", 3.0)), 0.5, 30, 0.25, func(x): tier["range"] = x)
		UiUtil.spin(UiUtil.row("Abklingzeit (s)", v), float(tier.get("cooldown", 1.0)), 0.05, 10, 0.05, func(x): tier["cooldown"] = x)

		var abilities: Array = tier.abilities
		var types := Abilities.types()
		for j in abilities.size():
			var ab: Dictionary = abilities[j]
			var ar := HBoxContainer.new()
			v.add_child(ar)
			var labels := types.map(func(t): return Abilities.SCHEMA[t].label)
			var o := _option(ar, labels, types.find(ab.get("type", "")))
			o.item_selected.connect(func(idx):
				abilities[j] = Abilities.default_for(types[idx])
				_build_form())
			var params: Dictionary = Abilities.SCHEMA.get(ab.get("type", ""), {}).get("params", {})
			for p in params:
				UiUtil.label(Abilities.PARAM_LABELS.get(p, p), ar)
				var is_int: bool = typeof(params[p]) == TYPE_INT
				UiUtil.spin(ar, float(ab.get(p, params[p])), 0, 1000, 1.0 if is_int else 0.05,
						func(x): ab[p] = int(x) if is_int else x)
			UiUtil.button("×", ar, func():
				abilities.remove_at(j)
				_build_form())
		UiUtil.button("+ Fähigkeit", v, func():
			abilities.append(Abilities.default_for(types[0]))
			_build_form())

	UiUtil.button("+ Stufe", box, func():
		tiers.append(tiers.back().duplicate(true) if not tiers.is_empty() else _default_tier())
		_build_form())


# --- Speichern / Testen ------------------------------------------------------

func _validate() -> String:
	var id := str(current.get("id", ""))
	if RegEx.create_from_string("^[a-z0-9_]+$").search(id) == null:
		return "Ungültige ID: nur Kleinbuchstaben, Ziffern und _ erlaubt."
	if (current.get("tiers", []) as Array).is_empty():
		return "Der Tower braucht mindestens eine Stufe."
	if current.get("category") == "special" and (current.get("recipe", []) as Array).is_empty():
		return "Ein Spezial-Tower braucht ein Rezept."
	return ""


func _save() -> bool:
	var err := _validate()
	if err != "":
		status_label.text = err
		return false
	var data := current.duplicate(true)
	if str(data.get("model", "")) == "":
		data.erase("model")
	if data.get("category") != "special":
		data.erase("recipe")
		data.erase("upgrades")
	elif data.has("upgrades"):
		data["upgrades"] = (data["upgrades"] as Array).slice(0, maxi((data["tiers"] as Array).size() - 1, 0))
	var path := Database.writable_path("towers", str(data.id))
	if not Database.save_json(path, data):
		status_label.text = "Speichern fehlgeschlagen: " + path
		return false
	Database.reload()
	_refresh_list(str(data.id))
	status_label.text = "Gespeichert: " + path
	return true


func _test() -> void:
	if not _save():
		return
	Session.test_tower = "%s:0" % current.id
	Session.map_override = null
	Session.return_scene = Session.TOWER_EDITOR
	Session.goto(Session.GAME)
