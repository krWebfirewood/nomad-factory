extends Node2D

var grid_pos = Vector2i()
var drones = []
var max_drones = 1

func _ready():
	var base_rect = ColorRect.new()
	base_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_rect.size = Vector2(64, 64)
	base_rect.position = Vector2(-32, -32)
	base_rect.color = Color(0.2, 0.2, 0.3)
	add_child(base_rect)
	
	var pad = ColorRect.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.size = Vector2(30, 30)
	pad.position = Vector2(-15, -15)
	pad.color = Color(0.8, 0.8, 0.1)
	add_child(pad)
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_check_drones)
	add_child(timer)

func _check_drones():
	var active_drones = []
	for d in drones:
		if is_instance_valid(d):
			active_drones.append(d)
	drones = active_drones
	
	var level = get_meta("level") if has_meta("level") else 1
	max_drones = level
	
	if drones.size() < max_drones:
		spawn_drone()

func spawn_drone():
	var drone_script = preload("res://scripts/gather_drone.gd")
	var drone = drone_script.new()
	drone.global_position = global_position
	drone.home_station = self
	
	get_tree().current_scene.add_child(drone)
	drones.append(drone)

func _exit_tree():
	for d in drones:
		if is_instance_valid(d):
			d.queue_free()
