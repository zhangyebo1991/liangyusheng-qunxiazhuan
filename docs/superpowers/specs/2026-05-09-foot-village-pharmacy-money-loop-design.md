# 山脚村镇药铺与铜钱补给切片设计

日期：2026-05-09
项目：liangyusheng-qunxiazhuan
目标引擎：Godot 4.6

## 目标

下一阶段创建“山脚村镇药铺与铜钱补给切片”，让刚完成的回合战斗产生真实补给需求。玩家应能在山脚村镇打开药铺，用铜钱购买小还丹，并通过存档恢复铜钱和背包数量。

本阶段不是完整经济系统。核心验证点是：铜钱字段、商品价格、购买规则、商店面板、背包叠加和存档恢复能否稳定运作，为后续药铺、铁匠铺、战斗掉落和任务奖励打基础。

## 范围

本阶段包含：

- `PartyState` 增加 `coins` 铜钱字段。
- 新游戏初始铜钱为 `80`。
- 山脚村镇新增药铺交互对象。
- 与药铺交互时打开商店面板。
- 商店显示当前铜钱、商品名称、价格、描述和购买按钮。
- 第一版商品只包含小还丹。
- 小还丹价格使用 `data/items.json` 中的 `value`，当前为 `30`。
- 玩家点击购买后，铜钱减少，小还丹数量增加。
- 铜钱不足时显示“铜钱不足。”，不扣钱，不加物品。
- 购买结果刷新商店面板和已打开的背包面板。
- 铜钱和购买后的背包数量可存档和读档恢复。

本阶段不做：

- 卖出物品。
- 多商店类型。
- 商店库存限制。
- 砍价、声望、价格浮动。
- 装备购买。
- 战斗后掉钱结算。
- 任务奖励铜钱。
- 正式菜单美术。

## 推荐方案

采用“村镇药铺买药”小切片。

当前项目已经有山道战斗、山脚村镇、背包、小还丹使用和存档。下阶段最自然的闭环是“战斗消耗小还丹，回村用铜钱补给”。相比一次性做通用商店系统，本阶段只做药铺买小还丹，可以用较小范围验证经济基础，不把工作扩大成完整菜单系统。

第一版只卖一种商品：小还丹，价格 `30` 铜钱。新游戏给 `80` 铜钱，玩家能买两次并在第三次看到“铜钱不足。”，可以同时验证成功购买、连续购买和失败提示。

## 架构

项目继续保持“领域逻辑、系统流程、场景表现”分层。

- `scripts/domain/party_state.gd` 保存队伍成员、背包数量和铜钱。
- `scripts/systems/shop_system.gd` 处理购买校验、扣钱和加物品。
- `scripts/core/game_state.gd` 初始化新游戏铜钱，并通过 `party.to_dictionary()` 保存铜钱。
- `scripts/scenes/hud.gd` 显示商店面板、铜钱、商品列表和购买按钮。
- `scripts/scenes/map_screen_base.gd` 持有 `ShopSystem`，构建商店商品列表并处理购买结果。
- `scripts/scenes/foot_village_screen.gd` 处理村镇药铺交互分支。
- `scripts/scenes/map_interactable.gd` 支持 `shop` 类型交互提示和颜色。
- `data/maps.json` 配置山脚村镇药铺对象。
- `data/items.json` 继续保存物品资料和价格。
- `tests/` 保存 GDScript 逻辑测试。

商店界面不直接修改 `GameState.party.inventory` 或 `PartyState.coins`。HUD 只发出购买意图，购买规则由 `ShopSystem` 统一处理。

## 关键组件

### PartyState

`PartyState` 新增：

- `coins: int`
- `add_coins(amount)`
- `can_afford(amount)`
- `spend_coins(amount)`

规则：

- 默认铜钱为 `0`。
- `add_coins()` 忽略小于等于 0 的数量。
- `can_afford()` 在金额小于等于 0 时返回 `false`。
- `spend_coins()` 在金额有效且余额足够时扣除并返回 `true`。
- 铜钱不足时 `spend_coins()` 返回 `false`，余额不变。
- `to_dictionary()` 和 `from_dictionary()` 保存和恢复 `coins`。
- 旧存档缺少 `coins` 时读入为 `0`。
- 读档铜钱小于 0 时钳制为 `0`。

### ShopSystem

新增 `scripts/systems/shop_system.gd`。

主要接口：

- `set_repository(repository)`
- `buy_item(game_state, item_id, quantity = 1)`

返回字典包含：

- `success`
- `message`
- `item_id`
- `quantity`
- `cost`
- `coins`
- `remaining`

规则：

- `game_state` 或 `game_state.party` 缺失时失败。
- `item_id` 为空时失败。
- `quantity <= 0` 时失败。
- 物品资料缺失时失败。
- 物品价格 `value <= 0` 时失败。
- 铜钱不足时失败。
- 成功购买时先扣铜钱，再加背包。
- 扣铜钱失败时不加物品。

用户可见消息：

- 成功：“买入小还丹。”
- 铜钱不足：“铜钱不足。”
- 商品缺失或价格无效：“此商品暂时不能购买。”

### 数据设计

`data/items.json` 继续使用 `value` 作为购买价格。

第一版商品：

```json
{
  "id": "herb_small",
  "name": "小还丹",
  "type": "consumable",
  "description": "恢复少量气血。",
  "value": 30,
  "effects": {
    "heal_hp": 30
  }
}
```

`data/maps.json` 在 `foot_village` 中新增药铺对象。

建议结构：

```json
{
  "id": "shop_foot_village_pharmacy",
  "type": "shop",
  "name": "药铺",
  "position": {"x": 980, "y": 320},
  "radius": 72,
  "shop_id": "foot_village_pharmacy",
  "items": ["herb_small"]
}
```

第一版不新增独立 `shops.json`。药铺商品直接放在地图对象上，减少数据文件数量。后续出现多个商店、库存或价格表时，再拆出 `data/shops.json`。

### HUD 商店面板

`hud.gd` 增加商店面板，和背包面板同级，不嵌套。

面板内容：

- 标题：药铺。
- 当前铜钱：`铜钱：80`。
- 空商品提示：`药铺暂时没有可买之物。`
- 商品行：`小还丹 30 文`。
- 商品描述：`恢复少量气血。`
- `购买` 按钮。
- `关闭` 按钮。

HUD 新增信号：

- `shop_buy_requested(item_id: String)`

HUD 新增方法：

- `show_shop(title, coins, items)`
- `hide_shop()`
- `refresh_shop(coins, items)`
- `is_shop_open()`

`items` 是场景层构建的商品显示数据，至少包含：

- `id`
- `name`
- `description`
- `price`
- `can_buy`

### MapScreenBase

`map_screen_base.gd` 统一接入商店行为：

- 创建 `shop_system` 并设置 `DataRepository`。
- 监听 `hud.shop_buy_requested`。
- 提供 `_open_shop(record)`。
- 提供 `_build_shop_items(record)`。
- 购买后显示 `ShopSystem` 返回的消息。
- 购买后刷新商店面板。
- 如果背包面板打开，也刷新背包面板。

`MapScreenBase` 只处理通用商店接线，不写死村镇药铺剧情。

### FootVillageScreen

`foot_village_screen.gd` 增加 `shop` 交互分支。

规则：

- 与 `shop` 类型对象交互时调用 `_open_shop(record)`。
- 不把购买规则写进村镇场景脚本。
- 药铺不要求先完成“送信到客栈”任务，避免补给被剧情卡住。

### MapInteractable

`map_interactable.gd` 增加 `shop` 类型：

- 提示文本：`按 E 查看药铺`。
- 颜色可使用与 NPC、出口、告示牌不同的颜色，方便调试。

## 玩家流程

1. 玩家从主菜单开始新游戏，初始铜钱为 `80`。
2. 玩家从山道进入山脚村镇。
3. 玩家靠近药铺，底部提示显示“按 E 查看药铺”。
4. 玩家按 `E` 打开药铺面板。
5. 面板显示当前铜钱和小还丹：
   - 小还丹。
   - `30 文`。
   - `恢复少量气血。`
6. 玩家点击“购买”。
7. 铜钱足够时，铜钱减少 `30`，背包小还丹数量增加 `1`，显示“买入小还丹。”。
8. 玩家连续购买两次后，铜钱从 `80` 变为 `20`。
9. 玩家第三次点击“购买”，显示“铜钱不足。”，背包数量不变。
10. 玩家按 `I` 打开背包，可以看到新增的小还丹。
11. 玩家存档后回到主菜单，再继续游戏，铜钱和小还丹数量保持正确。

## 输入与界面

沿用现有输入：

- WASD 连续移动。
- E 键交互。
- 鼠标点击交互对象和 UI 按钮。
- I 键打开背包。
- Esc 存档。

商店面板只用鼠标按钮操作。第一版不要求键盘快捷键或手柄导航。

背包面板和商店面板可以同时存在，但推荐实现时打开商店不自动打开背包。若背包已经打开，购买成功后刷新背包内容。

## 存档设计

现有 `SaveSystem` 继续保存 `GameState.to_dictionary()`。

本阶段新增保存字段位于 `party`：

- `coins`

继续保存：

- 队伍成员。
- 背包数量。
- 任务状态。
- 地图状态。
- 主角气血。
- 武学熟练度。

读档规则：

- 缺少 `party.coins` 时使用 `0`。
- `party.coins < 0` 时钳制为 `0`。
- 背包数量继续按现有规则恢复。

## 错误处理

错误处理规则：

- 药铺对象缺少 `items` 或 `items` 为空：显示“药铺暂时没有可买之物。”。
- 商品编号不存在：显示“此商品暂时不能购买。”。
- 商品价格小于等于 0：显示“此商品暂时不能购买。”。
- 购买数量小于等于 0：显示“此商品暂时不能购买。”。
- 铜钱不足：显示“铜钱不足。”。
- 购买失败时不扣铜钱，不增加背包数量。
- 商店面板刷新时遇到无效商品，应跳过或显示为不可购买项，不应黑屏或卡死。

## 测试

逻辑测试继续使用 Godot 无头脚本运行。

需要覆盖：

- `PartyState` 默认铜钱为 `0`。
- `PartyState.add_coins(80)` 后铜钱为 `80`。
- `PartyState.spend_coins(30)` 成功后铜钱为 `50`。
- 铜钱不足时 `spend_coins(100)` 失败且余额不变。
- `PartyState.to_dictionary()` 和 `from_dictionary()` 保存恢复铜钱。
- 旧存档缺少 `coins` 时为 `0`。
- 读档铜钱小于 `0` 时钳制为 `0`。
- 新游戏初始铜钱为 `80`。
- `ShopSystem.buy_item()` 铜钱足够时购买小还丹成功，铜钱减少，背包增加。
- 连续购买两次后余额为 `20`，小还丹数量增加 `2`。
- 铜钱不足时购买失败，不扣铜钱，不加物品。
- 物品资料缺失时购买失败，不扣铜钱。
- 价格无效时购买失败，不扣铜钱。
- `foot_village` 地图包含药铺对象。
- 药铺对象包含 `items: ["herb_small"]`。
- `MapInteractable.get_interaction_text()` 对 `shop` 类型返回药铺交易提示。
- HUD 商店面板能显示铜钱、商品和购买按钮。
- 点击购买按钮会发出 `shop_buy_requested`。
- `MapScreenBase` 能构建商店商品列表并调用 `ShopSystem`。

场景验收需要人工或后续自动化验证：

- 从主菜单开始新游戏后，进入山脚村镇。
- 靠近药铺显示“按 E 查看药铺”。
- 按 `E` 打开药铺面板。
- 面板显示铜钱 `80` 和小还丹价格 `30 文`。
- 点击购买后铜钱变为 `50`，背包小还丹增加。
- 再买一次后铜钱变为 `20`。
- 第三次购买显示“铜钱不足。”。
- 按 `I` 打开背包可以看到购买的小还丹。
- 按 Esc 存档后继续游戏，铜钱和小还丹数量恢复正确。

## 验收标准

本阶段完成后，玩家应能在山脚村镇打开药铺，用初始铜钱购买小还丹，并在铜钱不足时得到正确提示。购买后的铜钱和背包数量必须能存档恢复。

验收标准不是完整经济系统，而是建立第一条补给闭环：回合战斗造成消耗，村镇药铺提供补给，铜钱成为可保存、可消费的资源。

## 实现约束

- 所有玩家可见文本必须使用中文。
- 代码标识符、Godot API、路径、配置键和命令可以保留英文。
- 不引入外部插件。
- 不把 Godot 引擎二进制提交到仓库。
- 逻辑优先写测试，再实现。
- 商店购买规则必须有系统层测试覆盖。
- HUD 只负责展示和发出购买意图，不直接修改铜钱或背包。
- `ShopSystem` 是购买规则的唯一入口。
- `.superpowers/`、`.tools/` 和 `.spec-workflow/` 不纳入提交。
