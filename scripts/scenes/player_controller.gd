extends CharacterBody2D

signal interact_requested(target)
signal position_changed(position: Vector2)

const SimpleSpriteFactory = preload("res://scripts/scenes/simple_sprite_factory.gd")
const CharacterSpriteLoader = preload("res://scripts/scenes/character_sprite_loader.gd")

const CHARACTER_ID := "hero_yun"
const WALK_ACTION := "walk"

@export var speed: float = 160.0

var facing: String = "down_right"
var facing_horizontal: String = "right"
var facing_vertical: String = "down"
var cardinal_facing: String = "down"
var current_interactable = null
var sprite: AnimatedSprite2D
var _uses_diagonal_character_frames := false

# 自动寻路变量
var target_path: Array[Vector2] = []
var is_auto_moving: bool = false
var path_tolerance: float = 8.0

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	var loaded_frames: SpriteFrames = CharacterSpriteLoader.create_walk_frames(CHARACTER_ID, WALK_ACTION)
	if loaded_frames == null:
		_uses_diagonal_character_frames = false
		sprite.sprite_frames = SimpleSpriteFactory.create_frames(Color("#2f6fdd"), Color("#f1d37b"))
		sprite.animation = "idle_down"
	else:
		_uses_diagonal_character_frames = true
		sprite.sprite_frames = loaded_frames
		sprite.animation = get_walk_animation_name()
		sprite.frame = 0
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

func get_facing_direction() -> String:
	return "%s_%s" % [facing_vertical, facing_horizontal]

func get_walk_animation_name() -> String:
	return "%s_%s" % [WALK_ACTION, get_facing_direction()]

func _update_facing(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		return

	if input_vector.x > 0.0:
		facing_horizontal = "right"
	elif input_vector.x < 0.0:
		facing_horizontal = "left"

	if input_vector.y > 0.0:
		facing_vertical = "down"
	elif input_vector.y < 0.0:
		facing_vertical = "up"

	facing = get_facing_direction()
	cardinal_facing = _resolve_cardinal_facing(input_vector)

func _update_animation(input_vector: Vector2) -> void:
	if sprite == null:
		return

	if _uses_diagonal_character_frames:
		_update_diagonal_animation(input_vector)
		return

	var prefix = "idle" if input_vector == Vector2.ZERO else "walk"
	var next_animation = "%s_%s" % [prefix, cardinal_facing]
	if sprite.animation != next_animation:
		sprite.play(next_animation)

func _update_diagonal_animation(input_vector: Vector2) -> void:
	var next_animation := get_walk_animation_name()
	if input_vector == Vector2.ZERO:
		if sprite.animation != next_animation:
			sprite.animation = next_animation
		sprite.stop()
		sprite.frame = 0
		return

	if sprite.animation != next_animation or not sprite.is_playing():
		sprite.play(next_animation)

func _resolve_cardinal_facing(input_vector: Vector2) -> String:
	if absf(input_vector.x) > absf(input_vector.y):
		return "right" if input_vector.x > 0.0 else "left"
	return "down" if input_vector.y > 0.0 else "up"

# TODO: 后续补齐 8 方向素材后，把当前四斜方向临时方案改成完整 8 方向朝向系统。
