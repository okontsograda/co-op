extends CanvasLayer

## Debug Overlay for Game Director
## Displays real-time director metrics and performance data
## Toggle with 0 key

# ============================================================================
# UI REFERENCES
# ============================================================================

@onready var debug_panel: Panel = $DebugPanel
@onready var debug_label: RichTextLabel = $DebugPanel/MarginContainer/DebugLabel

# ============================================================================
# STATE
# ============================================================================

var is_visible: bool = false
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

	print("[DebugOverlay] Ready - Press 0 to toggle")

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_0:
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

	# Add phase description
	var phase_desc = get_phase_description(data.intensity)
	text += "[color=gray][font_size=11]%s[/font_size][/color]\n" % phase_desc

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
	var event_desc = ""
	if data.event == "BOSS_WAVE":
		event_color = "red"
		event_desc = "Multiple HUGE bosses!"
	elif data.event == "ELITE_SWARM":
		event_color = "orange"
		event_desc = "All enemies +1 size larger"
	elif data.event == "TANK_WAVE":
		event_color = "orange"
		event_desc = "More Large/Huge enemies"
	elif data.event == "SPEED_CHALLENGE":
		event_color = "orange"
		event_desc = "Faster enemies, bonus XP"

	text += "Event: [color=%s]%s[/color]\n" % [event_color, data.event]
	if event_desc != "":
		text += "[color=gray][font_size=11]%s[/font_size][/color]\n" % event_desc

	text += "Spawned: %d / %d [color=gray](%.0f%%)[/color]\n" % [
		data.enemies_spawned,
		data.enemies_total,
		data.spawn_progress * 100
	]

	# Get current enemy count from the scene
	var enemies_alive = get_tree().get_nodes_in_group("enemies").size()
	var alive_color = "green"
	if enemies_alive > data.enemies_total * 0.7:
		alive_color = "red"
	elif enemies_alive > data.enemies_total * 0.4:
		alive_color = "yellow"

	text += "Alive: [color=%s]%d[/color]\n" % [alive_color, enemies_alive]
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
	text += "[color=gray][font_size=12]Press 0 to hide[/font_size][/color]"

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

func get_phase_description(phase: String) -> String:
	match phase:
		"CALM":
			return "Slow spawn rate, easy start"
		"BUILDING":
			return "Gradual spawn acceleration"
		"PEAK":
			return "Maximum spawn rate & intensity"
		"RELIEF":
			return "Wind down before wave end"
		_:
			return "Unknown phase"
