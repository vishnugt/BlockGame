class_name LevelConfig
extends RefCounted

# grid_speed: units per second the grid moves left-to-right (0 = stationary)
# grid_size: 4 for rounds 1-5, 5 for rounds 6+
# No stacking — max_height always 1
const LEVELS = [
	# Rounds 1-3: 4x4, few blocks, no movement
	{"min_blocks": 3, "max_blocks": 6, "max_height": 1, "view_time": 4.0, "grid_speed": 0.0, "grid_size": 4, "use_dominos": false},
	{"min_blocks": 4, "max_blocks": 7, "max_height": 1, "view_time": 4.0, "grid_speed": 0.0, "grid_size": 4, "use_dominos": false},
	{"min_blocks": 5, "max_blocks": 8, "max_height": 1, "view_time": 4.0, "grid_speed": 0.0, "grid_size": 4, "use_dominos": false},
	# Rounds 4-5: 4x4, more blocks, slow movement
	{"min_blocks": 6, "max_blocks": 10, "max_height": 1, "view_time": 4.0, "grid_speed": 1.0, "grid_size": 4, "use_dominos": false},
	{"min_blocks": 7, "max_blocks": 11, "max_height": 1, "view_time": 4.0, "grid_speed": 1.5, "grid_size": 4, "use_dominos": false},
	# Rounds 6-8: 5x5, more blocks, medium movement
	{"min_blocks": 8, "max_blocks": 13, "max_height": 1, "view_time": 4.0, "grid_speed": 2.0, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 9, "max_blocks": 15, "max_height": 1, "view_time": 4.0, "grid_speed": 2.5, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 10, "max_blocks": 16, "max_height": 1, "view_time": 4.0, "grid_speed": 3.0, "grid_size": 5, "use_dominos": false},
	# Rounds 9-11: 5x5, lots of blocks, fast movement
	{"min_blocks": 12, "max_blocks": 18, "max_height": 1, "view_time": 4.0, "grid_speed": 3.5, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 13, "max_blocks": 19, "max_height": 1, "view_time": 4.0, "grid_speed": 4.0, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 14, "max_blocks": 20, "max_height": 1, "view_time": 4.0, "grid_speed": 4.5, "grid_size": 5, "use_dominos": false},
	# Rounds 12-15: 5x5, packed grid, very fast movement
	{"min_blocks": 15, "max_blocks": 21, "max_height": 1, "view_time": 4.0, "grid_speed": 5.0, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 16, "max_blocks": 22, "max_height": 1, "view_time": 4.0, "grid_speed": 5.5, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 17, "max_blocks": 23, "max_height": 1, "view_time": 4.0, "grid_speed": 6.0, "grid_size": 5, "use_dominos": false},
	{"min_blocks": 18, "max_blocks": 25, "max_height": 1, "view_time": 4.0, "grid_speed": 7.0, "grid_size": 5, "use_dominos": false},
]

const BLOCK_COLOR = Color(0.95, 0.95, 0.95)  # Near-white blocks

static func get_level(round_number: int) -> Dictionary:
	var idx = clampi(round_number - 1, 0, LEVELS.size() - 1)
	return LEVELS[idx]
