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

var shake_intensity = 0.0
var build_menu_panel = null
var upgrade_card_panel = null
var active_build_label = null

# --- 컨텍스트 UI ---
var building_context_panel = null
var context_title_label = null
var btn_upgrade = null
var btn_move = null
var btn_demolish = null
var filter_option = null
var selected_building = null
var moving_building = null
var moving_grid_pos = Vector2i()

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
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_rect.size = Vector2(64, 64)
	preview_rect.position = Vector2(-32, -32)
	preview_rect.color = Color(1, 1, 1, 0.5)
	build_preview.add_child(preview_rect)
	
	preview_arrow = ColorRect.new()
	preview_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	
	# 하단 중앙 건설 메뉴 토글 버튼
	var btn_build_menu = Button.new()
	btn_build_menu.text = "건설 메뉴 [B]"
	btn_build_menu.size = Vector2(150, 50)
	btn_build_menu.position = Vector2(vp_size.x / 2.0 - 75, vp_size.y - 60)
	btn_build_menu.pressed.connect(func(): toggle_build_menu())
	ui_canvas.add_child(btn_build_menu)
	
	# 현재 선택된 건물 표시 레이블
	active_build_label = Label.new()
	active_build_label.text = "현재 선택: 없음"
	active_build_label.position = Vector2(vp_size.x / 2.0 - 100, vp_size.y - 90)
	active_build_label.size = Vector2(200, 30)
	active_build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_canvas.add_child(active_build_label)
	
	# 건설 메뉴 패널
	build_menu_panel = ColorRect.new()
	build_menu_panel.color = Color(0.1, 0.1, 0.15, 0.95)
	build_menu_panel.size = Vector2(400, 300)
	build_menu_panel.position = Vector2(vp_size.x / 2.0 - 200, vp_size.y / 2.0 - 150)
	build_menu_panel.visible = false
	ui_canvas.add_child(build_menu_panel)
	
	var build_title = Label.new()
	build_title.text = "건설 항목 선택 (우클릭: 철거)"
	build_title.position = Vector2(0, 10)
	build_title.size = Vector2(400, 30)
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_menu_panel.add_child(build_title)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(20, 50)
	grid.size = Vector2(360, 240)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	build_menu_panel.add_child(grid)
	
	var colors = [Color(0.0, 0.3, 0.8), Color(0.8, 0.0, 0.0), Color(0.8, 0.8, 0.0), Color(1.0, 0.0, 1.0), Color(0.4, 0.4, 0.5), Color(0.0, 0.6, 0.8), Color(0.3, 0.2, 0.1), Color(0.2, 0.8, 0.2), Color(0.8, 0.5, 0.2), Color(0.5, 0.5, 0.5)]
	var names = [
		"1:기관총\n(나무5,돌5)", 
		"2:스나이퍼\n(돌15)", 
		"3:샷건\n(나무15)", 
		"4:레이저\n(강철10,코어5)", 
		"5:방벽\n(돌10)", 
		"6:수리소\n(나무20,돌10)", 
		"7:드릴\n(돌20,코어10)", 
		"8:공급기\n(나무5,돌5)", 
		"9:벨트\n(나무2)", 
		"0:가공소\n(돌15,코어2)",
		"-:미사일\n(강철5,코어10)"
	]
	var type_ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
	
	for i in range(11):
		var btn = Button.new()
		btn.text = names[i]
		btn.custom_minimum_size = Vector2(110, 60)
		# 람다 캡처 문제 해결을 위해 bind 사용
		btn.pressed.connect(select_build_type.bind(type_ids[i], names[i]))
		grid.add_child(btn)
		
	# 로그라이트 업그레이드 선택 패널
	upgrade_card_panel = ColorRect.new()
	upgrade_card_panel.color = Color(0, 0, 0, 0.85)
	upgrade_card_panel.size = get_viewport_rect().size
	upgrade_card_panel.visible = false
	upgrade_card_panel.process_mode = Node.PROCESS_MODE_ALWAYS # 일시정지 중에도 동작
	ui_canvas.add_child(upgrade_card_panel)
		
	# 업그레이드 패널 (기본 숨김)
	upgrade_panel = ColorRect.new()
	upgrade_panel.color = Color(0.1, 0.1, 0.2, 0.95)
	upgrade_panel.size = Vector2(500, 400)
	upgrade_panel.position = Vector2(vp_size.x/2 - 250, vp_size.y/2 - 200)
	upgrade_panel.visible = false
	ui_canvas.add_child(upgrade_panel)
	
	# --- 건물 컨텍스트 UI ---
	building_context_panel = ColorRect.new()
	building_context_panel.color = Color(0.1, 0.1, 0.15, 0.95)
	building_context_panel.size = Vector2(200, 230)
	building_context_panel.visible = false
	ui_canvas.add_child(building_context_panel)
	
	context_title_label = Label.new()
	context_title_label.position = Vector2(10, 10)
	context_title_label.text = "건물 이름 (Lv.1)"
	building_context_panel.add_child(context_title_label)
	
	btn_upgrade = Button.new()
	btn_upgrade.text = "업그레이드"
	btn_upgrade.position = Vector2(10, 40)
	btn_upgrade.size = Vector2(180, 40)
	btn_upgrade.pressed.connect(_on_btn_upgrade)
	building_context_panel.add_child(btn_upgrade)
	
	btn_move = Button.new()
	btn_move.text = "이동"
	btn_move.position = Vector2(10, 90)
	btn_move.size = Vector2(180, 40)
	btn_move.pressed.connect(_on_btn_move)
	building_context_panel.add_child(btn_move)
	
	btn_demolish = Button.new()
	btn_demolish.text = "철거 (자원 50% 반환)"
	btn_demolish.position = Vector2(10, 140)
	btn_demolish.size = Vector2(180, 40)
	btn_demolish.pressed.connect(_on_btn_demolish)
	building_context_panel.add_child(btn_demolish)
	
	filter_option = OptionButton.new()
	filter_option.position = Vector2(10, 190)
	filter_option.size = Vector2(180, 30)
	filter_option.add_item("자동", 0)
	filter_option.add_item("철광석", 1)
	filter_option.add_item("돌", 2)
	filter_option.add_item("나무", 3)
	filter_option.add_item("정지", 4)
	filter_option.item_selected.connect(_on_filter_selected)
	building_context_panel.add_child(filter_option)
	
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

func _process(delta):
	# 카메라 쉐이크 처리
	if has_node("Camera2D"):
		if shake_intensity > 0:
			$Camera2D.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
			shake_intensity = lerp(shake_intensity, 0.0, 10.0 * delta)
			if shake_intensity < 0.1:
				shake_intensity = 0
				$Camera2D.offset = Vector2.ZERO

func _physics_process(delta):
	_process_movement(delta)

func _process_movement(delta):
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if build_type == 0 and moving_building == null:
			var target = get_hovered_fortress()
			if target != null:
				var mouse_world_pos = get_canvas_transform().affine_inverse() * event.position
				var target_local_pos = target.to_local(mouse_world_pos)
				var grid_pos = FactoryManager.get_local_grid_pos(target_local_pos)
				if floor_grids[current_floor].has(grid_pos):
					open_context_ui(floor_grids[current_floor][grid_pos])
				else:
					if is_instance_valid(building_context_panel): building_context_panel.visible = false
			else:
				if is_instance_valid(building_context_panel): building_context_panel.visible = false

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: select_build_type(1, "1:기관총")
		elif event.keycode == KEY_2: select_build_type(2, "2:스나이퍼")
		elif event.keycode == KEY_3: select_build_type(3, "3:샷건")
		elif event.keycode == KEY_4: select_build_type(4, "4:레이저")
		elif event.keycode == KEY_5: select_build_type(5, "5:방벽")
		elif event.keycode == KEY_6: select_build_type(6, "6:수리소")
		elif event.keycode == KEY_7: select_build_type(7, "7:드릴")
		elif event.keycode == KEY_8: select_build_type(8, "8:공급기")
		elif event.keycode == KEY_9: select_build_type(9, "9:벨트")
		elif event.keycode == KEY_0: select_build_type(10, "0:가공소")
		elif event.keycode == KEY_MINUS: select_build_type(11, "-:미사일(폭발형)")
		elif event.keycode == KEY_ESCAPE: select_build_type(0, "현재 선택: 없음")
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
			toggle_build_menu()

func toggle_build_menu():
	if is_instance_valid(build_menu_panel):
		build_menu_panel.visible = not build_menu_panel.visible

func select_build_type(type: int, name: String):
	set_build_type(type)
	if is_instance_valid(active_build_label):
		active_build_label.text = "현재 선택: " + name
	if is_instance_valid(build_menu_panel):
		build_menu_panel.visible = false

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
		elif build_type == 11: preview_rect.color = Color(0.8, 0.3, 0.1, 0.5) # 미사일
	
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
		
	var check_type = build_type
	if build_type == -1 and is_instance_valid(moving_building):
		check_type = moving_building.get_meta("build_type_id") if moving_building.has_meta("build_type_id") else 1
		
	var is_internal = (check_type >= 1 and check_type <= 4) or (check_type >= 8 and check_type <= 11)
	var is_external = (check_type >= 5 and check_type <= 7)
	
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
		if check_type == 1: preview_rect.color = Color(0.0, 0.3, 0.8, 0.5)
		elif check_type == 2: preview_rect.color = Color(0.8, 0.0, 0.0, 0.5)
		elif check_type == 3: preview_rect.color = Color(0.8, 0.8, 0.0, 0.5)
		elif check_type == 4: preview_rect.color = Color(1.0, 0.0, 1.0, 0.5)
		elif check_type == 5: preview_rect.color = Color(0.4, 0.4, 0.5, 0.5)
		elif check_type == 6: preview_rect.color = Color(0.0, 0.6, 0.8, 0.5)
		elif check_type == 7: preview_rect.color = Color(0.3, 0.2, 0.1, 0.5)
		elif check_type == 8: preview_rect.color = Color(0.2, 0.8, 0.2, 0.5)
		elif check_type == 9: preview_rect.color = Color(0.8, 0.5, 0.2, 0.5)
		elif check_type == 10: preview_rect.color = Color(0.5, 0.5, 0.5, 0.5)
		elif check_type == 11: preview_rect.color = Color(0.8, 0.3, 0.1, 0.5) # 미사일 (다크 오렌지)
		
		if build_type == -1: preview_rect.color = Color(1.0, 1.0, 1.0, 0.5) # 이동 모드는 반투명 흰색도 괜찮지만 check_type 따라감
	
	var local_pos = FactoryManager.get_local_pos(grid_pos)
	build_preview.global_position = target.to_global(local_pos)
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not floor_grids[current_floor].has(grid_pos):
			if build_type == -1 and is_instance_valid(moving_building):
				moving_building.grid_pos = grid_pos
				if "floor_index" in moving_building: moving_building.floor_index = current_floor
				moving_building.position = local_pos
				floor_grids[current_floor][grid_pos] = moving_building
				
				moving_building = null
				build_type = 0
				if is_instance_valid(build_preview): build_preview.visible = false
				return
				
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
			elif build_type == 11:
				if inventory.get("steel_plate", 0) >= 5 and inventory.get("monster_core", 0) >= 10:
					var missile_script = preload("res://scripts/missile_turret.gd")
					building = missile_script.new()
					add_item("steel_plate", -5)
					add_item("monster_core", -10)
				else:
					print("자원 부족: 강철 5, 코어 10 필요 (미사일 타워)")
				
			if building:
				if "grid_pos" in building: building.grid_pos = grid_pos
				if "direction" in building: building.direction = build_direction
				if "floor_index" in building: building.floor_index = current_floor
				
				# 건물 메타데이터 설정
				building.set_meta("level", 1)
				building.set_meta("build_type_id", build_type)
				var b_names = ["", "기관총", "스나이퍼", "샷건", "레이저", "방벽", "수리소", "드릴", "공급기", "벨트", "가공소", "미사일"]
				if build_type > 0 and build_type < b_names.size():
					building.set_meta("b_name", b_names[build_type])
				
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

func add_camera_shake(intensity: float):
	shake_intensity = max(shake_intensity, intensity)

func destroy_buildings_in_radius(world_pos: Vector2, radius: float):
	var destroyed_count = 0
	for f in floor_grids.keys():
		var grid = floor_grids[f]
		var keys_to_erase = []
		for g_pos in grid.keys():
			var building = grid[g_pos]
			if is_instance_valid(building):
				if building.global_position.distance_to(world_pos) <= radius:
					var survive_chance = 0.3 # 일반 건물은 30% 확률로 생존
					
					# 방벽 등 자체 체력(내구도)이 있는 방어형 건물은 생존 확률이 80%로 높음
					if building.has_method("take_damage"):
						survive_chance = 0.8
						
					if randf() > survive_chance:
						building.queue_free()
						keys_to_erase.append(g_pos)
						destroyed_count += 1
					else:
						# 살아남았을 경우 시각적 피격 효과 부여
						if "modulate" in building:
							building.modulate = Color(2.0, 1.0, 1.0)
							var tween = get_tree().create_tween()
							tween.tween_property(building, "modulate", Color(1, 1, 1), 0.3)
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
	current_floor += 1
	max_floor += 1
	
	var floor_node = Node2D.new()
	floor_nodes[max_floor] = floor_node
	add_child(floor_node)
	floor_grids[max_floor] = {}
	
	change_floor(max_floor)
	print(str(max_floor) + "층이 추가되었습니다!")

func show_upgrade_selection():
	if not is_instance_valid(upgrade_card_panel): return
	
	# 게임 일시정지
	get_tree().paused = true
	upgrade_card_panel.visible = true
	
	# 기존 UI 찌꺼기 제거
	for child in upgrade_card_panel.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "보스 처치 보상! 업그레이드를 선택하세요"
	title.position = Vector2(0, 100)
	title.size = Vector2(get_viewport_rect().size.x, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	upgrade_card_panel.add_child(title)
	
	var hbox = HBoxContainer.new()
	hbox.size = Vector2(900, 400)
	hbox.position = Vector2(get_viewport_rect().size.x / 2.0 - 450, 200)
	hbox.add_theme_constant_override("separation", 30)
	upgrade_card_panel.add_child(hbox)
	
	var all_options = [
		{"id": "floor", "title": "[구조물] 층 증축", "desc": "요새의 층수를 1층 올립니다.\n디메리트: 기본 이동 속도 15% 감소"},
		{"id": "speed", "title": "[기동성] 엔진 오버클럭", "desc": "요새의 기본 이동 속도가 20% 증가합니다."},
		{"id": "hp", "title": "[방어] 티타늄 장갑", "desc": "요새의 최대 HP가 300 증가하고,\n현재 HP를 300 회복합니다."},
		{"id": "range", "title": "[화력] 고급 조준경", "desc": "모든 공격 타워의 사거리가 20% 증가합니다."},
		{"id": "damage", "title": "[화력] 철갑탄", "desc": "모든 공격 타워의 데미지가 20% 증가합니다."},
		{"id": "drill", "title": "[생산] 초정밀 드릴", "desc": "드릴의 자원 채굴 속도가 20% 빨라집니다."}
	]
	
	all_options.shuffle()
	var selected = all_options.slice(0, 3)
	
	for opt in selected:
		var card = Button.new()
		card.custom_minimum_size = Vector2(280, 400)
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 30)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(vbox)
		
		var l_title = Label.new()
		l_title.text = "\n" + opt["title"]
		l_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_title.add_theme_font_size_override("font_size", 22)
		l_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(l_title)
		
		var l_desc = Label.new()
		l_desc.text = opt["desc"]
		l_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l_desc.custom_minimum_size = Vector2(260, 200)
		l_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(l_desc)
		
		card.pressed.connect(func(): _apply_upgrade(opt["id"]))
		hbox.add_child(card)

func _apply_upgrade(id: String):
	if id == "floor":
		add_floor()
		GameManager.stat_speed_mult *= 0.85
	elif id == "speed":
		GameManager.stat_speed_mult *= 1.2
	elif id == "hp":
		max_hp += 300
		hp += 300
	elif id == "range":
		GameManager.stat_range_mult *= 1.2
	elif id == "damage":
		GameManager.stat_damage_mult *= 1.2
	elif id == "drill":
		GameManager.stat_drill_mult *= 0.8 # 간격이 줄어야 빨라짐
		
	base_speed = 100.0 * GameManager.stat_speed_mult
	
	upgrade_card_panel.visible = false
	get_tree().paused = false
	update_ui()
	
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

func open_context_ui(building, refresh = false):
	selected_building = building
	building_context_panel.visible = true
	
	if not refresh:
		var mouse_pos = get_viewport().get_mouse_position()
		
		var vp_size = get_viewport_rect().size
		if mouse_pos.x + 200 > vp_size.x: mouse_pos.x -= 220
		else: mouse_pos.x += 20
		if mouse_pos.y + 230 > vp_size.y: mouse_pos.y -= 230
		else: mouse_pos.y += 20
		
		building_context_panel.position = mouse_pos
	
	var b_name = building.get_meta("b_name") if building.has_meta("b_name") else "건물"
	var b_level = building.get_meta("level") if building.has_meta("level") else 1
	context_title_label.text = b_name + " (Lv." + str(b_level) + ")"
	
	var cost_core = b_level * 5
	btn_upgrade.text = "업그레이드\n(코어 " + str(cost_core) + ")"
	
	if b_name == "공급기":
		filter_option.visible = true
		building_context_panel.size.y = 230
		filter_option.selected = building.get_meta("filter_idx") if building.has_meta("filter_idx") else 0
	else:
		filter_option.visible = false
		building_context_panel.size.y = 190

func _on_btn_upgrade():
	if not is_instance_valid(selected_building): return
	var b_level = selected_building.get_meta("level") if selected_building.has_meta("level") else 1
	var cost_core = b_level * 5
	if inventory.get("monster_core", 0) >= cost_core:
		add_item("monster_core", -cost_core)
		selected_building.set_meta("level", b_level + 1)
		open_context_ui(selected_building, true)
	else:
		print("코어가 부족합니다!")

func _on_btn_move():
	if not is_instance_valid(selected_building): return
	moving_building = selected_building
	moving_grid_pos = selected_building.grid_pos
	building_context_panel.visible = false
	
	# 임시로 그리드에서 제거 (이동 중)
	if floor_grids[current_floor].has(moving_grid_pos):
		floor_grids[current_floor].erase(moving_grid_pos)
		
	# 이동 상태 설정
	build_type = -1 # 이동 모드
	if is_instance_valid(build_preview): build_preview.visible = true
	# 이동할 건물을 안보이게 처리하거나 투명하게 할 수 있지만, 여기서는 그대로 둡니다.

func _on_btn_demolish():
	if not is_instance_valid(selected_building): return
	var b_pos = selected_building.grid_pos
	if floor_grids[current_floor].has(b_pos):
		floor_grids[current_floor].erase(b_pos)
	selected_building.queue_free()
	selected_building = null
	building_context_panel.visible = false
	
	# 자원 50% 환불 (임시로 코어 2개)
	add_item("monster_core", 2)

func _on_filter_selected(index):
	if is_instance_valid(selected_building) and selected_building.get_meta("b_name") == "공급기":
		selected_building.set_meta("filter_idx", index)
