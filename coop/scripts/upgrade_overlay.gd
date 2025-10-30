extends CanvasLayer

# Reference to the player who is leveling up
var player: Node2D = null

# Available upgrades for selection
var available_upgrades: Array = []

# Currently selected upgrade index (0-2, or -1 for none)
var selected_index: int = -1

# Flag to prevent double-selection
var upgrade_accepted: bool = false


func _ready():
	# Start hidden
	hide()


# Show upgrade selection for a player
func show_upgrades(p_player: Node2D) -> void:
	player = p_player
	upgrade_accepted = false
	selected_index = -1

	# Get 3 random upgrades from UpgradeSystem
	available_upgrades = UpgradeSystem.get_random_upgrades(3, player.upgrade_stacks)

	# If we got less than 3 upgrades, something is wrong
	if available_upgrades.size() == 0:
		print("ERROR: No upgrades available!")
		queue_free()
		return

	# Populate upgrade cards
	populate_card(0, available_upgrades[0] if available_upgrades.size() > 0 else null)
	populate_card(1, available_upgrades[1] if available_upgrades.size() > 1 else null)
	populate_card(2, available_upgrades[2] if available_upgrades.size() > 2 else null)

	# Connect accept button
	var accept_button = get_node("CenterContainer/VBoxContainer/AcceptButton")
	if accept_button and not accept_button.pressed.is_connected(accept_upgrade):
		accept_button.pressed.connect(accept_upgrade)

	# Show the overlay
	show()

	# Make sure input is enabled
	set_process_input(true)


func populate_card(index: int, upgrade) -> void:
	if upgrade == null:
		# Hide the card if no upgrade
		var card = get_node("CenterContainer/VBoxContainer/UpgradeCards/Card" + str(index + 1))
		if card:
			card.hide()
		return

	var card_path = (
		"CenterContainer/VBoxContainer/UpgradeCards/Card" + str(index + 1) + "/VBoxContainer/"
	)

	# Get current stack count
	var current_level = player.upgrade_stacks.get(upgrade.id, 0)

	# Set card content
	var name_label = get_node(card_path + "NameLabel")
	if name_label:
		name_label.text = upgrade.name

	var desc_label = get_node(card_path + "DescLabel")
	if desc_label:
		desc_label.text = upgrade.description

	var level_label = get_node(card_path + "LevelLabel")
	if level_label:
		if current_level > 0:
			level_label.text = "Lv. " + str(current_level) + " → " + str(current_level + 1)
		else:
			level_label.text = "NEW!"


func _input(event: InputEvent) -> void:
	if not visible or upgrade_accepted:
		return

	# Handle keyboard input (keys 1, 2, 3) to SELECT upgrade
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.keycode
		if key == KEY_1 and available_upgrades.size() > 0:
			select_upgrade(0)
		elif key == KEY_2 and available_upgrades.size() > 1:
			select_upgrade(1)
		elif key == KEY_3 and available_upgrades.size() > 2:
			select_upgrade(2)

	# Handle mouse clicks on cards to SELECT upgrade
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check which card was clicked
		for i in range(min(3, available_upgrades.size())):
			var card = get_node("CenterContainer/VBoxContainer/UpgradeCards/Card" + str(i + 1))
			if card and card.visible:
				var card_rect = card.get_global_rect()
				if card_rect.has_point(event.position):
					select_upgrade(i)
					break


func select_upgrade(index: int) -> void:
	if index < 0 or index >= available_upgrades.size():
		print("ERROR: Invalid upgrade index: ", index)
		return

	# Clear previous selection
	if selected_index >= 0:
		clear_card_highlight(selected_index)

	# Set new selection
	selected_index = index
	highlight_card(index)

	# Enable accept button
	var accept_button = get_node("CenterContainer/VBoxContainer/AcceptButton")
	if accept_button:
		accept_button.disabled = false

	print(
		"Selected upgrade: ",
		available_upgrades[index].name,
		" (press ACCEPT to confirm)"
	)


func highlight_card(index: int) -> void:
	var card = get_node("CenterContainer/VBoxContainer/UpgradeCards/Card" + str(index + 1))
	if card:
		# Add a visual highlight (modulate to light green)
		card.modulate = Color(0.7, 1.0, 0.7)


func clear_card_highlight(index: int) -> void:
	var card = get_node("CenterContainer/VBoxContainer/UpgradeCards/Card" + str(index + 1))
	if card:
		# Remove highlight
		card.modulate = Color(1.0, 1.0, 1.0)


func accept_upgrade() -> void:
	if upgrade_accepted or selected_index < 0:
		return

	var selected_upgrade = available_upgrades[selected_index]
	print("Player accepted upgrade: ", selected_upgrade.name)

	# Mark as accepted to prevent double-acceptance
	upgrade_accepted = true

	# Apply upgrade to player
	if player and player.has_method("apply_upgrade"):
		player.apply_upgrade(selected_upgrade.id)

	# TODO: Play selection sound effect

	# Close overlay
	close_overlay()


func close_overlay() -> void:
	# Hide and cleanup
	hide()
	queue_free()
