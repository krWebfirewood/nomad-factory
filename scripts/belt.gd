extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var floor_index = 1
var item = null
var pass_timer = 0.0
var pass_rate = 0.5

@onready var sprite = null
@onready var item_rect = null

func _ready():
	sprite = ColorRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = Vector2(40, 40)
	sprite.position = Vector2(-20, -20)
	sprite.color = Color(0.8, 0.5, 0.2, 1.0) # 갈색 벨트
	add_child(sprite)
	
	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(0, -10), Vector2(10, 0), Vector2(0, 10)])
	arrow.color = Color(0, 0, 0, 0.5)
	sprite.add_child(arrow)
	arrow.position = Vector2(20, 20)
	
	item_rect = ColorRect.new()
	item_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_rect.size = Vector2(16, 16)
	item_rect.position = Vector2(-8, -8)
	item_rect.z_index = 10
	add_child(item_rect)
	item_rect.visible = false

func _process(delta):
	if item != null:
		pass_timer -= delta
		if pass_timer <= 0:
			try_pass_item()

func try_pass_item():
	var player = GameManager.player
	if not is_instance_valid(player): return
	
	var next_pos = grid_pos + direction
	
	# 코어 (0,0) 배달
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
		if item == "iron": item_rect.color = Color(0.8, 0.8, 0.8) # 밝은 은색
		elif item == "steel_plate": item_rect.color = Color(0.2, 0.6, 1.0) # 밝은 파란색
		pass_timer = pass_rate
		return true
	return false
