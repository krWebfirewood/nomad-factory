extends StaticBody2D

@export var item_name: String = "wood"
@export var hp: int = 3

func gather(player):
	hp -= 1
	print(item_name + " 캐는 중! 남은 체력: ", hp)
	
	# 시각적 피드백 (깜빡임)
	$Sprite2D.visible = false
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid($Sprite2D):
		$Sprite2D.visible = true
	
	if hp <= 0:
		print(item_name + " 채집 완료!")
		player.add_item(item_name, 1)
		queue_free()
