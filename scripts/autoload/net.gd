extends Node
## Mehrspieler Modus 1: jeder spielt sein eigenes Feld, alle sind über ENet verbunden.
## Übers Netz gehen nur der Stand jedes Spielers (für die Liste) und, solange jemand zuschaut,
## der Abzug seines Felds (net_sync.gd sendet, remote_field.gd zeigt an).
## Die Verbindung bleibt über Szenenwechsel bestehen; jeder kann unabhängig starten und neu starten.

signal players_changed
signal connection_changed
signal field_received(peer: int, data: Dictionary)
signal map_received(peer: int, data: Dictionary)
signal enemies_received(peer: int, data: Dictionary)
signal watchers_changed

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 8
const SETTINGS := "user://settings.cfg"

## peer_id -> {"name": String, "status": Dictionary}
var players: Dictionary = {}
var my_name := ""
var last_ip := ""
## Stand des eigenen Spiels: in_game, wave, waves, lives, phase, difficulty
var my_status: Dictionary = {}
## Wer gerade meinem Feld zuschaut (peer_ids).
var watchers: Dictionary = {}
var status_text := ""


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		my_name = str(cfg.get_value("net", "name", ""))
		last_ip = str(cfg.get_value("net", "ip", ""))
	if my_name == "":
		my_name = tr("Spieler") + " %d" % (randi() % 900 + 100)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("net", "name", my_name)
	cfg.set_value("net", "ip", last_ip)
	cfg.save(SETTINGS)


func is_active() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not p is OfflineMultiplayerPeer \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_connecting() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not p is OfflineMultiplayerPeer \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING


func is_host() -> bool:
	return is_active() and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func host(port := DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		_set_status(tr("Hosten fehlgeschlagen (Port %d belegt?)") % port)
		return err
	multiplayer.multiplayer_peer = peer
	_set_status(tr("Hoste auf Port %d") % port)
	connection_changed.emit()
	return OK


func join(ip: String, port := DEFAULT_PORT) -> Error:
	leave()
	last_ip = ip
	save_settings()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		_set_status(tr("Verbinden fehlgeschlagen"))
		return err
	multiplayer.multiplayer_peer = peer
	_set_status(tr("Verbinde mit %s …") % ip)
	connection_changed.emit()
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	watchers.clear()
	_set_status("")
	players_changed.emit()
	watchers_changed.emit()
	connection_changed.emit()


## Eigene IPv4-Adressen im LAN, damit der Host sie weitergeben kann.
func local_addresses() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func player_name(peer: int) -> String:
	return str(players.get(peer, {}).get("name", "?"))


func player_status(peer: int) -> Dictionary:
	return players.get(peer, {}).get("status", {})


## Eigenen Stand an alle melden (nur wenn er sich geändert hat).
func set_status(s: Dictionary) -> void:
	if s == my_status:
		return
	my_status = s.duplicate()
	if is_active():
		_status.rpc(my_status)


func set_my_name(n: String) -> void:
	n = n.strip_edges()
	if n == "" or n == my_name:
		return
	my_name = n.left(24)
	save_settings()
	if is_active():
		_hello.rpc(my_name, my_status)


# --- Zuschauen -----------------------------------------------------------------

## Dem Feld von peer zuschauen (true) oder aufhören (false).
func watch(peer: int, on: bool) -> void:
	if is_active() and players.has(peer):
		_watch.rpc_id(peer, on)


func send_map(peer: int, data: Dictionary) -> void:
	_map.rpc_id(peer, data)


func send_field(peer: int, data: Dictionary) -> void:
	_field.rpc_id(peer, data)


func send_enemies(peer: int, data: Dictionary) -> void:
	_enemies.rpc_id(peer, data)


## Host startet alle gleichzeitig auf derselben Map (jeder mit seiner eigenen Schwierigkeit).
func start_all(map_data: Dictionary) -> void:
	if is_host():
		_start.rpc(map_data)


# --- RPCs ------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello(n: String, status: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": n, "status": status}
	players_changed.emit()


@rpc("any_peer", "reliable")
func _status(status: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].status = status
		players_changed.emit()


@rpc("any_peer", "reliable")
func _watch(on: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if on:
		watchers[id] = true
	else:
		watchers.erase(id)
	watchers_changed.emit()


@rpc("any_peer", "reliable")
func _map(data: Dictionary) -> void:
	map_received.emit(multiplayer.get_remote_sender_id(), data)


@rpc("any_peer", "reliable")
func _field(data: Dictionary) -> void:
	field_received.emit(multiplayer.get_remote_sender_id(), data)


@rpc("any_peer", "unreliable_ordered")
func _enemies(data: Dictionary) -> void:
	enemies_received.emit(multiplayer.get_remote_sender_id(), data)


@rpc("authority", "call_local", "reliable")
func _start(map_data: Dictionary) -> void:
	Session.map_override = MapData.from_dict(map_data)
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.GAME)


# --- Verbindung ----------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	_hello.rpc_id(id, my_name, my_status)


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	if watchers.erase(id):
		watchers_changed.emit()
	players_changed.emit()


func _on_connected() -> void:
	_set_status(tr("Verbunden"))
	connection_changed.emit()


func _on_failed() -> void:
	leave()
	_set_status(tr("Verbindung fehlgeschlagen"))


func _on_server_lost() -> void:
	leave()
	_set_status(tr("Verbindung zum Host verloren"))


func _set_status(t: String) -> void:
	status_text = t
	connection_changed.emit()
