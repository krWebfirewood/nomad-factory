extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var floor_index = 1

var attack_timer = 0.0
var attack_rate = 0.1 # 레이저: 매우 빠른 속도 (지속딜 느낌)
var target_enemy = null

@onready var sprite = null
@onready var laser_beam = null

func _ready():
	sprite = Node2D.new()
	add_child(sprite)
	
	var rect = ColorRect.new()
	rect.size = Vector2(40, 40)
	rect.position = Vector2(-20, -20)
	rect.color = Color(1.0, 0.0, 1.0, 1.0) # 보라색/마젠타색 타워
	sprite.add_child(rect)
	
	# 레이저 발사구
	var barrel = ColorRect.new()
	barrel.size = Vector2(20, 10)
	barrel.position = Vector2(20, -5)
	barrel.color = Color(0.2, 0.8, 1.0, 1.0) # 하늘색 총구
	sprite.add_child(barrel)
	
	# 레이저 빔 (평소엔 숨김)
	laser_beam = ColorRect.new()
	laser_beam.size = Vector2(600, 4)
	laser_beam.position = Vector2(40, -2)
	laser_beam.color = Color(1.0, 0.2, 1.0, 0.8) # 투명한 분홍/보라 레이저
	sprite.add_child(laser_beam)
	laser_beam.visible = false

func _process(delta):
	target_enemy = get_target_enemy()
	
	if is_instance_valid(target_enemy):
		var target_angle = (target_enemy.global_position - global_position).angle()
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 20.0 * delta)
		
		var dist = global_position.distance_to(target_enemy.global_position)
		laser_beam.size.x = dist - 40
		laser_beam.visible = true
		
		attack_timer -= delta
		if attack_timer <= 0:
			if target_enemy.has_method("take_damage"):
				var dmg = 5.0 + (GameManager.upg_turret_damage_level * 2.0)
				target_enemy.take_damage(dmg)
			attack_timer = attack_rate
	else:
		laser_beam.visible = false

func get_target_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var min_dist = 600.0 # 레이저 사거리
	
	for e in enemies:
		var dist = global_position.distance_to(e.global_position)
		if dist <= min_dist:
			min_dist = dist
			closest = e
	return closest
