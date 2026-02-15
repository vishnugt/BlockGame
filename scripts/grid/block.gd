class_name Block
extends Node3D

var grid_x: int = 0
var grid_z: int = 0
var stack_y: int = 0
var is_domino: bool = false

const CEL_SHADER = preload("res://assets/shaders/cel_shade.gdshader")
const OUTLINE_SHADER = preload("res://assets/shaders/outline.gdshader")
const XRAY_SHADER = preload("res://assets/shaders/xray_outline.gdshader")

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var outline_mesh: MeshInstance3D = $OutlineMesh
@onready var xray_mesh: MeshInstance3D = $XRayMesh

func setup(x: int, z: int, y: int, color: Color) -> void:
	grid_x = x
	grid_z = z
	stack_y = y
	position = Vector3(x, y * 0.9 + 0.45, z)

	# Cel-shaded main material
	var cel_mat = ShaderMaterial.new()
	cel_mat.shader = CEL_SHADER
	cel_mat.set_shader_parameter("base_color", color)
	var shade = color * 0.65
	shade.a = 1.0
	cel_mat.set_shader_parameter("shade_color", shade)
	mesh_instance.material_override = cel_mat

	# Outline pass
	var outline_mat = ShaderMaterial.new()
	outline_mat.shader = OUTLINE_SHADER
	outline_mesh.material_override = outline_mat

	# X-ray outline (visible through other blocks)
	var xray_mat = ShaderMaterial.new()
	xray_mat.shader = XRAY_SHADER
	xray_mat.render_priority = 1
	xray_mesh.material_override = xray_mat
