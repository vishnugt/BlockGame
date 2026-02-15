class_name PlayerControls
extends VBoxContainer

signal locked_in(player_id: int, answer: int)

@export var player_id: int = 1
@export var player_label: String = "P1"

var current_number: int = 0
var is_active: bool = false
var has_won: bool = false
var default_lock_text: String = "LOCK IN"
var lock_cooldown: float = 0.0

@onready var label: Label = $PlayerLabel
@onready var number_display: Label = $NumberDisplay
@onready var increment_btn: Button = $ButtonRow/IncrementBtn
@onready var decrement_btn: Button = $ButtonRow/DecrementBtn
@onready var lock_in_btn: Button = $LockInBtn

func _ready() -> void:
	label.text = player_label
	number_display.text = "0"
	default_lock_text = lock_in_btn.text
	increment_btn.pressed.connect(_on_increment)
	decrement_btn.pressed.connect(_on_decrement)
	lock_in_btn.pressed.connect(_on_lock_in)
	set_active(false)

func _process(delta: float) -> void:
	if lock_cooldown > 0.0:
		lock_cooldown -= delta
		if lock_cooldown > 0.0:
			lock_in_btn.text = "WRONG (%.1fs)" % lock_cooldown
		elif is_active:
			lock_in_btn.disabled = false
			lock_in_btn.text = default_lock_text
			lock_in_btn.modulate = Color.WHITE

	if not is_active:
		return
	if player_id == 1:
		if Input.is_action_just_pressed("p1_increment"):
			_on_increment()
		elif Input.is_action_just_pressed("p1_decrement"):
			_on_decrement()
		elif Input.is_action_just_pressed("p1_lock_in"):
			_on_lock_in()
	elif player_id == 2:
		if Input.is_action_just_pressed("p2_increment"):
			_on_increment()
		elif Input.is_action_just_pressed("p2_decrement"):
			_on_decrement()
		elif Input.is_action_just_pressed("p2_lock_in"):
			_on_lock_in()

func set_active(active: bool) -> void:
	is_active = active
	increment_btn.disabled = not active
	decrement_btn.disabled = not active
	lock_in_btn.disabled = not active

func reset() -> void:
	current_number = 0
	number_display.text = "0"
	has_won = false
	lock_cooldown = 0.0
	lock_in_btn.text = default_lock_text
	lock_in_btn.modulate = Color.WHITE

func show_result(correct: bool) -> void:
	if correct:
		lock_in_btn.text = "CORRECT!"
		lock_in_btn.modulate = Color(0.4, 1.0, 0.4, 1)
	else:
		lock_in_btn.text = "WRONG"
		lock_in_btn.modulate = Color(1.0, 0.4, 0.4, 1)

func start_wrong_cooldown() -> void:
	lock_cooldown = 1.5
	lock_in_btn.disabled = true
	lock_in_btn.text = "WRONG"
	lock_in_btn.modulate = Color(1.0, 0.4, 0.4, 1)

func _on_increment() -> void:
	if not is_active:
		return
	current_number += 1
	number_display.text = str(current_number)

func _on_decrement() -> void:
	if not is_active:
		return
	if current_number > 0:
		current_number -= 1
		number_display.text = str(current_number)

func _on_lock_in() -> void:
	if not is_active or lock_cooldown > 0.0:
		return
	locked_in.emit(player_id, current_number)
