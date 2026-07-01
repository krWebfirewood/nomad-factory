extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var floor_index = 1

var attack_timer = 0.0
var attack_rate = 0.25 # 너무 빠르면 잡몹을 다 지워버리므로 약간 낮춤
var target_enemy = null
var target_groups = ["enemy"]

@onready var sprite = null
@onready var laser_beam = null

func _ready():
	sprite = Node2D.new()
	add_child(sprite)
	
	var rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(40, 40)
	rect.position = Vector2(-20, -20)
	rect.color = Color(1.0, 0.0, 1.0, 1.0) # 보라색/마젠타색 타워
	sprite.add_child(rect)
	
	# 레이저 발사구
	var barrel = ColorRect.new()
	barrel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrel.size = Vector2(20, 10)
	barrel.position = Vector2(20, -5)
	barrel.color = Color(0.2, 0.8, 1.0, 1.0) # 하늘색 총구
	sprite.add_child(barrel)
	
	# 레이저 빔 (글로벌 씬에 부착하기 위해 분리)
	laser_beam = ColorRect.new()
	laser_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	laser_beam.size = Vector2(600, 4)
	laser_beam.color = Color(1.0, 0.2, 1.0, 0.8) # 투명한 분홍/보라 레이저
	laser_beam.visible = false

func _process(delta):
	if not is_instance_valid(laser_beam): return
	target_enemy = get_target_enemy()
	
	if is_instance_valid(target_enemy):
		var target_angle = (target_enemy.global_position - global_position).angle()
		# 잡몹(스워머) 처리에 취약하도록 회전(추적) 속도 대폭 하향
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 4.0 * delta)
		
		# 글로벌 좌표계에서 레이저 빔 렌더링
		if laser_beam.get_parent() == null:
			get_tree().current_scene.add_child(laser_beam)
		
		var dist = global_position.distance_to(target_enemy.global_position)
		laser_beam.global_position = global_position + Vector2(40, -2).rotated(sprite.global_rotation)
		laser_beam.rotation = sprite.global_rotation
		laser_beam.size.x = dist - 40
		laser_beam.visible = is_visible_in_tree()
		
		attack_timer -= delta
		if attack_timer <= 0:
			# 조준이 일정 각도 이내로 맞았을 때만 데미지를 주도록 수정
			if abs(angle_difference(sprite.global_rotation, target_angle)) < 0.2:
				if target_enemy.has_method("take_damage"):
					var level = get_meta("level") if has_meta("level") else 1
					var dmg = (5.0 + (level - 1) * 2.0 + (GameManager.upg_turret_damage_level * 2)) * GameManager.stat_damage_mult
					target_enemy.take_damage(dmg, "energy")
			attack_timer = attack_rate * GameManager.stat_firerate_mult
	else:
		laser_beam.visible = false

func _exit_tree():
	if is_instance_valid(laser_beam):
		laser_beam.queue_free()

func get_target_enemy():
	var targets = []
	for g in target_groups:
		targets.append_array(get_tree().get_nodes_in_group(g))
		
	var closest = null
	var min_dist = 400.0 * GameManager.stat_range_mult # 레이저 사거리
	
	for e in targets:
		if e.get("is_dead") == true: continue
		var dist = global_position.distance_to(e.global_position)
		if dist <= min_dist:
			min_dist = dist
			closest = e
	return closest
