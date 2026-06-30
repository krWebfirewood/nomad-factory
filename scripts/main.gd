extends Node2D

var tree_scene = preload("res://scenes/resource_node.tscn")
var rock_scene = preload("res://scenes/rock_node.tscn")

@onready var tilemap = $TileMap
@onready var player = $Player

var chunk_size = 16
var loaded_chunks = {}
var noise = FastNoiseLite.new()
var time_modulate = null

func _ready():
	print("=== Main Scene 정상 시작됨 (심리스 무한 맵 가동) ===")
	
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", true)
	
	tilemap.queue_free()
	noise.seed = randi()
	noise.frequency = 0.05
	GameManager.player = player
	
	time_modulate = CanvasModulate.new()
	time_modulate.color = Color(1.0, 1.0, 1.0)
	add_child(time_modulate)

func _process(delta):
	if is_instance_valid(time_modulate):
		if GameManager.current_phase == "DAY":
			time_modulate.color = time_modulate.color.lerp(Color(1.0, 1.0, 1.0), delta * 2.0)
		else:
			time_modulate.color = time_modulate.color.lerp(Color(0.5, 0.5, 0.7), delta * 2.0)
			
	if is_instance_valid(player):
		var player_grid_pos = FactoryManager.get_world_grid_pos(player.global_position)
		var center_chunk = Vector2i(
			int(floor(float(player_grid_pos.x) / chunk_size)),
			int(floor(float(player_grid_pos.y) / chunk_size))
		)
		
		# 플레이어 주변 7x5 청크 로드 (해상도 증가에 대응)
		for cx in range(center_chunk.x - 3, center_chunk.x + 4):
			for cy in range(center_chunk.y - 2, center_chunk.y + 3):
				var chunk_pos = Vector2i(cx, cy)
				if not loaded_chunks.has(chunk_pos):
					_load_chunk(chunk_pos)

func _load_chunk(chunk_pos: Vector2i):
	loaded_chunks[chunk_pos] = true
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	
	var noise_val = noise.get_noise_2d(chunk_pos.x * chunk_size, chunk_pos.y * chunk_size)
	var biome = "plains"
	var bg_color = Color(0.25, 0.55, 0.25)
	
	if noise_val > 0.3:
		biome = "desert"
		bg_color = Color(0.75, 0.65, 0.45)
	elif noise_val < -0.3:
		biome = "snow"
		bg_color = Color(0.85, 0.9, 0.95)
		
	var bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = bg_color
	bg.size = Vector2(chunk_size * 64, chunk_size * 64)
	bg.global_position = Vector2(start_x * 64, start_y * 64)
	bg.z_index = -3
	add_child(bg)
	
	var spawn_ore_cluster = randf() < 0.5
	if biome == "snow": spawn_ore_cluster = randf() < 0.8
	elif biome == "desert": spawn_ore_cluster = randf() < 0.3
	
	var ore_center = Vector2i(start_x + randi() % chunk_size, start_y + randi() % chunk_size)
	
	for x in range(start_x, start_x + chunk_size):
		for y in range(start_y, start_y + chunk_size):
			var grid_pos = Vector2i(x, y)
			
			if abs(x) < 3 and abs(y) < 3: continue
				
			var is_ore = false
			if spawn_ore_cluster:
				var dist = abs(grid_pos.x - ore_center.x) + abs(grid_pos.y - ore_center.y)
				if dist <= 2 and randf() > 0.2: is_ore = true
			
			if not is_ore and randf() < 0.03: is_ore = true
				
			if is_ore:
				var ore_type = "stone"
				if biome == "desert": ore_type = "iron" if randf() < 0.6 else "stone"
				elif biome == "snow": ore_type = "iron" if randf() < 0.3 else "stone"
				else: ore_type = "iron" if randf() < 0.2 else "stone"
					
				GameManager._spawn_ore(grid_pos, ore_type)
				continue
			
			if FactoryManager.get_ore(grid_pos) != null: continue
				
			var tree_chance = 0.02
			var rock_chance = 0.03
			
			if biome == "desert":
				tree_chance = 0.001
				rock_chance = 0.05
			elif biome == "snow":
				tree_chance = 0.01
				rock_chance = 0.04
				
			var rand_val = randf()
			if rand_val < tree_chance: _spawn_object(tree_scene, grid_pos)
			elif rand_val < tree_chance + rock_chance: _spawn_object(rock_scene, grid_pos)
			
	if randf() < 0.1:
		var nest_script = preload("res://scripts/poi_nest.gd")
		var nest = nest_script.new()
		nest.global_position = Vector2(start_x * 64 + (chunk_size * 32), start_y * 64 + (chunk_size * 32))
		add_child(nest)

func _spawn_object(scene, grid_pos: Vector2i):
	var obj = scene.instantiate()
	obj.global_position = FactoryManager.get_world_pos(grid_pos)
	obj.z_index = 0
	add_child(obj)
