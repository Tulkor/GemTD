class_name YtSFX
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Klänge der Fähigkeiten: die Dateien aus YouTD 2 sind nicht übernommen, deshalb vorerst still.


static func sfx_at_unit(_sfx_path: String, _unit, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
	pass


static func sfx_at_pos(_sfx_path: String, _pos: Vector2, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
	pass


static func play_sfx(_sfx_path: String, _volume_db: float = 0.0, _pitch_scale: float = 1.0) -> void:
	pass
