extends Area2D

var velocity = Vector2.ZERO
var target = null
var item_type = "monster_core"
var friction = 4.0
var max_speed = 800.0
var tracking_delay = 1.0 # 흩뿌려진 후 추적 시작까지의 시간
var _timer = 0.0

func _ready():
	# 처음에 터져나가는 속도
	var angle = randf() * PI * 2
	var speed = randf_range(300.0, 700.0)
	velocity = Vector2(cos(angle), sin(angle)) * speed
	tracking_delay = randf_range(0.8, 1.5)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]
		
	# 타입에 따른 색상 변경
	if has_node("Sprite2D"):
		var spr = $Sprite2D
		if item_type == "wood": spr.modulate = Color(0.6, 0.4, 0.2, 1)
		elif item_type == "stone": spr.modulate = Color(0.6, 0.6, 0.6, 1)
		elif item_type == "steel_plate": spr.modulate = Color(0.8, 0.8, 0.9, 1)
		else: spr.modulate = Color(0.8, 0.2, 1, 1) # monster_core

func _physics_process(delta):
	_timer += delta
	
	if _timer < tracking_delay:
		# 아직 흩뿌려지는 중 (감속)
		position += velocity * delta
		velocity = velocity.lerp(Vector2.ZERO, friction * delta)
	else:
		# 타겟을 향해 자석처럼 끌려감
		if is_instance_valid(target):
			var dir = (target.global_position - global_position).normalized()
			# 자연스럽게 방향을 틀면서 최고 속도로 가속 (오빗 현상 방지)
			velocity = velocity.lerp(dir * max_speed, 8.0 * delta)
			position += velocity * delta
			
			if global_position.distance_to(target.global_position) < 40.0:
				_collect()
		else:
			# 타겟이 없으면 멈춤
			velocity = velocity.lerp(Vector2.ZERO, friction * delta)
			position += velocity * delta

func _collect():
	if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("add_item"):
		target.add_item(item_type, 1)
	queue_free()
