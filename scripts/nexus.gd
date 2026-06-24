extends StaticBody2D

var max_hp = 50
var hp = 50

@onready var hp_label = $HPLabel

func _ready():
	# GameManager에 자신을 등록 (이미 GameManager에서 할 수도 있지만 확실히 하기 위해)
	GameManager.nexus = self
	update_ui()

func take_damage(amount):
	hp -= amount
	update_ui()
	
	# 시각적 피격 효과 (반짝임)
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color(5, 5, 5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and has_node("Sprite2D"):
			$Sprite2D.modulate = Color(1, 1, 1)
		
	if hp <= 0:
		game_over()

func update_ui():
	if is_instance_valid(hp_label):
		hp_label.text = "NEXUS HP: " + str(max(0, hp))

func game_over():
	print("=== GAME OVER ===")
	get_tree().paused = true
	if is_instance_valid(hp_label):
		hp_label.text = "GAME OVER!"
		hp_label.modulate = Color(1, 0, 0)

func accept_item(item) -> bool:
	if is_instance_valid(GameManager.player):
		GameManager.player.add_item(item, 1)
		# 넥서스 흡수 시각 효과 (초록색 깜빡임)
		if has_node("Sprite2D"):
			var original_mod = $Sprite2D.modulate
			$Sprite2D.modulate = Color(0.5, 1.0, 0.5)
			await get_tree().create_timer(0.05).timeout
			if is_instance_valid(self) and has_node("Sprite2D"):
				$Sprite2D.modulate = original_mod
		return true
	return false
