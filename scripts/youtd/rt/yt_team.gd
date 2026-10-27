class_name YtTeam
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Das Team: Welle und Portal-Leben aus youtd_game.gd.


## Aktuelle Welle.
func get_level() -> int:
	return int(YtWorld.game.current_wave()) if YtWorld.game != null else 0


func get_lives_percent() -> float:
	return float(YtWorld.game.portal) if YtWorld.game != null else 100.0
