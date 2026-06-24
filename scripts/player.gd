extends CharacterBody2D

const SPEED = 100.0 # 육중한 이동 속도 (기존 300 -> 100)

var max_hp = 500
var hp = 500

var inventory = {"wood": 0}
@onready var inventory_label = $UI/InventoryLabel

var furnace_scene = preload("res://scenes/furnace.tscn")
var projectile_scene = preload("res://scenes/projectile.tscn")

var build_type = 0 # 0=None, 1=Belt, 2=Miner, 3=Turret, 4=Processor, 5=Splitter
var build_direction = Vector2i.RIGHT
var belt_scene = preload("res://scenes/belt.tscn")
var miner_scene = preload("res://scenes/miner.tscn")
var turret_scene = preload("res://scenes/turret.tscn")
var processor_scene = preload("res://scenes/processor.tscn")
var splitter_scene = preload("res://scenes/splitter.tscn")
var base_speed = 100.0
var speed = base_speed

var boost_timer = 0.0
var boost_cooldown = 0.0

var build_preview: Node2D
var preview_rect: ColorRect
var preview_arrow: ColorRect

var attack_timer = 0.0
var attack_rate = 0.5

var hotbar_slots = []
var position_history = []
var max_history = 200
var current_floor = 1
var max_floor = 0
var floor_nodes = {}
var floor_grids = {}

var grid = {} # 호환성 유지를 위해 빈 딕셔너리로 남겨둠 (거의 사용 안함)
var ui_canvas = null
var new_inventory_label = null
var status_label = null
var floor_label_ui = null

var upgrade_panel = null
var upg_buttons = []

var boss_hp_panel = null
var boss_hp_label = null

func _ready():
	GameManager.player = self
	
	if has_node("UI"):
		$UI.queue_free()
		
	_setup_ui()
	
	add_floor() # 1층 자동 추가
	
	if has_node("Camera2D"):
		$Camera2D.zoom = Vector2(0.6, 0.6) # 카메라 줌아웃 (거대 요새 시점)
		
	# 이동 요새 크기 설정 (5x5 그리드 = 320x320 픽셀)
	if has_node("CollisionShape2D"):
		var shape = $CollisionShape2D.shape
		if shape is RectangleShape2D:
			shape.size = Vector2(320, 320)
		elif shape is CircleShape2D:
			# 기존에 원형이었다면 사각형으로 변경
			var new_shape = RectangleShape2D.new()
			new_shape.size = Vector2(320, 320)
			$CollisionShape2D.shape = new_shape
			
	if has_node("Sprite2D"):
		$Sprite2D.visible = false # 기존 인간 스프라이트 숨김
		
	# 요새 배경 그리기 요청
	queue_redraw()
	
	build_preview = Node2D.new()
	preview_rect = ColorRect.new()
	preview_rect.size = Vector2(64, 64)
	preview_rect.position = Vector2(-32, -32)
	preview_rect.color = Color(1, 1, 1, 0.5)
	build_preview.add_child(preview_rect)
	
	preview_arrow = ColorRect.new()
	preview_arrow.size = Vector2(20, 10)
	preview_arrow.position = Vector2(12, -5)
	preview_arrow.color = Color(1, 1, 1, 0.9)
	build_preview.add_child(preview_arrow)
	
	build_preview.visible = false
	# 미리보기는 카메라 영향을 안 받도록 캔버스 레이어나 글로벌에 붙이지만, 지금은 플레이어 자식으로
	add_child(build_preview)
	
	update_ui()

func _draw():
	# 5x5 그리드의 거대 이동 요새 플랫폼 그리기
	var rect = Rect2(-160, -160, 320, 320)
	draw_rect(rect, Color(0.2, 0.2, 0.25, 0.9)) # 강철 바닥
	
	# 그리드 선 그리기
	for i in range(-2, 3):
		for j in range(-2, 3):
			var tile_rect = Rect2(i * 64 - 32, j * 64 - 32, 64, 64)
			draw_rect(tile_rect, Color(0.3, 0.3, 0.35, 1.0), false, 2.0)
			
	# 중앙 코어(넥서스 엔진) 그리기
	draw_circle(Vector2(0, 0), 20, Color(0.0, 1.0, 0.5, 0.8))

func _setup_ui():
	ui_canvas = CanvasLayer.new()
	get_tree().current_scene.add_child.call_deferred(ui_canvas)
	
	# 좌측 상단 자원 표시 패널
	var res_panel = ColorRect.new()
	res_panel.color = Color(0.1, 0.1, 0.1, 0.8)
	res_panel.size = Vector2(200, 150)
	res_panel.position = Vector2(20, 20)
	ui_canvas.add_child(res_panel)
	
	new_inventory_label = Label.new()
	new_inventory_label.position = Vector2(10, 10)
	res_panel.add_child(new_inventory_label)
	
	# 상단 중앙 넥서스/플레이어 상태
	var status_panel = ColorRect.new()
	status_panel.color = Color(0.1, 0.1, 0.1, 0.8)
	status_panel.size = Vector2(300, 60)
	var vp_size = get_viewport_rect().size
	status_panel.position = Vector2(vp_size.x / 2.0 - 150, 20)
	ui_canvas.add_child(status_panel)
	
	status_label = Label.new()
	status_label.position = Vector2(0, 0)
	status_label.size = status_panel.size
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_panel.add_child(status_label)
	
	# 보스 체력 표시 UI (기본 숨김)
	boss_hp_panel = ColorRect.new()
	boss_hp_panel.color = Color(0.8, 0.1, 0.1, 0.9) # 붉은색
	boss_hp_panel.size = Vector2(400, 40)
	boss_hp_panel.position = Vector2(vp_size.x / 2.0 - 200, 90)
	boss_hp_panel.visible = false
	ui_canvas.add_child(boss_hp_panel)
	
	boss_hp_label = Label.new()
	boss_hp_label.position = Vector2(0, 0)
	boss_hp_label.size = boss_hp_panel.size
	boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_hp_panel.add_child(boss_hp_label)
	
	# 층수 이동 UI (우측 하단)
	var floor_panel = ColorRect.new()
	floor_panel.color = Color(0.1, 0.1, 0.1, 0.8)
	floor_panel.size = Vector2(100, 150)
	floor_panel.position = Vector2(vp_size.x - 120, vp_size.y - 170)
	ui_canvas.add_child(floor_panel)
	
	floor_label_ui = Label.new()
	floor_label_ui.text = "1F"
	floor_label_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_label_ui.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	floor_label_ui.size = Vector2(100, 50)
	floor_label_ui.position = Vector2(0, 50)
	floor_label_ui.add_theme_font_size_override("font_size", 30)
	floor_panel.add_child(floor_label_ui)
	
	var btn_up = Button.new()
	btn_up.text = "▲"
	btn_up.size = Vector2(80, 40)
	btn_up.position = Vector2(10, 10)
	btn_up.pressed.connect(func(): change_floor(current_floor + 1))
	floor_panel.add_child(btn_up)
	
	var btn_down = Button.new()
	btn_down.text = "▼"
	btn_down.size = Vector2(80, 40)
	btn_down.position = Vector2(10, 100)
	btn_down.pressed.connect(func(): change_floor(current_floor - 1))
	floor_panel.add_child(btn_down)
	
	# 하단 중앙 핫바(Hotbar)
	var hotbar_bg = ColorRect.new()
	hotbar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	hotbar_bg.size = Vector2(430, 60)
	
	hotbar_bg.position = Vector2(vp_size.x / 2.0 - 215, vp_size.y - 80)
	ui_canvas.add_child(hotbar_bg)
	
	var colors = [Color(0.0, 0.3, 0.8), Color(0.8, 0.0, 0.0), Color(0.8, 0.8, 0.0), Color(1.0, 0.0, 1.0), Color(0.4, 0.4, 0.5), Color(0.0, 0.6, 0.8), Color(0.3, 0.2, 0.1), Color(0.2, 0.8, 0.2), Color(0.8, 0.5, 0.2), Color(0.5, 0.5, 0.5)]
	var names = ["1:기관총", "2:스나이퍼", "3:샷건", "4:레이저", "5:방벽", "6:수리소", "7:드릴", "8:공급기", "9:벨트", "0:가공소"]
	
	for i in range(10):
		var slot = ColorRect.new()
		slot.size = Vector2(60, 50)
		slot.position = Vector2(10 + i * 65, 5) # 간격 65로 줄여서 10개 배치
		slot.color = colors[i]
		hotbar_bg.add_child(slot)
		
		var outline = ReferenceRect.new()
		outline.editor_only = false
		outline.border_color = Color(1, 1, 1, 0)
		outline.border_width = 3.0
		outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(outline)
		
		var label = Label.new()
		label.text = names[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(label)
		
		hotbar_slots.append(outline)
		
	# 업그레이드 패널 (기본 숨김)
	upgrade_panel = ColorRect.new()
	upgrade_panel.color = Color(0.1, 0.1, 0.2, 0.95)
	upgrade_panel.size = Vector2(500, 400)
	upgrade_panel.position = Vector2(vp_size.x/2 - 250, vp_size.y/2 - 200)
	upgrade_panel.visible = false
	ui_canvas.add_child(upgrade_panel)
	
	var upg_title = Label.new()
	upg_title.text = "=== TECH TREE (단축키 U) ==="
	upg_title.position = Vector2(0, 20)
	upg_title.size = Vector2(500, 30)
	upg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_panel.add_child(upg_title)
	
	for i in range(4):
		var btn = Button.new()
		btn.size = Vector2(460, 60)
		btn.position = Vector2(20, 70 + i * 75)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_upgrade_btn_pressed.bind(i))
		upgrade_panel.add_child(btn)
		upg_buttons.append(btn)
		
	_update_upgrade_ui()

func _update_upgrade_ui():
	if upg_buttons.size() == 0: return
	
	var cost_stone_0 = 5 + (GameManager.upg_miner_speed_level * 2)
	var cost_brick_0 = 1 + (GameManager.upg_miner_speed_level * 1)
	upg_buttons[0].text = "[0] 드릴 속도 강화 Lv." + str(GameManager.upg_miner_speed_level) + "\n효과: 채굴 속도 10% 향상 | 비용: 돌 " + str(cost_stone_0) + ", 벽돌 " + str(cost_brick_0)
	
	var cost_stone_1 = 10 + (GameManager.upg_turret_damage_level * 5)
	var cost_core_1 = 1 + (GameManager.upg_turret_damage_level * 1)
	upg_buttons[1].text = "[1] 타워 대미지 강화 Lv." + str(GameManager.upg_turret_damage_level) + "\n효과: 타워 대미지 +1 | 비용: 돌 " + str(cost_stone_1) + ", 코어 " + str(cost_core_1)
	
	var cost_stone_2 = 15 + (GameManager.upg_player_hp_level * 2)
	var cost_core_2 = 2 + (GameManager.upg_player_hp_level * 1)
	upg_buttons[2].text = "[2] 요새 장갑 체력 강화 Lv." + str(GameManager.upg_player_hp_level) + "\n효과: 최대체력 +100 & 풀피 회복 | 비용: 돌 " + str(cost_stone_2) + ", 코어 " + str(cost_core_2)
	
	upg_buttons[3].text = "[3] 요새 수리 (일회성)\n효과: 요새 체력 +50 회복 | 비용: 돌 5"

func _on_upgrade_btn_pressed(index: int):
	var stone = inventory.get("stone", 0)
	var brick = inventory.get("stone_brick", 0)
	var core = inventory.get("monster_core", 0)
	
	if index == 0:
		var cost_stone = 5 + (GameManager.upg_miner_speed_level * 2)
		var cost_brick = 1 + (GameManager.upg_miner_speed_level * 1)
		if stone >= cost_stone and brick >= cost_brick:
			add_item("stone", -cost_stone)
			add_item("stone_brick", -cost_brick)
			GameManager.upg_miner_speed_level += 1
			print("드릴 강화 완료!")
			
	elif index == 1:
		var cost_stone = 10 + (GameManager.upg_turret_damage_level * 5)
		var cost_core = 1 + (GameManager.upg_turret_damage_level * 1)
		if stone >= cost_stone and core >= cost_core:
			add_item("stone", -cost_stone)
			add_item("monster_core", -cost_core)
			GameManager.upg_turret_damage_level += 1
			print("타워 강화 완료!")
			
	elif index == 2:
		var cost_stone = 15 + (GameManager.upg_player_hp_level * 2)
		var cost_core = 2 + (GameManager.upg_player_hp_level * 1)
		if stone >= cost_stone and core >= cost_core:
			add_item("stone", -cost_stone)
			add_item("monster_core", -cost_core)
			GameManager.upg_player_hp_level += 1
			max_hp += 100
			hp = max_hp
			print("요새 장갑 강화 완료!")
			
	elif index == 3:
		if stone >= 5:
			add_item("stone", -5)
			hp = min(max_hp, hp + 50)
			print("요새 수리 완료!")
	
	_update_upgrade_ui()
	update_ui()

func add_item(item_name, amount):
	if inventory.has(item_name):
		inventory[item_name] += amount
	else:
		inventory[item_name] = amount
	update_ui()

func accept_item(item) -> bool:
	add_item(item, 1)
	return true

func update_ui():
	if is_instance_valid(new_inventory_label):
		var wood_count = inventory.get("wood", 0)
		var stone_count = inventory.get("stone", 0)
		var brick_count = inventory.get("stone_brick", 0)
		var core_count = inventory.get("monster_core", 0)
		var iron_count = inventory.get("iron", 0)
		var steel_count = inventory.get("steel_plate", 0)
		new_inventory_label.text = "나무: " + str(wood_count) + "\n돌: " + str(stone_count) + "\n철광석(Iron): " + str(iron_count) + "\n강철 판재(Steel): " + str(steel_count) + "\n석재 벽돌: " + str(brick_count) + "\n몬스터 코어: " + str(core_count)
		
	if is_instance_valid(status_label):
		var s = "이동 요새 HP: " + str(max(0, hp)) + " / " + str(max_hp) + "\n"
		s += "웨이브 " + str(GameManager.current_wave) + " 진행 중!"
		status_label.text = s
		
	if is_instance_valid(boss_hp_panel) and is_instance_valid(boss_hp_label):
		if is_instance_valid(GameManager.boss) and not GameManager.boss.is_dead:
			boss_hp_panel.visible = true
			boss_hp_label.text = "보스 체력: " + str(max(0, GameManager.boss.hp)) + " / " + str(GameManager.boss.max_hp)
		else:
			boss_hp_panel.visible = false

func take_damage(amount):
	hp -= amount
	update_ui()
	
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color(5, 5, 5)
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(self) and has_node("Sprite2D"):
			$Sprite2D.modulate = Color(1, 1, 1)
			
	if hp <= 0:
		game_over()

func game_over():
	print("=== GAME OVER (요새 파괴됨) ===")
	get_tree().paused = true
	if is_instance_valid(status_label):
		status_label.text = "GAME OVER!\n이동 요새가 파괴되었습니다."
		status_label.modulate = Color(1, 0, 0)

func _physics_process(delta):
	# 부스터 로직
	if boost_timer > 0:
		boost_timer -= delta
		speed = base_speed * 3.0 # 부스터 사용 시 3배 속도
	else:
		speed = base_speed
		
	if boost_cooldown > 0:
		boost_cooldown -= delta
		
	if Input.is_physical_key_pressed(KEY_SHIFT) and boost_cooldown <= 0:
		boost_timer = 0.5 # 0.5초 지속
		boost_cooldown = 4.0 # 4초 쿨타임
		
	var direction = Vector2.ZERO
	
	if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		direction.y -= 1
		
	direction = direction.normalized()
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)

	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider != null and collider.has_method("gather"):
			collider.gather(self)
			
	# 위치 기록 (뱀파이어/스네이크 꼬리잡기용)
	handle_building()
	
	# 자동 공격 로직
	attack_timer -= delta
	if attack_timer <= 0:
		auto_attack()
		attack_timer = attack_rate

func auto_attack():
	var enemies = get_tree().get_nodes_in_group("enemy")
	var closest_enemy = null
	var min_dist = 500.0 # 최대 사거리
	
	for e in enemies:
		var dist = global_position.distance_to(e.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_enemy = e
			
	if closest_enemy:
		var proj = projectile_scene.instantiate()
		proj.global_position = global_position
		proj.direction = global_position.direction_to(closest_enemy.global_position)
		get_parent().add_child(proj)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: set_build_type(1)
		elif event.keycode == KEY_2: set_build_type(2)
		elif event.keycode == KEY_3: set_build_type(3)
		elif event.keycode == KEY_4: set_build_type(4)
		elif event.keycode == KEY_5: set_build_type(5)
		elif event.keycode == KEY_6: set_build_type(6)
		elif event.keycode == KEY_7: set_build_type(7)
		elif event.keycode == KEY_8: set_build_type(8)
		elif event.keycode == KEY_9: set_build_type(9)
		elif event.keycode == KEY_0: set_build_type(10)
		elif event.keycode == KEY_ESCAPE: set_build_type(0)
		elif event.keycode == KEY_U:
			upgrade_panel.visible = not upgrade_panel.visible
		elif event.keycode == KEY_R:
			if build_direction == Vector2i.RIGHT: build_direction = Vector2i.DOWN
			elif build_direction == Vector2i.DOWN: build_direction = Vector2i.LEFT
			elif build_direction == Vector2i.LEFT: build_direction = Vector2i.UP
			elif build_direction == Vector2i.UP: build_direction = Vector2i.RIGHT
			
			if is_instance_valid(preview_arrow):
				if build_direction == Vector2i.RIGHT: preview_arrow.rotation = 0
				elif build_direction == Vector2i.DOWN: preview_arrow.rotation = PI/2
				elif build_direction == Vector2i.LEFT: preview_arrow.rotation = PI
				elif build_direction == Vector2i.UP: preview_arrow.rotation = -PI/2
		elif event.keycode == KEY_SPACE:
			interact_with_resource()
		elif event.keycode == KEY_B:
			build_furnace()

func set_build_type(type):
	build_type = type
	if build_type == 0:
		if is_instance_valid(build_preview): build_preview.visible = false
	else:
		if is_instance_valid(build_preview): build_preview.visible = true
		if build_type == 1: preview_rect.color = Color(0.0, 0.3, 0.8, 0.5)
		elif build_type == 2: preview_rect.color = Color(0.8, 0.0, 0.0, 0.5)
		elif build_type == 3: preview_rect.color = Color(0.8, 0.8, 0.0, 0.5)
		elif build_type == 4: preview_rect.color = Color(1.0, 0.0, 1.0, 0.5) # 레이저
		elif build_type == 5: preview_rect.color = Color(0.4, 0.4, 0.5, 0.5) # 방벽
		elif build_type == 6: preview_rect.color = Color(0.0, 0.6, 0.8, 0.5) # 수리소
		elif build_type == 7: preview_rect.color = Color(0.3, 0.2, 0.1, 0.5) # 드릴
		elif build_type == 8: preview_rect.color = Color(0.2, 0.8, 0.2, 0.5) # 공급기
		elif build_type == 9: preview_rect.color = Color(0.8, 0.5, 0.2, 0.5) # 벨트
		elif build_type == 10: preview_rect.color = Color(0.5, 0.5, 0.5, 0.5) # 가공소
	
	# UI 하이라이트 업데이트
	for i in range(hotbar_slots.size()):
		if type - 1 == i:
			hotbar_slots[i].border_color = Color(1, 1, 0, 1) # 선택됨 (노란 테두리)
		else:
			hotbar_slots[i].border_color = Color(1, 1, 1, 0) # 투명

func get_hovered_fortress():
	var mouse_pos = get_global_mouse_position()
	# 메인 요새 반경 확장 (기존 160 -> 250, 외부 부착물 3칸 포함)
	if mouse_pos.distance_to(global_position) <= 250:
		return self
	return null

func handle_building():
	if build_type == 0: return
	if not is_instance_valid(build_preview): return
	
	var target = get_hovered_fortress()
	if target == null:
		build_preview.visible = false
		return
	else:
		build_preview.visible = true
		
	var target_local_pos = target.to_local(get_global_mouse_position())
	var grid_pos = FactoryManager.get_local_grid_pos(target_local_pos)
	
	var max_grid = 2 # 5x5 (player)
		
	var is_internal = (build_type >= 1 and build_type <= 4) or (build_type >= 8 and build_type <= 10)
	var is_external = (build_type >= 5 and build_type <= 7)
	
	var is_inside = abs(grid_pos.x) <= max_grid and abs(grid_pos.y) <= max_grid
	var is_outer_ring = max(abs(grid_pos.x), abs(grid_pos.y)) == max_grid + 1
	
	var valid_placement = false
	if is_internal and is_inside:
		valid_placement = true
	elif is_external and is_outer_ring:
		valid_placement = true
		
	if not valid_placement:
		if is_instance_valid(preview_rect):
			preview_rect.color = Color(1, 0, 0, 0.5) # 건설 불가 (빨간색)
		return
	
	if is_instance_valid(preview_rect):
		if build_type == 1: preview_rect.color = Color(0.0, 0.3, 0.8, 0.5)
		elif build_type == 2: preview_rect.color = Color(0.8, 0.0, 0.0, 0.5)
		elif build_type == 3: preview_rect.color = Color(0.8, 0.8, 0.0, 0.5)
		elif build_type == 4: preview_rect.color = Color(1.0, 0.0, 1.0, 0.5)
		elif build_type == 5: preview_rect.color = Color(0.4, 0.4, 0.5, 0.5)
		elif build_type == 6: preview_rect.color = Color(0.0, 0.6, 0.8, 0.5)
		elif build_type == 7: preview_rect.color = Color(0.3, 0.2, 0.1, 0.5)
		elif build_type == 8: preview_rect.color = Color(0.2, 0.8, 0.2, 0.5)
		elif build_type == 9: preview_rect.color = Color(0.8, 0.5, 0.2, 0.5)
		elif build_type == 10: preview_rect.color = Color(0.5, 0.5, 0.5, 0.5)
	
	var local_pos = FactoryManager.get_local_pos(grid_pos)
	build_preview.global_position = target.to_global(local_pos)
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not floor_grids[current_floor].has(grid_pos):
			var building = null
			
			if build_type == 1: 
				if inventory.get("wood", 0) >= 5 and inventory.get("stone", 0) >= 5:
					building = turret_scene.instantiate()
					add_item("wood", -5)
					add_item("stone", -5)
				else:
					print("자원 부족: 나무 5, 돌 5 필요 (기관총)")
			elif build_type == 2: 
				if inventory.get("stone", 0) >= 15:
					var sniper_script = preload("res://scripts/sniper_turret.gd")
					building = sniper_script.new()
					add_item("stone", -15)
				else:
					print("자원 부족: 돌 15 필요 (스나이퍼)")
			elif build_type == 3: 
				if inventory.get("wood", 0) >= 15:
					var shotgun_script = preload("res://scripts/shotgun_turret.gd")
					building = shotgun_script.new()
					add_item("wood", -15)
				else:
					print("자원 부족: 나무 15 필요 (샷건)")
			elif build_type == 4:
				if inventory.get("steel_plate", 0) >= 10 and inventory.get("monster_core", 0) >= 5:
					var laser_script = preload("res://scripts/laser_turret.gd")
					building = laser_script.new()
					add_item("steel_plate", -10)
					add_item("monster_core", -5)
				else:
					print("자원 부족: 강철 10, 코어 5 필요 (레이저 타워)")
			elif build_type == 5:
				if inventory.get("stone", 0) >= 10:
					var bar_script = preload("res://scripts/barricade.gd")
					building = bar_script.new()
					add_item("stone", -10)
				else:
					print("자원 부족: 돌 10 필요 (방벽)")
			elif build_type == 6:
				if inventory.get("wood", 0) >= 20 and inventory.get("stone", 0) >= 10:
					var rep_script = preload("res://scripts/repair_station.gd")
					building = rep_script.new()
					add_item("wood", -20)
					add_item("stone", -10)
				else:
					print("자원 부족: 나무 20, 돌 10 필요 (수리소)")
			elif build_type == 7:
				if inventory.get("monster_core", 0) >= 10 and inventory.get("stone", 0) >= 20:
					var dr_script = preload("res://scripts/drill.gd")
					building = dr_script.new()
					add_item("monster_core", -10)
					add_item("stone", -20)
				else:
					print("자원 부족: 코어 10, 돌 20 필요 (드릴)")
			elif build_type == 8:
				if inventory.get("wood", 0) >= 5 and inventory.get("stone", 0) >= 5:
					var prov_script = preload("res://scripts/provider.gd")
					building = prov_script.new()
					add_item("wood", -5)
					add_item("stone", -5)
				else:
					print("자원 부족: 나무 5, 돌 5 필요 (공급기)")
			elif build_type == 9:
				if inventory.get("wood", 0) >= 2:
					var belt_script = preload("res://scripts/belt.gd")
					building = belt_script.new()
					add_item("wood", -2)
				else:
					print("자원 부족: 나무 2 필요 (벨트)")
			elif build_type == 10:
				if inventory.get("stone", 0) >= 15 and inventory.get("monster_core", 0) >= 2:
					var proc_script = preload("res://scripts/processor.gd")
					building = proc_script.new()
					add_item("stone", -15)
					add_item("monster_core", -2)
				else:
					print("자원 부족: 돌 15, 코어 2 필요 (가공소)")
				
			if building:
				if "grid_pos" in building: building.grid_pos = grid_pos
				if "direction" in building: building.direction = build_direction
				if "floor_index" in building: building.floor_index = current_floor
				building.position = local_pos
				
				if build_direction == Vector2i.RIGHT: building.rotation = 0
				elif build_direction == Vector2i.DOWN: building.rotation = PI/2
				elif build_direction == Vector2i.LEFT: building.rotation = PI
				elif build_direction == Vector2i.UP: building.rotation = -PI/2
				
				floor_nodes[current_floor].add_child(building)
				floor_grids[current_floor][grid_pos] = building
				
				# 건설 후 건설 모드 종료 (미리보기 숨김)
				set_build_type(0)
				
	# 철거 로직 (마우스 우클릭)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if floor_grids[current_floor].has(grid_pos):
			var target_building = floor_grids[current_floor][grid_pos]
			if is_instance_valid(target_building):
				target_building.queue_free()
			floor_grids[current_floor].erase(grid_pos)

func build_furnace():
	var wood = inventory.get("wood", 0)
	var stone = inventory.get("stone", 0)
	
	if wood >= 2 and stone >= 2:
		# 자원 차감
		add_item("wood", -2)
		add_item("stone", -2)
		
		# 화로 생성
		var furnace = furnace_scene.instantiate()
		furnace.global_position = global_position + Vector2(0, -64) # 플레이어 살짝 위에 배치
		get_parent().add_child(furnace)
		print("화로를 건설했습니다!")
	else:
		print("자원이 부족합니다. (나무 2개, 돌 2개 필요)")

func destroy_buildings_in_radius(world_pos: Vector2, radius: float):
	var destroyed_count = 0
	for f in floor_grids.keys():
		var grid = floor_grids[f]
		var keys_to_erase = []
		for g_pos in grid.keys():
			var building = grid[g_pos]
			if is_instance_valid(building):
				if building.global_position.distance_to(world_pos) <= radius:
					building.queue_free()
					keys_to_erase.append(g_pos)
					destroyed_count += 1
		for k in keys_to_erase:
			grid.erase(k)
	return destroyed_count

func interact_with_resource():
	var interact_range = 80.0
	var closest_resource = null
	var closest_dist = interact_range
	
	var resources = get_tree().get_nodes_in_group("resource")
	for res in resources:
		var dist = global_position.distance_to(res.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_resource = res
			
	if closest_resource != null:
		closest_resource.gather(self)

func add_floor():
	max_floor += 1
	
	var floor_node = Node2D.new()
	floor_node.name = "Floor" + str(max_floor)
	add_child(floor_node)
	
	floor_nodes[max_floor] = floor_node
	floor_grids[max_floor] = {}
	
	print(str(max_floor) + "층이 증축되었습니다!")
	
	# 새로운 층으로 자동 이동
	change_floor(max_floor)

func change_floor(target_floor):
	if target_floor < 1 or target_floor > max_floor:
		return
		
	current_floor = target_floor
	
	if floor_label_ui:
		floor_label_ui.text = str(current_floor) + "F"
		
	for f in floor_nodes:
		if f == current_floor:
			floor_nodes[f].visible = true
		else:
			floor_nodes[f].visible = false
	
	print("현재 층: " + str(current_floor) + "F")
