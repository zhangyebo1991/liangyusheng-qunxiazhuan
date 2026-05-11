# 村外官道与地图规则基础切片设计

日期：2026-05-11
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

下一阶段创建“村外官道与地图规则基础切片”，用一张小型新地图验证地图系统的基础扩展能力。

本阶段的重点不是扩大剧情内容，而是让后续新增地图尽量通过数据和通用系统完成。完成后，项目应从“能手写两个地图切片”推进到“能按地图数据继续扩展地图、出口、条件对象和拾取奖励”。

核心验证点：

- 地图到场景路径由地图数据声明，不再只依赖 `GameState` 中的硬编码分支。
- 村镇官道出口根据“送信到客栈”任务完成状态解锁。
- 地图对象生成支持基础条件过滤。
- 新增 `pickup` 类型地图对象。
- 官道路边包裹可发放小还丹和铜钱。
- 包裹拾取后消失，并通过存档和读档保持。

## 范围

本阶段包含：

- `data/maps.json` 增加 `scene_path` 字段。
- `data/maps.json` 增加 `road_outskirts` 村外官道地图。
- 山脚村镇官道出口指向 `road_outskirts`。
- 官道出口要求 `quest_deliver_letter` 状态为 `completed`。
- 官道出口未解锁时显示中文锁定提示。
- 新增官道 Godot 场景和场景脚本。
- 新增路边包裹 `pickup` 对象。
- 包裹奖励为小还丹 `1` 个和铜钱 `20` 文。
- 拾取成功后包裹进入已解决对象列表。
- 已拾取包裹读档后不再生成。
- 相关系统层逻辑测试和场景无头加载验证。

本阶段不做：

- 大型官道剧情。
- 新战斗敌人。
- 新任务链。
- 随机遭遇。
- 世界地图。
- 正式地图美术。
- 多层地图或室内地图。
- 完整脚本化事件系统。
- 通用表达式条件语言。

## 推荐方案

采用“轻量地图规则基础 + 村外官道小地图”方案。

只重构现有山道和村镇会让能力验证偏抽象；直接做完整官道剧情又会扩大范围。本阶段用一张小官道承载最小内容：一个可条件进入的出口、一个可拾取包裹、一份可存档的奖励结果。

这样每个基础能力都有实际玩法验证，但不会把阶段扩大成新章节制作。

## 架构

项目继续保持“领域逻辑、系统流程、场景表现”分层。

- `data/maps.json` 保存地图静态配置、场景路径、出生点、对象、出口条件和拾取奖励。
- `scripts/core/game_state.gd` 继续保存当前地图、玩家坐标、任务状态、背包、铜钱和已解决对象。
- `scripts/systems/map_transition_system.gd` 处理出口目标、出生点和出口解锁条件。
- `scripts/systems/map_object_spawner.gd` 处理地图对象生成过滤。
- `scripts/systems/map_reward_system.gd` 处理拾取对象奖励。
- `scripts/scenes/map_screen_base.gd` 统一接入出口、商店、背包、对话和拾取对象。
- `scripts/scenes/road_outskirts_screen.gd` 只负责官道地图外观和少量地图个性化配置。
- `scripts/scenes/map_interactable.gd` 负责 `pickup` 类型的提示和调试显示。
- `tests/` 保存地图数据、切换条件、对象生成、奖励和存档测试。

条件、奖励和地图路径属于数据与系统层。具体地图脚本只保留地形、障碍、地图专属对白或特殊交互接线。

## 数据设计

### 地图记录

每张地图增加 `scene_path`：

```json
{
  "id": "road_outskirts",
  "name": "村外官道",
  "scene_path": "res://scenes/road_outskirts.tscn",
  "spawn_position": {"x": 120, "y": 360},
  "spawn_points": {
    "from_foot_village": {"x": 120, "y": 360}
  },
  "objects": []
}
```

现有 `mountain_pass` 和 `foot_village` 也补齐 `scene_path`。

### 条件出口

山脚村镇新增或更新官道出口：

```json
{
  "id": "exit_to_road_outskirts",
  "type": "exit",
  "name": "村外官道",
  "position": {"x": 1160, "y": 360},
  "radius": 72,
  "target_map_id": "road_outskirts",
  "target_spawn_id": "from_foot_village",
  "required_quest_id": "quest_deliver_letter",
  "required_quest_status": "completed",
  "locked_message": "脚夫说前路不太平，先把书信送到客栈再说。"
}
```

第一版只支持单个任务状态条件，不做复杂条件组合。

### 拾取对象

官道地图包含路边包裹：

```json
{
  "id": "pickup_roadside_bundle",
  "type": "pickup",
  "name": "路边包裹",
  "position": {"x": 620, "y": 340},
  "radius": 56,
  "reward_items": ["herb_small"],
  "reward_item_amounts": {"herb_small": 1},
  "reward_coins": 20
}
```

拾取对象被领取后使用现有 `MapState.resolved_objects` 记录，不新增独立拾取存档结构。

## 关键组件

### GameState

`get_scene_path_for_map(map_id)` 改为优先读取 `DataRepository.get_map(map_id).scene_path`。

规则：

- 地图存在且 `scene_path` 非空时返回该路径。
- 地图缺少 `scene_path` 时输出错误日志并回退 `res://scenes/mountain_pass.tscn`。
- 地图编号不存在时输出错误日志并回退 `res://scenes/mountain_pass.tscn`。
- `get_current_map_scene_path()` 继续委托 `get_scene_path_for_map(map_state.current_map_id)`。

这样新增地图时主要改 `data/maps.json` 和新增场景文件，不再扩展 `match map_id` 分支。

### MapTransitionSystem

`resolve_transition(exit_object, target_map, game_state = null)` 增加任务状态条件校验。

规则：

- `target_map_id` 缺失时失败。
- 目标地图不存在时失败。
- 出口声明 `required_quest_id` 和 `required_quest_status` 时，必须从 `game_state.quest_system` 读取状态。
- 状态不满足时失败，返回 `locked_message`。
- 条件满足时返回目标地图编号和目标出生点。

第一版只支持任务状态条件。后续需要物品、旗标或多条件组合时，再扩展通用条件系统。

### MapObjectSpawner

`get_spawn_records(map_data, resolved_objects, game_state = null)` 增加条件过滤。

第一版支持：

- 跳过空 `id` 对象。
- 跳过已存在于 `resolved_objects` 的对象。
- 对象声明 `required_quest_id` 和 `required_quest_status` 时，只有任务状态满足才生成。

对象条件和出口条件使用同一组字段，降低数据认知成本。

### MapRewardSystem

新增 `scripts/systems/map_reward_system.gd`。

主要接口：

- `set_repository(repository)`
- `claim_pickup(game_state, object_record)`

返回字典包含：

- `success`
- `message`
- `items`
- `coins`
- `object_id`

规则：

- `game_state` 或 `game_state.party` 缺失时失败。
- `object_record.id` 为空时失败。
- 对象已解决时失败，并提示“这里什么也没有。”。
- `reward_items` 中不存在的物品跳过。
- 有效物品奖励加入背包。
- `reward_coins > 0` 时加入铜钱。
- 至少发放一类有效奖励后，标记对象已解决。
- 奖励全部无效时不标记对象已解决。

用户可见消息：

- 同时获得物品和铜钱：`获得：小还丹、20 文。`
- 只获得物品：`获得：小还丹。`
- 只获得铜钱：`获得：20 文。`
- 没有有效奖励：`这里什么也没有。`

### MapScreenBase

通用地图场景基础增加 `pickup` 分支。

规则：

- 玩家与 `pickup` 对象交互时调用 `MapRewardSystem.claim_pickup()`。
- 成功后显示系统返回消息。
- 成功后从当前场景隐藏或移除该交互对象。
- 已打开背包时刷新背包面板。
- 已打开商店时刷新商店铜钱显示。

`MapScreenBase` 不写死“路边包裹”的奖励内容，只处理通用拾取流程。

### RoadOutskirtsScreen

新增 `scripts/scenes/road_outskirts_screen.gd`，继承 `map_screen_base.gd`。

职责：

- `configure_map("road_outskirts", ...)`。
- 创建简单背景、边界和少量矩形障碍。
- 可选地设置简短任务提示或空提示。

官道第一版不写专属任务流程，不接战斗。

### MapInteractable

新增 `pickup` 类型支持：

- 交互提示：`按 E 查看包裹`。
- 调试颜色与 NPC、出口、商店、告示牌区分。

## 玩家流程

1. 玩家进入山脚村镇。
2. 在完成“送信到客栈”前，与官道出口交互。
3. 游戏不切图，显示“脚夫说前路不太平，先把书信送到客栈再说。”
4. 玩家完成“送信到客栈”。
5. 玩家再次与官道出口交互。
6. 游戏切换到 `road_outskirts`。
7. 玩家出现在官道村口出生点。
8. 玩家靠近路边包裹，底部提示显示“按 E 查看包裹”。
9. 玩家交互后获得小还丹 `1` 个和铜钱 `20` 文。
10. 包裹从地图中消失。
11. 玩家存档、回主菜单、继续游戏。
12. 读档后玩家仍在正确地图和位置，包裹保持消失，背包与铜钱保持奖励后的数量。

## 输入与界面

沿用现有输入：

- WASD 连续移动。
- E 键交互。
- 鼠标点击交互对象。
- I 键打开背包。
- Esc 存档。

本阶段不新增地图专属 UI。奖励结果通过现有 HUD 短消息显示。

## 存档设计

继续使用现有 `GameState.to_dictionary()` 和 `MapState.to_dictionary()`。

本阶段依赖现有字段：

- `map_state.current_map_id`
- `map_state.player_position`
- `map_state.resolved_objects`
- `party.inventory`
- `party.coins`
- `quest_system`

路边包裹领取后写入 `resolved_objects`。读档后 `MapObjectSpawner` 根据 `resolved_objects` 跳过包裹对象。

## 错误处理

错误处理规则：

- 地图缺少 `scene_path`：回退山道场景，并输出错误日志。
- 地图编号不存在：回退山道场景，并输出错误日志。
- 出口目标地图不存在：不切图，显示 `locked_message` 或“前路尚未开放。”。
- 出口条件不满足：不切图，显示 `locked_message`。
- 出口声明条件但缺少 `game_state`：视为条件不满足。
- 拾取对象没有奖励：显示“这里什么也没有。”，对象不消失。
- 奖励物品不存在：跳过该物品，其他有效奖励继续发放。
- 奖励全部无效：显示“这里什么也没有。”，对象不消失。
- 拾取对象缺少 `id`：不发奖励，不标记对象，并输出错误日志。

## 测试

逻辑测试继续使用 Godot 无头脚本运行。

需要覆盖：

- `maps.json` 可以加载 `3` 张地图。
- `mountain_pass`、`foot_village` 和 `road_outskirts` 都包含 `scene_path`。
- `road_outskirts.scene_path` 为 `res://scenes/road_outskirts.tscn`。
- 山脚村镇官道出口指向 `road_outskirts`。
- 官道出口要求 `quest_deliver_letter` 为 `completed`。
- 未完成送信任务时，`MapTransitionSystem` 阻止切换并返回锁定提示。
- 完成送信任务后，`MapTransitionSystem` 返回 `road_outskirts` 和正确出生点。
- `GameState.get_scene_path_for_map("road_outskirts")` 返回地图数据中的场景路径。
- 未知地图或缺少 `scene_path` 时回退山道场景。
- `MapObjectSpawner` 跳过已解决对象。
- `MapObjectSpawner` 按任务状态过滤条件对象。
- `MapRewardSystem.claim_pickup()` 发放小还丹和 `20` 文。
- `MapRewardSystem.claim_pickup()` 成功后标记对象已解决。
- 已解决拾取对象读档后不再生成。
- 无效奖励不标记对象已解决。
- `MapInteractable.get_interaction_text()` 对 `pickup` 返回包裹提示。
- 官道场景可无头加载。

人工验收：

1. 从主菜单开始或继续游戏进入山脚村镇。
2. 未完成“送信到客栈”时，官道出口显示锁定提示。
3. 完成“送信到客栈”后，官道出口可以进入村外官道。
4. 官道中可看到路边包裹。
5. 靠近包裹显示“按 E 查看包裹”。
6. 交互后显示获得小还丹和铜钱。
7. 背包小还丹增加，铜钱增加 `20`。
8. 包裹消失。
9. 存档并继续游戏后，包裹保持消失，奖励保持。

## 验收标准

本阶段完成后，新增一张村外官道地图时，核心地图路径、出口条件、对象条件和拾取奖励都应由数据和通用系统驱动。

玩家可在完成“送信到客栈”后进入官道，拾取路边包裹获得小还丹和铜钱，并在读档后看到包裹不再重复出现。

## 实现约束

- 所有玩家可见文本必须使用中文。
- 代码标识符、Godot API、路径和配置键可以保留英文。
- 不引入外部插件。
- 不提交 Godot 引擎二进制。
- 逻辑优先写测试，再实现。
- 地图奖励规则必须有系统层测试覆盖。
- `MapRewardSystem` 是拾取奖励发放的唯一入口。
- `MapScreenBase` 不写死具体拾取对象奖励。
- 本阶段不修改 `.spec-workflow/`、`.superpowers/` 或 `.tools/`。
