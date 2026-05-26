# 角色斜方向动画加载器设计

## 背景

当前探索主角由 `scripts/scenes/player_controller.gd` 创建 `AnimatedSprite2D`，动画帧来自 `scripts/scenes/simple_sprite_factory.gd` 的程序生成占位图。用户已将主角行走素材放入 `assets/characters/hero_yun/walk/`，目前只有四个斜方向序列：

- `down_right/00.png` 至 `down_right/06.png`
- `up_right/00.png` 至 `up_right/06.png`
- `up_left/00.png` 至 `up_left/06.png`
- `down_left/00.png` 至 `down_left/06.png`

本次目标是让探索主角使用这些真实素材，同时保持当前 WASD 移动逻辑和自动寻路逻辑可用。

## 方案选择

采用通用角色动画加载器方案。新增 `scripts/scenes/character_sprite_loader.gd`，让它负责按约定路径生成 `SpriteFrames`。`player_controller.gd` 只负责输入、移动和朝向状态，不直接拼接每一张图片路径。

没有采用直接把加载逻辑写入 `player_controller.gd` 的方式，因为后续会继续增加角色和动作。独立加载器能把资源目录约定集中起来，避免主角控制器承担素材管理职责。

## 资源约定

加载器使用以下路径约定：

```text
res://assets/characters/<角色id>/<动作>/<方向>/<两位帧号>.png
```

本次主角行走动画实际路径示例：

```text
res://assets/characters/hero_yun/walk/down_right/00.png
```

第一版只读取四个斜方向：

- `down_right`
- `up_right`
- `up_left`
- `down_left`

空的 `up`、`down`、`left`、`right` 目录不参与加载判断。

## 朝向规则

`player_controller.gd` 将朝向拆成两个状态：

```text
facing_horizontal = "right"
facing_vertical = "down"
```

默认组合为 `down_right`。输入更新规则如下：

- 有右输入时，`facing_horizontal = "right"`。
- 有左输入时，`facing_horizontal = "left"`。
- 有下输入时，`facing_vertical = "down"`。
- 有上输入时，`facing_vertical = "up"`。

单轴输入只更新对应轴，另一个轴沿用上一次状态。例如默认右下时按上，动画方向变为 `up_right`；随后按左，动画方向变为 `up_left`。

当前动画名使用：

```text
walk_<纵向>_<横向>
```

例如：

```text
walk_down_right
walk_up_right
walk_up_left
walk_down_left
```

角色静止时不切换到独立 `idle` 动画，而是停止当前 `walk_*` 动画并停在第 0 帧。这样不需要额外 idle 素材。

## 组件职责

### `character_sprite_loader.gd`

- 输入角色 id、动作名、方向列表和帧数。
- 按资源约定检查每一帧是否存在。
- 生成 `SpriteFrames`，每个方向对应一个 `walk_*` 动画。
- 设置动画循环播放。
- 素材完整时返回 `SpriteFrames`；素材不完整时返回 `null`，并通过 `push_warning` 输出缺失路径。

### `player_controller.gd`

- 创建 `AnimatedSprite2D`。
- 优先调用 `CharacterSpriteLoader` 加载 `hero_yun` 的 `walk` 素材。
- 素材完整时使用新素材；素材不完整时回退到 `SimpleSpriteFactory`。
- 维护 `facing_horizontal` 和 `facing_vertical`。
- 根据输入更新朝向，并播放或停止当前方向的 `walk_*` 动画。
- 保留现有移动速度、碰撞体、交互信号、自动寻路和手动打断逻辑。
- 增加中文备注：后续补齐 8 方向素材后，需要把当前四斜方向临时方案改成完整 8 方向朝向系统。

## 异常处理

加载器按方向检查 `00.png` 至 `06.png`。任意方向缺任意一帧时，该方向视为不可用。

本次主角需要四个方向都完整才启用新素材。如果四个方向中有任何一组不完整，主角回退到现有占位动画，保证场景仍可启动。缺失资源通过 `push_warning` 输出具体路径，方便补图。

## 测试设计

新增轻量测试覆盖加载器和朝向规则：

- 加载器能创建 `walk_down_right`、`walk_up_right`、`walk_up_left`、`walk_down_left`。
- 每个动画有 7 帧。
- 每个动画设置为循环播放。
- 主角默认朝向为 `down_right`。
- 默认状态按上后朝向为 `up_right`。
- 再按左后朝向为 `up_left`。
- 静止时保持当前方向，并停止在当前动画第 0 帧。

验证命令沿用项目当前测试入口：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
```

## 范围边界

本次不制作新美术、不重命名用户已放入的图片、不引入 8 方向素材，也不修改战棋单位贴图系统。战棋单位目前仍使用 `assets/kenney_tiny-battle/Tiles/`，后续可单独设计角色战斗动画。
