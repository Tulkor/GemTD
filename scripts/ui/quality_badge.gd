class_name QualityBadge
extends Control
## Gem-Symbol mit Qualität: eine Raute mit innerer Raute (Facetten-Gem).
## Die 4 äußeren Facetten füllen sich im Uhrzeigersinn ab oben links, eine pro Qualität;
## die Mitte erst bei Perfekt, dazu weiße Linien und ein weißer Schein nach außen.
## Gezählt werden nur Qualitäten, die spawnen können (Splitter bis Perfekt, siehe chance_levels).

## Farben, die im Symbol greller sein sollen als die Tower-Farbe.
const VIVID := {"topaz": Color("ffe600")}
const INNER := 0.45  ## Größe der inneren Raute
## Stufe als römische Zahl (Splitter = I … Perfekt = V, Großartig = VI)
const ROMAN := ["I", "II", "III", "IV", "V", "VI"]

var tier := 0
var tiers := 5
var color := Color.WHITE


## px = Höhe; die Raute ist etwa 0,63 so breit wie hoch.
func _init(gem_color := Color.WHITE, gem_tier := 0, tier_count := 6, px := 36.0, gem_id := "") -> void:
	color = VIVID.get(gem_id, gem_color)
	tiers = clampi(spawn_tiers(), 1, maxi(tier_count, 1))
	tier = mini(gem_tier, tiers - 1)
	custom_minimum_size = Vector2(roundf(px * 0.63), px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func roman(gem_tier: int) -> String:
	return ROMAN[clampi(gem_tier, 0, ROMAN.size() - 1)]


## Anzahl Qualitäten, die direkt spawnen können (Länge der Chance-Gewichte).
static func spawn_tiers() -> int:
	var n := 0
	for l in Database.balance.get("chance_levels", []):
		n = maxi(n, (l.get("weights", []) as Array).size())
	return n if n > 0 else Database.TIER_NAMES.size()


func is_perfect() -> bool:
	return tier >= tiers - 1 and tiers > 1


func _draw() -> void:
	var h := size.y
	var w := minf(size.x, h * 0.63)
	var o := Vector2((size.x - w) / 2.0, 0)
	var cx := w / 2.0
	var my := h * 0.475
	var t := o + Vector2(cx, 0)
	var b := o + Vector2(cx, h)
	var l := o + Vector2(0, my)
	var r := o + Vector2(w, my)
	var it := o + Vector2(cx, my - my * INNER)
	var ib := o + Vector2(cx, my + (h - my) * INNER)
	var il := o + Vector2(cx - cx * INNER, my)
	var ir := o + Vector2(cx + cx * INNER, my)
	var outer := PackedVector2Array([t, r, b, l, t])
	var perfect := is_perfect()
	var lw := maxf(1.0, w / 42.0)
	if perfect:
		# Weißer Schein nach außen, wie die Rasterlinien des Spielfelds
		for g in [[lw * 7.0, 0.10], [lw * 4.5, 0.22], [lw * 2.6, 0.45]]:
			draw_polyline(outer, Color(1, 1, 1, g[1]), g[0], true)
	# Facetten im Uhrzeigersinn: oben links, oben rechts, unten rechts, unten links
	var facets := [[t, it, il, l], [t, r, ir, it], [r, b, ib, ir], [b, l, il, ib]]
	for q in facets.size():
		if q <= tier:
			draw_colored_polygon(PackedVector2Array(facets[q]), color)
	var mid := color.darkened(0.2)
	if perfect:
		draw_colored_polygon(PackedVector2Array([it, ir, ib, il]), mid)
	var line := Color.WHITE if perfect else mid
	for seg in [[t, it], [r, ir], [b, ib], [l, il]]:
		draw_line(seg[0], seg[1], line, lw, true)
	draw_polyline(PackedVector2Array([it, ir, ib, il, it]), line, lw, true)
	draw_polyline(outer, Color.WHITE, lw * (1.5 if perfect else 1.1), true)
