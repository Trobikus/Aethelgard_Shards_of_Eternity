class_name Bastion
extends Node3D

@onready var status_label: Label = $CanvasLayer/BastionHUD/StatusLabel
@onready var stats_label: Label = $CanvasLayer/BastionHUD/StatsLabel
@onready var prompt_label: Label = $CanvasLayer/BastionHUD/PromptLabel

func _ready() -> void:
	prompt_label.visible = false
	var message := RunState.consume_result_message()
	if message.is_empty():
		status_label.text = "Die Bastion — safe haven of the Echo-Smith"
	else:
		status_label.text = message
	_refresh_stats()
	SignalBus.interact_prompt_changed.connect(_on_interact_prompt_changed)

func _refresh_stats() -> void:
	stats_label.text = "Echos cleared: %d   |   Falls: %d" % [
		RunState.arenas_cleared,
		RunState.total_defeats,
	]

func _on_interact_prompt_changed(text: String) -> void:
	if text.is_empty():
		prompt_label.visible = false
		prompt_label.text = ""
	else:
		prompt_label.visible = true
		prompt_label.text = text
