extends Node

var PORT: int = 42069
var peer: ENetMultiplayerPeer

func _ready() -> void:
	print("Starting dedicated server...")
	start_dedicated_server()

func start_dedicated_server() -> void:
	print("🔧 Initializing ENet...")
	
	# Create the multiplayer peer
	peer = ENetMultiplayerPeer.new()
	if peer == null:
		print("❌ Failed to create ENetMultiplayerPeer")
		get_tree().quit()
		return
	
	print("🔧 Creating server on port ", PORT, "...")
	
	# Try to create server with error handling
	var result = peer.create_server(PORT)
	print("🔧 Server creation result: ", result)
	
	if result == OK:
		multiplayer.multiplayer_peer = peer
		print("✅ Dedicated server started successfully!")
		print("📡 Server listening on port: ", PORT)
		print("🌐 Clients can connect to: localhost:", PORT)
		
		# Connect to peer events
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		
		# Set up the game scene
		setup_game_scene()
	else:
		print("❌ Failed to start server!")
		print("🔍 Error code: ", result)
		print("💡 Common causes:")
		print("   - Port ", PORT, " is already in use")
		print("   - Firewall blocking the port")
		print("   - Insufficient permissions")
		print("🔄 Trying alternative port...")
		
		# Try alternative port
		PORT = 42070
		result = peer.create_server(PORT)
		if result == OK:
			multiplayer.multiplayer_peer = peer
			print("✅ Server started on alternative port: ", PORT)
			print("🌐 Clients can connect to: localhost:", PORT)
			multiplayer.peer_connected.connect(_on_peer_connected)
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
			setup_game_scene()
		else:
			print("❌ Failed on alternative port too. Exiting...")
			get_tree().quit()

func setup_game_scene() -> void:
	# Load the main game scene
	var game_scene = preload("res://coop/scenes/example.tscn")
	var game_instance = game_scene.instantiate()
	add_child(game_instance)
	print("🎮 Game scene loaded on server")

func _on_peer_connected(peer_id: int) -> void:
	print("👤 Player connected: ", peer_id)
	print("📊 Total players: ", multiplayer.get_peers().size() + 1)

func _on_peer_disconnected(peer_id: int) -> void:
	print("👋 Player disconnected: ", peer_id)
	print("📊 Total players: ", multiplayer.get_peers().size())

func _input(event: InputEvent) -> void:
	# Allow server to be closed with ESC
	if event.is_action_pressed("ui_cancel"):
		print("🛑 Shutting down server...")
		get_tree().quit()
