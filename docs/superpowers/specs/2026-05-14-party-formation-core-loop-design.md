# 出战编队基础闭环设计

## 背景

当前游戏已经具备队友、装备、成长、战斗奖励和多人战棋入场的基础能力，但玩家还不能明确决定“谁出战”和“队友站在哪个起始位”。现有战棋创建流程会按队伍成员顺序尝试生成玩家单位，地图若只提供一个玩家起始格，后续队友就可能无法入场；这让队友成长和装备投入缺少稳定的战斗承载点。

本阶段目标是建立“队伍面板调整默认编队 -> 地图战斗读取出战上限与起始格 -> 战棋按顺序生成玩家单位 -> 战后回写状态”的基础闭环。范围保持垂直可玩，先解决默认出战顺序和地图配置上限，不做复杂战前确认、拖拽站位或队友自动战术。

## 目标

- 玩家可以在队伍面板调整默认出战顺序。
- 主角必须出战，并占用一个出战位。
- 每场战斗可以通过地图数据配置玩家出战上限和起始格。
- 战棋创建时按默认编队顺序、本场上限和起始格生成玩家单位。
- 当前没有足够起始格时，只生成可入场成员，并给出清晰日志。
- 所有战斗结束后，参战且倒下的队伍成员恢复到 1 点气血，避免后续编队或战斗卡死。
- 编队状态、成员 HP/MP、成长和装备继续随存档恢复。
- 预留战前确认面板、手动站位和队友战术 AI 的扩展位置。

## 非目标

- 不做战前确认弹窗或战前准备场景。
- 不做棋盘拖拽站位或单人指定格子。
- 不做队友自动 AI、战术策略、阵型加成或职业站位。
- 不做临时替补、援护、候补经验、战斗中换人。
- 不重做现有队伍面板为完整角色管理页。
- 不调整敌人 AI 和战斗胜负规则。

## 核心规则

### 默认编队

默认编队保存在队伍状态中，表示玩家期望的出战顺序。第一版只管理顺序，不管理具体格子。

主角 `hero_yun` 必须在默认编队中，并且始终占用一个出战位。若旧存档或异常数据缺少主角，系统在读取编队时自动把主角补到首位。

队友加入队伍后，若不在默认编队中，则默认追加到队尾。队友离队或成员数据不存在时，读取编队时自动过滤无效角色。

### 地图配置

每个战斗触发对象可以声明玩家出战配置：

```json
"player_deploy": {
  "max_members": 2,
  "start_cells": [
    {"q": 5, "r": 3},
    {"q": 5, "r": 4}
  ]
}
```

`max_members` 表示本场最多允许几个玩家单位入场，包含主角。`start_cells` 表示按编队顺序依次分配的起始格。

兼容策略：

- 若缺少 `player_deploy`，继续兼容现有 `player_start_cells`。
- 若也缺少 `player_start_cells`，继续从 `units` 中 `team = "player"` 的旧配置读取 `start_cell`。
- 若仍没有起始格，使用现有兜底起始格。
- 若 `max_members` 缺失，则使用起始格数量作为上限。
- 实际出战人数不能超过 `max_members`、起始格数量和当前队伍有效成员数量。

### 入场顺序

战棋创建玩家单位时遵循：

```text
PartyState.formation_order
-> 过滤不在 party.members 的角色
-> 确保主角在首个有效出战序列中
-> 按地图 max_members 截断
-> 按 start_cells 顺序分配站位
-> ActorStatsSystem 合成属性
-> TacticalUnitState.from_dictionary()
```

第一版不区分前排、后排、职业或武器类型。第 1 个成员进入第 1 个起始格，第 2 个成员进入第 2 个起始格，以此类推。

### 战后 1 血保护

所有战斗结束后，无论胜利、失败或暂退，参战且倒下的队伍成员恢复到 1 点气血。这个规则只保证队伍不会因为倒下状态卡死，不代表完全恢复。

主角仍沿用现有失败回流、客栈绑定和 HUD 同步逻辑；但如果主角作为参战成员在战斗结果中 HP 为 0，写回队伍状态时也应至少保留 1 点气血，避免后续状态面板出现不可用角色。

## 数据设计

`PartyState` 新增默认编队字段：

```gdscript
var formation_order: Array[String] = []
```

序列化结构：

```json
{
  "members": ["hero_yun", "qingshanke"],
  "formation_order": ["hero_yun", "qingshanke"],
  "member_status": {
    "hero_yun": {"level": 2, "exp": 25, "total_exp": 55, "hp": 128, "mp": 22},
    "qingshanke": {"level": 1, "exp": 20, "total_exp": 20, "hp": 1, "mp": 18}
  }
}
```

旧存档缺少 `formation_order` 时，默认使用 `party.members` 顺序，并确保主角位于首位。

建议新增方法：

```gdscript
func get_formation_order() -> Array[String]
func set_formation_order(actor_ids: Array) -> void
func move_formation_member(actor_id: String, direction: int) -> void
func get_deployable_members(max_members: int) -> Array[String]
func normalize_formation() -> void
```

`normalize_formation()` 负责过滤无效角色、补齐主角和追加未进入编队的新队友。

## 系统设计

### PartyState

`PartyState` 负责保存和规范化默认编队。它不读取地图配置，也不判断战斗起始格，只提供合法的成员顺序。

规则：

- 编队只包含当前队伍成员。
- 主角必须存在且优先。
- 未在编队中的队伍成员追加到队尾。
- 重复角色只保留第一次出现。
- 序列化和反序列化都调用规范化逻辑。

### TacticalCombatSystem

`TacticalCombatSystem.create_battle()` 继续负责构造战斗。玩家单位生成改为读取规范化后的出战成员：

- 读取 `player_deploy.max_members` 和 `player_deploy.start_cells`。
- 兼容旧 `player_start_cells` 和旧 `units.team = player`。
- 调用 `game_state.party.get_deployable_members(max_members)` 获得出战成员。
- 按顺序生成玩家单位。
- 起始格不足时跳过后续成员，并写入中文战斗日志。

敌人单位仍来自 `context.units`，本阶段不改敌人配置。

### GameState

战斗结果回写时，继续通过 `party_member_results` 更新成员 HP/MP。新增保护规则：当参战成员 HP 小于等于 0 时，写回至少 `1`。

这条规则应放在统一回写路径，避免战棋和旧普通战斗结算行为不一致。

### PartyPanel

队伍面板新增轻量编队区域：

- 显示“默认出战顺序”。
- 列出当前编队成员中文名。
- 每个非主角成员提供“上移”“下移”按钮。
- 主角显示为“主角 必出战”，不能移出编队。
- 调整后立即刷新并保存到 `PartyState`。

第一版不做拖拽，不做复杂图标，不做战前临时覆盖。

## UI 文案

所有可见文本必须中文。建议文案：

- 面板标题：`默认出战顺序`
- 主角标记：`必出战`
- 按钮：`上移`、`下移`
- 空状态：`暂无可调整队友。`
- 日志：`青衫客无法入场：本场出战位置不足。`
- 日志：`青衫客重伤未愈，战后保留 1 点气血。`

## 测试计划

- `test_party_state.gd`：覆盖默认编队初始化、主角必出战、过滤无效成员、追加新队友、上移下移、序列化兼容旧存档。
- `test_tactical_party_battle.gd`：覆盖地图 `player_deploy.max_members` 限制出战人数，按 `start_cells` 顺序生成玩家单位。
- `test_tactical_party_battle.gd`：覆盖缺少 `player_deploy` 时兼容旧 `units.team = player` 起始格。
- `test_combat_and_save.gd` 或新增测试：覆盖战斗结束后倒下队友写回 1 点气血并可存档恢复。
- `test_party_panel.gd`：覆盖队伍面板显示默认出战顺序，上移/下移后顺序变化。
- 全量 `tests/run_tests.gd` 保持通过。

## 手动验收

1. 新游戏完成山道试剑，让青衫客入队。
2. 按 `P` 打开队伍面板，看到“默认出战顺序”。
3. 调整青衫客和后续队友的顺序，关闭再打开后顺序保持。
4. 进入配置了 2 个出战位的战棋，主角和第一名队友按顺序入场。
5. 将地图出战上限临时设为 1 时，只有主角入场，并有中文日志说明队友未入场。
6. 让队友在战斗中倒下，战斗结束后队伍面板显示该队友气血为 1。
7. 存档并重新进入，默认编队和队友 1 血状态保持正确。

## 风险与取舍

最大风险是编队、地图起始格和战棋单位生成三者边界不清。为降低风险，本阶段约定：`PartyState` 只管顺序，地图只管上限与格子，`TacticalCombatSystem` 负责组合两者生成战斗单位。

第二个风险是 UI 范围膨胀。第一版只在队伍面板中加入顺序调整，不做战前弹窗和棋盘站位选择，确保实现重点仍是规则闭环。

第三个风险是战后 1 血保护与现有失败回流冲突。实现时必须把主角旧字段和 `PartyState.member_status` 同步纳入测试，确保 HUD、队伍面板和战斗状态一致。
