extends StaticBody2D

enum State { IDLE, SMELTING, DONE }
var current_state = State.IDLE
var timer = 0.0
var process_time = 3.0

func _process(delta):
	if current_state == State.SMELTING:
		timer -= delta
		# 굽는 동안 붉은색으로 깜빡거리는 효과 (Sine 곡선 활용)
		var glow = 0.5 + sin(timer * 10) * 0.5
		$Sprite2D.modulate = Color(1, glow, glow)
		
		if timer <= 0:
			current_state = State.DONE
			$Sprite2D.modulate = Color(0.5, 0.5, 1.0) # 파란색(완료 상태)
			print("화로: 석재 벽돌 완성!")

func gather(player):
	if current_state == State.IDLE:
		if player.inventory.get("stone", 0) >= 1:
			player.add_item("stone", -1)
			current_state = State.SMELTING
			timer = process_time
			print("화로: 돌을 굽기 시작합니다.")
		else:
			print("화로: 돌이 부족합니다.")
	elif current_state == State.SMELTING:
		# 소수점 1자리까지만 출력
		print("화로: 굽는 중입니다... 남은 시간: ", snapped(timer, 0.1))
	elif current_state == State.DONE:
		player.add_item("stone_brick", 1)
		current_state = State.IDLE
		$Sprite2D.modulate = Color(1, 1, 1) # 원래 색으로 복구
		print("화로: 석재 벽돌을 회수했습니다.")
