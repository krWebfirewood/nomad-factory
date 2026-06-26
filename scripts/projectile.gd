extends Area2D

var speed = 400.0
var direction = Vector2.ZERO
var damage = 1
var attack_type = "normal"

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			var total_damage = (damage + GameManager.upg_turret_damage_level) * GameManager.stat_damage_mult
			body.take_damage(total_damage, attack_type)
		queue_free()

func _on_timer_timeout():
	queue_free()
