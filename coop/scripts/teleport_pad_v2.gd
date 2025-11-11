extends Area2D

# Teleport Pad V2 - Uses CanvasLayer for guaranteed visibility

signal teleport_activated(player: Node)

var players_in_range: Array = []
var interaction_hint_visible: bool = false
var hint_canvas: CanvasLayer = null
var interaction_label: Label = null


func _ready() -> void:
	# Add to teleport pads group
	add_to_group("teleport_pads")

	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create interaction hint canvas
	create_interaction_hint()


func create_interaction_hint() -> void:
	# Create a CanvasLayer to display the hint on screen
	hint_canvas = CanvasLayer.new()
	hint_canvas.name = "TeleportHintCanvas"
	hint_canvas.layer = 10  # Above most things
	add_child(hint_canvas)

	# Create a Control to hold the label
	var control = Control.new()
	control.name = "HintControl"
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint_canvas.add_child(control)

	# Create the label
	interaction_label = Label.new()
	interaction_label.text = "Press F to Teleport"
	interaction_label.add_theme_font_size_override("font_size", 24)
	interaction_label.modulate = Color(1, 1, 0, 1)  # Bright yellow

	# Add shadow effect
	interaction_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	interaction_label.add_theme_constant_override("shadow_offset_x", 2)
	interaction_label.add_theme_constant_override("shadow_offset_y", 2)

	control.add_child(interaction_label)

	# Start hidden
	hint_canvas.visible = false

	print("Teleport hint canvas created")


func _process(_delta: float) -> void:
	# Update label position to follow the teleport pad
	if interaction_label and interaction_hint_visible:
		update_label_position()

	# Check for interaction input from players in range
	for player in players_in_range:
		if not is_instance_valid(player):
			players_in_range.erase(player)
			continue

		# Only handle input for local player
		var peer_id = player.name.to_int()
		if peer_id != multiplayer.get_unique_id():
			continue

		# Check if F key is pressed
		if Input.is_action_just_pressed("shop_interact"):  # F key
			print("F key pressed on teleport pad!")
			open_teleport_ui_for_player(player)
			break


func update_label_position() -> void:
	# Convert world position to screen position
	var camera = get_viewport().get_camera_2d()
	if camera and interaction_label:
		var screen_pos = camera.get_screen_center_position() + (global_position - camera.global_position) * camera.zoom
		# Position label above the pad
		interaction_label.global_position = screen_pos + Vector2(-80, -80)


func _on_body_entered(body: Node2D) -> void:
	# Check if a player entered the teleport area
	if body.is_in_group("players"):
		print("Player ", body.name, " entered teleport area")
		if body not in players_in_range:
			players_in_range.append(body)

		# Show interaction hint for local player
		var peer_id = body.name.to_int()
		if peer_id == multiplayer.get_unique_id():
			print("Showing teleport interaction hint for local player")
			show_interaction_hint(true)


func _on_body_exited(body: Node2D) -> void:
	# Check if a player left the teleport area
	if body.is_in_group("players"):
		print("Player ", body.name, " left teleport area")
		if body in players_in_range:
			players_in_range.erase(body)

		# Hide interaction hint for local player
		var peer_id = body.name.to_int()
		if peer_id == multiplayer.get_unique_id():
			print("Hiding teleport interaction hint for local player")
			show_interaction_hint(false)


func show_interaction_hint(visible: bool) -> void:
	if hint_canvas:
		hint_canvas.visible = visible
		print("Teleport hint canvas visibility set to: ", visible)
	else:
		print("ERROR: hint_canvas is null!")

	interaction_hint_visible = visible


func open_teleport_ui_for_player(player: Node) -> void:
	print("Opening teleport UI for player ", player.name)

	# Emit signal
	teleport_activated.emit(player)

	# Load and show teleport UI
	var teleport_ui_scene = load("res://coop/scenes/teleport_ui.tscn")
	if not teleport_ui_scene:
		print("ERROR: Could not load teleport UI scene!")
		return

	# Check if teleport UI is already open
	var existing_teleport = get_tree().root.get_node_or_null("TeleportUI")
	if existing_teleport:
		print("Teleport UI already open, closing it")
		existing_teleport.queue_free()
		return

	var teleport_ui = teleport_ui_scene.instantiate()
	teleport_ui.name = "TeleportUI"

	# Add to root so it's above everything
	get_tree().root.add_child(teleport_ui)

	# Initialize teleport UI with player
	if teleport_ui.has_method("open_teleport_menu"):
		teleport_ui.open_teleport_menu(player)
