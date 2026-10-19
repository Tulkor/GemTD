class_name RelayPeer
extends MultiplayerPeerExtension
## Verbindung über den TD-Hub-Relay (tools/relay/relay.py) statt direkt per ENet: alle Spieler verbinden
## sich nur ausgehend per TCP mit dem Server, niemand muss einen Port freigeben. Der Host eröffnet einen
## Raum und bekommt einen Code (room_code), Mitspieler treten mit dem Code bei. Der Server leitet die
## Pakete weiter, auch direkt von Mitspieler zu Mitspieler, deshalb braucht es kein Server-Relay von Godot.
## Über TCP kommt jedes Paket an, auch die als „unreliable“ geschickten.

signal relay_error(code: String)   ## Server lehnt ab: version, unknown_code, room_full, full_server, timeout, …
signal welcomed(code: String)      ## im Raum angekommen (Host: Raum eröffnet)

const VERSION := "TDHUB1"
const DEFAULT_PORT := 24565
const HOST := 1
const JOIN := 2
const DATA := 3
const KICK := 4
const PING := 5
const WELCOME := 10
const PEER_ADD := 11
const PEER_DEL := 12
const DATA_IN := 13
const ERROR := 14
const MAX_FRAME := 16 * 1024 * 1024
const CONNECT_TIMEOUT := 10.0
const PING_EVERY := 10.0
const SILENCE_TIMEOUT := 40.0

var room_code := ""
var server_address := ""

var _tcp := StreamPeerTCP.new()
var _status := CONNECTION_DISCONNECTED
var _hosting := false
var _code_wanted := ""
var _max_players := 8
var _id := 0
var _peers: Dictionary = {}
var _queue: Array = []   ## [absender, kanal, modus, daten]
var _buf := PackedByteArray()
var _target := 0
var _channel := 0
var _mode := TRANSFER_MODE_RELIABLE
var _refuse := false
var _port := DEFAULT_PORT
var _resolve := -1
var _started := 0.0
var _last_in := 0.0
var _last_ping := 0.0
var _hello_sent := false


## Adresse "host" oder "host:port" in [host, port] zerlegen (IPv6 in eckigen Klammern).
static func split_address(address: String) -> Array:
	var a := address.strip_edges()
	var port := DEFAULT_PORT
	if a.begins_with("["):
		var end := a.find("]")
		if end > 0:
			if a.substr(end + 1).begins_with(":"):
				port = int(a.substr(end + 2))
			a = a.substr(1, end - 1)
	elif a.count(":") == 1:
		port = int(a.get_slice(":", 1))
		a = a.get_slice(":", 0)
	return [a, port if port > 0 else DEFAULT_PORT]


## Raum eröffnen (wird Host mit der Nummer 1).
func host(address: String, max_players := 8) -> Error:
	_hosting = true
	_max_players = max_players
	_id = 1
	return _start(address)


## Raum mit dem Code des Hosts betreten.
func join(address: String, code: String) -> Error:
	_hosting = false
	_code_wanted = code.strip_edges().to_upper()
	_id = generate_unique_id()
	return _start(address)


func _start(address: String) -> Error:
	var parts := split_address(address)
	if str(parts[0]) == "":
		return ERR_INVALID_PARAMETER
	server_address = address.strip_edges()
	_port = parts[1]
	_status = CONNECTION_CONNECTING
	_started = _now()
	if str(parts[0]).is_valid_ip_address():
		return _tcp.connect_to_host(parts[0], _port)
	_resolve = IP.resolve_hostname_queue_item(parts[0])
	return OK if _resolve != IP.RESOLVER_INVALID_ID else ERR_CANT_RESOLVE


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _fail(code: String) -> void:
	relay_error.emit(code)
	_drop()


func _drop() -> void:
	if _resolve >= 0:
		IP.erase_resolve_item(_resolve)
		_resolve = -1
	_tcp.disconnect_from_host()
	var was := _peers.keys()
	_peers.clear()
	for p in was:
		peer_disconnected.emit(p)
	_queue.clear()
	_buf.clear()
	_status = CONNECTION_DISCONNECTED


func _send(kind: int, body := PackedByteArray()) -> void:
	if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var head := PackedByteArray()
	head.resize(5)
	head.encode_u32(0, body.size() + 1)
	head[4] = kind
	_tcp.put_data(head + body)


func _poll() -> void:
	if _status == CONNECTION_DISCONNECTED:
		return
	if _resolve >= 0:
		match IP.get_resolve_item_status(_resolve):
			IP.RESOLVER_STATUS_DONE:
				var ip := IP.get_resolve_item_address(_resolve)
				IP.erase_resolve_item(_resolve)
				_resolve = -1
				if ip == "" or _tcp.connect_to_host(ip, _port) != OK:
					_fail("resolve")
				return
			IP.RESOLVER_STATUS_ERROR, IP.RESOLVER_STATUS_NONE:
				_fail("resolve")
				return
			_:
				if _now() - _started > CONNECT_TIMEOUT:
					_fail("timeout")
				return
	_tcp.poll()
	match _tcp.get_status():
		StreamPeerTCP.STATUS_CONNECTING:
			if _now() - _started > CONNECT_TIMEOUT:
				_fail("timeout")
			return
		StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE:
			if _status == CONNECTION_CONNECTING:
				_fail("unreachable")
			else:
				_drop()
			return
	if not _hello_sent:
		_hello_sent = true
		_last_in = _now()
		_last_ping = _now()
		if _hosting:
			_send(HOST, ("%s|%d" % [VERSION, _max_players]).to_utf8_buffer())
		else:
			_send(JOIN, ("%s|%s|%d" % [VERSION, _code_wanted, _id]).to_utf8_buffer())
	var n := _tcp.get_available_bytes()
	if n > 0:
		var got := _tcp.get_data(n)
		if got[0] == OK:
			_buf.append_array(got[1])
			_last_in = _now()
	_read_frames()
	if _status == CONNECTION_DISCONNECTED:
		return
	if _status == CONNECTION_CONNECTING and _now() - _started > CONNECT_TIMEOUT:
		_fail("timeout")
	elif _now() - _last_in > SILENCE_TIMEOUT:
		_drop()
	elif _now() - _last_ping > PING_EVERY:
		_last_ping = _now()
		_send(PING)


func _read_frames() -> void:
	var off := 0
	while _buf.size() - off >= 4:
		var size := _buf.decode_u32(off)
		if size < 1 or size > MAX_FRAME:
			_drop()
			return
		if _buf.size() - off - 4 < size:
			break
		var kind := _buf[off + 4]
		var body := _buf.slice(off + 5, off + 4 + size)
		off += 4 + size
		_frame(kind, body)
		if _status == CONNECTION_DISCONNECTED:
			return
	if off > 0:
		_buf = _buf.slice(off)


func _frame(kind: int, body: PackedByteArray) -> void:
	match kind:
		WELCOME:
			_id = body.decode_s32(0)
			room_code = body.slice(4).get_string_from_utf8()
			_status = CONNECTION_CONNECTED
			welcomed.emit(room_code)
		PEER_ADD:
			var p := body.decode_s32(0)
			if not _peers.has(p):
				_peers[p] = true
				peer_connected.emit(p)
		PEER_DEL:
			var p := body.decode_s32(0)
			if _peers.erase(p):
				peer_disconnected.emit(p)
		DATA_IN:
			if body.size() >= 6:
				_queue.append([body.decode_s32(0), body[4], body[5], body.slice(6)])
		ERROR:
			_fail(body.get_string_from_utf8())


func _get_available_packet_count() -> int:
	return _queue.size()


func _get_max_packet_size() -> int:
	return MAX_FRAME - 16


func _get_packet_script() -> PackedByteArray:
	return _queue.pop_front()[3] if not _queue.is_empty() else PackedByteArray()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var head := PackedByteArray()
	head.resize(6)
	head.encode_s32(0, _target)
	head[4] = _channel
	head[5] = _mode
	_send(DATA, head + buffer)
	return OK


func _get_packet_peer() -> int:
	return _queue[0][0] if not _queue.is_empty() else 0


func _get_packet_channel() -> int:
	return _queue[0][1] if not _queue.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return _queue[0][2] if not _queue.is_empty() else TRANSFER_MODE_RELIABLE


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> TransferMode:
	return _mode


func _set_target_peer(peer: int) -> void:
	_target = peer


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return _hosting


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


func _get_connection_status() -> ConnectionStatus:
	return _status


func _disconnect_peer(peer: int, _force: bool) -> void:
	if _hosting and _peers.has(peer):
		var body := PackedByteArray()
		body.resize(4)
		body.encode_s32(0, peer)
		_send(KICK, body)


func _close() -> void:
	_drop()
