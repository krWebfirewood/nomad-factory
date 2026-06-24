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
	max_hp = 100 + (wave * 50)
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
		if dash_timer <= 0:
			state = "WINDUP"
			windup_timer = 1.5
			dash_direction = direction
			warning_line.points = PackedVector2Array([Vector2.ZERO, dash_direction * 1500.0])
			warning_line.visible = true
			velocity = Vector2.ZERO
			
		# 광역 포격(AoE) 패턴은 대쉬를 안 할 때만 발동
		aoe_timer -= delta
		if aoe_timer <= 0:
			aoe_timer = aoe_rate
			fire_aoe_bomb()
			# 포격과 대쉬가 겹치지 않게 대쉬 쿨타임을 최소 2.5초 연장
			dash_timer = max(dash_timer, 2.5)
			
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
	
	# 플레이어 위치 근처로 조준 (완전 유도 방지)
	var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
	bomb.global_position = GameManager.player.global_position + offset
	get_tree().current_scene.add_child(bomb)

func take_damage(amount):
	hp -= amount
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
	
	if is_instance_valid(GameManager.player):
		# 보스 처치 보상
		GameManager.player.add_item("monster_core", 50)
		GameManager.player.add_item("wood", 20)
		GameManager.player.add_item("stone", 20)
		
		# 트레일러(보조 거점) 획득!
		if GameManager.player.has_method("add_floor"):
			GameManager.player.add_floor()
			print("=== 거대 보스 처치! 보조 거점을 획득했습니다! ===")
			
	queue_free()
