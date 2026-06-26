extends Area2D

var speed = 400.0
var direction = Vector2.ZERO
var damage = 1
var attack_type = "normal"
var target_groups = ["enemy"]

func _ready():
	collision_mask = 1 | 2 | 4 # Player(1), Enemy(2), Rival(4)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	var is_target = false
	for g in target_groups:
		if body.is_in_group(g):
			is_target = true
			break
			
	if is_target:
		if body.has_method("take_damage"):
			var total_damage = (damage + GameManager.upg_turret_damage_level) * GameManager.stat_damage_mult
			body.take_damage(total_damage, attack_type)
		queue_free()

func _on_timer_timeout():
	queue_free()
