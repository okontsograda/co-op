extends Control

# UI References
@onready var class_grid = $Panel/MarginContainer/VBoxContainer/ClassGrid
@onready var class_description = $Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var start_button = $Panel/MarginContainer/VBoxContainer/StartButton
@onready var back_button = $Panel/MarginContainer/VBoxContainer/BackButton

var current_selected_class: String = "archer"


func _ready():
	# Set up class selection
	_setup_class_selection()
	
	# Connect buttons
	start_button.pressed.connect(_on_start_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Show initial description
	_update_description()


func _setup_class_selection():
	var classes = PlayerClass.get_all_classes()
	for class_id in classes:
		# Skip mage and tank classes
		if class_id == "mage" or class_id == "tank":
			continue
		
		var class_data = classes[class_id]

		var button = Button.new()
		button.name = "Class_" + class_id
		button.text = class_data["name"]
		button.custom_minimum_size = Vector2(180, 80)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_class_selected.bind(class_id))

		class_grid.add_child(button)

		# Highlight selected class
		if class_id == current_selected_class:
			button.modulate = Color(1.2, 1.2, 1.2)


func _on_class_selected(class_id: String):
	current_selected_class = class_id
	
	# Update button highlights
	for child in class_grid.get_children():
		if child is Button:
			if child.name == "Class_" + class_id:
				child.modulate = Color(1.2, 1.2, 1.2)
			else:
				child.modulate = Color.WHITE
	
	# Update description
	_update_description()


func _update_description():
	var class_data = PlayerClass.get_class_by_name(current_selected_class)
	var desc = class_data["name"] + "\n\n"
	desc += class_data["description"] + "\n\n"
	desc += "Health: " + str(int(class_data["health_modifier"] * 100)) + "%\n"
	desc += "Damage: " + str(int(class_data["damage_modifier"] * 100)) + "%\n"
	desc += "Speed: " + str(int(class_data["speed_modifier"] * 100)) + "%\n"
	desc += "Attack Speed: " + str(int(class_data["attack_speed_modifier"] * 100)) + "%"
	
	class_description.text = desc


func _on_start_button_pressed():
	print("Starting local game with class: ", current_selected_class)
	# Start the local game with selected class
	NetworkHandler.start_local_game_with_class(current_selected_class)


func _on_back_button_pressed():
	# Go back to main menu
	get_tree().change_scene_to_file("res://coop/scenes/main_menu.tscn")

