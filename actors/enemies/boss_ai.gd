class_name BossAI
extends EnemyAI

## Multi-phase arena boss: melee opener, hybrid mid, enrage finale.

enum Phase { OPENING, HYBRID, ENRAGE }

@export var phase2_health_ratio: float = 0.55
@export var phase3_health_ratio: float = 0.25
@export var slam_damage: int = 22
@export var slam_cooldown: float = 3.2
@export var enrage_speed_multiplier: float = 1.35
@export var enrage_cooldown_multiplier: float = 0.65

var current_phase: Phase = Phase.OPENING
var _slam_timer: float = 1.5
var _base_speed: float = 0.0
var _base_cooldown: float = 0.0
var _base_damage: int = 0

func _ready() -> void:
	loot_source = LootTable.Source.BOSS
	drop_loot_on_death = true
	super._ready()
	add_to_group("boss")
	_base_speed = speed
	_base_cooldown = attack_cooldown
	_base_damage = attack_damage
	if not Engine.is_editor_hint():
		SignalBus.boss_spawned.emit(get_instance_id(), max_health)
		SignalBus.enemy_targeted.emit(get_instance_id())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or is_dead:
		return

	_update_phase()
	_slam_timer = maxf(_slam_timer - delta, 0.0)

	# Reuse EnemyAI movement/attacks, then add phase extras.
	super._physics_process(delta)

	if player_node == null or not is_instance_valid(player_node):
		return
	if player_node is Actor and (player_node as Actor).is_dead:
		return

	var distance := global_position.distance_to(player_node.global_position)
	if current_phase == Phase.HYBRID and distance <= preferred_range * 1.2:
		_try_ranged_attack()
	elif current_phase == Phase.ENRAGE and distance <= attack_range * 1.6:
		_try_slam()

func _update_phase() -> void:
	var ratio := float(current_health) / float(maxi(max_health, 1))
	var next_phase := current_phase
	if ratio <= phase3_health_ratio:
		next_phase = Phase.ENRAGE
	elif ratio <= phase2_health_ratio:
		next_phase = Phase.HYBRID
	else:
		next_phase = Phase.OPENING

	if next_phase == current_phase:
		return

	current_phase = next_phase
	match current_phase:
		Phase.OPENING:
			attack_style = AttackStyle.MELEE
			speed = _base_speed
			attack_cooldown = _base_cooldown
			attack_damage = _base_damage
			SignalBus.boss_phase_changed.emit(get_instance_id(), 1)
		Phase.HYBRID:
			attack_style = AttackStyle.MELEE
			speed = _base_speed * 1.1
			attack_cooldown = _base_cooldown * 0.85
			attack_damage = _base_damage + 4
			SignalBus.boss_phase_changed.emit(get_instance_id(), 2)
			print("Boss phase 2 — hybrid assault")
		Phase.ENRAGE:
			attack_style = AttackStyle.MELEE
			speed = _base_speed * enrage_speed_multiplier
			attack_cooldown = _base_cooldown * enrage_cooldown_multiplier
			attack_damage = _base_damage + 8
			SignalBus.boss_phase_changed.emit(get_instance_id(), 3)
			print("Boss phase 3 — enrage")

func _try_slam() -> void:
	if _slam_timer > 0.0:
		return
	if player_node.has_method("take_damage"):
		player_node.take_damage(slam_damage)
	_slam_timer = slam_cooldown
	_flash_hit()

func _on_died() -> void:
	SignalBus.boss_defeated.emit(get_instance_id())
	super._on_died()
