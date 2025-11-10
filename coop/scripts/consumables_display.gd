extends CanvasLayer

@onready var slot1_container: Control = $Control/Slot1Container
@onready var slot2_container: Control = $Control/Slot2Container
@onready var slot1_label: Label = $Control/Slot1Container/ItemLabel
@onready var slot2_label: Label = $Control/Slot2Container/ItemLabel
@onready var slot1_count: Label = $Control/Slot1Container/CountLabel
@onready var slot2_count: Label = $Control/Slot2Container/CountLabel
@onready var slot1_key: Label = $Control/Slot1Container/KeyLabel
@onready var slot2_key: Label = $Control/Slot2Container/KeyLabel

# Store current consumable data
var slot1_item_id: String = ""
var slot1_quantity: int = 0
var slot2_item_id: String = ""
var slot2_quantity: int = 0


func _ready() -> void:
	# Initialize display
	update_display()


func set_slot(slot_number: int, item_id: String, quantity: int) -> void:
	if slot_number == 1:
		slot1_item_id = item_id
		slot1_quantity = quantity
	elif slot_number == 2:
		slot2_item_id = item_id
		slot2_quantity = quantity
	update_display()


func update_slot_quantity(slot_number: int, quantity: int) -> void:
	if slot_number == 1:
		slot1_quantity = quantity
	elif slot_number == 2:
		slot2_quantity = quantity
	update_display()


func update_display() -> void:
	# Update slot 1
	if slot1_item_id != "" and slot1_quantity > 0:
		var item = ShopManager.get_item(slot1_item_id)
		if item:
			slot1_label.text = item.name
			slot1_count.text = "x" + str(slot1_quantity)
			slot1_container.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Fully visible
		else:
			_clear_slot_display(1)
	else:
		_clear_slot_display(1)
	
	# Update slot 2
	if slot2_item_id != "" and slot2_quantity > 0:
		var item = ShopManager.get_item(slot2_item_id)
		if item:
			slot2_label.text = item.name
			slot2_count.text = "x" + str(slot2_quantity)
			slot2_container.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Fully visible
		else:
			_clear_slot_display(2)
	else:
		_clear_slot_display(2)


func _clear_slot_display(slot_number: int) -> void:
	if slot_number == 1:
		slot1_label.text = "Empty"
		slot1_count.text = ""
		slot1_container.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Dimmed
	elif slot_number == 2:
		slot2_label.text = "Empty"
		slot2_count.text = ""
		slot2_container.modulate = Color(0.5, 0.5, 0.5, 0.7)  # Dimmed


func clear_slot(slot_number: int) -> void:
	if slot_number == 1:
		slot1_item_id = ""
		slot1_quantity = 0
	elif slot_number == 2:
		slot2_item_id = ""
		slot2_quantity = 0
	update_display()

