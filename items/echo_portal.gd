class_name EchoPortal
extends StaticBody3D

@export var prompt_text: String = "Enter Echo [E]"
@export_file("*.tscn") var target_scene: String = "res://levels/combat_arena.tscn"
@export var use_run_state: bool = true

func _ready() -> void:
	add_to_group("interactable")

func get_interact_prompt() -> String:
	return prompt_text

func interact(_interactor: Node) -> void:
	if use_run_state and target_scene == RunState.ARENA_PATH:
		RunState.enter_arena()
		return
	if target_scene.is_empty():
		return
	get_tree().change_scene_to_file(target_scene)
