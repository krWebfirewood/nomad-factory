extends Area2D

var speed = 250.0
var direction = Vector2.ZERO
var damage = 25.0
var attack_type = "explosive"
var explosion_radius = 120.0

func _ready():
	collision_layer = 0
	collision_mask = 2 # Enemy layer

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
	if body.is_in_group("enemy"):
		explode()

func _on_timer_timeout():
	explode()

func explode():
	# 광역 데미지
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
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
	particles.explosiveness = 0.95
	particles.amount = 40
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 400.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 10.0
	particles.color = Color(1.0, 0.8, 0.1)
	effect_node.add_child(particles)
	
	get_tree().current_scene.add_child(effect_node)
	
	circle.scale = Vector2(0.1, 0.1)
	var tween = effect_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(circle, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(circle, "color", Color(1.0, 0.3, 0.0, 0.0), 0.4).set_delay(0.1)
	tween.chain().tween_callback(func(): effect_node.queue_free())
	
	queue_free()
