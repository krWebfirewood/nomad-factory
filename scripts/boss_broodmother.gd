extends CharacterBody2D

var hp = 1
var max_hp = 1
var wave_level = 1
var speed = 120.0
var is_dead = false

var armor_type = "light"
var state = "IDLE"
var spawn_timer = 0.5
var change_dir_timer = 2.0
var move_dir = Vector2.RIGHT

var enemy_scene = preload("res://scenes/enemy.tscn")
@onready var sprite = null

func _ready():
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 0
	
	var shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 70.0
	shape.shape = circle_shape
	add_child(shape)
	
	sprite = Node2D.new()
	add_child(sprite)
	
	var body = ColorRect.new()
	body.size = Vector2(140, 140)
	body.position = Vector2(-70, -70)
	body.color = Color(0.2, 0.8, 0.2) # 밝은 초록색 독거미 느낌
	sprite.add_child(body)

func setup(wave: int):
	wave_level = wave
	# 체력 적당히 상향
	max_hp = 150 + (wave * 80) + int(pow(1.15, wave) * 30.0)
	hp = max_hp
	speed = 80.0 + (wave * 3.0)

func _physics_process(delta):
	if is_dead: return
	if not is_instance_valid(GameManager.player): return
	
	var target_pos = GameManager.player.global_position
	
	change_dir_timer -= delta
	if change_dir_timer <= 0:
		change_dir_timer = randf_range(1.0, 3.0)
		# 플레이어 주변을 빙빙 돎
		move_dir = global_position.direction_to(target_pos).rotated(PI/2 * (1 if randf() > 0.5 else -1))
	
	# 요새와 거리가 너무 멀어지면 다가옴
	if global_position.distance_to(target_pos) > 600:
		move_dir = global_position.direction_to(target_pos)
		
	velocity = move_dir * speed
	move_and_slide()
		
	# 스워머 지속 소환
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = max(0.2, 1.0 - wave_level * 0.02)
		spawn_swarmer()

func spawn_swarmer():
	var enemy = enemy_scene.instantiate()
	enemy.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	if enemy.has_method("setup"):
		enemy.setup(wave_level, 1) # 1: 스워머
	get_tree().current_scene.add_child(enemy)

func take_damage(amount, attack_type = "normal"):
	var mult = 1.0
	if attack_type == "kinetic": mult = 1.0
	elif attack_type == "piercing": mult = 0.5
	elif attack_type == "scatter": mult = 1.5
	elif attack_type == "explosive": mult = 0.5
	elif attack_type == "energy": mult = 1.0
	
	hp -= amount * mult
	if sprite:
		var orig_color = Color(1, 1, 1, 1)
		sprite.modulate = Color(5, 5, 5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and sprite:
			sprite.modulate = orig_color
			
	if hp <= 0:
		die()

func die():
	if is_dead: return
	is_dead = true
	
	if is_instance_valid(GameManager.player):
		if GameManager.player.has_method("show_upgrade_selection"):
			GameManager.player.show_upgrade_selection()
		GameManager.player.add_item("monster_core", 60)
		GameManager.player.add_item("wood", 50)
			
	queue_free()
