extends Node

@onready var network_handler = $NetworkHandler

func _ready() -> void:
	print("🎮 Starting client...")
	# Auto-connect to server after a short delay
	await get_tree().create_timer(1.0).timeout
	connect_to_server()

func connect_to_server() -> void:
	print("🔌 Connecting to server...")
	
	# Try primary port first
	network_handler.start_client()
	
	# Wait a moment to see if connection succeeds
	await get_tree().create_timer(2.0).timeout
	
	if network_handler.multiplayer.multiplayer_peer == null:
		print("❌ Failed to connect on port 42069")
		print("🔄 Trying alternative port 42070...")
		
		# Try alternative port
		network_handler.PORT = 42070
		network_handler.start_client()
		await get_tree().create_timer(2.0).timeout
		
		if network_handler.multiplayer.multiplayer_peer == null:
			print("❌ Failed to connect to server on both ports")
			print("💡 Make sure the dedicated server is running!")
		else:
			print("✅ Connected to server on port 42070!")
	else:
		print("✅ Connected to server successfully on port 42069!")

func _input(event: InputEvent) -> void:
	# Allow client to be closed with ESC
	if event.is_action_pressed("ui_cancel"):
		print("🛑 Disconnecting from server...")
		if network_handler.multiplayer.multiplayer_peer:
			network_handler.multiplayer.multiplayer_peer.close()
		get_tree().quit()
