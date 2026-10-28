class_name YtGlobals
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Statt des Autoloads Globals: Zufall und Spieleinstellungen kommen aus dem laufenden Spiel (YtWorld.game).

static var synced_rng := RandomNumberGenerator.new()
static var local_rng := RandomNumberGenerator.new()


static func get_wave_count() -> int:
	return YtWorld.game.max_wave() if YtWorld.game != null else 120


static func get_difficulty() -> int:
	return YtWorld.game.difficulty if YtWorld.game != null else 2


static func get_game_mode() -> int:
	return YtWorld.game.mode_index if YtWorld.game != null else 0


static func game_mode_is_random() -> bool:
	return YtWorld.game == null or not YtWorld.game.is_build_mode()


static func game_is_neverending() -> bool:
	return get_wave_count() == YtConstants.WAVE_COUNT_NEVERENDING
