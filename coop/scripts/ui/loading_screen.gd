extends CanvasLayer

@onready var status_label: Label = %StatusLabel


func set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func set_subtext(text: String) -> void:
	var sub_label := %SubstatusLabel
	if sub_label:
		sub_label.text = text
