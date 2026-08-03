extends Node

# Player signals
signal player_health_changed(current_health: float, max_health: float)

# Enemy signals
signal enemy_health_changed(enemy_id: int, current_health: float, max_health: float)
signal enemy_targeted(enemy_id: int)
signal enemy_died(enemy_id: int)

# Boss signals
signal boss_spawned(boss_id: int, max_health: float)
signal boss_phase_changed(boss_id: int, phase: int)
signal boss_defeated(boss_id: int)

# Arena / encounter signals
signal arena_wave_started(wave_index: int, enemy_count: int)
signal arena_wave_cleared(wave_index: int)
signal arena_cleared()

# Loot / inventory
signal loot_picked_up(item_name: String, rarity: String)

# Interaction UI
signal interact_prompt_changed(prompt_text: String)
signal inventory_ui_toggle_requested()
