extends Node2D

var grid_pos = Vector2i()
var heal_timer = 0.0
var heal_amount = 5

@onready var sprite = null

func _ready():
	sprite = ColorRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = Vector2(64, 64)
	sprite.position = Vector2(-32, -32)
	sprite.color = Color(0.0, 0.6, 0.8, 1.0) # 청록색 (수리소)
	add_child(sprite)
	
	# 십자가 마크
	var cross1 = ColorRect.new()
	cross1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross1.size = Vector2(10, 30)
	cross1.position = Vector2(-5, -15)
	cross1.color = Color(1, 1, 1, 1)
	sprite.add_child(cross1)
	
	var cross2 = ColorRect.new()
	cross2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross2.size = Vector2(30, 10)
	cross2.position = Vector2(-15, -5)
	cross2.color = Color(1, 1, 1, 1)
	sprite.add_child(cross2)

func _process(delta):
	var parent = GameManager.player
	if is_instance_valid(parent) and not parent.get("is_dead", false):
		heal_timer -= delta
		if heal_timer <= 0:
			heal_timer = 1.0
			if "hp" in parent and "max_hp" in parent:
				if parent.hp < parent.max_hp:
					parent.hp = min(parent.hp + heal_amount, parent.max_hp)
					if parent.has_method("queue_redraw"):
						parent.queue_redraw()
