extends HBoxContainer

@onready var stat_label: Label = $StatLabel
@onready var stat_value: Label = $StatValue

var pending_label_text: String = ""
var pending_value_text: String = ""

func _ready():
	if pending_label_text != "" or pending_value_text != "":
		_apply_texts(pending_label_text, pending_value_text)

func setup(label_text: String, value_text: String):
	if not is_node_ready():
		# Store for later if nodes aren't ready yet
		pending_label_text = label_text
		pending_value_text = value_text
		return

	_apply_texts(label_text, value_text)

func _apply_texts(label_text: String, value_text: String):
	if stat_label:
		stat_label.text = label_text + ":"
	if stat_value:
		stat_value.text = value_text
