extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var floor_index = 1
var pass_timer = 0.0
var pass_rate = 1.0

@onready var sprite = null

var filters = [
	{"id": "auto", "name": "자동"},
	{"id": "iron", "name": "철광석"},
	{"id": "stone", "name": "돌"},
	{"id": "wood", "name": "나무"},
	{"id": "off", "name": "정지"}
]

func _ready():
	sprite = ColorRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = Vector2(40, 40)
	sprite.position = Vector2(-20, -20)
	sprite.color = Color(0.2, 0.8, 0.2, 1.0) # 초록색 공급기
	add_child(sprite)
	
	# 화살표 표시
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(0, -10), Vector2(10, 0), Vector2(0, 10)])
	arrow.color = Color(0, 0, 0, 0.5)
	sprite.add_child(arrow)
	arrow.position = Vector2(20, 20)
	
	set_meta("b_name", "공급기")
	if not has_meta("filter_idx"):
		set_meta("filter_idx", 0)

func _process(delta):
	pass_timer -= delta
	if pass_timer <= 0:
		pass_timer = pass_rate
		try_provide()

func try_provide():
	var player = GameManager.player
	if not is_instance_valid(player): return
	
	var idx = get_meta("filter_idx") if has_meta("filter_idx") else 0
	var target_item = filters[idx]["id"]
	if target_item == "off": return
	
	var items_to_try = []
	if target_item == "auto":
		items_to_try = ["iron", "stone", "wood"] # 자동일 경우 기본 순서대로 시도
	else:
		items_to_try = [target_item]
		
	for item_name in items_to_try:
		if player.inventory.get(item_name, 0) > 0:
			var next_pos = grid_pos + direction
			
			var next_building = null
			if player.floor_grids.has(floor_index):
				next_building = player.floor_grids[floor_index].get(next_pos)
				
			if next_building != null:
				if next_building.has_method("accept_item") and next_building.accept_item(item_name):
					player.add_item(item_name, -1)
					return # 한 번에 한 개의 아이템만 공급
