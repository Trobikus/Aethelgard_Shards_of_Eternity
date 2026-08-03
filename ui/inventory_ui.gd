extends Control

## Toggle with I — equip bag loot into Weapon / Armor / Accessory slots.

@onready var panel: PanelContainer = $Panel
@onready var equipped_label: RichTextLabel = $Panel/Margin/VBox/EquippedLabel
@onready var bag_list: ItemList = $Panel/Margin/VBox/BagList
@onready var detail_label: Label = $Panel/Margin/VBox/DetailLabel
@onready var hint_label: Label = $Panel/Margin/VBox/HintLabel

var _open: bool = false

func _ready() -> void:
	add_to_group("inventory_ui")
	visible = true
	panel.visible = false
	bag_list.item_selected.connect(_on_bag_item_selected)
	bag_list.item_activated.connect(_on_bag_item_activated)
	Inventory.inventory_changed.connect(_refresh)
	Inventory.equipment_changed.connect(_refresh)
	_refresh()

func is_open() -> bool:
	return _open

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_open = not _open
	panel.visible = _open
	if _open:
		_refresh()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _refresh() -> void:
	equipped_label.clear()
	equipped_label.append_text("[b]Equipment[/b]\n")
	for slot in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.ACCESSORY]:
		var item: ItemData = Inventory.get_equipped(slot)
		if item:
			equipped_label.append_text(
				"%s: [color=#%s]%s[/color] — %+d dmg, %+d HP, %+.1f spd\n" % [
					item.slot_label(),
					item.rarity_color().to_html(false),
					item.display_name,
					item.bonus_damage,
					item.bonus_max_health,
					item.bonus_move_speed,
				]
			)
		else:
			var label := "Weapon" if slot == ItemData.Slot.WEAPON else ("Armor" if slot == ItemData.Slot.ARMOR else "Accessory")
			equipped_label.append_text("%s: —\n" % label)

	equipped_label.append_text(
		"\nBonuses: %+d dmg · %+d HP · %+.1f spd" % [
			Inventory.get_bonus_damage(),
			Inventory.get_bonus_max_health(),
			Inventory.get_bonus_move_speed(),
		]
	)

	bag_list.clear()
	for item in Inventory.bag:
		bag_list.add_item("%s [%s] %s" % [item.rarity_label(), item.slot_label(), item.display_name])
		bag_list.set_item_custom_fg_color(bag_list.item_count - 1, item.rarity_color())

	detail_label.text = "Bag: %d / %d — double-click or Enter to equip" % [
		Inventory.bag_count(),
		Inventory.MAX_BAG_SIZE,
	]
	hint_label.text = "I close · Equipped gear persists across Echo runs"

func _on_bag_item_selected(index: int) -> void:
	if index < 0 or index >= Inventory.bag.size():
		return
	var item: ItemData = Inventory.bag[index]
	detail_label.text = item.summary_line()

func _on_bag_item_activated(index: int) -> void:
	Inventory.equip_from_bag(index)
