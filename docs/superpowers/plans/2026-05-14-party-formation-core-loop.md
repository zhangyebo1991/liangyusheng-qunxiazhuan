# 出战编队基础闭环实施计划

> **给执行 agent：** 实施本计划时必须使用 `superpowers:subagent-driven-development` 或 `superpowers:executing-plans`，按任务逐步完成。每个任务使用 checkbox 追踪，完成一个可验证切片后提交一次。

**目标：** 建立第一版出战编队闭环：玩家在队伍面板调整默认出战顺序，战斗按地图配置的上限和起始格生成玩家单位，战后倒下成员保留 1 点气血，编队和成员状态随存档恢复。

**架构：** `PartyState` 只保存和规范化默认编队顺序；地图战斗数据只声明本场出战上限和起始格；`TacticalCombatSystem` 组合两者生成玩家单位；`GameState` 统一回写战斗结果并执行战后 1 血保护；`PartyPanel` 提供最小顺序调整 UI。

**技术栈：** Godot 4.6、GDScript、JSON 数据表、现有自定义 `tests/run_tests.gd` 测试入口。

---

## 文件结构

### 新增

- `docs/superpowers/plans/2026-05-14-party-formation-core-loop.md`：本实施计划。

### 修改

- `scripts/domain/party_state.gd`：新增 `formation_order`、编队规范化、上移下移、旧存档兼容。
- `scripts/systems/tactical_combat_system.gd`：读取 `player_deploy`，按默认编队和地图起始格生成玩家单位。
- `scripts/core/game_state.gd`：战斗回写时对倒下成员执行 1 血保护，并同步主角旧字段。
- `scripts/scenes/party_panel.gd`：新增“默认出战顺序”区域和上移/下移按钮。
- `data/maps.json`：给山道强人战补充 `player_deploy`，至少 2 个玩家起始格。
- `tests/test_party_state.gd`：覆盖编队状态、排序、序列化和旧存档兼容。
- `tests/test_tactical_party_battle.gd`：覆盖地图出战上限、起始格顺序和兼容旧配置。
- `tests/test_combat_and_save.gd` 或新增专测：覆盖倒下成员战后写回 1 血和存档恢复。
- `tests/test_party_panel.gd`：覆盖默认出战顺序 UI 和按钮行为。

每个验证步骤都使用这个命令：

```powershell
$godotExe = "D:/Projects/games/liangyusheng-qunxiazhuan/.tools/godot/4.6-stable/windows-x86_64/Godot_v4.6-stable_win64_console.exe"
& $godotExe --headless --path "." -s "res://tests/run_tests.gd"
Write-Output "GodotExit:$LASTEXITCODE"
```

成功标准：输出包含 `测试通过：`，并且 `GodotExit:0`。

---

## Task 1: PartyState 默认编队状态

**文件：**

- 修改：`scripts/domain/party_state.gd`
- 修改：`tests/test_party_state.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/test_party_state.gd` 增加以下覆盖点：

- 新游戏或旧存档缺 `formation_order` 时，默认编队等于队伍成员顺序，但主角必须在首位。
- `set_formation_order(["qingshanke", "hero_yun", "missing", "qingshanke"])` 后，读取结果应过滤缺失角色、去重，并把主角规范到首位。
- 新队友加入后调用规范化，未在编队中的队友追加到队尾。
- `move_formation_member("qingshanke", -1)` 不应把队友移动到主角之前。
- `move_formation_member("qingshanke", 1)` 能在非主角成员之间调整顺序。
- `to_dictionary()` / `from_dictionary()` 能保存和恢复 `formation_order`。

建议断言文案全部使用中文，避免直接显示内部 ID。

- [ ] **Step 2: 运行测试确认红灯**

运行全量测试。预期失败，因为 `PartyState` 还没有编队字段和 helper。

- [ ] **Step 3: 实现 PartyState 编队 API**

在 `PartyState` 增加：

```gdscript
var formation_order: Array[String] = []
```

新增方法：

```gdscript
func get_formation_order() -> Array[String]
func set_formation_order(actor_ids: Array) -> void
func move_formation_member(actor_id: String, direction: int) -> void
func get_deployable_members(max_members: int) -> Array[String]
func normalize_formation() -> void
```

实现规则：

- 只保留 `party.members` 中存在的角色。
- 主角 `hero_yun` 必须存在且排在首位。
- 重复角色只保留第一次。
- 未在编队中的成员追加到队尾。
- `get_deployable_members(max_members)` 返回编队前 N 名，`max_members <= 0` 时返回空数组。
- `add_member()` 成功新增成员后调用 `normalize_formation()`。
- `from_dictionary()` 读取 `formation_order` 后调用 `normalize_formation()`。
- `to_dictionary()` 写入规范化后的 `formation_order`。

- [ ] **Step 4: 运行测试并提交**

运行全量测试，预期通过。提交：

```powershell
git add scripts/domain/party_state.gd tests/test_party_state.gd
git commit -m "feat: 增加默认出战编队状态" --no-gpg-sign
```

---

## Task 2: 战棋读取地图出战配置

**文件：**

- 修改：`scripts/systems/tactical_combat_system.gd`
- 修改：`tests/test_tactical_party_battle.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/test_tactical_party_battle.gd` 增加场景：

- 队伍包含主角和青衫客。
- `party.set_formation_order(["hero_yun", "qingshanke"])`。
- 战斗 context 包含：

```gdscript
"player_deploy": {
    "max_members": 2,
    "start_cells": [
        {"q": 4, "r": 3},
        {"q": 4, "r": 4},
    ]
}
```

断言：

- 玩家单位数量为 2。
- 主角位于 `{q=4, r=3}`。
- 青衫客位于 `{q=4, r=4}`。
- `max_members = 1` 时只生成主角。
- 起始格只有 1 个时只生成主角，并有中文日志说明队友未入场。

- [ ] **Step 2: 运行测试确认红灯**

运行全量测试。预期失败，因为系统还不读取 `player_deploy`。

- [ ] **Step 3: 实现 player_deploy 解析**

在 `TacticalCombatSystem.create_battle()` 中读取：

- `context.player_deploy.max_members`
- `context.player_deploy.start_cells`

保留兼容顺序：

1. 优先 `player_deploy.start_cells`。
2. 其次旧 `player_start_cells`。
3. 再其次旧 `units.team = player` 的 `start_cell`。
4. 最后使用现有兜底起始格。

调整 `_add_party_player_units()`：

- 使用 `game_state.party.get_deployable_members(max_members)`。
- 按出战成员顺序生成单位。
- 起始格不足或无效时写中文日志。
- 日志中的角色名优先使用 `stats.display_name`，不要显示内部 ID。

- [ ] **Step 4: 运行测试并提交**

运行全量测试，预期通过。提交：

```powershell
git add scripts/systems/tactical_combat_system.gd tests/test_tactical_party_battle.gd
git commit -m "feat: 战棋按编队生成玩家单位" --no-gpg-sign
```

---

## Task 3: 战后倒下成员保留 1 点气血

**文件：**

- 修改：`scripts/core/game_state.gd`
- 修改：`tests/test_tactical_party_battle.gd`
- 可选修改：`tests/test_combat_and_save.gd`

- [ ] **Step 1: 写失败测试**

覆盖以下结果回写：

```gdscript
"party_member_results": {
    "hero_yun": {"hp": 0, "mp": 3},
    "qingshanke": {"hp": 0, "mp": 1}
}
```

断言：

- 战斗结果应用后，主角成员状态 HP 为 1。
- 青衫客成员状态 HP 为 1。
- 主角旧字段 `hero_hp` 也同步为 1 或遵循现有失败回流后的最终值，但不能与 `party.member_status.hero_yun.hp` 矛盾。
- 胜利、失败、暂退路径都触发 1 血保护。
- 存档恢复后倒下成员仍为 1 血。

- [ ] **Step 2: 运行测试确认红灯**

运行全量测试。预期失败，因为当前会把 0 HP 直接写回成员状态。

- [ ] **Step 3: 实现统一保护**

在 `GameState` 的战斗结果回写路径中增加 helper：

```gdscript
func _protected_battle_hp(value: int) -> int:
    if value <= 0:
        return 1
    return value
```

应用到所有 `party_member_results` 写回位置。确保：

- 只对参战并出现在结果里的队伍成员生效。
- MP 仍按战斗结果写回并 clamp 到非负。
- 主角旧字段与 `PartyState` 同步。
- 失败回客栈逻辑若已经回满主角，以回客栈后的状态为准，但不得留下 0 HP。

- [ ] **Step 4: 运行测试并提交**

运行全量测试，预期通过。提交：

```powershell
git add scripts/core/game_state.gd tests/test_tactical_party_battle.gd tests/test_combat_and_save.gd
git commit -m "feat: 战后倒下队友保留一血" --no-gpg-sign
```

如果没有修改 `tests/test_combat_and_save.gd`，提交命令中去掉该文件。

---

## Task 4: 队伍面板编队 UI

**文件：**

- 修改：`scripts/scenes/party_panel.gd`
- 修改：`tests/test_party_panel.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/test_party_panel.gd` 覆盖：

- 面板刷新后出现“默认出战顺序”。
- 主角行显示“必出战”。
- 青衫客行显示中文名，不显示 `qingshanke`。
- 点击“上移”或直接调用对应 handler 后，`party.get_formation_order()` 顺序改变。
- 主角不能被移到非首位。
- 装备区域和成员详情仍能正常刷新。

- [ ] **Step 2: 运行测试确认红灯**

运行全量测试。预期失败，因为面板还没有编队 UI。

- [ ] **Step 3: 实现最小 UI**

在 `PartyPanel` 增加：

- `VBoxContainer _formation_list`
- 标题 `默认出战顺序`
- 每行显示成员中文名。
- 主角附加 `必出战` 标记，不提供可破坏主角首位的操作。
- 非主角行提供 `上移`、`下移` 按钮。
- 按钮调用 `party.move_formation_member(actor_id, direction)` 后刷新面板。

保持第一版简单：不用拖拽、不用图标、不用战前确认弹窗。

- [ ] **Step 4: 运行测试并提交**

运行全量测试，预期通过。提交：

```powershell
git add scripts/scenes/party_panel.gd tests/test_party_panel.gd
git commit -m "feat: 队伍面板支持默认出战顺序" --no-gpg-sign
```

---

## Task 5: 地图数据投放与兼容测试

**文件：**

- 修改：`data/maps.json`
- 修改：`tests/test_tactical_party_battle.gd`
- 可选修改：`tests/test_effect_data.gd`

- [ ] **Step 1: 写失败测试或扩展现有测试**

针对真实 `mountain_pass.enemy_bandit_gate` 数据断言：

- 存在 `player_deploy.max_members`。
- `player_deploy.max_members >= 2`。
- `player_deploy.start_cells` 至少 2 个。
- 实际创建山道强人战时，主角和青衫客在青衫客入队后可以同时入场。

- [ ] **Step 2: 更新地图数据**

在山道强人 `battle_trigger` 中加入：

```json
"player_deploy": {
  "max_members": 2,
  "start_cells": [
    {"q": 5, "r": 3},
    {"q": 5, "r": 4}
  ]
}
```

保留旧 `units` 中玩家项，直到兼容测试确认不再依赖它。若后续清理旧玩家项，必须另开任务并补迁移测试。

- [ ] **Step 3: 运行测试并提交**

运行全量测试，预期通过。提交：

```powershell
git add data/maps.json tests/test_tactical_party_battle.gd tests/test_effect_data.gd
git commit -m "data: 配置山道强人出战位" --no-gpg-sign
```

如果没有修改 `tests/test_effect_data.gd`，提交命令中去掉该文件。

---

## Task 6: 最终验证与手测指引

**文件：**

- 修改：必要时更新 `README.md` 当前目标。

- [ ] **Step 1: 全量测试**

运行全量测试，确认 `GodotExit:0`。

- [ ] **Step 2: 检查 Godot 导入噪音**

运行：

```powershell
git status --short --branch
```

若只出现 `assets/**/*.import` 噪音，执行：

```powershell
git -c core.autocrlf=false restore -- assets
```

不要回退无关用户改动。

- [ ] **Step 3: 手动验收**

建议手测路径：

1. 新游戏进入山道。
2. 完成山道试剑，让青衫客入队。
3. 按 `P` 打开队伍面板，确认出现“默认出战顺序”。
4. 调整青衫客顺序后关闭再打开，确认顺序保持。
5. 触发山道强人战，确认主角和青衫客都进入战场。
6. 让青衫客倒下，结束战斗后回到地图。
7. 再按 `P` 打开队伍面板，确认青衫客气血为 1。
8. 存档、退回主菜单、读档，确认默认编队和 1 血状态仍正确。

- [ ] **Step 4: 最终提交**

若只更新文档或 README，单独提交：

```powershell
git add README.md
git commit -m "docs: 更新出战编队手测说明" --no-gpg-sign
```

如果没有文档更新，则不需要最终提交。

---

## 风险检查清单

- [ ] UI 可见文本全部中文，不能显示 `hero_yun`、`qingshanke` 等内部 ID。
- [ ] 主角必须始终在默认编队首位，并占用出战位。
- [ ] 旧存档缺 `formation_order` 不报错，并能按成员列表生成默认编队。
- [ ] 地图只给 1 个起始格时不会崩溃，且日志说明队友未入场。
- [ ] 战后 1 血保护不破坏客栈失败回流和 HUD 同步。
- [ ] `ActorStatsSystem` 仍是最终属性单一来源，编队系统不得重复计算装备或成长属性。
- [ ] 新增测试纳入 `tests/run_tests.gd` 或现有 suite，最终全量测试通过。
