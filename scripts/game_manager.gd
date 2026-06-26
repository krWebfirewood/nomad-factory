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

# 업그레이드 레벨 변수 (기존)
var upg_miner_speed_level = 0
var upg_turret_damage_level = 0
var upg_player_hp_level = 0

# 로그라이트 보스 보상 스탯 배율 (퍼센트 계수)
var stat_speed_mult = 1.0       # 이동 속도
var stat_damage_mult = 1.0      # 공격 데미지
var stat_range_mult = 1.0       # 사거리
var stat_drill_mult = 1.0       # 채굴 속도 (작을수록 빠름, 혹은 반대로 처리)

func _ready():
	pass

func _spawn_ore(grid_pos: Vector2i, type: String):
	var ore = ore_scene.instantiate()
	ore.global_position = FactoryManager.get_world_pos(grid_pos)
	ore.z_index = -1
	if type == "iron":
		ore.modulate = Color(0.6, 0.8, 1.0) # 푸른빛 도는 은색
	get_tree().current_scene.add_child(ore)
	FactoryManager.register_ore(grid_pos, type)

var last_boss_wave = 0

func _process(delta):
	game_time += delta
	var new_wave = int(game_time / 30.0) + 1
	
	if new_wave > current_wave:
		current_wave = new_wave
		
		# 3웨이브마다 보스 스폰 (3, 6, 9...)
		if current_wave % 3 == 0 and current_wave > last_boss_wave:
			spawn_boss()
			last_boss_wave = current_wave
	
	if is_instance_valid(player):
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
