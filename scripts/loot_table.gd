class_name LootTable
extends RefCounted

## Procedural equipment rolls for trash mobs and bosses.

enum Source { TRASH, ELITE, BOSS }

const WEAPON_NAMES: Array[String] = [
	"Shard Blade", "Echo Cleaver", "Resonance Edge", "Nullfang", "Weaver's Spike",
]
const ARMOR_NAMES: Array[String] = [
	"Bastion Mail", "Ashweave Coat", "Rift Plate", "Echo Hide", "Warden Shell",
]
const ACCESSORY_NAMES: Array[String] = [
	"Shard Band", "Echo Charm", "Null Ring", "Weaver's Seal", "Bastion Sigil",
]

static func roll_for_source(source: Source) -> Array[ItemData]:
	var drops: Array[ItemData] = []
	match source:
		Source.TRASH:
			if randf() <= 0.28:
				drops.append(roll_item(_pick_rarity_trash()))
		Source.ELITE:
			if randf() <= 0.65:
				drops.append(roll_item(_pick_rarity_elite()))
		Source.BOSS:
			# Guaranteed weapon or armor + chance at accessory
			drops.append(roll_item(_pick_rarity_boss(), _forced_slot_weapon_or_armor()))
			drops.append(roll_item(_pick_rarity_boss()))
			if randf() <= 0.55:
				drops.append(roll_item(ItemData.Rarity.UNIQUE, ItemData.Slot.ACCESSORY))
	return drops

static func roll_item(rarity: ItemData.Rarity, forced_slot: int = -1) -> ItemData:
	var item := ItemData.new()
	item.rarity = rarity
	if forced_slot >= 0:
		item.slot = forced_slot as ItemData.Slot
	else:
		var slots: Array[ItemData.Slot] = [
			ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.ACCESSORY
		]
		item.slot = slots[randi() % slots.size()]

	item.display_name = _name_for_slot(item.slot)
	item.id = "%s_%s_%d" % [item.slot_label().to_lower(), item.rarity_label().to_lower(), randi()]
	_apply_stats(item)
	item.description = _description_for(item)
	return item

static func _forced_slot_weapon_or_armor() -> ItemData.Slot:
	return ItemData.Slot.WEAPON if randf() < 0.5 else ItemData.Slot.ARMOR

static func _name_for_slot(slot: ItemData.Slot) -> String:
	match slot:
		ItemData.Slot.WEAPON:
			return WEAPON_NAMES[randi() % WEAPON_NAMES.size()]
		ItemData.Slot.ARMOR:
			return ARMOR_NAMES[randi() % ARMOR_NAMES.size()]
		_:
			return ACCESSORY_NAMES[randi() % ACCESSORY_NAMES.size()]

static func _pick_rarity_trash() -> ItemData.Rarity:
	var roll := randf()
	if roll < 0.70:
		return ItemData.Rarity.COMMON
	if roll < 0.95:
		return ItemData.Rarity.MAGIC
	return ItemData.Rarity.RARE

static func _pick_rarity_elite() -> ItemData.Rarity:
	var roll := randf()
	if roll < 0.35:
		return ItemData.Rarity.COMMON
	if roll < 0.75:
		return ItemData.Rarity.MAGIC
	if roll < 0.95:
		return ItemData.Rarity.RARE
	return ItemData.Rarity.UNIQUE

static func _pick_rarity_boss() -> ItemData.Rarity:
	var roll := randf()
	if roll < 0.20:
		return ItemData.Rarity.MAGIC
	if roll < 0.70:
		return ItemData.Rarity.RARE
	return ItemData.Rarity.UNIQUE

static func _apply_stats(item: ItemData) -> void:
	var mult := _rarity_multiplier(item.rarity)
	match item.slot:
		ItemData.Slot.WEAPON:
			item.bonus_damage = int(round(randi_range(3, 8) * mult))
			item.bonus_max_health = int(round(randi_range(0, 5) * mult * 0.5))
			item.bonus_move_speed = 0.0
		ItemData.Slot.ARMOR:
			item.bonus_max_health = int(round(randi_range(15, 35) * mult))
			item.bonus_damage = int(round(randi_range(0, 3) * mult * 0.5))
			item.bonus_move_speed = 0.0
		ItemData.Slot.ACCESSORY:
			item.bonus_move_speed = snappedf(randf_range(0.2, 0.8) * mult, 0.1)
			item.bonus_damage = int(round(randi_range(1, 4) * mult))
			item.bonus_max_health = int(round(randi_range(5, 12) * mult))

static func _rarity_multiplier(rarity: ItemData.Rarity) -> float:
	match rarity:
		ItemData.Rarity.COMMON:
			return 1.0
		ItemData.Rarity.MAGIC:
			return 1.45
		ItemData.Rarity.RARE:
			return 2.0
		ItemData.Rarity.UNIQUE:
			return 2.8
		_:
			return 1.0

static func _description_for(item: ItemData) -> String:
	match item.rarity:
		ItemData.Rarity.UNIQUE:
			return "A unique echo-bound relic forged in the Shard rift."
		ItemData.Rarity.RARE:
			return "Rare gear humming with residual echo power."
		ItemData.Rarity.MAGIC:
			return "Enchanted equipment touched by the Bastion's weave."
		_:
			return "Simple gear recovered from the Echo."
