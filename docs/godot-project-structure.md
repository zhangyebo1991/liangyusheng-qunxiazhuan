# Godot 项目结构

## 分层规则

- `scripts/domain/`：只放领域数据和规则对象，例如地图状态、战斗状态、队伍、角色、物品和武学记录，不依赖 Godot 场景节点。
- `scripts/systems/`：放可测试的游戏流程，例如数据、地图对象、地图切换、交互、任务、对话、战斗、背包和存档。
- `scripts/core/`：放全局服务，例如事件总线、游戏状态和场景切换。
- `scripts/scenes/`：放场景脚本，只负责展示、输入和连接系统。
- `data/`：放 JSON 内容数据，示例数据也必须使用中文。
- `scenes/`：放 Godot 场景文件。
- `tests/`：放 GDScript 逻辑测试。

## 中文规则

项目文档、界面文本、示例任务、示例对白、注释和提交说明优先使用中文。代码标识符、Godot API、路径、配置键和命令保留英文。

## 山道探索切片

山道探索切片使用 WASD 连续移动，不使用格子移动。地图地形放在 Godot 场景中，NPC 和战斗触发点由 `data/maps.json` 配置生成。鼠标只用于点击 NPC、交互对象和 UI，不支持点击地面自动寻路。

## 山脚村镇切片

山脚村镇切片使用同一套地图对象和交互结构。山道出口和村镇返回出口由 `data/maps.json` 配置，`MapTransitionSystem` 解析目标地图和出生点。村镇第一版是一条主街，包含客栈掌柜、村口脚夫、告示牌和未开放官道出口。

## 轻量背包切片

轻量背包切片使用 `I` 键在地图中打开背包面板。背包数量保存在 `GameState.party.inventory`，物品资料来自 `data/items.json`，物品使用规则由 `InventorySystem` 处理。HUD 只负责显示背包列表和发出使用请求，不直接修改背包数量或气血。

## 回合战斗与武学成长切片

回合战斗切片使用 `BattleState` 保存战斗运行时状态，`CombatSystem` 处理玩家攻击、敌人反击、战斗中用药、暂退和胜负。战斗界面只显示双方气血、按钮和日志，不直接计算伤害或扣除背包。胜利后 `GameState` 负责清除地图对象、推进任务，并记录 `basic_sword` 熟练度。

## 村外官道与地图规则基础切片

村外官道切片让 `data/maps.json` 声明地图场景路径、出口条件和拾取奖励。`GameState` 通过地图数据读取场景路径，`MapTransitionSystem` 校验任务状态后开放出口，`MapObjectSpawner` 根据任务状态和已解决对象过滤生成对象。`MapRewardSystem` 是拾取奖励发放入口，官道路边包裹领取后写入 `MapState.resolved_objects`，读档后不再生成。

## 双向地图预览编辑器

探索地图布局使用 `data/map_layouts/<map_id>.json` 保存地图尺寸、背景、出生点、障碍物、对象坐标和交互半径。`data/maps.json` 继续保存任务、对白、战斗、奖励、商店和出口目标等玩法字段。

Godot 编辑器插件位于 `addons/map_preview/`。打开地图场景后，插件会根据 `data/maps.json` 的 `scene_path` 匹配 `map_id`，读取布局文件并在场景根节点下生成 `GeneratedMapPreview`。这些预览节点只用于编辑器预览和微调，默认不作为正式 `.tscn` 内容提交。

AI 修改布局文件后，插件会自动刷新预览。用户在编辑器中拖拽预览 handle 并点击保存后，插件会把新的坐标或尺寸写回同一个布局文件。运行时通过 `DataRepository.get_map()` 合并玩法数据和布局数据，所以编辑器预览与实际运行应保持一致。

## 任务奖励与效果数据化基础切片

任务奖励与效果数据化切片使用 `EffectSystem` 统一执行内容数据声明的结果。`data/quests.json` 的 `complete_effects` 描述任务完成效果，`data/maps.json` 的拾取对象 `effects` 描述拾取结果，战斗胜利回流可通过 `victory_effects` 或兼容字段生成效果。`EffectSystem` 支持添加物品、添加铜钱、设置 flag、设置任务状态、标记地图对象已解决和增加武学熟练度。场景脚本只负责触发和展示消息，不直接硬写奖励、线索或任务状态。

## 剧情事件与分支对话基础切片

剧情事件与分支对话切片使用 `ConditionSystem` 判断内容条件，使用 `EventSystem` 在条件满足后执行 `EffectSystem` 效果。`data/dialogues.json` 的 `options` 描述玩家可选分支、条件、效果和后续对白，`data/maps.json` 只声明 NPC 的 `dialogue_id`。`DialogueBox` 只展示对白和选项，`MapScreenBase` 负责把选项交给系统层执行，不在地图脚本里硬写奖励、flag 或背包变化。

## 江湖记事基础切片

江湖记事切片使用 `JournalState` 保存追踪任务、可追查传闻和已触发传闻，使用 `JournalSystem` 统一处理传闻记录、传闻归档和任务追踪上限。地图中按 `J` 或点击 HUD“记事”按钮打开独立页面。HUD 只显示最多 3 个追踪任务，记事页面负责展示任务列表和传闻列表，不直接修改任务、传闻或存档状态。

## 方格战棋与集气基础切片

方格战棋切片新增 `TacticalUnitState` 和 `TacticalBattleState` 保存战棋单位与战斗运行时状态，新增 `TacticalCombatSystem` 处理实时集气、行动暂停、移动范围、攻击范围、敌人 AI、胜负和暂退。山道强人触发点通过 `data/maps.json` 声明 `battle_mode = "tactical"`、战场尺寸、单位站位和集气速度；`battle_screen.gd` 根据战斗上下文分流普通回合战斗和战棋战斗。战棋胜利仍生成 `GameState.apply_battle_result()` 可处理的 payload，不直接修改任务、地图对象或熟练度。

## 战棋武学与内力基础切片

战棋武学切片使用 `data/martial_arts.json` 的 `tactical` 字段声明战棋伤害加值、内力消耗、范围和范围形状。`GameState` 只保存主角长期最大内力；战棋单位的当前内力保存在 `TacticalUnitState`，每场战斗开局回满。`TacticalCombatSystem` 是普通攻击和武学攻击的统一规则入口，负责校验武学归属、内力、范围、伤害和胜负；`BattleScreen` 只负责动作按钮、内力显示、格子高亮和点击接线。

## 战利品掉落与可重复遭遇切片

战利品掉落切片在 `victory_rewards` 中增加嵌入式 `loot_table`。`LootSystem` 只负责按概率生成结构化掉落结果，不直接修改背包、铜钱或 UI。`GameState` 在战斗胜利时继续统一发放固定奖励和随机掉落，并把结果写入 `last_reward_result` 供奖励面板展示。

可重复战斗对象使用 `repeatable = true`。这类战斗胜利后不写入 `MapState.resolved_objects`，返回地图后仍可再次挑战；未声明该字段的战斗保持一次性逻辑。奖励面板、背包、商店和地图奖励消息必须通过物品资料显示中文名，不能把 `item_id` 直接展示给玩家。

## 验证命令

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果本机没有配置项目本地 Godot 或 PATH 中的 `godot` 命令，先使用文件检查确认结构，再在安装 Godot 4.6 后运行测试。
