class_name YtBuilder
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Baumeister mit Sonderregeln kommen in Etappe 3; bis dahin ohne Wirkung.


func apply_effects(_unit) -> void:
	pass


func get_tower_lvl_bonus() -> int:
	return 0


func get_range_bonus() -> float:
	return 0.0


func get_item_slots_bonus() -> int:
	return 0
