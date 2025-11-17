extends PanelContainer

signal purchase_requested(item_data: Dictionary)

@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var item_name: Label = $MarginContainer/HBoxContainer/VBoxContainer/ItemName
@onready var item_description: Label = $MarginContainer/HBoxContainer/VBoxContainer/ItemDescription
@onready var price_label: Label = $MarginContainer/HBoxContainer/PriceContainer/PriceLabel
@onready var buy_button: Button = $MarginContainer/HBoxContainer/PriceContainer/BuyButton

var item_data: Dictionary = {}
var pending_setup_data: Dictionary = {}

func _ready():
	if not pending_setup_data.is_empty():
		_apply_setup(pending_setup_data)

func setup(data: Dictionary):
	if not is_node_ready():
		pending_setup_data = data
		return

	_apply_setup(data)

func _apply_setup(data: Dictionary):
	item_data = data

	# Set item info
	if item_name:
		item_name.text = data.get("name", "Unknown Item")
	if item_description:
		item_description.text = data.get("description", "No description available")
	if price_label:
		price_label.text = str(data.get("cost", 0)) + " MC"

	# Set icon if available (using emoji for now)
	if data.has("icon") and icon_rect:
		var icon_label = Label.new()
		icon_label.text = data.icon
		icon_label.add_theme_font_size_override("font_size", 32)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_rect.add_child(icon_label)

	# Check if already owned
	var is_owned = _check_if_owned()
	if is_owned and buy_button:
		buy_button.text = "Owned"
		buy_button.disabled = true
		modulate = Color(0.7, 0.7, 0.7, 1.0)  # Gray out owned items
	elif buy_button:
		# Check if can afford
		var can_afford = SaveSystem.get_meta_coins() >= data.get("cost", 0)
		if not can_afford:
			buy_button.disabled = true
			buy_button.text = "Can't Afford"

func _check_if_owned() -> bool:
	match item_data.get("type", ""):
		"class":
			return SaveSystem.is_class_unlocked(item_data.get("unlock", ""))
		"weapon":
			return SaveSystem.is_weapon_unlocked(item_data.get("unlock", ""))
		"cosmetic":
			return SaveSystem.is_cosmetic_unlocked(item_data.get("unlock", ""))
		_:
			return false

func _on_buy_button_pressed():
	purchase_requested.emit(item_data)