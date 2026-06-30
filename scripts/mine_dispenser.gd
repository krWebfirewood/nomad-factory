extends Node2D

var shoot_timer = 0.0
var shoot_interval = 2.0
var max_mines = 30 

func _ready():
	pass

func _draw():
	# 지뢰 살포기 외형
	draw_rect(Rect2(-24, -24, 48, 48), Color(0.4, 0.4, 0.3))
	draw_circle(Vector2.ZERO, 15, Color(1.0, 0.2, 0.0))

func _process(delta):
	shoot_timer -= delta * GameManager.stat_firerate_mult
	if shoot_timer <= 0:
		shoot_timer = shoot_interval
		toss_mine()

func toss_mine():
	var active_mines = get_tree().get_nodes_in_group("landmine")
	if active_mines.size() >= max_mines:
		return
		
	var mine_script = preload("res://scripts/landmine.gd")
	var mine = mine_script.new()
	
	var angle = randf() * PI * 2
	var dist = randf_range(150.0, 400.0)
	var spawn_pos = GameManager.player.global_position + Vector2(cos(angle), sin(angle)) * dist
	
	mine.global_position = spawn_pos
	get_tree().current_scene.add_child(mine)
