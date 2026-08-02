class_name HealthBar3D
extends Sprite3D

@onready var health_bar = $SubViewport/HealthBar

var enemy_id: int

func _ready():
	SignalBus.enemy_health_changed.connect(_on_enemy_health_changed)

func _process(_delta):
	# Make the health bar face the camera
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var look_from := global_position
	var look_at_pos := camera.global_position
	if look_from.distance_squared_to(look_at_pos) < 0.0001:
		return
	look_at(look_at_pos, Vector3.UP)

func update_health_bar(current_health: float, max_health: float):
	health_bar.update_health_bar(current_health, max_health)

func _on_enemy_health_changed(id: int, current_health: float, max_health: float):
	if id == enemy_id:
		update_health_bar(current_health, max_health)
