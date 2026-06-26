extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var floor_index = 1
var item = null
var process_timer = 0.0
var process_rate = 2.0

@onready var sprite = null
@onready var item_rect = null

func _ready():
	sprite = ColorRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = Vector2(50, 50)
	sprite.position = Vector2(-25, -25)
	sprite.color = Color(0.5, 0.5, 0.5, 1.0) # 회색 가공소
	add_child(sprite)
	
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(0, -10), Vector2(10, 0), Vector2(0, 10)])
	arrow.color = Color(0, 0, 0, 0.8)
	sprite.add_child(arrow)
	arrow.position = Vector2(25, 25)
	
	item_rect = ColorRect.new()
	item_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_rect.size = Vector2(20, 20)
	item_rect.position = Vector2(-10, -10)
	item_rect.z_index = 10 # 항상 맨 위에 보이도록
	add_child(item_rect)
	item_rect.visible = false

func _process(delta):
	if item != null:
		process_timer -= delta
		if process_timer <= 0:
			if item == "iron":
				item = "steel_plate"
				item_rect.color = Color(0.2, 0.6, 1.0, 1.0) # 밝은 파란색(강철)
			elif item == "stone":
				item = "stone_brick"
				item_rect.color = Color(0.3, 0.3, 0.3, 1.0) # 짙은 회색(석재 벽돌)
			try_pass_item()

func try_pass_item():
	var player = GameManager.player
	if not is_instance_valid(player) or player.is_queued_for_deletion(): return
	
	var next_pos = grid_pos + direction
	
	if next_pos == Vector2i(0, 0):
		player.add_item(item, 1)
		item = null
		item_rect.visible = false
		return
		
	var next_building = null
	if player.floor_grids.has(floor_index):
		next_building = player.floor_grids[floor_index].get(next_pos)
		
	if next_building != null:
		if next_building.has_method("accept_item") and next_building.accept_item(item):
			item = null
			item_rect.visible = false

func accept_item(new_item) -> bool:
	if item == null:
		item = new_item
		item_rect.visible = true
		if item == "iron":
			item_rect.color = Color(0.8, 0.8, 0.8, 1.0) # 굽기 전(밝은 은색)
		elif item == "stone":
			item_rect.color = Color(0.6, 0.6, 0.6, 1.0) # 굽기 전 돌(회색)
		else:
			item_rect.color = Color(1.0, 1.0, 1.0, 1.0)
		var level = get_meta("level") if has_meta("level") else 1
		process_rate = max(0.5, 2.0 - (level - 1) * 0.3)
		process_timer = process_rate
		return true
	return false
