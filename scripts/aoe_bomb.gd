extends Node2D

var lifetime = 1.5
var radius = 100.0
var damage = 100.0
var exploded = false

func _ready():
	var circle = Polygon2D.new()
	circle.color = Color(1.0, 0.0, 0.0, 0.4) # 붉은색 경고 마커
	
	# 원형 폴리곤 생성
	var points = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = i * PI * 2.0 / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = points
	add_child(circle)
	
	var outline = Line2D.new()
	var line_points = points.duplicate()
	line_points.append(points[0]) # 닫힌 선
	outline.points = line_points
	outline.width = 2.0
	outline.default_color = Color(1, 0, 0, 1)
	add_child(outline)
	
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_explode)

func _process(delta):
	if exploded:
		scale += Vector2(delta * 4.0, delta * 4.0) # 폭발하며 커짐
		modulate.a -= delta * 3.0 # 서서히 사라짐
		if modulate.a <= 0:
			queue_free()
		return
		
	# 매우 빠른 점멸 효과 (위험 경고)
	modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 50.0)

func _on_explode():
	exploded = true
	# 폭발 순간 번쩍임 (폭발 이펙트 색상)
	modulate = Color(2.0, 1.0, 0.2, 1.0) # 밝은 노란/주황색 빛
	scale = Vector2(1.1, 1.1)
	
	# 데미지 판정
	if is_instance_valid(GameManager.player):
		var dist_to_player = GameManager.player.global_position.distance_to(global_position)
		if dist_to_player <= radius + 30.0: # 코어(본체) 데미지
			GameManager.player.take_damage(damage)
			
		# 건물 파괴!
		var destroyed = GameManager.player.destroy_buildings_in_radius(global_position, radius)
		if destroyed > 0:
			print("포격으로 인해 " + str(destroyed) + "개의 건물이 파괴되었습니다!")
