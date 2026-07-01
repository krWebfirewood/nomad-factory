extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var attack_timer = 0.0
var attack_rate = 1.0 # 샷건: 보통
var projectile_scene = preload("res://scenes/projectile.tscn")
var target_enemy = null
var target_groups = ["enemy"]

@onready var range_area = null
@onready var sprite = null

func _ready():
	sprite = Node2D.new()
	add_child(sprite)
	
	var rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(40, 40)
	rect.position = Vector2(-20, -20)
	rect.color = Color(0.8, 0.8, 0.0, 1.0) # 노란색
	sprite.add_child(rect)
	
	# 넓은 총구 묘사
	var barrel = ColorRect.new()
	barrel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrel.size = Vector2(20, 20)
	barrel.position = Vector2(15, -10)
	barrel.color = Color(0.3, 0.3, 0.3, 1.0)
	sprite.add_child(barrel)

func _process(delta):
	target_enemy = get_target_enemy()
	
	attack_timer -= delta
	if attack_timer <= 0:
		if shoot():
			attack_timer = attack_rate * GameManager.stat_firerate_mult
	
	if is_instance_valid(target_enemy):
		var target_angle = (target_enemy.global_position - global_position).angle()
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 8.0 * delta)

func get_target_enemy():
	var targets = []
	for g in target_groups:
		targets.append_array(get_tree().get_nodes_in_group(g))
		
	var closest = null
	var min_dist = 250.0 * GameManager.stat_range_mult # 샷건 사거리 (짧음)
	
	for e in targets:
		if e.get("is_dead") == true: continue
		var dist = global_position.distance_to(e.global_position)
		if dist <= min_dist:
			min_dist = dist
			closest = e
	return closest

func shoot() -> bool:
	if is_instance_valid(target_enemy):
		var cur_mod = get_meta("equipped_module") if has_meta("equipped_module") else ""
		var mult = 3 if cur_mod == "mod_multishot" else 1
		var num_pellets = 5 * mult
		var base_dir = global_position.direction_to(target_enemy.global_position)
		var spread_angle = 45.0 * mult * (PI / 180.0)
		
		for i in range(num_pellets):
			var proj = projectile_scene.instantiate()
			proj.global_position = global_position
			var angle_offset = -spread_angle/2.0 + (spread_angle / (num_pellets - 1)) * i
			proj.direction = base_dir.rotated(angle_offset)
			proj.visible = is_visible_in_tree()
			if "target_groups" in proj: proj.target_groups = target_groups
			get_tree().current_scene.add_child(proj)
			
			if "speed" in proj: proj.speed = 300.0 + randf() * 100.0
			if "attack_type" in proj: proj.attack_type = "scatter"
			var level = get_meta("level") if has_meta("level") else 1
			if "damage" in proj: proj.damage = 2.0 + (level - 1) * 1.0
			if "module" in proj: proj.module = cur_mod
		return true
	return false
