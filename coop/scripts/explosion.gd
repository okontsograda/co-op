extends Node2D

# Explosion effect that plays animation and auto-destroys


func _ready() -> void:
	# Get animation player
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player:
		# Animation should auto-play from scene settings
		# Connect to animation_finished signal
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)

	# Play explosion sound (if exists)
	var audio = get_node_or_null("ExplosionSound")
	if audio:
		audio.play()

	# Fallback: destroy after 1 second if no animation player
	if not anim_player:
		await get_tree().create_timer(1.0).timeout
		queue_free()


func _on_animation_finished(_anim_name: String) -> void:
	# Remove explosion effect after animation completes
	queue_free()
