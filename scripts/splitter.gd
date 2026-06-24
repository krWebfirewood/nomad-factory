extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var item = null
var pass_timer = 0.0
var pass_rate = 0.5
var output_index = 0

@onready var sprite = $Sprite2D
@onready var item_rect = $ItemRect

func _ready():
	item_rect.visible = false

func _process(delta):
	if item != null:
		pass_timer -= delta
		if pass_timer <= 0:
			try_pass_item()

func try_pass_item():
	# 방향 계산: Forward, Right(시계방향 90도), Left(반시계방향 90도)
	var dirs = [
		direction,
		Vector2i(-direction.y, direction.x),
		Vector2i(direction.y, -direction.x)
	]
	
	# 3방향 중 보낼 수 있는 곳을 찾을 때까지 루프
	for i in range(3):
		var current_dir = dirs[output_index]
		var next_pos = grid_pos + current_dir
		var next_building = FactoryManager.get_building(next_pos)
		
		if next_building != null and next_building.has_method("accept_item"):
			if next_building.accept_item(item):
				item = null
				item_rect.visible = false
				# 다음 아이템은 그 다음 출구로 나가도록 인덱스 증가
				output_index = (output_index + 1) % 3
				return
				
		# 현재 출구가 비어있거나 꽉 찼으면 다음 출구 방향으로 넘어감
		output_index = (output_index + 1) % 3

func accept_item(new_item) -> bool:
	if item == null:
		item = new_item
		item_rect.visible = true
		if item == "stone":
			item_rect.color = Color(0.0, 1.0, 0.0, 1.0)
		elif item == "refined_stone":
			item_rect.color = Color(0.0, 1.0, 1.0, 1.0)
		else:
			item_rect.color = Color(1.0, 1.0, 1.0, 1.0)
		pass_timer = pass_rate
		return true
	return false
