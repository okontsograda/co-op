extends Area2D

const speed: float = 500.0
var direction: Vector2 = Vector2.RIGHT
var has_hit: bool = false

func _ready() -> void:
	# Connect to body entered signal
	body_entered.connect(_on_body_entered)
	
	# Connect to visibility notifier
	var visibility = $VisibleOnScreenNotifier2D
	if visibility:
		visibility.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	if has_hit:
		return
	
	# Move the arrow in its direction
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Don't hit the player who fired it
	if body == get_meta("shooter", null):
		return
	
	# Check if we hit a player
	if body.has_method("take_damage"):
		var damage = 10  # Amount of damage
		body.take_damage(damage, get_meta("shooter", null))
		print("Arrow hit player ", body.name, " for ", damage, " damage")
	
	# Stop the arrow
	has_hit = true
	queue_free()

func _on_screen_exited() -> void:
	# Remove arrow when it leaves the screen
	queue_free()

func initialize(shooter: Node2D, start_pos: Vector2, target_pos: Vector2) -> void:
	# Set shooter metadata
	set_meta("shooter", shooter)
	
	# Position arrow
	global_position = start_pos
	
	# Calculate direction to target
	direction = (target_pos - start_pos).normalized()
	
	# Rotate arrow to face direction
	rotation = direction.angle()
