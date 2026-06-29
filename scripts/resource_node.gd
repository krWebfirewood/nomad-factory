extends StaticBody2D

@export var item_name: String = "wood"
@export var hp: int = 3

var is_gathering = false
var original_pos = Vector2.ZERO

func _ready():
	if has_node("Sprite2D"):
		original_pos = $Sprite2D.position

func gather(player):
	if is_gathering or hp <= 0: return
	is_gathering = true
	hp -= 1
	
	if hp <= 0:
		player.add_item(item_name, 1)
		$CollisionShape2D.set_deferred("disabled", true)
		visible = false
		queue_free()
		return
		
	# 시각적 피드백 (하얗게 번쩍이고 살짝 흔들림)
	if is_instance_valid($Sprite2D):
		$Sprite2D.modulate = Color(2, 2, 2)
		$Sprite2D.position = original_pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
	
	await get_tree().create_timer(0.15).timeout
	
	if is_instance_valid($Sprite2D):
		$Sprite2D.modulate = Color(1, 1, 1)
		$Sprite2D.position = original_pos
		
	is_gathering = false
