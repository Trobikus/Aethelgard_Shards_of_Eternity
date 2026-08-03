extends Node

## Persistent bag + equipment across Bastion <-> Arena scene changes.

signal inventory_changed
signal equipment_changed
signal item_loot_received(item: ItemData)

const MAX_BAG_SIZE := 24

var bag: Array[ItemData] = []
## slot (ItemData.Slot as int) -> ItemData
var equipped: Dictionary = {}

func add_item(item: ItemData, auto_equip_if_empty: bool = true) -> bool:
	if item == null:
		return false
	if bag.size() >= MAX_BAG_SIZE:
		print("Inventory full — could not pick up %s" % item.display_name)
		return false

	var stored := item.duplicate_item()
	bag.append(stored)
	item_loot_received.emit(stored)
	inventory_changed.emit()

	if auto_equip_if_empty and not equipped.has(stored.slot):
		equip_from_bag(bag.size() - 1)
	else:
		print("Looted: %s" % stored.summary_line())
	return true

func equip_from_bag(bag_index: int) -> bool:
	if bag_index < 0 or bag_index >= bag.size():
		return false
	var item: ItemData = bag[bag_index]
	var previous: ItemData = equipped.get(item.slot, null)
	equipped[item.slot] = item
	bag.remove_at(bag_index)
	if previous != null:
		bag.append(previous)
	inventory_changed.emit()
	equipment_changed.emit()
	print("Equipped: %s" % item.summary_line())
	return true

func unequip_slot(slot: ItemData.Slot) -> bool:
	if not equipped.has(slot):
		return false
	if bag.size() >= MAX_BAG_SIZE:
		return false
	var item: ItemData = equipped[slot]
	equipped.erase(slot)
	bag.append(item)
	inventory_changed.emit()
	equipment_changed.emit()
	return true

func get_equipped(slot: ItemData.Slot) -> ItemData:
	return equipped.get(slot, null)

func get_bonus_damage() -> int:
	var total := 0
	for item in equipped.values():
		total += item.bonus_damage
	return total

func get_bonus_max_health() -> int:
	var total := 0
	for item in equipped.values():
		total += item.bonus_max_health
	return total

func get_bonus_move_speed() -> float:
	var total := 0.0
	for item in equipped.values():
		total += item.bonus_move_speed
	return total

func equipped_summary() -> String:
	var lines: PackedStringArray = []
	for slot in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.ACCESSORY]:
		var item: ItemData = get_equipped(slot)
		if item:
			lines.append("%s: %s" % [item.slot_label(), item.display_name])
		else:
			var label := "Weapon" if slot == ItemData.Slot.WEAPON else ("Armor" if slot == ItemData.Slot.ARMOR else "Accessory")
			lines.append("%s: —" % label)
	return "  |  ".join(lines)

func bag_count() -> int:
	return bag.size()
