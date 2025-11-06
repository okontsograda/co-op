extends Control

# This is an example script showing how to use the SaveSystem
# You can attach this to any Control node to test the save system features

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel


func _ready() -> void:
	# Wait for SaveSystem to load (usually instant, but good practice)
	if not SaveSystem.is_loaded:
		await SaveSystem.data_loaded
	
	# Update the display
	update_display()
	
	# Connect to save system signals (optional)
	SaveSystem.data_saved.connect(_on_data_saved)


func update_display() -> void:
	# Display player name
	var player_name = SaveSystem.get_player_name()
	name_label.text = "Welcome, %s!" % player_name
	
	# Display player statistics
	var stats_text = ""
	stats_text += "Games Played: %d\n" % SaveSystem.get_games_played()
	stats_text += "Total Kills: %d\n" % SaveSystem.get_total_kills()
	stats_text += "Highest Wave: %d\n" % SaveSystem.get_highest_wave()
	stats_text += "Total Coins: %d\n" % SaveSystem.get_total_coins_earned()
	
	var hours = SaveSystem.get_total_playtime() / 3600.0
	stats_text += "Play Time: %.1f hours\n" % hours
	
	stats_label.text = stats_text


func _on_data_saved() -> void:
	print("[Example] Save system saved data")
	update_display()


# Example button handlers (you can connect these to buttons in your UI)

func _on_test_add_kills_pressed() -> void:
	SaveSystem.add_kills(5)
	print("Added 5 kills to player stats")
	update_display()


func _on_test_update_wave_pressed() -> void:
	var current_highest = SaveSystem.get_highest_wave()
	SaveSystem.update_highest_wave(current_highest + 1)
	print("Updated highest wave to: ", current_highest + 1)
	update_display()


func _on_test_add_coins_pressed() -> void:
	SaveSystem.add_coins_earned(100)
	print("Added 100 coins to lifetime earnings")
	update_display()


func _on_test_increment_games_pressed() -> void:
	SaveSystem.increment_games_played()
	print("Incremented games played counter")
	update_display()


func _on_reset_stats_pressed() -> void:
	# Show confirmation dialog before resetting (recommended)
	print("WARNING: Resetting all save data!")
	SaveSystem.reset_save_data()
	update_display()


# Example of tracking playtime during a game session
var session_start_time: float = 0.0

func start_game_session() -> void:
	session_start_time = Time.get_ticks_msec() / 1000.0
	print("Game session started")


func end_game_session() -> void:
	if session_start_time > 0:
		var current_time = Time.get_ticks_msec() / 1000.0
		var session_duration = current_time - session_start_time
		SaveSystem.add_playtime(session_duration)
		print("Game session ended. Duration: %.1f seconds" % session_duration)
		session_start_time = 0.0
		update_display()


# Example of integrating with game over / wave completion
func on_game_over(wave_reached: int, kills_this_game: int, coins_this_game: int) -> void:
	# Update all relevant stats
	SaveSystem.update_highest_wave(wave_reached)
	SaveSystem.add_kills(kills_this_game)
	SaveSystem.add_coins_earned(coins_this_game)
	SaveSystem.increment_games_played()
	
	# Track session playtime
	end_game_session()
	
	print("Game over! Stats updated.")
	print("  Wave: %d" % wave_reached)
	print("  Kills: %d" % kills_this_game)
	print("  Coins: %d" % coins_this_game)


