extends Area2D

# Shop Building - Players can interact with this to open the shop UI

signal shop_opened(player: Node)

var players_in_range: Array = []
var interaction_hint_visible: bool = false

@onready var interaction_label: Label = null


func _ready() -> void:
	# Add to shop buildings group
	add_to_group("shop_buildings")
	
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create interaction hint label
	create_interaction_label()


func create_interaction_label() -> void:
	# Create a label to show interaction hint
	interaction_label = Label.new()
	interaction_label.text = "Press F to Shop"
	interaction_label.position = Vector2(-60, -80)  # Position above building
	interaction_label.add_theme_font_size_override("font_size", 16)
	interaction_label.modulate = Color(1, 1, 1, 0.9)
	interaction_label.visible = false
	add_child(interaction_label)


func _process(_delta: float) -> void:
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
			print("F key pressed near shop!")
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

