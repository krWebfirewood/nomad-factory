extends Area2D

var speed = 300.0
var direction = Vector2.ZERO
var damage = 20.0
var lifetime = 3.0

@onready var sprite = null

func _ready():
	# 물리 계층 설정 (마스크 1: 플레이어, 트레일러 등)
	collision_layer = 0
	collision_mask = 1
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	col.shape = shape
	add_child(col)
	
	sprite = ColorRect.new()
	sprite.size = Vector2(16, 16)
	sprite.position = Vector2(-8, -8)
	sprite.color = Color(0.0, 1.0, 0.0, 1.0) # 초록색 맹독침
	add_child(sprite)
	
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player") or body.is_in_group("trailer"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
