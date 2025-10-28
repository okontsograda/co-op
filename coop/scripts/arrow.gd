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
	print("Arrow collision detected with ", body.name, ", has_hit: ", has_hit)
	# Don't process if already hit
	if has_hit:
		print("Arrow already hit, ignoring collision")
		return
	
	# Don't hit the player who fired it
	if body == get_meta("shooter", null):
		print("Arrow hit shooter, ignoring")
		return
	
	# Mark as hit immediately to prevent multiple collisions
	has_hit = true
	print("Arrow marked as hit, processing damage")
	
	# Disable collision detection immediately
	var collision = get_node("CollisionShape2D")
	if collision:
		collision.disabled = true
	
	# Check if we hit a player or enemy
	if body.has_method("take_damage"):
		var shooter = get_meta("shooter", null)
		var damage = 10  # Default damage
		
		if body.is_in_group("enemies"):
			# Use shooter's attack damage for enemies
			if shooter and shooter.has_method("get_attack_damage"):
				damage = shooter.get_attack_damage()
			else:
				damage = 25  # Fallback damage
		
		body.take_damage(damage, shooter)
		print("Arrow hit ", body.name, " for ", damage, " damage")
	
	# Stop the arrow
	queue_free()

func _on_screen_exited() -> void:
	# Remove arrow when it leaves the screen
	queue_free()

func get_shooter() -> Node2D:
	# Return the shooter for enemy collision detection
	return get_meta("shooter", null)

func initialize(shooter: Node2D, start_pos: Vector2, target_pos: Vector2) -> void:
	# Set shooter metadata
	set_meta("shooter", shooter)
	
	# Position arrow
	global_position = start_pos
	
	# Calculate direction to target
	direction = (target_pos - start_pos).normalized()
	
	# Rotate arrow to face direction
	rotation = direction.angle()
