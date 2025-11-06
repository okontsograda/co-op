extends Node
class_name WorldGenerator

## WorldGenerator - Procedural tilemap and world generation system
## Supports multiple generation algorithms for creating dynamic levels

# Generation parameters
@export_group("World Size")
@export var world_width: int = 100
@export var world_height: int = 100

@export_group("Generation Settings")
@export_enum("Islands", "Continents", "Caves", "Rivers", "Custom") var generation_type: String = "Islands"
@export var seed_value: int = -1  # -1 for random seed
@export var water_level: float = 0.4  # 0.0 to 1.0
@export var smoothing_passes: int = 2

@export_group("Noise Settings")
@export var noise_frequency: float = 0.05
@export var noise_octaves: int = 4
@export var noise_lacunarity: float = 2.0

@export_group("Decoration Density")
@export_range(0.0, 1.0) var tree_density: float = 0.15
@export_range(0.0, 1.0) var mushroom_density: float = 0.08
@export_range(0.0, 0.5) var bridge_chance: float = 0.3

@export_group("References")
@export var water_layer: TileMapLayer
@export var water_foam_layer: TileMapLayer
@export var land_layer: TileMapLayer
@export var bridge_layer: TileMapLayer
@export var decoration_parent: Node2D

# Scene references
var tree_scene: PackedScene = preload("res://coop/scenes/tree_1.tscn")
var mushroom_scene: PackedScene  # Optional

# Tile IDs (you may need to adjust these based on your tileset)
const WATER_TILE_ID = Vector2i(0, 0)
const LAND_TILE_ID = Vector2i(0, 0)
const FOAM_TILE_ID = Vector2i(0, 0)
const BRIDGE_TILE_H = Vector2i(0, 0)  # Horizontal bridge
const BRIDGE_TILE_V = Vector2i(0, 0)  # Vertical bridge

# Internal data
var terrain_map: Array[Array] = []  # 2D array of terrain types
var noise: FastNoiseLite

enum TerrainType {
	WATER,
	LAND,
	BRIDGE,
	DECORATION
}


func _ready() -> void:
	# Initialize noise
	noise = FastNoiseLite.new()
	
	# Set seed
	if seed_value == -1:
		seed_value = randi()
	noise.seed = seed_value
	seed(seed_value)
	
	# Configure noise
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = noise_lacunarity


## Generate the entire world
func generate_world() -> void:
	print("Generating world with seed: ", seed_value)
	
	# Clear existing tilemaps
	clear_world()
	
	# Initialize terrain map
	initialize_terrain_map()
	
	# Generate base terrain based on type
	match generation_type:
		"Islands":
			generate_islands()
		"Continents":
			generate_continents()
		"Caves":
			generate_caves()
		"Rivers":
			generate_rivers()
		"Custom":
			generate_custom()
	
	# Apply smoothing
	for i in smoothing_passes:
		smooth_terrain()
	
	# Place bridges
	if bridge_layer:
		place_bridges()
	
	# Apply terrain to tilemaps
	apply_terrain_to_tilemaps()
	
	# Add water foam at water edges
	if water_foam_layer:
		add_water_foam()
	
	# Place decorations (trees, mushrooms)
	if decoration_parent:
		place_decorations()
	
	print("World generation complete!")


## Clear all existing tiles and decorations
func clear_world() -> void:
	if water_layer:
		water_layer.clear()
	if water_foam_layer:
		water_foam_layer.clear()
	if land_layer:
		land_layer.clear()
	if bridge_layer:
		bridge_layer.clear()
	if decoration_parent:
		for child in decoration_parent.get_children():
			child.queue_free()


## Initialize the terrain map array
func initialize_terrain_map() -> void:
	terrain_map.clear()
	for x in world_width:
		var column: Array = []
		for y in world_height:
			column.append(TerrainType.WATER)
		terrain_map.append(column)


## Generate island-style terrain
func generate_islands() -> void:
	var center_x = world_width / 2.0
	var center_y = world_height / 2.0
	var max_distance = sqrt(center_x * center_x + center_y * center_y)
	
	for x in world_width:
		for y in world_height:
			# Distance from center (for island shape)
			var dx = x - center_x
			var dy = y - center_y
			var distance = sqrt(dx * dx + dy * dy)
			var distance_factor = 1.0 - (distance / max_distance)
			
			# Get noise value
			var noise_value = noise.get_noise_2d(x, y)
			
			# Combine noise with distance for island shape
			var combined_value = (noise_value + 1.0) / 2.0  # Normalize to 0-1
			combined_value = combined_value * distance_factor * 1.5
			
			# Determine terrain type
			if combined_value > water_level:
				terrain_map[x][y] = TerrainType.LAND
			else:
				terrain_map[x][y] = TerrainType.WATER


## Generate continent-style terrain (large landmasses)
func generate_continents() -> void:
	for x in world_width:
		for y in world_height:
			var noise_value = noise.get_noise_2d(x, y)
			var normalized = (noise_value + 1.0) / 2.0
			
			if normalized > water_level:
				terrain_map[x][y] = TerrainType.LAND
			else:
				terrain_map[x][y] = TerrainType.WATER


## Generate cave-like structures (inverted, mostly land with water pockets)
func generate_caves() -> void:
	for x in world_width:
		for y in world_height:
			var noise_value = noise.get_noise_2d(x, y)
			var normalized = (noise_value + 1.0) / 2.0
			
			# Invert the logic - mostly land
			if normalized < water_level * 0.5:  # Less water
				terrain_map[x][y] = TerrainType.WATER
			else:
				terrain_map[x][y] = TerrainType.LAND


## Generate terrain with rivers
func generate_rivers() -> void:
	# Start with mostly land
	for x in world_width:
		for y in world_height:
			terrain_map[x][y] = TerrainType.LAND
	
	# Create rivers using noise
	for x in world_width:
		for y in world_height:
			var noise_value = noise.get_noise_2d(x * 0.1, y)  # Stretch horizontally
			if abs(noise_value) < 0.15:  # Create river channels
				terrain_map[x][y] = TerrainType.WATER
	
	# Add some lakes
	var num_lakes = randi_range(3, 6)
	for i in num_lakes:
		var lake_x = randi_range(10, world_width - 10)
		var lake_y = randi_range(10, world_height - 10)
		var lake_radius = randi_range(3, 8)
		
		for dx in range(-lake_radius, lake_radius):
			for dy in range(-lake_radius, lake_radius):
				var x = lake_x + dx
				var y = lake_y + dy
				if x >= 0 and x < world_width and y >= 0 and y < world_height:
					if dx * dx + dy * dy < lake_radius * lake_radius:
						terrain_map[x][y] = TerrainType.WATER


## Custom generation (override this for your own algorithms)
func generate_custom() -> void:
	# Example: Checkerboard pattern
	for x in world_width:
		for y in world_height:
			if (x + y) % 10 < 5:
				terrain_map[x][y] = TerrainType.LAND
			else:
				terrain_map[x][y] = TerrainType.WATER


## Smooth terrain using cellular automata rules
func smooth_terrain() -> void:
	var new_map: Array[Array] = []
	
	# Create a copy of the terrain map
	for x in world_width:
		var column: Array = []
		for y in world_height:
			column.append(terrain_map[x][y])
		new_map.append(column)
	
	# Apply smoothing rules
	for x in range(1, world_width - 1):
		for y in range(1, world_height - 1):
			var water_count = count_neighbor_type(x, y, TerrainType.WATER)
			
			# If surrounded mostly by water, become water
			if water_count > 4:
				new_map[x][y] = TerrainType.WATER
			# If surrounded mostly by land, become land
			elif water_count < 4:
				new_map[x][y] = TerrainType.LAND
	
	terrain_map = new_map


## Count neighbors of a specific terrain type
func count_neighbor_type(x: int, y: int, type: TerrainType) -> int:
	var count = 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < world_width and ny >= 0 and ny < world_height:
				if terrain_map[nx][ny] == type:
					count += 1
	return count


## Place bridges at water crossings
func place_bridges() -> void:
	for x in range(1, world_width - 1):
		for y in range(1, world_height - 1):
			# Only place bridges on water
			if terrain_map[x][y] != TerrainType.WATER:
				continue
			
			# Check for horizontal crossing (land-water-land)
			if terrain_map[x-1][y] == TerrainType.LAND and terrain_map[x+1][y] == TerrainType.LAND:
				if randf() < bridge_chance:
					place_bridge_at(x, y, true)  # Horizontal
			
			# Check for vertical crossing (land-water-land)
			elif terrain_map[x][y-1] == TerrainType.LAND and terrain_map[x][y+1] == TerrainType.LAND:
				if randf() < bridge_chance:
					place_bridge_at(x, y, false)  # Vertical


## Place a bridge tile at a specific location
func place_bridge_at(x: int, y: int, horizontal: bool) -> void:
	terrain_map[x][y] = TerrainType.BRIDGE
	
	# You'll need to adjust these tile coordinates based on your tileset
	var tile_coords = BRIDGE_TILE_H if horizontal else BRIDGE_TILE_V
	bridge_layer.set_cell(Vector2i(x, y), 0, tile_coords)


## Apply the terrain map to actual TileMapLayers
func apply_terrain_to_tilemaps() -> void:
	for x in world_width:
		for y in world_height:
			var pos = Vector2i(x, y)
			
			match terrain_map[x][y]:
				TerrainType.WATER:
					if water_layer:
						# Use different water tiles for variation
						var variation = randi() % 4
						water_layer.set_cell(pos, 0, Vector2i(variation, 0))
				
				TerrainType.LAND:
					if land_layer:
						# Use different land tiles for variation
						var variation = randi() % 4
						land_layer.set_cell(pos, 0, Vector2i(variation, 0))
				
				TerrainType.BRIDGE:
					# Bridges already placed in place_bridges()
					pass


## Add water foam at the edges of water and land
func add_water_foam() -> void:
	for x in range(1, world_width - 1):
		for y in range(1, world_height - 1):
			# Only add foam on water tiles
			if terrain_map[x][y] != TerrainType.WATER:
				continue
			
			# Check if adjacent to land
			var adjacent_to_land = false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if terrain_map[nx][ny] == TerrainType.LAND:
						adjacent_to_land = true
						break
				if adjacent_to_land:
					break
			
			# Place foam if adjacent to land
			if adjacent_to_land:
				var pos = Vector2i(x, y)
				# Alternate between foam variations
				var variation = (x + y) % 2
				water_foam_layer.set_cell(pos, 0, Vector2i(variation, 0))


## Place decorative objects (trees, mushrooms, etc.)
func place_decorations() -> void:
	for x in world_width:
		for y in world_height:
			# Only place decorations on land
			if terrain_map[x][y] != TerrainType.LAND:
				continue
			
			# Random chance for tree
			if randf() < tree_density:
				spawn_decoration(tree_scene, x, y)
			
			# Random chance for mushroom (if scene is set)
			elif mushroom_scene and randf() < mushroom_density:
				spawn_decoration(mushroom_scene, x, y)


## Spawn a decoration at a specific tile position
func spawn_decoration(scene: PackedScene, tile_x: int, tile_y: int) -> void:
	if not scene or not decoration_parent:
		return
	
	var decoration = scene.instantiate()
	
	# Convert tile coordinates to world position
	# Assuming 16x16 tiles (adjust if different)
	var tile_size = 16
	decoration.position = Vector2(tile_x * tile_size, tile_y * tile_size)
	
	decoration_parent.add_child(decoration)


## Regenerate the world with a new seed
func regenerate_with_new_seed() -> void:
	seed_value = randi()
	noise.seed = seed_value
	seed(seed_value)
	generate_world()


## Get terrain type at a specific position
func get_terrain_at(x: int, y: int) -> TerrainType:
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return TerrainType.WATER
	return terrain_map[x][y]


## Check if a position is walkable
func is_walkable(x: int, y: int) -> bool:
	var terrain = get_terrain_at(x, y)
	return terrain == TerrainType.LAND or terrain == TerrainType.BRIDGE
