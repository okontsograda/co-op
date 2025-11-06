extends CanvasLayer

## Wave Notification - Shows wave completion and countdown messages

@onready var notification_label: Label = $CenterContainer/NotificationLabel

func _ready():
	# Start hidden
	hide()


func show_wave_completed(wave_number: int) -> void:
	if notification_label:
		notification_label.text = "WAVE %d COMPLETE!" % wave_number
		notification_label.modulate = Color(0.3, 1.0, 0.3)  # Green

	show()

	# Auto-hide after 2 seconds
	await get_tree().create_timer(2.0).timeout
	hide()


func show_countdown(seconds: int) -> void:
	if notification_label:
		notification_label.text = str(seconds)
		notification_label.modulate = Color(1.0, 1.0, 0.3)  # Yellow

	show()

	# Auto-hide after 0.8 seconds
	await get_tree().create_timer(0.8).timeout
	hide()


func show_wave_starting(wave_number: int) -> void:
	if notification_label:
		notification_label.text = "WAVE %d STARTING!" % wave_number
		notification_label.modulate = Color(1.0, 0.5, 0.3)  # Orange

	show()

	# Auto-hide after 1.5 seconds
	await get_tree().create_timer(1.5).timeout
	hide()
