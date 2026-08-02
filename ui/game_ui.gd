extends Control

@onready var player_health_bar = $PlayerHealthBar
@onready var enemy_health_bar = $EnemyHealthBar

var _targeted_enemy_id: int = -1

func _ready():
	SignalBus.player_health_changed.connect(player_health_bar.update_health_bar)
	SignalBus.enemy_health_changed.connect(_on_enemy_health_changed)
	SignalBus.enemy_targeted.connect(_on_enemy_targeted)

	enemy_health_bar.hide()

func _on_enemy_health_changed(id: int, current_health: float, max_health: float):
	if id == _targeted_enemy_id:
		enemy_health_bar.update_health_bar(current_health, max_health)
		if current_health <= 0:
			enemy_health_bar.hide()
			_targeted_enemy_id = -1 # Clear targeted enemy when it dies

func _on_enemy_targeted(enemy_id: int):
	_targeted_enemy_id = enemy_id
	if enemy_id < 0:
		enemy_health_bar.hide()
	else:
		enemy_health_bar.show()
