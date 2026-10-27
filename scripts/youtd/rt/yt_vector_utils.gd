class_name YtVectorUtils
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


static func vector3_to_vector2(vec3: Vector3) -> Vector2:
	return Vector2(vec3.x, vec3.y)


static func in_range(start: Vector2, end: Vector2, radius: float) -> bool:
	return start.distance_squared_to(end) <= radius * radius


# Bildschirm-Positionen ("canvas") aus YouTD 2 sind hier dieselben wie WC3-Positionen (kein isometrisches Bild).
static func wc3_2d_to_canvas(pos: Vector2) -> Vector2:
	return pos


static func canvas_to_wc3_2d(pos: Vector2) -> Vector2:
	return pos


## Auf die nächste mögliche Tower-Mitte (alle 64 WC3-Einheiten, ein Feld) runden.
static func snap_canvas_pos_to_buildable_pos(pos: Vector2) -> Vector2:
	return (pos / 64.0).round() * 64.0
