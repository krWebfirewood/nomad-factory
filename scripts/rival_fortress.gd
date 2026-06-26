extends CharacterBody2D

var max_hp = 1000.0
var hp = 1000.0
var speed = 100.0
var inventory = {"wood": 0, "stone": 0, "iron": 0, "monster_core": 0}

var floor_grid = {}
var max_grid = 1 # -1 to 1 is 3x3

var state = "WANDER"
var target_pos = Vector2.ZERO
var state_timer = 0.0

var build_goal = -1
var has_refinery = false

@onready var health_fill = $HealthBar/HealthFill

func _ready():
	add_to_group("rival")
	pick_random_target()

func _draw():
	var rect = Rect2(-96, -96, 192, 192)
	draw_rect(rect, Color(0.3, 0.1, 0.1, 0.9)) # 어두운 붉은색
	
	for i in range(-1, 2):
		for j in range(-1, 2):
			var tile_rect = Rect2(i * 64 - 32, j * 64 - 32, 64, 64)
			draw_rect(tile_rect, Color(0.4, 0.2, 0.2, 1.0), false, 2.0)
			
	draw_circle(Vector2(0, 0), 15, Color(1.0, 0.0, 0.0, 0.8)) # 붉은 코어

func pick_random_target():
	var resources = get_tree().get_nodes_in_group("resource")
	if resources.size() > 0:
		var closest_res = null
		var min_dist = 999999.0
		# 가까운 자원 중 랜덤성을 위해 약간의 셔플 (상위 5개 중 랜덤)
		var valid_resources = []
		for r in resources:
			if is_instance_valid(r):
				valid_resources.append({"node": r, "dist": global_position.distance_to(r.global_position)})
		
		if valid_resources.size() > 0:
			valid_resources.sort_custom(func(a, b): return a["dist"] < b["dist"])
			var top_k = min(5, valid_resources.size())
			var target_res = valid_resources[randi() % top_k]["node"]
			
			target_pos = target_res.global_position
			state = "GATHER"
			return
			
	target_pos = global_position + Vector2(randf_range(-300, 300), randf_range(-300, 300))
	state = "WANDER"

func _physics_process(delta):
	if is_instance_valid(GameManager.player) and global_position.distance_to(GameManager.player.global_position) > 3000:
		# 너무 멀어지면 삭제 (성능 최적화)
		queue_free()
		return
		
	state_timer -= delta
	if state_timer <= 0:
		# GATHER 상태가 아니거나 대상에 도달하지 못했을 때만 타겟 재설정
		if state != "GATHER" or global_position.distance_to(target_pos) < 50:
			pick_random_target()
		state_timer = randf_range(3.0, 6.0)
		
	var direction = global_position.direction_to(target_pos)
	if global_position.distance_to(target_pos) > 20:
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		if state == "GATHER": pick_random_target()
		
	move_and_slide()
	
	# 채집 로직
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider != null and collider.has_method("gather"):
			collider.gather(self)
			
	try_build()

func add_item(item_name: String, amount: int):
	if not inventory.has(item_name):
		inventory[item_name] = 0
	inventory[item_name] += amount

func try_build():
	if build_goal == -1: pick_new_goal()
	
	var cost_w = 0; var cost_s = 0; var cost_i = 0
	var scene_path = ""
	var b_name = ""
	
	if build_goal == 0:
		cost_w = 5; cost_s = 5; scene_path = "res://scenes/turret.tscn"; b_name = "라이벌 기관총"
	elif build_goal == 1:
		cost_w = 8; cost_s = 12; cost_i = 2; scene_path = "res://scripts/shotgun_turret.gd"; b_name = "라이벌 샷건"
	elif build_goal == 2:
		cost_w = 10; cost_s = 10; cost_i = 2; scene_path = "res://scripts/sniper_turret.gd"; b_name = "라이벌 스나이퍼"
	elif build_goal == 3:
		cost_w = 15; cost_s = 15; cost_i = 5; scene_path = "res://scripts/missile_turret.gd"; b_name = "라이벌 미사일"
	elif build_goal == 4:
		cost_w = 20; cost_s = 20; cost_i = 10; scene_path = "res://scripts/laser_turret.gd"; b_name = "라이벌 레이저"
	elif build_goal == 5:
		cost_w = 15; cost_s = 15; cost_i = 5; scene_path = "res://scripts/processor.gd"; b_name = "라이벌 가공소"
		
	if inventory.get("wood", 0) >= cost_w and inventory.get("stone", 0) >= cost_s and inventory.get("iron", 0) >= cost_i:
		var empty_spots = []
		for x in range(-max_grid, max_grid + 1):
			for y in range(-max_grid, max_grid + 1):
				var pos = Vector2i(x, y)
				if not floor_grid.has(pos):
					empty_spots.append(pos)
					
		if empty_spots.size() > 0:
			inventory["wood"] -= cost_w
			inventory["stone"] -= cost_s
			if cost_i > 0: inventory["iron"] -= cost_i
			
			var spot = empty_spots[randi() % empty_spots.size()]
			var turret
			if build_goal == 5:
				var refinery_script = preload("res://scripts/processor.gd")
				turret = refinery_script.new()
				has_refinery = true
			else:
				if scene_path.ends_with(".tscn"):
					var turret_scene = load(scene_path)
					turret = turret_scene.instantiate()
				else:
					var turret_script = preload("res://scripts/turret.gd") # fallback
					if scene_path == "res://scripts/shotgun_turret.gd": turret_script = preload("res://scripts/shotgun_turret.gd")
					elif scene_path == "res://scripts/sniper_turret.gd": turret_script = preload("res://scripts/sniper_turret.gd")
					elif scene_path == "res://scripts/missile_turret.gd": turret_script = preload("res://scripts/missile_turret.gd")
					elif scene_path == "res://scripts/laser_turret.gd": turret_script = preload("res://scripts/laser_turret.gd")
					turret = turret_script.new()
			
			turret.position = Vector2(spot.x * 64, spot.y * 64)
			turret.set_meta("b_name", b_name)
			if "target_groups" in turret:
				turret.target_groups = ["player", "enemy"]
				
			add_child(turret)
			floor_grid[spot] = turret
			
			pick_new_goal()

func pick_new_goal():
	var rand = randf()
	if not has_refinery:
		# 가공소가 없으면 기본 타워나 가공소만 건설
		if rand < 0.5: build_goal = 0 # 기관총
		elif rand < 0.7: build_goal = 1 # 샷건
		elif rand < 0.9: build_goal = 2 # 스나이퍼
		else: build_goal = 5 # 가공소 (10%)
	else:
		# 가공소가 있으면 고급 타워 건설 가능
		if rand < 0.3: build_goal = 0
		elif rand < 0.5: build_goal = 1
		elif rand < 0.7: build_goal = 2
		elif rand < 0.85: build_goal = 3 # 미사일 (15%)
		else: build_goal = 4 # 레이저 (15%)

func take_damage(amount, type="normal"):
	hp -= amount
	health_fill.anchor_right = max(0.0, hp / max_hp)
	
	if hp <= 0:
		die()

func die():
	var num_turrets = floor_grid.size()
	var wood_drop = 10 + num_turrets * 5
	var stone_drop = 10 + num_turrets * 5
	var core_drop = num_turrets * 2
	
	# 자원 드랍 (임시로 플레이어 인벤토리에 바로 지급)
	if is_instance_valid(GameManager.player) and not GameManager.player.is_queued_for_deletion():
		GameManager.player.add_item("wood", wood_drop)
		GameManager.player.add_item("stone", stone_drop)
		if core_drop > 0: GameManager.player.add_item("monster_core", core_drop)
		# 알림 표시 등 추가 가능
		print("라이벌 요새 파괴! 보상 지급됨: 나무 ", wood_drop, ", 돌 ", stone_drop, ", 코어 ", core_drop)
	
	queue_free()
	
	# 폭발 이펙트
	var effect = CPUParticles2D.new()
	effect.emitting = true
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.amount = 100
	effect.lifetime = 1.0
	effect.spread = 180.0
	effect.initial_velocity_min = 200.0
	effect.initial_velocity_max = 500.0
	effect.scale_amount_min = 10.0
	effect.scale_amount_max = 20.0
	effect.color = Color(1.0, 0.2, 0.0)
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	effect.scale_amount_curve = curve
	
	effect.global_position = global_position
	get_tree().current_scene.add_child(effect)
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
	
	queue_free()

func get_save_data() -> Dictionary:
	var data = {
		"hp": hp,
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"inventory": inventory.duplicate(),
		"build_goal": build_goal,
		"has_refinery": has_refinery,
		"buildings": []
	}
	
	for pos in floor_grid.keys():
		var b = floor_grid[pos]
		if is_instance_valid(b):
			var b_name = b.get_meta("b_name") if b.has_meta("b_name") else ""
			data["buildings"].append({
				"x": pos.x,
				"y": pos.y,
				"b_name": b_name
			})
		
	return data

func load_save_data(data: Dictionary):
	hp = data.get("hp", max_hp)
	global_position = Vector2(data.get("pos_x", global_position.x), data.get("pos_y", global_position.y))
	inventory = data.get("inventory", {"wood": 0, "stone": 0, "iron": 0, "monster_core": 0})
	build_goal = data.get("build_goal", -1)
	has_refinery = data.get("has_refinery", false)
	health_fill.anchor_right = max(0.0, hp / max_hp)
	
	if data.has("buildings"):
		var b_map = {
			"라이벌 기관총": "res://scenes/turret.tscn",
			"라이벌 샷건": "res://scripts/shotgun_turret.gd",
			"라이벌 스나이퍼": "res://scripts/sniper_turret.gd",
			"라이벌 미사일": "res://scripts/missile_turret.gd",
			"라이벌 레이저": "res://scripts/laser_turret.gd",
			"라이벌 가공소": "res://scripts/processor.gd"
		}
		for b_data in data["buildings"]:
			var pos = Vector2i(b_data["x"], b_data["y"])
			var b_name = b_data["b_name"]
			var scene_path = b_map.get(b_name, "")
			
			if scene_path != "":
				var turret = null
				if scene_path.ends_with(".tscn"):
					turret = load(scene_path).instantiate()
				else:
					if b_name == "라이벌 가공소": turret = preload("res://scripts/processor.gd").new()
					elif b_name == "라이벌 샷건": turret = preload("res://scripts/shotgun_turret.gd").new()
					elif b_name == "라이벌 스나이퍼": turret = preload("res://scripts/sniper_turret.gd").new()
					elif b_name == "라이벌 미사일": turret = preload("res://scripts/missile_turret.gd").new()
					elif b_name == "라이벌 레이저": turret = preload("res://scripts/laser_turret.gd").new()
					
				if turret:
					turret.position = Vector2(pos.x * 64, pos.y * 64)
					turret.set_meta("b_name", b_name)
					if "target_groups" in turret: turret.target_groups = ["player", "enemy"]
					add_child(turret)
					floor_grid[pos] = turret
