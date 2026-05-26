# Character Diagonal Animation Loader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让探索主角从 `assets/characters/hero_yun/walk/` 加载四斜方向行走素材，并按横纵保留状态播放正确动画。

**Architecture:** 新增 `character_sprite_loader.gd` 统一读取角色动画资源，`player_controller.gd` 只维护移动、朝向和播放状态。四斜方向素材完整时使用真实素材，不完整时回退到现有 `SimpleSpriteFactory` 占位动画。

**Tech Stack:** Godot 4.6、GDScript、`SpriteFrames`、`AnimatedSprite2D`、项目自定义 `tests/run_tests.gd` 测试入口。

---

## 文件结构

- Create: `scripts/scenes/character_sprite_loader.gd`
  - 负责从 `res://assets/characters/<角色id>/<动作>/<方向>/<帧号>.png` 生成 `SpriteFrames`。
  - 素材完整时返回 `SpriteFrames`，素材不完整时返回 `null` 并输出 `push_warning`。
- Modify: `scripts/scenes/player_controller.gd`
  - 引入加载器。
  - 新增 `facing_horizontal`、`facing_vertical`、`get_facing_direction()`、`get_walk_animation_name()`。
  - 保留当前移动、交互、自动寻路和占位动画回退。
- Create: `tests/test_character_sprite_loader.gd`
  - 覆盖加载器生成四斜方向动画、每组 7 帧、循环播放。
- Create: `tests/test_player_diagonal_animation.gd`
  - 覆盖默认右下、按上右上、再按左左上、右下输入回到右下，以及静止停在第 0 帧。
- Modify: `tests/run_tests.gd`
  - 注册新增两个测试套件。
- Add to git: `assets/characters/hero_yun/walk/down_right/00.png` 至 `06.png`
- Add to git: `assets/characters/hero_yun/walk/up_right/00.png` 至 `06.png`
- Add to git: `assets/characters/hero_yun/walk/up_left/00.png` 至 `06.png`
- Add to git: `assets/characters/hero_yun/walk/down_left/00.png` 至 `06.png`

---

### Task 1: 角色动画加载器

**Files:**
- Create: `tests/test_character_sprite_loader.gd`
- Modify: `tests/run_tests.gd`
- Create: `scripts/scenes/character_sprite_loader.gd`
- Add: `assets/characters/hero_yun/walk/down_right/00.png` 至 `06.png`
- Add: `assets/characters/hero_yun/walk/up_right/00.png` 至 `06.png`
- Add: `assets/characters/hero_yun/walk/up_left/00.png` 至 `06.png`
- Add: `assets/characters/hero_yun/walk/down_left/00.png` 至 `06.png`

- [ ] **Step 1: 写加载器失败测试**

Create `tests/test_character_sprite_loader.gd`:

```gdscript
extends RefCounted

const CharacterSpriteLoaderScript = preload("res://scripts/scenes/character_sprite_loader.gd")

const EXPECTED_DIRECTIONS := [
	"down_right",
	"up_right",
	"up_left",
	"down_left",
]

func run(assertions) -> void:
	var frames: SpriteFrames = CharacterSpriteLoaderScript.create_walk_frames("hero_yun")
	assertions.assert_true(frames != null, "角色动画加载器应为 hero_yun 创建 SpriteFrames")
	if frames == null:
		return

	for direction in EXPECTED_DIRECTIONS:
		var animation := "walk_%s" % direction
		assertions.assert_true(frames.has_animation(animation), "应存在动画 %s" % animation)
		if frames.has_animation(animation):
			assertions.assert_eq(frames.get_frame_count(animation), 7, "%s 应有 7 帧" % animation)
			assertions.assert_true(frames.get_animation_loop(animation), "%s 应循环播放" % animation)
```

- [ ] **Step 2: 注册加载器测试**

Modify `tests/run_tests.gd` by adding the preload near the other `const Test...Script` lines:

```gdscript
const TestCharacterSpriteLoaderScript = preload("res://tests/test_character_sprite_loader.gd")
```

Add the suite entry near the other scene/system tests:

```gdscript
		TestCharacterSpriteLoaderScript.new(),
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL。失败原因应指向 `res://scripts/scenes/character_sprite_loader.gd` 不存在，或 `create_walk_frames` 未定义。

- [ ] **Step 4: 实现角色动画加载器**

Create `scripts/scenes/character_sprite_loader.gd`:

```gdscript
extends RefCounted

const CHARACTER_ROOT := "res://assets/characters"
const DEFAULT_DIRECTIONS := [
	"down_right",
	"up_right",
	"up_left",
	"down_left",
]
const DEFAULT_FRAME_COUNT := 7
const DEFAULT_FPS := 8.0

static func create_walk_frames(
	character_id: String,
	action: String = "walk",
	directions: Array = [],
	frame_count: int = DEFAULT_FRAME_COUNT,
	fps: float = DEFAULT_FPS
) -> SpriteFrames:
	var resolved_directions: Array = directions
	if resolved_directions.is_empty():
		resolved_directions = DEFAULT_DIRECTIONS.duplicate()

	var missing_paths := _collect_missing_paths(character_id, action, resolved_directions, frame_count)
	if not missing_paths.is_empty():
		for path in missing_paths:
			push_warning("缺少角色动画帧：%s" % path)
		return null

	var frames := SpriteFrames.new()
	for direction in resolved_directions:
		var animation := "%s_%s" % [action, direction]
		frames.add_animation(animation)
		frames.set_animation_speed(animation, fps)
		frames.set_animation_loop(animation, true)
		for frame_index in range(frame_count):
			var frame_path := _build_frame_path(character_id, action, str(direction), frame_index)
			frames.add_frame(animation, load(frame_path))
	return frames

static func _collect_missing_paths(
	character_id: String,
	action: String,
	directions: Array,
	frame_count: int
) -> Array[String]:
	var missing_paths: Array[String] = []
	for direction in directions:
		for frame_index in range(frame_count):
			var frame_path := _build_frame_path(character_id, action, str(direction), frame_index)
			if not ResourceLoader.exists(frame_path):
				missing_paths.append(frame_path)
	return missing_paths

static func _build_frame_path(character_id: String, action: String, direction: String, frame_index: int) -> String:
	return "%s/%s/%s/%s/%02d.png" % [CHARACTER_ROOT, character_id, action, direction, frame_index]
```

- [ ] **Step 5: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出类似：

```text
测试通过：... 个测试套件
```

- [ ] **Step 6: 提交加载器、测试和主角素材**

Run:

```powershell
git add scripts/scenes/character_sprite_loader.gd tests/test_character_sprite_loader.gd tests/run_tests.gd assets/characters/hero_yun/walk/down_right assets/characters/hero_yun/walk/up_right assets/characters/hero_yun/walk/up_left assets/characters/hero_yun/walk/down_left
git commit -m "feat: 添加角色行走动画加载器"
```

Expected: commit 成功，提交内容包含加载器、测试注册和 28 张主角行走 PNG。

---

### Task 2: 主角四斜方向朝向与播放

**Files:**
- Create: `tests/test_player_diagonal_animation.gd`
- Modify: `tests/run_tests.gd`
- Modify: `scripts/scenes/player_controller.gd`

- [ ] **Step 1: 写主角朝向和动画失败测试**

Create `tests/test_player_diagonal_animation.gd`:

```gdscript
extends RefCounted

const PlayerControllerScript = preload("res://scripts/scenes/player_controller.gd")

func run(assertions) -> void:
	var methods := _collect_method_names(PlayerControllerScript)
	for method_name in ["get_facing_direction", "get_walk_animation_name", "_update_facing", "_update_animation"]:
		assertions.assert_true(methods.has(method_name), "PlayerController 应含方法 %s" % method_name)

	if not methods.has("get_facing_direction") or not methods.has("get_walk_animation_name"):
		return

	_assert_direction_state(assertions)
	_assert_diagonal_animation_stop(assertions)

func _assert_direction_state(assertions) -> void:
	var player = PlayerControllerScript.new()
	assertions.assert_eq(player.get_facing_direction(), "down_right", "主角默认应面向右下")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_down_right", "默认行走动画应为右下")

	player._update_facing(Vector2(0, -1))
	assertions.assert_eq(player.get_facing_direction(), "up_right", "默认右下时按上应变为右上")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_up_right", "按上后行走动画应为右上")

	player._update_facing(Vector2(-1, 0))
	assertions.assert_eq(player.get_facing_direction(), "up_left", "右上后按左应变为左上")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_up_left", "按左后行走动画应为左上")

	player._update_facing(Vector2(1, 1))
	assertions.assert_eq(player.get_facing_direction(), "down_right", "输入右下应回到右下")
	assertions.assert_eq(player.get_walk_animation_name(), "walk_down_right", "右下输入后行走动画应为右下")

func _assert_diagonal_animation_stop(assertions) -> void:
	var player = PlayerControllerScript.new()
	player.sprite = AnimatedSprite2D.new()
	player.sprite.sprite_frames = _make_test_frames()
	player._uses_diagonal_character_frames = true

	player._update_facing(Vector2(0, -1))
	player._update_animation(Vector2(0, -1))
	assertions.assert_eq(player.sprite.animation, "walk_up_right", "移动时应播放当前斜方向动画")
	assertions.assert_true(player.sprite.is_playing(), "移动时斜方向动画应播放")

	player._update_animation(Vector2.ZERO)
	assertions.assert_eq(player.sprite.animation, "walk_up_right", "静止时应保持当前斜方向动画")
	assertions.assert_eq(player.sprite.frame, 0, "静止时应停在第 0 帧")
	assertions.assert_false(player.sprite.is_playing(), "静止时斜方向动画应停止")

func _make_test_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	var texture := _make_texture()
	for direction in ["down_right", "up_right", "up_left", "down_left"]:
		var animation := "walk_%s" % direction
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		for _i in range(7):
			frames.add_frame(animation, texture)
	return frames

func _make_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _collect_method_names(script: Script) -> Array[String]:
	var names: Array[String] = []
	for method in script.get_script_method_list():
		names.append(str(method.get("name", "")))
	return names
```

- [ ] **Step 2: 注册主角动画测试**

Modify `tests/run_tests.gd` by adding the preload near the other `const Test...Script` lines:

```gdscript
const TestPlayerDiagonalAnimationScript = preload("res://tests/test_player_diagonal_animation.gd")
```

Add the suite entry near `TestCharacterSpriteLoaderScript.new()`:

```gdscript
		TestPlayerDiagonalAnimationScript.new(),
```

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: FAIL。失败信息应包含 `PlayerController 应含方法 get_facing_direction` 或 `PlayerController 应含方法 get_walk_animation_name`。

- [ ] **Step 4: 改造主角控制器**

Replace `scripts/scenes/player_controller.gd` with:

```gdscript
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
```

- [ ] **Step 5: 运行测试确认通过**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出类似：

```text
测试通过：... 个测试套件
```

- [ ] **Step 6: 提交主角斜方向播放**

Run:

```powershell
git add scripts/scenes/player_controller.gd tests/test_player_diagonal_animation.gd tests/run_tests.gd
git commit -m "feat: 接入主角四斜方向行走动画"
```

Expected: commit 成功，提交内容只包含主角控制器和新增测试。

---

### Task 3: 最终验证

**Files:**
- Verify: `scripts/scenes/character_sprite_loader.gd`
- Verify: `scripts/scenes/player_controller.gd`
- Verify: `tests/test_character_sprite_loader.gd`
- Verify: `tests/test_player_diagonal_animation.gd`
- Verify: `assets/characters/hero_yun/walk/`

- [ ] **Step 1: 运行完整测试套件**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

Expected: PASS，输出类似：

```text
测试通过：... 个测试套件
```

- [ ] **Step 2: 运行 Godot 项目加载检查**

Run:

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . --quit
```

Expected: exit code 0，控制台不应出现脚本解析错误。

- [ ] **Step 3: 检查 git 状态**

Run:

```powershell
git status --short
```

Expected: 没有与本计划相关的未提交代码、测试或素材文件。允许存在用户明确保留的无关本地文件。

