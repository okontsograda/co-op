extends CanvasLayer

# Shop UI - Displays shop items and handles purchases

var current_player: Node = null
var current_category: String = "weapon"
var selected_item: ShopManager.ShopItem = null

# UI References
@onready var panel: Panel = $Panel
@onready var close_button: Button = $Panel/CloseButton
@onready var category_container: HBoxContainer = $Panel/CategoryContainer
@onready var items_container: VBoxContainer = $Panel/ScrollContainer/ItemsContainer
@onready var item_details_panel: Panel = $Panel/ItemDetailsPanel
@onready var item_name_label: Label = $Panel/ItemDetailsPanel/ItemNameLabel
@onready var item_desc_label: Label = $Panel/ItemDetailsPanel/ItemDescLabel
@onready var item_cost_label: Label = $Panel/ItemDetailsPanel/ItemCostLabel
@onready var item_owned_label: Label = $Panel/ItemDetailsPanel/ItemOwnedLabel
@onready var purchase_button: Button = $Panel/ItemDetailsPanel/PurchaseButton
@onready var player_coins_label: Label = $Panel/PlayerCoinsLabel


func _ready() -> void:
	# Hide by default
	visible = false
	
	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connect purchase button
	if purchase_button:
		purchase_button.pressed.connect(_on_purchase_pressed)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Close shop with ESC
	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


func open_shop(player: Node) -> void:
	current_player = player
	visible = true
	
	# Pause game input while shop is open (but don't pause the game itself)
	get_tree().paused = false
	
	# Update player coins display
	update_player_coins()
	
	# Setup category buttons
	setup_categories()
	
	# Load first category
	load_category(current_category)


func close_shop() -> void:
	visible = false
	current_player = null
	selected_item = null
	queue_free()


func _on_close_pressed() -> void:
	close_shop()


func setup_categories() -> void:
	if not category_container:
		return
	
	# Clear existing category buttons
	for child in category_container.get_children():
		child.queue_free()
	
	# Create category buttons
	var categories = ["weapon", "armor", "upgrade", "consumable"]
	for category in categories:
		var button = Button.new()
		button.text = category.capitalize()
		button.custom_minimum_size = Vector2(100, 40)
		
		# Style the button based on if it's selected
		if category == current_category:
			button.modulate = Color(1, 1, 0.5)
		
		button.pressed.connect(func(): _on_category_selected(category))
		category_container.add_child(button)


func _on_category_selected(category: String) -> void:
	current_category = category
	setup_categories()  # Refresh to update selected state
	load_category(category)


func load_category(category: String) -> void:
	if not items_container:
		return
	
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()
	
	# Get player's weapon type for filtering
	var player_weapon = "bow"  # Default
	if current_player and "equipped_weapon" in current_player:
		player_weapon = current_player.equipped_weapon
	
	# Get items in this category filtered by weapon
	var items = ShopManager.get_items_by_category_and_weapon(category, player_weapon)
	
	if items.is_empty():
		var label = Label.new()
		label.text = "No items available in this category for your class"
		items_container.add_child(label)
		return
	
	# Sort items by cost
	items.sort_custom(func(a, b): return a.cost < b.cost)
	
	# Create item buttons
	for item in items:
		create_item_button(item)


func create_item_button(item: ShopManager.ShopItem) -> void:
	# Create a container for each item
	var item_button = Button.new()
	item_button.custom_minimum_size = Vector2(400, 50)
	item_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Check if player owns this item
	var purchase_count = ShopManager.get_purchase_count(str(current_player.name), item.id)
	var max_reached = ShopManager.has_max_purchases(str(current_player.name), item.id)
	
	# Build button text
	var button_text = item.name + " - " + str(item.cost) + " coins"
	
	if max_reached:
		button_text += " [MAXED]"
		item_button.modulate = Color(0.5, 0.5, 0.5)
	elif purchase_count > 0:
		button_text += " [Owned: " + str(purchase_count) + "]"
		item_button.modulate = Color(0.7, 1.0, 0.7)
	
	item_button.text = button_text
	item_button.pressed.connect(func(): _on_item_selected(item))
	
	items_container.add_child(item_button)


func _on_item_selected(item: ShopManager.ShopItem) -> void:
	selected_item = item
	update_item_details()


func update_item_details() -> void:
	if not selected_item or not item_details_panel:
		return
	
	# Update item details
	if item_name_label:
		item_name_label.text = selected_item.name
	
	if item_desc_label:
		item_desc_label.text = selected_item.description
	
	if item_cost_label:
		item_cost_label.text = "Cost: " + str(selected_item.cost) + " coins"
	
	# Show ownership info
	var purchase_count = ShopManager.get_purchase_count(str(current_player.name), selected_item.id)
	var max_purchases = selected_item.max_purchases
	
	if item_owned_label:
		if max_purchases == -1:
			item_owned_label.text = "Owned: " + str(purchase_count) + " (Unlimited)"
		else:
			item_owned_label.text = "Owned: " + str(purchase_count) + " / " + str(max_purchases)
	
	# Update purchase button
	if purchase_button:
		var can_afford = ShopManager.can_afford(current_player, selected_item.id)
		var max_reached = ShopManager.has_max_purchases(str(current_player.name), selected_item.id)
		
		if max_reached:
			purchase_button.text = "Max Purchases Reached"
			purchase_button.disabled = true
		elif not can_afford:
			purchase_button.text = "Cannot Afford"
			purchase_button.disabled = true
		else:
			purchase_button.text = "Purchase for " + str(selected_item.cost) + " coins"
			purchase_button.disabled = false


func _on_purchase_pressed() -> void:
	if not selected_item or not current_player:
		return
	
	# Attempt purchase
	var success = ShopManager.purchase_item(current_player, selected_item.id)
	
	if success:
		print("Purchase successful: ", selected_item.name)
		
		# Play purchase sound (if available)
		play_purchase_sound()
		
		# Refresh UI
		update_player_coins()
		update_item_details()
		load_category(current_category)  # Refresh item list
	else:
		print("Purchase failed: ", selected_item.name)
		# Could show error message here


func update_player_coins() -> void:
	if not current_player or not player_coins_label:
		return
	
	player_coins_label.text = "Your Coins: " + str(current_player.coins)


func play_purchase_sound() -> void:
	# Play purchase sound effect (using pickup sound as placeholder)
	var pickup_sound = load("res://assets/Sounds/SFX/pickup.mp3")
	if pickup_sound:
		var temp_sound = AudioStreamPlayer2D.new()
		temp_sound.stream = pickup_sound
		# Add to scene tree and play
		add_child(temp_sound)
		temp_sound.play()
		# Clean up after sound finishes
		temp_sound.finished.connect(func(): temp_sound.queue_free())

