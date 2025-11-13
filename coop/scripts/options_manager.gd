extends Node

# Options Manager - Global singleton for managing the options menu

var options_menu_scene = preload("res://coop/scenes/options_menu.tscn")
var options_menu_instance = null

func _ready():
	# Create the options menu instance
	options_menu_instance = options_menu_scene.instantiate()
	
	# Wait for the scene tree to be ready before adding
	await get_tree().process_frame
	
	# Add to the root so it persists across scene changes
	get_tree().root.add_child(options_menu_instance)
	
	# Make sure it's on top of everything
	options_menu_instance.layer = 100

func show_options():
	if options_menu_instance:
		options_menu_instance.show_menu()

func hide_options():
	if options_menu_instance:
		options_menu_instance.hide_menu()

