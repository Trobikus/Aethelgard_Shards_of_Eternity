extends SceneTree

## Headless smoke test: loot rolls, inventory equip, bonuses.
## Run: godot --headless --path . --script res://scripts/loot_smoke_test.gd

func _initialize() -> void:
	var failures := 0
	randomize()

	var trash := LootTable.roll_for_source(LootTable.Source.TRASH)
	var boss := LootTable.roll_for_source(LootTable.Source.BOSS)
	print("Trash drops: %d" % trash.size())
	print("Boss drops: %d" % boss.size())
	if boss.size() < 2:
		push_error("Boss should drop at least 2 items")
		failures += 1

	# Inventory autoload may not exist when running --script alone; simulate.
	var inv_script := load("res://scripts/inventory.gd")
	var inv = inv_script.new()
	root.add_child(inv)

	var weapon := LootTable.roll_item(ItemData.Rarity.RARE, ItemData.Slot.WEAPON)
	if not inv.add_item(weapon):
		push_error("Failed to add weapon")
		failures += 1
	if inv.get_bonus_damage() <= 0 and weapon.bonus_damage > 0:
		# auto-equip empty slot should apply
		pass
	if inv.get_equipped(ItemData.Slot.WEAPON) == null:
		push_error("Weapon should auto-equip into empty slot")
		failures += 1

	var armor := LootTable.roll_item(ItemData.Rarity.MAGIC, ItemData.Slot.ARMOR)
	inv.add_item(armor)
	if inv.get_bonus_max_health() < armor.bonus_max_health:
		push_error("Armor HP bonus missing after equip")
		failures += 1

	print("Equipped: %s" % inv.equipped_summary())
	print("Bonuses dmg=%d hp=%d spd=%.1f" % [
		inv.get_bonus_damage(), inv.get_bonus_max_health(), inv.get_bonus_move_speed()
	])

	if failures == 0:
		print("loot_smoke_test: OK")
		quit(0)
	else:
		print("loot_smoke_test: FAILED (%d)" % failures)
		quit(1)
