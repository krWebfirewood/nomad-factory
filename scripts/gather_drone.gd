extends CharacterBody2D

var speed = 500.0
var state = "SEARCH"
var target_resource = null
var home_station = null
var carry_type = ""
var carry_amount = 0

func _ready():
	add_to_group("drone")
	var base = ColorRect.new()
	base.size = Vector2(20, 20)
	base.position = Vector2(-10, -10)
	base.color = Color(0.2, 0.8, 1.0)
	add_child(base)
	
	var prop = ColorRect.new()
	prop.size = Vector2(10, 4)
	prop.position = Vector2(10, -2)
	prop.color = Color(1, 1, 1)
	add_child(prop)
	
	var tween = create_tween().set_loops()
	tween.tween_property(prop, "rotation", PI*2, 0.2).as_relative()

func _physics_process(_delta):
	if not is_instance_valid(home_station):
		queue_free()
		return
		
	if state == "SEARCH":
		find_nearest_resource()
		
	elif state == "MOVE":
		if not is_instance_valid(target_resource) or target_resource.is_queued_for_deletion():
			state = "SEARCH"
			return
			
		var dir = global_position.direction_to(target_resource.global_position)
		var speed_mult = 1.0 / max(0.1, GameManager.stat_drill_mult)
		velocity = dir * speed * speed_mult
		rotation = velocity.angle()
		move_and_slide()
		
		if global_position.distance_to(target_resource.global_position) < 30:
			state = "GATHER"
			gather_resource()
			
	elif state == "RETURN":
		var dir = global_position.direction_to(home_station.global_position)
		var speed_mult = 1.0 / max(0.1, GameManager.stat_drill_mult)
		velocity = dir * speed * speed_mult
		rotation = velocity.angle()
		move_and_slide()
		
		if global_position.distance_to(home_station.global_position) < 50:
			deliver_resource()

func find_nearest_resource():
	var resources = get_tree().get_nodes_in_group("resource")
	var closest = null
	var min_dist = 1500.0 # 탐색 반경 1500px
	
	for r in resources:
		if is_instance_valid(r) and not r.is_gathering:
			var d = global_position.distance_to(r.global_position)
			if d < min_dist:
				min_dist = d
				closest = r
				
	if closest != null:
		target_resource = closest
		target_resource.is_gathering = true # 점유
		state = "MOVE"

func gather_resource():
	if not is_instance_valid(target_resource):
		state = "SEARCH"
		return
		
	var type = target_resource.item_name
	
	# 자원 파괴
	target_resource.hp = 0
	target_resource.queue_free()
	
	carry_type = type
	carry_amount = 1 + int(home_station.get_meta("level") if home_station.has_meta("level") else 0)
	
	var base = get_child(0)
	if type == "wood": base.color = Color(0.6, 0.4, 0.2)
	elif type == "stone": base.color = Color(0.5, 0.5, 0.5)
	elif type == "iron": base.color = Color(0.8, 0.8, 0.9)
	
	state = "RETURN"

func deliver_resource():
	if is_instance_valid(GameManager.player):
		GameManager.player.add_item(carry_type, carry_amount)
		
	var base = get_child(0)
	base.color = Color(0.2, 0.8, 1.0)
	
	carry_type = ""
	carry_amount = 0
	state = "SEARCH"
