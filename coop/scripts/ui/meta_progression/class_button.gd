extends PanelContainer

signal class_selected(selected_class: String)

@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var class_name_label: Label = $VBoxContainer/ClassName
@onready var select_button: Button = $VBoxContainer/SelectButton
@onready var locked_overlay: ColorRect = $LockedOverlay

var player_class: String = ""
var is_unlocked: bool = false
var is_selected: bool = false
var pending_setup_data: Dictionary = {}

func _ready():
	if pending_setup_data.has("class_name"):
		_apply_setup(pending_setup_data.class_name, pending_setup_data.class_data, pending_setup_data.is_unlocked)

func setup(p_class_name: String, class_data: Dictionary, p_is_unlocked: bool):
	if not is_node_ready():
		pending_setup_data = {
			"class_name": p_class_name,
			"class_data": class_data,
			"is_unlocked": p_is_unlocked
		}
		return

	_apply_setup(p_class_name, class_data, p_is_unlocked)

func _apply_setup(p_class_name: String, class_data: Dictionary, p_is_unlocked: bool):
	player_class = p_class_name
	is_unlocked = p_is_unlocked

	# Set class info
	if class_name_label:
		class_name_label.text = p_class_name

	# Set icon (using emoji for now)
	if class_data.has("icon") and icon_rect:
		var icon_label = Label.new()
		icon_label.text = class_data.icon
		icon_label.add_theme_font_size_override("font_size", 48)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_rect.add_child(icon_label)

	# Update button state
	if not is_unlocked:
		if select_button:
			select_button.text = "Locked"
			select_button.disabled = true
		if locked_overlay:
			locked_overlay.visible = true
		tooltip_text = "Purchase this class in the Meta Shop"
	else:
		if select_button:
			select_button.text = "Select"
		if locked_overlay:
			locked_overlay.visible = false

func set_selected(selected: bool):
	is_selected = selected

	# If nodes aren't ready yet, defer the visual update
	if not is_node_ready() or not select_button:
		call_deferred("_apply_selected_state")
		return

	_apply_selected_state()

func _apply_selected_state():
	if not select_button:
		return

	if is_selected:
		select_button.text = "Selected"
		modulate = Color(1.2, 1.2, 1.0, 1.0)  # Highlight selected
	elif is_unlocked:
		select_button.text = "Select"
		modulate = Color.WHITE

func _on_select_button_pressed():
	if is_unlocked and not is_selected:
		class_selected.emit(player_class)
