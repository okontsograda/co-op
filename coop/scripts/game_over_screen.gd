extends CanvasLayer

@onready var enemies_killed_label = $Control/Panel/MarginContainer/VBoxContainer/StatsContainer/EnemiesKilledLabel
@onready var coins_collected_label = $Control/Panel/MarginContainer/VBoxContainer/StatsContainer/CoinsCollectedLabel
@onready var wave_reached_label = $Control/Panel/MarginContainer/VBoxContainer/StatsContainer/WaveReachedLabel
@onready var time_survived_label = $Control/Panel/MarginContainer/VBoxContainer/StatsContainer/TimeSurvivedLabel
@onready var damage_dealt_label = $Control/Panel/MarginContainer/VBoxContainer/StatsContainer/DamageDealtLabel
@onready var bosses_killed_label = $Control/Panel/MarginContainer/VBoxContainer/StatsContainer/BossesKilledLabel
@onready var restart_button = $Control/Panel/MarginContainer/VBoxContainer/ButtonContainer/RestartButton
@onready var main_menu_button = $Control/Panel/MarginContainer/VBoxContainer/ButtonContainer/MainMenuButton


func _ready() -> void:
	# Connect buttons
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Display stats
	display_stats()
	
	# DON'T pause the game - let other players continue
	# get_tree().paused = true  # Removed - game continues for alive players


func display_stats() -> void:
	if GameStats:
		GameStats.finalize_stats()
		
		enemies_killed_label.text = "⚔️ Enemies Defeated: " + str(GameStats.total_enemies_killed)
		coins_collected_label.text = "💰 Coins Collected: " + str(GameStats.total_coins_collected)
		wave_reached_label.text = "🌊 Wave Reached: " + str(GameStats.highest_wave_reached)
		time_survived_label.text = "⏱️ Time Survived: " + GameStats.get_time_survived_formatted()
		damage_dealt_label.text = "💥 Total Damage Dealt: " + str(GameStats.total_damage_dealt)
		bosses_killed_label.text = "👹 Bosses Defeated: " + str(GameStats.bosses_killed)


func _on_restart_pressed() -> void:
	# Remove all game over screens from root before restarting
	_remove_all_game_over_screens()

	# Award meta currency and return to hub
	var wave = GameStats.highest_wave_reached if GameStats else 0
	var kills = GameStats.total_enemies_killed if GameStats else 0

	# Reset stats
	if GameStats:
		GameStats.reset_stats()

	# Return to hub with rewards
	NetworkHandler.return_to_hub_after_game(wave, kills)


func _remove_all_game_over_screens() -> void:
	# Remove all game over screens from the root (they persist across scene reloads)
	var root = get_tree().root
	for child in root.get_children():
		if child is CanvasLayer and child.name == "GameOverScreen":
			child.queue_free()
	# Also remove this instance
	queue_free()


func _on_main_menu_pressed() -> void:
	# Remove all game over screens from root
	_remove_all_game_over_screens()

	# Award meta currency and return to hub
	var wave = GameStats.highest_wave_reached if GameStats else 0
	var kills = GameStats.total_enemies_killed if GameStats else 0

	# Reset stats
	if GameStats:
		GameStats.reset_stats()

	# Return to hub with rewards
	NetworkHandler.return_to_hub_after_game(wave, kills)
