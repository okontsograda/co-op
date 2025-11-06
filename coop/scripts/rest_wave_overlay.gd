extends CanvasLayer

## Rest Wave Overlay - Shows when players can shop and apply upgrades

# UI References
@onready var overlay_panel = $CenterContainer/Panel
@onready var title_label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var subtitle_label = $CenterContainer/Panel/VBoxContainer/SubtitleLabel
@onready var ready_status_container = $CenterContainer/Panel/VBoxContainer/ReadyStatusContainer
@onready var ready_button = $CenterContainer/Panel/VBoxContainer/ReadyButton
@onready var timer_label = $CenterContainer/Panel/VBoxContainer/TimerLabel

# State
var is_local_player_ready: bool = false
var player_ready_states: Dictionary = {}


func _ready():
	# Start hidden
	hide()

	# Connect ready button
	if ready_button and not ready_button.pressed.is_connected(_on_ready_button_pressed):
		ready_button.pressed.connect(_on_ready_button_pressed)


func show_overlay() -> void:
	print("[RestWaveOverlay] Showing overlay")
	is_local_player_ready = false

	# Reset UI
	if title_label:
		title_label.text = "REST WAVE"

	if subtitle_label:
		subtitle_label.text = "Visit the shop or apply level-ups\nPress Ready when done"

	if ready_button:
		ready_button.disabled = false
		ready_button.text = "READY UP"

	if timer_label:
		timer_label.text = ""

	# Clear ready status
	clear_ready_status()

	# Show the overlay
	show()

	print("[RestWaveOverlay] Overlay shown")


func hide_overlay() -> void:
	print("[RestWaveOverlay] Hiding overlay")
	hide()


func _on_ready_button_pressed() -> void:
	if is_local_player_ready:
		return

	print("[RestWaveOverlay] Local player marked ready")
	is_local_player_ready = true

	# Disable button
	if ready_button:
		ready_button.disabled = true
		ready_button.text = "WAITING FOR OTHERS..."

	# Send ready request to server
	var network_handler = get_node("/root/NetworkHandler")
	if network_handler:
		network_handler.request_ready_up.rpc()


func update_ready_states(ready_states: Dictionary) -> void:
	print("[RestWaveOverlay] Updating ready states: ", ready_states)
	player_ready_states = ready_states

	# Update UI
	refresh_ready_status()


func clear_ready_status() -> void:
	# Clear all ready status labels
	if not ready_status_container:
		return

	for child in ready_status_container.get_children():
		child.queue_free()


func refresh_ready_status() -> void:
	# Clear existing labels
	clear_ready_status()

	if not ready_status_container:
		return

	# Create labels for each player
	var ready_count = 0
	var total_count = player_ready_states.size()

	for peer_id in player_ready_states:
		var is_ready = player_ready_states[peer_id]
		if is_ready:
			ready_count += 1

		# Create a label for this player
		var label = Label.new()
		label.text = "Player %d: %s" % [peer_id, "✓ Ready" if is_ready else "⏳ Not Ready"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Color based on ready state
		if is_ready:
			label.modulate = Color(0.3, 1.0, 0.3)  # Green
		else:
			label.modulate = Color(1.0, 0.7, 0.3)  # Orange

		ready_status_container.add_child(label)

	# Update subtitle with count
	if subtitle_label:
		subtitle_label.text = "Ready: %d / %d\nVisit shop or apply upgrades" % [ready_count, total_count]


func update_timer(time_elapsed: float, max_time: float) -> void:
	if not timer_label:
		return

	var remaining = max_time - time_elapsed
	if remaining > 0:
		var minutes = int(remaining) / 60
		var seconds = int(remaining) % 60
		timer_label.text = "Time remaining: %d:%02d" % [minutes, seconds]

		# Change color when time is running out
		if remaining < 30:
			timer_label.modulate = Color(1.0, 0.3, 0.3)  # Red
		elif remaining < 60:
			timer_label.modulate = Color(1.0, 0.7, 0.3)  # Orange
		else:
			timer_label.modulate = Color(1.0, 1.0, 1.0)  # White
	else:
		timer_label.text = "Starting soon..."
		timer_label.modulate = Color(1.0, 0.3, 0.3)  # Red
