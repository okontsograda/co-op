extends Node

# Music Manager - Handles background music across all scenes
# This is an autoload singleton that persists across scene changes

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _init():
	# Allow music to continue playing even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

# Music tracks
const MAIN_MENU_MUSIC = "res://assets/Sounds/Music/Border_of_Forest.mp3"
const BOSS_MUSIC = "res://assets/Sounds/Music/Boss.wav"
const EPIC_BUILDUP_MUSIC = "res://assets/Sounds/Music/Epic_BuildUp.wav"
const INTRO_MUSIC = "res://assets/Sounds/Music/Intro.wav"

var current_track: String = ""

func _ready():
	# Add the music player as a child
	add_child(music_player)
	music_player.bus = "Music"
	music_player.volume_db = -20.927  # Match the volume you set in the scene
	
	# Start playing the main menu music
	play_music(MAIN_MENU_MUSIC, true)

func play_music(track_path: String, loop: bool = true):
	# Don't restart if already playing this track
	if current_track == track_path and music_player.playing:
		return
	
	var stream = load(track_path)
	if stream:
		music_player.stream = stream
		current_track = track_path
		music_player.play()
		print("Playing music: ", track_path)
	else:
		push_error("Failed to load music: " + track_path)

func stop_music():
	music_player.stop()
	current_track = ""

func set_volume(volume_db: float):
	music_player.volume_db = volume_db

func fade_out(duration: float = 1.0):
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -80, duration)
	tween.tween_callback(stop_music)

func fade_in(duration: float = 1.0, target_volume: float = -20.927):
	music_player.volume_db = -80
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", target_volume, duration)

