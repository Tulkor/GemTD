class_name CreditsPanel
extends ScrollContainer
## Seite „Mitwirkende“ im Hub (Art déco): Vorbilder, Modelle, Effekte, Sounds, Schriften mit Lizenz.
## Inhalt aus data/credits.json, damit CC-BY-Nennungen (Boss-Modell) für Spieler sichtbar sind.

const PATH := "res://data/credits.json"


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 18)
	add_child(v)
	var version := UiUtil.label(version_text(), v, 16)
	version.add_theme_color_override("font_color", DecoTheme.MUTED)
	for section in load_sections():
		_section(v, section)


## Versionsnummer aus project.godot (setzt tools/build_windows.sh beim Bauen), sonst „Entwicklerversion“.
static func version_text() -> String:
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	return str(TranslationServer.translate("Version")) + " " + ver if ver != "" else str(TranslationServer.translate("Entwicklerversion"))


static func load_sections() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		push_error("credits.json fehlt oder ist kaputt")
		return []
	return data.get("sections", [])


func _section(parent: Node, section: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", DecoTheme.panel(16))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	DecoTheme.caption(section.get("title", ""), box)
	if section.has("note"):
		var note := UiUtil.label(section.note, box, 16)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", DecoTheme.MUTED)
	for e in section.get("entries", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		var head := UiUtil.label(e.get("name", ""), text, 18)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var by := UiUtil.label(e.get("by", ""), text, 15)
		by.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		by.add_theme_color_override("font_color", DecoTheme.DIM)
		if e.get("license", "") != "":
			var lic := UiUtil.label(e.license, row, 15)
			lic.add_theme_color_override("font_color", DecoTheme.GOLD)
			lic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if e.has("url"):
			var link := LinkButton.new()
			link.text = tr("Seite")
			link.uri = e.url
			link.tooltip_text = e.url
			link.add_theme_color_override("font_color", DecoTheme.BRASS_LIGHT)
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(link)
