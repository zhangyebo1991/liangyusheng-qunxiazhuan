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

## 验证命令

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果本机没有配置项目本地 Godot 或 PATH 中的 `godot` 命令，先使用文件检查确认结构，再在安装 Godot 4.6 后运行测试。
