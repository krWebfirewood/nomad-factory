extends Node2D

var tree_scene = preload("res://scenes/resource_node.tscn")
var rock_scene = preload("res://scenes/rock_node.tscn")

@onready var tilemap = $TileMap
@onready var player = $Player

var chunk_size = 16
var loaded_chunks = {}

func _ready():
	print("=== Main Scene 정상 시작됨 (심리스 무한 맵 가동) ===")
	tilemap.z_index = -2 # 잔디가 광맥(-1)을 덮지 못하게 최하단 배치
	
	# 중앙 주변 강제 대형 광맥은 삭제 (절차적 생성에 전적으로 맡김)

func _process(_delta):
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
	
	# 새 청크가 열릴 때 50% 확률로 '작은' 광맥 군락 스폰
	var spawn_ore_cluster = randf() < 0.5
	var ore_center = Vector2i(start_x + randi() % chunk_size, start_y + randi() % chunk_size)
	
	for x in range(start_x, start_x + chunk_size):
		for y in range(start_y, start_y + chunk_size):
			var grid_pos = Vector2i(x, y)
			
			# 1. 잔디 타일 깔기 (0:0은 기본 잔디, 1:0은 다른 패턴)
			var atlas_coord = Vector2i(0, 0)
			if randf() > 0.8:
				atlas_coord = Vector2i(1, 0)
			tilemap.set_cell(0, grid_pos, 0, atlas_coord)
			
			# 2. 초기 넥서스 예상 스폰 지점 (0,0 근처) 보호
			if abs(x) < 3 and abs(y) < 3:
				continue
				
			# 3. 광맥 동적 스폰 (군락형 + 낱개 흩뿌리기)
			var is_ore = false
			if spawn_ore_cluster:
				var dist = abs(grid_pos.x - ore_center.x) + abs(grid_pos.y - ore_center.y)
				# 뭉툭한 네모 대신 마름모 형태의 작은 군락 (반경 2)
				if dist <= 2 and randf() > 0.2:
					is_ore = true
			
			# 낱개로 3% 확률로 흩뿌림
			if not is_ore and randf() < 0.03:
				is_ore = true
				
			if is_ore:
				var ore_type = "stone"
				if randf() < 0.2:
					ore_type = "iron"
				GameManager._spawn_ore(grid_pos, ore_type)
				continue # 광맥 위엔 자연물 불가
			
			# 기존에 광맥이 있는지 안전 확인
			if FactoryManager.get_ore(grid_pos) != null:
				continue
				
			# 4. 절차적 자연물 스폰 (나무 2%, 바위 1%)
			var rand_val = randf()
			if rand_val < 0.02:
				_spawn_object(tree_scene, grid_pos)
			elif rand_val < 0.03:
				_spawn_object(rock_scene, grid_pos)

func _spawn_object(scene, grid_pos: Vector2i):
	var obj = scene.instantiate()
	obj.global_position = FactoryManager.get_world_pos(grid_pos)
	obj.z_index = 0
	add_child(obj)
