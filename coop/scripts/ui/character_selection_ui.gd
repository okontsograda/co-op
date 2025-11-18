extends CanvasLayer

signal closed
signal selection_confirmed(selected_class: String, selected_weapon: String)

# UI References
@onready var class_grid: GridContainer = $Control/MainPanel/VBoxContainer/ContentContainer/ClassSelectionPanel/ClassGrid
@onready var class_icon: TextureRect = $Control/MainPanel/VBoxContainer/ContentContainer/ClassInfoPanel/ClassPreview/VBoxContainer/ClassIcon
@onready var class_name_label: Label = $Control/MainPanel/VBoxContainer/ContentContainer/ClassInfoPanel/ClassPreview/VBoxContainer/ClassName
@onready var class_description: Label = $Control/MainPanel/VBoxContainer/ContentContainer/ClassInfoPanel/ClassPreview/VBoxContainer/ClassDescription
@onready var stats_container: VBoxContainer = $Control/MainPanel/VBoxContainer/ContentContainer/ClassInfoPanel/ClassPreview/VBoxContainer/StatsContainer
@onready var weapon_options: HBoxContainer = $Control/MainPanel/VBoxContainer/ContentContainer/ClassInfoPanel/WeaponSelection/WeaponOptions
@onready var confirm_button: Button = $Control/MainPanel/VBoxContainer/BottomButtons/ConfirmButton

# Preload class button scene
var class_button_scene = preload("res://coop/scenes/ui/meta_progression/class_button.tscn")

# Current selection
var selected_class: String = ""
var selected_weapon: String = ""

# Class data with stats
var class_data = {
	"Archer": {
		"description": "A ranged damage dealer with high mobility and precision.",
		"icon": "🏹",
		"stats": {
			"Health": "75",
			"Speed": "120%",
			"Damage": "High",
			"Range": "Long",
			"Defense": "Low"
		},
		"weapons": ["Bow", "Crossbow", "Throwing Knives"]
	},
	"Knight": {
		"description": "A tanky melee fighter with high defense and sword mastery.",
		"icon": "⚔️",
		"stats": {
			"Health": "150",
			"Speed": "90%",
			"Damage": "Medium",
			"Range": "Melee",
			"Defense": "Very High"
		},
		"weapons": ["Sword", "Mace", "Axe"]
	},
	"Mage": {
		"description": "A powerful spellcaster with elemental abilities and area damage.",
		"icon": "🔮",
		"stats": {
			"Health": "60",
			"Speed": "100%",
			"Damage": "Very High",
			"Range": "Medium",
			"Defense": "Very Low"
		},
		"weapons": ["Staff", "Wand", "Orb"]
	},
	"Tank": {
		"description": "The ultimate defender with crowd control and damage mitigation.",
		"icon": "🛡️",
		"stats": {
			"Health": "200",
			"Speed": "75%",
			"Damage": "Low",
			"Range": "Melee",
			"Defense": "Maximum"
		},
		"weapons": ["Shield & Hammer", "Great Shield", "Tower Shield"]
	}
}

func _ready():
	visible = false

func open():
	visible = true
	_populate_classes()

	# Pre-select current class if any
	var current_class = SaveSystem.get_selected_class()
	if current_class != "":
		_select_class(current_class)

func close():
	visible = false
	closed.emit()

func _populate_classes():
	# Clear existing buttons
	for child in class_grid.get_children():
		child.queue_free()

	var unlocked_classes = SaveSystem.get_unlocked_classes()

	for p_class_name in class_data.keys():
		var class_button = class_button_scene.instantiate()

		# Add to tree first
		class_grid.add_child(class_button)

		# Then setup
		class_button.setup(p_class_name, class_data[p_class_name], p_class_name in unlocked_classes)
		class_button.class_selected.connect(_on_class_button_pressed)

		# Highlight current selection
		if p_class_name == selected_class:
			class_button.set_selected(true)

func _on_class_button_pressed(p_class_name: String):
	if not SaveSystem.is_class_unlocked(p_class_name):
		# Show message about needing to unlock
		_show_locked_message(p_class_name)
		return

	_select_class(p_class_name)

func _select_class(p_class_name: String):
	selected_class = p_class_name

	# Update all class buttons
	for button in class_grid.get_children():
		if button.has_method("set_selected"):
			button.set_selected(button.player_class == p_class_name)

	# Update class info display
	_update_class_info(p_class_name)

	# Populate weapon options
	_populate_weapon_options(p_class_name)

	# Enable confirm button
	confirm_button.disabled = false

func _update_class_info(p_class_name: String):
	if p_class_name not in class_data:
		return

	var data = class_data[p_class_name]

	# Update name and description
	class_name_label.text = p_class_name
	class_description.text = data.description

	# Update icon (using emoji for now)
	for child in class_icon.get_children():
		child.queue_free()

	var icon_label = Label.new()
	icon_label.text = data.icon
	icon_label.add_theme_font_size_override("font_size", 64)
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	class_icon.add_child(icon_label)

	# Update stats
	for child in stats_container.get_children():
		child.queue_free()

	for stat_name in data.stats:
		var stat_line = HBoxContainer.new()

		var stat_label = Label.new()
		stat_label.text = stat_name + ":"
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var stat_value = Label.new()
		stat_value.text = data.stats[stat_name]
		stat_value.add_theme_color_override("font_color", _get_stat_color(data.stats[stat_name]))

		stat_line.add_child(stat_label)
		stat_line.add_child(stat_value)
		stats_container.add_child(stat_line)

func _get_stat_color(stat_value: String) -> Color:
	# Color code stats based on their value
	match stat_value:
		"Very High", "Maximum", "Long":
			return Color(0.2, 1.0, 0.2)  # Green
		"High":
			return Color(0.6, 1.0, 0.6)  # Light green
		"Medium", "100%":
			return Color(1.0, 1.0, 1.0)  # White
		"Low", "90%", "Melee":
			return Color(1.0, 0.8, 0.4)  # Yellow
		"Very Low", "75%":
			return Color(1.0, 0.4, 0.4)  # Red
		_:
			return Color.WHITE

func _populate_weapon_options(p_class_name: String):
	# Clear existing weapon options
	for child in weapon_options.get_children():
		child.queue_free()

	if p_class_name not in class_data:
		return

	var weapons = class_data[p_class_name].weapons
	var unlocked_weapons = SaveSystem.get_unlocked_weapons()

	var button_group = ButtonGroup.new()
	var first_available = ""

	for weapon in weapons:
		var weapon_button = CheckBox.new()
		weapon_button.text = weapon
		weapon_button.button_group = button_group

		# Check if weapon is unlocked
		var weapon_id = weapon.to_lower().replace(" ", "_").replace("&", "and")
		var is_unlocked = weapon_id in unlocked_weapons or weapon == weapons[0]  # First weapon always unlocked

		if not is_unlocked:
			weapon_button.disabled = true
			weapon_button.text += " (Locked)"
		elif first_available == "":
			first_available = weapon
			weapon_button.button_pressed = true
			selected_weapon = weapon

		weapon_button.toggled.connect(_on_weapon_selected.bind(weapon))
		weapon_options.add_child(weapon_button)

	# Select first available weapon by default
	if first_available != "" and selected_weapon == "":
		selected_weapon = first_available

func _on_weapon_selected(pressed: bool, weapon: String):
	if pressed:
		selected_weapon = weapon

func _show_locked_message(p_class_name: String):
	# You could show a popup or toast message here
	print("Class %s is locked! Purchase it in the Meta Shop." % p_class_name)

func _on_close_button_pressed():
	close()

func _on_cancel_button_pressed():
	close()

func _on_confirm_button_pressed():
	if selected_class == "" or selected_weapon == "":
		return

	# Save selection
	SaveSystem.set_selected_class(selected_class)
	SaveSystem.save_loadout(selected_class, selected_weapon)

	# Update LobbyManager if in multiplayer
	var peer_id = multiplayer.get_unique_id()
	if peer_id in LobbyManager.players:
		LobbyManager.players[peer_id]["class"] = selected_class
		LobbyManager.players[peer_id]["weapon"] = selected_weapon

	# Emit signal and close
	selection_confirmed.emit(selected_class, selected_weapon)
	close()