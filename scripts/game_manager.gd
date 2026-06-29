extends Node

var player = null
var boss = null
var nexus = null
var enemy_scene = preload("res://scenes/enemy.tscn")
var nexus_scene = preload("res://scenes/nexus.tscn")
var ore_scene = preload("res://scenes/ore_patch.tscn")

var game_time = 0.0
var current_wave = 1
var _spawn_timer = 0.0
var _base_spawn_rate = 2.0 # 초반에는 2초에 한 마리씩 천천히

var nexus_setup_timer = 60.0
var nexus_placed = false

# 업그레이드 레벨 변수 (기존, 인게임용)
var upg_miner_speed_level = 0
var upg_turret_damage_level = 0
var upg_player_hp_level = 0

# 메타 프로그레션 (영구 강화) 데이터
var total_cores = 0
var meta_hp_level = 0
var meta_damage_level = 0
var meta_speed_level = 0

# 로그라이트 보스 보상 스탯 배율 (퍼센트 계수)
var stat_speed_mult = 1.0       # 이동 속도
var stat_damage_mult = 1.0      # 공격 데미지
var stat_range_mult = 1.0       # 사거리
var stat_drill_mult = 1.0       # 채굴 속도 (작을수록 빠름, 혹은 반대로 처리)
var stat_firerate_mult = 1.0    # 공격 속도 배율

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_meta_data()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(player) and "toggle_pause" in player:
			player.toggle_pause()

func _spawn_ore(grid_pos: Vector2i, type: String):
	var ore = ore_scene.instantiate()
	ore.global_position = FactoryManager.get_world_pos(grid_pos)
	ore.z_index = -1
	if type == "iron":
		ore.modulate = Color(0.6, 0.8, 1.0) # 푸른빛 도는 은색
	get_tree().current_scene.add_child(ore)
	FactoryManager.register_ore(grid_pos, type)

var last_boss_wave = 0
var initial_rival_spawned = false

func _process(delta):
	if get_tree().paused: return
	if not is_instance_valid(get_tree().current_scene): return
	if get_tree().current_scene.name == "TitleScreen": return
	
	game_time += delta
	var new_wave = int(game_time / 30.0) + 1
	
	if new_wave > current_wave:
		current_wave = new_wave
		
		if current_wave % 3 == 0 and current_wave > last_boss_wave:
			spawn_boss()
			last_boss_wave = current_wave
			
		# 웨이브마다 중립 요새(라이벌) 1기 스폰 (2웨이브부터)
		if current_wave >= 2:
			spawn_rival()
	
	if is_instance_valid(player):
		if not initial_rival_spawned:
			spawn_rival()
			initial_rival_spawned = true
			
		player.update_ui()
		
		_spawn_timer -= delta
		if _spawn_timer <= 0:
			_spawn_enemy()
			var current_spawn_rate = max(0.3, _base_spawn_rate - (current_wave * 0.15))
			_spawn_timer = current_spawn_rate

func spawn_boss():
	var boss_types = [
		preload("res://scripts/boss.gd"),
		preload("res://scripts/boss_incinerator.gd"),
		preload("res://scripts/boss_broodmother.gd")
	]
	
	var boss_script = boss_types[randi() % boss_types.size()]
	var boss_instance = boss_script.new()
	boss = boss_instance
	
	var angle = randf() * PI * 2
	var distance = 800.0
	if is_instance_valid(player):
		boss_instance.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	boss_instance.setup(current_wave)
	get_tree().current_scene.add_child(boss_instance)
	print("!!! 거대 보스 등장 !!!")

func _spawn_enemy():
	var angle = randf() * PI * 2
	var distance = 600.0
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	
	if enemy.has_method("setup"):
		# 몬스터 타입 결정 로직
		var type = 0 # 0: 일반
		var rand_val = randf()
		
		if current_wave >= 2:
			if rand_val < 0.2:
				type = 2 # 20% 확률로 탱커
			elif rand_val < 0.5:
				type = 1 # 30% 확률로 스워머
			elif rand_val < 0.7:
				type = 3 # 20% 확률로 스피터
		
		enemy.setup(current_wave, type)
		
	get_tree().current_scene.add_child(enemy)

func spawn_rival():
	var active_rivals = get_tree().get_nodes_in_group("rival").size()
	if active_rivals >= 2: return # 맵에 최대 2대까지만 유지
	
	var rival_scene = preload("res://scenes/rival_fortress.tscn")
	var rival = rival_scene.instantiate()
	
	var angle = randf() * PI * 2
	var distance = randf_range(1000.0, 1500.0)
	if is_instance_valid(player):
		rival.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * distance
		
	get_tree().current_scene.add_child(rival)
	print("중립 이동 요새(Rival)가 스폰되었습니다!")

func reset_state():
	game_time = 0.0
	current_wave = 1
	last_boss_wave = 0
	initial_rival_spawned = false
	_spawn_timer = 0.0
	
	upg_miner_speed_level = 0
	upg_turret_damage_level = 0
	upg_player_hp_level = 0
	
	stat_speed_mult = 1.0
	stat_damage_mult = 1.0
	stat_range_mult = 1.0
	stat_drill_mult = 1.0
	stat_firerate_mult = 1.0
	
	FactoryManager.grid.clear()
	FactoryManager.ore_grid.clear()
	
	get_tree().paused = false

func restart_game():
	reset_state()
	get_tree().reload_current_scene()

func start_new_game():
	reset_state()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func apply_meta_upgrades():
	# 메타 업그레이드를 인게임 스탯 배율에 반영
	stat_damage_mult = 1.0 + (meta_damage_level * 0.1)
	stat_speed_mult = 1.0 + (meta_speed_level * 0.05)
	
	if is_instance_valid(player):
		player.max_hp = 500.0 + (meta_hp_level * 100.0)
		player.hp = player.max_hp

func save_meta_data():
	var meta_data = {
		"total_cores": total_cores,
		"meta_hp_level": meta_hp_level,
		"meta_damage_level": meta_damage_level,
		"meta_speed_level": meta_speed_level
	}
	var file = FileAccess.open("user://meta_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta_data))
		file.close()
		print("메타 데이터 저장 완료!")

func load_meta_data():
	var file = FileAccess.open("user://meta_data.json", FileAccess.READ)
	if not file: return
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var data = json.data
		total_cores = data.get("total_cores", 0)
		meta_hp_level = data.get("meta_hp_level", 0)
		meta_damage_level = data.get("meta_damage_level", 0)
		meta_speed_level = data.get("meta_speed_level", 0)
		print("메타 데이터 로드 완료! 누적 코어: ", total_cores)

func save_game():
	var save_data = {}
	
	save_data["manager"] = {
		"game_time": game_time,
		"current_wave": current_wave,
		"last_boss_wave": last_boss_wave,
		"initial_rival_spawned": initial_rival_spawned,
		"upgrades": {
			"miner": upg_miner_speed_level,
			"turret": upg_turret_damage_level,
			"hp": upg_player_hp_level
		},
		"stats": {
			"speed": stat_speed_mult,
			"damage": stat_damage_mult,
			"range": stat_range_mult,
			"drill": stat_drill_mult,
			"firerate": stat_firerate_mult
		}
	}
	
	if FactoryManager.has_method("get_save_data"):
		save_data["factory"] = FactoryManager.get_save_data()
		
	if is_instance_valid(player) and player.has_method("get_save_data"):
		save_data["player"] = player.get_save_data()
		
	var rivals_data = []
	for r in get_tree().get_nodes_in_group("rival"):
		if r.has_method("get_save_data"):
			rivals_data.append(r.get_save_data())
	save_data["rivals"] = rivals_data
	
	var json_string = JSON.stringify(save_data)
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("게임 저장 완료!")
	else:
		print("게임 저장 실패!")
		
	if is_instance_valid(player) and "toggle_pause" in player:
		player.toggle_pause()

func load_game():
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if not file:
		print("저장된 게임이 없습니다!")
		return
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("저장 파일 파싱 실패!")
		return
		
	var save_data = json.data
	
	# 상태 복원 전 맵 초기화
	for n in get_tree().get_nodes_in_group("enemy"): n.queue_free()
	for n in get_tree().get_nodes_in_group("rival"): n.queue_free()
	for n in get_tree().get_nodes_in_group("resource"): n.queue_free()
	
	if is_instance_valid(player) and player.has_method("clear_buildings"):
		player.clear_buildings()
	
	# Manager 복원
	if save_data.has("manager"):
		var m = save_data["manager"]
		game_time = m.get("game_time", 0.0)
		current_wave = m.get("current_wave", 1)
		last_boss_wave = m.get("last_boss_wave", 0)
		initial_rival_spawned = m.get("initial_rival_spawned", false)
		
		if m.has("upgrades"):
			var u = m["upgrades"]
			upg_miner_speed_level = u.get("miner", 0)
			upg_turret_damage_level = u.get("turret", 0)
			upg_player_hp_level = u.get("hp", 0)
			
		if m.has("stats"):
			var s = m["stats"]
			stat_speed_mult = s.get("speed", 1.0)
			stat_damage_mult = s.get("damage", 1.0)
			stat_range_mult = s.get("range", 1.0)
			stat_drill_mult = s.get("drill", 1.0)
			stat_firerate_mult = s.get("firerate", 1.0)
	
	# Factory 복원
	if save_data.has("factory") and FactoryManager.has_method("load_save_data"):
		FactoryManager.load_save_data(save_data["factory"])
		
	# Player 복원
	if save_data.has("player") and is_instance_valid(player) and player.has_method("load_save_data"):
		player.load_save_data(save_data["player"])
		
	# Rivals 복원
	if save_data.has("rivals"):
		for r_data in save_data["rivals"]:
			var rival_scene = preload("res://scenes/rival_fortress.tscn")
			var rival = rival_scene.instantiate()
			get_tree().current_scene.add_child(rival)
			if rival.has_method("load_save_data"):
				rival.load_save_data(r_data)
	
	get_tree().paused = false
	if is_instance_valid(player) and is_instance_valid(player.pause_panel):
		player.pause_panel.visible = false
	
	print("게임 불러오기 완료!")
