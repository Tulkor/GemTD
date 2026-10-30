class_name StyleFilter
extends CanvasLayer
## Stimmung je Modus (Wunsch von Lukas, 2026-10-30): ein Bildfilter über dem 3D-Bild (style_filter.gdshader)
## und ein paar Lichtwerte, die FieldStyle.env() dazunimmt.
## - Arcade (GemTD): Retro/Synthwave, Violett in den Schatten, Pink und Orange in den Lichtern, rosa Dunst
##   am Horizont, Zeilenraster und Farbsäume wie auf einem alten Röhrenbildschirm.
## - Art déco (Shopping Maul): Messing und Gold kräftiger und heller, alles andere etwas gedämpft und
##   Richtung Petrol, Kanten nachgeschärft.
## - Druidenhain (eeveTD, YouTD): verlassener Wald, Farben ausgewaschen und kühl grünblau, nur die warmen
##   Laternen behalten ihre Farbe; Dunst hinten und am vorderen Rand, Filmkorn.
## - Plakatwand (Randgruppen TD): warmes Spätnachmittagslicht (Licht immer), Filter tönt leicht bernsteinfarben.
## Der Filter lässt sich in den Einstellungen abschalten (Display.style_filter), das Licht bleibt.
## Kosten: ein Bildschirm-Durchgang mit höchstens 7 Texturzugriffen.

## Werte je FieldStyle-Name, mit "_night" für die Nachtversion (sonst gilt der Tag).
## "grade" = Shader-Parameter, "light" = Überschreibungen für FieldStyle.env() (gelten auch ohne Filter).
const LOOKS := {
	FieldStyle.NEON: {
		"grade": {
			"shadow_tint": Color(0.42, 0.26, 0.72), "highlight_tint": Color(0.64, 0.5, 0.58), "split": 0.35,
			"saturation": 1.18, "contrast": 1.08, "brightness": 1.04,
			"chroma": 1.6, "scanlines": 0.14, "scan_px": 3.0, "grain": 0.025,
			"haze_color": Color(0.85, 0.2, 0.62), "haze": 0.3, "haze_reach": 0.42, "haze_low": 0.0,
			"edge_color": Color(0.1, 0.02, 0.22), "edge": 0.35,
		},
	},
	FieldStyle.DECO: {
		"grade": {
			"shadow_tint": Color(0.36, 0.54, 0.54), "highlight_tint": Color(0.64, 0.55, 0.4), "split": 0.25,
			"saturation": 0.9, "contrast": 1.1, "brightness": 1.0,
			"hue_target": 0.11, "hue_width": 0.09, "hue_sat": 1.25, "hue_gain": 1.06,
			"sharpen": 0.5,
			"edge_color": Color(0.01, 0.07, 0.08), "edge": 0.3,
		},
	},
	FieldStyle.DRUID: {
		"grade": {
			"shadow_tint": Color(0.4, 0.54, 0.5), "highlight_tint": Color(0.5, 0.52, 0.48), "split": 0.25,
			"saturation": 0.68, "contrast": 1.06, "brightness": 0.95,
			"hue_target": 0.09, "hue_width": 0.1, "hue_sat": 1.25, "hue_gain": 1.1,
			"grain": 0.035,
			"haze_color": Color(0.36, 0.42, 0.4), "haze": 0.32, "haze_reach": 0.5, "haze_low": 0.2,
			"edge_color": Color(0.01, 0.03, 0.03), "edge": 0.4,
		},
		"light": {"fog": Color("a0aa98"), "fog_density": 0.006, "saturation": 0.85},
	},
	FieldStyle.DRUID + "_night": {
		"grade": {
			"shadow_tint": Color(0.38, 0.52, 0.52), "highlight_tint": Color(0.5, 0.5, 0.5), "split": 0.3,
			"saturation": 0.62, "contrast": 1.08, "brightness": 0.97,
			# Laternen (Goldorange) bleiben warm und leuchten heraus
			"hue_target": 0.09, "hue_width": 0.12, "hue_sat": 1.35, "hue_gain": 1.15,
			"grain": 0.04,
			"haze_color": Color(0.11, 0.16, 0.18), "haze": 0.45, "haze_reach": 0.55, "haze_low": 0.3,
			"edge_color": Color(0.0, 0.02, 0.03), "edge": 0.5,
		},
		# dichterer, grünlicher Nebel zwischen den Bäumen
		"light": {"fog": Color("17262a"), "fog_density": 0.022},
	},
	FieldStyle.POSTER: {
		"grade": {
			"shadow_tint": Color(0.54, 0.48, 0.44), "highlight_tint": Color(0.58, 0.52, 0.42), "split": 0.22,
			"saturation": 1.06, "contrast": 1.03, "brightness": 1.02,
			"edge_color": Color(0.2, 0.1, 0.03), "edge": 0.25,
		},
		# Sonne tiefer und goldener, Umgebungslicht und Gegenlicht warm statt grau-blau
		"light": {
			"sun": Color("ffdcae"), "sun_pitch": -42.0, "ambient": Color("dcd2c4"), "fill": Color("d0bca8"),
			"sky_top": Color("a8b4c0"), "sky_horizon": Color("ecdcc4"),
		},
	},
}


## Werte des aktiven Stils (Tag oder Nacht nach FieldStyle.night).
static func look(name := "") -> Dictionary:
	if name == "":
		name = FieldStyle.current_name()
	if FieldStyle.night and LOOKS.has(name + "_night"):
		return LOOKS[name + "_night"]
	return LOOKS.get(name, {})


## Lichtwerte für FieldStyle.env().
static func light(name := "") -> Dictionary:
	return look(name).get("light", {})


## Filter in die Szene hängen (ersetzt einen alten, z. B. nach dem Wechsel Tag/Nacht).
static func attach(parent: Node) -> StyleFilter:
	var old := parent.get_node_or_null("StyleFilter")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	var grade: Dictionary = look().get("grade", {})
	if grade.is_empty():
		return null
	var f := StyleFilter.new()
	f.name = "StyleFilter"
	f._grade = grade
	parent.add_child(f)
	return f


var _grade: Dictionary
var _rect: ColorRect


func _ready() -> void:
	# unter der Oberfläche (HUD ab Ebene 0), über dem 3D-Bild
	layer = -1
	_rect = ColorRect.new()
	_rect.name = "Grade"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/style_filter.gdshader")
	for k in _grade:
		mat.set_shader_parameter(k, _grade[k])
	_rect.material = mat
	add_child(_rect)
	visible = Display.style_filter
	Display.style_filter_changed.connect(_on_changed)


func _on_changed(on: bool) -> void:
	visible = on
