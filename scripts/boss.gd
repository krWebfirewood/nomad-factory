extends CharacterBody2D

var speed = 40.0
var hp = 100
var max_hp = 100
var wave_level = 1

var spawn_timer = 5.0
var dash_timer = 5.0
var dash_speed = 800.0
var dash_duration = 0.8
var damage_cooldown = 0.0

var armor_type = "heavy"

var state = "IDLE" # "IDLE", "WINDUP", "DASH"
var windup_timer = 0.0
var dash_direction = Vector2()
var warning_line = null

var aoe_timer = 5.0
var aoe_rate = 8.0

var enemy_scene = preload("res://scenes/enemy.tscn")

@onready var sprite = null

func _ready():
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 3
	GameManager.boss = self
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 80.0
	col.shape = shape
	add_child(col)
	
	sprite = Node2D.new()
	add_child(sprite)
	
	var rect = ColorRect.new()
	rect.size = Vector2(160, 160)
	rect.position = Vector2(-80, -80)
	rect.color = Color(0.5, 0.0, 0.5, 1.0) # 보라색 거대 보스
	sprite.add_child(rect)
	
	warning_line = Line2D.new()
	warning_line.width = 15.0
	warning_line.default_color = Color(1.0, 0.0, 0.0, 0.6)
	warning_line.visible = false
	add_child(warning_line)

func setup(wave: int):
	wave_level = wave
	# 체력 적당히 상향
	max_hp = 300 + (wave * 120) + int(pow(1.15, wave) * 50.0)
	hp = max_hp
	speed = 30.0 + (wave * 2.0)

func _physics_process(delta):
	var target_pos = global_position
	if is_instance_valid(GameManager.player):
		target_pos = GameManager.player.global_position
		
	var direction = global_position.direction_to(target_pos)
	var dist = global_position.distance_to(target_pos)
	
	if state == "IDLE":
		warning_line.visible = false
		if dist < 300.0:
			velocity = -direction * speed * 1.5
		else:
			velocity = velocity.move_toward(direction * speed, 10.0)
			
		dash_timer -= delta
		aoe_timer -= delta
		
		# 광역 포격(AoE) 패턴 우선 발동 (타이머가 다 되었을 경우)
		if aoe_timer <= 0:
			aoe_timer = aoe_rate
			fire_aoe_bomb()
			# 포격과 대쉬가 겹치지 않게 대쉬 쿨타임을 최소 2.5초 연장
			dash_timer = max(dash_timer, 2.5)
			
		elif dash_timer <= 0:
			state = "WINDUP"
			windup_timer = 1.5
			dash_direction = direction
			warning_line.points = PackedVector2Array([Vector2.ZERO, dash_direction * 1500.0])
			warning_line.visible = true
			velocity = Vector2.ZERO
			
	elif state == "WINDUP":
		velocity = Vector2.ZERO
		windup_timer -= delta
		# 선 깜빡임 효과
		warning_line.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 50.0)
		if windup_timer <= 0:
			state = "DASH"
			dash_duration = 0.8
			warning_line.visible = false
			
	elif state == "DASH":
		velocity = dash_direction * dash_speed
		dash_duration -= delta
		if dash_duration <= 0:
			state = "IDLE"
			dash_timer = 8.0
			
	move_and_slide()
	
	# 산란 패턴
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = 6.0
		spawn_minions()
	
	# 충돌 (플레이어에게 데미지)
	damage_cooldown -= delta
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider != null:
			if collider.is_in_group("player") or collider.is_in_group("trailer"):
				if damage_cooldown <= 0:
					if collider.has_method("take_damage"):
						collider.take_damage(30) # 보스는 충돌 시 피해를 줌
						damage_cooldown = 0.5 # 0.5초마다 데미지
						if collider.has_method("add_camera_shake"):
							collider.add_camera_shake(15.0) # 대쉬/몸통 박치기 피격 시 약간의 화면 흔들림
						
				# 부딪히면 대쉬 취소 후 즉시 튕겨냄
				if state == "DASH" or state == "WINDUP":
					state = "IDLE"
					dash_timer = 5.0
					warning_line.visible = false
				velocity = -direction * speed * 3.0
					
func spawn_minions():
	# 스워머(1) 3마리 스폰
	for i in range(3):
		var enemy = enemy_scene.instantiate()
		enemy.global_position = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		if enemy.has_method("setup"):
			enemy.setup(wave_level, 1)
		get_tree().current_scene.add_child(enemy)

func fire_aoe_bomb():
	if not is_instance_valid(GameManager.player): return
	
	var bomb_script = preload("res://scripts/aoe_bomb.gd")
	var bomb = bomb_script.new()
	
	# 폭발까지 걸리는 시간 (기본 2.5초, 웨이브에 따라 최소 1.5초까지 단축)
	var bomb_lifetime = max(1.5, 2.5 - (wave_level * 0.05))
	bomb.set("lifetime", bomb_lifetime)
	
	# 플레이어 위치 근처로 조준 (완전 유도 방지)
	var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
	bomb.global_position = GameManager.player.global_position + offset
	get_tree().current_scene.add_child(bomb)

func take_damage(amount, attack_type = "normal"):
	var mult = 1.0
	if attack_type == "kinetic":
		if armor_type == "light": mult = 1.0
		elif armor_type == "medium": mult = 0.75
		elif armor_type == "heavy": mult = 0.5
	elif attack_type == "piercing":
		if armor_type == "light": mult = 0.5
		elif armor_type == "medium": mult = 1.0
		elif armor_type == "heavy": mult = 1.5
	elif attack_type == "scatter":
		if armor_type == "light": mult = 1.5
		elif armor_type == "medium": mult = 1.0
		elif armor_type == "heavy": mult = 0.5
	elif attack_type == "explosive":
		if armor_type == "light": mult = 0.5
		elif armor_type == "medium": mult = 1.0
		elif armor_type == "heavy": mult = 1.5
	elif attack_type == "energy":
		mult = 1.0
		
	hp -= amount * mult
	
	if is_instance_valid(GameManager.player) and GameManager.player.active_relics.get("vampire"):
		if randf() < 0.05:
			GameManager.player.hp = min(GameManager.player.max_hp, GameManager.player.hp + 1)
			
	if sprite:
		var orig_color = Color(0.5, 0.0, 0.5, 1.0)
		sprite.modulate = Color(5, 5, 5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and sprite:
			sprite.modulate = orig_color
			
	if hp <= 0:
		die()

var is_dead = false

func die():
	if is_dead: return
	is_dead = true
	
	# 도파민 폭발 연출: 슬로우 모션 및 카메라 쉐이크
	Engine.time_scale = 0.2
	if is_instance_valid(GameManager.player):
		if GameManager.player.has_method("add_camera_shake"):
			GameManager.player.add_camera_shake(30.0)
			
	# 폭발 깜빡임 이펙트
	for i in range(10):
		if is_instance_valid(sprite):
			sprite.modulate = Color(10, 10, 10) if i % 2 == 0 else Color(1, 0, 0)
		await get_tree().create_timer(0.1 * Engine.time_scale).timeout
		
	Engine.time_scale = 1.0
	
	# 전리품(코어) 대량 스폰
	var dropped_scene = preload("res://scenes/dropped_item.tscn")
	var drop_count = randi_range(30, 50)
	for i in range(drop_count):
		var item = dropped_scene.instantiate()
		item.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		item.set("item_type", "monster_core")
		get_tree().current_scene.add_child(item)
		
	var mat_drop_count = randi_range(15, 25)
	for i in range(mat_drop_count):
		var item = dropped_scene.instantiate()
		item.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var r = randf()
		var advanced_chance = min(0.5, wave_level * 0.05)
		if r < advanced_chance:
			item.set("item_type", "steel_plate")
		else:
			item.set("item_type", "wood" if randf() < 0.5 else "stone")
		get_tree().current_scene.add_child(item)
		
	# 모듈 드랍
	var module_drop = dropped_scene.instantiate()
	module_drop.global_position = global_position
	var mod_types = ["mod_explosive", "mod_multishot", "mod_frost"]
	module_drop.set("item_type", mod_types[randi() % mod_types.size()])
	get_tree().current_scene.add_child(module_drop)
	
	# 요새 증축 로직 대신 업그레이드 선택 UI 호출
	if is_instance_valid(GameManager.player):
		if GameManager.player.has_method("show_upgrade_selection"):
			GameManager.player.show_upgrade_selection()
			
	queue_free()
