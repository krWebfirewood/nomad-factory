extends Area2D

var speed = 250.0
var direction = Vector2.ZERO
var damage = 25.0
var attack_type = "explosive"
var explosion_radius = 120.0
var target_groups = ["enemy"]

func _ready():
	collision_layer = 0
	collision_mask = 1 | 2 | 4 # Player, Enemy, Rival

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	
	var rect = ColorRect.new()
	rect.size = Vector2(20, 10)
	rect.position = Vector2(-10, -5)
	rect.color = Color(1.0, 0.4, 0.0) # 오렌지색 미사일
	add_child(rect)
	
	body_entered.connect(_on_body_entered)
	
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_timer_timeout)

func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body):
	for g in target_groups:
		if body.is_in_group(g):
			explode()
			break

func _on_timer_timeout():
	explode()

func explode():
	# 광역 데미지
	var targets = []
	for g in target_groups:
		targets.append_array(get_tree().get_nodes_in_group(g))
		
	for e in targets:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= explosion_radius:
			if e.has_method("take_damage"):
				var total_damage = (damage + GameManager.upg_turret_damage_level * 5.0) * GameManager.stat_damage_mult
				e.take_damage(total_damage, attack_type)
				
	# 폭발 이펙트 (파티클 + 애니메이션)
	var effect_node = Node2D.new()
	effect_node.global_position = global_position
	
	var circle = Polygon2D.new()
	circle.color = Color(1.0, 0.3, 0.0, 0.8)
	var points = PackedVector2Array()
	var segments = 24
	for i in range(segments):
		var angle = i * PI * 2.0 / segments
		points.append(Vector2(cos(angle), sin(angle)) * explosion_radius)
	circle.polygon = points
	effect_node.add_child(circle)
	
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.8
	particles.amount = 60
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 350.0
	
	# 파티클 스케일 감쇠용 Curve
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = curve
	particles.scale_amount_min = 8.0
	particles.scale_amount_max = 15.0
	
	# 그라데이션 추가 (주황 -> 투명)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.9, 0.2, 1.0))
	grad.add_point(0.7, Color(1.0, 0.3, 0.0, 0.8))
	grad.add_point(1.0, Color(0.2, 0.2, 0.2, 0.0))
	particles.color_ramp = grad
	
	effect_node.add_child(particles)
	get_tree().current_scene.add_child(effect_node)
	
	circle.scale = Vector2(0.1, 0.1)
	var tween = effect_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(circle, "color", Color(1.0, 0.2, 0.0, 0.0), 0.4).set_delay(0.1)
	
	# 파티클이 모두 사라진 후(0.8초 + 여유) effect_node 삭제
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(effect_node): effect_node.queue_free())
	
	queue_free()
