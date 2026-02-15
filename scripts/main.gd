extends Node3D

enum GameState {
	MENU,
	VIEWING,
	ANSWERING,
	ROUND_RESULT,
	GAME_OVER,
}

var state: GameState = GameState.MENU
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
@onready var p1_name_input: LineEdit = $UI/StartScreen/VBoxContainer/NamesRow/P1NameContainer/P1NameInput
@onready var p2_name_input: LineEdit = $UI/StartScreen/VBoxContainer/NamesRow/P2NameContainer/P2NameInput
@onready var answer_score_p1: Label = $"UI/AnswerPhase/AnswerScoreBar/P1ScoreLabel"
@onready var answer_score_p2: Label = $"UI/AnswerPhase/AnswerScoreBar/P2ScoreLabel"
@onready var answer_round_label: Label = $"UI/AnswerPhase/AnswerScoreBar/RoundLabel"
@onready var answer_timer_bar: ProgressBar = $"UI/AnswerPhase/AnswerTimerBar"

var p1_name: String = "P1"
var p2_name: String = "P2"

func _ready() -> void:
	_setup_camera()
	_connect_signals()
	_set_state(GameState.MENU)

func _setup_camera() -> void:
	camera.size = 8.0
	camera.position = Vector3(8, 7, 8)
	camera.look_at(Vector3(1.5, 0, 1.5))

func _connect_signals() -> void:
	p1_controls.locked_in.connect(_on_player_lock_in)
	p2_controls.locked_in.connect(_on_player_lock_in)

func _process(delta: float) -> void:
	if input_cooldown > 0.0:
		input_cooldown -= delta

	match state:
		GameState.VIEWING:
			view_timer -= delta
			var pct = maxf(view_timer / view_timer_max, 0.0) * 100.0
			view_timer_bar.value = pct
			_update_bar_color(view_timer_bar, pct)
			if view_timer <= 0:
				_set_state(GameState.ANSWERING)
		GameState.ANSWERING:
			answer_timer -= delta
			var pct = maxf(answer_timer / answer_timer_max, 0.0) * 100.0
			answer_timer_bar.value = pct
			_update_bar_color(answer_timer_bar, pct)
			if answer_timer <= 0:
				_end_answer_phase()
		GameState.ROUND_RESULT:
			result_timer -= delta
			if result_timer <= 0:
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

func _on_start_pressed() -> void:
	p1_name = p1_name_input.text.strip_edges()
	p2_name = p2_name_input.text.strip_edges()
	if p1_name == "":
		p1_name = "P1"
	if p2_name == "":
		p2_name = "P2"

	p1_controls.player_label = p1_name
	p1_controls.get_node("PlayerLabel").text = p1_name
	p2_controls.player_label = p2_name
	p2_controls.get_node("PlayerLabel").text = p2_name

	game_manager.reset()
	start_screen.visible = false
	hud.get_parent().visible = true
	hud.set_names(p1_name, p2_name)
	hud.update_scores(0, 0)
	_set_state(GameState.VIEWING)

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
	p1_controls.set_active(true)
	p2_controls.set_active(true)

	block_prompt.text = "How many blocks?"
	block_prompt.modulate = Color(0, 0, 0, 1)
	block_prompt.visible = true

	# Update answer phase score display
	answer_score_p1.text = "%s: %d" % [p1_name, game_manager.p1_score]
	answer_score_p2.text = "%s: %d" % [p2_name, game_manager.p2_score]
	answer_round_label.text = "Round %d / %d" % [game_manager.current_round, GameManager.TOTAL_ROUNDS]

	answer_timer = GameManager.ANSWER_TIME
	answer_timer_max = GameManager.ANSWER_TIME
	answer_timer_bar.value = 100.0

func _on_player_lock_in(player_id: int, answer: int) -> void:
	if state != GameState.ANSWERING:
		return
	if input_cooldown > 0.0:
		return

	var result = game_manager.player_lock_in(player_id, answer)

	if not result.correct:
		# Wrong answer — disable lock-in for 0.5s
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
	game_manager.reset()
	_set_state(GameState.MENU)
