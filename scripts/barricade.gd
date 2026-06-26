extends StaticBody2D

var hp = 500
var max_hp = 500
var grid_pos = Vector2i()

@onready var sprite = null

func _ready():
	# 충돌 레이어 1 (적들이 와서 부딪힐 수 있음)
	collision_layer = 1
	collision_mask = 0
	
	add_to_group("trailer") # 편의상 적들이 트레일러/플레이어로 인식하게 함
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	col.shape = shape
	add_child(col)
	
	if is_instance_valid(GameManager.player):
		add_collision_exception_with(GameManager.player)
	
	sprite = ColorRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = Vector2(64, 64)
	sprite.position = Vector2(-32, -32)
	sprite.color = Color(0.4, 0.4, 0.5, 1.0) # 철회색
	add_child(sprite)

func take_damage(amount):
	hp -= amount
	if sprite:
		var orig_color = Color(0.4, 0.4, 0.5, 1.0)
		sprite.color = Color(1, 1, 1, 1)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and sprite:
			sprite.color = orig_color
			
	if hp <= 0:
		# 파괴 시 해당 층의 그리드에서 제거 (전체 층 순회)
		var player = GameManager.player
		if is_instance_valid(player) and "floor_grids" in player:
			for fl in player.floor_grids:
				if player.floor_grids[fl].has(grid_pos):
					player.floor_grids[fl].erase(grid_pos)
		queue_free()
