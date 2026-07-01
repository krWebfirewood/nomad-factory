extends Area2D

var speed = 400.0
var direction = Vector2.ZERO
var damage = 1
var attack_type = "normal"
var target_groups = ["enemy"]

var module = ""

func _ready():
	collision_mask = 1 | 2 | 4 # Player(1), Enemy(2), Rival(4)
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		if module == "mod_explosive":
			sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
			scale = Vector2(1.5, 1.5)
		elif module == "mod_frost":
			sprite.modulate = Color(0.2, 0.8, 1.0, 1.0)
			
func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	var is_target = false
	for g in target_groups:
		if body.is_in_group(g):
			is_target = true
			break
			
	if is_target:
		var total_damage = (damage + GameManager.upg_turret_damage_level) * GameManager.stat_damage_mult
		
		if module == "mod_explosive":
			# 폭발 광역 데미지
			var explosion_radius = 80.0
			var targets = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("rival") + get_tree().get_nodes_in_group("boss")
			for e in targets:
				if e.get("is_dead") == true: continue
				if e.global_position.distance_to(global_position) <= explosion_radius:
					if e.has_method("take_damage"):
						e.take_damage(total_damage * 0.8, "explosive")
			# 시각 이펙트
			var effect = CPUParticles2D.new()
			effect.emitting = true
			effect.one_shot = true
			effect.amount = 20
			effect.lifetime = 0.5
			effect.explosiveness = 1.0
			effect.spread = 180.0
			effect.initial_velocity_min = 50.0
			effect.initial_velocity_max = 100.0
			effect.color = Color(1.0, 0.3, 0.1)
			effect.global_position = global_position
			get_tree().current_scene.add_child(effect)
			get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
		else:
			if body.has_method("take_damage"):
				body.take_damage(total_damage, attack_type)
				
		if module == "mod_frost":
			if body.has_method("apply_slow"):
				body.apply_slow(0.5, 3.0) # 50% slow for 3 seconds
			else:
				# 임시 슬로우 로직 (속성 추가)
				body.set_meta("frost_slow", 0.5)
				body.set_meta("frost_timer", 3.0)
				# 적 스크립트에 슬로우 처리가 없다면 여기서 변형해줄 필요가 있지만, 기본적으로 이펙트만 줄 수도 있음
			var effect = CPUParticles2D.new()
			effect.emitting = true
			effect.one_shot = true
			effect.amount = 10
			effect.lifetime = 0.4
			effect.color = Color(0.3, 0.8, 1.0)
			effect.global_position = global_position
			get_tree().current_scene.add_child(effect)
			get_tree().create_timer(1.0).timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
			
		queue_free()

func _on_timer_timeout():
	queue_free()
