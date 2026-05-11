# 梁羽生群侠传

这是一个使用 Godot 4.6 和 GDScript 开发的免费单机武侠角色扮演游戏项目。

## 当前目标

当前阶段包含：

- Godot 4.6 项目配置。
- 数据加载、任务、对话、战斗和存档基础逻辑。
- 启动、主菜单、山道探索、山脚村镇和战斗场景。
- 山道探索垂直切片：WASD 连续移动、NPC 交互、任务、战斗返回和奖励。
- 山脚村镇任务延伸切片：山道和村镇双向切换、送信到客栈任务、线索记录和存档恢复。
- 轻量背包与物品使用切片：地图内背包面板、小还丹使用、气血恢复和存档恢复。
- 基础回合战斗与武学成长切片：多回合山道强人战、战斗中用药、失败回流和基础剑法熟练度。
- 村外官道与地图规则基础切片：地图场景路径数据化、送信完成后开放官道、路边包裹拾取奖励和对象状态存档。

## 运行方式

安装 Godot 4.6 后，用 Godot 打开本仓库根目录。

如果项目本地 Godot 已下载，可运行：

```powershell
$godot = ".tools\godot\4.6-stable\windows-x86_64\Godot_v4.6-stable_win64_console.exe"
& $godot --headless --path . -s tests/run_tests.gd
& $godot --headless --path . --quit
```

如果 `godot` 命令已加入 PATH，可运行：

```powershell
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . --quit
```
