extends CharacterBody2D

var speed = 30.0
var hp = 100.0
var max_hp = 100.0
var wave_level = 1
var is_dead = false

var armor_type = "heavy"
var state = "APPROACH" # "APPROACH", "AIMING", "FIRING"

var aim_timer = 0.0
var aim_duration = 3.0
var attack_cooldown = 0.0
var target_building = null
var target_pos = Vector2()

var warning_line = null
var sprite = null
var shield_sprite = null
var shield_active = true

var dropped_scene = preload("res://scenes/dropped_item.tscn")

func _ready():
	add_to_group("enemy")
	add_to_group("boss")
	
	collision_layer = 2
	collision_mask = 1 | 2
	
	# 몸체 렌더링
	sprite = Node2D.new()
	add_child(sprite)
	
	var base = ColorRect.new()
	base.size = Vector2(80, 80)
	base.position = Vector2(-40, -40)
	base.color = Color(0.3, 0.3, 0.35) # 육중한 회색/검은색
	sprite.add_child(base)
	
	var gun = ColorRect.new()
	gun.size = Vector2(60, 20)
	gun.position = Vector2(20, -10)
	gun.color = Color(0.1, 0.1, 0.1) # 대포
	sprite.add_child(gun)
	
	var hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(80, 8)
	hp_bar_bg.position = Vector2(-40, -55)
	hp_bar_bg.color = Color(1, 0, 0)
	hp_bar_bg.name = "HpBg"
	add_child(hp_bar_bg)
	
	var hp_bar_fg = ColorRect.new()
	hp_bar_fg.size = Vector2(80, 8)
	hp_bar_fg.position = Vector2(-40, -55)
	hp_bar_fg.color = Color(0, 1, 0)
	hp_bar_fg.name = "HpFg"
	add_child(hp_bar_fg)
	
	# 전면 쉴드 렌더링
	shield_sprite = Polygon2D.new()
	shield_sprite.color = Color(0.2, 0.8, 1.0, 0.5) # 반투명한 푸른색
	var points = PackedVector2Array()
	var segments = 16
	for i in range(segments + 1):
		var angle = -PI/2 + (PI/segments) * i
		points.append(Vector2(cos(angle), sin(angle)) * 60.0)
	points.append(Vector2(0, 0))
	shield_sprite.polygon = points
	sprite.add_child(shield_sprite)
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	add_child(shape)
	
	warning_line = Line2D.new()
	warning_line.width = 4.0
	warning_line.default_color = Color(1.0, 0.0, 0.0, 0.0) # 평소엔 투명
	get_tree().current_scene.call_deferred("add_child", warning_line)

func setup(wave: int):
	wave_level = wave
	max_hp = 3000 + wave * 500
	hp = max_hp
	speed = 30.0 + wave * 0.5

func _physics_process(delta):
	var player = GameManager.player
	if not is_instance_valid(player):
		return
		
	var to_player = global_position.direction_to(player.global_position)
	sprite.rotation = lerp_angle(sprite.rotation, to_player.angle(), 5.0 * delta)
	
	# 상태 머신
	if state == "APPROACH":
		velocity = to_player * speed
		if "frost_slow" in self:
			velocity *= (1.0 - get_meta("frost_slow"))
		move_and_slide()
		
		attack_cooldown -= delta
		if attack_cooldown <= 0.0 and global_position.distance_to(player.global_position) < 800.0:
			# 요새 타겟팅 시작
			target_building = get_random_building()
			if target_building:
				state = "AIMING"
				aim_timer = aim_duration
				target_pos = target_building.global_position
			else:
				# 건물이 없으면 본체 타겟팅
				state = "AIMING"
				aim_timer = aim_duration
				target_pos = player.global_position
				
	elif state == "AIMING":
		velocity = Vector2.ZERO # 조준 중 이동 불가
		aim_timer -= delta
		
		# EMP 반경 400 조준 연출
		if is_instance_valid(warning_line):
			warning_line.clear_points()
			if is_instance_valid(target_building):
				target_pos = target_building.global_position
			
			var segments = 32
			for i in range(segments + 1):
				var angle = (PI * 2.0 / segments) * i
				warning_line.add_point(target_pos + Vector2(cos(angle), sin(angle)) * 400.0)
				
			var alpha = 1.0 - (aim_timer / aim_duration)
			warning_line.default_color = Color(0.2, 0.5, 1.0, alpha)
			
		if aim_timer <= 0:
			fire_artillery()
			state = "APPROACH"
			attack_cooldown = 12.0
			if is_instance_valid(warning_line):
				warning_line.default_color = Color(1.0, 0.0, 0.0, 0.0)
				
	# 슬로우 해제 로직
	if has_meta("frost_timer"):
		var t = get_meta("frost_timer")
		t -= delta
		if t <= 0:
			remove_meta("frost_timer")
			remove_meta("frost_slow")
		else:
			set_meta("frost_timer", t)

func get_random_building() -> Node2D:
	var player = GameManager.player
	if not is_instance_valid(player): return null
	
	var buildings = []
	for f in player.floor_grids.keys():
		for pos in player.floor_grids[f].keys():
			var b = player.floor_grids[f][pos]
			if is_instance_valid(b):
				buildings.append(b)
				
	if buildings.size() > 0:
		return buildings[randi() % buildings.size()]
	return null

func fire_artillery():
	# EMP 시각 효과
	var effect = CPUParticles2D.new()
	effect.emitting = true
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.amount = 150
	effect.lifetime = 0.8
	effect.spread = 180.0
	effect.initial_velocity_min = 300.0
	effect.initial_velocity_max = 500.0
	effect.color = Color(0.2, 0.8, 1.0)
	effect.global_position = target_pos
	get_tree().current_scene.add_child(effect)
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
	
	# 반경 400 내의 건물들에 EMP 효과 적용
	var player = GameManager.player
	if is_instance_valid(player):
		for f in player.floor_grids.keys():
			for pos in player.floor_grids[f].keys():
				var b = player.floor_grids[f][pos]
				if is_instance_valid(b) and b.global_position.distance_to(target_pos) <= 400.0:
					apply_emp_to_building(b, 5.0)
					
func apply_emp_to_building(b: Node2D, duration: float):
	if not is_instance_valid(b): return
	if not b.has_meta("emp_disabled"):
		b.set_meta("emp_disabled", true)
		if "laser_beam" in b and is_instance_valid(b.laser_beam):
			b.laser_beam.visible = false
			
		b.process_mode = Node.PROCESS_MODE_DISABLED
		b.modulate = Color(0.3, 0.4, 0.8)
		
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(GameManager.clear_emp.bind(b))

func take_damage(amount, attack_type="normal", attacker_pos=Vector2.ZERO):
	var dmg = amount
	if armor_type == "heavy" and attack_type == "kinetic":
		dmg *= 0.5
		
	# 전면 쉴드 로직
	if shield_active and attacker_pos != Vector2.ZERO:
		var to_attacker = (attacker_pos - global_position).angle()
		var face_angle = sprite.global_rotation
		if abs(angle_difference(face_angle, to_attacker)) < PI/2:
			# 앞면에서 맞았을 경우 폭발이나 레이저가 아니면 데미지 대폭 감소
			if attack_type != "explosive" and attack_type != "energy":
				dmg *= 0.2
	
	hp -= dmg
	if has_node("HpFg"):
		var fg = get_node("HpFg")
		fg.size.x = max(0, (hp / max_hp) * 80)
		
	# 데미지 플로팅 텍스트
	var dmg_label = Label.new()
	dmg_label.text = str(int(dmg))
	dmg_label.position = global_position + Vector2(randf_range(-20, 20), -40)
	var settings = LabelSettings.new()
	settings.font_color = Color(1.0, 1.0, 1.0)
	if attack_type == "energy": settings.font_color = Color(1.0, 0.5, 1.0)
	if attack_type == "explosive": settings.font_color = Color(1.0, 0.5, 0.0)
	if attack_type == "kinetic" and shield_active and dmg < amount * 0.3: settings.font_color = Color(0.5, 0.5, 0.5) # Blocked
	dmg_label.label_settings = settings
	get_tree().current_scene.add_child(dmg_label)
	
	var tw = get_tree().create_tween()
	tw.tween_property(dmg_label, "position:y", dmg_label.position.y - 50, 0.5)
	tw.tween_property(dmg_label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(dmg_label.queue_free)
	
	if hp <= 0:
		die()

func die():
	if is_dead: return
	is_dead = true
	
	var mat_drop_count = randi_range(20, 30)
	for i in range(mat_drop_count):
		var item = dropped_scene.instantiate()
		item.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		item.set("item_type", "steel_plate" if randf() < 0.3 else "stone")
		get_tree().current_scene.add_child(item)
		
	# 모듈 확정 드랍
	var module_drop = dropped_scene.instantiate()
	module_drop.global_position = global_position
	var mod_types = ["mod_explosive", "mod_multishot", "mod_frost"]
	module_drop.set("item_type", mod_types[randi() % mod_types.size()])
	get_tree().current_scene.add_child(module_drop)
	
	if is_instance_valid(warning_line):
		warning_line.queue_free()
		
	if is_instance_valid(GameManager.player):
		if GameManager.player.has_method("show_upgrade_selection"):
			GameManager.player.show_upgrade_selection()
			
	queue_free()

func _exit_tree():
	if is_instance_valid(warning_line):
		warning_line.queue_free()
