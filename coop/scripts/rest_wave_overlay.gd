extends CanvasLayer

## Rest Wave Overlay - Shows when players can shop and apply upgrades

# UI References
@onready var title_label = $TopCenterMessage/VBoxContainer/TitleLabel
@onready var subtitle_label = $TopCenterMessage/VBoxContainer/SubtitleLabel
@onready var ready_status_label = $TopCenterMessage/VBoxContainer/ReadyStatusLabel
@onready var level_up_button = $LeftSidePanel/VBoxContainer/LevelUpButton
@onready var ready_button = $LeftSidePanel/VBoxContainer/ReadyButton

# State
var is_local_player_ready: bool = false
var player_ready_states: Dictionary = {}


func _ready():
	# Start hidden
	hide()

	# Connect buttons
	if ready_button and not ready_button.pressed.is_connected(_on_ready_button_pressed):
		ready_button.pressed.connect(_on_ready_button_pressed)

	if level_up_button and not level_up_button.pressed.is_connected(_on_level_up_button_pressed):
		level_up_button.pressed.connect(_on_level_up_button_pressed)


func _process(_delta):
	# Update level up button text with pending count
	if visible and level_up_button:
		var team_xp = get_node_or_null("/root/TeamXP")
		if team_xp:
			var pending = team_xp.get_pending_level_ups()
			level_up_button.text = "LEVEL UP (%d)" % pending
			level_up_button.disabled = pending <= 0


func show_overlay() -> void:
	print("[RestWaveOverlay] Showing overlay")
	is_local_player_ready = false

	# Reset ready button
	if ready_button:
		ready_button.disabled = false
		ready_button.text = "READY UP"

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
		ready_button.text = "WAITING..."

	# Send ready request to server
	var network_handler = get_node("/root/NetworkHandler")
	if network_handler:
		network_handler.request_ready_up.rpc()


func _on_level_up_button_pressed() -> void:
	# Trigger one level up from the queue
	var team_xp = get_node_or_null("/root/TeamXP")
	if team_xp and team_xp.has_method("trigger_single_level_up"):
		var triggered = team_xp.trigger_single_level_up()
		if triggered:
			print("[RestWaveOverlay] Triggered level up from button")


func update_ready_states(ready_states: Dictionary) -> void:
	print("[RestWaveOverlay] Updating ready states: ", ready_states)
	player_ready_states = ready_states

	# Count ready players
	var ready_count = 0
	var total_count = player_ready_states.size()

	for peer_id in player_ready_states:
		if player_ready_states[peer_id]:
			ready_count += 1

	# Update status label
	if ready_status_label:
		ready_status_label.text = "Ready: %d / %d" % [ready_count, total_count]

		# Color based on readiness
		if ready_count == total_count and total_count > 0:
			ready_status_label.modulate = Color(0.3, 1.0, 0.3)  # Green - all ready
		elif ready_count > 0:
			ready_status_label.modulate = Color(1.0, 0.7, 0.3)  # Orange - some ready
		else:
			ready_status_label.modulate = Color(1.0, 1.0, 1.0)  # White - none ready
