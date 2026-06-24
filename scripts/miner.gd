extends Node2D

@onready var sprite = $Sprite2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var mine_timer = 0.0
var mine_rate = 2.0

func _ready():
	pass

func _process(delta):
	# 업그레이드 레벨 1당 채굴 주기 10% 감소 (최소 0.2초)
	var current_mine_rate = max(0.2, mine_rate * (1.0 - (GameManager.upg_miner_speed_level * 0.1)))
	
	mine_timer -= delta
	if mine_timer <= 0:
		mine_item()
		mine_timer = current_mine_rate

func mine_item():
	# 글로벌 좌표를 기반으로 현재 채굴기가 밟고 있는 바닥에 광석이 있는지 검사
	var world_grid_pos = FactoryManager.get_world_grid_pos(global_position)
	var ore_type = FactoryManager.get_ore(world_grid_pos)
	
	if ore_type != null:
		var item = ore_type
		# 로컬 그리드 상의 다음 건물로 아이템 전달
		var next_pos = grid_pos + direction
		var next_building = FactoryManager.get_building(next_pos)
		
		if next_building != null and next_building.has_method("accept_item"):
			next_building.accept_item(item)
		else:
			# 벨트가 없으면 요새 중심(Player 본체)으로 보내기 위한 로직
			if abs(next_pos.x) <= 2 and abs(next_pos.y) <= 2:
				# 요새 본체(부모 노드)가 아이템 흡수
				var parent = get_parent()
				if parent and parent.has_method("accept_item"):
					parent.accept_item(item)
