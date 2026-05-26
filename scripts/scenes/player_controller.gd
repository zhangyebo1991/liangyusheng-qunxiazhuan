extends CharacterBody2D

signal interact_requested(target)
signal position_changed(position: Vector2)

const SimpleSpriteFactory = preload("res://scripts/scenes/simple_sprite_factory.gd")

@export var speed: float = 160.0

var facing: String = "down"
var current_interactable = null
var sprite: AnimatedSprite2D

# 自动寻路变量
var target_path: Array[Vector2] = []
var is_auto_moving: bool = false
var path_tolerance: float = 8.0

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = SimpleSpriteFactory.create_frames(Color("#2f6fdd"), Color("#f1d37b"))
	sprite.animation = "idle_down"
	add_child(sprite)

	var shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 8
	capsule.height = 22
	shape.shape = capsule
	shape.position = Vector2(0, 4)
	add_child(shape)

func _physics_process(_delta: float) -> void:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# 手动打断自动移动
	if input_vector != Vector2.ZERO and is_auto_moving:
		stop_auto_move()
	
	if is_auto_moving and target_path.size() > 0:
		_process_auto_move()
	else:
		velocity = input_vector * speed
		move_and_slide()
		_update_facing(input_vector)
		_update_animation(input_vector)
	
	position_changed.emit(global_position)

func _process_auto_move() -> void:
	if target_path.is_empty():
		is_auto_moving = false
		return
		
	var target = target_path[0]
	if global_position.distance_to(target) <= path_tolerance:
		target_path.remove_at(0)
		if target_path.is_empty():
			is_auto_moving = false
			velocity = Vector2.ZERO
			_update_animation(Vector2.ZERO)
			return
		target = target_path[0]
	
	var direction = global_position.direction_to(target)
	velocity = direction * speed
	move_and_slide()
	_update_facing(direction)
	_update_animation(direction)

func start_auto_move(path: Array[Vector2]) -> void:
	if path.is_empty():
		return
	target_path = path
	is_auto_moving = true

func stop_auto_move() -> void:
	is_auto_moving = false
	target_path.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable != null:
		interact_requested.emit(current_interactable)

func set_current_interactable(target) -> void:
	current_interactable = target

func _update_facing(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		return
	if absf(input_vector.x) > absf(input_vector.y):
		facing = "right" if input_vector.x > 0.0 else "left"
	else:
		facing = "down" if input_vector.y > 0.0 else "up"

func _update_animation(input_vector: Vector2) -> void:
	var prefix = "idle" if input_vector == Vector2.ZERO else "walk"
	var next_animation = "%s_%s" % [prefix, facing]
	if sprite.animation != next_animation:
		sprite.play(next_animation)
