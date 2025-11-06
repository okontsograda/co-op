extends Node
class_name WorldGenAlgorithms

## Collection of reusable world generation algorithms
## Use these as templates for creating custom world generation patterns

## Generates a circular island with beaches
static func generate_circular_island(
	terrain_map: Array[Array],
	width: int,
	height: int,
	noise: FastNoiseLite,
	water_level: float
) -> void:
	var center = Vector2(width / 2.0, height / 2.0)
	var max_radius = min(width, height) / 2.0 * 0.8
	
	for x in width:
		for y in height:
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			var distance_factor = 1.0 - (distance / max_radius)
			distance_factor = clamp(distance_factor, 0.0, 1.0)
			
			# Add noise for natural coastline
			var noise_val = noise.get_noise_2d(x, y)
			var height_val = (noise_val + 1.0) / 2.0  # Normalize to 0-1
			
			# Combine distance and noise
			var final_val = height_val * distance_factor * 1.3
			
			if final_val > water_level:
				terrain_map[x][y] = 1  # LAND
			else:
				terrain_map[x][y] = 0  # WATER


## Generates multiple scattered islands
static func generate_archipelago(
	terrain_map: Array[Array],
	width: int,
	height: int,
	noise: FastNoiseLite,
	num_islands: int = 5
) -> void:
	# Start with all water
	for x in width:
		for y in height:
			terrain_map[x][y] = 0  # WATER
	
	# Generate random island centers
	for i in num_islands:
		var center_x = randi_range(width * 0.2, width * 0.8)
		var center_y = randi_range(height * 0.2, height * 0.8)
		var island_radius = randf_range(10, 25)
		
		# Create island
		for x in range(center_x - int(island_radius * 1.5), center_x + int(island_radius * 1.5)):
			for y in range(center_y - int(island_radius * 1.5), center_y + int(island_radius * 1.5)):
				if x < 0 or x >= width or y < 0 or y >= height:
					continue
				
				var dx = x - center_x
				var dy = y - center_y
				var distance = sqrt(dx * dx + dy * dy)
				
				# Add noise for natural shape
				var noise_val = noise.get_noise_2d(x, y)
				var adjusted_radius = island_radius + noise_val * 5
				
				if distance < adjusted_radius:
					terrain_map[x][y] = 1  # LAND


## Generates a maze-like dungeon layout
static func generate_maze_dungeon(
	terrain_map: Array[Array],
	width: int,
	height: int,
	corridor_width: int = 2
) -> void:
	# Start with all walls (water)
	for x in width:
		for y in height:
			terrain_map[x][y] = 0  # WATER (acts as walls)
	
	# Create maze using recursive backtracking
	var visited = {}
	var stack = []
	var start_x = 1
	var start_y = 1
	
	stack.append(Vector2i(start_x, start_y))
	visited[Vector2i(start_x, start_y)] = true
	
	var directions = [Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)]
	
	while stack.size() > 0:
		var current = stack[-1]
		
		# Find unvisited neighbors
		var unvisited = []
		for dir in directions:
			var next = current + dir
			if next.x > 0 and next.x < width - 1 and next.y > 0 and next.y < height - 1:
				if not visited.has(next):
					unvisited.append(next)
		
		if unvisited.size() > 0:
			# Choose random unvisited neighbor
			var next = unvisited[randi() % unvisited.size()]
			visited[next] = true
			
			# Carve path (make it land)
			var between = (current + next) / 2
			terrain_map[current.x][current.y] = 1
			terrain_map[between.x][between.y] = 1
			terrain_map[next.x][next.y] = 1
			
			stack.append(next)
		else:
			stack.pop_back()


## Generates connected rooms (dungeon style)
static func generate_room_dungeon(
	terrain_map: Array[Array],
	width: int,
	height: int,
	num_rooms: int = 8
) -> void:
	# Start with all walls
	for x in width:
		for y in height:
			terrain_map[x][y] = 0  # WATER (walls)
	
	var rooms = []
	
	# Generate rooms
	for i in num_rooms:
		var room_w = randi_range(8, 15)
		var room_h = randi_range(8, 15)
		var room_x = randi_range(5, width - room_w - 5)
		var room_y = randi_range(5, height - room_h - 5)
		
		# Check for overlap with existing rooms
		var overlaps = false
		for room in rooms:
			if (room_x < room.x + room.w + 3 and room_x + room_w + 3 > room.x and
				room_y < room.y + room.h + 3 and room_y + room_h + 3 > room.y):
				overlaps = true
				break
		
		if not overlaps:
			rooms.append({"x": room_x, "y": room_y, "w": room_w, "h": room_h})
			
			# Carve out room
			for x in range(room_x, room_x + room_w):
				for y in range(room_y, room_y + room_h):
					if x >= 0 and x < width and y >= 0 and y < height:
						terrain_map[x][y] = 1  # LAND
	
	# Connect rooms with corridors
	for i in range(rooms.size() - 1):
		var room1 = rooms[i]
		var room2 = rooms[i + 1]
		
		var start_x = room1.x + room1.w / 2
		var start_y = room1.y + room1.h / 2
		var end_x = room2.x + room2.w / 2
		var end_y = room2.y + room2.h / 2
		
		# Horizontal corridor
		for x in range(min(start_x, end_x), max(start_x, end_x) + 1):
			if x >= 0 and x < width and start_y >= 0 and start_y < height:
				terrain_map[x][start_y] = 1
				# Make corridor 2 tiles wide
				if start_y + 1 < height:
					terrain_map[x][start_y + 1] = 1
		
		# Vertical corridor
		for y in range(min(start_y, end_y), max(start_y, end_y) + 1):
			if end_x >= 0 and end_x < width and y >= 0 and y < height:
				terrain_map[end_x][y] = 1
				# Make corridor 2 tiles wide
				if end_x + 1 < width:
					terrain_map[end_x + 1][y] = 1


## Generates a heightmap-based terrain
static func generate_heightmap_terrain(
	terrain_map: Array[Array],
	width: int,
	height: int,
	noise: FastNoiseLite,
	sea_level: float = 0.3,
	mountain_level: float = 0.7
) -> void:
	for x in width:
		for y in height:
			var noise_val = noise.get_noise_2d(x, y)
			var height_val = (noise_val + 1.0) / 2.0  # Normalize to 0-1
			
			if height_val < sea_level:
				terrain_map[x][y] = 0  # WATER
			elif height_val < mountain_level:
				terrain_map[x][y] = 1  # LAND
			else:
				terrain_map[x][y] = 1  # LAND (could be mountains if you add terrain type)


## Generates a spiral pattern
static func generate_spiral(
	terrain_map: Array[Array],
	width: int,
	height: int
) -> void:
	var center = Vector2(width / 2.0, height / 2.0)
	
	for x in width:
		for y in height:
			var pos = Vector2(x, y)
			var diff = pos - center
			var angle = atan2(diff.y, diff.x)
			var distance = diff.length()
			
			# Create spiral pattern
			var spiral_value = fmod(angle + distance * 0.3, PI)
			
			if spiral_value > PI / 2:
				terrain_map[x][y] = 1  # LAND
			else:
				terrain_map[x][y] = 0  # WATER


## Generates a grid pattern with rooms
static func generate_grid_world(
	terrain_map: Array[Array],
	width: int,
	height: int,
	grid_size: int = 15
) -> void:
	for x in width:
		for y in height:
			# Create grid walls
			if x % grid_size == 0 or y % grid_size == 0:
				terrain_map[x][y] = 0  # WATER (walls)
			else:
				terrain_map[x][y] = 1  # LAND (rooms)
	
	# Add doorways
	for i in range(0, width, grid_size):
		for j in range(0, height, grid_size):
			if i > 0 and i < width - 1:
				# Vertical doorway
				var door_y = j + grid_size / 2
				if door_y < height:
					terrain_map[i][door_y] = 1
			if j > 0 and j < height - 1:
				# Horizontal doorway
				var door_x = i + grid_size / 2
				if door_x < width:
					terrain_map[door_x][j] = 1


## Voronoi-based biome generation
static func generate_voronoi_biomes(
	terrain_map: Array[Array],
	width: int,
	height: int,
	num_points: int = 10
) -> void:
	# Generate random points
	var points = []
	for i in num_points:
		points.append(Vector2(randf() * width, randf() * height))
	
	# Assign each tile to nearest point
	for x in width:
		for y in height:
			var pos = Vector2(x, y)
			var nearest_dist = INF
			var nearest_idx = 0
			
			for i in points.size():
				var dist = pos.distance_to(points[i])
				if dist < nearest_dist:
					nearest_dist = dist
					nearest_idx = i
			
			# Alternate between land and water based on region
			if nearest_idx % 2 == 0:
				terrain_map[x][y] = 1  # LAND
			else:
				terrain_map[x][y] = 0  # WATER
