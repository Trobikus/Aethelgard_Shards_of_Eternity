extends Area3D

@export var attack_data: AttackData
@export var speed: float = 20.0
@export var lifetime: float = 3.0
@export var hits_enemies: bool = true
@export var hits_player: bool = false
## Optional override when attack_data is null
@export var fallback_damage: int = 10

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta

func _damage_amount() -> int:
	if attack_data != null:
		return int(attack_data.damage)
	return fallback_damage

func _on_body_entered(body: Node) -> void:
	if hits_enemies and body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(_damage_amount())
		SignalBus.enemy_targeted.emit(body.get_instance_id())
		queue_free()
		return

	if hits_player and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(_damage_amount())
		queue_free()
		return

	# Walls / floor / other blockers
	if body is StaticBody3D or (not body is CharacterBody3D and not body is Area3D):
		queue_free()
