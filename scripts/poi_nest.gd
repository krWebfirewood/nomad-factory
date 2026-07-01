extends StaticBody2D

var hp = 10000.0 # 엄청난 체력
var spawn_timer = 0.0
var spawn_interval = 2.0

func _ready():
	add_to_group("boss") # 폭발 등의 데미지를 받기 위함
	add_to_group("poi")
	
	var base = ColorRect.new()
	base.size = Vector2(150, 150)
	base.position = Vector2(-75, -75)
	base.color = Color(0.3, 0.05, 0.1) 
	add_child(base)
	
	var core = ColorRect.new()
	core.size = Vector2(50, 50)
	core.position = Vector2(-25, -25)
	core.color = Color(1.0, 0.2, 0.0)
	add_child(core)
	
	var tween = create_tween().set_loops()
	tween.tween_property(core, "scale", Vector2(1.5, 1.5), 0.5)
	tween.tween_property(core, "scale", Vector2(1.0, 1.0), 0.5)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(150, 150)
	collision.shape = shape
	add_child(collision)

func _process(delta):
	if is_instance_valid(GameManager.player):
		var dist = global_position.distance_to(GameManager.player.global_position)
		if dist < 2000:
			spawn_timer -= delta
			if spawn_timer <= 0:
				spawn_timer = spawn_interval
				spawn_defenders()

func spawn_defenders():
	var enemy_scene = load("res://scenes/enemy.tscn")
	for i in range(3 + randi() % 3):
		var enemy = enemy_scene.instantiate()
		var angle = randf() * PI * 2
		enemy.global_position = global_position + Vector2(cos(angle), sin(angle)) * 100
		
		var type = 1 if randf() < 0.7 else 3
		if enemy.has_method("setup"):
			enemy.setup(GameManager.current_wave + 5, type) 
			
		get_tree().current_scene.add_child(enemy)

func take_damage(amount, attack_type="normal"):
	hp -= amount
	var core = get_child(1)
	core.modulate = Color(3, 3, 3)
	get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(core): core.modulate = Color(1,1,1))
	
	if hp <= 0:
		die()

func die():
	var drop_scene = load("res://scenes/dropped_item.tscn")
	
	for i in range(50):
		var drop = drop_scene.instantiate()
		drop.global_position = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		drop.set("item_type", "monster_core")
		get_tree().current_scene.add_child.call_deferred(drop)
		
	for i in range(30):
		var drop = drop_scene.instantiate()
		drop.global_position = global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		drop.set("item_type", "iron")
		get_tree().current_scene.add_child.call_deferred(drop)
		
	# 확률적 모듈 드랍
	if randf() < 0.15:
		var module_drop = drop_scene.instantiate()
		module_drop.global_position = global_position
		var mod_types = ["mod_explosive", "mod_multishot", "mod_frost"]
		module_drop.set("item_type", mod_types[randi() % mod_types.size()])
		get_tree().current_scene.add_child.call_deferred(module_drop)
		
	var effect = CPUParticles2D.new()
	effect.emitting = true
	effect.one_shot = true
	effect.explosiveness = 1.0
	effect.amount = 300
	effect.lifetime = 1.5
	effect.spread = 180.0
	effect.initial_velocity_min = 300.0
	effect.initial_velocity_max = 800.0
	effect.scale_amount_min = 20.0
	effect.scale_amount_max = 50.0
	effect.color = Color(1.0, 0.1, 0.0)
	
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	effect.scale_amount_curve = curve
	
	effect.global_position = global_position
	get_tree().current_scene.add_child.call_deferred(effect)
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
	
	queue_free()
