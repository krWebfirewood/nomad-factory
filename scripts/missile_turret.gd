extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var floor_index = 1

var attack_timer = 0.0
var attack_rate = 2.0 # 미사일: 느린 속도, 광역 데미지
var target_enemy = null

@onready var sprite = null

func _ready():
	sprite = Node2D.new()
	add_child(sprite)
	
	var base = ColorRect.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.size = Vector2(40, 40)
	base.position = Vector2(-20, -20)
	base.color = Color(0.8, 0.3, 0.1, 1.0) # 다크 오렌지색 타워
	sprite.add_child(base)
	
	var barrel = ColorRect.new()
	barrel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrel.size = Vector2(30, 20)
	barrel.position = Vector2(10, -10)
	barrel.color = Color(0.2, 0.2, 0.2, 1.0) # 어두운 총구
	sprite.add_child(barrel)

func _process(delta):
	target_enemy = get_target_enemy()
	
	if is_instance_valid(target_enemy):
		var target_angle = (target_enemy.global_position - global_position).angle()
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 10.0 * delta)
		
		attack_timer -= delta
		if attack_timer <= 0:
			if shoot():
				attack_timer = attack_rate * GameManager.stat_firerate_mult

func get_target_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var min_dist = 500.0 * GameManager.stat_range_mult # 사거리 500
	
	for e in enemies:
		var dist = global_position.distance_to(e.global_position)
		if dist <= min_dist:
			min_dist = dist
			closest = e
	return closest

func shoot():
	if not is_instance_valid(target_enemy): return
	
	var cur_mod = get_meta("equipped_module") if has_meta("equipped_module") else ""
	var num_shots = 3 if cur_mod == "mod_multishot" else 1
	var base_dir = global_position.direction_to(target_enemy.global_position)
	
	for i in range(num_shots):
		var script = preload("res://scripts/missile_projectile.gd")
		var proj = script.new()
		proj.global_position = global_position
		if num_shots == 3:
			proj.direction = base_dir.rotated((i - 1) * 0.5)
		else:
			proj.direction = base_dir
			
		proj.visible = is_visible_in_tree()
		var level = get_meta("level") if has_meta("level") else 1
		if "damage" in proj: proj.damage = 25.0 + (level - 1) * 10.0
		if "module" in proj: proj.module = cur_mod
		get_tree().current_scene.add_child(proj)
