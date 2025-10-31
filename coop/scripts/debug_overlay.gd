extends CanvasLayer

## Debug Overlay for Game Director
## Displays real-time director metrics and performance data
## Toggle with F3

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var debug_panel: Panel = $DebugPanel
@onready var debug_label: RichTextLabel = $DebugPanel/MarginContainer/DebugLabel

# ============================================================================
# STATE
# ============================================================================

var is_visible: bool = true
var update_timer: float = 0.0
const UPDATE_INTERVAL = 0.1  # Update display 10 times per second

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	# Make sure we're on top of everything
	layer = 100

	# Initial visibility
	debug_panel.visible = is_visible

	print("[DebugOverlay] Ready - Press F3 to toggle")

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		toggle_debug()

func toggle_debug():
	is_visible = !is_visible
	debug_panel.visible = is_visible
	print("[DebugOverlay] Debug overlay %s" % ("shown" if is_visible else "hidden"))

# ============================================================================
# UPDATE LOOP
# ============================================================================

func _process(delta):
	if not is_visible:
		return

	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		update_display()

func update_display():
	if not GameDirector:
		debug_label.text = "[color=red]GameDirector not found![/color]"
		return

	var data = GameDirector.get_debug_data()
	var color = GameDirector.get_intensity_color()

	# Build debug text with BBCode formatting
	var text = "[font_size=16][b]GAME DIRECTOR DEBUG[/b][/font_size]\n\n"

	# === INTENSITY SECTION ===
	text += "[font_size=14][b]INTENSITY[/b][/font_size]\n"
	text += "Phase: [color=#%s][b]%s[/b][/color]\n" % [color.to_html(false), data.intensity]
	text += "Timer: %.1f / %.1f s [color=gray](%.0f%%)[/color]\n" % [
		data.intensity_timer,
		data.intensity_duration,
		data.intensity_progress * 100
	]
	text += "Spawn Rate: [color=yellow]%.1fx[/color]\n" % data.spawn_rate
	text += "\n"

	# === WAVE INFO ===
	text += "[font_size=14][b]WAVE INFO[/b][/font_size]\n"
	text += "Wave: [color=cyan]%d[/color]\n" % data.wave

	# Color code event type
	var event_color = "white"
	if data.event == "BOSS_WAVE":
		event_color = "red"
	elif data.event != "NONE":
		event_color = "orange"

	text += "Event: [color=%s]%s[/color]\n" % [event_color, data.event]
	text += "Spawned: %d / %d [color=gray](%.0f%%)[/color]\n" % [
		data.enemies_spawned,
		data.enemies_total,
		data.spawn_progress * 100
	]
	text += "\n"

	# === STRESS & SCALING ===
	text += "[font_size=14][b]PERFORMANCE[/b][/font_size]\n"

	# Color code stress level
	var stress_color = get_stress_color(data.stress_level)
	text += "Stress: [color=#%s]%.0f%% (%s)[/color]\n" % [
		stress_color.to_html(false),
		data.stress_level * 100,
		data.stress_category
	]

	text += "Players: %d (x%.1f scaling)\n" % [data.player_count, data.scaling_multiplier]
	text += "\n"

	# === PLAYER DETAILS ===
	if data.player_performance.size() > 0:
		text += "[font_size=14][b]PLAYER STATS[/b][/font_size]\n"

		for peer_id in data.player_performance:
			var perf = data.player_performance[peer_id]
			var health_color = get_health_color(perf.health_percent)

			text += "Player %d:\n" % peer_id
			text += "  HP: [color=#%s]%.0f%%[/color] (%.0f/%.0f)\n" % [
				health_color.to_html(false),
				perf.health_percent * 100,
				perf.current_health,
				perf.max_health
			]
			text += "  K/D: %d / %d\n" % [perf.kills, perf.deaths]

			if perf.damage_taken_recent > 0:
				text += "  [color=red]Recent Damage: %.0f[/color]\n" % perf.damage_taken_recent

		text += "\n"

	# === FOOTER ===
	text += "[color=gray][font_size=12]Press F3 to hide[/font_size][/color]"

	debug_label.text = text

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func get_stress_color(stress: float) -> Color:
	if stress < 0.3:
		return Color(0.3, 0.9, 0.3)  # Green - low stress
	elif stress < 0.5:
		return Color(0.9, 0.9, 0.3)  # Yellow - medium stress
	elif stress < 0.7:
		return Color(0.9, 0.6, 0.2)  # Orange - high stress
	else:
		return Color(0.9, 0.2, 0.2)  # Red - critical stress

func get_health_color(health_percent: float) -> Color:
	if health_percent > 0.7:
		return Color(0.3, 0.9, 0.3)  # Green - healthy
	elif health_percent > 0.4:
		return Color(0.9, 0.9, 0.3)  # Yellow - hurt
	elif health_percent > 0.2:
		return Color(0.9, 0.6, 0.2)  # Orange - low health
	else:
		return Color(0.9, 0.2, 0.2)  # Red - critical health
