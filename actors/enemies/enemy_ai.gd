class_name EnemyAI
extends Actor

enum AttackStyle { MELEE, RANGED }

@export var attack_style: AttackStyle = AttackStyle.MELEE
@export var chase_range: float = 18.0
@export var attack_range: float = 2.0
@export var preferred_range: float = 8.0
@export var attack_cooldown: float = 1.1
@export var attack_damage: int = 10
@export var speed: float = 4.5
@export var turn_speed: float = 10.0
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 16.0
@export var loot_source: LootTable.Source = LootTable.Source.TRASH
@export var drop_loot_on_death: bool = true

var _attack_timer: float = 0.0
var player_node: Node3D
var _loot_dropped: bool = false

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_bar: HealthBar3D = get_node_or_null("HealthBar3D")
@onready var projectile_spawn: Marker3D = get_node_or_null("ProjectileSpawn")

func _ready() -> void:
	super._ready()
	add_to_group("enemy")
	if Engine.is_editor_hint():
		return

	health_changed.connect(_on_health_changed)
	died.connect(_on_died)
	if health_bar:
		health_bar.enemy_id = get_instance_id()
	if nav_agent:
		nav_agent.path_desired_distance = 0.6
		nav_agent.target_desired_distance = 0.6
	player_node = get_tree().get_first_node_in_group("player")
	# Stagger first attacks so a wave does not all hit on the same frame
	_attack_timer = randf_range(0.2, attack_cooldown)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead:
		return

	super._physics_process(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
		_idle()
		return

	if player_node is Actor and (player_node as Actor).is_dead:
		_idle()
		return

	_attack_timer = maxf(_attack_timer - delta, 0.0)
	var distance := global_position.distance_to(player_node.global_position)

	if attack_style == AttackStyle.RANGED:
		_ranged_behavior(delta, distance)
	else:
		_melee_behavior(delta, distance)

func _melee_behavior(delta: float, distance: float) -> void:
	if distance <= attack_range:
		_face_target(delta)
		_try_melee_attack()
		_stop_horizontal()
		move_and_slide()
	elif distance <= chase_range:
		_chase_toward(player_node.global_position, delta)
	else:
		_idle()

func _ranged_behavior(delta: float, distance: float) -> void:
	if distance > chase_range:
		_idle()
		return

	_face_target(delta)

	if distance < preferred_range * 0.65:
		# Kite away
		var away := global_position - player_node.global_position
		away.y = 0.0
		if away.length_squared() > 0.001:
			_chase_toward(global_position + away.normalized() * 3.0, delta)
		else:
			_stop_horizontal()
			move_and_slide()
	elif distance > preferred_range * 1.15:
		_chase_toward(player_node.global_position, delta)
	else:
		_stop_horizontal()
		move_and_slide()

	if distance <= preferred_range * 1.35:
		_try_ranged_attack()

func _chase_toward(target: Vector3, delta: float) -> void:
	var direction := Vector3.ZERO

	if nav_agent:
		nav_agent.target_position = target
		var next_nav_point := nav_agent.get_next_path_position()
		direction = next_nav_point - global_position
		direction.y = 0.0

	if direction.length_squared() < 0.0001:
		direction = target - global_position
		direction.y = 0.0

	if direction.length_squared() < 0.0001:
		_stop_horizontal()
		move_and_slide()
		return

	direction = direction.normalized()
	_face_direction(direction, delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

func _try_melee_attack() -> void:
	if _attack_timer > 0.0:
		return
	if player_node.has_method("take_damage"):
		player_node.take_damage(attack_damage)
	_attack_timer = attack_cooldown

func _try_ranged_attack() -> void:
	if _attack_timer > 0.0 or projectile_scene == null:
		return

	var spawn_xf := global_transform
	if projectile_spawn:
		spawn_xf = projectile_spawn.global_transform

	var projectile := projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_transform = spawn_xf
	# Aim at player chest height
	var aim := player_node.global_position + Vector3.UP * 1.2
	projectile.look_at(aim, Vector3.UP)
	if "hits_enemies" in projectile:
		projectile.hits_enemies = false
	if "hits_player" in projectile:
		projectile.hits_player = true
	if "speed" in projectile:
		projectile.speed = projectile_speed
	if "fallback_damage" in projectile:
		projectile.fallback_damage = attack_damage
	# Enemy bolts should collide with the player layer
	if projectile is Area3D:
		(projectile as Area3D).collision_mask = 1

	_attack_timer = attack_cooldown

func _face_target(delta: float) -> void:
	var to_player := player_node.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.001:
		_face_direction(to_player.normalized(), delta)

func _face_direction(direction: Vector3, delta: float) -> void:
	var target_basis := Basis.looking_at(direction, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_basis, clampf(turn_speed * delta, 0.0, 1.0)).orthonormalized()

func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func _idle() -> void:
	_stop_horizontal()
	move_and_slide()

func _on_health_changed(p_current_health: float, p_max_health: float) -> void:
	SignalBus.enemy_health_changed.emit(get_instance_id(), p_current_health, p_max_health)

func _on_died() -> void:
	_drop_loot()
	SignalBus.enemy_died.emit(get_instance_id())

func _drop_loot() -> void:
	if _loot_dropped or not drop_loot_on_death or Engine.is_editor_hint():
		return
	_loot_dropped = true
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	LootSpawner.spawn_drops(parent, global_position, loot_source)
