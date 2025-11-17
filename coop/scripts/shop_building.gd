extends Node2D

# Shop Building - Players can interact with this to open the shop UI
# In hub mode, this just shows visual feedback (actual interaction handled by hub_scene.gd)

signal shop_opened(player: Node)

var players_in_range: Array = []
var interaction_hint_visible: bool = false
var is_in_hub: bool = false

@onready var interaction_label: Label = null
@onready var sprite: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D


func _ready() -> void:
	# Check if we're in the hub scene
	is_in_hub = _check_if_in_hub()

	# Add to shop buildings group
	add_to_group("shop_buildings")

	# Connect area signals
	if area_2d:
		area_2d.body_entered.connect(_on_body_entered)
		area_2d.body_exited.connect(_on_body_exited)

	# Create interaction hint label
	create_interaction_label()

	# Set initial sprite shader for outline effect
	setup_outline_shader()


func _check_if_in_hub() -> bool:
	# Check if this building is part of the hub scene
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("_connect_interaction_zones"):
		return true
	# Also check parent nodes for hub_scene script
	var parent = get_parent()
	while parent:
		if parent.has_method("_connect_interaction_zones"):
			return true
		parent = parent.get_parent()
	return false


func setup_outline_shader() -> void:
	# Create shader material for highlight/glow effect
	var shader_code = """
shader_type canvas_item;

uniform bool show_outline = false;
uniform vec4 highlight_color : source_color = vec4(1.5, 1.5, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 2.0) = 0.3;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (show_outline && color.a > 0.1) {
		// Make the sprite brighter/glow when highlighted
		COLOR = vec4(
			min(color.r + glow_strength, 1.0),
			min(color.g + glow_strength, 1.0),
			min(color.b + glow_strength * 0.5, 1.0),
			color.a
		);
		// Also apply a color tint
		COLOR.rgb = mix(COLOR.rgb, highlight_color.rgb, 0.2);
	} else {
		COLOR = color;
	}
}
"""

	var shader = Shader.new()
	shader.code = shader_code

	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("show_outline", false)
	material.set_shader_parameter("highlight_color", Color(1.5, 1.5, 1.0, 1.0))
	material.set_shader_parameter("glow_strength", 0.3)
	
	if sprite:
		sprite.material = material


func create_interaction_label() -> void:
	# Create a label to show interaction hint
	interaction_label = Label.new()
	# Different text based on whether we're in hub or mission
	if is_in_hub:
		interaction_label.text = "Press E to open"
	else:
		interaction_label.text = "Press E to open shop"
	interaction_label.position = Vector2(-60, -80)  # Position above building
	interaction_label.add_theme_font_size_override("font_size", 16)
	interaction_label.modulate = Color(1, 1, 1, 0.9)
	interaction_label.visible = false
	interaction_label.z_index = 100  # Ensure label renders on top of sprite
	add_child(interaction_label)


func _process(_delta: float) -> void:
	# Update z_index every frame based on Y position for proper sorting with moving objects
	# Use the base of the building (the Node2D root position) for sorting
	z_index = int(global_position.y)
	
	# Check for interaction input from players in range (only in mission mode)
	if not is_in_hub:
		for player in players_in_range:
			if not is_instance_valid(player):
				players_in_range.erase(player)
				continue

			# Only handle input for local player
			var peer_id = player.name.to_int()
			if peer_id != multiplayer.get_unique_id():
				continue

			# Check if E key is pressed
			if Input.is_action_just_pressed("ui_accept"):  # E key
				print("E key pressed near shop!")
				open_shop_for_player(player)
				break


func _on_body_entered(body: Node2D) -> void:
	# Check if a player entered the shop area
	if body.is_in_group("players"):
		print("Player ", body.name, " entered shop area")
		if body not in players_in_range:
			players_in_range.append(body)
		
		# Show interaction hint for local player
		var peer_id = body.name.to_int()
		if peer_id == multiplayer.get_unique_id():
			print("Showing shop interaction hint for local player")
			show_interaction_hint(true)


func _on_body_exited(body: Node2D) -> void:
	# Check if a player left the shop area
	if body.is_in_group("players"):
		print("Player ", body.name, " left shop area")
		if body in players_in_range:
			players_in_range.erase(body)
		
		# Hide interaction hint for local player
		var peer_id = body.name.to_int()
		if peer_id == multiplayer.get_unique_id():
			print("Hiding shop interaction hint for local player")
			show_interaction_hint(false)


func show_interaction_hint(visible: bool) -> void:
	if interaction_label:
		interaction_label.visible = visible
	
	# Show/hide white outline
	if sprite and sprite.material:
		sprite.material.set_shader_parameter("show_outline", visible)
	
	interaction_hint_visible = visible


func open_shop_for_player(player: Node) -> void:
	print("Opening shop for player ", player.name)
	
	# Emit signal
	shop_opened.emit(player)
	
	# Load and show shop UI
	var shop_ui_scene = load("res://coop/scenes/shop_ui.tscn")
	if not shop_ui_scene:
		print("ERROR: Could not load shop UI scene!")
		return
	
	# Check if shop UI is already open
	var existing_shop = get_tree().root.get_node_or_null("ShopUI")
	if existing_shop:
		print("Shop UI already open, closing it")
		existing_shop.queue_free()
		return
	
	var shop_ui = shop_ui_scene.instantiate()
	shop_ui.name = "ShopUI"
	
	# Add to root so it's above everything
	get_tree().root.add_child(shop_ui)
	
	# Initialize shop UI with player
	if shop_ui.has_method("open_shop"):
		shop_ui.open_shop(player)
