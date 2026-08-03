@tool
class_name Actor
extends CharacterBody3D

signal health_changed(current_health: float, max_health: float)
signal died

@export var gravity: float = 10.0

@export var max_health: int = 100
var current_health: int

@export var max_stamina: float = 100.0
@export var stamina_regeneration: float = 15.0
var current_stamina: float

var can_regenerate_stamina: bool = true
var is_dead: bool = false

@onready var _mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")

func _ready() -> void:
	if not Engine.is_editor_hint():
		current_health = max_health
		current_stamina = max_stamina
		health_changed.emit(current_health, max_health)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead:
		return
	if can_regenerate_stamina and current_stamina < max_stamina:
		current_stamina += stamina_regeneration * delta
		current_stamina = min(current_stamina, max_stamina)

func take_damage(amount: int) -> void:
	if is_dead or Engine.is_editor_hint():
		return
	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_flash_hit()
	print("%s took %s damage. Health is now %s" % [name, amount, current_health])
	if current_health <= 0:
		_die()

func _flash_hit() -> void:
	if _mesh == null:
		return
	var original := _mesh.get_surface_override_material(0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.1)
	mat.emission_energy_multiplier = 2.0
	_mesh.set_surface_override_material(0, mat)
	get_tree().create_timer(0.08).timeout.connect(
		func() -> void:
			if is_instance_valid(_mesh):
				_mesh.set_surface_override_material(0, original)
	)

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	print("%s has died." % name)
	died.emit()
	if not Engine.is_editor_hint():
		queue_free()
