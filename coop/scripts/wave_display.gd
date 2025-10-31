extends CanvasLayer

@onready var wave_label: Label = $Control/WaveLabel

var current_wave: int = 1


func _ready() -> void:
	# Initialize display
	update_display()


func update_wave(wave: int) -> void:
	current_wave = wave
	update_display()


func update_display() -> void:
	if wave_label:
		# Display wave number
		wave_label.text = "Wave " + str(current_wave)

