extends Area2D

# Coin properties
var coin_value: int = 1  # How much currency this coin gives
var lifetime: float = 10.0  # How long the coin lasts before disappearing
var time_alive: float = 0.0

# Visual properties
var float_amplitude: float = 5.0  # How much the coin bobs up and down
var float_speed: float = 3.0  # How fast the coin bobs
var initial_y: float = 0.0

# Collection range
var collection_enabled: bool = true


func _ready() -> void:
	# Add to coins group for easy reference
	add_to_group("coins")
	
	# Store initial position for floating animation
	initial_y = position.y
	
	# Connect to body entered signal for player collection
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Start fade-out timer
	await get_tree().create_timer(lifetime - 2.0).timeout
	start_fade_out()


func _process(delta: float) -> void:
	time_alive += delta
	
	# Bob up and down for visual effect
	position.y = initial_y + sin(time_alive * float_speed) * float_amplitude
	
	# Delete after lifetime
	if time_alive >= lifetime:
		queue_free()


func start_fade_out() -> void:
	# Fade out over the last 2 seconds
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 2.0)


func _on_body_entered(body: Node2D) -> void:
	# Check if a player collected the coin
	if body.is_in_group("players") and collection_enabled:
		collection_enabled = false  # Prevent double collection
		
		# Award currency to the player
		if body.has_method("collect_coin"):
			body.collect_coin(coin_value)
			print("Player ", body.name, " collected coin worth ", coin_value)
		
		# Play collection effect (optional sound/particles can be added here)
		play_collection_effect()
		
		# Remove the coin
		queue_free()


func play_collection_effect() -> void:
	# Visual feedback - quick scale up before disappearing
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.5, 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)

