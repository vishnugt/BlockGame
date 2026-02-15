class_name GameGrid
extends Node3D

const BLOCK_SCENE = preload("res://scenes/grid/block.tscn")

var grid_size: int = 4
var grid_data: Array = []
var block_nodes: Array = []
var total_block_count: int = 0

# Grid movement
var grid_speed: float = 0.0
var move_direction: float = 1.0
var start_position: Vector3
var move_range: float = 3.0

# Grid floor and lines
var floor_mesh: MeshInstance3D
var grid_line_nodes: Array = []

func _ready() -> void:
	start_position = position
	floor_mesh = $GridFloor
	_rebuild_grid_visuals()

func _process(delta: float) -> void:
	if grid_speed > 0.0 and visible:
		position.x += grid_speed * move_direction * delta
		if position.x > start_position.x + move_range:
			position.x = start_position.x + move_range
			move_direction = -1.0
		elif position.x < start_position.x - move_range:
			position.x = start_position.x - move_range
			move_direction = 1.0

func _rebuild_grid_visuals() -> void:
	# Clear old grid lines
	for node in grid_line_nodes:
		if is_instance_valid(node):
			node.queue_free()
	grid_line_nodes.clear()

	# Update floor size and position
	var floor_plane = PlaneMesh.new()
	floor_plane.size = Vector2(grid_size, grid_size)
	floor_mesh.mesh = floor_plane
	var center = (grid_size - 1) / 2.0
	floor_mesh.position = Vector3(center, 0, center)

	# Draw grid lines
	var grid_lines = $GridLines
	var line_color = Color(0.4, 0.4, 0.4, 0.8)

	for z in range(grid_size + 1):
		var mesh_instance = MeshInstance3D.new()
		var imm = ImmediateMesh.new()
		imm.surface_begin(Mesh.PRIMITIVE_LINES)
		imm.surface_set_color(line_color)
		imm.surface_add_vertex(Vector3(-0.5, 0.01, z - 0.5))
		imm.surface_set_color(line_color)
		imm.surface_add_vertex(Vector3(grid_size - 0.5, 0.01, z - 0.5))
		imm.surface_end()
		mesh_instance.mesh = imm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = line_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mesh_instance.material_override = mat
		grid_lines.add_child(mesh_instance)
		grid_line_nodes.append(mesh_instance)

	for x in range(grid_size + 1):
		var mesh_instance = MeshInstance3D.new()
		var imm = ImmediateMesh.new()
		imm.surface_begin(Mesh.PRIMITIVE_LINES)
		imm.surface_set_color(line_color)
		imm.surface_add_vertex(Vector3(x - 0.5, 0.01, -0.5))
		imm.surface_set_color(line_color)
		imm.surface_add_vertex(Vector3(x - 0.5, 0.01, grid_size - 0.5))
		imm.surface_end()
		mesh_instance.mesh = imm
		var mat = StandardMaterial3D.new()
		mat.albedo_color = line_color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mesh_instance.material_override = mat
		grid_lines.add_child(mesh_instance)
		grid_line_nodes.append(mesh_instance)

func _clear_grid_data() -> void:
	grid_data = []
	for x in range(grid_size):
		var row = []
		for z in range(grid_size):
			row.append(0)
		grid_data.append(row)

func clear_blocks() -> void:
	for node in block_nodes:
		if is_instance_valid(node):
			node.queue_free()
	block_nodes.clear()
	_clear_grid_data()
	total_block_count = 0

func generate_layout(level: Dictionary) -> int:
	# Update grid size if changed
	var new_size: int = level.get("grid_size", 4)
	if new_size != grid_size:
		grid_size = new_size
		_rebuild_grid_visuals()

	clear_blocks()

	var num_blocks = randi_range(level["min_blocks"], level["max_blocks"])
	var max_height: int = level["max_height"]
	var use_dominos: bool = level["use_dominos"]

	var blocks_placed = 0
	var domino_cells: Dictionary = {}

	if use_dominos:
		var num_dominos = randi_range(1, mini(3, num_blocks / 4))
		for i in range(num_dominos):
			var placed = _try_place_domino(max_height, domino_cells)
			if placed:
				blocks_placed += 1

	var attempts = 0
	while blocks_placed < num_blocks and attempts < 200:
		attempts += 1
		var x = randi_range(0, grid_size - 1)
		var z = randi_range(0, grid_size - 1)

		if grid_data[x][z] >= max_height:
			continue

		var cell_key = "%d_%d" % [x, z]
		if domino_cells.has(cell_key) and grid_data[x][z] > 0:
			continue

		var y = grid_data[x][z]

		var block = BLOCK_SCENE.instantiate()
		add_child(block)
		block.setup(x, z, y, LevelConfig.BLOCK_COLOR)
		block_nodes.append(block)

		grid_data[x][z] = y + 1
		blocks_placed += 1

	total_block_count = blocks_placed
	return blocks_placed

func _try_place_domino(max_height: int, domino_cells: Dictionary) -> bool:
	for _attempt in range(50):
		var x = randi_range(0, grid_size - 1)
		var z = randi_range(0, grid_size - 1)
		var dir = randi_range(0, 1)
		var x2 = x + (1 if dir == 0 else 0)
		var z2 = z + (0 if dir == 0 else 1)

		if x2 >= grid_size or z2 >= grid_size:
			continue
		if grid_data[x][z] >= max_height or grid_data[x2][z2] >= max_height:
			continue
		if grid_data[x][z] != grid_data[x2][z2]:
			continue

		var y = grid_data[x][z]

		var block = BLOCK_SCENE.instantiate()
		add_child(block)
		block.is_domino = true

		var mid_x = (x + x2) / 2.0
		var mid_z = (z + z2) / 2.0
		block.setup(x, z, y, LevelConfig.BLOCK_COLOR)
		block.position = Vector3(mid_x, y * 0.9 + 0.45, mid_z)

		var domino_scale = Vector3(2.0, 1.0, 1.0) if dir == 0 else Vector3(1.0, 1.0, 2.0)
		block.get_node("MeshInstance3D").scale = domino_scale
		block.get_node("OutlineMesh").scale = domino_scale
		block.get_node("XRayMesh").scale = domino_scale

		block_nodes.append(block)

		grid_data[x][z] = y + 1
		grid_data[x2][z2] = y + 1
		domino_cells["%d_%d" % [x, z]] = true
		domino_cells["%d_%d" % [x2, z2]] = true

		return true

	return false

func set_grid_speed(speed: float) -> void:
	grid_speed = speed
	move_direction = 1.0

func stop_movement() -> void:
	grid_speed = 0.0
	position = start_position

func show_grid() -> void:
	visible = true

func hide_grid() -> void:
	visible = false
	stop_movement()
