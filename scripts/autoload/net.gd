extends Node
## Mehrspieler Modus 1: jeder spielt sein eigenes Feld, alle sind über ENet verbunden.
## Übers Netz gehen nur der Stand jedes Spielers (für die Liste) und, solange jemand zuschaut,
## der Abzug seines Felds (net_sync.gd sendet, remote_field.gd zeigt an).
## Die Verbindung bleibt über Szenenwechsel bestehen; jeder kann unabhängig starten und neu starten.
##
## Sitzung (Lobby): Der Host führt eine Sitzung mit dem Stand jedes Mitspielers, erkannt an einer
## festen Spieler-ID (uid). Nur der Host speichert, dabei holt er die Felder aller Mitspieler ein
## (save_session). Mitspieler melden ihren Stand außerdem zu Beginn jeder Bauphase und beim Verlassen,
## so kann jeder später wieder einsteigen (_join_game) und spielt genau dort weiter.

signal players_changed
signal connection_changed
signal field_received(peer: int, data: Dictionary)
signal map_received(peer: int, data: Dictionary)
signal enemies_received(peer: int, data: Dictionary)
signal watchers_changed
signal session_changed

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 8
const SETTINGS := "user://settings.cfg"
const SAVE_TIMEOUT := 2.5   ## Sekunden, die der Host beim Speichern auf die Felder der Mitspieler wartet

## peer_id -> {"name": String, "status": Dictionary, "uid": String}
var players: Dictionary = {}
var my_name := ""
## Feste Spieler-ID dieses Rechners, damit der Host einen Mitspieler beim Wiederkommen erkennt.
var uid := ""
## Laufendes Spiel (game.gd) oder null.
var game = null
## Nur beim Host: {id, map, map_name, started, loaded, players {uid: {name, state}}}
var session: Dictionary = {}
## Nur beim Mitspieler: was der Host über die Sitzung meldet (siehe _info_for).
var session_info: Dictionary = {}
var _reports: Dictionary = {}   ## Host beim Speichern: peer -> true, sobald der Stand da ist

## Host: Adresse fürs Internet. public_ip kommt von api.ipify.org, upnp_state sagt, ob der Router
## den Port per UPnP freigegeben hat: "" (noch nicht), "busy", "open", "failed".
var public_ip := ""
var public_ip_failed := false
var upnp_ip := ""      ## Adresse, die der Router per UPnP meldet (weicht bei CGNAT von public_ip ab)
var upnp_state := ""
var host_port := DEFAULT_PORT
var _upnp: UPNP
var _upnp_port := 0
var _upnp_thread: Thread
var _ip_request: HTTPRequest
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
		uid = str(cfg.get_value("net", "uid", ""))
	if my_name == "":
		my_name = tr("Spieler") + " %d" % (randi() % 900 + 100)
	if uid == "":
		uid = _random_uid()
		save_settings()
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
	cfg.set_value("net", "uid", uid)
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
	session = {"id": SaveGame.new_id(), "map": {}, "map_name": "", "started": false, "loaded": false, "players": {}}
	_set_status(tr("Hoste auf Port %d") % port)
	host_port = port
	_open_port(port)
	_fetch_public_ip()
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
	_close_port()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	watchers.clear()
	session = {}
	session_info = {}
	_reports.clear()
	_set_status("")
	session_changed.emit()
	players_changed.emit()
	watchers_changed.emit()
	connection_changed.emit()


# --- Erreichbarkeit übers Internet -------------------------------------------------

## Port im Router per UPnP freigeben (im Hintergrund, die Suche dauert bis zu zwei Sekunden).
func _open_port(port: int) -> void:
	if OS.has_feature("headless") or _upnp_thread != null:
		return
	upnp_state = "busy"
	upnp_ip = ""
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> void:
	var u := UPNP.new()
	var ok := u.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() != null and u.get_gateway().is_valid_gateway()
	if ok:
		ok = u.add_port_mapping(port, port, "GemTD", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
	var ext := u.query_external_address() if ok else ""
	call_deferred("_upnp_done", u if ok else null, port, ext)


func _upnp_done(u: UPNP, port: int, ext: String) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if not is_host():
		# Inzwischen getrennt: Freigabe gleich wieder entfernen
		if u != null:
			u.delete_port_mapping(port, "UDP")
		upnp_state = ""
		return
	_upnp = u
	_upnp_port = port
	upnp_ip = ext
	upnp_state = "open" if u != null else "failed"
	connection_changed.emit()


func _close_port() -> void:
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null
	upnp_state = ""
	upnp_ip = ""


func _fetch_public_ip() -> void:
	if OS.has_feature("headless"):
		return
	if _ip_request == null:
		_ip_request = HTTPRequest.new()
		_ip_request.timeout = 6.0
		add_child(_ip_request)
		_ip_request.request_completed.connect(_on_public_ip)
	if public_ip == "":
		public_ip_failed = false
		_ip_request.cancel_request()
		_ip_request.request("https://api.ipify.org")


func _on_public_ip(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ip := body.get_string_from_utf8().strip_edges()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and ip.count(".") == 3:
		public_ip = ip
	else:
		public_ip_failed = true
	connection_changed.emit()


## Hat der Anschluss keine eigene öffentliche Adresse (Carrier-Grade-NAT, oft bei Mobilfunk und Glasfaser)?
## Dann hilft auch eine Portfreigabe nicht, nur ein virtuelles LAN.
func behind_cgnat() -> bool:
	if upnp_ip == "":
		return false
	return _is_private(upnp_ip) or (public_ip != "" and upnp_ip != public_ip)


static func _is_private(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return false
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or (a == 172 and b >= 16 and b < 32) or (a == 192 and b == 168) or (a == 100 and b >= 64 and b < 128)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:   # beim Beenden die Freigabe im Router wieder entfernen
		_close_port()


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
		_hello.rpc(my_name, my_status, uid)


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


# --- Sitzung -------------------------------------------------------------------

## Host: Sitzung aus einem Mehrspieler-Spielstand übernehmen (vorher host()).
func load_session(data: Dictionary) -> void:
	if not is_host():
		return
	var ps: Dictionary = data.get("players", {}).duplicate(true)
	# Der eigene Stand liegt unter der uid, mit der gespeichert wurde.
	var old := str(data.get("host_uid", uid))
	if old != uid and ps.has(old):
		ps[uid] = ps[old]
		ps.erase(old)
	session = {
		"id": str(data.get("id", SaveGame.new_id())),
		"map": data.get("map", {}),
		"map_name": str(data.get("meta", {}).get("map", "")),
		"started": false,
		"loaded": true,
		"players": ps,
	}
	for peer in players:
		players[peer].uid = _resolve_uid(peer, str(players[peer].get("asked_uid", "")))
	_push_info()


## Host: Sitzung starten. Jeder Verbundene, der gerade nicht spielt, steigt ein:
## mit seinem gespeicherten Stand, sonst neu auf der Map. map_data gilt nur für neue Sitzungen.
func start_session(map_data: Dictionary) -> void:
	if not is_host():
		return
	if session.get("map", {}).is_empty():
		session.map = map_data
		session.map_name = str(map_data.get("name", ""))
	session.started = true
	_push_info()
	for peer in players:
		if not player_status(peer).get("in_game", false):
			_begin.rpc_id(peer, session.map, _state_of(str(players[peer].uid)))
	_begin_local(session.map, _state_of(uid))


## Einer laufenden Sitzung (wieder) beitreten.
func join_session() -> void:
	if is_host():
		if session.get("started", false):
			_begin_local(session.map, _state_of(uid))
	elif is_active():
		_join_game.rpc_id(1)


## Eigenen Stand dem Host geben (beim Verlassen und zu Beginn jeder Bauphase). Leer = Partie vorbei.
func report_state(state: Dictionary) -> void:
	if is_host():
		_store_state(uid, my_name, state)
	elif is_active():
		_state_report.rpc_id(1, state, true)
		var p := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if p != null and p.host != null:
			p.host.flush()   # vor einem sofortigen Beenden noch rausschicken


## Host: Felder aller Mitspieler einholen und zusammen mit dem eigenen verschlüsselt speichern.
## Wer nicht rechtzeitig antwortet, behält seinen zuletzt gemeldeten Stand.
func save_session(g) -> bool:
	if not is_host():
		return false
	_reports.clear()
	var waiting := []
	for peer in players:
		if player_status(peer).get("in_game", false):
			waiting.append(peer)
			_request_state.rpc_id(peer)
	var deadline := Time.get_ticks_msec() + int(SAVE_TIMEOUT * 1000.0)
	while Time.get_ticks_msec() < deadline \
			and waiting.any(func(p): return players.has(p) and not _reports.has(p)):
		await get_tree().create_timer(0.05, true, false, true).timeout
	if g != null:
		_store_state(uid, my_name, SaveGame.capture(g))
		if session.map.is_empty():
			session.map = g.map.to_dict()
			session.map_name = g.map.name
	var names := []
	for u in session.players:
		names.append(str(session.players[u].get("name", "?")))
	var meta := SaveGame.meta_for(g, {"players": names}) if g != null else {"map": session.map_name, "players": names, "time": int(Time.get_unix_time_from_system())}
	var ok := SaveGame.write({"id": session.id, "kind": "multi", "meta": meta, "map": session.map,
		"host_uid": uid, "players": session.players})
	_push_info()
	return ok


## Sitzungsplätze für die Lobby: [{uid, name, online, peer, wave, has_state}], der Host (peer 1) zuerst.
func session_slots() -> Array:
	var out := []
	if is_host():
		var online := {uid: 1}
		for peer in players:
			online[str(players[peer].uid)] = peer
		var uids := [uid]
		for peer in players:
			if not uids.has(players[peer].uid):
				uids.append(str(players[peer].uid))
		for u in session.get("players", {}):
			if not uids.has(u):
				uids.append(u)
		for u in uids:
			var entry: Dictionary = session.get("players", {}).get(u, {})
			var st: Dictionary = entry.get("state", {})
			var name := my_name if u == uid else (player_name(online[u]) if online.has(u) else str(entry.get("name", "?")))
			out.append({"uid": u, "name": name, "online": online.has(u), "peer": int(online.get(u, -1)),
				"has_state": not st.is_empty(), "wave": int(st.get("wave_index", 0)) + 1 if not st.is_empty() else 0})
	else:
		out = session_info.get("slots", [])
	return out


func _state_of(u: String) -> Dictionary:
	return session.get("players", {}).get(u, {}).get("state", {})


func _store_state(u: String, n: String, state: Dictionary) -> void:
	if session.is_empty():
		return
	var ps: Dictionary = session.players
	if not ps.has(u):
		ps[u] = {}
	ps[u].name = n
	ps[u].state = state
	_push_info()


## Host: Spieler-ID eines Mitspielers festlegen. Eine schon vergebene ID (zwei Fenster auf einem
## Rechner) bekommt einen freien Platz mit gleichem Namen oder eine neue ID.
func _resolve_uid(peer: int, asked: String) -> String:
	var taken := {uid: true}
	for p in players:
		if p != peer and players[p].has("uid"):
			taken[str(players[p].uid)] = true
	if asked != "" and not taken.has(asked):
		return asked
	var n := player_name(peer)
	for u in session.get("players", {}):
		if not taken.has(u) and str(session.players[u].get("name", "")) == n:
			return u
	return _random_uid()


## Host: was ein Mitspieler über die Sitzung sieht.
func _info_for(u: String) -> Dictionary:
	var st := _state_of(u)
	return {
		"started": session.get("started", false),
		"loaded": session.get("loaded", false),
		"map": str(session.get("map_name", "")),
		"has_state": not st.is_empty(),
		"wave": int(st.get("wave_index", 0)) + 1 if not st.is_empty() else 0,
		"slots": session_slots(),
	}


func _push_info() -> void:
	if not is_host():
		return
	for peer in players:
		if players[peer].has("uid"):
			_session_info.rpc_id(peer, _info_for(str(players[peer].uid)))
	session_changed.emit()


func _begin_local(map_data: Dictionary, state: Dictionary) -> void:
	Session.load_state = state.duplicate(true)
	Session.save_id = ""
	Session.map_override = MapData.from_dict(state.get("map", map_data))
	Session.test_tower = ""
	Session.return_scene = Session.MAIN_MENU
	Session.goto(Session.GAME)


static func _random_uid() -> String:
	return Crypto.new().generate_random_bytes(12).hex_encode()


# --- RPCs ------------------------------------------------------------------------

@rpc("any_peer", "reliable")
func _hello(n: String, status: Dictionary, their_uid: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var known: Dictionary = players.get(id, {})
	players[id] = {"name": n, "status": status, "asked_uid": their_uid}
	if is_host():
		players[id].uid = str(known.uid) if known.has("uid") else _resolve_uid(id, their_uid)
		if session.players.has(players[id].uid):
			session.players[players[id].uid].name = n
		_push_info()
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


## Host → Mitspieler: Spiel starten, mit gespeichertem Stand oder neu auf der Map.
@rpc("authority", "reliable")
func _begin(map_data: Dictionary, state: Dictionary) -> void:
	_begin_local(map_data, state)


## Mitspieler → Host: in die laufende Sitzung einsteigen.
@rpc("any_peer", "reliable")
func _join_game() -> void:
	var id := multiplayer.get_remote_sender_id()
	if is_host() and session.get("started", false) and players.has(id):
		_begin.rpc_id(id, session.map, _state_of(str(players[id].uid)))


## Host → Mitspieler: aktuellen Stand fürs Speichern schicken.
@rpc("authority", "reliable")
func _request_state() -> void:
	if game != null and is_instance_valid(game):
		_state_report.rpc_id(1, SaveGame.capture(game), true)
	else:
		_state_report.rpc_id(1, {}, false)


## Mitspieler → Host: Stand des eigenen Felds (in_game false: spielt gerade nicht, nichts ändern).
@rpc("any_peer", "reliable")
func _state_report(state: Dictionary, in_game: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not is_host() or not players.has(id):
		return
	_reports[id] = true
	if in_game:
		_store_state(str(players[id].uid), player_name(id), state)


@rpc("authority", "reliable")
func _session_info(info: Dictionary) -> void:
	session_info = info
	session_changed.emit()


# --- Verbindung ----------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	_hello.rpc_id(id, my_name, my_status, uid)


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	_reports.erase(id)
	if watchers.erase(id):
		watchers_changed.emit()
	_push_info()
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
