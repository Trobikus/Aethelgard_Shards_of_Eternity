extends Control

@onready var player_health_bar = $PlayerHealthBar
@onready var enemy_health_bar = $EnemyHealthBar
@onready var loot_toast: Label = $LootToast
@onready var inventory_ui = $InventoryUI

var _targeted_enemy_id: int = -1
var _toast_timer: float = 0.0

func _ready():
	SignalBus.player_health_changed.connect(player_health_bar.update_health_bar)
	SignalBus.enemy_health_changed.connect(_on_enemy_health_changed)
	SignalBus.enemy_targeted.connect(_on_enemy_targeted)
	SignalBus.loot_picked_up.connect(_on_loot_picked_up)
	SignalBus.boss_spawned.connect(_on_boss_spawned)

	enemy_health_bar.hide()
	if loot_toast:
		loot_toast.visible = false

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and loot_toast:
			loot_toast.visible = false

func _on_enemy_health_changed(id: int, current_health: float, max_health: float):
	if id == _targeted_enemy_id:
		enemy_health_bar.update_health_bar(current_health, max_health)
		if current_health <= 0:
			enemy_health_bar.hide()
			_targeted_enemy_id = -1

func _on_enemy_targeted(enemy_id: int):
	_targeted_enemy_id = enemy_id
	if enemy_id < 0:
		enemy_health_bar.hide()
	else:
		enemy_health_bar.show()

func _on_boss_spawned(boss_id: int, max_health: float) -> void:
	_targeted_enemy_id = boss_id
	enemy_health_bar.show()
	enemy_health_bar.update_health_bar(max_health, max_health)

func _on_loot_picked_up(item_name: String, rarity: String) -> void:
	if loot_toast == null:
		return
	loot_toast.text = "Looted %s (%s)" % [item_name, rarity]
	loot_toast.visible = true
	_toast_timer = 2.5
