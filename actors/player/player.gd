@tool
class_name Player
extends Actor

# State Machine
enum State { MOVE, DODGE, SPRINT, ATTACK, RANGED_ATTACK }
var current_state: State = State.MOVE

# Movement variables
@export var speed = 5.0
@export var jump_velocity = 4.5
@export var sprint_speed_multiplier: float = 1.8
@export var sprint_stamina_cost: float = 10.0 # per second

# Dodge variables
@export var dodge_stamina_cost: float = 30.0
@export var dodge_speed: float = 12.0
@export var dodge_duration: float = 0.25

var dodge_timer: float = 0.0
var dodge_direction: Vector3

# Attack variables
@export var base_attack_data: AttackData
@export var max_combo_hits: int = 3 # New variable
@export var ranged_attack_data: AttackData
var attack_timer: float = 0.0
var attack_combo_counter: int = 0
var can_combo: bool = false
var _can_hit: bool = true

# Ranged Attack variables
@export var ranged_attack_cooldown: float = 1.0
var ranged_attack_timer: float = 0.0
var projectile_scene = preload("res://projectiles/magic_missile.tscn")

# Camera control variables
@export var mouse_sensitivity = 0.002
@export var zoom_speed: float = 0.5
@export var min_zoom: float = 1.0
@export var max_zoom: float = 5.0
@onready var camera = $CameraPivot/Camera3D
@onready var camera_pivot = $CameraPivot
@onready var interaction_raycast = $CameraPivot/Camera3D/InteractionRayCast
@onready var melee_hitbox = $MeleeHitbox
@onready var projectile_spawn = $ProjectileSpawn

var _base_max_health: int = 100
var _base_move_speed: float = 5.0

func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		health_changed.connect(_on_health_changed)
		_base_max_health = max_health
		_base_move_speed = speed
		Inventory.equipment_changed.connect(_apply_equipment_bonuses)
		_apply_equipment_bonuses()

	# Exclude the player itself from the raycast
	interaction_raycast.add_exception(self)

	# Connect hitbox signal
	melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)

func _apply_equipment_bonuses() -> void:
	var previous_max := max_health
	max_health = _base_max_health + Inventory.get_bonus_max_health()
	speed = _base_move_speed + Inventory.get_bonus_move_speed()
	if current_health <= 0:
		current_health = max_health
	elif max_health > previous_max:
		current_health += max_health - previous_max
	else:
		current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health)

func _melee_damage() -> int:
	var base := int(base_attack_data.damage) if base_attack_data else 10
	return base + Inventory.get_bonus_damage()

func _ranged_damage_data() -> AttackData:
	if ranged_attack_data == null:
		return null
	var data := ranged_attack_data.duplicate(true) as AttackData
	data.damage = ranged_attack_data.damage + Inventory.get_bonus_damage()
	return data

func _input(event):
	if not Engine.is_editor_hint():
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if event.pressed:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.position.z = clamp(camera.position.z - zoom_speed, min_zoom, max_zoom)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.position.z = clamp(camera.position.z + zoom_speed, min_zoom, max_zoom)

		if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)

		if Input.is_action_just_pressed("tab_target"):
			print("Tab target pressed")
			var closest_enemy = _find_closest_enemy_in_front()
			if closest_enemy:
				_targeted_enemy_instance_id = closest_enemy.get_instance_id()
				SignalBus.enemy_targeted.emit(_targeted_enemy_instance_id)
				print("Targeted enemy: ", closest_enemy.name, " ID: ", _targeted_enemy_instance_id)
			else:
				_targeted_enemy_instance_id = -1
				SignalBus.enemy_targeted.emit(_targeted_enemy_instance_id)
				print("No enemy found")

func _physics_process(delta):
	if not Engine.is_editor_hint():
		# Universal logic (stamina regen) is handled by Actor's _physics_process
		super._physics_process(delta)

		# Apply gravity
		if not is_on_floor():
			velocity.y -= gravity * delta
			
		# Update ranged attack timer
		if ranged_attack_timer > 0:
			ranged_attack_timer -= delta

		# State machine logic
		match current_state:
			State.MOVE:
				_move_state(delta)
			State.DODGE:
				_dodge_state(delta)
			State.SPRINT:
				_sprint_state(delta)
			State.ATTACK:
				_attack_state(delta)
			State.RANGED_ATTACK:
				_ranged_attack_state(delta)
		
		_handle_interaction_check()
		move_and_slide()

# --- Interaction ---
func _handle_interaction_check() -> void:
	interaction_raycast.force_raycast_update()
	var prompt := ""
	if interaction_raycast.is_colliding():
		var collider = interaction_raycast.get_collider()
		if collider != null and collider.is_in_group("interactable"):
			if collider.has_method("get_interact_prompt"):
				prompt = str(collider.get_interact_prompt())
			else:
				prompt = "Interact [E]"
			if Input.is_action_just_pressed("interact") and collider.has_method("interact"):
				collider.interact(self)
	SignalBus.interact_prompt_changed.emit(prompt)

# --- State Functions ---

func _move_state(_delta):
	# --- Get input --- 
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Block combat inputs while inventory is open
	var inventory_open := _is_inventory_open()

	# --- Check for state transitions ---
	# To Attack
	if not inventory_open and Input.is_action_just_pressed("attack"):
		current_state = State.ATTACK
		attack_timer = base_attack_data.duration # Initialize attack timer
		attack_combo_counter = 0 # Reset combo counter
		can_combo = false # Reset can_combo
		_can_hit = true
		return
	# To Sprint
	if not inventory_open and Input.is_action_pressed("sprint") and current_stamina > 0 and input_dir != Vector2.ZERO:
		can_regenerate_stamina = false
		current_state = State.SPRINT
		return
	# To Dodge
	if not inventory_open and Input.is_action_just_pressed("dodge") and current_stamina >= dodge_stamina_cost and is_on_floor():
		can_regenerate_stamina = true # Ensure stamina regens after dodge
		current_state = State.DODGE
		current_stamina -= dodge_stamina_cost
		dodge_timer = dodge_duration
		
		var input_dir_dodge = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir_dodge != Vector2.ZERO:
			dodge_direction = (transform.basis * Vector3(input_dir_dodge.x, 0, input_dir_dodge.y)).normalized()
		else:
			dodge_direction = -transform.basis.z
		return
	# To Ranged Attack
	if not inventory_open and Input.is_action_just_pressed("ranged_attack") and ranged_attack_timer <= 0:
		current_state = State.RANGED_ATTACK
		return

	# --- State logic ---
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func _dodge_state(delta):
	# --- State logic ---
	velocity.x = dodge_direction.x * dodge_speed
	velocity.z = dodge_direction.z * dodge_speed
	
	dodge_timer -= delta

	# --- Check for state transitions ---
	if dodge_timer <= 0:
		current_state = State.MOVE
		velocity = dodge_direction * speed 

func _sprint_state(delta):
	# --- Get input ---
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# --- Check for state transitions ---
	if not Input.is_action_pressed("sprint") or current_stamina <= 0 or input_dir == Vector2.ZERO:
		can_regenerate_stamina = true
		current_state = State.MOVE
		return

	# --- State logic ---
	# Stamina drain
	current_stamina -= sprint_stamina_cost * delta

	# Movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * speed * sprint_speed_multiplier
	velocity.z = direction.z * speed * sprint_speed_multiplier

func _attack_state(delta):
	# Manage attack timer
	attack_timer -= delta

	# Activate hitbox only for the duration of the attack
	if attack_timer > base_attack_data.duration - 0.1: # Activate for first 0.1s of attack
		melee_hitbox.set_deferred("monitoring", true)
		melee_hitbox.set_deferred("monitorable", true)
	else:
		melee_hitbox.set_deferred("monitoring", false)
		melee_hitbox.set_deferred("monitorable", false)

	# Check for combo window
	if attack_timer <= base_attack_data.combo_next_attack_window and attack_timer > 0:
		can_combo = true
	else:
		can_combo = false

	# Check for next combo input during combo window
	if can_combo and Input.is_action_just_pressed("attack"):
		attack_combo_counter += 1
		if attack_combo_counter >= max_combo_hits: # Check if max combo reached
			attack_combo_counter = 0 # Reset for next combo sequence
			current_state = State.MOVE # End combo, return to move state
			attack_timer = 0.0 # Ensure timer is reset
			return

		attack_timer = base_attack_data.duration # Reset timer for next hit
		can_combo = false # Consume combo window
		_can_hit = true # Allow damage on the next combo swing
		print("Combo hit: ", attack_combo_counter)
		return # Stay in attack state for next combo hit

	# Transition back to MOVE if attack duration ends
	if attack_timer <= 0:
		attack_combo_counter = 0 # Reset combo
		current_state = State.MOVE
		attack_timer = 0.0 # Reset for next attack
		return

# --- Hitbox Signal Function ---
func _on_melee_hitbox_body_entered(body):
	if not _can_hit:
		return

	if body is Actor and body != self: # Added 'and body != self'
		body.take_damage(_melee_damage())
		# To prevent multiple hits from one attack, we might disable the hitbox
		# or add a list of already-hit enemies. For now, simple.
		
		# Use set_deferred to avoid "Function blocked during in/out signal" error
		melee_hitbox.set_deferred("monitoring", false)
		melee_hitbox.set_deferred("monitorable", false)
		
		if body.is_in_group("enemy"):
			SignalBus.enemy_targeted.emit(body.get_instance_id())
			
		_can_hit = false
		var timer = get_tree().create_timer(0.1) # Small cooldown
		timer.timeout.connect(func(): _can_hit = true)

# Override death: reload the scene instead of queue_free() then reload
# (calling reload after queue_free is unreliable).
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	print("Player has died. Game Over!")
	if not Engine.is_editor_hint():
		# Arena defeats return to the Bastion hub; other scenes reload.
		if get_tree().current_scene is CombatArena:
			RunState.return_to_bastion(RunState.Result.DEFEAT)
		else:
			get_tree().call_deferred("reload_current_scene")

func _ranged_attack_state(_delta):
	var projectile = projectile_scene.instantiate()
	projectile.attack_data = _ranged_damage_data()
	# Parent to current_scene so scene changes (Bastion <-> Arena) free in-flight missiles.
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(projectile)
	projectile.global_transform = projectile_spawn.global_transform
	ranged_attack_timer = ranged_attack_cooldown
	current_state = State.MOVE

func _on_health_changed(current_health: float, p_max_health: float):
	SignalBus.player_health_changed.emit(current_health, p_max_health)

var _targeted_enemy_instance_id: int = -1

func _find_closest_enemy_in_front() -> Node3D:
	var enemies := get_tree().get_nodes_in_group("enemy")
	var closest_enemy: Node3D = null
	var min_distance := INF
	var player_forward := -global_transform.basis.z

	for enemy in enemies:
		if not (enemy is Node3D) or enemy == self:
			continue
		var enemy_3d := enemy as Node3D
		var to_enemy: Vector3 = (enemy_3d.global_position - global_position).normalized()
		var dot_product: float = player_forward.dot(to_enemy)

		# ~60° forward cone
		if dot_product > 0.5:
			var distance: float = global_position.distance_to(enemy_3d.global_position)
			if distance < min_distance:
				min_distance = distance
				closest_enemy = enemy_3d
	return closest_enemy

func _is_inventory_open() -> bool:
	var ui := get_tree().get_first_node_in_group("inventory_ui")
	return ui != null and ui.has_method("is_open") and ui.is_open()
