class_name LootPickup
extends StaticBody3D

@export var item: ItemData

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D

var _bob_time: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	_base_y = position.y
	_bob_time = randf() * TAU
	_refresh_visuals()

func setup(p_item: ItemData) -> void:
	item = p_item
	_refresh_visuals()

func sync_bob_base() -> void:
	_base_y = position.y

func _process(delta: float) -> void:
	_bob_time += delta * 2.5
	position.y = _base_y + sin(_bob_time) * 0.12
	rotate_y(delta * 1.4)

func get_interact_prompt() -> String:
	if item == null:
		return "Pick up loot [E]"
	return "Pick up %s [%s] [E]" % [item.display_name, item.rarity_label()]

func interact(_interactor: Node) -> void:
	if item == null:
		queue_free()
		return
	if Inventory.add_item(item):
		SignalBus.loot_picked_up.emit(item.display_name, item.rarity_label())
		queue_free()

func _refresh_visuals() -> void:
	if item == null:
		return
	var color := item.rarity_color()
	if mesh_instance:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4 if item.rarity >= ItemData.Rarity.RARE else 0.6
		mesh_instance.set_surface_override_material(0, mat)
	if label_3d:
		label_3d.text = item.display_name
		label_3d.modulate = color
