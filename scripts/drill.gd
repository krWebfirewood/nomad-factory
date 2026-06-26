extends Node2D

var grid_pos = Vector2i()
var drill_timer = 0.0
var anim_timer = 0.0

@onready var base_rect = null
@onready var drill_bit = null

func _ready():
	base_rect = ColorRect.new()
	base_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_rect.size = Vector2(64, 64)
	base_rect.position = Vector2(-32, -32)
	base_rect.color = Color(0.3, 0.2, 0.1, 1.0) # 짙은 갈색 기단
	add_child(base_rect)
	
	drill_bit = ColorRect.new()
	drill_bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drill_bit.size = Vector2(20, 40)
	drill_bit.position = Vector2(-10, -20)
	drill_bit.color = Color(0.8, 0.8, 0.8, 1.0) # 은색 드릴 날
	add_child(drill_bit)

func _process(delta):
	# 애니메이션 (위아래 흔들림)
	anim_timer += delta * 15.0
	drill_bit.position.y = -20 + sin(anim_timer) * 5.0
	
	drill_timer -= delta
	if drill_timer <= 0:
		var level = get_meta("level") if has_meta("level") else 1
		drill_timer = max(0.2, (2.0 - (level - 1) * 0.2)) * GameManager.stat_drill_mult
		mine_resources()

func mine_resources():
	# 드릴의 월드 좌표가 위치한 타일맵 타일 확인
	var world_pos = global_position
	var tile_grid_pos = FactoryManager.get_world_grid_pos(world_pos)
	
	var res_type = FactoryManager.get_ore(tile_grid_pos)
	if res_type != null:
		# 타일에 자원이 있다면!
		if is_instance_valid(GameManager.player) and not GameManager.player.is_queued_for_deletion():
			GameManager.player.add_item(res_type, 1)
			
			# 애니메이션 강하게 튕기기
			drill_bit.position.y = -30
