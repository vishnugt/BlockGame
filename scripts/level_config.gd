class_name LevelConfig
extends RefCounted

# grid_speed: units per second the grid moves left-to-right (0 = stationary)
# max_blocks is always <= 50% of grid cells (4x4=16, 5x5=25, 6x6=36)
# No stacking — max_height always 1
const LEVELS = [
	# Rounds 1-2: 4x4 (16 cells, max 8), no movement
	{"min_blocks": 3, "max_blocks": 6, "max_height": 1, "view_time": 4.0, "grid_speed": 0.0, "grid_size": 4, "use_dominos": false},
	{"min_blocks": 4, "max_blocks": 8, "max_height": 1, "view_time": 4.0, "grid_speed": 0.0, "grid_size": 4, "use_dominos": false},
	# Rounds 3-4: 4x4, slow movement
	{"min_blocks": 5, "max_blocks": 8, "max_height": 1, "view_time": 4.0, "grid_speed": 1.0, "grid_size": 4, "use_dominos": false},
	{"min_blocks": 6, "max_blocks": 8, "max_height": 1, "view_time": 4.0, "grid_speed": 1.5, "grid_size": 4, "use_dominos": false},
	# Rounds 5-6: 5x5 (25 cells, max 12), medium movement
	{"min_blocks": 7, "max_blocks": 12, "max_height": 1, "view_time": 4.0, "grid_speed": 2.0, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 9, "max_blocks": 12, "max_height": 1, "view_time": 4.0, "grid_speed": 2.5, "grid_size": 5, "use_dominos": false},
	# Rounds 7-8: 6x6 (36 cells), fast movement
	{"min_blocks": 8,  "max_blocks": 12, "max_height": 1, "view_time": 4.0, "grid_speed": 3.5, "grid_size": 6, "use_dominos": false},
	{"min_blocks": 10, "max_blocks": 15, "max_height": 1, "view_time": 4.0, "grid_speed": 4.5, "grid_size": 6, "use_dominos": false},
]

const BLOCK_COLOR = Color(0.95, 0.95, 0.95)  # Near-white blocks

static func get_level(round_number: int) -> Dictionary:
	var idx = clampi(round_number - 1, 0, LEVELS.size() - 1)
	return LEVELS[idx]
