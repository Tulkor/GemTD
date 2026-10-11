class_name QualityBadge
extends Control
## Gem-Symbol mit Qualität: ein Quadrat pro Qualitätsstufe ineinander geschachtelt,
## von innen nach außen in der Gem-Farbe gefüllt bis zur aktuellen Qualität.

var tier := 0
var tiers := 6
var color := Color.WHITE


func _init(gem_color := Color.WHITE, gem_tier := 0, tier_count := 6, px := 36.0) -> void:
	color = gem_color
	tier = gem_tier
	tiers = maxi(tier_count, 1)
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var side := minf(size.x, size.y)
	var center := size / 2.0
	var step := side / (2.0 * tiers)
	# Von außen nach innen zeichnen, damit die inneren Quadrate oben liegen
	for q in range(tiers - 1, -1, -1):
		var half := step * (q + 1)
		var r := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
		var filled := q <= tier
		draw_rect(r, color if filled else UiTheme.PANEL)
		draw_rect(r, UiTheme.BG if filled else UiTheme.BORDER_2, false, 1.0)
