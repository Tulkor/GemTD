class_name NetSync
extends Node
## Mehrspieler: meldet den Stand des eigenen Spiels an alle (für die Spielerliste), gibt dem Host
## zu Beginn jeder Bauphase einen Spielstand (zum Wiedereinsteigen) und schickt,
## solange jemand zuschaut, den Abzug des Felds an die Zuschauer:
##   Map einmal pro Zuschauer, Feld (Tower, Steine, Wege, Werte) bei jeder Änderung,
##   Gegner und Schüsse etwa 15 Mal pro Sekunde. Der Zuschauer lässt die Gegner dazwischen
##   selbst weiterlaufen (enemy.gd → _remote_step).

const STATUS_INTERVAL := 0.25
const FIELD_INTERVAL := 0.2
const ENEMY_INTERVAL := 1.0 / 15.0
const MAX_BEAMS := 64

var game  # game.gd

var _map_packet: Dictionary
var _map_sent: Dictionary = {}    ## Zuschauer, die Map und vollen Feldstand schon haben
var _last_field_hash := 0
var _status_timer := 0.0
var _field_timer := 0.0
var _enemy_timer := 0.0
var _sent_enemies := true   ## beim Start einmal leer schicken (Neustart mitten in einer Welle)
var _beams: Array = []
var _last_phase := -1


func _ready() -> void:
	var map_dict: Dictionary = game.map.to_dict()
	_map_packet = {"id": hash(map_dict), "map": map_dict}
	Net.watchers_changed.connect(_on_watchers_changed)


func _exit_tree() -> void:
	Net.set_status({"in_game": false})


func _on_watchers_changed() -> void:
	for p in _map_sent.keys():
		if not Net.watchers.has(p):
			_map_sent.erase(p)


## Schusslinie für Zuschauer merken (game.gd → add_beam).
func add_beam(from: Vector3, to: Vector3, col: Color, fx: String = "") -> void:
	if not Net.watchers.is_empty() and _beams.size() < MAX_BEAMS:
		_beams.append([from, to, col, fx] if fx != "" else [from, to, col])


func _process(delta: float) -> void:
	# Takt in echter Zeit, unabhängig vom Spieltempo
	var dt := delta / maxf(Engine.time_scale, 0.01)
	# Zwischenstand für die Sitzung des Hosts: zu Beginn jeder Bauphase und wenn die Partie endet
	if game.phase != _last_phase:
		_last_phase = game.phase
		# (zurück in die Bauphase durch Zurücknehmen eines Gems zählt nicht als neue Runde)
		# (im Koop meldet nur, wer das gemeinsame Feld rechnet; reiner Koop speichert der Host selbst)
		if not game.mirror and not Net.is_coop() and ((game.phase == game.Phase.BUILD and game.round_towers.is_empty()) or game.phase >= game.Phase.GAME_OVER):
			Net.report_state(SaveGame.capture(game))
	_status_timer -= dt
	if _status_timer <= 0.0:
		_status_timer = STATUS_INTERVAL
		Net.set_status(status())
	if Net.watchers.is_empty():
		return

	var fresh: Array = []
	for p in Net.watchers:
		if not _map_sent.has(p):
			Net.send_map(p, _map_packet)
			_map_sent[p] = true
			fresh.append(p)
	_field_timer -= dt
	if _field_timer <= 0.0 or not fresh.is_empty():
		_field_timer = FIELD_INTERVAL
		var f := field()
		var h := hash(f)
		var targets: Array = Net.watchers.keys() if h != _last_field_hash else fresh
		_last_field_hash = h
		for p in targets:
			Net.send_field(p, f)

	_enemy_timer -= dt
	if _enemy_timer <= 0.0:
		_enemy_timer = ENEMY_INTERVAL
		var list := []
		for e in game.enemies:
			if not e.dead:
				list.append(e.net_state())
		# nach dem letzten Gegner einmal leer schicken, damit der Zuschauer aufräumt
		if not list.is_empty() or not _beams.is_empty() or _sent_enemies:
			var packet := {"ts": Engine.time_scale, "now": Time.get_ticks_msec(), "e": list, "b": _beams}
			for p in Net.watchers:
				Net.send_enemies(p, packet)
			_beams = []
		_sent_enemies = not list.is_empty()


## Kurzer Stand für die Spielerliste.
func status() -> Dictionary:
	return {
		"in_game": true,
		"phase": game.phase,
		"wave": mini(game.current_wave(), game.waves.size()),
		"waves": game.waves.size(),
		"lives": game.lives,
		"score_mode": game.score_mode,
		"score": roundi(game.score),
		"difficulty": Session.difficulty,
	}


## Alles, was ein Zuschauer vom Feld braucht (ohne Gegner).
func field() -> Dictionary:
	var ts := []
	for t in game.all_towers():
		ts.append([t.cell.x, t.cell.y, t.tower_id, t.tier, t.is_new])
	var rs := PackedInt32Array()
	for c in game.rocks:
		rs.append(c.x)
		rs.append(c.y)
	var f := status()
	f.merge({
		"map_id": _map_packet.id,
		"gold": game.gold,
		"chance": game.chance_level,
		"towers": ts,
		"rocks": rs,
		"ground": game.ground_path,
		"air": game.air_path,
		"lanes": game.lane_paths.slice(1).map(func(l): return [l.ground, l.air]),
		"path_length": game.path_length,
	})
	return f
