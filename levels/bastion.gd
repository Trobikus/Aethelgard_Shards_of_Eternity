class_name Bastion
extends Node3D

@onready var status_label: Label = $CanvasLayer/BastionHUD/StatusLabel
@onready var stats_label: Label = $CanvasLayer/BastionHUD/StatsLabel
@onready var prompt_label: Label = $CanvasLayer/BastionHUD/PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	var message := RunState.consume_result_message()
	if message.is_empty():
		status_label.text = "Die Bastion — safe haven of the Echo-Smith · I inventory"
	else:
		status_label.text = message
	_refresh_stats()
	SignalBus.interact_prompt_changed.connect(_on_interact_prompt_changed)
	Inventory.equipment_changed.connect(_refresh_stats)
	Inventory.inventory_changed.connect(_refresh_stats)

func _refresh_stats() -> void:
	stats_label.text = "Echos: %d  |  Bosses: %d  |  Falls: %d  |  Bag: %d  |  %+d dmg / %+d HP" % [
		RunState.arenas_cleared,
		RunState.bosses_slain,
		RunState.total_defeats,
		Inventory.bag_count(),
		Inventory.get_bonus_damage(),
		Inventory.get_bonus_max_health(),
	]

func _on_interact_prompt_changed(text: String) -> void:
	if text.is_empty():
		prompt_label.visible = false
		prompt_label.text = ""
	else:
		prompt_label.visible = true
		prompt_label.text = text
