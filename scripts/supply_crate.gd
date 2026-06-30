extends Area2D

func _ready():
	add_to_group("crate")
	
	var base = ColorRect.new()
	base.size = Vector2(40, 40)
	base.position = Vector2(-20, -20)
	base.color = Color(1.0, 0.8, 0.2) # 황금색
	add_child(base)
	
	var band = ColorRect.new()
	band.size = Vector2(40, 10)
	band.position = Vector2(-20, -5)
	band.color = Color(0.8, 0.1, 0.1) # 빨간 띠
	add_child(band)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 40)
	collision.shape = shape
	add_child(collision)
	
	body_entered.connect(_on_body_entered)
	
	# 반짝이는 연출
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)
	
	# 낮 시간이 끝나면 사라짐 (20초 후 자동 삭제)
	get_tree().create_timer(20.0).timeout.connect(func(): queue_free())

func _on_body_entered(body):
	if body.is_in_group("player"):
		# 보급품 효과: 무작위 자원 대량 지급
		body.add_item("wood", 30)
		body.add_item("stone", 30)
		body.add_item("iron", 20)
		body.add_item("monster_core", 15)
		
		# 이펙트
		var effect = CPUParticles2D.new()
		effect.emitting = true
		effect.one_shot = true
		effect.explosiveness = 0.9
		effect.amount = 50
		effect.lifetime = 1.0
		effect.spread = 180.0
		effect.initial_velocity_min = 100.0
		effect.initial_velocity_max = 200.0
		effect.scale_amount_min = 5.0
		effect.scale_amount_max = 10.0
		effect.color = Color(1.0, 0.8, 0.2)
		
		effect.global_position = global_position
		get_tree().current_scene.add_child.call_deferred(effect)
		get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
		
		queue_free()
