extends HBoxContainer

@onready var p1_score_label: Label = $P1Score
@onready var round_label: Label = $RoundInfo
@onready var p2_score_label: Label = $P2Score

var p1_name: String = "P1"
var p2_name: String = "P2"

func set_names(name1: String, name2: String) -> void:
	p1_name = name1
	p2_name = name2

func update_scores(p1: int, p2: int) -> void:
	p1_score_label.text = "%s: %d" % [p1_name, p1]
	p2_score_label.text = "%s: %d" % [p2_name, p2]

func update_round(current: int, total: int) -> void:
	round_label.text = "Round %d / %d" % [current, total]
