extends Node

signal connected_to_room(your_slot: int, room_id: String)
signal connection_failed(reason: String)
signal player_joined(slot: int, name: String)
signal player_left(slot: int)
signal game_started(p1_name: String, p2_name: String)
signal round_started(round: int, seed: int, level_index: int, view_duration_ms: int, answer_duration_ms: int, server_ts: float)
signal answer_phase_begun(server_ts: float)
signal lock_in_result_received(slot: int, correct: bool, data: Dictionary)
signal reactivate_input(slot: int)
signal round_ended(data: Dictionary)
signal game_over_received(data: Dictionary)
signal opponent_number_changed(slot: int, value: int)

const SERVER_WS_URL = "wss://api-game1.gt.ms/ws"
const SERVER_HTTP_URL = "https://api-game1.gt.ms"

var socket: WebSocketPeer = WebSocketPeer.new()
var my_slot: int = -1
var room_id: String = ""
var is_connected: bool = false
var _connecting: bool = false

func _process(_delta: float) -> void:
	if not _connecting and not is_connected:
		return
	socket.poll()
	var ready_state = socket.get_ready_state()
	match ready_state:
		WebSocketPeer.STATE_OPEN:
			_connecting = false
			while socket.get_available_packet_count() > 0:
				_handle_packet(socket.get_packet())
		WebSocketPeer.STATE_CLOSED:
			if is_connected or _connecting:
				is_connected = false
				_connecting = false
				var code = socket.get_close_code()
				var reason = socket.get_close_reason()
				if code == 4000:
					connection_failed.emit("Room not found.")
				elif code == 4001:
					connection_failed.emit("Room is full.")
				else:
					connection_failed.emit("Disconnected (%d: %s)" % [code, reason])

func connect_to_room(room: String, player_name: String) -> void:
	room_id = room
	_connecting = true
	is_connected = false
	var encoded_name = player_name.uri_encode()
	var url = "%s?room=%s&name=%s" % [SERVER_WS_URL, room, encoded_name]
	socket = WebSocketPeer.new()
	socket.connect_to_url(url)

func send(data: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func disconnect_from_room() -> void:
	is_connected = false
	_connecting = false
	socket.close()

func _handle_packet(raw: PackedByteArray) -> void:
	var text = raw.get_string_from_utf8()
	var msg = JSON.parse_string(text)
	if msg == null:
		return
	match msg.get("type", ""):
		"room_joined":
			my_slot = msg["your_slot"]
			is_connected = true
			connected_to_room.emit(my_slot, msg["room_id"])
		"player_connected":
			player_joined.emit(msg["slot"], msg["name"])
		"player_disconnected":
			player_left.emit(msg["slot"])
		"game_start":
			game_started.emit(msg["p1_name"], msg["p2_name"])
		"round_start":
			round_started.emit(
				msg["round"], msg["seed"], msg["level_index"],
				msg["view_duration_ms"], msg["answer_duration_ms"],
				float(msg["server_ts"])
			)
		"answer_phase_start":
			answer_phase_begun.emit(float(msg["server_ts"]))
		"lock_in_result":
			lock_in_result_received.emit(msg["slot"], msg["correct"], msg)
		"reactivate_input":
			reactivate_input.emit(msg["slot"])
		"round_end":
			round_ended.emit(msg)
		"game_over":
			game_over_received.emit(msg)
		"opponent_number_changed":
			opponent_number_changed.emit(msg["slot"], msg["value"])
