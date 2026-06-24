extends Node2D

var grid_pos = Vector2i()
var direction = Vector2i.RIGHT
var floor_index = 1
var pass_timer = 0.0
var pass_rate = 1.0

@onready var sprite = null

func _ready():
	sprite = ColorRect.new()
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

func _process(delta):
	pass_timer -= delta
	if pass_timer <= 0:
		pass_timer = pass_rate
		try_provide()

func try_provide():
	var player = GameManager.player
	if not is_instance_valid(player): return
	
	if player.inventory.get("iron", 0) > 0:
		var next_pos = grid_pos + direction
		
		var next_building = null
		if player.floor_grids.has(floor_index):
			next_building = player.floor_grids[floor_index].get(next_pos)
			
		if next_building != null:
			if next_building.has_method("accept_item") and next_building.accept_item("iron"):
				player.add_item("iron", -1)
