class_name GameManager
extends RefCounted

var p1_score: int = 0
var p2_score: int = 0
var current_round: int = 0
var correct_answer: int = 0
var round_winner: int = -1  # -1 = none yet, 0 = both, 1 = p1, 2 = p2
var p1_correct: bool = false
var p2_correct: bool = false

const TOTAL_ROUNDS = 15
const ANSWER_TIME = 45.0

func reset() -> void:
	p1_score = 0
	p2_score = 0
	current_round = 0
	correct_answer = 0
	round_winner = -1
	p1_correct = false
	p2_correct = false

func start_round(grid: GameGrid) -> Dictionary:
	current_round += 1
	round_winner = -1
	p1_correct = false
	p2_correct = false

	var level = LevelConfig.get_level(current_round)
	var count = grid.generate_layout(level)
	correct_answer = count

	# Set grid movement speed for this round
	grid.set_grid_speed(level["grid_speed"])

	return level

func player_lock_in(player_id: int, answer: int) -> Dictionary:
	var is_correct = (answer == correct_answer)
	var result = {"correct": is_correct, "won_round": false, "points_awarded": false}

	if not is_correct:
		return result

	if player_id == 1:
		if p1_correct:
			return result
		p1_correct = true
		if p2_correct:
			if round_winner == -1:
				round_winner = 0
				p1_score += 1
				p2_score += 1
				result.won_round = true
				result.points_awarded = true
		else:
			if round_winner == -1:
				round_winner = 1
				p1_score += 1
				result.won_round = true
				result.points_awarded = true
	elif player_id == 2:
		if p2_correct:
			return result
		p2_correct = true
		if p1_correct:
			if round_winner == -1:
				round_winner = 0
				p1_score += 1
				p2_score += 1
				result.won_round = true
				result.points_awarded = true
		else:
			if round_winner == -1:
				round_winner = 2
				p2_score += 1
				result.won_round = true
				result.points_awarded = true

	return result

func is_game_over() -> bool:
	return current_round >= TOTAL_ROUNDS

func get_winner() -> int:
	if p1_score > p2_score:
		return 1
	elif p2_score > p1_score:
		return 2
	else:
		return 0  # Tie
