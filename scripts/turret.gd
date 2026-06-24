extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var attack_timer = 0.0
var attack_rate = 0.3 # 기관총: 빠름
var projectile_scene = preload("res://scenes/projectile.tscn")
var target_enemy = null

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
			attack_timer = attack_rate
	
	if is_instance_valid(target_enemy):
		var target_angle = (target_enemy.global_position - global_position).angle()
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 10.0 * delta)

func get_target_enemy():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest = null
	var min_dist = 400.0 # 기관총 사거리 (요새 전체를 커버하도록 넉넉히)
	
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
		get_tree().current_scene.add_child(proj)
		return true
	return false
