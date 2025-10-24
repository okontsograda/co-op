extends Control

@onready var message_label: Label = $MessageLabel
@onready var background: NinePatchRect = $Background

var display_duration: float = 5.0
var fade_duration: float = 1.0
var timer: Timer
var current_message: String = ""

func _ready() -> void:
	visible = false
	# Make sure the chat bubble is on top
	z_index = 100
	print("ChatBubble: Ready, initial visibility = ", visible, ", z_index = ", z_index)
	# Create a timer for auto-hiding the bubble
	timer = Timer.new()
	timer.wait_time = display_duration
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

func show_message(message: String) -> void:
	# Prevent showing the same message multiple times
	if current_message == message and visible:
		print("ChatBubble: Same message already showing, ignoring")
		return
	
	print("ChatBubble: Showing message: ", message)
	current_message = message
	message_label.text = message
	visible = true
	
	# Reset the timer
	timer.start()
	
	# Reset alpha for fade-in effect
	modulate.a = 1.0
	
	print("ChatBubble: Message displayed, visible = ", visible)
	print("ChatBubble: Position = ", global_position)
	print("ChatBubble: Size = ", size)

func _on_timer_timeout() -> void:
	# Start fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(_hide_bubble)

func _hide_bubble() -> void:
	visible = false
	modulate.a = 1.0  # Reset for next time
