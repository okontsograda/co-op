extends CanvasLayer

@onready var wave_label: Label = $Control/WaveLabel

var current_wave: int = 1
var is_rest_wave: bool = false
var ready_count: int = 0
var total_count: int = 0


func _ready() -> void:
	# Initialize display
	update_display()


func update_wave(wave: int) -> void:
	current_wave = wave
	is_rest_wave = false
	update_display()


func show_rest_wave() -> void:
	is_rest_wave = true
	update_display()


func hide_rest_wave() -> void:
	is_rest_wave = false
	update_display()


func update_ready_count(ready: int, total: int) -> void:
	ready_count = ready
	total_count = total
	if is_rest_wave:
		update_display()


func update_display() -> void:
	if wave_label:
		if is_rest_wave:
			# Display rest wave status
			wave_label.text = "REST WAVE"
			if total_count > 0:
				wave_label.text += " - Ready: %d/%d" % [ready_count, total_count]

			# Change color to indicate rest wave
			wave_label.modulate = Color(0.3, 1.0, 0.5)  # Green
		else:
			# Display wave number
			wave_label.text = "Wave " + str(current_wave)
			wave_label.modulate = Color(1.0, 1.0, 1.0)  # White
