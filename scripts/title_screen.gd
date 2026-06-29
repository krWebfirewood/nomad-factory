extends Control

var core_label: Label
var hp_label: Label
var hp_btn: Button
var dmg_label: Label
var dmg_btn: Button
var speed_label: Label
var speed_btn: Button

func _ready():
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 1.0)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "NOMAD FACTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vbox.add_child(title)
	
	core_label = Label.new()
	core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_label.add_theme_font_size_override("font_size", 24)
	core_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	vbox.add_child(core_label)
	
	var start_btn = Button.new()
	start_btn.text = "GAME START"
	start_btn.custom_minimum_size = Vector2(300, 60)
	start_btn.add_theme_font_size_override("font_size", 32)
	start_btn.pressed.connect(_on_start_button_pressed)
	vbox.add_child(start_btn)
	
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(separator)
	
	var upg_title = Label.new()
	upg_title.text = "- 영구 업그레이드 -"
	upg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(upg_title)
	
	hp_label = Label.new()
	hp_btn = Button.new()
	_add_upgrade_row(vbox, hp_label, hp_btn, _on_hp_upgrade_pressed)
	
	dmg_label = Label.new()
	dmg_btn = Button.new()
	_add_upgrade_row(vbox, dmg_label, dmg_btn, _on_dmg_upgrade_pressed)
	
	speed_label = Label.new()
	speed_btn = Button.new()
	_add_upgrade_row(vbox, speed_label, speed_btn, _on_speed_upgrade_pressed)
	
	update_ui()

func _add_upgrade_row(parent: Node, lbl: Label, btn: Button, callback: Callable):
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	
	lbl.custom_minimum_size = Vector2(250, 0)
	hbox.add_child(lbl)
	
	btn.custom_minimum_size = Vector2(100, 40)
	btn.pressed.connect(callback)
	hbox.add_child(btn)
	
	parent.add_child(hbox)

func update_ui():
	core_label.text = "보유 코어: " + str(GameManager.total_cores)
	
	var hp_cost = 5 + GameManager.meta_hp_level * 5
	hp_label.text = "요새 체력 강화 (Lv." + str(GameManager.meta_hp_level) + ")"
	hp_btn.text = "코어 " + str(hp_cost) + "개"
	hp_btn.disabled = GameManager.total_cores < hp_cost
	
	var dmg_cost = 10 + GameManager.meta_damage_level * 10
	dmg_label.text = "무기 화력 강화 (Lv." + str(GameManager.meta_damage_level) + ")"
	dmg_btn.text = "코어 " + str(dmg_cost) + "개"
	dmg_btn.disabled = GameManager.total_cores < dmg_cost
	
	var speed_cost = 8 + GameManager.meta_speed_level * 8
	speed_label.text = "엔진 속도 강화 (Lv." + str(GameManager.meta_speed_level) + ")"
	speed_btn.text = "코어 " + str(speed_cost) + "개"
	speed_btn.disabled = GameManager.total_cores < speed_cost

func _on_start_button_pressed():
	GameManager.start_new_game()

func _on_hp_upgrade_pressed():
	var cost = 5 + GameManager.meta_hp_level * 5
	if GameManager.total_cores >= cost:
		GameManager.total_cores -= cost
		GameManager.meta_hp_level += 1
		GameManager.save_meta_data()
		update_ui()

func _on_dmg_upgrade_pressed():
	var cost = 10 + GameManager.meta_damage_level * 10
	if GameManager.total_cores >= cost:
		GameManager.total_cores -= cost
		GameManager.meta_damage_level += 1
		GameManager.save_meta_data()
		update_ui()

func _on_speed_upgrade_pressed():
	var cost = 8 + GameManager.meta_speed_level * 8
	if GameManager.total_cores >= cost:
		GameManager.total_cores -= cost
		GameManager.meta_speed_level += 1
		GameManager.save_meta_data()
		update_ui()
