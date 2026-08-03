class_name LootSpawner
extends RefCounted

const PICKUP_SCENE := preload("res://items/loot_pickup.tscn")

static func spawn_drops(parent: Node, world_position: Vector3, source: LootTable.Source) -> Array[ItemData]:
	var items := LootTable.roll_for_source(source)
	if items.is_empty() or parent == null:
		return items

	var count := items.size()
	for i in count:
		var item: ItemData = items[i]
		var pickup: Node3D = PICKUP_SCENE.instantiate()
		if pickup.has_method("setup"):
			pickup.setup(item)
		parent.add_child(pickup)
		var angle := TAU * float(i) / float(maxi(count, 1))
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * (0.6 + 0.25 * float(i))
		pickup.global_position = world_position + offset + Vector3.UP * 0.4
		if pickup.has_method("sync_bob_base"):
			pickup.sync_bob_base()
	return items
