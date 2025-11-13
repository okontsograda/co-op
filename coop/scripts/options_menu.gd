extends CanvasLayer

# Options Menu - Handles audio settings and game options

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel

const MUSIC_BUS_INDEX = 1
const SFX_BUS_INDEX = 2

func _ready():
	# Hide the menu initially
	hide()
	
	# Load saved settings
	load_audio_settings()
	
	# Update the UI to match current settings
	update_music_label()
	update_sfx_label()

func _input(event):
	if event.is_action_pressed("options_menu"):
		toggle_menu()
		get_viewport().set_input_as_handled()

func toggle_menu():
	if visible:
		hide_menu()
	else:
		show_menu()

func show_menu():
	visible = true
	get_tree().paused = true

func hide_menu():
	visible = false
	get_tree().paused = false
	save_audio_settings()

func _on_music_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(MUSIC_BUS_INDEX, value)
	update_music_label()

func _on_sfx_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(SFX_BUS_INDEX, value)
	update_sfx_label()

func update_music_label():
	var percentage = db_to_percentage(music_slider.value)
	music_value_label.text = "%d%%" % percentage

func update_sfx_label():
	var percentage = db_to_percentage(sfx_slider.value)
	sfx_value_label.text = "%d%%" % percentage

func db_to_percentage(db_value: float) -> int:
	# Convert from dB range (-40 to 0) to percentage (0 to 100)
	return int((db_value + 40.0) / 40.0 * 100.0)

func _on_resume_button_pressed():
	hide_menu()

func _on_exit_button_pressed():
	# Save settings before exiting
	save_audio_settings()
	get_tree().paused = false
	get_tree().quit()

func save_audio_settings():
	var config = ConfigFile.new()
	
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	
	var error = config.save("user://audio_settings.cfg")
	if error != OK:
		push_error("Failed to save audio settings: " + str(error))

func load_audio_settings():
	var config = ConfigFile.new()
	var error = config.load("user://audio_settings.cfg")
	
	if error == OK:
		var music_volume = config.get_value("audio", "music_volume", 0.0)
		var sfx_volume = config.get_value("audio", "sfx_volume", 0.0)
		
		music_slider.value = music_volume
		sfx_slider.value = sfx_volume
		
		AudioServer.set_bus_volume_db(MUSIC_BUS_INDEX, music_volume)
		AudioServer.set_bus_volume_db(SFX_BUS_INDEX, sfx_volume)
	else:
		# Default settings
		music_slider.value = 0.0
		sfx_slider.value = 0.0

