extends CharacterBody2D

var speed = 100.0
var hp = 1
var max_hp = 1
var enemy_type = 0 # 0: 일반, 1: 스워머, 2: 탱커, 3: 스피터
var armor_type = "medium" # "light", "medium", "heavy"
var exploded = false

var shoot_timer = 0.0

func setup(wave: int, type: int = 0):
	enemy_type = type
	var sprite_node = get_node_or_null("Sprite2D")
	
	if enemy_type == 1: # 스워머 (빠르고 체력 낮음)
		armor_type = "light"
		max_hp = 1 + int(wave / 4.0)
		speed = 150.0 + (wave * 5.0)
		if sprite_node:
			sprite_node.modulate = Color(1.0, 0.5, 0.0)
			sprite_node.scale = Vector2(0.4, 0.4)
			
	elif enemy_type == 2: # 탱커 (느리고 체력 높음, 크기 큼)
		armor_type = "heavy"
		max_hp = 5 + int(wave * 1.5)
		speed = 50.0 + (wave * 2.0)
		if sprite_node:
			sprite_node.modulate = Color(0.3, 0.3, 0.3)
			sprite_node.scale = Vector2(1.0, 1.0)
			
	elif enemy_type == 3: # 스피터 (원거리)
		armor_type = "medium"
		max_hp = 2 + int(wave / 3.0)
		speed = 80.0 + (wave * 3.0)
		if sprite_node:
			sprite_node.modulate = Color(0.0, 1.0, 0.0)
			sprite_node.scale = Vector2(0.5, 0.5)
			
	else: # 일반
		armor_type = "medium"
		max_hp = 1 + int(wave / 2.0)
		speed = 100.0 + (wave * 4.0)
		
	hp = max_hp

func _physics_process(delta):
	if exploded: return
	
	var target_pos = global_position
	var dist_to_target = 0.0
	
	if is_instance_valid(GameManager.player):
		target_pos = GameManager.player.global_position
		dist_to_target = global_position.distance_to(target_pos)
		
	var direction = global_position.direction_to(target_pos)
	
	if enemy_type == 3 and dist_to_target < 400.0:
		# 스피터: 거리가 400 이하로 가까워지면 멈춰서 쏜다
		velocity = Vector2.ZERO
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_timer = 2.0
			shoot_projectile(direction)
	else:
		velocity = direction * speed
		
	move_and_slide()
	
	# 요새(플레이어) 충돌 및 자폭 로직
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider != null:
			if collider.is_in_group("player") or collider.is_in_group("trailer"):
				if collider.has_method("take_damage"):
					var dmg = max_hp
					if enemy_type == 2: dmg *= 3 # 탱커 충돌 피해량 3배
					collider.take_damage(dmg)
				exploded = true
				queue_free()
				break

func shoot_projectile(dir: Vector2):
	var proj_script = preload("res://scripts/enemy_projectile.gd")
	var proj = proj_script.new()
	proj.global_position = global_position
	proj.direction = dir
	get_tree().current_scene.add_child(proj)

var is_dead = false

func take_damage(amount, attack_type = "normal"):
	if is_dead: return
	
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
			
	var sprite_node = get_node_or_null("Sprite2D")
	
	if sprite_node:
		var orig_color = Color(1, 1, 1)
		if enemy_type == 1: orig_color = Color(0.8, 0.2, 0.2)
		elif enemy_type == 2: orig_color = Color(0.5, 0.5, 0.8)
		elif enemy_type == 3: orig_color = Color(0.8, 0.8, 0.2)
		
		sprite_node.modulate = Color(5, 5, 5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and is_instance_valid(sprite_node):
			sprite_node.modulate = orig_color
			
	if hp <= 0:
		is_dead = true
		var core_amount = 1
		if enemy_type == 2: core_amount = 3
		
		var dropped_item_scene = preload("res://scenes/dropped_item.tscn")
		for i in range(core_amount):
			var drop = dropped_item_scene.instantiate()
			drop.global_position = global_position
			drop.set("item_type", "monster_core")
			get_tree().current_scene.add_child.call_deferred(drop)
			
		# 추가 자원 드랍 (20% 확률)
		if randf() < 0.2:
			var extra_drop = dropped_item_scene.instantiate()
			extra_drop.global_position = global_position
			extra_drop.set("item_type", "wood" if randf() < 0.5 else "stone")
			get_tree().current_scene.add_child.call_deferred(extra_drop)
			
		queue_free()
