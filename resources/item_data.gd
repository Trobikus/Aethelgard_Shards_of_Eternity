class_name ItemData
extends Resource

enum Slot { WEAPON, ARMOR, ACCESSORY }
enum Rarity { COMMON, MAGIC, RARE, UNIQUE }

@export var id: String = ""
@export var display_name: String = "Unknown Relic"
@export var description: String = ""
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var bonus_damage: int = 0
@export var bonus_max_health: int = 0
@export var bonus_move_speed: float = 0.0

func rarity_label() -> String:
	match rarity:
		Rarity.COMMON:
			return "Common"
		Rarity.MAGIC:
			return "Magic"
		Rarity.RARE:
			return "Rare"
		Rarity.UNIQUE:
			return "Unique"
		_:
			return "Unknown"

func rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:
			return Color(0.78, 0.78, 0.78)
		Rarity.MAGIC:
			return Color(0.35, 0.55, 1.0)
		Rarity.RARE:
			return Color(1.0, 0.82, 0.25)
		Rarity.UNIQUE:
			return Color(0.95, 0.45, 0.15)
		_:
			return Color.WHITE

func slot_label() -> String:
	match slot:
		Slot.WEAPON:
			return "Weapon"
		Slot.ARMOR:
			return "Armor"
		Slot.ACCESSORY:
			return "Accessory"
		_:
			return "Item"

func summary_line() -> String:
	var bits: PackedStringArray = []
	if bonus_damage != 0:
		bits.append("%+d dmg" % bonus_damage)
	if bonus_max_health != 0:
		bits.append("%+d HP" % bonus_max_health)
	if not is_zero_approx(bonus_move_speed):
		bits.append("%+.1f spd" % bonus_move_speed)
	var stats := ", ".join(bits) if bits.size() > 0 else "no bonuses"
	return "[%s] %s (%s) — %s" % [rarity_label(), display_name, slot_label(), stats]

func duplicate_item() -> ItemData:
	var copy := ItemData.new()
	copy.id = id
	copy.display_name = display_name
	copy.description = description
	copy.slot = slot
	copy.rarity = rarity
	copy.bonus_damage = bonus_damage
	copy.bonus_max_health = bonus_max_health
	copy.bonus_move_speed = bonus_move_speed
	return copy
