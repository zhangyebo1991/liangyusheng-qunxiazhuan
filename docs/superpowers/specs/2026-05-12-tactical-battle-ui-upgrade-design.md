# 战棋 UI 全面升级切片设计

日期：2026-05-12
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

把当前「极简色块战棋」升级为**类火纹/梦战的成熟 SRPG 战棋体验**：像素美术 + 顶部集气进度条 + 完整四角信息面板 + 底部图标行动栏 + 范围三态切换 + 移动滑动动画 + 方向型/目标型范围技能 + 空放。

上个切片完成了「客栈休整与内力闭环」，玩家循环拼齐，但战棋本身仍是「Button + ColorRect 拼出来的方格 + 文字标签」，与项目其它系统的成熟度严重脱节，劝退新玩家、阻碍后续武学/友军/Boss 等扩展。本切片**一次性**把战棋从原型态推到「可对外展示、能继续叠加内容」的产品态。

## 范围

本阶段包含：

- **像素美术**：用 Kenney `tiny-battle`（CC0）替换战场色块，包括 8×6 地形 tile 与 1 主角 + 2 强人单位精灵。
- **8×6 网格 + 地形数据化**：地形分「草地 / 浅水 / 桥 / 树（不可走）」四类，每类有 `move_cost`（移动消耗）、`evasion_bonus`（闪避加成）、`passable`（是否可入）字段。
- **顶部集气进度条 UI**：一条 0→1000 的水平条，所有单位的头像图标按 `cur_charge` 实时排在条上，蓝圈友方、红圈敌方，行动阶段时该单位图标停在 1000 端高亮。
- **左上「战斗目标」+「战场信息」面板**：目标固定显示「击败所有敌人」；战场信息显示当前光标所在格的「地形：XX」「效果：XX」。
- **左下「地形信息」面板**：当前光标格地形的图标 + 名称 + 闪避/移动消耗，底部提示「按 Tab 切换地形信息」（Tab 在多地形可见性场景里轮换聚焦地形）。
- **右上「主角信息卡」**：头像 + 名字 + HP/MP 条 + 防御/攻击/移动 数值。
- **右下「战斗日志」**：滚动列表，记录集气开始、招式释放、伤害结算、单位倒下等事件。
- **底部 7 图标行动栏**：移动 / 普通攻击 / 技能 / 道具 / 待机 / 查看 / 系统。当前可用项高亮。
- **选中状态**：当前行动单位脚下白色虚线方括号，头顶倒三角箭头。
- **范围三态切换**：
  - 默认行动开始 = 显示**蓝色移动范围**（按 `move` 与地形 `move_cost` 算可达格）
  - 点底部「普通攻击」= 切换为**红色普攻范围**（1 格相邻）
  - 点底部「技能」+ 选某招 = 切换为**红色技能范围**（按招式 type 计算）
  - 选范围内任意格点击释放（**支持空放** —— 格中无敌人也可释放，消耗内力、计为行动结束）
- **方向型范围技能**：现有「直线剑招」(`straight_sword_thrust`) 升级为「选方向」交互——技能选定后出现 4 个方向箭头（上下左右），点方向后沿该方向投出 2 格直线红色范围，再点确认释放。
- **目标型范围技能**：新增武学「**剑气漩**」(`sword_aura_swirl`)，可选范围 = 主角 3 格内任意格，以选中格为中心释放十字 1 格（上下左右共 5 格）红色范围 + 中心一并命中。消耗内力 8。
- **移动滑动动画**：移动确认后单位以 `Tween` 从起点滑到终点（0.25s/格），**动画期间禁止下一动作输入**，结算在动画结束后触发。
- **删除右下角「主角要做什么」5 选 1 提示文本框**（用底部图标栏取代，对话方框留给后续剧情用）。

本阶段不包含：

- 等级/经验系统（角色卡只显示现有数据）。
- 友军/雇佣（仍 1v2）。
- 多种敌人原型 / Boss（仍现有 2 个强人）。
- 道具栏在战斗内的 UI 重做（点底部「道具」仍走现有 InventorySystem 弹层）。
- 「查看」「系统」两个图标的子菜单实现（点击仅显示「待开发」，不阻塞主流程）。
- AI 决策升级（敌人仍走现有简单逻辑）。
- 多地图战场（仍仅山道战场，但视觉换皮）。
- 旧的「文字流回合战斗」（村外送信遭遇等非战棋路径）的 UI 改造。

## 玩家循环

```
点开战棋 → 看到 8×6 像素地图（草地+浅水+桥）
  ↓
顶部集气条上 1 蓝 + 2 红圈实时移动
  ↓
轮到主角：脚下出白括号、头顶倒三角、底部图标栏「移动」高亮、地图蓝色高亮可达格
  ↓
玩家选择路径之一：
  • 点蓝格 → 滑动动画移动 → 行动结束
  • 点底部「普攻」→ 切红范围（相邻 1 格）→ 选格 → 命中或空放 → 行动结束
  • 点底部「技能」→ 选「直线剑招」→ 选方向 → 红范围出 → 确认 → 释放
  • 点底部「技能」→ 选「剑气漩」→ 选中心格（3 格内）→ 红十字范围出 → 确认 → 释放
  • 点底部「待机」→ 不动 → 行动结束
  ↓
战斗日志记录每一步 → 集气条重排 → 下一单位
  ↓
胜利 → 走客栈切片回流；失败 → 已绑定客栈则切场，否则原地复活
```

## 推荐方案

采用「**美术 + 9 块 UI 面板 + 范围状态机 + Tween 动画 + 数据化地形/招式**」一体化方案。

### 关键决策

1. **保留集气制底层**：上切片刚验证集气制可行，且玩家信息密度（上一个 1000 节奏）已建立。本切片只在 UI 上补「全场单位实时位置可视化」，不动 `tactical_combat_system` 集气推进逻辑。代价是顶部集气条 UI 是新组件，但比改回经典回合制成本低一个数量级。
2. **范围用「状态机」管理而非散落 if**：`battle_screen` 引入 `range_mode: enum { NONE, MOVE, ATTACK, SKILL_DIR_PREVIEW, SKILL_TARGET_PREVIEW }` 枚举，所有「点底部图标 → 重算高亮」逻辑统一走 `_set_range_mode(new_mode)`。避免「移动蓝 + 攻击红」同时出现这种状态混乱 bug。
3. **范围计算抽到 system 层**：新增 `scripts/systems/tactical_range_system.gd`，纯静态/RefCounted 函数：`get_move_range(unit, battle_state, terrain_grid) -> Array[Vector2i]`、`get_attack_range(unit, weapon_id) -> Array[Vector2i]`、`get_skill_range(unit, skill_id, target_or_dir) -> Array[Vector2i]`。`battle_screen` 只负责把结果可视化。这让范围逻辑可单测、可复用到 AI（敌人 AI 用相同函数判断「能否打到主角」）。
4. **Tween 动画走 Godot 原生 `create_tween()` + 信号 `tween_finished`**：动画期间设 `is_animating := true` flag，所有输入早返回。结算在 `tween_finished` 之后调用 `_finalize_move()`。
5. **像素美术不依赖 TileMapLayer 节点**：本切片地形是「数据 + 单层 Sprite2D 摆位」即可，不引入 Godot TileMap 节点（TileMap 学习曲线 + 资源配置较重）。`scripts/scenes/battle_grid.gd` 子节点遍历 8×6 = 48 个 `Sprite2D` 摆 tile 即可。这让代码可控、测试可命中。
6. **Kenney 单位精灵 → 主角/敌人映射写在数据**：`data/actors.json` 给每个 actor 增 `sprite_tile_id` 字段（指向 `assets/kenney_tiny-battle/Tiles/tile_NNNN.png`），不写硬编码。
7. **方向型与目标型技能的范围算法分两个函数**：避免「一个万能函数」分支地狱；后续加「弧形」「环形」等新形状直接加新函数。
8. **集气条 UI 单独 Control 子节点 + 自定义 `_draw`**：避免用 7 个 TextureRect 子节点摆头像（性能 OK 但代码难维护）。`scripts/scenes/charge_bar.gd` 收单位列表，`_process` 按 `cur_charge / 1000` 算 X 偏移，`queue_redraw` 重画。
9. **删除「主角要做什么」文本提示框**：底部图标栏 + 高亮态已经表达了「玩家可点哪些」，文字提示属于初学者引导（留给未来教程切片处理）。

## 架构

继续保持「核心 / 领域 / 系统 / 场景」四层。新增 / 修改：

### 新增脚本

- `scripts/systems/tactical_range_system.gd`（RefCounted）：范围计算
  - `get_move_range(unit, battle_state, terrain_grid) -> Array[Vector2i]`
  - `get_attack_range_simple(unit) -> Array[Vector2i]`（普攻 1 格）
  - `get_skill_directional_range(unit, skill_id, direction: Vector2i) -> Array[Vector2i]`
  - `get_skill_target_selection_range(unit, skill_id) -> Array[Vector2i]`（目标型可选中心格集合）
  - `get_skill_target_blast_range(skill_id, center: Vector2i) -> Array[Vector2i]`（中心确定后的命中格）
- `scripts/systems/terrain_system.gd`（RefCounted）：地形数据查询
  - `get_terrain(terrain_id) -> Dictionary`
  - `get_move_cost(terrain_id) -> int`
  - `get_evasion_bonus(terrain_id) -> int`
  - `is_passable(terrain_id) -> bool`
- `scripts/scenes/charge_bar.gd`（Control）：顶部集气条
- `scripts/scenes/battle_action_bar.gd`（Control）：底部 7 图标行动栏
- `scripts/scenes/battle_panel_objective.gd`（Control）：左上「战斗目标 + 战场信息」
- `scripts/scenes/battle_panel_terrain.gd`（Control）：左下「地形信息」
- `scripts/scenes/battle_panel_actor.gd`（Control）：右上「主角信息卡」
- `scripts/scenes/battle_log.gd`（Control）：右下「战斗日志」
- `scripts/scenes/battle_grid.gd`（Node2D）：地形 tile 显示 + 单位精灵管理 + 范围高亮 overlay
- `scripts/scenes/tactical_unit_sprite.gd`（Node2D）：单位精灵 + HP 条 + 选中括号 + 倒三角

### 修改脚本

- `scripts/scenes/battle_screen.gd`：去掉 ColorRect+Button 旧网格、引入 9 个 UI 子组件、引入 `range_mode` 状态机、去掉「主角要做什么」Label。
- `scripts/systems/tactical_combat_system.gd`：地形参数接入移动/闪避计算（小改）；新增 `sword_aura_swirl` 招式分支；保留所有现有公共 API。
- `scripts/domain/tactical_battle_state.gd`：增 `terrain_grid: Array[Array[String]]`（8 行 × 6 列地形 ID 矩阵）。
- `scripts/domain/tactical_unit_state.gd`：增 `sprite_tile_id: String`（从 actors.json 读）。
- `scripts/core/event_bus.gd`：增信号 `tactical_unit_moved(unit_id, from_pos, to_pos)`、`tactical_action_resolved(unit_id, action_id, target_cells)`、`tactical_log_appended(line)`、`tactical_range_mode_changed(mode)`。

### 不动的脚本

- `scripts/systems/combat_system.gd`（非战棋）
- `scripts/systems/effect_system.gd`、`condition_system.gd`、`inventory_system.gd`、`shop_system.gd` 等（已稳定）
- `scripts/core/game_state.gd`（除既有 `hero_cur_mp` 外不动）

## 数据设计

### `data/martial_arts.json` 新增「剑气漩」

```json
{
  "id": "sword_aura_swirl",
  "name": "剑气漩",
  "description": "凝聚内力一掷，目标处剑气漩起，伤及周遭。",
  "mp_cost": 8,
  "shape": "target_cross_1",
  "cast_range": 3,
  "base_damage": 14,
  "scale_attr": "atk",
  "scale_ratio": 0.6
}
```

`shape` 字段为新枚举：`"line_2"`（现有直线剑招升级值）、`"target_cross_1"`（剑气漩）、`"adjacent_1"`（普攻）。

现有 `straight_sword_thrust` 项追加 `"shape": "line_2"`。

### `data/actors.json` 角色新增 `sprite_tile_id`

每个 actor 项追加：

```json
"sprite_tile_id": "tile_0260"
```

主角用 `tile_0260`（蓝色剑士），强人用 `tile_0280`（红色士兵），具体 tile 编号在实施阶段对照 packed sheet 选定。

### `data/maps.json` 山道战场新增 `terrain_grid`

在战棋触发节点（`mountain_pass` 战斗触发器）的 battle 配置下追加：

```json
"terrain_grid": [
  ["grass","grass","grass","water","grass","grass","grass","grass"],
  ["grass","grass","grass","water","grass","grass","tree","grass"],
  ["grass","tree","grass","bridge","grass","grass","grass","grass"],
  ["grass","grass","grass","water","grass","grass","grass","grass"],
  ["grass","grass","grass","water","grass","grass","tree","grass"],
  ["grass","grass","grass","water","grass","grass","grass","grass"]
]
```

### 新增 `data/terrains.json`

```json
{
  "grass":  { "name":"草地", "passable":true,  "move_cost":1, "evasion_bonus":0,  "tile_id":"tile_0024" },
  "water":  { "name":"浅水", "passable":true,  "move_cost":2, "evasion_bonus":-10, "tile_id":"tile_0001" },
  "bridge": { "name":"桥",   "passable":true,  "move_cost":1, "evasion_bonus":0,  "tile_id":"tile_0048" },
  "tree":   { "name":"树丛", "passable":false, "move_cost":99,"evasion_bonus":0,  "tile_id":"tile_0096" }
}
```

实施阶段会用 Python 脚本扫 `Tilemap/tilemap_packed.png`（16×16 网格，9 列 × N 行）确定真实 tile 编号映射。

### `data/dialogues.json` 不变

### `data/items.json` 不变

## 领域状态与存档

### `tactical_battle_state.gd` 新增字段

```gdscript
var terrain_grid: Array  # Array[Array[String]] 8×6 地形 ID 矩阵
```

### `tactical_unit_state.gd` 新增字段

```gdscript
var sprite_tile_id: String = ""
```

### 存档兼容

战斗状态本身不入存档（每次战斗即时构建），所以**无存档迁移负担**。

`actors.json` 的 `sprite_tile_id` 是数据字段，没有玩家存档关系。

## 关键边界与契约

### 1. 范围三态状态机

`battle_screen.gd` 唯一改 `range_mode` 的入口是 `_set_range_mode(mode)`。任何「点图标」「选完方向」「确认释放」事件都通过它走。

```gdscript
enum RangeMode { NONE, MOVE, ATTACK, SKILL_DIR_PREVIEW, SKILL_TARGET_PREVIEW }
```

切换时一律先 `battle_grid.clear_range_overlay()` 再算新范围画上。**禁止**任何场景代码自行 `add_child(blue_cell)` / `queue_free` 范围 overlay。

### 2. 空放语义

凡 `range_mode in [ATTACK, SKILL_DIR_PREVIEW, SKILL_TARGET_PREVIEW]` 时点范围内格子：

- 计算命中：`tactical_combat_system.resolve_action(unit, action_id, target_cells)` 自动遍历命中格内的敌人，无敌人则结算 `[]`。
- **始终消耗 MP**（招式 cost）+ **始终算行动结束**（推进集气阶段）。
- 战斗日志会记 `「主角对 (3,4) 释放剑气漩，无人命中。」` 提示玩家这是空放。

### 3. 移动动画与异步行动

```gdscript
var is_animating := false

func _on_cell_clicked(cell):
    if is_animating: return
    if range_mode == RangeMode.MOVE:
        _start_move_animation(cell)

func _start_move_animation(target):
    is_animating = true
    var tween = create_tween()
    tween.tween_property(unit_sprite, "position", grid_to_pixel(target), 0.25 * path.size())
    tween.tween_callback(_finalize_move.bind(target))

func _finalize_move(target):
    is_animating = false
    tactical_combat_system.commit_move(battle_state, current_unit_id, target)
    # 触发行动结束流程
```

**强约束**：所有 `_process` 中 `tactical_combat_system.advance_charge` 推进**也**要在 `is_animating == false` 时才推进，否则集气在动画中持续走会导致行动单位切换异常。

### 4. 方向型技能交互

选了「直线剑招」后 `range_mode = SKILL_DIR_PREVIEW`，地图显示 4 个箭头按钮叠在主角四向相邻格。点箭头：
- `_pending_direction = direction`
- 算 `range_cells = get_skill_directional_range(unit, "straight_sword_thrust", direction)`
- 把 `range_mode` 切到 `SKILL_TARGET_PREVIEW`（语义上"等待确认"），高亮显示。
- 玩家**再次点**任意 range_cells 内的格子（或显示「确认」按钮）即释放。

为简化交互：**直接确认**——点方向箭头后立即释放，不要二次确认。

### 5. 目标型技能交互

选了「剑气漩」后 `range_mode = SKILL_TARGET_PREVIEW`：
- 算 `selectable_centers = get_skill_target_selection_range(unit, "sword_aura_swirl")`（主角 3 格内）
- 蓝色高亮可选中心格
- 鼠标悬停时实时显示该格 + 十字 5 格的红色预览（hover-preview）
- 点击中心格 → 释放（同样不二次确认）

### 6. 顶部集气条数据流

`charge_bar.gd` 每帧 `_process(delta)`：
- 收 `battle_state.units` 列表
- 算每个 unit 的 X 偏移 = `unit.cur_charge / 1000.0 * bar_width`
- `queue_redraw`，`_draw` 用 `draw_circle` 画头像背景 + `draw_texture_rect` 画头像（行动期高亮放大 1.2 倍）

### 7. 跨 UI 数值一致性

地形信息、HP/MP 数值、招式 MP cost 都走数据/状态对象 single source。任何 UI 面板**禁止**复算这些数值。

### 8. 删除「主角要做什么」提示

直接删 `battle_screen.gd` 中 `unit_panel: VBoxContainer` 相关创建/刷新代码，**不**保留隐藏节点（与本切片底部图标栏功能完全重叠，留着只造混淆）。如有测试断言其存在，本切片同步更新测试。

## 测试覆盖

按项目「信号契约必端到端测」沉淀，新增 7 个测试文件：

- `tests/test_terrain_system.gd`：terrain_system.get_terrain / move_cost / passable + 加载 terrains.json + 异常 ID 兜底
- `tests/test_tactical_range_system.gd`：移动范围算法在 8×6 草地、含水/桥/树阻挡场景的正确性 + 普攻范围 + 直线剑招方向型范围 + 剑气漩选中心格集合 + 剑气漩十字命中范围
- `tests/test_tactical_battle_terrain_grid.gd`：tactical_battle_state 持有 terrain_grid，combat_system 创建战斗时正确从 maps.json 加载
- `tests/test_sword_aura_swirl_skill.gd`：剑气漩数据加载 + tactical_combat_system.resolve_action 正确遍历十字 + 命中伤害 + 空放（中心无敌人/十字格全空）正确扣 MP 不命中
- `tests/test_battle_action_empty_cast.gd`：普攻空放、直线剑招空放、剑气漩空放都消耗 MP + 推进集气阶段 + 触发 `tactical_action_resolved` 信号
- `tests/test_charge_bar_layout.gd`：charge_bar 给定 mock 单位列表能正确算 X 偏移 + 行动单位被识别为 highlight
- `tests/test_battle_screen_range_mode.gd`：range_mode 状态机 NONE→MOVE→ATTACK→NONE 切换路径 + 切到 ATTACK 时 move 高亮被清

现有测试扩展：

- `tests/test_tactical_combat_system.gd`：扩展验地形 move_cost 影响可达；扩展 sword_aura_swirl
- `tests/test_tactical_battle_state.gd`：扩展验 terrain_grid 字段
- `tests/test_tactical_unit_state.gd`：扩展验 sprite_tile_id 字段
- `tests/test_data_loader.gd`：自动覆盖 terrains.json + 剑气漩
- `tests/test_map_data.gd`：扩展 mountain_pass 战斗 terrain_grid 校验
- `tests/test_tactical_battle_screen.gd`：**整体重写**，去掉旧 ColorRect+Button 断言，改为「9 子组件存在 + range_mode 初始 = MOVE + 删除"主角要做什么"Label」

## 实施顺序

每步可独立 commit、可独立 `--headless` 跑测试：

1. **terrain_system + terrains.json**（无视觉，纯数据 + system）
2. **maps.json 加 terrain_grid + tactical_battle_state.terrain_grid 字段 + combat_system 加载**
3. **tactical_range_system + 移动范围算法**（接入地形 move_cost）
4. **tactical_range_system + 普攻范围 + 直线剑招方向型范围**
5. **martial_arts.json 加剑气漩 + tactical_combat_system.resolve_action 加 sword_aura_swirl 分支**
6. **tactical_range_system + 剑气漩目标型范围算法**（选中心 + 十字）
7. **空放支持**（resolve_action 能处理 target_cells 为空集，仍扣 MP 推进集气）
8. **actors.json 加 sprite_tile_id + tactical_unit_state 字段**
9. **battle_grid.gd（地形 tile + 单位精灵）+ 替换 battle_screen 旧网格创建逻辑**
10. **tactical_unit_sprite.gd（单位精灵 + HP 条 + 选中括号 + 倒三角）**
11. **range overlay（蓝/红高亮）+ range_mode 状态机**
12. **底部 battle_action_bar 7 图标 + 状态机接线**
13. **顶部 charge_bar UI**
14. **左上 panel_objective + 左下 panel_terrain + Tab 切换**
15. **右上 panel_actor**
16. **右下 battle_log + EventBus 信号接线**
17. **方向型技能交互（4 方向箭头）**
18. **目标型技能交互（hover 预览）**
19. **移动滑动动画 + is_animating 锁**
20. **删除「主角要做什么」Label + 旧 unit_panel + 重写 test_tactical_battle_screen.gd**
21. **全套 `--headless` 跑通 + 手动 UAT 三循环**：胜利循环、失败回流循环、剑气漩+空放+方向型流程

## 与项目沉淀对齐

- 数据 .json 改动后 `--headless --import` 刷新缓存
- 测试目录与玩家存档物理隔离（沿用 `saves_test/` 沙盒）
- 信号契约端到端测：`test_battle_action_empty_cast` 必须验证 `EventBus.tactical_action_resolved` 真发出
- 跨 UI 数值一致性 single source：HP/MP 走 game_state、地形数据走 terrain_system、范围算法走 tactical_range_system，**禁止**任何场景脚本旁路计算
- container & z_index 风险：范围 overlay 用单独 Node2D 子层 + z_index=10；hover 预览用 z_index=20；底部图标栏放 CanvasLayer 避免被 grid 覆盖
- 测试中实例化 UI 节点要警惕 autoload 依赖（参考 hud_mp 的「严格版/退化版」选择）
- BattleResult 字段沿用 `victor`(int) / `rounds`(int) / `log`(Array[BattleAction])，**不动**
- BattleResult 胜负常量 `VICTOR_PLAYER=0` / `VICTOR_ENEMY=1` / `VICTOR_DRAW=2`，跨模块引用必走常量

## 风险与未决

- **R1**：Tween 动画 + 集气推进 `_process` 的并发协调可能在测试环境下不稳。**对策**：is_animating 设计为「集气推进早返回 + 输入早返回」双闸，测试用 `await tween.tween_finished` 同步。
- **R2**：Kenney `tile_NNNN` 编号到 packed sheet 的映射要实施期人工对照确认（packed sheet 是横向排布，9 列）。**对策**：实施阶段先写 Python 脚本切 sheet 出 200 个独立 tile 命名 `tile_0000.png`～`tile_0197.png`（已经是这个布局，可直接用 `Tiles/tile_NNNN.png`）。
- **R3**：旧测试 `tests/test_tactical_battle_screen.gd` 大量断言旧 UI 节点。**对策**：实施 Step 20 一并重写而非逐步 patch，避免中途测试一直挂。
- **R4**：Plan 估 25-30 Task / 3 周。子智能体串行执行模式下需要主线程频繁 `git log` 验证。**对策**：plan 阶段把每 Task 严格控制在「3-7 Step / 一次 commit」，遵循已验证模板。
- **R5**：本切片不动 `combat_system.gd`（非战棋路径），但村外送信遭遇仍是文字流战斗。**遗留**：玩家会在不同遭遇看到「极简文字战斗」vs「华丽战棋」两种风格，需在下一切片或同步切片中考虑统一。本切片范围内**不解决**。
