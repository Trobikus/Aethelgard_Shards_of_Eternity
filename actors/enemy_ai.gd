extends Actor

@export var chase_range: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.0
@export var attack_damage: int = 10
@export var speed: float = 5.0

var _attack_timer: float = 0.0
var player_node: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health_bar: HealthBar3D = get_node_or_null("HealthBar3D")

func _ready():
	super._ready()
	if not Engine.is_editor_hint():
		health_changed.connect(_on_health_changed)
		if health_bar:
			health_bar.enemy_id = get_instance_id()
		player_node = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if Engine.is_editor_hint():
		return

	super._physics_process(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
		_idle(delta)
		return

	var distance_to_player = global_position.distance_to(player_node.global_position)

	if distance_to_player <= attack_range:
		_attack_player(delta)
	elif distance_to_player <= chase_range:
		_chase_player(delta)
	else:
		_idle(delta)

func _chase_player(_delta):
	var direction := Vector3.ZERO

	if nav_agent:
		nav_agent.target_position = player_node.global_position
		var next_nav_point = nav_agent.get_next_path_position()
		direction = next_nav_point - global_position
		direction.y = 0.0

	# Empty/unbaked nav meshes return the current position — fall back to direct chase.
	if direction.length_squared() < 0.0001:
		direction = player_node.global_position - global_position
		direction.y = 0.0

	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

func _attack_player(delta):
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		if player_node.has_method("take_damage"):
			player_node.take_damage(attack_damage)
		_attack_timer = attack_cooldown
	move_and_slide()

func _idle(_delta):
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

func _on_health_changed(p_current_health: float, p_max_health: float):
	SignalBus.enemy_health_changed.emit(get_instance_id(), p_current_health, p_max_health)
