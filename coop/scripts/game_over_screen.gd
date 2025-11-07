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
	
	# Reset stats
	if GameStats:
		GameStats.reset_stats()
	
	# If we're in multiplayer and not the server, disconnect and go to main menu
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		# Peer can't restart - send them to main menu
		get_tree().change_scene_to_file("res://coop/scenes/main_menu.tscn")
	else:
		# Host/server can restart the game with current configuration
		NetworkHandler.restart_game_with_current_config()


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
	
	# Reset stats
	if GameStats:
		GameStats.reset_stats()
	
	# Go back to main menu (disconnects from multiplayer)
	get_tree().change_scene_to_file("res://coop/scenes/main_menu.tscn")
