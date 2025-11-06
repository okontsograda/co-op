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
	print("[RestWaveOverlay] _ready() called, connecting buttons...")
	if ready_button:
		if not ready_button.pressed.is_connected(_on_ready_button_pressed):
			ready_button.pressed.connect(_on_ready_button_pressed)
			print("[RestWaveOverlay] Ready button connected successfully")
		else:
			print("[RestWaveOverlay] Ready button already connected")
	else:
		print("[RestWaveOverlay] ERROR: ready_button is null in _ready()")

	if level_up_button:
		if not level_up_button.pressed.is_connected(_on_level_up_button_pressed):
			level_up_button.pressed.connect(_on_level_up_button_pressed)
			print("[RestWaveOverlay] Level up button connected successfully")
		else:
			print("[RestWaveOverlay] Level up button already connected")
	else:
		print("[RestWaveOverlay] ERROR: level_up_button is null in _ready()")


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

	# Debug: Check if UI elements are found
	print("[RestWaveOverlay] UI element check:")
	print("  - title_label: ", title_label != null)
	print("  - subtitle_label: ", subtitle_label != null)
	print("  - ready_status_label: ", ready_status_label != null)
	print("  - level_up_button: ", level_up_button != null)
	print("  - ready_button: ", ready_button != null)

	# Reset ready button
	if ready_button:
		ready_button.disabled = false
		ready_button.text = "READY UP"
	else:
		print("[RestWaveOverlay] ERROR: ready_button is null!")

	# Show the overlay
	show()

	print("[RestWaveOverlay] Overlay shown")


func hide_overlay() -> void:
	print("[RestWaveOverlay] Hiding overlay")
	hide()


func _on_ready_button_pressed() -> void:
	if is_local_player_ready:
		print("[RestWaveOverlay] Button already pressed, ignoring")
		return

	print("[RestWaveOverlay] Local player marked ready")
	is_local_player_ready = true

	# Disable button
	if ready_button:
		ready_button.disabled = true
		ready_button.text = "WAITING..."

	# Send ready request to server
	print("[RestWaveOverlay] Getting NetworkHandler...")
	var network_handler = get_node_or_null("/root/NetworkHandler")
	if network_handler:
		print("[RestWaveOverlay] NetworkHandler found")
		if network_handler.has_method("request_ready_up"):
			print("[RestWaveOverlay] Method exists, calling request_ready_up...")

			# In solo play (or as host), we ARE the server, so call directly
			# In multiplayer as client, use RPC
			if multiplayer.is_server():
				print("[RestWaveOverlay] Calling directly (we are server)")
				network_handler.request_ready_up()
			else:
				print("[RestWaveOverlay] Calling via RPC (we are client)")
				network_handler.request_ready_up.rpc()

			print("[RestWaveOverlay] Call completed")
		else:
			print("[RestWaveOverlay] ERROR: request_ready_up method not found!")
	else:
		print("[RestWaveOverlay] ERROR: NetworkHandler not found at /root/NetworkHandler!")


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

	print("[RestWaveOverlay] Counted %d/%d players ready" % [ready_count, total_count])

	# Update status label
	if ready_status_label:
		ready_status_label.text = "Ready: %d / %d" % [ready_count, total_count]
		print("[RestWaveOverlay] Updated label to: ", ready_status_label.text)

		# Color based on readiness
		if ready_count == total_count and total_count > 0:
			ready_status_label.modulate = Color(0.3, 1.0, 0.3)  # Green - all ready
		elif ready_count > 0:
			ready_status_label.modulate = Color(1.0, 0.7, 0.3)  # Orange - some ready
		else:
			ready_status_label.modulate = Color(1.0, 1.0, 1.0)  # White - none ready
	else:
		print("[RestWaveOverlay] ERROR: ready_status_label is null!")
