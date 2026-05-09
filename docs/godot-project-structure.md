# Godot 项目结构

## 分层规则

- `scripts/domain/`：只放领域数据和规则对象，不依赖 Godot 场景节点。
- `scripts/systems/`：放可测试的游戏流程，例如数据、地图对象、交互、任务、对话、战斗和存档。
- `scripts/core/`：放全局服务，例如事件总线、游戏状态和场景切换。
- `scripts/scenes/`：放场景脚本，只负责展示、输入和连接系统。
- `data/`：放 JSON 内容数据，示例数据也必须使用中文。
- `scenes/`：放 Godot 场景文件。
- `tests/`：放 GDScript 逻辑测试。

## 中文规则

项目文档、界面文本、示例任务、示例对白、注释和提交说明优先使用中文。代码标识符、Godot API、路径、配置键和命令保留英文。

## 山道探索切片

山道探索切片使用 WASD 连续移动，不使用格子移动。地图地形放在 Godot 场景中，NPC 和战斗触发点由 `data/maps.json` 配置生成。鼠标只用于点击 NPC、交互对象和 UI，不支持点击地面自动寻路。

## 验证命令

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果本机没有配置项目本地 Godot 或 PATH 中的 `godot` 命令，先使用文件检查确认结构，再在安装 Godot 4.6 后运行测试。
