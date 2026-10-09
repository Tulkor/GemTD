class_name Effects
extends Node2D
## Kurze Schusslinien von Tower zu Gegner.

const BEAM_TIME := 0.12

var beams: Array = []


func add_beam(from: Vector2, to: Vector2, col: Color) -> void:
	beams.append({"from": from, "to": to, "color": col, "t": BEAM_TIME})


func _process(delta: float) -> void:
	if beams.is_empty():
		return
	for b in beams:
		b.t -= delta
	beams = beams.filter(func(b): return b.t > 0.0)
	queue_redraw()


func _draw() -> void:
	for b in beams:
		var c: Color = b.color
		c.a = b.t / BEAM_TIME
		draw_line(b.from, b.to, c, 2.0)
