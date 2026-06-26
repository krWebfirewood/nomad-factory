extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var attack_timer = 0.0
var attack_rate = 1.5 # 스나이퍼: 느림
var projectile_scene = preload("res://scenes/projectile.tscn")
var target_enemy = null

@onready var range_area = null
@onready var sprite = null

func _ready():
	# 기존 타워의 하위 노드 구조를 코드로 흉내냄 (또는 씬 재사용)
	sprite = Node2D.new()
	add_child(sprite)
	
	var rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(40, 40)
	rect.position = Vector2(-20, -20)
	rect.color = Color(0.8, 0.0, 0.0, 1.0) # 빨간색
	sprite.add_child(rect)
	
	# 총열
	var barrel = ColorRect.new()
	barrel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrel.size = Vector2(30, 8)
	barrel.position = Vector2(10, -4)
	barrel.color = Color(0.2, 0.2, 0.2, 1.0)
	sprite.add_child(barrel)

func _process(delta):
	target_enemy = get_target_enemy()
	
	attack_timer -= delta
	if attack_timer <= 0:
		if shoot():
			attack_timer = attack_rate
	
	if is_instance_valid(target_enemy):
		var target_angle = (target_enemy.global_position - global_position).angle()
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 15.0 * delta)

func get_target_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var min_dist = 800.0 * GameManager.stat_range_mult # 스나이퍼 사거리 (화면 밖까지)
	
	for e in enemies:
		var dist = global_position.distance_to(e.global_position)
		if dist <= min_dist:
			min_dist = dist
			closest = e
	return closest

func shoot() -> bool:
	if is_instance_valid(target_enemy):
		var proj = projectile_scene.instantiate()
		proj.global_position = global_position
		proj.direction = global_position.direction_to(target_enemy.global_position)
		
		# 스나이퍼 프로젝타일 스탯 (추후 projectile.gd에서 지원하게 수정 필요, 임시로 속도/데미지 올리기)
		if "speed" in proj: proj.speed = 800.0
		if "attack_type" in proj: proj.attack_type = "piercing"
		var level = get_meta("level") if has_meta("level") else 1
		if "damage" in proj: proj.damage = 10.0 + (level - 1) * 3.0
		get_tree().current_scene.add_child(proj)
		return true
	return false
