extends CharacterBody2D

var hp = 1
var max_hp = 1
var wave_level = 1
var speed = 20.0
var is_dead = false

var armor_type = "medium"
var state = "IDLE"
var attack_timer = 5.0

var laser_beams = []
var warning_beams = []

@onready var sprite = null

func _ready():
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 0
	
	var shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(120, 120)
	shape.shape = rect_shape
	add_child(shape)
	
	sprite = Node2D.new()
	add_child(sprite)
	
	var body = ColorRect.new()
	body.size = Vector2(120, 120)
	body.position = Vector2(-60, -60)
	body.color = Color(1.0, 0.5, 0.0) # 주황색 눈알 느낌
	sprite.add_child(body)
	
	var eye = ColorRect.new()
	eye.size = Vector2(50, 50)
	eye.position = Vector2(-25, -25)
	eye.color = Color(1.0, 1.0, 0.0) # 노란색 눈동자
	sprite.add_child(eye)
	
	for i in range(3):
		var laser = ColorRect.new()
		laser.size = Vector2(1500, 40)
		laser.color = Color(1.0, 0.0, 0.0, 0.8) # 두꺼운 빨간 레이저
		laser.visible = false
		get_tree().current_scene.call_deferred("add_child", laser)
		laser_beams.append(laser)
		
		var warn = ColorRect.new()
		warn.size = Vector2(1500, 4)
		warn.color = Color(1.0, 0.0, 0.0, 0.3) # 반투명 빨간색 (경고)
		warn.visible = false
		get_tree().current_scene.call_deferred("add_child", warn)
		warning_beams.append(warn)

func setup(wave: int):
	wave_level = wave
	# 체력 적당히 상향
	max_hp = 200 + (wave * 100) + int(pow(1.15, wave) * 30.0)
	hp = max_hp
	speed = 20.0 + (wave * 1.5)

func _physics_process(delta):
	if is_dead: return
	if not is_instance_valid(GameManager.player): return
	
	var target_pos = GameManager.player.global_position
	var dist = global_position.distance_to(target_pos)
	
	if state == "IDLE":
		# 요새와 일정 거리 유지
		var direction = Vector2.ZERO
		if dist > 500:
			direction = global_position.direction_to(target_pos)
		elif dist < 300:
			direction = target_pos.direction_to(global_position)
			
		velocity = direction * speed
		move_and_slide()
		
		# 회전
		var target_angle = (target_pos - global_position).angle()
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 5.0 * delta)
		
		attack_timer -= delta
		if attack_timer <= 0:
			fire_laser_pattern()
	elif state == "FIRING":
		for laser_beam in laser_beams:
			if not is_instance_valid(laser_beam): continue
			if not laser_beam.visible: continue
			
			# 레이저 발사 중 지속 데미지
			var end_pos = global_position + Vector2(1500, 0).rotated(laser_beam.rotation)
			laser_beam.global_position = global_position + Vector2(40, -20).rotated(laser_beam.rotation)
			
			# 레이저 범위에 플레이어가 닿았는지 체크 (대략적 선분과 점 거리 계산)
			var p_pos = GameManager.player.global_position
			var p1 = global_position
			var p2 = end_pos
			
			var l2 = p1.distance_squared_to(p2)
			if l2 > 0:
				var t = max(0, min(1, (p_pos - p1).dot(p2 - p1) / l2))
				var proj = p1 + t * (p2 - p1)
				if p_pos.distance_to(proj) < 100.0: # 레이저 두께 판정
					GameManager.player.take_damage(20.0 * delta) # 매우 아픈 틱뎀
					# 레이저가 요새의 건물을 파괴할 수도 있음 (확률적)
					if randf() < 0.1:
						GameManager.player.destroy_buildings_in_radius(proj, 40.0)

func fire_laser_pattern():
	state = "WINDUP"
	
	var num_lasers = 1
	if wave_level >= 5: num_lasers = 2
	if wave_level >= 8: num_lasers = 3
	
	# 모으기 이펙트 및 경고선 표시
	sprite.modulate = Color(3, 3, 0)
	for i in range(num_lasers):
		if is_instance_valid(warning_beams[i]):
			var offset_angle = 0.0
			if num_lasers == 2:
				offset_angle = (i - 0.5) * (PI / 6.0) # 30도 간격
			elif num_lasers == 3:
				offset_angle = (i - 1.0) * (PI / 6.0) # 30도 간격
			
			warning_beams[i].rotation = sprite.global_rotation + offset_angle
			warning_beams[i].global_position = global_position + Vector2(40, -2).rotated(warning_beams[i].rotation)
			warning_beams[i].visible = true
		
	await get_tree().create_timer(1.5).timeout
	if is_dead: return
	
	state = "FIRING"
	sprite.modulate = Color(1, 1, 1)
	
	for i in range(num_lasers):
		if is_instance_valid(warning_beams[i]): warning_beams[i].visible = false
		if is_instance_valid(laser_beams[i]):
			var offset_angle = 0.0
			if num_lasers == 2: offset_angle = (i - 0.5) * (PI / 6.0)
			elif num_lasers == 3: offset_angle = (i - 1.0) * (PI / 6.0)
			
			laser_beams[i].rotation = sprite.global_rotation + offset_angle
			laser_beams[i].global_position = global_position + Vector2(40, -20).rotated(laser_beams[i].rotation)
			laser_beams[i].visible = true
	
	# 카메라 쉐이크
	if is_instance_valid(GameManager.player) and GameManager.player.has_method("add_camera_shake"):
		GameManager.player.add_camera_shake(15.0)
		
	await get_tree().create_timer(1.5).timeout
	if is_dead: return
	
	for beam in laser_beams:
		if is_instance_valid(beam): beam.visible = false
		
	state = "IDLE"
	attack_timer = max(3.0, 6.0 - wave_level * 0.1)

func take_damage(amount, attack_type = "normal"):
	var mult = 1.0
	if attack_type == "kinetic": mult = 0.75
	elif attack_type == "piercing": mult = 1.0
	elif attack_type == "scatter": mult = 1.0
	elif attack_type == "explosive": mult = 1.0
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
	
	for beam in laser_beams:
		if is_instance_valid(beam): beam.queue_free()
	for beam in warning_beams:
		if is_instance_valid(beam): beam.queue_free()
		
	if is_instance_valid(GameManager.player):
		if GameManager.player.has_method("show_upgrade_selection"):
			GameManager.player.show_upgrade_selection()
		GameManager.player.add_item("monster_core", 80)
		GameManager.player.add_item("steel_plate", 30)
			
	queue_free()

func _exit_tree():
	for beam in laser_beams:
		if is_instance_valid(beam): beam.queue_free()
	for beam in warning_beams:
		if is_instance_valid(beam): beam.queue_free()
