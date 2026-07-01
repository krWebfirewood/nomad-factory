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

var joystick_bg = null
var joystick_knob = null
var joystick_active = false
var joystick_touch_id = -1
var joystick_vector = Vector2.ZERO
var joystick_center = Vector2.ZERO
var build_pressed_this_frame = false
var mobile_action_btn = null
var btn_dash = null
var btn_orbital = null
var btn_cancel = null
var last_action_time = 0

var attack_timer = 0.0
var attack_rate = 0.5

var hotbar_slots = []
var hotbar_buttons = {}
var position_history = []
var max_history = 200

var unlocked_towers = [1, 2, 3, 5, 6, 7, 8, 9, 10] # 4(레이저), 11(미사일) 잠김

var active_relics = {
	"vampire": false,
	"overclock": false,
	"orbital_strike": false
}
var orbital_cooldown = 0.0
var overclock_timer = 0.0
var is_overclocked = false
var is_dead = false

var pause_panel
var floor_nodes = {}
var floor_grids = {}
var current_floor = 1
var max_floor = 0

var grid = {} # 호환성 유지를 위해 빈 딕셔너리로 남겨둠 (거의 사용 안함)
var ui_canvas = null
var new_inventory_label = null
var cooldown_label = null
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

func create_mobile_ui():
	var vp_size = get_viewport_rect().size
	joystick_bg = ColorRect.new()
	joystick_bg.size = Vector2(240, 240)
	joystick_bg.position = Vector2(50, vp_size.y - 290)
	joystick_bg.color = Color(1, 1, 1, 0.2)
	ui_canvas.add_child(joystick_bg)
	joystick_center = joystick_bg.position + joystick_bg.size / 2.0
	
	joystick_knob = ColorRect.new()
	joystick_knob.size = Vector2(100, 100)
	joystick_knob.position = joystick_center - joystick_knob.size / 2.0
	joystick_knob.color = Color(1, 1, 1, 0.5)
	ui_canvas.add_child(joystick_knob)
	
	var btn_size = Vector2(120, 120)
	# floor_panel이 vp_size.x - 120 에 있으므로, 안 겹치게 더 왼쪽으로 이동
	var right_margin = vp_size.x - 260
	var bottom_margin = vp_size.y - 150
	mobile_action_btn = Button.new()
	mobile_action_btn.text = "건설"
	mobile_action_btn.size = btn_size
	mobile_action_btn.position = Vector2(right_margin, bottom_margin)
	mobile_action_btn.focus_mode = Control.FOCUS_NONE
	mobile_action_btn.add_theme_font_size_override("font_size", 28)
	ui_canvas.add_child(mobile_action_btn)
	
	btn_dash = Button.new()
	btn_dash.text = "대쉬 [Shift]"
	btn_dash.size = btn_size
	btn_dash.position = Vector2(right_margin - 140, bottom_margin)
	btn_dash.focus_mode = Control.FOCUS_NONE
	btn_dash.add_theme_font_size_override("font_size", 24)
	ui_canvas.add_child(btn_dash)
	
	btn_orbital = Button.new()
	btn_orbital.text = "폭격 [F]"
	btn_orbital.size = btn_size
	btn_orbital.position = Vector2(right_margin - 280, bottom_margin)
	btn_orbital.focus_mode = Control.FOCUS_NONE
	btn_orbital.add_theme_font_size_override("font_size", 24)
	btn_orbital.visible = false
	ui_canvas.add_child(btn_orbital)
	
	btn_cancel = Button.new()
	btn_cancel.text = "취소"
	btn_cancel.size = btn_size
	btn_cancel.position = Vector2(right_margin, bottom_margin - 140)
	btn_cancel.focus_mode = Control.FOCUS_NONE
	btn_cancel.add_theme_font_size_override("font_size", 28)
	btn_cancel.visible = false
	ui_canvas.add_child(btn_cancel)

func use_dash():
	if boost_cooldown <= 0:
		boost_timer = 0.5
		boost_cooldown = 4.0

func use_orbital_strike():
	if active_relics.get("orbital_strike", false) and orbital_cooldown <= 0:
		cast_orbital_strike()

func _on_mobile_action_pressed():
	var current_time = Time.get_ticks_msec()
	if current_time - last_action_time < 100:
		return
	last_action_time = current_time
	
	if build_type == 0:
		toggle_build_menu()
	else:
		rotate_building()
func _ready():
	add_to_group("player")
	GameManager.player = self
	GameManager.apply_meta_upgrades()
	
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
	
	# 건설 모드 시 설치 가능 구역 하이라이트 표시
	if build_type != 0 or is_instance_valid(moving_building):
		var check_type = build_type
		if build_type == -1 and is_instance_valid(moving_building):
			check_type = moving_building.get_meta("build_type_id") if moving_building.has_meta("build_type_id") else 1
			
		var is_internal = (check_type >= 1 and check_type <= 4) or (check_type >= 8 and check_type <= 11)
		var is_external = (check_type >= 5 and check_type <= 7)
		var max_grid = 2
		
		for i in range(-max_grid - 1, max_grid + 2):
			for j in range(-max_grid - 1, max_grid + 2):
				var g_pos = Vector2i(i, j)
				var is_inside = abs(i) <= max_grid and abs(j) <= max_grid
				var is_outer_ring = max(abs(i), abs(j)) == max_grid + 1
				
				var can_build = false
				if is_internal and is_inside: can_build = true
				elif is_external and is_outer_ring: can_build = true
				
				if can_build:
					var tile_rect = Rect2(i * 64 - 32, j * 64 - 32, 64, 64)
					if floor_grids[current_floor].has(g_pos):
						draw_rect(tile_rect, Color(1.0, 0.0, 0.0, 0.2)) # 이미 점유됨 (빨강)
					else:
						draw_rect(tile_rect, Color(0.0, 1.0, 0.5, 0.2)) # 설치 가능 (초록/파랑)
				elif is_external and is_inside:
					var tile_rect = Rect2(i * 64 - 32, j * 64 - 32, 64, 64)
					draw_rect(tile_rect, Color(1.0, 0.0, 0.0, 0.1)) # 외부 전용인데 내부일 때 불가 표시

func _setup_ui():
	ui_canvas = CanvasLayer.new()
	get_tree().current_scene.add_child.call_deferred(ui_canvas)
	create_mobile_ui()
	
	# 좌측 상단 자원 표시 패널
	var res_panel = ColorRect.new()
	res_panel.color = Color(0.1, 0.1, 0.1, 0.8)
	res_panel.size = Vector2(200, 150)
	res_panel.position = Vector2(20, 20)
	ui_canvas.add_child(res_panel)
	
	new_inventory_label = Label.new()
	new_inventory_label.position = Vector2(10, 10)
	res_panel.add_child(new_inventory_label)
	
	cooldown_label = Label.new()
	cooldown_label.position = Vector2(20, 180)
	cooldown_label.add_theme_font_size_override("font_size", 18)
	cooldown_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	ui_canvas.add_child(cooldown_label)
	
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
		"7:드론기지\n(나무10,돌10)", 
		"8:공급기\n(나무5,돌5)", 
		"9:벨트\n(나무2)", 
		"0:가공소\n(돌15,코어2)",
		"-:미사일\n(강철5,코어10)",
		"M:지뢰살포기\n(강철5,코어5)"
	]
	var type_ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
	
	for i in range(12):
		var btn = Button.new()
		btn.text = names[i]
		btn.custom_minimum_size = Vector2(110, 60)
		btn.pressed.connect(select_build_type.bind(type_ids[i], names[i]))
		grid.add_child(btn)
		hotbar_buttons[type_ids[i]] = btn
		
	update_hotbar_ui()
		
	# 일시정지(ESC) 메뉴 패널
	pause_panel = ColorRect.new()
	pause_panel.color = Color(0, 0, 0, 0.8)
	pause_panel.size = get_viewport_rect().size
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_canvas.add_child(pause_panel)
	
	var continue_btn = Button.new()
	continue_btn.text = "계속하기 (Continue)"
	continue_btn.position = Vector2(vp_size.x/2 - 100, vp_size.y/2 - 120)
	continue_btn.size = Vector2(200, 50)
	continue_btn.pressed.connect(func(): toggle_pause())
	pause_panel.add_child(continue_btn)
	
	var save_btn = Button.new()
	save_btn.text = "게임 저장 (Save)"
	save_btn.position = Vector2(vp_size.x/2 - 100, vp_size.y/2 - 50)
	save_btn.size = Vector2(200, 50)
	save_btn.pressed.connect(func(): GameManager.save_game())
	pause_panel.add_child(save_btn)
	
	var load_btn = Button.new()
	load_btn.text = "게임 불러오기 (Load)"
	load_btn.position = Vector2(vp_size.x/2 - 100, vp_size.y/2 + 20)
	load_btn.size = Vector2(200, 50)
	load_btn.pressed.connect(func(): GameManager.load_game())
	pause_panel.add_child(load_btn)
	
	var restart_btn = Button.new()
	restart_btn.text = "재시작 (Restart)"
	restart_btn.position = Vector2(vp_size.x/2 - 100, vp_size.y/2 + 90)
	restart_btn.size = Vector2(200, 50)
	restart_btn.pressed.connect(func(): GameManager.restart_game())
	pause_panel.add_child(restart_btn)
		
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

func toggle_pause():
	if not is_instance_valid(pause_panel): return
	if upgrade_card_panel.visible: return # 업그레이드 중엔 무시
	
	if pause_panel.visible:
		pause_panel.visible = false
		get_tree().paused = false
	else:
		pause_panel.visible = true
		get_tree().paused = true

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
		var s = "이동 요새 HP: " + str(ceil(max(0, hp))) + " / " + str(ceil(max_hp)) + "\n"
		s += "웨이브 " + str(GameManager.current_wave) + " | " + ("낮(정비)" if GameManager.current_phase == "DAY" else "밤(방어)") + " - " + str(int(GameManager.phase_timer)) + "초 남음"
		status_label.text = s
		
		if is_instance_valid(mobile_action_btn):
			if build_type == 0:
				mobile_action_btn.text = "건설"
			else:
				mobile_action_btn.text = "회전"
				
		if is_instance_valid(btn_dash):
			if boost_cooldown > 0:
				btn_dash.text = "대쉬\n(" + str(int(boost_cooldown)) + "s)"
				btn_dash.disabled = true
			else:
				btn_dash.text = "대쉬 [Shift]"
				btn_dash.disabled = false
				
		if is_instance_valid(btn_orbital):
			if active_relics.get("orbital_strike", false):
				btn_orbital.visible = true
				if orbital_cooldown > 0:
					btn_orbital.text = "폭격\n(" + str(int(orbital_cooldown)) + "s)"
					btn_orbital.disabled = true
				else:
					btn_orbital.text = "폭격 [F]"
					btn_orbital.disabled = false
			else:
				btn_orbital.visible = false

	if is_instance_valid(boss_hp_panel) and is_instance_valid(boss_hp_label):
		if is_instance_valid(GameManager.boss) and not GameManager.boss.is_dead:
			boss_hp_panel.visible = true
			boss_hp_label.text = "보스 체력: " + str(max(0, GameManager.boss.hp)) + " / " + str(GameManager.boss.max_hp)
		else:
			boss_hp_panel.visible = false

func take_damage(amount, type="normal"):
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
	if is_dead: return
	is_dead = true
	
	print("=== GAME OVER (요새 파괴됨) ===")
	
	# 요새 파괴 시각적 이펙트
	add_camera_shake(100.0)
	
	get_tree().paused = true # 죽는 순간 화면 정지 및 포탑 작동 중지
	
	for i in range(15):
		var effect = ColorRect.new()
		effect.color = Color(1.0, randf_range(0.2, 0.5), 0.0, 0.8)
		var size_val = randf_range(100, 400)
		effect.size = Vector2(size_val, size_val)
		var offset = Vector2(randf_range(-150, 150), randf_range(-150, 150))
		effect.position = global_position + offset - effect.size / 2.0
		get_tree().current_scene.add_child.call_deferred(effect)
		
		var tween = get_tree().create_tween()
		tween.tween_interval(randf_range(0.0, 0.5))
		tween.tween_property(effect, "color:a", 0.0, 0.8)
		tween.tween_callback(effect.queue_free)
		
	# 약간 딜레이
	await get_tree().create_timer(1.0, true, false, true).timeout
	
	if is_instance_valid(status_label):
		status_label.text = "GAME OVER!\n이동 요새가 파괴되었습니다."
		status_label.modulate = Color(1, 0, 0)
		
	var final_core_count = inventory.get("monster_core", 0)
	GameManager.total_cores += final_core_count
	GameManager.save_meta_data()
	
	await get_tree().create_timer(2.0, true, false, true).timeout
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _process(delta):
	if is_dead: return
	
	queue_redraw()
	
	if get_tree().paused: return
	
	if orbital_cooldown > 0:
		orbital_cooldown -= delta
		
	if active_relics.get("overclock"):
		overclock_timer += delta
		if overclock_timer > 15.0:
			if not is_overclocked:
				is_overclocked = true
				GameManager.stat_firerate_mult *= 0.5 # 2배 빨라짐
				# 임시 이펙트: 요새 붉은색 깜빡임
				modulate = Color(2, 1, 1)
			if overclock_timer > 18.0:
				overclock_timer = 0.0
				is_overclocked = false
				GameManager.stat_firerate_mult /= 0.5
				modulate = Color(1, 1, 1)
				
	if is_instance_valid(cooldown_label):
		var cd_text = ""
		if boost_cooldown > 0:
			cd_text += "대쉬 쿨타임: " + str(snapped(boost_cooldown, 0.1)) + "초\n"
		else:
			cd_text += "[대쉬 준비 완료] (Space)\n"
			
		if active_relics.get("orbital_strike"):
			if orbital_cooldown > 0:
				cd_text += "궤도 폭격 쿨타임: " + str(snapped(orbital_cooldown, 0.1)) + "초\n"
			else:
				cd_text += "[궤도 폭격 준비 완료] (F키)\n"
		cooldown_label.text = cd_text
	
	# 카메라 쉐이크 처리
	if has_node("Camera2D"):
		if shake_intensity > 0:
			$Camera2D.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
			shake_intensity = lerp(shake_intensity, 0.0, 10.0 * delta)
			if shake_intensity < 0.1:
				shake_intensity = 0
				$Camera2D.offset = Vector2.ZERO

func _physics_process(delta):
	if get_tree().paused: return
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
	
	if joystick_active:
		direction = joystick_vector
	else:
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

func auto_attack():
	var targets = get_tree().get_nodes_in_group("enemy")
	targets.append_array(get_tree().get_nodes_in_group("rival"))
	var target = null
	var min_dist = 400.0 * GameManager.stat_range_mult
	
	for e in targets:
		if e.get("is_dead") == true: continue
		var dist = global_position.distance_to(e.global_position)
		if dist <= min_dist:
			min_dist = dist
			target = e
			
	if is_instance_valid(target):
		var proj = preload("res://scenes/projectile.tscn").instantiate()
		proj.global_position = global_position
		proj.direction = global_position.direction_to(target.global_position)
		proj.damage = 10.0 + (GameManager.stat_damage_mult * 5.0)
		proj.attack_type = "kinetic"
		proj.target_groups = ["enemy", "rival", "boss"]
		get_parent().add_child(proj)
		attack_timer = attack_rate

func _input(event):
	var is_touch_press = false
	var is_touch_release = false
	var is_drag = false
	var pos = Vector2.ZERO
	var touch_index = 0
	
	if event is InputEventScreenTouch:
		is_touch_press = event.pressed
		is_touch_release = not event.pressed
		pos = event.position
		touch_index = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_touch_press = event.pressed
		is_touch_release = not event.pressed
		pos = event.position
		touch_index = 0
	elif event is InputEventScreenDrag:
		is_drag = true
		pos = event.position
		touch_index = event.index
	elif event is InputEventMouseMotion and (Input.get_mouse_button_mask() & MOUSE_BUTTON_MASK_LEFT) != 0:
		is_drag = true
		pos = event.position
		touch_index = 0

	if is_touch_press:
		if joystick_touch_id == -1 and pos.distance_to(joystick_center) < 120:
			joystick_touch_id = touch_index
			joystick_active = true
			_update_joystick(pos)
			get_viewport().set_input_as_handled()
		else:
			var handled_by_btn = false
			if is_instance_valid(btn_dash) and btn_dash.get_global_rect().has_point(pos):
				use_dash()
				handled_by_btn = true
			elif is_instance_valid(mobile_action_btn) and mobile_action_btn.get_global_rect().has_point(pos):
				_on_mobile_action_pressed()
				handled_by_btn = true
			elif is_instance_valid(btn_cancel) and btn_cancel.visible and btn_cancel.get_global_rect().has_point(pos):
				set_build_type(0)
				handled_by_btn = true
			elif is_instance_valid(btn_orbital) and btn_orbital.visible and btn_orbital.get_global_rect().has_point(pos):
				use_orbital_strike()
				handled_by_btn = true
				
			if handled_by_btn:
				get_viewport().set_input_as_handled()
	elif is_touch_release:
		if touch_index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_active = false
			joystick_vector = Vector2.ZERO
			if is_instance_valid(joystick_knob):
				joystick_knob.position = joystick_center - joystick_knob.size / 2.0
			get_viewport().set_input_as_handled()
	elif is_drag:
		if touch_index == joystick_touch_id:
			_update_joystick(pos)
			get_viewport().set_input_as_handled()

func _update_joystick(pos: Vector2):
	if not is_instance_valid(joystick_knob): return
	var dir = joystick_center.direction_to(pos)
	var dist = min(joystick_center.distance_to(pos), 80.0)
	joystick_knob.position = (joystick_center + dir * dist) - joystick_knob.size / 2.0
	joystick_vector = dir * (dist / 80.0)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Time.get_ticks_msec() - last_action_time < 200:
			return
			
		build_pressed_this_frame = true
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
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if build_type != 0:
			set_build_type(0)
			get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1: select_build_type(1, "1:기관총")
		elif event.keycode == KEY_2: select_build_type(2, "2:스나이퍼")
		elif event.keycode == KEY_MINUS: select_build_type(11, "-:미사일")
		
		# 궤도 폭격 스킬
		elif event.keycode == KEY_F and active_relics.get("orbital_strike"):
			if orbital_cooldown <= 0:
				cast_orbital_strike()
			else:
				print("궤도 폭격 쿨타임 중: ", snapped(orbital_cooldown, 0.1), "초")
				
		elif event.keycode == KEY_ESCAPE: select_build_type(0, "현재 선택: 없음")
		elif event.keycode == KEY_5: select_build_type(5, "5:방벽")
		elif event.keycode == KEY_6: select_build_type(6, "6:수리소")
		elif event.keycode == KEY_7: select_build_type(7, "7:드릴")
		elif event.keycode == KEY_8: select_build_type(8, "8:공급기")
		elif event.keycode == KEY_9: select_build_type(9, "9:벨트")
		elif event.keycode == KEY_3: select_build_type(3, "3:샷건")
		elif event.keycode == KEY_4: select_build_type(4, "4:레이저")
		elif event.keycode == KEY_0: select_build_type(10, "0:가공소")
		elif event.keycode == KEY_M: select_build_type(12, "M:지뢰살포기")
		
		elif event.keycode == KEY_U:
			upgrade_panel.visible = not upgrade_panel.visible
		elif event.keycode == KEY_R:
			rotate_building()
		elif event.keycode == KEY_SPACE:
			interact_with_resource()
		elif event.keycode == KEY_B:
			toggle_build_menu()

func rotate_building():
	if build_direction == Vector2i.RIGHT: build_direction = Vector2i.DOWN
	elif build_direction == Vector2i.DOWN: build_direction = Vector2i.LEFT
	elif build_direction == Vector2i.LEFT: build_direction = Vector2i.UP
	elif build_direction == Vector2i.UP: build_direction = Vector2i.RIGHT
	
	if is_instance_valid(preview_arrow):
		if build_direction == Vector2i.RIGHT: preview_arrow.rotation = 0
		elif build_direction == Vector2i.DOWN: preview_arrow.rotation = PI/2
		elif build_direction == Vector2i.LEFT: preview_arrow.rotation = PI
		elif build_direction == Vector2i.UP: preview_arrow.rotation = -PI/2

func toggle_build_menu():
	if build_type != 0:
		set_build_type(0)
		return
		
	if is_instance_valid(build_menu_panel):
		build_menu_panel.visible = not build_menu_panel.visible

func update_hotbar_ui():
	var names = {
		1: "1:기관총\n(나무5,돌5)", 2: "2:스나이퍼\n(돌15)", 3: "3:샷건\n(나무15)",
		4: "4:레이저\n(강철10,코어5)", 5: "5:방벽\n(돌10)", 6: "6:수리소\n(나무20,돌10)",
		7: "7:드론기지\n(나무10,돌10)", 8: "8:공급기\n(나무5,돌5)", 9: "9:벨트\n(나무2)",
		10: "0:가공소\n(돌15,코어2)", 11: "-:미사일\n(강철5,코어10)", 12: "M:지뢰살포기\n(강철5,코어5)"
	}
	for tid in hotbar_buttons.keys():
		var btn = hotbar_buttons[tid]
		if tid in unlocked_towers:
			btn.disabled = false
			btn.text = names[tid]
		else:
			btn.disabled = true
			btn.text = "[잠김]\n" + names[tid].split(":")[1]

func select_build_type(type_id: int, b_name: String):
	last_action_time = Time.get_ticks_msec()
	if not type_id in unlocked_towers:
		print("아직 해금되지 않은 타워입니다!")
		return
		
	set_build_type(type_id)
	if is_instance_valid(active_build_label):
		active_build_label.text = "현재 선택: " + b_name
	if is_instance_valid(build_menu_panel):
		build_menu_panel.visible = false

func set_build_type(type):
	build_type = type
	if build_type == 0:
		if is_instance_valid(mobile_action_btn): mobile_action_btn.text = "건설"
		if is_instance_valid(btn_cancel): btn_cancel.visible = false
		if is_instance_valid(build_preview): build_preview.visible = false
	else:
		if is_instance_valid(mobile_action_btn): mobile_action_btn.text = "회전"
		if is_instance_valid(btn_cancel): btn_cancel.visible = true
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
		elif build_type == 12: preview_rect.color = Color(1.0, 0.5, 0.0, 0.5) # 지뢰
	
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
	
	if build_pressed_this_frame:
		build_pressed_this_frame = false
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
				if inventory.get("wood", 0) >= 10 and inventory.get("stone", 0) >= 10:
					var dr_script = preload("res://scripts/drill.gd")
					building = dr_script.new()
					add_item("wood", -10)
					add_item("stone", -10)
				else:
					print("자원 부족: 나무 10, 돌 10 필요 (드론 기지)")
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
			elif build_type == 12:
				if inventory.get("steel_plate", 0) >= 5 and inventory.get("monster_core", 0) >= 5:
					var mine_script = preload("res://scripts/mine_dispenser.gd")
					building = mine_script.new()
					add_item("steel_plate", -5)
					add_item("monster_core", -5)
				else:
					print("자원 부족: 강철 5, 코어 5 필요 (지뢰살포기)")
				
			if building:
				if "grid_pos" in building: building.grid_pos = grid_pos
				if "direction" in building: building.direction = build_direction
				if "floor_index" in building: building.floor_index = current_floor
				
				# 건물 메타데이터 설정
				building.set_meta("level", 1)
				building.set_meta("build_type_id", build_type)
				var b_names = ["", "기관총", "스나이퍼", "샷건", "레이저", "방벽", "수리소", "드론기지", "공급기", "벨트", "가공소", "미사일", "지뢰살포기"]
				if build_type > 0 and build_type < b_names.size():
					building.set_meta("b_name", b_names[build_type])
				if "target_groups" in building: building.target_groups = ["enemy", "rival", "boss"]
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
		{"id": "hp", "title": "[방어] 티타늄 장갑", "desc": "요새의 최대 HP가 300 증가하고,\n현재 HP를 300 회복합니다."},
		{"id": "range", "title": "[화력] 고급 조준경", "desc": "모든 공격 타워의 사거리가 20% 증가합니다."},
		{"id": "damage", "title": "[화력] 철갑탄", "desc": "모든 공격 타워의 데미지가 20% 증가합니다."},
		{"id": "drill", "title": "[생산] 초정밀 드릴", "desc": "드릴의 자원 채굴 속도가 20% 빨라집니다."}
	]
	
	if not 4 in unlocked_towers:
		all_options.append({"id": "unlock_laser", "title": "[해금] 레이저 타워", "desc": "적을 관통하는 강력한 레이저 타워 건설법을 해금합니다."})
	if not 11 in unlocked_towers:
		all_options.append({"id": "unlock_missile", "title": "[해금] 미사일 타워", "desc": "폭발성 미사일을 발사하는 타워 건설법을 해금합니다."})
		
	if not active_relics.get("vampire"):
		all_options.append({"id": "relic_vampire", "title": "[유물] 흡혈 코어", "desc": "모든 타워가 적을 공격할 때마다 5% 확률로 요새 체력을 1 회복합니다."})
	if not active_relics.get("overclock"):
		all_options.append({"id": "relic_overclock", "title": "[유물] 과부하 모듈", "desc": "요새가 15초마다 3초 동안 타워 공격 속도가 폭주합니다."})
	if not active_relics.get("orbital_strike"):
		all_options.append({"id": "skill_orbital", "title": "[스킬] 궤도 폭격", "desc": "단축키 F를 눌러 마우스 커서 위치에 강력한 폭격을 가합니다. (쿨타임 15초)"})
	
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
	if id == "hp":
		max_hp += 300
		hp += 300
	elif id == "range":
		GameManager.stat_range_mult *= 1.2
	elif id == "damage":
		GameManager.stat_damage_mult *= 1.2
	elif id == "drill":
		GameManager.stat_drill_mult *= 0.8
	elif id == "unlock_laser":
		unlocked_towers.append(4)
		update_hotbar_ui()
	elif id == "unlock_missile":
		unlocked_towers.append(11)
		update_hotbar_ui()
	elif id == "relic_vampire":
		active_relics["vampire"] = true
	elif id == "relic_overclock":
		active_relics["overclock"] = true
	elif id == "skill_orbital":
		active_relics["orbital_strike"] = true
		
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
		
		# 시각적 피드백 (Floating Text)
		var label = Label.new()
		label.text = "Level UP!"
		label.global_position = selected_building.global_position + Vector2(-30, -30)
		var settings = LabelSettings.new()
		settings.font_color = Color(1.0, 0.8, 0.2)
		settings.outline_size = 4
		settings.outline_color = Color(0, 0, 0)
		settings.font_size = 18
		label.label_settings = settings
		label.z_index = 100
		get_tree().current_scene.add_child(label)
		
		var tween = label.create_tween()
		tween.tween_property(label, "global_position", label.global_position + Vector2(0, -40), 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 1.0)
		tween.tween_callback(func(): label.queue_free())
		
	else:
		print("코어가 부족합니다!")

func _on_timer_timeout():
	pass

func cast_orbital_strike():
	orbital_cooldown = 15.0
	
	var target_pos = global_position
	var enemies = get_tree().get_nodes_in_group("enemy")
	var min_dist = 99999.0
	var closest_enemy = null
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = enemy.global_position.distance_to(global_position)
			if dist < min_dist:
				min_dist = dist
				closest_enemy = enemy
				
	if closest_enemy != null:
		target_pos = closest_enemy.global_position
	else:
		target_pos = global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	
	add_camera_shake(50.0)
	print("궤도 폭격 발사!")
	
	# 궤도 폭격 이펙트 (노란 섬광)
	var effect = ColorRect.new()
	effect.color = Color(1.0, 0.5, 0.1, 0.6)
	effect.size = Vector2(600, 600)
	effect.position = target_pos - effect.size / 2.0
	get_tree().current_scene.add_child(effect)
	
	var tween = get_tree().create_tween()
	tween.tween_property(effect, "color:a", 0.0, 0.5)
	tween.tween_callback(effect.queue_free)
	
	# 범위 내 적 데미지
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = enemy.global_position.distance_to(target_pos)
			if dist <= 300.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(800.0 * GameManager.stat_damage_mult, "explosive")
					
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		if is_instance_valid(boss):
			var dist = boss.global_position.distance_to(mouse_world_pos)
			if dist <= 350.0:
				if boss.has_method("take_damage"):
					boss.take_damage(800.0 * GameManager.stat_damage_mult, "explosive")

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

func get_save_data() -> Dictionary:
	var data = {
		"hp": hp,
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"inventory": inventory.duplicate(),
		"unlocked_towers": unlocked_towers.duplicate(),
		"active_relics": active_relics.duplicate(),
		"floor_grids": {}
	}
	
	for f in floor_grids.keys():
		var fg_data = []
		for pos in floor_grids[f].keys():
			var b = floor_grids[f][pos]
			var b_data = {
				"x": pos.x,
				"y": pos.y,
				"type": b.get_meta("build_type_id", 1),
				"level": b.get_meta("level", 1)
			}
			if "direction" in b:
				if b.direction == Vector2i.RIGHT: b_data["dir"] = 1
				elif b.direction == Vector2i.LEFT: b_data["dir"] = -1
				elif b.direction == Vector2i.DOWN: b_data["dir"] = 2
				elif b.direction == Vector2i.UP: b_data["dir"] = -2
			fg_data.append(b_data)
		data["floor_grids"][str(f)] = fg_data
		
	return data

func clear_buildings():
	for f in floor_grids.keys():
		for pos in floor_grids[f].keys():
			var b = floor_grids[f][pos]
			if is_instance_valid(b): b.queue_free()
		floor_grids[f].clear()

func load_save_data(data: Dictionary):
	hp = data.get("hp", max_hp)
	global_position = Vector2(data.get("pos_x", 0), data.get("pos_y", 0))
	inventory = data.get("inventory", {})
	if data.has("unlocked_towers"):
		unlocked_towers = data["unlocked_towers"]
	if data.has("active_relics"):
		active_relics = data["active_relics"]
	update_ui()
	update_hotbar_ui()
	
	if data.has("floor_grids"):
		var fg_data = data["floor_grids"]
		for f_str in fg_data.keys():
			var f = int(f_str)
			if not floor_grids.has(f): floor_grids[f] = {}
			for b_data in fg_data[f_str]:
				var pos = Vector2i(b_data["x"], b_data["y"])
				var b_type = b_data["type"]
				var b_level = b_data.get("level", 1)
				
				var build_direction = Vector2i.RIGHT
				if b_data.has("dir"):
					var d = b_data["dir"]
					if d == 1: build_direction = Vector2i.RIGHT
					elif d == -1: build_direction = Vector2i.LEFT
					elif d == 2: build_direction = Vector2i.DOWN
					elif d == -2: build_direction = Vector2i.UP
					
				var building = instantiate_building(b_type)
				if building:
					building.grid_pos = pos
					if "direction" in building: building.direction = build_direction
					if "floor_index" in building: building.floor_index = f
					
					building.set_meta("level", b_level)
					building.set_meta("build_type_id", b_type)
					var b_names = ["", "기관총", "스나이퍼", "샷건", "레이저", "방벽", "수리소", "드릴", "공급기", "벨트", "가공소", "미사일"]
					if b_type > 0 and b_type < b_names.size():
						building.set_meta("b_name", b_names[b_type])
						
					if "target_groups" in building: building.target_groups = ["enemy", "rival", "boss"]
					
					building.position = Vector2(pos.x * 64, pos.y * 64)
					if build_direction == Vector2i.RIGHT: building.rotation = 0
					elif build_direction == Vector2i.DOWN: building.rotation = PI/2
					elif build_direction == Vector2i.LEFT: building.rotation = PI
					elif build_direction == Vector2i.UP: building.rotation = -PI/2
					
					get_parent().add_child(building)
					floor_grids[f][pos] = building
					
					# 렌더링 노드 분기
					if not floor_nodes.has(f):
						var fn = Node2D.new()
						get_parent().add_child(fn)
						floor_nodes[f] = fn
						
					building.get_parent().remove_child(building)
					floor_nodes[f].add_child(building)

func instantiate_building(b_type: int) -> Node2D:
	var building = null
	if b_type == 1: building = preload("res://scenes/turret.tscn").instantiate()
	elif b_type == 2: building = preload("res://scripts/sniper_turret.gd").new()
	elif b_type == 3: building = preload("res://scripts/shotgun_turret.gd").new()
	elif b_type == 4: building = preload("res://scripts/laser_turret.gd").new()
	elif b_type == 5: building = preload("res://scripts/barricade.gd").new()
	elif b_type == 6: building = preload("res://scripts/repair_station.gd").new()
	elif b_type == 7: building = preload("res://scripts/drill.gd").new()
	elif b_type == 8: building = preload("res://scripts/provider.gd").new()
	elif b_type == 9: building = preload("res://scripts/belt.gd").new()
	elif b_type == 10: building = preload("res://scripts/processor.gd").new()
	elif b_type == 11: building = preload("res://scripts/missile_turret.gd").new()
	return building
