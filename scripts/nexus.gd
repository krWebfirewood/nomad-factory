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
		hp_label.text = "NEXUS HP: " + str(ceil(max(0, hp)))

func game_over():
	print("=== GAME OVER ===")
	get_tree().paused = true
	if is_instance_valid(hp_label):
		hp_label.text = "GAME OVER!"
		hp_label.modulate = Color(1, 0, 0)
		
	# 코어 누적 및 저장
	if is_instance_valid(GameManager.player):
		var final_core_count = GameManager.player.inventory.get("monster_core", 0) if "inventory" in GameManager.player else 0
		GameManager.total_cores += final_core_count
		print("획득한 코어: ", final_core_count, " / 총 코어: ", GameManager.total_cores)
	
	GameManager.save_meta_data()
	
	await get_tree().create_timer(2.0, true, false, true).timeout
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func accept_item(item) -> bool:
	if is_instance_valid(GameManager.player) and not GameManager.player.is_queued_for_deletion():
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
