extends CanvasLayer

# References to UI elements
@onready var ability_container: PanelContainer = $Control/AbilityContainer
@onready var ability_icon: TextureRect = $Control/AbilityContainer/HBoxContainer/AbilityIcon
@onready var ability_name: Label = $Control/AbilityContainer/HBoxContainer/VBoxContainer/AbilityName
@onready var ability_key: Label = $Control/AbilityContainer/HBoxContainer/VBoxContainer/AbilityKey
@onready var cooldown_overlay: ColorRect = $Control/AbilityContainer/CooldownOverlay
@onready var cooldown_text: Label = $Control/AbilityContainer/CooldownOverlay/CooldownText

# Visual states
var ready_color = Color(0.2, 0.8, 0.3, 0.9)  # Green when ready
var cooldown_color = Color(0.3, 0.3, 0.3, 0.9)  # Gray when on cooldown


func _ready() -> void:
	# Initialize UI (positioned via CanvasLayer anchors)
	if cooldown_overlay:
		cooldown_overlay.visible = false
	
	if ability_container:
		ability_container.modulate = ready_color


func update_cooldown(is_ready: bool, time_remaining: float, max_cooldown: float) -> void:
	# Update the cooldown display
	if not ability_container or not cooldown_overlay or not cooldown_text:
		return
	
	if is_ready:
		# Ability is ready
		cooldown_overlay.visible = false
		ability_container.modulate = ready_color
	else:
		# Ability is on cooldown
		cooldown_overlay.visible = true
		ability_container.modulate = cooldown_color
		
		# Update cooldown text
		cooldown_text.text = str(ceil(time_remaining)) + "s"
		
		# Update cooldown overlay height based on progress
		var progress = time_remaining / max_cooldown
		cooldown_overlay.size.y = ability_container.size.y * progress
		cooldown_overlay.position.y = ability_container.size.y * (1.0 - progress)

