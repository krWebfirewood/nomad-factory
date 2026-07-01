extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var attack_timer = 0.0
var attack_rate = 0.3 # 기관총: 빠름
var projectile_scene = preload("res://scenes/projectile.tscn")
var target_enemy = null
var target_groups = ["enemy"]

@onready var range_area = $RangeArea
@onready var sprite = $Sprite2D

func _ready():
	if has_node("AmmoLabel"): $AmmoLabel.queue_free()
	if has_node("AmmoRect"): $AmmoRect.queue_free()

func _process(delta):
	target_enemy = get_target_enemy()
	
	attack_timer -= delta
	if attack_timer <= 0:
		if shoot():
			attack_timer = attack_rate * GameManager.stat_firerate_mult
	
	if is_instance_valid(target_enemy):
		var target_angle = (target_enemy.global_position - global_position).angle()
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 10.0 * delta)

func get_target_enemy():
	var targets = []
	for g in target_groups:
		targets.append_array(get_tree().get_nodes_in_group(g))
		
	var closest = null
	var min_dist = 400.0 * GameManager.stat_range_mult # 기관총 사거리 (요새 전체를 커버하도록 넉넉히)
	
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
		var num_shots = 3 if cur_mod == "mod_multishot" else 1
		var base_dir = global_position.direction_to(target_enemy.global_position)
		
		for i in range(num_shots):
			var proj = projectile_scene.instantiate()
			proj.global_position = global_position
			
			if num_shots == 3:
				var angle_offset = (i - 1) * 0.3 # -0.3, 0, 0.3
				proj.direction = base_dir.rotated(angle_offset)
			else:
				proj.direction = base_dir
				
			proj.visible = is_visible_in_tree()
			if "target_groups" in proj: proj.target_groups = target_groups
			if "attack_type" in proj: proj.attack_type = "kinetic"
			var level = get_meta("level") if has_meta("level") else 1
			if "damage" in proj: proj.damage += (level - 1) * 0.5
			if "module" in proj: proj.module = cur_mod
			
			get_tree().current_scene.add_child(proj)
		return true
	return false
