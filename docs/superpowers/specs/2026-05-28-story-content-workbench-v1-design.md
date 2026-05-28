# 剧情内容工作台 v1 设计规格书

## 1. 阶段定位

地图编辑闭环 v1 已经支持在 Godot 编辑器 Dock 中新增和编辑地图对象模板。内容引用校验器 v1 已经能在地图预览 Dock 中提示当前地图对象引用了不存在的对白、任务、角色、物品或目标地图。

本阶段目标是把“引用是否存在”推进到“可以顺手补内容和轻量修改内容”。剧情内容工作台 v1 先嵌入现有地图预览 Dock，不做独立 Dock。用户选中 NPC 或其他地图对象后，可以查看对象挂载的对白和任务入口，打开对应对白和任务摘要，编辑最常用字段，并在已有占位 ID 缺失内容时创建模板。

v1 只服务对白与任务入口闭环，不做完整剧情编辑器。

## 2. 范围

### 2.1 本阶段支持

- 在现有 `地图预览` Dock 中加入剧情内容面板。
- 选中地图对象后显示对象剧情入口：`id`、`name`、`type`、`dialogue_id`、`quest_id`、`required_quest_id`。
- 对已有 `dialogue_id` 显示并编辑对白 `title`、`lines[].speaker`、`lines[].text`。
- 对已有任务显示并编辑 `title`、`description`。
- 显示对象直连任务：`quest_id` 和 `required_quest_id`。
- 反查并显示引用当前对白的任务：`start_dialogue` 或 `complete_dialogue` 等于当前 `dialogue_id`。
- 当对象已有 `dialogue_id` 但 `data/dialogues.json` 缺失对应记录时，可以创建对白模板。
- 当对象已有 `quest_id` 或 `required_quest_id` 但 `data/quests.json` 缺失对应记录时，可以创建任务模板。
- 对白和任务使用独立保存按钮，分别写入 `data/dialogues.json` 和 `data/quests.json`。
- 保存时检测磁盘外部修改，避免覆盖 AI 或用户刚改过的 JSON。

### 2.2 本阶段不支持

- 不编辑地图对象引用字段本身，例如不在剧情面板里修改 `dialogue_id` 或 `quest_id`。
- 不为缺失但为空的字段自动生成 ID，不回填 `data/maps.json`。
- 不编辑 dialogue `options`。
- 不编辑 `conditions`、`effects`、奖励字段、战斗上下文或 `battle_context`。
- 不做复杂对白树可视化。
- 不做独立剧情内容 Dock。
- 不做字段级冲突合并。
- 不扫描全项目所有间接剧情引用，只围绕当前选中对象和当前对白做入口级反查。

## 3. 用户体验

剧情内容面板嵌入现有 `地图预览` Dock，放在对象编辑区域之后、校验结果附近。面板只在选中地图对象时显示有效内容。选中出生点或障碍物时，显示空态文案，例如 `未选中剧情对象`。

### 3.1 对象剧情入口

面板顶部显示当前对象的只读入口信息：

```text
对象：npc_qingshanke / 青衫客 / npc
对白：mountain_pass_intro
任务：quest_mountain_trial
前置任务：-
```

这些字段来自 `data/maps.json` 中当前地图对象。v1 不在这里编辑对象引用，避免剧情内容保存和地图内容保存混在一起。

### 3.2 对白区域

当 `dialogue_id` 为空时，显示 `当前对象没有对白入口`。

当 `dialogue_id` 非空但对白缺失时，显示红字状态和 `创建对白模板` 按钮。按钮只创建已有 ID 的模板，不新起 ID。

当对白存在时，显示：

- 标题输入框。
- 对白行列表。每行包含一个 `speaker` 输入框和一个 `text` 输入框。
- `添加对白行` 按钮。
- 每行的 `删除` 按钮。
- `保存对白` 按钮。

如果对白包含 `options`，v1 只显示摘要，例如 `包含 3 个选项，v1 暂不编辑`。

### 3.3 任务区域

任务区域显示两类任务：

- 对象直连任务：对象自己的 `quest_id`、`required_quest_id`。
- 对白反查任务：`data/quests.json` 中 `start_dialogue` 或 `complete_dialogue` 指向当前 `dialogue_id` 的任务。

每个任务显示：

- 任务 ID。
- 来源说明，例如 `对象 quest_id`、`对象 required_quest_id`、`start_dialogue 引用当前对白`、`complete_dialogue 引用当前对白`。
- 标题输入框。
- 描述输入框。
- `保存任务` 按钮。

如果任务记录缺失但对象已有对应 `quest_id` 或 `required_quest_id`，显示 `创建任务模板` 按钮。对白反查只展示已有任务，不为反查结果生成新任务。

任务的 `complete_effects`、奖励字段和其他复杂字段只显示摘要，不编辑。

## 4. 架构设计

### 4.1 `StoryContentDocument`

新增 `addons/map_preview/story_content_document.gd`，作为编辑器专用剧情内容文档层。它的职责类似 `MapContentDocument`，但只处理对白和任务文件。

职责：

- 读取 `data/dialogues.json`。
- 读取 `data/quests.json`。
- 维护 `dialogues_by_id` 和 `quests_by_id`。
- 维护 `quests_by_dialogue_id`，用于当前对白的任务反查。
- 分别记录对白文件和任务文件的 `loaded_hash` 与 dirty 状态。
- 更新对白标题和对白行。
- 更新任务标题和描述。
- 创建缺失对白模板。
- 创建缺失任务模板。
- 分别保存对白文件和任务文件。
- 检测对白文件或任务文件是否发生外部修改。

建议接口：

```gdscript
func load_all(dialogues_path := "res://data/dialogues.json", quests_path := "res://data/quests.json") -> bool
func get_dialogue(dialogue_id: String) -> Dictionary
func get_quest(quest_id: String) -> Dictionary
func find_quests_for_dialogue(dialogue_id: String) -> Array

func update_dialogue_title(dialogue_id: String, title: String) -> Dictionary
func set_dialogue_lines(dialogue_id: String, lines: Array) -> Dictionary
func create_dialogue_template(dialogue_id: String) -> Dictionary
func save_dialogues() -> bool

func update_quest_summary(quest_id: String, title: String, description: String) -> Dictionary
func create_quest_template(quest_id: String) -> Dictionary
func save_quests() -> bool

func dialogues_have_external_change() -> bool
func quests_have_external_change() -> bool
```

返回 `Dictionary` 的修改接口使用现有编辑器文档层风格：

```gdscript
{"ok": true, "error": ""}
{"ok": false, "error": "对白不存在：missing_dialogue"}
```

### 4.2 模板格式

对白模板：

```json
{
  "id": "已有 dialogue_id",
  "title": "新对白",
  "lines": [
    {"speaker": "", "text": ""}
  ]
}
```

任务模板：

```json
{
  "id": "已有 quest_id",
  "title": "新任务",
  "description": ""
}
```

模板只补最小合法结构，不自动写 `start_dialogue`、`complete_dialogue`、奖励或效果。后续内容由用户或 AI 继续补。

### 4.3 `MapPreviewPlugin` 集成

`MapPreviewPlugin` 继续作为 Dock UI 聚合入口，但剧情内容读写逻辑放在 `StoryContentDocument`。

插件新增职责：

1. preload 并持有 `StoryContentDocument`。
2. 在 `_build_dock()` 中创建剧情内容面板。
3. 当选中对象变化时，调用 `_update_story_workbench(map_data)` 刷新面板。
4. 当 `data/maps.json`、`data/dialogues.json` 或 `data/quests.json` 外部变化时，刷新对应内容。
5. 将 UI 输入同步给 `StoryContentDocument`。
6. 处理 `保存对白`、`保存任务`、`创建对白模板`、`创建任务模板` 按钮。

地图主保存按钮仍只保存地图布局和地图内容，不保存对白或任务。对白和任务必须由各自按钮保存。

### 4.4 与引用校验器的关系

内容引用校验器 v1 继续负责报告断引用。剧情内容工作台 v1 负责处理其中一部分断引用的后续动作：当当前对象有缺失的 `dialogue_id` 或 `quest_id` 时，可以创建模板。

v1 不要求校验器和工作台共享同一个索引对象。两者可以各自从磁盘读取数据，保持实现简单。后续如果性能或一致性成为问题，再抽公共内容索引。

## 5. 数据流

### 5.1 选中对象

1. 用户点击地图预览对象或对象列表。
2. `MapPreviewPlugin` 更新 `selected_object_id`。
3. 插件从当前 `map_data.objects` 找到对象记录。
4. 插件读取对象的 `dialogue_id`、`quest_id`、`required_quest_id`。
5. 插件从 `StoryContentDocument` 查询对白和任务。
6. 插件刷新剧情内容面板。

### 5.2 编辑对白

1. 用户修改对白标题或对白行。
2. 插件收集当前 UI 中的 `title` 和 `lines`。
3. 插件调用 `StoryContentDocument.update_dialogue_title()` 和 `set_dialogue_lines()`。
4. 文档层标记对白 dirty。
5. 用户点击 `保存对白`。
6. 文档层检查 `dialogues.json` 是否有外部修改。
7. 若无冲突，写回 `data/dialogues.json` 并刷新 hash。
8. 若有冲突，拒绝保存并提示先刷新。

### 5.3 编辑任务

1. 用户修改任务标题或描述。
2. 插件调用 `StoryContentDocument.update_quest_summary()`。
3. 文档层标记任务 dirty。
4. 用户点击 `保存任务`。
5. 文档层检查 `quests.json` 是否有外部修改。
6. 若无冲突，写回 `data/quests.json`。
7. 若有冲突，拒绝保存并提示先刷新。

### 5.4 创建模板

1. 当前对象存在非空 `dialogue_id` 或任务 ID。
2. `StoryContentDocument` 中找不到对应记录。
3. 插件显示创建模板按钮。
4. 用户点击按钮。
5. 文档层向对应数组追加模板记录并标记 dirty。
6. 面板立即显示新模板的可编辑字段。
7. 用户继续编辑并点击对应保存按钮。

## 6. 错误处理

- JSON 文件不存在或不是数组时，面板显示错误状态，不允许保存。
- 创建模板时，如果 ID 为空，返回错误，不自动生成 ID。
- 创建模板时，如果 ID 已存在，返回错误并刷新面板。
- 保存时如果磁盘内容 hash 和 loaded_hash 不一致，拒绝覆盖并提示 `对白文件已被外部修改，请刷新后再保存。` 或 `任务文件已被外部修改，请刷新后再保存。`
- 对白行保存前过滤为数组中的字典结构，`speaker` 和 `text` 统一转字符串。
- 任务反查只读取合法字典记录。异常记录跳过，不阻断正常显示。

## 7. 测试策略

### 7.1 `StoryContentDocument` 单元测试

新增 `tests/test_story_content_document.gd`，覆盖：

- 加载对白和任务 JSON。
- 按 ID 获取对白和任务。
- 编辑对白 `title`。
- 替换对白 `lines`。
- 编辑任务 `title` 和 `description`。
- 创建缺失对白模板。
- 创建缺失任务模板。
- 反查引用某个对白的任务，覆盖 `start_dialogue` 和 `complete_dialogue`。
- 保存对白后 JSON 仍为数组。
- 保存任务后 JSON 仍为数组。
- dirty 状态下检测到外部修改时拒绝保存。
- 空 ID 创建模板返回错误。
- 重复 ID 创建模板返回错误。

### 7.2 `MapPreviewPlugin` 源级接线测试

扩展现有 map preview 插件源码测试，确认：

- 插件 preload `StoryContentDocument`。
- 插件持有 `story_content_document` 实例。
- 对象选中后调用剧情面板刷新方法。
- 存在对白保存、任务保存、创建对白模板、创建任务模板入口。
- 地图主保存按钮不保存对白和任务。
- 剧情面板 UI 创建逻辑存在空态、缺失状态和已有内容状态。

### 7.3 手动 smoke test

实现计划中保留手动验证：

1. 打开 Godot 编辑器。
2. 打开 `scenes/mountain_pass.tscn`。
3. 选中 `npc_qingshanke`。
4. 确认剧情内容面板显示对白标题和对白行。
5. 临时修改一行对白文本并点击 `保存对白`。
6. 确认 `data/dialogues.json` 写入变化。
7. 恢复文本并保存。
8. 临时让某个对象指向缺失 `dialogue_id`。
9. 确认面板显示创建对白模板按钮。
10. 撤回临时改动。

## 8. 验收标准

1. 选中地图对象后，Dock 显示对象剧情入口信息。
2. 已有对白可以查看、编辑标题、编辑对白行、添加行、删除行并独立保存。
3. 已有任务可以查看、编辑标题和描述并独立保存。
4. 对象已有占位 `dialogue_id` 但对白缺失时，可以创建对白模板。
5. 对象已有占位 `quest_id` 或 `required_quest_id` 但任务缺失时，可以创建任务模板。
6. 面板能显示引用当前对白的任务，至少覆盖 `start_dialogue` 和 `complete_dialogue`。
7. `options`、`conditions`、`effects`、奖励和战斗上下文只显示摘要，不可编辑。
8. 地图主保存按钮不保存对白或任务。
9. 对白文件和任务文件外部修改时，dirty 内容保存会被拒绝覆盖。
10. 完整 Godot headless 测试通过。

## 9. 后续阶段

### 9.1 剧情内容工作台 v1.5

- 从剧情面板跳转或定位到引用校验器报告的具体对象。
- 支持编辑任务 `start_dialogue` 和 `complete_dialogue`。
- 支持创建对白后回填任务字段，但仍避免复杂效果编辑。
- 显示 dialogue options 的 `next_dialogue_id` 断链状态。

### 9.2 独立剧情内容 Dock

- 将 `StoryContentDocument` 复用到独立 Dock。
- 提供对白列表、任务列表和搜索。
- 支持从地图对象跳转到独立剧情 Dock 的当前内容。
- 支持更完整的对白树查看。

### 9.3 完整剧情编辑器

- 编辑对白选项、条件、效果和战斗上下文。
- 编辑任务阶段、完成效果、奖励和传闻。
- 做全项目引用反查与内容体检。
- 提供缺失内容批量创建和修复建议。
