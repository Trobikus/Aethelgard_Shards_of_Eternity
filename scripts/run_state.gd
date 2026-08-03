extends Node

## Lightweight session state across Bastion <-> Arena scene changes.

enum Result { NONE, VICTORY, DEFEAT }

var last_result: Result = Result.NONE
var arenas_cleared: int = 0
var total_defeats: int = 0
var bosses_slain: int = 0

const BASTION_PATH := "res://levels/bastion.tscn"
const ARENA_PATH := "res://levels/combat_arena.tscn"

func enter_arena() -> void:
	last_result = Result.NONE
	get_tree().change_scene_to_file(ARENA_PATH)

func return_to_bastion(result: Result) -> void:
	last_result = result
	match result:
		Result.VICTORY:
			arenas_cleared += 1
			bosses_slain += 1
		Result.DEFEAT:
			total_defeats += 1
		_:
			pass
	get_tree().change_scene_to_file(BASTION_PATH)

func consume_result_message() -> String:
	match last_result:
		Result.VICTORY:
			last_result = Result.NONE
			var gear := Inventory.equipped_summary()
			return "Echo cleared. Loot secured. %s" % gear
		Result.DEFEAT:
			last_result = Result.NONE
			return "You fell in the Echo. Your gear endures — try again."
		_:
			return ""
