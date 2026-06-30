extends Area2D

var damage = 300.0
var explosion_radius = 200.0
var alpha = 1.0

func _ready():
	add_to_group("landmine")
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	add_child(collision)
	
	body_entered.connect(_on_body_entered)
	
	var tween = create_tween().set_loops()
	tween.tween_property(self, "alpha", 0.3, 0.5)
	tween.tween_property(self, "alpha", 1.0, 0.5)

func _process(_delta):
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.2, 0.0, alpha))
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.8, 0.0, alpha))
	
func _on_body_entered(body):
	if body.is_in_group("enemy") or body.is_in_group("rival") or body.is_in_group("boss"):
		explode()

func explode():
	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies.append_array(get_tree().get_nodes_in_group("rival"))
	enemies.append_array(get_tree().get_nodes_in_group("boss"))
	
	for e in enemies:
		if is_instance_valid(e) and global_position.distance_to(e.global_position) <= explosion_radius:
			if e.has_method("take_damage"):
				e.take_damage(damage * GameManager.stat_damage_mult, "explosive")
	
	var effect = CPUParticles2D.new()
	effect.emitting = true
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.amount = 50
	effect.lifetime = 0.5
	effect.spread = 180.0
	effect.initial_velocity_min = 200.0
	effect.initial_velocity_max = 400.0
	effect.scale_amount_min = 10.0
	effect.scale_amount_max = 20.0
	effect.color = Color(1.0, 0.5, 0.0)
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	effect.scale_amount_curve = curve
	
	effect.global_position = global_position
	get_tree().current_scene.add_child.call_deferred(effect)
	get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
	
	queue_free()
