class_name CombatArena
extends Node3D

@export var melee_enemy_scene: PackedScene
@export var ranged_enemy_scene: PackedScene
@export var boss_scene: PackedScene
@export var seconds_between_waves: float = 2.5
@export var post_boss_return_delay: float = 12.0
@export var wave_compositions: Array[Dictionary] = [
	{"melee": 2, "ranged": 0},
	{"melee": 2, "ranged": 1},
	{"melee": 3, "ranged": 2},
]

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var spawn_root: Node3D = $SpawnPoints
@onready var enemy_root: Node3D = $Enemies
@onready var status_label: Label = $CanvasLayer/ArenaHUD/StatusLabel
@onready var wave_label: Label = $CanvasLayer/ArenaHUD/WaveLabel

var _wave_index: int = -1
var _alive_enemies: int = 0
var _spawning: bool = false
var _arena_finished: bool = false
var _returning: bool = false
var _boss_active: bool = false

func _ready() -> void:
	randomize()
	_bake_navigation()
	SignalBus.enemy_died.connect(_on_enemy_died)
	SignalBus.boss_phase_changed.connect(_on_boss_phase_changed)
	_update_hud("Prepare...")
	await get_tree().create_timer(1.0).timeout
	_start_next_wave()

func _bake_navigation() -> void:
	# Floor lives under the region; parse static colliders only (no GPU mesh readback).
	if nav_region == null:
		return
	var mesh := nav_region.navigation_mesh
	if mesh:
		mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		mesh.cell_size = 0.25
		mesh.cell_height = 0.25
		mesh.agent_height = 1.5
		mesh.agent_radius = 0.5
		mesh.agent_max_climb = 0.25
	nav_region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("CombatArena: navigation baked")

func _start_next_wave() -> void:
	if _arena_finished or _spawning or _boss_active:
		return

	_wave_index += 1
	if _wave_index >= wave_compositions.size():
		_spawn_boss()
		return

	_spawning = true
	var composition: Dictionary = wave_compositions[_wave_index]
	var melee_count: int = int(composition.get("melee", 0))
	var ranged_count: int = int(composition.get("ranged", 0))
	var total := melee_count + ranged_count

	_update_hud("Wave %d" % (_wave_index + 1))
	wave_label.text = "Wave %d / %d" % [_wave_index + 1, wave_compositions.size()]
	SignalBus.arena_wave_started.emit(_wave_index, total)

	var points := _spawn_point_list()
	points.shuffle()

	var spawn_i := 0
	for i in melee_count:
		_spawn_enemy(melee_enemy_scene, points[spawn_i % points.size()])
		spawn_i += 1
		await get_tree().create_timer(0.15).timeout
	for i in ranged_count:
		_spawn_enemy(ranged_enemy_scene, points[spawn_i % points.size()])
		spawn_i += 1
		await get_tree().create_timer(0.15).timeout

	_spawning = false
	if _alive_enemies <= 0:
		_on_wave_cleared()

func _spawn_boss() -> void:
	if boss_scene == null:
		_finish_arena("ARENA CLEARED — no boss configured")
		return

	_spawning = true
	_boss_active = true
	_update_hud("BOSS — Shard Guardian approaches")
	wave_label.text = "Boss fight"

	var points := _spawn_point_list()
	var marker: Marker3D = points[0] if points.size() > 0 else null
	# Prefer a central-ish spawn: average of spawn points, or first marker.
	var spawn_pos := Vector3(0, 0, -6)
	if marker:
		spawn_pos = marker.global_position
		if points.size() > 1:
			var acc := Vector3.ZERO
			for p in points:
				acc += p.global_position
			spawn_pos = acc / float(points.size())

	await get_tree().create_timer(1.0).timeout
	var boss: Node3D = boss_scene.instantiate()
	enemy_root.add_child(boss)
	boss.global_position = spawn_pos
	_alive_enemies += 1
	_spawning = false
	_update_hud("BOSS PHASE 1 — survive the opening")

func _spawn_enemy(scene: PackedScene, marker: Marker3D) -> void:
	if scene == null or marker == null:
		return
	var enemy: Node3D = scene.instantiate()
	enemy_root.add_child(enemy)
	enemy.global_position = marker.global_position
	_alive_enemies += 1

func _spawn_point_list() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in spawn_root.get_children():
		if child is Marker3D:
			points.append(child)
	if points.is_empty():
		var fallback := Marker3D.new()
		fallback.position = Vector3(0, 0, -6)
		spawn_root.add_child(fallback)
		points.append(fallback)
	return points

func _on_enemy_died(_enemy_id: int) -> void:
	_alive_enemies = maxi(_alive_enemies - 1, 0)
	if _spawning:
		return
	if _alive_enemies > 0 or _arena_finished:
		return
	if _boss_active:
		_on_boss_cleared()
	else:
		_on_wave_cleared()

func _on_wave_cleared() -> void:
	SignalBus.arena_wave_cleared.emit(_wave_index)
	_update_hud("Wave cleared")
	await get_tree().create_timer(seconds_between_waves).timeout
	_start_next_wave()

func _on_boss_cleared() -> void:
	_boss_active = false
	_finish_arena("BOSS DEFEATED — pick up loot · I inventory · E Bastion · R retry")

func _finish_arena(status_text: String) -> void:
	_arena_finished = true
	_update_hud(status_text)
	wave_label.text = "Echo cleared"
	SignalBus.arena_cleared.emit()
	await get_tree().create_timer(post_boss_return_delay).timeout
	_try_return_to_bastion(RunState.Result.VICTORY)

func _on_boss_phase_changed(_boss_id: int, phase: int) -> void:
	if not _boss_active:
		return
	match phase:
		2:
			_update_hud("BOSS PHASE 2 — hybrid assault")
		3:
			_update_hud("BOSS PHASE 3 — ENRAGE")
		_:
			_update_hud("BOSS PHASE %d" % phase)

func _update_hud(text: String) -> void:
	if status_label:
		status_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()
		elif _arena_finished and event.physical_keycode == KEY_E:
			_try_return_to_bastion(RunState.Result.VICTORY)

func _try_return_to_bastion(result: RunState.Result) -> void:
	if _returning or not is_inside_tree():
		return
	_returning = true
	RunState.return_to_bastion(result)
