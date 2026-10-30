class_name YtBuildSpace
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Bauflächen, wie Item-Skripte sie abfragen (Chrono Jumper, Distorted Idol). "map"-Felder sind unsere Felder
## (ein Tower = 2 × 2), "canvas"-Positionen sind WC3-Positionen; eine Tower-Mitte liegt bei (Anker + 1) × 64.


## Kann player hier einen Tower hinstellen (pos = Tower-Mitte in WC3)?
func can_build_at_pos(player: YtPlayer, pos: Vector2) -> bool:
	if YtWorld.game == null:
		return false
	var a := _convert_pos_canvas_to_map(pos)
	return YtWorld.game.can_place_for(a, player.id if player != null else 0)


## Anker-Feld eines Towers mit Mitte pos.
func _convert_pos_canvas_to_map(pos: Vector2) -> Vector2i:
	return Vector2i(roundi(pos.x / 64.0) - 1, roundi(pos.y / 64.0) - 1)


## Liegt bei Anker pos eine Baufläche (egal ob frei)?
func buildable_cell_exists_at_pos(player: YtPlayer, pos: Vector2i) -> bool:
	if YtWorld.game == null:
		return false
	var m = YtWorld.game.map
	for c in Board3D.footprint(pos):
		if not m.is_buildable(c) or not YtWorld.game.may_build_for(c, player.id if player != null else 0):
			return false
	return true
