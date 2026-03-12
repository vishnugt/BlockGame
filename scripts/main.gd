extends Node3D

enum GameState {
	MENU,
	VIEWING,
	ANSWERING,
	ROUND_RESULT,
	GAME_OVER,
}

enum NetworkMode { LOCAL, ONLINE }

var state: GameState = GameState.MENU
var network_mode: NetworkMode = NetworkMode.LOCAL
var my_slot: int = -1  # 1 or 2 in online mode
var game_manager: GameManager = GameManager.new()
var view_timer: float = 0.0
var view_timer_max: float = 1.0
var answer_timer: float = 0.0
var answer_timer_max: float = 1.0
var result_timer: float = 0.0
var current_level: Dictionary = {}
var input_cooldown: float = 0.0

@onready var game_grid: GameGrid = $GameGrid
@onready var camera: Camera3D = $IsometricCamera

# UI References
@onready var start_screen: Control = $UI/StartScreen
@onready var hud: HBoxContainer = $UI/HUD/ScoreBar
@onready var view_timer_bar: ProgressBar = $UI/HUD/TimerBar
@onready var answer_phase: Control = $UI/AnswerPhase
@onready var p1_controls: PlayerControls = $UI/AnswerPhase/PlayerContainer/P1Controls
@onready var p2_controls: PlayerControls = $UI/AnswerPhase/PlayerContainer/P2Controls
@onready var block_prompt: Label = $UI/AnswerPhase/ColorPrompt
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var result_overlay: Control = $UI/ResultOverlay
@onready var p1_name_input: LineEdit = $UI/StartScreen/VBoxContainer/LocalPanel/NamesRow/P1NameContainer/P1NameInput
@onready var p2_name_input: LineEdit = $UI/StartScreen/VBoxContainer/LocalPanel/NamesRow/P2NameContainer/P2NameInput
@onready var answer_score_p1: Label = $"UI/AnswerPhase/AnswerScoreBar/P1ScoreLabel"
@onready var answer_score_p2: Label = $"UI/AnswerPhase/AnswerScoreBar/P2ScoreLabel"
@onready var answer_round_label: Label = $"UI/AnswerPhase/AnswerScoreBar/RoundLabel"
@onready var answer_timer_bar: ProgressBar = $"UI/AnswerPhase/AnswerTimerBar"

@onready var mode_panel: Control = $UI/StartScreen/VBoxContainer/ModePanel
@onready var local_panel: Control = $UI/StartScreen/VBoxContainer/LocalPanel
@onready var online_panel: Control = $UI/StartScreen/VBoxContainer/OnlinePanel
@onready var join_panel: Control = $UI/StartScreen/VBoxContainer/JoinPanel
@onready var waiting_panel: Control = $UI/StartScreen/VBoxContainer/WaitingPanel
@onready var online_name_input: LineEdit = $UI/StartScreen/VBoxContainer/OnlinePanel/OnlineNameInput
@onready var join_name_input: LineEdit = $UI/StartScreen/VBoxContainer/JoinPanel/JoinNameInput
@onready var room_code_input: LineEdit = $UI/StartScreen/VBoxContainer/JoinPanel/RoomCodeInput
@onready var share_link_label: Label = $UI/StartScreen/VBoxContainer/WaitingPanel/ShareLinkLabel
@onready var connection_status_label: Label = $UI/StartScreen/VBoxContainer/OnlinePanel/StatusLabel
@onready var join_status_label: Label = $UI/StartScreen/VBoxContainer/JoinPanel/JoinStatusLabel

var p1_name: String = "P1"
var p2_name: String = "P2"
var _http_request: HTTPRequest

func _ready() -> void:
	_setup_camera()
	_connect_signals()
	_setup_http_request()
	_set_state(GameState.MENU)
	_check_url_room()

func _setup_camera() -> void:
	camera.size = 8.0
	camera.position = Vector3(8, 7, 8)
	camera.look_at(Vector3(1.5, 0, 1.5))

func _setup_http_request() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_room_created)

func _connect_signals() -> void:
	p1_controls.locked_in.connect(_on_player_lock_in)
	p2_controls.locked_in.connect(_on_player_lock_in)
	p1_controls.number_changed.connect(_on_player_number_changed)
	p2_controls.number_changed.connect(_on_player_number_changed)

	# Network signals
	NetworkManager.connected_to_room.connect(_on_network_connected)
	NetworkManager.connection_failed.connect(_on_network_failed)
	NetworkManager.player_joined.connect(_on_network_player_joined)
	NetworkManager.player_left.connect(_on_network_player_left)
	NetworkManager.game_started.connect(_on_network_game_started)
	NetworkManager.round_started.connect(_on_network_round_started)
	NetworkManager.answer_phase_begun.connect(_on_network_answer_phase)
	NetworkManager.lock_in_result_received.connect(_on_network_lock_in_result)
	NetworkManager.reactivate_input.connect(_on_network_reactivate_input)
	NetworkManager.round_ended.connect(_on_network_round_end)
	NetworkManager.game_over_received.connect(_on_network_game_over)
	NetworkManager.opponent_number_changed.connect(_on_opponent_number_changed)

func _check_url_room() -> void:
	if OS.get_name() != "Web":
		return
	var room = JavaScriptBridge.eval("window.BLOCK_COUNT_ROOM || ''")
	if room != null and str(room).length() > 0:
		# Pre-fill room code and go straight to join panel
		room_code_input.text = str(room).to_lower()
		_show_join_panel()

func _process(delta: float) -> void:
	if input_cooldown > 0.0:
		input_cooldown -= delta

	match state:
		GameState.VIEWING:
			view_timer -= delta
			var pct = maxf(view_timer / view_timer_max, 0.0) * 100.0
			view_timer_bar.value = pct
			_update_bar_color(view_timer_bar, pct)
			if view_timer <= 0 and network_mode == NetworkMode.LOCAL:
				_set_state(GameState.ANSWERING)
		GameState.ANSWERING:
			answer_timer -= delta
			var pct = maxf(answer_timer / answer_timer_max, 0.0) * 100.0
			answer_timer_bar.value = pct
			_update_bar_color(answer_timer_bar, pct)
			if answer_timer <= 0 and network_mode == NetworkMode.LOCAL:
				_end_answer_phase()
		GameState.ROUND_RESULT:
			result_timer -= delta
			if result_timer <= 0 and network_mode == NetworkMode.LOCAL:
				_next_round_or_end()

func _set_state(new_state: GameState) -> void:
	state = new_state
	match new_state:
		GameState.MENU:
			_show_menu()
		GameState.VIEWING:
			_start_viewing()
		GameState.ANSWERING:
			_start_answering()
		GameState.ROUND_RESULT:
			_show_round_result()
		GameState.GAME_OVER:
			_show_game_over()

func _show_menu() -> void:
	start_screen.visible = true
	hud.get_parent().visible = false
	answer_phase.visible = false
	game_over_screen.visible = false
	result_overlay.visible = false
	game_grid.hide_grid()
	_show_mode_panel()

func _show_mode_panel() -> void:
	mode_panel.visible = true
	local_panel.visible = false
	online_panel.visible = false
	join_panel.visible = false
	waiting_panel.visible = false

func _show_local_panel() -> void:
	mode_panel.visible = false
	local_panel.visible = true
	online_panel.visible = false
	join_panel.visible = false
	waiting_panel.visible = false

func _show_online_panel() -> void:
	mode_panel.visible = false
	local_panel.visible = false
	online_panel.visible = true
	join_panel.visible = false
	waiting_panel.visible = false
	connection_status_label.text = ""

func _show_join_panel() -> void:
	mode_panel.visible = false
	local_panel.visible = false
	online_panel.visible = false
	join_panel.visible = true
	waiting_panel.visible = false
	join_status_label.text = ""

# --- Local multiplayer ---

func _on_start_pressed() -> void:
	p1_name = p1_name_input.text.strip_edges()
	p2_name = p2_name_input.text.strip_edges()
	if p1_name == "":
		p1_name = "P1"
	if p2_name == "":
		p2_name = "P2"

	network_mode = NetworkMode.LOCAL
	_begin_game(p1_name, p2_name)

# --- Online multiplayer: Host ---

func _on_local_mode_pressed() -> void:
	_show_local_panel()

func _on_online_mode_pressed() -> void:
	_show_online_panel()

func _on_back_to_mode_pressed() -> void:
	network_mode = NetworkMode.LOCAL
	NetworkManager.disconnect_from_room()
	_show_mode_panel()

func _on_back_to_online_pressed() -> void:
	_show_online_panel()

func _on_join_flow_pressed() -> void:
	_show_join_panel()

func _on_copy_link_pressed() -> void:
	var link = share_link_label.text
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("navigator.clipboard.writeText('%s')" % link)
	DisplayServer.clipboard_set(link)

func _on_cancel_waiting_pressed() -> void:
	NetworkManager.disconnect_from_room()
	network_mode = NetworkMode.LOCAL
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("history.replaceState(null,'','/')")
	_show_local_panel()

func _on_host_pressed() -> void:
	connection_status_label.text = "Creating room..."
	var server_url = NetworkManager.SERVER_HTTP_URL + "/room"
	var err = _http_request.request(server_url, [], HTTPClient.METHOD_POST)
	if err != OK:
		connection_status_label.text = "Failed to reach server."

func _on_room_created(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		connection_status_label.text = "Server error (%d)." % response_code
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("room_id"):
		connection_status_label.text = "Invalid server response."
		return

	var room_id: String = json["room_id"]
	NetworkManager.room_id = room_id

	# Update browser URL
	if OS.get_name() == "Web":
		JavaScriptBridge.eval("history.replaceState(null,'','?room=%s')" % room_id)

	var player_name = online_name_input.text.strip_edges()
	if player_name == "":
		player_name = "Player"

	# Show waiting panel with shareable link
	online_panel.visible = false
	waiting_panel.visible = true
	var base_url = "http://localhost:8060"
	if OS.get_name() == "Web":
		base_url = JavaScriptBridge.eval("window.location.origin")
	share_link_label.text = "%s?room=%s" % [base_url, room_id]

	network_mode = NetworkMode.ONLINE
	NetworkManager.connect_to_room(room_id, player_name)

# --- Online multiplayer: Join ---

func _on_join_pressed() -> void:
	var room_code = room_code_input.text.strip_edges().to_lower()
	if room_code.length() < 3 or not "-" in room_code:
		join_status_label.text = "Enter a room code (e.g. apple-mango)."
		return
	var player_name = join_name_input.text.strip_edges()
	if player_name == "":
		player_name = "Player"
	join_status_label.text = "Connecting..."
	network_mode = NetworkMode.ONLINE
	NetworkManager.connect_to_room(room_code, player_name)

# --- Network event handlers ---

func _on_network_connected(slot: int, room_id: String) -> void:
	my_slot = slot
	if join_panel.visible:
		join_status_label.text = "Connected! Waiting for game to start..."
	else:
		connection_status_label.text = "Connected. Waiting for opponent..."

func _on_network_failed(reason: String) -> void:
	network_mode = NetworkMode.LOCAL
	_show_online_panel()
	connection_status_label.text = "Failed: %s" % reason

func _on_network_player_joined(slot: int, name: String) -> void:
	connection_status_label.text = "%s joined!" % name

func _on_network_player_left(_slot: int) -> void:
	if state != GameState.MENU:
		# Show a notice — game_over signal will follow from server
		connection_status_label.text = "Opponent disconnected."

func _on_network_game_started(p1: String, p2: String) -> void:
	p1_name = p1
	p2_name = p2
	_begin_game(p1_name, p2_name)

func _begin_game(pname1: String, pname2: String) -> void:
	p1_controls.player_label = pname1
	p1_controls.get_node("PlayerLabel").text = pname1
	p2_controls.player_label = pname2
	p2_controls.get_node("PlayerLabel").text = pname2

	game_manager.reset()
	start_screen.visible = false
	hud.get_parent().visible = true
	hud.set_names(pname1, pname2)
	hud.update_scores(0, 0)

	if network_mode == NetworkMode.LOCAL:
		_set_state(GameState.VIEWING)
	# In ONLINE mode, wait for round_start from server

func _on_network_round_started(round: int, seed: int, level_index: int, view_duration_ms: int, _answer_duration_ms: int, server_ts: float) -> void:
	game_manager.current_round = round
	game_manager.round_winner = -1
	game_manager.p1_correct = false
	game_manager.p2_correct = false

	var level = LevelConfig.get_level(round)
	var count = game_grid.generate_layout(level, seed)
	game_manager.correct_answer = count
	game_grid.set_grid_speed(level["grid_speed"])

	current_level = level

	var gs = game_grid.grid_size
	var center = (gs - 1) / 2.0
	camera.size = 6.0 + gs
	camera.position = Vector3(center + 6, 7, center + 6)
	camera.look_at(Vector3(center, 0, center))

	hud.update_round(round, GameManager.TOTAL_ROUNDS)
	hud.update_scores(game_manager.p1_score, game_manager.p2_score)

	game_grid.show_grid()
	answer_phase.visible = false
	result_overlay.visible = false
	start_screen.visible = false

	# Adjust timer for network latency
	var elapsed_ms = clampf(Time.get_unix_time_from_system() * 1000.0 - server_ts, 0.0, float(view_duration_ms))
	view_timer = (view_duration_ms - elapsed_ms) / 1000.0
	view_timer_max = view_duration_ms / 1000.0
	view_timer_bar.value = 100.0
	view_timer_bar.visible = true

	state = GameState.VIEWING

func _on_network_answer_phase(_server_ts: float) -> void:
	if state == GameState.VIEWING:
		_set_state(GameState.ANSWERING)

func _on_network_lock_in_result(slot: int, correct: bool, data: Dictionary) -> void:
	var controls = p1_controls if slot == 1 else p2_controls

	if not correct:
		controls.start_wrong_cooldown()
		return

	controls.show_result(true)
	controls.set_active(false)

	game_manager.p1_score = data.get("p1_score", game_manager.p1_score)
	game_manager.p2_score = data.get("p2_score", game_manager.p2_score)
	if slot == 1:
		game_manager.p1_correct = true
	else:
		game_manager.p2_correct = true

	hud.update_scores(game_manager.p1_score, game_manager.p2_score)
	answer_score_p1.text = "%s: %d" % [p1_name, game_manager.p1_score]
	answer_score_p2.text = "%s: %d" % [p2_name, game_manager.p2_score]

func _on_network_reactivate_input(slot: int) -> void:
	# Only re-enable the local player's input
	if slot == my_slot:
		var controls = p1_controls if slot == 1 else p2_controls
		controls.set_active(true)
		controls.lock_cooldown = 0.0
		controls.lock_in_btn.text = controls.default_lock_text
		controls.lock_in_btn.modulate = Color.WHITE

func _on_network_round_end(data: Dictionary) -> void:
	game_manager.correct_answer = data["correct_answer"]
	game_manager.round_winner = data["round_winner"]
	game_manager.p1_score = data["p1_score"]
	game_manager.p2_score = data["p2_score"]

	p1_controls.set_active(false)
	p2_controls.set_active(false)
	if not game_manager.p1_correct:
		p1_controls.show_result(false)
	if not game_manager.p2_correct:
		p2_controls.show_result(false)

	_set_state(GameState.ROUND_RESULT)
	result_timer = 999.0  # Server drives next round

func _on_network_game_over(data: Dictionary) -> void:
	game_manager.p1_score = data["p1_score"]
	game_manager.p2_score = data["p2_score"]
	_set_state(GameState.GAME_OVER)

func _on_opponent_number_changed(slot: int, value: int) -> void:
	# Show opponent's current guess (read-only display)
	var controls = p1_controls if slot == 1 else p2_controls
	controls.current_number = value
	controls.number_display.text = str(value)

# --- Existing local game logic (unchanged) ---

func _start_viewing() -> void:
	current_level = game_manager.start_round(game_grid)
	hud.update_round(game_manager.current_round, GameManager.TOTAL_ROUNDS)
	hud.update_scores(game_manager.p1_score, game_manager.p2_score)

	var gs = game_grid.grid_size
	var center = (gs - 1) / 2.0
	camera.size = 6.0 + gs
	camera.position = Vector3(center + 6, 7, center + 6)
	camera.look_at(Vector3(center, 0, center))

	game_grid.show_grid()
	answer_phase.visible = false
	result_overlay.visible = false

	view_timer = current_level["view_time"]
	view_timer_max = view_timer
	view_timer_bar.value = 100.0
	view_timer_bar.visible = true

func _start_answering() -> void:
	game_grid.hide_grid()
	answer_phase.visible = true

	p1_controls.reset()
	p2_controls.reset()

	if network_mode == NetworkMode.LOCAL:
		p1_controls.set_active(true)
		p2_controls.set_active(true)
	else:
		# Active player gets full controls; opponent panel shows number only (no buttons)
		p1_controls.reset()
		p2_controls.reset()
		if my_slot == 1:
			p1_controls.online_mode = true
			p1_controls.set_active(true)
			p1_controls.set_online_button_labels()
			p2_controls.set_opponent_mode(true)
		else:
			p2_controls.online_mode = true
			p2_controls.set_active(true)
			p2_controls.set_online_button_labels()
			p1_controls.set_opponent_mode(true)

	block_prompt.text = "How many blocks?"
	block_prompt.modulate = Color(0, 0, 0, 1)
	block_prompt.visible = true

	answer_score_p1.text = "%s: %d" % [p1_name, game_manager.p1_score]
	answer_score_p2.text = "%s: %d" % [p2_name, game_manager.p2_score]
	answer_round_label.text = "Round %d / %d" % [game_manager.current_round, GameManager.TOTAL_ROUNDS]

	answer_timer = GameManager.ANSWER_TIME
	answer_timer_max = GameManager.ANSWER_TIME
	answer_timer_bar.value = 100.0

func _on_player_lock_in(player_id: int, answer: int) -> void:
	if state != GameState.ANSWERING:
		return

	if network_mode == NetworkMode.ONLINE:
		# Only the local player can lock in
		if player_id != my_slot:
			return
		# Send to server and wait for authoritative result
		var controls = p1_controls if player_id == 1 else p2_controls
		controls.set_active(false)
		NetworkManager.send({"type": "lock_in", "answer": answer})
		return

	# --- Local mode ---
	if input_cooldown > 0.0:
		return

	var result = game_manager.player_lock_in(player_id, answer)

	if not result.correct:
		if player_id == 1:
			p1_controls.start_wrong_cooldown()
		else:
			p2_controls.start_wrong_cooldown()
		return

	if result.correct:
		if player_id == 1:
			p1_controls.show_result(true)
			p1_controls.set_active(false)
		else:
			p2_controls.show_result(true)
			p2_controls.set_active(false)
		hud.update_scores(game_manager.p1_score, game_manager.p2_score)
		answer_score_p1.text = "%s: %d" % [p1_name, game_manager.p1_score]
		answer_score_p2.text = "%s: %d" % [p2_name, game_manager.p2_score]

		if game_manager.round_winner != -1:
			p1_controls.set_active(false)
			p2_controls.set_active(false)
			input_cooldown = 0.5
			_end_answer_phase()

func _on_player_number_changed(player_id: int, value: int) -> void:
	if network_mode == NetworkMode.ONLINE and player_id == my_slot:
		NetworkManager.send({"type": "number_changed", "value": value})

func _end_answer_phase() -> void:
	p1_controls.set_active(false)
	p2_controls.set_active(false)

	if not game_manager.p1_correct:
		p1_controls.show_result(false)
	if not game_manager.p2_correct:
		p2_controls.show_result(false)

	_set_state(GameState.ROUND_RESULT)

func _show_round_result() -> void:
	result_overlay.visible = true
	var correct_label: Label = result_overlay.get_node("CorrectAnswer")
	correct_label.text = "Answer: %d" % game_manager.correct_answer

	var winner_label: Label = result_overlay.get_node("RoundWinner")
	match game_manager.round_winner:
		-1:
			winner_label.text = "No one got it!"
		0:
			winner_label.text = "Both players got it!"
		1:
			winner_label.text = "%s wins the round!" % p1_name
		2:
			winner_label.text = "%s wins the round!" % p2_name

	result_timer = 2.5

func _next_round_or_end() -> void:
	if game_manager.is_game_over():
		_set_state(GameState.GAME_OVER)
	else:
		_set_state(GameState.VIEWING)

func _show_game_over() -> void:
	answer_phase.visible = false
	result_overlay.visible = false
	game_over_screen.visible = true

	var winner_label: Label = game_over_screen.get_node("VBoxContainer/WinnerLabel")
	var score_label: Label = game_over_screen.get_node("VBoxContainer/FinalScore")

	score_label.text = "%s: %d  -  %s: %d" % [p1_name, game_manager.p1_score, p2_name, game_manager.p2_score]

	match game_manager.get_winner():
		0:
			winner_label.text = "IT'S A TIE!"
		1:
			winner_label.text = "%s WINS!" % p1_name.to_upper()
		2:
			winner_label.text = "%s WINS!" % p2_name.to_upper()

func _update_bar_color(bar: ProgressBar, pct: float) -> void:
	var fill_style = StyleBoxFlat.new()
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.corner_radius_bottom_left = 4
	if pct <= 20.0:
		fill_style.bg_color = Color(0.6, 0.15, 0.15, 1)
	else:
		fill_style.bg_color = Color(0.15, 0.15, 0.15, 1)
	bar.add_theme_stylebox_override("fill", fill_style)

func _on_play_again_pressed() -> void:
	game_over_screen.visible = false
	if network_mode == NetworkMode.ONLINE:
		NetworkManager.disconnect_from_room()
		network_mode = NetworkMode.LOCAL
		if OS.get_name() == "Web":
			JavaScriptBridge.eval("history.replaceState(null,'','/')")
	game_manager.reset()
	_set_state(GameState.MENU)
